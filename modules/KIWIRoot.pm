#================
# FILE          : KIWIRoot.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to initialize and install
#               : the chroot system of the image
#               : 
#               :
# STATUS        : Development
#----------------
package KIWIRoot;
#==========================================
# Modules
#------------------------------------------
use strict;
use KIWIURL;
use KIWILog;
use KIWIManager;
use KIWIConfigure;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIRoot object which is used for
	# setting up a physical extend. In principal the root
	# object creates a chroot environment including all
	# packages which makes the image
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
	my $kiwi = shift;
	my $xml  = shift;
	my $imageDesc    = shift;
	my $selfRoot     = shift;
	my $baseSystem   = shift;
	my $useRoot      = shift;
	my $addPacks     = shift;
	my $baseRoot     = shift;
	my $baseRootMode = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $code;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (($imageDesc !~ /\//) && (! -d $imageDesc)) {
		$imageDesc = $main::System."/".$imageDesc;
	}
	if (! defined $baseSystem) {
		$kiwi -> error ("No base system path specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $xml) {
		$kiwi -> error ("No XML tree specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $imageDesc) {
		$kiwi -> error ("No image path specified");
		$kiwi -> failed ();
		return undef;
	}
	my %repository = $xml -> getRepository();
	if (! %repository) {
		$kiwi -> error ("No repository specified in XML tree");
		$kiwi -> failed ();
		return undef; 
	}
	my $count = 1;
	my %sourceChannel = ();
	#==========================================
	# Create sourceChannel hash
	#------------------------------------------
	foreach my $source (keys %repository) {
		my $type = $repository{$source};
		my $urlHandler  = new KIWIURL ($kiwi,$this);
		my $publics_url = $urlHandler -> normalizePath ($source);
		if ($publics_url =~ /^\//) {
			if (! -d $publics_url) {
				$kiwi -> warning ("local URL path not found: $publics_url");
				$kiwi -> skipped ();
				next;
			}
		}
		my $private_url = $publics_url;
		if ($private_url =~ /^\//) {
			$private_url = $baseSystem."/".$private_url;
		}
		my $publics_type = $urlHandler -> getRepoType();
		if (($publics_type ne "unknown") && ($publics_type ne $type)) {
			$kiwi -> warning (
				"$private_url: overwrite repo type $type with: $publics_type"
			);
			$kiwi -> done();
			$type = $publics_type;
		}
		my $channel = "kiwi".$count."-".$$;
		my $srckey  = "baseurl";
		my $srcopt;
		if ($type eq "rpm-dir") {
			$srckey = "path";
			$srcopt = "recursive=True";
		}
		my @private_options = ("type=$type","name=$channel",
			"$srckey=$private_url",$srcopt,"-y"
		);
		my @public_options  = ("type=$type","name=$channel",
			"$srckey=$publics_url",$srcopt,"-y"
		);
		$sourceChannel{private}{$channel} = \@private_options;
		$sourceChannel{public}{$channel}  = \@public_options;
		$count++;
	}
	if ($count == 1) {
		$kiwi -> error  ("No Channels left");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Create root directory
	#------------------------------------------
	my @root = $xml -> createTmpDirectory (
		$useRoot,$selfRoot,$baseRoot,$baseRootMode
	);
	my $overlay = $root[2];
	my $root    = $root[0];
	if ( ! defined $root ) {
		$kiwi -> error ("Couldn't create root directory: $!");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Set root log file
	#------------------------------------------
	if (! defined $main::LogFile) {
		$kiwi -> setRootLog ($root[1]."."."$$".".screenrc.log");
	}
	#==========================================
	# Get configured name of package manager
	#------------------------------------------
	$kiwi -> info ("Setting up package manager: ");
	my $pmgr = $xml -> getPackageManager();
	if (! defined $pmgr) {
		if (defined $overlay) {
			$overlay -> resetOverlay();
		}
		rmdir $root[1];
		return undef;
	}
	$kiwi -> note ($pmgr);
	$kiwi -> done ();
	#==========================================
	# Create package manager object
	#------------------------------------------
	my $manager = new KIWIManager (
		$kiwi,$xml,\%sourceChannel,$root,$pmgr
	);
	if (! defined $manager) {
		if (defined $overlay) {
			$overlay -> resetOverlay();
		}
		rmdir $root[1];
		return undef;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}          = $kiwi;
	$this->{sourceChannel} = \%sourceChannel;
	$this->{xml}           = $xml;
	$this->{imageDesc}     = $imageDesc;
	$this->{selfRoot}      = $selfRoot;
	$this->{baseSystem}    = $baseSystem;
	$this->{useRoot}       = $useRoot;
	$this->{root}          = $root;
	$this->{manager}       = $manager;
	$this->{addPacks}      = $addPacks;
	$this->{baseRoot}      = $baseRoot;
	$this->{overlay}       = $overlay;
	return $this;
}

#==========================================
# getRootPath
#------------------------------------------
sub getRootPath {
	# ...
	# Return chroot path for this image
	# ---
	my $this = shift;
	return $this->{root};
}

#==========================================
# init
#------------------------------------------
sub init {
	# ...
	# Initialize root system. The method will create a secured
	# tmp directory and extract all the given base files.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $root = $this->{root};
	my $manager    = $this->{manager};
	my $baseSystem = $this->{baseSystem};
	#==========================================
	# Get base Package list
	#------------------------------------------
	my @initPacs = $xml -> getBaseList();
	if (! @initPacs) {
		$kiwi -> error ("Couldn't create base package list");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Setup preperation checks
	#------------------------------------------
	$manager -> switchToLocal();
	if (! $manager -> setupSignatureCheck()) {
		return undef;
	}
	#==================================
	# Copy/touch some defaults files
	#----------------------------------
	$kiwi -> info ("Creating default template files for new root system");
	qxx (" mkdir -p $root/etc/sysconfig ");
	qxx (" mkdir -p $root/var/log/YaST2 ");
	# need mtab at least empty for mount calls
	qxx (" touch $root/etc/mtab ");
	qxx (" touch $root/etc/sysconfig/bootloader ");
	# need user/group files as template
	my $groupTemplate = "/etc/group"; 
	my $paswdTemplate = "/etc/passwd";
	# search for template files, add paths for different distros here
	my @searchPWD = (
		"/var/adm/fillup-templates/passwd.aaa_base"
	);
	my @searchGRP = (
		"/var/adm/fillup-templates/group.aaa_base"
	);
	foreach my $group (@searchGRP) {
		if ( -f $group ) {
			$groupTemplate = $group; last;
		}
	}
	foreach my $paswd (@searchPWD) {
		if ( -f $paswd ) {
			$paswdTemplate = $paswd; last;
		}
	}
	qxx (" cp $groupTemplate $root/etc/group  2>&1 ");
	qxx (" cp $paswdTemplate $root/etc/passwd 2>&1 ");
	# need resolv.conf for internal chroot name resolution
	qxx (" cp /etc/resolv.conf $root/etc 2>&1 ");
	qxx (" cp $main::KConfig $root/.kconfig 2>&1 ");
	$kiwi -> done();

	#==========================================
	# Add source, install and clean source
	#------------------------------------------
	if (! $manager -> setupInstallationSource()) {
		return undef;
	}
	if (! $manager -> setupRootSystem(@initPacs)) {
		$manager -> resetInstallationSource();
		return undef;
	}
	#==========================================
	# reset installation source
	#------------------------------------------
	if (! $manager -> resetInstallationSource()) {
		return undef;
	}
	#==========================================
	# Reset preperation checks
	#------------------------------------------
	if (! $manager -> resetSignatureCheck()) {
		return undef;
	}
	#==================================
	# Create default fstab file
	#----------------------------------
	if ( ! open (FD,">$root/etc/fstab")) {
		$kiwi -> error ("Failed to create fstab file: $!");
		$kiwi -> failed ();
		return undef;
	}
	print FD "devpts /dev/pts devpts mode=0620,gid=5 0 0\n";
	print FD "proc   /proc    proc   defaults        0 0\n";
	close FD;

	#==================================
	# Create /etc/ImageVersion file
	#----------------------------------
	my $imageVersionFile = "$root/etc/ImageVersion";
	my $imageVersion = $xml -> getImageVersion();
	my $imageName    = $xml -> getImageName();
	if ( ! open (FD,">$imageVersionFile")) {
		$kiwi -> error ("Failed to create version file: $!");
		$kiwi -> failed ();
		return undef;
	}
	print FD $imageName."-".$imageVersion; close FD;
	#==================================
	# Return object reference
	#----------------------------------
	return $this;
}

#==========================================
# upgrade
#------------------------------------------
sub upgrade {
	# ...
	# Upgrade a previosly prepared image root tree
	# with respect to changes of the installation source(s)
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $manager  = $this->{manager};
	my $addPacks = $this->{addPacks};
	#==========================================
	# Mount local and NFS directories
	#------------------------------------------
	if (! $this -> setupMount ()) {
		$kiwi -> error ("Couldn't mount base system");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Upgrade system
	#------------------------------------------
	if (! $manager -> setupUpgrade ($addPacks)) {
		return undef;
	}
	return $this;
}

#==========================================
# install
#------------------------------------------
sub install {
	# ...
	# Install the given package set into the root
	# directory of the image system
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $manager = $this->{manager};
	my %type;
	#==========================================
	# Get image package list
	#------------------------------------------
	my @packList = $xml -> getInstallList();
	if (! @packList) {
		$kiwi -> error ("Couldn't create image package list");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Get Xen package if type is appropriate
	#------------------------------------------
	%type = %{$xml -> getImageTypeAndAttributes()};
	if ("$type{type}" eq "xen") {
		$kiwi -> info ("Creating Xen package list");
		my @xenList = $xml -> getXenList();
		if (! @xenList) {
			$kiwi -> error ("Couldn't create xen package list");
			$kiwi -> failed ();
			return undef;
		}
		@packList = (@packList,@xenList);
		$kiwi -> done ();
	}
	#==========================================
	# Get VMware package if type is appropriate
	#------------------------------------------
	if (("$type{type}" eq "vmx") && ("$type{boot}" =~ /vmxboot/)) {
		$kiwi -> info ("Creating VMware package list");
		my @vmwareList = $xml -> getVMwareList();
		if (@vmwareList) {
			@packList = (@packList,@vmwareList);
		}
		$kiwi -> done ();
	}
	#==========================================
	# Mount local and NFS directories
	#------------------------------------------
	if (! setupMount ($this)) {
		$kiwi -> error ("Couldn't mount base system");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Setup signature check
	#------------------------------------------
	$manager -> switchToChroot();
	if (! $manager -> setupSignatureCheck()) {
		return undef;
	}
	#==========================================
	# Add source(s) and install
	#------------------------------------------
	if (! $manager -> setupInstallationSource()) {
		return undef;
	}
	if (! $manager -> setupRootSystem (@packList)) {
		return undef;
	}
	return $this;
}

#==========================================
# setup
#------------------------------------------
sub setup {
	# ...
	# Setup the installed system. This method will:
	# 1) copy the user defined files to the root tree and
	#    creates the .profile environment file.
	# 2) calls the config.sh and package scripts within the
	#    chroot of the physical extend.
	# 3) copy the complete image description tree to
	#    /image which contains information to create a logical
	#    extend from the chroot.
	# 4) configure the system with methods from KIWIConfigure
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $xml  = $this->{xml};
	my $imageDesc = $this->{imageDesc};
	my $manager   = $this->{manager};
	#======================================== 
	# Consistency check
	#----------------------------------------
	if (! -d "$root/tmp") {
		$kiwi -> error ("Image system seems to be broken");
		$kiwi -> failed ();
		return undef;
	}
	#========================================
	# copy user defined files to image tree
	#----------------------------------------
	if (-d "$imageDesc/root") {
		$kiwi -> info ("Copying user defined files to image tree");
		mkdir $root."/tmproot";
		my $copy = "cp -LR --remove-destination";
		my $data = qxx ("$copy $imageDesc/root/* $root/tmproot 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		}
		qxx ("find $root/tmproot -type d | grep '.svn\$' | xargs rm -rf 2>&1");
		$data = qxx ("$copy $root/tmproot/* $root");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		}
		qxx ("rm -rf $root/tmproot");
		$kiwi -> done();
	}
	#========================================
	# create .profile from <image> tags
	#----------------------------------------
	$kiwi -> info ("Create .profile for package scripts");
	if (! open (FD,">$root/.profile")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create .profile: $!");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
	my %config = $xml -> getImageConfig();
	foreach my $key (keys %config) {
		print FD "$key=\"$config{$key}\"\n";
	}
	close FD;
	#========================================
	# check for linuxrc
	#----------------------------------------
	if (-f "$root/linuxrc") {
		$kiwi -> info ("Setting up linuxrc...");
		my $data = qxx (" cp $root/linuxrc $root/init 2>&1 ");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		}
		$kiwi -> done ();
	}
	#========================================
	# call setup scripts
	#----------------------------------------
	if (-d "$imageDesc/config") {
		$kiwi -> info ("Preparing package setup scripts");
		qxx (" mkdir -p $root/image/config ");
		qxx (" cp $imageDesc/config/* $root/image/config 2>&1 ");
		if (! opendir (FD,"$root/image/config")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't open script directory: $!");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
		my @scriptList = readdir FD;
		foreach my $script (@scriptList) {
			if (-f "$root/image/config/$script") {
				if ($manager -> setupPackageInfo ( $script )) {
					next;
				}
				$kiwi -> info ("Calling package setup script: $script");
				qxx (" chmod u+x $root/image/config/$script");
				my $data = qxx (" chroot $root /image/config/$script 2>&1 ");
				my $code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> info   ($data);
					$kiwi -> failed ();
				} else {
					$kiwi -> loginfo ("$script: $data");
				}
				qxx ("rm -f $root/image/config/$script");
				$kiwi -> done ();
			}
		}
		rmdir ("$root/image/config");
		closedir FD;
	}
	#========================================
	# copy image description to image tree
	#----------------------------------------
	qxx (" mkdir -p $root/image ");
	qxx (" cp $imageDesc/config.xml $root/image 2>&1 ");
	qxx (" cp $imageDesc/images.sh $root/image 2>&1 ");
	qxx (" cp $imageDesc/config-cdroot.tgz $root/image 2>&1 ");
	qxx (" cp $imageDesc/config-cdroot.sh  $root/image 2>&1 ");
	qxx (" cp $root/.profile $root/image 2>&1 ");
	if (open (FD,">$root/image/main::Prepare")) {
		if ($imageDesc !~ /^\//) {
			my $pwd = qxx (" pwd "); chomp $pwd;
			print FD $pwd."/".$imageDesc; close FD;
		} else {
			print FD $imageDesc; close FD;
		}
	}
	#========================================
	# configure the system
	#----------------------------------------
	my $configure = new KIWIConfigure ( $kiwi,$xml,$root,$imageDesc );
	if (! defined $configure) {
		return undef;
	}
	#========================================
	# setup users/groups
	#----------------------------------------
	if (! $configure -> setupUsersGroups()) {
		return undef;
	}
	#========================================
	# check for yast firstboot setup file
	#----------------------------------------
	my $status = $configure -> setupFirstBootYaST();
	if ($status eq "skipped") {
		$status = $configure -> setupAutoYaST();
	}
	if ($status eq "failed") {
		return undef;
	}
	#========================================
	# call config.sh image script
	#----------------------------------------
	if (-x "$imageDesc/config.sh") {
		$kiwi -> info ("Calling image script: config.sh");
		qxx (" cp $imageDesc/config.sh $root/tmp ");
		my $data = qxx (" chroot $root /tmp/config.sh 2>&1 ");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		} else {
			$kiwi -> loginfo ("config.sh: $data");
		}
		qxx (" rm -f $root/tmp/config.sh ");
		$kiwi -> done ();
	}
	#========================================
	# cleanup temporary copy of resolv.conf
	#----------------------------------------
	my $data = qxx ("diff -q /etc/resolv.conf $root/etc/resolv.conf");
	my $code = $? >> 8;
	if ($code == 0) {
		$kiwi -> info ("Cleanup temporary copy of resolv.conf");
		qxx ("rm -f $root/etc/resolv.conf");
		$kiwi -> done ();
	}
	return $this;
}

#==========================================
# addToMountList
#------------------------------------------
sub addToMountList {
	# ...
	# add mount path to mount list
	# ---
	my $this = shift;
	my $path = shift;
	my @mountList;
	if (defined $this->{mountList}) {
		@mountList = @{$this->{mountList}};
	} else {
		@mountList = ();
	}
	push (@mountList,$path);
	$this->{mountList} = \@mountList;
	return $this;
}

#==========================================
# setupMount
#------------------------------------------
sub setupMount {
	# ...
	# mount all reachable local and nfs directories
	# and register them in the mountList
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $root   = $this->{root};
	my $baseSystem = $this->{baseSystem};
	my $prefix     = $root."/".$baseSystem;
	my @mountList;
	if (defined $this->{mountList}) {
		@mountList = @{$this->{mountList}};
	} else {
		@mountList = ();
	}
	$kiwi -> info ("Mounting required file systems");
	if (! -d $prefix) {
	if (! mkdir $prefix) {
		$kiwi -> failed ();
		$kiwi -> error ("Couldn't create directory: $prefix");
		$kiwi -> failed ();
		return undef;
	}
	} else {
		$kiwi -> failed ();
		$kiwi -> error ("Entity $prefix already exist");
		$kiwi -> failed ();
		return undef;
	}
	if (! -f "$root/proc/mounts") {
		qxx ("mkdir -p $root/proc");
		qxx ("mount -t proc none $root/proc");
		push (@mountList,"$root/proc");
	}
	if (! -d "$root/sys/block") {
		qxx ("mkdir -p $root/sys");
		qxx ("mount -t sysfs  none $root/sys");
		qxx ("mkdir -p $root/dev/pts");
		qxx ("mount -t devpts none $root/dev/pts");
		push (@mountList,"$root/sys");
		push (@mountList,"$root/dev/pts");
	}
	$kiwi -> done();
	foreach my $chl (keys %{$this->{sourceChannel}{private}}) {
		my @opts = @{$this->{sourceChannel}{private}{$chl}};
		my $path = $opts[2];
		if ($path =~ /=$baseSystem\/(.*)$/) {
			$path = $1;
		} else {
			next;
		}
		$kiwi -> info ("Mounting local channel: $chl");
		my $cache = "/var/cache/kiwi";
		my $roopt = "dirs=$cache=rw:$path=ro,ro";
		my $auopt = "dirs=$path=ro";
		my $mount = $prefix.$path;
		push (@mountList,$mount);
		if (! -d $cache) {
			qxx (" mkdir -p $cache ");
		}
		qxx ("mkdir -p $mount");
		my $data = qxx (" touch $path/bob 2>&1 ");
		my $code = $? >> 8;
		if ($code == 0) {
			#==========================================
			# $path is writable try overlay ro mount
			#------------------------------------------
			$kiwi -> skipped ();
			$kiwi -> warning ("Path $path is writable, trying read-only mount");
			qxx (" rm -f $path/bob 2>&1 ");
			$data = qxx ("mount -t aufs -o $auopt aufs $mount 2>&1");
			$code = $? >> 8;
			if ($code != 0) {
				$data = qxx ("mount -t unionfs -o $roopt unionfs $mount 2>&1");
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> skipped ();
				$kiwi -> warning ("Couldn't mount read-only, using bind mount");
			}
		}
		if ($code != 0) {
			my $data = qxx (" mount -o bind $path $mount 2>&1 ");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				$this->{mountList} = \@mountList;
				return undef;
			}
			$kiwi -> done();
		} else {
			$kiwi -> done();
		}
	}
	$this->{mountList} = \@mountList;
	return $this;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	# ...
	# umount all mountList registered devices
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $xml  = $this->{xml};
	my $overlay = $this->{overlay};
	if (! defined $this->{mountList}) {
		return $this;
	}
	my @mountList  = @{$this->{mountList}};
	my $baseSystem = $this->{baseSystem};
	my $prefix = $root."/".$baseSystem;
	foreach my $item (reverse @mountList) {
		$kiwi -> info ("Umounting path: $item\n");
		if ($item =~ /^\/tmp\/kiwimount/) {
			qxx ("umount $item 2>/dev/null");
		} else {
			qxx ("umount -l $item 2>/dev/null");
		}
		if ($item =~ /^$prefix/) {
			qxx (" rmdir -p $item 2>&1 ");
		}
		if ($item =~ /^\/tmp\/kiwimount/) {
			qxx (" rmdir -p $item 2>&1 ");
		}
	}
	if (defined $this->{baseRoot}) {
		$overlay -> resetOverlay();
	}
	if (-d $prefix) {
		rmdir $prefix;
	}
	undef $this->{mountList};
	return $this;
}

#==========================================
# cleanSource
#------------------------------------------
sub cleanSource {
	# ...
	# remove all source locations created by kiwi
	# ---
	my $this = shift;
	my $manager = $this->{manager};
	$manager -> resetSource();
	return $this;
}

#==========================================
# cleanManager
#------------------------------------------
sub cleanManager {
	# ...
	# remove data dir(s) of the packagemanager created
	# for kiwi in /var/cache/kiwi/<packagemanager>
	# ---
	my $this = shift;
	my $manager = $this->{manager};
	$manager -> removeCacheDir();
	return $this;
}

#==========================================
# cleanLock
#------------------------------------------
sub cleanLock {
	# ...
	# remove stale lock files
	# ---
	my $this = shift;
	my $manager = $this->{manager};
	$manager -> freeLock();
	return $this;
}

1;
