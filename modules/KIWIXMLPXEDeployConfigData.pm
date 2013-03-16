#================
# FILE          : KIWIXMLPXEDeployConfigData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <pxedeploy> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLPXEDeployConfigData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Readonly;
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
	# Create the KIWIXMLPXEDeployConfigData object
	#
	# Internal data structure
	#
	# this = {
	#     arch = '',
	#     dest = '',
	#     source = ''
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
	if (! $this -> isInitHashRef($init) ) {
		return;
	}
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	my %keywords = map { ($_ => 1) } qw(
		arch
		dest
		source
	);
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init)) {
		return;
	}
	$this->{arch}   = $init->{arch};
	$this->{dest}   = $init->{dest};
	$this->{source} = $init->{source};
	
	return $this;
}

#==========================================
# getArch
#------------------------------------------
sub getArch {
	# ...
	# Return the configured Architecture'
	# ---
	my $this = shift;
	return $this->{arch};
}

#==========================================
# getDestination
#------------------------------------------
sub getDestination {
	# ...
	# Return the configured destination
	# ---
	my $this = shift;
	return $this->{dest};
}

#==========================================
# getSource
#------------------------------------------
sub getSource {
	# ...
	# Return the configured source
	# ---
	my $this = shift;
	return $this->{source};
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
	# ...
	# Verify that the initialization hash given to the constructor meets
	# all consistency and data criteria.
	# ---
	my $this = shift;
	my $init = shift;
	my $arch = $init->{arch};
	if ($arch) {
		my @arches = split /,/smx, $arch;
		for my $ar (@arches) {
			if (! $this->{supportedArch}{$ar} ) {
				my $kiwi = $this->{kiwi};
				$kiwi -> error ("Specified arch '$ar' is not supported");
				$kiwi -> failed ();
				return;
			}
		}
	}
	return 1;
}

1;

