#!/usr/bin/perl -w
use strict;
use base "basetest";
use diagnostics;
use bmwqemu;
use autotest;

sub check() {
	my $results=\%::results;
	autotest::runtestdir(
		"$scriptdir/distri/$ENV{DISTRI}/test.d",
		\&::checkfunc
	);
	my $overall=1;
	for my $test (keys(%$results)) {
		$overall=0 unless ::is_ok($results->{$test});
	}
	return $overall;
}

1;
