#================
# FILE          : KIWIXMLProductArchitectureData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <arch> element.
#               :
#               : The child relationshipt to the <architectures> element is
#               : handeled in the XML class.
#               :
# STATUS        : Development
#----------------
package KIWIXMLProductArchitectureData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use XML::LibXML;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
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
  # Create the KIWIXMLProductArchitectureData object
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
  if (! $this -> p_hasInitArg($init) ) {
    return;
  }
  my %keywords = map { ($_ => 1) } qw(
    fallback
      id
    name
  );
  $this->{supportedKeywords} = \%keywords;
  if (! $this -> p_isInitHashRef($init) ) {
    return;
  }
  if (! $this -> p_areKeywordArgsValid($init) ) {
    return;
  }
  if (! $this -> __isInitConsistent($init)) {
    return;
  }
  $this->{fallback} = $init->{fallback};
  $this->{id}       = $init->{id};
  $this->{name}     = $init->{name};
  return $this;
}

#==========================================
# getFallbackArch
#------------------------------------------
sub getFallbackArch {
  # ...
  # Return the fallback architecture value, if any
  # ---
  my $this = shift;
  return $this->{fallback};
}

#==========================================
# getID
#------------------------------------------
sub getID {
  # ...
  # Return the ID for the architecture value, if any
  # ---
  my $this = shift;
  return $this->{id};
}

#==========================================
# getName
#------------------------------------------
sub getName {
  # ...
  # Return the name value
  # ---
  my $this = shift;
  return $this->{name};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
  # ...
  # Return an XML Element representing the object's data
  # ---
  my $this = shift;
  my $element = XML::LibXML::Element -> new( 'arch' );
  $element -> setAttribute('id', $this -> getID());
  $element -> setAttribute('name', $this -> getName());
  my $fallback = $this -> getFallbackArch();
  if ($fallback) {
    $element -> setAttribute('fallback', $fallback);
  }
  return $element;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
  # ...
  # Verify that the initialization hash is valid
  # ---
  my $this = shift;
  my $init = shift;
  my $kiwi = $this->{kiwi};
  if (! $init->{id} ) {
    my $msg = 'KIWIXMLProductArchitectureData: no "id" specified in '
      . 'initialization structure.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  if (! $init->{name} ) {
    my $msg = 'KIWIXMLProductArchitectureData: no "name" specified in '
      . 'initialization structure.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  my $fallback = $init->{fallback};
  if ($fallback) {
    if ( $fallback ne 'noarch' && (! $this->{supportedArch}{$fallback} )) {
      my $msg = "Specified 'fallback' has unexpected value '$fallback'";
      $kiwi -> error ($msg);
      $kiwi -> failed ();
      return;
    }
  }
  my $arch = $init->{id};
  if ( $arch ne 'noarch' && (! $this->{supportedArch}{$arch} )) {
    $kiwi -> error ("Specified 'id' has unexpected value '$arch'");
    $kiwi -> failed ();
    return;
  }
  return 1;
}

1;

