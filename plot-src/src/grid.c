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
 * grid - functions for calculating suitable gridline coordinates
 * given a range to be shown
 */

#include <math.h>

#include "grid.h"
#include "dataset.h"








#if 0
#define pprintf printf
#else
#define pprintf(...)
#endif

grid_t calc_gen_grid(double min, double max, int max_gridlines, int scalelength, int div, int lb, int *toff, int tofflen) {
   pprintf("calc_gen_grid: %lf - %lf mg %d sl %d div %d lb %d toff [", min, max, max_gridlines, scalelength, div, lb);
   int i;
   for(i=0; i<tofflen; ++i) {
      pprintf("%d,", toff[i]);
   }
   pprintf("]\n");
   if(lb != toff[tofflen-1]) {
      fprintf(stderr, "WARNING: lb != toff[tofflen-1] (%d != %d)\n", lb, toff[tofflen-1]);
   }

   if(min > max) {
      fprintf(stderr, "WARNING: min > max (%lf > %lf)\n", min, max);
      grid_t ret;
      ret.dvmin = 0;
      ret.dv    = 1;
      ret.dvmax = 1;
      ret.dmin  = 0;
      ret.d     = 1;
      ret.dmax  = 1;
      ret.minpermaj = 1;
      return ret;
   }

   double t = (max - min) / max_gridlines;

   double llb = log((double)lb);
   double dt = log(t / div) / llb;

   double dt2 = 0;
   int toi = 0;

   int a;
   for(a=0; a<tofflen; ++a) {
      double x = log(((double)lb) / toff[a]) / llb;
      double y = ceil(dt + x) - x;
      if(a == 0 || y < dt2) {
	 dt2 = y;
	 toi = a;
      }
   }
   grid_t ret;

   ret.dv = exp(dt2 * llb) * div;

   ret.dvmin = floor(min / ret.dv) * ret.dv;
   ret.dvmax = floor(max / ret.dv) * ret.dv;

   ret.dmin = (ret.dvmin - min) * scalelength / (max - min);
   ret.dmax = (ret.dvmax - min) * scalelength / (max - min);
   ret.d    = ret.dv            * scalelength / (max - min);

   ret.minpermaj = lb / toff[toi];

   while(ret.minpermaj > 5 && ret.minpermaj % 2 == 0) {
      ret.minpermaj /= 2;
   }
   if(ret.minpermaj <= 1) {
      if(ret.minpermaj < 1) {
	 fprintf(stderr, "BUG: minpermaj = %d\n", ret.minpermaj);
      }
      ret.minpermaj = 2;
   }

   pprintf("               %lf %lf %lf   %lf %lf %lf  %d\n", ret.dmin, ret.d, ret.dmax, ret.dvmin, ret.dv, ret.dvmax, ret.minpermaj);

   return ret;
}

grid_t calc_value_grid(double min, double max, int max_gridlines, int scalelength) {
   int toff[] = { 2, 5, 10 };
   return calc_gen_grid(min, max, max_gridlines, scalelength, 1, 10, toff, SZ(toff));
}

grid_t calc_log_value_grid(double min, double max, int max_gridlines, int scalelength) {
   double log_10 = log(10);
   min = log(min) / log_10;
   max = log(max) / log_10;
   int toff[] = { 2, 5, 10 };
   grid_t x = calc_gen_grid(min, max, max_gridlines, scalelength, 1, 10, toff, SZ(toff));
   x.dvmin = exp(x.dvmin * log_10);
   x.dvmax = exp(x.dvmax * log_10);
   return x;
}

// TODO since YEAR-MONTH or YEAR display doesn't work great, there is a workaround in plot_draw_grids.xc labeled "TODO remove when calc_time_grid fixed"
grid_t calc_time_grid(double min, double max, int max_gridlines, int scalelength) {
   double t = (max - min) / max_gridlines;

   if(t > 86400 * TIME_MULTIPLIER * 3 / 4) {
      int toff[] = { 2, 5, 10 };
      return calc_gen_grid(min, max, max_gridlines, scalelength, (int)(86400 * TIME_MULTIPLIER), 10, toff, SZ(toff));

   } else if(t > 3600 * TIME_MULTIPLIER * 3 / 4) {
      int toff[] = { 2, 4, 6, 8, 12, 24 };
      return calc_gen_grid(min, max, max_gridlines, scalelength, (int)(3600 * TIME_MULTIPLIER), 24, toff, SZ(toff));

   } else if(t > TIME_MULTIPLIER * 3 / 4) {
      int toff[] = { 2, 5, 10, 15, 20, 30, 60 };
      return calc_gen_grid(min, max, max_gridlines, scalelength, (int)TIME_MULTIPLIER, 60, toff, SZ(toff));

   } else if(t >= 1) {
      int toff[] = { 2, 5, 10 };
      return calc_gen_grid(min, max, max_gridlines, scalelength, 1, 10, toff, SZ(toff));

   } else {
      int toff[] = { 2, 5, 10 };
      return calc_gen_grid(min, max, (int)ceil(max - min), scalelength, 1, 10, toff, SZ(toff));
   }
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
