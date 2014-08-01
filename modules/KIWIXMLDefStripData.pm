#================
# FILE          : KIWIXMLDefStripData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the default settings encoded in KIWI
#               : for various strip settings.
#               :
# STATUS        : Development
#----------------
package KIWIXMLDefStripData;
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

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILog;
use KIWIXMLStripData;
use KIWIGlobals;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIXMLDefStripData object
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    my $kiwi = KIWILog -> instance();
    #==========================================
    # load the default strip section
    #------------------------------------------
    my $defaultDefFile = shift;
    if (! $defaultDefFile) {
        $defaultDefFile = KIWIGlobals
            -> instance()
            -> getKiwiConfig()
            -> {KStrip};
    }
    if (! -f $defaultDefFile) {
        my $msg = 'Could not find default strip section definition file: '
            . "'$defaultDefFile'";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $stripDOM;
    my $res = eval {
        my $xml = XML::LibXML -> new();
        $stripDOM = $xml -> parse_file( $defaultDefFile );
    };
    if ($@ || ! $res) {
        my $msg = 'Could not parse default strip section definition file: '
            . "'$defaultDefFile'\n";
        my $evaldata=$@;
        $msg .= $evaldata;
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my @stripNodes = $stripDOM
        -> getElementsByTagName ("initrd")
        -> get_node (1)
        -> getElementsByTagName ("strip");

    for my $stripND (@stripNodes) {
        my $type = $stripND -> getAttribute("type");
        my @stripData;
        for my $fileND ($stripND -> getElementsByTagName('file')) {
            my $arch = $fileND -> getAttribute('arch');
            my $name = $fileND -> getAttribute('name');
            my %stripData = (
                arch => $arch,
                name => $name
            );
            my $stripObj = KIWIXMLStripData -> new(\%stripData);
            if (! $stripObj) {
                return;
            }
            push @stripData, $stripObj;
        }
        $this->{$type} = \@stripData
    }
    $this->{kiwi} = $kiwi;
    return $this;
}

#==========================================
# getFilesToDelete
#------------------------------------------
sub getFilesToDelete {
    # ...
    # Return an array ref containing StripData objects for the delete section
    # in the default strip file.
    # ---
    my $this = shift;
    return $this -> {delete};
}

#==========================================
# getLibsToKeep
#------------------------------------------
sub getLibsToKeep {
    # ...
    # Return an array ref containing StripData objects for the libs section
    # in the default strip file.
    # ---
    my $this = shift;
    return $this -> {libs};
}

#==========================================
# getToolsToKeep
#------------------------------------------
sub getToolsToKeep {
    # ...
    # Return an array ref containing StripData objects for the tools section
    # in the default strip file.
    # ---
    my $this = shift;
    return $this -> {tools};
}

1;
