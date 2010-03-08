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
#import "PlotDrawView.h"
#import "PlotDocument.h"
#import <plot_draw.h>
#import <paintapi-test.h>

#import "PlotDrawWindowController.h"

@implementation PlotDrawView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
	
	/*
		// get font id
		OSStatus status = noErr;
		ATSUFontID fontID;
		status = ATSUFindFontFromName("Helvetica",
									  9,
									  kFontPostscriptName,
									  kFontMacintoshPlatform,
									  kFontRomanScript,
									  kFontNoLanguageCode,
									  &fontID);
								
		// ATSUStyle arrays
		status = ATSUCreateStyle(&font10Style);
		
		ATSUAttributeTag  theTags[] =  {kATSUSizeTag, kATSUQDBoldfaceTag, kATSUFontTag};
		ByteCount        theSizes[] = {sizeof(Fixed), sizeof(Boolean), sizeof(ATSUFontID)};
		
		Fixed   atsuSize = Long2Fix(12);
		Boolean isBold = FALSE;
		ATSUAttributeValuePtr theValues[] = {&atsuSize, &isBold, &fontID};
		
		status = ATSUSetAttributes (font10Style,
									3, 
									theTags, 
									theSizes, 
									theValues);
		
		status = ATSUCreateAndCopyStyle(font10Style,&font20Style);
		
		ATSUAttributeTag  theTags2[] =  {kATSUSizeTag};
		ByteCount        theSizes2[] = {sizeof(Fixed)};
		
		atsuSize = Long2Fix(20);
		ATSUAttributeValuePtr theValues2[] = {&atsuSize};
		
		status = ATSUSetAttributes (font20Style,
									1, 
									theTags2, 
									theSizes2, 
									theValues2);
									
	*/	
		// declare drag destination
		[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
		
	}
	return self;
}

- (void)dealloc {
	/*
	ATSUDisposeStyle(font10Style);
	ATSUDisposeStyle(font20Style);	
	*/
    [super dealloc];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
 
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
 
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        } else if (sourceDragMask & NSDragOperationLink) {
			return NSDragOperationLink;
		}
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
	
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
	
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

		NSArray *URLs = [[NSArray alloc] init];
		
		unsigned int i;
		for(i = 0; i < [files count] ; i++) {
			NSString *file = [files objectAtIndex:i];
			URLs = [URLs arrayByAddingObject: [[NSURL alloc] initFileURLWithPath:file]];
		}
		
		[controller addFiles:URLs];
    }
    return YES;
}


/*
-(void) debugPrintText:(CGContextRef) myContext: (NSRect)bounds
{
	// convert input text (UTF-8) to UTF-16
	const char *text = "FooBar";
	
	CFRange		r;
	CFStringRef cfstr = CFStringCreateWithBytes(NULL, text, strlen(text),kCFStringEncodingUTF8, 0);
	r.location = 0;
	r.length = CFStringGetLength(cfstr);
	char *textu = malloc(r.length*2);
	CFIndex len;
	
	CFStringGetBytes(cfstr, r,kCFStringEncodingUTF16,0,0,textu,r.length*2,&len);
	CFRelease(cfstr);
	OSStatus status = noErr;
	
	// style runs
	UniCharCount styleRuns[] = { kATSUToTextEnd };
	
	ATSUTextLayout layout;
	status = ATSUCreateTextLayoutWithTextPtr ((UniChar*) textu,
											  kATSUFromTextBeginning,  // offset from beginning
											  kATSUToTextEnd,         // length of text range
											  r.length,      // length of text buffer
											  1,                      // number of style runs
											  styleRuns,         // length of the style run
											  &font10Style,  // array of styles 
											  &layout);
	
	ATSUAttributeTag  theTags[] =  {kATSULineFlushFactorTag,  
		kATSULineJustificationFactorTag};
	ByteCount   theSizes[] = {sizeof(Fract), sizeof(Fract)};
	Fract   myFlushFactor = kATSUStartAlignment;
	Fract   myJustFactor = kATSUFullJustification;
	
	ATSUAttributeValuePtr theValues[] = {&myFlushFactor, &myJustFactor};
	
	status = ATSUSetLayoutControls (layout,
									2, 
									theTags, 
									theSizes, 
									theValues);
	
	
	CGContextSetRGBFillColor(myContext,1,1,1,1);			
	int i,j;
	for(i = 0,j = 0; i < bounds.size.width && j < bounds.size.height-20; i += 20, j += 20) {
		
		
		ATSUAttributeTag        theTags[] = { kATSUCGContextTag };
		ByteCount               theSizes[] = { sizeof (CGContextRef) };
		ATSUAttributeValuePtr   theValues[] = { &myContext };
		
		ATSUSetLayoutControls (layout, 
							   1, 
							   theTags, 
							   theSizes, 
							   theValues);
		
		status = ATSUDrawText(layout,
							  kATSUFromTextBeginning,
							  kATSUToTextEnd,
							  Long2Fix(i),
							  Long2Fix(j));
		
	}
	free(textu);
	ATSUDisposeTextLayout(layout);
	
	
}
*/

/*
void disable_plot_draw_bookmarks(my_plot_draw_t *plotdraw) 
{
	// triangle context
	NSGraphicsContext *nsgc = [NSGraphicsContext currentContext];
	CGContextRef myContext = [nsgc graphicsPort];
	CGContextSetRGBFillColor(myContext,1,1,0,1);

	paintapi_rgb_t bookmarkcolor = { 0xffff, 0xffff, 0x0000 };
	
	paintapi_t *api = plotdraw->paintapi;
	paintapi_gc_t *gc = api->gc_new(api);
	api->gc_set_foreground(api,gc,&bookmarkcolor);
	
	float xoffset = plotdraw->plot_xe/2 - 100;
	
	api->gc_set_dashes(api,gc,0,"\x10\x3",2);	
	api->draw_line(api,gc,xoffset, plotdraw->plot_yde,xoffset,0);
	
	CGContextBeginPath(myContext);
	CGContextMoveToPoint(myContext,xoffset,-10+plotdraw->plot_ye);
	CGContextAddLineToPoint(myContext,xoffset+10,plotdraw->plot_ye);	
	CGContextAddLineToPoint(myContext,xoffset-10,plotdraw->plot_ye);	
	//CGContextAddLineToPoint(myContext,xe+1,0);
	CGContextClosePath(myContext);
	CGContextFillPath(myContext);
	
	char tmp[100];
	snprintf(tmp,sizeof(tmp), "(%d)",1);
	paintapi_textlayout_t *layout = api->textlayout_create(api, plotdraw->font_yaxis, tmp);
	paintapi_textlayout_extents_t ri;
	api->textlayout_calculate_size(api, layout, &ri);
	
	api->draw_textlayout(api, gc, xoffset+7, 0 + 7 - ri.yt, layout);	
	api->textlayout_free(api, layout);
	
	xoffset = plotdraw->plot_xe/2;
	api->draw_line(api,gc,xoffset, plotdraw->plot_yde,xoffset,0);

	CGContextBeginPath(myContext);
	CGContextMoveToPoint(myContext,xoffset,-10+plotdraw->plot_ye);
	CGContextAddLineToPoint(myContext,xoffset+10,plotdraw->plot_ye);	
	CGContextAddLineToPoint(myContext,xoffset-10,plotdraw->plot_ye);	
	//CGContextAddLineToPoint(myContext,xe+1,0);
	CGContextClosePath(myContext);
	CGContextFillPath(myContext);

	snprintf(tmp,sizeof(tmp), "(%d) Tuli levisi yli maan",1);
	layout = api->textlayout_create(api, plotdraw->font_yaxis, tmp);
	ri;
	api->textlayout_calculate_size(api, layout, &ri);
	
	int width = abs(ri.xr - ri.xl);
	int height = abs(ri.yt - ri.yb);
	int poledistance = 20;
	
	api->draw_rectangle(api,gc,1,xoffset+poledistance,20,xoffset+poledistance+width+10,20+height);
	
	paintapi_rgb_t bookmarktextcolor = { 0x0000, 0x0000, 0x0000 };
	paintapi_gc_t *gc2 = api->gc_new(api);
	api->gc_set_foreground(api,gc2,&bookmarktextcolor);	
	api->draw_textlayout(api, gc2, xoffset+poledistance, 20 - ri.yt, layout);	
	api->textlayout_free(api, layout);
	
	api->draw_line(api,gc,xoffset,20+height+20,xoffset+poledistance,20+height);
	
	api->gc_free(api,gc);
	api->gc_free(api,gc2);	
}
*/

- (void)drawRect:(NSRect)rect
{
	//NSRect br = [self bounds];
	NSGraphicsContext *gc = [NSGraphicsContext currentContext];
	CGContextRef myContext = [gc graphicsPort];
	my_plot_draw_t *plotdraw = [[controller document] plotDraw];

	CGContextSetShouldAntialias(myContext,FALSE);

	if(plotdraw->inverse_colors) {
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
	CGContextSetLineWidth(myContext,1.0);
    CGContextSetRGBStrokeColor(myContext,1,1,1,1);
	CGContextSetAlpha(myContext,1);
		
	// Compensate horizontal scrollbar offset
	float yoffset = [controller yOffset];
	CGContextTranslateCTM(myContext,0.5,0.5 + yoffset);
	
	if(plotdraw) {
		CGContextBeginPath(myContext);
		CGContextMoveToPoint(myContext,0,0);
		CGContextAddLineToPoint(myContext,0,rect.size.height);	
		CGContextAddLineToPoint(myContext,rect.size.width,rect.size.height);	
		CGContextAddLineToPoint(myContext,rect.size.width,0);
		CGContextClosePath(myContext);
		CGContextClip(myContext);
		
		//paintapi_test(plotdraw->paintapi, (paintapi_font_t*)font10Style, (paintapi_font_t*)font20Style, br.size.width-1,br.size.height-1);	
		
		//if(![self inLiveResize]) {
		// TODO: something to lighten up
		// }
		
		// setup gc
		plot_draw_setup_gcs(plotdraw);
		plot_draw_grid_precalc(plotdraw);
		plot_draw_lines(plotdraw);
		plot_draw_time_grid(plotdraw);		
		plot_draw_value_grid(plotdraw);
		plot_draw_bookmarks(plotdraw);
		plot_draw_legend(plotdraw);
	}
}


- (BOOL)isOpaque 
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return NO;
}

- (void)setPlotDrawWindowController:(PlotDrawWindowController *)theController {
    controller = theController;
}

- (PlotDrawWindowController *)plotDrawWindowController {
    return controller;
}

@end
