#================
# FILE          : KIWIImage.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create a logical
#               : extend, an image file based on a Linux
#               : filesystem
#               : 
#               :
# STATUS        : Development
#----------------
package KIWIImage;
#==========================================
# Modules
#------------------------------------------
use strict;
use KIWILog;
use Math::BigFloat;

#==========================================
# Private
#------------------------------------------
my $imageTree;
my $imageDest;
my $kiwi;
my $xml;

#==========================================
# Constructor
#------------------------------------------
sub new {
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi = shift;
	$xml  = shift;
	$imageTree = shift;
	$imageDest = shift;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (! defined $imageTree) {
		$kiwi -> error  ("No image tree specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! -f "$imageTree/etc/ImageVersion") {
		$kiwi -> error  ("Validation of $imageTree failed");
		$kiwi -> failed ();
		return undef;
	}
	if (! -d $imageDest) {
		$kiwi -> error  ("No valid destdir: $imageDest");
		$kiwi -> failed ();
		return undef;
	}
	return $this;
}

#==========================================
# createImageEXT2
#------------------------------------------
sub createImageEXT2 {
	# ...
	# Create EXT2 image from source tree
	# ---
	my $this    = shift;
	my $journal = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = preImage ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	my $fsopts;
	my $fileCount = int (qx (find $imageTree | wc -l));
	my $nodeCount = $fileCount * 2;
	if (defined $journal) {
		$fsopts = "-b 4096 -j -J size=4 -q -F -N $nodeCount";
	} else {
		$fsopts = "-q -F -N $nodeCount";
	}
	my $data = qx (mke2fs $fsopts $imageDest/$name >/dev/null);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! postImage ($name)) {
		return undef;
	}
	return $this;
}

#==========================================
# createImageEXT3
#------------------------------------------
sub createImageEXT3 {
	# ...
	# create journaled EXT3 image from source tree
	# ---
	createImageEXT2 ("journaled");
}

#==========================================
# createImageReiserFS
#------------------------------------------
sub createImageReiserFS {
	# ...
	# create journaled ReiserFS image from source tree
	# ---
	my $this = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = preImage ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	my $data = qx (mkreiserfs -b 4096 -q $imageDest/$name 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! postImage ($name)) {
		return undef;
	}
	return $this;
}

#==========================================
# createImageCramFS
#------------------------------------------
sub createImageCramFS {
	# ...
	# create cpio archive from the image source tree
	# The kernel will use this archive and mount it as
	# cramfs type
	# ---
	my $this = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = preImage ("haveExtend");
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	my @cpio = ("--create", "--format=newc", "--quiet");
	my $tree = $imageTree;
	my $dest = $imageDest."/".$name.".gz";
	my $data = qx (cd $tree && find . | cpio @cpio | gzip > $dest);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create cpio archive");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! buildMD5Sum ($name.".gz")) {
		return undef;
	}
	return $this;
}

#==========================================
# getBlocks
#------------------------------------------
sub getBlocks {
	# ...
	# calculate the block size and number of blocks used
	# to create a <size> bytes long image. Return list
	# (bs,count)
	# ---
	my $size = $_[0];
	my $bigimage   = 1048576; # 1M
	my $smallimage = 8192;    # 8K
	my $number;
	my $suffix;
	if ($size =~ /(\d+)(.*)/) {
		$number = $1;
		$suffix = $2;
		if ($suffix eq "") {
			return (($size,1));
		} else {
			SWITCH: for ($suffix) { 
			/K/i   && do {
				$number *= 1024;
			last SWITCH;
			}; 
			/M/i   && do {
				$number *= 1024 * 1024;
			last SWITCH;
			}; 
			/G/i   && do {
				$number *= 1024 * 1024 * 1024;
			last SWITCH;
			};
			# default...
			return (($size,1));
			}
		}
	} else {
		return (($size,1));
	}
	my $count;
	if ($number > 100 * 1024 * 1024) {
		# big image...
		$count = $number / $bigimage;
		$count = Math::BigFloat->new($count)->ffround(0);
		return (($bigimage,$count));
	} else {
		# small image...
		$count = $number / $smallimage;
		$count = Math::BigFloat->new($count)->ffround(0);
		return (($smallimage,$count));
	}
}

#==========================================
# preImage
#------------------------------------------
sub preImage {
	# ...
	# pre-stage preparation of a logical extend.
	# This method includes all common not filesystem
	# dependant tasks before the logical extend
	# has been created
	# ---
	my $haveExtend = shift;
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $name = buildImageName ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	if (! extractKernel ($name)) {
		return undef;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! setupLogicalExtend ()) {
		return undef;
	}
	#==========================================
	# Create logical extend
	#------------------------------------------
	if (! defined $haveExtend) {
	if (! buildLogicalExtend ($name)) {
		return undef;
	}
	}
	return $name;
}

#==========================================
# postImage
#------------------------------------------
sub postImage {
	# ...
	# post-stage preparation of a logical extend.
	# This method includes all common not filesystem
	# dependant tasks after the logical extend has
	# been created
	# ---
	my $name = shift;
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	my $extend = mountLogicalExtend ($name);
	if (! defined $extend) {
		return undef;
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	if (! installLogicalExtend ($extend)) {
		return undef;
	}
	cleanMount();

	#==========================================
	# Check image file system
	#------------------------------------------
	$kiwi -> info ("Checking file system...");
	my $type = $xml->getImageType();
	SWITCH: for ($type) {
		#==========================================
		# Check EXT3 file system
		#------------------------------------------
		/ext3/i && do {
			qx (fsck.ext3 -f -y $imageDest/$name 2>&1);
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT2 file system
		#------------------------------------------
		/ext2/i && do {
			qx (e2fsck -f -y $imageDest/$name 2>&1);
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check ReiserFS file system
		#------------------------------------------
		/reiserfs/i && do {
			qx (reiserfsck -y $imageDest/$name 2>&1);
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Unknown filesystem type
		#------------------------------------------
		$kiwi -> failed();
		$kiwi -> error ("Unsupported filesystem type: $type");
		$kiwi -> failed();
		return undef;
	}
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! buildMD5Sum ($name)) {
		return undef;
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if ($xml->getCompressed()) {
	if (! compressImage ($name)) {
		return undef;
	}
	}
}

#==========================================
# buildImageName
#------------------------------------------
sub buildImageName {
	if (! open (FD,"$imageTree/image/VERSION")) {
		$kiwi -> error  ("Couldn't open image VERSION file");
		$kiwi -> failed ();
		return undef;
	}
	my $iver = <FD>; close FD; chomp ($iver);
	my $name = $xml -> getImageName();
	$name = $name."-".$iver;
	chomp  $name;
	return $name;
}

#==========================================
# buildLogicalExtend
#------------------------------------------
sub buildLogicalExtend {
	my $name = shift;
	#==========================================
	# Calculate block size and number of blocks
	#------------------------------------------
	my @bsc  = getBlocks ( $xml -> getImageSize() );
	my $bs   = $bsc[0];
	my $cnt  = $bsc[1];
	#==========================================
	# Create logical extend storage and FS
	#------------------------------------------
	my $data = qx (dd if=/dev/zero of=$imageDest/$name bs=$bs count=$cnt 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create logical extend");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	return $name;
}

#==========================================
# installLogicalExtend
#------------------------------------------
sub installLogicalExtend {
	my $extend = shift;
	#==========================================
	# copy physical to logical
	#------------------------------------------
	$kiwi -> info ("Copying physical to logical...");
	my $data = qx (cp -a $imageTree/* $extend 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> info   ("No space left on device: $!");
		$kiwi -> failed ();
		cleanMount();
		return undef;
	}
	$kiwi -> done();
	return $extend;
}

#==========================================
# setupLogicalExtend
#------------------------------------------
sub setupLogicalExtend {
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (-x "$imageTree/image/images.sh") {
		$kiwi -> info ("Calling image script: images.sh");
		my $data = qx ( chroot $imageTree /image/images.sh 2>&1 );
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			cleanMount();
			return undef;
		}
		qx ( rm -f $imageTree/image/images.sh );
		$kiwi -> done ();
	}
	#==========================================
	# Calculate needed space
	#------------------------------------------
	my $mbytes = getSize ($imageTree);
	$kiwi -> info ("Image requires $mbytes MB of disk space");
	$kiwi -> done ();
	return $mbytes;
}

#==========================================
# mountLogicalExtend
#------------------------------------------
sub mountLogicalExtend {
	my $name = shift;
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	mkdir "$imageDest/mnt-$$";
	my $data = qx (mount -oloop $imageDest/$name $imageDest/mnt-$$);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't mount image");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	return "$imageDest/mnt-$$";
}

#==========================================
# extractKernel
#------------------------------------------
sub extractKernel {
	my $name = shift;
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	# This is done for boot images only. Which means
	# we will check for a file named vmlinux.gz. This file
	# is created from the default-kernel package script which
	# exists for boot images only
	# ---
	if (-f "$imageTree/boot/vmlinux.gz") {
		$kiwi -> info ("Extracting kernel...");
		my $file = "$imageDest/$name.kernel";
		my $lx = '"^Linux version"';
		my $sp = '-f3 -d" "';
		qx (cp $imageTree/boot/vmlinuz $file);
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ("Failed to extract kernel: $!");
			$kiwi -> failed ();
			return undef;
		}
		my $gzfile = "$imageTree/boot/vmlinux.gz";
		my $kernel = qx (gzip -dc $gzfile | strings | grep $lx | cut $sp);
		chomp $kernel;
		qx (mv $file $file.$kernel);
		$kiwi -> done();
	}
	return $name;
}

#==========================================
# buildMD5Sum
#------------------------------------------
sub buildMD5Sum {
	my $name = shift;
	#==========================================
	# Create image md5sum
	#------------------------------------------
	$kiwi -> info ("Creating image MD5 sum...");
	my $size = -s "$imageDest/$name";
	my $primes = qx (factor $size); $primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		last if ($blocksize * $factor > 8192);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qx (cat $imageDest/$name | md5sum - | cut -f 1 -d-);
	chomp $sum;
	if ($name =~ /\.gz$/) {
		$name =~ s/\.gz//;
	}
	qx (echo "$sum $blocks $blocksize" > $imageDest/$name.md5);
	$kiwi -> done();
	return $name;
}

#==========================================
# compressImage
#------------------------------------------
sub compressImage {
	my $name = shift;
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	$kiwi -> info ("Compressing image...");
	my $data = qx (gzip $imageDest/$name);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Compressing image failed: $!");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
	return $name;
}

#==========================================
# getSize
#------------------------------------------
sub getSize {
	# ...
	# calculate size of the logical extend. The
	# method returns the size value in MegaByte
	# ---
	my $extend = shift;
	my $size = qx ( du -ks $extend );
	$size =~ /(\d+)\s.*/;
	#==========================================
	# Add 10% more space for later filesystem
	#------------------------------------------
	my $spare = 0.1 * $size;
	$size += $spare;
	$size /= 1024;
	$size = int ($size);
	return $size;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	qx (umount $imageDest/mnt-$$ 2>&1);
	rmdir "$imageDest/mnt-$$";
}

1;
