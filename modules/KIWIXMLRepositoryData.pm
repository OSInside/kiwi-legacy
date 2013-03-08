#================
# FILE          : KIWIXMLRepositoryData.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
package KIWIXMLRepositoryData;
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
	# Create the KIWIXMLRepositoryData object
	#
	# Internal data structure
	#
	# this = {
	#    alias         = ''
	#    components    = ''
	#    distribution  = ''
	#    imageinclude  = ''
	#    path          = ''
	#    password      = ''
	#    preferlicense = ''
	#    priority      = ''
	#    status        = ''
	#    type          = ''
	#    username      = ''
	# }
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $init = shift;
	my @addtlKeywords = qw(
		alias
		components
		distribution
		imageinclude
		preferlicense
		status
		type
	);
	my $this  = $class->SUPER::new($init, \@addtlKeywords);
	if (! $this) {
		return;
	}
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	my %boolKW = map { ($_ => 1) } qw(
		imageinclude
		preferlicense
	);
	$this->{boolKeywords} = \%boolKW;
	my %supportedRepo = map { ($_ => 1) } qw(
		apt-deb
		apt-rpm
		deb-dir
		mirrors
		red-carpet
		rpm-dir
		rpm-md
		slack-site
		up2date-mirrors
		urpmi
		yast2
	);
	$this->{supportedRepoTypes} = \%supportedRepo;
	if (! $this -> __isInitConsistent($init)) {
		return;
	}
	$this -> __initializeBoolMembers($init);
	$this->{alias}        = $init->{alias};
	$this->{components}   = $init->{components};
	$this->{distribution} = $init->{distribution};
	$this->{elname}       = 'repository';
	$this->{status}       = $init->{status};
	$this->{type}         = $init->{type};
	# Default settings
	if (! $init->{status} ) {
		$this->{status} = 'replaceable';
		$this->{defaultstatus} = 1;
	}
	return $this;
}

#==========================================
# getAlias
#------------------------------------------
sub getAlias {
	# ...
	# Return the alias setting for the repository
	# ---
	my $this = shift;
	return $this->{alias};
}

#==========================================
# getComponents
#------------------------------------------
sub getComponents {
	# ...
	# Return the components indicator for the repository
	# ---
	my $this = shift;
	return $this->{components};
}

#==========================================
# getDistribution
#------------------------------------------
sub getDistribution {
	# ...
	# Return the distribution name indicator for the repository
	# ---
	my $this = shift;
	return $this->{distribution};
}

#==========================================
# getImageInclude
#------------------------------------------
sub getImageInclude {
	# ...
	# Return the image include indicator for the repository
	# ---
	my $this = shift;
	return $this->{imageinclude};
}

#==========================================
# getPreferLicense
#------------------------------------------
sub getPreferLicense {
	# ...
	# Return the license file indicator for the repository
	# ---
	my $this = shift;
	return $this->{preferlicense};
}

#==========================================
# getPriority
#------------------------------------------
sub getPriority {
	# ...
	# Return the priority setting for the repository
	# ---
	my $this = shift;
	return $this->{priority};
}

#==========================================
# getStatus
#------------------------------------------
sub getStatus {
	# ...
	# Return the repository status
	# ---
	my $this = shift;
	return $this->{status};
}

#==========================================
# getType
#------------------------------------------
sub getType {
	# ...
	# Return the type setting for the repository
	# ---
	my $this = shift;
	return $this->{type};
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
	my $alias = $this -> getAlias();
	if ($alias) {
		$element -> setAttribute('alias', $alias);
	}
	my $comp = $this -> getComponents();
	if ($comp) {
		$element -> setAttribute('components',$comp)
	}
	my $dist = $this -> getDistribution();
	if ($dist) {
		$element -> setAttribute('distribution', $dist);
	}
	my $include = $this -> getImageInclude();
	if ($include) {
		$element -> setAttribute('imageinclude', $include);
	}
	my $prefLic = $this -> getPreferLicense();
	if ($prefLic) {
		$element -> setAttribute('prefer-license', $prefLic);
	}
	my $prio = $this -> getPriority();
	if ($prio) {
		$element -> setAttribute('priority', $prio);
	}
	if (! $this->{defaultstatus}) {
		my $status = $this -> getStatus();
		if ($status) {
			$element -> setAttribute('status', $status);
		}
	}
	$element -> setAttribute('type', $this -> getType());
	return $element;
}

#==========================================
# setAlias
#------------------------------------------
sub setAlias{
	# ...
	# Set the alias for this repository
	# ---
	my $this = shift;
	my $alias = shift;
	if (! $alias ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setAlias: No alias specified, retaining current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{alias} = $alias;
	return $this;
}

#==========================================
# setComponents
#------------------------------------------
sub setComponents {
	# ...
	# Set the components for this repository
	# ---
	my $this = shift;
	my $comp = shift;
	if (! $comp) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setComponents: No components specified, retaining '
			. 'current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{components} = $comp;
	return $this;
}

#==========================================
# setDistribution
#------------------------------------------
sub setDistribution {
	# ...
	# Set the distribution name tag for this repository
	# ---
	my $this = shift;
	my $dist = shift;
	if (! $dist) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDistribution: No distribution specified, retaining '
			. 'current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{distribution} = $dist;
	return $this;
}

#==========================================
# setImageInclude
#------------------------------------------
sub setImageInclude {
	# ...
	# Set the image include indicator, when called with no argument
	# the indicator is turned off.
	# ---
	my $this = shift;
	my $include = shift;
	my %settings = (
		attr   => 'imageinclude',
		value  => $include,
		caller => 'setImageInclude'
	);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setPreferLicense
#------------------------------------------
sub setPreferLicense {
	# ...
	# Set the prefer license indicator, when called with no argument
	# the indicator is turned off.
	# ---
	my $this = shift;
	my $val = shift;
	my %settings = (
		attr   => 'preferlicense',
		value  => $val,
		caller => 'setPreferLicense'
	);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setPriority
#------------------------------------------
sub setPriority {
	# ...
	# Set the priority for this repository
	# ---
	my $this = shift;
	my $prio = shift;
	if (! $prio ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setPriority: No priority specified, retaining current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{priority} = $prio;
	return $this;
}

#==========================================
# setStatus
#------------------------------------------
sub setStatus {
	# ...
	# Set the statusfor this repository based on
	# keywords (fixed, replaceable)
	# ---
	my $this = shift;
	my $status = shift;
	if (! $status ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setStatus: No status specified, retaining current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($status ne 'fixed' && $status ne 'replaceable') {
		my $kiwi = $this->{kiwi};
		my $msg = 'setStatus: Expected keyword "fixed" or "replaceable"';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{status} = $status;
	return $this;
}

#==========================================
# setType
#------------------------------------------
sub setType {
	# ...
	# Set the type of the repository
	# ---
	my $this = shift;
	my $type = shift;
	if (! $type ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setType: No type specified, retaining current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isSupportedRepoType($type) ) {
		return;
	}
	$this->{type} = $type;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isSupportedRepoType
#------------------------------------------
sub __isSupportedRepoType {
	# ...
	# Check if the specified repository type is supported
	# ---
	my $this = shift;
	my $type = shift;
	if (! $this->{supportedRepoTypes}{$type} ) {
		my $kiwi = $this->{kiwi};
		my $msg = "Specified repository type '$type' is not supported";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

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
	if (! $init->{type} ) {
		my $msg = 'KIWIXMLRepositoryData: no "type" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this -> __isSupportedRepoType($init->{type}) ) {
		return;
	}
	return 1;
}

1;
