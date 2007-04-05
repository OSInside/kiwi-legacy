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
# Private
#------------------------------------------
my $kiwi;
my $imageDesc;
my $optionsNodeList;
my $driversNodeList;
my $usrdataNodeList;
my $repositNodeList;
my $packageNodeList;
my $imgnameNodeList;
my $partitionsNodeList;
my @urllist;
my $arch;

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
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi = shift;
	$imageDesc = shift;
	my $otherRepo = shift;
	my %foreignRepo;
	if (defined $otherRepo) {
		 %foreignRepo = %{$otherRepo};
	}
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if ($imageDesc !~ /\//) {
		$imageDesc = $main::System."/".$imageDesc;
	}
	$arch = qx ( arch ); chomp $arch;
	my $systemTree;
	my $controlFile = $imageDesc."/config.xml";
	my $systemXML   = new XML::LibXML;
	my $systemXSD   = new XML::LibXML::Schema ( location => $main::Scheme );
	if (! -f $controlFile) {
		$kiwi -> failed ();
		$kiwi -> error ("Cannot open control file: $controlFile");
		$kiwi -> failed ();
		return undef;
	}
	eval {
		$systemTree = $systemXML
			-> parse_file ( $controlFile );
		$optionsNodeList = $systemTree -> getElementsByTagName ("preferences");
		$driversNodeList = $systemTree -> getElementsByTagName ("drivers");
		$usrdataNodeList = $systemTree -> getElementsByTagName ("users");
		$repositNodeList = $systemTree -> getElementsByTagName ("repository");
		$packageNodeList = $systemTree -> getElementsByTagName ("packages");
		$imgnameNodeList = $systemTree -> getElementsByTagName ("image");
		$partitionsNodeList = $systemTree -> getElementsByTagName("partitions");
	};
	if ($@) {
		$kiwi -> failed ();
		$kiwi -> error  ("Problem reading control file");
		$kiwi -> failed ();
		$kiwi -> error  ("$@\n");
		return undef;
	}
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
	if ( defined $foreignRepo{xmlnode} ) {
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
		$repositNodeList = $foreignRepo{xmlnode};
		$repositNodeList -> prepend ($need);
	}
	@urllist = ();
	my %repository = getRepository ($this);
	foreach my $source (keys %repository) {
		my $urlHandler;
		if ( defined $foreignRepo{prepare} ) {
			$urlHandler = new KIWIURL ($kiwi,$foreignRepo{prepare});
		} else {
			$urlHandler = new KIWIURL ($kiwi,$imageDesc);
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
	my $node = $imgnameNodeList -> get_node(1);
	my $name = $node -> getAttribute ("name");
	return $name;
}

#==========================================
# getImageInherit
#------------------------------------------
sub getImageInherit {
	my $this = shift;
	my $node = $imgnameNodeList -> get_node(1);
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
	my $node = $optionsNodeList -> get_node(1);
	my $size = $node -> getElementsByTagName ("size");
	my $unit = $node -> getElementsByTagName ("size")
		-> get_node(1) ->getAttribute("unit");
	return $size.$unit;
}

#==========================================
# getImageType
#------------------------------------------
sub getImageType {
	# ...
	# Get the filesystem type of the logical extend
	# ---
	my $this = shift;
	my $node = $optionsNodeList -> get_node(1);
	my $type = $node -> getElementsByTagName ("type");
	return $type;
}

#==========================================
# getImageVersion
#------------------------------------------
sub getImageVersion {
	# ...
	# Get the version of the logical extend
	# ---
	my $this = shift;
	my $node = $optionsNodeList -> get_node(1);
	my $version = $node -> getElementsByTagName ("version");
	return $version;
}

#==========================================
# getImageDevice
#------------------------------------------
sub getImageDevice {
	# ...
	# Get the device the image will be installed to
	# ---
	my $this = shift;
	my $node = $partitionsNodeList -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("device");
	} else {
		return undef;
	}
}

#==========================================
# getPartitions
#------------------------------------------
sub getPartitions {
	# ...
	# Get the partition configuration for this image
	# ---
	my $this = shift;
	my $partitionNodes = $partitionsNodeList -> get_node(1)
		-> getElementsByTagName ("partition");
	my @result = ();
	for (my $i=1;$i<= $partitionNodes->size();$i++) {
		my $node = $partitionNodes -> get_node($i);

		my $number = $node -> getAttribute ("number");
		my $type = $node -> getAttribute ("type");
		if (!defined $type) {
			$type = "linux";
		}
		
		my $size = $node -> getAttribute ("size");
		if (!defined $size) {
			$size = "x";
		}

		my $mountpoint = $node -> getAttribute ("mountpoint");
		if (!defined $mountpoint) {
			$mountpoint = "x";
		}

		my %part = ();
		$part{number} = $number;
		$part{type} = $type;
		$part{size} = $size;
		$part{mountpoint} = $mountpoint;

		push @result, { %part };
	}
	return sort { $a->{number} cmp $b->{number} } @result;
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
	my $type = getImageType();
	if ($type =~ /^vmx:/) {
		$kiwi -> info ("Virtual machine type: ignoring compressed flag");
		$kiwi -> done ();
		return 0;
	}
	my $node = $optionsNodeList -> get_node(1);
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
	my $node = $optionsNodeList -> get_node(1);
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
	my $node = $optionsNodeList -> get_node(1);
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
	my $node = $optionsNodeList -> get_node(1);
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
	my %result = ();
	my @node = $usrdataNodeList -> get_nodelist();
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
# getRepository
#------------------------------------------
sub getRepository {
	# ...
	# Get the repository type used for building
	# up the physical extend. For information on the available
	# types refer to the package manager documentation
	# ---
	my $this = shift;
	my @node = $repositNodeList -> get_nodelist();
	my %result;
	foreach my $element (@node) {
		my $type = $element -> getAttribute("type");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = resolveLink ( $stag -> getAttribute ("path") );
		$result{$source} = $type;
	}
	return %result;
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
	if (getCompressed ($this)) {
		$result{compressed} = "yes";
	}
	my $type = getImageType    ($this);
	my $iver = getImageVersion ($this);
	my $size = getImageSize    ($this);
	my $name = getImageName    ($this);
	if ($type) {
		$result{type} = $type;
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
	my @node = $driversNodeList -> get_nodelist();
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
	my %result;
	for (my $i=1;$i<= $packageNodeList->size();$i++) {
		my $node = $packageNodeList -> get_node($i);
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
	my %pattr= getPackageAttributes ($this,$what);
	my @result;
	for (my $i=1;$i<= $packageNodeList->size();$i++) {
		#==========================================
		# Get type and packages
		#------------------------------------------
		my $node = $packageNodeList -> get_node($i);
		my $type = $node -> getAttribute ("type");
		if ($type ne $what) {
			next;
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
					if ($archok eq $arch) {
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
				$kiwi,\@pattlist,\@urllist,$pattr{patternType}
			);
			if (! defined $psolve) {
				return ();
			}
			my @packageList = $psolve -> getPackages();
			push @result,@packageList;
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
	return $repositNodeList;
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
	$packageNodeList -> prepend (
		$ixml -> getPackageNodeList()
	);
	$kiwi -> done();
	$ixml -> setupImageInheritance();
#	return $this;    
}

#==========================================
# resolveLink
#------------------------------------------
sub resolveLink {
	my $data  = resolveArchitectur ($_[0]);
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
	my $path = shift;
	if ($arch =~ /i.86/) {
		$arch = "i386";
	}
	$path =~ s/\%arch/$arch/;
	return $path;
}

#==========================================
# getPackageNodeList
#------------------------------------------
sub getPackageNodeList {
	return $packageNodeList;
}

1;
