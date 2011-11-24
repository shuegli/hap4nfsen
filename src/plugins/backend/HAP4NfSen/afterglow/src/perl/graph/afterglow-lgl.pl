#!/usr/bin/perl
#
# Copyright (c) 2006 by Raffael Marty and Chrisitan Beedgen
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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Written by:	Christian Beedgen (krist@digitalresearch.org)
# 		Raffael Marty (ram@cryptojail.net)
#
# URL:		http://afterglow.sourceforge.net
#
##############################################################
  
# ------------------------------------------------------------
# Main program.
# ------------------------------------------------------------

# Whether or not verbose mode is enabled.
# A value of '1' indicates that verbose mode is enabled.
# By default, verbose mode is disabled.
$verbose = 0;

# Whether or not verbose verbose mode is enabled.
# A value of '1' indicates that verbose mode is enabled.
# By default, verbose mode is disabled.
$verboseverbose = 0;

# Whether or not to split source and target nodes.
# A value of '1' indicates that the nodes will be split.
# Any other value means the nodes will not be split.
$splitSourceAndTargetNodes = 0;

# The number of lines to skip before starting to read.
$skipLines = 0;

# The maximum number of lines to read.
$maxLines = 999999;

# Process commandline options.
&init;

# Echo options if verbose.
print STDERR "Verbose mode is on.\n" if $verbose;
print STDERR "Skipping $skipLines lines.\n" if $verbose;
print STDERR "Reading a maximum of $maxLines lines.\n" if $verbose;
print STDERR "Splitting source and target nodes.\n" if $verbose && $splitSourceAndTargetNodes;
print STDERR "\n" if $verbose;

# The line counter.
$lineCount = 0;

# Read each line from the file.
while (($lineCount < $skipLines + $maxLines) and $line = <STDIN>) {
    
    # Increment the line count.
    $lineCount += 1;
    
    # Verbose progress output.
    if ($verbose) {

       if ($lineCount < $skipLines) { $skippedLines = $lineCount; }
       else { $skippedLines = $skipLines; }
       $processedLines = $lineCount - $skipLines if $verbose;
       print STDERR "\rLines read so far: $lineCount. Skipped: $skippedLines. Processed: $processedLines";
    }

    # Are we suppoed to skip lines still?
    next if $lineCount < $skipLines;
    
    # Split the input into source and target.
    ($source, $target) = ($line =~ /(.*),(.*)/);
    print STDERR "====> Processing: $source -> $target\n" if $verboseverbose;

    # Figure out the node names.
    $sourceName = &getSourceName($source, $target, $splitSourceAndTargetNodes);
    $targetName = &getTargetName($source, $target, $splitSourceAndTargetNodes);

    # Check if this target is already known for this source.
    undef %stupidperlcrap;
    for (@{$sourceTargetLinkMap{$sourceName}}) { $stupidperlcrap{$_} = 1 }

    # Add the target to this source.        
    push( @{$sourceTargetLinkMap{$sourceName}}, $targetName) unless $stupidperlcrap{$targetName};
}

# Write each source along all it's targets.
foreach $sourceName (keys %sourceTargetLinkMap) {

    print "# $sourceName\n";
    
    $targets = $sourceTargetLinkMap{$sourceName};
    foreach $target (@$targets) {
        print "$target\n";    
    }
}

# Debug output.
print STDERR "\n\nAll over, buster.\n" if $verbose;

#
#
# And this is the end of all things.
#
#

# ------------------------------------------------------------
# Subroutines.
# ------------------------------------------------------------

# Computes the name to use for a source node.
sub getSourceName {
    
    # Get the arguments.
    ($source, $target) = @_;

    # Return value depends on whether or not to split nodes.
    return "\"S:$source\"" if $splitSourceAndTargetNodes;
    return "\"$source\"";
}

# Computes the name to use for a source node.
sub getTargetName {
    
    # Get the arguments.
    ($source, $target) = @_;

    # Return value depends on whether or not to split nodes.
    return "\"T:$target\"" if $splitSourceAndTargetNodes;
    return "\"$target\"";
}

# Command line options processing.
sub init() {

    use Getopt::Std;
    getopts("hvsm:b:", \%opt ) or usage();

    # Help?
    usage() if $opt{h};
    
    # Verbose?
    $verbose = 1 if $opt{v};

    # Number of lines to skip?
    $skipLines = $opt{b} if $opt{b};

    # Maximum number of lines to read?
    $maxLines = $opt{m} if $opt{m};

    # Split source and target nodes?
    $splitSourceAndTargetNodes = 1 if $opt{s};
}

# Message about this program and how to use it.
sub usage() {

    print STDERR << "EOF";

Afterglow ---------------------------------------------------------------------
    
A program to visualize network activitiy data using graphs.
Uses the dot graph layout program fromt the Graphviz suite.
Input data is expected to be in this simple CSV-style format:
    
    [subject],   [object]
    10.10.10.10, 216.239.37.99

Usage:   afterglow-lgl.pl [-hvs]

-h        : this (help) message
-v        : verbose output
-l        : the maximum number of lines to read
-s        : split subject and object nodes

Example: cat somedata.txt | afterglow-lgl.pl -v | dot -Tgif -o somedata.gif

The dot exectutable from the Graphviz suite can be obtained
from the AT&T research website: http://www.research.att.com/sw/tools/graphviz/

EOF
    exit;
}
