#================
# FILE          : KIWIManager.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to support multiple
#               : package manager like smart or zypper
#               :
# STATUS        : Development
#----------------
package KIWIManager;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use Env;
use FileHandle;
use File::Basename;
use Config::IniFiles;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILog;
use KIWILocator;
use KIWIQX;
use KIWITrace;

#==========================================
# Exports
#------------------------------------------
our @ISA       = qw (Exporter);
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create a new KIWIManager object, which is used
    # to import all data needed to abstract from different
    # package managers
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
    my $xml        = shift;
    my $sourceRef  = shift;
    my $root       = shift;
    my $manager    = shift;
    my $targetArch = shift;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    if (! defined $xml) {
        $kiwi -> error  ("Missing XML description pointer");
        $kiwi -> failed ();
        return;
    }
    if (! defined $sourceRef) {
        $kiwi -> error  ("Missing channel description pointer");
        $kiwi -> failed ();
        return;
    }
    my %source = %{$sourceRef};
    if (! defined $root) {
        $kiwi -> error  ("Missing chroot path");
        $kiwi -> failed ();
        return;
    }
    if (! defined $manager) {
        $manager = $xml -> getPreferences() -> getPackageManager();
    }
    if (defined $targetArch && $manager ne 'zypper') {
        $kiwi -> warning ("Target architecture not supported for $manager");
        $kiwi -> skipped ();
    }
    if ($manager eq "apt-get") {
        $manager = "apt";
    }
    my $locator = KIWILocator -> instance();
    my $dataDir = "/var/cache/kiwi/$manager";
    my @channelList = ();
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{kiwi}        = $kiwi;
    $this->{channelList} = \@channelList;
    $this->{xml}         = $xml;
    $this->{source}      = \%source;
    $this->{manager}     = $manager;
    $this->{root}        = $root;
    $this->{chroot}      = 0;
    $this->{lock}        = "/var/lock/kiwi-init.lock";
    $this->{screenCall}  = $root."/screenrc.smart";
    $this->{screenCtrl}  = $root."/screenrc.ctrls";
    $this->{screenErrs}  = $root."/screenrc.err";
    $this->{screenLogs}  = $kiwi -> getRootLog();
    $this->{dataDir}     = $dataDir;
    $this->{locator}     = $locator;
    $this->{targetArch}  = $targetArch;
    #==========================================
    # Store object data chroot path
    #------------------------------------------
    $this->{kchroot}     = [
        "chroot \"$root\""
    ];
    return $this;
}

#==========================================
# switchToChroot
#------------------------------------------
sub switchToChroot {
    my $this = shift;
    $this->{chroot} = 1;
    return 1;
}

#==========================================
# switchToLocal
#------------------------------------------
sub switchToLocal {
    my $this = shift;
    $this->{chroot} = 0;
    return 1;
}

#==========================================
# setupScreen
#------------------------------------------
sub setupScreen {
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $root = $this->{root};
    #==========================================
    # screen files
    #------------------------------------------
    my $screenCall = $this->{screenCall};
    my $screenCtrl = $this->{screenCtrl};
    my $screenLogs = $this->{screenLogs};

    #==========================================
    # Initiate screen call file
    #------------------------------------------
    my $fd = FileHandle -> new();
    my $cd = FileHandle -> new();
    if ((! $fd -> open (">$screenCall")) || (! $cd -> open (">$screenCtrl"))) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create call file: $!");
        $kiwi -> failed ();
        $this -> resetInstallationSource();
        return;
    }
    if ($screenLogs) {
        print $cd "logfile $screenLogs\n";
    }
    print $cd "logfile flush 1\n";
    $cd -> close();
    #==========================================
    # Global exports
    #------------------------------------------
    print $fd "export PBL_SKIP_BOOT_TEST=1"."\n";
    #==========================================
    # Global exports [ proxy setup ]
    #------------------------------------------
    if ($ENV{http_proxy}) {
        print $fd "export http_proxy=\"$ENV{http_proxy}\""."\n";
    }
    if ($ENV{ftp_proxy}) {
        print $fd "export ftp_proxy=\"$ENV{ftp_proxy}\""."\n";
    }
    if ($ENV{https_proxy}) {
        print $fd "export https_proxy=\"$ENV{https_proxy}\""."\n";
    }
    if ($ENV{no_proxy}) {
        print $fd "export no_proxy=\"$ENV{no_proxy}\""."\n";
    }
    #==========================================
    # return screen call file handle
    #------------------------------------------
    return $fd;
}

#==========================================
# setupScreenCall
#------------------------------------------
sub setupScreenCall {
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $screenCall = $this->{screenCall};
    my $screenCtrl = $this->{screenCtrl};
    my $screenErrs = $this->{screenErrs};
    my $logs = 1;
    my $code;
    my $data;
    #==========================================
    # Check log location
    #------------------------------------------
    my $trace = KIWITrace -> instance();
    if ($kiwi -> terminalLogging()) {
        $logs = 0;
    }
    #==========================================
    # activate shell set -x mode and stderr log
    #------------------------------------------
    my $fd = FileHandle -> new();
    if ($fd -> open ($screenCall)) {
        local $/; $data = <$fd>; $fd -> close();
        if ($fd -> open (">$screenCall")) {
            print $fd "#!/bin/bash\n";
            print $fd "exec 2> >(tee $this->{screenErrs} >&2)\n";
            print $fd "set -x\n";
            print $fd $data;
            $fd -> close();
        }
    }
    KIWIQX::qxx ("chmod 755 $screenCall");
    if ($logs) {
        $kiwi -> closeRootChannel();
    }
    #==========================================
    # run process in screen/terminal session
    #------------------------------------------
    $this->{child} = fork();
    if (! defined $this->{child}) {
        $kiwi -> failed ();
        $kiwi -> error  ("fork failed: $!");
        $kiwi -> failed ();
        return;
    }
    if ($this->{child}) {
        #==========================================
        # wait for the process to finish
        #------------------------------------------
        waitpid $this->{child},0;
        $code = $? >> 8;
        $data = "";
        undef $this->{child};
        #==========================================
        # create exit code and data value if screen
        #------------------------------------------
        if ($logs) {
            $kiwi -> reopenRootChannel();
            if ($fd -> open ($screenErrs)) {
                local $/; $data = <$fd>; $fd -> close();
            }   
            if ($code == 0) {
                if (! $fd -> open ("$screenCall.exit")) {
                    $code = 1;
                } else {
                    $code = <$fd>; chomp $code;
                    $fd -> close();
                }
            }
        }
        #==========================================
        # remove call and control files
        #------------------------------------------
        KIWIQX::qxx ("rm -f $screenCall*");
        KIWIQX::qxx ("rm -f $screenCtrl");
        KIWIQX::qxx ("rm -f $screenErrs");
    } else {
        #==========================================
        # do the job in the child process
        #------------------------------------------
        if ($logs) {
            if (! exec ("screen -L -D -m -c $screenCtrl $screenCall")) {
                die ("\n*** Couldn't exec screen: $! ***\n");
            }
        } else {
            if (! exec ( $screenCall )) {
                die ("\n*** Couldn't exec shell: $! ***\n");
            }
        }
    }
    #==========================================
    # check exit code from session
    #------------------------------------------
    if ($code != 0) {
        $kiwi -> failed ();
        if (($logs) && ($data)) {
            print STDERR $data;
        }
        $this -> resetInstallationSource();
        if ($kiwi -> trace()) {
            $trace->{BT}[$trace->{TL}] = eval {
                Carp::longmess ($trace->{TT}.$trace->{TL}++)
            };
        }
        return;
    }
    $kiwi -> done ();
    return $this;
}

#==========================================
# setupDeletePackages
#------------------------------------------
sub setupDeletePackages {
    # ...
    # create the delete packages list from the information
    # of the package types delete. Store the result in the
    # object pointer
    # ---
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $xml    = $this->{xml};
    #==========================================
    # check cached result
    #------------------------------------------
    if (defined $this->{delete_packlist}) {
        return @{$this->{delete_packlist}};
    }
    my @delete_packs;
    my $deletePacks = $xml -> getPackagesToDelete();
    for my $package (@{$deletePacks}) {
        my $name = $package -> getName();
        push @delete_packs,$name;
    }
    $this->{delete_packlist} = \@delete_packs;
    return @delete_packs;
}

#==========================================
# setupInstallPackages
#------------------------------------------
sub setupInstallPackages {
    # ...
    # create the install packages list from the information
    # of the package types image, xen and vmware. Store
    # the result in the object pointer
    # ---
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $xml    = $this->{xml};
    #==========================================
    # check cached result
    #------------------------------------------
    if (defined $this->{packlist}) {
        return @{$this->{packlist}};
    }
    #==========================================
    # Get image package list
    #------------------------------------------
    my @packList;
    my $imagePackages = $xml -> getPackages();
    for my $package (@{$imagePackages}) {
        my $name = $package -> getName();
        push @packList, $name;
    }
    #==========================================
    # Get image pattern list
    #------------------------------------------
    my $imageCollection = $xml -> getPackageCollections();
    for my $collection (@{$imageCollection}) {
        my $name = $collection -> getName();
        push @packList, 'pattern:'.$name;
    }
    #==========================================
    # Get image product list
    #------------------------------------------
    my $imageProduct = $xml -> getProducts();
    for my $product (@{$imageProduct}) {
        my $name = $product -> getName();
        push @packList, 'product:'.$name;
    }
    $this->{packlist} = \@packList;
    return @packList;
}

#==========================================
# setupArchives
#------------------------------------------
sub setupArchives {
    # ...
    # install the given tar archives into the
    # root system
    # ---
    my @args  = @_;
    my $this  = shift @args;
    my $idesc = shift @args;
    my @tars  = @{$args[0]};
    my @boot_include_tars = @{$args[1]};
    my $kiwi    = $this->{kiwi};
    my $chroot  = $this->{chroot};
    my @kchroot = @{$this->{kchroot}};
    my $root    = $this->{root};
    my $screenCall = $this->{screenCall};
    #==========================================
    # check for empty list
    #------------------------------------------
    if (! @tars) {
        return $this;
    }
    #==========================================
    # check for chroot
    #------------------------------------------
    if ($chroot) {
        $kiwi -> error ("Can't access archives in chroot");
        return;
    }
    #==========================================
    # check for origin of image description
    #------------------------------------------
    if (open my $FD, '<', "$idesc/image/main::Prepare") {
        $idesc = <$FD>;
        close $FD;
    }
    #==========================================
    # check for archive files
    #------------------------------------------
    foreach my $tar (@tars) {
        if (! -f "$idesc/$tar") {
            $kiwi -> error ("Can't find $idesc/$tar");
            return;
        }
    }
    #==========================================
    # setup screen call
    #------------------------------------------
    my $fd = $this -> setupScreen();
    if (! defined $fd) {
        return;
    }
    $kiwi -> info ("Installing raw archives in: $root...");
    #==========================================
    # Create screen call file
    #------------------------------------------
    print $fd "function clean { kill \$SPID;";
    print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
    print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
    print $fd "c=\$((\$c+1));done;\n";
    print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
    print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
    print $fd "trap clean INT TERM\n";
    if (@boot_include_tars) {
        print $fd "for i in @boot_include_tars;do\n";
        print $fd "   tar -tf $idesc/\$i";
        print $fd ' | grep -v /$ ';
        print $fd ">> $root/bootincluded_archives.filelist\n";
        print $fd "done\n";
    }
    print $fd "for i in @tars;do\n";
    print $fd "   if ! tar -C $root -xvf $idesc/\$i;then\n";
    print $fd "       ECODE=\$?\n";
    print $fd "       echo \$ECODE > $screenCall.exit\n";
    print $fd "       exit \$ECODE\n";
    print $fd "   fi\n";
    print $fd "done\n";
    print $fd "echo 0 > $screenCall.exit\n";
    print $fd "exit 0\n";
    $fd -> close();
    #==========================================
    # Call it
    #------------------------------------------
    return $this -> setupScreenCall();
}

#==========================================
# provideMediaLicense
#------------------------------------------
sub provideMediaLicense {
    # ...
    # walk through the repository list and search for a
    # license.tar.gz file on the media. If found the tarball
    # will be downloaded from the media and included into
    # the image
    # ---
    my $this     = shift;
    my $kiwi     = $this->{kiwi};
    my %source   = %{$this->{source}};
    my $root     = $this->{root};
    my @repolist = ();
    my $license  = "license.tar.gz";
    #=================================================
    # use only repos which set prefer-license to true
    #-------------------------------------------------
    foreach my $alias (keys %{$source{public}}) {
        if ($source{$alias}{license}) {
            push @repolist,$alias;
        }
    }
    #=================================================
    # use all repos if none has set prefer-license
    #-------------------------------------------------
    if (! @repolist) {
        foreach my $alias (keys %{$source{public}}) {
            push @repolist,$alias;
        }
    }
    # /.../
    # walk through selected repolist. Note if more than
    # one repo is searched the selected repo doesn't have
    # to be the first one according to the XML description
    # ----
    foreach my $alias (@repolist) {
        my $repo;
        foreach my $opt (@{$source{public}{$alias}}) {
            next if ! $opt;
            if ($opt =~ /(.*?)=['\"](.*)['\"]/) {
                my $key = $1;
                my $val = $2;
                $repo = $val;
                if ($val =~ /^\//) {
                    $val = "file://".$val;
                    $repo = $val;
                }
            }
        }
        next if ! $repo;
        KIWIGlobals -> instance() -> downloadFile (
            $repo."/".$license,$root."/".$license
        );
        last if -e $root."/".$license;
    }
    return $this;
}

#==========================================
# checkExclusiveLock
#------------------------------------------
sub checkExclusiveLock {
    # ...
    # During very first chroot build phase the package manager
    # requires an exclusive lock. Another kiwi process at that stage
    # will fail so we are waiting until the lock is done
    # ---
    my $this = shift;
    my $lock = $this->{lock};
    my $kiwi = $this->{kiwi};
    if (-f $lock) {
        $kiwi -> info ("Waiting for package lock to disappear...")
    } else {
        return $this;
    }
    while (-f $lock) {
        sleep (5);
    }
    $kiwi -> done();
    return $this;
}

#==========================================
# setLock
#------------------------------------------
sub setLock {
    my $this = shift;
    my $lock = $this->{lock};
    my $kiwi = $this->{kiwi};
    $kiwi -> loginfo ("Set package manager lock\n");
    KIWIQX::qxx (" touch $lock ");
    return 1;
}

#==========================================
# freeLock
#------------------------------------------
sub freeLock {
    my $this = shift;
    my $lock = $this->{lock};
    my $kiwi = $this->{kiwi};
    $kiwi -> loginfo ("Release package manager lock\n");
    KIWIQX::qxx (" rm -f $lock ");
    return 1;
}

#==========================================
# cleanChild
#------------------------------------------
sub cleanChild {
    my $this = shift;
    $this -> freeLock();
    if (defined $this->{child}) {
        kill 15,$this->{child};
    }
    return $this;
}

#==========================================
# removeCacheDir
#------------------------------------------
sub removeCacheDir {
    my $this    = shift;
    my $dataDir = $this->{dataDir};
    my $kiwi    = $this->{kiwi};
    my $config  = dirname ($dataDir);
    $this -> cleanChild();
    $kiwi -> loginfo ("Removing cache directory: $dataDir\n");
    KIWIQX::qxx ("rm -rf $dataDir");
    KIWIQX::qxx ("rm -rf $config/config");
    return $this;
}

#==========================================
# cleanupRPMDatabase
#------------------------------------------
sub cleanupRPMDatabase {
    my $this    = shift;
    my $kiwi    = $this->{kiwi};
    my @kchroot = @{$this->{kchroot}};
    my $root    = $this->{root};
    my $locator = $this->{locator};
    my $data;
    my $code;
    #==========================================
    # check for rpm binary
    #------------------------------------------
    my $rpm    = $locator -> getExecPath('rpm');
    my $rpmdb  = $locator -> getExecPath('rpmdb');
    my $dbdump = $locator -> getExecPath('db_dump');
    my $dbload = $locator -> getExecPath('db45_load');
    if (! $rpm) {
        return $this;
    }
    if (! $rpmdb) {
        $rpmdb = $rpm;
    }
    #==========================================
    # try to initialize rpm database
    #------------------------------------------
    $data = KIWIQX::qxx ("@kchroot $rpmdb --initdb &>/dev/null");
    $code = $? >> 8;
    #==========================================
    # try to rebuild DB on failed init
    #------------------------------------------
    if ($code != 0) {
        $kiwi -> info ('Rebuild RPM package db...');
        my $nameIndex = "$root/var/lib/rpm/Name";
        my $packIndex = "$root/var/lib/rpm/Packages";
        if (! $dbdump) {
            $kiwi -> failed ();
            $kiwi -> error ("db_dump tool required for rpm db rebuild\n");
            return;
        }
        if (! $dbload) {
            $kiwi -> failed ();
            $kiwi -> error ("db45_load tool required for rpm db rebuild\n");
            return;
        }
        KIWIQX::qxx ('mv '.$packIndex.' '.$packIndex.'.bak');
        KIWIQX::qxx ('mv '.$nameIndex.' '.$nameIndex.'.bak');
        KIWIQX::qxx ($dbdump.' '.$packIndex.'.bak | '.$dbload.' '.$packIndex);
        KIWIQX::qxx ($dbdump.' '.$nameIndex.'.bak | '.$dbload.' '.$nameIndex);
        KIWIQX::qxx ('rm -f '.$packIndex.'.bak');
        KIWIQX::qxx ('rm -f '.$nameIndex.'.bak');
        $data = KIWIQX::qxx ("@kchroot $rpmdb --rebuilddb 2>&1");
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error (
                "Most likely we encountered an RPM version incompatibility\n"
            );
            $kiwi -> error ("rpm: $data");
            return;
        }
        $kiwi -> done();
    }
    return $this;
}

#==========================================
# rpmLibs
#------------------------------------------
sub rpmLibs {
    # ...
    # try to fix rpm version incompatibility
    # ---
    my $this       = shift;
    my @kchroot    = @{$this->{kchroot}};
    my @packlist   = $this -> setupInstallPackages();
    my @deletelist = $this -> setupDeletePackages();
    #==========================================
    # cleanup baselibs
    #------------------------------------------
    if ((@packlist) || (@deletelist)) {
        if (! $this -> cleanupRPMDatabase()) {
            return;
        }
    }
    KIWIQX::qxx ("@kchroot ldconfig 2>&1");
    return $this;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
    my $this   = shift;
    my $meta   = $this->{dataDir};
    my $zypperConf = "$meta/zypper.conf.$$";
    my $zyppConf   = "$meta/zypp.conf.$$";
    KIWIQX::qxx ("rm -f $zypperConf $zyppConf");
    return 1;
}

1;
