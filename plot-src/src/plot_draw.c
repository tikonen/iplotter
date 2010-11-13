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
 * plot_draw - handles the drawing of a plot
 */

#include <math.h>
#include <sys/time.h>

#include "plot_draw.h"











#if 0
#define pprintf printf
#else
#define pprintf(...)
#endif

void *gc_new_with_color(my_plot_draw_t *plot, paintapi_rgb_t color) {
   void *gc = plot->paintapi->gc_new(plot->paintapi);
   plot->paintapi->gc_set_foreground(plot->paintapi, gc, &color);
   return gc;
}

void plot_draw(my_plot_draw_t *plot) {
   // check settings
   if(unlikely(plot->plot_xe<=0 || plot->plot_ye<=0 || !plot->paintapi || plot->samples_per_pixel<=0)) {
      fprintf(stderr, _c("You have not set up my_plot_draw_t correctly!\n"
			 "See plot_draw() in plot_draw.xc and comments in plot_draw.xh for help. Asserts and (values):\n"
			 "\tplot->plot_xe>0 (%d)\n"
			 "\tplot->plot_ye>0 (%d)\n"
			 "\tplot->paintapi (%p)\n"
			 "\tplot->samples_per_pixel>0 (%lf)\n"),
	      plot->plot_xe,
	      plot->plot_ye,
	      plot->paintapi,
	      plot->samples_per_pixel);
      return;
   }

   struct timeval start;
   gettimeofday(&start, 0);

   // setup gc
   plot_draw_setup_gcs(plot);

   // my $queued = 0;

   //    gtk_main_iteration() while(gtk_events_pending());
   //    if($mytrans != plot->dsc_x->{num_changes}) {
   //	print "- $mytrans plot->dsc_x->{num_changes}\n";
   //#	    $da->queue_draw() unless($queued++);
   //	$conc--; return;
   //    }

   plot_draw_grid_precalc(plot);

   plot_draw_logo(plot);

   if(system_check_events()) return;

   plot_draw_lines(plot);

   if(system_check_events()) return;

   plot_draw_time_grid(plot);

   plot_draw_value_grid(plot);

   if(system_check_events()) return;

   plot_draw_bookmarks(plot);

   if(system_check_events()) return;

   plot_draw_legend(plot);

   struct timeval end;
   gettimeofday(&end, 0);

   plot->last_render_time = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) * 0.000001;
}


void plot_draw_calc_x_minmax(my_plot_draw_t *plot, my_time_t *pmin, my_time_t *pmax, my_time_t *pdiffmin) {
   my_time_t ts = 0, te = 1;
   my_time_t min_time_diff = 1;

   int lsi;
   for(lsi=0; lsi<plot->line_set_count; ++lsi) {
      my_dataset_t *dataset = plot->line_set[lsi].dataset;

      if(lsi == 0 || min_time_diff > dataset->min_time_diff) {
	 min_time_diff = dataset->min_time_diff;
      }

      if(lsi == 0 || dataset->ts < ts) {
	 ts = dataset->ts;
      }

      if(lsi == 0 || dataset->te > te) {
	 te = dataset->te;
      }
   }

   if(pmin) *pmin = ts;
   if(pmax) *pmax = te;
   if(pdiffmin) *pdiffmin = min_time_diff;
}

// returns number of lines evaluated
int plot_draw_calc_y_minmax(my_plot_draw_t *plot, double *pmin, double *pmax, double *pdiffmin, boolean_t include_disabled) {
   double vmin = INFINITY, vmax = -INFINITY;
   double vdiffmin = INFINITY;

   int count = 0;
   boolean_t first = 1;

   // TODO if some line has all data values exactly the same,
   // dataset->item[that_line].vdiffmin == INFINITY and it doesn't
   // affect vdiffmin.. so it might be hard spotting by zooming

   // one way would be to force INFINITY to 0 in dataset.xc if after
   // loading everything it's still INFINITY.. but then that could
   // lead to all sorts of division by zero.. we could also use the
   // smallest double increment, but ...

   // for now in case we notice this situation we'll just check the
   // diffs between the max values of all other lines instead, dunno
   // if this is a very good algorithm but..

   // and additionally, this works only within lines of the current
   // plot, if there is multiple plots with single lines we still have
   // the problem..

   int lsi;
   for(lsi=0; lsi<plot->line_set_count; ++lsi) {
      my_dataset_t *dataset = plot->line_set[lsi].dataset;
      my_plot_line_info_t *line = plot->line_set[lsi].line;
      int line_count = plot->line_set[lsi].line_count;

      int li;
      for(li=0; li<line_count; ++li) {
	 if(!include_disabled && !line[li].enabled) continue;
	 int d = line[li].dataset_idx;
	 switch(line[li].mode) {
	    case LINE_MODE_NORMAL: {
	       if(first || vmin > dataset->item[d].min) vmin = dataset->item[d].min;
	       if(first || vmax < dataset->item[d].max) vmax = dataset->item[d].max;
	       if(isinf(dataset->item[d].diffmin) && !isinf(dataset->item[d].max)) {
		  // all data values on this line are exactly the same
		  // value. see comment above.
		  double comp = dataset->item[d].max; // min == max for this line
		  int lsi2;
		  for(lsi2=0; lsi2<plot->line_set_count; ++lsi2) {
		     my_dataset_t *dataset2 = plot->line_set[lsi2].dataset;
		     my_plot_line_info_t *line2 = plot->line_set[lsi2].line;
		     int line_count2 = plot->line_set[lsi2].line_count;
		     
		     int li2;
		     for(li2=0; li2<line_count2; ++li2) {
			if(lsi == lsi2 && li == li2) continue;
			if(!include_disabled && !line2[li2].enabled) continue;
			int d2 = line2[li2].dataset_idx;
			switch(line2[li2].mode) {
			   case LINE_MODE_NORMAL: {
			      double min = fabs(dataset2->item[d2].min - comp);
			      if(first || vdiffmin > min) vdiffmin = min;
			      double max = fabs(dataset2->item[d2].max - comp);
			      if(/* no first here, it's second already */ vdiffmin > max) vdiffmin = max;
			      first = 0;
			      break;
			   }
			}
		     }
		  }
	       } else {
		  if(first || vdiffmin > dataset->item[d].diffmin) vdiffmin = dataset->item[d].diffmin;
	       }
	       first = 0;
	       break;
	    }
	 }
	 count++;
      }
   }

   if(pmin) *pmin = vmin;
   if(pmax) *pmax = vmax;
   if(pdiffmin) *pdiffmin = vdiffmin;

   return count;
}


//
// init, deinit, clone -related functions ONLY below
//

void plot_draw_init(my_plot_draw_t *plot) {
   bzero(plot, sizeof(*plot));

   plot_draw_init_bookmarks(plot);
   plot_draw_init_grids(plot);
   plot_draw_init_legend(plot);
   plot_draw_init_lines(plot);
   plot_draw_init_logo(plot);

   plot->samples_per_pixel = 50;
}

void plot_draw_deinit(my_plot_draw_t *plot) {
   plot_draw_remove_all_data_files(plot);

   plot_draw_deinit_bookmarks(plot);
   plot_draw_deinit_grids(plot);
   plot_draw_deinit_legend(plot);
   plot_draw_deinit_lines(plot);
   plot_draw_deinit_logo(plot);

   if(plot->paintapi) {
      plot_draw_reset_gcs(plot);
      plot->paintapi->api_free(plot->paintapi);
   }

   bzero(plot, sizeof(*plot));
}

void plot_draw_clone(my_plot_draw_t *n, my_plot_draw_t *o) {
   plot_draw_clone_bookmarks(n, o);
   plot_draw_clone_grids(n, o);
   plot_draw_clone_legend(n, o);
   plot_draw_clone_lines(n, o);
   plot_draw_clone_logo(n, o);

   n->show_disabled = o->show_disabled;
   n->inverse_colors = o->inverse_colors;
   n->samples_per_pixel = o->samples_per_pixel;
   n->draw_min_max_lines = o->draw_min_max_lines;
   n->draw_average_line = o->draw_average_line;
   n->time_off = o->time_off;

   n->xstart = o->xstart;
   n->xend = o->xend;
   n->xmin = o->xmin;
   n->xmax = o->xmax;
   n->ymin = o->ymin;
   n->ymax = o->ymax;
}

static void plot_draw_free_line_info(my_plot_draw_t *plot, my_plot_line_info_t *p) {
   plot_draw_reset_line_info_gcs(plot, p);
   bzero(p, sizeof(*p));
}

static void plot_draw_free_line_info_set(my_plot_draw_t *plot, my_plot_line_info_set_t *p) {
   int li;
   for(li=0; li<p->line_count; ++li) {
      plot_draw_free_line_info(plot, &p->line[li]);
   }
   my_plot_line_info_arr_free(p->line);

   unref_dataset(p->dataset);

   bzero(p, sizeof(*p));
}

void plot_draw_remove_all_data_files(my_plot_draw_t *plot) {
   int lsi;
   for(lsi=0; lsi<plot->line_set_count; ++lsi) {
      plot_draw_free_line_info_set(plot, &plot->line_set[lsi]);
   }
   my_plot_line_info_set_arr_free(plot->line_set);
}

void plot_draw_remove_data_file(my_plot_draw_t *plot, int idx) {
   plot_draw_free_line_info_set(plot, &plot->line_set[idx]);
   --plot->line_set_count;
   memmove(&plot->line_set[idx], &plot->line_set[idx+1], (plot->line_set_count - idx) * sizeof(my_plot_line_info_set_t));
   memset(&plot->line_set[plot->line_set_count], 0, sizeof(my_plot_line_info_set_t)); // to spot bugs, clean the last slot
}

void plot_draw_setup_gcs(my_plot_draw_t *plot) {
   plot_draw_setup_logo_gcs(plot);
   plot_draw_setup_line_gcs(plot);
   plot_draw_setup_grid_gcs(plot);
   plot_draw_setup_bookmark_gcs(plot);
   plot_draw_setup_legend_gcs(plot);
}

void plot_draw_reset_gcs(my_plot_draw_t *plot) {
   plot_draw_reset_logo_gcs(plot);
   plot_draw_reset_line_gcs(plot);
   plot_draw_reset_grid_gcs(plot);
   plot_draw_reset_bookmark_gcs(plot);
   plot_draw_reset_legend_gcs(plot);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
