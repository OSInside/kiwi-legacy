#================
# FILE          : KIWIFilesystemOptions.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Represent filesystem options settings and data
#               :
# STATUS        : Development
#----------------
package KIWIFilesystemOptions;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Readonly;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILog;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# constants
#------------------------------------------
Readonly my $INODERATIO   => 16_384;
Readonly my $INODESIZE    => 256;
Readonly my $MINNUMINODES => 20_000;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIFilesystemOptions object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	my $options = shift;
	my $kiwi = KIWILog -> instance();
	if (! $options || ref($options) ne 'HASH') {
		my $msg = 'KIWIFilesystemOptions: expecting a hash ref as '
			. 'argument.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %supportedOpts = map { ($_ => 1) } qw(
		blocksize
		checkinterval
		inodesize
		inoderatio
		journalsize
		maxmountcnt
	);
	for my $entry (keys %{$options}) {
		if (! $supportedOpts{$entry} ) {
			my $msg = 'KIWIFilesystemOptions: unsupported filesystem option '
				. "entry '$entry'.";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	$this->{blocksize}     = $options->{blocksize};
	$this->{checkinterval} = $options->{checkinterval};
	$this->{inodesize}     = $options->{inodesize};
	$this->{inoderatio}    = $options->{inoderatio};
	$this->{journalsize}   = $options->{journalsize};
	$this->{maxmountcnt}   = $options->{maxmountcnt};
	#========================================
	# set defsult values
	#----------------------------------------
	if (! $options->{inoderatio}) {
		$this->{defaultInoderatio} = 1;
		$this->{inoderatio} = $INODERATIO;
	}
	if (! $options->{inodesize}) {
		$this->{defaultInodesize} = 1;
		$this->{inodesize} = $INODESIZE;
	}
	return $this;
}

#==========================================
# getInodeRatio
#------------------------------------------
sub getInodeRatio {
	# ...
	# Return the configured inode ratio
	# ---
	my $this = shift;
	return $this->{inoderatio};
}

#==========================================
# getInodeSize
#------------------------------------------
sub getInodeSize {
	# ...
	# Return the configured inode size
	# ---
	my $this = shift;
	return $this->{inodesize};
}

#==========================================
# getFSBlockSize
#------------------------------------------
sub getFSBlockSize {
	# ...
	# Return the configured filesystem blocksize
	# ---
	my $this = shift;
	return $this->{blocksize};
}

#==========================================
# setFSBlockSize
#------------------------------------------
sub setFSBlockSize {
	# ...
	# Set the given filesystem blocksize value
	# ---
	my $this = shift;
	my $blocksize = shift;
	if (! $blocksize) {
		undef $this->{blocksize};
	} else {
		$this->{blocksize} = $blocksize;
	}
	return $this;
}

#==========================================
# getMinNumInodes
#------------------------------------------
sub getMinNumInodes {
	# ...
	# Return the minimum number of inodes a filesystem should have
	# ---
	my $this = shift;
	return $MINNUMINODES;
}

#==========================================
# getOptionsStrBtrfs
#------------------------------------------
sub getOptionsStrBtrfs {
	# ...
	# Return an options string for btrfs filesystems based on the
	# defined options.
	# ---
	my $this = shift;
	my $opts = q{};
	if (! $this->{defaultInodesize} && $this->{inodesize}) {
		$opts .= '-n ' . $this->{inodesize};
	}
	return $opts;
}

#==========================================
# getOptionsStrExt
#------------------------------------------
sub getOptionsStrExt {
	# ...
	# Return an options string for ext filesystems based on the
	# defined options.
	# ---
	my $this = shift;
	my $opts = q{};
	if ($this->{blocksize}) {
		$opts .= '-b ' . $this->{blocksize};
	}
	if (! $this->{defaultInodesize}) {
		$opts .= ' -I ' . $this->{inodesize};
	}
	if (! $this->{defaultInoderatio}) {
		$opts .= ' -i ' . $this->{inoderatio};
	}
	if ($this->{journalsize}) {
		$opts .= ' -J size=' . $this->{journalsize};
	}
	$opts .= ' -F -O resize_inode';
	return $opts;
}

#==========================================
# getOptionsStrReiser
#------------------------------------------
sub getOptionsStrReiser {
	# ...
	# Return an options string for the reiser filesystem based on the
	# defined options.
	# ---
	my $this = shift;
	my $opts = q{};
	if ($this->{blocksize}) {
		$opts .= '-b ' . $this->{blocksize};
	}
	if ($this->{journalsize}) {
		$opts .= ' -s ' . $this->{journalsize};
	}
	return $opts;
}

#==========================================
# getOptionsStrXFS
#------------------------------------------
sub getOptionsStrXFS {
	# ...
	# Return an options string for xfs filesystems based on the
	# defined options.
	# ---
	my $this = shift;
	my $opts = q{};
	if ($this->{blocksize}) {
		$opts .= '-b size=' . $this->{blocksize};
	}
	if (! $this->{defaultInodesize} && $this->{inodesize}) {
		$opts .= ' -i size=' . $this->{inodesize};
	}
	if ($this->{journalsize}) {
		$opts .= ' -l size=' . $this->{journalsize};
	}
	return $opts;
}

#==========================================
# getTuneOptsExt
#------------------------------------------
sub getTuneOptsExt {
	# ...
	# Return a tune options string for ext filesystems based on the
	# defined options.
	# ---
	my $this = shift;
	my $opts = q{};
	if ($this->{maxmountcnt}) {
		$opts .= '-c ' . $this->{maxmountcnt};
	}
	if ($this->{checkinterval}) {
		$opts .= ' -i ' . $this->{checkinterval};
	}
	return $opts;
}

1;
