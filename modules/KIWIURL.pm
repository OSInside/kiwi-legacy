#================
# FILE          : KIWIURL.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
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
use Carp qw (cluck);
use File::Basename;
use KIWILog;
use LWP;
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
	my $kiwi = shift;
	my $root = shift;
	my $user = shift;
	my $pwd  = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	$this->{root} = $root;
	$this->{user} = $user;
	$this->{pwd}  = $pwd;
	$this->{type} = "unknown";
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{alias} = readRepoAliasTable();
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
	my %safe = {};
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
	my $prefix = $main::System;
	my $kiwi   = $this->{kiwi};
	my $path    = undef;
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^system:\/\//)) {
		return undef;
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
	my $kiwi;
	if (! defined $this->{kiwi}) {
		$kiwi = new KIWILog("tiny");
	} else {
		$kiwi = $this->{kiwi};
	}
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^this:\/\//)) {
		return undef;
	}
	$module =~ s/this:\/\///;
	if ((! defined $module) || ($module eq "/")) {
		return undef;
	}
	my $thisPath;
	if ((defined $main::ImageDescription) && (-d $main::ImageDescription)) {
		$thisPath = $main::ImageDescription;
		$thisPath = "$thisPath/$module";
	} elsif ((defined $main::ListXMLInfo) && (-d $main::ListXMLInfo)) {
		$thisPath = $main::ListXMLInfo;
		$thisPath = "$thisPath/$module";
	} elsif (defined $main::Create) {
		if (! open FD,"$main::Create/image/main::Prepare") {
			return undef;
		}
		$thisPath = <FD>; close FD;
		$thisPath = "$thisPath/$module";
	} elsif (defined $main::Upgrade) {
		if (! open FD,"$main::Upgrade/image/main::Prepare") {
			return undef;
		}
		$thisPath = <FD>; close FD;
		$thisPath = "$thisPath/$module";
	} else {
		$thisPath = "$main::Prepare/$module";
	}
	if ($thisPath !~ /^\//) {
		my $pwd = qxx ("pwd"); chomp $pwd;
		$thisPath = $pwd."/".$thisPath;
	}
	$thisPath =~ s/\/\.\//\//g;
	$thisPath =~ s/\/+/\//g;
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
		return undef;
	}
	$module =~ s/dir:\/\///;
	if ($module !~ /^\//) {
		my $pwd = qxx ("pwd"); chomp $pwd;
		$module = $pwd."/".$module;
	}
	my ( $module_test ) = glob ($module);
	if (! -e $module_test) {
		$kiwi -> warning ("dir path: $module_test doesn't exist: $!");
		$kiwi -> skipped ();
		return undef;
	}
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
		return undef;
	}
	$module =~ s/^smb://;
	#==========================================
	# create SMB mount point and perform mount
	#------------------------------------------
	if (! defined $root) {
		return $tmpdir;
	}
	$tmpdir = qxx ("mktemp -q -d /tmp/kiwimount.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Couldn't create tmp dir for smb mount: $tmpdir: $!");
		$kiwi -> skipped ();
		return undef;
	}
	if (($user) && ($pwd)) {
		$status = qxx (
			"mount -t cifs -o username=$user,passwort=$pwd $module $tmpdir 2>&1"
		);
	} else {
		$status = qxx ("mount -t cifs -o guest $module $tmpdir 2>&1");
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Failed to mount share $module: $status");
		$kiwi -> skipped ();
		return undef;
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
		return undef;
	}
	$module =~ s/obs:\/\///;
	if ((! defined $module) || ($module eq "/")) {
		return undef;
	}
	if (defined $boot) {
		$module = "this://images/$module"
	} else {
		$module = "this://repos/$module"
	}
	my $path = $this -> thisPath ($module);
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
		return undef;
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
			return undef;
		}
		$module = $path."/".$file;
	}
	#==========================================
	# Check existence of iso file
	#------------------------------------------
	if ($module !~ /^\//) {
		my $pwd = qxx ("pwd"); chomp $pwd;
		$module = $pwd."/".$module;
	}
	if ($module =~ /(.*\.iso)(.*)/) {
		$module = $1;
		$search = $2;
	}
	my ( $module_test ) = glob ($module);
	if (! -e $module_test) {
		$kiwi -> warning ("ISO path: $module_test doesn't exist: $!");
		$kiwi -> skipped ();
		return undef;
	}
	my $name   = basename ($module);
	my $tmpdir = "/tmp/kiwimount-$name";
	#==========================================
	# create ISO mount point and perform mount
	#------------------------------------------
	if (! defined $root) {
		return $tmpdir;
	}
	$status = qxx ("mkdir -p $tmpdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Couldn't create tmp dir for iso mount: $status: $!");
		$kiwi -> skipped ();
		return undef;
	}
	$status = qxx ("mount -o loop $module $tmpdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Failed to loop mount ISO path: $status");
		$kiwi -> skipped ();
		return undef;
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
	my $uriTable = $main::repoURI;
	my $origurl  = $module;
	my %matches  = ();
	my $FD;
	#==========================================
	# allow proxy server from environment
	#------------------------------------------
	$browser->env_proxy();
	$browser->timeout(30);
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^opensuse:\/\//)) {
		return undef;
	}
	$module =~ s/opensuse:\/\///;
	$module =~ s/\/$//;
	$module =~ s/^\///;
	if ((! defined $module) || ($module eq "")) {
		return undef;
	}
	#==========================================
	# Create URL list from URI table
	#------------------------------------------
	if (! open $FD, $uriTable) {
		return undef;
	}
	while (my $match =<$FD>) {
		chomp $match;
		my @list = split (/\|/,$match);
		my $repo = $module;
		my $match= '$repo =~ '.$list[1];
		eval $match;
		$matches{$repo} = $list[0];
	}
	close $FD;
	#==========================================
	# Check URL entries
	#------------------------------------------
	my @responses = ();
	foreach my $url (keys %matches) {
		my $type = $matches{$url};
		if ($type ne "opensuse") {
			next;
		}
		my $response = $this -> urlResponse ( $browser,$url );
		if (! $response) {
			next;
		}
		my $title = $response-> title ();
		if ((defined $title) && ($title !~ /not found/i)) {
			my $repourl = $url;
			$response = $this -> urlResponse ( $browser,$repourl."/repodata" );
			if (! $response) {
				next;
			}
			$title = $response-> title ();
			if ((defined $title) && ($title !~ /not found/i)) {
				$this->{type} = "rpm-md";
				return $url;
			} else {
				push (@responses,"$repourl/repodata -> $title");
			}
			$response = $this -> urlResponse ( $browser,$repourl."/media.1");
			if (! $response) {
				next;
			}
			$title = $response-> title ();
			if ((defined $title) && ($title !~ /not found/i)) {
				$this->{type} = "yast2";
				return $url;
			} else {
				push (@responses,"$repourl//media.1 -> $title");
			}
		} else {
			push (@responses,"$url -> $title");
		}
	}
	if (! defined $quiet) {
		$kiwi -> warning ("Couldn't resolve opensuse URL: $origurl");
		$kiwi -> skipped ();
	}
	return undef;
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
		return undef;
	}
	$module =~ s/^plain:\/\///;
	$kiwi -> loginfo (
		"URL: $module will be forwarded AS IS to the package manger!\n"
	);
	return $module;
}

#==========================================
# urlResponse
#------------------------------------------
sub urlResponse {
	my $this    = shift;
	my $browser = shift;
	my $url     = shift;
	my $timeout = 5;
	my $request;
	my $response;
	eval {
		local $SIG{ALRM} = sub { die "alarm\n" };
		alarm $timeout;
		$request = HTTP::Request->new (GET => $url);
		$response= $browser -> request  ( $request );
		alarm 0;
	};
	if ($@) {
		# host can't be resolved, network timeout
		if ($@ eq "alarm\n") {
			return undef;
		}
	}
	return $response;
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
	my $FD;
	my %repohash;
	if (! open ($FD, "/etc/kiwi/repoalias")) {
		return {};
	}
	while (my $line = <$FD>) {
		next if $line =~ /^#/;
		if ($line =~ /({.*})\s*(.*)/) {
			my $alias= $1;
			my $repo = $2;
			$repohash{$alias} = $repo;
		}
	}
	close $FD;
	return \%repohash;
}

1;
