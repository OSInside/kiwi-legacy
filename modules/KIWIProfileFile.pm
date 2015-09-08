#================
# FILE          : KIWIProfileFile.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This class collects all data needed to create the .profile
#               : file from the XML.
#               :
# STATUS        : Development
#----------------
package KIWIProfileFile;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Readonly;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use FileHandle;
use KIWIXML;
use KIWIXMLOEMConfigData;
use KIWIXMLPreferenceData;
use KIWIXMLTypeData;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIProfileFile object
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Object data
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    my %supportedEntries = map { ($_ => 1) } qw(
        kiwi_align
        kiwi_allFreeVolume
        kiwi_bootloader
        kiwi_bootprofile
        kiwi_bootkernel
        kiwi_boot_timeout
        kiwi_cmdline
        kiwi_compressed
        kiwi_cpio_name
        kiwi_delete
        kiwi_devicepersistency
        kiwi_displayname
        kiwi_drivers
        kiwi_firmware
        kiwi_fsmountoptions
        kiwi_hwclock
        kiwi_hybrid
        kiwi_hybridpersistent
        kiwi_hybridpersistent_filesystem
        kiwi_iname
        kiwi_installboot
        kiwi_iversion
        kiwi_keytable
        kiwi_language
        kiwi_loader_theme
        kiwi_lvm
        kiwi_lvmgroup
        kiwi_oemataraid_scan
        kiwi_oemvmcp_parmfile
        kiwi_oemmultipath_scan
        kiwi_oembootwait
        kiwi_oemkboot
        kiwi_oempartition_install
        kiwi_oemreboot
        kiwi_oemrebootinteractive
        kiwi_oemrecovery
        kiwi_oemrecoveryID
        kiwi_oemrecoveryInPlace
        kiwi_oemrecoveryPartSize
        kiwi_oemrootMB
        kiwi_oemshutdown
        kiwi_oemshutdowninteractive
        kiwi_oemsilentboot
        kiwi_oemsilentinstall
        kiwi_oemsilentverify
        kiwi_oemskipverify
        kiwi_oemswap
        kiwi_oemswapMB
        kiwi_oemdevicefilter
        kiwi_oemtitle
        kiwi_oemunattended
        kiwi_oemunattended_id
        kiwi_profiles
        kiwi_ramonly
        kiwi_target_blocksize
        kiwi_revision
        kiwi_showlicense
        kiwi_splash_theme
        kiwi_startsector
        kiwi_sectorsize
        kiwi_strip_delete
        kiwi_strip_libs
        kiwi_strip_tools
        kiwi_testing
        kiwi_timezone
        kiwi_type
        kiwi_vga
        kiwi_wwid_wait_timeout
        kiwi_xendomain
    );
    #==========================================
    # Store member data
    #------------------------------------------
    $this->{kiwi} = $kiwi;
    $this->{vars} = \%supportedEntries;
    return $this;
}

#==========================================
# addEntry
#------------------------------------------
sub addEntry {
    # ...
    # Add an entry to the profile data. If the value is empty
    # an existing entry will be deleted. the onus is on the
    # client to avoid duplicates in the data
    # ---
    my $this  = shift;
    my $key   = shift;
    my $value = shift;
    my $kiwi  = $this->{kiwi};
    if (! $key) {
        my $msg = 'addEntry: expecting a string as first argument';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if (! defined $value) {
        delete $this->{profile}{$key};
    }
    my %allowedVars = %{$this->{vars}};
    if ((! $allowedVars{$key}) &&
        ($key !~ /^kiwi_LVM_|^kiwi_allFreeVolume_/msx)
    ) {
        my $msg = "Unrecognized variable: $key";
        $kiwi -> warning ($msg);
        $kiwi -> skipped ();
        return $this;
    }
    if ($this->{profile}{$key}) {
        my $exist = $this->{profile}{$key};
        my $separator = q{ };
        if ($exist =~ /,/msx || $value =~ /,/msx) {
            $separator = q{,};
        }
        $this->{profile}{$key} = "$exist$separator$value";
    } else {
        $this->{profile}{$key} = $value;
    }
    return $this;
}

#==========================================
# updateFromCommandline
#------------------------------------------
sub updateFromCommandline {
    # ...
    # Update the existing data from a Commandline object.
    # the onus is on the client to avoid duplicates
    # in the data
    # ---
    my $this = shift;
    my $cmdL = shift;
    my $kiwi = $this->{kiwi};
    Readonly my $UNIT_MB => 1024;
    if (! $cmdL || ref($cmdL) ne 'KIWICommandLine') {
        my $msg = 'updateFromCommandline: expecting KIWICommandLine '.
            'object as first argument';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    #==========================================
    # kiwi_align
    #------------------------------------------
    my $align = $cmdL -> getDiskAlignment * $UNIT_MB;
    $this -> addEntry('kiwi_align', $align);
    #==========================================
    # kiwi_startsector
    #------------------------------------------
    my $start_sector = $cmdL -> getDiskStartSector();
    $this -> addEntry('kiwi_startsector', $start_sector);
    #==========================================
    # kiwi_sectorsize
    #------------------------------------------
    my $sector_size = $cmdL -> getDiskBIOSSectorSize();
    $this -> addEntry('kiwi_sectorsize', $sector_size);
    return $this;
}

#==========================================
# updateFromXML
#------------------------------------------
sub updateFromXML {
    # ...
    # Update the existing data from an XML object.
    # the onus is on the client to avoid duplicates
    # in the data
    # ---
    my $this = shift;
    my $xml  = shift;
    my $kiwi = $this->{kiwi};
    if (! $xml || ref($xml) ne 'KIWIXML') {
        my $msg = 'updateFromXML: expecting KIWIXML object as first argument';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $type = $xml -> getImageType() -> getTypeName();
    #==========================================
    # kiwi_profiles
    #------------------------------------------
    my $profiles = $xml -> getActiveProfileNames();
    if ($profiles) {
        $this -> addEntry('kiwi_profiles',join(q{,},@{$profiles}));
    }
    #==========================================
    # kiwi_delete
    #------------------------------------------
    my $delp = $xml -> getPackagesToDelete();
    if (@{$delp}) {
        my @items_delete;
        for my $package (@{$delp}) {
            my $name = $package -> getName();
            push @items_delete, $name;
        }
        $this -> addEntry('kiwi_delete',join(q{ },@items_delete));
    }
    #==========================================
    # kiwi_testing
    #------------------------------------------
    my $testsuite = $xml -> getTestSuitePackages();
    if (@{$testsuite}) {
        my @items_test;
        for my $package (@{$testsuite}) {
            my $name = $package -> getName();
            push @items_test, $name;
        }
        $this -> addEntry('kiwi_testing',join(q{ },@items_test));
    }
    #==========================================
    # kiwi_iname
    #------------------------------------------
    my $name  = $xml -> getImageName();
    if ($name) {
        $this -> addEntry('kiwi_iname',$name);
    }
    #==========================================
    # kiwi_cpio_name
    #------------------------------------------
    if ($type eq 'cpio') {
        $this -> addEntry('kiwi_cpio_name',$name);
    }
    #==========================================
    # kiwi_displayname
    #------------------------------------------
    my $dname = $xml -> getImageDisplayName ($xml);
    if ($dname) {
        $this -> addEntry('kiwi_displayname',quotemeta ($dname));
    }
    #==========================================
    # kiwi_drivers
    #------------------------------------------
    $this -> __updateXMLDrivers ($xml);
    #==========================================
    # kiwi_*
    #------------------------------------------
    $this -> __updateXMLSystemDisk ($xml);
    #==========================================
    # kiwi_xendomain
    #------------------------------------------
    $this -> __updateXMLMachine ($xml);
    #==========================================
    # kiwi_oem*
    #------------------------------------------
    $this -> __updateXMLOEMConfig ($xml);
    #==========================================
    # kiwi_strip*
    #------------------------------------------
    $this -> __updateXMLStrip ($xml);
    #==========================================
    # kiwi preferences variables
    #------------------------------------------
    $this -> __updateXMLPreferences ($xml);
    #==========================================
    # kiwi type variables
    #------------------------------------------
    $this -> __updateXMLType ($xml);
    return $this;
}

#==========================================
# writeProfile
#------------------------------------------
sub writeProfile {
    # ...
    # Write the profile data to the given path
    # ---
    my $this   = shift;
    my $target = shift;
    my $kiwi   = $this->{kiwi};
    my $msg    = 'KIWIProfileFile: ';
    if (!$target || ! -d $target) {
        $msg .= 'writeProfile expecting directory as argument';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if ($this->{profile}) {
        $this -> __storeRevisionInformation();
        my %profile = %{$this->{profile}};
        my $PROFILE = FileHandle -> new();
        if (! $PROFILE -> open (">$target/.profile")) {
            $msg .= "Could not open '$target/.profile' for writing";
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
        binmode ($PROFILE, ":encoding(UTF-8)");
        foreach my $key (sort keys %profile) {
            $kiwi -> loginfo ("[PROFILE]: $key=\"$profile{$key}\"\n");
            print $PROFILE "$key=\"$profile{$key}\"\n";
        }
        $PROFILE -> close();
        return 1;
    }
    $msg .= 'No data for profile file defined';
    $kiwi -> warning ($msg);
    $kiwi -> skipped ();
    return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __updateXMLType
#------------------------------------------
sub __updateXMLType {
    my $this = shift;
    my $xml  = shift;
    my $type = $xml -> getImageType();
    my %data;
    #==========================================
    # get profile type variables
    #------------------------------------------
    $data{kiwi_type} =
        $type -> getTypeName();
    $data{kiwi_compressed} =
        $type -> getCompressed();
    $data{kiwi_boot_timeout} =
        $type -> getBootTimeout();
    $data{kiwi_wwid_wait_timeout} =
        $type -> getWWIDWaitTimeout();
    $data{kiwi_hybrid} =
        $type -> getHybrid();
    $data{kiwi_hybridpersistent} =
        $type -> getHybridPersistent();
    $data{kiwi_hybridpersistent_filesystem} =
        $type -> getHybridPersistentFileSystem();
    $data{kiwi_ramonly} =
        $type -> getRAMOnly();
    $data{kiwi_target_blocksize} =
        $type -> getTargetBlockSize();
    $data{kiwi_cmdline} =
        $type -> getKernelCmdOpts();
    $data{kiwi_firmware} =
        $type -> getFirmwareType();
    $data{kiwi_bootloader} =
        $type -> getBootLoader();
    $data{kiwi_devicepersistency} =
        $type -> getDevicePersistent();
    $data{kiwi_installboot} =
        $type -> getInstallBoot();
    $data{kiwi_bootkernel} =
        $type -> getBootKernel();
    $data{kiwi_fsmountoptions} =
        $type -> getFSMountOptions();
    $data{kiwi_bootprofile} =
        $type -> getBootProfile();
    $data{kiwi_vga} =
        $type -> getVGA();
    #==========================================
    # store as profile variable
    #------------------------------------------
    foreach my $key (keys %data) {
        my $value = $data{$key};
        next if ! $value;
        next if ($value eq 'false');
        $this -> addEntry ($key,$value);
    }
    return $this;
}
#==========================================
# __updateXMLPreferences
#------------------------------------------
sub __updateXMLPreferences {
    my $this = shift;
    my $xml  = shift;
    my $pref = $xml -> getPreferences();
    #==========================================
    # kiwi_iversion
    #------------------------------------------
    my $iver = $pref -> getVersion();
    if ($iver) {
        $this -> addEntry('kiwi_iversion',$iver);
    }
    #==========================================
    # kiwi_showlicense
    #------------------------------------------
    my $lics = $pref -> getShowLic();
    if ($lics) {
        $this -> addEntry('kiwi_showlicense',"@{$lics}");
    }
    #==========================================
    # kiwi_keytable
    #------------------------------------------
    my $keytable = $pref -> getKeymap();
    if ($keytable) {
        $this -> addEntry('kiwi_keytable',$keytable);
    }
    #==========================================
    # kiwi_timezone
    #------------------------------------------
    my $timezone = $pref -> getTimezone();
    if ($timezone) {
        $this -> addEntry('kiwi_timezone',$timezone);
    }
    #==========================================
    # kiwi_hwclock
    #------------------------------------------
    my $hwclock = $pref -> getHWClock();
    if ($hwclock) {
        $this -> addEntry('kiwi_hwclock',$hwclock);
    }
    #==========================================
    # kiwi_language
    #------------------------------------------
    my $lang = $pref -> getLocale();
    if ($lang) {
        $this -> addEntry('kiwi_language',$lang);
    }
    #==========================================
    # kiwi_splash_theme
    #------------------------------------------
    my $splashtheme = $pref -> getBootSplashTheme();
    if ($splashtheme) {
        $this -> addEntry('kiwi_splash_theme',$splashtheme);
    }
    #==========================================
    # kiwi_loader_theme
    #------------------------------------------
    my $loadertheme = $pref -> getBootLoaderTheme();
    if ($loadertheme) {
        $this -> addEntry('kiwi_loader_theme',$loadertheme);
    }
    return $this;
}

#==========================================
# __updateXMLStrip
#------------------------------------------
sub __updateXMLStrip {
    my $this = shift;
    my $xml  = shift;
    my $s_delref = $xml -> getFilesToDelete();
    if ($s_delref) {
        my @s_del;
        foreach my $stripdata (@{$s_delref}) {
            push @s_del,$stripdata->getName();
        }
        if (@s_del) {
            $this -> addEntry('kiwi_strip_delete',join(q{ },@s_del));
        }
    }
    my $s_toolref = $xml -> getToolsToKeep();
    if ($s_toolref) {
        my @s_tool;
        foreach my $stripdata (@{$s_toolref}) {
            push @s_tool,$stripdata->getName();
        }
        if (@s_tool) {
            $this -> addEntry('kiwi_strip_tools',join(q{ },@s_tool));
        }
    }
    my $s_libref  = $xml -> getLibsToKeep();
    if ($s_libref) {
        my @s_lib;
        foreach my $stripdata (@{$s_libref}) {
            push @s_lib,$stripdata->getName();
        }
        if (@s_lib) {
            $this -> addEntry('kiwi_strip_libs',join(q{ },@s_lib));
        }
    }
    return $this;
}

#==========================================
# __updateXMLDrivers
#------------------------------------------
sub __updateXMLDrivers {
    my $this = shift;
    my $xml  = shift;
    my $drivers = $xml -> getDrivers();
    my @drvNames;
    for my $drv (@{$drivers}) {
        push @drvNames, $drv -> getName();
    }
    if (@drvNames) {
        my $addItem = join q{,}, @drvNames;
        $this -> addEntry('kiwi_drivers', $addItem);
    }
    return $this;
}

#==========================================
# __updateXMLSystemDisk
#------------------------------------------
sub __updateXMLSystemDisk {
    my $this = shift;
    my $xml  = shift;
    my $systemdisk = $xml -> getSystemDiskConfig();
    if ($systemdisk) {
        my $lvmgroup = $systemdisk -> getVGName();
        if ($lvmgroup) {
            $this -> addEntry('kiwi_lvmgroup',$lvmgroup);
        }
        my $type = $xml -> getImageType();
        if ($type) {
            if (KIWIGlobals -> instance() -> useLVM($xml)) {
                $this -> addEntry('kiwi_lvm','true');
            }
        }
        my $lvmparts = $systemdisk -> getVolumes();
        if ($lvmparts) {
            foreach my $vol (keys %{$lvmparts}) {
                if (! $lvmparts->{$vol}) {
                    next;
                }
                my $attrname = 'size';
                my $attrval  = $lvmparts->{$vol}->[0];
                my $absolute = $lvmparts->{$vol}->[1];
                my $lvname   = $lvmparts->{$vol}->[2];
                if (! $attrval) {
                    next;
                }
                if (! $absolute) {
                    $attrname = "freespace";
                }
                $vol = 'LV'.$vol;
                if ($vol eq 'LV@root') {
                    if ($attrval ne 'all') {
                        $this -> addEntry(
                            'kiwi_LVM_LVRoot', "$attrname:$attrval"
                        );
                    }
                } elsif ($attrval eq 'all') {
                    if ($lvname) {
                        $this -> addEntry(
                            "kiwi_allFreeVolume_$lvname", "size:all:$vol"
                        );
                    } else {
                        $this -> addEntry(
                            "kiwi_allFreeVolume_$vol", "size:all"
                        );
                    }
                } else {
                    if ($lvname) {
                        $this -> addEntry(
                            "kiwi_LVM_$lvname", "$attrname:$attrval:$vol"
                        );
                    } else {
                        $this -> addEntry(
                            "kiwi_LVM_$vol", "$attrname:$attrval"
                        );
                    }
                }
            }
        }
    }
    return $this;
}

#==========================================
# __updateXMLMachine
#------------------------------------------
sub __updateXMLMachine {
    my $this = shift;
    my $xml  = shift;
    my $vconf = $xml -> getVMachineConfig();
    if ($vconf) {
        my $domain = $vconf -> getDomain();
        if ($domain) {
            $this -> addEntry('kiwi_xendomain',$domain);
        }
    }
    return $this;
}

#==========================================
# __updateXMLOEMConfig
#------------------------------------------
sub __updateXMLOEMConfig {
    my $this = shift;
    my $xml  = shift; 
    my $oemconf = $xml -> getOEMConfig();
    my %oem;
    if ($oemconf) {
        $oem{kiwi_oemataraid_scan}       = $oemconf -> getAtaRaidScan();
        $oem{kiwi_oemvmcp_parmfile}      = $oemconf -> getVmcpParmFile();
        $oem{kiwi_oemmultipath_scan}     = $oemconf -> getMultipathScan();
        $oem{kiwi_oemswapMB}             = $oemconf -> getSwapSize();
        $oem{kiwi_oemrootMB}             = $oemconf -> getSystemSize();
        $oem{kiwi_oemswap}               = $oemconf -> getSwap();
        $oem{kiwi_oempartition_install}  = $oemconf -> getPartitionInstall();
        $oem{kiwi_oemdevicefilter}       = $oemconf -> getDeviceFilter();
        $oem{kiwi_oemtitle}              = $oemconf -> getBootTitle();
        $oem{kiwi_oemkboot}              = $oemconf -> getKiwiInitrd();
        $oem{kiwi_oemreboot}             = $oemconf -> getReboot();
        $oem{kiwi_oemrebootinteractive}  = $oemconf -> getRebootInteractive();
        $oem{kiwi_oemshutdown}           = $oemconf -> getShutdown();
        $oem{kiwi_oemshutdowninteractive}= $oemconf -> getShutdownInteractive();
        $oem{kiwi_oemsilentboot}         = $oemconf -> getSilentBoot();
        $oem{kiwi_oemsilentinstall}      = $oemconf -> getSilentInstall();
        $oem{kiwi_oemsilentverify}       = $oemconf -> getSilentVerify();
        $oem{kiwi_oemskipverify}         = $oemconf -> getSkipVerify();
        $oem{kiwi_oembootwait}           = $oemconf -> getBootwait();
        $oem{kiwi_oemunattended}         = $oemconf -> getUnattended();
        $oem{kiwi_oemunattended_id}      = $oemconf -> getUnattendedID();
        $oem{kiwi_oemrecovery}           = $oemconf -> getRecovery();
        $oem{kiwi_oemrecoveryID}         = $oemconf -> getRecoveryID();
        $oem{kiwi_oemrecoveryPartSize}   = $oemconf -> getRecoveryPartSize();
        $oem{kiwi_oemrecoveryInPlace}    = $oemconf -> getInplaceRecovery();
        #==========================================
        # special handling
        #------------------------------------------
        if (($oem{kiwi_oemswap}) &&
            ($oem{kiwi_oemswap} ne 'false')
        ) {
            $this -> addEntry('kiwi_oemswap','true');
            if (($oem{kiwi_oemswapMB}) && ($oem{kiwi_oemswapMB} > 0)) {
                $this -> addEntry('kiwi_oemswapMB',$oem{kiwi_oemswapMB});
            }
        }
        if (($oem{kiwi_oemataraid_scan}) &&
            ($oem{kiwi_oemataraid_scan} eq 'false')
        ) {
            $this -> addEntry(
                'kiwi_oemataraid_scan',$oem{kiwi_oemataraid_scan}
            );
        }
        if (($oem{kiwi_oemmultipath_scan}) &&
            ($oem{kiwi_oemmultipath_scan} eq 'false')
        ) {
            $this -> addEntry(
                'kiwi_oemmultipath_scan',$oem{kiwi_oemmultipath_scan}
            );
        }
        if ($oem{kiwi_oemtitle}) {
            $this -> addEntry(
                'kiwi_oemtitle',$this -> __quote ($oem{kiwi_oemtitle})
            );
        }
        if ($oem{kiwi_oemdevicefilter}) {
            $this-> addEntry(
                'kiwi_oemdevicefilter',
                $this -> __quote ($oem{kiwi_oemdevicefilter})
            );
        }
        if ($oem{kiwi_oemvmcp_parmfile}) {
            $this-> addEntry(
                'kiwi_oemvmcp_parmfile',
                $this -> __quote ($oem{kiwi_oemvmcp_parmfile})
            );
        }
        delete $oem{kiwi_oemvmcp_parmfile};
        delete $oem{kiwi_oemdevicefilter};
        delete $oem{kiwi_oemtitle};
        delete $oem{kiwi_oemswap};
        delete $oem{kiwi_oemswapMB};
        delete $oem{kiwi_oemataraid_scan};
        delete $oem{kiwi_oemmultipath_scan};
        #==========================================
        # default handling for non false values
        #------------------------------------------
        foreach my $key (keys %oem) {
            my $value = $oem{$key};
            next if ! $value;
            next if ($value eq 'false');
            $this -> addEntry ($key,$value);
        }
    }
    return $this;
}

#==========================================
# __storeRevisionInformation
#------------------------------------------
sub __storeRevisionInformation {
    my $this = shift;
    if (! $this->{profile}{kiwi_revision}) {
        my $rev   = "unknown";
        my $revFl = KIWIGlobals
            -> instance() -> getKiwiConfig() -> {Revision};
        my $FD = FileHandle -> new();
        if ($FD -> open ($revFl)) {
            $rev = <$FD>;
            $rev =~ s/\n//msxg;
            $FD -> close();
        }
        $this -> addEntry ("kiwi_revision",$rev);
    }
    return $this;
}

#==========================================
# __quote
#------------------------------------------
sub __quote {
        my $this = shift;
        my $line = shift;
        $line =~ s/([\"\$\`\\])/\\$1/sxmg;
        return $line;
}

1;
