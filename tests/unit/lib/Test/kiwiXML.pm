#================
# FILE          : kiwiXML.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIQX qw (qxx);
use KIWIXML;
use KIWIXMLDescriptionData;
use KIWIXMLDriverData;
use KIWIXMLEC2ConfigData;
use KIWIXMLOEMConfigData;
use KIWIXMLPreferenceData;
use KIWIXMLPXEDeployData;
use KIWIXMLRepositoryData;
use KIWIXMLSplitData;
use KIWIXMLSystemdiskData;
use KIWIXMLTypeData;
use KIWIXMLVMachineData;

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
	$this -> {kiwi} =  Common::ktLog -> new();
	$this -> {cmdL} = KIWICommandLine -> new($this->{kiwi});

	return $this;
}

#==========================================
# test_addArchives
#------------------------------------------
sub test_addArchives {
	# ...
	# Verify proper operation of addArchives method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addArchives('image', undef, undef, 'archiveA.tgz',
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
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addArchivesBootIncl
#------------------------------------------
sub test_addArchivesBootIncl {
	# ...
	# Verify proper operation of addArchives method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addArchives('image', 'true', undef, 'archiveA.tgz',
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
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addArchivesUseProf
#------------------------------------------
sub test_addArchivesUseProf {
	# ...
	# Verify proper operation of addArchives method
	# ---
	#
	# The handling is broken -- BUG --
	# We should either find all archives, or only the patterns specific
	# archives. The behavior at present is that the archives outside of the
	# profile are found.
	# disable test
#	my $this = shift;
#	my $kiwi = $this -> {kiwi};
#	my $confDir = $this->{dataDir} . 'packageSettings';
#    my @patterns = qw (aTest);
#	my $xml = KIWIXML -> new(
#		$this -> {kiwi}, $confDir, undef, \@patterns, $this->{cmdL}
#	);
#	$xml = $xml -> addArchives('image', undef, undef, 'archiveC.tgz',
#							'archiveD.tar.bz2');
#	my $msg = $kiwi -> getMessage();
#	$this -> assert_str_equals('Using profile(s): aTest', $msg);
#	my $msgT = $kiwi -> getMessageType();
#	$this -> assert_str_equals('info', $msgT);
#	my $state = $kiwi -> getState();
#	$this -> assert_str_equals('completed', $state);
#	# Test this condition last to get potential error messages
#	my @expectedArchs = qw /myAppArch.tgz archiveC.tgz archiveD.tar.bz2/;
#	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
#	$msg = $kiwi -> getMessage();
#	$this -> assert_str_equals('No messages set', $msg);
#	$msgT = $kiwi -> getMessageType();
#	$this -> assert_str_equals('none', $msgT);
#	$state = $kiwi -> getState();
#	$this -> assert_str_equals('No state set', $state);
#	my @archives;
#	IMGARCHS:
#	for my $node (@packNodes) {
#		my $type = $node -> getAttribute('type');
#		if ($type eq 'image') {
#			my @archiveNodes = $node -> getElementsByTagName('archive');
#			for my $archNode (@archiveNodes) {
#				push @archives, $archNode -> getAttribute('name');
#			}
#			last IMGARCHS;
#		}
#	}
#	$this -> assert_array_equal(\@expectedArchs, \@archives);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @drvNames = qw /vboxsf epat dcdbas/;
	my @drvsToAdd = ();
	for my $drv (@drvNames) {
		push @drvsToAdd, KIWIXMLDriverData -> new($kiwi, $drv);
	}
	push @drvsToAdd, 'slip';
	push @drvsToAdd, KIWIXMLDriverData -> new($kiwi, 'x25_asy');
	my $res = $xml -> addDrivers(\@drvsToAdd, 'default');
	my $expected = 'addDrivers: found array item not of type '
		. 'KIWIXMLDriverData in driver array';
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @drvNames = qw /vboxsf epat dcdbas/;
	my @drvsToAdd = ();
	for my $drv (@drvNames) {
		push @drvsToAdd, KIWIXMLDriverData -> new($kiwi, $drv);
	}
	my @profs = qw \profA timbuktu profB\;
	my $res = $xml -> addDrivers(\@drvsToAdd, \@profs);
	my $expected = "Attempting to add driver(s) to 'timbuktu', but "
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addDrivers();
	my $expected = 'addDrivers: no drivers specified, nothing to do';
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		push @drvsToAdd, KIWIXMLDriverData -> new($kiwi, \%init);
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
	} else {
		push @expectedDrvs, 'pc300too';
	}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	# Add the drivers, using the keyword "default" as 2nd arg
	my @drvNames = qw /vboxsf epat dcdbas/;
	my @drvsToAdd = ();
	for my $drv (@drvNames) {
		my %init = ( name => $drv );
		push @drvsToAdd, KIWIXMLDriverData -> new($kiwi, \%init);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addDrivers ('loop', 'default');
	my $expected = 'addDrivers: expecting array ref for XMLDriverData array '
		. 'as first argument';
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_addImagePackages
#------------------------------------------
sub test_addImagePackages {
	# ...
	# Verify proper operation of addImagePackages method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addImagePackages('perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /ed emacs kernel-default perl python vim/;
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addImagePatterns
#------------------------------------------
sub test_addImagePatterns {
	# ...
	# Verify proper operation of addImagePatterns method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addImagePatterns('gnome', 'kde');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPats = qw /base gnome kde xfce/;
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addPackagesBootstrap
#------------------------------------------
sub test_addPackagesBootstrap {
	# ...
	# Verify proper operation of addPackages method for bootstrap type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages('bootstrap', undef, undef, 'perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /emacs filesystem glibc-locale perl/;
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addPackagesImage
#------------------------------------------
sub test_addPackagesImage {
	# ...
	# Verify proper operation of addPackages method for image type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages('image', undef, undef, 'perl', 'emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /ed emacs kernel-default perl python vim/;
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addPackagesImageBootIncl
#------------------------------------------
sub test_addPackagesImageBootIncl {
	# ...
	# Verify proper operation of addPackages method for image type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %bootInclPacks = ( emacs => 1 );
	$xml = $xml -> addPackages('image', \%bootInclPacks, undef,'perl','emacs');
	#$xml = $xml -> addPackages('image', undef, undef,'perl','emacs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPcks = qw /ed emacs kernel-default perl python vim/;
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addPackagesNoBootstrap
#------------------------------------------
sub test_addPackagesNoBootstrap {
	# ...
	# Verify proper operation of addPackages method if not bootstrap packages
	# is defined
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsNoBootstrap';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages('bootstrap', undef, undef, 'perl', 'emacs');
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
# test_addPackagesNoImage
#------------------------------------------
sub test_addPackagesNoImage {
	# ...
	# Verify proper operation of addPackages method if not image packages
	# is defined
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsNoImage';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages('image', undef, undef, 'perl', 'emacs');
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
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addPackagesUnknownType
#------------------------------------------
sub test_addPackagesUnknownType {
	# ...
	# Verify proper operation of addPackages method for bootstrap type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPackages('vmx', undef, undef, 'perl', 'emacs');
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
# test_addPatterns
#------------------------------------------
sub test_addPatterns {
	# ...
	# Verify proper operation of addPatterns method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addPatterns('image', undef, 'gnome', 'kde');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPats = qw /base gnome kde xfce/;
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
# test_addRemovePackages
#------------------------------------------
sub test_addRemovePackages {
	# ...
	# Verify proper operation of addRemovePackages method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> addRemovePackages('gnome-shell', 'cups');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedDel = qw /cups java gnome-shell/;
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
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
		if ($path ne 'opensuse://12.1/repo/oss/' &&
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%dupAliasData);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%confPass);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
	my %init2 = (
				path => 'opensuse://12.1/repo/oss/',
				type => 'rpm-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init2);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%prefLic);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%confUser);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
	my %init2 = (
				path => '/work/repos/pckgs',
				type => 'rpm-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init2);
	push @reposToAdd, 'slip';
	my %init3 = (
				path => '/work/repos/debs',
				type => 'deb-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init3);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
	my %init2 = (
				path => '/work/repos/pckgs',
				type => 'rpm-dir'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init2);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @reposToAdd = ();
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	push @reposToAdd, KIWIXMLRepositoryData -> new($kiwi, \%init);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> addRepositories('opensuse:///', 'profA');
	my $expected = 'addRepositories: expecting array ref for '
		. 'XMLRepositoryData array as first argument';
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
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
# test_addStripConsistentCall
#------------------------------------------
sub test_addStripConsistentCall {
	# ...
	# Verify proper operation of addStrip method with improper argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @Del= qw (/etc/hosts /bin/zsh);
	$xml -> addStrip ('files', @Del);
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
	return;
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
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @Del= qw (/etc/hosts /bin/zsh);
	$xml -> addStrip ('delete', @Del);
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
	return;
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
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @Del= qw (/etc/hosts /bin/zsh);
	$xml -> addStrip ('delete', @Del);
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
	return;
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
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @Libs= qw /libm libcrypt/;
	$xml -> addStrip ('libs', @Libs);
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
	return;
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
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @Tools= qw /xfsrestore install-info/;
	$xml -> addStrip ('tools', @Tools);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
# test_getArchiveList
#------------------------------------------
sub test_getArchiveList {
	# ...
	# Verify proper return of getArchiveList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @archives = $xml -> getArchiveList();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /myInitStuff.tar myImageStuff.tgz/;
	$this -> assert_array_equal(\@expected, \@archives);
	return;
}

#==========================================
# test_getArchiveListUseProf
#------------------------------------------
sub test_getArchiveListUseProf {
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
		$this -> {kiwi}, $confDir, undef, \@patterns, $this->{cmdL}
	);
	my @archives = $xml -> getArchiveList();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /myAppArch.tgz myInitStuff.tar myImageStuff.tgz/;
	$this -> assert_array_equal(\@expected, \@archives);
	return;
}

#==========================================
# test_getBaseList
#------------------------------------------
sub test_getBaseList {
	# ...
	# Verify proper return of getBaseList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @basePcks = $xml -> getBaseList();
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
# test_getBootIncludes
#------------------------------------------
sub test_getBootIncludes {
	# ...
	# Verify proper return of getBootIncludes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @bootInclP = $xml -> getBootIncludes();
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
# test_getBootIncludesUseProf
#------------------------------------------
sub test_getBootIncludesUseProf {
	# ...
	# Verify proper return of getBootIncludes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, \@patterns, $this->{cmdL}
	);
	my @bootInclP = $xml -> getBootIncludes();
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getDeleteList
#------------------------------------------
sub test_getDeleteList {
	# ...
	# Verify proper return of getDeleteList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @delPcks = $xml -> getDeleteList();
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
# test_getDeleteListUseProf
#------------------------------------------
sub test_getDeleteListUseProf {
	# ...
	# Verify proper return of getDeleteList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, \@patterns, $this->{cmdL}
	);
	my @delPcks = $xml -> getDeleteList();
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
# test_getDeleteListInstallDelete
#------------------------------------------
sub test_getDeleteListInstallDelete {
	# ...
	# Verify proper return of getDeleteList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsInstallDelete';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @delPcks = $xml -> getDeleteList();
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
	$this -> assert_str_equals('rjschwei@suse.com', $contact);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getDriversNodeList
#------------------------------------------
sub test_getDriversNodeList {
	# ...
	# Verify proper return of getDriversNodeList method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'driversConfig';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getEc2Config_legacy
#------------------------------------------
sub test_getEc2Config_legacy {
	# ...
	# Verify proper return of EC2 configuration settings
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'ec2ConfigSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %ec2Info = $xml -> getEc2Config_legacy();
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getImageVersion
#------------------------------------------
sub test_getImageVersion {
	# ...
	# Verify proper return of getImageVersion method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
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
	return;
}

#==========================================
# test_getInstallList
#------------------------------------------
sub test_getInstallList {
	# ...
	# Verify proper return of getInstallList method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsNoPattern';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @instPcks = $xml -> getInstallList();
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getLocale
#------------------------------------------
sub test_getLocale {
	# ...
	# Verify proper return of getLocale method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getOVFConfig_legacy
#------------------------------------------
sub test_getOVFConfig_legacy {
	#...
	# Verify proper return of the OVF data
	#---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'ovfConfigSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %ovfConfig = $xml -> getOVFConfig_legacy();
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $pxeConfObj = $xml -> getPXEConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $blockS   = $pxeConfObj -> getBlocksize();
	my $confArch = $pxeConfObj -> getConfigurationArch();
	my $confDest = $pxeConfObj -> getConfigurationDestination();
	my $confSrc  = $pxeConfObj -> getConfigurationSource();
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
	my @expectedArch = qw /x86_64 ix86 armv5tel armv7l ppc64 ppc/;
	$this -> assert_array_equal(\@expectedArch, $confArch);
	$this -> assert_str_equals('target', $confDest);
	$this -> assert_str_equals('installSource', $confSrc);
	$this -> assert_str_equals('/dev/sda', $target);
	$this -> assert_str_equals('/pxeSetup/specialInitrd', $initrd);
	$this -> assert_str_equals('/pxeSetup/specialKernel', $kernel);
	$this -> assert_str_equals('/', $mntP);
	$this -> assert_equals(2, $partN);
	$this -> assert_str_equals('image', $partS);
	$this -> assert_str_equals('true', $partT);
	$this -> assert_str_equals('L', $partTy);
	$this -> assert_str_equals('192.168.100.2', $server);
	$this -> assert_str_equals('20', $timeout);
	$this -> assert_str_equals('/dev/sda2', $unionRO);
	$this -> assert_str_equals('/dev/sda3', $unionRW);
	$this -> assert_str_equals('clicfs', $unionT);
	return;
}

#==========================================
# test_getPXEDeployBlockSize_legacy
#------------------------------------------
sub test_getPXEDeployBlockSize_legacy {
	# ...
	# Verify proper return of getPXEDeployBlockSize method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployBlockSize_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('4096', $value);
	return;
}

#==========================================
# test_getPXEDeployConfiguration_legacy
#------------------------------------------
sub test_getPXEDeployConfiguration_legacy {
	# ...
	# Verify proper return of getPXEDeployConfiguration method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %config = $xml -> getPXEDeployConfiguration_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null(%config);
	$this -> assert_str_equals('target', $config{installSource});
	return;
}

#==========================================
# test_getPXEDeployImageDevice_legacy
#------------------------------------------
sub test_getPXEDeployImageDevice_legacy {
	# ...
	# Verify proper return of getPXEDeployImageDevice method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployImageDevice_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/dev/sda', $value);
	return;
}

#==========================================
# test_getPXEDeployInitrd_legacy
#------------------------------------------
sub test_getPXEDeployInitrd_legacy {
	# ...
	# Verify proper return of getPXEDeployInitrd method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployInitrd_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/pxeSetup/specialInitrd', $value);
	return;
}

#==========================================
# test_getPXEDeployKernel_legacy
#------------------------------------------
sub test_getPXEDeployKernel_legacy {
	# ...
	# Verify proper return of getPXEDeployKernel method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployKernel_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('/pxeSetup/specialKernel', $value);
	return;
}

#==========================================
# test_getPXEDeployPartitions_legacy
#------------------------------------------
sub test_getPXEDeployPartitions_legacy {
	# ...
	# Verify proper return of getPXEDeployPartitions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @partitions = $xml -> getPXEDeployPartitions_legacy();
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
	return;
}

#==========================================
# test_getPXEDeployServer_legacy
#------------------------------------------
sub test_getPXEDeployServer_legacy {
	# ...
	# Verify proper return of getPXEDeployServer method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployServer_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('192.168.100.2', $value);
	return;
}

#==========================================
# test_getPXEDeployTimeout_legacy
#------------------------------------------
sub test_getPXEDeployTimeout_legacy {
	# ...
	# Verify proper return of getPXEDeployTimeout method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getPXEDeployTimeout_legacy();
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
# test_getPXEDeployUnionConfig_legacy
#------------------------------------------
sub test_getPXEDeployUnionConfig_legacy {
	# ...
	# Verify proper return of getPXEDeployUnionConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'pxeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %unionConfig = $xml -> getPXEDeployUnionConfig_legacy();
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
	return;
}

#==========================================
# test_getPackageAttributes
#------------------------------------------
sub test_getPackageAttributes {
	# ...
	# Verify proper return of getPackageAttributes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
	);
	my %pattr = $xml -> getPackageAttributes('image');;
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
# test_getPackageAttributesUseProf
#------------------------------------------
sub test_getPackageAttributesUseProf {
	# ...
	# Verify proper return of getPackageAttributes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, \@patterns, $this->{cmdL}
	);
	my %pattr = $xml -> getPackageAttributes('image');;
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
# test_getPackageNodeList
#------------------------------------------
sub test_getPackageNodeList {
	# ...
	# Verify proper return of getPackageNodeList method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
	);
	my @packNodes = $xml -> getPackageNodeList() -> get_nodelist();
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
# test_getRPMCheckSignatures_legacy
#------------------------------------------
sub test_getRPMCheckSignatures_legacyFalse {
	# ...
	# Verify proper return of getRPMCheckSignatures_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMCheckSignatures_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($value);
	return;
}

#==========================================
# test_getRPMExcludeDocs_legacy
#------------------------------------------
sub test_getRPMExcludeDocs_legacyFalse {
	# ...
	# Verify proper return of getRPMExcludeDocs_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMExcludeDocs_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($value);
	return;
}

#==========================================
# test_getRPMForce_legacy
#------------------------------------------
sub test_getRPMForce_legacyFalse {
	# ...
	# Verify proper return of getRPMForce_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'oemSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMForce_legacy();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($value);
	return;
}

#==========================================
# test_getRPMCheckSignatures_legacy
#------------------------------------------
sub test_getRPMCheckSignatures_legacyTrue {
	# ...
	# Verify proper return of getRPMCheckSignatures_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMCheckSignatures_legacy();
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
# test_getRPMExcludeDocs_legacy
#------------------------------------------
sub test_getRPMExcludeDocs_legacyTrue {
	# ...
	# Verify proper return of getRPMExcludeDocs_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMExcludeDocs_legacy();
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
# test_getRPMForce_legacy
#------------------------------------------
sub test_getRPMForce_legacyTrue {
	# ...
	# Verify proper return of getRPMForce_legacy method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getRPMForce_legacy();
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	# Call getList to trigger the generation of the replace-add list as
	# a side effect :(
	my @gL = $xml -> getList('image');
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	# Call getList to trigger the generation of the replace-delete list as
	# a side effect :(
	my @gL = $xml -> getList('image');
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @repoNodes = $xml -> getRepoNodeList_legacy() -> get_nodelist();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	my @expectedPaths = ['opensuse://12.1/repo/oss/',
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		if ( $repoDataObj -> getPath() eq 'opensuse://12.1/repo/oss/' ) {
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> assert_str_equals('opensuse://12.1/repo/oss/',
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
		if ( $repoDataObj -> getPath() eq 'opensuse://12.1/repo/oss/' ) {
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
		if ( $repoDataObj -> getPath() eq 'opensuse://12.1/repo/oss/' ) {
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
# test_getRepositories_legacy
#------------------------------------------
sub test_getRepositories_legacy {
	# ...
	# Verify proper return of getRepositories method
	# ---
	if ($ENV{KIWI_NO_NET} && $ENV{KIWI_NO_NET} == 1) {
		return; # skip the test if there is no network connection
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %repos = $xml -> getRepositories_legacy();
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
	@repoInfo = @{$repos{'https://myreposerver/protectedrepos/12.1'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('foo', $repoInfo[3]);
	$this -> assert_str_equals('bar', $repoInfo[4]);
	@repoInfo = @{$repos{'/repos/12.1-additional'}};
	$this -> assert_str_equals('rpm-dir', $repoInfo[0]);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	$this -> assert_array_equal(\@persExceptExpect, $persExcept);
	$this -> assert_array_equal(\@persFilesExpect, $persFiles);
	$this -> assert_array_equal(\@tmpExceptExpect, $tmpExcept);
	$this -> assert_array_equal(\@tmpFilesExpect, $tmpFiles);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getStripDelete
#------------------------------------------
sub test_getStripDelete {
	# ...
	# Verify proper return of getStripDelete method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'stripConfig';
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getTypes
#------------------------------------------
sub test_getTypes {
	# ...
	# Verify proper return of getTypes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @types = $xml -> getTypes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('vmx', $types[0]->{type});
	$this -> assert_str_equals('true', $types[0]->{primary});
	$this -> assert_str_equals('oem', $types[1]->{type});
	return;
}

#==========================================
# test_getTypesUseProf
#------------------------------------------
sub test_getTypesUseProf {
	# ...
	# Verify proper return of getTypes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettings';
	my @patterns = qw (aTest);
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, \@patterns, $this->{cmdL}
	);
	my @types = $xml -> getTypes();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals('vmx', $types[0]->{type});
	$this -> assert_str_equals('true', $types[0]->{primary});
	$this -> assert_str_equals('oem', $types[1]->{type});
	$this -> assert_str_equals('pxe', $types[2]->{type});
	$this -> assert_str_equals('vmx', $types[3]->{type});
	return;
}

#==========================================
# test_getTypeSpecificPackageList
#------------------------------------------
sub test_getTypeSpecificPackageList {
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @pckgs = $xml -> getTypeSpecificPackageList();
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
# test_getTypeSpecificPackageListUseProf
#------------------------------------------
sub test_getTypeSpecificPackageListUseProf {
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
		$this -> {kiwi}, $confDir, undef, \@patterns, $this->{cmdL}
	);
	my @pckgs = $xml -> getTypeSpecificPackageList();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('Using profile(s): aTest', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	my @expected = qw /gimp kernel-firmware sane/;
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $vmConfig = $xml -> getVMachineConfig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $desMem = $vmConfig -> getDesiredMemory();
	my $maxMem = $vmConfig -> getMaxMemory();
	my $mem    = $vmConfig -> getMemory();
	my $minMem = $vmConfig -> getMinMemory();
	my $desCPU = $vmConfig -> getDesiredCPUCnt();
	my $maxCPU = $vmConfig -> getMaxCPUCnt();
	my $cpu    = $vmConfig -> getNumCPUs();
	my $minCPU = $vmConfig -> getMinCPUCnt();
	my $oType  = $vmConfig -> getOVFType();
	my $diskID = $vmConfig -> getSystemDiskDevice();
	my $diskT  = $vmConfig -> getSystemDiskType();
	my $nicIf  = $vmConfig -> getNICInterface(1);
	$this -> assert_str_equals('1024', $desMem);
	$this -> assert_str_equals('2048', $maxMem);
	$this -> assert_str_equals('1024', $mem);
	$this -> assert_str_equals('512', $minMem);
	$this -> assert_str_equals('2', $desCPU);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_getVMwareConfig_legacy
#------------------------------------------
sub test_getVMwareConfig_legacy {
	# ...
	# Verify proper return of VMWare configuration data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'vmwareConfigSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %vmConfig = $xml -> getVMwareConfig_legacy();
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
	return;
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
# test_hasDefaultPackages
#------------------------------------------
sub test_hasDefaultPackages {
	# ...
	# Verify proper operation of hasDefaultPackages method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> hasDefaultPackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_equals(1, $res);
	return;
}

#==========================================
# test_hasDefaultPackagesNoDef
#------------------------------------------
sub test_hasDefaultPackagesNoDef {
	# ...
	# Verify proper operation of hasDefaultPackages method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'packageSettingsNoDefault';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $res = $xml -> hasDefaultPackages();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_equals(0, $res);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> ignoreRepositories();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Ignoring all repositories previously configured';
	$this -> assert_str_equals($expectedMsg, $msg);
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
	my $expected = 'Using profile(s): profA, profB, profC';
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef,\@profiles,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
	);
	my %init = (
				author        => 'Robert Schweikert',
				contact       => 'rjschwei@suse.com',
				specification => 'test set method',
				type          => 'system'
	);
	my $descriptObj = KIWIXMLDescriptionData -> new ($kiwi, \%init);
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
	$this -> assert_str_equals('rjschwei@suse.com', $contact);
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
	$this -> assert_str_equals('rjschwei@suse.com', $contact);
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
	$this -> assert_str_equals('rjschwei@suse.com', $contact);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	my $repoData = KIWIXMLRepositoryData -> new($kiwi, \%init);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	my $repoData = KIWIXMLRepositoryData -> new($kiwi, \%init);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my %init = (
				path => '/work/repos/md',
				type => 'rpm-md'
	);
	my $repoData = KIWIXMLRepositoryData -> new($kiwi, \%init);
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
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
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
	my @repoInfo = @{$repos{'opensuse://12.1/repo/oss/'}};
	$this -> assert_str_equals('yast2', $repoInfo[0]);
	$this -> assert_str_equals('2', $repoInfo[2]);
	$this -> assert_str_equals('true', $repoInfo[-2]);
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
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

1;
