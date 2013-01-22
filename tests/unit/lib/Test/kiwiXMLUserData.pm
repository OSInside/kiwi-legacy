#================
# FILE          : kiwiXMLUserData.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use XML::LibXML;

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
	my $userDataObj = KIWIXMLUserData -> new('foo');
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new();
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
# test_getXMLElement
#------------------------------------------
sub test_getXMLElement{
	# ...
	# Verify that the getXMLElement method returns a node
	# with the proper data.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $elem = $userDataObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<users group="mygrp" id="1001">'
		. '<user '
		. 'home="/home/me" '
		. 'name="me" '
		. 'id="1111" '
		. 'pwd="hello" '
		. 'pwdformat="plain" '
		. 'realname="Pablo" '
		. 'shell="/usr/bin/zsh"/>'
		. '</users>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_mergeGroup
#------------------------------------------
sub test_mergeGroup {
	# ...
	# Test the merge method for group
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group        => 'audio',
		home         => '/home/me',
		name         => 'me',
		passwdformat => 'plain'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp,audio', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeGroupID
#------------------------------------------
sub test_mergeGroupID {
	# ...
	# Test the merge method for group id
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group        => 'audio',
		groupid      => '1268',
		home         => '/home/me',
		name         => 'me',
		passwdformat => 'plain'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp,audio', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001,1268', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergePass
#------------------------------------------
sub test_mergePass {
	# ...
	# Test the merge method with merging the password
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init1 = (
		group => 'audio',
		home  => '/home/you',
		name  => 'you'
	);
	my $user1 = KIWIXMLUserData -> new(\%init1);
	my %init2 = (
		group  => 'audio',
		home   => '/home/you',
		name   => 'you',
		passwd => '1xfg567yh',
		userid => '2344'
	);
	my $user2 = KIWIXMLUserData -> new(\%init2);
	my $res = $user1 -> merge($user2);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $grpNm = $user1 -> getGroupName();
	$this -> assert_str_equals('audio', $grpNm );
	my $pass = $user1 -> getPassword();
	$this -> assert_str_equals('1xfg567yh', $pass);
	my $uid = $user1 -> getUserID();
	$this -> assert_str_equals('2344', $uid );

	return;
}

#==========================================
# test_mergeShell
#------------------------------------------
sub test_mergeShell {
	# ...
	# Test the merge method with merging the login shell
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init1 = (
		group => 'audio',
		home  => '/home/you',
		name  => 'you'
	);
	my $user1 = KIWIXMLUserData -> new(\%init1);
	my %init2 = (
		group    => 'audio',
		home     => '/home/you',
		name     => 'you',
		realname => 'Fred Flinstone',
		shell    => '/usr/bin/tcsh',
		userid   => '2344'
	);
	my $user2 = KIWIXMLUserData -> new(\%init2);
	my $res = $user1 -> merge($user2);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $grpNm = $user1 -> getGroupName();
	$this -> assert_str_equals('audio', $grpNm );
	my $lsh = $user1 -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/tcsh', $lsh );
	my $uid = $user1 -> getUserID();
	$this -> assert_str_equals('2344', $uid );
	my $rName = $user1 -> getUserRealName();
	$this -> assert_str_equals('Fred Flinstone', $rName );
	return;
}

#==========================================
# test_mergeUid
#------------------------------------------
sub test_mergeUid {
	# ...
	# Test the merge method with merging the user ID
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init1 = (
		group => 'audio',
		home  => '/home/you',
		name  => 'you'
	);
	my $user1 = KIWIXMLUserData -> new(\%init1);
	my %init2 = (
		group  => 'audio',
		home   => '/home/you',
		name   => 'you',
		userid => '2344'
	);
	my $user2 = KIWIXMLUserData -> new(\%init2);
	my $res = $user1 -> merge($user2);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $grpNm = $user1 -> getGroupName();
	$this -> assert_str_equals('audio', $grpNm );
	my $uid = $user1 -> getUserID();
	$this -> assert_str_equals('2344', $uid );
	return;
}

#==========================================
# test_mergeURname
#------------------------------------------
sub test_mergeURname {
	# ...
	# Test the merge method with merging the user real name
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init1 = (
		group => 'audio',
		home  => '/home/you',
		name  => 'you'
	);
	my $user1 = KIWIXMLUserData -> new(\%init1);
	my %init2 = (
		group    => 'audio',
		home     => '/home/you',
		name     => 'you',
		realname => 'Fred Flinstone',
		userid   => '2344'
	);
	my $user2 = KIWIXMLUserData -> new(\%init2);
	my $res = $user1 -> merge($user2);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $grpNm = $user1 -> getGroupName();
	$this -> assert_str_equals('audio', $grpNm );
	my $uid = $user1 -> getUserID();
	$this -> assert_str_equals('2344', $uid );
	my $rName = $user1 -> getUserRealName();
	$this -> assert_str_equals('Fred Flinstone', $rName );
	return;
}

#==========================================
# test_mergeIncompatHome
#------------------------------------------
sub test_mergeIncompatHome {
	# ...
	# Test the merge method with incompatible home directories
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group => 'audio',
		home  => '/home/you',
		name  => 'you'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: attempting to merge user data for user with '
		. 'different home directory. Merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeIncompatPass
#------------------------------------------
sub test_mergeIncompatPass {
	# ...
	# Test the merge method with incompatible home directories
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group  => 'audio',
		home   => '/home/me',
		name   => 'me',
		passwd => 'world',
		userid => '1111'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: attempting to merge user data for user with '
		. 'different passwords. Merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeIncompatPassForm
#------------------------------------------
sub test_mergeIncompatPassForm {
	# ...
	# Test the merge method with incompatible home directories
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group  => 'audio',
		home   => '/home/me',
		name   => 'me',
		passwd => 'hello',
		userid => '1111'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: attempting to merge user data for user with '
		. 'different password format settings. Merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeIncompatShell
#------------------------------------------
sub test_mergeIncompatShell {
	# ...
	# Test the merge method with incompatible login shell
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group        => 'audio',
		home         => '/home/me',
		name         => 'me',
		passwdformat => 'plain',
		shell        => '/usr/bin/csh',
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: attempting to merge user data for user with '
		. 'different login shell. Merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeIncompatUid
#------------------------------------------
sub test_mergeIncompatUid {
	# ...
	# Test the merge method with incompatible home directories
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group  => 'audio',
		home   => '/home/me',
		name   => 'you',
		userid => '3000'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: attempting to merge user data for user with '
		. 'different user IDs. Merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeIncompatUname
#------------------------------------------
sub test_mergeIncompatUname {
	# ...
	# Test the merge method with incompatible home directories
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group  => 'audio',
		home   => '/home/me',
		name   => 'you',
		userid => '1111'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: attempting to merge user data for two different '
		. 'users. Merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeIncompatURName
#------------------------------------------
sub test_mergeIncompatURName {
	# ...
	# Test the merge method with incompatible home directories
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		group        => 'audio',
		home         => '/home/me',
		name         => 'me',
		passwdformat => 'plain',
		realname     => 'frank',
		userid       => '1111'
	);
	my $mergeUser = KIWIXMLUserData -> new(\%init);
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge($mergeUser);
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: attempting to merge user data for user with '
		. 'different real name settings. Merge error';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
	return;
}

#==========================================
# test_mergeInvalidArg
#------------------------------------------
sub test_mergeInvalidArg {
	# ...
	# Test the merge method with an invalid argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $userDataObj = $this -> __getUserObj();
	my $res = $userDataObj -> merge('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'merge: expecting KIWIXMLUserData object as argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $grpNm = $userDataObj -> getGroupName();
	$this -> assert_str_equals('mygrp', $grpNm );
	my $gid = $userDataObj -> getGroupID();
	$this -> assert_str_equals('1001', $gid );
	my $lsh = $userDataObj -> getLoginShell();
	$this -> assert_str_equals('/usr/bin/zsh', $lsh );
	my $pwd = $userDataObj -> getPassword();
	$this -> assert_str_equals('hello', $pwd );
	my $pwdf = $userDataObj -> getPasswordFormat();
	$this -> assert_str_equals('plain', $pwdf );
	my $home = $userDataObj -> getUserHomeDir();
	$this -> assert_str_equals('/home/me', $home );
	my $uid = $userDataObj -> getUserID();
	$this -> assert_str_equals('1111', $uid );
	my $name = $userDataObj -> getUserName();
	$this -> assert_str_equals('me', $name );
	my $rName = $userDataObj -> getUserRealName();
	$this -> assert_str_equals('Pablo', $rName );
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
	my $userDataObj = KIWIXMLUserData -> new(\%init);
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
