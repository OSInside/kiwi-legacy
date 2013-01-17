#================
# FILE          : KIWIXMLDescriptionData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <description> element
#               : as well as the element's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLDescriptionData;
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
	# Create the KIWIXMLDescriptionData object
	#
	# Internal data structure
	#
	# this = {
	#    author        = ''
	#    contact       = ('',...)
	#    specification = ''
	#    type          = ''
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
	if (! $this -> __hasInitArg($init) ) {
		return;
	}
	my %keywords = map { ($_ => 1) } qw(
		author contact specification type
	);
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> __isInitHashRef($init) ) {
		return;
	}
	if (! $this -> __areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitConsistent($init) )  {
		return;
	}
	$this->{author}        = $init->{author};
	$this->{contact}       = $init->{contact};
	$this->{specification} = $init->{specification};
	$this->{type}          = $init->{type};

	return $this;
}

#==========================================
# getAuthor
#------------------------------------------
sub getAuthor {
	# ...
	# Return the value of the author member
	# ---
	my $this = shift;
	return $this->{author};
}

#==========================================
# getContactInfo
#------------------------------------------
sub getContactInfo {
	# ...
	# Return a ref to an array containing contact information
	# ---
	my $this = shift;
	return $this->{contact};
}

#==========================================
# getSpecificationDescript
#------------------------------------------
sub getSpecificationDescript {
	# ...
	# Return the value of the specification member
	# ---
	my $this = shift;
	return $this->{specification};
}

#==========================================
# getType
#------------------------------------------
sub getType {
	# ...
	# Return the value of the type member
	# ---
	my $this = shift;
	return $this->{type};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new('description');
	$element -> setAttribute('type', $this->getType());
	my %initAuth = (
		parent    => $element,
		childName => 'author',
		text      => $this -> getAuthor()
	);
	$element = $this -> __addElement(\%initAuth);
	my @contacts = @{$this -> getContactInfo()};
	for my $cont (@contacts) {
		my %initCont = (
			parent    => $element,
			childName => 'contact',
		    text      => $cont
	    );
	    $element = $this -> __addElement(\%initCont);
	}
	my %initSpec = (
		parent    => $element,
		childName => 'specification',
		text      => $this -> getSpecificationDescript()
	);
	$element = $this -> __addElement(\%initSpec);
	return $element;
}

#==========================================
# setAuthor
#------------------------------------------
sub setAuthor {
	# ...
	# Set the value of the author member
	# ---
	my $this   = shift;
	my $author = shift;
	if (! defined $author) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setAuthor: no author given, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{author} = $author;
	return $this;
}

#==========================================
# setContactInfo
#------------------------------------------
sub setContactInfo {
	# ...
	# Set the value of the contact member
	# ---
	my $this   = shift;
	my $contact = shift;
	if (! defined $contact) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setContactInfo: no contact information given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($contact) ne 'ARRAY') {
		my @contacts = ($contact);
		$contact = \@contacts;
	}
	$this->{contact} = $contact;
	return $this;
}

#==========================================
# setSpecificationDescript
#------------------------------------------
sub setSpecificationDescript {
	# ...
	# Set the value of the specification member
	# ---
	my $this   = shift;
	my $spec = shift;
	if (! defined $spec) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setSpecificationDescript: no discription given, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{specification} = $spec;
	return $this;
}

#==========================================
# setType
#------------------------------------------
sub setType {
	# ...
	# Set the value of the type member
	# ---
	my $this = shift;
	my $type = shift;
	if (! $this -> __isValidType($type, 'setType')) {
		return;
	}
	$this->{type} = $type;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
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
	if (! $init->{author} ) {
		my $msg = 'KIWIXMLDescriptionData: no "author" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{contact} ) {
		my $msg = 'KIWIXMLDescriptionData: no "contact" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($init->{contact}) ne 'ARRAY') {
		my $msg = 'KIWIXMLDescriptionData: expecting array ref as value '
			. 'for "contact" argument.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{specification} ) {
		my $msg = 'KIWIXMLDescriptionData: no "specification" given in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{type} ) {
		my $msg = 'KIWIXMLDescriptionData: no "type" specified in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isValidType($init->{type}, 'object initialization')) {
		return;
	}
	return 1;
}

#==========================================
# __isValidType
#------------------------------------------
sub __isValidType {
	# ...
	# Verify that the given type is supported
	# Verify that the given bootloader is supported
	# ---
	my $this   = shift;
	my $type   = shift;
	my $caller = shift;
	my $kiwi = $this->{kiwi};
	if (! $caller ) {
		my $msg = 'Internal error __isValidType called without '
			. 'call origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $type ) {
		my $msg = "$caller: no description type given, retaining "
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %supported = map { ($_ => 1) } qw( boot system );
	if (! $supported{$type} ) {
		my $msg = "$caller: specified description type '$type' is not "
			. 'supported.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

1;
