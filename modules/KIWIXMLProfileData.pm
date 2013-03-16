#================
# FILE          : KIWIXMLProfileData.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use XML::LibXML;
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
	#
	# Internal data structure
	#
	# this = {
	#	 description = ''
	#    import      = ''
	# }
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	if (! $this -> hasInitArg($init) ) {
		return;
	}
	my %keywords = map { ($_ => 1) } qw(
		description
		import
		name
	);
	$this->{supportedKeywords} = \%keywords;
	my %boolKW = map { ($_ => 1) } qw( import );
	$this->{boolKeywords} = \%boolKW;
	if (! $this -> isInitHashRef($init) ) {
		return;
	}
	if (! $this -> areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init)) {
		return;
	}
	$this -> initializeBoolMembers($init);
	$this->{description} = $init->{description};
	$this->{name}        = $init->{name};

	# Track the defaults
	if (! $init->{import}) {
		$this->{defaultimport} = 1;
	}
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
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new('profile');
	$element -> setAttribute('name', $this -> getName());
	$element -> setAttribute('description', $this -> getDescription());
	if (! $this->{defaultimport}) {
		my $import = $this -> getImportStatus();
		if ($import) {
			$element -> setAttribute('import', $import);
		}
	}
	return $element;
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
	return $this -> setBooleanValue(\%settings);
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
	if (! $this -> areKeywordBooleanValuesValid($init) ) {
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
