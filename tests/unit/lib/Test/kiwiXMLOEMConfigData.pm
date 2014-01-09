#================
# FILE          : kiwiXMLOEMConfigData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLOEMConfigData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLOEMConfigData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use Readonly;
use base qw /Common::ktTestCase/;

use KIWIXMLOEMConfigData;


#==========================================
# constants
#------------------------------------------
Readonly my $RECOVER_SIZE => 1024;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the OEMConfigData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the OEMConfigData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as first argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_initConflictsPostInst
#------------------------------------------
sub test_ctor_initConflictsPostInst {
	# ...
	# Test the OEMConfigData constructor with conflicting post-install
	# setting in the initialization hash.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				oem_bootwait => 'true',
				oem_shutdown => 'true'
			);
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Conflicting post-install settings only one of '
				. "'oem_bootwait oem_reboot oem_reboot_interactive "
				. "oem_shutdown oem_shutdown_interactive' may be set.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_initConflictsSwap
#------------------------------------------
sub test_ctor_initConflictsSwap {
	# ...
	# Test the OEMConfigData constructor with conflicting swap space
	# setting in the initialization hash.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (oem_swapsize => '4096');
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Conflicting swap settings, specified swap size, but '
		. 'swap is disabled.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_initConflictsSwapFalse
#------------------------------------------
sub test_ctor_initConflictsSwapFalse {
	# ...
	# Test the OEMConfigData constructor with conflicting swap space
	# setting in the initialization hash.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				oem_swap     => 'false',
				oem_swapsize => '4096'
			);
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Conflicting swap settings, specified swap size, but '
		. 'swap is disabled.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_initConflictsUnattended
#------------------------------------------
sub test_ctor_initConflictsUnattended {
	# ...
	# Test the OEMConfigData constructor with conflicting
	# settings for auto intsall in the initialization hash.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (oem_unattended_id => '/dev/sdc');
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Conflicting unattended install settings, specified '
		. 'unattended target ID but unattended install is disabled.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_initConflictsUnattendedFalse
#------------------------------------------
sub test_ctor_initConflictsUnattendedFalse {
	# ...
	# Test the OEMConfigData constructor with conflicting
	# settings for auto intsall in the initialization hash.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				oem_unattended    => 'false',
				oem_unattended_id => '/dev/sdb'
			);
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Conflicting unattended install settings, specified '
		. 'unattended target ID but unattended install is disabled.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_initConflictsVerify
#------------------------------------------
sub test_ctor_initConflictsVerify {
	# ...
	# Test the OEMConfigData constructor with conflicting install
	# verification settings in the initialization hash.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				oem_silent_verify => 'true',
				oem_skip_verify => 'true'
			);
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Ambiguous install verification settings, install '
		. 'verification is disabled, but also expected silently '
		. 'unable to resolve ambiguity.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
	# ...
	# Test the OEMConfigData constructor with an initialization hash
	# that contains unsupported data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				firmwaredriver => 'b43',
				oem_swapsize   => '2048',
			);
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData: Unsupported keyword argument '
		. "'firmwaredriver' in initialization structure.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_wInit
#------------------------------------------
sub test_ctor_wInit {
	# ...
	# Test the OEMConfigData constructor with an initialization hash
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				oem_boot_title => 'test-system',
				oem_bootwait   => 'true',
				oem_shutdown   => 'false',
				oem_swap       => 'true',
				oem_swapsize   => '2048',
			);
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	return;
}

#==========================================
# test_getAtaRaidScan
#------------------------------------------
sub test_getAtaRaidScan {
	# ...
	# Test the getATARaidScan method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $scan = $confDataObj -> getAtaRaidScan();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $scan);
	return;
}

#==========================================
# test_getBootTitle
#------------------------------------------
sub test_getBootTitle {
	# ...
	# Test the getBootTitle method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $title = $confDataObj -> getBootTitle();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('test build', $title);
	return;
}

#==========================================
# test_getBootwait
#------------------------------------------
sub test_getBootwait {
	# ...
	# Test the getBootwait method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_bootwait} = 'false';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $bootw = $confDataObj -> getBootwait();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $bootw);
	return;
}

#==========================================
# test_getInplaceRecovery
#------------------------------------------
sub test_getInplaceRecovery {
	# ...
	# Test the getInplaceRecovery method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $inPlRec = $confDataObj -> getInplaceRecovery();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $inPlRec);
	return;
}

#==========================================
# test_getKiwiInitrd
#------------------------------------------
sub test_getKiwiInitrd {
	# ...
	# Test the getKiwiInitrd method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $kinit = $confDataObj -> getKiwiInitrd();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $kinit);
	return;
}

#==========================================
# test_getPartitionInstall
#------------------------------------------
sub test_getPartitionInstall {
	# ...
	# Test the getPartitionInstall method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $pInst = $confDataObj -> getPartitionInstall();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $pInst);
	return;
}

#==========================================
# test_getReboot
#------------------------------------------
sub test_getReboot {
	# ...
	# Test the getReboot method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_reboot} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $reboot = $confDataObj -> getReboot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $reboot);
	return;
}

#==========================================
# test_getRebootInteractive
#------------------------------------------
sub test_getRebootInteractive {
	# ...
	# Test the getRebootInteractive method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_reboot_interactive} = 'false';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $rebootI = $confDataObj -> getRebootInteractive();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $rebootI);
	return;
}

#==========================================
# test_getRecovery
#------------------------------------------
sub test_getRecovery {
	# ...
	# Test the getRecovery method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recover = $confDataObj -> getRecovery();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $recover);
	return;
}

#==========================================
# test_getRecoveryID
#------------------------------------------
sub test_getRecoveryID {
	# ...
	# Test the getRecoveryID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recoverID = $confDataObj -> getRecoveryID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1234', $recoverID);
	return;
}

#==========================================
# test_getRecoveryPartSize
#------------------------------------------
sub test_getRecoveryPartSize {
	# ...
	# Test the getRecoveryPartSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recoverSize = $confDataObj -> getRecoveryPartSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2048', $recoverSize);
	return;
}

#==========================================
# test_getShutdown
#------------------------------------------
sub test_getShutdown {
	# ...
	# Test the getShutdown method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_shutdown} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $halt = $confDataObj -> getShutdown();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $halt);
	return;
}

#==========================================
# test_getShutdownInteractive
#------------------------------------------
sub test_getShutdownInteractive {
	# ...
	# Test the getShutdownInteractive method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_shutdown_interactive} = 'false';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $haltI = $confDataObj -> getShutdownInteractive();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $haltI);
	return;
}

#==========================================
# test_getSilentBoot
#------------------------------------------
sub test_getSilentBoot {
	# ...
	# Test the getSilentBoot method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $sBoot = $confDataObj -> getSilentBoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $sBoot);
	return;
}

#==========================================
# test_getSilentInstall
#------------------------------------------
sub test_getSilentInstall {
	# ...
	# Test the getSilentInstall method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $sBoot = $confDataObj -> getSilentInstall();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $sBoot);
	return;
}

#==========================================
# test_getSilentVerify
#------------------------------------------
sub test_getSilentVerify {
	# ...
	# Test the getSilentVerify method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $sBoot = $confDataObj -> getSilentVerify();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $sBoot);
	return;
}

#==========================================
# test_getSkipVerify
#------------------------------------------
sub test_getSkipVerify {
	# ...
	# Test the getSkipVerify method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_skip_verify} = 'false';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $skip = $confDataObj -> getSkipVerify();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $skip);
	return;
}

#==========================================
# test_getSwap
#------------------------------------------
sub test_getSwap {
	# ...
	# Test the getSwap method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $swap = $confDataObj -> getSwap();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $swap);
	return;
}

#==========================================
# test_getSwapSize
#------------------------------------------
sub test_getSwapSize {
	# ...
	# Test the getSwapSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $swapSize = $confDataObj -> getSwapSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2048', $swapSize);
	return;
}

#==========================================
# test_getSystemSize
#------------------------------------------
sub test_getSystemSize {
	# ...
	# Test the getSystemSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $size = $confDataObj -> getSystemSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8192', $size);
	return;
}

#==========================================
# test_getUnattended
#------------------------------------------
sub test_getUnattended {
	# ...
	# Test the getUnattended method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $auto = $confDataObj -> getUnattended();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $auto);
	return;
}

#==========================================
# test_getUnattendedID
#------------------------------------------
sub test_getUnattendedID {
	# ...
	# Test the getUnattendedID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $autoID = $confDataObj -> getUnattendedID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1', $autoID);
	return;
}

#==========================================
# test_getXMLElement
#------------------------------------------
sub test_getXMLElement{
	# ...
	# Verify that the getXMLElement method returns a node
	# with the proper data.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	my $elem = $confDataObj -> getXMLElement();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<oemconfig>'
		. '<oem-ataraid-scan>true</oem-ataraid-scan>'
		. '<oem-boot-title>test build</oem-boot-title>'
		. '<oem-inplace-recovery>true</oem-inplace-recovery>'
		. '<oem-kiwi-initrd>false</oem-kiwi-initrd>'
		. '<oem-partition-install>false</oem-partition-install>'
		. '<oem-recovery>true</oem-recovery>'
		. '<oem-recoveryID>1234</oem-recoveryID>'
		. '<oem-recovery-part-size>2048</oem-recovery-part-size>'
		. '<oem-silent-boot>true</oem-silent-boot>'
		. '<oem-silent-install>true</oem-silent-install>'
		. '<oem-silent-verify>true</oem-silent-verify>'
		. '<oem-swap>true</oem-swap>'
		. '<oem-swapsize>2048</oem-swapsize>'
		. '<oem-systemsize>8192</oem-systemsize>'
		. '<oem-unattended>true</oem-unattended>'
		. '<oem-unattended-id>1</oem-unattended-id>'
		. '</oemconfig>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_setAtaRaidScan
#------------------------------------------
sub test_setAtaRaidScan {
	# ...
	# Test the setAtaRaidScan method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setAtaRaidScan('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $align = $confDataObj -> getAtaRaidScan();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $align);
	return;
}

#==========================================
# test_setAtaRaidScanInvalidArg
#------------------------------------------
sub test_setAtaRaidScanInvalidArg {
	# ...
	# Test the setAtaRaidScan method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setAtaRaidScan(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setAtaRaidScan: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setAtaRaidScanNoArg
#------------------------------------------
sub test_setAtaRaidScanNoArg {
	# ...
	# Test the setAtaRaidScan method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setAtaRaidScan();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $align = $confDataObj -> getAtaRaidScan();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $align);
	return;
}

#==========================================
# test_setBootTitle
#------------------------------------------
sub test_setBootTitle {
	# ...
	# Test the setBootTitle method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setBootTitle('kiwi-image');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $title = $confDataObj -> getBootTitle();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('kiwi-image', $title);
	return;
}

#==========================================
# test_setBootTitleNoArg
#------------------------------------------
sub test_setBootTitleNoArg {
	# ...
	# Test the setBootTitle method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setBootTitle();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $title = $confDataObj -> getBootTitle();;
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($title);
	return;
}

#==========================================
# test_setBootwait
#------------------------------------------
sub test_setBootwait {
	# ...
	# Test the setBootwait method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setBootwait('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $wait = $confDataObj -> getBootwait();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $wait);
	# Verify state of potentially conflicting settings
	my $reboot = $confDataObj -> getReboot();
	$this -> assert_null($reboot);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_null($shutdown);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();;
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setBootwaitInvalidArg
#------------------------------------------
sub test_setBootwaitInvalidArg {
	# ...
	# Test the setBootwait method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setBootwait(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setBootwait: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setBootwaitNoArg
#------------------------------------------
sub test_setBootwaitNoArg {
	# ...
	# Test the setBootwait method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_reboot} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setBootwait();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $wait = $confDataObj -> getBootwait();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($wait);
	# Verify state of potentially conflicting settings
	my $reboot = $confDataObj -> getReboot();
	$this -> assert_str_equals('true', $reboot);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_null($shutdown);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setInplaceRecovery
#------------------------------------------
sub test_setInplaceRecovery {
	# ...
	# Test the setInplaceRecovery method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setInplaceRecovery('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recov = $confDataObj -> getInplaceRecovery();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $recov);
	return;
}

#==========================================
# test_setInplaceRecoveryInvalidArg
#------------------------------------------
sub test_setInplaceRecoveryInvalidArg {
	# ...
	# Test the setInplaceRecovery method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setInplaceRecovery(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setInplaceRecovery: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setInplaceRecoveryNoArg
#------------------------------------------
sub test_setInplaceRecoveryNoArg {
	# ...
	# Test the setInplaceRecovery method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setInplaceRecovery();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recov = $confDataObj -> getInplaceRecovery();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $recov);
	return;
}

#==========================================
# test_setKiwiInitrd
#------------------------------------------
sub test_setKiwiInitrd {
	# ...
	# Test the setKiwiInitrd method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setKiwiInitrd('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $kinit = $confDataObj -> getKiwiInitrd();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $kinit);
	return;
}

#==========================================
# test_setKiwiInitrdInvalidArg
#------------------------------------------
sub test_setKiwiInitrdInvalidArg {
	# ...
	# Test the setKiwiInitrd method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setKiwiInitrd(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setKiwiInitrd: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setKiwiInitrdNoArg
#------------------------------------------
sub test_setKiwiInitrdNoArg {
	# ...
	# Test the setKiwiInitrd method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setKiwiInitrd();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $kinit = $confDataObj -> getKiwiInitrd();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $kinit);
	return;
}

#==========================================
# test_setPartitionInstall
#------------------------------------------
sub test_setPartitionInstall {
	# ...
	# Test the setPartitionInstall method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setPartitionInstall('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $partIn = $confDataObj -> getPartitionInstall();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $partIn);
	return;
}

#==========================================
# test_setPartitionInstallInvalidArg
#------------------------------------------
sub test_setPartitionInstallInvalidArg {
	# ...
	# Test the setPartitionInstall method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setPartitionInstall(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setPartitionInstall: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setPartitionInstallNoArg
#------------------------------------------
sub test_setPartitionInstallNoArg {
	# ...
	# Test the setPartitionInstall method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setPartitionInstall();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $partIn = $confDataObj -> getPartitionInstall();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $partIn);
	return;
}

#==========================================
# test_setReboot
#------------------------------------------
sub test_setReboot {
	# ...
	# Test the setReboot method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setReboot('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $reboot = $confDataObj -> getReboot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $reboot);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();
	$this -> assert_null($wait);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_null($shutdown);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();;
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setRebootInvalidArg
#------------------------------------------
sub test_setRebootInvalidArg {
	# ...
	# Test the setReboot method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setReboot(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setReboot: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setRebootNoArg
#------------------------------------------
sub test_setRebootNoArg {
	# ...
	# Test the setReboot method with no arg
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_shutdown} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setReboot();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $reboot = $confDataObj -> getReboot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($reboot);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();
	$this -> assert_null($wait);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_str_equals('true',$shutdown);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();;
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setRebootInteractive
#------------------------------------------
sub test_setRebootInteractive {
	# ...
	# Test the setRebootInteractive method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setRebootInteractive('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $rebInter = $confDataObj -> getRebootInteractive();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $rebInter);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();
	$this -> assert_null($wait);
	my $reboot = $confDataObj -> getReboot();
	$this -> assert_null($reboot);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_null($shutdown);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();;
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setRebootInteractiveInvalidArg
#------------------------------------------
sub test_setRebootInteractiveInvalidArg {
	# ...
	# Test the setRebootInteractive method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setRebootInteractive(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setRebootInteractive: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setRebootInteractiveNoArg
#------------------------------------------
sub test_setRebootInteractiveNoArg {
	# ...
	# Test the setRebootInteractive method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_bootwait} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setRebootInteractive();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $rebInter = $confDataObj -> getRebootInteractive();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($rebInter);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();
	$this -> assert_str_equals('true', $wait);
	my $reboot = $confDataObj -> getReboot();
	$this -> assert_null($reboot);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_null($shutdown);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();;
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setRecovery
#------------------------------------------
sub test_setRecovery {
	# ...
	# Test the setRecovery method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setRecovery('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recov = $confDataObj -> getRecovery();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $recov);
	return;
}

#==========================================
# test_setRecoveryInvalidArg
#------------------------------------------
sub test_setRecoveryInvalidArg {
	# ...
	# Test the setRecovery method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setRecovery(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setRecovery: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setRecoveryNoArg
#------------------------------------------
sub test_setRecoveryNoArg {
	# ...
	# Test the setRecovery method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setRecovery();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recov = $confDataObj -> getRecovery();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $recov);
	return;
}

#==========================================
# test_setRecoveryID
#------------------------------------------
sub test_setRecoveryID {
	# ...
	# Test the setRecoveryID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setRecoveryID('8e');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recovID = $confDataObj -> getRecoveryID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8e', $recovID);
	return;
}

#==========================================
# test_setRecoveryIDInvalid
#------------------------------------------
sub test_setRecoveryIDInvalid {
	# ...
	# Test the setRecoveryID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setRecoveryID('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'The recovery partition ID must be 2 digit hex value';
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
# test_setRecoveryIDNoArg
#------------------------------------------
sub test_setRecoveryIDNoArg {
	# ...
	# Test the setRecoveryID method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setRecoveryID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recovID = $confDataObj -> getRecoveryID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($recovID);
	return;
}

#==========================================
# test_setRecoveryPartSize
#------------------------------------------
sub test_setRecoveryPartSize {
	# ...
	# Test the setRecoveryPartSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setRecoveryPartSize('512');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recovSize = $confDataObj -> getRecoveryPartSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('512', $recovSize);
	return;
}

#==========================================
# test_setRecoveryPartSizeInvalid
#------------------------------------------
sub test_setRecoveryPartSizeInvalid {
	# ...
	# Test the setRecoveryPartSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	my $res = $confDataObj -> setRecoveryPartSize('foobar');
	my $msg = $kiwi -> getMessage();
	my $expected = 'The recovery partition size must be an integer value';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	my $recovSize = $confDataObj -> getRecoveryPartSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2048', $recovSize);
	return;
}

#==========================================
# test_setRecoveryPartSizeNoArg
#------------------------------------------
sub test_setRecoveryPartSizeNoArg {
	# ...
	# Test the setRecoveryPartSize method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setRecoveryPartSize();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recovSize = $confDataObj -> getRecoveryPartSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($recovSize);
	return;
}

#==========================================
# test_setRecoveryPartSizeNumber
#------------------------------------------
sub test_setRecoveryPartSizeNumber {
	# ...
	# Test the setRecoveryPartSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setRecoveryPartSize($RECOVER_SIZE);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $recovSize = $confDataObj -> getRecoveryPartSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1024', $recovSize);
	return;
}

#==========================================
# test_setShutdown
#------------------------------------------
sub test_setShutdown {
	# ...
	# Test the setShutdown method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setShutdown('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $down = $confDataObj -> getShutdown();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $down);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();
	$this -> assert_null($wait);
	my $reboot = $confDataObj -> getReboot();
	$this -> assert_null($reboot);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();;
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setShutdownInvalidArg
#------------------------------------------
sub test_setShutdownInvalidArg {
	# ...
	# Test the setShutdown method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setShutdown(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setShutdown: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setShutdownNoArg
#------------------------------------------
sub test_setShutdownNoArg {
	# ...
	# Test the setShutdown method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_reboot} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setShutdown();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $down = $confDataObj -> getShutdown();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($down);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();
	$this -> assert_null($wait);
	my $reboot = $confDataObj -> getReboot();
	$this -> assert_str_equals('true', $reboot);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdownInter = $confDataObj -> getShutdownInteractive();;
	$this -> assert_null($shutdownInter);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setShutdownInteractive
#------------------------------------------
sub test_setShutdownInteractive {
	# ...
	# Test the setShutdownInteractive method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setShutdownInteractive('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $downInter = $confDataObj -> getShutdownInteractive();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $downInter);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();;
	$this -> assert_null( $wait);
	my $reboot = $confDataObj -> getReboot();
	$this -> assert_null($reboot);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_null($shutdown);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setShutdownInteractiveInvalidArg
#------------------------------------------
sub test_setShutdownInteractiveInvalidArg {
	# ...
	# Test the seShutdownInteractivet method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setShutdownInteractive(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setShutdownInteractive: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setShutdownInteractiveNoArg
#------------------------------------------
sub test_setShutdownInteractiveNoArg {
	# ...
	# Test the setShutdownInteractive method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_bootwait} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setShutdownInteractive();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $downInter = $confDataObj -> getShutdownInteractive();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($downInter);
	# Verify state of potentially conflicting settings
	my $wait = $confDataObj -> getBootwait();
	$this -> assert_str_equals('true', $wait);
	my $reboot = $confDataObj -> getReboot();;
	$this -> assert_null($reboot);
	my $rebootInter = $confDataObj -> getRebootInteractive();
	$this -> assert_null($rebootInter);
	my $shutdown = $confDataObj -> getShutdown();
	$this -> assert_null($shutdown);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setSilentBoot
#------------------------------------------
sub test_setSilentBoot {
	# ...
	# Test the setSilentBoot method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setSilentBoot('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $silent = $confDataObj -> getSilentBoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $silent);
	return;
}

#==========================================
# test_setSilentBootInvalidArg
#------------------------------------------
sub test_setSilentBootInvalidArg {
	# ...
	# Test the setSilentBoot method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setSilentBoot(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setSilentBoot: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setSilentBootNoArg
#------------------------------------------
sub test_setSilentBootNoArg {
	# ...
	# Test the setSilentBoot method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setSilentBoot();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $silent = $confDataObj -> getSilentBoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $silent);
	return;
}

#==========================================
# test_setSilentInstall
#------------------------------------------
sub test_setSilentInstall {
	# ...
	# Test the setSilentInstall method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setSilentInstall('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $silent = $confDataObj -> getSilentInstall();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $silent);
	return;
}

#==========================================
# test_setSilentInstallInvalidArg
#------------------------------------------
sub test_setSilentInstallInvalidArg {
	# ...
	# Test the setSilentInstall method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setSilentInstall(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setSilentInstall: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setSilentInstallNoArg
#------------------------------------------
sub test_setSilentInstallNoArg {
	# ...
	# Test the setSilentInstall method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setSilentInstall();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $silent = $confDataObj -> getSilentInstall();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $silent);
	return;
}

#==========================================
# test_setSilentVerify
#------------------------------------------
sub test_setSilentVerify {
	# ...
	# Test the setSilentVerify method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = ( oem_skip_verify => 'true' );
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	$confDataObj = $confDataObj -> setSilentVerify('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $silent = $confDataObj -> getSilentVerify();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $silent);
	my $skip = $confDataObj -> getSkipVerify();
	$this -> assert_null($skip);
	return;
}

#==========================================
# test_setSilentVerifyInvalidArg
#------------------------------------------
sub test_setSilentVerifyInvalidArg {
	# ...
	# Test the setSilentVerify method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setSilentVerify(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setSilentVerify: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setSilentVerifyNoArg
#------------------------------------------
sub test_setSilentVerifyNoArg {
	# ...
	# Test the setSilentVerify method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setSilentVerify();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $silent = $confDataObj -> getSilentVerify();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $silent);
	return;
}

#==========================================
# test_setSkipVerify
#------------------------------------------
sub test_setSkipVerify {
	# ...
	# Test the setSkipVerify method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = ( oem_silent_verify => 'true' );
	my $confDataObj = KIWIXMLOEMConfigData -> new(\%init);
	$confDataObj = $confDataObj -> setSkipVerify('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $skip = $confDataObj -> getSkipVerify();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $skip);
	my $silent = $confDataObj -> getSilentVerify();
	$this -> assert_null($silent);
	return;
}

#==========================================
# test_setSkipVerifyInvalidArg
#------------------------------------------
sub test_setSkipVerifyInvalidArg {
	# ...
	# Test the setSkipVerify method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setSkipVerify(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setSkipVerify: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setSkipVerifyNoArg
#------------------------------------------
sub test_setSkipVerifyNoArg {
	# ...
	# Test the setSkipVerify method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	$init->{oem_silent_verify} = 'false';
	$init->{oem_skip_verify} = 'true';
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setSkipVerify();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $skip = $confDataObj -> getSkipVerify();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $skip);
	return;
}

#==========================================
# test_setSwap
#------------------------------------------
sub test_setSwap {
	# ...
	# Test the setSwap method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setSwap('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $swap = $confDataObj -> getSwap();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $swap);
	return;
}

#==========================================
# test_setSwapInvalidArg
#------------------------------------------
sub test_setSwapInvalidArg {
	# ...
	# Test the setSwap method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setSwap(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setSwap: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setSwapNoArg
#------------------------------------------
sub test_setSwapNoArg {
	# ...
	# Test the setSwap method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setSwap();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $swap = $confDataObj -> getSwap();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $swap);
	my $sSize = $confDataObj -> getSwapSize();
	$this -> assert_null($sSize);
	return;
}

#==========================================
# test_setSwapSize
#------------------------------------------
sub test_setSwapSize {
	# ...
	# Test the setSwapSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setSwapSize('4096');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $sSize = $confDataObj -> getSwapSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('4096', $sSize);
	my $swap = $confDataObj -> getSwap();
	$this -> assert_str_equals('true', $swap);
	return;
}

#==========================================
# test_setSwapSizeNoArg
#------------------------------------------
sub test_setSwapSizeNoArg {
	# ...
	# Test the setSwapSize method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setSwapSize();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $sSize = $confDataObj -> getSwapSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($sSize);
	my $swap = $confDataObj -> getSwap();
	$this -> assert_null($swap);
	return;
}

#==========================================
# test_setSystemSize
#------------------------------------------
sub test_setSystemSize {
	# ...
	# Test the setSystemSize method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setSystemSize('8192');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $size = $confDataObj -> getSystemSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8192', $size);
	return;
}

#==========================================
# test_setSystemSizeNoArg
#------------------------------------------
sub test_setSystemSizeNoArg {
	# ...
	# Test the setSystemSize method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setSystemSize();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $size = $confDataObj -> getSystemSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($size);
	return;
}

#==========================================
# test_setUnattended
#------------------------------------------
sub test_setUnattended {
	# ...
	# Test the setUnattended method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setUnattended('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $auto = $confDataObj -> getUnattended();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $auto);
	return;
}

#==========================================
# test_setUnattendedInvalidArg
#------------------------------------------
sub test_setUnattendedInvalidArg {
	# ...
	# Test the setUnattended method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	my $res = $confDataObj -> setUnattended(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLOEMConfigData:setUnattended: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setUnattendedNoArg
#------------------------------------------
sub test_setUnattendedNoArg {
	# ...
	# Test the setUnattended method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setUnattended();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $auto = $confDataObj -> getUnattended();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $auto);
	my $autoID = $confDataObj -> getUnattendedID();
	$this -> assert_null($autoID);
	return;
}

#==========================================
# test_setUnattendedID
#------------------------------------------
sub test_setUnattendedID {
	# ...
	# Test the setUnattendedID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $confDataObj = KIWIXMLOEMConfigData -> new();
	$confDataObj = $confDataObj -> setUnattendedID('/dev/sdb');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $id = $confDataObj -> getUnattendedID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/dev/sdb', $id);
	return;
}

#==========================================
# test_setUnattendedIDNoArg
#------------------------------------------
sub test_setUnattendedIDNoArg {
	# ...
	# Test the setUnattendedID method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $init = $this -> __getBaseInitHash();
	my $confDataObj = KIWIXMLOEMConfigData -> new($init);
	$confDataObj = $confDataObj -> setUnattendedID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $id = $confDataObj -> getUnattendedID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($id);
	my $auto = $confDataObj -> getUnattended();
	$this -> assert_null($auto);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getBaseInitHash
#------------------------------------------
sub __getBaseInitHash {
	# ...
	# Setup a basic initialization hash for the OEMConfigData object.
	# This method does not configure any of the potentially conflicting
	# settings.
	# ---
	my $this = shift;
	my %init = (
				oem_ataraid_scan          => 'true',
				oem_boot_title            => 'test build',
				oem_inplace_recovery      => 'true',
				oem_kiwi_initrd           => 'false',
				oem_partition_install     => 'false',
				oem_recovery              => 'true',
				oem_recoveryID            => '1234',
				oem_recoveryPartSize      => '2048',
				oem_silent_boot           => 'true',
				oem_silent_install        => 'true',
				oem_silent_verify         => 'true',
				oem_swap                  => 'true',
				oem_swapsize              => '2048',
				oem_systemsize            => '8192',
				oem_unattended            => 'true',
				oem_unattended_id         => '1'
			);
	return \%init;
}

1;
