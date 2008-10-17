#!/usr/bin/perl

use lib './blib/arch/auto/KIWI/dbusdevice';

use strict;
use dbusdevice;

my $d = new dbusdevice::HalConnection;

if (! $d -> open()) {
	print $d->state()."\n";
	exit 1;
}

if ($d -> lock ("/dev/sda")) {
	print $d->state()."\n";
}

if ($d -> unlock ("/dev/sda")) {
	print $d->state()."\n";
}


$d -> close();
