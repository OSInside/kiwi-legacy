#================
# FILE          : KIWIProductData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module administers all kinds of product
#               : data stored in different structures
#               :
#               :
# STATUS        : Development
#----------------

package KIWIProductData;

use strict;


#===========================
# This module deals with the following datasets:
#   <productvar name="DISTNAME">JeOS</productvar>
#   <productinfo name="PROVIDES">product:$DISTNAME = $DISTVERSION</productinfo>
#   <productoption name="SOURCEMEDIUM">2</productoption>
# These three types of information have two different kinds of representations.
# For details look at KIWIXML.pl and the following methods therein:
# - sub getInstSourceProductVar
# - sub getInstSourceProductOption
# - sub getInstSourceProductStuff
# - sub getInstSourceProductInfo
#
# The information has these structures:
# - var/option:
#   + name=value hashes
# - info:
#   + index=[name, value] hash of lists
#
# Reason for the difference is that the info flows into the content file
# and there the order matters (according to Rudi)
#---------------------------



#==========================================
# Constructor
#------------------------------------------
sub new
{
  my $class = shift;
  my $this = {
    m_collect => shift,
    prodinfo  => undef,
    prodvars  => undef,
    prodopts  => undef,
    m_trans   => undef,
    m_prodinfo_updated   => 0,
    m_prodvars_updated   => 0,
    m_prodopts_updated   => 0,
  };
  bless ($this, $class);

  return undef if not defined($this->{m_collect});
  return $this;
}
# / constructor



#==========================================
# addSet
#------------------------------------------
# add a set of information to the respective
# data structure
# returns the number of elements added
# ret=0 means all specified vars were already set
#------------------------------------------
sub addSet
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $name = shift;
  my $hashref = shift;
  my $num_added = 0;

  if(not(defined($name) and defined($hashref))) {
    $this->{m_collect}->logger()->error("Name and hashref must be defined!");
    return undef;
  }
  else {
    my $what = shift;
    return undef if not defined $what;	#just to be on the safe side
    if($what eq "prodinfo") {
      foreach my $index(keys(%{$hashref})) {
	my @list = @{$hashref->{$index}};
	if(not defined($this->{$what}->{$list[0]})) {
	  $this->{$what}->{$index} = \@list;
	  $this->{$what."-indices"}->{$list[0]} = $index;
	  $this->{m_prodinfo_updated} = 1;
	  $num_added++;
	}
	else {
	  $this->{m_collect}->logger()->error("ProductData::addSet(): element with index $index already exists in m_inforef hash!");
	}
      }
      #%{$this->{$what."-hash"}} = map { $_->[0], $_->[1] } values %{$this->{$what}};
    }
    elsif($what eq "prodvars" or $what eq "prodopts") {
      foreach my $name(keys(%{$hashref})) {
	my $value = $hashref->{$name};
	if(not defined($this->{$what}->{$name})) {
	  $this->{$what}->{$name} = $value;
	  $this->{"m_".$what."_updated"} = 1;
	  $num_added++;
	}
	else {
	  $this->{m_collect}->logger()->error("ProductData::addSet(): element with index $name already exists in $what hash!");
	}
      }
    }
    else {
      # error
	  $this->{m_collect}->logger()->error("ProductData::addSet(): $what is not a valid element!");
    }
  }
  return $num_added;
}
# /addSet



#==========================================
# getSet
#------------------------------------------
# retrieve a reference to a specified hash
#------------------------------------------
sub getSet
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $name = shift;
  if(not defined($name)) {
    return undef;
  }
  else {
    return $this->{$name};
  }
}
# /getSet



#==========================================
# getVar
#------------------------------------------
# retrieve a specific variable by name
#------------------------------------------
sub getVar
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $var = shift;
  if(not defined($var)) {
    return undef;
  }
  else {
    if(defined($this->{prodvars}->{$var})) {
      return $this->{prodvars}->{$var};
    }
    else {
      $this->{m_collect}->logger()->warning("ProductData:getVar($var) is not set");
      return undef;
    }
  }
}
# /getVar



#==========================================
# getVarSafe
#------------------------------------------
# retrieve a specific variable by name
# returns defined strings in case getVar
# returns undef
#------------------------------------------
sub getVarSafe
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $retval = $this->getVar(@_);
  if(not defined($retval)) {
    return "--UNDEFINED--";
  }
  else {
    return $retval;
  }
}
# /getVarSafe



#==========================================
# getInfo
#------------------------------------------
# retrieve a specific productinfo by name
#------------------------------------------
sub getInfo
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $info = shift;
  if(not defined($info)) {
    return undef;
  }
  else {
    if(defined($this->{'prodinfo'}->{$this->{'prodinfo-indices'}->{$info}})) {
      return $this->{'prodinfo'}->{$this->{'prodinfo-indices'}->{$info}}->[1];
    }
    else {
      $this->{m_collect}->logger()->warning("ProductData:getInfo($info) is not set");
      return undef;
    }
  }
}
# /getInfo



#==========================================
# getInfoSafe
#------------------------------------------
# retrieve a specific productinfo by name
# returns defined strings in case getInfo
# returns undef
#------------------------------------------
sub getInfoSafe
{
  my $this = shift;
  if(not ref($this)) {
    return "";
  }
  my $retval = $this->getInfo(@_);
  if(not defined($retval)) {
    return "--UNDEFINED--";
  }
  else {
    return $retval;
  }
}
# /getInfoSafe



#==========================================
# getOpt
#------------------------------------------
# retrieve a specific productopt by name
#------------------------------------------
sub getOpt
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $opt = shift;
  if(not defined($opt)) {
    return undef;
  }
  else {
    if(defined($this->{prodopts}->{$opt})) {
      return $this->{prodopts}->{$opt};
    }
    else {
      $this->{m_collect}->logger()->warning("ProductData:getOpt($opt) is not set");
      return undef;
    }
  }
}
# /getOpt



#==========================================
# getOptSafe
#------------------------------------------
# retrieve a specific productopt by name
# returns defined strings in case getOpt
# returns undef
#------------------------------------------
sub getOptSafe
{
  my $this = shift;
  if(not ref($this)) {
    return "";
  }
  my $retval = $this->getOpt(@_);
  if(not defined($retval)) {
    return "--UNDEFINED--";
  }
  else {
    return $retval;
  }
}
# /getOptSafe



#==========================================
# internal ("private") methods
#------------------------------------------



#==========================================
# _expand
#------------------------------------------
# expand variables in other variables
#------------------------------------------
sub _expand
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }

  #------------------------------------------
  # The workflow shall be as follows:
  # - check if the vars changed (must be set by
  #   addSet for instance)
  # - if yes, reread the variables to the trans-
  #   formation hash
  # - use the transformation hash's content to
  #   substitute all occurences of $varname in
  #   any variable's content
  #------------------------------------------

  # make m_trans hash up to date:
  if($this->{m_prodinfo_updated}) {
    foreach my $i(keys(%{$this->{prodinfo}})) {
      if(not defined($this->{m_trans}->{$i}) or $this->{m_trans}->{$this->{prodinfo}->{$i}->[0]} ne $this->{prodinfo}->{$i}->[0]) {
	$this->{m_trans}->{$this->{prodinfo}->{$i}->[0]} = $this->{prodinfo}->{$i}->[1];
	$this->{m_prodinfo_updated} = 0;
      }
    }
  }

  if($this->{m_prodvars_updated}) {
    foreach my $var(keys(%{$this->{prodvars}})) {
      if(not defined($this->{m_trans}->{$var}) or $this->{m_trans}->{$var} ne $this->{prodvars}->{$var}) {
	$this->{m_trans}->{$var} = $this->{prodvars}->{$var};
	$this->{m_prodvars_updated} = 0;
      }
    }
  }

  if($this->{m_prodopts_updated}) {
    foreach my $opt(keys(%{$this->{prodopts}})) {
      if(not defined($this->{m_trans}->{$opt}) or $this->{m_trans}->{$opt} ne $this->{prodopts}->{$opt}) {
	$this->{m_trans}->{$opt} = $this->{prodopts}->{$opt};
	$this->{m_prodopts_updated} = 0;
      }
    }
  }

  # now substitute:
  foreach my $i(keys(%{$this->{prodinfo}})) {
    $this->{prodinfo}->{$i}->[1] = $this->_substitute($this->{prodinfo}->{$i}->[1]);
  }
  foreach my $name(keys(%{$this->{prodvars}})) {
    $this->{prodvars}->{$name} = $this->_substitute($this->{prodvars}->{$name});
  }
  foreach my $name(keys(%{$this->{prodopts}})) {
    $this->{prodopts}->{$name} = $this->_substitute($this->{prodopts}->{$name});
  }
 
  return 0;
}



#==========================================
# _substitute
#------------------------------------------
# substitute variables in strings
# use m_trans as translation table.
# Redo a line if one variable contains another
# examlpe:
#   VERSION = 11
#   RELEASE = 0
#   FULLVER = $VERSION.$RELEASE
#   PRODUCT = openSUSE-$FULLVER
# shall expand to:
#   PRODUCT = openSUSE-11.0
# if product is expanded first:
#   PRODUCT = openSUSE-$FULLVER and redo expansion
#   until all $ are slashed
#------------------------------------------
sub _substitute
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }

  my $string = shift;
  if(not defined($string)) {
    return undef;
  }

  #expression: \$([A-Za-z_]*).* = a dollar sign followed by any character/underscore combination
  #while($string =~ m{\$([A-Za-z]*).*}) {
  while($string =~ m{(\$)([A-Za-z_]*).*}) {
    if(defined($this->{m_trans}->{$2})) {
      my $repl = $this->{m_trans}->{$2};
      $string =~ s{\$$2}{$repl};
    }
    else {
      $this->{m_collect}->logger()->warning("ProductData::_substitute: pattern $1 is not in the translation hash!\n");
      $string =~ s{\$$2}{NOTSET};
      next;
    }
  }

  return $string;
}




1;

