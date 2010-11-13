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
 * plot_draw_bookmarks - handles the drawing of the bookmarks of a plot
 */

#include "plot_draw.h"










static my_plot_rect_t zeroRect = { 0, 0, 0, 0 };

static my_plot_rect_t _rect_overlap(my_plot_rect_t *r1, my_plot_rect_t *r2, int threshold)
{
   my_plot_rect_t *tmp;
   my_plot_rect_t overlap;

   // sort by x-axis
   if(r1->x1 > r2->x1) {
      tmp = r2;
      r2 = r1;
      r1 = tmp;
   }
   // check if the distance of the closest horizontal edges is greater
   // than the threshold
   if(r2->x1 > r1->x2 + threshold) {
      // no overlap
      return zeroRect;
   }
   overlap.x1 = r2->x1;
   overlap.x2 = r2->x2 < r1->x2 ? r2->x2 : r1->x2;

   // sort by y-order
   if(r1->y1 > r2->y1) {
      tmp = r2;
      r2 = r1;
      r1 = tmp;
   }
   // check if the distance of the closest horizontal edges is greater
   // than the threshold
   if(r2->y1 > r1->y2 + threshold) {
      // no overlap
      return zeroRect;
   }
   overlap.y1 = r2->y1;
   overlap.y2 = r2->y2 < r1->y2 ? r2->y2 : r1->y2;

   return overlap;
}

static int _compare_bookmarks(const my_plot_bookmark_t *b1, const my_plot_bookmark_t *b2)
{
   return b1->timestamp - b2->timestamp;
}

void plot_draw_sort_bookmarks(my_plot_draw_t *plot)
{
   qsort(plot->bookmarks.bookmark, (size_t)plot->bookmarks.bookmark_count, sizeof(my_plot_bookmark_t), _compare_bookmarks);
}

void place_bookmark_note(my_plot_draw_t *plot, int bic, my_plot_rect_t *candidaterect, int dist)
{
   // todo placement is not the best, should use height from
   // overlapping note instead.. but that is jumpy (try resizing for
   // exmaple)..

   int height = abs(candidaterect->y2 - candidaterect->y1);
   //int width = abs(candidaterect->x2 - candidaterect->x1);

   int ti; // total iterations
   int bi;
   for(ti = 0, bi = 0; bi < bic && ti < 100 ; ti++) {
      my_plot_rect_t overlap = _rect_overlap(&plot->bookmarks.bookmark[bi].note_rect,candidaterect,dist);
      if(!rect_equal(&overlap,&zeroRect)) {
	 // bookmark rectangle overlaps with current one

	 // move down
	 candidaterect->y1 += height + dist;
	 candidaterect->y2 += height + dist;
	 bi = 0; // start over
	 continue;
      }
      // no overlap, try next
      bi++;
   }
   // done
}

void plot_draw_bookmarks(my_plot_draw_t *plot) {
   if(plot->bookmarks.show == BOOKMARKS_HIDE) {
      return;
   }

   int bi;
   for(bi = 0; bi < plot->bookmarks.bookmark_count ; bi++ ) {
      plot->bookmarks.bookmark[bi].note_rect = zeroRect;
      if(plot->bookmarks.bookmark[bi].timestamp >= plot->xmin &&
	 plot->bookmarks.bookmark[bi].timestamp <= plot->xmax) {

	 // in range
	 int xoffset = plot->plot_xe*(plot->bookmarks.bookmark[bi].timestamp - plot->xmin)/(plot->xmax - plot->xmin);
	 // bookmark flag pole
	 plot->paintapi->draw_line(plot->paintapi,plot->bookmarks.gc,xoffset,0,xoffset,plot->plot_yde);

	 if(plot->bookmarks.show == BOOKMARKS_SHOW_POLE_ONLY) continue;

	 plot->bookmarks.triangle_size = 3 + plot->plot_ye / 60;

	 // bookmark triangle
	 paintapi_point_t point_list[] = {
	    { xoffset, plot->bookmarks.triangle_size },
	    { xoffset-plot->bookmarks.triangle_size, 0 },
	    { xoffset+plot->bookmarks.triangle_size, 0 }
	 };
	 plot->paintapi->draw_closed_path(plot->paintapi,plot->bookmarks.gc,1,point_list,3);

	 char tmp[100];
	 // check the type of label draw
	 if(plot->bookmarks.show == BOOKMARKS_SHOW_LABEL_ONLY) {
	    snprintf(tmp,sizeof(tmp), "(%d)",bi+1);
	 } else if(plot->bookmarks.show == BOOKMARKS_SHOW) {
	    snprintf(tmp,sizeof(tmp), "%s",plot->bookmarks.bookmark[bi].bookmark);
	 }
	 paintapi_textlayout_t *layout = plot->paintapi->textlayout_create(plot->paintapi, plot->grid.font_yaxis, tmp); // TODO legend font separately
	 paintapi_textlayout_extents_t ri;
	 plot->paintapi->textlayout_calculate_size(plot->paintapi, layout, &ri);
	 int width = abs(ri.xr - ri.xl);
	 int height = abs(ri.yt - ri.yb);
	 int poledistance = 3 + plot->bookmarks.triangle_size * 3 / 2;
	 int padding = (height-1) / 5 + 1;

         // candidate location for the note text
         my_plot_rect_t candidaterect = { xoffset+poledistance-padding, poledistance-padding, xoffset+poledistance+width+padding, poledistance+height+padding };

         // check if it's already off screen
         if(candidaterect.x2 > plot->plot_xe) {
	    int xadjust = candidaterect.x2 - plot->plot_xe;
	    candidaterect.x1 -= xadjust + 5;
	    candidaterect.x2 -= xadjust + 5;
         }

         // find clean place for the note
         place_bookmark_note(plot,bi,&candidaterect,3);

         plot->bookmarks.bookmark[bi].note_rect = candidaterect;
         plot->bookmarks.bookmark[bi].xoffset = xoffset;

         plot->paintapi->draw_line(plot->paintapi,plot->bookmarks.gc,
                                   xoffset,
                                   plot->bookmarks.bookmark[bi].note_rect.y1+height/2,
                                   plot->bookmarks.bookmark[bi].note_rect.x1,
                                   plot->bookmarks.bookmark[bi].note_rect.y1+height/2+5);
	 plot->paintapi->draw_rectangle(plot->paintapi,plot->bookmarks.gc,1,
                                        plot->bookmarks.bookmark[bi].note_rect.x1,
                                        plot->bookmarks.bookmark[bi].note_rect.y1,
                                        plot->bookmarks.bookmark[bi].note_rect.x2,
                                        plot->bookmarks.bookmark[bi].note_rect.y2);
         plot->paintapi->draw_textlayout(plot->paintapi, plot->bookmarks.text_gc,
                                         plot->bookmarks.bookmark[bi].note_rect.x1 - ri.xl + padding,
                                         plot->bookmarks.bookmark[bi].note_rect.y1 - ri.yt + padding, layout);
	 plot->paintapi->textlayout_free(plot->paintapi, layout);
      }
   }
}


void plot_draw_init_bookmarks(my_plot_draw_t *plot) {
   plot->bookmarks.show = BOOKMARKS_SHOW;
}

void plot_draw_deinit_bookmarks(my_plot_draw_t *plot) {
   int bi;
   for(bi=0; bi < plot->bookmarks.bookmark_count; ++bi) {
      if(plot->bookmarks.bookmark[bi].bookmark) {
	 free(plot->bookmarks.bookmark[bi].bookmark);
      }
   }
}

void plot_draw_clone_bookmarks(my_plot_draw_t *n, my_plot_draw_t *o) {
   n->bookmarks.show = o->bookmarks.show;

   n->bookmarks.color = o->bookmarks.color;
   n->bookmarks.text_color = o->bookmarks.text_color;

   int bmcount = o->bookmarks.bookmark_count;
   my_plot_bookmark_arr_set_length(n->bookmarks.bookmark, bmcount);
   int bi;
   for(bi=0; bi < bmcount; ++bi) {
      n->bookmarks.bookmark[bi].timestamp = o->bookmarks.bookmark[bi].timestamp;
      n->bookmarks.bookmark[bi].bookmark = o->bookmarks.bookmark[bi].bookmark ? strdup(o->bookmarks.bookmark[bi].bookmark) : NULL;
   }
}

void plot_draw_setup_bookmark_gcs(my_plot_draw_t *plot) {
   plot->bookmarks.gc = gc_new_with_color(plot, plot->bookmarks.color);
   plot->paintapi->gc_set_dashes(plot->paintapi, plot->bookmarks.gc, 0, "\x10\x3", 2);
   plot->bookmarks.text_gc = gc_new_with_color(plot, plot->bookmarks.text_color);
}

void plot_draw_reset_bookmark_gcs(my_plot_draw_t *plot) {
   gc_free_and_zero(plot->bookmarks.text_gc);
   gc_free_and_zero(plot->bookmarks.gc);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
