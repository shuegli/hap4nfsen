#!/usr/bin/perl

package EnhanceDot;

use Cwd;
use Switch;
my $cwd = getcwd;
push @INC,$cwd;

use strict;
use warnings;
use Sys::Syslog;

sub extendDot{
	my $BASEURL= shift;
	my $inputfile = shift;
	my $outputfile = shift;
	my $NODE_ID_FILTERS = shift;

	open(INPUT, "<$inputfile") or die $inputfile . ": " . $!;
	open(OUTPUT, "+>$outputfile") or die $outputfile . ": " . $!;

	my @lines = <INPUT>;

	for(my $i = 0; $i < @lines; $i++) {

		#Extending k5_* nodes which are IPs so clicking on them just replaces the local IP
		while($lines[$i] =~ m/^(k[1-5]_[0-9]+)(\[label=\")([#=\s\.\w:]+)(\"[rolnumip\",=\s\w\.]*)\];/) {
			my $key = $1;
			my $label = $2;
			my $value = $3;
			my $add = $4;
			my $urlextension;
			if($value =~ m/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) { # TODO: add support for IPv6
				$urlextension = "&ip=$value";
			}
			else {
				$urlextension = "&nodeid=$key";
			}
			if ($lines[$i] =~ m/.*(rolnum=)\"(\d+)\".*/) {
				$urlextension .= "&desum=$2";
			}
			printf OUTPUT $key.$label.$value.$add.", URL=\"$BASEURL$urlextension\", target=\"_parent\"];\n";
			$i++;
		}
		print OUTPUT $lines[$i] if ($i < @lines);

	}

	close(OUTPUT);

	# extract all nodeid information
	my $is_comments_section = 0;
	my %dot_file = (); # will contain all filters when parsing is complete 
	$NODE_ID_FILTERS->{"$inputfile"} = \%dot_file;
	for(my $i = 0; $i < @lines; $i++) {
		if ($is_comments_section || $lines[$i] =~ m/^\/\* Comments for HAP4NFSEN/) {
			$is_comments_section = 1;
		}
		if ($is_comments_section) {
			my @node = split(/=/, $lines[$i]);
			if (scalar(@node)>1) { # ignore comments that are not nodeid filters 
				my $node_name = $node[0];
				$node_name =~ s/\s*\*\s*//;
				my @node_filters = ();
				my %filter_detail = ();
				if (exists $dot_file{"$node_name"}) {
					push(@{$dot_file{"$node_name"}}, \%filter_detail);
				} else {
					$dot_file{"$node_name"} = \@node_filters;
					push(@node_filters, \%filter_detail);
				}
				my $partial_filter = $node[1];
				my @filters = split(/;/, $partial_filter);
				if (scalar(@filters) >= 4) {
					if ($filters[0]) {
						$filter_detail{'proto'} = $filters[0];
					}
					if ($filters[1]) {
						$filter_detail{'srcport'} = $filters[1];
					}
					if ($filters[2]) {
						$filter_detail{'dstport'} = $filters[2];
					}
					if ($filters[3]) {
						$filter_detail{'dstip'} = $filters[3];
					}
					if ($filters[4]) {
						$filter_detail{'direction'} = $filters[4];
					}
					if ($filters[5]) {
						$filter_detail{'desum'} = $filters[5];
					}
				} else {
					syslog("info", "wrong number of attributes in partial filter $_");
				}
			}
		}
	}
}
