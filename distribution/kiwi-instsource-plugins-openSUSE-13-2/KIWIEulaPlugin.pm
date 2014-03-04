#================
# FILE          : KIWIEulaPlugin.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Module creating the EULA.txt file
#               :
# STATUS        : Development
#----------------

package KIWIEulaPlugin;

use strict;

use base "KIWIBasePlugin";
use Config::IniFiles;


sub new
{
  # ...
  # Create a new KIWIEulaPlugin object
  # creates patterns file
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
  #src = packages.en[.gz]
  #srcdir = $DESCRDIR
  #tool = packages2eula.pl
  #tooldir = /usr/bin
  #toolpack = inst-source-utils
  #defaultenable = 1
  #
  #[target]
  #targetfile = EULA.txt
  #targetdir = $PRODUCT_DIR
  #
  my $ini = new Config::IniFiles( -file => "$configpath/$configfile" );
  my $name	= $ini->val('base', 'name'); # scalar value
  my $order	= $ini->val('base', 'order'); # scalar value
  my $tool	= $ini->val('base', 'tool'); # scalar value
  my $tooldir   = $ini->val('base', 'tooldir'); # scalar value
  my $toolpack	= $ini->val('base', 'toolpack'); # scalar value
  my $enable	= $ini->val('base', 'defaultenable'); # scalar value
  my $src	= $ini->val('base', 'sourcefile'); # scalar value
  my $srcdir	= $ini->val('base', 'sourcedir'); # scalar value

  my $iopt	= $ini->val('option', 'in'); # scalar value
  my $oopt	= $ini->val('option', 'out'); # scalar value
  my $popt	= $ini->val('option', 'packfile'); # scalar value

  my $target  = $ini->val('target', 'targetfile');
  my $targetdir  = $ini->val('target', 'targetdir');

  # if any of those isn't set, complain!
  if(not defined($name)
     or not defined($order)
     or not defined($tool)
     or not defined($tooldir)
     or not defined($toolpack)
     or not defined($enable)
     or not defined($target)
     or not defined($targetdir)
     or not defined($iopt)
     or not defined($oopt)
     or not defined($popt)) {
    $this->logMsg("E", "Plugin ini file <$config> seems broken!\n");
    return undef;
  }

  $this->name($name);
  $this->order($order);
  $targetdir = $this->collect()->productData()->_substitute("$targetdir");
  $srcdir = $this->collect()->productData()->_substitute("$srcdir");
  $this->{m_target} = $target;
  if($enable != 0) {
    $this->ready(1);
  }
  $this->{m_source} = $src;
  $this->{m_srcdir} = $srcdir;
  $this->{m_tool} = $tool;
  $this->{m_toolpath} = $this->collect()->productData()->_substitute("$tooldir");
  $this->{m_toolpack} = $toolpack;
  $this->{m_iopt} = $iopt;
  $this->{m_oopt} = $oopt;
  $this->{m_popt} = $popt;
  $this->requiredDirs($srcdir, $targetdir);

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

  my @dirlist = $this->getSubdirLists();
  return undef unless @dirlist && $dirlist[0] && ref ($dirlist[0] eq "ARRAY") && $dirlist[0]->[0];
  my $dirname = $dirlist[0]->[0];

  my $srcdir = $dirname."/".$this->{m_requireddirs}->[0];
  my $targetdir = $dirname."/".$this->{m_requireddirs}->[1];

  if(!open(SRCFILE, "<", "$srcdir/".$this->{m_source})) {
    $this->logMsg("E", "PatternsPlugin: cannot read <$srcdir/".$this->{m_source}.">");
    $this->logMsg("I", "Skipping plugin <".$this->name().">");
    return $retval;
  }
  #if(!open(TARGET, ">", "$targetdir/".$this->{m_target}".new")) {
  #  $this->handler()->collect()->logger()->error("[E] PatternsPlugin: cannot create <$targetdir/".$this->{m_target}.">/!");
  #  $this->handler()->collect()->logger()->error("[I] Skipping plugin <".$this->name().">\n");
  #  return $retval;
  #}

  my $cmd = "$this->{m_toolpath}/$this->{m_tool} $this->{m_iopt} $targetdir/$this->{m_target} $this->{m_popt} $srcdir/$this->{m_source} $this->{m_oopt} $targetdir/$this->{m_target}.new";
  my @data = qx($cmd);
  #my $data = qx($this->{m_toolpath}/$this->{m_tool} -i "$this->{m_basesubdir}->{'1'}/EULA.txt" -p $pfilename -o "$this->{m_basesubdir}->{'1'}/EULA.txt.new");
  close(SRCFILE);

  $this->logMsg("I", "output of command $this->{m_tool}:\n");
  foreach my $l(@data) {
    chomp($l);
    $this->logMsg("I", "\t$l\n");
  }
  my $status = $? >> 8;
  if($status) {
    $this->logMsg("I", "command $this->{m_tool} exited with <$status>\n");
  }
  else {
    $this->logMsg("I", "command $this->{m_tool} exited successfully.\n");
    $retval = 1;
  }

  return $retval;
}



1;

