#================
# FILE          : KIWIImageBuildFactory.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This factory returns a KIWIImageBuilder object
#               : specifc for the image type being built.
#               :
# STATUS        : Development
#----------------
package KIWIImageBuildFactory;

#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWIModules
#------------------------------------------
use KIWICommandLine;
use KIWIContainerBuilder;
use KIWILog;
use KIWITarArchiveBuilder;
use KIWIXML;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIImageBuildFactory
    # ---
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Module Parameters
    #------------------------------------------
    my $xml = shift;
    my $cmdL = shift;
    my $uPckImg = shift;
    my $kiwi = KIWILog -> instance();
    if (! defined $xml || ref($xml) ne 'KIWIXML') {
        my $msg = 'KIWIImageBuildFactory: expecting KIWIXML object as '
            . 'first argument.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if (! defined $cmdL || ref($cmdL) ne 'KIWICommandLine') {
        my $msg = 'KIWIImageBuildFactory: expecting KIWICommandLine object '
            . 'as second argument.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if (! defined $uPckImg || ref($uPckImg) ne 'KIWIImage') {
        my $msg = 'KIWIImageBuildFactory: expecting KIWIImage object '
            . 'as third argument.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    $this->{cmdL}    = $cmdL;
    $this->{uPckImg} = $uPckImg;
    $this->{kiwi}    = $kiwi;
    $this->{xml}     = $xml;
    return $this;
}

#==========================================
# getImageBuilder
#------------------------------------------
sub getImageBuilder {
    # ...
    # Return an image tyep specific builder object
    # ---
    my $this = shift;
    my $cmdL = $this->{cmdL};
    my $unPImg = $this->{uPckImg};
    my $xml  = $this->{xml};
    my $typeName = $xml -> getImageType() -> getTypeName();
    SWITCH: for ($typeName) {
        /^lxc|^docker/smx && do {
            my $builder = KIWIContainerBuilder -> new($xml, $cmdL, $unPImg);
            return $builder;
        };
        /^tbz/smx && do {
            my $builder = KIWITarArchiveBuilder -> new($xml, $cmdL, $unPImg);
            return $builder;
        };
    }
    return;
}

1;
