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

#==========================================
# Private
#------------------------------------------
my @mountList;
my @smartOpts;
my $imageDesc;
my $imageVirt;
my $baseSystem;
my $selfRoot;
my %smartChannel;
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
	$imageVirt  = shift;
	$selfRoot   = shift;
	$baseSystem = shift;
	#==========================================
	# Check parameters
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
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
	#==========================================
	# Create smartChannel hash
	#------------------------------------------
	foreach my $type (keys %repository) {
		my $urlHandler  = new KIWIURL ($kiwi);
		my $publics_url = $repository{$type};
		if (defined $urlHandler -> openSUSEpath ($publics_url)) {
			$publics_url = $urlHandler -> openSUSEpath ($publics_url);
		}
		my $private_url = $publics_url;
		if ($private_url =~ /^\//) {
			$private_url = $baseSystem."/".$private_url;
		}
		my $channel = "kiwi".$count."-".$$;
		my @private_options = ("type=$type","name=$channel",
			"baseurl=$private_url","-y"
		);
		my @public_options  = ("type=$type","name=$channel",
			"baseurl=$publics_url","-y"
		);
		$smartChannel{private}{$channel} = \@private_options;
		$smartChannel{public}{$channel}  = \@public_options;
		$count++;
	}
	#==========================================
	# Create root directory
	#------------------------------------------
	my $rootError = 1;
	if (! defined $selfRoot) {
		$root = qx ( mktemp -q -d /tmp/kiwi.XXXXXX );
		if ($? == 0) {
			$rootError = 0;
		}
		chomp $root;
	} else {
		$root = $selfRoot;
		if (mkdir $root) {
			$rootError = 0;
		}
	}
	if ( $rootError ) {
		$kiwi -> error ("Couldn't create root dir: $root: $!");
		$kiwi -> failed ();
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
	my @initPacs = $xml -> getBaseList();
	my @channelList;
	my $data;
	my $code;
	#==========================================
	# Check base package list
	#------------------------------------------
	if (! @initPacs) {
		$kiwi -> error ("Couldn't create base package list");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Add channel, install and remove channel
	#------------------------------------------
	foreach my $channel (keys %{$smartChannel{public}}) {
		my @opts = @{$smartChannel{public}{$channel}};
		$kiwi -> info ("Adding local smart channel: $channel");
		$data = qx ( smart channel --add $channel @opts 2>&1 );
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		push (@channelList,$channel);
		$kiwi -> done ();
	}
	#==========================================
	# Create smart install options
	#------------------------------------------
	my $forceChannels = join (",",@channelList);
	my @installOpts = (
		"-o rpm-root=$root",
		"-o deb-root=$root",
		"-o force-channels=$forceChannels",
		"-y"
	);
	$kiwi -> info ("Initializing image system on: $root...");
	$data = qx ( smart update @channelList 2>&1 );
	$data = qx ( smart install @initPacs @installOpts 2>&1 );
	$code = $? >> 8;
	if ($code != 0) {
		qx ( smart channel --remove @channelList -y 2>&1 );
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$kiwi -> done ();
	$kiwi -> info ("Removing smart channel(s): @channelList");
	$data = qx ( smart channel --remove @channelList -y 2>&1 );
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$kiwi -> done ();
	#==================================
	# Copy/touch some defaults files
	#----------------------------------
	qx ( mkdir -p $root/etc/sysconfig );
	qx ( touch $root/etc/mtab );
	qx ( touch $root/etc/sysconfig/bootloader ); 
	qx ( cp /etc/resolv.conf $root/etc );
	qx ( cp /etc/fstab  $root/etc );
	qx ( cp /etc/group  $root/etc );
	qx ( cp /etc/passwd $root/etc );

	#==================================
	# Create /etc/ImageVersion file
	#----------------------------------
	my $imageVersionFile = "$root/etc/ImageVersion";
	my $imageVersion = "$imageDesc/VERSION";
	my $imageName = $xml -> getImageName();
	if ( ! open (FD,">$imageVersionFile")) {
		$kiwi -> error ("Failed to create Version File: $!");
		$kiwi -> failed ();
		return undef;
	}
	if ( ! open (VD,$imageVersion)) {
		$kiwi -> error ("Failed to open VERSION file: $!");
		$kiwi -> failed ();
		return undef; 
	}
	$imageVersion = <VD>;
	chomp $imageVersion; close VD;
	print FD $imageName."-".$imageVersion; close FD;
	#==================================
	# Return object reference
	#----------------------------------
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
	# Get virtualisation package list
	#------------------------------------------
	if (defined $imageVirt) {
		SWITCH: for ($imageVirt) {
			#==========================================
			# Xen based Virtual Machine
			#------------------------------------------
			/^xen$/  && do {
				$kiwi -> info ("Creating Xen package list");
				my @xenList = $xml -> getXenList();
				if (! @xenList) {
					$kiwi -> error ("Couldn't create xen package list");
					$kiwi -> failed ();
					return undef;
				}
				@packList = (@packList,@xenList);
				$kiwi -> done ();
				last SWITCH;
			};
			#==========================================
			# Sorry no such vm system
			#------------------------------------------
			$kiwi -> error ("Unsupported vm-system specified");
			$kiwi -> failed ();
			return undef;
		}
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
	# Add smart channel(s) and install
	#------------------------------------------
	foreach my $channel (keys %{$smartChannel{private}}) {
		my @opts = @{$smartChannel{private}{$channel}};
		$kiwi -> info ("Adding image smart channel: $channel");
		my $data = qx ( chroot $root smart channel --add $channel @opts 2>&1 );
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
	}
	$kiwi -> info ("Installing image packages...");
	my $data = qx ( chroot $root smart update 2>&1 );
	my $data = qx ( chroot $root smart install @packList -y 2>&1 );
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# setup
#------------------------------------------
sub setup {
	# ...
	# Setup the installed system. This method will copy the user
	# defined files to the root tree and creates the .profile
	# environment file. Additionally the config.sh and package
	# scripts are called within the chroot of the physical extend.
	# At the end of this procedure the complete image description
	# tree is copied to /image which contains information to
	# create a logical extend from the chroot.
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
		qx ( cp -LR --remove-destination $imageDesc/root/* $root 2>&1 );
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
		}
		qx ( rm -f $root/tmp/config.sh );
		$kiwi -> done ();
	}
	#=============================================
	# call setup scripts
	#---------------------------------------------
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
				$kiwi -> info ("Calling package setup script: $script");
				qx ( chroot $root smart query --installed $script 2>&1 );
				my $exit = $? >> 8;
				if ($exit != 0) {
					$kiwi -> failed ();
					$kiwi -> error  ("Package $script is not installed");
					$kiwi -> failed ();
					next;
				}
				qx ( chmod u+x $root/image/config/$script);
				my $data = qx ( chroot $root /image/config/$script 2>&1 );
				my $code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> info   ($data);
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
	qx ( cp $imageDesc/config.xml $root/image );
	qx ( cp $imageDesc/images.sh $root/image );
	qx ( cp $imageDesc/VERSION $root/image );
	return $this;
}

#==========================================
# solve
#------------------------------------------
sub solve {
	# ...
	# solve and fix package dependencies using smart.
	# The method will mount all rreachable local and nfs
	# directories and will setup a smart channel for
	# checking the package dependency tree
	# ---
	my $this   = shift;
	$kiwi -> info ("Solving/Fixing package dependencies");
	my $data = qx ( chroot $root smart fix -y 2>&1 );
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't resolve dependencies");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
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
	$kiwi -> info ("Mounting local/NFS file systems");
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
	if (! open (FD,"cat /proc/mounts|")) {
		$kiwi -> failed ();
		$kiwi -> error ("Couldn't open mount table: $!");
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
	while (<FD>) {
		if ($_ =~ /^#/) {
			next;
		}
		if ($_ =~ /(^\/.*)/) {
			my @list = split (/ +/,$1);
			my $device = shift @list;
			my $mount  = shift @list;
			$mount = $prefix.$mount;
			push (@mountList,$mount);
			#$kiwi -> info ("Mounting local device: $device $mount\n");
			qx (mkdir -p $mount);
			qx (mount $device $mount);
		}
		if ($_ =~ /(.*:\/.*) (.*) nfs/) {
			my $device = $1;
			my $mount  = $2;
			$mount = $prefix.$mount;
			push (@mountList,$mount);
			#$kiwi -> info ("Mounting NFS device: $device $mount\n");
			qx (mkdir -p $mount);
			qx (mount $device $mount);
		}
	}
	close  FD;
	$kiwi -> done();
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
		#$kiwi -> info ("Umounting device: $item\n"); 
		qx (umount $item 2>/dev/null);
		if ($item =~ /^$prefix/) {
			rmdir $item;
		}
	}
	return $this;
}

1;
