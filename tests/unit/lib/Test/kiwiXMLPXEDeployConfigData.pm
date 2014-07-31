#================
# FILE          : kiwiXMLPXEDeployConfigData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLPXEDeployConfigData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLPXEDeployConfigData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLPXEDeployConfigData;

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
  # Test the PXEDeployConfigData constructor with an improper
  # argument type
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDataObj = KIWIXMLPXEDeployConfigData -> new('foo');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Expecting a hash ref as first argument if provided';
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
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
  # ...
  # Test the PXEDeployConfigData constructor with no argument
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDataObj = KIWIXMLPXEDeployConfigData -> new();
  my $msg = $kiwi -> getMessage();
  my $expectedMsg = 'KIWIXMLPXEDeployConfigData: must be constructed with a '
    . 'keyword hash as argument';
  $this -> assert_str_equals($expectedMsg, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($confDataObj);
  return;
}

#==========================================
# test_ctor_unsuportedArch
#------------------------------------------
sub test_ctor_unsuportedArch {
  # ...
  # Test the PXEDeployConfigData constructor with an unsupported architecture
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
    arch   => 'tegra',
    dest   => '/dev/sda1',
    source => '/pxeData/myImage'
  );
  my $confDataObj = KIWIXMLPXEDeployConfigData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expectedMsg = "Specified arch 'tegra' is not supported";
  $this -> assert_str_equals($expectedMsg, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($confDataObj);
  return;
}

#==========================================
# test_ctor_unsupportedKW
#------------------------------------------
sub test_ctor_unsupportedKW {
  # ...
  # Test constructor with an unsupported keyword in the initialization data
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
      arch        => 'ppc64',
    destination => '/dev/sda1',
    source      => '/pxeData/myImage'
  );
  my $confDataObj = KIWIXMLPXEDeployConfigData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWIXMLPXEDeployConfigData: Unsupported keyword argument '
    . "'destination' in initialization structure.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($confDataObj);
  return;
}

#==========================================
# test_getArch
#------------------------------------------
sub test_getArch {
  # ...
  # Verify that the proper architecture value is returned.
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
    arch   => 's390',
    dest   => '/dev/sda1',
    source => '/pxeData/myImage'
  );
  my $confDataObj = KIWIXMLPXEDeployConfigData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $value = $confDataObj -> getArch();
  $this -> assert_str_equals('s390', $value);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($confDataObj);
  return;
}

#==========================================
# test_getDestination
#------------------------------------------
sub test_getDestination {
  # ...
  # Verify that the proper destination is returned.
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
    arch   => 's390',
    dest   => '/dev/sda1',
    source => '/pxeData/myImage'
  );
  my $confDataObj = KIWIXMLPXEDeployConfigData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $value = $confDataObj -> getDestination();
  $this -> assert_str_equals('/dev/sda1', $value);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($confDataObj);
  return;
}

#==========================================
# test_getSource
#------------------------------------------
sub test_getSource {
  # ...
  # Verify that the proper sourceis returned.
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
    arch   => 's390',
    dest   => '/dev/sda1',
    source => '/pxeData/myImage'
  );
  my $confDataObj = KIWIXMLPXEDeployConfigData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $value = $confDataObj -> getSource();
  $this -> assert_str_equals('/pxeData/myImage', $value);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($confDataObj);
  return;
}

1;
