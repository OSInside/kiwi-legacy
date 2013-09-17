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

use base qw /Test::Unit::TestCase/;

use FindBin;
use File::Basename qw /dirname/;

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
# createTestTmpDir
#------------------------------------------
sub createTestTmpDir {
	# ...
	# Create a directory to allow tests to write data
	# ---
	my $this = shift;
	# Lets assume /tmp exists
	my $testDir = '/tmp/kiwiDevTests';
	my $res = mkdir $testDir;
	$this -> assert_equals(1, $res);
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
		if ($line =~ /.*kiwi.*/x) {
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
