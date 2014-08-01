#================
# FILE          : KIWIXMLPackageProductData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <product> element.
#               :
# STATUS        : Development
#----------------
package KIWIXMLPackageProductData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
use base qw /KIWIXMLFileData/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIXMLPackageProductData object
    #
    # Internal data structure
    #
    # this = {
    #    arch        = '' (inherited from KIWIXMLFileData)
    #    name        = '' (inherited from KIWIXMLFileData)
    #    elname      = 'product'
    # }
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    if (! $this) {
        return;
    }
    $this->{elname} = 'product';
    return $this;
}

1;
