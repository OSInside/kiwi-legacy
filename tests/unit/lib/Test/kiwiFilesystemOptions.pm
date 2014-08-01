#================
# FILE          : kiwiFilesystemOptions.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIFilesystemOptions
#               : module
# STATUS        : Development
#----------------
package Test::kiwiFilesystemOptions;

use strict;
use warnings;
use Readonly;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIFilesystemOptions;

#==========================================
# constants
#------------------------------------------
Readonly my $HALFMEG      =>    512;
Readonly my $INODERATIO   => 16_384;
Readonly my $INODESIZE    =>    256;
Readonly my $MINNUMINODES => 20_000;
Readonly my $MEGA         =>   1024;
Readonly my $HUNDRED      =>    100;
Readonly my $TEN          =>     10;
Readonly my $THIRTYK      => 30_000;
Readonly my $TWOMEG       =>   2048;

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
    # Test the constructor with a populated init hash
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        blocksize     => $MEGA,
        checkinterval => $TEN,
        inodesize     => $HALFMEG,
        inoderatio    => $THIRTYK,
        journalsize   => $TWOMEG,
        maxmountcnt   => $HUNDRED,
    );
    my $fsopts = KIWIFilesystemOptions -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fsopts);
    return;
}

#==========================================
# test_ctor_invalidArg
#------------------------------------------
sub test_ctor_invalidArg {
    # ...
    # Test the constructor with an invalid argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = KIWIFilesystemOptions -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIFilesystemOptions: expecting a hash ref as '
        . 'argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($fsopts);
    return;
}

#==========================================
# test_ctor_invalidOption
#------------------------------------------
sub test_ctor_invalidOption {
    # ...
    # Test the constructor with an invalid option setting
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        blocksize     => $MEGA,
        checkinterval => $TEN,
        inodesize     => $HALFMEG,
        inoderatio    => $THIRTYK,
        journalsize   => $TWOMEG,
        sectorsize    => $HUNDRED,
    );
    my $fsopts = KIWIFilesystemOptions -> new(\%init);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIFilesystemOptions: unsupported filesystem option '
        . "entry 'sectorsize'.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($fsopts);
    return;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
    # ...
    # Test the constructor with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = KIWIFilesystemOptions -> new();
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIFilesystemOptions: expecting a hash ref as '
        . 'argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($fsopts);
    return;
}

#==========================================
# test_getInodeRatio
#------------------------------------------
sub test_getInodeRatio {
    # ...
    # Test the getInodeRatio method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $ratio = $fsopts -> getInodeRatio();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_equals($THIRTYK, $ratio);
    return;
}

#==========================================
# test_getInodeRatio_default
#------------------------------------------
sub test_getInodeRatio_default {
    # ...
    # Test the getInodeRatio method, expecting the default value
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        blocksize => $MEGA
    );
    my $fsopts = KIWIFilesystemOptions -> new(\%init);
    $this -> assert_not_null($fsopts);
    my $ratio = $fsopts -> getInodeRatio();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_equals($INODERATIO, $ratio);
    return;
}

#==========================================
# test_getInodeSize
#------------------------------------------
sub test_getInodeSize {
    # ...
    # Test the getInodeSize method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $size = $fsopts -> getInodeSize();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_equals($HALFMEG, $size);
    return;
}

#==========================================
# test_getInodeSize_default
#------------------------------------------
sub test_getInodeSize_default {
    # ...
    # Test the getInodeSize method, expecting the default value
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        blocksize => $MEGA
    );
    my $fsopts = KIWIFilesystemOptions -> new(\%init);
    $this -> assert_not_null($fsopts);
    my $size = $fsopts -> getInodeSize();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_equals($INODESIZE, $size);
    return;
}

#==========================================
# test_getMinNumInodes
#------------------------------------------
sub test_getMinNumInodes {
    # ...
    # Test the getMinNumInodes method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $minNodes = $fsopts -> getMinNumInodes();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_equals($MINNUMINODES, $minNodes);
    return;
}

#==========================================
# test_getOptionsStrBtrfs
#------------------------------------------
sub test_getOptionsStrBtrfs {
    # ...
    # Test the getOptionsStrBtrfs method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $extOpts = $fsopts -> getOptionsStrBtrfs();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    my $expected = "-n $HALFMEG";
    $this -> assert_str_equals($expected, $extOpts);
    return;
}

#==========================================
# test_getOptionsStrExt
#------------------------------------------
sub test_getOptionsStrExt {
    # ...
    # Test the getOptionsStrExt method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $extOpts = $fsopts -> getOptionsStrExt();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    my $expected = "-b $MEGA -I $HALFMEG -i $THIRTYK -J size=$TWOMEG "
        . '-F -O resize_inode';
    $this -> assert_str_equals($expected, $extOpts);
    return;
}

#==========================================
# test_getOptionsStrReiser
#------------------------------------------
sub test_getOptionsStrReiser {
    # ...
    # Test the getOptionsStrReiser method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $rOpts = $fsopts -> getOptionsStrReiser();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    my $expected = "-b $MEGA -s $TWOMEG";
    $this -> assert_str_equals($expected, $rOpts);
    return;
}

#==========================================
# test_getOptionsStrXFS
#------------------------------------------
sub test_getOptionsStrXFS {
    # ...
    # Test the getOptionsStrXFS method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $extOpts = $fsopts -> getOptionsStrXFS();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    my $expected = "-b size=$MEGA -i size=$HALFMEG -l size=$TWOMEG";
    $this -> assert_str_equals($expected, $extOpts);
    return;
}

#==========================================
# test_getTuneOptsExt
#------------------------------------------
sub test_getTuneOptsExt {
    # ...
    # Test the getTuneOptsExt method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $fsopts = $this -> __getFSOptObj();
    my $tunOpts = $fsopts -> getTuneOptsExt();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    my $expected = "-c $HUNDRED -i $TEN";
    $this -> assert_str_equals($expected, $tunOpts);
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getFSOptObj
#------------------------------------------
sub __getFSOptObj {
    # ...
    # Create afully populated FilesystemOptions object
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my %init = (
        blocksize     => $MEGA,
        checkinterval => $TEN,
        inodesize     => $HALFMEG,
        inoderatio    => $THIRTYK,
        journalsize   => $TWOMEG,
        maxmountcnt   => $HUNDRED,
    );
    my $fsopts = KIWIFilesystemOptions -> new(\%init);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($fsopts);
    return $fsopts;
}

1;
