#================
# FILE          : KIWIXML.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used for reading the control
#               : XML file, used for preparing an image
#               :
# STATUS        : Development
#----------------
package KIWIXML;
#==========================================
# Modules
#------------------------------------------
use strict;
use XML::LibXML;
use KIWILog;

#==========================================
# Private
#------------------------------------------
my $kiwi;
my @sourceFileList;
my $optionsNodeList;
my $driversNodeList;
my $repositNodeList;
my $packageNodeList;
my $imgnameNodeList;

#==========================================
# Constructor
#------------------------------------------
sub new { 
	# ...
	# Create a new KIWIXML object which is used to access the
	# configuration XML data saved as config.xml. The xml data
	# is splitted into four major tags: preferences, drivers,
	# repository and packages. While constructing an object of this
	# type there will be a node list created for each of the
	# major tags.
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi   = shift;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	my $controlFile = $_[0]."/config.xml";
	my $versionFile = $_[0]."/VERSION";
	my $systemXML   = new XML::LibXML;
	if (! -f $controlFile) {
		$kiwi -> failed ();
		$kiwi -> error ("Cannot open control file: $controlFile");
		$kiwi -> failed ();
		return undef;
	}
	if (! -f $versionFile) {
		$kiwi -> failed ();
		$kiwi -> error ("Cannot open VERSION file: $versionFile");
		$kiwi -> failed ();
		return undef;
	}
	eval {
		my $systemTree = $systemXML
			-> parse_file ( $controlFile );
		$optionsNodeList = $systemTree -> getElementsByTagName ("preferences");
		$driversNodeList = $systemTree -> getElementsByTagName ("drivers");
		$repositNodeList = $systemTree -> getElementsByTagName ("repository");
		$packageNodeList = $systemTree -> getElementsByTagName ("packages");
		$imgnameNodeList = $systemTree -> getElementsByTagName ("image");
	};
	if ((! $optionsNodeList) || (! $repositNodeList) || (! $packageNodeList)) {
		$kiwi -> failed ();
		$kiwi -> error ("Problem reading control file");
		$kiwi -> failed ();
		$kiwi -> error ("$@\n");
		return undef;
	}
	return $this;
}

#==========================================
# getImageName
#------------------------------------------
sub getImageName {
	# ...
	# Get the name of the logical extend
	# ---
	my $this = shift;
	my $node = $imgnameNodeList -> get_node(1);
	my $name = $node -> getAttribute ("name");
	return $name;
}

#==========================================
# getImageSize
#------------------------------------------
sub getImageSize {
	# ...
	# Get the predefined size of the logical extend
	# ---
	my $this = shift;
	my $node = $optionsNodeList -> get_node(1);
	my $size = $node -> getElementsByTagName ("size");
	my $unit = $node -> getElementsByTagName ("size")
		-> get_node(1) ->getAttribute("unit");
	return $size.$unit;
}

#==========================================
# getImageType
#------------------------------------------
sub getImageType {
	# ...
	# Get the filesystem type of the logical extend
	# ---
	my $this = shift;
	my $node = $optionsNodeList -> get_node(1);
	my $type = $node -> getElementsByTagName ("type");
	return $type;
}

#==========================================
# getCompressed
#------------------------------------------
sub getCompressed {
	# ...
	# Check if the image should be compressed or not. The
	# method returns true if the image should be compressed
	# otherwise false. 
	# ---
	my $this = shift;
	my $node = $optionsNodeList -> get_node(1);
	my $gzip = $node -> getElementsByTagName ("compressed");
	if ((defined $gzip) && ("$gzip" eq "yes")) {
		return 1;
	}
	return 0;
}

#==========================================
# getRepository
#------------------------------------------
sub getRepository {
	# ...
	# Get the smart package manager type used for building
	# up the physical extend. For information on the available
	# types refer to the smart documentation
	# ---
	my $this = shift;
	my @node = $repositNodeList -> get_nodelist();
	my %result;
	foreach my $element (@node) {
		my $type = $element -> getAttribute("type");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source =  $stag -> getAttribute ("path");
		$result{$type} = $source;
	}
	return %result;
}

#==========================================
# getImageConfig
#------------------------------------------
sub getImageConfig {
	# ...
	# Evaluate the attributes of the drivers and preferences tags and
	# build a hash containing all the image parameters. This information
	# is used to create the .profile environment
	# ---
	my $this = shift;
	my %result;
	#==========================================
	# preferences
	#------------------------------------------
	if (getCompressed ($this)) {
		$result{compressed} = "yes";
	}
	my $type = getImageType ($this);
	my $size = getImageSize ($this);
	my $name = getImageName ($this);
	if ($type) {
		$result{type} = $type;
	}
	if ($size) {
		$result{size} = $size;
	}
	if ($name) {
		$result{name} = $name;
	}
	#==========================================
	# drivers
	#------------------------------------------
	my @node = $driversNodeList -> get_nodelist();
	foreach my $element (@node) {
		my $type = $element -> getAttribute("type");
		my @ntag = $element -> getElementsByTagName ("file") -> get_nodelist();
		my $data = "";
		foreach my $element (@ntag) {
			my $name =  $element -> getAttribute ("name");
			$data = $data.",".$name
		}
		$data =~ s/^,+//;
		$result{$type} = $data;
	}
	return %result;
}

#==========================================
# getList
#------------------------------------------
sub getList {
	# ...
	# Create a package list out of the given base xml
	# object list. The xml objects are searched for the
	# attribute "name" to build up the package list.
	# Each entry must be found on the smart source medium
	# ---
	my $this = shift;
	my $what = shift;
	my @result;
	for (my $i=1;$i<= $packageNodeList->size();$i++) {
		my $node = $packageNodeList -> get_node($i);
		my $type = $node -> getAttribute ("type");
		if ($type ne $what) {
			next;
		}
		my @plist = $node -> getElementsByTagName ("package");
		foreach my $element (@plist) {
			my $package = $element -> getAttribute ("name");
			if (! defined $package) {
				next;
			}
			push @result,$package;
		}
	}
	return @result;
}

#==========================================
# getBaseList
#------------------------------------------
sub getBaseList {
	# ...
	# Create base package list needed to start creating
	# the physical extend. The packages in this list are
	# installed manually
	# ---
	my $this = shift;
	return getList ($this,"boot");
}

#==========================================
# getInstallList
#------------------------------------------
sub getInstallList {
	# ...
	# Create install package list needed to blow up the
	# physical extend to what the image was designed for
	# ---
	my $this = shift;
	return getList ($this,"image");
}

#==========================================
# getXenList
#------------------------------------------
sub getXenList {
	# ...
	# Create virtualisation package list needed to run that
	# image within a Xen virtualized system
	# ---
	my $this = shift;
	return getList ($this,"xen");
}

1;
