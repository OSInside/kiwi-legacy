#================
# FILE          : KIWIExt4Builder.pm
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
package KIWIExt4Builder;
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
    # Create the KIWIExt4Builder object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    if (! $this) {
        return;
    }
    $this->{baseWork} = 'fsext4';
    $this->{mountOpts} = 'nodelalloc';
    $this->{fstype} = 'ext4';
    return $this;
}

1;
