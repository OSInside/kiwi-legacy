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
	return $this;
}

#==========================================
# mountOverlay
#------------------------------------------
sub mountOverlay {
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
# resetOverlay
#------------------------------------------
sub resetOverlay {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $tmpdir = $this->{tmpdir};
	my $inodir = $this->{inodir};
	my $data;
	my $code;
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
