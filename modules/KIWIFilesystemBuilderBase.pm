#================
# FILE          : KIWIFilesystemBuilderBase.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2015 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Base class for the *Builder classes when * is a filesystem
#               :
# STATUS        : Development
#----------------
package KIWIFilesystemBuilderBase;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Readonly;

require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX;
use KIWIXML;

use base qw /KIWIImageBuilderBase/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# constants
#------------------------------------------
Readonly my $BASEFREE => 100;
Readonly my $BKILO    => 1024;
Readonly my $EIGHTK   => 8192;
Readonly my $MEGABYTE => 1_048_576;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIFilesystemBuilder object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    if (! $this) {
        return;
    }
    $this->{baseFreeSpace} = $BASEFREE;
    $this->{targetDevice}  = $this->{cmdL} -> getImageTargetDevice();
    return $this;
}

#==========================================
# Protected methods
#------------------------------------------
#==========================================
# p_calculateMinImageSize
#------------------------------------------
sub p_calculateMinImageSize {
    # ...
    # Calculate the size of the image file to be created for loop mounting
    # ---
    my $this = shift;
    my $cmdL    = $this->{cmdL};
    my $kiwi    = $this->{kiwi};
    my $uPckImg = $this->{uPckImg};
    my $xml     = $this->{xml};
    my $uPckSize = $uPckImg -> getInstalledSize();
    my $size = ($uPckSize * $this->{fsohead})
        + $this -> p_filesysSizingAdjustment()
        + ($this->{baseFreeSpace} * $BKILO * $BKILO);
    my $bldType = $xml -> getImageType();
    my $addSize = $bldType -> isSizeAdditive();
    if ($addSize eq 'true') {
        my $specSize = $bldType -> getSize();
        my $sizeUnit = $bldType -> getSizeUnit();
        $specSize = $this -> __convertToBytes($specSize, $sizeUnit);
        $kiwi ->  loginfo ("Adding specified $size Bytes per XML file\n");
        $size += $specSize;
    }
    my $minsize = sprintf ("%.0f", $size);
    $kiwi ->  loginfo ("Calculated mini fs size: $minsize Bytes\n");
    return $size;
}

#==========================================
# p_determineImageSize
#------------------------------------------
sub p_determineImageSize {
    # ...
    # Return a hash ref with
    #  size
    #  inodeCnt
    # values.
    # size =
    #        argument value if no value is specified in the XML
    #   or
    #        XML specified value if XML value is larger then argument value
    #   or
    #        the larger of XML value and absolute minimum if the XML
    #        value is smaller than the argument value
    #
    # inodeCnt =
    #        2 * inode count of unpacked image tree
    #  or
    #        XML-size / inode-ratio
    #
    # The argument is expected to be in Bytes
    # ---
    my $this = shift;
    my $size = shift;
    my $kiwi = $this->{kiwi};
    if (! $size) {
        my $msg = 'KIWIFilesystemBuilder:__determineImageSize called without '
            . 'size argument. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    my $uPckImg = $this->{uPckImg};
    my $inodeCnt = $uPckImg -> getNumInodes();
    if (! $inodeCnt) {
        return;
    }
    my %sizeInfo;
    my $cmdL = $this->{cmdL};
    my $fsoption = $cmdL -> getFilesystemOptions();
    my $inoderatio = $fsoption->getInodeRatio();
    $sizeInfo{size} = $size;
    $sizeInfo{inodeCnt} = 2* $inodeCnt;
    my $xml  = $this->{xml};
    my $specSize = $xml -> getImageType() -> getSize();
    if ($specSize) {
        my $sizeUnit =  $xml -> getImageType() -> getSizeUnit();
        $specSize = $this -> __convertToBytes($specSize, $sizeUnit);
        $sizeInfo{size} = $specSize;
        $sizeInfo{inodeCnt} = $specSize / $inoderatio;
        if ($specSize < $size) {
            # XML specified size is smaller than the calculated size
            # we might be in trouble but don't know for certain
            my $mSize = $this -> __convertBytesToMB($size);
            my $specMSize = $this -> __convertBytesToMB($specSize);
            my $wmsg = "Specified size in configuration '$specMSize' MB "
                . "is smaller than desired size '$mSize' MB "
                . 'attempting to use XML specified size.';
            $kiwi -> warning ($wmsg);
            my $defInodeRatio = $cmdL -> getdefaultFSRatio();
            if (! $defInodeRatio) {
                my $imsg = 'Ignoring command line specified inode ratio';
                $kiwi -> loginfo($imsg);
            }
            $sizeInfo{inodeCnt} = 2 * $inodeCnt;
            my $uSize = $uPckImg -> getInstalledSize();
            if ($specSize < $uSize) {
                # Specified size is smaller than the unpacked image tree
                # this is not going to work
                my $uMSize = $this -> __convertBytesToMB($uSize);
                my $msg = "Specified size in configuration '$specMSize' MB "
                    . "is smaller than unpacked image size '$uMSize' MB "
                    . "using minimum size '$uMSize' MB ";
                $kiwi -> warning ($msg);
                $sizeInfo{size} = $uSize;
            }
        }
    }
    return \%sizeInfo;
}

#==========================================
# p_getBlockData
#------------------------------------------
sub p_getBlockData {
    # ...
    # Return a hash ref containing information about the
    # blocksize
    # blockcount
    # offset
    # The size input unit is expected to be bytes.
    # ---
    my $this  = shift;
    my $sizeInfo = shift;
    if (! $sizeInfo) {
        my $kiwi = $this->{kiwi};
        my $msg = 'KIWIFilesystemBuilder:__getBlockSize called without '
            . 'size argument. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    my $sizeB = $sizeInfo->{size};
    my %blockInfo;
    if ($sizeB > $BASEFREE * $BKILO * $BKILO) {
        $blockInfo{blocksize} = $MEGABYTE;
    } else {
        $blockInfo{blocksize} = $EIGHTK;
    }
    $blockInfo{blockcount} = $sizeB / $blockInfo{blocksize};
    $blockInfo{offset} = $blockInfo{blockcount} * $blockInfo{blocksize};
    return \%blockInfo;
}

#==========================================
# p_getBlockDevice
#------------------------------------------
sub p_getBlockDevice {
    # ...
    # Return a block device for the image
    # ---
    my $this      = shift;
    my $blockInfo = shift;
    my $kiwi = $this->{kiwi};
    my $xml = $this->{xml};
    if (! $blockInfo) {
        my $msg = 'KIWIFilesystemBuilder:p_getBlockDevice called without '
            . 'block data. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    my $device = $this->{cmdL} -> getImageTargetDevice();
    if ($ device) {
        return $device
    }
    my $global = KIWIGlobals -> instance();
    my $studioNode = $global -> getKiwiConfigEntry('StudioNode');
    my $offset = $blockInfo->{offset};
    if ($studioNode) {
        #==========================================
        # Call custom image creation tool...
        #------------------------------------------
        my $studioDevice = KIWIQX::qxx ("$studioNode $offset 2>&1");
        my $code = $? >> 8;
        chomp $studioDevice;
        if (($code != 0) || (! -b $device)) {
            my $smsg = "Failed creating Studio storage device: $device";
            $kiwi -> error($smsg);
            $kiwi -> failed ();
            return;
        }
        return $studioDevice;
    }
    my $imgName = $global -> generateBuildImageName($xml)
                . '.'
                . $this->{fstype};
    my $imgPath = $this -> getBaseBuildDirectory()
        . '/'
        . $imgName;
    unlink $imgPath;
    my $locator = KIWILocator -> instance();
    my $qemuImg = $locator -> getExecPath('qemu-img');
    if (! $qemuImg) {
        my $msg = 'Could not find image file creation tool qemu-img';
        $kiwi -> error($msg);
        $kiwi -> failed ();
        return;
    }
    my $mSize = $this -> __convertBytesToMB($offset);
    my $cmd = "$qemuImg create $imgPath $mSize" . 'M';
    my $data = KIWIQX::qxx ("$cmd 2>&1");
    my $code = $? >> 8;
    if ($code != 0) {
        my $msg = "Could not create image file '$imgPath'";
        $kiwi -> error($msg);
        $kiwi -> failed();
        $kiwi -> error($data);
        return;
    }
    $this -> p_addCreatedFile($imgName);
    $device = $global -> loop_setup($imgPath, $xml);
    if (! $device) {
        return;
    }
    return $device;
}

#==========================================
# p_encryptDevice
#------------------------------------------
sub p_encryptDevice {
    # ...
    # Setup the given device for encryption
    # ---
    my $this   = shift;
    my $device = shift;
    my $kiwi = $this->{kiwi};
    my $xml = $this->{xml};
    my $cipher = $xml -> getImageType() -> getLuksPass();
    if (! $cipher) {
        return 1; # Nothing to do
    }
    if (! $device) {
        my $msg = 'KIWIFilesystemBuilder:__encryptDevice called without '
            . 'device argument. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    if (! -b $device) {
        my $msg = 'KIWIFilesystemBuilder:__encryptDevice given device is '
            . 'not a block device. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    my $data = KIWIQX::qxx ("echo $cipher | cryptsetup -q luksFormat $device 2>&1");
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't setup luks format: $device");
        $kiwi -> failed ();
        return;
    }
    my $imgName = KIWIGlobals -> instance() -> generateBuildImageName($xml);
    $data = KIWIQX::qxx ("echo $cipher | cryptsetup luksOpen $device $imgName 2>&1");
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't open luks device: $data");
        $kiwi -> failed ();
        return;
    }
    $this->{luksdevice} = $device;
    return 1;
}

#==========================================
# p_getFilesystemType
#------------------------------------------
sub p_getFilesystemType {
    # ...
    # Return the file system
    # ---
    my $this = shift;
    return $this->{fstype};
}

#==========================================
# p_mountDevice
#------------------------------------------
sub p_mountDevice {
    # ...
    # Mount the given device to a generated mount point in the
    # given target directory and return the mount point
    # ---
    my $this      = shift;
    my $device    = shift;
    my $targetDir = shift;
    my $kiwi = $this->{kiwi};
    if (! $device) {
        my $msg = 'p_mountDevice: called without device argument, '
            . 'internal error, please report a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $targetDir || ! -d $targetDir) {
        my $msg = 'p_mountDevice: called without target directory or '
            . 'directory does not exist. Internal error, please report a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $type = $this->{xml} -> getImageType();
    my $mntPnt = "$targetDir/kiwi-fsmnt-$$";
    my $status = mkdir "$mntPnt";
    if (! $status) {
        my $msg = "Could not create mount point '$mntPnt'";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $fsT = $this -> p_getFilesystemType();
    my $mountOpts = $type -> getFSMountOptions();
    my $data;
    if ($mountOpts) {
        $mountOpts .= ',' . $this -> __getFSMntOptions();
        $mountOpts =~ s/^,//smx;
        $data= KIWIQX::qxx ("mount -t $fsT -o $mountOpts $device $mntPnt 2>&1");
    } else {
        $data= KIWIQX::qxx ("mount -t $fsT $device $mntPnt 2>&1");
    }
    my $code = $? >> 8;
    if ($code != 0) {
        chomp $data;
        my $msg = "Could not mount device '$device' on '$mntPnt'";
        $kiwi -> error($msg);
        $kiwi -> failed();
        $kiwi -> error($data);
        return;
    }
    return $mntPnt;
}

#==========================================
# p_removeMountPoint
#------------------------------------------
sub p_removeDirectory {
    # ---
    # Remove the given directory
    # TODO: Should eventually end up on Globals
    # ---
    my $this   = shift;
    my $target = shift;
    my $locator = KIWILocator -> instance();
    my $rm = $locator -> getExecPath('rm');
    my $data= KIWIQX::qxx ("$rm -rf $target");
    my $code = $? >> 8;
    if ($code != 0) {
        my $kiwi = $this->{kiwi};
        my $msg = "Could not remove given directory: '$target'";
        $kiwi -> error($msg);
        $kiwi -> failed();
        $kiwi -> error($data);
        return;
    }

    return 1;
}

#==========================================
# p_umount
#------------------------------------------
sub p_umount {
    # ...
    # Unmount device at given mount point
    # ---
    my $this   = shift;
    my $mntPnt = shift;
    my $kiwi = $this->{kiwi};
    my $locator = KIWILocator -> instance();
    my $umount = $locator -> getExecPath('umount');
    if (! $umount) {
        my $msg = 'Could not find umount command. Your system is in an '
          . 'inconsistent state. To determine the extra mounts created by '
          . "kiwi. Check for $mntPnt";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $data = KIWIQX::qxx ("$umount $mntPnt");
    my $code = $? >> 8;
    if ($code != 0) {
        my $msg = "Could not unmount device connected to mount point '$mntPnt'";
        $kiwi -> error($msg);
        $kiwi -> failed();
        $kiwi -> error($data);
        return;
    }

    return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __convertToBytes
#------------------------------------------
sub __convertToBytes {
    # ...
    # Convert the given number into bytes based on the given unit
    # ---
    my $this = shift;
    my $size = shift;
    my $unit = shift;
    my $kiwi = $this->{kiwi};
    if (! $size) {
        my $msg = 'KIWIFilesystemBuilder:__convertToBytes called without '
            . 'size argument. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    if (! $unit) {
        my $msg = 'KIWIFilesystemBuilder:__convertToBytes called without '
            . 'unit argument. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    my $specSize = int $size;
    # Might overflow on 32 bit build systems with large image specifications
    if ($unit eq 'M') {
        $specSize *= $BKILO * $BKILO;
    } elsif ($unit eq 'G') {
        $specSize *= $BKILO * $BKILO * $BKILO;
    } elsif ($unit eq 'T') {
        $specSize *= $BKILO * $BKILO * $BKILO * $BKILO;
    }
    return $specSize;
}

#==========================================
# __convertBytesToMB
#------------------------------------------
sub __convertBytesToMB {
    # ...
    # Convert the given size in bytes to mega bytes
    # ---
    my $this = shift;
    my $size = shift;
    if (! $size) {
        my $kiwi = $this->{kiwi};
        my $msg = 'KIWIFilesystemBuilder:__convertBytesToMB called without '
            . 'size argument. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    return (int $size/ ($BKILO * $BKILO));
}

#==========================================
# __getFSMntOptions
#------------------------------------------
sub __getFSMntOptions {
    # ...
    # Return mount options required by the sepcific file system if they exist
    # ---
    my $this = shift;
    if ($this->{mountOpts}) {
        return $this->{mountOpts};
    }
    return q{};
}

1;
