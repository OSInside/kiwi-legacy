#================
# FILE          : KIWIXMLVMachineData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <machine> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLVMachineData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Scalar::Util qw /looks_like_number/;
require Exporter;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLVMachineData object
	#
	# Internal data structure
	#
	# this = {
	#    HWversion     = '',
	#    arch          = '',
	#    confEntries   = (),
	#    desiredCPUCnt = '',
	#    desiredMemory = '',
	#    disks         = {
	#        system = {
	#            controller = '',
	#            device     = '',
	#            disktype 	= '',
	#            id         = ''
	#        }
	#    }
	#    domain        = '',
	#    dvd           = {
	#        controller = '',
	#        id         = ''
	#    }
	#    guestOS       = '',
	#    maxCPUCnt     = '',
	#    maxMemory     = '',
	#    memory        = '',
	#    minCPUCnt     = '',
	#    minMemory     = '',
	#    ncpus         = '',
	#    nics          = {
	#        ID[+] = {
	#            driver    = '',
	#            interface = '',
	#            mac       = '',
	#            mode      = ''
	#        }
	#    }
	#    ovftype       = ''
	# }
	#
	# Having the disks as a two level hashref allows us to support
	# specification of storage images at a later point without having to
	# change the data structure or changing the arguments and return
	# values of the interface with minimal to no extra cost if we decide to
	# never support storage virtual disks.
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi = shift;
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	if ($init && ref($init) ne 'HASH') {
		my $msg = 'Expecting a hash ref as second argument if provided';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($init) {
		# Check for unsupported entries
		if (! $this -> __isInitHashValid($init)) {
			return;
		}
		$this->{HWversion}     = $init->{HWversion};
		$this->{arch}          = $init->{arch};
		$this->{desiredCPUCnt} = $init->{des_cpu};
		$this->{desiredMemory} = $init->{des_memory};
		$this->{domain}        = $init->{domain};
		$this->{guestOS}       = $init->{guestOS};
		$this->{maxCPUCnt}     = $init->{max_cpu};
		$this->{maxMemory}     = $init->{max_memory};
		$this->{memory}        = $init->{memory};
		$this->{minCPUCnt}     = $init->{min_cpu};
		$this->{minMemory}     = $init->{min_memory};
		$this->{ncpus}         = $init->{ncpus};
		$this->{ovftype}       = $init->{ovftype};
		$this->{confEntries}   = $init->{'vmconfig-entries'};
		$this->{disks}         = $init->{vmdisks};
		$this->{dvd}           = $init->{vmdvd};
		$this->{nics}          = $init->{vmnics}
	}
	
	return $this;
}

#==========================================
# createNICConfig
#------------------------------------------
sub createNICConfig {
	# ...
	# Create a NIC configuration entry with the data provided and return
	# the ID of the new configuration to allow completion of the
	# config using the setNIC* methods.
	# ---
	my $this    = shift;
	my $nicInit = shift;
	my $kiwi = $this->{kiwi};
	my @existIDs = @{$this->getNICIDs()};
	my $newID = 1;
	if (@existIDs) {
		$newID = $existIDs[-1] + 1;
	}
	if (! $nicInit ) {
		my $msg = 'createNICConfig: expecting interface ID or hash ref '
			. ' as argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	if (ref($nicInit) eq 'HASH' ) {
		if (! $this -> __areNICSettingsSupported($nicInit)) {
			my $msg = 'createNICConfig: found unsupported setting '
			. 'in initialization hash.';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
		my %givenConfig = %{$nicInit};
		if (! $givenConfig{interface} ) {
			my $msg = 'createNICConfig: provided NIC initialization  '
				. 'structure must provide "interface" key-value pair.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		if (! $this->__interfaceIsUnique($givenConfig{interface},
										'createNICConfig')) {
			return;
		}
		$this->{nics}{$newID} = $nicInit;
		return $newID;
	}
	if (! $this->__interfaceIsUnique($nicInit, 'createNICConfig')) {
		return;
	}
	my %newConfig = ( interface => $nicInit );
	$this->{nics}{$newID} = \%newConfig;
	return $newID;
}

#==========================================
# getArch
#------------------------------------------
sub getArch {
	# ...
	# Return the machine architecture
	# ---
	my $this = shift;
	return $this->{arch};
}

#==========================================
# getConfigEntries
#------------------------------------------
sub getConfigEntries {
	# ...
	# Return the configuration file entries for the VM
	# ---
	my $this = shift;
	return $this->{confEntries};
}

#==========================================
# getDVDController
#------------------------------------------
sub getDVDController {
	# ...
	# Return the DVD controller setting
	# ---
	my $this = shift;
	if (! $this->{dvd}) {
		return;
	}
	return $this->{dvd}{controller};
}

#==========================================
# getDVDID
#------------------------------------------
sub getDVDID {
	# ...
	# Return the DVD ID setting
	# ---
	my $this = shift;
	if (! $this->{dvd}) {
		return;
	}
	return $this->{dvd}{id};
}

#==========================================
# getDesiredCPUCnt
#------------------------------------------
sub getDesiredCPUCnt {
	# ...
	# Return the setting for the desired number of CPUs
	# ---
	my $this = shift;
	return $this->{desiredCPUCnt};
}

#==========================================
# getDesiredMemory
#------------------------------------------
sub getDesiredMemory {
	# ...
	# Return the setting for the desired memory
	# ---
	my $this = shift;
	return $this->{desiredMemory};
}

#==========================================
# getDomain
#------------------------------------------
sub getDomain {
	# ...
	# Return the specified domain
	# ---
	my $this = shift;
	return $this->{domain};
}

#==========================================
# getGuestOS
#------------------------------------------
sub getGuestOS {
	# ...
	# Return the setting for the guest OS
	# ---
	my $this = shift;
	return $this->{guestOS};
}

#==========================================
# getHardwareVersion
#------------------------------------------
sub getHardwareVersion {
	# ...
	# Return the setting for the hardware version to emulate
	# ---
	my $this = shift;
	return $this->{HWversion};
}

#==========================================
# getMaxCPUCnt
#------------------------------------------
sub getMaxCPUCnt {
	# ...
	# Return the setting for the maximum CPUs to use
	# ---
	my $this = shift;
	return $this->{maxCPUCnt};
}

#==========================================
# getMaxMemory
#------------------------------------------
sub getMaxMemory {
	# ...
	# Return the setting for the maximum amount of memory to allocate
	# ---
	my $this = shift;
	return $this->{maxMemory};
}

#==========================================
# getMemory
#------------------------------------------
sub getMemory {
	# ...
	# Return the amount of memory to allocate
	# ---
	my $this = shift;
	return $this->{memory};
}

#==========================================
# getMinCPUCnt
#------------------------------------------
sub getMinCPUCnt {
	# ...
	# Return the minimum number of CPUs to use
	# ---
	my $this = shift;
	return $this->{minCPUCnt};
}

#==========================================
# getMinMemory
#------------------------------------------
sub getMinMemory {
	# ...
	# Return the minimum memory to allocate for the virtual machine
	# ---
	my $this = shift;
	return $this->{minMemory};
}

#==========================================
# getNICDriver
#------------------------------------------
sub getNICDriver {
	# ...
	# Return the driver for the NIC configured with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isNICIDValid($id, 'getNICDriver')) {
		return;
	}
	return $this->{nics}{$id}{driver};
}

#==========================================
# getNICIDs
#------------------------------------------
sub getNICIDs {
	# ...
	# Return an array ref of IDs for configured NICs
	# ---
	my $this = shift;
	my @nicIDs = keys %{$this->{nics}};
	my @sorted = sort @nicIDs;
	return \@sorted;
}

#==========================================
# getNICInterface
#------------------------------------------
sub getNICInterface {
	# ...
	# Return the interface specified for the NIC configured with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isNICIDValid($id, 'getNICInterface')) {
		return;
	}
	return $this->{nics}{$id}{interface};
}

#==========================================
# getNICMAC
#------------------------------------------
sub getNICMAC {
	# ...
	# Return the MAC address specified for the NIC configured with
	# the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isNICIDValid($id, 'getNICMAC')) {
		return;
	}
	return $this->{nics}{$id}{mac};
}

#==========================================
# getNICMode
#------------------------------------------
sub getNICMode {
	# ...
	# Return the mode configured for the NIC with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isNICIDValid($id, 'getNICMode')) {
		return;
	}
	return $this->{nics}{$id}{mode};
}

#==========================================
# getNumCPUs
#------------------------------------------
sub getNumCPUs {
	# ...
	# Return the nominal number of CPUs configured
	# ---
	my $this = shift;
	return $this->{ncpus};
}

#==========================================
# getOVFType
#------------------------------------------
sub getOVFType {
	# ...
	# Return the configured OVF format type
	# ---
	my $this = shift;
	return $this->{ovftype};
}

#==========================================
# getSystemDiskController
#------------------------------------------
sub getSystemDiskController {
	# ...
	# Return the controller configured for the system disk
	# ---
	my $this = shift;
	return $this->{disks}{system}{controller};
}

#==========================================
# getSystemDiskDevice
#------------------------------------------
sub getSystemDiskDevice {
	# ...
	# Return the configured device ID for the system disk
	# ---
	my $this = shift;
	return $this->{disks}{system}{device};
}

#==========================================
# getSystemDiskType
#------------------------------------------
sub getSystemDiskType {
	# ...
	# Return the configured device type for the system disk
	# ---
	my $this = shift;
	return $this->{disks}{system}{disktype};
}

#==========================================
# getSystemDiskID
#------------------------------------------
sub getSystemDiskID {
	# ...
	# Return the disk ID configured for the system disk
	# ---
	my $this = shift;
	return $this->{disks}{system}{id};
}

#==========================================
# setArch
#------------------------------------------
sub setArch {
	# ...
	# Set the architecture to be used for this VM
	# ---
	my $this = shift;
	my $arch = shift;
	my $kiwi = $this->{kiwi};
	if (! $arch) {
		my $msg = 'setArch: no architecture argument provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this -> __isArchValid($arch) ) {
		my $msg = "setArch: unsupported architecture '$arch' provided, "
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{arch} = $arch;
	return $this;
}

#==========================================
# setConfigEntries
#------------------------------------------
sub setConfigEntries {
	# ...
	# Set the configuration file entries for the VM config
	# ---
	my $this   = shift;
	my $config = shift;
	my $kiwi = $this->{kiwi};
	if (! $config ) {
		my $msg = 'setConfigEntries: no configuration file entries provided, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($config) ne 'ARRAY') {
		my $msg = 'setConfigEntries: expecting ARRAY ref as argument, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{confEntries} = $config;
	return $this;
}

#==========================================
# setDVDController
#------------------------------------------
sub setDVDController {
	# ...
	# Set the dvd controller for the VM
	# ---
	my $this       = shift;
	my $controller = shift;
	if (! $controller ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDVDController: no controller data provided, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{dvd}) {
		$this->{dvd}{controller} = $controller;
	} else {
		my %dvdInfo = ( controller => $controller );
		$this->{dvd} = \%dvdInfo;
	}
	return $this;
}

#==========================================
# setDVDID
#------------------------------------------
sub setDVDID {
	# ...
	# Set the dvd ID for the VM
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $id ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDVDID: no ID data provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{dvd}) {
		$this->{dvd}{id} = $id;
	} else {
		my %dvdInfo = ( id => $id );
		$this->{dvd} = \%dvdInfo;
	}
	return $this;
}

#==========================================
# setDesiredCPUCnt
#------------------------------------------
sub setDesiredCPUCnt {
	# ...
	# Set the desired number of CPUs for the VM
	# ---
	my $this  = shift;
	my $dcpus = shift;
	if (! $dcpus ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDesiredCPUCnt: no cpu count provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{desiredCPUCnt} = $dcpus;
	return $this;
}

#==========================================
# setDesiredMemory
#------------------------------------------
sub setDesiredMemory {
	# ...
	# Set the desired memory for the VM
	# ---
	my $this = shift;
	my $dmem = shift;
	if (! $dmem ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDesiredMemory: no memory amount provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{desiredMemory} = $dmem;
	return $this;
}

#==========================================
# setDomain
#------------------------------------------
sub setDomain {
	# ...
	# Set the domain
	# ---
	my $this   = shift;
	my $domain = shift;
	if (! $domain ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDomain: no domain provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{domain} = $domain;
	return $this;
}

#==========================================
# setGuestOS
#------------------------------------------
sub setGuestOS {
	# ...
	# Set the name of the VM guest OS
	# ---
	my $this  = shift;
	my $guest = shift;
	if (! $guest ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setGuestOS: no guest OS name provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{guestOS} = $guest;
	return $this;
}

#==========================================
# setHardwareVersion
#------------------------------------------
sub setHardwareVersion {
	# ...
	# Set the harware version to emulate for this VM
	# ---
	my $this = shift;
	my $hwv  = shift;
	if (! $hwv ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setHardwareVersion: no version data provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{HWversion} = $hwv;
	return $this;
}

#==========================================
# setMaxCPUCnt
#------------------------------------------
sub setMaxCPUCnt {
	# ...
	# Set the maximum number of CPUs to allocate for this VM
	# ---
	my $this   = shift;
	my $maxCPU = shift;
	if (! $maxCPU ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setMaxCPUCnt: no value provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{maxCPUCnt} = $maxCPU;
	return $this;
}

#==========================================
# setMaxMemory
#------------------------------------------
sub setMaxMemory {
	# ...
	# Set the maximum memory to allocate for this VM
	# ---
	my $this   = shift;
	my $maxMem = shift;
	if (! $maxMem ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setMaxMemory: no value provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{maxMemory} = $maxMem;
	return $this;
}

#==========================================
# setMemory
#------------------------------------------
sub setMemory {
	# ...
	# Set the nominal  memory to allocate for this VM
	# ---
	my $this = shift;
	my $mem  = shift;
	if (! $mem ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setMemory: no value provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{memory} = $mem;
	return $this;
}

#==========================================
# setMinCPUCnt
#------------------------------------------
sub setMinCPUCnt {
	# ...
	# Set the minimum number of CPUs to allocate for this VM
	# ---
	my $this   = shift;
	my $minCPU = shift;
	if (! $minCPU ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setMinCPUCnt: no value provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{minCPUCnt} = $minCPU;
	return $this;
}

#==========================================
# setMinMemory
#------------------------------------------
sub setMinMemory {
	# ...
	# Set the minimum memory to allocate for this VM
	# ---
	my $this   = shift;
	my $minMem = shift;
	if (! $minMem ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setMinMemory: no value provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{minMemory} = $minMem;
	return $this;
}

#==========================================
# setNICDriver
#------------------------------------------
sub setNICDriver {
	# ...
	# Set the driver for the NIC configuration with the given ID
	# ---
	my $this   = shift;
	my $id     = shift;
	my $driver = shift;
	if (! $this->{nics} ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICDriver: no NICS configured, call createNICConfig '
			. 'first';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isNICIDValid($id, 'setNICDriver')) {
		return;
	}
	if (! $driver ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICDriver: no driver provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{nics}{$id}{driver} = $driver;
	return $this;
}

#==========================================
# setNICInterface
#------------------------------------------
sub setNICInterface {
	# ...
	# Set the interface for the NIC configuration with the given ID
	# ---
	my $this      = shift;
	my $id        = shift;
	my $interface = shift;
	if (! $this->{nics} ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICInterface: no NICS configured, call createNICConfig '
			. 'first';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isNICIDValid($id, 'setNICInterface')) {
		return;
	}
	if (! $interface ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICInterface: no interface provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{nics}{$id}{interface} = $interface;
	return $this;
}

#==========================================
# setNICMAC
#------------------------------------------
sub setNICMAC {
	# ...
	# Set the MAC for the NIC configuration with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	my $mac  = shift;
	if (! $this->{nics} ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICMAC: no NICS configured, call createNICConfig '
			. 'first';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isNICIDValid($id, 'setNICMAC')) {
		return;
	}
	if (! $mac ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICMAC: no MAC provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{nics}{$id}{mac} = $mac;
	return $this;
}

#==========================================
# setNICMode
#------------------------------------------
sub setNICMode {
	# ...
	# Set the Mode for the NIC configuration with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	my $mode = shift;
	if (! $this->{nics} ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICMode: no NICS configured, call createNICConfig '
			. 'first';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isNICIDValid($id, 'setNICMode')) {
		return;
	}
	if (! $mode ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNICMode: no mode provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{nics}{$id}{mode} = $mode;
	return $this;
}

#==========================================
# setNumCPUs
#------------------------------------------
sub setNumCPUs {
	# ...
	# Set the minimum memory to allocate for this VM
	# ---
	my $this = shift;
	my $cpus = shift;
	if (! $cpus ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setNumCPUs: no value provided, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{ncpus} = $cpus;
	return $this;
}

#==========================================
# setOVFtype
#------------------------------------------
sub setOVFType {
	# ...
	# Set the OVF type to be used to package and describe the VM image
	# ---
	my $this = shift;
	my $ovfT = shift;
	my $kiwi = $this->{kiwi};
	if (! $ovfT) {
		my $msg = 'setOVFtype: no OVF type argument provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this -> __isOVFTypeValid($ovfT) ) {
		my $msg = "setOVFtype: unsupported OVF type '$ovfT' provided, "
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{ovftype} = $ovfT;
	return $this;
}

#==========================================
# setSystemDiskController
#------------------------------------------
sub setSystemDiskController {
	# ...
	# Set the controller to emulate for the system disk for this VM
	# ---
	my $this       = shift;
	my $controller = shift;
	if (! $controller ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setSystemDiskController: no value provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{disks} ) {
		my %diskInfo = ( controller => $controller );
		my %sysDisk = ( 'system' => \%diskInfo );
		$this->{disks} = \%sysDisk;
	} elsif (! $this->{disks}{system} ) {
		my %diskInfo = ( controller => $controller );
		$this->{disks}{system} = \%diskInfo;
	} else {
		$this->{disks}{system}{controller} = $controller;
	}
	return $this;
}

#==========================================
# setSystemDiskDevice
#------------------------------------------
sub setSystemDiskDevice {
	# ...
	# Set the device to emulate for the system disk for this VM
	# ---
	my $this   = shift;
	my $device = shift;
	if (! $device ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setSystemDiskDevice: no value provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{disks} ) {
		my %diskInfo = ( device => $device );
		my %sysDisk = ( 'system' => \%diskInfo );
		$this->{disks} = \%sysDisk;
	} elsif (! $this->{disks}{system} ) {
		my %diskInfo = ( device => $device );
		$this->{disks}{system} = \%diskInfo;
	} else {
		$this->{disks}{system}{device} = $device;
	}
	return $this;
}

#==========================================
# setSystemDiskType
#------------------------------------------
sub setSystemDiskType {
	# ...
	# Set the type to emulate for the system disk for this VM
	# ---
	my $this = shift;
	my $type = shift;
	if (! $type ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setSystemDiskType: no value provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{disks} ) {
		my %diskInfo = ( disktype => $type );
		my %sysDisk = ( 'system' => \%diskInfo );
		$this->{disks} = \%sysDisk;
	} elsif (! $this->{disks}{system} ) {
		my %diskInfo = ( disktype => $type );
		$this->{disks}{system} = \%diskInfo;
	} else {
		$this->{disks}{system}{disktype} = $type;
	}
	return $this;
}

#==========================================
# setSystemDiskID
#------------------------------------------
sub setSystemDiskID {
	# ...
	# Set the ID to emulate for the system disk for this VM
	# ---
	my $this   = shift;
	my $id = shift;
	if (! $id ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setSystemDiskID: no value provided, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{disks} ) {
		my %diskInfo = ( id => $id );
		my %sysDisk = ( 'system' => \%diskInfo );
		$this->{disks} = \%sysDisk;
	} elsif (! $this->{disks}{system} ) {
		my %diskInfo = ( id => $id );
		$this->{disks}{system} = \%diskInfo;
	} else {
		$this->{disks}{system}{id} = $id;
	}
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __areNICSettingsSupported
#------------------------------------------
sub __areNICSettingsSupported {
	# ...
	# Verify that the hash has only supported settings
	# ---
	my $this       = shift;
	my $nicSettings = shift;
	my %supportedNICSet = map { ($_ => 1) } qw(
		driver interface mac mode
	);
	my %givenConfig = %{$nicSettings};
	for my $setting (keys %givenConfig) {
		if (! $supportedNICSet{$setting} ) {
			return;
		}
	}
	return 1;
}

#==========================================
# __hasUnsuportedVMSettings
#------------------------------------------
sub __hasUnsuportedVMSettings {
	# ...
	# Verify that the hash has only supported settings
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my %initStruct = %{$init};
	my %supported = map { ($_ => 1) } qw(
		HWversion arch des_cpu des_memory domain guestOS max_cpu max_memory
		memory min_cpu min_memory ncpus ovftype vmconfig-entries vmdisks
		vmdvd vmnics
	);
	for my $key (keys %initStruct) {
		if (! $supported{$key} ) {
			my $msg = 'Unsupported option in initialization structure '
			. "found '$key'";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return 1;
		}
	}
	return;
}

#==========================================
# __interfaceIsUnique
#------------------------------------------
sub __interfaceIsUnique {
	# ...
	# Verify that the interface given is unique
	# ---
	my $this   = shift;
	my $iFace  = shift;
	my $caller = shift;
	my $kiwi = $this->{kiwi};
	if (! $caller ) {
		my $msg = 'Internal error __interfaceIsUnique called without '
			. 'call origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $iFace ) {
		my $msg = 'Internal error __interfaceIsUnique called without '
			. 'interface argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
		return 1;
	}
	if ($this->{nics}) {
		for my $nicInfo (values %{$this->{nics}}) {
			if ($nicInfo->{interface} eq $iFace) {
				my $msg = "$caller: interface device for '$iFace' "
					. 'already exists, ambiguous operation.';
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __isArchValid
#------------------------------------------
sub __isArchValid {
	# ...
	# Check if the given architecture is a supported setting
	# ---
	my $this = shift;
	my $arch = shift;
	my %supportedArch = ( 'ix86'   => 1,
						'x86_64' => 1
						);
	if (! $supportedArch{$arch} ) {
		return;
	}
	return 1;
}

#==========================================
# __isDiskInitValid
#------------------------------------------
sub __isDiskInitValid {
	# ...
	# Verify that the initialization hash given for the disk configuration
	# setup is valid.
	# ---
	my $this  = shift;
	my $disks = shift;
	my $kiwi = $this->{kiwi};
	if (ref($disks) ne 'HASH') {
		my $msg = 'Expecting a hash ref as entry for "vmdisks" in the '
		. 'initialization hash.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $disks->{system} ) {
		my $msg = 'Initialization data for vmdisks incomplete, must '
			. 'provide "system" key with hash ref as value.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %supported = map { ($_ => 1) } qw(controller device disktype id);
	my %diskInfo = %{$disks};
	for my $entry (values %diskInfo) {
		my %diskData = %{$entry};
		for my $dataKey (keys %diskData) {
			if (! $supported{$dataKey} ) {
				my $msg = 'Unsupported option in initialization '
					. 'structure for disk configuration, found '
					. "'$dataKey'";
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __isDVDInitValid
#------------------------------------------
sub __isDVDInitValid {
	# ...
	# Verify that the initialization hash given for the DVD configuration
	# setup is valid.
	# ---
	my $this = shift;
	my $dvd  = shift;
	my $kiwi = $this->{kiwi};
	if (ref($dvd) ne 'HASH') {
		my $msg = 'Expecting a hash ref as entry for "vmdvd" in the '
			. 'initialization hash.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $dvd->{controller} ) {
		my $msg = 'Initialization data for vmdvd incomplete, must '
			. 'provide "controller" key-value pair.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $dvd->{id} ) {
		my $msg = 'Initialization data for vmdvd incomplete, must '
			. 'provide "id" key-value pair.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %supported = map { ($_ => 1) } qw( controller id );
	my %dvdInfo = %{$dvd};
	for my $dvdKey (keys %dvdInfo) {
		if (! $supported{$dvdKey} ) {
			my $msg = 'Unsupported option in initialization structure '
				. "for dvd configuration, found '$dvdKey'";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __isNICInitValid
#------------------------------------------
sub __isNICInitValid {
	# ...
	# Verify that the initialization hash given for the NIC configuration
	# setup is valid.
	# ---
	my $this = shift;
	my $nics = shift;
	my $kiwi = $this->{kiwi};
	if (ref($nics) ne 'HASH') {
		my $msg = 'Expecting a hash ref as entry for "vmnics" in the '
			. 'initialization hash.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %usedIface = ();
	for my $entry (values %{$nics}) {
		if (! $entry->{interface} ) {
			my $msg = 'Initialization data for nic incomplete, '
				. 'must provide "interface" key-value pair.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		if ( $usedIface{$entry->{interface}} ) {
			my $msg = 'Duplicate interface device ID definition, ambiguous '
				. 'operation.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		$usedIface{$entry->{interface}} = 1;
		if (! $this -> __areNICSettingsSupported($entry)) {
			my $msg = 'Unsupported option in initialization '
				. 'structure for nic configuration';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	for my $id (keys %{$nics}) {
		if (! looks_like_number($id) ) {
			my $msg = 'Expecting integer as key for "vmnics" '
				. 'initialization.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __isInitHashValid
#------------------------------------------
sub __isInitHashValid {
	# ...
	# Verify that the initialization hash given to the constructor meets
	# all consistency and data criteria.
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	if ($this -> __hasUnsuportedVMSettings($init) ) {
		return;
	}
	if ($init->{arch}) {
		my $arch = $init->{arch};
		if (! $this -> __isArchValid($arch)) {
			my $msg = "Unsupported VM architecture specified '$arch'";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	if ($init->{ovftype}) {
		my $ovft = $init->{ovftype};
		if (! $this -> __isOVFTypeValid($ovft) ) {
			my $msg = 'Initialization data for ovftype contains '
				. "unsupported value '$ovft'.";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	if ($init->{'vmconfig-entries'}) {
		if (ref($init->{'vmconfig-entries'}) ne 'ARRAY') {
			my $msg = 'Expecting an array ref as entry of '
				. '"vmconfig-entries" in the initialization hash.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	if ($init->{vmdisks}) {
		if (! $this -> __isDiskInitValid($init->{vmdisks})) {
			return;
		}
	}
	if ($init->{vmdvd}) {
		if (! $this -> __isDVDInitValid($init->{vmdvd})) {
			return;
		}
	}
	if ($init->{vmnics}) {
		if (! $this -> __isNICInitValid($init->{vmnics})) {
			return;
		}
	}
	return 1;
}

#==========================================
# __isNICIDValid
#------------------------------------------
sub __isNICIDValid {
	# ...
	# verify that the ID given for a NIC query is valid.
	# ---
	my $this   = shift;
	my $id     = shift;
	my $caller = shift;
	my $kiwi = $this->{kiwi};
	if (! $caller ) {
		my $msg = 'Internal error __isNICIDValid called without call origin '
			. 'argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $id ) {
		my $msg = "$caller: called without providing ID for NIC query.";
		$kiwi -> error($msg);
		$kiwi -> failed ();
		return;
	}
	if (! $this->{nics}{$id} ) {
		my $msg = "$caller: invalid ID for NIC query given, no data exists.";
		$kiwi -> error($msg);
		$kiwi -> failed ();
		return;
	}
	return 1;
}

#==========================================
# __isOVFTypeValid
#------------------------------------------
sub __isOVFTypeValid {
	# ...
	# Verify that the given OVF type is supported
	# ---
	my $this = shift;
	my $ovft = shift;
	my %supportedOVFtype = map { ($_ => 1) } qw(
		povervm vmware xen zvm
	);
	if (! $supportedOVFtype{$ovft} ) {
		return;
	}
	return 1;
}


1;
