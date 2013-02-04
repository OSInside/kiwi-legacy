#================
# FILE          : kiwiXMLInstRepositoryData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLInstRepositoryData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLInstRepositoryData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLInstRepositoryData;

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
# test_ctor_argsInvalidHashNoName
#------------------------------------------
sub test_ctor_argsInvalidHashNoName {
	# ...
	# Test the InstRepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
	    path     => 'opensuse:///',
		priority => '2'
	);
	my $repoDataObj = KIWIXMLInstRepositoryData -> new(\%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLInstRepositoryData: no "name" specified in '
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($repoDataObj);
	return;
}

#==========================================
# test_ctor_argsInvalidHashNoPath
#------------------------------------------
sub test_ctor_argsInvalidHashNoPath {
	# ...
	# Test the InstRepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
		name => 'myRepo',
		priority => '2'
	);
	my $repoDataObj = KIWIXMLInstRepositoryData -> new(\%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLInstRepositoryData: no "path" specified in '
		.'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($repoDataObj);
	return;
}

#==========================================
# test_ctor_argsInvalidHashNoPrio
#------------------------------------------
sub test_ctor_argsInvalidHashNoPrio {
	# ...
	# Test the InstRepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
		name => 'myRepo',
	    path => 'opensuse:///'
	);
	my $repoDataObj = KIWIXMLInstRepositoryData -> new(\%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLInstRepositoryData: no "priority" specified in '
		.'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($repoDataObj);
	return;
}

#==========================================
# test_ctor_argsInvalidHashPassNoUsr
#------------------------------------------
sub test_ctor_argsInvalidHashPassNoUsr {
	# ...
	# Test the InstRepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
	    name     => 'myRepo',
		password => 'ola',
		path     => 'opensuse:///',
		priority => '2'
	);
	my $repoDataObj = KIWIXMLInstRepositoryData -> new(\%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLInstRepositoryData: initialization data contains '
		. 'password, but no username';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($repoDataObj);
	return;
}

#==========================================
# test_ctor_argsInvalidHashUsrNoPass
#------------------------------------------
sub test_ctor_argsInvalidHashUsrNoPass {
	# ...
	# Test the InstRepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
	    name     => 'myRepo',
		path     => 'opensuse:///',
		priority => '2',
		username => 'pablo'
	);
	my $repoDataObj = KIWIXMLInstRepositoryData -> new(\%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLInstRepositoryData: initialization data contains '
		. 'username, but no password';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($repoDataObj);
	return;
}

#==========================================
# test_ctor_argsValidHash
#------------------------------------------
sub test_ctor_argsValidHash {
	# ...
	# Test the InstRepositoryData constructor with valid hash ref arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
		name     => 'myTest',
		path     => 'opensuse:///',
		priority => '2'
	);
	my $repoDataObj = KIWIXMLInstRepositoryData -> new(\%repoData);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($repoDataObj);
	return;
}

#==========================================
# test_ctor_invalidArg
#------------------------------------------
sub test_ctor_invalidArg {
	# ...
	# Test the InstRepositoryData constructor with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = KIWIXMLInstRepositoryData -> new('opensuse');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as first argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($repoDataObj);
	return;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
	# ...
	# Test the InstRepositoryData constructor with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = KIWIXMLInstRepositoryData -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLInstRepositoryData: must be constructed with '
		. 'a keyword hash as argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($repoDataObj);
	return;
}

#==========================================
# test_getCredentials
#------------------------------------------
sub test_getCredentials {
	# ...
	# Test the getCredentials method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my ($username, $password) = $repoDataObj->getCredentials();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1234567', $password);
	$this -> assert_str_equals('testuser', $username);
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
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->getName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myRepo', $res);
	return;
}

#==========================================
# test_getPath
#------------------------------------------
sub test_getPath {
	# ...
	# Test the getPath method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->getPath();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('opensuse:///', $res);
	return;
}

#==========================================
# test_getPriority
#------------------------------------------
sub test_getPriority {
	# ...
	# Test the getPriotity method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->getPriority();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_equals(2, $res);
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
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $elem = $repoDataObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<instrepo '
		. 'password="1234567" '
		. 'priority="2" '
		. 'username="testuser" '
		. 'local="true" '
		. 'name="myRepo">'
		. '<source path="opensuse:///"/>'
		. '</instrepo>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_isLocal
#------------------------------------------
sub test_isLocal {
	# ...
	# Test the isLocal method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->isLocal();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $res);
	return;
}

#==========================================
# test_setCredentials
#------------------------------------------
sub test_setCredentials {
	# ...
	# Test the setCredentials method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	$repoDataObj = $repoDataObj->setCredentials('tester', '7654321');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my ($username, $password) = $repoDataObj->getCredentials();
	$this -> assert_str_equals('7654321', $password);
	$this -> assert_str_equals('tester', $username);
	return;
}

#==========================================
# test_setCredentialsNoPass
#------------------------------------------
sub test_setCredentialsNoPass {
	# ...
	# Test the set method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->setCredentials('helper');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setCredentials: no password specified';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my ($username, $password) = $repoDataObj->getCredentials();
	$this -> assert_str_equals('1234567', $password);
	$this -> assert_str_equals('testuser', $username);
	return;
}

#==========================================
# test_setCredentialsNoUser
#------------------------------------------
sub test_setCredentialsNoUser {
	# ...
	# Test the set method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->setCredentials(undef, '7564321');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setCredentials: no username specified';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my ($username, $password) = $repoDataObj->getCredentials();
	$this -> assert_str_equals('1234567', $password);
	$this -> assert_str_equals('testuser', $username);
	return;
}

#==========================================
# test_setLocalInvalidArg
#------------------------------------------
sub test_setLocalInvalidArg {
	# ...
	# Test the setLocal method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->setLocal(1);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLInstRepositoryData:setLocal: unrecognized '
		. 'argument expecting "true" or "false".';
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
# test_setLocalOff
#------------------------------------------
sub test_setLocalOff {
	# ...
	# Test the setLocal method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	$repoDataObj = $repoDataObj->setLocal();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->isLocal();
	$this -> assert_str_equals('false', $res);
	return;
}

#==========================================
# test_setLocalOn
#------------------------------------------
sub test_setLocalOn {
	# ...
	# Test the setLocal method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	$repoDataObj = $repoDataObj->setLocal('true');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->isLocal();
	$this -> assert_str_equals('true',$res);
	return;
}

#==========================================
# test_setName
#------------------------------------------
sub test_setName {
	# ...
	# Test the setName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	$repoDataObj = $repoDataObj->setName('testName');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getName();
	$this -> assert_str_equals('testName', $res);
	return;
}

#==========================================
# test_setNameNoArg
#------------------------------------------
sub test_setNameNoArg {
	# ...
	# Test the setName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->setName();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setName: No name specified, retaining current data';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $name = $repoDataObj->getName();
	$this -> assert_str_equals('myRepo', $name);
	return;
}

#==========================================
# test_setPath
#------------------------------------------
sub test_setPath {
	# ...
	# Test the setPath method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	$repoDataObj = $repoDataObj->setPath('https:///');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getPath();
	$this -> assert_str_equals('https:///', $res);
	return;
}

#==========================================
# test_setPathNoArg
#------------------------------------------
sub test_setPathNoArg {
	# ...
	# Test the setPath method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->setPath();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPath: No location specified, retaining current data';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	$res = $repoDataObj->getPath();
	$this -> assert_str_equals('opensuse:///', $res);
	return;
}

#==========================================
# test_setPriority
#------------------------------------------
sub test_setPriority {
	# ...
	# Test the setPriority method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	$repoDataObj = $repoDataObj->setPriority(1);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getPriority();
	$this -> assert_equals(1, $res);
	return;
}

#==========================================
# test_setPriorityNoArg
#------------------------------------------
sub test_setPriorityNoArg {
	# ...
	# Test the setPriority method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getInstRepoDataObj();
	my $res = $repoDataObj->setPriority();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPriority: No priority specified, retaining '
		. 'current data';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $prio = $repoDataObj->getPriority();
	$this -> assert_str_equals('2', $prio);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
sub __getInstRepoDataObj {
	# ...
	# Helper method to create KIWIXMLInstRepositoryData object
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				name     => 'myRepo',
				local    => 'true',
				password => '1234567',
				path     => 'opensuse:///',
				priority => '2',
				username => 'testuser'
	);
	my $repoDataObj = KIWIXMLInstRepositoryData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	return $repoDataObj;
}

1;
