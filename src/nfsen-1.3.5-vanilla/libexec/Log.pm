#!%%PERL%%
#
#

package Log;

use strict;
use warnings;

use Sys::Syslog; 

use NfConf;

our $ERROR;

my $log_book = undef;

sub LogInit {

	Sys::Syslog::setlogsock($NfConf::LogSocket) if defined $NfConf::LogSocket;
	openlog("nfsen", 'cons,pid', $NfConf::syslog_facility);

} # End of LogInit

sub LogEnd {
	closelog();

} # End of LogEnd

sub StartLogBook {
	$log_book = shift;
} # End of SetLogBook

sub EndLogBook {
	$log_book = undef;
} # End of EndLogBook

sub TIEHANDLE {
	my $class	 = shift;
	my $name	 = shift;

	my %self;
	$self{'facility'} = $NfConf::syslog_facility;

	bless \%self, $class;

} # End of TIEHANDLE

sub PRINT {
	my $self = shift;
	my $msg = join '', @_;

	if ( defined $log_book ) {
		push @{$log_book}, $msg;
	}
	syslog('warning', "$msg"); 
}

sub UNTIE {
	my $self = shift;

} # End of UNTIE

1;
