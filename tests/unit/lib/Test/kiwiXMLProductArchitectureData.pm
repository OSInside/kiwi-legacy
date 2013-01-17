#================
# FILE          : kiwiXMLProductArchitectureData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the
#               : KIWIXMLProductArchitectureData module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLProductArchitectureData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLProductArchitectureData;

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
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the ProductArchitectureData constructor with an improper
	# argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prodArchObj = KIWIXMLProductArchitectureData -> new('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prodArchObj);
	return;
}

#==========================================
# test_ctor_initInvalidFallback
#------------------------------------------
sub test_ctor_initInvalidFallback {
	# ...
	# Test the ProductArchitectureData constructor with an initialization hash
	# that contains an unrecognized value for the fallback value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = (
		fallback => 'i786',
		id       => 'i686',
		name     => 'intel'
	);
	my $prodArchObj = KIWIXMLProductArchitectureData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = "Specified 'fallback' has unexpected value 'i786'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prodArchObj);
	return;
}

#==========================================
# test_ctor_initInvalidID
#------------------------------------------
sub test_ctor_initInvalidID {
	# ...
	# Test the ProductArchitectureData constructor with an initialization hash
	# that contains an unrecognized value for the id value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = (
		id   => 'tegra',
		name => 'arm'
	);
	my $prodArchObj = KIWIXMLProductArchitectureData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = "Specified 'id' has unexpected value 'tegra'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prodArchObj);
	return;
}

#==========================================
# test_ctor_initInvalidNoID
#------------------------------------------
sub test_ctor_initInvalidNoID {
	# ...
	# Test the ProductArchitectureData constructor with an initialization hash
	# that contains no id entry.
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = (
		name => 'arm'
	);
	my $prodArchObj = KIWIXMLProductArchitectureData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProductArchitectureData: no "id" specified in '
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prodArchObj);
	return;
}

#==========================================
# test_ctor_initInvalidNoName
#------------------------------------------
sub test_ctor_initInvalidNoName {
	# ...
	# Test the ProductArchitectureData constructor with an initialization hash
	# that contains no name entry.
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = (
		id => 'ppc64'
	);
	my $prodArchObj = KIWIXMLProductArchitectureData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProductArchitectureData: no "name" specified in '
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prodArchObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
	# ...
	# Test the ProductArchitectureData constructor with an initialization hash
	# that contains unsupported data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( arch => 'ia64' );
	my $prodArchObj = KIWIXMLProductArchitectureData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProductArchitectureData: Unsupported keyword '
		. "argument 'arch' in initialization structure.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prodArchObj);
	return;
}

#==========================================
# test_getFallbackArch
#------------------------------------------
sub test_getFallbackArch {
	# ...
	# Test the getFallbackArch method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prodArchObj = $this -> __getProdArchObj();
	my $fallback = $prodArchObj -> getFallbackArch();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('noarch', $fallback);
	return;
}

#==========================================
# test_getID
#------------------------------------------
sub test_getID {
	# ...
	# Test the getID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prodArchObj = $this -> __getProdArchObj();
	my $id = $prodArchObj -> getID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('x86_64', $id);
	return;
}

#==========================================
# test_getName
#------------------------------------------
sub test_getName {
	# ...
	# Test the getName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prodArchObj = $this -> __getProdArchObj();
	my $name = $prodArchObj -> getName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('intel', $name);
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
	my $prodArchObj = $this -> __getProdArchObj();
	my $elem = $prodArchObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<arch '
		. 'id="x86_64" '
		. 'name="intel" '
		. 'fallback="noarch"/>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getProdArchObj
#------------------------------------------
sub __getProdArchObj {
	# ...
	# Helper to construct a fully populated ProductArchitecture object.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		fallback => 'noarch',
		id       => 'x86_64',
		name     => 'intel'
	);
	my $prodArchObj = KIWIXMLProductArchitectureData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($prodArchObj);
	return $prodArchObj;
}

1;
