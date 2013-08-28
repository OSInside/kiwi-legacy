#================
# FILE          : KIWIXMLDataBase.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use XML::LibXML;
require Exporter;

use KIWILog;

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
	# Argument checking and common object data
	#------------------------------------------
	$this->{kiwi} = KIWILog -> instance();
	my $kiwi = $this->{kiwi};
	my %archesSup = map { ($_ => 1) } qw(
		aarch64
		armv5el
		armv5tel
		armv6l
		armv7l
		armv7hl
		ia64
		i386
		i486
		i586
		i686
		ix86
		ppc
		ppc64
		s390
		s390x
		x86_64
		skipit
	);
	$this->{supportedArch} = \%archesSup;
	return $this;
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Must be implemented in each child
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $objName = ref $this;
	my $msg = "$objName: no implementation of getXMLElement.";
	$kiwi -> error($msg);
	$kiwi -> failed();
	return;
}

#==========================================
# Protected methods by naming convention
#------------------------------------------
#==========================================
# p_addElement
#------------------------------------------
sub p_addElement {
	# ...
	# Add an element with the given name and value to the given parent
	# ---
	my $this = shift;
	my $init = shift;
	if (! $init) {
		return $this;
	}
	my $parent   = $init->{parent};
	my $chldName = $init->{childName};
	my $value    = $init->{text};
	if ($value) {
		my $child = XML::LibXML::Element -> new($chldName);
		$child -> appendText($value);
		$parent -> addChild($child);
	}
	return $parent;
}

#==========================================
# p_areKeywordArgsValid
#------------------------------------------
sub p_areKeywordArgsValid {
	# ...
	# Verify the keyword arguments
	# ---
	my $this = shift;
	my $init = shift;
	if (! $init) {
		return $this;
	}
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
	return 1;
}

#==========================================
# p_areKeywordBooleanValuesValid
#------------------------------------------
sub p_areKeywordBooleanValuesValid {
	# ...
	# Verify that the values given for booleans are recognized. Takes a ref
	# to a hashref
	# ---
	my $this = shift;
	my $init = shift;
	if (! $init) {
		return $this;
	}
	for my $keyword (keys %{$this->{boolKeywords}}) {
		if (! $this -> p_isValidBoolValue($init->{$keyword}) ) {
			my $objName = ref $this;
			my $kiwi = $this->{kiwi};
			my $msg = "$objName: Unrecognized value for boolean "
				. "'$keyword' in initialization structure.";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# p_containsNoWhiteSpace
#------------------------------------------
sub p_containsNoWhiteSpace {
	# ...
	# Verify that the given data contains no whitspace
	# ---
	my $this   = shift;
	my $name   = shift;
	my $caller = shift;
	my $kiwi = $this->{kiwi};
	if (! $caller ) {
		my $msg = 'Internal error containsNoWhiteSpace called without '
			. 'call origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $name ) {
		my $msg = 'Internal error containsNoWhiteSpace called without '
			. 'argument to check.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if ($name =~ /\s/msx) {
		my $msg = "$caller: given argument contains white space "
			. 'not supported, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# p_hasInitArg
#------------------------------------------
sub p_hasInitArg {
	# ...
	# Verify that the argument is defined, error if not.
	# Used for classes that must be initialized for proper construction.
	# ---
	my $this = shift;
	my $init = shift;
	if (! $init ) {
		my $objName = ref $this;
			my $kiwi = $this->{kiwi};
			my $msg = "$objName: must be constructed with "
			. 'a keyword hash as argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# p_initializeBoolMembers
#------------------------------------------
sub p_initializeBoolMembers {
	# ...
	# Initialize any members that hold boolean values
	# ---
	my $this = shift;
	my $init = shift;
	for my $boolAttr (keys %{$this->{boolKeywords}}) {
		my %settings = (
						attr   => $boolAttr,
						value  => $init->{$boolAttr},
						caller => 'ctor'
					);
		$this -> p_setBooleanValue(\%settings);
	}
	return 1;
}

#==========================================
# p_isInitHashRef
#------------------------------------------
sub p_isInitHashRef {
	# ...
	# Verify that the given argument is a hashref
	# ---
	my $this = shift;
	my $init = shift;
	if ($init && ref($init) ne 'HASH') {
		my $kiwi = $this->{kiwi};
		my $msg = 'Expecting a hash ref as first argument if provided';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# p_isValidBoolValue
#------------------------------------------
sub p_isValidBoolValue {
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
# p_setBooleanValue
#------------------------------------------
sub p_setBooleanValue {
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
		my $msg = 'Internal error setBooleanValue called without '
			. 'attribute to set.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $caller ) {
		my $msg = 'Internal error setBoolean called without '
			. 'call origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $this -> p_isValidBoolValue($bVal) ) {
		my $name = ref $this;
		my $msg = "$name:$caller: unrecognized argument expecting "
			. '"true" or "false".';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ((! $bVal) && $this->{$attr}) {
		$this->{$attr} = 'false';
	} else {
		$this->{$attr} = $bVal;
	}
	return $this;
}

1;
