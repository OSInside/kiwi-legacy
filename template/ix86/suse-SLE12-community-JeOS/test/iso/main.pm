#!/usr/bin/perl -w
use strict;
use bmwqemu;
use autotest;

# wait for qemu to start
while ( !getcurrentscreenshot() ) {
    sleep 1;
}

$username = "root";
$password = "linux";

autotest::loadtestdir(
    "$scriptdir/distri/$ENV{DISTRI}/test.d"
);

1;
