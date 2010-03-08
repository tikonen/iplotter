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
//  PrintView.m
//  Plotter
//
//  Created by Teemu Ikonen on 3/13/06.
//

#import <plot_draw.h>

#import "PrintView.h"

@implementation PrintView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)dealloc {
	ATSUDisposeStyle((ATSUStyle)plotdraw->legend.font);	
	plot_draw_remove_all_data_files(plotdraw);
	plotdraw->paintapi->api_free(plotdraw->paintapi);
	free(plotdraw);
    [super dealloc];
}

- (void)setDocument:(NSDocument *)doc
{
	document = doc;
}

- (void)setPlotDraw:(my_plot_draw_t *)plot
{
	plotdraw = plot;
}

- (void)drawPageBorderWithSize:(NSSize) borderSize {
	NSRect orgFrame = [self frame];

	[self setFrame:NSMakeRect(0,0,borderSize.width,borderSize.height)];
	
	// draw the filename
	NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:[[[document fileURL] path] lastPathComponent]];
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
	NSTextContainer *textContainer = [[NSTextContainer alloc] init];
	[layoutManager addTextContainer:textContainer];
	[textContainer release];
	[textStorage addLayoutManager:layoutManager];	
		
	NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
	NSRect area = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
	[self lockFocus];
	[layoutManager drawGlyphsForGlyphRange: glyphRange atPoint: NSMakePoint(borderSize.width/2 - area.size.width/2,borderSize.height - 2*area.size.height)];
	[self unlockFocus];
	[textStorage release];
	[layoutManager removeTextContainerAtIndex:0];
	//textStorage = [[NSTextStorage alloc] initWithString:[[[document fileURL] path] lastPathComponent]];
	
	// draw the start date
	const char *label;
	
	label = format_time2(plotdraw->xmin, TIME_FIELD_SEC, TIME_FIELD_YEAR);		
	NSString *s = [NSString stringWithCString:label length:strlen(label)];

	textContainer = [[NSTextContainer alloc] init];
	[layoutManager addTextContainer:textContainer];
	textStorage = [[NSTextStorage alloc] initWithString:s];	
	[textStorage addLayoutManager:layoutManager];	
	glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
	area = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
	[self lockFocus];
	[layoutManager drawGlyphsForGlyphRange: glyphRange atPoint: NSMakePoint(5,5)];
	[self unlockFocus];
	[textStorage release];
	[layoutManager removeTextContainerAtIndex:0];	
	
	// end date
	label = format_time2(plotdraw->xmax, TIME_FIELD_SEC, TIME_FIELD_YEAR);
	s = [NSString stringWithCString:label length:strlen(label)];

	textContainer = [[NSTextContainer alloc] init];
	[layoutManager addTextContainer:textContainer];
	textStorage = [[NSTextStorage alloc] initWithString:s];	
	[textStorage addLayoutManager:layoutManager];	
	glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
	area = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
	[self lockFocus];
	[layoutManager drawGlyphsForGlyphRange: glyphRange atPoint: NSMakePoint(borderSize.width - area.size.width-20,5)];
	[self unlockFocus];
	[textStorage release];
	[layoutManager removeTextContainerAtIndex:0];

	// range
	label = format_difftime(plotdraw->xmax - plotdraw->xmin, TRUE);
	s = [NSString stringWithCString:label length:strlen(label)];

	textContainer = [[NSTextContainer alloc] init];
	[layoutManager addTextContainer:textContainer];
	textStorage = [[NSTextStorage alloc] initWithString:s];
	[textStorage addLayoutManager:layoutManager];	
	glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
	area = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
	[self lockFocus];
	[layoutManager drawGlyphsForGlyphRange: glyphRange atPoint: NSMakePoint(borderSize.width/2 - area.size.width/2,5)];
	[self unlockFocus];
	[textStorage release];
	
	
	[layoutManager release];
	
	[self setFrame:orgFrame];
}

- (void)drawRect:(NSRect)rect
{
	NSGraphicsContext *gc = [NSGraphicsContext currentContext];
	CGContextRef myContext = [gc graphicsPort];
	
	CGContextSetShouldAntialias(myContext,FALSE);
	
	if(plotdraw->inverse_colors) {
		// wheat
		/*
		float r = 245.0 / 255;
		float g = 222.0 / 255;
		float b = 179.0 / 255;
		*/
		// lighter wheat
		float r = 255.0 / 255;
		float g = 246.0 / 255;
		float b = 229.0 / 255;
		
		CGContextSetRGBFillColor(myContext,r,g,b,1);	
	} else {
		CGContextSetRGBFillColor(myContext,0,0,0,1);
	}
	//CGContextSetRGBFillColor(myContext,0.13,.25,0.38,1); // for paintapi_test
	CGContextSetAlpha(myContext,1);
	CGContextSetBlendMode(myContext,kCGBlendModeNormal);
	
	CGContextFillRect(myContext,CGRectMake(0,0,rect.size.width,rect.size.height));
	//CGContextFillRect(myContext,CGRectMake(0,0,plotdraw->plot_xe+1,plotdraw->plot_ye+1));
	
	CGContextSetShouldAntialias(myContext,TRUE);
	CGContextSetLineWidth(myContext,1);
    CGContextSetRGBStrokeColor(myContext,0,0,0,1);
	CGContextSetAlpha(myContext,1);
	
	CGContextTranslateCTM(myContext,0.5,0.5);
	
	if(plotdraw) {
		CGContextSaveGState(myContext);
		
		CGContextBeginPath(myContext);
		CGContextMoveToPoint(myContext,0,0);
		CGContextAddLineToPoint(myContext,0,rect.size.height+1);	
		CGContextAddLineToPoint(myContext,rect.size.width+1,rect.size.height+1);	
		CGContextAddLineToPoint(myContext,rect.size.width+1,0);
		CGContextClosePath(myContext);
		CGContextClip(myContext);
		
		plot_draw_setup_gcs(plotdraw);
		plot_draw_grid_precalc(plotdraw);
		plot_draw_lines(plotdraw);
		plot_draw_time_grid(plotdraw);		
		plot_draw_value_grid(plotdraw);
		plot_draw_bookmarks(plotdraw);
		plot_draw_legend(plotdraw);
		
		CGContextRestoreGState(myContext);
		
		// draw rectangle to border the printout
		CGContextSetRGBStrokeColor(myContext,0,0,0,1);
		CGContextStrokeRect(myContext,CGRectMake(0,0,rect.size.width-1,rect.size.height-1));
		
	}
}

@end
