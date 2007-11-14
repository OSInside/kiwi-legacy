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
use KIWILog;

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
	if (! -d $baseRO) {
		$kiwi -> error  ("Directory $baseRO doesn't exist");
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
	my $tmpdir;
	my $inodir;
	my $result;
	$tmpdir = qx ( mktemp -q -d /tmp/kiwiRootOverlay.XXXXXX ); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to create overlay tmpdir");
		$kiwi -> failed ();
		return undef;
	}
	$inodir = qx ( mktemp -q -d /tmp/kiwiRootInode.XXXXXX ); chomp $inodir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to create overlay inode tmpdir");
		$kiwi -> failed ();
		return undef;
	}
	my $opts = "dirs=$rootRW=rw:$baseRO=ro";
	my $xino = "$inodir/.aufs.xino";
	my $data = qx ( mount -t tmpfs tmpfs $inodir );
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("tmpfs mount failed: $data");
		$kiwi -> failed ();
		return undef;
	}
	$data = qx ( mount -t aufs -o $opts,xino=$xino aufs $tmpdir 2>&1);
	$code = $? >> 8;
	if ($code != 0) {
		$data = qx (mount -t unionfs -o $opts unionfs $tmpdir 2>&1);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Overlay mount failed: $data");
			$kiwi -> failed ();
			return undef;
		}
	}
	$this->{tmpdir} = $tmpdir;
	$this->{inodir} = $inodir;
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
	$data = qx (tar -C $baseRO -cz --to-stdout . | tar -C $rootRW -xz);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to tar/untar base tree: $data");
		$kiwi -> failed ();
		return undef;
	}
	return $rootRW;
}

#==========================================
# resetOverlay
#------------------------------------------
sub resetOverlay {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $tmpdir = $this->{tmpdir};
	my $inodir = $this->{inodir};
	my $data;
	my $code;
	if ($this->{mode} eq "copy") {
		return $this;
	}
	$data = qx (umount $tmpdir 2>&1);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> warning ("Failed to umount overlay: $data");
		$kiwi -> skipped ();
	}
	$data = qx (umount $inodir 2>&1);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> warning ("Failed to umount tmpfs: $data");
		$kiwi -> skipped ();
	}
	if (! rmdir $tmpdir) {
		$kiwi -> warning ("Failed to remove overlay: $!");
		$kiwi -> skipped ();
	}
	if (! rmdir $inodir) {
		$kiwi -> warning ("Failed to remove tmpfs: $!");
		$kiwi -> skipped ();
	}
	return $this;
}

1;
