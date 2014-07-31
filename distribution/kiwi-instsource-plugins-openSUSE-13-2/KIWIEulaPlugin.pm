################################################################
# Copyright (c) 2014 SUSE
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
package KIWIEulaPlugin;

use strict;
use warnings;

use base "KIWIBasePlugin";
use Config::IniFiles;
use FileHandle;

sub new {
  # ...
  # Create a new KIWIEulaPlugin object
  # creates patterns file
  # ---
  my $class   = shift;
  my $handler = shift;
  my $config  = shift;
  my $configpath;
  my $configfile;
  my $this = KIWIBasePlugin -> new($handler);
  bless ($this, $class);
  if ($config =~ m{(.*)/([^/]+)$}x) {
    $configpath = $1;
    $configfile = $2;
  }
  if ((! $configpath) || (! $configfile)) {
    $this->logMsg("E",
      "wrong parameters in plugin initialisation\n"
    );
    return;
  }
  ## plugin content:
  #-----------------
  #[base]
  # name = KIWIEulaPlugin
  # order = 3
  # src = packages.en[.gz]
  # srcdir = $DESCRDIR
  # tool = packages2eula.pl
  # tooldir = /usr/bin
  # toolpack = inst-source-utils
  # defaultenable = 1
  #
  #[target]
  # targetfile = EULA.txt
  # targetdir = $PRODUCT_DIR
  #
  my $ini = Config::IniFiles -> new(
    -file => "$configpath/$configfile"
  );
  my $name     = $ini->val('base', 'name');
  my $order    = $ini->val('base', 'order');
  my $tool     = $ini->val('base', 'tool');
  my $tooldir  = $ini->val('base', 'tooldir');
  my $toolpack = $ini->val('base', 'toolpack');
  my $enable   = $ini->val('base', 'defaultenable');
  my $src      = $ini->val('base', 'sourcefile');
  my $srcdir   = $ini->val('base', 'sourcedir');
  my $iopt     = $ini->val('option', 'in');
  my $oopt     = $ini->val('option', 'out');
  my $popt     = $ini->val('option', 'packfile');
  my $target   = $ini->val('target', 'targetfile');
  my $targetdir= $ini->val('target', 'targetdir');
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
    or not defined($popt)
  ) {
    $this->logMsg("E",
      "Plugin ini file <$config> seems broken!\n"
    );
    return;
  }
  $this->name($name);
  $this->order($order);
  $targetdir = $this->collect()
    ->productData()->_substitute("$targetdir");
  $srcdir = $this->collect()
    ->productData()->_substitute("$srcdir");
  $this->{m_target} = $target;
  if($enable != 0) {
    $this->ready(1);
  }
  $this->{m_source} = $src;
  $this->{m_srcdir} = $srcdir;
  $this->{m_tool} = $tool;
  $this->{m_toolpath} = $this->collect()
    ->productData()->_substitute("$tooldir");
  $this->{m_toolpack} = $toolpack;
  $this->{m_iopt} = $iopt;
  $this->{m_oopt} = $oopt;
  $this->{m_popt} = $popt;
  $this->requiredDirs($srcdir, $targetdir);
  return $this;
}

sub execute {
  my $this = shift;
  if(not ref($this)) {
    return;
  }
  my $retval = 0;
  if($this->{m_ready} == 0) {
    return $retval;
  }
  my @dirlist = $this->getSubdirLists();
  return unless @dirlist && $dirlist[0] &&
    ref ($dirlist[0] eq "ARRAY") && $dirlist[0]->[0];
  my $dirname = $dirlist[0]->[0];
  my $srcdir = $dirname."/".$this->{m_requireddirs}->[0];
  my $targetdir = $dirname."/".$this->{m_requireddirs}->[1];
  my $SRCFILE = FileHandle -> new();
  if (! $SRCFILE -> open ("<$srcdir/$this->{m_source}")) {
    $this->logMsg("E",
      "PatternsPlugin: cannot read <$srcdir/".$this->{m_source}.">"
    );
    $this->logMsg("I", "Skipping plugin <".$this->name().">");
    return $retval;
  }
  $SRCFILE -> close();
  my $cmd = "$this->{m_toolpath}/$this->{m_tool} "
    . "$this->{m_iopt} $targetdir/$this->{m_target} "
    . "$this->{m_popt} $srcdir/$this->{m_source} "
    . "$this->{m_oopt} $targetdir/$this->{m_target}.new";
  my $call = $this -> callCmd($cmd);
  my $status = $call->[0];
  my @data = @{$call->[1]};
  $this->logMsg("I", "output of command $this->{m_tool}:\n");
  foreach my $l(@data) {
    $this->logMsg("I", "\t$l\n");
  }
  if($status) {
    $this->logMsg("I",
      "command $this->{m_tool} exited with <$status>\n"
    );
  } else {
    $this->logMsg("I",
      "command $this->{m_tool} exited successfully.\n"
    );
    $retval = 1;
  }
  return $retval;
}

1;
