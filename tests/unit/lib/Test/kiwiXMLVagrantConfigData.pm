#================
# FILE          : kiwiXMLVagrantConfigData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLVagrantConfigData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLVagrantConfigData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use Readonly;
use base qw /Common::ktTestCase/;

use KIWIXMLVagrantConfigData;


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
# test_ctor
#------------------------------------------
sub test_ctor {
  # ...
  # Test the VagrantConfigData constructor
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDataObj = KIWIXMLVagrantConfigData -> new();
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
  # Test the VagrantConfigData constructor with an improper argument type
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $confDataObj = KIWIXMLVagrantConfigData -> new('foo');
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
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
  # ...
  # Test the VagrantConfigData constructor with an initialization hash
  # that contains unsupported data
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
    firmwaredriver => 'b43'
  );
  my $confDataObj = KIWIXMLVagrantConfigData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWIXMLVagrantConfigData: Unsupported keyword argument '
    . "'firmwaredriver' in initialization structure.";
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
# test_getProvider
#------------------------------------------
sub test_getProvider {
  # ...
  # Test the getProvider method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $init = $this -> __getBaseInitHash();
  my $confDataObj = KIWIXMLVagrantConfigData -> new($init);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($confDataObj);
  my $scan = $confDataObj -> getProvider();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('libvirt', $scan);
  return;
}

#==========================================
# test_getVirtualSize
#------------------------------------------
sub test_getVirtualSize {
  # ...
  # Test the getVirtualSize method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $init = $this -> __getBaseInitHash();
  my $confDataObj = KIWIXMLVagrantConfigData -> new($init);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($confDataObj);
  my $scan = $confDataObj -> getVirtualSize();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('42', $scan);
  return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getBaseInitHash
#------------------------------------------
sub __getBaseInitHash {
  # ...
  # Setup a basic initialization hash for the VagrantConfigData object.
  # This method does not configure any of the potentially conflicting
  # settings.
  # ---
  my $this = shift;
  my %init = (
    provider  => 'libvirt',
    virtual_size => '42'
  );
  return \%init;
}

1;
