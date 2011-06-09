################################################################
# Copyright (c) 2008 Jan-Christoph Bornschlegel, Novell Inc.
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
# FILE          : KIWIDescrPlugin.pm
#----------------
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Module calling create_package_descr
#               :
# STATUS        : Development
#----------------

package KIWIDescrPlugin;

use strict;

use File::Basename;
use base "KIWIBasePlugin";
use Config::IniFiles;
use Data::Dumper;


sub new
{
  # ...
  # Create a new KIWIDescrPlugin object
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
    $this->logMsg("E", "wrong parameters in plugin initialisation");
    return undef;
  }

  my $ini = new Config::IniFiles( -file => "$configpath/$configfile" );
  my $name       = $ini->val('base', 'name'); # scalar value
  my $order      = $ini->val('base', 'order'); # scalar value
  my $tool       = $ini->val('base', 'tool'); # scalar value
  my $createrepo = $ini->val('base', 'createrepo'); # scalar value
  my $rezip      = $ini->val('base', 'rezip'); # scalar value
  my $tdir       = $ini->val('base', 'tooldir'); # scalar value
  my $tpack      = $ini->val('base', 'toolpack'); # scalar value
  my $enable     = $ini->val('base', 'defaultenable'); # scalar value

  my @params	 = $ini->val('options', 'parameter');

  my $gzip       = $ini->val('target', 'compress');

  # if any of those isn't set, complain!
  if(not defined($name)
     or not defined($order)
     or not defined($tool)
     or not defined($createrepo)
     or not defined($rezip)
     or not defined($tdir)
     or not defined($tpack)
     or not defined($enable)
     or not defined($gzip)
     or not (@params)) {
    $this->logMsg("E", "Plugin ini file <$config> seems broken!");
    return undef;
  }

  # sanity check for tools' existence:
  if(not( -f "$tdir/$tool" and -x "$tdir/$tool")) {
    $this->logMsg("E", "Plugin <$name>: tool <$tdir/$tool> is not executable!");
    $this->logMsg("I", "Check if package <$tpack> is installed.");
    return undef;
  }

  my $params = "";
  foreach my $p(@params) {
    $p = $this->collect()->productData()->_substitute("$p");
    $params .= "$p ";
  }

  $this->name($name);
  $this->order($order);
  $this->{m_tool} = $tool;
  $this->{m_tooldir} = $tdir;
  $this->{m_toolpack} = $tpack;
  $this->{m_createrepo} = $createrepo;
  $this->{m_rezip} = $rezip;
  $this->{m_params} = $params;
  $this->{m_compress} = $gzip;
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

  my $coll = $this->{m_collect};
  my $basesubdirs = $coll->basesubdirs();
  if(not defined($basesubdirs)) {
    ## prevent crash when dereferencing
    $this->logMsg("E", "<basesubdirs> is undefined! Skipping <$this->name()>");
    return $retval;
  }

  foreach my $dirlist($this->getSubdirLists()) {
    my ($s,$m) = $this->executeDir(sort @{$dirlist});
  }
#  if( $coll->productData()->getVar("FLAVOR") =~ m{ftp}i ) {
#    foreach my $d(values %{$basesubdirs}) {
#      my @a;
#      push @a, $d;
#      $retval += $this->executeDir( @a );
#    }
#  }
#  else {
#    my @paths = values(%{$basesubdirs});
#    @paths = grep { $_ =~ /[^0]$/ } @paths; # remove Media0
#    @paths = sort @paths; # sort it
#    $retval += $this->executeDir( @paths );
#  }
  return $retval;
}



sub executeDir
{
  my $this     = shift;
  my @paths    = @_;
  my $retval   = 0;
  if(!@paths) {
    $this->logMsg("W", "Empty path list!");
    return $retval;
  }

  my $coll  = $this->{m_collect};
  my $datadir  = $coll->productData()->getInfo("DATADIR");
  my $descrdir = $coll->productData()->getInfo("DESCRDIR");
  my $createrepomd = $coll->productData()->getVar("CREATE_REPOMD");

  my $targetdir = $paths[0]."/".$descrdir;

  ## this ugly bit creates a parameter string from a list of directories:
  # param = -d <dir1> -d <dir2> ...
  # the order is important. Idea: use map to make hash <dir> => -d for all subdirs not ending with "0"
  # (those are for metafile unpacking only). The result is evaluated in list context be reverse, so there's a list
  # looking like "<dir_N> -d ... <dir1> -d" which is reversed again, making the result
  # '-d', '<dir1>', ..., '-d', '<dir_N>'", after the join as string.
  my $pathlist = "-d ".join(' -d ', map{$_."/".$datadir}(@paths));

  $this->logMsg("I", "Calling ".$this->name()." for directories <@paths>:");

  my $cmd = "$this->{m_tooldir}/$this->{m_tool} $pathlist $this->{m_params} -o ".$paths[0]."/".$descrdir;
  $this->logMsg("I", "Executing command <$cmd>");
  my $data = qx( $cmd );
  my $status = $? >> 8;
  if($status) {
    $this->logMsg("E", "Calling <$cmd> exited with code <$status> and the following output:\n$data\n");
    return $retval;
  }

  if ( $createrepomd eq "true" ) {
    foreach my $p (@paths) {
      my $cmd = "$this->{m_createrepo} $p/$datadir ";
      $this->logMsg("I", "Executing command <$cmd>");
      my $data = qx( $cmd );
      my $status = $? >> 8;
      if($status) {
        $this->logMsg("E", "Calling <$cmd> exited with code <$status> and the following output:\n$data\n");
        return $retval;
      }
      $cmd = "$this->{m_rezip} $p/$datadir ";
      $this->logMsg("I", "Executing command <$cmd>");
      my $data = qx( $cmd );
      my $status = $? >> 8;
      if($status) {
        $this->logMsg("E", "Calling <$cmd> exited with code <$status> and the following output:\n$data\n");
        return $retval;
      }
    }
  }

  foreach my $trans (glob('/usr/share/locale/en_US/LC_MESSAGES/package-translations-*.mo')) {
     $trans = basename($trans, ".mo");
     $trans =~ s,.*-,,;
     my $cmd = "/usr/bin/translate_packages.pl $trans < $targetdir/packages.en > $targetdir/packages.$trans";
     my $data = qx( $cmd );
     if($? >> 8) {
	 $this->logMsg("E", "Calling <translate_packages.pl $trans > failed:\n$data\n");
	 return 1;
     }
  }

  if($this->{m_compress} =~ m{yes}i) {
      foreach my $pfile(glob("$targetdir/packages*")) {
	  if(system("gzip", "--rsyncable", "$pfile") == 0) {
	      unlink "$targetdir/$pfile";
	  }
	  else {
	      $this->logMsg("W", "Can't compress file <$targetdir/$pfile>!");
	  }
      }
  }

  return 1;
}


1;

