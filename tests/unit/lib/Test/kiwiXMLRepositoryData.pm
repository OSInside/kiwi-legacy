#================
# FILE          : kiwiXMLRepositoryData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLRepositoryData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLRepositoryData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLRepositoryData;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {kiwi} = Common::ktLog -> new();

	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor_argsIncompleteNoSecond {
	# ...
	# Test the RepositoryData constructor with no second argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi);
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
# test_ctor_argsInvalidHashNoPath
#------------------------------------------
sub test_ctor_argsInvalidHashNoPath {
	# ...
	# Test the RepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = ( alias => 'myRepo' );
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLRepositoryData: no "path" specified in '
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
# test_ctor_argsInvalidHashInvalidType
#------------------------------------------
sub test_ctor_argsInvalidHashInvalidType {
	# ...
	# Test the RepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = ( alias => 'myRepo',
					path  => 'opensuse:///',
					type  => 'bar'
				);
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = "Specified repository type 'bar' is not supported";
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
# test_ctor_argsInvalidHashNoType
#------------------------------------------
sub test_ctor_argsInvalidHashNoType {
	# ...
	# Test the RepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = ( alias => 'myRepo',
					path  => 'opensuse:///'
				);
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLRepositoryData: no "type" specified in '
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
# test_ctor_argsInvalidHashPassNoUsr
#------------------------------------------
sub test_ctor_argsInvalidHashPassNoUsr {
	# ...
	# Test the RepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
					alias => 'myRepo',
					password => 'ola',
					path  => 'opensuse:///',
					type => 'deb-dir'
				);
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLRepositoryData: initialization data contains '
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
	# Test the RepositoryData constructor with an invalid hash argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
					alias => 'myRepo',
					path  => 'opensuse:///',
					type => 'up2date-mirrors',
					username => 'pablo'
				);
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%repoData);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLRepositoryData: initialization data contains '
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
# test_ctor_argsInvalidType
#------------------------------------------
sub test_ctor_argsInvalidType {
	# ...
	# Test the RepositoryData constructor with an invalid third argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				path => 'opensuse:///',
				type => 'foo'
	);
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = "Specified repository type 'foo' is not supported";
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
	# Test the RepositoryData constructor with valid hash ref arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %repoData = (
					path  => 'opensuse:///',
					type => 'up2date-mirrors',
				);
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%repoData);
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
	# Test the RepositoryData constructor with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, 'opensuse');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
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
# test_getAlias
#------------------------------------------
sub test_getAlias {
	# ...
	# Test the getAlias method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->getAlias();
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
# test_getCredentials
#------------------------------------------
sub test_getCredentials {
	# ...
	# Test the getCredentials method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
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
# test_getImageInclude
#------------------------------------------
sub test_getImageInclude {
	# ...
	# Test the getImageInclude method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->getImageInclude();
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
# test_getPath
#------------------------------------------
sub test_getPath {
	# ...
	# Test the getPath method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
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
# test_getPreferLicense
#------------------------------------------
sub test_getPreferLicense {
	# ...
	# Test the getPreferLicense method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->getPreferLicense();
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
# test_getPriority
#------------------------------------------
sub test_getPriority {
	# ...
	# Test the getPriotity method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
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
# test_getStatus
#------------------------------------------
sub test_getStatus {
	# ...
	# Test the getStatus method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->getStatus();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('replacable', $res);
	return;
}

#==========================================
# test_getType
#------------------------------------------
sub test_getType {
	# ...
	# Test the getType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->getType();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('yast2', $res);
	return;
}

#==========================================
# test_setAlias
#------------------------------------------
sub test_setAlias {
	# ...
	# Test the setAlias method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setAlias('testName');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getAlias();
	$this -> assert_str_equals('testName', $res);
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
	my $repoDataObj = $this->__getRepoDataObj();
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
	my $repoDataObj = $this->__getRepoDataObj();
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
	my $repoDataObj = $this->__getRepoDataObj();
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
# test_setImageIncludeOff
#------------------------------------------
sub test_setImageIncludeOff {
	# ...
	# Test the setImageInclude method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setImageInclude();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getImageInclude();
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setImageIncludeOn
#------------------------------------------
sub test_setImageIncludeOn {
	# ...
	# Test the setsetImageInclude method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setImageInclude(1);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getImageInclude();
	$this -> assert_str_equals('true', $res);
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
	my $repoDataObj = $this->__getRepoDataObj();
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
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->setPath();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPath: No location specified, retaining current data';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($res);
	$res = $repoDataObj->getPath();
	$this -> assert_str_equals('opensuse:///', $res);
	return;
}

#==========================================
# test_setPreferLicenseOff
#------------------------------------------
sub test_setPreferLicenseOff {
	# ...
	# Test the setPreferLicense method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setPreferLicense();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getPreferLicense();
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setPreferLicenseOn
#------------------------------------------
sub test_setPreferLicenseOn {
	# ...
	# Test the setPreferLicense method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setPreferLicense(1);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getPreferLicense();
	$this -> assert_str_equals('true',$res);
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
	my $repoDataObj = $this->__getRepoDataObj();
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
# test_setStatus
#------------------------------------------
sub test_setStatus {
	# ...
	# Test the setStatus method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setStatus('fixed');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getStatus();
	$this -> assert_str_equals('fixed', $res);
	return;
}

#==========================================
# test_setStatusInvalidArg
#------------------------------------------
sub test_setStatusInvalidArg {
	# ...
	# Test the setStatus method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->setStatus('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setStatus: Expected keyword "fixed" or "replacable"';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	$res = $repoDataObj->getStatus();
	$this -> assert_str_equals('replacable', $res);
	return;
}

#==========================================
# test_setStatusNoArg
#------------------------------------------
sub test_setStatusNoArg {
	# ...
	# Test the setStatus method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setStatus();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setStatus: No status specified, retaining current data';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($repoDataObj);
	my $res = $repoDataObj->getStatus();
	$this -> assert_str_equals('replacable', $res);
	return;
}

#==========================================
# test_setType
#------------------------------------------
sub test_setType {
	# ...
	# Test the setType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	$repoDataObj = $repoDataObj->setType( 'red-carpet' );
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($repoDataObj);
	my $type = $repoDataObj->getType();
	$this -> assert_str_equals('red-carpet', $type);
	return;
}

#==========================================
# test_setTypeInvalid
#------------------------------------------
sub test_setTypeInvalid {
	# ...
	# Test the setType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->setType( 'twix' );
	my $msg = $kiwi -> getMessage();
	my $expected = "Specified repository type 'twix' is not supported";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	my $type = $repoDataObj->getType();
	$this -> assert_str_equals('yast2', $type);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setTypeNoArg
#------------------------------------------
sub test_setTypeNoArg {
	# ...
	# Test the setType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $repoDataObj = $this->__getRepoDataObj();
	my $res = $repoDataObj->setType();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setType: No type specified, retaining current data';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	my $type = $repoDataObj->getType();
	$this -> assert_str_equals('yast2', $type);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($res);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
sub __getRepoDataObj {
	# ...
	# Helper method to create KIWIXMLRepositoryData object
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				alias         => 'myRepo',
				imageinclude  => 'true',
				password      => '1234567',
				path          => 'opensuse:///',
				preferlicense => 'true',
				priority      => '2',
				status        => 'replacable',
				type          => 'yast2',
				username      => 'testuser'
	);
	my $repoDataObj = KIWIXMLRepositoryData -> new($kiwi, \%init);
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
