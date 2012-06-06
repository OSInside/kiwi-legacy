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
# test_addRepositories
#------------------------------------------
sub test_addRepositories {
	# ...
	# Verify proper operation of addRepositories method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @addedTypes = qw /red-carpet urpmi/;
	my @newLocs = ['/repos/rc/12.1', 'http://otherpublicrepos/12.1'];
	my @newAlia = qw /rc pubrepo/;
	my @newPrios = qw /13 99/;
	my @newUsr = qw /pablo/;
	my @newPass = qw /ola/;
	$xml = $xml -> addRepository(\@addedTypes, @newLocs, \@newAlia,
								\@newPrios, \@newUsr, \@newPass);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my %repos = $xml -> getRepositories();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numRepos = scalar keys %repos;
	$this -> assert_equals(6, $numRepos);
	# Spot check that existing data was not modified
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
	@repoInfo = @{$repos{'https//myreposerver/protectedrepos/12.1'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('foo', $repoInfo[3]);
	$this -> assert_str_equals('bar', $repoInfo[4]);
	# Verify that new data exists
	@repoInfo = @{$repos{'/repos/rc/12.1'}};
	$this -> assert_str_equals('red-carpet', $repoInfo[0]);
	$this -> assert_str_equals('rc', $repoInfo[1]);
	$this -> assert_str_equals('13', $repoInfo[2]);
	$this -> assert_str_equals('pablo', $repoInfo[3]);
	$this -> assert_str_equals('ola', $repoInfo[4]);
	@repoInfo = @{$repos{'http://otherpublicrepos/12.1'}};
	$this -> assert_str_equals('urpmi', $repoInfo[0]);
	$this -> assert_str_equals('pubrepo', $repoInfo[1]);
	$this -> assert_str_equals('99', $repoInfo[2]);
}

#==========================================
# test_addRepositoriesInvalidTypeInf
#------------------------------------------
sub test_addRepositoriesInvalidTypeInf {
	# ...
	# Verify proper operation of addRepositories method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @addedTypes = qw /red-carpet ola/;
	my @newLocs = ['/repos/rc/12.1', 'http://otherpublicrepos/12.1'];
	my @newAlia = qw /rc pubrepo/;
	my @newPrios = qw /13 99/;
	my @newUsr = qw /pablo/;
	my @newPass = qw /ola/;
	$xml = $xml -> addRepository(\@addedTypes, @newLocs, \@newAlia,
								\@newPrios, \@newUsr, \@newPass);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Addition of requested repo type [ola] not supported';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	my %repos = $xml -> getRepositories();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numRepos = scalar keys %repos;
	$this -> assert_equals(5, $numRepos);
	# Spot check that existing data was not modified
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
	@repoInfo = @{$repos{'https//myreposerver/protectedrepos/12.1'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('foo', $repoInfo[3]);
	$this -> assert_str_equals('bar', $repoInfo[4]);
	# Verify that new data exists
	@repoInfo = @{$repos{'/repos/rc/12.1'}};
	$this -> assert_str_equals('red-carpet', $repoInfo[0]);
	$this -> assert_str_equals('rc', $repoInfo[1]);
	$this -> assert_str_equals('13', $repoInfo[2]);
	$this -> assert_str_equals('pablo', $repoInfo[3]);
	$this -> assert_str_equals('ola', $repoInfo[4]);
}

#==========================================
# test_addRepositoriesNoTypeInf
#------------------------------------------
sub test_addRepositoriesNoTypeInf {
	# ...
	# Verify proper operation of addRepositories method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @addedTypes = qw /red-carpet/;
	my @newLocs = ['/repos/rc/12.1', 'http://otherpublicrepos/12.1'];
	my @newAlia = qw /rc pubrepo/;
	my @newPrios = qw /13 99/;
	my @newUsr = qw /pablo/;
	my @newPass = qw /ola/;
	$xml = $xml -> addRepository(\@addedTypes, @newLocs, \@newAlia,
								\@newPrios, \@newUsr, \@newPass);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'No type for repo [http://otherpublicrepos/12.1] '
		. 'specified';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	my %repos = $xml -> getRepositories();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numRepos = scalar keys %repos;
	$this -> assert_equals(5, $numRepos);
	# Spot check that existing data was not modified
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
	@repoInfo = @{$repos{'https//myreposerver/protectedrepos/12.1'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('foo', $repoInfo[3]);
	$this -> assert_str_equals('bar', $repoInfo[4]);
	# Verify that new data exists
	@repoInfo = @{$repos{'/repos/rc/12.1'}};
	$this -> assert_str_equals('red-carpet', $repoInfo[0]);
	$this -> assert_str_equals('rc', $repoInfo[1]);
	$this -> assert_str_equals('13', $repoInfo[2]);
	$this -> assert_str_equals('pablo', $repoInfo[3]);
	$this -> assert_str_equals('ola', $repoInfo[4]);
}

#==========================================
# test_addStripConsistentCall
#------------------------------------------
sub test_addStripConsistentCall {
	# ...
	# Verify proper operation of addStrip method with improper argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @newDel = qw (/etc/hosts /bin/zsh);
	$xml -> addStrip ('files', @newDel);
	my @delFiles = $xml -> getStripDelete();
	my $msg = $kiwi -> getMessage();
	my $expected = "Specified strip section type 'files' not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw (/etc/resolv.conf /lib/libc.so);
	$this -> assert_array_equal(\@expectedNames, \@delFiles);
}

#==========================================
# test_addStripDelete
#------------------------------------------
sub test_addStripDelete {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @newDel = qw (/etc/hosts /bin/zsh);
	$xml -> addStrip ('delete', @newDel);
	my @delFiles = $xml -> getStripDelete();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw (/etc/resolv.conf /lib/libc.so /etc/hosts /bin/zsh);
	$this -> assert_array_equal(\@expectedNames, \@delFiles);
}

#==========================================
# test_addStripDelete
#------------------------------------------
sub test_addStripDeleteNoPreExist {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @newDel = qw (/etc/hosts /bin/zsh);
	$xml -> addStrip ('delete', @newDel);
	my @delFiles = $xml -> getStripDelete();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw (/etc/hosts /bin/zsh);
	$this -> assert_array_equal(\@expectedNames, \@delFiles);
}

#==========================================
# test_addStripLibs
#------------------------------------------
sub test_addStripLibs {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @newLibs = qw /libm libcrypt/;
	$xml -> addStrip ('libs', @newLibs);
	my @libFiles = $xml -> getStripLibs();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /libdbus libnss libm libcrypt/;
	$this -> assert_array_equal(\@expectedNames, \@libFiles);
}

#==========================================
# test_addStripTools
#------------------------------------------
sub test_addStripTools {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @newTools = qw /xfsrestore install-info/;
	$xml -> addStrip ('tools', @newTools);
	my @toolFiles = $xml -> getStripTools();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /megacli virt-mgr xfsrestore install-info/;
	$this -> assert_array_equal(\@expectedNames, \@toolFiles);
}

#==========================================
# test_getBootTheme
#------------------------------------------
sub test_getBootTheme {
	# ...
	# Verify proper return of getBootTheme method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getBootTheme();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('bluestar', $value);
}

#==========================================
# test_getConfigName
#------------------------------------------
sub test_getConfigName {
	# ...
	# Verify proper return of getConfigName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getConfigName();
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @parts = split /\//x, $value;
	$this -> assert_str_equals('config.xml', $parts[-1]);
	$this -> assert_str_equals('preferenceSettings', $parts[-2]);
	$this -> assert_str_equals('kiwiXML', $parts[-3]);
	$this -> assert_str_equals('data', $parts[-4]);
	$this -> assert_str_equals('unit', $parts[-5]);
	$this -> assert_str_equals('tests', $parts[-6]);
}

#==========================================
# test_getDefaultPrebuiltDir
#------------------------------------------
sub test_getDefaultPrebuiltDir {
	# ...
	# Verify proper return of getDefaultPrebuiltDir method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getDefaultPrebuiltDir();
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/work/kiwibootimgs', $value);
}

#==========================================
# test_getEc2Config
#------------------------------------------
sub test_getEc2Config {
	# ...
	# Verify proper return of EC2 configuration settings
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'ec2ConfigSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %ec2Info = $xml -> getEc2Config();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	$this -> assert_str_equals('12345678911', $ec2Info{AWSAccountNr});
	$this -> assert_str_equals('cert.cert', $ec2Info{EC2CertFile});
	$this -> assert_str_equals('pv-key.key', $ec2Info{EC2PrivateKeyFile});
	my @expectedRegions = qw / EU-West US-West /;
	$this -> assert_array_equal(\@expectedRegions, $ec2Info{EC2Regions});
}

#==========================================
# test_getImageDefaultDestination
#------------------------------------------
sub test_getImageDefaultDestination {
	# ...
	# Verify proper return of getImageDefaultDestination method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageDefaultDestination();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/work/tmp', $value);
}

#==========================================
# test_getImageDefaultRoot
#------------------------------------------
sub test_getImageDefaultRoot {
	# ...
	# Verify proper return of getImageDefaultRoot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageDefaultRoot();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/var/tmp', $value);
}

#==========================================
# test_getImageDisplayName
#------------------------------------------
sub test_getImageDisplayName {
	# ...
	# Verify proper return of getImageDisplayName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageDisplayName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('testcase', $value);
}

#==========================================
# test_getImageID
#------------------------------------------
sub test_getImageID {
	# ...
	# Verify proper return of getImageID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('3030150', $value);
}

#==========================================
# test_getImageName
#------------------------------------------
sub test_getImageName {
	# ...
	# Verify proper return of getImageName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('testCase-preference-settings', $value);
}

#==========================================
# test_getImageSize
#------------------------------------------
sub test_getImageSizeNotAdditive {
	# ...
	# Verify proper return of getImageSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageSize();
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
# test_getImageSizeAdditiveBytes
#------------------------------------------
sub test_getImageSizeAdditiveBytesNotAdditive {
	# ...
	# Verify proper return of getImageSizeAdditiveBytes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageSizeAdditiveBytes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('0', $value);
}

#==========================================
# test_getImageSizeBytes
#------------------------------------------
sub test_getImageSizeBytesNotAdditive {
	# ...
	# Verify proper return of getImageSizeBytes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageSizeBytes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('21474836480', $value);
}

#==========================================
# test_getImageTypeAndAttributes
#------------------------------------------
sub test_getImageTypeAndAttributesSimple {
	# ...
	# Verify proper return of getImageTypeAndAttributes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $typeInfo = $xml -> getImageTypeAndAttributes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('vmx', $typeInfo->{type});
}

#==========================================
# test_getImageVersion
#------------------------------------------
sub test_getImageVersion {
	# ...
	# Verify proper return of getImageVersion method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageVersion();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('13.20.26', $value);
}

#==========================================
# test_getLocale
#------------------------------------------
sub test_getLocale {
	# ...
	# Verify proper return of getLocale method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getLocale();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('en_US', $value);
}

#==========================================
# test_getLVMGroupName
#------------------------------------------
sub test_getLVMGroupName {
	# ...
	# Verify proper return of getLVMGroupName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getLVMGroupName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('test_Volume', $value);
}

#==========================================
# test_getLVMVolumes
#------------------------------------------
sub test_getLVMVolumes {
	# ...
	# Verify proper return of getLVMVolumes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %volumes = $xml -> getLVMVolumes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedVolumes = qw /usr tmp var home/;
	my @volNames = keys %volumes;
	$this -> assert_array_equal(\@expectedVolumes, \@volNames);
	my @volSettings = $volumes{usr};
	$this -> assert_equals(4096, $volSettings[0][0]);
	$this -> assert_equals(1, $volSettings[0][1]);
	@volSettings = $volumes{tmp};
	$this -> assert_str_equals('all', $volSettings[0][0]);
	$this -> assert_equals(0, $volSettings[0][1]);
	@volSettings = $volumes{var};
	$this -> assert_equals(50, $volSettings[0][0]);
	$this -> assert_equals(1, $volSettings[0][1]);
	@volSettings = $volumes{home};
	$this -> assert_equals(2048, $volSettings[0][0]);
	$this -> assert_equals(0, $volSettings[0][1]);
}

#==========================================
# test_getLVMVolumesDisallowed
#------------------------------------------
sub test_getLVMVolumesUsingDisallowed {
	# ...
	# Verify proper return of getLVMVolumes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfigDisallowedDir';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %volumes = $xml -> getLVMVolumes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('LVM: Directory sbin is not allowed', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	# Test this condition last to get potential error messages
	my @expectedVolumes = qw /tmp var/;
	my @volNames = keys %volumes;
	$this -> assert_array_equal(\@expectedVolumes, \@volNames);
	my @volSettings = $volumes{tmp};
	$this -> assert_str_equals('all', $volSettings[0][0]);
	$this -> assert_equals(0, $volSettings[0][1]);
	@volSettings = $volumes{var};
	$this -> assert_equals(50, $volSettings[0][0]);
	$this -> assert_equals(1, $volSettings[0][1]);
}

#==========================================
# test_getLVMVolumesRoot
#------------------------------------------
sub test_getLVMVolumesUsingRoot {
	# ...
	# Verify proper return of getLVMVolumes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfigWithRoot';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %volumes = $xml -> getLVMVolumes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('LVM: Directory / is not allowed', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	# Test this condition last to get potential error messages
	my @expectedVolumes = qw /tmp var/;
	my @volNames = keys %volumes;
	$this -> assert_array_equal(\@expectedVolumes, \@volNames);
	my @volSettings = $volumes{tmp};
	$this -> assert_str_equals('all', $volSettings[0][0]);
	$this -> assert_equals(0, $volSettings[0][1]);
	@volSettings = $volumes{var};
	$this -> assert_equals(50, $volSettings[0][0]);
	$this -> assert_equals(1, $volSettings[0][1]);
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
# test_getOVFConfig
#------------------------------------------
sub test_getOVFConfig {
	#...
	# Verify proper return of the OVF data
	#---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'ovfConfigSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %ovfConfig = $xml -> getOVFConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	$this -> assert_str_equals('1024', $ovfConfig{ovf_desmemory});
	$this -> assert_str_equals('2048', $ovfConfig{ovf_maxmemory});
	$this -> assert_str_equals('1024', $ovfConfig{ovf_memory});
	$this -> assert_str_equals('512', $ovfConfig{ovf_minmemory});
	$this -> assert_str_equals('2', $ovfConfig{ovf_descpu});
	$this -> assert_str_equals('4', $ovfConfig{ovf_maxcpu});
	$this -> assert_str_equals('2', $ovfConfig{ovf_ncpus});
	$this -> assert_str_equals('1', $ovfConfig{ovf_mincpu});
	$this -> assert_str_equals('powervm', $ovfConfig{ovf_type});
	$this -> assert_str_equals('/dev/sda', $ovfConfig{ovf_disk});
	$this -> assert_str_equals('scsi', $ovfConfig{ovf_disktype});
	my $nicConfig = $ovfConfig{ovf_bridge};
	my %nicSetup = %$nicConfig;
	my $nicInfo = $nicSetup{eth0};
	$this -> assert_not_null($nicInfo);
}

#==========================================
# test_getPXEDeployBlockSize
#------------------------------------------
sub test_getPXEDeployBlockSize {
	# ...
	# Verify proper return of getPXEDeployBlockSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployBlockSize();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('4096', $value);
}

#==========================================
# test_getPXEDeployConfiguration
#------------------------------------------
sub test_getPXEDeployConfiguration {
	# ...
	# Verify proper return of getPXEDeployConfiguration method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %config = $xml -> getPXEDeployConfiguration();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null(%config);
	$this -> assert_str_equals('target', $config{installSource});
}

#==========================================
# test_getPXEDeployImageDevice
#------------------------------------------
sub test_getPXEDeployImageDevice {
	# ...
	# Verify proper return of getPXEDeployImageDevice method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployImageDevice();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/dev/sda', $value);
}

#==========================================
# test_getPXEDeployInitrd
#------------------------------------------
sub test_getPXEDeployInitrd {
	# ...
	# Verify proper return of getPXEDeployInitrd method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployInitrd();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/pxeSetup/specialInitrd', $value);
}

#==========================================
# test_getPXEDeployKernel
#------------------------------------------
sub test_getPXEDeployKernel {
	# ...
	# Verify proper return of getPXEDeployKernel method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployKernel();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/pxeSetup/specialKernel', $value);
}

#==========================================
# test_getPXEDeployPartitions
#------------------------------------------
sub test_getPXEDeployPartitions {
	# ...
	# Verify proper return of getPXEDeployPartitions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @partitions = $xml -> getPXEDeployPartitions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	$this -> assert_not_null(@partitions);
	my $partInfo = $partitions[0];
	$this -> assert_str_equals('swap', $partInfo -> {type});
	$this -> assert_str_equals('1', $partInfo -> {number});
	$this -> assert_str_equals('5', $partInfo -> {size});
	$partInfo = $partitions[1];
	$this -> assert_str_equals('/', $partInfo -> {mountpoint});
	$this -> assert_equals(1, $partInfo -> {target});
}

#==========================================
# test_getPXEDeployServer
#------------------------------------------
sub test_getPXEDeployServer {
	# ...
	# Verify proper return of getPXEDeployServer method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployServer();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('192.168.100.2', $value);
}

#==========================================
# test_getPXEDeployTimeout
#------------------------------------------
sub test_getPXEDeployTimeout {
	# ...
	# Verify proper return of getPXEDeployTimeout method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployTimeout();
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
# test_getPXEDeployUnionConfig
#------------------------------------------
sub test_getPXEDeployUnionConfig {
	# ...
	# Verify proper return of getPXEDeployUnionConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %unionConfig = $xml -> getPXEDeployUnionConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	$this -> assert_not_null(%unionConfig);
	$this -> assert_str_equals('/dev/sda2', $unionConfig{ro});
	$this -> assert_str_equals('/dev/sda3', $unionConfig{rw});
	$this -> assert_str_equals('clicfs', $unionConfig{type});
}

#==========================================
# test_getProfiles
#------------------------------------------
sub test_getProfiles {
	# ...
	# Verify proper storage of profile information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
	);
	my @profiles = $xml -> getProfiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test these conditions last to get potential error messages
	my $numProfiles = scalar @profiles;
	$this -> assert_equals(3, $numProfiles);
	for my $prof (@profiles) {
		my $name = $prof -> {name};
		if ($name eq 'profA') {
			$this -> assert_str_equals('false', $prof -> {include});
			$this -> assert_str_equals('Test prof A', $prof -> {description});
		} elsif ($name eq 'profB') {
			$this -> assert_str_equals('true', $prof -> {include});
		} else {
			$this -> assert_str_equals('profC', $prof -> {name});
		}
	}
}

#==========================================
# test_getRPMCheckSignatures
#------------------------------------------
sub test_getRPMCheckSignaturesFalse {
	# ...
	# Verify proper return of getRPMCheckSignatures method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMCheckSignatures();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($value);
}

#==========================================
# test_getRPMExcludeDocs
#------------------------------------------
sub test_getRPMExcludeDocsFalse {
	# ...
	# Verify proper return of getRPMExcludeDocs method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMExcludeDocs();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($value);
}

#==========================================
# test_getRPMForce
#------------------------------------------
sub test_getRPMForceFalse {
	# ...
	# Verify proper return of getRPMForce method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMForce();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($value);
}

#==========================================
# test_getRPMCheckSignatures
#------------------------------------------
sub test_getRPMCheckSignaturesTrue {
	# ...
	# Verify proper return of getRPMCheckSignatures method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMCheckSignatures();
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
# test_getRPMExcludeDocs
#------------------------------------------
sub test_getRPMExcludeDocsTrue {
	# ...
	# Verify proper return of getRPMExcludeDocs method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMExcludeDocs();
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
# test_getRPMForce
#------------------------------------------
sub test_getRPMForceTrue {
	# ...
	# Verify proper return of getRPMForce method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMForce();
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
# test_getRepositories
#------------------------------------------
sub test_getRepositories {
	# ...
	# Verify proper return of getRepositories method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %repos = $xml -> getRepositories();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numRepos = scalar keys %repos;
	$this -> assert_equals(4, $numRepos);
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
	@repoInfo = @{$repos{'http://download.opensuse.org/update/12.1'}};
	$this -> assert_str_equals('rpm-md', $repoInfo[0]);
	$this -> assert_str_equals('update', $repoInfo[1]);
	$this -> assert_str_equals('true', $repoInfo[-1]);
	@repoInfo = @{$repos{'https//myreposerver/protectedrepos/12.1'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('foo', $repoInfo[3]);
	$this -> assert_str_equals('bar', $repoInfo[4]);
	@repoInfo = @{$repos{'/repos/12.1-additional'}};
	$this -> assert_str_equals('rpm-dir', $repoInfo[0]);
}

#==========================================
# test_getSplitPersistentExceptions
#------------------------------------------
sub test_getSplitPersistentExceptions {
	# ...
	# Verify proper return of getSplitPersistentExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @persExcept = $xml -> getSplitPersistentExceptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedExcept = qw / bar /;
	$this -> assert_array_equal(\@expectedExcept, \@persExcept);
}

#==========================================
# test_getSplitPersistentFiles
#------------------------------------------
sub test_getSplitPersistentFiles {
	# ...
	# Verify proper return of getSplitPersistentFiles method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @persFiles = $xml -> getSplitPersistentFiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /bar64 genericBar/;
	$this -> assert_array_equal(\@expectedNames, \@persFiles);
}

#==========================================
# test_getSplitTempExceptions
#------------------------------------------
sub test_getSplitTempExceptions {
	# ...
	# Verify proper return of getSplitTempExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @tmpExcept = $xml -> getSplitTempExceptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedExcept = qw /foo anotherFoo/;
	$this -> assert_array_equal(\@expectedExcept, \@tmpExcept);
}

#==========================================
# test_getSplitTempFiles
#------------------------------------------
sub test_getSplitTempFiles {
	# ...
	# Verify proper return of getSplitTempFiles method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @tmpFiles = $xml -> getSplitTempFiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /foo64 genericFoo/;
	$this -> assert_array_equal(\@expectedNames, \@tmpFiles);
}

#==========================================
# test_getStripDelete
#------------------------------------------
sub test_getStripDelete {
	# ...
	# Verify proper return of getStripDelete method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @delFiles = $xml -> getStripDelete();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw (/etc/resolv.conf /lib/libc.so);
	$this -> assert_array_equal(\@expectedNames, \@delFiles);
}

#==========================================
# test_getStripLibs
#------------------------------------------
sub test_getStripLibs {
	# ...
	# Verify proper return of getStripLibs method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @libFiles = $xml -> getStripLibs();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /libdbus libnss/;
	$this -> assert_array_equal(\@expectedNames, \@libFiles);
}

#==========================================
# test_getStripNodeList
#------------------------------------------
sub test_getStripNodeList {
	# ...
	# Verify the expected return of getStripNodeList
	# Note, this method should eventually disappear from the XML object
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @stripNodes = $xml -> getStripNodeList() -> get_nodelist();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my @expectedDel = qw (/etc/resolv.conf /lib/libc.so);
	my @expectedLibs = qw /libdbus libnss/;
	my @expectedTools = qw /megacli virt-mgr/;
	for my $node (@stripNodes) {
		my $type  = $node -> getAttribute ("type");
		my @files = $node -> getElementsByTagName ("file");
		my @items = ();
		for my $element (@files) {
			my $name = $element -> getAttribute ("name");
			push (@items,$name);
		}
		if ($type eq 'delete') {
			$this -> assert_array_equal(\@expectedDel, \@items);
		} elsif ($type eq 'libs') {
			$this -> assert_array_equal(\@expectedLibs, \@items);
		} elsif ($type eq 'tools') {
			$this -> assert_array_equal(\@expectedTools, \@items);
		} else {
			$this -> assert_null(1);
		}
	}
}

#==========================================
# test_getStripTools
#------------------------------------------
sub test_getStripTools {
	# ...
	# Verify proper return of getStripTools method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @toolFiles = $xml -> getStripTools();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /megacli virt-mgr/;
	$this -> assert_array_equal(\@expectedNames, \@toolFiles);
}

#==========================================
# test_getUsers
#------------------------------------------
sub test_getUsers {
	# ...
	# Verify proper return of user information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %usrData = $xml -> getUsers();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my @expectedUsers = qw /root auser buser/;
	my @users = keys %usrData;
	$this -> assert_array_equal(\@expectedUsers, \@users);
	$this -> assert_str_equals('2000', $usrData{auser}{gid});
	$this -> assert_str_equals('2000', $usrData{buser}{gid});
	$this -> assert_str_equals('mygrp', $usrData{auser}{group});
	$this -> assert_str_equals('mygrp', $usrData{buser}{group});
	$this -> assert_str_equals('root', $usrData{root}{group});
	$this -> assert_str_equals('2001', $usrData{auser}{uid});
	$this -> assert_str_equals('/root', $usrData{root}{home});
	$this -> assert_str_equals('linux', $usrData{buser}{pwd});
	$this -> assert_str_equals('plain', $usrData{buser}{pwdformat});
	$this -> assert_str_equals('Bert', $usrData{buser}{realname});
	$this -> assert_str_equals('/bin/ksh', $usrData{auser}{shell});
}

#==========================================
# test_getVMwareConfig
#------------------------------------------
sub test_getVMwareConfig {
	# ...
	# Verify proper return of VMWare configuration data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'vmwareConfigSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %vmConfig = $xml -> getVMwareConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	$this -> assert_str_equals('x86_64', $vmConfig{vmware_arch});
	$this -> assert_str_equals('2', $vmConfig{vmware_cdid});
	$this -> assert_str_equals('ide', $vmConfig{vmware_cdtype});
	my @expectedOpts = qw / ola pablo /;
	$this -> assert_array_equal(\@expectedOpts, $vmConfig{vmware_config});
	$this -> assert_str_equals('1', $vmConfig{vmware_diskid});
	$this -> assert_str_equals('scsi', $vmConfig{vmware_disktype});
	$this -> assert_str_equals('sles-64', $vmConfig{vmware_guest});
	$this -> assert_str_equals('7', $vmConfig{vmware_hwver});
	$this -> assert_str_equals('1024', $vmConfig{vmware_memory});
	$this -> assert_str_equals('2', $vmConfig{vmware_ncpus});
	my $nicConfig = $vmConfig{vmware_nic};
	my %nicSetup = %$nicConfig;
	my $nicInfo = $nicSetup{eth0};
	$this -> assert_not_null($nicInfo);
	my %nicDetails = %$nicInfo;
	$this -> assert_str_equals('e1000', $nicDetails{drv});
	$this -> assert_str_equals('dhcp', $nicDetails{mode});
}

#==========================================
# test_getXenConfig
#------------------------------------------
sub test_getXenConfig {
	# ...
	# Verify proper return of Xen  configuration data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'xenConfigSettings';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %vmConfig = $xml -> getXenConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my @expectedOpts = qw / foo bar /;
	$this -> assert_array_equal(\@expectedOpts, $vmConfig{xen_config});
	$this -> assert_str_equals('/dev/xvda', $vmConfig{xen_diskdevice});
	$this -> assert_str_equals('domU', $vmConfig{xen_domain});
	$this -> assert_str_equals('128', $vmConfig{xen_memory});
	$this -> assert_str_equals('3', $vmConfig{xen_ncpus});
	$this -> assert_str_equals('00:0C:6E:AA:57:2F',$vmConfig{xen_bridge}{br0});
}

#==========================================
# test_ignoreRepositories
#------------------------------------------
sub test_ignoreRepositories {
	# ...
	# Verify proper operation of ignoreRepositories method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> ignoreRepositories();
	my %repos = $xml -> getRepositories();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Ignoring all repositories previously configured';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my $numRepos = scalar keys %repos;
	$this -> assert_equals(0, $numRepos);
}

#==========================================
# test_invalidProfileRequest
#------------------------------------------
sub test_invalidProfileRequest {
	# ...
	# Test the privat __checkProfiles method by passing an invalid
	# profile name to the ctor.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfig';
	my @reqProf = qw /profD/;
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, \@reqProf, $this->{cmdL}
	);
	$this -> assert_null($xml);
	my $msg = $kiwi -> getErrorMessage();
	$this -> assert_str_equals('Profile profD: not found', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getErrorState();
	$this -> assert_str_equals('failed', $state);
	# for this test, just make sure everything in the log object gets reset
	$kiwi -> getState();;
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

#==========================================
# test_setRepository
#------------------------------------------
sub test_setRepository {
	# ...
	# Verify proper operation of setRepository method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = new KIWIXML(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> setRepository('rpm-md', '/repos/newpckgs', 'replacement',
								'5');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Replacing repository '
	. 'http://download.opensuse.org/update/12.1';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my %repos = $xml -> getRepositories();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numRepos = scalar keys %repos;
	$this -> assert_equals(4, $numRepos);
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
	@repoInfo = @{$repos{'https//myreposerver/protectedrepos/12.1'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('foo', $repoInfo[3]);
	$this -> assert_str_equals('bar', $repoInfo[4]);
	@repoInfo = @{$repos{'/repos/12.1-additional'}};
	$this -> assert_str_equals('rpm-dir', $repoInfo[0]);
	@repoInfo = @{$repos{'/repos/newpckgs'}};
	$this -> assert_str_equals('rpm-md', $repoInfo[0]);
	$this -> assert_str_equals('replacement', $repoInfo[1]);
	$this -> assert_str_equals('5', $repoInfo[2]);
	# Assert the expected repo has been replaced
	my $repoInfo = $repos{'http://download.opensuse.org/update/12.1'};
	$this -> assert_null($repoInfo);
}

1;
