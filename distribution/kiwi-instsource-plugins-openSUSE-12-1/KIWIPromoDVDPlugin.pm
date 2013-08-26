################################################################
# Copyright (c) 2012 SUSE
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
# FILE          : KIWIPromoDVDPlugin.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Stephan Kulow <coolo@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Module patching mini iso builds
#               :
# STATUS        : Development
#----------------

package KIWIPromoDVDPlugin;

use strict;

use base "KIWIBasePlugin";
use Data::Dumper;
use Config::IniFiles;
use File::Find;
use File::Basename;


sub new
{
  # ...
  # Create a new KIWIPromoDVDPlugin object
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
  if($ismini !~ m{dvd-promo}i) {
    return $retval;
  }

  my $medium = $this->collect()->productData()->getVar("MEDIUM_NAME");
  find( sub { 
     if (m/initrd.liv/) { 
       my $cd = $File::Find::name; 
       system("mkdir -p boot; echo $medium > boot/mbrid");
       system("echo boot/mbrid | cpio --create --format=newc --quiet | gzip -9 -f >> $cd");
       system("rm boot/mbrid; rmdir boot");
       $this->logMsg("I", "updated $cd");
      }  
     }, $this->handler()->collect()->basedir());

  return $retval;
}

1;

