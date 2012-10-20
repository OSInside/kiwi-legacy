#================
# FILE          : KIWIXMLFileData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file encoded with the <file> element.
#               : As this is generic and non descriptive this class should
#               : not be used directly, only specific instances, i.e.
#               : children should be used.
#               :
# STATUS        : Development
#----------------
package KIWIXMLFileData;
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
	# Create the KIWIXMLFileData object
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
	my %keywords = map { ($_ => 1) } qw( arch name );
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> __isInitHashRef($init) ) {
		return;
	}
	if (! $this -> __areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init) )  {
		return;
	}
	$this->{name} = $init->{name};
	$this->{arch} = $init->{arch};

	return $this;
}

#==========================================
# setArch
#------------------------------------------
sub setArch {
	# ...
	# set the architecture value
	# ---
	my $this = shift;
	my $arch = shift;
	if (! $this->__isSupportedArch($arch)) {
		return;
	}
	$this->{arch} = $arch;
	return 1;
}

#==========================================
# getArch
#------------------------------------------
sub getArch {
	# ...
	# return the architecture value, if any
	# ---
	my $this = shift;
	return $this->{arch};
}

#==========================================
# getName
#------------------------------------------
sub getName {
	# ...
	# return the name value
	# ---
	my $this = shift;
	return $this->{name};
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
	# ...
	# Verify initialization consistency and validity requirements
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my $instName = ref $this;
	if (! $init->{name} ) {
		my $msg = "$instName: no 'name' specified in initialization "
			. 'structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($init->{arch}) {
		if (! $this -> __isSupportedArch($init->{arch})) {
			return;
		}
	}
	return 1;
}

#==========================================
# __isSupportedArch
#------------------------------------------
sub __isSupportedArch {
	# ...
	# See if the specified architecture is supported
	# ---
	my $this = shift;
	my $arch = shift;
	if (! $this->{supportedArch}{$arch} ) {
		my $kiwi = $this->{kiwi};
		$kiwi -> error ("Specified arch '$arch' is not supported");
		$kiwi -> failed ();
		return;
	}
	return 1;
}

1;
