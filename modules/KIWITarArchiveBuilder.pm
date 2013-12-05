#================
# FILE          : KIWITarArchiveBuilder.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Create a tar archive of the unpacked image tree
#               :
# STATUS        : Development
#----------------
package KIWITarArchiveBuilder;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX;
use KIWIXML;

use base qw /KIWIImageBuilderBase/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIContainerBuilder object
	# ---
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	if (! $this) {
		return;
	}
	$this->{baseWork} = 'tar';
	return $this;
}

#==========================================
# createImage
#------------------------------------------
sub createImage {
	# ...
	# Create the image, returns an array ref containing a
	# list of the files that are part of the image, created
	# by this builder
	# ---
	my $this = shift;
	my $status = 1; # assume success
	#==========================================
	# create the root directory
	#------------------------------------------
	my $targetDir = $this -> p_createBuildDir();
	if (! $targetDir) {
		return;
	}
	#==========================================
	# Run the user defined images.sh script
	#------------------------------------------
	$status = $this -> p_runUserImageScript();
	if (! $status) {
		return;
	}
	#==========================================
	# create the tarball
	#------------------------------------------
	$status = $this -> __createTarArchive();
	if (! $status) {
		return;
	}
	#==========================================
	# create a checksum file for the container
	#------------------------------------------
	$status = $this -> p_createChecksumFiles();
	if (! $status) {
		return;
	}
	return $this -> p_getCreatedFiles();
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __createTarArchive
#------------------------------------------
sub __createTarArchive {
	# ..
	# Create the tar archive
	# ---
	my $this = shift;
	my $cmdL = $this->{cmdL};
	my $kiwi = $this->{kiwi};
	my $locator = $this->{locator};
	my $xml  = $this->{xml};
	$kiwi -> info('Creating tar archive...');
	my $tarDestDir = $this -> getBaseBuildDirectory();
	my $origin = $cmdL -> getConfigDir();
	my $globals = KIWIGlobals -> instance();
	my $imgFlName = $globals -> generateBuildImageName($xml);
	$imgFlName .= '.tbz';
	my $tar = $locator -> getExecPath('tar');
	my $cmd = "cd $origin && "
		. "$tar -cjf $tarDestDir/$imgFlName --exclude=image . 2>&1";
	my $data = KIWIQX::qxx ($cmd);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed();
		$kiwi -> error("Could not create tarball $tarDestDir/$imgFlName");
		$kiwi -> failed();
		$kiwi -> error($data);
		return;
	}
	$this -> p_addCreatedFile($imgFlName);
	$kiwi -> done();
	return 1;
}

1;
