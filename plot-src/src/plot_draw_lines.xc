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
 * plot_draw_lines - handles the drawing of the lines of a plot
 */

#include "plot_draw.xh"

#include <limits.h>
#include <math.h>

#if 0
#define PPRINTF_ENABLED
#define pprintf printf
#else
#define pprintf(...)
#endif

#if 0
#define DPRINTF_ENABLED
#define dprintf printf
#else
#define dprintf(...)
#endif

#define MAX_OUTSIDE_COORD_OFFSET 1000

#define min_set(d,s) do { if((s) < (d)) (d) = (s); } while(0)
#define max_set(d,s) do { if((s) > (d)) (d) = (s); } while(0)

#define as(x) do { if(unlikely(!(x))) { printf("%s %d\n", #x, x); abort(); } } while(0)
#define asc(x,y) do { if(unlikely(x > y)) { printf("%d (%s) <= %d (%s)\n", x, #x, y, #y); abort(); } } while(0)

static void draw_mm_lines(const my_plot_draw_t *plot, my_plot_line_info_t *line) {
   if (plot->draw_min_max_lines) {
#if 0
      for(int x=0; x<=plot->plot_xe; x += line->smooth_amount) {
	 int xe = x + line->smooth_amount - 1;
	 min_set(xe, plot->plot_xe);

	 int min = INT_MAX;
	 int max = INT_MIN;
	 for(int xi=x; xi<=xe; ++xi) {
	    min_set(min, line->tmp.minmax_values_min[xi]);
	    max_set(max, line->tmp.minmax_values_max[xi]);
	 }
	 pprintf("mm %d, %d-%d  %d-%d\n", x, min, max, xo, xe);
	 if(max > min) {
	    for(int xi=x; xi<=xe; ++xi) {
	       paintapi_point_t *minmax_point = NULL;
	       minmax_point = &line->tmp.minmaxLines[(line->tmp.usedMinmaxLines++) * 2];
	       minmax_point[0].x = minmax_point[1].x = xi;
	       minmax_point[0].y = min;
	       minmax_point[1].y = max;
	    }
	 }
      }
#elif 1
      for(int x=0; x<=plot->plot_xe; ++x) {
	 int xo = x - (line->smooth_amount - 1) / 2;
	 max_set(xo, 0);
	 int xe = x + (line->smooth_amount) / 2;
	 min_set(xe, plot->plot_xe);

	 int min = INT_MAX;
	 int max = INT_MIN;
	 for(int xi=xo; xi<=xe; ++xi) {
	    min_set(min, line->tmp.minmax_values_min[xi]);
	    max_set(max, line->tmp.minmax_values_max[xi]);
	 }
	 pprintf("mm %d, %d-%d  %d-%d\n", x, min, max, xo, xe);
	 if(max > min) {
	    paintapi_point_t *minmax_point = NULL;
	    minmax_point = &line->tmp.minmaxLines[(line->tmp.usedMinmaxLines++) * 2];
	    minmax_point[0].x = minmax_point[1].x = x;
	    minmax_point[0].y = min;
	    minmax_point[1].y = max;
	 }
      }
#endif
      asc(line->tmp.usedMinmaxLines, plot->plot_xe+1);
      plot->paintapi->draw_segments(plot->paintapi, line->line_minmax_gc, line->tmp.minmaxLines, line->tmp.usedMinmaxLines);
   }
   line->tmp.usedMinmaxLines = 0;
}

static void draw_avg_lines(const my_plot_draw_t *plot, my_plot_line_info_t *line, int plot_xe) {
   if (plot->draw_average_line) {
      if(line->tmp.usedAvgLines > 1) {
	 line->tmp.avgLinesOffsets[line->tmp.usedAvgLinesOffsets] = line->tmp.usedAvgLines;
	 int start = 0;
	 for(int i=0; i<line->tmp.usedAvgLinesOffsets; ++i) {
	    plot->paintapi->draw_lines(plot->paintapi, line->line_gc, line->tmp.avgLines + start, line->tmp.avgLinesOffsets[i] - start);
	    start = line->tmp.avgLinesOffsets[i];
	 }
      }
   }
   line->tmp.usedAvgLinesOffsets = 0;
   line->tmp.usedAvgLines = 0;
}

/* call once per line of line_set */
static void draw_lines(const my_plot_draw_t *plot, my_plot_line_info_t *line, int plot_xe) {
   draw_mm_lines(plot, line);
   draw_avg_lines(plot, line, plot_xe);
}


static void add_avg_pixel(my_plot_line_info_t *line, int x, int y) {
   // calculate point coordinates
   paintapi_point_t *point = &line->tmp.avgLines[line->tmp.usedAvgLines++];
   point->x = x;
   point->y = y;

   pprintf("point %d,%d\n", x, y);

   if(line->tmp.usedAvgLines == 2) {
      paintapi_point_t *prevpoint = &line->tmp.avgLines[0];
      if(prevpoint->x < -MAX_OUTSIDE_COORD_OFFSET) {
	 // x1 = prevpoint->x
	 // x2 = point->x
	 // this algorithm has some visual artifacts, we should try to move x to reach a y == floor(y) instead of just fixing x at some point
	 prevpoint->y = y + (int)((-MAX_OUTSIDE_COORD_OFFSET - x) * (double)(y - prevpoint->y) / (double)(x - prevpoint->x));
	 prevpoint->x = -MAX_OUTSIDE_COORD_OFFSET;
	 pprintf("prevpoint moved to %d,%d\n", prevpoint->x, prevpoint->y);
      }
   }
}

/* call every time there's a discontinuity in the average line */
static void finish_avg_line(const my_plot_draw_t *plot, my_plot_line_info_t *line, int plot_xe) {
   pprintf("finish_avg_line()\n");
   if (plot->draw_average_line) {
      int prevEnd = line->tmp.usedAvgLinesOffsets > 0 ? line->tmp.avgLinesOffsets[line->tmp.usedAvgLinesOffsets-1] : 0;
      if(line->tmp.usedAvgLines > prevEnd + 1) {
	 paintapi_point_t *point = &line->tmp.avgLines[line->tmp.usedAvgLines-1];
	 int max_x = plot_xe + MAX_OUTSIDE_COORD_OFFSET;
	 if(point->x > max_x) {
	    paintapi_point_t *prevpoint = &line->tmp.avgLines[line->tmp.usedAvgLines-2];
	    // x1 = prevpoint->x
	    // x2 = point->x
	    // this algorithm has some visual artifacts, we should try to move x to reach a y == floor(y) instead of just fixing x at some point
	    point->y = prevpoint->y + (int)((max_x - prevpoint->x) * (double)(point->y - prevpoint->y) / (double)(point->x - prevpoint->x));
	    point->x = max_x;
	    pprintf("point moved to %d,%d\n", point->x, point->y);
	 }
	 line->tmp.avgLinesOffsets[line->tmp.usedAvgLinesOffsets++] = line->tmp.usedAvgLines;
      } else {
	 line->tmp.usedAvgLines = prevEnd;
      }
   }
}

static void add_mm_pixel(my_plot_line_info_t *line, int x, int ymin, int ymax) {
   pprintf("mmpoint %d,[%d-%d]\n", x, ymin, ymax);

   asc(0, x);

   line->tmp.minmax_values_min[x] = ymin;
   line->tmp.minmax_values_max[x] = ymax;
}

static int calc_screen_y(const my_plot_draw_t *plot, double y) {
   int ly = (plot->ymax - y) * plot->tmp.h_div_vdiff;
   // with extreme overdrives, these tend to go wrong (or so I guess)
   if(unlikely(ly > INT16_MAX)) ly = INT16_MAX;
   else if(unlikely(ly < INT16_MIN)) ly = INT16_MIN;
   return ly;
}

static void handle_one_line_in_line_set(const my_plot_draw_t *plot, my_plot_line_info_t *line, int start_x, int end_x) {
   const int *time_index = plot->tmp.sample_x;
   int start_idx = time_index[-1];
   int spp = plot->samples_per_pixel;
   enum { MODE_0, MODE_1, MODE_MULTI } prev_mode = MODE_1;

   pprintf("handle_one_line_in_line_set(start_x %d, end_x %d)\n", start_x, end_x);

   for (int x=-1; x<=plot->plot_xe+1; ++x) {
      int end_idx = time_index[x+1];
      boolean_t end_idx_was_negative = end_idx < 0;
      if(end_idx_was_negative) {
	 pprintf("%d %d %d %d %d\n", time_index[x-1], time_index[x], time_index[x+1], time_index[x+2], time_index[x+3]);
	 if(start_idx < 0) {
	    // if split lasts longer than one pixel, skip drawing of lines until end_idx goes positive again
	    continue;
	 }
	 end_idx = -end_idx;
      }
      if(start_idx < 0) {
	 start_idx = -start_idx;
      }

      int span = end_idx - start_idx;

      double min, max, avg;
      int points;
      my_data_t data;

      min = INT_MAX;
      max = INT_MIN;
      avg = 0;

      pprintf("[%d] [%d,%d[ ", x, start_idx, end_idx);

      if (span < 1) {
	 if(prev_mode == MODE_MULTI) {
	    data = line->tmp.data[start_idx-1];
	    if(likely(!isnan(data))) {
	       pprintf("extra start point added\n");
	       add_avg_pixel(line, x-1, calc_screen_y(plot, data));
	    } else {
	       pprintf("extra start point NOT added\n");
	       finish_avg_line(plot, line, plot->plot_xe);
	    }
	 }

	 prev_mode = MODE_0;
	 points = 0;
	 //min = max = avg = line->tmp.data[start_idx];
	 pprintf(" -  %d: %f\n", start_idx, line->tmp.data[start_idx]);
      } else if(span == 1) {
	 if(prev_mode == MODE_0 && line->linetype == TYPE_STEP && start_idx > 0) {
	    data = line->tmp.data[start_idx-1];
	    if(likely(!isnan(data))) {
	       pprintf("step end point added 1\n");
	       int px = x == plot->plot_xe+1 ? end_x : x;
	       add_avg_pixel(line, px, calc_screen_y(plot, data));
	    } else {
	       pprintf("step end point NOT added 1\n");
	       // finish_avg_line not needed since this is done only in STEP mode and thus the index is the same as when handled above in "span < 1" case
	    }
	 }

	 prev_mode = MODE_1;
	 points = 1;
	 data = line->tmp.data[start_idx];
	 pprintf("One %d: %f\n", start_idx, data);
	 if(unlikely(isnan(data))) {
	    finish_avg_line(plot, line, plot->plot_xe);
	    points = 0;
	 } else {
	    min = avg = max = data;
	 }
      } else {
	 if(prev_mode == MODE_0) {
	    data = line->tmp.data[line->linetype == TYPE_STEP ? start_idx-1 : start_idx];
	    if(likely(!isnan(data))) {
	       pprintf("extra end point added M\n");
	       int px = x == plot->plot_xe+1 ? end_x : x;
	       add_avg_pixel(line, px, calc_screen_y(plot, data));
	    } else {
	       pprintf("extra end point NOT added M\n");
	       finish_avg_line(plot, line, plot->plot_xe);
	    }
	 }

	 prev_mode = MODE_MULTI;

	 if (span <= spp) {
	    // linear scan
	    points = span;
	    for (int time=start_idx; time<end_idx; ++time) {
	       data = line->tmp.data[time];
	       pprintf("Lin %d: %f\n", time, data);
	       if(unlikely(isnan(data))) {
		  points--;
	       } else {
		  // TODO it would be nice with weighted average here and also in the skip scan below
		  avg += data;
		  if (data < min) {
		     min = data;
		  }  if (data > max) {
		     max = data;
		  }
	       }
	    }
	 } else {
	    // skip scan
	    points = spp;
	    for (int t=0; t < spp; ++t) {
	       int time = t * (span-1) / (spp-1) + start_idx;
	       data = line->tmp.data[time];
	       pprintf("Skp %d: %f\n", time, data);
	       if(unlikely(isnan(data))) {
		  points--;
	       } else {
		  avg += data;
		  if (data < min) {
		     min = data;
		  }  if (data > max) {
		     max = data;
		  }
	       }
	    }
	 }

	 if(points == 0) {
	    finish_avg_line(plot, line, plot->plot_xe);
	 }
      }

      if (points > 0) {
	 avg /= points;
	 int px = x == -1 ? start_x : x == plot->plot_xe+1 ? end_x : x;
	 add_avg_pixel(line, px, calc_screen_y(plot, avg));
	 if(px != start_x && px != end_x) {
	    add_mm_pixel(line, px, calc_screen_y(plot, max), calc_screen_y(plot, min));
	 }
      }

      if(end_idx_was_negative) {
	 finish_avg_line(plot, line, plot->plot_xe);
	 end_idx = -end_idx;
      }

      start_idx = end_idx;
   }

   finish_avg_line(plot, line, plot->plot_xe);
   draw_lines(plot, line, plot->plot_xe);
}

// with this, the range is [start,end]
#define PLOT_WIDTH_DIV_FROM_PLOT_XE(xe) (xe)

// with this, the range is [start,end[
//#define PLOT_WIDTH_DIV_FROM_PLOT_XE(xe) ((xe) + 1)

void plot_draw_lines(my_plot_draw_t *plot) {
   my_time_t start_time = (my_time_t)plot->xmin;
   my_time_t end_time = (my_time_t)plot->xmax;

#if defined(PPRINTF_ENABLED) || defined(DPRINTF_ENABLED)
   printf("--------------------------------- %" PRIdMYTIME " %" PRIdMYTIME " %d %d\n", start_time, end_time, plot->plot_xe+1, plot->plot_ye+1);
#endif

   plot->tmp.h_div_vdiff = plot->plot_yde / (plot->ymax - plot->ymin);

   // plot_xe indicates the x coordinate of the last visible pixel.
   // Thus the drawing area is plot_xe + 1 pixels wide.

   // first line goes from [x coordinate] -1 to 0 and last line goes
   // from plot_xe to plot_xe + 1. Thus we paint plot_xe + 2 lines.
   //
   // To calculate the y coordinate of plot_xe + 1 we need to scan the
   // data points in the range time[plot_xe + 1] <= point <
   // time[plot_xe + 2]. Thus we need to know the points in range
   // [-1,plot_xe + 2] which means we have plot_xe + 4 x values which
   // give plot_xe + 3 x ranges and thus plot_xe + 2 lines.
   size_t reqSize = (plot->plot_xe + 4);
   size_t reqSize2 = (plot->plot_xe + 1);

   // worst case scenario uses two lines per pixel
   plot->tmp.line.avgLines = realloc_c(plot->tmp.line.avgLines, 2 * reqSize * sizeof(paintapi_point_t));
   plot->tmp.line.avgLinesOffsets = realloc_c(plot->tmp.line.avgLinesOffsets, reqSize * sizeof(int));

   plot->tmp.line.minmaxLines = realloc_c(plot->tmp.line.minmaxLines, 2 * reqSize2 * sizeof(paintapi_point_t));
   plot->tmp.line.minmax_values_min = realloc_c(plot->tmp.line.minmax_values_min, reqSize2 * sizeof(int));
   plot->tmp.line.minmax_values_max = realloc_c(plot->tmp.line.minmax_values_max, reqSize2 * sizeof(int));

   plot->tmp.sample_x_allocated = realloc_c(plot->tmp.sample_x_allocated, reqSize * sizeof(int));
   plot->tmp.sample_x = plot->tmp.sample_x_allocated + 1; // sample_x[-1] <-> sample_x_allocated[0]

   // time fraction invariant used in fixed point math
   const int frac_off = (int)((PLOT_WIDTH_DIV_FROM_PLOT_XE(plot->plot_xe)) * fmod(plot->xmin, 1.0));

   // precalculate screen_x->time_index mapping for each line set
   int lsi;
   for(lsi = 0; lsi < plot->line_set_count; ++lsi) {

      /////////////////////////////
      // Check if there any enabled lines in this set
      int li;
      for(li=0; li<plot->line_set[lsi].line_count; ++li) {
	 if(plot->line_set[lsi].line[li].enabled) break;
      }
      if(li >= plot->line_set[lsi].line_count) continue; // no lines to draw, skip whole dataset

      my_dataset_t *dataset = plot->line_set[lsi].dataset;

      /////////////////////////////
      // find the start_idx of the single ghost point to draw to the left of pixel 0.
      // first try to find the first pixel left of 0 i.e. left of pixel 0 left border
      int start_idx = my_time_arr_find(dataset->time, start_time-1, AFB_LEFT_OR_MATCH);
      my_time_t start_time_m1pix = start_time + (start_time - end_time) / PLOT_WIDTH_DIV_FROM_PLOT_XE(plot->plot_xe); // see formula below in beginning of for loop
      // if it's within the time range covered by pixel -1, instead find the leftmost match of pixel -1 (i.e. the pixel right of pixel -1 left border)
      if(dataset->time[start_idx] > start_time_m1pix) {
	 dprintf("time[%d] = %" PRIdMYTIME " <= %" PRIdMYTIME ", now fetching for time %" PRIdMYTIME "\n", start_idx, dataset->time[start_idx], start_time - 1, start_time_m1pix);
	 start_idx = my_time_arr_find(dataset->time, start_time_m1pix, AFB_RIGHT_OR_MATCH);
      }
      plot->tmp.sample_x[-1] = start_idx;

      dprintf("xmin=%f xmax=%f, delta=%f\n", plot->xmin, plot->xmax, plot->xmax - plot->xmin);
      dprintf("start_time=%" PRIdMYTIME " end_time=%" PRIdMYTIME ", delta=%" PRIdMYTIME "\n", start_time, end_time, end_time - start_time);
      dprintf("start_idx=%d\n", start_idx);
      dprintf("screen_width=%d\n", plot->plot_xe + 1);
      dprintf("lastidx %d\n", dataset->time_count - 1);
      dprintf("frac_off %d\n", frac_off);

      my_time_t prev_realtime = start_time;
      boolean_t split_end_point = 0;

      int x;
      int end_idx = start_idx;
      int prev_end_idx = -100;
      // note: starts from -1
      my_time_t pt = -1;
      for (x=-1; x<=plot->plot_xe+1; ++x) {
	 // NOTE formula also used above in slightly different form
	 my_time_t time = (floor((x+1) * (plot->xmax - plot->xmin)) + frac_off) / PLOT_WIDTH_DIV_FROM_PLOT_XE(plot->plot_xe);

	 //time = (((x+1) * (end_time - start_time)) + frac_off) / PLOT_WIDTH_DIV_FROM_PLOT_XE(plot->plot_xe);
#ifdef DPRINTF_ENABLED
	 double   timed = (floor((x+1) * (plot->xmax - plot->xmin)) + frac_off) / (double)PLOT_WIDTH_DIV_FROM_PLOT_XE(plot->plot_xe);
	 my_time_t pt_debug = pt;
#endif
	 // if time is same as last round (happens if end_time - start_time < plot_xe + 1), adjust
	 if(time == pt) {
	    ++time;
	 } else {
	    pt = time;
	 }

	 dprintf("[%6Ld,%6Ld (%10.3lf)[ ", pt_debug + start_time - plot->time_off, time + start_time - plot->time_off, timed + start_time - plot->time_off);

	 /////////////////////////////
	 // find the first idx NOT inside the current pixel (== x), i.e. the first pixel right of the right border of the current pixel
	 end_idx = my_time_arr_find(dataset->time, time + start_time, AFB_RIGHT_OR_MATCH_OVER);
	 dprintf("x:%-4d %5d -> %d\n", x, start_idx, end_idx);
	 if(prev_end_idx != end_idx) {
#ifndef DPRINTF_ENABLED
	    pprintf("x:%-4d %5d -> %d\n", x, start_idx, end_idx);
#endif
	    prev_end_idx = end_idx;
	 }

	 // if the actually spanned time exceeds the maximum time difference times the number of indexes covered, mark
	 my_time_t realtime = dataset->time[end_idx >= dataset->time_count ? end_idx - 1 : end_idx];
	 if (end_idx > 0 && realtime - dataset->time[end_idx-1] > dataset->maxdiff) {
	    dprintf("%d-%d %" PRIdMYTIME " %" PRIdMYTIME " %" PRIdMYTIME "\n", start_idx, end_idx, realtime, prev_realtime, dataset->maxdiff);
	    // the end point is on the right side of a new split
	    split_end_point = 1;
	 } else {
	    if(realtime != prev_realtime) {
	       // split over, start drawing lines again
	       split_end_point = 0;
	    }
	 }
	 prev_realtime = realtime;

	 // store the end point for the line from x to x + 1.
	 //
	 // Example 1:
	 //   sample_x[x  ] = 10
	 //   sample_x[x+1] = 12
	 //   sample_x[x+2] = -15
	 //   sample_x[x+3] = 20
	 //
	 // means the following lines will be drawn: 10-12, 12-14, 15-20
	 //
	 // Example 2:
	 //   sample_x[x  ] = 10
	 //   sample_x[x+1] = 12
	 //   sample_x[x+2] = -15
	 //   sample_x[x+3] = -18
	 //   sample_x[x+4] = 20
	 //
	 // means the following lines will be drawn: 10-12, 12-14, 18-20

	 plot->tmp.sample_x[x+1] = split_end_point ? -end_idx : end_idx;

	 start_idx = end_idx; // needed for debug output only
      }

      my_plot_line_info_t *lines = plot->line_set[lsi].line;
      int line_count = plot->line_set[lsi].line_count;

      int start_x = (int)floor(((double)dataset->time[plot->tmp.sample_x[-1]] - start_time) / (end_time - start_time) * PLOT_WIDTH_DIV_FROM_PLOT_XE(plot->plot_xe));

      // if the last x coordinate doesn't draw a line, draw one additional line (that goes beyond plot_xe)
      int end_idx_p1 = end_idx-1;
      if(plot->tmp.sample_x[plot->plot_xe + 1] == end_idx && end_idx < dataset->time_count) {
	 end_idx_p1++;
	 plot->tmp.sample_x[plot->plot_xe + 2] = end_idx_p1 + 1;
      }
      int end_x = (int)(((double)dataset->time[end_idx_p1] - start_time) / (end_time - start_time) * PLOT_WIDTH_DIV_FROM_PLOT_XE(plot->plot_xe));

      dprintf("%d => x = [%d,%d]\n", end_idx_p1, start_x, end_x);

      for(li=0; li<line_count; ++li) {
	 my_plot_line_info_t *line = lines + li;
	 if(!line->enabled) continue;

	 line->tmp.data = dataset->item[line->dataset_idx].data;
	 dprintf("[%d] = %lf\n", li, dataset->item[li].max);

	 line->tmp.avgLines = plot->tmp.line.avgLines;
	 line->tmp.avgLinesOffsets = plot->tmp.line.avgLinesOffsets;
	 line->tmp.minmaxLines = plot->tmp.line.minmaxLines;
	 line->tmp.minmax_values_min = plot->tmp.line.minmax_values_min;
	 line->tmp.minmax_values_max = plot->tmp.line.minmax_values_max;

	 memset(plot->tmp.line.minmax_values_min, 127, reqSize2 * sizeof(int)); // 0x7F7F7F7F is close enough to INT_MAX_SIGNED, but maybe writing words would be faster even..
	 memset(plot->tmp.line.minmax_values_max, 128, reqSize2 * sizeof(int)); // 0x80808080 is close enough to INT_MIN_SIGNED, ---------------------"------------------------

	 line->tmp.usedAvgLines = 0;
	 line->tmp.usedAvgLinesOffsets = 0;
	 line->tmp.usedMinmaxLines = 0;

	 handle_one_line_in_line_set(plot, line, start_x, end_x);
      }
   }
}


void plot_draw_init_lines(my_plot_draw_t *plot) {
   //plot->line_set_dflt.line_dflt.linetype = TYPE_STEP;
   plot->line_set_dflt.line_dflt.hline = -1;
   plot->line_set_dflt.line_dflt.dataset_idx = -1;
   plot->line_set_dflt.line_dflt.smooth_amount = 3; // TODO: gui-configurable
   plot->draw_min_max_lines = true;
   plot->draw_average_line = true;
}

void plot_draw_deinit_lines(my_plot_draw_t *plot) {
   free(plot->tmp.sample_x_allocated);
   free(plot->tmp.line.avgLines);
   free(plot->tmp.line.avgLinesOffsets);
   free(plot->tmp.line.minmaxLines);
   free(plot->tmp.line.minmax_values_min);
   free(plot->tmp.line.minmax_values_max);
}

void plot_draw_clone_lines(my_plot_draw_t *n, my_plot_draw_t *o) {
   n->draw_min_max_lines = o->draw_min_max_lines;
   n->draw_average_line = o->draw_average_line;

   int setcount = o->line_set_count;
   my_plot_line_info_set_arr_set_length(n->line_set, setcount);

   int lsi;
   for(lsi = 0; lsi < setcount; ++lsi) {
      my_plot_line_info_set_t *ns, *os;
      ns = &n->line_set[lsi];
      os = &o->line_set[lsi];

      ns->dataset = os->dataset;
      ref_dataset(os->dataset);

      int linecount = os->line_count;
      my_plot_line_info_arr_set_length(ns->line, linecount);

      int li;
      for(li = 0; li < linecount; ++li) {
	 my_plot_line_info_t *nsl, *osl;
	 nsl = &ns->line[li];
	 osl = &os->line[li];

	 nsl->color = osl->color;
	 nsl->dataset_idx = osl->dataset_idx;
	 nsl->enabled = osl->enabled;
	 nsl->mode = osl->mode;
	 nsl->smooth_amount = osl->smooth_amount;
	 nsl->linetype = osl->linetype;
      }
   }
}

void plot_draw_setup_line_gcs(my_plot_draw_t *plot) {
   // ##TODO##
   int lsi;
   for(lsi = 0; lsi < plot->line_set_count; ++lsi) {
      my_plot_line_info_t *line = plot->line_set[lsi].line;
      int line_count = plot->line_set[lsi].line_count;
      int i;
      for(i=0; i<line_count; ++i) {
	 if(likely(line[i].line_gc)) continue;
	 // printf("%d %s\n", i, line[i].color);

	 line[i].line_gc = gc_new_with_color(plot, line[i].color);
	 paintapi_rgb_t mmc = line[i].color;
	 mmc.r /= 2;
	 mmc.g /= 2;
	 mmc.b /= 2;
	 line[i].line_minmax_gc = gc_new_with_color(plot, mmc);
	 line[i].horiz_marker_gc = gc_new_with_color(plot, line[i].color);

	 const char horiz_marker_dashes[] = { 2, 4 };
	 plot->paintapi->gc_set_dashes(plot->paintapi, line[i].horiz_marker_gc, 0, horiz_marker_dashes, SZ(horiz_marker_dashes));
	 plot->paintapi->gc_set_function(plot->paintapi, line[i].horiz_marker_gc, PAINTAPI_FUNCTION_XOR);
      }
   }
}

void plot_draw_reset_line_info_gcs(my_plot_draw_t *plot, my_plot_line_info_t *p) {
   gc_free_and_zero(p->line_gc);
   gc_free_and_zero(p->line_minmax_gc);
   gc_free_and_zero(p->horiz_marker_gc);
}

void plot_draw_reset_line_gcs(my_plot_draw_t *plot) {
   int lsi;
   for(lsi=0; lsi<plot->line_set_count; ++lsi) {
      my_plot_line_info_set_t *pp = &plot->line_set[lsi];
      int li;
      for(li=0; li<pp->line_count; ++li) {
	 plot_draw_reset_line_info_gcs(plot, &pp->line[li]);
      }
   }
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
