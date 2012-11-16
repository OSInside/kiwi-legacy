#================
# FILE          : KIWIXMLPackageData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE  LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <package> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLPackageData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

use base qw /KIWIXMLFileData/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLPackageData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $kiwi = shift;
	my $init = shift;
	my @addtlKeywords = qw(
		bootdelete
		bootinclude
		replaces
	);
	my $this  = $class->SUPER::new($kiwi, $init, \@addtlKeywords);
	if (! $this) {
		return;
	}
	my %boolKW = map { ($_ => 1) } qw(
		bootdelete
		bootinclude
	);
	$this->{boolKeywords} = \%boolKW;
	if (! $this -> __areKeywordBooleanValuesValid($init) ) {
		return;
	}
	$this->{bootdelete}  = $init->{bootdelete};
	$this->{bootinclude} = $init->{bootinclude};
	$this->{replaces}    = $init->{replaces};
	return $this;
}

#==========================================
# getBootDelete
#------------------------------------------
sub getBootDelete {
	# ...
	# Return the setting of the bootdelete setting
	# ---
	my $this = shift;
	return $this->{bootdelete};
}

#==========================================
# getBootInclude
#------------------------------------------
sub getBootInclude {
	# ...
	# Return the setting of the bootinclude setting
	# ---
	my $this = shift;
	return $this->{bootinclude};
}

#==========================================
# getPackageToReplace
#------------------------------------------
sub getPackageToReplace {
	# ...
	# Return the name of the package replaced by this one
	# ---
	my $this = shift;
	return $this->{replaces}
}

#==========================================
# setBootDelete
#------------------------------------------
sub setBootDelete {
	# ...
	# Set the bootdelete attribute, if called with no argument the
	# value is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
		attr   => 'bootdelete',
		value  => $val,
		caller => 'setBootDelete'
	);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setBootInclude
#------------------------------------------
sub setBootInclude {
	# ...
	# Set the bootinclude attribute, if called with no argument the
	# value is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
		attr   => 'bootinclude',
		value  => $val,
		caller => 'setBootInclude'
	);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setPackageToReplace
#------------------------------------------
sub setPackageToReplace {
	# ...
	# Set the name of the package replaced by this one, if called with no
	# argument the attribute is erased
	# ---
	my $this = shift;
	my $name = shift;
	if (! $name) {
		delete $this->{replaces};
	} else {
		$this->{replaces} = $name;
	}
	return $this;
}


1;
