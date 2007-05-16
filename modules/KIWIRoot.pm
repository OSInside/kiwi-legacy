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

#==========================================
# Private
#------------------------------------------
my @mountList;
my $imageDesc;
my $baseSystem;
my $manager;
my $useRoot;
my $selfRoot;
my %sourceChannel;
my $root;
my $xml;
my $kiwi;

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
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi = shift;
	$xml  = shift;
	$imageDesc  = shift;
	$selfRoot   = shift;
	$baseSystem = shift;
	$useRoot    = shift;
	my $code;
	#==========================================
	# Check parameters
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if ($imageDesc !~ /\//) {
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
	my %repository;
	if ($baseSystem eq "/meta-system") {
		%repository = $xml -> getMetaRepository();
	} else {
		%repository = $xml -> getRepository();
	}
	if (! %repository) {
		if ($baseSystem eq "/meta-system") {
			$kiwi -> error ("No instsource repository specified in XML tree");
		} else {
			$kiwi -> error ("No repository specified in XML tree");
		}
		$kiwi -> failed ();
		return undef; 
	}
	my $count = 1;
	#==========================================
	# Create sourceChannel hash
	#------------------------------------------
	foreach my $source (keys %repository) {
		my $type = $repository{$source};
		my $urlHandler  = new KIWIURL ($kiwi);
		my $publics_url = $source;
		my $highlvl_url = $urlHandler -> openSUSEpath ($publics_url);
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
		$highlvl_url = $urlHandler -> thisPath ($publics_url);
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
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
	my $rootError = 1;
	if (! defined $useRoot) {
		if (! defined $selfRoot) {
			$root = qx ( mktemp -q -d /tmp/kiwi.XXXXXX );
			$code = $? >> 8;
			if ($code == 0) {
				$rootError = 0;
			}
			chomp $root;
		} else {
			$root = $selfRoot;
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
		$kiwi -> error ("Couldn't create root dir: $root: $!");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Set root log file
	#------------------------------------------
	if (! defined $main::LogFile) {
		$kiwi -> setRootLog ($root."/screenrc.log");
	}
	#==========================================
	# Get configured name of package manager
	#------------------------------------------
	$kiwi -> info ("Setting up package manager: ");
	my $pmgr = $xml -> getPackageManager();
	if (! defined $pmgr) {
		rmdir $root;
		return undef;
	}
	$kiwi -> note ($pmgr);
	$kiwi -> done ();

	#==========================================
	# Create package manager object
	#------------------------------------------
	$manager = new KIWIManager (
		$kiwi,$xml,\%sourceChannel,$root,$pmgr
	);
	if (! defined $manager) {
		return undef;
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
	#==========================================
	# Get base Package list
	#------------------------------------------
	my @initPacs;
	if ($baseSystem eq "/meta-system") {
		@initPacs = $xml -> getBaseMetaList();
	} else {
		@initPacs = $xml -> getBaseList();
	}
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
	#==========================================
	# Add src, install/download and clean src
	#------------------------------------------
	if (! $manager -> setupInstallationSource()) {
		return undef;
	}
	if ($baseSystem eq "/meta-system") {
		if (! $manager -> setupDownload (@initPacs)) {
			$manager -> resetInstallationSource();
			return undef;
		}
	} else {
		if (! $manager -> setupRootSystem(@initPacs)) {
			$manager -> resetInstallationSource();
			return undef;
		}
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
	#==========================================
	# Return in case of instsource creation
	#------------------------------------------
	if ($baseSystem eq "/meta-system") {
		return $this;
	}
	#==================================
	# Copy/touch some defaults files
	#----------------------------------
	qx ( mkdir -p $root/etc/sysconfig );
	qx ( mkdir -p $root/var/log/YaST2 );
	qx ( touch $root/etc/mtab );
	qx ( touch $root/etc/sysconfig/bootloader ); 
	qx ( cp /etc/resolv.conf $root/etc 2>&1 );
	qx ( cp /etc/fstab  $root/etc 2>&1 );
	qx ( cp /etc/group  $root/etc 2>&1 );
	qx ( cp /etc/passwd $root/etc 2>&1 );
	qx ( cp $main::KConfig $root/.kconfig 2>&1 );

	#==================================
	# Create /etc/ImageVersion file
	#----------------------------------
	my $imageVersionFile = "$root/etc/ImageVersion";
	my $imageVersion = $xml -> getImageVersion();
	my $imageName    = $xml -> getImageName();
	if ( ! open (FD,">$imageVersionFile")) {
		$kiwi -> error ("Failed to create Version File: $!");
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
	#==========================================
	# Mount local and NFS directories
	#------------------------------------------
	if (! setupMount ($this)) {
		$kiwi -> error ("Couldn't mount base system");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Upgrade system
	#------------------------------------------
	if (! $manager -> setupUpgrade()) {
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
	my %type = %{$xml -> getImageTypeAndAttributes()};
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
		qx ( mkdir $root/tmproot );
		qx ( cp -LR --remove-destination $imageDesc/root/* $root/tmproot 2>&1 );
		qx ( find $root/tmproot -type d | grep .svn\$ | xargs rm -rf 2>&1 );
		qx ( cp -LR --remove-destination $root/tmproot/* $root );
		qx ( rm -rf $root/tmproot );
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
	# call config.sh image script
	#----------------------------------------
	if (-x "$imageDesc/config.sh") {
		$kiwi -> info ("Calling image script: config.sh");
		qx ( cp $imageDesc/config.sh $root/tmp );
		my $data = qx ( chroot $root /tmp/config.sh 2>&1 );
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			return undef;
		}
		qx ( rm -f $root/tmp/config.sh );
		$kiwi -> done ();
	}
	#========================================
	# check for linuxrc
	#----------------------------------------
	if (-f "$root/linuxrc") {
		$kiwi -> info ("Setting up linuxrc...");
		my $data = qx ( cp $root/linuxrc $root/init 2>&1 );
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
		qx ( mkdir -p $root/image/config );
		qx ( cp $imageDesc/config/* $root/image/config 2>&1 );
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
				qx ( chmod u+x $root/image/config/$script);
				my $data = qx ( chroot $root /image/config/$script 2>&1 );
				my $code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> info   ($data);
					$kiwi -> failed ();
				}
				qx (rm -f $root/image/config/$script);
				$kiwi -> done ();
			}
		}
		rmdir ("$root/image/config");
		closedir FD;
	}
	#========================================
	# copy image description to image tree
	#----------------------------------------
	qx ( mkdir -p $root/image );
	qx ( cp $imageDesc/config.xml $root/image 2>&1 );
	qx ( cp $imageDesc/images.sh $root/image 2>&1 );
	if (open (FD,">$root/image/main::Prepare")) {
		if ($imageDesc !~ /^\//) {
			my $pwd = qx ( pwd ); chomp $pwd;
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
	# setup yast if config-yast.xml exists
	#----------------------------------------
	if (! $configure -> setupAutoYaST()) {
		return undef;
	}
	#========================================
	# Create in place SVN repos from /etc
	#----------------------------------------
	if (! $configure -> setupInPlaceSVNRepository()) {
		return undef;
	}
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
	my $prefix = $root."/".$baseSystem;
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
		qx (mkdir -p $root/proc);
		qx (mount -t proc none $root/proc);
		push (@mountList,"$root/proc");
	}
	if (! -d "$root/sys/block") {
		qx (mkdir -p $root/sys);
		qx (mount -t sysfs  none $root/sys);
		qx (mount -t devpts none $root/dev/pts);
		push (@mountList,"$root/sys");
		push (@mountList,"$root/dev/pts");
	}
	$kiwi -> done();
	foreach my $chl (keys %{$sourceChannel{private}}) {
		my @opts = @{$sourceChannel{private}{$chl}};
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
			qx ( mkdir -p $cache );
		}
		qx (mkdir -p $mount);
		my $data = qx (mount -t aufs -o $auopt aufs $mount 2>&1);
		my $code = $? >> 8;
		if ($code != 0) {
			$data = qx (mount -t unionfs -o $roopt unionfs $mount 2>&1);
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> skipped ();
			$kiwi -> warning ("Couldn't mount read-only, using bind mount");
			my $data = qx ( mount -o bind $path $mount 2>&1 );
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				return undef;
			}
			$kiwi -> done();
		} else {
			$kiwi -> done();
		}
	}
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
	my $prefix = $root."/".$baseSystem;
	foreach my $item (reverse @mountList) {
		#$kiwi -> info ("Umounting path: $item\n");
		qx (umount $item 2>/dev/null);
		if ($item =~ /^$prefix/) {
			qx ( rmdir -p $item 2>&1 );
		}
	}
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
	$manager -> resetSource();
	return $this;
}

1;
