#================
# FILE          : KIWIXMLProfileData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <profile> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLProfileData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

use base qw /KIWIXMLDataBase/;
#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLProfileData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi = shift;
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	if (! $this -> __hasInitArg($init) ) {
		return;
	}
	my %keywords = map { ($_ => 1) } qw(
		description import name
	);
	$this->{supportedKeywords} = \%keywords;
	my %boolKW = map { ($_ => 1) } qw( import );
	$this->{boolKeywords} = \%boolKW;
	if (! $this -> __isInitHashRef($init) ) {
		return;
	}
	if (! $this -> __areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init)) {
		return;
	}
	$this -> __initializeBoolMembers($init);
	$this->{description} = $init->{description};
	$this->{name}        = $init->{name};

	return $this;
}

#==========================================
# getDescription
#------------------------------------------
sub getDescription {
	# ...
	# Return the description of this profile
	# ---
	my $this = shift;
	return $this->{description};
}

#==========================================
# getimportStatus
#------------------------------------------
sub getImportStatus {
	# ...
	# Return the import status of this profile
	# ---
	my $this = shift;
	return $this->{import};
}

#==========================================
# getName
#------------------------------------------
sub getName {
	# ...
	# Return the name of this profile
	# ---
	my $this = shift;
	return $this->{name};
}

#==========================================
# setDescription
#------------------------------------------
sub setDescription {
	# ...
	# Set the description of this profile
	# ---
	my $this    = shift;
	my $descrpt = shift;
	if (! $descrpt ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDescription: no description given, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{description} = $descrpt;
	return $this;
}

#==========================================
# setimportStatus
#------------------------------------------
sub setImportStatus {
	# ...
	# Return the import status of this profile
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
		attr   => 'import',
		value  => $val,
		caller => 'setImportStatus'
	);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setName
#------------------------------------------
sub setName {
	# ...
	# Return the name of this profile
	# ---
	my $this = shift;
	my $name = shift;
	if (! $name ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setName: no name given, retaining '
			. 'current data.';
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
	if (! $init->{description} ) {
		my $msg = 'KIWIXMLProfileData: no "description" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{name} ) {
		my $msg = 'KIWIXMLProfileData: no "name" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

1;
