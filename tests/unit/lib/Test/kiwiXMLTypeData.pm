#================
# FILE          : kiwiXMLTypeData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLTypeData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLTypeData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use Readonly;
use base qw /Common::ktTestCase/;

use KIWIXMLTypeData;

#==========================================
# constants
#------------------------------------------
Readonly my $BOOTPAT_SIZE   => 512;
Readonly my $IMAGE_SIZE     => 16_384;
Readonly my $LARGE_BOOTPART => 1024;
Readonly my $SMALL_IMAGE    => 4096;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct new test case
    # ---
    my $this = shift -> SUPER::new(@_);
    return $this;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
    # ...
    # Test the TypeData constructor with an improper argument type
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = KIWIXMLTypeData -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'Expecting a hash ref as first argument if provided';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initInvalidCheckprebuiltValue
#------------------------------------------
sub test_ctor_initInvalidCheckprebuiltValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the checkprebuilt value
    # ----
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        checkprebuilt => 'foo',
        image         => 'iso'
    );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'checkprebuilt' in initialization structure.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initInvalidCompressedValue
#------------------------------------------
sub test_ctor_initInvalidCompressedValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the compressed value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                compressed => 'foo',
                image      => 'oem'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'compressed' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidFirmwareValue
#------------------------------------------
sub test_ctor_initInvalidFirmwareValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized initialization for
    # the firmware value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
             firmware => 'foo',
         image    => 'ext3'
     );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'object initialization: specified firmware value '
        . "'foo' is not supported.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidFsnocheckValue
#------------------------------------------
sub test_ctor_initInvalidFsnocheckValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the fsnocheck value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
            fsnocheck => 'foo',
        image     => 'ext3'
     );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'fsnocheck' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidHybridValue
#------------------------------------------
sub test_ctor_initInvalidHybridValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the hybrid value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                hybrid => 'foo',
                image  => 'xfs'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'hybrid' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidHybridpersistentValue
#------------------------------------------
sub test_ctor_initInvalidHybridpersistentValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the hybridpersistent value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                hybridpersistent => 'foo',
                image            => 'cpio'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'hybridpersistent' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidInstallisoValue
#------------------------------------------
sub test_ctor_initInvalidInstallisoValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the installiso value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                image      => 'tbz',
                installiso => 'foo'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'installiso' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidInstallprovidefailsafeValue
#------------------------------------------
sub test_ctor_initInvalidInstallprovidefailsafeValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the installprovidefailsafe value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                image                  => 'vmx',
                installprovidefailsafe => 'foo'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'installprovidefailsafe' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidInstallPXEValue
#------------------------------------------
sub test_ctor_initInvalidInstallPXEValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the installpxe value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                image      => 'vmx',
                installpxe => 'foo'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'installpxe' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidInstallstickValue
#------------------------------------------
sub test_ctor_initInvalidInstallstickValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the installstick value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                image        => 'iso',
                installstick => 'foo'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'installstick' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidPrimaryValue
#------------------------------------------
sub test_ctor_initInvalidPrimaryValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the primary value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                image   => 'oem',
                primary => 'foo'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'primary' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidRamonlyValue
#------------------------------------------
sub test_ctor_initInvalidRamonlyValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the ramonly value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
                image   => 'vmx',
                ramonly => 'foo'
                );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'ramonly' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidSizeaddValue
#------------------------------------------
sub test_ctor_initInvalidSizeaddValue {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized boolean initialization for
    # the sizeadd value
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
             image   => 'iso',
         sizeadd => 'foo'
    );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'KIWIXMLTypeData: Unrecognized value for boolean '
        . "'sizeadd' in initialization structure.";
     $this -> assert_str_equals($expected, $msg);
     my $msgT = $kiwi -> getMessageType();
     $this -> assert_str_equals('error', $msgT);
     my $state = $kiwi -> getState();
     $this -> assert_str_equals('failed', $state);
     # Test this condition last to get potential error messages
     $this -> assert_null($typeDataObj);
     return;
}

#==========================================
# test_ctor_initInvalidSizeUnit
#------------------------------------------
sub test_ctor_initInvalidSizeUnit {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains an unrecognized initialization value for
    # the sizeunit
    # ----
     my $this = shift;
     my $kiwi = $this -> {kiwi};
     my %init = (
             image    => 'vmx',
         sizeunit => 'K'
     );
     my $typeDataObj = KIWIXMLTypeData -> new(\%init);
     my $msg = $kiwi -> getMessage();
     my $expected = 'object initialization: expecting unit setting of '
        . "'M' or 'G'.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedBootLoad
#------------------------------------------
sub test_ctor_initUnsupportedBootLoad {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for the bootloader
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                bootloader => 'lnxBoot',
                image      => 'split'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified bootloader '
        . "'lnxBoot' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedZiplTargetType
#------------------------------------------
sub test_ctor_initUnsupportedZiplTargetType {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for the zipl_targettype
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                zipl_targettype => 'foo',
                image      => 'split'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified zipl target type '
        . "'foo' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( bootparam => 'kiwidebug=1' );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData: Unsupported keyword argument '
        . "'bootparam' in initialization structure.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedDevPersist
#------------------------------------------
sub test_ctor_initUnsupportedDevPersist {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for the device persistence
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                image             => 'vmx',
                devicepersistency => 'mapper-id'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified device persistency '
        . "'mapper-id' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedFilesystem
#------------------------------------------
sub test_ctor_initUnsupportedFilesystem {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for the filesystem
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                filesystem => 'aufs',
                image      => 'btrfs'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified filesystem '
        . "'aufs' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedFlags
#------------------------------------------
sub test_ctor_initUnsupportedFlags {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for flags
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                flags => 'gzipped',
                image => 'ext4'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified flags value '
        . "'gzipped' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedFormat
#------------------------------------------
sub test_ctor_initUnsupportedFormat {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for the format setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                format => 'xen',
                image  => 'xfs'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified format '
    . "'xen' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedBootFS
#------------------------------------------
sub test_ctor_initUnsupportedBootFS {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for the boot filesystem setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        image => 'vmx',
        bootfilesystem => 'foo'
    );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified boot filesystem '
        . "'foo' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedImage
#------------------------------------------
sub test_ctor_initUnsupportedImage {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for image setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( image => 'qcow9' );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified image '
        . "'qcow9' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedInstBoot
#------------------------------------------
sub test_ctor_initUnsupportedInstBoot {
    # ...
    # Test the TypeData constructor with an initialization hash
    # that contains unsupported data for installboot setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                image       => 'pxe',
                installboot => 'drive'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: specified installboot option '
        . "'drive' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_noInit
#------------------------------------------
sub test_ctor_noInit {
    # ...
    # Test the TypeData constructor
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = KIWIXMLTypeData -> new();
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData: must be constructed with a '
        . 'keyword hash as argument';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_withInit
#------------------------------------------
sub test_ctor_withInit {
    # ...
    # Test the TypeData constructor with an initialization hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                boot        => 'oem/suse-12.2',
                boottimeout => '2',
                fsreadonly  => 'btrfs',
                hybrid      => 'false',
                image       => 'oem'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($typeDataObj);
    return;
}

#==========================================
# test_ctor_withInitIncomplete
#------------------------------------------
sub test_ctor_withInitIncomplete {
    # ...
    # Test the TypeData constructor with an initialization hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                boot        => 'oem/suse-12.2',
                boottimeout => '2',
                fsreadonly  => 'btrfs',
                hybrid      => 'false',
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData: no "image" specified in '
        . 'initialization structure.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($typeDataObj);
    return;
}

#==========================================
# test_getBootImageDescript
#------------------------------------------
sub test_getBootImageDescript {
    # ...
    # Test the getBootImageDescript method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $path = $typeDataObj -> getBootImageDescript();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('/oem/suse-12.2', $path);
    return;
}

#==========================================
# test_getBootImageFileSystem
#------------------------------------------
sub test_getBootImagetFileSystem {
    # ...
    # Test the getBootImagetFileSystem method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $bootFS = $typeDataObj -> getBootImageFileSystem();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('fat32', $bootFS);
    return;
}

#==========================================
# test_getBootKernel
#------------------------------------------
sub test_getBootKernel {
    # ...
    # Test the geBootKernelt method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $bootK = $typeDataObj -> getBootKernel();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xenk', $bootK);
    return;
}

#==========================================
# test_getBootLoader
#------------------------------------------
sub test_getBootLoader {
    # ...
    # Test the getBootLoader method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $name = $typeDataObj -> getBootLoader();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('grub2', $name);
    return;
}

#==========================================
# test_getZiplTargetType
#------------------------------------------
sub test_getZiplTargetType {
    # ...
    # Test the getZiplTargetType method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $name = $typeDataObj -> getZiplTargetType();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('FBA', $name);
    return;
}

#==========================================
# test_getTargetBlockSize
#------------------------------------------
sub test_getTargetBlockSize {
    # ...
    # Test the getTargetBlockSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $blocksize = $typeDataObj -> getTargetBlockSize();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('4096', $blocksize);
    return;
}

#==========================================
# test_getBootLoaderDefault
#------------------------------------------
sub test_getBootLoaderDefault {
    # ...
    # Test the getBootLoader method, verify the default setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( image => 'ext2' );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $name = $typeDataObj -> getBootLoader();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('grub', $name);
    return;
}

#==========================================
# test_getBootPartitionSize
#------------------------------------------
sub test_getBootPartitionSize {
    # ...
    # Test the getBootPartitionSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $size = $typeDataObj -> getBootPartitionSize();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_equals($BOOTPAT_SIZE, $size);
    return;
}

#==========================================
# test_getBootProfile
#------------------------------------------
sub test_getBootProfile {
    # ...
    # Test the getBootProfile method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $prof = $typeDataObj -> getBootProfile();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('std', $prof);
    return;
}

#==========================================
# test_getBootTimeout
#------------------------------------------
sub test_getBootTimeout {
    # ...
    # Test the getBootTimeout method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $time = $typeDataObj -> getBootTimeout();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('5', $time);
    return;
}

#==========================================
# test_getCheckPrebuilt
#------------------------------------------
sub test_getCheckPrebuilt {
    # ...
    # Test the getCheckPrebuilt method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $preb = $typeDataObj -> getCheckPrebuilt();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $preb);
    return;
}

#==========================================
# test_getCompressed
#------------------------------------------
sub test_getCompressed {
    # ...
    # Test the getCompressed method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $comp = $typeDataObj -> getCompressed();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $comp);
    return;
}

#==========================================
# test_getContainerName
#------------------------------------------
sub test_getContainerName {
    # ...
    # Test the getContainerName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $name = $typeDataObj -> getContainerName();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('mycont', $name);
    return;
}

#==========================================
# test_getDevicePersistent
#------------------------------------------
sub test_getDevicePersistent {
    # ...
    # Test the getDevicePersistent method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $kind = $typeDataObj -> getDevicePersistent();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('by-uuid', $kind);
    return;
}

#==========================================
# test_getEditBootConfig
#------------------------------------------
sub test_getEditBootConfig {
    # ...
    # Test the getEditBootConfig method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $conf = $typeDataObj -> getEditBootConfig();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myscript', $conf);
    return;
}

#==========================================
# test_getEditBootInstall
#------------------------------------------
sub test_getEditBootInstall {
    # ...
    # Test the getEditBootInstall method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $conf = $typeDataObj -> getEditBootInstall();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myInstScript', $conf);
    return;
}

#==========================================
# test_getFilesystem
#------------------------------------------
sub test_getFilesystem {
    # ...
    # Test the getFilesystem method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $fs = $typeDataObj -> getFilesystem();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xfs', $fs);
    return;
}

#==========================================
# test_getFirmwareType
#------------------------------------------
sub test_getFirmwareType {
    # ...
    # Test the getFirmwareType method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $fw = $typeDataObj -> getFirmwareType();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('efi', $fw);
    return;
}

#==========================================
# test_getFirmwareTypeDefault
#------------------------------------------
sub test_getFirmwareTypeDefault {
    # ...
    # Test the getFirmwareType method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( image => 'ext2' );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $fw = $typeDataObj -> getFirmwareType();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('bios', $fw);
    return;
}

#==========================================
# test_getFlags
#------------------------------------------
sub test_getFlags {
    # ...
    # Test the getFlags method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $flags = $typeDataObj -> getFlags();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('compressed', $flags);
    return;
}

#==========================================
# test_getFormat
#------------------------------------------
sub test_getFormat {
    # ...
    # Test the getFormat method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $format = $typeDataObj -> getFormat();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('qcow2', $format);
    return;
}

#==========================================
# test_getFormatOptions
#------------------------------------------
sub test_getFormatOptions {
    # ...
    # Test the getFormatOptions method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $format = $typeDataObj -> getFormatOptions();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('compat=bob,name=xxx', $format);
    return;
}

#==========================================
# test_getFSMountOptions
#------------------------------------------
sub test_getFSMountOptions {
    # ...
    # Test the getFSMountOptions method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $opt = $typeDataObj -> getFSMountOptions();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('barrier', $opt);
    return;
}

#==========================================
# test_getFSNoCheck
#------------------------------------------
sub test_getFSNoCheck {
    # ...
    # Test the getFSNoCheck method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $check = $typeDataObj -> getFSNoCheck();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $check);
    return;
}

#==========================================
# test_getFSReadOnly
#------------------------------------------
sub test_getFSReadOnly {
    # ...
    # Test the getFSReadOnly method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $fs = $typeDataObj -> getFSReadOnly();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ext3', $fs);
    return;
}

#==========================================
# test_getFSReadWrite
#------------------------------------------
sub test_getFSReadWrite {
    # ...
    # Test the getFSReadWrite method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $fs = $typeDataObj -> getFSReadWrite();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xfs', $fs);
    return;
}

#==========================================
# test_getHybrid
#------------------------------------------
sub test_getHybrid {
    # ...
    # Test the getHybrid method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $hybrid = $typeDataObj -> getHybrid();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $hybrid);
    return;
}

#==========================================
# test_getHybridPersistent
#------------------------------------------
sub test_getHybridPersistent {
    # ...
    # Test the getHybridPersistent method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $hybP = $typeDataObj -> getHybridPersistent();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $hybP);
    return;
}

#==========================================
# test_getHybridPersistentFileSystem
#------------------------------------------
sub test_getHybridPersistentFileSystem {
    # ...
    # Test the getHybridPersistentFileSystem method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $hybPFS = $typeDataObj -> getHybridPersistentFileSystem();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('btrfs', $hybPFS);
    return;
}

#==========================================
# test_getInstallBoot
#------------------------------------------
sub test_getInstallBoot {
    # ...
    # Test the getInstallBoot method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $boot = $typeDataObj -> getInstallBoot();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('install', $boot);
    return;
}

#==========================================
# test_getInstallProvideFailsafe
#------------------------------------------
sub test_getInstallProvideFailsafe {
    # ...
    # Test the getInstallProvideFailsafe method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $instFS = $typeDataObj -> getInstallProvideFailsafe();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $instFS);
    return;
}

#==========================================
# test_getInstallProvideFailsafeDefault
#------------------------------------------
sub test_getInstallProvideFailsafeDefault {
    # ...
    # Test the getInstallProvideFailsafe method, verify the default setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( image => 'cpio' );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $instFS = $typeDataObj -> getInstallProvideFailsafe();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $instFS);
    return;
}

#==========================================
# test_getInstallIso
#------------------------------------------
sub test_getInstallIso {
    # ...
    # Test the getInstallIso method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $iso = $typeDataObj -> getInstallIso();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $iso);
    return;
}

#==========================================
# test_getInstallPXE
#------------------------------------------
sub test_getInstallPXE {
    # ...
    # Test the getInstallPXE method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $instFS = $typeDataObj -> getInstallPXE();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $instFS);
    return;
}

#==========================================
# test_getInstallStick
#------------------------------------------
sub test_getInstallStick {
    # ...
    # Test the getInstallStick method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $stick = $typeDataObj -> getInstallStick();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $stick);
    return;
}

#==========================================
# test_getKernelCmdOpts
#------------------------------------------
sub test_getKernelCmdOpts {
    # ...
    # Test the getKernelCmdOpts method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $kOpts = $typeDataObj -> getKernelCmdOpts();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('kiwidebug=1', $kOpts);
    return;
}

#==========================================
# test_getLuksPass
#------------------------------------------
sub test_getLuksPass {
    # ...
    # Test the getLuksPass method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $pass = $typeDataObj -> getLuksPass();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('notApass', $pass);
    return;
}

#==========================================
# test_getLuksOS
#------------------------------------------
sub test_getLuksOS {
    # ...
    # Test the getLuksOS method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $dist = $typeDataObj -> getLuksOS();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('sle11', $dist);
    return;
}

#==========================================
# test_getMDRaid
#------------------------------------------
sub test_getMDRaid {
    # ...
    # Test the getMDRaid method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $raidt = $typeDataObj -> getMDRaid();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('striping', $raidt);
    return;
}

#==========================================
# test_getPrimary
#------------------------------------------
sub test_getPrimary {
    # ...
    # Test the getPrimary method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $prime = $typeDataObj -> getPrimary();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $prime);
    return;
}

#==========================================
# test_getRAMOnly
#------------------------------------------
sub test_getRAMOnly {
    # ...
    # Test the getRAMOnly method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $rOnly = $typeDataObj -> getRAMOnly();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $rOnly);
    return;
}

#==========================================
# test_getSize
#------------------------------------------
sub test_getSize {
    # ...
    # Test the getSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $size = $typeDataObj -> getSize();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_equals($IMAGE_SIZE, $size);
    return;
}

#==========================================
# test_getSizeUnit
#------------------------------------------
sub test_getSizeUnit {
    # ...
    # Test the getSizeUnit method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $unit = $typeDataObj -> getSizeUnit();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('M', $unit);
    return;
}

#==========================================
# test_getSizeUnitDefault
#------------------------------------------
sub test_getSizeUnitDefault {
    # ...
    # Test the getSizeUnit method default value setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
             image => 'vmx',
         size  => '8192'
    );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $unit = $typeDataObj -> getSizeUnit();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('M', $unit);
    return;
}

#==========================================
# test_getTypeName
#------------------------------------------
sub test_getTypeName {
    # ...
    # Test the getImageType method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $type = $typeDataObj -> getTypeName();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('oem', $type);
    return;
}

#==========================================
# test_getVHDFixedTag
#------------------------------------------
sub test_getVHDFixedTag {
    # ...
    # Test the getVHDFixedTag method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $tag = $typeDataObj -> getVHDFixedTag();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('12345678', $tag);
    return;
}

#==========================================
# test_getGCELicense
#------------------------------------------
sub test_getGCELicense {
    # ...
    # Test the getGCELicense method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $tag = $typeDataObj -> getGCELicense();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('0815', $tag);
    return;
}

#==========================================
# test_getVGA
#------------------------------------------
sub test_getVGA {
    # ...
    # Test the getVGA method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $vga = $typeDataObj -> getVGA();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('0x344', $vga);
    return;
}

#==========================================
# test_getVolID
#------------------------------------------
sub test_getVolID {
    # ...
    # Test the getVolID method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $id = $typeDataObj -> getVolID();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myImg', $id);
    return;
}

#==========================================
# test_isSizeAdditive
#------------------------------------------
sub test_isSizeAdditive {
    # ...
    # Test the isSizeAdditive method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $add = $typeDataObj -> isSizeAdditive();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('1', $add);
    return;
}

#==========================================
# test_isSizeAdditiveDefault
#------------------------------------------
sub test_isSizeAdditiveDefault {
    # ...
    # Test the isSizeAditive method default value setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
             image => 'vmx',
         size  => '8192'
    );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $add = $typeDataObj -> isSizeAdditive();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('0', $add);
    return;
}

#==========================================
# test_getXMLElement
#------------------------------------------
sub test_getXMLElement{
    # ...
    # Verify that the getXMLElement method returns a node
    # with the proper data.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $elem = $typeDataObj -> getXMLElement();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($elem);
    my $xmlstr = $elem -> toString();
    my $expected = '<type '
        . 'image="oem" '
        . 'boot="/oem/suse-12.2" '
        . 'bootfilesystem="fat32" '
        . 'bootkernel="xenk" '
        . 'bootloader="grub2" '
        . 'target_blocksize="4096" '
        . 'zipl_targettype="FBA" '
        . 'bootpartsize="512" '
        . 'bootpartition="true" '
        . 'bootprofile="std" '
        . 'boottimeout="5" '
        . 'checkprebuilt="true" '
        . 'compressed="true" '
        . 'container="mycont" '
        . 'devicepersistency="by-uuid" '
        . 'editbootconfig="myscript" '
        . 'editbootinstall="myInstScript" '
        . 'filesystem="xfs" '
        . 'firmware="efi" '
        . 'flags="compressed" '
        . 'format="qcow2" '
        . 'formatoptions="compat=bob,name=xxx" '
        . 'fsmountoptions="barrier" '
        . 'fsnocheck="true" '
        . 'fsreadonly="ext3" '
        . 'fsreadwrite="xfs" '
        . 'hybrid="true" '
        . 'hybridpersistent="true" '
        . 'hybridpersistent_filesystem="btrfs" '
        . 'installboot="install" '
        . 'installiso="true" '
        . 'installprovidefailsafe="true" '
        . 'installpxe="false" '
        . 'installstick="true" '
        . 'kernelcmdline="kiwidebug=1" '
        . 'luks="notApass" '
        . 'luksOS="sle11" '
        . 'mdraid="striping" '
        . 'primary="true" '
        . 'ramonly="true" '
        . 'vga="0x344" '
        . 'vhdfixedtag="12345678" '
        . 'gcelicense="0815" '
        . 'volid="myImg">'
        . '<size additive="true" unit="M">16384</size>'
        . '</type>';
    $this -> assert_str_equals($expected, $xmlstr);
    return;
}

#==========================================
# test_setBootImageDescript
#------------------------------------------
sub test_setBootImageDescript {
    # ...
    # Test the setBootImageDescript method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootImageDescript('vmxboot/suse-12.2');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $path = $typeDataObj -> getBootImageDescript();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('vmxboot/suse-12.2', $path);
    return;
}

#==========================================
# test_setBootImageDescriptNoArg
#------------------------------------------
sub test_setBootImageDescriptNoArg {
    # ...
    # Test the setBootImageDescript method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootImageDescript();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setBootImageDescript: no boot description given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $path = $typeDataObj -> getBootImageDescript();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('/oem/suse-12.2', $path);
    return;
}

#==========================================
# test_setBootImageFileSystem
#------------------------------------------
sub test_setBootImageFileSystem {
    # ...
    # Test the setBootImageDescript method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootImageFileSystem('ext3');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $bIfs = $typeDataObj -> getBootImageFileSystem();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ext3', $bIfs);
    return;
}

#==========================================
# test_setBootImageFileSystemNoArg
#------------------------------------------
sub test_setBootImageFileSystemNoArg {
    # ...
    # Test the setBootImageFileSystem method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootImageFileSystem();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setBootImageFileSystem: no boot filesystem argument '
        . 'specified, retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $bIfs = $typeDataObj -> getBootImageFileSystem();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('fat32', $bIfs);
    return;
}

#==========================================
# test_setBootKernel
#------------------------------------------
sub test_setBootKernel {
    # ...
    # Test the setBootKernel method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootKernel('default');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $bootK = $typeDataObj -> getBootKernel();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('default', $bootK);
    return;
}

#==========================================
# test_setBootKernelNoArg
#------------------------------------------
sub test_setBootKernelNoArg {
    # ...
    # Test the setBootKernel method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootKernel();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setBootKernel: no boot kernel given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $bootK = $typeDataObj -> getBootKernel();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xenk', $bootK);
    return;
}

#==========================================
# test_setBootLoader
#------------------------------------------
sub test_setBootLoader {
    # ...
    # Test the setBootLoader method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootLoader('yaboot');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $bootL = $typeDataObj -> getBootLoader();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('yaboot', $bootL);
    return;
}

#==========================================
# test_setZiplTargetType
#------------------------------------------
sub test_setZiplTargetType {
    # ...
    # Test the setZiplTargetType method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setZiplTargetType('CDL');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $bootL = $typeDataObj -> getZiplTargetType();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('CDL', $bootL);
    return;
}

#==========================================
# test_setTargetBlockSize
#------------------------------------------
sub test_setTargetBlockSize {
    # ...
    # Test the setTargetBlockSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setTargetBlockSize('512');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $blocksize = $typeDataObj -> getTargetBlockSize();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('512', $blocksize);
    return;
}

#==========================================
# test_setBootLoaderInvalidArg
#------------------------------------------
sub test_setBootLoaderInvalidArg {
    # ...
    # Test the setBootLoader method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootLoader('linLoad');
    my $msg = $kiwi -> getMessage();
    my $expected = "setBootLoader: specified bootloader 'linLoad' "
        . 'is not supported.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $loader = $typeDataObj -> getBootLoader();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('grub2', $loader);
    return;
}

#==========================================
# test_setBootLoaderNoArg
#------------------------------------------
sub test_setBootLoaderNoArg {
    # ...
    # Test the setBootLoader method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootLoader();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setBootLoader: no bootloader specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $loader = $typeDataObj -> getBootLoader();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('grub2', $loader);
    return;
}

#==========================================
# test_setBootPartitionSize
#------------------------------------------
sub test_setBootPartitionSize {
    # ...
    # Test the setBootPartitionSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootPartitionSize('1024');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $size = $typeDataObj -> getBootPartitionSize();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_equals($LARGE_BOOTPART, $size);
    return;
}

#==========================================
# test_setBootPartitionSizeNoArg
#------------------------------------------
sub test_setBootPartitionSizeNoArg {
    # ...
    # Test the setBootPartitionSize method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootPartitionSize();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setBootPartitionSize: no size given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $size = $typeDataObj -> getBootPartitionSize();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_equals($BOOTPAT_SIZE, $size);
    return;
}

#==========================================
# test_setBootPartition
#------------------------------------------
sub test_setBootPartition {
    # ...
    # Test the setBootPartition method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootPartition('false');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $comp = $typeDataObj -> getBootPartition();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $comp);
    return;
}

#==========================================
# test_setBootPartitionNoArg
#------------------------------------------
sub test_setBootPartitionNoArg {
    # ...
    # Test the setBootPartition method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootPartition();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $comp = $typeDataObj -> getBootPartition();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $comp);
    return;
}

#==========================================
# test_setBootPartitionUnknownArg
#------------------------------------------
sub test_setBootPartitionUnknownArg {
    # ...
    # Test the setBootPartition method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootPartition('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setBootPartition: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $comp = $typeDataObj -> getBootPartition();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $comp);
    return;
}

#==========================================
# test_setBootProfile
#------------------------------------------
sub test_setBootProfile {
    # ...
    # Test the setBootProfile method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootProfile('xen');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $prof = $typeDataObj -> getBootProfile();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xen', $prof);
    return;
}

#==========================================
# test_setBootProfileNoArg
#------------------------------------------
sub test_setBootProfileNoArg {
    # ...
    # Test the setBootProfile method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootProfile();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setBootProfile: no profile given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $prof = $typeDataObj -> getBootProfile();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('std', $prof);
    return;
}

#==========================================
# test_setBootTimeout
#------------------------------------------
sub test_setBootTimeout {
    # ...
    # Test the setBootTimeout method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setBootTimeout('8');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $time = $typeDataObj -> getBootTimeout();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('8', $time);
    return;
}

#==========================================
# test_setBootTimeoutNoArg
#------------------------------------------
sub test_setBootTimeoutNoArg {
    # ...
    # Test the setBootTimeout method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setBootTimeout();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setBootTimeout: no timeout value given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $time = $typeDataObj -> getBootTimeout();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('5', $time);
    return;
}

#==========================================
# test_setCheckPrebuilt
#------------------------------------------
sub test_setCheckPrebuilt {
    # ...
    # Test the setCheckPrebuilt method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setCheckPrebuilt('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $check = $typeDataObj -> getCheckPrebuilt();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $check);
    return;
}

#==========================================
# test_setCheckPrebuiltNoArg
#------------------------------------------
sub test_setCheckPrebuiltNoArg {
    # ...
    # Test the setCheckPrebuilt method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setCheckPrebuilt();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $check = $typeDataObj -> getCheckPrebuilt();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $check);
    return;
}

#==========================================
# test_setCheckPrebuiltUnknownArg
#------------------------------------------
sub test_setCheckPrebuiltUnknownArg {
    # ...
    # Test the setCheckPrebuilt method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setCheckPrebuilt('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setCheckPrebuilt: unrecognized '
        . 'argument expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $check = $typeDataObj -> getCheckPrebuilt();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $check);
    return;
}

#==========================================
# test_setCompressed
#------------------------------------------
sub test_setCompressed {
    # ...
    # Test the setCompressed method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setCompressed('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $comp = $typeDataObj -> getCompressed();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $comp);
    return;
}

#==========================================
# test_setCompressedNoArg
#------------------------------------------
sub test_setCompressedNoArg {
    # ...
    # Test the setCompressed method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setCompressed();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $comp = $typeDataObj -> getCompressed();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $comp);
    return;
}

#==========================================
# test_setCompressedUnknownArg
#------------------------------------------
sub test_setCompressedUnknownArg {
    # ...
    # Test the setCompressed method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setCompressed('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setCompressed: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $comp = $typeDataObj -> getCompressed();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $comp);
    return;
}

#==========================================
# test_setContainerName
#------------------------------------------
sub test_setContainerName {
    # ...
    # Test the setContainerName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setContainerName('foo');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $name = $typeDataObj -> getContainerName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('foo', $name);
    return;
}

#==========================================
# test_setContainerNameNoArg
#------------------------------------------
sub test_setContainerNameNoArg {
    # ...
    # Test the setContainerName method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setContainerName();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setContainerName: no container name given, retaining '
        . 'current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $name = $typeDataObj -> getContainerName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('mycont', $name);
    return;
}

#==========================================
# test_setContainerNameIllegal
#------------------------------------------
sub test_setContainerNameIllegal {
    # ...
    # Test the setContainerName method with an illegal name
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setContainerName('my$bucket');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setContainerName: given container name contains non word '
        . 'character, illegal name. Retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $name = $typeDataObj -> getContainerName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('mycont', $name);
    return;
}

#==========================================
# test_setDevicePersistent
#------------------------------------------
sub test_setDevicePersistent {
    # ...
    # Test the setDevicePersistent method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setDevicePersistent('by-label');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $devP = $typeDataObj -> getDevicePersistent();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('by-label', $devP);
    return;
}

#==========================================
# test_setDevicePersistentInvalidArg
#------------------------------------------
sub test_setDevicePersistentInvalidArg {
    # ...
    # Test the setDevicePersistent method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setDevicePersistent('unixDev');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setDevicePersistent: specified device persistency '
        . "'unixDev' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $devP = $typeDataObj -> getDevicePersistent();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('by-uuid', $devP);
    return;
}

#==========================================
# test_setDevicePersistentNoArg
#------------------------------------------
sub test_setDevicePersistentNoArg {
    # ...
    # Test the setDevicePersistent method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setDevicePersistent();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setDevicePersistent: no device persistency specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $devP = $typeDataObj -> getDevicePersistent();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('by-uuid', $devP);
    return;
}

#==========================================
# test_setEditBootConfig
#------------------------------------------
sub test_setEditBootConfig {
    # ...
    # Test the setEditBootConfig method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setEditBootConfig('confScript');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $bootE = $typeDataObj -> getEditBootConfig();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('confScript', $bootE);
    return;
}

#==========================================
# test_setEditBootConfigNoArg
#------------------------------------------
sub test_setEditBootConfigNoArg {
    # ...
    # Test the setEditBootConfig method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setEditBootConfig();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setEditBootConfig: no config script given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $bootE = $typeDataObj -> getEditBootConfig();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myscript', $bootE);
    return;
}

#==========================================
# test_setEditBootInstall
#------------------------------------------
sub test_setEditBootInstall {
    # ...
    # Test the setEditBootInstall method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setEditBootInstall('confInstScript');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $bootE = $typeDataObj -> getEditBootInstall();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('confInstScript', $bootE);
    return;
}

#==========================================
# test_setEditBootInstallNoArg
#------------------------------------------
sub test_setEditBootInstallNoArg {
    # ...
    # Test the setEditBootInstall method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setEditBootInstall();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setEditBootInstall: no config script given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $bootE = $typeDataObj -> getEditBootInstall();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myInstScript', $bootE);
    return;
}

#==========================================
# test_setFilesystem
#------------------------------------------
sub test_setFilesystem {
    # ...
    # Test the setFilesystem method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFilesystem('ext3');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $fs = $typeDataObj -> getFilesystem();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ext3', $fs);
    return;
}

#==========================================
# test_setFilesystemInvalidArg
#------------------------------------------
sub test_setFilesystemInvalidArg {
    # ...
    # Test the setFilesystem method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFilesystem('ceph');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFilesystem: specified filesystem '
        . "'ceph' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fs = $typeDataObj -> getFilesystem();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xfs', $fs);
    return;
}

#==========================================
# test_setFilesystemNoArg
#------------------------------------------
sub test_setFilesystemNoArg {
    # ...
    # Test the setFilesystem method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFilesystem();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFilesystem: no filesystem specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fs = $typeDataObj -> getFilesystem();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xfs', $fs);
    return;
}

#==========================================
# test_setFirmwareType
#------------------------------------------
sub test_setFirmwareType {
    # ...
    # Test the setFirmwareType method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFirmwareType('bios');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $fw = $typeDataObj -> getFirmwareType();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('bios', $fw);
    return;
}

#==========================================
# test_setFirmwareTypeInvalidArg
#------------------------------------------
sub test_setFirmwareTypeInvalidArg {
    # ...
    # Test the setFirmwareType method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFirmwareType('special');
    my $msg = $kiwi -> getMessage();
    my $expected = "setFirmwareType: specified firmware value 'special' "
        . 'is not supported.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fw = $typeDataObj -> getFirmwareType();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('efi', $fw);
    return;
}

#==========================================
# test_setFirmwareTypeNoArg
#------------------------------------------
sub test_setFirmwareTypeNoArg {
    # ...
    # Test the setFirmwareType method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFirmwareType();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFirmwareType: no firmware type given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fw = $typeDataObj -> getFirmwareType();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('efi', $fw);
    return;
}

#==========================================
# test_setFlags
#------------------------------------------
sub test_setFlags {
    # ...
    # Test the setFlags method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFlags('clic');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $flags = $typeDataObj -> getFlags();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('clic', $flags);
    return;
}

#==========================================
# test_setFlagsInvalidArg
#------------------------------------------
sub test_setFlagsInvalidArg {
    # ...
    # Test the setFlags method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFlags('gzip');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFlags: specified flags value '
        . "'gzip' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $flags = $typeDataObj -> getFlags();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('compressed', $flags);
    return;
}

#==========================================
# test_setFlagsNoArg
#------------------------------------------
sub test_setFlagsNoArg {
    # ...
    # Test the setFlags method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFlags();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFlags: no flags argument specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $flags = $typeDataObj -> getFlags();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('compressed', $flags);
    return;
}

#==========================================
# test_setFormat
#------------------------------------------
sub test_setFormat {
    # ...
    # Test the setFormat method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFormat('ec2');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $format = $typeDataObj -> getFormat();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ec2', $format);
    return;
}

#==========================================
# test_setFormatInvalidArg
#------------------------------------------
sub test_setFormatInvalidArg {
    # ...
    # Test the setFormat method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFormat('cow');
    my $msg = $kiwi -> getMessage();
    my $expected = "setFormat: specified format 'cow' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $format = $typeDataObj -> getFormat();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('qcow2', $format);
    return;
}

#==========================================
# test_setFormatNoArg
#------------------------------------------
sub test_setFormatNoArg {
    # ...
    # Test the setFormat method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFormat();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFormat: no format argument specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $format = $typeDataObj -> getFormat();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('qcow2', $format);
    return;
}

#==========================================
# test_setFSMountOptions
#------------------------------------------
sub test_setFSMountOptions {
    # ...
    # Test the setFSMountOptions method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFSMountOptions('journal');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $opts = $typeDataObj -> getFSMountOptions();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('journal', $opts);
    return;
}

#==========================================
# test_setFSMountOptionsNoArg
#------------------------------------------
sub test_setFSMountOptionsNoArg {
    # ...
    # Test the setFSMountOptions method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFSMountOptions();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFSMountOptions: no mount options given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $opts = $typeDataObj -> getFSMountOptions();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('barrier', $opts);
    return;
}

#==========================================
# test_setFSNoCheck
#------------------------------------------
sub test_setFSNoCheck {
    # ...
    # Test the setFSNoCheck method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFSNoCheck('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $check = $typeDataObj -> getFSNoCheck();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $check);
    return;
}

#==========================================
# test_setFSNoCheckNoArg
#------------------------------------------
sub test_setFSNoCheckNoArg {
    # ...
    # Test the setFSNoCheck method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFSNoCheck();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $check = $typeDataObj -> getFSNoCheck();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $check);
    return;
}

#==========================================
# test_setFSNoCheckUnknownArg
#------------------------------------------
sub test_setFSNoCheckUnknownArg {
    # ...
    # Test the setFSNoCheck method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFSNoCheck('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setFSNoCheck: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $check = $typeDataObj -> getFSNoCheck();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $check);
    return;
}

#==========================================
# test_setFSReadOnly
#------------------------------------------
sub test_setFSReadOnly {
    # ...
    # Test the setFSReadOnly method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFSReadOnly('ext3');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $fs = $typeDataObj -> getFSReadOnly();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ext3', $fs);
    return;
}

#==========================================
# test_setFSReadOnlyInvalidArg
#------------------------------------------
sub test_setFSReadOnlyInvalidArg {
    # ...
    # Test the setFSReadOnly method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFSReadOnly('ceph');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFSReadOnly: specified filesystem '
        . "'ceph' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fs = $typeDataObj -> getFSReadOnly();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ext3', $fs);
    return;
}

#==========================================
# test_setFSReadOnlyNoArg
#------------------------------------------
sub test_setFSReadOnlyNoArg {
    # ...
    # Test the setFSReadOnly method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFSReadOnly();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFSReadOnly: no filesystem specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fs = $typeDataObj -> getFSReadOnly();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ext3', $fs);
    return;
}

#==========================================
# test_setFSReadWrite
#------------------------------------------
sub test_setFSReadWrite {
    # ...
    # Test the setFSReadWrite method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setFSReadWrite('ext3');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $fs = $typeDataObj -> getFSReadWrite();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('ext3', $fs);
    return;
}

#==========================================
# test_setFSReadWriteInvalidArg
#------------------------------------------
sub test_setFSReadWriteInvalidArg {
    # ...
    # Test the setFSReadWrite method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFSReadWrite('ceph');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFSReadWrite: specified filesystem '
        . "'ceph' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fs = $typeDataObj -> getFSReadWrite();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xfs', $fs);
    return;
}

#==========================================
# test_setFSReadWriteNoArg
#------------------------------------------
sub test_setFSReadWriteNoArg {
    # ...
    # Test the setFSReadWrite method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setFSReadWrite();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setFSReadWrite: no filesystem specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fs = $typeDataObj -> getFSReadWrite();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('xfs', $fs);
    return;
}

#==========================================
# test_setHybrid
#------------------------------------------
sub test_setHybrid {
    # ...
    # Test the setHybrid method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setHybrid('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $hybrid = $typeDataObj -> getHybrid();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $hybrid);
    return;
}

#==========================================
# test_setHybridNoArg
#------------------------------------------
sub test_setHybridNoArg {
    # ...
    # Test the setHybrid method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setHybrid();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $hybrid = $typeDataObj -> getHybrid();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $hybrid);
    return;
}

#==========================================
# test_setHybridUnknownArg
#------------------------------------------
sub test_setHybridUnknownArg {
    # ...
    # Test the setHybrid method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setHybrid('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setHybrid: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $hybrid = $typeDataObj -> getHybrid();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $hybrid);
    return;
}

#==========================================
# test_setHybridPersistent
#------------------------------------------
sub test_setHybridPersistent {
    # ...
    # Test the setHybridPersistent method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setHybridPersistent('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $hybrid = $typeDataObj -> getHybridPersistent();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $hybrid);
    return;
}

#==========================================
# test_setHybridPersistentFileSystem
#------------------------------------------
sub test_setHybridPersistentFileSystem {
    # ...
    # Test the setHybridPersistentFileSystem method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setHybridPersistentFileSystem('fat');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $hybrid_fs = $typeDataObj -> getHybridPersistentFileSystem();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('fat', $hybrid_fs);
    return;
}

#==========================================
# test_setHybridPersistentNoArg
#------------------------------------------
sub test_setHybridPersistentNoArg {
    # ...
    # Test the setHybridPersistent method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setHybridPersistent();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $hybrid = $typeDataObj -> getHybridPersistent();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $hybrid);
    return;
}

#==========================================
# test_setHybridPersistentUnknownArg
#------------------------------------------
sub test_setHybridPersistentUnknownArg {
    # ...
    # Test the setHybridPersistent method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setHybridPersistent('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setHybridPersistent: unrecognized '
        . 'argument expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $hybrid = $typeDataObj -> getHybridPersistent();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $hybrid);
    return;
}

#==========================================
# test_setInstallBoot
#------------------------------------------
sub test_setInstallBoot {
    # ...
    # Test the setInstallBoot method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setInstallBoot('failsafe-install');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $opt = $typeDataObj -> getInstallBoot();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('failsafe-install', $opt);
    return;
}

#==========================================
# test_setInstallBootInvalidArg
#------------------------------------------
sub test_setInstallBootInvalidArg {
    # ...
    # Test the setInstallBoot method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallBoot('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setInstallBoot: specified installboot option '
        . "'foo' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $opt = $typeDataObj -> getInstallBoot();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('install', $opt);
    return;
}

#==========================================
# test_setInstallBootNoArg
#------------------------------------------
sub test_setInstallBootNoArg {
    # ...
    # Test the setInstallBoot method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallBoot();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setInstallBoot: no installboot argument specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $opt = $typeDataObj -> getInstallBoot();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('install', $opt);
    return;
}

#==========================================
# test_setInstallProvideFailsafe
#------------------------------------------
sub test_setInstallProvideFailsafe {
    # ...
    # Test the setInstallProvideFailsafe method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setInstallProvideFailsafe('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $failS = $typeDataObj -> getInstallProvideFailsafe();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $failS);
    return;
}

#==========================================
# test_setInstallProvideFailsafeNoArg
#------------------------------------------
sub test_setInstallProvideFailsafeNoArg {
    # ...
    # Test the setInstallProvideFailsafe method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallProvideFailsafe();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $failS = $typeDataObj -> getInstallProvideFailsafe();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $failS);
    return;
}

#==========================================
# test_setInstallProvideFailsafeUnknownArg
#------------------------------------------
sub test_setInstallProvideFailsafeUnknownArg {
    # ...
    # Test the setInstallProvideFailsafe method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallProvideFailsafe('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setInstallProvideFailsafe: unrecognized '
        . 'argument expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $failS = $typeDataObj -> getInstallProvideFailsafe();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $failS);
    return;
}

#==========================================
# test_setInstallIso
#------------------------------------------
sub test_setInstallIso {
    # ...
    # Test the setInstallIso method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setInstallIso('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $iso = $typeDataObj -> getInstallIso();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $iso);
    return;
}

#==========================================
# test_setInstallIsoNoArg
#------------------------------------------
sub test_setInstallIsoNoArg {
    # ...
    # Test the setInstallIso method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallIso();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $iso = $typeDataObj -> getInstallIso();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $iso);
    return;
}

#==========================================
# test_setInstallIsoUnknownArg
#------------------------------------------
sub test_setInstallIsoUnknownArg {
    # ...
    # Test the setInstallIso method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallIso('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setInstallIso: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $iso = $typeDataObj -> getInstallIso();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $iso);
    return;
}

#==========================================
# test_setInstallPXE
#------------------------------------------
sub test_setInstallPXE {
    # ...
    # Test the setInstallPXE method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setInstallPXE('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $failS = $typeDataObj -> getInstallPXE();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $failS);
    return;
}

#==========================================
# test_setInstallPXENoArg
#------------------------------------------
sub test_setInstallPXENoArg {
    # ...
    # Test the setInstallPXE method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallPXE();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $failS = $typeDataObj -> getInstallPXE();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $failS);
    return;
}

#==========================================
# test_setInstallPXEUnknownArg
#------------------------------------------
sub test_setInstallPXEUnknownArg {
    # ...
    # Test the setInstallPXE method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallPXE('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setInstallPXE: unrecognized '
        . 'argument expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $failS = $typeDataObj -> getInstallPXE();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $failS);
    return;
}

#==========================================
# test_setInstallStick
#------------------------------------------
sub test_setInstallStick {
    # ...
    # Test the setInstallStick method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setInstallStick('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $stick = $typeDataObj -> getInstallStick();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $stick);
    return;
}

#==========================================
# test_setInstallStickNoArg
#------------------------------------------
sub test_setInstallStickNoArg {
    # ...
    # Test the setInstallStick method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallStick();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $stick = $typeDataObj -> getInstallStick();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $stick);
    return;
}

#==========================================
# test_setInstallStickUnknownArg
#------------------------------------------
sub test_setInstallStickUnknownArg {
    # ...
    # Test the setInstallStick method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setInstallStick('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setInstallStick: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $stick = $typeDataObj -> getInstallStick();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $stick);
    return;
}

#==========================================
# test_setKernelCmdOpts
#------------------------------------------
sub test_setKernelCmdOpts {
    # ...
    # Test the setKernelCmdOpts method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setKernelCmdOpts('init=/bin/sh');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $opt = $typeDataObj -> getKernelCmdOpts();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('init=/bin/sh', $opt);
    return;
}

#==========================================
# test_setKernelCmdOptsNoArg
#------------------------------------------
sub test_setKernelCmdOptsNoArg {
    # ...
    # Test the setKernelCmdOpts method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setKernelCmdOpts();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setKernelCmdOpts: no options given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $opt = $typeDataObj -> getKernelCmdOpts();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('kiwidebug=1', $opt);
    return;
}

#==========================================
# test_setLuksPass
#------------------------------------------
sub test_setLuksPass {
    # ...
    # Test the setLuksPass method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setLuksPass('mySecret');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $pass = $typeDataObj -> getLuksPass();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('mySecret', $pass);
    return;
}

#==========================================
# test_setLuksPassNoArg
#------------------------------------------
sub test_setLuksPassNoArg {
    # ...
    # Test the setLuksPass method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setLuksPass();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setLuksPass: no password given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $pass = $typeDataObj -> getLuksPass();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('notApass', $pass);
    return;
}

#==========================================
# test_setMDRaid
#------------------------------------------
sub test_setMDRaid {
    # ...
    # Test the setMDRaid method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setMDRaid('mirroring');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $fs = $typeDataObj -> getMDRaid();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('mirroring', $fs);
    return;
}

#==========================================
# test_setMDRaidInvalidArg
#------------------------------------------
sub test_setMDRaidInvalidArg {
    # ...
    # Test the setMDRaid method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setMDRaid('raid1');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setMDRaid: specified raid type '
        . "'raid1' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $fs = $typeDataObj -> getMDRaid();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('striping', $fs);
    return;
}

#==========================================
# test_setMDRaidNoArg
#------------------------------------------
sub test_setMDRaidNoArg {
    # ...
    # Test the setMDRaid method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setMDRaid();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setMDRaid: no raid type specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $raidt = $typeDataObj -> getMDRaid();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('striping', $raidt);
    return;
}

#==========================================
# test_setPrimary
#------------------------------------------
sub test_setPrimary {
    # ...
    # Test the setPrimary method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setPrimary('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $prim = $typeDataObj -> getPrimary();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $prim);
    return;
}

#==========================================
# test_setPrimaryNoArg
#------------------------------------------
sub test_setPrimaryNoArg {
    # ...
    # Test the setPrimary method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setPrimary();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $prim = $typeDataObj -> getPrimary();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $prim);
    return;
}

#==========================================
# test_setPrimaryUnknownArg
#------------------------------------------
sub test_setPrimaryUnknownArg {
    # ...
    # Test the setPrimary method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setPrimary('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setPrimary: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $prim = $typeDataObj -> getPrimary();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $prim);
    return;
}

#==========================================
# test_setRAMOnly
#------------------------------------------
sub test_setRAMOnly {
    # ...
    # Test the setRAMOnly method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setRAMOnly('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $ramO = $typeDataObj -> getRAMOnly();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $ramO);
    return;
}

#==========================================
# test_setRAMOnlyNoArg
#------------------------------------------
sub test_setRAMOnlyNoArg {
    # ...
    # Test the setRAMOnly method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setRAMOnly();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $ramO = $typeDataObj -> getRAMOnly();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('false', $ramO);
    return;
}

#==========================================
# test_setRAMOnlyUnknownArg
#------------------------------------------
sub test_setRAMOnlyUnknownArg {
    # ...
    # Test the setRAMOnly method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setRAMOnly('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setRAMOnly: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $ramO = $typeDataObj -> getRAMOnly();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('true', $ramO);
    return;
}

#==========================================
# test_setSize
#------------------------------------------
sub test_setSize {
    # ...
    # Test the setSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setSize('4096');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $size = $typeDataObj -> getSize();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_equals($SMALL_IMAGE, $size);
    return;
}

#==========================================
# test_setSizeNoArg
#------------------------------------------
sub test_setSizeNoArg {
    # ...
    # Test the setSize method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setSize();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setSize: no systemsize value given, retaining '
        . 'current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $size = $typeDataObj -> getSize();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_equals($IMAGE_SIZE, $size);
    return;
}

#==========================================
# test_setSizeAdditive
#------------------------------------------
sub test_setSizeAdditive {
    # ...
    # Test the setSizeAdditive method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setSizeAdditive('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $add = $typeDataObj -> isSizeAdditive();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('1', $add);
    return;
}

#==========================================
# test_setSizeAdditiveNoArg
#------------------------------------------
sub test_setSizeAdditiveNoArg {
    # ...
    # Test the setSizeAdditive method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setSizeAdditive();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $add = $typeDataObj -> isSizeAdditive();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('0', $add);
    return;
}

#==========================================
# test_setSizeAdditiveUnknownArg
#------------------------------------------
sub test_setSizeAdditiveUnknownArg {
    # ...
    # Test the setSizeAdditive method with an unrecognized argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setSizeAdditive('5');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLTypeData:setSizeAdditive: unrecognized argument '
        . 'expecting "true" or "false".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $add = $typeDataObj -> isSizeAdditive();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('1', $add);
    return;
}

#==========================================
# test_setSizeUnit
#------------------------------------------
sub test_setSizeUnit {
    # ...
    # Test the setSizeUnit method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setSizeUnit('G');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $unit = $typeDataObj -> getSizeUnit();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('G', $unit);
    return;
}

#==========================================
# test_setSizeUnitInvalidArg
#------------------------------------------
sub test_setSizeUnitInvalidArg {
    # ...
    # Test the setSizeUnit method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setSizeUnit('K');
    my $msg = $kiwi -> getMessage();
    my $expected = "setSizeUnit: expecting unit setting of 'M' or 'G'.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $unit = $typeDataObj -> getSizeUnit();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('M', $unit);
    return;
}

#==========================================
# test_setSizeUnitNoArg
#------------------------------------------
sub test_setSizeUnitNoArg {
    # ...
    # Test the setSizeUnit method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setSizeUnit();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setSizeUnit: no systemsize unit value given, retaining '
        . 'current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $unit = $typeDataObj -> getSizeUnit();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('M', $unit);
    return;
}

#==========================================
# test_setTypeName
#------------------------------------------
sub test_setTypeName {
    # ...
    # Test the setTypeName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setTypeName('tbz');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $type = $typeDataObj -> getTypeName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('tbz', $type);
    return;
}

#==========================================
# test_setTypeNameInvalidArg
#------------------------------------------
sub test_setTypeNameInvalidArg {
    # ...
    # Test the setTypeName method with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setTypeName('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setTypeName: specified image '
        . "'foo' is not supported.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $type = $typeDataObj -> getTypeName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('oem', $type);
    return;
}

#==========================================
# test_setTypeNameNoArg
#------------------------------------------
sub test_setTypeNameNoArg {
    # ...
    # Test the setTypeName method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setTypeName();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setTypeName: no image argument specified, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $type = $typeDataObj -> getTypeName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('oem', $type);
    return;
}

#==========================================
# test_setVGA
#------------------------------------------
sub test_setVGA {
    # ...
    # Test the setVGA method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setVGA('0x348');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $vga = $typeDataObj -> getVGA();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('0x348', $vga);
    return;
}

#==========================================
# test_setVGANoArg
#------------------------------------------
sub test_setVGANoArg {
    # ...
    # Test the setVGA method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setVGA();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVGA: no VGA value given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $vga = $typeDataObj -> getVGA();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('0x344', $vga);
    return;
}

#==========================================
# test_setVHDFixedTag
#------------------------------------------
sub test_setVHDFixedTag {
    # ...
    # Test the setVHDFixedTag method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setVHDFixedTag('98765432');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $tag = $typeDataObj -> getVHDFixedTag();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('98765432', $tag);
    return;
}

#==========================================
# test_setGCELicense
#------------------------------------------
sub test_setGCELicense {
    # ...
    # Test the setGCELicense method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setGCELicense('foo');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $tag = $typeDataObj -> getGCELicense();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType(); 
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('foo', $tag);
    return;
}

#==========================================
# test_setVHDFixedTagNoArg
#------------------------------------------
sub test_setVHDFixedTagNoArg {
    # ...
    # Test the setVHDFixedTag method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setVHDFixedTag();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVHDFixedTag: no tag given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $tag = $typeDataObj -> getVHDFixedTag();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('12345678', $tag);
    return;
}

#==========================================
# test_setGCELicense
#------------------------------------------
sub test_setGCELicenseNoArg {
    # ...
    # Test the setGCELicense method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setGCELicense();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setGCELicense: no license tag given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $tag = $typeDataObj -> getGCELicense();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('0815', $tag);
    return;
}

#==========================================
# test_setVolID
#------------------------------------------
sub test_setVolID {
    # ...
    # Test the setVolID method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    $typeDataObj = $typeDataObj -> setVolID('myDist');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($typeDataObj);
    my $volID = $typeDataObj -> getVolID();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myDist', $volID);
    return;
}

#==========================================
# test_setVolIDNoArg
#------------------------------------------
sub test_setVolIDNoArg {
    # ...
    # Test the setVolID method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $typeDataObj = $this -> __getTypeObj();
    my $res = $typeDataObj -> setVolID();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolID: no volume ID given, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    my $volID = $typeDataObj -> getVolID();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myImg', $volID);
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getTypeObj
#------------------------------------------
sub __getTypeObj {
    # ...
    # Helper to construct a fully populated Type object using
    # initialization, the seetings in combination do not really make sense.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my %init = (
                boot                   => '/oem/suse-12.2',
                bootfilesystem         => 'fat32',
                bootkernel             => 'xenk',
                bootloader             => 'grub2',
                zipl_targettype        => 'FBA',
                target_blocksize       => '4096',
                bootpartition          => 'true',
                bootpartsize           => '512',
                bootprofile            => 'std',
                boottimeout            => '5',
                checkprebuilt          => 'true',
                compressed             => 'true',
                container              => 'mycont',
                devicepersistency      => 'by-uuid',
                editbootconfig         => 'myscript',
                editbootinstall        => 'myInstScript',
                filesystem             => 'xfs',
                firmware               => 'efi',
                flags                  => 'compressed',
                format                 => 'qcow2',
                formatoptions          => 'compat=bob,name=xxx',
                fsmountoptions         => 'barrier',
                fsnocheck              => 'true',
                fsreadonly             => 'ext3',
                fsreadwrite            => 'xfs',
                gcelicense             => '0815',
                hybrid                 => 'true',
                hybridpersistent       => 'true',
                hybridpersistent_filesystem => 'btrfs',
                image                  => 'oem',
                installboot            => 'install',
                installiso             => 'true',
                installprovidefailsafe => 'true',
                installpxe             => 'false',
                installstick           => 'true',
                kernelcmdline          => 'kiwidebug=1',
                luks                   => 'notApass',
                luksOS                 => 'sle11',
                mdraid                 => 'striping',
                primary                => 'true',
                ramonly                => 'true',
                size                   => '16384',
                sizeadd                => 'true',
                sizeunit               => 'M',
                vga                    => '0x344',
                vhdfixedtag            => '12345678',
                volid                  => 'myImg'
            );
    my $typeDataObj = KIWIXMLTypeData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($typeDataObj);
    return $typeDataObj;
}

1;
