#================
# FILE          : KIWIGlobals.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to store variables and
#               : functions which needs to be available globally
#               :
# STATUS        : Development
#----------------
package KIWIGlobals;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use KIWILocator;
use KIWILog;
use KIWIQX qw (qxx);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIGlobals object which is used to
	# store global values
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
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $arch = qxx ("uname -m");
	chomp $arch;
	#==========================================
	# Globals (generic)
	#------------------------------------------
	my %data;
	$data{Version}         = "5.03.57";
	$data{Publisher}       = "SUSE LINUX Products GmbH";
	$data{Preparer}        = "KIWI - http://kiwi.berlios.de";
	$data{ConfigName}      = "config.xml";
	$data{Partitioner}     = "parted";
	$data{FSInodeRatio}    = 16384;
	$data{FSMinInodes}     = 20000;
	$data{FSInodeSize}     = 256;
	$data{DiskStartSector} = 2048;
	$data{DiskSectorSize}  = 512;
	$data{DiskAlignment}   = 4096;
	$data{SnapshotChunk}   = 4096;
	$data{SnapshotCount}   = "5G";
	$data{OverlayRootTree} = 0;
	#============================================
	# Read .kiwirc
	#--------------------------------------------
	my $file;
	if (-f '.kiwirc') {
		$file = '.kiwirc';
	}
	elsif (($ENV{'HOME'}) && (-f $ENV{'HOME'}.'/.kiwirc')) {
		$file = "$ENV{'HOME'}/.kiwirc";
	}
	if ($file) {
		if (! do $file) {
			$kiwi -> warning ("Invalid $file file...");
			$kiwi -> skipped ();
		} else {
			$kiwi -> info ("Using $file");
			$kiwi -> done ();
		}
	}
	## no critic
	no strict 'vars';
	$data{BasePath}      = $BasePath;      # configurable base kiwi path
	$data{Gzip}          = $Gzip;          # configurable gzip command
	$data{LogServerPort} = $LogServerPort; # configurable log server port
	$data{LuksCipher}    = $LuksCipher;    # configurable luks passphrase
	$data{System}        = $System;        # configurable base image desc. path
	if ( ! defined $BasePath ) {
		$data{BasePath} = "/usr/share/kiwi";
	}
	if (! defined $Gzip) {
		$data{Gzip} = "gzip -9";
	}
	if (! defined $LogServerPort) {
		$data{LogServerPort} = "off";
	}
	if (! defined $System) {
		$data{System} = $data{BasePath}."/image";
	}
	if (! defined $LuksCipher) {
		# empty
	}
	use strict 'vars';
	## use critic
	my $BasePath = $data{BasePath};
	#==========================================
	# Globals (path names)
	#------------------------------------------
	$data{Tools}     = $BasePath."/tools";
	$data{Schema}    = $BasePath."/modules/KIWISchema.rng";
	$data{SchemaTST} = $BasePath."/modules/KIWISchemaTest.rng";
	$data{KConfig}   = $BasePath."/modules/KIWIConfig.sh";
	$data{KMigrate}  = $BasePath."/modules/KIWIMigrate.txt";
	$data{KRegion}   = $BasePath."/modules/KIWIEC2Region.txt";
	$data{KMigraCSS} = $BasePath."/modules/KIWIMigrate.tgz";
	$data{KSplit}    = $BasePath."/modules/KIWISplit.txt";
	$data{KStrip}    = $BasePath."/modules/KIWIConfig.txt";
	$data{repoURI}   = $BasePath."/modules/KIWIURL.txt";
	$data{Revision}  = $BasePath."/.revision";
	$data{TestBase}  = $BasePath."/tests";
	$data{SchemaCVT} = $BasePath."/xsl/master.xsl";
	$data{Pretty}    = $BasePath."/xsl/print.xsl";
	#==========================================
	# Globals (Supported filesystem names)
	#------------------------------------------
	my %KnownFS;
	my $locator = KIWILocator -> new();
	$KnownFS{ext4}{tool}      = $locator -> getExecPath("mkfs.ext4");
	$KnownFS{ext3}{tool}      = $locator -> getExecPath("mkfs.ext3");
	$KnownFS{ext2}{tool}      = $locator -> getExecPath("mkfs.ext2");
	$KnownFS{squashfs}{tool}  = $locator -> getExecPath("mksquashfs");
	$KnownFS{clicfs}{tool}    = $locator -> getExecPath("mkclicfs");
	$KnownFS{clic}{tool}      = $locator -> getExecPath("mkclicfs");
	$KnownFS{compressed}{tool}= $locator -> getExecPath("mksquashfs");
	$KnownFS{reiserfs}{tool}  = $locator -> getExecPath("mkreiserfs");
	$KnownFS{btrfs}{tool}     = $locator -> getExecPath("mkfs.btrfs");
	$KnownFS{xfs}{tool}       = $locator -> getExecPath("mkfs.xfs");
	$KnownFS{cpio}{tool}      = $locator -> getExecPath("cpio");
	$KnownFS{ext3}{ro}        = 0;
	$KnownFS{ext4}{ro}        = 0;
	$KnownFS{ext2}{ro}        = 0;
	$KnownFS{squashfs}{ro}    = 1;
	$KnownFS{clicfs}{ro}      = 1;
	$KnownFS{clic}{ro}        = 1;
	$KnownFS{compressed}{ro}  = 1;
	$KnownFS{reiserfs}{ro}    = 0;
	$KnownFS{btrfs}{ro}       = 0;
	$KnownFS{xfs}{ro}         = 0;
	$KnownFS{cpio}{ro}        = 0;
	$data{KnownFS} = \%KnownFS;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{data} = \%data;
	$this->{kiwi} = $kiwi;
	$this->{UmountStack} = [];
	return $this;
}

#==========================================
# getGlobals
#------------------------------------------
sub getGlobals {
	my $this = shift;
	return $this->{data};
}

#==========================================
# setGlobals
#------------------------------------------
sub setGlobals {
	my $this = shift;
	my $key  = shift;
	my $val  = shift;
	$this->{data}->{$key} = $val;
	return $this;
}

#============================================
# createDirInteractive
#--------------------------------------------
sub createDirInteractive {
	my $this      = shift;
	my $targetDir = shift;
	my $defaultAnswer = shift;
	my $kiwi = $this->{kiwi};
	if (! -d $targetDir) {
		my $prefix = $kiwi -> getPrefix (1);
		my $answer = (defined $defaultAnswer) ? "yes" : "unknown";
		$kiwi -> info ("Destination: $targetDir doesn't exist\n");
		while ($answer !~ /^yes$|^no$/) {
			print STDERR $prefix,
				"Would you like kiwi to create it [yes/no] ? ";
			chomp ($answer = <>);
		}
		if ($answer eq "yes") {
			qxx ("mkdir -p $targetDir");
			return 1;
		}
	} else {
		# Directory exists
		return 1;
	}
	# Directory does not exist and user did
	# not request dir creation.
	return;
}

#==========================================
# checkFSOptions
#------------------------------------------
sub checkFSOptions {
	# /.../
	# checks the $FS* option values and build an option
	# string for the relevant filesystems
	# ---
	my $this            = shift;
	my $FSBlockSize     = shift;
	my $FSInodeSize     = shift;
	my $FSInodeRatio    = shift;
	my $FSJournalSize   = shift;
	my $FSMaxMountCount = shift;
	my $FSCheckInterval = shift;
	my $kiwi            = $this->{kiwi};
	my %KnownFS         = %{$this->{data}->{KnownFS}};
	my %result          = ();
	my $fs_maxmountcount;
	my $fs_checkinterval;
	foreach my $fs (keys %KnownFS) {
		my $blocksize;   # block size in bytes
		my $journalsize; # journal size in MB (ext) or blocks (reiser)
		my $inodesize;   # inode size in bytes (ext only)
		my $inoderatio;  # bytes/inode ratio
		my $fsfeature;   # filesystem features (ext only)
		SWITCH: for ($fs) {
			#==========================================
			# EXT2-4
			#------------------------------------------
			/ext[432]/   && do {
				if ($FSBlockSize)   {$blocksize   = "-b $FSBlockSize"}
				if (($FSInodeSize) && ($FSInodeSize != 256)) {
					$inodesize = "-I $FSInodeSize"
				}
				if ($FSInodeRatio)  {$inoderatio  = "-i $FSInodeRatio"}
				if ($FSJournalSize) {$journalsize = "-J size=$FSJournalSize"}
				if ($FSMaxMountCount) {
					$fs_maxmountcount = " -c $FSMaxMountCount";
				}
				if ($FSCheckInterval) {
					$fs_checkinterval = " -i $FSCheckInterval";
				}
				$fsfeature = "-F -O resize_inode";
				last SWITCH;
			};
			#==========================================
			# reiserfs
			#------------------------------------------
			/reiserfs/  && do {
				if ($FSBlockSize)   {$blocksize   = "-b $FSBlockSize"}
				if ($FSJournalSize) {$journalsize = "-s $FSJournalSize"}
				last SWITCH;
			};
			# no options for this filesystem...
		};
		if (defined $inodesize) {
			$result{$fs} .= $inodesize." ";
		}
		if (defined $inoderatio) {
			$result{$fs} .= $inoderatio." ";
		}
		if (defined $blocksize) {
			$result{$fs} .= $blocksize." ";
		}
		if (defined $journalsize) {
			$result{$fs} .= $journalsize." ";
		}
		if (defined $fsfeature) {
			$result{$fs} .= $fsfeature." ";
		}
	}
	if ($fs_maxmountcount || $fs_checkinterval) {
		$result{extfstune} = "$fs_maxmountcount$fs_checkinterval";
	}
	return %result;
}

#==========================================
# getMountDev
#------------------------------------------
sub getMountDevice {
	my $this = shift;
	return $this->{mountdev};
}

#==========================================
# isDisk
#------------------------------------------
sub isDisk {
	my $this = shift;
	if ($this->{isdisk}) {
		return $this->{isdisk};
	} else {
		return 0;
	}
}

#==========================================
# mount
#------------------------------------------
sub mount {
	# /.../
	# implements a generic mount function for all
	# supported file system/image types
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $source = shift;
	my $dest   = shift;
	my $salt   = int (rand(20));
	my $cipher = $this->{data}->{LuksCipher};
	my @UmountStack = @{$this->{UmountStack}};
	my $status;
	my $result;
	#==========================================
	# Check for DISK file / device
	#------------------------------------------
	if ((-f $source) || (-b $source)) {
		my $boot = "'boot sector'";
		$status= qxx (
			"dd if=$source bs=512 count=1 2>/dev/null | file - | grep -q $boot"
		);
		$result= $? >> 8;
		if ($result == 0) {
			$this->{isdisk} = 1;
			if (-b $source) {
				my $devcopy = $source;
				my $lastc = chop $devcopy;
				if ($lastc =~ /\d/) {
					$source .= "p";
				}
				if (! -b $source."2") {
					$source .= "1";
				} else {
					$source .= "2";
				}
			} else {
				$status = qxx ("/sbin/losetup -f --show $source 2>&1");
				chomp $status;
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error  (
						"Couldn't loop bind disk file: $status"
					);
					$kiwi -> failed ();
					$this -> umount();
					return;
				}
				my $loop = $status;
				push @UmountStack,"losetup -d $loop";
				$this->{UmountStack} = \@UmountStack;
				$status = qxx ("kpartx -a $loop 2>&1");
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error (
						"Couldn't loop bind disk partition(s): $status"
					);
					$kiwi -> failed (); umount();
					return;
				}
				push @UmountStack,"kpartx -d $loop";
				$this->{UmountStack} = \@UmountStack;
				$loop =~ s/\/dev\///;
				$source = "/dev/mapper/".$loop."p2";
				if (! -b $source) {
					$source = "/dev/mapper/".$loop."p1";
				}
			}
			if (! -b $source) {
				$kiwi -> error ("No such block device $source");
				$kiwi -> failed (); umount();
				return;
			}
		}
	}
	#==========================================
	# Check source filesystem
	#------------------------------------------
	my %fsattr = $this -> checkFileSystem ($source);
	my $type   = $fsattr{type};
	if (! %fsattr) {
		$kiwi -> error  ("Couldn't detect filesystem on: $source");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Check for LUKS extension
	#------------------------------------------
	if ($type eq "luks") {
		if (-f $source) {
			$status = qxx ("/sbin/losetup -f --show $source 2>&1");
			chomp $status;
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> error  ("Couldn't loop bind logical extend: $status");
				$kiwi -> failed ();
				$this -> umount();
				return;
			}
			$source = $status;
			push @UmountStack,"losetup -d $source";
			$this->{UmountStack} = \@UmountStack;
		}
		if ($cipher) {
			$status = qxx (
				"echo $cipher | cryptsetup luksOpen $source luks-$salt 2>&1"
			);
		} else {
			$status = qxx ("cryptsetup luksOpen $source luks-$salt 2>&1");
		}
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Couldn't open luks device: $status");
			$kiwi -> failed ();
			$this -> umount();
			return;
		}
		$source = "/dev/mapper/luks-".$salt;
		push @UmountStack,"cryptsetup luksClose luks-$salt";
		$this->{UmountStack} = \@UmountStack;
	}
	#==========================================
	# Mount device or loop mount file
	#------------------------------------------
	if ((-f $source) && ($type ne "clicfs")) {
		$status = qxx ("mount -o loop $source $dest 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount $source to: $dest: $status");
			$kiwi -> failed ();
			$this -> umount();
			return;
		}
	} else {
		if ($type eq "clicfs") {
			$status = qxx ("clicfs -m 512 $source $dest 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx ("resize2fs $dest/fsdata.ext3 2>&1");
				$result = $? >> 8;
			}
		} else {
			$status = qxx ("mount $source $dest 2>&1");
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> error ("Failed to mount $source to: $dest: $status");
			$kiwi -> failed ();
			$this -> umount();
			return;
		}
	}
	push @UmountStack,"umount $dest";
	$this->{UmountStack} = \@UmountStack;
	#==========================================
	# Post mount actions
	#------------------------------------------
	if (-f $dest."/fsdata.ext3") {
		$source = $dest."/fsdata.ext3";
		$status = qxx ("mount -o loop $source $dest 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount $source to: $dest: $status");
			$kiwi -> failed ();
			$this -> umount();
			return;
		}
		push @UmountStack,"umount $dest";
		$this->{UmountStack} = \@UmountStack;
	}
	$this->{mountdev} = $source;
	return $dest;
}

#==========================================
# umount
#------------------------------------------
sub umount {
	# /.../
	# implements an umount function for filesystems mounted
	# via main::mount(). The function walks through the
	# contents of the UmountStack list
	# ---
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $stack = $this->{UmountStack};
	my $status;
	my $result;
	if (! $stack) {
		return;
	}
	qxx ("sync");
	my @UmountStack = @{$stack};
	foreach my $cmd (reverse @UmountStack) {
		$status = qxx ("$cmd 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> warning ("UmountStack failed: $cmd: $status\n");
		}
	}
	$this->{UmountStack} = [];
	return;
}

#==========================================
# isize
#------------------------------------------
sub isize {
	# /.../
	# implements a size function like the -s operator
	# but also works for block specials using blockdev
	# ---
	my $this   = shift;
	my $target = shift;
	my $kiwi   = $this->{kiwi};
	if (! defined $target) {
		return 0;
	}
	if (-b $target) {
		my $size = qxx ("blockdev --getsize64 $target 2>&1");
		my $code = $? >> 8;
		if ($code == 0) {
			chomp  $size;
			return $size;
		}
	} elsif (-f $target) {
		return -s $target;
	}
	return 0;
}

#==========================================
# generateBuildImageName
#------------------------------------------
sub generateBuildImageName {
	# ...
	# Generate a name for the build image based on information configured
	# in the config.xml file and provided parameters
	# ---
	my $this      = shift;
	my $xml       = shift;
	my $separator = shift;
	my $extension = shift;
	my $arch = qxx ("uname -m"); chomp ( $arch );
	$arch = ".$arch";
	if (! defined $separator) {
		$separator = "-";
	}
	my $name = $xml -> getImageName();
	my $iver = $xml -> getImageVersion();
	if (defined $extension) {
		$name = $name.$extension.$arch.$separator.$iver;
	} else {
		$name = $name.$arch.$separator.$iver;
	}
	chomp  $name;
	return $name;
}

#==========================================
# getMBRDiskLabel
#------------------------------------------
sub getMBRDiskLabel {
	# ...
	# set the mbrid to either the value given at the
	# commandline or a random 4byte MBR disk label ID
	# ---
	my $this  = shift;
	my $MBRID = shift;
	my $range = 0xfe;
	if (defined $MBRID) {
		return $MBRID;
	} else {
		my @bytes;
		for (my $i=0;$i<4;$i++) {
			$bytes[$i] = 1 + int(rand($range));
			redo if $bytes[0] <= 0xf;
		}
		my $nid = sprintf ("0x%02x%02x%02x%02x",
			$bytes[0],$bytes[1],$bytes[2],$bytes[3]
		);
		return $nid;
	}
}

#==========================================
# checkFileSystem
#------------------------------------------
sub checkFileSystem {
	# /.../
	# checks attributes of the given filesystem(s) and returns
	# a summary hash containing the following information
	# ---
	# $filesystem{hastool}  --> has the tool to create the filesystem
	# $filesystem{readonly} --> is a readonly filesystem
	# $filesystem{type}     --> what filesystem type is this
	# ---
	my $this    = shift;
	my $fs      = shift;
	my $kiwi    = $this->{kiwi};
	my %KnownFS = %{$this->{data}->{KnownFS}};
	my %result  = ();
	if (defined $KnownFS{$fs}) {
		#==========================================
		# got a known filesystem type
		#------------------------------------------
		$result{type}     = $fs;
		$result{readonly} = $KnownFS{$fs}{ro};
		$result{hastool}  = 0;
		if (($KnownFS{$fs}{tool}) && (-x $KnownFS{$fs}{tool})) {
			$result{hastool} = 1;
		}
	} else {
		#==========================================
		# got a file, block special or something
		#------------------------------------------
		if (-e $fs) {
			my $data = qxx ("dd if=$fs bs=128k count=1 2>/dev/null | file -");
			my $code = $? >> 8;
			my $type;
			if ($code != 0) {
				if ($main::kiwi -> trace()) {
					$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
				}
				return;
			}
			SWITCH: for ($data) {
				/ext4/      && do {
					$type = "ext4";
					last SWITCH;
				};
				/ext3/      && do {
					$type = "ext3";
					last SWITCH;
				};
				/ext2/      && do {
					$type = "ext2";
					last SWITCH;
				};
				/ReiserFS/  && do {
					$type = "reiserfs";
					last SWITCH;
				};
				/BTRFS/     && do {
					$type = "btrfs";
					last SWITCH;
				};
				/Squashfs/  && do {
					$type = "squashfs";
					last SWITCH;
				};
				/LUKS/      && do {
					$type = "luks";
					last SWITCH;
				};
				/XFS/     && do {
					$type = "xfs";
					last SWITCH;
				};
				# unknown filesystem type check clicfs...
				$data = qxx (
					"dd if=$fs bs=128k count=1 2>/dev/null | grep -q CLIC"
				);
				$code = $? >> 8;
				if ($code == 0) {
					$type = "clicfs";
					last SWITCH;
				}
				# unknown filesystem type use auto...
				$type = "auto";
			};
			$result{type}     = $type;
			$result{readonly} = $KnownFS{$type}{ro};
			$result{hastool}  = 0;
			if (defined $KnownFS{$type}{tool}) {
				if (-x $KnownFS{$type}{tool}) {
					$result{hastool} = 1;
				}
			}
		} else {
			if ($main::kiwi -> trace()) {
				$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
			}
			return ();
		}
	}
	return %result;
}

#==========================================
# setupBTRFSSubVolumes
#------------------------------------------
sub setupBTRFSSubVolumes {
	# /.../
	# create a btrfs subvolume setup as suggested
	# by the community and compatible to a standard
	# installation
	# ----
	#
	my $this = shift;
	my $path = shift;
	my $kiwi = $this->{kiwi};
	my @subvol = (
		'tmp','opt','srv','var','var/crash',
		'var/spool','var/log','var/run','var/tmp'
	);
	my $data = qxx ('btrfs subvolume create '.$path.'/@ 2>&1');
	my $code = $? >> 8;
	if ($code == 0) {
		my $rootID=0;
		$data = qxx ("btrfs subvolume list $path 2>&1");
		if ($data =~ /^ID (\d+) /) {
			$rootID=$1;
		}
		if ($rootID) {
			$data = qxx (
				"btrfs subvolume set-default $rootID $path 2>&1"
			);
			$code = $? >> 8;
		} else {
			$code = 1;
		}
	}
	if ($code == 0) {
		foreach my $vol (@subvol) {
		$data = qxx (
			'btrfs subvolume create '.$path.'/@/'.$vol.' 2>&1'
		);
		$code = $? >> 8;
			last if $code != 0;
		}
	}
	if ($code != 0) {
		$kiwi -> error ("Failed to create btrfs subvolume: $data\n");
		$kiwi -> failed();
		$this -> cleanLuks();
		return;
	}
	$path.='/@';
	return $path;
}

#==========================================
# umountSystemFileSystems
#------------------------------------------
sub umountSystemFileSystems {
	# /.../
	# umount system filesystems like proc within the given
	# root tree. This is called after a custom script call
	# to cleanup the environment
	# ----
	my $this = shift;
	my $root = shift;
	my @sysfs= ("/proc");
	if (! -d $root) {
		return;
	}
	foreach my $path (@sysfs) {
		qxx ("chroot $root umount -l $path 2>&1");
	}
	return $this;
}

#==========================================
# callContained
#------------------------------------------
sub callContained {
	# /.../
	# call the given program in a contained way by using
	# a lxc container or a simple chroot
	# ----
	my $this = shift;
	my $root = shift;
	my $prog = shift;
	my $kiwi = $this->{kiwi};
	my $data;
	my $code;
	my $FD;
	if (! -d $root) {
		$kiwi -> error  ("Can't find root directory: $root");
		$kiwi -> failed ();
		return;
	}
	if (! -e $root."/".$prog) {
		$kiwi -> error  ("Can't find program $root/$prog");
		$kiwi -> failed ();
		return;
	}
	my $locator = KIWILocator -> new($kiwi);
	my $lxcexec = $locator -> getExecPath('lxc-execute');
	my $lxcbase = $root."/usr/lib/lxc/";
	if (-d "/usr/lib64") {
		$lxcbase = $root."/usr/lib64/lxc/";
	}
	my $lxcinit = $lxcbase."lxc-init";
	my $legacy  = 0;
	if (! $lxcexec ) {
		#==========================================
		# no lxc installed used chroot
		#------------------------------------------
		$kiwi -> loginfo ("lxc not installed\n");
		$legacy = 1;
	} else {
		#==========================================
		# check for lxc in the unpacked tree
		#------------------------------------------
		if (-e $lxcinit) {
			qxx ("mv $lxcinit $lxcinit.orig 2>&1");
		}
		#==========================================
		# create lxc config file
		#------------------------------------------
		if (! open ($FD,">","$root/config.lxc")) {
			$kiwi -> loginfo ("Couldn't create lxc config file: $!\n");
			$legacy = 1;
		} else {
			print $FD "lxc.utsname = kiwi-contained-script"."\n";
			print $FD "lxc.rootfs  = $root"."\n";
			close $FD;
			#==========================================
			# check if lxc works
			#------------------------------------------
			if (! -d $lxcbase) {
				qxx ("mkdir -p $lxcbase");
			}
			if (! open ($FD, ">", $lxcinit)) {
				$kiwi -> loginfo ("Couldn't create lxc-init test: $!\n");
				$legacy = 1;
			} else {
				print $FD "#! /bin/bash"."\n";
				print $FD "echo OK"."\n";
				print $FD "exit 0"."\n";
				close $FD;
				$data = qxx ("chmod u+x $lxcinit 2>&1");
				$data = qxx (
					"lxc-execute -n kiwi -f $root/config.lxc true 2>&1"
				);
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> loginfo ("Failed to execute lxc: $data\n");
					$legacy = 1;
				} else {
					#==========================================
					# call via lxc
					#------------------------------------------
					$data = qxx ("mv $root/$prog $lxcinit 2>&1");
					$data = qxx (
						"lxc-execute -n kiwi -f $root/config.lxc true 2>&1"
					);
					$code = $? >> 8;
				}
			}
		}
	}
	if ($legacy) {
		#==========================================
		# cleanup lxc
		#------------------------------------------
		$kiwi -> loginfo ("Falling back to chroot method\n");
		if (-e "$root/config.lxc") {
			qxx ("rm -f $root/config.lxc 2>&1");
		}
		if (($lxcinit) && (-e "$root/$lxcinit")) {
			qxx ("rm -f $root/$lxcinit 2>&1");
		}
		if (($lxcinit) && (-e "$lxcinit.orig")) {
			qxx ("mv $lxcinit.orig $lxcinit 2>&1");
		}
		#==========================================
		# call in chroot
		#------------------------------------------
		$data = qxx ("chroot $root $prog 2>&1 ");
		$code = $? >> 8;
		$this -> umountSystemFileSystems ($root);
	}
	return ($code,$data);
}

1;
