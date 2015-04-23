#================
# FILE          : KIWIExtBuilderBase.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2015 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Build an ext2 based filesystem image
#               :
# STATUS        : Development
#----------------
package KIWIExtBuilderBase;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

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

use base qw /KIWIFilesystemBuilderBase/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIExtBuilderBase object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    if (! $this) {
        return;
    }
    $this->{fsohead} = 1.4;
    $this->{inodeFact} = 2;
    return $this;
}

#==========================================
# createFileSystem
#------------------------------------------
sub createFileSystem {
    # ...
    # Create the file system on the given device
    # ---
    my $this   = shift;
    my $device = shift;
    my $sizeInfo = shift;
    my $kiwi = $this->{kiwi};
    if (! $device) {
        my $msg = 'KIWIEXTBuilder:__createFileSystem called without '
            . 'device argument. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    if (! -b $device) {
        my $msg = 'KIWIEXTBuilder:__createFileSystem given device is '
            . 'not a block device. Internal error please file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    if (! $sizeInfo) {
        my $msg = 'KIWIEXTBuilder:__createFileSystem called without '
            . 'filesystem size info argument. Internal error please '
            . 'file a bug.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    my $cmdL = $this->{cmdL};
    my $fsopts = $cmdL -> getFilesystemOptions();
    my $createArgs = ' -t ' . $this -> p_getFilesystemType()
        . q{ } . $fsopts -> getOptionsStrExt()
        . ' -N ' . $sizeInfo->{inodeCnt};
    my $label = $this -> getLabel();
    if ($label) {
        $createArgs .= ' -L ' . $label;
    }
    my $locator = KIWILocator -> instance();
    my $fsTool = $locator -> getExecPath('mkfs');
    if (! $fsTool) {
        my $msg = 'KIWIEXTBuilder filesystem creation failed could not '
            . ' find mkfs';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    my $data = KIWIQX::qxx ("$fsTool $createArgs $device 2>&1");
    my $code = $? >> 8;
    if ($code != 0) {
        my $msg = 'KIWIEXTBuilder filesystem creation failed';
        $kiwi -> error($msg);
        $kiwi -> loginfo($data);
        $kiwi -> failed();
    }
    my $xml = $this->{xml};
    my $tuneopts = $fsopts -> getTuneOptsExt();
    my $fsnochk = $xml -> getImageType() -> getFSNoCheck();
    if ($fsnochk && $fsnochk eq 'true') {
        $tuneopts .= ' -c 0 -i 0';
    }
    if ($tuneopts) {
        my $tuneTool = $locator -> getExecPath('tune2fs');
        $data = KIWIQX::qxx ("$tuneTool $tuneopts $device 2>&1");
        $code = $? >> 8;
        if ($code != 0) {
            my $msg = 'KIWIEXTBuilder applying filsystem tuning options '
              . 'failed.';
            $kiwi -> error($msg);
            $kiwi -> loginfo($data);
            $kiwi -> failed();
        }
    }
    return 1;
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
    my $cmdL = $this->{cmdL};
    my $status = 1; # assume success
    #==========================================
    # create the root directory
    #------------------------------------------
    my $targetDir = $this -> p_createBuildDir();
    if (! $targetDir) {
        return;
    }
    #==========================================
    # apply user configuration
    #------------------------------------------
    $status = $this -> p_runUserImageScript();
    if (! $status) {
        return;
    }
    #==========================================
    # figure out the file system size and filesystem settings
    #------------------------------------------
    my $minImgSizeB = $this -> p_calculateMinImageSize();
    my $imgSizeInfo = $this -> p_determineImageSize($minImgSizeB);
    my $blockInfo = $this -> p_getBlockData($imgSizeInfo);
    #==========================================
    # setup the block device for the filesystem
    #------------------------------------------
    my $device = $this -> p_getBlockDevice($blockInfo);
    if (! $device) {
        return;
    }
    #==========================================
    # encrypt the device
    #------------------------------------------
    $status = $this -> p_encryptDevice($device);
    if (! $status) {
        return;
    }
    #==========================================
    # create the file system
    #------------------------------------------
    $status = $this -> createFileSystem($device, $imgSizeInfo);
    #==========================================
    # Mount the file system
    #------------------------------------------
    my $mountPnt = $this -> p_mountDevice($device, $targetDir);
    if (! $mountPnt) {
        return;
    }
    #==========================================
    # copy the unpacked root tree to the target
    #------------------------------------------
    $status = $this -> p_copyUnpackedTreeContent($mountPnt);
    if (! $status) {
        return;
    }
    #==========================================
    # Unmount the device file
    #------------------------------------------
    $status = $this -> p_umount($mountPnt);
    if (! $status) {
        return;
    }
    $status = $this -> p_removeDirectory($mountPnt);
    #==========================================
    # create a checksum file for the container
    #------------------------------------------
    $status = $this -> p_createChecksumFiles();
    if (! $status) {
        return;
    }
    # Create the links see KIWIIMage line 4560
    # move the files
    # done?
    return $this -> p_getCreatedFiles();
}

#==========================================
# getLabel
#------------------------------------------
sub getLabel {
    # ...
    # Return the label value for the file system
    # ---
    my $this = shift;
    return $this->{label};
}

#==========================================
# setLabel
#------------------------------------------
sub setLabel {
    # ...
    # Set the label to be used for the file system
    # ---
    my $this = shift;
    my $label = shift;
    if (! $label) {
        my $kiwi = $this->{kiwi};
        my $msg = 'KIWIEXTBuilder:setLabel called without argument, '
            . 'retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
    }
    $this->{label} = $label;
    return $this;
}

#==========================================
# Protected helper methods
#------------------------------------------
#==========================================
# p_filesysSizingAdjustment
#------------------------------------------
sub p_filesysSizingAdjustment {
    # ...
    # Return a size adjustment for this file system
    # ---
    my $this = shift;
    my $cmdL    = $this->{cmdL};
    my $uPckImg = $this->{uPckImg};
    my $fsopts = $cmdL -> getFilesystemOptions();
    my $inodeSize = $fsopts -> getInodeSize();
    my $numInodes = $uPckImg -> getNumInodes();
    return (int $numInodes * 2 * int $inodeSize);
}

1;
