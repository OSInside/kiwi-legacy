#================
# FILE          : collector.pl
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 SUSE
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Collect code statistics for the KIWI Perl code
#               : this code assumes the development tree layout
#               :
# STATUS        : Development
#----------------
use strict;
use warnings;
use DateTime;
use File::Basename;
use FindBin;
use IPC::Open2;

# Setup time parameters
my $curTime = time;
my $twoWeeks = 60 * 60 * 24 * 14;
my $nextScan = $curTime + $twoWeeks;

# Our statistics tracking file
my $statsFileName = "$FindBin::Bin/data/codeStats.txt";

# Get info about the next scan time from the file
open(my $STATS, '<', $statsFileName) ||
  die "Could not open '$statsFileName'\n";

my $scanDateInfo = readline $STATS;
close $STATS;
chomp $scanDateInfo;
my $nextScanTime = int ((split /:/, $scanDateInfo)[-1]);

if ($nextScan < $nextScanTime) {
    # Nothing to do
    exit 0;
}

# Generate the lists of modules to be processed
my @modules = glob "$FindBin::Bin/../../../modules/*.pm";
push @modules, "$FindBin::Bin/../../../kiwi.pl";
push @modules, glob "$FindBin::Bin/../../unit/*.t";
push @modules, glob "$FindBin::Bin/../../unit/lib/Test/*.pm";
push @modules, glob "$FindBin::Bin/../../unit/lib/Common/*.pm";

# Read existing stats since I cannot figure out how to just overwrite the
# first line :(
open($STATS, '<', $statsFileName) ||
  die "Could not open '$statsFileName'\n";
my (@lines) = <$STATS>;
close $STATS;

open($STATS, '>', $statsFileName) || die "Could not open '$statsFileName'\n";
print $STATS "#NEXT_SCAN:$nextScan\n";
shift @lines;
print $STATS @lines;
print $STATS "DATE:$curTime\n";
# Collect statistics
my $numFiles  = 0;
my $numTFiles = 0;
my $totalCCN  = 0.0;
my $totalTCCN = 0.0;
my $totalLOC  = 0;
my $totalTLOC = 0;
my $chld_in;
my $chld_out;
for my $fl (@modules) {
    my $isTest;
    if ($fl =~ /.*\/modules\/.*/ or $fl =~ /.*\/kiwi.pl/) {
        $numFiles += 1;
    } else {
        $numTFiles += 1;
        $isTest = 1;
    }
    my $fname = basename($fl);
    print $STATS "\tFILE:$fname\n";
    my $res = open2($chld_out, $chld_in, 'perlcritic', '--statistics-only',
                    '-severity', '1', "$fl");
    while (<$chld_out>) {
        # Extract line of code info an process
        if ($_ =~ /\s*(\d*)\s*lines of Perl code.$/) {
            my $fileLOC = int $1;
            if ($isTest) {
                $totalTLOC += $fileLOC;
            } else {
                $totalLOC += $fileLOC;
            }
            print $STATS "\t\tLOC:$fileLOC\n";
        }
        # Extract CCN and process
        if ($_ =~ /^Average McCabe score.*/) {
            chomp;
            chop; # trailing .
            my $fileCCN = (split / /, $_)[-1];
            if ($isTest) {
                $totalTCCN += $fileCCN;
            } else {
                $totalCCN += $fileCCN;
            }
            print $STATS "\t\tCCN:$fileCCN\n";
        }
        # Extract violations information levels 5 to 1
        if ($_ =~ /^\s*(\d*) severity (\d) violations./) {
            my $violations = $1;
            my $level = $2;
            my $levelID = "VIOL" . $level;
            print $STATS "\t\t$levelID:$violations\n";
        }
    }
}
# Write out summary data
print $STATS "TOTAL_LOC:$totalLOC\n";
print $STATS "NUMBER_FILES:$numFiles\n";
my $avg = $totalCCN / $numFiles;
print $STATS "AVG_CCN:$avg\n";
print $STATS "TOTAL_TEST_LOC:$totalTLOC\n";
print $STATS "NUMBER_TEST_FILES:$numTFiles\n";
$avg = $totalTCCN / $numTFiles;
print $STATS "AVG_TEST_CCN:$avg\n";
# Update the scan time
#seek $STATS, 0, 0;
#print $STATS "#NEXT_SCAN:$nextScan\n";
close $STATS;

