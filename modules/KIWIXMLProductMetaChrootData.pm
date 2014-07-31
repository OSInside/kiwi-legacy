#================
# FILE          : KIWIXMLProductMetaChrootData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE  LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <metafile> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLProductMetaChrootData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

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
  # Create the KIWIXMLProductMetaChrootData object
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $class = shift;
  my $this  = $class->SUPER::new(@_);
  #==========================================
  # Module Parameters
  #------------------------------------------
  my $init  = shift;
  #==========================================
  # Argument checking and object data store
  #------------------------------------------
  if (! $this -> p_hasInitArg($init) ) {
    return;
  }
  my %keywords = map { ($_ => 1) } qw(
      requires
    value
  );
  $this->{supportedKeywords} = \%keywords;
  my %boolKW = ( value => 1 );
  $this->{boolKeywords} = \%boolKW;
  if (! $this -> p_isInitHashRef($init) ) {
    return;
  }
  if (! $this -> p_areKeywordArgsValid($init) ) {
    return;
  }
  if (! $this -> __isInitConsistent($init)) {
    return;
  }
  $this->{requires} = $init->{requires};
  $this->{value}    = $init->{value};
  return $this;
}

#==========================================
# chrootNeeded
#------------------------------------------
sub chrootNeeded {
  # ...
  # Return the value indicating whether or not chroot is needed
  # ---
  my $this = shift;
  return $this->{value};
}

#==========================================
# getRequires
#------------------------------------------
sub getRequires {
  # ...
  # Return the configured requires value
  # ---
  my $this = shift;
  return $this->{requires};
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
  if (! $init->{requires} ) {
    my $msg = 'KIWIXMLProductMetaChrootData: no "requires" specified in '
      . 'initialization structure.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  if (! $init->{value} ) {
    my $msg = 'KIWIXMLProductMetaChrootData: no "value" specified in '
      . 'initialization structure.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  if (! $this -> p_areKeywordBooleanValuesValid($init) ) {
    return;
  }
  return 1;
}

1;
