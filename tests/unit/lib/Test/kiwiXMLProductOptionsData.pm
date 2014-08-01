#================
# FILE          : kiwiXMLProductOptionsData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLProductOptions
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLProductOptionsData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLProductOptionsData;

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
    # Test the ProductOptionsData constructor with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = KIWIXMLProductOptionsData -> new();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($prodOptObj);
    return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
    # ...
    # Test the ProductOptionsData constructor with an improper argument type
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = KIWIXMLProductOptionsData -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'Expecting a hash ref as first argument if provided';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($prodOptObj);
    return;
}

#==========================================
# test_ctor_invalidDataTInfo
#------------------------------------------
sub test_ctor_invalidDataTInfo {
    # ...
    # Test the ProductOptionsData constructor with an initialization hash
    # that contains invalid data for productinfo.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
my %opts = (
        INI_DIR      => 'localpath/version',
        'PLUGIN DIR' => 'localpath/plugins'
    );
    my %vars = (
        DISTNAME        => 'openSUSE',
        FLAVOR          => 'dvd',
        'PRODUCT THEME' => 'amaryllis'
    );
    my %init = (
        productinfo   => 'info',
        productoption => \%opts,
        productvar    => \%vars
    );
    my $prodOptObj = KIWIXMLProductOptionsData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: expecting hash ref as value '
        . "for 'productinfo' entry in initialization hash.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($prodOptObj);
    return;
}

#==========================================
# test_ctor_invalidDataTOpt
#------------------------------------------
sub test_ctor_invalidDataTOpt {
    # ...
    # Test the ProductOptionsData constructor with an initialization hash
    # that contains invalid data for productoption.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my %info = (
        CONTENTSTYLE => '11',
        DATADIR      => 'suse',
        LABEL        => 'openSUSE'
    );
    my %vars = (
        DISTNAME        => 'openSUSE',
        FLAVOR          => 'dvd',
        'PRODUCT THEME' => 'amaryllis'
    );
    my %init = (
        productinfo   => \%info,
        productoption => 'opts',
        productvar    => \%vars
    );
    my $prodOptObj = KIWIXMLProductOptionsData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: expecting hash ref as value '
        . "for 'productoption' entry in initialization hash.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($prodOptObj);
    return;
}

#==========================================
# test_ctor_invalidDataTVar
#------------------------------------------
sub test_ctor_invalidDataTVar {
    # ...
    # Test the ProductOptionsData constructor with an initialization hash
    # that contains invalid data for productinfo.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my %info = (
        CONTENTSTYLE => '11',
        DATADIR      => 'suse',
        LABEL        => 'openSUSE'
    );
    my %opts = (
        INI_DIR      => 'localpath/version',
        'PLUGIN DIR' => 'localpath/plugins'
    );
    my %init = (
        productinfo   => \%info,
        productoption => \%opts,
        productvar    => 'var'
    );
    my $prodOptObj = KIWIXMLProductOptionsData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'object initialization: expecting hash ref as value '
        . "for 'productvar' entry in initialization hash.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($prodOptObj);
    return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
    # ...
    # Test the ProductOptionsData constructor with an initialization hash
    # that contains unsupported data
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = ( bootparam => 'kiwidebug=1' );
    my $prodOptObj = KIWIXMLProductOptionsData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIXMLProductOptionsData: Unsupported keyword argument '
        . "'bootparam' in initialization structure.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($prodOptObj);
    return;
}

#==========================================
# test_getProductInfoData
#------------------------------------------
sub test_getProductInfoData {
    # ...
    # Test the getProductInfoData method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $dataDir = $prodOptObj -> getProductInfoData('DATADIR');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('suse', $dataDir);
    return;
}

#==========================================
# test_getProductInfoDataNoArg
#------------------------------------------
sub test_getProductInfoDataNoArg {
    # ...
    # Test the getProductInfoData method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $res = $prodOptObj -> getProductInfoData();
    my $msg = $kiwi -> getMessage();
    my $expected = "getProductInfoData: no 'name' for data access provided.";
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
# test_getProductInfoDataNoEntry
#------------------------------------------
sub test_getProductInfoDataNoEntry {
    # ...
    # Test the getProductInfoData method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $relLoc = $prodOptObj -> getProductInfoData('RELNOTESURL');
    my $msg = $kiwi -> getMessage();
    my $expected = 'getProductInfoData: RELNOTESURL lookup error, data '
        . 'does not exist.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($relLoc);
    return;
}

#==========================================
# test_getProductInfoNames
#------------------------------------------
sub test_getProductInfoNames {
    # ...
    # Test the getProductInfoNames method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $accessNames = $prodOptObj -> getProductInfoNames();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my @expected = qw / CONTENTSTYLE DATADIR LABEL /;
    $this -> assert_array_equal(\@expected, $accessNames);
    return;
}

#==========================================
# test_getProductOptionData
#------------------------------------------
sub test_getProductOptionData {
    # ...
    # Test the getProductOptionData method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $plugDir = $prodOptObj -> getProductOptionData('PLUGIN DIR');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('localpath/plugins', $plugDir);
    return;
}

#==========================================
# test_getProductOptionDataNoArg
#------------------------------------------
sub test_getProductOptionDataNoArg {
    # ...
    # Test the getProductOptionData method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $res = $prodOptObj -> getProductOptionData();
    my $msg = $kiwi -> getMessage();
    my $expected = "getProductOptionData: no 'name' for data access provided.";
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
# test_getProductOptionDataNoEntry
#------------------------------------------
sub test_getProductOptionDataNoEntry {
    # ...
    # Test the getProductOptionData method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $repoLoc = $prodOptObj -> getProductOptionData('REPO LOCATION');
    my $msg = $kiwi -> getMessage();
    my $expected = 'getProductOptionData: REPO LOCATION lookup error, data '
        . 'does not exist.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($repoLoc);
    return;
}

#==========================================
# test_getProductOptionNames
#------------------------------------------
sub test_getProductOptionNames {
    # ...
    # Test the getProductOptionNames method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $accessNames = $prodOptObj -> getProductOptionNames();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my @expected = ( 'INI_DIR', 'PLUGIN DIR' );
    $this -> assert_array_equal(\@expected, $accessNames);
    return;
}

#==========================================
# test_getProductVariableData
#------------------------------------------
sub test_getProductVariableData {
    # ...
    # Test the getProductVariableData method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $plugDir = $prodOptObj -> getProductVariableData('DISTNAME');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_str_equals('openSUSE', $plugDir);
    return;
}

#==========================================
# test_getProductVariableDataNoArg
#------------------------------------------
sub test_getProductVariableDataNoArg {
    # ...
    # Test the getProductVariableData method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $res = $prodOptObj -> getProductVariableData();
    my $msg = $kiwi -> getMessage();
    my $expected = "getProductVariableData: no 'name' for data "
        . 'access provided.';
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
# test_getProductVariableDataNoEntry
#------------------------------------------
sub test_getProductVariableDataNoEntry {
    # ...
    # Test the getProductVariableData method with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $repoLoc = $prodOptObj -> getProductVariableData('SHA1OPT');
    my $msg = $kiwi -> getMessage();
    my $expected = 'getProductVariableData: SHA1OPT lookup error, data '
        . 'does not exist.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($repoLoc);
    return;
}

#==========================================
# test_getProductVariableNames
#------------------------------------------
sub test_getProductVariableNames {
    # ...
    # Test the getProductVariableNames method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $prodOptObj = $this -> __getProdOptObj();
    my $accessNames = $prodOptObj -> getProductVariableNames();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    my @expected = ( 'DISTNAME', 'FLAVOR', 'PRODUCT THEME' );
    $this -> assert_array_equal(\@expected, $accessNames);
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
    my $prodOptObj = $this -> __getProdOptObj();
    my $elem = $prodOptObj -> getXMLElement();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    $this -> assert_not_null($elem);
    my $xmlstr = $elem -> toString();
    my $expected = '<productoptions>'
        . '<productinfo name="CONTENTSTYLE">11</productinfo>'
        . '<productinfo name="DATADIR">suse</productinfo>'
        . '<productinfo name="LABEL">openSUSE</productinfo>'
        . '<productoption name="INI_DIR">localpath/version</productoption>'
        . '<productoption name="PLUGIN DIR">localpath/plugins</productoption>'
        . '<productvar name="DISTNAME">openSUSE</productvar>'
        . '<productvar name="FLAVOR">dvd</productvar>'
        . '<productvar name="PRODUCT THEME">amaryllis</productvar>'
        . '</productoptions>';
    $this -> assert_str_equals($expected, $xmlstr);
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getProdOptObj
#------------------------------------------
sub __getProdOptObj {
    # ...
    # Helper to construct a fully populated ProductOptions object using
    # initialization.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my %info = (
        CONTENTSTYLE => '11',
        DATADIR      => 'suse',
        LABEL        => 'openSUSE'
    );
    my %opts = (
        INI_DIR      => 'localpath/version',
        'PLUGIN DIR' => 'localpath/plugins'
    );
    my %vars = (
        DISTNAME        => 'openSUSE',
        FLAVOR          => 'dvd',
        'PRODUCT THEME' => 'amaryllis'
    );
    my %init = (
        productinfo   => \%info,
        productoption => \%opts,
        productvar    => \%vars
    );
    my $prodOptObj = KIWIXMLProductOptionsData -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($prodOptObj);
    return $prodOptObj;
}

1;
