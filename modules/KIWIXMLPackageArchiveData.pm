#================
# FILE          : KIWIXMLPackageArchiveData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE  LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <archive> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLPackageArchiveData;
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
	# Create the KIWIXMLPackageArchiveData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $kiwi = shift;
	my $init = shift;
	my @addtlKeywords = ( 'bootinclude' );
	my $this  = $class->SUPER::new($kiwi, $init, \@addtlKeywords);
	if (! $this) {
		return;
	}
	my %boolKW = ( bootinclude => 1 );
	$this->{boolKeywords} = \%boolKW;
	if (! $this -> __areKeywordBooleanValuesValid($init) ) {
		return;
	}
	$this->{bootinclude} = $init->{bootinclude};
	return $this;
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

1;
