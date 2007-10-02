#================
# FILE          : KIWIManager.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to support multiple
#               : package manager like smart or zypper
#               :
# STATUS        : Development
#----------------
package KIWIManager;
#==========================================
# Modules
#------------------------------------------
require Exporter;
use strict;
use FileHandle;
use KIWILog;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (%packageManager);

#==========================================
# Exports
#------------------------------------------
our %packageManager;
$packageManager{smart}   = "/usr/bin/smart";
$packageManager{zypper}  = "/usr/bin/zypper";
$packageManager{default} = "smart";

#==========================================
# Constructor
#------------------------------------------
sub new { 
	# ...
	# Create a new KIWIManager object, which is used
	# to import all data needed to abstract from different
	# package managers
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
	my $kiwi      = shift;
	my $xml       = shift;
	my $sourceRef = shift;
	my $root      = shift;
	my $manager   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (! defined $xml) {
		$kiwi -> error  ("Missing XML description pointer");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $sourceRef) {
		$kiwi -> error  ("Missing channel description pointer");
		$kiwi -> failed ();
		return undef;
	}
	my %source = %{$sourceRef};
	if (! defined $root) {
		$kiwi -> error  ("Missing chroot path");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $manager) {
		$manager = "smart";
	}
	my @channelList = ();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}        = $kiwi;
	$this->{channelList} = \@channelList;
	$this->{xml}         = $xml;
	$this->{source}      = \%source;
	$this->{manager}     = $manager;
	$this->{root}        = $root;
	$this->{chroot}      = 0;
	$this->{lock}        = "/var/lock/kiwi-init.lock";
	$this->{screenCall}  = $root."/screenrc.smart";
	$this->{screenCtrl}  = $root."/screenrc.ctrls";
	$this->{screenLogs}  = $kiwi -> getRootLog();
	$this->{zypper}      = [
		"zypper","--non-interactive","--no-gpg-checks"
	];
	return $this;
}

#==========================================
# switchToChroot
#------------------------------------------
sub switchToChroot {
	my $this = shift;
	$this->{chroot} = 1;
}

#==========================================
# switchToLocal
#------------------------------------------
sub switchToLocal {
	my $this = shift;
	$this->{chroot} = 0;
}

#==========================================
# setupScreen
#------------------------------------------
sub setupScreen {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	#==========================================
	# screen files
	#------------------------------------------
	my $screenCall = $this->{screenCall};
	my $screenCtrl = $this->{screenCtrl};
	my $screenLogs = $this->{screenLogs};

	#==========================================
	# Initiate screen call file
	#------------------------------------------
	my $fd = new FileHandle;
	my $cd = new FileHandle;
	if ((! $fd -> open (">$screenCall")) || (! $cd -> open (">$screenCtrl"))) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create call file: $!");
		$kiwi -> failed ();
		$this -> resetInstallationSource();
		return undef;
	}
	print $cd "logfile $screenLogs\n";
	print $cd "logfile flush 10\n";
	$cd -> close();

	#==========================================
	# return screen call file handle
	#------------------------------------------
	return $fd;
}

#==========================================
# setupScreenCall
#------------------------------------------
sub setupScreenCall {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $screenCall = $this->{screenCall};
	my $screenCtrl = $this->{screenCtrl};
	my $screenLogs = $this->{screenLogs};
	my $logs = 1;
	my $code;
	#==========================================
	# Check log location
	#------------------------------------------
	if ($main::LogFile eq "terminal") {
		$logs = 0;
	}
	#==========================================
	# run process in screen session
	#------------------------------------------
	my $data = qx ( chmod 755 $screenCall );
	my $fd = new FileHandle;
	if ($logs) {
		$data = qx ( screen -L -D -m -c $screenCtrl $screenCall );
		$code = $? >> 8;
		if ($fd -> open ($screenLogs)) {
			local $/; $data = <$fd>; $fd -> close();
		}
		if ($code == 0) {
			if (! $fd -> open ("$screenCall.exit")) {
				$code = 1;
			} else {
				$code = <$fd>; chomp $code;
				$fd -> close();
			}
		}
	} else {
		$code = system ( $screenCall );
		$code = $code >> 8;
	}
	qx ( rm -f $screenCall* );
	qx ( rm -f $screenCtrl );
	#==========================================
	# check exit code from screen session
	#------------------------------------------
	if ($code != 0) {
		$kiwi -> failed ();
		if ( $logs ) {
			$kiwi -> error  ($data);
		}
		$this -> resetInstallationSource();
		return undef;
	}
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupSignatureCheck
#------------------------------------------
sub setupSignatureCheck {
	# ...
	# Check if the image description contains the signature
	# check option or not. If yes activate or deactivate it
	# according to the used package manager
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $manager = $this->{manager};
	my $chroot  = $this->{chroot};
	my $root    = $this->{root};
	my $lock    = $this->{lock};
	my $data;
	my $code;

	#==========================================
	# Get signature information
	#------------------------------------------
	my $imgCheckSig = $xml -> getRPMCheckSignatures();
	$this->{imgCheckSig} = $imgCheckSig;

	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		my $optionName  = "rpm-check-signatures";
		my $curCheckSig = qx (smart config --show $optionName|tr -d '\n');
		$this->{curCheckSig} = $curCheckSig;
		if (defined $imgCheckSig) {
			my $option = "$optionName=$imgCheckSig";
			my $cmdstr = "smart config --set";
			if (! $chroot) {
				$this -> checkExclusiveLock();
				$kiwi -> info ("Setting RPM signature check to: $imgCheckSig");
				$this -> setLock();
				$data = qx ( bash -c "$cmdstr $option 2>&1" );
				$this -> freeLock();
			} else {
				$kiwi -> info ("Setting RPM signature check to: $imgCheckSig");
				$data = qx ( chroot $root bash -c "$cmdstr $option 2>&1" );
			}
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			$kiwi -> done ();
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		# nothing to do for zypper here...
	}
	return $this;
}

#==========================================
# resetSignatureCheck
#------------------------------------------
sub resetSignatureCheck {
	# ...
	# reset the signature check option to the previos
	# value of the package manager
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my $manager= $this->{manager};
	my $root   = $this->{root};
	my $lock   = $this->{lock};
	my $curCheckSig = $this->{curCheckSig};
	my $data;
	my $code;
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		if (defined $this->{imgCheckSig}) {
			my $optionName  = "rpm-check-signatures";
			my $option = "$optionName=$curCheckSig";
			my $cmdstr = "smart config --set";
			if (! $chroot) {
				$this -> checkExclusiveLock();
				$kiwi -> info ("Reset RPM signature check to: $curCheckSig");
				$this -> setLock();
				$data = qx ( bash -c "$cmdstr $option 2>&1" );
				$this -> freeLock();
			} else {
				$kiwi -> info ("Reset RPM signature check to: $curCheckSig");
				$data = qx ( chroot $root bash -c "$cmdstr $option 2>&1" );
			}
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			$kiwi -> done ();
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		# nothing to do for zypper here...
	}
	return $this;
}

#==========================================
# setupInstallationSource
#------------------------------------------
sub setupInstallationSource {
	# ...
	# setup an installation source to retrieve packages
	# from. multiple sources are allowed
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my %source = %{$this->{source}};
	my $root   = $this->{root};
	my $manager= $this->{manager};
	my @zypper = @{$this->{zypper}};
	my $lock   = $this->{lock};
	my $data;
	my $code;
	#==========================================
	# Reset channel list
	#------------------------------------------
	my @channelList = ();

	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		my $stype = "private";
		if (! $chroot) {
			$stype = "public";
		}
		foreach my $chl (keys %{$source{$stype}}) {
			my @opts = @{$source{$stype}{$chl}};
			my $cmds = "smart channel --add";
			if (! $chroot) {
				$this -> checkExclusiveLock();
				$this -> setLock();
				$kiwi -> info ("Adding local smart channel: $chl");
				$data = qx ( bash -c "$cmds $chl @opts 2>&1" );
				$code = $? >> 8;
				$this -> freeLock();
			} else {
				$kiwi -> info ("Adding image smart channel: $chl");
				$data = qx ( chroot $root bash -c "$cmds $chl @opts 2>&1" );
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			push (@channelList,$chl);
			$kiwi -> done ();
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		my $stype = "private";
		if (! $chroot) {
			$stype = "public";
		}
		foreach my $alias (keys %{$source{$stype}}) {
			my @sopts = @{$source{$stype}{$alias}};
			my @zopts = ();
			foreach my $opt (@sopts) {
				my ($key,$val) = split (/=/,$opt);
				#==========================================
				# Adapt URI parameter
				#------------------------------------------
				if (($key eq "baseurl") || ($key eq "path")) {
					if ($val =~ /^\//) {
						$val = "file://$val";
					}
					push (@zopts,$val);
				}
				#==========================================
				# Adapt type parameter
				#------------------------------------------
				if ($key eq "type") {
					if ($val eq "yast2") {
						$val = "YaST";
					}
					if ($val eq "rpm-dir") {
						$val = "Plaindir";
					}
					if ($val eq "rpm-md") {
						$val = "YUM";
					}
					push (@zopts,"--type $val");
				}
			}
			my $sadd = "service-add @zopts $alias";
			if (! $chroot) {
				$this -> checkExclusiveLock();
				$this -> setLock();
				$kiwi -> info ("Adding local zypper service: $alias");
				$data = qx (bash -c "@zypper --root $root $sadd 2>&1");
				$code = $? >> 8;
				$this -> freeLock();
			} else {
				$kiwi -> info ("Adding image zypper service: $alias");
				$data = qx (chroot $root bash -c "@zypper $sadd 2>&1");
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			push (@channelList,$alias);
			$kiwi -> done ();
		}
	}
	$this->{channelList} = \@channelList;
	return $this;
}

#==========================================
# resetInstallationSource
#------------------------------------------
sub resetInstallationSource {
	# ...
	# clean the installation source environment
	# which means remove temporary inst-sources
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my $manager= $this->{manager};
	my $root   = $this->{root};
	my @zypper = @{$this->{zypper}};
	my $lock   = $this->{lock};
	my @channelList = @{$this->{channelList}};
	my $data;
	my $code;
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		my @list = @channelList;
		my $cmds = "smart channel --remove";
		if (! $chroot) {
			$this -> checkExclusiveLock();
			$kiwi -> info ("Removing smart channel(s): @channelList");
			$this -> setLock();
			$data = qx ( bash -c "$cmds @list -y 2>&1" );
			$code = $? >> 8;
			$this -> freeLock();
		} else {
			$kiwi -> info ("Removing smart channel(s): @channelList");
			$data = qx ( chroot $root bash -c "$cmds @list -y 2>&1" );
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		my @list = @channelList;
		my $sdel = "service-delete @list";
		if (! $chroot) {
			$this -> checkExclusiveLock();
			$kiwi -> info ("Removing zypper service(s): @channelList");
			$this -> setLock();
			$data = qx ( bash -c "@zypper --root $root $sdel 2>&1" );
			$code = $? >> 8;
			$this -> freeLock();
		} else {
			$kiwi -> info ("Removing zypper service(s): @channelList");
			$data = qx ( chroot $root bash -c "@zypper $sdel 2>&1" );
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
	}
	return $this;
}

#==========================================
# setupDownload
#------------------------------------------
sub setupDownload {
	# ...
	# download package files for later handling
	# using the package manager download functionality
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $manager= $this->{manager};
	my $root   = $this->{root};
	my @channelList = @{$this->{channelList}};
	my $screenCall  = $this->{screenCall};
	my @pacs   = @_;
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return undef;
	}
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		$kiwi -> info ("Downloading packages...");
		my $forceChannels = join (",",@channelList);
		my @loadOpts = (
			"-o force-channels=$forceChannels",
			"--target=$root"
		);
		#==========================================
		# Create screen call file
		#------------------------------------------
		print $fd "smart update @channelList\n";
		print $fd "test \$? = 0 && smart download @pacs @loadOpts\n";
		print $fd "echo \$? > $screenCall.exit\n";
		print $fd "rm -f $root/etc/smart/channels/*\n";
		$fd -> close();
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		# TODO
		$kiwi -> failed ();
		$kiwi -> error  ("*** not implemeted ***");
		$kiwi -> failed ();
		return undef;
	}
	return $this -> setupScreenCall();
}

#==========================================
# setupUpgrade
#------------------------------------------
sub setupUpgrade {
	# ...
	# upgrade the previosly installed root system
	# using the package manager upgrade functionality
	# ---
	my $this = shift;
	my $addPacks = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $manager = $this->{manager};
	my @zypper  = @{$this->{zypper}};
	my $screenCall = $this->{screenCall};
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return undef;
	}
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		#==========================================
		# Create screen call file
		#------------------------------------------
		$kiwi -> info ("Upgrading image...");
		print $fd "chroot $root smart update\n";
		if (defined $addPacks) {
			my @addonPackages = @{$addPacks};
			print $fd "chroot $root smart upgrade -y && ";
			print $fd "chroot $root smart install -y @addonPackages\n";
		} else {
			print $fd "chroot $root smart upgrade -y\n";
		}
		print $fd "echo \$? > $screenCall.exit\n";
		$fd -> close();
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		#==========================================
		# Create screen call file
		#------------------------------------------
		$kiwi -> info ("Upgrading image...");
		if (defined $addPacks) {
			my @addonPackages = @{$addPacks};
			print $fd "chroot $root @zypper update && ";
			print $fd "chroot $root @zypper install @addonPackages\n";
		} else {
			print $fd "chroot $root @zypper update\n";
		}
		print $fd "echo \$? > $screenCall.exit\n";
		$fd -> close();
	}
	return $this -> setupScreenCall();
}

#==========================================
# setupRootSystem
#------------------------------------------
sub setupRootSystem {
	# ...
	# install the bootstrap system to be able to
	# chroot into this minimal image
	# ---
	my $this   = shift;
	my @packs  = @_;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my $root   = $this->{root};
	my $xml    = $this->{xml};
	my $manager= $this->{manager};
	my @zypper = @{$this->{zypper}};
	my $lock   = $this->{lock};
	my @channelList = @{$this->{channelList}};
	my $screenCall  = $this->{screenCall};
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return undef;
	}
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		if (! $chroot) {
			$this -> checkExclusiveLock();
			$kiwi -> info ("Initializing image system on: $root...");
			my $forceChannels = join (",",@channelList);
			my @installOpts = (
				"-o rpm-root=$root",
				"-o deb-root=$root",
				"-o force-channels=$forceChannels",
				"--explain",
				"--log-level=error",
				"-y"
			);
			#==========================================
			# Add package manager to package list
			#------------------------------------------
			push (@packs,$manager);
			#==========================================
			# Create screen call file
			#------------------------------------------
			print $fd "touch $lock\n";
			print $fd "smart update @channelList\n";
			print $fd "test \$? = 0 && smart install @packs @installOpts\n";
			print $fd "echo \$? > $screenCall.exit\n";
			print $fd "rm -f $root/etc/smart/channels/*\n";
			print $fd "rm -f $lock\n";
		} else {
			$kiwi -> info ("Installing image packages...");
			my $querypack = "smart query '*' --installed --hide-version";
			my @installed = qx ( chroot $root $querypack 2>/dev/null);
			chomp ( @installed );
			my @install   = ();
			foreach my $need (@packs) {
				my $found = 0;
				foreach my $have (@installed) {
					if ($have eq $need) {
						$found = 1; last;
					}
				}
				if (! $found) {
					push @install,$need;
				}
			}
			my @installOpts = (
				"--explain",
				"--log-level=error",
				"-y"
			);
			my $force = $xml -> getRPMForce();
			if (defined $force) {
				push (@installOpts,"-o rpm-force=yes");
			}
			#==========================================
			# Create screen call file
			#------------------------------------------
			print $fd "chroot $root smart update\n";
			print $fd "test \$? = 0 && chroot $root smart install @install ";
			print $fd "@installOpts\n";
			print $fd "echo \$? > $screenCall.exit\n";
		}
		$fd -> close();
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		if (! $chroot) {
			$this -> checkExclusiveLock();
			$kiwi -> info ("Initializing image system on: $root...");
			my $forceChannels = join (",",@channelList);
			my @installOpts = (
				"--catalog $forceChannels",
				"--auto-agree-with-licenses"
			);
			#==========================================
			# Add package manager to package list
			#------------------------------------------
			push (@packs,$manager);
			#==========================================
			# Create screen call file
			#------------------------------------------
			print $fd "touch $lock\n";
			print $fd "@zypper --root $root install @installOpts @packs\n";
			print $fd "echo \$? > $screenCall.exit\n";
			print $fd "rm -f $lock\n";
		} else {
			$kiwi -> info ("Installing image packages...");
			my $querypack = "rpm -qa --qf %'{NAME}\n'";
			my @installed = qx ( chroot $root $querypack 2>/dev/null);
			chomp ( @installed );
			my @install   = ();
			foreach my $need (@packs) {
				my $found = 0;
				foreach my $have (@installed) {
					if ($have eq $need) {
						$found = 1; last;
					}
				}
				if (! $found) {
					push @install,$need;
				}
			}
			print $fd "chroot $root @zypper install @install\n";
			print $fd "echo \$? > $screenCall.exit\n";
		}
		$fd -> close();
	}
	return $this -> setupScreenCall();
}

#==========================================
# resetSource
#------------------------------------------
sub resetSource {
	# ...
	# cleanup source data. In case of any interrupt
	# which means remove all changes made by %source
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %source  = %{$this->{source}};
	my $manager = $this->{manager};
	my @zypper  = @{$this->{zypper}};
	my $lock    = $this->{lock};
	#==========================================
	# check lock
	#------------------------------------------
	$this -> checkExclusiveLock();
	$this -> setLock();
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		foreach my $channel (keys %{$source{public}}) {
			$kiwi -> info ("Removing smart channel: $channel\n");
			qx ( smart channel --remove $channel -y 2>&1 );
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		foreach my $channel (keys %{$source{public}}) {
			$kiwi -> info ("Removing zypper service: $channel\n");
			qx ( bash -c "@zypper service-delete $channel 2>&1" );
		}
	}
	$this -> freeLock();
	return $this;
}

#==========================================
# setupPackageInfo
#------------------------------------------
sub setupPackageInfo {
	# ...
	# check if a given package is installed or not.
	# return the exit code from the call
	# ---
	my $this   = shift;
	my $pack   = shift;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my $root   = $this->{root};
	my $manager= $this->{manager};
	my @zypper = @{$this->{zypper}};
	my $lock   = $this->{lock};
	my $data;
	my $code;
	my $opts;
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		if (! $chroot) {
			$this -> checkExclusiveLock();
			$kiwi -> info ("Checking for package: $pack");
			$this -> setLock();
			$data = qx ( smart query --installed $pack | grep -qi $pack 2>&1 );
			$code = $? >> 8;
			$this -> freeLock();
		} else {
			$kiwi -> info ("Checking for package: $pack");
			$opts = "--installed $pack";
			$data = qx ( chroot $root smart query $opts | grep -qi $pack 2>&1 );
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed  ();
			$kiwi -> error   ("Package $pack is not installed");
			$kiwi -> skipped ();
			return $code;
		}
		$kiwi -> done();
		return $code;
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		my $str = "not installed";
		if (! $chroot) {
			$this -> checkExclusiveLock();
			$kiwi -> info ("Checking for package: $pack");
			$this -> setLock();
			$data = qx ( zypper info $pack | grep -qi $str 2>&1 );
			$code = $? >> 8;
			$this -> freeLock();
		} else {
			$kiwi -> info ("Checking for package: $pack");
			$data = qx ( chroot $root @zypper info $pack | grep -qi $str 2>&1 );
			$code = $? >> 8;
		}
		if ($code == 0) {
			$kiwi -> failed  ();
			$kiwi -> error   ("Package $pack is not installed");
			$kiwi -> skipped ();
			return 1;
		}
		$kiwi -> done();
		return 0;
	}
	return 1;
}

#==========================================
# checkExclusiveLock
#------------------------------------------
sub checkExclusiveLock {
	# ...
	# During very first chroot build phase the package manager
	# requires an exclusive lock. Another kiwi process at that stage
	# will fail so we are waiting until the lock is done
	# ---
	my $this = shift;
	my $lock = $this->{lock};
	my $kiwi = $this->{kiwi};
	if (-f $lock) {
		$kiwi -> info ("Waiting for package lock to disappear...")
	} else {
		return $this;
	}
	while (-f $lock) {
		sleep (5);
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# setLock
#------------------------------------------
sub setLock {
	my $this = shift;
	my $lock = $this->{lock};
	qx ( touch $lock );
}

#==========================================
# freeLock
#------------------------------------------
sub freeLock {
	my $this = shift;
	my $lock = $this->{lock};
	qx ( rm -f $lock );
}

1;
