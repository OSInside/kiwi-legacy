#================
# FILE          : kiwiACIConfigWriter.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIACIConfigWriter
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiACIConfigWriter;

use strict;
use warnings;
use JSON;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use File::Slurp;

use KIWICommandLine;
use KIWIACIConfigWriter;
use KIWILog;
use KIWIXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct new test case
    # ---
    my $this = shift -> SUPER::new(@_);
    $this->{dataDir} = $this -> getDataDir() . '/kiwiACIConfWriter';
    $this -> removeTestTmpDir();
    return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
    # ...
    # Test the KIWIACIConfigWriter
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIACIConfigWriter -> new($xml, '/tmp');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($writer);
    return;
}

#==========================================
# test_ctor_dirNoExist
#------------------------------------------
sub test_ctor_dirNoExist {
    # ...
    # Test the KIWIACIConfigWriter with directory argument of
    # non existing directory
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIACIConfigWriter -> new($xml, '/foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIACIConfigWriter: configuration target directory '
        . 'does not exist.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_ctor_invalidArg1
#------------------------------------------
sub test_ctor_invalidArg1 {
    # ...
    # Test the KIWIACIConfigWriter with invalid first argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $writer = KIWIACIConfigWriter -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIACIConfigWriter: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_ctor_noArg1
#------------------------------------------
sub test_ctor_noArg1 {
    # ...
    # Test the KIWIACIConfigWriter with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $writer = KIWIACIConfigWriter -> new();
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIACIConfigWriter: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_ctor_noArg2
#------------------------------------------
sub test_ctor_noArg2 {
    # ...
    # Test the KIWIACIConfigWriter with no second argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIACIConfigWriter -> new($xml);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIACIConfigWriter: expecting configuration target '
        . 'directory as second argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_p_writeConfigFile
#------------------------------------------
sub test_p_writeConfigFile {
    # ...
    # Test the p_writeConfigFile method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $cDir = $this -> createTestTmpDir();
    my $writer = KIWIACIConfigWriter -> new($xml, $cDir);
    my $res = $writer -> p_writeConfigFile();
    my $msg = $kiwi -> getInfoMessage();
    my $expected = "Write container manifest file\n"
        . "--> /tmp/kiwiDevTests/manifest";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('completed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cDir . '/manifest');
    my $manifest = JSON->new->utf8->decode(read_file($cDir . '/manifest'));
    $this -> assert_str_equals($manifest->{'acKind'}, 'ImageManifest');
    $this -> assert_str_equals($manifest->{'acVersion'}, '0.5.1');
    $this -> assert_str_equals($manifest->{'name'}, $xml -> getImageName());
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getXMLObj
#------------------------------------------
sub __getXMLObj {
    # ...
    # Create an XML object with the given config dir
    # ---
    my $this      = shift;
    my $configDir = shift;
    my $kiwi = $this->{kiwi};
    # TODO
    # Fix the creation of the XML object once the ctor arguments change
    my $cmdL = KIWICommandLine -> new();
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
