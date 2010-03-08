/*
 * iPlotter - Port of plot on Mac OS X Cocoa
 * Copyright (C) 2006  Teemu Ikonen <teemu.ikonen@iki.fi>
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
 */
/* PlotDocument */

#import <Cocoa/Cocoa.h>

#include "plot_draw.h"

@interface PlotDocument : NSDocument
{
	// structure containing datasets and their lines
	my_plot_draw_t plotdraw;
	
	// growing number to select line color for new lines
	int linecoloroffset;
	
	// initial number of lines after load
	int linesetcount;
}

- (my_dataset_t *)readDataFile:(NSURL *)absoluteURL error:(NSError **)outError;
- (my_plot_draw_t *)plotDraw;
@end
