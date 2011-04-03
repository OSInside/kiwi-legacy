#================
# FILE          : xml.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLValidator module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXML;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXML;

# All tests will need to be adjusted once KIWXML turns into a stateless
# container and the ctor receives the config.xml file name as an argument.
# At this point the test data location should also change.
#
# Complete unit testing of the XML object may not be possible until the
# conversion to a stateless container is complete

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {dataDir} = $this -> getDataDir() . '/kiwiXML/';
	$this -> {kiwi} = new  Common::ktLog();

	return $this;
}

#==========================================
# test_packageManagerInfoHasConfigValue
#------------------------------------------
sub test_packageManagerInfoHasConfigValue {
	# ...
	# Verify that the default package manager is provided if no package manager
	# is set in the configuration
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = new KIWIXML($this -> {kiwi}, $confDir, undef, undef);
	my $pkgMgr = $xml -> getPackageManager();
	$this -> assert_str_equals('zypper', $pkgMgr);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
}

#==========================================
# test_packageManagerSet_noArg
#------------------------------------------
sub test_packageManagerSet_noArg {
	# ...
	# Verify of setPackageManager method error condition
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = new KIWIXML($this -> {kiwi}, $confDir, undef, undef);
	# Call set without argument, expect error
	my $res = $xml -> setPackageManager();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setPackageManager method called without specifying '
		. 'package manager value.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
}

#==========================================
# test_packageManagerSet_noArg
#------------------------------------------
sub test_packageManagerSet_valid {
	# ...
	# Verify setPackageManager works as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = new KIWIXML($this -> {kiwi}, $confDir, undef, undef);
	# Set the package manager to be smart
	my $res = $xml -> setPackageManager('smart');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $newPkgMgr = $xml -> getPackageManager();
	$this -> assert_str_equals('smart', $newPkgMgr);
}

#==========================================
# test_packageManagerInfoHasProfs
#------------------------------------------
sub test_packageManagerInfoHasProfs {
	# ...
	# Verify package manager override works as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'multiPkgMgrWithProf';
	my @profiles = ('specPkgMgr');
	# Verify we get the specified manager
	my $xml = new KIWIXML($this -> {kiwi}, $confDir, undef,\@profiles);
	my $pkgMgr = $xml -> getPackageManager();
	$this -> assert_str_equals('smart', $pkgMgr);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): specPkgMgr', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Override the specified package manager with yum
	my $res = $xml -> setPackageManager('yum');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $newPkgMgr = $xml -> getPackageManager();
	$this -> assert_str_equals('yum', $newPkgMgr);
}

1;
