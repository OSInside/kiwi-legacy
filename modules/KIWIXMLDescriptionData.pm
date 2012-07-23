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
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Arg processing
	#------------------------------------------
	my $kiwi   = shift;
	if (! defined $kiwi) {
		$kiwi = KIWILog -> new("tiny");
	}
	$this->{kiwi} = $kiwi;
	my $author = shift;
	if (defined $author) {
		if (ref $author eq 'HASH') {
			$this->{author}        = $author->{author};
			$this->{contact}       = $author->{contact};
			$this->{specification} = $author->{specification};
			# Use setType to get value checking
			$this -> setType($author->{type});
		} else {
			$this->{author}        = $author;
			$this->{contact}       = shift;
			$this->{specification} = shift;
			my $type = shift;
			# Use setType to get value checking
			$this -> setType($type);
		}
	}
	return $this;
}

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

sub setType {
	# ...
	# Set the value of the type member
	# ---
	my $this = shift;
	my $type = shift;
	if (! defined $type) {
		return;
	}
	if ($type ne 'system' && $type ne 'boot') {
		my $kiwi = $this->{kiwi};
		$kiwi->warning("Attempting to set invalid description type '$type'");
		$kiwi->oops();
		return;
	}
	$this->{type} = $type;
	return $this;
}

#==========================================
# Private helper methods
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


1;
