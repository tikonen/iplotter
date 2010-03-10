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
 * stringutil - misc functions for operating C strings
 */

//#define USE_STDLIB

#ifndef USE_STDLIB
#include <math.h>
#else
#include <stdlib.h>
#endif

#include "stringutil.xh"
#include "system.xh"

char *strnzdup(const char *p, size_t maxlen) {
   size_t len = strlen(p);
   if(len > maxlen) len = maxlen;
   char *new = (char *)malloc((size_t)(len + 1));
   if(!new) return NULL;
   memcpy(new, p, (size_t)len);
   new[len] = '\0';
   return new;
}

int chomp(char *p) {
   p += strlen(p) - 1;
   if(*p != '\n') return 0;
   *p = 0;
   return 1;
}

const char *skipws(const char *p) {
   while(my_isspace(*p)) p++;
   return p;
}

const char *skipnonws(const char *p) {
   while(*p && !my_isspace(*p)) p++;
   return p;
}

char *strip_comments(char *line) {
   char *comment = strchr(line, '#');
   if(comment) *comment = '\0';
   return line;
}

static inline int NUMBER(int c) { return c >= 0x30 && c <= 0x39; }

#define SAFE

#deftemplate parse_float_impl(TYPE)
TYPE parse_TYPE_num(const char **p) {
#ifndef USE_STDLIB
#if 0 // xkr47 v1
   TYPE data = 0;
   const char *q = *p;
   int neg;
   if(*q == '-') {
      neg = 1;
      q++;
   } else {
      if(*q == '+') q++;
      neg = 0;
   }

   for(; NUMBER(*q); ++q) {
      data *= 10;
      data += *q - '0';
   }

   if(*q == '.' || *q == ',') {
      int gotdot = 10;
      for(q++; NUMBER(*q); ++q) {
	 data += ((double)(*q - '0')) / gotdot;
	 gotdot *= 10;
      }
   }

   *p = q;
   if(neg) data = -data;
   return data;
#elif 1 // mokki v2
   /*
./parsetest 100000000 -123456789.987654321   4.520 total
./parsetest 100000000 123456789              2.336 total
./parsetest 100000000 -123456789             2.310 total
./parsetest 100000000 123.456                2.089 total
  */
   TYPE data;
   int64_t d = 0;
   const char *q = *p;
   char ch = *q++;
   int neg = 1;
   if (ch < '0') {
      neg = -1;
#ifdef SAFE
      if (ch != '-') {
	 return NAN;
      }
#endif
      ch = *q++;
   }

   do {
#ifdef SAFE
      if (ch > '9') {
	 return NAN;
      }
#endif
      ch -= '0';
      d = d * 10 + ch;
      ch = *q++;
   } while (ch >= '0');
   if(ch == '.') {
      data = d;
      ch = *q++;
      TYPE gotdot = 0.1;
      do {
#ifdef SAFE
	 if (ch > '9') {
	    return NAN;
	 }
#endif
	 ch -= '0';
	 data += ch * gotdot;
	 ch = *q++;
	 gotdot *= 0.1;
      } while (ch >= '0');
      data *= neg;
   } else {
      data = neg*d;
   }

   *p = q-1;
   return data;
#elif 1 // mokki v1
   TYPE data;
   int64_t d = 0;
   const char *q = *p;
   int neg = 1;
   if(*q == '-') {
      neg = -1;
      q++;
   }
   for(; NUMBER(*q); ++q) {
      d *= 10;
      d += *q - '0';
   }
   if(*q == '.' || *q == ',') {
      int decimals = 0;
      int64_t frac = 0;
      decimals = 0;
      for(++q; NUMBER(*q); ++q) {
	 frac *= 10;
	 frac += *q - '0';
	 decimals++;
      }
      data = neg*(d + frac/exp10((double)decimals));
   } else {
      data = neg*d;
   }
   *p = q;
   return data;
#endif
#else
   return (TYPE)strtod(*p, p);
#endif
}
#endtemplate

#template parse_float_impl(double)

#deftemplate parse_integer_impl(TYPE)
TYPE parse_TYPE_num(const char **p) {
#ifndef USE_STDLIB
   TYPE data = 0;
   const char *q = *p;
   int neg;
   if(*q == '-') {
      neg = 1;
      q++;
   } else {
      neg = 0;
   }

   for(; NUMBER(*q); ++q) {
      data *= 10;
      data += *q - '0';
   }
   *p = q;
   if(neg) data = -data;
   return data;
#else
   return (TYPE)strtol(*p, p, 10);
#endif
}
#endtemplate

#template parse_integer_impl(int)

#ifndef USE_GTK
/* GPL - Copied from gtk 2.4 */
const char *
strip_context  (const char *msgid,
		const char *msgval)
{
   if (msgval == msgid)
   {
      const char *c = strchr (msgid, '|');
      if (c != NULL)
	 return c + 1;
   }

   return msgval;
}
#endif

#ifdef ENABLE_NLS
#include <iconv.h>
#include <langinfo.h>
#include <stdio.h>
#include <errno.h>

static char *iconv_buff;
static size_t iconv_bufsz = 4096;
static iconv_t iconv_h;
static enum { IS_NONE, IS_OK, IS_FAILED } iconv_state;

#include "system.xh"

const char *utf8_to_console(const char *str) {
   switch(iconv_state) {
      case IS_NONE: {
	 iconv_buff = malloc(iconv_bufsz);

	 char *charset = nl_langinfo(CODESET);
	 iconv_h = iconv_open(charset, "UTF-8");
	 if(iconv_h == (iconv_t)-1) {
	    fprintf(stderr, "iconv failed, console output will be utf-8\n");
	    iconv_state = IS_FAILED;
	    return str;
	 }

	 // fall through
      }
      case IS_OK: {
	 while(1) {
	    size_t ib = strlen(str);
	    size_t ob = iconv_bufsz;
	    char *ip = (char*)str;
	    char *op = iconv_buff;
	    if(iconv(iconv_h, &ip, &ib, &op, &ob) == (size_t)-1) {
	       if(errno == E2BIG) {
		  iconv_bufsz *= 2;
		  iconv_buff = realloc(iconv_buff, iconv_bufsz);
		  continue;
	       }
	       perror("Problems converting");
	       return str;
	    }
	    *op = '\0';
	    return iconv_buff;
	 }
      }
      case IS_FAILED:
	 return str;
   }
   abort();
   return NULL;
}
#endif

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
