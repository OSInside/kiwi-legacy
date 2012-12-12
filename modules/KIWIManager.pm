#================
# FILE          : KIWIManager.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
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
use strict;
use warnings;
require Exporter;
use Carp qw (cluck);
use Env;
use FileHandle;
use File::Basename;
use Config::IniFiles;
use KIWILog;
use KIWILocator;
use KIWIQX qw (qxx);

#==========================================
# Exports
#------------------------------------------
our @ISA       = qw (Exporter);
our @EXPORT_OK = qw ();

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
	my $kiwi       = shift;
	my $xml        = shift;
	my $sourceRef  = shift;
	my $root       = shift;
	my $manager    = shift;
	my $targetArch = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $xml) {
		$kiwi -> error  ("Missing XML description pointer");
		$kiwi -> failed ();
		return;
	}
	if (! defined $sourceRef) {
		$kiwi -> error  ("Missing channel description pointer");
		$kiwi -> failed ();
		return;
	}
	my %source = %{$sourceRef};
	if (! defined $root) {
		$kiwi -> error  ("Missing chroot path");
		$kiwi -> failed ();
		return;
	}
	if (! defined $manager) {
		$manager = $xml -> getPackageManager_legacy();
	}
	if (defined $targetArch && $manager ne 'zypper') {
		$kiwi -> warning ("Target architecture not supported for $manager");
		$kiwi -> skipped ();
	}
	my $locator = KIWILocator -> new ($kiwi);
	my $dataDir = "/var/cache/kiwi/$manager";
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
	$this->{dataDir}     = $dataDir;
	$this->{locator}     = $locator;
	$this->{targetArch}  = $targetArch;
	#==========================================
	# Store object data chroot path
	#------------------------------------------
	$this->{kchroot}     = [
		"chroot \"$root\""
	];
	return $this;
}

#==========================================
# switchToChroot
#------------------------------------------
sub switchToChroot {
	my $this = shift;
	$this->{chroot} = 1;
	return 1;
}

#==========================================
# switchToLocal
#------------------------------------------
sub switchToLocal {
	my $this = shift;
	$this->{chroot} = 0;
	return 1;
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
	my $fd = FileHandle -> new();
	my $cd = FileHandle -> new();
	if ((! $fd -> open (">$screenCall")) || (! $cd -> open (">$screenCtrl"))) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create call file: $!");
		$kiwi -> failed ();
		$this -> resetInstallationSource();
		return;
	}
	print $cd "logfile $screenLogs\n";
	print $cd "logfile flush 1\n";
	$cd -> close();
	#==========================================
	# Global exports
	#------------------------------------------
	print $fd "export PBL_SKIP_BOOT_TEST=1"."\n";
	#==========================================
	# Global exports [ proxy setup ]
	#------------------------------------------
	if ($ENV{http_proxy}) {
		print $fd "export http_proxy=\"$ENV{http_proxy}\""."\n";
	}
	if ($ENV{ftp_proxy}) {
		print $fd "export ftp_proxy=\"$ENV{ftp_proxy}\""."\n";
	}
	if ($ENV{https_proxy}) {
		print $fd "export https_proxy=\"$ENV{https_proxy}\""."\n";
	}
	if ($ENV{no_proxy}) {
		print $fd "export no_proxy=\"$ENV{no_proxy}\""."\n";
	}
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
	my $data;
	#==========================================
	# Check log location
	#------------------------------------------
	if ($kiwi -> terminalLogging()) {
		$logs = 0;
	}
	#==========================================
	# activate shell set -x mode
	#------------------------------------------
	my $fd = FileHandle -> new();
	if ($fd -> open ($screenCall)) {
		local $/; $data = <$fd>; $fd -> close();
		if ($fd -> open (">$screenCall")) {
			print $fd "set -x\n";
			print $fd $data;
			$fd -> close();
		}
	}
	qxx (" chmod 755 $screenCall ");
	if ($logs) {
		$kiwi -> closeRootChannel();
	}
	#==========================================
	# run process in screen/terminal session
	#------------------------------------------
	$this->{child} = fork();
	if (! defined $this->{child}) {
		$kiwi -> failed ();
		$kiwi -> error  ("fork failed: $!");
		$kiwi -> failed ();
		return;
	}
	if ($this->{child}) {
		#==========================================
		# wait for the process to finish
		#------------------------------------------
		waitpid $this->{child},0;
		$code = $? >> 8;
		$data = "";
		undef $this->{child};
		#==========================================
		# create exit code and data value if screen
		#------------------------------------------
		if ($logs) {
			$kiwi -> reopenRootChannel();
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
		}
		#==========================================
		# remove call and control files
		#------------------------------------------
		qxx (" rm -f $screenCall* ");
		qxx (" rm -f $screenCtrl ");
	} else {
		#==========================================
		# do the job in the child process
		#------------------------------------------
		if ($logs) {
			if (! exec ("screen -L -D -m -c $screenCtrl $screenCall")) {
				die ("\n*** Couldn't exec screen: $! ***\n");
			}
		} else {
			if (! exec ( $screenCall )) {
				die ("\n*** Couldn't exec shell: $! ***\n");
			}
		}
	}
	#==========================================
	# check exit code from session
	#------------------------------------------
	if ($code != 0) {
		$kiwi -> failed ();
		if (($logs) && ($data)) {
			my @lines = split ("\n",$data);
			@lines = @lines[-10,-9,-8,-7,-6,-5,-4,-3,-2,-1];
			unshift (@lines,"[*** log excerpt follows, screen ***]");
			push    (@lines,"[*** end ***]\n");
			$data = join ("\n",@lines);
			printf STDERR $data;
			$kiwi -> doNorm();
		}
		$this -> resetInstallationSource();
		if ($kiwi -> trace()) {
			$main::BT[$main::TL] = eval {
				Carp::longmess ($main::TT.$main::TL++)
			};
		}
		return;
	}
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupInstallPackages
#------------------------------------------
sub setupInstallPackages {
	# ...
	# create the install packages list from the information
	# of the package types image, xen and vmware. Store
	# the result in the object pointer
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	#==========================================
	# check cached result
	#------------------------------------------
	if (defined $this->{packlist}) {
		return @{$this->{packlist}};
	}
	#==========================================
	# Get image package list
	#------------------------------------------
	my @packList = $xml -> getInstallList_legacy();
	#==========================================
	# Get type specific packages if set
	#------------------------------------------
	my @typeList = $xml -> getTypeSpecificPackageList_legacy();
	if (@typeList) {
		push @packList,@typeList;
	}
	$this->{packlist} = \@packList;
	return @packList;
}

#==========================================
# setupArchives
#------------------------------------------
sub setupArchives {
	# ...
	# install the given tar archives into the
	# root system
	# ---
	my @tars    = @_;
	my $this    = shift @tars;
	my $idesc   = shift @tars;
	my $kiwi    = $this->{kiwi};
	my $chroot  = $this->{chroot};
	my @kchroot = @{$this->{kchroot}};
	my $root    = $this->{root};
	my $screenCall = $this->{screenCall};
	#==========================================
	# check for empty list
	#------------------------------------------
	if (! @tars) {
		return $this;
	}
	#==========================================
	# check for chroot
	#------------------------------------------
	if ($chroot) {
		$kiwi -> error ("Can't access archives in chroot");
		return;
	}
	#==========================================
	# check for origin of image description
	#------------------------------------------
	if (open my $FD, '<', "$idesc/image/main::Prepare") {
		$idesc = <$FD>;
		close $FD;
	}
	#==========================================
	# check for archive files
	#------------------------------------------
	foreach my $tar (@tars) {
		if (! -f "$idesc/$tar") {
			$kiwi -> error ("Can't find $idesc/$tar");
			return;
		}
	}
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return;
	}
	$kiwi -> info ("Installing raw archives in: $root...");
	#==========================================
	# Create screen call file
	#------------------------------------------
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "for i in @tars;do\n";
	print $fd "   tar -tf $idesc/\$i";
	print $fd ' | grep -v /$ ';
	print $fd ">> $root/bootincluded_archives.filelist\n";
	print $fd "   if ! tar -C $root -xvf $idesc/\$i;then\n";
	print $fd "       ECODE=\$?\n";
	print $fd "       echo \$ECODE > $screenCall.exit\n";
	print $fd "       exit \$ECODE\n";
	print $fd "   fi\n";
	print $fd "done\n";
	print $fd "echo 0 > $screenCall.exit\n";
	print $fd "exit 0\n";
	$fd -> close();
	#==========================================
	# Call it
	#------------------------------------------
	return $this -> setupScreenCall();
}

#==========================================
# setupPackageKeys
#------------------------------------------
sub setupPackageKeys {
	# ...
	# import package keys to avoid warnings on installation
	# of packages. This is an rpm only task and needs to be
	# enhanced for non rpm based packages
	# ---
	my $this = shift;
	my $root = $this->{root};
	my $kiwi = $this->{kiwi};
	my $data;
	my $code;
	#==========================================
	# check for rpm binary
	#------------------------------------------
	if (! -x "/bin/rpm") {
		# operates on rpm only
		return $this;
	}
	#==========================================
	# check build key and gpg
	#------------------------------------------	
	$kiwi -> info ("Importing build keys...");
	my $dumsigsExec = '/usr/lib/rpm/gnupg/dumpsigs';
	my $keyringFile = '/usr/lib/rpm/gnupg/pubring.gpg';
	my $keydir      = '/usr/lib/rpm/gnupg/keys';
	my $sigs        = "$root/rpm-sigs";
	if (! -d $keydir) {
		if (! -x $dumsigsExec) {
			$kiwi -> skipped ();
			$kiwi -> warning ("Can't find dumpsigs on host system");
			$kiwi -> skipped ();
			return $this;
		}
		if (! -f $keyringFile) {
			$kiwi -> skipped ();
			$kiwi -> warning ("Can't find build keys on host system");
			$kiwi -> skipped ();
			return $this;
		}
		my $dump = $dumsigsExec . ' ' . $keyringFile;
		$data = qxx ("mkdir -p $sigs && cd $sigs && $dump 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> skipped ();
			$kiwi -> error  ("Can't dump pubkeys: $data");
			$kiwi -> failed ();
			qxx ("rm -rf $sigs");
			return $this;
		}
	} else {
		$sigs = $keydir;
	}
	$data.= qxx ("rpm -r $root --import $sigs/gpg-pubke* 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> skipped ();
		$kiwi -> error  ("Can't import pubkeys: $data");
		$kiwi -> failed ();
		if (-d "$root/rpm-sigs") {
			qxx ("rm -rf $root/rpm-sigs");
		}
		return $this;
	}
	$kiwi -> done();
	if (-d "$root/rpm-sigs") {
		qxx ("rm -rf $root/rpm-sigs");
	}
	return $this;
}

#==========================================
# provideMediaLicense
#------------------------------------------
sub provideMediaLicense {
	# ...
	# walk through the repository list and search for a
	# license.tar.gz file on the media. If found the tarball
	# will be downloaded from the media and included into
	# the image
	# ---
	my $this     = shift;
	my $kiwi     = $this->{kiwi};
	my %source   = %{$this->{source}};
	my $root     = $this->{root};
	my @repolist = ();
	my $license  = "license.tar.gz";
	#=================================================
	# use only repos which set prefer-license to true
	#-------------------------------------------------
	foreach my $alias (keys %{$source{public}}) {
		if ($source{$alias}{license}) {
			push @repolist,$alias;
		}
	}
	#=================================================
	# use all repos if none has set prefer-license
	#-------------------------------------------------
	if (! @repolist) {
		foreach my $alias (keys %{$source{public}}) {
			push @repolist,$alias;
		}
	}
	# /.../
	# walk through selected repolist. Note if more than
	# one repo is searched the selected repo doesn't have
	# to be the first one according to the XML description
	# ----
	foreach my $alias (@repolist) {
		my $repo = $alias;
		foreach my $opt (@{$source{public}{$alias}}) {
			next if ! $opt;
			if ($opt =~ /(.*?)=(.*)/) {
				my $key = $1;
				my $val = $2;
				if (($key eq "baseurl") || ($key eq "path")) {
					if ($val =~ /^'\//) {
						$val =~ s/^'(.*)'$/"file:\/\/$1"/
					}
					$repo = $val;
				}
			}
		}
		KIWIXML::getInstSourceFile (
			$kiwi,$repo."/".$license,$root."/".$license
		);
		last if -e $root."/".$license;
	}
	return $this;
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
	my $kiwi = $this->{kiwi};
	$kiwi -> loginfo ("Set package manager lock\n");
	qxx (" touch $lock ");
	return 1;
}

#==========================================
# freeLock
#------------------------------------------
sub freeLock {
	my $this = shift;
	my $lock = $this->{lock};
	my $kiwi = $this->{kiwi};
	$kiwi -> loginfo ("Release package manager lock\n");
	qxx (" rm -f $lock ");
	return 1;
}

#==========================================
# cleanChild
#------------------------------------------
sub cleanChild {
	my $this = shift;
	$this -> freeLock();
	if (defined $this->{child}) {
		kill 15,$this->{child};
	}
	return $this;
}

#==========================================
# removeCacheDir
#------------------------------------------
sub removeCacheDir {
	my $this    = shift;
	my $dataDir = $this->{dataDir};
	my $kiwi    = $this->{kiwi};
	my $config  = dirname ($dataDir);
	$this -> cleanChild();
	$kiwi -> loginfo ("Removing cache directory: $dataDir\n");
	qxx ("rm -rf $dataDir");
	qxx ("rm -rf $config/config");
	return $this;
}

#==========================================
# cleanupRPMDatabase
#------------------------------------------
sub cleanupRPMDatabase {
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my @kchroot = @{$this->{kchroot}};
	my $root    = $this->{root};
	my $data;
	my $code;
	#==========================================
	# check for rpm binary
	#------------------------------------------
	if (! -e "$root/bin/rpm") {
		return $this;
	}
	#==========================================
	# try to initialize rpm database
	#------------------------------------------
	$data = qxx ("@kchroot /bin/rpm --initdb &>/dev/null");
	$code = $? >> 8;
	#==========================================
	# try to rebuild DB on failed init
	#------------------------------------------
	if ($code != 0) {
		$kiwi -> info ('Rebuild RPM package db...');
		my $nameIndex = "$root/var/lib/rpm/Name";
		my $packIndex = "$root/var/lib/rpm/Packages";
		if (! -x "/usr/bin/db_dump") {
			$kiwi -> failed ();
			$kiwi -> error ("db_dump tool required for rpm db rebuild\n");
			return;
		}
		if (! -x "/usr/bin/db45_load") {
			$kiwi -> failed ();
			$kiwi -> error ("db45_load tool required for rpm db rebuild\n");
			return;
		}
		qxx ('mv '.$packIndex.' '.$packIndex.'.bak');
		qxx ('mv '.$nameIndex.' '.$nameIndex.'.bak');
		qxx ('db_dump '.$packIndex.'.bak | db45_load '.$packIndex);
		qxx ('db_dump '.$nameIndex.'.bak | db45_load '.$nameIndex);
		qxx ('rm -f '.$packIndex.'.bak');
		qxx ('rm -f '.$nameIndex.'.bak');
		$data = qxx ("@kchroot /bin/rpm --rebuilddb 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error (
				"Most likely we encountered an RPM version incompatibility\n"
			);
			$kiwi -> error ("rpm: $data");
			return;
		}
		$kiwi -> done();
	}
	return $this;
}

#==========================================
# rpmLibs
#------------------------------------------
sub rpmLibs {
	# ...
	# try to fix rpm version incompatibility
	# ---
	my $this   = shift;
	my @kchroot= @{$this->{kchroot}};
	#==========================================
	# cleanup baselibs
	#------------------------------------------
	if (! $this -> cleanupRPMDatabase()) {
		return;
	}
	qxx ("@kchroot ldconfig 2>&1");
	return $this;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this   = shift;
	my $meta   = $this->{dataDir};
	my $zypperConf = "$meta/zypper.conf.$$";
	my $zyppConf   = "$meta/zypp.conf.$$";
	qxx ("rm -f $zypperConf $zyppConf");
	return 1;
}

1;
