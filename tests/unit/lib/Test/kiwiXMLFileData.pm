#================
# FILE          : kiwiXMLFileData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLFileData module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLFileData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLFileData;

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
    # Test the FileData constructor with an improper
    # argument type
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fileDataObj = KIWIXMLFileData -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'Expecting a hash ref as first argument if provided';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($fileDataObj);
    return;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
    # ...
    # Test the FileData constructor
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fileDataObj = KIWIXMLFileData -> new();
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = 'KIWIXMLFileData: must be constructed with a '
        . 'keyword hash as argument';
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($fileDataObj);
    return;
}

#==========================================
# test_ctor_unsuportedArch
#------------------------------------------
sub test_ctor_unsuportedArch {
    # ...
    # Test the FileData constructor with an unsupported architecture
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
            arch => 'tegra',
        name => 'soundcore.ko'
    );
    my $fileDataObj = KIWIXMLFileData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = "Specified arch 'tegra' is not supported";
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($fileDataObj);
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
    my %init = ( name => 'soundcore.ko' );
    my $fileDataObj = KIWIXMLFileData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fileDataObj);
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
        filename => 'soundcore.ko'
    );
    my $fileDataObj = KIWIXMLFileData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = 'KIWIXMLFileData: Unsupported keyword argument '
        . "'filename' in initialization structure.";
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($fileDataObj);
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
                name => 'soundcore.ko'
    );
    my $fileDataObj = KIWIXMLFileData -> new(\%init );
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fileDataObj);
    return;
}

#==========================================
# test_getArch
#------------------------------------------
sub test_getArch {
    # ...
    # Verify that the proper architecture value is returned.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
            arch => 'i686',
        name => 'soundcore.ko'
    );
    my $fileDataObj = KIWIXMLFileData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $value = $fileDataObj -> getArch();
    $this -> assert_str_equals('i686', $value);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fileDataObj);
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
    my %init = ( name => 'soundcore.ko' );
    my $fileDataObj = KIWIXMLFileData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $value = $fileDataObj -> getName();
    $this -> assert_str_equals('soundcore.ko', $value);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fileDataObj);
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
    my %init = ( name => 'soundcore.ko' );
    my $fileDataObj = KIWIXMLFileData -> new(\%init );
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $value = $fileDataObj -> setArch('x86_64');
    $this -> assert_equals(1, $value);
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $value = $fileDataObj -> getArch();
    $this -> assert_str_equals('x86_64', $value);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fileDataObj);
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
    my %init = ( name => 'soundcore.ko' );
    my $fileDataObj = KIWIXMLFileData -> new(\%init );
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my $value = $fileDataObj -> setArch('tegra');
    my $expectedMsg = "Specified arch 'tegra' is not supported";
    $msg = $kiwi -> getMessage();
    $this -> assert_str_equals($expectedMsg, $msg);
    $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($value);
    $value = $fileDataObj -> getArch();
    $this -> assert_null($value);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fileDataObj);
    return;
}

1;
