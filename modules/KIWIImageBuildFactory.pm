#================
# FILE          : KIWIImageBuildFactory.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This factory returns a KIWIImageBuilder child object
#               : specifc for the image type being built.
#               :
# STATUS        : Development
#----------------
package KIWIImageBuildFactory;

#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

#==========================================
# KIWIModules
#------------------------------------------
use KIWICommandLine;
use KIWIContainerBuilder;
use KIWILog;
use KIWIXML;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIImageBuildFactory
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $xml = shift;
	my $cmdL = shift;
	my $kiwi = KIWILog -> instance();
	if (! defined $xml || ref($xml) ne 'KIWIXML') {
		my $msg = 'KIWIImageBuildFactory: expecting KIWIXML object as '
			. 'first argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! defined $cmdL || ref($cmdL) ne 'KIWICommandLine') {
		my $msg = 'KIWIImageBuildFactory: expecting KIWICommandLine object '
			. 'as second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	$this->{cmdL} = $cmdL;
	$this->{kiwi} = $kiwi;
	$this->{xml}  = $xml;

	return $this;
}

#==========================================
# getImageBuilder
#------------------------------------------
sub getImageBuilder {
	# ...
	# Return an image tyep specific builder object
	# ---
	my $this = shift;
	my $cmdL = $this->{cmdL};
	my $xml  = $this->{xml};
	my $type = $xml -> getImageType();
	my $typeName = $type -> getImageType();
	SWITCH: for ($typeName) {
		/^lxc/smx && do {
			my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
			return $builder;
	};
	}
	return;
}

1;
