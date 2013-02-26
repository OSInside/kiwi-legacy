#================
# FILE          : kiwiContainerBuilder.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIContainerBuilder
#               : module.
#               :
#               : Note we directly test private methods to help make detecting
#               : problems easier and keep the tests short.
#               :
# STATUS        : Development
#----------------
package Test::kiwiContainerBuilder;

use strict;
use warnings;
use File::Slurp;
use IPC::Open3;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIContainerBuilder;
use KIWIGlobals;
use KIWIXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {dataDir} = $this -> getDataDir() . '/kiwiConfigWriterFactory';
	$this -> removeTestTmpDir();
	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the KIWIContainerBuilder
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $cmdL = $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($builder);
	return;
}

#==========================================
# test_ctor_invalidArg1
#------------------------------------------
sub test_ctor_invalidArg1 {
	# ...
	# Test the KIWIContainerBuilder with invalid first argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $builder = KIWIContainerBuilder -> new('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIContainerBuilder: expecting KIWIXML object as '
		. 'first argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($builder);
	return;
}

#==========================================
# test_ctor_invalidArg2
#------------------------------------------
sub test_ctor_invalidArg2 {
	# ...
	# Test the KIWIContainerBuilder with invalid first argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $cmdL = $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, 'foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIContainerBuilder: expecting KIWICommandLine object '
		. 'as second argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($builder);
	return;
}

#==========================================
# test_ctor_noArg1
#------------------------------------------
sub test_ctor_noArg1 {
	# ...
	# Test the KIWIContainerBuilder with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $builder = KIWIContainerBuilder -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIContainerBuilder: expecting KIWIXML object as '
		. 'first argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($builder);
	return;
}

#==========================================
# test_ctor_noArg2
#------------------------------------------
sub test_ctor_noArg2 {
	# ...
	# Test the KIWIContainerBuilder with no second argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $cmdL = $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIContainerBuilder: expecting KIWICommandLine object '
		. 'as second argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($builder);
	return;
}

#==========================================
# test_applyContainerConfig
#------------------------------------------
sub test_applyContainerConfig {
	# ...
	# Test the KIWIContainerBuilder __applyContainerConfig method
	# --
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $cmdL = $this -> __getCommandLineObj();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	my $tmpDir = $this -> createTestTmpDir();
	# Create fstab file to be replaced
	mkdir $tmpDir . '/etc';
	my $status = open my $FSTAB, '>', $tmpDir . '/etc/fstab';
	$this -> assert_not_null($status);
	print $FSTAB 'foo';
	$status = close $FSTAB;
	$this -> assert_not_null($status);
	# Setup sysconfig dir for data writing by method
	mkdir $tmpDir . '/etc/sysconfig';
	# Test the method
	my $res = $builder -> __applyContainerConfig($tmpDir);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Setup container configuration';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	$this -> assert_file_exists($tmpDir . '/etc/fstab');
	$this -> assert_file_exists($tmpDir . '/etc/sysconfig/bootloader');
	$this -> assert_file_exists($tmpDir . '/etc/sysconfig/boot');
	$this -> assert_file_exists($tmpDir . '/etc/securetty');
	my $fstabE = q{};
	my $fstabT =  read_file($tmpDir . '/etc/fstab');
	$this -> assert_str_equals($fstabE, $fstabT);
	my $bootlE = 'LOADER_TYPE="none"' . "\n"
		. 'LOADER_LOCATION="none"' . "\n";
	my $bootlT = read_file($tmpDir . '/etc/sysconfig/bootloader');
	$this -> assert_str_equals($bootlE, $bootlT);
	my $bootE = 'ROOTFS_FSCK="0"' . "\n"
		. 'ROOTFS_BLKDEV="/dev/null"' . "\n";
	my $bootT = read_file($tmpDir . '/etc/sysconfig/boot');
	$this -> assert_str_equals($bootE, $bootT);
	my $secE = 'console' . "\n";
	my $secT = read_file($tmpDir . '/etc/securetty');
	$this -> assert_str_equals($secE, $secT);
	$this ->  removeTestTmpDir();
	return;
}

#==========================================
# test_copyUnpackedTreeContent
#------------------------------------------
sub test_copyUnpackedTreeContent {
	# ...
	# Test the KIWIContainerBuilder __copyUnpackedTreeContent method
	# --
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $cmdL = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	my $origin =  $tmpDir . '/origin';
	mkdir $origin;
	$cmdL -> setConfigDir($origin);
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	# Create some entries in the directory
	mkdir $origin . '/foo';
	mkdir $origin . '/bar';
	mkdir $origin . '/bar/glass';
	my $status = open my $WINE, '>', $origin . '/bar/glass/wine';
	$this -> assert_not_null($status);
	print $WINE 'If you do not like the food, drink more wine';
	$status = close $WINE;
	$this -> assert_not_null($status);
	$status = open my $BEER, '>', $origin . '/.good';
	$this -> assert_not_null($status);
	print $BEER 'A good beer is a good beer';
	$status = close $BEER;
	$this -> assert_not_null($status);
	# Test the method
	my $res = $builder -> __copyUnpackedTreeContent($tmpDir);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Copy unpacked image tree';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	$this -> assert_file_exists($tmpDir . '/.good');
	$this -> assert_file_exists($tmpDir . '/bar/glass/wine');
	if (! -d ($tmpDir . '/foo')) {
		this -> assert_null('Directory foo not found');
	}
	$this ->  removeTestTmpDir();
	return;
}

#==========================================
# test_createContainerBundle
#------------------------------------------
sub test_createContainerBundle {
	# ...
	# Test the __createContainerBundle method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir} . '/container';
	my $cmdL = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	$cmdL -> setImageTargetDir($tmpDir);
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	# Create a basic setup assimilating a true directory layout
	mkdir $tmpDir . '/container';
	mkdir $tmpDir . '/container/etc';
	mkdir $tmpDir . '/container/var';
	mkdir $tmpDir . '/container/var/lib';
	mkdir $tmpDir . '/container/var/lib/lxc';
	mkdir $tmpDir . '/container/var/lib/lxc/mycontainer';
	mkdir $tmpDir . '/container/var/lib/lxc/mycontainer/rootfs';
	my $status = open my $FSTAB, '>', $tmpDir . '/container/etc/fstab';
	$this -> assert_not_null($status);
	print $FSTAB 'proc  proc  proc nodev,noexec,nosuid 0 0';
	$status = close $FSTAB;
	$this -> assert_not_null($status);
	my $fl = $tmpDir . '/container/var/lib/lxc/mycontainer/rootfs/.peaks';
	$status = open my $PEAKS, '>', $fl;
	$this -> assert_not_null($status);
	print $PEAKS 'Matterhorn';
	print $PEAKS 'K2';
	$status = close $PEAKS;
	$this -> assert_not_null($status);
	# Test the method
	my $res = $builder -> __createContainerBundle();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Creating container tarball';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $expectedFl = 'container-test-lxc.';
	my $arch = KIWIGlobals -> instance() -> getArch();
	$expectedFl .= $arch . '-1.0.0.tbz';
	$this -> assert_file_exists($tmpDir . '/' . $expectedFl);
	my $CHILDWRITE;
	my $CHILDSTDO;
	my $CHILDSTDE;
	my $pid = open3 (
		$CHILDWRITE, $CHILDSTDO, $CHILDSTDE, "tar -tjvf $tmpDir/$expectedFl"
	);
	waitpid( $pid, 0 );
	$status = $? >> 8;
	my @files = <$CHILDSTDO>;
	if ($status) {
		$this -> assert_null('tar dump failed');
	}
	my @names;
	for my $fl (@files) {
		my @parts = split /\s/smx, $fl;
		push @names, $parts[-1];
	}
	my @expectedNames = qw (
		etc/
		etc/fstab
		var/
		var/lib/
		var/lib/lxc/
		var/lib/lxc/mycontainer/
		var/lib/lxc/mycontainer/rootfs/
		var/lib/lxc/mycontainer/rootfs/.peaks
	);
	$this -> assert_array_equal(\@expectedNames, \@names);
	$this ->  removeTestTmpDir();
	return;
}

#==========================================
# test_createContainerConfigDir
#------------------------------------------
sub test_createContainerConfigDir {
	# ...
	# Test the __createContainerConfigDir method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir} . '/container';
	my $cmdL = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	$cmdL -> setImageTargetDir($tmpDir);
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	my $res = $builder -> __createContainerConfigDir();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Creating container configuration directory';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $expectedDir = $tmpDir . '/container/etc/lxc/mycontainer';
	$this -> assert_dir_exists($expectedDir);
	$this ->  removeTestTmpDir();
	return;
}

#==========================================
# test_createDevNodes
#------------------------------------------
sub test_createDevNodes {
	# ...
	# Test the __createDevNodes method
	# ---
	if ($< != 0) {
		print "\t\tInfo: Not root, skipping test_createDevNodes\n";
		return;
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir} . '/container';
	my $cmdL = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	mkdir $tmpDir . '/dev';
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	my $res = $builder -> __createDevNodes($tmpDir);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Creating container device nodes';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	$this -> assert_dir_exists($tmpDir . '/dev/net');
	$this -> assert_dir_exists($tmpDir . '/dev/pts');
	$this -> assert_dir_exists($tmpDir . '/dev/shm');
	my @nodes = (
		'core',
		'fd',
		'full',
		'net/tun',
		'ptmx',
		'random',
		'tty',
		'tty0',
		'tty1',
		'tty10',
		'tty2',
		'tty3',
		'tty4',
		'urandom'
	);
	for my $nd (@nodes) {
		if (! -e ($tmpDir . '/dev/' . $nd)) {
			$this -> assert_null("$nd not properly created");
		}
	}
	$this ->  removeTestTmpDir();
	return;
}

#==========================================
# test_createInitTab
#------------------------------------------
sub test_createInitTab {
	# ...
	# Test the __createInitTab method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir} . '/container';
	my $cmdL = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	mkdir $tmpDir . '/etc';
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	my $res = $builder -> __createInitTab($tmpDir);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Create container inittab';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	$this -> assert_file_exists($tmpDir . '/etc/inittab');
	$this ->  removeTestTmpDir();
	return;
}

#==========================================
# test_createTargetRootTree
#------------------------------------------
sub test_createTargetRootTree {
	# ...
	# Test the __createTargetRootTree method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir} . '/container';
	my $cmdL = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	$cmdL -> setImageTargetDir($tmpDir);
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	my $tgtDir = $builder -> __createTargetRootTree();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Creating rootfs target directory';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $expectedDir = $tmpDir . '/container/var/lib/lxc/mycontainer/rootfs';
	$this -> assert_str_equals($expectedDir, $tgtDir);
	$this -> assert_dir_exists($expectedDir);
	$this ->  removeTestTmpDir();
	return;
}

#==========================================
# test_removeKiwiBuildInfo
#------------------------------------------
sub test_removeKiwiBuildInfo {
	# ...
	# Test the __removeKiwiBuildInfo method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir} . '/container';
	my $cmdL = $this -> __getCommandLineObj();
	my $tmpDir = $this -> createTestTmpDir();
	my $xml = $this -> __getXMLObj($confDir, $cmdL);
	my $builder = KIWIContainerBuilder -> new($xml, $cmdL);
	mkdir $tmpDir . '/image';
	my $status = open my $KCONF, '>', $tmpDir . '/.kconfig';
	$this -> assert_not_null($status);
	print $KCONF 'Would be kiwi config';
	$status = close $KCONF;
	$this -> assert_not_null($status);
	$status = open my $PROF, '>', $tmpDir . '/.profile';
	$this -> assert_not_null($status);
	print $PROF 'Would be kiwi profile';
	$status = close $PROF;
	$this -> assert_not_null($status);
	$status = open my $XML, '>', $tmpDir . '/image/config.xml';
	$this -> assert_not_null($status);
	print $XML 'WOULD be kiwi config.xml';
	$status = close $XML;
	$this -> assert_not_null($status);
	# Test the method
	my $res = $builder -> __removeKiwiBuildInfo($tmpDir);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Clean up kiwi image build artifacts';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	if (-f ($tmpDir . '/.kconfig')) {
		$this -> assert_null('.kconfig not removed as expected');
	}
	if (-f ($tmpDir . '/.profile')) {
		$this -> assert_null('.profile not removed as expected');
	}
	if (-d ($tmpDir . '/image')) {
		$this -> assert_null('image directory not removed as expected');
	}
	$this ->  removeTestTmpDir();
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
	# Return an empty command line
	# ---
	my $cmdL = KIWICommandLine -> new();
	return $cmdL;
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
	my $cmdL = shift;
	my $kiwi = $this->{kiwi};
	# TODO
	# Fix the creation of the XML object once the ctor arguments change
	my $xml = KIWIXML -> new(
		$configDir, undef, undef, $cmdL
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
