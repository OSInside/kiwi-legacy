#================
# FILE          : KIWIXML.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used for reading the control
#               : XML file, used for preparing an image
#               :
# STATUS        : Development
#----------------
package KIWIXML;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;
use Carp qw (cluck);
use File::Glob ':glob';
use File::Basename;
use LWP;
use XML::LibXML;
use KIWILocator;
use KIWILog;
use KIWIQX;
use KIWIURL;
use KIWIXMLValidator;
use KIWISatSolver;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (
	getInstSourceFile getInstSourceSatSolvable getSingleInstSourceSatSolvable
);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIXML object which is used to access the
	# configuration XML data stored as description file.
	# The xml data is splitted into four major tags: preferences,
	# drivers, repository and packages. While constructing an
	# object of this type there will be a node list created for
	# each of the major tags.
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
	my $kiwi        = shift;
	my $imageDesc   = shift;
	my $imageType   = shift;
	my $reqProfiles = shift;
	my $cmdL        = shift;
	my $changeset   = shift;
	my $addType     = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $arch = qxx ("uname -m"); chomp $arch;
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# Check pre condition
	#------------------------------------------
	if (! -d $imageDesc) {
		$kiwi -> error ("Couldn't locate configuration directory $imageDesc");
		$kiwi -> failed ();
		return;
	}
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
	}
	if (! $cmdL) {
		$kiwi -> error  ("No commandline reference specified");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	$this->{arch} = $arch;
	$this->{gdata}= $main::global -> getGlobals();
	$this->{cmdL} = $cmdL;
	#==========================================
	# Lookup XML configuration file
	#------------------------------------------
	my $locator = new KIWILocator($kiwi);
	my $controlFile = $locator -> getControlFile ( $imageDesc );
	if (! $controlFile) {
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{xmlOrigFile} = $controlFile;
	#==========================================
	# Read and Validate XML information
	#------------------------------------------
	my $validator = new KIWIXMLValidator (
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $systemTree = $validator -> getDOM();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{xmlOrigString} = $systemTree -> toString();
	$this->{systemTree}    = $systemTree;
	#==========================================
	# Read main XML sections
	#------------------------------------------
	my $imgnameNodeList = $systemTree -> getElementsByTagName ("image");
	my $optionsNodeList = $systemTree -> getElementsByTagName ("preferences");
	my $driversNodeList = $systemTree -> getElementsByTagName ("drivers");
	my $stripNodeList   = $systemTree -> getElementsByTagName ("strip");
	my $usrdataNodeList = $systemTree -> getElementsByTagName ("users");
	my $repositNodeList = $systemTree -> getElementsByTagName ("repository");
	my $packageNodeList = $systemTree -> getElementsByTagName ("packages");
	my $profilesNodeList= $systemTree -> getElementsByTagName ("profiles");
	my $instsrcNodeList = $systemTree -> getElementsByTagName ("instsource");
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{optionsNodeList} = $optionsNodeList;
	$this->{imgnameNodeList} = $imgnameNodeList;
	$this->{imageType}       = $imageType;
	$this->{reqProfiles}     = $reqProfiles;
	$this->{profilesNodeList}= $profilesNodeList;
	$this->{repositNodeList} = $repositNodeList;
	$this->{packageNodeList} = $packageNodeList;
	$this->{instsrcNodeList} = $instsrcNodeList;
	$this->{driversNodeList} = $driversNodeList;
	$this->{stripNodeList}   = $stripNodeList;
	#==========================================
	# add specified type if requested
	#------------------------------------------
	if ($addType) {
		$this -> addSimpleType ($imageType);
	}
	#==========================================
	# Read and create profile hash
	#------------------------------------------
	$this->{profileHash} = $this -> __populateProfiles();
	#==========================================
	# Read and create type hash
	#------------------------------------------
	$this->{typeList} = $this -> __populateTypeInfo();
	#==========================================
	# Update XML data from changeset if exists
	#------------------------------------------
	if (defined $changeset) {
		$this -> __populateImageTypeAndNode();
		$this -> __updateDescriptionFromChangeSet ($changeset);
	}
	#==========================================
	# Populate default profiles from XML if set
	#------------------------------------------
	$this -> __populateDefaultProfiles();
	#==========================================
	# Populate typeInfo hash
	#------------------------------------------
	$this -> __populateProfiledTypeInfo();
	#==========================================
	# Check profile names
	#------------------------------------------
	if (! $this -> checkProfiles()) {
		return;
	}
	#==========================================
	# Select and initialize image type
	#------------------------------------------
	if (! $this -> __populateImageTypeAndNode()) {
		return;
	}
	#==========================================
	# Add default split section if not defined
	#------------------------------------------
	if (! $this -> __addDefaultSplitNode()) {
		return;
	}
	#==========================================
	# Add default strip section if not defined
	#------------------------------------------
	if (! $this -> __addDefaultStripNode()) {
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{usrdataNodeList}    = $usrdataNodeList;
	$this->{controlFile}        = $controlFile;
	#==========================================
	# Store object data
	#------------------------------------------
	$this -> updateXML();
	return $this;
}

#==========================================
# updateTypeList
#------------------------------------------
sub updateTypeList {
	# ...
	# if the XML tree has changed because of a function
	# changing the typenode, it's required to update the
	# internal typeInfo hash too
	# ---
	my $this = shift;
	$this->{typeList} = $this -> __populateTypeInfo();
	$this -> __populateProfiledTypeInfo();
}

#==========================================
# updateXML
#------------------------------------------
sub updateXML {
	# ...
	# Write back the current DOM tree into the file
	# referenced by getRootLog but with the suffix .xml
	# if there is no log file set the service is skipped
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xmlu = $this->{systemTree}->toString();
	my $xmlf = $this->{xmlOrigFile};
	$kiwi -> storeXML ( $xmlu,$xmlf );
	return $this;
}

#==========================================
# writeXMLDescription
#------------------------------------------
sub writeXMLDescription {
	# ...
	# Write back the XML file into the prepare tree
	# below the image/ directory
	# ---
	my $this = shift;
	my $root = shift;
	my $gdata= $this->{gdata};
	my $xmlu = $this->{systemTree}->toString();
	my $file = $root."/image/config.xml";
	my $FD;
	if (! open ($FD, '>', $file)) {
		return;
	}
	print $FD $xmlu;
	close $FD;
	my $pretty = $gdata->{Pretty};
	qxx ("xsltproc -o $file.new $pretty $file");
	qxx ("mv $file.new $file");
	my $overlayTree = $gdata->{OverlayRootTree};
	if ($overlayTree) {
		qxx ("mkdir -p $overlayTree");
		qxx ("cp $file $overlayTree");
		$main::global -> setGlobals (
			"OverlayRootTree",0
		);
	}
	return $this;
}

#==========================================
# getConfigName
#------------------------------------------
sub getConfigName {
	my $this = shift;
	my $name = $this->{controlFile};
	return ($name);
}

#==========================================
# createURLList
#------------------------------------------
sub createURLList {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $cmdL = $this->{cmdL};
	my %repository  = ();
	my @urllist     = ();
	my %urlhash     = ();
	my @sourcelist  = ();
	%repository = $this->getRepository();
	if (! %repository) {
		%repository = $this->getInstSourceRepository();
		foreach my $name (keys %repository) {
			push (@sourcelist,$repository{$name}{source});
		}
	} else {
		@sourcelist = keys %repository;
	}
	foreach my $source (@sourcelist) {
		my $user = $repository{$source}[3];
		my $pwd  = $repository{$source}[4];
		my $urlHandler  = new KIWIURL ($kiwi,$cmdL,undef,$user,$pwd);
		my $publics_url = $urlHandler -> normalizePath ($source);
		push (@urllist,$publics_url);
		$urlhash{$source} = $publics_url;
	}
	$this->{urllist} = \@urllist;
	$this->{urlhash} = \%urlhash;
	return $this;
}

#==========================================
# getURLHash
#------------------------------------------
sub getURLHash {
	my $this = shift;
	if (! $this->{urlhash}) {
		$this -> createURLList();
	}
	return $this->{urlhash};
}

#==========================================
# getURLList
#------------------------------------------
sub getURLList {
	my $this = shift;
	if (! $this->{urllist}) {
		$this -> createURLList();
	}
	return $this->{urllist};
}

#==========================================
# getImageName
#------------------------------------------
sub getImageName {
	# ...
	# Get the name of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $name = $node -> getAttribute ("name");
	return $name;
}

#==========================================
# getImageDisplayName
#------------------------------------------
sub getImageDisplayName {
	# ...
	# Get the display name of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $name = $node -> getAttribute ("displayname");
	if (! defined $name) {
		return $this->getImageName();
	}
	return $name;
}

#==========================================
# getImageID
#------------------------------------------
sub getImageID {
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $code = $node -> getAttribute ("id");
	if (defined $code) {
		return $code;
	}
	return 0;
}

#==========================================
# getPreferencesNodeByTagName
#------------------------------------------
sub getPreferencesNodeByTagName {
	# ...
	# Searches in all nodes of the preferences sections
	# and returns the first occurenc of the specified
	# tag name. If the tag can't be found the function
	# returns the first node reference
	# ---
	my $this = shift;
	my $name = shift;
	my @node = $this->{optionsNodeList} -> get_nodelist();
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $tag = $element -> getElementsByTagName ("$name");
		if ($tag) {
			return $element;
		}
	}
	return $node[0];
}

#==========================================
# getImageSize
#------------------------------------------
sub getImageSize {
	# ...
	# Get the predefined size of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $plus = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("additive");
		if ((! defined $plus) || ($plus eq "false") || ($plus eq "0")) {
			my $unit = $node -> getElementsByTagName ("size")
				-> get_node(1) -> getAttribute("unit");
			if (! $unit) {
				# no unit specified assume MB...
				$unit = "M";
			}
			# /.../
			# the fixed size value was set, we will use this value
			# connected with the unit string
			# ----
			return $size.$unit;
		} else {
			# /.../
			# the size is setup as additive value to the required
			# size. The real size is calculated later and the additive
			# value is added at that point
			# ---
			return "auto";
		}
	} else {
		return "auto";
	}
}

#==========================================
# getImageSizeAdditiveBytes
#------------------------------------------
sub getImageSizeAdditiveBytes {
	# ...
	# Get the predefined size if the attribute additive
	# was set to true
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $plus = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("additive");
		if ((! defined $plus) || ($plus eq "false")) {
			return 0;
		}
	}
	if ($size) {
		my $byte = int $size;
		my $unit = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("unit");
		if ((! $unit) || ($unit eq "M")) {
			# no unit or M specified, turn into Bytes...
			return $byte * 1024 * 1024;
		} elsif ($unit eq "G") {
			# unit G specified, turn into Bytes...
			return $byte * 1024 * 1024 * 1024;
		}
	} else {
		return 0;
	}
}

#==========================================
# getImageSizeBytes
#------------------------------------------
sub getImageSizeBytes {
	# ...
	# Get the predefined size of the logical extend
	# as byte value
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $byte = int $size;
		my $plus = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("additive");
		if ((! defined $plus) || ($plus eq "false") || ($plus eq "0")) {
			# /.../
			# the fixed size value was set, we will use this value
			# and return a byte number
			# ----
			my $unit = $node -> getElementsByTagName ("size")
				-> get_node(1) -> getAttribute("unit");
			if ((! $unit) || ($unit eq "M")) {
				# no unit or M specified, turn into Bytes...
				return $byte * 1024 * 1024;
			} elsif ($unit eq "G") {
				# unit G specified, turn into Bytes...
				return $byte * 1024 * 1024 * 1024;
			}
		} else {
			# /.../
			# the size is setup as additive value to the required
			# size. The real size is calculated later and the additive
			# value is added at that point
			# ---
			return "auto";
		}
	} else {
		return "auto";
	}
}

#==========================================
# getEditBootConfig
#------------------------------------------
sub getEditBootConfig {
	# ...
	# Get the type specific editbootconfig value.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $editBoot = $tnode -> getAttribute ("editbootconfig");
	if ((! defined $editBoot) || ("$editBoot" eq "")) {
		return;
	}
	if (! -e $editBoot) {
		$kiwi -> warning ("Boot config script $editBoot doesn't exist");
		$kiwi -> skipped ();
		return;
	}
	return File::Spec->rel2abs($editBoot);
}

#==========================================
# getImageDefaultDestination
#------------------------------------------
sub getImageDefaultDestination {
	# ...
	# Get the default destination to store the images below
	# normally this is given by the --destination option but if
	# not and defaultdestination is specified in xml descr. we
	# will use this path as destination
	# ---
	my $this = shift;
	my $node = $this -> getPreferencesNodeByTagName ("defaultdestination");
	my $dest = $node -> getElementsByTagName ("defaultdestination");
	return $dest;
}

#==========================================
# getImageDefaultRoot
#------------------------------------------
sub getImageDefaultRoot {
	# ...
	# Get the default root directory name to build up a new image
	# normally this is given by the --root option but if
	# not and defaultroot is specified in xml descr. we
	# will use this path as root path.
	# ---
	my $this = shift;
	my $node = $this -> getPreferencesNodeByTagName ("defaultroot");
	my $root = $node -> getElementsByTagName ("defaultroot");
	return $root;
}

#==========================================
# getImageTypeAndAttributes
#------------------------------------------
sub getImageTypeAndAttributes {
	# ...
	# return typeinfo hash for selected build type
	# ---
	my $this     = shift;
	my $typeinfo = $this->{typeInfo};
	my $imageType= $this->{imageType};
	if (! $typeinfo) {
		return;
	}
	if (! $imageType) {
		return;
	}
	return $typeinfo->{$imageType};
}

#==========================================
# getImageVersion
#------------------------------------------
sub getImageVersion {
	# ...
	# Get the version of the logical extend
	# ---
	my $this = shift;
	my $node = $this -> getPreferencesNodeByTagName ("version");
	my $version = $node -> getElementsByTagName ("version");
	return $version;
}

#==========================================
# getPXEDeployUnionConfig
#------------------------------------------
sub getPXEDeployUnionConfig {
	# ...
	# Get the union file system configuration, if any
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("union") -> get_node(1);
	my %config = ();
	if (! $node) {
		return %config;
	}
	$config{ro}   = $node -> getAttribute ("ro");
	$config{rw}   = $node -> getAttribute ("rw");
	$config{type} = $node -> getAttribute ("type");
	return %config;
}

#==========================================
# getPXEDeployImageDevice
#------------------------------------------
sub getPXEDeployImageDevice {
	# ...
	# Get the device the image will be installed to
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("partitions") -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("device");
	} else {
		return;
	}
}

#==========================================
# getPXEDeployServer
#------------------------------------------
sub getPXEDeployServer {
	# ...
	# Get the server the config data is obtained from
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("server");
	} else {
		return "192.168.1.1";
	}
}

#==========================================
# getPXEDeployBlockSize
#------------------------------------------
sub getPXEDeployBlockSize {
	# ...
	# Get the block size the deploy server should use
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("blocksize");
	} else {
		return "4096";
	}
}

#==========================================
# getPXEDeployPartitions
#------------------------------------------
sub getPXEDeployPartitions {
	# ...
	# Get the partition configuration for this image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $partitions = $tnode -> getElementsByTagName ("partitions") -> get_node(1);
	my @result = ();
	if (! $partitions) {
		return @result;
	}
	my $partitionNodes = $partitions -> getElementsByTagName ("partition");
	for (my $i=1;$i<= $partitionNodes->size();$i++) {
		my $node = $partitionNodes -> get_node($i);
		my $number = $node -> getAttribute ("number");
		my $type = $node -> getAttribute ("type");
		if (! defined $type) {
			$type = "L";
		}
		my $size = $node -> getAttribute ("size");
		if (! defined $size) {
			$size = "x";
		}
		my $mountpoint = $node -> getAttribute ("mountpoint");
		if (! defined $mountpoint) {
			$mountpoint = "x";
		}
		my $target = $node -> getAttribute ("target");
		if (! defined $target or $target eq "false" or $target eq "0") {
			$target = 0;
		} else {
			$target = 1
		}
		
		my %part = ();
		$part{number} = $number;
		$part{type} = $type;
		$part{size} = $size;
		$part{mountpoint} = $mountpoint;
		$part{target} = $target;

		push @result, { %part };
	}
	my @ordered = sort { $a->{number} cmp $b->{number} } @result;
	return @ordered;
}

#==========================================
# getPXEDeployConfiguration
#------------------------------------------
sub getPXEDeployConfiguration {
	# ...
	# Get the configuration file information for this image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my @node = $tnode -> getElementsByTagName ("configuration");
	my %result;
	foreach my $element (@node) {
		my $source = $element -> getAttribute("source");
		my $dest   = $element -> getAttribute("dest");
		my $forarch= $element -> getAttribute("arch");
		my $allowed= 1;
		if (defined $forarch) {
			my @archlst = split (/,/,$forarch);
			my $foundit = 0;
			foreach my $archok (@archlst) {
				if ($archok eq $this->{arch}) {
					$foundit = 1; last;
				}
			}
			if (! $foundit) {
				$allowed = 0;
			}
		}
		if ($allowed) {
			$result{$source} = $dest;
		}
	}
	return %result;
}

#==========================================
# getPXEDeployTimeout
#------------------------------------------
sub getPXEDeployTimeout {
	# ...
	# Get the boot timeout, if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	my $timeout = $node -> getElementsByTagName ("timeout");
	if ((defined $timeout) && ! ("$timeout" eq "")) {
		return $timeout;
	} else {
		return;
	}
}

#==========================================
# getPXEDeployKernel
#------------------------------------------
sub getPXEDeployKernel {
	# ...
	# Get the deploy kernel, if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	my $kernel = $node -> getElementsByTagName ("kernel");
	if ((defined $kernel) && ! ("$kernel" eq "")) {
		return $kernel;
	} else {
		return;
	}
}

#==========================================
# getStripFileList
#------------------------------------------
sub getStripFileList {
	# ...
	# return filelist from the strip section referencing $ftype
	# ---
	my $this   = shift;
	my $ftype  = shift;
	my $inode  = $this->{imgnameNodeList} -> get_node(1);
	my @nodes  = $inode -> getElementsByTagName ("strip");
	my @result = ();
	my $tnode;
	if (! @nodes) {
		return @result;
	}
	foreach my $node (@nodes) {
		my $type = $node -> getAttribute ("type");
		if ($type eq $ftype) {
			$tnode = $node; last
		}
	}
	if (! $tnode) {
		return @result;
	}
	my @fileNodeList = $tnode -> getElementsByTagName ("file");
	foreach my $fileNode (@fileNodeList) {
		my $name = $fileNode -> getAttribute ("name");
		push @result, $name;
	}
	return @result;
}

#==========================================
# getStripDelete
#------------------------------------------
sub getStripDelete {
	# ...
	# return the type="delete" files from the strip section
	# ---
	my $this   = shift;
	return $this -> getStripFileList ("delete");
}

#==========================================
# getStripTools
#------------------------------------------
sub getStripTools {
	# ...
	# return the type="tools" files from the strip section
	# ---
	my $this   = shift;
	return $this -> getStripFileList ("tools");
}

#==========================================
# getStripLibs
#------------------------------------------
sub getStripLibs {
	# ...
	# return the type="libs" files from the strip section
	# ---
	my $this   = shift;
	return $this -> getStripFileList ("libs");
}

#==========================================
# getSplitPersistentFiles
#------------------------------------------
sub getSplitPersistentFiles {
	# ...
	# Get the persistent files/directories for split image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $persistNode = $node -> getElementsByTagName ("persistent")
		-> get_node(1);
	if (! defined $persistNode) {
		return @result;
	}
	my @fileNodeList = $persistNode -> getElementsByTagName ("file");
	foreach my $fileNode (@fileNodeList) {
		my $name = $fileNode -> getAttribute ("name");
		$name =~ s/\/$//;
		push @result, $name;
	}
	return @result;
}

#==========================================
# getSplitTempFiles
#------------------------------------------
sub getSplitTempFiles {
	# ...
	# Get the persistent files/directories for split image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $tempNode = $node -> getElementsByTagName ("temporary") -> get_node(1);
	if (! defined $tempNode) {
		return @result;
	}
	my @fileNodeList = $tempNode -> getElementsByTagName ("file");
	foreach my $fileNode (@fileNodeList) {
		my $name = $fileNode -> getAttribute ("name");
		$name =~ s/\/$//;
		push @result, $name;
	}
	return @result;
}

#==========================================
# getSplitTempExceptions
#------------------------------------------
sub getSplitTempExceptions {
	# ...
	# Get the exceptions defined for temporary
	# split portions. If there are no exceptions defined
	# return an empty list
	# ----
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $tempNode = $node -> getElementsByTagName ("temporary") -> get_node(1);
	if (! defined $tempNode) {
		return @result;
	}
	my @fileNodeList = $tempNode -> getElementsByTagName ("except");
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
	}
	return @result;
}

#==========================================
# getSplitPersistentExceptions
#------------------------------------------
sub getSplitPersistentExceptions {
	# ...
	# Get the exceptions defined for persistent
	# split portions. If there are no exceptions defined
	# return an empty list
	# ----
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $persistNode = $node -> getElementsByTagName ("persistent")
		-> get_node(1);
	if (! defined $persistNode) {
		return @result;
	}
	my @fileNodeList = $persistNode -> getElementsByTagName ("except");
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
	}
	return @result;
}

#==========================================
# getPXEDeployInitrd
#------------------------------------------
sub getPXEDeployInitrd {
	# ...
	# Get the deploy initrd, if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	my $initrd = $node -> getElementsByTagName ("initrd");
	if ((defined $initrd) && ! ("$initrd" eq "")) {
		return $initrd;
	} else {
		return;
	}
}

#==========================================
# setPackageManager
#------------------------------------------
sub setPackageManager {
	# ...
	# set packagemanager to use for this image
	# ---
	my $this  = shift;
	my $value = shift;
	if (! $value) {
		my $msg = 'setPackageManager method called without specifying '
		. 'package manager value.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return;
	}
	my $opts = $this -> getPreferencesNodeByTagName ("packagemanager");
	my $pmgr = $opts -> getElementsByTagName ("packagemanager");
	if (($pmgr) && ("$pmgr" eq "$value")) {
		return $this;
	}
	my $addElement = new XML::LibXML::Element ("packagemanager");
	$addElement -> appendText ($value);
	my $node = $opts -> getElementsByTagName ("packagemanager") -> get_node(1);
	if ($node) {
		$opts -> removeChild ($node);
	}
	$opts -> appendChild ($addElement);
	$this -> updateXML();
	return $this;
}

#==========================================
# getPackageManager
#------------------------------------------
sub getPackageManager {
	# ...
	# Get the name of the package manager if set.
	# if not set return the default package
	# manager name
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $node = $this -> getPreferencesNodeByTagName ("packagemanager");
	my @packMgrs = $node -> getElementsByTagName ("packagemanager");
	my $pmgr = $packMgrs[0];
	if (! $pmgr) {
		return 'zypper';
	}
	return $pmgr -> textContent();
}

#==========================================
# getLicenseNames
#------------------------------------------
sub getLicenseNames {
	# ...
	# Get the names of all showlicense elements and return
	# them as a list to the caller
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $node = $this -> getPreferencesNodeByTagName ("showlicense");
	my @lics = $node -> getElementsByTagName ("showlicense");
	my @names = ();
	foreach my $node (@lics) {
		push (@names,$node -> textContent());
	}
	if (@names) {
		return \@names;
	}
	return;
}

#==========================================
# getXenDomain
#------------------------------------------
sub getXenDomain {
	# ...
	# Obtain the Xen domain information if set
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $domain = $node -> getAttribute ("domain");
	if ((! defined $domain) || ("$domain" eq "")) {
		return;
	}
	return $domain;
}

#==========================================
# getOEMSwapSize
#------------------------------------------
sub getOEMSwapSize {
	# ...
	# Obtain the oem-swapsize value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $size = $node -> getElementsByTagName ("oem-swapsize");
	if ((! defined $size) || ("$size" eq "")) {
		return;
	}
	return $size;
}

#==========================================
# getOEMSystemSize
#------------------------------------------
sub getOEMSystemSize {
	# ...
	# Obtain the oem-systemsize value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $size = $node -> getElementsByTagName ("oem-systemsize");
	if ((! defined $size) || ("$size" eq "")) {
		return;
	}
	return $size;
}

#==========================================
# getOEMBootTitle
#------------------------------------------
sub getOEMBootTitle {
	# ...
	# Obtain the oem-boot-title value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $title= $node -> getElementsByTagName ("oem-boot-title");
	if ((! defined $title) || ("$title" eq "")) {
		$title = $this -> getImageDisplayName();
		if ((! defined $title) || ("$title" eq "")) {
			return;
		}
	}
	return $title;
}

#==========================================
# getOEMKiwiInitrd
#------------------------------------------
sub getOEMKiwiInitrd {
	# ...
	# Obtain the oem-kiwi-initrd value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $kboot= $node -> getElementsByTagName ("oem-kiwi-initrd");
	if ((! defined $kboot) || ("$kboot" eq "")) {
		return;
	}
	return $kboot;
}

#==========================================
# getOEMReboot
#------------------------------------------
sub getOEMReboot {
	# ...
	# Obtain the oem-reboot value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $boot = $node -> getElementsByTagName ("oem-reboot");
	if ((! defined $boot) || ("$boot" eq "")) {
		return;
	}
	return $boot;
}

#==========================================
# getOEMRebootInter
#------------------------------------------
sub getOEMRebootInter {
	# ...
	# Obtain the oem-reboot-interactive value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $boot = $node -> getElementsByTagName ("oem-reboot-interactive");
	if ((! defined $boot) || ("$boot" eq "")) {
		return;
	}
	return $boot;
}

#==========================================
# getOEMShutdown
#------------------------------------------
sub getOEMSilentBoot {
	# ...
	# Obtain the oem-silent-boot value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $silent = $node -> getElementsByTagName ("oem-silent-boot");
	if ((! defined $silent) || ("$silent" eq "")) {
		return;
	}
	return $silent;
}

#==========================================
# getOEMShutdown
#------------------------------------------
sub getOEMShutdown {
	# ...
	# Obtain the oem-shutdown value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $down = $node -> getElementsByTagName ("oem-shutdown");
	if ((! defined $down) || ("$down" eq "")) {
		return;
	}
	return $down;
}

#==========================================
# getOEMRebootInter
#------------------------------------------
sub getOEMShutdownInter {
	# ...
	# Obtain the oem-shutdown-interactive value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $down = $node -> getElementsByTagName ("oem-shutdown-interactive");
	if ((! defined $down) || ("$down" eq "")) {
		return;
	}
	return $down;
}

#==========================================
# getOEMBootWait
#------------------------------------------
sub getOEMBootWait {
	# ...
	# Obtain the oem-bootwait value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $wait = $node -> getElementsByTagName ("oem-bootwait");
	if ((! defined $wait) || ("$wait" eq "")) {
		return;
	}
	return $wait;
}

#==========================================
# getOEMUnattended
#------------------------------------------
sub getOEMUnattended {
	# ...
	# Obtain the oem-unattended value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $unattended = $node -> getElementsByTagName ("oem-unattended");
	if ((! defined $unattended) || ("$unattended" eq "")) {
		return;
	}
	return $unattended;
}

#==========================================
# getOEMUnattendedID
#------------------------------------------
sub getOEMUnattendedID {
	# ...
	# Obtain the oem-unattended-id value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $unattended_id = $node -> getElementsByTagName ("oem-unattended-id");
	if ((! defined $unattended_id) || ("$unattended_id" eq "")) {
		return;
	}
	return $unattended_id;
}

#==========================================
# getOEMSwap
#------------------------------------------
sub getOEMSwap {
	# ...
	# Obtain the oem-swap value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $swap = $node -> getElementsByTagName ("oem-swap");
	if ((! defined $swap) || ("$swap" eq "")) {
		return;
	}
	return $swap;
}

#==========================================
# getOEMAlignPartition
#------------------------------------------
sub getOEMAlignPartition {
	# ...
	# Obtain the oem-align-partition value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $align = $node -> getElementsByTagName ("oem-align-partition");
	if ((! defined $align) || ("$align" eq "")) {
		return;
	}
	return $align;
}

#==========================================
# getOEMPartitionInstall
#------------------------------------------
sub getOEMPartitionInstall {
	# ...
	# Obtain the oem-partition-install value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $pinst = $node -> getElementsByTagName ("oem-partition-install");
	if ((! defined $pinst) || ("$pinst" eq "")) {
		return;
	}
	return $pinst;
}

#==========================================
# getOEMRecovery
#------------------------------------------
sub getOEMRecovery {
	# ...
	# Obtain the oem-recovery value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $reco = $node -> getElementsByTagName ("oem-recovery");
	if ((! defined $reco) || ("$reco" eq "")) {
		return;
	}
	return $reco;
}

#==========================================
# getOEMRecoveryID
#------------------------------------------
sub getOEMRecoveryID {
	# ...
	# Obtain the oem-recovery partition ID value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $reco = $node -> getElementsByTagName ("oem-recoveryID");
	if ((! defined $reco) || ("$reco" eq "")) {
		return;
	}
	return $reco;
}

#==========================================
# getOEMRecoveryInPlace
#------------------------------------------
sub getOEMRecoveryInPlace {
	# ...
	# Obtain the oem-inplace-recovery value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $inplace = $node -> getElementsByTagName ("oem-inplace-recovery");
	if ((! defined $inplace) || ("$inplace" eq "")) {
		return;
	}
	return $inplace;
}

#==========================================
# getLocale
#------------------------------------------
sub getLocale {
	# ...
	# Obtain the locale value or return undef
	# ---
	my $this = shift;
	my $node = $this -> getPreferencesNodeByTagName ("locale");
	my $lang = $node -> getElementsByTagName ("locale");
	if ((! defined $lang) || ("$lang" eq "")) {
		return;
	}
	return $lang;
}

#==========================================
# getBootTheme
#------------------------------------------
sub getBootTheme {
	# ...
	# Obtain the boot-theme value or return undef
	# ---
	my $this = shift;
	my $node = $this -> getPreferencesNodeByTagName ("boot-theme");
	my $theme= $node -> getElementsByTagName ("boot-theme");
	if ((! defined $theme) || ("$theme" eq "")) {
		return;
	}
	return $theme;
}

#==========================================
# getRPMCheckSignatures
#------------------------------------------
sub getRPMCheckSignatures {
	# ...
	# Check if the package manager should check for
	# RPM signatures or not
	# ---
	my $this = shift;
	my $node = $this -> getPreferencesNodeByTagName ("rpm-check-signatures");
	my $sigs = $node -> getElementsByTagName ("rpm-check-signatures");
	if ((! defined $sigs) || ("$sigs" eq "") || ("$sigs" eq "false")) {
		return;
	}
	return $sigs;
}

#==========================================
# getRPMExcludeDocs
#------------------------------------------
sub getRPMExcludeDocs {
	# ...
	# Check if the package manager should exclude docs
	# from installed files or not
	# ---
	my $this = shift;
	my $node = $this-> getPreferencesNodeByTagName ("rpm-excludedocs");
	my $xdoc = $node -> getElementsByTagName ("rpm-excludedocs");
	if ((! defined $xdoc) || ("$xdoc" eq "")) {
		return;
	}
	return $xdoc;
}

#==========================================
# getRPMForce
#------------------------------------------
sub getRPMForce {
	# ...
	# Check if the package manager should force
	# installing packages
	# ---
	my $this = shift;
	my $node = $this -> getPreferencesNodeByTagName ("rpm-force");
	my $frpm = $node -> getElementsByTagName ("rpm-force");
	if ((! defined $frpm) || ("$frpm" eq "") || ("$frpm" eq "false")) {
		return;
	}
	return $frpm;
}

#==========================================
# getUsers
#------------------------------------------
sub getUsers {
	# ...
	# Receive a list of users to be added into the image
	# the user specification contains an optional password
	# and group. If the group doesn't exist it will be created
	# ---
	my $this   = shift;
	my %result = ();
	my @node   = $this->{usrdataNodeList} -> get_nodelist();
	foreach my $element (@node) {
		my $group = $element -> getAttribute("group");
		my $gid   = $element -> getAttribute("id");
		my @ntag  = $element -> getElementsByTagName ("user");
		foreach my $element (@ntag) {
			my $name = $element -> getAttribute ("name");
			my $uid  = $element -> getAttribute ("id");
			my $pwd  = $element -> getAttribute ("pwd");
			my $pwdformat = $element -> getAttribute ("pwdformat");
			my $home = $element -> getAttribute ("home");
			my $realname = $element -> getAttribute ("realname");
			my $shell = $element -> getAttribute ("shell");
			if (defined $name) {
				$result{$name}{group} = $group;
				$result{$name}{gid}   = $gid;
				$result{$name}{uid}   = $uid;
				$result{$name}{home}  = $home;
				$result{$name}{pwd}   = $pwd;
				$result{$name}{pwdformat}= $pwdformat;
				$result{$name}{realname} = $realname;
				$result{$name}{shell} = $shell;
			}
		}
	}
	return %result;
}

#==========================================
# getTypes
#------------------------------------------
sub getTypes {
	# ...
	# Receive a list of types available for this image
	# ---
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $cmdL    = $this->{cmdL};
	my @result  = ();
	my @tnodes  = ();
	my $gotprim = 0;
	my @node    = $this->{optionsNodeList} -> get_nodelist();
	my $urlhd   = new KIWIURL ($kiwi,$cmdL);
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my @types = $element -> getElementsByTagName ("type");
		push (@tnodes,@types);
	}
	foreach my $node (@tnodes) {
		my %record  = ();
		$record{type} = $node -> getAttribute("image");
		$record{boot} = $node -> getAttribute("boot");
		my $bootpath = $urlhd -> normalizeBootPath ($record{boot});
		if (defined $bootpath) {
			$record{boot} = $bootpath;
		}
		my $primary = $node -> getAttribute("primary");
		if ((defined $primary) && ("$primary" eq "true")) {
			$record{primary} = "true";
			$gotprim = 1;
		} else {
			$record{primary} = "false";
		}
		push (@result,\%record);
	}
	if (! $gotprim) {
		$result[0]->{primary} = "true";
	}
	return @result;
}

#==========================================
# getProfiles
#------------------------------------------
sub getProfiles {
	# ...
	# Receive a list of profiles available for this image
	# ---
	my $this   = shift;
	my $import = shift;
	my @result;
	if (! defined $this->{profilesNodeList}) {
		return @result;
	}
	my $base = $this->{profilesNodeList} -> get_node(1);
	if (! defined $base) {
		return @result;
	}
	my @node = $base -> getElementsByTagName ("profile");
	foreach my $element (@node) {
		my $name = $element -> getAttribute ("name");
		my $desc = $element -> getAttribute ("description");
		my $incl = $element -> getAttribute ("import");
		my %profile = ();
		$profile{name} = $name;
		$profile{description} = $desc;
		$profile{include} = $incl;
		push @result, { %profile };
	}
	return @result;
}

#==========================================
# checkProfiles
#------------------------------------------
sub checkProfiles {
	# ...
	# validate profile names. Wrong profile names are treated
	# as fatal error because you can't know what the result of
	# your image would be without the requested profile
	# ---
	my $this = shift;
	my $pref = shift;
	my $kiwi = $this->{kiwi};
	my $rref = $this->{reqProfiles};
	my @prequest;
	my @profiles = $this -> getProfiles();
	if (defined $pref) {
		@prequest = @{$pref};
	} elsif (defined $rref) {
		@prequest = @{$rref};
	}
	if (@prequest) {
		foreach my $requested (@prequest) {
			my $ok = 0;
			foreach my $profile (@profiles) {
				if ($profile->{name} eq $requested) {
					$ok=1; last;
				}
			}
			if (! $ok) {
				$kiwi -> error  ("Profile $requested: not found");
				$kiwi -> failed ();
				return;
			}
		}
	}
	return $this;
}

#==========================================
# getInstSourceRepository
#------------------------------------------
sub getInstSourceRepository {
	# ...
	# Get the repository path and priority used for building
	# up an installation source tree.
	# ---
	my $this = shift;
	my %result;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	if (! defined $base) {
		return %result;
	}
	my @node = $base -> getElementsByTagName ("instrepo");
	foreach my $element (@node) {
		my $prio = $element -> getAttribute("priority");
		my $name = $element -> getAttribute("name");
		my $user = $element -> getAttribute("username");
		my $pwd  = $element -> getAttribute("pwd");
		my $islocal  = $element -> getAttribute("local");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> resolveLink ( $stag -> getAttribute ("path") );
		if (! defined $name) {
			$name = "noname";
		}
		$result{$name}{source}   = $source;
		$result{$name}{priority} = $prio;
		$result{$name}{islocal} = $islocal;
		if (defined $user) {
			$result{$name}{user} = $user.":".$pwd;
		}
	}
	return %result;
}

#==========================================
# getInstSourceArchList
#------------------------------------------
sub getInstSourceArchList {
	# ...
	# Get the architecture list used for building up
	# an installation source tree
	# ---
	# return a hash with the following structure:
	# name  = [ description, follower ]
	#   name is the key, given as "id" in the xml file
	#   description is the alternative name given as "name" in the xml file
	#   follower is the key value of the next arch in the fallback chain
	# ---
	my $this = shift;
	my $base = $this->{instsrcNodeList}->get_node(1);
	my $elems = $base->getElementsByTagName("architectures");
	my %result;
	my @attr = ("id", "name", "fallback");
	for(my $i=1; $i<= $elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName("arch");
		my %rlist = map { $_->getAttribute("ref") => $_ }
			$node->getElementsByTagName("requiredarch");
		foreach my $element(@flist) {
			my $id = $element->getAttribute($attr[0]);
			next if (!$id);
			my $ra = 0;
			if($rlist{$id}) {
			  $ra = 1;
			}
			my ($d,$n) = (
				$element->getAttribute($attr[1]),
				$element->getAttribute($attr[2])
			);
			if($n) {
				$result{$id} = [ $d, $n, $ra ];
			} else {
				$result{$id} = [ $d, 0, $ra ];
			}
		}
	}
	return %result;
}

#==========================================
# getInstSourceProductVar
#------------------------------------------
sub getInstSourceProductVar {
	# ...
	# Get the shell variable values needed for
	# metadata creation
	# ---
	# return a hash with the following structure:
	# varname = value (quoted, may contain space etc.)
	# ---
	my $this = shift;
	return $this->getInstSourceProductStuff("productvar");
}

#==========================================
# getInstSourceProductOption
#------------------------------------------
sub getInstSourceProductOption {
	# ...
	# Get the shell variable values needed for
	# metadata creation
	# ---
	# return a hash with the following structure:
	# varname = value (quoted, may contain space etc.)
	# ---
	my $this = shift;
	return $this->getInstSourceProductStuff("productoption");
}

#==========================================
# getInstSourceProductStuff
#------------------------------------------
sub getInstSourceProductStuff {
	# ...
	# generic function returning indentical data
	# structures for different tags (of same type)
	# ---
	my $this = shift;
	my $what = shift;
	if (!$what) {
		return;
	}

	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $elems = $base->getElementsByTagName("productoptions");
	my %result;

	for(my $i=1; $i<=$elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName($what);
		foreach my $element(@flist) {
			my $name = $element->getAttribute("name");
			my $value = $element ->textContent("name");
			$result{$name} = $value;
		}
	}
	return %result;
}

#==========================================
# getInstSourceProductInfo
#------------------------------------------
sub getInstSourceProductInfo {
	# ...
	# Get the shell variable values needed for
	# content file generation
	# ---
	# return a hash with the following structure:
	# index = (name, value)
	# ---
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $elems = $base->getElementsByTagName("productoptions");
	my %result;

	for(my $i=1; $i<=$elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName("productinfo");
		for(my $j=0; $j <= $#flist; $j++) {
		#foreach my $element(@flist) {
			my $name = $flist[$j]->getAttribute("name");
			my $value = $flist[$j]->textContent("name");
			$result{$j} = [$name, $value];
		}
	}
	return %result;
}

#==========================================
# getInstSourceChrootList
#------------------------------------------
sub getInstSourceChrootList {
	# ...
	# Get the list of packages necessary to
	# run metafile shell scripts in chroot jail
	# ---
	# return a list of packages
	# ---
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $elems = $base->getElementsByTagName("metadata");
	my @result;

	for(my $i=1; $i<=$elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName("chroot");
		foreach my $element(@flist) {
			my $name = $element->getAttribute("requires");
			push @result, $name if $name;
		}
	}
	return @result;
}

#==========================================
# getInstSourceMetaFiles
#------------------------------------------
sub getInstSourceMetaFiles {
	# ...
	# Get the metafile data if any. The method is returning
	# a hash with key=metafile and a hashreference for the
	# attribute values url, target and script
	# ---
	my $this  = shift;
	my $base  = $this->{instsrcNodeList} -> get_node(1);
	my $nodes = $base -> getElementsByTagName ("metadata");
	my %result;
	my @attrib = (
		"target","script"
	);
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node  = $nodes -> get_node($i);
		my @flist = $node  -> getElementsByTagName ("metafile");
		foreach my $element (@flist) {
			my $file = $element -> getAttribute ("url");
			if (! defined $file) {
				next;
			}
			foreach my $key (@attrib) {
				my $value = $element -> getAttribute ($key);
				if (defined $value) {
					$result{$file}{$key} = $value;
				}
			}
		}
	}
	return %result;
}

#==========================================
# getRepository
#------------------------------------------
sub getRepository {
	# ...
	# Get the repository type used for building
	# up the physical extend. For information on the available
	# types refer to the package manager documentation
	# ---
	my $this = shift;
	my @node = $this->{repositNodeList} -> get_nodelist();
	my %result;
	foreach my $element (@node) {
		#============================================
		# Check to see if node is in included profile
		#--------------------------------------------
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		#============================================
		# Store repo information in hash
		#--------------------------------------------
		my $type = $element -> getAttribute("type");
		my $alias= $element -> getAttribute("alias");
		my $imgincl = $element -> getAttribute("imageinclude");
		my $prio = $element -> getAttribute("priority");
		my $user = $element -> getAttribute("username");
		my $pwd  = $element -> getAttribute("password");
		my $plic = $element -> getAttribute("prefer-license");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> resolveLink ( $stag -> getAttribute ("path") );
		$result{$source} = [$type,$alias,$prio,$user,$pwd,$plic,$imgincl];
	}
	return %result;
}

#==========================================
# getHttpsRepositoryCredentials
#------------------------------------------
sub getHttpsRepositoryCredentials {
	# ...
	# If any repository is configered with credentials return the username
	# and password
	# ---
	my $this = shift;
	my @repoNodes = $this->{repositNodeList} -> get_nodelist();
	for my $repo (@repoNodes) {
		my $uname = $repo -> getAttribute('username');
		my $pass = $repo -> getAttribute('password');
		if ($uname) {
			my @sources = $repo -> getElementsByTagName ('source');
			my $path = $sources[0] -> getAttribute('path');
			if ( $path =~ /^https:/) {
				return ($uname, $pass);
			}
		}
	}
	return;
}

#==========================================
# ignoreRepositories
#------------------------------------------
sub ignoreRepositories {
	# ...
	# Ignore all the repositories in the XML file.
	# ---
	my $this = shift;
	my @node = $this->{repositNodeList} -> get_nodelist();
	foreach my $element (@node) {
		$this->{imgnameNodeList}->get_node(1)->removeChild ($element);
	}
	$this->{repositNodeList} = 
		$this->{systemTree}->getElementsByTagName ("repository");
	$this-> updateXML();
	return $this;
}

#==========================================
# setRepository
#------------------------------------------
sub setRepository {
	# ...
	# Overwerite the repository path and type of the first
	# repository node with the given data
	# ---
	my $this = shift;
	my $type = shift;
	my $path = shift;
	my $alias= shift;
	my $prio = shift;
	my $user = shift;
	my $pass = shift;
	my @node = $this->{repositNodeList} -> get_nodelist();
	foreach my $element (@node) {
		my $status = $element -> getAttribute("status");
		if ((defined $status) && ($status eq "fixed")) {
			next;
		}
		if (defined $type) {
			$element -> setAttribute ("type",$type);
		}
		if (defined $path) {
			$element -> getElementsByTagName ("source")
				-> get_node (1) -> setAttribute ("path",$path);
		}
		if (defined $alias) {
			$element -> setAttribute ("alias",$alias);
		}
		if ((defined $prio) && ($prio != 0)) {
			$element -> setAttribute ("priority",$prio);
		}
		if ((defined $user) && (defined $pass)) {
			$element -> setAttribute ("username",$user);
			$element -> setAttribute ("password",$pass);
		}
		last;
	}
	$this -> createURLList();
	$this -> updateXML();
	return $this;
}

#==========================================
# addRepository
#------------------------------------------
sub addRepository {
	# ...
	# Add a repository section to the current list of
	# repos and update repositNodeList accordingly. 
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @type = @{$_[0]};
	my @path = @{$_[1]};
	my @alias;
	my @prio;
	my @user;
	my @pass;
	if ($_[2]) {
		@alias= @{$_[2]};
	}
	if ($_[3]) {
		@prio = @{$_[3]};
	}
	if ($_[4]) {
		@user = @{$_[4]};
	}
	if ($_[5]) {
		@pass = @{$_[5]};
	}
	foreach my $path (@path) {
		my $type = shift @type;
		my $alias= shift @alias;
		my $prio = shift @prio;
		my $user = shift @user;
		my $pass = shift @pass;
		if (! defined $type) {
			$kiwi -> error   ("No type for repo [$path] specified");
			$kiwi -> skipped ();
			next;
		}
		my $addrepo = new XML::LibXML::Element ("repository");
		$addrepo -> setAttribute ("type",$type);
		$addrepo -> setAttribute ("status","fixed");
		if (defined $alias) {
			$addrepo -> setAttribute ("alias",$alias);
		}
		if ((defined $prio) && ($prio != 0)) {
			$addrepo -> setAttribute ("priority",$prio);
		}
		if ((defined $user) && (defined $pass)) {
			$addrepo -> setAttribute ("username",$user);
			$addrepo -> setAttribute ("password",$pass);
		}
		my $addsrc  = new XML::LibXML::Element ("source");
		$addsrc -> setAttribute ("path",$path);
		$addrepo -> appendChild ($addsrc);
		$this->{imgnameNodeList}->get_node(1)->appendChild ($addrepo);
	}
	$this->{repositNodeList} =
		$this->{systemTree}->getElementsByTagName ("repository");
	$this -> createURLList();
	$this -> updateXML();
	return $this;
}

#==========================================
# addDrivers
#------------------------------------------
sub addDrivers {
	# ...
	# Add the given driver list to the specified drivers
	# section of the xml description parse tree.
	# ----
	my $this  = shift;
	my @drvs  = @_;
	my $kiwi  = $this->{kiwi};
	my $nodes = $this->{driversNodeList};
	my $nodeNumber = -1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		$nodeNumber = $i;
	}
	if ($nodeNumber < 0) {
		$kiwi -> loginfo ("addDrivers: no drivers section found... skipped\n");
		return $this;
	}
	foreach my $driver (@drvs) {
		next if ($driver eq "");
		my $addElement = new XML::LibXML::Element ("file");
		$addElement -> setAttribute("name",$driver);
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addStrip
#------------------------------------------
sub addStrip {
	# ...
	# Add the given strip list and type to the xml description
	# ----
	my $this  = shift;
	my $type  = shift;
	my @list  = @_;
	my $kiwi  = $this->{kiwi};
	my $image = $this->{imgnameNodeList} -> get_node(1);
	my $stripSection = new XML::LibXML::Element ("strip");
	$stripSection -> setAttribute("type",$type);
	foreach my $name (@list) {
		my $fileSection = new XML::LibXML::Element ("file");
		$fileSection  -> setAttribute("name",$name);
		$stripSection -> appendChild ($fileSection);
	}
	$image-> appendChild ($stripSection);
	$this -> updateXML();
	return $this;
}

#==========================================
# addSimpleType
#------------------------------------------
sub addSimpleType {
	# ...
	# add simple filesystem type to the list of types
	# inside the preferences section
	# ---
	my $this  = shift;
	my $type  = shift;
	my $kiwi  = $this->{kiwi};
	my $nodes = $this->{optionsNodeList};
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $addElement = new XML::LibXML::Element ("type");
		$addElement -> setAttribute("image",$type);
		$nodes -> get_node($i) -> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addPackages
#------------------------------------------
sub addPackages {
	# ...
	# Add the given package list to the specified packages
	# type section of the xml description parse tree.
	# ----
	my $this  = shift;
	my $ptype = shift;
	my $bincl = shift;
	my $nodes = shift;
	my $kiwi  = $this->{kiwi};
	my @packs = @_;
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = -1;
	my $nodeNumberBootStrap = -1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		if ($type eq "bootstrap") {
			$nodeNumberBootStrap = $i;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i;
		}
	}
	if ($nodeNumberBootStrap < 0) {
		$kiwi -> warning (
			"Failed to add @packs, package(s), no bootstrap section found"
		);
		$kiwi -> skipped ();
		return $this;
	}
	if (($nodeNumber < 0) && ($ptype eq "image")) {
		$kiwi -> warning (
			"addPackages: no image section found, adding to bootstrap"
		);
		$kiwi -> done();
		$nodeNumber = $nodeNumberBootStrap;
	}
	if ($nodeNumber < 0) {
		$kiwi -> loginfo ("addPackages: no $ptype section found... skipped\n");
		return $this;
	}
	foreach my $pack (@packs) {
		next if ($pack eq "");
		my $addElement = new XML::LibXML::Element ("package");
		$addElement -> setAttribute("name",$pack);
		if (($bincl) && ($bincl->{$pack} == 1)) {
			$addElement -> setAttribute("bootinclude","true");
		}
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addPatterns
#------------------------------------------
sub addPatterns {
	# ...
	# Add the given pattern list to the specified packages
	# type section of the xml description parse tree.
	# ----
	my $this  = shift;
	my $ptype = shift;
	my $nodes = shift;
	my @patts = @_;
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = 1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i; last;
		}
	}
	foreach my $pack (@patts) {
		my $addElement = new XML::LibXML::Element ("opensusePattern");
		$addElement -> setAttribute("name",$pack);
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addArchives
#------------------------------------------
sub addArchives {
	# ...
	# Add the given archive list to the specified packages
	# type section of the xml description parse tree as an.
	# archive element
	# ----
	my $this  = shift;
	my $ptype = shift;
	my $bincl = shift;
	my $nodes = shift;
	my @tars  = @_;
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = 1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i; last;
		}
	}
	foreach my $tar (@tars) {
		my $addElement = new XML::LibXML::Element ("archive");
		$addElement -> setAttribute("name",$tar);
		if ($bincl) {
			$addElement -> setAttribute("bootinclude","true");
		}
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addImagePackages
#------------------------------------------
sub addImagePackages {
	# ...
	# Add the given package list to the type=bootstrap packages
	# section of the xml description parse tree.
	# ----
	my $this  = shift;
	return $this -> addPackages ("image",undef,undef,@_);
}

#==========================================
# addImagePatterns
#------------------------------------------
sub addImagePatterns {
	# ...
	# Add the given pattern list to the type=bootstrap packages
	# section of the xml description parse tree.
	# ----
	my $this  = shift;
	return $this -> addPatterns ("image",undef,@_);
}

#==========================================
# addRemovePackages
#------------------------------------------
sub addRemovePackages {
	# ...
	# Add the given package list to the type=delete packages
	# section of the xml description parse tree.
	# ----
	my $this  = shift;
	return $this -> addPackages ("delete",undef,undef,@_);
}

#==========================================
# getBootIncludes
#------------------------------------------
sub getBootIncludes {
	# ...
	# Collect all items marked as bootinclude="true"
	# and return them in a list of names
	# ----
	my $this = shift;
	my @node = $this->{packageNodeList} -> get_nodelist();
	my @result = ();
	my @plist  = ();
	foreach my $element (@node) {
		my $type = $element -> getAttribute ("type");
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		if (($type eq "image") || ($type eq "bootstrap")) {
			push (@plist,$element->getElementsByTagName ("package"));
		}
	}
	foreach my $element (@plist) {
		my $itemname= $element -> getAttribute ("name");
		my $bootinc = $element -> getAttribute ("bootinclude");
		if ((defined $bootinc) && ("$bootinc" eq "true")) {
			push (@result,$itemname);
		}
	}
	return @result;
}

#==========================================
# getImageConfig
#------------------------------------------
sub getImageConfig {
	# ...
	# Evaluate the attributes of the drivers and preferences tags and
	# build a hash containing all the image parameters. This information
	# is used to create the .profile environment
	# ---
	my $this = shift;
	my %result;
	my @nodelist;
	#==========================================
	# revision information
	#------------------------------------------
	my $rev  = "unknown";
	if (open (my $FD, '<', $this->{gdata}->{Revision})) {
		$rev = <$FD>; close $FD;
		$rev =~ s/\n//g;
	}
	$result{kiwi_revision} = $rev;
	#==========================================
	# bootincluded items (packs,archives)
	#------------------------------------------
	my @bincl = $this -> getBootIncludes();
	if (@bincl) {
		$result{kiwi_fixedpackbootincludes} = join(" ",@bincl);
	}
	#==========================================
	# preferences attributes and text elements
	#------------------------------------------
	my %type  = %{$this->getImageTypeAndAttributes()};
	my @delp  = $this -> getDeleteList();
	my $iver  = getImageVersion ($this);
	my $size  = getImageSize    ($this);
	my $name  = getImageName    ($this);
	my $dname = getImageDisplayName ($this);
	my $lics  = getLicenseNames ($this);
	my @s_del = $this -> getStripDelete();
	my @s_tool= $this -> getStripTools();
	my @s_lib = $this -> getStripLibs();
	my @tstp  = $this -> getTestingList();
	if ($lics) {
		$result{kiwi_showlicense} = join(" ",@{$lics});
	}
	if (@delp) {
		$result{kiwi_delete} = join(" ",@delp);
	}
	if (@s_del) {
		$result{kiwi_strip_delete} = join(" ",@s_del);
	}
	if (@s_tool) {
		$result{kiwi_strip_tools} = join(" ",@s_tool);
	}
	if (@s_lib) {
		$result{kiwi_strip_libs} = join(" ",@s_lib);
	}
	if (@tstp) {
		$result{kiwi_testing} = join(" ",@tstp);
	}
	if ((%type)
		&& (defined $type{compressed})
		&& ($type{compressed} eq "true")) {
		$result{kiwi_compressed} = "yes";
	}
	if (%type) {
		$result{kiwi_type} = $type{type};
	}
	if ((%type) && ($type{cmdline})) {
		$result{kiwi_cmdline} = $type{cmdline};
	}
	if ((%type) && ($type{bootloader})) {
		$result{kiwi_bootloader} = $type{bootloader};
	}
	if ((%type) && ($type{devicepersistency})) {
		$result{kiwi_devicepersistency} = $type{devicepersistency};
	}
	if ((%type) && (defined $type{boottimeout})) {
		$result{KIWI_BOOT_TIMEOUT} = $type{boottimeout};
	}
	if ((%type) && ($type{installboot})) {
		$result{kiwi_installboot} = $type{installboot};
	}
	if ((%type)
		&& (defined $type{luks})
		&& ($type{luks} eq "true")) {
		$result{kiwi_luks} = "yes";
	}
	if ((%type)
		&& (defined $type{hybrid})
		&& ($type{hybrid} eq "true")) {
		$result{kiwi_hybrid} = "yes";
	}
	if ((%type)
		&& (defined $type{hybridpersistent})
		&& ($type{hybridpersistent} eq "true")) {
		$result{kiwi_hybridpersistent} = "yes";
	}
	if ((%type)
		&& (defined $type{ramonly})
		&& ($type{ramonly} eq "true")) {
		$result{kiwi_ramonly} = "yes";
	}
	if ((%type) && ($type{lvm})) {
		$result{kiwi_lvm} = $type{lvm};
	}
	if ($size) {
		$result{kiwi_size} = $size;
	}
	if ($name) {
		$result{kiwi_iname} = $name;
	}
	if ($dname) {
		$result{kiwi_displayname} = quotemeta $dname;
	}
	if ($iver) {
		$result{kiwi_iversion} = $iver;
	}
	@nodelist = $this->{optionsNodeList} -> get_nodelist();
	foreach my $element (@nodelist) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $keytable = $element -> getElementsByTagName ("keytable");
		my $timezone = $element -> getElementsByTagName ("timezone");
		my $hwclock  = $element -> getElementsByTagName ("hwclock");
		my $language = $element -> getElementsByTagName ("locale");
		my $boottheme= $element -> getElementsByTagName ("boot-theme");
		if ((defined $keytable) && ("$keytable" ne "")) {
			$result{kiwi_keytable} = $keytable;
		}
		if ((defined $timezone) && ("$timezone" ne "")) {
			$result{kiwi_timezone} = $timezone;
		}
		if ((defined $hwclock) && ("$hwclock" ne "")) {
			$result{kiwi_hwclock} = $hwclock;
		}
		if ((defined $language) && ("$language" ne "")) {
			$result{kiwi_language} = $language;
		}
		if ((defined $boottheme) && ("$boottheme" ne "")) {
			$result{kiwi_boottheme}= $boottheme;
		}
	}
	#==========================================
	# drivers
	#------------------------------------------
	@nodelist = $this->{driversNodeList} -> get_nodelist();
	foreach my $element (@nodelist) {
		my $type = $element -> getAttribute("type");
		$type = "kiwi_".$type;
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my @ntag = $element -> getElementsByTagName ("file");
		my $data = "";
		my $prefix = "";
		if ($type ne "kiwi_drivers") {
			$prefix = "drivers/";
		}
		foreach my $element (@ntag) {
			my $name =  $element -> getAttribute ("name");
			$data = $data.",".$prefix.$name;
		}
		$data =~ s/^,+//;
		if (defined $result{$type}) {
			$result{$type} .= ",".$data;
		} else {
			$result{$type} = $data;
		}
	}
	#==========================================
	# machine
	#------------------------------------------
	my $xendomain = $this -> getXenDomain();
	if (defined $xendomain) {
		$result{kiwi_xendomain} = $xendomain;
	}
	#==========================================
	# systemdisk
	#------------------------------------------
	my $allFreeVolume = $this -> getAllFreeVolume();
	if (defined $allFreeVolume) {
		$allFreeVolume =~ s/^\///;
		$allFreeVolume =~ s/\//_/g;
		$allFreeVolume = "LV".$allFreeVolume;
		$result{kiwi_allFreeVolume} = $allFreeVolume;
	}
	#==========================================
	# oemconfig
	#------------------------------------------
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (defined $node) {
		my $oemswapMB= $node
			-> getElementsByTagName ("oem-swapsize");
		my $oemrootMB= $node
			-> getElementsByTagName ("oem-systemsize");
		my $oemswap  = $node
			-> getElementsByTagName ("oem-swap");
		my $oemalign = $node
			-> getElementsByTagName ("oem-align-partition");
		my $oempinst = $node
			-> getElementsByTagName ("oem-partition-install");
		my $oemtitle = $node
			-> getElementsByTagName ("oem-boot-title");
		my $oemkboot = $node
			-> getElementsByTagName ("oem-kiwi-initrd");
		my $oemreboot= $node
			-> getElementsByTagName ("oem-reboot");
		my $oemrebootinter= $node
			-> getElementsByTagName ("oem-reboot-interactive");
		my $oemsilentboot = $node
			-> getElementsByTagName ("oem-silent-boot");
		my $oemshutdown= $node
			-> getElementsByTagName ("oem-shutdown");
		my $oemshutdowninter= $node
			-> getElementsByTagName ("oem-shutdown-interactive");
		my $oemwait  = $node
			-> getElementsByTagName ("oem-bootwait");
		my $oemnomsg = $node
			-> getElementsByTagName ("oem-unattended");
		my $oemdevid = $node
			-> getElementsByTagName ("oem-unattended-id");
		my $oemreco  = $node
			-> getElementsByTagName ("oem-recovery");
		my $oemrecoid= $node
			-> getElementsByTagName ("oem-recoveryID");
		my $inplace  = $node
			-> getElementsByTagName ("oem-inplace-recovery");
		if ((defined $oempinst) && ("$oempinst" eq "true")) {
			$result{kiwi_oempartition_install} = $oempinst;
		}
		if ("$oemswap" ne "false") {
			$result{kiwi_oemswap} = "true";
			if ((defined $oemswapMB) && 
				("$oemswapMB" ne "")   && 
				(int($oemswapMB) > 0)
			) {
				$result{kiwi_oemswapMB} = $oemswapMB;
			}
		}
		if ((defined $oemalign) && ("$oemalign" eq "true")) {
			$result{kiwi_oemalign} = $oemalign;
		}
		if ((defined $oemrootMB) && 
			("$oemrootMB" ne "")   && 
			(int($oemrootMB) > 0)
		) {
			$result{kiwi_oemrootMB} = $oemrootMB;
		}
		if ((defined $oemtitle) && ("$oemtitle" ne "")) {
			$result{kiwi_oemtitle} = $this -> __quote ($oemtitle);
		}
		if ((defined $oemkboot) && ("$oemkboot" ne "")) {
			$result{kiwi_oemkboot} = $oemkboot;
		}
		if ((defined $oemreboot) && ("$oemreboot" eq "true")) {
			$result{kiwi_oemreboot} = $oemreboot;
		}
		if ((defined $oemrebootinter) && ("$oemrebootinter" eq "true")) {
			$result{kiwi_oemrebootinteractive} = $oemrebootinter;
		}
		if ((defined $oemsilentboot) && ("$oemsilentboot" eq "true")) {
			$result{kiwi_oemsilentboot} = $oemsilentboot;
		}
		if ((defined $oemshutdown) && ("$oemshutdown" eq "true")) {
			$result{kiwi_oemshutdown} = $oemshutdown;
		}
		if ((defined $oemshutdowninter) && ("$oemshutdowninter" eq "true")) {
			$result{kiwi_oemshutdowninteractive} = $oemshutdowninter;
		}
		if ((defined $oemwait) && ("$oemwait" eq "true")) {
			$result{kiwi_oembootwait} = $oemwait;
		}
		if ((defined $oemnomsg) && ("$oemnomsg" eq "true")) {
			$result{kiwi_oemunattended} = $oemnomsg;
		}
		if ((defined $oemdevid) && ("$oemdevid" ne "")) {
			$result{kiwi_oemunattended_id} = $oemdevid;
		}
		if ((defined $oemreco) && ("$oemreco" eq "true")) {
			$result{kiwi_oemrecovery} = $oemreco;
		}
		if ((defined $oemrecoid) && ("$oemrecoid" ne "")) {
			$result{kiwi_oemrecoveryID} = $oemrecoid;
		}
		if ((defined $inplace) && ("$inplace" eq "true")) {
			$result{kiwi_oemrecoveryInPlace} = $inplace;
		}
	}
	#==========================================
	# profiles
	#------------------------------------------
	if (defined $this->{reqProfiles}) {
		$result{kiwi_profiles} = join ",", @{$this->{reqProfiles}};
	}
	return %result;
}

#==========================================
# getPackageAttributes
#------------------------------------------
sub getPackageAttributes {
	# ...
	# Create an attribute hash from the given
	# package category.
	# ---
	my $this = shift;
	my $what = shift;
	my $kiwi = $this->{kiwi};
	my @node = $this->{packageNodeList} -> get_nodelist();
	my %result;
	$result{patternType} = "onlyRequired";
	$result{type} = $what;
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $type = $element -> getAttribute ("type");
		if ($type ne $what) {
			next;
		}
		my $ptype = $element -> getAttribute ("patternType");
		if ($ptype) {
			$result{patternType} = $ptype;
			$result{type} = $type;
		}
	}
	return %result;
}

#==========================================
# getLVMGroupName
#------------------------------------------
sub getLVMGroupName {
	# ...
	# Return the name of the volume group if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	if (! defined $node) {
		return;
	}
	return $node -> getAttribute ("name");
}

#==========================================
# getAllFreeVolume
#------------------------------------------
sub getAllFreeVolume {
	# ...
	# search the volume list if there is one volume which
	# has the freespace="all" attribute set. By default
	# LVRoot is the volume which gets all free space
	# assigned
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $allFree = "Root";
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	if (! defined $node) {
		return $allFree;
	}
	my @vollist = $node -> getElementsByTagName ("volume");
	foreach my $volume (@vollist) {
		my $name = $volume -> getAttribute ("name");
		my $free = $volume -> getAttribute ("freespace");
		if ((defined $free) && ($free eq "all")) {
			$allFree = $name;
			last;
		}
	}
	return $allFree;
}

#==========================================
# getLVMVolumes
#------------------------------------------
sub getLVMVolumes {
	# ...
	# Create list of LVM volume names for sub volume
	# setup. Each volume name will end up in an own
	# LVM volume when the LVM setup is requested
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	my %result = ();
	if (! defined $node) {
		return %result;
	}
	my @vollist = $node -> getElementsByTagName ("volume");
	foreach my $volume (@vollist) {
		my $name = $volume -> getAttribute ("name");
		my $free = $volume -> getAttribute ("freespace");
		my $size = $volume -> getAttribute ("size");
		my $haveAbsolute;
		my $usedValue;
		if ($size) {
			$haveAbsolute = 1;
			$usedValue = $size;
		} elsif (($free) && ($free ne "all")) {
			$usedValue = $free;
			$haveAbsolute = 0;
		}
		if (($usedValue) && ($usedValue =~ /(\d+)([MG]*)/)) {
			my $byte = int $1;
			my $unit = $2;
			if ($unit eq "G") {
				$usedValue = $byte * 1024;
			} else {
				# no or unknown unit, assume MB...
				$usedValue = $byte;
			}
		}
		$name =~ s/\s+//g;
		if ($name eq "/") {
			$kiwi -> warning ("LVM: Directory $name is not allowed");
			$kiwi -> skipped ();
			next;
		}
		$name =~ s/^\///;
		if ($name
			=~ /^(image|proc|sys|dev|boot|mnt|lib|bin|sbin|etc|lost\+found)/) {
			$kiwi -> warning ("LVM: Directory $name is not allowed");
			$kiwi -> skipped ();
			next;
		}
		$name =~ s/\//_/g;
		$result{$name} = [ $usedValue,$haveAbsolute ];
	}
	return %result;
}

#==========================================
# getEc2Config
#------------------------------------------
sub getEc2Config {
	# ...
	# Create a hash for the <ec2config>
	# section if it exists
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("ec2config") -> get_node(1);
	my %result = ();
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# AWS account Nr
	#------------------------------------------
	my $awsacctno = $node -> getElementsByTagName ("ec2accountnr");
	if ($awsacctno) {
		$result{AWSAccountNr} = $awsacctno;
	}
	#==========================================
	# EC2 path to public key file
	#------------------------------------------
	my $certfile = $node -> getElementsByTagName ("ec2certfile");
	if ($certfile) {
		$result{EC2CertFile} = $certfile;
	}
	#==========================================
	# EC2 path to private key file
	#------------------------------------------
	my $privkeyfile = $node -> getElementsByTagName ("ec2privatekeyfile");
	if ($privkeyfile) {
		$result{EC2PrivateKeyFile} = $privkeyfile;
	}
	#==========================================
	# EC2 region
	#------------------------------------------
	my @regionNodes = $node -> getElementsByTagName ("ec2region");
	my @regions = ();
	for my $regNode (@regionNodes) {
		push @regions, $regNode -> textContent();
	}
	$result{EC2Regions} = \@regions;
	return %result;
}

#==========================================
# getVMwareConfig
#------------------------------------------
sub getVMwareConfig {
	# ...
	# Create an Attribute hash from the <machine>
	# section if it exists suitable for the VMware configuration
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	my %result = ();
	my %guestos= ();
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $arch = $node -> getAttribute ("arch");
	if (! defined $arch) {
		$arch = "ix86";
	} elsif ($arch eq "%arch") {
		my $sysarch = qxx ("uname -m"); chomp $sysarch;
		if ($sysarch =~ /i.86/) {
			$arch = "ix86";
		} else {
			$arch = $sysarch;
		}
	}
	my $hwver= $node -> getAttribute ("HWversion");
	if (! defined $hwver) {
		$hwver = 4;
	}
	$guestos{suse}{ix86}     = "suse";
	$guestos{suse}{x86_64}   = "suse-64";
	$guestos{sles}{ix86}     = "sles";
	$guestos{sles}{x86_64}   = "sles-64";
	$guestos{rhel6}{x86_64}  = "rhel6-64";
	$guestos{rhel6}{ix86}    = "rhel6";
	$guestos{rhel5}{x86_64}  = "rhel5-64";
	$guestos{rhel5}{ix86}    = "rhel5";
	$guestos{centos}{ix86}   = "centos";
	$guestos{centos}{x86_64} = "centos-64";
	my $guest= $node -> getAttribute ("guestOS");
	if ((!defined $guest) || (! defined $guestos{$guest}{$arch})) {
		if ($arch eq "ix86") {
			$guest = "suse";
		} else {
			$guest = "suse-64";
		}
	} else {
		$guest = $guestos{$guest}{$arch};
	}
	my $memory = $node -> getAttribute ("memory");
	my $ncpus  = $node -> getAttribute ("ncpus");
	#==========================================
	# storage setup disk
	#------------------------------------------
	my $disk = $node -> getElementsByTagName ("vmdisk");
	my ($type,$id);
	if ($disk) {
		my $node = $disk -> get_node(1);
		$type = $node -> getAttribute ("controller");
		$id   = $node -> getAttribute ("id");
	}
	#==========================================
	# storage setup CD rom
	#------------------------------------------
	my $cd = $node -> getElementsByTagName ("vmdvd");
	my ($cdtype,$cdid);
	if ($cd) {
		my $node = $cd -> get_node(1);
		$cdtype = $node -> getAttribute ("controller");
		$cdid   = $node -> getAttribute ("id");
	}
	#==========================================
	# network setup
	#------------------------------------------
	my $nic  = $node -> getElementsByTagName ("vmnic");
	my %vmnics;
	for (my $i=1; $i<= $nic->size(); $i++) {
		my $node = $nic  -> get_node($i);
		$vmnics{$node -> getAttribute ("interface")} =
		{
			drv  => $node -> getAttribute ("driver"),
			mode => $node -> getAttribute ("mode")
		};
	}
	#==========================================
	# configuration file settings
	#------------------------------------------
	my @vmConfigOpts = $this -> getVMConfigOpts();
	#==========================================
	# save hash
	#------------------------------------------
	$result{vmware_arch}  = $arch;
	if (@vmConfigOpts) {
		$result{vmware_config} = \@vmConfigOpts;
	}
	$result{vmware_hwver} = $hwver;
	$result{vmware_guest} = $guest;
	$result{vmware_memory}= $memory;
	$result{vmware_ncpus} = $ncpus;
	if ($disk) {
		$result{vmware_disktype} = $type;
		$result{vmware_diskid}   = $id;
	}
	if ($cd) {
		$result{vmware_cdtype} = $cdtype;
		$result{vmware_cdid}   = $cdid;
	}
	if (%vmnics) {
		$result{vmware_nic}= \%vmnics;
	}
	return %result;
}

#==========================================
# getXenConfig
#------------------------------------------
sub getXenConfig {
	# ...
	# Create an Attribute hash from the <machine>
	# section if it exists suitable for the xen domU configuration
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	my %result = ();
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $memory = $node -> getAttribute ("memory");
	my $ncpus  = $node -> getAttribute ("ncpus");
	my $domain = $node -> getAttribute ("domain");
	#==========================================
	# storage setup
	#------------------------------------------
	my $disk = $node -> getElementsByTagName ("vmdisk");
	my ($device);
	if ($disk) {
		my $node  = $disk -> get_node(1);
		$device= $node -> getAttribute ("device");
	}
	#==========================================
	# network setup (bridge)
	#------------------------------------------
	my $bridges = $node -> getElementsByTagName ("vmnic");
	my %vifs = ();
	for (my $i=1;$i<= $bridges->size();$i++) {
		my $bridge = $bridges -> get_node($i);
		if ($bridge) {
			my $mac   = $bridge -> getAttribute ("mac");
			my $bname = $bridge -> getAttribute ("interface");
			if (! $bname) {
				$bname = "undef";
			}
			$vifs{$bname} = $mac;
		}
	}
	#==========================================
	# configuration file settings
	#------------------------------------------
	my @vmConfigOpts = $this -> getVMConfigOpts();
	#==========================================
	# save hash
	#------------------------------------------
	if (@vmConfigOpts) {
		$result{xen_config} = \@vmConfigOpts
	}
	$result{xen_memory}= $memory;
	$result{xen_ncpus} = $ncpus;
	$result{xen_domain}= $domain;
	if ($disk) {
		$result{xen_diskdevice} = $device;
	}
	foreach my $bname (keys %vifs) {
		$result{xen_bridge}{$bname} = $vifs{$bname};
	}
	return %result;
}

#==========================================
# getOVFConfig
#------------------------------------------
sub getOVFConfig {
	# ...
	# Create an Attribute hash from the <machine>
	# section if it exists suitable for the OVM
	# configuration
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	my %result = ();
	my $device;
	my $disktype;
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $minmemory = $node -> getAttribute ("min_memory");
	my $desmemory = $node -> getAttribute ("des_memory");
	my $maxmemory = $node -> getAttribute ("max_memory");
	my $memory    = $node -> getAttribute ("memory");
	my $ncpus     = $node -> getAttribute ("ncpus");
	my $mincpu    = $node -> getAttribute ("min_cpu");
	my $descpu    = $node -> getAttribute ("des_cpu");
	my $maxcpu    = $node -> getAttribute ("max_cpu");
	my $type      = $node -> getAttribute ("ovftype");
	#==========================================
	# storage setup
	#------------------------------------------
	my $disk = $node -> getElementsByTagName ("vmdisk");
	if ($disk) {
		my $node  = $disk -> get_node(1);
		$device = $node -> getAttribute ("device");
		$disktype = $node -> getAttribute ("disktype");
	}
	#==========================================
	# network setup
	#------------------------------------------
	my $bridges = $node -> getElementsByTagName ("vmnic");
	my %vifs = ();
	for (my $i=1;$i<= $bridges->size();$i++) {
		my $bridge = $bridges -> get_node($i);
		if ($bridge) {
			my $bname = $bridge -> getAttribute ("interface");
			if (! $bname) {
				$bname = "undef";
			}
			$vifs{$bname} = $i;
		}
	}
	#==========================================
	# save hash
	#------------------------------------------
	$result{ovf_minmemory} = $minmemory;
	$result{ovf_desmemory} = $desmemory;
	$result{ovf_maxmemory} = $maxmemory;
	$result{ovf_memory}    = $memory;
	$result{ovf_ncpus}     = $ncpus;
	$result{ovf_mincpu}    = $mincpu;
	$result{ovf_descpu}    = $descpu;
	$result{ovf_maxcpu}    = $maxcpu;
	$result{ovf_type}      = $type;
	if ($disk) {
		$result{ovf_disk}    = $device;
		$result{ovf_disktype}= $disktype;
	}
	foreach my $bname (keys %vifs) {
		$result{ovf_bridge}{$bname} = $vifs{$bname};
	}
	return %result;
}

#==========================================
# getInstSourcePackageAttributes
#------------------------------------------
sub getInstSourcePackageAttributes {
	# ...
	# Create an attribute hash for the given package
	# and package category.
	# ---
	my $this = shift;
	my $what = shift;
	my $pack = shift;
	my $nodes;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	if ($what eq "metapackages") {
		$nodes = $base -> getElementsByTagName ("metadata");
	} elsif ($what eq "instpackages") {
		$nodes = $base -> getElementsByTagName ("repopackages");
	} elsif ($what eq "DUDmodules") {
		$nodes = $base -> getElementsByTagName("driverupdate")
			-> get_node(1) -> getElementsByTagName('modules');
	} elsif ($what eq "DUDinstall") {
		$nodes = $base -> getElementsByTagName("driverupdate")
			-> get_node(1) -> getElementsByTagName('install');
	} elsif ($what eq "DUDinstsys") {
		$nodes = $base -> getElementsByTagName("driverupdate")
			-> get_node(1) -> getElementsByTagName('instsys');
	}
	my %result;
	my @attrib = (
		"forcerepo" ,"addarch", "removearch", "arch",
		"onlyarch", "version", "source", "script", "medium"
	);
	if(not defined($this->{m_rpacks})) {
		my @nodes = ();
		for (my $i=1;$i<= $nodes->size();$i++) {
			my $node  = $nodes -> get_node($i);
			my @plist = $node  -> getElementsByTagName ("repopackage");
			push @nodes, @plist;
		}
		%{$this->{m_rpacks}} = map {$_->getAttribute("name") => $_} @nodes;
	}
	my $elem = $this->{m_rpacks}->{$pack};
	if(defined($elem)) {
		foreach my $key (@attrib) {
			my $value = $elem -> getAttribute ($key);
			if (defined $value) {
				$result{$key} = $value;
			}
		}
	}
	return \%result;
}

#==========================================
# clearPackageAttributes
#------------------------------------------
sub clearPackageAttributes {
	my $this = shift;
	$this->{m_rpacks} = undef;
}

#==========================================
# isArchAllowed
#------------------------------------------
sub isArchAllowed {
	my $this    = shift;
	my $element = shift;
	my $what    = shift;
	my $forarch = $element -> getAttribute ("arch");
	if (($what eq "metapackages") || ($what eq "instpackages")) {
		# /.../
		# arch setup is differently handled
		# in inst-source mode
		# ----
		return $this;
	}
	if (defined $forarch) {
		my @archlst = split (/,/,$forarch);
		my $foundit = 0;
		foreach my $archok (@archlst) {
			if ($archok eq $this->{arch}) {
				$foundit = 1; last;
			}
		}
		if (! $foundit) {
			return;
		}
	}
	return $this;
}

#==========================================
# getListBootIncludes
#------------------------------------------
sub getListBootIncludes {
	# ...
	# Return list of packages from image and bootstrap typed
	# packages sections which are flaged as bootinclude
	# ---
	my $this  = shift;
	my $nodes = $this->{packageNodeList};
	my @result;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node  = $nodes -> get_node($i);
		my $type = $node -> getAttribute ("type");
		#============================================
		# Check to see if node is in included profile
		#--------------------------------------------
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		if (($type ne "bootstrap") && ($type ne "image")) {
			next;
		}
		my @plist = $node -> getElementsByTagName ("package");
		foreach my $element (@plist) {
			my $package = $element -> getAttribute ("name");
			my $bootinc = $element -> getAttribute ("bootinclude");
			if (($bootinc) && ($bootinc eq "true")) {
				push @result,$package
			}
		}
	}
	return @result;
}

#==========================================
# getList
#------------------------------------------
sub getList {
	# ...
	# Create a package list out of the given base xml
	# object list. The xml objects are searched for the
	# attribute "name" to build up the package list.
	# Each entry must be found on the source medium
	# ---
	my $this = shift;
	my $what = shift;
	my $nopac= shift;
	my $kiwi = $this->{kiwi};
	my $urllist = $this -> getURLList();
	my %pattr;
	my $nodes;
	if ($what ne "metapackages") {
		%pattr= $this -> getPackageAttributes ( $what );
	}
	if ($what eq "metapackages") {
		my $base = $this->{instsrcNodeList} -> get_node(1);
		$nodes = $base -> getElementsByTagName ("metadata");
	} elsif ($what eq "instpackages") {
		my $base = $this->{instsrcNodeList} -> get_node(1);
		$nodes = $base -> getElementsByTagName ("repopackages");
	} else {
		$nodes = $this->{packageNodeList};
	}
	my @result;
	my $manager = $this -> getPackageManager();
	for (my $i=1;$i<= $nodes->size();$i++) {
		#==========================================
		# Get type and packages
		#------------------------------------------
		my $node  = $nodes -> get_node($i);
		my $ptype = $node -> getAttribute ("patternType");
		my $type  = "";
		if (($what ne "metapackages") && ($what ne "instpackages")) {
			$type = $node -> getAttribute ("type");
			if ($type ne $what) {
				next;
			}
		} else {
			$type = $what;
		}
		#============================================
		# Check to see if node is in included profile
		#--------------------------------------------
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		#==========================================
		# Check for package descriptions
		#------------------------------------------
		my @plist = ();
		if (($what ne "metapackages") && ($what ne "instpackages")) {
			if (defined $nopac) {
				@plist = $node -> getElementsByTagName ("archive");
			} else {
				@plist = $node -> getElementsByTagName ("package");
			}
		} else {
			@plist = $node -> getElementsByTagName ("repopackage");
		}
		foreach my $element (@plist) {
			my $package = $element -> getAttribute ("name");
			my $forarch = $element -> getAttribute ("arch");
			my $replaces= $element -> getAttribute ("replaces");
			if (! $this -> isArchAllowed ($element,$what)) {
				next;
			}
			if (! defined $package) {
				next;
			}
			if ($type ne "metapackages" && $type ne "instpackages") {
				if (($package =~ /@/) && $manager && ($manager eq "zypper")) {
					$package =~ s/@/\./;
				}
			}
			if (defined $replaces) {
				push @result,[$package,$replaces];
			}
			push @result,$package;
		}
		#==========================================
		# Check for pattern descriptions
		#------------------------------------------
		if (($type ne "metapackages") && (! defined $nopac)) {
			my @pattlist = ();
			my @slist = $node -> getElementsByTagName ("opensuseProduct");
			foreach my $element (@slist) {
				if (! $this -> isArchAllowed ($element,$type)) {
					next;
				}
				my $product = $element -> getAttribute ("name");
				if (! defined $product) {
					next;
				}
				push @pattlist,"product:".$product;
			}
			@slist = ();
			my @slist_suse = $node -> getElementsByTagName ("opensusePattern");
			my @slist_rhel = $node -> getElementsByTagName ("rhelGroup");
			if (@slist_suse) {
				push @slist,@slist_suse;
			}
			if (@slist_rhel) {
				push @slist,@slist_rhel; 
			}
			foreach my $element (@slist) {
				if (! $this -> isArchAllowed ($element,$type)) {
					next;
				}
				my $pattern = $element -> getAttribute ("name");
				if (! defined $pattern) {
					next;
				}
				push @pattlist,"pattern:".$pattern;
			}
			if (@pattlist) {
				if (($manager eq "ensconce")) {
					# nothing to do for ensconce here...
				} elsif (($manager ne "zypper") && ($manager ne "yum")) {
					#==========================================
					# turn patterns into pacs for this manager
					#------------------------------------------
					# 1) try to use libsatsolver...
					my $psolve = new KIWISatSolver (
						$kiwi,\@pattlist,$urllist,"solve-patterns",
						undef,undef,$ptype
					);
					if (! defined $psolve) {
						$kiwi -> error (
							"SaT solver setup failed, patterns can't be solved"
						);
						$kiwi -> skipped ();
						return ();
					}
					if (! defined $psolve) {
						my $pp ="Pattern or product";
						my $e1 ="$pp match failed for arch: $this->{arch}";
						my $e2 ="Check if the $pp is written correctly?";
						my $e3 ="Check if the arch is provided by the repo(s)?";
						$kiwi -> warning ("$e1\n");
						$kiwi -> warning ("    a) $e2\n");
						$kiwi -> warning ("    b) $e3\n");
						return ();
					}
					my @packageList = $psolve -> getPackages();
					push @result,@packageList;
				} else {
					#==========================================
					# zypper/yum knows about patterns/groups
					#------------------------------------------
					foreach my $pname (@pattlist) {
						$kiwi -> info ("--> Requesting $pname");
						push @result,$pname;
						$kiwi -> done();
					}
				}
			}
		}
		#==========================================
		# Check for ignore list
		#------------------------------------------
		if (! defined $nopac) {
			my @ilist = $node -> getElementsByTagName ("ignore");
			my @ignorelist = ();
			foreach my $element (@ilist) {
				my $ignore = $element -> getAttribute ("name");
				if (! defined $ignore) {
					next;
				}
				if (($ignore =~ /@/) && ($manager eq "zypper")) {
					$ignore =~ s/@/\./;
				}
				push @ignorelist,$ignore;
			}
			if (@ignorelist) {
				my @newlist = ();
				foreach my $element (@result) {
					my $pass = 1;
					foreach my $ignore (@ignorelist) {
						if ($element eq $ignore) {
							$pass = 0; last;
						}
					}
					if (! $pass) {
						next;
					}
					push @newlist,$element;
				}
				@result = @newlist;
			}
		}
	}
	#==========================================
	# Create unique lists
	#------------------------------------------
	my %packHash = ();
	my @replAddList = ();
	my @replDelList = ();
	foreach my $package (@result) {
		if (ref $package) {
			push @replAddList,$package->[0];
			push @replDelList,$package->[1];
		} else {
			$packHash{$package} = $package;
		}
	}
	$this->{replDelList} = \@replDelList;
	$this->{replAddList} = \@replAddList;
	my @ordered = sort keys %packHash;
	return @ordered;
}

#==========================================
# isDriverUpdateDisk
#------------------------------------------
sub isDriverUpdateDisk {
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	return ref $dud_node;
}

#==========================================
# getInstSourceDUDTargets
#------------------------------------------
sub getInstSourceDUDTargets {
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	my %targets = ();
	foreach my $target ($dud_node->getElementsByTagName('target')) {
		$targets{$target->textContent()} = $target->getAttribute("arch");
	}
	return %targets;
}

#==========================================
# getInstSourceDUDConfig
#------------------------------------------
sub getInstSourceDUDConfig {
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	my @config = $dud_node->getElementsByTagName('config');
	my %data;
	foreach my $cfg (@config) {
		$data{$cfg->getAttribute("key")} = $cfg->getAttribute("value");
	}
	return \%data;
}

#==========================================
# getInstSourceDUDModules
#------------------------------------------
sub getInstSourceDUDModules {
	my $this = shift;
	return $this->getInstSourceDUDPackList('modules');
}

#==========================================
# getInstSourceDUDInstall
#------------------------------------------
sub getInstSourceDUDInstall {
	my $this = shift;
	return $this->getInstSourceDUDPackList('install');
}

#==========================================
# getInstSourceDUDInstsys
#------------------------------------------
sub getInstSourceDUDInstsys {
	my $this = shift;
	return $this->getInstSourceDUDPackList('instsys');
}

#==========================================
# getInstSourceDUDPackList
#------------------------------------------
sub getInstSourceDUDPackList {
	my $this = shift;
	my $what = shift;
	return unless $what;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	my $modules_node = $dud_node->getElementsByTagName($what)->get_node(1);
	my @module_packs = $modules_node->getElementsByTagName('repopackage');
	my @modules;
	foreach my $mod (@module_packs) {
		push @modules, $mod->getAttribute("name");
	}
	return @modules;
}

#==========================================
# getInstallSize
#------------------------------------------
sub getInstallSize {
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $nodes   = $this->{packageNodeList};
	my $manager = $this->getPackageManager();
	my $urllist = $this -> getURLList();
	my @result  = ();
	my @delete  = ();
	my @packages= ();
	my %meta    = ();
	my $solf    = undef;
	my @solp    = ();
	my @rpat    = ();
	my $ptype;
	#==========================================
	# Handle package names to be included
	#------------------------------------------
	@packages = $this -> getBaseList();
	push @result,@packages;
	@packages = $this -> getInstallList();
	push @result,@packages;
	@packages = $this -> getTypeList();
	push @result,@packages;
	#==========================================
	# Handle package names to be deleted later
	#------------------------------------------
	@delete = $this -> getDeleteList();
	#==========================================
	# Handle pattern names
	#------------------------------------------
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		my @pattlist = ();
		my @slist = $node -> getElementsByTagName ("opensusePattern");
		foreach my $element (@slist) {
			if (! $this -> isArchAllowed ($element,"packages")) {
				next;
			}
			my $pattern = $element -> getAttribute ("name");
			if ($pattern) {
				push @result,"pattern:".$pattern;
			}
		}
	}
	#==========================================
	# Add packagemanager in any case
	#------------------------------------------
	push @result, $manager;
	#==========================================
	# Run the solver...
	#------------------------------------------
	if (($manager) && ($manager eq "ensconce")) {
		my $list = qxx ("ensconce -d");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error (
				"Error retrieving package metadata from ensconce."
			);
			return;
		}
		# Violates Expression form of "eval" FIXME
		%meta = eval($list); ## no critic
		@solp = keys(%meta);
		# Ensconce reports package sizes in bytes, fix that
		foreach my $pkg (keys(%meta)) {
			$meta{$pkg} =~ s#^(\d+)#int($1/1024)#e;
		}
	} else {
		my $psolve = new KIWISatSolver (
			$kiwi,\@result,$urllist,"solve-patterns",
			undef,undef,$ptype
		);
		if (! defined $psolve) {
			$kiwi -> error ("SaT solver setup failed");
			return;
		}
		if ($psolve -> getProblemsCount()) {
			$kiwi -> error ("SaT solver problems found !\n");
			return;
		}
		if (@{$psolve -> getFailedJobs()}) {
			$kiwi -> error ("SaT solver failed jobs found !");
			return;
		}
		%meta = $psolve -> getMetaData();
		$solf = $psolve -> getSolfile();
		@solp = $psolve -> getPackages();
		@rpat = qxx (
			"dumpsolv $solf|grep 'solvable:name: pattern:'|cut -f4 -d :"
		);
		chomp @rpat;
	}
	return (\%meta,\@delete,$solf,\@result,\@solp,\@rpat);
}

#==========================================
# getReplacePackageDelList
#------------------------------------------
sub getReplacePackageDelList {
	# ...
	# return the package names which are deleted in
	# a replace list setup
	# ---
	my $this = shift;
	my @pacs = @{$this->{replDelList}};
	return @pacs;
}

#==========================================
# getReplacePackageAddList
#------------------------------------------
sub getReplacePackageAddList {
	# ...
	# return the package names which are added in
	# a replace list setup
	# ---
	my $this = shift;
	my @pacs = @{$this->{replAddList}};
	return @pacs;
}

#==========================================
# getInstSourceMetaPackageList
#------------------------------------------
sub getInstSourceMetaPackageList {
	# ...
	# Create base package list of the instsource
	# metadata package description
	# ---
	my $this = shift;
	my @list = getList ($this,"metapackages");
	my %data = ();
	foreach my $pack (@list) {
		my $attr = $this -> getInstSourcePackageAttributes (
			"metapackages",$pack
		);
		$data{$pack} = $attr;
	}
	return %data;
}

#==========================================
# getInstSourcePackageList
#------------------------------------------
sub getInstSourcePackageList {
	# ...
	# Create base package list of the instsource
	# packages package description
	# ---
	my $this = shift;
	my @list = getList ($this,"instpackages");
	my %data = ();
	foreach my $pack (@list) {
		my $attr = $this -> getInstSourcePackageAttributes (
			"instpackages",$pack
		);
		$data{$pack} = $attr;
	}
	return %data;
}

#==========================================
# getBaseList
#------------------------------------------
sub getBaseList {
	# ...
	# Create base package list needed to start creating
	# the physical extend. The packages in this list are
	# installed manually
	# ---
	my $this = shift;
	return getList ($this,"bootstrap");
}

#==========================================
# getDeleteList
#------------------------------------------
sub getDeleteList {
	# ...
	# Create delete package list which are packages
	# which have already been installed but could be
	# forced for deletion in images.sh. The KIWIConfig.sh
	# module provides a function to get the contents of
	# this list. KIWI will store the delete list as
	# .profile variable
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @inc  = getListBootIncludes ($this);
	my @del  = getList ($this,"delete");
	my @ret  = ();
	#==========================================
	# check delete list for conflicts
	#------------------------------------------
	foreach my $del (@del) {
		my $found = 0;
		foreach my $include (@inc) {
			if ($include eq $del) {
				$kiwi -> loginfo (
					"WARNING: package $del also found in install list\n"
				);
				$kiwi -> loginfo (
					"WARNING: package $del ignored in delete list\n"
				);
				$found = 1;
				last;
			}
		}
		next if $found;
		push @ret,$del;
	}
	return @ret;
}

#==========================================
# getTestingList
#------------------------------------------
sub getTestingList {
	# ...
	# Create package list with packages used for testing
	# the image integrity. The packages here are installed
	# temporary as long as the testsuite runs. After the
	# test runs they should be removed again
	# ---
	my $this = shift;
	return getList ($this,"testsuite");
}

#==========================================
# getInstallList
#------------------------------------------
sub getInstallList {
	# ...
	# Create install package list needed to blow up the
	# physical extend to what the image was designed for
	# ---
	my $this = shift;
	return getList ($this,"image");
}

#==========================================
# getTypeList
#------------------------------------------
sub getTypeList {
	# ...
	# Create package list according to the selected
	# image type
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $type = $node -> getAttribute("image");
	return getList ($this,$type);
}

#==========================================
# getArchiveList
#------------------------------------------
sub getArchiveList {
	# ...
	# Create list of <archive> elements. These names
	# references tarballs which must exist in the image
	# description directory
	# ---
	my $this = shift;
	my @bootarchives = getList ($this,"bootstrap","archive");
	my @imagearchive = getList ($this,"image","archive");
	return (@bootarchives,@imagearchive);
}

#==========================================
# getNodeList
#------------------------------------------
sub getNodeList {
	# ...
	# Return the current <repository> list which consists
	# of XML::LibXML::Element object pointers
	# ---
	my $this = shift;
	return $this->{repositNodeList};
}

#==========================================
# getDriversNodeList
#------------------------------------------
sub getDriversNodeList {
	# ...
	# Return a list of all <drivers> nodes. Each list member
	# is an XML::LibXML::Element object pointer
	# ---
	my $this = shift;
	return $this->{driversNodeList};
}

#==========================================
# getStripNodeList
#------------------------------------------
sub getStripNodeList {
	# ...
	# Return a list of all <strip> nodes. Each list member
	# is an XML::LibXML::Element object pointer
	# ---
	my $this = shift;
	return $this->{stripNodeList};
}

#==========================================
# getPackageNodeList
#------------------------------------------
sub getPackageNodeList {
	# ...
	# Return a list of all <packages> nodes. Each list member
	# is an XML::LibXML::Element object pointer
	# ---
	my $this = shift;
	return $this->{packageNodeList};
}

#==========================================
# resolveLink
#------------------------------------------
sub resolveLink {
	my $this = shift;
	my $data = $this -> resolveArchitectur ($_[0]);
	my $cdir = qxx ("pwd"); chomp $cdir;
	if (chdir $data) {
		my $pdir = qxx ("pwd"); chomp $pdir;
		chdir $cdir;
		return $pdir
	}
	return $data;
}

#========================================== 
# resolveArchitectur
#------------------------------------------
sub resolveArchitectur {
	my $this = shift;
	my $path = shift;
	my $arch = $this->{arch};
	if ($arch =~ /i.86/) {
		$arch = "i386";
	}
	$path =~ s/\%arch/$arch/;
	return $path;
}

#==========================================
# getInstSourceFile
#------------------------------------------
sub getInstSourceFile {
	# ...
	# download a file from a network or local location to
	# a given local path. It's possible to use regular expressions
	# in the source file specification
	# ---
	my $this    = shift;
	my $url     = shift;
	my $dest    = shift;
	my $dirname;
	my $basename;
	#==========================================
	# Check parameters
	#------------------------------------------
	if ((! defined $dest) || (! defined $url)) {
		return;
	}
	#==========================================
	# setup destination base and dir name
	#------------------------------------------
	if ($dest =~ /(^.*\/)(.*)/) {
		$dirname  = $1;
		$basename = $2;
		if (! $basename) {
			$url =~ /(^.*\/)(.*)/;
			$basename = $2;
		}
	} else {
		return;
	}
	#==========================================
	# check base and dir name
	#------------------------------------------
	if (! $basename) {
		return;
	}
	if (! -d $dirname) {
		return;
	}
	#==========================================
	# download file
	#------------------------------------------
	if ($url !~ /:\/\//) {
		# /.../
		# local files, make them a file:// url
		# ----
		$url = "file://".$url;
		$url =~ s{/{3,}}{//};
	}
	if ($url =~ /dir:\/\//) {
		# /.../
		# dir url, make them a file:// url
		# ----
		$url =~ s/^dir/file/;
	}
	# /.../
	# use lwp-download to manage the process.
	# if first download failed check the directory list with
	# a regular expression to find the file. After that repeat
	# the download
	# ----
	$dest = $dirname."/".$basename;
	my $data = qxx ("lwp-download $url $dest 2>&1");
	my $code = $? >> 8;
	if ($code == 0) {
		return $this;
	}
	if ($url =~ /(^.*\/)(.*)/) {
		my $location = $1;
		my $search   = $2;
		my $browser  = LWP::UserAgent -> new;
		my $request  = HTTP::Request  -> new (GET => $location);
		my $response;
		eval {
			$response = $browser  -> request ( $request );
		};
		if ($@) {
			return;
		}
		my $content  = $response -> content ();
		my @lines    = split (/\n/,$content);
		foreach my $line(@lines) {
			if ($line !~ /href=\"(.*)\"/) {
				next;
			}
			my $link = $1;
			if ($link =~ /$search/) {
				$url  = $location.$link;
				$data = qxx ("lwp-download $url $dest 2>&1");
				$code = $? >> 8;
				if ($code == 0) {
					return $this;
				}
			}
		}
		return;
	} else {
		return;
	}
	return $this;
}

#==========================================
# getInstSourceSatSolvable
#------------------------------------------
sub getInstSourceSatSolvable {
	# /.../
	# This function will return a hash containing the
	# solvable and repo url per repo
	# ----
	my $kiwi  = shift;
	my $repos = shift;
	my %index = ();
	#==========================================
	# create solvable/repo index
	#------------------------------------------
	foreach my $repo (@{$repos}) {
		my $solvable = getSingleInstSourceSatSolvable ($kiwi,$repo);
		if (! $solvable) {
			return;
		}
		# /.../
		# satsolver / or the perl binding truncates the name if
		# there is a ':' sign. No clue why so we replace : with
		# a space and replace it back in the KIWIXMLInfo module
		# when the information is printed on the screen
		# ----
		$repo =~ s/:/ /g;
		$index{$solvable} = $repo;
	}
	return \%index;
}

#==========================================
# getSingleInstSourceSatSolvable
#------------------------------------------
sub getSingleInstSourceSatSolvable {
	# /.../
	# This function will return an uncompressed solvable record
	# for the given URL. If it's required to create
	# this solvable because it doesn't exist on the repository
	# the satsolver toolkit is used and therefore required in
	# order to allow this function to work correctly
	# ----
	my $kiwi = shift;
	my $repo = shift;
	$kiwi -> info ("--> Loading $repo...");
	#==========================================
	# one of the following for repo metadata
	#------------------------------------------
	my %repoxml;
	$repoxml{"/suse/repodata/repomd.xml"} = "repoxml";
	$repoxml{"/repodata/repomd.xml"}      = "repoxml";
	#==========================================
	# one of the following for a base solvable
	#------------------------------------------
	my %distro;
	$distro{"/suse/setup/descr/packages.gz"} = "packages";
	$distro{"/suse/setup/descr/packages"}    = "packages";
	$distro{"/suse/repodata/primary.xml.gz"} = "distxml";
	$distro{"/repodata/primary.xml.gz"}      = "distxml";
	#==========================================
	# all existing pattern files
	#------------------------------------------
	my %patterns;
	$patterns{"/suse/setup/descr/patterns"} = "patterns";
	$patterns{"/repodata/patterns.xml.gz"}  = "projectxml";
	#==========================================
	# common data variables
	#------------------------------------------
	my $arch     = qxx ("uname -m"); chomp $arch;
	my $count    = 0;
	my $index    = 0;
	my @index    = ();
	my $error    = 0;
	my $RXML;
	#==========================================
	# check for sat tools
	#------------------------------------------
	if ((! -x "/usr/bin/mergesolv") ||
		(! -x "/usr/bin/susetags2solv") ||
		(! -x "/usr/bin/rpmmd2solv") ||
		(! -x "/usr/bin/rpms2solv")
	) {
		$kiwi -> failed ();
		$kiwi -> error  ("--> Can't find satsolver tools");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check/create cache directory
	#------------------------------------------
	my $sdir = "/var/cache/kiwi/satsolver";
	if (! -d $sdir) {
		my $data = qxx ("mkdir -p $sdir 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("--> Couldn't create cache dir: $data");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# check/create solvable index file
	#------------------------------------------
	push (@index,$repo);
	push (@index,$arch);
	@index = sort (@index);
	$index = join (":",@index);
	$index = qxx ("echo $index | md5sum | cut -f1 -d-");
	$index = $sdir."/".$index; chomp $index;
	$index=~ s/ +$//;
	if ((-f $index) && (! -f "$index.timestamp")) {
		$kiwi -> done();
		return $index;
	}
	#==========================================
	# find system architecture
	#------------------------------------------
	if ($arch =~ /^i.86/) {
		$arch = 'i.86';
	}
	my $destfile;
	my $scommand;
	#==========================================
	# download repo XML metadata
	#------------------------------------------
	my $repoMD = $sdir."/repomd.xml"; unlink $repoMD;
	foreach my $md (keys %repoxml) {
		if (KIWIXML::getInstSourceFile ($kiwi,$repo.$md,$repoMD)) {
			last if -e $repoMD;
		}
	}
	if (-e $repoMD) {
		if (! open ($RXML, '-|', "cat $repoMD")) {
			$kiwi -> failed ();
			$kiwi -> error ("--> Failed to open file $repoMD");
			$kiwi -> failed ();
			unlink $repoMD;
			return;
		}
		binmode $RXML;
		my $rxml = new XML::LibXML;
		my $tree = $rxml -> parse_fh ( $RXML );
		my $nodes= $tree -> getElementsByTagName ("data");
		my $primary;
		my $pattern;
		my $time;
		for (my $i=1;$i<= $nodes->size();$i++) {
			my $node = $nodes-> get_node($i);
			my $type = $node -> getAttribute ("type");
			if ($type eq "primary") {
				$primary = $node -> getElementsByTagName ("location")
					-> get_node(1) -> getAttribute ("href");
				$time = $node -> getElementsByTagName ("timestamp")
					-> get_node(1) -> string_value();
			}
			if ($type eq "patterns") {
				$pattern = $node -> getElementsByTagName ("location")
					-> get_node(1) -> getAttribute ("href");
			}
		}
		close $RXML;
		#==========================================
		# Compare the repo timestamp
		#------------------------------------------
		if (open (my $FD, '<', "$index.timestamp")) {
			my $curstamp = <$FD>; chomp $curstamp;
			if ($curstamp eq $time) {
				$kiwi -> done();
				unlink $repoMD;
				return $index;
			}
		}
		#==========================================
		# Store distro/pattern path
		#------------------------------------------
		my %newdistro   = ();
		my %newpatterns = ();
		if ($primary) {
			foreach my $key (keys %distro) {
				if ($distro{$key} ne "distxml") {
					$newdistro{$key} = $distro{$key};
				}
			}
			$newdistro{"/".$primary}      = "distxml";
			$newdistro{"/suse/".$primary} = "distxml";
		}
		if ($pattern) {
			foreach my $key (keys %patterns) {
				if ($patterns{$key} ne "projectxml") {
					$newpatterns{$key} = $patterns{$key};
				}
			}
			$newpatterns{"/".$pattern} = "projectxml";
		}
		if (%newdistro) {
			undef %distro;
			%distro = %newdistro;
		}
		if (%newpatterns) {
			undef %patterns;
			%patterns = %newpatterns;
		}
		#==========================================
		# Store new time stamp
		#------------------------------------------
		if (! open ($RXML, '>', "$index.timestamp")) {
			$kiwi -> failed ();
			$kiwi -> error ("--> Failed to create timestamp: $!");
			$kiwi -> failed ();
			unlink $repoMD;
			return;
		}
		print $RXML $time;
		close $RXML;
	}
	#==========================================
	# create repo info file
	#------------------------------------------
	if (open (my $FD, '>', "$index.info")) {
		print $FD $repo."\n";
		close $FD;
	}
	#==========================================
	# download distro solvable(s)
	#------------------------------------------
	my $foundDist = 0;
	$count++;
	foreach my $dist (keys %distro) {
		my $name = $distro{$dist};
		if ($dist =~ /\.gz$/) {
			$destfile = $sdir."/$name-".$count.".gz";
		} else {
			$destfile = $sdir."/$name-".$count;
		}
		if (KIWIXML::getInstSourceFile ($kiwi,$repo.$dist,$destfile)) {
			$foundDist = 1;
		}
	}
	if (! $foundDist) {
		my $path = $repo; $path =~ s/dir:\/\///;
		my $data = qxx ("rpms2solv $path/*.rpm > $sdir/primary-$count 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("--> Can't find/create a distribution solvable");
			$kiwi -> failed ();
			return;
		}
		$foundDist = 1;
	}
	#==========================================
	# download pattern solvable(s)
	#------------------------------------------
	$count++;
	foreach my $patt (keys %patterns) {
		my $name = $patterns{$patt};
		$destfile = $sdir."/$name-".$count.".gz";
		my $ok = KIWIXML::getInstSourceFile ($kiwi,$repo.$patt,$destfile);
		if (($ok) && ($name eq "patterns")) {
			#==========================================
			# get files listed in patterns
			#------------------------------------------
			my $FD;
			my $patfile = $destfile;
			if (! open ($FD, '<', $patfile)) {
				$kiwi -> warning ("--> Couldn't open patterns file: $!");
				$kiwi -> skipped ();
				unlink $patfile;
				next;
			}
			foreach my $line (<$FD>) {
				chomp $line; $destfile = $sdir."/".$line;
				if ($line !~ /\.$arch\./) {
					next;
				}
				my $base = dirname $patt;
				my $file = $repo."/".$base."/".$line;
				if (! KIWIXML::getInstSourceFile($kiwi,$file,$destfile)) {
					$kiwi -> warning ("--> Pattern file $line not found");
					$kiwi -> skipped ();
					next;
				}
			}
			close $FD;
			unlink $patfile;
		}
	}
	$count++;
	#==========================================
	# create solvable from opensuse dist pat
	#------------------------------------------
	if (glob ("$sdir/distxml-*.gz")) {
		foreach my $file (glob ("$sdir/distxml-*.gz")) {
			$destfile = $sdir."/primary-".$count;
			my $data = qxx ("gzip -cd $file | rpmmd2solv > $destfile 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Can't create SaT solvable file");
				$kiwi -> failed ();
				$error = 1;
			}
			$count++;
		}
	}
	$count++;
	#==========================================
	# create solvable from suse tags data
	#------------------------------------------
	if (glob ("$sdir/packages-*")) {
		my $gzicmd = "gzip -cd ";
		my $stdcmd = "cat ";
		my @done   = ();
		$scommand = "";
		$destfile = $sdir."/primary-".$count;
		foreach my $file (glob ("$sdir/packages-*")) {
			if ($file =~ /\.gz$/) {
				$gzicmd .= $file." ";
			} else {
				$stdcmd .= $file." ";
			}
		}
		foreach my $file (glob ("$sdir/*.pat*")) {
			if ($file =~ /\.gz$/) {
				$gzicmd .= $file." ";
			} else {
				$stdcmd .= $file." ";
			}
		}
		if ($gzicmd ne "gzip -cd ") {
			push @done,$gzicmd;
		}
		if ($stdcmd ne "cat ") {
			push @done,$stdcmd;
		}
		foreach my $cmd (@done) {
			my $data = qxx ("$cmd | susetags2solv >> $destfile 2>/dev/null");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Can't create SaT solvable file");
				$kiwi -> failed ();
				$error = 1;
				last;
			}
		}
	}
	$count++;
	#==========================================
	# create solvable from opensuse xml pattern
	#------------------------------------------
	if (glob ("$sdir/projectxml-*.gz")) {
		foreach my $file (glob ("$sdir/projectxml-*.gz")) {
			$destfile = $sdir."/primary-".$count;
			my $data = qxx ("gzip -cd $file | rpmmd2solv > $destfile 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Can't create SaT solvable file");
				$kiwi -> failed ();
				$error = 1;
			}
			$count++;
		}
	}
	#==========================================
	# merge all solvables into one
	#------------------------------------------
	if (! $error) {
		if (! glob ("$sdir/primary-*")) {
			$kiwi -> error  ("--> Couldn't find any SaT solvable file(s)");
			$kiwi -> failed ();
			$error = 1;
		} else {
			my $data = qxx ("mergesolv $sdir/primary-* > $index");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Couldn't merge solve files");
				$kiwi -> failed ();
				$error = 1;
			}
		}
	}
	#==========================================
	# cleanup cache dir
	#------------------------------------------
	qxx ("rm -f $sdir/repomd.xml");
	qxx ("rm -f $sdir/primary-*");
	qxx ("rm -f $sdir/projectxml-*");
	qxx ("rm -f $sdir/distxml-*");
	qxx ("rm -f $sdir/packages-*");
	qxx ("rm -f $sdir/*.pat*");
	if (! $error) {
		$kiwi -> done();
		return $index;
	}
	return;
}

#==========================================
# getVMConfigOpts
#------------------------------------------
sub getVMConfigOpts {
	# ...
	# Extract the <vmconfig-entry> information from the
	# XML and return all options in a list
	# ---
	my $this = shift;
	my @configOpts;
	my @configNodes = $this->{systemTree}
		->getElementsByTagName ("vmconfig-entry");
	for my $node (@configNodes) {
		my $value = $node->textContent();
		push @configOpts, $node->textContent();
	}
	return @configOpts;
}

#==========================================
# buildImageName
#------------------------------------------
sub buildImageName {
	# ...
	# build image file name from XML information
	# ---
	my $this      = shift;
	my $separator = shift;
	my $extension = shift;
	my $arch = qxx ("uname -m"); chomp ( $arch );
	$arch = ".$arch";
	if (! defined $separator) {
		$separator = "-";
	}
	my $name = $this -> getImageName();
	my $iver = $this -> getImageVersion();
	if (defined $extension) {
		$name = $name.$extension.$arch.$separator.$iver;
	} else {
		$name = $name.$arch.$separator.$iver;
	}
	chomp  $name;
	return $name;
}

#==========================================
# hasDefaultPackages
#------------------------------------------
sub hasDefaultPackages {
	# ...
	# Returns true if a <packages> element exists that
	# has no profiles attribute.
	# ---
	my $this = shift;
	for my $pkgs (@{$this->{packageNodeList} }) {
		my $type = $pkgs -> getAttribute( 'type' );
		if ($type eq 'image') {
			my $profiles = $pkgs -> getAttribute ('profiles');
			if (! $profiles) {
				return 1;
			}
		}
	}
	return 0;
}

#==========================================
# Private helper methods
#------------------------------------------
sub __addDefaultStripNode {
	# ...
	# if no strip section is setup we add the default
	# section(s) from KIWIConfig.txt
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $image  = $this->{imgnameNodeList} -> get_node(1);
	my @snodes = $image -> getElementsByTagName ("strip");
	my %attr   = %{$this->getImageTypeAndAttributes()};
	my $haveDelete = 0;
	my $haveTools  = 0;
	my $haveLibs   = 0;
	#==========================================
	# check if type is boot image
	#------------------------------------------
	if ($attr{"type"} ne "cpio") {
		return $this;
	}
	#==========================================
	# check if there are strip nodes
	#------------------------------------------
	if (@snodes) {
		foreach my $node (@snodes) {
			my $type = $node -> getAttribute("type");
			if ($type eq "delete") {
				$haveDelete = 1;
			} elsif ($type eq "tools") {
				$haveTools = 1;
			} elsif ($type eq "libs") {
				$haveLibs = 1;
			}
		}
	}
	#==========================================
	# read in default strip section
	#------------------------------------------
	my $stripTree;
	my $stripXML = new XML::LibXML;
	eval {
		$stripTree = $stripXML
			-> parse_file ( $this->{gdata}->{KStrip} );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  (
			"Problem reading strip file: $this->{gdata}->{KStrip}"
		);
		$kiwi -> failed ();
		$kiwi -> error  ("$evaldata\n");
		return;
	}
	#==========================================
	# append default sections
	#------------------------------------------
	my @defaultStrip = $stripTree
		-> getElementsByTagName ("initrd") -> get_node (1)
		-> getElementsByTagName ("strip");
	foreach my $element (@defaultStrip) {
		my $type = $element -> getAttribute("type");
		if ((! $haveDelete) && ($type eq "delete")) {
			$kiwi -> loginfo ("STRIP: Adding default delete section\n");
			$image -> addChild ($element -> cloneNode (1));
		} elsif ((! $haveLibs) && ($type eq "libs")) {
			$kiwi -> loginfo ("STRIP: Adding default libs section\n");
			$image -> addChild ($element -> cloneNode (1));
		} elsif ((! $haveTools) && ($type eq "tools")) {
			$kiwi -> loginfo ("STRIP: Adding default tools section\n");
			$image -> addChild ($element -> cloneNode (1));
		}
	}
	$this -> updateXML();
	return $this;
}
#==========================================
# __addDefaultSplitNode
#------------------------------------------
sub __addDefaultSplitNode {
	# ...
	# if no split section is setup we add a default section
	# from the contents of the KIWISplit.txt file and apply
	# it to the split types
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my @node   = $this->{optionsNodeList} -> get_nodelist();
	my @tnodes = ();
	my @snodes = ();
	#==========================================
	# store list of all types
	#------------------------------------------
	foreach my $element (@node) {
		my @types = $element -> getElementsByTagName ("type");
		push (@tnodes,@types);
	}
	#==========================================
	# select relevant types w.o. split section
	#------------------------------------------
	foreach my $element (@tnodes) {
		my $image = $element -> getAttribute("image");
		my $flags = $element -> getAttribute("flags");
		if (($image eq "split") || 
			(($image eq "iso") && ($flags) && ($flags eq "compressed"))
		) {
			my @splitsections = $element -> getElementsByTagName ("split");
			if (! @splitsections) {
				push (@snodes,$element);
			}
		}
	}
	#==========================================
	# return if no split types are found
	#------------------------------------------
	if (! @snodes) {
		return $this;
	}
	#==========================================
	# read in default split section
	#------------------------------------------
	my $splitTree;
	my $splitXML = new XML::LibXML;
	eval {
		$splitTree = $splitXML
			-> parse_file ( $this->{gdata}->{KSplit} );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  (
			"Problem reading split file: $this->{gdata}->{KSplit}"
		);
		$kiwi -> failed ();
		$kiwi -> error  ("$evaldata\n");
		return;
	}
	#==========================================
	# append default section to selected nodes
	#------------------------------------------
	my $defaultSplit = $splitTree
		-> getElementsByTagName ("split") -> get_node(1);
	foreach my $element (@snodes) {
		$element -> addChild (
			$defaultSplit -> cloneNode (1)
		);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# __updateDescriptionFromChangeSet
#------------------------------------------
sub __updateDescriptionFromChangeSet {
	# ...
	# Write given changes into the previosly read in XML tree
	# This function is used to incorporate repository, packages
	# and other changes into the current XML description. Most
	# often required in order to build the boot image to fit
	# together with the system image
	# ---
	my $this      = shift;
	my $changeset = shift;
	my $kiwi      = $this->{kiwi};
	my $repositNodeList = $this->{repositNodeList};
	my $packageNodeList = $this->{packageNodeList};
	my $reqProfiles;
	#==========================================
	# check changeset...
	#------------------------------------------
	if (! defined $changeset) {
		return;
	}
	#==========================================
	# check profiles in changeset...
	#------------------------------------------
	if ($changeset->{profiles}) {
		$reqProfiles = $this->{reqProfiles};
		$this->{reqProfiles} = $changeset->{profiles};
	}
	#==========================================
	# 1) merge/update repositories
	#------------------------------------------
	if ($changeset->{repositories}) {
		$kiwi -> info ("Updating repository node(s):");
		$this -> ignoreRepositories();
		# 1) add those repos which are marked as fixed in the boot xml
		my @node = $repositNodeList -> get_nodelist();
		foreach my $element (@node) {
			if (! $this -> __requestedProfile ($element)) {
				next;
			}
			my $status = $element -> getAttribute("status");
			if ((! defined $status) || ($status eq "fixed")) {
				my $type  = $element -> getAttribute("type");
				my $source= $element -> getElementsByTagName("source")
					-> get_node(1) -> getAttribute ("path");
				my $alias = $element -> getAttribute("alias");
				my $prio = $element -> getAttribute("priority");
				$this -> addRepository ([$type],[$source],[$alias],[$prio]);
			}
		}
		# 2) add those repos which are part of the changeset
		foreach my $source (keys %{$changeset->{repositories}}) {
			my $props = $changeset->{repositories}->{$source};
			my $type  = $props->[0];
			my $alias = $props->[1];
			my $prio  = $props->[2];
			my $user  = $props->[3];
			my $pass  = $props->[4];
			$this -> addRepository (
				[$type],[$source],[$alias],[$prio],[$user],[$pass]
			);
		}
		$kiwi -> done ();
	}
	#==========================================
	# 2) merge/update drivers
	#------------------------------------------
	if (@{$changeset->{driverList}}) {
		$kiwi -> info ("Updating driver section(s):\n");
		my @drivers = @{$changeset->{driverList}};
		foreach my $d (@drivers) {
			$kiwi -> info ("--> $d\n");
		}
		$this -> addDrivers (@drivers);
	}
	#==========================================
	# 3) merge/update strip
	#------------------------------------------
	if ($changeset->{strip}) {
		foreach my $type (keys %{$changeset->{strip}}) {
			$kiwi -> info ("Updating $type strip section:\n");
			foreach my $item (@{$changeset->{strip}{$type}}) {
				$kiwi -> info ("--> $item\n");
			}
			$this -> addStrip ($type,@{$changeset->{strip}{$type}});
		}
	}
	#==========================================
	# 4) merge/update packages
	#------------------------------------------
	foreach my $section (("image","bootstrap")) {
		if (@{$changeset->{$section."_fplistImage"}}) {
			$kiwi -> info ("Updating package(s) [$section]:\n");
			my $fixedBootInclude = $changeset->{fixedBootInclude};
			my @fplistImage = @{$changeset->{$section."_fplistImage"}};
			my @fplistDelete = @{$changeset->{$section."_fplistDelete"}};
			foreach my $p (@fplistImage) {
				$kiwi -> info ("--> $p\n");
			}
			$this -> addPackages (
				$section,$fixedBootInclude,$packageNodeList,@fplistImage
			);
			if (@fplistDelete) {
				$this -> addPackages (
					"delete",undef,$packageNodeList,@fplistDelete
				);
			}
		}
	}
	#==========================================
	# 5) merge/update archives
	#------------------------------------------
	foreach my $section (("image","bootstrap")) {
		if (@{$changeset->{$section."_falistImage"}}) {
			$kiwi -> info ("Updating archive(s) [$section]:\n");
			my @falistImage = @{$changeset->{$section."_falistImage"}};
			foreach my $p (@falistImage) {
				$kiwi -> info ("--> $p\n");
			}
			$this -> addArchives (
				$section,"bootinclude",$packageNodeList,@falistImage
			);
		}
	}
	#==========================================
	# 6) merge/update machine attribs in type
	#------------------------------------------
	if (defined $changeset->{"domain"}) {
		$this -> __setMachineAttribute ("domain",$changeset);
	}
	#==========================================
	# 7) merge/update preferences and type
	#------------------------------------------
	if (defined $changeset->{"locale"}) {
		$this -> __setOptionsElement ("locale",$changeset);
	}
	if (defined $changeset->{"boot-theme"}) {
		$this -> __setOptionsElement ("boot-theme",$changeset);
	}
	if (defined $changeset->{"packagemanager"}) {
		$this -> __setOptionsElement ("packagemanager",$changeset);
	}
	if (defined $changeset->{"showlicense"}) {
		$this -> __addOptionsElement ("showlicense",$changeset);
	}
	if (defined $changeset->{"oem-swap"}) {
		$this -> __setOEMOptionsElement ("oem-swap",$changeset);
	}
	if (defined $changeset->{"oem-align-partition"}) {
		$this -> __setOEMOptionsElement ("oem-align-partition",$changeset);
	}
	if (defined $changeset->{"oem-partition-install"}) {
		$this -> __setOEMOptionsElement ("oem-partition-install",$changeset);
	}
	if (defined $changeset->{"oem-swapsize"}) {
		$this -> __setOEMOptionsElement ("oem-swapsize",$changeset);
	}
	if (defined $changeset->{"oem-systemsize"}) {
		$this -> __setOEMOptionsElement ("oem-systemsize",$changeset);
	}
	if (defined $changeset->{"oem-boot-title"}) {
		$this -> __setOEMOptionsElement ("oem-boot-title",$changeset);
	}
	if (defined $changeset->{"oem-kiwi-initrd"}) {
		$this -> __setOEMOptionsElement ("oem-kiwi-initrd",$changeset);
	}
	if (defined $changeset->{"oem-reboot"}) {
		$this -> __setOEMOptionsElement ("oem-reboot",$changeset);
	}
	if (defined $changeset->{"oem-reboot-interactive"}) {
		$this -> __setOEMOptionsElement ("oem-reboot-interactive",$changeset);
	}
	if (defined $changeset->{"oem-silent-boot"}) {
		$this -> __setOEMOptionsElement ("oem-silent-boot",$changeset);
	}
	if (defined $changeset->{"oem-shutdown"}) {
		$this -> __setOEMOptionsElement ("oem-shutdown",$changeset);
	}
	if (defined $changeset->{"oem-shutdown-interactive"}) {
		$this -> __setOEMOptionsElement ("oem-shutdown-interactive",$changeset);
	}
	if (defined $changeset->{"oem-bootwait"}) {
		$this -> __setOEMOptionsElement ("oem-bootwait",$changeset);
	}
	if (defined $changeset->{"oem-unattended"}) {
		$this -> __setOEMOptionsElement ("oem-unattended",$changeset);
	}
	if (defined $changeset->{"oem-unattended-id"}) {
		$this -> __setOEMOptionsElement ("oem-unattended-id",$changeset);
	}
	if (defined $changeset->{"oem-recovery"}) {
		$this -> __setOEMOptionsElement ("oem-recovery",$changeset);
	}
	if (defined $changeset->{"oem-recoveryID"}) {
		$this -> __setOEMOptionsElement ("oem-recoveryID",$changeset);
	}
	if (defined $changeset->{"oem-inplace-recovery"}) {
		$this -> __setOEMOptionsElement ("oem-inplace-recovery",$changeset);
	}
	if (defined $changeset->{"lvm"}) {
		$this -> __setSystemDiskElement (undef,$changeset);
	}
	#==========================================
	# 8) merge/update type attributes
	#------------------------------------------
	if (defined $changeset->{"hybrid"}) {
		$this -> __setTypeAttribute (
			"hybrid",$changeset->{"hybrid"}
		);
	}
	if (defined $changeset->{"hybridpersistent"}) {
		$this -> __setTypeAttribute (
			"hybridpersistent",$changeset->{"hybridpersistent"}
		);
	}
	if (defined $changeset->{"ramonly"}) {
		$this -> __setTypeAttribute (
			"ramonly",$changeset->{"ramonly"}
		);
	}
	if (defined $changeset->{"kernelcmdline"}) {
		$this -> __setTypeAttribute (
			"kernelcmdline",$changeset->{"kernelcmdline"}
		);
	}
	if (defined $changeset->{"bootloader"}) {
		$this -> __setTypeAttribute (
			"bootloader",$changeset->{"bootloader"}
		);
	}
	if (defined $changeset->{"devicepersistency"}) {
		$this -> __setTypeAttribute (
			"devicepersistency",$changeset->{"devicepersistency"}
		);
	}
	if (defined $changeset->{"installboot"}) {
		$this -> __setTypeAttribute (
			"installboot",$changeset->{"installboot"}
		);
	}
	if (defined $changeset->{"bootkernel"}) {
		$this -> __setTypeAttribute (
			"bootkernel",$changeset->{"bootkernel"}
		);
	}
	if (defined $changeset->{"bootprofile"}) {
		$this -> __setTypeAttribute (
			"bootprofile",$changeset->{"bootprofile"}
		);
	}
	#==========================================
	# 9) merge/update image attribs, toplevel
	#------------------------------------------
	if (defined $changeset->{"displayname"}) {
		$this -> __setImageAttribute (
			"displayname",$changeset->{"displayname"}
		);
	}
	#==========================================
	# 10) merge/update all free volume
	#------------------------------------------
	if (defined $changeset->{"allFreeVolume"}) {
		$this -> __addAllFreeVolume ($changeset->{"allFreeVolume"});
	}
	#==========================================
	# 11) cleanup reqProfiles
	#------------------------------------------
	$this->{reqProfiles} = $reqProfiles;
}

#==========================================
# __addAllFreeVolume
#------------------------------------------
sub __addAllFreeVolume {
	# ...
	# Add the given volume to the systemdisk section
	# ---
	my $this  = shift;
	my $volume= shift;
	my $kiwi  = $this->{kiwi};
	my $tnode = $this->{typeNode};
	my $disk  = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	if (! defined $disk) {
		return $this;
	}
	my $addElement = new XML::LibXML::Element ("volume");
	$addElement -> setAttribute("name",$volume);
	$addElement -> setAttribute("freespace","all");
	$disk -> appendChild ($addElement);
	$this -> updateXML();
	return $this;
}

#==========================================
# __setOptionsElement
#------------------------------------------
sub __setOptionsElement {
	# ...
	# If given element exists in the data hash, set this
	# element into the current preferences (options) XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $value = $data->{$item};
	$kiwi -> info ("Updating element $item: $value");
	my $addElement = new XML::LibXML::Element ("$item");
	$addElement -> appendText ($value);
	my $opts = $this -> getPreferencesNodeByTagName ("$item");
	my $node = $opts -> getElementsByTagName ("$item");
	if ($node) {
		if ("$node" eq "$value") {
			$kiwi -> done ();
			return $this;
		}
		$node = $node -> get_node(1);
		$opts -> removeChild ($node);
	}
	$opts -> appendChild ($addElement);
	$kiwi -> done ();
	$this -> updateXML();
	return $this;
}

#==========================================
# __addOptionsElement
#------------------------------------------
sub __addOptionsElement {
	# ...
	# add a new element into the current preferences XML tree
	# the data reference must be an array. Each element of the
	# array is processed as new XML element
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $value= $data->{$item};
	if (! $value) {
		return $this;
	}
	foreach my $text (@{$value}) {
		$kiwi -> info ("Adding element $item: $text");
		my $addElement = new XML::LibXML::Element ("$item");
		$addElement -> appendText ($text);
		my $opts = $this -> getPreferencesNodeByTagName ("$item");
		$opts -> appendChild ($addElement);
		$kiwi -> done ();
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# __setOEMOptionsElement
#------------------------------------------
sub __setOEMOptionsElement {
	# ...
	# If given element exists in the data hash, set this
	# element into the current oemconfig (options) XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $value = $data->{$item};
	my $newconfig = 0;
	$kiwi -> info ("Updating OEM element $item: $value");
	my $addElement = new XML::LibXML::Element ("$item");
	$addElement -> appendText ($value);
	my $opts = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $opts) {
		$opts = new XML::LibXML::Element ("oemconfig");
		$newconfig = 1;
	}
	my $node = $opts -> getElementsByTagName ("$item");
	if ($node) {
		$node = $node -> get_node(1);
		$opts -> removeChild ($node);
	}
	$opts -> appendChild ($addElement);
	if ($newconfig) {
		$this->{typeNode} -> appendChild ($opts);
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setSystemDiskElement
#------------------------------------------
sub __setSystemDiskElement {
	# ...
	# If given element exists in the data hash, set this
	# element into the current systemdisk XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $value;
	if (($data) && ($item)) {
		$value = $data->{$item};
	}
	my $newconfig = 0;
	my $addElement;
	if ($item) {
		$kiwi -> info ("Updating SystemDisk element $item: $value");
		$addElement = new XML::LibXML::Element ("$item");
		$addElement -> appendText ($value);
	} else {
		$kiwi -> info ("Updating SystemDisk element");
	}
	my $disk = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	if (! defined $disk) {
		$disk = new XML::LibXML::Element ("systemdisk");
		$newconfig = 1;
	}
	if ($item) {
		my $node = $disk -> getElementsByTagName ("$item");
		if ($node) {
			$node = $node -> get_node(1);
			$disk -> removeChild ($node);
		}
		$disk -> appendChild ($addElement);
	}
	if ($newconfig) {
		$this->{typeNode} -> appendChild ($disk);
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setMachineAttribute
#------------------------------------------
sub __setMachineAttribute {
	# ...
	# If given element exists in the data hash, set this
	# attribute into the current machine (options) XML tree
	# if no machine section exists create a new one
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $value = $data->{$item};
	my $newconfig = 0;
	$kiwi -> info ("Updating machine attribute $item: $value");
	my $opts = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	if (! defined $opts) {
		$opts = new XML::LibXML::Element ("machine");
		$newconfig = 1;
	}
	my $node = $opts -> getElementsByTagName ("$item");
	if ($node) {
		$node = $node -> get_node(1);
		$opts -> removeChild ($node);
	}
	if ($value) {
		$opts-> setAttribute ("$item","$value");
	} else {
		$opts-> setAttribute ("$item","true");
	}
	if ($newconfig) {
		$this->{typeNode} -> appendChild ($opts);
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setTypeAttribute
#------------------------------------------
sub __setTypeAttribute {
	# ...
	# set given attribute to selected type in the
	# xml preferences node
	# ---
	my $this = shift;
	my $attr = shift;
	my $val  = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	if ($val) {
		$kiwi -> info ("Updating type attribute: $attr : $val");
		$tnode-> setAttribute ("$attr","$val");
	} else {
		$kiwi -> info ("Updating type attribute: $attr");
		$tnode-> setAttribute ("$attr","true");
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setImageAttribute
#------------------------------------------
sub __setImageAttribute {
	# ...
	# set given attribute to the image section
	# ---
	my $this = shift;
	my $attr = shift;
	my $val  = shift;
	my $kiwi = $this->{kiwi};
	my $inode= $this->{imgnameNodeList} -> get_node(1);
	$kiwi -> info ("Updating image attribute: $attr");
	if ($val) {
		$inode -> setAttribute ("$attr","$val");
	} else {
		$inode -> setAttribute ("$attr","true");
	}
	$kiwi -> done ();
	$this -> updateXML();
	return $this;
}

#==========================================
# __requestedProfile
#------------------------------------------
sub __requestedProfile {
	# ...
	# Return a boolean representing whether or not
	# a given element is requested to be included
	# in this image.
	# ---
	my $this      = shift;
	my $element   = shift;
	my $nodeName  = $element->nodeName();

	if (! defined $element) {
		# print "Element not defined\n";
		return 1;
	}
	my $profiles = $element -> getAttribute ("profiles");
	if (! defined $profiles) {
		# If no profile is specified, then it is assumed to be in all profiles.
		# print "Section $nodeName always used\n";
		return 1;
	}
	if ((! $this->{reqProfiles}) || ((scalar @{$this->{reqProfiles}}) == 0)) {
		# element has a profile, but no profiles requested so exclude it.
		# print "Section $nodeName profiled, but no profiles requested\n";
		return 0;
	}
	my @splitProfiles = split(/,/, $profiles);
	my %profileHash = ();
	foreach my $profile (@splitProfiles) {
		$profileHash{$profile} = 1;
	}
	if (defined $this->{reqProfiles}) {
		foreach my $reqprof (@{$this->{reqProfiles}}) {
			# strip whitespace
			$reqprof =~ s/^\s+//s;
			$reqprof =~ s/\s+$//s;
			if (defined $profileHash{$reqprof}) {
				# print "Section $nodeName selected\n";
				return 1;
			}
		}
	}
	# print "Section $nodeName not selected\n";
	return 0;
}

#==========================================
# __populateProfiles
#------------------------------------------
sub __populateProfiles {
	# ...
	# import profiles section if specified
	# ---
	my $this     = shift;
	my %result   = ();
	my @profiles = $this -> getProfiles ();
	foreach my $profile (@profiles) {
		if ($profile->{include}) {
			$result{$profile->{name}} = "$profile->{include}";
		} else {
			$result{$profile->{name}} = "false";
		}
	}
	return \%result;
}

#==========================================
# __populateDefaultProfiles
#------------------------------------------
sub __populateDefaultProfiles {
	# ...
	# import default profiles if no other profiles
	# were set on the commandline
	# ---
	my $this     = shift;
	my $kiwi     = $this->{kiwi};
	my $profiles = $this->{profileHash};
	my @list     = ();
	#==========================================
	# check for profiles already processed
	#------------------------------------------
	if ((defined $this->{reqProfiles}) && (@{$this->{reqProfiles}})) {
		my $info = join (",",@{$this->{reqProfiles}});
		$kiwi -> info ("Using profile(s): $info");
		$kiwi -> done ();
		return $this;
	}
	#==========================================
	# select profiles marked to become included
	#------------------------------------------
	foreach my $name (keys %{$profiles}) {
		if ($profiles->{$name} eq "true") {
			push @list,$name;
		}
	}
	#==========================================
	# read default type: bootprofile,bootkernel
	#------------------------------------------
	# /.../
	# read the first <type> element which is always the one and only
	# type element in a boot image description. The check made here
	# applies only to boot image descriptions:
	# ----
	my $node = $this->{optionsNodeList}
		-> get_node(1) -> getElementsByTagName ("type") -> get_node(1);
	if (defined $node) {
		my $type = $node -> getAttribute("image");
		if ((defined $type) && ($type eq "cpio")) {
			my $bootprofile = $node -> getAttribute("bootprofile");
			my $bootkernel  = $node -> getAttribute("bootkernel");
			if ($bootprofile) {
				push @list, split (/,/,$bootprofile);
			} else {
				# apply 'default' profile required for boot images
				push @list, "default";
			}
			if ($bootkernel) {
				push @list, split (/,/,$bootkernel);
			} else {
				# apply 'std' kernel profile required for boot images
				push @list, "std";
			}
		}
	}
	#==========================================
	# store list of requested profiles
	#------------------------------------------
	if (@list) {
		my $info = join (",",@list);
		$kiwi -> info ("Using profile(s): $info");
		$this -> {reqProfiles} = \@list;
		$kiwi -> done ();
	}
	return $this;
}

#==========================================
# __populateTypeInfo
#------------------------------------------
sub __populateTypeInfo {
	# ...
	# Extract the information contained in the <type> elements
	# and store the type descriptions in a list of hash references
	# ---
	# list = (
	#   {
	#      'key' => 'value'
	#      'key' => 'value'
	#   },
	#   {
	#      'key' => 'value'
	#      'key' => 'value'
	#   }
	# )
	# ---
	#
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my $urlhd  = new KIWIURL ($kiwi,$cmdL);
	my @node   = $this->{optionsNodeList} -> get_nodelist();
	my @result = ();
	my $first  = 1;
	#==========================================
	# select types
	#------------------------------------------
	foreach my $element (@node) {
		my @types    = $element -> getElementsByTagName ("type");
		my $profiles = $element -> getAttribute("profiles");
		my @assigned = ("all");
		if ($profiles) {
			@assigned = split (/,/,$profiles);
		}
		foreach my $node (@types) {
			my %record = ();
			my $prim   = $node -> getAttribute("primary");
			if (! defined $prim) {
				$record{primary} = "false";
			} else {
				$record{primary} = $prim;
			}
			my $disk = $node->getElementsByTagName("systemdisk")->get_node(1);
			#==========================================
			# meta data
			#------------------------------------------
			$record{first}    = $first;
			$record{node}     = $node;
			$record{assigned} = \@assigned;
			$first = 0;
			#==========================================
			# type attributes
			#------------------------------------------
			$record{type}          = $node
				-> getAttribute("image");
			$record{luks}          = $node
				-> getAttribute("luks");
			$record{cmdline}       = $node
				-> getAttribute("kernelcmdline");
			$record{compressed}    = $node
				-> getAttribute("compressed");
			$record{boot}          = $node
				-> getAttribute("boot");
			$record{volid}         = $node
				-> getAttribute("volid");
			$record{flags}         = $node
				-> getAttribute("flags");
			$record{hybrid}        = $node
				-> getAttribute("hybrid");
			$record{format}        = $node
				-> getAttribute("format");
			$record{installiso}    = $node
				-> getAttribute("installiso");
			$record{installstick}  = $node
				-> getAttribute("installstick");
			$record{vga}           = $node
				-> getAttribute("vga");
			$record{bootloader}    = $node
				-> getAttribute("bootloader");
			$record{devicepersistency} = $node
				-> getAttribute("devicepersistency");
			$record{boottimeout}   = $node
				-> getAttribute("boottimeout");
			$record{installboot}   = $node
				-> getAttribute("installboot");
			$record{installprovidefailsafe} = $node
				-> getAttribute("installprovidefailsafe");
			$record{checkprebuilt} = $node
				-> getAttribute("checkprebuilt");
			$record{bootprofile}   = $node
				-> getAttribute("bootprofile");
			$record{bootkernel}    = $node
				-> getAttribute("bootkernel");
			$record{filesystem}    = $node
				-> getAttribute("filesystem");
			$record{fsnocheck}     = $node
				-> getAttribute("fsnocheck");
			$record{hybridpersistent}  = $node
				-> getAttribute("hybridpersistent");
			$record{ramonly}       = $node
				-> getAttribute("ramonly");
			if (defined $disk) {
				$record{lvm} = "true";
			}
			if ($record{type} eq "split") {
				my $filesystemRO = $node -> getAttribute("fsreadonly");
				my $filesystemRW = $node -> getAttribute("fsreadwrite");
				if ((defined $filesystemRO) && (defined $filesystemRW)) {
					$record{filesystem} = "$filesystemRW,$filesystemRO";
				}
			}
			my $bootpath = $urlhd -> normalizeBootPath ($record{boot});
			if (defined $bootpath) {
				$record{boot} = $bootpath;
			}
			#==========================================
			# push to list
			#------------------------------------------
			push @result,\%record;
		}
	}
	return \@result;
}

#==========================================
# __populateProfiledTypeInfo
#------------------------------------------
sub __populateProfiledTypeInfo {
	# ...
	# Store those types from the typeList which are selected
	# by the profiles or the internal 'all' profile and store
	# them in the object internal typeInfo hash:
	# ---
	# typeInfo{imagetype}{attr} = value
	# ---
	my $this     = shift;
	my $kiwi     = $this->{kiwi};
	my %result   = ();
	my %select   = ();
	my $typeList = $this->{typeList};
	my @node     = $this->{optionsNodeList} -> get_nodelist();
	#==========================================
	# create selection according to profiles
	#------------------------------------------
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $profiles = $element -> getAttribute("profiles");
		my @assigned = ("all");
		if ($profiles) {
			@assigned = split (/,/,$profiles);
		}
		foreach my $p (@assigned) {
			$select{$p} = $p;
		}
	}
	#==========================================
	# select record(s) according to selection
	#------------------------------------------
	foreach my $record (@{$typeList}) {
		my $found = 0;
		my $first = 1;
		foreach my $p (@{$record->{assigned}}) {
			if ($select{$p}) {
				$found = 1; last;
			}
		}
		next if ! $found;
		$record->{first} = $first;
		$result{$record->{type}} = $record;
		$first = 0;
	}
	#==========================================
	# store types in typeInfo hash
	#------------------------------------------
	$this->{typeInfo} = \%result;
	return $this;
}

#==========================================
# __populateImageTypeAndNode
#------------------------------------------
sub __populateImageTypeAndNode {
	# ...
	# initialize imageType and typeNode according to the
	# requested type or by the type specified as primary
	# or by the first type node found
	# ---
	my $this     = shift;
	my $kiwi     = $this->{kiwi};
	my $typeinfo = $this->{typeInfo};
	my $select;
	#==========================================
	# check if there is a preferences section
	#------------------------------------------
	if (! $this->{optionsNodeList}) {
		return;
	}
	#==========================================
	# check if typeinfo hash exists
	#------------------------------------------
	if (! $typeinfo) {
		# /.../
		# if no typeinfo hash was populated we use the first type
		# node listed in the description as the used type.
		# ----
		$this->{typeNode} = $this->{optionsNodeList}
			-> get_node(1) -> getElementsByTagName ("type") -> get_node(1);
		return $this;
	}
	#==========================================
	# select type and type node
	#------------------------------------------
	if (! defined $this->{imageType}) {
		# /.../
		# no type was requested: select primary type or if
		# not set in the XML description select the first one
		# in the list
		# ----
		my @types = keys %{$typeinfo};
		my $first;
		foreach my $type (@types) {
			if ($typeinfo->{$type}{primary} eq "true") {
				$select = $type; last;
			}
			if ($typeinfo->{$type}{first} == 1) {
				$first = $type;
			}
		}
		if (! $select) {
			$select = $first;
		}
	} else {
		# /.../
		# a specific type was requested, select this type
		# ----
		$select = $this->{imageType};
	}
	#==========================================
	# check selection
	#------------------------------------------
	if (! $select) {
		$kiwi -> error  ('Cannot determine build type');
		$kiwi -> failed ();
		return;
	}
	if (! $typeinfo->{$select}) {
		$kiwi -> error  ("Can't find requested image type: $select");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# store object data
	#------------------------------------------
	$this->{imageType} = $typeinfo->{$select}{type};
	$this->{typeNode}  = $typeinfo->{$select}{node};
	return $this;
}

#==========================================
# __quote
#------------------------------------------
sub __quote {
	my $this = shift;
	my $line = shift;
	$line =~ s/([\"\$\`\\])/\\$1/g;
	return $line;
}

1;

# vim: set noexpandtab:
