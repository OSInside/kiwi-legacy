#!/usr/bin/perl
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
use FileHandle;
use FindBin;
use IPC::Open2;

# Setup time parameters
my $curTime = time;
my $twoWeeks = 60 * 60 * 24 * 14;
my $nextScan = $curTime + $twoWeeks;

# Our statistics tracking file
my $statsFileName = "$FindBin::Bin/data/codeStats.txt";

# Get info about the next scan time from the file
my $STATS = FileHandle -> new();
if (! $STATS -> open ($statsFileName)) {
	die "Could not open '$statsFileName'\n";
}
my $scanDateInfo = readline $STATS;
$STATS -> close();
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

if (! $STATS -> open ("+<$statsFileName")) {
	die "Could not open '$statsFileName'\n";
}
# Mark time when the statistics should be collected again
print $STATS "#NEXT_SCAN:$nextScan\n";
# Write new data at the end
seek $STATS, 0, 2;
print $STATS "DATE:$curTime\n";
# Collect statistics
my $critExcept  = 0;
my $critExceptT = 0;
my $numFiles    = 0;
my $numTFiles   = 0;
my $totalCCN    = 0.0;
my $totalTCCN   = 0.0;
my $totalLOC    = 0;
my $totalTLOC   = 0;
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
	my $pid = open2($chld_out, $chld_in, 'perlcritic', '--statistics-only',
                    '-severity', '1', "$fl");
	waitpid( $pid, 0 );
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
	# Count the lines of code marked as critic exception
	my $MOD = FileHandle -> new();
	if (! $MOD -> open ($fl)) {
		die "Could not open $fl for stats collection";
	}
	my @lines = <$MOD>;
	$MOD -> close();
	my $exceptCnt = 0;
	my $exceptBlk;
	for my $ln (@lines) {
		if ($ln =~ /^\s*## no critic\s*$/) {
			# Beginning of a critic exception block
			$exceptBlk = 1;
			next;
		}
		if ($ln =~ /^\s*## use critic\s*$/) {
			# End of a critic exception block
			$exceptBlk = undef;
			next;
		}
		if ($exceptBlk or $ln =~ /\s*.*;\s*## no critic\s*$/) {
			$exceptCnt += 1;
		}
	}
	if ($isTest) {
		$critExceptT += $exceptCnt;
	} else {
		$critExcept += $exceptCnt;
	}
	print $STATS "\t\tCEC:$exceptCnt\n";
}
# Write out summary data
print $STATS "TOTAL_LOC:$totalLOC\n";
print $STATS "NUMBER_FILES:$numFiles\n";
my $avg = $totalCCN / $numFiles;
print $STATS "AVG_CCN:$avg\n";
print $STATS "CRITIC_EXCEPT_LOC:$critExcept\n";
print $STATS "TOTAL_TEST_LOC:$totalTLOC\n";
print $STATS "NUMBER_TEST_FILES:$numTFiles\n";
$avg = $totalTCCN / $numTFiles;
print $STATS "AVG_TEST_CCN:$avg\n";
print $STATS "CRITIC_EXCEPT_TEST_LOC:$critExceptT\n";
$STATS -> close();

