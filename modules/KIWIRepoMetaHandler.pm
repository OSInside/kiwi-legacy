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
    m_baseurl	=> undef,     # base url where $MEDIUMNAME$NR reside (m_united that is)
  };
  bless ($this, $class);

  # other init work:
  $this->{m_collect}	= shift;  # first and most important thing: store the caller object
  if(not defined($this->{m_collect})) {
    return; # rock hard get outta here: caller must check retval anyway
  }
  #$this->{m_unitedir}	= $this->{m_collect}->unitedDir();

  $this->collect()->logMsg("I", "Created $class object successfully.");

  return $this;
}
# /constructor



#==================
# access methods
#------------------



#==================
# media name
#------------------
sub mediaName
{
  my $this = shift;
  if(not ref($this)) {
    return;
  }
  my $oldname = $this->{m_medianame};
  if(@_) {
    $this->{m_medianame} = shift;
  }
  return $oldname;
}



#==================
# collect object (ro)
#------------------
sub collect
{
  my $this = shift;
  if(not ref($this)) {
    return;
  }
  return $this->{m_collect};
}



#==================
# base url
#------------------
sub baseurl
{
  my $this = shift;
  if(not ref($this)) {
    return;
  }
  my $oldbaseurl = $this->{m_baseurl};
  if(@_) {
    $this->{m_baseurl} = shift;
  }
  return $oldbaseurl;
}



#==================
# regular methods
#------------------



#==================
# loadPlugins(DIR)
# - load all plugins available in directory DIR
# return number of loaded plugins, 0 in case of error
#------------------
sub loadPlugins
{
  my $this = shift;

  my $loaded = 0;
  my $avail = 0;
  my $dir = shift;
  if(not defined($dir)) {
    $dir = $this->collect()->productData()->getOpt("PLUGIN_DIR");
    if(not defined($dir)) {
      return ($loaded, $avail);
    }
  }

  my $inidir = $this->collect()->productData()->getOpt("INI_DIR");
  unshift @INC, $dir;
  if(not opendir(PLUGINDIR, "$dir")) {
    $this->collect()->logMsg("W", "loadPlugins: cannot open directory $dir");
    return ($loaded, $avail);
  }

  my @plugins = readdir(PLUGINDIR);
  closedir(PLUGINDIR);

  # fish out plugins:
  my %plugins;
  foreach my $p(@plugins) {
    chomp($p);
    next if( -d "$p");
    if($p =~m{(.*Plugin)\.pm}) {
      my $prefix;
      if(defined($inidir)) {
	$prefix = "$inidir/";
      }
      else {
	$prefix = "$dir/";
      }
      if( -f "$prefix$1.ini") {
	$plugins{$1} = "$prefix$1.ini";
      }
      else {
	$this->collect()->logMsg("W", "loadPlugins: no ini file found for plugin <$1>, skipping\n");
      }
    }
  }

  foreach my $p(keys(%plugins)) {
    my $loadsuccess = $this->loadPlugin("$dir/$p", $plugins{$p});
    $avail++;
    if($loadsuccess == 1) {
      $this->collect()->logMsg("I", "loadPlugins: loaded plugin $p from url $dir successfully.");
      $loaded++;
    }
    else {
      $this->collect()->logMsg("E", "loadPlugins: failed to load plugin <$p> from url <$dir>: $@");
    }
  }

  return ($loaded, $avail);
}



#...
# loadPlugin(plugin, inifile)
# - load a specific plugin and do all the checks
#   (required packages, directories, order number free etc.)
# return 1 on success, 0 on failure
#---
sub loadPlugin
{
  my $this = shift;
  my $retval = 0;

  my $file = shift;
  if($file =~ m{^.*/[a-zA-Z_-]+$}) {
    $file .= ".pm";
  }
  if(not(defined($file) and -f $file)) {
    $this->{m_collect}->logMsg("E", "loadPlugin: file=<$file> maybe not readable");
    return $retval;
  }

  $file =~ m{(.*)/(.*)([.]pm)$};
  my $plugin = $2;
  if(not defined($plugin)) {
    $this->{m_collect}->logMsg("E", "loadPlugin: something in regexp broken: $file =~ m{(.*)/(.*)([.]pm)$}...?");
    return $retval;
  }

  eval "require $plugin"; ## no critic
  if($@) {
    $this->{m_collect}->logMsg("E", "loadPlugin: loading <$plugin> failed");
  }
  else {
    my $inifile = shift;
    if(!$inifile) {
      $this->{m_collect}->logMsg("E", "can't load inifile <$inifile> for plugin <$plugin>");
    }
    else {
      my $object = ($plugin)->new($this, $inifile);
      if(not defined($object)) {
	$this->{m_collect}->logMsg("E", "Unable to create object of <$plugin>: constructor failed!");
      }
      else {
	my $addsuccess = $this->_addPlugin($object);
	if($addsuccess) {
	  $retval = 1;
	}
      }
    }
  }
  return $retval;
}



sub _addPlugin
{
  my $this = shift;
  if(not ref $this) {
    return;
  }
  my $retval = 0;
  my $plugin = shift;

  my $order = $plugin->order();

  if(not defined($order)) {
    my $n = $plugin->name();
    if(not defined($n)) {
      $n = "Name not set";
    }
    $this->{m_collect}->logMsg("I", "Undefined order of plugin <$n>");
  }
  else {
    if(defined($this->{m_handlers}->{$order})) {
      # we have a problem: (TODO in the future)
      $this->collect()->logMsg("E", "Can't handle multiple occurance of order!");
      return $retval;
      #die "Can't handle mutliple occurences of ordernumbers yet!";
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
    return;
  }

  my $index = shift;
  if(not defined($index)) {
    return;
  }
  else {
    if(not defined($this->{m_handlers}->{$index})) {
      $this->collect()->logMsg("W", "no plugin defined with index <$index>\n");
      return;
    }
    else {
      return $this->{m_handlers}->{$index};
    }
  }
}



sub getPluginList
{
  my $this = shift;
  if(not ref($this)) {
    return;
  }

  return %{$this->{m_handlers}};
}



sub createMetadata
{
  my $this = shift;
  if(not ref $this) {
    return;
  }
  my $retval = 0;
  # execute all registered and activated plugins:

  foreach my $order(sort {$a <=> $b } keys(%{$this->{m_handlers}})) {
    if($this->{m_handlers}->{$order}->ready()) {
      $this->{m_handlers}->{$order}->execute();
    }
    else {
      $this->collect()->logMsg("W", "Plugin ".$this->{m_handlers}->{$order}->name()." is not activated yet!");
    }
  }
}



sub enableAllPlugins
{
  my $this = shift;
  if(not ref $this) {
    return;
  }

  foreach(values(%{$this->{m_handlers}})) {
    $_->ready(1);
  }
}



sub enablePlugins
{
  my $this = shift;
  if(not ref $this) {
    return;
  }

  my @enable = @_;
  if(not @enable) {
    return;
  }

  my $retval = 0; # number of enabled plugins
  foreach(@enable) {
    $this->{m_handlers}->{$_}->ready(1);
    $retval++;
  }
  return $retval;
}



1;

