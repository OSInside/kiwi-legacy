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
# FILE          : KIWILiveTreePlugin.pm
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

package KIWILiveTreePlugin;

use strict;

use base "KIWIBasePlugin";
use Data::Dumper;
use Config::IniFiles;
use File::Find;
use File::Basename;


sub new
{
  # ...
  # Create a new KIWILiveTreePlugin object
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

sub logandrename($$$$)
{
  my $this = shift;
  my $dname = shift;
  my $oname = shift;
  my $nname = shift;
  $this->logMsg("I", "Renaming $dname/$oname to $dname/$nname");
  rename("$dname/$oname", "$dname/$nname") || die "no such file!";
}

# returns: number of patched gfxboot files
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

  my $ismini = $this->collect()->productData()->getVar("FLAVOR");
  if(not defined($ismini)) {
    $this->logMsg("W", "FLAVOR not set?");
    return $retval;
  }
  if($ismini !~ m{livetree}i) {
    return $retval;
  }

  my $x11cd = undef;
  find( sub { if (m/kiwi-profiled-livecd-kde.i586.iso/) { $x11cd = $File::Find::name; }  }, $this->handler()->collect()->basedir());
  if (!$x11cd) {
	$this->logMsg("E", "Initial CD not found\n");
	exit(1);
  }
  print "$x11cd\n";
  my $dname = dirname($x11cd);
  print "$dname\n";
  my $base = basename($dname);
  $base =~ s,openSUSE-Live-Tree-i586-x86_64,,;

  #logandrename($this, $dname, "kiwi-profiled-livecd-x11.i586.iso", "openSUSE-X11-LiveCD-i686-$base.iso");
  #logandrename($this, $dname, "kiwi-profiled-livecd-x11.x86_64.iso", "openSUSE-X11-LiveCD-x86_64-$base.iso");
  logandrename($this, $dname, "kiwi-profiled-livecd-kde.i586.iso", "openSUSE-KDE-LiveCD-i686$base.iso");
  logandrename($this, $dname, "kiwi-profiled-livecd-kde.x86_64.iso", "openSUSE-KDE-LiveCD-x86_64$base.iso");
  logandrename($this, $dname, "kiwi-profiled-livecd-gnome.i586.iso", "openSUSE-GNOME-LiveCD-i686$base.iso");
  logandrename($this, $dname, "kiwi-profiled-livecd-gnome.x86_64.iso", "openSUSE-GNOME-LiveCD-x86_64$base.iso");

  return $retval;
}

1;

