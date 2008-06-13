#================
# FILE          : KIWIRepoMetaHandler.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module handles a list of specialised
#               : objects used to create all sort of metadata.
#               :
# STATUS        : Development
#----------------

package KIWIRepoMetaHandler;

use strict;


sub new
{
  # ...
  # Create a new KIWIRepoMetaHandler object which administers
  # a list of plugins used to do the concrete work of
  # metadata creation
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $class = shift;

  my $this  = {
    m_collect	=> undef,     # phone back to KIWICollect (getMediaNumbers and the like)
    m_handlers	=> {},	      # list of specialised handlers
    m_medianame	=> undef,     # name of the media (CD, DVD, ...)
    m_baseurl	=> undef,     # base url where $MEDIUMNAME$NR reside
  };
  bless ($this, $class);

  # other init work:
  $this->{m_collect}	= shift;  # first and most important thing: store the caller object
  if(not defined($this->{m_collect})) {
    return undef; # rock hard get outta here: caller must check retval anyway
  }
  $this->{m_unitedir}	= $this->{m_collect}->unitedDir();
  #$this->{m_logger}	= $this->{m_collect}->logger();

  $this->gossip("Created $class object successfully.");

  return $this;
}
# /constructor



sub mediaName
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $oldorder = $this->{m_order};
  if(@_) {
    $this->{m_order} = shift;
  }
  return $oldorder;
}



sub collect
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_collect};
}



sub baseurl
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $oldbaseurl = $this->{m_baseurl};
  if(@_) {
    $this->{m_baseurl} = shift;
  }
  return $oldbaseurl;
}



#sub initialiseHandlers
#{
#  #...
#  # read all pm files from a given directory, try to load the handlers
#  # and create a respective object for each (store in a list)
#  #---
#  my $this = shift;
#
#  my $retval = undef;
#
#  if(not defined($this->{m_plugindir})) {
#    $this->{m_logger}->error("[ERROR] [RepoMetaHandler::initialiseHandlers] plugin directory not set!");
#    return $retval;
#  }
#
#  if(not opendiri(PLUGINDIR, $this->{m_plugindir})) {
#    $this->{m_logger}->error("[ERROR] [RepoMetaHandler::initialiseHandlers] cannot open $this->{m_plugindir}");
#    return $retval;
#  }
#  my @plugins = readdir(PLUGINDIR);
#  closedir(PLUGINDIR);
#}



sub gossip
{
  my $this = shift;
  my $message = shift;
  if(defined($message) and $this->{m_collect}->debugflag()) {
    $this->{m_collect}->logger()->info("$message");
  }
}



#...
# loadPlugins(DIR)
# - load all plugins available in directory DIR
# return number of loaded plugins, 0 in case of error
#---
sub loadPlugins
{
  my $this = shift;

  my $retval = 0;
  my $dir = shift;
  if(not defined($dir)) {
    return $retval;
  }
  # remove annoying trailing slashes:
  #$dir =~ s{(.*)/+$}{$1};
  unshift @INC, $dir;
  if(not opendir(PLUGINDIR, "$dir")) {
    $this->gossip("loadPlugins: cannot open directory $dir");
    return $retval;
  }

  my @plugins = readdir(PLUGINDIR);
  closedir(PLUGINDIR);

  foreach my $p(@plugins) {
    chomp $p;
    next if(-d "$p");
    next if($p !~ m{.*[.]pm});

    my $loadsuccess = $this->loadPlugin("$dir/$p");
    if($loadsuccess == 1) {
      $this->gossip("loadPlugins: loaded plugin $p from url $dir successfully.");
      $retval++;
    }
    else {
      $this->gossip("loadPlugins: failed to load plugin $p from url $dir!");
    }
  }

  return $retval;
}



#...
# loadPlugin(FILE)
# - load a specific plugin and do all the checks
#   (required packages, directories, order number free etc.)
# return 1 on success, 0 on failure
#---
sub loadPlugin
{
  my $this = shift;
  my $retval = 0;

  my $file = shift;
  if(not(defined($file) and -f $file)) {
    $this->{m_collect}->logger()->error("loadPlugin: file=$file maybe not readable");
    return $retval;
  }

  $file =~ m{(.*)/(.*)([.]pm)$};
  my $plugin = $2;
  if(not defined($plugin)) {
    $this->{m_collect}->error("loadPlugin: something in regexp broken: $file =~ m{(.*)/(.*)([.]pm)$}...?");
    return $retval;
  }

  eval "require $plugin";
  if($@) {
    $this->{m_collect}->logger()->error("loadPlugin: loading $plugin failed");
  }
  else {
    my $object = ($plugin)->new($this);
    my $addsuccess = $this->_addPlugin($object);
    #my $addsuccess = $this->_addPlugin(new($plugin, $this));
    if($addsuccess) {
      $retval = 1;
    }
  }
  return $retval;
}



sub _addPlugin
{
  my $this = shift;
  if(not ref $this) {
    return undef;
  }
  my $retval = 0;
  my $plugin = shift;

  my $order = $plugin->order();
  #my $name  = $plugin->name();
  #my @dirs  = $plugin->requiredDirs();
  #my @reqs  = $plugin->requires();
  #my @desc  = $plugin->description();

  if(not defined($order)) {
    $this->{m_collect}->logger()->info("Undefined order of plugin $plugin->name()");
  }
  else {
    if(defined($this->{m_handlers}->{$order})) {
      # we have a problem: (TODO in the future)
      die "Can't handle mutliple occurences of ordernumbers yet! See next version!";
    }
    else {
      $this->{m_handlers}->{$order} = $plugin;
      $retval = 1;
    }
  }
  return $retval;
}



sub getPlugin
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }

  my $index = shift;
  if(not defined($index)) {
    return undef;
  }
  else {
    if(not defined($this->{m_handlers}->{$index})) {
      $this->{m_collect}->logger()->warning("no plugin defined with index $index");
      return undef;
    }
    else {
      return $this->{m_handlers}->{$index};
    }
  }
}



sub createMetadata
{
  my $this = shift;
  if(not ref $this) {
    return undef;
  }
  my $retval = 0;
  # execute all registered and activated plugins:

  foreach my $order(sort {$a lt $b } keys(%{$this->{m_handlers}})) {
    if($this->{m_handlers}->{$order}->ready()) {
      $this->{m_handlers}->{$order}->execute();
    }
    else {
      $this->gossip("Plugin $this->{m_handlers}->{$order}->name() is not activated yet!");
    }
  }
}



1;

