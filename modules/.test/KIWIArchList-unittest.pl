#!/usr/bin/perl -wd

# This is a unittest script for the ArchList (KIWIArchList.pm)
# written by Jan-Christoph Bornschlegel <jcborn@suse.de>
# The module must be run from the .test subfolder and requires two parameters.
# first, the directory where the configuration file resides
# second, the name of this file

BEGIN {
  unshift @INC, '..';
}

use KIWICollect;
use KIWIArchList;
use KIWILog;
use KIWIXML;

# some globals:
$DB::inhibit_exit = 0;

our $pathtoconfig = shift;
usage(1, "Path to config file is missing") if not defined($pathtoconfig);

our $ConfigName = shift; #"config.xml";
usage(2, "Name of config file is missing")  if not defined($ConfigName);

print "\nUnit test for KIWIArchList.pm module";
print "\n====================================\n\n";

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
exit $testresult;

# end of main program


#===========================
# functions
#---------------------------

sub performTest
{
  my $coll = shift;
  my $res = 5;

  # TEST 1: constructor sanity check (expect: undef):
  my $module = new KIWIArchList();
  if(not defined($module)) {
    print "Creation 1: constructor without parameters fails as expected\n";
    $res--;
  }
  else {
    print "1st constructor call should fail but didn't.\n";
    return $res;
  }

  # TEST 2: constructor sanity part two: expect success
  $module = new KIWIArchList($coll);
  if(defined($module)) {
    print "Creation 2: module is a ".ref($module)."...\n";
    $res--;
  }

  # TEST 3: insert data from config.xml file:
  my %archlist = $coll->{m_xml}->getInstSourceArchList();
  my $addret = $module->addArchs( \%archlist );
  if(defined($addret)) {
    $res--;
  }
  else {
    print "adding the archs failed!\n";
    return $res;
  }

  # TEST 4: retrieve fallback lists
  print "\nTest of fallback architecture list for (x86_64, i686, s390x, ia64, ppc64):\n";
  for my $arch("x86_64", "i686", "i586", "i486", "ppc", "s390", "s390x", "ia64", "ppc64") {
    print "\nArchitecture is $arch: fallbacks are: ";
    my @fallbacks = $module->fallbacks($arch);
    if(not(@fallbacks)) {
      print "No fallbacks defined for architecture $arch\n";
    }
    else {
      foreach my $fa(@fallbacks) {
	print "$fa ";
      }
      print "\n";
    }
  }
  $res--;

  # TEST 5: retrieve filtered fallback lists:
  print "\nTest of filtered fallback architecture lists -- omitting i486 and i386:\n";
  for my $arch("x86_64", "i686", "i586", "i486", "ppc", "s390", "s390x", "ia64", "ppc64") {
    print "\nArchitecture is $arch: fallbacks are: ";
    my @fallbacks = $module->fallbacks($arch, "i486", "i386");
    if(not(@fallbacks)) {
      print "No fallbacks defined for architecture $arch\n";
    }
    else {
      foreach my $fa(@fallbacks) {
	print "$fa ";
      }
      print "\n";
    }
  }
  print "please verify those results against $pathtoconfig/$ConfigName!\n";
  $res--;
  
  return $res;
}



sub usage
{
  my $retcode = shift;
  my $msg = shift;
  print "$msg\n";
  print "Usage: ./KIWIArchList-unittest.pl </path/to/config/> <configfilename>\n\n";
  exit $retcode;
}
