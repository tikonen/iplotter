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
 * whls - Weighted HLS <-> RGB conversions
 */

#include "whls.h"

typedef struct {

      // rgb multipliers, must satisfy rc + gc + bc = 1
      double rc, gc, bc;

      // how much light is given to grey when whls.value = 0.5 - not
      // fully implemented it seems, keep at 0.5 for now..
      double greyc;

} whls_profile_t;

const whls_profile_t default_prof = {
   rc: 0.37,
   gc: 0.43,
   bc: 0.20,
   greyc: 0.5,
};

void rgb_to_whls(paintapi_rgb_t *rgb, WHLSColor *whls) {
   double r = rgb->r / 65535.0;
   double g = rgb->g / 65535.0;
   double b = rgb->b / 65535.0;

   double h, v, v2, vmin;

   // calculate hue [as it works in HSV], range 0-6 using 2..4 conditions, 3..4 assignments and 0..1 divisions
   if(r >= g) {
      if(r >= b) {
	 if(g >= b) {
	    if(r > b) {
	       v = r; v2 = g; vmin = b;
	       h = (v2 - vmin) / (v - vmin);
	    } else {
	       v = vmin = r;
	       h = 0;
	    }
	 } else {
	    v = r; v2 = b; vmin = g;
	    h = 6 - (v2 - vmin) / (v - vmin);
	 }
      } else {
	 v = b; v2 = r; vmin = g;
	 h = 4 + (v2 - vmin) / (v - vmin);
      }
   } else if(g >= b) {
      if(r >= b) {
	 v = g; v2 = r; vmin = b;
	 h = 2 - (v2 - vmin) / (v - vmin);
      } else {
	 v = g; v2 = b; vmin = r;
	 h = 2 + (v2 - vmin) / (v - vmin);
      }
   } else {
      v = b; v2 = g; vmin = r;
      h = 4 - (v2 - vmin) / (v - vmin);
   }

   whls->h = h;

   // calculate saturation [as it works in HSV], range 0-1
   double s = v > 0 ? 1 - vmin / v : 0;

   // calculate color-agnostic value
   double imv2 = v - s * (1 - default_prof.greyc);

   if(imv2 >= 1) { // never > 1, included for rounding errors' sake
      // middle axis, greyscale
      whls->ms = 0;

   } else if(imv2 <= default_prof.greyc) {
      // lower cone or grey
      whls->ms = s;

   } else { // default_prof.greyc < imv2 < 1
      // upper cone
      whls->ms = s * (1 - default_prof.greyc) / (1 - imv2);
   }

   // calculate color-weighted value
   whls->wv = r * default_prof.rc + g * default_prof.gc + b * default_prof.bc;
}

static double hf(double v, int c) {
   v -= c;
   while(v < -3) v += 6;
   while(3 < v) v -= 6;
   if(-1 <= v && v <= 1) return 1;
   if(-2 < v && v < -1) return v+2;
   if(1 < v && v < 2) return 2-v;
   return 0;
}

static double chr(double v) {
   return hf(v, 0);
}

static double chg(double v) {
   return hf(v, 2);
}

static double chb(double v) {
   return hf(v, 4);
}

void whls_to_rgb(WHLSColor *whls, paintapi_rgb_t *rgb) {
   double h = whls->h;
   double ms = whls->ms;
   double wv = whls->wv;

   double hr = chr(h);
   double hg = chg(h);
   double hb = chb(h);

   // when whsum == 0.5, we are on the
   double whsum = hr * default_prof.rc + hg * default_prof.gc + hb * default_prof.bc;
   double s, v; // as in HSV

   // avoid compiler error ;)
   if(ms >= -0.0 && ms <= 0.0) {
      // middle axis, greyscale
      s = 0;
      v = wv;

   } else if(wv - 0.5 > (whsum - 0.5) * ms) { // same as wv / (whsum * ms + (1 - ms) * 0.5) > 1
      // upper cone
      s = ms * (1 - wv) / (1 - whsum);
      v = wv / (1 - ms * (1 - wv));

   } else {
      // lower cone or grey
      v = wv / (whsum + (1 - whsum) * (1 - ms));
      s = ms;
   }

   double spart = s * v;
   double gpart = (1 - s) * v;

   rgb->r = (hr * spart + gpart) * 65535.0;
   rgb->g = (hg * spart + gpart) * 65535.0;
   rgb->b = (hb * spart + gpart) * 65535.0;
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
