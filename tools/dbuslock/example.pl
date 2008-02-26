#!/usr/bin/perl

use lib './blib/arch/auto/dbusdevice';

use strict;
use dbusdevice;

my $d = new dbusdevice::HalConnection;

$d -> open();

$a = $d -> state();

print "$a\n";

$d -> close();
