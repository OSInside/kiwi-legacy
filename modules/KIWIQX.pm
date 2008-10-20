#================
# FILE          : KIWIQX.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide the generic qxx 
#               : method used for logging all exec calls
#               : 
#               :
# STATUS        : Development
#----------------
package KIWIQX;
#==========================================
# Modules
#------------------------------------------
require Exporter;
use Carp qw (cluck);
use strict;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (qxx);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIQX object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	return $this;
}

#==========================================
# qxx
#------------------------------------------
sub qxx ($) {
	# ...
	# Activate execution logging. The function also checks
	# if the first name evaluated as program name can be
	# found in the environment using the which command.
	# Please note if a command chain is given only the first
	# item is checked which means subsequent calls in the
	# chain might fail unnoticed
	# ---
	my $cmd = shift;
	my @prg = "";
	$cmd =~ s/^\n//g;
	$cmd =~ s/^ +//g;
	$cmd =~ s/ +$//g;
	@prg = split (/[\s|&]+/,"$cmd");
	#==========================================
	# Try to find program name in PATH
	#------------------------------------------
	my $prog = qx (/usr/bin/which $prg[0]); chomp ($prog);
	my $exit = $?;
	my $code = $exit >> 8;
	if ($exit == -1) {
		$main::kiwi -> loginfo ("EXEC [Failed to call /usr/bin/which: $!]\n");
		$main::BT.=cluck ($main::TT.$main::TL++);
		return $exit;
	}
	if ($code != 0) {
		$main::kiwi -> loginfo ("EXEC [Can't find ".$prg[0]."]\n");
		$main::BT.=cluck ($main::TT.$main::TL++);
		return $exit;
	}
	if (! -x $prog) {
		$main::kiwi -> loginfo ("EXEC [Program $prog not an executable]\n");
		$main::BT.=cluck ($main::TT.$main::TL++);
		return 0xffff;
	}
	#==========================================
	# Call command line
	#------------------------------------------
	if (defined $main::kiwi) {
		$main::kiwi -> loginfo ("EXEC [$cmd]\n");
	}
	return qx ($cmd);
}

1;
