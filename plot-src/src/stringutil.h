#ifndef __xcpp_stringutil_xh
#define __xcpp_stringutil_xh
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

#include <string.h>

#include "mem.h"
#include "gnu_extensions.h"

static inline int my_isspace(int c) { return c == ' ' || c == '\n' || c == '\r' || c == '\t'; }

MALLOC static inline char *my_strdup(const char *str) {
   size_t l = strlen(str) + 1;
   char *data = malloc(l);
   memcpy(data, str, l);
   return data;
}

#ifdef strdup
#undef strdup
#endif
#define strdup my_strdup

char *strnzdup(const char *p, size_t maxlen);

int chomp(char *p);

WARN_UNUSED_RESULT const char *skipws(const char *p);
WARN_UNUSED_RESULT const char *skipnonws(const char *p);
char *strip_comments(char *line);


double parse_double_num(const char **p);


int parse_int_num(const char **p);

// memmset

//#define MOKKI_V2 // TODO profile

static inline void *memmset_int(void *p, const void *d, size_t dsize, int count) {

#if 0 // xkr v1
   char *pp = p;
   while(count--) {
      memcpy(pp, d, dsize);
      pp += dsize;
   }
#else // mokki v1
   if (unlikely(count <= 0)) {
      return p;
   }
   memcpy(p, d, dsize);
   count--;
   size_t remaining = count * dsize;
   char *pp = p;
   pp += dsize;
   while (remaining > 0) {
      if (dsize > remaining) {
	 dsize = remaining;
      }
      memcpy(pp, p, dsize);
      pp += dsize;
      remaining -= dsize;
      dsize *= 2;
   }
#endif
   return p;
}

#ifdef MOKKI_V2

static inline void *memmset_4(void *p, const void *d, int count) {
   const int32_t *dd = (const int32_t *)d;
   int32_t v1 = dd[0];
   int32_t *pd = (int32_t *)p;
   do {
      *pd = v1;
      pd++;
   } while (--count);
   return p;
}

static inline void *memmset_8(void *p, const void *d, int count) {
   const int64_t *dd = (const int64_t *)d;
   int64_t v1 = dd[0];
   int64_t *pd = (int64_t *)p;
   do {
      *pd = v1;
      pd++;
   } while (--count);
   return p;
}

static inline void *memmset(void *p, const void *d, size_t dsize, int count) {
   if (unlikely(count <= 0)) {
      return p;
   }
   if (dsize == 4) {
      memmset_4(p, d, count);
   } else if (dsize == 8) {
      memmset_8(p, d, count);
   } else {
      memmset_int(p, d, dsize, count);
   }
}

#else

#define memmset memmset_int

#endif


#ifdef USE_GTK
#define strip_context g_strip_context
#else
CONST const char *strip_context(const char *msgid, const char *msgval);
#endif

#ifdef ENABLE_NLS
CONST const char *utf8_to_console(const char *str);
#else
#define utf8_to_console(x) (x)
#endif

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
#endif
