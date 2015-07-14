#================
# FILE          : KIWIContainerBuilder.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Create an image that will function as a lxc container
#               :
# STATUS        : Development
#----------------
package KIWIContainerBuilder;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use File::Basename;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
use base qw /KIWIImageBuilderBase/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX;
use KIWIXML;
use KIWIXMLTypeData;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIContainerBuilder object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    if (! $this) {
        return;
    }
    $this->{baseWork} = 'container';
    return $this;
}

#==========================================
# createImage
#------------------------------------------
sub createImage {
    # ...
    # Create the image, returns an array ref containing a
    # list of the files that are part of the image, created
    # by this builder
    # ---
    my $this = shift;
    my $status = 1; # assume success
    #==========================================
    # create the root directory
    #------------------------------------------
    my $targetDir = $this -> __createTargetRootTree();
    if (! $targetDir) {
        return;
    }
    #==========================================
    # Run the user defined images.sh script
    #------------------------------------------
    $status = $this -> p_runUserImageScript();
    if (! $status) {
        return;
    }
    #==========================================
    # copy the unpacked root tree to the target
    #------------------------------------------
    $status = $this -> __copyUnpackedTreeContent($targetDir);
    if (! $status) {
        return;
    }
    #==========================================
    # remove the KIWI specific stuff
    #------------------------------------------
    $status = $this -> __removeKiwiBuildInfo($targetDir);
    if (! $status) {
        return;
    }
    #==========================================
    # container configuration settings
    #------------------------------------------
    $status = $this -> __applyContainerConfig($targetDir);
    if (! $status) {
        return;
    }
    #==========================================
    # container inittab
    #------------------------------------------
    $status = $this -> __createInitTab($targetDir);
    if (! $status) {
        return;
    }
    #==========================================
    # disable services
    #------------------------------------------
    $status = $this -> __disableServices($targetDir);
    if (! $status) {
        return;
    }
    #==========================================
    # setup dev nodes in the image
    #------------------------------------------
    $status = $this -> __createDevNodes($targetDir);
    if (! $status) {
        return;
    }
    #==========================================
    # create the container configuration directory
    #------------------------------------------
    my $confDir = $this -> __createContainerConfigDir();
    if (! $confDir) {
        return;
    }
    #==========================================
    # write the configuration file
    #------------------------------------------
    $status = $this -> p_writeConfigFile($confDir);
    if (! $status) {
        return;
    }
    #==========================================
    # create the container tarball
    #------------------------------------------
    $status = $this -> __createContainerBundle();
    if (! $status) {
        return;
    }
    #==========================================
    # create a checksum file for the container
    #------------------------------------------
    $status = $this -> p_createChecksumFiles();
    if (! $status) {
        return;
    }
    #==========================================
    # clean up
    #------------------------------------------
    $status = $this -> __cleanupWorkingDir();
    if (! $status) {
        return;
    }
    return $this -> p_getCreatedFiles();
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __applyContainerConfig
#------------------------------------------
sub __applyContainerConfig {
    # ...
    # Apply container configuration settings
    # ---
    my $this      = shift;
    my $targetDir = shift;
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    $kiwi -> info('Setup container configuration');
    #==========================================
    # Create empty fstab file
    #------------------------------------------
    my $rm = $locator -> getExecPath('rm');
    my $cmd = "$rm $targetDir/etc/fstab";
    my $data = KIWIQX::qxx ($cmd);
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed();
        $kiwi -> error("Could not remove: $targetDir/etc/fstab");
        $kiwi -> failed();
        return;
    }
    my $touch = $locator -> getExecPath('touch');
    $cmd = "$touch $targetDir/etc/fstab";
    $data = KIWIQX::qxx ($cmd);
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed();
        $kiwi -> error("Could not create empty: $targetDir/etc/fstab");
        $kiwi -> failed();
        return;
    }
    #==========================================
    # disable yast->bootloader (clobber the file if it exists)
    #------------------------------------------
    my $config = 'LOADER_TYPE="none"' . "\n"
        . 'LOADER_LOCATION="none"' . "\n";
    my $status = open (my $BTLD, '>', "$targetDir/etc/sysconfig/bootloader");
    if (! $status) {
        $kiwi -> failed();
        my $msg = 'Could not write bootloader config: '
            . "$targetDir/etc/sysconfig/bootloader";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    binmode $BTLD;
    print $BTLD $config;
    close $BTLD;
    #==========================================
    # disable rootfs check  (clobber the file if it exists)
    #------------------------------------------
    $config = 'ROOTFS_FSCK="0"' . "\n"
        . 'ROOTFS_BLKDEV="/dev/null"' . "\n";
    $status = open (my $BOOT, '>', "$targetDir/etc/sysconfig/boot");
    if (! $status) {
        $kiwi -> failed();
        my $msg = 'Could not write boot config: '
            . "$targetDir/etc/sysconfig/boot";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    binmode $BOOT;
    print $BOOT $config;
    close $BOOT;
    #==========================================
    # add console to securetty to allow login
    #------------------------------------------
    my $ttyfd = FileHandle -> new();
    if (! $ttyfd -> open(">>$targetDir/etc/securetty")) {
        $kiwi -> failed();
        $kiwi -> error ("Could not open $targetDir/etc/securetty: $!");
        $kiwi -> failed();
        return;
    }
    print $ttyfd "console"."\n";
    $ttyfd -> close();
    $kiwi -> done();
    return 1;
}

#==========================================
# __cleanupWorkingDir
#------------------------------------------
sub __cleanupWorkingDir {
    # ...
    # Remove the tmp lxc root directory
    # ---
    my $this    = shift;
    my $dirToRm = shift;
    my $kiwi = $this->{kiwi};
    $kiwi -> info('Clean up intermediate working directory');
    my $baseWork = $this -> p_getBaseWorkingDir();
    if (! $dirToRm && $baseWork) {
        my $cmdL = $this->{cmdL};
        $dirToRm = $this -> getBaseBuildDirectory() . '/' . $baseWork;
    }
    if ($dirToRm) {
        my $data = KIWIQX::qxx ("rm -rf $dirToRm");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            $kiwi -> error("Could not remove: $dirToRm");
            $kiwi -> failed();
            return;
        }
    }
    $kiwi -> done();
    return 1;
}

#==========================================
# __copyUnpackedTreeContent
#------------------------------------------
sub __copyUnpackedTreeContent {
    # ...
    # Copy the unpacked image tree content to the given target directory
    # ---
    my $this      = shift;
    my $targetDir = shift;
    my $cmdL = $this->{cmdL};
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    $kiwi -> info('Copy unpacked image tree');
    my $origin = $cmdL -> getConfigDir();
    my $tar = $locator -> getExecPath('tar');
    my $cmd = "rsync -aHXA --one-file-system $origin/ $targetDir 2>&1";
    my $data = KIWIQX::qxx ($cmd);
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed();
        $kiwi -> error('Could not copy the unpacked image tree data');
        $kiwi -> failed();
        return;
    }
    $kiwi -> done();
    return 1;
}

#==========================================
# __createContainerBundle
#------------------------------------------
sub __createContainerBundle {
    # ...
    # Create a tarball of the container
    # ---
    my $this      = shift;
    my $cmdL = $this->{cmdL};
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    my $xml  = $this->{xml};
    my $type = $xml -> getImageType();
    my $imageType = $type -> getTypeName();
    my $extension = '-lxc';
    $kiwi -> info('Creating container tarball...');
    if ($imageType eq 'docker') {
        $extension = '-docker';
    } elsif ($imageType eq 'aci') {
        $extension = '';
    }
    my $baseBuildDir = $this -> getBaseBuildDirectory();
    my $origin = $baseBuildDir
        . '/'
        . $this -> p_getBaseWorkingDir();
    my $globals = KIWIGlobals -> instance();
    my $imgFlName = $globals -> generateBuildImageName(
        $xml, '-', $extension
    );
    if ($imageType eq 'aci') {
        $imgFlName .= '.aci';
    } else {
        $imgFlName .= '.tar.xz';
    }
    my $tar = $locator -> getExecPath('tar');
    if (! $tar) {
        $kiwi -> failed();
        $kiwi -> error("Could not find tar utility");
        $kiwi -> failed();
        return;
    }
    my @dirlist;
    if (opendir my($dh), $origin) {
        @dirlist = grep { !/^\.\.?$/x } readdir $dh;
        closedir $dh;
    } else {
        $kiwi -> failed();
        $kiwi -> error("Couldn't open dir $origin: $!");
        $kiwi -> failed();
        return;
    }
    if (! @dirlist) {
        $kiwi -> failed();
        $kiwi -> error("Got empty dirlist");
        $kiwi -> failed();
        return;
    }
    my $data = KIWIQX::qxx (
        "$tar -C $origin -cJf $baseBuildDir/$imgFlName @dirlist 2>&1"
    );
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed();
        $kiwi -> error("Could not create tarball $baseBuildDir/$imgFlName");
        $kiwi -> failed();
        $kiwi -> error($data);
        return;
    }
    $this -> p_addCreatedFile($imgFlName);
    $kiwi -> done();
    return 1;
}

#==========================================
# __createContainerConfigDir
#------------------------------------------
sub __createContainerConfigDir {
    # ...
    # Create the directory for the container configuration file
    # ---
    my $this = shift;
    my $cmdL = $this->{cmdL};
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    my $xml = $this->{xml};
    my $msg;
    $kiwi -> info("Creating container configuration directory\n");
    # Build the directory name
    my $dirPath = 'etc/lxc';
    my $type = $xml -> getImageType();
    my $containerName = $type -> getContainerName();
    my $imageType = $type -> getTypeName();
    if ($imageType eq "lxc") {
        if (! $containerName) {
            $msg = 'KIWIContainerBuilder:__createContainerConfigDir '
                . 'internal error no container name found. Please file a bug.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        $dirPath .= '/'.$containerName;
    } elsif ($imageType eq 'aci') {
        $dirPath = './';
    }
    my $path = $this -> __createWorkingDir($dirPath);
    $kiwi -> info ("--> $dirPath");
    if (! $path) {
        $kiwi -> failed();
        return;
    }
    $kiwi -> done();
    return $path;
}

#==========================================
# __createDevNodes
#------------------------------------------
sub __createDevNodes {
    # ...
    # Create the device nodes we need inside a container
    # ---
    my $this      = shift;
    my $targetDir = shift;
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    $kiwi -> info('Creating container device nodes');
    #==========================================
    # Create directories in dev
    #------------------------------------------
    my $mdir = $locator -> getExecPath('mkdir');
    if (! -d "$targetDir/dev/net") {
        my $data = KIWIQX::qxx ("$mdir -m 755 $targetDir/dev/net");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            my $msg = "Could not create device directory: $targetDir/dev/net";
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    if (! -d "$targetDir/dev/pts") {
        my $data = KIWIQX::qxx ("$mdir -m 755 $targetDir/dev/pts");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            my $msg = "Could not create device directory: $targetDir/dev/pts";
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    if (! -d "$targetDir/dev/shm") {
        my $data = KIWIQX::qxx ("$mdir -m 1777 $targetDir/dev/shm");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            my $msg = "Could not create device directory: $targetDir/dev/shm";
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    #==========================================
    # Create device nodes in dev
    #------------------------------------------
    my @nodes666 = (
        'full',
        'net/tun',
        'null',
        'ptmx',
        'random',
        'tty',
        'tty0',
        'tty1',
        'tty2',
        'tty3',
        'tty4',
        'urandom'
    );
    my %nodes666NumMap = (
        'full'    => 'c 1 7',
        'net/tun' => 'c 10 200',
        'null'    => 'c 1 3',
        'ptmx'    => 'c 5 2',
        'random'  => 'c 1 8',
        'tty'     => 'c 5 0',
        'tty0'    => 'c 4 0',
        'tty1'    => 'c 4 1',
        'tty2'    => 'c 4 2',
        'tty3'    => 'c 4 3',
        'tty4'    => 'c 4 4',
        'urandom' => 'c 1 9'
    );
    my $mnode = $locator -> getExecPath('mknod');
    for my $node (@nodes666) {
        if (! -e "$targetDir/dev/$node") {
            my $cmd = "$mnode -m 666 $targetDir/dev/$node "
                . $nodes666NumMap{$node};
            my $data = KIWIQX::qxx ($cmd);
            my $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> failed();
                my $msg = 'Could not create device node: '
                    . "$targetDir/dev/$node";
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    if (! -e "$targetDir/dev/console") {
        my $cmd = "$mnode -m 600 $targetDir/dev/console c 5 1";
        my $data = KIWIQX::qxx ($cmd);
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            my $msg = 'Could not create console device: '
                . "$targetDir/dev/console";
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    #==========================================
    # Create device links in dev
    #------------------------------------------
    my $lnk = $locator -> getExecPath('ln');
    if (! -e "$targetDir/dev/core") {
        my $cmd = "$lnk -s /proc/kcore $targetDir/dev/core";
        my $data = KIWIQX::qxx ($cmd);
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            my $msg = 'Could not create dev/core link to /proc/kcore';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    if (! -e "$targetDir/dev/fd") {
        my $cmd = "$lnk -s /proc/self/fd $targetDir/dev/fd";
        my $data = KIWIQX::qxx ($cmd);
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            my $msg = 'Could not create dev/fd link to /proc/self/fd';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    if (! -e "$targetDir/dev/tty10") {
        my $cmd = "$lnk -s null $targetDir/dev/tty10";
        my $data = KIWIQX::qxx ($cmd);
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed();
            my $msg = 'Could not create dev/tty10 link to null';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    $kiwi -> done();
    return 1;
}

#==========================================
# __createInitTab
#------------------------------------------
sub __createInitTab {
    # ...
    # Create an inittab file for the container
    # ---
    my $this      = shift;
    my $targetDir = shift;
    my $kiwi = $this->{kiwi};
    $kiwi -> info('Create container inittab');
    my $inittab = 'id:3:initdefault:' . "\n"
        . 'si::bootwait:/etc/init.d/boot' . "\n"
        . 'l0:0:wait:/etc/init.d/rc 0' . "\n"
        . 'l1:1:wait:/etc/init.d/rc 1' . "\n"
        . 'l2:2:wait:/etc/init.d/rc 2' . "\n"
        . 'l3:3:wait:/etc/init.d/rc 3' . "\n"
        . 'l6:6:wait:/etc/init.d/rc 6' . "\n"
        . 'ls:S:wait:/etc/init.d/rc S' . "\n"
        . '~~:S:respawn:/sbin/sulogin' . "\n"
        . 'p6::ctrlaltdel:/sbin/init 6' . "\n"
        . 'p0::powerfail:/sbin/init 0' . "\n"
        . 'cons:2345:respawn:/sbin/mingetty --noclear console screen' . "\n"
        . 'c1:2345:respawn:/sbin/mingetty --noclear tty1 screen' . "\n";
    my $status = open (my $INTT, '>', "$targetDir/etc/inittab");
    if (! $status) {
        $kiwi -> failed();
        my $msg = 'Could not write new inittab: '
            . "$targetDir/etc/inittab";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    binmode $INTT;
    print $INTT $inittab;
    close $INTT;

    $kiwi -> done();
    return 1;
}

#==========================================
# __createTargetRootTree
#------------------------------------------
sub __createTargetRootTree {
    # ...
    # Create the directory that will hold the container rootfs
    # ---
    my $this = shift;
    my $cmdL = $this->{cmdL};
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    my $xml  = $this->{xml};
    my $dirPath;
    my $msg;
    $kiwi -> info('Creating rootfs target directory');
    # Build the directory name
    my $type = $xml -> getImageType();
    my $imageType = $type -> getTypeName();
    if ($imageType eq 'lxc') {
        $dirPath = 'var/lib/lxc/';
        my $containerName = $type -> getContainerName();
        if (! $containerName) {
            $kiwi -> failed();
            $msg = 'KIWIContainerBuilder:__createTargetRootTree '
                . 'internal error no container name found. Please file a bug.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        $dirPath .= $containerName . '/rootfs';
    } elsif ($imageType eq 'aci') {
        $dirPath = 'rootfs';
    }
    my $path = $this -> __createWorkingDir($dirPath);
    if (! $path) {
        $kiwi -> failed();
        return;
    }
    $kiwi -> done();
    return $path;
}

#==========================================
# __createWorkingDir
#------------------------------------------
sub __createWorkingDir {
    # ...
    # Create a directory to tmp store the lxc root tree
    # ---
    my $this = shift;
    my $path = shift;
    my $cmdL = $this->{cmdL};
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    my $basePath = $this -> getBaseBuildDirectory();
    my $baseWork = $this -> p_getBaseWorkingDir();
    my $dirPath;
    if (! $baseWork) {
        return $basePath;
    }
    if ($path) {
        $dirPath = $basePath . '/' . $baseWork . '/' . $path;
    } else {
        $dirPath = $basePath . '/' . $baseWork;
    }
    my $mdir = $locator -> getExecPath('mkdir');
    my $data = KIWIQX::qxx ("$mdir -p $dirPath");
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error("Could not create directory: $dirPath");
        $kiwi -> failed();
        return;
    }
    return $dirPath;
}

#==========================================
# __disableServices
#------------------------------------------
sub __disableServices {
    # ...
    # Disable service we do not want to have running in a container
    # ---
    my $this      = shift;
    my $targetDir = shift;
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    $kiwi -> info("Disable unwanted services\n");
    my $sysctl = $locator -> getExecPath('systemctl', $targetDir);
    my $ins = $locator -> getExecPath('chkconfig', $targetDir);
    my $croot = $locator -> getExecPath('chroot');
    if (defined $sysctl) {
        my @srvs = qw (
            device-mapper.service
            kbd.service
            swap.service
            udev.service
            proc-sys-fs-binfmt_misc.automount
        );
        my @locations = (
            '/lib/systemd/system/',
            '/usr/lib/systemd/system'
        );
        my @services;
        for my $srv (@srvs) {
            for my $loc (@locations) {
                my $service = $targetDir.'/'.$loc.'/'.$srv;
                if (-e $service) {
                    push @services, $service
                }
            }
        }
        for my $srvPath (@services) {
            my $name = basename($srvPath);
            my $data = KIWIQX::qxx ("ln -sf /dev/null $srvPath 2>&1");
            my $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> error ("--> Could not disable service: $name: $data");
                $kiwi -> failed();
                return;
            } else {
                $kiwi -> info ("--> Disabled: $name");
                $kiwi -> done();
            }
        }
    } elsif (defined $ins) {
        my @services = (
            'boot.clock',
            'boot.device-mapper',
            'boot.klog',
            'boot.swap',
            'boot.udev'
        );
        foreach my $service (@services) {
            my $data = KIWIQX::qxx(
                "$croot $targetDir $ins -f $service off"
            );
            my $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> error("--> Could not disable service: $service");
                $kiwi -> failed();
                return;
            } else {
                $kiwi -> info ("--> Disabled: $service");
                $kiwi -> done();
            }
        }
    }
    return 1;
}

#==========================================
# __removeKiwiBuildInfo
#------------------------------------------
sub __removeKiwiBuildInfo {
    # ...
    # Remove data that is inserted in the root tree for image building
    # ---
    my $this      = shift;
    my $targetDir = shift;
    my $kiwi = $this->{kiwi};
    my $locator = $this->{locator};
    $kiwi -> info('Clean up kiwi image build artifacts');
    # Remove the shell scripts
    my $rm = $locator -> getExecPath('rm');
    my $cmd = "$rm -f $targetDir/.kconfig $targetDir/.profile";
    my $data = KIWIQX::qxx ($cmd);
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> info("Unable to remove KIWI scripts in rootfs: $targetDir");
        $kiwi -> skipped();
    }
    # Remove the image build information
    $cmd = "$rm -rf $targetDir/image";
    $data = KIWIQX::qxx ($cmd);
    $code = $? >> 8;
    if ($code != 0) {
        my $msg = 'Unable to remove KIWI image information in rootfs: '
            . "$targetDir";
        $kiwi -> info($msg);
        $kiwi -> skipped();
    }
    $kiwi -> done();
    return 1;
}

1;
