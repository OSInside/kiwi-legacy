#================
# FILE          : KIWIXMLOEMConfigData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
require Exporter;

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
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi = shift;
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	my %keywords = map { ($_ => 1) } qw(
			oem_align_partition oem_boot_title oem_bootwait
			oem_inplace_recovery oem_kiwi_initrd oem_partition_install
			oem_reboot oem_reboot_interactive oem_recovery oem_recoveryID
			oem_shutdown oem_shutdown_interactive oem_silent_boot oem_swap
			oem_swapsize oem_systemsize oem_unattended oem_unattended_id
	);
	$this->{supportedKeywords} = \%keywords;
	my %boolKW = map { ($_ => 1) } qw(
			oem_align_partition oem_bootwait oem_inplace_recovery
			oem_kiwi_initrd oem_partition_install oem_reboot
			oem_reboot_interactive oem_recovery oem_shutdown
			oem_shutdown_interactive oem_silent_boot oem_swap oem_unattended
	);
	if (! $this -> __isHashRef($init) ) {
		return;
	}
	if (! $this -> __areKeywordArgsValid($init) ) {
		return;
	}

	if ($init) {
		if (! $this -> __isInitConsistent($init) )  {
			return;
		}
		$this->{alignPart}      = $init->{oem_align_partition};
		$this->{bootTitle}      = $init->{oem_boot_title};
		$this->{bootwait}       = $init->{oem_bootwait};
		$this->{inplaceRecover} = $init->{oem_inplace_recovery};
		$this->{kiwiInitrd}     = $init->{oem_kiwi_initrd};
		$this->{partInstall}    = $init->{oem_partition_install};
		$this->{reboot}         = $init->{oem_reboot};
		$this->{rebootInter}    = $init->{oem_reboot_interactive};
		$this->{recovery}       = $init->{oem_recovery};
		$this->{recoveryID}     = $init->{oem_recoveryID};
		$this->{shutdown}       = $init->{oem_shutdown};
		$this->{shutdownInter}  = $init->{oem_shutdown_interactive};
		$this->{silentBoot}     = $init->{oem_silent_boot};
		$this->{swap}           = $init->{oem_swap};
		$this->{swapSize}       = $init->{oem_swapsize};
		$this->{systemSize}     = $init->{oem_systemsize};
		$this->{unattended}     = $init->{oem_unattended};
		$this->{unattendedID}   = $init->{oem_unattended_id};
	}

	return $this;
}

#==========================================
# getAlignPartition
#------------------------------------------
sub getAlignPartition {
	# ...
	# Return the setting for the oem-align-partition configuration
	# ---
	my $this = shift;
	return $this->{alignPart};
}

#==========================================
# getBootTitle
#------------------------------------------
sub getBootTitle {
	# ...
	# Return the setting for the oem-boot-title configuration
	# ---
	my $this = shift;
	return $this->{bootTitle};
}

#==========================================
# getBootwait
#------------------------------------------
sub getBootwait {
	# ...
	# Return the setting for the oem-bootwait configuration
	# ---
	my $this = shift;
	return $this->{bootwait};
}

#==========================================
# getInplaceRecovery
#------------------------------------------
sub getInplaceRecovery {
	# ...
	# Return the setting for the oem-inplace-recovery configuration
	# ---
	my $this = shift;
	return $this->{inplaceRecover};
}

#==========================================
# getKiwiInitrd
#------------------------------------------
sub getKiwiInitrd {
	# ...
	# Return the setting for the oem-kiwi-initrd configuration
	# ---
	my $this = shift;
	return $this->{kiwiInitrd};
}

#==========================================
# getPartitionInstall
#------------------------------------------
sub getPartitionInstall {
	# ...
	# Return the setting for the oem-partition-install configuration
	# ---
	my $this = shift;
	return $this->{partInstall};
}

#==========================================
# getReboot
#------------------------------------------
sub getReboot {
	# ...
	# Return the setting for the oem-reboot configuration
	# ---
	my $this = shift;
	return $this->{reboot};
}

#==========================================
# getRebootInteractive
#------------------------------------------
sub getRebootInteractive {
	# ...
	# Return the setting for the oem-reboot-interactive configuration
	# ---
	my $this = shift;
	return $this->{rebootInter};
}

#==========================================
# getRecovery
#------------------------------------------
sub getRecovery {
	# ...
	# Return the setting for the oem-recovery configuration
	# ---
	my $this = shift;
	return $this->{recovery};
}

#==========================================
# getRecoveryID
#------------------------------------------
sub getRecoveryID {
	# ...
	# Return the setting for the oem-recoveryID configuration
	# ---
	my $this = shift;
	return $this->{recoveryID};
}

#==========================================
# getShutdown
#------------------------------------------
sub getShutdown {
	# ...
	# Return the setting for the oem-shutdown configuration
	# ---
	my $this = shift;
	return $this->{shutdown};
}

#==========================================
# getShutdownInteractive
#------------------------------------------
sub getShutdownInteractive {
	# ...
	# Return the setting for the oem-shutdown-interactive configuration
	# ---
	my $this = shift;
	return $this->{shutdownInter};
}

#==========================================
# getSilentBoot
#------------------------------------------
sub getSilentBoot {
	# ...
	# Return the setting for the oem-silent-boot configuration
	# ---
	my $this = shift;
	return $this->{silentBoot};
}

#==========================================
# getSwap
#------------------------------------------
sub getSwap {
	# ...
	# Return the setting for the oem-swap configuration
	# ---
	my $this = shift;
	return $this->{swap};
}

#==========================================
# getSwapSize
#------------------------------------------
sub getSwapSize {
	# ...
	# Return the setting for the oem-swapsize configuration
	# ---
	my $this = shift;
	return $this->{swapSize};
}

#==========================================
# getSystemSize
#------------------------------------------
sub getSystemSize {
	# ...
	# Return the setting for the oem-systemsize configuration
	# ---
	my $this = shift;
	return $this->{systemSize};
}

#==========================================
# getUnattended
#------------------------------------------
sub getUnattended {
	# ...
	# Return the setting for the oem-unattended configuration
	# ---
	my $this = shift;
	return $this->{unattended};
}

#==========================================
# getUnattendedID
#------------------------------------------
sub getUnattendedID {
	# ...
	# Return the setting for the oem-unattended-id configuration
	# ---
	my $this = shift;
	return $this->{unattendedID};
}

#==========================================
# setAlignPartition
#------------------------------------------
sub setAlignPartition {
	# ...
	# Set the alignPart attribute, if called with no argument the
	# value is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'alignPart',
					value  => $val,
					caller => 'setAlignPartition'
				);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setBootTitle
#------------------------------------------
sub setBootTitle {
	# ...
	# Set the bootTitle attribute, if called with no argument the
	# attribute is erased
	# ---
	my $this = shift;
	my $val  = shift;
	if (! $val) {
		if ($this->{bootTitle}) {
			delete $this->{bootTitle};
		}
	} else {
		$this->{bootTitle} = $val;
	}
	return $this;
}

#==========================================
# setBootwait
#------------------------------------------
sub setBootwait {
	# ...
	# Set the bootwait attribute, if called with no argument the
	# value is set to false. If called with an argument all other potentially
	# conflicting settings are set to false
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'bootwait',
					value  => $val,
					caller => 'setBootwait'
				);
	if (! $this -> __setBooleanValue(\%settings) ) {
		return;
	}
	if ($this->{bootwait} eq 'true' ) {
		$this->{reboot}        = 'false';
		$this->{rebootInter}   = 'false';
		$this->{shutdown}      = 'false';
		$this->{shutdownInter} = 'false';
	}
	return $this;
}

#==========================================
# setInplaceRecovery
#------------------------------------------
sub setInplaceRecovery {
	# ...
	# Set the inplaceRecover attribute, if called with no argument the
	# value is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'inplaceRecover',
					value  => $val,
					caller => 'setInplaceRecovery'
				);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setKiwiInitrd
#------------------------------------------
sub setKiwiInitrd {
	# ...
	# Set the kiwiInitrd attribute, if called with no argument is given the
	# value is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'kiwiInitrd',
					value  => $val,
					caller => 'setKiwiInitrd'
				);
	return $this -> __setBooleanValue(\%settings);
}

#==========================================
# setPartitionInstall
#------------------------------------------
sub setPartitionInstall {
	# ...
	# Set the partInstall attribute, if called with no argument is given the
	# value is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'partInstall',
					value  => $val,
					caller => 'setPartitionInstall'
				);
	return $this -> __setBooleanValue(\%settings);
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
					attr   => 'reboot',
					value  => $val,
					caller => 'setReboot'
				);
	if (! $this -> __setBooleanValue(\%settings) ) {
		return;
	}
	if ($this->{reboot} eq 'true') {
		$this->{bootwait}      = 'false';
		$this->{rebootInter}   = 'false';
		$this->{shutdown}      = 'false';
		$this->{shutdownInter} = 'false';
	}
	return $this;
}

#==========================================
# setRebootInteractive
#------------------------------------------
sub setRebootInteractive {
	# ...
	# Set the rebootInter attribute, if called with no argument the
	# value is set to false. If called with an argument all other potentially
	# conflicting settings are set to false
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'rebootInter',
					value  => $val,
					caller => 'setRebootInteractive'
				);
	if (! $this -> __setBooleanValue(\%settings) ) {
		return;
	}
	if ($this->{rebootInter} eq 'true') {
		$this->{bootwait}      = 'false';
		$this->{reboot}        = 'false';
		$this->{shutdown}      = 'false';
		$this->{shutdownInter} = 'false';
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
					attr   => 'recovery',
					value  => $val,
					caller => 'setRecovery'
				);
	return $this -> __setBooleanValue(\%settings);
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
		if ($this->{recoveryID}) {
			delete $this->{recoveryID};
		}
	} else {
		$this->{recoveryID} = $val;
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
					attr   => 'shutdown',
					value  => $val,
					caller => 'setShutdown'
				);
	if (! $this -> __setBooleanValue(\%settings) ) {
		return;
	}
	if ($this->{shutdown} eq 'true') {
		$this->{bootwait}      = 'false';
		$this->{reboot}        = 'false';
		$this->{rebootInter}   = 'false';
		$this->{shutdownInter} = 'false';
	}
	return $this;
}

#==========================================
# setShutdownInteractive
#------------------------------------------
sub setShutdownInteractive {
	# ...
	# Set the shutdownInter attribute, if called with no argument the
	# value is set to false. If called with an argument all other potentially
	# conflicting settings are set to false
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'shutdownInter',
					value  => $val,
					caller => 'setShutdownInteractive'
				);
	if (! $this -> __setBooleanValue(\%settings) ) {
		return;
	}
	if ($this->{shutdownInter} eq 'true') {
		$this->{bootwait}      = 'false';
		$this->{reboot}        = 'false';
		$this->{rebootInter}   = 'false';
		$this->{shutdown}      = 'false';
	}
	return $this;
}

#==========================================
# setSilentBoot
#------------------------------------------
sub setSilentBoot {
	# ...
	# Set the silentBoot attribute, if called with no argument the
	# value is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'silentBoot',
					value  => $val,
					caller => 'setSilentBoot'
				);
	return $this -> __setBooleanValue(\%settings);
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
					attr   => 'swap',
					value  => $val,
					caller => 'setSwap'
				);
	if (! $this -> __setBooleanValue(\%settings) ) {
		return;
	}
	if (! $val || $val eq 'false') {
		if ($this->{swapSize}) {
			delete $this->{swapSize}
		}
	}
	return $this;
}

#==========================================
# setSwapSize
#------------------------------------------
sub setSwapSize {
	# ...
	# Set the swapSize attribute, if called with no argument the
	# attribute is removed and the swap attribute is set to false
	# ---
	my $this = shift;
	my $val  = shift;
	if (! $val) {
		$this->{swap} = 'false';
		if ($this->{swapSize}) {
			delete $this->{swapSize}
		}
	} else {
		$this->{swapSize} = $val;
		$this->{swap} = 'true';
	}
	return $this;
}

#==========================================
# setSystemSize
#------------------------------------------
sub setSystemSize {
	# ...
	# Set the systemSize attribute, if called with no argument the
	# attribute is removed
	# ---
	my $this = shift;
	my $val  = shift;
	if (! $val) {
		if ($this->{systemSize}) {
			delete $this->{systemSize};
		}
	} else {
		$this->{systemSize} = $val;
	}
	return $this;
}

#==========================================
# setUnattended
#------------------------------------------
sub setUnattended {
	# ...
	# Set the unattended attribute, if called with no argument the
	# value is set to false the unattendedID attribute is removed
	# ---
	my $this = shift;
	my $val  = shift;
	my %settings = (
					attr   => 'unattended',
					value  => $val,
					caller => 'setUnattended'
				);
	if (! $this -> __setBooleanValue(\%settings) ) {
		return;
	}
	if (! $val || $val eq 'false') {
		if ($this->{unattendedID}) {
			delete $this->{unattendedID};
		}
	}
	return $this;
}

#==========================================
# setUnattendedID
#------------------------------------------
sub setUnattendedID {
	# ...
	# Set the unattendedID attribute, if called with no argument the
	# attribute is removed and the unattended attribute is set to false.
	# ---
	my $this = shift;
	my $val  = shift;
	if (! $val) {
		if ($this->{unattendedID}) {
			delete $this->{unattendedID};
		}
		$this->{unattended} = 'false';
	} else {
		$this->{unattendedID} = $val;
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
	if (! $this -> __areBooleanValuesValid($init) ) {
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
	my @potConflict = qw ( oem_bootwait oem_reboot oem_reboot_interactive
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
	# Verify that the swap settings (swap and swapsize) do not conflict
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

1;
