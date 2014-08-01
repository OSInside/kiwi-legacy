#================
# FILE          : kiwiImage.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIImage
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiImage;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIImage;
use KIWIXML;
use KIWIOverlay;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct new test case
    # ---
    my $this = shift -> SUPER::new(@_);
    $this -> {dataDir} = $this -> getDataDir() . '/kiwiConfigWriterFactory';
    $this -> removeTestTmpDir();
    return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
    # ...
    # Test the KIWIImage constructor
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $tmpDir = $this -> createTestTmpDir();
        my $image = KIWIImage -> new($xml, $tmpDir, $tmpDir, undef, '/tmp',
                                                                 undef, undef, $cmdL);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($image);
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# test_ctor_invalidArg1
#------------------------------------------
sub test_ctor_invalidArg1 {
    # ...
    # Test the KIWIImage with invalid first argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $image = KIWIImage -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImage: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# test_ctor_invalidArg8
#------------------------------------------
sub test_ctor_invalidArg8 {
    # ...
    # Test the KIWIImage with an invalid eigth argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
        my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $image = KIWIImage -> new($xml, '/tmp', '/tmp', undef, '/tmp',
                                                                undef, undef, 'foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImage: expecting KIWICommandLine object as '
                . 'eigth argument';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# test_ctor_NoArg1
#------------------------------------------
sub test_ctor_NoArg1 {
    # ...
    # Test the KIWIImage with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $image = KIWIImage -> new();
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImage: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# test_ctor_NoArg2
#------------------------------------------
sub test_ctor_NoArg2 {
    # ...
    # Test the KIWIImage with no second argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
        my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $image = KIWIImage -> new($xml);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImage: expecting unpacked image directory path '
                . 'as second argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# test_ctor_NoArg3
#------------------------------------------
sub test_ctor_NoArg3 {
    # ...
    # Test the KIWIImage with no third argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
        my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $image = KIWIImage -> new($xml, '/tmp');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImage: expecting destination directory as '
                . 'third argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# test_ctor_NoArg5
#------------------------------------------
sub test_ctor_NoArg5 {
    # ...
    # Test the KIWIImage with no fifth argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
        my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $image = KIWIImage -> new($xml, '/tmp', '/tmp');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImage: expecting system path as fifth argument';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# test_ctor_NoArg8
#------------------------------------------
sub test_ctor_NoArg8 {
    # ...
    # Test the KIWIImage with no eigth argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
        my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $image = KIWIImage -> new($xml, '/tmp', '/tmp', undef, '/tmp');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImage: expecting KIWICommandLine object as '
                . 'eigth argument';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# test_ctor_NoDirArg3
#------------------------------------------
sub test_ctor_NoDirArg3 {
    # ...
    # Test the KIWIImage with no third argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
        my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $image = KIWIImage -> new($xml, 'tmp', 'foo');
    my $msg = $kiwi -> getMessage();
    my $expected ="KIWIImage: given destination directory 'foo' "
                . 'does not exist';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($image);
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getCommandLineObj
#------------------------------------------
sub __getCommandLineObj {
    # ...
    # Return an empty command line
    # ---
    my $cmdL = KIWICommandLine -> new();
    return $cmdL;
}

#==========================================
# __getXMLObj
#------------------------------------------
sub __getXMLObj {
    # ...
    # Create an XML object with the given config dir
    # ---
    my $this      = shift;
    my $configDir = shift;
    my $cmdL = shift;
    my $kiwi = $this->{kiwi};
    # TODO
    # Fix the creation of the XML object once the ctor arguments change
    my $xml = KIWIXML -> new(
        $configDir, undef, undef, $cmdL
    );
    if (! $xml) {
        my $errMsg = $kiwi -> getMessage();
        print "XML create msg: $errMsg\n";
        my $msg = 'Failed to create XML obj, most likely improper config '
        . 'path: '
        . $configDir;
        $this -> assert_equals(1, $msg);
    }
    return $xml;
}

1;
