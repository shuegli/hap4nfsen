#!/usr/bin/perl
use Cwd;
my $cwd = getcwd;
push @INC,$cwd; #usefull for testing, does not require a global installation

use NfDump2Dot;

my $infile = $ARGV[0];
my $outfile = $ARGV[1];
my $ip = $ARGV[2];

sub usage{
	print "Usage: ./NfDump2Dot.pl sourcefile outfile ip\n";
	exit -1;
}

unless ($#ARGV + 1 == 3)
{
	usage;
}

print "Infile: $infile\n";
print "Outfile: $outfile\n";
print "IP: $ip\n";

my $retval = NfDump2Dot::nfdump2dot($infile, $outfile, $ip, "", 1, 1, 0, 0);

print "Retval: ".$retval."\n";
