#!/usr/bin/perl

use lib '/usr/share/kiwi/modules';

use strict;
use KIWIXML;

our $BasePath = "/usr/share/kiwi";
our $Scheme   = $BasePath."/modules/KIWIScheme.rng";
our $ConfigName = "config.xml";

my $kiwi = new KIWILog ("tiny");

#my @list = ("http://download.opensuse.org/distribution/10.3/repo/oss");
my @list = (
	"/image/CDs/full-11.0-i386",
	"http://download.opensuse.org/repositories/Mono:/Preview/openSUSE_11.0"
);
my $data = KIWIXML::getInstSourceSatSolvable ($kiwi,\@list);

if (defined $data) {
	print "$data\n";
}
