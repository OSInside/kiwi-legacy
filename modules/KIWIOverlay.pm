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
	#==========================================
	# Check result of filesystem detection
	#------------------------------------------
	if (! %fsattr) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect filesystem on: $baseRO");
		return;
	}
	#==========================================
	# Check for ext2 extension
	#------------------------------------------
	if ($type ne "ext2") {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect ext2 on: $baseRO");
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
	# Create snapshot map
	#------------------------------------------
	%snapshot = $this -> createSnapshotMap ($baseRO,$cowdev);
	if (! %snapshot) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to snapshot $baseRO");
		return;
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
		return;
	}
	push @mount,"umount $tmpdir";
	$this->{mount} = \@mount;
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
		qxx ("rm -rf $tmpdir 2>&1");
	}
	return $this;
}

#==========================================
# createSnapshotMap
#------------------------------------------
sub createSnapshotMap {
	my $this = shift;
	my $readOnlyRootImage = shift;
	my $cowfile = shift;
	my $snapshotChunk = $this->{gdata}->{SnapshotChunk};
	my $snapshotCount = $this->{gdata}->{SnapshotCount};
	my $imageLoop;
	my $snapLoop;
	my @releaseList = ();
	my $snapshotMap;
	my $orig_s;
	my $data;
	my $code;
	my %result;
	my $table;
	my $range = 0xfe;
	my $tsalt = 1 + int (rand($range));
	#======================================
	# create root filesystem loop device
	#--------------------------------------
	$imageLoop = qxx ("losetup -f --show $readOnlyRootImage 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$result{stack} = \@releaseList;
		return;
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
			return;
		}
	}
	$snapLoop = qxx ("losetup -f --show $cowfile");
	$code = $? >> 8;
	if ($code != 0) {
		$result{stack} = \@releaseList;
		return;
	}
	chomp $snapLoop;
	push (@releaseList,"losetup -d $snapLoop");
	#======================================
	# setup device mapper tables
	#--------------------------------------
	$orig_s =qxx ("blockdev --getsize $imageLoop"); chomp $orig_s;
	qxx ("echo '0 $orig_s linear $imageLoop 0'|dmsetup create ms_data_$tsalt");
	push (@releaseList,"dmsetup remove ms_data_$tsalt");
	qxx ("dmsetup create ms_origin_$tsalt --notable");
	push (@releaseList,"dmsetup remove ms_origin_$tsalt");
	qxx ("dmsetup table ms_data_$tsalt | dmsetup load ms_origin_$tsalt");
	qxx ("dmsetup resume ms_origin_$tsalt");
	qxx ("dmsetup create ms_snap_$tsalt --notable");
	push (@releaseList,"dmsetup remove ms_snap_$tsalt");
	$table = "0 $orig_s snapshot $imageLoop $snapLoop p $snapshotChunk";
	qxx ("echo '$table' | dmsetup load ms_snap_$tsalt");
	$table = "0 $orig_s snapshot-origin $imageLoop";
	qxx ("echo '$table' | dmsetup load ms_data_$tsalt");
	qxx ("dmsetup resume ms_snap_$tsalt");
	qxx ("dmsetup resume ms_data_$tsalt");
	#======================================
	# return result
	#--------------------------------------
	$snapshotMap = "/dev/mapper/ms_snap_$tsalt";
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
