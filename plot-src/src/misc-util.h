#ifndef __xcpp_misc_util_xh
#define __xcpp_misc_util_xh
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

#include "dataset-types.h"

typedef enum {
   TIME_FIELD_MILLISEC,
   TIME_FIELD_CENTISEC,
   TIME_FIELD_DECISEC,
   TIME_FIELD_SEC,
   TIME_FIELD_MIN,
   TIME_FIELD_HOUR,
   TIME_FIELD_DAY,
   TIME_FIELD_MONTH,
   TIME_FIELD_YEAR,
} time_field_t;

extern my_time_t time_field_length[];

time_field_t time_diff_field(my_time_t time); // 23:59:59.999 -> TIME_FIELD_HOUR, 24:00:00.000 -> TIME_FIELD_DAY
time_field_t time_diff_field2(my_time_t time1, my_time_t time2);

const char *format_time2(my_time_t time, time_field_t min_field, time_field_t max_field);
const char *format_time(my_time_t time, int include_millis);
const char *format_difftime2(my_time_t time, time_field_t min_field, time_field_t max_field);
const char *format_difftime(my_time_t time, int include_millis);

char *fgets_strip_comments(char *s, int size, FILE *stream);

#define SZ(a) ((int)(sizeof(a)/sizeof(a[0])))

static inline int32_t max(int32_t a, int32_t b) {
   return a > b ? a : b;
}

static inline int32_t min(int32_t a, int32_t b) {
   return a < b ? a : b;
}

static inline int64_t maxll(int64_t a, int64_t b) {
   return a > b ? a : b;
}

static inline int64_t minll(int64_t a, int64_t b) {
   return a < b ? a : b;
}

static inline int floor_div(int value, int divisor) {
   return value - value % divisor;
}

static inline int ceil_div(int value, int divisor) {
#if 0 // xkr v1
   return ((value - 1) / divisor + 1) * divisor;
#elif 0 // xkr v2
   return ((value - 1) / divisor) * divisor + divisor;
#else // xkr v3
   --value; return value - value % divisor + divisor;
#endif
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
#endif
