#================
# FILE          : KIWIXMLEC2ConfigData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <ec2config> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLEC2ConfigData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLEC2ConfigData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi = shift;
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	if ($init && ref($init) ne 'HASH') {
		my $msg = 'Expecting a hash ref as second argument if provided';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($init) {
		# Check for unsupported entries
		my %initStruct = %{$init};
		my %supported = map { ($_ => 1) } qw(
			ec2accountnr ec2certfile ec2privatekeyfile ec2region
		);
		for my $key (keys %initStruct) {
			if (! $supported{$key} ) {
				my $msg = 'Unsupported option in initialization structure '
					. "found '$key'";
				$kiwi -> info($msg);
				$kiwi -> skipped();
			}
		}
		$this->{acctno}         = $init->{ec2accountnr};
		$this->{certfile}       = $init->{ec2certfile};
		$this->{privatekeyfile} = $init->{ec2privatekeyfile};

		if ($init->{ec2region} && ref($init->{ec2region}) ne 'ARRAY') {
			my $msg = 'Expecting an array ref as entry of "ec2region" in the '
				. 'initialization hash.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}

		$this->{regions}        = $init->{ec2region};
	}
	$this->{kiwi} = $kiwi;
	return $this;
}

#==========================================
# getAccountNumber
#------------------------------------------
sub getAccountNumber {
	# ...
	# Return the account number
	# ---
	my $this = shift;
	return $this->{acctno};
}

#==========================================
# getCertFilePath
#------------------------------------------
sub getCertFilePath {
	# ...
	# Return the path to the cert file
	# ---
	my $this = shift;
	return $this->{certfile};
}

#==========================================
# getPrivateKeyFilePath
#------------------------------------------
sub getPrivateKeyFilePath {
	# ...
	# Return the path to the private key file
	# ---
	my $this = shift;
	return $this->{privatekeyfile};
}

#==========================================
# getRegions
#------------------------------------------
sub getRegions {
	# ...
	# Return an array ref with the region information
	# ---
	my $this = shift;
	return $this->{regions};
}

#==========================================
# setAccountNumber
#------------------------------------------
sub setAccountNumber {
	# ...
	# Set the account number stored in the object
	# ---
	my $this  = shift;
	my $actno = shift;
	if (! $actno) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setAccountNumber: no account number provided, retaining '
			. 'current data.';
		$kiwi -> info($msg);
		$kiwi -> done ();
		return $this;
	}
	$this->{acctno} = $actno;
	return $this;
}

#==========================================
# setCertFilePath
#------------------------------------------
sub setCertFilePath {
	# ...
	# Set the cert file path, including cert file name
	# ---
	my $this = shift;
	my $path = shift;
	if (! $path) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setCertFilePath: no certfile path given, retaining '
			. 'current data.';
		$kiwi -> info($msg);
		$kiwi -> done ();
		return $this;
	}
	$this->{certfile} = $path;
	return $this;
}

#==========================================
# setPrivateKeyFilePath
#------------------------------------------
sub setPrivateKeyFilePath {
	# ...
	# Set the private key file path, including the filename
	# ---
	my $this = shift;
	my $path = shift;
	if (! $path) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setPrivateKeyFilePath: no private key file path given, '
			. 'retaining current data.';
		$kiwi -> info($msg);
		$kiwi -> done ();
		return $this;
	}
	$this->{privatekeyfile} = $path;
	return $this;
}

#==========================================
# setRegions
#------------------------------------------
sub setRegions {
	# ...
	# Set the regions
	# ---
	my $this    = shift;
	my $regions = shift;
	if (! $regions) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setRegions: no regions given, retaining current data.';
		$kiwi -> info($msg);
		$kiwi -> done ();
		return $this;
	}
	if (ref($regions) ne 'ARRAY') {
		my $kiwi = $this->{kiwi};
		my $msg = 'setRegions: expecting array ref as argument.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{regions} = $regions;
	return $this;
}

1;
