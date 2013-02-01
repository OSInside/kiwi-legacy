#================
# FILE          : KIWIQX.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
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
use warnings;

#==========================================
# Exports
#------------------------------------------
our @ISA       = qw (Exporter);
our @EXPORT_OK = qw (qxx qxxLogOff qxxLogOn);
our $QXXLOG = 1;

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
# qxxLogOff
#------------------------------------------
sub qxxLogOff {
	$QXXLOG = 0;
	return;
}

#==========================================
# qxxLogOff
#------------------------------------------
sub qxxLogOn {
	$QXXLOG = 1;
	return;
}

#==========================================
# qxx
#------------------------------------------
sub qxx {
	# ...
	# Activate execution logging. The function also checks
	# if the first name evaluated as program name can be
	# found in the environment using the which command.
	# Please note if a command chain is given only the first
	# item is checked which means subsequent calls in the
	# chain might fail unnoticed
	# ---
	my $cmd  = shift;
	my @prg  = "";
	my $prog = "";
	my $kiwi = KIWILog -> instance();
	#==========================================
	# Extract command name from command string
	#------------------------------------------
	$cmd =~ s/^\n//g;
	$cmd =~ s/^\s+//g;
	$cmd =~ s/\s+$//g;
	@prg = split (/[\s|&]+/,"$cmd");
	$prog= $prg[0];
	$prog=~ s/^\(//g;
	#==========================================
	# write command line to logfile
	#------------------------------------------
	if ($QXXLOG) {
		$kiwi -> loginfo ("EXEC [$cmd]\n");
	}
	#==========================================
	# Try to find program name in PATH
	#------------------------------------------
	$prog = qx (bash -c "type $prog" 2>&1);
	my $exit = $?;
	my $code = $exit >> 8;
	if (($code != 0) || ($exit == -1)) {
		$kiwi -> loginfo ("EXEC [Failed: $prog]\n");
		if ($kiwi -> trace()) {
			$main::BT[$main::TL] = eval { Carp::longmess (
				$main::TT.$main::TL++)
			};
		}
		$? = 0xffff; ## no critic
		return "$prog: command not found";
	}
	#==========================================
	# Call command line
	#------------------------------------------
	return qx ($cmd);
}

1;
