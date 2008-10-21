#================
# FILE          : KIWIUtil.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
use File::Glob ':glob';
use File::Find;
use File::Path;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
# Create a new KIWIUtil object. It is used to perform
# some utility methods that are not really bound to
# a certain problem area class.
#------------------------------------------
sub new
{
  my $class = shift;
  my $this =
  {
    m_logger  => undef,
    m_url     => undef,
  };
  bless ($this, $class);

  #==========================================
  # Module Parameters
  #------------------------------------------
  $this->{m_logger} = shift;
  if(not defined $this->{m_logger}) {
    print "No logger defined!";
    return undef;
  }

  return $this;
}



#==========================================
# splitPath
#------------------------------------------
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
#------------------------------------------
sub splitPath
{
  my $this = shift;
  my $targets = shift;
  my $browser = shift;
  my $path = shift;
  my $pat = shift;

  #==========================================
  # cancel on missing parameters:
  #------------------------------------------
  my $kiwi = $this->{m_logger};
  if(!defined($browser) or !defined($targets) or !defined($path))
  {
    $kiwi->info("Can't proceed request due to missing parameters!");
    $kiwi->failed();
    return undef;
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

  #if($path =~ m{^opensuse://.*}) {
  #  $path = $this->{m_url}->normalizePath($path);
  #}

  #==========================================
  # now decide which method to call:
  #------------------------------------------
  if("$path$pat" =~ m{^(http|https)(://)([^/]*)(/.*$)}) {
    my $basepath = $1.$2.$3;
    my $pattern = $4;
    $pattern =~ s{(.*)[/]{2,}(.*)}{$1/$2};
    # remove double slashes
    $this->{m_logger}->info("Examining HTTP path $basepath");
    return $this->splitPathHTTP($targets, $browser, $basepath, $pattern, $leafonly);
  }
  elsif($path =~ m{^(ftp://)}) {
    # warn and go, return undef
    $kiwi->{m_logger}->warning("Protocol not yet supported. Stay tuned...");
    return undef;
  }
  elsif($path =~ m{^(/|file://)(.*)}) {
    # we deal with local files (including nfs)
    my $basepath = "/$2";
    #my $pattern = $2;
    $this->{m_logger}->info("Examining local path $basepath");
    return $this->splitPathLocal($targets, $basepath, $pat, $leafonly);
  }
}



#==========================================
# splitPathHTTP
#------------------------------------------
# This method receives a pair of (hostname, path)
# containing arbitrary regular expressions as
# parameters.
# It creates a list of pathnames that match the
# expressions. Depending on the "leafonly" parameter
# it returns only paths mathing the *whole* expression
# (leafonly==0) or any part in between (leafonly==1).
# The call depends on how the repo is structured.
#------------------------------------------
sub splitPathHTTP
{
  my $this	= shift;
  my $targets	= shift;
  # refers to the result list
  my $browser	= shift;
  my $basepath	= shift;
  my $pattern	= shift;
  my $leafonly	= shift;

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
    $this->{m_logger}->error("[MAJOR ERROR] HTTP request failed! Server down?");
    $this->{m_logger}->error("\tThis repository can not be resolved at present.");
    $this->{m_logger}->error("\tI recommend you try again later unless you know what you're doing.");
    return undef;
  }

  my $content  = $response->content();

  # descend if the root page doesn't do dir listing:
  # FIXME: configurable message of server? find better way here!
  # (works for now, but...)
  if($response->title !~ m{(index of|repoview)}i) {
    # this means that no dir listing is done here, try one descend.
    $this->{m_logger}->info("Directory $basepath has no listings, descencding");
    return $this->splitPathHTTP($targets, $browser, $basepath."/".$prefix, $rest, $leafonly);
  }

  my @links = ();
  if($content =~ m{error 404}i) {
    pop @{$targets};
    return undef;
  }

  $this->{m_logger}->info("Current remote directory is $basepath");

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
    next if($line !~ m{<img.*href="(.*)\/">});

    $atleastonce++; # at least ONE match means the dir contains subdirs!

    my $link = $1;
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
	$this->{m_logger}->info("Descending into subdirectory $basepath/$link");
	$this->splitPathHTTP($targets, $browser, $basepath."/".$link, $rest, $leafonly);
      }
      else {
	# if the path is finished the leaves are stored
	push @{$targets}, $basepath."/".$link;
	$this->{m_logger}->info("Storing directory $basepath."/".$link");
      }
    }
  }

  if($atleastonce == 0 and $leafonly != 1) {
    # we're in a dir where no subdirs are found but:
    # $rest may be non-zero
    push @{$targets}, $basepath;
    $this->{m_logger}->info("Storing directory $basepath");
  }

  return $this;
}



#==========================================
# splitPathLocal
#------------------------------------------
# This method receives a local path
# containing arbitrary regular expressions as
# parameters.
# It creates a list of pathnames that match the
# expressions. Depending on the "leafonly" parameter
# it returns only paths mathing the *whole* expression
# (leafonly==0) or any part in between (leafonly==1).
# The call depends on how the repo is structured.
#------------------------------------------
sub splitPathLocal
{
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
  opendir(DIR, $basepath) or return undef;
  my @dirlist = readdir(DIR);
  closedir(DIR);

  $this->{m_logger}->info("Current local directory is $basepath");
  my $atleastonce = 0;

  foreach my $entry(@dirlist) {
    next if(!-d "$basepath/$entry");  # skip all non-directories
    next if($entry =~ m{^[.]+});      # ignore . and ..
    $atleastonce++; # at least ONE match means the dir contains subdirs!
    next if($entry !~ m{$prefix});    # skip anything not matching the regexp parameter

    if(defined($rest)) {
      #	pattern contains subdirs -> descent necessary
      if($leafonly == 1) {
	# list directory even if the path is not finished
	$this->{m_logger}->info("Storing directory $basepath/$entry");
	push @{$targets}, "$basepath/$entry";
      }
      #$this->{m_logger}->info("Descending into subdirectory $basepath/$entry");
      $this->splitPathLocal($targets, "$basepath/$entry", $rest, $leafonly);
    }
    else {
      push @{$targets}, "$basepath/$entry";
      #$this->{m_logger}->info("Storing directory $basepath/$entry");
    }

  }

  if($atleastonce == 0 and $leafonly != 1) {
    # we're in a dir where no subdirs are found
    # but the regexp isn't used up yet; store last found dir
    # ignoring the rest
    push @{$targets}, $basepath;
    #$this->{m_logger}->info("Storing directory $basepath");
  }

  return $this;
}



#==========================================
# expandFilename
#------------------------------------------
# This method receives a pair of (path, pattern)
# containing a regular expression for a filename
# (e.g. ".*\.[rs]pm") set by the caller.
# The method returns a list of files matching the
# pattern as full URI.
# This method works for both HTTP(S) and FTP.
#------------------------------------------
sub expandFilename
{
  my $this     = shift;
  my $browser  = shift;
  my $basepath = shift;
  my $filename = shift;
  #==========================================
  # cancel on missing parameters:
  #------------------------------------------
  # saves the checks in the resp. specialised method
  #------------------------------------------
  my $kiwi = $this->{m_logger};
  if(!defined($browser)
      or !defined($basepath)
      or !defined($filename))
  {
    $kiwi->error("Can't proceed request due to missing parameters!");
    $kiwi->failed();
    return undef;
  }

  $basepath =~ s{(.*)\/$}{$1}; # remove trailing slash
  if($basepath =~ m{^(http|ftp|https)}) {
    # we deal with a web request
    $this->{m_logger}->info("Expanding remote filenames for $basepath");
    return $this->expandFilenameHTTP($browser, $basepath, $filename);
  }
  elsif($basepath =~ m{^(/|file://)(.*)}) {
    # we deal with a local directory
    $this->{m_logger}->info("Expanding local filenames for $2");
    return $this->expandFilenameLocal($browser, $2, $filename);
  }
}



#==========================================
# expandFilenameHTTP
#------------------------------------------
# Does the concrete work of "expandFilename"
# for a http/ftp type connection.
# No need for further safety checks, those
# have been handled by the surrounding
# method before.
# CAUTION:
# For the reason mentioned above, please
# consider this method "private" :)
#------------------------------------------
sub expandFilenameHTTP
{
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
    return undef;
  }

  #==========================================
  # Evaluate LWP content
  #------------------------------------------
  my @lines    = split (/\n/,$content);
  foreach my $line (@lines) {
    next if($line !~ /<img.*?href="(.*?)">.*/);
    # skip "parent dir" to avoid cycles
    next if($line =~ /parent.+directory/i);

    my $link = $1;
    $link =~ s{^[./]+}{}g;
    # /.../
    # remove leading path. This only happens once: if the root dir is read
    # In that case the server puts the whole path into the link
    # This is fatal for descending...
    # ----
    $link =~ s{.*/}{}g;
    if($link =~ m{$filename}) {
      push @filelist, $basepath."/".$link;}
      #$this->{m_logger}->info("Storing path $basepath/$link");
  }
  return @filelist;
}



#==========================================
# expandFilenameLocal
#------------------------------------------
# Does the concrete work of "expandFilename"
# for local filesystem.
# No need for further safety checks, those
# have been handled by the surrounding
# method before.
# CAUTION:
# For the reason mentioned above, please
# consider this method "private" :)
#------------------------------------------
sub expandFilenameLocal
{
  my $this	= shift;
  my $browser	= shift;  # unused
  my $basepath	= shift;  # has already been stripped (usr/share/blablubb/)
  my $filename	= shift;

  $basepath =~ s{(.*)}{/$1};  # append a leading slash

  my @filelist = ();

  find(sub{ findCallback($this, $filename, \@filelist) }, $basepath);
  
  return @filelist;
}



sub findCallback
{
  my $this = shift;
  my $filename = shift;
  my $listref = shift;

  if($_ =~ m{$filename}) {
    push @{$listref}, $File::Find::name;
    # uncomment for gigatons of output if program runs too fast ;)
    #$this->{m_logger}->info("Storing path $File::Find::name");
  }
}



sub set_intersect
{
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



sub set_anob
{
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



sub unify
{
  my %h = map {$_ => 1} @_;
  return grep(delete($h{$_}), @_);
}



# methods for unpacking RPM files
#======================================
# unpac_package
#   implementation of the pac_unpack script
#   of the SuSE autobuild team
# original: /mounts/work/src/bin/tools/pac_unpack
#--------------------------------------
# params
#   $this - class name; always call as member
#   $p_uri - uri of the rpm file to unpack
#   $dir - target dir for the unpacking, created if necessary
#--------------------------------------
sub unpac_package
{
  my $this = shift;
  my $p_uri = shift;
  my $dir = shift;

  my $retval = 0;

  if(!($this and $p_uri and $dir)) {
    $retval = 1;
    goto up_failed;
  }

  if(! -d $dir) {
    if(!mkpath("$dir", { mode => umask })) {
      $this->{m_logger}->error("[E] unpac_package: cannot create directory <$dir>");
      $retval = 2;
      goto up_failed;
    }
  }

  if($p_uri =~ m{(.*\.tgz|.*\.tar\.gz|.*\.taz|.*\.tar\.Z)}) {
    my $out = qx(cd $dir && tar -zxvfp $p_uri);
    my $status = $?>>8;
    if($status != 0) {
      $this->{m_logger}->error("[E] command cp $dir && tar xvzfp $p_uri failed!\n");
      $this->{m_logger}->error("\t$out\n");
      $retval = 5;
      goto up_failed;
    }
    else {
      $this->{m_logger}->info("[I] unpacked $p_uri in directory $dir\n");
    }
  }
  elsif($p_uri =~ m{.*\.rpm}i) {
    my $out = qx(cd $dir && unrpm -q $p_uri);
  }
  else {
    $this->{m_logger}->error("[E] cannot process file $p_uri\n");
    $retval = 4;
    goto up_failed;
  }

  up_failed:
  return $retval;
}



#==========================================
# normaliseDirname
#------------------------------------------
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
#------------------------------------------
sub normaliseDirname
{
  my $this    = shift;
  my $dirname = shift;
  my $sepchar = shift;
  if(!defined($sepchar)
      or $sepchar =~ m{[\w\s:\(\)\[\]\$]}) {
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
# /normaliseDirname



1;

