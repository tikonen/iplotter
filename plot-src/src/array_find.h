#ifndef __xcpp_array_find_xh
#define __xcpp_array_find_xh
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
 * array_find - interpolating array binary search
 */

#include <stdio.h>

typedef enum {
   // all examples below assume the array contains the values 1, 2, 6, 9.

   AFB_LEFT_OR_MATCH,
   // if looking for 0 it will return the index of 1 (= 0)
   // if looking for 2 it will return the index of 2 (= 1)
   // if looking for 4 it will return the index of 2 (= 1)
   // if looking for 10 it will return the index of 9 (= 3)

   AFB_RIGHT_OR_MATCH,
   // if looking for 0 it will return the index of 1 (= 0)
   // if looking for 2 it will return the index of 2 (= 1)
   // if looking for 4 it will return the index of 6 (= 2)
   // if looking for 10 it will return the index of 9 (= 3)

   AFB_RIGHT_OR_MATCH_OVER,
   // if looking for 0 it will return the index of 1 (= 0)
   // if looking for 2 it will return the index of 2 (= 1)
   // if looking for 4 it will return the index of 6 (= 2)
   // if looking for 10 it will return the index of 9 + 1 (= 4)

} array_find_behaviour_t;


/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
#endif
