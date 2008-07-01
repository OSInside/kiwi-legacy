#================
# FILE          : KIWIArchList
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to adminster a list of
#               : architecture objects
#               :
# STATUS        : Development
#----------------

package KIWIArchList;

use strict;

use KIWIArch;


#==================
# constructor
#------------------
sub new
{
  # ...
  # Create a new KIWIArchList object which administers
  # the arch objects
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $class = shift;

  my $this  = {
    m_collect	=> undef,     # phone back to KIWICollect
    m_archs	=> {},	      # name/objref pairs
  };
  bless ($this, $class);

  # other init work:
  $this->{m_collect}	= shift;  # first and most important thing: store the caller object
  if(not defined($this->{m_collect})) {
    return undef; # rock hard get outta here: caller must check retval anyway
  }

  return $this;
}
# /constructor



#==================
# access methods
#------------------



#==================
# arch(NAME)
#------------------
# returns undef if the element is not in the hash
#------------------
sub arch
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $name = shift;

  if(defined($this->{m_archs}->{$name})) {
    return $this->{m_archs}->{$name};
  }
  else {
    return undef;
  }
}



#==================
# other methods
#------------------



#==================
# _addArch
#------------------
# adds one specific arch object to the list
#------------------
sub _addArch
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $num = @_;
  if(!@_ or $num < 3) {
    $this->{m_collect}->logger()->error("_addArch: wrong number of arguments!\n");
    return undef;
  }
  my ($name, $desc, $next) = @_;
  if(defined($this->{m_archs}->{$name})) {
    $this->{m_collect}->logger()->error("_addArch: arch=$name already in list, skipping\n");
    return 0;
  }
  my $arch = new KIWIArch($name, $desc, $next);
  $this->{m_archs}->{$name} = $arch;
  return 1;
}



#==================
# addArchs
#------------------
# add all architectures from a hash
# The hash has the following structure
# (see KIWIXML::getInstSourceArchList):
# - name => [descr, nextname]
# nextname is verified through xml validation:
# there must be an entry with the referred name
#------------------
sub addArchs
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }

  my $hashref = shift;
  if(not defined($hashref)) {
    return undef;
  }
  foreach my $a(keys(%{$hashref})) {
    my $n = $hashref->{$a}->[1] eq "0"?"":$hashref->{$a}->[1];
    $this->_addArch($a, $hashref->{$a}->[0], $hashref->{$a}->[1]);
  }
}



#==================
# fallbacks
#------------------
# Create a list of fallback architectures
# thereby omitting a list of archs in the
# fallback chain if given as parameters
# Call like this:
# my $list = $archlist->fallback(name[, omitlist])
# if omitlist is empty the full fallback chain
# is returned.
#------------------
sub fallbacks
{
  my $this = shift;
  my @al;
  if(not ref($this)) {
    return @al;
  }

  my $name = shift;
  if(not defined($name)) {
    return @al;
  }
  if(not defined($this->{m_archs}->{$name})) {
    return @al;
  }

  my %omits;
  if(@_) {
    %omits = map { $_ => 1 } @_;
  }
  # loop the whole chain following "$name":
  #for(my $a = $this->{m_archs}->{$name}; $a->follower();) {
  my $a = $this->arch($name);
  while(1) {
    if(not($omits{$a->name()})) {
      push @al, $a->name();
    }
    $a = $this->arch($a->follower());
    last if not defined($a);
  }
  return @al;
}



1;

