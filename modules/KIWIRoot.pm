#================
# FILE          : KIWIRoot.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to initialize and install
#               : the chroot system of the image
#               :
#               :
# STATUS        : Development
#----------------
package KIWIRoot;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use File::Glob ':glob';
use File::Find;
use FileHandle;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIConfigure;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIManagerApt;
use KIWIManagerEnsconce;
use KIWIManagerSmart;
use KIWIManagerYum;
use KIWIManagerZypper;
use KIWIOverlay;
use KIWIProfileFile;
use KIWIQX;
use KIWIURL;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create a new KIWIRoot object which is used for
    # setting up a physical extend. In principal the root
    # object creates a chroot environment including all
    # packages which makes the image
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Module Parameters
    #------------------------------------------
    my $xml          = shift;
    my $imageDesc    = shift;
    my $selfRoot     = shift;
    my $baseSystem   = shift;
    my $useRoot      = shift;
    my $addPacks     = shift;
    my $delPacks     = shift;
    my $cacheRoot    = shift;
    my $targetArch   = shift;
    my $cmdL         = shift;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    my $code;
    if (($imageDesc !~ /^\//) && (! -d $imageDesc)) {
        $imageDesc = $this->{gdata}->{System}."/".$imageDesc;
    }
    if (! defined $baseSystem) {
        $kiwi -> error ("No base system path specified");
        $kiwi -> failed ();
        return;
    }
    if (! defined $xml) {
        $kiwi -> error ("No XML tree specified");
        $kiwi -> failed ();
        return;
    }
    if (! defined $imageDesc) {
        $kiwi -> error ("No image path specified");
        $kiwi -> failed ();
        return;
    }
    my $repos = $xml -> getRepositories();
    if (! $repos) {
        $kiwi -> error ("No repository specified in XML tree");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Get configured name of package manager
    #------------------------------------------
    $kiwi -> info ("Setting up package manager: ");
    my $pmgr = $xml -> getPreferences() -> getPackageManager();
    if (! defined $pmgr) {
        $kiwi -> failed();
        $this -> cleanMount();
        return;
    }
    $kiwi -> note ($pmgr);
    $kiwi -> done ();
    #==========================================
    # Create sourceChannel hash
    #------------------------------------------
    my $count = 1;
    my %sourceChannel = ();
    for my $repo (@{$repos}) {
        my $alias        = $repo -> getAlias();
        my $comp         = $repo -> getComponents();
        my $dist         = $repo -> getDistribution();
        my $imgincl      = $repo -> getImageInclude();
        my $plic         = $repo -> getPreferLicense();
        my $prio         = $repo -> getPriority();
        my $type         = $repo -> getType();
        my $source       = $repo -> getPath();
        my ($user, $pwd) = $repo -> getCredentials();
        $kiwi -> info ("Setting up source channel:\n");
        $kiwi -> info ("--> $source\n");
        #==========================================
        # Set default repotype if not set
        #------------------------------------------
        if (! $type) {
            $kiwi -> warning ("--> Repository type set to: ");
            if ($pmgr ne "zypper") {
                $kiwi -> note ("rpm-md\n");
                $type = "rpm-md";
            } else {
                $kiwi -> note ("AutoDetect\n");
                $type = "NONE";
            }
        }
        #==========================================
        # Validate given URI for access and type
        #------------------------------------------
        my $urlHandler  = KIWIURL -> new ($cmdL,$this,$user,$pwd);
        my $publics_url = $urlHandler -> normalizePath ($source);
        if ($publics_url =~ /^\//) {
            my ( $publics_url_test ) = bsd_glob ( $publics_url );
            if (! -d $publics_url_test) {
                $kiwi ->warning (
                    "--> local URL path not found: $publics_url_test"
                );
                $kiwi ->skipped ();
                next;
            }
        }
        my $private_url = $publics_url;
        if ($private_url =~ /^\//) {
            $private_url = $baseSystem.$private_url;
        }
        my $publics_type = $urlHandler -> getRepoType();
        if (($publics_type ne "unknown") && ($publics_type ne $type)) {
            $kiwi -> warning (
                "--> overwrite repo type $type with: $publics_type"
            );
            $kiwi -> done();
            $type = $publics_type;
        }
        #==========================================
        # build channel name/alias...
        #------------------------------------------
        my $channel = $alias;
        if (! $channel) {
            $channel = $publics_url;
            $channel =~ s/\//_/g;
            $channel =~ s/_\$//g;
            $channel =~ s/^_//;
            $channel =~ s/_$//;
            $channel =~ s/\?.*//;
        }
        #==========================================
        # build source key...
        #------------------------------------------
        my $srckey  = "baseurl";
        my $srcopt;
        if (($type) && ($type =~ /rpm-dir|deb-dir/)) {
            $srckey = "path";
            $srcopt = "recursive=True";
        }
        $private_url = "'".$private_url."'";
        $publics_url = "'".$publics_url."'";

        my @private_options = ("type=$type","name=$channel",
            "$srckey=$private_url",$srcopt
        );
        my @public_options  = ("type=$type","name=$channel",
            "$srckey=$publics_url",$srcopt
        );

        if (($prio) && ($prio != 0)) {
            push (@private_options,"priority=$prio");
            push (@public_options ,"priority=$prio");
        }
        push (@private_options,"-y");
        push (@public_options ,"-y");
        $sourceChannel{private}{$channel} = \@private_options;
        $sourceChannel{public}{$channel}  = \@public_options;
        $sourceChannel{$channel}{license} = 0;
        $sourceChannel{$channel}{imgincl} = 0;
        if (($plic) && ("$plic" eq "true")) {
            $sourceChannel{$channel}{license} = 1;
        }
        if (($imgincl) && ("$imgincl" eq "true")) {
            $kiwi -> info ("Retain $channel\n");
            $sourceChannel{$channel}{imgincl} = 1;
        }
        #==========================================
        # set distribution name tag
        #------------------------------------------
        if ($dist) {
            $sourceChannel{$channel}{distribution} = $dist;
        }
        #==========================================
        # set components
        #------------------------------------------
        if ($comp) {
            $sourceChannel{$channel}{components} = $comp;
        }
        $count++;
    }
    #==========================================
    # Store object data
    #------------------------------------------
    my $global = KIWIGlobals -> instance();
    $this->{kiwi}          = $kiwi;
    $this->{sourceChannel} = \%sourceChannel;
    $this->{xml}           = $xml;
    $this->{imageDesc}     = $imageDesc;
    $this->{selfRoot}      = $selfRoot;
    $this->{baseSystem}    = $baseSystem;
    $this->{useRoot}       = $useRoot;
    $this->{addPacks}      = $addPacks;
    $this->{delPacks}      = $delPacks;
    $this->{cacheRoot}     = $cacheRoot;
    $this->{gdata}         = $global -> getKiwiConfig();
    #==========================================
    # check channel count
    #------------------------------------------
    if ($count == 1) {
        $kiwi -> error  ("No Channels left");
        $kiwi -> failed ();
        $this -> cleanMount();
        return;
    }
    #==========================================
    # Create root directory
    #------------------------------------------
    my $locator = KIWILocator -> instance ();
    my $root = $locator -> createTmpDirectory (
        $useRoot,$selfRoot,$cmdL
    );
    if ( ! defined $root ) {
        $kiwi -> error ("Couldn't create root directory");
        $kiwi -> failed ();
        $this -> cleanMount();
        return;
    }
    #==========================================
    # Check for overlay structure
    #------------------------------------------
    $this->{root}     = $root;
    $this->{origtree} = $root;
    $this->{overlay}  = KIWIOverlay -> new ($root,$cacheRoot);
    if (! $this->{overlay}) {
        $this -> cleanMount();
        return;
    }
    $root = $this->{overlay} -> mountOverlay();
    if (! -d $root) {
        $this -> cleanMount();
        return;
    }
    $this->{root} = $root;
    #==========================================
    # Mark new root directory as broken
    #------------------------------------------
    KIWIQX::qxx ("touch $root/.broken 2>&1");
    #==========================================
    # Set root log file
    #------------------------------------------
    if (! $cmdL -> getLogFile()) {
        if (-e $this->{origtree}) {
            $kiwi -> setRootLog ($this->{origtree}."."."$$".".screenrc.log");
        } else {
            $kiwi -> setRootLog ($root."."."$$".".screenrc.log");
        }
    }
    #==========================================
    # Create package manager object
    #------------------------------------------
    my $manager;
    if ($pmgr eq "zypper") {
        $manager = KIWIManagerZypper -> new (
            $xml,\%sourceChannel,$root,$pmgr,$targetArch
        );
    } elsif ($pmgr eq "smart") {
        $manager = KIWIManagerSmart -> new (
            $xml,\%sourceChannel,$root,$pmgr,$targetArch
        );
    } elsif ($pmgr eq "yum") {
        $manager = KIWIManagerYum -> new (
            $xml,\%sourceChannel,$root,$pmgr,$targetArch
        );
    } elsif ($pmgr eq "ensconce") {
        $manager = KIWIManagerEnsconce -> new (
            $xml,\%sourceChannel,$root,$pmgr,$targetArch
        );
    } elsif ($pmgr eq "apt-get") {
        $manager = KIWIManagerApt -> new (
            $xml,\%sourceChannel,$root,$pmgr,$targetArch
        );
    } else {
        $kiwi -> error ("No package manager backend found for $pmgr");
        $kiwi -> failed ();
        $this -> cleanMount();
        return;
    }
    if (! defined $manager) {
        $this -> cleanMount();
        return;
    }
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{manager} = $manager;
    $this->{cmdL}    = $cmdL;
    return $this;
}

#==========================================
# getRootPath
#------------------------------------------
sub getRootPath {
    # ...
    # Return chroot path for this image
    # ---
    my $this = shift;
    return $this->{root};
}

#==========================================
# cleanBroken
#------------------------------------------
sub cleanBroken {
    # ...
    # Remove the .broken indicator to allow
    # use of this root path for image creation
    # ---
    my $this = shift;
    my $root = $this->{root};
    unlink $root."/.broken";
    return $this;
}

#==========================================
# copyBroken
#------------------------------------------
sub copyBroken {
    # ...
    # copy the current logfile contents into
    # the .broken file below the root tree which
    # is indicated to be broken for some reason
    # mentioned in the log file
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $root = $this->{root};
    my $log  = $kiwi->getRootLog(); 
    if (-f $log) {
        KIWIQX::qxx ("cp $log $root/.broken 2>&1");
    }
    return $this;
}

#==========================================
# init
#------------------------------------------
sub init {
    # ...
    # Initialize root system. The method will create a secured
    # tmp directory and extract all the given base files.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $root = $this->{root};
    my $cmdL = $this->{cmdL};
    my $manager    = $this->{manager};
    my $baseSystem = $this->{baseSystem};
    my $FD;
    #==================================
    # Create /etc/ImageVersion file
    #----------------------------------
    my $packager = $xml -> getPreferences() -> getPackageManager();
    my $imageVersionFile = "$root/etc/ImageVersion";
    my $imageVersion = $xml -> getPreferences() -> getVersion();
    my $imageName    = $xml -> getImageName();
    KIWIQX::qxx ("mkdir -p $root/etc");
    KIWIQX::qxx ("chown root:root $root/etc");
    if ( ! open ($FD, '>', "$imageVersionFile")) {
        $kiwi -> error ("Failed to create version file: $!");
        $kiwi -> failed ();
        return;
    }
    print $FD $imageName."-".$imageVersion;
    close $FD;
    #==================================
    # Copy helper scripts to new root
    #----------------------------------
    KIWIQX::qxx ("cp $this->{gdata}->{KConfig} $root/.kconfig 2>&1");
    #==================================
    # Return early if existing root
    #----------------------------------
    my $forceBootStrap = $cmdL -> getForceBootstrap();
    if ($cmdL -> getRecycleRootDir()) {
        # return unless bootstrapping is enforced
        if (! $forceBootStrap) {
            return $this;
        }
    }
    #==================================
    # make sure DNS/proxy works
    #----------------------------------
    # need resolv.conf/hosts for internal chroot name resolution
    KIWIQX::qxx ("cp /etc/resolv.conf $root/etc 2>&1");
    KIWIQX::qxx ("cp /etc/hosts $root/etc 2>&1");
    # need /etc/sysconfig/proxy for internal chroot proxy usage
    KIWIQX::qxx ("mkdir -p $root/etc/sysconfig 2>&1");
    KIWIQX::qxx ("cp /etc/sysconfig/proxy $root/etc/sysconfig 2>&1");
    #==================================
    # Return early if cache is used
    #----------------------------------
    if (($cmdL-> getCacheDir()) && (! $cmdL->getOperationMode("initCache"))) {
        return $this;
    }
    #==========================================
    # Get base Package list
    #------------------------------------------
    my @initPacs;
    my $bootstrapPacks = $xml -> getBootstrapPackages();
    for my $package (@{$bootstrapPacks}) {
        my $name = $package -> getName();
        push @initPacs, $name;
    }
    if ((! @initPacs) && ($packager ne "apt-get")) {
        $kiwi -> error ("Couldn't create base package list");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Check and set lock
    #------------------------------------------
    $manager -> checkExclusiveLock();
    $manager -> setLock();
    #==========================================
    # Setup preperation checks
    #------------------------------------------
    $manager -> switchToLocal();
    if (! $manager -> setupSignatureCheck()) {
        $manager -> freeLock();
        return;
    }
    if (! $manager -> setupExcludeDocs()) {
        $manager -> freeLock();
        return;
    }
    #==================================
    # Copy/touch some defaults files
    #----------------------------------
    $kiwi -> info ("Creating default template files for new root system");
    if (! defined $this->{cacheRoot}) {
        KIWIQX::qxx ("mkdir -p $root/dev");
        KIWIQX::qxx ("chown root:root $root/dev");
        KIWIQX::qxx ("mkdir -m 755 -p $root/proc");
        KIWIQX::qxx ("chown root:root $root/proc");
        KIWIQX::qxx ("mkdir -m 755 -p $root/dev/pts");
        KIWIQX::qxx ("mknod -m 666 $root/dev/null c 1 3");
        KIWIQX::qxx ("mknod -m 666 $root/dev/zero c 1 5");
        KIWIQX::qxx ("mknod -m 622 $root/dev/full c 1 7");
        KIWIQX::qxx ("mknod -m 666 $root/dev/random c 1 8");
        KIWIQX::qxx ("mknod -m 644 $root/dev/urandom c 1 9");
        KIWIQX::qxx ("mknod -m 666 $root/dev/tty c 5 0");
        KIWIQX::qxx ("mknod -m 666 $root/dev/ptmx c 5 2");
        KIWIQX::qxx ("ln -s /proc/self/fd $root/dev/fd");
        KIWIQX::qxx ("ln -s fd/2 $root/dev/stderr");
        KIWIQX::qxx ("ln -s fd/0 $root/dev/stdin");
        KIWIQX::qxx ("ln -s fd/1 $root/dev/stdout");
        KIWIQX::qxx ("mknod -m 640 $root/dev/loop0 b 7 0");
        KIWIQX::qxx ("mknod -m 640 $root/dev/loop1 b 7 1");
        KIWIQX::qxx ("mknod -m 640 $root/dev/loop2 b 7 2");
        KIWIQX::qxx ("mknod -m 640 $root/dev/loop3 b 7 3");
        KIWIQX::qxx ("mkdir -p $root/etc/sysconfig");
        KIWIQX::qxx ("mkdir -m 755 -p $root/var");
        KIWIQX::qxx ("chown root:root $root/var");
        KIWIQX::qxx ("mkdir -m 755 -p $root/run");
        KIWIQX::qxx ("chown root:root $root/run");
        KIWIQX::qxx ("ln -s /run $root/var/run");
        # for zypper we need a yast log dir
        if ($packager eq "zypper") {
            KIWIQX::qxx ("mkdir -p $root/var/log/YaST2");
        }
        # for smart we need the dpkg default file
        if ($packager eq "smart") {
            KIWIQX::qxx ("mkdir -p $root/var/lib/dpkg");
            KIWIQX::qxx ("touch $root/var/lib/dpkg/status");
            KIWIQX::qxx ("mkdir -p $root/var/lib/dpkg/updates");
            KIWIQX::qxx ("touch $root/var/lib/dpkg/available");
        }
        # for building in suse autobuild we need the following file
        if (-f '/.buildenv') {
            KIWIQX::qxx ("touch $root/.buildenv");
        }
        # need sysconfig/bootloader to make post scripts happy
        KIWIQX::qxx ("touch $root/etc/sysconfig/bootloader");
    }
    # need user/group files as template
    my $groupTemplate = "/etc/group"; 
    my $paswdTemplate = "/etc/passwd";
    # search for template files, add paths for different distros here
    my @searchPWD = (
        "/var/adm/fillup-templates/passwd.aaa_base"
    );
    my @searchGRP = (
        "/var/adm/fillup-templates/group.aaa_base"
    );
    foreach my $group (@searchGRP) {
        if ( -f $group ) {
            $groupTemplate = $group; last;
        }
    }
    foreach my $paswd (@searchPWD) {
        if ( -f $paswd ) {
            $paswdTemplate = $paswd; last;
        }
    }
    KIWIQX::qxx (" cp $groupTemplate $root/etc/group  2>&1 ");
    KIWIQX::qxx (" cp $paswdTemplate $root/etc/passwd 2>&1 ");
    $kiwi -> done();
    #==========================================
    # Create package keys
    #------------------------------------------
    if (! defined $this->{cacheRoot}) {
        $this -> importHostPackageKeys();
    }
    #==========================================
    # Setup shared cache directory
    #------------------------------------------
    $this -> setupCacheMount();
    #==========================================
    # Add source, install and clean source
    #------------------------------------------
    if (! $manager -> setupInstallationSource()) {
        $this -> cleanMount();
        $manager -> freeLock();
        return;
    }
    if (! $manager -> setupRootSystem(@initPacs)) {
        $manager -> resetInstallationSource();
        $this -> cleanMount();
        $manager -> freeLock();
        return;
    }
    #==========================================
    # Reset preperation checks
    #------------------------------------------
    if (! $manager -> resetSignatureCheck()) {
        $this -> cleanMount();
        $manager -> freeLock();
        return;
    }
    $this -> cleanMount('(cache\/(kiwi|zypp)$)|(dev$)');
    $manager -> freeLock();
    #==================================
    # Create default fstab file
    #----------------------------------
    if ( ! open ($FD, '>', "$root/etc/fstab")) {
        $kiwi -> error ("Failed to create fstab file: $!");
        $kiwi -> failed ();
        return;
    }
    print $FD "devpts /dev/pts devpts mode=0620,gid=5 0 0\n";
    print $FD "proc   /proc    proc   defaults        0 0\n";
    close $FD;
    #==================================
    # Return object reference
    #----------------------------------
    return $this;
}

#==========================================
# upgrade
#------------------------------------------
sub upgrade {
    # ...
    # Upgrade a previosly prepared image root tree
    # with respect to changes of the installation source(s)
    # ---
    my $this     = shift;
    my $upStatus = shift;
    my $kiwi     = $this->{kiwi};
    my $root     = $this->{root};
    my $manager  = $this->{manager};
    my $addPacks = $this->{addPacks};
    my $delPacks = $this->{delPacks};
    #==========================================
    # Mount local and NFS directories
    #------------------------------------------
    $manager -> switchToChroot();
    if (! $this -> setupMount ()) {
        $kiwi -> error ("Couldn't mount base system");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # make sure name resolution works
    #------------------------------------------
    $this->{needResolvConf} = 0;
    $this->{needHosts} = 0;
    if (! -f "$root/etc/resolv.conf") {
        KIWIQX::qxx ("cp /etc/resolv.conf $root/etc 2>&1");
        $this->{needResolvConf} = 1;
    }
    if (! -f "$root/etc/hosts") {
        KIWIQX::qxx ("cp /etc/hosts $root/etc 2>&1");
        $this->{needHosts} = 1;
    }
    #==========================================
    # make sure proxy works
    #------------------------------------------
    $this->{needProxy} = 0;
    if (! -f "$root/etc/sysconfig/proxy") {
        KIWIQX::qxx ("cp /etc/sysconfig/proxy $root/etc/sysconfig 2>&1");
        $this->{needProxy} = 1;
    }
    #==========================================
    # Check and set lock
    #------------------------------------------
    $manager -> checkExclusiveLock();
    $manager -> setLock();
    #==========================================
    # Upgrade system
    #------------------------------------------
    if (! $manager -> setupSignatureCheck()) {
        $manager -> freeLock();
        return;
    }
    if (! $manager -> setupInstallationSource()) {
        $this -> cleanupResolvConf();
        $manager -> freeLock();
        return;
    }
    if (! $manager -> setupUpgrade ($addPacks,$delPacks,$upStatus)) {
        $this -> cleanupResolvConf();
        $manager -> freeLock();
        return;
    }
    $this -> cleanupResolvConf();
    $manager -> freeLock();
    return $this;
}

#==========================================
# prepareTestingEnvironment
#------------------------------------------
sub prepareTestingEnvironment {
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $root = $this->{root};
    my $manager  = $this->{manager};
    #==========================================
    # Mount local and NFS directories
    #------------------------------------------
    $manager -> switchToChroot();
    if (! $this -> setupMount ()) {
        $kiwi -> error ("Couldn't mount base system");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # make sure name resolution works
    #------------------------------------------
    $this->{needResolvConf} = 0;
    $this->{needHosts} = 0;
    if (! -f "$root/etc/resolv.conf") {
        KIWIQX::qxx ("cp /etc/resolv.conf $root/etc 2>&1");
        $this->{needResolvConf} = 1;
    }
    if (! -f "$root/etc/hosts") {
        KIWIQX::qxx ("cp /etc/hosts $root/etc 2>&1");
        $this->{needHosts} = 1;
    }
    #==========================================
    # make sure proxy works
    #------------------------------------------
    $this->{needProxy} = 0;
    if (! -f "$root/etc/sysconfig/proxy") {
        KIWIQX::qxx ("cp /etc/sysconfig/proxy $root/etc/sysconfig 2>&1");
        $this->{needProxy} = 1;
    }
    #==========================================
    # Check and set lock
    #------------------------------------------
    $manager -> checkExclusiveLock();
    $manager -> setLock();
    #==========================================
    # Setup sources
    #------------------------------------------
    if (! $manager -> setupInstallationSource()) {
        $this -> cleanupResolvConf();
        $manager -> freeLock();
        return;
    }
    $this -> cleanupResolvConf();
    return $this;
}

#==========================================
# cleanupTestingEnvironment
#------------------------------------------
sub cleanupTestingEnvironment {
    my $this = shift;
    my $root = $this->{root};
    my $manager = $this->{manager};
    $this -> cleanupResolvConf();
    $manager -> freeLock();
    return $this;
}

#==========================================
# cleanupResolvConf
#------------------------------------------
sub cleanupResolvConf {
    my $this = shift;
    my $root = $this->{root};
    my $needResolvConf = $this->{needResolvConf};
    my $needHosts = $this->{needHosts};
    my $needProxy = $this->{needProxy};
    if ($needResolvConf) {
        KIWIQX::qxx ("rm -f $root/etc/resolv.conf");
        undef $this->{needResolvConf};
    }
    if ($needHosts) {
        KIWIQX::qxx ("rm -f $root/etc/hosts");
        undef $this->{needHosts};
    }
    if ($needProxy) {
        KIWIQX::qxx ("rm -f $root/etc/sysconfig/proxy");
        undef $this->{needProxy};
    }
    return;
}

#==========================================
# installTestingPackages
#------------------------------------------
sub installTestingPackages {
    my $this = shift;
    my $pack = shift;
    my $manager  = $this->{manager};
    if (! $manager -> installPackages ($pack)) {
        $manager -> freeLock();
        return;
    }
    return $this;
}

#==========================================
# uninstallTestingPackages
#------------------------------------------
sub uninstallTestingPackages {
    my $this = shift;
    my $pack = shift;
    my $manager  = $this->{manager};
    if (! $manager -> removePackages ($pack)) {
        $manager -> freeLock();
        return;
    }
    return $this;
}

#==========================================
# install
#------------------------------------------
sub install {
    # ...
    # Install the given package set into the root
    # directory of the image system
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $manager = $this->{manager};
    my %type;
    #==========================================
    # Get image package list
    #------------------------------------------
    my @packList = $manager -> setupInstallPackages;
    #==========================================
    # proceed if packlist is not empty
    #------------------------------------------
    if (! @packList) {
        $kiwi -> loginfo ("Packlist is empty, skipping install\n");
        return $this;
    }
    #==========================================
    # Check for RPM incompatibility
    #------------------------------------------
    if (! $manager -> cleanupRPMDatabase()) {
        return;
    }
    #==========================================
    # Mount local and NFS directories
    #------------------------------------------
    if (! setupMount ($this)) {
        $kiwi -> error ("Couldn't mount base system");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Check and set lock
    #------------------------------------------
    $manager -> checkExclusiveLock();
    $manager -> setLock();
    #==========================================
    # Setup signature check
    #------------------------------------------
    $manager -> switchToChroot();
    if (! $manager -> setupSignatureCheck()) {
        $manager -> freeLock();
        return;
    }
    if (! $manager -> setupExcludeDocs()) {
        $manager -> freeLock();
        return;
    }
    #==========================================
    # Add source(s) and install
    #------------------------------------------
    if (! $manager -> setupInstallationSource()) {
        $manager -> freeLock();
        return;
    }
    if (! $manager -> setupRootSystem (@packList)) {
        $manager -> freeLock();
        return;
    }
    $manager -> freeLock();
    return $this;
}

#==========================================
# installArchives
#------------------------------------------
sub installArchives {
    # ...
    # Install the given raw archives into the root
    # directory of the image system
    # ---
    my $this = shift;
    my $idesc= shift;
    my $type = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $root = $this->{root};
    my $manager = $this->{manager};
    if (! defined $idesc) {
        $idesc = $this->{imageDesc};
    }
    #==========================================
    # get image archive list
    #------------------------------------------
    my @archives;
    my @bootinclude_archives;
    if (($type) && ($type eq 'bootstrap')) {
        my $archiveList = $xml -> getBootStrapArchives();
        for my $archive (@{$archiveList}) {
            my $name = $archive -> getName();
            push @archives, $name;
        }
        my $archiveListBootInclude = $xml -> getBootIncludeBootStrapArchives();
        for my $archive (@{$archiveListBootInclude}) {
            my $name = $archive -> getName();
            push @bootinclude_archives, $name;
        }
    } else {
        my $archiveList = $xml -> getImageArchives();
        for my $archive (@{$archiveList}) {
            my $name = $archive -> getName();
            push @archives, $name;
        }
        my $archiveListBootInclude = $xml -> getBootIncludeImageArchives();
        for my $archive (@{$archiveListBootInclude}) {
            my $name = $archive -> getName();
            push @bootinclude_archives, $name;
        }
    }
    #==========================================
    # Install raw data archives
    #------------------------------------------
    $manager -> switchToLocal();
    if (! $manager -> setupArchives(
        $idesc, \@archives, \@bootinclude_archives)
    ) {
        return;
    }
    #==========================================
    # Check ownership of archive files
    #------------------------------------------
    if (-f "$root/bootincluded_archives.filelist") {
        $this -> fixupOverlayFilesOwnership ("bootincluded_archives.filelist");
    }
    return $this;
}

#==========================================
# fixupOverlayFilesOwnership
#------------------------------------------
sub fixupOverlayFilesOwnership {
    # ...
    # search for files and directories in the given path or
    # table of contents (toc) file and make sure those files
    # get the right ownership assigned
    # ---
    my $this  = shift;
    my $path  = shift;
    my $kiwi  = $this->{kiwi};
    my $root  = $this->{root};
    my $item  = $root."/".$path;
    my $prefix= "FixupOwner";
    my @files = ();
    my %except= ();
    if (-d $item) {
        #==========================================
        # got dir, search files there
        #------------------------------------------
        my $wref = $this -> __generateWanted (\@files,$root);
        find ({ wanted => $wref, follow => 0 }, $item);
    } elsif (-f $item) {
        #==========================================
        # got archive, use archive toc file
        #------------------------------------------
        my $fd = FileHandle -> new();
        if ($fd -> open ($item)) {
            while (my $line = <$fd>) {
                chomp $line; $line =~ s/^\///;
                push (@files,$line);
            }
            $fd -> close();
        } else {
            $kiwi -> warning ("$prefix: Failed to open $item: $!");
            $kiwi -> skipped ();
            return;
        }
    } else {
        $kiwi -> warning ("$prefix: No such file or directory: $item");
        $kiwi -> skipped ();
        return;
    }
    #==========================================
    # check file list
    #------------------------------------------
    if (! @files) {
        $kiwi -> warning ("$prefix: No files found in: $item");
        $kiwi -> skipped ();
        return;
    }
    #==========================================
    # create passwd exception directories
    #------------------------------------------
    my $fd = FileHandle -> new();
    if (! $fd -> open ($root."/etc/passwd")) {
        $kiwi -> warning ("$prefix: No passwd file found in: $root");
        $kiwi -> skipped ();
        return;
    }
    while (my $line = <$fd>) {
        chomp $line;
        my $name = (split (/:/,$line))[5];
        $name =~ s/\///;
        next if ! $name;
        if ($name =~ /^(bin|sbin|root|proc|dev)/) {
            next;
        }
        $except{$name} = 1;
    }
    $fd -> close();
    #==========================================
    # walk through all files
    #------------------------------------------
    foreach my $file (@files) {
        my $ok = 1;
        $file =~ s/^ +//;
        foreach my $exception (keys %except) {
            if ($file =~ /^$exception/) {
                $kiwi -> loginfo (
                    "$prefix: $file belongs to passwd, leaving it untouched"
                );
                $ok = 0; last;
            }
        }
        next if ! $ok;
        my $data = KIWIQX::qxx (
            "chroot $root chown -c root:root '".$file."' 2>&1"
        );
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> warning (
                "$prefix: Failed to fixup ownership of $root/$file: $data"
            );
            $kiwi -> skipped ();
        }
    }
    return $this;
}

#==========================================
# setup
#------------------------------------------
sub setup {
    # ...
    # Setup the installed system. This method will:
    # 1) copy the user defined files to the root tree and
    #    creates the .profile environment file.
    # 2) create .profile image environment source file
    # 3) import linuxrc file if required
    # 4) call package setup scripts from config directory
    # 5) calls the config.sh and package scripts within the
    #    chroot of the physical extend.
    # 6) copy the complete image description tree to
    #    /image which contains information to create a logical
    #    extend from the chroot.
    # 7) configure the system with methods from KIWIConfigure
    # 8) cleanup temporary files
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $root = $this->{root};
    my $xml  = $this->{xml};
    my $cmdL = $this->{cmdL};
    my $initCache = $cmdL->getOperationMode("initCache");
    my $configFile= $xml -> getConfigName();
    my $imageDesc = $this->{imageDesc};
    my $manager   = $this->{manager};
    my $data;
    my $status;
    my $FD;
    #========================================
    # Consistency check
    #----------------------------------------
    if (! -d "$root/tmp") {
        $kiwi -> error ("Image system seems to be broken");
        $kiwi -> failed ();
        return;
    }
    #========================================
    # copy license files if they exist
    #----------------------------------------
    if (-f "$root/license.tar.gz") {
        KIWIQX::qxx ("mkdir -p $root/etc/YaST2/licenses/base");
        KIWIQX::qxx (
            "tar -C $root/etc/YaST2/licenses/base -xf $root/license.tar.gz"
        );
        KIWIQX::qxx ("rm -f $root/license.tar.gz");
    }
    #========================================
    # copy user defined files to image tree
    #----------------------------------------
    if ((-d "$imageDesc/root") && (bsd_glob($imageDesc.'/root/*'))) {
        $kiwi -> info ("Copying user defined files to image tree");
        #========================================
        # copy user defined files to tmproot
        #----------------------------------------
        if ((-l "$imageDesc/root/linuxrc") || (-l "$imageDesc/root/include")) {
            $data = KIWIQX::qxx (
                "cp -LR --force $imageDesc/root/ $root/tmproot 2>&1"
            );
        } else {
            mkdir $root."/tmproot";
            $data = KIWIQX::qxx (
                "tar -cf - -C $imageDesc/root . | tar -x -C $root/tmproot 2>&1"
            );
        }
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> info   ($data);
            return;
        }
        #========================================
        # check tmproot ownership
        #----------------------------------------
        $this -> fixupOverlayFilesOwnership ("tmproot");
        #========================================
        # copy tmproot to real root (tar)
        #----------------------------------------
        $data = KIWIQX::qxx (
            "tar -cf - -C $root/tmproot . | tar -x -C $root 2>&1"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> info   ($data);
            return;
        }
        #========================================
        # cleanup tmproot
        #----------------------------------------
        KIWIQX::qxx ("rm -rf $root/tmproot");
        $kiwi -> done();
    }
    #========================================
    # create .profile from <image> tags
    #----------------------------------------
    $kiwi -> info ("Create .profile environment");
    my $profile = KIWIProfileFile -> new();
    if (! $profile) {
        return;
    }
    $status = $profile -> updateFromXML ($xml);
    if (! $status) {
        return;
    }
    $status = $profile -> updateFromCommandline ($cmdL);
    if (! $status) {
        return;
    }
    $status = $profile -> writeProfile ($root);
    if (! $status) {
        return;
    }
    $kiwi -> done();
    #========================================
    # configure the system
    #----------------------------------------
    my $configure = KIWIConfigure -> new ( $xml,$root,$imageDesc );
    if (! defined $configure) {
        return;
    }
    #========================================
    # fixup quoting of .profile
    #----------------------------------------
    $configure -> quoteFile ("$root/.profile");
    #========================================
    # check for linuxrc
    #----------------------------------------
    if (-f "$root/linuxrc") {
        $kiwi -> info ("Setting up linuxrc...");
        unlink ("$root/init");
        my $data = KIWIQX::qxx ("ln $root/linuxrc $root/init 2>&1");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> info   ($data);
            return;
        }
        KIWIQX::qxx ("chmod u+x $root/linuxrc $root/init 2>&1");
        $kiwi -> done ();
    }
    #========================================
    # call setup scripts
    #----------------------------------------
    if (-d "$imageDesc/config") {
        $kiwi -> info ("Preparing package setup scripts");
        KIWIQX::qxx (" mkdir -p $root/image/config ");
        KIWIQX::qxx (" cp $imageDesc/config/* $root/image/config 2>&1 ");
        if (! opendir ($FD,"$root/image/config")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't open script directory: $!");
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
        my @scriptList = readdir $FD;
        foreach my $script (@scriptList) {
            if (-f "$root/image/config/$script") {
                if ($manager -> setupPackageInfo ( $script )) {
                    next;
                }
                $kiwi -> info ("Calling package setup script: $script");
                KIWIQX::qxx (" chmod u+x $root/image/config/$script");
                my $data = KIWIQX::qxx (
                    "chroot $root /image/config/$script 2>&1"
                );
                my $code = $? >> 8;
                if ($code != 0) {
                    $kiwi -> failed ();
                    $kiwi -> info   ($data);
                    $kiwi -> failed ();
                    return;
                } else {
                    $kiwi -> loginfo ("$script: $data");
                }
                KIWIQX::qxx ("rm -f $root/image/config/$script");
                $kiwi -> done ();
            }
        }
        rmdir ("$root/image/config");
        closedir $FD;
    }
    #========================================
    # copy image description to image tree
    #----------------------------------------
    KIWIQX::qxx (" mkdir -p $root/image ");
    KIWIQX::qxx (" cp $configFile $root/image 2>&1 ");
    KIWIQX::qxx (" cp $imageDesc/images.sh $root/image 2>&1 ");
    KIWIQX::qxx (" cp $imageDesc/config-cdroot.tgz $root/image 2>&1 ");
    KIWIQX::qxx (" cp $imageDesc/config-cdroot.sh  $root/image 2>&1 ");
    KIWIQX::qxx (" cp $root/.profile $root/image 2>&1 ");
    KIWIQX::qxx (" chmod u+x $root/image/images.sh 2>&1");
    KIWIQX::qxx (" chmod u+x $root/image/config-cdroot.sh 2>&1");
    if (open ($FD, '>', "$root/image/main::Prepare")) {
        if ($imageDesc !~ /^\//) {
            my $pwd = KIWIQX::qxx (" pwd "); chomp $pwd;
            print $FD $pwd."/".$imageDesc;
            close $FD;
        } else {
            print $FD $imageDesc;
            close $FD;
        }
    }
    #========================================
    # Apply system configuration
    #----------------------------------------
    if (! $configure -> setupGroups()) {
        return;
    }
    if (! $configure -> setupUsers()) {
        return;
    }
    # /.../
    # The following functions have been disabled because they
    # use the systemd tools timedatectl and localectl. Problem
    # is that these tools doesn't work correctly from within a
    # chroot environment. They access the dbus daemon from the
    # host system and thus they change the currently active
    # configuration on the host system which is unwanted
    # ---- 
    # $configure -> setupHWclock();
    # $configure -> setupKeyboardMap();
    # $configure -> setupLocale();
    # $configure -> setupTimezone();
    # ----
    #========================================
    # check for yast firstboot setup file
    #----------------------------------------
    $status = $configure -> setupFirstBootYaST();
    if (! $status) {
        return;
    }
    $status = $configure -> setupAutoYaST();
    if (! $status) {
        return;
    }
    $status = $configure -> setupFirstBootAnaconda();
    if (! $status) {
        return;
    }
    #========================================
    # check for augeas configuration file
    #----------------------------------------
    $status = $configure -> setupAugeasImport();
    if (! $status) {
        return;
    }
    #========================================
    # export build host imported rpm keys
    #----------------------------------------
    $this -> exportHostPackageKeys();
    #========================================
    # call config.sh image script
    #----------------------------------------
    if ((! $initCache) && (-e "$imageDesc/config.sh")) {
        $kiwi -> info ("Calling image script: config.sh");
        KIWIQX::qxx (" cp $imageDesc/config.sh $root/tmp ");
        KIWIQX::qxx (" chmod u+x $root/tmp/config.sh ");
        my ($code,$data) = KIWIGlobals -> instance() -> callContained (
            $root,"/tmp/config.sh"
        );
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> info   ($data);
            return;
        } else {
            $kiwi -> loginfo ("config.sh: $data");
        }
        KIWIQX::qxx (" rm -f $root/tmp/config.sh ");
        $kiwi -> done ();
    }
    #========================================
    # remove packages from delete section
    #----------------------------------------
    my @delete_packs;
    my $deletePacks = $xml -> getPackagesToDelete();
    for my $package (@{$deletePacks}) {
        my $name = $package -> getName();
        push @delete_packs,$name;
    }
    if ((! $initCache) && (@delete_packs)) {
        $kiwi -> info ("Removing packages marked for deletion:\n");
        foreach my $p (@delete_packs) {
            $kiwi -> info ("--> $p\n");
        }
        if (! $manager -> removePackages (\@delete_packs)) {
            $manager -> freeLock();
            return;
        }
    }
    #========================================
    # create /etc/ImageID file
    #----------------------------------------
    my $id = $xml -> getImageID();
    if ($id) {
        $kiwi -> info ("Creating image ID file: $id");
        if ( ! open ($FD, '>', "$root/etc/ImageID")) {
            $kiwi -> failed ();
            $kiwi -> error ("Failed to create ID file: $!");
            $kiwi -> failed ();
            return;
        }
        print $FD "$id\n";
        close $FD;
        $kiwi -> done();
    }
    #========================================
    # cleanup temporary copy of resolv.conf
    #----------------------------------------
    if (! -e "$imageDesc/root/etc/resolv.conf") {
        # restore only if overlay tree doesn't contain a resolv.conf
        if ((-f "$root/etc/resolv.conf") && (-f "/etc/resolv.conf")) {
            my $data = KIWIQX::qxx (
                "diff -q /etc/resolv.conf $root/etc/resolv.conf"
            );
            my $code = $? >> 8;
            if ($code == 0) {
                $kiwi -> info ("Cleanup temporary copy of resolv.conf");
                KIWIQX::qxx ("rm -f $root/etc/resolv.conf");
                $kiwi -> done ();
            }
        }
    }
    #========================================
    # cleanup temporary copy of hosts
    #----------------------------------------
    if (! -e "$imageDesc/root/etc/hosts") {
        # restore only if overlay tree doesn't contain a hosts
        if (-f "$root/etc/hosts.rpmnew") {
            $kiwi -> info ("Cleanup temporary copy of hosts");
            KIWIQX::qxx ("mv $root/etc/hosts.rpmnew $root/etc/hosts");
            $kiwi -> done ();
        }
    }
    #========================================
    # cleanup temporary copy of proxy
    #----------------------------------------
    if (! -e "$imageDesc/root/etc/sysconfig/proxy") {
        # restore only if overlay tree doesn't contain a proxy setup
        if ((-f "$root/etc/sysconfig/proxy") && (-f "/etc/sysconfig/proxy")) {
            my $data = KIWIQX::qxx (
                "diff -q /etc/sysconfig/proxy $root/etc/sysconfig/proxy"
            );
            my $code = $? >> 8;
            if ($code == 0) {
                $kiwi -> info ("Cleanup temporary copy of sysconfig/proxy");
                my $template = "$root/var/adm/fillup-templates/sysconfig.proxy";
                if (! -f $template) {
                    KIWIQX::qxx ("rm -f $root/etc/sysconfig/proxy");
                } else {
                    KIWIQX::qxx ("cp $template $root/etc/sysconfig/proxy");
                }
                $kiwi -> done ();
            }
        }
    }
    #========================================
    # cleanup temporary .buildenv
    #----------------------------------------
    if (-f "$root/.buildenv") {
        KIWIQX::qxx ("rm -f $root/.buildenv");
    }
    return $this;
}

#==========================================
# importHostPackageKeys
#------------------------------------------
sub importHostPackageKeys {
    # ...
    # import package keys to avoid warnings on installation
    # of packages. This is an rpm only task and needs to be
    # enhanced for non rpm based packages
    # ---
    my $this = shift;
    my $root = $this->{root};
    my $kiwi = $this->{kiwi};
    my $data;
    my $code;
    #==========================================
    # check for rpm binary
    #------------------------------------------
    if (! -x "/bin/rpm") {
        # operates on rpm only
        return $this;
    }
    #==========================================
    # check build key and gpg
    #------------------------------------------
    $kiwi -> info ("Importing build keys...");
    my $gnupg       = '/usr/lib/rpm/gnupg';
    my $dumsigsExec = "$gnupg/dumpsigs";
    my $keydir      = "$gnupg/keys";
    my $sigs        = "$root/rpm-sigs";
    if (! -d $gnupg) {
        # no rpm gpg setup available
        return $this;
    }
    if (! -d $keydir) {
        my @keyring = (
            "$gnupg/pubring.gpg",
            "$gnupg/suse-build-key.gpg"
        );
        if (! -x $dumsigsExec) {
            $kiwi -> skipped ();
            $kiwi -> warning ("Can't find dumpsigs on host system");
            $kiwi -> skipped ();
            return $this;
        }
        $data = KIWIQX::qxx ("mkdir -p $sigs");
        foreach my $key (@keyring) {
            if (! -f $key) {
                next;
            }
            $data = KIWIQX::qxx (
                "cd $sigs && $dumsigsExec $key 2>&1"
            );
            $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> skipped ();
                $kiwi -> error  ("Can't dump pubkeys: $data");
                $kiwi -> failed ();
                KIWIQX::qxx ("rm -rf $sigs");
                return $this;
            }
        }
    } else {
        $data = KIWIQX::qxx (
            "mkdir -p $sigs && cp -a $keydir/* $sigs"
        );
    }
    my @rpm_keys = ();
    if (opendir (my $FD,$sigs)) {
        @rpm_keys = readdir ($FD); closedir ($FD);
    }
    if (@rpm_keys <= 2) {
        $kiwi -> skipped ();
        $kiwi -> info ("No keys found for import");
        $kiwi -> skipped ();
        KIWIQX::qxx ("rm -rf $sigs");
        return $this;
    }
    $data.= KIWIQX::qxx (
        "rpm -r $root --import $sigs/gpg-pubke* 2>&1"
    );
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> skipped ();
        $kiwi -> error  ("Failed to import pubkeys: $data");
        $kiwi -> failed ();
        if (-d $sigs) {
            KIWIQX::qxx ("rm -rf $sigs");
        }
        return $this;
    }
    if (-d $sigs) {
        KIWIQX::qxx ("rm -rf $sigs");
    }
    $kiwi -> done();
    return $this;
}

#==========================================
# exportHostPackageKeys
#------------------------------------------
sub exportHostPackageKeys {
    # ...
    # remove kiwi imported host rpm package keys from the
    # new root system in order to cleanup the stage
    # ---
    my $this = shift;
    my $root = $this->{root};
    my $kiwi = $this->{kiwi};
    my $data;
    my $code;
    if (! -d "$root/rpm-sigs") {
        return $this;
    }
    my @rpm_keys = ();
    if (opendir (my $FD,"$root/rpm-sigs")) {
        @rpm_keys = readdir ($FD); closedir ($FD);
    }
    if (@rpm_keys <= 2) {
        return $this;
    }
    $kiwi -> info ("Removing host package keys\n");
    foreach my $key (@rpm_keys) {
        next if (($key eq '.') || ($key eq '..'));
        if ($key =~ /(.*)\.asc/) {
            $key = $1;
        }
        $data = KIWIQX::qxx ("rpm -r $root -e $key 2>&1");
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> info ("--> $key failed: $data\n");
        } else {
            $kiwi -> info ("--> $key\n");
        }
    }
    KIWIQX::qxx ("rm -rf $root/rpm-sigs");
    return $this;
}

#==========================================
# addToMountList
#------------------------------------------
sub addToMountList {
    # ...
    # add mount path to mount list
    # ---
    my $this = shift;
    my $path = shift;
    my @mountList;
    if (defined $this->{mountList}) {
        @mountList = @{$this->{mountList}};
    } else {
        @mountList = ();
    }
    push (@mountList,$path);
    $this->{mountList} = \@mountList;
    return $this;
}

#==========================================
# setupCacheMount
#------------------------------------------
sub setupCacheMount {
    # ...
    # bind mount the specified cache directory into
    # the chroot system. This is used to establish
    # a shared cache over multiple prepare processes
    # ---
    my $this  = shift;
    my $root  = $this->{root};
    my @cache = ("/var/cache/kiwi");
    my @mountList;
    if (defined $this->{mountList}) {
        @mountList = @{$this->{mountList}};
    } else {
        @mountList = ();
    }
    if (! -e "$root/dev/console") {
        KIWIQX::qxx ("mkdir -p $root/dev");
        KIWIQX::qxx ("mount -n --bind /dev $root/dev");
        push (@mountList,"$root/dev");
    }
    foreach my $cache (@cache) {
        my $status = KIWIQX::qxx (
            "cat /proc/mounts | grep ".$root.$cache." 2>&1"
        );
        my $result = $? >> 8;
        if ($result == 0) {
            next;
        }
        if (! -d $cache) {
            KIWIQX::qxx ("mkdir -p $cache");
        }
        if (! -d "$root/$cache") {
            KIWIQX::qxx ("mkdir -p $root/$cache 2>&1");
        }
        KIWIQX::qxx ("mount -n --bind $cache $root/$cache 2>&1");
        push (@mountList,"$root/$cache");
    }
    if (! -e "$root/proc/mounts") {
        KIWIQX::qxx ("mkdir -p $root/proc");
        KIWIQX::qxx ("mount -n -t proc proc $root/proc");
        push (@mountList,"$root/proc");
    }
    $this->{mountList} = \@mountList;
    return @mountList;
}

#==========================================
# setupMount
#------------------------------------------
sub setupMount {
    # ...
    # mount all reachable local and nfs directories
    # and register them in the mountList
    # ---
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $root   = $this->{root};
    my $baseSystem = $this->{baseSystem};
    my $prefix = $root."/".$baseSystem;
    my $cache  = "/var/cache";
    my @mountList;
    if (defined $this->{mountList}) {
        @mountList = @{$this->{mountList}};
    } else {
        @mountList = ();
    }
    $kiwi -> info ("Mounting required file systems");
    if (-d $prefix) {
        $kiwi -> failed ();
        $kiwi -> error ("Entity $prefix already exist");
        $kiwi -> failed ();
        return;
    }
    if (! mkdir $prefix) {
        $kiwi -> failed ();
        $kiwi -> error ("Couldn't create directory: $prefix");
        $kiwi -> failed ();
        return;
    }
    if (! -e "$root/proc/mounts") {
        KIWIQX::qxx ("mkdir -p $root/proc");
        KIWIQX::qxx ("mount -n -t proc proc $root/proc");
        push (@mountList,"$root/proc");
    }
    if (! -e "$root/dev/console") {
        KIWIQX::qxx ("mount -n --bind /dev $root/dev");
        push (@mountList,"$root/dev");
    }
    if (! -e "$root/var/run/dbus/pid") {
        KIWIQX::qxx ("mount -n --bind /var/run/dbus $root/var/run/dbus");
        push (@mountList,"$root/var/run/dbus");
    }
    if (! -d "$root/sys/block") {
        KIWIQX::qxx ("mkdir -p $root/sys");
        KIWIQX::qxx ("mount -n -t sysfs sysfs $root/sys");
        KIWIQX::qxx ("mkdir -p $root/dev/pts");
        KIWIQX::qxx (
            "mount -n -t devpts -o mode=0620,gid=5 devpts $root/dev/pts"
        );
        push (@mountList,"$root/sys");
        push (@mountList,"$root/dev/pts");
    }
    if (! -e "$root/proc/sys/fs/binfmt_misc/register") {
        KIWIQX::qxx ("mkdir -p $root/proc/sys/fs/binfmt_misc");
        KIWIQX::qxx (
            "mount -n -t binfmt_misc binfmt_misc $root/proc/sys/fs/binfmt_misc"
        );
        push (@mountList,"$root/proc/sys/fs/binfmt_misc");
    }
    $this->{mountList} = \@mountList;
    @mountList = $this -> setupCacheMount();
    $kiwi -> done();
    foreach my $chl (keys %{$this->{sourceChannel}{private}}) {
        my @opts = @{$this->{sourceChannel}{private}{$chl}};
        my $path = $opts[2];
        if ($path =~ /='$baseSystem(\/.*)'$/) {
            $path = $1;
        } else {
            next;
        }
        $kiwi -> info ("Mounting local channel: $chl\n");
        my $roopt = "dirs=$cache=rw:$path=ro,ro";
        my $auopt = "dirs=$path=ro";
        my $mount = $prefix.$path;
        push (@mountList,$mount);
        KIWIQX::qxx ("mkdir -p \"$mount\"");
        my $data = KIWIQX::qxx ("touch $path/bob 2>&1");
        my $code = $? >> 8;
        if ($code == 0) {
            KIWIQX::qxx ("rm -f $path/bob 2>&1");
            $kiwi -> warning ("--> Status: read-write mounted");
        } else {
            $kiwi -> info ("--> Status: read-only mounted");
        }
        $data = KIWIQX::qxx ("mount -n -o bind \"$path\" \"$mount\" 2>&1");
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            $this->{mountList} = \@mountList;
            return;
        }
        $kiwi -> done();
    }
    $this->{mountList} = \@mountList;
    return $this;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
    # ...
    # umount all mountList registered devices
    # ---
    my $this = shift;
    my $expr = shift;
    my $kiwi = $this->{kiwi};
    my $root = $this->{root};
    my $xml  = $this->{xml};
    if (! defined $this->{mountList}) {
        return $this;
    }
    my @mountList  = @{$this->{mountList}};
    my $baseSystem = $this->{baseSystem};
    my $prefix;
    if (($root) && (-d $root)) {
        $prefix = $root."/".$baseSystem;
    }
    my @newList= ();
    foreach my $item (reverse @mountList) {
        # check for matching exclude expression if specified
        if (defined $expr) {
            if ($item !~ /$expr/) {
                push (@newList,$item);
                next;
            }
        }
        # /.../
        # test if the item is a directory with a shell test built-in
        # this is because the repo string could contain shell escaped
        # characters which is not supported by perl's test operators
        # ----
        KIWIQX::qxx ("test -d \"$item\"");
        my $mountpoint_exists = ($? >> 8) == 0;
        if (! $mountpoint_exists) {
            $kiwi -> loginfo (
                "Warning: \"$item\" not a directory or not existing\n"
            );
            next;
        }
        $kiwi -> loginfo ("Umounting path: $item\n");
        my $data = KIWIQX::qxx ("umount \"$item\" 2>&1");
        my $code = $? >> 8;
        if (($code != 0) && ($data !~ "not mounted")) {
            # umount failed - for /dev we can allow to lazy umount it (null might be held open)
            if ($item =~ "/dev") {
                $kiwi -> loginfo ("Umounting path (lazy): $item\n");
                my $data = KIWIQX::qxx ("umount -l \"$item\" 2>&1");
                my $code = $? >> 8;
            }
            if ($code != 0) {
                $kiwi -> warning ("Umount of $item failed: $data");
                $kiwi -> skipped ();
            }
        }
        if (($prefix) && ($item =~ /^$prefix/)) {
            KIWIQX::qxx ("rmdir -p \"$item\" 2>&1");
        }
        if ($item =~ /^\/tmp\/kiwimount/) {
            KIWIQX::qxx ("rmdir -p \"$item\" 2>&1");
        }
        
    }
    if (($prefix) && (-d $prefix)) {
        rmdir $prefix;
    }
    if (defined $this->{overlay}) {
        undef $this->{overlay};
    }
    $this->{mountList} = \@newList;
    return $this;
}

#==========================================
# cleanSource
#------------------------------------------
sub cleanSource {
    # ...
    # remove all source locations created by kiwi
    # ---
    my $this = shift;
    my $manager = $this->{manager};
    $manager -> resetSource();
    return $this;
}

#==========================================
# cleanManager
#------------------------------------------
sub cleanManager {
    # ...
    # remove data and cache dir(s) of the packagemanager
    # created for building the new root system
    # ---
    my $this = shift;
    my $manager = $this->{manager};
    $manager -> cleanChild();
    return $this;
}

#==========================================
# cleanLock
#------------------------------------------
sub cleanLock {
    # ...
    # remove stale lock files
    # ---
    my $this = shift;
    my $manager = $this->{manager};
    $manager -> freeLock();
    return $this;
}

#==========================================
# __generateWanted
#------------------------------------------
sub __generateWanted {
    # ...
    # generate search for given files in given directory
    # ---
    my $this   = shift;
    my $result = shift;
    my $base   = shift;
    return sub {
        my @names = ($File::Find::name,$File::Find::dir);
        foreach my $name (@names) {
            $name =~ s/^$base//; $name =~ s/^\///;
            push @{$result},$name;
        }
    }
}

1;
