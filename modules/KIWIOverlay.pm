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
	my $baseRO = shift;
	my $rootRW = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! -e $baseRO) {
		$kiwi -> error  ("File/Directory $baseRO doesn't exist");
		$kiwi -> failed ();
		return undef;
	}
	if (! -d $rootRW) {
		$kiwi -> error ("Directory $rootRW doesn't exist");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}   = $kiwi;
	$this->{baseRO} = $baseRO;
	$this->{rootRW} = $rootRW;
	$this->{mode}   = "copy";
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
	#==========================================
	# Check result of filesystem detection
	#------------------------------------------
	if (! %fsattr) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect filesystem on: $baseRO");
		return undef;
	}
	#==========================================
	# Check for CLIC extension
	#------------------------------------------
	if ($type ne "clicfs") {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't detect clicfs on: $baseRO");
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
	if (! -f $cowdev) {
		#==========================================
		# Create tmp COW file for write operations
		#------------------------------------------
		$status = qxx ("cat < /dev/null > $cowdev 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to create overlay COW file: $status");
			return undef;
		}
	} else {
		$haveCow=1;
	}
	$this->{cowdev} = $cowdev;
	#==========================================
	# Mount the clicfs (free space = 5GB)
	#------------------------------------------
	$status = qxx ("/sbin/losetup -s -f $baseRO 2>&1"); chomp $status;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't loop bind overlay: $status");
		return undef;
	}
	push @mount,"sleep 1; losetup -d $status";
	$this->{mount} = \@mount;
	$baseRO = $status;
	$status = qxx (
		"clicfs --ignore-cow-errors -m 5000 -c $cowdev $baseRO $tmpdir 2>&1"
	);
	$result = $? >> 8;
	if ($result == 0) {
		$status = qxx ("resize2fs $tmpdir/fsdata.ext3 2>&1");
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to mount $baseRO to: $tmpdir: $status");
		return undef;
	}
	push @mount,"umount $tmpdir";
	$this->{mount} = \@mount;
	my $opts = "loop,noatime,nodiratime,errors=remount-ro,barrier=0";
	$baseRO = $tmpdir."/fsdata.ext3";
	$status = qxx ("mount -o $opts $baseRO $tmpdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to loop mount $baseRO to: $tmpdir: $status");
		return undef;
	}
	push @mount,"umount $tmpdir";
	if (! $haveCow) {
		qxx ("echo $this->{baseRO} > $rootRW/kiwi-root.cache");
		qxx ("mkdir -p $rootRW/image");
		$status = qxx ("cp $tmpdir/image/config.xml $rootRW/image 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$status = qxx ("cp $tmpdir/image/*.kiwi $rootRW/image 2>&1");
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to copy XML file: $status");
			return undef;
		}
	}
	$this->{mount} = \@mount;
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

1;
