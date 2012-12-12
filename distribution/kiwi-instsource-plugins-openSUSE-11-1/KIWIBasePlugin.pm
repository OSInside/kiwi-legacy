#================
# FILE          : KIWIInstSourceBasePlugin.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Base class for a loadable plugin which creates
#               : a certain type of metadata
#               :
# STATUS        : Development
#----------------

package KIWIBasePlugin;

use strict;


sub new
{
  # ...
  # Create a new KIWIInstSourceBasePlugin object which creates
  # one specific type of metadata
  # ---
  my $class = shift;
  
  my $this  = {
    m_handler	  => undef, # know the handler object
    m_name	  => "KIWIBasePlugin", # name of the plugin (just sound nice)
    m_order	  => undef, # order number, selects execution time
    m_requireddirs => [],    # list of directories required before execution
    m_descr	  => [],    # plaintext description of what the plugin does
    m_requires	  => [],    # list of required packages for the plugin
    m_ready	  => 0,	    # execution ready flag. Must be true to enable execute()
    m_collect	  => 0,	    # reference to KIWICollect object
  };
  bless ($this, $class);

  $this->{m_handler} = shift;
  if(not ref($this->{m_handler})) {
    return undef;
  }
  $this->{m_collect} = $this->{m_handler}->collect();

  return $this;
}
# /constructor



# access method for name:
sub name
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $oldname = $this->{m_name};
  if(@_) {
    $this->{m_name} = shift;
  }
  return $oldname;
}



# access method for order:
sub order
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $oldorder = $this->{m_order};
  if(@_) {
    $this->{m_order} = shift;
  }
  return $oldorder;
}



# access method for readyness:
sub ready
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $oldready = $this->{m_ready};
  if(@_) {
    $this->{m_ready} = shift;
  }
  return $oldready;
}



# access method for required directories:
sub requiredDirs
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my @oldrd = @{$this->{m_requireddirs}};
  foreach my $entry(@_) {
    push @{$this->{m_requireddirs}}, $entry;
  }
  return @oldrd;
}



# access method for description
sub description
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my @olddesc = $this->{m_descr};
  foreach my $entry(@_) {
    push @{$this->{m_descr}}, $entry;
  }
  return @olddesc;
}



# access method for requirements
sub requires
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my @oldreq = $this->{m_requires};
  foreach my $entry(@_) {
    push @{$this->{m_requires}}, $entry;
  }
  return @oldreq;
}



# access method for handler
sub handler
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_handler};
}



# access method for collect
sub collect
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  return $this->{m_collect};
}



# interface to KIWICollect::logMsg
sub logMsg
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $type = shift;
  my $msg = shift;
  if(not defined($type) or not defined($msg)) {
    return undef;
  }

  $this->{m_collect}->logMsg($type, $msg);
}



1;

