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
 * util - misc functions
 */

#include <time.h>
#include <stdio.h>
#include <string.h>

#include "stringutil.xh"
#include "system.xh"
#include "misc-util.xh"

my_time_t time_field_length[] = {
   TIME_MULTIPLIER / 1000,
   TIME_MULTIPLIER / 100,
   TIME_MULTIPLIER / 10,
   TIME_MULTIPLIER,
   60 * TIME_MULTIPLIER,
   3600 * TIME_MULTIPLIER,
   86400 * TIME_MULTIPLIER,
   28 * 86400 * TIME_MULTIPLIER,
   365 * 86400 * TIME_MULTIPLIER,
};

time_field_t time_diff_field(my_time_t time) {
   if(SZ(time_field_length) - 1 != TIME_FIELD_YEAR) {
      fprintf(stderr, "Bug in time_field_length\n");
      exit(1);
   }

   if(time >= 365 * 86400 * TIME_MULTIPLIER) {
      return TIME_FIELD_YEAR;
   } else if(time >= 28 * 86400 * TIME_MULTIPLIER) {
      return TIME_FIELD_MONTH;
   } else if(time >= 86400 * TIME_MULTIPLIER) {
      return TIME_FIELD_DAY;
   } else if(time >= 3600 * TIME_MULTIPLIER) {
      return TIME_FIELD_HOUR;
   } else if(time >= 60 * TIME_MULTIPLIER) {
      return TIME_FIELD_MIN;
   } else if(time >= TIME_MULTIPLIER) {
      return TIME_FIELD_SEC;
   } else if(time >= TIME_MULTIPLIER / 10) {
      return TIME_FIELD_DECISEC;
   } else if(time >= TIME_MULTIPLIER / 100) {
      return TIME_FIELD_CENTISEC;
   } else {
      return TIME_FIELD_MILLISEC;
   }
}

time_field_t time_diff_field2(my_time_t time1, my_time_t time2) {
   if(time1 / (86400 * TIME_MULTIPLIER) != time2 / (86400 * TIME_MULTIPLIER)) {
      return TIME_FIELD_YEAR;
   } else if(time1 / (3600 * TIME_MULTIPLIER) != time2 / (3600 * TIME_MULTIPLIER)) {
      return TIME_FIELD_HOUR;
   } else if(time1 / (60 * TIME_MULTIPLIER) != time2 / (60 * TIME_MULTIPLIER)) {
      return TIME_FIELD_MIN;
   } else if(time1 / TIME_MULTIPLIER != time2 / TIME_MULTIPLIER) {
      return TIME_FIELD_SEC;
   } else if(time1 / (TIME_MULTIPLIER / 10) != time2 / (TIME_MULTIPLIER / 10)) {
      return TIME_FIELD_DECISEC;
   } else if(time1 / (TIME_MULTIPLIER / 100) != time2 / (TIME_MULTIPLIER / 100)) {
      return TIME_FIELD_CENTISEC;
   } else {
      return TIME_FIELD_MILLISEC;
   }
}

const char *format_time2(my_time_t time, time_field_t min_field, time_field_t max_field) {
   static char buff[8+1+2+1+2 +1+ 2+1+2+1+2 +1+ 3 +1];
   if(min_field > max_field) {
      buff[0] = '\0';
      return buff;
   }

   char formatbuff[40];
   char *fbp = formatbuff;

   if(max_field > TIME_FIELD_SEC) {
      switch(max_field) {
	 case TIME_FIELD_YEAR:
	    *fbp++ = '%'; *fbp++ = 'Y';
	    if(min_field == TIME_FIELD_YEAR) break;
	    *fbp++ = '-';
	    // fall thorugh
	 case TIME_FIELD_MONTH:
	    *fbp++ = '%'; *fbp++ = 'm';
	    if(min_field == TIME_FIELD_MONTH) break;
	    *fbp++ = '-';
	    // fall thorugh
	 case TIME_FIELD_DAY:
	    *fbp++ = '%'; *fbp++ = 'd';
	    if(min_field == TIME_FIELD_DAY) break;
	    *fbp++ = ' ';
	    // fall thorugh
	 case TIME_FIELD_HOUR:
	    *fbp++ = '%'; *fbp++ = 'H';
	    if(min_field == TIME_FIELD_HOUR) break;
	    *fbp++ = ':';
	    // fall thorugh
	 case TIME_FIELD_MIN:
	    *fbp++ = '%'; *fbp++ = 'M';
	    if(min_field == TIME_FIELD_MIN) break;
	    *fbp++ = ':';

	    // the TIME_FIELD_SEC is handled separately, see else below
	    *fbp++ = '%'; *fbp++ = 'S';
	    if(min_field == TIME_FIELD_SEC) break;
	    *fbp++ = '.';
	    break;
	 default:
	    fprintf(stderr, "bug: max_field = %d\n", max_field);
	    break;
      }
      *fbp = '\0';

      time_t t = (time_t)(time / TIME_MULTIPLIER);
      struct tm *lt = localtime(&t);
      if(!strftime(buff, sizeof(buff), formatbuff, lt)) return "format_time error";

   } else { // if(max_field > TIME_FIELD_SEC)

      snprintf(buff, sizeof(buff), "%d", (int)(time / TIME_MULTIPLIER) % 60);
      if(min_field < TIME_FIELD_SEC) {
	 strcat(buff, ".");
      }
   }

   if(min_field < TIME_FIELD_SEC) {
      char *p = buff + strlen(buff);
      switch(min_field) {
	 case TIME_FIELD_DECISEC:
	    snprintf(p, (size_t)(buff + sizeof(buff) - p), "%d", (int)((time % TIME_MULTIPLIER) * 10 / TIME_MULTIPLIER));
	    break;
	 case TIME_FIELD_CENTISEC:
	    snprintf(p, (size_t)(buff + sizeof(buff) - p), "%02d", (int)((time % TIME_MULTIPLIER) * 100 / TIME_MULTIPLIER));
	    break;
	 case TIME_FIELD_MILLISEC:
	    snprintf(p, (size_t)(buff + sizeof(buff) - p), "%03d", (int)((time % TIME_MULTIPLIER) * 1000 / TIME_MULTIPLIER));
	    break;
	 default:
	    fprintf(stderr, "bug: min_field = %d\n", min_field);
	    break;
      }
   }
   return buff;
}

const char *format_time(my_time_t time, int include_millis) {
   static char buff[4+1+2+1+2 +1+ 2+1+2+1+2 +1+ 3    +1+ 14  +1];
   time_t t = (time_t)(time / TIME_MULTIPLIER);
   struct tm *lt = localtime(&t);
   if(!strftime(buff, sizeof(buff), "%F %T", lt)) return "format_time error";
   if(include_millis) {
      char *p = buff + strlen(buff);
      snprintf(p, (size_t)(buff + sizeof(buff) - p), ".%03d", (int)((time % TIME_MULTIPLIER) * 1000 / TIME_MULTIPLIER));
   }
// snprintf(p, (size_t)(buff + sizeof(buff) - p), ".%03d %10d.%03d", (int)((time % TIME_MULTIPLIER) * 1000 / TIME_MULTIPLIER), (int)(time / TIME_MULTIPLIER), (int)((time % TIME_MULTIPLIER) * 1000 / TIME_MULTIPLIER));
   return buff;
}

const char *format_difftime2(my_time_t time, time_field_t min_field, time_field_t max_field) {
   static char buff[6 +1+ 30 +1+ 2+1+2+1+2 +1+ 3 +1];
   time_t tm = (time_t)(time / TIME_MULTIPLIER);
   int sec = tm % 60; tm /= 60;
   int min = tm % 60; tm /= 60;
   int hour = tm % 24; tm /= 24;
   char formatbuff[40];
   char *fbp = formatbuff;

   if(min_field > max_field) {
      buff[0] = '\0';
      return buff;
   }

   int millisMult = 0;
   boolean_t got = 0;

   switch(max_field) {
      case TIME_FIELD_YEAR:
      case TIME_FIELD_MONTH:
      case TIME_FIELD_DAY:
	 *fbp++ = '%'; *fbp++ = '1'; *fbp++ = '$'; *fbp++ = 'd'; *fbp++ = 'd';
	 if(min_field == TIME_FIELD_DAY) break;
	 *fbp++ = ' ';
	 got = 1;
	 // fall thorugh
      case TIME_FIELD_HOUR:
	 *fbp++ = '%'; *fbp++ = '2'; *fbp++ = '$'; if(got) *fbp++ = '0'; *fbp++ = '2'; *fbp++ = 'd';
	 if(min_field == TIME_FIELD_HOUR) break;
	 *fbp++ = ':';
	 got = 1;
	 // fall thorugh
      case TIME_FIELD_MIN:
	 *fbp++ = '%'; *fbp++ = '3'; *fbp++ = '$'; if(got) *fbp++ = '0'; *fbp++ = '2'; *fbp++ = 'd';
	 if(min_field == TIME_FIELD_MIN) break;
	 *fbp++ = ':';
	 got = 1;
	 // fall thorugh
      case TIME_FIELD_SEC:
      case TIME_FIELD_DECISEC:
      case TIME_FIELD_CENTISEC:
      case TIME_FIELD_MILLISEC:
	 *fbp++ = '%'; *fbp++ = '4'; *fbp++ = '$'; if(got) *fbp++ = '0'; *fbp++ = '2'; *fbp++ = 'd';
	 if(min_field == TIME_FIELD_SEC) break;
	 *fbp++ = '.';
	 switch(min_field) {
	    case TIME_FIELD_DECISEC:
	       *fbp++ = '%'; *fbp++ = '5'; *fbp++ = '$'; *fbp++ = 'd';
	       millisMult = 10;
	       break;
	    case TIME_FIELD_CENTISEC:
	       *fbp++ = '%'; *fbp++ = '5'; *fbp++ = '$'; *fbp++ = '0'; *fbp++ = '2'; *fbp++ = 'd';
	       millisMult = 100;
	       break;
	    case TIME_FIELD_MILLISEC:
	       *fbp++ = '%'; *fbp++ = '5'; *fbp++ = '$'; *fbp++ = '0'; *fbp++ = '3'; *fbp++ = 'd';
	       millisMult = 1000;
	       break;
	    default:
	       fprintf(stderr, "bug: min_field = %d\n", min_field);
	       break;
	 }
	 break;
      default:
	 fprintf(stderr, "bug: max_field = %d\n", max_field);
	 break;
   }
   *fbp = '\0';

   snprintf(buff, sizeof(buff), formatbuff, tm, hour, min, sec, (int)((time % TIME_MULTIPLIER) * millisMult / TIME_MULTIPLIER));
   return buff;
}

const char *format_difftime(my_time_t time, int include_millis) {
   static char buff[6 +1+ 30 +1+ 2+1+2+1+2 +1+ 3 +1];
   time_t tm = (time_t)(time / TIME_MULTIPLIER);
   int sec = tm % 60; tm /= 60;
   int min = tm % 60; tm /= 60;
   int hour = tm % 24; tm /= 24;
   // TODO gettext plural form or maybe not needed now that days -> d
   snprintf(buff, sizeof(buff), _("%dd %02d:%02d:%02d"),
	    (int)tm, hour, min, sec);
   if(include_millis) {
      char *p = buff + strlen(buff);
      snprintf(p, (size_t)(buff + sizeof(buff) - p), ".%03d", (int)((time % TIME_MULTIPLIER) * 1000 / TIME_MULTIPLIER));
   }
   return buff;
}

char *fgets_strip_comments(char *s, int size, FILE *stream) {
   char *line = fgets(s, size, stream);
   if(!line) return line;
   return strip_comments(line);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
