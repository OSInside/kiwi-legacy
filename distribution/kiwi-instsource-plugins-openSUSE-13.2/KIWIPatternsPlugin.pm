################################################################
# Copyright (c) 2008 Jan-Christoph Bornschlegel, SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file LICENSE); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################

#================
# FILE          : KIWIPatternsPlugin.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Module creating the "patterns" file
#               :
# STATUS        : Development
#----------------

package KIWIPatternsPlugin;

use strict;

use base "KIWIBasePlugin";
use Config::IniFiles;


sub new
{
  # ...
  # Create a new KIWIPatternsPlugin object
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
  #name = KIWIPatternsPlugin
  #dir = $DATADIR/setup/descr
  #order = 1
  #tool = create_package_descr
  #tooldir = /usr/bin
  #toolpack = inst-source-utils
  #defaultenabled = 1
  #media = 1
  #
  #[target]
  #targetfile = patterns
  #compress = yes|no
  #
  my $ini = new Config::IniFiles( -file => "$configpath/$configfile" );
  my $name    = $ini->val('base', 'name'); # scalar value
  my $order   = $ini->val('base', 'order'); # scalar value
  my @dirs    = $ini->val('base', 'dir');	# here may be more than one
  my $enable  = $ini->val('base', 'defaultenable'); # scalar value
  my @media   = $ini->val('base', 'media'); # here may be a list again

  my $target  = $ini->val('target', 'targetfile');
  my $gzip    = $ini->val('target', 'compress');

  # if any of those isn't set, complain!
  if(not defined($name)
     or not defined($order)
     or not @dirs
     or not defined($enable)
     or not defined($target)
     or not defined($gzip)
     or not @media) {
    $this->logMsg("E", "Plugin ini file <$config> seems broken!\n");
    return undef;
  }

  # parse dirs for productvars content:
  for(my $i=0; $i <= $#dirs; $i++) {
    $dirs[$i] = $this->collect()->productData()->_substitute("$dirs[$i]");
  }

  $this->name($name);
  $this->order($order);
  $this->requiredDirs(@dirs);
  $this->{m_media} = @media;
  if($enable != 0) {
    $this->ready(1);
  }
  $this->{m_compress} = $gzip;
  $this->{m_target} = $target;

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

  my $dirname = $this->{m_handler}->baseurl()."/".$this->{m_handler}->mediaName();
  my $mult = $this->collect()->productData()->getVar("MULTIPLE_MEDIA");
  if( $mult ne "no") {
    $dirname .= $this->{m_media};
  }
  $dirname .= "/".$this->{m_requireddirs}->[0];

  if(!opendir(PATDIR, "$dirname")) {
    $this->logMsg("E", "PatternsPlugin: cannot read <$dirname>");
    $this->logMsg("I", "Skipping plugin <".$this->name().">");
    return $retval;
  }
  if(!open(PAT, ">", "$dirname/$this->{m_target}")) {
    $this->logMsg("E", "PatternsPlugin: cannot create <$dirname>/patterns!");
    $this->logMsg("I", "Skipping plugin <".$this->name().">");
    return $retval;
  }
  my @dirent = readdir(PATDIR);
  foreach my $f(@dirent) {
    next if $f !~ m{(.*\.pat|.*\.pat\.gz)};
    if($f !~ m{.*\.gz$} and $this->{m_compress} =~ m{yes}i) {
      if (system('gzip', '--rsyncable', "$dirname/$f") == 0) {
	$f = "$f.gz";
      }
    }
    print PAT "$f\n";
  }
  close(PATDIR);	
  close(PAT);	

  $retval = 1;
  return $retval;
}



1;

