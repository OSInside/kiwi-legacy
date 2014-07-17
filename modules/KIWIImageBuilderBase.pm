#================
# FILE          : KIWIImageBuilderBase.pm
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
package KIWIImageBuilderBase;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Digest::SHA1;
use File::Basename;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWIModules
#------------------------------------------
use KIWICommandLine;
use KIWIConfigWriterFactory;
use KIWILocator;
use KIWILog;
use KIWIQX;
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
	my $unPImg = shift;
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
	if (! defined $unPImg || ref($unPImg) ne 'KIWIImage') {
		my $msg = "$child: expecting KIWIImage object as third argument.";
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	$this->{cmdL} = $cmdL;
	$this->{kiwi} = $kiwi;
	$this->{locator} = KIWILocator -> instance();
	$this->{sumExtension} = 'sha1'; # Indicates the algorithm used
	$this->{uPckImg} = $unPImg;
	$this->{xml}  = $xml;
	$this->{baseBuildDir} = $this -> __generateBuildDirName();
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
# getChecksumExtension
#------------------------------------------
sub getChecksumExtension {
	# ...
	# Return the file name extension that indicates the checksum
	# algorithm used
	# ---
	my $this = shift;
	return $this->{sumExtension};
}

#==========================================
# Protected methods these should only be called by children
#------------------------------------------
#==========================================
# p_addCreatedFile
#------------------------------------------
sub p_addCreatedFile {
	# ...
	# Add the given name to teh creatde file array
	# ---
	my $this = shift;
	my $name = shift;
	if (! $name) {
		my $kiwi = $this->{kiwi};
		my $msg = 'KIWIImageBuilder:p_addCreatedFile no file name argument '
			. 'given, internal error, please file a bug';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{createdFiles}) {
		push @{$this->{createdFiles}}, $name;
		return 1;
	}
	my @files = ($name);
	$this->{createdFiles} = \@files;
	return 1;
}

#==========================================
# p_createBuildDir
#------------------------------------------
sub p_createBuildDir {
	# ...
	# Create a directory for the ImageBuilder to do its work
	# ---
	my $this = shift;
	my $destination = $this -> getBaseBuildDirectory();
	if ((! -d $destination) && (! mkdir $destination)) {
		my $kiwi = $this->{kiwi};
		$kiwi -> error  ("Failed to create destination subdir: $!");
		$kiwi -> failed ();
		return;
	}
	return $destination;
}

#==========================================
# p_createChecksumFiles
#------------------------------------------
sub p_createChecksumFiles {
	# ...
	# Create a checksum file for the container
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ext = $this -> getChecksumExtension();
	my @sumFiles;
	my $baseBuildDir = $this -> getBaseBuildDirectory();
	for my $fl (@{$this->{createdFiles}}) {
		my $baseFilePath = $baseBuildDir . '/' . $fl;
		my $digest = $this -> p_generateChecksum($baseFilePath);
		my $sumFilePath = $baseFilePath . '.' . $ext;
		push @sumFiles, $fl. '.' . $ext;
		my $status = open (my $SUMFL, '>', $sumFilePath);
		if (! $status) {
			$kiwi -> failed();
			my $msg = "Could create checksum file $sumFilePath";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		print $SUMFL "$digest  $fl";
		$status = close $SUMFL;
		if (! $status) {
			$kiwi -> failed();
			my $msg = "Could not close opened file: $sumFilePath";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	push @{$this->{createdFiles}}, @sumFiles;
	return $this;
}

#==========================================
# p_generateChecksum
#------------------------------------------
sub p_generateChecksum {
	# ...
	# Create a checksum for the given file
	# ---
	my $this     = shift;
	my $fileName = shift;
	my $kiwi = $this->{kiwi};

	if (! $fileName) {
		my $msg = 'KIWIImageBuilder:p_generateChecksum no file name argument '
			. 'given, internal error, please file a bug';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$kiwi -> info ('Generate image checksum...');
	my $status = open (my $INPUT, '<', $fileName);
	if (! $status) {
		$kiwi -> failed();
		my $msg = "Could not read $fileName";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $sha1 = Digest::SHA1->new();
	$sha1->addfile($INPUT);
	my $digest = $sha1->hexdigest();
	$status = close $INPUT;
	if (! $status) {
		$kiwi -> failed();
		my $msg = "Could not close opened file: $fileName";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
    $kiwi -> done();
	return $digest;
}

#==========================================
# p_getBaseWorkingDir
#------------------------------------------
sub p_getBaseWorkingDir {
	# ...
	# Return the name of the base working directory
	# ---
	my $this = shift;
	return $this->{baseWork};
}

#==========================================
# p_getCreatedFiles
#------------------------------------------
sub p_getCreatedFiles {
    # ...
    # Return an array ref containing names added with p_addCreatedFiles
    # ---
    my $this = shift;
    return $this->{createdFiles};
}

#==========================================
# p_runUserImageScript
#------------------------------------------
sub p_runUserImageScript {
	# ...
	# Execute the images.sh script on the unpacked image tree
	# ---
	my $this = shift;
	return $this->{uPckImg}->executeUserImagesScript();
}

#==========================================
# p_writeConfigFile
#------------------------------------------
sub p_writeConfigFile {
	# ...
	# Write the config file for this image to the given directory
	# ---
	my $this      = shift;
	my $configDir = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	if (! $configDir) {
		my $msg = 'KIWIImageBuilder:p_writeConfigFile no target for '
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
	my $status = $writer -> p_writeConfigFile();
	if (! $status) {
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __generateBuildDirName
#------------------------------------------
sub __generateBuildDirName {
	# ...
	# Construct the name of the work directory for the ImageBuilder to
	# do its work
	# ---
	my $this = shift;
	my $cmdL = $this->{cmdL};
	my $xml  = $this->{xml};
	my $destination = $cmdL -> getImageTargetDir();
	my $typeName = $xml -> getImageType() -> getTypeName();
	my $profileNames = $xml -> getActiveProfileNames();
	my $workDirName = $typeName;
	for my $prof (@{$profileNames}) {
		$workDirName .= '-' . $prof;
	}
	$destination .= "/" . $workDirName;
	return $destination
}

1;
