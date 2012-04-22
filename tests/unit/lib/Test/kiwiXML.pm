#================
# FILE          : xml.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@suse.com>
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
use KIWICommandLine;

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
	$this -> {cmdL} = new KIWICommandLine($this->{kiwi});

	return $this;
}

#==========================================
# test_getOEMAlignPartition
#------------------------------------------
sub test_getOEMAlignPartition {
	# ...
	# Verify proper return of getOEMAlignPartition method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMAlignPartition();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMBootTitle
#------------------------------------------
sub test_getOEMBootTitle {
	# ...
	# Verify proper return of getOEMBootTitle method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMBootTitle();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('Unit Test', $value);
}

#==========================================
# test_getOEMBootWait
#------------------------------------------
sub test_getOEMBootWait {
	# ...
	# Verify proper return of getOEMBootWait method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMBootWait();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
}

#==========================================
# test_getOEMKiwiInitrd
#------------------------------------------
sub test_getOEMKiwiInitrd {
	# ...
	# Verify proper return of getOEMKiwiInitrd method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMKiwiInitrd();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMPartitionInstall
#------------------------------------------
sub test_getOEMPartitionInstall {
	# ...
	# Verify proper return of getOEMPartitionInstall method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMPartitionInstall();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
}

#==========================================
# test_getOEMReboot
#------------------------------------------
sub test_getOEMReboot {
	# ...
	# Verify proper return of getOEMReboot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMReboot();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
}

#==========================================
# test_getOEMRebootInter
#------------------------------------------
sub test_getOEMRebootInter {
	# ...
	# Verify proper return of getOEMRebootInter method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRebootInter();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
}

#==========================================
# test_getOEMRecovery
#------------------------------------------
sub test_getOEMRecovery {
	# ...
	# Verify proper return of getOEMRecovery method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRecovery();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMRecoveryID
#------------------------------------------
sub test_getOEMRecoveryID {
	# ...
	# Verify proper return of getOEMRecoveryID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRecoveryID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('20', $value);
}

#==========================================
# test_getOEMRecoveryInPlace
#------------------------------------------
sub test_getOEMRecoveryInPlace {
	# ...
	# Verify proper return of getOEMRecoveryInPlace method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRecoveryInPlace();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMShutdown
#------------------------------------------
sub test_getOEMShutdown {
	# ...
	# Verify proper return of getOEMShutdown method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMShutdown();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
}

#==========================================
# test_getOEMShutdownInter
#------------------------------------------
sub test_getOEMShutdownInter {
	# ...
	# Verify proper return of getOEMShutdownInter method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMShutdownInter();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMSilentBoot
#------------------------------------------
sub test_getOEMSilentBoot {
	# ...
	# Verify proper return of getOEMSilentBoot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSilentBoot();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMSwap
#------------------------------------------
sub test_getOEMSwap {
	# ...
	# Verify proper return of getOEMSwap method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSwap();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMSwapSize
#------------------------------------------
sub test_getOEMSwapSize {
	# ...
	# Verify proper return of getOEMSwapSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSwapSize();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('2048', $value);
}

#==========================================
# test_getOEMSystemSize
#------------------------------------------
sub test_getOEMSystemSize {
	# ...
	# Verify proper return of getOEMSystemSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSystemSize();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('20G', $value);
}

#==========================================
# test_getOEMUnattended
#------------------------------------------
sub test_getOEMUnattended {
	# ...
	# Verify proper return of getOEMUnattended method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMUnattended();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
}

#==========================================
# test_getOEMUnattendedID
#------------------------------------------
sub test_getOEMUnattendedID {
	# ...
	# Verify proper return of getOEMUnattendedID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMUnattendedID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('scsi-SATA_ST9500420AS_5VJ5JL6T-part1', $value);
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
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
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
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
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
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
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
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef,\@profiles,$this->{cmdL}
	);
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
