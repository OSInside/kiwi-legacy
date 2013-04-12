#================
# FILE          : kiwiXML.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
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
use Readonly;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIQX qw (qxx);
use KIWIXML;
use KIWIXMLPackageArchiveData;
use KIWIXMLDescriptionData;
use KIWIXMLDriverData;
use KIWIXMLEC2ConfigData;
use KIWIXMLOEMConfigData;
use KIWIXMLPackageData;
use KIWIXMLPackageCollectData;
use KIWIXMLPackageProductData;
use KIWIXMLPreferenceData;
use KIWIXMLProductOptionsData;
use KIWIXMLProfileData;
use KIWIXMLPXEDeployData;
use KIWIXMLRepositoryData;
use KIWIXMLSplitData;
use KIWIXMLStripData;
use KIWIXMLSystemdiskData;
use KIWIXMLTypeData;
use KIWIXMLUserData;
use KIWIXMLVMachineData;

#==========================================
# constants
#------------------------------------------
Readonly my $PREFSET_IMAGE_SIZE => 20;

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
	$this -> {cmdL} = KIWICommandLine -> new();

	return $this;
}

#==========================================
# test_addArchives
#------------------------------------------
sub test_addArchives {
	# ...
	# Verify addArchives method behavior
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @archivesToAdd;
	my %init = ( name => 'data.tgz');
	my $archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'moreData.tar.bz2';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'ppcData.tbz';
	$init{arch} = 'ppc64';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	my $res = $xml-> addArchives(\@archivesToAdd, 'default');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $archives = $xml -> getArchives();
	my @archiveNames;
	for my $archive (@{$archives}) {
		push @archiveNames, $archive -> getName();
	}
	my @expected = ('data.tgz', 'moreData.tar.bz2');
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'ppcData.tbz';
	}
	$this -> assert_array_equal(\@expected, \@archiveNames);
	return;
}

#==========================================
# test_addArchivesInvalidData
#------------------------------------------
sub test_addArchivesInvalidData {
	# ...
	# Verify addArchives properly errors on invalid data
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @archivesToAdd;
	my %init = ( name => 'data.tgz');
	my $archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'moreData.tar.bz2';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	push @archivesToAdd, 'foo';
	my $res = $xml-> addArchives(\@archivesToAdd);
	my $expected = 'addArchives: found array item not of type '
		. 'KIWIXMLPackageArchiveData in archives array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addArchivesInvalidDataTArg
#------------------------------------------
sub test_addArchivesInvalidDataTArg {
	# ...
	# Verify addArchives properly errors on invalid data type for argument
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addArchives('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'addArchives: expecting array ref for '
		. 'KIWIXMLPackageArchiveData array as first argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addArchivesInvalidProf
#------------------------------------------
sub test_addArchivesInvalidProf {
	# ...
	# Verify addArchives properly errors when an undefined profile is used
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @archivesToAdd;
	my %init = ( name => 'data.tgz');
	my $archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'moreData.tar.bz2';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	my @profs = qw / aTest timbuktu /;
	my $res = $xml-> addArchives(\@archivesToAdd, \@profs);
	my $expected = "Attempting to add archives to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addArchivesNoArg
#------------------------------------------
sub test_addArchivesNoArg {
	# ...
	# Verify proper operation of addArchives method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addArchives();
	my $msg = $kiwi -> getMessage();
	my $expected = 'addArchives: no archives specified, nothing to do';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_addArchivesToSpecProf
#------------------------------------------
sub test_addArchivesToSpecProf {
	#...
	# Verify addArchives method behavior ading archive to specific profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @archivesToAdd;
	my %init = ( name => 'data.tgz');
	my $archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'moreData.tar.bz2';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'ppcData.tar';
	$init{arch} = 'ppc64';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	my @useProf = ('profA');
	my $res = $xml-> addArchives(\@archivesToAdd, \@useProf);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $archives = $xml -> getArchives();
	my @archiveNames;
	for my $archive (@{$archives}) {
		push @archiveNames, $archive -> getName();
	}
	my @expected = ('defaultArchive.tar');
	$this -> assert_array_equal(\@expected, \@archiveNames);
	# Select the profile and verify the archive is in the proper loaction
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	# Clear the log
	$state = $kiwi -> getState();
	$archives = $xml -> getArchives();
	my @profArchiveNames;
	for my $archive (@{$archives}) {
		push @profArchiveNames, $archive -> getName();
	}
	push @expected, 'data.tgz';
	push @expected, 'moreData.tar.bz2';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'ppcData.tar';
	}
	$this -> assert_array_equal(\@expected, \@profArchiveNames);
	return;
}

#==========================================
# test_addArchivesToSpecType
#------------------------------------------
sub test_addArchivesToSpecType {
	#...
	# Verify addArchives method behavior ading archive to specific image type
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @archivesToAdd;
	my %init = ( name => 'data.tgz');
	my $archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'moreData.tar.bz2';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'ppcData.tar';
	$init{arch} = 'ppc64';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	my @useProf = ('profC');
	my $res = $xml-> addArchives(\@archivesToAdd, \@useProf, 'iso');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $archives = $xml -> getArchives();
	my @archiveNames;
	for my $archive (@{$archives}) {
		push @archiveNames, $archive -> getName();
	}
	my @expected = ('defaultArchive.tar');
	$this -> assert_array_equal(\@expected, \@archiveNames);
	# Select the profile but do not change the build type, thus we should
	# still get the default list
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	# Clear the log
	$state = $kiwi -> getState();
	$archives = $xml -> getArchives();
	my @profArchiveNames;
	for my $archive (@{$archives}) {
		push @profArchiveNames, $archive -> getName();
	}
	$this -> assert_array_equal(\@expected, \@profArchiveNames);
	# Change the build type and now we should get the added archives
	$xml = $xml -> setBuildType('iso');
	$archives = $xml -> getArchives();
	my @typeArchiveNames;
	for my $archive (@{$archives}) {
		push @typeArchiveNames, $archive -> getName();
	}
	push @expected, 'data.tgz';
	push @expected, 'moreData.tar.bz2';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'ppcData.tar';
	}
	$this -> assert_array_equal(\@expected, \@typeArchiveNames);
	return;
}

#==========================================
# test_addArchivesUndefinedType
#------------------------------------------
sub test_addArchivesUndefinedType {
	# ...
	# Verify addArchives properly errors when addtion to undefined image type
	# is attempted.
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @archivesToAdd;
	my %init = ( name => 'data.tgz');
	my $archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	$init{name} = 'moreData.tar.bz2';
	$archiveObj = KIWIXMLPackageArchiveData -> new(\%init);
	push @archivesToAdd, $archiveObj;
	my $res = $xml-> addArchives(\@archivesToAdd, 'default', 'vmx');
	my $expected = 'addArchives: could not find specified type '
		. "'vmx' within the active profiles; archives not added.";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addArchives_legacy
#------------------------------------------
sub test_addArchives_legacy {
	# ...
	# Verify proper operation of addArchives method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addArchives_legacy('image', undef, undef, 'archiveA.tgz',
							'archiveB.tar.bz2');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedArchs = qw /myInitStuff.tar myImageStuff.tgz archiveA.tgz
							archiveB.tar.bz2/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @archives;
	IMGARCHS:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'image') {
			my @archiveNodes = $node -> getElementsByTagName('archive');
			for my $archNode (@archiveNodes) {
				push @archives, $archNode -> getAttribute('name');
			}
			last IMGARCHS;
		}
	}
	$this -> assert_array_equal(\@expectedArchs, \@archives);
	return;
}

#==========================================
# test_addArchivesBootIncl_legacy
#------------------------------------------
sub test_addArchivesBootIncl_legacy {
	# ...
	# Verify proper operation of addArchives method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addArchives_legacy('image', 'true', undef, 'archiveA.tgz',
							'archiveB.tar.bz2');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedArchs = qw /myInitStuff.tar myImageStuff.tgz archiveA.tgz
							archiveB.tar.bz2/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @archives;
	IMGARCHS:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'image') {
			my @archiveNodes = $node -> getElementsByTagName('archive');
			for my $archNode (@archiveNodes) {
				my $archName = $archNode -> getAttribute('name');
				push @archives, $archName;
				if ($archName eq 'archiveA.tgz'
					or $archName eq 'archiveB.tar.bz2' ) {
					$this -> assert_str_equals('true',
								$archNode -> getAttribute('bootinclude'));
				}
			}
			last IMGARCHS;
		}
	}
	$this -> assert_array_equal(\@expectedArchs, \@archives);
	return;
}

#==========================================
# test_addBootstrapPackages
#------------------------------------------
sub test_addBootstrapPackages {
	# ...
	# Verify addBootstrapPackages method behavior
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'tar';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'powervm';
	$init{arch} = 'ppc64';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my $res = $xml-> addBootstrapPackages(\@packagesToAdd, 'default');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $packages = $xml -> getBootstrapPackages();
	my @pckgNames;
	for my $pckg (@{$packages}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = qw(
		cpio
		filesystem
		glibc-locale
		tar
	);
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'powervm';
	}
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_addBootstrapPackagesInvalidData
#------------------------------------------
sub test_addBootstrapPackagesInvalidData {
	# ...
	# Verify addBootstrapPackages properly errors on invalid data
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'gzip';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	push @packagesToAdd, 'foo';
	my $res = $xml-> addBootstrapPackages(\@packagesToAdd);
	my $expected = 'addBootstrapPackages: found array item not of type '
		. 'KIWIXMLPackageData in packages array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addBootstrapPackagesInvalidDataTArg
#------------------------------------------
sub test_addBootstrapPackagesInvalidDataTArg {
	# ...
	# Verify addBootstrapPackages properly errors on invalid data
	# type for argument
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addBootstrapPackages('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'addBootstrapPackages: expecting array ref for '
		. 'KIWIXMLPackageData array as first argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addBootstrapPackagesInvalidProf
#------------------------------------------
sub test_addBootstrapPackagesInvalidProf {
	# ...
	# Verify addBootstrapPackages properly errors when an undefined
	# profile is used
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'gzip';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my @profs = qw / aTest timbuktu /;
	my $res = $xml-> addBootstrapPackages(\@packagesToAdd, \@profs);
	my $expected = "Attempting to add packages to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addBootstrapPackagesNoArg
#------------------------------------------
sub test_addBootstrapPackagesNoArg {
	# ...
	# Verify proper operation of addBootstrapPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addBootstrapPackages();
	my $msg = $kiwi -> getMessage();
	my $expected = 'addBootstrapPackages: no packages specified, '
		. 'nothing to do';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_addBootstrapPackagesToSpecProf
#------------------------------------------
sub test_addBootstrapPackagesToSpecProf {
	#...
	# Verify addBootstrapPackages method behavior ading archive to
	# specific profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'gzip';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'powervm';
	$init{arch} = 'ppc64';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my @useProf = ('profA');
	my $res = $xml-> addBootstrapPackages(\@packagesToAdd, \@useProf);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $packages = $xml -> getBootstrapPackages();
	my @pckgNames;
	for my $pckg (@{$packages}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = ('filesystem', 'glibc-locale');
	$this -> assert_array_equal(\@expected, \@pckgNames);
	# Select the profile and verify the archive is in the proper loaction
	$xml = $xml -> setSelectionProfileNames(\@useProf);
# Clear the log
$state = $kiwi -> getState();
	$packages = $xml -> getBootstrapPackages();
	my @profPackageNames;
	for my $pckg (@{$packages}) {
		push @profPackageNames, $pckg -> getName();
	}
	push @expected, 'cpio';
	push @expected, 'gzip';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'powervm';
	}
	$this -> assert_array_equal(\@expected, \@profPackageNames);
	return;
}

#==========================================
# test_addDriversImproperDataT
#------------------------------------------
sub test_addDriversImproperDataT {
	# ...
	# Verify addDrivers behaves as expected, pass an array ref containing
	# a string
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @drvNames = qw /vboxsf epat dcdbas/;
	my @drvsToAdd = ();
	for my $drv (@drvNames) {
		push @drvsToAdd, KIWIXMLDriverData -> new($drv);
	}
	push @drvsToAdd, 'slip';
	push @drvsToAdd, KIWIXMLDriverData -> new('x25_asy');
	my $res = $xml -> addDrivers(\@drvsToAdd, 'default');
	my $expected = 'addDrivers: found array item not of type '
		. 'KIWIXMLDriverData in drivers array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addDriversInvalidProf
#------------------------------------------
sub test_addDriversInvalidProf {
	# ...
	# Verify addDrivers behaves as expected, pass a profile name that
	# is not defined.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @drvNames = qw /vboxsf epat dcdbas/;
	my @drvsToAdd = ();
	for my $drv (@drvNames) {
		push @drvsToAdd, KIWIXMLDriverData -> new($drv);
	}
	my @profs = qw / profA timbuktu profB /;
	my $res = $xml -> addDrivers(\@drvsToAdd, \@profs);
	my $expected = "Attempting to add drivers to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addDriversNoArgs
#------------------------------------------
sub test_addDriversNoArgs {
	# ...
	# Verify addDrivers behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addDrivers();
	my $expected = 'addDrivers: no drivers specified, nothing to do';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addDriversToCurrentProf
#------------------------------------------
sub test_addDriversToCurrentProf {
	# ...
	# Verify addDrivers behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Set up the profile to which the drivers are to be added
	my @useProf = ('profA');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): profA';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	# Add the drivers, using no 2nd arg results in drivers to be added to
	# profA only
	my @drvNames = qw /vboxsf epat dcdbas/;
	my @drvsToAdd = ();
	for my $drv (@drvNames) {
		my %init = ( name => $drv );
		push @drvsToAdd, KIWIXMLDriverData -> new(\%init);
	}
	$xml = $xml -> addDrivers(\@drvsToAdd);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defDrvs = qw /e1000 rs232 usb/;
	my @expectedDrvs = @defDrvs;
	push @expectedDrvs, @drvNames;
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expectedDrvs, 'at76c50x-usb';
	} elsif ($arch eq 's390') {
		push @expectedDrvs, 'loop';
	}
	push @expectedDrvs, 'pc300too';
	my @drvsUsed = @{$xml -> getDrivers()};
	my @drvNamesUsed = ();
	for my $drv (@drvsUsed) {
		push @drvNamesUsed, $drv -> getName();
	}
	$this -> assert_array_equal(\@drvNamesUsed, \@expectedDrvs);
	# Check that the drivers were not added anywhere else
	# reset the active profiles and we should only get the default drivers
	$xml = $xml -> setSelectionProfileNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	@drvsUsed = @{$xml -> getDrivers()};
	@drvNamesUsed = ();
	for my $drv (@drvsUsed) {
		push @drvNamesUsed, $drv -> getName();
	}
	$this -> assert_array_equal(\@drvNamesUsed, \@defDrvs);
	return;
}

#==========================================
# test_addDriversToDefault
#------------------------------------------
sub test_addDriversToDefault {
	# ...
	# Verify addDrivers behaves as expected when the keyword "default" is used
	# as the second argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Add the drivers, using the keyword "default" as 2nd arg
	my @drvNames = qw /vboxsf epat dcdbas/;
	my @drvsToAdd = ();
	for my $drv (@drvNames) {
		my %init = ( name => $drv );
		push @drvsToAdd, KIWIXMLDriverData -> new(\%init);
	}
	$xml = $xml -> addDrivers(\@drvsToAdd, 'default');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defDrvs = qw /e1000 rs232 usb/;
	my @expectedDrvs = @defDrvs;
	push @expectedDrvs, @drvNames;
	my @drvsUsed = @{$xml -> getDrivers()};
	my @drvNamesUsed = ();
	for my $drv (@drvsUsed) {
		push @drvNamesUsed, $drv -> getName();
	}
	$this -> assert_array_equal(\@drvNamesUsed, \@expectedDrvs);
	return;
}

#==========================================
# test_addDriversWrongArgs
#------------------------------------------
sub test_addDriversWrongArgs {
	# ...
	# Verify addDrivers behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addDrivers ('loop', 'default');
	my $expected = 'addDrivers: expecting array ref for KIWIXMLDriverData '
		. 'array as first argument';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addDrivers_legacy
#------------------------------------------
sub test_addDrivers_legacy {
	# ...
	# Verify proper operation of addDrivers method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addDrivers_legacy('fglrx', 'wl2000');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @driversNodes = $xml -> getDriversNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedDrivers = qw /usb e1000 rs232 fglrx wl2000/;
	my @confDrivers;
	for my $node (@driversNodes) {
		my @files = $node -> getElementsByTagName ("file");
		for my $element (@files) {
			my $name = $element -> getAttribute ("name");
			push (@confDrivers, $name);
		}
	}
	$this -> assert_array_equal(\@expectedDrivers, \@confDrivers);
	return;
}

#==========================================
# test_addFilesToDeleteImproperDataT
#------------------------------------------
sub test_addFilesToDeleteImproperDataT {
	# ...
	# Verify addFilesToDelete behaves as expected, pass an array ref
	# containing a string
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @delNames = qw /vboxsf epat dcdbas/;
	my @delFlsToAdd = ();
	for my $delName (@delNames) {
		push @delFlsToAdd, KIWIXMLStripData -> new($delName);
	}
	push @delFlsToAdd, 'slip';
	push @delFlsToAdd, KIWIXMLStripData -> new('x25_asy');
	my $res = $xml -> addFilesToDelete(\@delFlsToAdd, 'default');
	my $expected = 'addFilesToDelete: found array item not of type '
		. 'KIWIXMLStripData in deletefiles array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addFilesToDeleteInvalidProf
#------------------------------------------
sub test_addFilesToDeleteInvalidProf {
	# ...
	# Verify addFilesToDelete behaves as expected, pass a profile name that
	# is not defined.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @delNames = qw /vboxsf epat dcdbas/;
	my @delFlsToAdd = ();
	for my $delFl (@delNames) {
		push @delFlsToAdd, KIWIXMLStripData -> new($delFl);
	}
	my @profs = qw / profA timbuktu profB /;
	my $res = $xml -> addFilesToDelete(\@delFlsToAdd, \@profs);
	my $expected = "Attempting to add deletefiles to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addFilesToDeleteNoArgs
#------------------------------------------
sub test_addFilesToDeleteNoArgs {
	# ...
	# Verify addFilesToDelete behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addFilesToDelete();
	my $expected = 'addFilesToDelete: no deletefiles specified, nothing to do';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addFilesToDeleteToCurrentProf
#------------------------------------------
sub test_addFilesToDeleteToCurrentProf {
	# ...
	# Verify addFilesToDelete behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Set up the profile to which the drivers are to be added
	my @useProf = ('profA');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): profA';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	# Add the drivers, using no 2nd arg results in drivers to be added to
	# profA only
	my @delNames = qw /vboxsf epat dcdbas/;
	my @delFlsToAdd = ();
	for my $delFl (@delNames) {
		my %init = ( name => $delFl );
		push @delFlsToAdd, KIWIXMLStripData -> new(\%init);
	}
	$xml = $xml -> addFilesToDelete(\@delFlsToAdd);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defDelFls = qw (
		/usr/bin/zoo
		/lib/lsb/init-functions
		/usr/lib/libogg.so.0
	);
	my @expectedDel = @defDelFls;
	push @expectedDel, @delNames;
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expectedDel, '/usr/lib/sushi-start';
	} elsif ($arch eq 's390') {
		push @expectedDel, '/usr/lib/null_applet';
	}
	push @expectedDel, '/usr/lib/trashapplet';
	my @delFiles = @{$xml -> getFilesToDelete()};
	my @delNamesUsed = ();
	for my $delFl (@delFiles) {
		push @delNamesUsed, $delFl -> getName();
	}
	$this -> assert_array_equal(\@delNamesUsed, \@expectedDel);
	# Check that the drivers were not added anywhere else
	# reset the active profiles and we should only get the default drivers
	$xml = $xml -> setSelectionProfileNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	@delFiles = @{$xml -> getFilesToDelete()};
	@delNamesUsed = ();
	for my $delFl (@delFiles) {
		push @delNamesUsed, $delFl -> getName();
	}
	$this -> assert_array_equal(\@delNamesUsed, \@defDelFls);
	return;
}

#==========================================
# test_addFilesToDeleteToDefault
#------------------------------------------
sub test_addFilesToDeleteToDefault {
	# ...
	# Verify addFilesToDelete behaves as expected when the keyword
	# "default" is used as the second argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Add the drivers, using the keyword "default" as 2nd arg
	my @delNames = qw /vboxsf epat dcdbas/;
	my @delFlsToAdd = ();
	for my $delFl (@delNames) {
		my %init = ( name => $delFl );
		push @delFlsToAdd, KIWIXMLStripData -> new(\%init);
	}
	$xml = $xml -> addFilesToDelete(\@delFlsToAdd, 'default');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defDelFls = qw (
		/usr/bin/zoo
		/lib/lsb/init-functions
		/usr/lib/libogg.so.0
	);
	my @expectedDel = @defDelFls;
	push @expectedDel, @delNames;
	my @delFiles = @{$xml -> getFilesToDelete()};
	my @delNamesUsed = ();
	for my $delFl (@delFiles) {
		push @delNamesUsed, $delFl -> getName();
	}
	$this -> assert_array_equal(\@delNamesUsed, \@expectedDel);
	return;
}

#==========================================
# test_addFilesToDeleteWrongArgs
#------------------------------------------
sub test_addFilesToDeleteWrongArgs {
	# ...
	# Verify addFilesToDelete behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addFilesToDelete ('loop', 'default');
	my $expected = 'addFilesToDelete: expecting array ref for '
		. 'KIWIXMLStripData array as first argument';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addImagePackages_legacy
#------------------------------------------
sub test_addImagePackages_legacy {
	# ...
	# Verify proper operation of addImagePackages_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addImagePackages_legacy('perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /ed emacs kernel-default perl python vim/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @packages;
	IMGPCKG:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'image') {
			my @bootPckgsNodes = $node -> getElementsByTagName('package');
			for my $pckNode (@bootPckgsNodes) {
				push @packages, $pckNode -> getAttribute('name');
			}
			last IMGPCKG;
		}
	}
	$this -> assert_array_equal(\@expectedPcks, \@packages);
	return;
}

#==========================================
# test_addImagePatterns_legacy
#------------------------------------------
sub test_addImagePatterns_legacy {
	# ...
	# Verify proper operation of addImagePatterns method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addImagePatterns_legacy('gnome', 'kde');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPats = qw /base gnome kde xfce/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @patterns;
	IMGPATT:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'image') {
			my @imgPckgsNodes = $node ->
									getElementsByTagName('opensusePattern');
			for my $pckNode (@imgPckgsNodes) {
				push @patterns, $pckNode -> getAttribute('name');
			}
			last IMGPATT;
		}
	}
	$this -> assert_array_equal(\@expectedPats, \@patterns);
	return;
}

#==========================================
# test_addLibsToKeepImproperDataT
#------------------------------------------
sub test_addLibsToKeepImproperDataT {
	# ...
	# Verify addLibsToKeep behaves as expected, pass an array ref
	# containing a string
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @libNames = qw /libpng libtiff libgif/;
	my @libsToKeep = ();
	for my $libName (@libNames) {
		push @libsToKeep, KIWIXMLStripData -> new($libName);
	}
	push @libsToKeep, 'slip';
	push @libsToKeep, KIWIXMLStripData -> new('x25_asy');
	my $res = $xml -> addLibsToKeep(\@libsToKeep, 'default');
	my $expected = 'addLibsToKeep: found array item not of type '
		. 'KIWIXMLStripData in keeplibs array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addLibsToKeepInvalidProf
#------------------------------------------
sub test_addLibsToKeepInvalidProf {
	# ...
	# Verify addLibsToKeep behaves as expected, pass a profile name that
	# is not defined.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @libNames = qw /libcurl libmenu libz/;
	my @libsToKeep = ();
	for my $libName (@libNames) {
		push @libsToKeep, KIWIXMLStripData -> new($libName);
	}
	my @profs = qw / profA timbuktu profB /;
	my $res = $xml -> addLibsToKeep(\@libsToKeep, \@profs);
	my $expected = "Attempting to add keeplibs to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addLibsToKeepNoArgs
#------------------------------------------
sub test_addLibsToKeepNoArgs {
	# ...
	# Verify addLibsToKeep behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addLibsToKeep();
	my $expected = 'addLibsToKeep: no keeplibs specified, nothing to do';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addLibsToKeepToCurrentProf
#------------------------------------------
sub test_addLibsToKeepToCurrentProf {
	# ...
	# Verify addLibsToKeep behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Set up the profile to which the drivers are to be added
	my @useProf = ('profA');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): profA';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	# Add the drivers, using no 2nd arg results in drivers to be added to
	# profA only
	my @libNames = qw /libcurl libstdc++ libz /;
	my @libsToKeep = ();
	for my $libName (@libNames) {
		my %init = ( name => $libName );
		push @libsToKeep, KIWIXMLStripData -> new(\%init);
	}
	$xml = $xml -> addLibsToKeep(\@libsToKeep);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defLibNames = qw (
		libxml2.so
		libcrack.so
	);
	my @expectedLibs = @defLibNames;
	push @expectedLibs, @libNames;
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expectedLibs, 'libldap-2.4.so';
	} elsif ($arch eq 's390') {
		push @expectedLibs, 'virt-manager-launch';
	}
	push @expectedLibs, 'libjson.so';
	my @libs = @{$xml -> getLibsToKeep()};
	my @libNamesUsed = ();
	for my $lib (@libs) {
		push @libNamesUsed, $lib -> getName();
	}
	$this -> assert_array_equal(\@libNamesUsed, \@expectedLibs);
	# Check that the drivers were not added anywhere else
	# reset the active profiles and we should only get the default drivers
	$xml = $xml -> setSelectionProfileNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	@libs = @{$xml -> getLibsToKeep()};
	@libNamesUsed = ();
	for my $lib (@libs) {
		push @libNamesUsed, $lib -> getName();
	}
	$this -> assert_array_equal(\@libNamesUsed, \@defLibNames);
	return;
}

#==========================================
# test_addLibsToKeepToDefault
#------------------------------------------
sub test_addLibsToKeepToDefault {
	# ...
	# Verify addLibsToKeep behaves as expected when the keyword
	# "default" is used as the second argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Add the drivers, using the keyword "default" as 2nd arg
	my @libNames = qw /libpng libz/;
	my @libsToKeep = ();
	for my $libName (@libNames) {
		my %init = ( name => $libName );
		push @libsToKeep, KIWIXMLStripData -> new(\%init);
	}
	$xml = $xml -> addLibsToKeep(\@libsToKeep, 'default');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defLibNames = qw (
		libxml2.so
		libcrack.so
	);
	my @expectedLibs = @defLibNames;
	push @expectedLibs, @libNames;
	my @libs = @{$xml -> getLibsToKeep()};
	my @libNamesUsed = ();
	for my $lib (@libs) {
		push @libNamesUsed, $lib -> getName();
	}
	$this -> assert_array_equal(\@libNamesUsed, \@expectedLibs);
	return;
}

#==========================================
# test_addLibsToKeepWrongArgs
#------------------------------------------
sub test_addLibsToKeepWrongArgs {
	# ...
	# Verify addLibsToKeep behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addLibsToKeep ('loop', 'default');
	my $expected = 'addLibsToKeep: expecting array ref for '
		. 'KIWIXMLStripData array as first argument';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesBootstrap_legacy
#------------------------------------------
sub test_addPackagesBootstrap_legacy {
	# ...
	# Verify proper operation of addPackages_legacy method for bootstrap type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages_legacy('bootstrap', undef, undef,
									'perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /emacs filesystem glibc-locale perl/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @packages;
	BOOSTRPCKG:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'bootstrap') {
			my @bootPckgsNodes = $node -> getElementsByTagName('package');
			for my $pckNode (@bootPckgsNodes) {
				push @packages, $pckNode -> getAttribute('name');
			}
			last BOOSTRPCKG;
		}
	}
	$this -> assert_array_equal(\@expectedPcks, \@packages);
	return;
}

#==========================================
# test_addPackages
#------------------------------------------
sub test_addPackages {
	# ...
	# Verify addPackages method behavior
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @packagesToAdd;
	my %init = ( name => 'python');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'xemacs';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'vim';
	$init{arch} = 'ppc64';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	delete $init{arch};
	$init{name} = 'ed';
	$init{bootinclude} = 'true';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'utils';
	$init{bootdelete} = 'true';
	$init{bootinclude} = 'false';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my $res = $xml -> addPackages(\@packagesToAdd, 'default');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $packages = $xml -> getPackages();
	my @pckgNames;
	for my $collect (@{$packages}) {
		push @pckgNames, $collect -> getName();
	}
	my @expected = ( 'ed', 'kernel-default', 'python', 'xemacs', 'utils' );
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'vim';
	}
	$this -> assert_array_equal(\@expected, \@pckgNames);
	# Verify that the packages have been marked for boot inclusion as expected
	$packages = $xml -> getBootIncludePackages();
	my @bInclPckgNames;
	for my $pckg (@{$packages}) {
		push @bInclPckgNames, $pckg -> getName();
	}
	@expected = ( 'ed' );
	$this -> assert_array_equal(\@expected, \@bInclPckgNames);
	# Verify that the packages have been marked for boot deletion as expected
	$packages = $xml -> getBootDeletePackages();
	my @bDelPckgNames;
	for my $pckg (@{$packages}) {
		push @bDelPckgNames, $pckg -> getName();
	}
	@expected = ( 'utils' );
	$this -> assert_array_equal(\@expected, \@bDelPckgNames);
	return;
}

#==========================================
# test_addPackagesInvalidData
#------------------------------------------
sub test_addPackagesInvalidData {
	# ...
	# Verify addPackages properly errors on invalid data
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'libpng');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'k3b';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	push @packagesToAdd, 'foo';
	my $res = $xml-> addPackages(\@packagesToAdd);
	my $expected = 'addPackages: found array item not of type '
		. 'KIWIXMLPackageData in packages array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesInvalidDataTArg
#------------------------------------------
sub test_addPackagesInvalidDataTArg {
	# ...
	# Verify addPackages properly errors on invalid data type
	# for argument
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addPackages('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'addPackages: expecting array ref for '
		. 'KIWIXMLPackageData array as first argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesInvalidProf
#------------------------------------------
sub test_addPackagesInvalidProf {
	# ...
	# Verify addPackages properly errors when an undefined
	# profile is used
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'python');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'emacs';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my @profs = qw / aTest timbuktu /;
	my $res = $xml-> addPackages(\@packagesToAdd, \@profs);
	my $expected = "Attempting to add packages to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesNoArg
#------------------------------------------
sub test_addPackagesNoArg {
	# ...
	# Verify proper operation of addPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addPackages();
	my $msg = $kiwi -> getMessage();
	my $expected = 'addPackages: no packages specified, '
		. 'nothing to do';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_addPackagesToSpecProf
#------------------------------------------
sub test_addPackagesToSpecProf {
	#...
	# Verify addPackages method behavior ading archive to
	# specific profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'python');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'gzip';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'tar';
	$init{arch} = 'ppc64';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	delete $init{arch};
	$init{name} = 'ed';
	$init{bootinclude} = 'true';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'utils';
	$init{bootdelete} = 'true';
	$init{bootinclude} = 'false';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my @useProf = ('profA');
	my $res = $xml-> addPackages(\@packagesToAdd, \@useProf);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $packages = $xml -> getPackages();
	my @pckgNames;
	for my $pckg (@{$packages}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = ('kernel-default');
	$this -> assert_array_equal(\@expected, \@pckgNames);
	# Select the profile and verify the archive is in the proper loaction
	$xml = $xml -> setSelectionProfileNames(\@useProf);
# Clear the log
$state = $kiwi -> getState();
	$packages = $xml -> getPackages();
	my @profPckgNames;
	for my $pckg (@{$packages}) {
		push @profPckgNames, $pckg -> getName();
	}
	push @expected, 'ed';
	push @expected, 'libtiff';
	push @expected, 'python';
	push @expected, 'gzip';
	push @expected, 'utils';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'tar';
	}
	$this -> assert_array_equal(\@expected, \@profPckgNames);
	# Verify that the packages have been marked for boot inclusion as expected
	$packages = $xml -> getBootIncludePackages();
	my @bInclPckgNames;
	for my $pckg (@{$packages}) {
		push @bInclPckgNames, $pckg -> getName();
	}
	@expected = ( 'ed' );
	$this -> assert_array_equal(\@expected, \@bInclPckgNames);
	# Verify that the packages have been marked for boot deletion as expected
	$packages = $xml -> getBootDeletePackages();
	my @bDelPckgNames;
	for my $pckg (@{$packages}) {
		push @bDelPckgNames, $pckg -> getName();
	}
	@expected = ( 'utils' );
	$this -> assert_array_equal(\@expected, \@bDelPckgNames);
	return;
}

#==========================================
# test_addPackagesToSpecType
#------------------------------------------
sub test_addPackagesToSpecType {
	#...
	# Verify addPackageCollections method behavior ading archive to
	# specific image type
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'perl');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'postgresql';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'apache2';
	$init{arch} = 'ppc64';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	delete $init{arch};
	$init{name} = 'vi';
	$init{bootinclude} = 'true';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'utils';
	$init{bootdelete} = 'true';
	$init{bootinclude} = 'false';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my @useProf = ('profC');
	my $res = $xml-> addPackages(\@packagesToAdd,
										\@useProf,
										'iso'
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $packages = $xml -> getPackages();
	my @pckgNames;
	for my $archive (@{$packages}) {
		push @pckgNames, $archive -> getName();
	}
	my @expected = ('kernel-default');
	$this -> assert_array_equal(\@expected, \@pckgNames);
	# Select the profile but do not change the build type, thus we should
	# still get the default list
	$xml = $xml -> setSelectionProfileNames(\@useProf);
# Clear the log
$state = $kiwi -> getState();
	$packages = $xml -> getPackages();
	my @profPckgNames;
	for my $archive (@{$packages}) {
		push @profPckgNames, $archive -> getName();
	}
	$this -> assert_array_equal(\@expected, \@profPckgNames);
	# Change the build type and now we should get the added archives
	$xml = $xml -> setBuildType('iso');
	$packages = $xml -> getPackages();
	my @typePckgNames;
	for my $pckg (@{$packages}) {
		push @typePckgNames, $pckg -> getName();
	}
	push @expected, 'perl';
	push @expected, 'postgresql';
	push @expected, 'vi';
	push @expected, 'utils';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'apache2';
	}
	$this -> assert_array_equal(\@expected, \@typePckgNames);
	# Verify that the packages have been marked for boot inclusion as expected
	$packages = $xml -> getBootIncludePackages();
	my @bInclPckgNames;
	for my $pckg (@{$packages}) {
		push @bInclPckgNames, $pckg -> getName();
	}
	@expected = ( 'vi' );
	$this -> assert_array_equal(\@expected, \@bInclPckgNames);
	# Verify that the packages have been marked for boot deletion as expected
	$packages = $xml -> getBootDeletePackages();
	my @bDelPckgNames;
	for my $pckg (@{$packages}) {
		push @bDelPckgNames, $pckg -> getName();
	}
	@expected = ( 'utils' );
	$this -> assert_array_equal(\@expected, \@bDelPckgNames);
	return;
}

#==========================================
# test_addPackagesUndefinedType
#------------------------------------------
sub test_addPackagesUndefinedType {
	# ...
	# Verify addPackages properly errors when addtion to undefined image type
	# is attempted.
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'ksnapshot');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'inkscape';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my $res = $xml-> addPackages(
		\@packagesToAdd,
		'default',
		'vmx'
	);
	my $expected = 'addPackages: could not find specified type '
		. "'vmx' within the active profiles; packages not added.";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackageCollections
#------------------------------------------
sub test_addPackageCollections {
	# ...
	# Verify addPackageCollections method behavior
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @collectionsToAdd;
	my %init = ( name => 'fileserve');
	my $collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'printserve';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'lamp';
	$init{arch} = 'ppc64';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	my $res = $xml-> addPackageCollections(\@collectionsToAdd, 'default');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $collections = $xml -> getPackageCollections();
	my @collectNames;
	for my $collect (@{$collections}) {
		push @collectNames, $collect -> getName();
	}
	my @expected = ('base', 'fileserve', 'printserve');
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'lamp';
	}
	$this -> assert_array_equal(\@expected, \@collectNames);
	return;
}

#==========================================
# test_addPackageCollectionsInvalidData
#------------------------------------------
sub test_addPackageCollectionsInvalidData {
	# ...
	# Verify addPackageCollections properly errors on invalid data
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @collectionsToAdd;
	my %init = ( name => 'gnome');
	my $collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'lamp';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	push @collectionsToAdd, 'foo';
	my $res = $xml-> addPackageCollections(\@collectionsToAdd);
	my $expected = 'addPackageCollections: found array item not of type '
		. 'KIWIXMLPackageCollectData in collections array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackageCollectionsInvalidDataTArg
#------------------------------------------
sub test_addPackageCollectionsInvalidDataTArg {
	# ...
	# Verify addPackageCollections properly errors on invalid data type
	# for argument
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addPackageCollections('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'addPackageCollections: expecting array ref for '
		. 'KIWIXMLPackageCollectData array as first argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackageCollectionsInvalidProf
#------------------------------------------
sub test_addPackageCollectionsInvalidProf {
	# ...
	# Verify addPackageCollections properly errors when an undefined
	# profile is used
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @collectionsToAdd;
	my %init = ( name => 'devel_python');
	my $collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'apparmor';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	my @profs = qw / aTest timbuktu /;
	my $res = $xml-> addPackageCollections(\@collectionsToAdd, \@profs);
	my $expected = "Attempting to add collections to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackageCollectionsNoArg
#------------------------------------------
sub test_addPackageCollectionsNoArg {
	# ...
	# Verify proper operation of addPackageCollections method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addPackageCollections();
	my $msg = $kiwi -> getMessage();
	my $expected = 'addPackageCollections: no collections specified, '
		. 'nothing to do';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_addPackageCollectionsToSpecProf
#------------------------------------------
sub test_addPackageCollectionsToSpecProf {
	#...
	# Verify addPackageCollections method behavior ading archive to
	# specific profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @collectionsToAdd;
	my %init = ( name => 'python_devel');
	my $collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'lamp';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'console';
	$init{arch} = 'ppc64';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	my @useProf = ('profA');
	my $res = $xml-> addPackageCollections(\@collectionsToAdd, \@useProf);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $collections = $xml -> getPackageCollections();
	my @collectNames;
	for my $archive (@{$collections}) {
		push @collectNames, $archive -> getName();
	}
	my @expected = ('base');
	$this -> assert_array_equal(\@expected, \@collectNames);
	# Select the profile and verify the archive is in the proper loaction
	$xml = $xml -> setSelectionProfileNames(\@useProf);
# Clear the log
$state = $kiwi -> getState();
	$collections = $xml -> getPackageCollections();
	my @profCollectNames;
	for my $collect (@{$collections}) {
		push @profCollectNames, $collect -> getName();
	}
	push @expected, 'python_devel';
	push @expected, 'lamp';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'console';
	}
	$this -> assert_array_equal(\@expected, \@profCollectNames);
	return;
}

#==========================================
# test_addPackageCollectionsToSpecType
#------------------------------------------
sub test_addPackageCollectionsToSpecType {
	#...
	# Verify addPackageCollections method behavior ading archive to
	# specific image type
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @collectionsToAdd;
	my %init = ( name => 'devel_basis');
	my $collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'xfce';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'lamp';
	$init{arch} = 'ppc64';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	my @useProf = ('profC');
	my $res = $xml-> addPackageCollections(\@collectionsToAdd,
										\@useProf,
										'iso'
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $collections = $xml -> getPackageCollections();
	my @collectNames;
	for my $archive (@{$collections}) {
		push @collectNames, $archive -> getName();
	}
	my @expected = ('base');
	$this -> assert_array_equal(\@expected, \@collectNames);
	# Select the profile but do not change the build type, thus we should
	# still get the default list
	$xml = $xml -> setSelectionProfileNames(\@useProf);
# Clear the log
$state = $kiwi -> getState();
	$collections = $xml -> getPackageCollections();
	my @profCollectNames;
	for my $collect (@{$collections}) {
		push @profCollectNames, $collect -> getName();
	}
	$this -> assert_array_equal(\@expected, \@profCollectNames);
	# Change the build type and now we should get the added archives
	$xml = $xml -> setBuildType('iso');
	$collections = $xml -> getPackageCollections();
	my @typeArchiveNames;
	for my $collect (@{$collections}) {
		push @typeArchiveNames, $collect -> getName();
	}
	push @expected, 'devel_basis';
	push @expected, 'xfce';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'lamp';
	}
	$this -> assert_array_equal(\@expected, \@typeArchiveNames);
	return;
}

#==========================================
# test_addPackageCollectionsUndefinedType
#------------------------------------------
sub test_addPackageCollectionsUndefinedType {
	# ...
	# Verify addPackageCollections properly errors when addtion to
	# undefined image type is attempted.
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @collectionsToAdd;
	my %init = ( name => 'lamp');
	my $collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	$init{name} = 'devel-basis';
	$collectObj = KIWIXMLPackageCollectData -> new(\%init);
	push @collectionsToAdd, $collectObj;
	my $res = $xml-> addPackageCollections(
		\@collectionsToAdd,
		'default',
		'vmx'
	);
	my $expected = 'addPackageCollections: could not find specified type '
		. "'vmx' within the active profiles; collections not added.";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesToDelete
#------------------------------------------
sub test_addPackagesToDelete {
	# ...
	# Verify addPackagesToDelete method behavior
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'tar';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'powervm';
	$init{arch} = 'ppc64';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my $res = $xml-> addPackagesToDelete(\@packagesToAdd, 'default');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $packages = $xml -> getPackagesToDelete();
	my @pckgNames;
	for my $pckg (@{$packages}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = qw(
		cpio
		tar
	);
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'powervm';
	}
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_addPackagesToDeleteInvalidData
#------------------------------------------
sub test_addPackagesToDeleteInvalidData {
	# ...
	# Verify addPackagesToDelete properly errors on invalid data
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'gzip';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	push @packagesToAdd, 'foo';
	my $res = $xml-> addPackagesToDelete(\@packagesToAdd);
	my $expected = 'addPackagesToDelete: found array item not of type '
		. 'KIWIXMLPackageData in packages array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesToDeleteInvalidDataTArg
#------------------------------------------
sub test_addPackagesToDeleteInvalidDataTArg {
	# ...
	# Verify addPackagesToDelete properly errors on invalid data
	# type for argument
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addPackagesToDelete('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'addPackagesToDelete: expecting array ref for '
		. 'KIWIXMLPackageData array as first argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesToDeleteInvalidProf
#------------------------------------------
sub test_addPackagesToDeleteInvalidProf {
	# ...
	# Verify addPackagesToDelete properly errors when an undefined
	# profile is used
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'gzip';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my @profs = qw / aTest timbuktu /;
	my $res = $xml-> addPackagesToDelete(\@packagesToAdd, \@profs);
	my $expected = "Attempting to add packages to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addPackagesToDeleteNoArg
#------------------------------------------
sub test_addPackagesToDeleteNoArg {
	# ...
	# Verify proper operation of addPackagesToDelete method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml-> addPackagesToDelete();
	my $msg = $kiwi -> getMessage();
	my $expected = 'addPackagesToDelete: no packages specified, '
		. 'nothing to do';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_addPackagesToDeleteToSpecProf
#------------------------------------------
sub test_addPackagesToDeleteToSpecProf {
	#...
	# Verify addPackagesToDelete method behavior ading archive to
	# specific profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @packagesToAdd;
	my %init = ( name => 'cpio');
	my $pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'gzip';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	$init{name} = 'powervm';
	$init{arch} = 'ppc64';
	$pckgObj = KIWIXMLPackageData -> new(\%init);
	push @packagesToAdd, $pckgObj;
	my @useProf = ('profA');
	my $res = $xml-> addPackagesToDelete(\@packagesToAdd, \@useProf);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that the default has not changed
	my $packages = $xml -> getPackagesToDelete();
	my @pckgNames;
	for my $pckg (@{$packages}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = ('vim');
	$this -> assert_array_equal(\@expected, \@pckgNames);
	# Select the profile and verify the archive is in the proper loaction
	$xml = $xml -> setSelectionProfileNames(\@useProf);
# Clear the log
$state = $kiwi -> getState();
	$packages = $xml -> getPackagesToDelete();
	my @profPackageNames;
	for my $pckg (@{$packages}) {
		push @profPackageNames, $pckg -> getName();
	}
	push @expected, 'cpio';
	push @expected, 'emacs';
	push @expected, 'gzip';
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expected, 'powervm';
	}
	$this -> assert_array_equal(\@expected, \@profPackageNames);
	return;
}

#==========================================
# test_addPackagesImage_legacy
#------------------------------------------
sub test_addPackagesImage_legacy {
	# ...
	# Verify proper operation of addPackages_legacy method for image type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages_legacy('image', undef, undef, 'perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /ed emacs kernel-default perl python vim/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @packages;
	IMGPCKG:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'image') {
			my @bootPckgsNodes = $node -> getElementsByTagName('package');
			for my $pckNode (@bootPckgsNodes) {
				push @packages, $pckNode -> getAttribute('name');
			}
			last IMGPCKG;
		}
	}
	$this -> assert_array_equal(\@expectedPcks, \@packages);
	return;
}

#==========================================
# test_addPackagesImageBootIncl_legacy
#------------------------------------------
sub test_addPackagesImageBootIncl_legacy {
	# ...
	# Verify proper operation of addPackages_legacy method for image type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %bootInclPacks = ( emacs => 1 );
	$xml = $xml -> addPackages_legacy('image', \%bootInclPacks, undef,
									'perl','emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /ed emacs kernel-default perl python vim/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @packages;
	IMGPCKG:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'image') {
			my @bootPckgsNodes = $node -> getElementsByTagName('package');
			for my $pckNode (@bootPckgsNodes) {
				my $pckgName = $pckNode -> getAttribute('name');
				push @packages, $pckgName;
				if ($pckgName eq 'emacs') {
					$this -> assert_str_equals('true',
								$pckNode -> getAttribute('bootinclude'));
				}
			}
			last IMGPCKG;
		}
	}
	$this -> assert_array_equal(\@expectedPcks, \@packages);
	return;
}

#==========================================
# test_addPackagesNoBootstrap_legacy
#------------------------------------------
sub test_addPackagesNoBootstrap_legacy {
	# ...
	# Verify proper operation of addPackages_legacy method if not
	# bootstrap packages is defined
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsNoBootstrap';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages_legacy('bootstrap', undef, undef,
									'perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Failed to add perl emacs, package(s), no bootstrap '
		. 'section found';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	return;
}

#==========================================
# test_addPackagesNoImage_legacy
#------------------------------------------
sub test_addPackagesNoImage_legacy {
	# ...
	# Verify proper operation of addPackages_legacy method if not
	# image packages is defined
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsNoImage';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages_legacy('image', undef, undef, 'perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'addPackages: no image section found, adding to '
		.'bootstrap';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /emacs filesystem glibc-locale perl/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @packages;
	BOOSTRPCKG:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'bootstrap') {
			my @bootPckgsNodes = $node -> getElementsByTagName('package');
			for my $pckNode (@bootPckgsNodes) {
				push @packages, $pckNode -> getAttribute('name');
			}
			last BOOSTRPCKG;
		}
	}
	$this -> assert_array_equal(\@expectedPcks, \@packages);
	return;
}

#==========================================
# test_addPackagesUnknownType_legacy
#------------------------------------------
sub test_addPackagesUnknownType_legacy {
	# ...
	# Verify proper operation of addPackages_legacy method for bootstrap type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages_legacy('vmx', undef, undef, 'perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = "addPackages: no vmx section found... skipped\n";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_addPatterns_legacy
#------------------------------------------
sub test_addPatterns_legacy {
	# ...
	# Verify proper operation of addPatterns method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPatterns_legacy('image', undef, 'gnome', 'kde');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPats = qw /base gnome kde xfce/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @patterns;
	IMGPATT:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'image') {
			my @imgPckgsNodes = $node ->
									getElementsByTagName('opensusePattern');
			for my $pckNode (@imgPckgsNodes) {
				push @patterns, $pckNode -> getAttribute('name');
			}
			last IMGPATT;
		}
	}
	$this -> assert_array_equal(\@expectedPats, \@patterns);
	return;
}

#==========================================
# test_addRemovePackages_legacy
#------------------------------------------
sub test_addRemovePackages_legacy {
	# ...
	# Verify proper operation of addRemovePackages_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addRemovePackages_legacy('gnome-shell', 'cups');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedDel = qw /cups java gnome-shell/;
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @delPckgs;
	DELPACKGS:
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'delete') {
			my @delPckgsNodes = $node -> getElementsByTagName('package');
			for my $pckNode (@delPckgsNodes) {
				push @delPckgs, $pckNode -> getAttribute('name');
			}
			last DELPACKGS;
		}
	}
	$this -> assert_array_equal(\@expectedDel, \@delPckgs);
	return;
}

#==========================================
# test_addRepositoriesDefault
#------------------------------------------
sub test_addRepositoriesDefault {
	# ...
	# Verify proper operation of addRepositories method
	# existing repo alias
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	my $res = $xml -> addRepositories(\@reposToAdd, 'default');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Verify the non conflicting repo got added
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(2, $numRepos);
	for my $repo (@repoData) {
		my $path = $repo -> getPath();
		if ($path ne '/tmp/12.1/repo/oss/' &&
			$path ne '/work/repos/md') {
			$this -> assert_str_equals('No path match', $path);
		}
	}
	# Verify that the repo added as default also is used in other profiles
	my @profs = ('profB');
	$xml -> setSelectionProfileNames(\@profs);
	my $expected = 'Using profile(s): profB';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	@repoData = @{$xml -> getRepositories()};
	$numRepos = @repoData;
	$this -> assert_equals(3, $numRepos);
	my $found;
	for my $repo (@repoData) {
		my $path = $repo -> getPath();
		if ($path eq '/work/repos/md') {
			$found = 1;
			last;
		}
	}
	if (! $found) {
		$this -> assert_str_equals('repo not found',  '/work/repos/md');
	}
	return;
}

#==========================================
# test_addRepositoriesExistAlias
#------------------------------------------
sub test_addRepositoriesExistAlias {
	# ...
	# Verify proper operation of addRepositories method, add repo with
	# existing repo alias
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %dupAliasData = ( alias => 'update',
						path  => 'http://download.opensuse.org/update/12.2',
						type  => 'rpm-md'
					);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%dupAliasData);
	my @profs = ('profA');
	my $res = $xml -> addRepositories(\@reposToAdd, \@profs);
	my $expected = 'addRepositories: attempting to add repo, but a repo '
		. 'with same alias already exists';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	# Verify the non conflicting repo got added
	$xml -> setSelectionProfileNames(\@profs);
	$expected = 'Using profile(s): profA';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(4, $numRepos);
	return;
}

#==========================================
# test_addRepositoriesExistPass
#------------------------------------------
sub test_addRepositoriesExistPass {
	# ...
	# Verify proper operation of addRepositories method, add repo with
	# conflicting password
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %confPass = ( password => 'foo',
					path     => '/work/repos/pckgs',
					type     => 'rpm-dir',
					username => 'foo'
				);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%confPass);
	my @profs = ('profB');
	my $res = $xml -> addRepositories(\@reposToAdd, \@profs);
	my $expected = 'addRepositories: attempting to add repo, but a repo '
		. 'with a different password already exists';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	# Verify the non conflicting repo got added
	$xml -> setSelectionProfileNames(\@profs);
	$expected = 'Using profile(s): profB';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(3, $numRepos);
	return;
}

#==========================================
# test_addRepositoriesExistPath
#------------------------------------------
sub test_addRepositoriesExist {
	# ...
	# Verify proper operation of addRepositories method, pass a profile
	# name that is not defined.
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	my %init2 = (
				path => '/tmp/12.1/repo/oss/',
				type => 'rpm-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init2);
	my $res = $xml -> addRepositories(\@reposToAdd, 'default');
	my $expected = 'addRepositories: attempting to add repo, but a repo '
		. 'with same path already exists';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	# Verify the non conflicting repo got added
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(2, $numRepos);
	return;
}

#==========================================
# test_addRepositoriesExistPrefLic
#------------------------------------------
sub test_addRepositoriesExistPrefLic {
	# ...
	# Verify proper operation of addRepositories method, add repo
	# when existing repo has prefer-license set
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %prefLic = ( path          => '/work/repos/pckgs',
					preferlicense => 'true',
					type          => 'rpm-dir'
				);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%prefLic);
	my $res = $xml -> addRepositories(\@reposToAdd, 'default');
	my $expected = 'addRepositories: attempting to add repo, but a repo '
		. 'with license preference indicator set already exists';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	# Verify the non conflicting repo got added
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(2, $numRepos);
	return;
}

#==========================================
# test_addRepositoriesExistUsr
#------------------------------------------
sub test_addRepositoriesExistUsr {
	# ...
	# Verify proper operation of addRepositories method, add repo with
	# conflicting username
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %confUser = ( password => 'bar',
					path     => '/work/repos/pckgs',
					type     => 'rpm-dir',
					username => 'bar'
				);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%confUser);
	my @profs = ('profB');
	my $res = $xml -> addRepositories(\@reposToAdd, \@profs);
	my $expected = 'addRepositories: attempting to add repo, but a repo '
		. 'with a different username already exists';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	# Verify the non conflicting repo got added
	$xml -> setSelectionProfileNames(\@profs);
	$expected = 'Using profile(s): profB';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(3, $numRepos);
	return;
}

#==========================================
# test_addRepositoriesImproperDataT
#------------------------------------------
sub test_addRepositoriesImproperDataT {
	# ...
	# Verify addRepositories behaves as expected, pass an array ref containing
	# a string
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	my %init2 = (
				path => '/work/repos/pckgs',
				type => 'rpm-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init2);
	push @reposToAdd, 'slip';
	my %init3 = (
				path => '/work/repos/debs',
				type => 'deb-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init3);
	my $res = $xml -> addRepositories(\@reposToAdd, 'default');
	my $expected = 'addRepositories: found array item not of type '
		. 'KIWIXMLRepositoryData in repository array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addRepositoriesInvalidProf
#------------------------------------------
sub test_addRepositoriesInvalidProf {
	# ...
	# Verify proper operation of addRepositories method, pass a profile
	# name that is not defined.
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	my %init2 = (
				path => '/work/repos/pckgs',
				type => 'rpm-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init2);
	my %init3 = (
				path => '/work/repos/debs',
				type => 'deb-dir'
	);
	my @profs = qw \profA timbuktu profB\;
	my $res = $xml -> addRepositories(\@reposToAdd, \@profs);
	my $expected = "Attempting to add repositorie(s) to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addRepositoriesNoArgs
#------------------------------------------
sub test_addRepositoriesNoArgs {
	# ...
	# Verify proper operation of addRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addRepositories();
	my $expected = 'addRepositories: no repos specified, nothing to do';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_addRepositoriesToProf
#------------------------------------------
sub test_addRepositoriesToProf {
	# ...
	# Verify  proper operation of addRepositories method, adding repo
	# to active profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new(\%init);
	my @profs = ('profC');
	my $res = $xml -> addRepositories(\@reposToAdd, \@profs);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify the repo got added to the proper profile
	$xml -> setSelectionProfileNames(\@profs);
	my $expected = 'Using profile(s): profC';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(3, $numRepos);
	my $found;
	for my $repo (@repoData) {
		my $path = $repo -> getPath();
		if ($path eq '/work/repos/md') {
			$found = 1;
			last;
		}
	}
	if (! $found) {
		$this -> assert_str_equals('repo not found',  '/work/repos/md');
	}
	# Verify the repo is not available in any other profile
	@profs = ('profA');
	$xml -> setSelectionProfileNames(\@profs);
	$expected = 'Using profile(s): profA';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	@repoData = @{$xml -> getRepositories()};
	$numRepos = @repoData;
	$this -> assert_equals(3, $numRepos);
	return;
}

#==========================================
# test_addRepositoriesWrongArgs
#------------------------------------------
sub test_addRepositoriesWrongArgs {
	# ...
	# Verify  proper operation of addRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addRepositories('opensuse:///', 'profA');
	my $expected = 'addRepositories: expecting array ref for '
		. 'KIWIXMLRepositoryData array as first argument';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addRepositories_legacy
#------------------------------------------
sub test_addRepositories_legacy {
	# ...
	# Verify proper operation of addRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @addedTypes = qw /red-carpet urpmi/;
	my @Locs= ['/repos/rc/12.1', 'http://otherpublicrepos/12.1'];
	my @Alia= qw /rc pubrepo/;
	my @Prios= qw /13 99/;
	my @Usr= qw /pablo/;
	my @Pass= qw /ola/;
	$xml = $xml -> addRepositories_legacy(\@addedTypes, @Locs,\@Alia,
								\@Prios,\@Usr, \@Pass);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my %repos = $xml -> getRepositories_legacy();
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
	my @repoInfo = @{$repos{'/tmp/12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-4]);
	@repoInfo = @{$repos{'https://myreposerver/protectedrepos/12.1'}};
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
	return;
}

#==========================================
# test_addRepositoriesInvalidTypeInf_legacy
#------------------------------------------
sub test_addRepositoriesInvalidTypeInf_legacy {
	# ...
	# Verify proper operation of addRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @addedTypes = qw /red-carpet ola/;
	my @Locs= ['/repos/rc/12.1', 'http://otherpublicrepos/12.1'];
	my @Alia= qw /rc pubrepo/;
	my @Prios= qw /13 99/;
	my @Usr= qw /pablo/;
	my @Pass= qw /ola/;
	$xml = $xml -> addRepositories_legacy(\@addedTypes, @Locs,\@Alia,
								\@Prios,\@Usr, \@Pass);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Addition of requested repo type [ola] not supported';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	my %repos = $xml -> getRepositories_legacy();
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
	my @repoInfo = @{$repos{'/tmp/12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-4]);
	@repoInfo = @{$repos{'https://myreposerver/protectedrepos/12.1'}};
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
	return;
}

#==========================================
# test_addRepositoriesNoTypeInf_legacy
#------------------------------------------
sub test_addRepositoriesNoTypeInf_legacy {
	# ...
	# Verify proper operation of addRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @addedTypes = qw /red-carpet/;
	my @Locs= ['/repos/rc/12.1', 'http://otherpublicrepos/12.1'];
	my @Alia= qw /rc pubrepo/;
	my @Prios= qw /13 99/;
	my @Usr= qw /pablo/;
	my @Pass= qw /ola/;
	$xml = $xml -> addRepositories_legacy(\@addedTypes, @Locs,\@Alia,
								\@Prios,\@Usr, \@Pass);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'No type for repo [http://otherpublicrepos/12.1] '
		. 'specified';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	my %repos = $xml -> getRepositories_legacy();
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
	my @repoInfo = @{$repos{'/tmp/12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-4]);
	@repoInfo = @{$repos{'https://myreposerver/protectedrepos/12.1'}};
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
	return;
}

#==========================================
# test_addStripConsistentCall_legacy
#------------------------------------------
sub test_addStripConsistentCall_legacy {
	# ...
	# Verify proper operation of addStrip method with improper argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @Del= qw (/etc/hosts /bin/zsh);
	$xml -> __addStrip_legacy ('files', @Del);
	my @delFiles = $xml -> __getStripDelete_legacy();
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
	return;
}

#==========================================
# test_addStripDelete_legacy
#------------------------------------------
sub test_addStripDelete_legacy {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @Del= qw (/etc/hosts /bin/zsh);
	$xml -> __addStrip_legacy ('delete', @Del);
	my @delFiles = $xml -> __getStripDelete_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw (/etc/resolv.conf /lib/libc.so /etc/hosts /bin/zsh);
	$this -> assert_array_equal(\@expectedNames, \@delFiles);
	return;
}

#==========================================
# test_addStripDeleteNoPreExist_legacy
#------------------------------------------
sub test_addStripDeleteNoPreExist_legacy {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @Del= qw (/etc/hosts /bin/zsh);
	$xml -> __addStrip_legacy ('delete', @Del);
	my @delFiles = $xml -> __getStripDelete_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw (/etc/hosts /bin/zsh);
	$this -> assert_array_equal(\@expectedNames, \@delFiles);
	return;
}

#==========================================
# test_addStripLibs_legacy
#------------------------------------------
sub test_addStripLibs_legacy {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @Libs= qw /libm libcrypt/;
	$xml -> __addStrip_legacy ('libs', @Libs);
	my @libFiles = $xml -> __getStripLibs_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /libdbus libnss libm libcrypt/;
	$this -> assert_array_equal(\@expectedNames, \@libFiles);
	return;
}

#==========================================
# test_addStripTools_legacy
#------------------------------------------
sub test_addStripTools_legacy {
	# ...
	# Verify proper operation of addStrip method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @Tools= qw /xfsrestore install-info/;
	$xml -> __addStrip_legacy('tools', @Tools);
	my @toolFiles = $xml -> __getStripTools_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /megacli virt-mgr xfsrestore install-info/;
	$this -> assert_array_equal(\@expectedNames, \@toolFiles);
	return;
}

#==========================================
# test_addToolsToKeepImproperDataT
#------------------------------------------
sub test_addToolsToKeepImproperDataT {
	# ...
	# Verify addToolsToKeep behaves as expected, pass an array ref
	# containing a string
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @toolNames = qw /libpng libtiff libgif/;
	my @toolsToKeep = ();
	for my $toolName (@toolNames) {
		push @toolsToKeep, KIWIXMLStripData -> new($toolName);
	}
	push @toolsToKeep, 'slip';
	push @toolsToKeep, KIWIXMLStripData -> new('x25_asy');
	my $res = $xml -> addToolsToKeep(\@toolsToKeep, 'default');
	my $expected = 'addToolsToKeep: found array item not of type '
		. 'KIWIXMLStripData in tools array';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addToolsToKeepInvalidProf
#------------------------------------------
sub test_addToolsToKeepInvalidProf {
	# ...
	# Verify addToolsToKeep behaves as expected, pass a profile name that
	# is not defined.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @toolNames = qw /libcurl libmenu libz/;
	my @toolsToKeep = ();
	for my $toolName (@toolNames) {
		push @toolsToKeep, KIWIXMLStripData -> new($toolName);
	}
	my @profs = qw / profA timbuktu profB /;
	my $res = $xml -> addToolsToKeep(\@toolsToKeep, \@profs);
	my $expected = "Attempting to add tools to 'timbuktu', but "
		. 'this profile is not specified in the configuration.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addToolsToKeepNoArgs
#------------------------------------------
sub test_addToolsToKeepNoArgs {
	# ...
	# Verify addToolsToKeep behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addToolsToKeep();
	my $expected = 'addToolsToKeep: no tools specified, nothing to do';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_addToolsToKeepToCurrentProf
#------------------------------------------
sub test_addToolsToKeepToCurrentProf {
	# ...
	# Verify addToolsToKeep behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Set up the profile to which the drivers are to be added
	my @useProf = ('profA');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): profA';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	# Add the drivers, using no 2nd arg results in drivers to be added to
	# profA only
	my @toolNames = qw /more cat sed /;
	my @toolsToKeep = ();
	for my $toolName (@toolNames) {
		my %init = ( name => $toolName );
		push @toolsToKeep, KIWIXMLStripData -> new(\%init);
	}
	$xml = $xml -> addToolsToKeep(\@toolsToKeep);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defToolNames = qw (
		megacli
	ping 
	);
	my @expectedTools = @defToolNames;
	push @expectedTools, @toolNames;
	my $arch = $xml -> getArch();
	if ($arch eq 'ppc64') {
		push @expectedTools, 'traceroute';
	} elsif ($arch eq 's390') {
		push @expectedTools, 'wireshark';
	}
	push @expectedTools, 'cp';
	my @tools = @{$xml -> getToolsToKeep()};
	my @toolNamesUsed = ();
	for my $tool (@tools) {
		push @toolNamesUsed, $tool -> getName();
	}
	$this -> assert_array_equal(\@toolNamesUsed, \@expectedTools);
	# Check that the drivers were not added anywhere else
	# reset the active profiles and we should only get the default drivers
	$xml = $xml -> setSelectionProfileNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	@tools = @{$xml -> getToolsToKeep()};
	@toolNamesUsed = ();
	for my $tool (@tools) {
		push @toolNamesUsed, $tool -> getName();
	}
	$this -> assert_array_equal(\@toolNamesUsed, \@defToolNames);
	return;
}

#==========================================
# test_addToolsToKeepToDefault
#------------------------------------------
sub test_addToolsToKeepToDefault {
	# ...
	# Verify addToolsToKeep behaves as expected when the keyword
	# "default" is used as the second argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Add the drivers, using the keyword "default" as 2nd arg
	my @toolNames = qw /awk less/;
	my @toolsToKeep = ();
	for my $toolName (@toolNames) {
		my %init = ( name => $toolName );
		push @toolsToKeep, KIWIXMLStripData -> new(\%init);
	}
	$xml = $xml -> addToolsToKeep(\@toolsToKeep, 'default');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	# Verify this has the expected results, we should get the default drivers
	# plus the arch specific profile drivers plus the ones added
	my @defToolNames = qw (
		megacli
		ping
	);
	my @expectedTools = @defToolNames;
	push @expectedTools, @toolNames;
	my @tools = @{$xml -> getToolsToKeep()};
	my @toolNamesUsed = ();
	for my $tool (@tools) {
		push @toolNamesUsed, $tool -> getName();
	}
	$this -> assert_array_equal(\@toolNamesUsed, \@expectedTools);
	return;
}

#==========================================
# test_addToolsToKeepWrongArgs
#------------------------------------------
sub test_addToolsToKeepWrongArgs {
	# ...
	# Verify addToolsToKeep behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripWithProfAndArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addToolsToKeep ('loop', 'default');
	my $expected = 'addToolsToKeep: expecting array ref for '
		. 'KIWIXMLStripData array as first argument';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_ctor_InvalidPXEConfigArch
#------------------------------------------
sub test_ctor_InvalidPXEConfigArch {
	# ...
	# Test the construction of the XML object with an invalid architecture
	# setting for the pxe configuration
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettingsInvArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Unsupported arch 'armv95' in PXE setup.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($xml);
	return;
}

#==========================================
# test_ctor_InvalidSplitArch
#------------------------------------------
sub test_ctor_InvalidSplitArch {
	# ...
	# Test the construction of the XML object with an invalid architecture
	# setting for a file in the split definition
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettingsInvArch';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Unsupported arch 'arm95' in split setup";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($xml);
	return;
}
#==========================================
# test_ctor_InvalidSysdiskVolNameDisallowed
#------------------------------------------
sub test_ctor_InvalidSysdiskVolNameDisallowed {
	# ...
	# Test the construction of the XML object with an invalid name setting
	# for one of the volume definitions.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfigDisallowedDir';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Invalid name 'sbin' for LVM volume setup";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($xml);
	return;
}

#==========================================
# test_ctor_InvalidSysdiskVolNameRoot
#------------------------------------------
sub test_ctor_InvalidSysdiskVolNameRoot {
	# ...
	# Test the construction of the XML object with an invalid name setting
	# for one of the volume definitions.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfigWithRoot';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Invalid name '/' for LVM volume setup";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($xml);
	return;
}

#==========================================
# test_ctor_TwoPrimaryMarkedtypes
#------------------------------------------
sub test_ctor_TwoPrimaryMarkedtypes {
	# ...
	# Test the construction of the XML object with a configuration that has
	# 2 types marked as primary, but both profiles are being built.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettingsTwoPrimary';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Processing more than one type marked as '
		. '"primary", cannot resolve build type.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($xml);
	return;
}

#==========================================
# test_ctor_NoTypeDefaultPref
#------------------------------------------
sub test_ctor_NoTypeDefaultPref {
	# ...
	# Test the construction of the XML object with a configuration that has
	# no type specified for the default prefrences.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettingsNoTypeDefPref';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $type = $xml -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($type);
	my $imageT = $type -> getImageType();
	$this -> assert_str_equals('oem', $imageT);
	return;
}

#==========================================
# test_getActiveProfileNames
#------------------------------------------
sub test_getActiveProfileNames {
	# ...
	# Verify the the names returned by the getActiveProfileNames method are
	# correct.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $profNames = $xml -> getActiveProfileNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = ('profB');
	$this -> assert_array_equal(\@expected, $profNames);
	return;
}

#==========================================
# test_getArchives
#------------------------------------------
sub test_getArchives {
	# ...
	# Verify proper return of getArchives method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $archives = $xml -> getArchives();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @archiveNames;
	for my $archive (@{$archives}) {
		push @archiveNames, $archive -> getName();
	}
	my @expected = qw(
		myImageStuff.tgz
		myInitStuff.tar
		myOEMstuffProf.tar.bz2
	);
	$this -> assert_array_equal(\@expected, \@archiveNames);
	return;
}

#==========================================
# test_getArchiveList_legacy
#------------------------------------------
sub test_getArchiveList_legacy {
	# ...
	# Verify proper return of getArchiveList_legacy method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Note there is a bug in the legacy implementation, it will not return
	# archive entries that are type specific
	# Will not be fixed as the new implementation addresses the issue
	my @archives = $xml -> getArchiveList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw / myInitStuff.tar myImageStuff.tgz /;
	$this -> assert_array_equal(\@expected, \@archives);
	return;
}

#==========================================
# test_getArchiveListUseProf_legacy
#------------------------------------------
sub test_getArchiveListUseProf_legacy {
	# ...
	# Verify proper return of getArchiveList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$confDir, undef, \@patterns, $this->{cmdL}
	);
	# Note there is a bug in the legacy implementation, it will not return
	# archive entries that are type specific
	# Will not be fixed as the new implementation addresses the issue
	my @archives = $xml -> getArchiveList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my @expected = qw / myAppArch.tgz myInitStuff.tar myImageStuff.tgz /;
	$this -> assert_array_equal(\@expected, \@archives);
	return;
}

#==========================================
# test_getArchivesUseProf
#------------------------------------------
sub test_getArchivesUseProf {
	# ...
	# Verify proper return of getArchives method with a selected build
	# profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my @useProf = ('aTest');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): aTest';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $archives = $xml -> getArchives();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @archiveNames;
	for my $archive (@{$archives}) {
		push @archiveNames, $archive -> getName();
	}
	my @expected = qw(
		myAppArch.tgz
		myImageStuff.tgz
		myInitStuff.tar
		myOEMstuffProf.tar.bz2
		myOEMstuffProf.tar.bz2
	);
	$this -> assert_array_equal(\@expected, \@archiveNames);
	return;
}

#==========================================
# test_getBaseList_legacy
#------------------------------------------
sub test_getBaseList_legacy {
	# ...
	# Verify proper return of getBaseList_legacy method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @basePcks = $xml -> getBaseList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /filesystem glibc-locale/;
	$this -> assert_array_equal(\@expected, \@basePcks);
	return;
}

#==========================================
# test_getBootDeletePackages
#------------------------------------------
sub test_getBootDeletePackages {
	# ...
	# Verify proper return of getBootDeletePackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $bDelPckgs = $xml -> getBootDeletePackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$bDelPckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = ( 'python' );
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getBootIncludeArchives
#------------------------------------------
sub test_getBootIncludeArchives {
	# ...
	# Verify proper return of getArchives method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $archives = $xml -> getBootIncludeArchives();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @archiveNames;
	for my $archive (@{$archives}) {
		push @archiveNames, $archive -> getName();
	}
	my @expected = ('myInitStuff.tar');
	$this -> assert_array_equal(\@expected, \@archiveNames);
	return;
}

#==========================================
# test_getBootIncludePackages
#------------------------------------------
sub test_getBootIncludePackages {
	# ...
	# Verify proper return of getBootIncludePackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $bInclPckgs = $xml -> getBootIncludePackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$bInclPckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = qw(
		python
		vim
	);
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getBootIncludePackagesUseProf
#------------------------------------------
sub test_getBootIncludePackagesUseProf {
	# ...
	# Verify proper return of getBootIncludePackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @useProf = ('aTest');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): aTest';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $bInclPckgs = $xml -> getBootIncludePackages();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$bInclPckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = qw(
		perl
		python
		vim
	);
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getBootIncludes_legacy
#------------------------------------------
sub test_getBootIncludes_legacy {
	# ...
	# Verify proper return of getBootIncludes_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @bootInclP = $xml -> getBootIncludes_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /python vim/;
	$this -> assert_array_equal(\@expected, \@bootInclP);
	return;
}

#==========================================
# test_getBootIncludesUseProf_legacy
#------------------------------------------
sub test_getBootIncludesUseProf_legacy{
	# ...
	# Verify proper return of getBootIncludes_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$confDir, undef, \@patterns, $this->{cmdL}
	);
	my @bootInclP = $xml -> getBootIncludes_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /perl python vim/;
	$this -> assert_array_equal(\@expected, \@bootInclP);
	return;
}

#==========================================
# test_getBootstrapPackages
#------------------------------------------
sub test_getBootstrapPackages {
	# ...
	# Verify proper return of test_getBootstrapPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $pckgs = $xml -> getBootstrapPackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$pckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = ('filesystem', 'glibc-locale');
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getBootTheme_legacy
#------------------------------------------
sub test_getBootTheme_legacy {
	# ...
	# Verify proper return of getBootTheme_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @values = $xml -> getBootTheme_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @themes = qw /bluestar silverlining/;
	$this -> assert_array_equal(\@themes, \@values);
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
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
	return;
}

#==========================================
# test_getConfiguredTypeNames
#------------------------------------------
sub test_getConfiguredTypeNames {
	# ...
	# Test the getConfiguredTypeNames method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $typeNames = $xml -> getConfiguredTypeNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ( 'oem', 'vmx' );
	$this -> assert_array_equal(\@expected, $typeNames);
	return;
}

#==========================================
# test_getDefaultPrebuiltDir_legacy
#------------------------------------------
sub test_getDefaultPrebuiltDir_legacy {
	# ...
	# Verify proper return of getDefaultPrebuiltDir_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getDefaultPrebuiltDir_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/work/kiwibootimgs', $value);
	return;
}

#==========================================
# test_getDeleteList_legacy
#------------------------------------------
sub test_getDeleteList_legacy {
	# ...
	# Verify proper return of getDeleteList_legacy method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @delPcks = $xml -> getDeleteList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /java/;
	$this -> assert_array_equal(\@expected, \@delPcks);
	return;
}

#==========================================
# test_getDeleteListUseProf_legacy
#------------------------------------------
sub test_getDeleteListUseProf_legacy {
	# ...
	# Verify proper return of getDeleteList_legacy method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$confDir, undef, \@patterns, $this->{cmdL}
	);
	my @delPcks = $xml -> getDeleteList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /java libreOffice/;
	$this -> assert_array_equal(\@expected, \@delPcks);
	return;
}

#==========================================
# test_getDeleteListInstallDelete_legacy
#------------------------------------------
sub test_getDeleteListInstallDelete {
	# ...
	# Verify proper return of getDeleteList_legacy method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsInstallDelete';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @delPcks = $xml -> getDeleteList_legacy();
	my $msg = $kiwi -> getLogInfoMessage();
	my $expectedMsg = "WARNING: package java ignored in delete list\n";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null(@delPcks);
	return;
}

#==========================================
# test_getDescriptionInfo
#------------------------------------------
sub test_getDescriptionInfo {
	# ...
	# Verify the proper return of getDescriptionInfo methof
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'descriptData';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my $descrpObj = $xml -> getDescriptionInfo();
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $author = $descrpObj -> getAuthor();
	$this -> assert_str_equals('Robert Schweikert', $author);
	my $contact = $descrpObj -> getContactInfo();
	my @expectCont = ('rjschwei@suse.com', 'rschweikert@suse.com');
	$this -> assert_array_equal(\@expectCont, $contact);
	my $spec = $descrpObj -> getSpecificationDescript();
	my $expected = 'Verify proper handling of description in XML obj';
	$this -> assert_str_equals($expected, $spec);
	my $type = $descrpObj -> getType();
	$this -> assert_str_equals('system', $type);
	return;
}

#==========================================
# test_getDrivers
#------------------------------------------
sub test_getDrivers {
	# ...
	# Verify proper return of getDrivers method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @drivers = @{$xml -> getDrivers()};
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expectedDrivers = qw /usb e1000 rs232/;
	my @confDrivers;
	for my $drvData (@drivers) {
		push @confDrivers, $drvData -> getName();
	}
	$this -> assert_array_equal(\@expectedDrivers, \@confDrivers);
	return;
}

#==========================================
# test_getDriversNodeList_legacy
#------------------------------------------
sub test_getDriversNodeList_legacy {
	# ...
	# Verify proper return of getDriversNodeList method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @driversNodes = $xml -> getDriversNodeList_legacy() -> get_nodelist();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedDrivers = qw /usb e1000 rs232/;
	my @confDrivers;
	for my $node (@driversNodes) {
		my @files = $node -> getElementsByTagName ("file");
		for my $element (@files) {
			my $name = $element -> getAttribute ("name");
			push (@confDrivers, $name);
		}
	}
	$this -> assert_array_equal(\@expectedDrivers, \@confDrivers);
	return;
}

#==========================================
# test_getDUDArchitectures
#------------------------------------------
sub test_getDUDArchitectures {
	# ...
	# Verify proper return of getDUDArchitectures method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $dudArches = $xml -> getDUDArchitectures();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($dudArches);
	my @expected = qw (i586 i686);
	$this -> assert_array_equal(\@expected, $dudArches);
	return;
}

#==========================================
# test_getDUDInstallSystemPackages
#------------------------------------------
sub test_getDUDInstallSystemPackages {
	# ...
	# Verify proper return of getDUDInstallSystemPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $iSysPkgs = $xml -> getDUDInstallSystemPackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($iSysPkgs);
	my @expected = qw (dudsetup yast);
	my @names;
	for my $repo (@{$iSysPkgs}) {
		push @names, $repo -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getDUDModulePackages
#------------------------------------------
sub test_getDUDModulePackages {
	# ...
	# Verify proper return of getDUDModulePackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $mPkgs = $xml -> getDUDModulePackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($mPkgs);
	my @expected = qw (weirdDrive_KMP weirdNet_KMP);
	my @names;
	for my $pkg (@{$mPkgs}) {
		push @names, $pkg -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getDUDPackages
#------------------------------------------
sub test_getDUPackages {
	# ...
	# Verify proper return of getDUDPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $pkgs = $xml -> getDUDPackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($pkgs);
	my @expected = qw (specialNetDriver-KMP specialRaidDriver-KMP);
	my @names;
	for my $pkg (@{$pkgs}) {
		push @names, $pkg -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getEC2Config
#------------------------------------------
sub test_getEC2Config {
	# ...
	# Verify proper return of EC2 configuration settings
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'ec2ConfigSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $ec2ConfObj = $xml -> getEC2Config();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $acctNr = $ec2ConfObj -> getAccountNumber();
	$this -> assert_str_equals('12345678911', $acctNr);
	my $regions = $ec2ConfObj -> getRegions();
	my @expectedRegions = qw / EU-West US-West /;
	$this -> assert_array_equal(\@expectedRegions, $regions);
	return;
}

#==========================================
# test_getEditBootConfig_legacy
#------------------------------------------
sub test_getEditBootConfig_legacy {
	# ...
	# Verify proper return of getEditBootConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $path = $xml -> getEditBootConfig_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my $fileName = (split /\//, $path)[-1];
	$this -> assert_str_equals('fixupBootEnter', $fileName);
	return;
}

#==========================================
# test_getFilesToDelete
#------------------------------------------
sub test_getFilesToDelete {
	# ...
	# Verify proper return of getFilesToDelete method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $delFiles = $xml -> getFilesToDelete();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = qw (/etc/resolv.conf /lib/libc.so);
	my @stripNames = ();
	for my $stripObj (@{$delFiles}) {
		push @stripNames, $stripObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@stripNames);
	return;
}

#==========================================
# test_getHttpsRepositoryCredentials_legacy
#------------------------------------------
sub test_getHttpsRepositoryCredentials_legacy {
	# ...
	# Verify proper return of getHttpsRepositoryCredentials method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my ($uname, $pass) = $xml->getHttpsRepositoryCredentials_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	$this -> assert_str_equals('foo', $uname);
	$this -> assert_str_equals('bar', $pass);
	return;
}

#==========================================
# test_getImageDefaultDestination_legacy
#------------------------------------------
sub test_getImageDefaultDestination_legacy {
	# ...
	# Verify proper return of getImageDefaultDestination_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageDefaultDestination_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/work/tmp', $value);
	return;
}

#==========================================
# test_getImageDefaultRoot_legacy
#------------------------------------------
sub test_getImageDefaultRoot_legacy {
	# ...
	# Verify proper return of getImageDefaultRoot_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageDefaultRoot_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/var/tmp', $value);
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
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
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
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
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
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
	return;
}

#==========================================
# test_getImageSizeNotAdditive_legacy
#------------------------------------------
sub test_getImageSizeNotAdditive_legacy {
	# ...
	# Verify proper return of getImageSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageSize_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('20G', $value);
	return;
}

#==========================================
# test_getImageSizeAdditiveBytesNotAdditive_legacy
#------------------------------------------
sub test_getImageSizeAdditiveBytesNotAdditive_legacy {
	# ...
	# Verify proper return of getImageSizeAdditiveBytes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageSizeAdditiveBytes_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('0', $value);
	return;
}

#==========================================
# test_getImageSizeBytesNotAdditive_legacy
#------------------------------------------
sub test_getImageSizeBytesNotAdditive_legacy {
	# ...
	# Verify proper return of getImageSizeBytes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageSizeBytes_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('21474836480', $value);
	return;
}

#==========================================
# test_getImageType
#------------------------------------------
sub test_getImageType {
	# ...
	# Verify proper return of getImageType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $typeInfo = $xml -> getImageType();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that we got the expected type
	my $imageType = $typeInfo -> getImageType();
	$this -> assert_str_equals('vmx', $imageType);
	return;
}

#==========================================
# test_getImageTypeProfiles
#------------------------------------------
sub test_getImageTypeProfiles {
	# ...
	# Verify proper return of getImageType method with multiple type
	# definitions and profiles.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $typeInfo = $xml -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that we got the expected type
	my $imageType = $typeInfo -> getImageType();
	$this -> assert_str_equals('oem', $imageType);
	return;
}

#==========================================
# test_getImageTypeProfilesNoPrimaryType
#------------------------------------------
sub test_getImageTypeProfilesNoPrimaryType {
	# ...
	# Verify proper return of getImageType method with multiple type
	# definitions and profiles. But no type is marked as primary and the
	# default preferences section has no type definition.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettingsNoTypeDefPrefNoPrim';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $type = $xml -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($type);
	my $imageT = $type -> getImageType();
	$this -> assert_str_equals('vmx', $imageT);
	return;
}

#==========================================
# test_getImageTypeAndAttributes_legacy
#------------------------------------------
sub test_getImageTypeAndAttributes_legacy {
	# ...
	# Verify proper return of getImageTypeAndAttributes_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $typeInfo = $xml -> getImageTypeAndAttributes_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('vmx', $typeInfo->{type});
	return;
}

#==========================================
# test_getImageVersion_legacy
#------------------------------------------
sub test_getImageVersion_legacy {
	# ...
	# Verify proper return of getImageVersion method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getImageVersion_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('13.20.26', $value);
	return;
}

#==========================================
# test_getInstallList_legacy
#------------------------------------------
sub test_getInstallList_legacy {
	# ...
	# Verify proper return of getInstallList_legacy method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsNoPattern';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @instPcks = $xml -> getInstallList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /ed kernel-default python vim/;
	$this -> assert_array_equal(\@expected, \@instPcks);
	return;
}

#==========================================
# test_getInstallOption
#------------------------------------------
sub test_getInstallOption {
	# ...
	# Verify proper return of getInstallOption method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @useProf = ('aTest');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): aTest';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $instOpt = $xml -> getInstallOption();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('plusRecommended', $instOpt);
	return;
}

#==========================================
# test_getInstallOptionConflict
#------------------------------------------
sub test_getInstallOptionConflict {
	# ...
	# Verify proper return of getInstallOption method when there is a
	# conflict in the settings
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @useProf = ('profA');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): profA';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $instOpt = $xml -> getInstallOption();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($instOpt);
	return;
}

#==========================================
# test_getInstallOptionDefault
#------------------------------------------
sub test_getInstallOptionDefault {
	# ...
	# Verify proper return of getInstallOption method when no patternType
	# is defined
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $instOpt = $xml -> getInstallOption();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('onlyRequired', $instOpt);
	return;
}

#==========================================
# test_getLibsToKeep
#------------------------------------------
sub test_getLibsToKeep {
	# ...
	# Verify proper return of getLibsToKeep method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $libs = $xml -> getLibsToKeep();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = qw /libdbus libnss/;
	my @libNames = ();
	for my $lib (@{$libs}) {
		push @libNames, $lib -> getName();
	}
	$this -> assert_array_equal(\@expected, \@libNames);
	return;
}

#==========================================
# test_getLicenseNames_legacy
#------------------------------------------
sub test_getLicenseNames_legacy {
	# ...
	# Verify proper return of getLicenseNames_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $licNames = $xml -> getLicenseNames_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw (/opt/myApp/lic.txt /opt/myApp/thirdParty/appA/lic.txt);
	$this -> assert_array_equal(\@expected, $licNames);
	return;
}

#==========================================
# test_getLocale_legacy
#------------------------------------------
sub test_getLocale_legacy {
	# ...
	# Verify proper return of getLocale method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getLocale_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('en_US', $value);
	return;
}

#==========================================
# test_getLVMGroupName_legacy
#------------------------------------------
sub test_getLVMGroupName_legacy {
	# ...
	# Verify proper return of getLVMGroupName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getLVMGroupName_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('test_Volume', $value);
	return;
}

#==========================================
# test_getLVMVolumes_legacy
#------------------------------------------
sub test_getLVMVolumes_legacy {
	# ...
	# Verify proper return of getLVMVolumes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %volumes = $xml -> getLVMVolumes_legacy();
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
	return;
}

#==========================================
# test_getOEMConfig
#------------------------------------------
sub test_getOEMConfig {
	# ...
	# Test the getOEMConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $oemConfObj = $xml -> getOEMConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $align   = $oemConfObj -> getAlignPartition();
	my $booT    = $oemConfObj -> getBootTitle();
	my $bootW   = $oemConfObj -> getBootwait();
	my $inplRec = $oemConfObj -> getInplaceRecovery();
	my $kInit   = $oemConfObj -> getKiwiInitrd();
	my $pInst   = $oemConfObj -> getPartitionInstall();
	my $reboot  = $oemConfObj -> getReboot();
	my $rebootI = $oemConfObj -> getRebootInteractive();
	my $recover = $oemConfObj -> getRecovery();
	my $recovI  = $oemConfObj -> getRecoveryID();
	my $sDown   = $oemConfObj -> getShutdown();
	my $sDownI  = $oemConfObj -> getShutdownInteractive();
	my $sBoot   = $oemConfObj -> getSilentBoot();
	my $swap    = $oemConfObj -> getSwap();
	my $swapS   = $oemConfObj -> getSwapSize();
	my $sysS    = $oemConfObj -> getSystemSize();
	my $unat    = $oemConfObj -> getUnattended();
	my $unatI   = $oemConfObj -> getUnattendedID();
	$this -> assert_str_equals('true', $align);
	$this -> assert_str_equals('Unit Test', $booT);
	$this -> assert_str_equals('false', $bootW);
	$this -> assert_str_equals('true', $kInit);
	$this -> assert_str_equals('false', $pInst);
	$this -> assert_str_equals('false', $reboot);
	$this -> assert_str_equals('false', $rebootI);
	$this -> assert_str_equals('true', $recover);
	$this -> assert_str_equals('20', $recovI);
	$this -> assert_str_equals('false', $sDown);
	$this -> assert_str_equals('true', $sDownI);
	$this -> assert_str_equals('true', $sBoot);
	$this -> assert_str_equals('true', $swap);
	$this -> assert_str_equals('2048', $swapS);
	$this -> assert_str_equals('20G', $sysS);
	$this -> assert_str_equals('true', $unat);
	$this -> assert_str_equals('scsi-SATA_ST9500420AS_5VJ5JL6T-part1', $unatI);
	return;
}

#==========================================
# test_getOEMAlignPartition_legacy
#------------------------------------------
sub test_getOEMAlignPartition_legacy {
	# ...
	# Verify proper return of getOEMAlignPartition method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMAlignPartition_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMBootTitle_legacy
#------------------------------------------
sub test_getOEMBootTitle_legacy {
	# ...
	# Verify proper return of getOEMBootTitle method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMBootTitle_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('Unit Test', $value);
	return;
}

#==========================================
# test_getOEMBootWait_legacy
#------------------------------------------
sub test_getOEMBootWait_legacy {
	# ...
	# Verify proper return of getOEMBootWait method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMBootWait_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
	return;
}

#==========================================
# test_getOEMKiwiInitrd_legacy
#------------------------------------------
sub test_getOEMKiwiInitrd_legacy {
	# ...
	# Verify proper return of getOEMKiwiInitrd method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMKiwiInitrd_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMPartitionInstall_legacy
#------------------------------------------
sub test_getOEMPartitionInstall_legacy {
	# ...
	# Verify proper return of getOEMPartitionInstall method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMPartitionInstall_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
	return;
}

#==========================================
# test_getOEMReboot_legacy
#------------------------------------------
sub test_getOEMReboot_legacy {
	# ...
	# Verify proper return of getOEMReboot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMReboot_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
	return;
}

#==========================================
# test_getOEMRebootInter_legacy
#------------------------------------------
sub test_getOEMRebootInter_legacy {
	# ...
	# Verify proper return of getOEMRebootInter method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRebootInter_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
	return;
}

#==========================================
# test_getOEMRecovery_legacy
#------------------------------------------
sub test_getOEMRecovery_legacy {
	# ...
	# Verify proper return of getOEMRecovery method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRecovery_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMRecoveryID_legacy
#------------------------------------------
sub test_getOEMRecoveryID_legacy {
	# ...
	# Verify proper return of getOEMRecoveryID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRecoveryID_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('20', $value);
	return;
}

#==========================================
# test_getOEMRecoveryInPlace_legacy
#------------------------------------------
sub test_getOEMRecoveryInPlace_legacy {
	# ...
	# Verify proper return of getOEMRecoveryInPlace method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMRecoveryInPlace_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMShutdown_legacy
#------------------------------------------
sub test_getOEMShutdown_legacy {
	# ...
	# Verify proper return of getOEMShutdown method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMShutdown_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('false', $value);
	return;
}

#==========================================
# test_getOEMShutdownInter_legacy
#------------------------------------------
sub test_getOEMShutdownInter_legacy {
	# ...
	# Verify proper return of getOEMShutdownInter method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMShutdownInter_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMSilentBoot_legacy
#------------------------------------------
sub test_getOEMSilentBoot_legacy {
	# ...
	# Verify proper return of getOEMSilentBoot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSilentBoot_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMSwap_legacy
#------------------------------------------
sub test_getOEMSwap_legacy {
	# ...
	# Verify proper return of getOEMSwap method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSwap_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMSwapSize_legacy
#------------------------------------------
sub test_getOEMSwapSize_legacy {
	# ...
	# Verify proper return of getOEMSwapSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSwapSize_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('2048', $value);
	return;
}

#==========================================
# test_getOEMSystemSize_legacy
#------------------------------------------
sub test_getOEMSystemSize_legacy {
	# ...
	# Verify proper return of getOEMSystemSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMSystemSize_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('20G', $value);
	return;
}

#==========================================
# test_getOEMUnattended_legacy
#------------------------------------------
sub test_getOEMUnattended_legacy {
	# ...
	# Verify proper return of getOEMUnattended method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMUnattended_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('true', $value);
	return;
}

#==========================================
# test_getOEMUnattendedID_legacy
#------------------------------------------
sub test_getOEMUnattendedID_legacy {
	# ...
	# Verify proper return of getOEMUnattendedID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getOEMUnattendedID_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('scsi-SATA_ST9500420AS_5VJ5JL6T-part1', $value);
	return;
}

#==========================================
# test_getPackages
#------------------------------------------
sub test_getPackages {
	# ...
	# Test the getPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my $pckgs = $xml -> getPackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$pckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = qw(
		ed
		kernel-default
		kernel-firmware
		python
		sane
		vim
	);
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getPackagesToDelete
#------------------------------------------
sub test_getPackagesToDelete {
	# ...
	# Test proper return of getPackagesToDelete method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $delPckgs = $xml -> getPackagesToDelete();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$delPckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = ( 'java' );
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getPackagesToDeleteUseProf
#------------------------------------------
sub test_getPackagesToDeleteUseProf {
	# ...
	# Test proper return of getPackagesToDelete method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @useProf = ('aTest');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): aTest';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $delPckgs = $xml -> getPackagesToDelete();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$delPckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = ( 'java' , 'libreOffice' );
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getPackagesUseProf
#------------------------------------------
sub test_getPackagesUseProf {
	# ...
	# Test the getPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my @useProf = ('aTest');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): aTest';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $pckgs = $xml -> getPackages();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @pckgNames;
	for my $pckg (@{$pckgs}) {
		push @pckgNames, $pckg -> getName();
	}
	my @expected = qw(
		ed
		emacs
		gimp
		kernel-desktop
		kernel-firmware
		perl
		sane
		xemacs
	);
	$this -> assert_array_equal(\@expected, \@pckgNames);
	return;
}

#==========================================
# test_getProductArchitectures
#------------------------------------------
sub test_getProductArchitectures {
	# ...
	# Verify proper return of getProductArchitectures method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $arches = $xml -> getProductArchitectures();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($arches);
	my @expected = qw (i586 i686 noarch);
	my @ids;
	for my$arch (@{$arches}) {
		push @ids, $arch -> getID();
	}
	$this -> assert_array_equal(\@expected, \@ids);
	return;
}

#==========================================
# test_getProductMetaChroots
#------------------------------------------
sub test_getProductMetaChroots {
	# ...
	# Verify proper return of getProductMetaChroots method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $chroots = $xml -> getProductMetaChroots();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($chroots);
	my $cnt = scalar @{$chroots};
	$this -> assert_equals(2, $cnt);
	return;
}

#==========================================
# test_getProductMetaFiles
#------------------------------------------
sub test_getProductMetaFiles {
	# ...
	# Verify proper return of getProductMetaFiles method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $mFiles = $xml -> getProductMetaFiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($mFiles);
	my $cnt = scalar @{$mFiles};
	$this -> assert_equals(2, $cnt);
	return;
}

#==========================================
# test_getProductMetaPackages
#------------------------------------------
sub test_getProductMetaPackages {
	# ...
	# Verify proper return of getProductMetaPackages method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $mPkgs = $xml -> getProductMetaPackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($mPkgs);
	my @expected = qw (dbus gtk vi);
	my @names;
	for my $pkg (@{$mPkgs}) {
		push @names, $pkg -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getProductOptions
#------------------------------------------
sub test_getProductOptions {
	# ...
	# Verify proper return of getProductOptions method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $prodOpts = $xml -> getProductOptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prodOpts);
	my $optNames = $prodOpts -> getProductOptionNames();
	my @expected = ('INI_DIR', 'REPO LOCATION', 'SOURCEMEDIUM');
	$this -> assert_array_equal(\@expected, $optNames);
	return;
}

#==========================================
# test_getProductRepositories
#------------------------------------------
sub test_getProductRepositories {
	# ...
	# Verify proper return of getProductRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $pRepos = $xml -> getProductRepositories();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($pRepos);
	my @expected = qw (repo1 repo2);
	my @names;
	for my $repo (@{$pRepos}) {
		push @names, $repo -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getProductRequiredArchitectures
#------------------------------------------
sub test_getProductRequiredArchitectures {
	# ...
	# Verify proper return of getProductRequiredArchitectures method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $reqArches = $xml -> getProductRequiredArchitectures();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($reqArches);
	my @expected = qw (i586 i686);
	$this -> assert_array_equal(\@expected, $reqArches);
	return;
}

#==========================================
# test_getProducts
#------------------------------------------
sub test_getProducts {
	# ...
	# Verify proper return of getProducts method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $products = $xml -> getProducts();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @prodNames;
	for my $prod (@{$products}) {
		push @prodNames, $prod -> getName();
	}
	my @expected = ( 'SLES' );
	$this -> assert_array_equal(\@expected, \@prodNames);
	return;
}

#==========================================
# test_getProductSourcePackages
#------------------------------------------
sub test_getProductSourcePackages {
	# ...
	# Test the getProductSourcePackages
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'productSetings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $pkgs = $xml -> getProductSourcePackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($pkgs);
	my @expected = qw (emacs glibc kernel-default vi);
	my @names;
	for my $pkg (@{$pkgs}) {
		push @names, $pkg -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getPXEConfig
#------------------------------------------
sub test_getPXEConfig {
	# ...
	# Test the getPXEConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $pxeConfObj = $xml -> getPXEConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $blockS   = $pxeConfObj -> getBlocksize();
	my $target   = $pxeConfObj -> getDevice();
	my $initrd   = $pxeConfObj -> getInitrd();
	my $kernel   = $pxeConfObj -> getKernel();
	my $mntP     = $pxeConfObj -> getPartitionMountpoint(2);
	my $partN    = $pxeConfObj -> getPartitionNumber(2);
	my $partS    = $pxeConfObj -> getPartitionSize(2);
	my $partT    = $pxeConfObj -> getPartitionTarget(2);
	my $partTy   = $pxeConfObj -> getPartitionType(2);
	my $server   = $pxeConfObj -> getServer();
	my $timeout  = $pxeConfObj -> getTimeout();
	my $unionRO  = $pxeConfObj -> getUnionRO();
	my $unionRW  = $pxeConfObj -> getUnionRW();
	my $unionT   = $pxeConfObj -> getUnionType();
	$this -> assert_str_equals('4096', $blockS);
	$this -> assert_str_equals('/dev/sda', $target);
	$this -> assert_str_equals('/pxeSetup/specialInitrd', $initrd);
	$this -> assert_str_equals('/pxeSetup/specialKernel', $kernel);
	$this -> assert_str_equals('/', $mntP);
	$this -> assert_equals(2, $partN);
	$this -> assert_str_equals('image', $partS);
	$this -> assert_equals(1, $partT);
	$this -> assert_str_equals('L', $partTy);
	$this -> assert_str_equals('192.168.100.2', $server);
	$this -> assert_str_equals('20', $timeout);
	$this -> assert_str_equals('/dev/sda2', $unionRO);
	$this -> assert_str_equals('/dev/sda3', $unionRW);
	$this -> assert_str_equals('clicfs', $unionT);
	return;
}

#==========================================
# test_getPXEConfigData
#------------------------------------------
sub test_getPXEConfigData {
	# ...
	# Test the getPXEConfigData method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $pxeConfData = $xml -> getPXEConfigData();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($pxeConfData);
	my @confData = @{$pxeConfData};
	my $cnt = 0;
	for my $dataObj (@confData) {
		my $dest = $dataObj -> getDestination();
		my $source = $dataObj -> getSource();
		if ($source eq 's390Img') {
			$this -> assert_str_equals('zdrive', $dest);
		} else {
			$this -> assert_str_equals('target', $dest);
		}
		$cnt += 1;
	}
	if ($cnt != 2) {
		$this -> assert_null('Did not get 2 PXEDeployConfigData objects');
	}
	return;
}

#==========================================
# test_getPackageAttributes_legacy
#------------------------------------------
sub test_getPackageAttributes_legacy {
	# ...
	# Verify proper return of getPackageAttributes_legacey method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my %pattr = $xml -> getPackageAttributes_legacy('image');;
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('image', $pattr{type});
	$this -> assert_str_equals('onlyRequired', $pattr{patternType});
	return;
}

#==========================================
# test_getPackageAttributesUseProf_legacy
#------------------------------------------
sub test_getPackageAttributesUseProf_legacy {
	# ...
	# Verify proper return of getPackageAttributes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$confDir, undef, \@patterns, $this->{cmdL}
	);
	my %pattr = $xml -> getPackageAttributes_legacy('image');;
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('image', $pattr{type});
	$this -> assert_str_equals('plusRecommended', $pattr{patternType});
	return;
}

#==========================================
# test_getPackageCollections
#------------------------------------------
sub test_getPackageCollections {
	# ...
	# Verify proper return of getPackageCollections method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $collections = $xml -> getPackageCollections();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @collectNames;
	for my $collect (@{$collections}) {
		push @collectNames, $collect -> getName();
	}
	my @expected = qw(
		base
		compatAddon
		xfce
	);
	$this -> assert_array_equal(\@expected, \@collectNames);
	return;
}

#==========================================
# test_getPackageCollectionsUseProf
#------------------------------------------
sub test_getPackageCollectionsUseProf {
	# ...
	# Verify proper return of getPackageCollections method with a selected
	# build profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my @useProf = ('aTest');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): aTest';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $collections = $xml -> getPackageCollections();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @collectNames;
	for my $collect (@{$collections}) {
		push @collectNames, $collect -> getName();
	}
	my @expected = qw(
		base
		compatAddon
		kde
		lamp
		xfce
	);
	$this -> assert_array_equal(\@expected, \@collectNames);
	return;
}

#==========================================
# test_getPackageNodeList_legacy
#------------------------------------------
sub test_getPackageNodeList_legacy {
	# ...
	# Verify proper return of getPackageNodeList method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my @packNodes = $xml -> getPackageNodeList_legacy() -> get_nodelist();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /ed emacs filesystem glibc-locale kernel-default
						kernel-desktop perl python vim/;
	my @expectedArch = qw /myInitStuff.tar myImageStuff.tgz myAppArch.tgz/;
	my @expectedPats = qw /base xfce kde/;
	my @packages;
	my @archives;
	my @patterns;
	for my $node (@packNodes) {
		my $type = $node -> getAttribute('type');
		if ($type eq 'bootstrap') {
			my @bootPckgsNodes = $node -> getElementsByTagName('package');
			for my $pckNode (@bootPckgsNodes) {
				push @packages, $pckNode -> getAttribute('name');
			}
		}
		elsif ($type eq 'image') {
			my @imgPckgNodes = $node -> getElementsByTagName('package');
			my @archNodes = $node -> getElementsByTagName('archive');
			my @pattNodes = $node -> getElementsByTagName('opensusePattern');
			for my $pckNode (@imgPckgNodes) {
				push @packages, $pckNode -> getAttribute('name');
			}
			for my $archNode (@archNodes) {
				push @archives, $archNode -> getAttribute('name');
			}
			for my $pattNode (@pattNodes) {
				push @patterns, $pattNode -> getAttribute('name');
			}
		}
	}
	$this -> assert_array_equal(\@expectedPcks, \@packages);
	$this -> assert_array_equal(\@expectedArch, \@archives);
	$this -> assert_array_equal(\@expectedPats, \@patterns);
	return;
}

#==========================================
# test_getPreferences
#------------------------------------------
sub test_getPreferences {
	# ...
	# Verify that a proper PreferenceData object is returned
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $prefDataObj = $xml -> getPreferences();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify some of the data, complete data verification is accomplished
	# with the unit test for the PreferenceData object
	my $blTheme = $prefDataObj -> getBootLoaderTheme();
	$this -> assert_str_equals('silverlining', $blTheme);
	my $ver = $prefDataObj -> getVersion();
	$this -> assert_str_equals('13.20.26', $ver);
	return;
}

#==========================================
# test_getPreferencesProfiles
#------------------------------------------
sub test_getPreferencesProfiles {
	# ...
	# Verify that a proper PreferenceData object is returned when
	# preference data in profiles need to be merged
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $prefDataObj = $xml -> getPreferences();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify some of the data, complete data verification is accomplished
	# with the unit test for the PreferenceData object
	# Should have data for settings in the default profile and data for
	# settings in profA
	my $blTheme = $prefDataObj -> getBootLoaderTheme();
	$this -> assert_str_equals('silverlining', $blTheme);
	my $ver = $prefDataObj -> getVersion();
	$this -> assert_str_equals('0.0.1', $ver);
	return;
}

#==========================================
# test_getPreferencesProfilesNoPref
#------------------------------------------
sub test_getPreferencesProfilesNoPref {
	# ...
	# Verify that a proper PreferenceData object is returned when
	# getting preferences for a profile that has no specific
	# preferences settings, i.e. the dafult should be returned
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @newProfs = ( 'profD' );
	$xml = $xml -> setSelectionProfileNames(\@newProfs);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profD', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	my $prefDataObj = $xml -> getPreferences();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify some of the data, complete data verification is accomplished
	# with the unit test for the PreferenceData object
	# Should have data for settings in the default profile
	my $blTheme = $prefDataObj -> getBootLoaderTheme();
	$this -> assert_null($blTheme);
	my $locale = $prefDataObj -> getLocale();
	$this -> assert_str_equals('en_US', $locale);
	my $ver = $prefDataObj -> getVersion();
	$this -> assert_str_equals('0.0.1', $ver);
	return;
}

#==========================================
# test_getPreferencesProfilesWithConflict
#------------------------------------------
sub test_getPreferencesProfilesWithConflict {
	# ...
	# Verify that getPreferences reports the proper error for
	# preference data in profiles that conflicts
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @newProfs = qw /profA profC/;
	$xml = $xml -> setSelectionProfileNames(\@newProfs);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA, profC', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $prefDataObj = $xml -> getPreferences();
	$msg = $kiwi -> getMessage();
	my $expected = 'Error merging preferences data, found data for '
		. "'defaultroot' in both preference definitions, ambiguous "
		. 'operation.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($prefDataObj);
	return;
}

#==========================================
# test_getPreferencesProfilesWithConflictType
#------------------------------------------
sub test_getPreferencesProfilesWithConflictType {
	# ...
	# Verify that getPreferences reports the proper error for
	# preference data in profiles that conflicts for type definitions
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @newProfs = ( 'profB' );
	$xml = $xml -> setSelectionProfileNames(\@newProfs);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $prefDataObj = $xml -> getPreferences();
	$msg = $kiwi -> getMessage();
	my $expected = 'Error merging preferences data, found definition for '
		. "type 'vmx' in both preference definitions, ambiguous operation.";
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($prefDataObj);
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my @profiles = @{$xml -> getProfiles()};
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
		my $name = $prof -> getName();
		if ($name eq 'profA') {
			$this -> assert_str_equals('false', $prof->getImportStatus());
			$this -> assert_str_equals('Test prof A', $prof->getDescription());
		} elsif ($name eq 'profB') {
			$this -> assert_str_equals('true', $prof->getImportStatus());
		} else {
			$this -> assert_str_equals('profC', $prof->getName());
		}
	}
	return;
}

#==========================================
# test_getReplacePackageAddList
#------------------------------------------
sub test_getReplacePackageAddList {
	# ...
	# Verify proper return of getReplacePackageAddList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageReplSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Call getList to trigger the generation of the replace-add list as
	# a side effect :(
	my @gL = $xml -> getList_legacy('image');
	my @replAdd = $xml -> getReplacePackageAddList();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /kernel-desktop vim/;
	$this -> assert_array_equal(\@expected, \@replAdd);
	return;
}

#==========================================
# test_getReplacePackageDelList
#------------------------------------------
sub test_getReplacePackageDelList {
	# ...
	# Verify proper return of getReplacePackageDelList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageReplSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Call getList to trigger the generation of the replace-delete list as
	# a side effect :(
	my @gL = $xml -> getList_legacy('image');
	my @replDel = $xml -> getReplacePackageDelList();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /kernel-default ed/;
	$this -> assert_array_equal(\@expected, \@replDel);
	return;
}

#==========================================
# test_getRepoNodeList_legacy
#------------------------------------------
sub test_getRepoNodeList_legacy {
	# ...
	# Verify proper return of getRepoNodeList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @repoNodes = $xml -> getRepoNodeList_legacy() -> get_nodelist();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPaths = ['/tmp/12.1/repo/oss/',
						'http://download.opensuse.org/update/12.1',
						'https://myreposerver/protectedrepos/12.1',
						'/repos/12.1-additional'];
	my @configPaths;
	for my $element (@repoNodes) {
		my $source= $element -> getElementsByTagName('source')
			-> get_node(1) -> getAttribute ('path');
		push @configPaths, $source;
	}
	$this -> assert_array_equal(@expectedPaths, \@configPaths);
	return;
}

#==========================================
# test_getRepositories
#------------------------------------------
sub test_getRepositories {
	# ...
	# Verify proper return of getRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		# TODO: Eliminate the net check once we eliminate
		#       URL resolution in the XML Object
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @repoData = @{$xml -> getRepositories()};
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $numRepos = @repoData;
	$this -> assert_equals(4, $numRepos);
	for my $repoDataObj (@repoData) {
		if ( $repoDataObj -> getPath() eq '/tmp/12.1/repo/oss/' ) {
			$this -> assert_str_equals('yast2', $repoDataObj -> getType() );
			$this -> assert_str_equals('2', $repoDataObj -> getPriority() );
			$this -> assert_str_equals('true',
									$repoDataObj -> getPreferLicense()
									);
			$this -> assert_str_equals('fixed', $repoDataObj -> getStatus() );
		}
		if ( $repoDataObj -> getPath() eq
			'http://download.opensuse.org/update/12.1' ) {
			$this -> assert_str_equals('rpm-md', $repoDataObj -> getType() );
			$this -> assert_str_equals('update', $repoDataObj -> getAlias() );
			$this -> assert_str_equals('true',
									$repoDataObj -> getImageInclude()
									);
		}
		if ( $repoDataObj -> getPath() eq
			'https://myreposerver/protectedrepos/12.1' ) {
			$this -> assert_str_equals('yast2', $repoDataObj -> getType() );
			my ($uname, $passwd) =  $repoDataObj -> getCredentials();
			$this -> assert_str_equals('foo', $uname );
			$this -> assert_str_equals('bar', $passwd );
		}
		if ( $repoDataObj -> getPath() eq '/repos/12.1-additional' ) {
			$this -> assert_str_equals('rpm-dir', $repoDataObj -> getType() );
		}
	}
	return;
}

#==========================================
# test_getRepositoriesWithProf
#------------------------------------------
sub test_getRepositoriesWithProf {
	# ...
	# Verify proper return of getRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		# TODO: Eliminate the net check once we eliminate
		#       URL resolution in the XML Object
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @repoData = @{$xml -> getRepositories()};
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $numRepos = @repoData;
	$this -> assert_equals(1, $numRepos);
	for my $repoDataObj (@repoData) {
		$this -> assert_str_equals('/tmp/12.1/repo/oss/',
								$repoDataObj -> getPath()
								);
		$this -> assert_str_equals('yast2', $repoDataObj -> getType() );
		$this -> assert_str_equals('2', $repoDataObj -> getPriority() );
		$this -> assert_str_equals('true',
								$repoDataObj -> getPreferLicense()
								);
		$this -> assert_str_equals('fixed', $repoDataObj -> getStatus() );
	}
	my @useProf = ('profA');
	$xml -> setSelectionProfileNames(\@useProf);
	my $expected = 'Using profile(s): profA';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	@repoData = @{$xml -> getRepositories()};
	$numRepos = @repoData;
	$this -> assert_equals(3, $numRepos);
	for my $repoDataObj (@repoData) {
		if ( $repoDataObj -> getPath() eq '/tmp/12.1/repo/oss/' ) {
			$this -> assert_str_equals('yast2', $repoDataObj -> getType() );
			$this -> assert_str_equals('2', $repoDataObj -> getPriority() );
			$this -> assert_str_equals('true',
									$repoDataObj -> getPreferLicense()
									);
			$this -> assert_str_equals('fixed', $repoDataObj -> getStatus() );
		}
		if ( $repoDataObj -> getPath() eq
			'http://download.opensuse.org/update/12.1' ) {
			$this -> assert_str_equals('rpm-md', $repoDataObj -> getType() );
			$this -> assert_str_equals('update', $repoDataObj -> getAlias() );
			$this -> assert_str_equals('true',
									$repoDataObj -> getImageInclude()
									);
		}
		if ( $repoDataObj -> getPath() eq '/repos/12.1-additional' ) {
			$this -> assert_str_equals('rpm-dir', $repoDataObj -> getType() );
		}
	}
	@useProf = ('profC');
	$xml -> setSelectionProfileNames(\@useProf);
	$expected = 'Using profile(s): profC';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	@repoData = @{$xml -> getRepositories()};
	$numRepos = @repoData;
	$this -> assert_equals(2, $numRepos);
	for my $repoDataObj (@repoData) {
		if ( $repoDataObj -> getPath() eq '/tmp/12.1/repo/oss/' ) {
			$this -> assert_str_equals('yast2', $repoDataObj -> getType() );
			$this -> assert_str_equals('2', $repoDataObj -> getPriority() );
			$this -> assert_str_equals('true',
									$repoDataObj -> getPreferLicense()
									);
			$this -> assert_str_equals('fixed', $repoDataObj -> getStatus() );
		}
		if ( $repoDataObj -> getPath() eq '/repos/12.1-additional' ) {
			$this -> assert_str_equals('rpm-dir', $repoDataObj -> getType() );
		}
	}
	return;
}

#==========================================
# test_getSplitConfig
#------------------------------------------
sub test_getSplitConfig {
	# ...
	# Test the getSplitConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $spltConfObj = $xml -> getSplitConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $persExcept = $spltConfObj -> getPersistentExceptions('x86_64');
	my $persFiles  = $spltConfObj -> getPersistentFiles('x86_64');
	my $tmpExcept  = $spltConfObj -> getTemporaryExceptions('x86_64');
	my $tmpFiles   = $spltConfObj -> getTemporaryFiles('x86_64');
	my @persExceptExpect = ( 'bar' );;
	my @persFilesExpect = qw /bar64 genericBar/;
	my @tmpExceptExpect = qw /foo anotherFoo/;
	my @tmpFilesExpect = qw /foo64 genericFoo/;
	my @persExcptNames;
	for my $peObj (@{$persExcept}) {
		push @persExcptNames, $peObj -> getName();
	}
	$this -> assert_array_equal(\@persExceptExpect, \@persExcptNames);
	my @persFileNames;
	for my $pfObj (@{$persFiles}) {
		push @persFileNames, $pfObj -> getName();
	}
	$this -> assert_array_equal(\@persFilesExpect, \@persFileNames);
	my @tmpExcptNames;
	for my $teObj (@{$tmpExcept}) {
		push @tmpExcptNames, $teObj -> getName();
	}
	$this -> assert_array_equal(\@tmpExceptExpect, \@tmpExcptNames);
	my @tmpFileNames;
	for my $tfObj (@{$tmpFiles}) {
		push @tmpFileNames, $tfObj -> getName();
	}
	$this -> assert_array_equal(\@tmpFilesExpect, \@tmpFileNames);
	return;
}

#==========================================
# test_getSplitPersistentExceptions_legacy
#------------------------------------------
sub test_getSplitPersistentExceptions_legacy {
	# ...
	# Verify proper return of getSplitPersistentExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @persExcept = $xml -> getSplitPersistentExceptions_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedExcept = qw / bar /;
	$this -> assert_array_equal(\@expectedExcept, \@persExcept);
	return;
}

#==========================================
# test_getSplitPersistentFiles_legacy
#------------------------------------------
sub test_getSplitPersistentFiles_legacy {
	# ...
	# Verify proper return of getSplitPersistentFiles method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @persFiles = $xml -> getSplitPersistentFiles_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /bar64 genericBar/;
	$this -> assert_array_equal(\@expectedNames, \@persFiles);
	return;
}

#==========================================
# test_getSplitTempExceptions_legacy
#------------------------------------------
sub test_getSplitTempExceptions_legacy {
	# ...
	# Verify proper return of getSplitTempExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @tmpExcept = $xml -> getSplitTempExceptions_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedExcept = qw /foo anotherFoo/;
	$this -> assert_array_equal(\@expectedExcept, \@tmpExcept);
	return;
}

#==========================================
# test_getSplitTempFiles_legacy
#------------------------------------------
sub test_getSplitTempFiles_legacy {
	# ...
	# Verify proper return of getSplitTempFiles method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @tmpFiles = $xml -> getSplitTempFiles_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /foo64 genericFoo/;
	$this -> assert_array_equal(\@expectedNames, \@tmpFiles);
	return;
}

#==========================================
# test_getStripDelete_legacy
#------------------------------------------
sub test_getStripDelete_legacy {
	# ...
	# Verify proper return of getStripDelete method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @delFiles = $xml -> __getStripDelete_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw (/etc/resolv.conf /lib/libc.so);
	$this -> assert_array_equal(\@expectedNames, \@delFiles);
	return;
}

#==========================================
# test_getStripLibs_legacy
#------------------------------------------
sub test_getStripLibs_legacy {
	# ...
	# Verify proper return of getStripLibs method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @libFiles = $xml -> __getStripLibs_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /libdbus libnss/;
	$this -> assert_array_equal(\@expectedNames, \@libFiles);
	return;
}

#==========================================
# test_getStripNodeList_legacy
#------------------------------------------
sub test_getStripNodeList_legacy {
	# ...
	# Verify the expected return of getStripNodeList
	# Note, this method should eventually disappear from the XML object
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @stripNodes = $xml -> getStripNodeList_legacy() -> get_nodelist();
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
	return;
}

#==========================================
# test_getStripTools_legacy
#------------------------------------------
sub test_getStripTools_legacy {
	# ...
	# Verify proper return of getStripTools method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @toolFiles = $xml -> __getStripTools_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedNames = qw /megacli virt-mgr/;
	$this -> assert_array_equal(\@expectedNames, \@toolFiles);
	return;
}

#==========================================
# test_getSystemDiskConfig
#------------------------------------------
sub test_getSystemDiskConfig {
	# ...
	# Test the getSystemDiskConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $sysDiskObj = $xml -> getSystemDiskConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $vgName = $sysDiskObj -> getVGName();
	$this -> assert_str_equals('test_Volume', $vgName);
	my $volIDs = $sysDiskObj -> getVolumeIDs();
	my @expectedIDs = ( 1, 2, 3, 4);
	$this -> assert_array_equal(\@expectedIDs, $volIDs);
	for my $id (@expectedIDs) {
		my $free = $sysDiskObj -> getVolumeFreespace($id);
		my $name = $sysDiskObj -> getVolumeName($id);
		my $size = $sysDiskObj -> getVolumeSize($id);
	if ($name eq 'home') {
		$this -> assert_equals(2048, $free);
	}
	if ($name eq 'tmp') {
		$this -> assert_str_equals('all', $free);
	}
	if ($name eq 'usr') {
		$this -> assert_equals(4096, $size);
	}
	if ($name eq 'var') {
		$this -> assert_equals(50, $size);
	}
	}
	return;
}

#==========================================
# test_getToolsToKeep
#------------------------------------------
sub test_getToolsToKeep {
	# ...
	# Verify proper return of getToolsToKeep method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $tools = $xml -> getToolsToKeep();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = qw /megacli virt-mgr/;
	my @toolNames = ();
	for my $tool (@{$tools}) {
		push @toolNames, $tool -> getName();
	}
	$this -> assert_array_equal(\@expected, \@toolNames);
	return;
}

#==========================================
# test_getType
#------------------------------------------
sub test_getType {
	# ...
	# Verify proper return of getType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @typeNames = @{$xml -> getConfiguredTypeNames()};
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $numTypes = 0;
	my %expectedTypes = (
		oem => 1,
		vmx => 1
	);
	for my $tname (@typeNames) {
		if (! $expectedTypes{$tname}) {
			$this -> assert_null('Data contains unexpected type');
		}
		my $type = $xml -> getType($tname);
		my $msg = $kiwi -> getMessage();
		$this -> assert_str_equals('No messages set', $msg);
		my $msgT = $kiwi -> getMessageType();
		$this -> assert_str_equals('none', $msgT);
		my $state = $kiwi -> getState();
		$this -> assert_str_equals('No state set', $state);
		$this -> assert_not_null($type);
		if ($tname eq 'vmx') {
			my $ebcfg = $type -> getEditBootConfig();
			my $expected = 'data/kiwiXML/typeSettings/fixupBootEnter';
			$this -> assert_str_equals($expected, $ebcfg);
		}
		if ($tname eq 'oem') {
			my $vga = $type -> getVGA();
			$this -> assert_str_equals('0x367', $vga);
		}
		$numTypes++;
	}
	if ($numTypes != 2) {
		$this -> assert_null('Did not get the expected number of types');
	}
	return;
}

#==========================================
# test_getTypeInvalid
#------------------------------------------
sub test_getTypeInvalid {
	# ...
	# Test getType method with an argument that request an undefined type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $type = $xml -> getType('iso');
	my $msg = $kiwi -> getMessage();
	my $expected = "getType: given type 'iso' not defined or available.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($type);
	return;
}

#==========================================
# test_getTypeNoArg
#------------------------------------------
sub test_getTypeNoArg {
	# ...
	# Test getType method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $type = $xml -> getType();
	my $msg = $kiwi -> getMessage();
	my $expected = 'getType: no type name specified';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($type);
	return;
}

#==========================================
# test_getTypeSpecificPackageList_legacy
#------------------------------------------
sub test_getTypeSpecificPackageList_legacy {
	# ...
	# Verify proper return of getTypeList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my @pckgs = $xml -> getTypeSpecificPackageList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /kernel-firmware sane/;
	$this -> assert_array_equal(\@expected, \@pckgs);
	return;
}

#==========================================
# test_getTypeSpecificPackageListUseProf_legacy
#------------------------------------------
sub test_getTypeSpecificPackageListUseProf_legacy {
	# ...
	# Verify proper return of getTypeList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$confDir, undef, \@patterns, $this->{cmdL}
	);
	my @pckgs = $xml -> getTypeSpecificPackageList_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /gimp kernel-firmware sane xemacs /;
	$this -> assert_array_equal(\@expected, \@pckgs);
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $usrData = $xml -> getUsers();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numUsers = 0;
	my %expectedUsers = (
		root  => 1,
		auser => 1,
		buser => 1
	);
	for my $usr (@{$usrData}) {
		my $name = $usr -> getUserName();
		if (! $expectedUsers{$name}) {
			$this -> assert_null('Found unexpected user name');
		}
		if ($name eq 'auser') {
			my $gid = $usr -> getGroupID();
			my $grp = $usr -> getGroupName();
			my $lsh = $usr -> getLoginShell();
			my $uid = $usr -> getUserID();
			$this -> assert_str_equals('2000', $gid);
			$this -> assert_str_equals('mygrp,video', $grp);
			$this -> assert_str_equals('/bin/ksh', $lsh);
			$this -> assert_str_equals('2001', $uid);
		}
		if ($name eq 'buser') {
			my $gid = $usr -> getGroupID();
			my $grp = $usr -> getGroupName();
			my $pwd = $usr -> getPassword();
			my $pwf = $usr -> getPasswordFormat();
			my $rnm = $usr -> getUserRealName();
			$this -> assert_str_equals('2000', $gid);
			$this -> assert_str_equals('mygrp', $grp);
			$this -> assert_str_equals('linux', $pwd);
			$this -> assert_str_equals('plain', $pwf);
			$this -> assert_str_equals('Bert', $rnm);
		}
		if ($name eq 'root') {
			my $grp  = $usr -> getGroupName();
			my $home = $usr -> getUserHomeDir();
			$this -> assert_str_equals('root', $grp);
			$this -> assert_str_equals('/root', $home);
		}
		$numUsers++;
	}
	if ($numUsers != 3) {
		$this -> assert_null('Did not receive 3 users as expected');
	}
	return;
}

#==========================================
# test_getUsersProfsDefault
#------------------------------------------
sub test_getUsersProfsDefault {
	# ...
	# Verify proper return of user information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $usrData = $xml -> getUsers();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numUsers = 0;
	my %expectedUsers = (
		root  => 1,
		auser => 1,
		buser => 1
	);
	for my $usr (@{$usrData}) {
		my $name = $usr -> getUserName();
		if (! $expectedUsers{$name}) {
			$this -> assert_null('Found unexpected user name');
		}
		$numUsers++;
	}
	if ($numUsers != 3) {
		my $msg = 'Did not receive 3 users for no profile selection';
		$this -> assert_null($msg);
	}
	return;
}

#==========================================
# test_getUsersProfsA
#------------------------------------------
sub test_getUsersProfsA {
	# ...
	# Verify proper return of user information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Use Prof A should get 5 users
	my @useProf = ('profA');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	# Clear the log
	my $state = $kiwi -> getState();
	my $usrData = $xml -> getUsers();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numUsers = 0;
	my %expectedUsers = (
		root  => 1,
		auser => 1,
		buser => 1,
		cuser => 1,
		duser => 1
	);
	for my $usr (@{$usrData}) {
		my $name = $usr -> getUserName();
		if (! $expectedUsers{$name}) {
			$this -> assert_null('Found unexpected user name');
		}
		$numUsers++;
	}
	if ($numUsers != 5) {
		$this -> assert_null('Did not receive 5 users for profA as expected');
	}
	return;
}

#==========================================
# test_getUsersProfsC
#------------------------------------------
sub test_getUsersProfsC {
	# ...
	# Verify proper return of user information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Use Prof C should get 4 users
	my @useProf = ('profC');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	# Clear the log
	my $state = $kiwi -> getState();
	my $usrData = $xml -> getUsers();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numUsers = 0;
	my %expectedUsers = (
		root  => 1,
		auser => 1,
		buser => 1,
		duser => 1
	);
	for my $usr (@{$usrData}) {
		my $name = $usr -> getUserName();
		if (! $expectedUsers{$name}) {
			$this -> assert_null('Found unexpected user name');
		}
		$numUsers++;
	}
	if ($numUsers != 4) {
		$this -> assert_null('Did not receive 4 users for profC as expected');
	}
	return ;
}

#==========================================
# test_getUsersProfsB
#------------------------------------------
sub test_getUsersProfsB {
	# ...
	# Verify proper return of user information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'userConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Use Prof B should get 3 users
	my @useProf = ('profB');
	$xml = $xml -> setSelectionProfileNames(\@useProf);
	# Clear the log
	my $state = $kiwi -> getState();
	my $usrData = $xml -> getUsers();
	my $msg = $kiwi -> getMessage();
	my $expected = "Merging data for user 'auser'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test these conditions last to get potential error messages
	my $numUsers = 0;
	my %expectedUsers = (
		root  => 1,
		auser => 1,
		buser => 1
	);
	for my $usr (@{$usrData}) {
		my $name = $usr -> getUserName();
		if (! $expectedUsers{$name}) {
			$this -> assert_null('Found unexpected user name');
		}
		$numUsers++;
	}
	if ($numUsers != 3) {
		$this -> assert_null('Did not receive 3 users for profB as expected');
	}
	return;
}

#==========================================
# test_getVMachineConfigOVF
#------------------------------------------
sub test_getVMachineConfigOVF {
	# ...
	# Test the getVMachineConfig method with a config set up for OVF
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'ovfConfigSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $vmConfig = $xml -> getVMachineConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $maxMem = $vmConfig -> getMaxMemory();
	my $mem    = $vmConfig -> getMemory();
	my $minMem = $vmConfig -> getMinMemory();
	my $maxCPU = $vmConfig -> getMaxCPUCnt();
	my $cpu    = $vmConfig -> getNumCPUs();
	my $minCPU = $vmConfig -> getMinCPUCnt();
	my $oType  = $vmConfig -> getOVFType();
	my $diskID = $vmConfig -> getSystemDiskDevice();
	my $diskT  = $vmConfig -> getSystemDiskType();
	my $nicIf  = $vmConfig -> getNICInterface(1);
	$this -> assert_str_equals('2048', $maxMem);
	$this -> assert_str_equals('1024', $mem);
	$this -> assert_str_equals('512', $minMem);
	$this -> assert_str_equals('4', $maxCPU);
	$this -> assert_str_equals('2', $cpu);
	$this -> assert_str_equals('1', $minCPU);
	$this -> assert_str_equals('powervm', $oType);
	$this -> assert_str_equals('/dev/sda', $diskID);
	$this -> assert_str_equals('scsi', $diskT);
	$this -> assert_str_equals('eth0', $nicIf);
	return;
}

#==========================================
# test_getVMachineConfigVMW
#------------------------------------------
sub test_getVMachineConfigVMW {
	# ...
	# Test the getVMachineConfig method with a config set up for VMware
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'vmwareConfigSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $vmConfig = $xml -> getVMachineConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $arch    = $vmConfig -> getArch();
	my $confEnt = $vmConfig -> getConfigEntries();
	my $dvdID   = $vmConfig -> getDVDID();
	my $dvdCnt  = $vmConfig -> getDVDController();
	my $diskCnt = $vmConfig -> getSystemDiskController();
	my $diskID  = $vmConfig -> getSystemDiskID();
	my $guest   = $vmConfig -> getGuestOS();
	my $hwver   = $vmConfig -> getHardwareVersion();
	my $mem     = $vmConfig -> getMemory();
	my $numCPU  = $vmConfig -> getNumCPUs();
	my $nicIF   = $vmConfig -> getNICInterface(1);
	my $nicDr   = $vmConfig -> getNICDriver(1);
	my $nicMod  = $vmConfig -> getNICMode(1);
	$this -> assert_str_equals('x86_64', $arch);
	my @expectedOpts = qw / ola pablo /;
	$this -> assert_array_equal(\@expectedOpts, $confEnt);
	$this -> assert_str_equals('2', $dvdID);
	$this -> assert_str_equals('ide', $dvdCnt);
	$this -> assert_str_equals('1', $diskID);
	$this -> assert_str_equals('scsi', $diskCnt);
	$this -> assert_str_equals('sles', $guest);
	$this -> assert_str_equals('7', $hwver);
	$this -> assert_str_equals('1024', $mem);
	$this -> assert_str_equals('2', $numCPU);
	$this -> assert_str_equals('eth0', $nicIF);
	$this -> assert_str_equals('e1000', $nicDr);
	$this -> assert_str_equals('dhcp', $nicMod);
	return;
}

#==========================================
# test_getVMachineConfigXen
#------------------------------------------
sub test_getVMachineConfigXen {
	# ...
	# Test the getVMachineConfig method with a config set up for Xen
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'xenConfigSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $vmConfig = $xml -> getVMachineConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $confEnt = $vmConfig -> getConfigEntries();
	my $dev     = $vmConfig -> getSystemDiskDevice();
	my $dom     = $vmConfig -> getDomain();
	my $mem     = $vmConfig -> getMemory();
	my $numCPU  = $vmConfig -> getNumCPUs();
	my $nicMac  = $vmConfig -> getNICMAC(1);
	my @expectedOpts = qw / foo bar /;
	$this -> assert_array_equal(\@expectedOpts, $confEnt);
	$this -> assert_str_equals('/dev/xvda', $dev);
	$this -> assert_str_equals('domU', $dom);
	$this -> assert_str_equals('128', $mem);
	$this -> assert_str_equals('3', $numCPU);
	$this -> assert_str_equals('00:0C:6E:AA:57:2F', $nicMac);
	return ;
}

#==========================================
# test_getXenConfig_legacy
#------------------------------------------
sub test_getXenConfig_legacy {
	# ...
	# Verify proper return of Xen  configuration data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'xenConfigSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %vmConfig = $xml -> getXenConfig_legacy();
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
	return;
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
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> ignoreRepositories();
	my $msg = $kiwi -> getMessage();
	my $expected = 'Ignoring all repositories previously configured';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	my @repos = @{$xml -> getRepositories()};
	my $numRepos = scalar @repos;
	$this -> assert_equals(0, $numRepos);
	# Verify that all repositories have been removed
	my @profs = qw \profA profB profC\;
	$xml = $xml -> setSelectionProfileNames(\@profs);
	$expected = 'Using profile(s): profA, profB, profC';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	@repos = @{$xml -> getRepositories()};
	$numRepos = scalar @repos;
	$this -> assert_equals(0, $numRepos);
	return;
}

#==========================================
# test_ignoreRepositories_legacy
#------------------------------------------
sub test_ignoreRepositories_legacy {
	# ...
	# Verify proper operation of ignoreRepositories method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> ignoreRepositories_legacy();
	my %repos = $xml -> getRepositories_legacy();
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
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, \@reqProf, $this->{cmdL}
	);
	$this -> assert_null($xml);
	my $msg = $kiwi -> getErrorMessage();
	$this -> assert_str_equals('Profile profD: not found', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getErrorState();
	$this -> assert_str_equals('failed', $state);
	# for this test, just make sure everything in the log object gets reset
	$kiwi -> getState();
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $pkgMgr = $xml -> getPackageManager_legacy();
	$this -> assert_str_equals('zypper', $pkgMgr);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_packageManagerSet_noArg_legacy
#------------------------------------------
sub test_packageManagerSet_noArg_legacy {
	# ...
	# Verify of setPackageManager_legacy method error condition
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Call set without argument, expect error
	my $res = $xml -> setPackageManager_legacy();
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
	return;
}

#==========================================
# test_packageManagerSet_noArg_legacy
#------------------------------------------
sub test_packageManagerSet_valid_legacy {
	# ...
	# Verify setPackageManager_legacy works as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	# Set the package manager to be smart
	my $res = $xml -> setPackageManager_legacy('smart');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $PkgMgr= $xml -> getPackageManager_legacy();
	$this -> assert_str_equals('smart', $PkgMgr);
	return;
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
	my $xml = KIWIXML -> new(
		$confDir, undef,\@profiles,$this->{cmdL}
	);
	my $pkgMgr = $xml -> getPackageManager_legacy();
	$this -> assert_str_equals('smart', $pkgMgr);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): specPkgMgr', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Override the specified package manager with yum
	my $res = $xml -> setPackageManager_legacy('yum');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	my $PkgMgr= $xml -> getPackageManager_legacy();
	$this -> assert_str_equals('yum', $PkgMgr);
	return;
}


#==========================================
# test_setArch
#------------------------------------------
sub test_setArch {
	# ...
	# Verify that the setArch implementation behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'defPkgMgr';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> setArch('s390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	my $arch = $xml -> getArch();
	$this -> assert_str_equals('s390', $arch);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setArchInvalid
#------------------------------------------
sub test_setArchInvalid {
	# ...
	# Verify that the setArch implementation behaves as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'defPkgMgr';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> setArch('mips');
	my $msg = $kiwi -> getMessage();
	my $expected = "setArch: Specified arch 'mips' is not supported";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $arch = $xml -> getArch();
	my $curArch = qxx ("uname -m");
	if ($curArch =~ /i.86/) {
		$curArch = "ix86";
	}
	chomp $curArch;
	$this -> assert_str_equals($curArch, $arch);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_setBuildType
#------------------------------------------
sub test_setBuildType {
	# ...
	# Test the setBuildType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$xml = $xml -> setBuildType('vmx');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $typeInfo = $xml -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that we got the expected type
	my $imageType = $typeInfo -> getImageType();
	$this -> assert_str_equals('vmx', $imageType);
	return;
}

#==========================================
# test_setBuildTypeInvalidArg
#------------------------------------------
sub test_setBuildTypeInvalidArg {
	# ...
	# Test the setBuildType method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $res = $xml -> setBuildType('iso');
	$msg = $kiwi -> getMessage();
	my $expected = 'setBuildType: no type configuration exists for the '
			. "given type 'iso' in the current active profiles.";
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $typeInfo = $xml -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that we got the expected type
	my $imageType = $typeInfo -> getImageType();
	$this -> assert_str_equals('oem', $imageType);
	return;
}

#==========================================
# test_setBuildTypeNoArg
#------------------------------------------
sub test_setBuildTypeNoArg {
	# ...
	# Test the setBuildType method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $res = $xml -> setBuildType();
	$msg = $kiwi -> getMessage();
	my $expected = 'setBuildType: no type name given, retaining current '
		. 'build type setting.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $typeInfo = $xml -> getImageType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify that we got the expected type
	my $imageType = $typeInfo -> getImageType();
	$this -> assert_str_equals('oem', $imageType);
	return;
}

#==========================================
# test_setDescriptionInfo
#------------------------------------------
sub test_setDescriptionInfo {
	# ...
	# Verify that setting the description information has the expected results
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'descriptData';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my @contacts = ('rjschwei@suse.com');
	my %init = (
	    author        => 'Robert Schweikert',
		contact       => \@contacts,
		specification => 'test set method',
		type          => 'system'
	);
	my $descriptObj = KIWIXMLDescriptionData -> new (\%init);
	$xml = $xml -> setDescriptionInfo($descriptObj);
	my $descrpObj = $xml -> getDescriptionInfo();
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $author = $descrpObj -> getAuthor();
	$this -> assert_str_equals('Robert Schweikert', $author);
	my $contact = $descrpObj -> getContactInfo();
	$this -> assert_array_equal(\@contacts, $contact);
	my $spec = $descrpObj -> getSpecificationDescript();
	$this -> assert_str_equals('test set method', $spec);
	my $type = $descrpObj -> getType();
	$this -> assert_str_equals('system', $type);
	$this -> assert_not_null($xml);
	return;
}

#==========================================
# test_setDescriptionInfoImproperArg
#------------------------------------------
sub test_setDescriptionInfoImproperArg {
	# ...
	# Verify that setting the description information with an improper
	# argument type fails as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'descriptData';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my $res = $xml -> setDescriptionInfo($xml);
	$this -> assert_null($res);
	my $expected = 'setDescriptionInfo: Expecting KIWIXMLDescriptionData '
		. 'instance as argument.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	my $descrpObj = $xml -> getDescriptionInfo();
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $author = $descrpObj -> getAuthor();
	$this -> assert_str_equals('Robert Schweikert', $author);
	my $contact = $descrpObj -> getContactInfo();
	my @expectCont = ('rjschwei@suse.com', 'rschweikert@suse.com');
	$this -> assert_array_equal(\@expectCont, $contact);
	my $spec = $descrpObj -> getSpecificationDescript();
	$expected = 'Verify proper handling of description in XML obj';
	$this -> assert_str_equals($expected, $spec);
	my $type = $descrpObj -> getType();
	$this -> assert_str_equals('system', $type);
	return;
}

#==========================================
# test_setDescriptionInfoNoArg
#------------------------------------------
sub test_setDescriptionInfoNoArg {
	# ...
	# Verify that setting the description information with no provided
	# DescriptionData object fails as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'descriptData';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	my $res = $xml -> setDescriptionInfo();
	$this -> assert_null($res);
	my $expected = 'setDescriptionInfo: Expecting KIWIXMLDescriptionData '
			. 'instance as argument.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	my $descrpObj = $xml -> getDescriptionInfo();
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $author = $descrpObj -> getAuthor();
	$this -> assert_str_equals('Robert Schweikert', $author);
	my $contact = $descrpObj -> getContactInfo();
	my @expectCont = ('rjschwei@suse.com', 'rschweikert@suse.com');
	$this -> assert_array_equal(\@expectCont, $contact);
	my $spec = $descrpObj -> getSpecificationDescript();
	$expected = 'Verify proper handling of description in XML obj';
	$this -> assert_str_equals($expected, $spec);
	my $type = $descrpObj -> getType();
	$this -> assert_str_equals('system', $type);
	return;
}

#==========================================
# test_setPreferences
#------------------------------------------
sub test_setPreferences {
	# ...
	# Verify proper behavior of the setPreferences method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @profNames = ( 'profA' );
	$xml -> setSelectionProfileNames(\@profNames);
	$msg = $kiwi -> getMessage();
	my $expected = 'Using profile(s): profA';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $prefObj = $xml -> getPreferences();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# This is expected modify data in profA
	my $res = $prefObj -> setBootLoaderTheme('SLES');
	$this -> assert_not_null($res);
	# This is expected to modify data that exists in the default
	$res = $prefObj -> setRPMForce('true');
	$this -> assert_not_null($res);
	# This adds a new attribut to the default settings
	$res = $prefObj -> setHWClock('UTC');
	$this -> assert_not_null($res);
	$res = $xml -> setPreferences($prefObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Verify the default setting changes
	$res = $xml -> setSelectionProfileNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $prefDefault = $xml -> getPreferences();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Verify the changed setting in the default
	my $rpmF = $prefDefault -> getRPMForce();
	$this -> assert_str_equals('true', $rpmF);
	# Verify the new setting has been applied to the default
	my $clock = $prefDefault -> getHWClock();
	$this -> assert_str_equals('UTC', $clock);
	# Verify the setting for boot loader has not been applied to the default
	my $bLTheme = $prefDefault -> getBootLoaderTheme();
	$this -> assert_null($bLTheme);
	$xml -> setSelectionProfileNames(\@profNames);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$prefObj = $xml -> getPreferences();
	# Verify the boot loader theme has changed
	$bLTheme = $prefObj -> getBootLoaderTheme();
	$this -> assert_str_equals('SLES', $bLTheme);
	return;
}

#==========================================
# test_setPreferencesInvalArg
#------------------------------------------
sub test_setPreferencesInvalArg {
	# ...
	# Verify proper behavior of the setPreferences method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $res = $xml -> setPreferences('foo');
	$msg = $kiwi -> getMessage();
	my $expected = 'setPreferences: expecting ref to KIWIXMLPreferenceData '
		. ' as first argument';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setPreferencesNoArg
#------------------------------------------
sub test_setPreferencesNoArg {
	# ...
	# Verify proper behavior of the setPreferences method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettingsProfNoDef';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $res = $xml -> setPreferences();
	$msg = $kiwi -> getMessage();
	my $expected = 'setPreferences: expecting ref to KIWIXMLPreferenceData '
		. ' as first argument';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setRepositoryBasic
#------------------------------------------
sub test_setRepositoryBasic {
	# ...
	# Verify proper behavior of setRepository method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	my $repoData = KIWIXMLRepositoryData -> new(\%init);
	$xml = $xml -> setRepository($repoData);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Replacing repository '
		. 'http://download.opensuse.org/update/12.1';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Verify that the proper repo got replaced
	my @repoData = @{$xml -> getRepositories()};
	my $numRepos = @repoData;
	$this -> assert_equals(4, $numRepos);
	for my $repo (@repoData) {
		my $path = $repo -> getPath();
		if ($path eq 'http://download.opensuse.org/update/12.1') {
			$this -> assert_str_equals('Improper repo replace', $path);
		}
	}
	return;
}

#==========================================
# test_setRepositoryImproperArg
#------------------------------------------
sub test_setRepositoryImproperArg {
	# ...
	# Verify proper behavior of setRepository method when
	# called with an invalid argument type
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> setRepository('norepo');
	my $expected = 'setRepository: expecting ref to KIWIXMLRepositoryData '
		. ' as first argument';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setRepositoryNoArg
#------------------------------------------
sub test_setRepositoryNoArg {
	# ...
	# Verify proper behavior of setRepository method when
	# called with an invalid argument type
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> setRepository();
	my $expected = 'setRepository: expecting ref to KIWIXMLRepositoryData '
		. ' as first argument';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setRepositoryNoReplace
#------------------------------------------
sub test_setRepositoryNoReplace {
	# ...
	# Verify proper behavior of setRepository method and there is
	# repository marked as replacable
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigNoRepl';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	my $repoData = KIWIXMLRepositoryData -> new(\%init);
	my $res = $xml -> setRepository($repoData);
	my $expected = 'No replacable repository configured, not using repo with '
			. "path: '/work/repos/md'";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_setRepositoryNoReplaceWithProf
#------------------------------------------
sub test_setRepositoryNoReplaceWithProf {
	# ...
	# Verify proper behavior of setRepository method and there is
	# no repository marked as replacable in the active profile
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfigWithProf';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	my $repoData = KIWIXMLRepositoryData -> new(\%init);
	my $res = $xml -> setRepository($repoData);
	my $expected = 'No replacable repository configured, not using repo with '
			. "path: '/work/repos/md'";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($res);
	return;
}

#==========================================
# test_setRepository_legacy
#------------------------------------------
sub test_setRepository_legacy {
	# ...
	# Verify proper operation of setRepository method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> setRepository_legacy('rpm-md', '/repos/pckgs','replacement',
								'5');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Replacing repository '
		. 'http://download.opensuse.org/update/12.1';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my %repos = $xml -> getRepositories_legacy();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test these conditions last to get potential error messages
	my $numRepos = scalar keys %repos;
	$this -> assert_equals(4, $numRepos);
	my @repoInfo = @{$repos{'/tmp/12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-4]);
	@repoInfo = @{$repos{'https://myreposerver/protectedrepos/12.1'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('foo', $repoInfo[3]);
	$this -> assert_str_equals('bar', $repoInfo[4]);
	@repoInfo = @{$repos{'/repos/12.1-additional'}};
	$this -> assert_str_equals('rpm-dir', $repoInfo[0]);
	@repoInfo = @{$repos{'/repos/pckgs'}};
	$this -> assert_str_equals('rpm-md', $repoInfo[0]);
	$this -> assert_str_equals('replacement', $repoInfo[1]);
	$this -> assert_str_equals('5', $repoInfo[2]);
	# Assert the expected repo has been replaced
	my $repoInfo = $repos{'http://download.opensuse.org/update/12.1'};
	$this -> assert_null($repoInfo);
	return;
}

#==========================================
# test_setSelectionProfileNames
#------------------------------------------
sub test_setSelectionProfileNames {
	# ...
	# Verify that setting the active profiles works as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Clear out the initial setup message
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @newProfs = qw /profA profC/;
	$xml = $xml -> setSelectionProfileNames(\@newProfs);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA, profC', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	my $profNames = $xml -> getActiveProfileNames();
	# Test this condition last to get potential error messages
	$this -> assert_array_equal(\@newProfs, $profNames);
	return;
}

#==========================================
# test_setActiveProfilNamesImpropProf
#------------------------------------------
sub test_setSelectionProfileNamesImpropProf {
	# ...
	# Verify that setActiveProfiles generates the expected error
	# when called with an improper profile name
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Clear out the initial setup message
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my @newProfs = qw /profA timbuktu/;
	my $res = $xml -> setSelectionProfileNames(\@newProfs);
	$msg = $kiwi -> getMessage();
	my $expected = 'Attempting to set active profile to "timbuktu", '
		. 'but this profile is not specified in the configuration.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_not_null($xml);
	my $profNames = $xml -> getActiveProfileNames();
	# Test this condition last to get potential error messages
	my @expectedProf = ('profB');
	$this -> assert_array_equal(\@expectedProf, $profNames);
	return;
}

#==========================================
# test_setActiveProfilNamesInvalidArg
#------------------------------------------
sub test_setSelectionProfileNamesInvalidArg {
	# ...
	# Verify that setActiveProfiles generates the expected error
	# when called with an invalid argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Clear out the initial setup message
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $res = $xml -> setSelectionProfileNames('profA,profB');
	$msg = $kiwi -> getMessage();
	my $expected = 'setActiveProfiles, expecting array ref argument';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $profNames = $xml -> getActiveProfileNames();
	# Test this condition last to get potential error messages
	my @expectedProf = ('profB');
	$this -> assert_array_equal(\@expectedProf, $profNames);
	return;
}

#==========================================
# test_setActiveProfilNamesNoArg
#------------------------------------------
sub test_setSelectionProfileNamesNoArg {
	# ...
	# Verify that setActiveProfiles resets to the default state
	# when called with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfig';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef, $this->{cmdL}
	);
	# Clear out the initial setup message
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profB', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Set the profile to someting else
	my @newProfs = qw /profA profC/;
	$xml = $xml -> setSelectionProfileNames(\@newProfs);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): profA, profC', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	# Reset to the default configured state
	#TODO when the legacy profiles are removed from the XML this
	# message has to change to "Using...."
	$xml = $xml -> setSelectionProfileNames();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($xml);
	my $profNames = $xml -> getActiveProfileNames();
	# Test this condition last to get potential error messages
	my @expectedProf = ('profB');
	$this -> assert_array_equal(\@expectedProf, $profNames);
	return;
}

#==========================================
# test_sizeHandling
#------------------------------------------
sub test_sizeHandling {
	# ...
	# Verify that size is properly handled
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$confDir, undef, undef,$this->{cmdL}
	);
	my $typeObj = $xml -> getImageType();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $size = $typeObj -> getSize();
	$this -> assert_equals($PREFSET_IMAGE_SIZE, $size);
	my $unit = $typeObj -> getSizeUnit();
	$this -> assert_str_equals('G', $unit);
	my $add = $typeObj -> isSizeAdditive();
	$this -> assert_str_equals('false', $add);
	return;
}

1;
