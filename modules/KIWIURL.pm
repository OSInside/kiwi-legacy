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
use KIWILog;
use LWP;

#==========================================
# Private
#------------------------------------------
my $kiwi;

#==========================================
# Constructor
#------------------------------------------
sub new { 
	# ...
	# Create a new KIWIURL object which is used to solve
	# the high level location information into a low level
	# distribution independent network url
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi   = shift;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	return $this;
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
		$thisPath = "$main::ForeignRepo{prepare}/$module";
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
	my $location = qw (http://ftp.opensuse.org/pub/opensuse);
	my @types    = qw (distribution repositories);
	my @dists    = qw (inst-source media.1);
	my @urllist  = ();
	#==========================================
	# normalize URL data
	#------------------------------------------
	if ((! defined $module) || ($module !~ /^opensuse:\/\//)) {
		return ( undef,undef );
	}
	$module =~ s/opensuse:\/\///;
	$module =~ s/:/:\//g;
	if ((! defined $module) || ($module eq "/")) {
		return ( undef,undef );
	}
	#==========================================
	# Create urllist for later testing
	#------------------------------------------
	foreach my $type (@types) {
		my $url = $location."/".$type."/".$module;
		if ($type eq $types[1]) {
			push @urllist,$url;
			next;
		}
		foreach my $dist (@dists) {
			$url = $url."/".$dist;
			push @urllist,$url;
		}
	}
	#==========================================
	# Check url entries in urllist
	#------------------------------------------
	foreach my $url (@urllist) {
		my $request = HTTP::Request->new (GET => $url);
		my $response = $browser -> request  ( $request );
		my $title = $response -> title ();
		if ((defined $title) && ($title !~ /not found/i)) {
			$url =~ s/([^:])\/+/\1\//g;
			if ($url =~ /repositories/) {
				my $repourl = $url;
				my $request = HTTP::Request->new (GET => $repourl."/repodata");
				my $answer  = $browser -> request  ( $request );
				my $title = $answer -> title ();
				if ((defined $title) && ($title !~ /not found/i)) {
					return ( $response,$url );
				}
			} else {
				return ( $response,$url );
			}
		}
	}
	return undef;
}

1;
