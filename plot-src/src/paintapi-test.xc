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
 * paintapi-test - paintapi test
 */

#include <stdio.h>

#include "paintapi-test.xh"

static paintapi_rgb_t c_red     = { 65535,     0,     0 };
static paintapi_rgb_t c_green   = {     0, 65535,     0 };
static paintapi_rgb_t c_blue    = {     0,     0, 65535 };
static paintapi_rgb_t c_yellow  = { 65535, 65535,     0 };
static paintapi_rgb_t c_white   = { 65535, 65535, 65535 };
static paintapi_rgb_t c_black   = {     0,     0,     0 };
static paintapi_rgb_t c_grey    = { 10000, 10000, 10000 };
static paintapi_rgb_t c_darkred = { 16384,     0,     0 };

static paintapi_t *a;

static paintapi_gc_t *red;
static paintapi_gc_t *green;
static paintapi_gc_t *blue;
static paintapi_gc_t *yellow;
static paintapi_gc_t *white;
static paintapi_gc_t *black;
static paintapi_gc_t *grey;
static paintapi_gc_t *darkred;

static paintapi_gc_t *dash;
static paintapi_gc_t *xor;
static paintapi_font_t *font10;

static void draw_text_advance(paintapi_gc_t *gc, paintapi_font_t *font, int xp, int *ypp, const char *text) {
   paintapi_textlayout_t *layout = a->textlayout_create(a, font, text);
   paintapi_textlayout_extents_t rect;
   a->textlayout_calculate_size(a, layout, &rect);
   a->draw_textlayout(a, gc, xp, *ypp, layout);
   *ypp += rect.yb;
}

static void do_font_test(paintapi_font_t *font, int xp, int *ypp, const char *text) {
   paintapi_textlayout_t *layout = a->textlayout_create(a, font, text);

   paintapi_textlayout_extents_t rect;
   a->textlayout_calculate_size(a, layout, &rect);

   int yp = *ypp;

   int yt = rect.yt < 0 ? -rect.yt : 0;
   int xl = rect.xl < 0 ? -rect.xl : 0;

   yp += yt;
   xp += xl;

   a->draw_rectangle(a, black, 1, xp, yp, xp + rect.xr, yp + rect.yb);
   if(rect.yt < 0) {
      a->draw_rectangle(a, grey, 1, xp + rect.xl, yp-yt, xp + rect.xr, yp-1);
   } else if(rect.yt > 0) {
      a->draw_rectangle(a, darkred, 1, xp + rect.xl, yp, xp + rect.xr, yp+rect.yt-1);
   }
   if(rect.xl < 0) {
      a->draw_rectangle(a, grey, 1, xp + rect.xl, yp, xp-1, yp+rect.yb);
   } else if(rect.xl > 0) {
      a->draw_rectangle(a, darkred, 1, xp, yp, xp + rect.xl-1, yp+rect.yb);
   }

   a->draw_rectangle(a, blue, 0, xp-1-xl, yp-1-yt, xp + rect.xr+1, yp + rect.yb+1);

   a->draw_textlayout(a, green, xp, yp, layout);

   char foo[100];
   sprintf(foo, "%d,%d %d,%d", rect.xl, rect.yt, rect.xr+1, rect.yb+1);
   a->draw_text(a, white, font10, xp + rect.xr + 10, yp+1, foo);

   a->draw_rectangle(a, white, 1, xp, yp, xp, yp);

   *ypp += rect.yb+yt+1 + 3;
}

void paintapi_test(paintapi_t *api, paintapi_font_t *font10_, paintapi_font_t *font20, int xe, int ye) {
   a = api;
   font10 = font10_;

   red = a->gc_new(a);     a->gc_set_foreground(a, red, &c_red);
   green = a->gc_new(a);   a->gc_set_foreground(a, green, &c_green);
   blue = a->gc_new(a);    a->gc_set_foreground(a, blue, &c_blue);
   yellow = a->gc_new(a);  a->gc_set_foreground(a, yellow, &c_yellow);
   white = a->gc_new(a);   a->gc_set_foreground(a, white, &c_white);
   black = a->gc_new(a);   a->gc_set_foreground(a, black, &c_black);
   grey = a->gc_new(a);    a->gc_set_foreground(a, grey, &c_grey);
   darkred = a->gc_new(a); a->gc_set_foreground(a, darkred, &c_darkred);

   dash = a->gc_new(a);
   a->gc_set_foreground(a, dash, &c_white);
   const char dashes[] = { 5, 2 };
   a->gc_set_dashes(a, dash, 2, dashes, 2);

   xor = a->gc_new(a);
   a->gc_set_foreground(a, xor, &c_white);
   a->gc_set_function(a, xor, PAINTAPI_FUNCTION_XOR);

   int xp, yp;

   /////

   a->draw_text(a, green, font10, 25, 10, "The arrow's head pixel is at (1,1)");
   a->draw_line(a, white, 20, 20, 1, 1);
   a->draw_line(a, white, 9, 1, 1, 1);
   a->draw_line(a, white, 1, 9, 1, 1);

   a->draw_line(a, white, 20, ye-20, 1, ye-1);
   a->draw_line(a, white, 9, ye-1, 1, ye-1);
   a->draw_line(a, white, 1, ye-9, 1, ye-1);

   char foo[200];
   sprintf(foo, "The arrow's head pixel is at (xe-1,ye-1) = (%d,%d)", xe-1, ye-1);
   paintapi_textlayout_t *layout = a->textlayout_create(a, font10, foo);
   paintapi_textlayout_extents_t rect;
   a->textlayout_calculate_size(a, layout, &rect);
   a->draw_textlayout(a, green, xe-rect.xr-25, ye-rect.yb-10, layout);
   a->draw_line(a, white, xe-20, ye-20, xe-1, ye-1);
   a->draw_line(a, white, xe-9, ye-1, xe-1, ye-1);
   a->draw_line(a, white, xe-1, ye-9, xe-1, ye-1);

   a->draw_line(a, white, xe-20, 20, xe-1, 1);
   a->draw_line(a, white, xe-9, 1, xe-1, 1);
   a->draw_line(a, white, xe-1, 9, xe-1, 1);

   a->draw_text(a, green, font10, xe/2 + 10, 10, "The arrow's head is three");
   a->draw_text(a, green, font10, xe/2 + 10, 10+12, "pixels above the area and the");
   a->draw_text(a, green, font10, xe/2 + 10, 10+24, "head should thus not be visible.");
   a->draw_line(a, white, xe/2, 20, xe/2, -3);
   a->draw_line(a, white, xe/2-7, 4, xe/2, -3);
   a->draw_line(a, white, xe/2+7, 4, xe/2, -3);

   /////

   xp = 10;
   yp = 40;

   draw_text_advance(green, font10, xp, &yp, "Four crosshairs whose lines end at");
   draw_text_advance(green, font10, xp, &yp, "the pixel next to the middle point.");

   yp += 6;

   xp += 10;
   yp += 10;

   paintapi_point_t cross1[8] = {
      { xp-10, yp },
      { xp-1,  yp },
      { xp,    yp-10 },
      { xp,    yp-1 },
      { xp+10, yp },
      { xp+1,  yp },
      { xp,    yp+10 },
      { xp,    yp+1 },
   };

   xp += 30;

   paintapi_point_t cross2[8] = {
      { xp-10, yp },
      { xp-1,  yp },
      { xp,    yp-10 },
      { xp,    yp-1 },
      { xp+1,  yp },
      { xp+10, yp },
      { xp,    yp+1  },
      { xp,    yp+10 },
   };

   int i;
   // draw 1 && calculate 3
   for(i=0; i<8; i+=2) {
      a->draw_line(a, white, cross1[i].x, cross1[i].y, cross1[i+1].x, cross1[i+1].y);
      cross1[i].x += 60;
      cross1[i+1].x += 60;
   }

   // draw 2 && calculate 4
   for(i=0; i<8; i+=2) {
      a->draw_line(a, white, cross2[i].x, cross2[i].y, cross2[i+1].x, cross2[i+1].y);
      cross2[i].x += 60;
      cross2[i+1].x += 60;
   }

   // draw 3
   a->draw_segments(a, white, cross1, 8);
   // draw 4
   a->draw_segments(a, white, cross2, 8);

   xp -= 10 + 30;
   yp += 16;

   /////

   draw_text_advance(green, font10, xp, &yp, "A hollow white box with a hollow red box");
   draw_text_advance(green, font10, xp, &yp, "inside whose corner pixels are missing.");

   yp += 6;

   a->draw_rectangle(a, white, 0, xp, yp, xp+10, yp+10);
   a->draw_line(a, red, xp+2, yp+1, xp+10-2, yp+1);
   a->draw_line(a, red, xp+2, yp+10-1, xp+10-2, yp+10-1);
   a->draw_line(a, red, xp+1, yp+2, xp+1, yp+10-2);
   a->draw_line(a, red, xp+10-1, yp+2, xp+10-1, yp+10-2);

   yp += 16;

   /////

   draw_text_advance(green, font10, xp, &yp, "A hollow white box with a hollow red box");
   draw_text_advance(green, font10, xp, &yp, "inside (corners not missing).");

   yp += 6;

   a->draw_rectangle(a, white, 0, xp, yp, xp+10, yp+10);
   a->draw_rectangle(a, green, 0, xp+1, yp+1, xp+9, yp+9);
   paintapi_point_t points[5] = {
      { xp+1, yp+1 },
      { xp+10-1, yp+1 },
      { xp+10-1, yp+10-1 },
      { xp+1, yp+10-1 },
      { xp+1, yp+2 },
   };

   a->draw_lines(a, red, points, 5);

   yp += 16;

   /////

   draw_text_advance(green, font10, xp, &yp, "There is a black box behind each text");
   draw_text_advance(green, font10, xp, &yp, "field and possibly a grey extension area");
   draw_text_advance(green, font10, xp, &yp, "for negative xl,yt values in");
   draw_text_advance(green, font10, xp, &yp, "paintapi_textlayout_extents_t. Text must");
   draw_text_advance(green, font10, xp, &yp, "not exit this area. Red boxes indicate");
   draw_text_advance(green, font10, xp, &yp, "positive xl,yt values. The white dot");
   draw_text_advance(green, font10, xp, &yp, "indicates the draw_text(x1,y1) coordinate.");

   yp += 6;

   do_font_test(font10, xp, &yp, "Testing 012345,!\xC3\x85\xC3\x84\xC3\x96\xC3\xA5\xC3\xA4\xC3\xB6.");
   do_font_test(font10, xp, &yp, "Testing 012345,!AAOaao.");
   do_font_test(font20, xp, &yp, "T5\xC3\x85\xC3\xA5.");
   do_font_test(font20, xp, &yp, "T5Aa.");

   yp += 5;

   ///////////// right side

   xp = xe/2;
   yp = 55;

   draw_text_advance(green, font10, xp, &yp, "Four pairs of dashed lines. Both lines");
   draw_text_advance(green, font10, xp, &yp, "in each pair should look the same.");

   yp += 6;

   yp += 2;

   const int d2 = 45;
   const int d3 = 90;
   const int d4 = 135;

   a->draw_line(a, dash,  xp, yp, xp+29, yp); // line 1
   a->draw_line(a, dash,  xp+d2, yp, xp+d2+29, yp); // line 2
   a->gc_set_dashes(a, dash, 0, dashes, 2);
   a->draw_line(a, dash,  xp+d3, yp, xp+d3+28, yp); // line 3
   a->gc_set_dashes(a, dash, -17, dashes, 2);
   a->draw_line(a, dash,  xp+d4, yp, xp+d4+28, yp); // line 4

   int q,w;

   yp += 2;
   // manually painted line 1 pair
   a->draw_line(a, white, xp, yp, xp+2, yp);
   for(q=0; q<3; ++q) {
      a->draw_line(a, white, xp+5 + q*7, yp, xp+9 + q*7, yp);
   }
   a->draw_line(a, white, xp+5 + 3*7, yp, xp+29, yp);

   // manually painted line 2 pair
   for(q=0; q<=2; ++q) {
      a->draw_line(a, white, xp+d2+q, yp, xp+d2+q, yp);
   }
   for(q=0; q<3; ++q) {
      for(w=5; w<=9; ++w) {
	 a->draw_line(a, white, xp+d2+w + q*7, yp, xp+d2+w + q*7, yp);
      }
   }
   for(q=xp+d2+5 + 3*7; q<=xp+d2+29; ++q) {
      a->draw_line(a, white, q, yp, q, yp);
   }

   // manually painted line 3 pair
   for(q=0; q<4; ++q) {
      a->draw_line(a, white, xp+d3 + q*7, yp, xp+d3+4 + q*7, yp);
   }

   // manually painted line 4 pair
   a->draw_line(a, white, xp+d4, yp, xp+d4, yp);
   for(q=0; q<3; ++q) {
      a->draw_line(a, white, xp+d4+3 + q*7, yp, xp+d4+7 + q*7, yp);
   }
   a->draw_line(a, white, xp+d4+3 + 3*7, yp, xp+d4+28, yp);


   yp += 10;

   /////

   draw_text_advance(green, font10, xp, &yp, "Two filled white boxes with one a");
   draw_text_advance(green, font10, xp, &yp, "one-pixel-wide red line between.");

   yp += 6;

   a->draw_line(a, red, xp+11, yp, xp+11, yp+10);
   a->draw_rectangle(a, white, 1, xp, yp, xp+10, yp+10);
   a->draw_rectangle(a, white, 1, xp+12, yp, xp+22, yp+10);

   yp += 16;

   /////

   draw_text_advance(green, font10, xp, &yp, "A filled white box with a hollow red box on");
   draw_text_advance(green, font10, xp, &yp, "top whose corners are one pixel towards");
   draw_text_advance(green, font10, xp, &yp, "the center from the white box corners.");

   yp += 6;

   a->draw_rectangle(a, white, 1, xp, yp, xp+10, yp+10);
   a->draw_rectangle(a, red, 0, xp+1, yp+1, xp+9, yp+9);

   yp += 16;

   /////

   draw_text_advance(green, font10, xp, &yp, "Two filled boxes which XOR each other");
   draw_text_advance(green, font10, xp, &yp, "which should leave a hole where");
   draw_text_advance(green, font10, xp, &yp, "they overlap.");

   yp += 6;

   a->draw_rectangle(a, xor, 1, xp, yp, xp+10, yp+10);
   a->draw_rectangle(a, xor, 1, xp+6, yp+6, xp+16, yp+16);

   yp += 22;

   /////

   draw_text_advance(green, font10, xp, &yp, "Some lines in yellow..");

   yp += 6;

   paintapi_point_t points2[7] = {
      { xp, yp },
      { xp+5, yp+10},
      { xp+10, yp-1 },
      { xp+15, yp-1 },
      { xp+20, yp+5 },
      { xp+25, yp+20 },
      { xp+30, yp+14 },
   };

   a->draw_lines(a, yellow, points2, 7);

   yp += 26;

   /////

   do_font_test(font10, xp, &yp, "tak");
   do_font_test(font10, xp, &yp, "2005-02-02");
   do_font_test(font10, xp, &yp, "2005.02.02");

   /////

   a->gc_free(a, red);
   a->gc_free(a, green);
   a->gc_free(a, blue);
   a->gc_free(a, yellow);
   a->gc_free(a, white);
   a->gc_free(a, black);
   a->gc_free(a, dash);
   a->gc_free(a, xor);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
