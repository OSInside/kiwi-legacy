#================
# FILE          : kiwiRuntimeChecker.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIRuntimeChecker module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiRuntimeChecker;

use strict;
use warnings;

use Readonly;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIGlobals;
use KIWILocator;
use KIWIRuntimeChecker;
use KIWIXML;

#==========================================
# constants
#------------------------------------------
Readonly my $MEGABYTE => 1048576;

if ($< != 0) {
	# /.../
	# stub the runtime check for the LSB root ownership if
	# unit tests are called as normal user
	# ----
	no warnings; ## no critic
	sub KIWIRuntimeChecker::__checkCorrectRootFSPermissons {
		return 1;
	}
}

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {dataDir} = $this -> getDataDir() . '/kiwiRuntimeChecker';
	$this -> {cmdL} = KIWICommandLine -> new();

	return $this;
}

#==========================================
# test_ctor_noArg1
#------------------------------------------
sub test_ctor_noArg1 {
	# ...
	# Test the runtime checker constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test missing second argument
	my $checker = KIWIRuntimeChecker -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting reference to KIWICommandLine object as '
		. 'argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($checker);
	return;
}

#==========================================
# test_ctor_noArg2
#------------------------------------------
sub test_ctor_noArg2 {
	# ...
	# Test the runtime checker constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test missing third argument
	my $cmd = $this -> __getCommandLineObj();
	my $checker = KIWIRuntimeChecker -> new($cmd);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting reference to KIWIXML object as second argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($checker);
	return;
}

#==========================================
# test_ctor_valid
#------------------------------------------
sub test_ctor_valid {
	# ...
	# Test the runtime checker constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# No error construction
	my $cmd = $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj( $this -> {dataDir} );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($checker);
	return;
}

#==========================================
# test_buildProfWithDefPackages
#------------------------------------------
sub test_buildProfWithDefPackages {
	# ...
	# Test that using specified build profiles with configuration that has
	# default packages does not trigger an error
	# in the runtime checker.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @profiles = ('my-first','my-second');
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/haveDefaultPkgs';
	$cmd -> setConfigDir ($configDir);
	$cmd -> setBuildProfiles(\@profiles);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $expected = 'Set profiles to command line provided profiles for '
		. "validation.\nUsing profile(s): my-first, my-secondReset profiles "
		. "to original values.\n";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_conflictingProfiles
#------------------------------------------
sub test_conflictingProfiles {
	# ...
	# Test that conflicting values of the patternType attribute
	# are properly detected at runtime.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @profiles = ('my-first','my-second');
	my $cmd = $this -> __getCommandLineObj();
	$cmd -> setBuildProfiles(\@profiles);
	my $xml = $this -> __getXMLObj( $this -> {dataDir} );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $infoMsg = $kiwi -> getInfoMessage();
	my $expected = 'Set profiles to command line provided profiles for '
		. "validation.\nUsing profile(s): my-first, my-secondReset profiles to original values.\n";
	$this -> assert_str_equals($expected, $infoMsg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	return;
}

#==========================================
# test_conflictingUsers
#------------------------------------------
sub test_conflictingUsers {
	# ...
	# Test that user definitions that conflict generate an error
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my @bldProfs = ('profA', 'profB');
	my $configDir = $this -> {dataDir} . '/conflictUsers';
	my $res = $cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	$xml -> setSelectionProfileNames( \@bldProfs );
	# Clear the log
	my $state = $kiwi -> getState();
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	$res = $checker -> prepareChecks();
	my $iMsg = $kiwi -> getInfoMessage();
	my $iExpect = "Merging data for user 'auser'";
	$this -> assert_str_equals($iExpect, $iMsg);
	my $msg = $kiwi -> getMessage();
	my $expected = 'User merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	return;
}

#==========================================
# test_containerPackMissing
#------------------------------------------
sub test_containerPackMissing {
	# ...
	# Test that a missing lxc package for a container build generates an
	# error
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/lxcMissing';
	my $res = $cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	$res = $checker -> createChecks();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Attempting to build container, but no lxc package '
		. 'included in image.';
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
# test_duplicateRepoAliasConflict
#------------------------------------------
sub test_duplicateRepoAliasConflict {
	# ...
	# Test that duplicate repo alias names trigger an error
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/noRepoAliasUnique';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my @profiles = ('profA');
	$xml -> setSelectionProfileNames( \@profiles );
	my $msg = $kiwi -> getMessage();
	my $msgT = $kiwi -> getMessageType();
	my $state = $kiwi -> getState();
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	$msg = $kiwi -> getMessage();
	my $expected = "Specified repo alias 'arepo' not unique across "
		. 'active repositories';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	return;
}

#==========================================
# test_duplicateRepoAliasNoConflict
#------------------------------------------
sub test_duplicateRepoAliasNoConflict {
	# ...
	# Test that duplicate repo alias names do not trigger an error if the
	# conflicting repos are not used at the same time
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/noRepoAliasUnique';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_fsToolCheckFsysImg
#------------------------------------------
sub test_fsToolCheckFsysImg {
	# ...
	# Test the verification of the *fs tool presence verification.
	# Do not know how to hide the tool from within the test, thus certain
	# conditions of the test are only exercised on systems where the
	# tool is not present.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $dataBaseDir = $this -> {dataDir} . '/fileSysImg/';
	my @fsTestDirs = glob "$dataBaseDir/*";
	for my $fsTestName (@fsTestDirs) {
		my $xml = $this -> __getXMLObj($fsTestName);
		my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
		my $res = $checker -> createChecks();
		my $eMsg = $kiwi -> getErrorMessage();
		if ($eMsg) {
			# File system tool is not present
			my $fsTool;
			if ($fsTestName =~ 'btrfs' ) {
				$fsTool = 'mkfs.btrfs'
			} elsif ($fsTestName =~ 'ext2' ) {
				$fsTool = 'mkfs.ext2';
			} elsif ($fsTestName =~ 'ext3' ) {
				$fsTool = 'mkfs.ext3';
			} elsif ($fsTestName =~ 'ext4' ) {
				$fsTool = 'mkfs.ext4';
			} elsif ($fsTestName =~ 'reiserfs' ) {
				$fsTool = 'mkreiserfs';
			} elsif ($fsTestName =~ 'xfs' ) {
				$fsTool = 'mkfs.xfs';
			}
			my $logMsg = $kiwi -> getLogInfoMessage();
			my $expected = "warning: $fsTool not found\n";
			$this -> assert_str_equals($expected, $logMsg);
			my @prts = split /\//, $fsTestName;
			my $fsExpected = $prts[-1];
			$expected = 'Requested image creation with filesystem "'
			. $fsExpected
			. '"; but tool to create the file system could not '
			. 'be found.';
			$this -> assert_str_equals($expected, $eMsg);
			my $msgT = $kiwi -> getMessageType();
			$this -> assert_str_equals('error', $msgT);
			my $state = $kiwi -> getState();
			$this -> assert_str_equals('failed', $state);
			# Test this condition last to get potential error messages
			$this -> assert_null($res);
		} else {
			# Filesystem tool is present
			my $msg = $kiwi -> getMessage();
			$this -> assert_str_equals('No messages set', $msg);
			my $msgT = $kiwi -> getMessageType();
			$this -> assert_str_equals('none', $msgT);
			my $state = $kiwi -> getState();
			$this -> assert_str_equals('No state set', $state);
			# Test this condition last to get potential error messages
			$this -> assert_not_null($res);
		}
	}
	return;
}

#==========================================
# test_fsToolCheckIsoImg
#------------------------------------------
sub test_fsToolCheckIsoImg {
	# ...
	# Test the verification of the *fs tool presence verification.
	# Do not know how to hide the tool from within the test, thus certain
	# conditions of the test are only exercised on systems where the
	# tool is not present.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $dataBaseDir = $this -> {dataDir} . '/liveIsoImg';
	my @fsTestDirs = glob "$dataBaseDir/*";
	for my $fsTestName (@fsTestDirs) {
		if ($fsTestName =~ 'efi') {
			next;
		}
		my $xml = $this -> __getXMLObj($fsTestName);
		my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
		my $res = $checker -> createChecks();
		my $eMsg = $kiwi -> getErrorMessage();
		if ($eMsg) {
			# File system tool is not present
			my $fsTool;
			my $fsExpected;
			if ($fsTestName =~ 'clic') {
				$fsExpected = 'clicfs';
				$fsTool = 'mkclicfs';
			} elsif ($fsTestName =~ 'compressed') {
				$fsExpected = 'squashfs';
				$fsTool = 'mksquashfs';
			}
			my $logMsg = $kiwi -> getLogInfoMessage();
			my $expected = "warning: $fsTool not found\n";
			$this -> assert_str_equals($expected, $logMsg);
			$expected = 'Requested image creation with filesystem "'
			. $fsExpected
			. '"; but tool to create the file system could not '
			. 'be found.';
			$this -> assert_str_equals($expected, $eMsg);
			my $msgT = $kiwi -> getMessageType();
			$this -> assert_str_equals('error', $msgT);
			my $state = $kiwi -> getState();
			$this -> assert_str_equals('failed', $state);
			# Test this condition last to get potential error messages
			$this -> assert_null($res);
		} else {
			# Filesystem tools is present
			my $msg = $kiwi -> getMessage();
			$this -> assert_str_equals('No messages set', $msg);
			my $msgT = $kiwi -> getMessageType();
			$this -> assert_str_equals('none', $msgT);
			my $state = $kiwi -> getState();
			$this -> assert_str_equals('No state set', $state);
			# Test this condition last to get potential error messages
			$this -> assert_not_null($res);
		}
	}
	return;
}

#==========================================
# test_fsToolCheckOemBtrfs
#------------------------------------------
sub test_fsToolCheckOemBtrfs {
	# ...
	# Test the verification of the *fs tool presence verification.
	# Do not know how to hide the tool from within the test, thus certain
	# conditions of the test are only exercised on systems where the
	# tool is not present.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configPath = $this -> {dataDir} . '/oemBtrfs';
	my $xml = $this -> __getXMLObj($configPath);
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	my $eMsg = $kiwi -> getErrorMessage();
	if ($eMsg) {
		# File system tool is not present
		my $logMsg = $kiwi -> getLogInfoMessage();
		my $expected = "warning: mkfs.btrfs not found\n";
		$this -> assert_str_equals($expected, $logMsg);
		$expected = 'Requested image creation with filesystem "btrfs"; '
		. 'but tool to create the file system could not '
		. 'be found.';
		$this -> assert_str_equals($expected, $eMsg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('error', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('failed', $state);
		# Test this condition last to get potential error messages
		$this -> assert_null($res);
	} else {
		# Filesystem tools is present
		my $msg = $kiwi -> getMessage();
		$this -> assert_str_equals('No messages set', $msg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('none', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('No state set', $state);
		# Test this condition last to get potential error messages
		$this -> assert_not_null($res);
	}
	return;
}

#==========================================
# test_fsToolCheckSplitImg
#------------------------------------------
sub test_fsToolCheckSplitImg {
	# ...
	# Test the verification of the *fs tool presence verification.
	# Do not know how to hide the tool from within the test, thus certain
	# conditions of the test are only exercised on systems where the
	# tool is not present.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configPath = $this -> {dataDir} . '/splitImg';
	my $xml = $this -> __getXMLObj($configPath);
	my $locator = KIWILocator -> instance();
	my $haveBtrfs = $locator -> getExecPath('mkfs.btrfs');
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	if ($haveBtrfs) {
		# Filesystem tool is present
		my $msg = $kiwi -> getMessage();
		$this -> assert_str_equals('No messages set', $msg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('none', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('No state set', $state);
		# Test this condition last to get potential error messages
		$this -> assert_not_null($res);
	} else {
		# File system tool is not present
		my $logMsg = $kiwi -> getLogInfoMessage();
		my $expected = "warning: mkfs.btrfs not found\n";
		$this -> assert_str_equals($expected, $logMsg);
		my $eMsg = $kiwi -> getErrorMessage();
		$expected = 'Requested image creation with filesystem "btrfs"; '
		. 'but tool to create the file system could not '
		. 'be found.';
		$this -> assert_str_equals($expected, $eMsg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('error', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('failed', $state);
		# Test this condition last to get potential error messages
		$this -> assert_null($res);
	}
	return;
}

#==========================================
# test_isohybrid
#------------------------------------------
sub test_isohybrid {
	# ...
	# Test that trying to build a hybrid ISO for EFI firmware does trigger an
	# error if the tool does not support the option. Also test that trying
	# to build an isohybrid on non x86 and x86_64 architectures triggers
	# an error.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = KIWILocator -> instance();
	my $arch = KIWIGlobals -> instance() -> getArch();
	my $isoHybrid;
	if ($arch eq 'i686' || $arch eq 'i586' || $arch eq 'x86_64') {
		$isoHybrid = $locator -> getExecPath('isohybrid');
		if (! $isoHybrid) {
			print "\t\tCould not find isohybrid executable skipping test "
			. "test_noEFIIsohybrid\n";
			return;
		}
	}
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/liveIsoImg/efi';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	my $msg = $kiwi -> getMessage();
	my $msgT = $kiwi -> getMessageType();
	my $state = $kiwi -> getState();
	if ($arch eq 'i686' || $arch eq 'i586' || $arch eq 'x86_64') {
		my @opt = ('uefi');
		my %cmdOpt = %{$locator -> getExecArgsFormat ($isoHybrid, \@opt)};
		if ($cmdOpt{'status'}) {
			# isohybrid has -uefi option
			$this -> assert_str_equals('No messages set', $msg);
			$this -> assert_str_equals('none', $msgT);
			$this -> assert_str_equals('No state set', $state);
			# Test this condition last to get potential error messages
			$this -> assert_not_null($res);
		} else {
			my $expected = 'Attempting to build EFI capable hybrid ISO '
				. 'image, but installed isohybrid binary does not support '
				. 'this option.';
			$this -> assert_str_equals($expected, $msg);
			$this -> assert_str_equals('error', $msgT);
			$this -> assert_str_equals('failed', $state);
			# Test this condition last to get potential error messages
			$this -> assert_null($res);
		}
	} else {
		my $expected = 'Attempting to create hybrid ISO image on a platform '
			. 'that does not support hybrid ISO creation.';
		$this -> assert_str_equals($expected, $msg);
		$this -> assert_str_equals('error', $msgT);
		$this -> assert_str_equals('failed', $state);
		# Test this condition last to get potential error messages
		$this -> assert_null($res);
	}
	return;
}

#==========================================
# test_lvmOEMSizeSetings
#------------------------------------------
sub test_lvmOEMSizeSetings {
	# ...
	# Test that a system size that is smaller than the addition of LVM
	# volume sizes causes an error.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/lvmGreaterSysSize';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Specified system size is smaller than requested '
		. 'volume sizes';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_lvmOEMSizeSetingsValid
#------------------------------------------
sub test_lvmOEMSizeSetingsValid {
	# ...
	# Test that a system size that is smaller than the addition of LVM
	# volume sizes causes an error.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/lvmAndSwapGreaterSysSize';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_noBuildProfile
#------------------------------------------
sub test_noBuildProfile {
	# ...
	# Test that using no build profile does not trigger an error
	# in the runtime checker.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/liveIsoImg/clic';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_noBuildType
#------------------------------------------
sub test_noBuildType {
	# ...
	# Test that an error is triggered if Kiwi cannot determine the build type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/noDefaultBuildType';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Cannot determine build type', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	return;
}

#==========================================
# test_noEFIIsohybridOEMImg
#------------------------------------------
sub test_noEFIIsohybridOEMImg {
	# ...
	# Test that trying to build a hybrid ISO for EFI firmware does trigger an
	# error if the tool does not support the option. Also test that trying
	# to build an isohybrid on non x86 and x86_64 architectures triggers
	# an error.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $locator = KIWILocator -> instance();
	my $arch = KIWIGlobals -> instance() -> getArch();
	my $isoHybrid;
	if ($arch eq 'i686' || $arch eq 'i586' || $arch eq 'x86_64') {
		$isoHybrid = $locator -> getExecPath('isohybrid');
		if (! $isoHybrid) {
			print "\t\tCould not find isohybrid executable skipping test "
			. "test_noEFIIsohybrid\n";
			return;
		}
	}
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/liveIsoImg/efiOEM';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	my $msg = $kiwi -> getMessage();
	my $msgT = $kiwi -> getMessageType();
	my $state = $kiwi -> getState();
	if ($arch eq 'i686' || $arch eq 'i586' || $arch eq 'x86_64') {
		my @opt = ('uefi');
		my %cmdOpt = %{$locator -> getExecArgsFormat ($isoHybrid, \@opt)};
		if ($cmdOpt{'status'}) {
			# isohybrid has -uefi option
			$this -> assert_str_equals('No messages set', $msg);
			$this -> assert_str_equals('none', $msgT);
			$this -> assert_str_equals('No state set', $state);
			# Test this condition last to get potential error messages
			$this -> assert_not_null($res);
		} else {
			my $expected = 'Attempting to build EFI capable hybrid ISO '
				. 'image, but installed isohybrid binary does not support '
				. 'this option.';
			$this -> assert_str_equals($expected, $msg);
			$this -> assert_str_equals('error', $msgT);
			$this -> assert_str_equals('failed', $state);
			# Test this condition last to get potential error messages
			$this -> assert_null($res);
		}
	} else {
		my $expected = 'Attempting to create hybrid ISO image on a platform '
			. 'that does not support hybrid ISO creation.';
		$this -> assert_str_equals($expected, $msg);
		$this -> assert_str_equals('error', $msgT);
		$this -> assert_str_equals('failed', $state);
		# Test this condition last to get potential error messages
		$this -> assert_null($res);
	}
	return;
}

#==========================================
# test_oemSizeSettingSufficient
#------------------------------------------
sub test_oemSizeSettingSufficient {
	# ...
	# Test that a insufficiently large system size causes an error
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $configDir = $this -> {dataDir} . '/minSysSize';
	my $xml = $this -> __getXMLObj( $configDir );
	my $cmd = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	my $status = open my $TESTFILE, '>', $tmpDir . '/out.txt';
	$this -> assert_not_null($status);
	my $cnt = 0;
	while ($cnt < $MEGABYTE + 1) {
		print $TESTFILE "a\n";
		$cnt += 1;
	}
	$status = close $TESTFILE;
	$this -> assert_not_null($status);
	$cmd -> setConfigDir ($tmpDir);
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	my $msg = $kiwi -> getMessage();
	my $expected = 'System requires 2 MB, but size '
		. 'constraint set to 1 MB';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_packageManagerCheck_ens
#------------------------------------------
sub test_packageManagerCheck_ens {
	# ...
	# Test that the runtime check for package manager tool existence behaves
	# properly.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/liveIsoImg/clic';
	$cmd -> setConfigDir ($configDir);
	# Select manager least likely to be present we want this part of
	# the test to simulate a failure condition
	$cmd -> setPackageManager('ensconce');
	my $xml = $this -> __getXMLObj( $configDir );
	my $prefObj = $xml -> getPreferences();
	$prefObj -> setPackageManager('ensconce');
	$xml -> setPreferences($prefObj);
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $locator = KIWILocator -> instance();
	my $haveEnsconce = $locator -> getExecPath('ensconce');
	if ($haveEnsconce) {
		my $msg = $kiwi -> getMessage();
		$this -> assert_str_equals('No messages set', $msg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('none', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('No state set', $state);
		$this -> assert_not_null($res);
		my $infoMsg = 'Found ensconce package manager, not hitting the '
			. "anticipated failure condition. This is NOT an error.\n";
		print STDOUT $infoMsg;
	} else {
		my $logInf = $kiwi -> getLogInfoMessage();
		$this -> assert_str_equals("warning: ensconce not found\n", $logInf);
		my $errMsg = $kiwi -> getErrorMessage();
		my $expected = 'Executable for specified package manager, ensconce, '
			. 'could not be found.';
		$this -> assert_str_equals($expected, $errMsg);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('failed', $state);
		$this -> assert_null($res);
	}
	return;
}

#==========================================
# test_packageManagerCheck_zypp
#------------------------------------------
sub test_packageManagerCheck_zypp {
	# ...
	# Test that the runtime check for package manager tool existence behaves
	# properly.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/liveIsoImg/clic';
	$cmd -> setConfigDir ($configDir);
	# Test the most likely use case, zypper set as package manager in
	# config.xml, this test should succeed
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();

	my $locator = KIWILocator -> instance();
	my $haveZypper = $locator -> getExecPath('zypper');
	if ($haveZypper) {
		my $msg = $kiwi -> getMessage();
		$this -> assert_str_equals('No messages set', $msg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('none', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('No state set', $state);
		$this -> assert_not_null($res);

	} else {
		my $logInf = $kiwi -> getLogInfoMessage();
		$this -> assert_str_equals("warning: zypper not found\n", $logInf);
		my $errMsg = $kiwi -> getErrorMessage();
		my $failExpect = 'Executable for specified package manager, zypper, '
			. 'could not be found.';
		$this -> assert_str_equals($failExpect, $errMsg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('error', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('failed', $state);
		$this -> assert_null($res);
		my $infoMsg = 'Did not find zypper package manager, not hitting the '
			. "anticipated success condition. This is NOT an error.\n";
		print STDOUT $infoMsg;
	}
	return;
}

#==========================================
# test_systemDiskDataNoVolume
#------------------------------------------
sub test_systemDiskDataNoVolume {
	# ...
	# Test that an error is generated if the specified volume does not
	# exist as a directory in the unpacked image tree
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/lvmSetup2';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $tmpDir = $this -> createTestTmpDir();
	$cmd -> setConfigDir ($tmpDir);
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Volume path home does not exist in unpacked tree';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_systemDiskDataSizeTooSmall
#------------------------------------------
sub test_systemDiskDataSizeTooSmall {
	# ...
	# Test that an insufficient system size generates an error
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/lvmSetup2';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $tmpDir = $this -> createTestTmpDir();
	$cmd -> setConfigDir ($tmpDir);
	mkdir $tmpDir . '/home';
	mkdir $tmpDir . '/usr';
	mkdir $tmpDir . '/var';
	my $status = open my $TESTFILE, '>', $tmpDir . '/home/out.txt';
	$this -> assert_not_null($status);
	my $cnt = 0;
	while ($cnt < 2*($MEGABYTE + 1)) {
		print $TESTFILE "a\n";
		$cnt += 1;
	}
	$status = close $TESTFILE;
	$this -> assert_not_null($status);
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Calculated 1 MB free, but require 3 MB';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_systemDiskDataVolTooSmall
#------------------------------------------
sub test_systemDiskDataVolTooSmall {
	# ...
	# Test that an insufficient volume size generates an error
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/lvmSetup2';
	$cmd -> setConfigDir ($configDir);
	my $xml = $this -> __getXMLObj( $configDir );
	my $tmpDir = $this -> createTestTmpDir();
	$cmd -> setConfigDir ($tmpDir);
	mkdir $tmpDir . '/home';
	mkdir $tmpDir . '/usr';
	mkdir $tmpDir . '/var';
	my $status = open my $TESTFILE, '>', $tmpDir . '/var/out.txt';
	$this -> assert_not_null($status);
	my $cnt = 0;
	while ($cnt < $MEGABYTE + 1) {
		print $TESTFILE "a\n";
		$cnt += 1;
	}
	$status = close $TESTFILE;
	$this -> assert_not_null($status);
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> createChecks();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Required size for var [ 2 MB ] is larger than specified size [ 1 ] MB';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_useSingleBuildProfile
#------------------------------------------
sub test_useSingleBuildProfile {
	# ...
	# Test that using a single build profile does not trigger an error
	# in the runtime checker.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @profiles = ('my-first');
	my $cmd = $this -> __getCommandLineObj();
	my $configDir = $this -> {dataDir} . '/liveIsoImg/clic';
	$cmd -> setConfigDir ($configDir);
	$cmd -> setBuildProfiles(\@profiles);
	my $xml = $this -> __getXMLObj( $configDir );
	my $checker = KIWIRuntimeChecker -> new($cmd, $xml);
	my $res = $checker -> prepareChecks();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
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
	# Create a command line object
	# ---
	my $this = shift;
	return KIWICommandLine -> new();
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
	my $kiwi = $this->{kiwi};
	# TODO
	# Fix the creation of the XML object once the ctor arguments change
	my $xml = KIWIXML -> new(
		$configDir, undef, undef, $this->{cmdL}
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
