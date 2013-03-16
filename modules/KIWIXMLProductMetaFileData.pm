#================
# FILE          : KIWIXMLProductMetaFileData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE  LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <metafile> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLProductMetaFileData;
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
	# Create the KIWIXMLProductMetaFileData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $init  = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	if (! $this -> hasInitArg($init) ) {
		return;
	}
	my %keywords = map { ($_ => 1) } qw(
	    script
		target
		url
	);
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> isInitHashRef($init) ) {
		return;
	}
	if (! $this -> areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init)) {
		return;
	}
	$this->{script} = $init->{script};
	$this->{target} = $init->{target};
	$this->{url}    = $init->{url};
	return $this;
}

#==========================================
# getScript
#------------------------------------------
sub getScript {
	# ...
	# Return the configured script
	# ---
	my $this = shift;
	return $this->{script};
}

#==========================================
# getTarget
#------------------------------------------
sub getTarget {
	# ...
	# Return the configured target
	# ---
	my $this = shift;
	return $this->{target};
}

#==========================================
# getURL
#------------------------------------------
sub getURL {
	# ...
	# Return the configured url
	# ---
	my $this = shift;
	return $this->{url};
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
	if (! $init->{script} ) {
		my $msg = 'KIWIXMLProductMetaFileData: no "script" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{target} ) {
		my $msg = 'KIWIXMLProductMetaFileData: no "target" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{url} ) {
		my $msg = 'KIWIXMLProductMetaFileData: no "url" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

1;
