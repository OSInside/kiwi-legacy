#================
# FILE          : KIWITestResult.pm
#               :
# PROJECT       : KIWI
# COPYRIGHT     : (c) 2008 Novell inc. All rights reserved
#               :
# AUTHOR        : Pavel Sladek <psladek@suse.cz>
#               : Pavel Nemec  <pnemec@suse.cz>
#               :
# BELONGS TO    : Testing framework for Images
#               :
# DESCRIPTION   : This module launches a given test, checks 
#               : prerequisities described in xml file and 
#               : returns results
#               :
# STATUS        : Development
#----------------
package KIWITestResult;
#==========================================
# Modules
#------------------------------------------
use strict;
use XML::LibXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create new KIWITestResult object which provides
	# methods to set/add result messages and store them
	# as object data
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $self  = {};
	bless $self,$class;
	undef $self->{CMD};
	undef $self->{MSG};
	undef $self->{ERR};
	return $self;
}

#==========================================
# setMessage
#------------------------------------------
sub setMessage {
	my ($self,$msg) = @_;
	$self->{MSG}=$msg;
	return(0);
}

#==========================================
# setErrorState
#------------------------------------------
sub setErrorState {
	my ($self,$err) = @_;
	$self->{ERR}=$err;
	return(0);
}

#==========================================
# setCommand
#------------------------------------------
sub setCommand {
	my ($self,$cmd) = @_;
	$self->{CMD}=$cmd;
	return(0);
}

#==========================================
# addMessage
#------------------------------------------
sub addMessage {
	my ($self,$msg) = @_;
	$self->{MSG}=$self->{MSG}.$msg;
	return(0);
}

#==========================================
# getMessage
#------------------------------------------
sub getMessage {
	my ($self) = @_;
	return($self->{MSG});
}

#==========================================
# getErrorState
#------------------------------------------
sub getErrorState {
	my ($self) = @_;
	return($self->{ERR});
}

#==========================================
# getCommand
#------------------------------------------
sub getCommand {
	my ($self) = @_;
	return($self->{CMD});
}

1;
