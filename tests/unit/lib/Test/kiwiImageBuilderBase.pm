#================
# FILE          : kiwiImageBuilderBase.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIImageBuilderBase
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiImageBuilderBase;

use strict;
use warnings;
use File::Slurp;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIImage;
use KIWIImageBuilderBase;
use KIWIGlobals;
use KIWIOverlay;
use KIWIXML;

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
    # Test the KIWIImageBuilderBase constructor
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $tmpDir = $this -> createTestTmpDir();
        my $image = $this -> __getImageObj($cmdL, $tmpDir, $xml);
    $cmdL -> setImageTargetDir($tmpDir);
    my $builder = KIWIImageBuilderBase -> new($xml, $cmdL, $image);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($builder);
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# test_ctor_invalidArg1
#------------------------------------------
sub test_ctor_invalidArg1 {
    # ...
    # Test the KIWIImageBuilderBase with invalid first argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $builder = KIWIImageBuilderBase -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImageBuilderBase: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($builder);
    return;
}

#==========================================
# test_ctor_invalidArg2
#------------------------------------------
sub test_ctor_invalidArg2 {
    # ...
    # Test the KIWIImageBuilderBase with invalid second argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $builder = KIWIImageBuilderBase -> new($xml, 'foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImageBuilderBase: expecting KIWICommandLine object '
        . 'as second argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($builder);
    return;
}

#==========================================
# test_ctor_invalidArg3
#------------------------------------------
sub test_ctor_invalidArg3 {
    # ...
    # Test the KIWIImageBuilderBase with invalid thried argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $builder = KIWIImageBuilderBase -> new($xml, , $cmdL, 'foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImageBuilderBase: expecting KIWIImage object '
                . 'as third argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($builder);
    return;
}

#==========================================
# test_ctor_noArg1
#------------------------------------------
sub test_ctor_noArg1 {
    # ...
    # Test the KIWIImageBuilderBase with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $builder = KIWIImageBuilderBase -> new();
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImageBuilderBase: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($builder);
    return;
}

#==========================================
# test_ctor_noArg2
#------------------------------------------
sub test_ctor_noArg2 {
    # ...
    # Test the KIWIImageBuilderBase with no second argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $builder = KIWIImageBuilderBase -> new($xml);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImageBuilderBase: expecting KIWICommandLine object '
        . 'as second argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($builder);
    return;
}

#==========================================
# test_ctor_noArg3
#------------------------------------------
sub test_ctor_noArg3 {
    # ...
    # Test the KIWIImageBuilderBase with no third argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $builder = KIWIImageBuilderBase -> new($xml, $cmdL);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIImageBuilderBase: expecting KIWIImage object '
                . 'as third argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($builder);
    return;
}

#==========================================
# test_p_addCreatedFile
#------------------------------------------
sub test_p_addCreatedFile {
        # ...
        # Test the p_addCreatedFile method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_addCreatedFile('ola');
        my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($res);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_addCreatedFileNoArg
#------------------------------------------
sub test_p_addCreatedFileNoArg {
        # ...
        # Test the p_addCreatedFile method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_addCreatedFile();
        my $msg = $kiwi -> getMessage();
        my $expected = 'KIWIImageBuilder:p_addCreatedFile no file name argument '
                . 'given, internal error, please file a bug';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_createBuildDir
#------------------------------------------
sub test_p_createBuildDir {
        # ...
        # Test the p_createBuildDir method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_createBuildDir();
        my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($res);
        $this -> assert_dir_exists('/tmp/kiwiDevTests/tbz');
        rmdir '/tmp/kiwiDevTests/tbz';
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_createChecksumFiles
#------------------------------------------
sub test_p_createChecksumFiles {
        # ...
        # Test the p_createChecksumFiles method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_createBuildDir();
        my $bldDir = $builder -> getBaseBuildDirectory();
        my $status = open my $TFILE, '>', $bldDir . '/foo.txt';
    $this -> assert_not_null($status);
        print $TFILE 'foo';
        $status = close $TFILE;
        $res = $builder -> p_addCreatedFile('foo.txt');
        $res = $builder -> p_createChecksumFiles();
        my $msg = $kiwi -> getMessage();
        my $expected = 'Generate image checksum...';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('completed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($res);
        $this -> assert_file_exists('/tmp/kiwiDevTests/tbz/foo.txt.sha1');
        my $fileCtx = read_file('/tmp/kiwiDevTests/tbz/foo.txt.sha1');
        my $expectCtx = '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33  foo.txt';
        $this -> assert_str_equals($expectCtx, $fileCtx);
        unlink '/tmp/kiwiDevTests/tbz/foo.txt.sha1';
        rmdir '/tmp/kiwiDevTests/tbz';
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_generateChecksum
#------------------------------------------
sub test_p_generateChecksum {
        # ...
        # Test the p_generateChecksum method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_createBuildDir();
        my $bldDir = $builder -> getBaseBuildDirectory();
        my $status = open my $TFILE, '>', $bldDir . '/foo.txt';
    $this -> assert_not_null($status);
        print $TFILE 'foo';
        $status = close $TFILE;
        my $digest = $builder -> p_generateChecksum($bldDir . '/foo.txt');
        my $msg = $kiwi -> getMessage();
        my $expected = 'Generate image checksum...';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('completed', $state);
    # Test this condition last to get potential error messages
        $this -> assert_str_equals(
                "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33", "$digest");
        unlink '/tmp/kiwiDevTests/tbz/foo.txt.sha1';
        rmdir '/tmp/kiwiDevTests/tbz';
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_generateChecksumNoArg
#------------------------------------------
sub test_p_generateChecksumNoArg {
        # ...
        # Test the p_generateChecksum method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_createBuildDir();
        my $digest = $builder -> p_generateChecksum();
        my $msg = $kiwi -> getMessage();
        my $expected = 'KIWIImageBuilder:p_generateChecksum no file name argument '
                . 'given, internal error, please file a bug';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
        $this -> assert_null($digest);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_generateChecksumNoFile
#------------------------------------------
sub test_p_generateChecksumNoFile {
        # ...
        # Test the p_generateChecksum method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_createBuildDir();
        my $digest = $builder -> p_generateChecksum('foo.txt');
        my $iMsg = $kiwi -> getInfoMessage();
        my $iExpected = 'Generate image checksum...';
        $this -> assert_str_equals($iExpected, $iMsg);
        my $msg = $kiwi -> getMessage();
        my $expected = 'Could not read foo.txt';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
        $this -> assert_null($digest);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_getBaseWorkingDir
#------------------------------------------
sub test_p_getBaseWorkingDir {
        # ...
        # Test the p_getBaseWorkingDir method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $bldDir = $builder -> p_getBaseWorkingDir();
        my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
        # The working directory is set by the child class
    $this -> assert_null($bldDir);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_getChecksumExtension
#------------------------------------------
sub test_getChecksumExtension {
        # ...
        # Test the getChecksumExtension method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $ext = $builder -> getChecksumExtension();
        my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
        $this -> assert_str_equals('sha1', $ext);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_getCreatedFiles
#------------------------------------------
sub test_p_getCreatedFiles {
        # ...
        # Test the p_getCreatedFiles method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $res = $builder -> p_addCreatedFile('ola');
        my $files = $builder -> p_getCreatedFiles();
        my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
        my @expected = ('ola');
        $this -> assert_array_equal(\@expected, $files);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# test_p_getCreatedFilesDefault
#------------------------------------------
sub test_p_getCreatedFilesDefault {
        # ...
        # Test the p_getCreatedFiles method
        # ---
        my $this = shift;
        my $kiwi = $this -> {kiwi};
        my $builder = $this -> __getBuilderObj();
        my $files = $builder -> p_getCreatedFiles();
        my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
        $this -> assert_null($files);
        $this -> removeTestTmpDir();
        return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getBuilderObj
#------------------------------------------
sub __getBuilderObj {
    # ...
    # Create a basic ImageBuilderBase object
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $cmdL = $this -> __getCommandLineObj();
    my $xml = $this -> __getXMLObj($confDir, $cmdL);
    my $tmpDir = $this -> createTestTmpDir();
        my $image = $this -> __getImageObj($cmdL, $tmpDir, $xml);
    $cmdL -> setImageTargetDir($tmpDir);
    my $builder = KIWIImageBuilderBase -> new($xml, $cmdL, $image);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($builder);
    return $builder;
}

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
# __getImageObj
#------------------------------------------
sub __getImageObj {
        # ...
        # Return a basic KIWIImage object
        # ---
        my $this = shift;
        my $cmdL = shift;
        my $imgTree = shift;
        my $xml  = shift;
        my $image = KIWIImage -> new($xml, $imgTree, $imgTree, undef, '/tmp',
                                                                 undef, undef, $cmdL);
        return $image;
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
