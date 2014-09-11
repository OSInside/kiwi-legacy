#================
# FILE          : KIWIXMLSystemdiskData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <systemdisk> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLSystemdiskData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Scalar::Util qw /looks_like_number/;
use Readonly;
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
# constant
#------------------------------------------
Readonly my $NEXT_UNIT => 1024;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIXMLSystemdiskData object
    #
    # Internal data structure
    #
    # this = {
    #    name = ''
    #    preferlvm = true|false
    #    volumes = {
    #        ID[+] = {
    #            freespace = ''
    #            name      = ''
    #            size      = ''
    #            mountpoint= ''
    #    }
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
    my %keywords = map { ($_ => 1) } qw( name preferlvm volumes );
    $this->{supportedKeywords} = \%keywords;
    if (! $this -> p_isInitHashRef($init) ) {
        return;
    }
    if (! $this -> p_areKeywordArgsValid($init) ) {
        return;
    }
    if ($init) {
        # Check for unsupported entries
        if (! $this -> __isInitConsistent($init)) {
            return;
        }
        $this->{name}      = $init->{name};
        $this->{preferlvm} = $init->{preferlvm};
        $this->{volumes}   = $init->{volumes};
    }
    # Set the default name
    if (! $this->{name} ) {
        $this->{name} = 'kiwiVG';
    }
    # Set the default volume management preference
    if (! $this->{preferlvm}) {
        $this->{preferlvm} = 'false';
    }
    return $this;
}

#==========================================
# createVolume
#------------------------------------------
sub createVolume {
    # ...
    # Create a volume setup and return the ID
    # ---
    my $this    = shift;
    my $volInit = shift;
    my $kiwi = $this->{kiwi};
    my @existIDs = @{$this->getVolumeIDs()};
    my $newID = 1;
    if (@existIDs ) {
        $newID = $existIDs[-1] + 1;
    }
    if (! $volInit ) {
        my $msg = 'createVolume: expecting hash ref with volume data as '
            . 'argument';
        $kiwi -> error ($msg);
        $kiwi -> failed ();
        return;
    }
    if (ref($volInit) eq 'HASH' ) {
        my %suppoetedVolAttrs = (
            freespace  => 1,
            name       => 1,
            size       => 1,
            mountpoint => 1
        );
        for my $key (keys %{$volInit}) {
            if (! $suppoetedVolAttrs{$key} ) {
                my $msg = "createVolume: found unsupported setting '$key' "
                    . 'in initialization hash.';
                $kiwi -> error ($msg);
                $kiwi -> failed ();
                return;
            }
        }
        if (! $volInit->{name} ) {
            my $msg = 'createVolume: initialization data must contain '
                . 'value for "name".';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        if (! $this->__isNameValid($volInit->{name}, 'createVolume')) {
            return;
        }
        if (! $this->__nameIsUnique($volInit->{name}, 'createVolume')) {
            return;
        }
        if ($volInit->{mountpoint} ) {
            if (! $this->__nameIsUnique
                ($volInit->{mountpoint},'createVolume')
            ) {
                return;
            }
        }
        $this->{volumes}{$newID} = $volInit;
        return $newID;
    }
    if (! $this->__isNameValid($volInit, 'createVolume')) {
        return;
    }
    if (! $this->__nameIsUnique($volInit, 'createVolume')) {
        return;
    }
    my %newVol = ( name => $volInit );
    $this->{volumes}{$newID} = \%newVol;
    return $newID;
}

#==========================================
# getVGName
#------------------------------------------
sub getVGName {
    # ...
    # Return the configured name for the volume group
    # ---
    my $this = shift;
    return $this->{name};
}

#==========================================
# getLVMVolumeManagement
#------------------------------------------
sub getLVMVolumeManagement {
    # ...
    # Return the configured boolean value to prefer LVM or not
    # ---
    my $this = shift;
    if ($this->{preferlvm} eq 'false') {
        return 0;
    }
    return 1;
}

#==========================================
# getVolumeFreespace
#------------------------------------------
sub getVolumeFreespace {
    # ...
    # Return the configured freespace for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    if (! $this->__isVolIDValid($id, 'getVolumeFreespace')) {
        return;
    }
    return $this->{volumes}{$id}{freespace};
}

#==========================================
# getVolumeIDs
#------------------------------------------
sub getVolumeIDs {
    # ...
    # Return an array ref of the IDs for defined volumes
    # ---
    my $this = shift;
    my @ids = sort keys %{$this->{volumes}};
    return \@ids;
}

#==========================================
# getVolumeName
#------------------------------------------
sub getVolumeName {
    # ...
    # Return the configured name for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    if (! $this->__isVolIDValid($id, 'getVolumeName')) {
        return;
    }
    return $this->{volumes}{$id}{name};
}

#==========================================
# getVolumeMountPoint
#------------------------------------------
sub getVolumeMountPoint {
    # ...
    # Return the configured mountpoint for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    if (! $this->__isVolIDValid($id, 'getVolumeMountPoint')) {
        return;
        }
        return $this->{volumes}{$id}{mountpoint};
}

#==========================================
# getVolumeSize
#------------------------------------------
sub getVolumeSize {
    # ...
    # Return the configured name for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    if (! $this->__isVolIDValid($id, 'getVolumeSize')) {
        return;
    }
    return $this->{volumes}{$id}{size};
}

#==========================================
# getVolumes
#------------------------------------------
sub getVolumes {
    # ...
    # Return a hash with the volume path as key and a list
    # reference containing two elements with size information
    # and one element with an optional mountpoint name
    # ---
    my $this = shift;
    my $volIDs = $this -> getVolumeIDs();
    my %lvmparts;
    if ($volIDs) {
        foreach my $id (@{$volIDs}) {
            my $name = $this -> getVolumeName ($id);
            my $mount= $this -> getVolumeMountPoint ($id);
            my $free = $this -> getVolumeFreespace ($id);
            my $size = $this -> getVolumeSize ($id);
            my $haveAbsolute;
            my $usedValue;
            if ($size) {
                # got absolute size value
                $haveAbsolute = 1;
                $usedValue = $size;
            } elsif ($free) {
                # got free space definition
                $usedValue = $free;
                $haveAbsolute = 0;
            } else {
                # add default freespace as default
                my $global = KIWIGlobals -> instance();
                my $gdata  = $global -> getKiwiConfig();
                $usedValue = $gdata->{VolumeFree};
                $haveAbsolute = 0;
            }
            if (($usedValue) && ($usedValue =~ /(\d+)([MG]*)/sxm)) {
                my $byte = int $1;
                my $unit = $2;
                if ($unit eq "G") {
                    $usedValue = $byte * $NEXT_UNIT;
                } else {
                    # no or unknown unit, assume MB...
                    $usedValue = $byte;
                }
            }
            $name =~ s/\s+//gsxm;
            if ($name eq q{/}) {
                next;
            }
            $name =~ s/^\///sxm;
            $name =~ s/\//_/gsxm;
            if ($mount) {
                # if a mountpoint is set the following applies:
                # --> volume path is $mount
                # --> volume name is $name
                $lvmparts{$mount} = [ $usedValue,$haveAbsolute,$name ];
            } else {
                # if no mountpoint is set the following applies:
                # --> volume path is $name
                # --> volume name is $name
                $lvmparts{$name} = [ $usedValue,$haveAbsolute ];
            }
        }
    }
    return \%lvmparts;
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
    # ...
    # Return an XML Element representing the object's data
    # ---
    my $this = shift;
    my $element = XML::LibXML::Element -> new('systemdisk');
    $element -> setAttribute('name',
        $this -> getVGName()
    );
    my $preferlvm = $this -> getLVMVolumeManagement();
    if ($preferlvm == 0) {
        $preferlvm = 'false';
    } else {
        $preferlvm = 'true';
    }
    $element -> setAttribute('preferlvm',$preferlvm);
    my @vIDs = @{$this -> getVolumeIDs()};
    if (@vIDs) {
        for my $id (@vIDs) {
            my $vElem = XML::LibXML::Element -> new('volume');
            $vElem -> setAttribute('name', $this -> getVolumeName($id));
            my $mount = $this -> getVolumeMountPoint($id);
            if ($mount) {
                $vElem -> setAttribute('mountpoint',$mount);
            }
            my $free = $this -> getVolumeFreespace($id);
            if ($free) {
                $vElem -> setAttribute('freespace', $free);
            }
            my $size = $this -> getVolumeSize($id);
            if ($size) {
                $vElem -> setAttribute('size', $size);
            }
            $element -> appendChild($vElem);
        }
    }
    return $element;
}

#==========================================
# setVGName
#------------------------------------------
sub setVGName {
    # ...
    # Set the name for the volume group
    # ---
    my $this = shift;
    my $name = shift;
    my $kiwi = $this->{kiwi};
    if (! $name) {
        my $msg = 'setVGName: no volume group name argument provided, '
            . 'retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $this->__isNameValid($name, 'setVGName')) {
        return;
    }
    $this->{name} = $name;
    return $this;
}

#==========================================
# setLVMVolumeManagement
#------------------------------------------
sub setLVMVolumeManagement {
    # ...
    # Set the boolean value to prefer LVM or not
    # ---
    my $this  = shift;
    my $value = shift;
    my %settings = (
        attr   => 'preferlvm',
        value  => $value,
        caller => 'setLVMVolumeManagement'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setVolumeFreespace
#------------------------------------------
sub setVolumeFreespace {
    # ...
    # Set the configured freespace for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    my $free = shift;
    my $kiwi = $this->{kiwi};
    if (! $this->{volumes} ) {
        my $msg = 'setVolumeFreespace: no volumes configured, call '
            . 'createVolume first.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $this->__isVolIDValid($id, 'setVolumeFreespace')) {
        return;
    }
    if (! $free) {
        my $msg = 'setVolumeFreespace: no setting for freespace provided, '
            . 'retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{volumes}{$id}{freespace} = $free;
    return $this;
}

#==========================================
# setVolumeName
#------------------------------------------
sub setVolumeName {
    # ...
    # Set the configured name for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    my $name = shift;
    my $kiwi = $this->{kiwi};
    if (! $this->{volumes} ) {
        my $msg = 'setVolumeName: no volumes configured, call '
            . 'createVolume first.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $this->__isVolIDValid($id, 'setVolumeName')) {
        return;
    }
    if (! $name) {
        my $msg = 'setVolumeName: no setting for name provided, '
            . 'retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $this->__isNameValid($name, 'setVolumeName')) {
        return;
    }
    $this->{volumes}{$id}{name} = $name;
    return $this;
}

#==========================================
# setVolumeMountPoint
#------------------------------------------
sub setVolumeMountPoint {
    # ...
    # Set the configured mountpoint for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    my $mount= shift;
    my $kiwi = $this->{kiwi};
    if (! $this->{volumes} ) {
        my $msg = 'setVolumeMountPoint: no volumes configured, call '
            . 'createVolume first.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $this->__isVolIDValid($id, 'setVolumeMountPoint')) {
        return;
    }
    if (! $mount) {
        my $msg = 'setVolumeMountPoint: no setting for mountpoint provided, '
            . 'retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{volumes}{$id}{mountpoint} = $mount;
    return $this;
}

#==========================================
# setVolumeSize
#------------------------------------------
sub setVolumeSize {
    # ...
    # Set the configured freespace for the volume with the given ID
    # ---
    my $this = shift;
    my $id   = shift;
    my $size = shift;
    my $kiwi = $this->{kiwi};
    if (! $this->{volumes} ) {
        my $msg = 'setVolumeSize: no volumes configured, call '
            . 'createVolume first.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! $this->__isVolIDValid($id, 'setVolumeSize')) {
        return;
    }
    if (! $size) {
        my $msg = 'setVolumeSize: no setting for size provided, '
            . 'retaining current data.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this->{volumes}{$id}{size} = $size;
    return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
    # ...
    # Verify that the initialization hash given to the constructor meets
    # all consistency and data criteria.
    # ---
    my $this = shift;
    my $init = shift;
    my $kiwi = $this->{kiwi};
    my %suppoetedVolAttrs = (
        freespace => 1,
        name      => 1,
        size      => 1,
        mountpoint=> 1
    );
    if (! $init->{volumes}) {
        return 1;
    }
    if (ref($init->{volumes}) ne 'HASH' ) {
        my $msg = 'Expecting hash ref as entry for "volumes" in '
            . 'initialization structure.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my %usedNames = ();
    for my $id (keys %{$init->{volumes}}) {
        if (! looks_like_number($id) ) {
            my $msg = 'Expecting integer as key for "volumes" '
                . 'initialization.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        for my $entry (keys %{$init->{volumes}{$id}}) {
            if (! $suppoetedVolAttrs{$entry} ) {
                my $msg = 'Unsupported option in initialization structure '
                    . "for 'volumes', found '$entry'";
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
            if (! $init->{volumes}{$id}{name} ) {
                my $msg = 'Initialization data for "volumes" is '
                    . 'incomplete, missing "name" entry.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
            if (! $this->__isNameValid(
                $init->{volumes}{$id}{name},'object initialization')) {
                return;
            }
        }
        my $vName = $init->{volumes}{$id}{name};
        if ( $usedNames{$init->{volumes}{$id}{name}} ) {
            my $msg = 'Duplicate volume name in initialization '
                . 'structure, ambiguous operation.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        $usedNames{$init->{volumes}{$id}{name}} = 1;
    }
    return 1;
}

#==========================================
# __isNameValid
#------------------------------------------
sub __isNameValid {
    # ...
    # Verify that the name given for a volume or volume group is valid.
    # ---
    my $this   = shift;
    my $name   = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isNameValid called without call origin '
            . 'argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
        return;
    }
    if (! $name ) {
        my $msg = 'Internal error __isNameValid called without name '
            . 'argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
        return;
    }
    if ($name !~ /^[A-Za-z0-9_\+\.][A-Za-z0-9_\/\+\-]*$|^\@root$/smx) {
        my $msg = "$caller: improper volume name found.";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if ($name
        =~ /^(image|proc|sys|dev|boot|mnt|lib|bin|sbin|etc)$/smx) {
        my $msg = "$caller: found disallowed name '$name'.";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}


#==========================================
# __isVolIDValid
#------------------------------------------
sub __isVolIDValid {
    # ...
    # Verify that the ID given for a volume is valid.
    # ---
    my $this   = shift;
    my $id     = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __isVolIDValid called without call origin '
            . 'argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $id ) {
        my $msg = "$caller: called without providing ID for volume data.";
        $kiwi -> error($msg);
        $kiwi -> failed ();
        return;
    }
    $id = int $id;
    if (! $this->{volumes}{$id} ) {
        my $msg = "$caller: invalid ID for volume data access given, no "
            . 'data exists.';
        $kiwi -> error($msg);
        $kiwi -> failed ();
        return;
    }
    return 1;
}

#==========================================
# __nameIsUnique
#------------------------------------------
sub __nameIsUnique {
    # ..
    # Verify that the name for a volume is unique
    # ---
    my $this   = shift;
    my $name   = shift;
    my $caller = shift;
    my $kiwi = $this->{kiwi};
    if (! $caller ) {
        my $msg = 'Internal error __nameIsUnique called without call origin '
            . 'argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
    }
    if (! $name ) {
        my $msg = 'Internal error __nameIsUnique called without name '
            . 'argument.';
        $kiwi -> info($msg);
        $kiwi -> oops();
        return 1;
    }
    if ($this->{volumes}) {
        for my $volInfo (values %{$this->{volumes}}) {
            if ($volInfo->{name} eq $name) {
                my $msg = "$caller: volume definition for name '$name' "
                    . 'already exists, ambiguous operation.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

1;
