<?php
/*
 * checks, if a HAP4NfSen ip chooser can be produced for the specified input parameters
 */
function graphAvailable() {
//print var_dump($_SESSION);
	if (!isset($_SESSION['process_form'])) {return false;}
	$form = &$_SESSION['process_form'];

	if ($form['modeselect']==0) { // flow list mode
		if ($form['aggr_proto'] ||
        	$form['aggr_srcport'] ||
        	$form['aggr_dstport'] ||
        	$form['aggr_srcip'] ||
        	$form['aggr_dstip']) {
                	return false;
        	}
		return true;
	} else { // mode must be 1(top n statistics)
		if (!($form['aggr_srcport'] &&
                $form['aggr_dstport'] &&
                $form['aggr_srcip'] &&
                $form['aggr_dstip'])) {
                        return false;
                }
		if ($form['stattype']==0) { // flow-statistics selected
			return true;
		}
	}
	return false; // default: no graph
}
/*
 * stores the required parameters in another part of the session to allow the ip chooser to access the data
 */
function storeParameters() {
	global $TopNOption, $ListNOption;
	$ip_chooser = &$_SESSION["plugin"][getHAP4NfSenId()]["ip_chooser"]['graph_params'];
	$ip_chooser['profile_type'] = ($_SESSION['profileinfo']['type'] & 4) > 0 ? 'shadow' : 'real';
	$ip_chooser['srcselector'] = implode(':', $_SESSION['process_form']['srcselector']);
	$ip_chooser['args'] = '-T '.$_SESSION['run'];
	$ip_chooser['filter'] = ($_SESSION['process_form']['filter'])?implode(' ', $_SESSION['process_form']['filter']):'any';
	$ip_chooser['profile'] = $_SESSION['profileswitch'];
	if ($_SESSION['process_form']['modeselect']==0) { // flow list mode
		$topN_id = $_SESSION['process_form']['listN'];
		$ip_chooser['row_count'] = $ListNOption[$topN_id];
		$ip_chooser['graph_type'] = 'flow';
	} else { // mode must be 1(top n statistics)
		$topN_id = $_SESSION['process_form']['topN'];
		$ip_chooser['row_count'] = $TopNOption[$topN_id];
		$ip_chooser['graph_type'] = 'stat';
	}
	if ($_SESSION['process_form']['DefaultFilter'] != -1) {
		$ip_chooser['and_filter'] = $_SESSION['process_form']['DefaultFilter'];
	} else {
		unset($ip_chooser['and_filter']);
	}
	$ip_chooser['comm_socket'] = &$GLOBALS['COMMSOCKET'];
}
/*
 * generates the "graph" button
 */
function ipChooserButton() {
	global $COMMSOCKET;
	if (graphAvailable()) {
		storeParameters();
		print '<input type="button" name="graph" value="graph" onClick="window.open(\'plugins/HAP4NfSen/ip_chooser.php?plugin_id='.getHAP4NfSenId().'\',\'nfsen_details_graph\',\'width=800,height=600,scrollbars=1,location=no\');" size="1">';
	}
}
?>
