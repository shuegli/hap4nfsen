#!/usr/bin/perl

use Cwd;
use Switch;
my $cwd = getcwd;
push @INC,$cwd;

use strict;
use warnings;
use EnhanceDot;

my $BASEURL="nfsen.php?tab=5&sub_tab=0";

if($#ARGV + 1 != 2 ){
	print "Usage: ./EnhanceDot.pl input.dot output.dot\n";
	exit -1;
}

EnhanceDot::extendDot($BASEURL, $ARGV[0], $ARGV[1]);

