#================
# FILE          : kiwiXMLSystemdiskData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLSystemdiskData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLSystemdiskData;

use strict;
use warnings;
use Readonly;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLSystemdiskData;

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
# test_createVolume
#------------------------------------------
sub test_createVolume {
    # ...
    # Test the SystemdiskData createVolume method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $id = $sysdDataObj -> createVolume('newVOL');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_equals($id, 1);
    my $name = $sysdDataObj -> getVolumeName($id);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('newVOL', $name);
    return;
}

#==========================================
# test_createVolumeDisallowedName
#------------------------------------------
sub test_createVolumeDisallowedName {
    # ...
    # Test the SystemdiskData createVolume method with a disallowed
    # volume name
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $id = $sysdDataObj -> createVolume('boot');
    my $msg = $kiwi -> getMessage();
    my $expected = "createVolume: found disallowed name 'boot'.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeNameDisallowedInInit
#------------------------------------------
sub test_createVolumeNameDisallowedInInit {
    # ...
    # Test the SystemdiskData createVolume method with an existsing
    # volume name in the initialization hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                name => 'proc',
                size => '50G'
            );
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $id = $sysdDataObj -> createVolume(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = "createVolume: found disallowed name 'proc'.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeDuplicateName
#------------------------------------------
sub test_createVolumeDuplicateName {
    # ...
    # Test the SystemdiskData createVolume method with an existsing
    # volume name
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $id = $sysdDataObj -> createVolume('data_VOL');
    my $msg = $kiwi -> getMessage();
    my $expected = "createVolume: volume definition for name 'data_VOL' "
        . 'already exists, ambiguous operation.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeDuplicateNameInInit
#------------------------------------------
sub test_createVolumeDuplicateNameInInit {
    # ...
    # Test the SystemdiskData createVolume method with an existsing
    # volume name in the initialization hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                name => 'data_VOL',
                size => '50G'
            );
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $id = $sysdDataObj -> createVolume(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = "createVolume: volume definition for name 'data_VOL' "
        . 'already exists, ambiguous operation.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeInvalidName
#------------------------------------------
sub test_createVolumeInvalidName {
    # ...
    # Test the SystemdiskData createVolume method with an invalid volume name
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $id = $sysdDataObj -> createVolume('t*Vol');
    my $msg = $kiwi -> getMessage();
    my $expected = 'createVolume: improper volume name found.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeInvalidNameInit
#------------------------------------------
sub test_createVolumeInvalidNameInit {
    # ...
    # Test the SystemdiskData createVolume method with an invalid volume name
    # value with init hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                name => 'test VG',
                size => '50G'
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $id = $sysdDataObj -> createVolume(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'createVolume: improper volume name found.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeIvalidNoArg
#------------------------------------------
sub test_createVolumeIvalidNNoArg {
    # ...
    # Test the SystemdiskData createVolume method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $id = $sysdDataObj -> createVolume();
    my $msg = $kiwi -> getMessage();
    my $expected = 'createVolume: expecting hash ref with volume data as '
        . 'argument';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeMissingNameData
#------------------------------------------
sub test_createVolumeMissingNameData {
    # ...
    # Test the SystemdiskData createVolume method with an initialization
    # hash misisng the name entry
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                freespace => '5G',
                size      => '50G'
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $id = $sysdDataObj -> createVolume(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'createVolume: initialization data must contain '
        . 'value for "name".';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeUnsupportedData
#------------------------------------------
sub test_createVolumeUnsupportedData {
    # ...
    # Test the SystemdiskData createVolume method with an unsupported data
    # entry in the init hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                volName => 'test VG',
                size    => '50G'
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $id = $sysdDataObj -> createVolume(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = "createVolume: found unsupported setting 'volName' "
        . 'in initialization hash.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($id);
    return;
}

#==========================================
# test_createVolumeWInit
#------------------------------------------
sub test_createVolumeWInit {
    # ...
    # Test the SystemdiskData createVolume method with an initialization
    # hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                freespace => '20M',
                name      => 'new_VOL',
                size      => '50G'
            );
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $id = $sysdDataObj -> createVolume(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $free = $sysdDataObj -> getVolumeFreespace($id);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('20M', $free);
    my $name = $sysdDataObj -> getVolumeName($id);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('new_VOL', $name);
    my $size = $sysdDataObj -> getVolumeSize($id);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('50G', $size);
    return;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
    # ...
    # Test the SystemdiskData constructor
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_disallowedVoName
#------------------------------------------
sub test_ctor_disallowedVoName {
    # ...
    # Test the SystemdiskData constructor with disallowed volume names in
    # the initialization hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %vol1 = (
                freespace => '20M',
                name      => 'sys',
                size      => '30G'
            );
    my %vol2 = (
                name      => 'data_VOL',
                size      => '100G'
            );
    my %volumes = ( 1 => \%vol1,
                    2 => \%vol2
                );
    my %init = (
                name => 'testVG',
                volumes => \%volumes
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = "object initialization: found disallowed name 'sys'.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_duplicateVoName
#------------------------------------------
sub test_ctor_duplicateVoName {
    # ...
    # Test the SystemdiskData constructor with duplicate volume names in
    # the initialization hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %vol1 = (
                freespace => '20M',
                name      => 'data_VOL',
                size      => '30G'
            );
    my %vol2 = (
                name      => 'data_VOL',
                size      => '100G'
            );
    my %volumes = ( 1 => \%vol1,
                    2 => \%vol2
                );
    my %init = (
                name => 'testVG',
                volumes => \%volumes
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'Duplicate volume name in initialization '
        . 'structure, ambiguous operation.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
    # ...
    # Test the SystemdiskData constructor with an improper argument type
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'Expecting a hash ref as first argument if provided';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_improperDataArg
#------------------------------------------
sub test_ctor_improperDataArg {
    # ...
    # Test the SystemdiskData constructor with an improper entry in the
    # initialization structure
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                name    => 'testVG',
                volumes => 'foo'
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'Expecting hash ref as entry for "volumes" in '
        . 'initialization structure.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}


#==========================================
# test_ctor_improperIDDataEntry
#------------------------------------------
sub test_ctor_improperIDDataEntry {
    # ...
    # Test the SystemdiskData constructor with an improper type for the
    # volume entry identifier
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %vol = (
            freespace => '20M',
                name      => 'test_VOL'
            );
    my %volumes = ( 'foo' => \%vol );
    my %init = (
                name => 'testVG',
                volumes => \%volumes
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'Expecting integer as key for "volumes" initialization.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_incompleteData
#------------------------------------------
sub test_ctor_incompleteData {
    # ...
    # Test the SystemdiskData constructor with incomplete data for the
    # volume initialization
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %vol = ( freespace => '20M' );
    my %volumes = ( 1 => \%vol );
    my %init = (
                name => 'testVG',
                volumes => \%volumes
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'Initialization data for "volumes" is incomplete, '
        . 'missing "name" entry.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_invalidVolName
#------------------------------------------
sub test_ctor_invalidVolName {
    # ...
    # Test the SystemdiskData constructor with an invalid entry for the
    # volume name in the initialization data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %vol = (
            freespace => '20M',
            name      => 'foo!bar'
            );
    my %volumes = ( 1 => \%vol );
    my %init = (
                name => 'testVG',
                volumes => \%volumes
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: improper volume name found.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedEntry
#------------------------------------------
sub test_ctor_initUnsupportedEntry {
    # ...
    # Test the SystemdiskData constructor with an unsupported initialization
    # data entry
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( name => 'testVG',
                foo  => 'bar'
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLSystemdiskData: Unsupported keyword argument '
        . "'foo' in initialization structure.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedVolDataEntry
#------------------------------------------
sub test_ctor_initUnsupportedVolDataEntry{
    # ...
    # Test the SystemdiskData constructor with an unsupported entry for the
    # volume data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %vol = (
            filesys   => 'ext4',
            freespace => '20M',
            name      => 'test_VOL'
            );
    my %volumes = ( 1 => \%vol );
    my %init = (
                name => 'testVG',
                volumes => \%volumes
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'Unsupported option in initialization structure '
        . "for 'volumes', found 'filesys'";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($sysdDataObj);
    return;
}

#==========================================
# test_ctor_wIni
#------------------------------------------
sub test_ctor_wIni {
    # ...
    # Test the SystemdiskData constructor with a valid initialization hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %vol = (
            freespace => '20M',
            name      => 'test_VOL'
            );
    my %volumes = ( 1 => \%vol );
    my %init = (
                name => 'testVG',
                volumes => \%volumes
            );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($sysdDataObj);
    return;
}

#==========================================
# test_getVGName
#------------------------------------------
sub test_getVGName {
    # ...
    # Test the getVGName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $name = $sysdDataObj -> getVGName();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('testVG', $name);
    return;
}

#==========================================
# test_getLVMVolumeManagement
#------------------------------------------
sub test_getLVMVolumeManagement {
    # ...
    # Test the getLVMVolumeManagement method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $name = $sysdDataObj -> getLVMVolumeManagement();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals(0, $name);
    return;
}

#==========================================
# test_getVGNameDefault
#------------------------------------------
sub test_getVGNameDefault {
    # ...
    # Test the getVGName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $name = $sysdDataObj -> getVGName();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('kiwiVG', $name);
    return;
}

#==========================================
# test_getVolumeFreespace
#------------------------------------------
sub test_getVolumeFreespace {
    # ...
    # Test the getVolumeFreespace method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $free = $sysdDataObj -> getVolumeFreespace('1');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('20M', $free);
    return;
}

#==========================================
# test_getVolumeFreespaceInvalidID
#------------------------------------------
sub test_getVolumeFreespaceInvalidID {
    # ...
    # Test the getVolumeFreespace method with an invalid ID arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $free = $sysdDataObj -> getVolumeFreespace('3');
    my $msg = $kiwi -> getMessage();
    my $expected = 'getVolumeFreespace: invalid ID for volume data access '
        . 'given, no data exists.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($free);
    return;
}

#==========================================
# test_getVolumeFreespaceNoArg
#------------------------------------------
sub test_getVolumeFreespaceNoArg {
    # ...
    # Test the getVolumeFreespace method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $free = $sysdDataObj -> getVolumeFreespace();
    my $msg = $kiwi -> getMessage();
    my $expected = 'getVolumeFreespace: called without providing ID for '
        . 'volume data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($free);
    return;
}

#==========================================
# test_getVolumeIDs
#------------------------------------------
sub test_getVolumeIDs {
    # ...
    # Test the getVolumeIDs method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $ids = $sysdDataObj -> getVolumeIDs();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my @expected = ( 1, 2 );
    $this->assert_array_equal(\@expected, $ids);
    return;
}

#==========================================
# test_getVolumeName
#------------------------------------------
sub test_getVolumeName {
    # ...
    # Test the getVolumeName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $name = $sysdDataObj -> getVolumeName('1');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('test_VOL', $name);
    return;
}

#==========================================
# test_getVolumeNameInvalidID
#------------------------------------------
sub test_getVolumeNameInvalidID {
    # ...
    # Test the getVolumeName method with an invalid ID arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $name = $sysdDataObj -> getVolumeName('3');
    my $msg = $kiwi -> getMessage();
    my $expected = 'getVolumeName: invalid ID for volume data access '
        . 'given, no data exists.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($name);
    return;
}

#==========================================
# test_getVolumeNameNoArg
#------------------------------------------
sub test_getVolumeNameNoArg {
    # ...
    # Test the getVolumeName method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $name = $sysdDataObj -> getVolumeName();
    my $msg = $kiwi -> getMessage();
    my $expected = 'getVolumeName: called without providing ID for '
        . 'volume data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($name);
    return;
}

#==========================================
# test_getVolumeSize
#------------------------------------------
sub test_getVolumeSize {
    # ...
    # Test the getVolumeSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $size = $sysdDataObj -> getVolumeSize('1');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('30G', $size);
    return;
}

#==========================================
# test_getVolumeSizeInvalidID
#------------------------------------------
sub test_getVolumeSizeInvalidID {
    # ...
    # Test the getVolumeSize method with an invalid ID arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $size = $sysdDataObj -> getVolumeSize('3');
    my $msg = $kiwi -> getMessage();
    my $expected = 'getVolumeSize: invalid ID for volume data access '
        . 'given, no data exists.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($size);
    return;
}

#==========================================
# test_getVolumeSizeNoArg
#------------------------------------------
sub test_getVolumeSizeNoArg {
    # ...
    # Test the getVolumeSize method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $size = $sysdDataObj -> getVolumeSize();
    my $msg = $kiwi -> getMessage();
    my $expected = 'getVolumeSize: called without providing ID for '
        . 'volume data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($size);
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
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $elem = $sysdDataObj -> getXMLElement();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($elem);
    my $xmlstr = $elem -> toString();
    my $expected = '<systemdisk name="testVG" '
        . 'preferlvm="false">'
        . '<volume name="test_VOL" freespace="20M" size="30G"/>'
        . '<volume name="data_VOL" size="100G"/>'
        . '</systemdisk>';
    $this -> assert_str_equals($expected, $xmlstr);
    return;
}

#==========================================
# test_setVGName
#------------------------------------------
sub test_setVGName {
    # ...
    # Test the setVGName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    $sysdDataObj = $sysdDataObj -> setVGName('foo_VG');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($sysdDataObj);
    my $name = $sysdDataObj -> getVGName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('foo_VG', $name);
    return;
}

#==========================================
# test_setLVMVolumeManagement
#------------------------------------------
sub test_setLVMVolumeManagement {
    # ...
    # Test the setLVMVolumeManagement method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    $sysdDataObj = $sysdDataObj -> setLVMVolumeManagement('true');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($sysdDataObj);
    my $name = $sysdDataObj -> getLVMVolumeManagement();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals(1, $name);
    return;
}

#==========================================
# test_setVGNameInvalidName
#------------------------------------------
sub test_setVGNameInvalidName {
    # ...
    # Test the setVGName method with an invalid name argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVGName('foo VG');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVGName: improper volume name found.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    my $name = $sysdDataObj -> getVGName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('testVG', $name);
    return;
}

#==========================================
# test_setVGNameNoArg
#------------------------------------------
sub test_setVGNameNoArg {
    # ...
    # Test the setVGName method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $res = $sysdDataObj -> setVGName();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVGName: no volume group name argument provided, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    my $name = $sysdDataObj -> getVGName();
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('kiwiVG', $name);
    return;
}

#==========================================
# test_setVolumeFreespace
#------------------------------------------
sub test_setVolumeFreespace {
    # ...
    # Test the setVolumeFreespace method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    $sysdDataObj = $sysdDataObj -> setVolumeFreespace(2, '50G');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($sysdDataObj);
    my $free = $sysdDataObj -> getVolumeFreespace(2);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('50G', $free);
    return;
}

#==========================================
# test_setVolumeFreespaceInvalidID
#------------------------------------------
sub test_setVolumeFreespaceInvalidID {
    # ...
    # Test the setVolumeFreespace method with an invalid ID arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeFreespace('3', '20M');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeFreespace: invalid ID for volume data access '
        . 'given, no data exists.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeFreespaceNoArg
#------------------------------------------
sub test_setVolumeFreespaceNoArg {
    # ...
    # Test the setVolumeFreespace method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeFreespace();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeFreespace: called without providing ID for '
        . 'volume data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeFreespaceNoArgFree
#------------------------------------------
sub test_setVolumeFreespaceNoArgFree {
    # ...
    # Test the setVolumeFreespace method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeFreespace(1);
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeFreespace: no setting for freespace provided, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeFreespaceNoVols
#------------------------------------------
sub test_setVolumeFreespaceNoVols {
    # ...
    # Test the setVolumeFreespace method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $res = $sysdDataObj -> setVolumeFreespace(1, '30M');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeFreespace: no volumes configured, call '
        . 'createVolume first.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeName
#------------------------------------------
sub test_setVolumeName {
    # ...
    # Test the setVolumeName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    $sysdDataObj = $sysdDataObj -> setVolumeName(2, 'newVOL');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($sysdDataObj);
    my $name = $sysdDataObj -> getVolumeName(2);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('newVOL', $name);
    return;
}

#==========================================
# test_setVolumeNameDisallowedName
#------------------------------------------
sub test_setVolumeNameDisallowedName {
    # ...
    # Test the setVolumeName method with an invalid Name arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeName('2', 'etc');
    my $msg = $kiwi -> getMessage();
    my $expected =  "setVolumeName: found disallowed name 'etc'.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeNameInvalidID
#------------------------------------------
sub test_setVolumeNameInvalidID {
    # ...
    # Test the setVolumeName method with an invalid ID arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeName('3', 'bar_VOL');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeName: invalid ID for volume data access '
        . 'given, no data exists.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeNameInvalidName
#------------------------------------------
sub test_setVolumeNameInvalidName {
    # ...
    # Test the setVolumeName method with an invalid Name arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeName('2', 'bar VOL');
    my $msg = $kiwi -> getMessage();
    my $expected =  'setVolumeName: improper volume name found.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeNameNoArg
#------------------------------------------
sub test_setVolumeNameNoArg {
    # ...
    # Test the setVolumeName method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeName();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeName: called without providing ID for '
        . 'volume data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeNameNoArgName
#------------------------------------------
sub test_setVolumeNameNoArgName {
    # ...
    # Test the setVolumeName method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeName(1);
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeName: no setting for name provided, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    my $name = $sysdDataObj -> getVolumeName('1');
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('test_VOL', $name);
    return;
}

#==========================================
# test_setVolumeNameNoVols
#------------------------------------------
sub test_setVolumeNameNoVols {
    # ...
    # Test the setVolumeName method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $res = $sysdDataObj -> setVolumeName(1, 'fooVol');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeName: no volumes configured, call '
        . 'createVolume first.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeSize
#------------------------------------------
sub test_setVolumeSize {
    # ...
    # Test the setVolumeSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    $sysdDataObj = $sysdDataObj -> setVolumeSize(2, '50G');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($sysdDataObj);
    my $size = $sysdDataObj -> getVolumeSize(2);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('50G', $size);
    return;
}

#==========================================
# test_setVolumeSizeInvalidID
#------------------------------------------
sub test_setVolumeSizeInvalidID {
    # ...
    # Test the setVolumeSize method with an invalid ID arg
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeSize('3', '20M');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeSize: invalid ID for volume data access '
        . 'given, no data exists.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeSizeNoArg
#------------------------------------------
sub test_setVolumeSizeNoArg {
    # ...
    # Test the setVolumeSize method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeSize();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeSize: called without providing ID for '
        . 'volume data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_setVolumeSizeNoArgSize
#------------------------------------------
sub test_setVolumeSizeNoArgSize {
    # ...
    # Test the setVolumeSize method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = $this -> __getSystemdiskObj();
    my $res = $sysdDataObj -> setVolumeSize(1);
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeSize: no setting for size provided, '
        . 'retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    my $size = $sysdDataObj -> getVolumeSize('1');
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('30G', $size);
    return;
}

#==========================================
# test_setVolumeSizeNoVols
#------------------------------------------
sub test_setVolumeSizeNoVols {
    # ...
    # Test the setVolumeSize method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $sysdDataObj = KIWIXMLSystemdiskData -> new();
    my $res = $sysdDataObj -> setVolumeSize(1, '30M');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setVolumeSize: no volumes configured, call '
        . 'createVolume first.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getSystemdiskObj
#------------------------------------------
sub __getSystemdiskObj {
    # ...
    # Helper to construct a fully populated Systemdisk object using
    # initialization.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my %vol1 = (
        freespace => '20M',
        name      => 'test_VOL',
        size      => '30G'
    );
    my %vol2 = (
        name      => 'data_VOL',
        size      => '100G'
    );
    my %volumes = (
        1 => \%vol1,
        2 => \%vol2
    );
    my %init = (
        name => 'testVG',
        volumes => \%volumes
    );
    my $sysdDataObj = KIWIXMLSystemdiskData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($sysdDataObj);
    return $sysdDataObj;
}

1;
