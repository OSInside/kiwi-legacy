#================
# FILE          : KIWIXMLInstRepositoryData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <repository> element
#               : and it's child element <source>.
#               :
# STATUS        : Development
#----------------
package KIWIXMLInstRepositoryData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use XML::LibXML;
require Exporter;

use base qw /KIWIXMLRepositoryBaseData/;
#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLInstRepositoryData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $init = shift;
	my @addtlKeywords = qw(
		local
		name
	);
	my $this  = $class->SUPER::new($init, \@addtlKeywords);
	if (! $this) {
		return;
	}
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	my %boolKW = ( local => 1 );
	if (! $this -> __isInitConsistent($init)) {
		return;
	}
	$this -> __initializeBoolMembers($init);
	$this->{elname} = 'instrepo';
	$this->{local}  = $init->{local};
	$this->{name}   = $init->{name};

	return $this;
}

#==========================================
# getName
#------------------------------------------
sub getName {
	# ...
	# Return the name setting for the repository
	# ---
	my $this = shift;
	return $this->{name};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = $this->SUPER::getXMLElement();
	my $loc = $this -> isLocal();
	if ($loc) {
		$element -> setAttribute('local', $loc);
	}
	$element -> setAttribute('name', $this -> getName());
	return $element;
}

#==========================================
# isLocal
#------------------------------------------
sub isLocal {
	# ...
	# Return the local setting for the repository
	# ---
	my $this = shift;
	return $this->{local};
}

#==========================================
# setLocal
#------------------------------------------
sub setLocal {
	# ...
	# Set the flag indicating whether the repository is local
	# ---
	my $this = shift;
	my $loc = shift;
	my %settings = (
		attr   => 'local',
		value  => $loc,
		caller => 'setLocal'
	);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setName
#------------------------------------------
sub setName{
	# ...
	# Set the name for this repository
	# ---
	my $this = shift;
	my $name = shift;
	if (! $name ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setName: No name specified, retaining current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{name} = $name;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
	# ...
	# Verify that the initialization hash is valid
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	if (! $this -> __areKeywordBooleanValuesValid($init) ) {
		return;
	}
	if (! $init->{name} ) {
		my $msg = 'KIWIXMLInstRepositoryData: no "name" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{priority} ) {
		my $msg = 'KIWIXMLInstRepositoryData: no "priority" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

1;
