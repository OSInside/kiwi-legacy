#!/usr/bin/perl

use lib './blib/arch/auto/SaT';

use strict;
use SaT;

# Open Solvable file
open(F, "gzip -cd tmp/primary-x86_64.gz |") || die;

# Create Pool and Repository 
my $pool = new SaT::_Pool;
my $repo = $pool -> createRepo('repo');

# Add Solvable to Repository
$repo -> addSolvable (*F);
close(F) || die;

# Create Solver
my $solver = new SaT::Solver ($pool);

# Create dependencies to provides table
$pool -> createWhatProvides();

# Create Queue
my $job = new SaT::Queue;

# Push jobs on Queue
$job -> queuePush ( $SaT::SOLVER_INSTALL_SOLVABLE );
if (! $pool -> selectSolvable ($repo,$job,"pattern:default")) {
	die "failed to push job";
}

# Solve the jobs
$solver -> solve ($job);
$job -> queue_free();

# Print packages to install
$a = $solver -> getInstallList($pool);
foreach my $c (@{$a}) {
	print "$c\n";
}

