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
#import "PlotDocument.h"
#import "PlotDrawWindowController.h"
#import "LoadIndicatorController.h"
#import "PlotError.h"

#include "misc-util.h"

@implementation PlotDocument

static paintapi_rgb_t default_line_colors[] = {
	{ 0xffff, 0x4444, 0x4444 },
	{ 0xffff, 0xc0c0, 0x4040 },
	{ 0x4040, 0xffff, 0x4040 },
	{ 0x4040, 0xffff, 0xffff },
	{ 0x4040, 0x8080, 0xffff },
	{ 0xffff, 0x0000, 0x0000 },
	{ 0x0000, 0xffff, 0x0000 },
	{ 0x0000, 0x0000, 0xffff },
	{ 0xffff, 0xffff, 0xffff },
};

- (id)init {
    self = [super init];
    if (self) {
		
		// initialize the dataset structure with default colors
		
        bzero(&plotdraw,sizeof(my_plot_draw_t));
	
		plot_draw_init(&plotdraw);
				
		// grid colors
		paintapi_rgb_t minor_color = { 0x6060, 0x6060, 0x6060 };
		plotdraw.grid.minor_color = minor_color;		
		paintapi_rgb_t major_color = { 0xc0c0, 0xc0c0, 0xc0c0 };
		plotdraw.grid.major_color = major_color;
		paintapi_rgb_t zerogrid_color = { 0xffff, 0x6060, 0x4040 };
		plotdraw.grid.zerogrid_color = zerogrid_color;
		paintapi_rgb_t sep_color = { 0x8080, 0x8080, 0x8080 };
		plotdraw.grid.sep_color = sep_color;
		paintapi_rgb_t label_color = { 0xffff, 0xffff, 0xffff };
		plotdraw.grid.label_color = label_color;
		//paintapi_rgb_t cursor_marker_color = { 0x8080, 0x8080, 0x8080 };
		//plotdraw.cursor_marker_color = cursor_marker_color;
		
		// legend
		paintapi_rgb_t legend_bg_color = { 0x2020, 0x2020, 0x2020 };
		plotdraw.legend.bg_color = legend_bg_color;
		paintapi_rgb_t legend_border_color = { 0xa0a0, 0xa0a0, 0xa0a0 };
		plotdraw.legend.border_color = legend_border_color;
		paintapi_rgb_t legend_text_color = { 0xe0e0, 0xe0e0, 0xe0e0 };
		plotdraw.legend.text_color = legend_text_color;
		
		// bookmark
		paintapi_rgb_t bookmark_color = { 0xffff, 0xffff, 0x0000 };
		plotdraw.bookmarks.color = bookmark_color;
		paintapi_rgb_t bookmark_text_color = { 0x0000, 0x0000, 0x0000 };
		plotdraw.bookmarks.text_color = bookmark_text_color;
		
		plotdraw.samples_per_pixel = 50;
		
		linecoloroffset = 0;
		linesetcount=0;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
	plot_draw_deinit(&plotdraw);
	    
    [super dealloc];
}

- (my_plot_draw_t *)plotDraw {
	return &plotdraw;
}

- (void)makeWindowControllers {
    PlotDrawWindowController *myController = [[PlotDrawWindowController allocWithZone:[self zone]] init];
    [self addWindowController:myController];
    [myController release];
}


// saves project file
- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)outError
{
	// parse in XML formatted project file
	NSXMLDocument *xmlDoc;
	NSXMLElement *rootElement = [[NSXMLElement alloc] initWithName:@"project"];
	
    xmlDoc = [[NSXMLDocument alloc] initWithRootElement:rootElement];
	[xmlDoc setCharacterEncoding:@"UTF-8"];
	
	// write datasets
	int di;
	for(di=0; di < plotdraw.line_set_count ; di++) {
		my_dataset_t *dataset = plotdraw.line_set[di].dataset;
		
		NSXMLElement *datase = [[NSXMLElement alloc] initWithName:@"datafile"];
		[rootElement addChild:datase];
		[datase addChild: [[NSXMLElement alloc] initWithName:@"path" stringValue:[NSString stringWithCString:dataset->path_utf8 encoding:NSUTF8StringEncoding]]];
		[datase addChild: [[NSXMLElement alloc] initWithName:@"name" stringValue:[NSString stringWithCString:dataset->name encoding:NSUTF8StringEncoding]]];			
		
		int li;
		for(li=0; li < dataset->item_count ; li++) {
			NSXMLElement *linee = [[NSXMLElement alloc] initWithName:@"line"];
			[datase addChild:linee];
			[linee addChild:[[NSXMLElement alloc] initWithName:@"column" stringValue:[NSString stringWithFormat:@"%d",li+1]]];
			[linee addChild:[[NSXMLElement alloc] initWithName:@"name" stringValue:[NSString stringWithCString:dataset->item[li].name encoding:NSUTF8StringEncoding]]];
			[linee addChild:[[NSXMLElement alloc] initWithName:@"enabled" stringValue:(plotdraw.line_set[di].line[li].enabled ? @"true" : @"false")]];			
		}
	}
	
	// write bookmarks
	int bi;
	for(bi=0; bi < plotdraw.bookmarks.bookmark_count ; bi++) {
		my_plot_bookmark_t *bookmark = &plotdraw.bookmarks.bookmark[bi];
		if(bookmark->timestamp > 0) {
			NSXMLElement *bme = [[NSXMLElement alloc] initWithName:@"bookmark"];
			[rootElement addChild:bme];
			
			// timestamps are stored as seconds from epoch
			unsigned int timestamp = bookmark->timestamp/1000;
			[bme addChild:[[NSXMLElement alloc] initWithName:@"timestamp" stringValue:[NSString stringWithFormat:@"%u",timestamp]]];
			if(bookmark->bookmark) {
				[bme addChild:[[NSXMLElement alloc] initWithName:@"note" stringValue:[NSString stringWithCString:bookmark->bookmark encoding:NSUTF8StringEncoding]]];	
			}
		}
	}
	
	// write project global settings
	[rootElement addChild:[[NSXMLElement alloc] initWithName:@"spp" stringValue:[NSString stringWithFormat:@"%d",(int)plotdraw.samples_per_pixel]]];
	
	NSData *data = [xmlDoc XMLDataWithOptions:NSXMLDocumentTidyXML];
	NSFileWrapper *filew = [[NSFileWrapper alloc] initRegularFileWithContents:data];
	[filew writeToFile:[absoluteURL path] atomically:YES updateFilenames:YES];
	[filew release];
	[xmlDoc release];
	
	return YES;
}


// reads dataset file
- (my_dataset_t *)readDataFile:(NSURL *)absoluteURL error:(NSError **)outError
{
	// find out the posix path for the file
	NSFileManager *sharedManager = [NSFileManager defaultManager];
	const char *path = [sharedManager fileSystemRepresentationWithPath: [absoluteURL path]];
	
	// TODO: check from file size if load indicator is required
	
	LoadIndicatorController *lc = [LoadIndicatorController sharedLoadIndicatorController];
	
	NSModalSession session = [NSApp beginModalSessionForWindow:[lc window]];
	[lc setFraction:0.0];
	[lc setLabel: [NSString stringWithFormat:@"Loading %@",[[absoluteURL path] lastPathComponent]]];
	
	path = strdup(path);
	my_dataset_t *dataset = read_dataset(path, progress_cb, session);
	
	[NSApp endModalSession:session];
	[[lc window] orderOut:self];
	
	if(!dataset) {
		//NSLocalizedDescriptionKey
		//NSLocalizedFailureReasonErrorKey
		
		NSArray *objArray = nil;
		NSArray *keyArray = nil;
		NSString *descrip;
		
		// some POSIX error			
		descrip = [NSString stringWithFormat:@"Error while reading the datafile '%s'",path];		
		objArray = [NSArray arrayWithObjects:descrip,[absoluteURL path],nil];
		keyArray = [NSArray arrayWithObjects:NSLocalizedDescriptionKey,NSFilePathErrorKey,nil];		
		NSDictionary *eDict = [NSDictionary dictionaryWithObjects:objArray forKeys:keyArray];
		*outError = [[[NSError alloc] initWithDomain:PlotErrorDomain code:0x1001 userInfo:eDict] autorelease];
		return nil;
	}
	
	// add dataset to draw
	dataset->maxdiff = 100 * TIME_MULTIPLIER;
	int lsi = plotdraw.line_set_count;
	my_plot_line_info_set_arr_set_length(plotdraw.line_set, lsi + 1);
	plotdraw.line_set[lsi].dataset = dataset;
		
	int dsi;
	for(dsi=0; dsi<dataset->item_count; ++dsi) {
		int li = plotdraw.line_set[lsi].line_count;
		my_plot_line_info_arr_set_length(plotdraw.line_set[lsi].line, li+1);
		int linecoloridx = linecoloroffset++;
		plotdraw.line_set[lsi].line[li].color = default_line_colors[linecoloridx % SZ(default_line_colors)];
		plotdraw.line_set[lsi].line[li].dataset_idx = dsi;
		plotdraw.line_set[lsi].line[li].enabled = 1;
		//plotdraw.line_set[lsi].line[li].linetype = TYPE_STEP;
	}
	
	return dataset;
}

// helper function for navigating the XML nodes
NSXMLElement *childElement(NSXMLElement *elem, NSString *name)
{
	NSXMLElement *child = (NSXMLElement *)[elem childAtIndex:0];
	do {
		if([[child name] isEqualToString:name]) {
			return child;
		}
	} while(child = (NSXMLElement *)[child nextSibling]);
	
	return nil;
}

- (BOOL)readProjectFile:(NSURL *)absoluteURL error:(NSError **)outError
{	
	// parse in XML formatted project file
	NSXMLDocument *xmlDoc;
	NSError *undError;
	
    xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:absoluteURL
												  options:(NSXMLNodePreserveWhitespace|NSXMLNodePreserveCDATA)
												  error:&undError];
    if (xmlDoc == nil) {
		// most likely parsing error
	
		/*
		NSString *descrip = NSLocalizedString(@"Unable to read project file.",@"");	
		NSString *reason = [undError localizedDescription];
		NSArray *objArray = [NSArray arrayWithObjects:descrip,reason,[absoluteURL path],nil];
		NSArray *keyArray = [NSArray arrayWithObjects:NSLocalizedDescriptionKey,NSLocalizedFailureReasonErrorKey,NSFilePathErrorKey,nil];
		*/
		NSString *reason = [undError localizedDescription];
		NSArray *objArray = [NSArray arrayWithObjects:reason,nil];
		NSArray *keyArray = [NSArray arrayWithObjects:NSLocalizedFailureReasonErrorKey,nil];
		
		
		NSDictionary *eDict = [NSDictionary dictionaryWithObjects:objArray forKeys:keyArray];
		*outError = [[[NSError alloc] initWithDomain:PlotErrorDomain code:0x1002 userInfo:eDict] autorelease];		
		
		//[self presentError:*outError];
		
		return NO;
		/*
		// possible retry?
        xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:absoluteURL
													  options:NSXMLDocumentTidyXML
														error:outError];
		*/
    }
	/*
    if (xmlDoc == nil)  {
        return NO;
    }
	 */

	BOOL success = NO;

	// parsing successful, read the datafiles
	NSArray *datafiles = [[xmlDoc rootElement] elementsForName:@"datafile"];
	int di;
	for(di=0; di < [datafiles count] ; di++) {
		NSXMLElement *dnode = (NSXMLElement *)[datafiles objectAtIndex:di];
		
		NSString *path = [childElement(dnode,@"path") stringValue];
		NSString *name = [childElement(dnode,@"name") stringValue];		
	
		if(path != nil) {
			my_dataset_t *dataset = [self readDataFile: [NSURL fileURLWithPath:path] error:outError];
			if(dataset) {
				if(name) {
					// override name
					dataset->name = strdup([name cStringUsingEncoding:NSUTF8StringEncoding]);
				}
				NSXMLElement *linee;
				for(linee = childElement(dnode,@"line"); linee ; linee = (NSXMLElement *)[linee nextSibling]) {
					NSString *index = [childElement(linee,@"column") stringValue];
					name = [childElement(linee,@"name") stringValue];
					NSString *enableds = [childElement(linee,@"enabled") stringValue];
					int enabled = 1;
					if(enableds) {
	                  enabled = ! [enableds isEqualToString:@"false"];
	                }
					if(index && name) {
						int idx = [index intValue];
						if(dataset->item_count >= idx) {
							// override name
							dataset->item[idx-1].name = strdup([name cStringUsingEncoding:NSUTF8StringEncoding]);
							plotdraw.line_set[di].line[idx-1].enabled = enabled;
						}
					}
				}
				success = success || YES;
			} else {
				[self presentError:*outError];
			}
		}
	}
	
	if(!success) {
		[xmlDoc release];
		return NO;
	}
	
	// read bookmarks
	NSArray *bookmarks = [[xmlDoc rootElement] elementsForName:@"bookmark"];
	int bi;
	for(bi=0; bi < [bookmarks count] ; bi++) {
		NSXMLElement *dnode = (NSXMLElement *)[bookmarks objectAtIndex:bi];
		
		float times = [[childElement(dnode,@"timestamp") stringValue] floatValue];
		NSString *note = [childElement(dnode,@"note") stringValue];		
		
		if(times > 0) {
			const char *notetext = nil;
			if(note) {
				notetext = [note cStringUsingEncoding:NSUTF8StringEncoding];
			}
			int bi=plotdraw.bookmarks.bookmark_count;
			my_plot_bookmark_arr_set_length(plotdraw.bookmarks.bookmark, plotdraw.bookmarks.bookmark_count+1);			
			plotdraw.bookmarks.bookmark[bi].timestamp = times * 1000;
			plotdraw.bookmarks.bookmark[bi].bookmark = notetext ? strdup(notetext) : NULL;
		}
	}
	plot_draw_sort_bookmarks(&plotdraw);
	
	// read project global settings
	NSXMLElement *sppe = childElement([xmlDoc rootElement],@"spp");
	if(sppe) {
		int spp = [[sppe stringValue] intValue];
	
		// vaidate samples per pixel
		if(spp <= 0) {
			spp = 4;
		} else if(spp > 100) {
			spp = 100;
		}
		
		plotdraw.samples_per_pixel = spp;
	}
	
	[xmlDoc release];
	
	return YES;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	BOOL result = NO;
	
	// validate the filetype
	if([absoluteURL isFileURL]) {		

		if([typeName isEqualToString:@"iPlotter project"]) {
			result =  [self readProjectFile: absoluteURL error:outError];
		} else {
			// read single text datafile
			result = [self readDataFile: absoluteURL error:outError] ? YES : NO;
		}
		linesetcount = plotdraw.line_set_count;
	}
	return result;
}

// reverts to document to the single dataset file.
- (IBAction)revertDocumentToSaved:(id)sender
{	
   while(plotdraw.line_set_count > linesetcount) {
	plot_draw_remove_data_file(&plotdraw,plotdraw.line_set_count-1);
   }
   linecoloroffset = plotdraw.line_set[0].line_count;

	/*
	NSArray *controllers = [self windowControllers];
	int i;
	for(i=0; i < [controllers count] ; i++) {
		NSWindowController *controller = [controllers objectAtIndex:i];
		if([controller isKindOfClass:[PlotDrawWindowController class]]) {
			PlotDrawWindowController *myController = (PlotDrawWindowController*)controller;
			[myController resetAndView];
			break;
		}
	}
	*/
	[[[self windowControllers] objectAtIndex:0] resetAndView];
}

- (IBAction)runPageLayout:(id)sender
{
	// call super, and cancel the change counter
	
	[super runPageLayout:sender];
	[self updateChangeCount:NSChangeUndone];
	[[[self windowControllers] objectAtIndex:0] setDocumentEdited:NO];
}


@end
