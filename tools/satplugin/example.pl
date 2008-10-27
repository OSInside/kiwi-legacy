#!/usr/bin/perl

use lib './blib/arch/auto/KIWI/SaT';

use strict;
use KIWI::SaT;

# Open Solvable file
open(F, "cat /var/cache/kiwi/satsolver/12e185e932ba137e4535d33ae2b97db4 |") || die;

# Create Pool and Repository 
my $pool = new KIWI::SaT::_Pool;
my $repo = $pool -> createRepo('repo');

# Add Solvable to Repository
$repo -> addSolvable (*F);
close(F) || die;

# Create Solver
my $solver = new KIWI::SaT::Solver ($pool);

# Create dependencies to provides table
$pool -> initializeLookupTable();

# Create Queue
my $queue = new KIWI::SaT::Queue;

my @pats = qw(apparmor apparmor_opt base devel_C_C++ devel_qt4);
#my @pats = qw(mono_everything);

#my @pats = qw(apparmor apparmor_opt base devel_C_C++ devel_qt4 devel_tcl enhanced_base file_server fonts games games_opt gateway_server gnome_basis_opt imaging imaging_opt kde kde3_games kde3_internet kde3_laptop kde3_multimedia kde3_office kde3_office_opt kde3_utilities kde3_utilities_opt kde3_yast kde4 kde4_basis kde4_games kde4_imaging kde4_imaging_opt kde4_internet kde4_laptop kde4_multimedia kde4_office kde4_office_opt kde4_utilities kde4_utilities_opt kde4_yast lamp_server misc_server multimedia non_oss non_oss_java office print_server remote_desktop sw_management sw_management_kde3 sw_management_kde4 voip x11 x11_opt xgl yast2_basis yast2_install_wf);

foreach my $p (@pats) {
	my $id = $pool -> selectSolvable ($repo,"pattern:$p");
	if (! $id) {
		print ("failed to push job: $p\n");
		next;
	}
	$queue -> queuePush ( $KIWI::SaT::SOLVER_INSTALL_SOLVABLE );
	$queue -> queuePush ( $id );
}

# Solve the jobs
$solver -> solve ($queue);

if ($solver->getProblemsCount()) {
	$a = $solver->getSolutions ($queue);
	open FD,$a;
	while (<FD>) {
		print $_;
	}
	close FD;
	unlink $a;
}


# Print packages to install
$a = $solver -> getInstallList($pool);
foreach my $c (@{$a}) {
	print "$c\n";
}

