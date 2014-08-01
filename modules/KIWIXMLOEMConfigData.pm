#================
# FILE          : KIWIXMLOEMConfigData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <oemconfig> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLOEMConfigData;
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
    # Create the KIWIXMLOEMConfigData object
    #
    # Internal data structure
    #
    # this = {
    #    oem_ataraid_scan         = ''
    #    oen_multipath_scan       = ''
    #    oem_boot_title           = ''
    #    oem_bootwait             = ''
    #    oem_inplace_recovery     = ''
    #    oem_kiwi_initrd          = ''
    #    oem_partition_install    = ''
    #    oem_reboot               = ''
    #    oem_reboot_interactive   = ''
    #    oem_recovery             = ''
    #    oem_recoveryID           = ''
    #    oem_recoveryPartSize     = ''
    #    oem_shutdown             = ''
    #    oem_shutdown_interactive = ''
    #    oem_silent_boot          = ''
    #    oem_silent_install       = ''
    #    oem_silent_verify        = ''
    #    oem_skip_verify          = ''
    #    oem_swap                 = ''
    #    oem_swapsize             = ''
    #    oem_systemsize           = ''
    #    oem_unattended           = ''
    #    oem_unattended_id        = ''
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
        oem_ataraid_scan
        oem_multipath_scan
        oem_boot_title
        oem_bootwait
        oem_inplace_recovery
        oem_kiwi_initrd
        oem_partition_install
        oem_reboot
        oem_reboot_interactive
        oem_recovery
        oem_recoveryID
        oem_recoveryPartSize
        oem_shutdown
        oem_shutdown_interactive
        oem_silent_boot
        oem_silent_install
        oem_silent_verify
        oem_skip_verify
        oem_swap
        oem_swapsize
        oem_systemsize
        oem_unattended
        oem_unattended_id
    );
    $this->{supportedKeywords} = \%keywords;
    my %boolKW = map { ($_ => 1) } qw(
        oem_ataraid_scan
        oem_multipath_scan
        oem_bootwait
        oem_inplace_recovery
        oem_kiwi_initrd
        oem_partition_install
        oem_reboot
        oem_reboot_interactive
        oem_recovery
        oem_shutdown
        oem_shutdown_interactive
        oem_silent_boot
        oem_silent_install
        oem_silent_verify
        oem_skip_verify
        oem_swap
        oem_unattended
    );
    $this->{boolKeywords} = \%boolKW;
    if (! $this -> p_isInitHashRef($init) ) {
        return;
    }
    if (! $this -> p_areKeywordArgsValid($init) ) {
        return;
    }
    if ($init) {
        if (! $this -> __isInitConsistent($init) )  {
            return;
        }
        $this -> p_initializeBoolMembers($init);
        $this->{oem_boot_title}    = $init->{oem_boot_title};
        $this->{oem_recoveryID}    = $init->{oem_recoveryID};
        $this->{oem_recoveryPartSize} = $init->{oem_recoveryPartSize};
        $this->{oem_swapsize}      = $init->{oem_swapsize};
        $this->{oem_systemsize}    = $init->{oem_systemsize};
        $this->{oem_unattended_id} = $init->{oem_unattended_id};
    }
    return $this;
}

#==========================================
# getDataReport
#------------------------------------------
sub getDataReport {
    # ...
    # return a hash with OEM keys set to a value
    # ---
    my $this = shift;
    my %result ;
    foreach my $key (keys %{$this}) {
        my $value = $this->{$key};
        next if ref $value;
        if (defined $value) {
            $result{$key} = $value;
        }
    }
    return \%result;
}

#==========================================
# getAtaRaidScan
#------------------------------------------
sub getAtaRaidScan {
    # ...
    # Return the setting for the oem-ataraid-scan configuration
    # ---
    my $this = shift;
    return $this->{oem_ataraid_scan};
}

#==========================================
# getMultipathScan
#------------------------------------------
sub getMultipathScan {
    # ...
    # Return the setting for the oem-multipath-scan configuration
    # ---
    my $this = shift;
    return $this->{oem_multipath_scan};
}

#==========================================
# getBootTitle
#------------------------------------------
sub getBootTitle {
    # ...
    # Return the setting for the oem-boot-title configuration
    # ---
    my $this = shift;
    return $this->{oem_boot_title};
}

#==========================================
# getBootwait
#------------------------------------------
sub getBootwait {
    # ...
    # Return the setting for the oem-bootwait configuration
    # ---
    my $this = shift;
    return $this->{oem_bootwait};
}

#==========================================
# getInplaceRecovery
#------------------------------------------
sub getInplaceRecovery {
    # ...
    # Return the setting for the oem-inplace-recovery configuration
    # ---
    my $this = shift;
    return $this->{oem_inplace_recovery};
}

#==========================================
# getKiwiInitrd
#------------------------------------------
sub getKiwiInitrd {
    # ...
    # Return the setting for the oem-kiwi-initrd configuration
    # ---
    my $this = shift;
    return $this->{oem_kiwi_initrd};
}

#==========================================
# getPartitionInstall
#------------------------------------------
sub getPartitionInstall {
    # ...
    # Return the setting for the oem-partition-install configuration
    # ---
    my $this = shift;
    return $this->{oem_partition_install};
}

#==========================================
# getReboot
#------------------------------------------
sub getReboot {
    # ...
    # Return the setting for the oem-reboot configuration
    # ---
    my $this = shift;
    return $this->{oem_reboot};
}

#==========================================
# getRebootInteractive
#------------------------------------------
sub getRebootInteractive {
    # ...
    # Return the setting for the oem-reboot-interactive configuration
    # ---
    my $this = shift;
    return $this->{oem_reboot_interactive};
}

#==========================================
# getRecovery
#------------------------------------------
sub getRecovery {
    # ...
    # Return the setting for the oem-recovery configuration
    # ---
    my $this = shift;
    return $this->{oem_recovery};
}

#==========================================
# getRecoveryID
#------------------------------------------
sub getRecoveryID {
    # ...
    # Return the setting for the oem-recoveryID configuration
    # ---
    my $this = shift;
    return $this->{oem_recoveryID};
}

#==========================================
# getRecoveryPartSize
#------------------------------------------
sub getRecoveryPartSize {
    my $this = shift;
    return $this->{oem_recoveryPartSize};
}

#==========================================
# getShutdown
#------------------------------------------
sub getShutdown {
    # ...
    # Return the setting for the oem-shutdown configuration
    # ---
    my $this = shift;
    return $this->{oem_shutdown};
}

#==========================================
# getShutdownInteractive
#------------------------------------------
sub getShutdownInteractive {
    # ...
    # Return the setting for the oem-shutdown-interactive configuration
    # ---
    my $this = shift;
    return $this->{oem_shutdown_interactive};
}

#==========================================
# getSilentBoot
#------------------------------------------
sub getSilentBoot {
    # ...
    # Return the setting for the oem-silent-boot configuration
    # ---
    my $this = shift;
    return $this->{oem_silent_boot};
}

#==========================================
# getSilentInstall
#------------------------------------------
sub getSilentInstall {
    # ...
    # Return the setting for the oem-silent-install configuration
    # ---
    my $this = shift;
    return $this->{oem_silent_install};
}

#==========================================
# getSilentVerify
#------------------------------------------
sub getSilentVerify {
    # ...
    # Return the setting for the oem-silent-verify configuration
    # ---
    my $this = shift;
    return $this->{oem_silent_verify};
}

#==========================================
# getSkipVerify
#------------------------------------------
sub getSkipVerify {
    # ...
    # Return the setting for the oem-skip-verify configuration
    # ---
    my $this = shift;
    return $this->{oem_skip_verify};
}

#==========================================
# getSwap
#------------------------------------------
sub getSwap {
    # ...
    # Return the setting for the oem-swap configuration
    # ---
    my $this = shift;
    return $this->{oem_swap};
}

#==========================================
# getSwapSize
#------------------------------------------
sub getSwapSize {
    # ...
    # Return the setting for the oem-swapsize configuration
    # ---
    my $this = shift;
    return $this->{oem_swapsize};
}

#==========================================
# getSystemSize
#------------------------------------------
sub getSystemSize {
    # ...
    # Return the setting for the oem-systemsize configuration
    # ---
    my $this = shift;
    return $this->{oem_systemsize};
}

#==========================================
# getUnattended
#------------------------------------------
sub getUnattended {
    # ...
    # Return the setting for the oem-unattended configuration
    # ---
    my $this = shift;
    return $this->{oem_unattended};
}

#==========================================
# getUnattendedID
#------------------------------------------
sub getUnattendedID {
    # ...
    # Return the setting for the oem-unattended-id configuration
    # ---
    my $this = shift;
    return $this->{oem_unattended_id};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
    # ...
    # Return an XML Element representing the object's data
    # ---
    my $this = shift;
    my $element = XML::LibXML::Element -> new('oemconfig');
    my %initAtaRaidScan = (
        parent    => $element,
        childName => 'oem-ataraid-scan',
        text      => $this -> getAtaRaidScan ()
    );
    $element = $this -> p_addElement(\%initAtaRaidScan);
    my %initMultipathScan = (
        parent    => $element,
        childName => 'oem-multipath-scan',
        text      => $this -> getMultipathScan ()
    );
    $element = $this -> p_addElement(\%initMultipathScan);
    my %initBootT = (
        parent    => $element,
        childName => 'oem-boot-title',
        text      => $this -> getBootTitle ()
    );
    $element = $this -> p_addElement(\%initBootT);
    my %initBootW = (
        parent    => $element,
        childName => 'oem-bootwait',
        text      => $this -> getBootwait ()
    );
    $element = $this -> p_addElement(\%initBootW);
    my %initInplRec = (
        parent    => $element,
        childName => 'oem-inplace-recovery',
        text      => $this -> getInplaceRecovery ()
    );
    $element = $this -> p_addElement(\%initInplRec);
    my %initKInit = (
        parent    => $element,
        childName => 'oem-kiwi-initrd',
        text      => $this -> getKiwiInitrd ()
    );
    $element = $this -> p_addElement(\%initKInit);
    my %initPartInst = (
        parent    => $element,
        childName => 'oem-partition-install',
        text      => $this -> getPartitionInstall ()
    );
    $element = $this -> p_addElement(\%initPartInst);
    my %initReboot = (
        parent    => $element,
        childName => 'oem-reboot',
        text      => $this -> getReboot ()
    );
    $element = $this -> p_addElement(\%initReboot);
    my %initRebootInt = (
        parent    => $element,
        childName => 'oem-reboot-interactive',
        text      => $this -> getRebootInteractive ()
    );
    $element = $this -> p_addElement(\%initRebootInt);
    my %initRecover = (
        parent    => $element,
        childName => 'oem-recovery',
        text      => $this -> getRecovery ()
    );
    $element = $this -> p_addElement(\%initRecover);
    my %initRecoverID = (
        parent    => $element,
        childName => 'oem-recoveryID',
        text      => $this -> getRecoveryID ()
    );
    $element = $this -> p_addElement(\%initRecoverID);
    my $size = $this -> getRecoveryPartSize ();
    my %initRecoverPSize = (
        parent    => $element,
        childName => 'oem-recovery-part-size',
        text      => $this -> getRecoveryPartSize ()
    );
    $element = $this -> p_addElement(\%initRecoverPSize);
    my %initDown = (
        parent    => $element,
        childName => 'oem-shutdown',
        text      => $this -> getShutdown ()
    );
    $element = $this -> p_addElement(\%initDown);
    my %initDownInter = (
        parent    => $element,
        childName => 'oem-shutdown-interactive',
        text      => $this -> getShutdownInteractive ()
    );
    $element = $this -> p_addElement(\%initDownInter);
    my %initSBoot = (
        parent    => $element,
        childName => 'oem-silent-boot',
        text      => $this -> getSilentBoot ()
    );
    $element = $this -> p_addElement(\%initSBoot);
    my %initSInst = (
        parent    => $element,
        childName => 'oem-silent-install',
        text      => $this -> getSilentInstall ()
    );
    $element = $this -> p_addElement(\%initSInst);
    my %initSVerify = (
        parent    => $element,
        childName => 'oem-silent-verify',
        text      => $this -> getSilentVerify ()
    );
    $element = $this -> p_addElement(\%initSVerify);
    my %initSSkip = (
        parent    => $element,
        childName => 'oem-skip-verify',
        text      => $this -> getSkipVerify ()
    );
    $element = $this -> p_addElement(\%initSSkip);
    my %initSwap = (
        parent    => $element,
        childName => 'oem-swap',
        text      => $this -> getSwap ()
    );
    $element = $this -> p_addElement(\%initSwap);
    my %initSwapS = (
        parent    => $element,
        childName => 'oem-swapsize',
        text      => $this -> getSwapSize ()
    );
    $element = $this -> p_addElement(\%initSwapS);
    my %initSysSize = (
        parent    => $element,
        childName => 'oem-systemsize',
        text      => $this -> getSystemSize ()
    );
    $element = $this -> p_addElement(\%initSysSize);
    my %initUnat = (
        parent    => $element,
        childName => 'oem-unattended',
        text      => $this -> getUnattended ()
    );
    $element = $this -> p_addElement(\%initUnat);
    my %initUnatID = (
        parent    => $element,
        childName => 'oem-unattended-id',
        text      => $this -> getUnattendedID ()
    );
    $element = $this -> p_addElement(\%initUnatID);
    return $element;
}

#==========================================
# setAtaRaidScan
#------------------------------------------
sub setAtaRaidScan {
    # ...
    # Set the oem_ataraid_scan attribute, if called with no argument the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_ataraid_scan',
        value  => $val,
        caller => 'setAtaRaidScan'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setMultipathScan
#------------------------------------------
sub setMultipathScan {
    # ...
    # Set the oem_multipath_scan attribute, if called with no argument the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_multipath_scan',
        value  => $val,
        caller => 'setMultipathScan'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setBootTitle
#------------------------------------------
sub setBootTitle {
    # ...
    # Set the oem_boot_title attribute, if called with no argument the
    # attribute is erased
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        if ($this->{oem_boot_title}) {
            delete $this->{oem_boot_title};
        }
    } else {
        $this->{oem_boot_title} = $val;
    }
    return $this;
}

#==========================================
# setBootwait
#------------------------------------------
sub setBootwait {
    # ...
    # Set the oem_bootwait attribute, if called with no argument the
    # value is set to false. If called with an argument all other potentially
    # conflicting settings are set to false
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_bootwait',
        value  => $val,
        caller => 'setBootwait'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if ($this->{oem_bootwait} && $this->{oem_bootwait} eq 'true' ) {
        delete $this->{oem_reboot};
        delete $this->{oem_reboot_interactive};
        delete $this->{oem_shutdown};
        delete $this->{oem_shutdown_interactive};
    }
    return $this;
}

#==========================================
# setInplaceRecovery
#------------------------------------------
sub setInplaceRecovery {
    # ...
    # Set the oem_inplace_recovery attribute, if called with no argument the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_inplace_recovery',
        value  => $val,
        caller => 'setInplaceRecovery'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setKiwiInitrd
#------------------------------------------
sub setKiwiInitrd {
    # ...
    # Set the oem_kiwi_initrd attribute, if called with no argument is given the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_kiwi_initrd',
        value  => $val,
        caller => 'setKiwiInitrd'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setPartitionInstall
#------------------------------------------
sub setPartitionInstall {
    # ...
    # Set the oem_partition_install attribute, if called with no argument is given the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_partition_install',
        value  => $val,
        caller => 'setPartitionInstall'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setReboot
#------------------------------------------
sub setReboot {
    # ...
    # Set the reboot attribute, if called with no argument the
    # value is set to false. If called with an argument all other potentially
    # conflicting settings are set to false
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_reboot',
        value  => $val,
        caller => 'setReboot'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if ($this->{oem_reboot} && $this->{oem_reboot} eq 'true') {
        delete $this->{oem_bootwait};
        delete $this->{oem_reboot_interactive};
        delete $this->{oem_shutdown};
        delete $this->{oem_shutdown_interactive};
    }
    return $this;
}

#==========================================
# setRebootInteractive
#------------------------------------------
sub setRebootInteractive {
    # ...
    # Set the oem_reboot_interactive attribute, if called with no argument the
    # value is set to false. If called with an argument all other potentially
    # conflicting settings are set to false
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_reboot_interactive',
        value  => $val,
        caller => 'setRebootInteractive'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if (($this->{oem_reboot_interactive}) &&
        ($this->{oem_reboot_interactive} eq 'true')
    ) {
        delete $this->{oem_bootwait};
        delete $this->{oem_reboot};
        delete $this->{oem_shutdown};
        delete $this->{oem_shutdown_interactive};
    }
    return $this;
}

#==========================================
# setRecovery
#------------------------------------------
sub setRecovery {
    # ...
    # Set the recovery attribute, if called with no argument the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_recovery',
        value  => $val,
        caller => 'setRecovery'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setRecoveryID
#------------------------------------------
sub setRecoveryID {
    # ...
    # Set the recoveryID attribute, if called with no argument the
    # attribute is removed
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        delete $this->{oem_recoveryID};
    } else {
        if ($val =~ /[0-9A-Fa-f]{2}/smx) {
            $this->{oem_recoveryID} = $val;
        } else {
            my $kiwi = $this -> {kiwi};
            my $msg = 'The recovery partition ID must be 2 digit hex value';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        
    }
    return $this;
}

#==========================================
# setRecvoveryPartitionSize
#------------------------------------------
sub setRecoveryPartSize {
    # ...
    # Set the recovery partition size attribute, if called
    # with no argument the attribute is removed.
    # Argument is expected to be a string or numeric value
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        delete $this->{oem_recoveryPartSize};
    } else {
        if (looks_like_number($val)) {
            $val = "$val";
        }
        if ($val =~ /\D/smx) {
            my $kiwi = $this -> {kiwi};
            my $msg = 'The recovery partition size must be an integer value';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        $this->{oem_recoveryPartSize} = $val;
    }
    return $this;
}

#==========================================
# setShutdown
#------------------------------------------
sub setShutdown {
    # ...
    # Set the shutdown attribute, if called with no argument the
    # value is set to false. If called with an argument all other potentially
    # conflicting settings are set to false
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_shutdown',
        value  => $val,
        caller => 'setShutdown'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if ($this->{oem_shutdown} && $this->{oem_shutdown} eq 'true') {
        delete $this->{oem_bootwait};
        delete $this->{oem_reboot};
        delete $this->{oem_reboot_interactive};
        delete $this->{oem_shutdown_interactive};
    }
    return $this;
}

#==========================================
# setShutdownInteractive
#------------------------------------------
sub setShutdownInteractive {
    # ...
    # Set the oem_shutdown_interactive attribute, if called with no argument the
    # value is set to false. If called with an argument all other potentially
    # conflicting settings are set to false
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_shutdown_interactive',
        value  => $val,
        caller => 'setShutdownInteractive'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if ($this->{oem_shutdown_interactive}
        && $this->{oem_shutdown_interactive} eq 'true') {
        delete $this->{oem_bootwait};
        delete $this->{oem_reboot};
        delete $this->{oem_reboot_interactive};
        delete $this->{oem_shutdown};
    }
    return $this;
}

#==========================================
# setSilentBoot
#------------------------------------------
sub setSilentBoot {
    # ...
    # Set the oem_silent_boot attribute, if called with no argument the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_silent_boot',
        value  => $val,
        caller => 'setSilentBoot'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setSilentInstall
#------------------------------------------
sub setSilentInstall {
    # ...
    # Set the oem_silent_install attribute, if called with no argument the
    # value is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_silent_install',
        value  => $val,
        caller => 'setSilentInstall'
    );
    return $this -> p_setBooleanValue(\%settings);
}

#==========================================
# setSilentVerify
#------------------------------------------
sub setSilentVerify {
    # ...
    # Set the oem_silent_verify attribute, if called with no argument the
    # value is set to false. If called with an argument all other potentially
    # conflicting settings are set to false
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_silent_verify',
        value  => $val,
        caller => 'setSilentVerify'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if ($this->{oem_silent_verify} && $this->{oem_silent_verify} eq 'true' ) {
        delete $this->{oem_skip_verify};
    }
    return $this;
}

#==========================================
# setSkipVerify
#------------------------------------------
sub setSkipVerify {
    # ...
    # Set the oem_skip_verify attribute, if called with no argument the
    # value is set to false. If called with an argument all other potentially
    # conflicting settings are set to false
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_skip_verify',
        value  => $val,
        caller => 'setSkipVerify'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if ($this->{oem_skip_verify} && $this->{oem_skip_verify} eq 'true' ) {
        delete $this->{oem_silent_verify};
    }
    return $this;
}

#==========================================
# setSwap
#------------------------------------------
sub setSwap {
    # ...
    # Set the swap attribute, if called with no argument the
    # value is set to false and the swapsize attribute is removed
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_swap',
        value  => $val,
        caller => 'setSwap'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if (! $val || $val eq 'false') {
        delete $this->{oem_swapsize}
    }
    return $this;
}

#==========================================
# setSwapSize
#------------------------------------------
sub setSwapSize {
    # ...
    # Set the oem_swapsize attribute, if called with no argument the
    # attribute is removed and the swap attribute is set to false
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        delete $this->{oem_swap};
        delete $this->{oem_swapsize}
    } else {
        $this->{oem_swapsize} = $val;
        $this->{oem_swap}     = 'true';
    }
    return $this;
}

#==========================================
# setSystemSize
#------------------------------------------
sub setSystemSize {
    # ...
    # Set the oem_systemsize attribute, if called with no argument the
    # attribute is removed
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        delete $this->{oem_systemsize};
    } else {
        $this->{oem_systemsize} = $val;
    }
    return $this;
}

#==========================================
# setUnattended
#------------------------------------------
sub setUnattended {
    # ...
    # Set the unattended attribute, if called with no argument the
    # value is set to false the oem_unattended_id attribute is removed
    # ---
    my $this = shift;
    my $val  = shift;
    my %settings = (
        attr   => 'oem_unattended',
        value  => $val,
        caller => 'setUnattended'
    );
    if (! $this -> p_setBooleanValue(\%settings) ) {
        return;
    }
    if (! $val || $val eq 'false') {
        if ($this->{oem_unattended_id}) {
            delete $this->{oem_unattended_id};
        }
    }
    return $this;
}

#==========================================
# setUnattendedID
#------------------------------------------
sub setUnattendedID {
    # ...
    # Set the oem_unattended_id attribute, if called with no argument the
    # attribute is removed and the unattended attribute is set to false.
    # ---
    my $this = shift;
    my $val  = shift;
    if (! $val) {
        delete $this->{oem_unattended_id};
        delete $this->{oem_unattended};
    } else {
        $this->{oem_unattended_id} = $val;
    }
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
    # Verify initialization consistency and validity requirements
    # ---
    my $this = shift;
    my $init = shift;
    if (! $this -> p_areKeywordBooleanValuesValid($init) ) {
        return;
    }
    if (! $this -> __noConflictingSettingPostInst($init)) {
        return;
    }
    if (! $this -> __noConflictingSettingSwap($init)) {
        return;
    }
    if (! $this -> __noConflictingSettingUnattended($init)) {
        return;
    }
    if (! $this -> __noConflictingSettingVerify($init)) {
        return;
    }
    return $this;
}
        
#==========================================
# __noConflictingSetting
#------------------------------------------
sub __noConflictingSettingPostInst {
    # ...
    # Verify that the post install option settings to not conflict
    # ---
    my $this = shift;
    my $init = shift;
    my @potConflict = qw(
        oem_bootwait oem_reboot oem_reboot_interactive
        oem_shutdown oem_shutdown_interactive
    );
    my $found = 0;
    for my $setting (@potConflict) {
        if ($init->{$setting} && $init->{$setting} ne 'false') {
            $found += 1;
        }
        if ($found > 1) {
            my $kiwi = $this -> {kiwi};
            my $msg = 'Conflicting post-install settings only one of '
                . "'@potConflict' may be set.";
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __noConflictingSettingSwap
#------------------------------------------
sub __noConflictingSettingSwap {
    # ...
    # Verify that the swap settings (swap and swapsize) do not conflict
    # ---
    my $this = shift;
    my $init = shift;
    if ($init->{oem_swapsize}) {
        if (! $init->{oem_swap} || $init->{oem_swap} eq 'false') {
            my $kiwi = $this -> {kiwi};
            my $msg = 'Conflicting swap settings, specified swap size, but '
                . 'swap is disabled.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __noConflictingSettingUnattended
#------------------------------------------
sub __noConflictingSettingUnattended  {
    # ...
    # Verify that the settings for unattended install do not conflict
    # ---
    my $this = shift;
    my $init = shift;
    if ($init->{oem_unattended_id}) {
        if (! $init->{oem_unattended}
            || $init->{oem_unattended}  eq 'false') {
            my $kiwi = $this -> {kiwi};
            my $msg = 'Conflicting unattended install settings, specified '
                . 'unattended target ID but unattended install is disabled.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __noConflictingSettingVerify
#------------------------------------------
sub __noConflictingSettingVerify {
    # ...
    # Verify that the settings for image verification do not conflict
    # ---
    my $this = shift;
    my $init = shift;
    if ($init->{oem_skip_verify} && $init->{oem_skip_verify} eq 'true') {
        if ($init->{oem_silent_verify}
            && $init->{oem_silent_verify} eq 'true') {
            my $kiwi = $this -> {kiwi};
            my $msg = 'Ambiguous install verification settings, install '
                . 'verification is disabled, but also expected silently '
                . 'unable to resolve ambiguity.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

1;
