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
/* PlotDrawWindowController */

#import <Cocoa/Cocoa.h>

#include "plot_draw.h"

@class PlotDrawView;
@class OverlayView;

typedef struct {
	double xmin;
	double xmax;
	double ymin;
	double ymax;
} my_plot_view_range_t;

@interface PlotDrawWindowController : NSWindowController 
{	
	// the overlay window 
	IBOutlet NSWindow *overlayWindow;
	IBOutlet OverlayView *overlayView;
    
	// the main view
	IBOutlet PlotDrawView *plotView;
	IBOutlet NSScroller *hScrollBar;
	IBOutlet NSScroller *vScrollBar;
	
	// controls
	IBOutlet NSSegmentedControl *segments;
	IBOutlet NSTextField *startDateField;
	IBOutlet NSTextField *endDateField;	
	IBOutlet NSTextField *rangeField;
	IBOutlet NSButton *toggleButton;
	IBOutlet NSButton *showAllButton;
	
	// tableview panel
	IBOutlet NSMatrix *resolutionSelection;
	IBOutlet NSView *graphAuxView;
	IBOutlet NSTableView *plotTableView;
	IBOutlet NSTextField *samplesppEdit;
	IBOutlet NSSlider *samplesppSlider;

	// bookmarks
	IBOutlet NSDatePicker *bookmarkDate;
	IBOutlet NSTextField *bookmarkNoteEdit;
	IBOutlet NSPanel *addBookmarkPanel;
	IBOutlet NSTextField *edit;
	my_plot_bookmark_t *currentbm;
	
	// initial maximum and minimum y values.
	my_plot_view_range_t initViewRanges;
	double yMin;
	double yMax;
	
	// array of zoom history
	my_plot_view_range_t *zoomHistories;
	int zoomc;
	int zoomidx;
}

- (PlotDrawView *)plotView;


// actions for scrollbars
- (IBAction)xMoved:(id)sender;
- (IBAction)yMoved:(id)sender;

// generic actions for code, buttons and menu
- (IBAction)reloadDocument: (id)sender;
- (IBAction)okAddBookmarkPanel: (id)sender;
- (IBAction)closeAddBookmarkPanel:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (IBAction)toggleBookmarks:(id)sender;
- (IBAction)toggleLegendPosition:(id)sender;
- (IBAction)showAll:(id)sender;
- (IBAction)toggleInvertAction:(id)sender;
- (void)resetAndView;
- (void)addFiles:(NSArray *)urlsToOpen;
- (IBAction)addFileToDoc:(id)sender;
- (IBAction)printDocument:(id)sender;

// y-offset for paint
- (float)yOffset;

// NSTableDataSource informal protocol
- (int)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
- (IBAction)lineEnabledClicked:(id)sender;

@end
