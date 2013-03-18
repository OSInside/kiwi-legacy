#================
# FILE          : KIWIXMLUserData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <user> element.
#               : Additionally the objects stores the attribute data of
#               : the <users> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLUserData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Readonly;
use XML::LibXML;
require Exporter;

use base qw /KIWIXMLDataBase/;
#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# constant
#------------------------------------------
Readonly my $MIN_ID => 1000;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLUserData object
	#
	# Internal data structure
	#
	# this = {
	#    group         = ''
	#    groupid       = ''
	#    home          = ''
	#    name          = ''
	#    passwd        = ''
	#    passwdformat  = ''
	#    realname      = ''
	#    shell         = ''
	#    userid        = ''
	# }
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	if (! $this -> p_hasInitArg($init) ) {
		return;
	}
	my %keywords = map { ($_ => 1) } qw(
		group
		groupid
		home
		name
		passwd
		passwdformat
		realname
		shell
		userid
	);
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> p_isInitHashRef($init) ) {
		return;
	}
	if (! $this -> p_areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init)) {
		return;
	}
	$this->{group}        = $init->{group};
	$this->{groupid}      = $init->{groupid};
	$this->{home}         = $init->{home};
	$this->{name}         = $init->{name};
	$this->{passwd}       = $init->{passwd};
	$this->{passwdformat} = $init->{passwdformat};
	$this->{realname}     = $init->{realname};
	$this->{shell}        = $init->{shell};
	$this->{userid}       = $init->{userid};
	# Set the default
	if (! $init->{passwdformat} ) {
		$this->{passwdformat} = 'encrypted';
		$this->{defaultpasswdformat} = 1;
	}
	return $this;
}

#==========================================
# getGroupName
#------------------------------------------
sub getGroupName {
	# ...
	# Return the name of the group this user belongs to
	# ---
	my $this = shift;
	return $this->{group};
}

#==========================================
# getGroupID
#------------------------------------------
sub getGroupID {
	# ...
	# Return the groupid for the group this user belongs to
	# ---
	my $this = shift;
	return $this->{groupid};
}

#==========================================
# getLoginShell
#------------------------------------------
sub getLoginShell {
	# ...
	# Return the configured e
	# ---
	my $this = shift;
	return $this->{shell};
}

#==========================================
# getPassword
#------------------------------------------
sub getPassword {
	# ...
	# Return the user's password
	# ---
	my $this = shift;
	return $this->{passwd};
}

#==========================================
# getPasswordFormat
#------------------------------------------
sub getPasswordFormat {
	# ...
	# Return the format of the password
	# ---
	my $this = shift;
	return $this->{passwdformat};
}

#==========================================
# getUserHomeDir
#------------------------------------------
sub getUserHomeDir {
	# ...
	# Return the user's home directory
	# ---
	my $this = shift;
	return $this->{home};
}

#==========================================
# getUserID
#------------------------------------------
sub getUserID {
	# ...
	# Return the user's ID
	# ---
	my $this = shift;
	return $this->{userid};
}

#==========================================
# getUserName
#------------------------------------------
sub getUserName {
	# ...
	# Return the user name
	# ---
	my $this = shift;
	return $this->{name};
}

#==========================================
# getUserRealName
#------------------------------------------
sub getUserRealName {
	# ...
	# Return the real name of the user
	# ---
	my $this = shift;
	return $this->{realname};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new('users');
	$element -> setAttribute('group', $this -> getGroupName());
	my $gid = $this -> getGroupID();
	if ($gid) {
		$element -> setAttribute('id', $gid);
	}
	my $uElem = XML::LibXML::Element -> new('user');
	$uElem -> setAttribute('home', $this -> getUserHomeDir());
	$uElem -> setAttribute('name', $this -> getUserName());
	my $id = $this -> getUserID();
	if ($id) {
		$uElem -> setAttribute('id', $id);
	}
	my $pass = $this -> getPassword();
	if ($pass) {
		$uElem -> setAttribute('password', $pass);
	}
	if (! $this->{defaultpasswdformat}) {
		my $passF = $this -> getPasswordFormat();
		if ($passF) {
			$uElem -> setAttribute('pwdformat', $passF);
		}
	}
	my $rname = $this -> getUserRealName();
	if ($rname) {
		$uElem -> setAttribute('realname', $rname);
	}
	my $shell = $this -> getLoginShell();
	if ($shell) {
		$uElem -> setAttribute('shell', $shell);
	}
	$element -> appendChild($uElem);
	return $element;
}

#==========================================
# merge
#------------------------------------------
sub merge {
	# ...
	# Merge user data into one consistent set of data
	# ---
	my $this = shift;
	my $user = shift;
	my $kiwi = $this->{kiwi};
	my $mergePossible = $this -> __checkMergeConditions($user);
	if (! $mergePossible) {
		return;
	}
	my $home = $user -> getUserHomeDir();
	my $id = $user -> getUserID();
	my $name = $user -> getUserName();
	my $pass = $user -> getPassword();
	my $format = $user -> getPasswordFormat();
	my $rName = $user -> getUserRealName();
	my $shell = $user -> getLoginShell();
	if ($id) {
		$this -> setUserID($id);
	}
	if ($pass) {
		$this -> setPassword($pass);
	}
	if ($format) {
		$this -> setPasswordFormat($format);
	}
	if ($rName) {
		$this -> setUserRealName($rName);
	}
	if ($shell) {
		$this -> setLoginShell($shell);
	}
	my $group = $user -> getGroupName();
	my $thisGroup = $this -> getGroupName();
	if ($group) {
		if ($thisGroup && $thisGroup ne $group) {
			my $newGroup = $thisGroup . q{,} . $group;
			$this -> setGroupName($newGroup);
		} else {
			$this -> setGroupName($group);
		}
	}
	my $gid = $user -> getGroupID();
	my $thisGid = $this -> getGroupID();
	if ($gid) {
		if ($thisGid && $thisGid ne $gid) {
			my $newGid = $thisGid . q{,} . $gid;
			$this -> setGroupID($newGid);
		} else {
			$this -> setGroupID($gid);
		}
	}
	return $this;
}

#==========================================
# setGroupName
#------------------------------------------
sub setGroupName {
	# ...
	# Set the name of the group this user belongs to
	# ---
	my $this = shift;
	my $name = shift;
	if (! $name) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setGroupName: no name argument given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $validName = $this -> p_containsNoWhiteSpace($name, 'setGroupName');
	if (! $validName ) {
		return;
	}
	$this->{group} = $name;
	return $this;
}

#==========================================
# setGroupID
#------------------------------------------
sub setGroupID {
	# ...
	# Return the groupid for the group this user belongs to
	# ---
	my $this = shift;
	my $id   = shift;
	my $validId = $this -> __checkAssignedID($id, 'setGroupID');
	if (! $validId) {
		return;
	}
	$this->{groupid} = $id;
	return $this;
}

#==========================================
# setLoginShell
#------------------------------------------
sub setLoginShell {
	# ...
	# Set the login shell for the user
	# ---
	my $this = shift;
	my $lsh  = shift;
	if (! $lsh) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setLoginShell: no login shell argument given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $nameValid = $this -> p_containsNoWhiteSpace($lsh, 'setLoginShell');
	if (! $nameValid) {
		return;
	}
	$this->{shell} = $lsh;
	return $this;
}

#==========================================
# setPassword
#------------------------------------------
sub setPassword {
	# ...
	# Set the usre's password
	# ---
	my $this = shift;
	my $pwd  = shift;
	if (! $pwd) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setPassword: no password argument given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{passwd} = $pwd;
	return $this;
}

#==========================================
# setPasswordFormat
#------------------------------------------
sub setPasswordFormat {
	# ...
	# Set the password format
	# ---
	my $this = shift;
	my $pwdF = shift;
	if (! $this -> __validPassFormat($pwdF, 'setPasswordFormat') ) {
		return;
	}
	$this->{passwdformat} = $pwdF;
	return $this;
}

#==========================================
# setUserHomeDir
#------------------------------------------
sub setUserHomeDir {
	# ...
	# Return the user's home directory
	# ---
	my $this = shift;
	my $dir  = shift;
	if (! $dir) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setUserHomeDir: no home directory argument given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $nameValid = $this -> p_containsNoWhiteSpace($dir, 'setUserHomeDir');
	if (! $nameValid) {
		return;
	}
	$this->{home} = $dir;
	return $this;
}

#==========================================
# setUserID
#------------------------------------------
sub setUserID {
	# ...
	# Return the user's ID
	# ---
	my $this = shift;
	my $id   = shift;
	my $validId = $this -> __checkAssignedID($id, 'setUserID');
	if (! $validId) {
		return;
	}
	$this->{userid} = $id;
	return $this;;
}

#==========================================
# setUserName
#------------------------------------------
sub setUserName {
	# ...
	# Return the user name
	# ---
	my $this = shift;
	my $name = shift;
	if (! $name) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setUserName: no name argument given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $validName = $this -> p_containsNoWhiteSpace($name, 'setUserName');
	if (! $validName ) {
		return;
	}
	$this->{name} = $name;
	return $this;
}

#==========================================
# setUserRealName
#------------------------------------------
sub setUserRealName {
	# ...
	# Return the real name of the user
	# ---
	my $this = shift;
	my $name = shift;
	if (! $name) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setUserRealName: no name argument given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{realname} = $name;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __checkAssignedID
#------------------------------------------
sub __checkAssignedID {
	# ...
	# Check the ID and generate a warning if it is below 500
	# ---
	my $this     = shift;
	my $id       = shift;
	my $caller   = shift;
	my $kiwi = $this->{kiwi};
	if (! $caller ) {
		my $msg = 'Internal error: please file a bug __checkAssignedID on '
			. 'UserData called with insufficient arguments.';
		$kiwi -> error($msg);
		$kiwi -> oops();
		return;
	}
	if (! $id) {
		my $msg = "$caller: no ID argument specified,, retaining "
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @specIds = split /,/smx, $id;
	for my $sid (@specIds) {
		my $idNum = int $sid;
	    if ( $idNum < $MIN_ID ) {
		    my $msg = "$caller: assigned ID is less than 1000, this may "
				. 'conflict with system assigned IDs for users and groups.';
		    $kiwi ->  warning($msg);
		    $kiwi -> done();
	    }
	}
	return 1;
}

#==========================================
# __checkMergeConditions
#------------------------------------------
sub __checkMergeConditions {
	# ...
	# Check the pre conditions for user merging
	# ---
	my $this = shift;
	my $user = shift;
	my $kiwi = $this->{kiwi};
	if (ref($user) ne 'KIWIXMLUserData') {
		my $msg = 'merge: expecting KIWIXMLUserData object as argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $home = $user -> getUserHomeDir();
	if ($home ne $this -> getUserHomeDir()) {
		my $msg = 'merge: attempting to merge user data for user with '
			. 'different home directory. Merge error';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $id = $user -> getUserID();
	my $thisID = $this -> getUserID();
	if ($id) {
		if ($thisID && $thisID ne $id) {
			my $msg = 'merge: attempting to merge user data for user with '
				. 'different user IDs. Merge error';
		    $kiwi -> error($msg);
		    $kiwi -> failed();
		    return;
	    }
	}
	my $name = $user -> getUserName();
	if ($name ne $this -> getUserName()) {
		my $msg = 'merge: attempting to merge user data for two different '
			. 'users. Merge error';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $pass = $user -> getPassword();
	my $thisPass = $this -> getPassword();
	if ($pass) {
		if ($thisPass && $thisPass ne $pass) {
			my $msg = 'merge: attempting to merge user data for user with '
				. 'different passwords. Merge error';
		    $kiwi -> error($msg);
		    $kiwi -> failed();
		    return;
	    }
	}
	my $format = $user -> getPasswordFormat();
	my $thisFormat = $this -> getPasswordFormat();
	if ($format) {
		if ($thisFormat && $thisFormat ne $format) {
			my $msg = 'merge: attempting to merge user data for user with '
				. 'different password format settings. Merge error';
		    $kiwi -> error($msg);
		    $kiwi -> failed();
		    return;
	    }
	}
	my $rName = $user -> getUserRealName();
	my $thisRName = $this -> getUserRealName();
	if ($rName) {
		if ($thisRName && $thisRName ne $rName) {
			my $msg = 'merge: attempting to merge user data for user with '
				. 'different real name settings. Merge error';
		    $kiwi -> error($msg);
		    $kiwi -> failed();
		    return;
	    }
	}
	my $shell = $user -> getLoginShell();
	my $thisShell = $this -> getLoginShell();
	if ($shell) {
		if ($thisShell && $thisShell ne $shell) {
			my $msg = 'merge: attempting to merge user data for user with '
				. 'different login shell. Merge error';
		    $kiwi -> error($msg);
		    $kiwi -> failed();
		    return;
	    }
	}
	return $this;
}

#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
	# ...
	# Verify that the initialization hash is valid
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	if (! $init->{group} ) {
		my $msg = 'KIWIXMLUserData: no "group" name specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{home} ) {
		my $msg = 'KIWIXMLUserData: no "home" directory specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{name} ) {
		my $msg = 'KIWIXMLUserData: no user "name" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($init->{passwdformat}) {
		my $pwdF = $init->{passwdformat};
		if (! $this -> __validPassFormat($pwdF, 'object initialization')) {
			return;
		}
	}
	$this -> __warnAssignedIDs($init);
	return 1;
}

#==========================================
# __validPassFormat
#------------------------------------------
sub __validPassFormat {
	# ...
	# Check that the passwdFormat argument has the expected value
	# ---
	my $this   = shift;
	my $pwdF   = shift;
	my $caller = shift;
	my $kiwi = $this->{kiwi};
	if (! $caller) {
		my $msg = 'Internal error: please file a bug __validPassFormat on '
			. 'UserData called with insufficient arguments.';
		$kiwi -> error($msg);
		$kiwi -> oops();
		return;
	}
	if (! $pwdF) {
		my $msg = "$caller: no format argument given, retaining "
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %supportedVals = (
						encrypted => 1,
						plain     => 1
	);
	if (! $supportedVals{$pwdF}) {
		my $msg = "$caller: unexpected value for password format, expecting "
			. 'encrypted or plain.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __warnAssignedIDs
#------------------------------------------
sub __warnAssignedIDs {
	# ...
	# Give a warning if the assigned IDs are below 500
	# ---
	my $this = shift;
	my $init = shift;
	if ($init->{groupid}) {
		$this -> __checkAssignedID($init->{groupid}, 'object initialization');
	}
	if ($init->{userid}) {
		$this -> __checkAssignedID($init->{userid}, 'object initialization');
	}
	return;
}

1;
