#================
# FILE          : KIWIURL.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to support the high level
#               : source locations like opensuse://
#               :
# STATUS        : Development
#----------------
package KIWIURL;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Cwd qw (realpath);
use Carp qw (cluck);
use File::Basename;
use FileHandle;
use LWP;
#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILog;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIURL object which is used to solve
	# the high level location information into a low level
	# distribution independent network url
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
	my $cmdL = shift;
	my $root = shift;
	my $user = shift;
	my $pwd  = shift;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi} = KIWILog -> instance();
	$this->{root} = $root;
	$this->{user} = $user;
	$this->{pwd}  = $pwd;
	$this->{type} = "unknown";
	$this->{cmdL} = $cmdL;
	#==========================================
	# Store object data
	#------------------------------------------
	my $global = KIWIGlobals -> instance();
	$this->{gdata}= $global ->getKiwiConfig ();

	#==========================================
	# Store object data
	#------------------------------------------
	$this->{alias} = $this -> readRepoAliasTable();
	return $this;
}

#==========================================
# getRepoType
#------------------------------------------
sub getRepoType {
	# ...
	# return repo type, could be unknown
	# ---
	my $this = shift;
	return $this->{type};
}

#==========================================
# normalizePath
#------------------------------------------
sub normalizePath {
	# ...
	# check all path functions and normalize the high level
	# URLs if required. This function also quotes reserved
	# characters in an URL.
	# ---
	my $this   = shift;
	my $module = shift;
	my $kiwi   = $this->{kiwi};
	my $path;
	if ($this->{alias}{$module}) {
		$module = $this->{alias}{$module};
	}
	$module = $this -> quote ($module);
	$path = $this -> thisPath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> obsPath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> openSUSEpath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> isoPath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> smbPath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> plainPath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> dirPath ($module);
	if (defined $path) {
		return $path;
	}
	$module = $this -> __realPath ($module);
	return $module;
}

#==========================================
# normalizeBootPath
#------------------------------------------
sub normalizeBootPath {
	# ...
	# check local path functions and normalize the high level
	# URLs if required. This function is meant to be called
	# on the value of the boot attribute only
	# ---
	my $this   = shift;
	my $module = shift;
	my $kiwi   = $this->{kiwi};
	my $path;
	if (! $module) {
		return;
	}
	$module = $this -> quote ($module);
	$path = $this -> thisPath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> obsPath ($module,"boot");
	if (defined $path) {
		return $path;
	}
	$path = $this -> systemPath ($module);
	if (defined $path) {
		return $path;
	}
	$path = $this -> dirPath ($module);
	if (defined $path) {
		return $path;
	}
	return $module;
}

#==========================================
# quote
#------------------------------------------
sub quote {
	# ...
	# Each part of a URL, e.g. the path info,
	# the query, etc., has a different set of reserved characters that
	# must be quoted.
	#
	# RFC 2396 Uniform Resource Identifiers (URI): Generic Syntax lists
	# the following reserved characters.
	#
	# reserved    = ";" | "?" | ":" | "@" | "&" | "=" | "+" | "$" | "," | "/"
	#
	# This function will quote the user name and password of a given
	# URL string identified by .*://<user>:<pwd>@...
	# ---
	my $this = shift;
	my $surl = shift;
	my $part1;
	my $part2;
	my $part3;
	my $part4;
	my $ordinary = 1;
	$surl =~ s/^[ \t]+//g;
	$surl =~ s/[ \t]+$//g;
	if ($surl =~ /^(.*:\/\/)(.*):(.*)(\@.*)$/) {
		$part1 = $1;
		$part2 = $2;
		$part3 = $3;
		$part4 = $4;
		$ordinary = 0;
	} else {
		$ordinary = 1;
	}
	my $safe = (
		'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-'
	);
	my %safe;
	foreach my $key (split (//,$safe)) {
		$safe{$key} = $key;
	}
	my $run = sub {
		my $part = $_[0];
		my %safe = %{$_[1]};
		my @done = ();
		foreach my $key (split (//,$part)) {
			if (! defined $safe{$key}) {
				$key = sprintf ("%%%02X",ord($key));
			}
			push @done,$key;
		}
		return join ("",@done);
	};
	if (! $ordinary) {
		$part2 = &{$run}($part2,\%safe);
		$part3 = &{$run}($part3,\%safe);
		return $part1.$part2.":".$part3.$part4;
	} else {
		if ($surl !~ /^(http|ftp|https)/) {
			$surl =~ s/(["\$`\\])/\\$1/g;
		}
		return $surl;
	}
}

#==========================================
# systemPath
#------------------------------------------
sub systemPath {
	#...
	# This path uses the provided system:// path and
	# prefix it with kiwi's default module system dir
	#---
	my $this   = shift;
	my $module = shift;
	my $prefix = $this->{gdata}->{System};
	my $kiwi   = $this->{kiwi};
	my $path    = undef;
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^system:\/\//)) {
		return;
	}
	$module =~ s/system:\/\///;
	$path = $this -> dirPath ("dir://".$prefix."/".$module);
	return $path;
}

#==========================================
# thisPath
#------------------------------------------
sub thisPath {
	# ...
	# This method builds a valid path from a this://..
	# description. The this path is the same as where the
	# image description tree resides
	# ---
	my $this   = shift;
	my $module = shift;
	my $cmdL   = $this->{cmdL};
	my $kiwi   = $this->{kiwi};
	my $cdir   = $cmdL->getConfigDir();
	my $xmlinfo= $cmdL->getOperationMode ("listXMLInfo");
	my $create = $cmdL->getOperationMode ("create");
	my $upgrade= $cmdL->getOperationMode ("upgrade");
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^this:\/\//)) {
		return;
	}
	$module =~ s/this:\/\///;
	if ((! defined $module) || ($module eq "/")) {
		return;
	}
	my $thisPath;
	my $lookup;
	#==========================================
	# standard path expansion
	#------------------------------------------
	if ((defined $xmlinfo) && (-d $xmlinfo)) {
		# this path is config dir set by --info option
		$thisPath = $xmlinfo."/".$module;
	} elsif (defined $create) {
		# set lookup file to search for this path
		$lookup = "$create/image/main::Prepare";
	} elsif (defined $upgrade) {
		# set lookup file to search for this path
		$lookup = "$upgrade/image/main::Prepare";
	} else {
		if ((defined $cdir) && (-d $cdir)) {
			# this path is config dir if it exists
			$thisPath = $cdir."/".$module;
		} else {
			# this path is config dir set by --prepare
			$thisPath = $cmdL->getOperationMode("prepare");
			$thisPath.= "/".$module;
		}
	}
	#==========================================
	# extra path expansion by lookup file
	#------------------------------------------
	if (defined $lookup) {
		my $FD;
		if (! open $FD, '<', $lookup) {
			return;
		}
		$thisPath = <$FD>;
		close $FD;
		$thisPath = $thisPath."/".$module;
	}
	#==========================================
	# turn into absolute path
	#------------------------------------------
	if ($thisPath !~ /^\//) {
		my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
		$thisPath = $pwd."/".$thisPath;
	}
	$thisPath =~ s/\/\.\//\//g;
	$thisPath =~ s/\/+/\//g;
	$thisPath = $this -> __realPath ($thisPath);
	return $thisPath;
}

#==========================================
# dirPath
#------------------------------------------
sub dirPath {
	my $this   = shift;
	my $module = shift;
	my $kiwi   = $this->{kiwi};
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^dir:\/\//)) {
		return;
	}
	$module =~ s/dir:\/\///;
	if ($module !~ /^\//) {
		my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
		$module = $pwd."/".$module;
	}
	my ( $module_test ) = glob ($module);
	if (! -e $module_test) {
		$kiwi -> warning ("dir path: $module_test doesn't exist: $!");
		$kiwi -> skipped ();
		return;
	}
	$module = $this -> __realPath ($module);
	return $module;
}

#==========================================
# smbPath
#------------------------------------------
sub smbPath {
	# ...
	# This method pass along the smb mount path to the
	# packagemanager. The smb prefix will only work for
	# zypper at the moment
	# ---
	my $this   = shift;
	my $module = shift;
	my $kiwi   = $this->{kiwi};
	my $root   = $this->{root};
	my $user   = $this->{user};
	my $pwd    = $this->{pwd};
	my $result;
	my $status;
	my $name;
	my $tmpdir;
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^smb:\/\//)) {
		return;
	}
	$module =~ s/^smb://;
	#==========================================
	# create SMB mount point and perform mount
	#------------------------------------------
	if (! defined $root) {
		return $tmpdir;
	}
	$tmpdir = KIWIQX::qxx ("mktemp -qdt kiwimount.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Couldn't create tmp dir for smb mount: $tmpdir: $!");
		$kiwi -> skipped ();
		return;
	}
	if (($user) && ($pwd)) {
		$status = KIWIQX::qxx (
	      "mount -t cifs -o username=$user,passwort=$pwd $module $tmpdir 2>&1"
		);
	} else {
		$status = KIWIQX::qxx ("mount -t cifs -o guest $module $tmpdir 2>&1");
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Failed to mount share $module: $status");
		$kiwi -> skipped ();
		return;
	}
	#==========================================
	# add mount to mount list of root obj
	#------------------------------------------
	$root -> addToMountList ($tmpdir);
	return $tmpdir;
}

#==========================================
# obsPath
#------------------------------------------
sub obsPath {
	# ...
	# This method will create an openSUSE buildservice
	# path as this:// url with the predefined subdirectories
	# images/ if called as part of a boot attribute or
	# repos if called as part of a repository source path
	# attribute
	# ---
	my $this   = shift;
	my $module = shift;
	my $boot   = shift;
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^obs:\/\//)) {
		return;
	}
	$module =~ s/obs:\/\///;
	if ((! defined $module) || ($module eq "/")) {
		return;
	}
	if (defined $boot) {
		$module = "this://images/$module"
	} else {
		$module = "this://repos/$module"
	}
	my $path = $this -> thisPath ($module);
	if ((! $path) || (! -d $path)) {
		return;
	}
	return $path;
}

#==========================================
# isoPath
#------------------------------------------
sub isoPath {
	# ...
	# This method builds a valid path from a iso://...
	# description. The iso woll be loop mounted and
	# the loop location serves as source path
	# ---
	my $this   = shift;
	my $module = shift;
	my $kiwi   = $this->{kiwi};
	my $root   = $this->{root};
	my $result;
	my $status;
	my $file;
	my $path;
	my $search;
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module)      || (
		($module !~ /^iso:\/\//) && 
		($module !~ /^file:\/\//))
	) {
		return;
	}
	$module =~ s/^iso:\/\///;
	$module =~ s/^file:\/\///;
	#==========================================
	# Convert zypper iso URL if required
	#------------------------------------------
	if ($module =~ /iso=(.*\.iso)/) {
		$file = $1;
		if ($module =~ /url=file:\/\/(.*)/) {
			$path = $1;
		} elsif ($module =~ /url=dir:\/\/(.*)/) {
			$path = $1;
		} else {
			return;
		}
		$module = $path."/".$file;
	}
	#==========================================
	# Check existence of iso file
	#------------------------------------------
	if ($module !~ /^\//) {
		my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
		$module = $pwd."/".$module;
	}
	if ($module =~ /(.*\.iso)(.*)/) {
		$module = $1;
		$search = $2;
	}
	$module = $this -> __realPath ($module);
	my ( $module_test ) = glob ($module);
	if (! -e $module_test) {
		$kiwi -> warning ("ISO path: $module_test doesn't exist: $!");
		$kiwi -> skipped ();
		return;
	}
	my $name   = basename ($module);
	my $tmpdir = "/tmp/kiwimount-$name";
	#==========================================
	# create ISO mount point and perform mount
	#------------------------------------------
	if (! defined $root) {
		return $tmpdir;
	}
	$status = KIWIQX::qxx ("mkdir -p $tmpdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Couldn't create tmp dir for iso mount: $status: $!");
		$kiwi -> skipped ();
		return;
	}
	$status = KIWIQX::qxx ("mount -o loop $module $tmpdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Failed to loop mount ISO path: $status");
		$kiwi -> skipped ();
		return;
	}
	#==========================================
	# add loop mount to mount list of root obj
	#------------------------------------------
	$root -> addToMountList ($tmpdir);
	if ($search) {
		return "$tmpdir/$search";
	} else {
		return $tmpdir;
	}
}

#==========================================
# openSUSEpath
#------------------------------------------
sub openSUSEpath {
	# ...
	# This method builds a valid URL path to be used as
	# source location for an openSUSE installation source.
	# The method needs the basic openSUSE distribution or
	# module repository name information to be able to
	# complete this data into a valid path
	# ---
	my $this     = shift;
	my $module   = shift;
	my $quiet    = shift;
	my $kiwi     = $this->{kiwi};
	my $browser  = LWP::UserAgent->new;
	my $uriTable = $this->{gdata}->{repoURI};
	my $origurl  = $module;
	my %matches  = ();
	#==========================================
	# allow proxy server from environment
	#------------------------------------------
	$browser->env_proxy();
	$browser->timeout(30);
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^(opensuse|obs):\/\//)) {
		return;
	}
	$module =~ s/opensuse:\/\///;
	$module =~ s/obs:\/\///;
	$module =~ s/\/$//;
	$module =~ s/^\///;
	if ((! defined $module) || ($module eq "")) {
		return;
	}
	#==========================================
	# Create URL list from URI table
	#------------------------------------------
	my $FD = FileHandle -> new();
	if (! $FD -> open ($uriTable)) {
		return;
	}
	while (my $match =<$FD>) {
		chomp $match;
		my ($match_type,$exp_match,$exp_replace) = split (/\|/,$match);
		my $repo_uri = $module;
		if ($repo_uri =~ s/$exp_match/$exp_replace/) {
			$matches{$repo_uri} = $match_type;
		}
	}
	$FD -> close();
	#==========================================
	# Check URL entries
	#------------------------------------------
	foreach my $url (sort keys %matches) {
		my $type = $matches{$url};
		if ($type ne "opensuse") {
			next;
		}
		foreach my $lookup ("/repodata/repomd.xml","/media.1/media") {
			#==========================================
			# Try to access URL from matches
			#------------------------------------------
			my $response = $browser -> get ( $url.$lookup );
			if ($response -> is_success) {
				if ($lookup eq "/repodata/repomd.xml") {
					$this->{type} = "rpm-md";
				} else {
					$this->{type} = "yast2";
				}
				return $url;
			}
		}
	}
	if (! defined $quiet) {
		$kiwi -> warning ("Couldn't resolve opensuse URL: $origurl");
		$kiwi -> skipped ();
	}
	return;
}

#==========================================
# plainPath
#------------------------------------------
sub plainPath {
	# ...
	# This method forwards the URL (everything following "plain://")
	# unmodified to the package manager. This can be used if kiwi
	# does not support a special URL but the package manager does.
	# ---
	my $this   = shift;
	my $module = shift;
	my $kiwi   = $this->{kiwi};
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^plain:\/\//)) {
		return;
	}
	$module =~ s/^plain:\/\///;
	$kiwi -> loginfo (
		"URL: $module will be forwarded AS IS to the package manger!\n"
	);
	return $module;
}

#==========================================
# readRepoAliasTable
#------------------------------------------
sub readRepoAliasTable {
	# ...
	# There is the optional /etc/kiwi/repoalias file which
	# contains an alternative location for a specific repo
	# This function reads in the file and provides an alias
	# hash table which is used to check if the given repo
	# has an alternative location to use
	# ---
	my $FD = FileHandle -> new();
	my %repohash;
	if (! $FD -> open ('/etc/kiwi/repoalias')) {
		return \%repohash;
	}
	while (my $line = <$FD>) {
		next if $line =~ /^#/;
		if ($line =~ /({.*})\s*(.*)/) {
			my $alias= $1;
			my $repo = $2;
			$repohash{$alias} = $repo;
		}
	}
	$FD -> close();
	return \%repohash;
}

#==========================================
# __realPath
#------------------------------------------
sub __realPath {
	# ...
	# make sure a local path is stored with its absolute
	# path. in any other case leave it untouched
	# ---
	my $this = shift;
	my $uri  = shift;
	if (-e $uri) {
		$uri = realpath ($uri);
	}
	return $uri;
}

1;
