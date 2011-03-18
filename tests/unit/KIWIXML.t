#================
# FILE          : KIWIXML.t
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test driver for the KIWIXMLValidator module.
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

# TODO eliminate the following variables
# Set some variables that are encoded in kiwi.pl and are used by KIWIXML via
# direct access through $main::*
# Once KIWIXML ctor args change this can be eliminated
our $KSplit    = "$FindBin::Bin/../../modules/KIWISplit.txt";
our $Revision  = "$FindBin::Bin/data/kiwiRuntimeChecker/revision";
our $Schema    = "$FindBin::Bin/../../modules/KIWISchema.rng";
our $SchemaCVT = "$FindBin::Bin/../../xsl/master.xsl";
# END variable hack

my $runner = Test::Unit::HarnessUnit->new();
$runner->start( 'Test::xml' );
