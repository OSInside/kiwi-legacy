#!/usr/bin/perl
#================
# FILE          : KIWICommandLine.t
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test driver for the KIWILocator module.
#               :
# STATUS        : Development
#----------------
use strict;
use warnings;
use FindBin;
use Test::Unit::HarnessUnit;

# Location of test cases according to program path
use lib "$FindBin::Bin/lib";

# Location of Kiwi modules relative to test
use lib "$FindBin::Bin/../../modules";

use KIWIGlobals;
our $kiwi   = KIWILog -> new();
our $global = KIWIGlobals -> new($kiwi);

my $runner = Test::Unit::HarnessUnit->new();
$runner->start( 'Test::kiwiCommandLine' );
