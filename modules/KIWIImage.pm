#================
# FILE          : KIWIImage.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2015 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create a logical
#               : extend, an image file based on a Linux
#               : filesystem
#               :
# STATUS        : Development
#----------------
package KIWIImage;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use Fcntl ':mode';
use FileHandle;
use File::Basename;
use File::Find qw(find);
use File::stat;
use Math::BigFloat;
use POSIX qw(getcwd);

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIBoot;
use KIWICommandLine;
use KIWIIsoLinux;
use KIWILog;
use KIWIQX;
use KIWIXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create a new KIWIImage object which is used to create
    # the different output image formats from a previosly
    # prepared physical extend
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
    my $xml        = shift;
    my $imageTree  = shift;
    my $imageDest  = shift;
    my $imageStrip = shift;
    my $baseSystem = shift;
    my $imageOrig  = shift;
    my $initCache  = shift;
    my $cmdL       = shift;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    my $msg  = 'KIWIImage: ';
    if (! defined $xml || ref($xml) ne 'KIWIXML') {
        $msg .= 'expecting KIWIXML object as first argument.';
        $kiwi -> error($msg);
        $kiwi -> failed ();
        return;
    }
    if (! defined $imageTree) {
        $msg .= 'expecting unpacked image directory ';
        $msg .= 'path as second argument.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! defined $imageDest) {
        $msg .= 'expecting destination directory as third argument.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! -d $imageDest) {
        $msg .= "given destination directory '$imageDest' ";
        $msg .= 'does not exist';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    if (! defined $baseSystem) {
        $msg .= 'expecting system path as fifth argument';
        $kiwi -> error ($msg);
        $kiwi -> failed ();
        return;
    }
    if (! defined $cmdL || ref($cmdL) ne 'KIWICommandLine') {
        $msg .= 'expecting KIWICommandLine object as eigth argument';
        $kiwi -> error($msg);
        $kiwi -> failed ();
        return;
    }
    my $configFile = $xml -> getConfigName();
    if (! -f $configFile) {
        $kiwi -> error  ("Validation of $imageTree failed");
        $kiwi -> failed ();
        return;
    }
    if (! $cmdL -> getLogFile()) {
        $imageTree =~ s/\/$//;
        if (defined $imageOrig) {
            $kiwi -> setRootLog ($imageOrig.".".$$.".screenrc.log");
        } else {
            $kiwi -> setRootLog ($imageTree.".".$$.".screenrc.log");
        }
    }
    #==========================================
    # Use absolute path for image destination
    #------------------------------------------
    if ($imageDest !~ /^\//) {
        my $pwd = getcwd();
        $imageDest = $pwd."/".$imageDest;
    }
    #==========================================
    # Store object data
    #------------------------------------------
    my $global = KIWIGlobals -> instance();
    $this->{kiwi}       = $kiwi;
    $this->{cmdL}       = $cmdL;
    $this->{initCache}  = $initCache;
    $this->{xml}        = $xml;
    $this->{imageTree}  = $imageTree;
    $this->{imageDest}  = $imageDest;
    $this->{imageStrip} = $imageStrip;
    $this->{baseSystem} = $baseSystem;
    $this->{gdata}      = $global -> getKiwiConfig();
    #==========================================
    # Mount overlay tree if required...
    #------------------------------------------
    $this -> setupOverlay();
    #==========================================
    # read origin path of XML description
    #------------------------------------------
    if (open my $FD, '<', "$imageTree/image/main::Prepare") {
        my $idesc = <$FD>; close $FD;
        $this->{originXMLPath} = $idesc;
    }
    #==========================================
    # Store a disk label ID for this object
    #------------------------------------------
    $this->{mbrid} = KIWIGlobals -> instance() -> getMBRDiskLabel (
        $cmdL -> getMBRID()
    );
    #==========================================
    # Clean kernel mounts if any
    #------------------------------------------
    $this -> cleanKernelFSMount();
    return $this;
}

#==========================================
# executeUserImagesScript
#------------------------------------------
sub executeUserImagesScript {
    # ...
    # Execute the images.sh script if it exists
    # ---
    my $this = shift;
    my $imageTree = $this->{imageTree};
    my $kiwi      = $this->{kiwi};
    if (-x "$imageTree/image/images.sh") {
        $kiwi -> info ('Calling image script: images.sh');
        my ($code,$data) = KIWIGlobals -> instance() -> callContained (
            $imageTree,"/image/images.sh"
        );
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> info   ($data);
            $this -> cleanMount();
            return;
        } else {
            $kiwi -> loginfo ("images.sh: $data");
        }
        $kiwi -> done ();
    }
    return $this;
}

#==========================================
# getImageTree
#------------------------------------------
sub getImageTree {
    # ...
    # return current value of system image tree. Normally
    # this is the same as given in the module parameter list
    # but in case of an overlay cache mount the path changes
    # ---
    my $this = shift;
    return $this->{imageTree}
}

#==========================================
# setupOverlay
#------------------------------------------
sub setupOverlay {
    # ...
    # mount the image cache if the image is based on it
    # and register the overlay mount point as new imageTree
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $tree = $this->{imageTree};
    my $xml  = $this->{xml};
    $this->{overlay} = KIWIOverlay -> new($tree);
    if (! $this->{overlay}) {
        return;
    }
    $this->{imageTree} = $this->{overlay} -> mountOverlay();
    if (! defined $this->{imageTree}) {
        return;
    }
    return $this;
}

#==========================================
# stripImage
#------------------------------------------
sub stripImage {
    # ...
    # remove symbols from shared objects and binaries
    # using strip -p
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $imageTree = $this->{imageTree};
    $kiwi -> info ("Stripping shared objects/executables...");
    my $list = KIWIQX::qxx ("find $imageTree -type f -perm -755");
    my @list = split(/\n/,$list);
    foreach my $file (@list) {
        chomp $file;
        my $data = KIWIQX::qxx ("file \"$file\"");
        chomp $data;
        if ($data =~ /not stripped/) {
        if ($data =~ /shared object/) {
            KIWIQX::qxx ("strip -p $file 2>&1");
        }
        if ($data =~ /executable/) {
            KIWIQX::qxx ("strip -p $file 2>&1");
        }
        }
    }
    $kiwi -> done ();
    return $this;
}

#==========================================
# createImageClicFS
#------------------------------------------
sub createImageClicFS {
    # ...
    # create compressed loop image container
    # ---
    my $this    = shift;
    my $rename  = shift;
    my $journal = "journaled-ext4";
    my $kiwi    = $this->{kiwi};
    my $data;
    my $code;
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ();
    if (! defined $name) {
        return;
    }
    if (defined $rename) {
        $data = KIWIQX::qxx (
            "mv $this->{imageDest}/$name $this->{imageDest}/$rename 2>&1"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("Can't rename image file");
            $kiwi -> failed ();
            $kiwi -> error  ($data);
            return;
        }
        $name = $rename;
    }
    #==========================================
    # Create ext4 filesystem on extend
    #------------------------------------------
    if (! $this -> setupEXT2 ( $name,$journal )) {
        return;
    }
    #==========================================
    # POST filesystem setup
    #------------------------------------------
    if (! $this -> postImage ($name,"nozip","clicfs")) {
        return;
    }
    #==========================================
    # Rename filesystem loop file
    #------------------------------------------
    $data = KIWIQX::qxx (
        "mv $this->{imageDest}/$name $this->{imageDest}/fsdata.ext4 2>&1"
    );
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Can't move file to fsdata.ext4");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    #==========================================  
    # Resize to minimum  
    #------------------------------------------
    my $rver= KIWIQX::qxx (
        "resize2fs --version 2>&1 | head -n 1 | cut -f2 -d ' ' | cut -f1-2 -d."
    ); chomp $rver;
    my $dfs = "/sbin/debugfs";
    my $req = "-R 'show_super_stats -h'";
    my $bcn = "'^Block count:'";
    my $bfr = "'^Free blocks:'";
    my $src = "$this->{imageDest}/fsdata.ext4";
    my $blocks = 0;
    $kiwi -> loginfo ("Using resize2fs version: $rver\n");
    if ($rver >= 1.41) {
        $data = KIWIQX::qxx (
            "resize2fs $this->{imageDest}/fsdata.ext4 -M 2>&1"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("Failed to resize ext3 container: $data");
            $kiwi -> failed ();
            return;
        }
    } else {
        $data = KIWIQX::qxx (
            "$dfs $req $src 2>/dev/null | grep $bcn | sed -e 's,.*: *,,'"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("debugfs: block count request failed: $data");
            $kiwi -> failed ();
            return;
        }
        chomp $data;
        $blocks = $data;  
        $data = KIWIQX::qxx (
            "$dfs $req $src 2>/dev/null | grep $bfr | sed -e 's,.*: *,,'"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("debugfs: free blocks request failed: $data");
            $kiwi -> failed ();
            return;
        }  
        $kiwi -> info ("clicfs: blocks count=$blocks free=$data");
        $blocks = $blocks - $data;  
        $data = KIWIQX::qxx (
            "resize2fs $this->{imageDest}/fsdata.ext4 $blocks 2>&1"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("Failed to resize ext3 container: $data");
            $kiwi -> failed ();
            return;
        }
    }
    #==========================================
    # Create clicfs filesystem from ext4
    #------------------------------------------
    $kiwi -> info (
        "Creating clicfs container: $this->{imageDest}/$name.clicfs"
    );
    my $clicfs = "mkclicfs";
    if (defined $ENV{MKCLICFS_COMPRESSION}) {
        my $c = int $ENV{MKCLICFS_COMPRESSION};
        my $d = $this->{imageDest};
        $data = KIWIQX::qxx ("$clicfs -c $c $d/fsdata.ext4 $d/$name 2>&1");
    } else {
        my $d = $this->{imageDest};
        $data = KIWIQX::qxx ("$clicfs $d/fsdata.ext4 $d/$name 2>&1");
    }
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create clicfs filesystem");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    KIWIQX::qxx (
        "mv -f $this->{imageDest}/$name.ext4 $this->{imageDest}/$name.clicfs"
    );
    KIWIQX::qxx (
        "rm -f $this->{imageDest}/fsdata.ext4"
    );
    $kiwi -> done();
    #==========================================
    # Create image md5sum
    #------------------------------------------
    if (! $this -> buildMD5Sum ($name)) {
        return;
    }
    return $this;
}

#==========================================
# createImageEXT
#------------------------------------------
sub createImageEXT {
    # ...
    # Create EXT2 image from source tree
    # ---
    my $this    = shift;
    my $journal = shift;
    my $device  = shift;
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ($device);
    if (! defined $name) {
        return;
    }
    if ($this->{targetDevice}) {
        $device = $this->{targetDevice};
    }
    #==========================================
    # Create filesystem on extend
    #------------------------------------------
    if (! $this -> setupEXT2 ( $name,$journal,$device )) {
        return;
    }
    #==========================================
    # POST filesystem setup
    #------------------------------------------
    if (! $this -> postImage ($name,undef,undef,$device)) {
        return;
    }
    return $this;
}

#==========================================
# createImageEXT2
#------------------------------------------
sub createImageEXT2 {
    # ...
    # create journaled EXT2 image from source tree
    # ---
    my $this = shift;
    my $device  = shift;
    my $journal = "journaled-ext2";
    return $this -> createImageEXT ($journal,$device);
}

#==========================================
# createImageEXT3
#------------------------------------------
sub createImageEXT3 {
    # ...
    # create journaled EXT3 image from source tree
    # ---
    my $this = shift;
    my $device  = shift;
    my $journal = "journaled-ext3";
    return $this -> createImageEXT ($journal,$device);
}

#==========================================
# createImageEXT4
#------------------------------------------
sub createImageEXT4 {
    # ...
    # create journaled EXT4 image from source tree
    # ---
    my $this = shift;
    my $device  = shift;
    my $journal = "journaled-ext4";
    return $this -> createImageEXT ($journal,$device);
}

#==========================================
# createImageReiserFS
#------------------------------------------
sub createImageReiserFS {
    # ...
    # create journaled ReiserFS image from source tree
    # ---
    my $this = shift;
    my $device  = shift;
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ($device);
    if (! defined $name) {
        return;
    }
    if ($this->{targetDevice}) {
        $device = $this->{targetDevice};
    }
    #==========================================
    # Create filesystem on extend
    #------------------------------------------
    if (! $this -> setupReiser ( $name,$device )) {
        return;
    }
    #==========================================
    # POST filesystem setup
    #------------------------------------------
    if (! $this -> postImage ($name,undef,undef,$device)) {
        return;
    }
    return $this;
}

#==========================================
# createImageBTRFS
#------------------------------------------
sub createImageBTRFS {
    # ...
    # create BTRFS image from source tree
    # ---
    my $this   = shift;
    my $device = shift;
    my $rename = shift;
    my $kiwi   = $this->{kiwi};
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ($device);
    if (! defined $name) {
        return;
    }
    if ($this->{targetDevice}) {
        $device = $this->{targetDevice};
    }
    if (defined $rename) {
        my $data = KIWIQX::qxx (
            "mv $this->{imageDest}/$name $this->{imageDest}/$rename 2>&1"
        );
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("Can't rename image file");
            $kiwi -> failed ();
            $kiwi -> error  ($data);
            return;
        }
        $name = $rename;
    }
    #==========================================
    # Create filesystem on extend
    #------------------------------------------
    if (! $this -> setupBTRFS ( $name,$device )) {
        return;
    }
    #==========================================
    # POST filesystem setup
    #------------------------------------------
    if (! $this -> postImage ($name,undef,'btrfs',$device)) {
        return;
    }
    return $this;
}

#==========================================
# createImageZFS
#------------------------------------------
sub createImageZFS {
    # ...
    # create ZFS image from source tree
    # ---
    my $this   = shift;
    my $device = shift;
    my $kiwi   = $this->{kiwi};
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ($device);
    if (! defined $name) {
        return;
    }
    if ($this->{targetDevice}) {
        $device = $this->{targetDevice};
    }
    #==========================================
    # Create filesystem on extend
    #------------------------------------------
    if (! $this -> setupZFS ( $name,$device )) {
        return;
    }
    #==========================================
    # POST filesystem setup
    #------------------------------------------
    if (! $this -> postImage ($name,undef,undef,$device)) {
        return;
    }
    return $this;
}

#==========================================
# createImageXFS
#------------------------------------------
sub createImageXFS {
    # ...
    # create XFS image from source tree
    # ---
    my $this   = shift;
    my $device = shift;
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ($device);
    if (! defined $name) {
        return;
    }
    if ($this->{targetDevice}) {
        $device = $this->{targetDevice};
    }
    #==========================================
    # Create filesystem on extend
    #------------------------------------------
    if (! $this -> setupXFS ( $name,$device )) {
        return;
    }
    #==========================================
    # POST filesystem setup
    #------------------------------------------
    if (! $this -> postImage ($name,undef,undef,$device)) {
        return;
    }
    return $this;
}

#==========================================
# createImageSquashFS
#------------------------------------------
sub createImageSquashFS {
    # ...
    # create squashfs image from source tree
    # ---
    my $this  = shift;
    my $rename= shift;
    my $opts  = shift;
    my $kiwi  = $this->{kiwi};
    my $xml   = $this->{xml};
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ("haveExtend");
    if (! defined $name) {
        return;
    }
    if (defined $rename) {
        $name = $rename;
    }
    #==========================================
    # Create filesystem on extend
    #------------------------------------------
    if (! $this -> setupSquashFS ( $name,undef,$opts )) {
        return;
    }
    #==========================================
    # Create image md5sum
    #------------------------------------------
    if (! $this -> buildMD5Sum ($name)) {
        return;
    }
    #==========================================
    # Compress image using gzip
    #------------------------------------------
    my $compressed = $xml -> getImageType() -> getCompressed();
    if (($compressed) && ($compressed eq 'true')) {
        if (! $this -> compressImage ($name,'squashfs')) {
            return;
        }
    }
    #==========================================
    # Create image boot configuration
    #------------------------------------------
    if (! defined $rename) {
        if (! $this -> writeImageConfig ($name)) {
            return;
        }
    }
    return $this;
}

#==========================================
# createImageCPIO
#------------------------------------------
sub createImageCPIO {
    # ...
    # create cpio archive from the image source tree
    # The kernel will use this archive and mount it as
    # cpio archive
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $imageTree = $this->{imageTree};
    my $zipper    = $this->{gdata}->{IrdZipperCommand};
    my $suf       = $this->{gdata}->{IrdZipperSuffix};
    my $compress  = 1;
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    my $name = $this -> preImage ("haveExtend","quiet");
    if (! defined $name) {
        return;
    }
    #==========================================
    # PRE Create filesystem on extend
    #------------------------------------------
    $kiwi -> info ("Creating cpio archive...");
    my $pwd  = KIWIQX::qxx ("pwd"); chomp $pwd;
    my @cpio = ("--create", "--format=newc", "--quiet");
    my $dest = $this->{imageDest}."/".$name.".".$suf;
    my $dspl = $this->{imageDest}."/".$name.".splash.".$suf;
    my $data;
    if (! $compress) {
        $dest = $this->{imageDest}."/".$name;
    }
    if ($dest !~ /^\//) {
        $dest = $pwd."/".$dest;
    }
    if ($dspl !~ /^\//) {
        $dspl = $pwd."/".$dspl;
    }
    if (-e $dspl) {
        KIWIQX::qxx ("rm -f $dspl 2>&1");
    }
    if ($compress) {
        $data = KIWIQX::qxx (
            "cd $imageTree && find . | cpio @cpio | $zipper -f > $dest"
        );
    } else {
        $data = KIWIQX::qxx ("rm -f $dest && rm -f $dest.gz");
        $data = KIWIQX::qxx (
            "cd $imageTree && find . | cpio @cpio > $dest"
        );
    }
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create cpio archive");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    $kiwi -> done();
    #==========================================
    # PRE filesystem setup
    #------------------------------------------
    if ($compress) {
        $name = $name.".".$suf;
    }
    if (! $this -> buildMD5Sum ($name)) {
        return;
    }
    return $this;
}

#==========================================
# createImageBootImage
#------------------------------------------
sub createImageBootImage {
    my $this       = shift;
    my $text       = shift;
    my $boot       = shift;
    my $sxml       = shift;
    my $idest      = shift;
    my $checkBase  = shift;
    my $kiwi       = $this->{kiwi};
    #==========================================
    # Prepare/Create boot image
    #------------------------------------------
    $kiwi -> info ("--> Creating $text boot image: $boot...\n");
    #==========================================
    # Create tmp dir for boot image creation
    #------------------------------------------
    my $tmpdir = KIWIQX::qxx ("mktemp -q -d $idest/boot-$text.XXXXXX");
    my $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
        $kiwi -> failed ();
        return;
    }
    chomp $tmpdir;
    push @{$this->{tmpdirs}},$tmpdir;
    #==========================================
    # Prepare boot image...
    #------------------------------------------
    my $rootTarget = "$tmpdir/kiwi-".$text."boot-$$";
    my $kic = KIWIImageCreator -> new ($this->{cmdL});
    if ((! $kic) || (! $kic -> prepareBootImage (
        $sxml,$rootTarget,$this->{imageTree}))
    ) {
        undef $kic;
        if (! -d $checkBase) {
            KIWIQX::qxx ("rm -rf $tmpdir");
        }
        return;
    }
    #==========================================
    # Create boot image...
    #------------------------------------------
    if ((! $kic) || (! $kic -> createBootImage (
        $sxml,$rootTarget,$this->{imageDest}))
    ) {
        undef $kic;
        if (! -d $checkBase) {
            KIWIQX::qxx ("rm -rf $tmpdir");
        }
        return;
    }
    #==========================================
    # Clean up tmp directory
    #------------------------------------------
    KIWIQX::qxx ("rm -rf $tmpdir");
    #==========================================
    # Return boot image name
    #------------------------------------------
    return $kic -> getBootImageName();
}

#==========================================
# createImageRootAndBoot
#------------------------------------------
sub createImageRootAndBoot {
    # ...
    # Create root filesystem image if required according to
    # the selected image type and also create the boot image
    # including kernel and initrd. This function is required
    # to create the preconditions for virtual disk images
    # ---
    #==========================================
    # Create root image
    #------------------------------------------
    my $this       = shift;
    my $para       = shift;
    my $text       = shift;
    my $kiwi       = $this->{kiwi};
    my $xml        = $this->{xml};
    my $cmdL       = $this->{cmdL};
    my $idest      = $cmdL->getImageIntermediateTargetDir();
    my $xmltype    = $xml -> getImageType();
    my $imageTree  = $this->{imageTree};
    my $baseSystem = $this->{baseSystem};
    my $treeAccess = 1;
    my $type;
    my $boot;
    my %result;
    my $ok;
    if ($para =~ /(.*):(.*)/) {
        $type = $1;
        $boot = $2;
    }
    if ((! defined $type) || (! defined $boot)) {
        $kiwi -> error  ("Invalid $text type specified: $para");
        $kiwi -> failed ();
        return;
    }
    my $rootTarget = $cmdL->getRootTargetDir();
    if (! $rootTarget) {
        $rootTarget = $cmdL->getConfigDir();
    }
    my $checkBase = $rootTarget."/".$baseSystem;
    #==========================================
    # Check for direct tree access
    #------------------------------------------
    if ($text eq 'PXE') {
        $treeAccess = 0;
    }
    #==========================================
    # Walk through the types
    #------------------------------------------
    SWITCH: for ($type) {
        /^ext2/       && do {
            if (! $treeAccess) {
                $ok = $this -> createImageEXT2 ();
            } else {
                $ok = $this -> setupLogicalExtend();
                $result{imageTree} = $imageTree;
            }
            last SWITCH;
        };
        /^ext3/       && do {
            if (! $treeAccess) {
                $ok = $this -> createImageEXT3 ();
            } else {
                $ok = $this -> setupLogicalExtend();
                $result{imageTree} = $imageTree;
            }
            last SWITCH;
        };
        /^ext4/       && do {
            if (! $treeAccess) {
                $ok = $this -> createImageEXT4 ();
            } else {
                $ok = $this -> setupLogicalExtend();
                $result{imageTree} = $imageTree;
            }
            last SWITCH;
        };
        /^reiserfs/   && do {
            if (! $treeAccess) {
                $ok = $this -> createImageReiserFS ();
            } else {
                $ok = $this -> setupLogicalExtend();
                $result{imageTree} = $imageTree;
            }
            last SWITCH;
        };
        /^squashfs/   && do {
            $ok = $this -> createImageSquashFS ();
            last SWITCH;
        };
        /^clicfs/     && do {
            $ok = $this -> createImageClicFS ();
            last SWITCH;
        };
        /^overlayfs/  && do {
            $ok = $this -> createImageSquashFS ();
            last SWITCH;
        };
        /^btrfs/      && do {
            if (! $treeAccess) {
                $ok = $this -> createImageBTRFS ();
            } else {
                $ok = $this -> setupLogicalExtend();
                $result{imageTree} = $imageTree;
            }
            last SWITCH;
        };
        /^xfs/        && do {
            if (! $treeAccess) {
                $ok = $this -> createImageXFS ();
            } else {
                $ok = $this -> setupLogicalExtend();
                $result{imageTree} = $imageTree;
            }
            last SWITCH;
        };
        /^zfs/        && do {
            if (! $treeAccess) {
                $ok = $this -> createImageZFS ();
            } else {
                $ok = $this -> setupLogicalExtend();
                $result{imageTree} = $imageTree;
            }
            last SWITCH;
        };
        $kiwi -> error  ("Unsupported $text type: $type");
        $kiwi -> failed ();
        return;
    };
    if (! $ok) {
        return;
    }
    #==========================================
    # Prepare/Create boot image
    #------------------------------------------
    my $bname = $this -> createImageBootImage (
        $text,$boot,$xml,$idest,$checkBase
    );
    if (! $bname) {
        return;
    }
    #==========================================
    # setup initrd name
    #------------------------------------------
    my $initrd = $idest."/".$bname.".".$this->{gdata}->{IrdZipperSuffix};
    if (! -f $initrd) {
        $initrd = $idest."/".$bname;
    }
    #==========================================
    # Check boot and system image kernel
    #------------------------------------------
    if ($cmdL->getCheckKernel()) {
        if (! $this -> checkKernel ($initrd,$imageTree,$bname)) {
            return;
        }
    }
    #==========================================
    # Include splash screen to initrd
    #------------------------------------------
    my $newinitrd = KIWIGlobals -> instance() -> setupSplash($initrd);
    #==========================================
    # Store meta data for subsequent calls
    #------------------------------------------
    $result{systemImage} = KIWIGlobals -> instance()
        -> generateBuildImageName ($xml);
    $result{bootImage}   = $bname;
    if ($text eq "VMX") {
        $result{format} = $xmltype -> getFormat();
    }
    return \%result;
}

#==========================================
# createImagePXE
#------------------------------------------
sub createImagePXE {
    # ...
    # Create Image usable within a PXE boot environment. The
    # method will create the specified boot image (initrd) and
    # the system image. In order to use this image via PXE the
    # administration needs to provide the images via TFTP
    # ---
    #==========================================
    # Create PXE boot and system image
    #------------------------------------------
    my $this = shift;
    my $para = shift;
    my $name = $this -> createImageRootAndBoot ($para,"PXE");
    if (! defined $name) {
        return;
    }
    return $this;
}

#==========================================
# createImageVMX
#------------------------------------------
sub createImageVMX {
    # ...
    # Create virtual machine disks. By default a raw disk image will
    # be created from which other types are derived via conversion.
    # The output format is specified by the format attribute in the
    # type section. Supported formats are: vmdk qcow raw ovf
    # The process will create the system image and the appropriate vmx
    # boot image plus a .raw and an optional format specific image.
    # ---
    #==========================================
    # Create VMX boot and system image
    #------------------------------------------
    my $this = shift;
    my $para = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $cmdL = $this->{cmdL};
    my $idest= $cmdL->getImageIntermediateTargetDir();
    my $name = $this -> createImageRootAndBoot ($para,"VMX");
    my $vconf= $xml -> getVMachineConfig();
    my $suf  = $this->{gdata}->{IrdZipperSuffix};
    my $xendomain;
    if ($vconf) {
        $xendomain = $vconf -> getDomain();
    }
    if (! defined $name) {
        return;
    }
    if (! $xendomain) {
        $xendomain = "dom0";
    }
    #==========================================
    # Create virtual disk image(s)
    #------------------------------------------
    $cmdL -> setInitrdFile (
        $idest."/".$name->{bootImage}.".splash.".$suf
    );
    if (defined $name->{imageTree}) {
        $cmdL -> setSystemLocation (
            $name->{imageTree}
        );
    } else {
        $cmdL -> setSystemLocation (
            $idest."/".$name->{systemImage}
        );
    }
    my $kic = KIWIImageCreator -> new($cmdL);
    if ((! $kic) || (! $kic->createImageDisk($xml))) {
        undef $kic;
        return;
    }
    #==========================================
    # Create VM format/configuration
    #------------------------------------------
    if ((defined $name->{format}) || ($xendomain eq "domU")) {
        $cmdL -> setSystemLocation (
            $idest."/".$name->{systemImage}.".raw"
        );
        $cmdL -> setImageFormat ($name->{format});
        my $kic = KIWIImageCreator -> new($cmdL);
        if ((! $kic) || (! $kic->createImageFormat($xml))) {
            undef $kic;
            return;
        }
    }
    return $this;
}

#==========================================
# createImageLiveCD
#------------------------------------------
sub createImageLiveCD {
    # ...
    # Create a live filesystem on CD using the isoboot boot image
    # 1) split physical extend into two parts:
    #    part1 -> writable
    #    part2 -> readonly
    # 2) Setup an ext2 based image for the RW part and a squashfs
    #    image if it should be compressed. If no compression is used
    #    all RO data will be directly on CD/DVD as part of the ISO
    #    filesystem
    # 3) Prepare and Create the given iso <$boot> boot image
    # 4) Setup the CD structure and copy all files
    #    including the syslinux isolinux data
    # 5) Create the iso image using isolinux shell script
    # ---
    my $this = shift;
    my $para = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $cmdL = $this->{cmdL};
    my $idest= $cmdL->getImageIntermediateTargetDir();
    my $imageTree = $this->{imageTree};
    my $baseSystem= $this->{baseSystem};
    my $error;
    my $data;
    my $code;
    my $imageTreeReadOnly;
    my $hybrid = 0;
    my $isxen  = 0;
    my $hybridpersistent = 0;
    my $cmdline = "";
    my $rootTarget = $cmdL->getRootTargetDir();
    if (! $rootTarget) {
        $rootTarget = $cmdL->getConfigDir();
    }
    my $checkBase = $rootTarget."/".$baseSystem;

    #==========================================
    # Check Memory Test dependecies
    #------------------------------------------
    my $checkMemtest = 0;
    my $pckgs = $xml -> getPackages();
    push @{$pckgs}, @{$xml -> getBootstrapPackages()};
    for my $pckg (@{$pckgs}) {
        my $pname = $pckg -> getName();
        my $version;
        ($pname, $version) = split(/=/,$pname);
        if ($pname =~ 'memtest86.*'){
            $checkMemtest = 1;
        }
    } 
    
    #==========================================
    # Failsafe boot options
    #------------------------------------------
    my @failsafe = (
        'ide=nodma',
        'apm=off',
        'noresume',
        'edd=off',
        'powersaved=off',
        'nohz=off',
        'highres=off',
        'processsor.max+cstate=1',
        'nomodeset',
        'x11failsafe'
    );
    #==========================================
    # Disable target device support for iso
    #------------------------------------------
    undef $this->{gdata}->{StudioNode};
    #==========================================
    # Store arch name used by iso
    #------------------------------------------
    my $isoarch = KIWIQX::qxx ("uname -m"); chomp $isoarch;
    if ($isoarch =~ /i.86/) {
        $isoarch = "i386";
    }
    #==========================================
    # Get system image name
    #------------------------------------------
    my $systemName = $xml -> getImageName();
    my $systemDisplayName = $xml -> getImageDisplayName();
    #==========================================
    # Get system image type information
    #------------------------------------------
    my $xmltype = $xml -> getImageType();
    #==========================================
    # Get boot image name and compressed flag
    #------------------------------------------
    my @plist = split (/,/,$para);
    my $boot  = $plist[0];
    my $gzip  = $plist[1];
    if (! defined $boot) {
        $kiwi -> failed ();
        $kiwi -> error  ("No boot image name specified");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Check for hybrid ISO
    #------------------------------------------
    my $xmlhybrid = $xmltype -> getHybrid();
    if (($xmlhybrid) && ($xmlhybrid eq 'true')) {
        $hybrid = 1;
    }
    my $xmlhybridpersistent = $xmltype -> getHybridPersistent();
    if (($xmlhybridpersistent) && ($xmlhybridpersistent eq 'true')) {
        $hybridpersistent = 1;
    }
    #==========================================
    # Check for user-specified cmdline options
    #------------------------------------------
    my $xmlcmdline = $xmltype -> getKernelCmdOpts();
    if ($xmlcmdline) {
        $cmdline = " $xmlcmdline";
    }
    #==========================================
    # Get image creation date and name
    #------------------------------------------
    my $namecd = KIWIGlobals
        -> instance()
        -> generateBuildImageName($xml, ';');
    my $namerw = KIWIGlobals
        -> instance()
        -> generateBuildImageName($xml);
    my $namero = KIWIGlobals -> instance() -> generateBuildImageName(
        $xml,'-', '-read-only'
    );
    if (! defined $namerw) {
        return;
    }
    my $isofile = $namerw;
    #==========================================
    # Call images.sh script
    #------------------------------------------
    if (! $this -> setupLogicalExtend ("quiet")) {
        return;
    }
    #==========================================
    # Check for config-cdroot and move it
    #------------------------------------------
    my $cdrootData = "config-cdroot.tgz";
    if (-f $imageTree."/image/".$cdrootData) {
        KIWIQX::qxx ("mv $imageTree/image/$cdrootData $this->{imageDest}");
    }
    #==========================================
    # Check for config-cdroot.sh and move it
    #------------------------------------------
    my $cdrootScript = "config-cdroot.sh";
    if (-x $imageTree."/image/".$cdrootScript) {
        KIWIQX::qxx ("mv $imageTree/image/$cdrootScript $this->{imageDest}");
    }
    #==========================================
    # split physical extend into RW / RO part
    #------------------------------------------
    if (! defined $gzip) {
        $imageTreeReadOnly = $imageTree;
        $imageTreeReadOnly =~ s/\/+$//;
        $imageTreeReadOnly.= "-read-only/";
        $this->{imageTreeReadOnly} = $imageTreeReadOnly;
        if (! -d $imageTreeReadOnly) {
            $kiwi -> info ("Creating read only image part");
            if (! mkdir $imageTreeReadOnly) {
                $error = $!;
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't create ro directory: $error");
                $kiwi -> failed ();
                return;
            }
            push @{$this->{tmpdirs}},$imageTreeReadOnly;
            my @rodirs = qw (bin boot lib lib64 opt sbin usr);
            foreach my $dir (@rodirs) {
                if (! -d "$imageTree/$dir") {
                    next;
                }
                $data = KIWIQX::qxx (
                    "mv $imageTree/$dir $imageTreeReadOnly 2>&1"
                );
                $code = $? >> 8;
                if ($code != 0) {
                    $kiwi -> failed ();
                    $kiwi -> error  ("Couldn't setup ro directory: $data");
                    $kiwi -> failed ();
                    return;
                }
            }
            $kiwi -> done();
        }
        #==========================================
        # Count disk space for RW extend
        #------------------------------------------
        $kiwi -> info ("Computing disk space...");
        my ($mbytesrw,$xmlsize) = $this -> getSize ($imageTree);
        $kiwi -> done ();

        #==========================================
        # Create RW logical extend
        #------------------------------------------
        $kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
        if (! $this -> buildLogicalExtend ($namerw,$mbytesrw."M")) {
            $this -> restoreSplitExtend ();
            $this -> cleanLuks();
            return;
        }
        $kiwi -> done ();
        #==========================================
        # Create EXT2 filesystem on RW extend
        #------------------------------------------
        my $setBlockSize = 0;
        my $fsopts       = $cmdL -> getFilesystemOptions();
        my $blocksize    = $fsopts -> getFSBlockSize();
        if (! defined $blocksize) {
            $fsopts -> setFSBlockSize(4096);
            $setBlockSize = 1;
        }
        if (! $this -> setupEXT2 ( $namerw )) {
            $this -> restoreSplitExtend ();
            $this -> cleanLuks();
            return;
        }
        if ($setBlockSize) {
            # /.../
            # reset blocksize to default value if previosly
            # set to the default RW blocksize of 4k
            # ----
            $fsopts -> setFSBlockSize();
        }
        #==========================================
        # mount logical extend for data transfer
        #------------------------------------------
        my $extend = $this -> mountLogicalExtend ($namerw);
        if (! defined $extend) {
            $this -> restoreSplitExtend ();
            $this -> cleanLuks();
            return;
        }
        #==========================================
        # copy physical to logical
        #------------------------------------------
        if (! $this -> installLogicalExtend ($extend,$imageTree)) {
            $this -> restoreSplitExtend ();
            $this -> cleanLuks();
            return;
        }
        $this -> cleanMount();
        $this -> restoreImageDest();
        $this -> cleanLuks();
    }
    #==========================================
    # Create compressed filesystem on RO extend
    #------------------------------------------
    if (defined $gzip) {
        SWITCH: for ($gzip) {
            /^compressed$/ && do {
                $kiwi -> info ("Creating split ext3 + squashfs...\n");
                if (! $this -> createImageSplit ("ext3,squashfs")) {
                    return;
                }
                $namero = $namerw;
                $namerw = KIWIGlobals -> instance() -> generateBuildImageName(
                    $xml,'-', '-read-write'
                );
                last SWITCH;
            };
            /^(clic|clic_udf)$/ && do {
                $kiwi -> info ("Creating clicfs read only filesystem...\n");
                if (! $this -> createImageClicFS ( $namero )) {
                    $this -> restoreSplitExtend ();
                    return;
                }
                last SWITCH;
            };
            /^seed$/ && do {
                $kiwi -> info ("Creating btrfs read only filesystem...\n");
                if (! $this -> createImageBTRFS ( undef,$namero )) {
                    $this -> restoreSplitExtend ();
                    return;
                }
                $data = KIWIQX::qxx (
                    "btrfstune -S 1 $this->{imageDest}/$namero 2>&1"
                );
                $code = $? >> 8;
                if ($code != 0) {
                    $kiwi -> failed ();
                    $kiwi -> error ("Write protection failed: $data");
                    $kiwi -> failed ();
                    $this -> restoreSplitExtend ();
                    return;
                }
                last SWITCH;
            };
            /^overlay$/ && do {
                $kiwi -> info ("Creating overlayfs read only filesystem...\n");
                my $options = "-comp xz -b 1M";
                if (($isoarch eq 'i386') || ($isoarch eq 'x86_64')) {
                    $options .= ' -Xbcj x86';
                } elsif ($isoarch =~ /arm/) {
                    $options .= ' -Xbcj arm';
                } elsif ($isoarch =~ /ppc/) {
                    $options .= ' -Xbcj powerpc';
                }
                if (! $this -> createImageSquashFS ($namero,$options)) {
                    $this -> restoreSplitExtend ();
                    return;
                }
                last SWITCH;
            };
            # invalid flag setup...
            $kiwi -> error  ("Invalid iso flags: $gzip");
            $kiwi -> failed ();
            return;
        }
    }
    #==========================================
    # Check / build md5 sum of RW extend
    #------------------------------------------
    if (! defined $gzip) {
        #==========================================
        # Checking RW file system
        #------------------------------------------
        KIWIQX::qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$namerw 2>&1");

        #==========================================
        # Create image md5sum
        #------------------------------------------
        if (! $this -> buildMD5Sum ($namerw)) {
            $this -> restoreSplitExtend ();
            return;
        }
        #==========================================
        # Restoring physical extend
        #------------------------------------------
        if (! $this -> restoreSplitExtend ()) {
            return;
        }
        #==========================================
        # compress RW extend
        #------------------------------------------
        if (! $this -> compressImage ($namerw,'ext2')) {
            return;
        }
    }
    #==========================================
    # recreate a copy of the read-only data
    #------------------------------------------ 
    if ((defined $imageTreeReadOnly) && (! -d $imageTreeReadOnly) &&
        (! defined $gzip)
    ) {
        $kiwi -> info ("Creating read only reference...");
        if (! mkdir $imageTreeReadOnly) {
            $error = $!;
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create ro directory: $error");
            $kiwi -> failed ();
            return;
        }
        my @rodirs = qw (bin boot lib lib64 opt sbin usr);
        foreach my $dir (@rodirs) {
            if (! -d "$imageTree/$dir") {
                next;
            }
            $data = KIWIQX::qxx (
                "cp -a $imageTree/$dir $imageTreeReadOnly 2>&1"
            );
            $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't setup ro directory: $data");
                $kiwi -> failed ();
                return;
            }
        }
        $kiwi -> done();
    }
    #==========================================
    # Prepare and Create ISO boot image
    #------------------------------------------
    my $bname = $this -> createImageBootImage (
        'iso',$boot,$xml,$idest,$checkBase
    );
    if (! $bname) {
        return;
    }
    #==========================================
    # setup initrd/kernel names
    #------------------------------------------
    my $suf = $this->{gdata}->{IrdZipperSuffix};
    my $pinitrd = $idest."/".$bname.".".$suf;
    my $plinux  = $idest."/".$bname.".kernel";
    my $pxboot  = glob ($idest."/".$bname."*xen.gz");
    if (($pxboot) && (-f $pxboot)) {
        $isxen = 1;
    }
    #==========================================
    # Check boot and system image kernel
    #------------------------------------------
    if ($cmdL->getCheckKernel()) {
        if (! $this -> checkKernel ($pinitrd,$imageTree,$bname)) {
            return;
        }
    }
    #==========================================
    # Include splash screen to initrd
    #------------------------------------------
    $pinitrd = KIWIGlobals -> instance() -> setupSplash($pinitrd);
    #==========================================
    # Prepare for CD ISO image
    #------------------------------------------
    my $CD = $idest."/CD";
    $kiwi -> info ("Creating CD filesystem structure");
    KIWIQX::qxx ("mkdir -p $CD/boot");
    push @{$this->{tmpdirs}},$CD;
    $kiwi -> done ();
    #==========================================
    # Check for optional config-cdroot archive
    #------------------------------------------
    if (-f $this->{imageDest}."/".$cdrootData) {
        $kiwi -> info ("Integrating CD root information...");
        my $data= KIWIQX::qxx (
            "tar -C $CD -xvf $this->{imageDest}/$cdrootData"
        );
        my $code= $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to integrate CD root data: $data");
            $kiwi -> failed ();
            $this -> restoreCDRootData();
            return;
        }
        $kiwi -> done();
    }
    #==========================================
    # Check for optional config-cdroot.sh
    #------------------------------------------
    if (-x $this->{imageDest}."/".$cdrootScript) {
        $kiwi -> info ("Calling CD root setup script...");
        my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
        my $cdrootEnv = $imageTree."/.profile";
        if ($cdrootEnv !~ /^\//) {
            $cdrootEnv = $pwd."/".$cdrootEnv;
        }
        my $script = $this->{imageDest}."/".$cdrootScript;
        if ($script !~ /^\//) {
            $script = $pwd."/".$script;
        }
        my $data = KIWIQX::qxx (
            "cd $CD && bash -c '. $cdrootEnv && . $script' 2>&1"
        );
        my $code = $? >> 8;
        if ($code != 0) {
            chomp $data;
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to call CD root script: $data");
            $kiwi -> failed ();
            $this -> restoreCDRootData();
            return;
        } else {
            $kiwi -> loginfo ("config-cdroot.sh: $data");
        }
        $kiwi -> done();
    }
    #==========================================
    # Restore CD root data and script
    #------------------------------------------
    $this -> restoreCDRootData();
    #==========================================
    # Installing system image file(s)
    #------------------------------------------
    $kiwi -> info ("Moving CD image data into boot structure");
    if (! defined $gzip) {
        # /.../
        # don't symlink these file because in this old live iso
        # mode we don't allow mkisofs to follow symlinks
        # ----
        KIWIQX::qxx ("mv $this->{imageDest}/$namerw.md5 $CD");
        KIWIQX::qxx ("mv $this->{imageDest}/$namerw.gz  $CD");
        KIWIQX::qxx ("rm $this->{imageDest}/$namerw.*");
    }
    if (defined $gzip) {
        KIWIQX::qxx ("ln -s $this->{imageDest}/$namero $CD/$namero");
        if (-e "$this->{imageDest}/$namerw") {
            KIWIQX::qxx (
                "ln -s $this->{imageDest}/$namerw $CD/$namero-read-write"
            );
        }
    } else {
        KIWIQX::qxx ("mkdir -p $CD/read-only-system");
        KIWIQX::qxx ("mv $imageTreeReadOnly/* $CD/read-only-system");
        rmdir $imageTreeReadOnly;
    }
    $kiwi -> done ();
    #==========================================
    # copy boot kernel and initrd
    #------------------------------------------
    $kiwi -> info ("Copying boot image and kernel [$isoarch]");
    my $destination = "$CD/boot/$isoarch/loader";
    KIWIQX::qxx ("mkdir -p $destination");
    $data = KIWIQX::qxx ("cp $pinitrd $destination/initrd 2>&1");
    $code = $? >> 8;
    if ($code == 0) {
        $data = KIWIQX::qxx ("cp $plinux $destination/linux 2>&1");
        $code = $? >> 8;
    }
    if (($code == 0) && ($isxen)) {
        $data = KIWIQX::qxx ("cp $pxboot $destination/xen.gz 2>&1");
        $code = $? >> 8;
    }
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Copy of isolinux boot files failed: $data");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> done ();
    #==========================================
    # check for graphics boot files
    #------------------------------------------
    $kiwi -> info ("Extracting initrd for boot graphics data lookup");
    my $tmpdir = KIWIQX::qxx ("mktemp -q -d $idest/boot-iso.XXXXXX");
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed();
        $kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
        $kiwi -> failed ();
        return;
    }
    chomp $tmpdir;
    push @{$this->{tmpdirs}},$tmpdir;
    my $zipper = $this->{gdata}->{IrdZipperCommand};
    $data = KIWIQX::qxx (
        "$zipper -cd $pinitrd | (cd $tmpdir && cpio -di 2>&1)"
    );
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed();
        $kiwi -> error ("Failed to extract initrd: $data");
        $kiwi -> failed();
        return;
    }
    $kiwi -> done();
    #==========================================
    # Include MBR ID to initrd
    #------------------------------------------
    $kiwi -> info ("Saving hybrid disk label in initrd: $this->{mbrid}...");
    KIWIQX::qxx ("mkdir -p $tmpdir/boot/grub");
    my $MBRFD = FileHandle -> new();
    if (! $MBRFD -> open (">$tmpdir/boot/mbrid")) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create mbrid file: $!");
        $kiwi -> failed ();
        return;
    }
    print $MBRFD "$this->{mbrid}";
    $MBRFD -> close();
    #==========================================
    # Store mbrid flag file on CD
    #------------------------------------------
    KIWIQX::qxx ("touch $CD/boot/$this->{mbrid}");
    #==========================================
    # Repackage initrd
    #------------------------------------------
    my @cpio = ("--create", "--format=newc", "--quiet");
    $data = KIWIQX::qxx (
        "cd $tmpdir && find . | cpio @cpio | $zipper -f > $destination/initrd"
    );
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed();
        $kiwi -> error ("Failed to repackage initrd: $data");
        $kiwi -> failed();
        return;
    }
    $kiwi -> done();
    #==========================================
    # recreate splash data to initrd
    #------------------------------------------
    my $splash = $pinitrd;
    if (! ($splash =~ s/splash\.(g|x)z/spl/)) {
        $splash =~ s/(g|x)z/spl/;
    }
    if (-f $splash) {
        KIWIQX::qxx ("cat $splash >> $destination/initrd");
    }
    #==========================================
    # check for boot firmware
    #------------------------------------------
    my $firmware = 'efi';
    my $xmlfirmware = $xmltype -> getFirmwareType();
    if ($xmlfirmware) {
        $firmware = $xmlfirmware;
    }
    if (($firmware eq 'uefi') && ($isoarch ne 'x86_64')) {
        $kiwi -> warning (
            "UEFI Secure boot is only supported on x86_64"
        );
        $kiwi -> skipped();
        $kiwi -> warning (
            "--> switching to non secure EFI boot\n"
        );
        $firmware = 'efi';
    }
    #==========================================
    # Create bootloader configuration
    #------------------------------------------
    if (($firmware eq "efi") || ($firmware eq "uefi")) {
        #==========================================
        # Setup grub2 if efi live iso is requested
        #------------------------------------------
        my $grub_efi   = 'grub2';
        my $grub_share = 'grub2';
        my $efi_fo     = 'x86_64-efi';
        my $efi_bin    = 'bootx64.efi';
        if ($isoarch ne 'x86_64') {
            $efi_fo = 'i386-efi';
            $efi_bin= 'bootx32.efi';
        }
        if (-d "$tmpdir/usr/lib/grub2") {
            $grub_efi = 'grub2';
        } elsif (-d "$tmpdir/usr/lib/grub") {
            $grub_efi = 'grub';
        }
        if (-d "$tmpdir/usr/share/grub") {
            $grub_share = 'grub';
        }
        my @theme      = ();
        my $pref       = $xml -> getPreferences();
        push @theme, $pref -> getBootSplashTheme();
        push @theme, $pref -> getBootLoaderTheme();
        my $ir_modules = "$tmpdir/usr/lib/$grub_efi/$efi_fo";
        my $ir_themes  = "$tmpdir/usr/share/$grub_share/themes";
        my $ir_font    = "$tmpdir/usr/share/$grub_share/unicode.pf2";
        my $efi_modules= "$CD/EFI/BOOT";
        my $cd_modules = "$CD/boot/grub2/$efi_fo";
        my $cd_loader  = "$CD/boot/grub2";
        my $theme      = $theme[1];
        my $ir_bg      = "$ir_themes/$theme/background.png";
        my $cd_bg      = "$cd_loader/themes/$theme/background.png";
        my $fodir      = '/boot/grub2/themes/';
        my $ascii      = 'ascii.pf2';
        my @fonts = (
            "DejaVuSans-Bold14.pf2",
            "DejaVuSans10.pf2",
            "DejaVuSans12.pf2",
            "ascii.pf2"
        );
        my @efimods = (
            'fat','ext2','part_gpt','efi_gop','iso9660','chain',
            'linux','echo','configfile','boot','search_label',
            'search_fs_file','search','search_fs_uuid','ls',
            'video','video_fb','normal','test','sleep','png',
            'gettext','gzio','efi_uga'
        );
        my $status;
        my $result;
        #==========================================
        # Check for grub2 efi modules in initrd
        #------------------------------------------
        if (! -d $ir_modules) {
            $kiwi -> error ("Couldn't find EFI grub2 data in: $ir_modules");
            $kiwi -> failed ();
            return;
        }
        #==========================================
        # Create directory structure
        #------------------------------------------
        KIWIQX::qxx ("mkdir -p $cd_modules");
        KIWIQX::qxx ("mkdir -p $efi_modules");
        #==========================================
        # Copy modules/fonts/themes on CD
        #------------------------------------------
        KIWIQX::qxx ("cp $ir_modules/* $cd_modules 2>&1");
        if (-d $ir_themes) {
            KIWIQX::qxx ("mv $ir_themes $cd_loader 2>&1");
        }
        if (-f $ir_bg) {
            KIWIQX::qxx ("cp $ir_bg $cd_bg 2>&1");
        }
        if (-e $ir_font) {
            KIWIQX::qxx ("mv $ir_font $CD/boot");
        } else {
            $kiwi -> warning ("Can't find unicode font for grub2");
            $kiwi -> skipped ();
        }
        #==========================================
        # Create boot partition file
        #------------------------------------------
        my $bootefi = "$CD/boot/bootpart.cfg";
        my $bpfd = FileHandle -> new();
        if (! $bpfd -> open(">$bootefi")) {
            $kiwi -> error ("Couldn't create grub2 EFI bootpart map: $!");
            $kiwi -> failed ();
            return;
        }
        print $bpfd "search --file /boot/$this->{mbrid} --set"."\n";
        print $bpfd 'set prefix=($root)/boot/grub2'."\n";
        $bpfd -> close();
        #==========================================
        # create / use efi boot image
        #------------------------------------------
        if ($firmware eq "efi") {
            $kiwi -> info ("Creating grub2 efi boot image");
            my $locator = KIWILocator -> instance();
            my $grub2_mkimage = $locator -> getExecPath ("grub2-mkimage");
            if (! $grub2_mkimage) {
                $kiwi -> failed ();
                $kiwi -> error  ("Can't find grub2 mkimage tool");
                $kiwi -> failed ();
                return;
            }
            my $core    = "$CD/EFI/BOOT/$efi_bin";
            my @modules = @efimods;
            my $core_opts = "-O $efi_fo -o $core -c $bootefi -d $ir_modules";
            $status = KIWIQX::qxx (
                "$grub2_mkimage $core_opts @modules 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't create efi boot image: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
        } else {
            $kiwi -> info ("Importing grub2 shim/signed efi modules");
            my $lib = 'lib';
            if ( -d "$tmpdir/usr/lib64" ) {
                $lib = 'lib64';
            }
            my $s_shim_ms   = "$tmpdir/usr/$lib/efi/shim.efi";
            my $s_shim_suse = "$tmpdir/usr/$lib/efi/shim-opensuse.efi";
            my $s_signed    = "$tmpdir/usr/$lib/efi/grub.efi";
            if ((! -e $s_shim_ms) && (! -e $s_shim_suse)) {
                my $s_shim = $s_shim_ms;
                if (-e $s_shim) {
                    $s_shim = $s_shim_suse;
                }
                $kiwi -> failed ();
                $kiwi -> error  ("Can't find $s_shim in initrd");
                $kiwi -> failed ();
                return;
            }
            if (! -e $s_signed) {
                $kiwi -> failed ();
                $kiwi -> error  ("Can't find grub2 $s_signed in initrd");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx (
                "cp $s_shim_ms $CD/EFI/BOOT/$efi_bin 2>&1"
            );
            $result = $? >> 8;
            if ($result != 0) {
                $status = KIWIQX::qxx (
                    "cp $s_shim_suse $CD/EFI/BOOT/$efi_bin 2>&1"
                );
                $result = $? >> 8;
            }
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error ("Failed to copy shim module: $status");
                $kiwi -> failed ();
                return;
            }
            $status = KIWIQX::qxx ("cp $s_signed $CD/EFI/BOOT/grub.efi 2>&1");
            $result = $? >> 8;
            if ($result != 0) {
                $kiwi -> failed ();
                $kiwi -> error ("Failed to copy signed module: $status");
                $kiwi -> failed ();
                return;
            }
            $kiwi -> done();
        }
        #==========================================
        # create grub configuration
        #------------------------------------------
        $kiwi -> info ("Creating grub2 configuration file...");
        my $FD = FileHandle -> new();
        if (! $FD -> open(">$CD/boot/grub2/grub.cfg")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create grub.cfg: $!");
            $kiwi -> failed ();
            return;
        }
        foreach my $module (@efimods) {
            print $FD "insmod $module"."\n";
        }
        print $FD "search --file /boot/$this->{mbrid} --set"."\n";
        # print $FD "set debug=all\n";
        print $FD 'if [ $grub_platform = "efi" ]; then'."\n";
        print $FD '    set linux=linuxefi'."\n";
        print $FD '    set initrd=initrdefi'."\n";
        print $FD 'else'."\n";
        print $FD '    set linux=linux'."\n";
        print $FD '    set initrd=initrd'."\n";
        print $FD 'fi'."\n";
        print $FD "set default=0\n";
        print $FD "set font=/boot/unicode.pf2"."\n";
        print $FD 'if loadfont $font ;then'."\n";
        print $FD "\t"."set gfxmode=auto"."\n";
        print $FD "\t".'insmod gfxterm'."\n";
        print $FD "\t".'insmod gfxmenu'."\n";
        print $FD "\t".'terminal_input gfxterm'."\n";
        print $FD "\t".'if terminal_output gfxterm; then true; else'."\n";
        print $FD "\t\t".'terminal gfxterm'."\n";
        print $FD "\t".'fi'."\n";
        print $FD 'fi'."\n";
        print $FD 'if loadfont '.$fodir.$theme.'/'.$ascii.';then'."\n";
        foreach my $font (@fonts) {
            print $FD "\t".'loadfont '.$fodir.$theme.'/'.$font."\n";
        }
        print $FD "\t".'set theme='.$fodir.$theme.'/theme.txt'."\n";
        print $FD "\t".'background_image -m stretch ';
        print $FD $fodir.$theme.'/background.png'."\n";
        print $FD 'fi'."\n";
        my $bootTimeout = 10;
        my $xmlboottimeout = $xmltype -> getBootTimeout();
        if (defined $xmlboottimeout) {
            $bootTimeout = $xmlboottimeout;
        }
        print $FD "set timeout=$bootTimeout\n";
        my $title = $systemDisplayName;
        my $lsafe = "Failsafe -- ".$title;
        print $FD 'menuentry "'.$title.'"';
        print $FD ' --class opensuse --class os {'."\n";
        #==========================================
        # Standard boot
        #------------------------------------------
        if (! $isxen) {
            print $FD "\t"."echo Loading linux...\n";
            print $FD "\t"."set gfxpayload=keep"."\n";
            print $FD "\t"."\$linux /boot/$isoarch/loader/linux";
            print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
            print $FD " ${cmdline}\n";
            print $FD "\t"."echo Loading initrd...\n";
            print $FD "\t"."\$initrd /boot/$isoarch/loader/initrd\n";
            print $FD "}\n";
        } else {
            print $FD "\t"."echo Loading Xen\n";
            print $FD "\t"."multiboot /boot/$isoarch/loader/xen.gz dummy\n";
            print $FD "\t"."echo Loading linux...\n";
            print $FD "\t"."set gfxpayload=keep"."\n";
            print $FD "\t"."module /boot/$isoarch/loader/linux dummy";
            print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
            print $FD " ${cmdline}\n";
            print $FD "\t"."echo Loading initrd...\n";
            print $FD "\t"."module /boot/$isoarch/loader/initrd dummy\n";
            print $FD "}\n";
        }
        #==========================================
        # Failsafe boot
        #------------------------------------------
        print $FD 'menuentry "'.$lsafe.'"';
        print $FD ' --class opensuse --class os {'."\n";
        if (! $isxen) {
            print $FD "\t"."echo Loading linux...\n";
            print $FD "\t"."set gfxpayload=keep"."\n";
            print $FD "\t"."\$linux /boot/$isoarch/loader/linux";
            print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
            print $FD " @failsafe ${cmdline}"."\n";
            print $FD "\t"."echo Loading initrd...\n";
            print $FD "\t"."\$initrd /boot/$isoarch/loader/initrd\n";
            print $FD "}\n";
        } else {
            print $FD "\t"."echo Loading Xen\n";
            print $FD "\t"."multiboot /boot/$isoarch/loader/xen.gz dummy\n";
            print $FD "\t"."echo Loading linux...\n";
            print $FD "\t"."set gfxpayload=keep"."\n";
            print $FD "\t"."module /boot/$isoarch/loader/linux dummy";
            print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
            print $FD " @failsafe ${cmdline}"."\n";
            print $FD "\t"."echo Loading initrd...\n";
            print $FD "\t"."module /boot/$isoarch/loader/initrd dummy\n";
            print $FD "}\n";
        }
        #==========================================
        # setup isolinux checkmedia boot entry
        #------------------------------------------
        if ($cmdL->getISOCheck()) {
            print $FD 'menuentry mediacheck';
            print $FD ' --class opensuse --class os {'."\n";
            if (! $isxen) {
                print $FD "\t"."echo Loading linux...\n";
                print $FD "\t"."set gfxpayload=keep"."\n";
                print $FD "\t"."\$linux /boot/$isoarch/loader/linux";
                print $FD " mediacheck=1";
                print $FD "\t"."echo Loading initrd...\n";
                print $FD "\t"."\$initrd /boot/$isoarch/loader/initrd";
                print $FD "\n}\n";
            } else {
                print $FD "\t"."echo Loading Xen\n";
                print $FD "\t"."multiboot /boot/$isoarch/loader/xen.gz dummy\n";
                print $FD "\t"."echo Loading linux...\n";
                print $FD "\t"."set gfxpayload=keep"."\n";
                print $FD "\t"."module /boot/$isoarch/loader/linux dummy";
                print $FD " mediacheck=1";
                print $FD "\t"."echo Loading initrd...\n";
                print $FD "\t"."module /boot/$isoarch/loader/initrd dummy";
                print $FD "\n}\n";
            }
        }
        #==========================================
        # setup harddisk entry
        #------------------------------------------
        # try to chainload another linux efi module from
        # the fixed hd0,1 partition. It's not certain that
        # this preconditions are true in any case
        # ----
        print $FD 'menuentry "Boot from Hard Disk"';
        print $FD ' --class opensuse --class os {'."\n";
        print $FD "\t"."set root='hd0,1'"."\n";
        if ($isoarch eq 'x86_64') {
            print $FD "\t".'chainloader /EFI/BOOT/bootx64.efi'."\n";
        } else {
            print $FD "\t".'chainloader /EFI/BOOT/bootx32.efi'."\n";
        }
        print $FD '}'."\n";
        #==========================================
        # setup memtest entry
        #------------------------------------------
        # memtest will not work in grub2 efi. This is because efi
        # does not support launching 16-bit binaries and memtest is
        # a 16-bit binary. Thats also the reason why there is no
        # linux16 command/module in grub2 efi
        # ----
        $FD -> close();
        #==========================================
        # copy grub config to efi directory too
        #------------------------------------------
        KIWIQX::qxx ("cp $CD/boot/grub2/grub.cfg $CD/EFI/BOOT");
        $kiwi -> done();
    }
    #==========================================
    # copy base graphics boot CD files
    #------------------------------------------
    $kiwi -> info ("Setting up isolinux boot CD [$isoarch]");
    my $gfx = $tmpdir."/image/loader";
    $data = KIWIQX::qxx ("cp -a $gfx/* $destination 2>&1");
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Copy failed: $data");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> done ();
    #==========================================
    # setup isolinux boot label name
    #------------------------------------------
    my $label = $this->makeLabel ($systemDisplayName);
    my $lsafe = $this->makeLabel ("Failsafe -- ".$label);
    #==========================================
    # setup isolinux.cfg file
    #------------------------------------------
    $kiwi -> info ("Creating isolinux configuration...");
    my $vga = $xmltype -> getVGA();
    my $syslinux_new_format = 0;
    my $bootTimeout = 200;
    my $xmlboottimeout = $xmltype -> getBootTimeout();
    if (defined $xmlboottimeout) {
        $bootTimeout = $xmlboottimeout;
    }
    if (-f "$gfx/gfxboot.com" || -f "$gfx/gfxboot.c32") {
        $syslinux_new_format = 1;
    }
    my $IFD = FileHandle -> new();
    if (! $IFD -> open (">$destination/isolinux.cfg")) {
        $kiwi -> failed();
        $kiwi -> error  ("Failed to create $destination/isolinux.cfg: $!");
        $kiwi -> failed ();
        if (! -d $checkBase) {
            KIWIQX::qxx ("rm -rf $cmdL->getRootTargetDir()");
            KIWIQX::qxx ("rm -rf $tmpdir");
        }
        return;
    }
    binmode($IFD, ":encoding(UTF-8)");
    print $IFD "default $label"."\n";
    print $IFD "implicit 1"."\n";
    print $IFD "display isolinux.msg"."\n";
    if (-f "$gfx/bootlogo" ) {
        if ($syslinux_new_format) {
            print $IFD "ui gfxboot bootlogo isolinux.msg"."\n";
        } else {
            print $IFD "gfxboot bootlogo"."\n";
        }
    } else {
        print $IFD "ui menu.c32"."\n";
    }
    print $IFD "prompt   1"."\n";
    print $IFD "timeout  $bootTimeout"."\n";
    if (! $isxen) {
        print $IFD "label $label"."\n";
        print $IFD "  kernel linux"."\n";
        print $IFD "  append initrd=initrd ramdisk_size=512000 ";
        print $IFD "ramdisk_blocksize=4096${cmdline} showopts ";
        #print FD "console=ttyS0,9600n8 console=tty0${cmdline} showopts ";
        if ($vga) {
            print $IFD "vga=$vga ";
        }
        print $IFD "\n";
        print $IFD "label $lsafe"."\n";
        print $IFD "  kernel linux"."\n";
        print $IFD "  append initrd=initrd ramdisk_size=512000 ";
        print $IFD "ramdisk_blocksize=4096${cmdline} showopts ";
        print $IFD "@failsafe"."\n";
    } else {
        print $IFD "label $label"."\n";
        print $IFD "  kernel mboot.c32"."\n";
        print $IFD "  append xen.gz --- linux ramdisk_size=512000 ";
        print $IFD "ramdisk_blocksize=4096${cmdline} ";
        if ($vga) {
            print $IFD "vga=$vga ";
        }
        print $IFD "--- initrd showopts"."\n";
        print $IFD "\n";
        print $IFD "label $lsafe"."\n";
        print $IFD "  kernel mboot.c32"."\n";
        print $IFD "  append xen.gz --- linux ramdisk_size=512000 ";
        print $IFD "ramdisk_blocksize=4096${cmdline} ";
        print $IFD "@failsafe ";
        print $IFD "--- initrd showopts"."\n";
    }
    #==========================================
    # setup isolinux checkmedia boot entry
    #------------------------------------------
    if ($cmdL->getISOCheck()) {
        print $IFD "\n";
        if (! $isxen) {
            print $IFD "label mediacheck"."\n";
            print $IFD "  kernel linux"."\n";
            print $IFD "  append initrd=initrd mediacheck=1";
            print $IFD "$cmdline ";
            print $IFD "showopts"."\n";
        } else {
            print $IFD "label mediacheck"."\n";
            print $IFD "  kernel mboot.c32"."\n";
            print $IFD "  append xen.gz --- linux mediacheck=1";
            print $IFD "$cmdline ";
            print $IFD "--- initrd showopts"."\n";
        }
    }
    #==========================================
    # setup default harddisk/memtest entries
    #------------------------------------------
    print $IFD "\n";
    print $IFD "label harddisk\n";
    print $IFD "  localboot 0x80"."\n";
    print $IFD "\n";
    if ($checkMemtest) {
        print $IFD "label memtest"."\n";
        print $IFD "  kernel memtest"."\n";
        print $IFD "\n";
    }
    $IFD -> close();
    #==========================================
    # setup isolinux.msg file
    #------------------------------------------
    my $MFD = FileHandle -> new();
    if (! $MFD -> open (">$destination/isolinux.msg")) {
        $kiwi -> failed();
        $kiwi -> error  ("Failed to create isolinux.msg: $!");
        $kiwi -> failed ();
        if (! -d $checkBase) {
            KIWIQX::qxx ("rm -rf $cmdL->getRootTargetDir()");
            KIWIQX::qxx ("rm -rf $tmpdir");
        }
        return;
    }
    print $MFD "\n"."Welcome !"."\n\n";
    print $MFD "To start the system enter '".$label."' and press <return>"."\n";
    print $MFD "\n\n";
    print $MFD "Available boot options:\n";
    printf ($MFD "%-20s - %s\n",$label,"Live System");
    printf ($MFD "%-20s - %s\n",$lsafe,"Live System failsafe mode");
    printf ($MFD "%-20s - %s\n","harddisk","Local boot from hard disk");
    printf ($MFD "%-20s - %s\n","mediacheck","Media check");
    if ($checkMemtest) {
        printf ($MFD "%-20s - %s\n","memtest","Memory Test");
    }
    print $MFD "\n";
    print $MFD "Have a lot of fun..."."\n";
    $MFD -> close();
    $kiwi -> done();
    #==========================================
    # Cleanup tmpdir
    #------------------------------------------
    KIWIQX::qxx ("rm -rf $tmpdir");
    #==========================================
    # Allow to identify this as a live iso
    #------------------------------------------
    # make sure to keep the 8.3 notation for iso9660
    my $LFD = FileHandle -> new();
    if (! $LFD -> open (">$CD/liveboot")) {
        $kiwi -> error  ("Couldn't create live CD identification");
        $kiwi -> failed ();
        return;
    }
    my $initrd_base = basename $pinitrd;
    print $LFD $initrd_base."\n";
    $LFD -> close();
    #==========================================
    # Create boot configuration
    #------------------------------------------
    my $CFD = FileHandle -> new();
    if (! $CFD -> open (">$CD/config.isoclient")) {
        $kiwi -> error  ("Couldn't create image boot configuration");
        $kiwi -> failed ();
        return;
    }
    if ((! defined $gzip) || ($gzip =~ /^clic/)) {
        print $CFD "IMAGE='/dev/ram1;$namecd'\n";
    } else {
        print $CFD "IMAGE='loop;$namecd'\n";
    }
    if (defined $gzip) {
        if ($gzip =~ /^clic/) {
            print $CFD "UNIONFS_CONFIG='/dev/ram1,loop,clicfs'\n";
        } elsif ($gzip =~ /^seed/) {
            print $CFD "UNIONFS_CONFIG='/dev/ram1,loop,seed'\n";
        } elsif ($gzip =~ /^overlay/) {
            print $CFD "UNIONFS_CONFIG='tmpfs,loop,overlay'\n";
        } else {
            print $CFD "COMBINED_IMAGE=yes\n";
        }
    }
    $CFD -> close();
    #==========================================
    # Check for edit boot config
    #------------------------------------------
    if ($cmdL) {
        my $editBoot = $cmdL -> getEditBootConfig();
        my $idesc;
        if ((! $editBoot) && ($xml)) {
            $editBoot = $xml -> getImageType() -> getEditBootConfig();
        }
        if ($editBoot) {
            if (($this->{originXMLPath}) && (! -f $editBoot)) {
                $editBoot = $this->{originXMLPath}."/".$editBoot;
            }
            if (-f $editBoot) {
                $kiwi -> info ("Calling pre bootloader install script:\n");
                $kiwi -> info ("--> $editBoot\n");
                my @opts = ();
                my $bootfilesystem = $xmltype -> getBootImageFileSystem();
                if ($bootfilesystem) {
                    push @opts,$bootfilesystem;
                }
                if ($this->{partids}) {
                    push @opts,$this->{partids}{boot};
                }
                system ("cd $CD && chmod u+x $editBoot");
                system ("cd $CD && bash --norc -c \"$editBoot @opts\"");
                my $result = $? >> 8;
                if ($result != 0) {
                    $kiwi -> error ("Call failed, see console log");
                    $kiwi -> failed ();
                    return;
                }
            } else {
                $kiwi -> warning (
                    "Can't find pre bootloader install script: $editBoot..."
                );
                $kiwi -> skipped ();
            }
        }
    }
    #==========================================
    # create ISO image
    #------------------------------------------
    $kiwi -> info ("Creating ISO image...\n");
    my $isoerror = 1;
    my $name = $this->{imageDest}."/".$isofile.".iso";
    my $attr = "-R -J -f -pad -joliet-long";
    my $flags= $xmltype -> getFlags();
    my $volid= $xmltype -> getVolID();
    if (! defined $gzip) {
        $attr = "-R -J -pad -joliet-long";
    }
    if ((($flags) && ($flags =~ /clic_udf|seed|overlay/)) &&
	(defined $gzip)) {
        $attr .= " -iso-level 3 -udf";
    } elsif ((($flags) && ($flags =~ /clic_udf|seed|overlay/)) &&
	(! defined $gzip)) {
        $attr .= " -iso-level 4 -udf";
    } elsif (! defined $gzip) {
        $attr .= " -iso-level 4";
    }
    if ($volid) {
        $attr .= " -V \"$volid\"";
    }
    $attr .= " -A \"$this->{mbrid}\"";
    $attr .= ' -p "'.$this->{gdata}->{Preparer}.'"';
    $attr .= ' -publisher "'.$this->{gdata}->{Publisher}.'"';
    my $isolinux = KIWIIsoLinux -> new (
        $CD,$name,$attr,"checkmedia",$this->{cmdL},$this->{xml}
    );
    if (defined $isolinux) {
        $isoerror = 0;
        if (! $isolinux -> makeIsoEFIBootable()) {
            $isoerror = 1;
        }
        if (! $isolinux -> callBootMethods()) {
            $isoerror = 1;
        }
        if (! $isolinux -> addBootLive()) {
            $isoerror = 1;
        }
        if (! $isolinux -> createISO()) {
            $isoerror = 1;
        }
    }
    if ($isoerror) {
        $isolinux -> cleanISO();
        return;
    }
    #==========================================
    # Check for edit boot install
    #------------------------------------------
    if ($cmdL) {
        my $editBoot = $cmdL -> getEditBootInstall();
        my $idesc;
        if ((! $editBoot) && ($xml)) {
            $editBoot = $xml -> getImageType() -> getEditBootInstall();
        }
        if ($editBoot) {
            if (($this->{originXMLPath}) && (! -f $editBoot)) {
                $editBoot = $this->{originXMLPath}."/".$editBoot;
            }
            if (-f $editBoot) {
                $kiwi -> info ("Calling post bootloader install script:\n");
                $kiwi -> info ("--> $editBoot\n");
                my @opts = ($name);
                system ("cd $CD && chmod u+x $editBoot");
                system ("cd $CD && bash --norc -c \"$editBoot @opts\"");
                my $result = $? >> 8;
                if ($result != 0) {
                    $kiwi -> error ("Call failed, see console log");
                    $kiwi -> failed ();
                    $isolinux -> cleanISO();
                    return;
                }
            } else {
                $kiwi -> warning (
                    "Can't find post bootloader install script: $editBoot..."
                );
                $kiwi -> skipped ();
            }
        }
    }
    #==========================================
    # relocate boot catalog
    #------------------------------------------
    if (! $isolinux -> relocateCatalog()) {
        $isolinux -> cleanISO();
        return;
    }
    if (! $isolinux -> fixCatalog()) {
        $isolinux -> cleanISO();
        return;
    }
    #==========================================
    # Turn ISO into hybrid if requested
    #------------------------------------------
    if ($hybrid) {
        $kiwi -> info ("Setting up hybrid ISO...\n");
        if (! $isolinux -> createHybrid ($this->{mbrid})) {
            $kiwi -> error  ("Failed to create hybrid ISO image");
            $kiwi -> failed ();
            $isolinux -> cleanISO();
            return;
        }
    }
    #==========================================
    # tag ISO image with tagmedia
    #------------------------------------------
    if (-x "/usr/bin/tagmedia") {
        $kiwi -> info ("Adding checkmedia tag...");
        if (! $isolinux -> checkImage()) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to tag ISO image");
            $kiwi -> failed ();
            $isolinux -> cleanISO();
            return;
        }
        $kiwi -> done();
    }
    #==========================================
    # cleanup
    #------------------------------------------
    KIWIQX::qxx ("rm -rf $CD 2>&1");
    $isolinux -> cleanISO();
    return $this;
}

#==========================================
# createImageSplit
#------------------------------------------
sub createImageSplit {
    # ...
    # Create all split images and the specified boot image which
    # should be used in combination to this split image. The process
    # requires subsequent kiwi calls to create the vmx/oemboot
    # required virtual disk images or the created images needs
    # to be copied into a PXE boot structure for use with
    # a netboot setup.
    # ---
    my $this         = shift;
    my $type         = shift;
    my $kiwi         = $this->{kiwi};
    my $cmdL         = $this->{cmdL};
    my $imageTree    = $this->{imageTree};
    my $baseSystem   = $this->{baseSystem};
    my $xml          = $this->{xml};
    my $idest        = $cmdL->getImageIntermediateTargetDir();
    my $fsopts       = $cmdL -> getFilesystemOptions();
    my $inodesize    = $fsopts -> getInodeSize();
    my $FSTypeRW;
    my $FSTypeRO;
    my $error;
    my $ok;
    my $imageTreeRW;
    my $imageTreeTmp;
    my $mbytesro;
    my $mbytesrw;
    my $xmlsize;
    my $boot;
    my $plinux;
    my $pinitrd;
    my $data;
    my $code;
    my $name;
    my $treebase;
    my $xendomain;
    my $minInodes;
    my $sizeBytes;
    my $splitconf  = $xml -> getSplitConfig();
    my $rootTarget = $cmdL->getRootTargetDir();
    if (! $rootTarget) {
        $rootTarget = $cmdL->getConfigDir();
    }
    my $checkBase = $rootTarget."/".$baseSystem;
    #==========================================
    # check for xen domain setup
    #------------------------------------------
    my $vconf = $xml -> getVMachineConfig();
    if ($vconf) {
        $xendomain = $vconf -> getDomain();
    }
    if (! $xendomain) {
        $xendomain = "dom0";
    }
    #==========================================
    # turn image path into absolute path
    #------------------------------------------
    if ($imageTree !~ /^\//) {
        my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
        $imageTree = $pwd."/".$imageTree;
    }
    #==========================================
    # Get filesystem info for split image
    #------------------------------------------
    if ($type =~ /(.*),(.*):(.*)/) {
        $FSTypeRW = $1;
        $FSTypeRO = $2;
        $boot = $3;
    } elsif ($type =~ /(.*),(.*)/) {
        $FSTypeRW = $1;
        $FSTypeRO = $2;
    } else {
        $kiwi -> error  ("Invalid filesystem setup for split type");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Get system image type information
    #------------------------------------------
    my $xmltype = $xml -> getImageType();
    #==========================================
    # Get image creation date and name
    #------------------------------------------
    my $namerw = KIWIGlobals -> instance() -> generateBuildImageName(
        $this->{xml},'-', '-read-write'
    );
    my $namero = KIWIGlobals
        -> instance()
        -> generateBuildImageName($this->{xml});
    if (! defined $namerw) {
        return;
    }
    #==========================================
    # Call images.sh script
    #------------------------------------------
    if (! $this -> setupLogicalExtend ("quiet", $namero)) {
        return;
    }
    #==========================================
    # Create clone of prepared tree
    #------------------------------------------
    $kiwi -> info ("Creating root tree clone for split operations");
    $treebase = basename $imageTree;
    if (-d $this->{imageDest}."/".$treebase) {
        KIWIQX::qxx ("rm -rf $this->{imageDest}/$treebase");
    }
    $data = KIWIQX::qxx ("cp -a -x $imageTree $this->{imageDest}");
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Can't create copy of image tree: $data");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $imageTree");
        return;
    }
    $kiwi -> done();
    #==========================================
    # split physical extend into RW/RO/tmp part
    #------------------------------------------
    $imageTree = $this->{imageDest}."/".$treebase;
    if ($imageTree !~ /^\//) {
        my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
        $imageTree = $pwd."/".$imageTree;
    }
    $imageTreeTmp = $imageTree;
    $imageTreeTmp =~ s/\/+$//;
    $imageTreeTmp.= "-tmp/";
    $this->{imageTreeTmp} = $imageTreeTmp;
    #==========================================
    # run split tree creation
    #------------------------------------------
    $kiwi -> info ("Creating temporary image part...\n");
    if (! mkdir $imageTreeTmp) {
        $error = $!;
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create split tmp directory: $error");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $imageTree");
        return;
    }
    #==========================================
    # walk through except files if any
    #------------------------------------------
    my %exceptHash;
    my $tmp_except_list = [];
    if ($splitconf) {
        $tmp_except_list = $splitconf -> getTemporaryExceptions();
    }
    foreach my $except_item (@{$tmp_except_list}) {
        my $except = $except_item -> getName();
        my $globsource = "${imageTree}${except}";
        my $files = KIWIQX::qxx("find $globsource -xtype f 2>/dev/null");
        my $code  = $? >> 8;
        if ($code != 0) {
            # excepted file(s) doesn't exist anyway
            next;
        }
        my @files = split(/\n/,$files);
        foreach my $file (@files) {
            $exceptHash{$file} = $file;
        }
    }
    #==========================================
    # create linked list for files, create dirs
    #------------------------------------------
    my $createTmpTree = sub {
        my $file  = $_;
        my $dir   = $File::Find::dir;
        my $path  = "$dir/$file";
        my $target= $path;
        $target =~ s#$imageTree#$imageTreeTmp#;
        my $rerooted = $path;
        $rerooted =~ s#$imageTree#/read-only/#;
        my $st = lstat($path);
        return if ! $st;
        if (S_ISDIR($st->mode)) {
            mkdir $target;
            chmod S_IMODE($st->mode), $target;
            chown $st->uid, $st->gid, $target;
        } elsif (
            S_ISCHR($st->mode)  ||
            S_ISBLK($st->mode)  ||
            S_ISLNK($st->mode)
        ) {
            KIWIQX::qxx ("cp -a $path $target");
        } else {
            $rerooted =~ s#/+#/#g;
            symlink ($rerooted, $target);
        }
    };
    find(\&$createTmpTree, $imageTree);
    my @tempFiles    = ();
    my @persistFiles = ();
    if ($splitconf) {
        my $tmp_file_list = $splitconf -> getTemporaryFiles();
        for my $item (@{$tmp_file_list}) {
            my $name = $item -> getName();
            push @tempFiles,$name;
        }
    }
    if ($splitconf) {
        my $persist_file_list = $splitconf -> getPersistentFiles();
        for my $item (@{$persist_file_list}) {
            my $name = $item -> getName();
            push @persistFiles,$name;
        }
    }
    #==========================================
    # search temporary files, respect excepts
    #------------------------------------------
    my %tempFiles_new;
    if (@tempFiles) {
        foreach my $temp (@tempFiles) {
            my $globsource = "${imageTree}${temp}";
            my $files = KIWIQX::qxx("find $globsource -xtype f 2>/dev/null");
            my $code  = $? >> 8;
            if ($code != 0) {
                $kiwi -> warning ("file $globsource doesn't exist");
                $kiwi -> skipped ();
                next;
            }
            my @files = split(/\n/,$files);
            foreach (@files) {
                $tempFiles_new{$_} = $_;
            }
        }
    }
    @tempFiles = sort keys %tempFiles_new;
    if (@tempFiles) {
        foreach my $file (@tempFiles) {
            if (defined $exceptHash{$file}) {
                next;
            }
            my $dest = $file;
            $dest =~ s#$imageTree#$imageTreeTmp#;
            KIWIQX::qxx ("rm -rf $dest");
            KIWIQX::qxx ("mv $file $dest");
        }
    }
    #==========================================
    # find persistent files for the read-write
    #------------------------------------------
    $imageTreeRW = $imageTree;
    $imageTreeRW =~ s/\/+$//;
    $imageTreeRW.= "-read-write";
    if (@persistFiles) {
        $kiwi -> info ("Creating read-write image part...\n");
        #==========================================
        # Create read-write directory
        #------------------------------------------
        $this->{imageTreeRW} = $imageTreeRW;
        if (! mkdir $imageTreeRW) {
            $error = $!;
            $kiwi -> error  (
                "Couldn't create split read-write directory: $error"
            );
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $imageTree $imageTreeTmp");
            return;
        }
        #==========================================
        # walk through except files if any
        #------------------------------------------
        my %exceptHash;
        my $persist_except_list = [];
        if ($splitconf) {
            $persist_except_list = $splitconf -> getPersistentExceptions();
        }
        foreach my $except_item (@{$persist_except_list}) {
            my $except = $except_item -> getName();
            my $globsource = "${imageTree}${except}";
            my $files = KIWIQX::qxx("find $globsource -xtype f 2>/dev/null");
            my $code  = $? >> 8;
            if ($code != 0) {
                # excepted file(s) doesn't exist anyway
                next;
            }
            my @files = split(/\n/,$files);
            foreach my $file (@files) {
                $exceptHash{$file} = $file;
            }
        }
        #==========================================
        # search persistent files, respect excepts
        #------------------------------------------
        my %expandedPersistFiles;
        foreach my $persist (@persistFiles) {
            my $globsource = "${imageTree}${persist}";
            my $files = KIWIQX::qxx("find $globsource 2>/dev/null");
            my $code  = $? >> 8;
            if ($code != 0) {
                $kiwi -> warning ("file $globsource doesn't exist");
                $kiwi -> skipped ();
                next;
            }
            my @files = split(/\n/,$files);
            foreach my $file (@files) {
                if (defined $exceptHash{$file}) {
                    next;
                }
                $expandedPersistFiles{$file} = $file;
            }
        }
        @persistFiles = keys %expandedPersistFiles;
        #==========================================
        # relink to read-write, and move files
        #------------------------------------------
        foreach my $file (@persistFiles) {
            my $dest = $file;
            my $link = $file;
            my $rlnk = $file;
            $dest =~ s#$imageTree#$imageTreeRW#;
            $link =~ s#$imageTree#$imageTreeTmp#;
            $rlnk =~ s#$imageTree#/read-write#;
            if (-d $file) {
                #==========================================
                # recreate directory
                #------------------------------------------
                my $st = stat($file);
                KIWIQX::qxx ("mkdir -p $dest");
                chmod S_IMODE($st->mode), $dest;
                chown $st->uid, $st->gid, $dest;
            } else {
                #==========================================
                # move file to read-write area
                #------------------------------------------
                my $st = stat(dirname $file);
                my $destdir = dirname $dest;
                KIWIQX::qxx ("rm -rf $dest");
                KIWIQX::qxx ("mkdir -p $destdir");
                chmod S_IMODE($st->mode), $destdir;
                chown $st->uid, $st->gid, $destdir;
                KIWIQX::qxx ("mv $file $dest");
                #==========================================
                # relink file to read-write area
                #------------------------------------------
                KIWIQX::qxx ("rm -rf $link");
                KIWIQX::qxx ("ln -s $rlnk $link");
            }
        }
        #==========================================
        # relink if entire directory was set
        #------------------------------------------
        my $persist_file_list = [];
        if ($splitconf) {
            $persist_file_list = $splitconf -> getPersistentFiles();
        }
        foreach my $persist_item (@{$persist_file_list}) {
            my $persist = $persist_item -> getName();
            my $globsource = "${imageTree}${persist}";
            if (-d $globsource) {
                my $link = $globsource;
                my $rlnk = $globsource;
                $link =~ s#$imageTree#$imageTreeTmp#;
                $rlnk =~ s#$imageTree#/read-write#;
                #==========================================
                # relink directory to read-write area
                #------------------------------------------
                KIWIQX::qxx ("rm -rf $link");
                KIWIQX::qxx ("ln -s $rlnk $link");
            }
        }
    }
    #==========================================
    # Embed rootfs meta data into ro extend
    #------------------------------------------
    $minInodes = KIWIQX::qxx ("find $imageTreeTmp | wc -l");
    $sizeBytes = KIWIGlobals -> instance() -> dsize ($imageTreeTmp);
    $sizeBytes+= $minInodes * $inodesize;
    $sizeBytes = sprintf ("%.0f", $sizeBytes);
    $minInodes*= 2;
    if (open (my $FD, '>', "$imageTree/rootfs.meta")) {
        print $FD "inode_nr=$minInodes\n";
        print $FD "min_size=$sizeBytes\n";
        close $FD;
    } else {
        $kiwi -> error  ("Failed to create rootfs meta data: $!");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $imageTreeRW");
        KIWIQX::qxx ("rm -rf $imageTreeTmp");
        KIWIQX::qxx ("rm -rf $imageTree");
        return;
    }
    #==========================================
    # Embed rootfs.tar for tmpfs into ro extend
    #------------------------------------------
    $data = KIWIQX::qxx (
        "cd $imageTreeTmp && tar -cf $imageTree/rootfs.tar * 2>&1"
    );
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Failed to create rootfs tarball: $data");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $imageTreeRW");
        KIWIQX::qxx ("rm -rf $imageTreeTmp");
        KIWIQX::qxx ("rm -rf $imageTree");
        return;
    }
    #==========================================
    # Clean rootfs tmp tree
    #------------------------------------------
    KIWIQX::qxx ("rm -rf $imageTreeTmp");
    #==========================================
    # Count disk space for extends
    #------------------------------------------
    $kiwi -> info ("Computing disk space...");
    ($mbytesro,$xmlsize) = $this -> getSize ($imageTree);
    if (defined $this->{imageTreeRW}) {
        ($mbytesrw,$xmlsize) = $this -> getSize ($imageTreeRW);
    }
    $kiwi -> done ();
    if (defined $this->{imageTreeRW}) {
        #==========================================
        # Create RW logical extend
        #------------------------------------------
        if (defined $this->{imageTreeRW}) {
            $kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
            if (! $this -> buildLogicalExtend ($namerw,$mbytesrw."M")) {
                KIWIQX::qxx ("rm -rf $imageTreeRW");
                KIWIQX::qxx ("rm -rf $imageTree");
                return;
            }
            $kiwi -> done();
        }
        #==========================================
        # Create filesystem on RW extend
        #------------------------------------------
        SWITCH: for ($FSTypeRW) {
            /ext2/       && do {
                $ok = $this -> setupEXT2 ( $namerw );
                last SWITCH;
            };
            /ext3/       && do {
                $ok = $this -> setupEXT2 ( $namerw,"journaled-ext3" );
                last SWITCH;
            };
            /ext4/       && do {
                $ok = $this -> setupEXT2 ( $namerw,"journaled-ext4" );
                last SWITCH;
            };
            /reiserfs/   && do {
                $ok = $this -> setupReiser ( $namerw );
                last SWITCH;
            };
            /btrfs/      && do {
                $ok = $this -> setupBTRFS ( $namerw );
                last SWITCH;
            };
            /xfs/        && do {
                $ok = $this -> setupXFS ( $namerw );
                last SWITCH;
            };
            /zfs/        && do {
                $ok = $this -> setupZFS ( $namerw );
                last SWITCH;
            };
            $kiwi -> error  ("Unsupported type: $FSTypeRW");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $imageTreeRW");
            KIWIQX::qxx ("rm -rf $imageTree");
            $this -> cleanLuks();
            return;
        }
        if (! $ok) {
            KIWIQX::qxx ("rm -rf $imageTreeRW");
            KIWIQX::qxx ("rm -rf $imageTree");
            $this -> cleanLuks();
            return;
        }
    }
    #==========================================
    # Create RO logical extend
    #------------------------------------------
    $kiwi -> info ("Image RO part requires $mbytesro MB of disk space");
    if (! $this -> buildLogicalExtend ($namero,$mbytesro."M")) {
        KIWIQX::qxx ("rm -rf $imageTreeRW");
        KIWIQX::qxx ("rm -rf $imageTree");
        return;
    }
    $kiwi -> done();
    #==========================================
    # Create filesystem on RO extend
    #------------------------------------------
    SWITCH: for ($FSTypeRO) {
        /ext2/       && do {
            $ok = $this -> setupEXT2 ( $namero );
            last SWITCH;
        };
        /ext3/       && do {
            $ok = $this -> setupEXT2 ( $namero,"journaled-ext3" );
            last SWITCH;
        };
        /ext4/       && do {
            $ok = $this -> setupEXT2 ( $namero,"journaled-ext4" );
            last SWITCH;
        };
        /reiserfs/   && do {
            $ok = $this -> setupReiser ( $namero );
            last SWITCH;
        };
        /btrfs/      && do {
            $ok = $this -> setupBTRFS ( $namero );
            last SWITCH;
        };
        /squashfs/   && do {
            $ok = $this -> setupSquashFS ( $namero,$imageTree );
            last SWITCH;
        };
        /xfs/      && do {
            $ok = $this -> setupXFS ( $namero );
            last SWITCH;
        };
        /zfs/      && do {
            $ok = $this -> setupZFS ( $namero );
            last SWITCH;
        };
        $kiwi -> error  ("Unsupported type: $FSTypeRO");
        $kiwi -> failed ();
        KIWIQX::qxx ("rm -rf $imageTreeRW");
        KIWIQX::qxx ("rm -rf $imageTree");
        $this -> cleanLuks();
        return;
    }
    if (! $ok) {
        KIWIQX::qxx ("rm -rf $imageTreeRW");
        KIWIQX::qxx ("rm -rf $imageTree");
        $this -> cleanLuks();
        return;
    }
    #==========================================
    # Install logical extends
    #------------------------------------------
    foreach my $name ($namerw,$namero) {
        #==========================================
        # select physical extend
        #------------------------------------------
        my $source;
        my $type;
        if ($name eq $namerw) {
            $source = $imageTreeRW;
            $type = $FSTypeRW;
        } else {
            $source = $imageTree;
            $type = $FSTypeRO;
        }
        if (! -d $source) {
            next;
        }
        my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($type);
        if (! $fsattr{readonly}) {
            #==========================================
            # mount logical extend for data transfer
            #------------------------------------------
            my $extend = $this -> mountLogicalExtend ($name);
            if (! defined $extend) {
                KIWIQX::qxx ("rm -rf $imageTreeRW");
                KIWIQX::qxx ("rm -rf $imageTree");
                $this -> cleanLuks();
                return;
            }
            #==========================================
            # copy physical to logical
            #------------------------------------------
            if (! $this -> installLogicalExtend ($extend,$source)) {
                KIWIQX::qxx ("rm -rf $imageTreeRW");
                KIWIQX::qxx ("rm -rf $imageTree");
                $this -> cleanLuks();
                return;
            }
            $this -> cleanMount();
        }
        #==========================================
        # Checking file system
        #------------------------------------------
        $kiwi -> info ("Checking file system: $type...");
        SWITCH: for ($type) {
            /ext2/       && do {
                KIWIQX::qxx (
                    "/sbin/e2fsck -f -y $this->{imageDest}/$name 2>&1"
                );
                $kiwi -> done();
                last SWITCH;
            };
            /ext3/       && do {
                KIWIQX::qxx (
                    "/sbin/fsck.ext3 -f -y $this->{imageDest}/$name 2>&1"
                );
                KIWIQX::qxx (
                    "/sbin/tune2fs -j $this->{imageDest}/$name 2>&1"
                );
                $kiwi -> done();
                last SWITCH;
            };
            /ext4/       && do {
                KIWIQX::qxx (
                    "/sbin/fsck.ext4 -f -y $this->{imageDest}/$name 2>&1"
                );
                KIWIQX::qxx (
                    "/sbin/tune2fs -j $this->{imageDest}/$name 2>&1"
                );
                $kiwi -> done();
                last SWITCH;
            };
            /reiserfs/   && do {
                KIWIQX::qxx (
                    "/sbin/reiserfsck -y $this->{imageDest}/$name 2>&1"
                );
                $kiwi -> done();
                last SWITCH;
            };
            /btrfs/      && do {
                KIWIQX::qxx (
                    "/sbin/btrfsck $this->{imageDest}/$name 2>&1"
                );
                $kiwi -> done();
                last SWITCH;
            };
            /squashfs/   && do {
                $kiwi -> done ();
                last SWITCH;
            };
            /xfs/        && do {
                KIWIQX::qxx (
                    "/sbin/mkfs.xfs $this->{imageDest}/$name 2>&1"
                );
                $kiwi -> done();
                last SWITCH;
            };
            /zfs/        && do {
                # do nothing for zfs
                $kiwi -> done();
                last SWITCH;
            };
            $kiwi -> error  ("Unsupported type: $type");
            $kiwi -> failed ();
            KIWIQX::qxx ("rm -rf $imageTreeRW");
            KIWIQX::qxx ("rm -rf $imageTree");
            $this -> cleanLuks();
            return;
        }
        #==========================================
        # Create image md5sum
        #------------------------------------------
        $this -> restoreImageDest();
        if (! $this -> buildMD5Sum ($name)) {
            KIWIQX::qxx ("rm -rf $imageTreeRW");
            KIWIQX::qxx ("rm -rf $imageTree");
            $this -> cleanLuks();
            return;
        }
        $this -> remapImageDest();
    }
    $this -> restoreImageDest();
    $this -> cleanLuks();
    #==========================================
    # Create network boot configuration
    #------------------------------------------
    if (! $this -> writeImageConfig ($namero)) {
        KIWIQX::qxx ("rm -rf $imageTreeRW");
        KIWIQX::qxx ("rm -rf $imageTree");
        return;
    }
    #==========================================
    # Cleanup temporary data
    #------------------------------------------
    KIWIQX::qxx ("rm -rf $imageTreeRW");
    KIWIQX::qxx ("rm -rf $imageTree");
    #==========================================
    # build boot image only if specified
    #------------------------------------------
    if (! defined $boot) {
        return $this;
    }
    $imageTree = $this->{imageTree};
    #==========================================
    # Prepare and Create boot image
    #------------------------------------------
    my $bname = $this -> createImageBootImage (
        'split',$boot,$xml,$idest,$checkBase
    );
    if (! $bname) {
        return;
    }
    #==========================================
    # setup initrd name
    #------------------------------------------
    my $initrd = $idest."/".$bname.".".$this->{gdata}->{IrdZipperSuffix};
    if (! -f $initrd) {
        $initrd = $idest."/".$bname;
    }
    #==========================================
    # Check boot and system image kernel
    #------------------------------------------
    if ($cmdL->getCheckKernel()) {
        if (! $this -> checkKernel ($initrd,$imageTree,$bname)) {
            return;
        }
    }
    #==========================================
    # Include splash screen to initrd
    #------------------------------------------
    KIWIGlobals -> instance() -> setupSplash($initrd);
    #==========================================
    # Store meta data for subsequent calls
    #------------------------------------------
    $name->{systemImage} = KIWIGlobals
        -> instance()
        -> generateBuildImageName($xml);
    $name->{bootImage}   = $bname;
    $name->{format}      = $xmltype -> getFormat();
    if ($boot =~ /vmxboot|oemboot/) {
        #==========================================
        # Create virtual disk images if requested
        #------------------------------------------
        my $suf = $this->{gdata}->{IrdZipperSuffix};
        $cmdL -> setInitrdFile (
            $idest."/".$name->{bootImage}.".splash.".$suf
        );
        $cmdL -> setSystemLocation (
            $idest."/".$name->{systemImage}
        );
        my $kic = KIWIImageCreator -> new($cmdL);
        if ((! $kic) || (! $kic->createImageDisk($xml))) {
            undef $kic;
            return;
        }
        #==========================================
        # Create VM format/configuration
        #------------------------------------------
        if ((defined $name->{format}) || ($xendomain eq "domU")) {
            $cmdL -> setSystemLocation (
                $idest."/".$name->{systemImage}.".raw"
            );
            $cmdL -> setImageFormat ($name->{format});
            my $kic = KIWIImageCreator -> new($cmdL);
            if ((! $kic) || (! $kic->createImageFormat($xml))) {
                undef $kic;
                return;
            }
        }
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
    # (bs,count,seek)
    # ---
    my $this = shift;
    my $size = shift;
    my $bigimage   = 1048576; # 1M
    my $smallimage = 8192;    # 8K
    my $number;
    my $suffix;
    my $count;
    my $seek;
    if ($size =~ /(\d+)(.*)/) {
        $number = $1;
        $suffix = $2;
        SWITCH: for ($suffix) {
            /K/i && do {
                $number *= 1024;
                last SWITCH;
            }; 
            /M/i && do {
                $number *= 1024 * 1024;
                last SWITCH;
            }; 
            /G/i && do {
                $number *= 1024 * 1024 * 1024;
                last SWITCH;
            };
        }
    } else {
        $number = $size;
    }
    if ($number > 100 * 1024 * 1024) {
        # big image...
        $count = $number / $bigimage;
        $count = Math::BigFloat->new($count)->ffround(0);
        $seek  = $count*$bigimage;
        return (($bigimage,$count,$seek));
    } else {
        # small image...
        $count = $number / $smallimage;
        $count = Math::BigFloat->new($count)->ffround(0);
        $seek  = $count*$smallimage;
        return (($smallimage,$count,$seek));
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
    my $this       = shift;
    my $haveExtend = shift;
    my $quiet      = shift;
    #==========================================
    # Get image creation date and name
    #------------------------------------------
    my $name = KIWIGlobals
        -> instance()
        -> generateBuildImageName($this->{xml});
    if (! defined $name) {
        return;
    }
    #==========================================
    # Call images.sh script
    #------------------------------------------
    my $mBytes = $this -> setupLogicalExtend ($quiet,$name);
    if (! defined $mBytes) {
        return;
    }
    #==========================================
    # Create logical extend
    #------------------------------------------
    if (! $this -> buildLogicalExtend ($name,$mBytes."M",$haveExtend)) {
        return;
    }
    return $name;
}

#==========================================
# writeImageConfig
#------------------------------------------
sub writeImageConfig {
    my $this = shift;
    my $name = shift;
    my $kiwi = $this->{kiwi};
    my $xml  = $this->{xml};
    my $configName = KIWIGlobals
    -> instance()
    -> generateBuildImageName($this->{xml});
    $configName .= '.config';
    my $pxeConfig = $xml -> getPXEConfig();
    my $bldType   = $xml -> getImageType();
    my $device;
    if ($pxeConfig) {
        $device = $pxeConfig -> getDevice();
    }
    #==========================================
    # create .config for types which needs it
    #------------------------------------------
    if (defined $device) {
        $kiwi -> info ("Creating boot configuration...");
        my $FD = FileHandle -> new();
        if (! $FD -> open (">$this->{imageDest}/$configName")) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't create image boot configuration");
            $kiwi -> failed ();
            return;
        }
        my $namecd = KIWIGlobals -> instance()
            -> generateBuildImageName($this->{xml}, ';');
        my $namerw = KIWIGlobals -> instance()
            -> generateBuildImageName($this->{xml},';', '-read-write');
        my $server = $pxeConfig -> getServer();
        my $blocks = $pxeConfig -> getBlocksize();
        if (! defined $server) {
            $server = "";
        }
        if (! defined $blocks) {
            $blocks = "";
        }
        print $FD "DISK=${device}\n";
        my $targetPartition = 2;
        my $targetPartitionNext = 3;
        #==========================================
        # PART information
        #------------------------------------------
        my $partIDs = $pxeConfig -> getPartitionIDs();
        if ($partIDs) {
            print $FD "PART=";
            for my $partID (@{$partIDs}) {
                my $target = $pxeConfig -> getPartitionTarget($partID);
                if ($target && $target eq 'true') {
                    $targetPartition =
                        $pxeConfig -> getPartitionNumber($partID);
                    $targetPartitionNext = $targetPartition + 1;
                }
                my $partSize = $pxeConfig -> getPartitionSize($partID);
                if ($partSize eq 'image') {
                    my $size = KIWIGlobals -> instance() -> isize (
                        "$this->{imageDest}/$name"
                    );
                    print $FD int (($size/1024/1024)+1);
                } else {
                    print $FD $partSize;
                }
                my $partType = $pxeConfig -> getPartitionType($partID);
                my $mountpoint = $pxeConfig -> getPartitionMountpoint($partID);

                SWITCH: for ($partType) {
                    /swap/i && do {
                        $partType = "S";
                        last SWITCH;
                    };
                    /linux/i && do {
                        $partType = "83";
                        last SWITCH;
                    };
                }
                print $FD ";$partType;$mountpoint,";
            }
            print $FD "\n";
        }
        #==========================================
        # IMAGE information
        #------------------------------------------
        my $compressed = $bldType -> getCompressed();
        my $imgType = $bldType -> getTypeName();
        if ($compressed && $compressed eq 'true') {
            print $FD "IMAGE='${device}${targetPartition};";
            print $FD "$namecd;$server;$blocks;compressed-gzip'";
            if ($imgType eq "split" && defined $this->{imageTreeRW}) {
                print $FD ",${device}${targetPartitionNext}";
                print $FD ";$namerw;$server;$blocks;compressed-gzip\n";
            } else {
                print $FD "\n";
            }
        } else {
            print $FD "IMAGE='${device}${targetPartition};";
            print $FD "$namecd;$server;$blocks'";
            if ($imgType eq "split" && defined $this->{imageTreeRW}) {
                print $FD ",${device}${targetPartitionNext}";
                print $FD ";$namerw;$server;$blocks\n";
            } else {
                print $FD "\n";
            }
        }
        #==========================================
        # CONF information
        #------------------------------------------
        my $bldArch = $xml -> getArch();
        my $configs = $xml -> getPXEConfigData();
        if ($configs) {
            my $confStr = 'CONF=';
            my $writeIt;
            for my $confData (@{$configs}) {
                my $confArch = $confData -> getArch();
                my $useIt = 1;
                if ($confArch) {
                    $useIt = 0;
                    my @arches = split /,/smx, $confArch;
                    for my $arch (@arches) {
                        if ($arch eq $bldArch) {
                            $useIt = 1;
                            last;
                        }
                    }
                }
                if ($useIt) {
                    $writeIt = 1;
                    my $dest   = $confData -> getDestination();
                    my $source = $confData -> getSource();
                    $confStr .= "$source;$dest;$server;$blocks,";
                }
            }
            if ($writeIt) {
                $confStr .= "\n";
                print $FD $confStr;
            }
        }
        #==========================================
        # COMBINED_IMAGE information
        #------------------------------------------
        if ($imgType eq "split") {
            print $FD "COMBINED_IMAGE=yes\n";
        }
        #==========================================
        # UNIONFS_CONFIG information
        #------------------------------------------
        my $unionFS = $pxeConfig -> getUnionType();
        my $unionRO = $pxeConfig -> getUnionRO();
        my $unionRW = $pxeConfig -> getUnionRW();
        if ($unionRO && $unionRW) {
            print $FD "UNIONFS_CONFIG='"
                . $unionRW
                . ','
                . $unionRO
                . ','
                . $unionFS
                . "'\n";
        }
        #==========================================
        # kiwi_boot_timeout information
        #------------------------------------------
        my $timeout = $pxeConfig -> getTimeout();
        if (defined $timeout) {
            print $FD "kiwi_boot_timeout=$timeout\n";
        }
        #==========================================
        # KIWI_KERNEL_OPTIONS information
        #------------------------------------------
        my $cmdline = $bldType -> getKernelCmdOpts();
        if (defined $cmdline) {
            print $FD "KIWI_KERNEL_OPTIONS='$cmdline'\n";
        }
        #==========================================
        # KIWI_KERNEL information
        #------------------------------------------
        my $kernel = $pxeConfig -> getKernel();
        if (defined $kernel) {
            print $FD "KIWI_KERNEL=$kernel\n";
        }
        #==========================================
        # KIWI_INITRD information
        #------------------------------------------
        my $initrd = $pxeConfig -> getInitrd();
        if (defined $initrd) {
            print $FD "KIWI_INITRD=$initrd\n";
        }
        #==========================================
        # More to come...
        #------------------------------------------
        $FD -> close();
        $kiwi -> done ();
    }
    return $configName;
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
    my $this   = shift;
    my $name   = shift;
    my $nozip  = shift;
    my $fstype = shift;
    my $device = shift;
    my $kiwi     = $this->{kiwi};
    my $xml      = $this->{xml};
    my $initCache= $this->{initCache};
    my $xmltype  = $xml -> getImageType();
    #==========================================
    # mount logical extend for data transfer
    #------------------------------------------
    my $extend = $this -> mountLogicalExtend ($name,undef,$device);
    if (! defined $extend) {
        return;
    }
    #==========================================
    # Setup filesystem specific environment
    #------------------------------------------
    if (! defined $initCache) {
        if (($fstype) && ($fstype eq 'btrfs')) {
            $extend = KIWIGlobals
                -> instance()
                -> setupBTRFSSubVolumes ($extend,undef,'false',$device);
            if (! $extend) {
                $this -> cleanLuks();
                return;
            }
        }
    }
    #==========================================
    # copy physical to logical
    #------------------------------------------
    if (! $this -> installLogicalExtend ($extend,undef,$device)) {
        $this -> cleanLuks();
        return;
    }
    $this -> cleanMount();
    #==========================================
    # Check image file system
    #------------------------------------------
    my $filesystem = $xmltype -> getFilesystem();
    my $imagetype  = $xmltype -> getTypeName();
    if ((! $filesystem) && ($fstype)) {
        $filesystem = $fstype;
    }
    if (! $filesystem) {
        $filesystem = $imagetype;
    }
    my $para = $imagetype.":".$filesystem;
    if ($filesystem) {
        $kiwi -> info ("Checking file system: $filesystem...");
    } else {
        $kiwi -> info ("Checking file system: $imagetype...");
    }
    SWITCH: for ($para) {
        #==========================================
        # Check EXT3 file system
        #------------------------------------------
        /ext3|ec2|clicfs/i && do {
            KIWIQX::qxx ("/sbin/fsck.ext3 -f -y $this->{imageDest}/$name 2>&1");
            KIWIQX::qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
            $kiwi -> done();
            last SWITCH;
        };
        #==========================================
        # Check overlayfs file system
        #------------------------------------------
        /overlayfs/ && do {
            # nothing to do for overlayfs (squashfs)
            last SWITCH;
        };
        #==========================================
        # Check EXT4 file system
        #------------------------------------------
        /ext4/i     && do {
            KIWIQX::qxx ("/sbin/fsck.ext4 -f -y $this->{imageDest}/$name 2>&1");
            KIWIQX::qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
            $kiwi -> done();
            last SWITCH;
        };
        #==========================================
        # Check EXT2 file system
        #------------------------------------------
        /ext2/i     && do {
            KIWIQX::qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$name 2>&1");
            $kiwi -> done();
            last SWITCH;
        };
        #==========================================
        # Check ReiserFS file system
        #------------------------------------------
        /reiserfs/i && do {
            KIWIQX::qxx ("/sbin/reiserfsck -y $this->{imageDest}/$name 2>&1");
            $kiwi -> done();
            last SWITCH;
        };
        #==========================================
        # Check BTRFS file system
        #------------------------------------------
        /btrfs/     && do {
            KIWIQX::qxx ("/sbin/btrfsck $this->{imageDest}/$name 2>&1");
            $kiwi -> done();
            last SWITCH;
        };
        #==========================================
        # Check XFS file system
        #------------------------------------------
        /xfs/       && do {
            KIWIQX::qxx ("/sbin/fsck.xfs $this->{imageDest}/$name 2>&1");
            $kiwi -> done();
            last SWITCH;
        };
        #==========================================
        # Check ZFS file system
        #------------------------------------------
        /zfs/       && do {
            # do nothing for zfs
            $kiwi -> done();
            last SWITCH;
        };
        #==========================================
        # Unknown filesystem type
        #------------------------------------------
        $kiwi -> failed();
        $kiwi -> error ("Unsupported filesystem type: $filesystem");
        $kiwi -> failed();
        $this -> cleanLuks();
        return;
    }
    $this -> restoreImageDest();
    $this -> cleanLuks ();
    #==========================================
    # Create image md5sum
    #------------------------------------------
    if (($para ne "clicfs") && ($para ne "overlayfs")) {
        if (! $this -> buildMD5Sum ($name)) {
            return;
        }
    }
    #==========================================
    # Compress image using gzip
    #------------------------------------------
    if (! defined $nozip) {
        my $compressed = $xmltype -> getCompressed();
        if (($compressed) && ($compressed eq 'true')) {
            my $rootfs;
            if ($filesystem) {
                $rootfs = $filesystem;
            } else {
                $rootfs = $imagetype;
            }
            if (! $this -> compressImage ($name,$rootfs)) {
                return;
            }
        }
    }
    #==========================================
    # Create image boot configuration
    #------------------------------------------
    if (! $this -> writeImageConfig ($name)) {
        return;
    }
    return $name;
}

#==========================================
# buildLogicalExtend
#------------------------------------------
sub buildLogicalExtend {
    my $this   = shift;
    my $name   = shift;
    my $size   = shift;
    my $device = shift;
    my $kiwi   = $this->{kiwi};
    my $xml    = $this->{xml};
    my $encode = 0;
    my $cipher = 0;
    my $out    = $this->{imageDest}."/".$name;
    my $xmltype= $xml -> getImageType();
    #==========================================
    # a size is required
    #------------------------------------------
    if (! defined $size) {
        return;
    }
    #==========================================
    # Check if luks encoding is requested
    #------------------------------------------
    my $luks = $xmltype -> getLuksPass();
    my $dist = $xmltype -> getLuksOS();
    if ($luks) {
        $encode = 1;
        $cipher = "$luks";
        KIWIGlobals -> instance() -> setKiwiConfigData ("LuksCipher",$cipher);
    }
    #==========================================
    # Calculate block size and number of blocks
    #------------------------------------------
    if (! defined $device) {
        my @bsc  = $this -> getBlocks ( $size );
        my $seek = $bsc[2];
        #==========================================
        # Create logical extend storage and FS
        #------------------------------------------
        if ($this->{gdata}->{StudioNode}) {
            #==========================================
            # Call custom image creation tool...
            #------------------------------------------
            my $data = KIWIQX::qxx ("$this->{gdata}->{StudioNode} $seek 2>&1");
            my $code = $? >> 8;
            chomp $data;
            if (($code != 0) || (! -b $data)) {
                $kiwi -> error  (
                    "Failed creating Studio storage device: $data"
                );
                $kiwi -> failed ();
                return;
            }
            $device = $data;
            $this->{targetDevice} = $device;
        } else {
            #==========================================
            # loop setup a disk device as file...
            #------------------------------------------
            unlink ($out);
            my $locator = KIWILocator -> instance();
            my $qemu_img = $locator -> getExecPath ("qemu-img");
            if (! $qemu_img) {
                $kiwi -> error  ("Mandatory qemu-img tool not found");
                $kiwi -> failed ();
                return;
            }
            my $data = KIWIQX::qxx ("$qemu_img create $out $seek 2>&1");
            my $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> error  ("Couldn't create logical extend");
                $kiwi -> failed ();
                $kiwi -> error  ($data);
                return;
            }
        }
    }
    #==========================================
    # Setup encoding
    #------------------------------------------
    if ($encode) {
        if (! $this -> setupEncoding($name,$out,$cipher,$dist,$device)) {
            return;
        }
    }
    return $name;
}

#==========================================
# setupEncoding
#------------------------------------------
sub setupEncoding {
    # ...
    # setup LUKS encoding on the given file and remap
    # the imageDest variable to the new device mapper
    # location
    # ---
    my $this   = shift;
    my $name   = shift;
    my $out    = shift;
    my $cipher = shift;
    my $dist   = shift;
    my $device = shift;
    my $kiwi   = $this->{kiwi};
    my $cmdL   = $this->{cmdL};
    my $data;
    my $code;
    if (($device) && (! -b $device)) {
        return;
    }
    if (! $device) {
        $data = KIWIGlobals -> instance() -> loop_setup($out, $this->{xml});
        if (! $data) {
            return;
        }
    } else {
        $data = $device;
    }
    my $loop = $data;
    my @luksloop;
    if ($this->{luksloop}) {
        @luksloop = @{$this->{luksloop}};
    }
    push @luksloop,$loop;
    $this->{luksloop} = \@luksloop;
    my $opts = '';
    if (($dist) && ($dist eq 'sle11')) {
        $opts = $this->{gdata}->{LuksDist}->{sle11};
    }
    # cryptsetup aligns in boundaries of 512-byte sectors
    my $alignment = int ($cmdL->getDiskAlignment() * 2);
    my $size_bt   = KIWIGlobals -> instance() -> isize ($loop);
    my $size_mb   = int ($size_bt / 1048576);
    $opts .= " --align-payload=$alignment";
    $data = KIWIQX::qxx (
        "dd if=/dev/urandom bs=1M count=$size_mb of=$loop 2>&1"
    );
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't fill image with random data: $data");
        $kiwi -> failed ();
        return;
    }
    $code = KIWIGlobals -> instance() -> cryptsetup (
        $cipher, "-q $opts luksFormat $loop"
    );
    if ($code != 0) {
        $kiwi -> error  ("Couldn't setup luks format: $loop");
        $kiwi -> failed ();
        return;
    }
    $code = KIWIGlobals -> instance() -> cryptsetup (
        $cipher, "luksOpen $loop $name"
    );
    if ($code != 0) {
        $kiwi -> error  ("Couldn't open luks device: $loop");
        $kiwi -> failed ();
        $this -> cleanLuks ();
        return;
    }
    my @luksname;
    if ($this->{luksname}) {
        @luksname = @{$this->{luksname}};
    }
    push @luksname,$name;
    $this->{luksname} = \@luksname;
    if (! $this->{imageDestOrig}) {
        $this->{imageDestOrig} = $this->{imageDest};
        $this->{imageDestMap} = "/dev/mapper/";
    }
    $this->{imageDest} = $this->{imageDestMap};
    return $this;
}

#==========================================
# installLogicalExtend
#------------------------------------------
sub installLogicalExtend {
    my $this   = shift;
    my $extend = shift;
    my $source = shift;
    my $device = shift;
    my $kiwi   = $this->{kiwi};
    my $imageTree = $this->{imageTree};
    if (! defined $source) {
        $source = $imageTree;
    }
    #==========================================
    # copy physical to logical
    #------------------------------------------
    my $name = basename ($source);
    $kiwi -> info ("Copying physical to logical [$name]...");
    my $free = KIWIQX::qxx ("df -h $extend 2>&1");
    $kiwi -> loginfo ("getSize: mount: $free\n");
    my $data = KIWIQX::qxx (
        "rsync -aHXA --one-file-system $source/ $extend 2>&1"
    );
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> info   ("rsync based copy failed: $data");
        $kiwi -> failed ();
        $this -> cleanMount();
        return;
    }
    $kiwi -> done();
    #==========================================
    # dump image file from device if requested
    #------------------------------------------
    if (($device) && (! $this->{gdata}->{StudioNode})) {
        $this -> cleanMount();
        $name = KIWIGlobals
            -> instance()
            -> generateBuildImageName($this->{xml});
        my $dest = $this->{imageDest}."/".$name;
        $kiwi -> info ("Dumping filesystem image from $device...");
        my $locator = KIWILocator -> instance();
        my $qemu_img = $locator -> getExecPath ("qemu-img");
        if (! $qemu_img) {
            $kiwi -> failed ();
            $kiwi -> error  ("Mandatory qemu-img tool not found");
            $kiwi -> failed ();
            return;
        }
        $data = KIWIQX::qxx (
            "$qemu_img convert -f raw -O raw $device $dest 2>&1"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to load filesystem image");
            $kiwi -> failed ();
            $kiwi -> error  ($data);
            return;
        }
        $kiwi -> done();
    }
    return $extend;
}

#==========================================
# setupLogicalExtend
#------------------------------------------
sub setupLogicalExtend {
    my $this  = shift;
    my $quiet = shift;
    my $name  = shift;
    my $kiwi  = $this->{kiwi};
    my $imageTree = $this->{imageTree};
    my $imageStrip= $this->{imageStrip};
    my $initCache = $this->{initCache};
    #==========================================
    # Call images.sh script
    #------------------------------------------
    if (! defined $initCache) {
        if (! $this -> executeUserImagesScript()) {
            return;
        }
    }
    #==========================================
    # extract kernel from physical extend
    #------------------------------------------
    if (! defined $initCache) {
        if (! $this -> extractKernel ($name)) {
            return;
        }
        $this -> extractSplash ($name);
    }
    #==========================================
    # Strip if specified
    #------------------------------------------
    if (defined $imageStrip) {
        $this -> stripImage();
    }
    #==========================================
    # Calculate needed space
    #------------------------------------------
    $this -> cleanKernelFSMount();
    my ($mbytes,$xmlsize) = $this -> getSize ($imageTree);
    if (! defined $quiet) {
        $kiwi -> info ("Image requires ".$mbytes."M, got $xmlsize");
        $kiwi -> done ();
        $kiwi -> info ("Suggested Image size: $mbytes"."M");
        $kiwi -> done ();
    }
    #==========================================
    # Check given XML size
    #------------------------------------------
    if ($xmlsize =~ /^(\d+)([MG])$/i) {
        $xmlsize = $1;
        my $unit = $2;
        if ($unit eq "G") {
            # convert GB to MB...
            $xmlsize *= 1024;
        }
    }
    #==========================================
    # Return XML size or required size
    #------------------------------------------
    if (int $xmlsize > $mbytes) {
        return $xmlsize;
    }
    return $mbytes;
}

#==========================================
# mountLogicalExtend
#------------------------------------------
sub mountLogicalExtend {
    my $this   = shift;
    my $name   = shift;
    my $opts   = shift;
    my $device = shift;
    my $kiwi   = $this->{kiwi};
    my $xml    = $this->{xml};
    my $dest   = $this->{imageDest}."/mnt-$$";
    my $target = "$this->{imageDest}/$name";
    my $xmltype= $xml -> getImageType();
    my $data;
    my $code;
    my @clean;
    #==========================================
    # check for target device
    #------------------------------------------
    if ($device) {
        $target = $device;
    }
    #==========================================
    # create mount point
    #------------------------------------------
    mkdir $dest;
    push @clean,"rmdir $dest";
    $this->{UmountStack} = \@clean;
    #==========================================
    # check for filesystem options
    #------------------------------------------
    my $fsmountoptions = $xmltype -> getFSMountOptions();
    if ($fsmountoptions) {
        $opts .= ','.$fsmountoptions;
    }
    if (! $device) {
        $opts .= ",loop";
    }
    my $fstype = KIWIQX::qxx (
        "/sbin/blkid -c /dev/null -s TYPE -o value $target"
    );
    chomp $fstype;
    if ($fstype eq "ext4") {
        # /.../
        # ext4 (currently) should be mounted with 'nodelalloc';
        # else we might run out of space unexpectedly...
        # ----
        $opts .= ",nodelalloc";
    }
    #==========================================
    # mount filesystem
    #------------------------------------------
    if ($fstype eq 'zfs_member') {
        #==========================================
        # mount zfs filesystem
        #------------------------------------------
        $data = KIWIQX::qxx (
            "zpool import -d $this->{imageDest} kiwipool 2>&1"
        );
        $code = $? >> 8;
        if ($code == 0) {
            push @clean,"zpool export kiwipool";
            $this->{UmountStack} = \@clean;
            $data = KIWIQX::qxx (
                "mount -n --bind /kiwipool/ROOT/system-1 $dest 2>&1"
            );
        }
    } else {
        #==========================================
        # standard mount
        #------------------------------------------
        if ($opts) {
            $opts =~ s/^,//;
            $data = KIWIQX::qxx ("mount -n -o $opts $target $dest 2>&1");
        } else {
            $data = KIWIQX::qxx ("mount -n $target $dest 2>&1");
        }
    }
    #==========================================
    # check return code
    #------------------------------------------
    $code = $? >> 8;
    if ($code != 0) {
        chomp $data;
        $kiwi -> error  ("Image file mount failed: $data");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # update cleanup stack
    #------------------------------------------
    push @clean,"umount $dest";
    $this->{UmountStack} = \@clean;
    return "$this->{imageDest}/mnt-$$";
}

#==========================================
# extractSplash
#------------------------------------------
sub extractSplash {
    my $this = shift;
    my $name = shift;
    my $kiwi = $this->{kiwi};
    my $imageTree = $this->{imageTree};
    my $imageDest = $this->{imageDest};
    my $zipper    = $this->{gdata}->{Gzip};
    my $newspl    = $imageDest."/splash";
    if (! defined $name) {
        return $this;
    }
    #==========================================
    # check if boot image
    #------------------------------------------
    if (! $this->isBootImage ($name)) {
        return $this;
    }
    #==========================================
    # check if plymouth is used and add flag
    #------------------------------------------
    if (-f "$imageTree/plymouth.splash.active") {
        KIWIQX::qxx ("touch $imageDest/plymouth.splash.active 2>&1");
        return $this;
    }
    #==========================================
    # move out all splash files
    #------------------------------------------
    $kiwi -> info ("Extracting kernel splash files...");
    mkdir $newspl;
    my $status = KIWIQX::qxx ("mv $imageTree/image/loader/*.spl $newspl 2>&1");
    my $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> skipped ();
        $kiwi -> info ("No splash files found in initrd");
        $kiwi -> skipped ();
        unlink $newspl;
        return $this;
    }
    #==========================================
    # create new splash with all pictures
    #------------------------------------------
    while (my $splash = glob("$newspl/*.spl")) {
        mkdir "$splash.dir";
        KIWIQX::qxx ("$zipper -cd $splash > $splash.bob");
        my $count = $this -> extractCPIO ( $splash.".bob" );
        for (my $id=1; $id <= $count; $id++) {
            KIWIQX::qxx (
                "cat $splash.bob.$id |(cd $splash.dir && cpio -i 2>&1)"
            );
        }
        KIWIQX::qxx ("cp -a $splash.dir/etc $newspl");
        $result = 1;
        if (-e "$splash.dir/bootsplash") {
            KIWIQX::qxx ("cat $splash.dir/bootsplash >> $newspl/bootsplash");
            $result = $? >> 8;
        }
        KIWIQX::qxx ("rm -rf $splash.dir");
        KIWIQX::qxx ("rm -f  $splash.bob*");
        KIWIQX::qxx ("rm -f  $splash");
        if ($result != 0) {
            my $splfile = basename ($splash);
            $kiwi -> skipped ();
            $kiwi -> info ("No bootsplash file found in $splfile cpio");
            $kiwi -> skipped ();
            return $this;
        }
    }
    KIWIQX::qxx ("(cd $newspl && \
        find|cpio --quiet -oH newc | $zipper) > $imageDest/$name.spl"
    );
    KIWIQX::qxx ("rm -rf $newspl");
    $kiwi -> done();
    return $this;
}

#==========================================
# isBootImage
#------------------------------------------
sub isBootImage {
    my $this = shift;
    my $name = shift;
    my $xml  = $this->{xml};
    if (! defined $name) {
        # no boot attribute set, no bootable entity
        return 2;
    }
    my $xmltype = $xml -> getImageType();
    my $imagetype  = $xmltype -> getTypeName();
    if ($imagetype eq 'cpio') {
        # cpio formatted initrd, OK
        return 1;
    }
    if (($imagetype eq 'ext2') && ($name =~ /boot/)) {
        # ext2 formatter initrd, OK
        return 1;
    }
    return 0;
}

#==========================================
# extractKernel
#------------------------------------------
sub extractKernel {
    my $this = shift;
    my $name = shift;
    my $imageTree = $this->{imageTree};
    #==========================================
    # check for boot image
    #------------------------------------------
    if (! defined $name) {
        return $this;
    }
    if (! $this->isBootImage ($name)) {
        return $name;
    }
    #==========================================
    # extract kernel from physical extend
    #------------------------------------------
    return $this -> extractLinux (
        $name,$imageTree,$this->{imageDest}
    );
}

#==========================================
# extractLinux
#------------------------------------------
sub extractLinux {
    my $this      = shift;
    my $name      = shift;
    my $imageTree = shift;
    my $dest      = shift;
    my $kiwi      = $this->{kiwi};
    my $xml       = $this->{xml};
    my $vconf     = $xml -> getVMachineConfig();
    my $xendomain;
    my $kernname = "vmlinuz";
    if (-f "$imageTree/boot/vmlinux") {
        $kernname = "vmlinux";
    }
    #
    # on s390x arch, kernel has /boot/image name
    # 
    if (-f "$imageTree/boot/image") {
        $kernname = "image";
    }
    if ($vconf) {
        $xendomain = $vconf -> getDomain();
    }
    if (-f "$imageTree/boot/$kernname") {
        $kiwi -> info ("Extracting kernel\n");
        #==========================================
        # setup file names / cleanup...
        #------------------------------------------
        my $pwd = KIWIQX::qxx ("pwd"); chomp $pwd;
        my $shortfile = "$name.kernel";
        my $file = "$dest/$shortfile";
        if ($file !~ /^\//) {
            $file = $pwd."/".$file;
        }
        if (-e $file) {
            KIWIQX::qxx ("rm -f $file");
        }
        # /.../
        # the KIWIConfig::suseStripKernel() function provides the
        # kernel as common name /boot/vmlinuz so we use this file
        # for the extraction
        # ----
        my $src_kernel = "$imageTree/boot/$kernname";
        if (! -e $src_kernel) {
            $kiwi -> error  ("--> Can't find kernel for extraction: $!");
            $kiwi -> failed ();
            return;
        }
        KIWIQX::qxx ("cp $src_kernel $file");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  ("--> Failed to extract kernel: $!");
            $kiwi -> failed ();
            return;
        }
        my $kernel = KIWIQX::qxx ("kversion $file");
        chomp $kernel;
        if ($kernel eq "") {
            $kernel = "no-version-found";
        }
        KIWIQX::qxx (
            "mv -f $file $file.$kernel && ln -s $shortfile.$kernel $file"
        );
        $kiwi -> info("--> Found $kernel");
        $kiwi -> done();
        $this -> buildMD5Sum ("$shortfile.$kernel");
        # /.../
        # check for the Xen hypervisor and extract them as well
        # ----
        if ((defined $xendomain) && ($xendomain eq "dom0")) {
            if (! -f "$imageTree/boot/xen.gz") {
                $kiwi -> error  ("Xen dom0 requested but no hypervisor found");
                $kiwi -> failed ();
                return;
            }
        }
        if (-f "$imageTree/boot/xen.gz") {
            $file = "$dest/$name.kernel-xen";
            KIWIQX::qxx ("cp $imageTree/boot/xen.gz $file");
            KIWIQX::qxx ("mv $file $file.$kernel.'gz'");
        }
        KIWIQX::qxx ("rm -rf $imageTree/boot/*");
    }
    else {
        $kiwi -> warning  ("--> Can't find kernel for extraction: " .
                           "did you call suseStripKernel?");
        $kiwi -> skipped ();
    }
    return $name;
}

#==========================================
# setupEXT2
#------------------------------------------
sub setupEXT2 {
    my $this    = shift;
    my $name    = shift;
    my $journal = shift;
    my $device  = shift;
    my $cmdL    = $this->{cmdL};
    my $kiwi    = $this->{kiwi};
    my $xml     = $this->{xml};
    my $xmltype = $xml -> getImageType();
    my $fsOpts = $cmdL -> getFilesystemOptions();
    my $createArgs = $fsOpts -> getOptionsStrExt();
    my $tuneopts = $fsOpts -> getTuneOptsExt();
    my $fstool;
    my $target = "$this->{imageDest}/$name";
    if ((defined $journal) && ($journal eq "journaled-ext3")) {
        $fstool = "mkfs.ext3";
    } elsif ((defined $journal) && ($journal eq "journaled-ext4")) {
        $fstool = "mkfs.ext4";
    } else {
        $fstool = "mkfs.ext2";
    }
    if ($this->{inodes}) {
        $createArgs .= " -N $this->{inodes}";
    }
    my $fsnocheck = $xmltype -> getFSNoCheck();
    if (($fsnocheck) && ($fsnocheck eq 'true')) {
        if ($tuneopts) {
            $kiwi -> info ('Overwrite ext tune options to nocheck per XML');
        }
        $tuneopts = " -c 0 -i 0";
    }
    if ($device) {
        $target = $device;
    }
    my $data = KIWIQX::qxx ("$fstool $createArgs $target 2>&1");
    my $code = $? >> 8;
    if (!$code && $tuneopts) {
        $data = KIWIQX::qxx ("/sbin/tune2fs $tuneopts $target 2>&1");
        $code = $? >> 8;
    }
    if ($code != 0) {
        $kiwi -> error  ("Couldn't create EXT2 filesystem");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    if ($device) {
        KIWIQX::qxx ("touch $this->{imageDest}/$name");
    }
    $this -> restoreImageDest();
    if ((defined $journal) && ($journal eq "journaled-ext3")) {
        $data = KIWIQX::qxx (
            "cd $this->{imageDest} && ln -vs $name $name.ext3 2>&1"
        );
    } elsif ((defined $journal) && ($journal eq "journaled-ext4")) {
        $data = KIWIQX::qxx (
            "cd $this->{imageDest} && ln -vs $name $name.ext4 2>&1"
        );
    } else {
        $data = KIWIQX::qxx (
            "cd $this->{imageDest} && ln -vs $name $name.ext2 2>&1"
        );
    }
    $this -> remapImageDest();
    $kiwi -> loginfo ($data);
    return $name;
}

#==========================================
# setupBTRFS
#------------------------------------------
sub setupBTRFS {
    my $this   = shift;
    my $name   = shift;
    my $device = shift;
    my $cmdL   = $this->{cmdL};
    my $kiwi   = $this->{kiwi};
    my $fsOpts = $cmdL -> getFilesystemOptions();
    my $createArgs = $fsOpts -> getOptionsStrBtrfs();
    my $target = "$this->{imageDest}/$name";
    if ($device) {
        $target = $device;
    }
    my $data = KIWIQX::qxx (
        "/sbin/mkfs.btrfs $createArgs $target 2>&1"
    );
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't create BTRFS filesystem");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    if ($device) {
        KIWIQX::qxx ("touch $this->{imageDest}/$name");
    }
    $this -> restoreImageDest();
    $data = KIWIQX::qxx (
        "cd $this->{imageDest} && ln -vs $name $name.btrfs 2>&1"
    );
    $this -> remapImageDest();
    $kiwi -> loginfo ($data);
    return $name;
}

#==========================================
# setupReiser
#------------------------------------------
sub setupReiser {
    my $this   = shift;
    my $name   = shift;
    my $device = shift;
    my $cmdL   = $this->{cmdL};
    my $kiwi   = $this->{kiwi};
    my $fsOpts = $cmdL -> getFilesystemOptions();
    my $createArgs = $fsOpts -> getOptionsStrReiser();
    my $target = "$this->{imageDest}/$name";
    if ($device) {
        $target = $device;
    }
    $createArgs .= "-f";
    my $data = KIWIQX::qxx (
        "/sbin/mkreiserfs $createArgs $target 2>&1"
    );
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't create Reiser filesystem");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    if ($device) {
        KIWIQX::qxx ("touch $this->{imageDest}/$name");
    }
    $this -> restoreImageDest();
    $data = KIWIQX::qxx (
        "cd $this->{imageDest} && ln -vs $name $name.reiserfs 2>&1"
    );
    $this -> remapImageDest();
    $kiwi -> loginfo ($data);
    return $name;
}

#==========================================
# setupSquashFS
#------------------------------------------
sub setupSquashFS {
    my $this    = shift;
    my $name    = shift;
    my $tree    = shift;
    my $opts    = shift;
    my $kiwi    = $this->{kiwi};
    my $xml     = $this->{xml};
    my $xmltype = $xml -> getImageType(); 
    my $imageTree = $this->{imageTree};
    my $locator = KIWILocator -> instance();
    if (! defined $tree) {
        $tree = $imageTree;
    }
    my $luks = $xmltype -> getLuksPass();
    my $dist = $xmltype -> getLuksOS();
    if ($luks) {
        $this -> restoreImageDest();
    }
    if (! $opts) {
        $opts = "";
    }
    unlink ("$this->{imageDest}/$name");
    my $squashfs_tool = $locator -> getExecPath("mksquashfs");
    my $data = KIWIQX::qxx (
        "$squashfs_tool $tree $this->{imageDest}/$name $opts 2>&1"
    );
    my $code = $? >> 8; 
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create squashfs filesystem");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    #==========================================
    # Check for LUKS extension
    #------------------------------------------
    if ($luks) {
        my $outimg = $this->{imageDest}."/".$name;
        my $squashimg = $outimg.".squashfs";
        my $cipher = "$luks";
        my $data = KIWIQX::qxx ("mv $outimg $squashimg 2>&1");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error ("Failed to rename squashfs image");
            $kiwi -> failed ();
            return;
        }
        my $bytes = int ((-s $squashimg) * 1.1);
        $data = KIWIQX::qxx (
            "dd if=/dev/zero of=$outimg bs=1 seek=$bytes count=1 2>&1"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error ("Failed to create luks loop container");
            $kiwi -> failed ();
            return;
        }
        if (! $this -> setupEncoding($name.".squashfs",$outimg,$cipher,$dist)) {
            return;
        }
        $data = KIWIQX::qxx (
            "dd if=$squashimg of=$this->{imageDest}/$name.squashfs 2>&1"
        );
        $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error ("Failed to dump squashfs to luks loop: $data");
            $kiwi -> failed ();
            $this -> cleanLuks();
            return;
        }
    }
    $this -> restoreImageDest();
    $data = KIWIQX::qxx ("chmod 644 $this->{imageDest}/$name");
    $data = KIWIQX::qxx ("rm -f $this->{imageDest}/$name.squashfs");
    $data = KIWIQX::qxx (
        "cd $this->{imageDest} && ln -vs $name $name.squashfs 2>&1"
    );
    $this -> remapImageDest();
    $kiwi -> loginfo ($data);
    return $name;
}

#==========================================
# setupZFS
#------------------------------------------
sub setupZFS {
    my $this   = shift;
    my $name   = shift;
    my $device = shift;
    my $cmdL   = $this->{cmdL};
    my $kiwi   = $this->{kiwi};
    my $target = $this->{imageDest}."/".$name;
    my $opts   = $this->{xml} -> getImageType() -> getFSMountOptions();
    my $zfsopts= $this->{xml} -> getImageType() -> getZFSOptions();
    my $data;
    if ($device) {
        $target = $device;
    }
    if ($opts) {
        $data = KIWIQX::qxx ("zpool create $opts kiwipool $target 2>&1");
    } else {
        $data = KIWIQX::qxx ("zpool create kiwipool $target 2>&1");
    }
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't create ZFS filesystem");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    if (! KIWIGlobals -> instance() -> createZFSPool($zfsopts)) {
        return;
    }
    if ($device) {
        KIWIQX::qxx ("touch $this->{imageDest}/$name");
    }
    $this -> restoreImageDest();
    $data = KIWIQX::qxx (
        "cd $this->{imageDest} && ln -vs $name $name.zfs 2>&1"
    );
    $this -> remapImageDest();
    $kiwi -> loginfo ($data);
    return $name;
}

#==========================================
# setupXFS
#------------------------------------------
sub setupXFS {
    my $this   = shift;
    my $name   = shift;
    my $device = shift;
    my $cmdL   = $this->{cmdL};
    my $kiwi   = $this->{kiwi};
    my $fsOpts = $cmdL -> getFilesystemOptions();
    my $createArgs = $fsOpts -> getOptionsStrXFS();
    my $target = $this->{imageDest}."/".$name;
    if ($device) {
        $target = $device;
    }
    my $data = KIWIQX::qxx (
        "/sbin/mkfs.xfs $createArgs $target 2>&1"
    );
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Couldn't create XFS filesystem");
        $kiwi -> failed ();
        $kiwi -> error  ($data);
        return;
    }
    if ($device) {
        KIWIQX::qxx ("touch $this->{imageDest}/$name");
    }
    $this -> restoreImageDest();
    $data = KIWIQX::qxx (
        "cd $this->{imageDest} && ln -vs $name $name.xfs 2>&1"
    );
    $this -> remapImageDest();
    $kiwi -> loginfo ($data);
    return $name;
}

#==========================================
# buildMD5Sum
#------------------------------------------
sub buildMD5Sum {
    my $this = shift;
    my $name = shift;
    my $kiwi = $this->{kiwi};
    my $initCache = $this->{initCache};
    my $image = $this->{imageDest}."/".$name;
    my $suf = $this->{gdata}->{IrdZipperSuffix};
    if ($this->{targetDevice}) {
        $image = $this->{targetDevice};
    }
    #==========================================
    # Skip this in init cache mode
    #------------------------------------------
    if (defined $initCache) {
        $name =~ s/\.$suf$//;
        return $name;
    }
    #==========================================
    # Create image md5sum
    #------------------------------------------
    $kiwi -> info ("Creating image MD5 sum...");
    my $size = int KIWIGlobals -> instance() -> isize ($image);
    my $primes = KIWIQX::qxx ("factor $size");
    $primes =~ s/^.*: //;
    my $blocksize = 1;
    for my $factor (split /\s/,$primes) {
        my $iFact = int $factor;
        if ($blocksize * $iFact > 65464) {
            last;
        }
        $blocksize *= $iFact;
    }
    my $blocks = $size / $blocksize;
    my $sum  = KIWIQX::qxx ("cat $image | md5sum - | cut -f 1 -d-");
    chomp $sum;
    $name =~ s/\.$suf$//;
    KIWIQX::qxx (
        "echo \"$sum $blocks $blocksize\" > $this->{imageDest}/$name.md5"
    );
    $this->{md5file} = $this->{imageDest}."/".$name.".md5";
    $kiwi -> done();
    return $name;
}

#==========================================
# restoreCDRootData
#------------------------------------------
sub restoreCDRootData {
    my $this = shift;
    my $imageTree    = $this->{imageTree};
    my $cdrootData   = "config-cdroot.tgz";
    my $cdrootScript = "config-cdroot.sh";
    if (-f $this->{imageDest}."/".$cdrootData) {
        KIWIQX::qxx ("mv $this->{imageDest}/$cdrootData $imageTree/image");
    }
    if (-f $this->{imageDest}."/".$cdrootScript) {
        KIWIQX::qxx ("mv $this->{imageDest}/$cdrootScript $imageTree/image");
    }
    return;
}

#==========================================
# restoreSplitExtend
#------------------------------------------
sub restoreSplitExtend {
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $imageTreeReadOnly = $this->{imageTreeReadOnly};
    my $imageTree = $this->{imageTree};
    if ((! defined $imageTreeReadOnly) || ( ! -d $imageTreeReadOnly)) {
        return $imageTreeReadOnly;
    }
    $kiwi -> info ("Restoring physical extend...");
    my @rodirs = qw (bin boot lib lib64 opt sbin usr);
    foreach my $dir (@rodirs) {
        if (! -d "$imageTreeReadOnly/$dir") {
            next;
        }
        my $data = KIWIQX::qxx ("mv $imageTreeReadOnly/$dir $imageTree 2>&1");
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Couldn't restore physical extend: $data");
            $kiwi -> failed ();
            return;
        }
    }
    $kiwi -> done();
    rmdir  $imageTreeReadOnly;
    return $imageTreeReadOnly;
}

#==========================================
# compressImage
#------------------------------------------
sub compressImage {
    my $this   = shift;
    my $name   = shift;
    my $fstype = shift;
    my $kiwi   = $this->{kiwi};
    my $image = $this->{imageDest}."/".$name;
    if ($this->{targetDevice}) {
        $image = $this->{targetDevice};
    }
    #==========================================
    # Compress image using gzip
    #------------------------------------------
    $kiwi -> info ("Compressing image...");
    my $suf = $this->{gdata}->{IrdZipperSuffix};
    my $zip = $this->{gdata}->{IrdZipperCommand};
    my $data = KIWIQX::qxx (
        "cat $image | $zip > $this->{imageDest}/$name.$suf"
    );
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error ("Compressing image failed: $!");
        $kiwi -> failed ();
        return;
    }
    $kiwi -> done();
    $this -> updateMD5File ("$this->{imageDest}/$name.$suf");
    #==========================================
    # Relink filesystem link to comp image file
    #------------------------------------------
    my $fslink = $this->{imageDest}."/".$name.".".$fstype;
    if (-l $fslink) {
        KIWIQX::qxx ("rm -f $fslink 2>&1");
        KIWIQX::qxx ("ln -vs $this->{imageDest}/$name.$suf $fslink 2>&1");
    }
    return $name;
}

#==========================================
# updateMD5File
#------------------------------------------
sub updateMD5File {
    my $this = shift;
    my $image= shift;
    my $kiwi = $this->{kiwi};
    #==========================================
    # Update md5file adding zblocks/zblocksize
    #------------------------------------------
    if (defined $this->{md5file}) {
        $kiwi -> info ("Updating md5 file...");
        my $FD;
        if (! open ($FD, '<', $this->{md5file})) {
            $kiwi -> failed ();
            $kiwi -> error ("Failed to open md5 file: $!");
            $kiwi -> failed ();
            return;
        }
        my $line = <$FD>;
        close $FD;
        chomp $line;
        my $size = KIWIGlobals -> instance() -> isize ($image);
        my $primes = KIWIQX::qxx ("factor $size"); $primes =~ s/^.*: //;
        my $blocksize = 1;
        for my $factor (split /\s/,$primes) {
            last if ($blocksize * $factor > 65464);
            $blocksize *= $factor;
        }
        my $blocks = $size / $blocksize;
        my $md5file= $this->{md5file};
        KIWIQX::qxx ("echo \"$line $blocks $blocksize\" > $md5file");
        $kiwi -> done();
    }
    return $this;
}

#==========================================
# getNumInodes
#------------------------------------------
sub getNumInodes {
    # ...
    # Return the number of inodes used for the unpacked image tree
    # ---
    my $this = shift;
    my $unpackedTree = $this->{imageTree};
    my $iCnt = KIWIQX::qxx ("find $unpackedTree | wc -l");
    chomp $iCnt;
    return $iCnt;
}

#==========================================
# getInstalledSize
#------------------------------------------
sub getInstalledSize {
    # ...
    # Return the size of the unpacked image tree in Bytes
    # ---
    my $this = shift;
    return KIWIGlobals -> instance() -> dsize ($this->{imageTree});
}

#==========================================
# getSize
#------------------------------------------
sub getSize {
    # ...
    # calculate size of the logical extend. The
    # method returns the size value in MegaByte
    # ---
    my $this    = shift;
    my $extend  = shift;
    my $kiwi    = $this->{kiwi};
    my $cmdL    = $this->{cmdL};
    my $xml     = $this->{xml};
    my $mini    = KIWIQX::qxx ("find $extend | wc -l"); chomp $mini;
    my $minsize = KIWIGlobals -> instance() -> dsize ($extend);
    my $spare   = 100 * 1024 * 1024;
    my $files   = $mini;
    my $fsopts  = $cmdL -> getFilesystemOptions();
    my $isize   = $fsopts -> getInodeSize();
    my $iratio  = $fsopts -> getInodeRatio();
    my $xmltype = $xml -> getImageType();
    my $fstype  = $xmltype -> getTypeName();
    my $xmlfs   = $xmltype -> getFilesystem();
    my $xmlsize;
    if ($xmlfs) {
        $fstype .= ":$xmlfs";
    }
    $minsize = sprintf ("%.0f",$minsize);
    #==========================================
    # Double minimum inode count
    #------------------------------------------
    $mini *= 2;
    #==========================================
    # Minimum size calculated in Byte
    #------------------------------------------
    $kiwi -> loginfo ("getSize: files: $files\n");
    $kiwi -> loginfo ("getSize: usage: $minsize Bytes\n");
    if ($fstype =~ /btrfs/) {
        my $fsohead= 2.0;
        $kiwi -> loginfo ("getSize: multiply by $fsohead\n");
        $minsize *= $fsohead;
    } else {
        my $fsohead= 1.4;
        $kiwi -> loginfo ("getSize: inode: $isize Bytes\n");
        $minsize *= $fsohead;
        $minsize += $mini * $isize;
        $minsize = sprintf ("%.0f",$minsize);
    }
    $minsize+= $spare;
    $kiwi -> loginfo ("getSize: minsz: $minsize Bytes\n");
    #==========================================
    # XML size calculated in Byte
    #------------------------------------------
    my $additive = $xml -> getImageType() -> getImageSizeAdditiveBytes();
    if ($additive) {
        # relative size value specified...
        $xmlsize = $minsize + $additive;
    } else {
        # absolute size value specified...
        $xmlsize = $xml -> getImageType() -> getImageSize();
        if ($xmlsize eq "auto") {
            $xmlsize = $minsize;
        } elsif ($xmlsize =~ /^(\d+)([MG])$/i) {
            my $value= $1;
            my $unit = $2;
            if ($unit eq "G") {
                # convert GB to MB...
                $value *= 1024;
            }
            # convert MB to Byte
            $xmlsize = $value * 1048576;
            # check the size value with what kiwi thinks is the minimum
            if ($xmlsize < $minsize) {
                my $s1 = sprintf ("%.0f", $minsize / 1048576);
                my $s2 = sprintf ("%.0f", $xmlsize / 1048576);
                $kiwi -> warning (
                    "--> given xml size might be too small, using it anyhow!\n"
                );
                $kiwi -> warning (
                    "--> min size changed from $s1 to $s2 MB\n"
                );
                $minsize = $xmlsize;
            }
        }
    }
    #==========================================
    # Setup used size and inodes, prefer XML
    #------------------------------------------
    my $usedsize = $minsize;
    if ($xmlsize > $minsize) {
        $usedsize = $xmlsize;
        $this->{inodes} = sprintf ("%.0f",$usedsize / $iratio);
    } else {
        $this->{inodes} = $mini;
    }
    #==========================================
    # return result list in MB
    #------------------------------------------
    $minsize = sprintf ("%.0f",$minsize  / 1048576);
    $usedsize= sprintf ("%.0f",$usedsize / 1048576);
    $usedsize.= "M";
    return ($minsize,$usedsize);
}

#==========================================
# checkKernel
#------------------------------------------
sub checkKernel {
    # ...
    # this function receives two parameters. The initrd image
    # file and the system image tree directory path. It checks
    # whether at least one kernel matches both, the initrd and
    # the system image. If not the function returns with an
    # error
    # ---
    my $this    = shift;
    my $initrd  = shift;
    my $systree = shift;
    my $name    = shift;
    my $kiwi    = $this->{kiwi};
    my $zipper  = $this->{gdata}->{IrdZipperCommand};
    my $suf     = $this->{gdata}->{IrdZipperSuffix};
    my %sysk    = ();
    my %bootk   = ();
    my $status;
    my $tmpdir;
    #==========================================
    # find system image kernel(s)
    #------------------------------------------
    foreach my $dir (glob ("$systree/lib/modules/*")) {
        if ($dir =~ /-debug$/) {
            next;
        }
        $dir =~ s/$systree\///;
        $sysk{$dir} = "system-kernel";
    }
    if (! %sysk) {
        $kiwi -> error  ("Can't find any system image kernel");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # find boot image kernel
    #------------------------------------------
    my $cmd = "cat $initrd";
    my $zip = 0;
    if ($initrd =~ /\.(g|x)z$/) {
        $cmd = "$zipper -cd $initrd";
        $zip = 1;
    }
    $status = KIWIQX::qxx (
        "$cmd|cpio -it --quiet 'lib/modules/*'|cut -f1-3 -d/"
    );
    my $result = $? >> 8;
    my @status = split(/\n/,$status);
    if ($result != 0) {
        $kiwi -> error  ("Can't find any boot image kernel");
        $kiwi -> failed ();
        return;
    }
    foreach my $module (@status) {
        chomp $module;
        $bootk{$module} = "boot-kernel";
    }
    if (! %bootk) {
        $kiwi -> error  ("Can't find any boot image kernel");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # search system image kernel in initrd 
    #------------------------------------------
    foreach my $system (keys %sysk) {
        if ($bootk{$system}) {
            # found system image kernel in initrd, ok
            return $this;
        }
    }
    #==========================================
    # no kernel matches the one in the initrd
    #------------------------------------------
    $kiwi -> error  (
        "Can't find any system kernel matching the initrd"
    );
    $kiwi -> failed ();
    return;
}

#==========================================
# cleanLuks
#------------------------------------------
sub cleanLuks {
    my $this = shift;
    my $loop = $this->{luksloop};
    my $name = $this->{luksname};
    if ($name) {
        foreach my $luks (@{$name}) {
            KIWIQX::qxx ("cryptsetup luksClose $luks 2>&1");
        }
    }
    if ($loop) {
        foreach my $ldev (@{$loop}) {
            KIWIGlobals -> instance() -> loop_delete($ldev);
        }
    }
    return;
}

#==========================================
# restoreImageDest
#------------------------------------------
sub restoreImageDest {
    my $this = shift;
    if ($this->{imageDestOrig}) {
        $this->{imageDest} = $this->{imageDestOrig};
    }
    return;
}

#==========================================
# remapImageDest
#------------------------------------------
sub remapImageDest {
    my $this = shift;
    if ($this->{imageDestMap}) {
        $this->{imageDest} = $this->{imageDestMap};
    }
    return;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
    my $this  = shift;
    my $kiwi  = $this->{kiwi};
    my $stack = $this->{UmountStack};
    if (! $stack) {
        return;
    }
    my @UmountStack = @{$stack};
    my $status;
    my $result;
    foreach my $cmd (reverse @UmountStack) {
        $status = KIWIQX::qxx ("$cmd 2>&1");
        $result = $? >> 8;
        if ($result != 0) {
            $kiwi -> warning ("UmountStack failed: $cmd: $status\n");
        }
    }
    $this->{UmountStack} = [];
    return;
}

#==========================================
# cleanKernelFSMount
#------------------------------------------
sub cleanKernelFSMount {
    my $this = shift;
    my @kfs  = ("/proc/sys/fs/binfmt_misc","/proc","/dev/pts","/sys");
    foreach my $system (@kfs) {
        KIWIQX::qxx ("umount $this->{imageTree}/$system 2>&1");
    }
    return;
}

#==========================================
# extractCPIO
#------------------------------------------
sub extractCPIO {
    my $this = shift;
    my $file = shift;
    my $FD = FileHandle -> new();
    if (! $FD -> open ($file)) {
        return 0;
    }
    local $/;
    my $data = <$FD>;
    $FD -> close();
    my @data   = split (//,$data);
    my $stream = "";
    my $count  = 0;
    my $start  = 0;
    my $pos1   = -1;
    my $pos2   = -1;
    my @index;
    while (1) {
        my $pos1 = index ($data,"TRAILER!!!",$start);
        if ($pos1 >= $start) {
            $pos2 = index ($data,"07070",$pos1);
        } else {
            last;
        }
        if ($pos2 >= $pos1) {
            $pos2--;
            push (@index,$pos2);
            #print "$start -> $pos2\n";
            $start = $pos2;
        } else {
            $pos2 = @data; $pos2--;
            push (@index,$pos2);
            #print "$start -> $pos2\n";
            last;
        }
    }
    for (my $i=0;$i<@data;$i++) {
        $stream .= $data[$i];
        if ($i == $index[$count]) {
            $count++;
            my $FD = FileHandle -> new();
            if (! $FD -> open (">$file.$count")) {
                return 0;
            }
            print $FD $stream;
            $FD -> close();
            $stream = "";
        }
    }
    return $count;
}

#==========================================
# makeLabel
#------------------------------------------
sub makeLabel {
    # ...
    # isolinux handles spaces as "_", so we replace
    # each space with an underscore
    # ----
    my $this = shift;
    my $label = shift;
    $label =~ s/ /_/g;
    return $label;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
    my $this = shift;
    my $dirs = $this->{tmpdirs};
    my $imageDest = $this->{imageDest};
    if ($imageDest) {
        my $spldir    = $imageDest."/splash";
        foreach my $dir (@{$dirs}) {
            KIWIQX::qxx ("rm -rf $dir 2>&1");
        }
        if (-d $spldir) {
            KIWIQX::qxx ("rm -rf $spldir 2>&1");
        }
        $this -> cleanMount();
        $this -> cleanLuks();
    }
    return $this;
}

1;

# vim: set noexpandtab:
