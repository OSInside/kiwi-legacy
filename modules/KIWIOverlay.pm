#================
# FILE          : KIWIOverlay.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used for directory overlay techniques
#               :
#               :
# STATUS        : Development
#----------------
package KIWIOverlay;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use File::Spec;
use File::stat;
use File::Stat::Bits;
use KIWILog;
use KIWIQX qw (qxx);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct a new KIWIOverlay object. The constructor
	# will store all information in order to overlay the
	# given directory information. A check whether the mount
	# has worked is done on demand
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless  $this,$class;
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi   = shift;
	my $rootRW = shift;
	my $baseRO = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! -d $rootRW) {
		$kiwi -> error ("Directory $rootRW doesn't exist");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Check rootRW structure
	#------------------------------------------
	$this->{initial} = 0;
	if (defined $baseRO) {
		# ...
		# base read-only path specified, means this is an initial
		# prepare call using a cache
		# ---
		$this->{initial} = 1;
	}
	if (-f "$rootRW/kiwi-root.cache") {
		my $FD;
		if (! open ($FD, '<', "$rootRW/kiwi-root.cache")) {
			$kiwi -> error  ("Can't open cache root meta data");
			$kiwi -> failed ();
			return;
		}
		$baseRO = <$FD>;
		close $FD;
		chomp $baseRO;
	}
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}   = $kiwi;
	$this->{gdata}  = $main::global -> getGlobals();
	$this->{baseRO} = $baseRO;
	$this->{rootRW} = $rootRW;
	return $this;
}

#==========================================
# mountOverlay
#------------------------------------------
sub mountOverlay {
	# ...
	# call the appropriate overlay function
	# ---
	my $this = shift;
	if (! defined $this->{baseRO}) {
		return $this->{rootRW};
	}
	return $this -> unionOverlay();
}

#==========================================
# unionOverlay
#------------------------------------------
sub unionOverlay {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $baseRO = $this->{baseRO};
	my $rootRW = $this->{rootRW};
	my %fsattr = $main::global -> checkFileSystem ($baseRO);
	my $type   = $fsattr{type};
	my @mount  = ();
	my $haveCow= 0;
	my $tmpdir;
	my $cowdev;
	my $result;
	my $status;
	my %snapshot;
	my $baseLoop;
	my $uuid;
	#==========================================
	# Check result of filesystem detection
	#------------------------------------------
	if (! %fsattr) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect filesystem on: $baseRO");
		return;
	}
	#==========================================
	# Check for btrfs extension
	#------------------------------------------
	if ($type ne "btrfs") {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect btrfs on: $baseRO");
		return;
	}
	#==========================================
	# Create tmpdir for mount point
	#------------------------------------------
	$tmpdir = qxx ("mktemp -q -d /tmp/kiwiRootOverlay.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create overlay tmpdir");
		return;
	}
	$this->{tmpdir} = $tmpdir;
	$cowdev = "$rootRW/kiwi-root.cow";
	$this->{cowdev} = $cowdev;
	#==========================================
	# Check for cow file before mount
	#------------------------------------------
	if (-f $cowdev) {
		$haveCow=1;
	}
	#==========================================
	# Create snapshot map if not done
	#------------------------------------------
	if (! $haveCow) {
		%snapshot = $this -> createBTRFSSeed ($cowdev);
		if (! %snapshot) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to snapshot $baseRO");
			return;
		}
		push @mount,@{$snapshot{stack}};
		$this->{mount} = \@mount;
	}
	#==========================================
	# Mount cache as snapshot
	#------------------------------------------
	$kiwi -> info("Creating overlay path\n");
	$kiwi -> info("--> Base: $baseRO(ro)\n");
	$kiwi -> info("--> COW:  $cowdev(rw)\n");
	if (! $haveCow) {
		$baseLoop = $this -> createLoopNode ($baseRO);
		if (! $baseLoop) {
			return;
		}
		$status = qxx ("losetup $baseLoop $baseRO 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to loop $baseRO to: $baseLoop: $status");
			$kiwi -> failed ();
			return;
		}
		push @mount,"losetup -d $baseLoop";
		$this->{mount} = \@mount;
		$status = qxx ("mount $baseLoop $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to mount $baseLoop to: $tmpdir: $status");
			$kiwi -> failed ();
			return;
		}
		push @mount,"umount $tmpdir";
		$this->{mount} = \@mount;
		$status = qxx ("btrfs device add $snapshot{seed} $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to add seed device to: $tmpdir: $status");
			$kiwi -> failed ();
			return;
		}
		$status = qxx ("mount -o remount,rw $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to remount cache read-write: $status");
			$kiwi -> failed ();
			return;
		}
	} else {
		$uuid = qxx ("blkid -s UUID -o value $baseRO 2>&1"); chomp $uuid;
		$baseLoop = "/dev/loop-".$uuid;
		if (! -e $baseLoop) {
			$kiwi -> error  ("Can't find base cache loop: $baseLoop");
			$kiwi -> failed ();
			return;
		}
		$status = qxx ("losetup $baseLoop $baseRO 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to loop setup base cache: $status");
			$kiwi -> failed ();
			return;
		}
		push @mount,"losetup -d $baseLoop";
		$this->{mount} = \@mount;
		$status = qxx ("mount -o loop $cowdev $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to mount $cowdev to: $tmpdir: $status");
			$kiwi -> failed ();
			return;
		}
		push @mount,"umount $tmpdir";
		$this->{mount} = \@mount;
	}
	#==========================================
	# setup cache meta data
	#------------------------------------------
	if (! $haveCow) {
		qxx ("echo $this->{baseRO} > $rootRW/kiwi-root.cache");
		if ($this->{initial}) {
			# /.../
			# tell the global object that we want to store the updated
			# XML configuration in $rootRW/image. This happens upon
			# the call of writeXMLDescription()
			# ----
			$main::global -> setGlobals (
				"OverlayRootTree","$rootRW/image"
			);
		}
	}
	return $tmpdir;
}

#==========================================
# resetOverlay
#------------------------------------------
sub resetOverlay {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $tmpdir = $this->{tmpdir};
	my $baseRO = $this->{baseRO};
	my $mount  = $this->{mount};
	my $data;
	my $code;
	if ($mount) {
		foreach my $cmd (reverse @{$mount}) {
			qxx ("$cmd 2>&1");
		}
	}
	if (($tmpdir) && (-d $tmpdir)) {
		qxx ("rmdir $tmpdir 2>&1");
	}
	return $this;
}

#==========================================
# createBTRFSSeed
#------------------------------------------
sub createBTRFSSeed {
	my $this    = shift;
	my $cowfile = shift;
	my $snapshotCount = $this->{gdata}->{SnapshotCount};
	my $seedLoop;
	my @releaseList = ();
	my $data;
	my $code;
	my %result;
	#======================================
	# create btrfs seed device
	#--------------------------------------
	if (! -f $cowfile) {
		$data = qxx (
			"qemu-img create $cowfile $snapshotCount 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$result{stack} = \@releaseList;
			return;
		}
	}
	$seedLoop = qxx ("losetup -f --show $cowfile");
	$code = $? >> 8;
	if ($code != 0) {
		$result{stack} = \@releaseList;
		return;
	}
	chomp $seedLoop;
	push (@releaseList,"losetup -d $seedLoop");
	#======================================
	# return result
	#--------------------------------------
	$result{seed}  = $seedLoop;
	$result{stack} = \@releaseList;
	return %result;
}

#==========================================
# createLoopNode
#------------------------------------------
sub createLoopNode {
	# /.../
	# create new loop device node with an
	# unused minor number
	# ----
	my $this       = shift;
	my $loop_file  = shift;
	my $kiwi       = $this->{kiwi};
	my $loop_major = 7;
	my $loop_minor = 0;
	my $FD;
	my $data;
	my $uuid;
	my $code;
	#==========================================
	# search free minor number
	#------------------------------------------
	opendir ($FD,"/dev");
	while (my $file = readdir ($FD)) {
		if ($file =~ /^loop/) {
			my $attr = stat ("/dev/$file");
			my ($major, $minor) = dev_split( $attr->rdev );
			if ($major != $loop_major) {
				next;
			}
			if ($minor > $loop_minor) {
				$loop_minor = $minor;
			}
		}
	}
	closedir ($FD);
	$loop_minor++;
	#==========================================
	# create node name
	#------------------------------------------
	$uuid = qxx ("blkid -s UUID -o value $loop_file 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to obtain UUID from $loop_file");
		$kiwi -> failed ();
		return;
	}
	chomp $uuid;
	my $loop_dev = "/dev/loop-".$uuid;
	#==========================================
	# create node and return
	#------------------------------------------
	if (! -e $loop_dev) {
		$data = qxx ("mknod $loop_dev b $loop_major $loop_minor 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Failed to create loop node: $data");
			$kiwi -> failed ();
			return;
		}
	}
	return $loop_dev;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this = shift;
	$this -> resetOverlay();
	return $this;
}

1;
