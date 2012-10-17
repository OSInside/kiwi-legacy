#================
# FILE          : KIWIXMLDescriptionData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi = shift;
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
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
	if ($init) {
		if (! $this -> __isInitConsistent($init) )  {
			return;
		}
		$this->{author}        = $init->{author};
		$this->{contact}       = $init->{contact};
		$this->{specification} = $init->{specification};
		$this->{type}          = $init->{type};
	}
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
	if (! $this -> __isObjectValid()) {
		return;
	}
	return $this->{author};
}

#==========================================
# getContactInfo
#------------------------------------------
sub getContactInfo {
	# ...
	# Return the value of the contact member
	# ---
	my $this = shift;
	if (! $this -> __isObjectValid()) {
		return;
	}
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
	if (! $this -> __isObjectValid()) {
		return;
	}
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
	if (! $this -> __isObjectValid()) {
		return;
	}
	return $this->{type};
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
		return;
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
# __isObjectValid
#------------------------------------------
sub __isObjectValid {
	# ...
	# All data members of the object must defined, or the object is
	# considered invalid and will not return any of its data.
	# ---
	my $this = shift;
	my @members = qw /author contact specification type/;
	for my $member (@members) {
		if (! defined $this->{$member}) {
			my $kiwi = $this->{kiwi};
			$kiwi->warning('XMLDescriptionData object in invalid state');
			$kiwi->oops();
			return;
		}
	}
	return 1;
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
		my $msg = "$caller: no description type specified, retaining "
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
