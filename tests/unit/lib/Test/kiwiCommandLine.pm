#================
# FILE          : kiwiCommandLine.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWICommandLine module..
#               :
# STATUS        : Development
#----------------
package Test::kiwiCommandLine;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {kiwi} = new Common::ktLog();

	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the commandline constructor, it has no error conditions, thus check
	# the object construction.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = new KIWICommandLine($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($cmd);
}

#==========================================
# test_cmdBuildTypeUsage
#------------------------------------------
sub test_cmdBuildTypeUsage {
	# ...
	# Test the storage and verification of the build type data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Use valid data to set a type information
	my $res = $cmd -> setBuildType('reiserfs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we can get our data back
	my $cmdT = $cmd -> getBuildType();
	$this -> assert_str_equals('reiserfs', $cmdT);
}

#==========================================
# test_cmdPackageMgrUsage
#------------------------------------------
sub test_cmdPackageMgrUsage {
	# ...
	# Test the storage of the package manager
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call
	my $res = $cmd -> setPackageManager();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setPackageManager method called without specifying '
	. 'package manager value.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	# Test unsupported package manager
	$res = $cmd -> setPackageManager('pablo');
	$msg = $kiwi -> getMessage();
	$expectedMsg = 'Unsupported package manager specified: pablo';
	$this -> assert_str_equals($expectedMsg, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	# Make sure we can get our data back
	$res = $cmd -> setPackageManager('zypper');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $pckMgr = $cmd -> getPackageManager();
	$this -> assert_str_equals('zypper', $pckMgr);
}

#==========================================
# test_cmdProfileUsage
#------------------------------------------
sub test_cmdProfileUsage {
	# ...
	# Test the storage for profile data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Set some list data
	my @profiles = qw(first second);
	my $res = $cmd -> setBuildProfiles(\@profiles);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we can get our data back
	my @cmdProfs = @{$cmd -> getBuildProfiles()};
	$this -> assert_array_equal(\@profiles, \@cmdProfs);
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
	my $cmd = new KIWICommandLine($this -> {kiwi});
	return $cmd;
}

1;
