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
# FILE          : KIWIContentPlugin.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Module creating the content file
#               :
# STATUS        : Development
#----------------

package KIWIContentPlugin;

use strict;

use base "KIWIBasePlugin";
use Data::Dumper;
use Config::IniFiles;


sub new
{
  # ...
  # Create a new KIWIContentPlugin object
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

  my $target	= $ini->val('target', 'targetfile');
  my $targetdir	= $ini->val('target', 'targetdir');
  my @media	= $ini->val('target', 'media');

  # if any of those isn't set, complain!
  if(not defined($name)
     or not defined($order)
     or not defined($enable)
     or not defined($target)
     or not defined($targetdir)
     or not @media
    ) {
    $this->logMsg("E", "Plugin ini file <$config> seems broken!");
    return undef;
  }

  $this->name($name);
  $this->order($order);
  $targetdir = $this->collect()->productData()->_substitute("$targetdir");
  if($enable != 0) {
    $this->ready(1);
  }
  $this->requiredDirs($targetdir);
  $this->{m_target} = $target;
  $this->{m_targetdir} = $targetdir;
  @{$this->{m_media}} = @media;

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

  my @targetmedia = $this->collect()->getMediaNumbers();
  my %targets;
  if($this->{m_media}->[0] =~ m{all}i) {
    %targets = map { $_ => 1 } @targetmedia;
  }
  else {
    foreach my $cd(@{$this->{m_media}}) {
      if(grep { $cd } @targetmedia) {
	$targets{$cd} = 1;
      }
    }
  }
  
  my $info = $this->collect()->productData()->getSet("prodinfo");
  if(!$info) {
    $this->logMsg("E", "data set named <prodinfo> seems to be broken:");
    $this->logMsg("E", Dumper($info));
    return $retval;
  }

  foreach my $cd(keys(%targets)) {
    $this->logMsg("I", "Creating content file on medium <$cd>:");
    my $dir = $this->collect()->basesubdirs()->{$cd};
    my $contentfile = "$dir/$this->{m_target}";
    if(not open(CONT, ">", $contentfile)) {
      $this->logMsg("E", "Cannot create <$contentfile> on medium <$cd>");
      next;
    }

    # compute maxlen:
    my $len = 0;
    foreach(keys(%{$info})) {
      my $l = length($info->{$_}->[0]);
      $len = ($l>$len)?$l:$len;
    }
    $len++;
    foreach my $i(sort { $a <=> $b } keys(%{$info})) {
      print CONT sprintf('%-*s %s', $len, $info->{$i}->[0], $info->{$i}->[1])."\n";
    }
    close(CONT);

    $this->logMsg("I", "Wrote file <$contentfile> for medium <$cd> successfully.");
    $retval++;
  }

  return $retval;
}



1;

