#================
# FILE          : KIWIXMLDriverData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <driver> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLDriverData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

use base qw /KIWIXMLFileData/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLDriverData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	if (! $this) {
		return;
	} elsif ($this eq 'missingName') {
		my $kiwi = shift;
		my $msg = 'Expecting a string as 2nd argument for DriverData object.';
		$kiwi -> error ($msg);
		return;
	}
	return $this;
}

1;
