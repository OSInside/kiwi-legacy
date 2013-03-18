#================
# FILE          : KIWIXMLPackageArchiveData.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use XML::LibXML;
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
	my $init = shift;
	my @addtlKeywords = ( 'bootinclude' );
	my $this = $class->SUPER::new($init, \@addtlKeywords);
	if (! $this) {
		return;
	}
	my %boolKW = ( bootinclude => 1 );
	$this->{boolKeywords} = \%boolKW;
	if (! $this -> p_areKeywordBooleanValuesValid($init) ) {
		return;
	}
	$this->{bootinclude} = $init->{bootinclude};
	$this->{elname}      = 'archive';
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
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $elem = $this->SUPER::getXMLElement();
	my $bootincl = $this -> getBootInclude();
	if ($bootincl) {
		$elem  -> setAttribute('bootinclude', $bootincl);
	}
	return $elem;
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
	return $this -> p_setBooleanValue(\%settings);
}

1;
