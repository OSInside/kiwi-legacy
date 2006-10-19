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
	my $code;
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
	foreach my $source (keys %repository) {
		my $type = $repository{$source};
		my $urlHandler  = new KIWIURL ($kiwi);
		my $publics_url = $source;
		if (defined $urlHandler -> openSUSEpath ($publics_url)) {
			$publics_url = $urlHandler -> openSUSEpath ($publics_url);
		}
		my $private_url = $publics_url;
		if ($private_url =~ /^\//) {
			$private_url = $baseSystem."/".$private_url;
		}
		my $channel = "kiwi".$count."-".$$;
		my $srckey  = "baseurl";
		if ($type eq "rpm-dir") {
			$srckey = "path";
		}
		my @private_options = ("type=$type","name=$channel",
			"$srckey=$private_url","-y"
		);
		my @public_options  = ("type=$type","name=$channel",
			"$srckey=$publics_url","-y"
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
	# Setup signature check
	#------------------------------------------
	my $curCheckSig = qx (smart config --show rpm-check-signatures|tr -d '\n');
	my $imgCheckSig = $xml->getRPMCheckSignatures();
	if (defined $imgCheckSig) {
		$kiwi -> info ("Setting RPM signature check to: $imgCheckSig");
		$data = qx (smart config --set rpm-check-signatures=$imgCheckSig 2>&1);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
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
	#==========================================
	# Create screen call file
	#------------------------------------------
	my $smartCall = $root."/screenrc.smart";
	my $smartCtrl = $root."/screenrc.ctrls";
	my $smartLogs = $root."/screenrc.log";
	if ((! open (FD,">$smartCall")) || (! open (CD,">$smartCtrl"))) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create call file: $!");
		$kiwi -> failed ();
		$kiwi -> info ("Removing smart channels: @channelList...");
		$data = qx ( smart channel --remove @channelList -y 2>&1 );
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			$kiwi -> failed ();
		} else {
			$kiwi -> done();
		}
		return undef;
	}
	print CD "logfile $smartLogs\n";
	close CD;
	print FD "smart update @channelList\n";
	print FD "test \$? = 0 && smart install @initPacs @installOpts\n";
	print FD "echo \$? > $smartCall.exit\n";
	close FD;

	#==========================================
	# run smart update and install in screen
	#------------------------------------------
	$data = qx ( chmod 755 $smartCall );
	$data = qx ( screen -L -D -m -c $smartCtrl $smartCall );
	$code = $? >> 8;
	if (open (FD,$smartLogs)) {
		local $/; $data = <FD>; close FD;
	}
	if ($code == 0) {
		if (! open (FD,"$smartCall.exit")) {
			$code = 1;
		} else {
			$code = <FD>; chomp $code;
			close FD;
		}
	}
	qx ( rm -f $smartCall* );
	qx ( rm -f $smartCtrl );
	qx ( rm -f $smartLogs );

	#==========================================
	# check exit code from screen session
	#------------------------------------------
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		$kiwi -> info ("Removing smart channels: @channelList...");
		$data = qx ( smart channel --remove @channelList -y 2>&1 );
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
		}
		$kiwi -> done();
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
	#==========================================
	# Reset signature check
	#------------------------------------------
	if (defined $imgCheckSig) {
		$kiwi -> info ("Resetting RPM signature check to: $curCheckSig");
		$data = qx (smart config --set rpm-check-signatures=$curCheckSig 2>&1);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
	}
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
	# Setup signature check
	#------------------------------------------
	my $imgCheckSig = $xml->getRPMCheckSignatures();
	if (defined $imgCheckSig) {
		$kiwi -> info ("Setting RPM signature check to: $imgCheckSig");
		my $option = "rpm-check-signatures=$imgCheckSig";
		my $data = qx ( chroot $root smart config --set $option 2>&1);
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
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
	#==========================================
	# Create screen call file
	#------------------------------------------
	my $smartCall = $root."/screenrc.smart";
	my $smartCtrl = $root."/screenrc.ctrls";
	my $smartLogs = $root."/screenrc.log";
	if ((! open (FD,">$smartCall")) || (! open (CD,">$smartCtrl"))) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create call file: $!");
		$kiwi -> failed ();
		return undef;
	}
	print CD "logfile $smartLogs\n";
	close CD;
	print FD "chroot $root smart update\n";
	print FD "test \$? = 0 && chroot $root smart install @packList -y\n";
	print FD "echo \$? > $smartCall.exit\n";
	close FD;

	#==========================================
	# run smart update and install in screen
	#------------------------------------------
	qx ( chmod 755 $smartCall );
	my $data = qx ( screen -L -D -m -c $smartCtrl $smartCall );
	my $code = $? >> 8;
	if (open (FD,$smartLogs)) {
		local $/; $data = <FD>; close FD;
	}
	if ($code == 0) {
		if (! open (FD,"$smartCall.exit")) {
			$code = 1;
		} else {
			$code = <FD>; chomp $code;
			close FD;
		}
	}
	qx (rm -f $smartCall* );
	qx (rm -f $smartCtrl );
	qx (rm -f $smartLogs );

	#==========================================
	# check exit code from screen session
	#------------------------------------------
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
	qx ( cp $imageDesc/VERSION $root/image 2>&1 );

	#========================================
	# check <users> tag, create users/groups
	#----------------------------------------
	my %users = $xml -> getUsers();
	if (defined %users) {
		my $adduser  = "/usr/sbin/useradd";
		my $addgroup = "/usr/sbin/groupadd";
		foreach my $user (keys %users) {
			my $group = $users{$user}{group};
			my $pwd   = $users{$user}{pwd};
			my $home  = $users{$user}{home};
			if (defined $pwd) {
				$adduser .= " -p '$pwd'";
			}
			if (defined $home) {
				$adduser .= " -m -d $home";
			}
			if (defined $group) {
				my $data = qx ( chroot $root grep -q $group /etc/group 2>&1 );
				my $code = $? >> 8;
				if ($code != 0) {
					$kiwi -> info ("Adding group: $group");
					my $data = qx ( chroot $root $addgroup $group );
					my $code = $? >> 8;
					if ($code != 0) {
						$kiwi -> failed ();
						$kiwi -> info   ($data);
						$kiwi -> failed ();
						return undef;
					}
					$kiwi -> done();
				}
				$adduser .= " -G $group";
			}
			$kiwi -> info ("Adding user: $user [$group]");
			my $data = qx ( chroot $root $adduser $user 2>&1 );
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> info   ($data);
				$kiwi -> failed ();
				return undef;
			}
			$kiwi -> done ();
		}
	}
	#========================================
	# setup yast if config-yast.xml exists
	#----------------------------------------
	if (-f "$imageDesc/config-yast.xml") {
		$kiwi -> info ("Setting up AutoYaST...");
		my $autodir = "var/lib/autoinstall/autoconf";
		my $autocnf = "autoconf.xml";
		if (! -d "$root/$autodir") {
			$kiwi -> failed ();
			$kiwi -> error  ("AutoYaST seems not be installed");
			$kiwi -> failed ();
			return undef;
		}
		qx ( cp $imageDesc/config-yast.xml $root/$autodir/$autocnf 2>&1 );
		if ( ! open (FD,">$root/etc/install.inf")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create install.inf: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "AutoYaST: http://192.168.100.99/part2.xml\n";
		close FD;
		if ( ! open (FD,">$root/var/lib/YaST2/runme_at_boot")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create runme_at_boot: $!");
			$kiwi -> failed ();
			return undef;
		}
		close FD;
		$kiwi -> done ();
	}
	#========================================
	# Create in place SVN repos from /etc
	#----------------------------------------
	if (-f "$root/usr/bin/svn") {
		$kiwi -> info ("Creating in-place SVN repository...");
		my $repo = "/var/adm/etc-repos";
		my $file = "/etc-repos.sh";
		if ( ! open (FD,">$root/$file")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create SVN script: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "#!/bin/bash\n";
		print FD "svnadmin create $repo\n";
		print FD "chmod 700 $repo\n";
		print FD "svn mkdir -m created file:///$repo/trunk\n";
		print FD "svn mkdir -m created file:///$repo/trunk/etc\n";
		print FD "svn mkdir -m created file:///$repo/trunk/srv\n";
		print FD "svn mkdir -m created file:///$repo/trunk/var\n";
		print FD "svn mkdir -m created file:///$repo/trunk/var/log\n";
		print FD "svn co file:///$repo/trunk/etc /etc\n";
		print FD "svn co file:///$repo/trunk/srv /srv\n";
		print FD "svn co file:///$repo/trunk/var/log /var/log\n";
		print FD "chmod 700 /etc/.svn\n";
		print FD "chmod 700 /srv/.svn\n";
		print FD "chmod 700 /var/log/.svn\n";
		print FD "svn add /etc/*\n";
		print FD "find /etc -name .svn | xargs chmod 700\n";
		print FD "svn ci -m initial /etc\n";
		print FD "svn add /srv/*\n";
		print FD "find /srv -name .svn | xargs chmod 700\n";
		print FD "svn ci -m initial /srv\n";
		print FD "svn add /var/log/*\n";
		print FD "find /var/log -name .svn | xargs chmod 700\n";
		print FD "svn ci -m initial /var/log\n";
		close FD;
		qx ( chmod 755 $root/$file 2>&1 );
		my $data = qx ( chroot $root $file 2>&1 );
		my $exit = $? >> 8;
		if ($exit != 0) {
			$kiwi -> failed ();
			$kiwi -> info ("Failed to create SVN repository: $data");
			$kiwi -> failed ();
			return undef;
		}
		unlink ("$root/$file");
		$kiwi -> done();
	}
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
			if ($device =~ /loop/) {
				#$kiwi -> info ("Mounting local loop: $device $mount\n");
				my $loop = qx (/sbin/losetup $device); chomp ($loop);
				if ($loop =~ /\((.*)\)/) {
					my $lobase = $1;
					my $mtab   = "/etc/mtab";
					my $lofile = qx (cat $mtab | grep $lobase | cut -f1 -d' ');
					chomp $lofile;
					qx (mount -o loop $lofile $mount);
				}
			} else {			
				#$kiwi -> info ("Mounting local device: $device $mount\n");
				qx (mkdir -p $mount);
				qx (mount $device $mount);
			}
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

#==========================================
# cleanSmart
#------------------------------------------
sub cleanSmart {
	# ...
	# remove all smart channels created by kiwi
	# ---
	my $this = shift;
	foreach my $channel (keys %{$smartChannel{public}}) {
		#$kiwi -> info ("Removing smart channel: $channel\n");
		qx ( smart channel --remove $channel -y 2>&1 );
	}
	return $this;
}

1;
