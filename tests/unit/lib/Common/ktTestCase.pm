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
# getBaseDir
#------------------------------------------
sub getBaseDir {
	# ...
	# Return the directory of the KIWI source tree
	# ---
	my $dir = dirname ($FindBin::Bin );
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

1;
