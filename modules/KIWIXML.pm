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
use KIWILog;
use KIWIPattern;
use KIWIManager qw (%packageManager);

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
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if ($imageDesc !~ /\//) {
		$imageDesc = $main::System."/".$imageDesc;
	}
	my $arch = qx ( arch ); chomp $arch;
	my $systemTree;
	my $schemeTree;
	my $controlFile = $imageDesc."/config.xml";
	my $schemeXML   = new XML::LibXML;
	my $systemXML   = new XML::LibXML;
	my $systemXSD   = new XML::LibXML::Schema ( location => $main::Scheme );
	if (! -f $controlFile) {
		$kiwi -> failed ();
		$kiwi -> error ("Cannot open control file: $controlFile");
		$kiwi -> failed ();
		return undef;
	}
	my $schemeNodeList;
	eval {
		$schemeTree = $schemeXML
			-> parse_file ( $main::Scheme );
		$schemeNodeList = $schemeTree -> getElementsByTagName ("xs:schema");
	};
	if ($@) {
		$kiwi -> failed ();
		$kiwi -> error  ("Problem reading scheme description");
		$kiwi -> failed ();
		$kiwi -> error  ("$@\n");
		return undef;
	}
	my $optionsNodeList;
	my $driversNodeList;
	my $usrdataNodeList;
	my $repositNodeList;
	my $packageNodeList;
	my $imgnameNodeList;
	my $deploysNodeList;
	my $instsrcNodeList;
	my $partitionsNodeList;
	my $configfileNodeList;
	my $unionNodeList;
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
		$instsrcNodeList = $systemTree -> getElementsByTagName ("instsource");
		$partitionsNodeList = $systemTree 
			-> getElementsByTagName ("partitions");
		$configfileNodeList = $systemTree 
			-> getElementsByTagName("configuration");
		$unionNodeList = $systemTree -> getElementsByTagName ("union");
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
		$systemXSD ->validate ( $systemTree );
	};
	if ($@) {
		$kiwi -> failed ();
		$kiwi -> error  ("Scheme validation failed");
		$kiwi -> failed ();
		$kiwi -> error  ("$@\n");
		return undef;
	}
	#==========================================
	# Check version information of the scheme
	#------------------------------------------
	my $schemeVers = $schemeNodeList -> get_node (1)
		-> getAttribute ("version");
	if ($main::SchemeVersion ne $schemeVers) {
		$kiwi -> failed ();
		$kiwi -> error  ("*** XML Scheme version mismatch ***\n");
		$kiwi -> error  ("Need v$main::SchemeVersion got v$schemeVers");
		$kiwi -> failed ();
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
	$this->{instsrcNodeList}    = $instsrcNodeList;
	$this->{partitionsNodeList} = $partitionsNodeList;
	$this->{configfileNodeList} = $configfileNodeList;
	$this->{schemeNodeList}     = $schemeNodeList;
	$this->{unionNodeList}      = $unionNodeList;
	$this->{schemeVers}         = $schemeVers;
	$this->{arch}               = $arch;

	#==========================================
	# Store object data (create URL list)
	#------------------------------------------
	$this -> createURLList ();

	#==========================================
	# Check type information from xml input
	#------------------------------------------
	if (! $this -> getImageTypeAndAttributes()) {
		$kiwi -> failed ();
		$kiwi -> error  ("Boot type: $imageWhat not specified in config.xml");
		$kiwi -> failed ();
		return undef;
	}
	return $this;
}

#==========================================
# createURLList
#------------------------------------------
sub createURLList {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $foreignRepo = $this->{foreignRepo};
	my %repository  = $this->getRepository();
	my @urllist     = ();
	foreach my $source (keys %repository) {
		my $urlHandler;
		if ( defined $foreignRepo->{prepare} ) {
			$urlHandler = new KIWIURL ($kiwi,$foreignRepo->{prepare});
		} else {
			$urlHandler = new KIWIURL ($kiwi,$this->{imageDesc});
		}
		my $publics_url = $source;
		my $highlvl_url = $urlHandler -> openSUSEpath ($publics_url);
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
		$highlvl_url = $urlHandler -> thisPath ($publics_url);
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
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
	my $unit = $node -> getElementsByTagName ("size")
		-> get_node(1) -> getAttribute("unit");
	return $size.$unit;
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
	my %result = ();
	my $count  = 0;
	my $first  = "";
	my @node   = $this->{optionsNodeList} -> get_node(1)
		-> getElementsByTagName ("type");
	foreach my $node (@node) {
		my %record = ();
		my $prim = $node -> getAttribute("primary");
		if ((! defined $prim) || ($prim eq "false") || ($prim eq "0")) {
			$prim = $node -> string_value();
		} else {
			$prim = "primary";
		}
		if ($count == 0) {
			$first = $prim;
		}
		$record{type} = $node -> string_value();
		$record{boot} = $node -> getAttribute("boot");
		$record{flags}= $node -> getAttribute("flags");
		$record{filesystem} = $node -> getAttribute("filesystem");
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
	return $result{$this->{imageWhat}};
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
	my $node = $this->{unionNodeList} -> get_node(1);
	if (!defined $node) {
		return undef;
	}
	my %config = ();
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
# getPackageManager
#------------------------------------------
sub getPackageManager {
	# ...
	# Get the name of the package manager if set.
	# if not set set return the default package
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
			if (defined $name) {
				$result{$name}{group} = $group;
				$result{$name}{home}  = $home;
				$result{$name}{pwd}   = $pwd;
			}
		}
	}
	return %result;
}

#==========================================
# getMetaRepository
#------------------------------------------
sub getMetaRepository {
	# ...
	# Get the repository type used for building
	# up an installation source tree. For information on the
	# available types refer to the package manager documentation
	# ---
	my $this = shift;
	my %result;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	if (! defined $base) {
		return %result;
	}
	my @node = $base -> getElementsByTagName ("metadata");
	foreach my $element (@node) {
		my $type = $element -> getAttribute("type");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> resolveLink ( $stag -> getAttribute ("path") );
		$result{$source} = $type;
	}
	return %result;
}

#==========================================
# getMetaTool
#------------------------------------------
sub getMetaTool {
	# ...
	# In order to be able to setup an installation source a tool
	# must be available to handle the downloaded packages correctly.
	# In case of suse a set of RPM packages must be unpacked using
	# rpm2cpio and other suse specific tasks may be needed. All this
	# is handled in the given tool which is different from one
	# distribution to another. Kiwi itself provdes only the suse
	# tool which is named suse-instsource
	# ---
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	if (! defined $base) {
		return undef;
	}
	my $element = $base -> getElementsByTagName ("srctool") -> get_node(1);
	my $tool = $element -> getAttribute("name");
	if (! $tool) {
		return undef;
	}
	return $tool;
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
	my $type = shift;
	my $path = shift;
	my $tempXML  = new XML::LibXML;
	my $xaddXML  = new XML::LibXML::NodeList;
	my $tempFile = $this->{imageDesc}."/config.xml";
	my $tempTree = $tempXML -> parse_file ( $tempFile );
	my $temprepositNodeList = $tempTree -> getElementsByTagName ("repository");
	my $element = $temprepositNodeList  -> get_node(1);
	$element -> setAttribute ("type",$type);
	$element -> setAttribute ("status","fixed");
	$element -> getElementsByTagName ("source") -> get_node (1)
		 -> setAttribute ("path",$path);
	$xaddXML -> push ( $element );
	$this->{repositNodeList} -> append ( $xaddXML );
	return $xaddXML;
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
	my $iver = getImageVersion ($this);
	my $size = getImageSize    ($this);
	my $name = getImageName    ($this);
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
		my @ntag = $element -> getElementsByTagName ("file") -> get_nodelist();
		my $data = "";
		foreach my $element (@ntag) {
			my $name =  $element -> getAttribute ("name");
			$data = $data.",".$name
		}
		$data =~ s/^,+//;
		$result{$type} = $data;
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
		my $ptype= $node -> getAttribute ("patternType");
		if (! defined $ptype) {
			$ptype = "onlyRequired";
		}
		$result{patternType} = $ptype;
		$result{type} = $type;
		if ($result{type} eq "xen") {
			my $memory  = $node -> getAttribute ("memory");
			my $disk    = $node -> getAttribute ("disk");
			if ((! $memory) || (! $disk)) {
				$kiwi -> warning ("Missing Xen virtualisation config data");
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
	if ($what ne "meta") {
		%pattr= getPackageAttributes ($this,$what);
	}
	if ($what ne "meta") {
		$nodes = $this->{packageNodeList};
	} else {
		$nodes = $this->{instsrcNodeList};
	}
	my @result;
	for (my $i=1;$i<= $nodes->size();$i++) {
		#==========================================
		# Get type and packages
		#------------------------------------------
		my $node = $nodes -> get_node($i);
		my $type;
		if ($what ne "meta") {
			$type = $node -> getAttribute ("type");
			if ($type ne $what) {
				next;
			}
		} else {
			$type = $what;
		}
		my @plist = $node -> getElementsByTagName ("package");
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
		if ($type ne "meta") {
			my @slist = $node -> getElementsByTagName ("opensusePattern");
			my @pattlist = ();
			foreach my $element (@slist) {
				my $pattern = $element -> getAttribute ("name");
				if (! defined $pattern) {
					next;
				}
				push @pattlist,$pattern;
			}
			if (@pattlist) {
				my $psolve = new KIWIPattern (
					$kiwi,\@pattlist,$this->{urllist},$pattr{patternType}
				);
				if (! defined $psolve) {
					return ();
				}
				my @packageList = $psolve -> getPackages();
				push @result,@packageList;
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
# getBaseMetaList
#------------------------------------------
sub getBaseMetaList {
	# ...
	# Create base package list needed to create the
	# installation source tree
	# ---
	my $this = shift;
	return getList ($this,"meta");
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
	return getList ($this,"boot");
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
	$ixml -> setupImageInheritance();
	#return $this;
}

#==========================================
# resolveLink
#------------------------------------------
sub resolveLink {
	my $this = shift;
	my $data = $this -> resolveArchitectur ($_[0]);
	my $cdir = qx (pwd); chomp $cdir;
	if (chdir $data) {
		my $pdir = qx (pwd); chomp $pdir;
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

1;
