#================
# FILE          : kiwiXMLEC2ConfigData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLEC2ConfigData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLEC2ConfigData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLEC2ConfigData;

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
	# Test the EC2ConfigData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the EC2ConfigData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi, 'foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_improperHashMemb
#------------------------------------------
sub test_ctor_improperHashMemb {
	# ...
	# Test the EC2ConfigData constructor with an improper type in the
	# initialization hash.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %args = ( ec2accountnr      => '1234567890',
				ec2certfile       => '/work/ec2/myaccount.cert',
				ec2privatekeyfile => '/work/ec2/mykey.pem',
				ec2region         => 'US-East'
			);
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi, \%args);
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting an array ref as entry of "ec2region" in the '
		. 'initialization hash.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($confDataObj);
	return;
}

#==========================================
# test_ctor_wInit
#------------------------------------------
sub test_ctor_wInit {
	# ...
	# Test the EC2ConfigData constructor with initialization
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @regions = qw /US-East EU-West AP-South/;
	my %args = ( ec2accountnr      => '1234567890',
				ec2certfile       => '/work/ec2/myaccount.cert',
				ec2privatekeyfile => '/work/ec2/mykey.pem',
				ec2region         => \@regions
			);
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi, \%args);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($confDataObj);
	my $acct = $confDataObj -> getAccountNumber();
	$this -> assert_str_equals('1234567890', $acct);
	my $cert = $confDataObj -> getCertFilePath();
	$this -> assert_str_equals('/work/ec2/myaccount.cert', $cert);
	my $pkey = $confDataObj -> getPrivateKeyFilePath();
	$this -> assert_str_equals('/work/ec2/mykey.pem', $pkey);
	my $setRegions = $confDataObj -> getRegions();
	$this -> assert_array_equal(\@regions, $setRegions);
	return;
}

#==========================================
# test_setAccountNumber
#------------------------------------------
sub test_setAccountNumber {
	# ...
	# Test the setAccountNumber method
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	# Verify initial state is empty
	my $actno = $confDataObj -> getAccountNumber();
	$this -> assert_null($actno);
	$confDataObj -> setAccountNumber('0987654321');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$actno = $confDataObj -> getAccountNumber();
	$this -> assert_str_equals('0987654321', $actno);
	return;
}

#==========================================
# test_setAccountNumber_noArg
#------------------------------------------
sub test_setAccountNumber_noArg {
	# ...
	# Test the setAccountNumber method without argument
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @regions = qw /US-East EU-West AP-South/;
	my %args = ( ec2accountnr      => '1234567890',
				ec2certfile       => '/work/ec2/myaccount.cert',
				ec2privatekeyfile => '/work/ec2/mykey.pem',
				ec2region         => \@regions
			);
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi, \%args);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	my $acct = $confDataObj -> getAccountNumber();
	$this -> assert_str_equals('1234567890', $acct);
	$confDataObj = $confDataObj -> setAccountNumber();
	$msg = $kiwi -> getMessage();
	my $expected = 'setAccountNumber: no account number provided, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($confDataObj);
	$acct = $confDataObj -> getAccountNumber();
	$this -> assert_str_equals('1234567890', $acct);
	# Test proper over-write
	$confDataObj -> setAccountNumber('0987654321');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$acct = $confDataObj -> getAccountNumber();
	$this -> assert_str_equals('0987654321', $acct);
	return;
}

#==========================================
# test_setCertFilePath
#------------------------------------------
sub test_setCertFilePath {
	# ...
	# Test the setCertFilePath method
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	# Verify initial state is empty
	my $cert = $confDataObj -> getCertFilePath();
	$this -> assert_null($cert);
	$confDataObj -> setCertFilePath('/tmp/tempCert.cert');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$cert = $confDataObj -> getCertFilePath();
	$this -> assert_str_equals('/tmp/tempCert.cert', $cert);
	return;
}

#==========================================
# test_setCertFilePath_noArg
#------------------------------------------
sub test_setCertFilePath_noArg {
	# ...
	# Test the setCertFilePath method without argument
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @regions = qw /US-East EU-West AP-South/;
	my %args = ( ec2accountnr      => '1234567890',
				ec2certfile       => '/work/ec2/myaccount.cert',
				ec2privatekeyfile => '/work/ec2/mykey.pem',
				ec2region         => \@regions
			);
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi, \%args);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	my $cert = $confDataObj -> getCertFilePath();
	$this -> assert_str_equals('/work/ec2/myaccount.cert', $cert);
	$confDataObj = $confDataObj -> setCertFilePath();
	$msg = $kiwi -> getMessage();
	my $expected = 'setCertFilePath: no certfile path given, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($confDataObj);
	$cert = $confDataObj -> getCertFilePath();
	$this -> assert_str_equals('/work/ec2/myaccount.cert', $cert);
	# Test proper over-write
	$confDataObj -> setCertFilePath('/tmp/tempCert.cert');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$cert = $confDataObj -> getCertFilePath();
	$this -> assert_str_equals('/tmp/tempCert.cert', $cert);
	return;
}

#==========================================
# test_setPrivateKeyFilePath
#------------------------------------------
sub test_setPrivateKeyFilePath {
	# ...
	# Test the setPrivateKeyFilePath method
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	# Verify initial state is empty
	my $pkeyP = $confDataObj -> getPrivateKeyFilePath();
	$this -> assert_null($pkeyP);
	$confDataObj -> setPrivateKeyFilePath('/tmp/tempKey.pem');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$pkeyP = $confDataObj -> getPrivateKeyFilePath();
	$this -> assert_str_equals('/tmp/tempKey.pem', $pkeyP);
	return;
}

#==========================================
# test_setPrivateKeyFilePath_noArg
#------------------------------------------
sub test_setPrivateKeyFilePath_noArg {
	# ...
	# Test the setPrivateKeyFilePath method without argument
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @regions = qw /US-East EU-West AP-South/;
	my %args = ( ec2accountnr      => '1234567890',
				ec2certfile       => '/work/ec2/myaccount.cert',
				ec2privatekeyfile => '/work/ec2/mykey.pem',
				ec2region         => \@regions
			);
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi, \%args);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	my $pkeyP = $confDataObj -> getPrivateKeyFilePath();
	$this -> assert_str_equals('/work/ec2/mykey.pem', $pkeyP);
	$confDataObj = $confDataObj -> setPrivateKeyFilePath();
	$msg = $kiwi -> getMessage();
	my $expected = 'setPrivateKeyFilePath: no private key file path given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($confDataObj);
	$pkeyP = $confDataObj -> getPrivateKeyFilePath();
	$this -> assert_str_equals('/work/ec2/mykey.pem', $pkeyP);
	# Test proper over-write
	$confDataObj = $confDataObj -> setPrivateKeyFilePath('/tmp/tempKey.pem');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$pkeyP = $confDataObj -> getPrivateKeyFilePath();
	$this -> assert_str_equals('/tmp/tempKey.pem', $pkeyP);
	return;
}

#==========================================
# test_setRegions
#------------------------------------------
sub test_setRegions {
	# ...
	# Test the setRegions method
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	# Verify initial state is empty
	my $setRegs = $confDataObj -> getRegions();
	$this -> assert_null($setRegs);
	my @regions = qw /US-East EU-West AP-South/;
	$confDataObj = $confDataObj -> setRegions(\@regions);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$setRegs = $confDataObj -> getRegions();
	$this -> assert_array_equal(\@regions, $setRegs);
	return;
}

#==========================================
# test_setRegionsImproperArg
#------------------------------------------
sub test_setRegionsImproperArg {
	# ...
	# Test the setRegions method with an improper argument type
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	# Verify initial state is empty
	my $regions = $confDataObj -> getRegions();
	$this -> assert_null($regions);
	my $res = $confDataObj -> setRegions('foo');
	$msg = $kiwi -> getMessage();
	my $expected = 'setRegions: expecting array ref as second argument.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setRegions_noArg
#------------------------------------------
sub test_setRegions_noArg {
	# ...
	# Test the setRegions method without argument
	# ----
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @regions = qw /US-East EU-West AP-South/;
	my %args = ( ec2accountnr      => '1234567890',
				ec2certfile       => '/work/ec2/myaccount.cert',
				ec2privatekeyfile => '/work/ec2/mykey.pem',
				ec2region         => \@regions
			);
	my $confDataObj = KIWIXMLEC2ConfigData -> new($kiwi, \%args);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	my $setRegs = $confDataObj -> getRegions();
	$this -> assert_array_equal(\@regions, $setRegs);
	$confDataObj = $confDataObj -> setRegions();
	$msg = $kiwi -> getMessage();
	my $expected = 'setRegions: no regions given, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('completed', $state);
	$this -> assert_not_null($confDataObj);
	$setRegs = $confDataObj -> getRegions();
	$this -> assert_array_equal(\@regions, $setRegs);
	my @newRegs = qw /US-West AP-Japan/;
	# Test proper over-write
	$confDataObj = $confDataObj -> setRegions(\@newRegs);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($confDataObj);
	$setRegs = $confDataObj -> getRegions();
	$this -> assert_array_equal(\@newRegs, $setRegs);
	return;
}
1;
