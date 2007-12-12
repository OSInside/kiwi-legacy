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
use File::Basename;
use KIWILog;
use LWP;

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
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	$this->{root} = $root;
	$this->{type} = "unknown";
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
	$path = $this -> thisPath ($module);
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
	return quote ($module);
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
	if ($surl =~ /^(.*:\/\/)(.*):(.*)(\@.*)$/) {
		$part1 = $1;
		$part2 = $2;
		$part3 = $3;
		$part4 = $4;
	} else {
		return $surl;
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
			if (! $safe{$key}) {
				$key = sprintf ("%%%02X",ord($key));
			}
			push @done,$key;
		}
		return join ("",@done);
	};
	$part2 = &{$run}($part2,\%safe);
	$part3 = &{$run}($part3,\%safe);
	return $part1.$part2.":".$part3.$part4;
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
	my $kiwi   = $this->{kiwi};
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ($module !~ /^this:\/\//) {
		return undef;
	}
	$module =~ s/this:\/\///;
	$module =~ s/:/:\//g;
	if ((! defined $module) || ($module eq "/")) {
		return undef;
	}
	my $thisPath;
	if (defined $main::ForeignRepo{prepare}) {
		if (! open FD,"$main::ForeignRepo{create}/image/main::Prepare") {
			return undef;
		}
		$thisPath = <FD>; close FD;
		$thisPath = "$thisPath/$module";
	} elsif (defined $main::Create) {
		if (! open FD,"$main::Create/image/main::Prepare") {
			return undef;
		}
		$thisPath = <FD>; close FD;
		$thisPath = "$thisPath/$module";
	} else {
		$thisPath = "$main::Prepare/$module";
	}
	if ($thisPath !~ /^\//) {
		my $pwd = qx (pwd); chomp $pwd;
		$thisPath = $pwd."/".$thisPath;
	}
	return $thisPath;
}

#==========================================
# isPath
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
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ($module !~ /^iso:\/\//) {
		return undef;
	}
	$module =~ s/iso:\/\///;
	if ($module !~ /^\//) {
		my $pwd = qx (pwd); chomp $pwd;
		$module = $pwd."/".$module;
	}
	if (! -e $module) {
		$kiwi -> warning ("ISO path: $module doesn't exist: $!");
		$kiwi -> skipped ();
		return undef;
	}
	my $name   = basename ($module);
	my $tmpdir = "/tmp/kiwimount-$name-$$";
	#==========================================
	# create ISO mount point and perform mount
	#------------------------------------------
	if (! defined $root) {
		return $tmpdir;
	}
	$status = qx (mkdir -p $tmpdir 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> warning ("Couldn't create tmp dir for iso mount: $status: $!");
		$kiwi -> skipped ();
		return undef;
	}
	$status = qx (mount -o loop $module $tmpdir 2>&1);
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
	return $tmpdir;
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
	my $browser  = LWP::UserAgent->new;
	my $location = $main::openSUSE;
	my @dists    = qw (standard);
	my @urllist  = ();
	my $kiwi     = $this->{kiwi};
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^opensuse:\/\//)) {
		return ( undef,undef );
	}
	$module =~ s/opensuse:\/\///;
	$module =~ s/\/$//;
	$module =~ s/^\///;
	if ((! defined $module) || ($module eq "")) {
		return ( undef,undef );
	}
	#==========================================
	# Create urllist for later testing
	#------------------------------------------
	foreach my $dist (@dists) {
		my $url1 = $location.$module."/";
		my $url2 = $location.$module."/".$dist."/";
		push @urllist,$url1;
		push @urllist,$url2;
	}
	#==========================================
	# Check url entries in urllist
	#------------------------------------------
	foreach my $url (@urllist) {
		my $request = HTTP::Request->new (GET => $url);
		my $response = $browser -> request  ( $request );
		my $title = $response -> title ();
		if ((defined $title) && ($title !~ /not found/i)) {
			my $repourl = $url;
			my $request = HTTP::Request->new (GET => $repourl."/repodata");
			my $answer  = $browser -> request  ( $request );
			my $title = $answer -> title ();
			if ((defined $title) && ($title !~ /not found/i)) {
				$this->{type} = "rpm-md";
				return ( $response,$url );
			}
			$request = HTTP::Request->new (GET => $repourl."/media.1");
			$answer  = $browser -> request  ( $request );
			$title = $answer -> title ();
			if ((defined $title) && ($title !~ /not found/i)) {
				$this->{type} = "yast2";
				return ( $response,$url );
			}
		}
	}
	return undef;
}

1;
