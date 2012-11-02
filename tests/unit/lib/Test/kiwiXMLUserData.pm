#================
# FILE          : kiwiXMLUserData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLUserData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLUserData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLUserData;

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
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the UserData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = KIWIXMLUserData -> new($kiwi, 'foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($userDataObj);
	return;
}

#==========================================
# test_ctor_initIncompleteNoGroup
#------------------------------------------
sub test_ctor_initIncompleteNoGroup {
	# ...
	# Test the UserData constructor with an incomplete initialization hash
	# missing goup name.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				home => '/home/me',
				name => 'me'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLUserData: no "group" name specified in '
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($userDataObj);
	return;
}

#==========================================
# test_ctor_initIncompleteNoHome
#------------------------------------------
sub test_ctor_initIncompleteNoHome {
	# ...
	# Test the UserData constructor with an incomplete initialization hash
	# missing home.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group => 'user',
				name  => 'me'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLUserData: no "home" directory specified in '
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($userDataObj);
	return;
}

#==========================================
# test_ctor_initIncompleteNoName
#------------------------------------------
sub test_ctor_initIncompleteNoName {
	# ...
	# Test the UserData constructor with an incomplete initialization hash
	# missing name.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group => 'user',
				home  => '/home/me'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLUserData: no user "name" specified in '
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($userDataObj);
	return;
}

#==========================================
# test_ctor_initLowGroupID
#------------------------------------------
sub test_ctor_initLowGroupID {
	# ...
	# Test the UserData constructor with an initialization hash
	# setting a low groupid
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group   => 'user',
				groupid => '600',
				home    => '/home/me',
				name    => 'me'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: assigned ID is less than 1000, '
		. 'this may conflict with system assigned IDs for users and groups.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($userDataObj);
	return;
}

#==========================================
# test_ctor_initLowUserID
#------------------------------------------
sub test_ctor_initLowUserID {
	# ...
	# Test the UserData constructor with an initialization hash
	# setting a low userid
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group  => 'user',
				home   => '/home/me',
				name   => 'me',
				userid => '600'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: assigned ID is less than 1000, '
		. 'this may conflict with system assigned IDs for users and groups.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($userDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
	# ...
	# Test the UserData constructor with an initialization hash
	# that contains unsupported data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group  => 'user',
				home   => '/home/me',
				name   => 'me',
				userNM => 'metoo'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLUserData: Unsupported keyword argument '
		. "'userNM' in initialization structure.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($userDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedPwdFormat
#------------------------------------------
sub test_ctor_initUnsupportedPwdFormat {
	# ...
	# Test the UserData constructor with an initialization hash
	# that contains unsupported data for the password format
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group        => 'user',
				home         => '/home/me',
				name         => 'me',
				passwdformat => 'foo'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: unexpected value for password '
		. 'format, expecting encrypted or plain.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($userDataObj);
	return;
}

#==========================================
# test_ctor_noInit
#------------------------------------------
sub test_ctor_noInit {
	# ...
	# Test the UserData constructor with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = KIWIXMLUserData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLUserData: must be constructed with a '
		. 'keyword hash as argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($userDataObj);
	return;
}

#==========================================
# test_ctor_withInit
#------------------------------------------
sub test_ctor_withInit {
	# ...
	# Test the UserData constructor with an initialization hash
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group  => 'user',
				home   => '/home/me',
				name   => 'me'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($userDataObj);
	return;
}

#==========================================
# test_getGroupName
#------------------------------------------
sub test_getGroupName {
	# ...
	# Test the getGroupName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $grpNm = $userDataObj -> getGroupName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('mygrp', $grpNm );
	return;
}

#==========================================
# test_getGroupID
#------------------------------------------
sub test_getGroupID {
	# ...
	# Test the getGroupID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $gid = $userDataObj -> getGroupID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1001', $gid );
	return;
}

#==========================================
# test_getLoginShell
#------------------------------------------
sub test_getLoginShell {
	# ...
	# Test the getLoginShell method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $lsh = $userDataObj -> getLoginShell();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	return;
}

#==========================================
# test_getPassword
#------------------------------------------
sub test_getPassword {
	# ...
	# Test the getPassword method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $pwd = $userDataObj -> getPassword();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('hello', $pwd );
	return;
}

#==========================================
# test_getPasswordFormat
#------------------------------------------
sub test_getPasswordFormat {
	# ...
	# Test the getPasswordFormat method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $pwdf = $userDataObj -> getPasswordFormat();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('plain', $pwdf );
	return;
}

#==========================================
# test_getPasswordFormatDefault
#------------------------------------------
sub test_getPasswordFormatDefault {
	# ...
	# Test the getPasswordFormat method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				group  => 'user',
				home   => '/home/me',
				name   => 'me'
			);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $pwdf = $userDataObj -> getPasswordFormat();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('encrypted', $pwdf );
	return;
}

#==========================================
# test_getUserHomeDir
#------------------------------------------
sub test_getUserHomeDir {
	# ...
	# Test the getUserHomeDir method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $home = $userDataObj -> getUserHomeDir();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/home/me', $home );
	return;
}

#==========================================
# test_getUserID
#------------------------------------------
sub test_getUserID {
	# ...
	# Test the getUserID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $uid = $userDataObj -> getUserID();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1111', $uid );
	return;
}

#==========================================
# test_getUserName
#------------------------------------------
sub test_getUserName {
	# ...
	# Test the getUserName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $name = $userDataObj -> getUserName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('me', $name );
	return;
}

#==========================================
# test_getUserRealName
#------------------------------------------
sub test_getUserRealName {
	# ...
	# Test the getUserRealName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $name = $userDataObj -> getUserRealName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('Pablo', $name );
	return;
}

#==========================================
# test_setGroupName
#------------------------------------------
sub test_setGroupName {
	# ...
	# Test the getGroupName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setGroupName('newGrp');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('newGrp', $grpNm );
	return;
}

#==========================================
# test_setGroupNameInvalName
#------------------------------------------
sub test_setGroupNameInvalName {
	# ...
	# Test the getGroupName method with invalid name
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setGroupName('ola grp');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setGroupName: given argument contains white space not '
		. 'supported, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	return;
}

#==========================================
# test_setGroupNameNoArg
#------------------------------------------
sub test_setGroupNameNoArg {
	# ...
	# Test the getGroupName method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setGroupName();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setGroupName: no name argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	return;
}

#==========================================
# test_setGroupID
#------------------------------------------
sub test_setGroupID {
	# ...
	# Test the setGroupID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setGroupID('2222');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('2222', $gid );
	return;
}

#==========================================
# test_setGroupIDLow
#------------------------------------------
sub test_setGroupIDLow {
	# ...
	# Test the setGroupID method with a low ID
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setGroupID('222');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setGroupID: assigned ID is less than 1000, this may '
		. 'conflict with system assigned IDs for users and groups.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($userDataObj);
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('222', $gid );
	return;
}

#==========================================
# test_setGroupNoArg
#------------------------------------------
sub test_setGroupNoArg {
	# ...
	# Test the setGroupID method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setGroupID();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setGroupID: no ID argument specified,, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	return;
}

#==========================================
# test_setLoginShell
#------------------------------------------
sub test_setLoginShell {
	# ...
	# Test the getLoginShell method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setLoginShell('/usr/bin/tcsh');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/tcsh', $lsh );
	return;
}

#==========================================
# test_setLoginShellInvalName
#------------------------------------------
sub test_setLoginShellInvalName {
	# ...
	# Test the getLoginShell method with invalid name
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setLoginShell('/usr/bin/ sh');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setLoginShell: given argument contains white space not '
		. 'supported, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	return;
}

#==========================================
# test_setLoginShellNoArg
#------------------------------------------
sub test_setLoginShellNoArg {
	# ...
	# Test the getLoginShell method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setLoginShell();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setLoginShell: no login shell argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	return;
}

#==========================================
# test_setPassword
#------------------------------------------
sub test_setPassword {
	# ...
	# Test the getPassword method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setPassword('fresh');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('fresh', $pwd );
	return;
}

#==========================================
# test_setPasswordNoArg
#------------------------------------------
sub test_setPasswordNoArg {
	# ...
	# Test the getPassword method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setPassword();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPassword: no password argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	return;
}

#==========================================
# test_setPasswordFormat
#------------------------------------------
sub test_setPasswordFormat {
	# ...
	# Test the getPasswordFormat method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setPasswordFormat('encrypted');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $pwdF = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('encrypted', $pwdF );
	return;
}

#==========================================
# test_setPasswordFormatInvalidArg
#------------------------------------------
sub test_setPasswordFormatInvalidArg {
	# ...
	# Test the getPasswordFormat method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setPasswordFormat('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPasswordFormat: unexpected value for password format, '
		. 'expecting encrypted or plain.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $pwdF = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdF );
	return;
}

#==========================================
# test_setPasswordFormatNoArg
#------------------------------------------
sub test_setPasswordFormatNoArg {
	# ...
	# Test the getPasswordFormat method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setPasswordFormat();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPasswordFormat: no format argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $pwd = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwd );
	return;
}

#==========================================
# test_setUserHomeDir
#------------------------------------------
sub test_setUserHomeDir {
	# ...
	# Test the getUserHomeDir method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setUserHomeDir('/home/you');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/you', $home );
	return;
}

#==========================================
# test_setUserHomeDirInvalName
#------------------------------------------
sub test_setUserHomeDirInvalName {
	# ...
	# Test the getUserHomeDir method with invalid name
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setUserHomeDir('/var/run/ dir');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setUserHomeDir: given argument contains white space not '
		. 'supported, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	return;
}

#==========================================
# test_setUserHomeDirNoArg
#------------------------------------------
sub test_setUserHomeDirNoArg {
	# ...
	# Test the getUserHomeDir method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setUserHomeDir();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setUserHomeDir: no home directory argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	return;
}

#==========================================
# test_setUserID
#------------------------------------------
sub test_setUserID {
	# ...
	# Test the setUserID method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setUserID('2222');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('2222', $uid );
	return;
}

#==========================================
# test_setUserIDLow
#------------------------------------------
sub test_setUserIDLow {
	# ...
	# Test the setUserID method with a low ID
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setUserID('222');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setUserID: assigned ID is less than 1000, this may '
		. 'conflict with system assigned IDs for users and groups.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($userDataObj);
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('222', $uid );
	return;
}

#==========================================
# test_setUserNoArg
#------------------------------------------
sub test_setUserNoArg {
	# ...
	# Test the setUserID method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setUserID();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setUserID: no ID argument specified,, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	return;
}

#==========================================
# test_setUserName
#------------------------------------------
sub test_setUserName {
	# ...
	# Test the getUserName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setUserName('frankdoe');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $usrNm = $userDataObj -> getUserName();
	$this -> assert_str_equals('frankdoe', $usrNm );
	return;
}

#==========================================
# test_setUserNameInvalName
#------------------------------------------
sub test_setUserNameInvalName {
	# ...
	# Test the getUserName method with invalid name
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setUserName('frank doe');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setUserName: given argument contains white space not '
		. 'supported, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $usrNm = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $usrNm );
	return;
}

#==========================================
# test_setUserNameNoArg
#------------------------------------------
sub test_setUserNameNoArg {
	# ...
	# Test the getUserName method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setUserName();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setUserName: no name argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $usrNm = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $usrNm );
	return;
}

#==========================================
# test_setUserRealName
#------------------------------------------
sub test_setUserRealName {
	# ...
	# Test the getUserRealName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	$userDataObj = $userDataObj -> setUserRealName('pablo franco');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($userDataObj);
	my $usrNm = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('pablo franco', $usrNm );
	return;
}

#==========================================
# test_setUserRealNameNoArg
#------------------------------------------
sub test_setUserRealNameNoArg {
	# ...
	# Test the getUserRealName method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> setUserRealName();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setUserRealName: no name argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $usrNm = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $usrNm );
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getUserObj
#------------------------------------------
sub __getUserObj {
	# ...
	# Helper to construct a fully populated User object
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group        => 'mygrp',
		groupid      => '1001',
		home         => '/home/me',
		name         => 'me',
		passwd       => 'hello',
		passwdformat => 'plain',
		realname     => 'Pablo',
		shell        => '/usr/bin/zsh',
		userid       => '1111'
	);
	my $userDataObj = KIWIXMLUserData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($userDataObj);
	return $userDataObj;
}

1;
