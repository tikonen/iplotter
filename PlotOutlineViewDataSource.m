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
#import "PlotOutlineViewDataSource.h"

#define ROOT_TYPE			0
#define DATASET_TYPE		1
#define LINEINFO_TYPE		2

@interface PlotItem : NSObject
{
	PlotItem *parent;
	my_plot_draw_t *plotdraw;
	my_dataset_t *dataset;
	my_plot_line_info_set_t *lineinfo;
	int datasetidx;
	int type;
}

-(int)numberOfChildren;

@end

@implementation PlotItem

- (id)initWithPlot:(int)itemType itemData:(void *)data  parent:(PlotItem *)obj
{
    if (self = [super init])
    {
		type = itemType;

		switch(type) {
			case ROOT_TYPE:
				plotdraw = (my_plot_draw_t *)data;
				break;
			case DATASET_TYPE:
				dataset = (my_dataset_t *)data;
				break;
			case LINEINFO_TYPE:
				lineinfo = (my_plot_line_info_set_t *)data;
				break;
		}		
        parent = obj;
    }
    return self;
}

-(int)numberOfChildren
{

	switch(type) {
		case ROOT_TYPE:
			// return number of datasets
			return plotdraw->line_set_count;
			break;
		case DATASET_TYPE:
			// return series count of dataset
			return plotdraw->line_set[datasetidx].line_count;
			break;
		default:
			return -1;
	}
}

@end

@implementation PlotOutlineViewDataSource

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return (item == nil) ? YES : ([item numberOfChildren] != -1);
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
}

@end
