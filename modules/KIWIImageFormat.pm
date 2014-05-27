#================
# FILE          : KIWIImageFormat.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide methods for
#               : creating image output formats based on the
#               : raw output file like vmdk, ovf, hyperV
#               : and more
#               :
#               :
# STATUS        : Development
#----------------
package KIWIImageFormat;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use FileHandle;
use File::Basename;
use JSON;
#==========================================
# KWIW Modules
#------------------------------------------
use KIWIBoot;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIImageFormat object which is used
	# to gather information required for the format conversion
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters [ mandatory ]
	#------------------------------------------
	my $image  = shift;
	my $cmdL   = shift;
	#==========================================
	# Module Parameters [ optional ]
	#------------------------------------------
	my $format = shift;
	my $xml    = shift;
	my $tdev   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $code;
	my $data;
	#==========================================
	# Store object data
	#------------------------------------------
	my $global = KIWIGlobals -> instance();
	$this->{gdata} = $global -> getKiwiConfig();
	#==========================================
	# check image file
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if ((! $this->{gdata}->{StudioNode}) && (! (-f $image || -b $image))) {
		$kiwi -> error ("no such image file: $image");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# read XML if required
	#------------------------------------------
	if (! defined $xml) {
		my $boot = KIWIBoot -> new (
			undef,$cmdL,$image,undef,undef,
			$cmdL->getBuildProfiles()
		);
		if ($boot) {
			$xml = $boot->{xml};
			$boot -> cleanStack ();
		}
		if (! defined $xml) {
			$kiwi -> error  ("Can't load XML configuration, not an image ?");
			$kiwi -> failed ();
			return;
		}
	}
	my $type = $xml  -> getImageType();
	#==========================================
	# get build type
	#------------------------------------------
	my $imgtype = $type -> getTypeName();
	#==========================================
	# get format
	#------------------------------------------
	my $xmlformat = $type -> getFormat();
	if ($xmlformat) {
		$format = $xmlformat;
	}
	#==========================================
	# check for guid in vhd-fixed format
	#------------------------------------------
	my $guid = $type -> getVHDFixedTag();
	#==========================================
	# get boot profile
	#------------------------------------------
	my $bootp = $type -> getBootProfile();
	#==========================================
	# get machine configuration
	#------------------------------------------
	my $vconf = $xml -> getVMachineConfig();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{cmdL}    = $cmdL;
	$this->{vmdata}  = $vconf;
	$this->{kiwi}    = $kiwi;
	$this->{xml}     = $xml;
	$this->{format}  = $format;
	$this->{image}   = $image;
	$this->{bootp}   = $bootp;
	$this->{guid}    = $guid;
	$this->{imgtype} = $imgtype;
	$this->{targetDevice} = $tdev;
	return $this;
}

#==========================================
# createFormat
#------------------------------------------
sub createFormat {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $image  = $this->{image};
	my $imgtype= $this->{imgtype};
	my $targetDevice = $this->{targetDevice};
	#==========================================
	# convert disk into specified format
	#------------------------------------------
	if (($this->{gdata}->{StudioNode}) && ($format ne "ec2")) {
		$kiwi -> warning ("Format conversion skipped in targetstudio mode");
		$kiwi -> skipped ();
		return $this;
	}
	#==========================================
	# check for target device or file
	#------------------------------------------
	if (($targetDevice) && (-b $targetDevice)) {
		$image = $targetDevice;
	}
	#==========================================
	# check if format is a disk
	#------------------------------------------
	if (! defined $format) {
		$kiwi -> warning ("No format for $imgtype conversion specified");
		$kiwi -> skipped ();
		return $this;
	} else {
		my $data = KIWIQX::qxx ("parted $image print 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("system image is not a disk or filesystem");
			$kiwi -> failed ();
			return
		}
	}
	if ($format eq "vagrant") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVagrantBox();
	} elsif ($format eq "vmdk") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVMDK();
	} elsif ($format eq "vhd") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVHD();
	} elsif ($format eq "vdi") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVDI();
	} elsif ($format eq "vhd-fixed") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVHDSubFormatFixed()
	} elsif ($format eq "ovf") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createOVF();
	} elsif ($format eq "ova") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createOVA();
	} elsif ($format eq "qcow2") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createQCOW2();
	} else {
		$kiwi -> warning (
			"Can't convert image type $imgtype to $format format"
		);
		$kiwi -> skipped ();
	}
	return;
}

#==========================================
# createMachineConfiguration
#------------------------------------------
sub createMachineConfiguration {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $imgtype= $this->{imgtype};
	my $xml    = $this->{xml};
	my $bootp  = $this->{bootp};
	my $vconf  = $this->{vmdata};
	if ((! $vconf) && ($format =~ /qcow2|vagrant/)) {
		# a machine configuration doesn't make sense with these
		# formats requested. Thus we can silently return here
		return;
	}
	my $xend = $vconf -> getDomain();
	if (! $xend) {
		$xend = "dom0";
	}
	if ($imgtype eq "iso") {
		$kiwi -> warning (
			"Can't create machine setup for selected $imgtype image type"
		);
		$kiwi -> skipped ();
		return;
	}
	if (($bootp) && ($bootp eq "xen") && ($xend eq "domU")) {
		$kiwi -> info ("Creating $imgtype image machine configuration\n");
		return $this -> createXENConfiguration();
	} elsif ($format eq "vmdk") {
		$kiwi -> info ("Creating $imgtype image machine configuration\n");
		return $this -> createVMwareConfiguration();
	} elsif (($format eq "ovf") || ($format eq "ova")) {
		my $ovftype = $vconf -> getOVFType();
		if (($ovftype) && ($ovftype eq "vmware")) {
			$kiwi -> info ("Creating vmdk image machine configuration\n");
			if (! $this -> createVMwareConfiguration()) {
				return;
			}
		}
		$kiwi -> info ("Creating $imgtype image machine configuration\n");
		return $this -> createOVFConfiguration();
	} else {
		$kiwi -> warning (
			"Can't create machine setup for selected $imgtype image type"
		);
		$kiwi -> skipped ();
	}
	return;
}

#==========================================
# createOVA
#------------------------------------------
sub createOVA {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my $format = $this->{format};
	#==========================================
	# requires ovf to operate
	#------------------------------------------
	my $ovfdir = $this -> createOVF();
	if (! $ovfdir) {
		return;
	}
	return $ovfdir;
}

#==========================================
# createOVF
#------------------------------------------
sub createOVF {
	my $this   = shift;
	my $image  = $this->{image};
	my $cmdl   = $this->{cmdL};
	#==========================================
	# create vmdk for VMware, required for ovf
	#------------------------------------------
	my $vmdata = $this->{vmdata};
	my $ovftype = $vmdata -> getOVFType();
	if ($ovftype eq "vmware") {
		my $origin_format = $this->{format};
		$this->{format} = "vmdk";
		$image = $this->createVMDK();
		if (! $image) {
			return;
		}
		$this->{format} = $origin_format;
		$this->{image}  = $image;
	}
	#==========================================
	# prepare ovf destination directory
	#------------------------------------------
	my $ovfdir = $image;
	if ($ovftype eq "vmware") {
		$ovfdir =~ s/\.vmdk$/\.ovf/;
	} else {
		$ovfdir =~ s/\.raw$/\.ovf/;
	}
	if (-d $ovfdir) {
		KIWIQX::qxx ("rm -f $ovfdir/*");
	} else {
		KIWIQX::qxx ("mkdir -p $ovfdir");
	}
	my $img_base = basename $image;
	KIWIQX::qxx ("ln -s ../$img_base $ovfdir/$img_base");
	$this->{ovfdir} = $ovfdir;
	return $ovfdir;
}

#==========================================
# createVMDK
#------------------------------------------
sub createVMDK {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $source = $this->{image};
	my $vmdata = $this->{vmdata};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	my $diskCnt;
	my $diskMode;
	if ($vmdata) {
		$diskCnt  = $vmdata -> getSystemDiskController();
		$diskMode = $vmdata -> getSystemDiskMode();
	}
	$kiwi -> info ("Creating $format image...");
	$target  =~ s/\.raw$/\.$format/;
	$convert = "convert -f raw $source -O $format";
	if (($format ne 'ovf') && ($format ne 'ova')) {
		# /.../
		# if the format is set to ova/ovf the format parameters
		# are stored in the ovf configuration and not inside the
		# vmdk format. Thus we skip the format parameters in this
		# case
		# -----
		if (($diskCnt) && ($diskCnt ne 'ide')) {
			$convert .= " -o adapter_type=$diskCnt";
		}
		if ($diskMode) {
			$convert .= " -o subformat=$diskMode";
		}
	}
	$status = KIWIQX::qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create $format image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createVDI
#------------------------------------------
sub createVDI {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating $format image...");
	$target  =~ s/\.raw$/\.$format/;
	$convert = "convert -f raw $source -O $format";
	$status = KIWIQX::qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create $format image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createVHD
#------------------------------------------
sub createVHD {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating vhd image...");
	$target  =~ s/\.raw$/\.vhd/;
	$convert = "convert -f raw $source -O vpc";
	$status = KIWIQX::qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create vhd image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createVHDSubFormatFixed
#------------------------------------------
sub createVHDSubFormatFixed {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $source = $this->{image};
	my $guid   = $this->{guid};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating vhd-fixed image...");
	$target  =~ s/\.raw$/\.vhdfixed/;
	$convert = "convert -f raw -O vpc -o subformat=fixed";
	$status = KIWIQX::qxx ("qemu-img $convert $source $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create vhd-fixed image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	if ($guid) {
		$kiwi -> info ("Saving VHD disk Tag: $guid");
		if (! $this -> writeVHDTag ($target,$guid)) {
			return;
		}
		$kiwi -> done();
	}
	return $target;
}

#==========================================
# createQCOW2
#------------------------------------------
sub createQCOW2 {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating qcow2 image...");
	$target  =~ s/\.raw$/\.qcow2/;
	$convert = "convert -c -f raw $source -O qcow2";
	$status = KIWIQX::qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create qcow2 image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createVagrantBox
#------------------------------------------
sub createVagrantBox {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $dest   = dirname  $this->{image};
	my $vgclist= $xml -> getVagrantConfig();
	my $desc   = $xml -> getDescriptionInfo();
	my $pref   = $xml -> getPreferences();
	my $img;
	my $fmt;
	my @boxes;
	if (! $vgclist) {
		$kiwi -> error  (
			"No vagrantconfig section(s) found"
		);
		$kiwi -> failed ();
		return;
	}
	foreach my $vgc (@{$vgclist}) {
		my $box = $this->{image};
		my $provider = $vgc -> getProvider();
		$kiwi -> info ("Creating vagrant box for $provider provider\n");
		#==========================================
		# create vagrant image
		#------------------------------------------
		if ($provider eq 'libvirt') {
			$this->{format} = 'qcow2';
			$img = $this -> createQCOW2();
			$fmt = 'qcow2';
		} elsif ($provider eq 'virtualbox') {
			$this->{format} = 'vmdk';
			$img = $this -> createVMDK();
			$fmt = 'vmdk';
		}
		$this->{format} = 'vagrant';
		if (! $img) {
			return;
		}
		$kiwi -> info ("--> Creating box metadata files");
		#==========================================
		# create vagrant metadata.json
		#------------------------------------------
		my $vsize = $vgc -> getVirtualSize();
		my $json_fd = FileHandle -> new();
		my $json_meta = $dest."/metadata.json";
		my $json_ref = JSON->new->allow_nonref;
		my %json_data;
		$json_data{provider} = $provider;
		$json_data{format} = $fmt;
		$json_data{virtual_size} = $vsize;
		$json_ref -> pretty;
		my $json_text = $json_ref ->encode( \%json_data );
		if (! $json_fd -> open (">$json_meta")) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"Couldn't create $json_meta file: $!"
			);
			$kiwi -> failed ();
			return;
		}
		print $json_fd $json_text;
		$json_fd -> close();
		#==========================================
		# create vagrant cloud configuration
		#------------------------------------------
		my $json_cloud = $box;
		$json_cloud =~ s/\.raw$/\.json/;
		$box =~ s/\.raw$/\.$provider\.box/;
		%json_data = ();
		my $versions = [];
		my $providers = [];
		$providers->[0]->{name} = $provider;
		$providers->[0]->{url} = basename $box;
		$versions->[0]->{version} = $pref -> getVersion();
		$versions->[0]->{providers} = $providers;
		$json_data{name} = $xml -> getImageName();
		$json_data{description} = $desc -> getSpecificationDescript();
		$json_data{description} =~ s/[\n\t]+//g;
		$json_data{versions} = $versions;
		$json_ref = JSON->new->allow_nonref;
		$json_ref -> pretty;
		$json_text = $json_ref ->encode( \%json_data );
		$json_fd = FileHandle -> new();
		if (! $json_fd -> open (">$json_cloud")) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"Couldn't create $json_cloud file: $!"
			);
			$kiwi -> failed ();
			return;
		}
		print $json_fd $json_text;
		$json_fd -> close();
		#==========================================
		# create vagrant Vagrantfile
		#------------------------------------------
		my $vagrant_meta = $dest."/Vagrantfile";
		my $vagrant_fd = FileHandle -> new();
		my $vagrant_mac= $this -> __randomMAC();
		if (! $vagrant_fd -> open (">$vagrant_meta")) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"Couldn't create Vagrantfile file: $!"
			);
			$kiwi -> failed ();
			return;
		}
		print $vagrant_fd 'Vagrant::Config.run do |config|'."\n";
		print $vagrant_fd '  config.vm.base_mac = "'.$vagrant_mac.'"'."\n";
		print $vagrant_fd 'end'."\n";
		print $vagrant_fd 'include_vagrantfile = ';
		print $vagrant_fd 'File.expand_path("../include/_Vagrantfile", ';
		print $vagrant_fd '__FILE__)'."\n";
		print $vagrant_fd 'load include_vagrantfile ';
		print $vagrant_fd 'if File.exist?(include_vagrantfile)'."\n";
		$vagrant_fd -> close();
		$kiwi -> done();
		#==========================================
		# package vagrant box
		#------------------------------------------
		$kiwi -> info ("--> Creating box archive");
		my $img_basename = basename $img;
		KIWIQX::qxx ("cd $dest && mv $img_basename box.img");
		my @components = ();
		push @components, basename $json_meta;
		push @components, basename $vagrant_meta;
		push @components, 'box.img';
		my $status = KIWIQX::qxx (
			"tar -C $dest -czf $box @components 2>&1"
		);
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"Couldn't create box tarball: $status"
			);
			$kiwi -> failed ();
			return;
		}
		push @boxes, $box;
		$kiwi -> done();
		#==========================================
		# cleanup
		#------------------------------------------
		KIWIQX::qxx ("rm -f $json_meta $vagrant_meta $dest/box.img");
	}
	return @boxes;
}

#==========================================
# createXENConfiguration
#------------------------------------------
sub createXENConfiguration {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $vmc    = $this->{vmdata};
	my $dest   = dirname  $this->{image};
	my $base   = basename $this->{image};
	my $format;
	my $file;
	$kiwi -> info ("Creating image Xen configuration file...");
	#==========================================
	# setup config file name from image name
	#------------------------------------------
	my $image = $base;
	if ($base =~ /(.*)\.(.*?)$/) {
		$image  = $1;
		$format = $2;
		$base   = $image.".xenconfig";
	}
	$file = $dest."/".$base;
	unlink $file;
	#==========================================
	# find kernel
	#------------------------------------------
	my $kernel;
	my $initrd;
	foreach my $k (glob ($dest."/*.kernel")) {
		if (-l $k) {
			$kernel = readlink ($k);
			$kernel = basename ($kernel);
			last;
		}
	}
	if (! -e "$dest/$kernel") {
		$kiwi -> skipped ();
		$kiwi -> warning ("Can't find kernel in $dest");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# find initrd
	#------------------------------------------
	foreach my $i (glob ($dest."/*.splash.gz")) {
		$initrd = $i;
		$initrd = basename ($initrd);
		last;
	}
	if (! -e "$dest/$initrd") {
		$kiwi -> skipped ();
		$kiwi -> warning ("Can't find initrd in $dest");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# check XML configuration data
	#------------------------------------------
	if ((! $vmc ) || (! defined $vmc -> getSystemDiskID())) {
		$kiwi -> skipped ();
		if (! $vmc) {
			$kiwi -> warning ("No machine section for this image type found");
		} else {
			$kiwi -> warning ("No disk device setup found in machine section");
		}
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# Create config file
	#------------------------------------------
	my $XENFD = FileHandle -> new();
	if (! $XENFD -> open (">$file")) {
		$kiwi -> skipped ();
		$kiwi -> warning  ("Couldn't create xenconfig file: $!");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $device = $vmc -> getSystemDiskDevice();
	$device =~ s/\/dev\///;
	my $part = $device."1";
	my $memory = $vmc -> getMemory();
	my $ncpus  = $vmc -> getNumCPUs();
	$image .= ".".$format;
	print $XENFD '#  -*- mode: python; -*-'."\n";
	print $XENFD "name=\"".$this->{xml}->getImageDisplayName()."\"\n";
	if ($memory) {
		print $XENFD 'memory='.$memory."\n";
	}
	if ($ncpus) {
		print $XENFD 'vcpus='.$ncpus."\n";
	}
	my $tap = $format;
	if ($tap eq "raw") {
		$tap = "aio";
	}
	print $XENFD 'disk=[ "tap:'.$tap.':'.$image.','.$device.',w" ]'."\n";
	#==========================================
	# network setup
	#------------------------------------------
	my $vifcount = -1;
	my @nIDs = @{$vmc -> getNICIDs()};
	for my $nID (@nIDs) {
		$vifcount++;
		my $mac   = $vmc -> getNICMAC ($nID);
		my $bname = $vmc -> getNICInterface ($nID);
		my $vif = '"bridge='.$bname.'"';
		if ($bname eq "undef") {
			$vif = '""';
		}
		if ($mac) {
			$vif = '"mac='.$mac.',bridge='.$bname.'"';
			if ($bname eq "undef") {
				$vif = '"mac='.$mac.'"';
			}
		}
		if ($vifcount == 0) {
			print $XENFD "vif=[ ".$vif;
		} else {
			print $XENFD ", ".$vif;
		}
	}
	if ($vifcount >= 0) {
		print $XENFD " ]"."\n";
	}
	#==========================================
	# Process raw config options
	#------------------------------------------
	my @userOptSettings;
	my $confEntries = $vmc -> getConfigEntries();
	if ($confEntries) {
		my @confEntries = @{$confEntries};
		for my $configOpt (@confEntries) {
			print $XENFD $configOpt . "\n";
			push @userOptSettings, (split /=/, $configOpt)[0];
		}
	}
	#==========================================
	# xen virtual framebuffer
	#------------------------------------------
	if (! grep {/vfb/} @userOptSettings) {
		print $XENFD 'vfb = ["type=vnc,vncunused=1,vnclisten=0.0.0.0"]'."\n";
	}
	$XENFD -> close();
	$kiwi -> done();
	return $file;
}

#==========================================
# createVMwareConfiguration
#------------------------------------------
sub createVMwareConfiguration {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $dest   = dirname  $this->{image};
	my $base   = basename $this->{image};
	my $file;
	$kiwi -> info ("Creating image VMware configuration file...");
	#==========================================
	# setup config file name from image name
	#------------------------------------------
	my $image = $base;
	if ($base =~ /(.*)\.(.*?)$/) {
		$image = $1;
		$base  = $image.".vmx";
	}
	$file = $dest."/".$base;
	unlink $file;
	#==========================================
	# check XML configuration data
	#------------------------------------------
	my $vmdata = $this->{vmdata};
	if (! $vmdata ) {
		$kiwi -> skipped ();
		$kiwi -> warning ('No machine section for this image type found');
		$kiwi -> skipped ();
		return $file;
	}
	my $diskController = $vmdata -> getSystemDiskController();
	if (! $diskController) {
		$kiwi -> skipped ();
		$kiwi -> warning ('No disk device setup found in machine section');
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# Create config file
	#------------------------------------------
	my $VMWFD = FileHandle -> new();
	if (! $VMWFD -> open (">$file")) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Couldn't create VMware config file: $!");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# global setup
	#------------------------------------------
	print $VMWFD '#!/usr/bin/env vmware'."\n";
	print $VMWFD 'config.version = "8"'."\n";
	print $VMWFD 'tools.syncTime = "true"'."\n";
	print $VMWFD 'uuid.action = "create"'."\n";
	my $hwVer = $vmdata -> getHardwareVersion();
	print $VMWFD 'virtualHW.version = "' . $hwVer . '"' . "\n";
	print $VMWFD 'displayName = "' . $image . '"' . "\n";
	my $memory = $vmdata -> getMemory();
	if ($memory) {
		print $VMWFD 'memsize = "' . $memory . '"' . "\n";
	}
	my $ncpus = $vmdata -> getNumCPUs();
	if ($ncpus) {
		print $VMWFD 'numvcpus = "' . $ncpus . '"' . "\n";
	}
	my $guest = $vmdata -> getGuestOS();
	print $VMWFD 'guestOS = "' . $guest . '"' . "\n";
	#==========================================
	# storage setup
	#------------------------------------------
	my $diskID = $vmdata -> getSystemDiskID();
	if (! $diskID) {
		$diskID = '0';
	}
	if ($diskController eq "ide") {
		my $device = $diskController . $diskID;
		# IDE Interface...
		print $VMWFD $device.':0.present = "true"'."\n";
		print $VMWFD $device.':0.fileName= "'.$image.'.vmdk"'."\n";
		print $VMWFD $device.':0.redo = ""'."\n";
	} else {
		# SCSI Interface...
		my $device = 'scsi' . $diskID;
		print $VMWFD $device.'.present = "true"'."\n";
		print $VMWFD $device.'.sharedBus = "none"'."\n";
		print $VMWFD $device.'.virtualDev = "' . $diskController . '"' . "\n";
		print $VMWFD $device.':0.present = "true"'."\n";
		print $VMWFD $device.':0.fileName = "'.$image.'.vmdk"'."\n";
		print $VMWFD $device.':0.deviceType = "scsi-hardDisk"'."\n";
	}
	#==========================================
	# network setup
	#------------------------------------------
	my @nicIds = @{$vmdata -> getNICIDs()};
	for my $id (@nicIds) {
		my $iFace = $vmdata -> getNICInterface($id);
		my $nic = "ethernet" . $iFace;
		print $VMWFD $nic . '.present = "true"' . "\n";
		my $mac = $vmdata -> getNICMAC($id);
		if ($mac) {
			print $VMWFD $nic . '.addressType = "static"' . "\n";
			print $VMWFD $nic . '.address = ' . "$mac\n";
		} else {
			print $VMWFD $nic . '.addressType = "generated"' . "\n";
		}
		my $driver = $vmdata -> getNICDriver($id);
		if ($driver) {
			print $VMWFD $nic . '.virtualDev = "' . $driver . '"' . "\n";
		}
		my $mode = $vmdata -> getNICMode($id);
		if ($mode) {
			print $VMWFD $nic . '.connectionType = "' . $mode . '"' . "\n";
		}
		my $arch = $vmdata -> getArch();
		if ($arch && $arch=~ /64$/smx) {
			print $VMWFD $nic.'.allow64bitVmxnet = "true"'."\n";
		}
	}
	#==========================================
	# CD/DVD drive setup
	#------------------------------------------
	my $cdtype = $vmdata -> getDVDController();
	my $cdid = $vmdata -> getDVDID();
	if ($cdtype && defined $cdid) {
		my $device = $cdtype . $cdid;
		print $VMWFD $device.':0.present = "true"'."\n";
		print $VMWFD $device.':0.deviceType = "cdrom-raw"'."\n";
		print $VMWFD $device.':0.autodetect = "true"'."\n";
		print $VMWFD $device.':0.startConnected = "true"'."\n";
	}
	#==========================================
	# Setup default options
	#------------------------------------------
	my %defaultOpts = (
		'usb.present'        => 'true',
		'priority.grabbed'   => 'normal',
		'priority.ungrabbed' => 'normal',
		'powerType.powerOff' => 'soft',
		'powerType.powerOn'  => 'soft',
		'powerType.suspend'  => 'soft',
		'powerType.reset'    => 'soft'
	);
	#==========================================
	# Process raw config options
	#------------------------------------------
	my $rawConfig = $vmdata -> getConfigEntries();
	my %usrConfigSet = ();
	if ($rawConfig) {
		my @usrConfig = @{$rawConfig};
		for my $configOpt (@usrConfig) {
			print $VMWFD $configOpt . "\n";
			my @opt = split /=/smx, $configOpt;
			$usrConfigSet{$opt[0]} = 1;
		}
	}
	#==========================================
	# Process the default options
	#------------------------------------------
	for my $defOpt (keys %defaultOpts) {
		if ($usrConfigSet{$defOpt}) {
			next;
		}
		print $VMWFD $defOpt . ' = ' . '"' . $defaultOpts{$defOpt}
			. '"' . "\n";
	}
	$VMWFD -> close();
	chmod 0755,$file;
	$kiwi -> done();
	return $file;
}

#==========================================
# createOVFConfiguration
#------------------------------------------
sub createOVFConfiguration {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $ovfdir = $this->{ovfdir};
	my $format = $this->{format};
	my $base   = basename $this->{image};
	my $ovf;
	my $vmdk;
	#==========================================
	# setup config file name from image name
	#------------------------------------------
	$kiwi -> info ("Creating image OVF configuration file...");
	my $image = $base;
	if ($base =~ /(.*)\.(.*?)$/) {
		$image = $1;
		$base  = $image.".ovf";
	}
	$ovf  = $ovfdir."/".$base;
	$vmdk = $base;
	$vmdk =~ s/\.ovf/\.vmdk/;
	unlink $ovf;
	#==========================================
	# search for ovftool, needed for ova
	#------------------------------------------
	my $locator = KIWILocator -> instance();
	my $ovftool = $locator -> getExecPath ('ovftool');
	if (($format eq 'ova') && (! $ovftool)) {
		$kiwi -> skipped ();
		$kiwi -> warning ('ovftool not found, will create only ova tarball');
		$kiwi -> skipped ();
	}
	#==========================================
	# check XML configuration data
	#------------------------------------------
	my $vmdata = $this->{vmdata};
	if (! $vmdata ) {
		$kiwi -> skipped ();
		$kiwi -> warning ('No machine section for this image type found');
		$kiwi -> skipped ();
		return $ovf;
	}
	my $ovfType = $vmdata -> getOVFType();
	if (! $ovfType) {
		$kiwi -> skipped ();
		my $msg = 'No type specified, cannot disambiguate OVF format.';
		$kiwi -> warning ($msg);
		$kiwi -> skipped ();
		return $ovf;
	}
	#==========================================
	# OVF type specific setup
	#------------------------------------------
	my $diskformat;
	my $osid;
	my $systemtype;
	my $diskmode = $vmdata -> getSystemDiskMode();
	my $guest = $vmdata -> getGuestOS();
	my $hwVersion = $vmdata -> getHardwareVersion();
	if ($guest eq 'suse') {
		$guest = 'SUSE';
	} elsif ($guest eq 'suse-64') {
		$guest = 'SUSE 64-Bit';
	}
	my $ostype = $guest;
	if ($ovfType eq 'zvm') {
		$osid       = 36;
		$systemtype = 'IBM:zVM:LINUX';
		$diskformat = 'http://www.ibm.com/'
			. 'xmlns/ovf/diskformat/s390.linuxfile.exustar.gz';
	} elsif ($ovfType eq 'powervm') {
		$osid       = 84;
		$systemtype = 'IBM:POWER:AIXLINUX';
		$diskformat = 'http://www.ibm.com/'
			. 'xmlns/ovf/diskformat/power.aix.mksysb';
	} elsif ($ovfType eq 'xen') {
		$osid       = 84;
		$systemtype = 'xen-' . $hwVersion;
		$diskformat = 'http://xen.org/';
	} else {
		$osid       = 84;
		$systemtype = 'vmx-0' . $hwVersion;
		$diskformat = 'http://www.vmware.com/'
			. 'interfaces/specifications/vmdk.html#streamOptimized';
	}
	#==========================================
	# create config file
	#------------------------------------------
	my $OVFFD = FileHandle -> new();
	if (! $OVFFD -> open (">$ovf")) {
		$kiwi -> error ("Couldn't create OVF config file: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# global setup
	#------------------------------------------
	print $OVFFD '<?xml version="1.0" encoding="UTF-8"?>' . "\n"
		. '<Envelope vmw:buildId="build-260188"' . "\n"
		. 'xmlns="http://schemas.dmtf.org/ovf/envelope/1"' . "\n"
		. 'xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common"' . "\n"
		. 'xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"' . "\n"
		. 'xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/'
		. 'CIM_ResourceAllocationSettingData"' . "\n"
		. 'xmlns:vmw="http://www.vmware.com/schema/ovf"' . "\n"
		. 'xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/'
		. 'CIM_VirtualSystemSettingData"' . "\n"
		. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' . "\n";
	#==========================================
	# image description
	#------------------------------------------
	my $size = -s $this->{image};
	print $OVFFD '<ovf:References>' . "\n"
		. "\t" . '<ovf:File ovf:href="' . $vmdk. '" ovf:id="file1" '
		. 'ovf:size="' . $size . '"/>' . "\n"
		. '</ovf:References>' . "\n";
	#==========================================
	# storage description
	#------------------------------------------
	# /.../
	# for vSphere it needs some bigger then real image disk size.
	# this size is in "byte * 2^20" because MB is not a right value,
	# because rasd/cim standart define nothing and vbox and vSphere
	# understand different values.
	# ----
	my $vsize = $xml -> getImageType() -> getSize();
	if (! $vsize) {
		# fallback if size not set, should be ok for VirtualBox,
		# but bad for vSphere 5
		$vsize = $size;
	}
	print $OVFFD '<ovf:DiskSection>' . "\n"
		. "\t" . '<ovf:Info>Virtual disk information</ovf:Info>' . "\n"
		. "\t" . '<ovf:Disk ovf:capacity="' . $vsize . '" '
		. 'ovf:capacityAllocationUnits="byte * 2^20" '
		. 'ovf:diskId="vmdisk1" '
		. 'ovf:fileRef="file1" '
		. 'ovf:format="' . $diskformat . '" '
		. 'ovf:populatedSize="' . $size . '"/>' . "\n"
	    . '</ovf:DiskSection>' . "\n";
	#==========================================
	# network description
	#------------------------------------------
	my @nicIDs = @{$vmdata -> getNICIDs()};
	my $numNics = scalar @nicIDs;
	if ($numNics) {
		print $OVFFD '<ovf:NetworkSection>' . "\n"
			. "\t" . '<Info>The list of logical networks</Info>' . "\n";
	}
	my %modes;
	for my $id (@nicIDs) {
		my $mode = $vmdata -> getNICMode($id);
		if (! $modes{$mode}) {
			print $OVFFD "\t" . '<Network ovf:name="' . $mode . '">' . "\n"
				. "\t\t" . '<Description>The ' . $mode . ' network'
				. '</Description>' . "\n"
				. "\t" . '</Network>' . "\n";
			$modes{$mode} = 1;
		}
	}
	if ($numNics) {
		print $OVFFD '</ovf:NetworkSection>' . "\n";
	}
	#==========================================
	# virtual system description
	#------------------------------------------
	my $instID = 0;
	print $OVFFD '<VirtualSystem ovf:id="vm">' . "\n"
		. "\t" . '<Info>A virtual machine</Info>' . "\n"
		. "\t" . '<Name>' . $base . '</Name>' . "\n"
		. "\t" . '<OperatingSystemSection '
		. 'ovf:id="' . $osid. '" '
		. 'vmw:osType="' . $ostype . '">' . "\n"
		. "\t\t" . '<Info>Appliance created by KIWI</Info>' . "\n"
		. "\t" . '</OperatingSystemSection>' . "\n"
		. "\t" . '<VirtualHardwareSection>' . "\n"
		. "\t\t" . '<Info>Virtual hardware requirements</Info>' . "\n"
		. "\t\t" . '<System>' . "\n"
		. "\t\t\t" . '<vssd:ElementName>Virtual Hardware Family'
		. '</vssd:ElementName>' . "\n"
		. "\t\t\t" . '<vssd:InstanceID>' . $instID
		. '</vssd:InstanceID>' . "\n"
		. "\t\t\t" . '<vssd:VirtualSystemIdentifier>' . $base
		. '</vssd:VirtualSystemIdentifier>' . "\n"
		. "\t\t\t" . '<vssd:VirtualSystemType>' . $systemtype
		. '</vssd:VirtualSystemType>' . "\n"
		. "\t\t" . '</System>' . "\n";
	$instID += 1;
	# CPU setup
	my $maxCPU = $vmdata -> getMaxCPUCnt();
	my $minCPU = $vmdata -> getMinCPUCnt();
	my $numCPU = $vmdata -> getNumCPUs();
	if ($maxCPU || $minCPU || $numCPU) {
		if (! $numCPU) {
			if ($maxCPU && $minCPU) {
				my $max = int $maxCPU;
				my $min = int $minCPU;
				$numCPU = ($max + $min) / 2;
			} elsif ($maxCPU) {
				$numCPU = int $maxCPU;
				if ($numCPU > 1) {
					$numCPU -= 1;
				}
			} elsif ($minCPU) {
				$numCPU = int $minCPU;
				$numCPU += 1;
			}
		}
		print $OVFFD "\t\t" . '<Item>' . "\n"
			. "\t\t\t"
			. '<rasd:Description>'
			. 'Number of Virtual CPUs'
			. '</rasd:Description>' . "\n"
			. "\t\t\t"
			. '<rasd:ElementName>'
			. 'CPU definition'
			. '</rasd:ElementName>' . "\n"
			. "\t\t\t"
			. '<rasd:InstanceID>'
			. $instID
			. '</rasd:InstanceID>' . "\n";
		if ($minCPU) {
			print $OVFFD "\t\t\t"
				. '<rasd:Limit>'
				. $minCPU
				. '</rasd:Limit>' . "\n";
		}
		if ($maxCPU) {
			print $OVFFD "\t\t\t"
				. '<rasd:Limit>'
				. $maxCPU
				. '</rasd:Limit>' . "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:ResourceType>3</rasd:ResourceType>' . "\n";
		print $OVFFD "\t\t\t"
			. '<rasd:VirtualQuantity>'
			. $numCPU
			. '</rasd:VirtualQuantity>' . "\n";
		print $OVFFD "\t\t" . '</Item>' . "\n";
		$instID += 1;
	}
	# Memory setup
	my $maxMem = $vmdata -> getMaxMemory();
	my $minMem = $vmdata -> getMinMemory();
	my $memory = $vmdata -> getMemory();
	if ($maxMem || $minMem || $memory) {
		if (! $memory) {
			if ($maxMem && $minMem) {
				my $max = int $maxMem;
				my $min = int $minMem;
				$memory = ($maxMem + $minMem) / 2;
			} elsif ($maxMem) {
				$memory = int $maxMem;
				if ($memory > 512) {
					$memory -= 512;
				}
			} elsif ($minMem) {
				$memory = int $minMem;
				$memory += 512;
			}
		}
		print $OVFFD "\t\t" . '<Item>' . "\n"
			. "\t\t\t"
			. '<rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>' . "\n"
			. "\t\t\t"
			. '<rasd:Description>Memory Size</rasd:Description>' . "\n"
			. "\t\t\t"
			. '<rasd:ElementName>'
			. $memory
			. 'MB Memory</rasd:ElementName>' . "\n"
			. "\t\t\t"
			. '<rasd:InstanceID>'
			. $instID
			. '</rasd:InstanceID>' . "\n";
		if ($minMem) {
			print $OVFFD "\t\t\t" 
				. '<rasd:Limit>' . $minMem . '</rasd:Limit>' . "\n";
		}
		if ($maxMem) {
			print $OVFFD "\t\t\t" 
				. '<rasd:Limit>' . $maxMem . '</rasd:Limit>' . "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:ResourceType>4</rasd:ResourceType>' . "\n"
			. "\t\t\t"
			. '<rasd:VirtualQuantity>'
			. $memory
			. '</rasd:VirtualQuantity>' . "\n";
		print $OVFFD "\t\t" . '</Item>' . "\n";
		$instID += 1;
	}
	# Disk controller
	my $controller = $vmdata -> getSystemDiskController();
	my $controllerID = $instID;
	if ($controller) {
		my $rType;
		if ($controller eq 'ide') {
			$rType = 5;
		} else {
			$rType = 6;
		}
		print $OVFFD "\t\t" . '<Item>' . "\n"
		. "\t\t\t"
		. '<rasd:Description>System disk controller</rasd:Description>' . "\n"
		. "\t\t\t"
		. '<rasd:ElementName>'
		. $controller . 'Controller'
		. '</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceSubType>'
		. $controller
		. '</rasd:ResourceSubType>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>' . $rType . '</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
		$instID += 1;
	}
	# Connect the system disk to the controller
	my $pAddress = 0;
	if ($controller) {
		print $OVFFD "\t\t" . '<Item>' . "\n"
		. "\t\t\t"
		. '<rasd:AddressOnParent>'
		. $pAddress
		. '</rasd:AddressOnParent>' . "\n"
		. "\t\t\t"
		. '<rasd:ElementName>disk1</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:Parent>' . $controllerID . '</rasd:Parent>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>17</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
		$pAddress += 1;
		$instID += 1;
	}
	# DVD
	my $dvdController = $vmdata -> getDVDController();
	if ($dvdController) {
		my $dvdContID = $controllerID;
		if ($controller && $dvdController ne $controller) {
			my $rType;
			if ($dvdController eq 'ide') {
				$rType = 5;
			} else {
				$rType = 6;
			}
			print $OVFFD "\t\t" . '<Item>' . "\n"
				. "\t\t\t"
				. '<rasd:Description>DVD controller</rasd:Description>'	. "\n"
				. "\t\t\t"
				. '<rasd:ElementName>DVDController'
				. $dvdController
				. '</rasd:ElementName>' . "\n"
				. "\t\t\t"
				. '<rasd:InstanceID>'
				. $instID
				. '</rasd:InstanceID>' . "\n"
				. "\t\t\t"
				. '<rasd:ResourceType>'
				. $rType
				. '</rasd:ResourceType>' . "\n"
				. "\t\t" . '</Item>' . "\n";
			$dvdContID = $instID;
			$instID += 1;
		}
		print $OVFFD "\t\t" . '<Item ovf:required="false">' . "\n"
		. "\t\t\t"
		. '<rasd:AddressOnParent>'
		. $pAddress
		. '</rasd:AddressOnParent>' . "\n"
		. "\t\t\t"
		. '<rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>' . "\n"
		. "\t\t\t"
		. '<rasd:Description>DVD device</rasd:Description>' . "\n"
		. "\t\t\t"
		. '<rasd:ElementName>DVDdrive</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:Parent>' . $dvdContID . '</rasd:Parent>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>16</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
		$pAddress += 1;
		$instID += 1;
	}
	# Network
	for my $id (@nicIDs) {
		my $iFace = $vmdata -> getNICInterface($id);
		my $mac = $vmdata -> getNICMAC($id);
		print $OVFFD "\t\t" . '<Item>' . "\n";
		if ($mac) {
			print $OVFFD "\t\t\t"
				. '<rasd:Address>' . $mac . '</rasd:Address>'. "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:AddressOnParent>'
			. $pAddress
			. '</rasd:AddressOnParent>' . "\n"
			. "\t\t\t"
			. '<rasd:AutomaticAllocation>'
			. 'true'
			. '</rasd:AutomaticAllocation>' . "\n";
		my $mode = $vmdata -> getNICMode($id);
		print $OVFFD "\t\t\t"
			. '<rasd:Connection>' . $mode . '</rasd:Connection>' . "\n"
			. "\t\t\t"
			. '<rasd:Description>Network adapter</rasd:Description>' . "\n"
			. "\t\t\t"
			. '<rasd:ElementName>ethernet'
			. $iFace
			. '</rasd:ElementName>'	. "\n"
			. "\t\t\t"
			. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n";
		my $driver = $vmdata -> getNICDriver($id);
		if ($driver) {
			print $OVFFD "\t\t\t"
			. '<rasd:ResourceSubType>'
			. $driver
			. '</rasd:ResourceSubType>' . "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:ResourceType>10</rasd:ResourceType>' . "\n"
			. "\t\t" . '</Item>' . "\n";
		$pAddress += 1;
		$instID += 1;
	}
	# Video section
	print $OVFFD "\t\t" . '<Item ovf:required="false">' . "\n"
		. "\t\t\t"
		. '<rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>'
		. "\n"
		. "\t\t\t"
		. '<rasd:ElementName>video</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>24</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
	$pAddress += 1;
	print $OVFFD "\t" . '</VirtualHardwareSection>' . "\n"
		. '</VirtualSystem>' ."\n";
	#==========================================
	# close envelope
	#------------------------------------------
	print $OVFFD '</Envelope>';
	$OVFFD -> close();
	#==========================================
	# create manifest file
	#------------------------------------------
	my $mf = $ovf;
	$mf =~ s/\.ovf$/\.mf/;
	my $MFFD = FileHandle -> new();
	if (! $MFFD -> open (">$mf")) {
		$kiwi -> error ("Couldn't create manifest file: $!");
		$kiwi -> failed ();
		return;
	}
	my $base_image = basename $this->{image};
	my $base_config= basename $ovf;
	my $ovfsha1 = KIWIQX::qxx ("sha1sum $ovf | cut -f1 -d ' ' 2>&1");
	chomp ($ovfsha1);
	my $imagesha1 = KIWIQX::qxx ("sha1sum $this->{image} | cut -f1 -d ' ' 2>&1");
	chomp ($imagesha1);
	print $MFFD "SHA1($base_config)= $ovfsha1"."\n";
	print $MFFD "SHA1($base_image)= $imagesha1"."\n";
	$MFFD -> close();
	#==========================================
	# create OVA tarball
	#------------------------------------------
	if ($format eq 'ova') {
		my $destdir  = dirname $this->{image};
		my $ovaimage = basename $ovfdir;
		$ovaimage =~ s/\.ovf$/\.ova/;
		my $ovabasis = $ovaimage;
		$ovabasis =~ s/\.ova$//;
		my $ovapath = $destdir."/".$ovaimage;
		my $status;
		if ($ovftool) {
			my $options;
			if ($diskmode) {
				$options = " --diskMode=$diskmode";
			}
			$status = KIWIQX::qxx (
				"cd $ovfdir && ovftool $options $ovabasis.ovf $ovapath 2>&1"
			);
		} else {
			my $files = "$ovabasis.ovf $ovabasis.mf $ovabasis.vmdk";
			$status = KIWIQX::qxx (
				"tar -h -C $ovfdir -cf $ovapath $files 2>&1"
			);
		}
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $format image: $status");
			$kiwi -> failed ();
			return;
		}
		if ($ovftool) {
			$kiwi -> info (
				"Replacing qemu's vmdk file with version from generated OVA"
			);
			KIWIQX::qxx ("rm -f $ovabasis.vmdk $ovfdir/$ovabasis.vmdk");
			my $extract = "$ovabasis-disk1.vmdk";
			$status = KIWIQX::qxx (
				"tar -h -C $ovfdir -xf $destdir/$ovaimage $extract 2>&1"
			);
			$result = $? >> 8;
			if ($result == 0) {
				$status = KIWIQX::qxx ("mv $ovfdir/$extract $ovabasis.vmdk 2>&1");
				$result = $? >> 8;
			}
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't unpack vmdk file: $status");
				$kiwi -> failed ();
				return;
			}
			$kiwi -> info (
				"Replacing kiwi's ovf file with version from generated OVA"
			);
			KIWIQX::qxx ("rm -f $ovfdir/$ovabasis.ovf $ovfdir/$ovabasis.mf");
			$extract = "$ovabasis.ovf";
			$status = KIWIQX::qxx (
				"tar -h -C $ovfdir -xf $destdir/$ovaimage $extract"
			);
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't unpack ovf and mf file: $status");
				$kiwi -> failed ();
				return;
			}
		}
	}
	$kiwi -> done();
	return $ovf;
}

#==========================================
# createNetGUID
#------------------------------------------
sub createNetGUID {
	# /.../
	# Convert a string in the expected format, into 16 bytes,
	# emulating .Net's Guid constructor
	# ----
	my $this = shift;
	my $id   = shift;
	my $hx   = '[0-9a-f]';
	if ($id !~ /^($hx{8})-($hx{4})-($hx{4})-($hx{4})-($hx{12})$/i) {
		return;
	}
	my @parts = split (/-/,$id);
	#==========================================
	# pack into signed long 4 byte
	#------------------------------------------
	my $p1 = $parts[0];
	$p1 = pack   'H*', $p1;
	$p1 = unpack 'l>', $p1;
	$p1 = pack   'l' , $p1;
	#==========================================
	# pack into unsigned short 2 byte
	#------------------------------------------
	my $p2 = $parts[1];
	$p2 = pack   'H*', $p2;
	$p2 = unpack 'S>', $p2;
	$p2 = pack   'S' , $p2;
	#==========================================
	# pack into unsigned short 2 byte
	#------------------------------------------
	my $p3 = $parts[2];
	$p3 = pack   'H*', $p3;
	$p3 = unpack 'S>', $p3;
	$p3 = pack   'S' , $p3;
	#==========================================
	# pack into hex string (high nybble first)
	#------------------------------------------
	my $p4 = $parts[3];
	my $p5 = $parts[4];
	$p4 = pack   'H*', $p4;
	$p5 = pack   'H*', $p5;
	#==========================================
	# concat result and return
	#------------------------------------------
	my $guid = $p1.$p2.$p3.$p4.$p5;
	return $guid;
}

#==========================================
# writeVHDTag
#------------------------------------------
sub writeVHDTag {
	# /.../
	# Azure service uses a tag injected into the disk
	# image to identify the OS. The tag is 512B long,
	# starting with a GUID, and is placed at a 16K offset
	# from the start of the disk image.
	#
	# +------------------------------+
	# | jump       | GUID(16B)000... |
	# +------------------------------|
	# | 16K offset | TAG (512B)      |
	# +------------+-----------------+
	#
	# Fixed-format VHD
	# ----
	my $this   = shift;
	my $file   = shift;
	my $tag    = shift;
	my $kiwi   = $this->{kiwi};
	my $guid   = $this->createNetGUID ($tag);
	my $buffer = '';
	my $null_fh;
	my $done;
	#==========================================
	# check result of guid format
	#------------------------------------------
	if (! $guid) {
		$kiwi -> failed ();
		$kiwi -> error  ("VHD Tag: failed to convert tag: $tag");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# open target file
	#------------------------------------------
	my $FD = FileHandle -> new();
	if (! $FD -> open("+<$file")) {
		$kiwi -> failed ();
		$kiwi -> error  ("VHD Tag: failed to open file: $file: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# read in an empty buffer
	#------------------------------------------
	if (! sysopen ($null_fh,"/dev/zero",O_RDONLY) ) {
		$kiwi -> error  ("VHD Tag: Cannot open /dev/zero: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# seek to 16k offset and zero out 512 byte
	#------------------------------------------
	sysread ($null_fh,$buffer, 512); close ($null_fh);
	seek $FD,16384,0;
	$done = syswrite ($FD,$buffer);
	if ((! $done) || ($done != 512)) {
		$kiwi -> failed ();
		if ($done) {
			$kiwi -> error ("VHD Tag: only $done bytes cleaned");
		} else {
			$kiwi -> error ("VHD Tag: syswrite to $file failed: $!");
		}
		$kiwi -> failed ();
		seek $FD,0,2;
		$FD -> close();
		return;
	}
	#==========================================
	# seek back to 16k offset
	#------------------------------------------
	seek $FD,16384,0;
	#==========================================
	# write 16 bytes GUID
	#------------------------------------------
	$done = syswrite ($FD,$guid,16);
	if ((! $done) || ($done != 16)) {
		$kiwi -> failed ();
		if ($done) {
			$kiwi -> error ("VHD Tag: only $done bytes written");
		} else {
			$kiwi -> error ("VHD Tag: syswrite to $file failed: $!");
		}
		$kiwi -> failed ();
		seek $FD,0,2;
		$FD -> close();
		return;
	}
	#==========================================
	# seek end and close
	#------------------------------------------
	seek $FD,0,2;
	$FD -> close();
	return $this;
}

#==========================================
# helper functions
#------------------------------------------
#==========================================
# __ensure_key
#------------------------------------------
sub __ensure_key {
	my $this = shift;
	my $lines= shift;
	my $key  = shift;
	my $val  = shift;
	my $found= 0;
	my $i = 0;
	for ($i=0;$i<@{$lines};$i++) {
		if ($lines->[$i] =~ /^$key/) {
			$lines->[$i] = "$key=\"$val\"";
			$found = 1;
			last;
		}
	}
	if (! $found) {
		$lines->[$i] = "$key=\"$val\"\n";
	}
	return;
}
#==========================================
# __copy_origin
#------------------------------------------
sub __copy_origin {
	my $this = shift;
	my $file = shift;
	if (-f "$file.orig") {
		KIWIQX::qxx ("cp $file.orig $file 2>&1");
	} else {
		KIWIQX::qxx ("cp $file $file.orig 2>&1");
	}
	return;
}
#==========================================
# __clean_loop
#------------------------------------------
sub __clean_loop {
	my $this = shift;
	my $dir = shift;
	KIWIQX::qxx ("umount $dir/sys 2>&1");
	KIWIQX::qxx ("umount $dir 2>&1");
	KIWIQX::qxx ("rmdir  $dir 2>&1");
	return;
}
#==========================================
# __randomMAC
#------------------------------------------
sub __randomMAC {
	my $this = shift;
	my @mac = (0x00, 0x16, 0x3e);
	push @mac, 0x00 + int(rand(0x7e));
	push @mac, 0x00 + int(rand(0xff));
	push @mac, 0x00 + int(rand(0xff));
	my $result = sprintf "%02x%02x%02x%02x%02x%02x", @mac;
	return uc $result;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this   = shift;
	my $tmpdir = $this->{tmpdir};
	if (($tmpdir) && (-d $tmpdir)) {
		KIWIQX::qxx ("rm -rf $tmpdir 2>&1");
	}
	return $this;
}

1;

# vim: set noexpandtab:
