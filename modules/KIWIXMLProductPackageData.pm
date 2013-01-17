#================
# FILE          : KIWIXMLProductPackageData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE  LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <repopackage> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLProductPackageData;
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
	# Create the KIWIXMLProductPackageData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $init  = shift;
	my @addtlKeywords = qw(
		addarch
		forcerepo
		medium
		onlyarch
		removearch
		script
		source
	);
	my $this = $class->SUPER::new($init, \@addtlKeywords);
	if (! $this) {
		return;
	}
	if (! $this -> __isProdInitConsistent($init) ) {
		return;
	}
	$this->{addarch}    = $init->{addarch};
	$this->{elname}     = 'repopackage';
	$this->{forcerepo}  = $init->{forcerepo};
	$this->{medium}     = $init->{medium};
	$this->{onlyarch}   = $init->{onlyarch};
	$this->{removearch} = $init->{removearch};
	$this->{script}     = $init->{script};
	$this->{source}     = $init->{source};
	return $this;
}

#==========================================
# getAdditionalArch
#------------------------------------------
sub getAdditionalArch {
	# ...
	# Return the additional architecture value, if any
	# ---
	my $this = shift;
	return $this->{addarch};
}

#==========================================
# getForceRepo
#------------------------------------------
sub getForceRepo {
	# ...
	# Return the search priority value, if any
	# ---
	my $this = shift;
	return $this->{forcerepo};
}

#==========================================
# getMediaID
#------------------------------------------
sub getMediaID {
	# ...
	# Return the media ID value, if any
	# ---
	my $this = shift;
	return $this->{medium};
}

#==========================================
# getOnlyArch
#------------------------------------------
sub getOnlyArch {
	# ...
	# Return the architecture value, if any
	# ---
	my $this = shift;
	return $this->{onlyarch};
}

#==========================================
# getRemoveArch
#------------------------------------------
sub getRemoveArch {
	# ...
	# Return the text that indicates packages to be remove that match
	# the returned value, if any
	# Note this is misnamed as it has nothing to do with any of the
	# architecture values
	# ---
	my $this = shift;
	return $this->{removearch};
}

#==========================================
# getScriptPath
#------------------------------------------
sub getScriptPath {
	# ...
	# Return the path to a script value, if any
	# ---
	my $this = shift;
	return $this->{script};
}

#==========================================
# getSourceLocation
#------------------------------------------
sub getSourceLocation {
	# ...
	# Return the location where the packages can be found value, if any
	# ---
	my $this = shift;
	return $this->{source};
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
	my $addarch = $this -> getAdditionalArch();
	if ($addarch) {
		$elem -> setAttribute('addarch', $addarch);
	}
	my $force = $this -> getForceRepo();
	if (defined $force) {
		$elem -> setAttribute('forcerepo', $force);
	}
	my $medid = $this -> getMediaID();
	if (defined $medid) {
		$elem -> setAttribute('medium', $medid);
	}
	my $oarch = $this -> getOnlyArch();
	if ($oarch) {
		$elem -> setAttribute('onlyarch', $oarch);
	}
	my $rarch = $this -> getRemoveArch();
	if ($rarch) {
		$elem -> setAttribute('removearch', $rarch);
	}
	my $script = $this -> getScriptPath();
	if ($script) {
		$elem -> setAttribute('script', $script);
	}
	my $src = $this -> getSourceLocation();
	if ($src) {
		$elem -> setAttribute('source', $src);
	}
	return $elem;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isProdInitConsistent {
	# ...
	# Verify that the initialization hash is valid
	# ---
	my $this = shift;
	my $init = shift;
	if ($init->{addarch}) {
		if (! $this->__isSupportedArch($init->{addarch})) {
			return;
		}
	}
	if ($init->{onlyarch}) {
		if (! $this->__isSupportedArch($init->{onlyarch})) {
			return;
		}
	}
	return 1;
}

1;
