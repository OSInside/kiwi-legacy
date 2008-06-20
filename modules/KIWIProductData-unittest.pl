#!/usr/bin/perl -wd


use KIWICollect;
use KIWIProductData;
use KIWILog;
use KIWIXML;

$DB::inhibit_exit = 0;

print "\nUnit test for KIWIProductData.pm module";
print "\n=======================================\n\n";

my $bd = "/tmp/testkiwi";
my $log  =new KIWILog();
$main::Scheme = "/usr/share/kiwi/modules/KIWIScheme.rng";
my $xml = new KIWIXML($log, "/suse/jcborn/Work/KIWI/JeOS-svn/instsource/");


my $collect = new KIWICollect($log, $xml, $bd, 1);
if(not defined($collect)) {
  print "Failed to create KIWICollect object\n";
  exit 1;
}

my $testresult = performTest($collect);


#===========================================
# test method. Call in class context, give these parameters:
# - KIWICollect object
sub performTest
{
  my $testresult = 0;
  my $collect = shift;

  # constructor sanity check (expect: undef):
  my $module = new KIWIProductData();
  if(not defined($module)) {
    print "Constructor sane\n";
  }
  else {
    print "Construct 1 should have failed but didn't\n";
    return undef;
  }

  $module = new KIWIProductData($collect);
  if(defined($module)) {
    print "Creation 2: module is a ".ref($module)."...\n";
  }
  else {
    print "Creation with parameter $collect failed. [".ref($collect)."]\n";
    return undef;
  }

  print "Setting prodvars content: A->Bla, B->Blubb, C->A--B\n";
  $module->addSet("Some crappy variables", { 'A' => 'Bla', 'B' => 'Blubb', 'C' => '$A--$B' }, "prodvars");
  $module->_expand();
  print $module->getVar("A")."\n";
  print $module->getVar("B")."\n";
  print "expect expanded C: Bla--Blubb\n";
  print $module->getVar("C")."\n";

  print "Setting prodinfo content: D->Gobble, E->Wobble, F->D--A\n";
  $module->addSet("Some slutty variables", { '1' => ['D','Gobble'], '2' => ['E', 'Wobble'], '3' => ['F', '$D--$HUBBLE'] }, "prodinfo");
  $module->_expand();
  print $module->getInfo("D")."\n";
  print $module->getInfo("E")."\n";
  print "expect expanded F: Gobble--Bla\n";
  print $module->getInfo("F")."\n";

  print "Setting prodopts content: GLOB->Gobble, HUBBLE->Wobble, INDY->D--A\n";
  $module->addSet("Some stupid options", { 'GLOB' => 'Hallelujah!', 'HUBBLE' => 'Telescope', 'INDY' => '$C $F $GLOB-bagga' }, "prodopts");
  $module->_expand();
  print $module->getOpt("GLOB")."\n";
  print $module->getOpt("HUBBLE")."\n";
  print "expect expanded INDY: Bla--Blubb Gobble--Bla Hallelujah!-bagga\n";
  print $module->getOpt("INDY")."\n";

}
