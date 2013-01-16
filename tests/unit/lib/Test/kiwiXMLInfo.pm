#================
# FILE          : kiwiXMLInfo.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLInfo module.
#               : Certain queries require root priveleges, thus these queries
#               : only get tested when this test is executed as root.
#               :     -- packages
#               :     -- patterns       (TBI)
#               :     -- repo-patterns  (TBI)
#               :     -- size
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLInfo;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIXMLInfo;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	my $baseDir = $this -> getDataDir() . '/kiwiXMLInfo/';
	$this -> {baseDir} = $baseDir;
	$this -> {kiwi}    = Common::ktLog -> new();

	return $this;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the XMLInfo object constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmdL = KIWICommandLine -> new($kiwi);
	# No argument for CommandLine object
	my $info = KIWIXMLInfo -> new($kiwi, $cmdL);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Invalid KIWICommandLine object, no configuration '
		. 'directory.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($info);
	return;
}

#==========================================
# test_ctor_missArg
#------------------------------------------
sub test_ctor_missArg {
	# ...
	# Test the XMLInfo object constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# No argument for CommandLine object
	my $info = KIWIXMLInfo -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLInfo: expecting KIWICommandLine object as '
		. 'second argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($info);
	return;
}

#==========================================
# test_ArchiveInfo
#------------------------------------------
sub test_ArchiveInfo {
	# ...
	# Test to ensure we get the proper archive information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	my @requests = ('archives');
	my $tree = $info -> getXMLInfoTree(\@requests);
	my $expectedMsg = '<imagescan description="'
		. $cmd->getConfigDir()
		. '">'
		. '<archive name="testArchive.tgz"/>'
		. '</imagescan>';
	$this -> assert_not_null($tree);
	$this -> assert_str_equals($expectedMsg, $tree -> toString());
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_getTree_improperArg
#------------------------------------------
sub test_getTree_improperArg {
	# ...
	# Test getting a tree
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	# Supply improper argument
	my @invalidOpts = ('ola');
	my $res = $info -> getXMLInfoTree(@invalidOpts);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Expecting ARRAY_REF as first argument for info '
		. 'requests.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_getTree_invalidReq
#------------------------------------------
sub test_getTree_invalidReq {
	# ...
	# Test getting a tree
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	# Supply improper argument
	my @invalidOpts = ('ola');
	my $res = $info -> getXMLInfoTree(\@invalidOpts);
	my $expectedMsg = 'Requested information option ola not supported, '
		. 'ignoring.';
	my $warnMsg = $kiwi -> getWarningMessage();
	$this -> assert_str_equals($expectedMsg, $warnMsg);
	my $state = $kiwi -> getWarningState();
	$this -> assert_equals('skipped', $state);
	my $errMsg = $kiwi -> getErrorMessage();
	$expectedMsg = 'None of the specified information options are available.';
	$this -> assert_str_equals($expectedMsg, $errMsg);
	my $msg = $kiwi -> getMessage();
	$expectedMsg = "Choose between the following:\n"
		. "--> archives       :List of tar archives to be installed\n"
		. "--> overlay-files  :List of files in root overlay\n"
		. "--> packages       :List of packages to be installed\n"
		. "--> patterns       :List configured patterns\n"
		. "--> profiles       :List profiles\n"
		. "--> repo-patterns  :List available patterns from repos\n"
		. "--> size           :List install/delete size estimation\n"
		. "--> sources        :List configured source URLs\n"
		. "--> types          :List configured types\n"
		. "--> version        :List name and version\n";
	$this -> assert_str_equals($expectedMsg, $msg);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_getTree_noArg
#------------------------------------------
sub test_getTree_noArg {
	# ...
	# Test getting a tree
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	# Do not supply an argument
	my $res = $info -> getXMLInfoTree();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'No information requested, nothing todo.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_packagesInfo
#------------------------------------------
sub test_packagesInfo {
	# ...
	# Test to ensure we get the proper package information
	# skip test if not root
	# ---
	if ($< != 0) {
		print "\t\tInfo: Not root, skipping test_packagesInfo\n";
		return;
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Avoid chain failures
	$this -> removeTestTmpDir();
	# Setup directory to operate as repository
	my $repoParentDir = $this -> createTestTmpDir();
	my $repoOrig = $this -> getDataDir();
	system "cp -r $repoOrig/kiwiTestRepo $repoParentDir";
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	# Replace the repo from the config file with the previously setup repo
	$cmd -> setReplacementRepo($repoParentDir . '/kiwiTestRepo', 'testRepo',
							1, 'rpm-md');
	my $info = $this -> __getInfoObj($cmd);
	my @requests = ('packages');
	my $tree = $info -> getXMLInfoTree(\@requests);
	my $expectedMsg = '<imagescan description="'
		. $cmd->getConfigDir()
		. '">'
		. '<package name="kiwi-test-dummy" arch="noarch" version="0.0.1-1"/>'
		. '</imagescan>';
	$this -> assert_str_equals($expectedMsg, $tree -> toString());
	$this -> assert_not_null($tree);
	# Setting up SaT generates a number of meesges that are not useful
	# for this test, just make sure everything in the log object gets reset
	$kiwi -> getState();
	# Clean up
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_printTree_improperArg
#------------------------------------------
sub test_printTree_improperArg {
	# ...
	# Test getting a tree
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	# Supply improper argument
	my @invalidOpts = ('ola');
	my $res = $info -> printXMLInfo(@invalidOpts);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Expecting ARRAY_REF as first argument for info '
		. 'requests.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_printTree_invalidReq
#------------------------------------------
sub test_printTree_invalidReq {
	# ...
	# Test getting a tree
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	# Supply improper argument
	my @invalidOpts = ('ola');
	my $res = $info -> printXMLInfo(\@invalidOpts);
	my $expectedMsg = 'Requested information option ola not supported, '
		. 'ignoring.';
	my $warnMsg = $kiwi -> getWarningMessage();
	$this -> assert_str_equals($expectedMsg, $warnMsg);
	my $state = $kiwi -> getWarningState();
	$this -> assert_equals('skipped', $state);
	my $errMsg = $kiwi -> getErrorMessage();
	$expectedMsg = 'None of the specified information options are available.';
	$this -> assert_str_equals($expectedMsg, $errMsg);
	my $msg = $kiwi -> getMessage();
	$expectedMsg = "Choose between the following:\n"
		. "--> archives       :List of tar archives to be installed\n"
		. "--> overlay-files  :List of files in root overlay\n"
		. "--> packages       :List of packages to be installed\n"
		. "--> patterns       :List configured patterns\n"
		. "--> profiles       :List profiles\n"
		. "--> repo-patterns  :List available patterns from repos\n"
		. "--> size           :List install/delete size estimation\n"
		. "--> sources        :List configured source URLs\n"
		. "--> types          :List configured types\n"
		. "--> version        :List name and version\n";
	$this -> assert_str_equals($expectedMsg, $msg);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_printTree_noArg
#------------------------------------------
sub test_printTree_noArg {
	# ...
	# Test getting a tree
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	# Do not supply an argument
	my $res = $info -> printXMLInfo();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'No information requested, nothing todo.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_profileInfo
#------------------------------------------
sub test_profileInfo {
	# ...
	# Test to ensure we get the proper profile information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	my @requests = ('profiles');
	my $tree = $info -> getXMLInfoTree(\@requests);
	my $expectedMsg = '<imagescan description="'.$cmd->getConfigDir().'"><profile name="first" description="a '
		. 'profile"/><profile name="second" description="another profile"/>'
		.  '</imagescan>';
	$this -> assert_not_null($tree);
	$this -> assert_str_equals($expectedMsg, $tree -> toString());
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_typesInfo
#------------------------------------------
sub test_typesInfo {
	# ...
	# Test to ensure we get the proper type information back
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	my @requests = ('types');
	my $tree = $info -> getXMLInfoTree(\@requests);
	my $expectedMsg = '<imagescan description="'
		. $cmd->getConfigDir()
		. '">'
		. '<type name="iso" primary="true" boot="isoboot/suse-11.4"/>'
		. '<type name="oem" boot="oemboot/suse-11.4"/>'
		. '<type name="xfs"/>'
		. '</imagescan>';
	$this -> assert_not_null($tree);
	$this -> assert_str_equals($expectedMsg, $tree -> toString());
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_sizeInfo
#------------------------------------------
sub test_sizeInfo {
	# ...
	# Test to ensure we get the proper package information
	# skip test if not root
	# ---
	if ($< != 0) {
		print "\t\tInfo: Not root, skipping test_sizeInfo\n";
		return;
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Avoid chain failures
	$this -> removeTestTmpDir();
	# Setup directory to operate as repository
	my $repoDir = $this -> createTestTmpDir();
	my $pckgOrig = $this -> getDataDir();
	system "cp -r $pckgOrig/kiwiTestRepo $repoDir";
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	# Replace the repo from the config file with the previously setup repo
	$cmd -> setReplacementRepo($repoDir . '/kiwiTestRepo', 'testRepo',
							1, 'rpm-md');
	my $info = $this -> __getInfoObj($cmd);
	my @requests = ('size');
	my $tree = $info -> getXMLInfoTree(\@requests);
	my $expectedMsg = '<imagescan description="'
		. $cmd->getConfigDir()
		. '">'
		. '<size rootsizeKB="1"/>'
		. '</imagescan>';
	$this -> assert_str_equals($expectedMsg, $tree -> toString());
	$this -> assert_not_null($tree);
	# Setting up SaT generates a number of meesges that are not useful
	# for this test, just make sure everything in the log object gets reset
	$kiwi -> getState();
	# Clean up
	$this -> removeTestTmpDir();
	return;
}

#==========================================
# test_sourcesInfo
#------------------------------------------
sub test_sourcesInfo {
	# ...
	# Test to ensure we get the proper source information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	my @requests = ('sources');
	my $tree = $info -> getXMLInfoTree(\@requests);
	my $expectedMsg = '<imagescan description="'
		. $cmd->getConfigDir()
		.'">'
		. '<source path="/tmp" type="rpm-dir"/>'
		. '</imagescan>';
	$this -> assert_not_null($tree);
	$this -> assert_str_equals($expectedMsg, $tree -> toString());
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_versionInfo
#------------------------------------------
sub test_versionInfo {
	# ...
	# Test to ensure we get the proper version information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd  = $this -> __getCmdl();
	$cmd -> setConfigDir($this -> {baseDir});
	my $info = $this -> __getInfoObj($cmd);
	my @requests = ('version');
	my $tree = $info -> getXMLInfoTree(\@requests);
	my $expectedMsg = '<imagescan description="'.$cmd->getConfigDir().'"><image version="1.0.0" '
		. 'name="test-xml-infod"/></imagescan>';
	$this -> assert_not_null($tree);
	$this -> assert_str_equals($expectedMsg, $tree -> toString());
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getInfoObj
#------------------------------------------
sub __getInfoObj {
	# ...
	# Helper mehod to create a valid XMLInfo object
	# ---
	my $this = shift;
	my $cmd  = shift;
	my $info = KIWIXMLInfo -> new($this -> {kiwi}, $cmd);

	return $info;
}

#==========================================
# __getCmdl
#------------------------------------------
sub __getCmdl {
	# ...
	# Helper to create a command line object
	# ---
	my $this = shift;
	return KIWICommandLine -> new($this -> {kiwi});
}


1;
