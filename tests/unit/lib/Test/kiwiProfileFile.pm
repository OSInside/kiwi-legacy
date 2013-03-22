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
	my $expected = 'KIWIProfileFile: writeProfile expecting directory '
		. 'as argument';
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
	my $expected = 'KIWIProfileFile: writeProfile expecting directory '
		. 'as argument';
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
