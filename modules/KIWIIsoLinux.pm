#================
# FILE          : KIWIIsoLinux.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create an ISO
#               : filesystem based on mkisofs
#               : 
#               :
# STATUS        : Development
#----------------
package KIWIIsoLinux;
#==========================================
# Modules
#------------------------------------------
use strict;
use File::Find;
use KIWILog;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIIsoLinux object which is used to wrap
	# around the major mkisofs call. This code requires a
	# specific source directory structure which is:
	# ---
	# $source/boot/<arch>/loader
	# ---
	# Below the loader path the initrd and kernel as well as
	# all isolinux related binaries and files must be stored
	# Given that structure this module creates a bootable
	# ISO file from the data below $source
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
	my $kiwi         = shift;
	my $source       = shift;  # location of source tree
	my $dest         = shift;  # destination for the iso file
	my $publisher    = shift;  # publisher string
	my $preparer     = shift;  # preparer string
	my $params       = shift;  # mkisofs parameters
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $bootbase     = "boot";
	my $bootbaseZ    = "";
	my $bootimage    = "";
	my $bootisolinux = "";
	#==========================================
	# create log object if not done
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog ("tiny");
	}
	if (! -d $source) {
		$kiwi -> error  ("No such file or directory: $source");
		$kiwi -> failed (); 
		return undef;
	}
	if (! defined $dest) {
		$kiwi -> error  ("No destination file specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $preparer) {
		$preparer = $main::Preparer;
	}
	if (! defined $publisher) {
		$publisher = $main::Publisher;
	}
	if (! defined $params) {
		$params = '-R -J -pad -joliet-long';
	}
	#=======================================
	# check /boot/<arch>/loader layout
	#---------------------------------------
	if (-d "$source/$bootbase/s390x") {
		$bootbaseZ = $bootbase."/s390x";
		$bootbase  = $bootbase."/i386";
	} elsif (-d "$source/$bootbase/s390") {
		$bootbaseZ = $bootbase."/s390";
		$bootbase  = $bootbase."/i386";
	} elsif (-d "$source/$bootbase/i386") {
		$bootbase  = $bootbase."/i386";
	} elsif (-d "$source/$bootbase/x86_64") {
		$bootbase  = $bootbase."/x86_64";
	} elsif (-d "$source/$bootbase/ia64") {
		$bootbase  = $bootbase."/ia64";
	} else {
		$kiwi -> error  ("No $source/$bootbase/<arch>/ layout found");
		$kiwi -> failed ();
		return undef;
	}
	$bootimage    = $bootbase."/image";
	$bootisolinux = $bootbase."/loader";
	#==========================================
	# Store object data
	#------------------------------------------
	$this -> {kiwi}         = $kiwi;
	$this -> {source}       = $source;
	$this -> {dest}         = $dest;
	$this -> {params}       = $params;
	$this -> {publisher}    = $publisher;
	$this -> {preparer}     = $preparer;
	$this -> {rootoncd}     = "suse";
	$this -> {bootbase}     = $bootbase;
	$this -> {bootimage}    = $bootimage;
	$this -> {bootisolinux} = $bootisolinux;
	return $this;
}

#==========================================
# createSortFile 
#------------------------------------------
sub createSortFile {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $boot = $this->{bootisolinux};
	my $base = $this->{bootbase};
	my $src  = $this->{source};
	my $para = $this->{params};
	my $code;
	#==========================================
	# check boot directory 
	#------------------------------------------
	if (! -d "$src/$boot") {
		$kiwi -> error ("Directory $src/$boot doesn't exist");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# create tmp files/directories 
	#------------------------------------------
	my $sort = qxx ("mktemp /tmp/m_cd-XXXXXX 2>&1"); chomp $sort;
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create sort file: $sort: $!");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	my $sdir = qxx ("mktemp -q -d /tmp/m_cd-XXXXXX 2>&1"); chomp $sdir;
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create tmp directory: $sdir: $!");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	#==========================================
	# store tmp files/directories 
	#------------------------------------------
	$this -> {sortfile} = $sort;
	$this -> {srcxdir}  = $sdir;
	#==========================================
	# create sort file 
	#------------------------------------------
	sub generateWanted {
		my $filelist = shift;
		return sub {
			push (@{$filelist},$File::Find::name);
		}
	}
	if (! open FD, ">$sort") {
		$kiwi -> error  ("Failed to open sort file: $!");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	my @list = ();
	my $wref = generateWanted (\@list);
	find ({wanted => $wref, follow => 0 }, "$src/$boot");
	print FD "$sdir/$base/boot.catalog 3"."\n";
	print FD "$base/boot.catalog 3"."\n";
	print FD "$src/$base/boot.catalog 3"."\n";
	foreach my $file (@list) {
		print FD "$file 1"."\n";
	}
	print FD "$src/$boot/isolinux.bin 2"."\n";
	close FD;
	qxx ("mkdir -p $sdir/$boot");
	#==========================================
	# setup mkisofs parameters for boot iso 
	#------------------------------------------
	$para.= " -sort $sort -no-emul-boot -boot-load-size 4 -boot-info-table";
	$para.= " -b $boot/isolinux.bin -c $base/boot.catalog";
	$para.= " -hide $base/boot.catalog -hide-joliet $base/boot.catalog";
	$this -> {params} = $para;
	return $this;
}

#==========================================
# createISOLinuxConfig 
#------------------------------------------
sub createISOLinuxConfig {
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $boot = $this -> {bootisolinux};
	my $src  = $this -> {source};
	my $isox = "/usr/bin/isolinux-config";
	if (! -x $isox) {
		$kiwi -> error  ("Can't find isolinux-config binary");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	my $data = qxx ("$isox --base $boot $src/$boot/isolinux.bin 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to call isolinux-config binary: $data");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	return $this;
}

#==========================================
# createISO
#------------------------------------------
sub createISO {
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $src  = $this -> {source};
	my $dest = $this -> {dest};
	my $para = $this -> {params};
	my $pub  = $this -> {publisher};
	my $prep = $this -> {preparer};
	my $srcx = $this -> {srcxdir};
	my $prog = "/usr/bin/mkisofs";
	my $data = qxx (
		"$prog -p \"$prep\" -publisher \"$pub\" $para -o $dest $srcx $src 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to call mkisofs binary: $data");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	$this -> cleanISO();
	return $this;
}

#==========================================
# cleanISO
#------------------------------------------
sub cleanISO {
	my $this = shift;
	my $sort = $this -> {sortfile};
	my $srcx = $this -> {srcxdir};
	if (-f $sort) {
		qxx ("rm -f $sort 2>&1");
	}
	if (-d $srcx) {
		qxx ("rm -rf $srcx 2>&1");
	}
	return $this;
}

#==========================================
# checkImage
#------------------------------------------
sub checkImage {
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $dest = $this -> {dest};
	my $data = qxx ("tagmedia --md5 $dest 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to call tagmedia: $data");
		$kiwi -> failed ();
		return undef;
	}
	return $this;
}

1;
