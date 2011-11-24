package HAP4NfSen;

use strict;
use NfProfile;
use NfConf;
BEGIN {
	push @INC,"$NfConf::BASEDIR/plugins/HAP4NfSen/Dot2Graphic";
	push @INC,"$NfConf::BASEDIR/plugins/HAP4NfSen/NfDump2Dot";
	push @INC,"$NfConf::BASEDIR/plugins/HAP4NfSen/EnhanceDot";
}
use File::Path;
use Dot2Graphic;
use NfDump2Dot;
use IO::Handle;
use File::Copy;
use File::stat;
use File::Basename;
use EnhanceDot;
use Data::Dumper;
use Digest::MD5;
use List::Util qw[min max];

#
# The plugin may send any messages to syslog
# Do not initialize syslog, as this is done by 
# the main process nfsen-run
use Sys::Syslog;

# frontend->backend mappings configuration
our %cmd_lookup = (
	'generateGraphlet'			=>	\&GenerateGraphlet,
        'assembleNetflowData'   		=>      \&AssembleNetflowData,
        'generateDotFile'       		=>      \&GenerateDotFile,
	'getConfig'				=>	\&GetConfig,
	'generateIpChooser'			=>	\&GetIpChooser,
);

our $VERSION = 130;

our $NETFLOW_FILE_EXTENSION = "netflow";
our $DOT_FILE_EXTENSION = "dot";
our $HAP_TEMP_FILE_EXTENSION = "hpg";
our $OUTPUT_FORMAT = "svg";
our $FILTER_FORMAT = "filter";

our $DELETE_FILES_AFTER = 60*5; # in seconds

our $WORK_DIR = "/tmp/hap4nfsen/";
our $IMAGE_DIR = "/data/nfsen/plugins/";

our %NODE_ID_FILTERS = ();

my ( $nfdump, $PROFILEDIR );

# generates afterglow image for the ip chooser
sub GetIpChooser {
	my $socket  = shift;
	my $opts    = shift;
	my %args;

	# check parameters
        if ( !exists $$opts{'hap4nfsen_type'} ||
                !exists $$opts{'hap4nfsen_profile'} ||
                !exists $$opts{'hap4nfsen_srcselector'} ||
                !exists $$opts{'hap4nfsen_filter'} ||
                !exists $$opts{'hap4nfsen_args'} ||
		!exists $$opts{'hap4nfsen_plugin_id'} ||
		!exists $$opts{'hap4nfsen_graph_type'} ||
		!exists $$opts{'hap4nfsen_ip_only_mode'}) {
                Nfcomm::socket_send_error($socket, "Missing parameters");
		syslog("info", "GetIpChooser: missing parameters");
                return;
        }

	my $type = $$opts{'hap4nfsen_type'};
	my $plugin_id = $$opts{'hap4nfsen_plugin_id'};
        my $profile = $$opts{'hap4nfsen_profile'};
        my $srcselector = $$opts{'hap4nfsen_srcselector'};
        my $nfdump_args = $$opts{'hap4nfsen_args'};
        my $filters = $$opts{'hap4nfsen_filter'};
        my $and_filter = $$opts{'hap4nfsen_and_filter'};
	my $graph_type = $$opts{'hap4nfsen_graph_type'};

	my $conf = $NfConf::PluginConf{HAP4NfSen};
	my $top_x = 50; # does impact performance. higher number -> more edges -> bigger graphs/(much)longer rendering times
	if (exists $$opts{'hap4nfsen_record_count'}) {
		$top_x = $$opts{'hap4nfsen_record_count'};
	}
	if (exists $$conf{'ip_chooser_top_x'}) { # configured value allows to limit the max number of records
		$top_x = min($$conf{'ip_chooser_top_x'}, $top_x);
	} else {
		syslog("info", "parameter 'ip_chooser_top_x' not configured. using default value: $top_x");
	}

	# prepare parameters for call
        my $image_name = getUuid() . ".svg";
	my $afterglow_properties = "$NfConf::BASEDIR/plugins/HAP4NfSen/afterglow/src/perl/parsers/ip_chooser.properties";
	my $afterglow_app = "$NfConf::BASEDIR/plugins/HAP4NfSen/afterglow/src/perl/graph/afterglow.pl";
	my $parser_app = "$NfConf::BASEDIR/plugins/HAP4NfSen/afterglow/src/perl/parsers/nfdump2csv.pl";
	my $graphviz_app = "neato";
	my $data_location = assembleNfDumpArguments($type, $profile, $srcselector, $nfdump_args, $filters, $and_filter, 'any', 'any', 1);
	if ($data_location =~ m/-b/i) {
		$parser_app .= ' -b'
	}
	if ($$opts{'hap4nfsen_ip_only_mode'}) {
		$parser_app .= ' -i';
	}
	#$data_location =~ s/\s-b\s/ /g; # remove the -b flag
	$data_location =~ s/(\s(-c|-n)\s+\d+)/ /g; # remove the -c or -n flag and its numerical value
	$data_location =~ s/\s-o\s+\S+/ /g; # remove the -o flag.

	# prepare calls
	$top_x = (($graph_type eq 'flow')?'-c':'-n').' '.$top_x; # different flags are used to limit the number of flow or stat records
	my $nfdump_call = "$NfConf::PREFIX/nfdump $data_location -o line6 $top_x";
	my $afterglow_call = "$parser_app|$afterglow_app -p2 -t -a -c $afterglow_properties";
	my $graphviz_call = "$graphviz_app -Tsvg -v -Gmaxiter=20000 -Nfontname=monospace -Nfontsize=8 -Elen=2 -Goverlap=stretch -Gsep=0 -Gsplines=true -o $IMAGE_DIR$image_name";
	my $system_call = "$nfdump_call | $afterglow_call | $graphviz_call";

	# execute nfdump->parser->afterglow->graphviz to generate picture
	my $generated_image = '';
	syslog("info", "ip chooser command: $system_call");
	chdir "$NfConf::BASEDIR/plugins/HAP4NfSen/afterglow/src/perl/graph/";
	system($system_call);
	my $return_value = ($?>>8);
	my $target_exp = "s/xlink:href/target=\"_parent\" xlink:href/g";
	my $sub_tab_exp = "s/sub_tab=x/sub_tab=$plugin_id/g";
	my $ip_port_exp = "s/\\(.*ip=\\)\\(\\([0-9]\\+\\.\\?\\)\\+\\):\\([^&]*\\)/\\1\\2\\&amp;port=\\4/g";
	system("sed -i '$target_exp;$sub_tab_exp;$ip_port_exp' $IMAGE_DIR$image_name"); # adds target attribute to all links and sets the correct sub-tab number
	my $link_count_command = "grep \"xlink:href\" $IMAGE_DIR$image_name | wc -l";
	my $link_count = `$link_count_command`;
	if ($link_count > 0 && $return_value != -1) { # TODO: problems with return values..
		$args{'hap4nfsen_ipchooser_pic'} = $image_name;
	        Nfcomm::socket_send_ok($socket, \%args);
		return;
	}
	Nfcomm::socket_send_error($socket, "GetIpChooser: failed to generate IP chooser image");
}

# returns an array containing plugin configuration information to the front end.
sub GetConfig {
        my $socket  = shift;
 
        my $conf = $NfConf::PluginConf{HAP4NfSen};
	my %args;
        if (exists $$conf{'max_history'}) {
                $args{'hap4nfsen_max_history'} = $$conf{'max_history'};
        } else {
		$args{'hap4nfsen_max_history'} = 16;
                syslog("info", "no value specified for hap4nfsen front end parameter max_history. Using default value: 16");
        }
        if (exists $$conf{'graph_zoom_limit'}) {
                $args{'hap4nfsen_graph_zoom_limit'} = $$conf{'graph_zoom_limit'};
        } else {
		$args{'hap4nfsen_graph_zoom_limit'} = 128;
                syslog("info", "no value specified for hap4nfsen front end parameter graph_zoom_limit. Using default value: 128");
        }
        if (exists $$conf{'graph_display_limit'}) {
                $args{'hap4nfsen_graph_display_limit'} = $$conf{'graph_display_limit'};
        } else {
		$args{'hap4nfsen_graph_display_limit'} = 1024;
                syslog("info", "no value specified for hap4nfsen front end parameter graph_display_limit. Using default value: 1024");
        }

        Nfcomm::socket_send_ok($socket, \%args);
}

# assembles netflow data, writes it to a file and returns the file name
sub AssembleNetflowData {
        my $socket  = shift;
        my $opts    = shift;

        # check parameters
        if ( !exists $$opts{'hap4nfsen_type'} || 
		!exists $$opts{'hap4nfsen_profile'} ||
		!exists $$opts{'hap4nfsen_srcselector'} ||
		!exists $$opts{'hap4nfsen_filter'} ||
		!exists $$opts{'hap4nfsen_args'} ) {
                Nfcomm::socket_send_error($socket, "Missing parameters");
                return;
        }

        my $type = $$opts{'hap4nfsen_type'};
        my $profile = $$opts{'hap4nfsen_profile'};
        my $srcselector = $$opts{'hap4nfsen_srcselector'};
        my $nfdump_args = $$opts{'hap4nfsen_args'};
	my $filters = $$opts{'hap4nfsen_filter'};
	my $hap_filter = $$opts{'hap4nfsen_hapfilter'};
	my $and_filter = $$opts{'hap4nfsen_and_filter'};
	my $node_id_filter = "";
	my $node_id_count = 0;
	while (exists $$opts{'hap4nfsen_node_id_filters_'.$node_id_count}) {
		$node_id_filter .= ($$opts{'hap4nfsen_node_id_filters_'.$node_id_count});
		$node_id_count++;
	}

	my $netflow_file = "nfcapd." . getUuid() . ".$NETFLOW_FILE_EXTENSION";
	my $nfdump_command = "$NfConf::PREFIX/nfdump " . assembleNfDumpArguments($type, $profile, $srcselector, $nfdump_args, $filters, $and_filter, $hap_filter, $node_id_filter, 0) . " -w $WORK_DIR$netflow_file";

	chdir $WORK_DIR;

	syslog("info", "HAP4NfSen: $nfdump_command");
	# FIXME: system call fails. investigate
	createWorkDir();
	system($nfdump_command);
	if ( ($?>>8) == -1 ) {
		syslog("info", "HAP4NfSen: nfdump call failed: $?");
                Nfcomm::socket_send_error($socket, "nfdump call failed");
                return;
	}
	#else
	syslog("info", "nfdump call successful:".($?>>8)."=>$!");
	#unless (-e $netflow_file) {
	#	Nfcomm::socket_send_error($socket, "Netflow data file generation failed");
	#}

        my %args;
        $args{'hap4nfsen_netflow_file'} = $netflow_file;
        Nfcomm::socket_send_ok($socket, \%args);
}

# generates a .dot file using hap lib. returns the name of the created file
sub GenerateDotFile {
        my $socket  = shift;
        my $opts    = shift;

        # check parameters
        if ( !exists $$opts{'hap4nfsen_netflow_file'} || !exists $$opts{'hap4nfsen_ip'} ||  
		!exists $$opts{'hap4nfsen_summarization_client_roles'} || !exists $$opts{'hap4nfsen_summarization_multi_client_roles'} ||
		!exists $$opts{'hap4nfsen_summarization_server_roles'} || !exists $$opts{'hap4nfsen_summarization_p2p_roles'} ||
		!exists $$opts{'hap4nfsen_plugin_id'}) {
		syslog("info", "HAP4NfSen: Missing parameters in GenerateDotFile");
		Nfcomm::socket_send_error($socket, "Missing parameters");
		return;
        }

	my $desummarized_roles = (exists $$opts{'hap4nfsen_desummarized_role_list'})?$$opts{'hap4nfsen_desummarized_role_list'}:'';
        my $netflow_file = $$opts{'hap4nfsen_netflow_file'};
	my $ip = $$opts{'hap4nfsen_ip'};
	my $dot_file = $WORK_DIR . getUuid() . ".$DOT_FILE_EXTENSION";
	my $summarization_client_roles = ($$opts{'hap4nfsen_summarization_client_roles'})?1:0;
	my $summarization_multi_client_roles = ($$opts{'hap4nfsen_summarization_multi_client_roles'})?1:0;
	my $summarization_server_roles = ($$opts{'hap4nfsen_summarization_server_roles'})?1:0;
	my $summarization_p2p_roles = ($$opts{'hap4nfsen_summarization_p2p_roles'})?1:0;
	my $front_end_plugin_id = $$opts{'hap4nfsen_plugin_id'};

	createWorkDir();
	chdir $WORK_DIR;
	
	
	syslog("info", "HAP4NfSen: calling NfDump2Dot::nfdump2dot(\"$netflow_file\", \"$dot_file\", \"$ip\", \"$desummarized_roles\", \"$summarization_client_roles\", \"$summarization_multi_client_roles\", \"$summarization_server_roles\", \"$summarization_p2p_roles\")");
        NfDump2Dot::nfdump2dot($netflow_file, $dot_file, $ip, $desummarized_roles, $summarization_client_roles, $summarization_multi_client_roles, $summarization_server_roles, $summarization_p2p_roles);
	unlink($netflow_file); # TODO: re-enable
	unlink("$netflow_file\$.hpg"); # delete temporary file created by the hap library
	enhanceDotFileWithImageMapInformation($dot_file, $front_end_plugin_id);
	my @node_id_filters = getNodeIdFilter($dot_file);
	my @node_id_summarizations = getNodeIdFilter($dot_file, "getSummarizations");
	my $node_count = getNodeCount($dot_file);
	my %args;
        $args{'hap4nfsen_dot'} = $dot_file;
	$args{'hap4nfsen_node_count'} = $node_count;
	$args{'hap4nfsen_node_id_filters'} = \@node_id_filters;
	$args{'hap4nfsen_node_id_summarization'} = \@node_id_summarizations;
        Nfcomm::socket_send_ok($socket, \%args);
}

# converts a dot file to an image using graphviz, stores it in the work directory and returns a file name.
sub GenerateGraphlet {
	my $socket  = shift;
	my $opts    = shift;
	
	# check parameters
	if ( !exists $$opts{"hap4nfsen_dot_file"} ) {
		Nfcomm::socket_send_error($socket, "Missing parameters");
		return;
	}
	my $dot_file = $$opts{"hap4nfsen_dot_file"};
	my $generated_name = getUuid();
	my $graphlet_file = $generated_name . "." . $OUTPUT_FORMAT;

	# convert dot file to image
	createWorkDir();
	Dot2Graphic::dot2graphic($OUTPUT_FORMAT, $dot_file, $WORK_DIR . $graphlet_file);
	unlink($dot_file);
	if (exists $$opts{"hap4nfsen_disable_svg_js"} && !$$opts{"hap4nfsen_disable_svg_js"}) {
                enhanceSvgWithZoomFunctionality($graphlet_file);
        } else {
                move($graphlet_file, $IMAGE_DIR.$graphlet_file);
        }
	system("sed -i 's/<\\/svg>/<script xlink:href=\"plugins\\/HAP4NfSen\\/drilldown.js\"\\/><\\/svg>/g' $IMAGE_DIR$graphlet_file"); # add drilldown functionality

	my %args;
	$args{'hap4nfsen_graphlet'} = $graphlet_file;
	Nfcomm::socket_send_ok($socket, \%args);
}

# adds (java script-)zoom functionality to svg file
sub enhanceSvgWithZoomFunctionality {
	if (!exists $_[0]) {
		syslog("info", "no svg file specified. skipping file enhancement.");
		return;
	}

	my $svg_file_name = $_[0];
	syslog("info", "enhancing svg file $svg_file_name");
	my $tmp_file_name = $WORK_DIR . "tmp_" . $svg_file_name;
	my $in_file;
	my $out_file;
	createWorkDir();
	open( $in_file,  "<$svg_file_name" ) || syslog("info", "could not open svg for reading");
	open( $out_file, ">$tmp_file_name" ) || syslog("info", "could not open temporary svg for writing");
	my $line;
	my $in_svg_tag = 0;
	while (<$in_file>) {
		$line = $_;
		if (!$in_svg_tag && $line =~ m/<svg.*/) { # check if line contains svg start tag
			$line =~ s/width=".*?"//g; # remove width
			$line =~ s/height=".*?"//g; # remove height
			print $out_file $line;
			$in_svg_tag = 1;
		} elsif ($in_svg_tag && $line =~ m/>/) {
			$line =~ s/viewBox=".*?"//g; # remove viewbox
			print $out_file $line;
                        print $out_file "<script xlink:href=\"plugins/HAP4NfSen/SVGPan.js\"/>\n";
			$in_svg_tag = 0;
		} elsif ($line =~ m/<g.*id="graph0"/) {
			$line =~ s/scale\(.*?\)//g; # change scale attribute
			print $out_file $line;
		} else {
			print $out_file $line;
		}
	}
	close($in_file);
	close($out_file);
	unlink($svg_file_name);
	move( $tmp_file_name, "$IMAGE_DIR$svg_file_name" );
}

# adds image map infromation to dot file
sub enhanceDotFileWithImageMapInformation {
	my $dot_input_file = $_[0];
	my $plugin_id = $_[1];
	my $BASEURL="nfsen.php?tab=5&sub_tab=$plugin_id";

	my $dot_output_file = "$dot_input_file.new";
	syslog("info", "enhancing dot file $dot_input_file to $dot_output_file");

	EnhanceDot::extendDot($BASEURL, $dot_input_file, $dot_output_file, \%NODE_ID_FILTERS);
	move($dot_output_file, $dot_input_file);
}

# generates a filter for specified node id
sub getNodeIdFilter {
	if (!exists $_[0]) {
                syslog("info", "no dot file specified");
                return "";
        }

        my $dot_input_file = $_[0];
	my $generate_sync_filters;
	if (exists $_[1]) {
		$generate_sync_filters = $_[1];
	}
        my $node_id = '';
	my @filters = ();

	if (!exists $NODE_ID_FILTERS{$dot_input_file}) {
		syslog("info", "no keys for specified dot file($dot_input_file) found");
                return "";
	}
        my $node_ids = $NODE_ID_FILTERS{$dot_input_file};
	foreach $node_id (keys %$node_ids) {
		my $nodes = $node_ids->{$node_id};
		my $filter = "";
		if ($generate_sync_filters) {
			foreach (@{$nodes}) {
				if (exists($_->{'desum'})) {
					my $value = $_;
					$value =~ s/^\s+//;
					$value =~ s/\s+$//;
					if ($value) {
						push(@filters, "$node_id=".$_->{'desum'});
					}
				}
			}
		} else {
			$filter .= "(";
			my $proto_connector = "";
			foreach (@{$nodes}) {
				my $filter_connector = "";
				my $flow_direction = 0;
				if (exists $_->{'direction'}) {
					if ($_->{'direction'} eq "inflow" || $_->{'direction'} eq "unibiflow_in") {
						$flow_direction = 2;
					} elsif ($_->{'direction'} eq "outflow" || $_->{'direction'} eq "unibiflow_out") {
						$flow_direction = 1;
					}
				}
				$filter = "$filter$proto_connector(";
				if (exists($_->{'srcip'})) {
					my @attribute_names = ("ip", "src ip", "dst ip");
                			$filter .= "$filter_connector".generatePartialNfDumpFilter(@attribute_names[$flow_direction], $_->{'srcip'});
                        		$filter_connector = " and ";
				}
				if (exists($_->{'dstip'})) {
					my @attribute_names = ("ip", "dst ip", "src ip");
					$filter .= "$filter_connector".generatePartialNfDumpFilter(@attribute_names[$flow_direction], $_->{'dstip'});
					$filter_connector = " and ";
				}
				if (exists($_->{'proto'})) {
					$filter .= "$filter_connector".generatePartialNfDumpFilter("proto", $_->{'proto'});
					$filter_connector = " and ";
				}
				if (exists($_->{'srcport'})) {
					if (uc($_->{'proto'}) ne "ICMP") {
						my @attribute_names = ("port", "src port", "dst port");
						$filter .= "$filter_connector".generatePartialNfDumpFilter(@attribute_names[$flow_direction], $_->{'srcport'});
						$filter_connector = " and ";
					}
        		        }
				if (exists($_->{'dstport'})) {
					if (uc($_->{'proto'}) ne "ICMP") {
						my @attribute_names = ("port", "dst port", "src port");
        	        	        	$filter .= "$filter_connector".generatePartialNfDumpFilter(@attribute_names[$flow_direction], $_->{'dstport'});
        		                	$filter_connector = " and ";
					}
		                }
				$filter = "$filter)";
				$proto_connector = " or ";
			}
			$filter .= ")";
			my $filter_length = length($filter);
			my $count = 0;
			while ($count <= $filter_length) {
				my $max_length = 900;
				my $start = $count;
				my $max_end = 0;
				my $end = ($start + $max_length>$filter_length)?$filter_length:$start + $max_length;
				if ($end != $filter_length) {
					while (!(substr($filter,$end-1,3) =~ m/\S\S\S/)) {
						$end--;
					}
				}
				my $partial_filter = substr($filter, $start, ($end-$start)+1);
				$count = $end+1;
				push(@filters, "$node_id=".$partial_filter);
			}
		}
	}
	return @filters;
}

# generates a partial nfdump filter from node id information
sub generatePartialNfDumpFilter {
        my $filter_name = $_[0];
        my $filter_value = $_[1];
	$filter_value =~ s/^\s+//;
	$filter_value =~ s/\s+$//;

	if (!$filter_value) {
		return "(any)"
	}

	if ($filter_value  =~ m/,/) {
		my $filter = "(";
		my @filter_values = split(/,/, $filter_value);
		my $connector = "";
		foreach (@filter_values) {
			$filter .= "$connector$filter_name $_";
			$connector = " or ";
		}
		$filter .= ")";
		return $filter;
	} else {
		return "$filter_name $filter_value";
	}
}

# calculates an estimate of the number of nodes
sub getNodeCount {
        if (!exists $_[0]) {
                syslog("info", "no dot file specified");
                return undef;
        }

        my $dot_input_file = $_[0];
        if (!exists $NODE_ID_FILTERS{$dot_input_file}) {
                syslog("info", "no keys for specified dot file($dot_input_file) found");
                return undef;
        }
        my $node_ids = $NODE_ID_FILTERS{$dot_input_file};
        return scalar(keys %$node_ids);
}

# generates and returns a unique id.
sub getUuid {
	return Digest::MD5::md5_hex(rand * time); # used to generate the unique id
}

# function is periodically called by nfsen. deletes files older than $DELETE_FILES_AFTER from the work dir.
sub run {
	syslog("info", "periodic cleanup");
	cleanWorkdir();
	return;
}

# not used
sub alert_condition {
return 1;
}

# not used
sub alert_action {
return 1;
}

# creates the work_dir. Function is called before accessing files in the work_dir because open bsd deletes content of /tmp
# (default location for work_dir) once a day.
sub createWorkDir {
	mkdir($WORK_DIR);
}

# initialization function, called by nfsen. returns 1 if initialization was successful.
sub Init {
	syslog("info", "HAP4NfSen: Init");
	# Init some vars
	$nfdump  = "$NfConf::PREFIX/nfdump";
	$PROFILEDIR = "$NfConf::PROFILEDATADIR";
	my $conf = $NfConf::PluginConf{HAP4NfSen};
	if (exists $$conf{'delete_temp_files_after'}) {
		$DELETE_FILES_AFTER = $$conf{'delete_temp_files_after'};
		syslog("info", "hap4nfsen parameter delete_temp_files_after set to $DELETE_FILES_AFTER");
	} else {
		syslog("info", "no value specified for hap4nfsen parameter delete_temp_files_after. using default value $DELETE_FILES_AFTER");
	}
	if (exists $$conf{'work_dir'}) {   
                $WORK_DIR = $$conf{'work_dir'};
                syslog("info", "hap4nfsen parameter work_dir set to $WORK_DIR");
        } else {
                syslog("info", "no value specified for hap4nfsen parameter work_dir. using default value $WORK_DIR");
        }
	if (exists $$conf{'image_dir'}) {   
                $IMAGE_DIR = $$conf{'image_dir'};
                syslog("info", "hap4nfsen parameter image_dir set to $IMAGE_DIR");
        } else {
                syslog("info", "no value specified for hap4nfsen parameter image_dir. using default value $IMAGE_DIR");
        }
	createWorkDir();
	return 1;
}

# automatically called by nfsen during shutdown process.
sub Cleanup {
	syslog("info", "HAP4NfSen Cleanup");
	cleanWorkdir("full");
}

# cleans working directories. removes generated and temporary files.
# if an argument is passed, all temporary files will be deleted. without argument, only files older than $DELETE_FILES_AFTER will be removed.
sub cleanWorkdir {
	createWorkDir();
	if (exists $_[0]) {
        	system("rm $WORK_DIR*.$OUTPUT_FORMAT");
        	system("rm $WORK_DIR*.$NETFLOW_FILE_EXTENSION");
        	system("rm $WORK_DIR*.$DOT_FILE_EXTENSION");
        	system("rm $WORK_DIR*.$HAP_TEMP_FILE_EXTENSION");
		system("rm $WORK_DIR*.$FILTER_FORMAT");
		system("rm $IMAGE_DIR*.$OUTPUT_FORMAT");
	} else {
		chdir $WORK_DIR;
		my $file;
		foreach $file ( glob("*$NETFLOW_FILE_EXTENSION *$DOT_FILE_EXTENSION *$HAP_TEMP_FILE_EXTENSION *$OUTPUT_FORMAT *$FILTER_FORMAT") ) {
			if ( ( time - stat($file)->mtime ) > ( $DELETE_FILES_AFTER ) ) {
				syslog("info", "deleting $file");
				unlink($file);
			}
		}
		chdir $IMAGE_DIR;
                foreach $file ( glob("*$OUTPUT_FORMAT") ) {
                        if ( ( time - stat($file)->mtime ) > ( $DELETE_FILES_AFTER ) ) {
                                syslog("info", "deleting $file");
                                unlink($file);
                        }
                }
	}
}

# assembeles all arguments(source files, filters, ..) required to call nfdump. -w argument not included
sub assembleNfDumpArguments {
	my $type = $_[0];
        my $profile = $_[1];
        my $srcselector = $_[2];
        my $args = $_[3];
	my $filters = $_[4];
	my $and_filter = $_[5];
	my $hap_filter = $_[6];
	my $node_id_filter = $_[7];
	my $keep_existing_parameters = $_[8];

	$args =~ s/-T//g; # removes the -T parameter(special parameter, only used by NfSen to simplify formatting)
	if (!$keep_existing_parameters) {
		# remove a few parameters not needed for our data
        	$args =~ s/-s.*//g; # removes the sort and all following parameters(including stat type) 
        	$args =~ s/-n\ [0-9]+//g; # removes the -n ..(top n) parameter
	}
	createWorkDir();

	# add hap filters to the existing nfdump filters
	if ($hap_filter) {
		if ($filters) {
			$filters = $hap_filter . " and ( $filters )";
		} else {
			$filters = $hap_filter;
		}
	}
	# add node id filters
	if ($node_id_filter) {
		$filters .= " and ($node_id_filter) ";
	}

	my $opts = {};
	$opts->{"type"} = $type;
	$opts->{"profile"} = $profile;
	$opts->{"srcselector"} = $srcselector;
	$opts->{"args"} = $args;
	$opts->{"filter"} = $filters;

	my @FilterChain = ();
	my $dirlist;
	my $ret = NfProfile::CompileFileArg($opts, \$dirlist, \@FilterChain);
	if ( $ret ne "ok" ) {
		syslog("info", "ERR $ret");
		return;
	}
	$args = "$dirlist $args";

	my $filter = 'any';
    	my @_tmp;
    	foreach my $line ( $filters ) {
        	next if $line =~ /^\s*#/;
	
        	if ( $line =~ /(.+)#/ ) {
            	push @_tmp, $1;
        	} else {
            	push @_tmp, $line;
        	}
	
    	}
    	$filter = join "\n", @_tmp;
    if ( $filter =~ /[^\s!-~\n]+/ || $filter =~ /['"`;\\]/ ) {
		syslog("info", "ERR Illegal characters in filter");
		return;
    }

	if ($and_filter) {
		my $name = $and_filter;
		if ( $name =~ /[^A-Za-z0-9\-+_]+/ ) {
			syslog("info", "ERR Illegal characters in filter name '$name': '$&'!");
			return;
		}

		if ( !-f "$NfConf::FILTERDIR/$name" ) {
			syslog("info", "ERR filter '$name' No such filter!");
			return;
		}

		my @_tmp;
		if ( open FILTER, "$NfConf::FILTERDIR/$name" ) {
			@_tmp = <FILTER>;
			close FILTER;
		} else {
			syslog("info", "ERR filter '$name': $!!");
			return;
		}
		if ( $filter eq 'any' ) {
			$filter = "(" . join("", @_tmp) . ")";
		} else {
			$filter = " ($filter) and (" . join("", @_tmp) . ")";
		}
	}

	if ( scalar @FilterChain > 0 ) {
		if ( $filter eq 'any' ) {
			$filter = "(" . join("\n", @FilterChain) . ")";
		} else {
			$filter = "(" . join("\n", @FilterChain) . ") and ( $filter )";
		}
	}

	my $file;
	my $file_name = "$WORK_DIR".getUuid.".$FILTER_FORMAT";
        open($file, ">>$file_name");
        print $file $filter;
	print $file "\n";
        close($file);

	return "$args -f $file_name ".((!$keep_existing_parameters)?" -b ":"");
}

1;
