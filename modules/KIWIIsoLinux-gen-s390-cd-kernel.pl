#!/usr/bin/perl -w
#
# Generates a bootable CD-ROM for S/390
#
# Copyright (C) 2006 Novell Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street,
# Fifth Floor,
# Boston, MA  02110-1301,
# USA.
#
# $Id: gen-s390-cd-kernel.pl 107 2009-03-06 11:48:14Z ro $

use FileHandle;
use Getopt::Long;
use strict;

# Help text
#
sub help($) {
	my $exitcode = shift || 1;
    print "Usage: $0 <OPTIONS> - generate a kernel image for CD-ROM boot\n";
    print "SYNOPSIS: $0 [--initrd=file] \n";
	print "             [--parmfile=file] [--outfile=file] \n";
	print "	            [--kernel=file] [--cmdline=string] \n";
    exit $exitcode;
}

# Parse command line options
my ($initrd,       $image,        $parmfile, $outfile,        $cmdline ) =
   ('/boot/initrd','/boot/image', '',        '/tmp/image.cd', 'root=/dev/sda2');

Getopt::Long::Configure ("bundling");
eval {
    unless (GetOptions (
	'i|initrd=s' => \$initrd,
	'k|kernel=s' => \$image,
	'p|parmfile=s' => \$parmfile,
	'o|outfile=s' => \$outfile,
	'c|cmdline=s' => \$cmdline,
	'h|help' => sub { help(0); } )) {
	help(1);
    }
};

if ($@) {
    print "$@";
    help(1);
}

# Open input files
sysopen(image_fh,$image,O_RDONLY) or die "Cannot open $image: $!\n";
sysopen(initrd_fh,$initrd,O_RDONLY) or die "Cannot $initrd: $!\n";

my $image_size = (stat(image_fh))[7];
my $initrd_size = (stat(initrd_fh))[7];

# Get the size of the input files
printf("%s: offset 0x%x len 0x%x (%d blocks)\n", 
       $image, 0, $image_size, ($image_size >> 12) + 1);

# The kernel appearently needs some free space above the
# actual image (bss? stack?), so use this hard-coded
# limit (from include/asm-s390/setup.h)

# my $initrd_offset = (($image_size >> 12) + 1) << 12;
my $initrd_offset = 0x800000;
my $boot_size = ((($initrd_offset + $initrd_size) >> 12) + 1 ) << 12;
printf("%s: offset 0x%x len 0x%x (%d blocks)\n", 
       $initrd, $initrd_offset, $initrd_size, ($initrd_size >>12) + 1);
printf("%s: len 0x%x (%d blocks)\n", 
       $outfile, $initrd_offset + $initrd_size, $boot_size / 4096);

# Get the kernel command line arguments
$cmdline .= " " if ($cmdline ne "");

if ($parmfile ne "") {
    my $line;

    $cmdline = '';
    open(parm_fh,$parmfile) or die "Cannot open $parmfile: $!\n";
    while($line=<parm_fh>) {
	    chomp $line;
        $cmdline .= $line . " ";
    }
    close(parm_fh);
}

if ($cmdline ne "") {
    chop $cmdline;
}

# Max length for the kernel command line is 896 bytes
die "Kernel commandline too long (". length($cmdline) ." bytes)\n" if (length($cmdline) >= 896);

# Now create the image file.
sysopen(out_fh,$outfile,O_RDWR|O_CREAT|O_TRUNC) or die "Cannot open $outfile: $!\n";

# First fill the entire size with zeroes
sysopen(null_fh,"/dev/zero",O_RDONLY) or die "Cannot open /dev/zero: $!\n";

my $buffer="";
my $blocks_read=0;
while ($blocks_read < ($boot_size >> 12)) {
    sysread(null_fh,$buffer, 4096);
    syswrite(out_fh,$buffer);
    $blocks_read += 1;
}

print "Read $blocks_read blocks from /dev/zero\n";
close(null_fh);

# Now copy the image file to location 0
sysseek(out_fh,0,0);
$blocks_read = 0;
while (sysread(image_fh,$buffer, 4096) != 0) {
    syswrite(out_fh,$buffer,4096);
    $blocks_read += 1;
}

print "Read $blocks_read blocks from $image\n";
close(image_fh);

# Then the initrd to location specified by initrd_offset
sysseek(out_fh,$initrd_offset,0);
$blocks_read = 0;
while (sysread(initrd_fh,$buffer, 4096) != 0) {
    syswrite(out_fh,$buffer,4096);
    $blocks_read += 1;
}

print "Read $blocks_read blocks from $initrd\n";

close(initrd_fh);

# Now for the real black magic.
# If we are loading from CD-ROM or HMC, the kernel is already loaded
# in memory by the first loader itself.
print "Setting boot loader control to 0x10000\n";

sysseek(out_fh,4,0 );
syswrite(out_fh,pack("N",0x80010000),4);

print "Writing kernel commandline (". length($cmdline) ." bytes):\n$cmdline\n";

sysseek(out_fh,0x10480,0);
syswrite(out_fh,$cmdline,length($cmdline));

print "Setting initrd parameter: offset $initrd_offset size $initrd_size\n";

sysseek(out_fh,0x1040C,0);
syswrite(out_fh,pack("N",$initrd_offset),4);
sysseek(out_fh,0x10414,0);
syswrite(out_fh,pack("N",$initrd_size),4);

close(out_fh);
