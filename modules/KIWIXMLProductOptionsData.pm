#================
# FILE          : KIWIXMLProductOptionsData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <productoptions> element
#               : and it's children <productinfo>, <productoption>,
#               : <productvar>.
#               :
# STATUS        : Development
#----------------
package KIWIXMLProductOptionsData;
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
	# Create the KIWIXMLProductOptions object
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
	my %keywords = map { ($_ => 1) } qw(
		productinfo
		productoption
		productvar
	);
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> isInitHashRef($init) ) {
		return;
	}
	if (! $this -> areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init) )  {
		return;
	}
	$this->{productinfo}   = $init->{productinfo};
	$this->{productoption} = $init->{productoption};
	$this->{productvar}    = $init->{productvar};

	return $this;
}

#==========================================
# getProductInfoData
#------------------------------------------
sub getProductInfoData {
	# ...
	# Return the data associated with the given product info name
	# ---
	my $this = shift;
	my $name = shift;
	my %args = (
		accessName => $name,
		typeName   => 'productinfo',
		caller     => 'getProductInfoData'
	);
	return $this -> __getData(\%args);
}

#==========================================
# getProductInfoNames
#------------------------------------------
sub getProductInfoNames {
	# ...
	# Return an array ref containing alpha sorted strings indicating
	# the available product info entries.
	# ---
	my $this = shift;
	return $this -> __getNames('productinfo');
}

#==========================================
# getProductOptionData
#------------------------------------------
sub getProductOptionData {
	# ...
	# Return the data associated with the given product option name
	# ---
	my $this = shift;
	my $name = shift;
	my %args = (
		accessName => $name,
		typeName   => 'productoption',
		caller     => 'getProductOptionData'
	);
	return $this -> __getData(\%args);
}

#==========================================
# getProductOptionNames
#------------------------------------------
sub getProductOptionNames {
	# ...
	# Return an array ref containing alpha sorted strings indicating
	# the available product option entries.
	# ---
	my $this = shift;
	return $this -> __getNames('productoption');
}

#==========================================
# getProductVariableData
#------------------------------------------
sub getProductVariableData {
	# ...
	# Return the data associated with the given product variable name
	# ---
	my $this = shift;
	my $name = shift;
	my %args = (
		accessName => $name,
		typeName   => 'productvar',
		caller     => 'getProductVariableData'
	);
	return $this -> __getData(\%args);
}

#==========================================
# getProductVariableNames
#------------------------------------------
sub getProductVariableNames {
	# ...
	# Return an array ref containing alpha sorted strings indicating
	# the available product variable entries.
	# ---
	my $this = shift;
	return $this -> __getNames('productvar');
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new('productoptions');
	my @childNames = qw / productinfo productoption productvar /;
	for my $child (@childNames) {
		my @entryNames = @{$this -> __getNames($child)};
		for my $entry (@entryNames) {
			my $elem = XML::LibXML::Element -> new($child);
			$elem -> setAttribute('name', $entry);
			my %args = (
				accessName => $entry,
				typeName   => $child,
				caller     => 'getXMLElement'
			);
			$elem -> appendText($this -> __getData(\%args));
			$element -> addChild($elem);
		}
	}
	return $element;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getData
#------------------------------------------
sub __getData {
	# ...
	# Return the data associated with the given name for the given type
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	if (! $init) {
		my $msg = 'Internal error __getData called without keyword '
			. 'arguments. Pplease file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($init) ne 'HASH') {
		my $msg = 'Internal error __getData expecting hash ref as argument. '
			. 'Please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $accessName = $init->{accessName};
	my $typeName   = $init->{typeName};
	my $caller     = $init->{caller};
	if (! $caller) {
		my $msg = 'Internal error __getData called without '
			. 'call origin argument. Please file a bug.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $accessName) {
		my $msg = "$caller: no 'name' for data access provided.";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $typeName) {
		my $msg = 'Internal error __getData called without '
			. '"typeName" keyword argument. Please file a bug.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $this->{$typeName}{$accessName}) {
		my $msg = "$caller: $accessName lookup error, data does not "
			. 'exist.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return $this->{$typeName}{$accessName};
}

#==========================================
# __getNames
#------------------------------------------
sub __getNames {
	# ...
	# Return an array ref of sorted string so fthe names for the given
	# entry type.
	# ---
	my $this     = shift;
	my $typeName = shift;
	if (! $typeName) {
		my $kiwi = $this->{kiwi};
		my $msg = 'Internal error __getNames called without type argument. '
			. 'Please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @entryNames;
	if ($this->{$typeName}) {
		my @names = keys %{$this->{$typeName}};
		@entryNames = sort @names;
	}
	return \@entryNames;
}

#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
	# ...
	# Verify initialization consistency and validity requirements
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my @entries = keys %{$init};
	for my $data (@entries) {
		if (ref($init->{$data}) ne 'HASH') {
			my $msg = 'object initialization: expecting hash ref as value '
				. "for '$data' entry in initialization hash.";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

1;
