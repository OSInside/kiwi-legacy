#================
# FILE          : ktTestCase.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test base class for test cases.
#               :
# STATUS        : Development
#----------------
package Common::ktTestCase;

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

	for my $item (@base_array) {
		if ( ! grep /^$item$/x, @cmp_array ) {
			my $msg = 'Did not get the expected list of names. '
			.'Mismatch content.';
			$self->assert(0, $msg);
		}
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
	system 'rm -rf /tmp/kiwiDevTests';
	return 1;
}

1;
