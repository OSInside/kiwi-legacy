#!/usr/bin/perl -wd

# This is a unittest script for the ProductData module (KIWIProductData.pm)
# written by Jan-Christoph Bornschlegel <jcborn@suse.de>
# The module must be run from the .test subfolder and requires two parameters.
# first, the directory where the configuration file resides
# second, the name of this file

BEGIN {
  unshift @INC, '..';
}

use KIWICollect;
use KIWIProductData;
use KIWILog;
use KIWIXML;

# some globals:
$DB::inhibit_exit = 0;

my $pathtoconfig = shift;
exit 1 if not defined($pathtoconfig);

our $ConfigName = shift; #"config.xml";
exit 2 if not defined($ConfigName);

print "\nUnit test for KIWIProductData.pm module";
print "\n=======================================\n\n";

my $bd = "/tmp/testkiwi";
my $log  =new KIWILog();
$main::Scheme = "/usr/share/kiwi/modules/KIWIScheme.rng";
my $xml = new KIWIXML($log, $pathtoconfig);


my $collect = new KIWICollect($log, $xml, $bd, 1);
if(not defined($collect)) {
  print "Failed to create KIWICollect object\n";
  exit 12;
}

my $testresult = performTest($collect);
print "\n\nResults\n=======\n\n$testresult tests failed\n\n";
exit $testresult;


#===========================================
# test method. Call in class context, give these parameters:
# - KIWICollect object
sub performTest
{
  # run eleven stage test; the number of unsuccessful tests is returned
  my $testresult = 11;
  my $collect = shift;

  # TEST 1: constructor sanity check (expect: undef):
  my $module = new KIWIProductData();
  if(not defined($module)) {
    print "Constructor sane\n";
    $testresult--;
  }
  else {
    print "Construct 1 should have failed but didn't\n";
    return $testresult;
  }

  # TEST 2: constructor sanity part two: expect success
  $module = new KIWIProductData($collect);
  if(defined($module)) {
    print "Creation 2: module is a ".ref($module)."...\n";
    $testresult--;
  }
  else {
    print "Creation with parameter $collect failed. [".ref($collect)."]\n";
    return $testresult;
  }

  print "Setting prodvars content: A->Bla, B->Blubb, C->A--B\n";
  print "expect expanded C: Bla--Blubb\n";
  $module->addSet("Some crappy variables", { 'A' => 'Bla', 'B' => 'Blubb', 'C' => '$A--$B' }, "prodvars");
  $module->_expand();

  # TEST 3..5: retrieve some data:
  my $reply;
  for my $i('A', 'B', 'C') {
    $reply = $module->getVar($i);
    if(defined($reply)) {
      $testresult--;
      print "Fetch value of $i: $reply\n";
    }
    else {
      print "reply is undef\n";
    }
  }

  print "Setting prodinfo content: D->Gobble, E->Wobble, F->D--HUBBLE (which isn't set yet)\n";
  print "expect expanded F: Gobble--[undef-case]\n";
  $module->addSet("Some slutty variables", { '1' => ['D','Gobble'], '2' => ['E', 'Wobble'], '3' => ['F', '$D--$HUBBLE'] }, "prodinfo");
  $module->_expand();

  # TEST 6..8: retrieve some data:
  for my $i('D', 'E', 'F') {
    $reply = $module->getInfo($i);
    if(defined($reply)) {
      $testresult--;
      print "Fetch value of $i: $reply\n";
    }
    else {
      print "reply is undef\n";
    }
  }

  print "Setting prodopts content: GLOB->Gobble, HUBBLE->Wobble, INDY->D--A\n";
  print "expect expanded INDY: Bla--Blubb Gobble--Bla Hallelujah!-bagga\n";
  $module->addSet("Some stupid options", { 'GLOB' => 'Hallelujah!', 'HUBBLE' => 'Telescope', 'INDY' => '$C $F $GLOB-bagga' }, "prodopts");
  $module->_expand();

  # TEST 9..11: retrieve some data:
  for my $i('GLOB', 'HUBBLE', 'INDY') {
    $reply = $module->getOpt($i);
    if(defined($reply)) {
      $testresult--;
      print "Fetch value of $i: $reply\n";
    }
    else {
      print "reply is undef\n";
    }
  }

  return $testresult;
}
