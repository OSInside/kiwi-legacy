#================
# FILE          : KIWILocator.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to perform operations
#               : on the local filesystem
#               :
# STATUS        : Development
#----------------
package KIWILocator;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use base qw (Exporter);

use IPC::Open3;
use KIWILog;
use KIWIQX qw (qxx);

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the Locator object
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
	# Store object data
	#------------------------------------------
	$this->{configName}  = 'config.xml';
	$this->{defCacheDir} = '/var/cache/kiwi/image';
	$this->{kiwi}        = $kiwi;
	return $this;
}

#==========================================
# createTmpDirectory
#------------------------------------------
sub createTmpDirectory {
	my $this          = shift;
	my $useRoot       = shift;
	my $selfRoot      = shift;
	my $cmdL          = shift;
	my $rootError     = 1;
	my $root;
	my $code;
	my $kiwi = $this->{kiwi};
	my $forceRoot = $cmdL -> getForceNewRoot();
	if (! defined $useRoot) {
		if (! defined $selfRoot) {
			$root = qxx (" mktemp -q -d /tmp/kiwi.XXXXXX ");
			$code = $? >> 8;
			if ($code == 0) {
				$rootError = 0;
			}
			chomp $root;
		} else {
			$root = $selfRoot;
			rmdir $root;
			if ( -e $root && -d $root && $forceRoot ) {
				$kiwi -> info ("Removing old root directory '$root'");
				my $status = qxx ("cat /proc/mounts | grep '$root' 2>&1");
				my $result = $? >> 8;
				if ($result == 0) {
					$kiwi -> failed();
					$kiwi -> error  ("Found active mount points in '$root'");
					$kiwi -> failed();
					return;
				}
				qxx ("rm -R $root");
				$kiwi -> done();
			}
			if (mkdir $root) {
				$rootError = 0;
			}
		}
	} else {
		if (-d $useRoot) {
			$root = $useRoot;
			$rootError = 0;
		}
	}
	if ( $rootError ) {
		if ($kiwi -> trace()) {
			$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return;
	}
	if ( $rootError ) {
		return;
	}
	return $root;
}

#==========================================
# getControlFile
#------------------------------------------
sub getControlFile {
	# /.../
	# This function receives a directory as parameter
	# and searches for a kiwi xml description in it.
	# ----
	my $this    = shift;
	my $dir     = shift;
	my $kiwi    = $this->{kiwi};
	my @subdirs = ("/","/image/");
	my $found   = 0;
	my @globsearch;
	my $config;
	if (! -d $dir) {
		my $msg = "Expected a directory at $dir.\nSpecify a directory";
		$msg .= ' as the configuration base.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	foreach my $search (@subdirs) {
		$config = $dir.$search.$this->{configName};
		if (-f $config) {
			$found = 1; last;
		}
		@globsearch = glob ($dir."/*.kiwi");
		my $globitems  = @globsearch;
		if ($globitems == 0) {
			next;
		} elsif ($globitems > 1) {
			$found = 2; last;
		} else {
			$config = pop @globsearch;
			$found = 1; last;
		}
	}
	if ($found == 1) {
		return $config;
	} elsif ($found == 2) {
		my $msg = "Found multiple control files in $dir\n";
		for my $item (@globsearch) {
			$msg .= "\t$item\n";
		}
		$kiwi -> error ($msg);
		$kiwi -> failed();
	} else {
		$kiwi -> error ( "Could not locate a configuration file in $dir");
		$kiwi -> failed();
	}
	return;
}

#============================================
# getDefaultCacheDir
#--------------------------------------------
sub getDefaultCacheDir {
	# ...
	# Return the path of the default cache directory Kiwi uses
	# ---
	my $this = shift;
	return $this -> {defCacheDir};
}

#============================================
# getExecArgsFormat
#--------------------------------------------
sub getExecArgsFormat {
	# ...
	# Return a hash ref of the argument format for the sought after
	# arguments.
	# The method handles long arguments and deals with difference in
	# version where arguments may have changed from -argument to --argument
	# ---
	my $this = shift;
	my $execName = shift;
	my $opts = shift;
	my @optsToGet = @{ $opts };
	my %optInfo;
	my $allOptionsFound;
	my $execPath;
	my $numOptsToGet = @optsToGet;
	my $numOptsFound = 0;
	my $CHILDWRITE;
	my $CHILDSTDOUT;
	my $CHILDSTDERR;
	if (! -f $execName) {
		$execPath = $this -> getExecPath($execName);
		if (! $execPath) {
			$optInfo{'status'} = 0;
			$optInfo{'error'} = "Could not find $execName";
			return \%optInfo;
		} else {
			$execName = $execPath
		}
	}
	my $pid = open3 (
		$CHILDWRITE, $CHILDSTDOUT, $CHILDSTDERR, "$execName --help"
	);
	waitpid( $pid, 0 );
	my $status = $? >> 8;
	my @help = <$CHILDSTDOUT>;
	if (($status) && ($CHILDSTDERR)) {
		my @chldstderr = <$CHILDSTDERR>;
		@help = (@help, @chldstderr);
	}
	HELPOPTS:
	for my $opt (@help) {
		GETOPTS:
		for my $seekOpt (@optsToGet) {
			if ($opt =~ /$seekOpt[,\s]+/x) {
				my @prts = split /[,\s]+/x, $opt;
				OPTLINE:
				for my $item (@prts) {
					if ($item =~ /-+$seekOpt/x) {
						$optInfo{$seekOpt} = $item;
						$numOptsFound += 1;
						last OPTLINE;
					}
				}
			}
		}
		if ($numOptsFound == $numOptsToGet) {
			$allOptionsFound = 1;
			last HELPOPTS;
		}
	}
	if ($allOptionsFound) {
		$optInfo{'status'} = 1;
	} else {
		my @foundOpts = keys %optInfo;
		for my $item (@optsToGet) {
			if (! grep { /$item/x } @foundOpts) {
				my $msg = "Could not find argument $item for $execName";
				$optInfo{'error'} = $msg;
				last;
			}
		}
		$optInfo{'status'} = 0;
	}
	return \%optInfo;
}

#============================================
# getExecPath
#--------------------------------------------
sub getExecPath {
	# ...
	# Return the full path of the given executable
	# ---
	my $this     = shift;
	my $execName = shift;
	my $kiwi     = $this->{kiwi};
	my $execPath = qxx (
		"bash -c \"PATH=\$PATH:/sbin which $execName\" 2>&1"
	);
	chomp $execPath;
	my $code = $? >> 8;
	if ($code != 0) {
		if ($kiwi) {
			$kiwi -> loginfo ("warning: $execName not found\n");
		}
		return;
	}
	return $execPath;
}



1;
