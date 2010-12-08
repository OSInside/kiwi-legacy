#================
# FILE          : KIWIXMLValidator.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
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
use KIWILog;
use KIWIQX;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (getDOM validate);

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
		$kiwi = new KIWILog();
	}
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	if (! -f $configPath) {
		$kiwi -> error ("Could not find specified configuration: $configPath");
		$kiwi -> failed ();
		return undef;
	}
	if (! -f $revRecPath) {
		$kiwi -> error ("Could not find specified revision file: $revRecPath");
		$kiwi -> failed ();
		return undef;
	}
	if (! -f $schemaPath) {
		$kiwi -> error ("Could not find specified schema: $schemaPath");
		$kiwi -> failed ();
		return undef;
	}
	if (! -f $xsltPath) {
		$kiwi -> error ("Could not find specified transformation: $xsltPath");
		$kiwi -> failed ();
		return undef;
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
		return undef;
	}
	#=========================================
	# Generate the DOM
	#-----------------------------------------
	my $systemTree = $this -> __getXMLDocTree ( $XML );
	if (! $systemTree) {
		return undef;
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
		return undef;
	}
	#==========================================
	# Check data consistentcy
	#==========================================
	if (! $this -> __validateConsistency ()) {
		return undef;
	}
	$this->{isValid} = 1;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
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
			my $msg = 'Only one profile may be set as the dafault profile by '
			. 'using the "import" attrinute.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return undef;
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
				my $msg = 'Only one primary type my be specified per '
				. 'preferences section.';
				$kiwi -> error ($msg);
				$kiwi -> failed ();
				return undef;
			}
		}
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
	my @typeNodes = $this->{systemTree} -> getElementsByTagName("type");
	my @typesReqFS = qw /oem pxe usb vmx/;
	for my $typeN (@typeNodes) {
		my $imgType = $typeN -> getAttribute( "image" );
		if (grep /$imgType/, @typesReqFS) {
			my $hasFSattr = $typeN -> getAttribute( "filesystem" );
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
		return undef;
	}
	return 1;
}

#==========================================
# __checkPostDumpAction
#------------------------------------------
sub __checkPostDumpAction {
	# ...
	# Check that only one post dump action for the OEM
	# image type is set
	# ---
	my $this = shift;
	my @confNodes = $this->{systemTree} -> getElementsByTagName("oemconfig");
	for my $oemconfig (@confNodes) {
		my @postDumOpts = qw
		/oem-bootwait oem-reboot
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
					return undef;
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
	#
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
			if (grep /$profName/, @usedProfs) {
				my $msg = 'Only one <preferences> element may reference a '
				. "given profile. $profName referenced multiple times.";
				$kiwi -> error ($msg);
				$kiwi -> failed ();
				return undef;
			} else {
				push @usedProfs, $profName;
			}
		}
		if ($numProfilesAttr > 1) {
			my $msg = 'Specify only one <preferences> element without using '
			. 'the "profiles" attribute.';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return undef;
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
				my $msg = "Found reference to profile $profile "
				. 'but this profile does not exist.';
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
	if (open (my $FD,$this->{revision})) {
		my $cur_rev = <$FD>; close $FD;
		my $req_rev = $imgnameNodeList
			-> get_node(1) -> getAttribute ("kiwirevision");
		if ((defined $req_rev) && ($cur_rev < $req_rev)) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"KIWI revision too old, require r$req_rev got r$cur_rev"
			);
			$kiwi -> failed ();
			return undef;
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
			if (grep /$imgT/, @imgTypes) {
				my $kiwi = $this->{kiwi};
				my $msg = 'Multiple definition of <type image="'
					. $imgT
					. '".../> found.';
				$kiwi -> error ($msg);
				$kiwi -> failed ();
				return undef;
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
	my @versions = $systemTree -> getElementsByTagName("version");
	my $numVersions = @versions;
	if ($numVersions > 1) {
		my $msg = "Only one <version> definition expected, found $numVersions";
		$kiwi -> error  ($msg);
		$kiwi -> failed ();
		return undef;
	}
	my $version = $versions[0] -> textContent();
	if ($version !~ /^\d+\.\d+\.\d+$/) {
		$kiwi -> error  ("Invalid version format: $version");
		$kiwi -> failed ();
		$kiwi -> error  ("Expected 'Major.Minor.Release'");
		$kiwi -> failed ();
		return undef;
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
	my $systemXML = new XML::LibXML;
	eval {
		$systemTree = $systemXML -> parse_fh ( $XML );
	};
	if ($@) {
		my $evaldata = $@;
		$kiwi -> error  ("Problem reading control file");
		$kiwi -> failed ();
		return undef;
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
		if (! open ($XML,"cat $controlFile|")) {
			$kiwi -> error ("XSL: Failed to open file $controlFile");
			$kiwi -> failed ();
			return undef;
		}
	} else {
		if (! open ($XML,"xsltproc $xslt $controlFile|")) {
			$kiwi -> error ("XSL: Failed to open xslt processor");
			$kiwi -> failed ();
			return undef;
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
	if (! $this -> __checkDefaultProfSetting()) {
		return undef;
	}
	if (! $this -> __checkDefaultTypeSetting()){
		return undef;
	}
	if (! $this -> __checkFilesysSpec()) {
		return undef;
	}
	if (! $this -> __checkPostDumpAction()) {
		return undef;
	}
	if (! $this -> __checkPreferencesDefinition()) {
		return undef;
	}
	if (! $this -> __checkReferencedProfDefined()) {
		return undef;
	}
	if (! $this -> __checkRevision()) {
		return undef;
	}
	if (! $this -> __checkTypeUnique()) {
		return undef;
	}
	if (! $this -> __checkVersionDefinition()) {
		return undef;
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
	my $systemXML   = new XML::LibXML;
	my $systemRNG   = new XML::LibXML::RelaxNG ( location => $this->{schema} );
	eval {
		$systemRNG ->validate ( $systemTree );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  ("Schema validation failed");
		$kiwi -> failed ();
		my $configStr = $systemXML -> parse_file( $controlFile ) -> toString();
		my $upgradedStr = $systemTree -> toString();
		my $upgradedContolFile = $controlFile;
		if ($configStr ne $upgradedStr) {
			$upgradedContolFile =~ s/\.xml/\.converted\.xml/;
			$kiwi -> info ("Automatically upgraded $controlFile to");
			$kiwi -> info ("$upgradedContolFile\n");
			$kiwi -> info ("Reported line numbers may not match the ");
			$kiwi -> info ("file $controlFile\n");
			open (my $UPCNTFL, '>', $upgradedContolFile);
			print $UPCNTFL $upgradedStr;
			close ( $UPCNTFL );
		}
		my $jingExec = main::findExec('jing');
		if ($jingExec) {
			qxx ("$jingExec $this->{schema} $upgradedContolFile 1>&2");
			return undef;
		} else {
			$kiwi -> error ("$evaldata\n");
			$kiwi -> info  ("Use the jing command for more details\n");
			$kiwi -> info  ("The following requires jing to be installed\n");
			$kiwi -> info  ("jing $this->{schema} $upgradedContolFile\n");
			return undef;
		}
	}
	return 1;
}

1;
