#================
# FILE          : KIWIXMLDataBase.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Base class for the XML Data objects
#               :
# STATUS        : Development
#----------------
package KIWIXMLDataBase;
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
	# Create KIWIXMLDataBase object
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
	#my $init = shift;
	#==========================================
	# Argument checking and common object data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	my %archesSup = map { ($_ => 1) } qw(
		armv7l ia64 ix86 ppc ppc64 s390 s390x x86_64
	);
	$this->{supportedArch} = \%archesSup;

	return $this;
}

#==========================================
# __areKeywordArgsValid
#------------------------------------------
sub __areKeywordArgsValid {
	# ...
	# Verify the keyword arguments
	# ---
	my $this = shift;
	my $init = shift;
	if ($init) {
		for my $keyword (keys %{$init}) {
			if (! $this->{supportedKeywords}{$keyword} ) {
				my $objName = ref $this;
				my $kiwi = $this->{kiwi};
				my $msg = "$objName: Unsupported keyword argument '$keyword' "
					. 'in initialization structure.';
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
	}

	return $this;
}

#==========================================
# __areKeywordBooleanValuesValid
#------------------------------------------
sub __areKeywordBooleanValuesValid {
	# ...
	# Verify that the values given for booleans are recognized. Takes a ref
	# to a hashref
	# ---
	my $this = shift;
	my $init = shift;
	if ($init) {
		for my $keyword (keys %{$this->{boolKeywords}}) {
			if (! $this -> __isValidBoolValue($init->{$keyword}) ) {
				my $objName = ref $this;
				my $kiwi = $this->{kiwi};
				my $msg = "$objName: Unrecognized value for boolean "
					. "'$keyword' in initialization structure.";
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
	}

	return $this;
}

#==========================================
# __isInitHashRef
#------------------------------------------
sub __isInitHashRef {
	# ...
	# Verify that the given argument is a hashref
	# ---
	my $this = shift;
	my $init = shift;
	if ($init && ref($init) ne 'HASH') {
		my $kiwi = $this->{kiwi};
		my $msg = 'Expecting a hash ref as second argument if provided';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return $this;
}

#==========================================
# __isValidBoolValue
#------------------------------------------
sub __isValidBoolValue {
	# ...
	# Verify that the given boolean is a recognized value
	# true, false, or undef (undef maps to false)
	# ---
	my $this = shift;
	my $bVal = shift;
	if (! $bVal || $bVal eq 'false' || $bVal eq 'true') {
		return 1;
	}
	return;
}

#==========================================
# __setBooleanValue
#------------------------------------------
sub __setBooleanValue {
	# ...
	# Generic code to set the given boolean attribute on the object
	# ---
	my $this     = shift;
	my $settings = shift;
	my $attr   = $settings->{attr};
	my $bVal   = $settings->{value};
	my $caller = $settings->{caller};
	my $kiwi   = $this->{kiwi};
	if (! $attr ) {
		my $msg = 'Internal error __setBooleanValue called without '
			. 'attribute to set.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $caller ) {
		my $msg = 'Internal error __setBoolean called without '
			. 'call origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $this -> __isValidBoolValue($bVal) ) {
		my $name = ref $this;
		my $msg = "$name:$caller: unrecognized argument expecting "
			. '"true" or "false".';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $bVal) {
		$this->{$attr} = 'false';
	} else {
		$this->{$attr} = $bVal;
	}
		
	return $this;
}

1;
