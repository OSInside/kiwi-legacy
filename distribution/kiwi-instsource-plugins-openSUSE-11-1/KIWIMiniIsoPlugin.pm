#================
# FILE          : KIWIMiniIsoPlugin.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Module patching mini iso builds
#               :
# STATUS        : Development
#----------------

package KIWIMiniIsoPlugin;

use strict;

use base "KIWIBasePlugin";
use Data::Dumper;
use Config::IniFiles;
use File::Find;


sub new
{
  # ...
  # Create a new KIWIMiniIsoPlugin object
  # ---
  my $class   = shift;
  my $handler = shift;
  my $config  = shift;

  my $this = new KIWIBasePlugin($handler);
  bless ($this, $class);

  $config =~ m{(.*)/([^/]+)$};
  my $configpath = $1;
  my $configfile = $2;
  if(not defined($configpath) or not defined($configfile)) {
    $this->logMsg("E", "wrong parameters in plugin initialisation\n");
    return undef;
  }

  ## now gather all necessary information from the inifile:
  #===
  # Issue: why duplicate code here? Why not put it into the base class?
  # Answer: Each plugin may have different options. Some only need a target filename,
  # whilst some others may need much more. I don't want to specify a complicated framework
  # for the plugin, it shall just be a simple straightforward way to get information
  # into the plugin. The idea is that the people who decide on the metadata write
  # the plugin, and therefore damn well know what it needs and what not.
  # I'm definitely not bothering PMs with Yet Another File Specification (tm)
  #---

  ## plugin content:
  #-----------------
  #[base]
  #name = KIWIEulaPlugin
  #order = 3
  #defaultenable = 1
  #
  #[target]
  #targetfile = content
  #targetdir = $PRODUCT_DIR
  #media = (list of numbers XOR "all")
  #
  my $ini = new Config::IniFiles( -file => "$configpath/$configfile" );
  my $name	= $ini->val('base', 'name'); # scalar value
  my $order	= $ini->val('base', 'order'); # scalar value
  my $enable	= $ini->val('base', 'defaultenable'); # scalar value

  # if any of those isn't set, complain!
  if(not defined($name)
     or not defined($order)
     or not defined($enable)
    ) {
    $this->logMsg("E", "Plugin ini file <$config> seems broken!\n");
    return undef;
  }

  $this->name($name);
  $this->order($order);
  if($enable != 0) {
    $this->ready(1);
  }
  return $this;
}
# /constructor



sub execute
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $retval = 0;
  # sanity check:
  if($this->{m_ready} == 0) {
    return $retval;
  }

  my $repoloc = $this->collect()->productData()->getOpt("REPO_LOCATION");
  my $ismini = $this->collect()->productData()->getVar("FLAVOR");
  if(not defined($repoloc) or $repoloc =~ m{notset}i) {
    $this->logMsg("W", "<REPO_LOCATION> is missing, can't patch <gfxboot.cfg>!");
    return $retval;
  }
  if(not defined($ismini) or $ismini =~ m{notset}i) {
    $this->logMsg("W", "Can't determine if this is a miniiso! Doing nothing");
    return $retval;
  }
  $repoloc =~ m{^http://([^/]+)/(.+)};
  my ($srv, $path) = ($1, $2);

  if($ismini !~ m{mini}i and !$srv) {
    $this->logMsg("I", "Nothing to for for media type <$ismini>");
    return $retval;
  }

  my @gfxbootfiles;
  find( sub { find_cb($this, \@gfxbootfiles) }, $this->handler()->collect()->basedir());

  if(!@gfxbootfiles) {
    $this->logMsg("E", "No gfxboot.cfg file found!");
    return $retval;
  }

  foreach my $cfg(@gfxbootfiles) {
    $this->logMsg("I", "Processing file <$cfg>: ");
    if(not open(F, "<", $cfg)) {
      $this->logMsg("E", "Cant open file <$cfg>!");
      next;
    }
    my @lines = <F>;
    close(F);
    chomp(@lines);
    my $install = -1;
    my $ihs = -1;
    my $ihp = -1;
    my $i = -1;
    foreach my $line(@lines) {
      $i++;
      next if $line !~ m{^install};
      if($line =~ m{^install=.*}) {
	$install = $i;
      }
      if($line =~ m{^install.http.server=+}) {
	$ihs = $i;
      }
      if($line =~ m{^install.http.path=+}) {
	$ihp = $i;
      }
    }

    if($ismini =~ m{mini}i) {
      if($install == -1) {
	push @lines, "install=slp";
      }
      else {
	$lines[$install] =~ s{^install.*}{install=slp};
      }
    }
    else {
      if($ihs == -1) {
	push @lines, "install.http.server=$srv";
      }
      else {
	$lines[$ihs] =~ s{^(install.http.server).*}{$1=$srv};
      }
      if($ihp == -1) {
	push @lines, "install.http.path=$path";
      }
      else {
	$lines[$ihp] =~ s{^(install.http.path).*}{$1=$path};
      }
      if($install == -1) {
	push @lines, "install=http";
      }
      else {
	$lines[$install] =~ s{^install.*}{install=http};
      }
    }
    unlink $cfg;
    open(F, ">", $cfg);
    foreach(@lines) {
      print F "$_\n";
    }
    close(F);
    $retval++;
  }
  return $retval;
}



sub find_cb
{
  my $this = shift;
  return undef if not ref($this);

  my $listref = shift;
  return undef if not defined($listref);

  if($File::Find::name =~ m{.*/gfxboot\.cfg$}) {
    push @{$listref}, $File::Find::name;
  }
}



1;

