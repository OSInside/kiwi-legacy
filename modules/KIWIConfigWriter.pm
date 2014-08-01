#================
# FILE          : KIWIConfigWriter.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Base class for all *ConfigWriter classes
#               :
# STATUS        : Development
#----------------
package KIWIConfigWriter;
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
use KIWILog;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIConfigWriter object
    # ---
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Module Parameters
    #------------------------------------------
    my $xml = shift;
    my $configDir = shift;
    my $kiwi = KIWILog -> instance();
    my $child = ref $this;
    if (! defined $xml || ref($xml) ne 'KIWIXML') {
        my $msg = "$child: expecting KIWIXML object as "
            . 'first argument.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if (! defined $configDir) {
        my $msg = "$child: expecting configuration target "
            . 'directory as second argument.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if (! -d $configDir) {
        my $msg = "$child: configuration target directory "
            . 'does not exist.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }

    $this->{kiwi} = $kiwi;
    $this->{confDir} = $configDir;
    $this->{xml}  = $xml;

    return $this;
}

#==========================================
# getConfigDir
#------------------------------------------
sub getConfigDir {
    # ...
    # Return the location of the configuration directory
    # ---
    my $this = shift;
    return $this->{confDir};
}

#==========================================
# getConfigFileName
#------------------------------------------
sub getConfigFileName {
    # ...
    # Return the configuration file name
    # ---
    my $this = shift;
    return $this->{name};
}

#==========================================
# setConfigFileName
#------------------------------------------
sub setConfigFileName {
    # ...
    # Set the configuration file name
    # ---
    my $this = shift;
    my $name = shift;
    my $kiwi = $this->{kiwi};
    if (! $name) {
        my $msg = 'setConfigFileName: no filename argument '
            . 'provided, retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{name} = $name;
    return $this;
}

#==========================================
# setConfigDir
#------------------------------------------
sub setConfigDir {
    # ...
    # Set the location of the configuration directory
    # ---
    my $this = shift;
    my $confDir = shift;
    my $kiwi = $this->{kiwi};
    if (! $confDir) {
        my $msg = 'setConfigDir: no configuration directory argument '
            . 'provided, retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if ( ! -d $confDir) {
        my $msg = 'setConfigDir: given configuration directory does not '
            . 'exist, retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{confDir} = $confDir;
    return $this;
}

1;
