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
#               : based on aufs / unionfs mount calls
#               :
#               :
# STATUS        : Development
#----------------
package KIWIOverlay;
#==========================================
# Modules
#------------------------------------------
use strict;
use Carp qw (cluck);
use File::Spec;
use KIWILog;
use KIWIQX;

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
	my $mode   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! $mode) {
		$mode = "copy";
	}
	if (! -d $rootRW) {
		$kiwi -> error ("Directory $rootRW doesn't exist");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Check rootRW structure
	#------------------------------------------
	if (-f "$rootRW/kiwi-root.cache") {
		my $FD; if (! open ($FD,"$rootRW/kiwi-root.cache")) {
			$kiwi -> error  ("Can't open cache root meta data");
			$kiwi -> failed ();
			return undef;
		}
		$baseRO = <$FD>; close $FD; chomp $baseRO;
		$mode = "union";
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}   = $kiwi;
	$this->{baseRO} = $baseRO;
	$this->{rootRW} = $rootRW;
	$this->{mode}   = $mode;
	return $this;
}

#==========================================
# setMode
#------------------------------------------
sub setMode {
	# ...
	# set the overlay mode. There are two modes "union" and
	# "copy". The copy mode is the default mode. While in the
	# union mode the overlay root system will be created by
	# mounting the baseRO together with the rootRW tree into
	# a temporary new root tree. The copy mode will tar/untar
	# the baseRO into the rootRW and return the rootRW as root
	# directory.
	# ---
	my $this = shift;
	my $mode = shift;
	if ($mode eq "union") {
		$this->{mode} = $mode;
	} elsif ($mode eq "recycle") {
		$this->{mode} = $mode;
	} else {
		$this->{mode} = "copy";
	}
	return $this;
}

#==========================================
# mountOverlay
#------------------------------------------
sub mountOverlay {
	# ...
	# call the appropriate overlay function according to the
	# specified mode. Note if in copy mode mountOverlay will
	# _not_ mount anything
	# ---
	my $this = shift;
	if (! defined $this->{baseRO}) {
		return $this->{rootRW};
	}
	if ($this->{mode} eq "union") {
		return $this -> unionOverlay();
	} elsif ($this->{mode} eq "recycle") {
		return $this -> recycleOverlay();
	} else {
		return $this -> copyOverlay();
	}
}

#==========================================
# unionOverlay
#------------------------------------------
sub unionOverlay {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $baseRO = $this->{baseRO};
	my $rootRW = $this->{rootRW};
	my %fsattr = main::checkFileSystem ($baseRO);
	my $type   = $fsattr{type};
	my @mount  = ();
	my $haveCow= 0;
	my $tmpdir;
	my $cowdev;
	my $result;
	my $status;
	my %snapshot;
	#==========================================
	# Check result of filesystem detection
	#------------------------------------------
	if (! %fsattr) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect filesystem on: $baseRO");
		return undef;
	}
	#==========================================
	# Check for ext2 extension
	#------------------------------------------
	if ($type ne "ext2") {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect ext2 on: $baseRO");
		return undef;
	}
	#==========================================
	# Create tmpdir for mount point
	#------------------------------------------
	$tmpdir = qxx ("mktemp -q -d /tmp/kiwiRootOverlay.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create overlay tmpdir");
		return undef;
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
	# Create snapshot map
	#------------------------------------------
	%snapshot = $this -> createSnapshotMap ($baseRO,$cowdev);
	if (! %snapshot) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to snapshot $baseRO");
		return undef;
	}
	push @mount,@{$snapshot{stack}};
	$this->{mount} = \@mount;
	#==========================================
	# Mount cache as snapshot
	#------------------------------------------
	$kiwi -> info("Creating overlay path\n");
	$kiwi -> info("--> Base: $baseRO(ro)\n");
	$kiwi -> info("--> COW:  $cowdev(rw)\n");
	$status = qxx ("mount $snapshot{mount} $tmpdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to mount $baseRO to: $tmpdir: $status");
		$kiwi -> failed ();
		return undef;
	}
	push @mount,"umount $tmpdir";
	$this->{mount} = \@mount;
	#==========================================
	# setup cache meta data
	#------------------------------------------
	if (! $haveCow) {
		qxx ("echo $this->{baseRO} > $rootRW/kiwi-root.cache");
		if ($main::Prepare) {
			$main::OverlayRootTree = "$rootRW/image";
		}
	}
	return $tmpdir;
}

#==========================================
# copyOverlay
#------------------------------------------
sub copyOverlay {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $baseRO = $this->{baseRO};
	my $rootRW = $this->{rootRW};
	my $data;
	my $code;
	$data = qxx ("tar -C $baseRO -cz --to-stdout . | tar -C $rootRW -xz");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to tar/untar base tree: $data");
		$kiwi -> failed ();
		return undef;
	}
	return $rootRW;
}

#==========================================
# recycleOverlay
#------------------------------------------
sub recycleOverlay {
	my $this = shift;
	return $this->{baseRO};
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
	if ($this->{mode} eq "copy") {
		return $this;
	}
	if ($this->{mode} eq "recycle") {
		return $this;
	}
	if ($mount) {
		foreach my $cmd (reverse @{$mount}) {
			qxx ("$cmd 2>&1");
		}
	}
	qxx ("rm -rf $tmpdir 2>&1");
	return $this;
}

#==========================================
# createSnapshotMap
#------------------------------------------
sub createSnapshotMap {
	my $this = shift;
	my $readOnlyRootImage = shift;
	my $cowfile = shift;
	my $snapshotChunk=8;
	my $snapshotCount="5G";
	my $imageLoop;
	my $snapLoop;
	my @releaseList = ();
	my $snapshotMap;
	my $orig_s;
	my $data;
	my $code;
	my %result;
	my $table;
	#======================================
	# create root filesystem loop device
	#--------------------------------------
	$imageLoop = qxx ("losetup -s -f $readOnlyRootImage 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$result{stack} = \@releaseList;
		return undef;
	}
	chomp $imageLoop;
	push (@releaseList,"losetup -d $imageLoop");
	#======================================
	# create snapshot loop device
	#--------------------------------------
	if (! -f $cowfile) {
		$data = qxx (
			"dd if=/dev/zero of=$cowfile bs=1 seek=$snapshotCount count=1 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$result{stack} = \@releaseList;
			return undef;
		}
	}
	$snapLoop = qxx ("losetup -s -f $cowfile");
	$code = $? >> 8;
	if ($code != 0) {
		$result{stack} = \@releaseList;
		return undef;
	}
	chomp $snapLoop;
	push (@releaseList,"losetup -d $snapLoop");
	#======================================
	# setup device mapper tables
	#--------------------------------------
	$orig_s =qxx ("blockdev --getsize $imageLoop"); chomp $orig_s;
	qxx ("echo '0 $orig_s linear $imageLoop 0' | dmsetup create ms_data");
	push (@releaseList,"dmsetup remove ms_data");
	qxx ("dmsetup create ms_origin --notable");
	push (@releaseList,"dmsetup remove ms_origin");
	qxx ("dmsetup table ms_data | dmsetup load ms_origin");
	qxx ("dmsetup resume ms_origin");
	qxx ("dmsetup create ms_snap --notable");
	push (@releaseList,"dmsetup remove ms_snap");
	$table = "0 $orig_s snapshot $imageLoop $snapLoop p $snapshotChunk";
	qxx ("echo '$table' | dmsetup load ms_snap");
	$table = "0 $orig_s snapshot-origin $imageLoop";
	qxx ("echo '$table' | dmsetup load ms_data");
	qxx ("dmsetup resume ms_snap");
	qxx ("dmsetup resume ms_data");
	#======================================
	# return result
	#--------------------------------------
	$snapshotMap = "/dev/mapper/ms_snap";
	$result{mount} = $snapshotMap;
	$result{stack} = \@releaseList;
	return %result;
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
