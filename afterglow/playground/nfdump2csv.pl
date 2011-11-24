#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;

# example nfdump output
# Date flow start         Duration Proto    Src IP Addr:Port         Dst IP Addr:Port   Packets    Bytes Flows
# 2005-08-30 06:59:52.338    0.001 UDP    36.249.80.226:3040  ->   92.98.219.116:1434         1      404     1

my %PATTERNS = (
	'DATE_TIME'	=>	'\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}.\d{3}',
	'DURATION'	=>	'\d+(?:\.\d+)?',
	'PROTO'		=>	'\w+',													# allows all protocols
	'IP_PORT'	=>	'(?:\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|.{4}:.{4}:.{4}:.{4}:.{4}:.{4}:.{4}:.{4}):\d+(?:\.\d+)?',
	'PACKET'	=>	'\d+',
	'BYTES'		=>	'\d+',
	'FLOWS'		=>	'\d+',
	'FLOW_DIRECTION'=>	'(?:<-|<->|->)',
);

my @INPUT_FORMAT = (
	'DATE_TIME',
	'DURATION',
	'PROTO',
	'IP_PORT',
	'FLOW_DIRECTION',
	'IP_PORT',
	'PACKET',
	'BYTES',
	'FLOWS',
);

my @OUTPUT_COLUMNS = (
	3,
#	2,
	5,
);

my $SKIP_PATTERN = '(?:\s*|Date flow|Summary:|Time window:|Time window:|Sys:|Total flows processed:|Aggregated flows|Top.*\d+.*ordered by.*).*';
my $IP_PORT_SPLIT_PATTERN = '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|.{4}:.{4}:.{4}:.{4}:.{4}:.{4}:.{4}:.{4}):(\d+(?:\.\d+))?';

sub extractIpFromIpPort($) {
	my $ip_port = $_[0];
	my @parts = split(/$IP_PORT_SPLIT_PATTERN/,$ip_port);
	return $parts[1];
}

my $PATTERN = '';
foreach (@INPUT_FORMAT) {
	$PATTERN .= '\s*('.$PATTERNS{$_}.')\s*';
}

while (<STDIN>) {
	chomp;
	if ($_ =~ /$PATTERN/) {
		my @record = split(/$PATTERN/, $_);
		my @output = ();
		foreach (@OUTPUT_COLUMNS) {
			my $value = @record[($_+1)];
			if ($_==3||$_==5) {$value = extractIpFromIpPort($value);} # hack..
			push(@output, $value);
		};
		print join(',',@output)."\n";
	} else {
		if ($_ =~ /$SKIP_PATTERN/) {
			next; # caption or summary row
		}
		die 'unable to parse record: '.$_."\n";
	}
}


