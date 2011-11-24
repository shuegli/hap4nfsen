<?php

include ("conf.php");
include ("nfsenutil.php");
session_start();
unset($_SESSION['nfsend']);

function OpenLogFile () {
	global $log_handle;
	global $DEBUG;

	if ( $DEBUG ) {
		$log_handle = fopen("/var/tmp/nfsen-log", "a");
		$_d = date("Y-m-d-H:i:s");
		ReportLog("\n=========================\nDetails Graph run at $_d\n");
	} else 
		$log_handle = null;

} // End of OpenLogFile

function CloseLogFile () {
	global $log_handle;

	if ( $log_handle )
		fclose($log_handle);

} // End of CloseLogFile

function ReportLog($message) {
	global $log_handle;

	if ( $log_handle )
		fwrite($log_handle, "$message\n");
} // End of ReportLog

OpenLogFile();

$arglist = split(' ', urldecode($_GET['arg']));
$opts = array();
$opts['.silent'] = 1;
$opts['profile'] = array_shift($arglist);
foreach ( $arglist as $arg ) {
	$opts['detailargs'][] = $arg;
}

header("Content-type: image/gif");
nfsend_query("@get-detailsgraph", $opts, 1);
nfsend_disconnect();
unset($_SESSION['nfsend']);
CloseLogFile();

?>
