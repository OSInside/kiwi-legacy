#================
# FILE          : KIWIIsoLinux.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create an ISO
#               : filesystem based on genisoimage/mkisofs
#               :
#               :
# STATUS        : Development
#----------------
package KIWIIsoLinux;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw /cluck/;
use Fcntl;
use File::Find;
use File::Basename;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX;

my @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create a new KIWIIsoLinux object which is used to wrap
    # around the major genisoimage/mkisofs call. This code requires a
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
    my $source       = shift;  # location of source tree
    my $dest         = shift;  # destination for the iso file
    my $params       = shift;  # global genisoimage/mkisofs parameters
    my $mediacheck   = shift;  # run tagmedia with --check y/n
    my $cmdL         = shift;  # commandline params: optional
    my $xml          = shift;  # system image XML: optional
    #==========================================
    # Constructor setup
    #------------------------------------------
    my %base;
    my @catalog;
    my $code;
    my $sort;
    my $ldir;
    my $tool;
    my $check = 0;
    #==========================================
    # create log object if not done
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    if (! -d $source) {
        $kiwi -> error  ("No such file or directory: $source");
        $kiwi -> failed ();
        return;
    }
    if (! defined $dest) {
        $kiwi -> error  ("No destination file specified");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Find iso tool to use on this system
    #------------------------------------------
    my $locator = KIWILocator -> instance();
    my $genTool = $locator -> getExecPath('genisoimage');
    my $mkTool = $locator -> getExecPath('mkisofs');
    if ($genTool && -x $genTool) {
        $tool = $genTool;
    } elsif ($mkTool && -x $mkTool) {
        $tool = $mkTool;
    } else {
        $kiwi -> error  ("No ISO creation tool found");
        $kiwi -> failed ();
        return;
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
    # ppc64
    $base{ppc64}{boot}    = "boot/ppc64";
    $base{ppc64}{loader}  = "undef";
    $base{ppc64}{efi}     = "undef";
    # ppc64le
    $base{ppc64le}{boot}    = "boot/ppc64le";
    $base{ppc64le}{loader}  = "undef";
    $base{ppc64le}{efi}     = "undef";
    # aarch64
    $base{aarch64}{boot}    = "boot/aarch64";
    $base{aarch64}{loader}  = "undef";
    $base{aarch64}{efi}     = "boot/aarch64/efi";
    #=======================================
    # 1) search for legacy boot
    #---------------------------------------
    foreach my $arch (sort keys %base) {
        if (-d $source."/".$base{$arch}{boot}) {
            if ($arch eq "x86_64") {
                $catalog[0] = "x86_64_legacy";
            }
            if ($arch eq "ix86") {
                $catalog[0] = "ix86_legacy";
            }
            if ($arch =~ /ppc64|ppc64le/) {
                $catalog[0] = "ppc64_default";
            }
            if ($arch eq "s390") {
                $catalog[0] = "ix86_legacy";
                $catalog[1] = "s390_ikr";
            }
            if ($arch eq "s390x") {
                $catalog[0] = "ix86_legacy";
                $catalog[1] = "s390x_ikr";
            }
        }
    }
    #=======================================
    # 2) search for efi/ikr boot
    #---------------------------------------
    foreach my $arch (sort keys %base) {
        if (-f $source."/".$base{$arch}{efi}) {
            if ($arch eq "x86_64") {
                push (@catalog, "x86_64_efi");
            }
            if ($arch eq "ix86") {
                push (@catalog, "ix86_efi");
            }
            if ($arch eq "ia64") {
                push (@catalog, "ia64_efi");
            }
            if ($arch eq "aarch64") {
                push (@catalog, "aarch64_efi");
            }
        }
    }
    #==========================================
    # create tmp files/directories 
    #------------------------------------------
    $sort = KIWIQX::qxx ("mktemp -t kiso-sort-XXXXXX 2>&1"); chomp $sort;
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't create sort file: $sort: $!");
        $kiwi -> failed ();
        $this -> cleanISO();
        return;
    }
    $ldir = KIWIQX::qxx ("mktemp -qdt kiso-loader-XXXXXX 2>&1"); chomp $ldir;
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't create tmp directory: $ldir: $!");
        $kiwi -> failed ();
        $this -> cleanISO();
        return;
    }
    KIWIQX::qxx ("chmod 755 $ldir");
    #==========================================
    # Store object data
    #------------------------------------------
    my $global = KIWIGlobals -> instance();
    $this -> {kiwi}        = $kiwi;
    $this -> {source}      = $source;
    $this -> {dest}        = $dest;
    $this -> {params}      = $params;
    $this -> {orig_params} = $params;
    $this -> {base}        = \%base;
    $this -> {tmpfile}     = $sort;
    $this -> {tmpdir}      = $ldir;
    $this -> {catalog}     = \@catalog;
    $this -> {tool}        = $tool;
    $this -> {check}       = $mediacheck;
    $this -> {gdata}       = $global -> getKiwiConfig();
    $this -> {cmdL}        = $cmdL;
    $this -> {xml}         = $xml;
    $this -> {magicID}     = '7984fc91-a43f-4e45-bf27-6d3aa08b24cf';
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
    $para.= " -sort $sort" if $sort;
    $para.= " -no-emul-boot -boot-load-size 4 -boot-info-table";
    $para.= " -b $loader -c $boot/boot.catalog";
    $para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
    $this -> {params} = $para;
    $this -> createISOLinuxConfig ($boot);
    return $this;
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
    $para.= " -sort $sort" if $sort;
    $para.= " -no-emul-boot -boot-load-size 4 -boot-info-table";
    $para.= " -b $loader -c $boot/boot.catalog";
    $para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
    $this -> {params} = $para;
    $this -> createISOLinuxConfig ($boot);
    return $this;
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
    $para.= " -no-emul-boot";
    $para.= " -boot-load-size 1";
    $para.= " -b $loader";
    $this -> {params} = $para;
    return $this;
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
    $para.= " -no-emul-boot";
    $para.= " -boot-load-size 1";
    $para.= " -b $loader";
    $this -> {params} = $para;
    return $this;
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
    my $sort  = $this -> createLegacySortFile ("ia64");

    $para.= " -no-emul-boot";
    $para.= " -boot-load-size 1";
    $para.= " -sort $sort" if $sort;
    $para.= " -b $loader";
    $para.= " -c $boot/boot.catalog";
    $para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";

    $this -> {params} = $para;
    return $this;
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
    $para.= " -no-emul-boot";
    $para.= " -b $ikr";
    $this -> {params} = $para;
    return $this;
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
    $para.= " -no-emul-boot";
    $para.= " -b $ikr";
    $this -> {params} = $para;
    return $this;
}

#==========================================
# ppc64_default
#------------------------------------------
sub ppc64_default {
    my $this  = shift;
    my $arch  = shift;
    my %base  = %{$this->{base}};
    my $para  = $this -> {params};
    my $src   = $this -> {source};
    my $boot  = $base{$arch}{boot};
    my $volid = $this -> createVolumeID();

    $para.= " -chrp-boot";
    $para.= " -hfs-bless $src/$boot/grub2-ieee1275";
    $para.= " -hfs-volid '$volid'";
    $para.= " -l";
    $para.= " --macbin";
    $para.= " -map $this->{gdata}->{BasePath}";
    $para.= "/metadata/KIWIIsoLinux-AppleFileMapping.map";
    $para.= " --netatalk";
    $para.= " -part";
    $para.= " -U";
    $this -> {params} = $para;
    return $this;
}

#==========================================
# aarch64_efi
#------------------------------------------
sub aarch64_efi {
    my $this  = shift;
    my $arch  = shift;
    my %base  = %{$this->{base}};
    my $para  = $this -> {params};
    my $boot  = $base{$arch}{boot};
    my $loader= $base{$arch}{efi};
    $para.= " -no-emul-boot";
    # do not add -boot-load-size 1 here
    $para.= " -b $loader";
    $para.= " -c $boot/boot.catalog";
    $para.= " -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog";
    $this -> {params} = $para;
    return $this;
}

#==========================================
# addBootLive
#------------------------------------------
sub addBootLive {
    my $this    = shift;
    my $size    = $this->{bootloadsize};
    my $para    = $this->{params};
    my $sort    = $this->{sortfile};
    my $src     = $this->{source};
    my $tmpdir  = $this->{tmpdir};
    my $magicID = $this->{magicID};
    my $xml     = $this->{xml};
    my $firmware= 'efi';
    my $arch;
    if ($size) {
        $size = ($size + 2047) >> 11 << 2;
    }
    if (! -f $sort) {
        return;
    }
    if (-d "$src/boot/x86_64") {
        $arch = 'x86_64';
    } elsif (-d "$src/boot/i386") {
        $arch = 'i386';
    } else {
        return;
    }
    #==========================================
    # Lookup firmware setup
    #------------------------------------------
    if ($xml) {
        my $type = $xml -> getImageType();
        my $xmlFirmWare = $type -> getFirmwareType();
        if ($xmlFirmWare) {
            $firmware = $xmlFirmWare;
        }
    }
    #==========================================
    # update sort file
    #------------------------------------------
    KIWIQX::qxx ("echo $src/boot/$arch/efi 1000001 >> $sort");
    #==========================================
    # add end-of-header marker
    #------------------------------------------
    KIWIQX::qxx ("echo $magicID > $tmpdir/glump");
    KIWIQX::qxx ("echo $tmpdir/glump 1000000 >> $sort");
    #==========================================
    # update parameter list
    #------------------------------------------
    if (($firmware ne 'bios') && (-e "$src/boot/$arch/efi")) {
        $para.= ' -eltorito-alt-boot ';
        $para.= " -b boot/$arch/efi";
    }
    $para.= ' -no-emul-boot -joliet-long -hide glump -hide-joliet glump';
    $this -> {params} = $para;
    return $this;
}

#==========================================
# callBootMethods
#------------------------------------------
sub callBootMethods {
    my $this    = shift;
    my $kiwi    = $this->{kiwi};
    my @catalog = @{$this->{catalog}};
    my %base    = %{$this->{base}};
    my $ldir    = $this->{tmpdir};
    if (! @catalog) {
        $kiwi -> error  ("Can't find valid boot/<arch>/ layout");
        $kiwi -> failed ();
        return;
    }
    foreach my $boot (@catalog) {
        if ($boot =~ /(.*)_.*/) {
            my $arch = $1;
            KIWIQX::qxx ("mkdir -p $ldir/".$base{$arch}{boot});
            no strict 'refs'; ## no critic
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
    my $FD;
    if (! -d $src."/".$base{$arch}{boot}) {
        return;
    }
    my @list = ();
    my $wref = $this -> __generateWanted (\@list);
    if (! open $FD, '>', "$sort") {
        $kiwi -> error  ("Failed to open sort file: $!");
        $kiwi -> failed ();
        $this -> cleanISO();
        return;
    }
    find ({wanted => $wref,follow => 0 },$src."/".$base{$arch}{boot}."/loader");
    print $FD "$ldir/".$base{$arch}{boot}."/boot.catalog 3"."\n";
    print $FD $base{$arch}{boot}."/boot.catalog 3"."\n";
    print $FD "$src/".$base{$arch}{boot}."/boot.catalog 3"."\n";
    foreach my $file (@list) {
        print $FD "$file 1"."\n";
    }
    print $FD $src."/".$base{$arch}{boot}."/loader/isolinux.bin 2"."\n";
    close $FD;
    $this->{sortfile} = $sort;
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
    $kiwi -> info ("Creating S390 CD kernel:");
    # originally from gen-s390-cd-kernel.pl by Ruediger Oertel
    my $parmfile = "$src/$basez/parmfile";
    if (-e $parmfile.".cd") {
        $parmfile = $parmfile.".cd";
    }
    my $image = "$src/$basez/vmrdr.ikr";
    my $initrd = "$src/$basez/initrd";
    my $outfile = "$src/$basez/cd.ikr";
    my $cmdline = 'root=/dev/sda2';
    # Nothing to do if file already exists.
    if (-f $outfile) {
        $kiwi -> info ("\tUsing pre-ceated image $outfile");
        $outfile =~ s|$src/||;
        return $outfile;
    }
    # Open input files
    if (! sysopen(image_fh,$image,O_RDONLY) ) {
        $kiwi -> error  ("Cannot open kernel image $image: $!");
        $kiwi -> failed ();
        $this -> cleanISO();
        return;
    }
    if (! sysopen(initrd_fh,$initrd,O_RDONLY) ) {
        $kiwi -> error  ("Cannot open initrd $initrd: $!");
        $kiwi -> failed ();
        $this -> cleanISO ();
        return;
    }
    my $image_size = (stat(image_fh))[7];
    my $initrd_size = (stat(initrd_fh))[7];
    # Get the size of the input files
    $kiwi -> info (
        sprintf("\t%s: offset 0x%x len 0x%x (%d blocks)",
        $image, 0, $image_size, ($image_size >> 12) + 1)
    );
    # The kernel appearently needs some free space above the
    # actual image (bss? stack?), so use this hard-coded
    # limit (from include/asm-s390/setup.h)
    # my $initrd_offset = (($image_size >> 12) + 1) << 12;
    my $initrd_offset = 0x800000;
    my $boot_size = ((($initrd_offset + $initrd_size) >> 12) + 1 ) << 12;
    $kiwi -> info (
        sprintf("\t%s: offset 0x%x len 0x%x (%d blocks)",
        $initrd, $initrd_offset, $initrd_size, ($initrd_size >>12) + 1)
    );
    $kiwi -> info (
        sprintf("\t%s: len 0x%x (%d blocks)",
        $outfile, $initrd_offset + $initrd_size, $boot_size / 4096)
    );
    # Get the kernel command line arguments
    $cmdline .= " " if ($cmdline ne "");
    if ($parmfile ne "") {
        my $line;
        $cmdline = '';
        my $PARMFH;
        if (! open($PARMFH, '<', $parmfile) ) {
            $kiwi -> error  ("Cannot open parmfile $parmfile: $!");
            $kiwi -> failed ();
            $this -> cleanISO();
            return;
        }
        while($line=<$PARMFH>) {
            chomp $line;
            $cmdline .= $line . " ";
        }
        close($PARMFH);
    }
    if ($cmdline ne "") {
        chop $cmdline;
    }
    # Max length for the kernel command line is 896 bytes
    if (length($cmdline) >= 896) {
        $kiwi -> error  (
            "Kernel commandline too long (". length($cmdline) ." bytes)"
        );
        $kiwi -> failed ();
        $this -> cleanISO ();
        return;
    }
    # Now create the image file.
    if (! sysopen(out_fh,$outfile,O_RDWR|O_CREAT|O_TRUNC) ) {
        $kiwi -> error  ("Cannot open outfile $outfile: $!");
        $kiwi -> failed ();
        $this -> cleanISO ();
        return;
    }
    # First fill the entire size with zeroes
    if (! sysopen(null_fh,"/dev/zero",O_RDONLY) ) {
        $kiwi -> error  ("Cannot open /dev/zero: $!");
        $kiwi -> failed ();
        $this -> cleanISO ();
        return;
    }
    my $buffer="";
    my $blocks_read=0;
    while ($blocks_read < ($boot_size >> 12)) {
        sysread(null_fh,$buffer, 4096);
        syswrite(out_fh,$buffer);
        $blocks_read += 1;
    }
    $kiwi -> info ("\tRead $blocks_read blocks from /dev/zero");
    close(null_fh);
    # Now copy the image file to location 0
    sysseek(out_fh,0,0);
    $blocks_read = 0;
    while (sysread(image_fh,$buffer, 4096) != 0) {
        syswrite(out_fh,$buffer,4096);
        $blocks_read += 1;
    }
    $kiwi -> info ("\tRead $blocks_read blocks from $image");
    close(image_fh);
    # Then the initrd to location specified by initrd_offset
    sysseek(out_fh,$initrd_offset,0);
    $blocks_read = 0;
    while (sysread(initrd_fh,$buffer, 4096) != 0) {
        syswrite(out_fh,$buffer,4096);
        $blocks_read += 1;
    }
    $kiwi -> info ("\tRead $blocks_read blocks from $initrd");
    close(initrd_fh);
    # Now for the real black magic.
    # If we are loading from CD-ROM or HMC, the kernel is already loaded
    # in memory by the first loader itself.
    $kiwi -> info ("\tSetting boot loader control to 0x10000");
    sysseek(out_fh,4,0 );
    syswrite(out_fh,pack("N",0x80010000),4);
    $kiwi -> info (
        "\tWriting kernel commandline (". length($cmdline) ." bytes):"
    );
    $kiwi -> info ("\t$cmdline");
    sysseek(out_fh,0x10480,0);
    syswrite(out_fh,$cmdline,length($cmdline));
    $kiwi -> info (
        "\tSetting initrd parameter: offset $initrd_offset size $initrd_size"
    );
    sysseek(out_fh,0x1040C,0);
    syswrite(out_fh,pack("N",$initrd_offset),4);
    sysseek(out_fh,0x10414,0);
    syswrite(out_fh,pack("N",$initrd_size),4);
    close(out_fh);
    (my $retval = $outfile) =~ s|$src/||;
    return $retval;
}

#==========================================
# createVolumeID 
#------------------------------------------
sub createVolumeID {
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $src  = $this->{source};
    my $hfsvolid = "unknown";
    my $FD;
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
        open ($FD, '<', "$src/content");
        while (my $line = <$FD>) {
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
        close $FD;
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
        } elsif (open ($FD, '<', $src."media.1/build")) {
            my $line = <$FD>;
            close $FD;
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
        return;
    }
    my $data = KIWIQX::qxx (
        "$isox --base $boot/loader $src/$boot/loader/isolinux.bin 2>&1"
    );
    my $code = $? >> 8;
    if ($code != 0) {
        # /.../
        # Could not set base directory to isolinux, therefore we
        # create a compat directory /isolinux and hardlink all files
        # ----
        my $data = KIWIQX::qxx ("mkdir -p $src/isolinux 2>&1");
        my $code = $? >> 8;
        if ($code == 0) {
            $data = KIWIQX::qxx ("ln $src/$boot/loader/* $src/isolinux/ 2>&1");
            $code = $? >> 8;
        };
    }
    return $this;
}

#==========================================
# findAndCopyMagicBlock
#------------------------------------------
sub findAndCopyMagicBlock {
    # /.../
    # Look for magic block. As we don't have a directory entry
    # for it scan backward at the position of the first few
    # files. If found copy that iso meta data
    # ----
    my $this   = shift;
    my $kiwi   = $this -> {kiwi};
    my $iso    = $this -> {dest};
    my $magicID= $this -> {magicID};
    my $tmpdir = $this -> {tmpdir};
    my $iso_fd = FileHandle -> new();
    my $iso_blk= FileHandle -> new();
    my $cnt    = 0;
    my $buf    = 0;
    my $start;
    if (! $iso_fd -> open ($iso)) {
        return;
    }
    my $files = $this -> isols();
    found: for (@{$files}) {
        next unless $_->{type} eq ' ';
        last if $cnt++ >= 8; # check only the first 8 files
        my $buf;
        for (my $i = 0; $i >= -8; $i--) { # go back up to 8 blocks
            seek $iso_fd, ($_->{start} + $i) << 11, 0;
            sysread $iso_fd, $buf, length $magicID;
            $start = $_->{start} + $i;
            if ($buf eq $magicID) {
                last found;
            }
        }
    }
    if (! $iso_blk -> open (">$tmpdir/glump")) {
        $iso -> close();
        return;
    }
    seek $iso_fd, 0, 0;
    for (my $i = 0; $i < $start + 1; $i++) {
        if (! sysread($iso_fd, $buf, 2048) == 2048) {
            return;
        }
        if (! syswrite($iso_blk, $buf, 2048) == 2048) {
            return;
        }
    }
    $iso_blk -> close();
    $iso_fd  -> close();
    $kiwi -> loginfo ("
        KIWIIsoLinux::findAndCopyMagicBlock start block at: $start\n"
    );
    $this->{magic_offset} = $start * 4;
    $this->{magic_loop_offset} = $start * 2048;
    return $start;
}

#==========================================
# isEmptyDir
#------------------------------------------
sub isEmptyDir {
    my $this  = shift;
    my $ldir  = shift;
    my $count = 0;
    if (-d $ldir) {
        opendir(my $dh, $ldir) || return;
        while (my $entry = readdir ($dh)) {
            next if $entry eq "." || $entry eq "..";
            $count++;
        }
        closedir $dh;
    }
    if ($count > 0) {
        return 0;
    }
    return 1;
}

#==========================================
# createISO
#------------------------------------------
sub createISO {
    my $this     = shift;
    my $kiwi     = $this -> {kiwi};
    my $src      = $this -> {source};
    my $dest     = $this -> {dest};
    my $para     = $this -> {params};
    my $ldir     = $this -> {tmpdir};
    my $prog     = $this -> {tool};
    my $cmdL     = $this -> {cmdL};
    my $xml      = $this -> {xml};
    my $magicID  = $this -> {magicID};
    my $addpara  = "-hide glump -hide-joliet glump";
    my $firmware = 'efi';
    my $ldir_cnt = 0;
    my %type;
    my $cmdln;
    my $hybrid;
    #==========================================
    # Lookup firmware setup
    #------------------------------------------
    if ($xml) {
        my $type = $xml -> getImageType();
        my $xmlFirmWare = $type -> getFirmwareType();
        if ($xmlFirmWare) {
            $firmware = $xmlFirmWare;
        }
        $hybrid = $type -> getHybrid();
    }
    #==========================================
    # check for pre bootloader install
    #------------------------------------------
    if ($cmdL) {
        my $editBoot = $cmdL -> getEditBootConfig();
        if ((! $editBoot) && ($xml)) {
            $editBoot = $xml -> getImageType() -> getEditBootConfig();
        }
        if ($editBoot) {
            my $rootpath = $cmdL -> getConfigDir();
            if ($rootpath) {
                if (open my $FD, '<',"$rootpath/image/main::Prepare") {
                    my $idesc = <$FD>; close $FD;
                    if ($idesc) {
                        $editBoot = $idesc."/".$editBoot;
                    }
                }
            }
            if (($editBoot) && (-e $editBoot)) {
                $kiwi -> info ("Calling pre bootloader install script...\n");
                $kiwi -> info ("--> $editBoot\n");
                system ("cd $src && chmod u+x $editBoot");
                system ("cd $src && bash --norc -c $editBoot");
            }
        }
    }
    #==========================================
    # Call mkisofs first stage
    #------------------------------------------
    if ($this -> isEmptyDir ($ldir)) {
        $cmdln = "$prog $para -o $dest $src 2>&1";
    } else {
        $cmdln = "$prog $para -o $dest $ldir $src 2>&1";
    }
    my $data = KIWIQX::qxx ( $cmdln );
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Failed to call $prog: $data");
        $kiwi -> failed ();
        $this -> cleanISO();
        return;
    }
    #==========================================
    # Call mkisofs second stage
    #------------------------------------------
    if ($hybrid) {
        if (! $this -> findAndCopyMagicBlock()) {
            $kiwi -> error  ("Failed to read magic iso header");
            $kiwi -> failed ();
            $this -> cleanISO();
            return;
        }
        if ($this -> isEmptyDir ($ldir)) {
            $cmdln = "$prog $para $addpara -o $dest $src 2>&1";
        } else {
            $cmdln = "$prog $para $addpara -o $dest $ldir $src 2>&1";
        }
        $data = KIWIQX::qxx ( $cmdln );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("Failed to call $prog: $data");
            $kiwi -> failed ();
            $this -> cleanISO();
            return;
        }
    }
    #==========================================
    # Call post bootloader install
    #------------------------------------------
    if ($cmdL) {
        my $editBoot = $cmdL -> getEditBootInstall();
        if ((! $editBoot) && ($xml)) {
            $editBoot = $xml -> getImageType() -> getEditBootInstall();
        }
        if ($editBoot) {
            my $rootpath = $cmdL -> getConfigDir();
            if ($rootpath) {
                if (open my $FD, '<',"$rootpath/image/main::Prepare") {
                    my $idesc = <$FD>; close $FD;
                    if ($idesc) {
                        $editBoot = $idesc."/".$editBoot;
                    }
                }
            }
            if (($editBoot) && (-e $editBoot)) {
                $kiwi -> info ("Calling post bootloader install script...\n");
                $kiwi -> info ("--> $editBoot\n");
                my @opts = ("'".$cmdln."'");
                system ("cd $src && chmod u+x $editBoot");
                system ("cd $src && bash --norc -c \"$editBoot @opts\"");
            }
        }
    }
    #==========================================
    # Cleanup
    #------------------------------------------
    $this -> cleanISO();
    return $this;
}

#==========================================
# isols
#------------------------------------------
sub isols {
    # /.../
    # ISO file list sorted by start address.
    # Return ref to array with files.
    # ----
    my $this = shift;
    my $iso  = $this -> {dest};
    my $fd   = FileHandle -> new();
    my $dir  = "/";
    my $files;
    local $_;
    if (! $fd -> open ("isoinfo -R -l -i $iso 2>/dev/null |")) {
        return;
    }
    while(<$fd>) {
        if(/^Directory listing of\s*(\/.*\/)/) {
            $dir = $1;
            next;
        }
        if(/^(.).*\s\[\s*(\d+)(\s+\d+)?\]\s+(.*?)\s*$/) {
            my $type = $1;
            $type = ' ' if $type eq '-';
            if($4 ne '.' && $4 ne '..') {
                push @$files, {
                    name => "$dir$4",type => $type,start => $2 + 0
                };
            }
        }
    }
    $fd -> close();
    if ($files) {
        $files = [ sort { $a->{start} <=> $b->{start} } @$files ];
    }
    return $files;
}

#==========================================
# cleanISO
#------------------------------------------
sub cleanISO {
    my $this = shift;
    my $sort = $this -> {tmpfile};
    my $ldir = $this -> {tmpdir};
    if (-f $sort) {
        KIWIQX::qxx ("rm -f $sort 2>&1");
    }
    if (-d $ldir) {
        KIWIQX::qxx ("rm -rf $ldir 2>&1");
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
    my $check= $this -> {check};
    my $data;
    if (defined $this->{check}) {
        $data = KIWIQX::qxx ("tagmedia --md5 --check --pad 150 $dest 2>&1");
    } else {
        $data = KIWIQX::qxx ("tagmedia --md5 $dest 2>&1");
    }
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Failed to call tagmedia: $data");
        $kiwi -> failed ();
        return;
    }
    return $this;
}

#==========================================
# createHybrid
#------------------------------------------
sub createHybrid {
    # ...
    # create hybrid ISO by calling isohybrid
    # ---
    my $this     = shift;
    my $mbrid    = shift;
    my $kiwi     = $this->{kiwi};
    my $iso      = $this->{dest};
    my $xml      = $this->{xml};
    my $firmware = 'efi';
    my $data;
    my $code;
    my $loop;
    my $FD;
    #==========================================
    # Lookup firmware setup
    #------------------------------------------
    if ($xml) {
        my $xmlFirmWare = $xml -> getImageType() -> getFirmwareType();
        if ($xmlFirmWare) {
            $firmware = $xmlFirmWare;
        }
    }
    #==========================================
    # Call isohybrid
    #------------------------------------------
    my $sysarch = KIWIQX::qxx ("uname -m");
    chomp $sysarch;
    if ($sysarch =~ /ppc|ia64/) {
        $kiwi -> warning (
            "Hybrid ISO not supported on $sysarch architecture"
        );
        $kiwi -> skipped ();
        return $this;
    }
    my $locator = KIWILocator -> instance();
    my $isoHybrid = $locator -> getExecPath ('isohybrid');
    if (! $isoHybrid) {
        $kiwi -> error ("Can't find isohybrid, check your syslinux version");
        $kiwi -> failed ();
        return;
    }
    my @neededOpts = qw(id offset type partok entry);
    my %optNames = %{$locator -> getExecArgsFormat ($isoHybrid, \@neededOpts)};
    if (! $optNames{'status'}) {
        $kiwi -> error ($optNames{'error'});
        $kiwi -> failed ();
        return;
    }
    my @desiredOpt = ('uefi');
    my %desOptNames = %{$locator
        -> getExecArgsFormat ($isoHybrid, \@desiredOpt )};
    if ($desOptNames{'status'}) {
        $optNames{'uefi'} = $desOptNames{'uefi'}
    }
    my $idOpt     = $optNames{'id'};
    my $offsetOpt = $optNames{'offset'};
    my $typeOpt   = $optNames{'type'};
    my $partOpt   = $optNames{'partok'};
    my $uefiOpt   = $optNames{'uefi'};
    my $entryOpt  = $optNames{'entry'};
    my $offset    = $this->{magic_offset};
    if (($firmware eq 'efi' || $firmware eq 'uefi') && (! $uefiOpt)) {
        $kiwi -> error ("installed isohybrid does not support --uefi option");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Create partition table on iso
    #------------------------------------------
    my $cmd = "$isoHybrid $offsetOpt $offset";
    if ($mbrid) {
        $cmd.= " $idOpt $mbrid $typeOpt 0x83";
    }
    if ($firmware eq 'efi' || $firmware eq 'uefi') {
        $cmd.= " $uefiOpt";
    }
    if ($firmware eq 'bios') {
        # allow to add a partition with the partition number 1 later
        # e.g for stick devices with an additional persistent write
        # partition. Along with efi the entry option has no effect.
        # Thus we make use of this feature only in standard bios mode
        $cmd.= " $entryOpt 2";
    }
    $data = KIWIQX::qxx ("$cmd $iso 2>&1");
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Failed to call isohybrid: $data");
        $kiwi -> failed ();
        return;
    }
    return $this;
}

#==========================================
# relocateCatalog
#------------------------------------------
sub relocateCatalog {
    # ...
    # mkisofs/genisoimage leave one sector empty (or fill it with
    # version info if the ISODEBUG environment variable is set) before
    # starting the path table. We use this space to move the boot
    # catalog there. It's important that the boot catalog is at the
    # beginning of the media to be able to boot on any machine
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $iso  = $this->{dest};
    my $ISO;
    $kiwi -> info ("Relocating boot catalog ");
    if (! open $ISO, '+<', "$iso") {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed opening iso file: $iso: $!");
        $kiwi -> failed ();
        return;
    }
    my $rs = read_sector_closure  ($ISO);
    my $ws = write_sector_closure ($ISO);
    local *read_sector  = $rs;
    local *write_sector = $ws;
    my $vol_descr = read_sector (0x10);
    my $vol_id = substr($vol_descr, 0, 7);
    if ($vol_id ne "\x01CD001\x01") {
        $kiwi -> failed ();
        $kiwi -> error  ("No iso9660 filesystem");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    my $path_table = unpack "V", substr($vol_descr, 0x08c, 4);
    if ($path_table < 0x11) {
        $kiwi -> failed ();
        $kiwi -> error  ("Strange path table location: $path_table");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    my $applemedia = read_sector (0x00);
    my $applemedia_id = substr($applemedia, 0x230, 19);
    if ($applemedia_id eq "Apple_partition_map") {
        $kiwi -> skipped ();
        $kiwi -> info  ("Apple partition does not need catalog relocation");
        $kiwi -> skipped ();
        close $ISO;
        return $this;
    }
    my $new_location = $path_table - 1;
    my $eltorito_descr = read_sector (0x11);
    my $eltorito_id = substr($eltorito_descr, 0, 0x1e);
    if ($eltorito_id ne "\x00CD001\x01EL TORITO SPECIFICATION") {
        $kiwi -> failed ();
        $kiwi -> error  ("Given iso is not bootable");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    my $boot_catalog = unpack "V", substr($eltorito_descr, 0x47, 4);
    if ($boot_catalog < 0x12) {
        $kiwi -> failed ();
        $kiwi -> error  ("Strange boot catalog location: $boot_catalog");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    my $vol_descr2 = read_sector ($new_location - 1);
    my $vol_id2 = substr($vol_descr2, 0, 7);
    if($vol_id2 ne "\xffCD001\x01") {
        undef $new_location;
        for (my $i = 0x12; $i < 0x40; $i++) {
            $vol_descr2 = read_sector ($i);
            $vol_id2 = substr($vol_descr2, 0, 7);
            if ($vol_id2 eq "\x00TEA01\x01" || $boot_catalog == $i + 1) {
                $new_location = $i + 1;
                last;
            }
        }
    }
    if (! defined $new_location) {
        $kiwi -> failed ();
        $kiwi -> error  ("Unexpected iso layout");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    if ($boot_catalog == $new_location) {
        $kiwi -> skipped ();
        $kiwi -> info ("Boot catalog already relocated");
        $kiwi -> done ();
        close $ISO;
        return $this;
    }
    my $version_descr = read_sector ($new_location);
    if (
        ($version_descr ne ("\x00" x 0x800)) &&
        (substr($version_descr, 0, 4) ne "MKI ")
    ) {
        $kiwi -> skipped ();
        $kiwi -> info  ("Unexpected iso layout");
        $kiwi -> skipped ();
        close $ISO;
        return $this;
    }
    my $boot_catalog_data = read_sector ($boot_catalog);
    #==========================================
    # now reloacte to $path_table - 1
    #------------------------------------------
    substr($eltorito_descr, 0x47, 4) = pack "V", $new_location;
    write_sector ($new_location, $boot_catalog_data);
    write_sector (0x11, $eltorito_descr);
    close $ISO;
    $kiwi -> note ("from sector $boot_catalog to $new_location");
    $kiwi -> done();
    return $this;
}

#==========================================
# makeIsoEFIBootable
#------------------------------------------
sub makeIsoEFIBootable {
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $source = $this->{source};
    my $efi_arch = 'x86_64';
    my $firmware = 'bios';
    if ($xml) {
        my $type = $xml -> getImageType();
        my $xmlFirmWare = $type -> getFirmwareType();
        if ($xmlFirmWare) {
            $firmware = $xmlFirmWare;
        }
    }
    if ($firmware eq 'bios') {
        $kiwi -> loginfo (
            "makeIsoEFIBootable: No EFI firmware requested"
        );
        return $this;
    }
    my $arch = KIWIQX::qxx ("uname -m");
    chomp $arch;
    if ($arch =~ /i.86/) {
        $efi_arch = 'i386';
    } else {
        $efi_arch = $arch;
    }
    my $efi_fat = "$source/boot/$efi_arch/efi";
    if (-e $efi_fat) {
        $kiwi -> loginfo (
            "makeIsoEFIBootable: EFI fat image already exists"
        );
        return $this;
    }
    my $status = KIWIQX::qxx ("mkdir -p $source/boot/$efi_arch");
    my $result = $? >> 8;
    if ($result == 0) {
        my $locator = KIWILocator -> instance();
        my $qemu_img = $locator -> getExecPath ("qemu-img");
        if ($qemu_img) {
            $status = KIWIQX::qxx ("$qemu_img create $efi_fat 4M 2>&1");
            $result = $? >> 8;
        } else {
            $status = "Mandatory qemu-img tool not found";
            $result = 1;
        }
    }
    if ($result == 0) {
        $status = KIWIQX::qxx ("/sbin/mkdosfs -n 'BOOT' $efi_fat 2>&1");
        $result = $? >> 8;
        if ($result == 0) {
            $status = KIWIQX::qxx (
                "mcopy -Do -s -i $efi_fat $source/EFI :: 2>&1"
            );
            $result = $? >> 8;
        }
    }
    if ($result != 0) {
        $kiwi -> error  ("Failed creating efi fat image: $status");
        $kiwi -> failed ();
        return;
    }
    $this->{bootloadsize} = -s $efi_fat;
    return $this;
}

#==========================================
# fixCatalog
#------------------------------------------
sub fixCatalog {
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $iso  = $this->{dest};
    my $ISO;
    $kiwi -> info ("Fixing boot catalog according to standard");
    if (! open $ISO, '+<', "$iso") {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed opening iso file: $iso: $!");
        $kiwi -> failed ();
        return;
    }
    my $rs = read_sector_closure  ($ISO);
    my $ws = write_sector_closure ($ISO);
    local *read_sector  = $rs;
    local *write_sector = $ws;
    my $vol_descr = read_sector (0x10);
    my $vol_id = substr($vol_descr, 0, 7);
    if ($vol_id ne "\x01CD001\x01") {
        $kiwi -> failed ();
        $kiwi -> error  ("No iso9660 filesystem");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    my $applemedia = read_sector (0x00);
    my $applemedia_id = substr($applemedia, 0x230, 19);
    if ($applemedia_id eq "Apple_partition_map") {
        $kiwi -> skipped ();
        $kiwi -> info  ("Apple partition does not need catalog relocation");
        $kiwi -> skipped ();
        close $ISO;
        return $this;
    }
    my $eltorito_descr = read_sector (0x11);
    my $eltorito_id = substr($eltorito_descr, 0, 0x1e);
    if ($eltorito_id ne "\x00CD001\x01EL TORITO SPECIFICATION") {
        $kiwi -> failed ();
        $kiwi -> error  ("ISO Not bootable");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    my $boot_catalog_idx = unpack "V", substr($eltorito_descr, 0x47, 4);
    if ($boot_catalog_idx < 0x12) {
        $kiwi -> failed ();
        $kiwi -> error  ("Strange boot catalog location: $boot_catalog_idx");
        $kiwi -> failed ();
        close $ISO;
        return;
    }
    my $boot_catalog = read_sector ($boot_catalog_idx);
    my $entry1 = substr $boot_catalog, 32 * 1, 32;
    substr($entry1, 12, 20) = pack "Ca19", 1, "Legacy (isolinux)";
    substr($boot_catalog, 32 * 1, 32) = $entry1;
    my $entry2 = substr $boot_catalog, 32 * 2, 32;
    substr($entry2, 12, 20) = pack "Ca19", 1, "UEFI (elilo)";
    if((unpack "C", $entry2)[0] == 0x88) {
        substr($boot_catalog, 32 * 3, 32) = $entry2;
        $entry2 = pack "CCva28", 0x91, 0xef, 1, "";
        substr($boot_catalog, 32 * 2, 32) = $entry2;
        write_sector ($boot_catalog_idx, $boot_catalog);
        $kiwi -> done();
    } else {
        $kiwi -> skipped();
    }
    close $ISO;
    return $this;
}

#==========================================
# read_sector_closure
#------------------------------------------
sub read_sector_closure {
    my $ISO = shift;
    return sub {
        my $buf;
        if (! seek $ISO, $_[0] * 0x800, 0) {
            return;
        }
        if (sysread($ISO, $buf, 0x800) != 0x800) {
            return;
        }
        return $buf;
    }
}

#==========================================
# write_sector_closure
#------------------------------------------
sub write_sector_closure {
    my $ISO = shift;
    return sub {
        if (! seek $ISO, $_[0] * 0x800, 0) {
            return;
        }
        if (syswrite($ISO, $_[1], 0x800) != 0x800) {
            return;
        }
    }
}

#==========================================
# getTool
#------------------------------------------
sub getTool {
    # ...
    # return ISO toolkit name used on this system
    # ---
    my $this = shift;
    my $tool = $this->{tool};
    return basename $tool;
}

#==========================================
# __generateWanted
#------------------------------------------
sub __generateWanted {
    my $this = shift;
    my $filelist = shift;
    return sub {
        push (@{$filelist},$File::Find::name);
    }
}

1;
