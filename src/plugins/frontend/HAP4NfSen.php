<?php

/*
 * Frontend plugin: HAP4NfSen
 *
 */

$plugin_name = "HAP4NfSen";

$filters = array("ip", "port", "nodeid", "desum");
$hap_plugin_id;

$max_history = 16;
$js_disable_limit = 128;
$graphlet_display_limit = 1024;
$plugin_initialized = false; // used to make sure the configuration is only read once.

/*
 * parses and checks the input
 */
function HAP4NfSen_ParseInput( $plugin_id ) {
	global $hap_plugin_id, $filters, $required_session_parameters;
	initPlugin();
	$hap_plugin_id = $plugin_id;
	setSessionContext();
	$hap4nfsen_session = &$_SESSION["plugin"][$plugin_id]["context"];
	$hap4nfsen_session["parameters_ok"] = true;
	$parameters_ok = &$hap4nfsen_session["parameters_ok"];

	if (!isset($_GET["bookmark"])) { // bookmark parameter is only present in case of a page reload
		foreach ($filters as $filter_key) {
			if (!isset($_GET[$filter_key])) {
				continue;
			}
			$filter = $_GET[$filter_key];
			if ($filter != "") { // copy get parameters to session
        			$hap4nfsen_session[$filter_key] = $filter;
			}
		}
	}
	updateHapRoles(&$hap4nfsen_session["hap_summarizations"]);
	updateDesummarizedRoles();
	$parameters_ok = !(!isset($hap4nfsen_session["cmd_opts"]) || (!isset($hap4nfsen_session["ip"]) && !isset($hap4nfsen_session["nodeid"])));
}

function array_trim(&$array, $index) {
	if (is_array($array)) {
		unset($array[$index]);
		array_unshift ($array, array_shift($array));
	}
}

/*
 * creates and/or sets the context. also handles undo functionality.
 */
function setSessionContext() {
	global $hap_plugin_id, $max_history;
	$session = &$_SESSION["plugin"][$hap_plugin_id];

	if (isset($_GET["mode"])&&$_GET["mode"]=="new") {
		unset($session["context"]);
		unset($session["history"]);
	}

	// create history array, if needed
	if (!isset($session["history"])) {
		$session["history"] = array();
	}
	$history = &$session["history"];

	// set the context
	if (isset($_GET["bookmark"])) {
		// nothing changed, just an automatic page reload => keep previous context
		$idx = count($history) - 1;
		if ($idx < 0) {
			SetMessage('error', "Unknown history id.");
		}
		$session["context"] = &$history[$idx];
	} else if (isset($_GET["history"])) {
		$id = $_GET["history"];
		$history_size = count($history)-1; // current size of the history
		$history_index = -1; // position of the requested step in the history array
		for ($idx=0; $idx<=$history_size;$idx++) {
			if ($history[$idx]["id"]==$id) {
				$history_index = $idx;
				break;
			}
		}
		if ($history_index>=0) {
			$session["context"] = &$history[$history_index];
			while (count($history)>($history_index+1)) {
				array_pop($history);
			}
		} else {
			SetMessage('error', "History id does not exist.");
		}
	} else {
		$context;
		if (count($history)==0) { // create the first context
			$context = array();
			$context["cmd_opts"] = $session["cmd_opts"];
			if (!isset($context["cmd_opts"]["and_filter"])) {$context["cmd_opts"]["and_filter"]="";}
			$context["hap_summarizations"] = array("client_roles" => true, "multi_client_roles" => true, "server_roles" => true, "p2p_roles" => true);
			$context["desum_role_numbers"] = array();
		} else { // use last context as prototype for the new one
			$context = $history[count($history)-1];
			unset($context["node_id_filters"]);
			unset($context["node_id_summarizations"]);
			unset($context["disable_svg_js"]);
		}
		$context["id"] = uniqid("", true);
		array_push($history, &$context);
		$session["context"] = &$context;
	}
	$session["context"]["exec_time"] = microtime(true);
	if (isset($_GET["ip"])) { // reset nodeid info
		unset($session["context"]["nodeid"]);
		$session["context"]["hap_summarizations"] = array("client_roles" => true, "multi_client_roles" => true, "server_roles" => true, "p2p_roles" => true);
	}
	if (isset($_GET["forceJS"])) {
		$session["context"]["force_svg_js"] = ($_GET["forceJS"]=="true");
	}
	if (isset($_GET["forceGraphlet"])) {
		$session["context"]["force_graphlet_display"] = ($_GET["forceGraphlet"]=="true");
	}

	// age stack data
	if ((count($history)-1)>=$max_history) {
		array_trim($history, 0);
	}
}

/*
 * main function that creates the page
 */
function HAP4NfSen_Run( $plugin_id ) {
	@ini_set('display_errors', 'on');
	$time_start = microtime(true);
	$hap4nfsen_session = &$_SESSION["plugin"][$plugin_id]["context"];
	$parameters_ok = &$hap4nfsen_session["parameters_ok"];
	$print_desummarization_warning_message = (isset($hap4nfsen_session["desum_role_numbers"])&&count($hap4nfsen_session["desum_role_numbers"])>0);
	printUndoBar();
	if ($print_desummarization_warning_message) {
		printActiveSummarizationsWarning();
	};
	if ($parameters_ok) {
		$netflow_file = generateNetflowFile($hap4nfsen_session["cmd_opts"], assembleHAPFilters($hap4nfsen_session));
		if ($netflow_file=="") {SetMessage('warning', "Back end call returned no netflow file.");}
		$dot_file = generateDotFile($netflow_file, $hap4nfsen_session["ip"], $hap4nfsen_session["hap_summarizations"], implode(',', $hap4nfsen_session['desum_role_numbers']));
		if ($netflow_file=="") {SetMessage('warning', "Back end call returned no graph definition");}
		$height_attribute = (isSvgJsEnabled()||isForceSvgJs())?"height=\"80%\"":"";
		$width_attribute = (isSvgJsEnabled()||isForceSvgJs())?"width=\"95%\"":"width=\"50%\"";
		print "<embed type=\"image/svg+xml\" src=\"" . generateGraphlet($dot_file) . "\" $width_attribute $height_attribute/>";
	} else {
		SetMessage('warning', "missing required parameters");
	}
	print "<br/>";
	printControlArea();
	printHelpArea();
	printFilters();
	printFunctionLinks();
	$time = microtime(true) - $time_start;
	print "<br/><small>generated on " . date("d/m/Y H:i:s") . " in " . round($time, 3) . " seconds</small>";
	//print "<pre>".var_dump($_SESSION["plugin"][1]["context"]["node_id_filters"])."</pre>";
	//print '</br></br>'.var_dump($hap4nfsen_session["desum_role_numbers"]);
}

/*
 * prints a box containing a warning message
 */
function printActiveSummarizationsWarning() {
	print "<div style=\"width:65%;border:1px solid gray;padding:5px;background:rgb(216, 233, 232);\">";
	print '<embed width="20px" style="vertical-align:middle;border:1px solid gray;" title="warning icon" src="plugins/HAP4NfSen/warning_exclamation_mark.svg" type="image/svg+xml"></embed>';
	print "<font size=\"-1\" style=\"font-family:Verdana,sans-serif;\"> One or more roles have been desummarised. Further drilldowns will remove currently active desummarisations.</font>";
	print "</div>";
}

/*
 * prints an area that contais controls that enable the user to modify the plugin's behaviour
 */
function printControlArea() {
	global $hap_plugin_id;
        $hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id]["context"];
	$hidden = (!isSvgJsEnabled() || isGraphletTooLarge() || isForceSvgJs() || isForceDisplayGraphlet())?"":"display:none;";
	print "<div id=\"graphlet_control_area\" style=\"".$hidden."width:95%;border:1px solid gray;padding:8px;background:rgb(216, 233, 232);\">";
	print "<table width=\"100%\">";
	print "<h5>Graphlet Control</h5>";
	print "<tr>";
	print "<th width=\"50%\" align=\"left\"><small>Zoom and Pan</small></th>";
	print "<th width=\"50%\" align=\"left\"><small>Graphlet</small></th>";
	print "</tr>";
	print "<tr valign=\"top\">";
	print "<td><small>Zoom and Pan functionality is by default disabled for larger Graphlets to avoid browser performance problems.<br/>This behaviour can be overwritten by forcing the plugin to enable JavaScript enhancements.</small></td>";
	print "<td><small>To protect the HAP4NfSen Plugin from requests that would run for a long time, oversized Graphlets are not displayed.<br/>In order to display large graphlets, this default behaviour can be overwritten.</small></td>";
	print "</tr>";
	print "<tr>";
	$isForceJS = isForceSvgJs();
	$isForceGraphlet = isForceDisplayGraphlet();
	$id = $hap4nfsen_session["id"];
	$JSButtonCommand = "window.location='nfsen.php?history=$id&forceJS=".(($isForceJS)?"false":"true")."';";
	$graphletButtonCommand = "window.location='nfsen.php?history=$id&forceGraphlet=".(($isForceGraphlet)?"false":"true")."';";
	print "<td><input type=\"button\" value=\"".(($isForceJS)?"Use dynamic Zoom and Pan activation":"Always activate Zoom & Pan")."\" onclick=\"$JSButtonCommand\"/></td>";
	print "<td><input type=\"button\" value=\"".(($isForceGraphlet)?"Do not display oversized Graphlets":"Always show Graphlet")."\" onclick=\"$graphletButtonCommand\"/></td>";
	print "</tr>";
	print "</table>";
	print "</div>";
}

/*
 * helper function to determine if javascript svg extent
 */
function isSvgJsEnabled() {
	return !isSetInContext("disable_svg_js", true);
}

/*
 *
 */
function isGraphletTooLarge() {
	return isSetInContext("graphlet_too_large", false);
}

/*
 *
 */
function isForceSvgJs() {
	return isSetInContext("force_svg_js", false);
}

/*
 *
 */
function isForceDisplayGraphlet() {
	return isSetInContext("force_graphlet_display", false);
}

/*
 * helper function used to check if an attribute in the context is set to true
 */
function isSetInContext($attribute, $default_value) {
	global $hap_plugin_id;
        $hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id]["context"];
	if (!isset($hap4nfsen_session[$attribute])) {
		return $default_value;
	}
        return $hap4nfsen_session[$attribute];
}

/*
 * prints links providing additional functionality
 */
function printFunctionLinks() {
	$show_control_button = !(!isSvgJsEnabled() || isGraphletTooLarge() || isForceSvgJs() || isForceDisplayGraphlet());
	print "<div style=\"width:95%;\">";
	print "<table align=\"right\">";
        print "<tr>";
        print "<td><input type=\"button\" value=\"Show Usage\" onClick=\"document.getElementById('help_area').style.display='';this.style.display='none';\"/></td>";
	print (($show_control_button)?"<td><input type=\"button\" value=\"Show Graphlet Controls\" onClick=\"document.getElementById('graphlet_control_area').style.display='';this.style.display='none';\"/></td>":"");
        print "<td><input type=\"button\" value=\"Display Filters\" onClick=\"document.getElementById('filter_area').style.display='';this.style.display='none';\"/></td>";
        print "</tr>";
        print "</table>";
	print "</div>";
}

/*
 * prints the current filters(ndfump, hap specific & hap summarizations)
 */
function printFilters() {
	global $hap_plugin_id;
	$hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id]["context"];
	print "<div id=\"filter_area\" style=\"display:none;width:95%;border:1px solid gray;padding:8px;background:rgb(216, 233, 232);\">";
	print "<table width=\"100%\">";
	print "<tr>";
	print "</tr>";
	print "<th colspan=\"4\">Active Filters</th>";
	print "<tr>";
	print "<td width=\"25%\"><small>Initial Filters</small></td>";
	print "<td width=\"25%\"><small>Additional Filters</small></td>";
	print "<td width=\"25%\"><small>Active HAP Role Summarisations</small></td>";
	print "<td width=\"25%\"><small>Desummarised Roles</small></td>";
	print "</tr>";
        print "<tr>";
	$and_filter = $hap4nfsen_session["cmd_opts"]["and_filter"];
	$initial_filters = preg_replace("/\s+/"," ",trim(array_reduce(isset($hap4nfsen_session["cmd_opts"]["filter"])?$hap4nfsen_session["cmd_opts"]["filter"]:array(), "reduceFilters")))
		. (($and_filter)?"\nand {{$and_filter}}":"");
	$has_nodeid_filter = (isset($hap4nfsen_session["nodeid"])&&$hap4nfsen_session["nodeid"]);
	$additional_filters = preg_replace("/\s+/"," ",trim(assembleHAPFilters($hap4nfsen_session)));
	$hap_summarizations = "";
	foreach( $hap4nfsen_session["hap_summarizations"] as $key => $value ) {
                $hap_summarizations = "$hap_summarizations$key: " . (($value)?"on":"off") . "\n";
        }
        print "<td><textarea readonly=\"true\" style=\"width:100%;\" rows=\"5\">$initial_filters</textarea></td>";
        print "<td><textarea readonly=\"true\" style=\"width:100%;\" rows=\"5\">$additional_filters";
	if ($has_nodeid_filter) {print " and "; foreach (createNodeIdFilter($hap4nfsen_session["nodeid"]) as $partial_filter) {print $partial_filter;}}
	print "</textarea></td>";
	print "<td><textarea readonly=\"true\" style=\"width:100%;\" rows=\"5\">$hap_summarizations</textarea></td>";
	print "<td><textarea readonly=\"true\" style=\"width:100%;\" rows=\"5\">".join(',', array_unique($hap4nfsen_session["desum_role_numbers"]))."</textarea></td>";
        print "</tr>";
	print "</table>";
	print "</div>";
}

/*
 * prints a hidden area with instructions
 */
function printHelpArea() {
	global $max_history;
	print "<div id=\"help_area\" style=\"display:none;width:95%;border:1px solid gray;padding:8px;background:rgb(216, 233, 232);\">";
	print "<h3>Help</h3>";
	print "<h4>Graphlet</h4>";
	print "<small><i>Basic interaction with the HAP graphlet</i></small>";
	print "<h5>Node and Edge Labels</h5>";
	print "The following image describes the meaning of node and edge labels:";
	print "<embed type=\"image/svg+xml\" src=\"plugins/HAP4NfSen/labels.svg\" width=\"100%\" title=\"graphlet nodes and edges\"/>";
	print "<h5>Zoom and Pan</h5>";
	print "<table>";
	print "<tr><td><b>Zoom:</b></td><td>The mouse wheel allows the user to adjust the zoom level of the graphlet.</td></tr>";
	print "<tr><td><b>Pan:</b></td><td>Dragging the HAP graphlet with the mouse enables the user to move it.</td></tr>";
	print "</table>";
	print "<h5>Drill Down</h5>";
	print "Clicking on one of the graphlets' nodes allows the user to drill down. If the node is summarised(a square instead of an oval), the next graphlet will display the content of the node in an unsummarized form.";
	print "<h5>Single Summary Node Desummarisation</h5>";
	print "Right-clicking on a summary node(a square) allows to desummarise the specified node without altering the rest of the graph. Once a single node is desummarized, any further normal drill downs will result in a loss of the currently active  summary node desummarisations.";
	print "<h5>Highlighting</h5>";
	print "Lines that connect nodes with each other can be highlighted with a mouse click. This will cause the line to change its colour. When a new line is highlighted, the previously highlighted line gets its original colour back.";
	print "<h4>Undo previous Actions</h4>";
	print "The HAP viewer automatically stores the last $max_history actions of a user. To go back to a previous step, the links in the history bar above the graphlet can be used.";
	print "<h4>Active Filters</h4>";
	print "To see the filters that were used to generate the graphlet, click on the \"Display Filters\" button. This will open a new area with three sections:";
	print "<table>";
	print "<tr><td><b>Initial Filters:</b></td><td>This section contains all filters that were active on the NfSen details page when the user clicked on one of the HAP links. These filters are not affected by interaction with the graphlet.<br/>If there is an NfSen \"and\" filter active, the name of the filter will be displayed in curly brackets.</td></tr>";
	print "<tr><td><b>Additional Filters:</b></td><td>This group contains additional filters that were added when the user clicked on one of the HAP links on the NfSen details page or used the graphlets' drill down functionality. Most interactions with the graphlet will affect these filters.</td></tr>";
	print "<tr><td><b>Active HAP Role Summarizations:</b></td><td>This area shows active HAP role summarisations.</td></tr>";
	print "<tr><td><b>Desummarised Roles:</b></td><td>Lists the ids of all currently desummarised roles.</td></tr>";
	print "</table>";
	print "</div>";
}

/*
 * prints a bar contining undo links.
 */
function printUndoBar() {
	global $max_history, $hap_plugin_id;
        $session = &$_SESSION["plugin"][$hap_plugin_id];
        $history = &$session["history"];
        $hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id]["context"];

	$num_undo = count($history)-1;
	$step_width = 100/$max_history;
	print "<table width=\"95%\" style=\"background-image: url('icons/shade.png');\">";
	print "<tr>";
	print "<td colspan=\"$max_history\" class=\"navigator\">";
	print "History";
	print "</td>";
	print "</tr>";
	print "<tr>";
	for ($i=0; $i<$max_history; $i++) {
		$is_set = $i == $num_undo;
		$exists = $i <= $num_undo;
		$bg = "";
		$css_class = "";
		$style = "";
		if ($exists) {
			$bg = "background=\"".($is_set?"icons/shadeactive.png":"icons/shade.png")."\"";
			$css_class = "class=\"".($is_set?"selected":"navigator")."\"";
			$style = "style=\"border:1px solid #777788;font-family:Verdana,sans-serif;\"";
		}
		print "<td $css_class $style $bg width=\"$step_width%\">";
		if ($exists) {
			$element = $history[$i];
			$history_param = "?history=".$element["id"];
			print "<a href=\"#\" onClick=\"window.location='nfsen.php$history_param';\" title=\""."generated: ".date("d/m/Y H:i:s",$element["exec_time"])."\">Step ".($i+1)."</a>";
		}
		print "</td>";
	}
	print "</tr>";
	print "</table>";
}

/*
 * simple helper function used to reduce an array to a space separated string
 */
function reduceFilters($v1,$v2) {
        return $v1 . " " . $v2;
}

/*
 * assembles additional nfdump filters required to generate the temporary netflow file read by the hap lib
 */
function assembleHAPFilters($hap4nfsen_session) {
	// filter definition: (get)parameter name => function name
	$filter_definition = array(
		"ip"		=>	"createIpFilter",
		"port"		=>	"createPortFilter"
	);
	$filter = "";

	foreach( $filter_definition as $key => $value ) {
		if (isset($hap4nfsen_session[$key])) {
			$filter = " $filter ".(($filter=="")?"":" and ");
			$filter .= call_user_func($value, $hap4nfsen_session[$key]);
		}
	}
	return $filter;
}

function createNodeIdFilter($value) {
        global $hap_plugin_id;
        $hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id];
	$context_count =  count($hap4nfsen_session["history"]);
	if ($context_count < 2) {
		SetMessage('error', "no node filters found");
		return array("(not any)");
	}
	if (!isset($hap4nfsen_session["history"][$context_count-2]["node_id_filters"])) {
		SetMessage('error', "no node filters found");
                return array("(not any)");
	}
	$filters = &$hap4nfsen_session["history"][$context_count-2]["node_id_filters"];
	if (!isset($filters[$value])) {
		SetMessage('error', "no filter for node id $value available");
                return array("(not any)");
	}
        return $filters[$value];
}

function createIpFilter($value) {
	return createNfDumpFilter("ip", $value);
}

function createPortFilter($value) {
        return createNfDumpFilter("port", $value);
}

/*
 * default implementation
 */
function createNfDumpFilter($filter_name, $value) {
	return " $filter_name $value ";
}

/*
 * assembles netflow data and applies specified filters using NfDump. output is written to a temporary file
 */
function generateNetflowFile( $cmd_opts, $hap_filter ) {
	global $hap_plugin_id;
        $hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id]["context"];
        $command = 'HAP4NfSen::assembleNetflowData';
	$node_id_filters = array();
        if (isset($hap4nfsen_session["nodeid"])&&$hap4nfsen_session["nodeid"]) {
                $node_id_filters = createNodeIdFilter($hap4nfsen_session["nodeid"]);
        }
        $opts = array();

        $opts['hap4nfsen_type'] = $cmd_opts["type"];
        $opts['hap4nfsen_profile'] = $cmd_opts["profile"];
	$opts['hap4nfsen_srcselector'] = $cmd_opts["srcselector"];
	$opts['hap4nfsen_args'] = $cmd_opts["args"];
	$opts['hap4nfsen_filter'] = array_reduce($cmd_opts["filter"], "reduceFilters");
	$opts['hap4nfsen_and_filter'] = $cmd_opts["and_filter"];
	$opts['hap4nfsen_hapfilter'] = $hap_filter;
	for ($i=0;$i<count($node_id_filters);$i++) {
		$opts['hap4nfsen_node_id_filters_'.$i] = $node_id_filters[$i];
	}

	$out_list = nfsend_query($command, $opts);
	if ( !is_array($out_list) ) {
                SetMessage('error', "Could not generate Netflow File.");
                return "";
        }
	#SetMessage('info', "command: $command, args: ".print_r($opts));
        return $out_list['hap4nfsen_netflow_file'];
}

/*
 * generates a dot file from from netflowdata using haplib
 */
function generateDotFile( $netflow_file, $ip, $summarizations, $desum_roles ) {
	global $hap_plugin_id, $js_disable_limit, $graphlet_display_limit;
        $hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id]["context"];
        $command = 'HAP4NfSen::generateDotFile';

	$opts = array();
        $opts['hap4nfsen_netflow_file'] = $netflow_file;
        $opts['hap4nfsen_ip'] = $ip;
	$opts['hap4nfsen_summarization_client_roles'] = $summarizations["client_roles"];
	$opts['hap4nfsen_summarization_multi_client_roles'] = $summarizations["multi_client_roles"];
	$opts['hap4nfsen_summarization_server_roles'] = $summarizations["server_roles"];
	$opts['hap4nfsen_summarization_p2p_roles'] = $summarizations["p2p_roles"];
	$opts['hap4nfsen_plugin_id'] = $hap_plugin_id;
	$opts['hap4nfsen_desummarized_role_list'] = $desum_roles;

        $out_list = nfsend_query($command, $opts);
        if ( !is_array($out_list) ) {
                SetMessage('error', "Could not generate .dot File.");
                return "";
        }
	$dot_file_name = $out_list['hap4nfsen_dot'];
	$hap4nfsen_session["dot_file_name"] = $dot_file_name;
	$hap4nfsen_session["disable_svg_js"] = (!isset($out_list['hap4nfsen_node_count']) || $out_list['hap4nfsen_node_count'] > $js_disable_limit);
	$hap4nfsen_session["graphlet_too_large"] = (!isset($out_list['hap4nfsen_node_count']) || $out_list['hap4nfsen_node_count'] > $graphlet_display_limit);
	if (!is_array($out_list['hap4nfsen_node_id_filters'])) {
		SetMessage('error', "Did not receive node id filters.");
	} else { // parse nodeid filters and store them in the session
		$in_filters = $out_list['hap4nfsen_node_id_filters'];
		$filters = array();
		foreach ($in_filters as $row) {
			$parts = explode("=", $row);
			if (!isset($filters[$parts[0]])) {
				$filters[$parts[0]] = array();
			}
			array_push($filters[$parts[0]], $parts[1]);
		}
		$hap4nfsen_session["node_id_filters"] = $filters;
	}
	if (!isset($out_list['hap4nfsen_node_id_summarization']) || !is_array($out_list['hap4nfsen_node_id_summarization'])) {
                SetMessage('error', "Did not receive node id summarization data.");
        } else { // parse nodeid summarization information and store them in the session
                $in_filters = $out_list['hap4nfsen_node_id_summarization'];
                $filters = array();
                foreach ($in_filters as $row) {
                        $parts = explode("=", $row);
                        if (!isset($filters[$parts[0]])) {
                                $filters[$parts[0]] = array();
                        }
                        array_push($filters[$parts[0]], $parts[1]);
                }
                $hap4nfsen_session["node_id_summarizations"] = $filters;
        }
        return $dot_file_name;
}

/*
 * generates a HAP graphlet using graphviz
 */
function generateGraphlet( $dot_file ) {
	global $hap_plugin_id;
        $hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id]["context"];
        $command = 'HAP4NfSen::generateGraphlet';
	if (isGraphletTooLarge() && !isForceDisplayGraphlet()) {
		return "plugins/HAP4NfSen/graphlet_too_large.svg";
	}
        $opts = array();
        $opts['hap4nfsen_dot_file'] = $dot_file;
	$opts['hap4nfsen_disable_svg_js'] = (isSvgJsEnabled()||isForceSvgJs())?0:1;
        $out_list = nfsend_query($command, $opts);

        if ( !is_array($out_list) ) {
                SetMessage('error', "Could not generate Graphlet.");
                return "plugins/HAP4NfSen/error.svg";
        }
        return "pic.php?picture=" .$out_list['hap4nfsen_graphlet'];
}

/*
 * initializes plugin variables with data from nfsen configuration file
 */
function initPlugin() {
	global $max_history, $js_disable_limit, $graphlet_display_limit, $plugin_initialized;
	if ($plugin_initialized) {
		return; // no need to read configuration again
	}
        $command = 'HAP4NfSen::getConfig';
        $opts = array();
        $out_list = nfsend_query($command, $opts);

        if ( is_array($out_list) && isset($out_list['hap4nfsen_max_history']) &&
		isset($out_list['hap4nfsen_graph_zoom_limit']) &&
		isset($out_list['hap4nfsen_graph_display_limit'])) {
                $max_history = $out_list['hap4nfsen_max_history'];
		$graphlet_display_limit = $out_list['hap4nfsen_graph_display_limit'];
		$js_disable_limit = $out_list['hap4nfsen_graph_zoom_limit'];
		$plugin_initialized = true;
        }
}

/*
 * updates roles in session(context) with new parameter information from get request
 */
function updateHapRoles(&$roles) {
	global $hap_plugin_id;
	$hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id];
        $hap4nfsen_session_context = &$_SESSION["plugin"][$hap_plugin_id]["context"];
	if (!isset($hap4nfsen_session_context["nodeid"])) {
		return;
	}
	$nodeid = $hap4nfsen_session_context["nodeid"];
    	$context_count =  count($hap4nfsen_session["history"]);
       	if ($context_count < 2 || !isset($hap4nfsen_session["history"][$context_count-2]["node_id_summarizations"])) {
               	return;
        }
	$summarization_updates = &$hap4nfsen_session["history"][$context_count-2]["node_id_summarizations"];
	if (!isset($summarization_updates["$nodeid"])) {
		return; // no changes
	}
        $active_roles_definition = array(
               	"c"		=>	"client_roles",
               	"m"		=>	"multi_client_roles",
               	"s"		=>	"server_roles",
               	"p"		=>	"p2p_roles"
        );

	foreach( $summarization_updates["$nodeid"] as $update ) {
                if (!$active_roles_definition[$update]) {
			continue;
		}
		$role = $active_roles_definition[$update];
		$roles[$role] = false;
        }
}

/*
 * updates list containing the numbers of desummarized roles
 */
function updateDesummarizedRoles() {
	global $hap_plugin_id;
	$hap4nfsen_session = &$_SESSION["plugin"][$hap_plugin_id];
        $hap4nfsen_session_context = &$_SESSION["plugin"][$hap_plugin_id]["context"];
	$context_count =  count($hap4nfsen_session["history"]);
	if (isset($hap4nfsen_session_context["nodeid"]) &&// HAP flow list changes => role numbers are no longer valid
		($context_count >= 2 && $hap4nfsen_session["history"][$context_count-2]["nodeid"] != $hap4nfsen_session["history"][$context_count-1]["nodeid"])) {
		$hap4nfsen_session_context["desum_role_numbers"] = array(); // delete role number list
		return;
	}
        if (!isset($hap4nfsen_session_context["desum"])) {
                return; // no update needed
        }
	$role_numbers = &$hap4nfsen_session_context["desum_role_numbers"];
	array_push($role_numbers, $hap4nfsen_session_context["desum"]);
	$role_numbers = array_unique($role_numbers); // remove duplicate values(can happen through page reloads. duplicates would not affect the graphlet, but waste memory)
}

?>
