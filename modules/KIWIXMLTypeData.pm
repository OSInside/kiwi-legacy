#================
# FILE          : KIWIXMLTypeData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <type> element.
#               :
#               : The type has no reference to any child objects, such
#               : as <pxedeploy> or <systemdisk>. The parent - child
#               : relationship is a construct at the XML data structure level.
#               : This design eliminates lengthy call chains such as
#               : XML -> type -> config -> getSomething
#               :
# STATUS        : Development
#----------------
package KIWIXMLTypeData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Readonly;
use XML::LibXML;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
use base qw /KIWIXMLDataBase/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constants
#------------------------------------------
Readonly my $NEXT_UNIT => 1024;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIXMLTypeData object
    #
    # Internal data structure
    #
    # this = {
    #     boot                   = ''
    #     bootfilesystem         = ''
    #     bootkernel             = ''
    #     bootloader             = ''
    #     bootpartition          = ''
    #     bootpartsize           = ''
    #     bootprofile            = ''
    #     boottimeout            = ''
    #     checkprebuilt          = ''
    #     compressed             = ''
    #     devicepersistency      = ''
    #     editbootconfig         = ''
    #     editbootinstall        = ''
    #     filesystem             = ''
    #     firmware               = ''
    #     flags                  = ''
    #     format                 = ''
    #     formatoptions          = ''
    #     fsmountoptions         = ''
    #     zfsoptions             = ''
    #     fsnocheck              = ''
    #     fsreadonly             = ''
    #     fsreadwrite            = ''
    #     gcelicense             = ''
    #     hybrid                 = ''
    #     hybridpersistent       = ''
    #     image                  = ''
    #     installboot            = ''
    #     installiso             = ''
    #     installprovidefailsafe = ''
    #     installpxe             = ''
    #     installstick           = ''
    #     kernelcmdline          = ''
    #     luks                   = ''
    #     luksOS                 = ''
    #     mdraid                 = ''
    #     primary                = ''
    #     ramonly                = ''
    #     size                   = ''
    #     sizeadd                = ''
    #     sizeunit               = ''
    #     target_blocksize       = ''
    #     vga                    = ''
    #     vhdfixedtag            = ''
    #     volid                  = ''
    #     wwid_wait_timeout      = ''
    #     zipl_targettype        = ''
    # }
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    #==========================================
    # Module Parameters
    #------------------------------------------
    my $init = shift;
    #==========================================
    # Argument checking and object data store
    #------------------------------------------
    if (! $this -> p_hasInitArg($init) ) {
        return;
    }
    # While <ec2config>, <machine>, <oemconfig>, <pxedeploy>, <split>,
    # <vagrantconfig> and <systemdisk> are children of <type> the data
    # is not in this class the child relationship is enforced at the
    # XML level.
    my %keywords = map { ($_ => 1) } qw(
        boot
        bootfilesystem
        bootkernel
        bootloader
        bootpartition
        bootpartsize
        bootprofile
        boottimeout
        checkprebuilt
        compressed
        container
        devicepersistency
        editbootconfig
        editbootinstall
        filesystem
        firmware
        flags
        format
        formatoptions
        fsmountoptions
        zfsoptions
        fsnocheck
        fsreadonly
        fsreadwrite
        gcelicense
        hybrid
        hybridpersistent
        hybridpersistent_filesystem
        image
        installboot
        installiso
        installprovidefailsafe
        installpxe
        installstick
        kernelcmdline
        luks
        luksOS
        mdraid
        primary
        ramonly
        size
        sizeadd
        sizeunit
        target_blocksize
        vga
        vhdfixedtag
        volid
        wwid_wait_timeout
        zipl_targettype
    );
    $this->{supportedKeywords} = \%keywords;
    my %boolKW = map { ($_ => 1) } qw(
        checkprebuilt
        bootpartition
        compressed
        fsnocheck
        hybrid
        hybridpersistent
        installiso
        installprovidefailsafe
        installpxe
        installstick
        primary
        ramonly
        sizeadd
    );
    $this->{boolKeywords} = \%boolKW;
    if (! $this -> p_isInitHashRef($init) ) {
        return;
    }
    if (! $this -> p_areKeywordArgsValid($init) ) {
        return;
    }
    if (! $this -> __isInitConsistent($init)) {
        return;
    }
    $this -> p_initializeBoolMembers($init);
    $this->{boot}                   = $init->{boot};
    $this->{bootfilesystem}         = $init->{bootfilesystem};
    $this->{bootkernel}             = $init->{bootkernel};
    $this->{bootloader}             = $init->{bootloader};
    $this->{zipl_targettype}        = $init->{zipl_targettype};
    $this->{bootpartsize}           = $init->{bootpartsize};
    $this->{bootprofile}            = $init->{bootprofile};
    $this->{boottimeout}            = $init->{boottimeout};
    $this->{container}              = $init->{container};
    $this->{devicepersistency}      = $init->{devicepersistency};
    $this->{editbootconfig}         = $init->{editbootconfig};
    $this->{editbootinstall}        = $init->{editbootinstall};
    $this->{filesystem}             = $init->{filesystem};
    $this->{firmware}               = $init->{firmware};
    $this->{flags}                  = $init->{flags};
    $this->{format}                 = $init->{format};
    $this->{formatoptions}          = $init->{formatoptions};
    $this->{fsmountoptions}         = $init->{fsmountoptions};
    $this->{gcelicense}             = $init->{gcelicense};
    $this->{fsreadonly}             = $init->{fsreadonly};
    $this->{fsreadwrite}            = $init->{fsreadwrite};
    $this->{hybridpersistent_filesystem} =
        $init->{hybridpersistent_filesystem};
    $this->{image}                  = $init->{image};
    $this->{installboot}            = $init->{installboot};
    $this->{kernelcmdline}          = $init->{kernelcmdline};
    $this->{luks}                   = $init->{luks};
    $this->{luksOS}                 = $init->{luksOS};
    $this->{mdraid}                 = $init->{mdraid};
    $this->{size}                   = $init->{size};
    $this->{sizeadd}                = $init->{sizeadd};
    $this->{sizeunit}               = $init->{sizeunit};
    $this->{vga}                    = $init->{vga};
    $this->{vhdfixedtag}            = $init->{vhdfixedtag};
    $this->{volid}                  = $init->{volid};
    $this->{wwid_wait_timeout}      = $init->{wwid_wait_timeout};
    $this->{target_blocksize}       = $init->{target_blocksize};
    $this->{zfsoptions}             = $init->{zfsoptions};
    # Set default values
    if (! $init->{bootloader} ) {
        $this->{bootloader} = 'grub';
        $this->{defaultBootloader} = 1;
    }
    if (! $init->{installprovidefailsafe} ) {
        $this->{installprovidefailsafe} = 'true';
        $this->{defaultinstallprovidefailsafe} = 1;
    }
    if (! $init->{firmware} ) {
        $this->{firmware} = 'bios';
        $this->{defaultfirmware} = 1;
    }
    if (! $init->{primary} ) {
        $this->{defaultprimary} = 1;
    }
    if (! $init->{sizeadd} ) {
        $this->{sizeadd} = 'false';
        $this->{defaultsizeadd} = 1;
    }
    if (! $init->{sizeunit} ) {
        $this->{sizeunit} = 'M';
        $this->{defaultsizeunit} = 1;
    }
    return $this;
}

#==========================================
# getBootImageDescript
#------------------------------------------
sub getBootImageDescript {
    # ...
    # Return the configured boot image description
    # ---
    my $this = shift;
    return $this->{boot};
}

#==========================================
# getBootImageFileSystem
#------------------------------------------
sub getBootImageFileSystem {
    # ...
    # Return the option configured for the boot filesystem
    # ---
    my $this = shift;
    return $this->{bootfilesystem};
}

#==========================================
# getBootKernel
#------------------------------------------
sub getBootKernel {
    # ...
    # Return the configured bootkernel
    # ---
    my $this = shift;
    return $this->{bootkernel};
}

#==========================================
# getBootLoader
#------------------------------------------
sub getBootLoader {
    # ...
    # Return the configured bootloader
    # ---
    my $this = shift;
    return $this->{bootloader};
}

#==========================================
# getZiplTargetType
#------------------------------------------
sub getZiplTargetType {
    # ...
    # Return the configured zypl target type
    # ---
    my $this = shift;
    return $this->{zipl_targettype};
}

#==========================================
# getTargetBlockSize
#------------------------------------------
sub getTargetBlockSize {
    # ...
    # Return the configured target blocksize
    # ---
    my $this = shift;
    return $this->{target_blocksize};
}

#==========================================
# getBootPartitionSize
#------------------------------------------
sub getBootPartitionSize {
    # ...
    # Return the configured bootpartition size
    # ---
    my $this = shift;
    my $size;
    if ($this->{bootpartsize}) {
        $size = int $this->{bootpartsize};
    }
    return $size;
}

#==========================================
# getBootPartition
#------------------------------------------
sub getBootPartition {
    # ...
    # Return the configuration for the setup of a bootpartition
    # ---
    my $this = shift;
    return $this->{bootpartition};
}

#==========================================
# getBootProfile
#------------------------------------------
sub getBootProfile {
    # ...
    # Return the configured bootprofile
    # ---
    my $this = shift;
    return $this->{bootprofile};
}

#==========================================
# getBootTimeout
#------------------------------------------
sub getBootTimeout {
    # ...
    # Return the configured boot timeout
    # ---
    my $this = shift;
    return $this->{boottimeout};
}

#==========================================
# getWWIDWaitTimeout
#------------------------------------------
sub getWWIDWaitTimeout {
    my $this = shift;
    return $this->{wwid_wait_timeout};
}

#==========================================
# getCheckPrebuilt
#------------------------------------------
sub getCheckPrebuilt {
    # ...
    # Return the configuration for the pre built boot image check
    # ---
    my $this = shift;
    return $this->{checkprebuilt};
}

#==========================================
# getCompressed
#------------------------------------------
sub getCompressed {
    # ...
    # Return the configuration for compressed image generation
    # ---
    my $this = shift;
    return $this->{compressed};
}

#==========================================
# getContainerName
#------------------------------------------
sub getContainerName {
    # ...
    # Return the configuration for the container name
    # ---
    my $this = shift;
    return $this->{container};
}


#==========================================
# getDevicePersistent
#------------------------------------------
sub getDevicePersistent {
    # ...
    # Return the configuration for the device persistency method
    # ---
    my $this = shift;
    return $this->{devicepersistency};
}

#==========================================
# getEditBootConfig
#------------------------------------------
sub getEditBootConfig {
    # ...
    # Return the path to the script to modify the boot configuration
    # ---
    my $this = shift;
    return $this->{editbootconfig};
}

#==========================================
# getEditBootInstall
#------------------------------------------
sub getEditBootInstall {
    # ...
    # Return the path to the script to modify the boot configuration
    # ---
    my $this = shift;
    return $this->{editbootinstall};
}

#==========================================
# getFilesystem
#------------------------------------------
sub getFilesystem {
    # ...
    # Return the configured filesystem
    # ---
    my $this = shift;
    return $this->{filesystem};
}

#==========================================
# getFirmwareType
#------------------------------------------
sub getFirmwareType {
    # ...
    # Return the configured firmware type
    # ---
    my $this = shift;
    return $this->{firmware};
}

#==========================================
# getFlags
#------------------------------------------
sub getFlags {
    # ...
    # Return the configuration for the fags setting
    # ---
    my $this = shift;
    return $this->{flags};
}

#==========================================
# getFormat
#------------------------------------------
sub getFormat {
    # ...
    # Return the format for the virtual image
    # ---
    my $this = shift;
    return $this->{format};
}

#==========================================
# getFormatOptions
#------------------------------------------
sub getFormatOptions {
    # ...
    # Return the format options for the virtual image format
    # ---
    my $this = shift;
    return $this->{formatoptions};
}

#==========================================
# getFSMountOptions
#------------------------------------------
sub getFSMountOptions {
    # ...
    # Return the file system mount options
    # ---
    my $this = shift;
    return $this->{fsmountoptions};
}

#==========================================
# getZFSOptions
#------------------------------------------
sub getZFSOptions {
    # ...
    # Return the ZFS filesystem pool options
    # ---
    my $this = shift;
    return $this->{zfsoptions};
}

#==========================================
# getFSNoCheck
#------------------------------------------
sub getFSNoCheck {
    # ...
    # Return the value for the fscheck flag
    # ---
    my $this = shift;
    return $this->{fsnocheck};
}

#==========================================
# getFSReadOnly
#------------------------------------------
sub getFSReadOnly {
    # ...
    # Return the filesystem for read only access
    # ---
    my $this = shift;
    return $this->{fsreadonly};
}

#==========================================
# getFSReadWrite
#------------------------------------------
sub getFSReadWrite {
    # ...
    # Return the filesystem for read write access
    # ---
    my $this = shift;
    return $this->{fsreadwrite};
}

#==========================================
# getHybrid
#------------------------------------------
sub getHybrid {
    # ...
    # Return the flag value to indicate a hybrid image
    # ---
    my $this = shift;
    return $this->{hybrid};
}

#==========================================
# getHybridPersistent
#------------------------------------------
sub getHybridPersistent {
    # ...
    # Return the flag value indicating whether or not persistent storage
    # is included in the hybrid image
    # ---
    my $this = shift;
    return $this->{hybridpersistent};
}

#==========================================
# getHybridPersistentFileSystem
#------------------------------------------
sub getHybridPersistentFileSystem {
    # ...
    # Return the flag value indicating which filesystem should be
    # use for persistent writing on a hybrid capable ISO image
    # ---
    my $this = shift;
    return $this->{hybridpersistent_filesystem};
}

#==========================================
# getInstallBoot
#------------------------------------------
sub getInstallBoot {
    # ...
    # Return the option configured for the initial boot selection
    # ---
    my $this = shift;
    return $this->{installboot};
}

#==========================================
# getInstallProvideFailsafe
#------------------------------------------
sub getInstallProvideFailsafe {
    # ...
    # Return the value indicating whether the boot menu should have a
    # failsfe entry or not
    # ---
    my $this = shift;
    return $this->{installprovidefailsafe}
}

#==========================================
# getInstallIso
#------------------------------------------
sub getInstallIso {
    # ...
    # Return the value indicating whether or not an ISO image should be
    # created as install media
    # ---
    my $this = shift;
    return $this->{installiso};
}

#==========================================
# getInstallStick
#------------------------------------------
sub getInstallStick {
    # ...
    # Return the value indicating whether or not an USB stick image
    # should be created for installation
    # ---
    my $this = shift;
    return $this->{installstick};
}

#==========================================
# getInstallPXE
#------------------------------------------
sub getInstallPXE {
    # ...
    # Return the value indicating whether or not all data required
    # for an oem PXE installation should be created as install set
    # ---
    my $this = shift;
    return $this->{installpxe};
}

#==========================================
# getKernelCmdOpts
#------------------------------------------
sub getKernelCmdOpts {
    # ...
    # Return the configured kernel command line options
    # ---
    my $this = shift;
    return $this->{kernelcmdline};
}

#==========================================
# getLuksPass
#------------------------------------------
sub getLuksPass {
    # ...
    # Return the configured luks password for the filesystem encryption
    # ---
    my $this = shift;
    return $this->{luks};
}

#==========================================
# getLuksOS
#------------------------------------------
sub getLuksOS {
    # ...
    # Return the configured luks target operating system name
    # ---
    my $this = shift;
    return $this->{luksOS};
}

#==========================================
# getMDRaid
#------------------------------------------
sub getMDRaid {
    # ...
    # Return the software raid type
    # ---
    my $this = shift;
    return $this->{mdraid};
}

#==========================================
# getPrimary
#------------------------------------------
sub getPrimary {
    # ...
    # Return the flag indicating if this type is marked default
    # ---
    my $this = shift;
    return $this->{primary};
}

#==========================================
# getRAMOnly
#------------------------------------------
sub getRAMOnly {
    # ...
    # Return the flag indicating whether overlay file system writes
    # take place in RAM only
    # ---
    my $this = shift;
    return $this->{ramonly};
}

#==========================================
# getSize
#------------------------------------------
sub getSize {
    # ...
    # Return the systemsize for this type
    # ---
    my $this = shift;
    my $size;
    if ($this->{size}) {
        $size = int $this->{size};
    }
    return $size;
}

#==========================================
# getImageSize
#------------------------------------------
sub getImageSize {
    # ...
    # return a size string with unit or the string 'auto'
    # ---
    my $this = shift;
    my $size = $this -> getSize();
    my $unit = $this -> getSizeUnit();
    if ($size) {
        if (! $this -> isSizeAdditive()) {
            # /.../
            # a fixed size value was set, we will use this value
            # connected with the unit string
            # ----
            if (! $unit) {
                # no unit specified assume MB...
                $unit = 'M';
            }
            return $size.$unit;
        } else {
            # /.../
            # the size is setup as additive value to the required
            # size. The real size is calculated later and the additive
            # value is added at that point
            # ---
            return 'auto';
        }
    }
    return 'auto';
}

#==========================================
# getImageSizeBytes
#------------------------------------------
sub getImageSizeBytes {
    # ...
    # return a size byte value or 'auto'
    # ---
    my $this = shift;
    my $size = $this -> getImageSize();
    if ($size eq 'auto') {
        return $size;
    }
    return $this -> __byteValue (
        $this -> getSize(),
        $this -> getSizeUnit()
    );
}

#==========================================
# getImageSizeAdditiveBytes
#------------------------------------------
sub getImageSizeAdditiveBytes {
    # ...
    # return the size byte value if the additive
    # attribute is set to true, otherwise return
    # zero
    # ---
    my $this = shift;
    my $size = $this -> getSize();
    if (! $this -> isSizeAdditive()) {
        return 0;
    }
    if ($size) {
        return $this -> __byteValue (
            $size, $this -> getSizeUnit()
        );
    }
    return 0;
}

#==========================================
# getSizeUnit
#------------------------------------------
sub getSizeUnit {
    # ...
    # Return the systemsize for this type
    # ---
    my $this = shift;
    return $this->{sizeunit};
}

#==========================================
# getTypeName
#------------------------------------------
sub getTypeName {
    # ...
    # Return the image type
    # ---
    my $this = shift;
    return $this->{image};
}

#==========================================
# getVGA
#------------------------------------------
sub getVGA {
    # ...
    # Return the vga settings for the kernel command line
    # ---
    my $this = shift;
    return $this->{vga};
}

#==========================================
# getVHDFixedTag
#------------------------------------------
sub getVHDFixedTag {
    # ...
    # Return the VHD fixed tag for a fixed-vhd formated image
    # ---
    my $this = shift;
    return $this->{vhdfixedtag};
}

#==========================================
# getGCELicense
#------------------------------------------
sub getGCELicense {
    # ...
    # Return the GCE license information for a gce formated image
    # ---
    my $this = shift;
    return $this->{gcelicense};
}

#==========================================
# getVolID
#------------------------------------------
sub getVolID {
    # ...
    # Return the volume ID for an ISO image
    # ---
    my $this = shift;
    return $this->{volid};
}

#==========================================
# isSizeAdditive
#------------------------------------------
sub isSizeAdditive {
    # ...
    # Return indication whether the size for this type is additive or not
    # ---
    my $this = shift;
    my $added = $this->{sizeadd};
    if (! $added) {
        return 0;
    }
    if (($added eq 'false') || ($added eq '0')) {
        return 0;
    }
    return 1;
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
    # ...
    # Return an XML Element representing the object's data
    # ---
    my $this = shift;
    my $element = XML::LibXML::Element -> new('type');
    $element -> setAttribute('image', $this -> getTypeName());
    my $bootIm = $this -> getBootImageDescript();
    if ($bootIm) {
        $element -> setAttribute('boot', $bootIm);
    }
    my $bootFS = $this -> getBootImageFileSystem();
    if ($bootFS) {
        $element -> setAttribute('bootfilesystem', $bootFS);
    }
    my $bootK = $this -> getBootKernel();
    if ($bootK) {
        $element -> setAttribute('bootkernel', $bootK);
    }
    if (! $this->{defaultBootloader}) {
        my $loader = $this -> getBootLoader();
        if ($loader) {
            $element -> setAttribute('bootloader', $loader);
        }
    }
    my $target_blocksize = $this -> getTargetBlockSize();
    if ($target_blocksize) {
        $element -> setAttribute('target_blocksize', $target_blocksize);
    }
    my $zipl_targettype = $this -> getZiplTargetType();
    if ($zipl_targettype) {
        $element -> setAttribute('zipl_targettype', $zipl_targettype);
    }
    my $bPartSize = $this -> getBootPartitionSize();
    if ($bPartSize) {
        $element -> setAttribute('bootpartsize', $bPartSize);
    }
    my $bPart = $this -> getBootPartition();
    if ($bPart) {
        $element -> setAttribute('bootpartition', $bPart);
    }
    my $bProf = $this -> getBootProfile();
    if ($bProf) {
        $element -> setAttribute('bootprofile', $bProf);
    }
    my $bTime = $this -> getBootTimeout();
    if ($bTime) {
        $element -> setAttribute('boottimeout', $bTime);
    }
    my $wwidwait = $this -> getWWIDWaitTimeout();
    if ($wwidwait) {
        $element -> setAttribute('wwid_wait_timeout', $wwidwait);
    }
    my $cPreb = $this -> getCheckPrebuilt();
    if ($cPreb) {
        $element -> setAttribute('checkprebuilt', $cPreb);
    }
    my $comp = $this -> getCompressed();
    if ($comp) {
        $element -> setAttribute('compressed', $comp);
    }
    my $container = $this -> getContainerName();
    if ($container) {
        $element -> setAttribute('container', $container);
    }
    my $devPer = $this -> getDevicePersistent();
    if ($devPer) {
        $element -> setAttribute('devicepersistency', $devPer);
    }
    my $eBootConf = $this -> getEditBootConfig();
    if ($eBootConf) {
        $element -> setAttribute('editbootconfig', $eBootConf);
    }
    my $eBootInst = $this -> getEditBootInstall();
    if ($eBootInst) {
        $element -> setAttribute('editbootinstall', $eBootInst);
    }
    my $fileSys = $this -> getFilesystem();
    if ($fileSys) {
        $element -> setAttribute('filesystem', $fileSys);
    }
    if (! $this->{defaultfirmware}) {
        my $firmware = $this -> getFirmwareType();
        if ($firmware) {
            $element -> setAttribute('firmware', $firmware);
        }
    }
    my $flags = $this -> getFlags();
    if ($flags) {
        $element -> setAttribute('flags', $flags);
    }
    my $format = $this -> getFormat();
    if ($format) {
        $element -> setAttribute('format', $format);
    }
    my $formatoptions = $this -> getFormatOptions();
    if ($formatoptions) {
        $element -> setAttribute('formatoptions', $formatoptions);
    }
    my $fsOpts = $this -> getFSMountOptions();
    if ($fsOpts) {
        $element -> setAttribute('fsmountoptions', $fsOpts);
    }
    my $zfsOpts = $this -> getZFSOptions();
    if ($zfsOpts) {
        $element -> setAttribute('zfsoptions',$zfsOpts);
    }
    my $fsnoch = $this -> getFSNoCheck();
    if ($fsnoch) {
        $element -> setAttribute('fsnocheck', $fsnoch);
    }
    my $fsRO = $this -> getFSReadOnly();
    if ($fsRO) {
        $element -> setAttribute('fsreadonly', $fsRO);
    }
    my $fsRW = $this -> getFSReadWrite();
    if ($fsRW) {
        $element -> setAttribute('fsreadwrite', $fsRW);
    }
    my $hybrid = $this -> getHybrid();
    if ($hybrid) {
        $element -> setAttribute('hybrid', $hybrid);
    }
    my $hybridP = $this -> getHybridPersistent();
    if ($hybridP) {
        $element -> setAttribute('hybridpersistent', $hybridP);
    }
    my $hybridFS = $this -> getHybridPersistentFileSystem();
    if ($hybridFS) {
        $element -> setAttribute('hybridpersistent_filesystem', $hybridFS);
    }
    my $instBoot = $this -> getInstallBoot();
    if ($instBoot) {
        $element -> setAttribute('installboot', $instBoot);
    }
    my $instIso = $this -> getInstallIso();
    if ($instIso) {
        $element -> setAttribute('installiso', $instIso);
    }
    if (! $this->{defaultinstallprovidefailsafe}) {
        my $instFail = $this -> getInstallProvideFailsafe();
        if ($instFail) {
            $element -> setAttribute('installprovidefailsafe', $instFail);
        }
    }
    my $instPXE = $this -> getInstallPXE();
    if ($instPXE) {
        $element -> setAttribute('installpxe', $instPXE);
    }
    my $instSt = $this -> getInstallStick();
    if ($instSt) {
        $element -> setAttribute('installstick', $instSt);
    }
    my $kernC = $this -> getKernelCmdOpts();
    if ($kernC) {
        $element -> setAttribute('kernelcmdline', $kernC);
    }
    my $luks = $this -> getLuksPass();
    if ($luks) {
        $element -> setAttribute('luks', $luks);
    }
    my $luksOS = $this -> getLuksOS();
    if ($luksOS) {
        $element -> setAttribute('luksOS', $luksOS);
    }
    my $mdraid = $this -> getMDRaid();
    if ($mdraid) {
        $element -> setAttribute('mdraid',$mdraid);
    }
    if (! $this->{defaultprimary}) {
        my $prim = $this -> getPrimary();
        if ($prim) {
            $element -> setAttribute('primary', $prim);
        }
    }
    my $ramO = $this -> getRAMOnly();
    if ($ramO) {
        $element -> setAttribute('ramonly', $ramO);
    }
    my $size = $this -> getSize();
    if ($size) {
        my $sElem = XML::LibXML::Element -> new('size');
        $sElem -> appendText($size);
        if (! $this->{defaultsizeadd}) {
            my $additive = 'false';
            if ($this -> isSizeAdditive()) {
                $additive = 'true';
            }
            $sElem -> setAttribute('additive', $additive);
        }
        if (! $this->{defaultsizeunit}) {
            $sElem -> setAttribute('unit', $this -> getSizeUnit());
        }
        $element -> appendChild($sElem);
    }
    my $vga = $this -> getVGA();
    if ($vga) {
        $element -> setAttribute('vga', $vga);
    }
    my $vhdfixedtag = $this -> getVHDFixedTag();
    if ($vhdfixedtag) {
        $element -> setAttribute('vhdfixedtag', $vhdfixedtag);
    }
    my $gcelicense = $this -> getGCELicense();
    if ($gcelicense) {
        $element -> setAttribute('gcelicense', $gcelicense);
    }
    my $volid = $this -> getVolID();
    if ($volid) {
        $element -> setAttribute('volid', $volid);
    }
    return $element;
}

#==========================================
# setBootImageDescript
#------------------------------------------
sub setBootImageDescript {
    # ...
    # Set the configuration for the boot image description
    # ---
    my $this  = shift;
    my $bootD = shift;
    if (! $bootD ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setBootImageDescript: no boot description given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{boot} = $bootD;
    return $this;
}

#==========================================
# setBootImageFileSystem
#------------------------------------------
sub setBootImageFileSystem {
    # ...
    # Set the option configuration for the boot filesystem
    # ---
    my $this = shift;
    my $opt  = shift;
    if (! $this -> __isValidBootFS($opt, 'setBootImageFileSystem') ) {
        return;
    }
    $this->{bootfilesystem} = $opt;
    return $this;
}

#==========================================
# setBootKernel
#------------------------------------------
sub setBootKernel {
    # ...
    # Set the configuration for the bootkernel
    # ---
    my $this  = shift;
    my $bootK = shift;
    if (! $bootK ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setBootKernel: no boot kernel given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{bootkernel} = $bootK;
    return $this;
}

#==========================================
# setBootLoader
#------------------------------------------
sub setBootLoader {
    # ...
    # Set the configuration for the  bootloader
    # ---
    my $this  = shift;
    my $bootL = shift;
    if (! $this -> __isValidBootloader($bootL, 'setBootLoader') ) {
        return;
    }
    $this->{bootloader} = $bootL;
    return $this;
}

#==========================================
# setZiplTargetType
#------------------------------------------
sub setZiplTargetType {
    # ...
    # Set the configuration for the zipl target type
    # ---
    my $this  = shift;
    my $zipl_type = shift;
    if (! $this -> __isValidZiplTargetType($zipl_type, 'setZiplTargetType')) {
        return;
    }
    $this->{zipl_targettype} = $zipl_type;
    return $this;
}

#==========================================
# setTargetBlockSize
#------------------------------------------
sub setTargetBlockSize {
    # ...
    # Set the configuration for the target blocksize
    # ---
    my $this  = shift;
    my $target_blocksize = shift;
    if (! $target_blocksize ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setTargetBlockSize: no blocksize given, retaining current '
            . 'data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{target_blocksize} = $target_blocksize;
    return $this;
}

#==========================================
# setBootPartitionSize
#------------------------------------------
sub setBootPartitionSize {
    # ...
    # Set the configuration for the  bootpartition size
    # ---
    my $this = shift;
    my $size = shift;
    if (! $size ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setBootPartitionSize: no size given, retaining current '
            . 'data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{bootpartsize} = $size;
    return $this;
}

#==========================================
# setBootPartition
#------------------------------------------
sub setBootPartition {
    # ...
    # Set the configuration for the use of a bootpartition
    # ---
    my $this = shift;
    my $bootpart = shift;
    my %settings = (
        attr   => 'bootpartition',
        value  => $bootpart,
        caller => 'setBootPartition'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setBootProfile
#------------------------------------------
sub setBootProfile {
    # ...
    # Set the configuration for the bootprofile
    # ---
    my $this = shift;
    my $prof = shift;
    if (! $prof ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setBootProfile: no profile given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{bootprofile} = $prof;
    return $this;
}

#==========================================
# setBootTimeout
#------------------------------------------
sub setBootTimeout {
    # ...
    # Set the configuration for the  boot timeout
    # ---
    my $this = shift;
    my $time = shift;
    if (! $time) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setBootTimeout: no timeout value given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{boottimeout} = $time;
    return $this;
}

#==========================================
# setWWIDWaitTimeout
#------------------------------------------
sub setWWIDWaitTimeout {
    # ...
    # Set the configuration for the wwid wait timeout
    # ---
    my $this = shift;
    my $time = shift;
    if (! $time) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setWWIDWaitTimeout: no timeout value given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{wwid_wait_timeout} = $time;
    return $this;
}

#==========================================
# setCheckPrebuilt
#------------------------------------------
sub setCheckPrebuilt {
    # ...
    # Set the configuration for the pre built boot image check
    # ---
    my $this  = shift;
    my $check = shift;
    my %settings = (
        attr   => 'checkprebuilt',
        value  => $check,
        caller => 'setCheckPrebuilt'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setCompressed
#------------------------------------------
sub setCompressed {
    # ...
    # Set the configuration for compressed image generation
    # ---
    my $this = shift;
    my $comp = shift;
    my %settings = (
        attr   => 'compressed',
        value  => $comp,
        caller => 'setCompressed'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setContainerName
#------------------------------------------
sub setContainerName {
    # ...
    # Set the container name
    # ---
    my $this = shift;
    my $name = shift;
    my $kiwi = $this->{kiwi};
    if (! $name) {
        my $msg = 'setContainerName: no container name given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if ($name =~ /\W/smx) {
        my $msg = 'setContainerName: given container name contains non word '
            . 'character, illegal name. Retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{container} = $name;
    return $this;
}

#==========================================
# setDevicePersistent
#------------------------------------------
sub setDevicePersistent {
    # ...
    # Set the configuration for the device persistency method
    # ---
    my $this = shift;
    my $devP = shift;
    if (! $this -> __isValidDevPersist($devP, 'setDevicePersistent') ) {
        return;
    }
    $this->{devicepersistency} = $devP;
    return $this;
}

#==========================================
# setEditBootConfig
#------------------------------------------
sub setEditBootConfig {
    # ...
    # Set the path to the script to modify the boot configuration
    # ---
    my $this  = shift;
    my $confE = shift;
    if (! $confE ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setEditBootConfig: no config script given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{editbootconfig} = $confE;
    return $this;
}

#==========================================
# setEditBootInstall
#------------------------------------------
sub setEditBootInstall {
    # ...
    # Set the path to the script to modify the boot configuration
    # ---
    my $this  = shift;
    my $confE = shift;
    if (! $confE ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setEditBootInstall: no config script given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{editbootinstall} = $confE;
    return $this;
}

#==========================================
# setFilesystem
#------------------------------------------
sub setFilesystem {
    # ...
    # Set the configuration for the  filesystem
    # ---
    my $this = shift;
    my $fs   = shift;
    if (! $this -> __isValidFilesystem($fs , 'setFilesystem') ) {
        return;
    }
    $this->{filesystem} = $fs;
    return $this;
}

#==========================================
# setFlags
#------------------------------------------
sub setFlags {
    # ...
    # Set the configuration for the fags setting
    # ---
    my $this  = shift;
    my $flags = shift;
    if (! $this -> __isValidFlags($flags, 'setFlags') ) {
        return;
    }
    $this->{flags} = $flags;
    return $this;
}

#==========================================
# setFormat
#------------------------------------------
sub setFormat {
    # ...
    # Set the format for the virtual image
    # ---
    my $this   = shift;
    my $format = shift;
    if (! $this -> __isValidFormat($format, 'setFormat') ) {
        return;
    }
    $this->{format} = $format;
    return $this;
}

#==========================================
# setFormatOptions
#------------------------------------------
sub setFormatOptions {
    # ...
    # Set format options for the virtual image format
    # ---
    my $this   = shift;
    my $options= shift;
    $this->{formatoptions} = $options;
    return $this;
}

#==========================================
# setFSMountOptions
#------------------------------------------
sub setFSMountOptions {
    # ...
    # Set the file system mount options
    # ---
    my $this = shift;
    my $opts = shift;
    if (! $opts ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setFSMountOptions: no mount options given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{fsmountoptions} = $opts;
    return $this;
}

#==========================================
# setZFSOptions
#------------------------------------------
sub setZFSOptions {
    # ...
    # Set the ZFS pool options
    # ---
    my $this = shift;
    my $opts = shift;
    if (! $opts ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setZFSOptions: no pool options given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{zfsoptions} = $opts;
    return $this;
}

#==========================================
# setFSNoCheck
#------------------------------------------
sub setFSNoCheck {
    # ...
    # Set the value for the fscheck flag
    # ---
    my $this  = shift;
    my $check = shift;
    my %settings = (
        attr   => 'fsnocheck',
        value  => $check,
        caller => 'setFSNoCheck'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setFSReadOnly
#------------------------------------------
sub setFSReadOnly {
    # ...
    # Set the filesystem for read only access
    # ---
    my $this = shift;
    my $fs   = shift;
    if (! $this -> __isValidFilesystem($fs , 'setFSReadOnly') ) {
        return;
    }
    $this->{fsreadonly} = $fs;
    return $this;
}

#==========================================
# setFSReadWrite
#------------------------------------------
sub setFSReadWrite {
    # ...
    # Set the filesystem for read write access
    # ---
    my $this = shift;
    my $fs   = shift;
    if (! $this -> __isValidFilesystem($fs , 'setFSReadWrite') ) {
        return;
    }
    $this->{fsreadwrite} = $fs;
    return $this;
}

#==========================================
# setHybrid
#------------------------------------------
sub setHybrid {
    # ...
    # Set the flag value to indicate a hybrid image
    # ---
    my $this   = shift;
    my $hybrid = shift;
    my %settings = (
        attr   => 'hybrid',
        value  => $hybrid,
        caller => 'setHybrid'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setHybridPersistent
#------------------------------------------
sub setHybridPersistent {
    # ...
    # Set the flag value indicating whether or not persistent storage
    # is included in the hybrid image
    # ---
    my $this = shift;
    my $hybridP = shift;
    my %settings = (
        attr   => 'hybridpersistent',
        value  => $hybridP,
        caller => 'setHybridPersistent'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setHybridPersistentFileSystem
#------------------------------------------
sub setHybridPersistentFileSystem {
    # ...
    # Set the hybrid persistent filesystem name
    # ---
    my $this = shift;
    my $opt  = shift;
    if (! $opt ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setHybridPersistentFileSystem: no options given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{hybridpersistent_filesystem} = $opt;
    return $this;
}

#==========================================
# setInstallBoot
#------------------------------------------
sub setInstallBoot {
    # ...
    # Set the option configuration for the  for the initial boot selection
    # ---
    my $this = shift;
    my $opt  = shift;
    if (! $this -> __isValidInstBoot($opt, 'setInstallBoot') ) {
        return;
    }
    $this->{installboot} = $opt;
    return $this;
}

#==========================================
# setInstallProvideFailsafe
#------------------------------------------
sub setInstallProvideFailsafe {
    # ...
    # Set the value indicating whether the boot menu should have a
    # failsfe entry or not
    # ---
    my $this  = shift;
    my $instF = shift;
    my %settings = (
        attr   => 'installprovidefailsafe',
        value  => $instF,
        caller => 'setInstallProvideFailsafe'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setInstallIso
#------------------------------------------
sub setInstallIso {
    # ...
    # Set the value indicating whether or not an ISO image should be
    # created as install media
    # ---
    my $this  = shift;
    my $instI = shift;
    my %settings = (
        attr   => 'installiso',
        value  => $instI,
        caller => 'setInstallIso'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setInstallStick
#------------------------------------------
sub setInstallStick {
    # ...
    # Set the value indicating whether or not an USB stick image
    # should be created for installation
    # ---
    my $this = shift;
    my $instS = shift;
    my %settings = (
        attr   => 'installstick',
        value  => $instS,
        caller => 'setInstallStick'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setInstallPXE
#------------------------------------------
sub setInstallPXE {
    # ...
    # Set the value indicating whether or not PXE
    # data files should be created for installation
    # ---
    my $this = shift;
    my $instP = shift;
    my %settings = (
        attr   => 'installpxe',
        value  => $instP,
        caller => 'setInstallPXE'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setKernelCmdOpts
#------------------------------------------
sub setKernelCmdOpts {
    # ...
    # Set the configuration for the  kernel command line options
    # ---
    my $this = shift;
    my $opt  = shift;
    if (! $opt ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setKernelCmdOpts: no options given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{kernelcmdline} = $opt;
    return $this;
}

#==========================================
# setFirmwareType
#------------------------------------------
sub setFirmwareType {
    # ...
    # Set the configuration for the firmware type
    # ---
    my $this = shift;
    my $opt  = shift;
    
    if (! $this -> __isValidFirmware($opt, 'setFirmwareType') ) {
        return;
    }

    $this->{firmware} = $opt;
    return $this;
}

#==========================================
# setLuksPass
#------------------------------------------
sub setLuksPass {
    # ...
    # Set the configuration for the luks password for the filesystem encryption
    # ---
    my $this = shift;
    my $pass = shift;
    if (! $pass ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setLuksPass: no password given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{luks} = $pass;
    return $this;
}

#==========================================
# setLuksOS
#------------------------------------------
sub setLuksOS {
    # ...
    # Set the configuration for the luks target distribution
    # ---
    my $this = shift;
    my $dist = shift;
    if (! $dist ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setLuksOS: no OS value given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{luksOS} = $dist;
    return $this;
}

#==========================================
# setMDRaid
#------------------------------------------
sub setMDRaid {
    # ...
    # Set software raid type
    # ---
    my $this = shift;
    my $type = shift;
    if (! $this -> __isValidRaidType($type, 'setMDRaid') ) {
        return;
    }
    $this->{mdraid} = $type;
    return $this;
}

#==========================================
# setPrimary
#------------------------------------------
sub setPrimary {
    # ...
    # Set the flag indicating if this type is marked default
    # ---
    my $this = shift;
    my $prim = shift;
    my %settings = (
        attr   => 'primary',
        value  => $prim,
        caller => 'setPrimary'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setRAMOnly
#------------------------------------------
sub setRAMOnly {
    # ...
    # Set the flag indicating whether overlay file system writes
    # take place in RAM only
    # ---
    my $this = shift;
    my $ramO = shift;
    my %settings = (
        attr   => 'ramonly',
        value  => $ramO,
        caller => 'setRAMOnly'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setSize
#------------------------------------------
sub setSize {
    # ...
    # Set the systemsize for this type
    # ---
    my $this = shift;
    my $size = shift;
    if (! $size ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setSize: no systemsize value given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{size} = int $size;
    return $this;
}

#==========================================
# setSizeAdditive
#------------------------------------------
sub setSizeAdditive {
    # ...
    # Set the flag indicating whether the size is additive or not
    # ---
    my $this = shift;
    my $add = shift;
    my %settings = (
        attr   => 'sizeadd',
        value  => $add,
        caller => 'setSizeAdditive'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setSizeUnit
#------------------------------------------
sub setSizeUnit {
    # ...
    # Set the systemsize unit of measure for this type
    # ---
    my $this = shift;
    my $unit = shift;
    my $u = $this->{sizeunit};
    if (! $this->__isValidSizeUnit($unit, 'setSizeUnit')) {
        return;
    }
    $this->{sizeunit} = $unit;
    return $this;
}

#==========================================
# setTypeName
#------------------------------------------
sub setTypeName {
    # ...
    # Set the image type
    # ---
    my $this = shift;
    my $type = shift;
    if (! $this -> __isValidImage($type, 'setTypeName') ) {
        return;
    }
    $this->{image} = $type;
    return $this;
}


#==========================================
# setVGA
#------------------------------------------
sub setVGA {
    # ...
    # Set the vga settings for the kernel command line
    # ---
    my $this = shift;
    my $vga  = shift;
    if (! $vga ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setVGA: no VGA value given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{vga} = $vga;
    return $this;
}

#==========================================
# setVHDFixedTag
#------------------------------------------
sub setVHDFixedTag {
    # ...
    # Set the VHD tag for a fixed-vhd formated image
    # ---
    my $this = shift;
    my $guid = shift;
    if (! $guid ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setVHDFixedTag: no tag given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{vhdfixedtag} = $guid;
    return $this;
}

#==========================================
# setGCELicense
#------------------------------------------
sub setGCELicense {
    # ...
    # Set the GCE license information for a gce formated image
    # ---
    my $this = shift;
    my $license = shift;
    if (! $license ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setGCELicense: no license tag given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{gcelicense} = $license;
    return $this;
}

#==========================================
# setVolID
#------------------------------------------
sub setVolID {
    # ...
    # Set the volume ID for an ISO image
    # ---
    my $this  = shift;
    my $volID = shift;
    if (! $volID ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'setVolID: no volume ID given, retaining '
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{volid} = $volID;
    return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
    # ...
    # Verify that the initialization hash is valid
    # ---
    my $this = shift;
    my $init = shift;
    if (! $init->{image} ) {
        my $kiwi = $this->{kiwi};
        my $msg = 'KIWIXMLTypeData: no "image" specified in '
            . 'initialization structure.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $this -> p_areKeywordBooleanValuesValid($init) ) {
        return;
    }
    if ($init->{bootloader}) {
        if (! $this->__isValidBootloader(
            $init->{bootloader},'object initialization')) {
            return;
        }
    }
    if ($init->{bootfilesystem}) {
        if (! $this->__isValidBootFS(
            $init->{bootfilesystem},'object initialization')) {
            return;
        }
    }
    if ($init->{devicepersistency}) {
        if (! $this->__isValidDevPersist(
            $init->{devicepersistency}, 'object initialization')) {
            return;
        }
    }
    if ($init->{filesystem}) {
        if (! $this->__isValidFilesystem(
            $init->{filesystem}, 'object initialization')) {
            return;
        }
    }
    if ($init->{firmware}) {
        if (! $this->__isValidFirmware(
            $init->{firmware}, 'object initialization')) {
            return;
        }
    }
    if ($init->{flags}) {
        if (! $this->__isValidFlags(
            $init->{flags}, 'object initialization')) {
            return;
        }
    }
    if ($init->{format}) {
        if (! $this->__isValidFormat(
            $init->{format},'object initialization')) {
            return;
        }
    }
    if ($init->{fsreadonly}) {
        if (! $this->__isValidFilesystem(
            $init->{fsreadonly},'object initialization')) {
            return;
        }
    }
    if ($init->{fsreadwrite}) {
        if (! $this->__isValidFilesystem(
            $init->{fsreadwrite},'object initialization')) {
            return;
        }
    }
    if (! $this->__isValidImage($init->{image},'object initialization')) {
        return;
    }
    if ($init->{installboot}) {
        if (! $this->__isValidInstBoot(
            $init->{installboot},'object initialization')) {
            return;
        }
    }
    if ($init->{mdraid}) {
        if (! $this->__isValidRaidType (
            $init->{mdraid},'object initialization')) {
            return;
        }
    }
    if ($init->{sizeunit}) {
        if (! $this->__isValidSizeUnit(
            $init->{sizeunit}, 'object initialization')) {
            return;
        }
    }
    if ($init->{zipl_targettype}) {
        if (! $this->__isValidZiplTargetType(
            $init->{zipl_targettype}, 'object initialization')) {
            return;
        }
    }
    return 1;
}

#==========================================
# __isValidZiplTargetType
#------------------------------------------
sub __isValidZiplTargetType {
    # ...
    # Verify that the given zipl target type is supported
    # ---
    my $this   = shift;
    my $zipl_type = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidZiplTargetType called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $zipl_type ) {
        my $msg = "$caller: no zipl target type argument specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        CDL
        LDL
        FBA
        SCSI
    );
    if (! $supported{$zipl_type} ) {
        my $msg = "$caller: specified zipl target type '$zipl_type' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidBootFS
#------------------------------------------
sub __isValidBootFS {
    # ...
    # Verify that the given boot filesystem type is supported
    # ---
    my $this   = shift;
    my $bootFS = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidBootFS called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $bootFS ) {
        my $msg = "$caller: no boot filesystem argument specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        ext2
        ext3
        ext4
        fat16
        fat32
    );
    if (! $supported{$bootFS} ) {
        my $msg = "$caller: specified boot filesystem '$bootFS' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidBootloader
#------------------------------------------
sub __isValidBootloader {
    # ...
    # Verify that the given bootloader is supported
    # ---
    my $this   = shift;
    my $bootL  = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidBootloader called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $bootL ) {
        my $msg = "$caller: no bootloader specified, retaining current data.";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        extlinux
        grub
        grub2
        syslinux
        isolinux
        uboot
        berryboot
        yaboot
        zipl
        grub2_s390x_emu
    );
    if (! $supported{$bootL} ) {
        my $msg = "$caller: specified bootloader '$bootL' is not supported.";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidDevPersist
#------------------------------------------
sub __isValidDevPersist {
    # ...
    # Verify that the given device persistency setting is supported
    # ---
    my $this   = shift;
    my $devP  = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidDevPersist called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $devP ) {
        my $msg = "$caller: no device persistency specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        by-uuid by-label by-path
    );
    if (! $supported{$devP} ) {
        my $msg = "$caller: specified device persistency '$devP' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidFilesystem
#------------------------------------------
sub __isValidFilesystem {
    # ...
    # Verify that the given filesystem is supported
    # ---
    my $this   = shift;
    my $fileS  = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidFilesystem called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $fileS ) {
        my $msg = "$caller: no filesystem specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        btrfs clicfs ext2 ext3 ext4 overlayfs reiserfs squashfs xfs zfs
    );
    if (! $supported{$fileS} ) {
        my $msg = "$caller: specified filesystem '$fileS' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidFirmware
#------------------------------------------
sub __isValidFirmware {
    # ...
    # Verify that the given firmware setting value is supported
    # ---
    my $this     = shift;
    my $firmware = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidFirmware called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $firmware ) {
        my $msg = "$caller: no firmware type given, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        bios ec2 ec2hvm efi uefi vboot ofw
    );
    if (! $supported{$firmware} ) {
        my $msg = "$caller: specified firmware value '$firmware' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidFlags
#------------------------------------------
sub __isValidFlags {
    # ...
    # Verify that the given flags value is supported
    # ---
    my $this   = shift;
    my $flag   = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidFlags called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $flag ) {
        my $msg = "$caller: no flags argument specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        clic compressed clic_udf overlay seed
    );
    if (! $supported{$flag} ) {
        my $msg = "$caller: specified flags value '$flag' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidFormat
#------------------------------------------
sub __isValidFormat {
    # ...
    # Verify that the given format value is supported
    # ---
    my $this   = shift;
    my $format = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidFormat called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $format ) {
        my $msg = "$caller: no format argument specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        ec2 gce ovf ova qcow2 raw vmdk vdi vhd vhd-fixed vagrant
    );
    if (! $supported{$format} ) {
        my $msg = "$caller: specified format '$format' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidImage
#------------------------------------------
sub __isValidImage {
    # ...
    # Verify that the given image type value is supported
    # ---
    my $this   = shift;
    my $image  = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidImage called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $image ) {
        my $msg = "$caller: no image argument specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        aci
        btrfs
        clicfs
        cpio
        docker
        ext2
        ext3
        ext4
        iso
        lxc
        oem
        product
        pxe
        reiserfs
        split
        squashfs
        tbz
        vmx
        xfs
        zfs
    );
    if (! $supported{$image} ) {
        my $msg = "$caller: specified image '$image' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidInstBoot
#------------------------------------------
sub __isValidInstBoot {
    # ...
    # Verify that the given installboot value is supported
    # ---
    my $this   = shift;
    my $instB  = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidInstBoot called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $instB ) {
        my $msg = "$caller: no installboot argument specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        failsafe-install harddisk install
    );
    if (! $supported{$instB} ) {
        my $msg = "$caller: specified installboot option '$instB' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidRaidType
#------------------------------------------
sub __isValidRaidType {
    # ...
    # Verify that the given raid type is supported
    # ---
    my $this   = shift;
    my $mdtype = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidRaidType called without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $mdtype ) {
        my $msg = "$caller: no raid type specified, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %supported = map { ($_ => 1) } qw(
        mirroring striping
    );
    if (! $supported{$mdtype} ) {
        my $msg = "$caller: specified raid type '$mdtype' is not "
            . 'supported.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __isValidSizeUnit
#------------------------------------------
sub __isValidSizeUnit {
    # ...
    # Verify that the given unit of measure for the size is a
    # recognized value
    # ---
    my $this   = shift;
    my $unit   = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isValidSizeUnitcalled without '
            . 'call origin argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $unit ) {
        my $msg = "$caller: no systemsize unit value given, retaining "
            . 'current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if ($unit ne 'M' && $unit ne 'G') {
        my $msg = "$caller: expecting unit setting of 'M' or 'G'.";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __byteValue
#------------------------------------------
sub __byteValue {
    # ...
    # turn given value into bytes, units M and G
    # are allowed no unit assumes a MB value
    # ---
    my $this = shift;
    my $size = shift;
    my $unit = shift;
    if (! $unit) {
        $unit = 'M';
    }
    if (! $size) {
        return 0;
    }
    if ($unit eq 'M') {
        # no unit or M specified, turn into Bytes...
        return $size * $NEXT_UNIT * $NEXT_UNIT;
    } elsif ($unit eq 'G') {
        # unit G specified, turn into Bytes...
        return $size * $NEXT_UNIT * $NEXT_UNIT * $NEXT_UNIT;
    }
    return 0;
}

1;
