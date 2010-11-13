#ifndef __xcpp_array_xh
#define __xcpp_array_xh
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
 * array - array functions with optional interpolating binary search
 * functionality
 */

#include <stdio.h>

#include "gnu_extensions.h"
#include "mem.h"
#include "stringutil.h"


#include "misc-util.h"
#include "plot-types.h"
#include "system.h"



#define ARRAY_DEFAULTTYPE_NONE 159000
#define ARRAY_DEFAULTTYPE_ZERO 159001
#define ARRAY_DEFAULTTYPE_CUSTOM 159002
#define ARRAY_DEFAULTTYPE_CUSTOM_MALLOC 159003

#define ARRAY_MAX_INC_CHUNK (8 * 1024 * 1024)


/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
#endif
