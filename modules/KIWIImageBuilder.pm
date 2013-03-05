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
use File::Basename;

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
	#==========================================
	# Create atomic build dir
	#------------------------------------------
	my $baseBuildDir = $this -> __createBuildDir();
	if (! $baseBuildDir) {
		return;
	}
	$this->{baseBuildDir} = $baseBuildDir;
	return $this;
}

#==========================================
# getBaseBuildDirectory
#------------------------------------------
sub getBaseBuildDirectory {
	# ...
	# Return the path to the build directory that each builder should use to
	# create it's image specific working files and directories.
	# ---
	my $this = shift;
	return $this->{baseBuildDir};
}


#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __createBuildDir
#------------------------------------------
sub __createBuildDir {
	# ...
	# Create a directory for the ImageBuilder to do its work
	# ---
	my $this = shift;
	my $cmdL = $this->{cmdL};
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $destination = $cmdL -> getImageTargetDir();
	my $typeName = $xml -> getImageType() -> getImageType();
	my $profileNames = $xml -> getActiveProfileNames();
	my $workDirName = $typeName;
	for my $prof (@{$profileNames}) {
		$workDirName .= '-' . $prof;
	}
	$destination .= "/" . $workDirName;
	if ((! -d $destination) && (! mkdir $destination)) {
		$kiwi -> error  ("Failed to create destination subdir: $!");
		$kiwi -> failed ();
		return;
	}
	return $destination;
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
