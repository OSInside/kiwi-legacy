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
# DESCRIPTION   : This module is used to provide the generic KIWIQX::qxx
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
use KIWITrace;

#==========================================
# Exports
#------------------------------------------
our @ISA = qw (Exporter);

#==========================================
# KIWIQX::qxx
#------------------------------------------
sub KIWIQX::qxx {
	# ...
	# Central method to call commands. The command string
	# will be logged with the prefix 'EXEC'
	# ---
	my $cmd   = shift;
	my $kiwi  = KIWILog -> instance();
	my $trace = KIWITrace -> instance();
	#==========================================
	# Extract waste from command string
	#------------------------------------------
	$cmd =~ s/^\n//g;
	$cmd =~ s/^\s+//g;
	$cmd =~ s/\s+$//g;
	#==========================================
	# write command line to logfile
	#------------------------------------------
	$kiwi -> loginfo ("EXEC [$cmd]\n");
	#==========================================
	# Call command line
	#------------------------------------------
	my $output = qx($cmd);
	if ($? == -1) {
		$kiwi -> loginfo ("EXEC [Execution Failed: $!]\n");
		if ($kiwi -> trace()) {
			$trace->{BT}[$trace->{TL}] = eval {
				Carp::longmess ($trace->{TT}.$trace->{TL}++)
			};
		}
	}
	return $output;
}

1;
