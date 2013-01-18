#================
# FILE          : KIWIXMLEC2ConfigData.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use XML::LibXML;
require Exporter;

use base qw /KIWIXMLDataBase/;
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
	#
	# Internal data structure
	#
	# this = {
	#    acctno         = ''
	#    certfile       = ''
	#    privatekeyfile = ''
	#    regions        = ''
	# }
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	my %keywords = map { ($_ => 1) } qw(
		ec2accountnr ec2certfile ec2privatekeyfile ec2region
	);
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> __isInitHashRef($init) ) {
		return;
	}
	if (! $this -> __areKeywordArgsValid($init) ) {
		return;
	}
	my $kiwi = $this->{kiwi};
	if ($init) {
		$this->{acctno}    = $init->{ec2accountnr};
		$this->{certfile}  = $init->{ec2certfile};
		$this->{privatekeyfile} = $init->{ec2privatekeyfile};
		if ($init->{ec2region} && ref($init->{ec2region}) ne 'ARRAY') {
			my $msg = 'Expecting an array ref as entry of "ec2region" in the '
				. 'initialization hash.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		$this->{regions} = $init->{ec2region};
	}
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
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new('ec2config');
	my %initAcct = (
		parent    => $element,
		childName => 'ec2accountnr',
		text      => $this -> getAccountNumber()
	);
	$element = $this -> __addElement(\%initAcct);
	my %initCert = (
		parent    => $element,
		childName => 'ec2certfile',
		text      => $this -> getCertFilePath()
	);
	$element = $this -> __addElement(\%initCert);
	my %initPk = (
		parent    => $element,
		childName => 'ec2privatekeyfile',
		text      => $this -> getPrivateKeyFilePath()
	);
	$element = $this -> __addElement(\%initPk);
	my $regions = $this -> getRegions();
	if ($regions) {
		for my $reg (@{$regions}) {
			my %initReg = (
				parent    => $element,
				childName => 'region',
				text      => $reg
			);
			$element = $this -> __addElement(\%initReg);
		}
	}
	return $element;
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
