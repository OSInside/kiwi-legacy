#================
# FILE          : KIWIConfigWriterFactory.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Factory to create configuration file writer objects
#               : for the given image type or format.
#               :
# STATUS        : Development
#----------------
package KIWIConfigWriterFactory;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWIModules
#------------------------------------------
use KIWIContainerConfigWriter;
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
	# Create the KIWIConfigWriterFactory
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $xml    = shift;
	my $tgtDir = shift;
	my $kiwi = KIWILog -> instance();
	if (! defined $xml || ref($xml) ne 'KIWIXML') {
		my $msg = 'KIWIConfigWriterFactory: expecting KIWIXML object as '
			. 'first argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! defined $tgtDir) {
		my $msg = 'KIWIConfigWriterFactory: expecting configuration target '
			. 'directory as second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! -d $tgtDir) {
		my $msg = 'KIWIConfigWriterFactory: configuration target directory '
			. 'does not exist.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	$this->{kiwi} = $kiwi;
	$this->{confDir} = $tgtDir;
	$this->{xml}  = $xml;

	return $this;
}

#==========================================
# getConfigWriter
#------------------------------------------
sub getConfigWriter {
	# ...
	# Return the configuration writer for the given type or format
	# ---
	my $this = shift;
	my $confDir = $this->{confDir};
	my $xml  = $this->{xml};
	my $typeName = $xml -> getImageType() -> getTypeName();
	SWITCH: for ($typeName) {
		/^lxc|^docker/smx && do {
			my $writer = KIWIContainerConfigWriter -> new($xml, $confDir);
			if (($writer) && ($typeName eq 'docker')) {
				$writer -> setConfigFileName('default.conf');
			}
			return $writer;
	    };
	}
	return;
}

1;
