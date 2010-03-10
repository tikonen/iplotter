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
 * plot_draw_grids - handles the drawing of the grids of a plot
 */

#include "plot_draw.xh"
#include "grid.xh"

#include <math.h>

#if 0
#define pprintf printf
#else
#define pprintf(...)
#endif

static const char major_dashes[] = { 2, 2 };
static const char minor_dashes[] = { 1, 3 };

void plot_draw_value_grid(my_plot_draw_t *plot) {

   pprintf("y %lf %lf\n", plot->ymin, plot->ymax);

   grid_t value_grid = calc_value_grid(plot->ymin, plot->ymax, plot->plot_yde / (20 + 2 * plot->font_height), plot->plot_yde + 1);

   pprintf("%lf %lf %lf %lf %lf %lf %d\n", value_grid.dmin, value_grid.d, value_grid.dmax, value_grid.dvmin, value_grid.dv, value_grid.dvmax, value_grid.minpermaj);

   double xlength = plot->xmax - plot->xmin;
   int doff = (int)(plot->xmin * plot->plot_xe / xlength);
   plot->paintapi->gc_set_dashes(plot->paintapi, plot->grid.minor_gc, doff, minor_dashes, SZ(minor_dashes));
   plot->paintapi->gc_set_dashes(plot->paintapi, plot->grid.major_gc, doff, major_dashes, SZ(major_dashes));
   plot->paintapi->gc_set_dashes(plot->paintapi, plot->grid.zerogrid_gc, doff, major_dashes, SZ(major_dashes));

   // how many decimals to display
   int decimals = (int)-floor(log10(value_grid.dv) + 0.05); // 0.05 is for rounding erros
   if(decimals < 0) decimals = 0;

   plot->value_axis_width = 0;

   // draw text labels
   double yo,yvo;
   for(yo = value_grid.dmin, yvo = value_grid.dvmin; yo < value_grid.dmax + value_grid.d; yo += value_grid.d, yvo += value_grid.dv) {
      int y = plot->plot_yde - (int)yo;

      char tmp[30];
      snprintf(tmp, sizeof(tmp), "%.*lf", decimals, yvo);
      if(fabs(yvo / value_grid.dv) < 1e-10) {
	 snprintf(tmp, sizeof(tmp), "%.*lf", decimals, 0.0); // to avoid -0.0
      }

      paintapi_textlayout_t *layout = plot->paintapi->textlayout_create(plot->paintapi, plot->grid.font_yaxis, tmp);

      paintapi_textlayout_extents_t ri;
      plot->paintapi->textlayout_calculate_size(plot->paintapi, layout, &ri);
      plot->value_axis_width = max(plot->value_axis_width, ri.xr - ri.xl + 1);

      plot->paintapi->draw_textlayout(plot->paintapi, plot->grid.label_gc, 0, y + 1 + (ri.yb - ri.yt) / 4 - ri.yt, layout);
      plot->paintapi->textlayout_free(plot->paintapi, layout);
   }

   // draw the lines separately to allow for paintapi gc optimizations
   for(yo = value_grid.dmin, yvo = value_grid.dvmin; yo < value_grid.dmax + value_grid.d; yo += value_grid.d, yvo += value_grid.dv) {
      if(yo < 0 || yo > plot->plot_yde) continue;
      int y = plot->plot_yde - (int)yo;

      // TODO maybe plot minor & major separately for further osx optimizations?

      paintapi_gc_t *gc;
      if(fabs(yvo / value_grid.dv) < 1e-10) {
	 gc = plot->grid.zerogrid_gc;
      } else if(((int)(round(yvo / value_grid.dv))) % value_grid.minpermaj == 0) {
	 gc = plot->grid.major_gc;
      } else {
	 gc = plot->grid.minor_gc;
      }

      plot->paintapi->draw_line(plot->paintapi, gc, 0, y, plot->plot_xe, y);
   }
}

void plot_draw_grid_precalc(my_plot_draw_t *plot) {

   pprintf("x %lf %lf\n", plot->xmin, plot->xmax);

   plot->tmp.max_diff_field = time_diff_field(plot->xend - plot->xstart);
   plot->tmp.min_diff_field = TIME_FIELD_MILLISEC;

   if(plot->tmp.max_diff_field == TIME_FIELD_MILLISEC) plot->tmp.max_diff_field = TIME_FIELD_SEC;
   if(plot->tmp.max_diff_field == TIME_FIELD_MIN) plot->tmp.max_diff_field = TIME_FIELD_HOUR;
   if(plot->tmp.max_diff_field == TIME_FIELD_MONTH) plot->tmp.max_diff_field = TIME_FIELD_YEAR;

   paintapi_textlayout_extents_t ri;

   // determine optimal time grid with a few iterations
   double min = plot->xmin - plot->time_off;
   for(; plot->tmp.min_diff_field < plot->tmp.max_diff_field; plot->tmp.min_diff_field++) {
      if(plot->tmp.min_diff_field == TIME_FIELD_HOUR) plot->tmp.min_diff_field = TIME_FIELD_DAY;

      //printf("%d %d\n", plot->tmp.min_diff_field, plot->tmp.max_diff_field);

      const char *example_time;
      if(plot->time_off) {
	 example_time = format_difftime2((my_time_t)round(min), plot->tmp.min_diff_field, plot->tmp.max_diff_field);
      } else {
	 example_time = format_time2((my_time_t)round(min), plot->tmp.min_diff_field, plot->tmp.max_diff_field);
      }
      //printf("-- %s --\n", example_time);

      paintapi_textlayout_t *layout = plot->paintapi->textlayout_create(plot->paintapi, plot->grid.font_xaxis, example_time);
      plot->paintapi->textlayout_calculate_size(plot->paintapi, layout, &ri);
      plot->paintapi->textlayout_free(plot->paintapi, layout);

      //printf("%d,%d %d,%d '%s'\n", ri.xl, ri.yt, ri.xr, ri.yb, example_time);

      plot->time_stamp_width = ri.xr-ri.xl+1;

      //printf(" tsw %d\n", plot->time_stamp_width);

      //printf("tsw %s %d\n", example_time, plot->time_stamp_width);
      //printf("%d\n", (int)(plot->plot_xe / (plot->time_stamp_width * (1.3 / 2))));

      int maxgrid = (int)(plot->plot_xe / (plot->time_stamp_width * (1.3 / 2)));
      if(maxgrid <= 0) {
	 continue;
      }
      double dxmin = plot->xmin - plot->time_off;
      double dxmax = plot->xmax - plot->time_off;
      plot->tmp.time_grid = calc_time_grid(dxmin, dxmax, maxgrid, plot->plot_xe + 1);

      min = plot->tmp.time_grid.dvmin;

      pprintf("%lf %lf %lf %lf %lf %lf %d\n", plot->tmp.time_grid.dmin, plot->tmp.time_grid.d, plot->tmp.time_grid.dmax, plot->tmp.time_grid.dvmin, plot->tmp.time_grid.dv, plot->tmp.time_grid.dvmax, plot->tmp.time_grid.minpermaj);

      time_field_t resulting_min_diff_field = time_diff_field((my_time_t)(plot->tmp.time_grid.dv * (1 + 1e-10)));

      if(resulting_min_diff_field == TIME_FIELD_HOUR) resulting_min_diff_field = TIME_FIELD_MIN;
      if(resulting_min_diff_field == TIME_FIELD_MONTH || resulting_min_diff_field == TIME_FIELD_YEAR) resulting_min_diff_field = TIME_FIELD_DAY; // TODO remove when calc_time_grid fixed

      //printf("pass %d - %d\n", resulting_min_diff_field, plot->tmp.min_diff_field);

      if(resulting_min_diff_field <= plot->tmp.min_diff_field) {
	 if(resulting_min_diff_field < plot->tmp.min_diff_field) {

	    plot->tmp.time_grid = calc_time_grid(dxmin, dxmax,
						 (int)((plot->xmax - plot->xmin) / (time_field_length[plot->tmp.min_diff_field] * (1.3 / 2))),
						 plot->plot_xe + 1);

	    resulting_min_diff_field = time_diff_field((my_time_t)(plot->tmp.time_grid.dv * (1 + 1e-10)));
	    //printf("updated %d / %d\n", resulting_min_diff_field, plot->tmp.min_diff_field);
	    pprintf("%lf %lf %lf %lf %lf %lf %d\n", plot->tmp.time_grid.dmin, plot->tmp.time_grid.d, plot->tmp.time_grid.dmax, plot->tmp.time_grid.dvmin, plot->tmp.time_grid.dv, plot->tmp.time_grid.dvmax, plot->tmp.time_grid.minpermaj);
	 }
	 break;
      }
   }

   //printf("--> minmax %d %d\n", plot->tmp.min_diff_field, plot->tmp.max_diff_field);

   ////

   int font_h = ri.yb - ri.yt + 1;

   plot->font_height = font_h;
   plot->plot_yde = plot->plot_ye - (2 + font_h * 2.3);
}

void plot_draw_time_grid(my_plot_draw_t *plot) {
   plot->paintapi->draw_line(plot->paintapi, plot->grid.sep_gc, 0, plot->plot_yde+1, plot->plot_xe, plot->plot_yde+1);

   // set dash offsets
   double ylength = plot->ymax - plot->ymin;
   int doff = -(int)(plot->ymin * plot->plot_yde / ylength);
   plot->paintapi->gc_set_dashes(plot->paintapi, plot->grid.major_gc, doff, major_dashes, SZ(major_dashes));
   plot->paintapi->gc_set_dashes(plot->paintapi, plot->grid.minor_gc, doff, minor_dashes, SZ(minor_dashes));
   plot->paintapi->gc_set_dashes(plot->paintapi, plot->grid.zerogrid_gc, doff, major_dashes, SZ(major_dashes));

   // draw text labels
   int odd = ((int)round(plot->tmp.time_grid.dvmin / plot->tmp.time_grid.dv)) % 2;
   double xo,xvo;
   int *ys = malloc(sizeof(int) * (int)((plot->tmp.time_grid.dmax - plot->tmp.time_grid.dmin) / plot->tmp.time_grid.d + 4));
   int yc = 0;

   //printf(" got           %lf %lf %lf   %lf %lf %lf  %d\n", plot->tmp.time_grid.dmin, plot->tmp.time_grid.d, plot->tmp.time_grid.dmax, plot->tmp.time_grid.dvmin, plot->tmp.time_grid.dv, plot->tmp.time_grid.dvmax, plot->tmp.time_grid.minpermaj);

   //printf("---- %.20lf\n", plot->tmp.time_grid.d);
   for(xo = plot->tmp.time_grid.dmin, xvo = plot->tmp.time_grid.dvmin; xo < plot->tmp.time_grid.dmax + plot->tmp.time_grid.d; xo += plot->tmp.time_grid.d, xvo += plot->tmp.time_grid.dv) {
      odd = !odd;
      int x = (int)xo;

      // printf(" - %lf\n", xo);

      const char *text;
      if(plot->time_off) {
	 // times are already diffed - calc_time_grid() was called with diffed values
	 text = format_difftime2((my_time_t)round(xvo), plot->tmp.min_diff_field, plot->tmp.max_diff_field);
      } else {
	 text = format_time2((my_time_t)round(xvo), plot->tmp.min_diff_field, plot->tmp.max_diff_field);
      }

      paintapi_textlayout_t *layout = plot->paintapi->textlayout_create(plot->paintapi, plot->grid.font_xaxis, text);

      paintapi_textlayout_extents_t ri;
      plot->paintapi->textlayout_calculate_size(plot->paintapi, layout, &ri);

      int y = plot->plot_yde + 1 + 2 + (int)(plot->font_height * (odd ? 0.15 : 1.3));
      ys[yc++] = y - 2;

      plot->paintapi->draw_textlayout(plot->paintapi, plot->grid.label_gc, x - (ri.xr-ri.xl+1)/2, y - ri.yt, layout);

      plot->paintapi->textlayout_free(plot->paintapi, layout);
   }

   // draw the lines separately to allow for paintapi gc optimizations
   yc = 0;
   for(xo = plot->tmp.time_grid.dmin, xvo = plot->tmp.time_grid.dvmin; xo < plot->tmp.time_grid.dmax + plot->tmp.time_grid.d; xo += plot->tmp.time_grid.d, xvo += plot->tmp.time_grid.dv) {
      int x = (int)xo;
      int y = ys[yc++];

      // TODO maybe plot minor & major separately for further osx optimizations?

      paintapi_gc_t *gc = fabs(xvo / plot->tmp.time_grid.dv) < 1e-10 ?
			  plot->grid.zerogrid_gc :
                          ((int)round(xvo / plot->tmp.time_grid.dv)) % plot->tmp.time_grid.minpermaj == 0 ? plot->grid.major_gc : plot->grid.minor_gc;

      plot->paintapi->draw_line(plot->paintapi, gc, x, 0, x, y);
   }

   free(ys);
}


void plot_draw_init_grids(my_plot_draw_t *plot) {
}

void plot_draw_deinit_grids(my_plot_draw_t *plot) {
}

void plot_draw_clone_grids(my_plot_draw_t *n, my_plot_draw_t *o) {
   n->grid.minor_color = o->grid.minor_color;
   n->grid.major_color = o->grid.major_color;
   n->grid.zerogrid_color = o->grid.zerogrid_color;

   n->grid.sep_color = o->grid.sep_color;

   n->grid.label_color = o->grid.label_color;
}

void plot_draw_setup_grid_gcs(my_plot_draw_t *plot) {
   plot->grid.minor_gc = gc_new_with_color(plot, plot->grid.minor_color);
   plot->grid.major_gc = gc_new_with_color(plot, plot->grid.major_color);
   plot->grid.zerogrid_gc = gc_new_with_color(plot, plot->grid.zerogrid_color);

   plot->grid.sep_gc = gc_new_with_color(plot, plot->grid.sep_color);

   plot->grid.label_gc = gc_new_with_color(plot, plot->grid.label_color);
}

void plot_draw_reset_grid_gcs(my_plot_draw_t *plot) {
   gc_free_and_zero(plot->grid.minor_gc);
   gc_free_and_zero(plot->grid.major_gc);
   gc_free_and_zero(plot->grid.zerogrid_gc);

   gc_free_and_zero(plot->grid.sep_gc);

   gc_free_and_zero(plot->grid.label_gc);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
