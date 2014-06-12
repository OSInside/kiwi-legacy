#================
# FILE          : KIWIGlobals.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use File::Basename;
use Config::IniFiles;
use LWP;
#==========================================
# KIWI Modules
#------------------------------------------
require KIWILocator;
require KIWILog;
require KIWIQX;
require KIWITrace;
#==========================================
# Singleton class
#------------------------------------------
use base qw /Class::Singleton/;

#==========================================
# getArch
#------------------------------------------
sub getArch {
	# ...
	# Return the architecture setting of the build environment
	# ---
	my $locator = KIWILocator -> instance();
	my $uname_exec = $locator -> getExecPath("uname");
	return if ! $uname_exec;
	my $arch = KIWIQX::qxx ("$uname_exec -m");
	chomp $arch;
	return $arch;
}

#==========================================
# getKiwiConfig
#------------------------------------------
sub getKiwiConfig {
	# ...
	# Return a hash of all the KIWI configuration data
	# ---
	my $this = shift;
	return $this->{data};
}

#==========================================
# setKiwiConfigData
#------------------------------------------
sub setKiwiConfigData {
	# ...
	# Set a configuration data key value pair
	# ---
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
			KIWIQX::qxx ("mkdir -p $targetDir");
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
# getMountDev
#------------------------------------------
sub getMountDevice {
	my $this = shift;
	return $this->{mountdev};
}

#==========================================
# getMountLVMGroup
#------------------------------------------
sub getMountLVMGroup {
	my $this = shift;
	return $this->{lvmgroup}
}

#==========================================
# isMountLVM
#------------------------------------------
sub isMountLVM {
	my $this = shift;
	return $this->{lvm};
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
	my $source = shift;
	my $dest   = shift;
	my $opts   = shift;
	my $kiwi   = $this->{kiwi};
	my $salt   = int (rand(20));
	my $cipher = $this->{data}->{LuksCipher};
	my @UmountStack = @{$this->{UmountStack}};
	my $status;
	my $result;
	my %fsattr;
	my $type;
	#==========================================
	# Check source
	#------------------------------------------
	if (! $source) {
		$kiwi -> error ("No mount source specified:");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Check for DISK file / device
	#------------------------------------------
	if ((-f $source) || (-b $source)) {
		$this->{isdisk} = 0;
		$status = KIWIQX::qxx ("blkid $source -s TYPE -o value 2>/dev/null");
		if (! $status) {
			# no blkid filesystem id, do another filesystem check
			%fsattr = $this -> checkFileSystem ($source);
			$type   = $fsattr{type};
			if (($type) && ($type ne "auto")) {
				$status = $type;
			}
		}
		if (! $status) {
			# no filesystem detected, check for PTTYPE
			$status= KIWIQX::qxx (
				"blkid $source -s PTTYPE -o value 2>/dev/null"
			);
			if ($status) {
				# got partition table ID, handle source as disk
				$this->{isdisk} = 1;
			} else {
				# got no information about the type of this source
				# we assume this is a disk
				$this->{isdisk} = 1;
			}
		}
		if ($this->{isdisk}) {
			if (-b $source) {
				my $pdev = $this -> getPartDevice ($source,2);
				if (! -b $pdev) {
					$pdev = $this -> getPartDevice ($source,1);
				}
				$source = $pdev;
			} else {
				$status = KIWIQX::qxx ("/sbin/losetup -f --show $source 2>&1");
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
				$status = KIWIQX::qxx ("kpartx -sa $loop 2>&1");
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error (
						"Couldn't loop bind disk partition(s): $status"
					);
					$kiwi -> failed ();
					$this -> umount();
					return;
				}
				# wait for the mapping to finish
				KIWIQX::qxx ("udevadm settle --timeout=30 2>&1");
				push @UmountStack,"kpartx -sd $loop";
				$this->{UmountStack} = \@UmountStack;
				$loop =~ s/\/dev\///;
				$source = "/dev/mapper/".$loop."p3";
				if (! -b $source) {
					$source = "/dev/mapper/".$loop."p2";
				}
				if (! -b $source) {
					$source = "/dev/mapper/".$loop."p1";
				}
			}
			if (! -b $source) {
				$kiwi -> error ("No such block device $source");
				$kiwi -> failed ();
				$this -> umount();
				return;
			}
		}
	}
	#==========================================
	# check for activated volume group
	#------------------------------------------
	$source = $this -> checkLVMbind ($source);
	@UmountStack = @{$this->{UmountStack}};
	if (! $source) {
		$kiwi -> error ("Failed to bind disk to LVM group");
		$kiwi -> failed ();
		$this -> umount();
		return;
	}
	#==========================================
	# Check source filesystem
	#------------------------------------------
	if (! %fsattr) {
		%fsattr = $this -> checkFileSystem ($source);
		$type   = $fsattr{type};
		if (! %fsattr) {
			$kiwi -> error  ("Couldn't detect filesystem on: $source");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Check for LUKS extension
	#------------------------------------------
	if ($type eq "luks") {
		if (-f $source) {
			$status = KIWIQX::qxx ("/sbin/losetup -f --show $source 2>&1");
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
			$status = KIWIQX::qxx (
				"echo $cipher | cryptsetup luksOpen $source luks-$salt 2>&1"
			);
		} else {
			$status = KIWIQX::qxx (
				"cryptsetup luksOpen $source luks-$salt 2>&1"
			);
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
	if ((-f $source) && ($type ne "clicfs") && ($type ne 'zfs')) {
		if ($opts) {
			$status = KIWIQX::qxx ("mount -n -o loop,$opts $source $dest 2>&1");
		} else {
			$status = KIWIQX::qxx ("mount -n -o loop $source $dest 2>&1");
		}
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount $source to: $dest: $status");
			$kiwi -> failed ();
			$this -> umount();
			return;
		}
	} else {
		if ($type eq 'zfs') {
			if (! -b $source) {
				my $basedir = dirname ($source);
				$status = KIWIQX::qxx (
					"zpool import -d $basedir kiwipool 2>&1"
				);
			} else {
				$status = KIWIQX::qxx (
					"zpool import kiwipool 2>&1"
				);
			}
			$result = $? >> 8;
			if ($result == 0) {
				push @UmountStack,"zpool export kiwipool";
				$this->{UmountStack} = \@UmountStack;
				my $rootpool = '/kiwipool/ROOT/system-1';
				$status = KIWIQX::qxx (
					"mount -n --bind $rootpool $dest 2>&1"
				);
				$result = $? >> 8;
			}
		} elsif ($type eq "clicfs") {
			$status = KIWIQX::qxx ("clicfs -m 512 $source $dest 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = KIWIQX::qxx ("resize2fs $dest/fsdata.ext4 2>&1");
				$result = $? >> 8;
			}
		} else {
			if ($opts) {
				$status = KIWIQX::qxx ("mount -n -o $opts $source $dest 2>&1");
			} else {
				$status = KIWIQX::qxx ("mount -n $source $dest 2>&1");
			}
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
	if (-f $dest."/fsdata.ext4") {
		$source = $dest."/fsdata.ext4";
		$status = KIWIQX::qxx ("mount -n -o loop $source $dest 2>&1");
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
# getPartDevice
#------------------------------------------
sub getPartDevice {
	# ...
	# find the correct partition device according
	# to the disk device and partition number
	# ---
	my $this = shift;
	my $disk = shift;
	my $part = shift;
	my $devcopy = $disk;
	my $devbase = basename $devcopy;
	my @checklist = (
		"/dev/mapper/".$devbase."p".$part,
		"/dev/".$devbase."p".$part,
		"/dev/".$devbase.$part
	);
	foreach my $device (@checklist) {
		if (-b $device) {
			return $device;
		}
	}
	return;
}

#==========================================
# umount
#------------------------------------------
sub umount {
	# /.../
	# implements an umount function for filesystems mounted
	# via mount(). The function walks through the
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
	KIWIQX::qxx ("sync");
	my @UmountStack = @{$stack};
	foreach my $cmd (reverse @UmountStack) {
		$status = KIWIQX::qxx ("$cmd 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> loginfo (
				"KIWIGlobals::umount $cmd failed: $status\n"
			);
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
		my $size = KIWIQX::qxx ("blockdev --getsize64 $target 2>&1");
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
# dsize
#------------------------------------------
sub dsize {
	# /.../
	# implements a size function which calculates the size of
	# all entities in a directory using the 'du' utility
	# ---
	my $this = shift;
	my $dir  = shift;
	if (! defined $dir) {
		return 0;
	}
	my $size1 = KIWIQX::qxx (
		"du -s --block-size=1 $dir | cut -f1"
	);
	chomp $size1;
	my $size2 = KIWIQX::qxx (
		"du -s --apparent-size --block-size=1 $dir | cut -f1"
	);
	chomp $size2;
	if ($size1 > $size2) {
		return $size1;
	}
	return $size2;
}

#==========================================
# generateBuildInformation
#------------------------------------------
sub generateBuildInformation {
	# ...
	# write an ini file containing information about
	# the build. This data is used in the KIWIResult to
	# create an image release
	# ---
	my $this = shift;
	my $xml  = shift;
	my $cmdL = shift;
	my $kiwi = $this->{kiwi};
	#==========================================
	# requires pointer to xml and command line
	#------------------------------------------
	if ((! $xml) || (! $cmdL)) {
		$kiwi -> warning (
			"Need pointer to XML config and command line"
		);
		$kiwi -> skipped();
		return;
	}
	my $idest = $cmdL -> getImageIntermediateTargetDir();
	my $name  = $this -> generateBuildImageName($xml);
	my $file  = $idest.'/kiwi.buildinfo';
	KIWIQX::qxx ("echo '[main]' > $file");
	my $buildinfo = Config::IniFiles -> new (
		-file => $file, -allowedcommentchars => '#'
	);
	if (! $buildinfo) {
		$kiwi -> warning (
			"Can't create build info file: $file"
		);
		$kiwi -> skipped ();
		return;
	}
	#==========================================
	# store image base name
	#------------------------------------------
	$buildinfo->newval('main', 'image.basename', $name);
	#==========================================
	# store build format
	#------------------------------------------
	my $bldType = $xml -> getImageType();
	if ($bldType) {
		my $format = $bldType -> getFormat();
		if ($format) {
			$buildinfo->newval('main', 'image.format', $format);
		}
	}
	#==========================================
	# store build type
	#------------------------------------------
	if ($bldType) {
		my $imgtype = $bldType -> getTypeName();
		$buildinfo->newval('main', 'image.type', $imgtype);
	}
	#==========================================
	# store install media type
	#------------------------------------------
	if ($bldType) {
		my $instIso   = $bldType -> getInstallIso();
		my $instStick = $bldType -> getInstallStick();
		my $instPXE   = $bldType -> getInstallPXE();
		if (($instIso) && ($instIso eq 'true')) {
			$buildinfo->newval('main', 'install.iso', 'true');
		}
		if (($instStick) && ($instStick eq 'true')) {
			$buildinfo->newval('main', 'install.stick', 'true');
		}
		if (($instPXE) && ($instPXE eq 'true')) {
			$buildinfo->newval('main', 'install.pxe', 'true');
		}
	}
	$buildinfo->RewriteConfig();
	return $this;
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
	my $locator   = KIWILocator -> instance();
	my $uname_exec= $locator -> getExecPath("uname");
	return if ! $uname_exec;
	my $arch = KIWIQX::qxx ("$uname_exec -m");
	chomp ( $arch );
	$arch = ".$arch";
	if (! defined $separator) {
		$separator = "-";
	}
	my $name = $xml -> getImageName();
	my $iver = $xml -> getPreferences() -> getVersion();
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
	my $trace   = KIWITrace -> instance();
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
			my $data = KIWIQX::qxx ("blkid -o value -s TYPE $fs");
			my $code = $? >> 8;
			my $type;
			SWITCH: for ($data) {
				/ext4/         && do {
					$type = "ext4";
					last SWITCH;
				};
				/ext3/         && do {
					$type = "ext3";
					last SWITCH;
				};
				/ext2/         && do {
					$type = "ext2";
					last SWITCH;
				};
				/reiserfs/     && do {
					$type = "reiserfs";
					last SWITCH;
				};
				/btrfs/        && do {
					$type = "btrfs";
					last SWITCH;
				};
				/squashfs/     && do {
					$type = "squashfs";
					last SWITCH;
				};
				/luks/         && do {
					$type = "luks";
					last SWITCH;
				};
				/crypto_LUKS/  && do {
					$type = "luks";
					last SWITCH;
				};
				/xfs/          && do {
					$type = "xfs";
					last SWITCH;
				};
				/zfs_member/   && do {
					$type = "zfs";
					last SWITCH;
				};
				# unknown filesystem type check clicfs...
				$data = KIWIQX::qxx (
					"dd if=$fs bs=128k count=1 2>/dev/null | grep -qi CLIC"
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
			if ($kiwi -> trace()) {
				$trace->{BT}[$trace->{TL}] = eval {
					Carp::longmess ($trace->{TT}.$trace->{TL}++)
				};
			}
			return ();
		}
	}
	return %result;
}

#==========================================
# createZFSPool
#------------------------------------------
sub createZFSPool {
	# /.../
	# create zfs pool layout as suggested by
	# the community
	# ----
	my $this = shift;
	my $opts = shift;
	my $kiwi = $this->{kiwi};
	my $data;
	my $code;
	#==========================================
	# create sub pools
	#------------------------------------------
	$data = KIWIQX::qxx ('zfs create kiwipool/ROOT 2>&1');
	$code = $? >> 8;
	if ($code == 0) {
		$data = KIWIQX::qxx ('zfs create kiwipool/ROOT/system-1 2>&1');
		$code = $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> error ("Failed to create zfs pool volumes: $data\n");
		$kiwi -> failed();
		return;
	}
	#==========================================
	# create pool properties
	#------------------------------------------
	$data = KIWIQX::qxx (
		'zpool set bootfs=kiwipool/ROOT/system-1 kiwipool 2>&1'
	);
	$code = $? >> 8;
	if ($code != 0) {
		KIWIQX::qxx ("zpool export kiwipool 2>&1");
		$kiwi -> error ("Failed to create zfs pool properties: $data\n");
		$kiwi -> failed();
		return;
	}
	#==========================================
	# set pool options
	#------------------------------------------
	if ($opts) {
		my @optlist = split (/,/,$opts);
		foreach my $opt (@optlist) {
			$data = KIWIQX::qxx ("zfs set $opt kiwipool 2>&1");
			$code = $? >> 8;
			if ($code != 0) {
				KIWIQX::qxx ("zpool export kiwipool 2>&1");
				$kiwi -> error ("Failed to set pool property: $opt:$data\n");
				$kiwi -> failed();
				return;
			}
		}
	}
	#==========================================
	# export pool
	#------------------------------------------
	$data = KIWIQX::qxx ("zpool export kiwipool 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error ("Failed to export zfs pool: $data\n");
		$kiwi -> failed();
		return;
	}
	return $this;
}

#==========================================
# setupZFSPoolVolumes
#------------------------------------------
sub setupZFSPoolVolumes {
	# /.../
	# create zfs subvolume setup as configured in
	# the systemdisk volume setup
	# ----
	my $this   = shift;
	my $path   = shift;
	my $vols   = shift;
	my $kiwi   = $this->{kiwi};
	my %phash  = ();
	my @paths  = ();
	my $data;
	my $code;
	my @UmountStack = @{$this->{UmountStack}};
	if ($vols) {
		#==========================================
		# Create path names in correct order
		#------------------------------------------
		foreach my $name (keys %{$vols}) {
			next if $name eq '@root';
			my $pname  = $name; $pname =~ s/_/\//g;
			$pname =~ s/^\///;
			$pname =~ s/\s*$//;
			push @paths,$pname;
		}
		foreach my $name (@paths) {
			my @parts = split (/\//,$name);
			my $part  = @parts;
			push @{$phash{$part}},$name;
		}
	}
	if (! %phash) {
		return $this;
	}
	$kiwi -> info ("Creating ZFS pool\n");
	my $main = 'kiwipool/ROOT/system-1';
	foreach my $level (sort {($a <=> $b) || ($a cmp $b)} keys %phash) {
		foreach my $vol (@{$phash{$level}}) {
			$kiwi -> info ("--> Adding pool $vol");
			$data = KIWIQX::qxx ("zfs create $main/$vol 2>&1");
			$code = $? >> 8;
			if ($code == 0) {
				push @UmountStack,"umount /$main/$vol";
				$this->{UmountStack} = \@UmountStack;
				$kiwi -> done();
			} else {
				$kiwi -> failed();
				last;
			}
		}
	}
	#==========================================
	# check error flag and return
	#------------------------------------------
	if ($code != 0) {
		$kiwi -> error ("Failed to create zfs pool volumes: $data\n");
		$kiwi -> failed();
		return;
	}
	return $this;
}

#==========================================
# setupBTRFSSubVolumes
#------------------------------------------
sub setupBTRFSSubVolumes {
	# /.../
	# create a btrfs subvolume setup as configured in
	# the systemdisk volume setup
	# ----
	my $this   = shift;
	my $path   = shift;
	my $vols   = shift;
	my $kiwi   = $this->{kiwi};
	my %phash  = ();
	my @paths  = ();
	if ($vols) {
		#==========================================
		# Create path names in correct order
		#------------------------------------------
		foreach my $name (keys %{$vols}) {
			next if $name eq '@root';
			my $pname  = $name; $pname =~ s/_/\//g;
			$pname =~ s/^\///;
			$pname =~ s/\s*$//;
			push @paths,$pname;
		}
		foreach my $name (@paths) {
			my @parts = split (/\//,$name);
			my $part  = @parts;
			push @{$phash{$part}},$name;
		}
	}
	if (! %phash) {
		return $path;
	}
	$kiwi -> info ("Creating btrfs pool\n");
	my $data = KIWIQX::qxx ('btrfs subvolume create '.$path.'/@ 2>&1');
	my $code = $? >> 8;
	if ($code == 0) {
		my $rootID=0;
		$data = KIWIQX::qxx ("btrfs subvolume list $path 2>&1");
		if ($data =~ /^ID (\d+) /) {
			$rootID=$1;
		}
		if ($rootID) {
			$data = KIWIQX::qxx (
				"btrfs subvolume set-default $rootID $path 2>&1"
			);
			$code = $? >> 8;
		} else {
			$code = 1;
		}
	}
	if ($code == 0) {
		foreach my $level (sort {($a <=> $b) || ($a cmp $b)} keys %phash) {
			foreach my $vol (@{$phash{$level}}) {
				$kiwi -> info ("--> Adding subvolume $vol");
				$data = KIWIQX::qxx (
					'btrfs subvolume create '.$path.'/@/'.$vol.' 2>&1'
				);
				$code = $? >> 8;
				if ($code == 0) {
					$kiwi -> done();
				} else {
					$kiwi -> failed();
					last;
				}
			}
		}
	}
	if ($code != 0) {
		$kiwi -> error ("Failed to create btrfs subvolume: $data\n");
		$kiwi -> failed();
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
		KIWIQX::qxx ("chroot $root umount -l $path 2>&1");
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
	# /.../
	# currently the use of lxc to run the call is deactivated
	# because lxc requires cgroups support which is often not
	# present in the environments people call kiwi in
	# ----
	my $uselxc   = 0;
	my $fallback = 0;
	if ($uselxc) {
		#==========================================
		# create lxc config file
		#------------------------------------------
		my $locator = KIWILocator -> instance();
		my $lxstart = $locator -> getExecPath('lxc-start');
		my $lxstop  = $locator -> getExecPath('lxc-stop');
		if ((! $lxstart) || (! $lxstop)) {
			#==========================================
			# no lxc installed used chroot
			#------------------------------------------
			$kiwi -> loginfo ("lxc not installed\n");
			$fallback = 1;
		} else {
			if (! open ($FD,">","$root/config.lxc")) {
				$kiwi -> loginfo ("Couldn't create lxc config file: $!\n");
				$fallback = 1;
			} else {
				print $FD "lxc.utsname = kiwi-contained-script"."\n";
				print $FD "lxc.rootfs  = $root"."\n";
				close $FD;
				#==========================================
				# call via lxc-start
				#------------------------------------------
				$data = KIWIQX::qxx (
					"$lxstart -n kiwi -f $root/config.lxc ./$prog 2>&1"
				);
				$code = $? >> 8;
				#==========================================
				# cleanup lxc
				#------------------------------------------
				KIWIQX::qxx ("rm -f $root/config.lxc 2>&1");
				KIWIQX::qxx ("$lxstop -n kiwi 2>&1");
			}
		}
	}
	if ((! $uselxc) || ($fallback)) {
		#==========================================
		# cleanup lxc
		#------------------------------------------
		if ($fallback) {
			$kiwi -> loginfo ("Falling back to chroot method\n");
			if (-e "$root/config.lxc") {
				KIWIQX::qxx ("rm -f $root/config.lxc 2>&1");
			}
		}
		#==========================================
		# call in chroot
		#------------------------------------------
		$data = KIWIQX::qxx ("chroot $root $prog 2>&1 ");
		$code = $? >> 8;
		$this -> umountSystemFileSystems ($root);
	}
	return ($code,$data);
}

#==========================================
# checkLVMbind
#------------------------------------------
sub checkLVMbind {
	# ...
	# check if sdev points to LVM, if yes activate it and
	# rebuild sdev to point to the right logical volume
	# ---
	my $this = shift;
	my $sdev = shift;
	if (! $sdev) {
		return;
	}
	my @UmountStack = @{$this->{UmountStack}};
	my $vgname = KIWIQX::qxx ("pvs --noheadings -o vg_name $sdev 2>/dev/null");
	my $result = $? >> 8;
	if ($result != 0) {
		return $sdev;
	}
	chomp $vgname;
	$vgname =~ s/^\s+//;
	$vgname =~ s/\s+$//;
	$this->{lvm} = 1;
	$this->{lvmgroup} = $vgname;
	my $status = KIWIQX::qxx ("vgchange -a y $vgname 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		return;
	}
	push @UmountStack,"vgchange -a n $vgname";
	$this->{UmountStack} = \@UmountStack;
	$sdev = "/dev/mapper/$vgname-LVComp";
	if (! -e $sdev) {
		$sdev = "/dev/mapper/$vgname-LVRoot";
	}
	if (! -e $sdev) {
		return;
	}
	return $sdev;
}

#==========================================
# downloadFile
#------------------------------------------
sub downloadFile {
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
	my $proxy;
	my $user;
	my $pass;
	my $lwp = "/dev/shm/lwp-download";
	#==========================================
	# Check parameters
	#------------------------------------------
	if ((! defined $dest) || (! defined $url)) {
		return;
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
		return;
	}
	#==========================================
	# check base and dir name
	#------------------------------------------
	if (! $basename) {
		return;
	}
	if (! -d $dirname) {
		return;
	}
	#==========================================
	# quote shell escape sequences
	#------------------------------------------
	$url =~ s/(["\$`\\])/\\$1/g;
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
	if ($url =~ /^(.*)\?(.*)$/) {
		$url=$1;
		my $redirect=$2;
		if ($redirect =~ /(.*?)\/(.*)?$/) {
			$redirect = $1;
			$url.='/'.$2;
		}
		# get proxy url:
		# \bproxy makes sure it does not pick up "otherproxy=unrelated"
		# (?=&|$) makes sure the captured substring is followed by an
		# ampersand or the end-of-string
		# ----
		if ($redirect =~ /\bproxy=(.*?)(?=&|$)/) {
			$proxy = "$1";
		}
		# remove locator string e.g http://
		if ($proxy) {
			$proxy =~ s/^.*\/\///;
		}
		# extract credentials user and password
		if ($redirect =~ /proxyuser=(.*)\&proxypass=(.*)/) {
			$user=$1;
			$pass=$2;
		}
	}
	my $LWP = FileHandle -> new();
	if (! $LWP -> open (">$lwp")) {
		return;
	}
	if ($proxy) {
		print $LWP 'export PERL_LWP_ENV_PROXY=1'."\n";
		if (($user) && ($pass)) {
			print $LWP "export http_proxy=http://$user:$pass\@$proxy\n";
		} else {
			print $LWP "export http_proxy=http://$proxy\n";
		}
	}
	my $locator = KIWILocator -> instance();
	my $lwpload = $locator -> getExecPath ('lwp-download');
	if (! $lwpload) {
		return;
	}
	print $LWP $lwpload.' "$1" "$2"'."\n";
	$LWP -> close();
	# /.../
	# use lwp-download to manage the process.
	# if first download failed check the directory list with
	# a regular expression to find the file. After that repeat
	# the download
	# ----
	KIWIQX::qxx ("chmod u+x $lwp 2>&1");
	$dest = $dirname."/".$basename;
	my $data = KIWIQX::qxx ("$lwp $url $dest 2>&1");
	my $code = $? >> 8;
	if ($code == 0) {
		return $url;
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
			return;
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
				$data = KIWIQX::qxx ("$lwp $url $dest 2>&1");
				$code = $? >> 8;
				if ($code == 0) {
					return $url;
				}
			}
		}
		return;
	} else {
		return;
	}
	return $url;
}

#==========================================
# checkType
#------------------------------------------
sub checkType {
	# ...
	# Check the image type
	# ---
	my $this = shift;
	my $xml  = shift;
	my $root = shift;
	my $cmdL = shift;
	my $kiwi = $this->{kiwi};
	my $type = $xml -> getImageType();
	my $para = "ok";
	#==========================================
	# check for required image attributes
	#------------------------------------------
	if ($cmdL->getFatStorage()) {
		# /.../
		# if the option --fat-storage is set, we set grub2
		# as bootloader because it works well on USB sticks.
		# Additionally we use LVM because it allows to better
		# resize the stick
		# ----
		$type -> setBootLoader('grub2');
		$type -> setBootImageFileSystem('fat16');
		$xml  -> updateType ($type);
		my $sysDisk = $xml -> getSystemDiskConfig();
		if (! $sysDisk) {
			my %lvmData;
			$sysDisk = KIWIXMLSystemdiskData -> new(\%lvmData);
			$xml -> addSystemDisk ($sysDisk);
		}
	} elsif ($cmdL->getLVM()) {
		# /.../
		# if the option --lvm is set, we add/update a systemdisk
		# element which triggers the use of LVM
		# ----
		my $sysDisk = $xml -> getSystemDiskConfig();
		if (! $sysDisk) {
			my %lvmData;
			$sysDisk = KIWIXMLSystemdiskData -> new(\%lvmData);
			$xml -> addSystemDisk ($sysDisk);
		}
	}
	#==========================================
	# check for required filesystem tool(s)
	#------------------------------------------
	my $typeName   = $type -> getTypeName();
	my $flags      = $type -> getFlags();
	my $filesystem = $type -> getFilesystem();
	if (($flags) || ($filesystem)) {
		my @fs = ();
		if (($flags) && ($typeName eq "iso")) {
			push (@fs, $flags);
		} else {
			@fs = split (/,/, $filesystem);
		}
		foreach my $fs (@fs) {
			my %result = KIWIGlobals -> instance() -> checkFileSystem ($fs);
			if (%result) {
				if (! $result{hastool}) {
					$kiwi -> error (
						"Can't find filesystem tool for: $result{type}"
					);
					$kiwi -> failed ();
					return;
				}
			} else {
				$kiwi -> error ("Can't check filesystem attributes from: $fs");
				$kiwi -> failed ();
				return;
			}
		}
	}
	#==========================================
	# check for default bootloader on iso
	#------------------------------------------
	my $hybrid = $type -> getHybrid();
	if ($typeName eq 'iso') {
		# /.../
		# live iso images always use isolinux for bios boot
		# and grub2 for efi boot. Thus overwrite the default
		# if a hybrid setup is specified we have to use
		# isolinux as well
		# ----
		$type -> setBootLoader ('isolinux');
	}
	#==========================================
	# check tool/driver compatibility
	#------------------------------------------
	my $check_mksquashfs = 0;
	if ($typeName eq "squashfs") {
		$check_mksquashfs = 1;
	}
	my $instISO = $type -> getInstallIso();
	my $instStick = $type -> getInstallStick();
	if ( $instISO || $instStick ) {
		$check_mksquashfs = 1;
	}
	if (($filesystem) && ($filesystem =~ /squashfs/)) {
		$check_mksquashfs = 1;
	}
	if (($flags) && ($flags =~ /compressed/)) {
		$check_mksquashfs = 1;
	}
	#==========================================
	# squashfs...
	#------------------------------------------
	if ($check_mksquashfs) {
		my $km = glob ("$root/lib/modules/*/kernel/fs/squashfs/squashfs.ko");
		if ($km) {
			my $locator = KIWILocator -> instance();
			my $mk_squash = $locator -> getExecPath ("mksquashfs");
			my $modinfo   = $locator -> getExecPath ("modinfo");
			my $mktool_vs = 'unknown';
			my $module_vs = 'unknown';
			if ($mk_squash) {
				$mktool_vs = KIWIQX::qxx (
					"$mk_squash -version 2>&1 | head -n 1"
				);
			}
			if ($module_vs) {
				$module_vs = KIWIQX::qxx (
					"$modinfo -d $km 2>&1"
				);
			}
			my $error = 0;
			if ($mktool_vs =~ /^mksquashfs version (\d)\.\d \(/) {
				$mktool_vs = $1;
				$error++;
			}
			if ($module_vs =~ /^squashfs (\d)\.\d,/) {
				$module_vs = $1;
				$error++;
			}
			$kiwi -> loginfo ("squashfs mktool major version: $mktool_vs\n");
			$kiwi -> loginfo ("squashfs module major version: $module_vs\n");
			if (($error == 2) && ($mktool_vs ne $module_vs)) {
				my $msg = "--> squashfs tool/driver mismatch";
				$kiwi -> error (
					"$msg: $mktool_vs vs $module_vs"
				);
				$kiwi -> failed ();
				return;
			}
		}
	}
	#==========================================
	# build and check KIWIImage method params
	#------------------------------------------
	my $bootImg = $type -> getBootImageDescript();
	SWITCH: for ($typeName) {
		/^iso/ && do {
			if (! $bootImg) {
				$kiwi -> error ("$typeName: No boot image specified");
				$kiwi -> failed ();
				return;
			}
			$para = $bootImg;
			if ((defined $flags) && ($flags ne "")) {
				$para .= ",$flags";
			}
			last SWITCH;
		};
		/^split/ && do {
			my $fsro = $type -> getFSReadOnly();
			my $fsrw = $type -> getFSReadWrite();
			if (! $fsro || ! $fsrw) {
				$kiwi -> error ("$typeName: No filesystem pair specified");
				$kiwi -> failed ();
				return;
			}
			$para = "$fsrw,$fsro";
			if (defined $bootImg) {
				$para .= ":".$bootImg;
			}
			last SWITCH;
		};
		/^vmx|oem|pxe/ && do {
			if (! defined $filesystem) {
				$kiwi -> error ("$typeName: No filesystem specified");
				$kiwi -> failed ();
				return;
			}
			if (! defined $bootImg) {
				$kiwi -> error ("$typeName: No boot image specified");
				$kiwi -> failed ();
				return;
			}
			$para = $filesystem . ":" . $bootImg;
			last SWITCH;
		};
	}
	return $para;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# One time initialization code
#------------------------------------------
sub _new_instance {
	# ...
	# Construct a KIWIGlobals object. The globals object holds configuration
	# data for kiwi itself and provides methods
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $arch = qx(uname -m);
	chomp $arch;
	#==========================================
	# Globals (generic)
	#------------------------------------------
	my %data;
	$data{Version}         = "5.06.114";
	$data{Publisher}       = "SUSE LINUX GmbH";
	$data{Preparer}        = "KIWI - http://opensuse.github.com/kiwi";
	$data{ConfigName}      = "config.xml";
	$data{Partitioner}     = "parted";
	$data{PackageManager}  = "zypper";
	$data{FSInodeRatio}    = 16384;
	$data{FSMinInodes}     = 20000;
	$data{FSInodeSize}     = 256;
	$data{DiskStartSector} = 2048;
	$data{DiskSectorSize}  = 512;
	$data{DiskAlignment}   = 4096;
	$data{SnapshotChunk}   = 4096;
	$data{SnapshotCount}   = "5G";
	$data{OverlayRootTree} = 0;
	$data{VolumeFree}      = 20;
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
	my $kiwi = KIWILog -> instance();
	$this->{kiwi} = $kiwi;
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
	$data{Xz}            = $Xz;            # configurable xz command
	$data{LogServerPort} = $LogServerPort; # configurable log server port
	$data{LuksCipher}    = $LuksCipher;    # configurable luks passphrase
	$data{System}        = $System;        # configurable base image desc. path
	$data{IrdZipper}     = $IrdZipper;     # configurable zipper switch for ird
	if ( ! defined $BasePath ) {
		$data{BasePath} = "/usr/share/kiwi";
	}
	if (! defined $Gzip) {
		$data{Gzip} = "gzip -9";
	}
	if (! defined $Xz) {
		$data{Xz} = "xz -6";
	}
	if (! defined $LogServerPort) {
		$data{LogServerPort} = "off";
	}
	if (! defined $System) {
		$data{System} = $data{BasePath}."/image";
	}
	if (! defined $IrdZipper) {
		$data{IrdZipper} = "gzip";
	}
	if (! defined $LuksCipher) {
		# empty
	}
	$data{IrdZipperCommand} = $data{Gzip};
	$data{IrdZipperSuffix} = "gz";
	if ($data{IrdZipper} eq "xz") {
		$data{IrdZipperCommand} = $data{Xz}." --check=crc32";
		$data{IrdZipperSuffix} = "xz";
	}
	use strict 'vars';
	## use critic
	my $BasePath = $data{BasePath};
	#==========================================
	# Globals (path names)
	#------------------------------------------
	$data{Tools}       = $BasePath."/tools";
	$data{Schema}      = $BasePath."/modules/KIWISchema.rng";
	$data{KConfig}     = $BasePath."/modules/KIWIConfig.sh";
	$data{KAnalyse}    = $BasePath."/metadata/KIWIAnalyse.systems";
	$data{KAnalyseCSS} = $BasePath."/metadata/KIWIAnalyse.tgz";
	$data{KAnalyseCMK} = $BasePath."/metadata/KIWIAnalyse.custom.sync.mkd";
	$data{KSplit}      = $BasePath."/metadata/KIWISplit.xml";
	$data{KAnalyseTPL} = $BasePath."/metadata";
	$data{KModules}    = $BasePath."/modules";
	$data{KStrip}      = $BasePath."/metadata/KIWIConfig.xml";
	$data{repoURI}     = $BasePath."/metadata/KIWIURL.patterns";
	$data{Revision}    = $BasePath."/.revision";
	$data{TestBase}    = $BasePath."/tests";
	$data{SchemaCVT}   = $BasePath."/xsl/master.xsl";
	$data{Pretty}      = $BasePath."/xsl/print.xsl";
	#==========================================
	# Globals (Supported filesystem names)
	#------------------------------------------
	my %KnownFS;
	my $locator = KIWILocator -> instance();
	my %tools;
	$tools{ext4}       = "mkfs.ext4";
	$tools{ext3}       = "mkfs.ext3";
	$tools{ext2}       = "mkfs.ext2";
	$tools{squashfs}   = "mksquashfs";
	$tools{overlayfs}  = "mksquashfs";
	$tools{clicfs}     = "mkclicfs";
	$tools{clic}       = "mkclicfs";
	$tools{seed}       = "mkfs.btrfs";
	$tools{overlay}    = "mksquashfs";
	$tools{clic_udf}   = "mkclicfs";
	$tools{compressed} = "mksquashfs";
	$tools{reiserfs}   = "mkreiserfs";
	$tools{btrfs}      = "mkfs.btrfs";
	$tools{xfs}        = "mkfs.xfs";
	$tools{zfs}        = "zpool";
	$tools{cpio}       = "cpio";
	foreach my $flag (keys %tools) {
		$KnownFS{$flag}{tool} = $locator -> getExecPath(
			$tools{$flag},undef,'nolog'
		);
	}
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
	$KnownFS{zfs}{ro}         = 0;
	$KnownFS{cpio}{ro}        = 0;
	$data{KnownFS} = \%KnownFS;
	#==========================================
	# Globals (luks options)
	#------------------------------------------
	my %LuksDist;
	$LuksDist{sle11} =
		'--cipher aes-cbc-essiv:sha256 --key-size 256 --hash sha1';
	$data{LuksDist} = \%LuksDist;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{data} = \%data;
	$this->{UmountStack} = [];
	return $this;
}

1;
