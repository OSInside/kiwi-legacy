#================
# FILE          : kiwiLocator.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWILocator module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiLocator;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWILocator;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {dataDir} = $this -> getDataDir() . '/kiwiLocator/';
	$this -> {kiwi} = new Common::ktLog();

	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the locator constructor, it has no error conditions, thus check
	# the object construction.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = new KIWILocator ( $kiwi );
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($locator);
}

#==========================================
# test_getControlFileMultiConfig
#------------------------------------------
sub test_getControlFileMultiConfig {
	# ...
	# Test the getControlFile method using a directory with multiple
	# configuration files.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $multiConfDir = $this -> {dataDir} . 'multiConf';
	my $res = $locator -> getControlFile( $multiConfDir );
	my $msg = $kiwi -> getMessage();
	my $expected = 'Found multiple control files in '
	. "$multiConfDir\n"
	. "\t$multiConfDir/config_one.kiwi\n"
	. "\t$multiConfDir/config_two.kiwi\n";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
}

#==========================================
# test_getControlFileNoConfigFile
#------------------------------------------
sub test_getControlFileNoConfigFile {
	# ...
	# Test the getControlFile method using a directory without a config file
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $noConfDir = $this -> {dataDir} . 'noConf';
	my $res = $locator -> getControlFile( $noConfDir );
	my $msg = $kiwi -> getMessage();
	my $expected = 'Could not locate a configuration file in '
	. "$noConfDir";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
}

#==========================================
# test_getControlFileNoDir
#------------------------------------------
sub test_getControlFileNoDir {
	# ...
	# Test the getControlFile method using a file path as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $aFilePath = $this -> {dataDir} . 'config.xml';
	my $res = $locator -> getControlFile( $aFilePath );
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expected a directory at '
	. "$aFilePath.\nSpecify a directory as the configuration base.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
}

#==========================================
# test_getControlFileNoErrorConfigXML
#------------------------------------------
sub test_getControlFileNoErrorConfigXML {
	# ...
	# Test the getControlFile method using a directory with one config.xml
	# file.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $res = $locator -> getControlFile( $this -> {dataDir} );
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $configFilePath = $this -> {dataDir} . '/config.xml';
	$this -> assert_str_equals($configFilePath, $res);
}

#==========================================
# test_getControlFileNoErrorKiwiExt
#------------------------------------------
sub test_getControlFileNoErrorKiwiExt {
	# ...
	# Test the getControlFile method using a directory with one *.kiwi
	# file.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $confDir = $this -> {dataDir} . 'sglConf';
	my $res = $locator -> getControlFile( $confDir );
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $configFilePath = $this -> {dataDir} . 'sglConf/config_one.kiwi';
	$this -> assert_str_equals($configFilePath, $res);
}

#==========================================
# test_getExecPathNoExec
#------------------------------------------
sub test_getExecPathNoExec {
	# ...
	# Test behavior when an executable cannot be found
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $res = $locator -> getExecPath( 'execDoesNotExist' );
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals("warning: execDoesNotExist not found\n", $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
}

#==========================================
# test_getExecPerl
#------------------------------------------
sub test_getExecPerl {
	# ...
	# Test behavior when an executable can be found
	# Using the perl interpreter as an example
	# Perl's location is specified by LSB, thus we only make the
	# assumption that we are on an LSB compliant system, this should be
	# reasonable.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $res = $locator -> getExecPath( 'perl' );
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $perlPath = '/usr/bin/perl';
	$this -> assert_str_equals($perlPath, $res);
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getLocator
#------------------------------------------
sub __getLocator {
	# ...
	# Helper method to create a KIWILocator object
	# ---
	my $this = shift;
	my $locator = new KIWILocator ( $this -> {kiwi} );
	return $locator;
}

1;
