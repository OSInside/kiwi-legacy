#================
# FILE          : kiwiXMLVMachineData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLVMachineData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLVMachineData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLVMachineData;

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
# test_createNICConfig
#------------------------------------------
sub test_createNICConfig {
	# ...
	# Test the createNICConfig method using an interface name
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $newID = $machDataObj -> createNICConfig('eth10');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_equals(3, $newID);
	my $inf = $machDataObj -> getNICInterface($newID);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('eth10', $inf);
	return;
}

#==========================================
# test_createNICConfigDuplicateIface
#------------------------------------------
sub test_createNICConfigDuplicateIface {
	# ...
	# Test the createNICConfig method when passing interface name
	# that already exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $newID = $machDataObj -> createNICConfig('eth0');
	my $msg = $kiwi -> getMessage();
	my $expected = "createNICConfig: interface device for 'eth0' "
		. 'already exists, ambiguous operation.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($newID);
	return;
}

#==========================================
# test_createNICConfigDuplicateIfaceInInit
#------------------------------------------
sub test_createNICConfigDuplicateIfaceInInit {
	# ...
	# Test the createNICConfig method when passing interface name
	# in the init data that already exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %nicData = ( driver    => 'e1000',
					interface => 'eth0',
					mac       => 'FE:C0:B1:96:64:AD'
				);
	my $machDataObj = $this -> __getVMachineObj();
	my $newID = $machDataObj -> createNICConfig(\%nicData);
	my $msg = $kiwi -> getMessage();
	my $expected = "createNICConfig: interface device for 'eth0' "
		. 'already exists, ambiguous operation.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($newID);
	return;
}

#==========================================
# test_createNICConfigInsufficientData
#------------------------------------------
sub test_createNICConfigInsufficientData {
	# ...
	# Test the createNICConfig method with an initialization hash
	# that does not contain the interface key-value pair
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %nicData = ( driver    => 'e1000',
					mac       => 'FE:C0:B1:96:64:AD'
				);
	my $machDataObj = $this -> __getVMachineObj();
	my $newID = $machDataObj -> createNICConfig(\%nicData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'createNICConfig: provided NIC initialization  '
		. 'structure must provide "interface" key-value pair.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($newID);
	my $existingNICIDs = $machDataObj -> getNICIDs();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expectedIDs = (1, 2);
	$this -> assert_array_equal(\@expectedIDs, $existingNICIDs);
	return;
}

#==========================================
# test_createNICConfigNoArg
#------------------------------------------
sub test_createNICConfigNoArg {
	# ...
	# Test the createNICConfig method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $newID = $machDataObj -> createNICConfig();
	my $msg = $kiwi -> getMessage();
	my $expected = 'createNICConfig: expecting interface ID or hash ref '
		. ' as argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($newID);
	my $existingNICIDs = $machDataObj -> getNICIDs();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expectedIDs = (1, 2);
	$this -> assert_array_equal(\@expectedIDs, $existingNICIDs);
	return;
}

#==========================================
# test_createNICConfigUnsupportedData
#------------------------------------------
sub test_createNICConfigUnsupportedData {
	# ...
	# Test the createNICConfig method with an initialization hash
	# that contains unsupported data in the NIC setup
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %nicData = ( driver    => 'e1000',
					firmware  => 'broadcom',
					interface => 'eth1',
					mac       => 'FE:C0:B1:96:64:AD'
				);
	my $machDataObj = $this -> __getVMachineObj();
	my $newID = $machDataObj -> createNICConfig(\%nicData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'createNICConfig: found unsupported setting '
		. 'in initialization hash.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($newID);
	my $existingNICIDs = $machDataObj -> getNICIDs();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expectedIDs = (1, 2);
	$this -> assert_array_equal(\@expectedIDs, $existingNICIDs);
	return;
}

#==========================================
# test_ctor_duplicateIfaceEntry
#------------------------------------------
sub test_ctor_duplicateIfaceEntry  {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains duplicate interface names
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %diskData = (
		controller => 'scsi',
		device     => 'sda',
		disktype   => 'hdd',
		id         => '1'
	);
	my %disks = ( system => \%diskData );
	my %nicData1 = ( driver    => 'e1000',
					interface => 'eth0',
					mac       => 'FE:C0:B1:96:64:AC'
				);
	my %nicData2 = ( driver    => 'r8169',
					interface => 'eth0',
					mac       => 'FE:C0:B1:96:64:AD',
					mode      => 'bridge'
				);
	my %nics = ( 1 => \%nicData1,
				2 => \%nicData2
			);
	my %init = (
		vmdisks => \%disks,
		vmnics  => \%nics
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Duplicate interface device ID definition, ambiguous '
		. 'operation.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the VMachineData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $machDataObj = KIWIXMLVMachineData -> new('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}


#==========================================
# test_ctor_initImproperArch
#------------------------------------------
sub test_ctor_initImproperArch {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an unsuported arch value
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %diskData = (
		controller => 'scsi',
		device     => 'sda',
		disktype   => 'hdd',
		id         => '1'
	);
	my %disks = ( system => \%diskData );
	my %init = (
		arch    => 's390',
		vmdisks => \%disks
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = "Unsupported VM architecture specified 's390'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperConfEntry
#------------------------------------------
sub test_ctor_initImproperConfEntry {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper type for the vmconfig_entries key
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %diskData = (
		controller => 'scsi',
		device     => 'sda',
		disktype   => 'hdd',
		id         => '1'
	);
	my %disks = ( system => \%diskData );
	my %init = (
		arch             => 'x86_64',
		vmconfig_entries => 'foo',
		vmdisks          => \%disks
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting an array ref as entry of "vmconfig_entries" '
		. 'in the initialization hash.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperDisksEntry
#------------------------------------------
sub test_ctor_initImproperDisksEntry {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper type for the disks key
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => 'foo'
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as entry for "vmdisks" in the '
		. 'initialization hash.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperDisksHash
#------------------------------------------
sub test_ctor_initImproperDisksHash {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper hash for the disks key
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( storage => \%diskData );
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Initialization data for vmdisks incomplete, must '
		. 'provide "system" key with hash ref as value.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperDVDEntry
#------------------------------------------
sub test_ctor_initImproperDVDEntry {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper type for the dvd key
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => 'foo'
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as entry for "vmdvd" in the '
		. 'initialization hash.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperDVDHashNoCont
#------------------------------------------
sub test_ctor_initImproperDVDHashNoCont {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper hash for the dvd key, missing controller
	# entry
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %dvd = ( id => 9 );
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => \%dvd
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Initialization data for vmdvd incomplete, must '
		. 'provide "controller" key-value pair.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperDVDHashNoId
#------------------------------------------
sub test_ctor_initImproperDVDHashNoId {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper hash for the dvd key, missing id
	# entry
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %dvd   = ( controller => 'ide' );
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => \%dvd
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Initialization data for vmdvd incomplete, must '
		. 'provide "id" key-value pair.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperNICEntry
#------------------------------------------
sub test_ctor_initImproperNICEntry {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper type for the nic key
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmnics             => 'foo'
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as entry for "vmnics" in the '
		. 'initialization hash.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperNICHashNoInterf
#------------------------------------------
sub test_ctor_initImproperNoInterf {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains an improper hash for the nic key, missing interface
	# entry
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %dvd = (
		controller => 'ide',
		id         =>  3
	);
	my %nicData1 = (
		driver    => 'r8169',
		interface => 'eth1',
		mac       => 'FE:C0:B1:96:64:AD',
		mode      => 'bridge'
	);
	my %nicData2 = (
		driver => 'e1000',
		mac    => 'FE:C0:B1:96:64:AC'
	);
	my %nics = (
		1 => \%nicData1,
		2 => \%nicData2
	);
	my %init = (
		arch             => 'x86_64',
		vmconfig_entries => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => \%dvd,
		vmnics             => \%nics
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Initialization data for nic incomplete, must provide '
		. '"interface" key-value pair.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initImproperNICID
#------------------------------------------
sub test_ctor_initImproperNICID {
	# ...
	# # Test the VMachineData constructor with an initialization hash
	# that contains an improper type for the index of the nic data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %nicData = (
		driver    => 'e1000',
		interface => 'eth9',
		mac       => 'FE:C0:B1:96:64:AC'
	);
	my %nics = ( 'foo' => \%nicData );
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmnics             => \%nics
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting integer as key for "vmnics" initialization.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains unsupported data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %init = (
	    arch               => 'x86_64',
		vmconfig_entries   => \@confEntries,
		disks              => 'foo'
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLVMachineData: Unsupported keyword argument '
		. "'disks' in initialization structure.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDataDisk
#------------------------------------------
sub test_ctor_initUnsupportedDataDisk {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains unsupported data in the disk setup
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		id         => 1,
		sectors    => 30000
	);
	my %disks = ( system => \%diskData );
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Unsupported option in initialization structure for '
		. "disk configuration, found 'sectors'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDataDvd
#------------------------------------------
sub test_ctor_initUnsupportedDataDvd {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains unsupported data in the DVD setup
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %dvd   = (
		controller => 'ide',
		id         => 2,
		opticont   => 'specialdev'
	);
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => \%dvd
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Unsupported option in initialization structure for '
		. "dvd configuration, found 'opticont'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDataNic
#------------------------------------------
sub test_ctor_initUnsupportedDataNic {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains unsupported data in the NIC setup
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %dvd   = (
		controller => 'ide',
		id         => 2
	);
	my %nicData1 = (
		driver    => 'e1000',
		interface => 'eth0',
		mac       => 'FE:C0:B1:96:64:AC'
	);
	my %nicData2 = (
		driver    => 'e1000',
		firmware  => 'broadcom',
		interface => 'eth1',
		mac       => 'FE:C0:B1:96:64:AD'
	);
	my %nics = (
		1 => \%nicData1,
		2 => \%nicData2
	);
	my %init = (
		arch               => 'x86_64',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => \%dvd,
		vmnics             => \%nics
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Unsupported option in initialization structure for '
		. 'nic configuration';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDataOVFType
#------------------------------------------
sub test_ctor_initUnsupportedDataOVFType {
	# ...
	# Test the VMachineData constructor with an initialization hash
	# that contains unsupported data for the OVF type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %dvd   = (
		controller => 'ide',
		id         => 2
	);
	my %nicData1 = (
		driver    => 'e1000',
		interface => 'eth0',
		mac       => 'FE:C0:B1:96:64:AC'
	);
	my %nicData2 = (
		driver    => 'e1000',
		interface => 'eth1',
		mac       => 'FE:C0:B1:96:64:AD'
	);
	my %nics = (
		1 => \%nicData1,
		2 => \%nicData2
	);
	my %init = (
		arch               => 'x86_64',
		ovftype            => 'ibm',
		'vmconfig_entries' => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => \%dvd,
		vmnics             => \%nics
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Initialization data for ovftype contains unsupported '
		. "value 'ibm'.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
	# ...
	# Test the VMachineData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $machDataObj = KIWIXMLVMachineData -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLVMachineData: must be constructed with a '
		. 'keyword hash as argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($machDataObj);
	return;
}

#==========================================
# test_getArch
#------------------------------------------
sub test_getArch {
	# ...
	# Test the getArch method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $arch = $machDataObj -> getArch();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('x86_64', $arch);
	return;
}

#==========================================
# test_getConfigEntries
#------------------------------------------
sub test_getConfigEntries {
	# ...
	# Test the getConfigEntries method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $configs = $machDataObj -> getConfigEntries();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = qw /foo=bar cd=none/;
	$this -> assert_array_equal(\@expected, $configs);
	return;
}

#==========================================
# test_getDVDController
#------------------------------------------
sub test_getDVDController {
	# ...
	# Test the getDVDController method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $cont = $machDataObj -> getDVDController();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ide', $cont);
	return;
}

#==========================================
# test_getDVDID
#------------------------------------------
sub test_getDVDID {
	# ...
	# Test the getDVDID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $id = $machDataObj -> getDVDID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('0', $id);
	return;
}

#==========================================
# test_getDesiredCPUCnt
#------------------------------------------
sub test_getDesiredCPUCnt {
	# ...
	# Test the getDesiredCPUCnt method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $num = $machDataObj -> getDesiredCPUCnt();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8', $num);
	return;
}

#==========================================
# test_getDesiredMemory
#------------------------------------------
sub test_getDesiredMemory {
	# ...
	# Test the getDesiredMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mem = $machDataObj -> getDesiredMemory();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8192', $mem);
	return;
}

#==========================================
# test_getDomain
#------------------------------------------
sub test_getDomain {
	# ...
	# Test the getDomain method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $dom = $machDataObj -> getDomain();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('domU', $dom);
	return;
}

#==========================================
# test_getGuestOS
#------------------------------------------
sub test_getGuestOS {
	# ...
	# Test the getGuestOS method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $osN = $machDataObj -> getGuestOS();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('SUSE', $osN);
	return;
}

#==========================================
# test_getGuestOSDefault
#------------------------------------------
sub test_getGuestOSDefault {
	# ...
	# Test the getGuestOS method for default value population
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %diskData = (
		controller => 'scsi',
		device     => 'sda',
		disktype   => 'hdd',
		id         => '1'
	);
	my %disks = ( system => \%diskData );
	my %init = (
		HWversion          => '7',
		arch               => 'x86_64',
		memory             => '4096',
		ncpus              => '4',
		vmdisks            => \%disks,
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $guest = $machDataObj -> getGuestOS();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $expected  = 'suse-64';;
	$this -> assert_str_equals($expected, $guest);
	return;
}

#==========================================
# test_getGuestOSDefaultNoArch
#------------------------------------------
sub test_getGuestOSDefaultNoArch {
	# ...
	# Test the getGuestOS method for default value population
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %diskData = (
		controller => 'scsi',
		device     => 'sda',
		disktype   => 'hdd',
		id         => '1'
	);
	my %disks = ( system => \%diskData );
	my %init = (
		HWversion          => '7',
		memory             => '4096',
		ncpus              => '4',
		vmdisks            => \%disks,
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $guest = $machDataObj -> getGuestOS();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $expected  = 'suse';;
	$this -> assert_str_equals($expected, $guest);
	return;
}

#==========================================
# test_getHardwareVersion
#------------------------------------------
sub test_getHardwareVersion {
	# ...
	# Test the getHardwareVersion method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $hwv = $machDataObj -> getHardwareVersion();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('7', $hwv);
	return;
}

#==========================================
# test_getMaxCPUCnt
#------------------------------------------
sub test_getMaxCPUCnt {
	# ...
	# Test the getMaxCPUCnt method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $cnt = $machDataObj ->getMaxCPUCnt ();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('16', $cnt);
	return;
}

#==========================================
# test_getMaxMemory
#------------------------------------------
sub test_getMaxMemory {
	# ...
	# Test the getMaxMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mem = $machDataObj -> getMaxMemory();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('16384', $mem);
	return;
}

#==========================================
# test_getMemory
#------------------------------------------
sub test_getMemory {
	# ...
	# Test the getMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mem = $machDataObj -> getMemory();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('4096', $mem);
	return;
}

#==========================================
# test_getMinCPUCnt
#------------------------------------------
sub test_getMinCPUCnt {
	# ...
	# Test the getMinCPUCnt method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $num = $machDataObj -> getMinCPUCnt();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2', $num);
	return;
}

#==========================================
# test_getMinMemory
#------------------------------------------
sub test_getMinMemory {
	# ...
	# Test the getMinMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mem = $machDataObj -> getMinMemory();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2048', $mem);
	return;
}

#==========================================
# test_getNICDriver
#------------------------------------------
sub test_getNICDriver {
	# ...
	# Test the getNICDriver method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $drv = $machDataObj -> getNICDriver(2);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('r8169', $drv);
	return;
}

#==========================================
# test_getNICDriverInvalidID
#------------------------------------------
sub test_getNICDriverInvalidID {
	# ...
	# Test the getNICDriver method with an invalid NIC IS
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $drv = $machDataObj -> getNICDriver(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICDriver: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($drv);
	return;
}

#==========================================
# test_getNICDriverNoID
#------------------------------------------
sub test_getNICDriverNoID {
	# ...
	# Test the getNICDriver method when no ID is given
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $drv = $machDataObj -> getNICDriver();
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICDriver: called without providing ID for NIC query.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($drv);
	return;
}

#==========================================
# test_getNICIDs
#------------------------------------------
sub test_getNICIDs {
	# ...
	# Test the getNICIDs method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $ids = $machDataObj -> getNICIDs();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = (1, 2);
	$this -> assert_array_equal(\@expected, $ids);
	return;
}

#==========================================
# test_getNICIDsUndefData
#------------------------------------------
sub test_getNICIDsUndefData {
	# ...
	# Test the getNICIDs method if no data is defined
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %diskData = (
		controller => 'scsi',
		device     => 'sda',
		disktype   => 'hdd',
		id         => '1'
	);
	my %disks = ( system => \%diskData );
	my %init = (
		HWversion          => '7',
		arch               => 'x86_64',
		memory             => '4096',
		ncpus              => '4',
		vmdisks            => \%disks,
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $ids = $machDataObj -> getNICIDs();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($ids);
	return;
}

#==========================================
# test_getNICInterface
#------------------------------------------
sub test_getNICInterface {
	# ...
	# Test the getNICInterface method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $inf = $machDataObj -> getNICInterface(1);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('eth0', $inf);
	return;
}

#==========================================
# test_getNICInterfaceInvalidID
#------------------------------------------
sub test_getNICInterfaceInvalidID {
	# ...
	# Test the getNICInterface method with an invalid NIC IS
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $inf = $machDataObj -> getNICInterface(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICInterface: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($inf);
	return;
}

#==========================================
# test_getNICInterfaceNoID
#------------------------------------------
sub test_getNICInterfaceNoID {
	# ...
	# Test the getNICInterface method when no ID is given
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $inf = $machDataObj -> getNICInterface();
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICInterface: called without providing ID for '
		. 'NIC query.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($inf);
	return;
}

#==========================================
# test_getNICMAC
#------------------------------------------
sub test_getNICMAC {
	# ...
	# Test the getNICMAC method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mac = $machDataObj -> getNICMAC(1);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('FE:C0:B1:96:64:AC', $mac);
	return;
}

#==========================================
# test_getNICMACInvalidID
#------------------------------------------
sub test_getNICMACInvalidID {
	# ...
	# Test the getNICMAC method with an invalid NIC IS
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mac = $machDataObj -> getNICMAC(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICMAC: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($mac);
	return;
}

#==========================================
# test_getNICMACNoID
#------------------------------------------
sub test_getNICMACNoID {
	# ...
	# Test the getNICMAC method when no ID is given
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mac = $machDataObj -> getNICMAC();
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICMAC: called without providing ID for '
		. 'NIC query.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($mac);
	return;
}

#==========================================
# test_getNICMode
#------------------------------------------
sub test_getNICMode {
	# ...
	# Test the getNICMode method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mode = $machDataObj -> getNICMode(2);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('bridge', $mode);
	# Test on an interface where the mode is not defined
	$mode = $machDataObj -> getNICMode(1);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($mode);
	return;
}

#==========================================
# test_getNICModeInvalidID
#------------------------------------------
sub test_getNICModeInvalidID {
	# ...
	# Test the getNICMode method with an invalid NIC IS
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mode = $machDataObj -> getNICMode(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICMode: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($mode);
	return;
}

#==========================================
# test_getNICModeNoID
#------------------------------------------
sub test_getNICModeNoID {
	# ...
	# Test the getNICMode method when no ID is given
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $mode = $machDataObj -> getNICMode();
	my $msg = $kiwi -> getMessage();
	my $expected = 'getNICMode: called without providing ID for '
		. 'NIC query.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($mode);
	return;
}

#==========================================
# test_getNumCPUs
#------------------------------------------
sub test_getNumCPUs {
	# ...
	# Test the getNumCPUs method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $num = $machDataObj -> getNumCPUs();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('4', $num);
	return;
}

#==========================================
# test_getOVFType
#------------------------------------------
sub test_getOVFType {
	# ...
	# Test the getOVFType method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $ovft = $machDataObj -> getOVFType();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('zvm', $ovft);
	return;
}

#==========================================
# test_getSystemDiskController
#------------------------------------------
sub test_getSystemDiskController {
	# ...
	# Test the getSystemDiskController method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $cont = $machDataObj -> getSystemDiskController();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('scsi', $cont);
	return;
}

#==========================================
# test_getSystemDiskDevice
#------------------------------------------
sub test_getSystemDiskDevice {
	# ...
	# Test the getSystemDiskDevice method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $dev = $machDataObj -> getSystemDiskDevice();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('sda', $dev);
	return;
}

#==========================================
# test_getSystemDiskType
#------------------------------------------
sub test_getSystemDiskType {
	# ...
	# Test the getSystemDiskType method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $devt = $machDataObj -> getSystemDiskType();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('hdd', $devt);
	return;
}

#==========================================
# test_getSystemDiskID
#------------------------------------------
sub test_getSystemDiskID {
	# ...
	# Test the getSystemDiskID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $sdID = $machDataObj -> getSystemDiskID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1', $sdID);
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
	my $machDataObj = $this -> __getVMachineObj();
	my $elem = $machDataObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<machine '
		. 'arch="x86_64" '
		. 'des_cpu="8" '
		. 'des_memory="8192" '
		. 'domain="domU" '
		. 'guestOS="SUSE" '
		. 'HWversion="7" '
		. 'max_cpu="16" '
		. 'max_memory="16384" '
		. 'memory="4096" '
		. 'min_cpu="2" '
		. 'min_memory="2048" '
		. 'ncpus="4" '
		. 'ovftype="zvm">'
		. '<vmconfig-entry>foo=bar</vmconfig-entry>'
		. '<vmconfig-entry>cd=none</vmconfig-entry>'
		. '<vmdisk controller="scsi" device="sda" disktype="hdd" id="1"/>'
		. '<vmdvd controller="ide" id="0"/>'
		. '<vmnic interface="eth0" driver="e1000" mac="FE:C0:B1:96:64:AC"/>'
		. '<vmnic interface="eth1" driver="r8169" mac="FE:C0:B1:96:64:AD" '
		. 'mode="bridge"/>'
		. '</machine>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_setArch
#------------------------------------------
sub test_setArch {
	# ...
	# Test the setArch method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setArch('ix86');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $arch = $machDataObj -> getArch();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ix86', $arch);
	return;
}

#==========================================
# test_setArchInvalidArg
#------------------------------------------
sub test_setArchInvalidArg {
	# ...
	# Test the setArch method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setArch('s390');
	my $msg = $kiwi -> getMessage();
	my $expected = "setArch: unsupported architecture 's390' provided, "
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $arch = $machDataObj -> getArch();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('x86_64',$arch);
	return;
}

#==========================================
# test_setArchNoArg
#------------------------------------------
sub test_setArchNoArg {
	# ...
	# Test the setArch method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setArch();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setArch: no architecture argument provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $arch = $machDataObj -> getArch();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('x86_64', $arch);
	return;
}

#==========================================
# test_setConfigEntries
#------------------------------------------
sub test_setConfigEntries {
	# ...
	# Test the setConfigEntries method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my @config = qw \salsa=hot foo=bar\;
	$machDataObj = $machDataObj -> setConfigEntries(\@config);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $vmConfig = $machDataObj -> getConfigEntries();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_array_equal(\@config, $vmConfig);
	return;
}

#==========================================
# test_setConfigEntriesInvalidArg
#------------------------------------------
sub test_setConfigEntriesInvalidArg {
	# ...
	# Test the setConfigEntries method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setConfigEntries('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setConfigEntries: expecting ARRAY ref as argument, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $config = $machDataObj -> getConfigEntries();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = qw /foo=bar cd=none/;
	$this -> assert_array_equal(\@expected, $config);
	return;
}

#==========================================
# test_setConfigEntriesNoArg
#------------------------------------------
sub test_setConfigEntriesNoArg {
	# ...
	# Test the setConfigEntries method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setConfigEntries();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setConfigEntries: no configuration file entries provided, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $config = $machDataObj -> getConfigEntries();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expectedConf = qw /foo=bar cd=none/;
	$this -> assert_array_equal(\@expectedConf, $config);
	return;
}

#==========================================
# test_setDVDController
#------------------------------------------
sub test_setDVDController {
	# ...
	# Test the setDVDController method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setDVDController('scsi');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $controller = $machDataObj -> getDVDController();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('scsi', $controller);
	return;
}

#==========================================
# test_setDVDControllerNoArg
#------------------------------------------
sub test_setDVDControllerNoArg {
	# ...
	# Test the setDVDController method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setDVDController();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDVDController: no controller data provided, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $controller = $machDataObj -> getDVDController();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ide', $controller);
	return;
}

#==========================================
# test_setDVDID
#------------------------------------------
sub test_setDVDID {
	# ...
	# Test the setDVDID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setDVDID('4');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $id = $machDataObj -> getDVDID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('4', $id);
	return;
}

#==========================================
# test_setDVDIDNoArg
#------------------------------------------
sub test_setDVDIDNoArg {
	# ...
	# Test the setDVDID method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setDVDID();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDVDID: no ID data provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $id = $machDataObj -> getDVDID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('0', $id);
	return;
}

#==========================================
# test_setDesiredCPUCnt
#------------------------------------------
sub test_setDesiredCPUCnt {
	# ...
	# Test the setDesiredCPUCnt method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setDesiredCPUCnt('5');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $cnt = $machDataObj -> getDesiredCPUCnt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('5', $cnt);
	return;
}

#==========================================
# test_setDesiredCPUCntNoArg
#------------------------------------------
sub test_setDesiredCPUCntNoArg {
	# ...
	# Test the setDesiredCPUCnt method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setDesiredCPUCnt();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDesiredCPUCnt: no cpu count provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $num = $machDataObj -> getDesiredCPUCnt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8', $num);
	return;
}

#==========================================
# test_setDesiredMemory
#------------------------------------------
sub test_setDesiredMemory {
	# ...
	# Test the setDesiredMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setDesiredMemory('2048');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $mem = $machDataObj -> getDesiredMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2048', $mem);
	return;
}

#==========================================
# test_setDesiredMemoryNoArg
#------------------------------------------
sub test_setDesiredMemoryNoArg {
	# ...
	# Test the setDesiredMemory method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setDesiredMemory();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDesiredMemory: no memory amount provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $mem = $machDataObj -> getDesiredMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8192', $mem);
	return;
}

#==========================================
# test_setDomain
#------------------------------------------
sub test_setDomain {
	# ...
	# Test the setDomain method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setDomain('dom0');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $dom = $machDataObj -> getDomain();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('dom0', $dom);
	return;
}

#==========================================
# test_setDomainNoArg
#------------------------------------------
sub test_setDomainNoArg {
	# ...
	# Test the setDomain method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setDomain();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDomain: no domain provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $dom = $machDataObj -> getDomain();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('domU', $dom);
	return;
}

#==========================================
# test_setGuestOS
#------------------------------------------
sub test_setGuestOS {
	# ...
	# Test the setGuestOS method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setGuestOS('SLES');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $guest = $machDataObj -> getGuestOS();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('SLES', $guest);
	return;
}

#==========================================
# test_setGuestOSNoArg
#------------------------------------------
sub test_setGuestOSNoArg {
	# ...
	# Test the setGuestOS method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setGuestOS();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setGuestOS: no guest OS name provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $osN = $machDataObj -> getGuestOS();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('SUSE', $osN);
	return;
}

#==========================================
# test_setHardwareVersion
#------------------------------------------
sub test_setHardwareVersion {
	# ...
	# Test the setHardwareVersion method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setHardwareVersion('9');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $hwv = $machDataObj -> getHardwareVersion();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('9', $hwv);
	return;
}

#==========================================
# test_setHardwareVersionNoArg
#------------------------------------------
sub test_setHardwareVersionNoArg {
	# ...
	# Test the setHardwareVersion method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setHardwareVersion();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setHardwareVersion: no version data provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $hwv = $machDataObj -> getHardwareVersion();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('7', $hwv);
	return;
}

#==========================================
# test_setMaxCPUCnt
#------------------------------------------
sub test_setMaxCPUCnt {
	# ...
	# Test the setMaxCPUCnt method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setMaxCPUCnt('20');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $cnt = $machDataObj -> getMaxCPUCnt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('20', $cnt);
	return;
}

#==========================================
# test_setMaxCPUCntNoArg
#------------------------------------------
sub test_setMaxCPUCntNoArg {
	# ...
	# Test the setMaxCPUCnt method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setMaxCPUCnt();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setMaxCPUCnt: no value provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $cnt = $machDataObj -> getMaxCPUCnt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('16', $cnt);
	return;
}

#==========================================
# test_setMaxMemory
#------------------------------------------
sub test_setMaxMemory {
	# ...
	# Test the setMaxMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setMaxMemory('8192');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $mem = $machDataObj -> getMaxMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8192', $mem);
	return;
}

#==========================================
# test_setMaxMemoryNoArg
#------------------------------------------
sub test_setMaxMemoryNoArg {
	# ...
	# Test the setMaxMemory method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setMaxMemory();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setMaxMemory: no value provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $mem = $machDataObj -> getMaxMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('16384', $mem);
	return;
}

#==========================================
# test_setMemory
#------------------------------------------
sub test_setMemory {
	# ...
	# Test the setMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setMemory('1024');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $mem = $machDataObj -> getMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1024', $mem);
	return;
}

#==========================================
# test_setMemoryNoArg
#------------------------------------------
sub test_setMemoryNoArg {
	# ...
	# Test the setMemory method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setMemory();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setMemory: no value provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $mem = $machDataObj -> getMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('4096', $mem);
	return;
}

#==========================================
# test_setMinCPUCnt
#------------------------------------------
sub test_setMinCPUCnt {
	# ...
	# Test the setMinCPUCnt method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setMinCPUCnt('3');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $cnt = $machDataObj -> getMinCPUCnt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('3', $cnt);
	return;
}

#==========================================
# test_setMinCPUCntNoArg
#------------------------------------------
sub test_setMinCPUCntNoArg {
	# ...
	# Test the setMinCPUCnt method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setMinCPUCnt();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setMinCPUCnt: no value provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $cnt = $machDataObj -> getMinCPUCnt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2', $cnt);
	return;
}

#==========================================
# test_setMinMemory
#------------------------------------------
sub test_setMinMemory {
	# ...
	# Test the setMinMemory method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setMinMemory('512');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $mem = $machDataObj -> getMinMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('512', $mem);
	return;
}

#==========================================
# test_setMinMemoryNoArg
#------------------------------------------
sub test_setMinMemoryNoArg {
	# ...
	# Test the setMinMemory method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setMinMemory();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setMinMemory: no value provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $mem = $machDataObj -> getMinMemory();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('2048', $mem);
	return;
}

#==========================================
# test_setNICDriver
#------------------------------------------
sub test_setNICDriver {
	# ...
	# Test the setNICDriver method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setNICDriver(1, 'b43');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $drv = $machDataObj -> getNICDriver(1);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('b43', $drv);
	return;
}

#==========================================
# test_setNICDriverInvalidID
#------------------------------------------
sub test_setNICDriverInvalidID {
	# ...
	# Test the setNICDriver method with an invalid ID
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICDriver(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICDriver: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICDriverNoConfig
#------------------------------------------
sub test_setNICDriverNoConfig {
	# ...
	# Test the setNICDriver method if no NIC configuration exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %init = ( vmdisks => \%disks );
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $res = $machDataObj -> setNICDriver(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICDriver: no NICS configured, call createNICConfig '
		. 'first';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICDriverNoDriverArg
#------------------------------------------
sub test_setNICDriverNoDriverArg {
	# ...
	# Test the setNICDriver method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICDriver(2);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICDriver: no driver provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $drv = $machDataObj -> getNICDriver(2);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('r8169', $drv);
	return;
}

#==========================================
# test_setNICInterface
#------------------------------------------
sub test_setNICInterface {
	# ...
	# Test the setNICInterface method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setNICInterface(2, 'eth4');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $iface = $machDataObj -> getNICInterface(2);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('eth4', $iface);
	return;
}

#==========================================
# test_setNICInterfaceInvalidID
#------------------------------------------
sub test_setNICInterfaceInvalidID {
	# ...
	# Test the setNICInterface method with an invalid ID
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICInterface(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICInterface: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICInterfaceNoConfig
#------------------------------------------
sub test_setNICInterfaceNoConfig {
	# ...
	# Test the setNICInterface method if no NIC configuration exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %init = ( vmdisks => \%disks );
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $res = $machDataObj -> setNICInterface(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICInterface: no NICS configured, call createNICConfig '
		. 'first';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICInterfaceNoInterfaceArg
#------------------------------------------
sub test_setNICInterfaceNoInterfaceArg {
	# ...
	# Test the setNICInterface method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICInterface(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICInterface: no interface provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $iface = $machDataObj -> getNICInterface(1);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('eth0', $iface);
	return;
}

#==========================================
# test_setNICMAC
#------------------------------------------
sub test_setNICMAC {
	# ...
	# Test the setNICMAC method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setNICMAC(1, '00:16:3e:7e:18:24');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $mac = $machDataObj -> getNICMAC(1);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('00:16:3e:7e:18:24', $mac);
	return;
}

#==========================================
# test_setNICMACInvalidID
#------------------------------------------
sub test_setNICMACInvalidID {
	# ...
	# Test the setNICMAC method with an invalid ID
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICMAC(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICMAC: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICMACNoConfig
#------------------------------------------
sub test_setNICMACNoConfig {
	# ...
	# Test the setNICMAC method if no NIC configuration exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %init = ( vmdisks => \%disks );
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $res = $machDataObj -> setNICMAC(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICMAC: no NICS configured, call createNICConfig '
		. 'first';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICMACNoMACArg
#------------------------------------------
sub test_setNICMACNoMACArg {
	# ...
	# Test the setNICMAC method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICMAC(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICMAC: no MAC provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $mac = $machDataObj -> getNICMAC(1);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('FE:C0:B1:96:64:AC', $mac);
	return;
}

#==========================================
# test_setNICMode
#------------------------------------------
sub test_setNICMode {
	# ...
	# Test the setNICMode method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setNICMode(1, 'bridge');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $mode = $machDataObj -> getNICMode(1);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('bridge', $mode);
	return;
}

#==========================================
# test_setNICModeInvalidID
#------------------------------------------
sub test_setNICModeInvalidID {
	# ...
	# Test the setNICMode method with an invalid ID
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICMode(3);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICMode: invalid ID for NIC query given, no data '
		. 'exists.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICModeNoConfig
#------------------------------------------
sub test_setNICModeNoConfig {
	# ...
	# Test the setNICMode method if no NIC configuration exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %diskData    = (
		controller => 'scsi',
		id         => 1
	);
	my %disks = ( system => \%diskData );
	my %init = ( vmdisks => \%disks );
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $res = $machDataObj -> setNICMode(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICMode: no NICS configured, call createNICConfig '
		. 'first';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setNICModeNoModeArg
#------------------------------------------
sub test_setNICModeNoModeArg {
	# ...
	# Test the setNICMode method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNICMode(2);
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNICMode: no mode provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $mode = $machDataObj -> getNICMode(2);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('bridge', $mode);
	return;
}

#==========================================
# test_setNumCPUs
#------------------------------------------
sub test_setNumCPUs {
	# ...
	# Test the setNumCPUs method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setNumCPUs('4');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $ncpus = $machDataObj -> getNumCPUs();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('4', $ncpus);
	return;
}

#==========================================
# test_setNumCPUsNoArg
#------------------------------------------
sub test_setNumCPUsNoArg {
	# ...
	# Test the  method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setNumCPUs();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setNumCPUs: no value provided, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	my $num = $machDataObj -> getNumCPUs();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('4', $num);
	return;
}

#==========================================
# test_setOVFType
#------------------------------------------
sub test_setOVFType {
	# ...
	# Test the setOVFType method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setOVFType('xen');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $ovft = $machDataObj -> getOVFType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xen', $ovft);
	return;
}

#==========================================
# test_setOVFTypeInvalidArg
#------------------------------------------
sub test_setOVFTypeInvalidArg {
	# ...
	# Test the setOVFType method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setOVFType('ibm');
	my $msg = $kiwi -> getMessage();
	my $expected = "setOVFtype: unsupported OVF type 'ibm' provided, "
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $ovft = $machDataObj -> getOVFType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('zvm', $ovft);
	return;
}

#==========================================
# test_setOVFTypeNoArg
#------------------------------------------
sub test_setOVFTypeNoArg {
	# ...
	# Test the setOVFType method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setOVFType();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setOVFtype: no OVF type argument provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $ovft = $machDataObj -> getOVFType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('zvm', $ovft);
	return;
}

#==========================================
# test_setSystemDiskController
#------------------------------------------
sub test_setSystemDiskController {
	# ...
	# Test the setSystemDiskController method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setSystemDiskController('scsi');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $cont = $machDataObj -> getSystemDiskController();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('scsi', $cont);
	return;
}

#==========================================
# test_setSystemDiskControllerNoArg
#------------------------------------------
sub test_setSystemDiskControllerNoArg {
	# ...
	# Test the setSystemDiskController method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setSystemDiskController();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setSystemDiskController: no value provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $cont = $machDataObj -> getSystemDiskController();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('scsi', $cont);
	return;
}

#==========================================
# test_setSystemDiskDevice
#------------------------------------------
sub test_setSystemDiskDevice {
	# ...
	# Test the setSystemDiskDevice method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setSystemDiskDevice('sdb');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $dev = $machDataObj -> getSystemDiskDevice();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('sdb', $dev);
	return;
}

#==========================================
# test_setSystemDiskDeviceNoArg
#------------------------------------------
sub test_setSystemDiskDeviceNoArg {
	# ...
	# Test the setSystemDiskDevice method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setSystemDiskDevice();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setSystemDiskDevice: no value provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $dev = $machDataObj -> getSystemDiskDevice();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('sda', $dev);
	return;
}

#==========================================
# test_setSystemDiskType
#------------------------------------------
sub test_setSystemDiskType {
	# ...
	# Test the setSystemDiskType method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setSystemDiskType('hdd');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $devt = $machDataObj -> getSystemDiskType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('hdd', $devt);
	return;
}

#==========================================
# test_setSystemDiskTypeNoArg
#------------------------------------------
sub test_setSystemDiskTypeNoArg {
	# ...
	# Test the setSystemDiskType method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setSystemDiskType();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setSystemDiskType: no value provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $devt = $machDataObj -> getSystemDiskType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('hdd', $devt);
	return;
}

#==========================================
# test_setSystemDiskID
#------------------------------------------
sub test_setSystemDiskID {
	# ...
	# Test the setSystemDiskID method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	$machDataObj = $machDataObj -> setSystemDiskID('3');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $sdID = $machDataObj -> getSystemDiskID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('3', $sdID);
	return;
}

#==========================================
# test_setSystemDiskIDNoArg
#------------------------------------------
sub test_setSystemDiskIDNoArg {
	# ...
	# Test the setSystemDiskID method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $machDataObj = $this -> __getVMachineObj();
	my $res = $machDataObj -> setSystemDiskID();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setSystemDiskID: no value provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $sdID = $machDataObj -> getSystemDiskID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1', $sdID);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getVMachineObj
#------------------------------------------
sub __getVMachineObj {
	# ...
	# Helper to construct a fully populated VMachineData object using
	# initialization.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @confEntries = qw /foo=bar cd=none/;
	my %diskData = (
		controller => 'scsi',
		device     => 'sda',
		disktype   => 'hdd',
		id         => '1'
	);
	my %disks = ( system => \%diskData );
	my %dvd = (
		controller => 'ide',
		id         => '0'
	);
	my %nicData1 = (
		driver    => 'e1000',
		interface => 'eth0',
		mac       => 'FE:C0:B1:96:64:AC'
	);
	my %nicData2 = (
		driver    => 'r8169',
		interface => 'eth1',
		mac       => 'FE:C0:B1:96:64:AD',
		mode      => 'bridge'
	);
	my %nics = (
		1 => \%nicData1,
		2 => \%nicData2
	);
	my %init = (
		HWversion          => '7',
		arch               => 'x86_64',
		des_cpu            => '8',
		des_memory         => '8192',
		domain             => 'domU',
		guestOS            => 'SUSE',
		max_cpu            => '16',
		max_memory         => '16384',
		memory             => '4096',
		min_cpu            => '2',
		min_memory         => '2048',
		ncpus              => '4',
		ovftype            => 'zvm',
		vmconfig_entries   => \@confEntries,
		vmdisks            => \%disks,
		vmdvd              => \%dvd,
		vmnics             => \%nics
	);
	my $machDataObj = KIWIXMLVMachineData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($machDataObj);
	return $machDataObj;
}

1;
