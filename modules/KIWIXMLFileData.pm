#================
# FILE          : KIWIXMLFileData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file encoded with the <file> element.
#               : As this is generic and non descriptive this class should
#               : not be used directly, only specific instances, i.e.
#               : children should be used.
#               :
# STATUS        : Development
#----------------
package KIWIXMLFileData;
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
    # Create the KIWIXMLFileData object
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    #==========================================
    # Module Parameters
    #------------------------------------------
    my $init   = shift;
    my $addlKW = shift;
    #==========================================
    # Argument checking and object data store
    #------------------------------------------
    if (! $this -> p_hasInitArg($init) ) {
        return;
    }
    my %keywords = map { ($_ => 1) } qw( arch name );
    if ($addlKW) {
        for my $kw (@{$addlKW}) {
            $keywords{$kw} = 1;
        }
    }
    $this->{supportedKeywords} = \%keywords;
    if (! $this -> p_isInitHashRef($init) ) {
        return;
    }
    if (! $this -> p_areKeywordArgsValid($init) ) {
        return;
    }
    if (! $this -> __isInitConsistent($init) )  {
        return;
    }
    $this->{arch}   = $init->{arch};
    $this->{elname} = 'file';
    $this->{name}   = $init->{name};

    return $this;
}

#==========================================
# getArch
#------------------------------------------
sub getArch {
    # ...
    # Return the architecture value, if any
    # ---
    my $this = shift;
    return $this->{arch};
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
    my $element = XML::LibXML::Element -> new( $this->{elname} );
    $element -> setAttribute('name', $this -> getName());
    my $arch = $this -> getArch();
    if ($arch) {
        $element -> setAttribute('arch', $arch);
    }
    return $element;
}

#==========================================
# setArch
#------------------------------------------
sub setArch {
    # ...
    # Set the architecture value
    # ---
    my $this = shift;
    my $arch = shift;
    if (! $this->__isSupportedArch($arch)) {
        return;
    }
    $this->{arch} = $arch;
    return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
    # ...
    # Verify initialization consistency and validity requirements
    # ---
    my $this = shift;
    my $init = shift;
    my $kiwi = $this->{kiwi};
    my $instName = ref $this;
    if (! $init->{name} ) {
        my $msg = "$instName: no 'name' specified in initialization "
            . 'structure.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if ($init->{arch}) {
        if (! $this -> __isSupportedArch($init->{arch})) {
            return;
        }
    }
    return 1;
}

#==========================================
# __isSupportedArch
#------------------------------------------
sub __isSupportedArch {
    # ...
    # See if the specified architecture is supported
    # ---
    my $this = shift;
    my $arch = shift;
    my @arches = split /,/smx, $arch;
    for my $arch (@arches) {
        if (! $this->{supportedArch}{$arch} ) {
            my $kiwi = $this->{kiwi};
            $kiwi -> error ("Specified arch '$arch' is not supported");
            $kiwi -> failed ();
            return;
        }
    }
    return 1;
}

1;
