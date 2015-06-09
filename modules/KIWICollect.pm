#================
# FILE          : KIWICollect.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
# Maintainer    : Adrian Schroeter <adrian@suse.de>
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
package KIWICollect;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use FileHandle;
use File::Find;
use File::Path;
use Cwd 'abs_path';
use Data::Dumper;

#==========================================
# Dynamic Modules
#------------------------------------------
BEGIN {
    unshift @INC, '/usr/share/inst-source-utils/modules';
    eval {
        require RPMQ;
        RPMQ -> import;
    };
}

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIArchList;
use KIWIGlobals;
use KIWIProductData;
use KIWIRepoMetaHandler;
use KIWIURL;
use KIWIUtil;
use KIWIXML;
use KIWILog;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create a new KIWICollect object which is used to create a
    # consistent package directory from various source trees
    # ---
    #==========================================
    # Members
    #------------------------------------------
    # m_logger:
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
    #==========================================
    # Object setup
    #------------------------------------------
    my $class = shift;
    my $this  = {
        # object handling the various metadata types
        m_metacreator  => undef,
        m_archlist     => undef,
        m_basedir      => undef,
        m_repos        => undef,
        m_xml        => undef,
        m_util         => undef,
        m_logger       => undef,
        m_packagePool  => undef,
        m_repoPacks    => undef,
        m_sourcePacks  => undef,
        m_debugPacks   => undef,
        m_metaPacks    => undef,
        m_metafiles    => undef,
        m_browser      => undef,
        m_srcmedium    => -1,
        m_debugmedium  => -1,
        m_logStdOut    => 0,
        m_startUpTime  => undef,
        m_fpacks       => [],
        m_fmpacks      => [],
        m_fsrcpacks    => [],
        m_fdebugpacks  => [],
        m_debug        => undef,
        m_rmlists      => undef,
        m_appdata      => undef,
        m_reportLog    => {},
    };

    my $global = KIWIGlobals -> instance();
    $this->{gdata} = $global -> getKiwiConfig();

    bless $this, $class;

    $this->{m_logger} = KIWILog -> instance();
    $this->{m_logger}->setLogFile("terminal");

    #==========================================
    # Module Parameters
    #------------------------------------------
    $this->{m_xml}      = shift;
    $this->{m_basedir}  = shift;
    $this->{m_debug}    = shift || 0;
    $this->{cmdL}     = shift;

    if( !(defined($this->{m_xml})
                and defined($this->{m_basedir})
                and defined($this->{m_logger}))
    ) {
        return;
    }
    # work with absolute paths from here.
    $this->{m_basedir} = abs_path($this->{m_basedir});
    $this->{m_startUpTime} = time();

    # create second logger object to log only the data relevant
    # for repository creation:
    $this->{m_util} = KIWIUtil -> new ($this);
    if(!$this->{m_util}) {
        $this->logMsg('E', "Can't create KIWIUtil object!");
        return;
    } else {
        $this->logMsg('I', "Created new KIWIUtil object");
    }
    $this->{m_urlparser} = KIWIURL -> new ($this->{cmdL});
    if(!$this->{m_urlparser}) {
        $this->logMsg('E', "Can't create KIWIURL object!");
        return;
    } else {
        $this->logMsg('I', "Created new KIWIURL object");
    }

    # create the product variables administrator object.
    # This must be incubated with the respective data in the Init() method
    $this->{m_proddata} = KIWIProductData -> new ($this);
    if(!$this->{m_proddata}) {
        $this->logMsg('E', "Can't create KIWIProductData object!");
        return;
    } else {
        $this->logMsg('I', "Created new KIWIProductData object");
    }
    $this->logMsg('I', "KIWICollect2 object initialisation finished");
    return $this;
}

#==========================================
# logMsg
#------------------------------------------
sub logMsg {
    # ...
    # kiwi log extension suitable for product builds which
    # directly prints messages as raw output in order to
    # speed up the build
    # --- 
    my $this = shift;
    my $mode = shift;
    my $string = shift;
    my $out = "[".$mode."] ".$string."\n";
    if ($this->{m_logStdOut} == 1 || $this->{m_debug} >= 1) {
        # significant speed up in production mode
        print $out;
        if ( $mode eq 'E' ) {
            exit 1;
        }
    } else {
        if ( $mode eq 'E' ) {
            $this->{m_logger}->error($out);
        } elsif ( $mode eq 'W' ) {
            $this->{m_logger}->warning($out);
        } elsif ( $mode eq 'I' ) {
            $this->{m_logger}->info($out);
        } elsif ($this->{m_debug}){
            $this->{m_logger}->info($out);
        }
    }
    return;
}

#==========================================
# unitedDir
#------------------------------------------
sub unitedDir {
    my $this = shift;
    my $list = shift;
    if(! ref $this ) {
        return;
    }
    my $oldunited = $this->{m_united};
    if($list) {
        $this->{m_united} = $list;
    }
    return $oldunited;
}

#==========================================
# archlist
#------------------------------------------
sub archlist {
    my $this = shift;
    if(not ref $this ) {
        return;
    }
    return $this->{m_archlist};
}

#==========================================
# productData
#------------------------------------------
sub productData {
    my $this = shift;
    if(not ref $this ) {
        return;
    }
    return $this->{m_proddata};
}

#==========================================
# basedir
#------------------------------------------
sub basedir {
    my $this = shift;
    if(not ref $this ) {
        return;
    }
    return $this->{m_basedir};
}

#==========================================
# basesubdirs
#------------------------------------------
sub basesubdirs {
    my $this = shift;
    if(! ref $this ) {
        return;
    }
    return $this->{m_basesubdir};
}

#==========================================
# Init
#------------------------------------------
sub Init {
    # ...
    # Initialize product build environment. This includes
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
    # ---
    my $this = shift;
    my $debug = shift || 0;

    # retrieve data from xml file:
    # packages list (regular packages)
    my %instPacks;
    my $instref = $this->{m_xml} -> getProductSourcePackages();
    for my $package (@{$instref}) {
        my $name = $package -> getName();
        my %attr;
        $attr{forcerepo} = $package -> getForceRepo();
        $attr{addarch}   = $package -> getAdditionalArch();
        $attr{removearch}= $package -> getRemoveArch();
        $attr{arch}      = $package -> getArch();
        $attr{onlyarch}  = $package -> getOnlyArch();
        $attr{source}    = $package -> getSourceLocation();
        $attr{script}    = $package -> getScriptPath();
        $attr{medium}    = $package -> getMediaID();
        $instPacks{$name} = \%attr;
    }
    $this->logMsg('I', "KIWICollect::Init: querying instsource package list");
    %{$this->{m_repoPacks}} = %instPacks;
    # this list may be empty!
    $this->logMsg('I', "KIWICollect::Init: queried package list.");
    if($this->{m_debug}) {
        my $DUMP;
        $this->logMsg('I', "See packages.dump.pl");
        open($DUMP, '>', "$this->{m_basedir}/packages.dump.pl")
                or die 'Fail dbg';
        print $DUMP Dumper($this->{m_repoPacks});
        close $DUMP;
    }

    # architectures information (hash with name|desrc|next, next may be 0
    # which means "no fallback")
    # this element is mandatory. Empty = Error
    $this->logMsg('I',
        'KIWICollect::Init: querying instsource architecture list'
    );
    $this->{m_archlist} = KIWIArchList -> new ($this);
    my $archref = $this->{m_xml} -> getProductRequiredArchitectures();
    my $archadd = $this->{m_archlist}->addArchs( $archref );
    if(! defined $archadd ) {
        $this->logMsg('I', Dumper($archref));
        $this->logMsg('E', "KIWICollect::Init: addArchs returned undef");
        return;
    } else {
        $this->logMsg('I', "KIWICollect::Init: queried archlist.");
        if($this->{m_debug}) {
            $this->logMsg('I', "See archlist.dump.pl");
            my $DUMP;
            open($DUMP, ">", "$this->{m_basedir}/archlist.dump.pl")
                or die 'Fail dbg';
            print $DUMP $this->{m_archlist}->dumpList();
            close $DUMP;
        }
    }
    # repository information
    # mandatory. Missing = Error
    my $prodrepo = $this->{m_xml} -> getProductRepositories();
    my %repodata;
    for my $repo (@{$prodrepo}) {
        my $name = $repo -> getName();
        my $prio = $repo -> getPriority();
        my ($user,$pwd) = $repo -> getCredentials(); 
        my $islocal =  $repo -> isLocal();
        my $path = $repo -> getPath();
        my $source = $this->{m_xml} -> __resolveLink ($path);
        if (! defined $name) {
            $name = "noname";
        }
        $repodata{$name}{source}   = $source;
                $repodata{$name}{priority} = $prio;
                $repodata{$name}{islocal} = $islocal;
        if (defined $user) {
            $repodata{$name}{user} = $user.":".$pwd;
        }
    }
    %{$this->{m_repos}} = %repodata;
    if(!$this->{m_repos}) {
        $this->logMsg('E',
                'KIWICollect::Init: getProductRepositories returned empty hash');
        return;
    } else {
        $this->logMsg('I', "KIWICollect::Init: retrieved repository list.");
        if($this->{m_debug}) {
            $this->logMsg('I', "See repos.dump.pl");
            my $DUMP;
            open($DUMP, '>', "$this->{m_basedir}/repos.dump.pl")
                or die 'Fail dbg';
            print $DUMP Dumper($this->{m_repos});
            close $DUMP;
        }
    }

    # package list (metapackages with extra effort by scripts)
    # mandatory. Empty = Error
    my %metaPacks;
    my $metaref = $this->{m_xml} -> getProductMetaPackages();
    for my $package (@{$metaref}) {
        my $name = $package -> getName();
        my %attr;
        $attr{forcerepo} = $package -> getForceRepo();
        $attr{addarch}   = $package -> getAdditionalArch();
        $attr{removearch}= $package -> getRemoveArch();
        $attr{arch}      = $package -> getArch();
        $attr{onlyarch}  = $package -> getOnlyArch();
        $attr{source}    = $package -> getSourceLocation();
        $attr{script}    = $package -> getScriptPath();
        $attr{medium}    = $package -> getMediaID();
        $metaPacks{$name} = \%attr;
    }
    %{$this->{m_metaPacks}}  = %metaPacks;
    if(!$this->{m_metaPacks}) {
        my $msg = 'KIWICollect::Init: getProductMetaPackages '
            . 'returned no information, no metadata specified.';
        $this->logMsg('E', $msg);
        return;
    } else {
        $this->logMsg('I', "KIWICollect::Init: retrieved metapackage list.");
        if($this->{m_debug}) {
            $this->logMsg('I', "See metaPacks.dump.pl");
            my $DUMP;
            open($DUMP, '>', "$this->{m_basedir}/metaPacks.dump.pl")
                or die 'Fal dbg';
            print $DUMP Dumper($this->{m_metaPacks});
            close $DUMP;
        }
    }

    # metafiles: different handling
    # may be omitted
    my $metafileref = $this->{m_xml} -> getProductMetaFiles();
    my %metafile;
    for my $file (@{$metafileref}) {
        my $url = $file -> getURL();
        next if (! $url);
        my $target = $file -> getTarget();
        if ($target) {
            $metafile{$url}{target} = $target;
        }
        my $script = $file -> getScript();
        if ($script) {
            $metafile{$url}{script} = $script;
        }
    }
    %{$this->{m_metafiles}} = %metafile;
    if(!$this->{m_metaPacks}) {
        my $msg = 'KIWICollect::Init: getProductMetaFiles returned '
            . 'no information, no metafiles specified.';
        $this->logMsg('I', $msg);
    } else {
        $this->logMsg('I', "KIWICollect::Init: retrieved metafile list.");
        if($this->{m_debug}) {
            $this->logMsg('I', "See metafiles.dump.pl");
            my $DUMP;
            open($DUMP, '>', "$this->{m_basedir}/metafiles.dump.pl")
                or die 'Fail dbg';
            print $DUMP Dumper($this->{m_metafiles});
            close $DUMP;
        }
    }

    # info about requirements for chroot env to run metadata scripts
    # may be empty
    my $metachrootref = $this->{m_xml} -> getProductMetaChroots();
    my @metachroot;
    for my $item (@{$metachrootref}) {
        my $reqvalue = $item -> getRequires();
        if ($reqvalue) {
            push @metachroot,$reqvalue
        }
    }
    @{$this->{m_chroot}} = @metachroot;
    if(!$this->{m_chroot}) {
        my $msg = 'KIWICollect::Init: chroot list is empty hash, no chroot '
            . 'requirements specified';
        $this->logMsg('I', $msg);
    } else {
        $this->logMsg('I', "KIWICollect::Init: retrieved chroot list.");
        if($this->{m_debug}) {
            $this->logMsg('I', "See chroot.dump.pl");
            my $DUMP;
            open($DUMP, '>', "$this->{m_basedir}/chroot.dump.pl")
                or die 'Fail dbg';
            print $DUMP Dumper($this->{m_chroot});
            close $DUMP;
        }
    }
    my ($iadded, $vadded, $oadded);
    my $prod_info = $this->{m_xml} -> getProductOptions();
    my @prod_info_names = @{$prod_info -> getProductInfoNames()};
    my %prod_info_hash;
    for(my $n=0; $n <= $#prod_info_names; $n++) {
        my $name = $prod_info_names[$n];
        my $data = $prod_info -> getProductInfoData ($name);
        $prod_info_hash{$n} = [$name,$data];
    }
    my @prod_var_names = @{$prod_info -> getProductVariableNames()};
    my %prod_var_hash;
    for(my $n=0; $n <= $#prod_var_names; $n++) {
        my $name = $prod_var_names[$n];
        my $data = $prod_info -> getProductVariableData ($name);
        $prod_var_hash{$name} = $data;
    }
    my @prod_opt_names = @{$prod_info -> getProductOptionNames()};
    my %prod_opt_hash;
    for(my $n=0; $n <= $#prod_opt_names; $n++) {
        my $name = $prod_opt_names[$n];
        my $data = $prod_info -> getProductOptionData ($name);
        $prod_opt_hash{$name} = $data;
    }
    $iadded = $this->{m_proddata}->addSet(
        "ProductInfo stuff",\%prod_info_hash,"prodinfo"
    );
    $vadded = $this->{m_proddata}->addSet(
        "ProductVar stuff",\%prod_var_hash,"prodvars"
    );
    $oadded = $this->{m_proddata}->addSet(
        "ProductOption stuff",\%prod_opt_hash,"prodopts"
    );
    if ($iadded) {
        if ((! $vadded) || (! $oadded)) {
            my $msg = 'KIWICollect::Init: incomplete productoptions section';
            $this->logMsg('E', $msg);
            return;
        }
    }
    $this->{m_proddata}->_expand(); #once should be it, now--
    if($this->{m_debug}) {
        my $DUMP;
        open($DUMP, '>', "$this->{m_basedir}/productdata.pl")
            or die 'Fail dbg';
        print $DUMP "# PRODUCTINFO:";
        print $DUMP Dumper($this->{m_proddata}->getSet('prodinfo'));
        print $DUMP "# PRODUCTVARS:";
        print $DUMP Dumper($this->{m_proddata}->getSet('prodvars'));
        print $DUMP "# PRODUCTOPTIONS:";
        print $DUMP Dumper($this->{m_proddata}->getSet('prodopts'));
        close $DUMP;
    }

    # Set possible defined source or debugmediums
    $this->{m_srcmedium}   = $this->{m_proddata}->getOpt("SOURCEMEDIUM") || -1;
    $this->{m_debugmedium} = $this->{m_proddata}->getOpt("DEBUGMEDIUM") || -1;

    $this->{m_united} = "$this->{m_basedir}/main";
    $this->{m_dirlist}->{"$this->{m_united}"} = 1;
    my $mediumname = $this->{m_proddata}->getVar("MEDIUM_NAME");
    if(not defined($mediumname)) {
        $this->logMsg('E',
            "Variable MEDIUM_NAME is not specified correctly!"
        );
        return;
    }
    my $theme = $this->{m_proddata}->getVar("PRODUCT_THEME");
    if(not defined($theme)) {
        my $msg = 'Variable <PRODUCT_THEME> is not specified correctly!';
        $this->logMsg('E', $msg);
        return;
    }
    my @media = $this->getMediaNumbers();
    my $mult = $this->{m_proddata}->getVar("MULTIPLE_MEDIA", "yes");
    my $dirext = undef;
    if($mult eq "no" || $mult eq "false") {
        if(scalar(@media) == 1) {
            $dirext = 1;
        } else {
            # this means the config says multiple_media=no BUT defines a
            #"medium=<number>" somewhere!
            my $msg = 'You want a single medium distro but specified '
                . "medium=... for some packages\n\tIgnoring the "
                . 'MULTIPLE_MEDIA=no flag!';
            $this->logMsg('W', $msg);
        }
    }
    my $descrdir = $this->{m_proddata}->getInfo("DESCRDIR");
    my $create_repomd;
    if ( defined($this->{m_proddata}->getVar("CREATE_REPOMD"))
        && $this->{m_proddata}->getVar("CREATE_REPOMD") eq "true") {
        $create_repomd = 1;
    }

    if(not defined($descrdir) or $descrdir =~ m{notset}i) {
        if ($create_repomd) {
            $this->logMsg('W',
                "Variable DESCRDIR not set but CREATE_REPOMD is true!"
            );
        } else {
            $this->logMsg('E', "Variable DESCRDIR missing!");
            return;
        }
    }
    my $datadir = $this->{m_proddata}->getInfo("DATADIR");
    if(not defined($datadir) or $datadir =~ m{notset}i) {
        $this->logMsg('E', "Variable DATADIR missing!");
        return;
    }

    $descrdir =~ s{^/(.*)/$}{$1};
    my @descrdirs = split('/', $descrdir);
    foreach my $n(@media) {
        my $dirbase = "$this->{m_united}/$mediumname";
        $dirbase .= "$n" if not defined($dirext);
        $this->{m_dirlist}->{"$dirbase"} = 1;
        $this->{m_dirlist}->{"$dirbase/$datadir"} = 1;
        if ($create_repomd) {
            $this->{m_dirlist}->{"$dirbase/$datadir/repodata"} = 1
        }
        my $curdir = "$dirbase/";
        foreach my $part(@descrdirs) {
            $curdir .= "$part/";
            $this->{m_dirlist}->{"$curdir"} = 1;
        }
        my $num = $n;
        if ( $this->{m_proddata}->getVar("FLAVOR", '') eq "ftp"
            or $this->{m_proddata}->getVar("FLAVOR", '') eq "POOL"
            or $n == $this->{m_debugmedium}
        ) {
            $num = 1;
        }
        $this->{m_dirlist}->{"$dirbase/media.$num"} = 1;
        $this->{m_basesubdir}->{$n} = "$dirbase";
        $this->{m_dirlist}->{"$this->{m_basesubdir}->{$n}"} = 1;
    }
    # /.../
    # we also need a basesubdir "0" for the metapackages that
    # shall _not_ be put to the CD. Those specify medium number "0",
    # which means we only need a dir to download scripts.
    # ----
    $this->{m_basesubdir}->{'0'} = "$this->{m_united}/".$mediumname."0";
    $this->{m_dirlist}->{"$this->{m_united}/".$mediumname."0/temp"} = 1;

    my $dircreate = $this->createDirectoryStructure();
    if($dircreate != 0) {
        my $msg = 'KIWICollect::Init: calling createDirectoryStructure failed';
        $this->logMsg('E', $msg);
        return;
    }

    if($this->{m_debug}) {
        my $msg = 'Debug: dumping packages list to <packagelist.txt>';
        $this->logMsg('I', $msg);
        $this->dumpPackageList("$this->{m_basedir}/packagelist.txt");
    }

    $this->logMsg('I', "KIWICollect::Init: create LWP module");
    $this->{m_browser} = LWP::UserAgent -> new();

    # create the metadata handler and load (+verify) all available plugins:
    # the required variables are MEDIUM_NAME, PLUGIN_DIR, INI_DIR
    # should be set by now.
    $this->logMsg('I',
        "KIWICollect::Init: create KIWIRepoMetaHandler module"
    );
    $this->{m_metacreator} = KIWIRepoMetaHandler -> new ($this);
    $this->{m_metacreator}->baseurl($this->{m_united});
    $this->{m_metacreator}->mediaName(
        $this->{m_proddata}->getVar('MEDIUM_NAME')
    );
    my $msg = 'Loading plugins from <'
        . $this->{m_proddata}->getOpt("PLUGIN_DIR")
        . '>';
    $this->logMsg('I', $msg);
    my ($loaded, $avail) = $this->{m_metacreator}->loadPlugins();
    if($loaded < $avail) {
        $this->logMsg('E',
            "could not load all plugins! <$loaded/$avail>!"
        );
        return;
    }
    $this->logMsg('I',
        "Loaded <$loaded> plugins successfully."
    );

    # second level initialisation done, now start work:
    if($this->{m_debug}) {
        $msg = 'STEP 0 (initialise) -- Examining repository structure';
        $this->logMsg('I', $msg);
        if ($this->{m_debug}) {
            $this->logMsg('I', 'STEP 0.1 (initialise) -- Create local paths');
        }
    }

    # create local directories as download targets. Normalising special chars
    # (slash, dot, ...) by replacing with second param.
    for my $r(keys(%{$this->{m_repos}})) {
        if ($this->{m_debug}) {
            $msg = '[Init] resolving URL '
                . "$this->{m_repos}->{$r}->{'source'}...";
            $this->logMsg('I', $msg);
        }
        $this->{m_repos}->{$r}->{'origin'} = $this->{m_repos}->{$r}->{'source'};
        $this->{m_repos}->{$r}->{'source'} =
        $this->{m_urlparser}->normalizePath(
            $this->{m_repos}->{$r}->{'source'}
        );
        if ($this->{m_debug}) {
            $msg = '[Init] resolved URL: '
                . "$this->{m_repos}->{$r}->{'source'}";
            $this->logMsg('I', $msg);
        }
        my $path = $this->{m_basedir}
            . "/"
            . $this->{m_util}->normaliseDirname(
        $this->{m_repos}->{$r}->{'source'}, '-');
        $this->{m_repos}->{$r}->{'basedir'} = $path;
        $this->{m_dirlist}->{"$this->{m_repos}->{$r}->{'basedir'}"} = 1;
        if ($this->{m_debug}) {
            $msg = 'STEP 1.2 -- Expand path names for all repositories';
            $this->logMsg('I', $msg);
        }
        # strip off trailing slash in each repo (robust++)
        $this->{m_repos}->{$r}->{'source'} =~ s{(.*)/$}{$1};
        my @tmp;
        # /.../
        # splitPath scans the URLs for valid directories no matter if they
        # are local/remote (currently http(s), file and obs://
        # are allowed. The list of directories is stored in the tmp list
        # (param 1), the 4th param pattern determines the depth for the scan.
        if(! defined($this->{m_util}->splitPath(\@tmp,
            $this->{m_browser},
            $this->{m_repos}->{$r}->{'source'},
            "/.*/.*/", 0))
        ) {
            $msg = 'KIWICollect::new: KIWIUtil::splitPath returned undef!';
            $this->logMsg('W', $msg);
            $this->logMsg('W', "\tparsing repository $r");
            $msg = "\tusing source "
                . $this->{m_repos}->{$r}->{'source'}
                . ': check repository structure!';
            $this->logMsg('W', $msg);
        }
        for my $dir(@tmp) {
            $dir = substr($dir, length($this->{m_repos}->{$r}->{'source'}));
            $dir = "$dir/";
        }
        my $tmp = @tmp;
        my %tmp = map { $_ => undef } @tmp;
        if($tmp != 0) {
            $this->{m_repos}->{$r}->{'srcdirs'} = \%tmp;
        } else {
            $this->{m_repos}->{$r}->{'srcdirs'} = undef;
        }
    }
    return 1;
}

#==========================================
# mainTask
#------------------------------------------
sub mainTask {
    # ...
    # After initialisation by the constructor the repositories
    # have to be processed and all relevant data will be
    # collected to form an installation media
    # ---
    my $this = shift;
    my $retval = undef;
    if (! defined $this ) {
        return 1;
    }
    # Collect all needed packages
    if ($this->collectPackages()) {
        $this->logMsg('E', "collecting packages failed!");
    }

    # Look for all products collected
    if ($this->{m_proddata}->getInfo("NAME")) {
        # product must be part of content file for
        # pre-openSUSE 13.2 and SLE 12
        $this->collectProducts();
                }

    # create meta data
    $this->createMetadata();
    # DUD:
    if ($this->{m_xml}->isDriverUpdateDisk()) {
        $this->unpackModules();
        $this->unpackInstSys();
        $this->createInstallPackageLinks();
    }
    # We create iso files by default, but keep this for manual override
    if($this->{m_proddata}->getVar("REPO_ONLY", 'false') eq "true") {
        $this->logMsg('I',
            "Skipping ISO generation due to REPO_ONLY setting"
        );
        return 0;
    }
    # should not be applied anymore
    if($this->{m_proddata}->getVar("FLAVOR", '') eq "ftp") {
        my $msg = 'Skipping ISO generation for FLAVOR ftp, please use '
            . 'REPO_ONLY flag instead !';
        $this->logMsg('W', $msg);
        return 0;
    }
    # create ISO using KIWIIsoLinux.pm
    eval "require KIWIIsoLinux"; ## no critic
    if($@) {
        $this->logMsg('E',
            "Module KIWIIsoLinux not loadable: $@"
        );
        return 1;
    } else {
        my $iso;
        for my $cd ($this->getMediaNumbers()) {
            if ( $cd == 0 ) {
                next;
            }
            ( my $name = $this->{m_basesubdir}->{$cd} ) =~ s{.*/(.*)/*$}{$1};
            my $isoname = $this->{m_united}."/$name.iso";
            # construct volume id, no longer than 32 bytes allowed
            my $volid_maxlen = 32;
            my $vname = $name;
            $vname =~ s/-Media//;
            $vname =~ s/-Build// if length($vname) > ($volid_maxlen - 4);
            my $vid = substr($vname,0,($volid_maxlen));
            if ($this->{m_proddata}->getVar("MULTIPLE_MEDIA", "yes") eq "yes") {
                $vid = sprintf(
                    "%s.%03d",
                    substr($vname,0,($volid_maxlen - 4)), $cd
                );
            }
            my $attr = "-r"; # RockRidge
            $attr .= " -pad"; # pad image by 150 sectors - needed for Linux
            $attr .= " -f"; # follow symlinks - really necessary?
            $attr .= " -J"; # Joilet extensions - only useful for i586/x86_64,
            $attr .= " -joliet-long"; # longer filenames for joilet filenames
            $attr .= " -p \"$this->{gdata}->{Preparer}\"";
            $attr .= " -publisher \"$this->{gdata}->{Publisher}\"";
            $attr .= " -A \"$name\"";
            $attr .= " -V \"$vid\"";
            my $checkmedia = '';
            if ( defined($this->{m_proddata}->getVar("RUN_MEDIA_CHECK"))
                && $this->{m_proddata}->getVar("RUN_MEDIA_CHECK") ne "0"
                && $this->{m_proddata}->getVar("RUN_MEDIA_CHECK") ne "false"
            ) {
                $checkmedia = "checkmedia";
            }
            my $hybridmedia;
            if ( defined($this->{m_proddata}->getVar("RUN_ISOHYBRID"))
                && $this->{m_proddata}->getVar("RUN_ISOHYBRID") eq "true"
            ) {
                $hybridmedia = 1 ;
            }
            $iso = KIWIIsoLinux -> new(
                $this->{m_basesubdir}->{$cd},
                $isoname, $attr, $checkmedia, $this->{cmdL}, $this->{m_xml}
            );
            # Just the first media is usually bootable at SUSE
            my $is_bootable = 0;
            if(-d "$this->{m_basesubdir}->{$cd}/boot") {
                if(!$iso->makeIsoEFIBootable()) {
                    my $msg = 'Creating fat image for efi iso boot failed '
                        . 'not efi bootable';
                    $this->logMsg('W', $msg);
                }
                if(!$iso->callBootMethods()) {
                    my $msg = 'Creating boot methods failed, medium maybe '
                        . 'not be bootable';
                    $this->logMsg('W', $msg);
                } else {
                    my $firmware = 'bios';
                    my $xmlFirmWare = $this->{m_xml}
                        -> getImageType() -> getFirmwareType();
                    if ($xmlFirmWare) {
                        $firmware = $xmlFirmWare;
                    }
                    if ($firmware eq "efi" || $firmware eq "uefi") {
                        my @archs = $this->{m_archlist}->headList();
                        if (grep {"x86_64" eq $_} @archs) {
                            $this->logMsg('I', "Add Live setup");
                            $iso -> addBootLive();
                        }
                    }
                    $this->logMsg('I', "Boot methods called successfully");
                    $is_bootable = 1;
                }
            }
            if(!$iso->createISO()) {
                $this->logMsg('E', "Cannot create Iso image");
                return 1;
            } else {
                $this->logMsg('I', "Created Iso image <$isoname>");
            }
            if ($is_bootable) {
                if (! $iso->relocateCatalog()) {
                    return 1;
                }
                if (! $iso->fixCatalog()) {
                    return 1;
                }
                if ($hybridmedia) {
                    if(!$iso->createHybrid()) {
                        $this->logMsg('W', "Isohybrid call failed");
                    } else {
                        $this->logMsg('I', "Isohybrid call successful");
                    }
                }
            }
            if(!$iso->checkImage()) {
                $this->logMsg('E', "Tagmedia call failed");
                return 1;
            } else {
                $this->logMsg('I', "Tagmedia call successful");
            }
        }
    }
    return 0;
}

#==========================================
# getMetafileList
#------------------------------------------
sub getMetafileList {
    # ...
    # get list of metafiles (no packages)
    # possible return values:
    # 0     =>  all ok
    # -1    =>  error in call
    # n > 0 =>  [n] metafiles failed
    # ---
    my $this = shift;
    if((!%{$this->{m_basesubdir}}) || (! -d $this->{m_basesubdir}->{'1'})) {
        my $msg = 'getMetafileList called to early? basesubdir must be set!';
        $this->logMsg('W', $msg);
        return -1;
    }
    my $failed = 0;
    for my $mf(keys(%{$this->{m_metafiles}})) {
        my $t = $this->{m_metafiles}->{$mf}->{'target'} || "";
        KIWIGlobals -> instance() -> downloadFile(
            $mf, "$this->{m_basesubdir}->{'1'}/$t"
        );
        my $fname;
        $mf =~ m{.*/([^/]+)$};
        $fname = $1;
        if(! defined $fname) {
            my $msg = "[getMetafileList] filename $mf doesn't match regexp, "
                . 'skipping';
            $this->logMsg('W', $msg);
            next;
        }
    }
    return $failed;
}

#==========================================
# addAppdata
#------------------------------------------
sub addAppdata {
    my $this = shift;
    my $packPointer = shift;
    return unless $packPointer->{'appdata'};
    $this->logMsg('I', "taking $packPointer->{'appdata'}");
    my $XML = FileHandle -> new();
    $XML -> open ($packPointer->{'appdata'});
    my $xml  = XML::LibXML -> new();
    eval { $xml -> parse_fh ( $XML ); };
    if ($@) {
        $this->logMsg('W', "ignoring broken appdata file");
        $XML -> close();
        return;
    }
    $XML->seek(0, 0);
    while ( <$XML> ) {
        next if m,<\?xml,;
        next if m,^\s*</?applications,;
        $this->{m_appdata} .= $_;
    }
    $XML -> close();
    return;
}

#==========================================
# addDebugPackage
#------------------------------------------
sub addDebugPackage {
    my $this = shift;
    my $packname = shift;
    my $arch = shift;
    my $packPointer = shift;
    if ( $this->{m_debugPacks}->{$packname} ){
        $this->{m_debugPacks}->{$packname}->{'onlyarch'} .= ",$arch";
    } else {
        $this->{m_debugPacks}->{$packname} = {
            'medium' => $this->{m_debugmedium},
            'onlyarch' => $arch
        };
    }
    $this->{m_debugPacks}->{$packname}->{'requireVersion'}->
    { "$packPointer->{'version'}-$packPointer->{'release'}" } = 1;
    return;
}

#==========================================
# indexOfArray
#------------------------------------------
sub indexOfArray {
    my $element = shift;
    my $array = shift;
    my $count = 0;
    foreach my $val(@$array) {
        $count = $count + 1;
        return $count if "$val" eq "$element";
    }
    return $count;
}

#==========================================
# setupPackageFiles
#------------------------------------------
sub setupPackageFiles {
    # ...
    # 1 = collect source & debug packnames
    # 2 = use only src/nosrc packs
    # 3 = ignore missing packages in any case (debug media mode)
    # ---
    my $this = shift;
    my $mode = shift;
    my $usedPackages = shift;
    my $retval = 0;
    my $base_on_cd = $this->{m_proddata}->getInfo("DATADIR");
    if(! defined($base_on_cd)) {
        $this->logMsg('E', "setupPackageFile: variable DATADIR must be set!");
        return $retval;
    }
    if(!%{$usedPackages}) {
        # empty repopackages -> probably a mini-iso (metadata only)
        # nothing to do
        my $msg = 'Looks like no repopackages are required, assuming '
            . 'miniiso. Skipping setupPackageFile.';
        $this->logMsg('W', $msg);
        return $retval;
    }
    my $last_progress_time = 0;
    my $count_packs = 0;
    my $num_packs = keys %{$usedPackages};
    my @missingPackages = ();
    PACK:
    for my $packName(keys(%{$usedPackages})) {
        if ($packName eq "_name") {
            next;
        }
        #input options from kiwi files
        my $packOptions = $usedPackages->{$packName};
        #pointer to local package pool hash
        my $poolPackages = $this->{m_packagePool}->{$packName};
        my $nofallback = 0;
        my @archs;
        $count_packs++;
        if ( $mode == 2 ) {
            # use src or nosrc only for this package
            for my $a (split(/,\s*/, $packOptions->{'onlyarch'})) {
              push @archs, $a;
            }
        } else {
            @archs = $this->getArchList($packOptions, $packName, \$nofallback);
        }
        if ( $this->{m_debug} >= 1 ) {
            if ( $last_progress_time < time() ){
                my $str;
                $str = (time() - $this->{m_startUpTime}) / 60;
                $str = sprintf "%.0f", $str;
                my $msg = "  process $usedPackages->{_name}->{label} package "
                    . "links: ($count_packs/$num_packs), running $str minutes";
                $this->logMsg('I', $msg);
                $last_progress_time = time() + 5;
            }
            if ($this->{m_debug} >= 4) {
                $this->logMsg('I', "Evaluate package $packName for @archs");
            }
        }
        ARCH:
        for my $requestedArch(@archs) {
            if ($this->{m_debug} >= 5) {
                my $msg = "  Evaluate package $packName for requested arch "
                    . "$requestedArch";
                $this->logMsg('I', $msg);
            }
            my @fallbacklist = ($requestedArch);
            if($nofallback==0 && $mode != 2) {
                @fallbacklist = $this->{m_archlist}->fallbacks($requestedArch);
                @fallbacklist = ($requestedArch) unless @fallbacklist;
                if ($this->{m_debug} >= 6) {
                    $this->logMsg('I', " Look for fallbacks fallbacks") ;
                }
            }
            if ($this->{m_debug} >= 5) {
                my $msg = '    Use as expanded architectures >'
                    . join(" ", @fallbacklist)
                    . '<';
                $this->logMsg('I', $msg);
            }
            my $fb_available = 0;
                PACKKEY:
                for my $packKey( sort {
                        $poolPackages->{$a}->{priority}
                        <=> $poolPackages->{$b}->{priority}
					|| indexOfArray($poolPackages->{$a}->{arch}, \@fallbacklist)
					<=> indexOfArray($poolPackages->{$b}->{arch}, \@fallbacklist)
                    } keys(%{$poolPackages})
                ) {
                    if ($this->{m_debug} >= 5) {
                        $this->logMsg('I', "  check $packKey ");
                    }

                    my $arch;
                    my $packPointer = $poolPackages->{$packKey};
		    for my $checkarch(@fallbacklist) {
                        if ($this->{m_debug} >= 5) {
                            $this->logMsg('I', "    check architecture $checkarch ");
                        }
                        # sort keys 1st by repository order and secondary by architecture priority
                        if ( $packPointer->{arch} ne $checkarch ) {
                            if ($this->{m_debug} >= 4) {
                                my $msg = "     => package $packName not available "
                                          ."for arch $checkarch in repo $packKey";
                                $this->logMsg('I', $msg);
                            }
                            next;
                        }
                        if ($nofallback==0
                            && $mode != 2 && $this->{m_archlist}->arch($checkarch)) {
                            my $follow = $this->{m_archlist}->arch($checkarch)->follower();
                            if( defined $follow ) {
                                if ($this->{m_debug} >= 4) {
                                    my $msg = " => falling back to $follow "
                                        . "from $packKey instead";
                                    $this->logMsg('I', $msg);
                                }
                            }
                        }
                        if ( scalar(keys %{$packOptions->{requireVersion}}) > 0
                             && ! defined($packOptions->{requireVersion}->{$packPointer->{version}
                                           ."-".$packPointer->{release}}) ) {
                             if ($this->{m_debug} >= 4) {
                                my $msg = "     => package "
                                          .$packName
                                          .'-'
                                          .$packPointer->{version}
                                          .'-'
                                          .$packPointer->{release}
                                          ." not available for arch $checkarch in "
                                          ."repo $packKey in this version";
                                $this->logMsg('D', $msg);
                             }
                             next;
                    }
                    # Success, found a package !
                    $arch = $checkarch;
                    last;
                }
                next unless defined $arch;

                # process package
                my $medium = $packOptions->{'medium'} || 1;
                $packOptions->{$requestedArch}->{'newfile'} =
                    "$packName-"
                    .$packPointer->{'version'}
                    .'-'
                    .$packPointer->{'release'}
                    .".$packPointer->{'arch'}.rpm";
                $packOptions->{$requestedArch}->{'newpath'} =
                    "$this->{m_basesubdir}->{$medium}"
                    ."/$base_on_cd/$packPointer->{'arch'}";
                # check for target directory:
                if (! $this->{m_dirlist}->
                    {"$packOptions->{$requestedArch}->{'newpath'}"}
                ) {
                    $this->{m_dirlist}->
                        {"$packOptions->{$requestedArch}->{'newpath'}"} = 1;
                    $this->createDirectoryStructure();
                }
                # link it:
                my $item = $packOptions->{$requestedArch}->{'newpath'}."/$packOptions->{$requestedArch}->{'newfile'}";
                if ((! -e  $item) && (! link (
                    $packPointer->{'localfile'},
                    "$packOptions->{$requestedArch}->{'newpath'}"
                    ."/$packOptions->{$requestedArch}->{'newfile'}"))) {
                    my $msg = "  linking file $packPointer->{'localfile'} "
                        . "to $packOptions->{$requestedArch}->{'newpath'}/"
                        . "$packOptions->{$requestedArch}->{'newfile'} "
                        . 'failed';
                    $this->logMsg('E', $msg);
                } else {
                    my $lnkTarget =
                        $packOptions->{$requestedArch}->{'newpath'}
                        . "/$packOptions->{$requestedArch}->{'newfile'}";
                    $this->addToTrackFile(
                        $packName, $packPointer, $medium, $lnkTarget
                    );
                    if ($this->{m_debug} >= 4) {
                        my $lnkTarget = $packOptions->{$requestedArch}->{'newpath'};
                        my $msg = "	 linked file $packPointer->{'localfile'}"
                                  ." to $lnkTarget";
                        $this->logMsg('I', $msg);
                    }
                    if ($this->{m_debug} >= 2) {
                        if ($arch eq $requestedArch) {
                            my $msg = "  package $packName found for "
                                . "architecture $arch as $packKey";
                            $this->logMsg('I', $msg);
                        } else {
                            my $msg = "  package $packName found for "
                                . "architecture $arch (fallback of "
                                . "$requestedArch) as $packKey";
                            $this->logMsg('I', $msg);
                        }
                    }
                    if ( $mode == 1 && $packPointer->{sourcepackage} ) {
                        my $srcname = $packPointer->{sourcepackage};
                        # this strips everything, except main name
                        $srcname =~ s/-[^-]*-[^-]*\.rpm$//;

                        if ( $this->{m_srcmedium} > 0 )
                        {
                           my $srcarch = $packPointer->{sourcepackage};
                           $srcarch =~ s{.*\.(.*)\.rpm$}{$1};
                           if (!$this->{m_sourcePacks}->{$srcname}) {
                               # FIXME: add forcerepo here
                               $this->{m_sourcePacks}->{$srcname} = {
                                   'medium' => $this->{m_srcmedium},
                                   'arch' => $srcarch,
                                   'onlyarch' => $srcarch
                               };
                           }
                           # get version-release string
                           $packPointer->{sourcepackage} =~ m/.*-([^-]*-[^-]*)\.[^\.]*\.rpm/;
                           $this->{m_sourcePacks}->{$srcname}->{'requireVersion'}->{$1} = 1;
                        }
                        if ( $this->{m_debugmedium} > 0 ) {
                            # Add debug packages, we do not know,
                            # if they exist at all
                            my $suffix = "";
                            my $basename = $packName;
                            for my $tsuffix (qw(32bit 64bit x86)) {
                                next unless $packName =~ /^(.*)(-$tsuffix)$/;
                                $basename = $1;
                                $suffix = $2;
                                last;
                            }
                            $this->addDebugPackage( $srcname."-debuginfo".$suffix,
                                                    $arch, $packPointer);
                            $this->addDebugPackage(
                                $srcname."-debugsource", $arch,
                                $packPointer);
                                $this->addDebugPackage(
                                $basename."-debuginfo".$suffix,
                                $arch, $packPointer) unless $srcname eq $basename;
                        }
                    }
                }
                $this->addAppdata($packPointer);

                # package processed, jump to the next request arch or package
                next ARCH;
            } # /FARCH
            if ($this->{m_debug} >= 1) {
                my $msg = "    => package $packName not available for "
                    . "$requestedArch nor its fallbacks";
                $this->logMsg('W', $msg);
            }
            push @missingPackages, $packName;
       } # /ARCH
    } # /PACK
    # Ignore missing packages on debug media, they may really not exist
    if ($mode != 3 && @missingPackages > 0) {
        $this->logMsg('W', "MISSING PACKAGES:");
        foreach my $pack(@missingPackages) {
            $this->logMsg('W', "  ".$pack);
        }
        my $opt = 'IGNORE_MISSING_REPO_PACKAGES';
        my $val = $this->{m_proddata}->getOpt($opt);
        if (!defined($val) || $val ne "true") {
            $this->logMsg('E', "Required packages were not found");
        }
    }
    return $retval;
}

#==========================================
# collectPackages
#------------------------------------------
sub collectPackages {
    # ...
    # collect all required packages from any repo.
    # The workflow to do this is separated into steps.
    # each step is implemented as private helper method
    # ---
    my $this = shift;
    my $rfailed = 0;
    my $mfailed = 0;
    # step 1
    # expand dir lists (setup in constructor for each repo) to filenames
    if($this->{m_debug}) {
        $this->logMsg('I', "STEP 1 [collectPackages]" );
        $this->logMsg('I', "expand dir lists for all repositories");
    }
    for my $r(keys(%{$this->{m_repos}})) {
        my $tmp_ref = \%{$this->{m_repos}->{$r}->{'srcdirs'}};
        for my $dir(keys(%{$this->{m_repos}->{$r}->{'srcdirs'}})) {
            # directories are scanned during Init()
            # expandFilenames scans the already known directories for
            # matching filenames, in this case: *.rpm, *.spm
            $tmp_ref->{$dir} = [
                $this->{m_util}->expandFilename(
                $this->{m_browser},
                $this->{m_repos}->{$r}->{'source'}.$dir,
                '.*[.][rs]pm$')
            ];
        }
    }
    # dump files for debugging purposes:
    $this->dumpRepoData("$this->{m_basedir}/repolist.txt");
    # get informations about all available packages.
    my $result = $this->lookUpAllPackages();
    if( $result == -1) {
        $this->logMsg('E', "lookUpAllPackages failed !");
        return 1;
    }
    # Just for nicer output
    $this->{m_repoPacks}->{_name} = { label => "main" };
    $this->{m_sourcePacks}->{_name} = { label => "source" };
    $this->{m_debugPacks}->{_name}  = { label => "debug" };

    # step 2:
    if($this->{m_debug}) {
        $this->logMsg('I', "STEP 2 [collectPackages]" );
        $this->logMsg('I', "Select packages and create links");
    }

    # Setup the package FS layout
    my $setupFiles = $this->setupPackageFiles(1, $this->{m_repoPacks});
    if($setupFiles > 0) {
        my $msg = "[collectPackages] $setupFiles RPM packages could not be "
            . 'setup';
        $this->logMsg('E', $msg);
        return 1;
    }
    if ( $this->{m_srcmedium} > 0 ) {
        $setupFiles = $this->setupPackageFiles(2, $this->{m_sourcePacks});
        if($setupFiles > 0) {
            my $msg = "[collectPackages] $setupFiles SOURCE RPM packages "
                . 'could not be setup';
            $this->logMsg('E', $msg);
            return 1;
        }
    }
    if ( $this->{m_debugmedium} > 0 ) {
        $setupFiles = $this->setupPackageFiles(3, $this->{m_debugPacks});
        if($setupFiles > 0) {
            my $msg = "[collectPackages] $setupFiles DEBUG RPM packages "
                . 'could not be setup';
            $this->logMsg('E', $msg);
            return 1;
        }
    }

    # step 3: NOW I know where you live...
    if($this->{m_debug}) {
        $this->logMsg('I', "STEP 3 [collectPackages]" );
        $this->logMsg('I', "Handle scripts for metafiles and metapackages");
    }
    # unpack metapackages and download metafiles to the {m_united} path
    # (or relative path from there if specified) <- according to rnc file
    # this must not be empty in any case

    # download metafiles to new basedir:
    $this->getMetafileList();

    $this->{m_scriptbase} = "$this->{m_united}/scripts";
    if(!mkpath($this->{m_scriptbase}, { mode => oct(755) } )) {
        my $msg = '[collectPackages] Cannot create script directory!';
        $this->logMsg('E', $msg);
        return 1;
    }

    my @metafiles = sort keys(%{$this->{m_metafiles}});
    if($this->executeMetafileScripts(@metafiles) != 0) {
        my $msg = '[collectPackages] executing metafile scripts failed!';
        $this->logMsg('E', $msg);
        return 1;
    }
    my $descrdir = $this->{m_proddata}->getInfo("DESCRDIR");
    if ($descrdir && $this->{m_appdata}) {
        my $dirbase = "$this->{m_basesubdir}->{1}";
        $this->logMsg('I', "write appdata to $dirbase/$descrdir\n");
        my $XML = FileHandle -> new();
        $XML -> open (">$dirbase/$descrdir/appdata.xml") or die "WHAT";
        print $XML "<?xml version='1.0' ?>\n";
        print $XML "<applications>\n";
        print $XML $this->{m_appdata};
        print $XML "</applications>\n";
        $XML -> close ();
    }
    my $datadir = $this->{m_proddata}->getInfo("DATADIR");
    if ( defined($this->{m_proddata}->getVar("CREATE_REPOMD"))
        && $this->{m_proddata}->getVar("CREATE_REPOMD") eq "true"
        && $this->{m_appdata}) {
        my $dirbase = "$this->{m_basesubdir}->{1}";
        $this->logMsg('I', "write appdata to $dirbase/$datadir/repodata\n");
        my $XML = FileHandle -> new();
        $XML -> open (">$dirbase/$datadir/repodata/appdata.xml") or die "WHAT";
        print $XML "<?xml version='1.0' ?>\n";
        print $XML "<applications>\n";
        print $XML $this->{m_appdata};
        print $XML "</applications>\n";
        $XML -> close ();
    }
    my @packagelist = sort(keys(%{$this->{m_metaPacks}}));
    if($this->unpackMetapackages(@packagelist) != 0) {
        $this->logMsg('E', "[collectPackages] executing scripts failed!");
        return 1;
    }

    # step 4: run scripts for other (non-meta) packages
    # collect support levels for _channel file
    my %supporthash;
    my $supportfile = abs_path($this->{m_xml}->{xmlOrigFile});
    $supportfile =~ s/.kiwi$/.kwd/;
    if ( -e $supportfile ) {
        my $support_fd = FileHandle -> new();
        if (! $support_fd -> open ($supportfile)) {
            $this->logMsg(
                'E', "[collectPackages] failed to read support file!"
            );
            return 1;
        }
        while (my $line = <$support_fd>) {
            $line =~ s/\n$//;
            if ($line =~ /^([^:]*):.*support_([^\\]*)\\n-Kwd:$/) {
                $supporthash{$1} = $2;
            }
        }
        $support_fd -> close();
    }

    # write out the channel files based on the collected rpms
    for my $m (keys($this->{m_reportLog})) {
        my $medium = $this->{m_reportLog}->{$m};
        my $fd;
        if (! open($fd, ">", $medium->{filename})) {
            die "Unable to open report file: $medium->{filename}";
        }
        print $fd "<report>\n";
        for my $entry(sort(keys($medium->{entries}))) {
                                                my $binary = $medium->{entries}->{$entry};
            $this->printTrackLine(
                $fd,
                "    <binary ", $binary, ">".$binary->{'localfile'}."</binary>",
                %supporthash
            );
        }
        print $fd "</report>\n";
        close $fd;
    }
    return 0;
}

#==========================================
# printTrackLine
#------------------------------------------
sub printTrackLine {
    my ($this, $fd, $prefix, $hash, $suffix, %supporthash) = @_;
    print $fd $prefix;
    my $name;
    for my $k(sort(keys($hash))) {
        next if $k eq 'localfile';
        print $fd " ";
        my $attribute = $k."='".$hash->{$k}."'";
        print $fd $attribute;
        $name = $hash->{$k} if $k eq 'name';
    }
    if ( $name && $supporthash{$name} ) {
        print $fd " supportstatus='".$supporthash{$name}."'";
    }
    print $fd $suffix."\n";
    return $this;
}

#==========================================
# addToTrackFile
#------------------------------------------
sub addToTrackFile {
    my ($this, $name, $pkg, $medium, $on_media_path) = @_;
    if (!$this->{m_reportLog}->{$medium}) {
        $this->{m_reportLog}->{$medium}->{filename} = 
            "$this->{m_basesubdir}->{$medium}.report";
    }
    my %hash = (
        "name"       => $name,
        "version"    => $pkg->{version},
        "release"    => $pkg->{release},
        "binaryarch" => $pkg->{arch},
        "buildtime"  => $pkg->{buildtime},
        "disturl"    => $pkg->{disturl},
        "localfile"  => $pkg->{repo}->{origin}.substr(
            $pkg->{localfile}, length($pkg->{repo}->{source})
        )
    );
    if (defined($pkg->{epoch}) && $pkg->{epoch} ne "") {
        $hash{"epoch"} = $pkg->{epoch};
    }
    $this->{m_reportLog}->{$medium}->{entries}->{$on_media_path} = \%hash;
    return $this;
}

#==========================================
# unpackMetapackages
#------------------------------------------
sub unpackMetapackages {
    # ...
    # metafiles and metapackages may have an attribute
    # called 'script' which shall be executed after the packages
    # are gathered.
    # ---
    my @packlist = @_;
    my $this = shift @packlist;
    METAPACKAGE:
    for my $metapack(@packlist) {
        my %packOptions = %{$this->{m_metaPacks}->{$metapack}};
        my $poolPackages = $this->{m_packagePool}->{$metapack};
        my $medium = 1;
        my $nokeep = 0;
        if (defined($packOptions{'medium'})) {
            if($packOptions{'medium'} == 0) {
                $nokeep = 1;
            } else {
                $medium = $packOptions{'medium'};
            }
        }
        # regular handling: unpack, put everything from CD1..CD<n> to
        # cdroot {m_basedir}
        my $tmp = "$this->{m_basesubdir}->{$medium}/temp";
        if(-d $tmp) {
            qx(rm -rf $tmp);
        }
        if (!mkpath("$tmp", { mode => oct(755) } )) {
            $this->logMsg('E', "can't create dir <$tmp>");
            return 1;
        }
        my $nofallback = 0;
        ARCH:
        for my $reqArch (
            $this->getArchList(
                $this->{m_metaPacks}->{$metapack}, $metapack, \$nofallback
            )
        ) {
            if ($reqArch =~ m{(src|nosrc)}) {
                next;
            }
            if (defined($packOptions{$reqArch})) {
                next;
            }
            my @fallbacklist;
            @fallbacklist = ($reqArch);
            if($nofallback==0 ) {
                @fallbacklist = $this->{m_archlist}->fallbacks($reqArch);
                @fallbacklist = ($reqArch) unless @fallbacklist;
                if ($this->{m_debug} >= 6) {
                    $this->logMsg('I', " Look for fallbacks fallbacks");
                }
            }
            if ($this->{m_debug} >= 5) {
                my $msg = '    Use as expanded architectures >'
                    . join(" ", @fallbacklist)
                    . '<';
                $this->logMsg('I', $msg);
            }
            FARCH:
            for my $arch(@fallbacklist) {
                PACKKEY:
                for my $packKey(
                        sort {
                            $poolPackages->{$a}->{priority}
                            <=> $poolPackages->{$b}->{priority}
                        }
                        keys(%{$poolPackages}
                    )
                ) {
                    my $packPointer = $poolPackages->{$packKey};
                    if (!$packPointer->{'localfile'}) {
                        next PACKKEY; # should not be needed
                    }
                    if ($packPointer->{arch} ne $arch) {
                        next PACKKEY;
                    }

                    $this->logMsg('I', "unpack $packPointer->{localfile} ");
                    $this->{m_util}->unpac_package(
                        $packPointer->{localfile}, $tmp
                    );
                    # all metapackages contain at least a CD1 dir and _may_
                    # contain another /usr/share/<name> dir
                    if ( -d "$tmp/CD1") {
                        qx(cp -a $tmp/CD1/* $this->{m_basesubdir}->{$medium});
                    } else {
                        my $msg;
                        $msg = "No CD1 directory on $packPointer->{localfile}";
                        $this->logMsg('W', $msg);
                    }
                    if(-f "$tmp/usr/share/mini-iso-rmlist") {
                        my $RMLIST;
                        if (! open(
                            $RMLIST, '<', "$tmp/usr/share/mini-iso-rmlist")
                        ) {
                            $this->logMsg('W',
                                "cannot open <$tmp/usr/share/mini-iso-rmlist>"
                            );
                        } else {
                            my @rmfiles = <$RMLIST>;
                            chomp(@rmfiles);
                            $this->{m_rmlists}->{$arch} = [@rmfiles];
                            close $RMLIST;
                        }
                    }
                    # copy content of CD2 ... CD<i> subdirs if exists:
                    for (2..10) {
                        if (-d "$tmp/CD$_"
                            and defined $this->{m_basesubdir}->{$_}
                        ) {
                            qx(cp -a $tmp/CD$_/* $this->{m_basesubdir}->{$_});
                            $this->logMsg('I',
                                "Unpack CD$_ for $packPointer->{name} "
                            );
                        }
                    }
                    # THEMING
                    if ($this->{m_debug}) {
                        $this->logMsg('I',
                            "Handling theming for package $metapack"
                        );
                    }
                    my $thema = $this->{m_proddata}->getVar("PRODUCT_THEME");
                    $this->logMsg('I', "\ttarget theme $thema");
                    if(-d "$tmp/SuSE") {
                        my $TD;
                        if (! opendir($TD, "$tmp/SuSE")) {
                            my $msg;
                            $msg = '[unpackMetapackages] Cannot open ';
                            $msg.= "theme directory for reading!\nSkipping ";
                            $msg.= "themes for package $metapack";
                            $this->logMsg('W', $msg);
                            next;
                        }
                        my @themes = readdir $TD;
                        closedir $TD;
                        my $found=0;
                        for my $d(sort(@themes)) {
                            if($d =~ m{$thema}i) {
                                $this->logMsg('I', "Using thema $d");
                                # changed after I saw that yast2-slideshow has
                                # a thema "SuSE-SLES" (matches "SuSE", but not
                                # in line 831)
                                $thema = $d;
                                $found=1;
                                last;
                            }
                        }
                        if($found==0) {
                            for my $d(sort(@themes)) {
                                if($d =~ m{linux|sles|suse}i) {
                                    my $msg;
                                    $msg = "Using fallback theme $d ";
                                    $msg.= "instead of $thema";
                                    $this->logMsg('W', $msg);
                                    $thema = $d;
                                    last;
                                }
                            }
                        }
                        ## $thema is now the thema to use:
                        for my $i(1..3) {
                            # drop not used configs when media does not exist
                            if(-d "$tmp/SuSE/$thema/CD$i"
                                and $this->{m_basesubdir}->{$i}
                                and -d "$tmp/SuSE/$thema/CD$i"
                            ) {
                                my $cmd;
                                $cmd = "cp -a $tmp/SuSE/$thema/CD$i/* ";
                                $cmd.= "$this->{m_basesubdir}->{$i}";
                                qx( $cmd );
                            }
                        }
                    }
                    # handling optional special scripts if given
                    # (``anchor of the last choice'')
                    if($packOptions{'script'}) {
                        my $scriptfile;
                        $packOptions{'script'} =~ m{.*/([^/]+)$};
                        if(defined($1)) {
                            $scriptfile = $1;
                        } else {
                            my $msg;
                            $msg = '[executeScripts] malformed script ';
                            $msg.= "name: $packOptions{'script'}";
                            $this->logMsg('W', $msg);
                            next;
                        }
                        my $info;
                        $info = "Downloading script $packOptions{'script'} ";
                        $info.= "to $this->{m_scriptbase}:";
                        print $info;
                        KIWIGlobals -> instance() -> downloadFile(
                            $packOptions{'script'},
                            "$this->{m_scriptbase}/$scriptfile"
                        );
                        qx(chmod u+x "$this->{m_scriptbase}/$scriptfile");
                        my $msg;
                        $msg = '[executeScripts] Execute script ';
                        $msg.= "$this->{m_scriptbase}/$scriptfile:";
                        $this->logMsg('I', $msg);
                        if (-f "$this->{m_scriptbase}/$scriptfile"
                                and -x "$this->{m_scriptbase}/$scriptfile"
                        ) {
                            my $status = qx($this->{m_scriptbase}/$scriptfile);
                            my $retcode = $? >> 8;
                            print "STATUS:\n$status\n";
                            print "RETURNED:\n$retcode\n";
                        } else {
                            $msg = '[executeScripts] script '
                                . $this->{m_scriptbase}
                                . "/$scriptfile for metapackage $metapack "
                                . 'could not be executed successfully!';
                            $this->logMsg('W', $msg);
                        }
                    } else {
                        $this->logMsg('W',
                            "No script defined for metapackage $metapack");
                    }
                    # found a package, jump to next required arch.
                    next ARCH;
                }
            }
            # Package was not found
            if (!defined(
                $this->{m_proddata}->getOpt("IGNORE_MISSING_META_PACKAGES")
            )|| $this->{m_proddata}->getOpt("IGNORE_MISSING_META_PACKAGES")
                ne "true" 
            ) {
                # abort
                my $msg;
                $msg = "Metapackage <$metapack> not available for ";
                $msg.= "required $reqArch architecture!";
                $this->logMsg('E', $msg);
            }
        }
    }
    # cleanup old files:
    for my $index($this->getMediaNumbers()) {
        if(-d "$this->{m_basesubdir}->{$index}/temp") {
            qx(rm -rf $this->{m_basesubdir}->{$index}/temp);
        }
        if(-d "$this->{m_basesubdir}->{$index}/script") {
            qx(rm -rf $this->{m_basesubdir}->{$index}/script);
        }
    }
    return 0;
}

#==========================================
# executeMetafileScripts
#------------------------------------------
sub executeMetafileScripts {
    my @filelist = @_;
    my $this = shift @filelist;
    my $ret = 0;
    for my $metafile(@filelist) {
        my %tmp = %{$this->{m_metafiles}->{$metafile}};
        if($tmp{'script'}) {
            my $scriptfile;
            $tmp{'script'} =~ m{.*/([^/]+)$};
            if(defined($1)) {
                $scriptfile = $1;
            } else {
                $this->logMsg('W',
                    "[executeScripts] malformed script name: $tmp{'script'}"
                );
                next;
            }
            my $info = "Downloading script $tmp{'script'} to "
                . "$this->{m_scriptbase}:";
            print $info;
            KIWIGlobals -> instance() -> downloadFile(
                $tmp{'script'}, "$this->{m_scriptbase}/$scriptfile"
            );
            qx(chmod u+x "$this->{m_scriptbase}/$scriptfile");
            my $msg;
            $msg = '[executeScripts] Execute script ';
            $msg.= "$this->{m_scriptbase}/$scriptfile:";
            $this->logMsg('I', $msg);
            if (-f "$this->{m_scriptbase}/$scriptfile"
                and -x "$this->{m_scriptbase}/$scriptfile"
            ) {
                my $status = qx($this->{m_scriptbase}/$scriptfile);
                my $retcode = $? >> 8;
                $msg = '[executeScripts] Script '
                    . "$this->{m_scriptbase}/$scriptfile returned "
                    . "with $status($retcode).";
                $this->logMsg('I', );
            } else {
                $msg = '[executeScripts] script '
                    . "$this->{m_scriptbase}/$scriptfile for "
                    . "metafile $metafile could not be executed successfully!";
                $this->logMsg('W', );
            }
        } else {
            $this->logMsg('W',
                "No script defined for metafile $metafile"
            );
        }
    }
    return $ret;
}

#==========================================
# lookUpAllPackages
#------------------------------------------
sub lookUpAllPackages {
    # ...
    # checks all packages for their content.
    # Returns the number of resolved files, or 0 for bad list
    # ---
    my $this = shift;
    my $retval = 0;
    my $packPool = {};
    my $num_repos = keys %{$this->{m_repos}};
    my $count_repos = 0;
    my $last_progress_time = 0;
    REPO:
    for my $r (
        sort {
            $this->{m_repos}->{$a}->{priority}
            <=> $this->{m_repos}->{$b}->{priority}
        } keys(%{$this->{m_repos}})
    ) {
        my $num_dirs = keys %{$this->{m_repos}->{$r}->{'srcdirs'}};
        my $count_dirs = 0;
        $count_repos++;

        DIR:
        for my $d(keys(%{$this->{m_repos}->{$r}->{'srcdirs'}})) {
            my $num_files = @{$this->{m_repos}->{$r}->{'srcdirs'}->{$d}};
            my $count_files = 0;
            $count_dirs++;
            if(! $this->{m_repos}->{$r}->{'srcdirs'}->{$d}->[0]) {
                next DIR;
            }
            URI:
            for my $uri(@{$this->{m_repos}->{$r}->{'srcdirs'}->{$d}}) {
                $count_files++;
                # skip all files without rpm suffix
                next URI unless( $uri =~ /\.rpm$/);
                if ($this->{m_debug} >= 1) {
                    # show progress every 30 seconds
                    if ($last_progress_time < time()) {
                        my $str;
                        $str = (time() - $this->{m_startUpTime}) / 60;
                        $str = sprintf "%.0f", $str;
                        my $msg = 'read package progress: '
                            . "($count_repos/$num_repos | "
                            . "$count_dirs/$num_dirs | "
                            . "$count_files/$num_files) running $str minutes ";
                        $this->logMsg('I', $msg);
                        $last_progress_time = time() + 5;
                    }
                    if ($this->{m_debug} >= 3) {
                        $this->logMsg('I', "read package: $uri ");
                    }
                }
                my %flags = RPMQ::rpmq_many(
                    "$uri",
                    'NAME',
                    'EPOCH',
                    'VERSION',
                    'RELEASE',
                    'ARCH',
                    'SOURCE',
                    'SOURCERPM',
                    'NOSOURCE',
                    'NOPATCH',
                    'DISTURL',
                    'BUILDTIME'
                );
                if(!%flags || !$flags{'NAME'} || !$flags{'RELEASE'}
                    || !$flags{'VERSION'} || !$flags{'RELEASE'}
                ) {
                    my $msg = "[lookUpAllPakcges] Package $uri seems to "
                        . 'have an invalid header or is no rpm at all!';
                    $this->logMsg('W', $msg);
                } else {
                    my $arch;
                    my $name = $flags{'NAME'}[0];
                    if( !$flags{'SOURCERPM'} ) {
                        # we deal with a source rpm...
                        my $srcarch = 'src';
                        if ($flags{'NOSOURCE'} || $flags{'NOPATCH'}) {
                            $srcarch = 'nosrc';
                        }
                        $arch = $srcarch;
                    } else {
                        $arch = $flags{'ARCH'}->[0];
                    }
                    # all data gets assigned, which is needed for setting the
                    # directory structure up.
                    my $package;
                    $package->{'arch'} = $arch;
                    $package->{'repo'} = $this->{m_repos}->{$r};
                    $package->{'localfile'} = $uri;
                    $package->{'disturl'} = $flags{'DISTURL'}[0];
                    if ($flags{'SOURCERPM'}) {
                        my $appdata = $uri;
                        # Old appdata location before OBS 2.5
                        $appdata =~ s,[^/]*$,$name-appdata.xml,;
                        $package->{'appdata'} = $appdata if (-s $appdata);
                        # New appdata location since OBS 2.5.0
                        $appdata =~ s,[^/]*$,../appdata/$name-appdata.xml,;
                        $package->{'appdata'} = $appdata if (-s $appdata);
                    }
                    $package->{'epoch'} = $flags{'EPOCH'}[0];
                    $package->{'version'} = $flags{'VERSION'}[0];
                    $package->{'release'} = $flags{'RELEASE'}[0];
                    $package->{'buildtime'} = $flags{'BUILDTIME'}[0];
                    # needs to be a string or sort breaks later
                    $package->{'priority'} =
                        "$this->{m_repos}->{$r}->{priority}";

                    # We can have a package only once per architecture and in
                    # one repo
                    my $repokey = $r."@".$arch;
                    # BUT src, nosrc and debug packages need to be available
                    # in all versions.
                    if ( !$flags{'SOURCERPM'} || $name =~ /-debugsource$/
                             || $name =~ /-debuginfo$/
                    ) {
                        $repokey .= "@"
                            . $package->{'version'}
                            . "@"
                            . $package->{'release'};
                    }
                    if ( $packPool->{$name}->{$repokey} ) {
                        # we have it already from a more important repo.
                        next;
                    }
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
                    } else {
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

#==========================================
# dumpRepoData
#------------------------------------------
sub dumpRepoData {
    # ...
    # dumps repo metadata collected for debugging
    # purpose to the given target file.
    # ---
    my $this    = shift;
    my $target  = shift;
    my $DUMP = FileHandle -> new();
    if(! $DUMP -> open (">$target")) {
        my $msg = "[dumpRepoData] Dumping data to file $target failed: ";
        $msg .= 'file could not be created!';
        $this->logMsg('E', $msg);
    } else {
        print $DUMP "Dumped data from KIWICollect object\n\n";
        print $DUMP "\n\nKNOWN REPOSITORIES:\n";
        for my $repo(keys(%{$this->{m_repos}})) {
            print $DUMP "\nNAME:\t\"$repo\"\t[HASHREF]\n";
            print $DUMP "\tBASEDIR:\t\"";
            print $DUMP "$this->{m_repos}->{$repo}->{'basedir'}\"\n";
            print $DUMP "\tPRIORITY:\t\"";
            print $DUMP "$this->{m_repos}->{$repo}->{'priority'}\"\n";
            print $DUMP "\tSOURCEDIR:\t\"";
            print $DUMP "$this->{m_repos}->{$repo}->{'source'}\"\n";
            print $DUMP "\tSUBDIRECTORIES:\n";
            for my $srcdir(keys(%{$this->{m_repos}->{$repo}->{'srcdirs'}})) {
                print $DUMP "\t\"$srcdir\"\t[URI LIST]\n";
                my @fls = @{$this->{m_repos}->{$repo}->{'srcdirs'}->{$srcdir}};
                for my $file (@fls) {
                    print $DUMP "\t\t\"$file\"\n";
                }
            }
        }
        $DUMP -> close();
    }
    return 0;
}

#==========================================
# dumpPackageList
#------------------------------------------
sub dumpPackageList {
    # ...
    # dump repo packages for debugging purpose.
    # to the given target file
    # ---
    my $this    = shift;
    my $target  = shift;
    my $DUMP = FileHandle -> new();
    if(! $DUMP -> open(">$target")) {
        my $msg = "[dumpPackageList] Dumping data to file $target failed: ";
        $msg .= 'file could not be created!';
        $this->logMsg('E', $msg);
    }
    print $DUMP "Dumped data from KIWICollect object\n\n";
    print $DUMP "LIST OF REQUIRED PACKAGES:\n\n";
    if(!%{$this->{m_repoPacks}}) {
        $this->logMsg('W', "Empty packages list");
        return;
    }
    for my $pack(keys(%{$this->{m_repoPacks}})) {
        print $DUMP "$pack";
        if(defined($this->{m_repoPacks}->{$pack}->{'priority'})) {
            my $prio = $this->{m_repoPacks}->{$pack}->{'priority'};
            print $DUMP "\t (prio=$prio)\n";
        } else {
            print $DUMP "\n";
        }
    }
    $DUMP -> close();
    return;
}

#==========================================
# getArchList
#------------------------------------------
sub getArchList {
    my $this = shift;
    my $packOptions = shift;
    my $packName = shift;
    my $nofallbackref = shift;
    my @archs = ();
    if (not defined($packName)) {
        return @archs;
    }
    if(defined($packOptions->{'onlyarch'})) {
        # black listed packages
        if ($packOptions->{'onlyarch'} eq "") {
            return @archs;
        }
        if ($packOptions->{'onlyarch'} eq "skipit") {
            return @archs; # convinience for old hack
        }
    }
    @archs = $this->{m_archlist}->headList();
    if(defined($packOptions->{'arch'})) {
        # Check if this is a rule for this platform
        $packOptions->{'arch'} =~ s{,\s*,}{,}g;
        $packOptions->{'arch'} =~ s{,\s*}{,}g;
        $packOptions->{'arch'} =~ s{,\s*$}{};
        $packOptions->{'arch'} =~ s{^\s*,}{};
        @archs = ();
        for my $plattform (split(/,\s*/, $packOptions->{'arch'})) {
            for my $reqArch ($this->{m_archlist}->headList()) {
                if ( $reqArch eq $plattform ) {
                    push @archs, $reqArch;
                }
            }
        }
        if ( @archs == 0 ) {
            # our required plattforms were not found
            # Thus return an empty list
            return @archs;
        }
    }
    if(defined($packOptions->{'onlyarch'})) {
        # reset arch list and limit to onlyarch definition
        @archs = ();
        $packOptions->{'onlyarch'} =~ s{,\s*,}{,}g;
        $packOptions->{'onlyarch'} =~ s{,\s*}{,}g;
        $packOptions->{'onlyarch'} =~ s{,\s*$}{};
        $packOptions->{'onlyarch'} =~ s{^\s*,}{};
        push @archs, split(/,\s*/, $packOptions->{'onlyarch'});
        $$nofallbackref = 1;
        # onlyarch supersedes the following options !
        return @archs;
    }
    if(defined($packOptions->{'addarch'})) {
        # addarch is a modifier, use default list as base
        @archs = $this->{m_archlist}->headList();
        $packOptions->{'addarch'} =~ s{,\s*,}{,}g;
        $packOptions->{'addarch'} =~ s{,\s*}{,}g;
        $packOptions->{'addarch'} =~ s{,\s*$}{};
        $packOptions->{'addarch'} =~ s{^\s*,}{};
        push @archs, split(/,\s*/, $packOptions->{'addarch'});
    }
    if(defined($packOptions->{'removearch'})) {
        # removearch is a modifier, use default list as base
        @archs = $this->{m_archlist}->headList();
        $packOptions->{'removearch'} =~ s{,\s*,}{,}g;
        $packOptions->{'removearch'} =~ s{,\s*}{,}g;
        $packOptions->{'removearch'} =~ s{,\s*$}{};
        $packOptions->{'removearch'} =~ s{^\s*,}{};
        my %omits = map {$_ => 1} split(/,\s*/, $packOptions->{'removearch'});
        @archs = grep {!$omits{$_}} @archs;
    }
    return @archs;
}

#==========================================
# collectProducts
#------------------------------------------
sub collectProducts {
    # ...
    # reads the product data which are on the media
    # ---
    my $this = shift;
    my $xml = XML::LibXML -> new();
    my $tmp = $this->{m_basesubdir}->{0}."/temp";
    if (-d $tmp) {
        qx(rm -rf $tmp);
    }
    # /.../
    # not nice, just look for all -release packages and
    # their content. This will become nicer when we
    # switched to rpm-md as product repo format
    # ---
    my $found_product = 0;
    RELEASEPACK:
    for my $i(grep {$_ =~ /-release$/} keys(%{$this->{m_repoPacks}})) {
        qx(rm -rf $tmp);
        if(!mkpath("$tmp", { mode => oct(755) } )) {
            $this->logMsg('E', "can't create dir <$tmp>");
        }
        my $file;
        # go via all used archs
        my $nofallback = 0;
        for my $arch(
            $this->getArchList( $this->{m_repoPacks}->{$i}, $i, \$nofallback)
        ) {
            if ($this->{m_repoPacks}->{$i}->{$arch}->{'newpath'} eq ""
                || $this->{m_repoPacks}->{$i}->{$arch}->{'newfile'} eq ""
            ) {
                $this->logMsg('I', "Skip product release package $i");
                next RELEASEPACK;
            }
            $file = $this->{m_repoPacks}->{$i}->{$arch}->{'newpath'}
                . "/"
                . $this->{m_repoPacks}->{$i}->{$arch}->{'newfile'};
        }
        $this->logMsg('I',
            "Unpacking product release package $i in file $file ".$tmp);
        $this->{m_util}->unpac_package($file, $tmp);

        # get all .prod files
        local *D;
        if (!opendir(D, $tmp."/etc/products.d/")) {
            $this->logMsg('I', "No products found, skipping");
            next RELEASEPACK;
        }
        my @r = grep {$_ =~ '\.prod$'} readdir(D);
        closedir D;

        # read each product file
        for my $prodfile(@r) {
            my $tree = $xml->parse_file( $tmp."/etc/products.d/".$prodfile );
            my $release = $tree->getElementsByTagName( "release" )
                    ->get_node(1)->textContent();
            my $product_name = $tree->getElementsByTagName( "name" )
                    ->get_node(1)->textContent();
            my $label = $tree->getElementsByTagName( "summary" )
                    ->get_node(1)->textContent();
            my $version = $tree->getElementsByTagName( "version" )
                    ->get_node(1)->textContent();
            my $sp_version;
            if ($tree->getElementsByTagName( "patchlevel" )->get_node(1) ) {
                $sp_version = $tree->getElementsByTagName( "patchlevel" )
                        ->get_node(1)->textContent();
            }
            my $main_product = $this->{m_proddata}->getOpt("MAIN_PRODUCT");
            if ( defined($main_product) && $main_product ne $product_name ) {
                $this->logMsg(
                    'I', "Skip $product_name, main product is $main_product"
                );
                next;
            }
            if ( $found_product ) {
                my $msg = 'ERROR: No handling of multiple products on one '
                    . 'media supported yet (spec for content file missing)!';
                die $msg;
            }
            $found_product = 1;

            # overwrite data with informations from prod file.
            my $msg = 'Found product file, superseding data from config '
                . 'file variables';
            $this->logMsg('I', $msg);
            $this->logMsg('I', "set release to ".$release);
            $this->logMsg('I', "set product name to ".$product_name);
            $this->logMsg('I', "set label to ".$label);
            $this->logMsg('I', "set version to ".$version);
            if ( defined $sp_version ) {
                $this->logMsg('I', "set sp version to ".$sp_version);
            }
            $this->{m_proddata}->setInfo("RELEASE", $release);
            $this->{m_proddata}->setInfo("LABEL", $label);
            $this->{m_proddata}->setVar("PRODUCT_NAME", $product_name);
            $this->{m_proddata}->setVar("PRODUCT_VERSION", $version);
            if ( defined $sp_version ) {
                $this->{m_proddata}->setVar("SP_VERSION", $sp_version);
            }
        }
    }
    qx(rm -rf $tmp);
    return;
}

#==========================================
# createMetadata
#------------------------------------------
sub createMetadata {
    my $this = shift;
    # retrieve a complete list of all loaded plugins
    my %plugins = $this->{m_metacreator}->getPluginList();

    # create required directories if necessary:
    for my $i(keys(%plugins)) {
        my $p = $plugins{$i};
        $this->logMsg('I', "Processing plugin ".$p->name()."");
        my @requireddirs = $p->requiredDirs();
        # this may be a list and each entry may look like "/foo/bar/baz/"
        # in the worst case.
        for my $dir(@requireddirs) {
            # just to be on the safe side: split leading and trailing slashes
            $dir =~ s{^/(.*)/$}{$1};
            my @sublist = split('/', $dir);
            my $curdir = $this->{m_basesubdir}->{1};
            for my $part_dir(@sublist) {
                $curdir .= "/$part_dir";
                $this->{m_dirlist}->{"$curdir"} = 1;
            }
        }
    }
    # that should be all, bit by bit and in order ;)
    $this->createDirectoryStructure();
    #$this->logMsg('I', "Enabling all plugins...");
    #$this->{m_metacreator}->enableAllPlugins();

    $this->logMsg('I', "Executing all plugins...");
    $this->{m_metacreator}->createMetadata();
    # creates the patters file. Rest will follow later

    # Handle plugins

    # moved to beginnig after diffing with autobuild:
    # step 1: ChangeLog file
    my $make_listings = $this->{m_proddata}->getVar("MAKE_LISTINGS");
    unless (defined($make_listings) && $make_listings eq "false") {
        $this->logMsg('I', "Running mk_changelog for base directory");
        my $mk_cl = "/usr/bin/mk_changelog";
        if(! (-f $mk_cl or -x $mk_cl)) {
            my $msg = "[createMetadata] excutable `$mk_cl` not found. Maybe "
                    . 'package `inst-source-utils` is not installed?';
            $this->logMsg('E', $msg);
            return;
        }
        my @data = qx($mk_cl $this->{m_basesubdir}->{'1'});
        my $res = $? >> 8;
        if($res == 0) {
            $this->logMsg('I', "$mk_cl finished successfully.");
        }
        else {
            $this->logMsg(
                'E', "$mk_cl finished with errors: returncode was $res"
            );
        }
        $this->logMsg('I', "[createMetadata] $mk_cl output:");
        foreach(@data) {
            chomp $_;
            $this->logMsg('I', "\t$_");
        }
        @data = ();
    }

    # step 2: media file
    $this->logMsg('I', "Creating media file in all media:");
    my $manufacturer = $this->{m_proddata}->getVar("VENDOR");
    if($manufacturer) {
        my @media = $this->getMediaNumbers();
        for my $n(@media) {
            my $num = $n;
            if ( $this->{m_proddata}->getVar("FLAVOR") eq "ftp"
                or $this->{m_proddata}->getVar("FLAVOR") eq "POOL"
                or $n == $this->{m_debugmedium}
            ) {
                $num = 1;
            }
            my $mediafile = "$this->{m_basesubdir}->{$n}/media.$num/media";
            my $MEDIA = FileHandle -> new();
            if(! $MEDIA -> open (">$mediafile")) {
                $this->logMsg('E', "Cannot create file <$mediafile>");
                return;
            }
            print $MEDIA "$manufacturer\n";
            print $MEDIA qx(date +%Y%m%d%H%M%S);
            if($num == 1) {
                # some specialities for medium number 1: contains a line with
                # the number of media
                if ( $this->{m_proddata}->getVar("FLAVOR") eq "ftp"
                    or $this->{m_proddata}->getVar("FLAVOR") eq "POOL"
                    or $n == $this->{m_debugmedium}
                ) {
                    print $MEDIA "1\n";
                } else {
                    my $set = @media;
                    $set-- if ( $this->{m_debugmedium} >= 2 );
                    print $MEDIA $set."\n";
                }
            }
            $MEDIA -> close();
            my $bfile = "$this->{m_basesubdir}->{$n}/media.$num/build";
            my $BUILD;
            if(! open($BUILD, ">", $bfile)) {
                $this->logMsg('E', "Cannot create file <$bfile>!");
                return;
            }
            print $BUILD $this->{m_proddata}->getVar("BUILD_ID", "0")."\n";
            close $BUILD;
        }
    } else {
        $this->logMsg('E',
            "[createMetadata] required variable \"VENDOR\" not set"
        );
    }

    # step 3: create info.txt for Beta releases.
    $this->logMsg('I', "Handling Beta information on media:");
    my $beta_version = $this->{m_proddata}->getOpt("BETA_VERSION");
    my $summary = $this->{m_proddata}->getVar("PRODUCT_SUMMARY");

    # step 4: fallbacks for pre openSUSE 13.2/SLE 12
    $summary = $this->{m_proddata}->getInfo("LABEL") unless $summary;
    $summary = $this->{m_proddata}->getInfo("SUMMARY") unless $summary;
    if (defined($beta_version)) {
        my $dist_string = $summary." ".${beta_version};
        my $readme_file = "$this->{m_basesubdir}->{'1'}/README.BETA";
        my $info_file   = "$this->{m_basesubdir}->{'1'}/media.1/info.txt";
        if ( -e $readme_file ) {
            if (system(
                    "sed", "-i", "s/BETA_DIST_VERSION/$dist_string/",
                    $readme_file
                ) == 0
            ) {
                if (system("ln", "-sf", "../README.BETA", $info_file) != 0 ) {
                    $this->logMsg('W', "Failed to symlink README.BETA file!");
                }
            } else {
                $this->logMsg('W',
                    "Failed to replace beta version in README.BETA file!"
                );
            }
        } else {
            $this->logMsg('W',
                "No README.BETA file, but beta version is defined!"
            );
        }
    } else {
        unlink("$this->{m_basesubdir}->{'1'}/README.BETA");
    }

    # step 5: products file
    $this->logMsg('I', "Creating products file in all media:");
    my $proddir  = $this->{m_proddata}->getVar("PRODUCT_DIR");
    my $prodname = $this->{m_proddata}->getVar("PRODUCT_NAME");
    my $prodver  = $this->{m_proddata}->getVar("PRODUCT_VERSION");
    my $prodrel  = $this->{m_proddata}->getVar("PRODUCT_RELEASE");
    my $sp_ver   = $this->{m_proddata}->getVar("SP_VERSION");
    $prodrel = $this->{m_proddata}->getInfo("RELEASE") unless defined($prodrel); # old style before 13.2
    $prodrel = "-$prodrel" if defined($prodrel) and $prodrel ne "";
    $prodname =~ s/\ /-/g;
    $prodver .= ".$sp_ver" if defined($sp_ver);
    if (defined($proddir)
        and defined($prodname)
        and defined($prodver)
        and defined($summary)
    ) {
        $summary =~ s{\s+}{-}g; # replace space(s) by a single dash
        for my $n($this->getMediaNumbers()) {
            my $num = $n;
            if ( $this->{m_proddata}->getVar("FLAVOR") eq "ftp"
                or $this->{m_proddata}->getVar("FLAVOR") eq "POOL"
                or $n == $this->{m_debugmedium}
            ) {
                $num = 1;
            }
            my $productsfile =
                "$this->{m_basesubdir}->{$n}/media.$num/products";
            my $PRODUCT;
            if(! open($PRODUCT, ">", $productsfile)) {
                die "Cannot create $productsfile";
            }
            print $PRODUCT "$proddir $summary $prodver$prodrel\n";
            close $PRODUCT;
        }
    } else {
        my $msg;
        $msg = '[createMetadata] one or more of the following  variables ';
        $msg.= 'are missing: PRODUCT_DIR|PRODUCT_NAME|PRODUCT_VERSION|LABEL';
        $this->logMsg('E', $msg);
    }
    $this->createBootPackageLinks();

    # step 6: LISTINGS
    unless (defined($make_listings) && $make_listings eq "false") {
        $this->logMsg('I', "Calling mk_listings:");
        my $listings = "/usr/bin/mk_listings";
        if(! (-f $listings or -x $listings)) {
            my $msg = "[createMetadata] excutable `$listings` not found. "
                . 'Maybe package `inst-source-utils` is not installed?';
            $this->logMsg('W', $msg);
            return;
        }
        my $cmd = "$listings ".$this->{m_basesubdir}->{'1'};
        my @data = qx($cmd);
        undef $cmd;
        $this->logMsg('I', "[createMetadata] $listings output:");
        for my $item (@data) {
            chomp $item;
            $this->logMsg('I', "\t$item");
        }
        @data = (); # clear list
    }
    my $datadir = $this->{m_proddata}->getInfo("DATADIR");
    my $descrdir = $this->{m_proddata}->getInfo("DESCRDIR");
    my $create_repomd;
    if ( defined($this->{m_proddata}->getVar("CREATE_REPOMD"))
        && $this->{m_proddata}->getVar("CREATE_REPOMD") eq "true"
    ) {
        $create_repomd = 1;
    }
    if(! defined($datadir)) {
        $this->logMsg('E', "variables DATADIR is missing");
        die "MISSING VARIABLES!";
    }
    if((! defined($descrdir)) && !$create_repomd) {
        $this->logMsg(
            'E', "variables DESCRDIR is missing and CREATE_REPOMD is not set"
        );
        die "MISSING VARIABLES!";
    }
    
    # step 7: SHA1SUMS
    $this->logMsg('I', "Calling create_sha1sums:");
    my $csha1sum = "/usr/bin/create_sha1sums";
    my $s1sum_opts = $this->{m_proddata}->getVar("SHA1OPT");
    if (! defined($s1sum_opts)) {
        $s1sum_opts = "";
    }
    if (! (-f $csha1sum or -x $csha1sum)) {
        my $msg;
        $msg = "[createMetadata] excutable `$csha1sum` not found. ";
        $msg.= 'Maybe package `inst-source-utils` is not installed?';
        $this->logMsg('E', $msg);
        return;
    }
    for my $sd($this->getMediaNumbers()) {
        my @data = qx($csha1sum $s1sum_opts $this->{m_basesubdir}->{$sd});
        if ($? >> 8 != 0) {
            $this->logMsg('E', "[createMetadata] $csha1sum failed");
        }else{
            $this->logMsg('I', "[createMetadata] $csha1sum output:");
        }
        for my $item (@data) {
            chomp $item;
            $this->logMsg('I', "\t$item");
        }
    }

    # skip the rest if we are not creating susetags
    return unless $descrdir;

    ## step 8: DIRECTORY.YAST FILES
    $this->logMsg('I', "Calling create_directory.yast:");
    my $dy = "/usr/bin/create_directory.yast";
    if (! (-f $dy or -x $dy)) {
        my $msg;
        $msg = "[createMetadata] excutable `$dy` not found. ";
        $msg.= 'Maybe package `inst-source-utils` is not installed?';
        $this->logMsg('W', $msg);
        return;
    }
    for my $d($this->getMediaNumbers()) {
        my $dbase = $this->{m_basesubdir}->{$d};
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
        if(defined $descrdir) {
            push @dlist, "$dbase/$descrdir";
        }
        for my $item (@dlist) {
            if(-d $item) {
                my @data = qx($dy $item);
                $this->logMsg(
                    'I',"[createMetadata] $dy output for directory $item:"
                );
                for my $entry (@data) {
                    chomp $entry;
                    $this->logMsg('I', "\t$entry");
                }
            }
        }
    }
    return;
}

#==========================================
# unpackModules
#------------------------------------------
sub unpackModules {
    my $this = shift;
    my $tmp_dir = "$this->{m_basesubdir}->{'1'}/temp";
    if(-d $tmp_dir) {
        qx(rm -rf $tmp_dir);
    }
    if(!mkpath("$tmp_dir", { mode => oct(755) } )) {
        $this->logMsg('E', "can't create dir <$tmp_dir>");
        return;
    }
    my @modules;
    my $modsref = $this->{m_xml} -> getDUDModulePackages();
    for my $package (@{$modsref}) {
        my $name = $package -> getName();
        push @modules,$name;
    }
    my %targets = %{$this->{m_xml}->getDUDArchitectures()};
    my %target_archs = reverse %targets; # values of this hash are not used

    # So far DUDs only have one single medium
    my $medium = 1;
    
    # unpack module packages to temp dir for the used architectures
    for my $arch (keys(%target_archs)) {
        my $arch_tmp_dir = "$tmp_dir/$arch";

        for my $module (@modules) {
            my $pack_file = $this->getBestPackFromRepos($module, $arch)
                    ->{'localfile'};
            $this->logMsg('I', "Unpacking $pack_file to $arch_tmp_dir/");
            $this->{m_util}->unpac_package($pack_file, "$arch_tmp_dir");
        }
    }
    # copy modules from temp dir to targets
    foreach my $target (keys(%targets)) {
        my $arch = $targets{$target};
        my $arch_tmp_dir = "$tmp_dir/$arch";
        my $target_dir = $this->{m_basesubdir}->{$medium}
            . "/linux/suse/$target/modules/";
        my @kos = split /\n/, qx(find $arch_tmp_dir -iname "*.ko");
        foreach my $ko (@kos) {
            $this->logMsg('I', "Copying module $ko to $target_dir");
            qx(mkdir -p $target_dir && cp $ko $target_dir);
        }
    }
    return;
}

#==========================================
# getBestPackFromRepos
#------------------------------------------
sub getBestPackFromRepos {
    my $this = shift;
    my $pkg_name = shift;
    my $arch = shift;

    my $pkg_pool = $this->{m_packagePool};
    my $pkg_repos = $pkg_pool->{$pkg_name};

    for my $repo (sort{
        $pkg_repos->{$a}->{priority}
        <=> $pkg_repos->{$b}->{priority}}
                    keys(%{$pkg_repos})
    ) {
        if ($pkg_repos->{$repo}->{arch} eq $arch) {
            return $pkg_repos->{$repo};
        }
    }
    return;
}

#==========================================
# unpackInstSys
#------------------------------------------
sub unpackInstSys {
    my $this = shift;
    my $tmp_dir = "$this->{m_basesubdir}->{'1'}/temp";
    if(-d $tmp_dir) {
        qx(rm -rf $tmp_dir);
    }
    if(!mkpath("$tmp_dir", { mode => oct(755) } )) {
        $this->logMsg('E', "can't create dir <$tmp_dir>");
        return;
    }
    my @inst_sys_packages = ();
    my $packref = $this->{m_xml} -> getDUDInstallSystemPackages();
    for my $package (@{$packref}) {
        my $name = $package -> getName();
        push @inst_sys_packages,$name;  
    }
    my %targets = %{$this->{m_xml}->getDUDArchitectures()};
    my %target_archs = reverse %targets;

    # So far DUDs only have one single medium
    my $medium = 1;
    
    # unpack module packages to temp dir for the used architectures
    foreach my $arch (keys(%target_archs)) {
        my $repo = "repository_1\@$arch";
        my $arch_tmp_dir = "$tmp_dir/$arch";

        foreach my $module (@inst_sys_packages) {
            my $pack_file =
                $this->getBestPackFromRepos($module, $arch)->{'localfile'};
            $this->logMsg('I', "Unpacking $pack_file to $arch_tmp_dir");
            $this->{m_util}->unpac_package($pack_file, "$arch_tmp_dir");
        }
    }
    # copy inst_sys_packages from temp dir to targets
    foreach my $target (keys(%targets)) {
        my $arch = $targets{$target};
        my $arch_tmp_dir = "$tmp_dir/$arch";
        my $target_dir = $this->{m_basesubdir}->{$medium}
            . "/linux/suse/$target/inst-sys/";
        qx(cp -a $arch_tmp_dir $target_dir);
    }
    return;
}

#==========================================
# createInstallPackageLinks
#------------------------------------------
sub createInstallPackageLinks {
    my $this = shift;
    if (! ref $this ) {
        return;
    }
    print Dumper($this->{m_repoPacks});

    # So far DUDs only have one single medium
    my $medium = 1;

    my $retval = 0;
    my @packlist = ();
    my $packref = $this->{m_xml} -> getDUDInstallSystemPackages();
    my $modsref = $this->{m_xml} -> getDUDModulePackages();
    for my $package (@{$modsref}) {
        my $name = $package -> getName();
        push @packlist,$name;
    }
    for my $package (@{$packref}) {
        my $name = $package -> getName();
        push @packlist,$name;
    }
    my %targets = %{$this->{m_xml}->getDUDArchitectures()};
    for my $target (keys(%targets)) {
        my $arch = $targets{$target};
        my $target_dir = "$this->{m_basesubdir}->{$medium}"
            . "/linux/suse/$target/install/";
        qx(mkdir -p $target_dir) unless -d $target_dir;
        my @fallback_archs = $this->{m_archlist}->fallbacks($arch);
        RPM:
        for my $rpmname (@packlist) {
            if((! defined($rpmname))
                || (! defined($this->{m_repoPacks}->{$rpmname}))
            ) {
                my $msg = 'something wrong with rpmlist: undefined value '
                    . "$rpmname";
                $this->logMsg('W', $msg);
                next RPM;
            }
            FARCH:
            for my $fallback_arch (@fallback_archs) {
                my $pPointer = $this->{m_repoPacks}->{$rpmname};
                my $file = $pPointer->{$arch}->{'newpath'}
                    . "/"
                    . $pPointer->{$fallback_arch}->{'newfile'};
                next FARCH unless (-e $file);
                link($file,
                    "$target_dir/".$pPointer->{$fallback_arch}->{'newfile'}
                );
                if ($this->{m_debug} > 2) {
                    my $msg = "linking $file to $target_dir/"
                        . $pPointer->{$fallback_arch}->{'newfile'};
                    $this->logMsg('I', $msg);
                }
                $retval++;
                next RPM;
            }
        }
    }
    return $retval;
}

#==========================================
# createBootPackageLinks
#------------------------------------------
sub createBootPackageLinks {
    my $this = shift;
    if (! ref $this ) {
        return;
    }
    my $base = $this->{m_basesubdir}->{'1'};
    my $datadir = $this->{m_proddata}->getInfo('DATADIR');
    my $retval = 0;
    if(! -d "$base/boot") {
        my $msg;
        $msg = 'There is no /boot subdirectory. This may be ok for some ';
        $msg.= 'media, but might indicate errors in metapackages!';
        $this->logMsg('W', $msg);
        return $retval;
    }
    my %rpmlist_files;
    find( sub { rpmlist_find_cb($this, \%rpmlist_files) }, "$base/boot");
    my $RPMLIST;
    for my $arch(keys(%rpmlist_files)) {
        $RPMLIST = FileHandle -> new();
        if(! $RPMLIST -> open($rpmlist_files{$arch})) {
            $this->logMsg('W',
                "can not open file $base/boot/$arch/$rpmlist_files{$arch}!");
            return -1;
        } else {
            RPM:
            while (my $rpmname = <$RPMLIST>) {
                chomp $rpmname;
                if((! defined($rpmname))
                    || (! defined($this->{m_repoPacks}->{$rpmname}))
                ) {
                    $this->logMsg('W',
                        "rpmlist is wrong: undefined value $rpmname"
                    );
                    next RPM;
                }
                # HACK: i586 is hardcoded as i386 in boot loader
                my $targetarch = $arch;
                if ( $arch eq 'i386' ) {
                    $targetarch = "i586";
                }
                # End of hack
                my @fallb = $this->{m_archlist}->fallbacks($targetarch);
                FARCH:
                for my $fa(@fallb) {
                    my $pPointer = $this->{m_repoPacks}->{$rpmname};
                    my $file = $pPointer->{$targetarch}->{'newpath'}
                        . "/"
                        . $pPointer->{$targetarch}->{'newfile'};
                    next FARCH unless (-e $file);
                    link($file, "$base/boot/$arch/$rpmname.rpm");
                    if ($this->{m_debug} > 2) {
                        my $msg = "linking $file to "
                            . "$base/boot/$arch/$rpmname.rpm";
                        $this->logMsg('I', $msg);
                    }
                    $retval++;
                    next RPM;
                }
            }
        }
    }
    $RPMLIST -> close() if ($RPMLIST);
    return $retval;
}

#==========================================
# rpmlist_find_cb
#------------------------------------------
sub rpmlist_find_cb {
    my $this = shift;
    if (! ref $this ) {
        return;
    }
    my $listref = shift;
    if (! defined $listref ) {
        return;
    }
    if($File::Find::name =~ m{.*/([^/]+)/rpmlist}) {
        $listref->{$1} = $File::Find::name;
    }
    return;
}

#==========================================
# createDirecotryStructure
#------------------------------------------
sub createDirectoryStructure {
    # ...
    # Creates directory structure for install media
    # Possible return value are:
    #
    # 0 => directory exists
    # 1 => directory must be created
    # 2 => an error occured at creation
    # ---
    my $this = shift;
    my %dirs = %{$this->{m_dirlist}};
    my $errors = 0;
    for my $d(keys(%dirs)) {
        if ($dirs{$d} == 0) {
            next;
        }
        if(-d $d) {
            $dirs{$d} = 0;
        } elsif (!mkpath($d, { mode => oct(755) } )) {
            $this->logMsg('E',
                "createDirectoryStructure: can't create directory $d!"
            );
            $dirs{$d} = 2;
            $errors++;
        } else {
            if ($this->{m_debug}) {
                $this->logMsg('I', "created directory $d");
            }
            $dirs{$d} = 0;
        }
    }
    if($errors) {
        $this->logMsg('E',
            "createDirectoryStructure failed. Abort recommended."
        );
    }
    return $errors;
}

#==========================================
# getMediaNumbers
#------------------------------------------
sub getMediaNumbers {
    # ...
    # Returns a list containing all the media involved in a
    # product. Each number is only reported once. The list
    # is allowed to contain leaks like (1,2,5,6)
    # ---
    my $this = shift;
    if (! defined $this) {
        return;
    }
    my @media = (1);
    if ( $this->{m_srcmedium} > 1 ) {
        push @media, $this->{m_srcmedium};
    }
    if ( $this->{m_debugmedium} > 1 ) {
        push @media, $this->{m_debugmedium};
    }
    for my $p(values(%{$this->{m_repoPacks}}),
        values(%{$this->{m_metapackages}})
    ) {
        if(defined($p->{'medium'}) and $p->{'medium'} != 0) {
            push @media, $p->{medium};
        }
    }
    my @ordered = sort(KIWIUtil::unify(@media));
    return @ordered;
}

1;
