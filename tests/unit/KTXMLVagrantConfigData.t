#!/usr/bin/perl
#================
# FILE          : KTXMLVagrantConfigData.t
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.com
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test driver for the KIWIXMLVagrantConfigData module.
#               :
# STATUS        : Development
#----------------
package KTXMLVagrantConfigData;
use strict;
use warnings;
use FindBin;
use Test::Unit::Lite;

# Location of test cases according to program path
use lib "$FindBin::Bin/lib";

# Location of Kiwi modules relative to test
use lib "$FindBin::Bin/../../modules";

my $runner = Test::Unit::HarnessUnit->new();
$runner->start( 'Test::kiwiXMLVagrantConfigData');

1;
