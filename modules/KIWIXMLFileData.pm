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
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi = shift;
	my $name = shift;
	my $arch = shift;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	my %supported = map { ($_ => 1) } qw(
		armv7l ia64 ix86 ppc ppc64 s390 s390x x86_64
	);
	$this->{supportedArch} = \%supported;
	#==========================================
	# Argument checking
	#------------------------------------------
	if (! $name) {
		$kiwi -> error ('missing second argument for FileData ctor');
		$kiwi -> failed ();
		return 'missingName';
	}
	if (($arch) && (! $this->__isSupportedArch($arch))) {
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{name} = $name;
	$this->{arch} = $arch;
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
sub __isSupportedArch {
	# ...
	# See if the specified architecture is supported
	# ---
	my $this = shift;
	my $arch = shift;
	my %supported = %{ $this->{supportedArch} };
	if (! $supported{$arch} ) {
		my $kiwi = $this->{kiwi};
		$kiwi -> error ("Specified arch '$arch' is not supported");
		$kiwi -> failed ();
		return;
	}
	return 1;
}

1;
