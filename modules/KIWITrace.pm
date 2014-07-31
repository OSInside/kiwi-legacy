#================
# FILE          : KIWITrace.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to store variables and
#               : functions which needs to be available globally
#               : for the purpose of tracing the perl commands
#               :
# STATUS        : Development
#----------------
package KIWITrace;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use File::Basename;

#==========================================
# Base class
#------------------------------------------
use base qw /Class::Singleton/;

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# One time initialization code
#------------------------------------------
sub _new_instance {
  # ...
  # Construct a KIWITrace object.
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $this  = {};
  my $class = shift;
  bless $this,$class;
  #==========================================
  # Globals (call trace)
  #------------------------------------------
  $this->{TT} = "Trace Level ";
  $this->{TL} = 1;
  $this->{BT} = [];
  return $this;
}

1;
