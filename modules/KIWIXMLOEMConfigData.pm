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
		my %initStruct = %{$init};
		my %supported = map { ($_ => 1) } qw(
			oem-align-partition oem-boot-title oem-bootwait
			oem-inplace-recovery oem-kiwi-initrd oem-partition-install
			oem-reboot oem-reboot-interactive oem-recovery oem-recoveryID
			oem-shutdown oem-shutdown-interactive oem-silent-boot oem-swap
			oem-swapsize oem-systemsize oem-unattended oem-unattended-id
		);
		for my $key (keys %initStruct) {
			if (! $supported{"$key"} ) {
				my $msg = 'Unsupported option in initialization structure '
					. "found '$key'";
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
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
		$this->{alignPart}      = $init->{'oem-align-partition'};
		$this->{bootTitle}      = $init->{'oem-boot-title'};
		$this->{bootwait}       = $init->{'oem-bootwait'};
		$this->{inplaceRecover} = $init->{'oem-inplace-recovery'};
		$this->{kiwiInitrd}     = $init->{'oem-kiwi-initrd'};
		$this->{partInstall}    = $init->{'oem-partition-install'};
		$this->{reboot}         = $init->{'oem-reboot'};
		$this->{rebootInter}    = $init->{'oem-reboot-interactive'};
		$this->{recovery}       = $init->{'oem-recovery'};
		$this->{recoveryID}     = $init->{'oem-recoveryID'};
		$this->{shutdown}       = $init->{'oem-shutdown'};
		$this->{shutdownInter}  = $init->{'oem-shutdown-interactive'};
		$this->{silentBoot}     = $init->{'oem-silent-boot'};
		$this->{swap}           = $init->{'oem-swap'};
		$this->{swapSize}       = $init->{'oem-swapsize'};
		$this->{systemSize}     = $init->{'oem-systemsize'};
		$this->{unattended}     = $init->{'oem-unattended'};
		$this->{unattendedID}   = $init->{'oem-unattended-id'};
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
	if (! $val) {
		$this->{alignPart} = 'false';
	} else {
		$this->{alignPart} = $val;
	}
	return $this;
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
	if (! $val) {
		$this->{bootwait} = 'false';
	} else {
		$this->{bootwait}      = 'true';
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
	if (! $val) {
		$this->{inplaceRecover} = 'false';
	} else {
		$this->{inplaceRecover} = 'true';
	}
	return $this;
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
	if (! $val) {
		$this->{kiwiInitrd} = 'false';
	} else {
		$this->{kiwiInitrd} = 'true';
	}
	return $this;
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
	if (! $val) {
		$this->{partInstall} = 'false';
	} else {
		$this->{partInstall} = 'true';
	}
	return $this;
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
	if (! $val) {
		$this->{reboot} = 'false';
	} else {
		$this->{bootwait}      = 'false';
		$this->{reboot}        = 'true';
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
	if (! $val) {
		$this->{rebootInter} = 'false';
	} else {
		$this->{bootwait}      = 'false';
		$this->{reboot}        = 'false';
		$this->{rebootInter}   = 'true';
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
	if (! $val) {
		$this->{recovery} = 'false';
	} else {
		$this->{recovery} = 'true';
	}
	return $this;
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
	if (! $val) {
		$this->{shutdown} = 'false';
	} else {
		$this->{bootwait}      = 'false';
		$this->{reboot}        = 'false';
		$this->{rebootInter}   = 'false';
		$this->{shutdown}      = 'true';
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
	if (! $val) {
		$this->{shutdownInter} = 'false';
	} else {
		$this->{bootwait}      = 'false';
		$this->{reboot}        = 'false';
		$this->{rebootInter}   = 'false';
		$this->{shutdown}      = 'false';
		$this->{shutdownInter} = 'true';
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
	if (! $val) {
		$this->{silentBoot} = 'false';
	} else {
		$this->{silentBoot} = 'true';
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
	if (! $val) {
		$this->{swap} = 'false';
		if ($this->{swapSize}) {
			delete $this->{swapSize}
		}
	} else {
		$this->{swap} = 'true';
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
	if (! $val) {
		$this->{unattended} = 'false';
		if ($this->{unattendedID}) {
			delete $this->{unattendedID};
		}
	} else {
		$this->{unattended} = 'true';
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
# __noConflictingSetting
#------------------------------------------
sub __noConflictingSettingPostInst {
	# ...
	# Verify that the post install option settings to not conflict
	# ---
	my $this = shift;
	my $init = shift;
	my @potConflict = qw ( oem-bootwait oem-reboot oem-reboot-interactive
						oem-shutdown oem-shutdown-interactive
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
	if ($init->{'oem-swapsize'}) {
		if (! $init->{'oem-swap'} || $init->{'oem-swap'} eq 'false') {
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
	if ($init->{'oem-unattended-id'}) {
		if (! $init->{'oem-unattended'}
			|| $init->{'oem-unattended'}  eq 'false') {
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
