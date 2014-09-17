#================
# FILE          : ktTestCase.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2011 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test base class for test cases.
#               :
# STATUS        : Development
#----------------
package Common::ktTestCase;

use warnings;
use strict;
use Test::Unit::Lite;
use base qw /Test::Unit::TestCase/;

use FindBin;
use File::Basename qw /dirname/;
use File::Slurp;

use KIWIGlobals;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct the test case
    #---
    my $this = shift -> SUPER::new(@_);
    my $kiwi = Common::ktLog -> instance();
    $this -> {kiwi} = $kiwi;
    # Create the Globals instance and clear any messages it may produce
    KIWIGlobals -> instance();
    $kiwi -> getState();
    return $this;
}


#==========================================
# assert_array_equal
#------------------------------------------
sub assert_array_equal {
    # ...
    # Make sure two arrays are equal (element order is not considered)
    # ---
    my $this           = shift;
    my $base_array_ref = shift;
    my $cmp_array_ref  = shift;
    my @base_array = @{$base_array_ref};
    my @cmp_array  = @{$cmp_array_ref};
    my $text;
    if (scalar @base_array != scalar @cmp_array) {
        $text = 'Did not get the expected list of names: got: ';
        $text.= "\(@base_array\) and \(@cmp_array\)";
        $this -> assert(0, $text);
    }
    my %baseEntryMap = map { ("$_" => 1) } @base_array;
    for my $item (@cmp_array) {
        if (! $baseEntryMap{"$item"}) {
            $text = 'Did not get the expected list of names. ';
            $text.= 'Mismatch content.';
            $this -> assert(0, $text);
        }
    }
    return;
}

#==========================================
# assert_dir_exists
#------------------------------------------
sub assert_dir_exists {
    # ...
    # Test for file existence
    # ---
    my $this = shift;
    my $dir   = shift;
    if (! -d $dir) {
        $this -> assert(0, "Directory $dir not found.");
    }
    return;
}

#==========================================
# assert_file_exists
#------------------------------------------
sub assert_file_exists {
    # ...
    # Test for file existence
    # ---
    my $this = shift;
    my $fl   = shift;
    if (! -f $fl) {
        $this -> assert(0, "File $fl not found.");
    }
    return;
}

#==========================================
# compareFiles
#------------------------------------------
sub compareFiles {
    # ...
    # Compare two files for equality
    #    return 1 if content is equal
    # We do not implement assert_file_equal to give the test a chance to
    # recover and preserve the non matching file for manual debugging.
    # ---
    my $this    = shift;
    my $refFile = shift;
    my $cmpFile = shift;
    if (! -f $refFile) {
        $this -> assert(0, "Reference file '$refFile' not found.");
    }
    if (! -f $cmpFile) {
        my $msg = "Could not find given file '$cmpFile' for comparison.";
        $this -> assert(0, $msg);
    }
    my $reference = read_file($refFile);
    my $target = read_file($cmpFile);
    if ($reference eq $target) {
        return 1;
    }
    return;
}

#==========================================
# createResultSaveDir
#------------------------------------------
sub createResultSaveDir {
    # ...
    # Create a directoy that is not cleaned up that may be used to
    # preserve results for debugging purposes.
    # ---
    my $this = shift;
    # Lets assume /tmp exists
    my $saveDir = '/tmp/kiwiResultsSaved';
    if (! -d $saveDir) {
        my $res = mkdir $saveDir;
        $this -> assert_equals(1, $res);
    }
    return $saveDir;
}

#==========================================
# createTestTmpDir
#------------------------------------------
sub createTestTmpDir {
    # ...
    # Create a directory to allow tests to write data
    # ---
    my $this = shift;
    # Lets assume /tmp exists
    my $testDir = '/tmp/kiwiDevTests';
    if (! -d $testDir) {
        my $res = mkdir $testDir;
        $this -> assert_equals(1, $res);
    }
    return $testDir;
}

#==========================================
# getBaseDir
#------------------------------------------
sub getBaseDir {
    # ...
    # Return the directory of the KIWI source tree
    # ---
    my $dir = dirname ($FindBin::Bin );
    return $dir;
}

#==========================================
# getDataDir
#------------------------------------------
sub getDataDir {
    # ...
    # Return location of test data
    # ---
    my $dir = dirname ( $FindBin::Bin ) . '/unit/data';
    return $dir;
}

#==========================================
# getRefResultsDir
#------------------------------------------
sub getRefResultsDir {
    # ...
    # Return the location of the directory containing the reference results
    # files
    # ---
    my $dir = dirname ( $FindBin::Bin ) . '/unit/refresults';
    return $dir;
}

#==========================================
# removeTestTmpDir
#------------------------------------------
sub removeTestTmpDir {
    # ...
    # Remove the test temporary directory
    # ---
    my $this = shift;
    # Before removing anything make sure there are no dangling mounts that
    # might have a negative imapct on the system we run on
    my @mountInfo;
    if (! -f '/proc/mounts') {
            my $chld_in;
            my $chld_out;
            my $pid = open2($chld_out, $chld_in, 'mount');
            waitpid $pid, 0;
            while (<$chld_out>) {
            push @mountInfo, $_;
            }
    } else {
            my $mounts;
            if (! open $mounts, '<', '/proc/mounts' ) {
            return 0;
            }
            @mountInfo = <$mounts>;
            close $mounts;
    }
    for my $line (@mountInfo) {
        if ($line =~ /.*kiwiDevTests.*/x) {
            next if $line =~ /tmpfs/;
            my ($source, $mntPnt, $rest) = split /\s/x, $line;
            my $res = system "umount $mntPnt";
            if ($res) {
                my $msg = "Unable to clean up mount point $mntPnt from "
                    . 'previous test run. Not deleting directory '
                    . '/tmp/kiwiDevTests. Please umount and clean up '
                    . 'manually. ';
                $this -> assert(0, $msg);
            }
        }
    }
    system 'rm -rf /tmp/kiwiDevTests';
    return 1;
}

1;
