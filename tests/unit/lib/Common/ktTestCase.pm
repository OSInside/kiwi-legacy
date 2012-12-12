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

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct the test case
	#---
	my $this = shift -> SUPER::new(@_);
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

	if (scalar @base_array != scalar @cmp_array) {
		$this -> assert(0, 'Did not get the expected list of names.');
	}

	my %baseEntryMap = map { ("$_" => 1) } @base_array;
	for my $item (@cmp_array) {
		if (! $baseEntryMap{"$item"}) {
			my $msg = 'Did not get the expected list of names. '
			    .'Mismatch content.';
			$this -> assert(0, $msg);
		}
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
	my $mounts;
	if (! open $mounts, '<', '/proc/mounts' ) {
		return 0;
	}
	my @mountInfo = <$mounts>;
	close $mounts;
	for my $line (@mountInfo) {
		if ($line =~ /.*kiwi.*/x) {
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
