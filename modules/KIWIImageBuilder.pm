#================
# FILE          : KIWIImageBuilder.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Base class for all *Builder classes
#               :
# STATUS        : Development
#----------------
package KIWIImageBuilder;
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
use KIWIConfigWriterFactory;
use KIWILocator;
use KIWILog;
use KIWIQX qw(qxx);
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
	# Create the KIWIImageBuilder object
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
	my $child = ref $this;
	if (! defined $xml || ref($xml) ne 'KIWIXML') {
		my $msg = "$child: expecting KIWIXML object as first argument.";
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! defined $cmdL || ref($cmdL) ne 'KIWICommandLine') {
		my $msg = "$child: expecting KIWICommandLine object "
			. 'as second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	$this->{cmdL} = $cmdL;
	$this->{kiwi} = $kiwi;
	$this->{locator} = KIWILocator -> instance();
	$this->{xml}  = $xml;

	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __cleanupWorkingDir
#------------------------------------------
sub __cleanupWorkingDir {
	# ...
	# Remove the intermediate image creation directory
	# ---
	my $this    = shift;
	my $dirToRm = shift;
	my $kiwi = $this->{kiwi};
	if ($ENV{KIWI_KEEP_INTERMEDIATE}) {
		$kiwi -> info('Envirnment set to retain intermediate working tree');
		$kiwi -> done();
		return 1;
	}
	$kiwi -> info('Clean up intermediate working directory');
	my $baseWork = $this -> __getBaseWorkingDir();
	if (! $dirToRm && $baseWork) {
		my $cmdL = $this->{cmdL};
		$dirToRm = $cmdL -> getImageTargetDir() . '/' . $baseWork;
	}
	if ($dirToRm) {
		my $data = qxx ("rm -rf $dirToRm");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed();
			$kiwi -> error("Could not remove: $dirToRm");
			$kiwi -> failed();
			return;
		}
	}
	$kiwi -> done();
	return 1;
}

#==========================================
# __createWorkingDir
#------------------------------------------
sub __createWorkingDir {
	# ...
	# Create a directory for the ImageBuilder to do its work
	# ---
	my $this = shift;
	my $path = shift;
	my $cmdL = $this->{cmdL};
	my $kiwi = $this->{kiwi};
	my $locator = $this->{locator};
	my $basePath = $cmdL -> getImageTargetDir();
	my $baseWork = $this -> __getBaseWorkingDir();
	if (! $path && ! $baseWork) {
		return $basePath;
	}

	my $dirPath = $basePath . '/' . $baseWork . '/' . $path;
	my $mdir = $locator -> getExecPath('mkdir');
	my $data = qxx ("$mdir -p $dirPath");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error("Could not create directory: $dirPath");
		$kiwi -> failed();
		return;
	}
	return $dirPath;
}

#==========================================
# __getBaseWorkingDir
#------------------------------------------
sub __getBaseWorkingDir {
	# ...
	# Return the name of the base working directory
	# ---
	my $this = shift;
	return $this->{baseWork};
}

#==========================================
# __writeConfigFile
#------------------------------------------
sub __writeConfigFile {
	# ...
	# Write the config file for this image to the given directory
	# ---
	my $this      = shift;
	my $configDir = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	if (! $configDir) {
		my $msg = 'KIWIImageBuilder:__writeConfigFile no target for '
			. 'configuration given, internal error, please file a bug';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $confWriteFactory = KIWIConfigWriterFactory -> new($xml, $configDir);
	if (! $confWriteFactory) {
		return;
	}
	my $writer = $confWriteFactory -> getConfigWriter();
	my $status = $writer -> writeConfigFile();
	if (! $status) {
		$kiwi -> failed();
		return;
	}
	return 1;
}

1;
