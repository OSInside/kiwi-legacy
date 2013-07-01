#!/usr/bin/perl
#================
# FILE          : KTCommandLine.t
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test driver for the KIWILocator module.
#               :
# STATUS        : Development
#----------------
package KTCommandLine;
use strict;
use warnings;
use FindBin;
use Test::Unit::Lite;

# Location of test cases according to program path
use lib "$FindBin::Bin/lib";

# Location of Kiwi modules relative to test
use lib "$FindBin::Bin/../../modules";

my $runner = Test::Unit::HarnessUnit->new();
$runner->start( 'Test::kiwiCommandLine' );

1;
