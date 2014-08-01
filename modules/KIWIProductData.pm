#================
# FILE          : KIWIProductData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Adrian Schroeter <adrian@suse.de>
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
    # This module deals with the following datasets:
    #   <productvar name="DISTNAME">JeOS</productvar>
    #   <productinfo name="PROVIDES">
    #      product:$DISTNAME = $DISTVERSION
    #   </productinfo>
    #   <productoption name="SOURCEMEDIUM">2</productoption>
    # These three types of information have two different
    # kinds of representations. For details look at KIWIXML.pl
    # and the following methods there in:
    #
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
    # Reason for the difference is that the info flows into
    # the content file and there the order matters
    # (according to Rudi)
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Constructor setup
    #------------------------------------------
    $this->{m_collect} = shift;
    $this->{m_prodinfo_updated} = 0;
    $this->{m_prodvars_updated} = 0;
    $this->{m_prodopts_updated} = 0;
    #==========================================
    # Check pre condition
    #------------------------------------------
    if (! $this->{m_collect}) {
        return;
    }
    return $this;
}

#==========================================
# addSet
#------------------------------------------
sub addSet {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $name = shift;
    my $hashref = shift;
    my $num_added = 0;

    if (not(defined($name) and defined($hashref))) {
        $this->{m_collect}->logMsg("E", "Name and hashref must be defined!");
        return;
    } else {
        my $what = shift;
        return if not defined $what;  #just to be on the safe side
        if ($what eq "prodinfo") {
            foreach my $index(keys(%{$hashref})) {
                my @list = @{$hashref->{$index}};
                if(not defined($this->{$what}->{$list[0]})) {
                    $this->{$what}->{$index} = \@list;
                    $this->{$what."-indices"}->{$list[0]} = $index;
                    $this->{m_prodinfo_updated} = 1;
                    $num_added++;
                } else {
                    $this->{m_collect} -> logMsg("E", 
                            "ProductData::addSet(): element with index $index already exists in m_inforef hash!"
                    );
                }
            }
        } elsif ($what eq "prodvars" or $what eq "prodopts") {
            foreach my $name(keys(%{$hashref})) {
                my $value = $hashref->{$name};
                if(not defined($this->{$what}->{$name})) {
                    $this->{$what}->{$name} = $value;
                    $this->{"m_".$what."_updated"} = 1;
                    $num_added++;
                } else {
                    $this->{m_collect} -> logMsg("E",
                        "ProductData::addSet(): element with index $name already exists in $what hash!"
                    );
                }
            }
        } else {
            $this->{m_collect} -> logMsg("E",
                "ProductData::addSet(): $what is not a valid element!"
            );
        }
    }
    return $num_added;
}

#==========================================
# getSet
#------------------------------------------
sub getSet {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $name = shift;
    if (not defined($name)) {
        return;
    } else {
        return $this->{$name};
    }
}

#==========================================
# setInfo
#------------------------------------------
sub setInfo {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $var = shift;
    my $value = shift;
    if (! $this->{prodinfo}->{$this->{'prodinfo-indices'}->{$var}}) {
        $this->{'prodinfo-indices'}->{$var}=keys %{$this->{'prodinfo-indices'}};
        $this->{prodinfo}->{$this->{'prodinfo-indices'}->{$var}}->[0] = $var;
    }
    $this->{prodinfo}->{$this->{'prodinfo-indices'}->{$var}}->[1] = $value;
    return;
}

#==========================================
# setOpt
#------------------------------------------
sub setOpt {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $var = shift;
    my $value = shift;
    $this->{prodopts}->{$var} = $value;
    return;
}

#==========================================
# setVar
#------------------------------------------
sub setVar {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $var = shift;
    my $value = shift;
    $this->{prodvars}->{$var} = $value;
    return;
}

#==========================================
# getVar
#------------------------------------------
sub getVar {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $var = shift;
    my $mydefault = undef;
    eval { $mydefault = shift; };

    if (not defined($var)) {
        $this->{m_collect}->logMsg("E",
            "ProductData:getVar() \$var is not set"
        );
        return;
    } else {
        if(defined($this->{prodvars}->{$var})) {
        return $this->{prodvars}->{$var};
        } else {
            $this->{m_collect}->logMsg("I",
                "ProductData:getVar($var) is not set"
            );
            return $mydefault;
        }
    }
    return $mydefault;
}

#==========================================
# getVarSafe
#------------------------------------------
sub getVarSafe {
    my @list = @_;
    my $this = shift @list;
    if (not ref($this)) {
        return;
    }
    my $retval = $this->getVar(@list);
    if (not defined($retval)) {
        return "--UNDEFINED--";
    } else {
        return $retval;
    }
}

#==========================================
# getInfo
#------------------------------------------
sub getInfo {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $info = shift;
    if(not defined($info)) {
        return;
    } else {
        if ($this->{'prodinfo-indices'}->{$info} && $this->{'prodinfo'}->{$this->{'prodinfo-indices'}->{$info}}) {
            return $this->{'prodinfo'}
                ->{$this->{'prodinfo-indices'}->{$info}}->[1];
        } else {
            $this->{m_collect}->logMsg("W",
                "ProductData:getInfo($info) is not set"
            );
            return;
        }
    }
}

#==========================================
# getInfoSafe
#------------------------------------------
sub getInfoSafe {
    my @list = @_;
    my $this = shift @list;
    if (not ref($this)) {
        return "";
    }
    my $retval = $this->getInfo(@list);
    if (not defined($retval)) {
        return "--UNDEFINED--";
    } else {
        return $retval;
    }
}

#==========================================
# getOpt
#------------------------------------------
sub getOpt {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $opt = shift;
    if (not defined($opt)) {
        return;
    } else {
        if(defined($this->{prodopts}->{$opt})) {
            return $this->{prodopts}->{$opt};
        } else {
            $this->{m_collect}->logMsg("W",
                "ProductData:getOpt($opt) is not set"
            );
            return;
        }
    }
}

#==========================================
# getOptSafe
#------------------------------------------
sub getOptSafe {
    my @list = @_;
    my $this = shift @list;
    if (not ref($this)) {
        return "";
    }
    my $retval = $this->getOpt(@list);
    if(not defined($retval)) {
        return "--UNDEFINED--";
    } else {
        return $retval;
    }
}

#==========================================
# internal ("private") methods
#------------------------------------------
#==========================================
# _expand
#------------------------------------------
sub _expand {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    if($this->{m_prodinfo_updated}) {
        foreach my $i(keys(%{$this->{prodinfo}})) {
            if ((!defined($this->{m_trans}->{$i})) or
                ($this->{m_trans}->{$this->{prodinfo}->{$i}->[0]} ne
                 $this->{prodinfo}->{$i}->[0])
            ) {
                $this->{m_trans}->{$this->{prodinfo}->{$i}->[0]} 
                    = $this->{prodinfo}->{$i}->[1];
                $this->{m_prodinfo_updated} = 0;
            }
        }
    }
    if($this->{m_prodvars_updated}) {
        foreach my $var(keys(%{$this->{prodvars}})) {
            if ((!defined($this->{m_trans}->{$var})) or 
                ($this->{m_trans}->{$var} ne $this->{prodvars}->{$var})
            ) {
                $this->{m_trans}->{$var} = $this->{prodvars}->{$var};
                $this->{m_prodvars_updated} = 0;
            }
        }
    }
    if($this->{m_prodopts_updated}) {
        foreach my $opt(keys(%{$this->{prodopts}})) {
            if ((!defined($this->{m_trans}->{$opt})) ||
                ($this->{m_trans}->{$opt} ne $this->{prodopts}->{$opt})
            ) {
                $this->{m_trans}->{$opt} = $this->{prodopts}->{$opt};
                $this->{m_prodopts_updated} = 0;
            }
        }
    }
    foreach my $i(keys(%{$this->{prodinfo}})) {
        $this->{prodinfo}->{$i}->[1] =
            $this->_substitute($this->{prodinfo}->{$i}->[1]);
    }
    foreach my $name(keys(%{$this->{prodvars}})) {
        $this->{prodvars}->{$name} =
            $this->_substitute($this->{prodvars}->{$name});
    }
    foreach my $name(keys(%{$this->{prodopts}})) {
        $this->{prodopts}->{$name} =
            $this->_substitute($this->{prodopts}->{$name});
    }
    return 0;
}

#==========================================
# _substitute
#------------------------------------------
sub _substitute {
    my $this = shift;
    if (not ref($this)) {
        return;
    }
    my $string = shift;
    if (not defined($string)) {
        return;
    }
    while($string =~ m{(\$)([A-Za-z_]*).*}) {
        if (defined($this->{m_trans}->{$2})) {
            my $repl = $this->{m_trans}->{$2};
            $string =~ s{\$$2}{$repl};
        } else {
            $this->{m_collect}->logMsg("W",
                "ProductData::_substitute: pattern $1 is not in the translation hash!\n"
            );
            $string =~ s{\$$2}{NOTSET};
            next;
        }
    }
    return $string;
}

1;

