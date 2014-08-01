#================
# FILE          : kiwiXMLProductPackageData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIProductPackageData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLProductPackageData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLProductPackageData;

use Data::Dumper;

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
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
    # ...
    # Test the ProductPackageData constructor
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = KIWIXMLProductPackageData -> new();
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = 'KIWIXMLProductPackageData: must be constructed with a '
        . 'keyword hash as argument';
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($pckgDataObj);
    return;
}

#==========================================
# test_ctor_simple
#------------------------------------------
sub test_ctor_simple {
    # ...
    # Test proper construction with only the name argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( name => 'libtiff' );
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($pckgDataObj);
    return;
}

#==========================================
# test_ctor_unsuportedAddArchValue
#------------------------------------------
sub test_ctor_unsuportedAddArchValue {
    # ...
    # Test the ProductPackageData constructor with an invalid value for the
    # bootdelete keyword
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
            addarch => 'tegra',
        name    => 'python'
    );
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = "Specified arch 'tegra' is not supported";
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($pckgDataObj);
    return;
}

#==========================================
# test_ctor_unsuportedArch
#------------------------------------------
sub test_ctor_unsuportedArch {
    # ...
    # Test the ProductPackageData constructor with an unsupported architecture
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
            arch => 'tegra',
        name => 'dia'
    );
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = "Specified arch 'tegra' is not supported";
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($pckgDataObj);
    return;
}

#==========================================
# test_ctor_unsupportedKW
#------------------------------------------
sub test_ctor_unsupportedKW {
    # ...
    # Test constructor with an unsupported keyword in the initialization data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                arch     => 'ppc64',
                filename => 'zypper'
    );
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = 'KIWIXMLProductPackageData: Unsupported keyword '
        . "argument 'filename' in initialization structure.";
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($pckgDataObj);
    return;
}

#==========================================
# test_ctor_unsuportedOnlyArch
#------------------------------------------
sub test_ctor_unsuportedOnlyArch {
    # ...
    # Test the ProductPackageData constructor with an unsupported architecture
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        name     => 'dia',
            onlyarch => 'tegra'
    );
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = "Specified arch 'tegra' is not supported";
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($pckgDataObj);
    return;
}

#==========================================
# test_ctor_withArch
#------------------------------------------
sub test_ctor_withArch {
    # ...
    # Test proper construction with only the name argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
                arch => 'ppc64',
                name => 'libpng'
    );
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($pckgDataObj);
    return;
}

#==========================================
# test_getAdditionalArch
#------------------------------------------
sub test_getAdditionalArch {
    # ...
    # Verify that the addarch setting is properly returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $arch = $pckgDataObj -> getAdditionalArch();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('s390', $arch);
    return;
}

#==========================================
# test_getArch
#------------------------------------------
sub test_getArch {
    # ...
    # Verify that the arch setting is properly returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $arch = $pckgDataObj -> getArch();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('x86_64', $arch);
    return;
}

#==========================================
# test_getForceRepo
#------------------------------------------
sub test_getForceRepo {
    # ...
    # Verify that the forcerepo setting is properly returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $force = $pckgDataObj -> getForceRepo();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('2', $force);
    return;
}

#==========================================
# test_getMediaID
#------------------------------------------
sub test_getMediaID {
    # ...
    # Verify that the forcerepo setting is properly returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $id = $pckgDataObj -> getMediaID();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('5', $id);
    return;
}

#==========================================
# test_getName
#------------------------------------------
sub test_getName {
    # ...
    # Verify that the proper name is returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $name = $pckgDataObj -> getName();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('python', $name);
    return;
}

#==========================================
# test_getOnlyArch
#------------------------------------------
sub test_geOnlyArch {
    # ...
    # Verify that the proper onlyarch setting is returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $arch = $pckgDataObj -> getOnlyArch();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('x86_64', $arch);
    return;
}

#==========================================
# test_getRemoveArch
#------------------------------------------
sub test_geRemoveArch {
    # ...
    # Verify that the proper onlyarch setting is returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $regex = $pckgDataObj -> getRemoveArch();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('src', $regex);
    return;
}

#==========================================
# test_getScriptPath
#------------------------------------------
sub test_geScriptPath {
    # ...
    # Verify that the proper script setting is returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $script = $pckgDataObj -> getScriptPath();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('myScript.csh', $script);
    return;
}

#==========================================
# test_getSourceLocation
#------------------------------------------
sub test_geSourceLocation {
    # ...
    # Verify that the proper source setting is returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $source = $pckgDataObj -> getSourceLocation();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('http:///download', $source);
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
    my $pckgDataObj = $this -> __getPckgDataObj();
    my $elem = $pckgDataObj -> getXMLElement();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($elem);
    my $xmlstr = $elem -> toString();
    my $expected = '<repopackage '
        . 'name="python" '
        . 'arch="x86_64" '
        . 'addarch="s390" '
        . 'forcerepo="2" '
        . 'medium="5" '
        . 'onlyarch="x86_64" '
        . 'removearch="src" '
        . 'script="myScript.csh" '
        . 'source="http:///download"/>';
    $this -> assert_str_equals($expected, $xmlstr);
    return;
}

#==========================================
# test_setArch
#------------------------------------------
sub test_setArch {
    # ...
    # Verify that the proper architecture value is set and returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( name => 'libzypp');
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $value = $pckgDataObj -> setArch('x86_64');
    $this -> assert_equals(1, $value);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $arch = $pckgDataObj -> getArch();
    $this -> assert_str_equals('x86_64', $arch);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($pckgDataObj);
    return;
}

#==========================================
# test_setArch_invalid
#------------------------------------------
sub test_setArch_invalid {
    # ...
    # Verify proper error condition handling for setArch().
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( name => 'snapper');
    my $pckgDataObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $value = $pckgDataObj -> setArch('tegra');
    my $expectedMsg = "Specified arch 'tegra' is not supported";
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals($expectedMsg, $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($value);
    $value = $pckgDataObj -> getArch();
    $this -> assert_null($value);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($pckgDataObj);
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getPckgDataObj
#------------------------------------------
sub __getPckgDataObj {
    # ...
    # Helper to construct a fully populated ProductPackageData object.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my %init = (
        addarch     => 's390',
        arch        => 'x86_64',
        forcerepo   => '2',
        medium      => '5',
        name        => 'python',
        onlyarch    => 'x86_64',
        removearch  => 'src',
        script      => 'myScript.csh',
        source      => 'http:///download'
    );
    my $pckgObj = KIWIXMLProductPackageData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($pckgObj);
    return $pckgObj;
}

1;
