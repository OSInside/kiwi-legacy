#================
# FILE          : KIWIImage.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create a logical
#               : extend, an image file based on a Linux
#               : filesystem
#               :
# STATUS        : Development
#----------------
package KIWIImage;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use Fcntl ':mode';
use FileHandle;
use File::Basename;
use File::Find qw(find);
use File::stat;
use Math::BigFloat;
use POSIX qw(getcwd);

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIBoot;
use KIWICommandLine;
use KIWIImageCreator;
use KIWIIsoLinux;
use KIWILog;
use KIWIQX qw (qxx);
use KIWIXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIImage object which is used to create
	# the different output image formats from a previosly
	# prepared physical extend
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
	my $xml        = shift;
	my $imageTree  = shift;
	my $imageDest  = shift;
	my $imageStrip = shift;
	my $baseSystem = shift;
	my $imageOrig  = shift;
	my $initCache  = shift;
	my $cmdL       = shift;
	my $configFile = $xml -> getConfigName();
	#==========================================
	# Use absolute path for image destination
	#------------------------------------------
	if ($imageDest !~ /^\//) {
		my $pwd = getcwd();
		$imageDest = $pwd."/".$imageDest;
	}
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if (! defined $cmdL) {
		$kiwi -> error ("No Commandline reference specified");
		$kiwi -> failed ();
		return;
	}
	if (! defined $xml) {
		$kiwi -> error ("No XML reference specified");
		$kiwi -> failed ();
		return;
	}
	if (! defined $baseSystem) {
		$kiwi -> error ("No base system path specified");
		$kiwi -> failed ();
		return;
	}
	if (! defined $imageTree) {
		$kiwi -> error  ("No image tree specified");
		$kiwi -> failed ();
		return;
	}
	if (! -f $configFile) {
		$kiwi -> error  ("Validation of $imageTree failed");
		$kiwi -> failed ();
		return;
	}
	if (! -d $imageDest) {
		$kiwi -> error  ("No valid destdir: $imageDest");
		$kiwi -> failed ();
		return;
	}
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
	}
	if (! $cmdL -> getLogFile()) {
		$imageTree =~ s/\/$//;
		if (defined $imageOrig) {
			$kiwi -> setRootLog ($imageOrig.".".$$.".screenrc.log");
		} else {
			$kiwi -> setRootLog ($imageTree.".".$$.".screenrc.log");
		}
	}
	my $arch = qxx ("uname -m"); chomp ( $arch );
	$arch = ".$arch";
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}       = $kiwi;
	$this->{cmdL}       = $cmdL;
	$this->{initCache}  = $initCache;
	$this->{xml}        = $xml;
	$this->{imageTree}  = $imageTree;
	$this->{imageDest}  = $imageDest;
	$this->{imageStrip} = $imageStrip;
	$this->{baseSystem} = $baseSystem;
	$this->{arch}       = $arch;
	$this->{gdata}      = $main::global -> getGlobals();
	#==========================================
	# Mount overlay tree if required...
	#------------------------------------------
	$this -> setupOverlay();
	#==========================================
	# Store a disk label ID for this object
	#------------------------------------------
	$this->{mbrid} = $main::global -> getMBRDiskLabel (
		$cmdL -> getMBRID()
	);
	#==========================================
	# Clean kernel mounts if any
	#------------------------------------------
	$this -> cleanKernelFSMount();
	return $this;
}

#==========================================
# getImageTree
#------------------------------------------
sub getImageTree {
	# ...
	# return current value of system image tree. Normally
	# this is the same as given in the module parameter list
	# but in case of an overlay cache mount the path changes
	# ---
	my $this = shift;
	return $this->{imageTree}
}

#==========================================
# updateDescription
#------------------------------------------
sub updateDescription {
	# ...
	# Create change set hash from the given XML object
	# to be integrated into another XML object at a later
	# point in the process.
	# ---
	my $this      = shift;
	my $src_xml   = shift;
	my %src_type  = %{$src_xml->getImageTypeAndAttributes_legacy()};
	my %changeset = ();
	my @profiles;
	my %repos;
	my %strip;
	my %strip_default;
	my @bootstrap_plist;
	my @image_plist;
	my @bootstrap_alist;
	my @image_alist;
	my @bootstrap_falistImage;
	my @image_falistImage;
	my @bootstrap_fplistImage;
	my @image_fplistImage;
	my @bootstrap_fplistDelete;
	my @image_fplistDelete;
	my @driverList;
	my %fixedBootInclude;
	my @node;
	#==========================================
	# Store general data
	#------------------------------------------
	if ($src_type{hybrid}) {
		$changeset{"hybrid"}= $src_type{hybrid};
	}
	if ($src_type{hybridpersistent}) {
		$changeset{"hybridpersistent"} = $src_type{hybridpersistent};
	}
	if ($src_type{ramonly}) {
		$changeset{"ramonly"} = $src_type{ramonly};
	}
	if ($src_type{cmdline}) {
		$changeset{"kernelcmdline"} = $src_type{cmdline};
	}
	if ($src_type{firmware}) {
		$changeset{"firmware"} = $src_type{firmware};
	}
	if ($src_type{bootloader}) {
		$changeset{"bootloader"} = $src_type{bootloader};
	}
	if ($src_type{devicepersistency}) {
		$changeset{"devicepersistency"} = $src_type{devicepersistency};
	}
	if ($src_type{installboot}) {
		$changeset{"installboot"} = $src_type{installboot};
	}
	if ($src_type{bootprofile}) {
		$changeset{"bootprofile"} = $src_type{bootprofile};
	}
	if ($src_type{bootkernel}) {
		$changeset{"bootkernel"} = $src_type{bootkernel};
	}
	if ($src_type{fsmountoptions}) {
		$changeset{"fsmountoptions"} = $src_type{fsmountoptions};
	}
	if ($src_xml->{reqProfiles}) {
		push @profiles,@{$src_xml->{reqProfiles}};
		$changeset{"profiles"} = \@profiles;
	}
	#==========================================
	# Store general data
	#------------------------------------------
	$changeset{"packagemanager"} = $src_xml->getPackageManager_legacy();
	$changeset{"showlicense"}    = $src_xml->getLicenseNames_legacy();
	my $domain;
	my %xenc = $src_xml -> getXenConfig_legacy();
	if (%xenc) {
		if (defined $xenc{xen_domain} && $xenc{xen_domain} ne '') {
			$domain = $xenc{xen_domain};
		}
	}
	$changeset{"domain"}         = $domain;
	$changeset{"displayname"}    = $src_xml->getImageDisplayName();
	$changeset{"locale"}         = $src_xml->getLocale_legacy();
	#==========================================
	# Store Theme data
	#------------------------------------------
	my @theme = $src_xml->getBootTheme_legacy();
	$changeset{"bootsplash-theme"} = $theme[0];
	$changeset{"bootloader-theme"} = $theme[1];
	#==========================================
	# Store LVM volumes
	#------------------------------------------
	if ($src_type{lvm}) {
		my %lvmparts = $src_xml -> getLVMVolumes_legacy();
		$changeset{"lvm"} = $src_type{lvm};
		$changeset{"lvmparts"} = \%lvmparts;
	}
	#==========================================
	# Store repositories
	#------------------------------------------
	@node = $src_xml->getRepoNodeList_legacy() -> get_nodelist();
	foreach my $element (@node) {
		if (! $src_xml -> __requestedProfile ($element)) {
			next;
		}
		my $type  = $element -> getAttribute("type");
		my $alias = $element -> getAttribute("alias");
		my $prio  = $element -> getAttribute("priority");
		my $user  = $element -> getAttribute("username");
		my $pwd   = $element -> getAttribute("password");
		my $source= $element -> getElementsByTagName("source")
			-> get_node(1) -> getAttribute ("path");
		$repos{$source} = [$type,$alias,$prio,$user,$pwd];
	}
	$changeset{"repositories"} = \%repos;
	#==========================================
	# Store drivers section if any
	#------------------------------------------
	@node = $src_xml->getDriversNodeList_legacy() -> get_nodelist();
	foreach my $element (@node) {
		if (! $src_xml -> __requestedProfile ($element)) {
			next;
		}
		my @files = $element->getElementsByTagName ("file");
		foreach my $element (@files) {
			my $driver = $element -> getAttribute ("name");
			push (@driverList,$driver);
		}
	}
	$changeset{"driverList"} = \@driverList;
	#==========================================
	# Store strip sections if any
	#------------------------------------------
	my $stripXML = XML::LibXML -> new();
	my $stripTree = $stripXML -> parse_file ($this->{gdata}->{KStrip});
	my @defaultStrip = $stripTree
		-> getElementsByTagName ("initrd") -> get_node (1)
		-> getElementsByTagName ("strip");
	foreach my $element (@defaultStrip) {
		my $type  = $element -> getAttribute("type");
		my @files = $element -> getElementsByTagName ("file");
		my @items = ();
		foreach my $element (@files) {
			my $name = $element -> getAttribute ("name");
			push (@items,$name);
		}
		$strip_default{$type} = \@items;
	}
	@node = $src_xml->getStripNodeList_legacy() -> get_nodelist();
	foreach my $element (@node) {
		if (! $src_xml -> __requestedProfile ($element)) {
			next;
		}
		my $type  = $element -> getAttribute ("type");
		my @files = $element -> getElementsByTagName ("file");
		my @items = ();
		foreach my $element (@files) {
			my $name = $element -> getAttribute ("name");
			push (@items,$name);
		}
		if (($type eq "tools") || ($type eq "libs") || ($type eq "delete")) {
			push (@items,@{$strip_default{$type}});
		}
		$strip{$type} = \@items;
	}
	$changeset{"strip"} = \%strip;
	#==========================================
	# Store boot included packages
	#------------------------------------------
	@node = $src_xml->getPackageNodeList_legacy() -> get_nodelist();
	foreach my $element (@node) {
		if (! $src_xml -> __requestedProfile ($element)) {
			next;
		}
		my $type = $element  -> getAttribute ("type");
		if ($type =~ /^(bootstrap|$src_type{type})$/x) {
			push (@bootstrap_plist,$element->getElementsByTagName ("package"));
			push (@bootstrap_alist,$element->getElementsByTagName ("archive"));
		}
		if ($type eq "image") {
			push (@image_plist,$element->getElementsByTagName ("package"));
			push (@image_alist,$element->getElementsByTagName ("archive"));
		}

	}
	foreach my $element (@bootstrap_plist) {
		my $package = $element -> getAttribute ("name");
		my $bootinc = $element -> getAttribute ("bootinclude");
		my $bootdel = $element -> getAttribute ("bootdelete");
		my $include = 0;
		if ((defined $bootinc) && ("$bootinc" eq "true")) {
			push (@bootstrap_fplistImage,$package);
			$include++;
		}
		if ((defined $bootdel) && ("$bootdel" eq "true")) {
			push (@bootstrap_fplistDelete,$package);
			$include--;
		}
		$fixedBootInclude{$package} = $include;
	}
	foreach my $element (@image_plist) {
		my $package = $element -> getAttribute ("name");
		my $bootinc = $element -> getAttribute ("bootinclude");
		my $bootdel = $element -> getAttribute ("bootdelete");
		my $include = 0;
		if ((defined $bootinc) && ("$bootinc" eq "true")) {
			push (@image_fplistImage,$package);
			$include++;
		}
		if ((defined $bootdel) && ("$bootdel" eq "true")) {
			push (@image_fplistDelete,$package);
			$include--;
		}
		$fixedBootInclude{$package} = $include;
	}
	foreach my $element (@bootstrap_alist) {
		my $archive = $element -> getAttribute ("name");
		my $bootinc = $element -> getAttribute ("bootinclude");
		if ((defined $bootinc) && ("$bootinc" eq "true")) {
			push (@bootstrap_falistImage,$archive);
		}
	}
	foreach my $element (@image_alist) {
		my $archive = $element -> getAttribute ("name");
		my $bootinc = $element -> getAttribute ("bootinclude");
		if ((defined $bootinc) && ("$bootinc" eq "true")) {
			push (@image_falistImage,$archive);
		}
	}
	$changeset{"fixedBootInclude"}       = \%fixedBootInclude;
	$changeset{"bootstrap_falistImage"}  = \@bootstrap_falistImage;
	$changeset{"image_falistImage"}      = \@image_falistImage;
	$changeset{"bootstrap_fplistImage"}  = \@bootstrap_fplistImage;
	$changeset{"image_fplistImage"}      = \@image_fplistImage;
	$changeset{"bootstrap_fplistDelete"} = \@bootstrap_fplistDelete;
	$changeset{"image_fplistDelete"}     = \@image_fplistDelete;
	#==========================================
	# Store OEM data
	#------------------------------------------
	$changeset{"oem-partition-install"}    =
		$src_xml->getOEMPartitionInstall_legacy();
	$changeset{"oem-swap"}                 =
		$src_xml->getOEMSwap_legacy();
	$changeset{"oem-align-partition"}      =
		$src_xml->getOEMAlignPartition_legacy();
	$changeset{"oem-swapsize"}             =
		$src_xml->getOEMSwapSize_legacy();
	$changeset{"oem-systemsize"}           =
		$src_xml->getOEMSystemSize_legacy();
	$changeset{"oem-boot-title"}           =
		$src_xml->getOEMBootTitle_legacy();
	$changeset{"oem-kiwi-initrd"}          =
		$src_xml->getOEMKiwiInitrd_legacy();
	$changeset{"oem-reboot"}               =
		$src_xml->getOEMReboot_legacy();
	$changeset{"oem-reboot-interactive"}   =
		$src_xml->getOEMRebootInter_legacy();
	$changeset{"oem-silent-boot"}          =
		$src_xml->getOEMSilentBoot_legacy();
	$changeset{"oem-shutdown"}             =
		$src_xml->getOEMShutdown_legacy();
	$changeset{"oem-shutdown-interactive"} =
		$src_xml->getOEMShutdownInter_legacy();
	$changeset{"oem-bootwait"}             =
		$src_xml->getOEMBootWait_legacy();
	$changeset{"oem-unattended"}           =
		$src_xml->getOEMUnattended_legacy();
	$changeset{"oem-unattended-id"}        =
		$src_xml->getOEMUnattendedID_legacy();
	$changeset{"oem-recovery"}             =
		$src_xml->getOEMRecovery_legacy();
	$changeset{"oem-recoveryID"}           =
		$src_xml->getOEMRecoveryID_legacy();
	$changeset{"oem-inplace-recovery"}     =
		$src_xml->getOEMRecoveryInPlace_legacy();
	#==========================================
	# Return changeset hash
	#------------------------------------------
	return %changeset;
}

#==========================================
# checkAndSetupPrebuiltBootImage
#------------------------------------------
sub checkAndSetupPrebuiltBootImage {
	# ...
	# check the xml if a prebuild boot image was requested.
	# if yes check if that boot image exists and if yes
	# copy it to the destination directory for this build
	# ---
	my $this = shift;
	my $ixml = shift;
	my $kiwi = $this->{kiwi};
	my $cmdL = $this->{cmdL};
	my $idest= $cmdL->getImageIntermediateTargetDir();
	my %type = %{$ixml->getImageTypeAndAttributes_legacy()};
	my $pblt = $type{checkprebuilt};
	my $boot = $type{boot};
	my $ok   = 0;
	my $bootpath = $boot;
	if (($boot !~ /^\//) && (! -d $boot)) {
		$bootpath = $this->{gdata}->{System}."/".$boot;
	}
	#==========================================
	# open boot image XML object
	#------------------------------------------
	my $locator = KIWILocator -> new();
	my $controlFile = $locator -> getControlFile ($bootpath);
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new (
		$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return;
	}
	my $bxml = KIWIXML -> new ($bootpath,undef,undef,$cmdL );
	if (! $bxml) {
		return;
	}
	my $bootImageName = $main::global ->generateBuildImageName($bxml);
	undef $bxml;
	$kiwi -> info ("Checking for pre-built boot image");
	#==========================================
	# is it requested...
	#------------------------------------------
	if ((! $pblt) || ($pblt eq "false")) {
		$kiwi -> notset();
		return ($bootImageName,0);
	}
	#==========================================
	# check path names for boot image
	#------------------------------------------
	my $lookup = $bootpath."-prebuilt/";
	my $prebuiltPath = $cmdL -> getPrebuiltBootImagePath();
	if (defined $prebuiltPath) {
		$lookup = $prebuiltPath."/";
	} else {
		my $defaultPath = $ixml -> getDefaultPrebuiltDir_legacy();
		if ($defaultPath) {
			$lookup =  $defaultPath . '/';
		}
	}
	my $pinitrd = $lookup.$bootImageName.".gz";
	my $psplash;
	if (-f $lookup.$bootImageName.'.spl') {
		$psplash = $lookup.$bootImageName.'.spl';
	}
	my $plinux  = $lookup.$bootImageName.".kernel";
	if (! -f $pinitrd) {
		$pinitrd = $lookup.$bootImageName;
	}
	if ((! -f $pinitrd) || (! -f $plinux)) {
		$kiwi -> skipped();
		$kiwi -> info ("Can't find pre-built boot image in $lookup");
		$kiwi -> skipped();
		$ok = 0;
	} else {
		$kiwi -> done();
		$kiwi -> info ("Copying pre-built boot image to destination");
		my $lookup = basename $pinitrd;
		if (-f "$idest/$lookup") {
			#==========================================
			# Already exists in destination dir
			#------------------------------------------
			$kiwi -> done();
			$ok = 1;
		} else {
			#==========================================
			# Needs to be copied...
			#------------------------------------------
			if ($psplash) {
				qxx ("cp -a $psplash $idest 2>&1");
			}
			my $data = qxx ("cp -a $pinitrd $idest 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				$kiwi -> error ("Can't copy pre-built initrd: $data");
				$kiwi -> failed();
				$ok = 0;
			} else {
				$data = qxx ("cp -a $plinux* $idest 2>&1");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed();
					$kiwi -> error ("Can't copy pre-built kernel: $data");
					$kiwi -> failed();
					$ok = 0;
				} else {
					$kiwi -> done();
					$ok = 1;
				}
			}
		}
	}
	#==========================================
	# setup return for ok
	#------------------------------------------
	if (! $ok) {
		return ($bootImageName,0);
	}
	return ($bootImageName,1);
}

#==========================================
# setupOverlay
#------------------------------------------
sub setupOverlay {
	# ...
	# mount the image cache if the image is based on it
	# and register the overlay mount point as new imageTree
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $tree = $this->{imageTree};
	my $xml  = $this->{xml};
	$this->{overlay} = KIWIOverlay -> new($tree);
	if (! $this->{overlay}) {
		return;
	}
	$this->{imageTree} = $this->{overlay} -> mountOverlay();
	if (! defined $this->{imageTree}) {
		return;
	}
	$xml -> writeXMLDescription_legacy ($this->{imageTree});
	return $this;
}

#==========================================
# stripImage
#------------------------------------------
sub stripImage {
	# ...
	# remove symbols from shared objects and binaries
	# using strip -p
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	$kiwi -> info ("Stripping shared objects/executables...");
	my @list = qxx ("find $imageTree -type f -perm -755");
	foreach my $file (@list) {
		chomp $file;
		my $data = qxx ("file \"$file\"");
		chomp $data;
		if ($data =~ /not stripped/) {
		if ($data =~ /shared object/) {
			qxx ("strip -p $file 2>&1");
		}
		if ($data =~ /executable/) {
			qxx ("strip -p $file 2>&1");
		}
		}
	}
	$kiwi -> done ();
	return $this;
}

#==========================================
# createImageClicFS
#------------------------------------------
sub createImageClicFS {
	# ...
	# create compressed loop image container
	# ---
	my $this    = shift;
	my $rename  = shift;
	my $journal = "journaled-ext3";
	my $kiwi    = $this->{kiwi};
	my $data;
	my $code;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ();
	if (! defined $name) {
		return;
	}
	if (defined $rename) {
		$data = qxx (
			"mv $this->{imageDest}/$name $this->{imageDest}/$rename 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Can't rename image file");
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return;
		}
		$name = $rename;
	}
	#==========================================
	# Create ext3 filesystem on extend
	#------------------------------------------
	if (! $this -> setupEXT2 ( $name,$journal )) {
		return;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name,"nozip","clicfs")) {
		return;
	}
	#==========================================
	# Rename filesystem loop file
	#------------------------------------------
	$data = qxx (
		"mv $this->{imageDest}/$name $this->{imageDest}/fsdata.ext3 2>&1"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Can't move file to fsdata.ext3");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	#==========================================  
	# Resize to minimum  
	#------------------------------------------
	my $rver= qxx (
		"resize2fs --version 2>&1 | head -n 1 | cut -f2 -d ' ' | cut -f1-2 -d."
	); chomp $rver;
	my $dfs = "/sbin/debugfs";
	my $req = "-R 'show_super_stats -h'";
	my $bcn = "'^Block count:'";
	my $bfr = "'^Free blocks:'";
	my $src = "$this->{imageDest}/fsdata.ext3";
	my $blocks = 0;
	$kiwi -> loginfo ("Using resize2fs version: $rver\n");
	if ($rver >= 1.41) {
		$data = qxx (
			"resize2fs $this->{imageDest}/fsdata.ext3 -M 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Failed to resize ext3 container: $data");
			$kiwi -> failed ();
			return;
		}
	} else {
		$data = qxx (
			"$dfs $req $src 2>/dev/null | grep $bcn | sed -e 's,.*: *,,'"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("debugfs: block count request failed: $data");
			$kiwi -> failed ();
			return;
		}
		chomp $data;
		$blocks = $data;  
		$data = qxx (
			"$dfs $req $src 2>/dev/null | grep $bfr | sed -e 's,.*: *,,'"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("debugfs: free blocks request failed: $data");
			$kiwi -> failed ();
			return;
		}  
		$kiwi -> info ("clicfs: blocks count=$blocks free=$data");
		$blocks = $blocks - $data;  
		$data = qxx (
			"resize2fs $this->{imageDest}/fsdata.ext3 $blocks 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Failed to resize ext3 container: $data");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Create clicfs filesystem from ext3
	#------------------------------------------
	$kiwi -> info (
		"Creating clicfs container: $this->{imageDest}/$name.clicfs"
	);
	my $clicfs = "mkclicfs";
	if (defined $ENV{MKCLICFS_COMPRESSION}) {
		my $c = int $ENV{MKCLICFS_COMPRESSION};
		my $d = $this->{imageDest};
		$data = qxx ("$clicfs -c $c $d/fsdata.ext3 $d/$name 2>&1");
	} else {
		my $d = $this->{imageDest};
		$data = qxx ("$clicfs $d/fsdata.ext3 $d/$name 2>&1");
	}
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create clicfs filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	qxx ("mv -f $this->{imageDest}/$name.ext3 $this->{imageDest}/$name.clicfs");
	qxx ("rm -f $this->{imageDest}/fsdata.ext3");
	$kiwi -> done();
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! $this -> buildMD5Sum ($name)) {
		return;
	}
	return $this;
}

#==========================================
# createImageEXT
#------------------------------------------
sub createImageEXT {
	# ...
	# Create EXT2 image from source tree
	# ---
	my $this    = shift;
	my $journal = shift;
	my $device  = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ($device);
	if (! defined $name) {
		return;
	}
	if ($this->{targetDevice}) {
		$device = $this->{targetDevice};
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupEXT2 ( $name,$journal,$device )) {
		return;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name,undef,undef,$device)) {
		return;
	}
	return $this;
}

#==========================================
# createImageEXT2
#------------------------------------------
sub createImageEXT2 {
	# ...
	# create journaled EXT2 image from source tree
	# ---
	my $this = shift;
	my $device  = shift;
	my $journal = "journaled-ext2";
	return $this -> createImageEXT ($journal,$device);
}

#==========================================
# createImageEXT3
#------------------------------------------
sub createImageEXT3 {
	# ...
	# create journaled EXT3 image from source tree
	# ---
	my $this = shift;
	my $device  = shift;
	my $journal = "journaled-ext3";
	return $this -> createImageEXT ($journal,$device);
}

#==========================================
# createImageEXT4
#------------------------------------------
sub createImageEXT4 {
	# ...
	# create journaled EXT4 image from source tree
	# ---
	my $this = shift;
	my $device  = shift;
	my $journal = "journaled-ext4";
	return $this -> createImageEXT ($journal,$device);
}

#==========================================
# createImageReiserFS
#------------------------------------------
sub createImageReiserFS {
	# ...
	# create journaled ReiserFS image from source tree
	# ---
	my $this = shift;
	my $device  = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ($device);
	if (! defined $name) {
		return;
	}
	if ($this->{targetDevice}) {
		$device = $this->{targetDevice};
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupReiser ( $name,$device )) {
		return;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name,undef,undef,$device)) {
		return;
	}
	return $this;
}

#==========================================
# createImageBTRFS
#------------------------------------------
sub createImageBTRFS {
	# ...
	# create BTRFS image from source tree
	# ---
	my $this   = shift;
	my $device = shift;
	my $rename = shift;
	my $kiwi   = $this->{kiwi};
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ($device);
	if (! defined $name) {
		return;
	}
	if ($this->{targetDevice}) {
		$device = $this->{targetDevice};
	}
	if (defined $rename) {
		my $data = qxx (
			"mv $this->{imageDest}/$name $this->{imageDest}/$rename 2>&1"
		);
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Can't rename image file");
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return;
		}
		$name = $rename;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupBTRFS ( $name,$device )) {
		return;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name,undef,'btrfs',$device)) {
		return;
	}
	return $this;
}

#==========================================
# createImageXFS
#------------------------------------------
sub createImageXFS {
	# ...
	# create XFS image from source tree
	# ---
	my $this   = shift;
	my $device = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ($device);
	if (! defined $name) {
		return;
	}
	if ($this->{targetDevice}) {
		$device = $this->{targetDevice};
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupXFS ( $name,$device )) {
		return;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name,undef,undef,$device)) {
		return;
	}
	return $this;
}

#==========================================
# createImageSquashFS
#------------------------------------------
sub createImageSquashFS {
	# ...
	# create squashfs image from source tree
	# ---
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $xml   = $this->{xml};
	my %type  = %{$xml->getImageTypeAndAttributes_legacy()};
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ("haveExtend");
	if (! defined $name) {
		return;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupSquashFS ( $name )) {
		return;
	}
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! $this -> buildMD5Sum ($name)) {
		return;
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if (($type{compressed}) && ($type{compressed} eq 'true')) {
		if (! $this -> compressImage ($name,'squashfs')) {
			return;
		}
	}
	#==========================================
	# Create image boot configuration
	#------------------------------------------
	if (! $this -> writeImageConfig ($name)) {
		return;
	}
	return $this;
}

#==========================================
# createImageCPIO
#------------------------------------------
sub createImageCPIO {
	# ...
	# create cpio archive from the image source tree
	# The kernel will use this archive and mount it as
	# cpio archive
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $imageTree = $this->{imageTree};
	my $zipper    = $this->{gdata}->{Gzip};
	my $compress  = 1;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ("haveExtend","quiet");
	if (! defined $name) {
		return;
	}
	#==========================================
	# PRE Create filesystem on extend
	#------------------------------------------
	$kiwi -> info ("Creating cpio archive...");
	my $pwd  = qxx ("pwd"); chomp $pwd;
	my @cpio = ("--create", "--format=newc", "--quiet");
	my $dest = $this->{imageDest}."/".$name.".gz";
	my $dspl = $this->{imageDest}."/".$name.".splash.gz";
	my $data;
	if (! $compress) {
		$dest = $this->{imageDest}."/".$name;
	}
	if ($dest !~ /^\//) {
		$dest = $pwd."/".$dest;
	}
	if ($dspl !~ /^\//) {
		$dspl = $pwd."/".$dspl;
	}
	if (-e $dspl) {
		qxx ("rm -f $dspl 2>&1");
	}
	if ($compress) {
		$data = qxx (
			"cd $imageTree && find . | cpio @cpio | $zipper -f > $dest"
		);
	} else {
		$data = qxx ("rm -f $dest && rm -f $dest.gz");
		$data = qxx (
			"cd $imageTree && find . | cpio @cpio > $dest"
		);
	}
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create cpio archive");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	$kiwi -> done();
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	if ($compress) {
		$name = $name.".gz";
	}
	if (! $this -> buildMD5Sum ($name)) {
		return;
	}
	return $this;
}

#==========================================
# createImageTar
#------------------------------------------
sub createImageTar {
	# ...
	# create tar archive from the image source tree
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $imageTree = $this->{imageTree};
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ("haveExtend");
	if (! defined $name) {
		return;
	}
	#==========================================
	# PRE Create tarball from extend
	#------------------------------------------
	$kiwi -> info ("Creating tar archive...");
	my $dest = $this->{imageDest}."/".$name;
	my $data = qxx ("cd $imageTree && tar -cjf $dest . 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create tar archive");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	$kiwi -> done();
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $dest_dir  = dirname  $dest;
	my $dest_file = basename $dest;
	qxx ("cd $dest_dir && ln -vs $dest_file $dest_file.tbz");
	if (! $this -> buildMD5Sum ($name)) {
		return;
	}
	return $this;
}

#==========================================
# createImageRootAndBoot
#------------------------------------------
sub createImageRootAndBoot {
	# ...
	# Create root filesystem image if required according to
	# the selected image type and also create the boot image
	# including kernel and initrd. This function is required
	# to create the preconditions for virtual disk images
	# ---
	#==========================================
	# Create root image
	#------------------------------------------
	my $this       = shift;
	my $para       = shift;
	my $text       = shift;
	my $kiwi       = $this->{kiwi};
	my $sxml       = $this->{xml};
	my $cmdL       = $this->{cmdL};
	my $idest      = $cmdL->getImageIntermediateTargetDir();
	my %stype      = %{$sxml->getImageTypeAndAttributes_legacy()};
	my $imageTree  = $this->{imageTree};
	my $baseSystem = $this->{baseSystem};
	my $treeAccess = 1;
	my @bootdata;
	my $type;
	my $boot;
	my %result;
	my $ok;
	if ($para =~ /(.*):(.*)/) {
		$type = $1;
		$boot = $2;
	}
	if ((! defined $type) || (! defined $boot)) {
		$kiwi -> error  ("Invalid $text type specified: $para");
		$kiwi -> failed ();
		return;
	}
	my $rootTarget = $cmdL->getRootTargetDir();
	if (! $rootTarget) {
		$rootTarget = $cmdL->getConfigDir();
	}
	my $checkBase = $rootTarget."/".$baseSystem;
	#==========================================
	# Check for direct tree access
	#------------------------------------------
	if (($text ne "VMX") || ($stype{luks})) {
		$treeAccess = 0;
	}
	if ($stype{lvm}) {
		if ($stype{luks}) {
			$kiwi -> warning ("LUKS encryption on LVM not yet supported");
			$kiwi -> skipped ();
		}
		$treeAccess = 1;
	}
	#==========================================
	# Walk through the types
	#------------------------------------------
	SWITCH: for ($type) {
		/^ext2/       && do {
			if (! $treeAccess) {
				$ok = $this -> createImageEXT2 ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^ext3/       && do {
			if (! $treeAccess) {
				$ok = $this -> createImageEXT3 ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^ext4/       && do {
			if (! $treeAccess) {
				$ok = $this -> createImageEXT4 ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^reiserfs/   && do {
			if (! $treeAccess) {
				$ok = $this -> createImageReiserFS ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^squashfs/   && do {
			$ok = $this -> createImageSquashFS ();
			last SWITCH;
		};
		/^clicfs/     && do {
			$ok = $this -> createImageClicFS ();
			last SWITCH;
		};
		/^btrfs/      && do {
			if (! $treeAccess) {
				$ok = $this -> createImageBTRFS ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^xfs/        && do {
			if (! $treeAccess) {
				$ok = $this -> createImageXFS ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported $text type: $type");
		$kiwi -> failed ();
		return;
	};
	if (! $ok) {
		return;
	}
	#==========================================
	# Prepare/Create boot image
	#------------------------------------------
	$kiwi -> info ("--> Creating $text boot image: $boot...\n");
	@bootdata = $this -> checkAndSetupPrebuiltBootImage ($sxml);
	if (! @bootdata) {
		return;
	}
	if ($bootdata[1] == 0) {
		#==========================================
		# Setup changeset to be used by boot image
		#------------------------------------------
		my %XMLChangeSet = $this -> updateDescription ($sxml);
		#==========================================
		# Create tmp dir for boot image creation
		#------------------------------------------
		my $tmpdir = qxx ("mktemp -q -d $idest/boot-$text.XXXXXX");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
			$kiwi -> failed ();
			return;
		}
		chomp $tmpdir;
		push @{$this->{tmpdirs}},$tmpdir;
		#==========================================
		# Prepare boot image...
		#------------------------------------------
		my $configDir;
		if (($stype{boot} !~ /^\//) && (! -d $stype{boot})) {
			$configDir = $this->{gdata}->{System}."/".$stype{boot};
		} else {
			$configDir = $stype{boot};
		}
		my $rootTarget = "$tmpdir/kiwi-".$text."boot-$$";
		my $kic = KIWIImageCreator -> new($cmdL);
		if ((! $kic) ||	(! $kic -> prepareBootImage (
			$configDir,$rootTarget,$this->{imageTree},\%XMLChangeSet))
		) {
			undef $kic;
			if (! -d $checkBase) {
				qxx ("rm -rf $tmpdir");
			}
			return;
		}
		#==========================================
		# Create boot image...
		#------------------------------------------
		if ((! $kic) || (! $kic -> createBootImage (
			$rootTarget,$this->{imageDest}))
		) {
			undef $kic;
			if (! -d $checkBase) {
				qxx ("rm -rf $tmpdir");
			}
			return;
		}
		#==========================================
		# Clean up tmp directory
		#------------------------------------------
		qxx ("rm -rf $tmpdir");
	}
	#==========================================
	# setup initrd name
	#------------------------------------------
	my $initrd = $idest."/".$bootdata[0].".gz";
	if (! -f $initrd) {
		$initrd = $idest."/".$bootdata[0];
	}
	#==========================================
	# Check boot and system image kernel
	#------------------------------------------
	if ($cmdL->getCheckKernel()) {
		if (! $this -> checkKernel ($initrd,$imageTree,$bootdata[0])) {
			return;
		}
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $kboot  = KIWIBoot -> new($initrd,$cmdL);
	if (! defined $kboot) {
		return;
	}
	my $newinitrd = $kboot -> setupSplash();
	#==========================================
	# Store meta data for subsequent calls
	#------------------------------------------
	$result{systemImage} = $main::global -> generateBuildImageName($sxml);
	$result{bootImage}   = $bootdata[0];
	if ($text eq "VMX") {
		$result{format} = $stype{format};
	}
	return \%result;
}

#==========================================
# createImagePXE
#------------------------------------------
sub createImagePXE {
	# ...
	# Create Image usable within a PXE boot environment. The
	# method will create the specified boot image (initrd) and
	# the system image. In order to use this image via PXE the
	# administration needs to provide the images via TFTP
	# ---
	#==========================================
	# Create PXE boot and system image
	#------------------------------------------
	my $this = shift;
	my $para = shift;
	my $name = $this -> createImageRootAndBoot ($para,"PXE");
	if (! defined $name) {
		return;
	}
	return $this;
}

#==========================================
# createImageVMX
#------------------------------------------
sub createImageVMX {
	# ...
	# Create virtual machine disks. By default a raw disk image will
	# be created from which other types are derived via conversion.
	# The output format is specified by the format attribute in the
	# type section. Supported formats are: vmdk qcow raw ovf
	# The process will create the system image and the appropriate vmx
	# boot image plus a .raw and an optional format specific image.
	# The boot image description must exist in /usr/share/kiwi/image.
	# ---
	#==========================================
	# Create VMX boot and system image
	#------------------------------------------
	my $this = shift;
	my $para = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $cmdL = $this->{cmdL};
	my $idest= $cmdL->getImageIntermediateTargetDir();
	my %xenc = $xml  -> getXenConfig_legacy();
	my $name = $this -> createImageRootAndBoot ($para,"VMX");
	my $xendomain;
	if (! defined $name) {
		return;
	}
	if (defined $xenc{xen_domain}) {
		$xendomain = $xenc{xen_domain};
	} else {
		$xendomain = "dom0";
	}
	#==========================================
	# Create virtual disk image(s)
	#------------------------------------------
	$cmdL -> setInitrdFile (
		$idest."/".$name->{bootImage}.".splash.gz"
	);
	if (defined $name->{imageTree}) {
		$cmdL -> setSystemLocation (
			$name->{imageTree}
		);
	} else {
		$cmdL -> setSystemLocation (
			$idest."/".$name->{systemImage}
		);
	}
	my $kic = KIWIImageCreator -> new($cmdL);
	if ((! $kic) || (! $kic->createImageDisk())) {
		undef $kic;
		return;
	}
	#==========================================
	# Create VM format/configuration
	#------------------------------------------
	if ((defined $name->{format}) || ($xendomain eq "domU")) {
		$cmdL -> setSystemLocation (
			$idest."/".$name->{systemImage}.".raw"
		);
		$cmdL -> setImageFormat ($name->{format});
		my $kic = KIWIImageCreator -> new($cmdL);
		if ((! $kic) || (! $kic->createImageFormat($xml))) {
			undef $kic;
			return;
		}
	}
	return $this;
}

#==========================================
# createImageLiveCD
#------------------------------------------
sub createImageLiveCD {
	# ...
	# Create a live filesystem on CD using the isoboot boot image
	# 1) split physical extend into two parts:
	#    part1 -> writable
	#    part2 -> readonly
	# 2) Setup an ext2 based image for the RW part and a squashfs
	#    image if it should be compressed. If no compression is used
	#    all RO data will be directly on CD/DVD as part of the ISO
	#    filesystem
	# 3) Prepare and Create the given iso <$boot> boot image
	# 4) Setup the CD structure and copy all files
	#    including the syslinux isolinux data
	# 5) Create the iso image using isolinux shell script
	# ---
	my $this = shift;
	my $para = shift;
	my $kiwi = $this->{kiwi};
	my $arch = $this->{arch};
	my $sxml = $this->{xml};
	my $cmdL = $this->{cmdL};
	my $idest= $cmdL->getImageIntermediateTargetDir();
	my $imageTree = $this->{imageTree};
	my $baseSystem= $this->{baseSystem};
	my @bootdata;
	my $error;
	my $data;
	my $code;
	my $imageTreeReadOnly;
	my $hybrid = 0;
	my $isxen  = 0;
	my $hybridpersistent = 0;
	my $efibootloadsize  = 0;
	my $cmdline = "";
	my $rootTarget = $cmdL->getRootTargetDir();
	if (! $rootTarget) {
		$rootTarget = $cmdL->getConfigDir();
	}
	my $checkBase = $rootTarget."/".$baseSystem;
	#==========================================
	# Disable target device support for iso
	#------------------------------------------
	undef $this->{gdata}->{StudioNode};
	#==========================================
	# Store arch name used by iso
	#------------------------------------------
	my $isoarch = qxx ("uname -m"); chomp $isoarch;
	if ($isoarch =~ /i.86/) {
		$isoarch = "i386";
	}
	#==========================================
	# Get system image name
	#------------------------------------------
	my $systemName = $sxml -> getImageName_legacy();
	my $systemDisplayName = $sxml -> getImageDisplayName();
	#==========================================
	# Get system image type information
	#------------------------------------------
	my %stype= %{$sxml->getImageTypeAndAttributes_legacy()};
	my $vga  = $stype{vga};
	#==========================================
	# Get boot image name and compressed flag
	#------------------------------------------
	my @plist = split (/,/,$para);
	my $boot  = $plist[0];
	my $gzip  = $plist[1];
	if (! defined $boot) {
		$kiwi -> failed ();
		$kiwi -> error  ("No boot image name specified");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Check for hybrid ISO
	#------------------------------------------
	if ((defined $stype{hybrid}) && ($stype{hybrid} eq 'true')) {
		$hybrid = 1;
	}
	if ((defined $stype{hybridpersistent}) &&
		($stype{hybridpersistent} eq 'true')
	) {
		$hybridpersistent = 1;
	}
	#==========================================
	# Check for user-specified cmdline options
	#------------------------------------------
	if (defined $stype{cmdline}) {
		$cmdline = " $stype{cmdline}";
	}
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $namecd = $main::global -> generateBuildImageName($this->{xml}, ';');
	my $namerw = $main::global -> generateBuildImageName($this->{xml});
	my $namero = $main::global -> generateBuildImageName(
		$this->{xml},'-', '-read-only'
	);
	if (! defined $namerw) {
		return;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! $this -> setupLogicalExtend ("quiet")) {
		return;
	}
	#==========================================
	# Check for config-cdroot and move it
	#------------------------------------------
	my $cdrootData = "config-cdroot.tgz";
	if (-f $imageTree."/image/".$cdrootData) {
		qxx ("mv $imageTree/image/$cdrootData $this->{imageDest}");
	}
	#==========================================
	# Check for config-cdroot.sh and move it
	#------------------------------------------
	my $cdrootScript = "config-cdroot.sh";
	if (-x $imageTree."/image/".$cdrootScript) {
		qxx ("mv $imageTree/image/$cdrootScript $this->{imageDest}");
	}
	#==========================================
	# split physical extend into RW / RO part
	#------------------------------------------
	if (! defined $gzip) {
		$imageTreeReadOnly = $imageTree;
		$imageTreeReadOnly =~ s/\/+$//;
		$imageTreeReadOnly.= "-read-only/";
		$this->{imageTreeReadOnly} = $imageTreeReadOnly;
		if (! -d $imageTreeReadOnly) {
			$kiwi -> info ("Creating read only image part");
			if (! mkdir $imageTreeReadOnly) {
				$error = $!;
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create ro directory: $error");
				$kiwi -> failed ();
				return;
			}
			push @{$this->{tmpdirs}},$imageTreeReadOnly;
			my @rodirs = qw (bin boot lib lib64 opt sbin usr);
			foreach my $dir (@rodirs) {
				if (! -d "$imageTree/$dir") {
					next;
				}
				$data = qxx ("mv $imageTree/$dir $imageTreeReadOnly 2>&1");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> error  ("Couldn't setup ro directory: $data");
					$kiwi -> failed ();
					return;
				}
			}
			$kiwi -> done();
		}
		#==========================================
		# Count disk space for RW extend
		#------------------------------------------
		$kiwi -> info ("Computing disk space...");
		my ($mbytesrw,$xmlsize) = $this -> getSize ($imageTree);
		$kiwi -> done ();

		#==========================================
		# Create RW logical extend
		#------------------------------------------
		$kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
		if (! $this -> buildLogicalExtend ($namerw,$mbytesrw."M")) {
			$this -> restoreSplitExtend ();
			$this -> cleanLuks();
			return;
		}
		$kiwi -> done ();
		#==========================================
		# Create EXT2 filesystem on RW extend
		#------------------------------------------
		my $setBlockSize = 0;
		my $fsopts       = $cmdL -> getFilesystemOptions();
		my $blocksize    = $fsopts->[0];
		if (! defined $blocksize) {
			$fsopts->[0] = 4096;
			$setBlockSize = 1;
			$cmdL -> setFilesystemOptions (@{$fsopts});
		}
		if (! $this -> setupEXT2 ( $namerw )) {
			$this -> restoreSplitExtend ();
			$this -> cleanLuks();
			return;
		}
		if ($setBlockSize) {
			undef $fsopts->[0];
			$cmdL -> setFilesystemOptions (@{$fsopts});
		}
		#==========================================
		# mount logical extend for data transfer
		#------------------------------------------
		my $extend = $this -> mountLogicalExtend ($namerw);
		if (! defined $extend) {
			$this -> restoreSplitExtend ();
			$this -> cleanLuks();
			return;
		}
		#==========================================
		# copy physical to logical
		#------------------------------------------
		if (! $this -> installLogicalExtend ($extend,$imageTree)) {
			$this -> restoreSplitExtend ();
			$this -> cleanLuks();
			return;
		}
		$this -> cleanMount();
		$this -> restoreImageDest();
		$this -> cleanLuks();
	}
	#==========================================
	# Create compressed filesystem on RO extend
	#------------------------------------------
	if (defined $gzip) {
		SWITCH: for ($gzip) {
			/^compressed$/ && do {
				$kiwi -> info ("Creating split ext3 + squashfs...\n");
				if (! $this -> createImageSplit ("ext3,squashfs", 1)) {
					return;
				}
				$namero = $namerw;
				last SWITCH;
			};
			/^(clic|clic_udf)$/ && do {
				$kiwi -> info ("Creating clicfs read only filesystem...\n");
				if (! $this -> createImageClicFS ( $namero )) {
					$this -> restoreSplitExtend ();
					return;
				}
				last SWITCH;
			};
			/^seed$/ && do {
				$kiwi -> info ("Creating btrfs read only filesystem...\n");
				if (! $this -> createImageBTRFS ( undef,$namero )) {
					$this -> restoreSplitExtend ();
					return;
				}
				$data = qxx ("btrfstune -S 1 $this->{imageDest}/$namero 2>&1");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> error ("Write protection failed: $data");
					$kiwi -> failed ();
					$this -> restoreSplitExtend ();
					return;
				}
				last SWITCH;
			};
			# invalid flag setup...
			$kiwi -> error  ("Invalid iso flags: $gzip");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Check / build md5 sum of RW extend
	#------------------------------------------
	if (! defined $gzip) {
		#==========================================
		# Checking RW file system
		#------------------------------------------
		qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$namerw 2>&1");

		#==========================================
		# Create image md5sum
		#------------------------------------------
		if (! $this -> buildMD5Sum ($namerw)) {
			$this -> restoreSplitExtend ();
			return;
		}
		#==========================================
		# Restoring physical extend
		#------------------------------------------
		if (! $this -> restoreSplitExtend ()) {
			return;
		}
		#==========================================
		# compress RW extend
		#------------------------------------------
		if (! $this -> compressImage ($namerw,'ext2')) {
			return;
		}
	}
	#==========================================
	# recreate a copy of the read-only data
	#------------------------------------------	
	if ((defined $imageTreeReadOnly) && (! -d $imageTreeReadOnly) &&
		(! defined $gzip)
	) {
		$kiwi -> info ("Creating read only reference...");
		if (! mkdir $imageTreeReadOnly) {
			$error = $!;
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create ro directory: $error");
			$kiwi -> failed ();
			return;
		}
		my @rodirs = qw (bin boot lib lib64 opt sbin usr);
		foreach my $dir (@rodirs) {
			if (! -d "$imageTree/$dir") {
				next;
			}
			$data = qxx ("cp -a $imageTree/$dir $imageTreeReadOnly 2>&1");
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't setup ro directory: $data");
				$kiwi -> failed ();
				return;
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# Prepare and Create ISO boot image
	#------------------------------------------
	$kiwi -> info ("--> Creating ISO boot image: $boot...\n");
	@bootdata = $this -> checkAndSetupPrebuiltBootImage ($sxml);
	if (! @bootdata) {
		return;
	}
	if ($bootdata[1] == 0) {
		#==========================================
		# Setup changeset to be used by boot image
		#------------------------------------------
		my %XMLChangeSet = $this -> updateDescription ($sxml);
		#==========================================
		# Create tmp dir for boot image creation
		#------------------------------------------
		my $tmpdir = qxx ("mktemp -q -d $idest/boot-iso.XXXXXX");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
			$kiwi -> failed ();
			return;
		}
		chomp $tmpdir;
		push @{$this->{tmpdirs}},$tmpdir;
		#==========================================
		# Prepare boot image...
		#------------------------------------------
		my $configDir;
		if (($stype{boot} !~ /^\//) && (! -d $stype{boot})) {
			$configDir = $this->{gdata}->{System}."/".$stype{boot};
		} else {
			$configDir = $stype{boot};
		}
		my $rootTarget = "$tmpdir/kiwi-isoboot-$$";
		my $kic = KIWIImageCreator -> new($cmdL);
		if ((! $kic) || (! $kic -> prepareBootImage (
			$configDir,$rootTarget,$this->{imageTree},\%XMLChangeSet))
		) {
			undef $kic;
			if (! -d $checkBase) {
				qxx ("rm -rf $tmpdir");
			}
			return;
		}
		#==========================================
		# Create boot image...
		#------------------------------------------
		if ((! $kic) || (! $kic -> createBootImage (
			$rootTarget,$this->{imageDest}))
		) {
			undef $kic;
			if (! -d $checkBase) {
				qxx ("rm -rf $tmpdir");
			}
			return;
		}
		#==========================================
		# Clean up tmp directory
		#------------------------------------------
		qxx ("rm -rf $tmpdir");
	}
	#==========================================
	# setup initrd/kernel names
	#------------------------------------------
	my $pinitrd = $idest."/".$bootdata[0].".gz";
	my $plinux  = $idest."/".$bootdata[0].".kernel";
	my $pxboot  = glob ($idest."/".$bootdata[0]."*xen.gz");
	if (($pxboot) && (-f $pxboot)) {
		$isxen = 1;
	}
	#==========================================
	# Check boot and system image kernel
	#------------------------------------------
	if ($cmdL->getCheckKernel()) {
		if (! $this -> checkKernel ($pinitrd,$imageTree,$bootdata[0])) {
			return;
		}
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $kboot  = KIWIBoot -> new($pinitrd,$cmdL);
	if (! defined $kboot) {
		return;
	}
	$pinitrd = $kboot -> setupSplash();
	#==========================================
	# Prepare for CD ISO image
	#------------------------------------------
	my $CD = $idest."/CD";
	$kiwi -> info ("Creating CD filesystem structure");
	qxx ("mkdir -p $CD/boot");
	push @{$this->{tmpdirs}},$CD;
	$kiwi -> done ();
	#==========================================
	# Check for optional config-cdroot archive
	#------------------------------------------
	if (-f $this->{imageDest}."/".$cdrootData) {
		$kiwi -> info ("Integrating CD root information...");
		my $data= qxx (
			"tar -C $CD -xvf $this->{imageDest}/$cdrootData"
		);
		my $code= $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to integrate CD root data: $data");
			$kiwi -> failed ();
			$this -> restoreCDRootData();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	if (-x $this->{imageDest}."/".$cdrootScript) {
		$kiwi -> info ("Calling CD root setup script...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $cdrootEnv = $imageTree."/.profile";
		if ($cdrootEnv !~ /^\//) {
			$cdrootEnv = $pwd."/".$cdrootEnv;
		}
		my $script = $this->{imageDest}."/".$cdrootScript;
		if ($script !~ /^\//) {
			$script = $pwd."/".$script;
		}
		my $data = qxx (
			"cd $CD && bash -c '. $cdrootEnv && . $script' 2>&1"
		);
		my $code = $? >> 8;
		if ($code != 0) {
			chomp $data;
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to call CD root script: $data");
			$kiwi -> failed ();
			$this -> restoreCDRootData();
			return;
		} else {
			$kiwi -> loginfo ("config-cdroot.sh: $data");
		}
		$kiwi -> done();
	}
	#==========================================
	# Restore CD root data and script
	#------------------------------------------
	$this -> restoreCDRootData();
	#==========================================
	# Installing system image file(s)
	#------------------------------------------
	$kiwi -> info ("Moving CD image data into boot structure");
	if (! defined $gzip) {
		# /.../
		# don't symlink these file because in this old live iso
		# mode we don't allow mkisofs to follow symlinks
		# ----
		qxx ("mv $this->{imageDest}/$namerw.md5 $CD");
		qxx ("mv $this->{imageDest}/$namerw.gz  $CD");
		qxx ("rm $this->{imageDest}/$namerw.*");
	}
	if (defined $gzip) {
		#qxx ("mv $this->{imageDest}/$namero $CD");
		#qxx ("rm $this->{imageDest}/$namero.*");
		qxx ("ln -s $this->{imageDest}/$namero $CD/$namero");
	} else {
		qxx ("mkdir -p $CD/read-only-system");
		qxx ("mv $imageTreeReadOnly/* $CD/read-only-system");
		rmdir $imageTreeReadOnly;
	}
	$kiwi -> done ();
	#==========================================
	# copy boot kernel and initrd
	#------------------------------------------
	$kiwi -> info ("Copying boot image and kernel [$isoarch]");
	my $destination = "$CD/boot/$isoarch/loader";
	qxx ("mkdir -p $destination");
	$data = qxx ("cp $pinitrd $destination/initrd 2>&1");
	$code = $? >> 8;
	if ($code == 0) {
		$data = qxx ("cp $plinux $destination/linux 2>&1");
		$code = $? >> 8;
	}
	if (($code == 0) && ($isxen)) {
		$data = qxx ("cp $pxboot $destination/xen.gz 2>&1");
		$code = $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Copy of isolinux boot files failed: $data");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	#==========================================
	# check for graphics boot files
	#------------------------------------------
	$kiwi -> info ("Extracting initrd for boot graphics data lookup");
	my $tmpdir = qxx ("mktemp -q -d $idest/boot-iso.XXXXXX");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed();
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return;
	}
	chomp $tmpdir;
	push @{$this->{tmpdirs}},$tmpdir;
	my $zipper = $this->{gdata}->{Gzip};
	$data = qxx ("$zipper -cd $pinitrd | (cd $tmpdir && cpio -di 2>&1)");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed();
		$kiwi -> error ("Failed to extract initrd: $data");
		$kiwi -> failed();
		return;
	}
	$kiwi -> done();
	#==========================================
	# Include MBR ID to initrd
	#------------------------------------------
	$kiwi -> info ("Saving hybrid disk label in initrd: $this->{mbrid}...");
	qxx ("mkdir -p $tmpdir/boot/grub");
	my $MBRFD = FileHandle -> new();
	if (! $MBRFD -> open (">$tmpdir/boot/mbrid")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create mbrid file: $!");
		$kiwi -> failed ();
		return;
	}
	print $MBRFD "$this->{mbrid}";
	$MBRFD -> close();
	#==========================================
	# Store mbrid flag file on CD
	#------------------------------------------
	qxx ("touch $CD/boot/$this->{mbrid}");
	#==========================================
	# Repackage initrd
	#------------------------------------------
	my @cpio = ("--create", "--format=newc", "--quiet");
	$data = qxx (
		"cd $tmpdir && find . | cpio @cpio | $zipper -f > $destination/initrd"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed();
		$kiwi -> error ("Failed to repackage initrd: $data");
		$kiwi -> failed();
		return;
	}
	$kiwi -> done();
	#==========================================
	# recreate splash data to initrd
	#------------------------------------------
	my $splash = $pinitrd;
	if (! ($splash =~ s/splash\.gz/spl/)) {
		$splash =~ s/gz/spl/;
	}
	if (-f $splash) {
		qxx ("cat $splash >> $destination/initrd");
	}
	#==========================================
	# check for boot firmware
	#------------------------------------------
	my $firmware = 'bios';
	if ($stype{firmware}) {
		$firmware = $stype{firmware};
	}
	#==========================================
	# Create bootloader configuration
	#------------------------------------------
	if ($firmware eq "efi") {
		#==========================================
		# Setup grub2 if efi live iso is requested
		#------------------------------------------
		my @theme      = $sxml -> getBootTheme_legacy();
		my $ir_modules = "$tmpdir/usr/lib/grub2-efi/x86_64-efi";
		my $ir_themes  = "$tmpdir/usr/share/grub2/themes";
		my $ir_bgnds   = "$tmpdir/usr/share/grub2/backgrounds";
		my $ir_font    = "$tmpdir/usr/share/grub2/unicode.pf2";
		my $efi_modules= "$CD/efi/boot";
		my $cd_modules = "$CD/boot/grub2-efi/x86_64-efi";
		my $cd_loader  = "$CD/boot/grub2-efi";
		my $theme      = $theme[1];
		my $ir_bg      = "$ir_bgnds/$theme/1024x768.png";
		my $cd_bg      = "$cd_loader/themes/$theme/background.png";
		my $fodir      = '/boot/grub2-efi/themes/';
		my $ascii      = 'ascii.pf2';
		my @fonts = (
			"DejaVuSans-Bold14.pf2",
			"DejaVuSans10.pf2",
			"DejaVuSans12.pf2",
			"ascii.pf2"
		);
		my @efimods = (
			'fat','ext2','gettext','part_gpt','efi_gop',
			'chain','video','video_bochs','video_cirrus',
			'gzio','efi_uga','search','configfile','png',
			'test'
		);
		my $status;
		my $result;
		#==========================================
		# Check for grub2-efi
		#------------------------------------------
		if (! -d $ir_modules) {
			$kiwi -> error ("Couldn't find grub2-efi in initrd");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# Create directory structure
		#------------------------------------------
		qxx ("mkdir -p $cd_modules");
		qxx ("mkdir -p $efi_modules");
		#==========================================
		# Copy modules/fonts/themes on CD
		#------------------------------------------
		qxx ("mv $ir_modules/* $cd_modules 2>&1");
		if (-d $ir_themes) {
			qxx ("mv $ir_themes $cd_loader 2>&1");
		}
		if (-d $ir_bgnds) {
			qxx ("cp $ir_bg $cd_bg 2>&1");
		}
		if (-e $ir_font) {
			qxx ("mv $ir_font $CD/boot");
		} else {
			$kiwi -> warning ("Can't find unicode font for grub2");
			$kiwi -> skipped ();
		}
		#==========================================
		# Create boot partition file
		#------------------------------------------
		my $bootefi = "$CD/boot/bootpart.cfg";
		my $bpfd = FileHandle -> new();
		if (! $bpfd -> open(">$bootefi")) {
			$kiwi -> error ("Couldn't create grub2 EFI bootpart map: $!");
			$kiwi -> failed ();
			return;
		}
		print $bpfd "search -f /boot/$this->{mbrid} --set"."\n";
		print $bpfd 'set prefix=($root)/boot/grub2-efi'."\n";
		$bpfd -> close();
		#==========================================
		# create efi boot image
		#------------------------------------------
		$kiwi -> info ("Creating grub2 efi boot image");
		my $core    = "$CD/efi/boot/bootx64.efi";
		my @modules = (
			'fat','ext2','part_gpt','efi_gop','iso9660','chain',
			'linux','echo','configfile','boot','search_label',
			'search_fs_file','search','search_fs_uuid','ls',
			'video','video_fb','normal','test','sleep'
		);
		my $fo = 'x86_64-efi';
		$status = qxx (
			"grub2-efi-mkimage -O $fo -o $core -c $bootefi @modules 2>&1"
		);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create efi boot image: $status");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
		#==========================================
		# make iso EFI bootable
		#------------------------------------------
		my $efi_fat = "$CD/boot/grub2-efi/efiboot.img";
		$status = qxx ("qemu-img create $efi_fat 1M 2>&1");
		$result = $? >> 8;
		if ($result == 0) {
			$status = qxx ("/sbin/mkdosfs -n 'BOOT' $efi_fat 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx ("mount -o loop $efi_fat /mnt 2>&1");
				$result = $? >> 8;
				if ($result == 0) {
					$status = qxx ("mkdir -p /mnt/efi/boot");
					$status = qxx (
						"cp $CD/efi/boot/bootx64.efi /mnt/efi/boot 2>&1"
					);
					$result = $? >> 8;
				}
				qxx ("umount /mnt 2>&1");
			}
		}
		if ($result != 0) {
			$kiwi -> error  ("Failed creating efi fat image: $status");
			$kiwi -> failed ();
			return;
		}
		$efibootloadsize = -s $efi_fat;
		#==========================================
		# create grub configuration
		#------------------------------------------
		$kiwi -> info ("Creating grub2 configuration file...");
		my $FD = FileHandle -> new();
		if (! $FD -> open(">$CD/boot/grub2-efi/grub.cfg")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create grub.cfg: $!");
			$kiwi -> failed ();
			return;
		}
		foreach my $module (@efimods) {
			print $FD "insmod $module"."\n";
		}
		print $FD "search -f /boot/$this->{mbrid} --set"."\n";
		print $FD "set default=0\n";
		print $FD "set font=/boot/unicode.pf2"."\n";
		print $FD 'if loadfont $font ;then'."\n";
		print $FD "\t"."set gfxmode=auto"."\n";
		print $FD "\t".'insmod gfxterm'."\n";
		print $FD "\t".'insmod gfxmenu'."\n";
		print $FD "\t".'terminal_input gfxterm'."\n";
		print $FD "\t".'if terminal_output gfxterm; then true; else'."\n";
		print $FD "\t\t".'terminal gfxterm'."\n";
		print $FD "\t".'fi'."\n";
		print $FD 'fi'."\n";
		print $FD 'if loadfont '.$fodir.$theme.'/'.$ascii.';then'."\n";
		foreach my $font (@fonts) {
			print $FD "\t".'loadfont '.$fodir.$theme.'/'.$font."\n";
		}
		print $FD "\t".'set theme='.$fodir.$theme.'/theme.txt'."\n";
		print $FD "\t".'background_image -m stretch ';
		print $FD $fodir.$theme.'/background.png'."\n";
		print $FD 'fi'."\n";
		my $bootTimeout = 10;
		if (defined $stype{boottimeout}) {
			$bootTimeout = $stype{boottimeout};
		}
		if ($stype{fastboot}) {
			$bootTimeout = 0;
		}
		print $FD "set timeout=$bootTimeout\n";
		my $title = $systemDisplayName;
		my $lsafe = "Failsafe -- ".$title;
		print $FD 'menuentry "'.$title.'"';
		print $FD ' --class opensuse --class os {'."\n";
		#==========================================
		# Standard boot
		#------------------------------------------
		if (! $isxen) {
			print $FD "\t"."echo Loading linux...\n";
			print $FD "\t"."set gfxpayload=keep"."\n";
			print $FD "\t"."linux /boot/$isoarch/loader/linux";
			print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
			print $FD " splash=silent"."\n";
			print $FD "\t"."echo Loading initrd...\n";
			print $FD "\t"."initrd /boot/$isoarch/loader/initrd\n";
			print $FD "}\n";
		} else {
			print $FD "\t"."echo Loading Xen\n";
			print $FD "\t"."multiboot /boot/$isoarch/loader/xen.gz dummy\n";
			print $FD "\t"."echo Loading linux...\n";
			print $FD "\t"."set gfxpayload=keep"."\n";
			print $FD "\t"."module /boot/$isoarch/loader/linux dummy";
			print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
			print $FD " splash=silent"."\n";
			print $FD "\t"."echo Loading initrd...\n";
			print $FD "\t"."module /boot/$isoarch/loader/initrd dummy\n";
			print $FD "}\n";
		}
		#==========================================
		# Failsafe boot
		#------------------------------------------
		print $FD 'menuentry "'.$lsafe.'"';
		print $FD ' --class opensuse --class os {'."\n";
		if (! $isxen) {
			print $FD "\t"."echo Loading linux...\n";
			print $FD "\t"."set gfxpayload=keep"."\n";
			print $FD "\t"."linux /boot/$isoarch/loader/linux";
			print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
			print $FD " splash=silent";
			print $FD " ide=nodma apm=off acpi=off noresume selinux=0";
			print $FD " nosmp noapic maxcpus=0 edd=off"."\n";
			print $FD "\t"."echo Loading initrd...\n";
			print $FD "\t"."initrd /boot/$isoarch/loader/initrd\n";
			print $FD "}\n";
		} else {
			print $FD "\t"."echo Loading Xen\n";
			print $FD "\t"."multiboot /boot/$isoarch/loader/xen.gz dummy\n";
			print $FD "\t"."echo Loading linux...\n";
			print $FD "\t"."set gfxpayload=keep"."\n";
			print $FD "\t"."module /boot/$isoarch/loader/linux dummy";
			print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
			print $FD " splash=silent";
			print $FD " ide=nodma apm=off acpi=off noresume selinux=0";
			print $FD " nosmp noapic maxcpus=0 edd=off"."\n";
			print $FD "\t"."echo Loading initrd...\n";
			print $FD "\t"."module /boot/$isoarch/loader/initrd dummy\n";
			print $FD "}\n";
		}
		#==========================================
		# setup isolinux checkmedia boot entry
		#------------------------------------------
		if ($cmdL->getISOCheck()) {
			print $FD 'menuentry mediacheck';
			print $FD ' --class opensuse --class os {'."\n";
			if (! $isxen) {
				print $FD "\t"."echo Loading linux...\n";
				print $FD "\t"."set gfxpayload=keep"."\n";
				print $FD "\t"."linux /boot/$isoarch/loader/linux";
				print $FD " mediacheck=1 splash=silent";
				print $FD "\t"."echo Loading initrd...\n";
				print $FD "\t"."initrd /boot/$isoarch/loader/initrd\n";
				print $FD "}\n";
			} else {
				print $FD "\t"."echo Loading Xen\n";
				print $FD "\t"."multiboot /boot/$isoarch/loader/xen.gz dummy\n";
				print $FD "\t"."echo Loading linux...\n";
				print $FD "\t"."set gfxpayload=keep"."\n";
				print $FD "\t"."module /boot/$isoarch/loader/linux dummy";
				print $FD " mediacheck=1 splash=silent";
				print $FD "\t"."echo Loading initrd...\n";
				print $FD "\t"."module /boot/$isoarch/loader/initrd dummy\n";
				print $FD "}\n";
			}
		}
		#==========================================
		# setup harddisk entry
		#------------------------------------------
		# try to chainload another linux efi module from
		# the fixed hd0,1 partition. It's not certain that
		# this preconditions are true in any case
		# ----
		print $FD 'menuentry "Boot from Hard Disk"';
		print $FD ' --class opensuse --class os {'."\n";
		print $FD "\t"."set root='hd0,1'"."\n";
		print $FD "\t".'chainloader /efi/boot/bootx64.efi'."\n";
		print $FD '}'."\n";
		#==========================================
		# setup memtest entry
		#------------------------------------------
		# memtest will not work in grub2-efi. This is because efi
		# does not support launching 16-bit binaries and memtest is
		# a 16-bit binary. Thats also the reason why there is no
		# linux16 command/module in grub2 efi
		# ----
		$FD -> close();
		#==========================================
		# copy grub config to efi directory too
		#------------------------------------------
		qxx ("cp $CD/boot/grub2-efi/grub.cfg $CD/efi/boot");
		$kiwi -> done();
	}
	#==========================================
	# copy base graphics boot CD files
	#------------------------------------------
	$kiwi -> info ("Setting up isolinux boot CD [$isoarch]");
	my $gfx = $tmpdir."/image/loader";
	$data = qxx ("cp -a $gfx/* $destination");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Copy failed: $data");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	#==========================================
	# setup isolinux boot label name
	#------------------------------------------
	my $label = $this->makeLabel ($systemDisplayName);
	my $lsafe = $this->makeLabel ("Failsafe -- ".$label);
	#==========================================
	# setup isolinux.cfg file
	#------------------------------------------
	$kiwi -> info ("Creating isolinux configuration...");
	my $syslinux_new_format = 0;
	my $bootTimeout = $stype{boottimeout} ? int $stype{boottimeout} : 200;
	if (-f "$gfx/gfxboot.com" || -f "$gfx/gfxboot.c32") {
		$syslinux_new_format = 1;
	}
	my $IFD = FileHandle -> new();
	if (! $IFD -> open (">$destination/isolinux.cfg")) {
		$kiwi -> failed();
		$kiwi -> error  ("Failed to create $destination/isolinux.cfg: $!");
		$kiwi -> failed ();
		if (! -d $checkBase) {
			qxx ("rm -rf $cmdL->getRootTargetDir()");
			qxx ("rm -rf $tmpdir");
		}
		return;
	}
	binmode($IFD, ":encoding(UTF-8)");
	print $IFD "default $label"."\n";
	print $IFD "implicit 1"."\n";
	print $IFD "display isolinux.msg"."\n";
	if (-f "$gfx/bootlogo" ) {
		if ($syslinux_new_format) {
			print $IFD "ui gfxboot bootlogo isolinux.msg"."\n";
		} else {
			print $IFD "gfxboot bootlogo"."\n";
		}
	}
	print $IFD "prompt   1"."\n";
	print $IFD "timeout  $bootTimeout"."\n";
	if (! $isxen) {
		print $IFD "label $label"."\n";
		print $IFD "  kernel linux"."\n";
		print $IFD "  append initrd=initrd ramdisk_size=512000 ";
		print $IFD "ramdisk_blocksize=4096 splash=silent${cmdline} showopts ";
		#print FD "console=ttyS0,9600n8 console=tty0${cmdline} showopts ";
		if ($vga) {
			print $IFD "vga=$vga ";
		}
		print $IFD "\n";
		print $IFD "label $lsafe"."\n";
		print $IFD "  kernel linux"."\n";
		print $IFD "  append initrd=initrd ramdisk_size=512000 ";
		print $IFD "ramdisk_blocksize=4096 splash=silent${cmdline} showopts ";
		print $IFD "ide=nodma apm=off acpi=off noresume selinux=0 nosmp ";
		print $IFD "noapic maxcpus=0 edd=off"."\n";
	} else {
		print $IFD "label $label"."\n";
		print $IFD "  kernel mboot.c32"."\n";
		print $IFD "  append xen.gz --- linux ramdisk_size=512000 ";
		print $IFD "ramdisk_blocksize=4096 splash=silent${cmdline} ";
		if ($vga) {
			print $IFD "vga=$vga ";
		}
		print $IFD "--- initrd showopts"."\n";
		print $IFD "\n";
		print $IFD "label $lsafe"."\n";
		print $IFD "  kernel mboot.c32"."\n";
		print $IFD "  append xen.gz --- linux ramdisk_size=512000 ";
		print $IFD "ramdisk_blocksize=4096 splash=silent${cmdline} ";
		print $IFD "ide=nodma apm=off acpi=off noresume selinux=0 nosmp ";
		print $IFD "noapic maxcpus=0 edd=off ";
		print $IFD "--- initrd showopts"."\n";
	}
	#==========================================
	# setup isolinux checkmedia boot entry
	#------------------------------------------
	if ($cmdL->getISOCheck()) {
		print $IFD "\n";
		if (! $isxen) {
			print $IFD "label mediacheck"."\n";
			print $IFD "  kernel linux"."\n";
			print $IFD "  append initrd=initrd splash=silent mediacheck=1";
			print $IFD "$cmdline ";
			print $IFD "showopts"."\n";
		} else {
			print $IFD "label mediacheck"."\n";
			print $IFD "  kernel mboot.c32"."\n";
			print $IFD "  append xen.gz --- linux splash=silent mediacheck=1";
			print $IFD "$cmdline ";
			print $IFD "--- initrd showopts"."\n";
		}
	}
	#==========================================
	# setup default harddisk/memtest entries
	#------------------------------------------
	print $IFD "\n";
	print $IFD "label harddisk\n";
	print $IFD "  localboot 0x80"."\n";
	print $IFD "\n";
	print $IFD "label memtest"."\n";
	print $IFD "  kernel memtest"."\n";
	print $IFD "\n";
	$IFD -> close();
	#==========================================
	# setup isolinux.msg file
	#------------------------------------------
	my $MFD = FileHandle -> new();
	if (! $MFD -> open (">$destination/isolinux.msg")) {
		$kiwi -> failed();
		$kiwi -> error  ("Failed to create isolinux.msg: $!");
		$kiwi -> failed ();
		if (! -d $checkBase) {
			qxx ("rm -rf $cmdL->getRootTargetDir()");
			qxx ("rm -rf $tmpdir");
		}
		return;
	}
	print $MFD "\n"."Welcome !"."\n\n";
	print $MFD "To start the system enter '".$label."' and press <return>"."\n";
	print $MFD "\n\n";
	print $MFD "Available boot options:\n";
	printf ($MFD "%-20s - %s\n",$label,"Live System");
	printf ($MFD "%-20s - %s\n",$lsafe,"Live System failsafe mode");
	printf ($MFD "%-20s - %s\n","harddisk","Local boot from hard disk");
	printf ($MFD "%-20s - %s\n","mediacheck","Media check");
	printf ($MFD "%-20s - %s\n","memtest","Memory Test");
	print $MFD "\n";
	print $MFD "Have a lot of fun..."."\n";
	$MFD -> close();
	$kiwi -> done();
	#==========================================
	# Cleanup tmpdir
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	#==========================================
	# Create boot configuration
	#------------------------------------------
	my $CFD = FileHandle -> new();
	if (! $CFD -> open (">$CD/config.isoclient")) {
		$kiwi -> error  ("Couldn't create image boot configuration");
		$kiwi -> failed ();
		return;
	}
	if ((! defined $gzip) || ($gzip =~ /^clic/)) {
		print $CFD "IMAGE='/dev/ram1;$namecd'\n";
	} else {
		print $CFD "IMAGE='/dev/loop1;$namecd'\n";
	}
	if (defined $gzip) {
		if ($gzip =~ /^clic/) {
			print $CFD "UNIONFS_CONFIG='/dev/ram1,/dev/loop1,clicfs'\n";
		} elsif ($gzip =~ /^seed/) {
			print $CFD "UNIONFS_CONFIG='/dev/ram1,/dev/loop1,seed'\n";
		} else {
			print $CFD "COMBINED_IMAGE=yes\n";
		}
	}
	$CFD -> close();
	#==========================================
	# create ISO image
	#------------------------------------------
	$kiwi -> info ("Creating ISO image...\n");
	my $isoerror = 1;
	my $name = $this->{imageDest}."/".$namerw.".iso";
	my $attr = "-R -J -f -pad -joliet-long";
	if (! defined $gzip) {
		$attr = "-R -J -pad -joliet-long";
	}
	if ((defined $stype{flags}) && ($stype{flags} =~ /clic_udf|seed/)) {
		$attr .= " -allow-limited-size -udf";
	}
	if (! defined $gzip) {
		$attr .= " -iso-level 4";
	}
	if ($stype{volid}) {
		$attr .= " -V \"$stype{volid}\"";
	}
	$attr .= " -A \"$this->{mbrid}\"";
	$attr .= ' -p "'.$this->{gdata}->{Preparer}.'"';
	$attr .= ' -publisher "'.$this->{gdata}->{Publisher}.'"';
	my $isolinux = KIWIIsoLinux -> new (
		$CD,$name,$attr,"checkmedia",$this->{cmdL},$this->{xml}
	);
	if (defined $isolinux) {
		$isoerror = 0;
		if (! $isolinux -> callBootMethods()) {
			$isoerror = 1;
		}
		if ($firmware eq "efi") {
			if (! $isolinux -> addBootEFILive($efibootloadsize)) {
				$isoerror = 1;
			}
		}
		if (! $isolinux -> createISO()) {
			$isoerror = 1;
		}
	}
	if ($isoerror) {
		return;
	}
	#==========================================
	# relocate boot catalog
	#------------------------------------------
	if (! $isolinux -> relocateCatalog()) {
		return;
	}
	if (! $isolinux -> fixCatalog()) {
		return;
	}
	#==========================================
	# Turn ISO into hybrid if requested
	#------------------------------------------
	if ($hybrid) {
		$kiwi -> info ("Setting up hybrid ISO...");
		if (! $isolinux -> createHybrid ($this->{mbrid})) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to create hybrid ISO image");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# tag ISO image with tagmedia
	#------------------------------------------
	if (-x "/usr/bin/tagmedia") {
		$kiwi -> info ("Adding checkmedia tag...");
		if (! $isolinux -> checkImage()) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to tag ISO image");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# cleanup
	#------------------------------------------
	qxx ("rm -rf $CD 2>&1");
	return $this;
}

#==========================================
# createImageSplit
#------------------------------------------
sub createImageSplit {
	# ...
	# Create all split images and the specified boot image which
	# should be used in combination to this split image. The process
	# requires subsequent kiwi calls to create the vmx/oemboot
	# required virtual disk images or the created images needs
	# to be copied into a PXE boot structure for use with
	# a netboot setup.
	# ---
	my $this = shift;
	my $type = shift;
	my $nopersistent = shift;
	my $kiwi = $this->{kiwi};
	my $cmdL = $this->{cmdL};
	my $arch = $this->{arch};
	my $imageTree  = $this->{imageTree};
	my $baseSystem = $this->{baseSystem};
	my $sxml       = $this->{xml};
	my $idest      = $cmdL->getImageIntermediateTargetDir();
	my %xenc       = $sxml->getXenConfig_legacy();
	my $fsopts     = $cmdL -> getFilesystemOptions();
	my $inodesize  = $fsopts->[1];
	my $FSTypeRW;
	my $FSTypeRO;
	my $error;
	my $ok;
	my @bootdata;
	my $imageTreeRW;
	my $imageTreeTmp;
	my $mbytesro;
	my $mbytesrw;
	my $xmlsize;
	my $boot;
	my $plinux;
	my $pinitrd;
	my $data;
	my $code;
	my $name;
	my $treebase;
	my $xendomain;
	my $minInodes;
	my $sizeBytes;
	my $rootTarget = $cmdL->getRootTargetDir();
	if (! $rootTarget) {
		$rootTarget = $cmdL->getConfigDir();
	}
	my $checkBase = $rootTarget."/".$baseSystem;
	#==========================================
	# check for xen domain setup
	#------------------------------------------
	if (defined $xenc{xen_domain}) {
		$xendomain = $xenc{xen_domain};
	} else {
		$xendomain = "dom0";
	}
	#==========================================
	# turn image path into absolute path
	#------------------------------------------
	if ($imageTree !~ /^\//) {
		my $pwd = qxx ("pwd"); chomp $pwd;
		$imageTree = $pwd."/".$imageTree;
	}
	#==========================================
	# Get filesystem info for split image
	#------------------------------------------
	if ($type =~ /(.*),(.*):(.*)/) {
		$FSTypeRW = $1;
		$FSTypeRO = $2;
		$boot = $3;
	} elsif ($type =~ /(.*),(.*)/) {
		$FSTypeRW = $1;
		$FSTypeRO = $2;
	} else {
		$kiwi -> error  ("Invalid filesystem setup for split type");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Get system image type information
	#------------------------------------------
	my %type = %{$sxml->getImageTypeAndAttributes_legacy()};
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $namerw = $main::global -> generateBuildImageName(
		$this->{xml},'-', '-read-write'
	);
	my $namero = $main::global -> generateBuildImageName($this->{xml});
	if (! defined $namerw) {
		return;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! $this -> setupLogicalExtend ("quiet", $namero)) {
		return;
	}
	#==========================================
	# Create clone of prepared tree
	#------------------------------------------
	$kiwi -> info ("Creating root tree clone for split operations");
	$treebase = basename $imageTree;
	if (-d $this->{imageDest}."/".$treebase) {
		qxx ("rm -rf $this->{imageDest}/$treebase");
	}
	$data = qxx ("cp -a -x $imageTree $this->{imageDest}");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Can't create copy of image tree: $data");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTree");
		return;
	}
	$kiwi -> done();
	#==========================================
	# split physical extend into RW/RO/tmp part
	#------------------------------------------
	$imageTree = $this->{imageDest}."/".$treebase;
	if ($imageTree !~ /^\//) {
		my $pwd = qxx ("pwd"); chomp $pwd;
		$imageTree = $pwd."/".$imageTree;
	}
	$imageTreeTmp = $imageTree;
	$imageTreeTmp =~ s/\/+$//;
	$imageTreeTmp.= "-tmp/";
	$this->{imageTreeTmp} = $imageTreeTmp;
	#==========================================
	# run split tree creation
	#------------------------------------------
	$kiwi -> info ("Creating temporary image part...\n");
	if (! mkdir $imageTreeTmp) {
		$error = $!;
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create split tmp directory: $error");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTree");
		return;
	}
	#==========================================
	# walk through except files if any
	#------------------------------------------
	my %exceptHash;
	foreach my $except ($sxml -> getSplitTempExceptions_legacy()) {
		my $globsource = "${imageTree}${except}";
		my @files = qxx ("find $globsource -xtype f 2>/dev/null");
		my $code  = $? >> 8;
		if ($code != 0) {
			# excepted file(s) doesn't exist anyway
			next;
		}
		chomp @files;
		foreach my $file (@files) {
			$exceptHash{$file} = $file;
		}
	}
	#==========================================
	# create linked list for files, create dirs
	#------------------------------------------
	my $createTmpTree = sub {
		my $file  = $_;
		my $dir   = $File::Find::dir;
		my $path  = "$dir/$file";
		my $target= $path;
		$target =~ s#$imageTree#$imageTreeTmp#;
		my $rerooted = $path;
		$rerooted =~ s#$imageTree#/read-only/#;
		my $st = lstat($path);
		if (S_ISDIR($st->mode)) {
			mkdir $target;
			chmod S_IMODE($st->mode), $target;
			chown $st->uid, $st->gid, $target;
		} elsif (
			S_ISCHR($st->mode)  ||
			S_ISBLK($st->mode)  ||
			S_ISLNK($st->mode)
		) {
			qxx ("cp -a $path $target");
		} else {
			$rerooted =~ s#/+#/#g;
			symlink ($rerooted, $target);
		}
	};
	find(\&$createTmpTree, $imageTree);
	my @tempFiles    = $sxml -> getSplitTempFiles_legacy ();
	my @persistFiles = $sxml -> getSplitPersistentFiles_legacy ();
	if ($nopersistent) {
		push (@tempFiles, @persistFiles);
		undef @persistFiles;
	}
	#==========================================
	# search temporary files, respect excepts
	#------------------------------------------
	my %tempFiles_new;
	if (@tempFiles) {
		foreach my $temp (@tempFiles) {
			my $globsource = "${imageTree}${temp}";
			my @files = qxx ("find $globsource -xtype f 2>/dev/null");
			my $code  = $? >> 8;
			if ($code != 0) {
				$kiwi -> warning ("file $globsource doesn't exist");
				$kiwi -> skipped ();
				next;
			}
			chomp @files;
			foreach (@files) {
				$tempFiles_new{$_} = $_;
			}
		}
	}
	@tempFiles = sort keys %tempFiles_new;
	if (@tempFiles) {
		foreach my $file (@tempFiles) {
			if (defined $exceptHash{$file}) {
				next;
			}
			my $dest = $file;
			$dest =~ s#$imageTree#$imageTreeTmp#;
			qxx ("rm -rf $dest");
			qxx ("mv $file $dest");
		}
	}
	#==========================================
	# find persistent files for the read-write
	#------------------------------------------
	$imageTreeRW = $imageTree;
	$imageTreeRW =~ s/\/+$//;
	$imageTreeRW.= "-read-write";
	if (@persistFiles) {
		$kiwi -> info ("Creating read-write image part...\n");
		#==========================================
		# Create read-write directory
		#------------------------------------------
		$this->{imageTreeRW} = $imageTreeRW;
		if (! mkdir $imageTreeRW) {
			$error = $!;
			$kiwi -> error  (
				"Couldn't create split read-write directory: $error"
			);
			$kiwi -> failed ();
			qxx ("rm -rf $imageTree $imageTreeTmp");
			return;
		}
		#==========================================
		# walk through except files if any
		#------------------------------------------
		my %exceptHash;
		foreach my $except ($sxml -> getSplitPersistentExceptions_legacy()) {
			my $globsource = "${imageTree}${except}";
			my @files = qxx ("find $globsource -xtype f 2>/dev/null");
			my $code  = $? >> 8;
			if ($code != 0) {
				# excepted file(s) doesn't exist anyway
				next;
			}
			chomp @files;
			foreach my $file (@files) {
				$exceptHash{$file} = $file;
			}
		}
		#==========================================
		# search persistent files, respect excepts
		#------------------------------------------
		my %expandedPersistFiles;
		foreach my $persist (@persistFiles) {
			my $globsource = "${imageTree}${persist}";
			my @files = qxx ("find $globsource 2>/dev/null");
			my $code  = $? >> 8;
			if ($code != 0) {
				$kiwi -> warning ("file $globsource doesn't exist");
				$kiwi -> skipped ();
				next;
			}
			chomp @files;
			foreach my $file (@files) {
				if (defined $exceptHash{$file}) {
					next;
				}
				$expandedPersistFiles{$file} = $file;
			}
		}
		@persistFiles = keys %expandedPersistFiles;
		#==========================================
		# relink to read-write, and move files
		#------------------------------------------
		foreach my $file (@persistFiles) {
			my $dest = $file;
			my $link = $file;
			my $rlnk = $file;
			$dest =~ s#$imageTree#$imageTreeRW#;
			$link =~ s#$imageTree#$imageTreeTmp#;
			$rlnk =~ s#$imageTree#/read-write#;
			if (-d $file) {
				#==========================================
				# recreate directory
				#------------------------------------------
				my $st = stat($file);
				qxx ("mkdir -p $dest");
				chmod S_IMODE($st->mode), $dest;
				chown $st->uid, $st->gid, $dest;
			} else {
				#==========================================
				# move file to read-write area
				#------------------------------------------
				my $st = stat(dirname $file);
				my $destdir = dirname $dest;
				qxx ("rm -rf $dest");
				qxx ("mkdir -p $destdir");
				chmod S_IMODE($st->mode), $destdir;
				chown $st->uid, $st->gid, $destdir;
				qxx ("mv $file $dest");
				#==========================================
				# relink file to read-write area
				#------------------------------------------
				qxx ("rm -rf $link");
				qxx ("ln -s $rlnk $link");
			}
		}
		#==========================================
		# relink if entire directory was set
		#------------------------------------------
		foreach my $persist ($sxml -> getSplitPersistentFiles_legacy()) {
			my $globsource = "${imageTree}${persist}";
			if (-d $globsource) {
				my $link = $globsource;
				my $rlnk = $globsource;
				$link =~ s#$imageTree#$imageTreeTmp#;
				$rlnk =~ s#$imageTree#/read-write#;
				#==========================================
				# relink directory to read-write area
				#------------------------------------------
				qxx ("rm -rf $link");
				qxx ("ln -s $rlnk $link");
			}
		}
	}
	#==========================================
	# Embed rootfs meta data into ro extend
	#------------------------------------------
	$minInodes = qxx ("find $imageTreeTmp | wc -l");
	$sizeBytes = qxx ("du -s --block-size=1 $imageTreeTmp | cut -f1");
	$sizeBytes+= $minInodes * $inodesize;
	$sizeBytes = sprintf ("%.0f", $sizeBytes);
	$minInodes*= 2;
	if (open (my $FD, '>', "$imageTree/rootfs.meta")) {
		print $FD "inode_nr=$minInodes\n";
		print $FD "min_size=$sizeBytes\n";
		close $FD;
	} else {
		$kiwi -> error  ("Failed to create rootfs meta data: $!");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTreeTmp");
		qxx ("rm -rf $imageTree");
		return;
	}
	#==========================================
	# Embed rootfs.tar for tmpfs into ro extend
	#------------------------------------------
	$data = qxx (
		"cd $imageTreeTmp && tar -cf $imageTree/rootfs.tar * 2>&1"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to create rootfs tarball: $data");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTreeTmp");
		qxx ("rm -rf $imageTree");
		return;
	}
	#==========================================
	# Clean rootfs tmp tree
	#------------------------------------------
	qxx ("rm -rf $imageTreeTmp");
	#==========================================
	# Count disk space for extends
	#------------------------------------------
	$kiwi -> info ("Computing disk space...");
	($mbytesro,$xmlsize) = $this -> getSize ($imageTree);
	if (defined $this->{imageTreeRW}) {
		($mbytesrw,$xmlsize) = $this -> getSize ($imageTreeRW);
	}
	$kiwi -> done ();
	if (defined $this->{imageTreeRW}) {
		#==========================================
		# Create RW logical extend
		#------------------------------------------
		if (defined $this->{imageTreeRW}) {
			$kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
			if (! $this -> buildLogicalExtend ($namerw,$mbytesrw."M")) {
				qxx ("rm -rf $imageTreeRW");
				qxx ("rm -rf $imageTree");
				return;
			}
			$kiwi -> done();
		}
		#==========================================
		# Create filesystem on RW extend
		#------------------------------------------
		SWITCH: for ($FSTypeRW) {
			/ext2/       && do {
				$ok = $this -> setupEXT2 ( $namerw );
				last SWITCH;
			};
			/ext3/       && do {
				$ok = $this -> setupEXT2 ( $namerw,"journaled-ext3" );
				last SWITCH;
			};
			/ext4/       && do {
				$ok = $this -> setupEXT2 ( $namerw,"journaled-ext4" );
				last SWITCH;
			};
			/reiserfs/   && do {
				$ok = $this -> setupReiser ( $namerw );
				last SWITCH;
			};
			/btrfs/      && do {
				$ok = $this -> setupBTRFS ( $namerw );
				last SWITCH;
			};
			/xfs/        && do {
				$ok = $this -> setupXFS ( $namerw );
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $FSTypeRW");
			$kiwi -> failed ();
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
			return;
		}
		if (! $ok) {
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
			return;
		}
	}
	#==========================================
	# Create RO logical extend
	#------------------------------------------
	$kiwi -> info ("Image RO part requires $mbytesro MB of disk space");
	if (! $this -> buildLogicalExtend ($namero,$mbytesro."M")) {
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		return;
	}
	$kiwi -> done();
	#==========================================
	# Create filesystem on RO extend
	#------------------------------------------
	SWITCH: for ($FSTypeRO) {
		/ext2/       && do {
			$ok = $this -> setupEXT2 ( $namero );
			last SWITCH;
		};
		/ext3/       && do {
			$ok = $this -> setupEXT2 ( $namero,"journaled-ext3" );
			last SWITCH;
		};
		/ext4/       && do {
			$ok = $this -> setupEXT2 ( $namero,"journaled-ext4" );
			last SWITCH;
		};
		/reiserfs/   && do {
			$ok = $this -> setupReiser ( $namero );
			last SWITCH;
		};
		/btrfs/      && do {
			$ok = $this -> setupBTRFS ( $namero );
			last SWITCH;
		};
		/squashfs/   && do {
			$ok = $this -> setupSquashFS ( $namero,$imageTree );
			last SWITCH;
		};
		/xfs/      && do {
			$ok = $this -> setupXFS ( $namero );
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported type: $FSTypeRO");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		$this -> cleanLuks();
		return;
	}
	if (! $ok) {
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		$this -> cleanLuks();
		return;
	}
	#==========================================
	# Install logical extends
	#------------------------------------------
	foreach my $name ($namerw,$namero) {
		#==========================================
		# select physical extend
		#------------------------------------------
		my $source;
		my $type;
		if ($name eq $namerw) {
			$source = $imageTreeRW;
			$type = $FSTypeRW;
		} else {
			$source = $imageTree;
			$type = $FSTypeRO;
		}
		if (! -d $source) {
			next;
		}
		my %fsattr = $main::global -> checkFileSystem ($type);
		if (! $fsattr{readonly}) {
			#==========================================
			# mount logical extend for data transfer
			#------------------------------------------
			my $extend = $this -> mountLogicalExtend ($name);
			if (! defined $extend) {
				qxx ("rm -rf $imageTreeRW");
				qxx ("rm -rf $imageTree");
				$this -> cleanLuks();
				return;
			}
			#==========================================
			# copy physical to logical
			#------------------------------------------
			if (! $this -> installLogicalExtend ($extend,$source)) {
				qxx ("rm -rf $imageTreeRW");
				qxx ("rm -rf $imageTree");
				$this -> cleanLuks();
				return;
			}
			$this -> cleanMount();
		}
		#==========================================
		# Checking file system
		#------------------------------------------
		$kiwi -> info ("Checking file system: $type...");
		SWITCH: for ($type) {
			/ext2/       && do {
				qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/ext3/       && do {
				qxx ("/sbin/fsck.ext3 -f -y $this->{imageDest}/$name 2>&1");
				qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/ext4/       && do {
				qxx ("/sbin/fsck.ext4 -f -y $this->{imageDest}/$name 2>&1");
				qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/reiserfs/   && do {
				qxx ("/sbin/reiserfsck -y $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/btrfs/      && do {
				qxx ("/sbin/btrfsck $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/squashfs/   && do {
				$kiwi -> done ();
				last SWITCH;
			};
			/xfs/        && do {
				qxx ("/sbin/mkfs.xfs $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type");
			$kiwi -> failed ();
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
			return;
		}
		#==========================================
		# Create image md5sum
		#------------------------------------------
		$this -> restoreImageDest();
		if (! $this -> buildMD5Sum ($name)) {
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
			return;
		}
		$this -> remapImageDest();
	}
	$this -> restoreImageDest();
	$this -> cleanLuks();
	#==========================================
	# Create network boot configuration
	#------------------------------------------
	if (! $this -> writeImageConfig ($namero)) {
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		return;
	}
	#==========================================
	# Cleanup temporary data
	#------------------------------------------
	qxx ("rm -rf $imageTreeRW");
	qxx ("rm -rf $imageTree");
	#==========================================
	# build boot image only if specified
	#------------------------------------------
	if (! defined $boot) {
		return $this;
	}
	#==========================================
	# Prepare and Create boot image
	#------------------------------------------
	$imageTree = $this->{imageTree};
	$kiwi -> info ("--> Creating boot image: $boot...\n");
	@bootdata = $this -> checkAndSetupPrebuiltBootImage ($sxml);
	if (! @bootdata) {
		return;
	}
	if ($bootdata[1] == 0) {
		#==========================================
		# Setup changeset to be used by boot image
		#------------------------------------------
		my %XMLChangeSet = $this -> updateDescription ($sxml);
		#==========================================
		# Create tmp dir for boot image creation
		#------------------------------------------
		my $tmpdir = qxx ("mktemp -q -d $idest/boot-split.XXXXXX");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
			$kiwi -> failed ();
			return;
		}
		chomp $tmpdir;
		push @{$this->{tmpdirs}},$tmpdir;
		#==========================================
		# Prepare boot image...
		#------------------------------------------
		my $configDir;
		if (($type{boot} !~ /^\//) && (! -d $type{boot})) {
			$configDir = $this->{gdata}->{System}."/".$type{boot};
		} else {
			$configDir = $type{boot};
		}
		my $rootTarget = "$tmpdir/kiwi-splitboot-$$";
		my $kic = KIWIImageCreator -> new($cmdL);
		if ((! $kic) || (! $kic -> prepareBootImage (
			$configDir,$rootTarget,$this->{imageTree},\%XMLChangeSet))
		) {
			undef $kic;
			if (! -d $checkBase) {
				qxx ("rm -rf $tmpdir");
			}
			return;
		}
		#==========================================
		# Create boot image...
		#------------------------------------------
		if ((! $kic) || (! $kic -> createBootImage (
			$rootTarget,$this->{imageDest}))
		) {
			undef $kic;
			if (! -d $checkBase) {
				qxx ("rm -rf $tmpdir");
			}
			return;
		}
		#==========================================
		# Clean up tmp directory
		#------------------------------------------
		qxx ("rm -rf $tmpdir");
	}
	#==========================================
	# setup initrd name
	#------------------------------------------
	my $initrd = $idest."/".$bootdata[0].".gz";
	if (! -f $initrd) {
		$initrd = $idest."/".$bootdata[0];
	}
	#==========================================
	# Check boot and system image kernel
	#------------------------------------------
	if ($cmdL->getCheckKernel()) {
		if (! $this -> checkKernel ($initrd,$imageTree,$bootdata[0])) {
			return;
		}
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $kboot  = KIWIBoot -> new($initrd,$cmdL);
	if (! defined $kboot) {
		return;
	}
	$kboot -> setupSplash();
	#==========================================
	# Store meta data for subsequent calls
	#------------------------------------------
	$name->{systemImage} = $main::global -> generateBuildImageName($sxml);
	$name->{bootImage}   = $bootdata[0];
	$name->{format}      = $type{format};
	if ($boot =~ /vmxboot|oemboot/) {
		#==========================================
		# Create virtual disk images if requested
		#------------------------------------------
		$cmdL -> setInitrdFile (
			$idest."/".$name->{bootImage}.".splash.gz"
		);
		$cmdL -> setSystemLocation (
			$idest."/".$name->{systemImage}
		);
		my $kic = KIWIImageCreator -> new($cmdL);
		if ((! $kic) || (! $kic->createImageDisk())) {
			undef $kic;
			return;
		}
		#==========================================
		# Create VM format/configuration
		#------------------------------------------
		if ((defined $name->{format}) || ($xendomain eq "domU")) {
			$cmdL -> setSystemLocation (
				$idest."/".$name->{systemImage}.".raw"
			);
			$cmdL -> setImageFormat ($name->{format});
			my $kic = KIWIImageCreator -> new($cmdL);
			if ((! $kic) || (! $kic->createImageFormat($sxml))) {
				undef $kic;
				return;
			}
		}
	}
	return $this;
}

#==========================================
# getBlocks
#------------------------------------------
sub getBlocks {
	# ...
	# calculate the block size and number of blocks used
	# to create a <size> bytes long image. Return list
	# (bs,count,seek)
	# ---
	my $this = shift;
	my $size = shift;
	my $bigimage   = 1048576; # 1M
	my $smallimage = 8192;    # 8K
	my $number;
	my $suffix;
	my $count;
	my $seek;
	if ($size =~ /(\d+)(.*)/) {
		$number = $1;
		$suffix = $2;
		SWITCH: for ($suffix) {
			/K/i && do {
				$number *= 1024;
				last SWITCH;
			}; 
			/M/i && do {
				$number *= 1024 * 1024;
				last SWITCH;
			}; 
			/G/i && do {
				$number *= 1024 * 1024 * 1024;
				last SWITCH;
			};
		}
	} else {
		$number = $size;
	}
	if ($number > 100 * 1024 * 1024) {
		# big image...
		$count = $number / $bigimage;
		$count = Math::BigFloat->new($count)->ffround(0);
		$seek  = $count*$bigimage;
		return (($bigimage,$count,$seek));
	} else {
		# small image...
		$count = $number / $smallimage;
		$count = Math::BigFloat->new($count)->ffround(0);
		$seek  = $count*$smallimage;
		return (($smallimage,$count,$seek));
	}
}

#==========================================
# preImage
#------------------------------------------
sub preImage {
	# ...
	# pre-stage preparation of a logical extend.
	# This method includes all common not filesystem
	# dependant tasks before the logical extend
	# has been created
	# ---
	my $this       = shift;
	my $haveExtend = shift;
	my $quiet      = shift;
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $name = $main::global -> generateBuildImageName($this->{xml});
	if (! defined $name) {
		return;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	my $mBytes = $this -> setupLogicalExtend ($quiet,$name);
	if (! defined $mBytes) {
		return;
	}
	#==========================================
	# Create logical extend
	#------------------------------------------
	if (! $this -> buildLogicalExtend ($name,$mBytes."M",$haveExtend)) {
		return;
	}
	return $name;
}

#==========================================
# writeImageConfig
#------------------------------------------
sub writeImageConfig {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $configName = $main::global -> generateBuildImageName($this->{xml})
		. '.config';
	my $device = $xml -> getPXEDeployImageDevice_legacy ();
	my %type = %{$xml -> getImageTypeAndAttributes_legacy()};
	#==========================================
	# create .config for types which needs it
	#------------------------------------------
	if (defined $device) {
		$kiwi -> info ("Creating boot configuration...");
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$this->{imageDest}/$configName")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create image boot configuration");
			$kiwi -> failed ();
			return;
		}
		my $namecd = $main::global
			-> generateBuildImageName($this->{xml}, ';');
		my $namerw = $main::global
			-> generateBuildImageName($this->{xml},';', '-read-write');
		my $server = $xml -> getPXEDeployServer_legacy ();
		my $blocks = $xml -> getPXEDeployBlockSize_legacy ();
		if (! defined $server) {
			$server = "";
		}
		if (! defined $blocks) {
			$blocks = "";
		}
		print $FD "DISK=${device}\n";
		my $targetPartition = 2;
		my $targetPartitionNext = 3;
		#==========================================
		# PART information
		#------------------------------------------
		my @parts = $xml -> getPXEDeployPartitions_legacy ();
		if ((scalar @parts) > 0) {
			print $FD "PART=";
			for my $href (@parts) {
				if ($href -> {target}) {
					$targetPartition = $href -> {number};
					$targetPartitionNext = $targetPartition + 1;
				}
				if ($href -> {size} eq "image") {
					my $size = $main::global -> isize (
						"$this->{imageDest}/$name"
					);
					print $FD int (($size/1024/1024)+1);
				} else {
					print $FD $href -> {size};
				}

				my $type = $href -> {type};
				my $mountpoint = $href -> {mountpoint};

				SWITCH: for ($type) {
					/swap/i && do {
						$type = "S";
						last SWITCH;
					};
					/linux/i && do {
						$type = "83";
						last SWITCH;
					};
				}
				print $FD ";$type;$mountpoint,";
			}
			print $FD "\n";
		}
		#==========================================
		# IMAGE information
		#------------------------------------------
		if (($type{compressed}) && ($type{compressed} eq 'true')) {
			print $FD "IMAGE='${device}${targetPartition};";
			print $FD "$namecd;$server;$blocks;compressed'";
			if ("$type{type}" eq "split" && defined $this->{imageTreeRW}) {
				print $FD ",${device}${targetPartitionNext}";
				print $FD ";$namerw;$server;$blocks;compressed\n";
			} else {
				print $FD "\n";
			}
		} else {
			print $FD "IMAGE='${device}${targetPartition};";
			print $FD "$namecd;$server;$blocks'";
			if ("$type{type}" eq "split" && defined $this->{imageTreeRW}) {
				print $FD ",${device}${targetPartitionNext}";
				print $FD ";$namerw;$server;$blocks\n";
			} else {
				print $FD "\n";
			}
		}
		#==========================================
		# CONF information
		#------------------------------------------
		my %confs = $xml -> getPXEDeployConfiguration_legacy ();
		if ((scalar keys %confs) > 0) {
			print $FD "CONF=";
			foreach my $source (keys %confs) {
				print $FD "$source;$confs{$source};$server;$blocks,";
			}
			print $FD "\n";
		}
		#==========================================
		# COMBINED_IMAGE information
		#------------------------------------------
		if ("$type{type}" eq "split") {
			print $FD "COMBINED_IMAGE=yes\n";
		}
		#==========================================
		# UNIONFS_CONFIG information
		#------------------------------------------
		my %unionConfig = $xml -> getPXEDeployUnionConfig_legacy ();
		if (%unionConfig) {
			my $valid = 0;
			my $value;
			if (! $unionConfig{type}) {
				$unionConfig{type} = "clicfs";
			}
			if (($unionConfig{rw}) && ($unionConfig{ro})) {
				$value = "$unionConfig{rw},$unionConfig{ro},$unionConfig{type}";
				$valid = 1;
			}
			if ($valid) {
				print $FD "UNIONFS_CONFIG='".$value."'\n";
			}
		}
		#==========================================
		# KIWI_BOOT_TIMEOUT information
		#------------------------------------------
		my $timeout = $xml -> getPXEDeployTimeout_legacy ();
		if (defined $timeout) {
			print $FD "KIWI_BOOT_TIMEOUT=$timeout\n";
		}
		#==========================================
		# KIWI_KERNEL_OPTIONS information
		#------------------------------------------
		my $cmdline = $type{cmdline};
		if (defined $cmdline) {
			print $FD "KIWI_KERNEL_OPTIONS='$cmdline'\n";
		}
		#==========================================
		# KIWI_KERNEL information
		#------------------------------------------
		my $kernel = $xml -> getPXEDeployKernel_legacy ();
		if (defined $kernel) {
			print $FD "KIWI_KERNEL=$kernel\n";
		}
		#==========================================
		# KIWI_INITRD information
		#------------------------------------------
		my $initrd = $xml -> getPXEDeployInitrd_legacy ();
		if (defined $initrd) {
			print $FD "KIWI_INITRD=$initrd\n";
		}
		#==========================================
		# More to come...
		#------------------------------------------
		$FD -> close();
		$kiwi -> done ();
	}
	return $configName;
}

#==========================================
# postImage
#------------------------------------------
sub postImage {
	# ...
	# post-stage preparation of a logical extend.
	# This method includes all common not filesystem
	# dependant tasks after the logical extend has
	# been created
	# ---
	my $this   = shift;
	my $name   = shift;
	my $nozip  = shift;
	my $fstype = shift;
	my $device = shift;
	my $kiwi     = $this->{kiwi};
	my $xml      = $this->{xml};
	my $initCache= $this->{initCache};
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	my $extend = $this -> mountLogicalExtend ($name,undef,$device);
	if (! defined $extend) {
		return;
	}
	#==========================================
	# Setup filesystem specific environment
	#------------------------------------------
	if (! defined $initCache) {
		if (($fstype) && ($fstype eq 'btrfs')) {
			$extend = $main::global -> setupBTRFSSubVolumes ($extend);
			if (! $extend) {
				$this -> cleanLuks();
				return;
			}
		}
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	if (! $this -> installLogicalExtend ($extend,undef,$device)) {
		$this -> cleanLuks();
		return;
	}
	$this -> cleanMount();
	#==========================================
	# Check image file system
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes_legacy()};
	if ((! $type{filesystem}) && ($fstype)) {
		$type{filesystem} = $fstype;
	}
	if (! $type{filesystem}) {
		$type{filesystem} = $type{type};
	}
	my $para = $type{type}.":".$type{filesystem};
	if ($type{filesystem}) {
		$kiwi -> info ("Checking file system: $type{filesystem}...");
	} else {
		$kiwi -> info ("Checking file system: $type{type}...");
	}
	SWITCH: for ($para) {
		#==========================================
		# Check EXT3 file system
		#------------------------------------------
		/ext3|ec2|clicfs/i && do {
			qxx ("/sbin/fsck.ext3 -f -y $this->{imageDest}/$name 2>&1");
			qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT4 file system
		#------------------------------------------
		/ext4/i     && do {
			qxx ("/sbin/fsck.ext4 -f -y $this->{imageDest}/$name 2>&1");
			qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT2 file system
		#------------------------------------------
		/ext2/i     && do {
			qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check ReiserFS file system
		#------------------------------------------
		/reiserfs/i && do {
			qxx ("/sbin/reiserfsck -y $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check BTRFS file system
		#------------------------------------------
		/btrfs/     && do {
			qxx ("/sbin/btrfsck $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check XFS file system
		#------------------------------------------
		/xfs/       && do {
			qxx ("/sbin/fsck.xfs $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Unknown filesystem type
		#------------------------------------------
		$kiwi -> failed();
		$kiwi -> error ("Unsupported filesystem type: $type{filesystem}");
		$kiwi -> failed();
		$this -> cleanLuks();
		return;
	}
	$this -> restoreImageDest();
	$this -> cleanLuks ();
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if ($para ne "clicfs") {
		if (! $this -> buildMD5Sum ($name)) {
			return;
		}
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if (! defined $nozip) {
		if (($type{compressed}) && ($type{compressed} eq 'true')) {
			my $rootfs;
			if ($type{filesystem}) {
				$rootfs = $type{filesystem};
			} else {
				$rootfs = $type{type};
			}
			if (! $this -> compressImage ($name,$rootfs)) {
				return;
			}
		}
	}
	#==========================================
	# Create image boot configuration
	#------------------------------------------
	if (! $this -> writeImageConfig ($name)) {
		return;
	}
	return $name;
}

#==========================================
# buildLogicalExtend
#------------------------------------------
sub buildLogicalExtend {
	my $this   = shift;
	my $name   = shift;
	my $size   = shift;
	my $device = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $encode = 0;
	my $cipher = 0;
	my $out    = $this->{imageDest}."/".$name;
	my %type   = %{$xml->getImageTypeAndAttributes_legacy()};
	#==========================================
	# a size is required
	#------------------------------------------
	if (! defined $size) {
		return;
	}
	#==========================================
	# Check if luks encoding is requested
	#------------------------------------------
	if ($type{luks}) {
		$encode = 1;
		$cipher = "$type{luks}";
		$main::global -> setGlobals ("LuksCipher",$cipher);
	}
	#==========================================
	# Calculate block size and number of blocks
	#------------------------------------------
	if (! defined $device) {
		my @bsc  = $this -> getBlocks ( $size );
		my $seek = $bsc[2];
		#==========================================
		# Create logical extend storage and FS
		#------------------------------------------
		if ($this->{gdata}->{StudioNode}) {
			#==========================================
			# Call custom image creation tool...
			#------------------------------------------
			my $data = qxx ("$this->{gdata}->{StudioNode} $seek 2>&1");
			my $code = $? >> 8;
			chomp $data;
			if (($code != 0) || (! -b $data)) {
				$kiwi -> error  (
					"Failed creating Studio storage device: $data"
				);
				$kiwi -> failed ();
				return;
			}
			$device = $data;
			$this->{targetDevice} = $device;
		} else {
			#==========================================
			# loop setup a disk device as file...
			#------------------------------------------
			unlink ($out);
			my $data = qxx ("qemu-img create $out $seek 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> error  ("Couldn't create logical extend");
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return;
			}
		}
	}
	#==========================================
	# Setup encoding
	#------------------------------------------
	if ($encode) {
		$this -> setupEncoding ($name,$out,$cipher,$device);
	}
	return $name;
}

#==========================================
# setupEncoding
#------------------------------------------
sub setupEncoding {
	# ...
	# setup LUKS encoding on the given file and remap
	# the imageDest variable to the new device mapper
	# location
	# ---
	my $this   = shift;
	my $name   = shift;
	my $out    = shift;
	my $cipher = shift;
	my $device = shift;
	my $kiwi   = $this->{kiwi};
	my $data;
	my $code;
	if ((defined $device) && (! -b $device)) {
		return;
	}
	if (! defined $device) {
		$data = qxx ("/sbin/losetup -f --show $out 2>&1"); chomp $data;
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Couldn't loop bind logical extend: $data");
			$kiwi -> failed ();
			return;
		}
	} else {
		$data = $device;
	}
	my $loop = $data;
	my @luksloop;
	if ($this->{luksloop}) {
		@luksloop = @{$this->{luksloop}};
	}
	push @luksloop,$loop;
	$this->{luksloop} = \@luksloop;
	$data = qxx ("echo $cipher | cryptsetup -q luksFormat $loop 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't setup luks format: $loop");
		$kiwi -> failed ();
		$this -> cleanLuks ();
		return;
	}
	$data = qxx ("echo $cipher | cryptsetup luksOpen $loop $name 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't open luks device: $data");
		$kiwi -> failed ();
		$this -> cleanLuks ();
		return;
	}
	my @luksname;
	if ($this->{luksname}) {
		@luksname = @{$this->{luksname}};
	}
	push @luksname,$name;
	$this->{luksname} = \@luksname;
	if (! $this->{imageDestOrig}) {
		$this->{imageDestOrig} = $this->{imageDest};
		$this->{imageDestMap} = "/dev/mapper/";
	}
	$this->{imageDest} = $this->{imageDestMap};
	return $this;
}

#==========================================
# installLogicalExtend
#------------------------------------------
sub installLogicalExtend {
	my $this   = shift;
	my $extend = shift;
	my $source = shift;
	my $device = shift;
	my $kiwi   = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	if (! defined $source) {
		$source = $imageTree;
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	my $name = basename ($source);
	$kiwi -> info ("Copying physical to logical [$name]...");
	my $free = qxx ("df -h $extend 2>&1");
	$kiwi -> loginfo ("getSize: mount: $free\n");
	my $data = qxx ("rsync -aHXA --one-file-system $source/ $extend 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> info   ("rsync based copy failed: $data");
		$kiwi -> failed ();
		$this -> cleanMount();
		return;
	}
	$kiwi -> done();
	#==========================================
	# dump image file from device if requested
	#------------------------------------------
	if (($device) && (! $this->{gdata}->{StudioNode})) {
		$this -> cleanMount();
		$name = $main::global -> generateBuildImageName($this->{xml});
		my $dest = $this->{imageDest}."/".$name;
		$kiwi -> info ("Dumping filesystem image from $device...");
		$data = qxx ("qemu-img convert -f raw -O raw $device $dest 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to load filesystem image");
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return;
		}
		$kiwi -> done();
	}
	return $extend;
}

#==========================================
# setupLogicalExtend
#------------------------------------------
sub setupLogicalExtend {
	my $this  = shift;
	my $quiet = shift;
	my $name  = shift;
	my $kiwi  = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	my $imageStrip= $this->{imageStrip};
	my $initCache = $this->{initCache};
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if ((! defined $initCache) && (-x "$imageTree/image/images.sh")) {
		$kiwi -> info ("Calling image script: images.sh");
		my ($code,$data) = $main::global -> callContained (
			$imageTree,"/image/images.sh"
		);
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			$this -> cleanMount();
			return;
		} else {
			$kiwi -> loginfo ("images.sh: $data");
		}
		$kiwi -> done ();
	}
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	if (! defined $initCache) {
		if (! $this -> extractKernel ($name)) {
			return;
		}
		$this -> extractSplash ($name);
	}
	#==========================================
	# Strip if specified
	#------------------------------------------
	if (defined $imageStrip) {
		$this -> stripImage();
	}
	#==========================================
	# Calculate needed space
	#------------------------------------------
	$this -> cleanKernelFSMount();
	my ($mbytes,$xmlsize) = $this -> getSize ($imageTree);
	if (! defined $quiet) {
		$kiwi -> info ("Image requires ".$mbytes."M, got $xmlsize");
		$kiwi -> done ();
		$kiwi -> info ("Suggested Image size: $mbytes"."M");
		$kiwi -> done ();
	}
	#==========================================
	# Check given XML size
	#------------------------------------------
	if ($xmlsize =~ /^(\d+)([MG])$/i) {
		$xmlsize = $1;
		my $unit = $2;
		if ($unit eq "G") {
			# convert GB to MB...
			$xmlsize *= 1024;
		}
	}
	#==========================================
	# Return XML size or required size
	#------------------------------------------
	if (int $xmlsize > $mbytes) {
		return $xmlsize;
	}
	return $mbytes;
}

#==========================================
# mountLogicalExtend
#------------------------------------------
sub mountLogicalExtend {
	my $this   = shift;
	my $name   = shift;
	my $opts   = shift;
	my $device = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my %type   = %{$xml->getImageTypeAndAttributes_legacy()};
	my $data;
	my $code;
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	my $target = "$this->{imageDest}/$name";
	if (defined $type{fsmountoptions}) {
		$opts .= ','.$type{fsmountoptions};
	}
	if ($device) {
		$target = $device;
	} else {
		$opts .= ",loop";
	}
	mkdir "$this->{imageDest}/mnt-$$";
	#==========================================
	# check for filesystem options
	#------------------------------------------
	my $fstype = qxx (
		"/sbin/blkid -c /dev/null -s TYPE -o value $target"
	);
	chomp $fstype;
	if ($fstype eq "ext4") {
		# /.../
		# ext4 (currently) should be mounted with 'nodelalloc';
		# else we might run out of space unexpectedly...
		# ----
		$opts .= ",nodelalloc";
	}
	if ($opts) {
		$opts =~ s/^,//;
		$data= qxx (
			"mount -o $opts $target $this->{imageDest}/mnt-$$ 2>&1"
		);
	} else {
		$data= qxx (
			"mount $target $this->{imageDest}/mnt-$$ 2>&1"
		);
	}
	$code= $? >> 8;
	if ($code != 0) {
		chomp $data;
		$kiwi -> error  ("Image loop mount failed:");
		$kiwi -> failed ();
		$kiwi -> error  (
			"mnt: $target -> $this->{imageDest}/mnt-$$: $data"
		);
		return;
	}
	return "$this->{imageDest}/mnt-$$";
}

#==========================================
# extractSplash
#------------------------------------------
sub extractSplash {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	my $zipper    = $this->{gdata}->{Gzip};
	my $newspl    = $imageDest."/splash";
	if (! defined $name) {
		return $this;
	}
	#==========================================
	# check if boot image
	#------------------------------------------
	if (! $this->isBootImage ($name)) {
		return $this;
	}
	#==========================================
	# check if plymouth is used and add flag
	#------------------------------------------
	if (-f "$imageTree/plymouth.splash.active") {
		qxx ("touch $imageDest/plymouth.splash.active 2>&1");
		return $this;
	}
	#==========================================
	# move out all splash files
	#------------------------------------------
	$kiwi -> info ("Extracting kernel splash files...");
	mkdir $newspl;
	my $status = qxx ("mv $imageTree/image/loader/*.spl $newspl 2>&1");
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> info ("No splash files found in initrd");
		$kiwi -> skipped ();
		unlink $newspl;
		return $this;
	}
	#==========================================
	# create new splash with all pictures
	#------------------------------------------
	while (my $splash = glob("$newspl/*.spl")) {
		mkdir "$splash.dir";
		qxx ("$zipper -cd $splash > $splash.bob");
		my $count = $this -> extractCPIO ( $splash.".bob" );
		for (my $id=1; $id <= $count; $id++) {
			qxx ("cat $splash.bob.$id |(cd $splash.dir && cpio -i 2>&1)");
		}
		qxx ("cp -a $splash.dir/etc $newspl");
		$result = 1;
		if (-e "$splash.dir/bootsplash") {
			qxx ("cat $splash.dir/bootsplash >> $newspl/bootsplash");
			$result = $? >> 8;
		}
		qxx ("rm -rf $splash.dir");
		qxx ("rm -f  $splash.bob*");
		qxx ("rm -f  $splash");
		if ($result != 0) {
			my $splfile = basename ($splash);
			$kiwi -> skipped ();
			$kiwi -> info ("No bootsplash file found in $splfile cpio");
			$kiwi -> skipped ();
			return $this;
		}
	}
	qxx ("(cd $newspl && \
		find|cpio --quiet -oH newc | $zipper) > $imageDest/$name.spl"
	);
	qxx ("rm -rf $newspl");
	$kiwi -> done();
	return $this;
}

#==========================================
# isBootImage
#------------------------------------------
sub isBootImage {
	my $this = shift;
	my $name = shift;
	my $xml  = $this->{xml};
	if (! defined $name) {
		return $this;
	}
	my %type = %{$xml->getImageTypeAndAttributes_legacy()};
	my $para = $type{type};
	if (defined $type{filesystem}) {
		$para = $para.":".$type{filesystem};
	}
	SWITCH: for ($para) {
		/ext3/i     && do {
			return 0;
		};
		/ext4/i     && do {
			return 0;
		};
		/reiserfs/i && do {
			return 0;
		};
		/iso/i && do {
			return 0;
		};
		/ext2/i && do {
			if ($name !~ /boot/) {
				return 0;
			}
			last SWITCH;
		};
		/squashfs/i && do {
			return 0;
		};
		/clicfs/i && do {
			return 0;
		};
		/btrfs/i  && do {
			return 0;
		};
		/tbz/i    && do {
			return 0;
		};
		/xfs/i    && do {
			return 0;
		};
	}
	return 1;
}

#==========================================
# extractKernel
#------------------------------------------
sub extractKernel {
	my $this = shift;
	my $name = shift;
	my $imageTree = $this->{imageTree};
	#==========================================
	# check for boot image
	#------------------------------------------
	if (! defined $name) {
		return $this;
	}
	if (! $this->isBootImage ($name)) {
		return $name;
	}
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	return $this -> extractLinux (
		$name,$imageTree,$this->{imageDest}
	);
}

#==========================================
# extractLinux
#------------------------------------------
sub extractLinux {
	my $this      = shift;
	my $name      = shift;
	my $imageTree = shift;
	my $dest      = shift;
	my $kiwi      = $this->{kiwi};
	my $xml       = $this->{xml};
	my %xenc      = $xml->getXenConfig_legacy();
	if ((-f "$imageTree/boot/vmlinux.gz")  ||
		(-f "$imageTree/boot/vmlinuz.el5") ||
		(-f "$imageTree/boot/vmlinux")     ||
		(-f "$imageTree/boot/vmlinuz")
	) {
		$kiwi -> info ("Extracting kernel\n");
		#==========================================
		# setup file names / cleanup...
		#------------------------------------------
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $shortfile = "$name.kernel";
		my $file = "$dest/$shortfile";
		if ($file !~ /^\//) {
			$file = $pwd."/".$file;
		}
		if (-e $file) {
			qxx ("rm -f $file");
		}
		# /.../
		# the KIWIConfig::suseStripKernel() function provides the
		# kernel as common name /boot/vmlinuz so we use this file
		# for the extraction
		# ----
		my $src_kernel = "$imageTree/boot/vmlinuz";
		if (! -e $src_kernel) {
			$kiwi -> error  ("Can't find kernel for extraction: $!");
			$kiwi -> failed ();
			return;
		}
		qxx ("cp $src_kernel $file");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Failed to extract kernel: $!");
			$kiwi -> failed ();
			return;
		}
		my $kernel = qxx ("kversion $file"); chomp $kernel;
		if ($kernel eq "") {
			$kernel = "no-version-found";
		}
		qxx ("mv -f $file $file.$kernel && ln -s $shortfile.$kernel $file");
		$this -> buildMD5Sum ("$shortfile.$kernel");
		# /.../
		# check for the Xen hypervisor and extract them as well
		# ----
		if ((defined $xenc{xen_domain}) && ($xenc{xen_domain} eq "dom0")) {
			if (! -f "$imageTree/boot/xen.gz") {
				$kiwi -> error  ("Xen dom0 requested but no hypervisor found");
				$kiwi -> failed ();
				return;
			}
		}
		if (-f "$imageTree/boot/xen.gz") {
			$file = "$dest/$name.kernel-xen";
			qxx ("cp $imageTree/boot/xen.gz $file");
			qxx ("mv $file $file.$kernel.'gz'");
		}
		qxx ("rm -rf $imageTree/boot/*");
	}
	return $name;
}

#==========================================
# setupEXT2
#------------------------------------------
sub setupEXT2 {
	my $this    = shift;
	my $name    = shift;
	my $journal = shift;
	my $device  = shift;
	my $cmdL    = $this->{cmdL};
	my $kiwi    = $this->{kiwi};
	my $xml     = $this->{xml};
	my %type    = %{$xml->getImageTypeAndAttributes_legacy()};
	my $fsopts;
	my $tuneopts;
	my %FSopts = $main::global -> checkFSOptions(
		@{$cmdL->getFilesystemOptions()}
	);
	my $fstool;
	my $target = "$this->{imageDest}/$name";
	if ((defined $journal) && ($journal eq "journaled-ext3")) {
		$fsopts = $FSopts{ext3};
		$fstool = "mkfs.ext3";
	} elsif ((defined $journal) && ($journal eq "journaled-ext4")) {
		$fsopts = $FSopts{ext4};
		$fstool = "mkfs.ext4";
	} else {
		$fsopts = $FSopts{ext2};
		$fstool = "mkfs.ext2";
	}
	if ($this->{inodes}) {
		$fsopts.= " -N $this->{inodes}";
	}
	$tuneopts = "";
	if ($FSopts{extfstune}) {
		$tuneopts = $FSopts{extfstune};
	}
	if (($type{fsnocheck}) && ($type{fsnocheck} eq "true")) {
		$tuneopts .= " -c 0 -i 0";
	}
	if ($device) {
		$target = $device;
	}
	my $data = qxx ("$fstool $fsopts $target 2>&1");
	my $code = $? >> 8;
	if (!$code && $tuneopts) {
		$data = qxx ("/sbin/tune2fs $tuneopts $target 2>&1");
		$code = $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create EXT2 filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	if ($device) {
		qxx ("touch $this->{imageDest}/$name");
	}
	$this -> restoreImageDest();
	if ((defined $journal) && ($journal eq "journaled-ext3")) {
		$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.ext3 2>&1");
	} elsif ((defined $journal) && ($journal eq "journaled-ext4")) {
		$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.ext4 2>&1");
	} else {
		$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.ext2 2>&1");
	}
	$this -> remapImageDest();
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# setupBTRFS
#------------------------------------------
sub setupBTRFS {
	my $this   = shift;
	my $name   = shift;
	my $device = shift;
	my $cmdL   = $this->{cmdL};
	my $kiwi   = $this->{kiwi};
	my %FSopts = $main::global -> checkFSOptions(
		@{$cmdL->getFilesystemOptions()}
	);
	my $fsopts = $FSopts{btrfs};
	my $target = "$this->{imageDest}/$name";
	if ($device) {
		$target = $device;
	}
	my $data = qxx (
		"/sbin/mkfs.btrfs $fsopts $target 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create BTRFS filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	if ($device) {
		qxx ("touch $this->{imageDest}/$name");
	}
	$this -> restoreImageDest();
	$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.btrfs 2>&1");
	$this -> remapImageDest();
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# setupReiser
#------------------------------------------
sub setupReiser {
	my $this   = shift;
	my $name   = shift;
	my $device = shift;
	my $cmdL   = $this->{cmdL};
	my $kiwi   = $this->{kiwi};
	my %FSopts = $main::global -> checkFSOptions(
		@{$cmdL->getFilesystemOptions()}
	);
	my $fsopts = $FSopts{reiserfs};
	my $target = "$this->{imageDest}/$name";
	if ($device) {
		$target = $device;
	}
	$fsopts.= "-f";
	my $data = qxx (
		"/sbin/mkreiserfs $fsopts $target 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create Reiser filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	if ($device) {
		qxx ("touch $this->{imageDest}/$name");
	}
	$this -> restoreImageDest();
	$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.reiserfs 2>&1");
	$this -> remapImageDest();
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# setupSquashFS
#------------------------------------------
sub setupSquashFS {
	my $this = shift;
	my $name = shift;
	my $tree = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my %type = %{$xml->getImageTypeAndAttributes_legacy()};
	my $imageTree = $this->{imageTree};
	my $locator = KIWILocator -> new();
	if (! defined $tree) {
		$tree = $imageTree;
	}
	if ($type{luks}) {
		$this -> restoreImageDest();
	}
	unlink ("$this->{imageDest}/$name");
	my $squashfs_tool = $locator -> getExecPath("mksquashfs");
	my $data = qxx ("$squashfs_tool $tree $this->{imageDest}/$name 2>&1");
	my $code = $? >> 8; 
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create squashfs filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	#==========================================
	# Check for LUKS extension
	#------------------------------------------
	if ($type{luks}) {
		my $outimg = $this->{imageDest}."/".$name;
		my $squashimg = $outimg.".squashfs";
		my $cipher = "$type{luks}";
		my $data = qxx ("mv $outimg $squashimg 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to rename squashfs image");
			$kiwi -> failed ();
			return;
		}
		my $bytes = int ((-s $squashimg) * 1.1);
		$data = qxx (
			"dd if=/dev/zero of=$outimg bs=1 seek=$bytes count=1 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create luks loop container");
			$kiwi -> failed ();
			return;
		}
		if (! $this -> setupEncoding ($name.".squashfs",$outimg,$cipher)) {
			return;
		}
		$data = qxx (
			"dd if=$squashimg of=$this->{imageDest}/$name.squashfs 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to dump squashfs to luks loop: $data");
			$kiwi -> failed ();
			$this -> cleanLuks();
			return;
		}
	}
	$this -> restoreImageDest();
	$data = qxx ("chmod 644 $this->{imageDest}/$name");
	$data = qxx ("rm -f $this->{imageDest}/$name.squashfs");
	$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.squashfs 2>&1");
	$this -> remapImageDest();
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# setupXFS
#------------------------------------------
sub setupXFS {
	my $this   = shift;
	my $name   = shift;
	my $device = shift;
	my $cmdL   = $this->{cmdL};
	my $kiwi   = $this->{kiwi};
	my %FSopts = $main::global -> checkFSOptions(
		@{$cmdL->getFilesystemOptions()}
	);
	my $fsopts = $FSopts{xfs};
	my $target = $this->{imageDest}."/".$name;
	if ($device) {
		$target = $device;
	}
	my $data = qxx (
		"/sbin/mkfs.xfs $fsopts $target 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create XFS filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	if ($device) {
		qxx ("touch $this->{imageDest}/$name");
	}
	$this -> restoreImageDest();
	$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.xfs 2>&1");
	$this -> remapImageDest();
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# buildMD5Sum
#------------------------------------------
sub buildMD5Sum {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $initCache = $this->{initCache};
	my $image = $this->{imageDest}."/".$name;
	if ($this->{targetDevice}) {
		$image = $this->{targetDevice};
	}
	#==========================================
	# Skip this in init cache mode
	#------------------------------------------
	if (defined $initCache) {
		if ($name =~ /\.gz$/) {
			$name =~ s/\.gz//;
		}
		return $name;
	}
	#==========================================
	# Create image md5sum
	#------------------------------------------
	$kiwi -> info ("Creating image MD5 sum...");
	my $size = int $main::global -> isize ($image);
	my $primes = qxx ("factor $size");
	$primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		my $iFact = int $factor;
		if ($blocksize * $iFact > 65464) {
			last;
		}
		$blocksize *= $iFact;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qxx ("cat $image | md5sum - | cut -f 1 -d-");
	chomp $sum;
	if ($name =~ /\.gz$/) {
		$name =~ s/\.gz//;
	}
	qxx ("echo \"$sum $blocks $blocksize\" > $this->{imageDest}/$name.md5");
	$this->{md5file} = $this->{imageDest}."/".$name.".md5";
	$kiwi -> done();
	return $name;
}

#==========================================
# restoreCDRootData
#------------------------------------------
sub restoreCDRootData {
	my $this = shift;
	my $imageTree    = $this->{imageTree};
	my $cdrootData   = "config-cdroot.tgz";
	my $cdrootScript = "config-cdroot.sh";
	if (-f $this->{imageDest}."/".$cdrootData) {
		qxx ("mv $this->{imageDest}/$cdrootData $imageTree/image");
	}
	if (-f $this->{imageDest}."/".$cdrootScript) {
		qxx ("mv $this->{imageDest}/$cdrootScript $imageTree/image");
	}
	return;
}

#==========================================
# restoreSplitExtend
#------------------------------------------
sub restoreSplitExtend {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $imageTreeReadOnly = $this->{imageTreeReadOnly};
	my $imageTree = $this->{imageTree};
	if ((! defined $imageTreeReadOnly) || ( ! -d $imageTreeReadOnly)) {
		return $imageTreeReadOnly;
	}
	$kiwi -> info ("Restoring physical extend...");
	my @rodirs = qw (bin boot lib lib64 opt sbin usr);
	foreach my $dir (@rodirs) {
		if (! -d "$imageTreeReadOnly/$dir") {
			next;
		}
		my $data = qxx ("mv $imageTreeReadOnly/$dir $imageTree 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't restore physical extend: $data");
			$kiwi -> failed ();
			return;
		}
	}
	$kiwi -> done();
	rmdir  $imageTreeReadOnly;
	return $imageTreeReadOnly;
}

#==========================================
# compressImage
#------------------------------------------
sub compressImage {
	my $this   = shift;
	my $name   = shift;
	my $fstype = shift;
	my $kiwi   = $this->{kiwi};
	my $image = $this->{imageDest}."/".$name;
	if ($this->{targetDevice}) {
		$image = $this->{targetDevice};
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	$kiwi -> info ("Compressing image...");
	my $data = qxx (
		"cat $image | $this->{gdata}->{Gzip} > $this->{imageDest}/$name.gz"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Compressing image failed: $!");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done();
	$this -> updateMD5File ("$this->{imageDest}/$name.gz");
	#==========================================
	# Relink filesystem link to comp image file
	#------------------------------------------
	my $fslink = $this->{imageDest}."/".$name.".".$fstype;
	if (-l $fslink) {
		qxx ("rm -f $fslink 2>&1");
		qxx ("ln -vs $this->{imageDest}/$name.gz $fslink 2>&1");
	}
	return $name;
}

#==========================================
# updateMD5File
#------------------------------------------
sub updateMD5File {
	my $this = shift;
	my $image= shift;
	my $kiwi = $this->{kiwi};
	#==========================================
	# Update md5file adding zblocks/zblocksize
	#------------------------------------------
	if (defined $this->{md5file}) {
		$kiwi -> info ("Updating md5 file...");
		my $FD;
		if (! open ($FD, '<', $this->{md5file})) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to open md5 file: $!");
			$kiwi -> failed ();
			return;
		}
		my $line = <$FD>;
		close $FD;
		chomp $line;
		my $size = $main::global -> isize ($image);
		my $primes = qxx ("factor $size"); $primes =~ s/^.*: //;
		my $blocksize = 1;
		for my $factor (split /\s/,$primes) {
			last if ($blocksize * $factor > 65464);
			$blocksize *= $factor;
		}
		my $blocks = $size / $blocksize;
		my $md5file= $this->{md5file};
		qxx ("echo \"$line $blocks $blocksize\" > $md5file");
		$kiwi -> done();
	}
	return $this;
}

#==========================================
# getSize
#------------------------------------------
sub getSize {
	# ...
	# calculate size of the logical extend. The
	# method returns the size value in MegaByte
	# ---
	my $this    = shift;
	my $extend  = shift;
	my $kiwi    = $this->{kiwi};
	my $cmdL    = $this->{cmdL};
	my $xml     = $this->{xml};
	my $mini    = qxx ("find $extend | wc -l"); chomp $mini;
	my $minsize = qxx ("du -s --block-size=1 $extend | cut -f1");
	my $spare   = 100 * 1024 * 1024;
	my $files   = $mini;
	my $fsopts  = $cmdL -> getFilesystemOptions();
	my $isize   = $fsopts->[1];
	my $iratio  = $fsopts->[2];
	my %type    = %{$xml->getImageTypeAndAttributes_legacy()};
	my $fstype  = $type{type};
	my $xmlsize;
	if ($type{filesystem}) {
		$fstype .= ":$type{filesystem}";
	}
	$minsize = sprintf ("%.0f",$minsize);
	#==========================================
	# Double minimum inode count
	#------------------------------------------
	$mini *= 2;
	#==========================================
	# Minimum size calculated in Byte
	#------------------------------------------
	$kiwi -> loginfo ("getSize: files: $files\n");
	$kiwi -> loginfo ("getSize: usage: $minsize Bytes\n");
	if ($fstype =~ /btrfs/) {
		my $fsohead= 2.0;
		$kiwi -> loginfo ("getSize: multiply by $fsohead\n");
		$minsize *= $fsohead;
	} else {
		my $fsohead= 1.4;
		$kiwi -> loginfo ("getSize: inode: $isize Bytes\n");
		$minsize *= $fsohead;
		$minsize += $mini * $isize;
		$minsize = sprintf ("%.0f",$minsize);
	}
	$minsize+= $spare;
	$xmlsize = $minsize;
	$kiwi -> loginfo ("getSize: minsz: $minsize Bytes\n");
	#==========================================
	# XML size calculated in Byte
	#------------------------------------------
	my $additive = $xml -> getImageSizeAdditiveBytes_legacy();
	if ($additive) {
		# relative size value specified...
		$xmlsize = $minsize + $additive;
	} else {
		# absolute size value specified...
		$xmlsize = $xml -> getImageSize_legacy();
		if ($xmlsize eq "auto") {
			$xmlsize = $minsize;
		} elsif ($xmlsize =~ /^(\d+)([MG])$/i) {
			my $value= $1;
			my $unit = $2;
			if ($unit eq "G") {
				# convert GB to MB...
				$value *= 1024;
			}
			# convert MB to Byte
			$xmlsize = $value * 1048576;
			# check the size value with what kiwi thinks is the minimum
			if ($xmlsize < $minsize) {
				my $s1 = sprintf ("%.0f", $minsize / 1048576);
				my $s2 = sprintf ("%.0f", $xmlsize / 1048576);
				$kiwi -> warning (
					"--> given xml size might be too small, using it anyhow!\n"
				);
				$kiwi -> warning (
					"--> min size changed from $s1 to $s2 MB\n"
				);
				$minsize = $xmlsize;
			}
		}
	}
	#==========================================
	# Setup used size and inodes, prefer XML
	#------------------------------------------
	my $usedsize = $minsize;
	if ($xmlsize > $minsize) {
		$usedsize = $xmlsize;
		$this->{inodes} = sprintf ("%.0f",$usedsize / $iratio);
	} else {
		$this->{inodes} = $mini;
	}
	#==========================================
	# return result list in MB
	#------------------------------------------
	$minsize = sprintf ("%.0f",$minsize  / 1048576);
	$usedsize= sprintf ("%.0f",$usedsize / 1048576);
	$usedsize.= "M";
	return ($minsize,$usedsize);
}

#==========================================
# checkKernel
#------------------------------------------
sub checkKernel {
	# ...
	# this function receives two parameters. The initrd image
	# file and the system image tree directory path. It checks
	# whether at least one kernel matches both, the initrd and
	# the system image. If not the function tries to copy the
	# kernel from the system image into the initrd. If the
	# system image specifies more than one kernel an error
	# is printed pointing out that the boot image needs to
	# specify one of the found system image kernels
	# ---
	my $this    = shift;
	my $initrd  = shift;
	my $systree = shift;
	my $name    = shift;
	my $kiwi    = $this->{kiwi};
	my $arch    = $this->{arch};
	my $zipper  = $this->{gdata}->{Gzip};
	my %sysk    = ();
	my %bootk   = ();
	my $status;
	my $tmpdir;
	#==========================================
	# find system image kernel(s)
	#------------------------------------------
	foreach my $dir (glob ("$systree/lib/modules/*")) {
		if ($dir =~ /-debug$/) {
			next;
		}
		$dir =~ s/$systree\///;
		$sysk{$dir} = "system-kernel";
	}
	if (! %sysk) {
		$kiwi -> error  ("Can't find any system image kernel");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# find boot image kernel
	#------------------------------------------
	my $cmd = "cat $initrd";
	my $zip = 0;
	if ($initrd =~ /\.gz$/) {
		$cmd = "$zipper -cd $initrd";
		$zip = 1;
	}
	my @status = qxx ("$cmd|cpio -it --quiet 'lib/modules/*'|cut -f1-3 -d/");
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Can't find any boot image kernel");
		$kiwi -> failed ();
		return;
	}
	foreach my $module (@status) {
		chomp $module;
		$bootk{$module} = "boot-kernel";
	}
	if (! %bootk) {
		$kiwi -> error  ("Can't find any boot image kernel");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# search system image kernel in initrd 
	#------------------------------------------
	foreach my $system (keys %sysk) {
		if ($bootk{$system}) {
			# found system image kernel in initrd, ok
			return $this;
		}
	}
	#==========================================
	# check system image kernel count
	#------------------------------------------
	if (keys %sysk > 1) {
		$kiwi -> error  ("*** kernel check failed ***");
		$kiwi -> failed ();
		$kiwi -> note ("Can't find a system kernel matching the initrd\n");
		$kiwi -> note ("multiple system kernels were found, make sure your\n");
		$kiwi -> note ("boot image includes the intended kernel\n");
		return;
	}
	#==========================================
	# fix kernel inconsistency:
	#------------------------------------------
	$kiwi -> info ("Fixing kernel inconsistency...");
	$tmpdir = qxx ("mktemp -qdt kiwi-fixboot.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return;
	}
	push @{$this->{tmpdirs}},$tmpdir;
	#==========================================
	# 1) unpack initrd...
	#------------------------------------------
	$status = qxx ("cd $tmpdir && $cmd|cpio -di --quiet");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't unpack initrd: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $tmpdir");
		return;
	}
	#==========================================
	# 2) create images.sh script...
	#------------------------------------------
	my $FD = FileHandle -> new();
	if (! $FD -> open (">$tmpdir/images.sh")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create image.sh file: $!");
		$kiwi -> failed ();
		qxx ("rm -rf $tmpdir");
		return;
	}
	print $FD '#!/bin/sh'."\n";
	print $FD 'test -f /.kconfig && . /.kconfig'."\n";
	print $FD 'test -f /.profile && . /.profile'."\n";
	print $FD 'echo "*** Fixing kernel inconsistency ***"'."\n";
	print $FD 'suseStripKernel'."\n";
	print $FD 'exit 0'."\n";
	$FD -> close();
	#==========================================
	# 3) copy system kernel to initrd...
	#------------------------------------------
	qxx ("rm -rf $tmpdir/boot");
	qxx ("cp -a  $systree/boot $tmpdir");
	qxx ("rm -rf $tmpdir/lib/modules");
	qxx ("cp -a  $systree/lib/modules $tmpdir/lib");
	qxx (
		"cp $this->{gdata}->{BasePath}/modules/KIWIConfig.sh $tmpdir/.kconfig"
	);
	qxx ("chmod u+x $tmpdir/images.sh");
	#==========================================
	# 4) call images.sh script...
	#------------------------------------------
	($result,$status) = $main::global -> callContained (
		$tmpdir,"/images.sh"
	);
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> info   ($status);
		qxx ("rm -rf $tmpdir");
		return;
	} else {
		$kiwi -> loginfo ("images.sh: $status");
	}
	$kiwi -> done();
	#==========================================
	# 5) extract kernel files...
	#------------------------------------------
	my $dest = dirname $initrd;
	qxx ("rm -f $dest/$name*");
	if (! $this -> extractLinux ($name,$tmpdir,$dest)) {
		qxx ("rm -rf $tmpdir");
		return;
	}
	#==========================================
	# 6) rebundle initrd...
	#------------------------------------------
	my @cpio = ("--create", "--format=newc", "--quiet");
	$status = qxx ( "cd $tmpdir && find . | cpio @cpio > $dest/$name");
	if ($zip) {
		$status = qxx (
			"cd $tmpdir && cat $dest/$name | $zipper -f > $initrd"
		);
	}
	#==========================================
	# 7) recreate md5 file...
	#------------------------------------------
	my $origDest = $this->{imageDest};
	$this->{imageDest} = $dest;
	if (! $this -> buildMD5Sum ($name)) {
		$this->{imageDest} = $origDest;
		qxx ("rm -rf $tmpdir");
		return;
	}
	$this->{imageDest} = $origDest;
	qxx ("rm -rf $tmpdir");
	return $this;
}

#==========================================
# cleanLuks
#------------------------------------------
sub cleanLuks {
	my $this = shift;
	my $loop = $this->{luksloop};
	my $name = $this->{luksname};
	if ($name) {
		foreach my $luks (@{$name}) {
			qxx ("cryptsetup luksClose $luks 2>&1");
		}
	}
	if ($loop) {
		foreach my $ldev (@{$loop}) {
			qxx ("losetup -d $ldev 2>&1");
		}
	}
	return;
}

#==========================================
# restoreImageDest
#------------------------------------------
sub restoreImageDest {
	my $this = shift;
	if ($this->{imageDestOrig}) {
		$this->{imageDest} = $this->{imageDestOrig};
	}
	return;
}

#==========================================
# remapImageDest
#------------------------------------------
sub remapImageDest {
	my $this = shift;
	if ($this->{imageDestMap}) {
		$this->{imageDest} = $this->{imageDestMap};
	}
	return;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	my $this = shift;
	qxx ("umount $this->{imageDest}/mnt-$$ 2>&1");
	rmdir "$this->{imageDest}/mnt-$$";
	return;
}

#==========================================
# cleanKernelFSMount
#------------------------------------------
sub cleanKernelFSMount {
	my $this = shift;
	my @kfs  = ("/proc/sys/fs/binfmt_misc","/proc","/dev/pts","/sys");
	foreach my $system (@kfs) {
		qxx ("umount $this->{imageTree}/$system 2>&1");
	}
	return;
}

#==========================================
# extractCPIO
#------------------------------------------
sub extractCPIO {
	my $this = shift;
	my $file = shift;
	my $FD = FileHandle -> new();
	if (! $FD -> open ($file)) {
		return 0;
	}
	local $/;
	my $data = <$FD>;
	$FD -> close();
	my @data   = split (//,$data);
	my $stream = "";
	my $count  = 0;
	my $start  = 0;
	my $pos1   = -1;
	my $pos2   = -1;
	my @index;
	while (1) {
		my $pos1 = index ($data,"TRAILER!!!",$start);
		if ($pos1 >= $start) {
			$pos2 = index ($data,"07070",$pos1);
		} else {
			last;
		}
		if ($pos2 >= $pos1) {
			$pos2--;
			push (@index,$pos2);
			#print "$start -> $pos2\n";
			$start = $pos2;
		} else {
			$pos2 = @data; $pos2--;
			push (@index,$pos2);
			#print "$start -> $pos2\n";
			last;
		}
	}
	for (my $i=0;$i<@data;$i++) {
		$stream .= $data[$i];
		if ($i == $index[$count]) {
			$count++;
			my $FD = FileHandle -> new();
			if (! $FD -> open (">$file.$count")) {
				return 0;
			}
			print $FD $stream;
			$FD -> close();
			$stream = "";
		}
	}
	return $count;
}

#==========================================
# makeLabel
#------------------------------------------
sub makeLabel {
	# ...
	# isolinux handles spaces as "_", so we replace
	# each space with an underscore
	# ----
	my $this = shift;
	my $label = shift;
	$label =~ s/ /_/g;
	return $label;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this = shift;
	my $dirs = $this->{tmpdirs};
	my $imageDest = $this->{imageDest};
	my $spldir    = $imageDest."/splash";
	foreach my $dir (@{$dirs}) {
		qxx ("rm -rf $dir 2>&1");
	}
	if (-d $spldir) {
		qxx ("rm -rf $spldir 2>&1");
	}
	$this -> cleanMount();
	$this -> cleanLuks();
	return $this;
}

1;

# vim: set noexpandtab:
