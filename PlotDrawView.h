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
/* PlotDrawView */

#import <Cocoa/Cocoa.h>

@class PlotDrawWindowController;

@interface PlotDrawView : NSView
{
    IBOutlet PlotDrawWindowController *controller;
	
	/*
	// for test api
	ATSUStyle       font10Style;
	ATSUStyle       font20Style;
	*/
}

- (void)setPlotDrawWindowController:(PlotDrawWindowController *)theController;
- (PlotDrawWindowController *)plotDrawWindowController;
@end
