#================
# FILE          : kiwiXMLDescriptionData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLDescriptionData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLDescriptionData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLDescriptionData;

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
# test_ctor_argsIncomplete
#------------------------------------------
sub test_ctor_argsIncomplete {
	# ...
	# Test the DescriptionData constructor only partially initialized
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi, 'me');
	$this -> assert_not_null($descrpObj);
	$this -> assert_null($descrpObj -> getAuthor());
	my $expected = 'XMLDescriptionData object in invalid state';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getContactInfo());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getSpecificationDescript());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getType());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_ctor_invalidHashRef
#------------------------------------------
sub test_ctor_incompleteHashRef {
	# ...
	# Test the DescriptionData constructor with an invalid hashRef as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %args = ( author        => 'me',
				 contact       => 'me@suse.com',
				 type          => 'system',
			);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi, \%args);
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($descrpObj -> getAuthor());
	my $expected = 'XMLDescriptionData object in invalid state';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getContactInfo());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getSpecificationDescript());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getType());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_ctor_invalidHashRef
#------------------------------------------
sub test_ctor_invalidHashRef {
	# ...
	# Test the DescriptionData constructor with an invalid hashRef as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %args = ( author        => 'me',
				 contact       => 'me@suse.com',
				 specification => 'the test case',
				 type          => 'pablo',
			);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi, \%args);
	$this -> assert_not_null($descrpObj);
	my $expected = "Attempting to set invalid description type 'pablo'";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_ctor_noArgs
#------------------------------------------
sub test_ctor_noArgs {
	# ...
	# Test the DescriptionData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with no arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi);
	$this -> assert_not_null($descrpObj);
	$this -> assert_null($descrpObj -> getAuthor());
	my $expected = 'XMLDescriptionData object in invalid state';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getContactInfo());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getSpecificationDescript());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getType());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_ctor_typeArgInvalid
#------------------------------------------
sub test_ctor_typeArgInvalid {
	# ...
	# Test the DescriptionData constructor with an invalid string argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi, 'me',
												'me@suse.com',
												'the test case',
												'ola');
	$this -> assert_not_null($descrpObj);
	my $expected = "Attempting to set invalid description type 'ola'";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getAuthor());
	$expected = 'XMLDescriptionData object in invalid state';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getContactInfo());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getSpecificationDescript());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getType());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_ctor_validStrings
#------------------------------------------
sub test_ctor_validStrings {
	# ...
	# Test the DescriptionData constructor with valid string args
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi, 'me',
												'me@suse.com',
												'the test case',
												'system');
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $author = $descrpObj -> getAuthor();
	$this -> assert_str_equals('me', $author);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $contact = $descrpObj -> getContactInfo();
	$this -> assert_str_equals('me@suse.com', $contact);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $spec = $descrpObj -> getSpecificationDescript();
	$this -> assert_str_equals('the test case', $spec);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $type = $descrpObj -> getType();
	$this -> assert_str_equals('system', $type);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_ctor_validHashRef
#------------------------------------------
sub test_ctor_validHashRef {
	# ...
	# Test the DescriptionData constructor with a valid hashRef as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %args = ( author        => 'me',
				contact       => 'me@suse.com',
				specification => 'the test case',
				type          => 'boot',
			);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi, \%args);
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $author = $descrpObj -> getAuthor();
	$this -> assert_str_equals('me', $author);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $contact = $descrpObj -> getContactInfo();
	$this -> assert_str_equals('me@suse.com', $contact);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $spec = $descrpObj -> getSpecificationDescript();
	$this -> assert_str_equals('the test case', $spec);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $type = $descrpObj -> getType();
	$this -> assert_str_equals('boot', $type);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

#==========================================
# test_incompleteSetOnly1
#------------------------------------------
sub test_incompleteSetOnly1 {
	# ...
	# Test the DescriptionData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with no arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi);
	$this -> assert_not_null($descrpObj);
	$descrpObj = $descrpObj -> setAuthor('me');
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($descrpObj -> getAuthor());
	my $expected = 'XMLDescriptionData object in invalid state';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getContactInfo());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getSpecificationDescript());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getType());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_incompleteSetOnly2
#------------------------------------------
sub test_incompleteSetOnly2 {
	# ...
	# Test the DescriptionData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with no arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi);
	$this -> assert_not_null($descrpObj);
	$descrpObj = $descrpObj -> setAuthor('me');
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$descrpObj = $descrpObj -> setContactInfo('me@suse.com');
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($descrpObj -> getAuthor());
	my $expected = 'XMLDescriptionData object in invalid state';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getContactInfo());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getSpecificationDescript());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getType());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_incompleteSetOnly3
#------------------------------------------
sub test_incompleteSetOnly3 {
	# ...
	# Test the DescriptionData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with no arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi);
	$this -> assert_not_null($descrpObj);
	$descrpObj = $descrpObj -> setAuthor('me');
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$descrpObj = $descrpObj -> setContactInfo('me@suse.com');
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$descrpObj = $descrpObj -> setSpecificationDescript('a test case');
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_null($descrpObj -> getAuthor());
	my $expected = 'XMLDescriptionData object in invalid state';
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getContactInfo());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getSpecificationDescript());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	$this -> assert_null($descrpObj -> getType());
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('warning', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('oops', $state);
	return;
}

#==========================================
# test_validSet
#------------------------------------------
sub test_validSet {
	# ...
	# Test that we get a valid object after all values have been set
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	# Test with no arguments
	my $descrpObj = KIWIXMLDescriptionData -> new($kiwi);
	$this -> assert_not_null($descrpObj);
	$descrpObj = $descrpObj -> setAuthor('me');
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$descrpObj = $descrpObj -> setContactInfo('me@suse.com');
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$descrpObj = $descrpObj -> setSpecificationDescript('a test case');
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$descrpObj = $descrpObj -> setType('boot');
	$this -> assert_not_null($descrpObj);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $author = $descrpObj -> getAuthor();
	$this -> assert_str_equals('me', $author);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $contact = $descrpObj -> getContactInfo();
	$this -> assert_str_equals('me@suse.com', $contact);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $spec = $descrpObj -> getSpecificationDescript();
	$this -> assert_str_equals('a test case', $spec);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $type = $descrpObj -> getType();
	$this -> assert_str_equals('boot', $type);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	return;
}

1;
