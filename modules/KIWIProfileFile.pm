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

require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
require KIWIGlobals;
require KIWILog;
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
	# Module Parameters
	#------------------------------------------
	my $arg = shift;
	my $kiwi = KIWILog -> instance();
	if (! $arg) {
		my $msg = 'KIWIProfileFile: expecting file path or KIWIXML object '
			. 'as first argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	my %supportedEntries = map { ($_ => 1) } qw(
		kiwi_allFreeVolume
		kiwi_bootloader
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
		kiwi_fixedpackbootincludes
		kiwi_hwclock
		kiwi_hybrid
		kiwi_hybridpersistent
		kiwi_iname
		kiwi_installboot
		kiwi_iversion
		kiwi_keytable
		kiwi_language
		kiwi_loader_theme
		kiwi_luks
		kiwi_lvm
		kiwi_oemalign
		kiwi_oembootwait
		kiwi_oemkboot
		kiwi_oempartition_install
		kiwi_oemreboot
		kiwi_oemrebootinteractive
		kiwi_oemrecovery
		kiwi_oemrecoveryID
		kiwi_oemrecoveryInPlace
		kiwi_oemrootMB
		kiwi_oemshutdown
		kiwi_oemshutdowninteractive
		kiwi_oemsilentboot
		kiwi_oemsilentinstall
		kiwi_oemsilentverify
		kiwi_oemswap
		kiwi_oemswapMB
		kiwi_oemtitle
		kiwi_oemunattended
		kiwi_oemunattended_id
		kiwi_profiles
		kiwi_ramonly
		kiwi_revision
		kiwi_showlicense
		kiwi_size
		kiwi_splash_theme
		kiwi_strip_delete
		kiwi_strip_libs
		kiwi_strip_tools
		kiwi_syncMBR
		kiwi_testing
		kiwi_timezone
		kiwi_type
		kiwi_xendomain
	);
	#==========================================
	# Store member data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	$this->{vars} = \%supportedEntries;
	#==========================================
	# Initialize the profile data
	#------------------------------------------
	if (ref($arg) eq 'KIWIXML') {
		$this -> __initializeFromXML($arg);
		$this->{xml} = $arg;
	} elsif (-f $arg) {
		my $status = $this -> __initializeFromFile($arg);
		if (! $status) {
			return;
		}
	} else {
		my $msg = 'KIWIProfileFile: given argument is neither a KIWIXML '
			. 'object nor an existing file. Could not initialize this '
			. 'object.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	#==========================================
	# revision information
	#------------------------------------------
	if (! $this->{profile}{kiwi_revision}) {
		my $rev  = "unknown";
		my $revFl = KIWIGlobals -> instance() -> getKiwiConfig() ->{Revision};
		if (open (my $FD, '<', $revFl)) {
			$rev = <$FD>;
			my $status = close $FD;
			if (! $status) {
				$kiwi -> info('Could not close revision file');
				$kiwi -> skipped();
			}
			$rev =~ s/\n//msxg;
		}
		$this->{profile}{kiwi_revision} = $rev;
	}

	return $this;
}

#==========================================
# addEntry
#------------------------------------------
sub addEntry {
	# ...
	# Add an entry to the profile data. If the value is empty an existing
	# entry will be deleted
	# NOTE, the onus is on the client to avoid duplicates in the data
	# ---
	my $this = shift;
	my $key = shift;
	my $value = shift;
	my $kiwi = $this->{kiwi};
	if (! $key) {
		my $msg = 'addEntry: expecting a string as first argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! defined $value) {
		delete $this->{profile}{$key};
	}
	my %allowedVars = %{$this->{vars}};
	if ((! $allowedVars{$key}) && ($key !~ /^kiwi_LVM_LV/msx)) {
		my $msg = "Unrecognized variable: $key";
		$kiwi -> info($msg);
		$kiwi -> skipped();
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
# updateFromFile
#------------------------------------------
sub updateFromFile {
	# ...
	# Update the existing data from a file.
	# NOTE, the onus is on the client to avoid duplicates in the data
	# ---
	my $this = shift;
	my $path = shift;
	my $kiwi = $this->{kiwi};
	if (! $path || (! -f $path)) {
		my $msg = 'updateFromFile: expecting existing file as first argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $status = open my $PROFILE, '<', $path;
	if (! $status) {
		my $msg = "Could not read given file: $path";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @ctx = <$PROFILE>;
	$status = close $PROFILE;
	if (! $status) {
		my $msg = "Could not close file: $path";
		$kiwi -> info($msg);
		$kiwi -> skipped();
	}
	for my $line (@ctx) {
		my ($key, $value) = split /=/msx, $line;
		chomp $value;
		$value =~ s/'//msxg;
		my $res = $this -> addEntry($key, $value);
		if (! $res) {
			return;
		}
	}
	return $this;
}


#==========================================
# updateFromXML
#------------------------------------------
sub updateFromXML {
	# ...
	# Update the existing data from an XML object.
	# NOTE, the onus is on the client to avoid duplicates in the data
	# ---
	my $this = shift;
	my $xml = shift;
	my $kiwi = $this->{kiwi};
	if (! $xml || ref($xml) ne 'KIWIXML') {
		my $msg = 'updateFromXML: expecting KIWIXML object as first argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	# All list entries using a space as separator
	my %listObjData = (
#        kiwi_delete                => $xml -> getPackagesToDelete(),
#        kiwi_fixedpackbootincludes => $xml -> getBootIncludePackages(),
#        kiwi_strip_delete          => $xml -> getFilesToDelete(),
#        kiwi_strip_tools           => $xml -> getToolsToKeep(),
#        kiwi_strip_libs            => $xml -> getLibsToKeep(),
	);
	for my $entry (keys %listObjData) {
		my @names;
		my $objs = $listObjData{$entry};
		for my $obj (@{$objs}) {
			push @names, $obj -> getName();
		}
		if (@names) {
			my $addItem = join q{ }, @names;
			$this -> addEntry($entry, $addItem);
		}
	}
	# Process the drivers
	my $drivers = $xml -> getDrivers();
	my @drvNames;
	for my $drv (@{$drivers}) {
		push @drvNames, $drv -> getName();
	}
	if (@drvNames) {
		my $addItem = join q{,}, @drvNames;
		$this -> addEntry('kiwi_drivers', $addItem);
	}
	my $type = $xml -> getImageType();
#    my $comp = $type -> getCompressed();
#    if ($comp && $comp eq 'true') {
#        $this -> addEntry('kiwi_compressed', 'yes');
#    }
#    # Process license file data
#    my $prefs = $xml -> getPreferences();
#    my $lics = $prefs -> getShowLic();
#    my $addItem = join q{ }, @{$lics};
#    if ($addItem) {
#        $this -> addEntry('kiwi_showlicense', $addItem);
#    }
	return $this;
}

#==========================================
# writeProfile
#------------------------------------------
sub writeProfile {
	# ...
	# Write the profile data to the given path
	# ---
	my $this = shift;
	my $targetDir = shift;
	my $kiwi = $this->{kiwi};
	if (!$targetDir || ! -d $targetDir) {
		my $msg = 'KIWIProfileFile:writeProfile expecting directory '
			. 'as argument.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{profile}) {
		my %profile = %{$this->{profile}};
		my @definedVars = keys %profile;
		my @vars = sort @definedVars;
		my $status = open my $PROFILE, '>', $targetDir . '/.profile';
		if (! $status) {
			my $msg = "Could not open '$targetDir/.profile' for writing";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		for my $var (@vars) {
			print $PROFILE $var . q{='} . $profile{$var} . q{'} . "\n";
		}
		$status = close $PROFILE;
		if (! $status) {
			my $msg = "Could not close file: $targetDir/.profile";
			$kiwi -> info($msg);
			$kiwi -> skipped();
		}
		return 1;
	}
	my $msg = 'No data for profile file defined';
	$kiwi -> info($msg);
	$kiwi -> skipped();
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __initializeFromFile
#------------------------------------------
sub __initializeFromFile {
	# ...
	# Initialize the data from an existing file
	# ---
	my $this = shift;
	my $path = shift;
	my %profile;
	$this->{profile} = \%profile;
	return $this -> updateFromFile($path);
}

#==========================================
# __initializeFromXML
#------------------------------------------
sub __initializeFromXML {
	# ...
	# Initialize the data from the given XML object
	# ---
	my $this = shift;
	my $xml  = shift;
	my %profile;
	$this->{profile} = \%profile;
	return $this -> updateFromXML($xml);
}

1;
