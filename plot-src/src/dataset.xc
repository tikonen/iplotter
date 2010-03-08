/*
 * Plot - plot time-based data on screen and to file with interactive controls
 * Copyright (C) 2006  Jonas Berlin <xkr47@outerspace.dyndns.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 ****
 * dataset - functions for managing data sets. Usually one instance
 * represents all the data loaded from a single data file.
 */

#include <ctype.h>
#include <math.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include "dataset.xh"
#include "stringutil.xh"
#include "system.xh"
#include "misc-util.xh"

static void free_dataset(my_dataset_t *dataset);

static my_time_t parse_timestamp(const char **p) {
   return (my_time_t)(parse_double_num(p) * TIME_MULTIPLIER);
}

static void parse_error(my_dataset_t *dataset, const char *fmt, ...) FORMAT(2,3);

static void parse_error(my_dataset_t *dataset, const char *fmt, ...) {
   int n;
   va_list ap;

   char *err_data = dataset->parse_errors;
   int pos = dataset->parse_errors_pos;
   size_t fullSize = dataset->parse_errors_size;

   /* The preview does not store the parsing errors */
   if (!err_data) {
      return;
   }

   // TODO extract to my_vasprintf()
   while (true) {
      size_t size = fullSize - pos;
      /* Try to print in the allocated space. */
      va_start(ap, fmt);
      n = vsnprintf (err_data+pos, size, fmt, ap);
      va_end(ap);
      /* If that worked, return the string. */
      if (n > -1 && n < (int)size) {
	 dataset->parse_errors = err_data;
	 dataset->parse_errors_size = fullSize;
	 dataset->parse_errors_pos += n;
	 return;
      }
      /* Else try again with more space. */
      fullSize *= 2;
      err_data = realloc_c(err_data, fullSize);
   }
}

static void print_parse_errors(my_dataset_t *dataset) {
   if (dataset->parse_errors) {
      dataset->parse_errors[dataset->parse_errors_pos] = '\0';
      fputs(utf8_to_console(dataset->parse_errors), stdout);
   }
}

/**
 * @return any remaining text not recognized as directive
 */
static const char *parse_directive(my_dataset_t *dataset, const char *directive) {
   while(*directive == '!') {
      printf("Parsing directive: %s", directive);

      // maxdiff(milliseconds)
      if(!strncmp(directive+1, "maxdiff(", 8)) {
	 char *e = strchr(directive+9, ')');
	 if(e) {
	    dataset->maxdiff = atoll(directive+9);
	    directive = skipws(e + 1);
	 } else {
	    parse_error(dataset, _("Broken directive: %s"), directive);
	    return directive;
	 }

      } else {
	 parse_error(dataset, _("Broken directive: %s"), directive);
	 return directive;
      }
   }
   return directive;
}

static void parse_line(my_dataset_t *dataset, char *line, my_time_t timeoff, timestamp_base_t timestamp_base) {
   const char *p = line;

   if (unlikely(*p == '#')) {
      parse_directive(dataset, p+1);
      // TODO tell parse_directive that this directive was not tied to a specific line and thus should consider global functions only.
      return;
   }

   my_time_t timestamp = parse_timestamp(&p);
   if(p == line || !*p) {
      //only timestamp or nothing at all
      return;
   }
   if(!my_isspace(*p)) {
      chomp(line);
      parse_error(dataset, _("Bad data '%s' in line '%s'\n"), p, line);
      return;
   }

   switch(timestamp_base) {
      case TIMESTAMP_BASE_SEC:
	 break;
      case TIMESTAMP_BASE_MILLIS:
	 timestamp /= 1000;
	 break;
      case TIMESTAMP_BASE_DAYS:
	 timestamp *= 86400;
	 break;
   }

   timestamp += timeoff;

   if(unlikely(timestamp < 0)) {
      chomp(line);
      parse_error(dataset, _("Time too big or negative %" PRIdMYTIME " - ignoring line '%s'\n"), timestamp, line);
      return;
   }

   const int lineidx = dataset->time_count;

   my_time_t cur_time_diff;
   if(likely(lineidx > 0)) {
      cur_time_diff = timestamp - dataset->time[lineidx - 1];
      if(unlikely(cur_time_diff <= 0)) {
	 if(cur_time_diff == 0 || dataset->last_parsed_nonadjusted_timestamp == timestamp) {
	    // advance time by 1/TIME_MULTIPLIER seconds
	    dataset->last_parsed_nonadjusted_timestamp = timestamp;
	    timestamp = dataset->time[lineidx - 1] + 1;
	 } else {
	    chomp(line);
	    // TODO translation modifications to get PRIdMYTIME out
	    parse_error(dataset, _("Time goes back %" PRIdMYTIME " diff %" PRIdMYTIME " (prev timestamps [-2] %" PRIdMYTIME ", [-1] %" PRIdMYTIME ") - ignoring line '%s'\n"), timestamp, cur_time_diff, dataset->time[lineidx - 2], dataset->time[lineidx - 1], line);
	    return;
	 }
      }
   } else {
      cur_time_diff = 0;
   }

   my_time_arr_set_length(dataset->time, lineidx + 1);

   dataset->time[lineidx] = timestamp;

   if(likely(lineidx > 0)) {
      if(likely(cur_time_diff > 0) && (cur_time_diff < dataset->min_time_diff || unlikely(!dataset->min_time_diff))) {
	 dataset->min_time_diff = cur_time_diff;
      }
   }

   int i;
   for(i=0; *(p = skipws(p)); ++i) {
      if (unlikely(*p == '#')) {
	 parse_directive(dataset, p+1);
	 // TODO maybe use return value of parse_directive as row-specific data and store it somewhere
         break;
      }

      // try to extract a number
      my_data_t num;
      do {
	 num = parse_double_num(&p);
	 if(unlikely(!my_isspace(*p) && *p)) {
	    // failed to parse number, check quickly why
	    const char *pe = skipnonws(p);

	    // check for nan, NaN or NAN
	    if(pe == p + 3 &&
	       ((*p == 'n' && p[1] == 'a' && p[2] == 'n') ||
		(*p == 'N' && (p[1] == 'A' || p[1] == 'a') && p[2] == 'N'))) {

	       num = NAN;

	    } else {
	       // this field is unparseable, ignore it

	       // check if it's a time field, and if not, complain
	       if(*p != ':') {
		  chomp(line);
		  parse_error(dataset, _("Ignoring bad data '\033[1m%.*s\033[m' in line:\n  %.*s\033[1m%.*s\033[m%s\n\n"), (int)(pe-p), p, (int)(p-line), line, (int)(pe-p), p, pe);
	       }

	       p = skipws(pe);
	       continue;
	    }

	    p = pe;
	 }
	 break;
      } while(1);

      if(unlikely(!*p)) break;

      // make sure we have room for this column
      if(unlikely(i >= dataset->item_count)) {
	 my_dataset_item_arr_set_length(dataset->item, i+1);
      }
      // make sure we have room for this row in this column
      my_data_arr_set_length(dataset->item[i].data, lineidx + 1);

      // check minmax
      if(unlikely(dataset->item[i].max < num)) dataset->item[i].max = num;
      if(unlikely(dataset->item[i].min > num)) dataset->item[i].min = num;

      // check diff minmax
      if(likely(lineidx > 0)) {
	 double diff = (num - dataset->item[i].prev);
	 double diff_abs = fabs(diff);
	 if(diff_abs > 1e-12 && unlikely(dataset->item[i].diffmin > diff_abs)) dataset->item[i].diffmin = diff_abs;
      }

      dataset->item[i].data[lineidx] = num;
      dataset->item[i].prev = num;
   }
}

static void set_path_and_name(my_dataset_t *dataset, char *file) {
   dataset->path_system = file;
   dataset->path_utf8 = filename_to_utf8(file);

   const char *filename = strrchr(dataset->path_utf8, '/');
   if(filename) {
      // slash found, jump to next letter
      filename++;
   } else {
      // no slash, use full name
      filename = dataset->path_utf8;
   }

   dataset->name = strdup(filename);
}

#define MAX_LINE_LEN 500

my_dataset_t *read_dataset_int(const char *cfile, int maxlines, progress_cb_t *cb, void *user_data) {
   FILE *f = fopen(cfile, "rt");
   if(f == NULL) return NULL;

   my_dataset_t *dataset = zmalloc_c(sizeof(my_dataset_t));

   dataset->maxdiff = -1;
   dataset->item_dflt.min = INFINITY;
   dataset->item_dflt.max = -INFINITY;
   dataset->item_dflt.diffmin = INFINITY;
   dataset->item_dflt.data_dflt = NAN;
   dataset->parse_errors_size = 1024;
   dataset->parse_errors = malloc(dataset->parse_errors_size);

   char *file = strdup(cfile);
   set_path_and_name(dataset, file);

   time_t pd_l1 = time(0);

   char line[MAX_LINE_LEN];
   char *labels[100]; //##TODO## non-fixed
   int numlabels = 0;

   // fseek(f, -55 * 10000L, SEEK_END); fgets(line, (int)sizeof(line), f); // skip first partial line

   my_time_t ts_unadjusted;

   // loop until first line with timestamp has been successfully read.
   // while looping, possible column headings and file-specific
   // configuration directives are also parsed
   do {
      if(maxlines >= 0) {
	 if(maxlines-- == 0) {
	    fclose(f);
            int i;
	    for(i=0; i<numlabels; ++i) {
	       free(labels[i]);
	    }
	    parse_error(dataset, _("Too many lines\n"));
	    print_parse_errors(dataset);
	    free_dataset(dataset);
	    return NULL;
	 }
      }
      if(!fgets(line, (int)sizeof(line), f)) {
	 fclose(f);

         int i;
	 for(i=0; i<numlabels; ++i) {
	    free(labels[i]);
	 }
	 parse_error(dataset, _("Error reading file\n"));
	 print_parse_errors(dataset);
	 free_dataset(dataset);
	 return NULL;
      }

      if(numlabels == 0) {
	 // try to detect column labels
	 const char *x = skipws(line);
	 if(*x == '#') {
	    x++;
	    x = parse_directive(dataset, x);
	    x = skipws(x);
	 }

	 // this "detection" is too simple but works in basic cases
	 if(isalpha(*x)) {
	    chomp(line);
	    // labels found -> detect separator - check for tabs, multiple spaces or default to single space
	    const char *sep;
	    if(strchr(x, '\t')) {
	       sep = "\t";
	    } else if(strstr(x, "  ")) {
	       sep = "  ";
	    } else {
	       sep = " ";
	    }

	    char *next;
	    while((next = strstr(x, sep))) {
	       if(numlabels >= SZ(labels) - 1) break;
	       labels[numlabels++] = strnzdup(x, (size_t)(next - x));
	       x = skipws(next+1);
	    }
	    labels[numlabels++] = strdup(x);

	    continue;
	 }
      } else {
	 const char *x = strchr(line, '#');
	 if(x) {
	    parse_directive(dataset, x+1);
	 }
      }

      strip_comments(line);

      if(!*skipws(line)) {
	 // ignore empty lines
	 continue;
      }

      const char *p = line;
      ts_unadjusted = parse_timestamp(&p);
      if(p == line || (!my_isspace(*p) && *p)) {
	 chomp(line);
	 parse_error(dataset, _("Ignoring bad line '%s'\n"), line);
	 continue;
      }

      break;
   } while(1);

   // determine timestamp base

   timestamp_base_t timestamp_base;

   if(ts_unadjusted > 300000000000LL * TIME_MULTIPLIER) {
      timestamp_base = TIMESTAMP_BASE_MILLIS;
      dataset->timetype = TIMETYPE_EPOCH;

   } else if(ts_unadjusted > 300000000LL * TIME_MULTIPLIER) {
      timestamp_base = TIMESTAMP_BASE_SEC;
      dataset->timetype = TIMETYPE_EPOCH;

   } else if(ts_unadjusted > 3650LL * TIME_MULTIPLIER) {
      timestamp_base = TIMESTAMP_BASE_DAYS;
      dataset->timetype = TIMETYPE_EPOCH;

   } else {
      timestamp_base = TIMESTAMP_BASE_SEC;
      dataset->timetype = TIMETYPE_START;
   }

   // get last modification time and assume that's also the time of the last entry
   struct stat st;
   if(stat(file, &st)) {
      perror(_c("read_dataset(): failed to stat file"));
   }

   dataset->last_modified = st.st_mtime * TIME_MULTIPLIER;

   my_time_t timeoff = 0;

   // try to get the relative time of the last entry
   if(dataset->timetype == TIMETYPE_START) {
      long origoff = ftell(f);

      fseek(f, -MAX_LINE_LEN - 1L, SEEK_END);
      char eline[MAX_LINE_LEN];
      my_time_t te = 0;
      fgets(eline, (int)sizeof(eline), f); // skip first partial line
      while(fgets_strip_comments(eline, (int)sizeof(eline), f)) {
	 const char *p = eline;
	 my_time_t tmp = parse_timestamp(&p);
	 if(p > eline) {
	    // update only if successful
	    te = tmp;
	 }
      }

      timeoff = st.st_mtime * TIME_MULTIPLIER - te;

      dataset->ts += timeoff;

      fseek(f, origoff, SEEK_SET);
   }

/*
   dataset->ts -= timeoff;
   timeoff = 0;
   dataset->ts *= 86400;
*/

   dataset->timeoff = timeoff;
   dataset->timestamp_base = timestamp_base;

   if(maxlines >= 0) {
      // scan mode.. load only part of data

      if(maxlines == 0) {
	 maxlines = 1;
      }

      int i;
      for(i=0; i<maxlines; ++i) {
	 parse_line(dataset, line, timeoff, timestamp_base);

	 if(!fgets(line, (int)sizeof(line), f)) break;
      }

      int origcount = dataset->time_count;

      // scan end of file also in case there are more data columns there

      fseek(f, -MAX_LINE_LEN - 1L, SEEK_END);
      fgets(line, (int)sizeof(line), f); // skip first partial line
      while(fgets(line, (int)sizeof(line), f)) {
	 parse_line(dataset, line, timeoff, timestamp_base);
      }

      dataset->te = dataset->time[dataset->time_count-1];

      // restore time count
      dataset->time_count = origcount;

   } else {
      // load whole file

      int idx = 0;

      while(1) {
	 parse_line(dataset, line, timeoff, timestamp_base);

	 if(unlikely(!(idx % 5000))) {
	    if(!(idx % 20000)) {
	       if(cb) {
		  cb(((double)ftell(f)) / st.st_size, user_data);
	       }
	    }

	    if(system_check_events()) {
	       // quit
	       dataset->item_count = 0;
	       break;
	    }
	 }
	 idx++;

	 if(unlikely(!fgets(line, (int)sizeof(line), f))) {
	    dataset->filepos = ftell(f);
	    break;
	 }

	 // ensure complete line
	 if(unlikely(!strrchr(line, '\n'))) {
	    dataset->filepos = ftell(f) - strlen(line);
	    break;
	 }
      }

      dataset->te = dataset->time[dataset->time_count-1];
   }

   fclose(f);

   dataset->ts = dataset->time[0];

   // if the maxdiff was not set by a directive in the file, set it to full length of file -> no discontinuity
   if(dataset->maxdiff == -1) {
      dataset->maxdiff = dataset->te - dataset->ts;
   }

   // make sure all items have same amount of elements and insert labels
   int i;
   for(i=0; i<dataset->item_count; ++i) {
      my_data_arr_set_length(dataset->item[i].data, dataset->time_count);
      if(i < numlabels-1 && labels[i+1]) {
	 dataset->item[i].name = labels[i+1];
      } else {
	 char buff[200];
	 sprintf(buff, _("item %d"), i + 1);
	 dataset->item[i].name = strdup(buff);
      }
   }

   if(dataset->item_count == 0) {
      free_dataset(dataset);
      print_parse_errors(dataset);
      return NULL;
   }

   time_t pd_l2 = time(0);
   if(!maxlines) printf(_c("  loading time: %ld seconds\n"), pd_l2 - pd_l1);

   ref_dataset(dataset);

   print_parse_errors(dataset);
   return dataset;
}

// return value documented in dataset.xh
int update_dataset(my_dataset_t *dataset) {
   // read more data from file

   struct stat st;
   if(stat(dataset->path_system, &st)) {
      perror(dataset->path_system);
      return 0;
   }

   if(st.st_size <= dataset->filepos) {
      if(st.st_size < dataset->filepos) {
	 printf(_c("File %s shrunk - update aborted\n"), dataset->path_system);
	 return 0;
      } else {
	 //printf("DEBUG: File %s same as before\n", dataset->path_system);
	 return 1;
      }
   }

   FILE *f = fopen(dataset->path_system, "rt");
   if(f == NULL) {
      perror(dataset->path_system);
      return 0;
   }

   if(fseek(f, dataset->filepos, SEEK_SET)) {
      perror(dataset->path_system);
      fclose(f);
      return 0;
   }

   char line[MAX_LINE_LEN];
   my_time_t timeoff = dataset->timeoff;
   boolean_t timestamp_base = dataset->timestamp_base;
   int idx = 0;

   while(1) {
      if(unlikely(!fgets(line, (int)sizeof(line), f))) {
	 dataset->filepos = ftell(f);
	 break;
      }

      // set_length complete line
      if(unlikely(!strchr(line, '\n'))) {
	 dataset->filepos = ftell(f) - strlen(line);
	 break;
      }

      parse_line(dataset, line, timeoff, timestamp_base);

      if(unlikely(!(idx % 5000))) {
	 if(system_check_events()) {
	    fclose(f);
	    return 0;
	 }
      }
      idx++;
   }

   dataset->te = dataset->time[dataset->time_count-1];

   fclose(f);

   // make sure all items have same amount of elements and insert labels
   int i;
   for(i=0; i<dataset->item_count; ++i) {
      my_data_arr_set_length(dataset->item[i].data, dataset->time_count);
   }

   if(dataset->item_count == 0) {
      return 0;
   }

   return 2;
}

my_dataset_t *read_dataset_preview(const char *cfile, int maxsamples) {
   FILE *f = fopen(cfile, "rt");
   if(f == NULL) return NULL;

   my_dataset_t *dataset = zmalloc_c(sizeof(my_dataset_t));

   dataset->item_dflt.min = INFINITY;
   dataset->item_dflt.max = -INFINITY;
   dataset->item_dflt.data_dflt = NAN;

   char *file = strdup(cfile);
   set_path_and_name(dataset, file);

   dataset->timetype = TIMETYPE_EPOCH;

   // get last modification time and assume that's also the time of the last entry
   struct stat st;
   if(stat(file, &st)) {
      perror(_c("read_dataset(): failed to stat file"));
   }

   dataset->last_modified = st.st_mtime * TIME_MULTIPLIER;

   char line[MAX_LINE_LEN];

   int i;
   for(i=0; i<maxsamples; ++i) {
      if(!fgets(line, (int)sizeof(line), f)) break;
      parse_line(dataset, line, 0LL, 0);
      int off = st.st_size / (maxsamples + 1) * i - ftell(f);
      if(off > 0)
	 fseek(f, (off_t)off, SEEK_CUR);

      // skip partial line
      if(!fgets(line, (int)sizeof(line), f)) break;
   }

   fclose(f);

   dataset->ts = dataset->time[0];
   dataset->te = dataset->time[dataset->time_count-1];
   dataset->maxdiff = dataset->te - dataset->ts;

   // make sure all items have same amount of elements
   for(i=0; i<dataset->item_count; ++i) {
      my_data_arr_set_length(dataset->item[i].data, dataset->time_count);
   }

   if(dataset->item_count == 0) {
      free_dataset(dataset);
      return NULL;
   }

   ref_dataset(dataset);

   return dataset;
}

/*
void add_dataset_listener(my_dataset_t *dataset, my_dataset_update_cb_t *cb, void *user_data) {

}

void remove_dataset_listener(my_dataset_t *dataset, my_dataset_update_cb_t *cb, void *user_data) {

}
*/

static void free_dataset(my_dataset_t *dataset) {
   int i;
   for(i=0; i<dataset->item_count; ++i) {
      my_data_arr_free(dataset->item[i].data);
      if(dataset->item[i].name) {
	 free(dataset->item[i].name);
      }
   }

   my_time_arr_free(dataset->time);
   my_dataset_item_arr_free(dataset->item);

   if (dataset->parse_errors) {
      free(dataset->parse_errors);
   }

   if(dataset->path_system) {
      free(dataset->path_system);
   }
   if(dataset->path_utf8) {
      free(dataset->path_utf8);
   }
   if(dataset->name) {
      free(dataset->name);
   }

   bzero(dataset, sizeof(*dataset));
   free(dataset);
}

void ref_dataset(my_dataset_t *dataset) {
   ++dataset->refcount;
}

int unref_dataset(my_dataset_t *dataset) {
   if(--dataset->refcount <= 0) {
      //printf("Freeing dataset %s\n", dataset->name);
      free_dataset(dataset);
      return 1;
   }
   return 0;
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
