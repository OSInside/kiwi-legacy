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
use Carp qw (cluck);
use File::Glob ':glob';
use File::Find;
use FileHandle;
use KIWIConfigure;
use KIWILocator;
use KIWILog;
use KIWIManager;
use KIWIOverlay;
use KIWIQX;
use KIWIURL;

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
	my $delPacks     = shift;
	my $cacheRoot    = shift;
	my $targetArch   = shift;
	my $cmdL         = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $code;
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	if (($imageDesc !~ /^\//) && (! -d $imageDesc)) {
		$imageDesc = $this->{gdata}->{System}."/".$imageDesc;
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
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return undef;
	}
	my $count = 1;
	my %sourceChannel = ();
	#==========================================
	# Create sourceChannel hash
	#------------------------------------------
	foreach my $source (keys %repository) {
		my $type = $repository{$source}[0];
		my $alias= $repository{$source}[1];
		my $prio = $repository{$source}[2];
		my $user = $repository{$source}[3];
		my $pwd  = $repository{$source}[4];
		my $plic = $repository{$source}[5];
		my $imgincl = $repository{$source}[6];
		my $urlHandler  = new KIWIURL ($kiwi,$cmdL,$this,$user,$pwd);
		my $publics_url = $urlHandler -> normalizePath ($source);
		if ($publics_url =~ /^\//) {
			my ( $publics_url_test ) = bsd_glob ( $publics_url );
			if (! -d $publics_url_test) {
				$kiwi ->warning ("local URL path not found: $publics_url_test");
				$kiwi ->skipped ();
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
		#==========================================
		# build channel name/alias...
		#------------------------------------------
		my $channel = $alias;
		if (! $channel) {
			$channel = $publics_url;
			$channel =~ s/\//_/g;
			$channel =~ s/^_//;
			$channel =~ s/_$//;
		}
		#==========================================
		# build source key...
		#------------------------------------------
		my $srckey  = "baseurl";
		my $srcopt;
		if (($type eq "rpm-dir") || ($type eq "deb-dir")) {
			$srckey = "path";
			$srcopt = "recursive=True";
		}
		$private_url = "'".$private_url."'";
		$publics_url = "'".$publics_url."'";
		my @private_options = ("type=$type","name=$channel",
			"$srckey=$private_url",$srcopt
		);
		my @public_options  = ("type=$type","name=$channel",
			"$srckey=$publics_url",$srcopt
		);
		if (($prio) && ($prio != 0)) {
			push (@private_options,"priority=$prio");
			push (@public_options ,"priority=$prio");
		}
		push (@private_options,"-y");
		push (@public_options ,"-y");
		$sourceChannel{private}{$channel} = \@private_options;
		$sourceChannel{public}{$channel}  = \@public_options;
		$sourceChannel{$channel}{license} = 0;
		$sourceChannel{$channel}{imgincl} = 0;
		if (($plic) && ("$plic" eq "true")) {
			$sourceChannel{$channel}{license} = 1;
		}
		if (($imgincl) && ("$imgincl" eq "true")) {
			$kiwi -> info ("Retain $channel\n");
			$sourceChannel{$channel}{imgincl} = 1;
		}
		$count++;
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
	$this->{addPacks}      = $addPacks;
	$this->{delPacks}      = $delPacks;
	$this->{cacheRoot}     = $cacheRoot;
	$this->{gdata}         = $main::global -> getGlobals();
	#==========================================
	# check channel count
	#------------------------------------------
	if ($count == 1) {
		$kiwi -> error  ("No Channels left");
		$kiwi -> failed ();
		$this -> cleanMount();
		return undef;
	}
	#==========================================
	# Create root directory
	#------------------------------------------
	my $locator = new KIWILocator ($this -> {kiwi});
	my $root = $locator -> createTmpDirectory (
		$useRoot,$selfRoot,$cmdL
	);
	if ( ! defined $root ) {
		$kiwi -> error ("Couldn't create root directory: $!");
		$kiwi -> failed ();
		$this -> cleanMount();
		return undef;
	}
	#==========================================
	# Check for overlay structure
	#------------------------------------------
	$this->{origtree}= $root;
	$this->{overlay} = new KIWIOverlay ($kiwi,$root,$cacheRoot);
	if (! $this->{overlay}) {
		return undef;
	}
	$root = $this->{overlay} -> mountOverlay();
	if (! -d $root) {
		return undef;
	}
	#==========================================
	# Mark new root directory as broken
	#------------------------------------------
	qxx ("touch $root/.broken 2>&1");
	#==========================================
	# Set root log file
	#------------------------------------------
	if (! $cmdL -> getLogFile()) {
		if (-e $this->{origtree}) {
			$kiwi -> setRootLog ($this->{origtree}."."."$$".".screenrc.log");
		} else {
			$kiwi -> setRootLog ($root."."."$$".".screenrc.log");
		}
	}
	#==========================================
	# Get configured name of package manager
	#------------------------------------------
	$kiwi -> info ("Setting up package manager: ");
	my $pmgr = $xml -> getPackageManager();
	if (! defined $pmgr) {
		$kiwi -> failed();
		$this -> cleanMount();
		return undef;
	}
	$kiwi -> note ($pmgr);
	$kiwi -> done ();
	#==========================================
	# Create package manager object
	#------------------------------------------
	my $manager = new KIWIManager (
		$kiwi,$xml,\%sourceChannel,$root,$pmgr,$targetArch
	);
	if (! defined $manager) {
		$this -> cleanMount();
		return undef;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{root}    = $root;
	$this->{manager} = $manager;
	$this->{cmdL}    = $cmdL;
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
# cleanBroken
#------------------------------------------
sub cleanBroken {
	# ...
	# Remove the .broken indicator to allow
	# use of this root path for image creation
	# ---
	my $this = shift;
	my $root = $this->{root};
	unlink $root."/.broken";
	return $this;
}

#==========================================
# copyBroken
#------------------------------------------
sub copyBroken {
	# ...
	# copy the current logfile contents into
	# the .broken file below the root tree which
	# is indicated to be broken for some reason
	# mentioned in the log file
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $log  = $kiwi->getRootLog();	
	if (-f $log) {
		qxx ("cp $log $root/.broken 2>&1");
	}
	return $this;
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
	my $cmdL = $this->{cmdL};
	my $manager    = $this->{manager};
	my $baseSystem = $this->{baseSystem};
	my $FD;
	#==================================
	# Create /etc/ImageVersion file
	#----------------------------------
	my $imageVersionFile = "$root/etc/ImageVersion";
	my $imageVersion = $xml -> getImageVersion();
	my $imageName    = $xml -> getImageName();
	qxx ("mkdir -p $root/etc");
	if ( ! open ($FD, ">$imageVersionFile")) {
		$kiwi -> error ("Failed to create version file: $!");
		$kiwi -> failed ();
		return undef;
	}
	print $FD $imageName."-".$imageVersion;
	close $FD;
	#==================================
	# Copy helper scripts to new root
	#----------------------------------
	qxx ("cp $this->{gdata}->{KConfig} $root/.kconfig 2>&1");
	#==================================
	# Return early if existing root
	#----------------------------------
	if ($cmdL -> getRecycleRootDir()) {
		return $this;
	}
	#==================================
	# Return early if cache is used
	#----------------------------------
	if (($cmdL-> getCacheDir()) && (! $cmdL->getOperationMode("initCache"))) {
		return $this;
	}
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
	# Check and set lock
	#------------------------------------------
	$manager -> checkExclusiveLock();
	$manager -> setLock();
	#==========================================
	# Setup preperation checks
	#------------------------------------------
	$manager -> switchToLocal();
	if (! $manager -> setupSignatureCheck()) {
		$manager -> freeLock();
		return undef;
	}
	if (! $manager -> setupExcludeDocs()) {
		$manager -> freeLock();
		return undef;
	}
	#==================================
	# Copy/touch some defaults files
	#----------------------------------
	$kiwi -> info ("Creating default template files for new root system");
	if (! defined $this->{cacheRoot}) {
		qxx ("mkdir -p $root/dev");
		qxx ("mkdir -m 755 -p $root/dev/pts");
		qxx ("mknod -m 666 $root/dev/null c 1 3");
		qxx ("mknod -m 666 $root/dev/zero c 1 5");
		qxx ("mknod -m 622 $root/dev/full c 1 7");
		qxx ("mknod -m 666 $root/dev/random c 1 8");
		qxx ("mknod -m 644 $root/dev/urandom c 1 9");
		qxx ("mknod -m 666 $root/dev/tty c 5 0");
		qxx ("mknod -m 666 $root/dev/ptmx c 5 2");
		qxx ("ln -s /proc/self/fd $root/dev/fd");
		qxx ("ln -s fd/2 $root/dev/stderr");
		qxx ("ln -s fd/0 $root/dev/stdin");
		qxx ("ln -s fd/1 $root/dev/stdout");
		qxx ("mknod -m 640 $root/dev/loop0 b 7 0");
		qxx ("mknod -m 640 $root/dev/loop1 b 7 1");
		qxx ("mknod -m 640 $root/dev/loop2 b 7 2");
		qxx ("mknod -m 640 $root/dev/loop3 b 7 3");
		qxx ("mkdir -p $root/etc/sysconfig");
		qxx ("mkdir -p $root/var/log/YaST2");
		# for smart we need the dpkg default file
		qxx ("mkdir -p $root/var/lib/dpkg");
		qxx ("touch $root/var/lib/dpkg/status");
		qxx ("mkdir -p $root/var/lib/dpkg/updates");
		qxx ("touch $root/var/lib/dpkg/available");
		# for building in suse autobuild we need the following file
		if (-f '/.buildenv') {
			qxx ("touch $root/.buildenv");
		}
		# need mtab link for mount calls
		qxx ("ln -s /proc/self/mounts $root/etc/mtab");
		# need sysconfig/bootloader to make post scripts happy
		qxx ("touch $root/etc/sysconfig/bootloader");
	}
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
	# need resolv.conf/hosts for internal chroot name resolution
	qxx (" cp /etc/resolv.conf $root/etc 2>&1 ");
	qxx (" cp /etc/hosts $root/etc 2>&1 ");
	$kiwi -> done();
	#==========================================
	# Create package keys
	#------------------------------------------
	if (! defined $this->{cacheRoot}) {
		$manager -> setupPackageKeys();
	}
	#==========================================
	# Setup shared cache directory
	#------------------------------------------
	$this -> setupCacheMount();
	#==========================================
	# Add source, install and clean source
	#------------------------------------------
	if (! $manager -> setupInstallationSource()) {
		$this -> cleanMount();
		$manager -> freeLock();
		return undef;
	}
	if (! $manager -> setupRootSystem(@initPacs)) {
		$manager -> resetInstallationSource();
		$this -> cleanMount();
		$manager -> freeLock();
		return undef;
	}
	#==========================================
	# reset installation source
	#------------------------------------------
	# /.../
	# In order to re-use an already downloaded metadata cache
	# we prevent kiwi from removing the package manager cache.
	# kiwi point the package manger to an alternative cache
	# directory in /var/cache/kiwi/$manager. My hope is that
	# there will be no conflicts if different package manager
	# versions uses the cache. If you find problems activate
	# the following code:
	# ----
	# if (! $manager -> resetInstallationSource()) {
	#	$this -> cleanMount();
	#	$manager -> freeLock();
	#	return undef;
	# }
	#==========================================
	# Reset preperation checks
	#------------------------------------------
	if (! $manager -> resetSignatureCheck()) {
		$this -> cleanMount();
		$manager -> freeLock();
		return undef;
	}
	$this -> cleanMount('(cache\/(kiwi|zypp)$)|(dev$)');
	$manager -> freeLock();
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
	my $root = $this->{root};
	my $manager  = $this->{manager};
	my $addPacks = $this->{addPacks};
	my $delPacks = $this->{delPacks};
	#==========================================
	# Mount local and NFS directories
	#------------------------------------------
	$manager -> switchToChroot();
	if (! $this -> setupMount ()) {
		$kiwi -> error ("Couldn't mount base system");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# make sure name resolution works
	#------------------------------------------
	$this->{needResolvConf} = 0;
	$this->{needHosts} = 0;
	if (! -f "$root/etc/resolv.conf") {
		qxx ("cp /etc/resolv.conf $root/etc 2>&1");
		$this->{needResolvConf} = 1;
	}
	if (! -f "$root/etc/hosts") {
		qxx ("cp /etc/hosts $root/etc 2>&1");
		$this->{needHosts} = 1;
	}
	#==========================================
	# Check and set lock
	#------------------------------------------
	$manager -> checkExclusiveLock();
	$manager -> setLock();
	#==========================================
	# Upgrade system
	#------------------------------------------
	if (! $manager -> setupSignatureCheck()) {
		$manager -> freeLock();
		return undef;
	}
	if (! $manager -> setupInstallationSource()) {
		$this -> cleanupResolvConf();
		$manager -> freeLock();
		return undef;
	}
	if (! $manager -> setupUpgrade ($addPacks,$delPacks)) {
		$this -> cleanupResolvConf();
		$manager -> freeLock();
		return undef;
	}
	# /.../
	# In order to re-use an already downloaded metadata cache
	# we prevent kiwi from removing the package manager cache.
	# kiwi point the package manger to an alternative cache
	# directory in /var/cache/kiwi/$manager. My hope is that
	# there will be no conflicts if different package manager
	# versions uses the cache. If you find problems activate
	# the following code:
	# ----
	# if (! $manager -> resetInstallationSource()) {
	#	$this -> cleanupResolvConf();
	#	$manager -> freeLock();
	#	return undef;
	# }
	$this -> cleanupResolvConf();
	$manager -> freeLock();
	return $this;
}

#==========================================
# prepareTestingEnvironment
#------------------------------------------
sub prepareTestingEnvironment {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $manager  = $this->{manager};
	#==========================================
	# Mount local and NFS directories
	#------------------------------------------
	$manager -> switchToChroot();
	if (! $this -> setupMount ()) {
		$kiwi -> error ("Couldn't mount base system");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# make sure name resolution works
	#------------------------------------------
	$this->{needResolvConf} = 0;
	$this->{needHosts} = 0;
	if (! -f "$root/etc/resolv.conf") {
		qxx ("cp /etc/resolv.conf $root/etc 2>&1");
		$this->{needResolvConf} = 1;
	}
	if (! -f "$root/etc/hosts") {
		qxx ("cp /etc/hosts $root/etc 2>&1");
		$this->{needHosts} = 1;
	}
	#==========================================
	# Check and set lock
	#------------------------------------------
	$manager -> checkExclusiveLock();
	$manager -> setLock();
	#==========================================
	# Setup sources
	#------------------------------------------
	if (! $manager -> setupInstallationSource()) {
		$this -> cleanupResolvConf();
		$manager -> freeLock();
		return undef;
	}
	$this -> cleanupResolvConf();
	return $this;
}

#==========================================
# cleanupTestingEnvironment
#------------------------------------------
sub cleanupTestingEnvironment {
	my $this = shift;
	my $root = $this->{root};
	my $manager = $this->{manager};
	# /.../
	# In order to re-use an already downloaded metadata cache
	# we prevent kiwi from removing the package manager cache.
	# kiwi point the package manger to an alternative cache
	# directory in /var/cache/kiwi/$manager. My hope is that
	# there will be no conflicts if different package manager
	# versions uses the cache. If you find problems activate
	# the following code:
	# ----
	# if (! $manager -> resetInstallationSource()) {
	#	$this -> cleanupResolvConf();
	#	$manager -> freeLock();
	#	return undef;
	# }
	$this -> cleanupResolvConf();
	$manager -> freeLock();
	return $this;
}

#==========================================
# cleanupResolvConf
#------------------------------------------
sub cleanupResolvConf {
	my $this = shift;
	my $root = $this->{root};
	my $needResolvConf = $this->{needResolvConf};
	my $needHosts = $this->{needHosts};
	if ($needResolvConf) {
		qxx ("rm -f $root/etc/resolv.conf");
		undef $this->{needResolvConf};
	}
	if ($needHosts) {
		qxx ("rm -f $root/etc/hosts");
		undef $this->{needHosts};
	}
}

#==========================================
# installTestingPackages
#------------------------------------------
sub installTestingPackages {
	my $this = shift;
	my $pack = shift;
	my $manager  = $this->{manager};
	if (! $manager -> installPackages ($pack)) {
		$manager -> freeLock();
		return undef;
	}
	return $this;
}

#==========================================
# uninstallTestingPackages
#------------------------------------------
sub uninstallTestingPackages {
	my $this = shift;
	my $pack = shift;
	my $manager  = $this->{manager};
	if (! $manager -> removePackages ($pack)) {
		$manager -> freeLock();
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
	my @packList = $manager -> setupInstallPackages;
	#==========================================
	# proceed if packlist is not empty
	#------------------------------------------
	if (! @packList) {
		$kiwi -> loginfo ("Packlist is empty, skipping install\n");
		return $this;
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
	# Check and set lock
	#------------------------------------------
	$manager -> checkExclusiveLock();
	$manager -> setLock();
	#==========================================
	# Setup signature check
	#------------------------------------------
	$manager -> switchToChroot();
	if (! $manager -> setupSignatureCheck()) {
		$manager -> freeLock();
		return undef;
	}
	if (! $manager -> setupExcludeDocs()) {
		$manager -> freeLock();
		return undef;
	}
	#==========================================
	# Add source(s) and install
	#------------------------------------------
	if (! $manager -> setupInstallationSource()) {
		$manager -> freeLock();
		return undef;
	}
	if (! $manager -> setupRootSystem (@packList)) {
		$manager -> freeLock();
		return undef;
	}
	#==========================================
	# reset installation source
	#------------------------------------------
	# /.../
	# In order to re-use an already downloaded metadata cache
	# we prevent kiwi from removing the package manager cache.
	# kiwi point the package manger to an alternative cache
	# directory in /var/cache/kiwi/$manager. My hope is that
	# there will be no conflicts if different package manager
	# versions uses the cache. If you find problems activate
	# the following code:
	# ----
	# if (! $manager -> resetInstallationSource()) {
	#	$manager -> freeLock();
	#	return undef;
	# }
	$manager -> freeLock();
	return $this;
}

#==========================================
# installArchives
#------------------------------------------
sub installArchives {
	# ...
	# Install the given raw archives into the root
	# directory of the image system
	# ---
	my $this = shift;
	my $idesc= shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $root = $this->{root};
	my $manager = $this->{manager};
	if (! defined $idesc) {
		$idesc = $this->{imageDesc};
	}
	#==========================================
	# get image archive list
	#------------------------------------------
	my @archives = $xml -> getArchiveList();
	#==========================================
	# Install raw data archives
	#------------------------------------------
	$manager -> switchToLocal();
	if (! $manager -> setupArchives($idesc,@archives)) {
		return undef;
	}
	#==========================================
	# Check ownership of archive files
	#------------------------------------------
	if (-f "$root/bootincluded_archives.filelist") {
		$this -> fixupOverlayFilesOwnership ("bootincluded_archives.filelist");
	}
	return $this;
}

#==========================================
# fixupOverlayFilesOwnership
#------------------------------------------
sub fixupOverlayFilesOwnership {
	# ...
	# search for files and directories in the given path or
	# table of contents (toc) file and make sure those files
	# get the right ownership assigned
	# ---
	my $this  = shift;
	my $path  = shift;
	my $kiwi  = $this->{kiwi};
	my $root  = $this->{root};
	my $item  = $root."/".$path;
	my $prefix= "FixupOwner";
	my @files = ();
	my %except= ();
	if (-d $item) {
		#==========================================
		# got dir, search files there
		#------------------------------------------
		sub generateWanted {
			my $result = shift;
			my $base   = shift;
			return sub {
				my @names = ($File::Find::name,$File::Find::dir);
				foreach my $name (@names) {
					$name =~ s/^$base//; $name =~ s/^\///;
					push @{$result},$name;
				}
			}
		}
		my $wref = generateWanted (\@files,$root);
		find ({ wanted => $wref, follow => 0 }, $item);
	} elsif (-f $item) {
		#==========================================
		# got archive, use archive toc file
		#------------------------------------------
		my $fd = new FileHandle;
		if ($fd -> open ($item)) {
			while (my $line = <$fd>) {
				chomp $line; $line =~ s/^\///;
				push (@files,$line);
			}
			$fd -> close();
		} else {
			$kiwi -> warning ("$prefix: Failed to open $item: $!");
			$kiwi -> skipped ();
			return undef;
		}
	} else {
		$kiwi -> warning ("$prefix: No such file or directory: $item");
		$kiwi -> skipped ();
		return undef;
	}
	#==========================================
	# check file list
	#------------------------------------------
	if (! @files) {
		$kiwi -> warning ("$prefix: No files found in: $item");
		$kiwi -> skipped ();
		return undef;
	}
	#==========================================
	# create passwd exception directories
	#------------------------------------------
	my $fd = new FileHandle;
	if (! $fd -> open ($root."/etc/passwd")) {
		$kiwi -> warning ("$prefix: No passwd file found in: $root");
		$kiwi -> skipped ();
		return undef;
	}
	while (my $line = <$fd>) {
		chomp $line;
		my $name = (split (/:/,$line))[5];
		$name =~ s/\///;
		if ($name =~ /^(bin|sbin|root)/) {
			next;
		}
		$except{$name} = 1;
	}
	$fd -> close();
	#==========================================
	# walk through all files
	#------------------------------------------
	foreach my $file (@files) {
		my $ok = 1;
		$file =~ s/^ +//;
		foreach my $exception (keys %except) {
			if ($file =~ /$exception/) {
				$kiwi -> loginfo (
					"$prefix: $file belongs to passwd, leaving it untouched"
				);
				$ok = 0; last;
			}
		}
		next if ! $ok;
		my $data = qxx ("chroot $root chown -c root:root '".$file."' 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> warning (
				"$prefix: Failed to fixup ownership of $root/$file: $data"
			);
			$kiwi -> skipped ();
		}
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
	# 2) create .profile image environment source file
	# 3) import linuxrc file if required
	# 4) call package setup scripts from config directory
	# 5) calls the config.sh and package scripts within the
	#    chroot of the physical extend.
	# 6) copy the complete image description tree to
	#    /image which contains information to create a logical
	#    extend from the chroot.
	# 7) configure the system with methods from KIWIConfigure
	# 8) cleanup temporary files
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $xml  = $this->{xml};
	my $configFile= $xml -> getConfigName();
	my $imageDesc = $this->{imageDesc};
	my $manager   = $this->{manager};
	my $data;
	my $status;
	#======================================== 
	# Consistency check
	#----------------------------------------
	if (! -d "$root/tmp") {
		$kiwi -> error ("Image system seems to be broken");
		$kiwi -> failed ();
		return undef;
	}
	#========================================
	# copy license files if they exist
	#----------------------------------------
	if (-f "$root/license.tar.gz") {
		qxx ("mkdir -p $root/etc/YaST2/licenses/base");
		qxx ("tar -C $root/etc/YaST2/licenses/base -xf $root/license.tar.gz");
		qxx ("rm -f $root/license.tar.gz");
	}
	#========================================
	# copy user defined files to image tree
	#----------------------------------------
	if ((-d "$imageDesc/root") && (bsd_glob($imageDesc.'/root/*'))) {
		$kiwi -> info ("Copying user defined files to image tree");
		#========================================
		# copy user defined files to tmproot
		#----------------------------------------
		mkdir $root."/tmproot";
		if ((-l "$imageDesc/root/linuxrc") || (-l "$imageDesc/root/include")) {
			$data = qxx (
				"cp -LR --force $imageDesc/root/* $root/tmproot 2>&1"
			);
		} else {
			$data = qxx (
				"tar -cf - -C $imageDesc/root . | tar -x -C $root/tmproot 2>&1"
			);
		}
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		}
		#========================================
		# check tmproot ownership
		#----------------------------------------
		$this -> fixupOverlayFilesOwnership ("tmproot");
		#========================================
		# copy tmproot to real root (tar)
		#----------------------------------------
		$data = qxx ("tar -cf - -C $root/tmproot . | tar -x -C $root 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		}
		#========================================
		# cleanup tmproot
		#----------------------------------------
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
		$kiwi -> loginfo ("[PROFILE]: $key=\"$config{$key}\"\n");
		print FD "$key=\"$config{$key}\"\n";
	}
	close FD;
	#========================================
	# check for linuxrc
	#----------------------------------------
	if (-f "$root/linuxrc") {
		$kiwi -> info ("Setting up linuxrc...");
		my $data = qxx ("ln $root/linuxrc $root/init 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		}
		qxx ("chmod u+x $root/linuxrc $root/init 2>&1");
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
					return undef;
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
	qxx (" cp $configFile $root/image 2>&1 ");
	qxx (" cp $imageDesc/images.sh $root/image 2>&1 ");
	qxx (" cp $imageDesc/config-cdroot.tgz $root/image 2>&1 ");
	qxx (" cp $imageDesc/config-cdroot.sh  $root/image 2>&1 ");
	qxx (" cp $root/.profile $root/image 2>&1 ");
	qxx (" chmod u+x $root/image/images.sh 2>&1");
	qxx (" chmod u+x $root/image/config-cdroot.sh 2>&1");
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
	$status = $configure -> setupFirstBootYaST();
	if ($status eq "failed") {
		return undef;
	}
	$status = $configure -> setupAutoYaST();
	if ($status eq "failed") {
		return undef;
	}
	$status = $configure -> setupFirstBootAnaconda();
	if ($status eq "failed") {
		return undef;
	}
	#========================================
	# call config.sh image script
	#----------------------------------------
	if (-e "$imageDesc/config.sh") {
		$kiwi -> info ("Calling image script: config.sh");
		qxx (" cp $imageDesc/config.sh $root/tmp ");
				qxx (" chmod u+x $root/tmp/config.sh ");
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
	# create /etc/ImageID file
	#----------------------------------------
	my $id = $xml -> getImageID();
	if ($id) {
		$kiwi -> info ("Creating image ID file: $id");
		if ( ! open (FD,">$root/etc/ImageID")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create ID file: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "$id\n"; close FD;
		$kiwi -> done();
	}
	#========================================
	# cleanup temporary copy of resolv.conf
	#----------------------------------------
	if (! -e "$imageDesc/root/etc/resolv.conf") {
		# restore only if overlay tree doesn't contain a resolv.conf
		if ((-f "$root/etc/resolv.conf") && (-f "/etc/resolv.conf")) {
			my $data = qxx ("diff -q /etc/resolv.conf $root/etc/resolv.conf");
			my $code = $? >> 8;
			if ($code == 0) {
				$kiwi -> info ("Cleanup temporary copy of resolv.conf");
				qxx ("rm -f $root/etc/resolv.conf");
				$kiwi -> done ();
			}
		}
	}
	#========================================
	# cleanup temporary copy of hosts
	#----------------------------------------
	if (! -e "$imageDesc/root/etc/hosts") {
		# restore only if overlay tree doesn't contain a hosts
		if (-f "$root/etc/hosts.rpmnew") {
			$kiwi -> info ("Cleanup temporary copy of hosts");
			qxx ("mv $root/etc/hosts.rpmnew $root/etc/hosts");
			$kiwi -> done ();
		}
	}
	#========================================
	# cleanup temporary .buildenv
	#----------------------------------------
	if (-f "$root/.buildenv") {
		qxx ("rm -f $root/.buildenv");
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
# setupCacheMount
#------------------------------------------
sub setupCacheMount {
	# ...
	# bind mount the specified cache directory into
	# the chroot system. This is used to establish
	# a shared cache over multiple prepare processes
	# ---
	my $this  = shift;
	my $root  = $this->{root};
	my @cache = ("/var/cache/zypp","/var/cache/kiwi");
	my @mountList;
	if (defined $this->{mountList}) {
		@mountList = @{$this->{mountList}};
	} else {
		@mountList = ();
	}
	if (! -f "$root/dev/console") {
		qxx ("mkdir -p $root/dev");
		qxx ("mount --bind /dev $root/dev");
		push (@mountList,"$root/dev");
	}
	foreach my $cache (@cache) {
		if (! -d $cache) {
			qxx ("mkdir -p $cache");
		}
		if (! -d "$root/$cache") {
			qxx ("mkdir -p $root/$cache 2>&1");
		}
		qxx ("mount --bind $cache $root/$cache 2>&1");
		push (@mountList,"$root/$cache");
	}
	if (! -f "$root/proc/mounts") {
		qxx ("mkdir -p $root/proc");
		qxx ("mount -t proc proc $root/proc");
		push (@mountList,"$root/proc");
	}
	$this->{mountList} = \@mountList;
	return @mountList;
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
	my $prefix = $root."/".$baseSystem;
	my $cache  = "/var/cache";
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
		qxx ("mount -t proc proc $root/proc");
		push (@mountList,"$root/proc");
	}
	if (! -f "$root/dev/console") {
		qxx ("mount --bind /dev $root/dev");
		push (@mountList,"$root/dev");
	}
	if (! -f "$root/var/run/dbus/pid") {
		qxx ("mkdir -p $root/var/run/dbus");
		qxx ("mount --bind /var/run/dbus $root/var/run/dbus");
		push (@mountList,"$root/var/run/dbus");
	}
	if (! -d "$root/sys/block") {
		qxx ("mkdir -p $root/sys");
		qxx ("mount -t sysfs sysfs $root/sys");
		qxx ("mkdir -p $root/dev/pts");
		qxx ("mount -t devpts devpts $root/dev/pts");
		push (@mountList,"$root/sys");
		push (@mountList,"$root/dev/pts");
	}
	$this->{mountList} = \@mountList;
	@mountList = $this -> setupCacheMount();
	$kiwi -> done();
	foreach my $chl (keys %{$this->{sourceChannel}{private}}) {
		my @opts = @{$this->{sourceChannel}{private}{$chl}};
		my $path = $opts[2];
		if ($path =~ /='$baseSystem\/(.*)'$/) {
			$path = $1;
		} else {
			next;
		}
		$kiwi -> info ("Mounting local channel: $chl");
		my $roopt = "dirs=$cache=rw:$path=ro,ro";
		my $auopt = "dirs=$path=ro";
		my $mount = $prefix.$path;
		push (@mountList,$mount);
		qxx ("mkdir -p \"$mount\"");
		my $data = qxx ("touch $path/bob 2>&1");
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
			my $data = qxx (" mount -o bind \"$path\" \"$mount\" 2>&1 ");
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
	my $expr = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $xml  = $this->{xml};
	if (! defined $this->{mountList}) {
		return $this;
	}
	my @mountList  = @{$this->{mountList}};
	my $baseSystem = $this->{baseSystem};
	my $prefix = $root."/".$baseSystem;
	my @newList= ();
	foreach my $item (reverse @mountList) {
		if (defined $expr) {
			if ($item !~ /$expr/) {
				push (@newList,$item);
				next;
			}
		}
		$kiwi -> loginfo ("Umounting path: $item\n");
		my $data = qxx ("umount \"$item\" 2>&1");
		my $code = $? >> 8;
		if (($code != 0) && ($data !~ "not mounted")) {
			$kiwi -> loginfo ("Umount failed: $data");
			$kiwi -> warning ("Umount failed: calling lazy umount");
			my $data = qxx ("umount -l \"$item\" 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
			} else {
				$kiwi -> done();
			}
		}
		if ($item =~ /^$prefix/) {
			qxx ("rmdir -p \"$item\" 2>&1");
		}
		if ($item =~ /^\/tmp\/kiwimount/) {
			qxx ("rmdir -p \"$item\" 2>&1");
		}
		
	}
	if (-d $prefix) {
		rmdir $prefix;
	}
	if (defined $this->{overlay}) {
		undef $this->{overlay};
	}
	$this->{mountList} = \@newList;
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
	# remove data and cache dir(s) of the packagemanager
	# created for building the new root system
	# ---
	my $this = shift;
	my $manager = $this->{manager};
	$manager -> cleanChild();
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
