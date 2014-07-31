#================
# FILE          : kiwiXMLPXEDeployData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLPXEDeployData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLPXEDeployData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use Readonly;
use base qw /Common::ktTestCase/;

use KIWIXMLPXEDeployData;

#==========================================
# constants
#------------------------------------------
Readonly my $ARBITRARY_MULTIPLY => 10;
Readonly my $PART_ID_TOO_BIG    => 5;
Readonly my $THIRD_PART         => 3;

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
# test_createPartition
#------------------------------------------
sub test_createPartition {
  # ...
  # Test the createPartition method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my %partInfo = (
    mountpoint  => '/home',
    number      => '3',
    size        => '400G',
    target      => 'true',
    type        => '0x83'
  );
  my $id = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($THIRD_PART, $id);
  my $mntP = $pxeDataObj -> getPartitionMountpoint($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/home', $mntP);
  my $num = $pxeDataObj -> getPartitionNumber($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
   $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($id, $num);
  my $size = $pxeDataObj -> getPartitionSize($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('400G', $size);
  my $tgt = $pxeDataObj -> getPartitionTarget($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals(1, $tgt);
  my $type = $pxeDataObj -> getPartitionType($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x83', $type);
  my @pIDs = @{$pxeDataObj -> getPartitionIDs()};
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my @expected = ( 1, 2, $THIRD_PART );
  $this -> assert_array_equal(\@expected, \@pIDs);
  return;
}

#==========================================
# test_createPartitionDefaultMountP
#------------------------------------------
sub test_createPartitionDefaultMountP {
  # ...
  # Test the createPartition method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my %partInfo = (
    number      => '3',
    size        => '400G',
    target      => 'true',
    type        => '0x83'
  );
  my $id = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($THIRD_PART, $id);
  my $mntP = $pxeDataObj -> getPartitionMountpoint($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('x', $mntP);
  my $num = $pxeDataObj -> getPartitionNumber($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
   $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($id, $num);
  my $size = $pxeDataObj -> getPartitionSize($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('400G', $size);
  my $tgt = $pxeDataObj -> getPartitionTarget($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals(1, $tgt);
  my $type = $pxeDataObj -> getPartitionType($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x83', $type);
  my @pIDs = @{$pxeDataObj -> getPartitionIDs()};
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my @expected = ( 1, 2, $THIRD_PART );
  $this -> assert_array_equal(\@expected, \@pIDs);
  return;
}

#==========================================
# test_createPartitionDefaultSize
#------------------------------------------
sub test_createPartitionDefaultSize {
  # ...
  # Test the createPartition method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my %partInfo = (
    mountpoint  => '/home',
    number      => '3',
    target      => 'true',
    type        => '0x83'
  );
  my $id = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($THIRD_PART, $id);
  my $mntP = $pxeDataObj -> getPartitionMountpoint($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/home', $mntP);
  my $num = $pxeDataObj -> getPartitionNumber($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
   $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($id, $num);
  my $size = $pxeDataObj -> getPartitionSize($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('x', $size);
  my $tgt = $pxeDataObj -> getPartitionTarget($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals(1, $tgt);
  my $type = $pxeDataObj -> getPartitionType($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x83', $type);
  my @pIDs = @{$pxeDataObj -> getPartitionIDs()};
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my @expected = ( 1, 2, $THIRD_PART );
  $this -> assert_array_equal(\@expected, \@pIDs);
  return;
}

#==========================================
# test_createPartitionDefaultTargetFalse
#------------------------------------------
sub test_createPartitionDefaultTargetFalse {
  # ...
  # Test the createPartition method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my %partInfo = (
    mountpoint  => '/home',
    number      => '3',
    size        => '400G',
    target      => 'false',
    type        => '0x83'
  );
  my $id = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($THIRD_PART, $id);
  my $mntP = $pxeDataObj -> getPartitionMountpoint($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/home', $mntP);
  my $num = $pxeDataObj -> getPartitionNumber($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
   $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($id, $num);
  my $size = $pxeDataObj -> getPartitionSize($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('400G', $size);
  my $tgt = $pxeDataObj -> getPartitionTarget($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals(0, $tgt);
  my $type = $pxeDataObj -> getPartitionType($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x83', $type);
  my @pIDs = @{$pxeDataObj -> getPartitionIDs()};
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my @expected = ( 1, 2, $THIRD_PART );
  $this -> assert_array_equal(\@expected, \@pIDs);
  return;
}

#==========================================
# test_createPartitionIcompleteArgNoNum
#------------------------------------------
sub test_createPartitionIcompleteArgNoNum {
  # ...
  # Test the createPartition method with incomplete data
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my %partInfo = ( type => '0x83' );
  my $res = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  my $expected = 'createPartition: must provide "number" and "type" entry '
    . 'in hash arg.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createPartitionIcompleteArgNoType
#------------------------------------------
sub test_createPartitionIcompleteArgNotype {
  # ...
  # Test the createPartition method with incomplete data
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my %partInfo = ( number => 2 );
  my $res = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  my $expected = 'createPartition: must provide "number" and "type" entry '
    . 'in hash arg.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createPartitionInvalidArgNum
#------------------------------------------
sub test_createPartitionInvalidArgNum {
  # ...
  # Test the createPartition method with invalid data for the number
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my %partInfo = (
    number => '5',
    type   => '0x83'
  );
  my $res = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  my $expected = 'createPartition: invalid partition ID specified, must be '
    . 'between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createPartitionInvalidArgType
#------------------------------------------
sub test_createPartitionInvalidArgType {
  # ...
  # Test the createPartition method with an invalid argument type
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> createPartition('foo');
  my $msg = $kiwi -> getMessage();
  my $expected = 'createPartition: expecting hash ref as argument.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createPartitionOverwrite
#------------------------------------------
sub test_createPartitionOverwrite {
  # ...
  # Test the createPartition method overwriting an existing entry
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my %partInfo = (
    mountpoint  => '/swap',
      number      => '2',
    size        => '4G',
    target      => 'false',
    type        => '0x82'
  );
  my $id = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  my $expected = 'createPartition: overwriting data for partition with id: '
      . "'2'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('info', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('completed', $state);
  $this -> assert_equals(2, $id);
  my $mntP = $pxeDataObj -> getPartitionMountpoint($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/swap', $mntP);
  my $num = $pxeDataObj -> getPartitionNumber($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
   $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals($id, $num);
  my $size = $pxeDataObj -> getPartitionSize($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('4G', $size);
  my $tgt = $pxeDataObj -> getPartitionTarget($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('false', $tgt);
  my $type = $pxeDataObj -> getPartitionType($id);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x82', $type);
  return;
}

#==========================================
# test_createPartitionUnsupportedEntry
#------------------------------------------
sub test_createPartitionUnsupportedEntry {
  # ...
  # Test the createPartition method with unsupported data entry
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my %partInfo = (
    label  => 'root',
    number => '3',
    type   => '0x83'
  );
  my $res = $pxeDataObj -> createPartition(\%partInfo);
  my $msg = $kiwi -> getMessage();
  my $expected = 'createPartition: unsupported option in '
    . "argument hash for partition setup, found 'label'";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createUnionFSConfig
#------------------------------------------
sub test_createUnionFSConfig {
  # ...
  # Test the createUnionFSConfig method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> createUnionFSConfig(
    '/dev/sdc1',
    '/dev/sdc2',
    'clicfs'
  );
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_not_null($pxeDataObj);
  my $unionRO = $pxeDataObj -> getUnionRO();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdc1', $unionRO);
  my $unionRW = $pxeDataObj -> getUnionRW();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdc2', $unionRW);
  my $unionType = $pxeDataObj -> getUnionType();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
   $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('clicfs', $unionType);
  return;
}

#==========================================
# test_createUnionFSConfigOverwrite
#------------------------------------------
sub test_createUnionFSConfigOverwrite {
  # ...
  # Test the createUnionFSConfig method overwriting existing config
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  $pxeDataObj = $pxeDataObj -> createUnionFSConfig(
    '/dev/sdc1',
    '/dev/sdc2',
    'clicfs'
  );
  my $msg = $kiwi -> getMessage();
  my $expected = 'createUnionFSConfig: overwriting existing union fs '
    . 'config.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('info', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('completed', $state);
  $this -> assert_not_null($pxeDataObj);
  my $unionRO = $pxeDataObj -> getUnionRO();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdc1', $unionRO);
  my $unionRW = $pxeDataObj -> getUnionRW();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdc2', $unionRW);
  my $unionType = $pxeDataObj -> getUnionType();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
   $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('clicfs', $unionType);
  return;
}

#==========================================
# test_createUnionFSConfigInvalidType
#------------------------------------------
sub test_createUnionFSConfigInvalidType {
  # ...
  # Test the createUnionFSConfig method no 3rd argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> createUnionFSConfig('/dev/sdc1',
                        '/dev/sdc2',
                        'aufs'
                        );
  my $msg = $kiwi -> getMessage();
  my $expected = 'createUnionFSConfig: unionType argument must be "clicfs".';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createUnionFSConfigMissing2Args
#------------------------------------------
sub test_createUnionFSConfigMissing2Args {
  # ...
  # Test the createUnionFSConfig method 2 arguments missing
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> createUnionFSConfig('/dev/sdc1');
  my $msg = $kiwi -> getMessage();
  my $expected = 'createUnionFSConfig: must be called with 3 arguments, '
    . 'unionRO, unionRW, unionType.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createUnionFSConfigMissing3rdArg
#------------------------------------------
sub test_createUnionFSConfigMissing3rdArg {
  # ...
  # Test the createUnionFSConfig method no 3rd argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> createUnionFSConfig('/dev/sdc1',
                        '/dev/sdc2',
                        );
  my $msg = $kiwi -> getMessage();
  my $expected = 'createUnionFSConfig: must be called with 3 arguments, '
    . 'unionRO, unionRW, unionType.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_createUnionFSConfigNoArg
#------------------------------------------
sub test_createUnionFSConfigNoArg {
  # ...
  # Test the createUnionFSConfig method with no arguments
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> createUnionFSConfig();
  my $msg = $kiwi -> getMessage();
  my $expected = 'createUnionFSConfig: must be called with 3 arguments, '
    . 'unionRO, unionRW, unionType.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
  # ...
  # Test the PXEDeployData constructor
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
  # ...
  # Test the PXEDeployData constructor with an improper argument type
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new('foo');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Expecting a hash ref as first argument if provided';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initImproperPartsIDTooHigh
#------------------------------------------
sub test_ctor_initImproperPartsIDTooHigh {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains too many partition entries
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %partitions;
  my $id = 1;
  while ($id < $PART_ID_TOO_BIG) {
      my $sz = $id * $ARBITRARY_MULTIPLY;
      my %data = ( mountpoint => "/dev/sdx$id",
          size       => "$sz",
      );
      $partitions{$id+1} = \%data;
      $id += 1;
  }
  my %init = ( partitions => \%partitions );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Specified a parttion number larger than 4 in '
      . 'initialization hash.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initImproperPartsTooMany
#------------------------------------------
sub test_ctor_initImproperPartsTooMany {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains too many partition entries
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %partitions;
  my $id = 1;
  while ($id < $PART_ID_TOO_BIG + 1) {
      my $sz = $id * $ARBITRARY_MULTIPLY;
      my %data = ( mountpoint => "/dev/sdx$id",
          size       => "$sz",
      );
      $partitions{$id} = \%data;
      $id += 1;
  }
  my %init = ( partitions => \%partitions );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Specified more than 4 partitions in initialization '
      . 'hash.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initImproperUnionType
#------------------------------------------
sub test_ctor_initImproperUnionType {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains an improper unionType setting
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = ( unionType => 'aufs' );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Type specified for union fs is not supported, only '
    . '"clicfs" is supported';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompletePartitionNoType
#------------------------------------------
sub test_ctor_initIncompletePartitionNoType {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete partition settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %diskData1  = (
          mountpoint => q{/},
          size       => '20G',
          target     => 'true'
          );
  my %diskData2  = (
          mountpoint => '/home',
          size       => '50G',
          type       => '0x83'
          );
  my %partitions = (
          1 => \%diskData1,
          2 => \%diskData2
          );
  my %init = ( partitions   => \%partitions );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Partition configuration without "type" specification '
    . 'given.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionRONoType
#------------------------------------------
sub test_ctor_initIncompleteUnionRONoType {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
        unionRO => '/dev/sdb1',
        unionRW => '/dev/sdb2'
      );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionRWNoRO
#------------------------------------------
sub test_ctor_initIncompleteUnionRWNoRO {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
        unionRW   => '/dev/sdb2',
        unionType => 'clicfs'
      );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionRWNoType
#------------------------------------------
sub test_ctor_initIncompleteUnionRWNoType {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
        unionRO => '/dev/sdb1',
        unionRW => '/dev/sdb2'
      );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionRONoRW
#------------------------------------------
sub test_ctor_initIncompleteUnionRONoRW {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
        unionRO   => '/dev/sdb1',
        unionType => 'clicfs'
      );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionTypeNoRO
#------------------------------------------
sub test_ctor_initIncompleteUnionTypeNoRO {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
        unionRW   => '/dev/sdb2',
        unionType => 'clicfs'
      );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionTypeNoRW
#------------------------------------------
sub test_ctor_initIncompleteUnionTypeNoRW {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
        unionRO   => '/dev/sdb1',
        unionType => 'clicfs'
      );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionOnlyRO
#------------------------------------------
sub test_ctor_initIncompleteUnionOnlyRO {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = ( unionRO => '/dev/sda1' );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionOnlyRW
#------------------------------------------
sub test_ctor_initIncompleteUnionOnlyRW {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = ( unionRW => '/dev/sda1' );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initIncompleteUnionOnlyType
#------------------------------------------
sub test_ctor_initIncompleteUnionOnlyType {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains incomplete union fs settings
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = ( unionType => 'clicfs' );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected =  'Incomplete initialization hash "unionRO", '
    . '"unionRW", and "unionType" must be specified together.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains unsupported data
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %init = (
      blocksize => '4096',
    kernel    => 'myKernel',
    disks     => 'foo'
  );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected = 'KIWIXMLPXEDeployData: Unsupported keyword argument '
    . "'disks' in initialization structure.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_initUnsupportedDataPartitions
#------------------------------------------
sub test_ctor_initUnsupportedDataPartitions {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # that contains unsupported data in the partitions setup
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %diskData = (
      mountpoint => '/dev/sda',
    size       => '30G',
    unit       => 'GB'
  );
  my %disks = ( 1 => \%diskData );
  my @arches = qw / ppc64 x86_64/;
  my %init = (
      blocksize  => '4096',
    partitions => \%disks
  );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Unsupported option in initialization structure '
      . "for partition initialization, found 'unit'";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  # Test this condition last to get potential error messages
  $this -> assert_null($pxeDataObj);
  return;
}

#==========================================
# test_ctor_withInit
#------------------------------------------
sub test_ctor_withInit {
  # ...
  # Test the PXEDeployData constructor with an initialization hash
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my %diskData = (
    mountpoint => '/dev/sda',
    size       => '30G',
    type      => '0x83'
  );
  my %disks = ( 1 => \%diskData );
  my @arches = qw / ppc64 x86_64/;
  my %init = (
      blocksize  => '4096',
    partitions => \%disks
  );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($pxeDataObj);
  return;
}

#==========================================
# test_defaultBlocksize
#------------------------------------------
sub test_defaultBlocksize {
  # ...
  # Test the PXEDeployData object default blocksize setting
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($pxeDataObj);
  my $block = $pxeDataObj -> getBlocksize();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('4096', $block);
  return;
}

#==========================================
# test_defaultServer
#------------------------------------------
sub test_defaultServer {
  # ...
  # Test the PXEDeployData object default server setting
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($pxeDataObj);
  my $srv = $pxeDataObj -> getServer();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('192.168.1.1', $srv);
  return;
}

#==========================================
# test_defaultUnionType
#------------------------------------------
sub test_defaultUnionType {
  # ...
  # Test the PXEDeployData object default union type setting
  # ---
  my $this = shift;
  my $kiwi = $this -> {kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($pxeDataObj);
  my $unionType = $pxeDataObj -> getUnionType();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('clicfs', $unionType);
  return;
}

#==========================================
# test_getBlocksize
#------------------------------------------
sub test_getBlocksize {
  # ...
  # Test the getBlocksize method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $block = $pxeDataObj -> getBlocksize();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('8192', $block);
  return;
}

#==========================================
# test_getDevice
#------------------------------------------
sub test_getDevice {
  # ...
  # Test the getDevice method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $dev = $pxeDataObj -> getDevice();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdb1', $dev);
  return;
}

#==========================================
# test_getInitrd
#------------------------------------------
sub test_getInitrd {
  # ...
  # Test the getInitrd method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $initrd = $pxeDataObj -> getInitrd();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('initrd-3.4.6', $initrd);
  return;
}

#==========================================
# test_getKernel
#------------------------------------------
sub test_getKernel {
  # ...
  # Test the getKernel method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $kern = $pxeDataObj -> getKernel();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('vmlinuz-3.4.6-default', $kern);
  return;
}

#==========================================
# test_getPartitionIDs
#------------------------------------------
sub test_getPartitionIDs {
  # ...
  # Test the getPartitionIDs method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my @pIDs = @{$pxeDataObj -> getPartitionIDs()};
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my @expected = ( 1, 2 );
  $this -> assert_array_equal(\@expected, \@pIDs);
  return;
}

#==========================================
# test_getPartitionMountpoint
#------------------------------------------
sub test_getPartitionMountpoint {
  # ...
  # Test the getPartitionMountpoint method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $mntP = $pxeDataObj -> getPartitionMountpoint(1);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals(q{/}, $mntP);
  return;
}

#==========================================
# test_getPartitionMountpointInvalID
#------------------------------------------
sub test_getPartitionMountpointInvalID {
  # ...
  # Test the getPartitionMountpoint method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $mntP = $pxeDataObj -> getPartitionMountpoint($THIRD_PART);
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($mntP);
  return;
}

#==========================================
# test_getPartitionMountpointInvalIDTooBig
#------------------------------------------
sub test_getPartitionMountpointInvalIDTooBig {
  # ...
  # Test the getPartitionMountpoint method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $mntP = $pxeDataObj -> getPartitionMountpoint($PART_ID_TOO_BIG);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($mntP);
  return;
}

#==========================================
# test_getPartitionMountpointInvalIDTooSmall
#------------------------------------------
sub test_getPartitionMountpointInvalIDTooSmall {
  # ...
  # Test the getPartitionMountpoint method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $mntP = $pxeDataObj -> getPartitionMountpoint(0);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($mntP);
  return;
}

#==========================================
# test_getPartitionMountpointNoID
#------------------------------------------
sub test_getPartitionMountpointNoID {
  # ...
  # Test the getPartitionMountpoint method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $mntP = $pxeDataObj -> getPartitionMountpoint();
  my $msg = $kiwi -> getMessage();
  my $expected = 'getPartitionMountpoint: must be called with id argument.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($mntP);
  return;
}

#==========================================
# test_getPartitionNumber
#------------------------------------------
sub test_getPartitionNumber {
  # ...
  # Test the getPartitionNumber method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $num = $pxeDataObj -> getPartitionNumber(1);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals(1, $num);
  return;
}

#==========================================
# test_getPartitionNumberInvalID
#------------------------------------------
sub test_getPartitionNumberInvalID {
  # ...
  # Test the getPartitionNumber method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $num = $pxeDataObj -> getPartitionNumber($THIRD_PART);
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($num);
  return;
}

#==========================================
# test_getPartitionNumberInvalIDTooBig
#------------------------------------------
sub test_getPartitionNumberInvalIDTooBig {
  # ...
  # Test the getPartitionNumber method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $num = $pxeDataObj -> getPartitionNumber($PART_ID_TOO_BIG);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($num);
  return;
}

#==========================================
# test_getPartitionNumberInvalIDTooSmall
#------------------------------------------
sub test_getPartitionNumberInvalIDTooSmall {
  # ...
  # Test the getPartitionNumber method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $num = $pxeDataObj -> getPartitionNumber(0);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($num);
  return;
}

#==========================================
# test_getPartitionNumberNoID
#------------------------------------------
sub test_getPartitionNumberNoID {
  # ...
  # Test the getPartitionNumber method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $num = $pxeDataObj -> getPartitionNumber();
  my $msg = $kiwi -> getMessage();
  my $expected = 'getPartitionNumber: must be called with id argument.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($num);
  return;
}

#==========================================
# test_getPartitionSize
#------------------------------------------
sub test_getPartitionSize {
  # ...
  # Test the getPartitionSize method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $size = $pxeDataObj -> getPartitionSize(1);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('20G', $size);
  return;
}

#==========================================
# test_getPartitionSizeInvalID
#------------------------------------------
sub test_getPartitionSizeInvalID {
  # ...
  # Test the getPartitionSize method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $size = $pxeDataObj -> getPartitionSize($THIRD_PART);
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($size);
  return;
}

#==========================================
# test_getPartitionSizeInvalIDTooBig
#------------------------------------------
sub test_getPartitionSizeInvalIDTooBig {
  # ...
  # Test the getPartitionSize method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $size = $pxeDataObj -> getPartitionSize($PART_ID_TOO_BIG);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($size);
  return;
}

#==========================================
# test_getPartitionSizeInvalIDTooSmall
#------------------------------------------
sub test_getPartitionSizeInvalIDTooSmall {
  # ...
  # Test the getPartitionSize method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $size = $pxeDataObj -> getPartitionSize(0);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($size);
  return;
}

#==========================================
# test_getPartitionSizeNoID
#------------------------------------------
sub test_getPartitionSizeNoID {
  # ...
  # Test the getPartitionSize method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $size = $pxeDataObj -> getPartitionSize();
  my $msg = $kiwi -> getMessage();
  my $expected = 'getPartitionSize: must be called with id argument.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($size);
  return;
}

#==========================================
# test_getPartitionTarget
#------------------------------------------
sub test_getPartitionTarget {
  # ...
  # Test the getPartitionTarget method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $tgt = $pxeDataObj -> getPartitionTarget(1);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals(1, $tgt);
  return;
}

#==========================================
# test_getPartitionTargetInvalID
#------------------------------------------
sub test_getPartitionTargetInvalID {
  # ...
  # Test the getPartitionTarget method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $tgt = $pxeDataObj -> getPartitionTarget($THIRD_PART);
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($tgt);
  return;
}

#==========================================
# test_getPartitionTargetInvalIDTooBig
#------------------------------------------
sub test_getPartitionTargetInvalIDTooBig {
  # ...
  # Test the getPartitionTarget method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $tgt = $pxeDataObj -> getPartitionTarget($PART_ID_TOO_BIG);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($tgt);
  return;
}

#==========================================
# test_getPartitionTargetInvalIDTooSmall
#------------------------------------------
sub test_getPartitionTargetInvalIDTooSmall {
  # ...
  # Test the getPartitionTarget method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $tgt = $pxeDataObj -> getPartitionTarget(0);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($tgt);
  return;
}

#==========================================
# test_getPartitionTargetNoID
#------------------------------------------
sub test_getPartitionTargetNoID {
  # ...
  # Test the getPartitionTarget method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $tgt = $pxeDataObj -> getPartitionTarget();
  my $msg = $kiwi -> getMessage();
  my $expected = 'getPartitionTarget: must be called with id argument.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($tgt);
  return;
}

#==========================================
# test_getPartitionType
#------------------------------------------
sub test_getPartitionType {
  # ...
  # Test the getPartitionType method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $type = $pxeDataObj -> getPartitionType(2);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x83', $type);
  return;
}

#==========================================
# test_getPartitionTypeInvalID
#------------------------------------------
sub test_getPartitionTypeInvalID {
  # ...
  # Test the getPartitionType method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $type = $pxeDataObj -> getPartitionType($THIRD_PART);
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($type);
  return;
}

#==========================================
# test_getPartitionTypeInvalIDTooBig
#------------------------------------------
sub test_getPartitionTypeInvalIDTooBig {
  # ...
  # Test the getPartitionType method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $type = $pxeDataObj -> getPartitionType($PART_ID_TOO_BIG);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($type);
  return;
}

#==========================================
# test_getPartitionTypeInvalIDTooSmall
#------------------------------------------
sub test_getPartitionTypeInvalIDTooSmall {
  # ...
  # Test the getPartitionType method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $type = $pxeDataObj -> getPartitionType(0);
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($type);
  return;
}

#==========================================
# test_getPartitionTypeNoID
#------------------------------------------
sub test_getPartitionTypeNoID {
  # ...
  # Test the getPartitionType method with an invalid ID
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $type = $pxeDataObj -> getPartitionType();
  my $msg = $kiwi -> getMessage();
  my $expected = 'getPartitionType: must be called with id argument.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($type);
  return;
}

#==========================================
# test_getServer
#------------------------------------------
sub test_getServer {
  # ...
  # Test the getServer method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $srv = $pxeDataObj -> getServer();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('10.10.1.1', $srv);
  return;
}

#==========================================
# test_getTimeout
#------------------------------------------
sub test_getTimeout {
  # ...
  # Test the getTimeout method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $tOut = $pxeDataObj -> getTimeout();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('45', $tOut);
  return;
}

#==========================================
# test_getUnionRO
#------------------------------------------
sub test_getUnionRO {
  # ...
  # Test the getUnionRO method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $unionRO = $pxeDataObj -> getUnionRO();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdb1', $unionRO);
  return;
}

#==========================================
# test_getUnionRW
#------------------------------------------
sub test_getUnionRW {
  # ...
  # Test the getUnionRW method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $unionRW = $pxeDataObj -> getUnionRW();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdb2', $unionRW);
  return;
}

#==========================================
# test_getUnionType
#------------------------------------------
sub test_getUnionType {
  # ...
  # Test the getUnionType method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $unionType = $pxeDataObj -> getUnionType();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('clicfs', $unionType);
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
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $elem = $pxeDataObj -> getXMLElement();
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_not_null($elem);
  my $xmlstr = $elem -> toString();
  my $expected = '<pxedeploy blocksize="8192" server="10.10.1.1">'
    . '<initrd>initrd-3.4.6</initrd>'
    . '<kernel>vmlinuz-3.4.6-default</kernel>'
    . '<partitions device="/dev/sdb1">'
    . '<partition mountpoint="/" number="1" size="20G" target="true" '
    . 'type="0x83"/>'
    . '<partition mountpoint="/home" number="2" size="50G" type="0x83"/>'
    . '</partitions>'
    . '<timeout>45</timeout>'
    . '<union ro="/dev/sdb1" rw="/dev/sdb2" type="clicfs"/>'
    . '</pxedeploy>';
  $this -> assert_str_equals($expected, $xmlstr);
  return;
}

#==========================================
# test_setBlocksize
#------------------------------------------
sub test_setBlocksize {
  # ...
  # Test the setBlocksize method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> setBlocksize('8192');
  $this -> assert_not_null($pxeDataObj);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $blockS = $pxeDataObj -> getBlocksize();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('8192', $blockS);
  return;
}

#==========================================
# test_setBlocksizeReset
#------------------------------------------
sub test_setBlocksizeReset {
  # ...
  # Test the setBlocksize method with no argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> setBlocksize('8192');
  $this -> assert_not_null($pxeDataObj);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $pxeDataObj = $pxeDataObj -> setBlocksize();
  $this -> assert_not_null($pxeDataObj);
  $msg = $kiwi -> getMessage();
  my $expected = 'Resetting blocksize to default, 4096';
  $this -> assert_str_equals($expected, $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('info', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('completed', $state);
  my $blockS = $pxeDataObj -> getBlocksize();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('4096', $blockS);
  return;
}

#==========================================
# test_setDevice
#------------------------------------------
sub test_setDevice {
  # ...
  # Test the setDevice method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> setDevice('/dev/sdc1');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $device = $pxeDataObj -> getDevice();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdc1', $device);
  return;
}

#==========================================
# test_setDeviceNoArg
#------------------------------------------
sub test_setDeviceNoArg {
  # ...
  # Test the setDevice method with no argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setDevice();
  my $msg = $kiwi -> getMessage();
  my $expected = 'setDevice: no target device given, retaining current '
    . 'data.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $device = $pxeDataObj -> getDevice();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/dev/sdb1', $device);
  return;
}

#==========================================
# test_setInitrd
#------------------------------------------
sub test_setInitrd {
  # ...
  # Test the setInitrd method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> setInitrd('initrd-3.4.3-0.0');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $initrd = $pxeDataObj -> getInitrd();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('initrd-3.4.3-0.0', $initrd);
  return;
}

#==========================================
# test_setInitrdNoArg
#------------------------------------------
sub test_setInitrdNoArg {
  # ...
  # Test the setInitrd method with no argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setInitrd();
  my $msg = $kiwi -> getMessage();
  my $expected = 'setInitrd: no initrd specified, retaining current data.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $initrd = $pxeDataObj -> getInitrd();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('initrd-3.4.6', $initrd);
  return;
}

#==========================================
# test_setKernel
#------------------------------------------
sub test_setKernel {
  # ...
  # Test the setKernel method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> setKernel('vmlinuz-3.2.29-33');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $kern = $pxeDataObj -> getKernel();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('vmlinuz-3.2.29-33', $kern);
  return;
}

#==========================================
# test_setKernelNoArg
#------------------------------------------
sub test_setKernelNoArg {
  # ...
  # Test the setKernel method with no argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setKernel();
  my $msg = $kiwi -> getMessage();
  my $expected = 'setKernel: no kernel specified, retaining current data.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $kern = $pxeDataObj -> getKernel();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('vmlinuz-3.4.6-default', $kern);
  return;
}

#==========================================
# test_setPartitionMountpoint
#------------------------------------------
sub test_setPartitionMountpoint {
  # ...
  # Test the setPartitionMountpoint method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  $pxeDataObj = $pxeDataObj -> setPartitionMountpoint('2', '/swap');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $mntP = $pxeDataObj -> getPartitionMountpoint(2);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/swap', $mntP);
  return;
}

#==========================================
# test_setPartitionMountpointInvalidIDTooBig
#------------------------------------------
sub test_setPartitionMountpointInvalidIDTooBig {
  # ...
  # Test the setPartitionMountpoint method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionMountpoint('5', '/swap');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionMountpointInvalidIDTooSmall
#------------------------------------------
sub test_setPartitionMountpointInvalidIDTooSmall {
  # ...
  # Test the setPartitionMountpoint method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionMountpoint(0, '/swap');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionMountpointInvalidIDNoConf
#------------------------------------------
sub test_setPartitionMountpointInvalidIDNoConf {
  # ...
  # Test the setPartitionMountpoint method for an ID that does not exist
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionMountpoint('3', '/swap');
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionMountpointNoMountpArg
#------------------------------------------
sub test_setPartitionMountpointNoMountpArg {
  # ...
  # Test the setPartitionMountpoint method with no argument for the
  # mount point
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionMountpoint(2);
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionMountpoint: must provide 2nd argument '
    . 'specifying mount point.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $mntP = $pxeDataObj -> getPartitionMountpoint(2);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('/home', $mntP);
  return;
}

#==========================================
# test_setPartitionMountpointNoPartdata
#------------------------------------------
sub test_setPartitionMountpointNoPartdata {
  # ...
  # Test the setPartitionMountpoint method when no partition data
  # has been set previously
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> setPartitionMountpoint(2, '/swap');
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionMountpoint: no partition data set, call '
    . 'createPartition first.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionSize
#------------------------------------------
sub test_setPartitionSize {
  # ...
  # Test the setPartitionSize method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  $pxeDataObj = $pxeDataObj -> setPartitionSize('2', '4096');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $size = $pxeDataObj -> getPartitionSize(2);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('4096', $size);
  return;
}

#==========================================
# test_setPartitionSizeInvalidIDTooBig
#------------------------------------------
sub test_setPartitionSizeInvalidIDTooBig {
  # ...
  # Test the setPartitionSize method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionSize('5', '2048');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionSizeInvalidIDTooSmall
#------------------------------------------
sub test_setPartitionSizeInvalidIDTooSmall {
  # ...
  # Test the setPartitionSize method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionSize(0, '2048');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionSizeInvalidIDNoConf
#------------------------------------------
sub test_setPartitionSizeInvalidIDNoConf {
  # ...
  # Test the setPartitionSize method for an ID that does not exist
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionSize('3', '4096');
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionSizeNoSizeArg
#------------------------------------------
sub test_setPartitionSizeNoSizeArg {
  # ...
  # Test the setPartitionSize method with no argument for the size
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionSize(2);
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionSize: must provide 2nd argument '
    . 'specifying partition size.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $size = $pxeDataObj -> getPartitionSize(2);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('50G', $size);
  return;
}

#==========================================
# test_setPartitionSizeNoPartdata
#------------------------------------------
sub test_setPartitionSizeNoPartdata {
  # ...
  # Test the setPartitionSize method when no partition data
  # has been set previously
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> setPartitionSize(2, '/swap');
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionSize: no partition data set, call '
    . 'createPartition first.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionTarget
#------------------------------------------
sub test_setPartitionTarget {
  # ...
  # Test the setPartitionTarget method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  $pxeDataObj = $pxeDataObj -> setPartitionTarget('2', 'true');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $target = $pxeDataObj -> getPartitionTarget(2);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('true', $target);
  return;
}

#==========================================
# test_setPartitionTargetInvalidIDTooBig
#------------------------------------------
sub test_setPartitionTargetInvalidIDTooBig {
  # ...
  # Test the setPartitionTarget method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionTarget('5', 'false');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionTargetInvalidIDTooSmall
#------------------------------------------
sub test_setPartitionTargetInvalidIDTooSmall {
  # ...
  # Test the setPartitionTarget method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionTarget(0, 'false');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionTargetInvalidIDNoConf
#------------------------------------------
sub test_setPartitionTargetInvalidIDNoConf {
  # ...
  # Test the setPartitionTarget method for an ID that does not exist
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionTarget('3', 'true');
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionTargetNoTargetArg
#------------------------------------------
sub test_setPartitionTargetNoTargetArg {
  # ...
  # Test the setPartitionTarget method with no argument for the target
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionTarget(1);
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionTarget: must provide 2nd argument '
    . 'specifying target device.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $target = $pxeDataObj -> getPartitionTarget(1);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_equals(1, $target);
  return;
}

#==========================================
# test_setPartitionTargetNoPartdata
#------------------------------------------
sub test_setPartitionTargetNoPartdata {
  # ...
  # Test the setPartitionTarget method when no partition data
  # has been set previously
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> setPartitionTarget(2, 'false');
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionTarget: no partition data set, call '
    . 'createPartition first.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionType
#------------------------------------------
sub test_setPartitionType {
  # ...
  # Test the setPartitionType method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  $pxeDataObj = $pxeDataObj -> setPartitionType('2', '0x82');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $type = $pxeDataObj -> getPartitionType(2);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x82', $type);
  return;
}

#==========================================
# test_setPartitionTypeInvalidIDTooBig
#------------------------------------------
sub test_setPartitionTypeInvalidIDTooBig {
  # ...
  # Test the setPartitionType method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionType('5', '0x83');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionTypeInvalidIDTooSmall
#------------------------------------------
sub test_setPartitionTypeInvalidIDTooSmall {
  # ...
  # Test the setPartitionType method for an ID that is out of bounds
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionType(0, '0x83');
  my $msg = $kiwi -> getMessage();
  my $expected = 'Invalid partition ID specified, must be between 1 and 4.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionTypeInvalidIDNoConf
#------------------------------------------
sub test_setPartitionTypeInvalidIDNoConf {
  # ...
  # Test the setPartitionType method for an ID that does not exist
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionType('3', '0x83');
  my $msg = $kiwi -> getMessage();
  my $expected = "No partition data configured for partition with ID '3'.";
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('warning', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('skipped', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setPartitionTypeNoTypeArg
#------------------------------------------
sub test_setPartitionTypeNoTypeArg {
  # ...
  # Test the setPartitionType method with no argument for the type
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setPartitionType(1);
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionType: must provide 2nd argument '
    . 'specifying partition type.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $type = $pxeDataObj -> getPartitionType(1);
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('0x83', $type);
  return;
}

#==========================================
# test_setPartitionTypeNoTypedata
#------------------------------------------
sub test_setPartitionTypeNoPartdata {
  # ...
  # Test the setPartitionType method when no partition data
  # has been set previously
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  my $res = $pxeDataObj -> setPartitionType(2, '0x82');
  my $msg = $kiwi -> getMessage();
  my $expected = 'setPartitionType: no partition data set, call '
    . 'createPartition first.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  return;
}

#==========================================
# test_setServer
#------------------------------------------
sub test_setServer {
  # ...
  # Test the setServer method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> setServer('10.10.10.1');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $srv = $pxeDataObj -> getServer();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('10.10.10.1', $srv);
  return;
}

#==========================================
# test_setServerNoArg
#------------------------------------------
sub test_setServerNoArg {
  # ...
  # Test the setServer method with no argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  $pxeDataObj = $pxeDataObj -> setServer();
  my $msg = $kiwi -> getMessage();
  my $expected = 'Resetting server IP to default, 192.168.1.1';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('info', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('completed', $state);
  $this -> assert_not_null($pxeDataObj);
  my $srv = $pxeDataObj -> getServer();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('192.168.1.1', $srv);
  return;
}

#==========================================
# test_setTimeout
#------------------------------------------
sub test_setTimeout {
  # ...
  # Test the setTimeout method
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = KIWIXMLPXEDeployData -> new();
  $pxeDataObj = $pxeDataObj -> setTimeout('50');
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  my $timeout = $pxeDataObj -> getTimeout();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('50', $timeout);
  return;
}

#==========================================
# test_setTimeoutNoArg
#------------------------------------------
sub test_setTimeoutNoArg {
  # ...
  # Test the setTimeout method with no argument
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my $pxeDataObj = $this -> __getPXEDeployObj();
  my $res = $pxeDataObj -> setTimeout();
  my $msg = $kiwi -> getMessage();
  my $expected = 'setTimeout: no timeout value given, retaining '
    . 'current data.';
  $this -> assert_str_equals($expected, $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('error', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('failed', $state);
  $this -> assert_null($res);
  my $timeout = $pxeDataObj -> getTimeout();
  $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  $this -> assert_str_equals('45', $timeout);
  return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getPXEDeployObj
#------------------------------------------
sub __getPXEDeployObj {
  # ...
  # Helper to construct a fully populated PXEDeployData object using
  # initialization.
  # ---
  my $this = shift;
  my $kiwi = $this->{kiwi};
  my %diskData1  = (
          mountpoint => q{/},
          size       => '20G',
          target     => 'true',
          type       => '0x83'
          );
  my %diskData2  = (
          mountpoint => '/home',
          size       => '50G',
          type       => '0x83'
          );
  my %partitions = (
          1 => \%diskData1,
          2 => \%diskData2
          );
  my %init = (
        blocksize    => '8192',
        device       => '/dev/sdb1',
        initrd       => 'initrd-3.4.6',
        kernel       => 'vmlinuz-3.4.6-default',
        partitions   => \%partitions,
        server       => '10.10.1.1',
        timeout      => '45',
        unionRO      => '/dev/sdb1',
        unionRW      => '/dev/sdb2',
        unionType    => 'clicfs'
      );
  my $pxeDataObj = KIWIXMLPXEDeployData -> new(\%init);
  my $msg = $kiwi -> getMessage();
  $this -> assert_str_equals('No messages set', $msg);
  my $msgT = $kiwi -> getMessageType();
  $this -> assert_str_equals('none', $msgT);
  my $state = $kiwi -> getState();
  $this -> assert_str_equals('No state set', $state);
  # Test this condition last to get potential error messages
  $this -> assert_not_null($pxeDataObj);
  return $pxeDataObj;
}

1;
