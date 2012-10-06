#================
# FILE          : kiwiXMLTypeData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLTypeData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLTypeData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLTypeData;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {kiwi} = Common::ktLog -> new();

	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the TypeData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the TypeData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, 'foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initInvalidCheckprebuiltValue
#------------------------------------------
sub test_ctor_initInvalidCheckprebuiltValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the checkprebuilt value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( checkprebuilt => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'checkprebuilt' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidCompressedValue
#------------------------------------------
sub test_ctor_initInvalidCompressedValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the compressed value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( compressed => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'compressed' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidFsnocheckValue
#------------------------------------------
sub test_ctor_initInvalidFsnocheckValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the fsnocheck value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( fsnocheck => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'fsnocheck' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidHybridValue
#------------------------------------------
sub test_ctor_initInvalidHybridValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the hybrid value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( hybrid => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'hybrid' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidHybridpersistentValue
#------------------------------------------
sub test_ctor_initInvalidHybridpersistentValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the hybridpersistent value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( hybridpersistent => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'hybridpersistent' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidInstallisoValue
#------------------------------------------
sub test_ctor_initInvalidInstallisoValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the installiso value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( installiso => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'installiso' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidInstallprovidefailsafeValue
#------------------------------------------
sub test_ctor_initInvalidInstallprovidefailsafeValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the installprovidefailsafe value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( installprovidefailsafe => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'installprovidefailsafe' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidInstallstickValue
#------------------------------------------
sub test_ctor_initInvalidInstallstickValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the installstick value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( installstick => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'installstick' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidPrimaryValue
#------------------------------------------
sub test_ctor_initInvalidPrimaryValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the primary value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( primary => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'primary' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidRamonlyValue
#------------------------------------------
sub test_ctor_initInvalidRamonlyValue {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the ramonly value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( ramonly => 'foo' );
	 my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'Unrecognized value for boolean '
		 . "'ramonly' in initialization hash, expecting "
	     . '"true" or "false".';
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($typeDataObj);
	 return;
}

#==========================================
# test_ctor_initUnsupportedBootLoad
#------------------------------------------
sub test_ctor_initUnsupportedBootLoad {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data for the bootloader
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( bootloader => 'lnxBoot' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified bootloader '
		. "'lnxBoot' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( bootparam => 'kiwidebug=1' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Unsupported option in initialization structure '
		. "found 'bootparam'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDevPersist
#------------------------------------------
sub test_ctor_initUnsupportedDevPersist {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data for the device persistence
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( devicepersistency => 'mapper-id' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified device persistency '
		. "'mapper-id' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedFilesystem
#------------------------------------------
sub test_ctor_initUnsupportedFilesystem {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data for the filesystem
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( filesystem => 'aufs' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified filesystem '
		. "'aufs' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedFlags
#------------------------------------------
sub test_ctor_initUnsupportedFlags {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data for flags
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( flags => 'gzipped' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified flags value '
		. "'gzipped' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedFormat
#------------------------------------------
sub test_ctor_initUnsupportedFormat {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data for the format setting
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( format => 'xen' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified format '
	. "'xen' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedImage
#------------------------------------------
sub test_ctor_initUnsupportedImage {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data for image setting
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( image => 'qcow9' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified image '
		. "'qcow9' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedInstBoot
#------------------------------------------
sub test_ctor_initUnsupportedInstBoot {
	# ...
	# Test the TypeData constructor with an initialization hash
	# that contains unsupported data for installboot setting
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( installboot => 'drive' );
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified installboot option '
		. "'drive' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($typeDataObj);
	return;
}

#==========================================
# test_ctor_withInit
#------------------------------------------
sub test_ctor_withInit {
	# ...
	# Test the TypeData constructor with an initialization hash
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
my %init = ( boot        => 'oem/suse-12.2',
				boottimeout => '2',
				fsreadonly  => 'btrfs',
				hybrid      => 'false'
			);
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($typeDataObj);
	return;
}

#==========================================
# test_getBootImageDescript
#------------------------------------------
sub test_getBootImageDescript {
	# ...
	# Test the getBootImageDescript method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $path = $typeDataObj -> getBootImageDescript();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/oem/suse-12.2', $path);
	return;
}

#==========================================
# test_getBootKernel
#------------------------------------------
sub test_getBootKernel {
	# ...
	# Test the geBootKernelt method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $bootK = $typeDataObj -> getBootKernel();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xenk', $bootK);
	return;
}

#==========================================
# test_getBootLoader
#------------------------------------------
sub test_getBootLoader {
	# ...
	# Test the getBootLoader method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $name = $typeDataObj -> getBootLoader();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('grub', $name);
	return;
}

#==========================================
# test_getBootPartitionSize
#------------------------------------------
sub test_getBootPartitionSize {
	# ...
	# Test the getBootPartitionSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $size = $typeDataObj -> getBootPartitionSize();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('512M', $size);
	return;
}

#==========================================
# test_getBootProfile
#------------------------------------------
sub test_getBootProfile {
	# ...
	# Test the getBootProfile method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $prof = $typeDataObj -> getBootProfile();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('std', $prof);
	return;
}

#==========================================
# test_getBootTimeout
#------------------------------------------
sub test_getBootTimeout {
	# ...
	# Test the getBootTimeout method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $time = $typeDataObj -> getBootTimeout();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('5', $time);
	return;
}

#==========================================
# test_getCheckPrebuilt
#------------------------------------------
sub test_getCheckPrebuilt {
	# ...
	# Test the getCheckPrebuilt method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $preb = $typeDataObj -> getCheckPrebuilt();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $preb);
	return;
}

#==========================================
# test_getCompressed
#------------------------------------------
sub test_getCompressed {
	# ...
	# Test the getCompressed method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $comp = $typeDataObj -> getCompressed();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $comp);
	return;
}

#==========================================
# test_getDevicePersistent
#------------------------------------------
sub test_getDevicePersistent {
	# ...
	# Test the getDevicePersistent method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $kind = $typeDataObj -> getDevicePersistent();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('by-uuid', $kind);
	return;
}

#==========================================
# test_getEditBootConfig
#------------------------------------------
sub test_getEditBootConfig {
	# ...
	# Test the getEditBootConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $conf = $typeDataObj -> getEditBootConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myscript', $conf);
	return;
}

#==========================================
# test_getFilesystem
#------------------------------------------
sub test_getFilesystem {
	# ...
	# Test the getFilesystem method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $fs = $typeDataObj -> getFilesystem();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xfs', $fs);
	return;
}

#==========================================
# test_getFlags
#------------------------------------------
sub test_getFlags {
	# ...
	# Test the getFlags method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $flags = $typeDataObj -> getFlags();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('compressed', $flags);
	return;
}

#==========================================
# test_getFormat
#------------------------------------------
sub test_getFormat {
	# ...
	# Test the getFormat method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $format = $typeDataObj -> getFormat();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('qcow2', $format);
	return;
}

#==========================================
# test_getFSMountOptions
#------------------------------------------
sub test_getFSMountOptions {
	# ...
	# Test the getFSMountOptions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $opt = $typeDataObj -> getFSMountOptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('barrier', $opt);
	return;
}

#==========================================
# test_getFSNoCheck
#------------------------------------------
sub test_getFSNoCheck {
	# ...
	# Test the getFSNoCheck method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $check = $typeDataObj -> getFSNoCheck();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $check);
	return;
}

#==========================================
# test_getFSReadOnly
#------------------------------------------
sub test_getFSReadOnly {
	# ...
	# Test the getFSReadOnly method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $fs = $typeDataObj -> getFSReadOnly();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ext3', $fs);
	return;
}

#==========================================
# test_getFSReadWrite
#------------------------------------------
sub test_getFSReadWrite {
	# ...
	# Test the getFSReadWrite method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $fs = $typeDataObj -> getFSReadWrite();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xfs', $fs);
	return;
}

#==========================================
# test_getHybrid
#------------------------------------------
sub test_getHybrid {
	# ...
	# Test the getHybrid method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $hybrid = $typeDataObj -> getHybrid();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $hybrid);
	return;
}

#==========================================
# test_getHybridPersistent
#------------------------------------------
sub test_getHybridPersistent {
	# ...
	# Test the getHybridPersistent method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $hybP = $typeDataObj -> getHybridPersistent();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $hybP);
	return;
}

#==========================================
# test_getImageType
#------------------------------------------
sub test_getImageType {
	# ...
	# Test the getImageType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $type = $typeDataObj -> getImageType();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('oem', $type);
	return;
}

#==========================================
# test_getInstallBoot
#------------------------------------------
sub test_getInstallBoot {
	# ...
	# Test the getInstallBoot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $boot = $typeDataObj -> getInstallBoot();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('install', $boot);
	return;
}

#==========================================
# test_getInstallIso
#------------------------------------------
sub test_getInstallIso {
	# ...
	# Test the getInstallIso method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $iso = $typeDataObj -> getInstallIso();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $iso);
	return;
}

#==========================================
# test_getInstallFailsafe
#------------------------------------------
sub test_getInstallFailsafe {
	# ...
	# Test the getInstallFailsafe method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $instFS = $typeDataObj -> getInstallFailsafe();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $instFS);
	return;
}

#==========================================
# test_getInstallStick
#------------------------------------------
sub test_getInstallStick {
	# ...
	# Test the getInstallStick method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $stick = $typeDataObj -> getInstallStick();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $stick);
	return;
}

#==========================================
# test_getKernelCmdOpts
#------------------------------------------
sub test_getKernelCmdOpts {
	# ...
	# Test the getKernelCmdOpts method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $kOpts = $typeDataObj -> getKernelCmdOpts();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('kiwidebug=1', $kOpts);
	return;
}

#==========================================
# test_getLucksPass
#------------------------------------------
sub test_getLucksPass {
	# ...
	# Test the getLucksPass method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $pass = $typeDataObj -> getLucksPass();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('notApass', $pass);
	return;
}

#==========================================
# test_getPrimary
#------------------------------------------
sub test_getPrimary {
	# ...
	# Test the getPrimary method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $prime = $typeDataObj -> getPrimary();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $prime);
	return;
}

#==========================================
# test_getRAMOnly
#------------------------------------------
sub test_getRAMOnly {
	# ...
	# Test the getRAMOnly method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $rOnly = $typeDataObj -> getRAMOnly();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $rOnly);
	return;
}

#==========================================
# test_getVGA
#------------------------------------------
sub test_getVGA {
	# ...
	# Test the getVGA method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $vga = $typeDataObj -> getVGA();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('0x344', $vga);
	return;
}

#==========================================
# test_getVolID
#------------------------------------------
sub test_getVolID {
	# ...
	# Test the getVolID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $id = $typeDataObj -> getVolID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myImg', $id);
	return;
}

#==========================================
# test_setBootImageDescript
#------------------------------------------
sub test_setBootImageDescript {
	# ...
	# Test the setBootImageDescript method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setBootImageDescript('vmxboot/suse-12.2');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $path = $typeDataObj -> getBootImageDescript();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('vmxboot/suse-12.2', $path);
	return;
}

#==========================================
# test_setBootImageDescriptNoArg
#------------------------------------------
sub test_setBootImageDescriptNoArg {
	# ...
	# Test the setBootImageDescript method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setBootImageDescript();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootImageDescript: no boot description given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $path = $typeDataObj -> getBootImageDescript();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/oem/suse-12.2', $path);
	return;
}

#==========================================
# test_setBootKernel
#------------------------------------------
sub test_setBootKernel {
	# ...
	# Test the setBootKernel method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setBootKernel('default');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $bootK = $typeDataObj -> getBootKernel();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('default', $bootK);
	return;
}

#==========================================
# test_setBootKernelNoArg
#------------------------------------------
sub test_setBootKernelNoArg {
	# ...
	# Test the setBootKernel method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setBootKernel();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootKernel: no boot kernel given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $bootK = $typeDataObj -> getBootKernel();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xenk', $bootK);
	return;
}

#==========================================
# test_setBootLoader
#------------------------------------------
sub test_setBootLoader {
	# ...
	# Test the setBootLoader method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setBootLoader('yaboot');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $bootL = $typeDataObj -> getBootLoader();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('yaboot', $bootL);
	return;
}

#==========================================
# test_setBootLoaderInvalidArg
#------------------------------------------
sub test_setBootLoaderInvalidArg {
	# ...
	# Test the setBootLoader method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setBootLoader('linLoad');
	my $msg = $kiwi -> getMessage();
	my $expected = "setBootLoader: specified bootloader 'linLoad' "
		. 'is not supported.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $loader = $typeDataObj -> getBootLoader();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('grub', $loader);
	return;
}

#==========================================
# test_setBootLoaderNoArg
#------------------------------------------
sub test_setBootLoaderNoArg {
	# ...
	# Test the setBootLoader method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setBootLoader();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootLoader: no bootloader specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $loader = $typeDataObj -> getBootLoader();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('grub', $loader);
	return;
}

#==========================================
# test_setBootPartitionSize
#------------------------------------------
sub test_setBootPartitionSize {
	# ...
	# Test the setBootPartitionSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setBootPartitionSize('1024M');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $size = $typeDataObj -> getBootPartitionSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1024M', $size);
	return;
}

#==========================================
# test_setBootPartitionSizeNoArg
#------------------------------------------
sub test_setBootPartitionSizeNoArg {
	# ...
	# Test the setBootPartitionSize method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setBootPartitionSize();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootPartitionSize: no size given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $size = $typeDataObj -> getBootPartitionSize();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('512M', $size);
	return;
}

#==========================================
# test_setBootProfile
#------------------------------------------
sub test_setBootProfile {
	# ...
	# Test the setBootProfile method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setBootProfile('xen');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $prof = $typeDataObj -> getBootProfile();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xen', $prof);
	return;
}

#==========================================
# test_setBootProfileNoArg
#------------------------------------------
sub test_setBootProfileNoArg {
	# ...
	# Test the setBootProfile method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setBootProfile();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootProfile: no profile given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $prof = $typeDataObj -> getBootProfile();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('std', $prof);
	return;
}

#==========================================
# test_setBootTimeout
#------------------------------------------
sub test_setBootTimeout {
	# ...
	# Test the setBootTimeout method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setBootTimeout('8');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $time = $typeDataObj -> getBootTimeout();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('8', $time);
	return;
}

#==========================================
# test_setBootTimeoutNoArg
#------------------------------------------
sub test_setBootTimeoutNoArg {
	# ...
	# Test the setBootTimeout method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setBootTimeout();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootTimeout: no timeout value given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $time = $typeDataObj -> getBootTimeout();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('5', $time);
	return;
}

#==========================================
# test_setCheckPrebuilt
#------------------------------------------
sub test_setCheckPrebuilt {
	# ...
	# Test the setCheckPrebuilt method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setCheckPrebuilt('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $check = $typeDataObj -> getCheckPrebuilt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $check);
	return;
}

#==========================================
# test_setCheckPrebuiltNoArg
#------------------------------------------
sub test_setCheckPrebuiltNoArg {
	# ...
	# Test the setCheckPrebuilt method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setCheckPrebuilt();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $check = $typeDataObj -> getCheckPrebuilt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $check);
	return;
}

#==========================================
# test_setCheckPrebuiltUnknownArg
#------------------------------------------
sub test_setCheckPrebuiltUnknownArg {
	# ...
	# Test the setCheckPrebuilt method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setCheckPrebuilt('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setCheckPrebuilt: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $check = $typeDataObj -> getCheckPrebuilt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $check);
	return;
}

#==========================================
# test_setCompressed
#------------------------------------------
sub test_setCompressed {
	# ...
	# Test the setCompressed method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setCompressed('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $comp = $typeDataObj -> getCompressed();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $comp);
	return;
}

#==========================================
# test_setCompressedNoArg
#------------------------------------------
sub test_setCompressedNoArg {
	# ...
	# Test the setCompressed method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setCompressed();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $comp = $typeDataObj -> getCompressed();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $comp);
	return;
}

#==========================================
# test_setCompressedUnknownArg
#------------------------------------------
sub test_setCompressedUnknownArg {
	# ...
	# Test the setCompressed method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setCompressed('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setCompressed: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $comp = $typeDataObj -> getCompressed();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $comp);
	return;
}

#==========================================
# test_setDevicePersistent
#------------------------------------------
sub test_setDevicePersistent {
	# ...
	# Test the setDevicePersistent method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setDevicePersistent('by-label');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $devP = $typeDataObj -> getDevicePersistent();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('by-label', $devP);
	return;
}

#==========================================
# test_setDevicePersistentInvalidArg
#------------------------------------------
sub test_setDevicePersistentInvalidArg {
	# ...
	# Test the setDevicePersistent method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setDevicePersistent('unixDev');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDevicePersistent: specified device persistency '
		. "'unixDev' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $devP = $typeDataObj -> getDevicePersistent();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('by-uuid', $devP);
	return;
}

#==========================================
# test_setDevicePersistentNoArg
#------------------------------------------
sub test_setDevicePersistentNoArg {
	# ...
	# Test the setDevicePersistent method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setDevicePersistent();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDevicePersistent: no device persistency specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $devP = $typeDataObj -> getDevicePersistent();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('by-uuid', $devP);
	return;
}

#==========================================
# test_setEditBootConfig
#------------------------------------------
sub test_setEditBootConfig {
	# ...
	# Test the setEditBootConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setEditBootConfig('confScript');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $bootE = $typeDataObj -> getEditBootConfig();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('confScript', $bootE);
	return;
}

#==========================================
# test_setEditBootConfigNoArg
#------------------------------------------
sub test_setEditBootConfigNoArg {
	# ...
	# Test the setEditBootConfig method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setEditBootConfig();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setEditBootConfig: no config script given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $bootE = $typeDataObj -> getEditBootConfig();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myscript', $bootE);
	return;
}

#==========================================
# test_setFilesystem
#------------------------------------------
sub test_setFilesystem {
	# ...
	# Test the setFilesystem method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setFilesystem('ext3');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $fs = $typeDataObj -> getFilesystem();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ext3', $fs);
	return;
}

#==========================================
# test_setFilesystemInvalidArg
#------------------------------------------
sub test_setFilesystemInvalidArg {
	# ...
	# Test the setFilesystem method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFilesystem('ceph');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFilesystem: specified filesystem '
		. "'ceph' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $fs = $typeDataObj -> getFilesystem();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xfs', $fs);
	return;
}

#==========================================
# test_setFilesystemNoArg
#------------------------------------------
sub test_setFilesystemNoArg {
	# ...
	# Test the setFilesystem method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFilesystem();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFilesystem: no filesystem specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $fs = $typeDataObj -> getFilesystem();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xfs', $fs);
	return;
}

#==========================================
# test_setFlags
#------------------------------------------
sub test_setFlags {
	# ...
	# Test the setFlags method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setFlags('clic');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $flags = $typeDataObj -> getFlags();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('clic', $flags);
	return;
}

#==========================================
# test_setFlagsInvalidArg
#------------------------------------------
sub test_setFlagsInvalidArg {
	# ...
	# Test the setFlags method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFlags('gzip');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFlags: specified flags value '
		. "'gzip' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $flags = $typeDataObj -> getFlags();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('compressed', $flags);
	return;
}

#==========================================
# test_setFlagsNoArg
#------------------------------------------
sub test_setFlagsNoArg {
	# ...
	# Test the setFlags method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFlags();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFlags: no flags argument specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $flags = $typeDataObj -> getFlags();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('compressed', $flags);
	return;
}

#==========================================
# test_setFormat
#------------------------------------------
sub test_setFormat {
	# ...
	# Test the setFormat method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setFormat('ec2');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $format = $typeDataObj -> getFormat();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ec2', $format);
	return;
}

#==========================================
# test_setFormatInvalidArg
#------------------------------------------
sub test_setFormatInvalidArg {
	# ...
	# Test the setFormat method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFormat('cow');
	my $msg = $kiwi -> getMessage();
	my $expected = "setFormat: specified format 'cow' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $format = $typeDataObj -> getFormat();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('qcow2', $format);
	return;
}

#==========================================
# test_setFormatNoArg
#------------------------------------------
sub test_setFormatNoArg {
	# ...
	# Test the setFormat method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFormat();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFormat: no format argument specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $format = $typeDataObj -> getFormat();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('qcow2', $format);
	return;
}

#==========================================
# test_setFSMountOptions
#------------------------------------------
sub test_setFSMountOptions {
	# ...
	# Test the setFSMountOptions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setFSMountOptions('journal');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $opts = $typeDataObj -> getFSMountOptions();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('journal', $opts);
	return;
}

#==========================================
# test_setFSMountOptionsNoArg
#------------------------------------------
sub test_setFSMountOptionsNoArg {
	# ...
	# Test the setFSMountOptions method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFSMountOptions();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFSMountOptions: no mount options given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $opts = $typeDataObj -> getFSMountOptions();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('barrier', $opts);
	return;
}

#==========================================
# test_setFSNoCheck
#------------------------------------------
sub test_setFSNoCheck {
	# ...
	# Test the setFSNoCheck method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setFSNoCheck('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $check = $typeDataObj -> getFSNoCheck();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $check);
	return;
}

#==========================================
# test_setFSNoCheckNoArg
#------------------------------------------
sub test_setFSNoCheckNoArg {
	# ...
	# Test the setFSNoCheck method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFSNoCheck();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $check = $typeDataObj -> getFSNoCheck();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $check);
	return;
}

#==========================================
# test_setFSNoCheckUnknownArg
#------------------------------------------
sub test_setFSNoCheckUnknownArg {
	# ...
	# Test the setFSNoCheck method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFSNoCheck('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFSNoCheck: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $check = $typeDataObj -> getFSNoCheck();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $check);
	return;
}

#==========================================
# test_setFSReadOnly
#------------------------------------------
sub test_setFSReadOnly {
	# ...
	# Test the setFSReadOnly method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setFSReadOnly('ext3');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $fs = $typeDataObj -> getFSReadOnly();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ext3', $fs);
	return;
}

#==========================================
# test_setFSReadOnlyInvalidArg
#------------------------------------------
sub test_setFSReadOnlyInvalidArg {
	# ...
	# Test the setFSReadOnly method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFSReadOnly('ceph');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFSReadOnly: specified filesystem '
		. "'ceph' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $fs = $typeDataObj -> getFSReadOnly();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ext3', $fs);
	return;
}

#==========================================
# test_setFSReadOnlyNoArg
#------------------------------------------
sub test_setFSReadOnlyNoArg {
	# ...
	# Test the setFSReadOnly method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFSReadOnly();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFSReadOnly: no filesystem specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $fs = $typeDataObj -> getFSReadOnly();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ext3', $fs);
	return;
}

#==========================================
# test_setFSReadWrite
#------------------------------------------
sub test_setFSReadWrite {
	# ...
	# Test the setFSReadWrite method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setFSReadWrite('ext3');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $fs = $typeDataObj -> getFSReadWrite();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ext3', $fs);
	return;
}

#==========================================
# test_setFSReadWriteInvalidArg
#------------------------------------------
sub test_setFSReadWriteInvalidArg {
	# ...
	# Test the setFSReadWrite method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFSReadWrite('ceph');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFSReadWrite: specified filesystem '
		. "'ceph' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $fs = $typeDataObj -> getFSReadWrite();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xfs', $fs);
	return;
}

#==========================================
# test_setFSReadWriteNoArg
#------------------------------------------
sub test_setFSReadWriteNoArg {
	# ...
	# Test the setFSReadWrite method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setFSReadWrite();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setFSReadWrite: no filesystem specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $fs = $typeDataObj -> getFSReadWrite();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('xfs', $fs);
	return;
}

#==========================================
# test_setHybrid
#------------------------------------------
sub test_setHybrid {
	# ...
	# Test the setHybrid method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setHybrid('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $hybrid = $typeDataObj -> getHybrid();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $hybrid);
	return;
}

#==========================================
# test_setHybridNoArg
#------------------------------------------
sub test_setHybridNoArg {
	# ...
	# Test the setHybrid method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setHybrid();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $hybrid = $typeDataObj -> getHybrid();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $hybrid);
	return;
}

#==========================================
# test_setHybridUnknownArg
#------------------------------------------
sub test_setHybridUnknownArg {
	# ...
	# Test the setHybrid method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setHybrid('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setHybrid: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $hybrid = $typeDataObj -> getHybrid();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $hybrid);
	return;
}

#==========================================
# test_setHybridPersistent
#------------------------------------------
sub test_setHybridPersistent {
	# ...
	# Test the setHybridPersistent method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setHybridPersistent('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $hybrid = $typeDataObj -> getHybridPersistent();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $hybrid);
	return;
}

#==========================================
# test_setHybridPersistentNoArg
#------------------------------------------
sub test_setHybridPersistentNoArg {
	# ...
	# Test the setHybridPersistent method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setHybridPersistent();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $hybrid = $typeDataObj -> getHybridPersistent();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $hybrid);
	return;
}

#==========================================
# test_setHybridPersistentUnknownArg
#------------------------------------------
sub test_setHybridPersistentUnknownArg {
	# ...
	# Test the setHybridPersistent method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setHybridPersistent('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setHybridPersistent: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $hybrid = $typeDataObj -> getHybridPersistent();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $hybrid);
	return;
}

#==========================================
# test_setImageType
#------------------------------------------
sub test_setImageType {
	# ...
	# Test the setImageType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setImageType('tbz');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $type = $typeDataObj -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('tbz', $type);
	return;
}

#==========================================
# test_setImageTypeInvalidArg
#------------------------------------------
sub test_setImageTypeInvalidArg {
	# ...
	# Test the setImageType method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setImageType('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setImageType: specified image '
		. "'foo' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $type = $typeDataObj -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('oem', $type);
	return;
}

#==========================================
# test_setImageTypeNoArg
#------------------------------------------
sub test_setImageTypeNoArg {
	# ...
	# Test the setImageType method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setImageType();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setImageType: no image argument specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $type = $typeDataObj -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('oem', $type);
	return;
}

#==========================================
# test_setInstallBoot
#------------------------------------------
sub test_setInstallBoot {
	# ...
	# Test the setInstallBoot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setInstallBoot('failsafe-install');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $opt = $typeDataObj -> getInstallBoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('failsafe-install', $opt);
	return;
}

#==========================================
# test_setInstallBootInvalidArg
#------------------------------------------
sub test_setInstallBootInvalidArg {
	# ...
	# Test the setInstallBoot method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallBoot('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setInstallBoot: specified installboot option '
		. "'foo' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $opt = $typeDataObj -> getInstallBoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('install', $opt);
	return;
}

#==========================================
# test_setInstallBootNoArg
#------------------------------------------
sub test_setInstallBootNoArg {
	# ...
	# Test the setInstallBoot method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallBoot();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setInstallBoot: no installboot argument specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $opt = $typeDataObj -> getInstallBoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('install', $opt);
	return;
}

#==========================================
# test_setInstallFailsafe
#------------------------------------------
sub test_setInstallFailsafe {
	# ...
	# Test the setInstallFailsafe method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setInstallFailsafe('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $failS = $typeDataObj -> getInstallFailsafe();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $failS);
	return;
}

#==========================================
# test_setInstallFailsafeNoArg
#------------------------------------------
sub test_setInstallFailsafeNoArg {
	# ...
	# Test the setInstallFailsafe method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallFailsafe();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $failS = $typeDataObj -> getInstallFailsafe();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $failS);
	return;
}

#==========================================
# test_setInstallFailsafeUnknownArg
#------------------------------------------
sub test_setInstallFailsafeUnknownArg {
	# ...
	# Test the setInstallFailsafe method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallFailsafe('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setInstallFailsafe: unrecognized argument expecting '
		. '"true" or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $failS = $typeDataObj -> getInstallFailsafe();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $failS);
	return;
}

#==========================================
# test_setInstallIso
#------------------------------------------
sub test_setInstallIso {
	# ...
	# Test the setInstallIso method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setInstallIso('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $iso = $typeDataObj -> getInstallIso();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $iso);
	return;
}

#==========================================
# test_setInstallIsoNoArg
#------------------------------------------
sub test_setInstallIsoNoArg {
	# ...
	# Test the setInstallIso method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallIso();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $iso = $typeDataObj -> getInstallIso();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $iso);
	return;
}

#==========================================
# test_setInstallIsoUnknownArg
#------------------------------------------
sub test_setInstallIsoUnknownArg {
	# ...
	# Test the setInstallIso method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallIso('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setInstallIso: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $iso = $typeDataObj -> getInstallIso();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $iso);
	return;
}

#==========================================
# test_setInstallStick
#------------------------------------------
sub test_setInstallStick {
	# ...
	# Test the setInstallStick method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setInstallStick('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $stick = $typeDataObj -> getInstallStick();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $stick);
	return;
}

#==========================================
# test_setInstallStickNoArg
#------------------------------------------
sub test_setInstallStickNoArg {
	# ...
	# Test the setInstallStick method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallStick();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $stick = $typeDataObj -> getInstallStick();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $stick);
	return;
}

#==========================================
# test_setInstallStickUnknownArg
#------------------------------------------
sub test_setInstallStickUnknownArg {
	# ...
	# Test the setInstallStick method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setInstallStick('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setInstallStick: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $stick = $typeDataObj -> getInstallStick();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $stick);
	return;
}

#==========================================
# test_setKernelCmdOpts
#------------------------------------------
sub test_setKernelCmdOpts {
	# ...
	# Test the setKernelCmdOpts method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setKernelCmdOpts('init=/bin/sh');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $opt = $typeDataObj -> getKernelCmdOpts();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('init=/bin/sh', $opt);
	return;
}

#==========================================
# test_setKernelCmdOptsNoArg
#------------------------------------------
sub test_setKernelCmdOptsNoArg {
	# ...
	# Test the setKernelCmdOpts method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setKernelCmdOpts();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setKernelCmdOpts: no options given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $opt = $typeDataObj -> getKernelCmdOpts();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('kiwidebug=1', $opt);
	return;
}

#==========================================
# test_setLucksPass
#------------------------------------------
sub test_setLucksPass {
	# ...
	# Test the setLucksPass method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setLucksPass('mySecret');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $pass = $typeDataObj -> getLucksPass();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('mySecret', $pass);
	return;
}

#==========================================
# test_setLucksPassNoArg
#------------------------------------------
sub test_setLucksPassNoArg {
	# ...
	# Test the setLucksPass method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setLucksPass();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setLucksPass: no password given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $pass = $typeDataObj -> getLucksPass();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('notApass', $pass);
	return;
}

#==========================================
# test_setPrimary
#------------------------------------------
sub test_setPrimary {
	# ...
	# Test the setPrimary method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setPrimary('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $prim = $typeDataObj -> getPrimary();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $prim);
	return;
}

#==========================================
# test_setPrimaryNoArg
#------------------------------------------
sub test_setPrimaryNoArg {
	# ...
	# Test the setPrimary method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setPrimary();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $prim = $typeDataObj -> getPrimary();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $prim);
	return;
}

#==========================================
# test_setPrimaryUnknownArg
#------------------------------------------
sub test_setPrimaryUnknownArg {
	# ...
	# Test the setPrimary method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setPrimary('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPrimary: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $prim = $typeDataObj -> getPrimary();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $prim);
	return;
}

#==========================================
# test_setRAMOnly
#------------------------------------------
sub test_setRAMOnly {
	# ...
	# Test the setRAMOnly method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setRAMOnly('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $ramO = $typeDataObj -> getRAMOnly();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $ramO);
	return;
}

#==========================================
# test_setRAMOnlyNoArg
#------------------------------------------
sub test_setRAMOnlyNoArg {
	# ...
	# Test the setRAMOnly method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setRAMOnly();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $ramO = $typeDataObj -> getRAMOnly();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $ramO);
	return;
}

#==========================================
# test_setRAMOnlyUnknownArg
#------------------------------------------
sub test_setRAMOnlyUnknownArg {
	# ...
	# Test the setRAMOnly method with an unrecognized argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setRAMOnly('5');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setRAMOnly: unrecognized argument expecting "true" '
		. 'or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $ramO = $typeDataObj -> getRAMOnly();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $ramO);
	return;
}

#==========================================
# test_setVGA
#------------------------------------------
sub test_setVGA {
	# ...
	# Test the setVGA method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setVGA('0x348');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $vga = $typeDataObj -> getVGA();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('0x348', $vga);
	return;
}

#==========================================
# test_setVGANoArg
#------------------------------------------
sub test_setVGANoArg {
	# ...
	# Test the setVGA method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setVGA();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setVGA: no VGA value given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $vga = $typeDataObj -> getVGA();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('0x344', $vga);
	return;
}

#==========================================
# test_setVolID
#------------------------------------------
sub test_setVolID {
	# ...
	# Test the setVolID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi);
	$typeDataObj = $typeDataObj -> setVolID('myDist');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($typeDataObj);
	my $volID = $typeDataObj -> getVolID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myDist', $volID);
	return;
}

#==========================================
# test_setVolIDNoArg
#------------------------------------------
sub test_setVolIDNoArg {
	# ...
	# Test the setVolID method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $typeDataObj = $this -> __getTypeObj();
	my $res = $typeDataObj -> setVolID();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setVolID: no volume ID given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $volID = $typeDataObj -> getVolID();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myImg', $volID);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getTypeObj
#------------------------------------------
sub __getTypeObj {
	# ...
	# Helper to construct a fully populated Type object using
	# initialization, the seetings in combination do not really make sense.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = ( boot                   => '/oem/suse-12.2',
				bootkernel             => 'xenk',
				bootloader             => 'grub',
				bootpartsize           => '512M',
				bootprofile            => 'std',
				boottimeout            => '5',
				checkprebuilt          => 'true',
				compressed             => 'true',
				devicepersistency      => 'by-uuid',
				editbootconfig         => 'myscript',
				filesystem             => 'xfs',
				flags                  => 'compressed',
				format                 => 'qcow2',
				fsmountoptions         => 'barrier',
				fsnocheck              => 'true',
				fsreadonly             => 'ext3',
				fsreadwrite            => 'xfs',
				hybrid                 => 'true',
				hybridpersistent       => 'true',
				image                  => 'oem',
				installboot            => 'install',
				installiso             => 'true',
				installprovidefailsafe => 'true',
				installstick           => 'true',
				kernelcmdline          => 'kiwidebug=1',
				luks                   => 'notApass',
				primary                => 'true',
				ramonly                => 'true',
				vga                    => '0x344',
				volid                  => 'myImg'
			);
	my $typeDataObj = KIWIXMLTypeData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($typeDataObj);
	return $typeDataObj;
}

1;
