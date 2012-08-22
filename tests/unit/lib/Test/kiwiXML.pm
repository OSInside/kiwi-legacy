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
	my $expected = 'addDrivers: found list item not of type '
		. 'KIWIXMLDriverData in driver list';
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
	my $expected = 'Attempting to add drivers to "timbuktu", but '
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
	$xml = $xml -> setActiveProfileNames(\@useProf);
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
		push @drvsToAdd, KIWIXMLDriverData -> new($kiwi, $drv);
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
	$xml = $xml -> setActiveProfileNames();
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
		push @drvsToAdd, KIWIXMLDriverData -> new($kiwi, $drv);
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
# test_getBootTheme
#------------------------------------------
sub test_getBootTheme {
	# ...
	# Verify proper return of getBootTheme method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
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
# test_getDefaultPrebuiltDir
#------------------------------------------
sub test_getDefaultPrebuiltDir {
	# ...
	# Verify proper return of getDefaultPrebuiltDir method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $value = $xml -> getDefaultPrebuiltDir();
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
# test_getEc2Config
#------------------------------------------
sub test_getEc2Config {
	# ...
	# Verify proper return of EC2 configuration settings
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'ec2ConfigSettings';
	my $xml = KIWIXML -> new(
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
	return;
}

#==========================================
# test_getEditBootConfig
#------------------------------------------
sub test_getEditBootConfig {
	# ...
	# Verify proper return of getEditBootConfig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'typeSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $path = $xml -> getEditBootConfig();
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
# test_getImageDefaultDestination
#------------------------------------------
sub test_getImageDefaultDestination {
	# ...
	# Verify proper return of getImageDefaultDestination method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
# test_getImageTypeAndAttributes
#------------------------------------------
sub test_getImageTypeAndAttributesSimple {
	# ...
	# Verify proper return of getImageTypeAndAttributes method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
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
# test_getLicenseNames
#------------------------------------------
sub test_getLicenseNames {
	# ...
	# Verify proper return of getLicenseNames method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'preferenceSettings';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my $licNames = $xml -> getLicenseNames();
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
# test_getLVMGroupName
#------------------------------------------
sub test_getLVMGroupName {
	# ...
	# Verify proper return of getLVMGroupName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'lvmConfig';
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
# test_getSplitPersistentExceptions
#------------------------------------------
sub test_getSplitPersistentExceptions {
	# ...
	# Verify proper return of getSplitPersistentExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'splitSettings';
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
# test_getVMwareConfig
#------------------------------------------
sub test_getVMwareConfig {
	# ...
	# Verify proper return of VMWare configuration data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'vmwareConfigSettings';
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	my $pkgMgr = $xml -> getPackageManager();
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
# test_packageManagerSet_noArg
#------------------------------------------
sub test_packageManagerSet_noArg {
	# ...
	# Verify of setPackageManager method error condition
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'specPkgMgr';
	my $xml = KIWIXML -> new(
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
	return;
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
	my $xml = KIWIXML -> new(
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
	my $PkgMgr= $xml -> getPackageManager();
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
	my $PkgMgr= $xml -> getPackageManager();
	$this -> assert_str_equals('yum', $PkgMgr);
	return;
}

#==========================================
# test_setActiveProfileNames
#------------------------------------------
sub test_setActiveProfileNames {
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
	$xml = $xml -> setActiveProfileNames(\@newProfs);
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
sub test_setActiveProfileNamesImpropProf {
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
	my $res = $xml -> setActiveProfileNames(\@newProfs);
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
sub test_setActiveProfileNamesInvalidArg {
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
	my $res = $xml -> setActiveProfileNames('profA,profB');
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
sub test_setActiveProfileNamesNoArg {
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
	$xml = $xml -> setActiveProfileNames(\@newProfs);
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
	$xml = $xml -> setActiveProfileNames();
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
	my $descriptObj = KIWIXMLDescriptionData -> new ($kiwi,
													'Robert Schweikert',
													'rjschwei@suse.com',
													'test set method',
													'system'
													);
	$xml = $xml -> setDescriptionInfo($descriptObj);
	$this -> assert_not_null($xml);
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
# test_setDescriptionInfoInvalArg
#------------------------------------------
sub test_setDescriptionInfoInvalArg {
	# ...
	# Verify that setting the description information with an invalid
	# DescriptionData object fails as expected
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'descriptData';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef, $this->{cmdL}
	);
	my $descriptObj = KIWIXMLDescriptionData -> new ($kiwi,
													'Robert Schweikert',
													'rjschwei@suse.com',
													);
	my $res = $xml -> setDescriptionInfo($descriptObj);
	$this -> assert_null($res);
	my $msg =  $kiwi -> getWarningMessage();
	my $expected = 'XMLDescriptionData object in invalid state';
	$this -> assert_str_equals($expected, $msg);
	my $state = $kiwi -> getOopsState();
	$this -> assert_str_equals('oops', $state);
	$expected = 'setDescriptionInfo: Provided KIWIXMLDescriptionData '
		. 'instance is not valid.';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
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
# test_setSelectionProfiles
#------------------------------------------
sub test_setSelectionProfiles {
	# ...
	# Verify proper operation of setSelectionProfiles method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'profilesConfigNoDef';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @profsToUse = qw /profA profB/;
	$xml = $xml -> setSelectionProfiles(\@profsToUse);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Using profile(s): profA, profB';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($xml);
	return;
}

#==========================================
# test_setSelectionProfilesInvalidProf
#------------------------------------------
sub test_setSelectionProfilesInvalidProf {
	# ...
	# Verify proper operation of setSelectionProfiles method when called with
	# improper selection
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	my @profsToUse = ('profTest',);
	$xml = $xml -> setSelectionProfiles(\@profsToUse);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = "Cannot select profile 'profTest', "
		. 'not specified in XML';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($xml);
	return;
}

#==========================================
# test_setSelectionProfilesNoArg
#------------------------------------------
sub test_setSelectionProfilesNoArg {
	# ...
	# Verify proper operation of setSelectionProfiles method when called with
	# no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> setSelectionProfiles();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'No profiles specified, nothing selecetd';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('skipped', $state);
	$this -> assert_not_null($xml);
	return;
}

#==========================================
# test_setSelectionProfilesWrongArg
#------------------------------------------
sub test_setSelectionProfilesWrongArg {
	# ...
	# Verify proper operation of setSelectionProfiles method when called with
	# an icorrect type argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this->{dataDir} . 'reposConfig';
	my $xml = KIWIXML -> new(
		$this -> {kiwi}, $confDir, undef, undef,$this->{cmdL}
	);
	$xml = $xml -> setSelectionProfiles(1);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Expecting array ref as argument for '
		. 'setSelectionProfiles';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($xml);
	return;
}

1;
