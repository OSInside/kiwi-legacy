#================
# FILE          : KIWIBoot.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create a boot USB stick
#               : or boot cd from a previously created initrd
#               : image
#               :
#               :
# STATUS        : Development
#----------------
package KIWIBoot;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use FileHandle;
use File::Basename;
use File::Spec;
use Math::BigFloat;
use Config::IniFiles;
use Scalar::Util 'looks_like_number';

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIIsoLinux;
use KIWIQX;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create KIWIBoot object which is used to create bootable
    # media images like CD/DVD's , USB sticks or Virtual disks
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
    my $initrd = shift;
    my $cmdL   = shift;
    my $system = shift;
    my $vmsize = shift;
    my $device = shift;
    my $profile= shift;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $global    = KIWIGlobals -> instance();
    my $syszip    = 0;
    my $sysird    = 0;
    my $zipped    = 0;
    my $firmware  = "bios";
    my $vga       = "0x314";
    my $haveTree  = 0;
    my $haveSplit = 0;
    my $vmmbyte;
    my $kernel;
    my $knlink;
    my $tmpdir;
    my $loopdir;
    my $boot_mount_point;
    my $result;
    my $status;
    my $isxen;
    my $xendomain;
    my $xengz;
    my $xml;
    my %type;
    #==========================================
    # check initrd file parameter
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    if ((defined $initrd) && (! -f $initrd)) {
        $kiwi -> error  ("Couldn't find initrd file: $initrd");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # check for split system
    #------------------------------------------
    if (($system) && (-f "$system/rootfs.tar")) {
        $kiwi -> error ("Can't use split root tree, run create first");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # find image type from buildinfo
    #------------------------------------------
    if (($system) && (! defined $cmdL->getBuildType())) {
        my $result_dir = dirname($initrd);
        my $buildinfo_file = $result_dir.'/kiwi.buildinfo';
        if (! -f $buildinfo_file) {
            $kiwi -> error (
                "Can't find buildinfo file in image result at: $result_dir"
            );
            $kiwi -> failed ();
            return;
        }
        my $buildinfo = Config::IniFiles -> new (
            -file => $buildinfo_file, -allowedcommentchars => '#'
        );
        my $imagetype = $buildinfo->val('main','image.type');
        if (! $imagetype) {
            $kiwi -> error (
                "Can't find image type in buildinfo file: $buildinfo_file"
            );
            $kiwi -> failed ();
            return;
        }
        if ($imagetype eq 'split') {
            $haveSplit = 1;
        }
        $cmdL -> setBuildType($imagetype);
    }
    #==========================================
    # check system image file parameter
    #------------------------------------------
    if (defined $system) {
        if ((-f $system) || (-b $system)) {
            my %fsattr = KIWIGlobals
                -> instance()
                -> checkFileSystem ($system);
            if ($fsattr{readonly}) {
                $syszip = KIWIGlobals -> instance() -> isize ($system);
            } else {
                $syszip = 0;
            }
        } elsif (! -d $system) {
            $kiwi -> error  ("Couldn't find image file/directory: $system");
            $kiwi -> failed ();
            return;
        } elsif (-f "$system/kiwi-root.cow") {
            #==========================================
            # Check for overlay structure
            #------------------------------------------
            $this->{overlay} = KIWIOverlay -> new($system);
            if (! $this->{overlay}) {
                return;
            }
            $system = $this->{overlay} -> mountOverlay();
            if (! -d $system) {
                return;
            }
        }
    }
    #==========================================
    # check if we got the tree or image file
    #------------------------------------------
    if (($system) && (-d $system)) {
        $haveTree = 1;
    }
    #==========================================
    # compressed initrd used...
    #------------------------------------------
    if (($initrd) && ($initrd =~ /\.(g|x)z$/)) {
        $zipped = 1;
    }
    #==========================================
    # find kernel file
    #------------------------------------------
    $kernel = $initrd;
    if (($kernel) && ($kernel =~ /(g|x)z$/)) {
        $kernel =~ s/(g|x)z$/kernel/;
    } else {
        $kernel = $kernel.".kernel";
    }
    if (! -e $kernel) {
        $kernel =~ s/splash\.kernel$/kernel/;
    }
    if (-l $kernel) {
        $knlink = $kernel;
        $kernel = readlink ($knlink);
        if (!File::Spec->file_name_is_absolute($kernel)) {
            $kernel = File::Spec->catfile(dirname($initrd), $kernel);
        }
    }
    if ((defined $initrd) && (! -f $kernel)) {
        $kiwi -> error  ("Couldn't find kernel file: $kernel");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Store pointer to global values
    #------------------------------------------
    $this->{gdata} = $global -> getKiwiConfig();
    #==========================================
    # check if Xen system is used
    #------------------------------------------
    ($xengz, $isxen) = $global -> isXen ($initrd);
    #==========================================
    # create tmp dir for operations
    #------------------------------------------
    $tmpdir = KIWIQX::qxx ("mktemp -qdt kiwiboot.XXXXXX");
    chomp $tmpdir;
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
        $kiwi -> failed ();
        return;
    }
    $loopdir = KIWIQX::qxx ("mktemp -qdt kiwiloop.XXXXXX");
    chomp $loopdir;
    $result  = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $loopdir: $!");
        $kiwi -> failed ();
        return;
    }
    $boot_mount_point = KIWIQX::qxx ("mktemp -qdt kiwiboot.XXXXXX");
    chomp $boot_mount_point;
    $result  = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $boot_mount_point: $!");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Store object data (1)
    #------------------------------------------
    $this->{cleanupStack} = [];
    $this->{tmpdir}   = $tmpdir;
    $this->{loopdir}  = $loopdir;
    $this->{bootmountpoint} = $boot_mount_point;
    $this->{tmpdirs}  = [ $tmpdir, $loopdir, $boot_mount_point ];
    $this->{haveTree} = $haveTree;
    $this->{kiwi}     = $kiwi;
    $this->{bootsize} = 100;
    $this->{isDisk}   = 0;
    #==========================================
    # read XML from given image file or path
    #------------------------------------------
    if ($system) {
        my %read_result = $global -> readXMLFromImage (
            $system, $cmdL, $tmpdir
        );
        if (! %read_result) {
            return;
        }
        if ($read_result{xml}) {
            $xml = $read_result{xml};
        }
        if ($read_result{sysz_size}) {
            $syszip = $read_result{sysz_size};
        }
        if ($read_result{originXMLPath}) {
            $this->{originXMLPath} = $read_result{originXMLPath};
        }
    }
    #==========================================
    # store systemdisk information
    #------------------------------------------
    if (defined $xml) {
        $this->{sysdisk} = $xml -> getSystemDiskConfig();
    }
    #==========================================
    # store type information
    #------------------------------------------
    if ($xml) {
        my $xmltype = $xml -> getImageType();
        if (! $xmltype) {
            return;
        }
        $type{lvm} = KIWIGlobals -> instance() -> useLVM($xml);
        $type{lvmgroup}               = "kiwiVG";
        $type{bootfilesystem}         = $xmltype -> getBootImageFileSystem();
        $type{bootloader}             = $xmltype -> getBootLoader();
        $type{bootpartition}          = $xmltype -> getBootPartition();
        $type{bootpartsize}           = $xmltype -> getBootPartitionSize();
        $type{boottimeout}            = $xmltype -> getBootTimeout();
        $type{cmdline}                = $xmltype -> getKernelCmdOpts();
        $type{filesystem}             = $xmltype -> getFilesystem();
        $type{firmware}               = $xmltype -> getFirmwareType();
        $type{fsmountoptions}         = $xmltype -> getFSMountOptions();
        $type{fsnocheck}              = $xmltype -> getFSNoCheck();
        $type{installboot}            = $xmltype -> getInstallBoot();
        $type{installiso}             = $xmltype -> getInstallIso();
        $type{installprovidefailsafe} = $xmltype -> getInstallProvideFailsafe();
        $type{installpxe}             = $xmltype -> getInstallPXE();
        $type{installstick}           = $xmltype -> getInstallStick();
        $type{luks}                   = $xmltype -> getLuksPass();
        $type{luksOS}                 = $xmltype -> getLuksOS();
        $type{mdraid}                 = $xmltype -> getMDRaid();
        $type{type}                   = $xmltype -> getTypeName();
        $type{vga}                    = $xmltype -> getVGA();
        $type{volid}                  = $xmltype -> getVolID();
        if (! $type{filesystem}) {
            my $fsro = $xmltype -> getFSReadOnly();
            my $fsrw = $xmltype -> getFSReadWrite();
            if (($fsro) && ($fsrw)) {
                $type{filesystem} = "$fsrw,$fsro";
            }
        }
        if ($this->{sysdisk}) {
            $type{lvmgroup} = $this->{sysdisk} -> getVGName();
        }
    }
    #==========================================
    # find Xen domain configuration
    #------------------------------------------
    if ($isxen && defined $xml) {
        my $vconf = $xml -> getVMachineConfig();
        if ($vconf) {
            $xendomain = $vconf -> getDomain();
        }
        if (! $xendomain) {
            $xendomain = "dom0";
        }
    }
    #==========================================
    # Setup disk size and inode count
    #------------------------------------------
    if ((defined $system) && (defined $initrd)) {
        my $sizeBytes;
        my $minInodes;
        my $sizeXMLBytes = 0;
        my $fsoverhead   = 1.2;
        my $fsopts       = $cmdL -> getFilesystemOptions();
        my $inodesize    = $fsopts -> getInodeSize();
        my $inoderatio   = $fsopts -> getInodeRatio();
        my $kernelSize   = KIWIGlobals -> instance() -> isize ($kernel);
        my $initrdSize   = KIWIGlobals -> instance() -> isize ($initrd);
        #==========================================
        # Calculate minimum size of the system
        #------------------------------------------
        if (-d $system) {
            # System is specified as a directory...
            $minInodes = KIWIQX::qxx ("find $system | wc -l");
            $sizeBytes = KIWIGlobals -> instance() -> dsize ($system);
            $sizeBytes*= $fsoverhead;
            chomp $minInodes;
            chomp $sizeBytes;
            $minInodes*= 2;
            $sizeBytes+= $minInodes * $inodesize;
            $sizeBytes+= $kernelSize;
            $sizeBytes+= $initrdSize;
        } else {
            # system is specified as a file...
            $sizeBytes = KIWIGlobals -> instance() -> isize ($system);
            $sizeBytes+= $kernelSize;
            $sizeBytes+= $initrdSize;
        }
        #==========================================
        # Store optional size setup from XML
        #------------------------------------------
        my $sizeXMLAddBytes = $xml -> getImageType()
            -> getImageSizeAdditiveBytes();
        if ($sizeXMLAddBytes) {
            $sizeXMLBytes = $sizeBytes + $sizeXMLAddBytes;
        } else {
            $sizeXMLBytes = $xml -> getImageType()
                -> getImageSizeBytes();
        }
        #==========================================
        # Store initial disk size
        #------------------------------------------
        $this -> __initDiskSize ($sizeBytes,$vmsize,$sizeXMLBytes);
        #==========================================
        # Calculate required inode count for root
        #------------------------------------------
        if (-d $system) {
            # /.../
            # if the system is a directory the root filesystem
            # will be created during the image creation. In this
            # case we need to create the inode count
            # ----
            my $buildType = $xml -> getImageType() -> getTypeName();
            if (($sizeXMLBytes ne 'auto') && ($buildType eq 'vmx')) {
                # calculate inodes according to requested size for vmx type
                $this->{inodes} = int ($sizeXMLBytes / $inoderatio);
            } else {
                # calculate inodes for required min size
                $this->{inodes} = int ($this->{vmmbyte}*1048576 / $inoderatio);
            }
            $kiwi -> loginfo (
                "Using ".$this->{inodes}." inodes for the root filesystem\n"
            );
        }
    }
    #==========================================
    # round compressed image size
    #------------------------------------------
    if ($syszip) {
        $syszip = $syszip / 1e6;
        $syszip = sprintf ("%.0f", $syszip);
    }
    #==========================================
    # Store a disk label ID for this object
    #------------------------------------------
    $this->{mbrid} = KIWIGlobals -> instance() -> getMBRDiskLabel (
        $cmdL -> getMBRID()
    );
    #==========================================
    # find system architecture
    #------------------------------------------
    my $arch = KIWIGlobals -> instance() -> getArch();
    if (defined $xml) {
        #==========================================
        # check framebuffer vga value
        #------------------------------------------
        if ($type{vga}) {
            $vga = $type{vga};
        }
        if ($type{luks}) {
            KIWIGlobals
            -> instance()
            -> setKiwiConfigData ("LuksCipher",$type{luks});
        }
        #==========================================
        # check boot firmware
        #------------------------------------------
        if ($type{firmware}) {
            $firmware = $type{firmware};
        }
        if (($firmware eq 'uefi') && ($arch ne 'x86_64')) {
            $kiwi -> warning (
                "UEFI Secure boot is only supported on x86_64"
            );
            $kiwi -> skipped();
            $kiwi -> warning (
                "--> switching to non secure EFI boot\n"
            );
            $firmware = 'efi';
        }
    }
    #==========================================
    # set the bootloader
    #------------------------------------------
    my $bootloader = "grub2";
    if ($type{bootloader}) {
        $bootloader = $type{bootloader};
    }
    #==========================================
    # check partitioner
    #------------------------------------------
    my $ptool;
    if (defined $xml) {
        # lookup partitioner from XML description
        my $preferences = $xml -> getPreferences();
        if ($preferences) {
            $ptool = $preferences -> getPartitioner();
        }
        my $type = $xml -> getImageType();
        if ($type) {
            my $zipl_target = $type -> getZiplTargetType();
            if (($zipl_target) && ($zipl_target =~ /LDL|CDL/)) {
                $ptool = 'fdasd';
            }
        }
    }
    if ($cmdL -> getPartitioner()) {
        # commandline specified partitioner overwrites all
        $ptool = $cmdL -> getPartitioner();
    }
    if (! $ptool) {
        # use default partitioner if no value is set
        $ptool = $this->{gdata}->{Partitioner};
    }
    #==========================================
    # Store object data (2)
    #------------------------------------------
    $this->{initrd}    = $initrd;
    $this->{system}    = $system;
    $this->{kernel}    = $kernel;
    $this->{syszip}    = $syszip;
    $this->{device}    = $device;
    $this->{zipped}    = $zipped;
    $this->{isxen}     = $isxen;
    $this->{xengz}     = $xengz;
    $this->{arch}      = $arch;
    $this->{bootloader}= $bootloader;
    $this->{ptool}     = $ptool;
    $this->{vga}       = $vga;
    $this->{xml}       = $xml;
    $this->{cmdL}      = $cmdL;
    $this->{xendomain} = $xendomain;
    $this->{profile}   = $profile;
    $this->{haveSplit} = $haveSplit;
    $this->{imgtype}   = $cmdL->getBuildType();
    $this->{chainload} = $cmdL->getGrubChainload();
    $this->{firmware}  = $firmware;
    $this->{type}      = \%type;
    return $this;
}

#==========================================
# createBootStructure
#------------------------------------------
sub createBootStructure {
    my $this   = shift;
    my $loc    = shift;
    my $kiwi   = $this->{kiwi};
    my $initrd = $this->{initrd};
    my $tmpdir = $this->{tmpdir};
    my $kernel = $this->{kernel};
    my $zipped = $this->{zipped};
    my $isxen  = $this->{isxen};
    my $xengz  = $this->{xengz};
    my $suf    = $this->{gdata}->{IrdZipperSuffix};
    my $zipper = $this->{gdata}->{IrdZipperCommand};
    my $xendomain = $this->{xendomain};
    my $lname  = "linux";
    my $iname  = "initrd";
    my $xname  = "xen.gz";
    my $status;
    my $result;
    if (defined $loc) {
        $lname  = $lname.".".$loc;
        $iname  = $iname.".".$loc;
    }
    if ($initrd !~ /splash\.$suf$|splash\.install\.$suf/) {
        $initrd = KIWIGlobals -> instance() -> setupSplash($initrd);
        $zipped = 1;
    }
    $kiwi -> info ("Creating initial boot structure");
    $status = KIWIQX::qxx ( "mkdir -p $tmpdir/boot 2>&1" );
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed creating initial directories: $status");
        $kiwi -> failed ();
        return;
    }
    if ($zipped) {
        $status = KIWIQX::qxx ("cp $initrd $tmpdir/boot/$iname 2>&1");
    } else {
        $status = KIWIQX::qxx ("cat $initrd | $zipper > $tmpdir/boot/$iname");
    }
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed importing initrd: $!");
        $kiwi -> failed ();
        return;
    }
    $status = KIWIQX::qxx ("cp $kernel $tmpdir/boot/$lname 2>&1");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed importing kernel: $!");
        $kiwi -> failed ();
        return;
    }
    if (($isxen) && ($xendomain eq "dom0")) {
        $status = KIWIQX::qxx ("cp $xengz $tmpdir/boot/$xname 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed importing Xen hypervisor: $!");
            $kiwi -> failed ();
            return;
        }
    }
    KIWIQX::qxx ("touch $tmpdir/boot/$this->{mbrid}");
    $kiwi -> done();
    return $tmpdir;
}

#==========================================
# setupInstallCD
#------------------------------------------
sub setupInstallCD {
    my $this      = shift;
    my $kiwi      = $this->{kiwi};
    my $arch      = $this->{arch};
    my $initrd    = $this->{initrd};
    my $system    = $this->{system};
    my $oldird    = $this->{initrd};
    my $zipped    = $this->{zipped};
    my $isxen     = $this->{isxen};
    my $xml       = $this->{xml};
    my $firmware  = $this->{firmware};
    my $global    = KIWIGlobals -> instance();
    my $md5name   = $system;
    my $destdir   = dirname ($initrd);
    my $gotsys    = 1;
    my $volid     = "KIWI CD/DVD Installation";
    my $appid     = $this->{mbrid};
    my $type      = $this->{type};
    my $status;
    my $result;
    my $tmpdir;
    my $haveDiskDevice;
    my $version;
    my $FD;
    my $hybrid;
    #==========================================
    # Overwrite bootloader with syslinux
    #------------------------------------------
    my $bootloader= "syslinux";
    #==========================================
    # Check for hybrid setup
    #------------------------------------------
    if ($xml) {
        $hybrid = $xml -> getImageType() -> getHybrid();
    }
    #==========================================
    # Check for disk device
    #------------------------------------------
    if (($system) && (-b $system)) {
        $haveDiskDevice = $system;
        $version = $xml -> getPreferences() -> getVersion();
        $system  = $xml -> getImageName();
        $system  = $destdir."/".$system.".".$arch."-".$version.".raw";
        $md5name = $system;
        $this->{system} = $system;
    }
    #==========================================
    # Create new MBR label for install ISO
    #------------------------------------------
    $this->{mbrid} = $global -> getMBRDiskLabel();
    $appid = $this->{mbrid};
    $kiwi -> info ("Using ISO Application ID: $appid");
    $kiwi -> done();
    #==========================================
    # check for volume id
    #------------------------------------------
    if ($type->{volid}) {
        $volid = $type->{volid};
    }
    #==========================================
    # create tmp directory
    #------------------------------------------
    my $basedir;
    if ($system) {
        $basedir = dirname ($system);
    } else {
        $basedir = dirname ($initrd);
    }
    $tmpdir = KIWIQX::qxx (
        "mktemp -q -d $basedir/kiwicdinst.XXXXXX"
    );
    chomp $tmpdir;
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
        $kiwi -> failed ();
        return;
    }
    $this->{tmpdir} = $tmpdir;
    push @{$this->{tmpdirs}},$tmpdir;
    #==========================================
    # check if initrd is zipped
    #------------------------------------------
    if (! $zipped) {
        $kiwi -> error  ("Compressed boot image required");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # check if system image is given
    #------------------------------------------
    if (! $system) {
        $system = $initrd;
        $gotsys = 0;
    }
    #==========================================
    # build label from xml data
    #------------------------------------------
    if ($gotsys) {
        $this->{bootlabel} = $xml -> getImageDisplayName();
    }
    #==========================================
    # Build md5sum of system image
    #------------------------------------------
    if ($gotsys) {
        if (! $haveDiskDevice) {
            $global -> buildMD5Sum ($system);
        } else {
            $global -> buildMD5Sum ($this->{loop},$system);
        }
    }
    #==========================================
    # Setup image basename
    #------------------------------------------
    my $namecd = basename ($system);
    #==========================================
    # Compress system image
    #------------------------------------------
    if ($gotsys) {
        $md5name =~ s/\.raw$/\.md5/;
        $kiwi -> info ("Compressing installation image...");
        $result = 0;
        my $locator = KIWILocator -> instance();
        if ($haveDiskDevice) {
            # /.../
            # Unfortunately mksquashfs can not use a block device as
            # input file so we have to create a file from the device
            # first and pass that to mksquashfs
            # ----
            my $qemu_img = $locator -> getExecPath ("qemu-img");
            if (! $qemu_img) {
                $kiwi -> failed ();
                $kiwi -> error  ("Mandatory qemu-img tool not found");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "$qemu_img convert -f raw -O raw $haveDiskDevice $system"
            );
            $result = $? >> 8;
        }
        if ($result == 0) {
            my $mk_squash = $locator -> getExecPath ("mksquashfs");
            if (! $mk_squash) {
                $kiwi -> failed ();
                $kiwi -> error  ("Mandatory mksquashfs tool not found");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "$mk_squash $system $md5name $system.squashfs -no-progress 2>&1"
            );
            $result = $? >> 8;
        }
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to compress system image: $status");
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
        $system = $system.".squashfs";
    }
    #==========================================
    # Setup initrd for install purpose
    #------------------------------------------
    $kiwi -> info ("Repack initrd with install flags...");
    $initrd = $this -> setupInstallFlags();
    if (! defined $initrd) {
        return;
    }
    $this->{initrd} = $initrd;
    $kiwi -> done();
    #==========================================
    # Create CD structure
    #------------------------------------------
    if (! $this -> createBootStructure()) {
        $this->{initrd} = $oldird;
        return;
    }
    #==========================================
    # Import boot loader stages
    #------------------------------------------
    if (! $this -> setupBootLoaderStages ($bootloader,'iso')) {
        return;
    }
    if (($firmware eq "efi") || ($firmware eq "uefi")) {
        if (! $this -> setupBootLoaderStages ('grub2','iso')) {
            return;
        }
    }
    KIWIQX::qxx ("rm -rf $tmpdir/usr 2>&1");
    KIWIQX::qxx ("rm -rf $tmpdir/image 2>&1");
    $this->{initrd} = $oldird;
    #==========================================
    # Creating boot loader configuration
    #------------------------------------------
    my $title = "KIWI CD Installation";
    if (! $gotsys) {
        $title = "KIWI CD Boot: $namecd";
    }
    if (! $this -> setupBootLoaderConfiguration (
        $bootloader,$title,undef,"ISO")
    ) {
        return;
    }
    if (($firmware eq "efi") || ($firmware eq "uefi")) {
        if (! $this -> setupBootLoaderConfiguration (
            'grub2',$title,undef,"ISO")
        ) {
            return;
        }
    }
    #==========================================
    # Check for optional config-cdroot archive
    #------------------------------------------
    my $cdrootData = "config-cdroot.tgz";
    if (-f "$destdir/$cdrootData") {
        $kiwi -> info ("Integrating CD root information...");
        $status= KIWIQX::qxx (
            "tar -C $tmpdir -xvf $destdir/$cdrootData"
        );
        $result= $? >> 8;
        KIWIQX::qxx ("rm -f $destdir/$cdrootData");
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to integrate CD root data: $status");
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
    }
    #==========================================
    # Check for optional config-cdroot.sh
    #------------------------------------------
    my $cdrootScript = "config-cdroot.sh";
    if (-x "$destdir/$cdrootScript") {
        $kiwi -> info ("Calling CD root setup script...");
        my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
        my $script = "$destdir/$cdrootScript";
        if ($script !~ /^\//) {
            $script = $pwd."/".$script;
        }
        $status = KIWIQX::qxx (
            "cd $tmpdir && bash -c $script 2>&1"
        );
        $result = $? >> 8;
        KIWIQX::qxx ("rm -f $script");
        if ($result != 0) {
            chomp $status;
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to call CD root script: $status");
            $kiwi -> failed ();
            return;
        } else {
            $kiwi -> loginfo ("config-cdroot.sh: $status");
        }
        $kiwi -> done();
    }
    #==========================================
    # Copy system image if given
    #------------------------------------------
    if ($gotsys) {
        my $FD;
        if (! open ($FD,'>',"$tmpdir/config.isoclient")) {
            $kiwi -> error  ("Couldn't create CD install flag file");
            $kiwi -> failed ();
            return;
        }
        print $FD "IMAGE='".$namecd."'\n";
        close $FD;
        $kiwi -> info ("Importing system image: $system");
        $status = KIWIQX::qxx ("mv $system $tmpdir 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed importing system image: $status");
            $kiwi -> failed ();
            return;
        }
        $system =~ s/\.squashfs$//;
        $kiwi -> done();
    }
    #==========================================
    # copy grub2 config file to efi path too
    #------------------------------------------
    if (($firmware eq "efi") || ($firmware eq "uefi")) {
        KIWIQX::qxx ("mkdir -p $tmpdir/EFI/BOOT");
        KIWIQX::qxx ("cp $tmpdir/boot/grub2/grub.cfg $tmpdir/EFI/BOOT");
        # add compatibility link for non standard EFI firmware
        KIWIQX::qxx ("ln -s $tmpdir/EFI/BOOT $tmpdir/EFI/Boot");
    }
    #==========================================
    # Store arch name used by iso
    #------------------------------------------
    my $isoarch = KIWIQX::qxx ("uname -m"); chomp $isoarch;
    if ($isoarch =~ /i.86/) {
        $isoarch = "i386";
    }
    #==========================================
    # Create an iso image from the tree
    #------------------------------------------
    $kiwi -> info ("Creating install ISO image...\n");
    my $isoerror = 1;
    my $name = $system;
    if ($gotsys) {
        $name =~ s/raw$/install\.iso/;
    } else {
        $name =~ s/gz$/install\.iso/;
    }
    my $base;
    my $opts;
    # turn sys/extlinux configuation into a isolinux configuration...
    my $cfg_ext = "$tmpdir/boot/syslinux/syslinux.cfg";
    if (! -f $cfg_ext) {
        $cfg_ext = "$tmpdir/boot/syslinux/extlinux.conf";
    }
    # move files into suse official iso data structure
    my $cfg_iso = "$tmpdir/boot/syslinux/isolinux.cfg";
    KIWIQX::qxx ("mkdir -p $tmpdir/boot/$isoarch");
    KIWIQX::qxx ("mv $cfg_ext $cfg_iso 2>&1");
    KIWIQX::qxx ("ln $tmpdir/boot/initrd $tmpdir/boot/syslinux");
    KIWIQX::qxx ("ln $tmpdir/boot/linux  $tmpdir/boot/syslinux");
    if (-e "$tmpdir/boot/xen.gz") {
        KIWIQX::qxx ("ln $tmpdir/boot/xen.gz  $tmpdir/boot/syslinux");
    }
    KIWIQX::qxx ("mv $tmpdir/boot/syslinux $tmpdir/boot/$isoarch/loader");
    #==========================================
    # setup ISO options
    #------------------------------------------
    my $attr = "-R -J -f -pad -joliet-long";
    if (-s $system >= 4294967296) {
        # install image is bigger than 4g, needs extra iso options
        $attr .= " -allow-limited-size -udf -hfs -iso-level 3";
    }
    $attr .= " -V \"$volid\"";
    $attr .= " -A \"$this->{mbrid}\"";
    $attr .= ' -p "'.$this->{gdata}->{Preparer}.'"';
    #==========================================
    # create ISO
    #------------------------------------------
    my $wdir = KIWIQX::qxx ("pwd");
    chomp $wdir;
    if ($name !~ /^\//) {
        $name = $wdir."/".$name;
    }
    my $iso = KIWIIsoLinux -> new (
        $tmpdir,$name,$attr,"checkmedia",$this->{cmdL},$this->{xml}
    );
    if (defined $iso) {
        $isoerror = 0;
        if (! $iso -> makeIsoEFIBootable()) {
            $isoerror = 1;
        }
        if (! $iso -> callBootMethods()) {
            $isoerror = 1;
        }
        if (! $iso -> addBootLive()) {
            $isoerror = 1;
        }
        if (! $iso -> createISO()) {
            $isoerror = 1;
        }
    }
    if ($isoerror) {
        $iso  -> cleanISO ();
        return;
    }
    #==========================================
    # relocate boot catalog
    #------------------------------------------
    if (! $iso -> relocateCatalog ()) {
        $iso  -> cleanISO ();
        return;
    }
    if (! $iso -> fixCatalog()) {
        $iso  -> cleanISO ();
        return;
    }
    #==========================================
    # Turn ISO into hybrid if requested
    #------------------------------------------
    if (($hybrid) && ($hybrid eq "true")) {
        $kiwi -> info ("Setting up hybrid install ISO...\n");
        if (! $iso -> createHybrid ($this->{mbrid})) {
            $kiwi -> error  ("Failed to create hybrid ISO image");
            $kiwi -> failed ();
            $iso  -> cleanISO ();
            return;
        }
    }
    #==========================================
    # Clean tmp
    #------------------------------------------
    KIWIQX::qxx ("rm -rf $tmpdir");
    my $imgfile = basename $name;
    $kiwi -> info ("Created $imgfile to be burned on CD");
    $kiwi -> done ();
    $iso  -> cleanISO ();
    return $this;
}

#==========================================
# setupInstallStick
#------------------------------------------
sub setupInstallStick {
    my $this      = shift;
    my $kiwi      = $this->{kiwi};
    my $arch      = $this->{arch};
    my $initrd    = $this->{initrd};
    my $system    = $this->{system};
    my $oldird    = $this->{initrd};
    my $device    = $this->{device};
    my $loopdir   = $this->{loopdir};
    my $zipped    = $this->{zipped};
    my $isxen     = $this->{isxen};
    my $xml       = $this->{xml};
    my $cmdL      = $this->{cmdL};
    my $firmware  = $this->{firmware};
    my $type      = $this->{type};
    my $bootloader= $this->{bootloader};
    my $bootsize  = $this -> __getBootSize ();
    my $global    = KIWIGlobals -> instance();
    my $vmsize    = $global -> isize ($system);
    my $md5name   = $system;
    my $destdir   = dirname ($initrd);
    my %deviceMap = ();
    my @commands  = ();
    my $gotsys    = 1;
    my $haveDiskDevice;
    my $status;
    my $result;
    my $version;
    my $tmpdir;
    my $stick;
    my $diskname;
    #==========================================
    # Clear image inode setup, use default
    #------------------------------------------
    undef $this->{inodes};
    #==========================================
    # Create new MBR label for install disk
    #------------------------------------------
    $this->{mbrid} = $global -> getMBRDiskLabel();
    #==========================================
    # Check for disk device
    #------------------------------------------
    if (($system) && (-b $system)) {
        $haveDiskDevice = $system;
        $version = $xml -> getPreferences() -> getVersion();
        $system  = $xml -> getImageName();
        $system  = $destdir."/".$system.".".$arch."-".$version.".raw";
        $md5name = $system;
        $this->{system} = $system;
    }
    #==========================================
    # create tmp directory
    #------------------------------------------
    $tmpdir = KIWIQX::qxx ("mktemp -qdt kiwistickinst.XXXXXX");
    chomp $tmpdir;
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
        $kiwi -> failed ();
        return;
    }
    $this->{tmpdir} = $tmpdir;
    push @{$this->{tmpdirs}},$tmpdir;
    #==========================================
    # check if initrd is zipped
    #------------------------------------------
    if (! $zipped) {
        $kiwi -> error  ("Compressed boot image required");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # check if system image is given
    #------------------------------------------
    if ($system) {
        $diskname = $system.".install.raw";
    } else {
        $system   = $initrd;
        $diskname = $initrd;
        $diskname =~ s/gz$/install\.raw/;
        $gotsys   = 0;
    }
    #==========================================
    # check for boot menu entry base name
    #------------------------------------------
    if ($gotsys) {
        $this->{bootlabel} = $xml -> getImageDisplayName();
    }
    #==========================================
    # Build md5sum of system image
    #------------------------------------------
    if ($gotsys) {
        if (! $haveDiskDevice) {
            $global -> buildMD5Sum ($system);
        } else {
            $global -> buildMD5Sum ($haveDiskDevice,$system);
        }
    }
    #==========================================
    # Check toolchain
    #------------------------------------------
    my $locator = KIWILocator -> instance();
    my $qemu_img = $locator -> getExecPath ("qemu-img");
    if (! $qemu_img) {
        $kiwi -> error  ("Mandatory qemu-img tool not found");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Compress system image
    #------------------------------------------
    if ($gotsys) {
        $md5name =~ s/\.raw$/\.md5/;
        $kiwi -> info ("Compressing installation image...");
        $result = 0;
        if ($haveDiskDevice) {
            $status = KIWIQX::qxx (
                "$qemu_img convert -f raw -O raw $haveDiskDevice $system"
            );
            $result = $? >> 8;
        }
        if ($result == 0) {
            my $mk_squash = $locator -> getExecPath ("mksquashfs");
            if (! $mk_squash) {
                $kiwi -> failed ();
                $kiwi -> error  ("Mandatory mksquashfs tool not found");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "$mk_squash $system $md5name $system.squashfs -no-progress 2>&1"
            );
            $result = $? >> 8;
        }
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to compress system image: $status");
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
        $system = $system.".squashfs";
        $vmsize = -s $system;
    }
    #==========================================
    # setup required disk size
    #------------------------------------------
    $vmsize = ($vmsize / 1e6) * 1.3 + $bootsize;
    $vmsize = sprintf ("%.0f", $vmsize);
    $vmsize = $vmsize."M";
    #==========================================
    # Setup image basename and partid file
    #------------------------------------------
    my $nameusb = basename ($system);
    my $partidfile = $diskname;
    $partidfile =~ s/\.raw.install.raw$/\.pids/;
    #==========================================
    # Create virtual disk to be dumped on stick
    #------------------------------------------
    $kiwi -> info ("Creating virtual disk...");
    $status = KIWIQX::qxx ("$qemu_img create $diskname $vmsize 2>&1");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed creating virtual disk: $status");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> done();
    $kiwi -> info ("Binding virtual disk to loop device");
    if (! $this -> bindDiskDevice ($diskname)) {
        $kiwi -> failed ();
        return;
    }
    $kiwi -> done();
    #==========================================
    # check required boot filesystem type
    #------------------------------------------
    my $bootfs = 'ext3';
    my $partid = "83";
    my $needBiosP  = 0;
    my $needPrepP  = 0;
    my $legacysize = 2;
    my $prepsize = 8;
    if ($bootloader eq 'syslinux') {
        $bootfs = 'fat32';
    } elsif ($bootloader eq 'yaboot') {
        $bootfs = 'fat16';
    } elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
        $bootfs = 'fat16';
    } elsif ( $firmware eq "ofw" ) {
        $needPrepP = 1;
    } else {
        $bootfs = 'ext3';
    }
    #==========================================
    # Do we need a bios legacy partition
    #------------------------------------------
    if (($arch =~ /i.86|x86_64/) &&
        (($firmware eq "efi") || ($firmware eq "uefi"))
    ) {
        $needBiosP = 1;
    }
    #==========================================
    # setup boot partition type
    #------------------------------------------
    if ($bootfs =~ /^fat/) {
        $partid = "c";
    }
    #==========================================
    # setup disk partitions
    #------------------------------------------
    $kiwi -> info ("Create partition table for install media");
    my $pnr = 0;    # partition number start for increment
    #==========================================
    # setup legacy bios_grub partition
    #------------------------------------------
    if ($needBiosP) {
        $pnr++;
        push @commands,"n","p:legacy",$pnr,".","+".$legacysize."M";
        $this->{partids}{biosgrub} = $pnr;
    }
    #==========================================
    # setup Power PReP partition
    #------------------------------------------
    if ($needPrepP) {
        $pnr++;
        push @commands,"n","p:prep",$pnr,".","+".$prepsize."M";
        push @commands,"t",$pnr,"41";
        push @commands,"a",$pnr;
        $this->{partids}{prep} = $pnr;
    }
    #==========================================
    # setup boot partition
    #------------------------------------------
    $pnr++;
    push @commands,"n","p:lxboot",$pnr,".","+".$bootsize."M";
    push @commands,"t",$pnr,$partid;
    push @commands,"a",$pnr;
    $this->{partids}{installboot} = $pnr;
    #==========================================
    # setup install partition
    #------------------------------------------
    if ($gotsys) {
        $pnr++;
        push @commands,"n","p:lxinstall",$pnr,".",".";
        $this->{partids}{installroot} = $pnr;
    }
    push @commands,"w","q";
    #==========================================
    # create partition table
    #------------------------------------------
    if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create partition table");
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    #==========================================
    # create bios_grub flag
    #------------------------------------------
    if ($needBiosP) {
        $status = KIWIQX::qxx (
            "parted $this->{loop} set 1 bios_grub on 2>&1"
        );
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error ("Couldn't set bios_grub label: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
    }
    $kiwi -> done();
    #==========================================
    # Create partition IDs meta data file
    #------------------------------------------
    $kiwi -> info ("Create install partition IDs meta data...");
    if (! $this -> setupPartIDs ($partidfile)) {
        return;
    }
    $kiwi -> done();
    #==========================================
    # setup device mapper
    #------------------------------------------
    $kiwi -> info ("Setup device mapper for partition access");
    if (! $this -> bindDiskPartitions ($this->{loop})) {
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    $kiwi -> done();
    #==========================================
    # Create loop device mapping table
    #------------------------------------------
    %deviceMap = $this -> setLoopDeviceMap ($this->{loop});
    #==========================================
    # Setup device names
    #------------------------------------------
    my $boot = $deviceMap{installboot};
    my $data;
    if ($gotsys) {
        $data = $deviceMap{installroot};
    }
    #==========================================
    # Create filesystem on partitions
    #------------------------------------------
    foreach my $root ($boot,$data) {
        next if ! defined $root;
        if ($root eq $boot) {
            #==========================================
            # build boot filesystem
            #------------------------------------------
            if (! $this -> setupFilesystem ($bootfs,$root,"install-boot","BOOT")
            ) {
                $this -> cleanStack ();
                return;
            }
        } else {
            #==========================================
            # build root filesystem
            #------------------------------------------
            if (! $this -> setupFilesystem ('ext3',$root,"install-root")) {
                $this -> cleanStack ();
                return;
            }
        }
    }
    #==========================================
    # Setup initrd for install purpose
    #------------------------------------------
    $kiwi -> info ("Repack initrd with install flags...");
    $initrd = $this -> setupInstallFlags();
    if (! defined $initrd) {
        return;
    }
    $this->{initrd} = $initrd;
    $kiwi -> done();
    #==========================================
    # Create Disk boot structure
    #------------------------------------------
    if (! $this -> createBootStructure("vmx")) {
        $this->{initrd} = $oldird;
        return;
    }
    #==========================================
    # Import boot loader stages
    #------------------------------------------
    my $uuid = KIWIQX::qxx("blkid $boot -s UUID -o value"); chomp $uuid;
    if (! $this -> setupBootLoaderStages ($bootloader,'disk',$uuid)) {
        return;
    }
    #==========================================
    # Creating boot loader configuration
    #------------------------------------------
    my $title = "KIWI USB-Stick Installation";
    if (! $gotsys) {
        $title = "KIWI USB Boot: $nameusb";
    }
    if (! $this -> setupBootLoaderConfiguration (
        $bootloader,$title,undef,undef,$uuid)
    ) {
        return;
    }
    $this->{initrd} = $oldird;
    #==========================================
    # Copy boot data on first partition
    #------------------------------------------
    $kiwi -> info ("Installing boot data to disk");
    if (! KIWIGlobals -> instance() -> mount ($boot, $loopdir, undef, $xml)) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't mount boot partition: $status");
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    if (! $this -> copyBootCode ($tmpdir,$loopdir,$bootloader)) {
        KIWIGlobals -> instance() -> umount();
        return;
    }
    KIWIGlobals -> instance() -> umount();
    $kiwi -> done();
    #==========================================
    # Check for optional config-cdroot archive
    #------------------------------------------
    my $cdrootData = "config-cdroot.tgz";
    if (-f "$destdir/$cdrootData") {
        $kiwi -> info ("Integrating CD root information...");
        $status= KIWIQX::qxx (
            "tar -C $loopdir -xvf $destdir/$cdrootData"
        );
        $result= $? >> 8;
        KIWIQX::qxx ("rm -f $destdir/$cdrootData");
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to integrate CD root data: $status");
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
    }
    #==========================================
    # Check for optional config-cdroot.sh
    #------------------------------------------
    my $cdrootScript = "config-cdroot.sh";
    if (-x "$destdir/$cdrootScript") {
        $kiwi -> info ("Calling CD root setup script...");
        my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
        my $script = "$destdir/$cdrootScript";
        if ($script !~ /^\//) {
            $script = $pwd."/".$script;
        }
        $status = KIWIQX::qxx (
            "cd $loopdir && bash -c $script 2>&1"
        );
        $result = $? >> 8;
        KIWIQX::qxx ("rm -f $script");
        if ($result != 0) {
            chomp $status;
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to call CD root script: $status");
            $kiwi -> failed ();
            return;
        } else {
            $kiwi -> loginfo ("config-cdroot.sh: $status");
        }
        $kiwi -> done();
    }
    #==========================================
    # Copy system image if defined
    #------------------------------------------
    if ($gotsys) {
        $kiwi -> info ("Installing image data to disk");
        if (! KIWIGlobals
            -> instance()
            -> mount ($data, $loopdir, undef, $xml)) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't mount data partition: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        $status = KIWIQX::qxx ("mv $system $loopdir 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed importing system image: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        my $FD;
        if (! open ($FD,'>',"$loopdir/config.usbclient")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create USB install flag file");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        print $FD "IMAGE='".$nameusb."'\n";
        close $FD;
        KIWIGlobals -> instance() -> umount();
        $kiwi -> done();
    }
    #==========================================
    # Install boot loader on disk
    #------------------------------------------
    my $diskdevice = $diskname;
    if (! $this -> installBootLoader ($bootloader, $diskdevice, \%deviceMap)) {
        $this -> cleanStack ();
        return;
    }
    $this -> cleanStack();
    my $imgfile = basename $diskname;
    $kiwi -> info ("Created $imgfile to be dd'ed on Stick");
    $kiwi -> done ();
    return $this;
}

#==========================================
# setupInstallPXE
#------------------------------------------
sub setupInstallPXE {
    my $this = shift;
    my $kiwi      = $this->{kiwi};
    my $zipper    = $this->{gdata}->{Xz};
    my $initrd    = $this->{initrd};
    my $system    = $this->{system};
    my $xml       = $this->{xml};
    my $zipped    = $this->{zipped};
    my $arch      = $this->{arch};
    my $imgtype   = $this->{imgtype};
    my $type      = $this->{type};
    my $global    = KIWIGlobals -> instance();
    my $destdir   = dirname ($initrd);
    my $md5name   = $system;
    my $appname;
    my $sysname;
    my $irdname;
    my $krnname;
    my $tarname;
    my $haveDiskDevice;
    my $status;
    my $result;
    my $version;
    my @packfiles;
    #==========================================
    # Create new MBR label for PXE install
    #------------------------------------------
    $this->{mbrid} = $global -> getMBRDiskLabel();
    #==========================================
    # Check for disk device
    #------------------------------------------
    if (-b $system) {
        $haveDiskDevice = $system;
        $version = $xml -> getPreferences() -> getVersion();
        $system  = $xml -> getImageName();
        $system  = $destdir."/".$system.".".$arch."-".$version.".raw";
        $md5name = $system;
        $this->{system} = $system;
    }
    #==========================================
    # check if initrd is zipped
    #------------------------------------------
    if (! $zipped) {
        $kiwi -> error  ("Compressed boot image required");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # check if system image is given
    #------------------------------------------
    if (! defined $system) {
        $kiwi -> error  ("System raw disk image required");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # check for kernel image
    #------------------------------------------
    $krnname = $initrd;
    if ($krnname =~ /gz$/) {
        $krnname =~ s/gz$/kernel/;
    } else {
        $krnname = $krnname.".kernel";
    }
    if (! -e $krnname) {
        $krnname =~ s/splash\.kernel$/kernel/;
    }
    if (-l $krnname) {
        my $knlink = $krnname;
        $krnname = readlink ($knlink);
        if (!File::Spec->file_name_is_absolute($krnname)) {
            $krnname = File::Spec->catfile(dirname($initrd), $krnname);
        }
    }
    if (! -e $krnname) {
        $kiwi -> error  ("Can't find kernel image: $krnname");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Build md5sum of system image
    #------------------------------------------
    if (! $haveDiskDevice) {
        $global -> buildMD5Sum ($system);
    } else {
        $global -> buildMD5Sum ($this->{loop},$system);
    }
    $md5name =~ s/\.raw$/\.md5/;
    #==========================================
    # Create PXE config append information
    #------------------------------------------
    $appname = $system;
    $appname =~ s/\.raw$/\.append/;
    my $appfd = FileHandle -> new();
    if ($appfd -> open(">$appname")) {
        print $appfd 'pxe=1';
        if ($type->{cmdline}) {
            print $appfd " $type->{cmdline}";
        }
        if ($imgtype eq 'split') {
            print $appfd ' COMBINED_IMAGE=yes';
        }
        print $appfd "\n";
        $appfd -> close();
    } else {
        $kiwi -> error  ("Failed to create append file: $!");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Compress system image
    #------------------------------------------
    $kiwi -> info ("Compressing installation image...");
    $result = 0;
    $sysname = $system;
    $sysname =~ s/\.raw$/\.xz/;
    if ($haveDiskDevice) {
        my $locator = KIWILocator -> instance();
        my $qemu_img = $locator -> getExecPath ("qemu-img");
        if (! $qemu_img) {
            $kiwi -> failed ();
            $kiwi -> error  ("Mandatory qemu-img tool not found");
            $kiwi -> failed ();
            return;
        }
        $status = KIWIQX::qxx (
            "$qemu_img convert -f raw -O raw $haveDiskDevice $system"
        );
        $result = $? >> 8;
    }
    if ($result == 0) {
        $status = KIWIQX::qxx ("$zipper -c $system > $sysname 2>&1");
        $result = $? >> 8;
    }
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed to compress system image: $status");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> done();
    #==========================================
    # update md5 block/blocksize information
    #------------------------------------------
    if (! $this -> updateMD5File ($sysname,$md5name)) {
        return;
    }
    #==========================================
    # Setup initrd for install purpose
    #------------------------------------------
    $kiwi -> info ("Repack initrd with install flags...");
    $irdname = $this -> setupInstallFlags();
    if (! defined $irdname) {
        return;
    }
    $kiwi -> done();
    #==========================================
    # Pack result into tarball
    #------------------------------------------
    $kiwi -> info ("Packing installation data...");
    $tarname = $system;
    $tarname =~ s/\.raw$/\.install\.tar\.xz/;
    foreach my $file ($md5name,$sysname,$irdname,$krnname,$appname) {
        push @packfiles, basename $file;
    }
    $status = KIWIQX::qxx (
        "tar -C $destdir -cJf $tarname @packfiles"
    );
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed to pack PXE install data: $status");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> done();
    unlink $md5name;
    unlink $sysname;
    unlink $irdname;
    unlink $appname;
    $kiwi -> info ("Successfully created PXE data set: $tarname");
    $kiwi -> done();
    return $this;
}

#==========================================
# setupBootDisk
#------------------------------------------
sub setupBootDisk {
    my $this      = shift;
    my $device    = shift;
    my $kiwi      = $this->{kiwi};
    my $arch      = $this->{arch};
    my $system    = $this->{system};
    my $syszip    = $this->{syszip};
    my $tmpdir    = $this->{tmpdir};
    my $initrd    = $this->{initrd};
    my $loopdir   = $this->{loopdir};
    my $zipped    = $this->{zipped};
    my $isxen     = $this->{isxen};
    my $profile   = $this->{profile};
    my $xendomain = $this->{xendomain};
    my $xml       = $this->{xml};
    my $cmdL      = $this->{cmdL};
    my $haveTree  = $this->{haveTree};
    my $imgtype   = $this->{imgtype};
    my $haveSplit = $this->{haveSplit};
    my $firmware  = $this->{firmware};
    my $type      = $this->{type};
    my $systemDisk= $this->{sysdisk};
    my $bootloader= $this->{bootloader};
    my $diskname  = $system.".raw";
    my %deviceMap = ();
    my @commands  = ();
    my $bootfix   = "VMX";
    my $haveluks  = 0;
    my $needBiosP = 0;
    my $needJumpP = 0;
    my $needBootP = 0;
    my $needPrepP = 0;
    my $needRoP   = 0;
    my $rawRW     = 0;
    my $boot;
    my $partidfile;
    my $haveDiskDevice;
    my $splitfile;
    my $version;
    my $label;
    my $FSTypeRW;
    my $FSTypeRO;
    my $sysname;
    my $sysird;
    my $result;
    my $status;
    my $destdir;
    my %lvmparts;
    #==========================================
    # check if we can operate on this root
    #------------------------------------------
    if ($this->{isDisk}) {
        $kiwi -> error ("System is specified as raw disk device");
        $kiwi -> failed();
        $kiwi -> error (
            "Required is either a root: directory, fsimage, or partition"
        );
        $kiwi -> failed();
        return;
    }
    #==========================================
    # check if we got a real device
    #------------------------------------------
    if ($device) {
        $haveDiskDevice = $device;
    }
    #==========================================
    # load type attributes...
    #------------------------------------------
    if (! $type->{installiso}) {
        $type->{installiso} = 'false';
    }
    if (! $type->{installstick}) {
        $type->{installstick} = 'false';
    }
    if (! $type->{installpxe}) {
        $type->{installpxe} = 'false';
    }
    #==========================================
    # check for LUKS extension
    #------------------------------------------
    if ($type->{luks}) {
        $haveluks = 1;
    }
    #==========================================
    # Check subsystem combination
    #------------------------------------------
    if (($type->{mdraid}) && ($haveluks)) {
        $kiwi -> error (
            "LUKS encryption on Software RAID not yet supported"
        );
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Check if ZFS setup can be done...
    #------------------------------------------
    if (($type->{filesystem} =~ /zfs/) && ( ! -d $system )) {
        $kiwi -> error (
            "ZFS setup requires root tree but got image file"
        );
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Check if LVM setup can be done...
    #------------------------------------------
    if ($systemDisk) {
        my $volumes = $systemDisk -> getVolumes();
        if ($volumes) {
            %lvmparts = %{$volumes};
        }
    }
    if (($type->{lvm}) && (%lvmparts)) {
        if ( ! -d $system ) {
            $kiwi -> error (
                "LVM volumes setup requires root tree but got image file"
            );
            $kiwi -> failed ();
            return;
        }
        if ($type->{filesystem} =~ /zfs/) {
            $kiwi -> error (
                "LVM volumes setup not yet supported with zfs filesystem"
            );
            $kiwi -> failed ();
            return;
        }
    }
    #==========================================
    # Calculate volume size requirements...
    #------------------------------------------
    if (($type->{lvm}) || ($type->{filesystem} =~ /zfs|btrfs/)) {
        #==========================================
        # check and set volumes setup
        #------------------------------------------
        # the volume information is also evaluated for filesystems
        # which supports volumes/snapshots
        # ----
        if (%lvmparts) {
            my $lvsum = 0;
            foreach my $vol (keys %lvmparts) {
                #==========================================
                # skip special @root volume data
                #------------------------------------------
                if ($vol eq '@root') {
                    # /.../
                    # this volume contains the size information for the
                    # LVRoot volume and doesn't need to be handled here
                    # see end of block for handling @root
                    # ----
                    next;
                }
                #==========================================
                # check directory per volume
                #------------------------------------------
                my $pname = $lvmparts{$vol}->[4];
                if (! -d "$system/$pname") {
                    $kiwi -> info (
                        "Creating volume mount point $system/$pname"
                    );
                    $status = KIWIQX::qxx ("mkdir -p $system/$pname 2>&1");
                    $result = $? >> 8;
                    if ($result != 0) {
                        $kiwi -> failed();
                        return;
                    }
                    $kiwi -> done ();
                }
                #==========================================
                # calculate size required by volume
                #------------------------------------------
                my $lvpath = "$system/$pname";
                my $lvsize = KIWIGlobals -> instance() -> dsize ($lvpath);
                $lvsize = int ($lvsize / 1048576);
                $lvsum += $lvsize;
                #==========================================
                # use 20% (min 30M) spare space per volume
                #------------------------------------------
                my $spare = int (($lvsize * 1.2) - $lvsize);
                if ($spare < 30) {
                    $spare = 30;
                }
                my $spare_on_volume = $spare;
                my $serve_on_disk   = 30;
                #==========================================
                # is requested size absolute or relative
                #------------------------------------------
                my $reqAbsolute = 0;
                if ($lvmparts{$vol}) {
                    $reqAbsolute = $lvmparts{$vol}->[1];
                }
                #==========================================
                # requested size value
                #------------------------------------------
                my $reqSize = 0;
                # /.../
                # The requested volume size is only used if the image
                # type is _not_ oem. That's because for oem images the
                # size of the volumes is created by a resize operation
                # on first boot of the appliance
                # ----
                if (($type->{type} ne "oem") && ($lvmparts{$vol})) {
                    $reqSize = $lvmparts{$vol}->[0];
                    if ((! $reqSize) || ($reqSize eq "all")) {
                        $reqSize = 0;
                    }
                }
                #==========================================
                # calculate volume size
                #------------------------------------------
                my $addToDisk = 0;
                if ($reqAbsolute) {
                    # process absolute size value from XML
                    if ($reqSize > ($lvsize + $spare_on_volume)) {
                        $addToDisk = $reqSize - $lvsize;
                        $lvsize = $reqSize;
                    } else {
                        $addToDisk = $serve_on_disk;
                        $lvsize += $spare_on_volume;
                    }
                } else {
                    # process relative size value from XML
                    $lvsize = int ( $lvsize + $reqSize + $spare_on_volume);
                    $addToDisk = $reqSize + $serve_on_disk;
                }
                #==========================================
                # add calculated volume size to lvmparts
                #------------------------------------------
                $lvmparts{$vol}->[3] = $lvsize;
                #==========================================
                # increase total vm disk size
                #------------------------------------------
                $kiwi->loginfo ("Increasing disk size for volume $pname\n");
                $this -> __updateDiskSize ($addToDisk);
            }
            #==========================================
            # Handle @root volume
            #------------------------------------------
            if ($type->{type} eq "vmx") {
                #==========================================
                # calculate size required by root volume
                #------------------------------------------
                my $rootsize = KIWIGlobals -> instance() -> dsize ($system);
                $rootsize = int ($rootsize / 1048576);
                $rootsize -= $lvsum;
                #==========================================
                # use 20% (min 30M) spare space
                #------------------------------------------
                my $spare = int (($rootsize * 1.2) - $rootsize);
                if ($spare < 30) {
                    $spare = 30;
                }
                my $spare_on_volume = $spare;
                my $serve_on_disk   = 30;
                #==========================================
                # is requested size absolute or relative
                #------------------------------------------
                my $reqAbsolute = 0;
                if ($lvmparts{'@root'}) {
                    $reqAbsolute = $lvmparts{'@root'}->[1];
                }
                #==========================================
                # calculate root volume size
                #------------------------------------------
                my $reqSize   = 0;
                my $addToDisk = 0;
                my $lvroot    = 0;
                if ($lvmparts{'@root'}) {
                    $reqSize = $lvmparts{'@root'}->[0];
                    if ((! $reqSize) || ($reqSize eq "all")) {
                        $reqSize = 0;
                    }
                }
                if ($reqAbsolute) {
                    if ($reqSize > ($rootsize + $spare_on_volume)) {
                        $lvroot = int ($reqSize + $spare_on_volume);
                        $addToDisk = $reqSize - $rootsize;
                    } else {
                        $lvroot = int ($rootsize + $spare);
                        $addToDisk = $serve_on_disk;
                    }
                } else {
                    $lvroot = int ($rootsize + $reqSize + $spare_on_volume);
                    $addToDisk = $reqSize + $serve_on_disk;
                }
                #==========================================
                # add calculated root vol. size to lvmparts
                #------------------------------------------
                $lvmparts{'@root'}->[3] = $lvroot;
                #==========================================
                # increase total vm disk size
                #------------------------------------------
                $kiwi->loginfo ("Increasing disk size for root volume\n");
                $this -> __updateDiskSize ($addToDisk);
            }
        }
    }
    #==========================================
    # check for raw read-write overlay
    #------------------------------------------
    if ($type->{filesystem} =~ /clicfs/) {
        $rawRW = 1;
    }
    #==========================================
    # Do we need a bios legacy partition
    #------------------------------------------
    if (($arch =~ /i.86|x86_64/) &&
        (($firmware eq "efi") || ($firmware eq "uefi"))
    ) {
        $needBiosP = 1;
        $this->{legacysize} = 2;
        $this -> __updateDiskSize ($this->{legacysize});
    }
    #==========================================
    # Do we need a jump to boot partition
    #------------------------------------------
    if (($firmware eq "efi")  ||
        ($firmware eq "uefi") ||
        ($firmware eq "vboot")
    ) {
        $this->{jumpsize} = 200;
        $this -> __updateDiskSize ($this->{jumpsize});
        $needJumpP = 1;
    }
    $this->{needJumpP} = $needJumpP;
    #==========================================
    # Do we need a boot partition
    #------------------------------------------
    if ($type->{mdraid}) {
        $needBootP = 1;
    } elsif ($type->{lvm}) {
        $needBootP = 1;
    } elsif ($syszip) {
        $needBootP = 1;
    } elsif ($type->{filesystem} =~ /btrfs|xfs|zfs/) {
        $needBootP = 1;
    } elsif ($bootloader =~ /(sys|ext)linux|yaboot|uboot|berryboot/) {
        $needBootP = 1;
    } elsif ($type->{luks}) {
        $needBootP = 1;
    } elsif ($firmware eq "ofw") {
        $needPrepP = 1;
        $this->{prepsize} = 8;
        $this -> __updateDiskSize ($this->{prepsize});
    }
    if ($type->{bootpartition}) {
        if ($type->{bootpartition} eq 'true') {
            $needBootP = 1;
        } else {
            $needBootP = 0;
        }
    }
    $this->{needBootP} = $needBootP;
    #==========================================
    # Do we need a PrepP partition
    #------------------------------------------
    if ($firmware eq "ofw") {
        $needPrepP = 1;
    }
    #==========================================
    # Do we need a read-only root partition
    #------------------------------------------
    if ($imgtype eq "split") {
        $needRoP = 1;
    } elsif ($type->{filesystem} =~ /clicfs|overlayfs|squashfs/) {
        $needRoP = 1;
    }
    #==========================================
    # check root partition type
    #------------------------------------------
    my $rootid = '83';
    if ($type->{lvm}) {
        $rootid = '8e';
    }
    if ($type->{mdraid}) {
        $rootid = 'fd';
    }
    #==========================================
    # check required boot filesystem type
    #------------------------------------------
    my $partid = 83;
    my $bootfs = 'ext3';
    if ($needBootP) {
        if ($type->{bootfilesystem}) {
            $bootfs = $type->{bootfilesystem};
        } elsif ($bootloader eq 'syslinux') {
            $bootfs = 'fat32';
        } elsif ($bootloader eq 'yaboot') {
            if ($type->{lvm}) {
                $bootfs = 'fat16';
            } else {
                $bootfs = 'fat32';
            }
        } elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
            $bootfs = 'ext3';
        } else {
            $bootfs = 'ext3';
        }
    }
    $type->{bootfilesystem} = $bootfs;
    #==========================================
    # setup boot partition type
    #------------------------------------------
    if ($bootfs =~ /^fat/) {
        $partid = "c";
    }
    #==========================================
    # build disk name and label from xml data
    #------------------------------------------
    $destdir    = dirname ($initrd);
    $label      = $xml -> getImageDisplayName();
    $version    = $xml -> getPreferences() -> getVersion();
    $diskname   = $xml -> getImageName();
    $splitfile  = $destdir."/".$diskname."-read-write.".$arch."-".$version;
    $diskname   = $destdir."/".$diskname.".".$arch."-".$version.".raw";
    $partidfile = $diskname;
    $partidfile =~ s/\.raw$/\.pids/;
    $this->{bootlabel}= $label;
    #==========================================
    # build bootfix for the bootloader on oem
    #------------------------------------------
    my $oemconf = $xml -> getOEMConfig();
    if ($initrd =~ /oemboot/) {
        my $oemtitle;
        if ($oemconf) {
            $oemtitle = $oemconf -> getBootTitle();
        }
        if ($oemtitle) {
            $this->{bootlabel} = $oemtitle;
            $bootfix = "OEM";
        }
    }
    #==========================================
    # increase disk size for PrepP partition
    #------------------------------------------
    if ($needPrepP) {
        $this->{prepsize} = 8;
        $this -> __updateDiskSize ($this->{prepsize});
    }
    #==========================================
    # increase disk size for in-place recovery
    #------------------------------------------
    my $inplace;
    if ($oemconf) {
        $inplace = $oemconf -> getInplaceRecovery();
    }
    if (($inplace) && ("$inplace" eq "true")) {
        my ($FD,$recoMB);
        my $sizefile = "$destdir/recovery.partition.size";
        if (open ($FD,'<',$sizefile)) {
            $recoMB = <$FD>; chomp $recoMB; close $FD; unlink $sizefile;
            $kiwi -> info (
                "Adding $recoMB MB spare space for in-place recovery"
            );
            $this -> __updateDiskSize ($recoMB);
            $kiwi -> done ();
        }
    }
    #==========================================
    # increase vmsize if image split RW portion
    #------------------------------------------
    if (($imgtype eq "split") && (-f $splitfile)) {
        my $splitsize = KIWIGlobals -> instance() -> isize ($splitfile);
        my $splitMB = int (($splitsize * 1.2) / 1048576);
        $kiwi -> info (
            "Adding $splitMB MB space for split read-write portion"
        );
        $this -> __updateDiskSize ($splitMB);
        $kiwi -> done();
    }
    #==========================================
    # obtain filesystem type from xml data
    #------------------------------------------
    if ($type->{filesystem} =~ /(.*),(.*)/) {
        $FSTypeRW = $1;
        $FSTypeRO = $2;
    } else {
        $FSTypeRW = $type->{filesystem};
        $FSTypeRO = $FSTypeRW;
    }
    if ($haveSplit) {
        my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($FSTypeRW);
        if ($fsattr{readonly}) {
            $kiwi -> error ("Can't copy data into requested RO filesystem");
            $kiwi -> failed ();
            return;
        }
    }
    #==========================================
    # Setup boot partition space
    #------------------------------------------
    if ($needBootP) {
        $this ->{bootsize} = $this -> __getBootSize ();
    }
    #==========================================
    # add boot space if syslinux based
    #------------------------------------------
    if ($bootfs =~ /^fat/) {
        my $fatstorage = $cmdL->getFatStorage();
        if (defined $fatstorage) {
            if ($this->{bootsize} < $fatstorage) {
                $kiwi -> info ("Fat Storage option set:\n");
                $kiwi -> info (
                    "Set Fat boot partition space to: ".$fatstorage."M\n"
                );
                $this->{bootsize} = $fatstorage;
            }
        }
    }
    #==========================================
    # Update raw disk size if boot part is used
    #------------------------------------------
    if ($needBootP) {
        $this -> __updateDiskSize ($this->{bootsize});
    }
    #==========================================
    # Check and Update to custom disk size
    #------------------------------------------
    $this -> __updateCustomDiskSize ();
    #==========================================
    # create/use disk
    #------------------------------------------
    my $locator = KIWILocator -> instance();
    my $dmap; # device map
    my $root; # root device
    my $try_count = 50;
    my $try_loop  = 0;
    if (! defined $system) {
        $kiwi -> error  ("No system image given");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> info ("Setup disk image/device\n");
    $kiwi -> info (
        "--> Disk start sector: ".$cmdL->getDiskStartSector."\n"
    );
    $kiwi -> info (
        "--> Disk alignment: ".$cmdL->getDiskAlignment." KBytes\n"
    );
    while (1) {
        if ($this->{gdata}->{StudioNode}) {
            #==========================================
            # Call custom image creation tool...
            #------------------------------------------
            $status = KIWIQX::qxx (
                "$this->{gdata}->{StudioNode} $this->{vmsize} 2>&1"
            );
            $result = $? >> 8;
            chomp $status;
            if (($result != 0) || (! -b $status)) {
                $kiwi -> error  (
                    "Failed creating Studio storage device: $status"
                );
                $kiwi -> failed ();
                return;
            }
            $haveDiskDevice = $status;
            $this->{loop} = $haveDiskDevice;
        } elsif (! $haveDiskDevice) {
            #==========================================
            # loop setup a disk device as file...
            #------------------------------------------
            my $qemu_img = $locator -> getExecPath ("qemu-img");
            if (! $qemu_img) {
                $kiwi -> error  ("Mandatory qemu-img tool not found");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "$qemu_img create $diskname $this->{vmsize} 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> error  ("Failed creating virtual disk: $status");
                $kiwi -> failed ();
                return;
            }
            #==========================================
            # setup loop device for virtual disk
            #------------------------------------------
            if (! $this -> bindDiskDevice($diskname)) {
                return;
            }
        } else {
            #==========================================
            # Use specified disk device...
            #------------------------------------------
            $this->{loop} = $haveDiskDevice;
            if (! -b $this->{loop}) {
                $kiwi -> error  ("No such block device: $this->{loop}");
                $kiwi -> failed ();
                return;
            }
        }
        #==========================================
        # create disk partitions
        #------------------------------------------
        my $pnr = 0;    # partition number start for increment
        my $active = 1; # default active partition (bios)
        my @linux_parts = (); # linux partition numbers
        if ($needBiosP) {
            $pnr++;
            push @commands,"n","p:legacy",$pnr,".","+".$this->{legacysize}."M";
            $this->{partids}{biosgrub}  = $pnr;
        }
        if ($needPrepP) {
            $pnr++;
            push @commands,"n","p:prep",$pnr,".","+".$this->{prepsize}."M";
            push @commands,"t",$pnr,"41";
            $this->{partids}{prep}  = $pnr;
            $active = $pnr;
        }
        if ($needJumpP) {
            $pnr++;
            push @commands,"n","p:UEFI",$pnr,".","+".$this->{jumpsize}."M";
            push @commands,"t",$pnr,"c";
            $this->{partids}{jump} = $pnr;
            $active = $pnr;
        }
        if ($needBootP) {
            $pnr++;
            push @commands,"n","p:lxboot",$pnr,".","+".$this->{bootsize}."M";
            push @commands,"t",$pnr,$partid;
            $this->{partids}{boot} = $pnr;
            if (! $needJumpP) {
                $active = $pnr;
            }
        }
        if (! $type->{lvm}) {
            if ($needRoP) {
                $pnr++;
                push @linux_parts, $pnr;
                push @commands,"n","p:lxroot",$pnr,".","+".$syszip."M";
                push @commands,"t",$pnr,$rootid;
                $this->{partids}{readonly} = $pnr;
                $this->{partids}{root}     = $pnr;
                $pnr++;
                push @linux_parts, $pnr;
                push @commands,"n","p:lxrw",$pnr,".",".";
                $this->{partids}{readwrite} = $pnr;
            } else {
                $pnr++;
                push @linux_parts, $pnr;
                push @commands,"n","p:lxroot",$pnr,".",".";
                $this->{partids}{root} = $pnr;
                if (! $needBootP) {
                    $this->{partids}{boot} = $pnr;
                }
            }
        } else {
            $pnr++;
            push @commands,"n","p:lxlvm",$pnr,".",".";
            push @commands,"t",$pnr,$rootid;
            $this->{partids}{root} = $pnr;
            if ($needRoP) {
                $this->{partids}{root_lv}      = 'LVComp';
                $this->{partids}{readonly_lv}  = 'LVComp';
                $this->{partids}{readwrite_lv} = 'LVRoot';
            } else {
                $this->{partids}{root_lv}  = 'LVRoot';
            }
        }
        push @commands,"a",$active;
        #==========================================
        # write partition table
        #------------------------------------------
        $kiwi -> info ("--> writing partition table\n");
        if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
            $kiwi -> error  ("Couldn't create partition table");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        #==========================================
        # Set bios boot flag if requested
        #------------------------------------------
        if ($needBiosP) {
            $status = KIWIQX::qxx (
                "parted $this->{loop} set 1 bios_grub on 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> error ("Couldn't set bios_grub label: $status");
                $kiwi -> failed ();
                $this -> cleanStack ();
                return;
            }
        }
        #==========================================
        # Update linux partition ID for GPT table
        #------------------------------------------
        if (($this->{ptype}) && ($this->{ptype} eq 'gpt')) {
            my $sgdisk = $locator -> getExecPath ("sgdisk");
            if (! $sgdisk) {
                $kiwi -> warning(
                    "sgdisk tool not found, GPT partition code stays untouched"
                );
                $kiwi -> skipped()
            } else {
                foreach my $part (@linux_parts) {
                    $status = KIWIQX::qxx (
                        "sgdisk -t $part:8300 $this->{loop} 2>&1"
                    );
                    $result = $? >> 8;
                    if ($result != 0) {
                        $kiwi -> error  (
                            "Couldn't set Linux code to part:$part: $status"
                        );
                        $kiwi -> failed ();
                        $this -> cleanStack ();
                        return;
                    }
                }
            }
        }
        if ((! $haveDiskDevice ) || ($haveDiskDevice =~ /nbd|aoe/)) {
            #==========================================
            # setup device mapper
            #------------------------------------------
            if (! $this -> bindDiskPartitions ($this->{loop})) {
                $this -> cleanStack ();
                return;
            }
            #==========================================
            # Create loop device mapping table
            #------------------------------------------
            %deviceMap = $this -> setLoopDeviceMap ($this->{loop});
        } else {
            #==========================================
            # Create disk device mapping table
            #------------------------------------------
            %deviceMap = $this -> setDefaultDeviceMap ($this->{loop});
        }
        #==========================================
        # setup md device if requested
        #------------------------------------------
        if ($type->{mdraid}) {
            %deviceMap = $this -> setMD (\%deviceMap,$type->{mdraid});
            if (! %deviceMap) {
                $this -> cleanStack ();
                return;
            }
        }
        #==========================================
        # setup luks device if requested
        #------------------------------------------
        if ($haveluks) {
            if (($syszip) && (! $haveSplit) && (! $rawRW)) {
                # for compressed and split systems we encode the RW partition
                %deviceMap = $this -> setupEncoding (
                    'luksReadWrite',\%deviceMap
                );
            } else {
                # for everything else we encode the root partition
                %deviceMap = $this -> setupEncoding (
                    'luksRoot',\%deviceMap
                );
            }
            if (! %deviceMap) {
                $this -> cleanStack ();
                return;
            }
        }
        #==========================================
        # setup volume group if requested
        #------------------------------------------
        if ($type->{lvm}) {
            %deviceMap = $this -> setVolumeGroup (
                \%deviceMap,$this->{loop},$syszip,$haveSplit,\%lvmparts
            );
            if (! %deviceMap) {
                $this -> cleanStack ();
                return;
            }
        }
        #==========================================
        # set root device name from deviceMap
        #------------------------------------------
        $root = $deviceMap{root};
        #==========================================
        # check system partition size
        #------------------------------------------
        my $sizeOK = 1;
        my $splitPSize  = 1;
        my $splitISize  = 0;
        my $systemPSize = $this->getStorageSize ($root);
        my $systemISize = KIWIGlobals -> instance() -> isize ($system);
        $systemISize /= 1024;
        chomp $systemPSize;
        if ($systemPSize < 0) {
            $kiwi -> error ("Sorry Can't get size for device $root");
            $kiwi -> failed();
            return;
        }
        #print "_______A $systemPSize : $systemISize\n";
        if ($haveSplit) {
            $splitPSize = $this->getStorageSize ($deviceMap{readwrite});
            $splitISize = KIWIGlobals -> instance() -> isize ($splitfile);
            $splitISize /= 1024;
            chomp $splitPSize;
            if ($splitPSize < 0) {
                $kiwi -> error (
                    "Sorry Can't get size for device $deviceMap{readwrite}"
                );
                $kiwi -> failed();
                return;
            }
            #print "_______B $splitPSize : $splitISize\n";
        }
        if (($systemPSize <= $systemISize) || ($splitPSize <= $splitISize)) {
            #==========================================
            # system partition(s) still too small
            #------------------------------------------
            if ($haveDiskDevice) {
                $kiwi -> error (
                    "Sorry given disk $haveDiskDevice is too small"
                );
                $kiwi -> failed();
                return;
            }
            sleep (1);
            $this -> deleteVolumeGroup();
            $this -> cleanStack();
            $this -> __updateDiskSize (10);
        } else {
            #==========================================
            # looks good go for it
            #------------------------------------------
            last;
        }
        $kiwi -> note (".");
        $try_loop++;
        if ($try_loop > $try_count) {
            #==========================================
            # We should never get there
            #------------------------------------------
            $kiwi -> error (
                "Sorry can't create requested partition table"
            );
            $kiwi -> failed();
            return;
        }
    }
    #==========================================
    # Create partition IDs meta data file
    #------------------------------------------
    $kiwi -> info ("Create partition IDs meta data...");
    if (! $this -> setupPartIDs ($partidfile)) {
        return;
    }
    $kiwi -> done();
    #==========================================
    # Dump system image on disk
    #------------------------------------------
    if (! $haveTree) {
        $kiwi -> info ("Dumping system image on disk");
        $status = KIWIQX::qxx ("dd if=$system of=$root bs=32k 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't dump image to disk: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        $kiwi -> done();
        $result = 0;
        my $mapper = $root;
        my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($root);
        if ($fsattr{type} eq "luks") {
            $mapper = $this -> luksResize ($root,"luks-resize");
            if (! $mapper) {
                $this -> luksClose();
                return;
            }
            %fsattr= KIWIGlobals -> instance() -> checkFileSystem ($mapper);
        }
        my $expanded = $this -> __expandFS (
            $fsattr{type},'system', $mapper
        );
        if (! $expanded ) {
            return;
        }
        if (($haveSplit) && (-f $splitfile)) {
            $kiwi -> info ("Dumping split read/write part on disk");
            $root = $deviceMap{readwrite};
            $status = KIWIQX::qxx ("dd if=$splitfile of=$root bs=32k 2>&1");
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't dump split file: $status");
                $kiwi -> failed ();
                $this -> cleanStack ();
                return;
            }
            $kiwi -> done();
            $result = 0;
            $mapper = $root;
            my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($root);
            if ($fsattr{type} eq "luks") {
                $mapper = $this -> luksResize ($root,"luks-resize");
                if (! $mapper) {
                    $this -> luksClose();
                    return;
                }
                %fsattr = KIWIGlobals
                    -> instance()
                    -> checkFileSystem ($mapper);
            }
            my $expanded = $this -> __expandFS (
                $fsattr{type},'split', $mapper
            );
            if (! $expanded ) {
                return;
            }
        }
    } else {
        #==========================================
        # Create fs on system image partition
        #------------------------------------------
        if (! $this -> setupFilesystem ($FSTypeRO,$root,"root")) {
            return;
        }
        #==========================================
        # Mount system image partition
        #------------------------------------------
        if (! KIWIGlobals
            -> instance()
            -> mount ($root, $loopdir, $type->{fsmountoptions}, $xml
        )) {
            $this -> cleanStack ();
            return;
        }
        #==========================================
        # Create LVM volumes filesystems
        #------------------------------------------
        if (($type->{lvm}) && (%lvmparts)) {
            my $VGroup = $type->{lvmgroup};
            my @paths  = ();
            my %phash  = ();
            my %lhash  = ();
            #==========================================
            # Create path names in correct order
            #------------------------------------------
            foreach my $name (keys %lvmparts) {
                my $pname  = $name;
                $pname =~ s/_/\//g;
                $pname =~ s/^\///;
                $pname =~ s/\s*$//;
                push @paths,$pname;
                $lhash{$pname} = $lvmparts{$name}->[2];
            }
            foreach my $name (@paths) {
                my @parts = split (/\//,$name);
                my $part  = @parts;
                push @{$phash{$part}},$name;
            }
            #==========================================
            # Create filesystems and Mount LVM volumes
            #------------------------------------------
            foreach my $level (sort {($a <=> $b) || ($a cmp $b)} keys %phash) {
                foreach my $pname (@{$phash{$level}}) {
                    next if $pname eq '@root';
                    my $lvname = $lhash{$pname};
                    if (! $lvname) {
                        $lvname = $pname;
                        $lvname =~ s/\//_/g;
                        $lvname = 'LV'.$lvname;
                    }
                    my $device = "/dev/$VGroup/$lvname";
                    $status = KIWIQX::qxx ("mkdir -p $loopdir/$pname 2>&1");
                    $result = $? >> 8;
                    if ($result != 0) {
                        $kiwi -> error (
                            "Can't create mount point $loopdir/$pname"
                        );
                        $this -> cleanStack ();
                        return;
                    }
                    if (! $this -> setupFilesystem ($FSTypeRO,$device,$pname)) {
                        $this -> cleanStack ();
                        return;
                    }
                    $kiwi -> loginfo ("Mounting logical volume: $pname\n");
                    if (! KIWIGlobals -> instance() -> mount
                        ($device,"$loopdir/$pname",$type->{fsmountoptions})
                    ) {
                        $this -> cleanStack ();
                        return;
                    }
                }
            }
        }
        #==========================================
        # Setup filesystem specific environment
        #------------------------------------------
        if (! $type->{lvm}) {
            if ($FSTypeRW eq 'btrfs') {
                if (! KIWIGlobals
                    -> instance()
                    -> setupBTRFSSubVolumes ($loopdir,\%lvmparts)) {
                    $this -> cleanStack ();
                    return;
                }
            }
            if ($FSTypeRW eq 'zfs') {
                if (! KIWIGlobals
                    -> instance()
                    -> setupZFSPoolVolumes ($loopdir,\%lvmparts)) {
                    $this -> cleanStack ();
                    return;
                }
            }
        }
        #==========================================
        # Copy root tree to disk
        #------------------------------------------
        $kiwi -> info ("Copying system image tree on disk");
        my $btrfs_sub_vol = '';
        my $rsync_cmd = 'rsync -aHXA --one-file-system ';
        if (-e $loopdir.'/@') {
            # /.../
            # if we found the special btrfs subvolume named @ we
            # sync only this volume and not the other nested sub
            # volumes
            # ----
            $btrfs_sub_vol = '/@';
        }
        $status = KIWIQX::qxx (
            $rsync_cmd.$system.'/ '.$loopdir.$btrfs_sub_vol.' 2>&1'
        );
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Can't copy image tree to disk: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        $kiwi -> done();
        #==========================================
        # Umount system image partition
        #------------------------------------------
        KIWIGlobals -> instance() -> umount();
    }
    #==========================================
    # Run zerofree if present and extX rootfs
    #------------------------------------------
    # zerofree replaces any block of an extX filesystem marked as free
    # and containing something different than a zero with a zero byte.
    # Later on that results in better compression results of an image
    # containing this filesystem
    my $blktype = KIWIQX::qxx("blkid $root -s TYPE -o value");
    chomp $blktype;
    if ($blktype) {
        my $zero_free = $locator -> getExecPath ("zerofree");
        if (($zero_free) && ($blktype =~ /^ext[234]/)) {
            $kiwi -> info (
                "Scanning $blktype free blocks and replace them by zero..."
            );
            my $status = KIWIQX::qxx ("$zero_free $root 2>&1");
            my $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed();
                $kiwi -> error ("zerofree failed with: $status");
                $kiwi -> failed();
                $this -> cleanStack ();
                return;
            }
            $kiwi -> done();
        } else {
            $kiwi -> warning(
                "No free blocks analyzer available for $blktype"
            );
            $kiwi -> skipped();
        }
    }
    #==========================================
    # create read/write filesystem if needed
    #------------------------------------------
    if (($syszip) && (! $haveSplit) && (! $rawRW)) {
        $kiwi -> info ("Creating ext3 read-write filesystem");
        my $rw = $deviceMap{readwrite};
        my $fsOpts = $cmdL -> getFilesystemOptions();
        my $createArgs = $fsOpts -> getOptionsStrExt();
        my $fstool = "mkfs.ext3";
        $status = KIWIQX::qxx ("$fstool $createArgs $rw 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create filesystem: $status");
            $kiwi -> failed ();
            $this -> luksClose();
            $this -> cleanStack ();
            return;
        }
        $this -> luksClose();
        $kiwi -> done();
    }
    #==========================================
    # create bootloader filesystem(s) if needed
    #------------------------------------------
    if ($needBootP) {
        #==========================================
        # check for boot device node
        #------------------------------------------
        $boot = $deviceMap{boot};
        #==========================================
        # build boot filesystem
        #------------------------------------------
        if (! $this -> setupFilesystem ($bootfs,$boot,"boot","BOOT")) {
            $this -> cleanStack ();
            return;
        }
    }
    if ($needJumpP) {
        #==========================================
        # build jump boot filesystem
        #------------------------------------------
        my $jump = $deviceMap{jump};
        if (! $this -> setupFilesystem ('fat16',$jump,"jump","EFI")) {
            $this -> cleanStack ();
            return;
        }
    }
    #==========================================
    # Find boot partition
    #------------------------------------------
    if ($needBootP) {
        $boot = $deviceMap{boot};
    } else {
        $boot = $deviceMap{root};
    }
    #==========================================
    # Setup initrd for boot
    #------------------------------------------
    $kiwi -> info ("Repack initrd with boot flags...");
    if (! $this -> setupBootFlags()) {
        return;
    }
    $kiwi -> done();
    #==========================================
    # Create Disk boot structure
    #------------------------------------------
    if (! $this -> createBootStructure("vmx")) {
        return;
    }
    #==========================================
    # Import boot loader stages
    #------------------------------------------
    my $uuid = KIWIQX::qxx("blkid $boot -s UUID -o value"); chomp $uuid;
    if (! $this -> setupBootLoaderStages ($bootloader,'disk',$uuid)) {
        return;
    }
    #==========================================
    # add extra Xen boot options if necessary
    #------------------------------------------
    my $extra = "";
    #==========================================
    # Create boot loader configuration
    #------------------------------------------
    if (! $this -> setupBootLoaderConfiguration (
        $bootloader,$bootfix,$extra,undef,$uuid)
    ) {
        return;
    }
    #==========================================
    # Mount boot space on this disk
    #------------------------------------------
    if (! KIWIGlobals -> instance() -> mount ($boot, $loopdir, undef, $xml)) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't mount image boot device: $boot");
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    if ($firmware =~ /efi|uefi|vboot/) {
        #==========================================
        # Mount jump boot space on this disk
        #------------------------------------------
        my $subdir = 'efi';
        if ($firmware eq 'vboot') {
            $subdir = 'vboot';
        }
        my $jump = $deviceMap{jump};
        KIWIQX::qxx ("mkdir -p $loopdir/$subdir");
        if (! KIWIGlobals -> instance() -> mount (
            $jump, "$loopdir/$subdir", undef, $xml
        )) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't mount image jump device: $boot");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
    }
    #==========================================
    # Copy boot data on system image
    #------------------------------------------
    if (! $this -> copyBootCode ($tmpdir,$loopdir,$bootloader)) {
        KIWIGlobals -> instance() -> umount();
        return;
    }
    if (($firmware eq "efi") || ($firmware eq "uefi")) {
        #==========================================
        # Adapt efi boot path on jump partition
        #------------------------------------------
        KIWIQX::qxx ("mv $loopdir/EFI $loopdir/efi");
    }
    #==========================================
    # umount entire boot space
    #------------------------------------------
    KIWIGlobals -> instance() -> umount();
    #==========================================
    # Install boot loader on disk
    #------------------------------------------
    my $diskdevice = $diskname;
    if ($haveDiskDevice) {
        $diskdevice = $this->{loop};
    }
    if (! $this->installBootLoader ($bootloader,$diskdevice, \%deviceMap)) {
        $this -> cleanStack ();
        return;
    }
    #==========================================
    # cleanup device maps and part mount
    #------------------------------------------
    $this -> cleanStack();
    #==========================================
    # cleanup temp directory
    #------------------------------------------
    KIWIQX::qxx ("rm -rf $tmpdir");
    if (($haveDiskDevice) && (! $this->{gdata}->{StudioNode})) {
        if (
            ($type->{installiso}   ne "true") &&
            ($type->{installstick} ne "true") &&
            ($type->{installpxe}   ne "true")
        ) {
            #==========================================
            # create image file from disk device
            #------------------------------------------
            $kiwi -> info ("Dumping image file from $this->{loop}...");
            my $qemu_img = $locator -> getExecPath ("qemu-img");
            if (! $qemu_img) {
                $kiwi -> failed ();
                $kiwi -> error  ("Mandatory qemu-img tool not found");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "$qemu_img convert -f raw -O raw $this->{loop} $diskname 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error ("Image dump failed: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
        }
    }
    #==========================================
    # Create image described by given format
    #------------------------------------------
    if ($initrd =~ /oemboot/) {
        #==========================================
        # OEM Install CD...
        #------------------------------------------
        if (($type->{installiso}) && ($type->{installiso} eq 'true')) {
            $this -> {system} = $diskname;
            if ($haveDiskDevice) {
                $this -> {system} = $this->{loop};
            }
            $kiwi -> info ("--> Creating install ISO image\n");
            $this -> cleanStack ();
            if (! $this -> setupInstallCD()) {
                return;
            }
        }
        #==========================================
        # OEM Install Stick...
        #------------------------------------------
        if (($type->{installstick}) && ($type->{installstick} eq 'true')) {
            $this -> {system} = $diskname;
            if ($haveDiskDevice) {
                $this -> {system} = $this->{loop};
            }
            $kiwi -> info ("--> Creating install USB Stick image\n");
            $this -> cleanStack ();
            if (! $this -> setupInstallStick()) {
                return;
            }
        }
        #==========================================
        # OEM Install PXE...
        #------------------------------------------
        if (($type->{installpxe}) && ($type->{installpxe} eq 'true')) {
            $this -> {system} = $diskname;
            if ($haveDiskDevice) {
                $this -> {system} = $this->{loop};
            }
            $kiwi -> info ("--> Creating install PXE data set\n");
            $this -> cleanStack ();
            if (! $this -> setupInstallPXE()) {
                return;
            }
        }
    }
    #==========================================
    # cleanup loop setup and device mapper
    #------------------------------------------
    $this -> cleanStack ();
    return $this;
}

#==========================================
# setupInstallFlags
#------------------------------------------
sub setupInstallFlags {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $initrd = $this->{initrd};
    my $system = $this->{system};
    my $xml    = $this->{xml};
    my $zipper = $this->{gdata}->{IrdZipperCommand};
    my $suf    = $this->{gdata}->{IrdZipperSuffix};
    my $newird;
    my $irddir = KIWIQX::qxx ("mktemp -qdt kiwiird.XXXXXX"); chomp $irddir;
    my $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create tmp dir: $irddir: $!");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # unpack initrd files
    #------------------------------------------
    my $unzip  = "$zipper -cd $initrd 2>&1";
    my $status = KIWIQX::qxx ("$unzip | (cd $irddir && cpio -di 2>&1)");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed to extract initrd data: $status");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $irddir");
        return;
    }
    #==========================================
    # Include recovery information
    #------------------------------------------
    if (defined $system) {
        my $destdir = dirname ($system);
        my $recopart= "$destdir/recovery.partition.size";
        if (-f $recopart) {
            my $status = KIWIQX::qxx ("cp $recopart $irddir 2>&1");
            my $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Failed to copy recovery metadata: $result");
                $kiwi -> failed ();
                KIWIQX::qxx ("rm -rf $irddir");
                return;
            }
        }
    }
    #==========================================
    # Include Partition ID information
    #------------------------------------------
    if (defined $system) {
        my $partidfile = $system;
        $partidfile =~ s/\.raw$/\.pids/;
        if (! -f $partidfile) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't find partid metadata: $partidfile");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $irddir");
            return;
        }
        my $status = KIWIQX::qxx ("cp $partidfile $irddir/config.partids 2>&1");
        my $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to copy partid metadata: $result");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $irddir");
            return;
        }
    }
    #==========================================
    # Include MBR ID to initrd
    #------------------------------------------
    my $FD;
    KIWIQX::qxx ("mkdir -p $irddir/boot");
    if (! open ($FD, '>', "$irddir/boot/mbrid")) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create mbrid file: $!");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $irddir");
        return;
    }
    print $FD "$this->{mbrid}";
    close $FD;
    #===========================================
    # add image.md5 / config.vmxsystem to initrd
    #-------------------------------------------
    if (defined $system) {
        my $imd5 = $system;
        $imd5 =~ s/\.raw$/\.md5/;
        my $status = KIWIQX::qxx ("cp $imd5 $irddir/etc/image.md5 2>&1");
        my $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed importing md5 file: $status");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $irddir");
            return;
        }
        my $namecd = basename ($system);
        if (! -f $imd5) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't find md5 file");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $irddir");
            return;
        }
        my $FD;
        if (! open ($FD,'>',"$irddir/config.vmxsystem")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create image boot configuration");
            $kiwi -> failed ();
            return;
        }
        print $FD "IMAGE='".$namecd."'\n";
        close $FD;
    }
    #==========================================
    # create new initrd with vmxsystem file
    #------------------------------------------
    $newird = $initrd;
    $newird =~ s/\.$suf/\.install\.$suf/;
    $status = KIWIQX::qxx (
        "(cd $irddir && find|cpio --quiet -oH newc | $zipper) > $newird"
    );
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed to re-create initrd: $status");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $irddir");
        return;
    }
    KIWIQX::qxx ("rm -rf $irddir");
    #==========================================
    # recreate splash data to initrd
    #------------------------------------------
    my $splash = $initrd;
    if (! ($splash =~ s/splash\.$suf/spl/)) {
        $splash =~ s/$suf/spl/;
    }
    if (-f $splash) {
        KIWIQX::qxx ("cat $splash >> $newird");
    }
    return $newird;
}

#==========================================
# setupBootFlags
#------------------------------------------
sub setupBootFlags {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $initrd = $this->{initrd};
    my $zipper = $this->{gdata}->{IrdZipperCommand};
    my $suf    = $this->{gdata}->{IrdZipperSuffix};
    my $newird;
    my $irddir = KIWIQX::qxx ("mktemp -qdt kiwiird.XXXXXX"); chomp $irddir;
    my $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $irddir: $!");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # resolve if link
    #------------------------------------------
    if (-l $initrd) {
        my $dirname = dirname $initrd;
        my $lnkname = readlink $initrd;
        $initrd = $dirname.'/'.$lnkname;
    }
    #==========================================
    # unpack initrd files
    #------------------------------------------
    my $unzip  = "$zipper -cd $initrd 2>&1";
    my $status = KIWIQX::qxx ("$unzip | (cd $irddir && cpio -di 2>&1)");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed to extract initrd data: $status");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $irddir");
        return;
    }
    #==========================================
    # Include recovery information
    #------------------------------------------
    my $destdir = dirname ($initrd);
    my $recopart= "$destdir/recovery.partition.size";
    if (-f $recopart) {
        my $status = KIWIQX::qxx ("cp $recopart $irddir 2>&1");
        my $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to copy recovery metadata: $result");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $irddir");
            return;
        }
    }
    #==========================================
    # Include Partition ID information
    #------------------------------------------
    if (! $this -> setupPartIDs ("$irddir/config.partids")) {
        KIWIQX::qxx ("rm -rf $irddir");
        return;
    }
    #==========================================
    # Include mdadm.conf of mdraid is active
    #------------------------------------------
    if ($this->{mddev}) {
        KIWIQX::qxx ("mkdir -p $irddir/etc");
        $status = KIWIQX::qxx (
            "mdadm -Db $this->{mddev} > $irddir/etc/mdadm.conf 2>&1"
        );
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to extract raid configuration: $status");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $irddir");
            return;
        }
    }
    #==========================================
    # Include MBR ID to initrd
    #------------------------------------------
    my $FD;
    KIWIQX::qxx ("mkdir -p $irddir/boot");
    if (! open ($FD, '>', "$irddir/boot/mbrid")) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create mbrid file: $!");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $irddir");
        return;
    }
    print $FD "$this->{mbrid}";
    close $FD;
    #==========================================
    # create new initrd with mbr information
    #------------------------------------------
    $newird = $initrd;
    $newird =~ s/\.$suf/\.mbrinfo\.$suf/;
    $status = KIWIQX::qxx (
        "(cd $irddir && find|cpio --quiet -oH newc | $zipper) > $newird"
    );
    $result = $? >> 8;
    if ($result == 0) {
        $status = KIWIQX::qxx ("mv $newird $initrd 2>&1");
        $result = $? >> 8;
    }
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed to re-create initrd: $status");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $irddir");
        return;
    }
    KIWIQX::qxx ("rm -rf $irddir");
    #==========================================
    # update splash initrd if required
    #------------------------------------------
    my $splashird = $initrd;
    $splashird =~ s/\.$suf$/\.splash.$suf/;
    if (($initrd !~ /splash\.$suf$/) && (-f $splashird)) {
        KIWIQX::qxx ("cp $initrd $splashird 2>&1");
        $initrd = $splashird;
    }
    #==========================================
    # recreate splash data to initrd
    #------------------------------------------
    my $splash = $initrd;
    if (! ($splash =~ s/splash\.$suf/spl/)) {
        $splash =~ s/$suf/spl/;
    }
    if (-f $splash) {
        KIWIQX::qxx ("cat $splash >> $initrd");
    }
    return $initrd;
}

#==========================================
# setupPartIDs
#------------------------------------------
sub setupPartIDs {
    # ...
    # create information about device ID for root,boot
    # readonly/readwrite partitions created for this
    # appliance. The information is read by the initrd
    # code to assign the correct partition device
    # ----
    my $this = shift;
    my $file = shift;
    my $kiwi = $this->{kiwi};
    my $type = $this->{type};
    if ($this->{partids}) {
        my %currentIDs;
        my $ID_FD = FileHandle -> new();
        if (-e $file) {
            if (! $ID_FD -> open ($file)) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't open partition ID information");
                $kiwi -> failed ();
                return;
            }
            while (my $line = <$ID_FD>) {
                $currentIDs{$line} = 1;
            }
            $ID_FD -> close();
            if (! $ID_FD -> open (">>$file")) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't append partition ID information");
                $kiwi -> failed ();
                return;
            }
        } else {
            if (! $ID_FD -> open (">$file")) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't create partition ID information");
                $kiwi -> failed ();
                return;
            }
        }
        my $entry;
        if ($type->{mdraid}) {
            $entry = "kiwi_RaidPart=\"$this->{partids}{root}\"\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
            $entry = "kiwi_RaidDev=/dev/md0\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
        }
        if ($type->{lvm}) {
            if ($this->{partids}{root_lv}) {
                $entry = "kiwi_RootPartVol=\"$this->{partids}{root_lv}\"\n";
                if (! $currentIDs{$entry}) { print $ID_FD $entry }
                $entry = "kiwi_RootPart=\"$this->{partids}{root}\"\n";
                if (! $currentIDs{$entry}) { print $ID_FD $entry }
            }
            if ($this->{partids}{readonly_lv}) {
                $entry = "kiwi_ROPartVol=\"$this->{partids}{readonly_lv}\"\n";
                if (! $currentIDs{$entry}) { print $ID_FD $entry }
            }
            if ($this->{partids}{readwrite_lv}) {
                $entry = "kiwi_RWPartVol=\"$this->{partids}{readwrite_lv}\"\n";
                if (! $currentIDs{$entry}) { print $ID_FD $entry }
            }
        } else {
            if ($this->{partids}{root}) {
                $entry = "kiwi_RootPart=\"$this->{partids}{root}\"\n";
                if (! $currentIDs{$entry}) { print $ID_FD $entry }
            }
            if ($this->{partids}{readonly}) {
                $entry = "kiwi_ROPart=\"$this->{partids}{readonly}\"\n";
                if (! $currentIDs{$entry}) { print $ID_FD $entry }
            }
            if ($this->{partids}{readwrite}) {
                $entry = "kiwi_RWPart=\"$this->{partids}{readwrite}\"\n";
                if (! $currentIDs{$entry}) { print $ID_FD $entry }
            }
        }
        if ($this->{partids}{installroot}) {
            $entry = "kiwi_InstallRootPart=\"$this->{partids}{installroot}\"\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
        }
        if ($this->{partids}{installboot}) {
            $entry = "kiwi_InstallBootPart=\"$this->{partids}{installboot}\"\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
        }
        if ($this->{partids}{boot}) {
            $entry = "kiwi_BootPart=\"$this->{partids}{boot}\"\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
        }
        if ($this->{partids}{jump}) {
            $entry = "kiwi_JumpPart=\"$this->{partids}{jump}\"\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
        }
        if ($this->{partids}{biosgrub}) {
            $entry = "kiwi_BiosGrub=\"$this->{partids}{biosgrub}\"\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
        }
        if ($this->{partids}{prep}) {
            $entry = "kiwi_OfwGrub=\"$this->{partids}{prep}\"\n";
            if (! $currentIDs{$entry}) { print $ID_FD $entry }
        }
        $ID_FD -> close();
    }
    return $this;
}

#==========================================
# cleanStack
#------------------------------------------
sub cleanStack {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $cStack = $this->{cleanupStack};
    my $status;
    my $result;
    if (! $cStack) {
        return;
    }
    #==========================================
    # make sure data is written
    #------------------------------------------
    KIWIQX::qxx ("sync");
    #==========================================
    # umount from global space
    #------------------------------------------
    KIWIGlobals -> instance() -> umount();
    #==========================================
    # cleanup device bindings from this object
    #------------------------------------------
    my @cStack = @{$cStack};
    foreach my $cmd (reverse @cStack) {
        $status = KIWIQX::qxx ("$cmd 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> warning ("cleanStack failed: $cmd: $status\n");
        }
    }
    #==========================================
    # reset cleanupStack
    #-----------------------------------------
    $this->{cleanupStack} = [];
    return;
}

#==========================================
# updateMD5File
#------------------------------------------
sub updateMD5File {
    my $this = shift;
    my $file = shift;
    my $outf = shift;
    my $kiwi = $this->{kiwi};
    #==========================================
    # Update md5file adding zblocks/zblocksize
    #------------------------------------------
    if (-e $outf) {
        $kiwi -> info ("Updating md5 file...");
        my $FD;
        if (! open ($FD, '<', $outf)) {
            $kiwi -> failed ();
            $kiwi -> error ("Failed to open md5 file: $!");
            $kiwi -> failed ();
            return;
        }
        my $line = <$FD>;
        close $FD;
        chomp $line;
        my $size = KIWIGlobals -> instance() -> isize ($file);
        my $primes = KIWIQX::qxx ("factor $size"); $primes =~ s/^.*: //;
        my $blocksize = 1;
        for my $factor (split /\s/,$primes) {
            last if ($blocksize * $factor > 65464);
            $blocksize *= $factor;
        }
        my $blocks = $size / $blocksize;
        KIWIQX::qxx ("echo \"$line $blocks $blocksize\" > $outf");
        $kiwi -> done();
    }
    return $this;
}

#==========================================
# writeMBRDiskLabel
#------------------------------------------
sub writeMBRDiskLabel {
    # ...
    # writes a 4byte random ID into the MBR of the
    # previosly installed boot manager. The function
    # returns the written ID or undef on error
    # ---
    my $this  = shift;
    my $file  = shift;
    my $kiwi  = $this->{kiwi};
    my $nid   = $this->{mbrid};
    if (! defined $nid) {
        $kiwi -> failed ();
        $kiwi -> error  ("MBR: don't have a mbr id");
        $kiwi -> failed ();
        return;
    }
    my $pid = pack "V", eval $nid; ## no critic
    my $FD = FileHandle -> new();
    if (! $FD -> open("+<$file")) {
        $kiwi -> failed ();
        $kiwi -> error  ("MBR: failed to open file: $file: $!");
        $kiwi -> failed ();
        return;
    }
    seek $FD,440,0;
    my $done = syswrite ($FD,$pid,4);
    if ((! $done) || ($done != 4)) {
        $kiwi -> failed ();
        if ($done) {
            $kiwi -> error  ("MBR: only $done bytes written");
        } else {
            $kiwi -> error  ("MBR: syswrite to $file failed: $!");
        }
        $kiwi -> failed ();
        seek $FD,0,2;
        $FD -> close();
        return;
    }
    seek $FD,0,2;
    $FD -> close();
    return $this;
}

#==========================================
# setupBootLoaderStages
#------------------------------------------
sub setupBootLoaderStages {
    my $this     = shift;
    my $loader   = shift;
    my $type     = shift;
    my $uuid     = shift;
    my $kiwi     = $this->{kiwi};
    my $typeinfo = $this->{type};
    my $tmpdir   = $this->{tmpdir};
    my $initrd   = $this->{initrd};
    my $zipped   = $this->{zipped};
    my $zipper   = $this->{gdata}->{IrdZipperCommand};
    my $firmware = $this->{firmware};
    my $arch     = $this->{arch};
    my $status   = 0;
    my $result   = 0;
    #==========================================
    # Grub2
    #------------------------------------------
    if ($loader eq "grub2") {
        my $efipc;
        my $grubpc;
        my $grubofw;
        my $xenpc;
        my $earlyboot  = "$tmpdir/boot/grub2/bootpart.cfg";
        my $unzip      = "$zipper -cd $initrd 2>&1";
        my %stages     = ();
        my $test       = "cat $initrd";
        my $grub_bios  = 'grub2';
        my $grub_efi   = 'grub2';
        my $grub_ofw   = 'grub2';
        my $grub_share = 'grub2';
        my $lib        = 'lib';
        if ($arch eq 'x86_64') {
            $efipc = 'x86_64-efi';
            $grubpc = 'i386-pc';
            $xenpc  = 'x86_64-xen';
        } elsif ($arch =~ /i.86/) {
            $efipc = 'i386-efi';
            $grubpc = 'i386-pc';
            $xenpc = 'i386-xen';
        } elsif (($arch eq 'aarch64') || ($arch eq 'arm64')) {
            $efipc = 'arm64-efi';
            $grubpc = 'arm64-efi';
        } elsif ($arch =~ /arm/) {
            $efipc = 'arm-efi';
            $grubpc = 'arm-efi';
        } elsif ($arch =~ /ppc|ppc64|ppc64le/) {
            if ($firmware eq 'ofw') {
                $grubofw = 'powerpc-ieee1275';
            }
        } else {
            $kiwi -> failed ();
            $kiwi -> error  (
                "grub2: Unsupported architecture/firmware: $arch/$firmware"
            );
            $kiwi -> failed ();
            return;
        }
        if ($zipped) {
            $test = $unzip;
        }
        $status = KIWIQX::qxx (
            "$test | cpio -it --quiet | grep -q share/grub/ 2>&1"
        );
        $result = $? >> 8;
        if ($result == 0) {
            $grub_share = 'grub';
        }
        $status = KIWIQX::qxx (
            "$test | cpio -it --quiet | grep -q lib/grub2/ 2>&1"
        );
        $result = $? >> 8;
        if ($result != 0) {
            $grub_bios = 'grub';
            $grub_efi  = 'grub';
        }
        $status = KIWIQX::qxx (
            "$test | cpio -it --quiet | grep -q lib64/efi 2>&1"
        );
        $result = $? >> 8;
        if ($result == 0) {
            $lib = 'lib64';
        }
        #==========================================
        # Stage files
        #------------------------------------------
        $stages{bios}{initrd}   = "'usr/lib/$grub_bios/$grubpc/*'";
        $stages{bios}{stageSRC} = "/usr/lib/$grub_bios/$grubpc";
        $stages{bios}{stageDST} = "/boot/grub2/$grubpc";
        if (($firmware eq "efi") || ($firmware eq "uefi")) {
            $stages{efi}{initrd}   = "'usr/lib/$grub_efi/$efipc/*'";
            $stages{efi}{stageSRC} = "/usr/lib/$grub_efi/$efipc";
            $stages{efi}{stageDST} = "/boot/grub2/$efipc";
        }
        if ($firmware eq "uefi") {
            $stages{efi}{data}      = "'usr/$lib/efi/*'";
            $stages{efi}{shim_ms}   = "usr/$lib/efi/shim.efi";
            $stages{efi}{shim_suse} = "usr/$lib/efi/shim-opensuse.efi";
            $stages{efi}{signed}    = "usr/$lib/efi/grub.efi";
        }
        if (($firmware eq "ec2") || ($firmware eq "ec2hvm")) {
            $stages{ec2}{initrd}   = "'usr/lib/$grub_bios/$xenpc/*'";
            $stages{ec2}{stageSRC} = "/usr/lib/$grub_bios/$xenpc";
            $stages{ec2}{stageDST} = "/boot/grub2/$xenpc";
        }
        if ($firmware eq "ofw") {
            $stages{ofw}{initrd}    = "'usr/lib/$grub_ofw/$grubofw/*'";
            $stages{ofw}{stageSRC}  = "/usr/lib/$grub_ofw/$grubofw";
            $stages{ofw}{stageDST}  = "/boot/grub2/$grubofw";
        }
        #==========================================
        # Module lists for self created grub images
        #------------------------------------------
        my @core_modules = (
            'ext2','iso9660','linux','echo','configfile',
            'search_label','search_fs_file','search',
            'search_fs_uuid','ls','normal','gzio',
            'png','fat','gettext','font','minicmd',
            'gfxterm','gfxmenu','video','video_fb'
        );
        my @bios_core_modules = (
            'part_msdos','part_gpt'
        );
        if ($typeinfo->{filesystem} eq 'xfs') {
            push @core_modules, 'xfs';
        }
        if ($typeinfo->{filesystem} eq 'btrfs') {
            push @core_modules, 'btrfs';
        }
        if ($typeinfo->{lvm}) {
            push @core_modules, 'lvm';
        }
        push @core_modules, 'boot';
        push @bios_core_modules, qw /chain/;
        if ($arch =~ /i.86|x86_64/) {
            push @bios_core_modules, qw /biosdisk vga vbe multiboot/;
        }
        my @efi_core_modules = (
            'part_gpt','efi_gop'
        );
        my @ofw_core_modules = (
            'ofnet','part_gpt','part_msdos'
        );
        push @efi_core_modules ,@core_modules;
        push @bios_core_modules,@core_modules;
        push @ofw_core_modules,@core_modules;
        #==========================================
        # Boot directories
        #------------------------------------------
        my @bootdir = ("$tmpdir/boot/grub2/$grubpc");
        if (($firmware eq "efi") || ($firmware eq "uefi")) {
            push @bootdir,"$tmpdir/boot/grub2/$efipc";
            push @bootdir,"$tmpdir/EFI/BOOT";
        }
        if ($firmware eq "ofw") {
            @bootdir = ("$tmpdir/boot/grub2/$grubofw");
        }
        if (($firmware eq 'ec2') || ($firmware eq 'ec2hvm')) {
            push @bootdir,"$tmpdir/boot/grub2/$xenpc";
        }
        if ($arch =~ /i.86|x86_64/) {
            push @efi_core_modules,'efi_uga';
        }
        $status = KIWIQX::qxx ("mkdir -p @bootdir 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed creating boot manager directory: $status");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # Create boot partition file
        #------------------------------------------
        $kiwi -> info ("Creating grub2 boot partition map\n");
        if ($uuid) {
            $kiwi -> info ("--> Using fs-uuid search method\n");
            $kiwi -> loginfo ("grub search fs-uuid: $uuid\n");
        } else {
            $kiwi -> info ("--> Using file search method\n");
            $kiwi -> loginfo ("grub search file: boot/$this->{mbrid}\n");
        }
        my $bpfd = FileHandle -> new();
        if (! $bpfd -> open(">$earlyboot")) {
            $kiwi -> failed ();
            $kiwi -> error ("Couldn't create grub2 bootpart map: $!");
            $kiwi -> failed ();
            return;
        }
        my $bootpath = '/boot';
        if (($type ne 'iso') && (! $this->{needBootP})) {
            if (($typeinfo->{filesystem} eq 'btrfs') && ($this->{sysdisk})) {
                my $volumes = $this->{sysdisk} -> getVolumes();
                if (($volumes) && (keys %{$volumes} > 0)) {
                    $bootpath = '/@/boot';
                }
            }
        }
        if ($uuid) {
            print $bpfd "search --fs-uuid --set=root $uuid";
        } else {
            print $bpfd "search --file --set=root $bootpath/$this->{mbrid}";
        }
        print $bpfd "\n";
        print $bpfd 'set prefix=($root)'.$bootpath.'/grub2'."\n";
        $bpfd -> close();
        #==========================================
        # Get Grub2 stage and theming files
        #------------------------------------------
        $kiwi -> info ("Importing grub2 stage and theming files");
        my $figure= "'usr/share/$grub_share/themes/*'";
        my $s_efi = "";
        my $s_bio = "";
        my $s_ofw = "";
        my $s_ec2 = "";
        if ($stages{efi}{initrd}) {
            $s_efi = "-d $stages{efi}{initrd}";
        }
        if ($stages{bios}{initrd}) {
            $s_bio = "-d $stages{bios}{initrd}";
        }
        if ($stages{ofw}{initrd}) {
            $s_ofw = "-d $stages{ofw}{initrd}";
        }
        if ($stages{ec2}{initrd}) {
            $s_ec2 = "-d $stages{ec2}{initrd}";
        }
        if ($zipped) {
            $status= KIWIQX::qxx (
                "$unzip | \\
                (cd $tmpdir && cpio -i -d $figure $s_bio $s_efi $s_ofw $s_ec2 2>&1)"
            );
        } else {
            $status= KIWIQX::qxx (
                "cat $initrd | \\
                (cd $tmpdir && cpio -i -d $figure $s_bio $s_efi $s_ofw $s_ec2 2>&1)"
            );
        }
        #==========================================
        # import Grub2 theme files...
        #------------------------------------------
        foreach my $grub ('grub','grub2') {
            if (-d "$tmpdir/usr/share/$grub/themes") {
                $status = KIWIQX::qxx (
                    "mv $tmpdir/usr/share/$grub/themes $tmpdir/boot/grub2 2>&1"
                );
                last;
            }
        }
        #==========================================
        # import Grub2 stage files...
        #------------------------------------------
        my $stagesOK   = 0;
        my $stagesBIOS = 0;
        my $stagesEFI  = 0;
        my $stagesOFW  = 0;
        my $stagesEC2  = 0;
        my @stageFiles = ('bios');
        if (($firmware eq "efi") || ($firmware eq "uefi")) {
            push @stageFiles,'efi';
        }
        if ($firmware eq "ofw") {
            @stageFiles = ('ofw');
        }
        if (($firmware eq "ec2") || ($firmware eq "ec2hvm")) {
            push @stageFiles,'ec2';
        }
        foreach my $stage (@stageFiles) {
            my $stageD = $stages{$stage}{stageSRC};
            my $stageT = $stages{$stage}{stageDST};
            if (-d $tmpdir.$stageD) {
                $status = KIWIQX::qxx (
                    'cp '.$tmpdir.$stageD.'/* '.$tmpdir.$stageT.' 2>&1'
                );
                $result = $? >> 8;
                if ($result != 0) {
                    next;
                }
                $stagesOK = 1;
                if ($stage eq 'bios') {
                    $stagesBIOS = 1;
                } elsif ($stage eq 'ec2') {
                    $stagesEC2 = 1;
                } elsif ($stage eq 'efi') {
                    $stagesEFI = 1;
                } elsif ($stage eq 'ofw') {
                    $stagesOFW = 1;
                }
            }
        }
        if (! $stagesOK) {
            $kiwi -> failed ();
            $kiwi -> error  ("No grub2 stage files found in boot image");
            $kiwi -> failed ();
            return;
        }
        if (($firmware =~ /efi/) && (! $stagesEFI)) {
            $kiwi -> failed ();
            $kiwi -> error  ("No grub2 EFI stage files found in boot image");
            $kiwi -> failed ();
            return;
        }
        if (($firmware eq 'bios') && (! $stagesBIOS)) {
            $kiwi -> failed ();
            $kiwi -> error  ("No grub2 BIOS stage files found in boot image");
            $kiwi -> failed ();
            return;
        }
        if (($firmware eq 'ofw') && (! $stagesOFW)) {
            $kiwi -> failed ();
            $kiwi -> error  ("No grub2 OFW stage files found in boot image");
            $kiwi -> failed ();
            return;
        }
        if (($firmware =~ /ec2/) && (! $stagesEC2)) {
            $kiwi -> failed ();
            $kiwi -> error  (
                "No grub2 EC2 Xen stage files found in boot image"
            );
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
        #==========================================
        # Lookup grub2 mkimage tool
        #------------------------------------------
        my $locator = KIWILocator -> instance();
        my $grub2_mkimage = $locator -> getExecPath ("grub2-mkimage");
        #==========================================
        # Create core efi boot image, standard EFI
        #------------------------------------------
        if ($firmware eq "efi") {
            $kiwi -> info ("Creating grub2 efi boot image");
            if (! $grub2_mkimage) {
                $kiwi -> failed ();
                $kiwi -> error  ("Can't find grub2 mkimage tool");
                $kiwi -> failed ();
                return;
            }
            my @modules = @efi_core_modules;
            my $fo;
            my $fo_bin;
            if ($arch eq 'x86_64') {
                $fo      = 'x86_64-efi';
                $fo_bin  = 'bootx64.efi';
            } elsif ($arch =~ /i.86/) {
                $fo     = 'i386-efi';
                $fo_bin = 'bootx32.efi';
            } elsif (($arch eq 'aarch64') || ($arch eq 'arm64')) {
                $fo     = 'arm64-efi';
                $fo_bin = 'bootaa64.efi';
            } elsif ($arch =~ /arm/) {
                $fo     = 'arm-efi';
                $fo_bin = 'bootarm.efi';
            }
            my $core= "$tmpdir/EFI/BOOT/$fo_bin";
            my $core_opts;
            $core_opts = "-O $fo -o $core -c $earlyboot ";
            $core_opts.= "-d $tmpdir/$stages{efi}{stageSRC}";
            $status = KIWIQX::qxx (
                "$grub2_mkimage $core_opts @modules 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't create efi boot image: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
        }
        #==========================================
        # Use signed EFI modules from packages UEFI
        #------------------------------------------
        if ($firmware eq "uefi") {
            $kiwi -> info ("Importing grub2 shim/signed efi modules");
            my $s_data      = $stages{efi}{data};
            my $s_shim_ms   = $stages{efi}{shim_ms};
            my $s_shim_suse = $stages{efi}{shim_suse};
            my $s_signed    = $stages{efi}{signed};
            my $fo_bin;
            if ($arch eq 'x86_64') {
                $fo_bin = 'bootx64.efi';
            } elsif ($arch =~ /i.86/) {
                $fo_bin = 'bootx32.efi';
            } elsif (($arch eq 'aarch64') || ($arch eq 'arm64')) {
                $fo_bin = 'bootaa64.efi';
            } elsif ($arch =~ /arm/) {
                $fo_bin = 'bootarm.efi';
            }
            $result = 0;
            if ($zipped) {
                $status= KIWIQX::qxx (
                    "$unzip | (cd $tmpdir && cpio -i -d $s_data 2>&1)"
                );
            } else {
                $status= KIWIQX::qxx (
                    "cat $initrd | (cd $tmpdir && cpio -i -d $s_data 2>&1)"
                );
            }
            if ((! -e "$tmpdir/$s_shim_ms") && (! -e "$tmpdir/$s_shim_suse")) {
                my $s_shim = "$tmpdir/$s_shim_ms";
                if (-e $s_shim) {
                    $s_shim = "$tmpdir/$s_shim_suse"
                }
                $kiwi -> failed ();
                $kiwi -> error  (
                    "Can't find shim $s_shim in initrd");
                $kiwi -> failed ();
                return;
            }
            if (! -e "$tmpdir/$s_signed") {
                $kiwi -> failed ();
                $kiwi -> error  (
                    "Can't find grub2 $s_signed in initrd");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "cp $tmpdir/$s_shim_ms $tmpdir/EFI/BOOT/$fo_bin 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $status = KIWIQX::qxx (
                    "cp $tmpdir/$s_shim_suse $tmpdir/EFI/BOOT/$fo_bin 2>&1"
                );
                $result = $? >> 8;
            }
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error ("Failed to copy shim module: $status");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "cp $tmpdir/$s_signed $tmpdir/EFI/BOOT/grub.efi 2>&1");
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error ("Failed to copy signed module: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
        }
        #==========================================
        # Create OFW grub2 boot images
        #------------------------------------------
        if ($firmware eq 'ofw') {
            $kiwi -> info ("Creating grub2 ofw core boot image");
            if (! $grub2_mkimage) {
                $kiwi -> failed ();
                $kiwi -> error  ("Can't find grub2 mkimage tool");
                $kiwi -> failed ();
                return;
            }
            my $format   = $grubofw;
            my @modules  = @ofw_core_modules;
            my $core     = "$tmpdir/boot/grub2/$format/core.elf";
            my $core_opts;
            $core_opts = "-O $format -o $core -c $earlyboot";
            $core_opts.= "-d $tmpdir/$stages{ofw}{stageSRC}";
            my $status = KIWIQX::qxx (
                "$grub2_mkimage $core_opts @modules 2>&1"
            );
            my $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't create core boot image: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
        }
        #==========================================
        # Create core grub2 boot images
        #------------------------------------------
        if (($stagesBIOS) || ($stagesEC2)) {
            $kiwi -> info ("Creating grub2 core boot image");
            if (! $grub2_mkimage) {
                $kiwi -> failed ();
                $kiwi -> error  ("Can't find grub2 mkimage tool");
                $kiwi -> failed ();
                return;
            }
            my $format   = $grubpc;
            my @modules  = @bios_core_modules;
            my $core     = "$tmpdir/boot/grub2/$format/core.img";
            my $cdimg    = "$tmpdir/boot/grub2/$format/eltorito.img";
            my $cdcore   = "$tmpdir/boot/grub2/$format/cdboot.img";
            my $core_opts;
            $core_opts = "-O $format -o $core -c $earlyboot ";
            $core_opts.= "-d $tmpdir/$stages{bios}{stageSRC}";
            my $status = KIWIQX::qxx (
                "$grub2_mkimage $core_opts @modules 2>&1"
            );
            my $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't create core boot image: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
            #==========================================
            # Create eltorito grub2 boot image
            #------------------------------------------
            if ((defined $type) && ($type eq "iso")) {
                $kiwi -> info ("Creating grub2 eltorito boot image");
                $status = KIWIQX::qxx ("cat $cdcore $core > $cdimg");
                $result = $? >> 8;
                if ($result != 0) {
                    $kiwi -> failed ();
                    $kiwi -> error  ("Couldn't create eltorito image: $status");
                    $kiwi -> failed ();
                    return;
                }
                $kiwi -> done();
            }
        }
    }
    #==========================================
    # Grub
    #------------------------------------------
    if ($loader eq "grub") {
        my $stages = "'usr/lib/grub/*'";
        my $figure = "'image/loader/message'";
        my $unzip  = "$zipper -cd $initrd 2>&1";
        $status = KIWIQX::qxx ( "mkdir -p $tmpdir/boot/grub 2>&1" );
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed creating boot manager directory: $status");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # Get Grub graphics boot message
        #------------------------------------------
        $kiwi -> info ("Importing graphics boot message and stage files");
        if ($zipped) {
            $status= KIWIQX::qxx (
                "$unzip | (cd $tmpdir && cpio -i -d $figure -d $stages 2>&1)"
            );
        } else {
            $status= KIWIQX::qxx (
                "cat $initrd|(cd $tmpdir && cpio -i -d $figure -d $stages 2>&1)"
            );
        }
        if (-e $tmpdir."/image/loader/message") {
            $status = KIWIQX::qxx (
                "mv $tmpdir/$figure $tmpdir/boot/message 2>&1"
            );
            $result = $? >> 8;
            $kiwi -> done();
        } else {
            $kiwi -> skipped();
        }
        #==========================================
        # check Grub stage files...
        #------------------------------------------
        if (glob($tmpdir."/usr/lib/grub/*")) {
            $status = KIWIQX::qxx (
                "mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1"
            );
            $result = $? >> 8;
            if (($result == 0) && (defined $type) && ($type eq "iso")) {
                my $src = "$tmpdir/boot/grub/stage2_eltorito";
                my $dst = "$tmpdir/boot/grub/stage2";
                $status = KIWIQX::qxx ("mv $src $dst 2>&1");
                $result = $? >> 8;
            }
        } else {
            $kiwi -> warning ("No grub stage files found in boot image");
            $kiwi -> skipped ();
            $kiwi -> info    ("Trying to use grub stages from local machine");
            $status = KIWIQX::qxx ("cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1");
            $result = $? >> 8;
            if (($result == 0) && (defined $type) && ($type eq "iso")) {
                my $src = "$tmpdir/boot/grub/stage2_eltorito";
                my $dst = "$tmpdir/boot/grub/stage2";
                $status = KIWIQX::qxx ("mv $src $dst 2>&1");
                $result = $? >> 8;
            }
            if ($result != 0) {
                $kiwi -> error  ("Failed importing grub stages: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
        }
    }
    #==========================================
    # syslinux
    #------------------------------------------
    if ($loader =~ /(sys|ext)linux/) {
        my $message= "'image/loader/*'";
        my $unzip  = "$zipper -cd $initrd 2>&1";
        #==========================================
        # Create syslinux boot data directory
        #------------------------------------------
        KIWIQX::qxx ("mkdir -p $tmpdir/boot/syslinux 2>&1");
        #==========================================
        # Get syslinux graphics data
        #------------------------------------------
        $kiwi -> info ("Importing graphics boot message");
        if ($zipped) {
            $status= KIWIQX::qxx (
                "$unzip | (cd $tmpdir && cpio -di $message 2>&1)"
            );
        } else {
            $status= KIWIQX::qxx (
                "cat $initrd|(cd $tmpdir && cpio -di $message 2>&1)"
            );
        }
        if (-d $tmpdir."/image/loader") {
            $status = KIWIQX::qxx (
                "mv $tmpdir/image/loader/* $tmpdir/boot/syslinux 2>&1"
            );
            $result = $? >> 8;
            $kiwi -> done();
        } else {
            $kiwi -> skipped();
        }
        #==========================================
        # Cleanup tmpdir
        #------------------------------------------
        KIWIQX::qxx ("rm -rf $tmpdir/image 2>&1");
    }
    #==========================================
    # yaboot
    #------------------------------------------
    if ($loader eq "yaboot") {
        my $chrp  = "'lib/lilo/chrp/yaboot.chrp'";
        my $unzip = "$zipper -cd $initrd 2>&1";
        #==========================================
        # Create yaboot boot data directory
        #------------------------------------------
        KIWIQX::qxx ("mkdir -p $tmpdir/boot 2>&1");
        #==========================================
        # Get lilo chrp data
        #------------------------------------------
        $kiwi -> info ("Importing yaboot.chrp file");
        if ($zipped) {
            $status= KIWIQX::qxx (
                "$unzip | (cd $tmpdir && cpio -di $chrp 2>&1)"
            );
        } else {
            $status= KIWIQX::qxx (
                "cat $initrd|(cd $tmpdir && cpio -di $chrp 2>&1)"
            );
        }
        if (-e $tmpdir."/lib/lilo/chrp/yaboot.chrp") {
            KIWIQX::qxx (
                "mv $tmpdir/lib/lilo/chrp/yaboot.chrp $tmpdir/boot/yaboot"
            );
        } else {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to import yaboot.chrp file: $status");
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
    }
    #==========================================
    # uboot stages
    #------------------------------------------
    if (($loader eq "uboot") || ($loader eq "berryboot")) {
        my $loaders= "'image/loader/*'";
        my $unzip  = "$zipper -cd $initrd 2>&1";
        #==========================================
        # Create boot data directory
        #------------------------------------------
        KIWIQX::qxx ("mkdir -p $tmpdir/boot 2>&1");
        #==========================================
        # Get MLO loaders
        #------------------------------------------
        $kiwi -> info ("Importing $loader loaders");
        if ($zipped) {
            $status= KIWIQX::qxx (
                "$unzip | (cd $tmpdir && cpio -di $loaders 2>&1)"
            );
        } else {
            $status= KIWIQX::qxx (
                "cat $initrd|(cd $tmpdir && cpio -di $loaders 2>&1)"
            );
        }
        if (-d $tmpdir."/image/loader") {
            $status = KIWIQX::qxx (
                "mv $tmpdir/image/loader/* $tmpdir/boot 2>&1"
            );
            $result = $? >> 8;
            $kiwi -> done();
        } else {
            $kiwi -> skipped();
        }
        #==========================================
        # Cleanup tmpdir
        #------------------------------------------
        KIWIQX::qxx ("rm -rf $tmpdir/image 2>&1");
    }
    #==========================================
    # more boot managers to come...
    #------------------------------------------
    return $this;
}

#==========================================
# setupBootLoaderConfiguration
#------------------------------------------
sub setupBootLoaderConfiguration {
    my $this     = shift;
    my $loader   = shift;
    my $topic    = shift;
    my $extra    = shift;
    my $iso      = shift;
    my $uuid     = shift;
    my $type     = $this->{type};
    my $cmdL     = $this->{cmdL};
    my $system   = $this->{system};
    my $kiwi     = $this->{kiwi};
    my $tmpdir   = $this->{tmpdir};
    my $initrd   = $this->{initrd};
    my $isxen    = $this->{isxen};
    my $xendomain= $this->{xendomain};
    my $imgtype  = $this->{imgtype};
    my $label    = $this->{bootlabel};
    my $vga      = $this->{vga};
    my $xml      = $this->{xml};
    my $firmware = $this->{firmware};
    my $failsafe = 1;
    my $cmdline;
    my $title;
    #==========================================
    # set empty label if not defined
    #------------------------------------------
    if (! $label) {
        $label = "";
    }
    #==========================================
    # Failsafe boot options
    #------------------------------------------
    my @failsafe = (
        'ide=nodma',
        'apm=off',
        'noresume',
        'edd=off',
        'powersaved=off',
        'nohz=off',
        'highres=off',
        'processsor.max+cstate=1',
        'nomodeset',
        'x11failsafe'
    );
    #==========================================
    # store loader type in object instance
    #------------------------------------------
    $this->{loader} = $loader;
    #==========================================
    # setup boot loader default boot label/nr
    #------------------------------------------
    my $defaultBootNr = 0;
    if ($type->{cmdline}) {
        $cmdline  = $type->{cmdline};
    }
    if (($cmdline) && ($cmdline =~ /root=(.*)/)) {
        $kiwi -> info (
            "Kernel root device set to $1 via custom cmdline\n"
        );
    } elsif ($firmware eq 'ec2') {
        # /.../
        # EC2 requires to specifiy the root device in the bootloader
        # configuration. EC2 extracts this information via pygrub and
        # use it for the guest configuration which has an impact on
        # the devices attached to the guest. With the current EC2
        # implementation and linux kernel the storage device allways
        # appears as /dev/sda1. Thus this value is set as fixed
        # kernel commandline parameter
        # ----
        $kiwi -> info (
            "Kernel root device set to /dev/sda1 via $firmware firmware\n"
        );
        $cmdline .= " root=/dev/sda1";
    } elsif ($firmware eq 'ec2hvm') {
        # /.../
        # Similar to the firmware type 'ec2', EC2 needs in case of HVM
        # (hardware-assisted virtual machine) instances the root device to be
        # set to /dev/hda1.
        #
        # Reason:
        # During the first boot, kiwi tries to detect the root device via
        # "hwinfo --storage", takes the first entry and creates an initrd and
        # bootlaoder configuration based on this assumption. The problem is,
        # that the first entry refers to /dev/sda1 (the second is /dev/hda1).
        # During the second reboot, /dev/sda will be removed from the system
        # and therefore such an instance won't come up.
        # ----
        $kiwi -> info (
            "Kernel root device set to /dev/hda1 via $firmware firmware\n"
        );
        $cmdline .= " root=/dev/hda1";
    }
    if ($topic =~ /^KIWI (CD|USB) Boot/) {
        # /.../
        # use predefined set of parameters for simple boot CD
        # not including a system image
        # ----
        $type->{installboot} = "install";
        $type->{boottimeout} = 1;
        $type->{fastboot}    = 1;
        $vga="normal";
    }
    if ($topic =~ /^KIWI (CD|USB)/) {
        # In install mode we have the following menu layout
        # ----
        # 0 -> Boot from Hard Disk
        # 1 -> Install $label
        # 2 -> [ Failsafe -- Install $label ]
        # ----
        if ($type->{installboot}) {
            if ($type->{installboot} eq 'install') {
                $defaultBootNr = 1;
            }
            if ($type->{installboot} eq 'failsafe-install') {
                $defaultBootNr = 2;
            }
        }
        if (($type->{installprovidefailsafe}) &&
            ($type->{installprovidefailsafe} eq 'false')
        ) {
            $failsafe = 0;
            if ($defaultBootNr == 2) {
                $defaultBootNr = 1;
            }
        }
    }
    #==========================================
    # report additional cmdline options
    #------------------------------------------
    if ($cmdline) {
        $kiwi -> loginfo (
            "Additional commandline options: \"$cmdline\""
        );
    }
    #==========================================
    # join common options, finish with '\n'
    #------------------------------------------
    $cmdline .= " $extra" if $extra;
    if (($imgtype) && ($imgtype eq 'split')) {
        $cmdline .= " COMBINED_IMAGE=yes";
    }
    $cmdline .= " showopts\n";
    # ensure exactly one space at start
    $cmdline =~ s/^\s*/ /;
    #==========================================
    # Create MBR id file for boot device check
    #------------------------------------------
    if ($firmware ne "ofw") {
        $kiwi -> info ("Saving disk label boot/mbrid: $this->{mbrid}...");
        KIWIQX::qxx ("mkdir -p $tmpdir/boot");
        my $FD;
        if (! open ($FD,'>',"$tmpdir/boot/mbrid")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create mbrid file: $!");
            $kiwi -> failed ();
            return;
        }
        print $FD "$this->{mbrid}";
        close $FD;
        $kiwi -> done();
    }
    #==========================================
    # Grub2
    #------------------------------------------
    if ($loader eq "grub2") {
        #==========================================
        # Theme and Fonts table
        #------------------------------------------
        my $theme = $xml -> getPreferences() -> getBootLoaderTheme();
        my $ascii = 'ascii.pf2';
        my $fodir = '/boot/grub2/themes/';
        my $bootpath = '/boot';
        if ((! $iso) && (! $this->{needBootP})) {
            if (($type->{filesystem} eq 'btrfs') && ($this->{sysdisk})) {
                my $volumes = $this->{sysdisk} -> getVolumes();
                if (($volumes) && (keys %{$volumes} > 0)) {
                    $bootpath = '/@/boot';
                    $fodir = '/@/boot/grub2/themes/';
                }
            }
        }
        my @fonts = (
            "DejaVuSans-Bold14.pf2",
            "DejaVuSans10.pf2",
            "DejaVuSans12.pf2",
            "ascii.pf2"
        );
        my $font;
        #==========================================
        # config file name
        #------------------------------------------
        my $config = 'grub2';
        #==========================================
        # gfxpayload mapping table
        #------------------------------------------
        my %vesa;
        $vesa{'0x301'} = ["640x480x8"   , "640x480"  ];
        $vesa{'0x310'} = ["640x480x16"  , "640x480"  ];
        $vesa{'0x311'} = ["640x480x24"  , "640x480"  ];
        $vesa{'0x312'} = ["640x480x32"  , "640x480"  ];
        $vesa{'0x303'} = ["800x600x8"   , "800x600"  ];
        $vesa{'0x313'} = ["800x600x16"  , "800x600"  ];
        $vesa{'0x314'} = ["800x600x24"  , "800x600"  ];
        $vesa{'0x315'} = ["800x600x32"  , "800x600"  ];
        $vesa{'0x305'} = ["1024x768x8"  , "1024x768" ];
        $vesa{'0x316'} = ["1024x768x16" , "1024x768" ];
        $vesa{'0x317'} = ["1024x768x24" , "1024x768" ];
        $vesa{'0x318'} = ["1024x768x32" , "1024x768" ];
        $vesa{'0x307'} = ["1280x1024x8" , "1280x1024"];
        $vesa{'0x319'} = ["1280x1024x16", "1280x1024"];
        $vesa{'0x31a'} = ["1280x1024x24", "1280x1024"];
        $vesa{'0x31b'} = ["1280x1024x32", "1280x1024"];
        my $gfx = 'keep';
        if (($vga) && ($vesa{$vga})) {
            $gfx = $vesa{$vga}->[1];
        }
        #==========================================
        # add unicode font for grub2
        #------------------------------------------
        foreach my $grub ('grub2','grub') {
            $font = "/usr/share/$grub/unicode.pf2";
            last if (-e $font);
        }
        if (($font) && (-e $font)) {
            KIWIQX::qxx ("cp $font $tmpdir/boot");
        } else {
            $kiwi -> warning ("Can't find unicode font for grub2");
            $kiwi -> skipped ();
        }
        #==========================================
        # Create grub.cfg file
        #------------------------------------------
        $kiwi -> info ("Creating grub2 configuration file...");
        KIWIQX::qxx ("mkdir -p $tmpdir/boot/$config");
        my $FD = FileHandle -> new();
        if (! $FD -> open(">$tmpdir/boot/$config/grub.cfg")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create $config/grub.cfg: $!");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # General grub2 setup
        #------------------------------------------
        if ($uuid) {
            print $FD "search --fs-uuid --set=root $uuid"."\n";
        } else {
            print $FD "search --file --set=root $bootpath/$this->{mbrid}"."\n";
        }
        print $FD 'set prefix=($root)'.$bootpath.'/grub2'."\n";
        # print $FD "set debug=all\n";
        print $FD 'set linux=linux'."\n";
        print $FD 'set initrd=initrd'."\n";
        print $FD 'if [ "${grub_cpu}" = "x86_64" ] or ';
        print $FD '[ "${grub_cpu}" = "i386" ]; then'."\n";
        print $FD '    if [ $grub_platform = "efi" ]; then'."\n";
        print $FD '        set linux=linuxefi'."\n";
        print $FD '        set initrd=initrdefi'."\n";
        print $FD '    fi'."\n";
        print $FD 'fi'."\n";
        print $FD "set default=$defaultBootNr\n";
        print $FD "set font=$bootpath/unicode.pf2"."\n";
        # setup to use boot graphics. If this is unwanted
        # you can disable it with the following alternative
        # console setup
        #
        # print $FD "\t".'terminal_input console'."\n";
        # print $FD "\t".'terminal_output console'."\n";
        #
        print $FD 'if loadfont $font ;then'."\n";
        print $FD "\t"."set gfxmode=$gfx"."\n";
        print $FD "\t".'terminal_input gfxterm'."\n";
        print $FD "\t".'if terminal_output gfxterm;then true;else'."\n";
        print $FD "\t\t".'terminal gfxterm'."\n";
        print $FD "\t".'fi'."\n";
        print $FD 'fi'."\n";
        print $FD 'if loadfont '.$fodir.$theme.'/'.$ascii.';then'."\n";
        foreach my $font (@fonts) {
            print $FD "\t".'loadfont '.$fodir.$theme.'/'.$font."\n";
        }
        print $FD "\t".'set theme='.$fodir.$theme.'/theme.txt'."\n";
        print $FD "\t".'background_image -m stretch ';
        print $FD $fodir.$theme.'/background.png'."\n";
        print $FD 'fi'."\n";
        # ----
        my $bootTimeout = 10;
        if (defined $type->{boottimeout}) {
            $bootTimeout = $type->{boottimeout};
        }
        if ($type->{fastboot}) {
            $bootTimeout = 0;
        }
        print $FD "set timeout=$bootTimeout\n";
        if ($topic =~ /^KIWI (CD|USB)/) {
            my $dev = $1 eq 'CD' ? '(cd)' : '(hd0,0)';
            my $arch = $this->{arch};
            print $FD 'menuentry "Boot from Hard Disk"';
            print $FD ' --class opensuse --class os {'."\n";
            if (($firmware eq "efi") || ($firmware eq "uefi")) {
                print $FD "\t"."search --set=root --label EFI"."\n";
                my $prefix = '(${root})/EFI/BOOT';
                if ($arch eq 'x86_64') {
                    print $FD "\t"."chainloader $prefix/bootx64.efi"."\n";
                } elsif ($arch =~ /i.86/) {
                    print $FD "\t"."chainloader $prefix/bootx32.efi"."\n";
                } elsif (($arch eq 'aarch64') || ($arch eq 'arm64')) {
                    print $FD "\t"."chainloader $prefix/bootaa64.efi"."\n";
                }
            } else {
                print $FD "\t"."set root='hd0'"."\n";
                if ($dev eq '(cd)') {
                    print $FD "\t".'chainloader +1'."\n";
                } else {
                    print $FD "\t"."chainloader $bootpath/grub2/bootnext"."\n";
                    my $bootnext = $this -> addBootNext (
                        "$tmpdir/boot/grub2/bootnext", hex $this->{mbrid}
                    );
                    if (! defined $bootnext) {
                        $kiwi -> failed ();
                        $kiwi -> error  ("Failed to write bootnext\n");
                        $kiwi -> failed ();
                        $FD -> close();
                        return;
                    }
                }
                print $FD "\t".'boot'."\n";
            }
            print $FD '}'."\n";
            $title = $this -> quoteLabel ("Install $label");
        } else {
            $title = $this -> quoteLabel ("$label [ $topic ]");
        }
        print $FD 'menuentry "'.$title.'"';
        print $FD ' --class opensuse --class os {'."\n";
        #==========================================
        # Standard boot
        #------------------------------------------
        if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
            if ($iso) {
                print $FD "\t"."echo Loading linux...\n";
                print $FD "\t"."set gfxpayload=$gfx"."\n";
                print $FD "\t".'$linux '.$bootpath.'/linux';
                print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
                print $FD " cdinst=1";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "\t"."echo Loading linux.vmx...\n";
                print $FD "\t"."set gfxpayload=$gfx"."\n";
                print $FD "\t".'$linux '.$bootpath.'/linux.vmx';
            } else {
                print $FD "\t"."echo Loading linux...\n";
                print $FD "\t"."set gfxpayload=$gfx"."\n";
                print $FD "\t".'$linux '.$bootpath.'/linux';
            }
            print $FD $cmdline;
            if ($iso) {
                print $FD "\t"."echo Loading initrd...\n";
                print $FD "\t".'$initrd '.$bootpath.'/initrd'."\n";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "\t"."echo Loading initrd.vmx...\n";
                print $FD "\t".'$initrd '.$bootpath.'/initrd.vmx'."\n";
            } else {
                print $FD "\t"."echo Loading initrd...\n";
                print $FD "\t".'$initrd '.$bootpath.'/initrd'."\n";
            }
            print $FD "}\n";
        } else {
            if ($iso) {
                print $FD "\t"."echo Loading Xen\n";
                print $FD "\t"."multiboot $bootpath/xen.gz dummy\n";
                print $FD "\t"."echo Loading linux...\n";
                print $FD "\t"."set gfxpayload=$gfx"."\n";
                print $FD "\t"."module $bootpath/linux dummy";
                print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
                print $FD " cdinst=1";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "\t"."echo Loading Xen\n";
                print $FD "\t"."multiboot $bootpath/xen.gz dummy\n";
                print $FD "\t"."echo Loading linux.vmx...\n";
                print $FD "\t"."set gfxpayload=$gfx"."\n";
                print $FD "\t"."module $bootpath/linux.vmx dummy";
            } else {
                print $FD "\t"."echo Loading Xen\n";
                print $FD "\t"."multiboot $bootpath/xen.gz dummy\n";
                print $FD "\t"."echo Loading linux...\n";
                print $FD "\t"."set gfxpayload=$gfx"."\n";
                print $FD "\t"."module $bootpath/linux dummy";
            }
            print $FD $cmdline;
            if ($iso) {
                print $FD "\t"."echo Loading initrd...\n";
                print $FD "\t"."module $bootpath/initrd dummy\n";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "\t"."echo Loading initrd...\n";
                print $FD "\t"."module $bootpath/initrd.vmx dummy\n";
            } else {
                print $FD "\t"."echo Loading initrd...\n";
                print $FD "\t"."module $bootpath/initrd dummy\n";
            }
            print $FD "}\n";
        }
        #==========================================
        # Failsafe boot
        #------------------------------------------
        if ($failsafe) {
            $title = $this -> quoteLabel ("Failsafe -- $title");
            print $FD 'menuentry "'.$title.'"';
            print $FD ' --class opensuse --class os {'."\n";
            if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
                if ($iso) {
                    print $FD "\t"."echo Loading linux...\n";
                    print $FD "\t"."set gfxpayload=$gfx"."\n";
                    print $FD "\t".'$linux '.$bootpath.'/linux';
                    print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
                    print $FD " cdinst=1";
                } elsif (
                    ($topic=~ /^KIWI USB/) ||
                    ($imgtype=~ /vmx|oem|split/)
                ) {
                    print $FD "\t"."echo Loading linux.vmx...\n";
                    print $FD "\t"."set gfxpayload=$gfx"."\n";
                    print $FD "\t".'$linux '.$bootpath.'/linux.vmx';
                } else {
                    print $FD "\t"."echo Loading linux...\n";
                    print $FD "\t"."set gfxpayload=$gfx"."\n";
                    print $FD "\t".'$linux '.$bootpath.'/linux';
                }
                print $FD " @failsafe";
                print $FD $cmdline;
                if ($iso) {
                    print $FD "\t"."echo Loading initrd...\n";
                    print $FD "\t".'$initrd '.$bootpath.'/initrd'."\n";
                } elsif (
                    ($topic=~ /^KIWI USB/) ||
                    ($imgtype=~ /vmx|oem|split/)
                ) {
                    print $FD "\t"."echo Loading initrd.vmx...\n";
                    print $FD "\t".'$initrd '.$bootpath.'/initrd.vmx'."\n";
                } else {
                    print $FD "\t"."echo Loading initrd...\n";
                    print $FD "\t".'$initrd '.$bootpath.'/initrd'."\n";
                }
                print $FD "}\n";
            } else {
                if ($iso) {
                    print $FD "\t"."echo Loading Xen\n";
                    print $FD "\t"."multiboot $bootpath/xen.gz dummy\n";
                    print $FD "\t"."echo Loading linux...\n";
                    print $FD "\t"."set gfxpayload=$gfx"."\n";
                    print $FD "\t"."module $bootpath/linux dummy";
                    print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
                    print $FD " cdinst=1";
                } elsif (
                    ($topic=~ /^KIWI USB/) ||
                    ($imgtype=~ /vmx|oem|split/)
                ) {
                    print $FD "\t"."echo Loading Xen\n";
                    print $FD "\t"."multiboot $bootpath/xen.gz dummy\n";
                    print $FD "\t"."echo Loading linux.vmx...\n";
                    print $FD "\t"."set gfxpayload=$gfx"."\n";
                    print $FD "\t"."module $bootpath/linux.vmx dummy";
                } else {
                    print $FD "\t"."echo Loading Xen\n";
                    print $FD "\t"."multiboot $bootpath/xen.gz dummy\n";
                    print $FD "\t"."echo Loading linux...\n";
                    print $FD "\t"."set gfxpayload=$gfx"."\n";
                    print $FD "\t"."module $bootpath/linux dummy";
                }
                print $FD " @failsafe";
                print $FD $cmdline;
                if ($iso) {
                    print $FD "\t"."echo Loading initrd...\n";
                    print $FD "\t"."module $bootpath/initrd dummy\n";
                } elsif (
                    ($topic=~ /^KIWI USB/) ||
                    ($imgtype=~ /vmx|oem|split/)
                ) {
                    print $FD "\t"."echo Loading initrd.vmx...\n";
                    print $FD "\t"."module $bootpath/initrd.vmx dummy\n";
                } else {
                    print $FD "\t"."echo Loading initrd...\n";
                    print $FD "\t"."module $bootpath/initrd dummy\n";
                }
                print $FD "}\n";
            }
        }
        $FD -> close();
        #==========================================
        # copy grub2 config file to efi path too
        #------------------------------------------
        if (($firmware eq "efi") || ($firmware eq "uefi")) {
            KIWIQX::qxx (
                "cp $tmpdir/boot/$config/grub.cfg $tmpdir/EFI/BOOT 2>&1"
            );
        }
        $kiwi -> done();
    }
    #==========================================
    # Grub
    #------------------------------------------
    if ($loader eq "grub") {
        if (($type->{installprovidefailsafe}) &&
            ($type->{installprovidefailsafe} eq 'false')
        ) {
            $failsafe = 0;
        }
        #==========================================
        # boot id in grub context
        #------------------------------------------
        my $boot_id = 0;
        if ($this->{partids}) {
            if ($this->{partids}{boot}) {
                $boot_id = $this->{partids}{boot} - 1;
            } elsif ($this->{partids}{root}) {
                $boot_id = $this->{partids}{root} - 1;
            }
        }
        #==========================================
        # Create menu.lst file
        #------------------------------------------
        $kiwi -> info ("Creating grub menu list file...");
        KIWIQX::qxx ("mkdir -p $tmpdir/boot/grub");
        my $FD = FileHandle -> new();
        if (! $FD -> open (">$tmpdir/boot/grub/menu.lst")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create menu.lst: $!");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # Compat link
        #------------------------------------------
        KIWIQX::qxx ("cd $tmpdir/boot/grub && ln -s menu.lst grub.conf");
        #==========================================
        # General grub setup
        #------------------------------------------
        binmode($FD, ":encoding(UTF-8)");
        print $FD "color cyan/blue white/blue\n";
        print $FD "default $defaultBootNr\n";
        my $bootTimeout = 10;
        if (defined $type->{boottimeout}) {
            $bootTimeout = $type->{boottimeout};
        }
        if ($type->{fastboot}) {
            $bootTimeout = 0;
        }
        print $FD "timeout $bootTimeout\n";
        if ($topic =~ /^KIWI (CD|USB)/) {
            my $dev = $1 eq 'CD' ? '(cd)' : "(hd0,$boot_id)";
            if (! $type->{fastboot}) {
                if (-e "$tmpdir/boot/grub/splash.xpm.gz") {
                    print $FD "splashimage=$dev/boot/grub/splash.xpm.gz\n"
                } elsif (-e "$tmpdir/boot/message") {
                    print $FD "gfxmenu $dev/boot/message\n";
                }
            }
            print $FD "title Boot from Hard Disk\n";
            if ($dev eq '(cd)') {
                print $FD " rootnoverify (hd0)\n";
                print $FD " chainloader (hd0)+1\n";
            } else {
                print $FD " chainloader $dev/boot/grub/bootnext\n";
                my $bootnext = $this -> addBootNext (
                    "$tmpdir/boot/grub/bootnext", hex $this->{mbrid}
                );
                if (! defined $bootnext) {
                    $kiwi -> failed ();
                    $kiwi -> error  ("Failed to write bootnext\n");
                    $kiwi -> failed ();
                    $FD -> close();
                    return;
                }
            }
            $title = $this -> makeLabel ("Install $label");
            print $FD "title $title\n";
        } else {
            $title = $this -> makeLabel ("$label [ $topic ]");
            if (-e "$tmpdir/boot/grub/splash.xpm.gz") {
                print $FD "splashimage=(hd0,$boot_id)/boot/grub/splash.xpm.gz\n"
            } elsif (-e "$tmpdir/boot/message") {
                print $FD "gfxmenu (hd0,$boot_id)/boot/message\n";
            }
            print $FD "title $title\n";
        }
        #==========================================
        # Standard boot
        #------------------------------------------
        if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
            if ($iso) {
                print $FD " kernel (cd)/boot/linux vga=$vga";
                print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
                print $FD " cdinst=1";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD " root (hd0,$boot_id)\n";
                print $FD " kernel /boot/linux.vmx vga=$vga";
            } else {
                print $FD " root (hd0,$boot_id)\n";
                print $FD " kernel /boot/linux vga=$vga";
            }
            print $FD $cmdline;
            if ($iso) {
                print $FD " initrd (cd)/boot/initrd\n";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD " initrd /boot/initrd.vmx\n";
            } else {
                print $FD " initrd /boot/initrd\n";
            }
        } else {
            if ($iso) {
                print $FD " kernel (cd)/boot/xen.gz\n";
                print $FD " module /boot/linux vga=$vga";
                print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
                print $FD " cdinst=1";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD " root (hd0,$boot_id)\n";
                print $FD " kernel /boot/xen.gz.vmx\n";
                print $FD " module /boot/linux.vmx vga=$vga";
            } else {
                print $FD " root (hd0,$boot_id)\n";
                print $FD " kernel /boot/xen.gz\n";
                print $FD " module /boot/linux vga=$vga";
            }
            print $FD $cmdline;
            if ($iso) {
                print $FD " module (cd)/boot/initrd\n";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD " module /boot/initrd.vmx\n";
            } else {
                print $FD " module /boot/initrd\n";
            }
        }
        #==========================================
        # Failsafe boot
        #------------------------------------------
        if ($failsafe) {
            $title = $this -> makeLabel ("Failsafe -- $title");
            print $FD "title $title\n";
            if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
                if ($iso) {
                    print $FD " kernel (cd)/boot/linux vga=$vga";
                    print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
                    print $FD " cdinst=1";
                } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                    print $FD " root (hd0,$boot_id)\n";
                    print $FD " kernel /boot/linux.vmx vga=$vga";
                } else {
                    print $FD " root (hd0,$boot_id)\n";
                    print $FD " kernel /boot/linux vga=$vga";
                }
                print $FD " @failsafe";
                print $FD $cmdline;
                if ($iso) {
                    print $FD " initrd (cd)/boot/initrd\n";
                } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                    print $FD " initrd /boot/initrd.vmx\n";
                } else {
                    print $FD " initrd /boot/initrd\n";
                }
            } else {
                if ($iso) {
                    print $FD " kernel (cd)/boot/xen.gz\n";
                    print $FD " module (cd)/boot/linux vga=$vga";
                    print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
                    print $FD " cdinst=1";
                } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                    print $FD " root (hd0,$boot_id)\n";
                    print $FD " kernel /boot/xen.gz.vmx\n";
                    print $FD " module /boot/linux.vmx vga=$vga";
                } else {
                    print $FD " root (hd0,$boot_id)\n";
                    print $FD " kernel /boot/xen.gz\n";
                    print $FD " module /boot/linux vga=$vga";
                }
                print $FD " @failsafe";
                print $FD $cmdline;
                if ($iso) {
                    print $FD " module (cd)/boot/initrd\n"
                } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                    print $FD " module /boot/initrd.vmx\n"
                } else {
                    print $FD " module /boot/initrd\n";
                }
            }
        }
        $FD -> close();
        $kiwi -> done();
    }
    #==========================================
    # syslinux
    #------------------------------------------
    if ($loader =~ /(sys|ext)linux/) {
        #==========================================
        # Create syslinux config file
        #------------------------------------------
        my $syslconfig = "syslinux.cfg";
        if ($loader eq "extlinux") {
            $syslconfig = "extlinux.conf";
        }
        $kiwi -> info ("Creating $syslconfig config file...");
        my $FD = FileHandle -> new();
        if (! $FD -> open (">$tmpdir/boot/syslinux/$syslconfig")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create $syslconfig: $!");
            $kiwi -> failed ();
            return;
        }
        my $syslinux_new_format = 0;
        my $gfx = "$tmpdir/boot/syslinux";
        if (-f "$gfx/gfxboot.com" || -f "$gfx/gfxboot.c32") {
            $syslinux_new_format = 1;
        }
        #==========================================
        # General syslinux setup
        #------------------------------------------
        print $FD "implicit 1"."\n";
        print $FD "prompt   1"."\n";
        my $bootTimeout = 100;
        if (defined $type->{boottimeout}) {
            $bootTimeout = $type->{boottimeout};
            if (int ($bootTimeout) == 0) {
                # /.../
                # a timeout value of 0 disables the timeout in syslinux
                # therefore we set the smallest possible value in that case
                # which is 1/10 sec
                # ----
                $bootTimeout = 1;
            }
        }
        print $FD "timeout  $bootTimeout"."\n";
        print $FD "display isolinux.msg"."\n";
        my @labels = ();
        if (-f "$gfx/bootlogo") {
            if ($syslinux_new_format) {
                print $FD "ui gfxboot bootlogo isolinux.msg"."\n";
            } else {
                print $FD "gfxboot bootlogo"."\n";
            }
        } else {
            print $FD "ui menu.c32"."\n";
        }
        #==========================================
        # Setup default title
        #------------------------------------------
        if ($topic =~ /^KIWI (CD|USB)/) {
            if ($defaultBootNr == 0) {
                $title = $this -> makeLabel ("Boot from Hard Disk");
            } elsif ($defaultBootNr == 1) {
                $title = $this -> makeLabel ("Install $label");
            } else {
                $title = $this -> makeLabel (
                    "Failsafe -- Install $label"
                );
            }
        } else {
            $title = $this -> makeLabel ("$label [ $topic ]");
        }
        print $FD "default $title"."\n";
        if ($topic =~ /^KIWI (CD|USB)/) {
            $title = $this -> makeLabel ("Boot from Hard Disk");
            print $FD "label $title\n";
            push @labels,$title;
            print $FD "localboot 0x80\n";
            $title = $this -> makeLabel ("Install $label");
        } else {
            $title = $this -> makeLabel ("$label [ $topic ]");
        }
        print $FD "label $title"."\n";
        push @labels,$title;
        #==========================================
        # Standard boot
        #------------------------------------------
        if (! $isxen) {
            if ($iso) {
                print $FD "kernel linux\n";
                print $FD "append initrd=initrd ";
                print $FD "vga=$vga ";
                print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                print $FD "cdinst=1 kiwi_hybrid=1";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "kernel /boot/linux.vmx\n";
                print $FD "append initrd=/boot/initrd.vmx ";
                print $FD "vga=$vga";
            } else {
                print $FD "kernel /boot/linux\n";
                print $FD "append initrd=/boot/initrd ";
                print $FD "vga=$vga";
            }
            print $FD $cmdline;
        } else {
            chomp $cmdline;
            if ($iso) {
                print $FD "kernel mboot.c32\n";
                print $FD "append xen.gz --- linux ";
                print $FD "vga=$vga ";
                print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                print $FD "cdinst=1 kiwi_hybrid=1${cmdline} ";
                print $FD "--- initrd showopts"."\n";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "kernel mboot.c32\n";
                print $FD "append boot/xen.gz --- boot/linux.vmx ";
                print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                print $FD "vga=${vga}${cmdline} ";
                print $FD "--- boot/initrd.vmx showopts"."\n";
            } else {
                print $FD "kernel mboot.c32\n";
                print $FD "append boot/xen.gz --- boot/linux ";
                print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                print $FD "vga=${vga}${cmdline} ";
                print $FD "--- boot/initrd showopts"."\n";
            }
        }
        #==========================================
        # Failsafe boot
        #------------------------------------------
        if ($failsafe) {
            if ($iso) {
                $title = $this -> makeLabel ("Failsafe -- Install $label");
                print $FD "label $title"."\n";
            } elsif ($topic =~ /^KIWI USB/) {
                $title = $this -> makeLabel ("Failsafe -- Install $label");
                print $FD "label $title"."\n";
            } else {
                $title = $this -> makeLabel ("Failsafe -- $label [ $topic ]");
                print $FD "label $title"."\n";
            }
            push @labels,$title;
            if (! $isxen) {
                if ($iso) {
                    print $FD "kernel linux\n";
                    print $FD "append initrd=initrd ";
                    print $FD "vga=$vga ";
                    print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                    print $FD "cdinst=1 kiwi_hybrid=1";
                } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                    print $FD "kernel /boot/linux.vmx\n";
                    print $FD "append initrd=/boot/initrd.vmx ";
                    print $FD "vga=$vga";
                } else {
                    print $FD "kernel /boot/linux\n";
                    print $FD "append initrd=/boot/initrd ";
                    print $FD "vga=$vga";
                }
                print $FD " @failsafe";
                print $FD $cmdline;
            } else {
                chomp $cmdline;
                if ($iso) {
                    print $FD "kernel mboot.c32\n";
                    print $FD "append xen.gz --- linux ";
                    print $FD "vga=$vga ";
                    print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                    print $FD "cdinst=1 kiwi_hybrid=1 @failsafe${cmdline} ";
                    print $FD "--- initrd showopts"."\n";
                } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                    print $FD "kernel mboot.c32\n";
                    print $FD "append boot/xen.gz --- boot/linux.vmx ";
                    print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                    print $FD "vga=$vga @failsafe${cmdline} ";
                    print $FD "--- boot/initrd.vmx showopts"."\n";
                } else {
                    print $FD "kernel mboot.c32\n";
                    print $FD "append boot/xen.gz --- boot/linux ";
                    print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
                    print $FD "vga=$vga @failsafe${cmdline} ";
                    print $FD "--- boot/initrd showopts"."\n";
                }
            }
        }
        $FD -> close();
        #==========================================
        # setup isolinux.msg file
        #------------------------------------------
        my $isofd = FileHandle -> new();
        if (! $isofd -> open (">$tmpdir/boot/syslinux/isolinux.msg")) {
            $kiwi -> failed();
            $kiwi -> error  ("Failed to create isolinux.msg: $!");
            $kiwi -> failed ();
            return;
        }
        print $isofd "\n"."Welcome !"."\n\n";
        foreach my $label (@labels) {
            print $isofd "$label"."\n";
        }
        print $isofd "\n\n";
        print $isofd "Have a lot of fun..."."\n";
        $isofd -> close();
        $kiwi -> done();
    }
    #==========================================
    # Zipl
    #------------------------------------------
    if ($loader eq "zipl") {
        #==========================================
        # Create zipl.conf
        #------------------------------------------
        KIWIQX::qxx ("mkdir -p $tmpdir/boot/zipl");
        $cmdline =~ s/\n//g;
        my $ziplconfig = "zipl.conf";
        $kiwi -> info ("Creating $ziplconfig config file...");
        if ($isxen) {
            $kiwi -> failed ();
            $kiwi -> error  ("*** zipl: Xen boot not supported ***");
            $kiwi -> failed ();
            return;
        }
        if (! -e "/boot/zipl") {
            $kiwi -> failed ();
            $kiwi -> error  ("Can't find bootloader: /boot/zipl");
            $kiwi -> failed ();
            return;
        }
        my $FD = FileHandle -> new();
        if (! $FD -> open (">$tmpdir/boot/$ziplconfig")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create $ziplconfig: $!");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # General zipl setup
        #------------------------------------------
        # Note:
        # The initrd will be loaded at offset address 0x4000000 (64MB)
        # This means the kernel must not be bigger than 64MB otherwise it
        # will overwrite the initrd. The reason for the static address
        # is for compatibility with zipl and kernel versions which were
        # not able to handle the initrd at variing adresses e.g sle11
        # ----
        my $title_standard;
        my $title_failsafe;
        my $bootTimeout = 200;
        if (defined $type->{boottimeout}) {
            $bootTimeout = $type->{boottimeout};
        }
        if ($topic =~ /^KIWI (CD|USB)/) {
            $title_standard = $this -> makeLabel (
                "Install $label"
            );
            $title_failsafe = $this -> makeLabel (
                "Failsafe -- Install $label"
            );
        } else {
            $title_standard = $this -> makeLabel (
                "$label ( $topic )"
            );
            $title_failsafe = $this -> makeLabel (
                "Failsafe -- $label ( $topic )"
            );
        }
        print $FD "[defaultboot]"."\n";
        print $FD "defaultmenu = menu"."\n\n";
        print $FD ":menu"."\n";
        print $FD "\t"."default = 1"."\n";
        print $FD "\t"."prompt  = 1"."\n";
        print $FD "\t"."target  = boot/zipl"."\n";
        print $FD "\t"."timeout = $bootTimeout"."\n";
        print $FD "\t"."1 = $title_standard"."\n";
        print $FD "\t"."2 = $title_failsafe"."\n\n";
        #==========================================
        # Standard boot
        #------------------------------------------
        print $FD "[$title_standard]"."\n";
        if ($iso) {
            $kiwi -> failed ();
            $kiwi -> error  ("*** zipl: CD boot not supported ***");
            $kiwi -> failed ();
            return;
        } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
            print $FD "\t"."image   = boot/linux.vmx"."\n";
            print $FD "\t"."target  = boot/zipl"."\n";
            print $FD "\t"."ramdisk = boot/initrd.vmx,0x4000000"."\n";
        } else {
            print $FD "\t"."image   = boot/linux"."\n";
            print $FD "\t"."target  = boot/zipl"."\n";
            print $FD "\t"."ramdisk = boot/initrd,0x4000000"."\n";
        }
        print $FD "\t"."parameters = \"$cmdline\""."\n";
        #==========================================
        # Failsafe boot
        #------------------------------------------
        if ($failsafe) {
            print $FD "[$title_failsafe]"."\n";
            if ($iso) {
                $kiwi -> failed ();
                $kiwi -> error  ("*** zipl: CD boot not supported ***");
                $kiwi -> failed ();
                return;
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "\t"."image   = boot/linux.vmx"."\n";
                print $FD "\t"."target  = boot/zipl"."\n";
                print $FD "\t"."ramdisk = boot/initrd.vmx,0x4000000"."\n";
            } else {
                print $FD "\t"."image   = boot/linux"."\n";
                print $FD "\t"."target  = boot/zipl"."\n";
                print $FD "\t"."ramdisk = boot/initrd,0x4000000"."\n";
            }
            print $FD "\t"."parameters = \"x11failsafe";
            print $FD " $cmdline\""."\n";
        }
        $FD -> close();
        $kiwi -> done();
    }
    #==========================================
    # yaboot
    #------------------------------------------
    if ($loader eq "yaboot") {
        #==========================================
        # Create yaboot.cnf
        #------------------------------------------
        $kiwi -> info ("Creating lilo/yaboot config file...");
        $cmdline =~ s/\n//g;
        my $bootTimeout = 80;
        if (defined $type->{boottimeout}) {
            $bootTimeout = $type->{boottimeout};
        }
        #==========================================
        # Standard boot
        #------------------------------------------
        my $FD = FileHandle -> new();
        if (! $FD -> open (">$tmpdir/boot/yaboot.cnf")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create yaboot.cnf: $!");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # General yaboot setup
        #------------------------------------------
        if ($topic =~ /^KIWI (CD|USB)/) {
            $title = $this -> makeLabel ("Install $label");
        } else {
            $title = $this -> makeLabel ("$label [ $topic ]");
        }
        print $FD "default = $title\n";
        print $FD "timeout = $bootTimeout\n";
        #==========================================
        # Standard boot
        #------------------------------------------
        if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
            if ($iso) {
                print $FD "\t"."label = $title\n";
                print $FD "\t"."image  = /boot/linux\n";
                print $FD "\t"."initrd = /boot/initrd\n";
                print $FD "\t"."append = \"$cmdline cdinst=1\"";
                print $FD "\n";
            } elsif (($topic=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
                print $FD "\t"."label = $title\n";
                print $FD "\t"."image  = /boot/linux.vmx"."\n";
                print $FD "\t"."initrd = /boot/initrd.vmx\n";
                print $FD "\t"."append = \"$cmdline\"\n";
            } else {
                print $FD "\t"."label = $title\n";
                print $FD "\t"."image  = /boot/linux"."\n";
                print $FD "\t"."initrd = /boot/initrd\n";
                print $FD "\t"."append = \"$cmdline\"\n";
            }
        } else {
            $kiwi -> failed ();
            $kiwi -> error  ("*** not implemented ***");
            $kiwi -> failed ();
            return;
        }
        $FD -> close();
        $kiwi -> done();
        #==========================================
        # Create bootinfo.txt
        #------------------------------------------
        my $binfofd = FileHandle -> new();
        if (! $binfofd -> open (">$tmpdir/boot/bootinfo.txt")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create bootinfo.txt: $!");
            $kiwi -> failed ();
            return;
        }
        print $binfofd "<chrp-boot>\n";
        print $binfofd "<description>$title</description>\n";
        print $binfofd "<os-name>$title</os-name>\n";
        print $binfofd "<boot-script>boot &device;:1,yaboot</boot-script>\n";
        print $binfofd "</chrp-boot>\n";
        $binfofd -> close();
        $kiwi -> done ();
    }
    #==========================================
    # uboot / berryboot
    #------------------------------------------
    if (($loader eq "uboot") || ($loader eq "berryboot")) {
        #==========================================
        # Create uboot image file from initrd
        #------------------------------------------
        $kiwi -> info ("Creating uBoot initrd image...");
        $cmdline =~ s/\n//g;
        my $mkopts = "-A arm -O linux -T ramdisk -C none -a 0x0 -e 0x0";
        my $inputf = "$tmpdir/boot/initrd.vmx";
        my $result = "$tmpdir/boot/initrd.uboot";
        my $data = KIWIQX::qxx (
            "mkimage $mkopts -n 'Initrd' -d $inputf $result"
        );
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to create uboot initrd image: $data");
            $kiwi -> failed ();
            return;
        }
        KIWIQX::qxx ("rm -f $inputf 2>&1");
        $kiwi -> done();
        #==========================================
        # Create boot.script
        #------------------------------------------
        $kiwi -> info ("Creating boot.script uboot config file...");
        #==========================================
        # Standard boot
        #------------------------------------------
        # this is only the generic part of the boot script. The
        # custom parts needs to be added via the editbootconfig
        # script hook
        # ----
        my $FD = FileHandle -> new();
        if (! $FD -> open (">$tmpdir/boot/boot.script")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create boot.script: $!");
            $kiwi -> failed ();
            return;
        }
        print $FD 'setenv ramdisk boot/initrd.uboot'."\n";
        print $FD 'setenv kernel boot/linux.vmx'."\n";
        print $FD 'setenv initrd_high "0xffffffff"'."\n";
        print $FD 'setenv fdt_high "0xffffffff"'."\n";
        if ($iso) {
            $kiwi -> failed ();
            $kiwi -> error  ("*** uboot: CD boot not supported ***");
            $kiwi -> failed ();
            return;
        } else {
            print $FD "setenv bootargs \"$cmdline \${append}\"\n";
        }
        $FD -> close();
        $kiwi -> done();
    }
    #==========================================
    # berryboot
    #------------------------------------------
    if ($loader eq "berryboot") {
        #==========================================
        # Create config.txt
        #------------------------------------------
        $kiwi -> info ("Creating config.txt chainloading uboot...");
        #==========================================
        # Standard boot
        #------------------------------------------
        # this is only the generic part of the config.txt. The
        # custom parts needs to be added via the editbootconfig
        # script hook
        # ----
        my $FD = FileHandle -> new();
        if (! $FD -> open (">$tmpdir/boot/config.txt")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create config.txt: $!");
            $kiwi -> failed ();
            return;
        }
        print $FD 'kernel=u-boot.bin'."\n";
        $FD -> close();
        $kiwi -> done();
    }
    #==========================================
    # more boot managers to come...
    #------------------------------------------
    #==========================================
    # Check for edit boot config
    #------------------------------------------
    if ($cmdL) {
        my $editBoot = $cmdL -> getEditBootConfig();
        my $idesc;
        if ((! $editBoot) && ($xml)) {
            $editBoot = $xml -> getImageType() -> getEditBootConfig();
        }
        if ($editBoot) {
            if (($this->{originXMLPath}) &&
                (!File::Spec->file_name_is_absolute($editBoot))
            ) {
                $editBoot = $this->{originXMLPath}."/".$editBoot;
            }
            if (-f $editBoot) {
                $kiwi -> info ("Calling pre bootloader install script:\n");
                $kiwi -> info ("--> $editBoot\n");
                my @opts = ();
                if ($type->{bootfilesystem}) {
                    push @opts,$type->{bootfilesystem};
                }
                if ($this->{partids}) {
                    push @opts,$this->{partids}{boot};
                }
                system ("cd $tmpdir && bash --norc $editBoot @opts");
                my $result = $? >> 8;
                if ($result != 0) {
                    $kiwi -> error ("Call failed, see console log");
                    $kiwi -> failed ();
                    return;
                }
            } else {
                $kiwi -> warning (
                    "Can't find pre bootloader install script: $editBoot..."
                );
                $kiwi -> skipped ();
            }
        }
    }
    return $this;
}

#==========================================
# copyBootCode
#------------------------------------------
sub copyBootCode {
    my $this     = shift;
    my $source   = shift;
    my $dest     = shift;
    my $loader   = shift;
    my $kiwi     = $this->{kiwi};
    my $firmware = $this->{firmware};
    my $status   = KIWIQX::qxx ("cp -dR $source/boot $dest 2>&1");
    my $result   = $? >> 8;
    if ($result != 0) {
        $kiwi -> oops ();
        $kiwi -> warning ("Copy of boot data returned: $status");
    }
    #==========================================
    # EFI
    #------------------------------------------
    if ($this->{needJumpP}) {
        if (($firmware eq "efi") || ($firmware eq "uefi")) {
            $status = KIWIQX::qxx ("cp -a $source/EFI $dest 2>&1");
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error (
                    "Couldn't copy EFI loader to final path: $status"
                );
                $kiwi -> failed ();
                return;
            }
        }
    }
    #==========================================
    # return early if no boot partition
    #------------------------------------------
    if (! $this->{needBootP}) {
        return $this;
    }
    #==========================================
    # Uboot / BerryBoot
    #------------------------------------------
    if (($loader eq "uboot") || ($loader eq "berryboot")) {
        my $target = $dest;
        KIWIQX::qxx ("mv $dest/boot/boot.scr $target &>/dev/null");
        KIWIQX::qxx ("mv $dest/boot/*.dtb $target &>/dev/null");
        KIWIQX::qxx ("mv $dest/boot/dtb/  $target &>/dev/null");
        if (-f "$dest/boot/MLO") {
            $status = KIWIQX::qxx ("mv $dest/boot/MLO $target");
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error (
                    "Couldn't move $loader/MLO loaders to final path: $status"
                );
                $kiwi -> failed ();
                return;
            }
        }
        if ($firmware eq 'vboot') {
            # if vboot firmware is used we copy all first stage
            # loader files to the jump partition
            $target .= '/vboot';
        }
        if ($loader eq "berryboot") {
            KIWIQX::qxx ("mv $dest/boot/config.txt $target &>/dev/null");
        }
        KIWIQX::qxx ("mv $dest/boot/*.bin $target &>/dev/null");
        KIWIQX::qxx ("mv $dest/boot/*.dat $target &>/dev/null");
        KIWIQX::qxx ("mv $dest/boot/*.img $target &>/dev/null");
        KIWIQX::qxx ("mv $dest/boot/*.imx $target &>/dev/null");
        KIWIQX::qxx ("mv $dest/boot/*.elf $target &>/dev/null");
    }
    #==========================================
    # YaBoot
    #------------------------------------------
    if ($loader eq "yaboot") {
        $status = KIWIQX::qxx ("mv $dest/boot/bootinfo.txt $dest");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error ("Couldn't move bootinfo.txt: $status");
            $kiwi -> failed ();
            return;
        }
        $status = KIWIQX::qxx ("mv $dest/boot/yaboot.cnf $dest");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error ("Couldn't move yaboot config: $status");
            $kiwi -> failed ();
            return;
        }
        $status = KIWIQX::qxx ("mv $dest/boot/yaboot $dest");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error ("Couldn't move yaboot loader: $status");
            $kiwi -> failed ();
            return;
        }
    }
    return $this;
}

#==========================================
# installBootLoader
#------------------------------------------
sub installBootLoader {
    my $this     = shift;
    my $loader   = shift;
    my $diskname = shift;
    my $deviceMap= shift;
    my $kiwi     = $this->{kiwi};
    my $tmpdir   = $this->{tmpdir};
    my $chainload= $this->{chainload};
    my $cmdL     = $this->{cmdL};
    my $xml      = $this->{xml};
    my $firmware = $this->{firmware};
    my $system   = $this->{system};
    my $haveTree = $this->{haveTree};
    my $mount    = $this->{bootmountpoint};
    my $locator  = KIWILocator -> instance();
    my $bootdev;
    my $result;
    my $status;
    my $grubtool;
    my $grubtoolopts;
    my $grubarch;
    #==========================================
    # Setup boot device name
    #------------------------------------------
    if ($deviceMap->{boot}) {
        $bootdev = $deviceMap->{boot};
    } else {
        $bootdev = $deviceMap->{root};
    }
    #==========================================
    # Grub2
    #------------------------------------------
    if ($loader eq "grub2") {
        #==========================================
        # Create device map for the disk
        #------------------------------------------
        $kiwi -> info ("Creating grub2 device map");
        my $dmfile = "$tmpdir/boot/grub2/device.map";
        my $dmfd = FileHandle -> new();
        if (! $dmfd -> open(">$dmfile")) {
            $kiwi -> failed ();
            return;
        }
        print $dmfd "(hd0) $diskname\n";
        $dmfd -> close();
        $kiwi -> done();

        #==========================================
        # Check for loader
        #------------------------------------------
        $grubtool = $locator -> getExecPath ('grub2-bios-setup');
        $grubarch = "i386-pc";
        my $grubimg  = "core.img";
        if ($firmware eq 'ofw') {
            $grubimg  = "core.elf";
            $grubtool = $locator -> getExecPath ('grub2-install');
            $grubarch = "powerpc-ieee1275";
        }
        #==========================================
        # Mount boot partition
        #------------------------------------------
        if (! KIWIGlobals -> instance() -> mount (
            $bootdev, $mount, undef, $xml
        )) {
            $kiwi -> error ("Couldn't mount boot partition: $bootdev");
            $kiwi -> failed ();
            return;
        }
        my $stages = $mount."/boot/grub2/$grubarch";
        if (($firmware =~ /ec2|bios|ofw/) && (! -e "$stages/$grubimg")) {
            $kiwi -> error  ("Mandatory grub2 modules not found");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # Copy grub2 core modules to tmpdir
        #------------------------------------------
        if (-e "$stages/$grubimg") {
            $status = KIWIQX::qxx (
                "cp -a $stages $tmpdir/boot/grub2/ 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  (
                    "Couldn't copy grub2 modules: $status"
                );
                $kiwi -> failed ();
                $this -> cleanStack ();
                return;
            }
            $stages = "$tmpdir/boot/grub2/$grubarch";
        }
        #==========================================
        # Install grub2
        #------------------------------------------
        my $loaderTarget;
        my $targetMessage;
        if (-e "$stages/core.img") {
            # architectures: ix86, x86_64 and arm
            if ($chainload) {
                $loaderTarget = readlink ($bootdev);
                $loaderTarget =~ s/\.\./\/dev/;
                $grubtoolopts = "-f -d $stages -m $dmfile";
                $targetMessage= "On partition target";
            } else {
                $loaderTarget = $diskname;
                $grubtoolopts = "-f -d $stages -m $dmfile";
                $targetMessage= "On disk target";
            }
        } elsif (-e "$stages/core.elf") {
            # architectures: ppc64le
            $loaderTarget = $deviceMap->{prep};
            $grubtoolopts = "--grub-mkdevicemap=$dmfile -v ";
            $grubtoolopts.= "-d $mount/usr/lib/grub2/$grubarch ";
            $grubtoolopts.= "--root-directory=$mount --force --no-nvram ";
            $targetMessage= "On PReP partition";
        } else {
            if (! -e "$stages/core.img") {
                $kiwi -> warning (
                    "grub2-bios modules not found, legacy boot disabled"
                );
                $kiwi -> skipped();
            } elsif (! -e "$stages/core.elf") {
                $kiwi -> error (
                    "grub2 ppc core.elf module not found"
                );
                $kiwi -> failed();
                return;
            }
        }
        if ($loaderTarget) {
            if (! $grubtool) {
                $kiwi -> error  ("Mandatory $grubtool not found");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> info ("Installing grub2:\n");
            $kiwi -> info ("--> $targetMessage: $loaderTarget\n");
            $status = KIWIQX::qxx (
                "$grubtool $grubtoolopts $loaderTarget 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> error  (
                    "Couldn't install $loader on $loaderTarget: $status"
                );
                $kiwi -> failed ();
                return;
            }
        }
        #==========================================
        # Clean loop maps
        #------------------------------------------
        $this -> cleanStack ();
        #==========================================
        # Check for chainloading
        #------------------------------------------
        if ($chainload) {
            # /.../
            # chainload grub with master-boot-code
            # zero out sectors between 0x200 - 0x3f0 for preload
            # process store a copy of the master-boot-code at 0x800
            # write FDST flag at 0x190
            # ---
            my $mbr = "/usr/lib/boot/master-boot-code";
            my $opt = "conv=notrunc";
            my $fdst;
            #==========================================
            # write master-boot-code
            #------------------------------------------
            $status = KIWIQX::qxx (
                "dd if=$mbr of=$diskname bs=1 count=446 $opt 2>&1"
            );
            $result= $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  (
                    "Couldn't install master boot code: $status"
                );
                $kiwi -> failed ();
                return;
            }
            #==========================================
            # write FDST flag
            #------------------------------------------
            $fdst = "perl -e \"printf '%s', pack 'A4', eval 'FDST';\"";
            KIWIQX::qxx (
                "$fdst| \\
                dd of=$diskname bs=1 count=4 seek=\$((0x190)) $opt 2>&1"
            );
        }
    }
    #==========================================
    # Grub
    #------------------------------------------
    if ($loader eq "grub") {
        $kiwi -> info ("Installing grub on device: $diskname");
        #==========================================
        # re-init bootid, legacy grub starts at 0
        #------------------------------------------
        my $boot_id = 0;
        if ($this->{partids}) {
            if ($this->{partids}{boot}) {
                $boot_id = $this->{partids}{boot} - 1;
            } elsif ($this->{partids}{root}) {
                $boot_id = $this->{partids}{root} - 1;
            }
        }
        #==========================================
        # Clean loop maps
        #------------------------------------------
        $this -> cleanStack();
        #==========================================
        # Create device map for the disk
        #------------------------------------------
        my $dmfile = "$tmpdir/grub-device.map";
        my $dmfd = FileHandle -> new();
        if (! $dmfd -> open(">$dmfile")) {
            $kiwi -> failed ();
            $kiwi -> error ("Couldn't create grub device map: $!");
            $kiwi -> failed ();
            return;
        }
        print $dmfd "(hd0) $diskname\n";
        $dmfd -> close();
        #==========================================
        # Create command list to install grub
        #------------------------------------------
        my $cmdfile = "$tmpdir/grub-device.cmds";
        if (! $dmfd -> open(">$cmdfile")) {
            $kiwi -> failed ();
            $kiwi -> error ("Couldn't create grub command list: $!");
            $kiwi -> failed ();
            return;
        }
        print $dmfd "device (hd0) $diskname\n";
        print $dmfd "root (hd0,$boot_id)\n";
        if ($chainload) {
            print $dmfd "setup (hd0,$boot_id)\n";
        } else {
            print $dmfd "setup (hd0)\n";
        }
        print $dmfd "quit\n";
        $dmfd -> close();
        #==========================================
        # Install grub in batch mode
        #------------------------------------------
        my $grub;
        my $image_grub;
        if ($haveTree) {
            # Try to use image root system grub
            $grub = $locator -> getExecPath ('grub', $system);
        }
        if (! $grub) {
            # Use host system grub if not found in system tree
            $grub = $locator -> getExecPath ('grub');
        } else {
            # Found grub in image, use it
            $image_grub = 1;
        }
        if (! $grub) {
            $kiwi -> failed ();
            if ($haveTree) {
                $kiwi -> error (
                    "Can't locate grub binary in image root"
                );
            } else {
                $kiwi -> error (
                    "Can't locate grub binary"
                );
            }
            $kiwi -> failed ();
            return;
        }
        my $gopts = "--device-map $dmfile --no-floppy --batch";
        if ($image_grub) {
            # Use image root system grub
            my $basedir_disk = dirname ($diskname);
            my $basedir_tmp  = $tmpdir;
            $status = KIWIQX::qxx (
                "mkdir -p $system/$basedir_disk $system/$basedir_tmp 2>&1"
            );
            $result= $? >> 8;
            if ($result == 0) {
                $status = KIWIQX::qxx (
                    "mount -n --bind $basedir_disk $system/$basedir_disk"
                );
                $result= $? >> 8;
            }
            if ($result == 0) {
                $status = KIWIQX::qxx (
                    "mount -n --bind $basedir_tmp $system/$basedir_tmp"
                );
                $result= $? >> 8;
            }
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error ("grub chroot setup failed: $status");
                $kiwi -> failed ();
                return;
            }
            KIWIQX::qxx (
                "chroot $system $grub $gopts < $cmdfile &> $tmpdir/grub.log"
            );
            KIWIQX::qxx ("umount $system/$basedir_tmp 2>&1");
            KIWIQX::qxx ("umount $system/$basedir_disk 2>&1");
            my $rmopts = "-p --ignore-fail-on-non-empty";
            KIWIQX::qxx (
                "rmdir $rmopts $system/$basedir_disk $system/$basedir_tmp"
            );
        } else {
            # Use host system grub
            if (-d "/boot/grub") {
                KIWIQX::qxx ("mount -n --bind $tmpdir/boot/grub /boot/grub");
            }
            KIWIQX::qxx ("$grub $gopts < $cmdfile &> $tmpdir/grub.log");
            KIWIQX::qxx ("umount /boot/grub &>/dev/null");
        }
        my $glog;
        if ($dmfd -> open ("$tmpdir/grub.log")) {
            my @glog = <$dmfd>; $dmfd -> close();
            if ($dmfd -> open ($cmdfile)) {
                my @cmdlog = <$dmfd>; $dmfd -> close();
                push @glog,"GRUB: commands:";
                push @glog,@cmdlog;
            }
            $result = grep { /^\s*Running.*succeeded$/ } @glog;
            if (($result) && (! $chainload)) {
                $result = grep { /^\s*Running.*are embedded\.$/ } @glog;
            }
            if ($result) {
                # found stage information, set good result exit code
                $result = 0;
            }
            $glog = join ("\n",@glog);
            $kiwi -> loginfo ("GRUB: $glog\n");
        }
        if ($result == 0) {
            my $boot = "'boot sector'";
            my $null = "/dev/null";
            $status= KIWIQX::qxx (
                "dd if=$diskname bs=4k count=1 2>$null|file - | grep -q $boot"
            );
            $result= $? >> 8;
        }
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't install grub on $diskname: $glog");
            $kiwi -> failed ();
            return;
        }
        if ($chainload) {
            # /.../
            # chainload grub with master-boot-code
            # zero out sectors between 0x200 - 0x3f0 for preload process
            # store a copy of the master-boot-code at 0x800
            # write FDST flag at 0x190
            # ---
            my $mbr = "/usr/lib/boot/master-boot-code";
            my $opt = "conv=notrunc";
            #==========================================
            # write master-boot-code
            #------------------------------------------
            $status = KIWIQX::qxx (
                "dd if=$mbr of=$diskname bs=1 count=446 $opt 2>&1"
            );
            $result= $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't install master boot code: $status");
                $kiwi -> failed ();
                return;
            }
            #==========================================
            # write FDST flag
            #------------------------------------------
            my $fdst = "perl -e \"printf '%s', pack 'A4', eval 'FDST';\"";
            KIWIQX::qxx (
                "$fdst|dd of=$diskname bs=1 count=4 seek=\$((0x190)) $opt 2>&1"
            );
        }
        $kiwi -> done();
    }
    #==========================================
    # syslinux
    #------------------------------------------
    if ($loader =~ /(sys|ext)linux/) {
        #==========================================
        # Install sys/extlinux on boot device
        #------------------------------------------
        if ($loader eq "syslinux") {
            $kiwi -> info ("Installing syslinux on device: $bootdev");
            $status = KIWIQX::qxx ("syslinux $bootdev 2>&1");
            $result = $? >> 8;
        } else {
            $kiwi -> info ("Installing extlinux on device: $bootdev");
            if (KIWIGlobals -> instance() -> mount (
                $bootdev, $mount, undef, $xml
            )) {
                $status = KIWIQX::qxx (
                    "extlinux --install $mount/boot/syslinux 2>&1"
                );
                $result = $? >> 8;
            }
            $status = KIWIQX::qxx ("umount $mount 2>&1");
        }
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't install $loader on $bootdev: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        #==========================================
        # Clean loop maps
        #------------------------------------------
        $this -> cleanStack();
        #==========================================
        # Write syslinux master boot record
        #------------------------------------------
        my $syslmbr = "/usr/share/syslinux/mbr.bin";
        $status = KIWIQX::qxx (
            "dd if=$syslmbr of=$diskname bs=512 count=1 conv=notrunc 2>&1"
        );
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't install syslinux MBR on $diskname");
            $kiwi -> failed ();
            return;
        }
        $kiwi -> done();
    }
    #==========================================
    # Zipl
    #------------------------------------------
    if ($loader eq "zipl") {
        $kiwi -> info ("Installing zipl on device: $diskname\n");
        my $haveRealDevice = 1;
        my $offset;
        if (! -b $diskname) {
            #==========================================
            # detect disk offset of disk image file
            #------------------------------------------
            $offset = $this -> diskOffset ($diskname);
            if (! $offset) {
                $kiwi -> error  ("Failed to detect disk offset");
                $kiwi -> failed ();
                return;
            }
            $haveRealDevice = 0;
        }
        #==========================================
        # mount boot device...
        #------------------------------------------
        if (! KIWIGlobals -> instance() -> mount (
            $bootdev, $mount, undef, $xml
        )) {
            $kiwi -> error  ("Can't mount boot partition: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        my $config = "$mount/boot/zipl.conf";
        if (! $haveRealDevice) {
            #==========================================
            # set target type
            #------------------------------------------
            my $bsize = $xml -> getImageType() -> getTargetBlockSize();
            if (! $bsize) {
                $bsize = KIWIGlobals -> instance() -> getKiwiConfigEntry(
                    'DiskSectorSize'
                );
            }
            my $chs = $this -> diskCHS($diskname);
            my $type = $xml -> getImageType() -> getZiplTargetType();
            if (! $type) {
                if ($bsize == 4096) {
                    # we assume the target is a 4k dasd device in LDL mode
                    # this could be wrong, there are also CDL dasd devices
                    $type = 'LDL';
                } else {
                    # we assume the target is a 512b scsi device in SCSI mode
                    # this could be wrong, thre are also emulated dasd devices
                    # using 512b blocksize in FBA mode
                    $type = 'SCSI';
                }
            }
            #==========================================
            # setup zipl caller options in zipl.conf
            #------------------------------------------
            my $readzconf = FileHandle -> new();
            if (! $readzconf -> open ($config)) {
                $kiwi -> error  ("Can't open config file for reading: $!");
                $kiwi -> failed ();
                KIWIQX::qxx ("umount $mount 2>&1");
                $this -> cleanStack ();
                return;
            }
            my @data = <$readzconf>;
            $readzconf -> close();
            my $zconffd = FileHandle -> new();
            if (! $zconffd -> open (">$config")) {
                $kiwi -> error  ("Can't open config file for writing: $!");
                $kiwi -> failed ();
                KIWIQX::qxx ("umount $mount 2>&1");
                $this -> cleanStack ();
                return;
            }
            foreach my $line (@data) {
                print $zconffd $line;
                if ($line =~ /^:menu/) {
                    $kiwi -> info ("--> targetbase = $this->{loop}\n");
                    $kiwi -> info ("--> targettype = $type\n");
                    $kiwi -> info ("--> targetblocksize = $bsize\n");
                    $kiwi -> info ("--> targetoffset = $offset\n");
                    print $zconffd "\t"."targetbase = $this->{loop}"."\n";
                    print $zconffd "\t"."targettype = $type"."\n";
                    print $zconffd "\t"."targetblocksize = $bsize"."\n";
                    print $zconffd "\t"."targetoffset = $offset"."\n";
                    if ($type =~ /CDL|LDL/) {
                        $kiwi -> info ("--> targetgeometry = $chs\n");
                        print $zconffd "\t"."targetgeometry = $chs"."\n";
                    }
               }
            }
            $zconffd -> close();
        }
        #==========================================
        # call zipl...
        #------------------------------------------
        $status = KIWIQX::qxx (
            "cd $mount && zipl -V -c $config -m menu 2>&1"
        );
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> error  ("Couldn't install zipl on $diskname: $status");
            $kiwi -> failed ();
            KIWIQX::qxx ("umount $mount 2>&1");
            $this -> cleanStack ();
            return;
        }
        $kiwi -> loginfo($status);
        KIWIQX::qxx ("umount $mount 2>&1");
        #==========================================
        # clean loop maps
        #------------------------------------------
        $this -> cleanStack ();
    }
    #==========================================
    # install yaboot/lilo
    #------------------------------------------
    if ($loader eq "yaboot") {
        # presence of yaboot binary in the boot partition is already done
    }
    #==========================================
    # install uboot
    #------------------------------------------
    if ($loader eq "uboot") {
        # There is no generic way to do this, use editbootinstall script hook
    }
    #==========================================
    # install berryboot
    #------------------------------------------
    if ($loader eq "berryboot") {
        # There is no generic way to do this, use editbootinstall script hook
    }
    #==========================================
    # more boot managers to come...
    #------------------------------------------
    #==========================================
    # Check for edit boot install
    #------------------------------------------
    if ($cmdL) {
        my $editBoot = $cmdL -> getEditBootInstall();
        my $idesc;
        if ((! $editBoot) && ($xml)) {
            $editBoot = $xml -> getImageType() -> getEditBootInstall();
        }
        if ($editBoot) {
            if (($this->{originXMLPath}) &&
                (!File::Spec->file_name_is_absolute($editBoot))
            ) {
                $editBoot = $this->{originXMLPath}."/".$editBoot;
            }
            if (-f $editBoot) {
                $kiwi -> info ("Calling post bootloader install script:\n");
                $kiwi -> info ("--> $editBoot\n");
                my @opts = ($diskname,$bootdev);
                system ("cd $tmpdir && bash --norc $editBoot @opts");
                my $result = $? >> 8;
                if ($result != 0) {
                    $kiwi -> error ("Call failed, see console log");
                    $kiwi -> failed ();
                    return;
                }
            } else {
                $kiwi -> warning (
                    "Can't find post bootloader install script: $editBoot..."
                );
                $kiwi -> skipped ();
            }
        }
    }
    #==========================================
    # clean loop maps
    #------------------------------------------
    $this -> cleanStack ();
    #==========================================
    # Write custom disk label ID to MBR
    #------------------------------------------
    if ($firmware ne "ofw") {
        $kiwi -> info ("Saving disk label in MBR: $this->{mbrid}...");
        if (! $this -> writeMBRDiskLabel ($diskname)) {
            return;
        }
        $kiwi -> done();
    }
    return $this;
}

#==========================================
# bindDiskDevice
#------------------------------------------
sub bindDiskDevice {
    my $this   = shift;
    my $system = shift;
    my $kiwi   = $this->{kiwi};
    my @cStack = @{$this->{cleanupStack}};
    my $global = KIWIGlobals -> instance();
    my $status;
    my $result;
    #==========================================
    # bind file to loop device
    #------------------------------------------
    my $loop = $global -> loop_setup($system, $this->{xml});
    $this->{loop} = $loop;
    push @cStack, $global -> loop_delete_command($loop);
    $this->{cleanupStack} = \@cStack;
    return $this;
}

#==========================================
# bindDiskPartitions
#------------------------------------------
sub bindDiskPartitions {
    # ...
    # make sure we can access the partitions of the
    # loop mounted disk file
    # ---
    my $this   = shift;
    my $disk   = shift;
    my $kiwi   = $this->{kiwi};
    my @cStack = @{$this->{cleanupStack}};
    my $status;
    my $result;
    my $part;
    $status = KIWIQX::qxx ("/sbin/kpartx -sa $disk 2>&1");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> loginfo ("Failed mapping partition: $status");
        return;
    }
    # wait for the mapping devices to finish
    KIWIQX::qxx ("udevadm settle --timeout=30 2>&1");
    push @cStack,"kpartx -sd $disk";
    $this->{cleanupStack} = \@cStack;
    $disk =~ s/dev\///;
    $part = "/dev/mapper".$disk."p";
    return $this;
}

#==========================================
# getGeometry
#------------------------------------------
sub getGeometry {
    # ...
    # Create a new disk label on the given device and
    # obtain the number of sectors from this disk
    # ---
    my $this     = shift;
    my $disk     = shift;
    my $kiwi     = $this->{kiwi};
    my $cmdL     = $this->{cmdL};
    my $loader   = $this->{bootloader};
    my $firmware = $this->{firmware};
    my $xml      = $this->{xml};
    my $secsz    = $cmdL -> getDiskBIOSSectorSize();
    my $label    = 'msdos';
    my $status;
    my $result;
    my $parted;
    my $locator = KIWILocator -> instance();
    my $parted_exec = $locator -> getExecPath("parted");
    $status = KIWIQX::qxx ("dd if=/dev/zero of=$disk bs=4k count=1 2>&1");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> loginfo ($status);
        return;
    }
    if (($firmware eq "efi")  ||
        ($firmware eq "uefi") ||
        (($firmware eq "vboot") && ($loader ne "berryboot"))
    ) {
        $label = 'gpt';
    }
    $status = KIWIQX::qxx ("$parted_exec -s $disk mklabel $label 2>&1");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> loginfo ($status);
        return;
    }
    $parted = "$parted_exec -m $disk unit s print";
    $status = KIWIQX::qxx (
        "$parted | head -n 3 | tail -n 1 | cut -f2 -d:"
    );
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> loginfo ($status);
        return;
    }
    chomp $status;
    $status =~ s/s//;
    if ($label =~ /^gpt/) {
        $status -= 128;
    } else {
        $status --;
    }
    $this->{pDiskSectors} = $status;
    $kiwi -> loginfo (
        "Disk Sector count is: $this->{pDiskSectors}\n"
    );
    return $label;
}

#==========================================
# getSector
#------------------------------------------
sub getSector {
    # ...
    # turn the given size in MB to the number of
    # required sectors aligned to the value of
    # getDiskAlignment
    # ----
    my $this  = shift;
    my $size  = shift;
    my $cmdL  = $this->{cmdL};
    my $count = $this->{pDiskSectors};
    my $secsz = $cmdL->getDiskBIOSSectorSize;
    my $align = ($cmdL->getDiskAlignment * 1024) / $secsz;
    my $sectors;
    if ($size =~ /\+(.*)M$/) {
        # turn value into bytes
        $size = $1;
        $size*= 1048576;
    } else {
        # use entire rest space
        $size = $count * $secsz;
    }
    if ($size < $align) {
        $size = $align;
    }
    $size = sprintf ("%.0f",$size / $align);
    $size*= $align;
    $size+= $align;
    $sectors = sprintf ("%.0f",$size / $secsz);
    $sectors-= 1;
    return $sectors;
}

#==========================================
# resetGeometry
#------------------------------------------
sub resetGeometry {
    # ...
    # reset global disk geometry information
    # ---
    my $this = shift;
    undef $this->{pDiskSectors};
    undef $this->{pStart};
    undef $this->{pStopp};
    return $this;
}

#==========================================
# initGeometry
#------------------------------------------
sub initGeometry {
    # ...
    # setup start sector and stop sector for the given size at
    # first invocation the start sector is set to the default
    # value from the global space or to the value specified on
    # the commandline. On any subsequent call the start sector is
    # calculated from the end sector of the previos partition
    # and the new value gets aligned to the value of getDiskAlignment
    # The function returns the number of sectors which represents
    # the given size
    # ---
    my $this   = shift;
    my $device = shift;
    my $size   = shift;
    my $kiwi   = $this->{kiwi};
    my $cmdL   = $this->{cmdL};
    my $secsz  = $cmdL->getDiskBIOSSectorSize;
    my $align  = ($cmdL->getDiskAlignment * 1024) / $secsz;
    my $locator= KIWILocator -> instance();
    if (! defined $this->{pStart}) {
        $this->{pStart} = $cmdL->getDiskStartSector();
    } else {
        sleep (1);
        my $parted_exec = $locator -> getExecPath("parted");
        my $parted = "$parted_exec -m $device unit s print";
        my $status = KIWIQX::qxx (
            "$parted | grep :$this->{pStart} | cut -f3 -d:"
        );
        chomp $status;
        $status=~ s/s//;
        if ($status >= $align) {
            $status = sprintf ("%.0f",$status / $align);
            $status*= $align;
            $status+= $align;
        }
        $this->{pStart} = $status;
    }
    my $sector = $this -> getSector ($size);
    $this->{pStopp} = $this->{pStart} + $sector;
    if ($this->{pStopp} > $this->{pDiskSectors}) {
        $this->{pStopp} = $this->{pDiskSectors}
    }
    return $sector;
}

#==========================================
# setStoragePartition
#------------------------------------------
sub setStoragePartition {
    # ...
    # creates the partition table on the given device
    # according to the command argument list
    # ---
    my $this     = shift;
    my $device   = shift;
    my $cmdref   = shift;
    my $tool     = $this->{ptool};
    my $kiwi     = $this->{kiwi};
    my $xml      = $this->{xml};
    my $tmpdir   = $this->{tmpdir};
    my @commands = @{$cmdref};
    my $result;
    my $status;
    my $ignore;
    my $action;
    if (! defined $tool) {
        $tool = $this->{gdata}->{Partitioner};
    }
    my $locator = KIWILocator -> instance();
    my $partitioner = $locator -> getExecPath($tool);
    if (! $partitioner) {
        $kiwi -> failed ();
        $kiwi -> error ("Can't find partitioner: $tool");
        return;
    }
    SWITCH: for ($tool) {
        #==========================================
        # fdasd
        #------------------------------------------
        /^fdasd/  && do {
            $kiwi -> loginfo (
                "FDASD input: $device [@commands]"
            );
            $status = KIWIQX::qxx (
                "dd if=/dev/zero of=$device bs=4k count=10 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> loginfo ($status);
                return;
            }
            my $FD = FileHandle -> new();
            if (! $FD-> open("|$partitioner -f $device &> $tmpdir/fdasd.log")) {
                return;
            }
            # confirm creating new vtoc table for empty disk
            print $FD "y\n";
            # confirm creating new label for empty disk
            print $FD "\n";
            foreach my $cmd (@commands) {
                if ($cmd =~ /[ntwq]$/) {
                    $action = $cmd;
                }
                if (($ignore) && ($cmd =~ /[ntwq]$/)) {
                    undef $ignore;
                } elsif ($ignore) {
                    next;
                }
                if ($cmd eq "a") {
                    $ignore=1;
                    next;
                }
                if ($cmd =~ /^p:/) {
                    next;
                }
                if (($cmd =~ /^[0-9]$/) && ($action ne "t")) {
                    next;
                }
                if (($cmd eq "83") || ($cmd eq "8e")) {
                    $cmd = 1;
                }
                if ($cmd eq "82") {
                    $cmd = 2;
                }
                if ($cmd eq ".") {
                    print $FD "\n";
                } else {
                    print $FD "$cmd\n";
                }
            }
            print $FD "w\n";
            $FD -> close();
            $result = $? >> 8;
            my $flog;
            my $flogfd = FileHandle -> new();
            if ($flogfd -> open ("$tmpdir/fdasd.log")) {
                my @flog = <$flogfd>;
                $flogfd -> close();
                $flog = join ("\n",@flog);
                $kiwi -> loginfo ("FDASD: $flog");
            }
            last SWITCH;
        };
        #==========================================
        # parted
        #------------------------------------------
        /^parted/  && do {
            my $p_cmd = ();
            $this -> resetGeometry();
            $this->{ptype} = $this -> getGeometry ($device);
            if (! $this->{ptype}) {
                return;
            }
            for (my $count=0;$count<@commands;$count++) {
                my $status;
                my $result = 0;
                my $cmd = $commands[$count];
                if ($cmd eq "n") {
                    my $name = $commands[$count+1];
                    my $size = $commands[$count+4];
                    if ($this->{ptype} ne 'gpt') {
                        $name = 'primary';
                    } else {
                        $name =~ s/^p://;
                    }
                    $this -> initGeometry ($device,$size);
                    $p_cmd = "mkpart $name $this->{pStart} $this->{pStopp}";
                    $kiwi -> loginfo ("PARTED input: $device [$p_cmd]\n");
                    $status = KIWIQX::qxx (
                        "$partitioner -s $device unit s $p_cmd 2>&1"
                    );
                }
                if (($cmd eq "t") && ($this->{ptype} eq 'msdos')) {
                    my $index= $commands[$count+1];
                    my $type = $commands[$count+2];
                    if ($type eq '82') {
                        # suse parted is not able to do this
                        # $p_cmd = "set $index swap on";
                        next;
                    } elsif ($type eq 'fd') {
                        $p_cmd = "set $index raid on";
                    } elsif ($type eq '8e') {
                        $p_cmd = "set $index lvm on";
                    } elsif ($type eq '41') {
                        $p_cmd = "set $index prep on";
                    } elsif ($type eq '83') {
                        # default partition type set by parted is linux(83)
                        next;
                    } else {
                        # be careful, this is a suse parted extension
                        $p_cmd = "set $index type 0x$type";
                    }
                    $kiwi -> loginfo ("PARTED input: $device [$p_cmd]\n");
                    $status = KIWIQX::qxx (
                        "$partitioner -s $device unit s $p_cmd 2>&1"
                    );
                }
                if ($cmd eq "a") {
                    my $index= $commands[$count+1];
                    $p_cmd = "set $index boot on";
                    $kiwi -> loginfo ("PARTED input: $device [$p_cmd]\n");
                    $status = KIWIQX::qxx (
                        "$partitioner -s $device unit s $p_cmd 2>&1"
                    );
                }
                $result = $? >> 8;
                if ($result != 0) {
                    $kiwi -> loginfo ($status);
                    return;
                }
            }
            if ($this->{arch} =~ /arm/) {
                # make sure there is no x86 boot code in MBR
                $status = KIWIQX::qxx (
                    "dd if=/dev/zero of=$device bs=440 count=1 2>&1"
                );
                $result = $? >> 8;
                if ($result != 0) {
                    $kiwi -> loginfo ($status);
                    return;
                }
            }
            last SWITCH;
        }
    }
    return $this;
}

#==========================================
# getStorageID
#------------------------------------------
sub getStorageID {
    # ...
    # return the partition id of the given
    # partition. If the call fails the function
    # returns 0
    # ---
    my $this   = shift;
    my $device = shift;
    my $partid = shift;
    my $status = KIWIQX::qxx ("sfdisk --id $device $partid 2>&1");
    my $result = $? >> 8;
    if ($result == 0) {
        chomp  $status;
        return $status;
    }
    return 0;
}

#==========================================
# getStorageSize
#------------------------------------------
sub getStorageSize {
    # ...
    # return the size of the given disk or disk
    # partition in Kb. If the call fails the function
    # returns 0
    # --- 
    my $this = shift;
    my $pdev = shift;
    if ((! $pdev) || (! -e $pdev)) {
        return -1;
    }
    my $status = KIWIQX::qxx ("blockdev --getsize64 $pdev 2>&1");
    my $result = $? >> 8;
    if ($result == 0) {
        return int ($status / 1024);
    }
    return 0;
}

#==========================================
# setDefaultDeviceMap
#------------------------------------------
sub setDefaultDeviceMap {
    # ...
    # set default device map which creates a mapping for
    # device names to a number
    # ---
    my $this   = shift;
    my $device = shift;
    my %result;
    if (! defined $device) {
        return;
    }
    # wait for udev to finish device creation
    KIWIQX::qxx ("udevadm settle --timeout=30 2>&1");
    for my $part
        (qw(root readonly readwrite boot jump installroot installboot prep)
    ) {
        if ($this->{partids}{$part}) {
            $result{$part} = $this -> __getPartDevice (
                $device,$this->{partids}{$part}
            );
        }
    }
    return %result;
}

#==========================================
# setLoopDeviceMap
#------------------------------------------
sub setLoopDeviceMap {
    # ...
    # set loop device map which creates a mapping for
    # /dev/mapper loop device names to a number
    # ---
    my $this   = shift;
    my $device = shift;
    my %result;
    if (! defined $device) {
        return;
    }
    for my $part
        (qw(root readonly readwrite boot jump installroot installboot prep)
    ) {
        if ($this->{partids}{$part}) {
            $result{$part} = $this -> __getPartDevice (
                $device,$this->{partids}{$part}
            );
        }
    }
    return %result;
}

#==========================================
# setLVMDeviceMap
#------------------------------------------
sub setLVMDeviceMap {
    # ...
    # set LVM device map which creates a mapping for
    # /dev/VG/name volume group device names to a number
    # ---
    my $this   = shift;
    my $group  = shift;
    my $device = shift;
    my $names  = shift;
    my @names  = @{$names};
    my %result;
    if (! defined $group) {
        return;
    }
    for my $part (qw(root readonly readwrite)) {
        if ($this->{partids}{$part."_lv"}) {
            $result{$part} = "/dev/$group/".$this->{partids}{$part."_lv"};
        }
    }
    for my $part (qw(boot jump prep)) {
        if ($this->{partids}{$part}) {
            $result{$part} = $this -> __getPartDevice (
                $device,$this->{partids}{$part}
            );
        }
    }
    return %result;
}

#==========================================
# setupEncoding
#------------------------------------------
sub setupEncoding {
    # ...
    # create luks device map for encryption capabilities
    # The function returns a new device map which has
    # the root device overwritten by the luks device
    # ---
    my $this      = shift;
    my $name      = shift;
    my $map       = shift;
    my $kiwi      = $this->{kiwi};
    my $type      = $this->{type};
    my @cStack    = @{$this->{cleanupStack}};
    my %deviceMap = %{$map};
    my $cipher    = $type->{luks};
    my $dist      = $type->{luksOS};
    my $cmdL      = $this->{cmdL};
    my $data;
    my $code;
    my $opts = '';
    my $device = $deviceMap{root};
    if ($name eq 'luksReadWrite') {
        $device = $deviceMap{readwrite};
    }
    my $blktype = KIWIQX::qxx("blkid $device -s TYPE -o value");
    if (($blktype) && ($blktype eq 'crypto_LUKS')) {
        return %deviceMap;
    }
    if (($dist) && ($dist eq 'sle11')) {
        $opts = $this->{gdata}->{LuksDist}->{sle11};
    }
    # cryptsetup aligns in boundaries of 512-byte sectors
    my $alignment = int ($cmdL->getDiskAlignment() * 2);
    my $size_bt = KIWIGlobals -> instance() -> isize ($device);
    my $size_mb = int ($size_bt / 1048576);
    $opts .= " --align-payload=$alignment";
    $kiwi -> info ("--> Filling $name with random data\n");
    $data = KIWIQX::qxx (
        "dd if=/dev/urandom bs=1M count=$size_mb of=$device 2>&1"
    );
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't fill image with random data: $data");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> info ("--> Creating LUKS encoding\n");
    $code = KIWIGlobals -> instance() -> cryptsetup (
        $cipher, "-q $opts luksFormat $device"
    );
    if ($code != 0) {
        $kiwi -> error  ("Couldn't setup luks format: $device");
        $kiwi -> failed ();
        return;
    }
    $code = KIWIGlobals -> instance() -> cryptsetup (
        $cipher, "luksOpen $device $name"
    );
    if ($code != 0) {
        $kiwi -> error  ("Couldn't open luks device: $device");
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    push @cStack,"cryptsetup luksClose $name";
    $this->{cleanupStack} = \@cStack;
    my $luksdevice = "/dev/mapper/$name";
    if ($name eq 'luksReadWrite') {
        $deviceMap{readwrite} = $luksdevice;
    } else {
        $deviceMap{root} = $luksdevice;
    }
    $this->{luks} = $name;
    return %deviceMap;
}

#==========================================
# setMD
#------------------------------------------
sub setMD {
    # ...
    # create md device for software raid capabilities
    # The function returns a new device map which has
    # the root device overwritten by the md device
    # ---
    my $this      = shift;
    my $map       = shift;
    my $raidtype  = shift;
    my $kiwi      = $this->{kiwi};
    my @cStack    = @{$this->{cleanupStack}};
    my %deviceMap = %{$map};
    my $mdcnt     = 0;
    my $level     = 1;
    my $mddev;
    my $status;
    my $result;
    $kiwi -> info ("--> Creating MD raid\n");
    if ($raidtype eq "striping") {
        $level = 0;
    }
    my $array = "--level=$level --raid-disks=2 $deviceMap{root} missing";
    while ($mdcnt <= 9) {
        $mddev  = '/dev/md'.$mdcnt;
        $status = KIWIQX::qxx ("mdadm --create --run $mddev $array 2>&1");
        $result+= $? >> 8;
        if ($result == 0) {
            last;
        }
        $mdcnt++;
    }
    if ($result != 0) {
        $kiwi -> error  ("Software raid array creation failed: $status");
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    push @cStack,"mdadm --stop $mddev";
    $this->{cleanupStack} = \@cStack;
    $deviceMap{root} = $mddev;
    $this->{mddev} = $mddev;
    return %deviceMap;
}

#==========================================
# setVolumeGroup
#------------------------------------------
sub setVolumeGroup {
    # ...
    # create volume group and required logical
    # volumes. The function returns a new device map
    # including the volume device names
    # ---
    my $this      = shift;
    my $map       = shift;
    my $device    = shift;
    my $syszip    = shift;
    my $haveSplit = shift;
    my $parts     = shift;
    my @cStack    = @{$this->{cleanupStack}};
    my $cmdL      = $this->{cmdL};
    my $kiwi      = $this->{kiwi};
    my $system    = $this->{system};
    my %deviceMap = %{$map};
    my %lvmparts  = %{$parts};
    my $type      = $this->{type};
    my $VGroup    = $type->{lvmgroup};
    my $fsopts    = $cmdL -> getFilesystemOptions();
    my $inoderatio= $fsopts -> getInodeRatio();
    my $align     = $cmdL -> getDiskAlignment();
    my %newmap;
    my $status;
    my $result;
    my $allFree = 'LVRoot';
    $kiwi -> info ("--> Creating volume group\n");
    $status = KIWIQX::qxx ("vgremove --force $VGroup 2>&1");
    $status = KIWIQX::qxx ("test -d /dev/$VGroup && rm -rf /dev/$VGroup 2>&1");
    $status = KIWIQX::qxx (
        "pvcreate --dataalignment $align $deviceMap{root} 2>&1"
    );
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Failed creating physical extends: $status");
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    $status = KIWIQX::qxx ("vgcreate $VGroup $deviceMap{root} 2>&1");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Failed creating volume group: $status");
        $kiwi -> failed ();
        $this -> cleanStack ();
        return;
    }
    push @cStack,"vgchange -an $VGroup";
    $this->{cleanupStack} = \@cStack;
    $kiwi -> info ("--> Creating logical volumes\n");
    if (($syszip) || ($haveSplit)) {
        $status = KIWIQX::qxx (
            "lvcreate --noudevsync -L $syszip -n LVComp $VGroup 2>&1"
        );
        $result = $? >> 8;
        $status.= KIWIQX::qxx (
            "lvcreate --noudevsync -l +100%FREE -n LVRoot $VGroup 2>&1"
        );
        $result+= $? >> 8;
        if ($result != 0) {
            $kiwi -> error  ("Logical volume(s) setup failed: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        %newmap = $this -> setLVMDeviceMap (
            $VGroup,$device,["LVComp","LVRoot"]
        );
    } else {
        if (%lvmparts) {
            my %ihash = ();
            foreach my $name (keys %lvmparts) {
                my $lvname = $lvmparts{$name}->[2];
                if (! $lvname) {
                    $lvname = 'LV'.$name;
                }
                if (($lvmparts{$name}->[0]) &&
                    ($lvmparts{$name}->[0] eq 'all')
                ) {
                    if ($name eq '@root') {
                        $allFree = 'LVRoot';
                    } else {
                        $allFree = $lvname;
                    }
                }
                if ($name ne '@root') {
                    my $lvsize = $lvmparts{$name}->[3];
                    my $lvdev  = "/dev/$VGroup/$lvname";
                    my $inodes = 2 * int ($lvsize * 1048576 / $inoderatio);
                    if ($inodes < $this->{gdata}->{FSMinInodes}) {
                        $inodes = $this->{gdata}->{FSMinInodes};
                    }
                    $ihash{$lvdev} = $inodes;
                    $status = KIWIQX::qxx (
                        "lvcreate --noudevsync -L $lvsize -n $lvname $VGroup 2>&1"
                    );
                    $result = $? >> 8;
                    if ($result != 0) {
                        last;
                    }
                }
            }
            $this->{deviceinodes} = \%ihash;
        }
        if ($result == 0) {
            if (($lvmparts{'@root'}) && ($lvmparts{'@root'}->[3])) {
                my $rootsize = $lvmparts{'@root'}->[3];
                $status = KIWIQX::qxx (
                    "lvcreate --noudevsync -L $rootsize -n LVRoot $VGroup 2>&1"
                );
            } else {
                $status = KIWIQX::qxx (
                    "lvcreate --noudevsync -l +100%FREE -n LVRoot $VGroup 2>&1"
                );
            }
            $result = $? >> 8;
        }
        if ($result == 0) {
            if (($lvmparts{'@root'}) && ($lvmparts{'@root'}->[3])) {
                $status = KIWIQX::qxx (
                    "lvextend -l +100%FREE /dev/$VGroup/$allFree 2>&1"
                );
                $result = $? >> 8;
            }
        }
        if ($result != 0) {
            $kiwi -> error  ("Logical volume(s) setup failed: $status");
            $kiwi -> failed ();
            $this -> cleanStack ();
            return;
        }
        %newmap = $this -> setLVMDeviceMap (
            $VGroup,$device,["LVRoot"]
        );
    }
    return %newmap;
}

#==========================================
# deleteVolumeGroup
#------------------------------------------
sub deleteVolumeGroup {
    my $this   = shift;
    my $type   = $this->{type};
    my $VGroup = $type->{lvmgroup};
    if ($type->{lvm}) {
        KIWIQX::qxx ("vgremove --force $VGroup 2>&1");
        KIWIQX::qxx ("test -d /dev/$VGroup && rm -rf /dev/$VGroup 2>&1");
    }
    return $this;
}

#==========================================
# makeLabel
#------------------------------------------
sub makeLabel {
    # ...
    # grub handles spaces as "_", so we replace
    # each space with an underscore
    # ----
    my $this  = shift;
    my $label = shift;
    my $loader= $this->{loader};
    if ($loader ne "grub2") {
        $label =~ s/ /_/g;
    }
    return $label;
}

#==========================================
# quoteLabel
#------------------------------------------
sub quoteLabel {
    my $this  = shift;
    my $label = shift;
    return KIWIConfigure::quoteshell ($label);
}

#==========================================
# luksResize
#------------------------------------------
sub luksResize {
    my $this   = shift;
    my $source = shift;
    my $name   = shift;
    my $kiwi   = $this->{kiwi};
    my $cipher = $this->{gdata}->{LuksCipher};
    my $status;
    my $result;
    my $hald;
    #==========================================
    # open luks device
    #------------------------------------------
    if ($cipher) {
        $result = KIWIGlobals -> instance() -> cryptsetup(
            $cipher, "luksOpen $source $name"
        );
    } else {
        KIWIQX::qxx ("cryptsetup luksOpen $source $name 2>&1");
        $result = $? >> 8;
    }
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't open luks device: $source");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # resize luks header
    #------------------------------------------
    $this->{luks} = $name;
    $status = KIWIQX::qxx ("cryptsetup resize $name");
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't resize luks device: $status");
        $kiwi -> failed ();
        $this -> luksClose();
        return;
    }
    #==========================================
    # return mapped device name
    #------------------------------------------
    return "/dev/mapper/".$name;
}

#==========================================
# luksClose
#------------------------------------------
sub luksClose {
    my $this = shift;
    if ($this->{luks}) {
        KIWIQX::qxx ("cryptsetup luksClose $this->{luks} 2>&1");
        undef $this->{luks};
    }
    return $this;
}

#==========================================
# umountDevice
#------------------------------------------
sub umountDevice {
    # ...
    # umount all mounted filesystems from the given
    # storage device. The functions searches the
    # /proc/mounts table and umounts all corresponding
    # mount entries
    # ----
    my $this = shift;
    my $disk = shift;
    my $kiwi = $this->{kiwi};
    my $MOUNTS;
    if (! defined $disk) {
        $kiwi -> loginfo ("umountDevice: no disk prefix provided, skipped");
        return;
    }
    if (! open ($MOUNTS, '<', '/proc/mounts')) {
        $kiwi -> loginfo ("umountDevice: failed to open proc/mounts: $!");
        return;
    }
    my @mounts = <$MOUNTS>; close $MOUNTS;
    for my $mount (@mounts) {
        if ($mount =~ /^$disk/) {
            my ($device, $mountpoint, $rest) = split / /, $mount, 3;
            KIWIQX::qxx ("umount $device 2>&1");
        }
    }
    return $this;
}

#==========================================
# setupFilesystem
#------------------------------------------
sub setupFilesystem {
    # ...
    # create filesystem according to selected type
    # ----
    my $this   = shift;
    my $fstype = shift;
    my $device = shift;
    my $name   = shift;
    my $bootp  = shift;
    my $type   = $this->{type};
    my $inodes = $this->{deviceinodes};
    my $kiwi   = $this->{kiwi};
    my $xml    = $this->{xml};
    my $cmdL   = $this->{cmdL};
    if (! $type->{fsnocheck}) {
        $type->{fsnocheck} = 'true';
    }
    my $fsOpts = $cmdL -> getFilesystemOptions();
    my $iorig  = $this->{inodes};
    my $result;
    my $status;
    if (($inodes) && ($inodes->{$device})) {
        if ($inodes->{$device} ne "no-opts") {
            $this->{inodes} = $inodes->{$device};
        } else {
            undef $this->{inodes};
        }
    }
    SWITCH: for ($fstype) {
        /^ext[234]/     && do {
            $kiwi -> info ("Creating $_ $name filesystem");
            my $createArgs = $fsOpts -> getOptionsStrExt();
            my $fstool = "mkfs.".$fstype;
            if (($this->{inodes}) && (! $bootp)) {
                $createArgs .= " -N $this->{inodes}";
            }
            my $tuneopts = $fsOpts -> getTuneOptsExt();
            if ($bootp) {
                $createArgs .= " -L '".$bootp."'";
                if (! $tuneopts) {
                    $tuneopts = "-c 0 -i 0 ";
                }
            }
            $status = KIWIQX::qxx ("$fstool $createArgs $device 2>&1");
            $result = $? >> 8;
            if (!$result && $tuneopts) {
                $status .= KIWIQX::qxx ("/sbin/tune2fs $tuneopts $device 2>&1");
                $result = $? >> 8;
            }
            last SWITCH;
        };
        /^fat16|fat32/  && do {
            my $fstool = 'mkdosfs';
            my $fsopts = '';
            if ($fstype eq 'fat16') {
                $kiwi -> info ("Creating DOS [Fat16] filesystem");
                $fsopts.= " -F16 -I";
            } else {
                $kiwi -> info ("Creating DOS [Fat32] filesystem");
                $fsopts.= " -F32 -I";
            }
            if ($bootp) {
                $fsopts.= " -n '".$bootp."'";
            }
            $status = KIWIQX::qxx ("$fstool $fsopts $device 2>&1");
            $result = $? >> 8;
            last SWITCH;
        };
        /^reiserfs/     && do {
            $kiwi -> info ("Creating reiserfs $name filesystem");
            my $createArgs = $fsOpts -> getOptionsStrReiser();
            $createArgs .= " -f";
            $status = KIWIQX::qxx (
                "/sbin/mkreiserfs $createArgs $device 2>&1"
            );
            $result = $? >> 8;
            last SWITCH;
        };
        /^btrfs/        && do {
            $kiwi -> info ("Creating btrfs $name filesystem");
            my $createArgs = $fsOpts -> getOptionsStrBtrfs();
            $status = KIWIQX::qxx (
                "/sbin/mkfs.btrfs $createArgs $device 2>&1"
            );
            $result = $? >> 8;
            last SWITCH;
        };
        /^xfs/          && do {
            $kiwi -> info ("Creating xfs $name filesystem");
            my $createArgs = $fsOpts -> getOptionsStrXFS();
            $status = KIWIQX::qxx (
                "/sbin/mkfs.xfs $createArgs $device 2>&1"
            );
            $result = $? >> 8;
            last SWITCH;
        };
        /^zfs/          && do {
            $kiwi -> info ("Creating zfs $name filesystem");
            my $opts;
            my $zfsopts;
            if ($xml) {
                $opts = $xml -> getImageType() -> getFSMountOptions();
                $zfsopts = $xml -> getImageType() -> getZFSOptions();
            }
            if ($opts) {
                $status = KIWIQX::qxx (
                    "zpool create $opts kiwipool $device 2>&1"
                );
            } else {
                $status = KIWIQX::qxx (
                    "zpool create kiwipool $device 2>&1"
                );
            }
            $result = $? >> 8;
            if ($result == 0) {
                if (! KIWIGlobals -> instance() -> createZFSPool($zfsopts)) {
                    $result = 1;
                }
            }
            last SWITCH;
        };
        $kiwi -> error  ("Unsupported filesystem type: $fstype");
        $kiwi -> failed ();
        $this->{inodes} = $iorig;
        return;
    };
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create $fstype filesystem: $status");
        $kiwi -> failed ();
        $this->{inodes} = $iorig;
        return;
    }
    $kiwi -> done();
    $this->{inodes} = $iorig;
    return $this;
}

#==========================================
# addBootNext
#------------------------------------------
sub addBootNext {
    # ...
    # Write boot program that boots the firsts drive that
    # does _not_ have our mbr id. The boot program source which
    # creates $bootnext below is added in the git repo below
    # tools/bootnext
    # ---
    my $this = shift;
    my $file = shift;
    my $id   = shift;
    my $bootnext =
        "\x8c\xc8\x8e\xd0\x31\xe4\x8e\xd8\x8e\xc0\xfc\xfb\xbe\x00\x7c\xbf" .
        "\x00\x60\xb9\x00\x01\xf3\xa5\xea\x1c\x60\x00\x00\xb4\x08\x31\xff" .
        "\xb2\x80\xcd\x13\x73\x02\xb2\x01\x80\xfa\x01\xb0\x80\x10\xc2\x88" .
        "\x16\x29\x61\xa2\x2a\x61\xe8\x8b\x00\x73\x10\xa0\x2a\x61\x40\x3a" .
        "\x06\x29\x61\x72\xee\xbe\x2d\x61\xe9\xb3\x00\x80\x3e\x2a\x61\x80" .
        "\x74\x03\xe8\x07\x00\xb2\x80\xea\x00\x7c\x00\x00\xa1\x13\x04\x48" .
        "\xa3\x13\x04\xc1\xe0\x06\x2d\x00\x06\x66\x8b\x16\x4c\x00\x66\x89" .
        "\x16\x25\x61\x50\x68\x89\x60\x66\x8f\x06\x4c\x00\x50\x07\xbe\x00" .
        "\x60\x89\xf7\xb9\x00\x01\xf3\xa5\xc3\x9c\x2e\x88\x16\x2b\x61\x2e" .
        "\x88\x26\x2c\x61\x2e\x3a\x16\x2a\x61\x75\x04\xb2\x80\xeb\x0a\x80" .
        "\xfa\x80\x75\x05\x2e\x8a\x16\x2a\x61\x2e\xff\x1e\x25\x61\x50\x9f" .
        "\x67\x88\x64\x24\x06\x58\x2e\x80\x3e\x2c\x61\x08\x74\x05\x2e\x8a" .
        "\x16\x2b\x61\xcf\xe8\x10\x00\x72\x0d\x66\xa1\xb8\x61\x66\x3b\x06" .
        "\xb8\x7d\xf9\x74\x01\xf8\xc3\xb8\x01\x02\xb9\x01\x00\xb6\x00\x8a" .
        "\x16\x2a\x61\xbb\x00\x7c\xcd\x13\x72\x13\x66\x83\x3e\x00\x7c\x00" .
        "\xf9\x74\x0a\x81\x3e\xfe\x7d\x55\xaa\xf9\x75\x01\xf8\xc3\xe8\x15" .
        "\x00\xbe\x44\x61\xe8\x0f\x00\xb4\x00\xcd\x16\xbe\x41\x61\xe8\x05" .
        "\x00\xcd\x19\xf4\xeb\xfd\xac\x08\xc0\x74\x09\xbb\x07\x00\xb4\x0e" .
        "\xcd\x10\xeb\xf2\xc3\x00\x00\x00\x00\x00\x00\x00\x00\x4e\x6f\x20" .
        "\x6f\x70\x65\x72\x61\x74\x69\x6e\x67\x20\x73\x79\x73\x74\x65\x6d" .
        "\x2e\x0d\x0a\x00\x0a\x50\x72\x65\x73\x73\x20\x61\x20\x6b\x65\x79" .
        "\x20\x74\x6f\x20\x72\x65\x62\x6f\x6f\x74\x2e\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x55\xaa";

    # we really need a valid id
    return unless $id;

    substr $bootnext, 0x1b8, 4, pack("V", $id);

    my $bn = FileHandle -> new();
    if (! $bn -> open (">$file")) {
        return;
    }
    print $bn $bootnext;
    $bn -> close();
    return $this;
}

#==========================================
# diskOffset
#------------------------------------------
sub diskOffset {
    # ...
    # find the offset to the start of the first partition
    # ---
    my $this = shift;
    my $disk = shift;
    my $kiwi = $this->{kiwi};
    my $tool = $this->{ptool};
    my $global = KIWIGlobals -> instance();
    my $offset;
    my $result;
    my $status;
    if ($tool eq 'fdasd') {
        my $loop = $global -> loop_setup($disk, $this->{xml});
        my $track_blocks = KIWIQX::qxx(
            "fdasd -f -p $loop | grep 'blocks per track' | cut -f2 -d:"
        );
        $result = $? >> 8;
        chomp $track_blocks;
        my $start_tracks = 0;
        if ($result == 0) {
            $start_tracks = KIWIQX::qxx(
                "fdasd -f -s -p $loop | head -n 1 | tr -s ' ' | cut -f3 -d ' '"
            );
            $result = $? >> 8;
            chomp $start_tracks;
        }
        $global -> loop_delete($loop);
        $offset = int($track_blocks) * int($start_tracks);
    } else {
        $status = KIWIQX::qxx(
            "parted -m $disk unit s print 2>&1"
        );
        $result = $? >> 8;
        chomp $status;
        my @table = split(/\n/,$status);
        foreach my $entry (@table) {
            if ($entry =~ /^[1-4]:/) {
                my @items = split (/:/,$entry);
                $offset = $items[1];
                chop $offset;
                last;
            }
        }
    }
    if ($result != 0) {
        $kiwi -> error ("Failed to obtain partition geometry: $status");
        $kiwi -> failed();
        return;
    }
    if (! $offset) {
        $kiwi -> error ("empty partition offset: $status");
        $kiwi -> failed();
        return;
    } elsif (! looks_like_number($offset)) {
        $kiwi -> error ("bogus partition offset: $offset");
        $kiwi -> failed();
        return;
    }
    return $offset;
}

#==========================================
# diskCHS
#------------------------------------------
sub diskCHS {
    my $this = shift;
    my $disk = shift;
    my $kiwi = $this->{kiwi};
    my $tool = $this->{ptool};
    my $global = KIWIGlobals -> instance();
    my $cylinders;
    my $tracks;
    my $blocks;
    my $result;
    if ($tool ne 'fdasd') {
        $kiwi -> error ("CHS retrieval only implemented for fdasd");
        $kiwi -> failed();
        return;
    }
    my $loop = $global -> loop_setup($disk, $this->{xml});
    $cylinders = KIWIQX::qxx(
        "fdasd -f -p $loop | grep cylinders | cut -f2 -d:"
    );
    $result = $? >> 8;
    chomp $cylinders;
    if ($result == 0) {
        $tracks = KIWIQX::qxx(
            "fdasd -f -p $loop | grep 'tracks per cylinder' | cut -f2 -d:"
        );
        $result = $? >> 8;
        chomp $tracks;
    }
    if ($result == 0) {
        $blocks = KIWIQX::qxx(
            "fdasd -f -p $loop | grep 'blocks per track' | cut -f2 -d:"
        );
        $result = $? >> 8;
        chomp $blocks;
    }
    $global -> loop_delete($loop);
    if ($result != 0) {
        $kiwi -> error ("Failed to obtain CHS geometry");
        $kiwi -> failed();
        return;
    }
    return sprintf "%d,%d,%d",
        int($cylinders), int($tracks), int($blocks);
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
    my $this = shift;
    my $dirs = $this->{tmpdirs};
    foreach my $dir (@{$dirs}) {
        KIWIQX::qxx ("rm -rf $dir 2>&1");
    }
    return $this -> cleanStack ();
}

#==========================================
# Private methods
#------------------------------------------
#==========================================
# __getBootSize
#------------------------------------------
sub __getBootSize {
    # ...
    # set minimum boot size or the specified value from the
    # XML description. The function returns the size in
    # M-Bytes.
    # ---
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $xml    = $this->{xml};
    my $type   = $this->{type};
    my $system = $this->{system};
    my $initrd = $this->{initrd};
    my $bootMB = 0;
    my $irdMB  = 0;
    my $msg;
    # /.../
    # The minimum boot partition size is based on best guess
    # because prior to the creation of the disk boot fs and uuid
    # we don't know exactly how much space is used on boot. Thus
    # the size estimation is based on:
    #
    # 1. the current size of the system boot/ directory as a start
    if (($system) && (-d $system.'/boot')) {
        $bootMB = int (KIWIGlobals -> instance()
            -> dsize ($system.'/boot') / 1048576);
    }
    # 2. plus twice the size of the kiwi initrd
    if (($initrd) && (-e $initrd)) {
        $irdMB = int (KIWIGlobals -> instance()
            -> isize ($initrd) / 1048576);
        # it's doubled because bootloader and theme data is
        # copied from the initrd in the stage setup
        $bootMB += (2 * $irdMB);
    }
    # 3. plus 100M addon space to reach roughly 100MB free
    my $needMB = 100 + $bootMB;
    if ($type->{bootpartsize}) {
        my $wantMB = $type->{bootpartsize};
        if ($wantMB < $needMB) {
            $msg = "Specified bootpartsize is smaller than ";
            $msg.= "recommended value of $needMB MB\n";
            $kiwi -> warning ($msg);
        }
        $needMB = $wantMB;
    }
    $kiwi -> info ("Set boot partition space to: ".$needMB."M\n");
    return $needMB;
}

#==========================================
# __expandFS
#------------------------------------------
sub __expandFS {
    # ...
    # Expand the file system to its maximum size
    # ---
    my $this      = shift;
    my $fsType    = shift;
    my $diskType  = shift;
    my $mapper    = shift;
    my $kiwi      = $this->{kiwi};
    my $locator   = KIWILocator -> instance();
    my $result    = 1;
    my $status;
    my $tmpdir = KIWIQX::qxx ("mktemp -qdt kiwiresize.XXXXXX");
    chomp $tmpdir;
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
        $kiwi -> failed ();
        $this -> luksClose();
        return;
    }
    push @{$this->{tmpdirs}}, $tmpdir;
    $kiwi->loginfo ("Resize Operation: Device: $mapper\n");
    $kiwi->loginfo ("Resize Operation: Image Disk Type: $diskType\n");
    $kiwi->loginfo ("Resize Operation: Filesystem Type: $fsType\n");
    SWITCH: for ($fsType) {
        /^ext\d/    && do {
            $kiwi -> info ("Resizing $diskType $fsType filesystem");
            my $resize = $locator -> getExecPath ('resize2fs');
            if (! $resize) {
                $kiwi -> error ('Could not locate resize2fs');
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx ("$resize -f -F -p $mapper 2>&1");
            $result = $? >> 8;
            last SWITCH;
        };
        /^reiserfs/ && do {
            $kiwi -> info ("Resizing $diskType $fsType filesystem");
            my $resize = $locator -> getExecPath ('resize_reiserfs');
            if (! $resize) {
                $kiwi -> error ('Could not locate resize_reiserfs');
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx ("$resize $mapper 2>&1");
            $result = $? >> 8;
            last SWITCH;
        };
        /^btrfs/    && do {
            $kiwi -> info ("Resizing $diskType $fsType filesystem");
            my $btrfs_ctrl = $locator -> getExecPath('btrfsctl');
            my $btrfs_tool = $locator -> getExecPath('btrfs');
            my $btrfs_cmd;
            if ((! $btrfs_tool) && (! $btrfs_ctrl)) {
                $kiwi -> error ('Could not locate btrfs control tool');
                $kiwi -> failed ();
                return;
            }
            if ($btrfs_tool) {
                $btrfs_cmd = "$btrfs_tool filesystem resize max $tmpdir";
            } else {
                $btrfs_cmd = "$btrfs_ctrl -r max $tmpdir";
            }
            $status = KIWIQX::qxx ("
                mount $mapper $tmpdir && $btrfs_cmd; umount $tmpdir 2>&1"
            );
            $result = $? >> 8;
            last SWITCH;
        };
        /^xfs/      && do {
            $kiwi -> info ("Resizing $diskType $fsType filesystem");
            my $xfsGrow = $locator -> getExecPath('xfs_growfs');
            if (! $xfsGrow) {
                $kiwi -> error ('Could not locate xfs_grow');
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx ("
                mount $mapper $tmpdir && $xfsGrow $tmpdir; umount $tmpdir 2>&1"
            );
            $result = $? >> 8;
            last SWITCH;
        };
        $kiwi->loginfo ("Resize Operation: no resize\n");
        $result = 0;
    };
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't resize $fsType filesystem $status");
        $kiwi -> failed ();
        $this -> luksClose();
        return;
    }
    $this -> luksClose();
    if ($status) {
        $kiwi -> done();
    }
    return $this;
}

#==========================================
# __initDiskSize
#------------------------------------------
sub __initDiskSize {
    # ...
    # setup initial disk size value
    # ---
    my $this      = shift;
    my $kiwi      = $this->{kiwi};
    my $minBytes  = shift;
    my $cmdlsize  = shift;
    my $XMLBytes  = shift;
    my $vmsize    = 0;
    my $vmmbyte   = 0;
    #==========================================
    # Store size values from cmdline and XML
    #------------------------------------------
    $this->{cmdlsize} = $cmdlsize;
    $this->{XMLBytes} = $XMLBytes;
    #==========================================
    # Create vmsize MB string and vmmbyte value
    #------------------------------------------
    $vmsize  = $minBytes / 1048576;
    $vmsize  = sprintf ("%.0f", $vmsize);
    $vmmbyte = $vmsize;
    $vmsize  = $vmsize."M";
    $kiwi -> loginfo (
        "Starting with disk size: $vmsize\n"
    );
    $this->{vmmbyte} = $vmmbyte;
    $this->{vmsize}  = $vmsize;
    return $this;
}

#==========================================
# __updateDiskSize
#------------------------------------------
sub __updateDiskSize {
    # ...
    # increase the current virtual disk size value
    # by the specified value. value is treated as
    # number in MB
    # ---
    my $this   = shift;
    my $addMB  = shift;
    my $kiwi   = $this->{kiwi};
    my $vmsize = $this->{vmmbyte} + $addMB;
    $vmsize = sprintf ("%.0f", $vmsize);
    $this->{vmmbyte} = $vmsize;
    $vmsize = $vmsize."M";
    $this->{vmsize}  = $vmsize;
    $kiwi->loginfo (
        "Increasing disk size by ".$addMB."M to: ".$vmsize."\n"
    );
    return $this;
}

#==========================================
# __updateCustomDiskSize
#------------------------------------------
sub __updateCustomDiskSize {
    # ...
    # if a custom disk size is set via the commandline
    # or the <size> element from XML, this function uses
    # the custom value if it is smaller than the currently
    # calculcated disk size value
    # ---
    my $this      = shift;
    my $kiwi      = $this->{kiwi};
    my $cmdlsize  = $this->{cmdlsize};
    my $XMLBytes  = $this->{XMLBytes};
    my $cmdlBytes = 0;
    my $vmsize    = 0;
    my $vmmbyte   = 0;
    my $reqBytes  = 0;
    #===========================================
    # turn optional size from cmdline into bytes
    #-------------------------------------------
    if (($cmdlsize) && ($cmdlsize =~ /^(\d+)([MG])$/i)) {
        my $value= $1;
        my $unit = $2;
        if ($unit eq "G") {
            # convert GB to MB...
            $value *= 1024;
        }
        # convert MB to Byte
        $cmdlBytes = $value * 1048576;
    }
    #===========================================
    # adapt req size according to cmdline or XML
    #-------------------------------------------
    if ($cmdlBytes > 0) {
        $reqBytes = $cmdlBytes;
    } elsif (("$XMLBytes" ne "auto") && ($XMLBytes > 0)) {
        $reqBytes = $XMLBytes;
    }
    if ($reqBytes == 0) {
        return $this;
    }
    my $reqMBytes = int ($reqBytes / 1048576);
    if ($reqMBytes < $this->{vmmbyte}) {
        $kiwi -> warning (
            "given disk size is smaller than calculated size, using it anyhow"
        );
        $kiwi -> oops ();
    }
    #==========================================
    # Create vmsize MB string and vmmbyte value
    #------------------------------------------
    $vmmbyte = $reqMBytes;
    $vmsize  = $reqMBytes."M";
    $kiwi -> loginfo (
        "Using custom disk size: $vmsize\n"
    );
    $this->{vmmbyte} = $vmmbyte;
    $this->{vmsize}  = $vmsize;
    return $this;
}

#==========================================
# __getPartDevice
#------------------------------------------
sub __getPartDevice {
    # ...
    # find the correct partition device according
    # to the disk device and partition number
    # ---
    my $this = shift;
    my $disk = shift;
    my $part = shift;
    my $devcopy = $disk;
    my $devbase = basename $devcopy;
    my @checklist = (
        "/dev/mapper/".$devbase."p".$part,
        "/dev/".$devbase."p".$part,
        "/dev/".$devbase.$part
    );
    foreach my $device (@checklist) {
        if (-b $device) {
            return $device;
        }
    }
    return;
}

1;
