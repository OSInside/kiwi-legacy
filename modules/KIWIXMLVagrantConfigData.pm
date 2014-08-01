#================
# FILE          : KIWIXMLVagrantConfigData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <vagrantconfig> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLVagrantConfigData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Scalar::Util qw /looks_like_number/;
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
    # Create the KIWIXMLVagrantConfigData object
    #
    # Internal data structure
    #
    # this = {
    #    provider = ''
    #    virtual_size = ''
    # }
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
    my %keywords = map { ($_ => 1) } qw(
        provider
        virtual_size
    );
    $this->{supportedKeywords} = \%keywords;
    if (! $this -> p_isInitHashRef($init) ) {
        return;
    }
    if (! $this -> p_areKeywordArgsValid($init) ) {
        return;
    }
    $this->{provider} = $init->{provider};
    $this->{virtual_size} = $init->{virtual_size};
    return $this;
}

#==========================================
# getProvider
#------------------------------------------
sub getProvider {
    # ...
    # Return the setting for the provider configuration
    # ---
    my $this = shift;
    return $this->{provider};
}

#==========================================
# setProvider
#------------------------------------------
sub setProvider {
    # ...
    # Set the provider attribute, if called with no argument the
    # attribute is erased
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        if ($this->{provider}) {
            delete $this->{provider};
        }
    } else {
        $this->{provider} = $val;
    }
    return $this;
}

#==========================================
# getVirtualSize
#------------------------------------------
sub getVirtualSize {
    # ...
    # Return the setting for the virtual size configuration
    # ---
    my $this = shift;
    return $this->{virtual_size};
}

#==========================================
# setVirtualSize
#------------------------------------------
sub setVirtualSize {
    # ...
    # Set the virtual_size attribute, if called with no argument the
    # attribute is erased
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        if ($this->{virtual_size}) {
            delete $this->{virtual_size};
        }
    } else {
        $this->{virtual_size} = $val;
    }
    return $this;
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
    # ...
    # Return an XML Element representing the object's data
    # ---
    my $this = shift;
    my $element = XML::LibXML::Element -> new('vagrantconfig');
    my $provider = $this -> getProvider();
    my $vsize = $this -> getVirtualSize();
    if ($provider) {
        $element -> setAttribute('provider', $provider);
    }
    if ($vsize) {
        $element -> setAttribute('virtualsize', $vsize);
    }
    return $element;
}

1;
