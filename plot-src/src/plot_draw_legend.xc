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
 * plot_draw_legend - handles the drawing of the legend of a plot
 */

#include "plot_draw.xh"
#include "system.xh"

#if 0
#define pprintf printf
#else
#define pprintf(...)
#endif

void plot_draw_legend(my_plot_draw_t *plot) {

   if(plot->legend.show == LEGEND_HIDE) return;

   // precalculate layouts to get max layout width
   int layout_max_x = 0;
   int layout_max_y = 0;
   int layout_min_y = 1000;

   int list_count = 0;
   int lsi;
   for(lsi = 0; lsi < plot->line_set_count; ++lsi) {
      my_dataset_t *dataset = plot->line_set[lsi].dataset;
      my_plot_line_info_t *line = plot->line_set[lsi].line;
      int line_count = plot->line_set[lsi].line_count;

      int li;
      for(li=0; li<line_count; ++li) {
	 if(!line[li].enabled && !plot->show_disabled) continue;

	 const char *linename = dataset->item[line[li].dataset_idx].name;
	 char *text = malloc((dataset->name ? strlen(dataset->name) : 7 + 1 + 10) + 2 + (linename ? strlen(linename) : 4 + 1 + 10) + 1);

	 if(plot->line_set_count > 1 || (line_count == 1 && !linename)) {
	    if(dataset->name) {
	       strcpy(text, dataset->name);
	    } else {
	       sprintf(text, _("dataset %d"), lsi + 1);
	    }
	 } else {
	    text[0] = '\0';
	 }

	 if(linename) {
	    if(plot->line_set_count > 1) {
	       strcat(text, ": ");
	    }
	    strcat(text, linename);
	 } else if(line_count > 1) {
	    if(plot->line_set_count > 1) {
	       strcat(text, ": ");
	    }
	    sprintf(text + strlen(text), _("item %d"), li + 1);
	 }

	 paintapi_textlayout_t *layout = plot->paintapi->textlayout_create(plot->paintapi, plot->legend.font, text);

	 // overstrike if not enabled
	 if(!line[li].enabled) {
	    plot->paintapi->textlayout_set_strikeout(plot->paintapi, layout);
	 }

	 paintapi_textlayout_extents_t ri;
	 plot->paintapi->textlayout_calculate_size(plot->paintapi, layout, &ri);

	 layout_max_x = max(layout_max_x, ri.xr);
	 layout_max_y = max(layout_max_y, ri.yb);
	 layout_min_y = min(layout_min_y, ri.yt);

	 pprintf("h %d - %d\n", ri.yt, ri.yb);

	 free(text);

	 line[li].tmp.legend_layout = layout;

	 list_count++;
      }
   }

   if(list_count == 0) return;

   pprintf("max %d,%d min %d newmax %d\n", layout_max_x, layout_max_y, layout_min_y, layout_max_y - layout_min_y);

   int layout_max_width = layout_max_x + 1;
   int layout_max_height = layout_max_y - layout_min_y + 1;

   pprintf("\n");

   double box_size_multiplier = 0.5;

   // the color box of a entry
   int legend_list_box_offset_x = 0;
   int legend_list_box_offset_y = (layout_max_height - 2 - (int)(layout_max_height * box_size_multiplier)) / 2;
   int legend_list_box_size_x = (int)(layout_max_height * box_size_multiplier);
   int legend_list_box_size_y = (int)(layout_max_height * box_size_multiplier);
   int legend_list_box_text_spacing_x = 2 + legend_list_box_size_x / 2;

   // printf("%d %d %d\n", legend_list_box_offset_y, legend_list_box_size_y, layout_max_height);

   // the whole entry representing a line
   int legend_list_unit_size_x = layout_max_width + legend_list_box_offset_x + legend_list_box_size_x + legend_list_box_text_spacing_x;
   int legend_list_unit_size_y = layout_max_height;

   // all entries
   int legend_list_size_x = legend_list_unit_size_x;
   int legend_list_size_y = legend_list_unit_size_y * list_count;

   // margins outside the whole thing
   int legend_margin_left_x = plot->value_axis_width * 4 / 3 + layout_max_height / 2 + 2;
   int legend_margin_right_x = layout_max_height / 2 + 2;
   int legend_margin_y = layout_max_height / 2 + 2;

   // padding between the whole thing and the list of all entries
   int legend_list_padding_x = 4 + legend_list_box_size_x / 2;
   int legend_list_padding_y = layout_max_height / 3;

   // final coordinates
   int legend_corner_x =
      plot->legend.show == LEGEND_SHOW_LEFT ?
      legend_margin_left_x :
      plot->plot_xe - legend_margin_right_x - 2 * legend_list_padding_x - legend_list_size_x;
   int legend_corner_y = legend_margin_y;

   int legend_corner_x2 = legend_corner_x + 2 * legend_list_padding_x + legend_list_size_x;
   int legend_corner_y2 = legend_corner_y + 2 * legend_list_padding_y + legend_list_size_y;

   my_plot_rect_t candidaterect = { legend_corner_x, legend_corner_y,
                                    legend_corner_x2, legend_corner_y2 };
   if(plot->bookmarks.show != BOOKMARKS_SHOW_POLE_ONLY &&
      plot->bookmarks.show != BOOKMARKS_HIDE) {
      place_bookmark_note(plot,plot->bookmarks.bookmark_count,&candidaterect,2);
   }

   legend_corner_x = candidaterect.x1;
   legend_corner_y = candidaterect.y1;
   legend_corner_x2 = candidaterect.x2;
   legend_corner_y2 = candidaterect.y2;

   // draw box
   plot->paintapi->draw_rectangle(plot->paintapi, plot->legend.bg_gc,     1, legend_corner_x+1, legend_corner_y+1, legend_corner_x2-1, legend_corner_y2-1);
   plot->paintapi->draw_rectangle(plot->paintapi, plot->legend.border_gc, 0, legend_corner_x  , legend_corner_y  , legend_corner_x2  , legend_corner_y2  );

   plot->legend.rect.x1 = legend_corner_x;
   plot->legend.rect.y1 = legend_corner_y;
   plot->legend.rect.x2 = legend_corner_x2;
   plot->legend.rect.y2 = legend_corner_y2;

   int no = 0;

   // draw legend items
   for(lsi = 0; lsi < plot->line_set_count; ++lsi) {
      my_plot_line_info_t *line = plot->line_set[lsi].line;
      int line_count = plot->line_set[lsi].line_count;

      int li;
      for(li=0; li<line_count; ++li) {
	 if(!line[li].enabled && !plot->show_disabled) {
	    line[li].legend_rect.x1 = line[li].legend_rect.y1 = line[li].legend_rect.x2 = line[li].legend_rect.y2 = -1;
	    continue;
	 }

	 int legend_list_corner_x = legend_corner_x + legend_list_padding_x;
	 int legend_list_corner_y = legend_corner_y + legend_list_padding_y + legend_list_unit_size_y * no;

	 line[li].legend_rect.x1 = legend_list_corner_x;
	 line[li].legend_rect.y1 = legend_list_corner_y;
	 line[li].legend_rect.x2 = legend_list_corner_x + legend_list_unit_size_x;
	 line[li].legend_rect.y2 = legend_list_corner_y + legend_list_unit_size_y;

	 int legend_list_text_corner_x = legend_list_corner_x + legend_list_box_offset_x + legend_list_box_size_x + legend_list_box_text_spacing_x;
	 int legend_list_text_corner_y = legend_list_corner_y;

	 plot->paintapi->draw_rectangle(plot->paintapi, line[li].enabled ? line[li].line_gc : plot->legend.border_gc, line[li].enabled,
					legend_list_corner_x + legend_list_box_offset_x,
					legend_list_corner_y + legend_list_box_offset_y,
					legend_list_corner_x + legend_list_box_offset_x + legend_list_box_size_x - 1,
					legend_list_corner_y + legend_list_box_offset_y + legend_list_box_size_y - 1);

/*
	 plot->paintapi->gc_set_function(plot->paintapi, plot->legend.border_gc, PAINTAPI_FUNCTION_XOR);
	 plot->paintapi->draw_rectangle(plot->paintapi, plot->legend.border_gc, 0,
			      legend_list_corner_x, legend_list_corner_y,
			      legend_list_corner_x + legend_list_unit_size_x - 1, legend_list_corner_y + legend_list_unit_size_y - 1);
	 plot->paintapi->gc_set_function(plot->paintapi, plot->legend.border_gc, PAINTAPI_FUNCTION_SET);
*/

	 plot->paintapi->draw_textlayout(plot->paintapi, plot->legend.text_gc,
					 legend_list_text_corner_x,
					 legend_list_text_corner_y - layout_min_y, line[li].tmp.legend_layout);

	 plot->paintapi->textlayout_free(plot->paintapi, line[li].tmp.legend_layout);

/*
	 if(!line[li].enabled) {
	    printf("%d %d\n", lx, ly);
	    plot->paintapi->draw_line(plot->paintapi, plot->legend.text_gc,
			  legend_list_text_corner_x, legend_list_text_corner_y + ly/2,
			  legend_list_text_corner_x + lx, legend_list_text_corner_y + ly/2);
	 }
*/

	 no++;
      }
   }

   //    last outer2 if(normal_expose);

   //	    if(mytrans != plot->dsc_x->{num_changes} + plot->dsc_y->{num_changes}) {
   //	    print "- mytrans plot->dsc_x->{num_changes}\n";
   //	    da->queue_draw() unless(queued++);
   //	    queued++;
   //	    plot->conc--; return;

   //####################
}

boolean_t plot_draw_check_if_hit_legend_box(my_plot_draw_t *draw, int x, int y) {
   return draw->legend.show && rect_is_in(&draw->legend.rect, x, y);
}

my_plot_line_info_t *plot_draw_check_if_hit_legend_item(my_plot_draw_t *draw, int x, int y, int *lsip, int *lip) {
   int lsi;
   for(lsi = 0; lsi < draw->line_set_count; ++lsi) {
      my_plot_line_info_t *line = draw->line_set[lsi].line;
      int line_count = draw->line_set[lsi].line_count;

      int li;
      for(li=0; li<line_count; ++li) {
	 if(rect_is_in(&line[li].legend_rect, x, y)) {
	    if(lsip) *lsip = lsi;
	    if(lip) *lip = li;
	    return &line[li];
	 }
      }
   }

   return NULL;
}


void plot_draw_init_legend(my_plot_draw_t *plot) {
   plot->legend.show = LEGEND_SHOW_RIGHT;
}

void plot_draw_deinit_legend(my_plot_draw_t *plot) {
}

void plot_draw_clone_legend(my_plot_draw_t *n, my_plot_draw_t *o) {
   n->legend.show = o->legend.show;

   n->legend.bg_color = o->legend.bg_color;
   n->legend.border_color = o->legend.border_color;
   n->legend.text_color = o->legend.text_color;
}

void plot_draw_setup_legend_gcs(my_plot_draw_t *plot) {
   plot->legend.bg_gc = gc_new_with_color(plot, plot->legend.bg_color);
   plot->legend.border_gc = gc_new_with_color(plot, plot->legend.border_color);
   plot->legend.text_gc = gc_new_with_color(plot, plot->legend.text_color);
}

void plot_draw_reset_legend_gcs(my_plot_draw_t *plot) {
   gc_free_and_zero(plot->legend.bg_gc);
   gc_free_and_zero(plot->legend.border_gc);
   gc_free_and_zero(plot->legend.text_gc);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
