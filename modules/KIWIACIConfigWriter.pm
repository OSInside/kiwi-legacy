#================
# FILE          : KIWIACIConfigWriter.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2015 Matwey V. Kornilov
#               :
# AUTHOR        : Matwey V. Kornilov <matwey.kornilov@gmail.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Write a manifest file for a ACI
#               :
# STATUS        : Development
#----------------
package KIWIACIConfigWriter;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use JSON;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
use base qw /KIWIConfigWriter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIXML;
use KIWIXMLVMachineData;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIACIConfigWriter object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    if (! $this) {
        return;
    }
    $this->{name} = 'config';
    return $this;
}

#==========================================
# p_writeConfigFile
#------------------------------------------
sub p_writeConfigFile {
    # ...
    # Write the container configuration file
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $xml = $this->{xml};
    my $loc = $this -> getConfigDir();
    my $fileName = 'manifest';
    my $name = $xml -> getImageName();
    my $iver = $xml -> getPreferences() -> getVersion();
    my $json_data = {
    'acKind' => 'ImageManifest',
    'acVersion' => '0.5.1',
    'name' => $name,
    'labels' =>
    [{
         'name' => 'os',
         'value' => 'linux',
    },
    {
         'name' => 'version',
         'value' => $iver,
    }],
    };
    my $json_text = JSON->new->utf8->encode($json_data);

    $kiwi -> info("Write container manifest file\n");
    $kiwi -> info("--> $loc/$fileName");
    my $status = open (my $CONF, '>', "$loc/$fileName");
    if (! $status) {
         $kiwi -> failed();
         my $msg = 'Could not write container manifest file'."$loc/$fileName";
         $kiwi -> error($msg);
         $kiwi -> failed();
         return;
    }
    binmode $CONF;
    print $CONF $json_text;
    $status = close $CONF;
    if (! $status) {
         $kiwi -> oops();
         my $msg = 'Unable to close manifest file'."$loc/$fileName";
         $kiwi -> warning($msg);
         $kiwi -> skipped();
    }
    $kiwi -> done();

    return 1;
}

1;
