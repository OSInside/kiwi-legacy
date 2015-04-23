#================
# FILE          : KIWIExt2Builder.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2015 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Build an ext2 based filesystem image
#               :
# STATUS        : Development
#----------------
package KIWIExt2Builder;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX;
use KIWIXML;

use base qw /KIWIExtBuilderBase/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIExt2Builder object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    if (! $this) {
        return;
    }
    $this->{baseWork} = 'fsext2';
    $this->{fstype} = 'ext2';
    return $this;
}

1;
