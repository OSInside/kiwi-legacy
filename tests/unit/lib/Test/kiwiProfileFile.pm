#================
# FILE          : kiwiProfileFile.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the  KIWIProfileFile
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiProfileFile;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIProfileFile;
use KIWIXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {dataDir} = $this -> getDataDir() . '/kiwiProfileFile';
	$this -> removeTestTmpDir();
	return $this;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the ProfileFile constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profFileObj = KIWIProfileFile -> new('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIProfileFile: given argument is neither a KIWIXML '
		. 'object nor an existing file. Could not initialize this '
		. 'object.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($profFileObj);
	return;
}

#==========================================
# test_ctor_initFile
#------------------------------------------
sub test_ctor_initFile {
	# ...
	# Test the ProfileFile constructor with a file path as initialization
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.src';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($profFileObj);
	return;
}

#==========================================
# test_ctor_initFile_unkonwnVar
#------------------------------------------
sub test_ctor_initFile_unkonwnVar {
	# ...
	# # Test the ProfileFile constructor with a file path as initialization
	# the file contains an unknown variable
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.upUnkk';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Unrecognized variable: foo_bar';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($profFileObj);
	return;
}

#==========================================
# test_ctor_initXML
#------------------------------------------
sub test_ctor_initXML {
	# ...
	# Test the ProfileFile constructor with XML object as initialization
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir};
	my $cmdL =  $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $profFileObj = KIWIProfileFile -> new($xml);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($profFileObj);
	return;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
	# ...
	# Test the ProfileFile constructor with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profFileObj = KIWIProfileFile -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIProfileFile: expecting file path or KIWIXML object '
		. 'as first argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($profFileObj);
	return;
}

#==========================================
# test_updateFromFile
#------------------------------------------
sub test_updateFromFile {
	# ...
	# Test the updateFromFile method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.src';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $upFl = $this->{dataDir} . '/profile.up';
	my $res = $profFileObj -> updateFromFile($upFl);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $tmpDir = $this -> createTestTmpDir();
	$res = $profFileObj -> writeProfile($tmpDir);
	my $cmd = 'diff ' . $this->{dataDir} . '/profile.upRef '
		. $tmpDir .'/.profile';
	my $status = system $cmd;
	$this -> assert_equals(0, $status);
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_updateFromFile_noArg
#------------------------------------------
sub test_updateFromFile_noArg {
	# ...
	# Test the updateFromFile method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.src';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $res = $profFileObj -> updateFromFile();
	my $msg = $kiwi -> getMessage();
	my $expected = 'updateFromFile: expecting existing file as first argument';
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
# test_updateFromFile_noFile
#------------------------------------------
sub test_updateFromFile_noFile {
	# ...
	# Test the updateFromFile method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.src';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $res = $profFileObj -> updateFromFile('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'updateFromFile: expecting existing file as first argument';
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
# test_updateFromXML_invalidArg
#------------------------------------------
sub test_updateFromXML_invalidArg {
	# ...
	# Test the updateFromXML method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir};
	my $cmdL =  $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $profFileObj = KIWIProfileFile -> new($xml);
	my $res = $profFileObj -> updateFromXML('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'updateFromXML: expecting KIWIXML object as first argument';
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
# test_updateFromXML_noArg
#------------------------------------------
sub test_updateFromXML_noArg {
	# ...
	# Test the updateFromXML method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir};
	my $cmdL =  $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $profFileObj = KIWIProfileFile -> new($xml);
	my $res = $profFileObj -> updateFromXML();
	my $msg = $kiwi -> getMessage();
	my $expected = 'updateFromXML: expecting KIWIXML object as first argument';
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
# test_writeProfile_initFile
#------------------------------------------
sub test_writeProfile_initFile {
	# ...
	# Test the writeProfile method with file initialize object
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.src';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $tmpDir = $this -> createTestTmpDir();
	my $res = $profFileObj -> writeProfile($tmpDir);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $cmd = 'diff ' . $this->{dataDir} . '/profile.src '
		. $tmpDir .'/.profile';
	my $status = system $cmd;
	$this -> assert_equals(0, $status);
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_writeProfile_initXML
#------------------------------------------
sub test_writeProfile_initXML {
	# ...
	# Test the writeProfile method with XML initialized object
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir};
	my $cmdL =  $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $profFileObj = KIWIProfileFile -> new($xml);
	my $tmpDir = $this -> createTestTmpDir();
	my $res = $profFileObj -> writeProfile($tmpDir);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $cmd = 'diff ' . $this->{dataDir} . '/prof.xmlRef '
		. $tmpDir .'/.profile';
	my $status = system $cmd;
	$this -> assert_equals(0, $status);
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_writeProfile_noArg
#------------------------------------------
sub test_writeProfile_noArg {
	# ...
	# Tets the writeProfile method when no argument is given
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.src';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $res = $profFileObj -> writeProfile();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIProfileFile:writeProfile expecting directory '
		. 'as argument.';
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
# test_writeProfile_noDir
#------------------------------------------
sub test_writeProfile_noDir {
	# ...
	# Tets the writeProfile method when no argument is given
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fl = $this->{dataDir} . '/profile.src';
	my $profFileObj = KIWIProfileFile -> new($fl);
	my $res = $profFileObj -> writeProfile('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIProfileFile:writeProfile expecting directory '
		. 'as argument.';
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
