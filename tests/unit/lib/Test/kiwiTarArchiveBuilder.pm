#================
# FILE          : kiwiTarArchiveBuilder.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWITarArchiveBuilder
#               : module.
#               :
#               : Note we directly test private methods to help make detecting
#               : problems easier and keep the tests short.
#               :
# STATUS        : Development
#----------------
package Test::kiwiTarArchiveBuilder;

use strict;
use warnings;
use File::Slurp;
use IPC::Open3;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWITarArchiveBuilder;
use KIWIImage;
use KIWIOverlay;
use KIWIGlobals;
use KIWIXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
  # ...
  # Construct new test case
  # ---
  my $this = shift -> SUPER::new(@_);
  $this -> {dataDir} = $this -> getDataDir() . '/kiwiImageBuildFactory';
  $this -> removeTestTmpDir();
  return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
  # ...
  # Test the KIWITarArchiveBuilder
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDir = $this -> {dataDir};
  my $cmdL = $this -> __getCommandLineObj();
  my $xml = $this -> __getXMLObj($confDir, $cmdL);
  my $tmpDir = $this -> createTestTmpDir();
  my $image = $this -> __getImageObj($cmdL, $tmpDir, $xml);
  $cmdL -> setImageTargetDir($tmpDir);
  my $builder = KIWITarArchiveBuilder -> new($xml, $cmdL, $image);
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
  # Test the KIWITarArchiveBuilder with invalid first argument
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $builder = KIWITarArchiveBuilder -> new('foo');
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWITarArchiveBuilder: expecting KIWIXML object as '
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
  # Test the KIWITarArchiveBuilder with invalid second argument
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDir = $this -> {dataDir};
  my $cmdL = $this -> __getCommandLineObj();
  my $xml = $this -> __getXMLObj($confDir, $cmdL);
  my $builder = KIWITarArchiveBuilder -> new($xml, 'foo');
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWITarArchiveBuilder: expecting KIWICommandLine object '
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
  # Test the KIWITarArchiveBuilder with invalid thried argument
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDir = $this -> {dataDir};
  my $cmdL = $this -> __getCommandLineObj();
  my $xml = $this -> __getXMLObj($confDir, $cmdL);
  my $builder = KIWITarArchiveBuilder -> new($xml, , $cmdL, 'foo');
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWITarArchiveBuilder: expecting KIWIImage object '
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
  # Test the KIWITarArchiveBuilder with no argument
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $builder = KIWITarArchiveBuilder -> new();
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWITarArchiveBuilder: expecting KIWIXML object as '
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
  # Test the KIWITarArchiveBuilder with no second argument
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDir = $this -> {dataDir};
  my $cmdL = $this -> __getCommandLineObj();
  my $xml = $this -> __getXMLObj($confDir, $cmdL);
  my $builder = KIWITarArchiveBuilder -> new($xml);
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWITarArchiveBuilder: expecting KIWICommandLine object '
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
  # Test the KIWITarArchiveBuilder with no third argument
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDir = $this -> {dataDir};
  my $cmdL = $this -> __getCommandLineObj();
  my $xml = $this -> __getXMLObj($confDir, $cmdL);
  my $builder = KIWITarArchiveBuilder -> new($xml, $cmdL);
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWITarArchiveBuilder: expecting KIWIImage object '
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
# test_createTarArchive
#------------------------------------------
sub test_createTarArchive {
  # ...
  # Test the __createTarArchive method
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $tmpDir = $this -> createTestTmpDir();
  # Create a basic setup assimilating a true directory layout
  mkdir $tmpDir . '/origin';
  mkdir $tmpDir . '/origin/image';
  mkdir $tmpDir . '/origin/etc';
  mkdir $tmpDir . '/origin/usr';
  mkdir $tmpDir . '/origin/home';
  mkdir $tmpDir . '/origin/home/tux';
  my $status = open my $SCRIPT, '>', $tmpDir . '/origin/usr/hello';
  $this -> assert_not_null($status);
  print $SCRIPT '#!/usr/bash' . "\n";
  print $SCRIPT 'echo "hello world"';
  $status = close $SCRIPT;
  $this -> assert_not_null($status);
  my $fl = $tmpDir . '/origin/home/tux/.peaks';
  $status = open my $PEAKS, '>', $fl;
  $this -> assert_not_null($status);
  print $PEAKS 'Matterhorn';
  print $PEAKS 'K2';
  $status = close $PEAKS;
  $this -> assert_not_null($status);
  # Object setup
  my $confDir = $this -> {dataDir};
  my $cmdL = $this -> __getCommandLineObj();
  $cmdL -> setImageTargetDir($tmpDir);
  $cmdL -> setConfigDir($tmpDir . '/origin');
  my $xml = $this -> __getXMLObj($confDir, $cmdL);
  my $image = $this -> __getImageObj($cmdL, $tmpDir, $xml);
  my $builder = KIWITarArchiveBuilder -> new($xml, $cmdL, $image);
  $builder -> p_createBuildDir();
  # Test the method
  my $res = $builder -> __createTarArchive();
  my $msg = $kiwi -> getMessage();
  my $expected = 'Creating tar archive...';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('info', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('completed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($res);
  my $expectedFl = 'tbz/suse-xml-test-config.';
  my $arch = KIWIQX::qxx ("uname -m");
  chomp ( $arch );
  $expectedFl .= $arch . '-1.0.1.tbz';
  $this -> assert_file_exists($tmpDir . '/' . $expectedFl);
  my $CHILDWRITE;
  my $CHILDSTDO;
  my $CHILDSTDE;
  my $pid = open3 (
    $CHILDWRITE, $CHILDSTDO, $CHILDSTDE, "tar -tjvf $tmpDir/$expectedFl"
  );
  waitpid( $pid, 0 );
  $status = $? >> 8;
  my @files = <$CHILDSTDO>;
  if ($status) {
    $this -> assert_null('tar dump failed');
  }
  my @names;
  for my $fl (@files) {
    my @parts = split /\s/smx, $fl;
    push @names, $parts[-1];
  }
  my @expectedNames = qw (
    ./
    ./etc/
    ./usr/
    ./usr/hello
    ./home/
    ./home/tux/
    ./home/tux/.peaks
  );
  $this -> assert_array_equal(\@expectedNames, \@names);
  $this ->  removeTestTmpDir();
  return;
}

#==========================================
# test_getBaseBuildDirectory
#------------------------------------------
sub test_getBaseBuildDirectory {
  # ...
  # Test the getBaseBuildDirectory method
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDir = $this -> {dataDir};
  my $cmdL = $this -> __getCommandLineObj();
  my $tmpDir = $this -> createTestTmpDir();
  $cmdL -> setImageTargetDir($tmpDir);
  my $xml = $this -> __getXMLObj($confDir, $cmdL);
  my $image = $this -> __getImageObj($cmdL, $tmpDir, $xml);
  my $builder = KIWITarArchiveBuilder -> new($xml, $cmdL, $image);
  my $buildDir = $builder -> getBaseBuildDirectory();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  my $expectedDir = $tmpDir . '/tbz';
  $this -> assert_str_equals($expectedDir, $buildDir);
  $this -> removeTestTmpDir();
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
  $xml -> setBuildType('tbz');
  return $xml;
}

1;
