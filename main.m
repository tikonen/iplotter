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
//  main.m
//  Plotter
//
//  Created by Teemu Ikonen on 2/23/06.
//

#import <Cocoa/Cocoa.h>

#include "system.h"

int main(int argc, char *argv[])
{
    return NSApplicationMain(argc, (const char **) argv);
}

boolean_t system_check_events(void) {
	return 0;
}

char *filename_to_utf8(const char *filename) {
	// OS X filename paths are utf-8 by default
	return strdup(filename);
}