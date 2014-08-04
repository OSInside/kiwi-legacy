#================
# FILE          : KIWIOVFConfigWriter.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2014 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Write a OVF configuration file
#               :
# REFERENCES    : http://www.dmtf.org/sites/default/files/standards/
#               : documents/DSP0243_1.1.0.pdf
#               : http://schemas.dmtf.org/wbem/cim-html/2/
#               : CIM_ResourceAllocationSettingData.html
#               :
# STATUS        : Development
#----------------
package KIWIOVFConfigWriter;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Digest::SHA1;
use Readonly;

require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWIXML;
use KIWIXMLVMachineData;

use base qw /KIWIConfigWriter/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constants
#------------------------------------------
Readonly my $EXTRALARGE => 100_000_000;
Readonly my $GIG => 1024;
Readonly my $HALFGIG => 512;
Readonly my $SLOTNUM => 160;
Readonly my $TEN => 10;  # Fudge factor for weighting

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIOVFConfigWriter object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    if (! $this) {
        return;
    }
    my $imgName = KIWIGlobals
        -> instance()
        -> generateBuildImageName($this->{xml});
    $this->{name} = $imgName . '.ovf';
    return $this;
}

#==========================================
# writeConfigFile
#------------------------------------------
sub writeConfigFile {
    # ...
    # Write the OVF configuration file
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $xml = $this->{xml};
    my $loc = $this -> getConfigDir();
    my $fileName = $this -> getConfigFileName();
    my $vmConfig = $xml -> getVMachineConfig();
    if (! $vmConfig) {
        my $msg = 'Generation of OVF file requires <machine> '
            . "definition\nin config file.";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $this -> __setOVFType($vmConfig);
    my $ovfType = $this -> {ovfType};
    my $baseName = KIWIGlobals
        -> instance()
        -> generateBuildImageName($this->{xml});
    my $imageName =  $baseName . '.vmdk';
    if (! -f "$loc/$imageName") {
        my $msg = "Could not find expected image '$loc/$imageName'";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $vsize = -s "$loc/$imageName";
    if (! $vsize) {
        $kiwi -> error(
            "Can't obtain embedded OVF image size: $!"
        );
        $kiwi -> failed();
        return;
    }
    $kiwi -> info("Write OVF configuration file\n");
    $kiwi -> info ("--> $loc/$fileName\n");
    # Start out with the XML header
    my $config = $this -> __generateXMLHeader();
    #==========================================
    # image description
    #------------------------------------------
    # Should be able to tie into the build p_generateChecksum code
    # but that's currently protected, needs some restructuring
    my $status = open (my $INPUT, '<', "$loc/$imageName");
    if (! $status) {
        my $msg = "Could not read $loc/$imageName";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $sha1 = Digest::SHA1->new();
    $sha1->addfile($INPUT);
    my $checksum = $sha1->hexdigest();
    $status = close $INPUT;
    if (! $status) {
        my $msg = "Could not close opened file: $loc/$imageName";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    my $refID;
    if ($this -> {predictID}) {
        $refID = '1-2';
    } else {
        $refID = "$checksum" . '-' . time;
    }
    my $fileRef = 'file-' . $refID;
    my $vmdkSize = -s "$loc/$imageName";
    $config .= '<ovf:References>' . "\n"
        . "\t" . '<ovf:File ovf:href="' . $imageName . '" '
        . 'ovf:id="' . $fileRef . '" '
        . 'ovf:size="' . $vmdkSize . '"/>' . "\n"
        . '</ovf:References>' . "\n";
    #==========================================
    # storage description
    #------------------------------------------
    my $diskID = 'vmdisk-' . $refID;
    $config .= '<ovf:DiskSection>' . "\n"
        . "\t" . '<ovf:Info>Virtual disk information</ovf:Info>' . "\n"
        . "\t" . '<ovf:Disk '
        . 'ovf:capacity="' . $vsize . '" '
        . 'ovf:capacityAllocationUnits="byte * 2^20" '
        . 'ovf:diskId="' . $diskID . '" '
        . 'ovf:fileRef="' . $fileRef . '"/>' . "\n"
        . '</ovf:DiskSection>' . "\n";
    #==========================================
    # network description
    #------------------------------------------
    $config .= $this -> __generateNetworkDeclaration($vmConfig);
    #==========================================
    # virtual system description
    #------------------------------------------
    my $instID = 0;
    my $sysID = 'vm-' . $refID;
    my $sysData = $this -> __getSystemData($vmConfig);
    if (! $sysData) {
        return;
    }
    $config .= '<ovf:VirtualSystem ovf:id="' . $sysID . '">' . "\n"
        . "\t" . '<Info>A virtual machine</Info>' . "\n"
        . "\t" . '<Name>' . $baseName . '</Name>' . "\n"
        . "\t" . '<OperatingSystemSection '
        . 'ovf:id="' . $sysData->{osid} . '" '
        . 'vmw:osType="' . $sysData->{ostype} . '">' . "\n"
        . "\t\t" . '<Info>Image cretaed by KIWI</Info>' . "\n"
        . "\t" . '</OperatingSystemSection>' . "\n"
        . "\t" . '<ovf:VirtualHardwareSection ovf:transport="">' . "\n"
        . "\t\t" . '<Info>Virtual hardware requirements</Info>' . "\n"
        . "\t\t" . '<ovf:System>' . "\n"
        . "\t\t\t" . '<vssd:ElementName>Virtual Hardware Family'
        . '</vssd:ElementName>' . "\n"
        . "\t\t\t" . '<vssd:InstanceID>' . $instID
        . '</vssd:InstanceID>' . "\n"
        . "\t\t\t" . '<vssd:VirtualSystemIdentifier>' . $baseName
        . '</vssd:VirtualSystemIdentifier>' . "\n"
        . "\t\t\t" . '<vssd:VirtualSystemType>' . $sysData->{type}
        . '</vssd:VirtualSystemType>' . "\n"
        . "\t\t" . '</ovf:System>' . "\n";
    $instID += 1;
    # CPU setup
    my $cpuConfig = $this -> __generateCPUCfgSection($vmConfig, $instID);
    if (! $cpuConfig) {
        return;
    }
    $config .= $cpuConfig;
    $instID += 1;
    # Memory setup
    my $memConfig = $this -> __generateMemoryCfgSection($vmConfig, $instID);
    if (! $memConfig) {
        return;
    }
    $config .= $memConfig;
    $instID += 1;
    # Disk controller
    my ($diskCtrlConfig, $controllerID) =
        $this -> __generateDiskCtrlCfgSection($vmConfig, $instID);
    if (! $diskCtrlConfig) {
        return;
    }
    $config .= $diskCtrlConfig;
    $instID += 1;
    # Connect the system disk to the controller
    my $pAddress = 0;
    my $diskCfg =
        $this -> __generateDiskCfgSection($vmConfig, $instID, $controllerID);
    $config .= $diskCfg;
    $instID += 1;
    # DVD
    my ($dvdCfg, $upInstIDDVD) =
    $this -> __generateDVDCfgSection($vmConfig, $instID, $controllerID);
    if ($dvdCfg) {
        $config .= $dvdCfg;
        $instID = $upInstIDDVD;
    }
    # Network
    my ($netCfg, $upInstID) =
        $this -> __generateNetworkCfgSection($vmConfig, $instID);
    $instID = $upInstID;
    $config .= $netCfg;
    # Configuration we received from VMWare, not certain if this applies to
    # other environments, being cautious
    if ($ovfType eq 'vmware') {
        $config .= "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="cpuHotAddEnabled" vmw:value="false"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="cpuHotRemoveEnabled" vmw:value="false"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="firmware" vmw:value="bios"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="virtualICH7MPresent" vmw:value="false"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="virtualSMCPresent" vmw:value="false"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="memoryHotAddEnabled" vmw:value="false"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="nestedHVEnabled" vmw:value="false"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="powerOpInfo.powerOffType" vmw:value="soft"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="powerOpInfo.resetType" vmw:value="soft"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="powerOpInfo.standbyAction" '
            . 'vmw:value="checkpoint"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="powerOpInfo.suspendType" vmw:value="hard"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="tools.afterPowerOn" vmw:value="true"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="tools.afterResume" vmw:value="true"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="tools.beforeGuestShutdown" vmw:value="true"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="tools.beforeGuestStandby" vmw:value="true"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="tools.syncTimeWithHost" vmw:value="false"/>' . "\n"
            . "\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="tools.toolsUpgradePolicy" vmw:value="manual"/>' . "\n";
    }
    $config .= "\t"
        . '</ovf:VirtualHardwareSection>' . "\n";
    # vCloud specific settingw. When generating an ovf for VMWare we assume
    # the destination is a vCloud instance
    if ($ovfType eq 'vmware') {
        $config .= "\t"
            . '<vcloud:GuestCustomizationSection ovf:required="false">' . "\n"
            . "\t\t"
            . '<ovf:Info>Specifies Guest OS Customization Settings'
            . '</ovf:Info>' . "\n"
            . "\t\t"
            . '<vcloud:Enabled>true</vcloud:Enabled>' . "\n"
            . "\t\t"
            . '<vcloud:ChangeSid>false</vcloud:ChangeSid>' . "\n";
        my $vmID;
        if ($this -> {predictID}) {
            $vmID = $EXTRALARGE;
        } else {
            $vmID = rand $EXTRALARGE;
        }
        my $vcloudVMID = "$vmID";
        $vcloudVMID =~ s/\./-/smx;
        $config .= "\t\t"
            . '<vcloud:VirtualMachineId>' . $vcloudVMID
            . '</vcloud:VirtualMachineId>' . "\n"
            . "\t\t"
            . '<vcloud:JoinDomainEnabled>false'
            . '</vcloud:JoinDomainEnabled>' . "\n"
            . "\t\t"
            . '<vcloud:UseOrgSettings>false</vcloud:UseOrgSettings>' . "\n"
            . "\t\t"
            . '<vcloud:AdminPasswordEnabled>true'
            . '</vcloud:AdminPasswordEnabled>' . "\n"
            . "\t\t"
            . '<vcloud:AdminPasswordAuto>true'
            . '</vcloud:AdminPasswordAuto>' . "\n"
            . "\t\t"
            . '<vcloud:ResetPasswordRequired>true'
            . '</vcloud:ResetPasswordRequired>' . "\n"
            . "\t\t"
            . '<vcloud:ComputerName>KIWI Machine</vcloud:ComputerName>' . "\n"
            . "\t"
            . '</vcloud:GuestCustomizationSection>' . "\n";
    }
    $config .= '</ovf:VirtualSystem>' . "\n"
        . '</ovf:Envelope>';
    $status = open (my $CONF, '>', "$loc/$fileName");
    if (! $status) {
        my $msg = 'Could not write OVF configuration file '
            . "$loc/$fileName";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    binmode $CONF;
    print $CONF $config;
    $status = close $CONF;
    if (! $status) {
        my $msg = 'Unable to close configuration file'
            . "$loc/$fileName";
        $kiwi -> warning($msg);
        $kiwi -> skipped();
    }
    return 1;
}

#==========================================
# setPredictableID
#------------------------------------------
sub setPredictableID {
    # ...
    # A consession to testing to generate prdictable identifiers. May also
    # useful during image generation.
    # ---
    my $this = shift;
    $this -> {predictID} = 1;
    return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __generateCPUCfgSection
#------------------------------------------
sub __generateCPUCfgSection {
    # ...
    # Generate the section of the configuration concerning the CPU settings
    # ---
    my $this     = shift;
    my $vmConfig = shift;
    my $instID   = shift;
    my $kiwi = $this -> {kiwi};
    my $maxCPU = $vmConfig -> getMaxCPUCnt();
    my $minCPU = $vmConfig -> getMinCPUCnt();
    my $numCPU = $vmConfig -> getNumCPUs();
    if ($maxCPU || $minCPU || $numCPU) {
        if (! $numCPU) {
            if ($maxCPU && $minCPU) {
                my $max = int $maxCPU;
                my $min = int $minCPU;
                if ($min > $ max) {
                    my $msg = 'Minimum CPU count specified larger '
                        . 'than maximum';
                    $kiwi -> error($msg);
                    $kiwi -> failed();
                    return;
                }
                $numCPU = int (($max + $min) / 2);
            } elsif ($maxCPU) {
                $numCPU = int $maxCPU;
                if ($numCPU > 1) {
                    $numCPU -= 1;
                }
            } elsif ($minCPU) {
                $numCPU = int $minCPU;
                $numCPU += 1;
            }
        }
    }
    if (! $numCPU ) {
        my $msg = '--> No nominal CPU count set, using 1';
        $kiwi -> warning($msg);
        $kiwi -> notset();
        $numCPU = 1;
    }
    my $config = "\t\t" . '<ovf:Item>' . "\n"
        . "\t\t\t"
        . '<rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>' . "\n"
        . "\t\t\t"
        . '<rasd:Description>Number of Virtual CPUs</rasd:Description>' . "\n"
        . "\t\t\t"
        . '<rasd:ElementName>CPU definition</rasd:ElementName>' . "\n"
        . "\t\t\t"
        . '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n";
    # Do not consider minCPU, according to the description Limit specifies
    # an upper bound only
    if ($maxCPU) {
        $config .= "\t\t\t"
            . '<rasd:Limit>' . $maxCPU . '</rasd:Limit>' . "\n";
    }
    $config .= "\t\t\t"
        . '<rasd:Reservation>0</rasd:Reservation>' . "\n"
        . "\t\t\t"
        . '<rasd:ResourceType>3</rasd:ResourceType>' . "\n"
        . "\t\t\t"
        . '<rasd:VirtualQuantity>' . $numCPU . '</rasd:InstanceID>' . "\n"
        . "\t\t\t"
        . '<rasd:Weight>1000</rasd:Weight>' . "\n"
        . "\t\t\t"
        . '<vmw:CoresPerSocket ovf:required="false">'
        . '1</vmw:CoresPerSocket>' . "\n"
        . "\t\t\t"
        . '<rasd:Weight>1000</rasd:Weight>' . "\n"
        . "\t\t" . '</ovf:Item>' . "\n";

    return $config;
}

#==========================================
# __generateDiskCfgSection
#------------------------------------------
sub __generateDiskCfgSection {
    # ...
    # Generate the disk configuration section connecting it to the controller
    # ---
    my $this         = shift;
    my $vmConfig     = shift;
    my $instID       = shift;
    my $controllerID = shift;
    my $ovfType = $this -> {ovfType};
    my $pAddress = 0;
    my $diskID = $pAddress + 1;
    my $config = "\t\t" . '<ovf:Item>' . "\n"
        . "\t\t\t"
        . '<rasd:AddressOnParent>' . $pAddress
        . '</rasd:AddressOnParent>' . "\n"
        . "\t\t\t"
        . '<rasd:Description>Hard disk</rasd:Description>' . "\n"
        . "\t\t\t"
        . '<rasd:ElementName>Hard disk' . $diskID
        . '</rasd:ElementName>' . "\n"
        . "\t\t\t"
        . '<rasd:HostResource>ovf:/disk/' . $diskID
        . '</rasd:HostResource>' . "\n"
        . "\t\t\t"
        . '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
        . "\t\t\t"
        . '<rasd:Parent>' . $controllerID . '</rasd:Parent>' . "\n"
        . "\t\t\t"
        . '<rasd:ResourceType>17</rasd:ResourceType>' . "\n";
    if ($ovfType eq 'vmware') {
        $config .= "\t\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="backing.writeThrough" '
            . 'vmw:value="false"/>' . "\n";
    }
    $config .= "\t\t" . '</ovf:Item>' . "\n";

    return $config;
}

#==========================================
# __generateDiskCtrlCfgSection
#------------------------------------------
sub __generateDiskCtrlCfgSection {
    # ...
    # Generate the section for the disk settings
    # ---
    my $this     = shift;
    my $vmConfig = shift;
    my $instID   = shift;
    my $controllerID = $instID;
    my $kiwi = $this -> {kiwi};
    my $ovfType = $this -> {ovfType};
    my $diskType = $vmConfig -> getSystemDiskType();
    if (! $ovfType) {
        $ovfType = 'vmware';
    }
    if (! $diskType) {
        my $msg = '--> No disk disktype set, using "scsi"';
        $kiwi -> warning($msg);
        $kiwi -> notset();
        $diskType = 'scsi';
    }
    my $rType;
    if ($diskType eq 'ide') {
        $rType = 5;
    } else {
        $rType = 6;
    }
    my $controller = $vmConfig -> getSystemDiskController();
    if (! $controller) {
        my $msg = '--> No disk controller set, using "lsilogic"';
        $kiwi -> warning($msg);
        $kiwi -> notset();
        $controller = 'lsilogic';
    }
    my $descptType = uc $diskType;
    my $config = "\t\t" . '<ovf:Item>' . "\n"
        . "\t\t\t"
        . '<rasd:Description>' . $descptType
        . ' Controller</rasd:Description>' . "\n"
        . "\t\t\t"
        . '<rasd:ElementName>' . $diskType . ' Controller'
        . '</rasd:ElementName>' . "\n"
        . "\t\t\t"
        . '<rasd:InstanceID>' . $controllerID . '</rasd:InstanceID>' . "\n"
        . "\t\t\t"
        . '<rasd:ResourceSubType>' . $controller
        . '</rasd:ResourceSubType>' . "\n"
        . "\t\t\t"
        . '<rasd:ResourceType>' . $rType . '</rasd:ResourceType>' . "\n";
    if ($ovfType eq 'vmware') {
        $config .= "\t\t\t"
            . '<vmw:Config ovf:required="false" '
            . 'vmw:key="slotInfo.pciSlotNumber" '
            . 'vmw:value="16"/>' . "\n";
    }
    $config .= "\t\t" . '</ovf:Item>' . "\n";

    return $config, $controllerID;
}

#==========================================
# __generateDVDCfgSection
#------------------------------------------
sub __generateDVDCfgSection {
    # ...
    # Generate the DVD device configuration section
    # ---
    my $this         = shift;
    my $vmConfig     = shift;
    my $instID       = shift;
    my $controllerID = shift;
    my $dvdController = $vmConfig -> getDVDController();
    if (! $dvdController) {
        return;
    }
    my $pAddress = 0;
    my $config = qw {};
    my $dvdContID;
    my $diskType = $vmConfig -> getSystemDiskType();
    if ($dvdController eq $diskType) {
        $dvdContID = $controllerID;
    } else {
        $dvdContID = $instID;
    }
    my $rType;
    if ($dvdController eq 'ide') {
        $rType = 5;
    } else {
        $rType = 6;
    }
    my $pAddressDVD = $pAddress + 1;
    if ($dvdContID ne $controllerID) {
        # Need to create a new contoller, different type than the disk
        $pAddressDVD = $pAddress;
        $config .= "\t\t" . '<ovf:Item>' . "\n"
            . "\t\t\t"
            . '<rasd:Description>DVD controller</rasd:Description>' . "\n"
            . "\t\t\t"
            . '<rasd:ElementName>DVDController'
            . $dvdController
            . '</rasd:ElementName>' . "\n"
            . "\t\t\t"
            . '<rasd:InstanceID>' . $dvdContID
            . '</rasd:InstanceID>' . "\n"
            . "\t\t\t"
            . '<rasd:ResourceType>' . $rType
            . '</rasd:ResourceType>' . "\n"
            . "\t\t" . '</ovf:Item>' . "\n";
        $instID += 1;
    }
    # Create the DVD device
    $config .= "\t\t" . '<ovf:Item>' . "\n"
        . "\t\t\t"
        . '<rasd:AddressOnParent>' . $pAddressDVD
        . '</rasd:AddressOnParent>' . "\n"
        . "\t\t\t"
        . '<rasd:AutomaticAllocation>false'
        . '</rasd:AutomaticAllocation>' . "\n"
        . "\t\t\t"
        . '<rasd:Description>CD/DVD Drive</rasd:Description>' . "\n"
        . "\t\t\t"
        . '<rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>' . "\n"
        . "\t\t\t"
        . '<rasd:HostResource/>' . "\n"
        . "\t\t\t"
        . '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
        . "\t\t\t"
        . '<rasd:Parent>' . $dvdContID . '</rasd:Parent>' . "\n"
        . "\t\t\t"
        . '<rasd:ResourceType>15</rasd:ResourceType>' . "\n"
        . "\t\t" . '</Item>' . "\n";
    $instID += 1;

    return $config, $instID
}

#==========================================
# __generateMemoryCfgSection
#------------------------------------------
sub __generateMemoryCfgSection {
    # ...
    # Generate the section of the configuration concerning the memory settings
    # ---
    my $this     = shift;
    my $vmConfig = shift;
    my $instID   = shift;
    my $kiwi = $this -> {kiwi};
    my $maxMem = $vmConfig -> getMaxMemory();
    my $minMem = $vmConfig -> getMinMemory();
    my $memory = $vmConfig -> getMemory();
    if ($maxMem || $minMem || $memory) {
        if (! $memory) {
            if ($maxMem && $minMem) {
                my $max = int $maxMem;
                my $min = int $minMem;
                if ($min > $ max) {
                    my $msg = 'Minimum memory specified larger than maximum';
                    $kiwi -> error($msg);
                    $kiwi -> failed();
                    return;
                }
                $memory = int (($maxMem + $minMem) / 2);
            } elsif ($maxMem) {
                $memory = int $maxMem;
                if ($memory > $HALFGIG) {
                    $memory -= $HALFGIG;
                }
            } elsif ($minMem) {
                $memory = int $minMem;
                $memory += $HALFGIG;
            }
        }
    }
    if (! $memory ) {
        my $msg = "--> No memory value set, using '$GIG MB'";
        $kiwi -> warning($msg);
        $kiwi -> notset();
        $memory = $GIG;
    }
    my $config = "\t\t" . '<ovf:Item>' . "\n"
        . "\t\t\t"
        . '<rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>' . "\n"
        . "\t\t\t"
        . '<rasd:Description>Memory Size</rasd:Description>' . "\n"
        . "\t\t\t"
        . '<rasd:ElementName>' . $memory . 'MB of memory'
        . '</rasd:ElementName>' . "\n"
        . "\t\t\t"
        . '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n";
    # Do not consider minMem, according to the description Limit specifies
    # an upper bound only
    if ($maxMem) {
        $config .= "\t\t\t"
            . '<rasd:Limit>' . $maxMem . '</rasd:Limit>' . "\n";
    }
    $config .= "\t\t\t"
        . '<rasd:Reservation>0</rasd:Reservation>' . "\n"
        . "\t\t\t"
        . '<rasd:ResourceType>4</rasd:ResourceType>' . "\n"
        . "\t\t\t"
        . '<rasd:VirtualQuantity>' . $memory . '</rasd:VirtualQuantity>' . "\n"
        . "\t\t\t"
        . '<rasd:Weight>' . $memory * $TEN . '</rasd:Weight>' . "\n"
        . "\t\t" . '</Item>' . "\n";

    return $config;
}

#==========================================
# __generateNetworkCfgSection
#------------------------------------------
sub __generateNetworkCfgSection {
    # ...
    # Generate the network device config section
    # ---
    my $this = shift;
    my $vmConfig = shift;
    my $instID   = shift;
    my $kiwi = $this -> {kiwi};
    my $ovfType = $this -> {ovfType};
    my $config = qw {};
    my $nicCnt = 1;
    my $pAddress = 0;
    my $pciSlotNum = $SLOTNUM;
    my @nicIDs = @{$vmConfig -> getNICIDs()};
    for my $id (@nicIDs) {
        my $iFace = $vmConfig -> getNICInterface($id);
        my $mac = $vmConfig -> getNICMAC($id);
        my $mode = $vmConfig -> getNICMode($id);
        if (! $mode) {
            my $msg = '--> No network mode set, using "none"';
            $kiwi -> info($msg);
            $kiwi -> notset();
            $mode = 'none';
        }
        my $driver = $vmConfig -> getNICDriver($id);
        if (! $driver) {
            my $msg = '--> No network driver set, using "vmxnet3"';
            $kiwi -> info($msg);
            $kiwi -> notset();
            $driver = 'vmxnet3';
        }
        $pAddress += 1;
        $config .= "\t\t" . '<ovf:Item>' . "\n";
        if ($mac) {
            $config .= "\t\t\t"
                . '<rasd:Address>' . $mac . '</rasd:Address>'. "\n";
        }
        $config .= "\t\t\t"
            . '<rasd:AddressOnParent>' . $pAddress
            . '</rasd:AddressOnParent>'. "\n"
            . "\t\t\t"
            . '<rasd:Description>' . $driver . ' ethernet on -' . $mode
            . '-</rasd:Description>' . "\n"
            . "\t\t\t"
            . '<rasd:ElementName>Network adapter ' . $id
            . '</rasd:ElementName>' . "\n"
            . "\t\t\t"
            . '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
            . "\t\t\t"
            . '<rasd:ResourceSubType>' . $driver
            . '</rasd:ResourceSubType>' . "\n"
            . "\t\t\t"
            . '<rasd:ResourceType>10</rasd:ResourceType>' . "\n"
            . "\t\t\t"
            . '<rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>'
            . "\n";
        if  ($ovfType eq 'vmware') {
            $config .= "\t\t\t";
            if ($nicCnt == 1) {
                $config .= '<rasd:Connection vcloud:ipAddressingMode="NONE" '
                    . 'vcloud:primaryNetworkConnection="true">'
                    . $mode . '</rasd:Connection>' . "\n"
                    . "\t\t\t"
                    . '<vmw:Config ovf:required="false" '
                    . 'vmw:key="wakeOnLanEnabled" vmw:value="true"/>' . "\n";
                $nicCnt += 1;
            } else {
                $config .= '<rasd:Connection vcloud:ipAddressingMode="NONE" '
                    . 'vcloud:primaryNetworkConnection="false">'
                    . $mode . '</rasd:Connection>' . "\n"
                    . "\t\t\t"
                    . '<vmw:Config ovf:required="false" '
                    . 'vmw:key="wakeOnLanEnabled" vmw:value="false"/>' . "\n";
            }
            $config .= "\t\t\t"
                . '<vmw:Config ovf:required="false" '
                . 'vmw:key="slotInfo.pciSlotNumber" '
                . 'vmw:value="' . $pciSlotNum . '"/>' . "\n";
            $pciSlotNum += 1;
        } else {
            $config .= "\t\t\t"
                . '<rasd:Connection>' . $mode . '</rasd:Connection>' . "\n";
        }
        $config .= "\t\t" . '</ovf:Item>' . "\n";
        $instID += 1;
    }

    return $config, $instID;
}

#==========================================
# __generateNetworkDeclaration
#------------------------------------------
sub __generateNetworkDeclaration {
    # ...
    # Generate the network declaration data
    # ---
    my $this = shift;
    my $vmConfig = shift;
    my $kiwi = $this -> {kiwi};
    my $config = qw {};
    my @nicIDs = @{$vmConfig -> getNICIDs()};
    my $numNics = scalar @nicIDs;
    if ($numNics) {
        $config .= '<ovf:NetworkSection>' . "\n"
        . "\t" . '<ovf:Info>The list of logical networks</ovf:Info>' . "\n";
    }
    my %modes;
    for my $id (@nicIDs) {
        my $mode = $vmConfig -> getNICMode($id);
        if (! $mode) {
            my $msg = '--> No network mode set, using "none"';
            $kiwi -> info($msg);
            $kiwi -> notset();
            $mode = 'none';
        }
        if (! $modes{$mode}) {
            $config .= "\t" . '<Network ovf:name="' . $mode . '">' . "\n"
                . "\t\t" . '<Description>The ' . $mode . ' network'
                . '</Description>' . "\n"
                . "\t" . '</Network>' . "\n";
            $modes{$mode} = 1;
        }
    }
    if ($numNics) {
        $config .= '</ovf:NetworkSection>' . "\n";
    }

    return $config;
}

#==========================================
# __generateXMLHeader
#------------------------------------------
sub __generateXMLHeader {
    # ...
    # Generate the header data
    # ---
    my $this = shift;
    my $ovfType = $this -> {ovfType};
    my $config = '<?xml version="1.0" encoding="UTF-8"?>' . "\n"
        . '<!-- KIWI generated ovf file --> ' . "\n"
        . '<ovf:Envelope '
        . 'xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" '
        . 'xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" '
        . 'xmlns:vmw="http://www.vmware.com/schema/ovf" '
        . 'xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" '
        . 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ';
    if ($ovfType eq 'vmware') {
        $config .= 'xmlns:vcloud="http://www.vmware.com/vcloud/v1.5"';
    }
    $config .= ' xsi:schemaLocation="'
        . 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData '
        . 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd '
        . 'http://www.vmware.com/schema/ovf '
        . 'http://schemas.dmtf.org/ovf/envelope/1 '
        . 'http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd '
        . 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData '
        . 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd';
    if ($ovfType eq 'vmware') {
        $config .= ' http://www.vmware.com/vcloud/v1.5 '
    }
    $config .= '">' . "\n";

    return $config;
}

#==========================================
# __getHWVersion
#------------------------------------------
sub __getHWVersion {
    # ...
    # Get the configured hw version
    # ---
    my $this = shift;
    my $vmdata = shift;
    my $default = shift;
    my $kiwi = $this->{kiwi};
    my $hwVersion = $vmdata -> getHardwareVersion();
    if (! $hwVersion ) {
        my $msg = "--> No HW version set using default: '$default'";
        $kiwi -> info($msg);
        $kiwi -> notset();
        return $default;
    }
    return $hwVersion;
}

#==========================================
# __getSystemData
#------------------------------------------
sub __getSystemData {
    # ...
    # Create system specific settings
    # https://support.opennodecloud.com/wiki/doku.php?id=devdoc:os:ovf#operatingsystemsection
    # ---
    my $this = shift;
    my $vmdata = shift;
    my $kiwi = $this->{kiwi};
    my %sysSettings;
    my %osTypDescrpt = (
        'unknown' => 'LINUX',
        'rhel'    => 'RedHat Enterprise Linux',
        'rhel-64' => 'RedHat Enterprise Linux 64-Bit',
        'sles'    => 'SLES',
        'sles-64' => 'SLES 64-Bit',
        'suse'    => 'SUSE',
        'suse-64' => 'SUSE 64-Bit',
    );
    my %osIDDescrpt = (
        'unknown' => '36',
        'rhel'    => '79',
        'rhel-64' => '80',
        'sles'    => '84',
        'sles-64' => '85',
        'suse'    => '82',
        'suse-64' => '83',
    );
    my %ovfTypeID = (
        'powervm' => 'IBM:POWER:AIXLINUX',
        # Match the default HW version seeting for the XMLMachine data object
        'vmware'  => 'vmx-' . $this -> __getHWVersion($vmdata, '9'),
        # The default here will never apply due to the default setting in the
        # XMLMachine object. There is uncertainty aboy the HW version indicator
        'xen'     => 'xen-' . $this -> __getHWVersion($vmdata, '4'),
        'zvm'     => 'IBM:zVM:LINUX',
    );
    my %ovfDiskInfo = (
        'powervm' => 'http://www.ibm.com/'
            . 'xmlns/ovf/diskformat/power.aix.mksysb',
        'vmware'  => 'http://www.vmware.com/'
            . 'interfaces/specifications/vmdk.html#streamOptimized',
        'xen'     => 'http://xen.org/',
        'zvm'     => 'http://www.ibm.com/'
            . 'xmlns/ovf/diskformat/s390.linuxfile.exustar.gz',
    );
    my $guest = $vmdata -> getGuestOS();
    if (! $guest) {
        # There is a default in the vmdata for suse, should never
        # reach this code. But we need to have it in case the default
        #is removed
        my $msg = 'No guest OS specified using generic Linux setup';
        $kiwi -> info ($msg);
        $guest = 'unknown';
    }
    if (! $osTypDescrpt{$guest}) {
        my $msg = "\nUnknown guest OS setting '$guest' using "
                . 'generic Linux setup';
        $kiwi -> info ($msg);
        $guest = 'unknown';
    }
    $sysSettings{ostype} = $osTypDescrpt{$guest};
    $sysSettings{osid} = $osIDDescrpt{$guest};

    my $ovfType = $this -> {ovfType};
    if (! $ovfTypeID{$ovfType}) {
        my $msg = 'Unknown ovf type specified';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    $sysSettings{type} = $ovfTypeID{$ovfType};
    $sysSettings{disk} = $ovfDiskInfo{$ovfType};

    return \%sysSettings;
}

#==========================================
# __setOVFType
#------------------------------------------
sub __setOVFType {
    # ...
    # Set the OVF type as a member
    # ---
    my $this     = shift;
    my $vmConfig = shift;
    my $kiwi = $this -> {kiwi};
    my $ovfType = $vmConfig -> getOVFType();
    if (! $ovfType) {
        my $msg = '--> No OVF type specified using fallback "vmware".';
        $kiwi -> warning($msg);
        $kiwi -> notset();
        $ovfType = 'vmware';
    }
    $this -> {ovfType} = $ovfType;
    return 1;
}

1;
