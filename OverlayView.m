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
//
//  OverlayView.m
//  Plotter
//
//  Created by Teemu Ikonen on 3/6/06.
//

#import "OverlayView.h"

@implementation OverlayView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		ghostposition = -1;
		selectRect = NSZeroRect;
		needsCleanUp = NO;
    }
    return self;
}

- (NSRect)selectRect; {
	return selectRect;
}

- (void)setSelectRect:(NSRect) rect
{
	if(NSEqualRects(rect, NSZeroRect)) {
	  needsCleanUp = YES;
    }

	selectRect = rect;
}

- (void)setBookmarkGhost:(float) xoffset
{
	if(xoffset < 0) {
		needsCleanUp = YES;
	}
	
	ghostposition = xoffset;
}

- (float)bookmarkGhost
{
	return ghostposition;
}


- (void)drawRect:(NSRect)rect {
    
	if(NSEqualRects(selectRect,NSZeroRect) && !needsCleanUp && ghostposition < 0) {
		return;
	}
	
	// clear
	[[NSColor clearColor] setFill];
	NSRectFill(rect);
	
	if(!needsCleanUp) {
		if(ghostposition > 0) {
			[[NSColor colorWithCalibratedRed: 1 green: 1 blue: 1 alpha: 0.9] setFill];
			[NSBezierPath fillRect:NSMakeRect(ghostposition-1.5,0,3,rect.size.height)];
			NSBezierPath *path = [NSBezierPath bezierPath];
			//[path setLineWidth:4];
			[path moveToPoint:NSMakePoint(ghostposition,rect.size.height-10)];
			[path lineToPoint:NSMakePoint(ghostposition+10,rect.size.height)];
			[path lineToPoint:NSMakePoint(ghostposition-10,rect.size.height)];
			[path lineToPoint:NSMakePoint(ghostposition,rect.size.height-10)];
			//[path closePath];
			//[path stroke];
			[path fill];
		} else {
			[[NSColor colorWithCalibratedRed: 1 green: 1 blue: 1 alpha: 0.5] setFill];
			NSRectFill(selectRect);
		}
	} else {
		needsCleanUp = NO;
	}
}

@end
