#ifndef __xcpp_dataset_types_xh
#define __xcpp_dataset_types_xh
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
 * dataset-types - types used by dataset
 */

#include <inttypes.h>

#define TIME_MULTIPLIER 1000LL // how many my_time_t units per second

// base time unit, see TIME_MULTIPLIER above
typedef int64_t my_time_t;
typedef float my_data_t; // if changed to double, please change FLT_ in MY_DATA_T_INFO(SUF) macro to DBL_

// this is used to dig out constants such as FLT_DIG and FLT_EPSILON
#define MY_DATA_T_INFO(suffix) FLT_ ## suffix

#define PRIdMYTIME PRId64

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
#endif
