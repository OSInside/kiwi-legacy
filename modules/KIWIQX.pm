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
	# Activate execution logging
	# ---
	my $cmd = shift;
	$cmd =~ s/^ +//g;
	$cmd =~ s/ +$//g;
	if (defined $main::kiwi) {
		$main::kiwi -> loginfo ("EXEC [$cmd]\n");
	}
	my $eval = "qx ($cmd)";
	return eval ($eval);
}

1;
