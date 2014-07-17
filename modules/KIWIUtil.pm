#================
# FILE          : KIWIUtil.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module provides some generally useful
#               : methods which had been part of KIWIXML.pm before
#               :
# STATUS        : Development
#----------------
package KIWIUtil;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use File::Glob ':glob';
use File::Find;
use File::Path;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
	my $class = shift;
	my $this  = {
		m_collect => undef,
		m_url     => undef,
	};
	bless ($this, $class);
	#==========================================
	# Module Parameters
	#------------------------------------------
	$this->{m_collect} = shift;
	if(not defined $this->{m_collect}) {
		print "No parent defined!";
		return;
	}
	return $this;
}

#==========================================
# splitPath
#------------------------------------------
sub splitPath {
	# ...
	# does some plausibility checks and then
	# calls the protocol dependent method
	# (which may omit the checks)
	# This method receives a pair of (hostname, path)
	# containing arbitrary regular expressions as
	# parameters.
	# It creates a list of pathnames that match the
	# expressions. Depending on the "leafonly" parameter
	# it returns only paths mathing the *whole* expression
	# (leafonly==0) or any part in between (leafonly==1).
	# The call depends on how the repo is structured.
	#
	# The result list has to be defined elsewhere before
	# the call and contains the directories after the caol.
	# ---
	my $this = shift;
	my $targets = shift;
	my $browser = shift;
	my $path = shift;
	my $pat = shift;
	#==========================================
	# cancel on missing parameters:
	#------------------------------------------
	if(!defined($browser) || !defined($targets) || !defined($path)) {
		my $msg = 'Cannot proceed request due to missing parameters!';
		$this->{m_collect}->error("E", $msg);
		return;
	}
	# ...
	# optional: only shows directories matching the complete expression
	# when set to 1. Default mode shows every step
	# Example: /foo*/bar* may expand to
	# /football, /football/bart, /fools, /fools/barbarian
	# with leafonly, the folders /football and /fools are omitted.
	# ----
	my $leafonly = shift;
	if(!defined($leafonly)) {
		$leafonly = 0;
	}
	#==========================================
	# now decide which method to call:
	#------------------------------------------
	if("$path$pat" =~ m{^(http|https)(://)([^/]*)(/.*$)}) {
		my $basepath = $1.$2.$3;
		my $pattern = $4;
		$pattern =~ s{(.*)[/]{2,}(.*)}{$1/$2};
		# remove double slashes
		$this->{m_collect}->logMsg("I", "Examining HTTP path $basepath");
		return $this->splitPathHTTP(
			$targets, $browser, $basepath,
			$pattern, $leafonly
		);
	} elsif($path =~ m{^(ftp://)}) {
		# warn and go, return undef
		my $msg = 'Protocol not yet supported. Stay tuned...';
		$this->{m_collect}->logMsg("W", $msg);
		return;
	} elsif($path =~ m{^(/|file://)(.*)}) {
		# we deal with local files (including nfs)
		my $basepath = "/$2";
		#my $pattern = $2;
		$this->{m_collect}->logMsg("I", "Examining local path $basepath");
		return $this->splitPathLocal($targets, $basepath, $pat, $leafonly);
	}
	return;
}

#==========================================
# splitPathHTTP
#------------------------------------------
sub splitPathHTTP {
	# ...
	# This method receives a pair of (hostname, path)
	# containing arbitrary regular expressions as
	# parameters.
	# It creates a list of pathnames that match the
	# expressions. Depending on the "leafonly" parameter
	# it returns only paths mathing the *whole* expression
	# (leafonly==0) or any part in between (leafonly==1).
	# The call depends on how the repo is structured.
	# ---
	my $this	= shift;
	my $targets	= shift;
	my $browser	= shift;
	my $basepath= shift;
	my $pattern	= shift;
	my $leafonly= shift;
	#==========================================
	# remove leading/trailing slashes if any
	#------------------------------------------
	$pattern =~ s{^/*(.*)/$}{$1};
	my @testlist = split( "/", $pattern, 2);
	my $prefix = $testlist[0];
	my $rest   = $testlist[1];
	#==========================================
	# Form LWP request
	#------------------------------------------
	my $request  = HTTP::Request->new( GET => $basepath );
	my $response = $browser->request( $request );
	# catch 3xx error codes from HTTP server
	# is_error handles 400-599 http replies (according to "PERL in a nutshell")
	if($response->is_error()) {
		my $msg = '[E] HTTP request failed! Server down?'
			. "\tThis repository can not be resolved at present."
			. "\tI recommend you try again later unless you know what "
			. 'you are doing.';
		$this->{m_collect}->logMsg("E", $msg);
		return;
	}
	my $content  = $response->content();
	# descend if the root page doesn't do dir listing:
	# configurable message of server? find better way here!
	# (works for now, but...)
	if($response->title !~ m{(index of|repoview)}i) {
		# this means that no dir listing is done here, try one descend.
		my $msg = "Directory $basepath has no listings, descencding";
		$this->{m_collect}->logMsg("I", $msg);
		return $this->splitPathHTTP(
			$targets, $browser,
			$basepath."/".$prefix, $rest, $leafonly
		);
	}
	my @links = ();
	if($content =~ m{error 404}i) {
		pop @{$targets};
		return;
	}
	$this->{m_collect}->logMsg("I", "Current remote directory is $basepath");
	#==========================================
	# Evaluate LWP content
	#------------------------------------------
	# /.../
	# do the actual work:
	# get the current dir list, parse for links and match them to prefix
	# for each match call splitPath with the correct parameters recursively
	# ----
	my @lines = split(/\n/,$content);
	my $atleastonce = 0;
	foreach my $line(@lines) {
		# skip "parent dir" to avoid cycles
		next if($line =~ m{parent.+directory}i);
		next if($line !~ m{<(img|a).*href="(.*)\/">});
		$atleastonce++; # at least ONE match means the dir contains subdirs!
		my $link = $2;
		$link =~ s{^[./]+}{}g;
		# remove leading path. This only happens once: if the root dir is read
		# In that case the server puts the whole path into the link
		# This is fatal for descending...
		$link =~ s{.*/}{}g;
		if($link =~ m{$prefix}) {
			if(defined($rest)) {
				if($leafonly == 1) {
					# list directory even if the path is not finished
					push @{$targets}, $basepath."/".$link;
				}
				my $msg = "Descending into subdirectory $basepath/$link";
				$this->{m_collect}->logMsg("I", $msg);
				$this->splitPathHTTP(
					$targets, $browser,
					$basepath."/".$link, $rest, $leafonly
				);
			} else {
				# if the path is finished the leaves are stored
				push @{$targets}, $basepath."/".$link;
				my $msg = "Storing directory $basepath/$link";
				$this->{m_collect}->logMsg("I", $msg);
			}
		}
	}
	if($atleastonce == 0 and $leafonly != 1) {
		# we're in a dir where no subdirs are found but:
		# $rest may be non-zero
		push @{$targets}, $basepath;
		$this->{m_collect}->logMsg("I", "Storing directory $basepath");
	}
	return $this;
}

#==========================================
# splitPathLocal
#------------------------------------------
sub splitPathLocal {
	# ...
	# This method receives a local path
	# containing arbitrary regular expressions as
	# parameters.
	# It creates a list of pathnames that match the
	# expressions. Depending on the "leafonly" parameter
	# it returns only paths mathing the *whole* expression
	# (leafonly==0) or any part in between (leafonly==1).
	# The call depends on how the repo is structured.
	# ---
	my $this	= shift;
	my $targets	= shift; # refers to the result list
	my $basepath	= shift;
	my $pattern	= shift;
	my $leafonly	= shift;
	#==========================================
	# remove leading/trailing slashes if any
	#------------------------------------------
	$pattern =~ s{^/*(.*)/$}{$1};
	my @testlist = split("/", $pattern, 2);
	my $prefix = $testlist[0];
	my $rest   = $testlist[1];
	# read current dir to list before descent:
	opendir(DIR, $basepath) or return;
	my @dirlist = readdir(DIR);
	closedir(DIR);
	$this->{m_collect}->logMsg("I", "Current local directory is $basepath");
	my $atleastonce = 0;
	foreach my $entry(@dirlist) {
		next if(!-d "$basepath/$entry");  # skip all non-directories
		next if($entry =~ m{^[.]+});      # ignore . and ..
		$atleastonce++; # at least ONE match means the dir contains subdirs!
		next if($entry !~ m{$prefix});    # skip anything not matching
		if(defined($rest)) {
			# pattern contains subdirs -> descent necessary
			if($leafonly == 1) {
				# list directory even if the path is not finished
				my $msg = "Storing directory $basepath/$entry";
				$this->{m_collect}->logMsg("I", $msg);
				push @{$targets}, "$basepath/$entry";
			}
			$this->splitPathLocal(
				$targets, "$basepath/$entry", $rest, $leafonly
			);
		} else {
			push @{$targets}, "$basepath/$entry";
		}
	}
	if($atleastonce == 0 and $leafonly != 1) {
		# we're in a dir where no subdirs are found
		# but the regexp isn't used up yet; store last found dir
		# ignoring the rest
		push @{$targets}, $basepath;
	}
	return $this;
}

#==========================================
# expandFilename
#------------------------------------------
sub expandFilename {
	# ...
	# This method receives a pair of (path, pattern)
	# containing a regular expression for a filename
	# (e.g. ".*\.[rs]pm") set by the caller.
	# The method returns a list of files matching the
	# pattern as full URI.
	# This method works for both HTTP(S) and FTP.
	# ---
	my $this     = shift;
	my $browser  = shift;
	my $basepath = shift;
	my $filename = shift;
	#==========================================
	# cancel on missing parameters:
	#------------------------------------------
	# saves the checks in the resp. specialised method
	#------------------------------------------
	if(!defined($browser) || !defined($basepath) || !defined($filename)) {
		my $msg = 'Cannot proceed request due to missing parameters!';
		$this->{m_collect}->logMsg("E", $msg);
		return;
	}
	$basepath =~ s{(.*)\/$}{$1}; # remove trailing slash
	if($basepath =~ m{^(http|ftp|https)}) {
		# we deal with a web request
		my $msg = "Expanding remote filenames for $basepath";
		$this->{m_collect}->logMsg("I", $msg);
		return $this->expandFilenameHTTP($browser, $basepath, $filename);
	} elsif($basepath =~ m{^(/|file://)(.*)}) {
		# we deal with a local directory
		$this->{m_collect}->logMsg("I", "Expanding local filenames for $2");
		return $this->expandFilenameLocal($browser, $2, $filename);
	}
	return;
}

#==========================================
# expandFilenameHTTP
#------------------------------------------
sub expandFilenameHTTP {
	# ...
	# Does the concrete work of "expandFilename"
	# for a http/ftp type connection.
	# No need for further safety checks, those
	# have been handled by the surrounding
	# method before.
	# CAUTION:
	# For the reason mentioned above, please
	# consider this method "private" :)
	# ---
	my $this     = shift;
	my $browser  = shift;
	my $basepath = shift;
	my $filename = shift;
	#==========================================
	# form LWP request
	#------------------------------------------
	my @filelist = ();
	my $request  = HTTP::Request->new( GET => $basepath );
	my $response = $browser->request( $request );
	my $content  = $response->content();
	my @links    = ();
	if ($content =~ m{error 404}i) {
		return;
	}
	#==========================================
	# Evaluate LWP content
	#------------------------------------------
	my @lines    = split (/\n/,$content);
	foreach my $line (@lines) {
		next if($line !~ /<(img|a).*?href="(.*?)">.*/);
		# skip "parent dir" to avoid cycles
		next if($line =~ /parent.+directory/i);

		my $link = $2;
		$link =~ s{^[./]+}{}g;
		# /.../
		# remove leading path. This only happens once: if the root dir is read
		# In that case the server puts the whole path into the link
		# This is fatal for descending...
		# ----
		$link =~ s{.*/}{}g;
		if($link =~ m{$filename}) {
			push @filelist, $basepath."/".$link;
		}
	}
	return @filelist;
}

#==========================================
# expandFilenameLocal
#------------------------------------------
sub expandFilenameLocal {
	# ...
	# Does the concrete work of "expandFilename"
	# for local filesystem.
	# No need for further safety checks, those
	# have been handled by the surrounding
	# method before.
	# CAUTION:
	# For the reason mentioned above, please
	# consider this method "private" :)
	# ---
	my $this	= shift;
	my $browser	= shift;  # unused
	my $basepath	= shift;  # has already been stripped (usr/share/blablubb/)
	my $filename	= shift;
	$basepath =~ s{(.*)}{/$1};  # append a leading slash
	my @filelist = ();
	find(sub{ findCallback($this, $filename, \@filelist) }, $basepath);
	return @filelist;
}

#==========================================
# findCallback
#------------------------------------------
sub findCallback {
	my $this = shift;
	my $filename = shift;
	my $listref = shift;
	if($_ =~ m{$filename}) {
		push @{$listref}, $File::Find::name;
		# uncomment for gigatons of output if program runs too fast ;)
		#$this->{m_collect}->logMsg("I", "Storing path $File::Find::name");
	}
	return;
}

#==========================================
# set_intersect
#------------------------------------------
sub set_intersect {
	my $refA = shift;
	my $refB = shift;
	my @result;
	A:foreach my $s(@{$refA}) {
		B:foreach my $t(@{$refB}) {
			if($s =~ m{$t}) {
				push @result, $s;
				next A;
			}
		}
	}
	return @result;
}

#==========================================
# set_anob
#------------------------------------------
sub set_anob {
	my $refA = shift;
	my $refB = shift;
	my @result;
	A:foreach my $s(@{$refA}) {
		foreach my $t(@{$refB}) {
			if($s =~ m{$t}) {
				next A;
			}
		}
		push @result, $s;
	}
	return @result;
}

#==========================================
# unify
#------------------------------------------
sub unify {
	my @list = @_;
	my %h = map {$_ => 1} @list;
	return ( grep { delete($h{$_}) } @list );
}

#==========================================
# unpac_package
#------------------------------------------
sub unpac_package {
	# ...
	# implementation of the pac_unpack script
	# of the SuSE autobuild team
	# original: /mounts/work/src/bin/tools/pac_unpack
	#--------------------------------------
	# params
	#   $this - class name; always call as member
	#   $p_uri - uri of the rpm file to unpack
	#   $dir - target dir for the unpacking, created if necessary
	# ---
	my $this   = shift;
	my $p_uri  = shift;
	my $dir    = shift;
	my $retval = 0;
	if(!($this and $p_uri and $dir)) {
		$retval = 1;
		goto up_failed;
	}
	if(! -d $dir) {
		if(!mkpath("$dir", { mode => oct(755) })) {
			my $msg = "[E] unpac_package: cannot create directory <$dir>";
			$this->{m_collect}->logMsg("E", $msg);
			$retval = 2;
			goto up_failed;
		}
	}
	if($p_uri =~ m{(.*\.tgz|.*\.tar\.gz|.*\.taz|.*\.tar\.Z)}) {
		my $out = qx(cd $dir && tar -zxvfp $p_uri);
		my $status = $?>>8;
		if($status != 0) {
			my $msg = "[E] command cp $dir && tar xvzfp $p_uri failed!\n";
			$this->{m_collect}->logMsg("E", $msg);
			$this->{m_collect}->logMsg("E", "\t$out\n");
			$retval = 5;
			goto up_failed;
		} else {
			my $msg = "[I] unpacked $p_uri in directory $dir\n";
			$this->{m_collect}->logMsg("I", $msg);
		}
	} elsif($p_uri =~ m{.*\.rpm}i) {
		my $out = qx(cd $dir && unrpm -q $p_uri);
	} else {
		$this->{m_collect}->logMsg("E", "[E] cannot process file $p_uri\n");
		$retval = 4;
		goto up_failed;
	}
	up_failed:
	return $retval;
}

#==========================================
# normaliseDirname
#------------------------------------------
sub normaliseDirname {
	# ...
	# Create a name without slashes, colons et cetera, replace
	# all funny characters by dots and thus create a string which
	# can be used as directory name.
	#------------------------------------------
	# Parameters:
	#   $this - reference to the object for which it is called
	#   $dirname - the RAW name, in the usual case an URL
	#   $sepchar - the character that shall be used for token separation
	#	Defaults to `.' if omitted.
	# Returns:
	#   a string consisting of letter tokens separated by dots
	# ---
	my $this    = shift;
	my $dirname = shift;
	my $sepchar = shift;
	if(!defined($sepchar) || $sepchar =~ m{[\w\s:\(\)\[\]\$]}) {
		$sepchar = "-";
	}
	# remove leading protocol name:
	$dirname =~ s{^(http|https|file|ftp)[:]/*}{};
	# remove some annoying chars:
	$dirname =~ s{[\/:]}{$sepchar}g;
	# remove double sep chars:
	$dirname =~ s{[$sepchar]+}{$sepchar}g;
	# remove leading and trailing sepchars:
	$dirname =~ s{^[$sepchar]}{}g;
	$dirname =~ s{[$sepchar]$}{}g;
	# remove trailing slashes:
	$dirname =~ s{/+$}{}g;
	return $dirname;
}

1;
