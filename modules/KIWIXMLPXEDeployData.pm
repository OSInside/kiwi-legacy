#================
# FILE          : KIWIXMLPXEDeployData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <pxedeploy> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLPXEDeployData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
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
# constants
#------------------------------------------
Readonly my $MAX_PART_ID => 4;
Readonly my $MIN_PART_ID => 1;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLPXEDeployData object
	#
	# Internal data structure
	#
	# this = {
	#     blocksize    = '',
	#     device       = '',
	#     initrd       = '',
	#     kernel       = '',
	#     partitions   = {
	#         ID[+] = {
	#             mountpoint = '',
	#             size       = '',
	#             target     = '',
	#             type       = ''
	#     }
	#     server       = '',
	#     timeout      = '',
	#     unionRO      = '',
	#     unionRW      = '',
	#     unionType    = ''
	# }
	#
	# The key, ID (key) in the partitions hash is equal to the "number"
	# attribute in the config.xml file.
	#
	# The <pxedeploy> element has a <configuration> child element. This
	# child relation ship is enforced at the XML class level and the
	# configuration data is not accessible from this class.
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
		blocksize
		device
		initrd
		kernel
		partitions
		server
		timeout
		unionRO
		unionRW
		unionType
	);
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
		$this->{blocksize}     = $init->{blocksize};
		$this->{device}        = $init->{device};
		$this->{initrd}        = $init->{initrd};
		$this->{kernel}        = $init->{kernel};
		$this->{partitions}    = $init->{partitions};
		$this->{server}        = $init->{server};
		$this->{timeout}       = $init->{timeout};
		$this->{unionRO}       = $init->{unionRO};
		$this->{unionRW}       = $init->{unionRW};
		$this->{unionType}     = $init->{unionType};
	}
	#==========================================
	# Apply defaults
	#------------------------------------------
	if (! $this->{blocksize} ) {
		$this->{blocksize} = '4096';
	}
	if (! $this->{server} ) {
		$this->{server} = '192.168.1.1';
	}
	if (! $this->{unionType} ) {
		$this->{unionType} = "clicfs";
	}
	if ($this->{partitions}) {
		$this -> __applyPartitionDefaultSettings();
	}
	return $this;
}

#==========================================
# createPartition
#------------------------------------------
sub createPartition {
	# ...
	# Create a patrition entry, return the ID of the partition entry
	# ---
	my $this     = shift;
	my $partInfo = shift;
	my $kiwi = $this->{kiwi};
	if (ref($partInfo) ne 'HASH') {
		my $msg = 'createPartition: expecting hash ref as argument.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %partSupported = map { ($_ => 1) } qw (
		mountpoint
		number
		size
		target
		type
	);
	for my $key (keys %{$partInfo}) {
		if (! $partSupported{$key} ) {
			my $msg = 'createPartition: unsupported option in '
				. "argument hash for partition setup, found '$key'";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	if (! defined $partInfo->{number} || ! $partInfo->{type} ) {
		my $msg = 'createPartition: must provide "number" and "type" entry '
			. 'in hash arg.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $id = int $partInfo->{number};
	if ($id < $MIN_PART_ID || $id > $MAX_PART_ID) {
		my $msg = 'createPartition: invalid partition ID specified, must be '
			. 'between 1 and 4.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{partitions}{$id}) {
		my $msg = 'createPartition: overwriting data for partition with id: '
			. "'$id'.";
		$kiwi -> info($msg);
		if ($partInfo->{mountpoint}) {
			$this->{partitions}{$id}{mountpoint} = $partInfo->{mountpoint};
		}
		if ($partInfo->{size}) {
			$this->{partitions}{$id}{size} = $partInfo->{size};
		}
		if ($partInfo->{target}) {
			if ($partInfo->{target} ne 'false') {
				$this->{partitions}{$id}{target} = 'true';
			} else {
				$this->{partitions}{$id}{target} = $partInfo->{target};
			}
		} else {
			$this->{partitions}{$id}{target} = 'false';
		}
		$this->{partitions}{$id}{type} = $partInfo->{type};
		$kiwi -> done();
		return $id;
	}
	my %partData = (
		mountpoint => $partInfo->{mountpoint},
		size       => $partInfo->{size},
		target     => $partInfo->{target},
		type       => $partInfo->{type}
	);
	$this->{partitions}{$id} = \%partData;
	$this -> __applyPartitionDefaultSettings();
	return $id;
}

#==========================================
# createUnionFSConfig
#------------------------------------------
sub createUnionFSConfig {
	# ...
	# Create the union fs configuration settings
	# ---
	my $this      = shift;
	my $unionRO   = shift;
	my $unionRW   = shift;
	my $unionType = shift;
	my $kiwi = $this->{kiwi};
	if (! $unionRO || ! $unionRW || ! $unionType) {
		my $msg = 'createUnionFSConfig: must be called with 3 arguments, '
			. 'unionRO, unionRW, unionType.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($unionType ne 'clicfs') {
		my $msg = 'createUnionFSConfig: unionType argument must be "clicfs".';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{unionRO}) {
		my $msg = 'createUnionFSConfig: overwriting existing union fs config.';
		$kiwi -> info($msg);
		$kiwi -> done();
	}
	$this->{unionRO}   = $unionRO;
	$this->{unionRW}   = $unionRW;
	$this->{unionType} = $unionType;
	return $this;
}

#==========================================
# getBlocksize
#------------------------------------------
sub getBlocksize {
	# ...
	# Return the blocksize value
	# ---
	my $this = shift;
	return $this->{blocksize};
}

#==========================================
# getDevice
#------------------------------------------
sub getDevice {
	# ...
	# Return the target device for the install
	# ---
	my $this = shift;
	return $this->{device};
}

#==========================================
# getInitrd
#------------------------------------------
sub getInitrd {
	# ...
	# Return the location, including file, of the initrd to be used
	# ---
	my $this = shift;
	return $this->{initrd};
}

#==========================================
# getKernel
#------------------------------------------
sub getKernel {
	# ...
	# Return the location, including file, of the kernel to be used
	# ---
	my $this = shift;
	return $this->{kernel};
}

#==========================================
# getPartitionIDs
#------------------------------------------
sub getPartitionIDs {
	# ...
	# Return a sorted array ref of the partition IDs configured
	# ---
	my $this = shift;
	if ($this->{partitions}) {
		my @partIDs = sort keys %{$this->{partitions}};
		return \@partIDs;
	}
	return;
}

#==========================================
# getPartitionMountpoint
#------------------------------------------
sub getPartitionMountpoint {
	# ...
	# Return the configured mountpoint for the partition with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isPartitionIDValid($id, 'getPartitionMountpoint')) {
		return;
	}
	return $this->{partitions}{$id}{mountpoint};
}

#==========================================
# getPartitionNumber
#------------------------------------------
sub getPartitionNumber {
	# ...
	# Return the configured partition number  for the partition with the
	# given ID, partition numbers are identical to the ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isPartitionIDValid($id, 'getPartitionNumber')) {
		return;
	}
	return $id;
}

#==========================================
# getPartitionSize
#------------------------------------------
sub getPartitionSize {
	# ...
	# Return the configured partition size for the partition with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isPartitionIDValid($id, 'getPartitionSize') ) {
		return;
	}
	return $this->{partitions}{$id}{size};
}

#==========================================
# getPartitionTarget
#------------------------------------------
sub getPartitionTarget {
	# ...
	# Return the configured target for the partition with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isPartitionIDValid($id, 'getPartitionTarget') ) {
		return;
	}
	return $this->{partitions}{$id}{target};
}

#==========================================
# getPartitionType
#------------------------------------------
sub getPartitionType {
	# ...
	# Return the configured type for the partition with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	if (! $this->__isPartitionIDValid($id, 'getPartitionType') ) {
		return;
	}
	return $this->{partitions}{$id}{type};
}

#==========================================
# getServer
#------------------------------------------
sub getServer {
	# ...
	# Return the IP of the PXE server
	# ---
	my $this = shift;
	return $this->{server};
}

#==========================================
# getTimeout
#------------------------------------------
sub getTimeout {
	# ...
	# Return the timeout value configured for the PXE
	# ---
	my $this = shift;
	return $this->{timeout};
}

#==========================================
# getUnionRO
#------------------------------------------
sub getUnionRO {
	# ...
	# Return the read-only device for the overlay file system
	# ---
	my $this = shift;
	return $this->{unionRO};
}

#==========================================
# getUnionRW
#------------------------------------------
sub getUnionRW {
	# ...
	# Return the read/write device for the overlay file system
	# ---
	my $this = shift;
	return $this->{unionRW};
}

#==========================================
# getUnionType
#------------------------------------------
sub getUnionType {
	# ...
	# Return the type of the overlay file system
	# ---
	my $this = shift;
	return $this->{unionType};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new('pxedeploy');
	$element -> setAttribute('blocksize', $this -> getBlocksize());
	$element -> setAttribute('server', $this -> getServer());
	my %initBootImg = (
		parent    => $element,
		childName => 'initrd',
		text      => $this -> getInitrd()
	);
	$element = $this -> p_addElement(\%initBootImg);
	my %initKern = (
		parent    => $element,
		childName => 'kernel',
		text      => $this -> getKernel()
	);
	$element = $this -> p_addElement(\%initKern);
	my @pIDs = @{$this -> getPartitionIDs()};
	if (@pIDs) {
		my $partElem = XML::LibXML::Element -> new('partitions');
		my $dev = $this -> getDevice();
		if ($dev) {
			$partElem -> setAttribute('device', $dev);
		}
		for my $id (@pIDs) {
			my $pElem = XML::LibXML::Element -> new('partition');
			my $mount = $this -> getPartitionMountpoint($id);
			if ($mount && $mount ne 'x') {
				$pElem -> setAttribute('mountpoint', $mount);
			}
			$pElem -> setAttribute('number', $this -> getPartitionNumber($id));
			my $size = $this -> getPartitionSize($id);
			if ($size && $size ne 'x') {
				$pElem -> setAttribute('size', $size);
			}
			my $target = $this -> getPartitionTarget($id);
			if ($target && $target == 1) {
				$pElem -> setAttribute('target', 'true');
			}
			$pElem -> setAttribute('type', $this -> getPartitionType($id));
			$partElem -> addChild($pElem);
		}
		$element -> addChild($partElem);
	}
	my %initTO = (
		parent    => $element,
		childName => 'timeout',
		text      => $this -> getTimeout()
	);
	$element = $this -> p_addElement(\%initTO);
	my $unionRO = $this -> getUnionRO();
	if ($unionRO) {
		my $uElem = XML::LibXML::Element -> new('union');
		$uElem -> setAttribute('ro', $unionRO);
		$uElem -> setAttribute('rw', $this -> getUnionRW());
		$uElem -> setAttribute('type', $this -> getUnionType());
		$element -> addChild($uElem);
	}
	return $element;
}

#==========================================
# setBlocksize
#------------------------------------------
sub setBlocksize {
	# ...
	# Set the blocksize value, rest to the default if no value is given
	# ---
	my $this   = shift;
	my $blockS = shift;
	if (! $blockS) {
		$blockS = '4096';
		my $kiwi = $this->{kiwi};
		my $msg = 'Resetting blocksize to default, 4096';
		$kiwi -> info($msg);
		$kiwi -> done();
	}
	$this->{blocksize} = $blockS;
	return $this;
}

#==========================================
# setDevice
#------------------------------------------
sub setDevice {
	# ...
	# Set the target device for the install
	# ---
	my $this   = shift;
	my $device = shift;
	if (! $device) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setDevice: no target device given, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{device} = $device;
	return $this;
}

#==========================================
# setInitrd
#------------------------------------------
sub setInitrd {
	# ...
	# Set the location, including file, of the initrd to be used
	# ---
	my $this   = shift;
	my $initrd = shift;
	if (! $initrd) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setInitrd: no initrd specified, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{initrd} = $initrd;
	return $this;
}

#==========================================
# setKernel
#------------------------------------------
sub setKernel {
	# ...
	# Return the location, including file, of the kernel to be used
	# ---
	my $this   = shift;
	my $kernel = shift;
	if (! $kernel) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setKernel: no kernel specified, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{kernel} = $kernel;
	return $this;
}

#==========================================
# setPartitionMountpoint
#------------------------------------------
sub setPartitionMountpoint {
	# ...
	# Set the mountpoint for the partition with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	my $mntP = shift;
	my $kiwi = $this->{kiwi};
	$id = int $id;
	if (! $mntP) {
		my $msg = 'setPartitionMountpoint: must provide 2nd argument '
			. 'specifying mount point.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{partitions}) {
		my $msg = 'setPartitionMountpoint: no partition data set, call '
			. 'createPartition first.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isPartitionIDValid($id, 'setPartitionMountpoint') ) {
		return;
	}
	$this->{partitions}{$id}{mountpoint} = $mntP;
	return $this;
}

#==========================================
# setPartitionSize
#------------------------------------------
sub setPartitionSize {
	# ...
	# Set the configured partition size for the partition with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	my $size = shift;
	my $kiwi = $this->{kiwi};
	$id = int $id;
	if (! $size) {
		my $msg = 'setPartitionSize: must provide 2nd argument '
			. 'specifying partition size.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{partitions}) {
		my $msg = 'setPartitionSize: no partition data set, call '
			. 'createPartition first.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isPartitionIDValid($id, 'setPartitionSize') ) {
		return;
	}
	$this->{partitions}{$id}{size} = $size;
	return $this;
}

#==========================================
# setPartitionTarget
#------------------------------------------
sub setPartitionTarget {
	# ...
	# Set the configured target for the partition with the given ID
	# ---
	my $this   = shift;
	my $id     = shift;
	my $target = shift;
	my $kiwi = $this->{kiwi};
	$id = int $id;
	if (! $target) {
		my $msg = 'setPartitionTarget: must provide 2nd argument '
			. 'specifying target device.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{partitions}) {
		my $msg = 'setPartitionTarget: no partition data set, call '
			. 'createPartition first.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isPartitionIDValid($id, 'setPartitionTarget') ) {
		return;
	}
	$this->{partitions}{$id}{target} = $target;
	return $this;
}

#==========================================
# setPartitionType
#------------------------------------------
sub setPartitionType {
	# ...
	# Return the configured type for the partition with the given ID
	# ---
	my $this = shift;
	my $id   = shift;
	my $type = shift;
	my $kiwi = $this->{kiwi};
	$id = int $id;
	if (! $type) {
		my $msg = 'setPartitionType: must provide 2nd argument '
			. 'specifying partition type.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{partitions}) {
		my $msg = 'setPartitionType: no partition data set, call '
			. 'createPartition first.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->__isPartitionIDValid($id, 'setPartitionType') ) {
		return;
	}
	$this->{partitions}{$id}{type} = $type;
	return $this;
}

#==========================================
# setServer
#------------------------------------------
sub setServer {
	# ...
	# Set the IP of the PXE server
	# ---
	my $this  = shift;
	my $srvIP = shift;
	if (! $srvIP) {
		$srvIP = '192.168.1.1';
		my $kiwi = $this->{kiwi};
		my $msg = 'Resetting server IP to default, 192.168.1.1';
		$kiwi -> info($msg);
		$kiwi -> done();
	}
	# Choosing not to validate the value for being a valid IPv4 or IPv6
	# address, if verification is needed at a later point use Net::IP module
	$this->{server} = $srvIP;
	return $this;
}

#==========================================
# setTimeout
#------------------------------------------
sub setTimeout {
	# ...
	# Set the timeout value configured for the PXE
	# ---
	my $this    = shift;
	my $timeout = shift;
	if (! $timeout) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setTimeout: no timeout value given, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{timeout} = $timeout;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __applyPartitionDefaultSettings
#------------------------------------------
sub __applyPartitionDefaultSettings {
	# ...
	# Apply default settings for partition data if it was not specified
	# ---
	my $this = shift;
	for my $id (keys %{$this->{partitions}}) {
		if (! $this->{partitions}{$id}{mountpoint}) {
			$this->{partitions}{$id}{mountpoint} = 'x';
		}
		if (! $this->{partitions}{$id}{size}) {
			$this->{partitions}{$id}{size} = 'x';
		}
		my $tgt = $this->{partitions}{$id}{target};
		if (! $tgt || $tgt eq 'false') {
			$this->{partitions}{$id}{target} = 0;
		} else {
			$this->{partitions}{$id}{target} = 1;
		}
	}
	return $this;
}

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
	if (! $this -> __isPartitionConfigValid($init) ) {
		return;
	}
	if (! $this -> __isUnionConfigValid($init)) {
		return;
	}
	return 1;
}

#==========================================
# __isPartitionConfigValid
#------------------------------------------
sub __isPartitionConfigValid {
	# ...
	# Verify that the initialization hash given to the constructor contains
	# a valid setup for the partitions.
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	if (! $init->{partitions}) {
		return 1;
	}
	if (ref($init->{partitions}) ne 'HASH') {
		my $msg = 'Expecting hash ref as entry for partitions key in '
			. 'initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @pIDs = keys %{$init->{partitions}};
	my $numIDs = @pIDs;
	if ($numIDs > $MAX_PART_ID) {
		my $msg = 'Specified more than 4 partitions in initialization '
			. 'hash.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @sPIDs = sort @pIDs;
	if ($sPIDs[-1] > $MAX_PART_ID) {
		my $msg = 'Specified a parttion number larger than 4 in '
			. 'initialization hash.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %partSupported = map { ($_ => 1) } qw (
		mountpoint size target type
	);
	for my $entry (values %{$init->{partitions}}) {
		for my $key (keys %{$entry}) {
			if (! $partSupported{$key} ) {
				my $msg = 'Unsupported option in initialization structure '
					. "for partition initialization, found '$key'";
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
		if (! $entry->{type} ) {
			my $msg = 'Partition configuration without "type" '
				. 'specification given.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __isPartitionIDValid
#------------------------------------------
sub __isPartitionIDValid {
	# ...
	# Verify that the given partition ID is valid
	# ---
	my $this   = shift;
	my $id     = shift;
	my $caller = shift;
	my $kiwi = $this->{kiwi};
	if (! $caller ) {
		my $msg = 'Internal error __isPartitionIDValid called without call '
			. 'origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! defined $id ) {
		my $msg = "$caller: must be called with id argument.";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($id < $MIN_PART_ID || $id > $MAX_PART_ID) {
		my $msg = 'Invalid partition ID specified, must be between 1 and 4.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $this->{partitions}{$id} ) {
		my $msg = "No partition data configured for partition with ID '$id'.";
		$kiwi -> warning($msg);
		$kiwi -> skipped ();
		return;
	}
	return 1;
}

#==========================================
# __isUnionConfigValid
#------------------------------------------
sub __isUnionConfigValid {
	# ...
	# Verify that the initialization hash given to the constructor contains
	# a valid setup for the union fs if given.
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my $inclMsg = 'Incomplete initialization hash "unionRO", '
		. '"unionRW", and "unionType" must be specified together.';
	if ($init->{unionRO}) {
		if (! $init->{unionRW} || ! $init->{unionType} ) {
			$kiwi -> error($inclMsg);
			$kiwi -> failed();
			return;
		}
	}
	if ($init->{unionRW}) {
		if (! $init->{unionRO} || ! $init->{unionType} ) {
			$kiwi -> error($inclMsg);
			$kiwi -> failed();
			return;
		}
	}
	if ($init->{unionType}) {
		if ($init->{unionType} ne 'clicfs') {
			my $msg = 'Type specified for union fs is not supported, only '
				. '"clicfs" is supported';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		if (! $init->{unionRO} || ! $init->{unionRW} ) {
			$kiwi -> error($inclMsg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

1;
