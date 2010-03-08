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
#import "PlotDrawWindowController.h"
#import "PlotDrawView.h"
#import "PlotDocument.h"
#import "OverlayView.h"
#import "PrintView.h"
#import "paintapi-cocoa.h"

#include "misc-util.h"

static inline my_plot_view_range_t _make_ranges(double xmin, double xmax, double ymin, double ymax) 
{
	my_plot_view_range_t ranges;
	ranges.xmax = xmax;
	ranges.xmin = xmin;
	ranges.ymax = ymax;
	ranges.ymin = ymin;
	
	return ranges;
}

@implementation PlotDrawWindowController

- (id)init {
    self = [super initWithWindowNibName:@"PlotWindow"];
	
	zoomHistories = (my_plot_view_range_t*)malloc(10*sizeof(my_plot_view_range_t));
	zoomidx = 0;
	zoomc = 0; 

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowResigned:) name:NSWindowDidResignMainNotification object:nil];	
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidEndEditing:) name:NSTextDidEndEditingNotification object:nil];
	
	// disable window cascading as this causes problems in positioning the overlay window
	//[self setShouldCascadeWindows: NO];
	
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	free(zoomHistories);
		
    // Balance the -setDrawWindowController: that our -windowDidLoad does.
    [plotView setPlotDrawWindowController:nil];
    
	// TODO: cleanup, now the fonts can not be released as the document destructor clears the
	// structure before this code is reached
	
	//ATSUDisposeStyle
	//my_plot_draw_t *plotdraw = [[self document] plotDraw];
	
	//ATSUDisposeStyle((ATSUStyle)plotdraw->font_legend);
	/*
	ATSUDisposeStyle((ATSUStyle)plotdraw->font_legend);
	ATSUDisposeStyle((ATSUStyle)plotdraw->font_xaxis);
	ATSUDisposeStyle((ATSUStyle)plotdraw->font_yaxis);	
	*/
	[overlayWindow release];
	
    [super dealloc];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (IBAction)runPageLayout:(id)sender
{
	[[self document] runPageLayout: sender];
}

// toggles invert colors on and off
- (IBAction)toggleInvertAction:(id)sender
{
	NSMenuItem *menuitem = (NSMenuItem*)sender;
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	plotdraw->inverse_colors = ! plotdraw->inverse_colors;	
	plot_draw_reset_gcs(plotdraw);
	
	[menuitem setState: plotdraw->inverse_colors ? NSOnState : NSOffState];
		
	[plotView setNeedsDisplay: YES];
}



static ATSUStyle _createATSUFont(const char *psname, int dots)
{
	OSStatus status = noErr;
	
	// ATSU code
	
	// get font id
	ATSUFontID fontID;
	status = ATSUFindFontFromName(psname,
								  strlen(psname),
								  kFontPostscriptName,
								  kFontMacintoshPlatform,
								  kFontRomanScript,
								  kFontNoLanguageCode,
								  &fontID);
	
	// ATSUStyle arrays
	ATSUStyle       fontStyle;
	status = ATSUCreateStyle(&fontStyle);
	
	ATSUAttributeTag  theTags[] =  {kATSUSizeTag, kATSUQDBoldfaceTag, kATSUFontTag};
	ByteCount        theSizes[] = {sizeof(Fixed), sizeof(Boolean), sizeof(ATSUFontID)};
	
	Fixed   atsuSize = Long2Fix(dots);
	Boolean isBold = FALSE;
	ATSUAttributeValuePtr theValues[] = {&atsuSize, &isBold, &fontID};
	
	status = ATSUSetAttributes (fontStyle,
								3, 
								theTags, 
								theSizes, 
								theValues);

	if(status == noErr) {
		return fontStyle;
	}
	return 0;
}

// updates text fonts
- (void)updatePlotFonts {

	my_plot_draw_t *plotdraw = [[self document] plotDraw];

	/*
	OSStatus status = noErr;
	
	// ATSU code
	
	// get font id
	ATSUFontID fontID;
	status = ATSUFindFontFromName("Helvetica",
								9,
								kFontPostscriptName,
								kFontMacintoshPlatform,
								kFontRomanScript,
								kFontNoLanguageCode,
								&fontID);
								
	// ATSUStyle arrays
	ATSUStyle       defaultStyle;
	status = ATSUCreateStyle(&defaultStyle);
	
	ATSUAttributeTag  theTags[] =  {kATSUSizeTag, kATSUQDBoldfaceTag, kATSUFontTag};
	ByteCount        theSizes[] = {sizeof(Fixed), sizeof(Boolean), sizeof(ATSUFontID)};
 
	Fixed   atsuSize = Long2Fix(12);
	Boolean isBold = FALSE;
	ATSUAttributeValuePtr theValues[] = {&atsuSize, &isBold, &fontID};
	
	status = ATSUSetAttributes (defaultStyle,
                            3, 
                            theTags, 
                            theSizes, 
                            theValues);
	*/
	ATSUStyle defaultStyle = _createATSUFont("Helvetica",12); 
	// use same font for all
	plotdraw->legend.font = (paintapi_font_t*)defaultStyle;
	plotdraw->grid.font_xaxis = (paintapi_font_t*)defaultStyle;
	plotdraw->grid.font_yaxis = (paintapi_font_t*)defaultStyle;
}

- (void) updateLables {
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	
	time_field_t fieldmin = plotdraw->xmax - plotdraw->xmin < 15000 ? TIME_FIELD_MILLISEC : TIME_FIELD_SEC; 
	time_field_t field = time_diff_field2(plotdraw->xmin, plotdraw->xmax);
	if(field < TIME_FIELD_MIN) {
		field = TIME_FIELD_MIN; 
	}
	/*
	 NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc]
     initWithDateFormat:@"%2H:%2M:%2S %1d.%1m.%Y" allowNaturalLanguage:NO] autorelease];
	 */
	
	const char *label;
	
	if(plotdraw->xmax == initViewRanges.xmax &&
	   plotdraw->xmin == initViewRanges.xmin) {
		label = format_time2(plotdraw->xmin, TIME_FIELD_SEC, TIME_FIELD_YEAR);		
	} else {
		label = format_time2(plotdraw->xmin, fieldmin, field);
	}
	NSString *s = [NSString stringWithCString:label length:strlen(label)];
	[startDateField setStringValue:s];
	
	label = format_time2(plotdraw->xmax, fieldmin, field);
	s = [NSString stringWithCString:label length:strlen(label)];
	[endDateField setStringValue:s];
	
	label = format_difftime(plotdraw->xmax - plotdraw->xmin, TRUE);
	s = [NSString stringWithCString:label length:strlen(label)];
	[rangeField setStringValue:s];
	
	/*
	 NSDate *date = [NSDate dateWithTimeIntervalSince1970:plotdraw->xmin];
	 NSString *s = [dateFormatter stringFromDate:date];
	 [startDateField setStringValue:s];
	 
	 date = [NSDate dateWithTimeIntervalSince1970:plotdraw->xmax];
	 s = [dateFormatter stringFromDate:date];
	 [endDateField setStringValue:s];
	 */
	
	//NSLog(@"formattedDateString: %@", formattedDateString);
}

// updates the maximum ranges from datasets
- (void)updatePlotLimits {
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];

	my_time_t ts = 0, te = 1;
	plot_draw_calc_x_minmax(plotdraw,&ts,&te,NULL);
	plotdraw->xmin = ts;
	plotdraw->xmax = te;
	plotdraw->xstart = ts;
	plotdraw->xend = te;
	
	plot_draw_calc_y_minmax(plotdraw,&plotdraw->ymin,&plotdraw->ymax,NULL,true);

	plotdraw->ymin -= (plotdraw->ymax - plotdraw->ymin)/20;
	plotdraw->ymax += (plotdraw->ymax - plotdraw->ymin)/20;
		
	initViewRanges.xmax = plotdraw->xmax;
	initViewRanges.xmin = plotdraw->xmin;
	initViewRanges.ymax = plotdraw->ymax;
	initViewRanges.ymin = plotdraw->ymin;
	
	zoomHistories[0] = initViewRanges;
	zoomidx = 0;
	zoomc = 0;
	
	[segments setEnabled:NO forSegment:0];
	[segments setEnabled:NO forSegment:1];
	
	[self updateLables];	
}

// enables/disables menu items based on view status
- (void)updateMainMenu {
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	
	// bookmarks
	
	NSMenu *mainmenu = [NSApp mainMenu];
	NSMenuItem *viewitem = [mainmenu itemWithTitle: @"View"];
	NSMenu *viewmenu = [viewitem submenu];
	NSMenuItem *bookmarkitem = [viewmenu itemWithTitle: @"Bookmarks"];
	NSMenu *bookmarkmenu = [bookmarkitem submenu];
	
	
	switch(plotdraw->bookmarks.show) {
		case BOOKMARKS_SHOW:
			[[bookmarkmenu itemWithTag:1] setState:NSOnState];
			[[bookmarkmenu itemWithTag:2] setState:NSOffState];
			[[bookmarkmenu itemWithTag:3] setState:NSOffState];		
			break;
			
		case BOOKMARKS_SHOW_LABEL_ONLY:
			[[bookmarkmenu itemWithTag:2] setState:NSOnState];
			[[bookmarkmenu itemWithTag:1] setState:NSOffState];
			[[bookmarkmenu itemWithTag:3] setState:NSOffState];		
			break;
			
		case BOOKMARKS_HIDE:
			[[bookmarkmenu itemWithTag:3] setState:NSOnState];
			[[bookmarkmenu itemWithTag:1] setState:NSOffState];
			[[bookmarkmenu itemWithTag:2] setState:NSOffState];		
			break;			
	}
	
	// legend
	
	NSMenuItem *legenditem = [viewmenu itemWithTitle: @"Legend"];
	NSMenu *legendmenu = [legenditem submenu];
	
	switch(plotdraw->legend.show) {
		case LEGEND_SHOW_LEFT:
			[[legendmenu itemWithTag:1] setState:NSOnState];			
			[[legendmenu itemWithTag:2] setState:NSOffState];
			[[legendmenu itemWithTag:3] setState:NSOffState];			
			break;
		case LEGEND_SHOW_RIGHT:
			[[legendmenu itemWithTag:2] setState:NSOnState];			
			[[legendmenu itemWithTag:1] setState:NSOffState];
			[[legendmenu itemWithTag:3] setState:NSOffState];			
			break;			
		case LEGEND_HIDE:
			[[legendmenu itemWithTag:3] setState:NSOnState];
			[[legendmenu itemWithTag:1] setState:NSOffState];
			[[legendmenu itemWithTag:2] setState:NSOffState];			
			break;
	}
	
	// other
	
	NSMenuItem *invertitem = [viewmenu itemWithTitle: @"Invert"];
	[invertitem setState: plotdraw->inverse_colors ? NSOnState : NSOffState ];	
}

- (void)mainWindowChanged:(NSNotification *)notification {
	if([notification object] == [self window]) {
		[self updateMainMenu];
	}
}

// adjusts scrollbar location, knob proportion and disables them if full range is visible
- (void)adjustScrollBarRanges {

	my_plot_draw_t *plotdraw = [[self document] plotDraw];

	// compute x-axis
	double range = plotdraw->xmax - plotdraw->xmin;
	double xoff = (plotdraw->xmin - plotdraw->xstart) / (plotdraw->xend - plotdraw->xstart - range + 1); // +1 is to prevent div by zero
	range /= plotdraw->xend - plotdraw->xstart;
	
	range += 0.005; // increase to eliminate rounding errors
	[hScrollBar setFloatValue: xoff knobProportion: range];
	[hScrollBar setEnabled:(range < 1 ? YES: NO)];
	
	range = plotdraw->ymax - plotdraw->ymin;	
	double yoff = 1 - (plotdraw->ymin - initViewRanges.ymin)/(initViewRanges.ymax - range- initViewRanges.ymin);	
	range /= initViewRanges.ymax - initViewRanges.ymin;
	
	range += 0.005; // increase to eliminate rounding errors
	[vScrollBar setFloatValue: yoff knobProportion: range];
	[vScrollBar setEnabled:(range < 1 ? YES: NO)];
}

// place the scrollbars on the view, used on window resize
- (void)adjustScrollBarLocations {

	// TODO: replace magic numbers (15,16) with scollerWidth class call
	
	// vertical scroll bar (y scroll)
	NSRect frame = [plotView frame];
	
	frame.origin.x = frame.size.width - 16;
	frame.origin.y = 15;
	frame.size.width = 16;
	frame.size.height -= 15;
	[vScrollBar setFrame: frame];

	// horizontal scroll bar (x scroll)
	frame = [plotView frame];
	frame.origin.x = 0;
	frame.origin.y = 0;
	frame.size.height = 16;
	frame.size.width -= 15;
	[hScrollBar setFrame: frame];
	
	frame = [plotView frame];
	frame.origin.x = frame.size.width - 15;
	frame.origin.y = 0;
	frame.size.width = 15;
	frame.size.height = 15;	
	[showAllButton setFrame:frame];
}

// sets the drawable area, used on window resize
- (void)adjustGraphViewFrame {
		
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	NSRect br = [plotView bounds];

	// define the draw area boundary co-ordinates for plot_draw
	plotdraw->plot_xe = br.size.width-1;
	plotdraw->plot_ye = br.size.height+1;
	
	if(! [vScrollBar isHidden]) {
	  plotdraw->plot_xe -= 15;
	}
	if(! [hScrollBar isHidden]) {
	  plotdraw->plot_ye -= 15;
	}
		
	[self adjustScrollBarLocations];
}

- (IBAction)toggleStep:(id)sender {
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	//plotdraw->draw_min_max_lines = ! [sender intValue];
	//int lsi = plotdraw.line_set_count;

	int linetype;
	if([sender intValue] == 1) {
		linetype = TYPE_STEP;
	} else {
		linetype = TYPE_LINE;
	}
	
	int di;
	for(di=0; di < plotdraw->line_set_count ; di++) {
		my_dataset_t *dataset = plotdraw->line_set[di].dataset;
			
		int li;
		for(li=0; li < dataset->item_count ; li++) {
			plotdraw->line_set[di].line[li].linetype = linetype;			
		}
	}
	
	[plotView setNeedsDisplay:YES];
}



- (IBAction)toggleLiteral:(id)sender {

	//BOOL flag = [sender intValue] == 1 ? YES : NO;
	//[plotView toggleLiteral: flag];
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	plotdraw->draw_min_max_lines = ! [sender intValue];
	
	/*
	if(!flag && [samplesppEdit intValue] < 50) {
		[samplesppEdit setIntValue:50];
		[samplesppSlider setIntValue:50];
	} else if(flag && [samplesppEdit intValue] > 40) {
		[samplesppEdit setIntValue:8];
		[samplesppSlider setIntValue:8];	
	}
	*/
	[plotView setNeedsDisplay:YES];
}

- (IBAction)toggleBookmarks:(id)sender {
	
	NSMenuItem *item = (NSMenuItem *)sender;
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	
	switch([item tag]) {
	
		case 1:				
			plotdraw->bookmarks.show = BOOKMARKS_SHOW;
			[[[item menu] itemWithTag:2] setState:NSOffState];
			[[[item menu] itemWithTag:3] setState:NSOffState];
			break;
				
		case 2:
			plotdraw->bookmarks.show = BOOKMARKS_SHOW_LABEL_ONLY;
			[[[item menu] itemWithTag:1] setState:NSOffState];
			[[[item menu] itemWithTag:3] setState:NSOffState];

			break;
		case 3:
			plotdraw->bookmarks.show = BOOKMARKS_HIDE;
			[[[item menu] itemWithTag:1] setState:NSOffState];
			[[[item menu] itemWithTag:2] setState:NSOffState];

			break;			
	}
	[item setState:NSOnState];
	[plotView setNeedsDisplay:YES];
	
}

// add bookmark sheet closed
- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	
	if(returnCode == NSOKButton) {
		// add new bookmark
		const char *bookmark = [[bookmarkNoteEdit stringValue] cStringUsingEncoding:NSUTF8StringEncoding];
	
		int bi=plotdraw->bookmarks.bookmark_count;
		my_plot_bookmark_arr_set_length(plotdraw->bookmarks.bookmark, plotdraw->bookmarks.bookmark_count+1);
		
		plotdraw->bookmarks.bookmark[bi].timestamp = 1000 * [[bookmarkDate dateValue] timeIntervalSince1970];
		plotdraw->bookmarks.bookmark[bi].bookmark = strdup(bookmark);
		//plotdraw->bookmark_count++;
		
		// show bookmarks if not visible
		if(plotdraw->bookmarks.show == BOOKMARKS_HIDE) {
			plotdraw->bookmarks.show = BOOKMARKS_SHOW;
		}
		
		[plotView setNeedsDisplay:YES];
	}
	
    [sheet orderOut:self];
}

- (IBAction)okAddBookmarkPanel: (id)sender
{
	[NSApp endSheet:addBookmarkPanel returnCode:NSOKButton];	
}

- (IBAction)closeAddBookmarkPanel: (id)sender
{
	[NSApp endSheet:addBookmarkPanel returnCode:NSCancelButton];
}

- (void)clearBookmarksAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];

	if(returnCode  == NSAlertDefaultReturn) {
		plotdraw->bookmarks.bookmark_count=0;
		[plotView setNeedsDisplay:YES];
	}
}

- (IBAction)clearBookmarks:(id)sender
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	if(plotdraw->bookmarks.bookmark_count) {
		
		NSAlert *alert =[NSAlert alertWithMessageText:@"Clear all bookmarks?" defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Deleted bookmarks cannot be restored."];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(clearBookmarksAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		 
		//int result = NSRunAlertPanel(@"Clear all bookmarks?",@"Deleted bookmarks cannot be restored.",@"OK",@"Cancel",nil);
	}
}

- (IBAction)addBookmark:(id)sender
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	
	// TODO: check scale
	
    NSDate *mindate = [NSDate dateWithTimeIntervalSince1970:plotdraw->xstart/1000];
	NSDate *maxdate = [NSDate dateWithTimeIntervalSince1970:plotdraw->xend/1000];
	
	// default is in the middle of screen
	NSDate *center = [NSDate dateWithTimeIntervalSince1970:((plotdraw->xmax - plotdraw->xmin)/2+plotdraw->xmin)/1000];

	[bookmarkDate setMinDate:mindate];
	[bookmarkDate setMaxDate:maxdate];
	[bookmarkDate setDateValue:center];
	
	// starts new sheet
	[NSApp beginSheet:addBookmarkPanel modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)toggleLegendPosition:(id)sender {

	NSMenuItem *item = (NSMenuItem *)sender;
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	
	switch([item tag]) {
		case 1:
			plotdraw->legend.show = LEGEND_SHOW_LEFT;
			[[[item menu] itemWithTag:2] setState:NSOffState];
			[[[item menu] itemWithTag:3] setState:NSOffState];
			break;
		case 2:
			plotdraw->legend.show = LEGEND_SHOW_RIGHT;
			[[[item menu] itemWithTag:1] setState:NSOffState];
			[[[item menu] itemWithTag:3] setState:NSOffState];
			break;			
		case 3:
			plotdraw->legend.show = LEGEND_HIDE;
			[[[item menu] itemWithTag:1] setState:NSOffState];
			[[[item menu] itemWithTag:2] setState:NSOffState];
			break;
	}
	[item setState:NSOnState];
	[plotView setNeedsDisplay:YES];
}

#define MOVE_STEP 10

- (IBAction)xMoved:(id)sender {

	NSScrollerPart part = [sender hitPart];
	my_plot_draw_t *plotdraw = [[self document] plotDraw];

	float f = [hScrollBar floatValue];
	float pl = [hScrollBar knobProportion];
	
	switch(part) {
		
		case NSScrollerDecrementPage:
			f -= pl;
			if(f < 0) {
				f = 0;
			}
				break;		
		case NSScrollerIncrementPage:
			f += pl;
			if(f > 1) {
				f = 1;
			}
				break;
			
		case NSScrollerDecrementLine:
			f -= pl/MOVE_STEP;
			if(f < 0) {
				f = 0;
			}
				
				break;
			
		case NSScrollerIncrementLine:
			f += pl/MOVE_STEP;
			if(f > 1) {
				f = 1;
			}
				break;
			
		case NSScrollerKnob:
		case NSScrollerKnobSlot:
			break;
			
	}
	double range = plotdraw->xmax - plotdraw->xmin;
	double xmin = f * (plotdraw->xend - range- plotdraw->xstart) + plotdraw->xstart;
	plotdraw->xmin = xmin;
	plotdraw->xmax = xmin + range;
	[hScrollBar setFloatValue:f knobProportion:pl];
	[self updateLables];
	[plotView setNeedsDisplay:YES];
}

- (IBAction)yMoved:(id)sender {

	NSScrollerPart part =[sender hitPart];
	my_plot_draw_t *plotdraw = [[self document] plotDraw];

	float f = [vScrollBar floatValue];
	float pl = [vScrollBar knobProportion];
	
	switch(part) {

	case NSScrollerDecrementPage:
		f -= pl;
		if(f < 0) {
			f = 0;
		}
	
		break;		
	case NSScrollerIncrementPage:
		f += pl;
		if(f > 1) {
			f = 1;
		}
		break;
		
	case NSScrollerDecrementLine:
		f -= pl/MOVE_STEP;
		if(f < 0) {
			f = 0;
		}
		break;
		
	case NSScrollerIncrementLine:
		f += pl/MOVE_STEP;
		if(f > 1) {
			f = 1;
		}
		break;
		
	case NSScrollerKnob:
	case NSScrollerKnobSlot:
		break;
	
	}
	double range = plotdraw->ymax - plotdraw->ymin;
	double ymin = (1-f) * (initViewRanges.ymax - range- initViewRanges.ymin) + initViewRanges.ymin;
	plotdraw->ymin = ymin;
	plotdraw->ymax = ymin + range;
	[vScrollBar setFloatValue:f knobProportion:pl];
	[plotView setNeedsDisplay:YES];
}


- (void)windowDidLoad {

	[self setShouldCloseDocument:YES];
	
	[plotView setPlotDrawWindowController: self];
	
	NSWindow *window = [self window];
	
	// vertical scroll bar (y scroll)
	NSRect frame = [plotView frame];
	
	frame.origin.x = frame.size.width - 16;
	frame.origin.y = 15;
	frame.size.width = 16;
	frame.size.height -= 15;
	vScrollBar = [[NSScroller alloc] initWithFrame: frame];
	[vScrollBar setFloatValue: 0 knobProportion: 1];
	[vScrollBar setAction:@selector(yMoved:)];
	[vScrollBar setEnabled: NO];
	[plotView addSubview: vScrollBar];
	[vScrollBar setHidden: YES];

	// horizontal scroll bar (x scroll)
	frame = [plotView frame];
	frame.origin.x = 0;
	frame.origin.y = 0;
	frame.size.height = 16;
	frame.size.width -= 15;
	hScrollBar = [[NSScroller alloc] initWithFrame: frame];
	[hScrollBar setFloatValue: 0 knobProportion: 1];
	[hScrollBar setAction:@selector(xMoved:)];
	[hScrollBar setEnabled: NO];	
	[plotView addSubview: hScrollBar];	
	[hScrollBar setHidden: YES];

	
	/* set in NIB by Interface Builder
	NSImage *leftArrowImage = [NSImage imageNamed: @"BackAdorn"];
	NSImage *rightArrowImage = [NSImage imageNamed: @"ForwardAdorn"]; 
	NSImage *downArrowImage = [NSImage imageNamed: @"DownAdorn"];
	*/
	// set segmented controls
	//[segments setImage:leftArrowImage forSegment:0];
	//[segments setImage:rightArrowImage forSegment:1];
	[segments setAutoresizesSubviews:YES];
	[segments setWidth:0 forSegment:0];
	[segments setWidth:0 forSegment:1];	
	[segments setEnabled:NO forSegment:0];
	[segments setEnabled:NO forSegment:1];
	[segments setToolTip:@"Zoom history navigation"];
	
	// set in NIB by Interface Builder
	//[toggleButton setImage:downArrowImage];
	//[toggleButton setImagePosition:NSImageAbove];
	[toggleButton setToolTip:@"Toggle graph line drawer"];
	
	// assign the checkbox action for the table view
	NSTableColumn *column = [plotTableView tableColumnWithIdentifier:@"lineEnabled"];
	NSButtonCell *cell = [column dataCell];
	[cell setAction:@selector(lineEnabledClicked:)];
	[cell setTarget: self];
	
	// create show all button
	frame = [plotView frame];
	frame.origin.x = frame.size.width - 15;
	frame.origin.y = 0;
	frame.size.width = 15;
	frame.size.height = 15;	
	showAllButton = [[NSButton alloc] initWithFrame:frame];
	[showAllButton setBezelStyle:NSShadowlessSquareBezelStyle];
	[showAllButton setToolTip: @"Show all"];
	[showAllButton setTitle:@"*"];
	[showAllButton setAction:@selector(showAll:)];
	[showAllButton setTarget: self];
	[plotView addSubview: showAllButton];
	[showAllButton setHidden:YES];
	[showAllButton setEnabled:NO];
	
	// create edit control
	frame = NSMakeRect(100,100,60,15);
	edit = [[NSTextField alloc] initWithFrame:frame];
	[edit setFont: [NSFont fontWithName:@"Helvetica" size:12]];
	[edit setBackgroundColor:[NSColor yellowColor]];
	[edit setBordered: NO];
	[edit setAction: @selector(noteTextDidEndEditing:)];
	[plotView addSubview:edit];
	[edit setHidden:YES];
			
    // Transparent overlay window
	frame = [window contentRectForFrameRect:[window frame]];
	overlayWindow = [[[NSWindow alloc] initWithContentRect: frame styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer:NO ] retain];
	[overlayWindow setBackgroundColor:[NSColor clearColor]];
	[overlayWindow setAlphaValue:1.0];
	[overlayWindow setOpaque:NO];
	[overlayWindow setIgnoresMouseEvents: YES];
	[overlayWindow setHasShadow:NO];
	
	overlayView = [[OverlayView alloc] initWithFrame: [overlayWindow frame]];
	[overlayWindow setContentView: overlayView];
	
	[bookmarkDate setLocale:[NSLocale currentLocale]];
	
	// No overlapping subviews
	[window useOptimizedDrawing:YES];

	// load the api to the structure
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	plotdraw->paintapi = paintapi_cocoa_new(plotdraw);

	// default legend setting
	plotdraw->legend.show = LEGEND_SHOW_RIGHT;
	if(plotdraw->bookmarks.bookmark_count) {
		plotdraw->bookmarks.show = BOOKMARKS_SHOW;
	} else {
		plotdraw->bookmarks.show = BOOKMARKS_HIDE;
	}
	// samplespp edit
	[samplesppEdit setIntValue:plotdraw->samples_per_pixel];
	[samplesppEdit setAction: @selector(samplesppDidChange:)];
	[samplesppEdit setTarget:self];
	
	[samplesppSlider setIntValue:plotdraw->samples_per_pixel];
	[samplesppSlider setAction: @selector(samplesppDidChange:)];
	[samplesppSlider setTarget:self];
	
	// set initial size
	frame = [[self window] frame];
	frame.size.height = 600;
	frame.size.width = 800;
	[[self window] setFrame: frame display:YES];
	
	// prepare the views for first draw
	[self updatePlotLimits];
	[self updatePlotFonts];
	[self adjustGraphViewFrame];
	[self updateMainMenu];
}


- (IBAction)segmentClicked:(id)sender {
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	int idx = [segments selectedSegment];
	
	if(idx == 0 && zoomidx > 0) {
		// pop one
		my_plot_view_range_t ranges = zoomHistories[--zoomidx];

		plotdraw->ymax = ranges.ymax;
		plotdraw->ymin = ranges.ymin;
		plotdraw->xmax = ranges.xmax;
		plotdraw->xmin = ranges.xmin;
				
		if(zoomidx == 0) {
			[segments setEnabled:NO forSegment:0];
		}
		[segments setEnabled:YES forSegment:1];
				
		[self updateLables];
		[self adjustScrollBarRanges];
		[plotView setNeedsDisplay:YES];
		
	} if(idx == 1 && zoomc > 0 && zoomidx < zoomc) {
					
		my_plot_view_range_t ranges = zoomHistories[++zoomidx];
		
		plotdraw->ymax = ranges.ymax;
		plotdraw->ymin = ranges.ymin;
		plotdraw->xmax = ranges.xmax;
		plotdraw->xmin = ranges.xmin;
		

		[segments setEnabled:YES forSegment:0];
		if(zoomidx == zoomc) {
			[segments setEnabled:NO forSegment:1];
		}				
				
		[self updateLables];
		[self adjustScrollBarRanges];
		[plotView setNeedsDisplay:YES];
	}	
}

- (IBAction)showAll:(id)sender {
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	
	plotdraw->xmax = initViewRanges.xmax;
	plotdraw->xmin = initViewRanges.xmin;
	plotdraw->ymax = initViewRanges.ymax;
	plotdraw->ymin = initViewRanges.ymin;
	
	zoomidx = zoomc = 0;
	zoomHistories[zoomidx] = initViewRanges;
	[segments setEnabled:NO forSegment:0];
	[segments setEnabled:NO forSegment:1];
	
	[vScrollBar setHidden: YES]; 
	[hScrollBar setHidden: YES]; 
	[showAllButton setHidden:YES];
	[showAllButton setEnabled:NO];
	[self adjustGraphViewFrame];
	
	[self updateLables];
	
	// update the scrollbars
	[self adjustScrollBarRanges];
	[plotView setNeedsDisplay: YES];
}

- (void)resetAndView {
	[plotTableView noteNumberOfRowsChanged];
	[self updatePlotLimits];
	//[self updatePlotFonts];
	[self adjustGraphViewFrame];
	[plotView setNeedsDisplay:YES];
}

- (PlotDrawView *)plotView {
	return plotView;
}

- (float)yOffset {
	if([hScrollBar isHidden]) {
		return 0;
	}
	return [NSScroller scrollerWidth];
}

- (void) moveViewY:(double)ydiff {
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	
	double yrange = plotdraw->ymax - plotdraw->ymin;
	plotdraw->ymin += ydiff;
	plotdraw->ymax += ydiff;
	
	if(plotdraw->ymin < initViewRanges.ymin) {
		plotdraw->ymin = initViewRanges.ymin;
		plotdraw->ymax = initViewRanges.ymin + yrange;
	}
	if(plotdraw->ymax > initViewRanges.ymax) {
		plotdraw->ymax = initViewRanges.ymax;
		plotdraw->ymin = initViewRanges.ymax - yrange;
	}
}


- (void) moveViewX:(double)xdiff {
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	
	double xrange = plotdraw->xmax - plotdraw->xmin;
	plotdraw->xmin += xdiff;
	plotdraw->xmax += xdiff;
	if(plotdraw->xmin < plotdraw->xstart) {
		plotdraw->xmin = plotdraw->xstart;
		plotdraw->xmax = plotdraw->xmin + xrange;
	}
	if(plotdraw->xmax > plotdraw->xend) {
		plotdraw->xmax = plotdraw->xend;
		plotdraw->xmin = plotdraw->xend - xrange;
	}
	[self updateLables];
}

- (void)setXRange:(double)newxrange {

	my_plot_draw_t *plotdraw = [[self document] plotDraw];	

	/*
	if(newxrange < 10) {
		return;
	}
	 */

	// get current range center
	double xrange = (plotdraw->xmax - plotdraw->xmin);
	double xcenter = xrange/2 + plotdraw->xmin;
	
	// new xmin
	plotdraw->xmin = xcenter - newxrange/2;
	plotdraw->xmax = xcenter + newxrange/2;	

	double xmaxrange = plotdraw->xend - plotdraw->xstart; 
	if(xmaxrange > newxrange) {
		xrange = newxrange;
	} else {
		xrange = xmaxrange;
	}

	if(plotdraw->xmin < plotdraw->xstart) {
		plotdraw->xmin = plotdraw->xstart;
		plotdraw->xmax = plotdraw->xmin + xrange;
	}
	if(plotdraw->xmax > plotdraw->xend) {
		plotdraw->xmax = plotdraw->xend;
		plotdraw->xmin = plotdraw->xend - xrange;
	}
	[self updateLables];
}

-(void)setYRange:(double)newyrange {

	my_plot_draw_t *plotdraw = [[self document] plotDraw];	

	/*
	if(newyrange < 0.1) {
		return;
	}
	 */

	// get current range center
	double yrange = (plotdraw->ymax - plotdraw->ymin);
	double ycenter = yrange/2 + plotdraw->ymin;
	
	// new xmin
	plotdraw->ymin = ycenter - newyrange/2;
	plotdraw->ymax = ycenter + newyrange/2;	

	double ymaxrange = initViewRanges.ymax - initViewRanges.ymin; 
	if(ymaxrange > newyrange) {
		yrange = newyrange;
	} else {
		yrange = ymaxrange;
	}
	if(plotdraw->ymin < initViewRanges.ymin) {
		plotdraw->ymin = initViewRanges.ymin;
		plotdraw->ymax = initViewRanges.ymin + yrange;
	}
	if(plotdraw->ymax > initViewRanges.ymax) {
		plotdraw->ymax = initViewRanges.ymax;
		plotdraw->ymin = initViewRanges.ymax - yrange;
	}
}

#define ZOOM_OUT_FACTOR 1.08
#define ZOOM_IN_FACTOR 0.93
#define MOVE_STEP 20
#define MINOR_MOD 0.3

- (void)keyDown:(NSEvent *)theEvent {

	if(NSKeyDown != [theEvent type]) {
		return;
	}
	unsigned int mFlags = [theEvent modifierFlags];
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	NSString *chars = [theEvent charactersIgnoringModifiers];
	// [theEvent isARepeat]
	BOOL doZoom = mFlags & NSCommandKeyMask ? YES : NO;
	BOOL doMinor = mFlags & NSShiftKeyMask ? YES : NO;
	
	double mmod = doMinor ? MINOR_MOD : 1;
	
	switch([chars characterAtIndex:0] ) {
		
		case NSLeftArrowFunctionKey:
			if(doZoom) {
				[self setXRange: (plotdraw->xmax - plotdraw->xmin)*ZOOM_OUT_FACTOR];
			} else {
				// page left
				[self moveViewX:-(plotdraw->xmax - plotdraw->xmin)/MOVE_STEP*mmod];
			}
			[self adjustScrollBarRanges];
			[plotView setNeedsDisplay:YES];
		break;
		
		case NSRightArrowFunctionKey:
			if(doZoom) {
				[self setXRange: (plotdraw->xmax - plotdraw->xmin)*ZOOM_IN_FACTOR];
			} else {
			// page left
				[self moveViewX:(plotdraw->xmax - plotdraw->xmin)/MOVE_STEP*mmod];
			}
			[self adjustScrollBarRanges];
			[plotView setNeedsDisplay:YES];
		break;
		
		case NSUpArrowFunctionKey:
			if(doZoom) {
				[self setYRange: (plotdraw->ymax - plotdraw->ymin)*ZOOM_OUT_FACTOR];			
			} else {
				// page up
				[self moveViewY:(plotdraw->ymax - plotdraw->ymin)/MOVE_STEP*mmod];
			}
			[self adjustScrollBarRanges];
			[plotView setNeedsDisplay:YES];
		break;

		case NSDownArrowFunctionKey:
			if(doZoom) {
				[self setYRange: (plotdraw->ymax - plotdraw->ymin)*ZOOM_IN_FACTOR];
			} else {
				// page up
				[self moveViewY:-(plotdraw->ymax - plotdraw->ymin)/MOVE_STEP*mmod];
			}
			[self adjustScrollBarRanges];
			[plotView setNeedsDisplay:YES];
		break;
			
		default:
			[super keyDown:theEvent];
			return;
	}
	[hScrollBar setHidden:[hScrollBar knobProportion] == 1];
	[vScrollBar setHidden:[vScrollBar knobProportion] == 1];
	[showAllButton setHidden:[vScrollBar isHidden] && [hScrollBar isHidden]];
	[showAllButton setEnabled:! [showAllButton isHidden]];
	
	[self adjustGraphViewFrame];
	
}

- (void)samplesppDidChange:(id)sender
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	int spp = [sender intValue];
	if(spp < 10) {
		spp = 10;
	} else if(spp > [samplesppSlider maxValue]) {
		spp = [samplesppSlider maxValue];
	}
	plotdraw->samples_per_pixel = spp;
		
	if(sender == samplesppEdit) {
		[samplesppSlider setIntValue:spp];
	} else {
		[samplesppEdit setIntValue:spp];
	}
		
	[plotView setNeedsDisplay:YES];
	[sender setIntValue:plotdraw->samples_per_pixel];
}

- (void)noteTextDidEndEditing:(id)sender
{
	free((void *)currentbm->bookmark);
	const char *newtext = [[edit stringValue] cStringUsingEncoding: NSUTF8StringEncoding];		
	currentbm->bookmark = strdup(newtext);
	
	[edit setHidden:YES];
	[plotView setNeedsDisplay:YES];
}

#define BOOKMARK_DRAGOUT_THRESHOLD 10

- (void)mouseDown:(NSEvent *)theEvent
{
	if(NSLeftMouseDown != [theEvent type]) {
		// some non-apple mouse
		return;
	}
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
		
	// Mouse tracking local event loop has here several possible operation modes
	// 1. Normal zoom with highlighted selection box, change cursor to cross
	// 2. Drag view with mouse, change cursor to hand
	// 3. Move bookmark with mouse
	
    BOOL keepOn = YES;
    BOOL isInside = YES;
	NSPoint mouseStartLoc;
    NSPoint mouseLoc;
	
	unsigned int mFlags = [theEvent modifierFlags];
	BOOL moving = mFlags & NSCommandKeyMask ? YES : NO;
	BOOL bookmarkmove = NO;
	
	// compute the limiting frames
	NSRect boundsr = [plotView frame];
	
#define PLOT_NO_SELECT_ON_TIME 1
	// plot_yde has the location of minimum lower y-limit
	//int miny = plotdraw->plot_ye - plotdraw->plot_yde + 1;
	int miny;
	int yorg = 0;
#ifdef PLOT_NO_SELECT_ON_TIME
	miny = plotdraw->plot_ye - plotdraw->plot_yde + 1;
#else
	miny = 0;
#endif
	if(![hScrollBar isHidden]) {
		miny += 15;
		yorg += 15;
	}
	int maxx = boundsr.size.width - 1;
	if(![vScrollBar isHidden]) {
		maxx -= 14;
	}
	
	mouseStartLoc = [plotView convertPoint:[theEvent locationInWindow] fromView:nil];

	// doubleclick is reset
	if([theEvent clickCount] == 2) {
		
		// if mouse is double-clicked on bookmark note area put edit box there
		int bi;
		for(bi=0; bi < plotdraw->bookmarks.bookmark_count ; bi++) {
			my_plot_rect_t *bmr = &plotdraw->bookmarks.bookmark[bi].note_rect;
			if(rect_is_in(bmr, mouseStartLoc.x, plotdraw->plot_ye-mouseStartLoc.y + yorg)) {
				// is inside
				NSRect frame = [plotView frame];
				frame.origin.x = bmr->x1;
				frame.size.width = bmr->x2 - bmr->x1 + 1;
				frame.size.height = bmr->y2 - bmr->y1 + 1;					
				frame.origin.y = plotdraw->plot_ye - bmr->y1 - frame.size.height + yorg+1;
				
				if(frame.size.width < 30) {
					frame.size.width = 30;
				}
				
				[edit setFrame: frame];

				currentbm = &plotdraw->bookmarks.bookmark[bi];
				
				NSString *string = [NSString stringWithCString:currentbm->bookmark encoding: NSUTF8StringEncoding];
				[edit setStringValue: string];
				
				[edit setHidden: NO ];
				[[self window] makeFirstResponder:edit];
				
				return;				
			}
		}
		//[self showAll:nil];
		return;
	}
	
	// stop editing
	if(![edit isHidden]) {
		
		[self noteTextDidEndEditing:edit];
	}
	[[self window] makeFirstResponder:plotView];
	
	// check if mouse was pressed on bookmark
	int bi=0;
	if(plotdraw->bookmarks.show != BOOKMARKS_HIDE) {
	  for(bi=0; bi < plotdraw->bookmarks.bookmark_count; bi++) {
	    if(plotdraw->bookmarks.triangle_size >= abs(plotdraw->bookmarks.bookmark[bi].xoffset - mouseStartLoc.x) &&
	       mouseStartLoc.y > plotdraw->plot_ye - plotdraw->bookmarks.triangle_size) {
	      bookmarkmove = YES;
	      break;
	    }
	  }	
	}
		
#ifdef PLOT_NO_SELECT_ON_TIME
	// check if mouse was clicked outside plotting area
	if(mouseStartLoc.y < miny) {
		return;
	}
#endif
	
    while (keepOn) {
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        mouseLoc = [plotView convertPoint:[theEvent locationInWindow] fromView:nil];
        isInside = [plotView mouse:mouseLoc inRect:[plotView bounds]];
		
        switch ([theEvent type]) {
			case NSLeftMouseDown:
				break;
				
            case NSLeftMouseDragged:
			{
				if(moving) {
					// move operation
					
					[[NSCursor openHandCursor] set];
					
					// move, compute new location from diff
					double ydiff = mouseLoc.y - mouseStartLoc.y;
					double xdiff = mouseLoc.x - mouseStartLoc.x;
					
					// the relative move
					xdiff /= maxx;
					ydiff /= boundsr.size.height-1 -miny;
					
					// visible ranges
					double xrange = plotdraw->xmax - plotdraw->xmin;
					double yrange = plotdraw->ymax - plotdraw->ymin;
					
					// actual move
					double xmove = xrange * xdiff;
					double ymove = yrange * ydiff;
					
					[self moveViewY:-ymove];
					[self moveViewX:-xmove];
					
					// save old location
					mouseStartLoc = mouseLoc;
					
					// update the scrollbars
					[self adjustScrollBarRanges];
					[plotView setNeedsDisplay: YES];
					
				} else if(bookmarkmove) {
					// bookmarkmove
					[[self window] addChildWindow: overlayWindow ordered: NSWindowAbove];
					
					NSRect wframe = [[self window] frame];
					NSRect frame = [plotView frame];
					frame.origin.x += wframe.origin.x;
					frame.origin.y += wframe.origin.y;					
					[overlayWindow setFrame: frame display: YES];
					
					if(isInside || mouseLoc.y < plotdraw->plot_ye + BOOKMARK_DRAGOUT_THRESHOLD + yorg) {
						[[NSCursor resizeLeftRightCursor] set];
					} else {
						[[NSCursor disappearingItemCursor] set];	
					}
					
					double oldpos = [overlayView bookmarkGhost];
					[overlayView setBookmarkGhost: mouseLoc.x];
					[overlayView setNeedsDisplayInRect:NSMakeRect((oldpos < mouseLoc.x ? oldpos : mouseLoc.x) - 10,0,abs(mouseLoc.x-oldpos)+20,frame.size.height)];
					
				} else {
					// zoom select
					[[self window] addChildWindow: overlayWindow ordered: NSWindowAbove];
					
					NSRect wframe = [[self window] frame];
					NSRect frame = [plotView frame];
					frame.origin.x += wframe.origin.x;
					frame.origin.y += wframe.origin.y;					
					[overlayWindow setFrame: frame display: YES];
					
					//[overlayWindow setFrame: [[self window] frame] display: YES];
					
					[[NSCursor crosshairCursor] set];
					
					NSRect oldRect = [overlayView selectRect];
					
					if(mouseLoc.x < 0) mouseLoc.x = 0;
					if(mouseLoc.x > maxx) mouseLoc.x = maxx;
					if(mouseLoc.y < miny) mouseLoc.y = miny;
					if(mouseLoc.y >= boundsr.size.height) mouseLoc.y = boundsr.size.height - 1;					
					
					NSRect hlrect = NSMakeRect(mouseStartLoc.x, mouseStartLoc.y, mouseLoc.x - mouseStartLoc.x, mouseLoc.y - mouseStartLoc.y);
					// normalize coordinates if rectangle has negative width or height
					if(hlrect.size.width < 0) {
						hlrect.size.width *= -1;
						hlrect.origin.x -= hlrect.size.width;
					}
					if(hlrect.size.height < 0) {
						hlrect.size.height *= -1;
						hlrect.origin.y -= hlrect.size.height;
					}
					[overlayView setSelectRect: hlrect];
					[overlayView setNeedsDisplayInRect:oldRect];
				}
			}
				break;
            case NSLeftMouseUp:
			{				
				if(moving) {
					// move finished
					[[NSCursor arrowCursor] set];
				} else if(bookmarkmove) {
					
					// - check that new position is in window
					if(isInside || mouseLoc.y < plotdraw->plot_ye + BOOKMARK_DRAGOUT_THRESHOLD + yorg) {
						// move selected bookmark to new location
						double timestamp = mouseLoc.x;
						timestamp /= plotdraw->plot_xe;
						timestamp *= plotdraw->xmax - plotdraw->xmin;
						timestamp += plotdraw->xmin;
						
						plotdraw->bookmarks.bookmark[bi].timestamp = timestamp;
						
					} else {
						// remove the bookmark
						bzero(&plotdraw->bookmarks.bookmark[bi],sizeof(my_plot_bookmark_t));
					}
					plot_draw_sort_bookmarks(plotdraw);
					
					[[self window] removeChildWindow: overlayWindow];
					[overlayWindow orderOut:self];
					[overlayView setNeedsDisplay: YES];
					[overlayView setBookmarkGhost: -1];
					[[NSCursor arrowCursor] set];
					[plotView setNeedsDisplay:YES];
					
				} else {
					// zoom finished, or normal upclick
					NSRect selectedr = [overlayView selectRect];
					
					if(NSEqualRects(selectedr,NSZeroRect)) {
						// normal zoom click, exit
						return;
					}
					
					[[self window] removeChildWindow: overlayWindow];
					[overlayWindow orderOut:self];
					
					// update new zoom based on selected rectangle coordinates
					double xl = selectedr.origin.x;
					xl /= maxx;
					double oldxmin = plotdraw->xmin;
					plotdraw->xmin = (plotdraw->xmax - plotdraw->xmin)*xl + plotdraw->xmin;
					double xr = selectedr.origin.x + selectedr.size.width;
					xr /= maxx;
					plotdraw->xmax = (plotdraw->xmax - oldxmin)*xr + oldxmin;
					
					double by = selectedr.origin.y - miny;
					by /= boundsr.size.height-1 - miny;
					double oldymin = plotdraw->ymin;
					plotdraw->ymin = (plotdraw->ymax - oldymin)*by + oldymin;
					
					double ty = selectedr.origin.y + selectedr.size.height - miny;
					ty /= boundsr.size.height-1 -miny;
					plotdraw->ymax = (plotdraw->ymax - oldymin)*ty + oldymin;

					
					// add current to zoom history, start dropping oldest if enough histories
					if(zoomc == 10) {
						memmove(zoomHistories,zoomHistories+1,9*sizeof(zoomHistories[0]));
						zoomidx--;
					}
					zoomHistories[++zoomidx] = _make_ranges(plotdraw->xmin,plotdraw->xmax,plotdraw->ymin,plotdraw->ymax);
					zoomc = zoomidx;
					
					[segments setEnabled:YES forSegment:0];
					[segments setEnabled:NO forSegment:1];
					
					
					[self updateLables];
					
					// update the scrollbars
					[self adjustScrollBarRanges];
					
					[[NSCursor arrowCursor] set];
					
					[vScrollBar setHidden: NO]; 
					[hScrollBar setHidden: NO];
					[showAllButton setHidden:NO];
					[showAllButton setEnabled:YES];
					[self adjustGraphViewFrame];
					
					[plotView setNeedsDisplay: YES];
					[overlayView setNeedsDisplayInRect:selectedr];
					[overlayView setSelectRect: NSZeroRect];
				}
				keepOn = NO;
			}
				break;
            default:
				/* Ignore any other kind of event. */
				break;
        }
		
    };
	
    return;
}


- (void)windowDidResize:(NSNotification *)aNotification
{
	[self adjustGraphViewFrame];
}

/*
-(NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{	
	return proposedFrameSize;
}
*/

- (IBAction)printDocument:(id)sender
{
	
	NSPrintInfo *printInfo = [[self document] printInfo];
	[printInfo retain];
	
	[printInfo setVerticallyCentered:YES];
	[printInfo setVerticalPagination:NSFitPagination];
	[printInfo setHorizontallyCentered:YES];
	[printInfo setHorizontalPagination:NSFitPagination];
	
	[printInfo setTopMargin:30];
	[printInfo setLeftMargin:20];
	[printInfo setRightMargin:20];
	[printInfo setBottomMargin:30];
	
	NSRect bounds = [plotView bounds];
	if(! [vScrollBar isHidden]) {
	   bounds.size.width -= [NSScroller scrollerWidth];
	}
	if(! [hScrollBar isHidden]) {
		bounds.size.height -= [NSScroller scrollerWidth];
	}
	
	// 254 dpi on A4
	if([printInfo orientation] == NSLandscapeOrientation) {
		bounds.size.height = 1700;
		bounds.size.width = 2700;
	} else { // potrait
		bounds.size.height = 2700;
		bounds.size.width = 1700;
	}
	
	// create separate view for the printing
	PrintView *printView = [[[PrintView alloc] initWithFrame:bounds] autorelease];
	
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	my_plot_draw_t *drawclone = malloc(sizeof(my_plot_draw_t));
	plot_draw_init(drawclone);
	
	// the clone does not copy dataset data, it just increases the referencecount
	plot_draw_clone(drawclone,plotdraw);
	
	/*
	drawclone->plot_xe = plotdraw->plot_xe;
	drawclone->plot_ye = plotdraw->plot_ye;
	 */
	drawclone->plot_xe = bounds.size.width-1;
	drawclone->plot_ye = bounds.size.height-1;	
	
	// use same fonts as with screen view
	//drawclone->paintapi = plotdraw->paintapi;
	drawclone->paintapi = paintapi_cocoa_new(drawclone);
	ATSUStyle defaultStyle = _createATSUFont("Helvetica",32);
	drawclone->legend.font = (paintapi_font_t*)defaultStyle;
	drawclone->grid.font_xaxis = (paintapi_font_t*)defaultStyle;
	drawclone->grid.font_yaxis = (paintapi_font_t*)defaultStyle;
	
	[printView setPlotDraw:drawclone];
	[printView setDocument: [self document]];
	
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView: printView printInfo: printInfo];
    [printOperation runOperationModalForWindow: [self window] delegate: nil didRunSelector: NULL contextInfo: NULL];	
}

- (NSData*)imageDataWithWidth:(size_t)width andHeight:(size_t)height fileType:(NSBitmapImageFileType)fileType
{		
	// export
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	size_t bbc = 8;  // bits per component
	size_t bpl = 4*width; // bytes per line
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	void *imagedata = malloc(height*bpl);  // RGB 8bit with alpha
	
	CGContextRef myContext = CGBitmapContextCreate(imagedata,width,height,bbc,bpl,colorSpace,kCGImageAlphaNoneSkipLast);
	
	NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithGraphicsPort:myContext flipped:NO];
	[NSGraphicsContext saveGraphicsState];	
	[NSGraphicsContext setCurrentContext:gc];
	
	NSBitmapImageRep *image = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char **)&imagedata 
																	  pixelsWide:width 
																	  pixelsHigh:height 
																   bitsPerSample:bbc 
																 samplesPerPixel:4 
																		hasAlpha:YES 
																		isPlanar:NO 
																  colorSpaceName:NSDeviceRGBColorSpace 
																	bitmapFormat:0 
																	 bytesPerRow:bpl 
																	bitsPerPixel:32];
	
	BOOL hHidden = [hScrollBar isHidden];
	BOOL vHidden = [vScrollBar isHidden];
	[hScrollBar setHidden:YES];
	[vScrollBar setHidden:YES];
	[showAllButton setHidden:YES];
	[showAllButton setEnabled:NO];	
	[self adjustScrollBarRanges];
	
	double origxe = plotdraw->plot_xe;
	double origye = plotdraw->plot_ye;	
	
	plotdraw->plot_xe = width-1;
	plotdraw->plot_ye = height-1;	
	
	[plotView drawRect:NSMakeRect(0,0,width,height)];
	
	plotdraw->plot_xe = origxe;
	plotdraw->plot_ye = origye;	
	
	[hScrollBar setHidden:hHidden];
	[vScrollBar setHidden:vHidden];
	[showAllButton setHidden:[vScrollBar isHidden] && [hScrollBar isHidden]];
	[showAllButton setEnabled:! [showAllButton isHidden]];
	
	[self adjustScrollBarRanges];																			  
	
	[NSGraphicsContext restoreGraphicsState];
	
	[image setCompression:NSTIFFCompressionLZW factor:.9];
	NSData *data = [[image representationUsingType:fileType properties:nil] retain];
		
CleanUp:
	[image release];
	free(imagedata);
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(myContext);	
	return data;
}

- (void)exportPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if(returnCode != NSOKButton) {
		return;
	}
	
	NSString *filename = [sheet filename];
	NSString *extension = [filename pathExtension];
	
	NSBitmapImageFileType fileType;
	if([extension caseInsensitiveCompare: @"jpg"] == NSOrderedSame) {
		fileType = NSJPEGFileType;
	} else if([extension caseInsensitiveCompare: @"png"] == NSOrderedSame) {
		fileType = NSPNGFileType;
	} else if([extension caseInsensitiveCompare: @"gif"] == NSOrderedSame) {
		fileType = NSGIFFileType;
	} else {
		// TODO: error
	}
	
	// export
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	size_t width = 640;
	size_t height = 480;
	//size_t bbc = 8;  // bits per component
	
	// check actual width/height selection
	if(	[[resolutionSelection cellAtRow: 0 column: 0] intValue] == 1) {
		width = 640;
		height = 480;
	} if([[resolutionSelection cellAtRow: 1 column: 0] intValue] == 1) { 
		width = 800;
		height = 600;
	} else {
		// use current
		width = plotdraw->plot_xe+1;
		height = plotdraw->plot_ye+1;
	}
	
	NSData *data = [self imageDataWithWidth:width andHeight:height fileType:fileType];
	if(data == nil) {
		goto CleanUp;
	}
	
	NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:data];
	BOOL eresult = [wrapper writeToFile:filename atomically:YES updateFilenames:YES];

CleanUp:
		// TODO: better error reporting	
		if(!eresult) {
			[NSAlert alertWithMessageText:@"Failed to create export" defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:nil];
		}
	
	[wrapper release];
}

// copy support
- (void)copy:(id)sender
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	size_t width = plotdraw->plot_xe+1;
	size_t height = plotdraw->plot_ye+1;
	
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
	
	/*
	// file paste
    [pb declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] 
			   owner:self];
	
	NSString *filename = [[[[self document] fileURL] path] lastPathComponent];
	filename = [NSString stringWithFormat:@"%@/%@.png",NSTemporaryDirectory(),filename];
	
	// note that the image data is actually PNG data altough its labeled as TIFF in the pasteboard.
	NSData *data = [self imageDataWithWidth:width andHeight:height fileType:NSPNGFileType];
	NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:data];
	BOOL eresult = [wrapper writeToFile:filename atomically:YES updateFilenames:YES];

	NSArray *props = [NSArray arrayWithObjects: filename,nil];
	
	if(eresult) {
		[pb setPropertyList:props forType:NSFilenamesPboardType];
	}
	[wrapper release];
	*/
	
	// Raw data paste
    [pb declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] 
			   owner:self];
	
	// note that the image data is actually PNG data altough its labeled as TIFF in the pasteboard.
	NSData *data = [self imageDataWithWidth:width andHeight:height fileType:NSPNGFileType];
	if(data != nil) {
		[pb setData:data forType:NSTIFFPboardType];
	}
}

// export plot view as image file
- (IBAction)exportDocument:(id)sender
{
    NSArray *fileTypes = [NSArray arrayWithObjects: @"png",@"jpg",@"gif",nil];
    NSSavePanel *savePanel = [NSSavePanel savePanel];
 
	// get document filename
	NSString *filename = [[[self document] fileURL] path];
	NSString *dir = [filename stringByDeletingLastPathComponent];
	filename = [filename lastPathComponent];
	filename = [filename stringByDeletingPathExtension]; 

	//[[resolutionSelection cellAtRow: 0 column: 0] setIntValue:1];
	
	[savePanel setAccessoryView:graphAuxView];
	[savePanel setAllowedFileTypes: fileTypes];
	[savePanel setPrompt:@"Export"];
	[savePanel setTitle:@"Export plot"];
	[savePanel setNameFieldLabel:@"Export As:"];
	[savePanel setExtensionHidden:NO];
	[savePanel setCanSelectHiddenExtension:YES];

	// begin export sheet
	[savePanel beginSheetForDirectory:dir file:filename modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(exportPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)addFiles:(NSArray *)urlsToOpen
{
	BOOL success = NO;
	
	int i, count = [urlsToOpen count];
	for (i=0; i<count; i++) {
		NSURL *aURL = [urlsToOpen objectAtIndex:i];
		
		NSError *error;
		
		if(! [[self document] readDataFile:aURL error:&error]) {
			[NSAlert alertWithError:error];
			[error release];
		} else {
			success = success || YES;
		}
	}	
	
	if(success) {
		[plotTableView noteNumberOfRowsChanged];
		[self updatePlotLimits];
		[self adjustScrollBarRanges];
		[plotView setNeedsDisplay:YES];
	}	
}

- (IBAction)addFileToDoc:(id)sender 
{
    int result;
    NSArray *fileTypes = [NSArray arrayWithObjects: @"txt",@"text",nil];
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
 
	NSString *path = [[[[self document] fileURL] path] stringByDeletingLastPathComponent];
	
    [oPanel setAllowsMultipleSelection:YES];
    result = [oPanel runModalForDirectory:path
                     file:nil types:fileTypes];
					 
    if (result == NSOKButton) {
		[self addFiles: [oPanel URLs]];
    }
}

- (IBAction)reloadDocument: (id)sender
{
	int updatec=0;
	my_plot_draw_t *plotdraw = [[self document] plotDraw];
	int lsi;
	
	for(lsi=0; lsi < plotdraw->line_set_count; lsi++) { 
		updatec += update_dataset(plotdraw->line_set[lsi].dataset);
	}
	if(updatec > 0) {
	  // recompute the limits as data is updated
	  my_time_t ts = 0, te = 1;
	  plot_draw_calc_x_minmax(plotdraw,&ts,&te,NULL);
	  plotdraw->xmin = ts;
	  plotdraw->xmax = te;

	  double ymin,ymax;
	  plot_draw_calc_y_minmax(plotdraw,&ymin,&ymax,NULL,true);

	  ymin -= (ymax - ymin)/20;
	  ymax += (ymax - ymin)/20;
	  
	  // update range limits
	  initViewRanges.xmax = plotdraw->xmax;
	  initViewRanges.xmin = plotdraw->xmin;
	  initViewRanges.ymax = ymax;
	  initViewRanges.ymin = ymin;
	
	  zoomHistories[0] = initViewRanges;

	  // update the view
	  [self adjustScrollBarLocations];
	  [plotView setNeedsDisplay:YES];
	}
}

///////////// Dataset and line drawer table methods /////////////////

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
	my_plot_draw_t *plotdraw = [[self document] plotDraw];

	int rowcount=0;
	
	int lsi=0;
	for(lsi = 0; lsi < plotdraw->line_set_count ; lsi++) {
		rowcount += plotdraw->line_set[lsi].line_count;		
	}
	return rowcount;
}

/* returns the line info at logical row */
static my_plot_line_info_t *locate_line_info(my_plot_draw_t *plotdraw, int row)
{	
	int currentrow = 0;
	int lsi=0;
	for(lsi = 0; lsi < plotdraw->line_set_count ; lsi++) {
		my_plot_line_info_t *line = plotdraw->line_set[lsi].line;
		int line_count = plotdraw->line_set[lsi].line_count;
		
		int i=0;
		for(i=0; i < line_count ; i++) {
			
			if(row == currentrow) {	
				return line+i;
			}
			currentrow++;
		}
	}	
	return NULL;
}

- (IBAction)lineEnabledClicked:(id)sender
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	int row = [plotTableView clickedRow];
	
	int currentrow = 0;
	int lsi=0;
	for(lsi = 0; lsi < plotdraw->line_set_count ; lsi++) {
		//my_dataset_t *dataset = plotdraw->line_set[lsi].dataset;
		my_plot_line_info_t *line = plotdraw->line_set[lsi].line;
		int line_count = plotdraw->line_set[lsi].line_count;
		
		int i=0;
		for(i=0; i < line_count ; i++) {
			
			if(row == currentrow) {					
				line[i].enabled = ! line[i].enabled;
				[plotView setNeedsDisplay:YES];
				return;
			}
			currentrow++;
		}
	}
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	//int colidx = [tableView columnWithIdentifier:[tableColumn identifier]];
	NSString *column = [tableColumn identifier];
	
	int currentrow = 0;
	int lsi=0;
	
	for(lsi = 0; lsi < plotdraw->line_set_count ; lsi++) {
		my_dataset_t *dataset = plotdraw->line_set[lsi].dataset;
		my_plot_line_info_t *line = plotdraw->line_set[lsi].line;
		int line_count = plotdraw->line_set[lsi].line_count;
		
		int i=0;
		for(i=0; i < line_count ; i++) {
			
			if(row == currentrow) {
				if([column isEqualToString:@"datafileName"]) {
					// datafile name
					const char *pathname = plotdraw->line_set[lsi].dataset->path_utf8;
					return [NSString stringWithCString:pathname encoding:NSUTF8StringEncoding]; 
					
				} else if([column isEqualToString:@"datasetName"]) {
					// dataset name
					const char *datasetname = plotdraw->line_set[lsi].dataset->name;
					return [NSString stringWithCString:datasetname encoding:NSUTF8StringEncoding]; 
					
				} else if([column isEqualToString:@"lineName"]) {
					// data name
					const char *linename = dataset->item[line[i].dataset_idx].name;
					return [NSString stringWithCString:linename encoding:NSUTF8StringEncoding];
					
				} else if([column isEqualToString:@"lineEnabled"]) {
					return line[i].enabled ? [NSNumber numberWithInt:1]  : nil;
				}
				break;
			}
			currentrow++;
		}
	}
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	//int colidx = [tableView columnWithIdentifier:[tableColumn identifier]];		
	NSString *column = [tableColumn identifier];
	
	if(! [anObject isKindOfClass:[NSString class]]) {
		return;
	}
	
	NSString *text = anObject;
	
	if([text length] == 0) {
		return;
	}
	
	const char *newtext = [text cStringUsingEncoding: NSUTF8StringEncoding];	
	
	int currentrow = 0;
	int lsi=0;
	
	for(lsi = 0; lsi < plotdraw->line_set_count ; lsi++) {
		my_dataset_t *dataset = plotdraw->line_set[lsi].dataset;
		my_plot_line_info_t *line = plotdraw->line_set[lsi].line;
		int line_count = plotdraw->line_set[lsi].line_count;
		
		int i=0;
		for(i=0; i < line_count ; i++) {
			
			if(row == currentrow) {
				if([column isEqualToString:@"datafileName"]) {
					// not editable
					return;
				} else if([column isEqualToString:@"lineEnabled"]) {
					// not editable
					return;
				} else if([column isEqualToString:@"datasetName"]) {
					// dataset name
					// TOOD: remove leak
					//free(plotdraw->line_set[lsi].dataset->name);
					plotdraw->line_set[lsi].dataset->name = strdup(newtext);
					[plotView setNeedsDisplay:YES];
					return;
					
				} else if([column isEqualToString:@"lineName"]) {		
					// data name
					free(dataset->item[line[i].dataset_idx].name);
					dataset->item[line[i].dataset_idx].name = strdup(newtext);						
					[plotView setNeedsDisplay:YES];
					return;
				}	
				break;
			}
			currentrow++;
		}
	}
}

/*
-(void)textDidEndEditing:(NSNotification *)notification {

	my_plot_draw_t *plotdraw = [[self document] plotDraw];	
	NSTextField *textfield = [[notification userInfo] objectForKey:@"NSFieldEditor"];
	const char *newtext = [[textfield stringValue] cStringUsingEncoding:NSUTF8StringEncoding];
	
	int row = [[notification object] editedRow];
	int col = [[notification object] editedColumn];	
	
	if(row >= 0 && col == 1) { 
		int currentrow = 0;
		int lsi=0;
		
		for(lsi = 0; lsi < plotdraw->line_set_count ; lsi++) {
			my_dataset_t *dataset = plotdraw->line_set[lsi].dataset;
			my_plot_line_info_t *line = plotdraw->line_set[lsi].line;
			int line_count = plotdraw->line_set[lsi].line_count;
			
			int i=0;
			for(i=0; i < line_count ; i++) {
				
				if(row == currentrow) {
					if(col == 0) {
						// datafilename
						free(plotdraw->line_set[lsi].dataset->name);
						plotdraw->line_set[lsi].dataset->name = strdup(newtext);
						return;
						
					} else if(col == 1) {
						// data name
						free(dataset->item[line[i].dataset_idx].name);
						dataset->item[line[i].dataset_idx].name = strdup(newtext);						
						return;
					}	
					break;
				}
				currentrow++;
			}
		}
		
	}
}
*/

@end
