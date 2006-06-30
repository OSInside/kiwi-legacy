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
my $source;
my @sourceFileList;
my @entryList;
my @imageList;
my @cpiosList;
my @xenvmList;

#==========================================
# Constructor
#------------------------------------------
sub new { 
	# ...
	# Create a new KIWIXML object which is used to access the
	# configuration XML data saved as config.xml. The xml data
	# is splitted into four major tags: entry, image, cpios and
	# xenvm. While constructing an object of this type there
	# will be a list created for each of the major tags.
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi   = shift;
	$source = shift;
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
		@entryList = $systemTree -> getElementsByTagName ("entry");
		@imageList = $systemTree -> getElementsByTagName ("image");
		@cpiosList = $systemTree -> getElementsByTagName ("cpios");
		@xenvmList = $systemTree -> getElementsByTagName ("xenvm");
	};
	if ((! @entryList) || (! @imageList) || (! @cpiosList)) {
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
	# Get the name of the logial extend
	# ---
	my $this   = shift;
	my %config = getImageConfig ($this);
	return $config{name};
}

#==========================================
# getImageSize
#------------------------------------------
sub getImageSize {
	# ...
	# Get the predefined size of the logical extend
	# ---
	my $this   = shift;
	my %config = getImageConfig ($this);
	return $config{size};
}

#==========================================
# getImageType
#------------------------------------------
sub getImageType {
	# ...
	# Get the filesystem type of the logical extend
	# ---
	my $this   = shift;
	my %config = getImageConfig ($this);
	return $config{type};
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
	my $this   = shift;
	my %config = getImageConfig ($this);
	my $zipped = $config{compressed};
	if ((defined $zipped) && ($zipped eq "yes")) {
		return 1;
	}
	return 0;
}

#==========================================
# getType
#------------------------------------------
sub getType {
	# ...
	# Get the smart package manager type used for building
	# up the physical extend. For information on the available
	# types refer to the smart documentation
	# ---
	my $this = shift;
	return $entryList[0] -> getAttribute("type");
}

#==========================================
# getSource
#------------------------------------------
sub getSource {
	# ...
	# Get the smart package manager source used for building
	# up the physical extend. For information on the available
	# source formats refer to the smart documentation
	# ---
	my $this = shift;
	my $path = $source;

	if (defined $path) {
		return $path;
	}
	foreach my $item (@entryList) {
		if (defined $item->getAttribute("source")) {
			my $d = $item->getAttribute("source");
			$path=$path."|".$d;
		}
	}
	$path =~ s/^\|//;
	return $path;
}

#==========================================
# getImageConfig
#------------------------------------------
sub getImageConfig {
	# ...
	# Evaluate the attributes of the image tag and build
	# up a hash containing all the image parameters. This
	# information is used to create the .profile environment
	# ---
	my $this = shift;
	my %config;
	foreach my $item (@imageList) {
		if (defined $item->getAttribute("name")) {
			$config{name} = $item->getAttribute("name");
		}
		if (defined $item->getAttribute("type")) {
			$config{type} = $item->getAttribute("type");
		}
		if (defined $item->getAttribute("netdrivers")) {
			$config{netdrivers} = $item->getAttribute("netdrivers");
		}
		if (defined $item->getAttribute("drivers")) {
			$config{drivers} = $item->getAttribute("drivers");
		}
		if (defined $item->getAttribute("compressed")) {
			$config{compressed} = $item->getAttribute("compressed");
		}
		if (defined $item->getAttribute("size")) {
			$config{size} = $item->getAttribute("size");
		}
	}
	return %config;
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
	my $lref = shift;
	my @list = @{$lref};
	my @result;
	foreach my $item (@list) {
		my $name = $item->getAttribute("name");
		if (! defined $name) {
			next;
		}
		push @result,$name;
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
	return getList ($this,\@cpiosList);
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
	return getList ($this,\@entryList);
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
	return getList ($this,\@xenvmList);
}

1;
