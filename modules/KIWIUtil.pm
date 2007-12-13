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



#==========================================
# Constructor
#------------------------------------------
# there are no members to initialise
#------------------------------------------
sub new
{
  # ...
  # Create a new KIWIXML object which is used to access the
  # configuration XML data saved as config.xml. The xml data
  # is splitted into four major tags: preferences, drivers,
  # repository and packages. While constructing an object of this
  # type there will be a node list created for each of the
  # major tags.
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $this  = {
    m_logger => undef,
  };
  my $class = shift;
  bless $this,$class;
  #==========================================
  # Module Parameters
  #------------------------------------------
  $this->{m_logger} = shift;
  die "No logger defined\n" if(not defined $this->{m_logger});

  return $this;
}




#==========================================
# splitPath
#------------------------------------------
#   does some plausibility checks and then
#   calls the protocol dependent method
#   (which may omit the checks)
#------------------------------------------
sub splitPath
{
  # ...
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

  my $this     = shift;
  my $targets  = shift;
  my $browser  = shift;
  my $path     = shift;

  #==========================================
  # cancel on missing parameters:
  #------------------------------------------
  my $kiwi = $this->{m_logger};
  if( !defined($browser) or !defined($targets) or !defined($path) ) {
    $kiwi -> info  ("Can't proceed request due to missing parameters!");
    $kiwi -> failed();
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
  if( !defined( $leafonly ) ) {
    $leafonly = 0;
  }

  #==========================================
  # now decide which method to call:
  #------------------------------------------
  if($path =~ m{^(http|https)(://)([^/]*)(/.*$)}) {
    my $basepath = $1.$2.$3;
    my $pattern  = $4;
    $pattern =~ s{(.*)\/{2,}(.*)}{$1\/$2}; # remove double slashes
    return $this->splitPathHTTP($targets, $browser, $basepath, $pattern, $leafonly);
  }
  elsif( $path =~ m{^(ftp://|file://)}) {
    # warn and go, return undef
    $kiwi->warning("Protocol not yet supported. Stay tuned...");
    return undef;
  }
  elsif($path =~ m{^(/.*)/(.*)$}) {
    # we deal with local files (including nfs)
    my $basepath = $1;
    my $pattern = $2;
    return $this->splitPathLocal($targets, $browser, $basepath, $pattern, $leafonly);
  }
}




#==========================================
# splitPathHTTP
#------------------------------------------
sub splitPathHTTP
{
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
  my $this     = shift;
  my $targets  = shift;
  my $browser  = shift;
  my $basepath = shift;
  my $pattern  = shift;

  my $leafonly = shift;

  #==========================================
  # remove leading/trailing slashes if any
  #------------------------------------------
  $pattern =~ s{^/*(.*)}{$1};
  $pattern =~ s{(.*)/$}{$1};

  my @testlist = split( "/", $pattern, 2);
  my $prefix = $testlist[0];
  my $rest   = $testlist[1];

  #==========================================
  # Form LWP request
  #------------------------------------------
  my $request  = HTTP::Request->new( GET => $basepath );
  my $response = $browser->request( $request );
  my $content  = $response->content();

  # descend if the root page doesn't do dir listing:
  # FIXME: configurable message of server? find better way here!
  # (works for now, but...)
  if($response->title !~ m{(index of|repoview)}i) {
    # this means that no dir listing is done here, try one descend.
    $this->{m_logger}->note("Directory $basepath has no listings, descencding");
    return $this->splitPathHTTP($targets, $browser, $basepath."/".$prefix, $rest, $leafonly);
  }

  my @links    = ();
  if($content =~ m{error 404}i) {
    pop @{$targets};
    return undef;
  }
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

    $atleastonce++;	# at least ONE match means the dir contains subdirs!
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
	$this->splitPathHTTP($targets, $browser, $basepath."/".$link, $rest, $leafonly);
      }
      else {
	# if the path is finished the leaves are stored
	push @{$targets}, $basepath."/".$link;
	return $this;
      }
    }
  }

  if($atleastonce == 0 and $leafonly != 1) {
    # we're in a dir where no subdirs are found but:
    # $rest may be non-zero
    push @{$targets}, $basepath;
  }
  return $this;
}




#==========================================
# splitPathLocal
#------------------------------------------
sub splitPathLocal
{
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

  # not yet implemented!
  my $this = shift;
  return undef;
}




#==========================================
# expandFilename
#------------------------------------------
sub expandFilename
{
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
  my $kiwi = $this->{m_logger};
  if( !defined($browser) or !defined($basepath) or !defined($filename) ) {
    $kiwi -> info  ("Can't proceed request due to missing parameters!");
    $kiwi -> failed();
    return undef;
  }

  $basepath =~ s{(.*)\/$}{$1}; # remove trailing slash
  if($basepath =~ m{^(http|ftp|https)}) {
    # we deal with a web request
    return $this->expandFilenameHTTP($browser, $basepath, $filename);
  }
  elsif($basepath =~ m{^/.*}) {
  # we deal with a local directory
    return $this->expandFilenameLocal($browser, $basepath, $filename);
  }
}




#==========================================
# expandFilenameHTTP
#------------------------------------------
sub expandFilenameHTTP
{
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
    return undef;
  }

  #==========================================
  # Evaluate LWP content
  #------------------------------------------
  my @lines    = split (/\n/,$content);
  foreach my $line (@lines) {
    next if ($line !~ /<img.*href="(.*)">/);
    # skip "parent dir" to avoid cycles
    next if ($line =~ /parent.+directory/i);
  
    my $link = $1;
    $link =~ s{^[./]+}{}g;
    # /.../
    # remove leading path. This only happens once: if the root dir is read
    # In that case the server puts the whole path into the link
    # This is fatal for descending...
    # ----
    $link =~ s{.*/}{}g;
    #$basepath =~ s#(.*)/#$1#g;
    if($link =~ m{$filename}) {
      push @filelist, $basepath."/".$link;
    }
  }
  return @filelist;
}




#==========================================
# expandFilenameLocal
#------------------------------------------
sub expandFilenameLocal
{
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
  my $this     = shift;
  my $browser  = shift;	# unused
  my $basepath = shift;
  my $filename = shift;

  #==========================================
  # form LWP request
  #------------------------------------------
  my @filelist = ();

#  foreach my $line (@lines) {
#    next if ($line !~ /<img.*href="(.*)">/);
#    # skip "parent dir" to avoid cycles
#    next if ($line =~ /parent.+directory/i);
#    my $link = $1;
#    $link =~ s#^[./]+##g;
    # /.../
    # remove leading path. This only happens once: if the root dir is read
    # In that case the server puts the whole path into the link
    # This is fatal for descending...
    # ----
#    $link =~ s#.*/##g;
#    if ($link =~ m/$filename/) {
#      push @filelist, $basepath."/".$link;
#    }
#  }
  return @filelist;
}



1;

