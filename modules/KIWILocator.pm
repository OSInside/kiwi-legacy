#================
# FILE          : KIWILocator.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
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
require Exporter;
use KIWILog;
use KIWIQX;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (createTmpDirectory getExecPath getControlFile );

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
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
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
	my $rootError     = 1;
	my $root;
	my $code;
	my $kiwi = $this->{kiwi};
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
			if ( -e $root && -d $root && $main::ForceNewRoot ) {
				$kiwi -> info ("Removing old root directory '$root'");
				if (-e $root."/base-system") {
					$kiwi -> failed();
					$kiwi -> info  ("Mount point /base-system exists");
					$kiwi -> failed();
					return undef;
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
			$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return undef;
	}
	if ( $rootError ) {
		return undef;
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
	my $this   = shift;
	my $dir    = shift;
	my $kiwi   = $this->{kiwi};
	if (! -d $dir) {
		my $msg = "Expected a directory at $dir.\nSpecify a directory";
		$msg .= ' as the configuration base.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	my $config = "$dir/" . $this->{configName};
	if (-f $config) {
		return $config;
	}
	my @globsearch = glob ($dir."/*.kiwi");
	my $globitems  = @globsearch;
	if ($globitems == 0) {
		$kiwi -> error ( "Could not locate a configuration file in $dir");
		$kiwi -> failed();
		return undef;
	} elsif ($globitems > 1) {
		my $msg = "Found multiple control files in $dir\n";
		for my $item (@globsearch) {
			$msg .= "\t$item\n";
		}
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	} else {
		$config = pop @globsearch;
	}
	return $config;
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
# getExecPath
#--------------------------------------------
sub getExecPath {
	my $this     = shift;
	my $execName = shift;
	my $kiwi     = $this->{kiwi};
	my $execPath = qxx ("which $execName 2>&1"); chomp $execPath;
	my $code = $? >> 8;
	if ($code != 0) {
		if ($kiwi) {
			$kiwi -> loginfo ("warning: $execName not found\n");
		}
		return undef;
	}
	return $execPath;
}

1;
