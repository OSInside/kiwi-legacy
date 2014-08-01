#================
# FILE          : kiwiImageCreator.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIImageCreator module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiImageCreator;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIImageCreator;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct new test case
    # ---
    my $this = shift -> SUPER::new(@_);
    my $baseDir = $this -> getDataDir() . '/kiwiImageCreator/';
    $this -> {baseDir} = $baseDir;
    return $this;
}

#==========================================
# test_ctor_noCmdlArg
#------------------------------------------
sub test_ctor_noCmdlArg {
    # ...
    # Test object construction, do not supply a command line object argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $kic = KIWIImageCreator -> new();
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = 'KIWIImageCreator: expecting KIWICommandLine object as '
        . 'argument.';
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($kic);
    return;
}

#==========================================
# test_prepBootImg_invalidTypeXML
#------------------------------------------
sub test_prepBootImg_invalidTypeXML {
    # ...
    # Test error condition for non existent config dir
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $cmd = $this -> __getCmdObj();
    my $confDir = $this -> {baseDir} . 'prepareXmlRoot';
    $cmd -> setConfigDir($confDir);
    my $kic = KIWIImageCreator -> new($cmd);
    my $res = $kic -> prepareBootImage('ola');
    my $expectedMsg = 'prepareBootImage: expecting KIWIXML object as first '
        . 'argument.';
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_prepBootImg_noXMLArg
#------------------------------------------
sub test_prepBootImg_noXMLArg {
    # ...
    # Test error condition for missing config dir argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $cmd = $this -> __getCmdObj();
    my $confDir = $this -> {baseDir} . 'prepareXmlRoot';
    $cmd -> setConfigDir($confDir);
    my $kic = KIWIImageCreator -> new($cmd);
    my $res = $kic -> prepareBootImage();
    my $expectedMsg = 'prepareBootImage: no system XML description '
        . 'object given';
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_prepBootImg_noRootDirArg
#------------------------------------------
sub test_prepBootImg_noRootDirArg {
    # ...
    # Test error condition for missing target root dir argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $cmd = $this -> __getCmdObj();
    my $confDir = $this -> {baseDir} . 'prepareXmlRoot';
    my $xml = KIWIXML -> new($confDir, undef, undef, $cmd);
    $cmd -> setConfigDir($confDir);
    my $kic = KIWIImageCreator -> new($cmd);
    my $res = $kic -> prepareBootImage($xml);
    my $expectedMsg = 'prepareBootImage: no root traget defined';
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_prepImg_noRootTgt
#------------------------------------------
sub test_prepImg_noRootTgt {
    # ...
    # Test error condition, no root target dir in command line and
    # no default rout in XML
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $cmd = $this -> __getCmdObj();
    $cmd -> setConfigDir($this -> {baseDir} . 'prepareNoRoot');
    my $kic = KIWIImageCreator -> new($cmd);
    my $res = $kic -> prepareImage();
    my $info = $kiwi -> getInfoMessage();
    my $expectedIMsg = "Description provides no MD5 hash, check\n"
        . "Reading image description [Prepare]...\n"
        . 'Checking for default root in XML data...';
    $this -> assert_str_equals($expectedIMsg, $info);
    my $expectedEMsg = 'No target directory set for the unpacked image tree.';
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals($expectedEMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    return;
}

#==========================================
# test_prepImg_cmdRootTgt
#------------------------------------------
sub test_prepImg_cmdRootTgt {
    # ...
    # Test expected use case, root target directory on command line
    # ---
    if ($< != 0) {
        print "\t\tInfo: Not root, skipping test_prepImg_cmdRootTgt\n";
        return;
    }
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    # Do not run the test if there is a lock file
    if ( -f '/var/lock/kiwi-init.lock') {
        print "\t\tInfo: Found kiwi lock file /var/lock/kiwi-init.lock\n";
        print "\t\tFailing test\n";
        $this -> assert(0, 1);
    }
    my $cmd = $this -> __getCmdObj();
    my $confDir = $this -> {baseDir} . 'prepareXmlRoot';
    $cmd -> setConfigDir($confDir);
    $cmd -> setRootTargetDir('/tmp/kiwiDevTests/imgPrep_unpacked');
    # Avoid chain failures
    $this -> removeTestTmpDir();
    # Set up target dir and repo
    my $repoParentDir = $this -> createTestTmpDir();
    my $repoOrig = $this -> getDataDir();
    system "cp -r $repoOrig/kiwiTestRepo $repoParentDir";
    my $kic = KIWIImageCreator -> new($cmd);
    my $res = $kic -> prepareImage();
    # Look for e specific file in the target directory to provide a base
    # verification that the prep step worked
    # basePath is set in config.xml and must match here
    my $basePath = '/tmp/kiwiDevTests/imgPrep_unpacked';
    $this -> assert_file_exists(
                            "$basePath/usr/share/doc/kiwi/tests/README.txt");
    # Test this condition last to get potential error messages
    $this -> assert_not_null($res);
    # Test generate a lot of messages, ignore them, just make sure
    # everything in the log object gets reset
    $kiwi -> getState();
    # Clean up
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# test_prepImg_xmlRootTgt
#------------------------------------------
sub test_prepImg_xmlRootTgt {
    # ...
    # Test expected use case, root target directory in XML file
    # ---
    if ($< != 0) {
        print "\t\tInfo: Not root, skipping test_prepImg_xmlRootTgt\n";
        return;
    }
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    # Do not run the test if there is a lock file
    if ( -f '/var/lock/kiwi-init.lock') {
        print "\t\tInfo: Found kiwi lock file /var/lock/kiwi-init.lock\n";
        print "\t\tFailing test\n";
        $this -> assert(0, 1);
    }
    my $cmd = $this -> __getCmdObj();
    my $confDir = $this -> {baseDir} . 'prepareXmlRoot';
    $cmd -> setConfigDir($confDir);
    # Avoid chain failures
    $this -> removeTestTmpDir();
    # Set up target dir and repo
    my $repoParentDir = $this -> createTestTmpDir();
    my $repoOrig = $this -> getDataDir();
    system "cp -r $repoOrig/kiwiTestRepo $repoParentDir";
    my $kic = KIWIImageCreator -> new($cmd);
    my $res = $kic -> prepareImage();
    # Look for e specific file in the target directory to provide a base
    # verification that the prep step worked
    # basePath is set in config.xml and must match here
    my $basePath = '/tmp/kiwiDevTests/imgPrep_unpacked';
    $this -> assert_file_exists(
                            "$basePath/usr/share/doc/kiwi/tests/README.txt");
    # Test this condition last to get potential error messages
    $this -> assert_not_null($res);
    # Test generate a lot of messages, ignore them, just make sure 
    # everything in the log object gets reset
    $kiwi -> getState();
    # Clean up
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getCmdObj
#------------------------------------------
sub __getCmdObj {
    # ...
    # Helper method to create a CommandLine object;
    # ---
    my $this = shift;
    my $cmd = KIWICommandLine -> new();
    return $cmd;
}

1;
