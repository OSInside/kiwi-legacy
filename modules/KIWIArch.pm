#================
# FILE          : KIWIArch
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Encapsulates an architecture object with access methods.
#		: Provides a single ended queue mechanism
#               :
# STATUS        : Development
#----------------

package KIWIArch;

use strict;



#==================
# constructor
#------------------
# parameters:
# - [class name]
# - name of the architecture (scalar)
# - description string (scalar)
# - next architcture in fallback chain (scalar)
#------------------
sub new
{
  # ...
  # Create a new KIWIArch object which represents one
  # particular architecture and its next fallback
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $class = shift;

  my $this  = {
    m_name	=> undef,
    m_desc	=> undef,
    m_next	=> undef,
  };
  bless ($this, $class);

  $this->{m_name} = shift;
  $this->{m_desc} = shift;
  $this->{m_next} = shift;
  if(not(defined($this->{m_name}) and defined($this->{m_desc}) and defined($this->{m_next}))) {
    return undef; # rock hard get outta here: caller must check retval anyway
  }

  return $this;
}
# /constructor



#==================
# access methods
#------------------



#==================
# name
#------------------
sub name
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_name};
}



#==================
# desc
#------------------
sub desc
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_desc};
}



#==================
# next
#------------------
sub follower
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  if($this->{m_next} eq "") {
    return undef;
  }
  else {
    return $this->{m_next};
  }
}



1;

