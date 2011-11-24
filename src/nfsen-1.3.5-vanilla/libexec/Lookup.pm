#!%%PERL%%
#
#  Copyright (c) 2004, SWITCH - Teleinformatikdienste fuer Lehre und Forschung
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#	 this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#	 this list of conditions and the following disclaimer in the documentation
#	 and/or other materials provided with the distribution.
#   * Neither the name of SWITCH nor the names of its contributors may be
#	 used to endorse or promote products derived from this software without
#	 specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
#  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.
#
#  $Author: haag $
#
#  $Id: Lookup.pm 67 2010-09-09 05:56:05Z haag $
#
#  $LastChangedRevision: 67 $

package Lookup;

use strict;
use warnings;
use Socket;
use IO::Socket::INET;
use Log;

sub Lookup {
	my $socket  = shift;
	my $opts	= shift;

	if ( !exists $$opts{'lookup'} ) {
		print $socket "<h3>Missing lookup parameter</h3>\n";
		return;
	}
	my $lookup = $$opts{'lookup'};

	my ($ip, $port);
	if ( $lookup =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(\d{1,5})$/ ) {
		$ip   = $1;
		$port = $2;
	} elsif ( $lookup =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
		$ip   = $1;
		$port = 0;
	} elsif ( $lookup =~ /^([0-9a-f]+[0-9a-f:]+)\.(\d{1,5})$/ ) {
		$ip   = $1;
	} elsif ( $lookup =~ /^([0-9a-f]+[0-9a-f:]+)$/ ) {
		$ip   = $1;
		$port = 0;
	} elsif ( $lookup =~ /^([0-9a-f]+[0-9a-f:]+\.\.[0-9a-f:]+)\.(\d{1,5})$/ ) {
		$ip   = $1;
		$port = $2;
	} elsif ( $lookup =~ /^([0-9a-f]+[0-9a-f:]+\.\.[0-9a-f:]+)$/ ) {
		$ip   = $1;
		$port = 0;
	} 

	my $ipaddr = inet_aton($ip);
	my $hostname = gethostbyaddr($ipaddr, AF_INET);

	print $socket "<h3>$ip: $hostname</h3>\n";
#   print $socket "Port: $port<br>";

	my $whois_socket = IO::Socket::INET->new(
		PeerAddr  => 'whois.cyberabuse.org',
		PeerPort  => 43,
		Proto	  => 'tcp',
		timeout	  => 10 );

	if ( !$whois_socket ) {
		 print $socket "Can't connect to whoisd: $@<br>\n";
		return;
	}
	
	print $whois_socket "$ip\n";
	print $socket "<pre>";
	while ( <$whois_socket> ) {
		chomp;
		next if $_ =~ /^%/;
		next if $_ =~ /^\[/;
		next if $_ =~ /^$/;
		$_ =~ s/^\s*(.+)/$1/;
		$_ =~ s/:\s+/ /;
		next if $_ =~ /^Source/;
		print $socket "$_\n";
	}

	close $whois_socket;
	print $socket "</table>";

} # End of Lookup

1;
