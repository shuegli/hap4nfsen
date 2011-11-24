#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;

# usage:
# {nfdump call}|nfdump2csv.pl|{afterflow call}|

# parameters:
# [-i]	returns only IPs instead of IPs & ports
# [-b]  bi-directional flow mode

# example nfdump output
# Date flow start         Duration Proto    Src IP Addr:Port         Dst IP Addr:Port   Packets    Bytes Flows
# 2005-08-30 06:59:52.338    0.001 UDP    36.249.80.226:3040  ->   92.98.219.116:1434         1      404     1

# the following nfdump call generates data in the specified format:
# nfdump -M /data/nfsen/profiles-data/live/test -r 2010/12/22/nfcapd.201012220630 -n 50 -s record -o line6 -A srcip,dstport

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

my %OUTPUT_OPTIONS = ( # configuration allows to select, invert and duplicate fields of the parsed nfdump output
	'->'	=>	[
				[
					3,
					5,
				],
			],
	'<->'	=>	[
				[
					3,
					5,
				],
				[
					5,
					3,
				],
			],
	'<-'	=>	[
				[
					5,
					3,
				],
			],
);

my $SKIP_PATTERN = '(?:\s*|Date flow|Summary:|Time window:|Time window:|Sys:|Total flows processed:|Aggregated flows|Top.*\d+.*ordered by.*).*';
my $IP_PORT_SPLIT_PATTERN = '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|.{4}:.{4}:.{4}:.{4}:.{4}:.{4}:.{4}:.{4}):(\d+(?:\.\d+))?';

my $ip_only;
my $bi_directional_flows;

# extracts ip from ip:port field if -i flag is active
sub extractIpFromIpPort($) {
	my $ip_port = $_[0];
	my @parts = split(/$IP_PORT_SPLIT_PATTERN/,$ip_port);
	if ($ip_only) {
		return $parts[1];
	}
	$ip_port =~ s/\Q$parts[1]:\E//;
	if ($ip_port =~ m/(\A0|\d+\.\d+)/) { # must be ICMP => do not use port information
		return $parts[1];
	}
	return $parts[1].':'.$ip_port;
}

GetOptions(
	"i"	=>	\$ip_only,
	"b"	=>	\$bi_directional_flows,
);

my $PATTERN = '';
foreach (@INPUT_FORMAT) {
	$PATTERN .= '\s*('.$PATTERNS{$_}.')\s*';
}

while (<STDIN>) {
	chomp;
	if ($_ =~ /$PATTERN/) {
		my @record = split(/$PATTERN/, $_);
		my $flow_dir = ($bi_directional_flows)?'<->':$record[5];
		my $out_row_patterns = $OUTPUT_OPTIONS{$flow_dir};
		foreach (@{$out_row_patterns}) {
			my @output = ();
			foreach (@{$_}) {
				my $value = @record[($_+1)];
				if ($_==3||$_==5) {$value = extractIpFromIpPort($value);}
				push(@output, $value);
			};
			print join(',',@output)."\n";
		}
	} else {
		if ($_ =~ /$SKIP_PATTERN/) {
			next; # caption or summary row
		}
		die 'unable to parse record: '.$_."\n";
	}
}


