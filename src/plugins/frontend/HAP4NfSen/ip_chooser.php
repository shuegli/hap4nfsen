<?php
	session_start();
?>

<html>
	<head>
		<title>HAP4NfSen IP Chooser</title>
	</head>
<body>
<?php
function ReportLog($msg){} // this is a dummy implementation of a function called from "nfsenutil.php". the real implementation is located in "nfsen.php" and is not needed in this context.
$messages = array();
/*
 * checks if all required parameters are set
 */
function parametersSet() {
	global $messages;
	if (!isset($_GET['plugin_id'])) {
		array_push($messages, array('error','HAP4NfSen plugin Id unknown. Has the plugin been deactivated?'));
		return false;
	}
	if (isset($_SESSION["plugin"][$_GET['plugin_id']]["ip_chooser"]['graph_params'])) {
		if (isset($_GET['ip_only_mode'])) {
			$_SESSION["plugin"][$_GET['plugin_id']]["ip_chooser"]['ip_only_mode'] = $_GET['ip_only_mode'];
		}
		return true;
	}
	array_push($messages, array('error','Information required to generate IP Chooser could not be found.'));
	return false;
}
/*
 * calls the HAP4NfSen back-end to generate the svg for the ip chooser. returns the location of the generated file
 */
function generateIpChooser() {
	global $COMMSOCKET, $messages;
	$command = 'HAP4NfSen::generateIpChooser';
	$opts = array();
	$ip_chooser = &$_SESSION["plugin"][$_GET['plugin_id']]["ip_chooser"]['graph_params'];
	$opts['hap4nfsen_type'] = $ip_chooser['profile_type'];
	$opts['hap4nfsen_srcselector'] = $ip_chooser['srcselector'];
	$opts['hap4nfsen_args'] = $ip_chooser['args'];
	$opts['hap4nfsen_filter'] = $ip_chooser['filter'];
	$opts['hap4nfsen_profile'] = $ip_chooser['profile'];
	$opts['hap4nfsen_record_count'] = $ip_chooser['row_count'];
	$opts['hap4nfsen_graph_type'] = $ip_chooser['graph_type'];
	$opts['hap4nfsen_ip_only_mode'] = ((isIpOnlyMode())?'1':'0');
	if (isset($ip_chooser['and_filter'])) {
        	$opts['hap4nfsen_and_filter'] = $ip_chooser['and_filter'];
	}
	if (!isset($COMMSOCKET)||!$COMMSOCKET) {
		$COMMSOCKET = $ip_chooser['comm_socket'];
	}
	$opts['hap4nfsen_plugin_id'] = ''.$_GET['plugin_id'];
	include "../../nfsenutil.php"; // include requires the global variable $COMMSOCKET
	nfsend_connect();
	//ShowMessages();
	$out_list = nfsend_query($command, $opts);
	nfsend_disconnect();
	if (!is_array($out_list) ) {
		array_push($messages, array('error','Could not generate HAP4NfSen IP Chooser'));
                return 'ip_chooser_no_data.svg';
        }
	return '../../pic.php?picture='.$out_list['hap4nfsen_ipchooser_pic'];
}
/*
 * prints information about the parameters used to generate the data for the graph
 */
function printGraphFilters() {
	$ip_chooser = &$_SESSION["plugin"][$_GET['plugin_id']]["ip_chooser"]['graph_params'];
	print '<div id="hap4nfsen_ip_chooser_parameters" style="display:none;width:95%;border:1px solid gray;padding: 8px; background: none repeat scroll 0% 0% rgb(216, 233, 232);" >';
	print '<h3>Graph Parameters</h3>';
	//print "<pre>".var_dump($_SESSION["plugin"][$_GET['plugin_id']]["ip_chooser"]['graph_params'])."</pre>";
	print '<style type="text/css"><!--TD{font-size:small;} .nfsen_parameter_value{font-family:monospace;}---></style>';
	print '<table>';
	print '<tr>';
	print '<th align="left">Parameter</th>';
	print '<th align="left">Value</th>';
	print '</tr>';
	print '<tr>';
        print '<td><b>Graph Type</b></td>';
        print '<td class="nfsen_parameter_value">'.$ip_chooser['graph_type'].'</td>';
        print '</tr>';
	print '<tr>';
        print '<td><b>Node Summarisation</b></td>';
        print '<td class="nfsen_parameter_value">'.((isIpOnlyMode())?'IP':'IP:port').'</td>';
        print '</tr>';
        print '<tr>';
	print '<td><b>Filters</b></td>';
	print '<td class="nfsen_parameter_value">'.$ip_chooser['filter'].'</td>';
	print '</tr>';
	print '<tr>';
        print '<td><b>Default Filter</b></td>';
        print '<td class="nfsen_parameter_value">'.(($ip_chooser['and_filter'])?$ip_chooser['and_filter']:'none').'</td>';
        print '</tr>';
	print '<tr>';
        print '<td><b>NfDump Arguments</b></td>';
        print '<td class="nfsen_parameter_value">'.$ip_chooser['args'].'</td>';
        print '</tr>';
	print '<tr>';
        print '<td><b>Profile</b></td>';
        print '<td class="nfsen_parameter_value">'.$ip_chooser['profile'].'('.$ip_chooser['profile_type'].')'.'</td>';
        print '</tr>';
	print '<tr>';
        print '<td><b>Sources</b></td>';
        print '<td class="nfsen_parameter_value">'.$ip_chooser['srcselector'].'</td>';
        print '</tr>';
	print '</table>';
	print '</div>';
}
/**
 * print the html code for the help box
 */
function printHelpBox() {
	print '<div id="hap4nfsen_ip_chooser_help" style="display:none;width:95%;border:1px solid gray;padding: 8px; background: none repeat scroll 0% 0% rgb(216, 233, 232);" >';
        print '<h3>Help</h3>';
        print '<h4>HAP4NfSen IP Chooser</h4>';
        print 'The IP Chooser provides an additional entry point for NetFlow analysis with the HAP4NfSen plugin.<br/>';
        print 'The graph visualises interaction between the hosts listed on the NfSen details page. The direction of the connecting arrows indicates the direction of communication between hosts.<br/>';
        print 'Clicking one of the graphs nodes opens a HAP graphlet with the selected IP as local IP.<br/>';
	print 'The current version of the IP Chooser supports only a few of the aggregations available on the NfSen details page.';
	print '<h4>Summarisation Modes</h4>';
	print 'The IP Chooser offers two different display modes for the selected data. The default mode aggregates hosts using their IP address and port. The alternative mode aggregates on IP only.</br>';
	print 'A button at the bottom of the screen allows to toggle between the two modes.';
	print '<h4>ICMP Control Message Types</h4>';
	print 'The HAP4NfSen plugin does not support ICMP Control Message Type handling. The IP Chooser therefore ignores this information (displayed as port on the NfSen details page) when aggregating IP addresses and ports.';
        print '</div>';
}
/**
 * prints a list ofpreviously generated error messages & warnings
 */
function printMessages() {
	global $messages;
	$msg_count = count($messages);
	if ($msg_count>0) {
		print '<div style="width:95%;border:1px solid gray;padding: 8px; background: none repeat scroll 0% 0% rgb(216, 233, 232);" >';
		print '<table width="100%">';
		print '<tr>';
		print '<td>';
		print '<embed width="20px" type="image/svg+xml" src="warning_exclamation_mark.svg" title="warning icon" style="vertical-align: middle; border: 1px solid gray;">';
		print '</td>';
		print '<td>';
		for ($i=0;$i<$msg_count;$i++) {
			print $messages[$i][1]."</br>";
		}
		print '</td>';
		print '</tr>';
		print '</div>';
	}
}
/**
 * returns true, if nfdump data is aggregated by ip only
 */
function isIpOnlyMode() {
	if (!isset($_SESSION["plugin"][$_GET['plugin_id']]["ip_chooser"]['ip_only_mode'])) {
		return false;
	}
	$value = $_SESSION["plugin"][$_GET['plugin_id']]["ip_chooser"]['ip_only_mode'];
	return $value;
}
/**
 * prints a button that allows users to toggle between ip and ip:port mode
 */
function printModeToggleButton() {
	$url = 'ip_chooser.php?plugin_id='.$_GET['plugin_id'].'&ip_only_mode='.((isIpOnlyMode())?'0':'1');
	$label = (isIpOnlyMode())?'Switch to IP:Port Mode':'Switch to IP Mode';
	print '<input type="button" value="'.$label.'" onclick="window.location=\''.$url.'\';"/>';
}
$time_start = microtime(true);
if (parametersSet()) {
	print '<embed id="hap4nfsen_ip_chooser" type="image/svg+xml" width="100%" src="'.generateIpChooser().'"/>';
	print '<script languale="JavaScript">';
        print 'var isFF = (/Firefox[\/\s](\d+\.\d+)/.test(navigator.userAgent));';
        print "document.getElementById('hap4nfsen_ip_chooser').width = '100%';";
        print "if (!isFF){document.getElementById('hap4nfsen_ip_chooser').height = '100%';}";
        print '</script>';
	printMessages();
	printGraphFilters();
	print '</br>';
	printHelpBox();
	printModeToggleButton();
	print '<input type="button" value="Display Graph Parameters" onclick="document.getElementById(\'hap4nfsen_ip_chooser_parameters\').style.display=\'\' ;this.style.display=\'none\';"/>';
	print '<input type="button" value="Show Usage" onclick="document.getElementById(\'hap4nfsen_ip_chooser_help\').style.display=\'\' ;this.style.display=\'none\';"/>';
	$time = microtime(true) - $time_start;
	print "&nbsp;<small>generated on " . date("d/m/Y H:i:s") . " in " . round($time, 3) . " seconds</small>";
} else {
	printMessages();
}
?>
</body>
</html>
