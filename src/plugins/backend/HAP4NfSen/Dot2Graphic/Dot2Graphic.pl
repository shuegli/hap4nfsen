#!/usr/bin/perl
use Cwd;
my $cwd = getcwd;
push @INC,$cwd;
use Dot2Graphic;

my $type = $ARGV[0];
my $infile = $ARGV[1];
my $outfile = $ARGV[2];

sub usage{
	print "Usage: ./Dot2Graphic type sourcefile outfile\n";
	exit -1;
}

unless ($#ARGV + 1 == 3)
{
	usage;
}

print "Type: $type\n";
print "Infile: $infile\n";
print "Outfile: $outfile\n";

my $retval = Dot2Graphic::dot2graphic($type, $infile, $outfile);

print "Retval: ".$retval."\n";
