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
  my $name    = $ini->val('base', 'name'); # scalar value
  my $order   = $ini->val('base', 'order'); # scalar value
  my $tool    = $ini->val('base', 'tool'); # scalar value
  my $tdir    = $ini->val('base', 'tooldir'); # scalar value
  my $tpack   = $ini->val('base', 'toolpack'); # scalar value
  my $enable  = $ini->val('base', 'defaultenable'); # scalar value

  my $pdbfiles	= $ini->val('options', 'pdbfiles');
  my @params	= $ini->val('options', 'parameter');
  my @langs	= $ini->val('options', 'language');

  my $gzip    = $ini->val('target', 'compress');

  # if any of those isn't set, complain!
  if(not defined($name)
     or not defined($order)
     or not defined($tool)
     or not defined($tdir)
     or not defined($tpack)
     or not defined($enable)
     or not defined($pdbfiles)
     or not defined($gzip)
     or not (@params)
     or not (@langs)) {
    $this->logMsg("E", "Plugin ini file <$config> seems broken!");
    return undef;
  }

  # sanity check for tools' existence:
  if(not( -f "$tdir/$tool" and -x "$tdir/$tool")) {
    $this->logMsg("E", "Plugin <$name>: tool <$tdir/$tool> is not executable!");
    $this->logMsg("I", "Check if package <$tpack> is installed.");
    return undef;
  }

  $this->name($name);
  $this->order($order);
  $this->{m_tool} = $tool;
  $this->{m_tooldir} = $tdir;
  $this->{m_toolpack} = $tpack;
  $this->{m_pdbfiles} = $pdbfiles;
  $this->{m_params} = join(' ', @params);
  $this->{m_languages} = join(' ', @langs);
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

  # ftp trees should get no connection. This should maybe get an optional switch.
  # FIXME: FLAVOR is not a good idea, but the media type is currently not reachable here.
  if( $coll->productData()->getvar("FLAVOR") =~ m{ftp}i ) {
    foreach my $d(values %{$basesubdirs}) {
      my @a;
      push @a, $d;
      $retval += $this->executeDir( @a );
    }
  }
  else {
    my @paths = values(%{$basesubdirs});
    @paths = grep { $_ =~ /[^0]$/ } @paths; # remove Media0
    @paths = sort @paths; # sort it
    $retval += $this->executeDir( @paths );
  }
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

  my $targetdir = $paths[0]."/".$descrdir;

  ## this ugly bit creates a parameter string from a list of directories:
  # param = -d <dir1> -d <dir2> ...
  # the order is important. Idea: use map to make hash <dir> => -d for all subdirs not ending with "0"
  # (those are for metafile unpacking only). The result is evaluated in list context be reverse, so there's a list
  # looking like "<dir_N> -d ... <dir1> -d" which is reversed again, making the result
  # '-d', '<dir1>', ..., '-d', '<dir_N>'", after the join as string.
  my $pathlist = "-d ".join(' -d ', map{$_."/".$datadir}(@paths));

  $this->logMsg("I", "Calling ".$this->name()." for directories <@paths>:");

  my $cmd = "$this->{m_tooldir}/$this->{m_tool} $this->{m_pdbfiles} $pathlist $this->{m_params} $this->{m_languages} -o ".$paths[0]."/".$descrdir;
  my $data = qx( $cmd );
  my $status = $? >> 8;
  my $linkname = "packages.sk";	# default link name for uncompressed file
  my $linktarget = "packages.cs";
  if($this->{m_compress} =~ m{yes}i) {
    if(!opendir(PATDIR, "$targetdir")) {
      $this->logMsg("E", "Can't open directory <$targetdir>!");
      return $retval;
    }
    my @files = readdir(PATDIR);
    closedir(PATDIR);

    foreach my $pfile(@files) {
      next if($pfile !~ m{^(packages[.]*.*)});
      if(system("gzip", "$targetdir/$pfile") == 0) {
	unlink "$targetdir/$pfile";
	if($pfile =~ m{packages.(cs|cz)}) {
	  $linktarget .= ".gz";
	  $linkname .= ".gz";
	}
      }
      else {
	$this->logMsg("W", "Can't compress file <$targetdir/$pfile>!");
      }
    }
  }
  symlink "$linktarget", "$targetdir/$linkname";

  $retval = 1;
  return $retval;
}


1;

