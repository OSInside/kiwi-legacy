#================
# FILE          : KIWIXMLValidator.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to upgrade and validate the
#               : XML file, describing the image to be created
#               :
# STATUS        : Development
#----------------
package KIWIXMLValidator;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;
use XML::LibXML;
use KIWILocator;
use KIWILog;
use KIWIQX qw (qxx);
use Scalar::Util 'refaddr';

#==========================================
# Exports
#------------------------------------------
our @ISA       = qw (Exporter);
our @EXPORT_OK = qw (getDOM validate);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the validator object.
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
	my $kiwi       = shift;
	my $configPath = shift;
	my $revRecPath = shift;
	my $schemaPath = shift;
	my $xsltPath   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = KIWILog -> new ( 'tiny' );
	}
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	if ((! $configPath) || (! -f $configPath)) {
		if (! $configPath) {
			$configPath = "undefined";
		}
		$kiwi -> error ("Could not find specified configuration: $configPath");
		$kiwi -> failed ();
		return;
	}
	if (! -f $revRecPath) {
		$kiwi -> error ("Could not find specified revision file: $revRecPath");
		$kiwi -> failed ();
		return;
	}
	if (! -f $schemaPath) {
		$kiwi -> error ("Could not find specified schema: $schemaPath");
		$kiwi -> failed ();
		return;
	}
	if (! -f $xsltPath) {
		$kiwi -> error ("Could not find specified transformation: $xsltPath");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{config}   = $configPath;
	$this->{kiwi}     = $kiwi;
	$this->{revision} = $revRecPath;
	$this->{schema}   = $schemaPath;
	$this->{xslt}     = $xsltPath;
	#=========================================
	# Load the configuration, automatically upgrade if necessary
	#----------------------------------------
	my $XML = $this -> __loadControlfile ();
	if (! $XML) {
		return;
	}
	#=========================================
	# Generate the DOM
	#-----------------------------------------
	my $systemTree = $this -> __getXMLDocTree ( $XML );
	if (! $systemTree) {
		return;
	}
	$this->{systemTree} = $systemTree;
	return $this;
}

#=========================================
# getDOM
#-----------------------------------------
sub getDOM {
	# ...
	# Return the DOM for the configuration file.
	# ---
	my $this = shift;
	return $this->{systemTree};
}

#=========================================
# validate
#-----------------------------------------
sub validate {
	# ...
	# Validate the XML for syntactic correctness and consistency
	# ---
	my $this = shift;
	if (defined $this->{isValid}) {
		return $this;
	}
	#==========================================
	# validate XML document with the schema
	#------------------------------------------
	if (! $this -> __validateXML ()) {
		return;
	}
	#==========================================
	# Check data consistentcy
	#==========================================
	if (! $this -> __validateConsistency ()) {
		return;
	}
	$this->{isValid} = 1;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __checkBootSpecPresent
#------------------------------------------
sub __checkBootSpecPresent {
	# ...
	# Check that the boot attribute is set for types that require an
	# initrd.
	# ---
	my $this        = shift;
	my $systemTree  = $this->{systemTree};
	my @needsInitrd = qw /iso oem pxe split vmx/;
	my @types = $systemTree -> getElementsByTagName('type');
	for my $type (@types) {
		my $image = $type -> getAttribute('image');
		if (grep { /^$image/x } @needsInitrd) {
			my $boot = $type -> getAttribute('boot');
			if (! $boot) {
				my $kiwi = $this -> {kiwi};
				my $msg = "$image requires initrd, but no 'boot' "
					. 'attribute specified.';
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
	}
	return 1;
}
#==========================================
# __checkDefaultProfSetting
#------------------------------------------
sub __checkDefaultProfSetting {
	# ...
	# Make sure only one profile is marked as default.
	# ---
	my $this        = shift;
	my $numDefProfs = 0;
	my $systemTree  = $this->{systemTree};
	my @profiles    = $systemTree -> getElementsByTagName('profile');
	for my $profile (@profiles) {
		my $import = $profile -> getAttribute('import');
		if (defined $import && $import eq 'true') {
			$numDefProfs++;
		}
		if ($numDefProfs > 1) {
			my $kiwi = $this->{kiwi};
			my $msg = 'Only one profile may be set as the default profile by '
			. 'using the "import" attribute.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkDefaultTypeSetting
#------------------------------------------
sub __checkDefaultTypeSetting {
	# ...
	# Check that only one type is marked as primary per profile
	# ---
	my $this        = shift;
	my $systemTree  = $this->{systemTree};
	my @preferences = $systemTree -> getElementsByTagName('preferences');
	for my $pref (@preferences) {
		my $hasPrimary = 0;
		my @types = $pref -> getChildrenByTagName('type');
		for my $typeN (@types) {
			my $primary = $typeN -> getAttribute('primary');
			if (defined $primary && $primary eq 'true') {
				$hasPrimary++;
			}
			if ($hasPrimary > 1) {
				my $kiwi = $this->{kiwi};
				my $msg = 'Only one primary type may be specified per '
				. 'preferences section.';
				$kiwi -> error ($msg);
				$kiwi -> failed ();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __checkDisplaynameValid
#------------------------------------------
sub __checkDisplaynameValid {
	# ...
	# The displayname attribute of the image may not contain spaces
	# ---
	my $this = shift;
	my @imgNodes = $this->{systemTree} -> getElementsByTagName('image');
	# There is only one image node, it is the root node
	my $displayName = $imgNodes[0] -> getAttribute('displayname');
	if ($displayName) {
		my @words = split /\s/, $displayName;
		my $count = @words;
		if ($count > 1) {
			my $kiwi = $this->{kiwi};
			my $msg = 'Found white space in string provided as displayname. '
			. 'No white space permitted';
			$kiwi -> error ( $msg );
			$kiwi -> failed ();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkEC2IsFsysType
#------------------------------------------
sub __checkEC2IsFsysType {
	# ...
	# When building an EC2 image we expect the type to be a file system image.
	# ---
	my $this = shift;
	# TODO:
	# Excluding btrfs and xfs, needs testing first. There are potentisl issues
	# with both file systems as they require a boot partiotion and our current
	# setup for EC2 is to not have a boot partition.
	# Excluding clicfs and squashfs, they appear to be impractical for EC2,
	# can be enabled if someone complains
	my @supportedFSTypes = qw /ext2 ext3 ext4 reiserfs/;
	my @typeNodes = $this->{systemTree}->getElementsByTagName('type');
	for my $type (@typeNodes) {
		my $format = $type -> getAttribute('format');
		if ($format && $format eq 'ec2') {
			my $imgType = $type -> getAttribute('image');
			if (! grep { /^$imgType$/x } @supportedFSTypes) {
				my $kiwi = $this->{kiwi};
				my $msg = 'For EC2 image creation the image type must be '
					. 'one of the following supported file systems: '
					. "@supportedFSTypes";
				$kiwi -> error ( $msg );
				$kiwi -> failed ();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __checkEC2Regions
#------------------------------------------
sub __checkEC2Regions {
	# ...
	# If a region is specified for an EC2 image creation it must only be
	# specified once.
	# ---
	my $this = shift;
	my @ec2ConfNodes = $this->{systemTree}->getElementsByTagName('ec2config');
	if (! @ec2ConfNodes) {
		return 1;
	}
	my @regions = $ec2ConfNodes[0] -> getElementsByTagName('ec2region');
	my @supportedRegions =
	qw /AP-Northeast AP-Southeast EU-West SA-East US-East US-West US-West2/;
	my @selectedRegions = ();
	for my $region (@regions) {
		my $regionStr = $region -> textContent();
		if (! grep { /$regionStr/x } @supportedRegions) {
			my $msg = "Only one of @supportedRegions may be specified "
			. 'as ec2region';
			my $kiwi = $this->{kiwi};
			$kiwi -> error ( $msg );
			$kiwi -> failed ();
			return;
		}
		if (grep { /$regionStr/x } @selectedRegions) {
			my $msg = "Specified region $regionStr not unique";
			my $kiwi = $this->{kiwi};
			$kiwi -> error ( $msg );
			$kiwi -> failed ();
			return;
		}
		push @selectedRegions, $regionStr
	}
	return 1;
}

#==========================================
# __checkFilesysSpec
#------------------------------------------
sub __checkFilesysSpec {
	# ...
	# It is necessary to specify the filesystem attribute for certain
	# image types. Make sure the attribute is specified when required.
	# ---
	my $this = shift;
	my $isInvalid;
	my $kiwi = $this->{kiwi};
	my @typeNodes = $this->{systemTree} -> getElementsByTagName('type');
	my @typesReqFS = qw /oem pxe vmx/;
	for my $typeN (@typeNodes) {
		my $imgType = $typeN -> getAttribute( 'image' );
		if (grep { /$imgType/x } @typesReqFS) {
			my $hasFSattr = $typeN -> getAttribute( 'filesystem' );
			if (! $hasFSattr) {
				my $msg = 'filesystem attribute must be set for image="'
				. $imgType
				. '"';
				$kiwi -> error ( $msg );
				$kiwi -> failed ();
				$isInvalid = 1;
			}
		}
	}
	if ($isInvalid) {
		return;
	}
	return 1;
}

#==========================================
# __checkHttpsCredentialsrConsistent
#------------------------------------------
sub __checkHttpsCredentialsConsistent {
	# ...
	# username and password attributes for all repositories configured
	# as https: must have the same value. Any repository that has a
	# username attribute must also have a password attribute.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @repoNodes = $this->{systemTree} -> getElementsByTagName('repository');
	my $uname;
	my $passwd;
	my $numRep = @repoNodes;
	for my $repoNode (@repoNodes) {
		my $user = $repoNode -> getAttribute('username');
		my $pass = $repoNode -> getAttribute('password');
		if (! $user && $pass) {
			my $msg = 'Specified password without username on repository';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
		if ($user && (! $pass)) {
			my $msg = 'Specified username without password on repository';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
		if ($user && $pass) {
			my @sources = $repoNode -> getElementsByTagName ('source');
			my $path = $sources[0] -> getAttribute('path');
			if ($path !~ /^https:/) {
				next;
			}
			if (! $uname) {
				$uname = $user;
				$passwd = $pass;
				next;
			}
			if ($user ne $uname) {
				my $msg = "Specified username, $user, for https repository "
				. "does not match previously specified name, $uname. "
				. 'All credentials for https repositories must be equal.';
				$kiwi -> error ($msg);
				$kiwi -> failed();
				return;
			}
			if ($pass ne $passwd) {
				my $msg = "Specified password, $pass, for https repository "
				. "does not match previously specified password, $passwd. "
				. 'All credentials for https repositories must be equal.';
				$kiwi -> error ($msg);
				$kiwi -> failed();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __checkPatternTypeAttrConsistent
#------------------------------------------
sub __checkPatternTypeAttrConsistent {
	# ...
	# Check that the values for the patternType attribute do not conflict.
	# If all <packages> sections use profiles attributes the patternType
	# attribute value may be different for all <packages> sections. However,
	# if a default <packages> section exists, i.e. no profiles attribute
	# is used, then all patternType attribute values must be the same as
	# the value set for the default profile.
	# ---
	my $this = shift;
	my @pkgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	my $defPatternTypeVal = '';
	my $defPackSection;
	# Check if a <packages> spec without a profiles attribute exists
	for my $pkgs (@pkgsNodes) {
		if ( (! $pkgs -> getAttribute( 'profiles' ))
			&& ($pkgs -> getAttribute( 'type' ) eq 'image')) {
			$defPackSection = $pkgs;
			my $patternType = $pkgs -> getAttribute( 'patternType' );
			if ($patternType) {
				$defPatternTypeVal = $patternType;
			} else {
				$defPatternTypeVal = 'onlyRequired';
			}
			last;
		}
	}
	# Set up a hash for specified profiles for packages, if a profile is used
	# multiple times, the value of patternType must be the same for each use
	my %profPatternUseMap = ();
	for my $pkgs (@pkgsNodes) {
		if ( $pkgs -> getAttribute( 'type' ) eq 'delete') {
			next;
		}
		my $profiles = $pkgs -> getAttribute( 'profiles' );
		if ($profiles) {
			my @profNames = split /,/, $profiles;
			my $patternType = $pkgs -> getAttribute( 'patternType' );
			if (! $patternType) {
				$patternType = 'onlyRequired';
			}
			for my $profName (@profNames) {
				if (! grep { /^$profName$/x } (keys %profPatternUseMap) ) {
					$profPatternUseMap{$profName} = $patternType;
				} elsif ( $profPatternUseMap{$profName} ne $patternType) {
					my $kiwi = $this->{kiwi};
					my $msg = 'Conflicting patternType attribute values for "'
					. $profName
					. '" profile found.';
					$kiwi -> error ( $msg );
					$kiwi -> failed ();
					return;
				}
			}
		}
	}
	if (! $defPackSection) {
		# No default <packages> section exists, no additional checking
		# required
		return 1;
	}
	for my $pkgs (@pkgsNodes) {
		if (refaddr($pkgs) != refaddr($defPackSection)) {
			my $patternType = $pkgs -> getAttribute( 'patternType' );
			if ($patternType && $patternType ne $defPatternTypeVal) {
				my $kiwi = $this->{kiwi};
				my $msg = 'The specified value "'
				. $patternType
				. '" for the patternType attribute differs from the '
				. 'specified default value: "'
				. $defPatternTypeVal
				. '".';
				$kiwi -> error ( $msg );
				$kiwi -> failed ();
				return;
			}
			my $type = $pkgs -> getAttribute( 'type' );
			if (! $patternType
				&& $type ne 'bootstrap'
				&& $type ne 'delete'
				&& $defPatternTypeVal ne 'onlyRequired') {
				my $kiwi = $this->{kiwi};
				my $msg = 'The patternType attribute was omitted, but the '
				. 'base <packages> specification requires "'
				. $defPatternTypeVal
				. '" the values must match.';
				$kiwi -> error ( $msg );
				$kiwi -> failed ();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __checkPatternTypeAttrUse
#------------------------------------------
sub __checkPatternTypeAttrUse {
	# ...
	# The PatternType attribute may only be used for image and bootstrap
	# packages. Check that this is set appropriately.
	# ---
	my $this = shift;
	my @pkgsNodes = $this->{systemTree} -> getElementsByTagName("packages");
	my @notAllowedTypes = qw /delete/;
	for my $pkgs (@pkgsNodes) {
		if ($pkgs -> getAttribute( "patternType" )) {
			my $type = $pkgs -> getAttribute( "type");
			if (grep { /$type/x } @notAllowedTypes) {
				my $kiwi = $this->{kiwi};
				my $msg = 'The patternType atribute is not allowed on a '
				. "<packages> specification of type $type.";
				$kiwi -> error ( $msg );
				$kiwi -> failed ();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __checkPostDumpAction
#------------------------------------------
sub __checkPostDumpAction {
	# ...
	# Check that only one post dump action for the OEM
	# image type is set, spare oem-bootwait
	# It is reasonable to use oem-bootwait with other actions such
	# as shutdown or reboot.
	# ---
	my $this = shift;
	my @confNodes = $this->{systemTree} -> getElementsByTagName("oemconfig");
	for my $oemconfig (@confNodes) {
		my @postDumOpts = qw
		/oem-reboot
		 oem-reboot-interactive
		 oem-shutdown
		 oem-shutdown-interactive
		/;
		my $havePostDumpAction = 0;
		for my $action (@postDumOpts) {
			my @actionList = $oemconfig -> getElementsByTagName($action);
			if (@actionList) {
				my $isSet = $actionList[0]->textContent();
				if ($isSet eq "true") {
					if ($havePostDumpAction == 0) {
						$havePostDumpAction = 1;
						next;
					}
					my $kiwi = $this->{kiwi};
					$kiwi -> error('Only one post dump action may be defined');
					$kiwi -> error("Use one of @postDumOpts");
					$kiwi -> failed();
					return;
				}
			}
		}
	}
	return 1;
}

#==========================================
# __checkPreferencesDefinition
#------------------------------------------
sub __checkPreferencesDefinition {
	# ...
	# Check that only one <preference> definition exists without
	# use of the profiles attribute.
	# ---
	my $this            = shift;
	my $kiwi            = $this->{kiwi};
	my $numProfilesAttr = 0;
	my $systemTree      = $this->{systemTree};
	my @preferences     = $systemTree -> getElementsByTagName('preferences');
	my @usedProfs       = ();
	for my $pref (@preferences) {
		my $profName = $pref -> getAttribute('profiles');
		if (! $profName) {
			$numProfilesAttr++;
		} else {
			if (grep { /$profName/x } @usedProfs) {
				my $msg = 'Only one <preferences> element may reference a '
				. "given profile. $profName referenced multiple times.";
				$kiwi -> error ($msg);
				$kiwi -> failed ();
				return;
			} else {
				push @usedProfs, $profName;
			}
		}
		if ($numProfilesAttr > 1) {
			my $msg = 'Specify only one <preferences> element without using '
			. 'the "profiles" attribute.';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkPreferLicenseUnique
#------------------------------------------
sub __checkPreferLicenseUnique {
	# ...
	# Check that the prefer-license attribute is set to true on only one
	# repository per profile.
	# ---
	my $this            = shift;
	my $kiwi            = $this->{kiwi};
	my $systemTree      = $this->{systemTree};
	my @repositories = $systemTree -> getElementsByTagName('repository');
	my $errorCond;
	my %definedPrefLic;
	REPOLOOP:
	for my $repo (@repositories) {
		my $prefLic = $repo -> getAttribute('prefer-license');
		if (defined $prefLic && $prefLic eq 'true') {
			my $profiles = $repo -> getAttribute('profiles');
			if (defined $profiles) {
				my @profs = split /,/, $profiles;
				PROFLOOP:
				for my $prof (@profs) {
					if (! defined $definedPrefLic{$prof}) {
						if (defined $definedPrefLic{default}) {
							$errorCond = 1;
							last REPOLOOP;
						}
						$definedPrefLic{$prof} = 1;
					}
					else {
						$errorCond = 1;
						last REPOLOOP;
					}
				}
			}
			else {
				if (! defined $definedPrefLic{default}) {
					$definedPrefLic{default} = 1;
				}
				else {
					$errorCond = 1;
					last REPOLOOP;
				}
			}
		}
	}
	if ($errorCond) {
		my $kiwi = $this -> {kiwi};
		my $msg = 'Ambiguous license preference defined. Cannot resolve '
			. 'prefer-license=true for 2 or repositories.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __checkProfileNames
#------------------------------------------
sub __checkProfileNames {
	# ...
	# Check that a profile name does not contain whitespace, and is not
	# named "all". "all" has a special meaning in Kiwi :(
	# ---
	my $this = shift;
	my @profiles = $this->{systemTree} -> getElementsByTagName('profile');
	for my $prof (@profiles) {
		my $name = $prof -> getAttribute('name');
		if ($name =~ /\s/) {
			my $kiwi = $this -> {kiwi};
			my $msg = 'Name of a profile may not contain whitespace.';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
		if ($name =~ /(^all$)|(^kiwi_default$)/) {
			my $match = $1 || $2;
			my $kiwi = $this -> {kiwi};
			my $msg = "Name of a profile may not be set to '$match'.";
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkReferencedProfDefined
#------------------------------------------
sub __checkReferencedProfDefined {
	# ...
	# Check that any reference of profiles has a defined
	# target, i.e. the profile must be defined
	# ---
	my $this       = shift;
	my $kiwi       = $this->{kiwi};
	my $status     = 1;
	my $systemTree = $this->{systemTree};
	my @profiles = $systemTree -> getElementsByTagName('profile');
	my @profNames = ();
	for my $prof (@profiles) {
		push @profNames, $prof -> getAttribute('name');
	}
	my @nodes = ();
	push @nodes, $systemTree -> getElementsByTagName('drivers');
	push @nodes, $systemTree -> getElementsByTagName('packages');
	push @nodes, $systemTree -> getElementsByTagName('preferences');
	push @nodes, $systemTree -> getElementsByTagName('repository');
	for my $node (@nodes) {
		my $refProf = $node -> getAttribute('profiles');
		if (! $refProf) {
			next;
		}
		foreach my $profile (split (/,/,$refProf)) {
			my $foundit = 0;
			foreach my $lookup (@profNames) {
				if ($profile eq $lookup) {
					$foundit = 1;
					last;
				}
			}
			if (! $foundit) {
				my $msg = 'Found reference to profile "'
				. $profile
				. '" but this profile is not defined.';
				$kiwi -> error ($msg);
				$kiwi -> failed ();
				$status = undef;
			}
		}
	}
	return $status;
}

#==========================================
# __checkRevision
#------------------------------------------
sub __checkRevision {
	# ...
	# Check that the current revision meets the minimum requirement
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemTree = $this->{systemTree};
	my $imgnameNodeList = $systemTree -> getElementsByTagName ("image");
	if (open (my $FD, '<', $this->{revision})) {
		my $cur_rev = <$FD>; close $FD;
		my $req_rev = $imgnameNodeList
			-> get_node(1) -> getAttribute ("kiwirevision");
		if ((defined $req_rev) && ($cur_rev ne $req_rev)) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"KIWI revision mismatch, require r$req_rev got r$cur_rev"
			);
			$kiwi -> failed ();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkSysdiskNameNoWhitespace
#------------------------------------------
sub __checkSysdiskNameNoWhitespace {
	# ...
	# Check that the name attribute of the <systemdisk> element does not
	# contain white space
	# ---
	my $this        = shift;
	my $systemTree  = $this -> {systemTree};
	my @sysdiskNodes = $systemTree -> getElementsByTagName('systemdisk');
	if (! @sysdiskNodes ) {
		return 1;
	}
	for my $sysdiskNode (@sysdiskNodes) {
		my $name = $sysdiskNode -> getAttribute('name');
		if ($name) {
			if ($name =~ /\s/x) {
				my $kiwi = $this -> {kiwi};
				my $msg = 'Found whitespace in name given for systemdisk. '
					. 'Provided name may not contain whitespace.';
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __checkTypeConfigConsist
#------------------------------------------
sub __checkTypeConfigConsist {
	# ...
	# Check that a specified <*config> section is consistent with the
	# specified image type.
	# ---
	my $this        = shift;
	my $kiwi        = $this -> {kiwi};
	my $systemTree  = $this -> {systemTree};
	my @types = $systemTree -> getElementsByTagName('type');
	# /.../
	# Relationship of type children to expected type attribute values
	# allow all for cpio (initrd) type which is used to gather information
	# relevant inside the initrd
	# ----
	my %typeChildDeps = (
		'ec2config'  => 'format:ec2,cpio',
		'machine'    => 'image:vmx,split,oem,cpio',
		'oemconfig'  => 'image:oem,split,cpio',
		'pxedeploy'  => 'image:pxe,cpio',
		'size'       => ':', # generic
		'split'      => ':', # generic
		'systemdisk' => ':'  # generic
	);
	for my $typeNode (@types) {
		if (! $typeNode -> hasChildNodes()) {
			next;
		}
		my @typeConfig = $typeNode -> childNodes();
		for my $typeOpt (@typeConfig) {
			my $optName = $typeOpt->localname();
			if ($optName) {
				if ( grep { /^$optName$/x } keys %typeChildDeps ) {
					my @deps = split /:/, $typeChildDeps{$optName};
					if (@deps) {
						my $typeAttrReq    = $deps[0];
						my @typeAttrValReq = split (/,/,$deps[1]);
						my $configValue =
							$typeNode -> getAttribute ($typeAttrReq);
						my $found = 0;
						foreach my $typeAttrValReq (@typeAttrValReq) {
							if ( $configValue eq $typeAttrValReq ) {
								$found = 1; last;
							}
						}
						if ( ! $found ) {
							my $msg = 'Inconsistent configuration: Found '
							. "$optName type configuration as child of "
							. "image type $configValue.";
							$kiwi -> error($msg);
							$kiwi -> failed();
							return;
						}
					}
				} else {
					my $msg = "Unknown type configuration section '$optName'"
					. 'found. Please report to the kiwi mailing list';
					$kiwi -> warning($msg);
					$kiwi -> skipped();
					next;
				}
			}
		}
	}

	return 1;
}

#==========================================
# __checkTypeUnique
#------------------------------------------
sub __checkTypeUnique {
	# ...
	# Check that only one type with image="myName" exists per
	# <preferences section>
	# ---
	my $this        = shift;
	my $systemTree  = $this->{systemTree};
	my @preferences = $systemTree -> getElementsByTagName('preferences');
	for my $pref (@preferences) {
		my @imgTypes = ();
		my @types = $pref -> getChildrenByTagName('type');
		for my $typeN (@types) {
			my $imgT = $typeN -> getAttribute('image');
			if (grep { /$imgT/x } @imgTypes) {
				my $kiwi = $this->{kiwi};
				my $msg = 'Multiple definition of <type image="'
					. $imgT
					. '".../> found.';
				$kiwi -> error ($msg);
				$kiwi -> failed ();
				return;
			}
			push @imgTypes, $imgT
		}
	}
	return 1;
}

#==========================================
# __checkVersionDefinition
#------------------------------------------
sub __checkVersionDefinition {
	# ...
	# Check image version format
	# This check should be implemented in the schema but there is a
	# bug in libxml2 that prevents proper type validation for elements
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemTree = $this->{systemTree};
	my @versions = $systemTree -> getElementsByTagName('version');
	my $numVersions = @versions;
	if ($numVersions > 1) {
		my $msg = "Only one <version> definition expected, found $numVersions";
		$kiwi -> error  ($msg);
		$kiwi -> failed ();
		return;
	}
	my $version = $versions[0] -> textContent();
	if ($version !~ /^\d+\.\d+\.\d+$/) {
		$kiwi -> error  ("Invalid version format: $version");
		$kiwi -> failed ();
		$kiwi -> error  ("Expected 'Major.Minor.Release'");
		$kiwi -> failed ();
		return;
	}
	return 1;
}

#==========================================
# __checkVolAttrsConsist
#------------------------------------------
sub __checkVolAttrsConsist {
	# ...
	# Check that the attributes size and freespace are not used in
	# combination on the <volume> element.
	# ---
	my $this        = shift;
	my $systemTree  = $this -> {systemTree};
	my @volumeNodes = $systemTree -> getElementsByTagName('volume');
	if (! @volumeNodes ) {
		return 1;
	}
	for my $volNode (@volumeNodes) {
		my $size = $volNode -> getAttribute('size');
		my $free = $volNode -> getAttribute('freespace');
		if ($size && $free) {
			my $kiwi = $this -> {kiwi};
			my $msg = 'Found combination of "size" and "freespace" attribute '
				. 'for volume element. This is not supported.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkVolNameNoWhitespace
#------------------------------------------
sub __checkVolNameNoWhitespace {
	# ...
	# Check that the name attribute of the <volume> element does not
	# contain white space
	# ---
	my $this        = shift;
	my $systemTree  = $this -> {systemTree};
	my @volumeNodes = $systemTree -> getElementsByTagName('volume');
	if (! @volumeNodes ) {
		return 1;
	}
	for my $volNode (@volumeNodes) {
		my $name = $volNode -> getAttribute('name');
		if ($name =~ /\s/x) {
			my $kiwi = $this -> {kiwi};
			my $msg = 'Found whitespace in given volume name. '
				. 'Provided name may not contain whitespace.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __getXMLDocTree
#------------------------------------------
sub __getXMLDocTree {
	# ...
	# Generate the XML Document tree for perl
	# ---
	my $this = shift;
	my $XML  = shift;
	my $kiwi = $this->{kiwi};
	my $systemTree;
	my $systemXML = XML::LibXML -> new ();
	eval {
		$systemTree = $systemXML -> parse_fh ( $XML );
	};
	if ($@) {
		my $evaldata = $@;
		$kiwi -> error  ("Problem reading control file");
		$kiwi -> failed ();
		return;
	}
	return $systemTree;
}

#==========================================
# __loadControlfile
#------------------------------------------
sub __loadControlfile {
	# ...
	# Load the XML file and pass it to the XSLT stylesheet
	# processor for internal version conversion
	# ---
	my $this        = shift;
	my $controlFile = $this->{config};
	my $kiwi        = $this->{kiwi};
	my $skipXSLT    = 0; # For development debug purposes
	my $xslt        = $this->{xslt};
	my $XML;
	if ($skipXSLT) {
		if (! open ($XML, '-|', "cat $controlFile")) {
			$kiwi -> error ("XSL: Failed to open file $controlFile");
			$kiwi -> failed ();
			return;
		}
	} else {
		if (! open ($XML, '-|', "xsltproc $xslt $controlFile")) {
			$kiwi -> error ("XSL: Failed to open xslt processor");
			$kiwi -> failed ();
			return;
		}
	}
	binmode $XML;
	return $XML;
}
#==========================================
# __validateConsistency
#------------------------------------------
sub __validateConsistency {
	# ...
	# Validate XML data that cannot be validated through Schema and
	# structure validation. This includes conditional presence of
	# elements and attributes as well as certain values.
	# Note that any checks need to work off $this->{systemTree}. The
	# consistency check occurs prior to this object being porpulated
	# with XML data. This allows us to basically have no error checking
	# in any code that populates this object from XML data.
	# ---
	my $this = shift;
	if (! $this -> __checkBootSpecPresent()) {
		return;
	}
	if (! $this -> __checkDefaultProfSetting()) {
		return;
	}
	if (! $this -> __checkDefaultTypeSetting()){
		return;
	}
	if (! $this -> __checkDisplaynameValid()) {
		return;
	}
	if (! $this -> __checkEC2IsFsysType()) {
		return;
	}
	if (! $this -> __checkEC2Regions()) {
		return;
	}
	if (! $this -> __checkFilesysSpec()) {
		return;
	}
	if (! $this -> __checkHttpsCredentialsConsistent()) {
		return;
	}
	if (! $this -> __checkPatternTypeAttrUse()) {
		return;
	}
	if (! $this -> __checkPatternTypeAttrConsistent()) {
		return;
	}
	if (! $this -> __checkPostDumpAction()) {
		return;
	}
	if (! $this -> __checkPreferencesDefinition()) {
		return;
	}
	if (! $this -> __checkPreferLicenseUnique()) {
		return;
	}
	if (! $this -> __checkProfileNames()) {
		return;
	}
	if (! $this -> __checkReferencedProfDefined()) {
		return;
	}
	if (! $this -> __checkRevision()) {
		return;
	}
	if (! $this -> __checkSysdiskNameNoWhitespace()) {
		return;
	}
	if (! $this -> __checkTypeConfigConsist()) {
		return;
	}
	if (! $this -> __checkTypeUnique()) {
		return;
	}
	if (! $this -> __checkVersionDefinition()) {
		return;
	}
	if (! $this -> __checkVolAttrsConsist()) {
		return;
	}
	if (! $this -> __checkVolNameNoWhitespace()) {
		return;
	}
	return 1;
}

#==========================================
# __validateXML
#------------------------------------------
sub __validateXML {
	# ...
	# Validate the control file for syntactic and
	# structural correctness according to current schema
	# ---
	my $this = shift;
	my $controlFile = $this->{config};
	my $kiwi        = $this->{kiwi};
	my $systemTree  = $this->{systemTree};
	my $systemXML   = XML::LibXML -> new ();
	my $systemRNG   = XML::LibXML::RelaxNG -> new(location => $this->{schema});
	eval {
		$systemRNG ->validate ( $systemTree );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  ("Schema validation failed: $evaldata");
		$kiwi -> failed ();
		my $configStr = $systemXML -> parse_file( $controlFile ) -> toString();
		my $upgradedStr = $systemTree -> toString();
		my $upgradedContolFile = $controlFile;
		if ($configStr ne $upgradedStr) {
			$upgradedContolFile =~ s/\.xml/\.converted\.xml/;
			$kiwi -> info (
				"Automatically upgraded $controlFile to $upgradedContolFile\n"
			);
			$kiwi -> info (
				"Reported line numbers may not match the file $controlFile\n"
			);
			open (my $UPCNTFL, '>', $upgradedContolFile);
			print $UPCNTFL $upgradedStr;
			close ( $UPCNTFL );
		}
		my $locator = KIWILocator -> new( $kiwi );
		my $jingExec = $locator -> getExecPath('jing');
		if ($jingExec) {
			qxx ("$jingExec $this->{schema} $upgradedContolFile 1>&2");
			return;
		} else {
			$kiwi -> error ("$evaldata\n");
			$kiwi -> info  ("Use the jing command for more details\n");
			$kiwi -> info  ("The following requires jing to be installed\n");
			$kiwi -> info  ("jing $this->{schema} $upgradedContolFile\n");
			return;
		}
	}
	return 1;
}

1;
