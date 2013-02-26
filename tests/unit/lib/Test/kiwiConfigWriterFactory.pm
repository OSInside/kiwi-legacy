#================
# FILE          : kiwiConfigWriterFactory.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIConfigWriterFactory
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiConfigWriterFactory;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIConfigWriterFactory;
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

	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the KIWIConfigWriterFactory
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $xml = $this -> __getXMLObj($confDir);
	my $wFact = KIWIConfigWriterFactory -> new($xml, '/tmp');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($wFact);
	return;
}

#==========================================
# test_ctor_dirNoExist
#------------------------------------------
sub test_ctor_dirNoExist {
	# ...
	# Test the KIWIConfigWriterFactory with directory argument of
	# non existing directory
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $xml = $this -> __getXMLObj($confDir);
	my $wFact = KIWIConfigWriterFactory -> new($xml, '/foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIConfigWriterFactory: configuration target directory '
		. 'does not exist.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($wFact);
	return;
}

#==========================================
# test_ctor_invalidArg1
#------------------------------------------
sub test_ctor_invalidArg1 {
	# ...
	# Test the KIWIConfigWriterFactory with invalid first argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $wFact = KIWIConfigWriterFactory -> new('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIConfigWriterFactory: expecting KIWIXML object as '
		. 'first argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($wFact);
	return;
}

#==========================================
# test_ctor_noArg1
#------------------------------------------
sub test_ctor_noArg1 {
	# ...
	# Test the KIWIConfigWriterFactory with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $wFact = KIWIConfigWriterFactory -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIConfigWriterFactory: expecting KIWIXML object as '
		. 'first argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($wFact);
	return;
}

#==========================================
# test_ctor_noArg2
#------------------------------------------
sub test_ctor_noArg2 {
	# ...
	# Test the KIWIConfigWriterFactory with no second argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir};
	my $xml = $this -> __getXMLObj($confDir);
	my $wFact = KIWIConfigWriterFactory -> new($xml);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIConfigWriterFactory: expecting configuration target '
		. 'directory as second argument.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($wFact);
	return;
}

#==========================================
# test_expectContWriter
#------------------------------------------
sub test_expectContWriter {
	# ...
	# Test the getConfigWriter method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDir = $this -> {dataDir} . '/container';
	my $xml = $this -> __getXMLObj($confDir);
	my $wFact = KIWIConfigWriterFactory -> new($xml, '/tmp');
	$this -> assert_not_null($wFact);
	my $writer = $wFact -> getConfigWriter();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_str_equals(ref($writer), 'KIWIContainerConfigWriter');
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
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
	my $cmdL = KIWICommandLine -> new();
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
