#================
# FILE          : kiwiXMLSplitData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLSplitData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLSplitData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use Readonly;
use base qw /Common::ktTestCase/;

use KIWIXMLSplitData;

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
sub test_ctor {
	# ...
	# Test the SplitData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the SplitData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, 'foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_improperDataBehavior
#------------------------------------------
sub test_ctor_improperDataBehavior {
	# ...
	# Test the SplitData constructor with an initialization hash
	# that contains improper data type for the specified behavior
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @tmpFiles = qw ( /etc /etc* );
	my %tmpSettings = ( all => \@tmpFiles);
	my %temp = ( files =>  \%tmpSettings);
	my %init = ( persistent => 'yes',
				temporary  => \%temp
	    );
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = "Expecting hash ref as entry for 'persistent' in "
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_improperDataContent
#------------------------------------------
sub test_ctor_improperDataContent {
	# ...
	# Test the SplitData constructor with an initialization hash
	# that contains improper data type for the content
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %tmpSettings = ( all => 'foo');
	my %temp = ( files =>  \%tmpSettings);
	my %init = ( temporary  => \%temp );
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = "Expecting array ref as the entry for 'all' files in "
		. "initialization structure for 'temporary' with 'files'.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_improperDataUsage
#------------------------------------------
sub test_ctor_improperDataUsage {
	# ...
	# Test the SplitData constructor with an initialization hash
	# that contains improper data type for the specified usage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %temp = ( files => 'foo');
	my %init = ( temporary  => \%temp );
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = "Expecting hash ref as entry for 'files' in "
		. 'initialization structure.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDataBehavior
#------------------------------------------
sub test_ctor_initUnsupportedDataBehavior {
	# ...
	# Test the SplitData constructor with an initialization hash
	# that contains unsupported data in the first level (behavior)
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				persistent => 'yes',
				temporary  => 'yes',
				unknown    => 'foo'
	);
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLSplitData: Unsupported keyword argument '
		. "'unknown' in initialization structure.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDataContent
#------------------------------------------
sub test_ctor_initUnsupportedDataContent {
	# ...
	# Test the SplitData constructor with an initialization hash
	# that contains unsupported data in the third level (content)
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @tmpFiles = qw ( /etc /etc* );
	my %tmpSettings = ( all   => \@tmpFiles,
						arm95 => \@tmpFiles
					);
	my %temp = ( files =>  \%tmpSettings );
	my %init = ( temporary  => \%temp );
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Initialization structure: specified architecture '
		. "'arm95' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedDataUsage
#------------------------------------------
sub test_ctor_initUnsupportedDataUsage {
	# ...
	# Test the SplitData constructor with an initialization hash
	# that contains unsupported data in the second level (usage)
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @tmpFiles = qw ( /etc /etc* );
	my %tmpSettings = ( all => \@tmpFiles);
	my %temp = ( files =>  \%tmpSettings,
				foo   => 'bar'
			);
	my %init = ( temporary  => \%temp );
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Unsupported option in initialization structure '
		. "for 'temporary', found 'foo'";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($splitDataObj);
	return;
}

#==========================================
# test_ctor_withInit
#------------------------------------------
sub test_ctor_withInit {
	# ...
	# Test the SplitData constructor with a valid initialization hash
	# --
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @tmpFiles = qw ( /etc /etc* );
	my %tmpSettings = ( all => \@tmpFiles);
	my %temp = ( files =>  \%tmpSettings);
	my %init = ( temporary  => \%temp );
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($splitDataObj);
	return;
}

#==========================================
# test_getPersistentExceptions
#------------------------------------------
sub test_getPersistentExceptions {
	# ...
	# Test the getPersistentExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getPersistentExceptions('s390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /home/demouser /home/demouser/*
						/etc/s390/base.conf /etc/s390/opt
					);
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getPersistentExceptionsInvalidArg
#------------------------------------------
sub test_getPersistentExceptionsInvalidArg {
	# ...
	# Test the getPersistentExceptions method with an invalid architecture
	# argument.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getPersistentExceptions('arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = "getPersistentExceptions: specified architecture 'arm95' "
		. 'is not supported.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($data);
	return;
}

#==========================================
# test_getPersistentExceptionsNoArg
#------------------------------------------
sub test_getPersistentExceptionsNoArg {
	# ...
	# Test the getPersistentExceptions method with no architecture argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getPersistentExceptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /home/demouser /home/demouser/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getPersistentFiles
#------------------------------------------
sub test_getPersistentFiles {
	# ...
	# Test the getPersistentFiles method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getPersistentFiles('s390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /etc/s390 /etc/s390/* /home /home/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getPersistentFilesInvalidArg
#------------------------------------------
sub test_getPersistentFilesInvalidArg {
	# ...
	# Test the getPersistentFiles method with an invalid architecture
	# argument.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getPersistentFiles('arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = "getPersistentFiles: specified architecture 'arm95' "
		. 'is not supported.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($data);
	return;
}

#==========================================
# test_getPersistentFilesNoArg
#------------------------------------------
sub test_getPersistentFilesNoArg {
	# ...
	# Test the getPersistentFiles method with no architecture argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getPersistentFiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /home /home/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getTemporaryExceptions
#------------------------------------------
sub test_getTemporaryExceptions {
	# ...
	# Test the getTemporaryExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getTemporaryExceptions('s390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /run/media/sysuser /run/media/sysuser/*
						/var/run/s390/var.conf
					);
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getTemporaryExceptionsInvalidArg
#------------------------------------------
sub test_getTemporaryExceptionsInvalidArg {
	# ...
	# Test the getTemporaryExceptions method with an invalid architecture
	# argument.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getTemporaryExceptions('arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = "getTemporaryExceptions: specified architecture 'arm95' "
		. 'is not supported.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($data);
	return;
}

#==========================================
# test_getTemporaryExceptionsNoArg
#------------------------------------------
sub test_getTemporaryExceptionsNoArg {
	# ...
	# Test the getTemporaryExceptions method with no architecture argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getTemporaryExceptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /run/media/sysuser /run/media/sysuser/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getTemporaryFiles
#------------------------------------------
sub test_getTemporaryFiles {
	# ...
	# Test the getTemporaryFiles method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getTemporaryFiles('s390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /run/media /run/media/*
						/var/run/s390 /var/run/s390/*
					);
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_getTemporaryFilesInvalidArg
#------------------------------------------
sub test_getTemporaryFilesInvalidArg {
	# ...
	# Test the getTemporaryFiles method with an invalid architecture
	# argument.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getTemporaryFiles('arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = "getTemporaryFiles: specified architecture 'arm95' "
		. 'is not supported.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($data);
	return;
}

#==========================================
# test_getTemporaryFilesNoArg
#------------------------------------------
sub test_getTemporaryFilesNoArg {
	# ...
	# Test the getTemporaryFiles method with no architecture argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $data = $splitDataObj -> getTemporaryFiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /run/media /run/media/* );
	$this -> assert_array_equal(\@expected, \@names);
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
	my $splitDataObj = $this -> __getSplitDataObj();
	my $elem = $splitDataObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<split>'
		. '<persistent>'
		. '<except name="/home/demouser"/>'
		. '<except name="/home/demouser/*"/>'
		. '<except name="/etc/s390/base.conf" arch="s390"/>'
		. '<except name="/etc/s390/opt" arch="s390"/>'
		. '<file name="/home"/>'
		. '<file name="/home/*"/>'
		. '<file name="/etc/s390" arch="s390"/>'
		. '<file name="/etc/s390/*" arch="s390"/>'
		. '</persistent>'
		. '<temporary>'
		. '<except name="/run/media/sysuser"/>'
		. '<except name="/run/media/sysuser/*"/>'
		. '<except name="/var/run/s390/var.conf" arch="s390"/>'
		. '<file name="/run/media"/>'
		. '<file name="/run/media/*"/>'
		. '<file name="/var/run/s390" arch="s390"/>'
		. '<file name="/var/run/s390/*" arch="s390"/>'
		. '</temporary>'
		. '</split>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_setPersistentExceptions
#------------------------------------------
sub test_setPersistentExceptions {
	# ...
	# Test the setPersistentExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setPersistentExceptions(\@expected);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentExceptions();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentExceptionsArch
#------------------------------------------
sub test_setPersistentExceptionsArch {
	# ...
	# Test the setPersistentExceptions method for a given arch
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	$splitDataObj = $splitDataObj -> setPersistentExceptions(\@expected,'ppc');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentExceptions('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentExceptionsArchPlus
#------------------------------------------
sub test_setPersistentExceptionsArchPlus {
	# ...
	# Test the setPersistentExceptions method for a given arch and
	# general
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expectedArch = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	my @expectedGen  = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setPersistentExceptions(\@expectedArch,
															'ppc'
															);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	$splitDataObj = $splitDataObj -> setPersistentExceptions(\@expectedGen);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentExceptions('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = @expectedGen;
	push @expected, @expectedArch;
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentExceptionsImproperArg
#------------------------------------------
sub test_setPersistentExceptionsImproperArg {
	# ...
	# Test the setPersistentExceptions method with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my $res = $splitDataObj -> setPersistentExceptions('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPersistentExceptions: expecting array ref as first '
		. 'argument if given.';
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
# test_setPersistentExceptionsNoArg
#------------------------------------------
sub test_setPersistentExceptionsNoArg {
	# ...
	# Test the setPersistentExceptions method with no argument
	# this should result in a data reset for the platform independent data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setPersistentExceptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentExceptions('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /etc/s390/base.conf /etc/s390/opt );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentExceptionsArchArg
#------------------------------------------
sub test_setPersistentExceptionsArchArg {
	# ...
	# Test the setPersistentExceptions method with only the architecture
	# this should result in a data reset for the platform sepcific data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setPersistentExceptions(undef, 's390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentExceptions('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /home/demouser /home/demouser/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentExceptionsUnsupportedArch
#------------------------------------------
sub test_setPersistentExceptionsUnsupportedArch {
	# ...
	# Test the setPersistentExceptions method with an unsupported arch argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $res = $splitDataObj -> setPersistentExceptions(undef, 'arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPersistentExceptions: specified architecture '
		. "'arm95' is not supported.";
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
# test_setPersistentFiles
#------------------------------------------
sub test_setPersistentFiles {
	# ...
	# Test the setPersistentFiles method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setPersistentFiles(\@expected);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentFiles();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentFilesArch
#------------------------------------------
sub test_setPersistentFilesArch {
	# ...
	# Test the setPersistentFiles method for a given arch
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	$splitDataObj = $splitDataObj -> setPersistentFiles(\@expected,'ppc');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentFiles('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentFilesArchPlus
#------------------------------------------
sub test_setPersistentFilesArchPlus {
	# ...
	# Test the setPersistentFiles method for a given arch and
	# general
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expectedArch = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	my @expectedGen  = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setPersistentFiles(
		\@expectedArch,
		'ppc'
	);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	$splitDataObj = $splitDataObj -> setPersistentFiles(\@expectedGen);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentFiles('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = @expectedGen;
	push @expected, @expectedArch;
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentFilesImproperArg
#------------------------------------------
sub test_setPersistentFilesImproperArg {
	# ...
	# Test the setPersistentFiles method with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my $res = $splitDataObj -> setPersistentFiles('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPersistentFiles: expecting array ref as first '
		. 'argument if given.';
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
# test_setPersistentFilesNoArg
#------------------------------------------
sub test_setPersistentFilesNoArg {
	# ...
	# Test the setPersistentFiles method with no argument
	# this should result in a data reset for the platform independent data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setPersistentFiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentFiles('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /etc/s390 /etc/s390/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentFilesArchArg
#------------------------------------------
sub test_setPersistentFilesArchArg {
	# ...
	# Test the setPersistentFiles method with only the architecture
	# this should result in a data reset for the platform sepcific data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setPersistentFiles(undef, 's390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getPersistentFiles('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /home /home/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setPersistentFilesUnsupportedArch
#------------------------------------------
sub test_setPersistentFilesUnsupportedArch {
	# ...
	# Test the setPersistentFiles method with an unsupported arch argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $res = $splitDataObj -> setPersistentFiles(undef, 'arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPersistentFiles: specified architecture '
		. "'arm95' is not supported.";
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
# test_setTemporaryExceptions
#------------------------------------------
sub test_setTemporaryExceptions {
	# ...
	# Test the setTemporaryExceptions method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setTemporaryExceptions(\@expected);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryExceptions();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryExceptionsArch
#------------------------------------------
sub test_setTemporaryExceptionsArch {
	# ...
	# Test the setTemporaryExceptions method for a given arch
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	$splitDataObj = $splitDataObj -> setTemporaryExceptions(\@expected,'ppc');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryExceptions('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryExceptionsArchPlus
#------------------------------------------
sub test_setTemporaryExceptionsArchPlus {
	# ...
	# Test the setTemporaryExceptions method for a given arch and
	# general
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expectedArch = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	my @expectedGen  = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setTemporaryExceptions(\@expectedArch,
															'ppc'
															);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	$splitDataObj = $splitDataObj -> setTemporaryExceptions(\@expectedGen);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryExceptions('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = @expectedGen;
	push @expected, @expectedArch;
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryExceptionsImproperArg
#------------------------------------------
sub test_setTemporaryExceptionsImproperArg {
	# ...
	# Test the setTemporaryExceptions method with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my $res = $splitDataObj -> setTemporaryExceptions('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setTemporaryExceptions: expecting array ref as first '
		. 'argument if given.';
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
# test_setTemporaryExceptionsNoArg
#------------------------------------------
sub test_setTemporaryExceptionsNoArg {
	# ...
	# Test the setTemporaryExceptions method with no argument
	# this should result in a data reset for the platform independent data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setTemporaryExceptions();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryExceptions('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /var/run/s390/var.conf );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryExceptionsArchArg
#------------------------------------------
sub test_setTemporaryExceptionsArchArg {
	# ...
	# Test the setTemporaryExceptions method with only the architecture
	# this should result in a data reset for the platform sepcific data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setTemporaryExceptions(undef, 's390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryExceptions('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /run/media/sysuser /run/media/sysuser/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryExceptionsUnsupportedArch
#------------------------------------------
sub test_setTemporaryExceptionsUnsupportedArch {
	# ...
	# Test the setTemporaryExceptions method with an unsupported arch argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $res = $splitDataObj -> setTemporaryExceptions(undef, 'arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setTemporaryExceptions: specified architecture '
		. "'arm95' is not supported.";
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
# test_setTemporaryFiles
#------------------------------------------
sub test_setTemporaryFiles {
	# ...
	# Test the setTemporaryFiles method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setTemporaryFiles(\@expected);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryFiles();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryFilesArch
#------------------------------------------
sub test_setTemporaryFilesArch {
	# ...
	# Test the setTemporaryFiles method for a given arch
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expected = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	$splitDataObj = $splitDataObj -> setTemporaryFiles(\@expected,'ppc');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryFiles('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryFilesArchPlus
#------------------------------------------
sub test_setTemporaryFilesArchPlus {
	# ...
	# Test the setTemporaryFiles method for a given arch and
	# general
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my @expectedArch = qw ( /etc/ppc/base.conf /etc/ppc/opt );
	my @expectedGen  = qw ( /home/demouser /home/demouser/* );
	$splitDataObj = $splitDataObj -> setTemporaryFiles(\@expectedArch,
															'ppc'
															);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	$splitDataObj = $splitDataObj -> setTemporaryFiles(\@expectedGen);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryFiles('ppc');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = @expectedGen;
	push @expected, @expectedArch;
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryFilesImproperArg
#------------------------------------------
sub test_setTemporaryFilesImproperArg {
	# ...
	# Test the setTemporaryFiles method with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi);
	my $res = $splitDataObj -> setTemporaryFiles('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setTemporaryFiles: expecting array ref as first '
		. 'argument if given.';
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
# test_setTemporaryFilesNoArg
#------------------------------------------
sub test_setTemporaryFilesNoArg {
	# ...
	# Test the setTemporaryFiles method with no argument
	# this should result in a data reset for the platform independent data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setTemporaryFiles();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryFiles('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /var/run/s390 /var/run/s390/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryFilesArchArg
#------------------------------------------
sub test_setTemporaryFilesArchArg {
	# ...
	# Test the setTemporaryFiles method with only the architecture
	# this should result in a data reset for the platform sepcific data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	$splitDataObj = $splitDataObj -> setTemporaryFiles(undef, 's390');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($splitDataObj);
	my $data = $splitDataObj -> getTemporaryFiles('s390');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @names;
	for my $dObj (@{$data}) {
		push @names, $dObj -> getName();
	}
	my @expected = qw ( /run/media /run/media/* );
	$this -> assert_array_equal(\@expected, \@names);
	return;
}

#==========================================
# test_setTemporaryFilesUnsupportedArch
#------------------------------------------
sub test_setTemporaryFilesUnsupportedArch {
	# ...
	# Test the setTemporaryFiles method with an unsupported arch argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $splitDataObj = $this -> __getSplitDataObj();
	my $res = $splitDataObj -> setTemporaryFiles(undef, 'arm95');
	my $msg = $kiwi -> getMessage();
	my $expected = 'setTemporaryFiles: specified architecture '
		. "'arm95' is not supported.";
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
# Private helper methods
#------------------------------------------
#==========================================
# __getSplitDataObj
#------------------------------------------
sub __getSplitDataObj {
	# ...
	# Helper to construct a fully populated SplitData object using
	# initialization.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @persExceptArch = qw ( /etc/s390/base.conf /etc/s390/opt );
	my @persExceptGen  = qw ( /home/demouser /home/demouser/* );
	my @persFilesArch  = qw ( /etc/s390 /etc/s390/* );
	my @persFilesGen   = qw ( /home /home/* );
	my %persFiles = (
		all  => \@persFilesGen,
		s390 => \@persFilesArch
	);
	my %persExcept = (
		all  => \@persExceptGen,
		s390 => \@persExceptArch
	);
	my %persSettings = (
		except => \%persExcept,
		files  => \%persFiles
	);
	my @tempExceptArch = qw ( /var/run/s390/var.conf );
	my @tempExceptGen  = qw ( /run/media/sysuser /run/media/sysuser/* );
	my @tempFilesArch  = qw ( /var/run/s390 /var/run/s390/* );
	my @tempFilesGen   = qw ( /run/media /run/media/* );
	my %tempFiles = (
		all  => \@tempFilesGen,
		s390 => \@tempFilesArch
	);
	my %tempExcept = (
		all  => \@tempExceptGen,
		s390 => \@tempExceptArch
	);
	my %tempSettings = (
		except => \%tempExcept,
		files  => \%tempFiles
	);
	my %init = (
		persistent => \%persSettings,
		temporary  => \%tempSettings
	);
	my $splitDataObj = KIWIXMLSplitData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($splitDataObj);
	return $splitDataObj;
}

1;
