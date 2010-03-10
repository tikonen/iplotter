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
 * plot_draw_logo - handles the drawing of the logo
 */

#include "plot_draw.h"











#if 0
#define pprintf printf
#else
#define pprintf(...)
#endif

#define LOGO "google: xkr47 plot 0.29"

void plot_draw_logo(my_plot_draw_t *plot) {
   paintapi_textlayout_t *layout = plot->paintapi->textlayout_create(plot->paintapi, plot->logo.font, LOGO);

   paintapi_textlayout_extents_t ri;
   plot->paintapi->textlayout_calculate_size(plot->paintapi, layout, &ri);

   int x = plot->plot_xe - ri.xr - 2;
   int y = plot->plot_yde - ri.yb - 2;

   if(x < -ri.xl) x = -ri.xl;
   if(y < -ri.yt) y = -ri.yt;

   plot->paintapi->draw_textlayout(plot->paintapi, plot->logo.text_gc, x, y, layout);
   plot->paintapi->textlayout_free(plot->paintapi, layout);
}

void plot_draw_init_logo(my_plot_draw_t *plot) {
}

void plot_draw_deinit_logo(my_plot_draw_t *plot) {
}

void plot_draw_clone_logo(my_plot_draw_t *n, my_plot_draw_t *o) {
   n->logo.text_color = o->logo.text_color;
}

void plot_draw_setup_logo_gcs(my_plot_draw_t *plot) {
   plot->logo.text_gc = gc_new_with_color(plot, plot->logo.text_color);
}

void plot_draw_reset_logo_gcs(my_plot_draw_t *plot) {
   gc_free_and_zero(plot->logo.text_gc);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
