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
use Carp qw (cluck);
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
	my $params       = shift;  # global mkisofs parameters
	#==========================================
	# Constructor setup
	#------------------------------------------
	my %base;
	my @catalog;
	my $code;
	my $sort;
	my $ldir;
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
	#=======================================
	# path setup for supported archs
	#---------------------------------------
	# s390x
	$base{s390x}{boot}   = "boot/s390x";
	$base{s390x}{loader} = "undef";
	$base{s390x}{efi}    = "undef";
	# s390
	$base{s390}{boot}    = "boot/s390";
	$base{s390}{loader}  = "undef";
	$base{s390}{efi}     = "undef";
	# ix86
	$base{ix86}{boot}    = "boot/i386";
	$base{ix86}{loader}  = "boot/i386/loader/isolinux.bin";
	$base{ix86}{efi}     = "boot/i386/efi";
	# x86_64
	$base{x86_64}{boot}  = "boot/x86_64";
	$base{x86_64}{loader}= "boot/x86_64/loader/isolinux.bin";
	$base{x86_64}{efi}   = "boot/x86_64/efi";
	# ia64
	$base{ia64}{boot}    = "boot/ia64";
	$base{ia64}{loader}  = "undef";
	$base{ia64}{efi}     = "boot/ia64/efi";
	#=======================================
	# 1) search for legacy boot
	#---------------------------------------
	foreach my $arch (keys %base) {
		if (-d $source."/".$base{$arch}{boot}) {
			if ($arch eq "x86_64") {
				$catalog[0] = "x86_64_legacy";
			}
			if ($arch eq "ix86") {
				$catalog[0] = "ix86_legacy";
				last;
			}
		}
	}
	#=======================================
	# 2) search for efi/ikr boot
	#---------------------------------------
	foreach my $arch (keys %base) {
		if (-d $source."/".$base{$arch}{efi}) {
			if ($arch eq "x86_64") {
				push (@catalog, "x86_64_efi");
			}
			if ($arch eq "ix86") {
				push (@catalog, "ix86_efi");
			}
			if ($arch eq "ia64") {
				push (@catalog, "ia64_efi");
			}
			if ($arch eq "s390") {
				push (@catalog, "s390_ikr");
			}
			if ($arch eq "s390x") {
				push (@catalog, "s390x_ikr");
			}
		}
	}
	if (! @catalog) {
		$kiwi -> error  ("Can't find valid $source/boot/<arch>/ layout");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# create tmp files/directories 
	#------------------------------------------
	$sort = qxx ("mktemp /tmp/kiso-sort-XXXXXX 2>&1"); chomp $sort;
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create sort file: $sort: $!");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	$ldir = qxx ("mktemp -q -d /tmp/kiso-loader-XXXXXX 2>&1"); chomp $ldir;
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create tmp directory: $ldir: $!");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	qxx ("chmod 755 $ldir");
	#==========================================
	# Store object data
	#------------------------------------------
	$this -> {kiwi}   = $kiwi;
	$this -> {source} = $source;
	$this -> {dest}   = $dest;
	$this -> {params} = $params;
	$this -> {base}   = \%base;
	$this -> {tmpfile}= $sort;
	$this -> {tmpdir} = $ldir;
	$this -> {catalog}= \@catalog;
	return $this;
}

#==========================================
# x86_64_legacy
#------------------------------------------
sub x86_64_legacy {
	my $this  = shift;
	my $arch  = shift;
	my %base  = %{$this->{base}};
	my $para  = $this -> {params};
	my $sort  = $this -> createLegacySortFile ("x86_64");
	my $boot  = $base{$arch}{boot};
	my $loader= $base{$arch}{loader};
	$para.= " -sort $sort -no-emul-boot -boot-load-size 4 -boot-info-table";
	$para.= " -b $loader -c $boot/boot.catalog";
	$para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
	$this -> {params} = $para;
	$this -> createISOLinuxConfig ($boot);
}

#==========================================
# ix86_legacy
#------------------------------------------
sub ix86_legacy {
	my $this  = shift;
	my $arch  = shift;
	my %base  = %{$this->{base}};
	my $para  = $this -> {params};
	my $sort  = $this -> createLegacySortFile ("ix86");
	my $boot  = $base{$arch}{boot};
	my $loader= $base{$arch}{loader};
	$para.= " -sort $sort -no-emul-boot -boot-load-size 4 -boot-info-table";
    $para.= " -b $loader -c $boot/boot.catalog";
	$para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
	$this -> {params} = $para;
	$this -> createISOLinuxConfig ($boot);
}

#==========================================
# x86_64_efi
#------------------------------------------
sub x86_64_efi {
	my $this  = shift;
	my $arch  = shift;
	my %base  = %{$this->{base}};
	my $para  = $this -> {params};
	my $boot  = $base{$arch}{boot};
	my $loader= $base{$arch}{efi};
	$para.= " -eltorito-alt-boot";
	$para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
	$para.= " -b $loader";
	$this -> {params} = $para;
}

#==========================================
# ix86_efi
#------------------------------------------
sub ix86_efi {
	my $this  = shift;
	my $arch  = shift;
	my %base  = %{$this->{base}};
	my $para  = $this -> {params};
	my $boot  = $base{$arch}{boot};
	my $loader= $base{$arch}{efi};
	$para.= " -eltorito-alt-boot";
	$para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
	$para.= " -b $loader";
	$this -> {params} = $para;
}

#==========================================
# ia64_efi
#------------------------------------------
sub ia64_efi {
	my $this  = shift;
	my $arch  = shift;
	my %base  = %{$this->{base}};
	my $para  = $this -> {params};
	my $boot  = $base{$arch}{boot};
	my $loader= $base{$arch}{efi};
	$para.= " -eltorito-alt-boot";
	$para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
	$para.= " -b $loader";
	$this -> {params} = $para;
}

#==========================================
# s390_ikr
#------------------------------------------
sub s390_ikr {
	my $this = shift;
	my $arch = shift;
	my %base = %{$this->{base}};
	my $para = $this -> {params};
	my $boot = $base{$arch}{boot};
	my $ikr  = $this -> createS390CDLoader($boot);
	$para.= " -eltorito-alt-boot";
	$para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
	$para.= " -b $boot/cd.ikr";
	$this -> {params} = $para;
}

#==========================================
# s390x_ikri
#------------------------------------------
sub s390x_ikr {
	my $this = shift;
	my $arch = shift;
	my %base = %{$this->{base}};
	my $para = $this -> {params};
	my $boot = $base{$arch}{boot};
	my $ikr  = $this -> createS390CDLoader($boot);
	$para.= " -eltorito-alt-boot";
	$para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
	$para.= " -b $boot/cd.ikr";
	$this -> {params} = $para; 
}

#==========================================
# callBootMethods 
#------------------------------------------
sub callBootMethods {
	my $this    = shift;
	my @catalog = @{$this->{catalog}};
	my %base    = %{$this->{base}};
	my $ldir    = $this->{tmpdir};
	foreach my $boot (@catalog) {
		if ($boot =~ /(.*)_.*/) {
			my $arch = $1;
			qxx ("mkdir -p $ldir/".$base{$arch}{boot}."/loader");
			no strict 'refs';
			&{$boot}($this,$arch);
			use strict 'refs';
		}
	}
	return $this;
}
	
#==========================================
# createLegacySortFile
#------------------------------------------
sub createLegacySortFile {
	my $this = shift;
	my $arch = shift;
	my $kiwi = $this->{kiwi};
	my %base = %{$this->{base}};
	my $src  = $this->{source};
	my $sort = $this->{tmpfile};
	my $ldir = $this->{tmpdir};
	if (! -d $src."/".$base{$arch}{boot}) {
		return undef;
	}
	if (! open FD, ">$sort") {
		$kiwi -> error  ("Failed to open sort file: $!");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	sub generateWanted {
		my $filelist = shift;
		return sub {
			push (@{$filelist},$File::Find::name);
		}
	}
	my @list = ();
	my $wref = generateWanted (\@list);
	find ({wanted => $wref,follow => 0 },$src."/".$base{$arch}{boot}."/loader");
	print FD "$ldir/boot/boot.catalog 3"."\n";
	print FD "boot/boot.catalog 3"."\n";
	print FD "$src/boot/boot.catalog 3"."\n";
	foreach my $file (@list) {
		print FD "$file 1"."\n";
	}
	print FD "$src/boot/isolinux.bin 2"."\n";
	close FD;
	return $sort;
}

#==========================================
# createS390CDLoader 
#------------------------------------------
sub createS390CDLoader {
	my $this = shift;
	my $basez= shift;
	my $kiwi = $this->{kiwi};
	my $src  = $this->{source};
	my $ldir = $this->{tmpdir};
	if (-f $src."/".$basez."/vmrdr.ikr") {
		qxx ("mkdir -p $ldir/$basez");
		my $parmfile = $src."/".$basez."/parmfile";
		if (-e $parmfile.".cd") {
			$parmfile = $parmfile.".cd";
		}
		my $gen = "gen-s390-cd-kernel.pl";
		$gen .= " --initrd=$src/$basez/initrd";
		$gen .= " --kernel=$src/$basez/vmrdr.ikr";
		$gen .= " --parmfile=$parmfile";
		$gen .= " --outfile=$ldir/$basez/cd.ikr";
		qxx ($gen);
	}
	if (-f "$ldir/$basez/cd.ikr") {
		return "$basez/cd.ikr";
	}
	return undef
}

#==========================================
# createVolumeID 
#------------------------------------------
sub createVolumeID {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $src  = $this->{source};
	my $hfsvolid = "unknown";
	if (-f $src."/content") {
		my $number;
		my $version;
		my $name;
		my @media = glob ("$src/media.?");
		foreach my $i (@media) {
			if ((-d $i) && ( $i =~ /.*\.(\d+)/)) {
				$number = $1; last;
			}
		}
		open (FD,"$src/content");
		foreach my $line (<FD>) {
			if (($version) && ($name)) {
				last;
			}
			if ($line =~ /(NAME|PRODUCT)\s+(\w+)/) {
				$name=$2;
			}
			if ($line =~ /VERSION\s+([\d\.]+)/) {
				$version=$1;
			}
		}
		close FD;
		if ($name) {
			$hfsvolid=$name;
		}
		if ($version) {
			$hfsvolid="$name $version";
		}
		if ($hfsvolid) {
			if ($number) {
				$hfsvolid = substr ($hfsvolid,0,25);
				$hfsvolid.= " $number";
			}
		} elsif (open (FD,$src."media.1/build")) {
			my $line = <FD>; close FD;
			if ($line =~ /(\w+)-(\d+)-/) {
				$hfsvolid = "$1 $2 $number";
			}
		}
	}
	return $hfsvolid;
}

#==========================================
# createISOLinuxConfig 
#------------------------------------------
sub createISOLinuxConfig {
	my $this = shift;
	my $boot = shift;
	my $kiwi = $this -> {kiwi};
	my $src  = $this -> {source};
	my $isox = "/usr/bin/isolinux-config";
	if (! -x $isox) {
		$kiwi -> error  ("Can't find isolinux-config binary");
		$kiwi -> failed ();
		$this -> cleanISO();
		return undef;
	}
	my $data = qxx (
		"$isox --base $boot/loader $src/$boot/loader/isolinux.bin 2>&1"
	);
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
	my $ldir = $this -> {tmpdir};
	my $prog = "/usr/bin/mkisofs";
	my $data = qxx (
		"$prog $para -o $dest $ldir $src 2>&1"
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
	my $sort = $this -> {tmpfile};
	my $ldir = $this -> {tmpdir};
	if (-f $sort) {
		qxx ("rm -f $sort 2>&1");
	}
	if (-d $ldir) {
		qxx ("rm -rf $ldir 2>&1");
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
	my $data = qxx ("tagmedia --pad 150 --md5 --check $dest 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Failed to call tagmedia: $data");
		$kiwi -> failed ();
		return undef;
	}
	return $this;
}

1;
