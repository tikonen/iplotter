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
/*
 *  paintapi-cocoa.c
 *  Plotter
 *
 *  Created by Teemu Ikonen on 3/3/06.
 *
 */

#include "paintapi-cocoa.h"

#include "whls.h"

typedef struct {
	// pointer to supersructure
	paintapi_t api;
	
	// plot instructions and the datasets
	my_plot_draw_t *plotdraw;
			
} paintapi_cocoa_t;

typedef struct {
	ATSUTextLayout layout;
	
	// text in UTF-16 format
	char *utext; 
} paintapi_cocoa_textlayout_t;

typedef struct {
	paintapi_rgb_t color; // current color
	float *dashes;
	int dash_count;
} paintapi_cocoa_gc_t;

static paintapi_rgb_t gWhiteColor = { 0xffff, 0xffff, 0xffff };

static	paintapi_gc_t *lastcontext = 0;

static void gc_set_foreground(paintapi_t *api_instance, paintapi_gc_t *gc, paintapi_rgb_t *color) {
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;	
	paintapi_rgb_t c = *color;
	
	if(cocoaapi->plotdraw->inverse_colors) {
		WHLSColor whls;
		rgb_to_whls(&c, &whls);
		whls.wv = 1 - whls.wv;
		whls_to_rgb(&whls, &c);
	}
	
	context->color = c;	
}


static paintapi_gc_t *gc_new(paintapi_t *api_instance) {
		
    //paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;
	
	paintapi_cocoa_gc_t *gc = zmalloc_c(sizeof(paintapi_cocoa_gc_t));
	
	gc_set_foreground(api_instance, (paintapi_gc_t*)gc, &gWhiteColor);
	
	return (paintapi_gc_t*)gc;
}

static void gc_free(paintapi_t *api_instance, paintapi_gc_t *gc)  {
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;
	if(context) {
		free(context->dashes);
		free(context);
	}
}

static void setContextLineDash(CGContextRef myContext, float *dasharray, int dash_list_len)
{
	CGContextSetLineDash(myContext, 0 , dasharray, dash_list_len);
}

static void gc_set_dashes(paintapi_t *api_instance, paintapi_gc_t *gc, int dash_offset, const char *dash_list, int dash_list_len) {

	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;	
	
	if(!context->dashes) {
		context->dashes = malloc(sizeof(float)*10);
	}
	context->dash_count = dash_list_len;
		
	int i;
	for(i=0; i < dash_list_len && i < 10; i++) {
		context->dashes[i] = dash_list[i];
	}
}


static void setContextColor(CGContextRef myContext, paintapi_rgb_t *color) 
{
	paintapi_rgb_t c = *color;
	float r = c.r;
	float g = c.g;
	float b = c.b;
	
	r /= 0xffff;
	g /= 0xffff;
	b /= 0xffff;
	
	CGContextSetRGBStrokeColor(myContext,r,g,b,1);
	CGContextSetRGBFillColor(myContext,r,g,b,1);
}

static void gc_set_function(paintapi_t *api_instance, paintapi_gc_t *gc, paintapi_function_t function) {
/*
	CGContextRef myContext = [(NSGraphicsContext *)gc graphicsPort];
	
	switch(function) {
		case PAINTAPI_FUNCTION_SET:
			CGContextSetBlendMode(myContext,kCGBlendModeNormal);
			break;
		case PAINTAPI_FUNCTION_XOR:
			CGContextSetBlendMode(myContext,kCGBlendModeScreen);
			break;
	}
	*/
}

static void draw_line(paintapi_t *api_instance, paintapi_gc_t *gc, int x1, int y1, int x2, int y2) {

	// set some defaults
	CGContextRef myContext = [[NSGraphicsContext currentContext] graphicsPort];
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;		
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;
	
	if(lastcontext != gc) { 
		setContextColor(myContext,&context->color);
		setContextLineDash(myContext,context->dashes, context->dash_count);
	}
	lastcontext = gc;
		
	CGContextMoveToPoint(myContext,x1,-y1+cocoaapi->plotdraw->plot_ye);
	CGContextAddLineToPoint(myContext,x2,-y2+cocoaapi->plotdraw->plot_ye);
	CGContextDrawPath(myContext,kCGPathStroke);
}

static void draw_segments(paintapi_t *api_instance, paintapi_gc_t *gc, paintapi_point_t *segment_list, int segment_list_len)
{
	CGContextRef myContext = [[NSGraphicsContext currentContext] graphicsPort];
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;		
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;
	
	if(lastcontext != gc) { 
		setContextColor(myContext,&context->color);
		setContextLineDash(myContext,context->dashes, context->dash_count);
	}
	lastcontext = gc;
	
	CGContextBeginPath(myContext);
	
	int idx;
	for(idx = 0; idx < 2*segment_list_len ; idx+=2)  { 
		CGContextMoveToPoint(myContext,segment_list[idx].x,-segment_list[idx].y + cocoaapi->plotdraw->plot_ye);
		CGContextAddLineToPoint(myContext,segment_list[idx+1].x,-segment_list[idx+1].y + cocoaapi->plotdraw->plot_ye);
	}	
	CGContextDrawPath(myContext,kCGPathStroke);
}

static void draw_lines(paintapi_t *api_instance, paintapi_gc_t *gc, paintapi_point_t *point_list, int point_list_len) {
	CGContextRef myContext = [[NSGraphicsContext currentContext] graphicsPort];
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;		
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;

	if(lastcontext != gc) { 
		setContextColor(myContext,&context->color);
		setContextLineDash(myContext,context->dashes, context->dash_count);
	}
	lastcontext = gc;

	CGContextBeginPath(myContext);
	CGContextMoveToPoint(myContext,point_list[0].x,-point_list[0].y + cocoaapi->plotdraw->plot_ye);
	int idx;
	for(idx = 1; idx < point_list_len ; idx++)  { 
		CGContextAddLineToPoint(myContext,point_list[idx].x,-point_list[idx].y + cocoaapi->plotdraw->plot_ye);
	}
	CGContextDrawPath(myContext,kCGPathStroke);
}

static void draw_closed_path(paintapi_t *api_instance, paintapi_gc_t *gc, pa_boolean filled, paintapi_point_t *point_list, int point_list_len)
{
	CGContextRef myContext = [[NSGraphicsContext currentContext] graphicsPort];
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;		
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;

	if(lastcontext != gc) { 
		setContextColor(myContext,&context->color);
		setContextLineDash(myContext,context->dashes, context->dash_count);
	}
	lastcontext = gc;

	CGContextMoveToPoint(myContext,point_list[0].x,-point_list[0].y + cocoaapi->plotdraw->plot_ye);
	int idx;
	for(idx = 1; idx < point_list_len ; idx++)  { 
		CGContextAddLineToPoint(myContext,point_list[idx].x,-point_list[idx].y + cocoaapi->plotdraw->plot_ye);
	}	
	CGContextClosePath(myContext);
	if(filled) {
		CGContextFillPath(myContext);
	} else {
		CGContextDrawPath(myContext,kCGPathStroke);
	}
}

static void draw_rectangle(paintapi_t *api_instance, paintapi_gc_t *gc, pa_boolean filled, int x1, int y1, int x2, int y2) {
	CGContextRef myContext = [[NSGraphicsContext currentContext] graphicsPort];
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;		
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;

	if(lastcontext != gc) { 
		setContextColor(myContext,&context->color);
		setContextLineDash(myContext,context->dashes, context->dash_count);
	}
	lastcontext = gc;
	
	int height = abs(y2-y1)+1;
	int width = abs(x2-x1)+1;
	
	// x1/y1 = top/left x2/y2 = right/bottom
	y1 = -y1 + cocoaapi->plotdraw->plot_ye;
	y2 = -y2 + cocoaapi->plotdraw->plot_ye;
	
	if(filled) {
		// use ready function
		CGContextFillRect(myContext,CGRectMake(x1,y1-height,width+1,height+1));
	} else {
		// draw using lines
		CGContextMoveToPoint(myContext,x1,y1);
		CGContextAddLineToPoint(myContext,x2,y1);
		CGContextAddLineToPoint(myContext,x2,y2);
		CGContextAddLineToPoint(myContext,x1,y2);
		CGContextAddLineToPoint(myContext,x1,y1);
		CGContextDrawPath(myContext,kCGPathStroke);
	}
}

static paintapi_textlayout_t *textlayout_create(paintapi_t *api_instance, paintapi_font_t *font, const char *text) {

	paintapi_cocoa_textlayout_t *layout = zmalloc_c(sizeof(paintapi_cocoa_textlayout_t));
	
	// convert input text (UTF-8) to UTF-16
	CFRange		r;
	CFStringRef cfstr = CFStringCreateWithBytes(NULL, (unsigned char *)text, strlen(text),kCFStringEncodingUTF8, 0);
	r.location = 0;
    r.length = CFStringGetLength(cfstr);
	
	char *textu = malloc(r.length*2);
	CFIndex len;
	
	CFStringGetBytes(cfstr, r,kCFStringEncodingUTF16,0,0,(unsigned char*)textu,r.length*2,&len);
	CFRelease(cfstr);
	OSStatus status = noErr;
	
	// style runs
	UniCharCount styleRuns[] = { kATSUToTextEnd };
		
	status = ATSUCreateTextLayoutWithTextPtr ((UniChar*) textu,
                kATSUFromTextBeginning,  // offset from beginning
                kATSUToTextEnd,         // length of text range
                r.length,      // length of text buffer
                1,                      // number of style runs
                styleRuns,         // length of the style run
                (ATSUStyle *)&font,  // array of styles 
                &layout->layout);
	
	ATSUAttributeTag  theTags[] =  {kATSULineFlushFactorTag,  
                            kATSULineJustificationFactorTag};
	ByteCount   theSizes[] = {sizeof(Fract), sizeof(Fract)};
	Fract   myFlushFactor = kATSUStartAlignment;
	Fract   myJustFactor = kATSUFullJustification;
 
	ATSUAttributeValuePtr theValues[] = {&myFlushFactor, &myJustFactor};
	
	status = ATSUSetLayoutControls (layout->layout,
                            2, 
                            theTags, 
                            theSizes, 
                            theValues);
	layout->utext = textu;						
	return (paintapi_textlayout_t *)layout;
}

static void textlayout_free(paintapi_t *api_instance, paintapi_textlayout_t *layout) {
	paintapi_cocoa_textlayout_t *clayout = (paintapi_cocoa_textlayout_t *)layout;
    
	ATSUDisposeTextLayout(clayout->layout);
	free(clayout->utext);
	free(clayout);
}

static void textlayout_calculate_size(paintapi_t *api_instance, paintapi_textlayout_t *layout, paintapi_textlayout_extents_t *size) {
	paintapi_cocoa_textlayout_t *clayout = (paintapi_cocoa_textlayout_t *)layout;
	
	OSStatus status = noErr;
	Rect outrect;
	
	status = ATSUMeasureTextImage(clayout->layout,
						 kATSUFromTextBeginning,
						 kATSUToTextEnd,
						 0,  // only size
						 0,  // only size
						 &outrect);
						 
	size->xl = outrect.left;
	size->yt = outrect.top;
	size->xr = outrect.right+1;
	size->yb = outrect.bottom+1;
}

static void textlayout_set_strikeout(paintapi_t *api_instance, paintapi_textlayout_t *layout) {

	// TODO: implement
}

static void draw_textlayout(paintapi_t *api_instance, paintapi_gc_t *gc, int x1, int y1, paintapi_textlayout_t *layout) {
	CGContextRef myContext = [[NSGraphicsContext currentContext] graphicsPort];
	paintapi_cocoa_gc_t *context = (paintapi_cocoa_gc_t *)gc;		
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;
	paintapi_cocoa_textlayout_t *clayout = (paintapi_cocoa_textlayout_t*)layout;

	if(lastcontext != gc) {
	  setContextColor(myContext,&context->color);
	} 
	lastcontext = gc;
		
	OSStatus status = noErr;

	ATSUAttributeTag        theTags[] = { kATSUCGContextTag };
	ByteCount               theSizes[] = { sizeof (CGContextRef) };
	ATSUAttributeValuePtr   theValues[] = { &myContext };
 
	ATSUSetLayoutControls (clayout->layout, 
                    1, 
                    theTags, 
                    theSizes, 
                    theValues);

	status = ATSUDrawText(clayout->layout,
						  kATSUFromTextBeginning,
						  kATSUToTextEnd,
						  Long2Fix(x1),
						  Long2Fix(-y1+cocoaapi->plotdraw->plot_ye));						  	
}

static void draw_text(paintapi_t *api_instance, paintapi_gc_t *gc, paintapi_font_t *font, int x1, int y1, const char *text) {
	paintapi_textlayout_t *layout = textlayout_create(api_instance, font, text);
	draw_textlayout(api_instance, gc, x1, y1, layout);
	textlayout_free(api_instance,layout);
}


static void api_free(paintapi_t *api_instance) {
	paintapi_cocoa_t *cocoaapi = (paintapi_cocoa_t*)api_instance;
	free(cocoaapi);
}

paintapi_t *paintapi_cocoa_new(my_plot_draw_t *plotdraw) {
	paintapi_cocoa_t *cocoaapi = zmalloc_c(sizeof(paintapi_cocoa_t));
	
	cocoaapi->api.api_free = api_free;
	cocoaapi->api.gc_new = gc_new;
	cocoaapi->api.gc_free = gc_free;
	cocoaapi->api.gc_set_dashes = gc_set_dashes;
	cocoaapi->api.gc_set_foreground = gc_set_foreground;
	cocoaapi->api.gc_set_function = gc_set_function;
	
	cocoaapi->api.draw_line = draw_line;
	cocoaapi->api.draw_lines = draw_lines;
	cocoaapi->api.draw_segments = draw_segments;
	cocoaapi->api.draw_closed_path = draw_closed_path;
	cocoaapi->api.draw_rectangle = draw_rectangle;
	cocoaapi->api.draw_text = draw_text;
	cocoaapi->api.draw_textlayout = draw_textlayout;
	
	cocoaapi->api.textlayout_create = textlayout_create;
	cocoaapi->api.textlayout_free = textlayout_free;
	cocoaapi->api.textlayout_calculate_size = textlayout_calculate_size;
	cocoaapi->api.textlayout_set_strikeout = textlayout_set_strikeout;
	
	cocoaapi->plotdraw = plotdraw;
		
	return (paintapi_t*)cocoaapi;
}
