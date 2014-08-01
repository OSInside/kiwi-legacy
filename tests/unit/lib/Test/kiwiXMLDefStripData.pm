#================
# FILE          : kiwiXMLDefStripData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIStripData module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLDefStripData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLDefStripData;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct new test case
    # ---
    my $this = shift -> SUPER::new(@_);
    $this -> {dataDir} = $this -> getDataDir() . '/kiwiXMLDefStrip';
    return $this;
}

#==========================================
# test_ctor_invalidFile
#------------------------------------------
sub test_ctor_invalidFile {
    # ...
    # Test the DefStripData constructor with an invalid XML file
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $invalFl = $this -> {dataDir} . '/invalid.xml';
    my $stripDataObj = KIWIXMLDefStripData -> new($invalFl);
    my $msg = $kiwi -> getMessage();
    # Need to fiddle with the output message to remove the parser info
    my @prts = split /:/msx, $msg;
    my $msgStub = $prts[0];
    my $expectedMsg = 'Could not parse default strip section definition file';
    $this -> assert_str_equals($expectedMsg, $msgStub);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($stripDataObj);
    return;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
    # ...
    # Test the DefStripData constructor
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $stripDataObj = KIWIXMLDefStripData -> new();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($stripDataObj);
    return;
}

#==========================================
# test_ctor_noFile
#------------------------------------------
sub test_ctor_noFile {
    # ...
    # Test the DefStripData constructor with an arg that does not point
    # to a file.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $stripDataObj = KIWIXMLDefStripData -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expectedMsg = 'Could not find default strip section '
        . "definition file: 'foo'";
    $this -> assert_str_equals($expectedMsg, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($stripDataObj);
    return;
}

#==========================================
# test_getFilesToDelete
#------------------------------------------
sub test_getFilesToDelete {
    # ...
    # Verify that the getFilesToDelete method returns the expected data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $stripDataObj = $this -> __getDefStripObj();
    my @flDel = @{$stripDataObj -> getFilesToDelete()};
    my %expectedNames = (
        '/usr/share/info' => 1,
        '/usr/share/splashy' => 1
    );
    my $numEntries = scalar @flDel;
    $this -> assert_equals(2, $numEntries);
    for my $item (@flDel) {
        if ((ref $item) ne 'KIWIXMLStripData') {
            $this -> assert_null('Invalid object in delete file array');
        }
        my $name = $item -> getName();
        if (! $expectedNames{$name}) {
            $this -> assert_null('Invalid delete name found');
        }
    }
    return;
}

#==========================================
# test_getLibsToKeep
#------------------------------------------
sub test_getLibsToKeep {
    # ...
    # Verify that the getLibsToKeep method returns the expected data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $stripDataObj = $this -> __getDefStripObj();
    my @flKeep = @{$stripDataObj -> getLibsToKeep()};
    my %expectedNames = (
        'libdmraid-events-isw' => 1,
        'libfontenc' => 1
    );
    my $numEntries = scalar @flKeep;
    $this -> assert_equals(2, $numEntries);
    for my $item (@flKeep) {
        if ((ref $item) ne 'KIWIXMLStripData') {
            $this -> assert_null('Invalid object in libs file array');
        }
        my $name = $item -> getName();
        if (! $expectedNames{$name}) {
            $this -> assert_null('Invalid libs name found');
        }
    }
    return;
}

#==========================================
# test_getToolsToKeep
#------------------------------------------
sub test_getToolsToKeep {
    # ...
    # Verify that the getToolsToKeep method returns the expected data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $stripDataObj = $this -> __getDefStripObj();
    my @flTools = @{$stripDataObj -> getToolsToKeep()};
    my %expectedNames = (
        'date' => 1,
        'zfs' => 1
    );
    my $numEntries = scalar @flTools;
    $this -> assert_equals(2, $numEntries);
    for my $item (@flTools) {
        if ((ref $item) ne 'KIWIXMLStripData') {
            $this -> assert_null('Invalid object in tools file array');
        }
        my $name = $item -> getName();
        if (! $expectedNames{$name}) {
            $this -> assert_null('Invalid tools name found');
        }
    }
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getDefStripObj
#------------------------------------------
sub __getDefStripObj {
    # ...
    # Get a DefStripData object using the valid.xml data file
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $dataFl = $this -> {dataDir} . '/valid.xml';
    my $stripDataObj = KIWIXMLDefStripData -> new($dataFl);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($stripDataObj);
    return $stripDataObj;
}

1;
