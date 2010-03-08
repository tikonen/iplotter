#!/usr/bin/perl -w
#
# Plot - plot time-based data on screen and to file with interactive controls
# Copyright (C) 2006  Jonas Berlin <xkr47@outerspace.dyndns.org>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
####
# xcpp - extended C preprocessor that supports multiline macros which
# also allow #defines to be used inside

use strict;

my %templates;

my %files;

my $err = 0;

my $export_mode = 0;

if($ARGV[0] eq "--export") {
    shift @ARGV;
    # just preprocess file to .c without including all .xh files
    $export_mode = 1;
}

unless($export_mode) {
    open DEPFILE, '>', $ARGV[0].".d";
    print DEPFILE $ARGV[1],": \\\n";
}

sub read_file {
    my ($path, $fd, $doprint) = @_;

    $files{$path} = 1;

    print '#line 1 "'.$path."\"\n" unless($export_mode);

    if($export_mode && $doprint && $path =~ m!\.xh$!) {
	my $mangled_path = $path;
	$mangled_path =~ s!.*/!!;
	$mangled_path =~ s![^a-zA-Z_]!_!g;
	print '#ifndef __xcpp_'.$mangled_path."\n";
	print '#define __xcpp_'.$mangled_path."\n";
    }

    my $lineno = 0;
    while(<$fd>) {
	++$lineno;
#     unless(m!^(.*)<<(\S+)\s*\{!) {
# 	print;
# 	next;
#     }

#     my ($pre, $key) = ($1, $2);
#     print $pre."\\\n";

#     while(<$fd>) {
# 	chomp;
# 	if(m!^\}\s*$key\s*;\s*$!) {
# 	    print "\n";
# 	    last;
# 	}
# 	print $_."\\\n";
 #     }

#######################################

	if(/^\#deftemplate\s+(\S+)\s*\(\s*(\S+(?:\s*,\s*\S+)*)\s*\)\s*$/) {
	    my ($name, $args) = ($1,$2);
	    if(defined($templates{$name})) {
		my $t = $templates{$name};
		print STDERR $path.':'.$lineno.": error: template '$name' already defined\n";
		print STDERR $t->[3].':'.$t->[2].": .. here\n";
		$err = 1;
	    }
	    my @args = split(/\s*,\s*/, $args);
	    my @lines;
	    my $firstline = $lineno + 1;
	    while(<$fd>) {
		++$lineno;
		last if(/^\#endtemplate\b/);
		push @lines, $_;
	    }
	    $templates{$name} = [ \@args, \@lines, $firstline, $path ] unless(defined($templates{$name}));
	    next;
	}

	if(/^\#template\s+(\S+)\s*\(\s*([^,]*(?:\s*,\s*[^,]*)*)\s*\)\s*$/) {
	    my ($name, $args) = ($1,$2);
	    my @args = split(/\s*,\s*/, $args);

	    my $tref = $templates{$name};
	    unless(defined($tref)) {
		print STDERR $path.':'.$lineno.": no such template $name\n";
		print "\n" if($doprint);
		next;
	    }
	    my ($targs, $tlines, $firstline, $tpath) = @$tref;

	    unless($#{$targs} == $#args) {
		print STDERR $path.':'.$lineno.": wrong number of arguments (expecting ".($#{$targs}+1).", got ".($#args+1).")\n";
		exit(1);
	    }

	    print '#line '.$firstline.' "'.$tpath."\"\n" unless($export_mode);
	    foreach (@$tlines) {
		my $line = $_;
		for(my $i=0; $i<=$#{$targs}; ++$i) {
#		$line =~ s/(?<![a-zA-Z0-9])$targs->[$i](?![a-zA-Z0-9])/$args[$i]/g;
		    $line =~ s/$targs->[$i]/$args[$i]/g;
		}
		$line =~ s/__TEMPLATE_FILE__/$path/g;
		$line =~ s/__TEMPLATE_LINE__/$lineno/g;
		print $line if($doprint);
	    }
	    print '#line '.($lineno+1).' "'.$path."\"\n" unless($export_mode);
	    next;
	}

	if(/^\#include\s+\"([^\"]+\.xh)\"/) {
	    my $newfilename = $1;
	    my $newpath = $path;
	    $newpath =~ s![^/]+$!!;
	    $newpath .= $newfilename;
	    
	    if(defined($files{$newpath})) {
		#print STDERR $path.':'.$lineno.": Already did $newpath\n";
		print "\n";
		next;
	    }

	    print DEPFILE "\t",$newpath," \\\n" unless($export_mode);

	    my $newfd;
	    unless(open $newfd, '<', $newpath) {
		print STDERR $path.':'.$lineno.": error: file '$newpath' not found\n";
		$err = 1;
		print "\n";
		next;
	    }

	    if($export_mode && $doprint) {
		$newfilename =~ s/\.xh/\.h/g;
		print "#include \"". $newfilename ."\"\n";
	    }
	    read_file($newpath, $newfd, !$export_mode);

	    close($newfd);
#	print '#line 1 "'.$path."\"\n";
#	    my $pathdef = "__".$newpath."_";
#	    $pathdef =~ s/[^a-zA-Z_]/_/g;
	    #print "#ifndef $pathdef\n#define $pathdef\n";
#	    while(<F>) {
#		print;
#	    }
	    #print "#endif\n";
	    print '#line '.($lineno+1).' "'.$path."\"\n" unless($export_mode);
	    next;
	}

	print if($doprint);
    }

    if($export_mode && $doprint && $path =~ m!\.xh$!) {
	print "#endif\n";
    }
}

read_file($ARGV[0], *STDIN, 1);

unless($export_mode) {
    print DEPFILE "\n";
    close DEPFILE;
}

exit($err);
