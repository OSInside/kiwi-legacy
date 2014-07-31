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
package KIWIPatternsPlugin;

use strict;
use warnings;

use base "KIWIBasePlugin";
use Config::IniFiles;

sub new {
  # ...
  # Create a new KIWIPatternsPlugin object
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
  # name = KIWIPatternsPlugin
  # dir = $DATADIR/setup/descr
  # order = 1
  # tool = create_package_descr
  # tooldir = /usr/bin
  # toolpack = inst-source-utils
  # defaultenabled = 1
  # media = 1
  #
  #[target]
  # targetfile = patterns
  # compress = yes|no
  #
  my $ini = Config::IniFiles ->new(
    -file => "$configpath/$configfile"
  );
  my $name    = $ini->val('base', 'name');
  my $order   = $ini->val('base', 'order');
  my @dirs    = $ini->val('base', 'dir');
  my $enable  = $ini->val('base', 'defaultenable');
  my @media   = $ini->val('base', 'media');
  my $target  = $ini->val('target', 'targetfile');
  my $gzip    = $ini->val('target', 'compress');
  # if any of those isn't set, complain!
  if(not defined($name)
    or not defined($order)
    or not @dirs
    or not defined($enable)
    or not defined($target)
    or not defined($gzip)
    or not @media
  ) {
    $this->logMsg("E",
      "Plugin ini file <$config> seems broken!\n"
    );
    return;
  }
  # parse dirs for productvars content:
  for(my $i=0; $i <= $#dirs; $i++) {
    $dirs[$i] = $this->collect()
      ->productData()->_substitute("$dirs[$i]");
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

sub execute {
  my $this = shift;
  if(not ref($this)) {
    return;
  }
  if($this->{m_ready} == 0) {
    return 0;
  }
  my $dirname = $this->{m_handler}->baseurl()
    . "/"
    . $this->{m_handler}->mediaName();
  my $mult = $this->collect()
    ->productData()->getVar("MULTIPLE_MEDIA");
  if( $mult ne "no") {
    $dirname .= $this->{m_media};
  }
  $dirname .= "/".$this->{m_requireddirs}->[0];
  my $PATDIR;
  if(!opendir($PATDIR, "$dirname")) {
    $this->logMsg("E",
      "PatternsPlugin: cannot read <$dirname>"
    );
    $this->logMsg("I",
      "Skipping plugin <".$this->name().">"
    );
    return 0;
  }
  my $PAT = FileHandle -> new();
  if (! $PAT -> open(">$dirname/$this->{m_target}")) {
    $this->logMsg("E",
      "PatternsPlugin: cannot create <$dirname>/patterns!"
    );
    $this->logMsg("I",
      "Skipping plugin <".$this->name().">"
    );
    return 0;
  }
  my @dirent = readdir($PATDIR);
  foreach my $f(@dirent) {
    next if $f !~ m{.*\.pat|.*\.pat\.gz}x;
    if($f !~ m{.*\.gz$}x and $this->{m_compress} =~ m{yes}i) {
      if (system('gzip', '--rsyncable', "$dirname/$f") == 0) {
        $f = "$f.gz";
      }
    }
    print $PAT "$f\n";
  }
  closedir($PATDIR);
  $PAT -> close();
  return 1;
}

1;
