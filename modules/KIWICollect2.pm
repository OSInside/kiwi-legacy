#================
# FILE          : KIWICollect2.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module collects sources from various source trees
#               : and creates one base directory structure which can be
#               : used as base for CD creation
#               :
#               :
# STATUS        : Development
#----------------

BEGIN {
  unshift @INC, "/usr/share/inst-source-utils/modules";
}

package KIWICollect2;

#==========================================
# Modules
#------------------------------------------
use strict;
use KIWIXML;
use KIWIUtil;
use KIWIURL;
use KIWIRepoMetaHandler;
use KIWIProductData;
use KIWIArchList;

use RPMQ;

use File::Find;
use File::Path;
use Cwd 'abs_path';
#use IO::Compress::Gzip qw(gzip $GzipError); # temporarily: as soon as plugins extracted, scratch here
#use PerlIO::gzip qw(gzip $GzipError); # temporarily: as soon as plugins extracted, scratch here

# remove if not longer necessary:
use Data::Dumper;

#==========================================
# Members
#------------------------------------------
# m_kiwi:
#   Instance of KIWILog for feedback
# m_xml:
#   Instance of KIWIXML for retrieving the data contained
#   in the xml description file
# m_util:
#   Instance of KIWIUtil which provides several methods to
#   analyse directories locally and via http(s)
# m_basedir:
#   Directory under which everything is accumulated
#   (aka downloaded/copied to)
# m_packagePool:
#   All available packages in all repos
# m_repoPacks:
#   list of all packages from the config file for main repo.
#   (...)
# m_sourcePacks:
#   source rpms, which are refered from m_repoPacks
# m_debugPacks:
#   debug rpms, which are refered from m_repoPacks
# m_srcmedium:
#   source medium number
# m_debugmedium:
#   debug medium number
#
# ---BAUSTELLE---

#==========================================
# Constructor
#------------------------------------------
sub new {
  # ...
  # Create a new KIWICollect object which is used to create a
  # consistent package directory from various source trees
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $class = shift;

  my $this  = {
    m_metacreator   => undef, # object handling the various metadata types
    m_archlist	    => undef,
    m_basedir	    => undef,
    m_repos	    => undef,
    m_xml	    => undef,
    m_util	    => undef,
    m_kiwi	    => undef,
    m_packagePool   => undef,
    m_repoPacks	    => undef,
    m_sourcePacks   => undef,
    m_debugPacks    => undef,
    m_metaPacks     => undef,
    m_metafiles	    => undef,
    m_browser	    => undef,
    m_logger	    => undef,
    m_srcmedium	    => undef,
    m_debugmedium   => undef,
    m_fpacks	    => [],
    m_fmpacks	    => [],
    m_fsrcpacks	    => [],
    m_fdebugpacks   => [],
    m_debug	    => undef,
  };

  bless $this, $class;

  #==========================================
  # Module Parameters
  #------------------------------------------
  $this->{m_kiwi}     = shift;
  $this->{m_xml}      = shift;
  $this->{m_basedir}  = shift;
  $this->{m_debug}    = shift || 0;

  if( !(defined($this->{m_xml})
	and defined($this->{m_basedir})
	and defined($this->{m_kiwi})))
  {
    return undef;
  }

  # work with absolute paths from here.
  $this->{m_basedir} = abs_path($this->{m_basedir});

  if($this->{m_debug} >= 2 || $ENV{'KIWI_COLLECT_TERMINAL_LOG'} ) {
    $this->{m_logger} = $this->{m_kiwi};
  }
  else {
    # create second logger object to log only the data relevant
    # for repository creation:
    $this->{m_logger} = new KIWILog("tiny");
    $this->{m_logger}->setLogHumanReadable();
    $this->{m_logger}->setLogFile("$this->{m_basedir}/collect.log");
    $this->{m_kiwi}->info("Logging repository specific data to file $this->{m_basedir}/collect.log");
  }

  $this->{m_util} = new KIWIUtil($this->{m_logger});
  if(!$this->{m_util}) {
    $this->{m_logger}->error("[E] Can't create KIWIUtil object!");
    return undef;
  }
  else {
    $this->{m_logger}->info("[I] Created new KIWIUtil object\n");
    $this->{m_kiwi}->info("[I] Created new KIWIUtil object\n");
  }

  $this->{m_urlparser} = new KIWIURL($this->{m_logger});
  if(!$this->{m_urlparser}) {
    $this->{m_logger}->error("[E] Can't create KIWIURL object!");
    return undef;
  }
  else {
    $this->{m_logger}->info("[I] Created new KIWIURL object\n");
    $this->{m_kiwi}->info("[I] Created new KIWIURL object\n");
  }


  # create the product variables administrator object.
  # This must be incubated with the respective data in the Init() method
  $this->{m_proddata} = new KIWIProductData($this);
  if(!$this->{m_proddata}) {
    $this->{m_logger}->error("[E] Can't create KIWIProductData object!");
    return undef;
  }
  else {
    $this->{m_logger}->info("[I] Created new KIWIProductData object\n");
    $this->{m_kiwi}->info("[I] Created new KIWIProductData object\n");
  }

  $this->{m_kiwi}->info("KIWICollect2 object initialisation finished.\n");
  return $this;
}
# /constructor



#=================
# access methods:
#-----------------
sub logger
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $oldlog = $this->{m_logger};
  if(@_) {
    $this->{m_logger} = shift;
  }
  return $oldlog;
}



sub debugflag
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $olddeb = $this->{m_debug};
  if(@_) {
    $this->{m_debug} = shift;
  }
  return $olddeb;
}



sub unitedDir
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $oldunited = $this->{m_united};
  if(@_) {
    $this->{m_united} = shift;
  }
  return $oldunited;
}



sub archlist
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_archlist};
}



sub productData
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_proddata};
}



sub basedir
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_basedir};
}



sub basesubdirs
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_basesubdir};
}



#=================
# other methods:
#-----------------
#==========================================
# Init
#------------------------------------------
# does everything that needs to be done but
# makes no sense in the constructor:
# - setup the logger for repo creation stuff
# - create Utility object
# - retrieve lists of required packages
# - dump them (optional)
# - create LWP client object
# - calls "normaliseDirname for each repo's sourcedirs
#   (stores the result in repo->[name]->'basedir')
# - creates path list for each repo
#   (stored in repos->[name]->'srcdirs')
# - initialises failed packs lists (empty)
#==========================================
sub Init
{
  my $this = shift;
  my $debug = shift || 0;

  # retrieve data from xml file:
  ## packages list (regular packages)
  $this->{m_kiwi}->info("KIWICollect::Init: querying instsource package list");
  %{$this->{m_repoPacks}}      = $this->{m_xml}->getInstSourcePackageList();
  # this list may be empty!
  $this->{m_kiwi}->info("KIWICollect::Init: queried package list.");
  if($this->{m_debug}) {
    $this->{m_kiwi}->info("See packages.dump.pl");
    open(DUMP, ">", "$this->{m_basedir}/packages.dump.pl");
    print DUMP Dumper($this->{m_repoPacks});
    close(DUMP);
  }

  ## architectures information (hash with name|desrc|next, next may be 0 which means "no fallback")
  # this element is mandatory. Empty = Error
  $this->{m_kiwi}->info("KIWICollect::Init: querying instsource architecture list");
  $this->{m_archlist} = new KIWIArchList($this);
  my $archadd = $this->{m_archlist}->addArchs( { $this->{m_xml}->getInstSourceArchList() } );
  if(not defined($archadd)) {
    $this->{m_kiwi}->error("KIWICollect::Init: addArchs returned undef");
    $this->{m_kiwi}->info( Dumper($this->{m_xml}->getInstSourceArchList()));
    return undef;
  }
  else {
    $this->{m_kiwi}->info("KIWICollect::Init: queried archlist.");
    if($this->{m_debug}) {
      $this->{m_kiwi}->info("See archlist.dump.pl");
      open(DUMP, ">", "$this->{m_basedir}/archlist.dump.pl");
      print DUMP $this->{m_archlist}->dumpList();
      close(DUMP);
    }
  }

  #cleanup the wasted memory in KIWIXML:
  $this->{m_xml}->clearPackageAttributes();

  ## repository information
  # mandatory. Missing = Error
  %{$this->{m_repos}}	      = $this->{m_xml}->getInstSourceRepository();
  if(!$this->{m_repos}) {
    $this->{m_kiwi}->error("KIWICollect::Init: getInstSourceRepository returned empty hash");
    return undef;
  }
  else {
    $this->{m_kiwi}->info("KIWICollect::Init: retrieved repository list.");
    if($this->{m_debug}) {
      $this->{m_kiwi}->info("See repos.dump.pl");
      open(DUMP, ">", "$this->{m_basedir}/repos.dump.pl");
      print DUMP Dumper($this->{m_repos});
      close(DUMP);
    }
  }

  ## package list (metapackages with extra effort by scripts)
  # mandatory. Empty = Error
  %{$this->{m_metaPacks}}  = $this->{m_xml}->getInstSourceMetaPackageList();
  if(!$this->{m_metaPacks}) {
    $this->{m_kiwi}->error("KIWICollect::Init: getInstSourceMetaPackageList returned empty hash");
    return undef;
  }
  else {
    $this->{m_kiwi}->info("KIWICollect::Init: retrieved metapackage list.");
    if($this->{m_debug}) {
      $this->{m_kiwi}->info("See metaPacks.dump.pl");
      open(DUMP, ">", "$this->{m_basedir}/metaPacks.dump.pl");
      print DUMP Dumper($this->{m_metaPacks});
      close(DUMP);
    }
  }

  ## metafiles: different handling
  # may be omitted
  %{$this->{m_metafiles}}     = $this->{m_xml}->getInstSourceMetaFiles();
  if(!$this->{m_metaPacks}) {
    $this->{m_kiwi}->info("KIWICollect::Init: getInstSourceMetaPackageList returned empty hash, no metafiles specified.");
  }
  else {
    $this->{m_kiwi}->info("KIWICollect::Init: retrieved metafile list.");
    if($this->{m_debug}) {
      $this->{m_kiwi}->info("See metafiles.dump.pl");
      open(DUMP, ">", "$this->{m_basedir}/metafiles.dump.pl");
      print DUMP Dumper($this->{m_metafiles});
      close(DUMP);
    }
  }

  ## info about requirements for chroot env to run metadata scripts
  # may be empty
  @{$this->{m_chroot}}	      = $this->{m_xml}->getInstSourceChrootList();
  if(!$this->{m_chroot}) {
    $this->{m_kiwi}->info("KIWICollect::Init: chroot list is empty hash, no chroot requirements specified");
  }
  else {
    $this->{m_kiwi}->info("KIWICollect::Init: retrieved chroot list.");
    if($this->{m_debug}) {
      $this->{m_kiwi}->info("See chroot.dump.pl");
      open(DUMP, ">", "$this->{m_basedir}/chroot.dump.pl");
      print DUMP Dumper($this->{m_chroot});
      close(DUMP);
    }
  }

  my ($iadded, $vadded, $oadded);
  $iadded = $this->{m_proddata}->addSet("ProductInfo stuff", {$this->{m_xml}->getInstSourceProductInfo()}, "prodinfo");
  $vadded = $this->{m_proddata}->addSet("ProductVar stuff", {$this->{m_xml}->getInstSourceProductVar()}, "prodvars");
  $oadded = $this->{m_proddata}->addSet("ProductOption stuff", {$this->{m_xml}->getInstSourceProductOption()}, "prodopts");
  if(not defined($iadded) or not defined($vadded) or not defined($oadded)) {
    $this->{m_kiwi}->error("KIWICollect::Init: something wrong in the productoptions section"); 
    return undef;
  }
  $this->{m_proddata}->_expand(); #once should be it, now--

  if($this->{m_debug}) {
    open(DUMP, ">", "$this->{m_basedir}/productdata.pl");
    print DUMP "# PRODUCTINFO:";
    print DUMP Dumper($this->{m_proddata}->getSet('prodinfo'));
    print DUMP "# PRODUCTVARS:";
    print DUMP Dumper($this->{m_proddata}->getSet('prodvars'));
    print DUMP "# PRODUCTOPTIONS:";
    print DUMP Dumper($this->{m_proddata}->getSet('prodopts'));
    close(DUMP);
  }

  ## Set possible defined source or debugmediums
  #
  $this->{m_srcmedium}   = $this->{m_proddata}->getOpt("SOURCEMEDIUM");
  $this->{m_debugmedium} = $this->{m_proddata}->getOpt("DEBUGMEDIUM");

  $this->{m_united} = "$this->{m_basedir}/main";
  $this->{m_dirlist}->{"$this->{m_united}"} = 1;
  my $mediumname = $this->{m_proddata}->getVar("MEDIUM_NAME");
  if(not defined($mediumname)) {
    $this->{m_logger}->error("[E] Variable MEDIUM_NAME is not specified correctly!");
    return undef;
  }

  my @media = $this->getMediaNumbers();
  my $mult = $this->{m_proddata}->getVar("MULTIPLE_MEDIA");
  my $dirext = undef;
  if($mult eq "no") {
    if(scalar(@media) == 1) { 
      $dirext = 1;
    }
    else {
      # this means the config says multiple_media=no BUT defines a "medium=<number>" somewhere!
      $this->{m_logger}->warning("[W] You want a single medium distro but specified medium=... for some packages\n\tIgnoring the MULTIPLE_MEDIA=no flag!");
    }
  }
  my $descrdir = $this->{m_proddata}->getInfo("DESCRDIR");
  if(not defined($descrdir) or $descrdir =~ m{notset}i) {
    $this->{m_logger}->error("Variable DESCRDIR missing!");
    return undef;
  }
  my $datadir = $this->{m_proddata}->getInfo("DATADIR");
  if(not defined($datadir) or $datadir =~ m{notset}i) {
    $this->{m_logger}->error("Variable DATADIR missing!");
    return undef;
  }
  ### FIXME: remove later checks on those vars

  $descrdir =~ s{^/(.*)/$}{$1};
  my @descrdirs = split('/', $descrdir);
  foreach my $n(@media) {
    my $dirbase = "$this->{m_united}/$mediumname";
    $dirbase .= "$n" if not defined($dirext);
    $this->{m_dirlist}->{"$dirbase"} = 1;
    $this->{m_dirlist}->{"$dirbase/$datadir"} = 1;
    my $curdir = "$dirbase/";
    foreach my $part(@descrdirs) {
      $curdir .= "$part/";
      $this->{m_dirlist}->{"$curdir"} = 1;
    }
    my $num = $n;
    $num = 1 if ( $this->{m_proddata}->getInfo("FLAVOR") eq "ftp" );
    $this->{m_dirlist}->{"$dirbase/media.$num"} = 1;
    $this->{m_basesubdir}->{$n} = "$dirbase";
    $this->{m_dirlist}->{"$this->{m_basesubdir}->{$n}"} = 1;
  }
  
  # we also need a basesubdir "0" for the metapackages that shall _not_ be put to the CD.
  # Those specify medium number "0", which means we only need a dir to download scripts.
  $this->{m_basesubdir}->{'0'} = "$this->{m_united}/".$mediumname."0";
  $this->{m_dirlist}->{"$this->{m_united}/".$mediumname."0/temp"} = 1;
  
  my $dircreate = $this->createDirectoryStructure();
  if($dircreate != 0) {
    $this->{m_kiwi}->error("KIWICollect::Init: calling createDirectoryStructure failed");
    return undef;
  }

  # for debugging:
  if($this->{m_debug}) {
    $this->{m_kiwi}->info("Debug: dumping packages list to <packagelist.txt>");
    $this->dumpPackageList("$this->{m_basedir}/packagelist.txt");
  }

  $this->{m_kiwi}->info("KIWICollect::Init: create LWP module");
  $this->{m_browser} = new LWP::UserAgent;

  ## create the metadata handler and load (+verify) all available plugins:
  # the required variables are MEDIUM_NAME, PLUGIN_DIR, INI_DIR
  # should be set by now.
  $this->{m_kiwi}->info("KIWICollect::Init: create KIWIRepoMetaHandler module");
  $this->{m_metacreator} = new KIWIRepoMetaHandler($this);
  $this->{m_metacreator}->baseurl($this->{m_united});
  $this->{m_metacreator}->mediaName($this->{m_proddata}->getVar('MEDIUM_NAME'));
  $this->{m_logger}->info("[I] Loading plugins from <".$this->{m_proddata}->getOpt("PLUGIN_DIR").">");
  my ($loaded, $avail) = $this->{m_metacreator}->loadPlugins();
  if($loaded < $avail) {
    $this->{m_logger}->error("[E] could not load all plugins! <$loaded/$avail>!");
    return undef;
  }
  $this->{m_logger}->info("[I] Loaded <$loaded> plugins successfully.\n");

  ### object is set up so far; next step is the repository scan analysis (TODO: create an own method for that bit)

  ## second level initialisation done, now start work:
  if($this->{m_debug}) {
    $this->{m_logger}->info("");
    $this->{m_logger}->info("[I] STEP 0 (initialise) -- Examining repository structure" );
    $this->{m_logger}->info("[I] STEP 0.1 (initialise) -- Create local paths") if $this->{m_debug};
  }

  # create local directories as download targets. Normalising special chars (slash, dot, ...) by replacing with second param.
  foreach my $r(keys(%{$this->{m_repos}})) {
    #if($this->{m_repos}->{$r}->{'source'} =~ m{^obs:.*}) {
      $this->{m_logger}->info("[I] [Init] resolving URL $this->{m_repos}->{$r}->{'source'}...") if $this->{m_debug};
      $this->{m_repos}->{$r}->{'source'} = $this->{m_urlparser}->normalizePath($this->{m_repos}->{$r}->{'source'});
      $this->{m_logger}->info("[I] [Init] resolved URL: $this->{m_repos}->{$r}->{'source'}") if $this->{m_debug};
    #}
    $this->{m_repos}->{$r}->{'basedir'} = $this->{m_basedir}."/".$this->{m_util}->normaliseDirname($this->{m_repos}->{$r}->{'source'}, '-');

    $this->{m_dirlist}->{"$this->{m_repos}->{$r}->{'basedir'}"} = 1;

    $this->{m_logger}->info("[I] STEP 1.2 -- Expand path names for all repositories") if $this->{m_debug};
    $this->{m_repos}->{$r}->{'source'} =~ s{(.*)/$}{$1};  # strip off trailing slash in each repo (robust++)
    my @tmp;

    # splitPath scans the URLs for valid directories no matter if they are local/remote (currently http(s), file and obs://
    # are allowed. The list of directories is stored in the tmp list (param 1), the 4th param pattern determines the depth
    # for the scan.
    # TODO verify if a common interface with scanner/redirector code is possible!
    if(not defined($this->{m_util}->splitPath(\@tmp, $this->{m_browser}, $this->{m_repos}->{$r}->{'source'}, "/.*/.*/", 0))) {
      $this->{m_logger}->warning("[W] KIWICollect::new: KIWIUtil::splitPath returned undef!\n");
      $this->{m_logger}->warning("[W] \tparsing repository $r\n");
      $this->{m_logger}->warning("[W] \tusing source ".$this->{m_repos}->{$r}->{'source'}.": check repository structure!\n");
    }

    foreach my $dir(@tmp) {
      $dir = substr($dir, length($this->{m_repos}->{$r}->{'source'}));
      $dir = "$dir/";
    }

    my $tmp = @tmp;
    my %tmp = map { $_, undef } @tmp;
    if($tmp != 0) {
      $this->{m_repos}->{$r}->{'srcdirs'} = \%tmp;
    }
    else {
      $this->{m_repos}->{$r}->{'srcdirs'} = undef;
    }
  }
}
# /Init



#==========================================
# mainTask
#------------------------------------------
# After initialisation by the constructor the repositories
# have to be processed and a lot of things will have to be
# done. So this method will grow a lot doing all this by
# invoking specialised submethods
#------------------------------------------
# Parameters
# $this - reference to the object for which it is called
# nothing more - everything else must be handled through
# member data and accessible methods. No dirty tricks *please*
#------------------------------------------
sub mainTask
{
  my $this = shift;
  my $retval = undef;

  return $retval if not defined($this);

  my ($collectret, $initmphandlers, $metadatacreate);

  $collectret = $this->collectPackages();
  ## HACK: continue anyway, some are false positives
  #if($collectret != 0) {
  #  $this->{m_logger}->error("[E] collecting packages failed!");
  #  $retval = 1;
  #}

  #else {
    $this->createMetadata();
    

    ## Q&D HACK for Adrian: set KIWI_ISO to enable ISO creation
    if(!$ENV{'KIWI_ISO'}) {
      return;
    }

    ## HACK
    # create ISO using KIWIIsoLinux.pm
    eval "require KIWIIsoLinux";
    if($@) {
      $this->{m_logger}->warning("[W] Module KIWIIsoLinux not loadable: $@\n");
    }
    else {
      my $iso;
      foreach my $cd($this->getMediaNumbers()) {
	next if($cd == 0);
	my $cdname = $this->{m_basesubdir}->{$cd};
	$cdname =~ s{.*/(.*)/*$}{$1};
	$iso = new KIWIIsoLinux($this->{m_logger}, $this->{m_basesubdir}->{$cd}, $this->{m_united}."/$cdname.iso");
	if(!$iso->createSortFile()) {
	  $this->{m_logger}->error("[E] Cannot create sortfile");
	}
	else {
	  $this->{m_logger}->info("[I] Created sortfile");
	}
	if(!$iso->createISOLinuxConfig()) {
	  $this->{m_logger}->error("[E] Cannot create IsoLinuxConfig");
	}
	else {
	  $this->{m_logger}->info("[I] Created IsoLinux Config");
	}
	if(!$iso->createISO()) {
	  $this->{m_logger}->error("[E] Cannot create Iso image");
	}
	else {
	  $this->{m_logger}->info("[I] Created Iso image <$cdname.iso>");
	}
	if(!$iso->checkImage()) {
	  $this->{m_logger}->error("[E] Tagmedia call failed");
	}
	else {
	  $this->{m_logger}->info("[I] Tagmedia call successful");
	}
      }
    }
#      $metadatacreate = $this->{m_metacreator}->createMetadata();
#      # handle return value here
#    }
#    else {
#      $this->{m_logger}->error("[E] Initialisation of metadata handlers failed!");
#      $retval = 10;
#    }
  #}
  
  return $retval;
}
# /mainTask


#==========================================
# getPackagesList OBSOLETE REMOVE ME
#------------------------------------------
sub getPackagesList
{
  my $this = shift;
  my $type = shift;

  my $failed = 0;
  if(!@_) {
    $this->{m_logger}->error("[E] getPackagesList called with empty arguments!");
    return -1;
  }
  
  foreach my $pack(@_) {
    my $numfail = $this->fetchFileFrom($pack, $this->{m_repos}, $type);
    if( $numfail == 0) {
      $this->{m_logger}->warning("[W] Package $pack not found in any repository!");
      if($type =~ m{meta}) {
	push @{$this->{m_fmpacks}}, "$pack";
      }
      elsif($type =~ m{debug}) {
	push @{$this->{m_fdebugpacks}}, "$pack";
      }
      elsif($type =~ m{src}) {
	push @{$this->{m_fsrcpacks}}, "$pack";
      }
      else {
	push @{$this->{m_fpacks}}, "$pack";
      }
      $failed++;
    }
  }
  return $failed;
} # getPackagesList



#==========================================
# getMetafileList
#------------------------------------------
# returns:
#   0	= all ok
#   -1	= error in call
#   n>0	= n metafiles failed
#==========================================
sub getMetafileList
{
  my $this = shift;
  if(!%{$this->{m_basesubdir}} or ! -d $this->{m_basesubdir}->{'1'}) {
    $this->{m_logger}->warning("[W] getMetafileList called to early? basesubdir must be set!\n");
    return -1;
  }

  my $failed = 0;
  
  foreach my $mf(keys(%{$this->{m_metafiles}})) {
    my $t = $this->{m_metafiles}->{$mf}->{'target'} || "";
    $this->{m_xml}->getInstSourceFile($mf, "$this->{m_basesubdir}->{'1'}/$t"); # from, to
    my $fname;
    $mf =~ m{.*/([^/]+)$};
    $fname = $1;
    if(not defined $fname) {
      $this->{m_logger}->warning("[W] [getMetafileList] filename $mf doesn't match regexp, skipping\n");
      next;
    }
  }
  return $failed;
} # getMetafileList



#==========================================
# setupPackageFiles
#------------------------------------------
sub setupPackageFiles
{
  my $this = shift;
  my $mode = shift; # 1 = collect source & debug packnames; 2 = use only src/nosrc packs; 0 = nothing special
  my $usedPackages = shift;

  my $retval = 0;

  my $base_on_cd = $this->{m_proddata}->getInfo("DATADIR");
  if(not defined($base_on_cd)) {
    $this->{m_logger}->error("[E] setupPackageFile: variable DATADIR must be set!");
    return $retval;
  }

  if(!%{$usedPackages}) {
    # empty repopackages -> probably a mini-iso (metadata only) - nothing to do
    $this->{m_logger}->info("[I] Looks like no repopackages are required, assuming miniiso. Skipping setupPackageFile.\n");
    return $retval;
  }

  PACK:foreach my $packName(keys(%{$usedPackages})) {
    my $packOptions = $usedPackages->{$packName}; #input options from kiwi files
    my $poolPackages = $this->{m_packagePool}->{$packName}; #pointer to local package pool hash
    my $nofallback = 0;
    my @archs;
    if ( $mode eq 2 ) {
      push @archs, 'src', 'nosrc';
    }else{
      @archs = $this->getArchList($packOptions, $packName, \$nofallback);
    }
    $this->{m_logger}->info("[I] Evaluate package $packName for @archs\n") if $this->{m_debug} >= 4;

#    if ( $packOptions->{pointers} ) {
#      # A package has been found in former runs, do not evaluate, just take it
#      ELEMENTS:foreach my $p(@{$packOptions->{pointers}}) {
#      };
#      next PACK;
#    };

    ARCH:foreach my $requestedArch(@archs) {
      $this->{m_logger}->info("[I]   Evaluate package $packName for requested arch $requestedArch\n") if $this->{m_debug} >= 5;

      my @fallbacklist;
      if($nofallback==0 && $mode ne 2) {
	@fallbacklist = $this->{m_archlist}->fallbacks($requestedArch);
      }
      else {
	@fallbacklist = ($requestedArch);
      }
#      push @fallbacklist, $a; # if $a eq 'src' || $a eq 'nosrc';
      my $fb_available = 0;
      FA:foreach my $arch(@fallbacklist) {
        $this->{m_logger}->info("[I]     check architecture $arch \n") if $this->{m_debug} >= 5;
        PACKKEY:foreach my $packKey(keys(%{$poolPackages})) {
        # FIXME: check for forcerepo
          $this->{m_logger}->info("[I]     check $packKey \n") if $this->{m_debug} >= 5;

          my $packPointer = $poolPackages->{$packKey};
	  if ( $packPointer->{arch} ne $arch ) {
	    $this->{m_logger}->warning("[I]     => package $packName not available for arch $arch in repo $packKey") if $this->{m_debug} >= 4;
            next PACKKEY;
          }
          if($nofallback==0 && $mode ne 2) {
	    my $follow = $this->{m_archlist}->arch($arch)->follower();
	    if(defined($follow)) { 
	      $this->{m_logger}->warning("[I]     => falling back to $follow from $packKey instead") if $this->{m_debug} >= 3;
	    }
	  }
	  if ( $packOptions->{requireVersion}
               && $packOptions->{requireVersion}->{ $packPointer->{version}."-".$packPointer->{release} } )
          {
	    $this->{m_logger}->warning("[I]     => package ".$packName-$packPointer->{version}."-".$packPointer->{release}." not available for arch $arch in repo $packKey") if $this->{m_debug} >= 4;
            next PACKKEY;
          }else{
            # success, but remove key to avoid error message later
            delete( $packOptions->{requireVersion}->{$packPointer->{version}."-".$packPointer->{release}} );
          }

          # Success, found a package !
          my $medium = 1;
          $medium = $packOptions->{'medium'} if( $packOptions->{'medium'});
          
          $packOptions->{'newfile'}  = "$packName-$packPointer->{'version'}-$packPointer->{'release'}.$packPointer->{'arch'}.rpm";
          $packOptions->{'newpath'} = "$this->{m_basesubdir}->{$medium}/$base_on_cd/$packPointer->{'arch'}";
          $packOptions->{'arch'}  = $packPointer->{'arch'};
          # check for target directory:
          if(!$this->{m_dirlist}->{"$packOptions->{'newpath'}"}) {
            $this->{m_dirlist}->{"$packOptions->{'newpath'}"} = 1;
            $this->createDirectoryStructure();
          }
          # link it:
          if(!-e "$packOptions->{'newpath'}/$packOptions->{'newfile'}" and !link $packPointer->{'localfile'}, "$packOptions->{'newpath'}/$packOptions->{'newfile'}") {
            $this->{m_logger}->error("[E]   linking file $packPointer->{'localfile'} to $packOptions->{'newpath'}/$packOptions->{'newfile'} failed");
          } else {
            $this->{m_logger}->info("[I]   package $packName found for architecture $arch (fallback of $requestedArch) in repo ") if $this->{m_debug} >= 2;
            if ( $mode eq 1 && $packPointer->{sourcepackage} ) {
              my $srcname = $packPointer->{sourcepackage};
              $srcname =~ s/-[^-]*-[^-]*\.[^\.]*\.[^\.]*\.rpm$//; # this strips everything, except main name
              # 
              if ( $this->{m_srcmedium} && $this->{m_srcmedium} > 1 ) {
                if (!$this->{m_sourcePacks}->{$srcname}) {
                  # FIXME: add forcerepo here
                  $this->{m_sourcePacks}->{$srcname} = {
                    'medium' => $this->{m_srcmedium},
                    'onlyarch' => 'src,nosrc'
                  };
                }
                $this->{m_sourcePacks}->{$srcname}->{'requireVersion'} =>
                     { $packPointer->{'version'}."-".$packPointer->{'release'} => 1 };
              }
              if ( $this->{m_debugmedium} && $this->{m_debugmedium} > 1 ) {
                # Add debug packages, we do not know, if they exist at all
                # FIXME: this does not work for packages create by baselibs !
                if ( $this->{m_debugPacks}->{$srcname."-debuginfo"} ){
                  $this->{m_debugPacks}->{$srcname."-debuginfo"}->{'onlyarch'} .= ",$arch";
                  $this->{m_debugPacks}->{$srcname."-debugsource"}->{'onlyarch'} .= ",$arch";
                } else {
                  $this->{m_debugPacks}->{$srcname."-debuginfo"} = {
                    'medium' => $this->{m_debugmedium},
                    'onlyarch' => $arch
                  };
                  $this->{m_debugPacks}->{$srcname."-debugsource"} = {
                    'medium' => $this->{m_debugmedium},
                    'onlyarch' => $arch
                  };
                };
                $this->{m_debugPacks}->{$srcname."-debuginfo"}->{'requireVersion'} =>
                     { $packPointer->{'version'}."-".$packPointer->{'release'} => 1 };
                $this->{m_debugPacks}->{$srcname."-debugsource"}->{'requireVersion'} =>
                     { $packPointer->{'version'}."-".$packPointer->{'release'} => 1 };
              };
            }
          }
	  next PACKKEY if ( $packOptions->{requireVersion} );
	  next ARCH; # package processed, jump to the next request arch or package
	}
	$this->{m_logger}->warning("[I]     => package $packName not available for arch $arch in any repo") if $this->{m_debug} >= 3;
      } # /@fallbackarch
      $this->{m_logger}->warning("[W]     => package $packName not available for $requestedArch nor its fallbacks") if $this->{m_debug} >= 3;
    } # /@archs
  }
  return $retval;
}
# /setupPackageFile



#==========================================
# collectPackages
#------------------------------------------
# collect all required packages from any repo
# This method defines the central workflow.
# I'll try to keep this very brief and clear
# and put the 'real' work in tiny submethods
# which should be considered private and will
# therefore be called "_something"
#------------------------------------------
# Parameters
# $this - reference to the object for which it is called
#------------------------------------------
sub collectPackages
{
  my $this = shift;

  my $retval = undef;
  my $rfailed = 0;
  my $mfailed = 0;


  ### step 1
  # expand dir lists (setup in constructor for each repo) to filenames
  if($this->{m_debug}) {
    $this->{m_logger}->info("");
    $this->{m_logger}->info("[I] STEP 1 [collectPackages]" );
    $this->{m_logger}->info("[I] expand dir lists for all repositories");
  }
  foreach my $r(keys(%{$this->{m_repos}})) {
    my $tmp_ref = \%{$this->{m_repos}->{$r}->{'srcdirs'}};
    foreach my $dir(keys(%{$this->{m_repos}->{$r}->{'srcdirs'}})) {
      # directories are scanned during Init()
      # expandFilenames scans the already known directories for matching filenames, in this case: *.rpm, *.spm
      $tmp_ref->{$dir} = [ $this->{m_util}->expandFilename($this->{m_browser}, $this->{m_repos}->{$r}->{'source'}.$dir, '.*[.][rs]pm$') ];
    }
  }

  # dump files for debugging purposes:
  $this->dumpRepoData("$this->{m_basedir}/repolist.txt");

  # get informations about all available packages.
  my $result = $this->lookUpAllPackages();
  if( $result == -1) {
    $this->{m_logger}->error("[E] lookUpAllPackages failed !");
    die("[E] lookUpAllPackages failed !");
  }


  ### step 2:
  if($this->{m_debug}) {
    $this->{m_logger}->info("");
    $this->{m_logger}->info("[I] STEP 2 [collectPackages]" );
    $this->{m_logger}->info("[I] Query RPM archive headers for undecided archives");
  }

  # Setup the package FS layout
  my $setupFiles = $this->setupPackageFiles(1, $this->{m_repoPacks});
  if($setupFiles > 0) {
    $this->{m_logger}->error("[E] [collectPackages] $setupFiles RPM packages could not be setup");
    $retval++;
  }
  if ( $this->{m_srcmedium} && $this->{m_srcmedium} > 0 ) {
    $setupFiles = $this->setupPackageFiles(2, $this->{m_sourcePacks});
    if($setupFiles > 0) {
      $this->{m_logger}->error("[E] [collectPackages] $setupFiles SOURCE RPM packages could not be setup");
      $retval++;
    }
  }
  if ( $this->{m_debugmedium} && $this->{m_debugmedium} > 0 ) {
    $setupFiles = $this->setupPackageFiles(0, $this->{m_debugPacks});
    if($setupFiles > 0) {
      $this->{m_logger}->error("[E] [collectPackages] $setupFiles DEBUG RPM packages could not be setup");
      $retval++;
    }
  }

  ### step 3: NOW I know where you live...
  if($this->{m_debug}) {
    $this->{m_logger}->info("");
    $this->{m_logger}->info("[I] STEP 3 [collectPackages]" );
    $this->{m_logger}->info("[I] Handle scripts for metafiles and metapackages");
  }
  # unpack metapackages and download metafiles to the {m_united} path
  # (or relative path from there if specified) <- according to rnc file
  # this must not be empty in any case

  # download metafiles to new basedir:
  $this->getMetafileList();

  $this->{m_scriptbase} = "$this->{m_united}/scripts";
  if(!mkpath($this->{m_scriptbase}, { mode => umask } )) {
    $this->{m_logger}->error("[E] [collectPackages] Cannot create script directory!");
    die;  # TODO clean exit somehow
  }

  my @metafiles = keys(%{$this->{m_metafiles}});
  if(!$this->executeMetafileScripts(@metafiles)) {
    $this->{m_logger}->error("[E] [collectPackages] executing metafile scripts failed!");
    $retval++;
  }

  # create some dirs needed for metapackage handling:
  #my @mfsubdirs;
  #for(1..5) {
  #  push @mfsubdirs, "$this->{m_united}/CD$_";
  #  mkdir("$this->{m_united}/CD$_", 0755);
  #}
  #@{$this->{m_metasubdirs}} = @mfsubdirs;


  my @packagelist = sort(keys(%{$this->{m_metaPacks}}));
  if(!$this->unpackMetapackages(@packagelist)) {
    $this->{m_logger}->error("[E] [collectPackages] executing scripts failed!");
    $retval++;
  }


  ### step 4: run scripts for other (non-meta) packages
  # TODO (copy/paste?)
  
  return $retval;
}
# /collectPackages



#==========================================
# executeMetapackageScripts
#------------------------------------------
# metafiles and metapackages may have an attribute called 'script'
# which shall be executed after the packages are gathered.
# TODO: find a way to secure this
#   ISSUES:
# I'd very much like to setup a chroot environment for that, but then
# all binaries that will be used need to be copied/linked beneath the
# new root.
# - metaPACKAGES _could_ define dependencies through RPM's
#   REQUIRES mecahnism. Lars is working on that so this will come soon.
# - different for metaFILES because they are loose and don't have any
#   install mechanism yet. We think about this.
#==========================================
sub unpackMetapackages
{
  my $this = shift;

  # the second (first explicit) parameter is a list of packages
  my @packlist = @_;

  my $retval = 0;

  foreach my $metapack(@packlist) {
    my %packOptions = %{$this->{m_metaPacks}->{$metapack}};
    my $poolPackages = $this->{m_packagePool}->{$metapack};

    my $nofallback;
    my $medium = 1;
    my $nokeep = 0;
    if(defined($packOptions{'medium'})) {
      #$medium = $tmp{'medium'};
      if($packOptions{'medium'} == 0) {
	$nokeep = 1;
      }
      else {
	$medium = $packOptions{'medium'};
      }
    }

    ## regular handling: unpack, put everything from CD1..CD<n> to cdroot {m_basedir}
    # ...
    my $tmp = "$this->{m_basesubdir}->{$medium}/temp";
    if(-d $tmp) {
      qx(rm -rf $tmp);
    }
    if(!mkpath("$tmp", { mode => umask } )) {
      $this->{m_logger}->error("[E] can't create dir <$tmp>\n");
      return $retval;;
    }

    ARCH:foreach my $arch($this->getArchList($this->{m_metaPacks}, $metapack, \$nofallback)) {
      next if($arch =~ m{(src|nosrc)});
      PACKKEY:foreach my $packKey(keys(%{$poolPackages})) {
        my $packPointer = $poolPackages->{$packKey};
        next PACKKEY if(!$packPointer->{'localfile'}); # should not be needed
        next PACKKEY if($packPointer->{arch} ne $arch);

        $this->{m_logger}->info("[I] unpack $packPointer->{'localfile'} \n");
        $this->{m_util}->unpac_package($packPointer->{'localfile'}, "$tmp");
        ## all metapackages contain at least a CD1 dir and _may_ contain another /usr/share/<name> dir
        if ( -d "$tmp/CD1") {
          qx(cp -r $tmp/CD1/* $this->{m_basesubdir}->{$medium}) if ( -d "$tmp/CD1")
        }else{
          $this->{m_logger}->info("[I] No CD1 directory on $packPointer->{name} \n");
        }
        for my $sub("usr", "etc") {
          if(-d "$tmp/$sub") {
            qx(cp -r $tmp/$sub $this->{m_basesubdir}->{$medium});
          }
        }
        ## copy content of CD2 ... CD<i> subdirs if exists:
        for(2..10) {
          if(-d "$tmp/CD$_" and defined $this->{m_basesubdir}->{$_}) {
            qx(cp -r $tmp/CD$_/* $this->{m_basesubdir}->{$_});
            $this->{m_logger}->info("[I] Unpack CD$_ for $packPointer->{name} \n");
          }
          ## add handling for "DVD<i>" subdirs if necessary FIXME
        }

        ## THEMING
        $this->{m_logger}->info("[I] Handling theming for package $metapack\n") if $this->{m_debug};
        my $thema = $this->{m_proddata}->getVar("PRODUCT_THEME");
        if(not defined($thema)) {
          $this->{m_logger}->error("[E] unpackMetapackages: PRODUCT_THEME undefined!");
          die;# TODO clean solution
        }
        $this->{m_logger}->info("\ttarget theme $thema\n");

        if(-d "$tmp/SuSE") {
          if(not opendir(TD, "$tmp/SuSE")) {
            $this->{m_logger}->warning("[W] [unpackMetapackages] Can't open theme directory for reading!\nSkipping themes for package $metapack\n");
            next;
          }
          my @themes = readdir(TD);
          closedir(TD);
          my $found=0;
          foreach my $d(@themes) {
            if($d =~ m{$thema}i) {
              $this->{m_logger}->info("[I] Using thema $d\n");
              $thema = $d;	# changed after I saw that yast2-slideshow has a thema "SuSE-SLES" (matches "SuSE", but not in line 831)
              $found=1;
              last;
            }
          }
          if($found==0) {
            foreach my $d(@themes) {
              if($d =~ m{linux|sles|suse}i) {
                $this->{m_logger}->info("[I] Using fallback theme $d instead of $thema\n");
                $thema = $d;
                last;
              }
            }
          }
          ## $thema is now the thema to use:
          for my $i(1..3) {
            ## @lars: wtf soll denn sein, wenn es CD2 gibt, aber die Konfig der Medien kein Medium "2" hat?
            ## Laut Rudi (tm) ist das zulässig!
            if(-d "$tmp/SuSE/$thema/CD$i" and $this->{m_basesubdir}->{$i} and -d "$tmp/SuSE/$thema/CD$i") {
              qx(cp -a $tmp/SuSE/$thema/CD$i/* $this->{m_basesubdir}->{$i});
            }
          }
        }

        ## handling optional special scripts if given (``anchor of the last choice'')
        if($packOptions{'script'}) {
          my $scriptfile;
          $packOptions{'script'} =~ m{.*/([^/]+)$};
          if(defined($1)) {
            $scriptfile = $1;
          }
          else {
            $this->{m_logger}->warning("[W] [executeScripts] malformed script name: $packOptions{'script'}");
            next;
          }

          print "Downloading script $packOptions{'script'} to $this->{m_scriptbase}:";
          $this->{m_xml}->getInstSourceFile($packOptions{'script'}, "$this->{m_scriptbase}/$scriptfile");

          # TODO I don't like this. Not at all. use chroot in next version!
          qx(chmod u+x "$this->{m_scriptbase}/$scriptfile");
          $this->{m_logger}->info("[I] [executeScripts] Execute script $this->{m_scriptbase}/$scriptfile:\n");
          if(-f "$this->{m_scriptbase}/$scriptfile" and -x "$this->{m_scriptbase}/$scriptfile") {
            my $status = qx($this->{m_scriptbase}/$scriptfile);
            my $retcode = $? >> 8;
            print "STATUS:\n$status\n";
            print "RETURNED:\n$retcode\n";
          }
          else {
            $this->{m_logger}->warning("[W] [executeScripts] script ".$this->{m_scriptbase}."/$scriptfile for metapackage $metapack could not be executed successfully!\n");
          }
        }
        else {
          $this->{m_logger}->info("[I] No script defined for metapackage $metapack\n");
        }

        if($nokeep == 1) {
          foreach my $d(keys(%{$this->{m_repoPacks}->{$metapack}})) {
            next if($d =~ m{(arch|addarch|removearch|onlyarch|source|script|medium)});
            if(defined($this->{m_repoPacks}->{$metapack}->{$d}->{'newpath'}) and defined($this->{m_repoPacks}->{$metapack}->{$d}->{'newfile'})) {
              unlink("$this->{m_repoPacks}->{$metapack}->{$d}->{'newpath'}/$this->{m_packages}->{$metapack}->{$d}->{'newfile'}");
            }
            else {
              $this->{m_logger}->warning("[W] Undefined values in hash for package $metapack");
              #$this->{m_logger}->warning( Dumper($this->{$metapack}));
            }
          }
        }
        # success, found package for arch
        next ARCH;
      }
      # we should not reach this ...
      $this->{m_logger}->warning("[W] Metapackage <$metapack> not available for architecure <$arch>!");
    }
  }

  ## cleanup old files:
  foreach my $index($this->getMediaNumbers()) {
    if(-d "$this->{m_basesubdir}->{$index}/temp") {
      qx(rm -rf $this->{m_basesubdir}->{$index}/temp);
    }
    if(-d "$this->{m_basesubdir}->{$index}/script") {
      qx(rm -rf $this->{m_basesubdir}->{$index}/script);
    }
  }
  return $retval;
}
# /executeScripts



#==========================================
# executeMetafileScripts
#------------------------------------------
sub executeMetafileScripts
{
  my $this = shift;

  # the second (first explicit) parameter is a list of either packages or files
  # for which scripts shall be executed.
  my @filelist = @_;

  foreach my $metafile(@filelist) {
    my %tmp = %{$this->{m_metafiles}->{$metafile}};
    if($tmp{'script'}) {
      my $scriptfile;
      ## TODO doesn't work for local files! (no bla/script.x) (abs paths required?)
      $tmp{'script'} =~ m{.*/([^/]+)$};
      if(defined($1)) {
	$scriptfile = $1;
      }
      else {
	$this->{m_logger}->warning("[W] [executeScripts] malformed script name: $tmp{'script'}\n");
	next;
      }

      print "Downloading script $tmp{'script'} to $this->{m_scriptbase}:";
      $this->{m_xml}->getInstSourceFile($tmp{'script'}, "$this->{m_scriptbase}/$scriptfile");

      # TODO I don't like this. Not at all. use chroot in next version!
      qx(chmod u+x "$this->{m_scriptbase}/$scriptfile");
      $this->{m_logger}->info("[I] [executeScripts] Execute script $this->{m_scriptbase}/$scriptfile:");
      if(-f "$this->{m_scriptbase}/$scriptfile" and -x "$this->{m_scriptbase}/$scriptfile") {
	my $status = qx($this->{m_scriptbase}/$scriptfile);
	my $retcode = $? >> 8;
	print "STATUS:\n$status\n";
	print "RETURNED:\n$retcode\n";
      }
      else {
	$this->{m_logger}->warning("[W] [executeScripts] script $this->{m_scriptbase}/$scriptfile for metafile $metafile could not be executed successfully!\n");
      }
    }
    else {
      $this->{m_logger}->info("[I] No script defined for metafile $metafile\n");
      
    }
  }
}
# /executeScripts




#==========================================
# lookUpAllPackages
#------------------------------------------
# checks all packages for their content.
# this requires that they are local !
#------------------------------------------
# Parameters
# ==========
# $this:
#   reference to the object for which it is called
#------------------------------------------
# Returns the number of resolved files, or 0 for bad list
#------------------------------------------
sub lookUpAllPackages
{
  my $this = shift;

  my $retval = 0;

  my $packPool = {};

  REPO:foreach my $r(keys(%{$this->{m_repos}})) { # FIXME priority !
    DIR:foreach my $d(keys(%{$this->{m_repos}->{$r}->{'srcdirs'}})) {
      next DIR if(! $this->{m_repos}->{$r}->{'srcdirs'}->{$d}->[0]);

      URI:foreach my $uri(@{$this->{m_repos}->{$r}->{'srcdirs'}->{$d}}) {
        next URI  unless( $uri =~ /\.rpm$/); # skip all files without rpm suffix
	$this->{m_logger}->info("read package: $uri ") if $this->{m_debug} >= 3;

        my %flags = RPMQ::rpmq_many("$uri", 'NAME', 'VERSION', 'RELEASE', 'ARCH', 'SOURCE', 'SOURCERPM', 'NOSOURCE', 'NOPATCH');
        if(! %flags || !$flags{'NAME'} || !$flags{'NAME'}[0] || !$flags{'VERSION'}[0] || !$flags{'RELEASE'}[0] ) {
  	  $this->{m_logger}->warning("[W] [lookUpAllPakcges] Package $uri seems to have an invalid header or is no rpm at all!");
        }
        else {
          my $arch;
          my $name = $flags{'NAME'}[0];

          if( !$flags{'SOURCERPM'} ) {
            # we deal with a source rpm...
            my $srcarch = 'src';
            $srcarch = 'nosrc' if $flags{'NOSOURCE'} || $flags{'NOPATCH'};
            $arch = $srcarch;
          } else {
            $arch = $flags{'ARCH'}->[0];
          }

          # all data gets assigned, which is needed for setting the directory structure up.
          my $package;
          $package->{'arch'} = $arch;
          $package->{'localfile'} = $uri;
          $package->{'version'} = $flags{'VERSION'}[0];
          $package->{'release'} = $flags{'RELEASE'}[0];

          # We can have a package only once per architecture and in one repo
          my $repokey = $r."@".$arch;
          # BUT src, nosrc and debug packages need to be available in all versions.
          if ( !$flags{'SOURCERPM'} || $name =~ /-debugsource$/ || $name =~ /-debuginfo$/ ) {
            $repokey .= "@".$package->{'version'}."@".$package->{'release'};
          }
          next if( $packPool->{$name}->{$repokey} ); # we have it already from a more important repo.

          # collect data for connected source rpm
          if( $flags{'SOURCERPM'} ) {
            # collect source rpms
            my $srcname = $flags{'SOURCERPM'}[0];
            $package->{'sourcepackage'} = $srcname if ($srcname);
          }
          # store the result.
          my $store;
          if($packPool->{$name}) {
            $store = $packPool->{$name};
          }
          else {
            $store = {};
            $packPool->{$name} = $store;
          }
          $store->{$repokey} = $package;
          $retval++;
        } # read RPM header
      } # foreach URI
    } # foreach DIR
  } # foreach REPO

  # set result
  $this->{m_packagePool} = $packPool;
  return $retval;
}
# /lookUpAllPackages



#==========================================
# dumpRepoData
#------------------------------------------
sub dumpRepoData
{
  # dumps data collected in $this-> ... for debugging purpose.
  # receives a file name as parameter.
  # If file can't be openend, a warning is issued through $this->{m_kiwi}
  # and nothing else happens.
  # Successful completion provides a list of content in the file.
  my $this    = shift;
  my $target  = shift;

  if(!open(DUMP, ">", $target)) {
    $this->{m_logger}->warning("[W] [dumpRepoData] Dumping data to file $target failed: file could not be created!");
    $this->{m_logger}->failed();
  }
  else {
    print DUMP "Dumped data from KIWICollect object\n\n";

    print DUMP "\n\nKNOWN REPOSITORIES:\n";
    foreach my $repo(keys(%{$this->{m_repos}})) {
      print DUMP "\nNAME:\t\"$repo\"\t[HASHREF]\n";
      print DUMP "\tBASEDIR:\t\"$this->{m_repos}->{$repo}->{'basedir'}\"\n";
      print DUMP "\tPRIORITY:\t\"$this->{m_repos}->{$repo}->{'priority'}\"\n";
      print DUMP "\tSOURCEDIR:\t\"$this->{m_repos}->{$repo}->{'source'}\"\n";
      print DUMP "\tSUBDIRECTORIES:\n";
      foreach my $srcdir(keys(%{$this->{m_repos}->{$repo}->{'srcdirs'}})) {
	print DUMP "\t\"$srcdir\"\t[URI LIST]\n";
	foreach my $file(@{$this->{m_repos}->{$repo}->{'srcdirs'}->{$srcdir}}) {
	  print DUMP "\t\t\"$file\"\n";
	}
      }
    }
    close(DUMP);
  }
  return 0;
}
# /dumpRepoData



#==========================================
# dumpPackageList
#------------------------------------------
sub dumpPackageList
{
  # dumps data collected in $this->{m_repoPacks} for debugging purpose.
  # receives a file name as parameter.
  # If file can't be openend, a warning is issued through $this->{m_kiwi}
  # and nothing else happens.
  # Successful completion provides a list of content in the file.
  my $this    = shift;
  my $target  = shift;

  if(!open(DUMP, ">", $target)) {
    $this->{m_logger}->warning("[W] [dumpPackageList] Dumping data to file $target failed: file could not be created!");
    $this->{m_kiwi}->failed();
  }

  print DUMP "Dumped data from KIWICollect object\n\n";

  print DUMP "LIST OF REQUIRED PACKAGES:\n\n";
  if(!%{$this->{m_repoPacks}}) {
    $this->{m_logger}->info("[I] Empty packages list\n");
    return;
  }
  foreach my $pack(keys(%{$this->{m_repoPacks}})) {
    print DUMP "$pack";
    if(defined($this->{m_repoPacks}->{$pack}->{'priority'})) {
      print DUMP "\t (prio=$this->{m_repoPacks}->{$pack}->{'priority'})\n";
    }
    else {
      print DUMP "\n";
    }
  }
  close(DUMP);
  return;
}
# /dumpData



sub getArchList
{
  my $this = shift;
  my $packOptions = shift;
  my $packName = shift;
  my $nofallbackref = shift;

  my @archs = ();
  my $ret = 0;
  
  return $ret if(not defined($packName));

  my @omits = ();
  if(defined($packOptions->{'arch'})) {
    # Check if this is a rule for this platform
    $packOptions->{'arch'} =~ s{,\s*,}{,}g;
    $packOptions->{'arch'} =~ s{,\s*}{,}g;
    $packOptions->{'arch'} =~ s{,\s*$}{};
    $packOptions->{'arch'} =~ s{^\s*,}{};
    my $found = 0;
    foreach my $plattform (split(/,\s*/, $packOptions->{'arch'})) {
      foreach my $reqArch ($this->{m_archlist}->headList()) {
        $found = 1 if ( $reqArch eq $plattform );
      };
    };
    if ( "$found" eq "0" ) {
      # not our plattform
      return $ret;
    }
  }

  if(defined($packOptions->{'onlyarch'})) {
    # allow 'onlyarch="x86_64,i586"'
    $packOptions->{'onlyarch'} =~ s{,\s*,}{,}g;
    $packOptions->{'onlyarch'} =~ s{,\s*}{,}g;
    $packOptions->{'onlyarch'} =~ s{,\s*$}{};
    $packOptions->{'onlyarch'} =~ s{^\s*,}{};
    push @archs, split(/,\s*/, $packOptions->{'onlyarch'});
    $$nofallbackref = 1;

    # onlyarch superceeds the following options !
    return @archs;
  }

  # set required archs
  push @archs, $this->{m_archlist}->headList();

  if(defined($packOptions->{'addarch'})) {
    if(not(grep(/$packOptions->{'addarch'}/, @archs))) {
      $packOptions->{'addarch'} =~ s{,\s*,}{,}g;
      $packOptions->{'addarch'} =~ s{,\s*}{,}g;
      $packOptions->{'addarch'} =~ s{,\s*$}{};
      $packOptions->{'addarch'} =~ s{^\s*,}{};
      push @archs, split(/,\s*/, $packOptions->{'addarch'});
    }
  }

  if(defined($packOptions->{'removearch'})) {
    $packOptions->{'removearch'} =~ s{,\s*,}{,}g;
    $packOptions->{'removearch'} =~ s{,\s*}{,}g;
    $packOptions->{'removearch'} =~ s{,\s*$}{};
    $packOptions->{'removearch'} =~ s{^\s*,}{};
    @omits = split(/,\s*/, $packOptions->{'removearch'});
    my @rl;
    foreach my $x(@omits) {
      push @rl, grep(/$x/, @archs);
    }
    if(@rl) {
      my %h = map { $_ => 1 } @archs;
      my @cleared = grep delete($h{$_}), @rl;
      @archs = ();
      @archs = keys(%h);
    }
  }
  
  return @archs;
}


sub failedPackagesWarning
{
  my $this = shift;
  my $call = shift;
  my $numf = shift;
  my $flist = shift;

  goto all_ok if($numf == 0);

  $this->{m_logger}->warning("[W] $call: $numf packages not found");
  foreach my $pack(@{$flist}) {
    $this->{m_logger}->error("[E] [collectPackages]\t$pack\n");
  }

  all_ok:
  return;
}



#==========================================
# createMetadata
#------------------------------------------
# 
#------------------------------------------
# params:
#------------------------------------------
sub createMetadata
{
  my $this = shift;

  my %plugins = $this->{m_metacreator}->getPluginList(); # retrieve a complete list of all loaded plugins

  # create required directories if necessary:
  foreach my $i(keys(%plugins)) {
    my $p = $plugins{$i};
    $this->{m_logger}->info("[I] Processing plugin ".$p->name()."\n");
    my @requireddirs = $p->requiredDirs();
    # this may be a list and each entry may look like "/foo/bar/baz/" in the worst case.
    foreach my $dir(@requireddirs) {
      $dir =~ s{^/(.*)/$}{$1}; # just to be on the safe side: split leading and trailing slashes
      my @sublist = split('/', $dir);
      my $curdir = $this->{m_basesubdir}->{1};
      foreach my $part_dir(@sublist) {
	$curdir .= "/$part_dir";
	$this->{m_dirlist}->{"$curdir"} = 1;
      }
    }
  }
  # that should be all, bit by bit and in order ;)
  $this->createDirectoryStructure();
  #$this->{m_logger}->info("[I] Enabling all plugins...\n");
  #$this->{m_metacreator}->enableAllPlugins();

  $this->{m_logger}->info("[I] Executing all plugins...\n");
  $this->{m_metacreator}->createMetadata();
  # creates the patters file. Rest will follow later

### ALTLASTEN ###
### TODO more plugins

# moved to beginnig after diffing with autobuild:
  ## STEP 11: ChangeLog file
  $this->{m_logger}->info("[I] Running mk_changelog for base directory");
  my $mk_cl = "/usr/bin/mk_changelog";
  if(! (-f $mk_cl or -x $mk_cl)) {
    $this->{m_logger}->warning("[W] [createMetadata] excutable `$mk_cl` not found. Maybe package `inst-source-utils` is not installed?");
    return;
  }
  my @data = qx($mk_cl $this->{m_basesubdir}->{'1'});
  my $res = $? >> 8;
  if($res == 0) {
    $this->{m_logger}->info("[I] $mk_cl finished successfully.");
  }
  else {
    $this->{m_logger}->warning("[W] $mk_cl finished with errors: returncode was $res");
  }
  $this->{m_logger}->info("[I] [createMetadata] $mk_cl output:\n");
  foreach(@data) {
    chomp $_;
    $this->{m_logger}->info("\t$_\n");
  }
  @data = (); # clear list



  ## step 5: media file
  $this->{m_logger}->info("[I] Creating media file in all media:");
  my $manufacturer = $this->{m_proddata}->getVar("VENDOR");
  if($manufacturer) {
    my @media = $this->getMediaNumbers();
    for my $n(@media) {
      my $num = $n;
      $num = 1 if ( $this->{m_proddata}->getInfo("FLAVOR") eq "ftp" );
      my $mediafile = "$this->{m_basesubdir}->{$n}/media.$num/media";
      if(not open(MEDIA, ">", $mediafile)) {
	$this->{m_logger}->error("[E] Cannot create file <$mediafile>");
	return undef;
      }
      print MEDIA "$manufacturer\n";
      print MEDIA qx(date +%Y%m%d%H%M%S);
      if($num == 1) {
	# some specialities for medium number 1: contains a line with the number of media (? ask ma!)
	print MEDIA $num."\n";
      }
      close(MEDIA);
      ## Q&D patch: create build file:
      my $bfile = "$this->{m_basesubdir}->{$n}/media.$num/build";
      if(not open(BUILD, ">", $bfile)) {
	$this->{m_logger}->error("[E] Cannot create file <$bfile>!");
	return undef;
      }
      print BUILD $this->{m_proddata}->getVar("BUILD_ID")."\n";
      close(BUILD);
    }
  }
  else { 
    $this->{m_logger}->error("[E] [createMetadata] required variable \"VENDOR\" not set");
    $this->{m_logger}->info("[I] [createMetadata] skipping media file due to error!");
  }

  ## step 5b: create info.txt for Beta releases.
  $this->{m_logger}->info("[I] Handling Beta information on media:");
  my $beta_version = $this->{m_proddata}->getOpt("BETA_VERSION");
  if (defined($beta_version)) {
    my $dist_string = $this->{m_proddata}->getVar("DISTNAME")." ".$this->{m_proddata}->getVar("PRODUCT_VERSION")." ".${beta_version};
    if (system("sed","-i","s/BETA_DIST_VERSION/$dist_string/","$this->{m_basesubdir}->{'1'}/README.BETA") == 0 ) {
      if (system("ln", "-sf", "../README.BETA", "$this->{m_basesubdir}->{'1'}/media.1/info.txt") != 0 ) {
        $this->{m_logger}->info("[E] Failed to symlink README.BETA file!");
      };
    }else{
      $this->{m_logger}->info("[E] Failed to replace beta version in README.BETA file!");
    };
  }else{
    if (system("rm", "-f", "$this->{m_basesubdir}->{'1'}/README.BETA") != 0 ) {
      $this->{m_logger}->info("[E] Failed to remove README.BETA file!");
    };
  };

  ## step 6: products file
  $this->{m_logger}->info("[I] Creating products file in all media:");
  my $proddir  = $this->{m_proddata}->getVar("PRODUCT_DIR");
  my $prodname = $this->{m_proddata}->getVar("PRODUCT_NAME");
  my $summary = $this->{m_proddata}->getInfo("SUMMARY");
  my $sp_ver = $this->{m_proddata}->getVar("SP_VERSION");
  my $prodver  = $this->{m_proddata}->getVar("PRODUCT_VERSION");
  my $prodrel  = $this->{m_proddata}->getVar("RELEASE");
  $prodname =~ s/\ /-/g;
  $prodver .= ".$sp_ver" if defined($sp_ver);
  if(defined($proddir) and defined($prodname) and defined($prodver) and defined($summary)) {
    $summary =~ s{\s+}{-}g; # replace space(s) by a single dash
    for my $n($this->getMediaNumbers()) {
      my $num = $n;
      $num = 1 if ( $this->{m_proddata}->getInfo("FLAVOR") eq "ftp" );
      my $productsfile = "$this->{m_basesubdir}->{$n}/media.$num/products";
      if(not open(PRODUCT, ">", $productsfile)) {
	die "Cannot create $productsfile";
      }
      print PRODUCT "$proddir $summary $prodver-$prodrel\n";
      close(PRODUCT);
    }
  }
  else {
    $this->{m_logger}->error("[E] [createMetadata] one or more of the following  variables are missing:");
    $this->{m_logger}->error("\tPRODUCT_DIR");
    $this->{m_logger}->error("\tPRODUCT_NAME");
    $this->{m_logger}->error("\tPRODUCT_VERSION");
    $this->{m_logger}->error("\tSUMMARY");
    $this->{m_logger}->info("[I] [createMetadata] skipping products file due to missing vars!");
  }

  $this->createBootPackageLinks();

  ## step 9: LISTINGS
  $this->{m_logger}->info("[I] Calling mk_listings:");
  my $listings = "/usr/bin/mk_listings";
  if(! (-f $listings or -x $listings)) {
    $this->{m_logger}->warning("[W] [createMetadata] excutable `$listings` not found. Maybe package `inst-source-utils` is not installed?");
    return;
  }
  my $cmd = "$listings ".$this->{m_basesubdir}->{'1'};
  @data = qx($cmd);
  undef $cmd;
  $this->{m_logger}->info("[I] [createMetadata] $listings output:\n");
  foreach(@data) {
    chomp $_;
    $this->{m_logger}->info("\t$_\n");
  }
  @data = (); # clear list



  ## step 7: SHA1SUMS
  $this->{m_logger}->info("[I] Calling create_sha1sums:");
  my $csha1sum = "/usr/bin/create_sha1sums";
  my $s1sum_opts = $this->{m_proddata}->getVar("SHA1OPT");
  if(not defined($s1sum_opts)) {
    $s1sum_opts = "";
  }
  if(! (-f $csha1sum or -x $csha1sum)) {
    $this->{m_logger}->warning("[W] [createMetadata] excutable `$csha1sum` not found. Maybe package `inst-source-utils` is not installed?");
    return;
  }
  for my $sd($this->getMediaNumbers()) {
    my @data = qx($csha1sum $s1sum_opts $this->{m_basesubdir}->{$sd});
    $this->{m_logger}->info("[I] [createMetadata] $csha1sum output:\n");
    foreach(@data) {
      chomp $_;
      $this->{m_logger}->info("\t$_\n");
    }
  }


  ### step 8: MD5SUMS
  #$this->{m_logger}->info("[I] Calling create_md5sums:");
  #my $md5sums = "/usr/bin/create_md5sums";
  #my $md5opt = $this->{m_proddata}->getVar("MD5OPT");
  ## available option: '--meta'
  #if(not defined($md5opt)) {
  #  $md5opt = "";
  #}
  #if(! (-f $md5sums or -x $md5sums)) {
  #  $this->{m_logger}->warning("[W] [createMetadata] excutable `$md5sums` not found. Maybe package `inst-source-utils` is not installed?");
  #  return;
  #}
  #my $cmd = "$md5sums $md5opt ";
  #$cmd .= $this->{m_basesubdir}->{1}."/".$this->{m_proddata}->getInfo("DATADIR");
  #my @data = qx($cmd);
  #undef $cmd;
  #$this->{m_logger}->info("[I] [createMetadata] $md5sums output:\n");
  #foreach(@data) {
  #  chomp $_;
  #  $this->{m_logger}->info("\t$_\n");
  #}
  #@data = (); # clear list


  ## step 10: DIRECTORY.YAST FILES
  $this->{m_logger}->info("[I] Calling create_directory.yast:");
  my $dy = "/usr/bin/create_directory.yast";
  if(! (-f $dy or -x $dy)) {
    $this->{m_logger}->warning("[W] [createMetadata] excutable `$dy` not found. Maybe package `inst-source-utils` is not installed?");
    return;
  }

  my $datadir = $this->{m_proddata}->getInfo("DATADIR");
  my $descrdir = $this->{m_proddata}->getInfo("DESCRDIR");
  if(not defined($datadir) or not defined($descrdir)) {
    $this->{m_logger}->error("[E] variables DATADIR and/or DESCRDIR are missing");
    die "MISSING VARIABLES!";
  }

  foreach my $d($this->getMediaNumbers()) {
    my $dbase = $this->{m_basesubdir}->{$d};
    #my $dbase = $ENV{'PWD'}.$this->{m_basesubdir}->{$d};
    my @dlist;
    push @dlist, "$dbase";
    # boot may be nonexistent if no metapack creates it
    if(-d "$dbase/boot") {
      push @dlist, "$dbase/boot" ;
      push @dlist, glob("$dbase/boot/*");
      push @dlist, glob("$dbase/boot/*/loader");
    }
    push @dlist, "$dbase/media.1";
    push @dlist, "$dbase/media.1/license";
    push @dlist, "$dbase/images";
    push @dlist, "$dbase/$datadir/setup/slide";
    push @dlist, "$dbase/$descrdir";

    foreach (@dlist) {
      if(-d $_) {
	@data = qx($dy $_);
	$this->{m_logger}->info("[I] [createMetadata] $dy output for directory $_:\n");
	foreach(@data) {
	  chomp $_;
	  $this->{m_logger}->info("\t$_\n");
	}
      }
    }
  }
}
# createMetadata



# returns the number of links created
sub createBootPackageLinks
{
  my $this = shift;
  return undef if not ref($this);

  my $base = $this->{m_basesubdir}->{'1'};
  my $datadir = $this->{m_proddata}->getInfo('DATADIR');

  my $retval = 0;
  if(! -d "$base/boot") {
    $this->{m_logger}->warning("[W] There is no /boot subdirectory. This may be ok for some media, but might indicate errors in metapackages!");
    return $retval;
  }

  my %rpmlist_files;
  find( sub { rpmlist_find_cb($this, \%rpmlist_files) }, "$base/boot");

  foreach my $arch(keys(%rpmlist_files)) {
    if(not open(RPMLIST, $rpmlist_files{$arch})) {
      $this->{m_logger}->warning("[W] cannot open file $base/boot/$arch/$rpmlist_files{$arch}!");
      return -1;
    }
    else {
      RPM:foreach my $rpmname(<RPMLIST>) {
	chomp $rpmname;
	if(not defined($rpmname) or not defined($this->{m_repoPacks}->{$rpmname})) {
	  $this->{m_logger}->warning("[W] something wrong with rpmlist: undefined value $rpmname");
	  next RPM;
	}
	my %tmp = %{$this->{m_repoPacks}->{$rpmname}};
	if(!%tmp) {
	  $this->{m_logger}->warning("[W] No package hash entry for package $rpmname in packages hash! Package missing?");
	}
	else {
          # FIXME: This is just a hack, where do we get the upper architecture from ?
          my $targetarch = $arch;
          if ( $arch eq 'i386' ) {
             $targetarch = "i586";
          }
          # End of hack
	  my @fallb = $this->{m_archlist}->fallbacks($targetarch);
	  FARCH:foreach my $fa(@fallb) {
	    if(not defined($tmp{$fa})) {
	      next FARCH;
	    }
	    symlink("../../$datadir/$fa/".$tmp{$fa}->{'newfile'}, "$base/boot/$arch/$rpmname.rpm");
	    $retval++;
	    next RPM;
	  }
	}
      }
    }
  }
  return $retval;
}



sub rpmlist_find_cb
{
  my $this = shift;
  return undef if not ref($this);

  my $listref = shift;
  return undef if not defined($listref);

  if($File::Find::name =~ m{.*/([^/]+)/rpmlist}) {
    $listref->{$1} = $File::Find::name;
  }
}



#sub getSrcList
#{
#  my $this = shift;
#  my $p = shift;
#
#  return undef if(!$p);
#
#  my %src;
#  foreach my $a(keys(%{$this->{m_packages}->{$p}})) {
#    next if($a =~ m{(arch|addarch|removearch|onlyarch|source|script|medium)});
#    if(!$this->{m_packages}->{$p}->{$a}->{'localfile'}) {
#      # pack without source is bäh!
#      goto error;
#    }
#    $src{$a} = $this->{m_packages}->{$p}->{$a}->{'localfile'}
#  }
#  return %src;
#
#  error:
#  $this->{m_logger}->warning("[W] [getSrcList] source not defined, method called before downloads complete!\n");
#  return undef;
#}
#


#==========================================
# createDirecotryStructure
#------------------------------------------
# Creates and updates the directories that are created during
# installation source creation.
#------------------------------------------
# Hash values of %{$this->{m_dirlist}}:
# 0 = directory exists
# 1 = directory must be created
# 2 = an error occured at creation
#------------------------------------------
sub createDirectoryStructure
{
  my $this = shift;
  my %dirs = %{$this->{m_dirlist}};

  my $errors = 0;

  foreach my $d(keys(%dirs)) {
		next if $dirs{$d} == 0;
    if(-d $d) {
      $dirs{$d} = 0;
    }
    elsif(!mkpath($d, 0755)) {
      $this->{m_logger}->error("[E] createDirectoryStructure: can't create directory $d!");
      $dirs{$d} = 2;
      $errors++;
    }
    else {
      $this->{m_logger}->info("[I] created directory $d") if $this->{m_debug};
      $dirs{$d} = 0;
    }
  }

  if($errors) {
    $this->{m_logger}->error("[E] createDirectoryStructure failed. Abort recommended.");
  }
  return $errors;
}



#==========================================
# getMediaNumbers
#------------------------------------------
# Returns a list containing all the media involved in a
# product. Each number is only reported once.
# The list may contain leaks (1,2,5,6 is perfectly ok)
#------------------------------------------
sub getMediaNumbers
{
  my $this = shift;
  return undef if not defined $this;
  
  my @media = (1);	# default medium is 1 (always)
  if(not defined($this->{m_srcmedium})) {
    $this->{m_kiwi}->error("[E] getMediaNumbers: SOURCEMEDIUM is undefined!");
    return undef;
  }
  push @media, $this->{m_srcmedium};

  if(defined($this->{m_debugmedium})) {
    push @media, $this->{m_debugmedium};
  }

  foreach my $p(values(%{$this->{m_repoPacks}}), values(%{$this->{m_metapackages}})) {
    if(defined($p->{'medium'}) and $p->{'medium'} != 0) {
      push @media, $p->{medium};
    }
  }
  return sort(KIWIUtil::unify(@media));
}



1;

