#================
# FILE          : kiwiLocator.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
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

use KIWICommandLine;
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
	$this -> removeTestTmpDir();
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
	my $locator = KIWILocator -> new();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($locator);

	return;
}

#==========================================
# test_createTmpDirInTmp
#------------------------------------------
sub test_createTmpDirInTmp {
	# ...
	# Test the createTmpDirectory method for the most simplistic case
	# where a temporary directory is created in /tmp, i.e. there is
	# no preset root directory.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $cmdL = $this -> __getCommandLine();
	$cmdL -> setForceNewRoot(0);
	my $newTmpDir = $locator -> createTmpDirectory( undef, undef, $cmdL);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	if (! -d $newTmpDir) {
		my $err = 'Temp dir "' . $newTmpDir . '" was reported to be created,';
		$err .= ' but does not exists';
		$this -> assert_null($err);
	}
	rmdir $newTmpDir;

	return;
}

#==========================================
# test_createTmpDirSpecifiedDir
#------------------------------------------
sub test_createTmpDirSpecifiedDir {
	# ...
	# Test the createTmpDirectory method using a specified directory
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $cmdL = $this -> __getCommandLine();
	$cmdL -> setForceNewRoot(0);
	my $tmpDir = $this -> createTestTmpDir();
	my $newTmpDir = $locator -> createTmpDirectory( undef, $tmpDir, $cmdL);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals($tmpDir, $newTmpDir);
	if (! -d $tmpDir) {
		my $err = 'Temp dir "' . $tmpDir . '" was reported to be created,';
		$err .= ' but does not exists';
		$this -> assert_null($err);
	}
	$this -> removeTestTmpDir();

	return;
}

#==========================================
# test_createTmpDirSpecifiedDirForceOK
#------------------------------------------
sub test_createTmpDirSpecifiedDirOK {
	# ...
	# Test the createTmpDirectory method using a specified directory
	# that is not empty but is OK to be removed
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $cmdL = $this -> __getCommandLine();
	$cmdL -> setForceNewRoot(1);
	my $tmpDir = $this -> createTestTmpDir();
	mkdir "$tmpDir/kiwi";
	my $newTmpDir = $locator -> createTmpDirectory( undef, $tmpDir, $cmdL);
	my $msg = $kiwi -> getMessage();
	my $expected = "Removing old root directory '$tmpDir'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_str_equals($tmpDir, $newTmpDir);
	if (! -d $tmpDir) {
		my $err = 'Temp dir "' . $tmpDir . '" was reported to be created,';
		$err .= ' but does not exists';
		$this -> assert_null($err);
	}
	rmdir "$tmpDir/kiwi";
	$this -> removeTestTmpDir();

	return;
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

	return;
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

	return;
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

	return;
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

	return;
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

	return;
}

#==========================================
# test_getDefCacheDir
#------------------------------------------
sub test_getDefCacheDir {
	# ...
	# Test that we get the expected location for the default cache directory
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $cacheDir = $locator -> getDefaultCacheDir();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Make sure directory has expected path
	$this -> assert_str_equals($cacheDir, '/var/cache/kiwi/image');

	return;
}

#==========================================
# test_getExecPathArgsDoubleDash
#------------------------------------------
sub test_getExecPathArgsDoubleDash {
	# ...
	# Test behavior when an executable provides single dash argument options
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $execDir = $this -> {dataDir} . 'bin';
	my @opts = qw(calc break);
	my $res = $locator -> getExecArgsFormat($execDir . '/doubleDash', \@opts);
	my %result = %{$res};
	$this -> assert_equals(1, $result{'status'});
	$this -> assert_str_equals('--calc', $result{'calc'});
	$this -> assert_str_equals('--break', $result{'break'});

	return;
}

#==========================================
# test_getExecPathArgsPythonDash
#------------------------------------------
sub test_getExecPathArgsPythonDash {
	# ...
	# Test behavior when an executable provides double-dash and short
	# argument options, formatted in the python optparse/argparse way
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $execDir = $this -> {dataDir} . 'bin';
	my @opts = qw(\? h help c calc o option b break t timeout mangle);
	my $res = $locator -> getExecArgsFormat($execDir . '/pythonDash', \@opts);
	my %result = %{$res};
	$this -> assert_equals(1, $result{'status'});
	$this -> assert_str_equals('-?', $result{'\?'});
	$this -> assert_str_equals('-h', $result{'h'});
	$this -> assert_str_equals('--help', $result{'help'});
	$this -> assert_str_equals('-c', $result{'c'});
	$this -> assert_str_equals('--calc', $result{'calc'});
	$this -> assert_str_equals('-o', $result{'o'});
	$this -> assert_str_equals('--option', $result{'option'});
	$this -> assert_str_equals('-b', $result{'b'});
	$this -> assert_str_equals('--break', $result{'break'});
	$this -> assert_str_equals('-t', $result{'t'});
	$this -> assert_str_equals('--timeout', $result{'timeout'});
	$this -> assert_str_equals('--mangle', $result{'mangle'});

	return;
}

#==========================================
# test_getExecPathArgsMissingOpt
#------------------------------------------
sub test_getExecPathArgsMissingOpt {
	# ...
	# Test behavior when an executable provides single dash argument options
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $execDir = $this -> {dataDir} . 'bin';
	my @opts = qw(calc break halftime);
	my $res = $locator -> getExecArgsFormat($execDir . '/doubleDash', \@opts);
	my %result = %{$res};
	$this -> assert_equals(0, $result{'status'});
	$this -> assert_str_equals('--calc', $result{'calc'});
	$this -> assert_str_equals('--break', $result{'break'});
	my $errMsg = "Could not find argument halftime for $execDir/doubleDash";
	$this -> assert_str_equals($errMsg, $result{'error'});

	return;
}

#==========================================
# test_getExecPathArgsNoExec
#------------------------------------------
sub test_getExecPathArgsNoExec {
	# ...
	# Test behavior when an executable cannot be found
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my @opts = qw(calc break);
	my $res = $locator -> getExecArgsFormat( 'execDoesNotExist', \@opts );
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals("warning: execDoesNotExist not found\n", $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my %result = %{$res};
	$this -> assert_equals(0, $result{'status'});
	$this -> assert_str_equals('Could not find execDoesNotExist',
							$result{'error'});

	return;
}

#==========================================
# test_getExecPathArgsOneDash
#------------------------------------------
sub test_getExecPathArgsOneDash {
	# ...
	# Test behavior when an executable provides single dash argument options
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my $execDir = $this -> {dataDir} . 'bin';
	my @opts = qw(calc break);
	my $res = $locator -> getExecArgsFormat($execDir . '/singleDash', \@opts);
	my %result = %{$res};
	$this -> assert_equals(1, $result{'status'});
	$this -> assert_str_equals('-calc', $result{'calc'});
	$this -> assert_str_equals('-break', $result{'break'});

	return;
}

#==========================================
# test_getExecPathArgsSysLS
#------------------------------------------
sub test_getExecPathArgsSysLS {
	# ...
	# Test behavior when an executable provides single dash argument options
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = $this -> __getLocator();
	my @opts = qw(directory full-time);
	my $res = $locator -> getExecArgsFormat( 'ls', \@opts);
	my %result = %{$res};
	$this -> assert_equals(1, $result{'status'});
	$this -> assert_str_equals('--directory', $result{'directory'});
	$this -> assert_str_equals('--full-time', $result{'full-time'});

	return;
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

	return;
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

	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getLocator
#------------------------------------------
sub __getCommandLine {
	# ...
	# Helper method to create a KIWICommandLine object
	# ---
	my $this = shift;
	my $cmdL = KIWICommandLine -> new();
	return $cmdL;
}

#==========================================
# __getLocator
#------------------------------------------
sub __getLocator {
	# ...
	# Helper method to create a KIWILocator object
	# ---
	my $this = shift;
	my $locator = KIWILocator -> new();
	return $locator;
}

1;
