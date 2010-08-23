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
require Exporter;
use Carp qw (cluck);
use File::Glob ':glob';
use File::Basename;
use LWP;
use XML::LibXML;
use KIWILog;
use KIWIManager qw (%packageManager);
use KIWIOverlay;
use KIWIQX;
use KIWISatSolver;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (
	getInstSourceFile getInstSourceSatSolvable getSingleInstSourceSatSolvable
);

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
	my $controlFile = $imageDesc."/".$main::ConfigName;
	my $checkmdFile = $imageDesc."/.checksum.md5";
	my $havemd5File = 1;
	my $systemTree;
	#==========================================
	# Check all xml alternatives
	#------------------------------------------
	if (! -f $controlFile) {
		my @globsearch = glob ($imageDesc."/*.kiwi");
		my $globitems  = @globsearch;
		if ($globitems == 0) {
			$kiwi -> error ("Cannot open control file: $controlFile");
			$kiwi -> failed ();
			return undef;
		} elsif ($globitems > 1) {
			$kiwi -> error ("Found multiple *.kiwi control files");
			$kiwi -> failed ();
			return undef;
		} else {
			$controlFile = pop @globsearch;
		}
	}
	#==========================================
	# Check image md5 sum
	#------------------------------------------
	if (-f $checkmdFile) {
		my $data = qxx ("cd $imageDesc && md5sum -c .checksum.md5 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			chomp $data;
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
	my $systemRNG   = new XML::LibXML::RelaxNG ( location => $main::Schema );
	my $optionsNodeList;
	my $driversNodeList;
	my $usrdataNodeList;
	my $repositNodeList;
	my $packageNodeList;
	my $imgnameNodeList;
	my $instsrcNodeList;
	my $profilesNodeList;
	my $XML;
	my $skipXSLT = 0;
	if ($skipXSLT) {
		if (! open ($XML,"cat $controlFile|")) {
			$kiwi -> error ("XSL: Failed to open file $controlFile");
			$kiwi -> failed ();
			return undef;
		}
	} else {
		if (! open ($XML,"xsltproc $main::SchemaCVT $controlFile|")) {
			$kiwi -> error ("XSL: Failed to open xslt processor");
			$kiwi -> failed ();
			return undef;
		}
	}
	binmode $XML;
	eval {
		$systemTree = $systemXML -> parse_fh ( $XML );
	};
	if ($@) {
		my $evaldata = $@;
		$kiwi -> error  ("Problem reading control file");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Validate xml input with current schema
	#------------------------------------------
	eval {
		$systemRNG ->validate ( $systemTree );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  ("Schema validation failed");
		$kiwi -> failed ();
		my $configStr = $systemXML -> parse_file( $controlFile ) -> toString();
		my $upgradedStr = $systemTree -> toString();
		my $upgradedContolFile = $controlFile;
		if ($configStr ne $upgradedStr) {
			$upgradedContolFile =~ s/\.xml/\.converted\.xml/;
			$kiwi -> info ("Automatically upgraded $controlFile to");
			$kiwi -> info ("$upgradedContolFile\n");
			$kiwi -> info ("Reported line numbers may not match the ");
			$kiwi -> info ("file $controlFile\n");
			open (my $UPCNTFL, '>', $upgradedContolFile);
			print $UPCNTFL $upgradedStr;
			close ( $UPCNTFL );
		}
		my $jingExec = main::findExec('jing');
		if ($jingExec) {
			qxx ("$jingExec $main::Schema $upgradedContolFile 1>&2");
			return undef;
		} else {
			$kiwi -> error ("$evaldata\n");
			$kiwi -> info  ("Use the jing command for more details\n");
			$kiwi -> info  ("The following requires jing to be installed\n");
			$kiwi -> info  ("jing $main::Schema $upgradedContolFile\n");
			return undef;
		}
	}
	#==========================================
	# Read main XML sections
	#------------------------------------------
	$imgnameNodeList = $systemTree -> getElementsByTagName ("image");
	$optionsNodeList = $systemTree -> getElementsByTagName ("preferences");
	$driversNodeList = $systemTree -> getElementsByTagName ("drivers");
	$usrdataNodeList = $systemTree -> getElementsByTagName ("users");
	$repositNodeList = $systemTree -> getElementsByTagName ("repository");
	$packageNodeList = $systemTree -> getElementsByTagName ("packages");
	$profilesNodeList= $systemTree -> getElementsByTagName ("profiles");
	$instsrcNodeList = $systemTree -> getElementsByTagName ("instsource");
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{xmlOrigString}   = $systemTree -> toString();
	$this->{xmlOrigFile}     = $controlFile;
	$this->{kiwi}            = $kiwi;
	$this->{foreignRepo}     = $foreignRepo;
	$this->{optionsNodeList} = $optionsNodeList;
	$this->{imgnameNodeList} = $imgnameNodeList;
	$this->{systemTree}      = $systemTree;
	$this->{imageWhat}       = $imageWhat;
	$this->{reqProfiles}     = $reqProfiles;
	$this->{profilesNodeList}= $profilesNodeList;
	#==========================================
	# Check kiwirevision attribute
	#------------------------------------------
	if (open (my $FD,$main::Revision)) {
		my $cur_rev = <$FD>; close $FD;
		my $req_rev = $imgnameNodeList
			-> get_node(1) -> getAttribute ("kiwirevision");
		if ((defined $req_rev) && ($cur_rev < $req_rev)) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"KIWI revision too old, require r$req_rev got r$cur_rev"
			);
			$kiwi -> failed ();
			return undef;
		}
	}
	#==========================================
	# Check image version format
	#------------------------------------------
	my $version = $this -> getImageVersion();
	if ($version !~ /^\d+\.\d+\.\d+$/) {
		$kiwi -> error  ("Invalid version format: $version");
		$kiwi -> failed ();
		$kiwi -> error  ("Expected 'Major.Minor.Release'");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Apply default profiles from XML if set
	#------------------------------------------
	$this -> setDefaultProfiles();
	#==========================================
	# Check profile names
	#------------------------------------------
	if (! $this -> checkProfiles()) {
		return undef;
	}
	#==========================================
	# Check type information from xml input
	#------------------------------------------
	if ($optionsNodeList) {
		$this -> getImageTypeAndAttributes();
		if (! $this->{typeNode}) {
			$kiwi -> error  ("Boot type: $imageWhat not specified in xml");
			$kiwi -> failed ();
			return undef;
		}
	}
	#==========================================
	# Add default split section if not defined
	#------------------------------------------
	$this -> addDefaultSplitNode();
	#==========================================
	# Set global packagemanager value
	#------------------------------------------
	if (defined $main::PackageManager) {
		$this -> setPackageManager ($main::PackageManager);
	} else {
		$main::PackageManager = $this -> getPackageManager();
	}
	#==========================================
	# setup foreign XML sections
	#------------------------------------------
	if ( defined $foreignRepo->{xmlnode} ) {
		#==========================================
		# 1) foreign repositories
		#------------------------------------------
		$kiwi -> info ("Including foreign repository node(s)");
		my $need = new XML::LibXML::NodeList();
		my @node = $repositNodeList -> get_nodelist();
		foreach my $element (@node) {
			if (! $this -> requestedProfile ($element)) {
				next;
			}
			my $status = $element -> getAttribute("status");
			if ((! defined $status) || ($status eq "fixed")) {
				$need -> push ($element);
			}
		}
		$repositNodeList = $foreignRepo->{xmlnode};
		$repositNodeList -> prepend ($need);
		$kiwi -> done ();
		if ( defined $foreignRepo->{xmlpacnode} ) {
			#==========================================
			# 2) foreign image packages
			#------------------------------------------
			my @node = $foreignRepo -> {xmlpacnode} -> get_nodelist();
			my @plist;
			my @alist;
			my @falistImage;
			my @fplistImage;
			my @fplistDelete;
			foreach my $element (@node) {
				my $type = $element  -> getAttribute ("type");
				if (! $foreignRepo -> {xmlobj} -> requestedProfile ($element)) {
					next;
				}
				if (($type eq "image") || ($type eq "bootstrap")) {
					push (@plist,$element->getElementsByTagName ("package"));
					push (@alist,$element->getElementsByTagName ("archive"));
				}
			}
			foreach my $element (@plist) {
				my $package = $element -> getAttribute ("name");
				my $bootinc = $element -> getAttribute ("bootinclude");
				my $bootdel = $element -> getAttribute ("bootdelete");
				if ((defined $bootinc) && ("$bootinc" eq "true")) {
					push (@fplistImage,$package);
				}
				if ((defined $bootdel) && ("$bootdel" eq "true")) {
					push (@fplistDelete,$package);
				}
			}
			foreach my $element (@alist) {
				my $archive = $element -> getAttribute ("name");
				my $bootinc = $element -> getAttribute ("bootinclude");
				if ((defined $bootinc) && ("$bootinc" eq "true")) {
					push (@falistImage,$archive);
				}
			}
			if (@fplistImage) {
				$kiwi -> info ("Adding foreign package(s):\n");
				foreach my $p (@fplistImage) {
					$kiwi -> info ("--> $p\n");
				}
				$this -> addPackages (
					"bootstrap",$packageNodeList,@fplistImage
				);
				if (@fplistDelete) {
					$this -> addPackages (
						"delete",$packageNodeList,@fplistDelete
					);
				}
			}
			if (@falistImage) {
				$kiwi -> info ("Adding foreign archive(s):\n");
				foreach my $p (@falistImage) {
					$kiwi -> info ("--> $p\n");
				}
				$this -> addArchives (
					"bootstrap",$packageNodeList,@falistImage
				);
			}
		}
		#==========================================
		# 3) foreign machine attributes in type
		#------------------------------------------
		if (defined $foreignRepo->{"domain"}) {
			$this -> setForeignMachineAttribute ("domain");
		}
		#==========================================
		# 4) foreign preferences in type
		#------------------------------------------
		if (defined $foreignRepo->{"locale"}) {
			$this -> setForeignOptionsElement ("locale");
		}
		if (defined $foreignRepo->{"boot-theme"}) {
			$this -> setForeignOptionsElement ("boot-theme");
		}
		if (defined $foreignRepo->{"packagemanager"}) {
			$this -> setForeignOptionsElement ("packagemanager");
		}
		if (defined $foreignRepo->{"oem-swap"}) {
			$this -> setForeignOEMOptionsElement ("oem-swap");
		}
		if (defined $foreignRepo->{"oem-partition-install"}) {
			$this -> setForeignOEMOptionsElement ("oem-partition-install");
		}
		if (defined $foreignRepo->{"oem-swapsize"}) {
			$this -> setForeignOEMOptionsElement ("oem-swapsize");
		}
		if (defined $foreignRepo->{"oem-home"}) {
			$this -> setForeignOEMOptionsElement ("oem-home");
		}
		if (defined $foreignRepo->{"oem-systemsize"}) {
			$this -> setForeignOEMOptionsElement ("oem-systemsize");
		}
		if (defined $foreignRepo->{"oem-boot-title"}) {
			$this -> setForeignOEMOptionsElement ("oem-boot-title");
		}
		if (defined $foreignRepo->{"oem-kiwi-initrd"}) {
			$this -> setForeignOEMOptionsElement ("oem-kiwi-initrd");
		}
		if (defined $foreignRepo->{"oem-reboot"}) {
			$this -> setForeignOEMOptionsElement ("oem-reboot");
		}
		if (defined $foreignRepo->{"oem-dumphalt"}) {
			$this -> setForeignOEMOptionsElement ("oem-dumphalt");
		}
		if (defined $foreignRepo->{"oem-unattended"}) {
			$this -> setForeignOEMOptionsElement ("oem-unattended");
		}
		if (defined $foreignRepo->{"oem-recovery"}) {
			$this -> setForeignOEMOptionsElement ("oem-recovery");
		}
		if (defined $foreignRepo->{"oem-recoveryID"}) {
			$this -> setForeignOEMOptionsElement ("oem-recoveryID");
		}
		if (defined $foreignRepo->{"oem-inplace-recovery"}) {
			$this -> setForeignOEMOptionsElement ("oem-inplace-recovery");
		}
		#==========================================
		# 5) foreign attributes in type
		#------------------------------------------
		if (defined $foreignRepo->{"hybrid"}) {
			$this -> setForeignTypeAttribute ("hybrid");
		}
		if (defined $foreignRepo->{"hybridpersistent"}) {
			$this -> setForeignTypeAttribute ("hybridpersistent");
		}
		if (defined $foreignRepo->{"kernelcmdline"}) {
			$this -> setForeignTypeAttribute (
				"kernelcmdline",$foreignRepo->{"kernelcmdline"}
			);
		}
		if (defined $foreignRepo->{"bootloader"}) {
			$this -> setForeignTypeAttribute (
				"bootloader",$foreignRepo->{"bootloader"}
			);
		}
		if (defined $foreignRepo->{"installboot"}) {
			$this -> setForeignTypeAttribute (
				"installboot",$foreignRepo->{"installboot"}
			);
		}
		#==========================================
		# 6) foreign image attributes, toplevel
		#------------------------------------------
		if (defined $foreignRepo->{"displayname"}) {
			$this -> setForeignImageAttribute (
				"displayname",$foreignRepo->{"displayname"}
			);
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{imageDesc}          = $imageDesc;
	$this->{driversNodeList}    = $driversNodeList;
	$this->{usrdataNodeList}    = $usrdataNodeList;
	$this->{repositNodeList}    = $repositNodeList;
	$this->{packageNodeList}    = $packageNodeList;
	$this->{instsrcNodeList}    = $instsrcNodeList;
	$this->{havemd5File}        = $havemd5File;
	$this->{arch}               = $arch;
	$this->{controlFile}        = $controlFile;
	#==========================================
	# Store object data (create URL list)
	#------------------------------------------
	$this -> createURLList ();
	return $this;
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
# getConfigName
#------------------------------------------
sub getConfigName {
	my $this = shift;
	my $name = $this->{controlFile};
	return ($name);
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
		my $urlHandler  = new KIWIURL ($kiwi,undef);
		my $publics_url = $urlHandler -> normalizePath ($source);
		push (@urllist,$publics_url);
		$urlhash{$source} = $publics_url;
	}
	$this->{urllist} = \@urllist;
	$this->{urlhash} = \%urlhash;
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
# getImageInherit
#------------------------------------------
sub getImageInherit {
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $path = $node -> getAttribute ("inherit");
	return $path;
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
		if (! $this -> requestedProfile ($element)) {
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
		if ((! defined $plus) || ($plus eq "false") || ($plus eq "0")) {
			return 0;
		}
	}
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
			if ($unit eq "M") {
				return $byte * 1024 * 1024;
			}
			if ($unit eq "G") {
				return $byte * 1024 * 1024 * 1024;
			}
			# no unit specified assume MB...
			return $byte * 1024 * 1024;
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
	# Get the image type and its attributes for beeing
	# able to create the appropriate logical extend
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my %result = ();
	my $count  = 0;
	my $first  = "";
	my $ptype  = "";
	my $urlhd  = new KIWIURL ($kiwi,undef);
	my @tnodes = ();
	my @node = $this->{optionsNodeList} -> get_nodelist();
	foreach my $element (@node) {
		if (! $this -> requestedProfile ($element)) {
			next;
		}
		my @types = $element -> getElementsByTagName ("type");
		push (@tnodes,@types);
	}
	foreach my $node (@tnodes) {
		my %record = ();
		my $prim = $node -> getAttribute("primary");
		if ((! defined $prim) || ($prim eq "false")) {
			$prim = $node -> getAttribute("image");
		} else {
			$prim  = "primary";
			$ptype = $node -> getAttribute("image");
		}
		if ($count == 0) {
			$first = $prim;
		}
		$record{node}          = $node;
		$record{type}          = $node -> getAttribute("image");
		$record{luks}          = $node -> getAttribute("luks");
		$record{cmdline}       = $node -> getAttribute("kernelcmdline");
		$record{lvm}           = $node -> getAttribute("lvm");
		$record{compressed}    = $node -> getAttribute("compressed");
		$record{boot}          = $node -> getAttribute("boot");
		$record{volid}         = $node -> getAttribute("volid");
		$record{flags}         = $node -> getAttribute("flags");
		$record{hybrid}        = $node -> getAttribute("hybrid");
		$record{format}        = $node -> getAttribute("format");
		$record{installiso}    = $node -> getAttribute("installiso");
		$record{installstick}  = $node -> getAttribute("installstick");
		$record{vga}           = $node -> getAttribute("vga");
		$record{bootloader}    = $node -> getAttribute("bootloader");
		$record{installboot}   = $node -> getAttribute("installboot");
		$record{checkprebuilt} = $node -> getAttribute("checkprebuilt");
		$record{baseroot}      = $node -> getAttribute("baseroot");
		$record{bootprofile}   = $node -> getAttribute("bootprofile");
		$record{bootkernel}    = $node -> getAttribute("bootkernel");
		$record{filesystem}    = $node -> getAttribute("filesystem");
		$record{fsnocheck}     = $node -> getAttribute("fsnocheck");
		$record{hybridpersistent}  = $node -> getAttribute("hybridpersistent");
		if ($record{type} eq "split") {
			my $filesystemRO = $node -> getAttribute("fsreadonly");
			my $filesystemRW = $node -> getAttribute("fsreadwrite");
			if ((defined $filesystemRO) && (defined $filesystemRW)) {
				$record{filesystem} = "$filesystemRW,$filesystemRO";
			}
		}
		my $bootpath = $urlhd -> obsPath ($record{boot},"boot");
		if (defined $bootpath) {
			$record{boot} = $bootpath;
		}
		$result{$prim} = \%record;
		$count++;
	}
	if (! defined $this->{imageWhat}) {
		if (defined $result{primary}) {
			$this->{imageWhat} = $result{primary}{type};
			$this->{typeNode}  = $result{primary}{node};
			return $result{primary};
		} else {
			$this->{imageWhat} = $result{$first}{type};
			$this->{typeNode}  = $result{$first}{node};
			return $result{$first};
		}
	}
	if ($ptype eq $this->{imageWhat}) {
		$this->{typeNode}  = $result{primary}{node};
		return $result{primary};
	} else {
		$this->{typeNode}  = $result{$this->{imageWhat}}{node};
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
		return undef;
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
	return sort { $a->{number} cmp $b->{number} } @result;
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
		return undef;
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
	my @fileNodeList = $persistNode -> getElementsByTagName ("file")
		-> get_nodelist();
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
	my @fileNodeList = $tempNode -> getElementsByTagName ("file")
		-> get_nodelist();
	foreach my $fileNode (@fileNodeList) {
		my $name = $fileNode -> getAttribute ("name");
		$name =~ s/\/$//;
		push @result, $name;
	}
	return @result;
}

#==========================================
# getSplitTmpExceptions
#------------------------------------------
sub getSplitTmpExceptions {
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
	my @fileNodeList = $tempNode -> getElementsByTagName ("except")
		-> get_nodelist();
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
	my @fileNodeList = $persistNode -> getElementsByTagName ("except")
		-> get_nodelist();
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
		return undef;
	}
}

#==========================================
# setForeignOptionsElement
#------------------------------------------
sub setForeignOptionsElement {
	# ...
	# If given element exists in the foreign hash, set this
	# element into the current preferences (options) XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $kiwi = $this->{kiwi};
	my $foreignRepo = $this->{foreignRepo};
	my $value = $foreignRepo->{$item};
	$kiwi -> info ("Including foreign element $item: $value");
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
# setForeignOEMOptionsElement
#------------------------------------------
sub setForeignOEMOptionsElement {
	# ...
	# If given element exists in the foreign hash, set this
	# element into the current oemconfig (options) XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $foreignRepo = $this->{foreignRepo};
	my $value = $foreignRepo->{$item};
	my $newconfig = 0;
	$kiwi -> info ("Including foreign OEM element $item: $value");
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
	$this -> updateXML();
	return $this;
}

#==========================================
# setForeignMachineAttribute
#------------------------------------------
sub setForeignMachineAttribute {
	# ...
	# If given element exists in the foreign hash, set this
	# attribute into the current machine (options) XML tree
	# if no machine section exists create a new one
	# ---
	my $this = shift;
	my $item = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $foreignRepo = $this->{foreignRepo};
	my $value = $foreignRepo->{$item};
	my $newconfig = 0;
	$kiwi -> info ("Including foreign machine attribute $item: $value");
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
	$this -> updateXML();
	return $this;
}

#==========================================
# setForeignTypeAttribute
#------------------------------------------
sub setForeignTypeAttribute {
	# ...
	# set given attribute to selected type in the
	# xml preferences node
	# ---
	my $this = shift;
	my $attr = shift;
	my $val  = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	$kiwi -> info ("Including foreign type attribute: $attr");
	if ($val) {
		$tnode-> setAttribute ("$attr","$val");
	} else {
		$tnode-> setAttribute ("$attr","true");
	}
	$kiwi -> done ();
	$this -> updateXML();
	return $this;
}

#==========================================
# setForeignImageAttribute
#------------------------------------------
sub setForeignImageAttribute {
	# ...
	# set given attribute to the image section
	# ---
	my $this = shift;
	my $attr = shift;
	my $val  = shift;
	my $kiwi = $this->{kiwi};
	my $inode= $this->{imgnameNodeList} -> get_node(1);
	$kiwi -> info ("Including foreign image attribute: $attr");
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
# setPackageManager
#------------------------------------------
sub setPackageManager {
	# ...
	# set packagemanager to use for this image
	# ---
	my $this  = shift;
	my $value = shift;
	my $opts = $this -> getPreferencesNodeByTagName ("packagemanager");
	my $pmgr = $opts -> getElementsByTagName ("packagemanager");
	if (($pmgr) && ("$pmgr" eq "$value")) {
		return $this;
	}
	my $addElement = new XML::LibXML::Element ("packagemanager");
	$addElement -> appendText ($value);
	my $node = $opts -> getElementsByTagName ("packagemanager") -> get_node(1);
	$opts -> removeChild ($node);
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
	my $pmgr = $node -> getElementsByTagName ("packagemanager");
	if (! $pmgr) {
		return $packageManager{default};
	}
	foreach my $manager (keys %packageManager) {
		if ("$pmgr" eq "$manager") {
			my $file = $packageManager{$manager};
			if (! -f $file) {
				$kiwi -> loginfo ("Package manager $file doesn't exist");
				return undef;
			}
			return $manager;
		}
	}
	$kiwi -> loginfo ("Invalid package manager: $pmgr");
	return undef;
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
		return undef;
	}
	my $domain = $node -> getAttribute ("domain");
	if ((! defined $domain) || ("$domain" eq "")) {
		return undef;
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
		return undef;
	}
	my $size = $node -> getElementsByTagName ("oem-swapsize");
	if ((! defined $size) || ("$size" eq "")) {
		return undef;
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
		return undef;
	}
	my $size = $node -> getElementsByTagName ("oem-systemsize");
	if ((! defined $size) || ("$size" eq "")) {
		return undef;
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
		return undef;
	}
	my $title= $node -> getElementsByTagName ("oem-boot-title");
	if ((! defined $title) || ("$title" eq "")) {
		$title = $this -> getImageDisplayName();
		if ((! defined $title) || ("$title" eq "")) {
			return undef;
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
		return undef;
	}
	my $kboot= $node -> getElementsByTagName ("oem-kiwi-initrd");
	if ((! defined $kboot) || ("$kboot" eq "")) {
		return undef;
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
		return undef;
	}
	my $boot = $node -> getElementsByTagName ("oem-reboot");
	if ((! defined $boot) || ("$boot" eq "")) {
		return undef;
	}
	return $boot;
}

#==========================================
# getOEMDumpHalt
#------------------------------------------
sub getOEMDumpHalt {
	# ...
	# Obtain the oem-dumphalt value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return undef;
	}
	my $halt = $node -> getElementsByTagName ("oem-dumphalt");
	if ((! defined $halt) || ("$halt" eq "")) {
		return undef;
	}
	return $halt;
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
		return undef;
	}
	my $unattended = $node -> getElementsByTagName ("oem-unattended");
	if ((! defined $unattended) || ("$unattended" eq "")) {
		return undef;
	}
	return $unattended;
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
		return undef;
	}
	my $swap = $node -> getElementsByTagName ("oem-swap");
	if ((! defined $swap) || ("$swap" eq "")) {
		return undef;
	}
	return $swap;
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
		return undef;
	}
	my $pinst = $node -> getElementsByTagName ("oem-partition-install");
	if ((! defined $pinst) || ("$pinst" eq "")) {
		return undef;
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
		return undef;
	}
	my $reco = $node -> getElementsByTagName ("oem-recovery");
	if ((! defined $reco) || ("$reco" eq "")) {
		return undef;
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
		return undef;
	}
	my $reco = $node -> getElementsByTagName ("oem-recoveryID");
	if ((! defined $reco) || ("$reco" eq "")) {
		return undef;
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
		return undef;
	}
	my $inplace = $node -> getElementsByTagName ("oem-inplace-recovery");
	if ((! defined $inplace) || ("$inplace" eq "")) {
		return undef;
	}
	return $inplace;
}

#==========================================
# getOEMHome
#------------------------------------------
sub getOEMHome {
	# ...
	# Obtain the oem-home value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return undef;
	}
	my $home = $node -> getElementsByTagName ("oem-home");
	if ((! defined $home) || ("$home" eq "")) {
		return undef;
	}
	return $home;
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
		return undef;
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
		return undef;
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
		return undef;
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
		return undef;
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
		my $gid   = $element -> getAttribute("id");
		my @ntag  = $element -> getElementsByTagName ("user") -> get_nodelist();
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
	my @result  = ();
	my @tnodes  = ();
	my $gotprim = 0;
	my @node    = $this->{optionsNodeList} -> get_nodelist();
	my $urlhd   = new KIWIURL ($kiwi,undef);
	foreach my $element (@node) {
		if (! $this -> requestedProfile ($element)) {
			next;
		}
		my @types = $element -> getElementsByTagName ("type");
		push (@tnodes,@types);
	}
	foreach my $node (@tnodes) {
		my %record  = ();
		$record{type} = $node -> getAttribute("image");
		$record{boot} = $node -> getAttribute("boot");
		my $bootpath = $urlhd -> obsPath ($record{boot},"boot");
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
		if ((defined $import) && ("$incl" ne "true")) {
			next;
		}
		my %profile = ();
		$profile{name} = $name;
		$profile{description} = $desc;
		push @result, { %profile };
	}
	return @result;
}

#==========================================
# setDefaultProfiles
#------------------------------------------
sub setDefaultProfiles {
	# ...
	# import default profiles if no other profiles
	# were set on the commandline
	# ---
	my $this = shift;
	my @list = ();
	if ((defined $this->{reqProfiles}) && (@{$this->{reqProfiles}})) {
		return $this;
	}
	my @profiles = $this -> getProfiles ("default");
	foreach my $profile (@profiles) {
		push (@list,$profile->{name});
	}
	if (@list) {
		$this->{reqProfiles} = \@list;
	}
	return $this;
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
				return undef;
			}
		}
	}
	if (@prequest) {
		my $info = join (",",@prequest);
		$kiwi -> info ("Using profile(s): $info");
		$kiwi -> done ();
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
	return undef if !$what;

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
		if (! $this -> requestedProfile ($element)) {
			next;
		}
		#============================================
		# Store repo information in hash
		#--------------------------------------------
		my $type = $element -> getAttribute("type");
		my $alias= $element -> getAttribute("alias");
		my $prio = $element -> getAttribute("priority");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> resolveLink ( $stag -> getAttribute ("path") );
		$result{$source} = [$type,$alias,$prio];
	}
	return %result;
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
	# Add a repository node to the current list of repos
	# this is done by reading the xml description file again and
	# overwriting the first repository node with the new data
	# A new object XML::LibXML::NodeList is created which
	# contains the changed element. The element is then appended
	# the the global repositNodeList
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @type = @{$_[0]};
	my @path = @{$_[1]};
	my @alias= @{$_[2]};
	my @prio = @{$_[3]};
	foreach my $path (@path) {
		my $type = shift @type;
		my $alias= shift @alias;
		my $prio = shift @prio;
		if (! defined $type) {
			$kiwi -> error   ("No type for repo [$path] specified");
			$kiwi -> skipped ();
			next;
		}
		my $tempXML  = new XML::LibXML;
		my $xaddXML  = new XML::LibXML::NodeList;
		my $tempFile = $this->{controlFile};
		my $tempTree = $tempXML -> parse_file ( $tempFile );
		my $temprepositNodeList = $tempTree->getElementsByTagName("repository");
		my $element = $temprepositNodeList->get_node(1);
		$element -> setAttribute ("type",$type);
		$element -> setAttribute ("status","fixed");
		$element -> getElementsByTagName ("source") -> get_node (1)
			 -> setAttribute ("path",$path);
		if (defined $alias) {
			$element -> setAttribute ("alias",$alias);
		}
		if ((defined $prio) && ($prio != 0)) {
			$element -> setAttribute ("priority",$prio);
		}
		$xaddXML -> push ( $element );
		$this->{repositNodeList} -> append ( $xaddXML );
	}
	$this -> createURLList();
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
	my $nodes = shift;
	my @packs = @_;
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = 1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> requestedProfile ($node)) {
			next;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i; last;
		}
	}
	foreach my $pack (@packs) {
		my $addElement = new XML::LibXML::Element ("package");
		$addElement -> setAttribute("name",$pack);
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
		if (! $this -> requestedProfile ($node)) {
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
	my $nodes = shift;
	my @tars  = @_;
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = 1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> requestedProfile ($node)) {
			next;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i; last;
		}
	}
	foreach my $tar (@tars) {
		my $addElement = new XML::LibXML::Element ("archive");
		$addElement -> setAttribute("name",$tar);
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
	return $this -> addPackages ("bootstrap",undef,@_);
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
	return $this -> addPackages ("delete",undef,@_);
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
	if (open (my $FD,$main::Revision)) {
		$rev = <$FD>; close $FD;
		$rev =~ s/\n//g;
	}
	$result{kiwi_revision} = $rev;
	#==========================================
	# preferences attributes and text elements
	#------------------------------------------
	my %type = %{$this->getImageTypeAndAttributes()};
	my @delp = $this -> getDeleteList();
	my @tstp = $this -> getTestingList();
	my $iver = getImageVersion ($this);
	my $size = getImageSize    ($this);
	my $name = getImageName    ($this);
	my $dname= getImageDisplayName ($this);
	if (@delp) {
		$result{kiwi_delete} = join(" ",@delp);
	}
	if (@tstp) {
		$result{kiwi_testing} = join(" ",@tstp);
	}
	if ((%type) && ($type{compressed} eq "true")) {
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
	if ((%type) && ($type{installboot})) {
		$result{kiwi_installboot} = $type{installboot};
	}
	if ((%type) && ($type{luks})) {
		$result{kiwi_luks} = "yes";
	}
	if ((%type) && ($type{hybrid})) {
		$result{kiwi_hybrid} = "yes";
	}
	if ((%type) && ($type{hybridpersistent})) {
		$result{kiwi_hybridpersistent} = "yes";
	}
	if ($size) {
		$result{kiwi_size} = $size;
	}
	if ($name) {
		$result{kiwi_iname} = $name;
	}
	if ($dname) {
		$result{kiwi_displayname} = $dname;
	}
	if ($iver) {
		$result{kiwi_iversion} = $iver;
	}
	@nodelist = $this->{optionsNodeList} -> get_nodelist();
	foreach my $element (@nodelist) {
		if (! $this -> requestedProfile ($element)) {
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
		if (! $this -> requestedProfile ($element)) {
			next;
		}
		my @ntag = $element -> getElementsByTagName ("file") -> get_nodelist();
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
	# oemconfig
	#------------------------------------------
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (defined $node) {
		my $oemswapMB= $node -> getElementsByTagName ("oem-swapsize");
		my $oemrootMB= $node -> getElementsByTagName ("oem-systemsize");
		my $oemswap  = $node -> getElementsByTagName ("oem-swap");
		my $oempinst = $node -> getElementsByTagName ("oem-partition-install");
		my $oemhome  = $node -> getElementsByTagName ("oem-home");
		my $oemtitle = $node -> getElementsByTagName ("oem-boot-title");
		my $oemkboot = $node -> getElementsByTagName ("oem-kiwi-initrd");
		my $oemreboot= $node -> getElementsByTagName ("oem-reboot");
		my $oemhalt  = $node -> getElementsByTagName ("oem-dumphalt");
		my $oemnomsg = $node -> getElementsByTagName ("oem-unattended");
		my $oemreco  = $node -> getElementsByTagName ("oem-recovery");
		my $oemrecoid= $node -> getElementsByTagName ("oem-recoveryID");
		my $inplace  = $node -> getElementsByTagName ("oem-inplace-recovery");
		if ((defined $oempinst) && ("$oempinst" eq "true")) {
			$result{kiwi_oempartition_install} = "yes";
		}
		if ((defined $oemswap) && ("$oemswap" eq "false")) {
			$result{kiwi_oemswap} = "no";
		} elsif ((defined $oemswapMB) && ("$oemswapMB" > 0)) {
			$result{kiwi_oemswapMB} = $oemswapMB;
		}
		if ((defined $oemhome) && ("$oemhome" eq "false")) {
			$result{kiwi_oemhome} = "no";
		}
		if ((defined $oemrootMB) && ("$oemrootMB" > 0)) {
			$result{kiwi_oemrootMB} = $oemrootMB;
		}
		if ((defined $oemtitle) && ("$oemtitle" ne "")) {
			$result{kiwi_oemtitle} = $oemtitle;
		}
		if ((defined $oemkboot) && ("$oemkboot" ne "")) {
			$result{kiwi_oemkboot} = $oemkboot;
		}
		if ((defined $oemreboot) && ("$oemreboot" eq "true")) {
			$result{kiwi_oemreboot} = $oemreboot;
		}
		if ((defined $oemhalt) && ("$oemhalt" eq "true")) {
			$result{kiwi_oemdumphalt} = $oemhalt;
		}
		if ((defined $oemnomsg) && ("$oemnomsg" eq "true")) {
			$result{kiwi_oemunattended} = $oemnomsg;
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
	foreach my $element (@node) {
		if (! $this -> requestedProfile ($element)) {
			next;
		}
		my $type = $element -> getAttribute ("type");
		if ($type ne $what) {
			next;
		}
		my $ptype = $element -> getAttribute ("patternType");
		if (! defined $ptype) {
			$ptype = "onlyRequired";
		}
		$result{patternType} = $ptype;
		$result{type} = $type;
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
	my $node = $tnode -> getElementsByTagName ("lvmvolumes") -> get_node(1);
	if (! defined $node) {
		return undef;
	}
	return $node -> getAttribute ("lvmgroup");
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
	my $node = $tnode -> getElementsByTagName ("lvmvolumes") -> get_node(1);
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
		} elsif ($free) {
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
	$guestos{suse}{ix86}   = "suse";
	$guestos{suse}{x86_64} = "suse-64";
	$guestos{sles}{ix86}   = "sles";
	$guestos{sles}{x86_64} = "sles-64";
	my $guest= $node -> getAttribute ("guestOS");
	if (! defined $guestos{$guest}{$arch}) {
		if ($arch eq "ix86") {
			$guest = "suse";
		} else {
			$guest = "suse-64";
		}
	} else {
		$guest = $guestos{$guest}{$arch};
	}
	my $memory = $node -> getAttribute ("memory");
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
	my ($drv,$iface,$mode);
	if ($nic) {
		my $node = $nic  -> get_node(1);
		$drv  = $node -> getAttribute ("driver");
		$iface= $node -> getAttribute ("interface");
		$mode = $node -> getAttribute ("mode");
	}
	#==========================================
	# save hash
	#------------------------------------------
	$result{vmware_arch}  = $arch;
	$result{vmware_hwver} = $hwver;
	$result{vmware_guest} = $guest;
	$result{vmware_memory}= $memory;
	if ($disk) {
		$result{vmware_disktype} = $type;
		$result{vmware_diskid}   = $id;
	}
	if ($cd) {
		$result{vmware_cdtype} = $cdtype;
		$result{vmware_cdid}   = $cdid;
	}
	if ($nic) {
		$result{vmware_nicdriver}= $drv;
		$result{vmware_niciface} = $iface;
		$result{vmware_nicmode}  = $mode;
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
	# save hash
	#------------------------------------------
	$result{xen_memory}= $memory;
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
		"onlyarch", "source", "script", "medium"
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
			return undef;
		}
	}
	return $this;
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
			if ($type ne "metapackages") {
				if (($package =~ /@/) && ($manager eq "zypper")) {
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
				if (($manager ne "zypper") && ($manager ne "yum")) {
					#==========================================
					# turn patterns into pacs for this manager
					#------------------------------------------
					# 1) try to use libsatsolver...
					my $psolve = new KIWISatSolver (
						$kiwi,\@pattlist,$this->{urllist},"solve-patterns"
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
	return sort keys %packHash;
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
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $nodes = $this->{packageNodeList};
	my @result= ();
	my @delete= ();
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node -> getAttribute ("type");
		#============================================
		# Check to see if node is in included profile
		#--------------------------------------------
		if (! $this -> requestedProfile ($node)) {
			next;
		}
		#==========================================
		# Handle package names to be deleted later
		#------------------------------------------
		if ($type eq "delete") {
			my @dlist = $node -> getElementsByTagName ("package");
			foreach my $element (@dlist) {
				my $package = $element -> getAttribute ("name");
				if (! $this -> isArchAllowed ($element,"packages")) {
					next;
				}
				$package =~ s/@//;
				if ($package) {
					push @delete,$package;
				}
			}
		}
		#==========================================
		# Handle package names
		#------------------------------------------
		my @plist = $node -> getElementsByTagName ("package");
		foreach my $element (@plist) {
			my $package = $element -> getAttribute ("name");
			if (! $this -> isArchAllowed ($element,"packages")) {
				next;
			}
			$package =~ s/@//;
			if ($package) {
				push @result,$package;
			}
		}
		#==========================================
		# Handle pattern names
		#------------------------------------------
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
	my $psolve = new KIWISatSolver (
		$kiwi,\@result,$this->{urllist},"solve-patterns",
		undef,undef
	);
	if (! defined $psolve) {
		$kiwi -> warning ("SaT solver setup failed");
		return undef;
	}
	my %meta = $psolve -> getMetaData();
	my $solf = $psolve -> getSolfile();
	my @solp = $psolve -> getPackages();
	my @rpat = qxx (
		"dumpsolv $solf|grep 'name: pattern'|cut -f4 -d :"
	);
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
	return getList ($this,"delete");
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
# getForeignPackageNodeList
#------------------------------------------
sub getForeignPackageNodeList {
	# ...
	# Return the current <packages> list which consists
	# of XML::LibXML::Element object pointers
	# ---
	my $this = shift;
	return $this->{packageNodeList};
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
	$this -> updateXML();
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
	my $arch = $this->{arch};
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
		if ($kiwi -> trace()) {
			$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return undef;
	}
	my $origroot = $root;
	my $overlay;
	if (defined $baseRoot) {
		if ((defined $baseRootMode) && ($baseRootMode eq "union")) {
			$kiwi -> info("Creating overlay path\n");
			$kiwi -> info("--> Base: $baseRoot(ro)\n");
			$kiwi -> info("--> COW:  $root/kiwi-root.cow(rw)\n");
		} elsif ((defined $baseRootMode) && ($baseRootMode eq "recycle")) {
			$kiwi -> info("Using overlay path $baseRoot\n");
		} else {
			$kiwi -> info("Importing overlay path $baseRoot -> $root\n");
		}
		$overlay = new KIWIOverlay ( $kiwi,$baseRoot,$root );
		if (! defined $overlay) {
			$rootError = 1;
		} elsif (defined $baseRootMode) {
			$overlay -> setMode ($baseRootMode);
		}
		if ($overlay) {
			$root = $overlay -> mountOverlay();
		}
		if (! defined $root) {
			$rootError = 1;
		}
		if (! $rootError) {
			if ((defined $baseRootMode) && ($baseRootMode eq "union")) {
				$kiwi -> info ("--> Mounted on: $root\n");
			}
		}
	}
	if ( $rootError ) {
		if ($overlay) {
			$overlay -> resetOverlay();
		}
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
			return undef;
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
	# for the given repository list.
	# ----
	my $kiwi  = shift;
	my $repos = shift;
	my $arch  = qxx ("uname -m"); chomp $arch;
	my $sdir  = "/var/cache/kiwi/satsolver";
	my @index = ();
	my $count = 0;
	my $solv;
	#==========================================
	# check/create main solvable file name
	#------------------------------------------
	foreach my $repo (@{$repos}) {
		push (@index,$repo);
	}
	push (@index,$arch);
	@index = sort (@index);
	$solv  = join (":",@index);
	$solv = qxx ("echo $solv | md5sum | cut -f1 -d-");
	$solv = $sdir."/".$solv; chomp $solv;
	$solv =~ s/ +$//;
	#==========================================
	# create one solvable per repo
	#------------------------------------------
	undef @index;
	foreach my $repo (@{$repos}) {
		my $solvable = getSingleInstSourceSatSolvable ($kiwi,$repo);
		if (! $solvable) {
			return undef;
		}
		push @index,$solvable;
		$count++;
	}
	#==========================================
	# merge all solvables into one
	#------------------------------------------
	if ($count > 1) {
		my $data = qxx ("mergesolv @index > $solv.system");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("--> Couldn't merge solve files");
			$kiwi -> failed ();
			return undef
		}
	} else {
		qxx ("cp $solv $solv.system 2>&1");
	}
	return $solv.".system";
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
			$kiwi -> failed ();
			$kiwi -> error  ("--> Couldn't create cache dir: $data");
			$kiwi -> failed ();
			return undef;
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
		if (! open ($RXML,"cat $repoMD|")) {
			$kiwi -> failed ();
			$kiwi -> error ("--> Failed to open file $repoMD");
			$kiwi -> failed ();
			return undef;
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
		if (open (my $FD,"$index.timestamp")) {
			my $curstamp = <$FD>; chomp $curstamp;
			if ($curstamp eq $time) {
				$kiwi -> done();
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
		if (! open ($RXML,">$index.timestamp")) {
			$kiwi -> failed ();
			$kiwi -> error ("--> Failed to create timestamp: $!");
			$kiwi -> failed ();
			return undef;
		}
		print $RXML $time;
		close $RXML;
	}
	#==========================================
	# create repo info file
	#------------------------------------------
	if (open (my $FD,">$index.info")) {
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
			return undef;
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
			if (! open ($FD,$patfile)) {
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
		$scommand = join (";",@done);
		my $data = qxx ("($scommand) | susetags2solv > $destfile 2>/dev/null");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("--> Can't create SaT solvable file");
			$kiwi -> failed ();
			$error = 1;
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
	return undef;
}

#==========================================
# addDefaultSplitNode
#------------------------------------------
sub addDefaultSplitNode {
	# ...
	# if no split section is setup we add a default section
	# from the contents of the KIWISplit.txt file and use it
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $type = $this->{imageWhat};
	if (($type ne "split") && ($type ne "iso")) {
		return $this;
	}
	my $splitNodeList = $tnode -> getElementsByTagName ("split");
	if ($splitNodeList) {
		return;
	}
	my $splitTree;
	my $splitXML = new XML::LibXML;
	eval {
		$splitTree = $splitXML
			-> parse_file ( $main::KSplit );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  ("Problem reading split file: $main::KSplit");
		$kiwi -> failed ();
		$kiwi -> error  ("$evaldata\n");
		return undef;
	}
	$this->{typeNode} -> appendChild (
		$splitTree -> getElementsByTagName ("split")
	);
	$this -> updateXML();
	return $this;
}

1;

# vim: set noexpandtab:
