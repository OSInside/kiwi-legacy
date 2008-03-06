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
use XML::LibXML;
use LWP;
use KIWILog;
use KIWIPattern;
use KIWIOverlay;
use KIWISatSolver;
use KIWIManager qw (%packageManager);
use File::Glob ':glob';
use KIWIQX;

#==========================================
# Globals
#------------------------------------------
our %inheritanceHash;

#==========================================
# Constructor
#------------------------------------------
sub new { 
	# ...
	# Create a new KIWIXML object which is used to access the
	# configuration XML data saved as config.xml. The xml data
	# is splitted into four major tags: preferences, drivers,
	# repository and packages. While constructing an object of this
	# type there will be a node list created for each of the
	# major tags.
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
	my $foreignRepo = shift;
	my $imageWhat   = shift;
	my $reqProfiles = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (($imageDesc !~ /\//) && (! -d $imageDesc)) {
		$imageDesc = $main::System."/".$imageDesc;
	}
	my $arch = qxx ("uname -m"); chomp $arch;
	my $controlFile = $imageDesc."/config.xml";
	my $checkmdFile = $imageDesc."/.checksum.md5";
	my $havemd5File = 1;
	my $systemTree;
	#==========================================
	# Check if config.xml exist
	#------------------------------------------
	if (! -f $controlFile) {
		$kiwi -> failed ();
		$kiwi -> error ("Cannot open control file: $controlFile");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Check/Transform due to XSL stylesheet(s)
	#------------------------------------------
	my $data = qxx (
		"xsltproc -o $controlFile-v2.0 $main::S14to20 $controlFile 2>&1"
	);
	my $code = $? >> 8;
	if (($code == 0) && (-f "$controlFile-v2.0")) {
		qxx ("mv $controlFile-v2.0 $controlFile");
	} else {
		$kiwi -> loginfo ("XSL: $data");
	}
	#==========================================
	# Check image md5 sum
	#------------------------------------------
	if (-f $checkmdFile) {
		my $data = qxx ("cd $imageDesc && md5sum -c .checksum.md5 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			chomp $data;
			$kiwi -> failed ();
			$kiwi -> error ("Integrity check for $imageDesc failed:\n$data");
			$kiwi -> failed ();
			return undef;
		}
	} else {
		$havemd5File = 0;
	}
	#==========================================
	# Load XML objects and schema
	#------------------------------------------
	my $systemXML   = new XML::LibXML;
	my $systemRNG   = new XML::LibXML::RelaxNG ( location => $main::Scheme );
	my $optionsNodeList;
	my $driversNodeList;
	my $usrdataNodeList;
	my $repositNodeList;
	my $packageNodeList;
	my $imgnameNodeList;
	my $deploysNodeList;
	my $splitNodeList;
	my $instsrcNodeList;
	my $partitionsNodeList;
	my $configfileNodeList;
	my $unionNodeList;
	my $profilesNodeList;
	eval {
		$systemTree = $systemXML
			-> parse_file ( $controlFile );
		$optionsNodeList = $systemTree -> getElementsByTagName ("preferences");
		$driversNodeList = $systemTree -> getElementsByTagName ("drivers");
		$usrdataNodeList = $systemTree -> getElementsByTagName ("users");
		$repositNodeList = $systemTree -> getElementsByTagName ("repository");
		$packageNodeList = $systemTree -> getElementsByTagName ("packages");
		$imgnameNodeList = $systemTree -> getElementsByTagName ("image");
		$deploysNodeList = $systemTree -> getElementsByTagName ("deploy");
		$splitNodeList   = $systemTree -> getElementsByTagName ("split");
		$instsrcNodeList = $systemTree -> getElementsByTagName ("instsource");
		$partitionsNodeList = $systemTree 
			-> getElementsByTagName ("partitions");
		$configfileNodeList = $systemTree 
			-> getElementsByTagName("configuration");
		$unionNodeList = $systemTree -> getElementsByTagName ("union");
		$profilesNodeList = $systemTree -> getElementsByTagName ("profiles");
	};
	if ($@) {
		$kiwi -> failed ();
		$kiwi -> error  ("Problem reading control file");
		$kiwi -> failed ();
		$kiwi -> error  ("$@\n");
		return undef;
	}
	#==========================================
	# Validate xml input with current scheme
	#------------------------------------------
	eval {
		$systemRNG ->validate ( $systemTree );
	};
	if ($@) {
		$kiwi -> failed ();
		$kiwi -> error  ("Scheme validation failed");
		$kiwi -> failed ();
		$kiwi -> error  ("$@\n");
		return undef;
	}
	#==========================================
	# setup foreign repository sections
	#------------------------------------------
	if ( defined $foreignRepo->{xmlnode} ) {
		$kiwi -> done ();
		$kiwi -> info ("Including foreign repository node(s)");
		my $need = new XML::LibXML::NodeList();
		my @node = $repositNodeList -> get_nodelist();
		foreach my $element (@node) {
			my $status = $element -> getAttribute("status");
			if ((! defined $status) || ($status eq "fixed")) {
				$need -> push ($element);
			}
		}
		$repositNodeList = $foreignRepo->{xmlnode};
		$repositNodeList -> prepend ($need);
		if (defined $foreignRepo->{locale}) {
			my $lang = $foreignRepo->{locale};
			$kiwi -> done ();
			$kiwi -> info ("Including foreign locale: $lang");
			my $addElement = new XML::LibXML::Element ("locale");
			$addElement -> appendText ($lang);
			my $opts = $optionsNodeList -> get_node(1);
			my $node = $opts -> getElementsByTagName ("locale");
			if ($node) {
				$node = $node -> get_node(1);
				$opts -> removeChild ($node);
			}
			$opts -> appendChild ($addElement);
		}
		if (defined $foreignRepo->{packagemanager}) {
			my $manager = $foreignRepo->{packagemanager};
			$kiwi -> done ();
			$kiwi -> info ("Including foreign package manager: $manager");
			my $addElement = new XML::LibXML::Element ("packagemanager");
			$addElement -> appendText ($manager);
			my $opts = $optionsNodeList -> get_node(1);
			my $node = $opts -> getElementsByTagName ("packagemanager")
				-> get_node(1);
			$opts -> removeChild ($node);
			$opts -> appendChild ($addElement);
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}               = $kiwi;
	$this->{imageDesc}          = $imageDesc;
	$this->{imageWhat}          = $imageWhat;
	$this->{foreignRepo}        = $foreignRepo;
	$this->{optionsNodeList}    = $optionsNodeList;
	$this->{driversNodeList}    = $driversNodeList;
	$this->{usrdataNodeList}    = $usrdataNodeList;
	$this->{repositNodeList}    = $repositNodeList;
	$this->{packageNodeList}    = $packageNodeList;
	$this->{imgnameNodeList}    = $imgnameNodeList;
	$this->{deploysNodeList}    = $deploysNodeList;
	$this->{splitNodeList}      = $splitNodeList;
	$this->{instsrcNodeList}    = $instsrcNodeList;
	$this->{partitionsNodeList} = $partitionsNodeList;
	$this->{configfileNodeList} = $configfileNodeList;
	$this->{unionNodeList}      = $unionNodeList;
	$this->{profilesNodeList}   = $profilesNodeList;
	$this->{reqProfiles}        = $reqProfiles;
	$this->{havemd5File}        = $havemd5File;
	$this->{arch}               = $arch;
	
	#==========================================
	# Store object data (create URL list)
	#------------------------------------------
	$this -> createURLList ();

	#==========================================
	# Check type information from xml input
	#------------------------------------------
	if (! $optionsNodeList) {
		return $this;
	}
	if (! $this -> getImageTypeAndAttributes()) {
		$kiwi -> failed ();
		$kiwi -> error  ("Boot type: $imageWhat not specified in config.xml");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Check profile names
	#------------------------------------------
	if (! $this -> checkProfiles()) {
		return undef;
	}
	return $this;
}

#==========================================
# haveMD5File
#------------------------------------------
sub haveMD5File {
	my $this = shift;
	return $this->{havemd5File};
}

#==========================================
# createURLList
#------------------------------------------
sub createURLList {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %repository  = ();
	my @urllist     = ();
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
		my $urlHandler  = new KIWIURL ($kiwi,undef);
		my $publics_url = $urlHandler -> normalizePath ($source);
		push (@urllist,$publics_url);
	}
	$this->{urllist} = \@urllist;
	return $this;
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
# getImageInherit
#------------------------------------------
sub getImageInherit {
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $path = $node -> getAttribute ("inherit");
	return $path;
}

#==========================================
# getImageSize
#------------------------------------------
sub getImageSize {
	# ...
	# Get the predefined size of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $unit = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("unit");
		return $size.$unit;
	} else {
		return "auto";
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
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $byte = int $size;
		my $unit = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("unit");
		if ($unit eq "M") {
			return $byte * 1024 * 1024;
		}
		if ($unit eq "G") {
			return $byte * 1024 * 1024 * 1024;
		}
		# no unit specified assume MB...
		return $byte * 1024 * 1024;
	} else {
		return "auto";
	}
}

#==========================================
# getImageDefaultDestination
#------------------------------------------
sub getImageDefaultDestination {
	# ...
	# Get the default destination to store the images below
	# normally this is given by the --destination option but if
	# not and defaultdestination is specified in config.xml we
	# will use this path as destination
	# ---
	my $this = shift;
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $dest = $node -> getElementsByTagName ("defaultdestination");
	return $dest;
}

#==========================================
# getImageDefaultBaseRoot
#------------------------------------------
sub getImageDefaultBaseRoot {
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $path = $node -> getAttribute ("defaultbaseroot");
	return $path;
}

#==========================================
# getImageDefaultRoot
#------------------------------------------
sub getImageDefaultRoot {
	# ...
	# Get the default root directory name to build up a new image
	# normally this is given by the --root option but if
	# not and defaultroot is specified in config.xml we
	# will use this path as root path.
	# ---
	my $this = shift;
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $root = $node -> getElementsByTagName ("defaultroot");
	return $root;
}

#==========================================
# getImageTypeAndAttributes
#------------------------------------------
sub getImageTypeAndAttributes {
	# ...
	# Get the image type and its attributes for beeing
	# able to create the appropriate logical extend
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my %result = ();
	my $count  = 0;
	my $first  = "";
	my $ptype  = "";
	my @node   = $this->{optionsNodeList} -> get_node(1)
		-> getElementsByTagName ("type");
	foreach my $node (@node) {
		my %record = ();
		my $prim = $node -> getAttribute("primary");
		if ((! defined $prim) || ($prim eq "false") || ($prim eq "0")) {
			$prim = $node -> string_value();
		} else {
			$prim  = "primary";
			$ptype = $node -> string_value();
		}
		if ($count == 0) {
			$first = $prim;
		}
		$record{type}   = $node -> string_value();
		$record{boot}   = $node -> getAttribute("boot");
		$record{flags}  = $node -> getAttribute("flags");
		$record{format} = $node -> getAttribute("format");
		$record{checkprebuilt} = $node -> getAttribute("checkprebuilt");
		$record{baseroot}      = $node -> getAttribute("baseroot");
		$record{bootprofile}   = $node -> getAttribute("bootprofile");
		$record{filesystem}    = $node -> getAttribute("filesystem");
		if ($record{type} eq "split") {
			my $filesystemRO = $node -> getAttribute("fsreadonly");
			my $filesystemRW = $node -> getAttribute("fsreadwrite");
			if ((defined $filesystemRO) && (defined $filesystemRW)) {
				$record{filesystem} = "$filesystemRW,$filesystemRO";
			}
		}
		$result{$prim} = \%record;
		$count++;
	}
	if (! defined $this->{imageWhat}) {
		if (defined $result{primary}) {
			return $result{primary};
		} else {
			return $result{$first};
		}
	}
	if ($ptype eq $this->{imageWhat}) {
		return $result{primary};
	} else {
		return $result{$this->{imageWhat}};
	}
}

#==========================================
# getImageVersion
#------------------------------------------
sub getImageVersion {
	# ...
	# Get the version of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $version = $node -> getElementsByTagName ("version");
	return $version;
}

#==========================================
# getDeployUnionConfig
#------------------------------------------
sub getDeployUnionConfig {
	# ...
	# Get the union file system configuration, if any
	# ---
	my $this = shift;
	my %config = ();
	my $node = $this->{unionNodeList} -> get_node(1);
	if (! $node) {
		return %config;
	}
	$config{ro}   = $node -> getAttribute ("ro");
	$config{rw}   = $node -> getAttribute ("rw");
	$config{type} = $node -> getAttribute ("type");
	return %config;
}

#==========================================
# getDeployImageDevice
#------------------------------------------
sub getDeployImageDevice {
	# ...
	# Get the device the image will be installed to
	# ---
	my $this = shift;
	my $node = $this->{partitionsNodeList} -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("device");
	} else {
		return undef;
	}
}

#==========================================
# getDeployServer
#------------------------------------------
sub getDeployServer {
	# ...
	# Get the server the config data is obtained from
	# ---
	my $this = shift;
	my $node = $this->{deploysNodeList} -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("server");
	} else {
		return "192.168.1.1";
	}
}

#==========================================
# getDeployBlockSize
#------------------------------------------
sub getDeployBlockSize {
	# ...
	# Get the block size the deploy server should use
	# ---
	my $this = shift;
	my $node = $this->{deploysNodeList} -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("blocksize");
	} else {
		return "4096";
	}
}

#==========================================
# getDeployPartitions
#------------------------------------------
sub getDeployPartitions {
	# ...
	# Get the partition configuration for this image
	# ---
	my $this = shift;
	my $partitionNodes = $this->{partitionsNodeList} -> get_node(1)
		-> getElementsByTagName ("partition");
	my @result = ();
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
	return sort { $a->{number} cmp $b->{number} } @result;
}

#==========================================
# getDeployConfiguration
#------------------------------------------
sub getDeployConfiguration {
	# ...
	# Get the configuration file information for this image
	# ---
	my $this = shift;
	my @node = $this->{configfileNodeList} -> get_nodelist();
	my %result;
	foreach my $element (@node) {
		my $source = $element -> getAttribute("source");
		my $dest   = $element -> getAttribute("dest");
		$result{$source} = $dest;
	}
	return %result;
}

#==========================================
# getDeployTimeout
#------------------------------------------
sub getDeployTimeout {
	# ...
	# Get the boot timeout, if specified
	# ---
	my $this = shift;
	my $node = $this->{deploysNodeList} -> get_node(1);
	my $timeout = $node -> getElementsByTagName ("timeout");
	if ((defined $timeout) && ! ("$timeout" eq "")) {
		return $timeout;
	} else {
		return undef;
	}
}

#==========================================
# getDeployCommandline
#------------------------------------------
sub getDeployCommandline {
	# ...
	# Get the boot commandline, if specified
	# ---
	my $this = shift;
	my $node = $this->{deploysNodeList} -> get_node(1);
	my $cmdline = $node -> getElementsByTagName ("commandline");
	if ((defined $cmdline) && ! ("$cmdline" eq "")) {
		return $cmdline;
	} else {
		return undef;
	}
}

#==========================================
# getDeployKernel
#------------------------------------------
sub getDeployKernel {
	# ...
	# Get the deploy kernel, if specified
	# ---
	my $this = shift;
	my $node = $this->{deploysNodeList} -> get_node(1);
	my $kernel = $node -> getElementsByTagName ("kernel");
	if ((defined $kernel) && ! ("$kernel" eq "")) {
		return $kernel;
	} else {
		return undef;
	}
}

#==========================================
# getSplitPersistentFiles
#------------------------------------------
sub getSplitPersistentFiles {
	# ...
	# Get the persistent files/directories for split image
	# ---
	my $this = shift;
	my $node = $this->{splitNodeList} -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $persistNode = $node -> getElementsByTagName ("persistent")
		-> get_node(1);
	if (! defined $persistNode) {
		return @result;
	}
	my @fileNodeList = $persistNode -> getElementsByTagName ("file")
		-> get_nodelist();
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
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
	my $node = $this->{splitNodeList} -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $tempNode = $node -> getElementsByTagName ("temporary") -> get_node(1);
	if (! defined $tempNode) {
		return @result;
	}
	my @fileNodeList = $tempNode -> getElementsByTagName ("file")
		-> get_nodelist();
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
	}
	return @result;
}

#==========================================
# getSplitExceptions
#------------------------------------------
sub getSplitExceptions {
	# ...
	# Get the exceptions defined for temporary and/or persistent
	# split portions. If no exceptions defined return an empty list
	# ----
	my $this = shift;
	my $node = $this->{splitNodeList} -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $tempNode = $node -> getElementsByTagName ("temporary") -> get_node(1);
	if (! defined $tempNode) {
		return @result;
	}
	my @fileNodeList = $tempNode -> getElementsByTagName ("except")
		-> get_nodelist();
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
	}
	my $persistNode = $node -> getElementsByTagName ("persistent")
		-> get_node(1);
	if (! defined $persistNode) {
		return @result;
	}
	@fileNodeList = $persistNode -> getElementsByTagName ("except")
		-> get_nodelist();
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
	}
	return @result;
}

#==========================================
# getDeployInitrd
#------------------------------------------
sub getDeployInitrd {
	# ...
	# Get the deploy initrd, if specified
	# ---
	my $this = shift;
	my $node = $this->{deploysNodeList} -> get_node(1);
	my $initrd = $node -> getElementsByTagName ("initrd");
	if ((defined $initrd) && ! ("$initrd" eq "")) {
		return $initrd;
	} else {
		return undef;
	}
}

#==========================================
# getCompressed
#------------------------------------------
sub getCompressed {
	# ...
	# Check if the image should be compressed or not. The
	# method returns true if the image should be compressed
	# otherwise false. 
	# ---
	my $this = shift;
	my $quiet= shift;
	my $kiwi = $this->{kiwi};
	my %type = %{$this->getImageTypeAndAttributes()};
	if ("$type{type}" eq "vmx") {
		if (defined $quiet) {
			return 0;
		}
		$kiwi -> info ("Virtual machine type: ignoring compressed flag");
		$kiwi -> done ();
		return 0;
	}
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $gzip = $node -> getElementsByTagName ("compressed");
	if ((defined $gzip) && ("$gzip" eq "yes")) {
		return 1;
	}
	return 0;
}

#==========================================
# setCompressed
#------------------------------------------
sub setCompressed {
	# ...
	# Set compressed element to yes or no. Sometimes the
	# compression state of an image needs to be adapted according
	# to the output image type
	# ---
	my $this  = shift;
	my $value = shift;
	if (($value ne "no") && ($value ne "yes")) {
		return $this;
	}
	my $addElement = new XML::LibXML::Element ("compressed");
	$addElement -> appendText ($value);
	my $opts = $this->{optionsNodeList} -> get_node(1);
	my $node = $opts -> getElementsByTagName ("compressed") -> get_node(1);
	$opts -> removeChild ($node);
	$opts -> appendChild ($addElement);
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
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $pmgr = $node -> getElementsByTagName ("packagemanager");
	if (! $pmgr) {
		return $packageManager{default};
	}
	foreach my $manager (keys %packageManager) {
		if ("$pmgr" eq "$manager") {
			my $file = $packageManager{$manager};
			if (! -f $file) {
				$kiwi -> failed ();
				$kiwi -> error  ("Package manager $file doesn't exist");
				$kiwi -> failed ();
				return undef;
			}
			return $manager;
		}
	}
	$kiwi -> failed ();
	$kiwi -> error  ("Invalid package manager: $pmgr");
	$kiwi -> failed ();
	return undef;
}

#==========================================
# getLocale
#------------------------------------------
sub getLocale {
	# ...
	# Obtain the locale value or return undef
	# ---
	my $this = shift;
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $lang = $node -> getElementsByTagName ("locale");
	if ((! defined $lang) || ("$lang" eq "")) {
		return undef;
	}
	return $lang;
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
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $sigs = $node -> getElementsByTagName ("rpm-check-signatures");
	if ((! defined $sigs) || ("$sigs" eq "")) {
		return undef;
	}
	return $sigs;
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
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $frpm = $node -> getElementsByTagName ("rpm-force");
	if ((! defined $frpm) || ("$frpm" eq "")) {
		return undef;
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
		my @ntag  = $element -> getElementsByTagName ("user") -> get_nodelist();
		foreach my $element (@ntag) {
			my $name = $element -> getAttribute ("name");
			my $pwd  = $element -> getAttribute ("pwd");
			my $home = $element -> getAttribute ("home");
			my $realname = $element -> getAttribute ("realname");
			my $shell = $element -> getAttribute ("shell");
			if (defined $name) {
				$result{$name}{group} = $group;
				$result{$name}{home}  = $home;
				$result{$name}{pwd}   = $pwd;
				$result{$name}{realname} = $realname;
				$result{$name}{shell} = $shell;
			}
		}
	}
	return %result;
}

#==========================================
# getProfiles
#------------------------------------------
sub getProfiles {
	# ...
	# Receive a list of profiles available for this image
	# ---
	my $this = shift;
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
		
		my %profile = ();
		$profile{name} = $name;
		$profile{description} = $desc;
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
				if (! defined $pref) {
					$kiwi -> failed ();
				}
				$kiwi -> error  ("Profile $requested: not found");
				$kiwi -> failed ();
				return undef;
			}
		}
	}
	if (@prequest) {
		if (! defined $pref) {
			$kiwi -> done ();
		}
		$kiwi -> info ("Using profile(s): @prequest");
		if (defined $pref) {
			$kiwi -> done ();
		}
	}
	return $this;
}

#==========================================
# requestedProfile
#------------------------------------------
sub requestedProfile {
	# ...
	# Return a boolean representing whether or not
	# a given element is requested to be included
	# in this image.
	# ---
	my $this = shift;
	my $element = shift;
	if (! defined $element) {
		return 1;
	}
	my $profiles = $element -> getAttribute ("profiles");
	if (! defined $profiles) {
		# If no profile is specified, then it is assumed
		# to be in all profiles.
		return 1;
	}
	if ((scalar $this->{reqProfiles}) == 0) {
		# element has a profile, but no profiles requested
		# so exclude it.
		return 0;
	}
	my @splitProfiles = split(/,/, $profiles);
	my %profileHash = ();
	foreach my $profile (@splitProfiles) {
		$profileHash{$profile} = 1;
	}
	foreach my $reqprof (@{$this->{reqProfiles}}) {
		# strip whitespace
		$reqprof =~ s/^\s+//s;
		$reqprof =~ s/\s+$//s;
		if (defined $profileHash{$reqprof}) {
			return 1;
		}
	}
	return 0;
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
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> resolveLink ( $stag -> getAttribute ("path") );
		if (! defined $name) {
			$name = "noname";
		}
		$result{$name}{source}   = $source;
		$result{$name}{priority} = $prio;
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
	my $this = shift;
	my $base = $this->{instsrcNodeList} ->  get_node(1);
	my $attr = $base->getAttribute ("arch");
	return split (",",$attr);
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
		my $type = $element -> getAttribute("type");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> resolveLink ( $stag -> getAttribute ("path") );
		$result{$source} = $type;
	}
	return %result;
}

#==========================================
# setValidateRepositoryType
#------------------------------------------
sub setValidateRepositoryType {
	# ...
	# check the source URL and the used repo type. in case of
	# opensuse:// we have to use the rpm-md repo type because the
	# openSUSE buildservice repositories are no valid yast2 repos
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @node = $this->{repositNodeList} -> get_nodelist();
	foreach my $element (@node) {
		my $type = $element -> getAttribute("type");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> resolveLink ( $stag -> getAttribute ("path") );
	}
	return $this;
}

#==========================================
# ignoreRepositories
#------------------------------------------
sub ignoreRepositories {
	# ...
	# Ignore all the repositories in the XML file.
	# ---
	my $this = shift;
	$this->{repositNodeList} = new XML::LibXML::NodeList;
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
	my $element = $this->{repositNodeList} -> get_node(1);
	if (defined $type) {
		$element -> setAttribute ("type",$type);
	}
	if (defined $path) {
		$element -> getElementsByTagName ("source")
			-> get_node (1) -> setAttribute ("path",$path);
	}
	$this -> createURLList();
	return $this;
}

#==========================================
# addRepository
#------------------------------------------
sub addRepository {
	# ...
	# Add a repository node to the current list of repos
	# this is done by reading the config.xml file again and
	# overwriting the first repository node with the new data
	# A new object XML::LibXML::NodeList is created which
	# contains the changed element. The element is then appended
	# the the global repositNodeList
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @type = @{$_[0]};
	my @path = @{$_[1]};
	foreach my $path (@path) {
		my $type = shift @type;
		if (! defined $type) {
			$kiwi -> error   ("No type for repo [$path] specified");
			$kiwi -> skipped ();
			next;
		}
		my $tempXML  = new XML::LibXML;
		my $xaddXML  = new XML::LibXML::NodeList;
		my $tempFile = $this->{imageDesc}."/config.xml";
		my $tempTree = $tempXML -> parse_file ( $tempFile );
		my $temprepositNodeList = $tempTree->getElementsByTagName("repository");
		my $element = $temprepositNodeList->get_node(1);
		$element -> setAttribute ("type",$type);
		$element -> setAttribute ("status","fixed");
		$element -> getElementsByTagName ("source") -> get_node (1)
			 -> setAttribute ("path",$path);
		$xaddXML -> push ( $element );
		$this->{repositNodeList} -> append ( $xaddXML );
	}
	return $this;
}

#==========================================
# addImagePackages
#------------------------------------------
sub addImagePackages {
	# ...
	# Add the given package list to the type=bootstrap packages
	# section of the config.xml parse tree.
	# ----
	my $this  = shift;
	my @packs = @_;
	my $nodes = $this->{packageNodeList};
	my $nodeNumber = 1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if ($type eq "bootstrap") {
			$nodeNumber = $i; last;
		}
	}
	foreach my $pack (@packs) {
		my $addElement = new XML::LibXML::Element ("package");
		$addElement -> setAttribute("name",$pack);
		$this->{packageNodeList} -> get_node($nodeNumber)
			-> addChild ($addElement);
	}
	return $this;
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
	#==========================================
	# preferences
	#------------------------------------------
	if (getCompressed ($this,"quiet")) {
		$result{compressed} = "yes";
	}
	my %type = %{$this->getImageTypeAndAttributes()};
	my @delp = $this -> getDeleteList();
	my $iver = getImageVersion ($this);
	my $size = getImageSize    ($this);
	my $name = getImageName    ($this);
	if (@delp) {
		$result{delete} = join(" ",@delp);
	}
	if (%type) {
		$result{type} = $type{type};
	}
	if ($size) {
		$result{size} = $size;
	}
	if ($name) {
		$result{name} = $name;
	}
	if ($iver) {
		$result{version} = $iver;
	}
	#==========================================
	# drivers
	#------------------------------------------
	my @node = $this->{driversNodeList} -> get_nodelist();
	foreach my $element (@node) {
		my $type = $element -> getAttribute("type");
		if (! $this -> requestedProfile ($element)) {
			next;
		}
		my @ntag = $element -> getElementsByTagName ("file") -> get_nodelist();
		my $data = "";
		foreach my $element (@ntag) {
			my $name =  $element -> getAttribute ("name");
			$data = $data.",".$name
		}
		$data =~ s/^,+//;

		if (defined $result{$type}) {
			$result{$type} .= ",".$data;
		} else {
			$result{$type} = $data;
		}
	}
	#==========================================
	# preferences options
	#------------------------------------------
	my $node = $this->{optionsNodeList} -> get_node(1);
	my $keytable = $node -> getElementsByTagName ("keytable");
	my $timezone = $node -> getElementsByTagName ("timezone");
	my $language = $node -> getElementsByTagName ("locale");
	if (defined $keytable) {
		$result{keytable} = $keytable;
	}
	if (defined $timezone) {
		$result{timezone} = $timezone;
	}
	if (defined $language) {
		$result{language} = $language;
	}
	#==========================================
	# profiles
	#------------------------------------------
	if (defined $this->{reqProfiles}) {
		$result{profiles} = join ",", @{$this->{reqProfiles}};
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
	my %result;
	for (my $i=1;$i<= $this->{packageNodeList}->size();$i++) {
		my $node = $this->{packageNodeList} -> get_node($i);
		my $type = $node -> getAttribute ("type");
		if ($type ne $what) {
			next;
		}
		my $ptype = $node -> getAttribute ("patternType");
		if (! defined $ptype) {
			$ptype = "onlyRequired";
		}
		my $ppactype = $node -> getAttribute ("patternPackageType");
		if (! defined $ppactype) {
			$ppactype = "onlyRequired";
		}
		$result{patternType} = $ptype;
		$result{patternPackageType} = $ppactype;
		$result{type} = $type;
		if (($type eq "xen") || ($type eq "vmware")) {
			my $memory  = $node -> getAttribute ("memory");
			my $disk    = $node -> getAttribute ("disk");
			if ((! $memory) || (! $disk)) {
				$kiwi -> warning ("Missing $type virtualisation config data");
				$kiwi -> skipped ();
				return undef;
			}
			$result{memory}  = $memory;
			$result{disk}    = $disk;
		}
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
	}
	my %result;
	my @attrib = (
		"priority" ,"addarch","removearch",
		"forcearch","source" ,"script"
	);
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node  = $nodes -> get_node($i);
		my @plist = $node  -> getElementsByTagName ("repopackage");
		foreach my $element (@plist) {
			my $package = $element -> getAttribute ("name");
			if ($package ne $pack) {
				next;
			}
			foreach my $key (@attrib) {
				my $value = $element -> getAttribute ($key);
				if (defined $value) {
					$result{$key} = $value;
				}
			}
			return \%result;
		}
	}
	return undef;
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
	my $kiwi = $this->{kiwi};
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
	for (my $i=1;$i<= $nodes->size();$i++) {
		#==========================================
		# Get type and packages
		#------------------------------------------
		my $node = $nodes -> get_node($i);
		my $type;
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
		if (! $this -> requestedProfile ($node)) {
			next;
		}
		my @plist = ();
		if (($what ne "metapackages") && ($what ne "instpackages")) {
			@plist = $node -> getElementsByTagName ("package");
		} else {
			@plist = $node -> getElementsByTagName ("repopackage");
		}
		foreach my $element (@plist) {
			my $package = $element -> getAttribute ("name");
			my $forarch = $element -> getAttribute ("arch");
			my $allowed = 1;
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
			if (! $allowed) {
				next;
			}
			if (! defined $package) {
				next;
			}
			push @result,$package;
		}
		#==========================================
		# Check for pattern descriptions
		#------------------------------------------
		if ($type ne "metapackages") {
			my @slist = $node -> getElementsByTagName ("opensusePattern");
			my @pattlist = ();
			my $manager  = $this -> getPackageManager();
			foreach my $element (@slist) {
				my $pattern = $element -> getAttribute ("name");
				if (! defined $pattern) {
					next;
				}
				push @pattlist,$pattern;
			}
			if (@pattlist) {
				if ($manager ne "zypper") {
					#==========================================
					# turn patterns into pacs for this manager
					#------------------------------------------
					# 1) try to use libsatsolver...
					my $psolve = new KIWISatSolver (
						$kiwi,$this,\@pattlist,$this->{urllist}
					);
					if (! defined $psolve) {
						# 2) use generic pattern module
						$kiwi -> warning (
							"SaT solver setup failed, using generic module"
						);
						$kiwi -> skipped ();
						$psolve = new KIWIPattern (
							$kiwi,\@pattlist,$this->{urllist},
							$pattr{patternType},$pattr{patternPackageType}
						);
					}
					if (! defined $psolve) {
						my $e1 ="Pattern match failed for arch: $this->{arch}";
						my $e2 ="Check if the pattern is written correctly?";
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
					# zypper knows about patterns
					#------------------------------------------
					foreach my $pname (@pattlist) {
						$kiwi -> info ("--> Requesting pattern: $pname");
						push @result,"pattern:".$pname;
						$kiwi -> done();
					}
				}
			}
		}
		#==========================================
		# Check for ignore list
		#------------------------------------------
		my @ilist = $node -> getElementsByTagName ("ignore");
		my @ignorelist = ();
		foreach my $element (@ilist) {
			my $ignore = $element -> getAttribute ("name");
			if (! defined $ignore) {
				next;
			}
			push @ignorelist,$ignore;
		}
		if (@ignorelist) {
			my %keylist = ();
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
				$keylist{$element} = $element;
			}
			@result = keys %keylist;
		}
	}
	#==========================================
	# Create unique list
	#------------------------------------------
	my %packHash = ();
	foreach my $package (@result) {
		$packHash{$package} = $package;
	}
	return sort keys %packHash;
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
	return getList ($this,"delete");
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
# getXenList
#------------------------------------------
sub getXenList {
	# ...
	# Create virtualisation package list needed to run that
	# image within a Xen virtualized system
	# ---
	my $this = shift;
	return getList ($this,"xen");
}

#==========================================
# getVMwareList
#------------------------------------------
sub getVMwareList {
	# ...
	# Create virtualisation package list needed to run that
	# image within VMware
	# ---
	my $this = shift;
	return getList ($this,"vmware");
}

#==========================================
# getForeignNodeList
#------------------------------------------
sub getForeignNodeList {
	# ...
	# Return the current <repository> list which consists
	# of XML::LibXML::Element object pointers
	# ---
	my $this = shift;
	return $this->{repositNodeList};
}

#==========================================
# getImageInheritance
#------------------------------------------
sub setupImageInheritance {
	# ...
	# check if there is a configuration specified to inherit
	# data from. The method will read the inherited description
	# and prepend the data to this object. Currently only the
	# <packages> nodes are used from the base description
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $path = $this -> getImageInherit();
	if (! defined $path) {
		return $this;
	}
	$kiwi -> info ("--> Inherit: $path ");
	if (defined $KIWIXML::inheritanceHash{$path}) {
		$kiwi -> skipped();
		return $this;
	}
	my $ixml = new KIWIXML ( $kiwi,$path );
	if (! defined $ixml) {
		return undef;
	}
	my $name = $ixml -> getImageName();
	$kiwi -> note ("[$name]");
	$this->{packageNodeList} -> prepend (
		$ixml -> getPackageNodeList()
	);
	$kiwi -> done();
	$KIWIXML::inheritanceHash{$path} = 1;
	$ixml -> setupImageInheritance();
	#return $this;
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
	if ($this->{arch} =~ /i.86/) {
		$this->{arch} = "i386";
	}
	$path =~ s/\%arch/$this->{arch}/;
	return $path;
}

#==========================================
# getPackageNodeList
#------------------------------------------
sub getPackageNodeList {
	my $this = shift;
	return $this->{packageNodeList};
}

#==========================================
# createTmpDirectory
#------------------------------------------
sub createTmpDirectory {
	my $this     = shift;
	my $useRoot  = shift;
	my $selfRoot = shift;
	my $baseRoot = shift;
	my $baseRootMode = shift;
	my $rootError = 1;
	my $root;
	my $code;
	my $kiwi = $this->{kiwi};
	if ((defined $baseRootMode) && ($baseRootMode eq "recycle")) {
		$useRoot = $baseRoot;
	}
	if (! defined $useRoot) {
		if (! defined $selfRoot) {
			$root = qxx (" mktemp -q -d /tmp/kiwi.XXXXXX ");
			$code = $? >> 8;
			if ($code == 0) {
				$rootError = 0;
			}
			chomp $root;
		} else {
			$root = $selfRoot;
			rmdir $root;
			if ( -e $root && -d $root && $main::ForceNewRoot ) {
				$kiwi -> info ("Removing old root directory '$root'");
				if (-e $root."/base-system") {
					$kiwi -> failed();
					$kiwi -> info  ("Mount point /base-system exists");
					$kiwi -> failed();
					return undef;
				}
				qxx ("rm -R $root");
				$kiwi -> done();
			}
			if (mkdir $root) {
				$rootError = 0;
			}
		}
	} else {
		if (-d $useRoot) { 
			$root = $useRoot;
			$rootError = 0;
		}
	}
	if ( $rootError ) {
		return undef;
	}
	my $origroot = $root;
	my $overlay;
	if (defined $baseRoot) {
		if ((defined $baseRootMode) && ($baseRootMode eq "union")) {
			$kiwi -> info("Creating overlay path [$root(rw) + $baseRoot(ro)] ");
		} elsif ((defined $baseRootMode) && ($baseRootMode eq "recycle")) {
			$kiwi -> info("Using overlay path $baseRoot");
		} else {
			$kiwi -> info("Importing overlay path $baseRoot -> $root");
		}
		$overlay = new KIWIOverlay ( $kiwi,$baseRoot,$root );
		if (! defined $overlay) {
			$rootError = 1;
		}
		if (defined $baseRootMode) {
			$overlay -> setMode ($baseRootMode);
		}
		$root = $overlay -> mountOverlay();
		if (! defined $root) {
			$rootError = 1;
		}
		if ($rootError) {
			$kiwi -> failed;
		} else {
			if ((defined $baseRootMode) && ($baseRootMode eq "union")) {
				$kiwi -> note ("-> $root");
			}
			$kiwi -> done ();
		}
	}
	if ( $rootError ) {
		return undef;
	}
	return ($root,$origroot,$overlay);
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
		return undef;
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
		return undef;
	}
	#==========================================
	# check base and dir name
	#------------------------------------------
	if (! $basename) {
		return undef;
	}
	if (! -d $dirname) {
		return undef;
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
		my $response = $browser  -> request ( $request );
		my $content  = $response -> content ();
		my @lines    = split (/\n/,$content);
		foreach my $line(@lines) {
			if ($line !~ /href=\"(.*)\"/) {
				next;
			}
			my $link = $1;
			if ($link =~ /$search/) {
				$url  = $location.$link;
				print ("NEXT\n");
				$data = qxx ("lwp-download $url $dest 2>&1");
				$code = $? >> 8;
				if ($code == 0) {
					return $this;
				}
			}
		}
		return undef;
	} else {
		return undef;
	}
	return $this;
}

#==========================================
# getInstSourceSatSolvable
#------------------------------------------
sub getInstSourceSatSolvable {
	# /.../
	# This function will return an uncompressed solvable record
	# for the given repository list. If it's required to create
	# this solvable because it doesn't exist on the repository
	# the satsolver toolkit is used and therefore required in
	# order to allow this function to work correctly
	# ----
	my $this     = shift;
	my $repos    = shift;
	my $kiwi     = $this->{kiwi};
	my $patternd = "/suse/setup/descr/";
	my $patterns = "/suse/setup/descr/patterns";
	my $packages = "/suse/setup/descr/packages.gz";
	my $solvable = "/suse/setup/descr/primary.gz";
	my $count    = 0;
	my $index    = 0;
	my @index    = ();
	my $error    = 0;
	#==========================================
	# check for sat tools
	#------------------------------------------
	if ((! -x "/usr/bin/mergesolv") || (! -x "/usr/bin/susetags2solv")) {
		$kiwi -> error  ("--> Can't find satsolver tools");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# check/create cache directory
	#------------------------------------------
	my $sdir = "/var/cache/kiwi/satsolver";
	if (! -d $sdir) {
		my $data = qxx ("mkdir -p $sdir 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("--> Couldn't create cache dir: $data");
			$kiwi -> failed ();
			return undef;
		}
	}
	#==========================================
	# check/create solvable index file
	#------------------------------------------
	foreach my $repo (@{$repos}) {
		#==========================================
		# create directory listing for each repo
		#------------------------------------------
		my $destfile = $sdir."/listing";
		if (! $this -> getInstSourceFile ($repo.$patternd,$destfile)) {
			next;
		}
		#==========================================
		# check if this is a valid suse repo
		#------------------------------------------
		if (! open (FD,$destfile)) {
			unlink $destfile; next;
		}
		my $repoOK = -1;
		foreach my $line (<FD>) {
			if ($line =~ /\"primary.gz\"/) {
				$repoOK = 1; last;
			}
			if ($line =~ /\"packages.gz\"/) {
				$repoOK++;
			}
			if ($line =~ /\"patterns\"/) {
				$repoOK++;
			}
		}
		if ($repoOK) {
			push (@index,$repo);
		}
		close FD;
		unlink $destfile;
	}
	@index = sort (@index);
	$index = join (":",@index);
	$index = qxx ("echo $index | md5sum | cut -f1 -d-");
	$index = $sdir."/".$index; chomp $index;
	$index=~ s/ +$//;
	if (-f $index) {
		return $index;
	}
	#==========================================
	# find system architecture
	#------------------------------------------
	my $arch = qxx ("uname -m"); chomp $arch;
	if ($arch =~ /^i.86/) {
		$arch = 'i.86';
	}
	my $destfile;
	my $scommand;
	foreach my $repo (@{$repos}) {
		$count++;
		#==========================================
		# check for pre-created solvable first
		#------------------------------------------
		$destfile = $sdir."/primary-".$count.".gz";
		if ($this -> getInstSourceFile ($repo.$solvable,$destfile)) {
			next;
		}
		#==========================================
		# get patterns file next
		#------------------------------------------
		$destfile = $sdir."/patterns-".$count;
		if (! $this -> getInstSourceFile ($repo.$patterns,$destfile)) {
			$kiwi -> warning ("--> No patterns file on repo: $repo");
			$kiwi -> skipped ();
			next;
		}
		#==========================================
		# get files listed in patterns
		#------------------------------------------
		my $patfile = $destfile;
		if (! open (FD,$patfile)) {
			$kiwi -> warning ("--> Couldn't open patterns file: $!");
			$kiwi -> skipped ();
			unlink $patfile;
			next;
		}
		foreach my $line (<FD>) {
			chomp $line; $destfile = $sdir."/".$line;
			if ($line !~ /\.$arch\./) {
				next;
			}
			my $file = $repo.$patternd.$line;
			if (! $this -> getInstSourceFile($file,$destfile)) {
				$kiwi -> warning ("--> Pattern file $line not found");
				$kiwi -> skipped ();
				next;
			}
		}
		close FD;
		unlink $patfile;
		#==========================================
		# get packages.gz file next
		#------------------------------------------
		$destfile = $sdir."/packages-".$count.".gz";
		if (! $this -> getInstSourceFile ($repo.$packages,$destfile)) {
			$kiwi -> warning ("--> No packages.gz file on repo: $repo");
			$kiwi -> skipped ();
			next;
		}
	}
	$count++;
	#==========================================
	# create solvable from suse tags data
	#------------------------------------------
	if (-f "$sdir/packages-1.gz") {
		$destfile = $sdir."/primary-".$count;
		$scommand = "gzip -cd $sdir/packages-*.gz; gzip -cd $sdir/*.pat.gz";
		my $data = qxx ("($scommand) | susetags2solv > $destfile");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("--> Can't create SaT solvable file");
			$kiwi -> failed ();
			$error = 1;
		}
	}
	#==========================================
	# uncompress all pre-created solvables
	#------------------------------------------
	if (! $error) {
		foreach my $solvables (glob ("$sdir/primary-*.gz")) {
			my $data = qxx ("gzip -d $sdir/primary-*.gz");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> error  ("--> Couldn't uncompress solve files");
				$kiwi -> failed ();
				$error = 1;
			}
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
				$kiwi -> error  ("--> Couldn't merge solve files");
				$kiwi -> failed ();
				$error = 1;
			}
		}
	}
	#==========================================
	# cleanup cache dir
	#------------------------------------------
	qxx ("rm -f $sdir/primary-*");
	qxx ("rm -f $sdir/packages-*.gz");
	qxx ("rm -f $sdir/*.pat.gz");
	if (! $error) {
		return $index;
	}
	return undef;
}

1;
