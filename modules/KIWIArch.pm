#================
# FILE          : KIWIArch
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Encapsulates an architecture object with
#               : access methods. Provides a single ended
#               : queue mechanism
#               :
# STATUS        : Development
#----------------
package KIWIArch;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

#==========================================
# Constructor
#------------------------------------------
sub new {
  # ...
  # Create a new KIWIArch object which represents one
  # particular architecture and its next fallback
  # parameters:
  # - [class name]
  # - name of the architecture (scalar)
  # - description string (scalar)
  # - next architcture in fallback chain (scalar)
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
  $this->{m_name} = shift;
  $this->{m_desc} = shift;
  $this->{m_next} = shift;
  $this->{m_head} = shift;
  if (
    (! $this->{m_name}) &&
    ($this->{m_desc}) && ($this->{m_next}) && ($this->{m_head})
  ) {
    return;
  }
  return $this;
}
#==========================================
# name
#------------------------------------------
sub name {
  my $this = shift;
  return $this->{m_name};
}

#==========================================
# desc
#------------------------------------------
sub desc {
  my $this = shift;
  return $this->{m_desc};
}

#==========================================
# follower
#------------------------------------------
sub follower {
  my $this = shift;
  if (($this->{m_next}) && (! $this->{m_next} eq "")) {
    return $this->{m_next};
  }
  return;
}

#==========================================
# isHead 
#------------------------------------------
sub isHead {
  my $this = shift;
  if (($this->{m_head}) && (! $this->{m_head} eq "")) {
    return 1;
  }
  return 0;
}

1;
