#================
# FILE          : KIWICache.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schäfer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to initialize
#               : and create filesystem image caches
#               :
# STATUS        : Development
#----------------
package KIWICache;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIImage;
use KIWIImageCreator;
use KIWILog;
use KIWIQX qw (qxx);
use KIWIXMLInfo;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the image creator object.
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
	my $kiwi = shift;
	my $xml  = shift;
	my $cdir = shift;
	my $base = shift;
	my $prof = shift;
	my $conf = shift;
	my $cmdL = shift;
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	if (! defined $cmdL) {
		my $msg = 'KIWICache: failed to create KIWICommandLine object';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! defined $xml) {
		my $msg = 'KIWICache: expecting KIWIXML object as second argument';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if ((! defined $cdir) || (! -d $cdir)) {
		my $msg = 'KIWICache: no valid cache directory specified';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if ((! defined $base) || (! -d $base)) {
		my $msg = 'KIWICache: no valid base modules directory specified';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (($prof) && (! ref $prof)) {
		my $msg = 'KIWICache: expecting ARRAY_REF as fifth argument';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if ((! defined $conf) || (! -d $conf)) {
		my $msg = 'KIWICache: no valid image configuration directory specified';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}     = $kiwi;
	$this->{cmdL}     = $cmdL;
	$this->{xml}      = $xml;      
	$this->{cdir}     = $cdir;
	$this->{base}     = $base;
	$this->{profiles} = $prof;
	$this->{config}   = $conf;
	$this->{gdata}    = $main::global -> getGlobals();
	return $this;
}

#==========================================
# initializeCache
#------------------------------------------
sub initializeCache {
	my $this = shift;
	my $cmdL = shift;
	my $createCache = shift;
	my $conf = $this->{config};
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	#==========================================
	# Variable setup
	#------------------------------------------
	my $CacheDistro;   # cache base name
	my @CachePatterns; # image patterns building the cache
	my @CachePackages; # image packages building the cache
	my $CacheScan;     # image scan, for cache package check
	#==========================================
	# Find base distro name
	#------------------------------------------
	$kiwi -> info ("Initialize image cache...\n");
	my $name = $xml -> getImageName();
	foreach my $t (keys %{$xml->{typeInfo}}) {
		my %type = %{$xml->{typeInfo}->{$t}};
		if (($type{boot}) && ($type{boot} =~ /.*\/(.*)/)) {
			$CacheDistro = $1; last;
		} elsif (
			($type{type} =~ /ext2|cpio/) && ($name =~ /initrd-.*boot-(.*)/)
		) {
			$CacheDistro = $1; last;
		}
	}
	if (! $CacheDistro) {
		$kiwi -> warning ("Can't setup distro name for cache");
		$kiwi -> skipped ();
		return;
	}
	#==========================================
	# Check for cachable patterns
	#------------------------------------------
	my @sections = ("bootstrap","image");
	foreach my $section (@sections) {
		my @list = $xml -> getList_legacy ($section);
		foreach my $pac (@list) {
			if ($pac =~ /^pattern:(.*)/) {
				push @CachePatterns,$1;
			} elsif ($pac =~ /^product:(.*)/) {
				# no cache for products at the moment
			} else {
				push @CachePackages,$pac;
			}
		}
	}
	if ((! @CachePatterns) && (! @CachePackages)) {
		$kiwi -> warning ("No cachable patterns/packages in this image");
		$kiwi -> skipped ();
		return;
	}
	#==========================================
	# Create image package list
	#------------------------------------------
	if (! $createCache) {
		$cmdL -> setConfigDir ($conf);
		my $info = KIWIXMLInfo -> new($kiwi,$cmdL,$xml);
		my @infoReq = ('packages', 'sources');
		$CacheScan = $info -> getXMLInfoTree(\@infoReq);
		if (! $CacheScan) {
			$kiwi -> warning ("Failed to scan cache");
			$kiwi -> skipped ();
			return;
		}
	}
	#==========================================
	# Return result list
	#------------------------------------------
	return [
		$CacheDistro,\@CachePatterns,
		\@CachePackages,$CacheScan
	];
}

#==========================================
# createCache
#------------------------------------------
sub createCache {
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $cmdL = $this->{cmdL};
	my $cdir = $this->{cdir};
	my $prof = $this->{profiles};
	if (! $init) {
		return;
	}
	#==========================================
	# Variable setup and reset function
	#------------------------------------------
	my $CacheDistro   = $init->[0];
	my $imageCacheDir = $cdir;
	#==========================================
	# setup variables for kiwi prepare call
	#------------------------------------------
	qxx ("mkdir -p $imageCacheDir 2>&1");
	#==========================================
	# Prepare cache
	#------------------------------------------
	my $CacheName = $xml -> getImageName();
	$kiwi -> info (
		"--> Building cache $CacheName...\n"
	);
	my $rootTarget  = $imageCacheDir."/".$CacheDistro."-".$CacheName;
	$cmdL -> setBuildProfiles ($prof);
	$cmdL -> setRootTargetDir ($rootTarget);
	$cmdL -> setOperationMode ("prepare", $cmdL->getConfigDir());
	$cmdL -> setBuildType ("btrfs");
	$cmdL -> setForceNewRoot (1);
	my $kic = KIWIImageCreator -> new($kiwi, $cmdL);
	if (! $kic) {
		return;
	}
	$this->{kic} = $kic;
	if (! $kic -> prepareImage()) {
		undef $kic;	return;
	}
	#==========================================
	# Create cache meta data
	#------------------------------------------
	my $meta   = $rootTarget.".cache";
	my $root   = $rootTarget;
	my $ignore = "'gpg-pubkey|bundle-lang'";
	my $rpmopts= "'%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n'";
	my $rpm    = "chroot $root rpm";
	qxx ("$rpm -qa --qf $rpmopts | grep -vE $ignore > $meta");
	qxx ("rm -f $root/image/config.xml");
	qxx ("rm -f $root/image/*.kiwi");
	#==========================================
	# Turn cache into btrfs fs image
	#------------------------------------------
	$kiwi -> info (
		"--> Building btrfs cache...\n"
	);
	# /.../
	# tell the system that we are in cache mode with
	# the 'active' flag and therefore prevent kernel
	# extraction from image cache
	# ----
	my $image = KIWIImage -> new(
		$kiwi,$xml,$root,$imageCacheDir,
		undef,"/base-system",undef,"active",$cmdL
	);
	if (! defined $image) {
		undef $kic; return;
	}
	if (! $image -> createImageBTRFS ()) {
		undef $kic; return;
	}
	my $name= $imageCacheDir."/".$main::global -> generateBuildImageName($xml);
	#==========================================
	# Turn cache into read-only image
	#------------------------------------------
	my $data = qxx ("/sbin/losetup -f --show $name 2>&1");
	my $code = $? >> 8;
	chomp $data;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't loopsetup BTRFS cache");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	my $loop = $data;
	$data = qxx ("/sbin/btrfstune -S 1 $loop 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		qxx ("losetup -d $loop 2>&1");
		$kiwi -> error  ("Failed to turn BTRFS cache to read-only");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
	qxx ("losetup -d $loop 2>&1");
	#==========================================
	# Cleanup
	#------------------------------------------
	qxx ("mv $name $rootTarget.btrfs");
	qxx ("rm -f  $name.btrfs");
	qxx ("rm -f  $imageCacheDir/initrd-*");
	qxx ("rm -rf $rootTarget");
	#==========================================
	# Reformat log file for human readers...
	#------------------------------------------
	$kiwi -> setLogHumanReadable();
	#==========================================
	# Move process log to final cache log...
	#------------------------------------------
	$kiwi -> finalizeLog();
	$kiwi -> resetRootChannel();
	undef $kic;
	return $imageCacheDir;
}

#==========================================
# selectCache
#------------------------------------------
sub selectCache {
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $cmdL = $this->{cmdL};
	if (! $init) {
		$cmdL -> unsetCacheDir();
		return;
	}
	my $CacheDistro   = $init->[0];
	my $CacheScan     = $init->[3];
	my $haveCache     = 0;
	my %plist         = ();
	my %Cache         = ();
	#==========================================
	# Search for a suitable cache
	#------------------------------------------
	my @packages = $CacheScan -> getElementsByTagName ("package");
	foreach my $node (@packages) {
		my $name = $node -> getAttribute ("name");
		my $arch = $node -> getAttribute ("arch");
		my $pver = $node -> getAttribute ("version");
		$plist{"$name-$pver.$arch"} = $name;
	}
	my $pcnt = keys %plist;
	my @file = ();
	#==========================================
	# setup cache file names...
	#------------------------------------------
	@file = glob ($this->{cdir}.'/'.$CacheDistro.'*.btrfs');
	#==========================================
	# walk through cache files
	#------------------------------------------
	foreach my $clic (@file) {
		my $meta = $clic;
		$meta =~ s/\.btrfs$/\.cache/;
		#==========================================
		# check cache files
		#------------------------------------------
		my $CACHE_FD;
		if (! open ($CACHE_FD, '<', $meta)) {
			$kiwi -> loginfo (
				"Cache: no cache meta data $meta found\n"
			);
			next;
		}
		#==========================================
		# read cache file
		#------------------------------------------
		my @cpac = <$CACHE_FD>;
		close $CACHE_FD;
		chomp @cpac;
		my $ccnt = @cpac;
		$kiwi -> loginfo (
			"Cache: $meta $ccnt packages, Image: $pcnt packages\n"
		);
		#==========================================
		# check validity of cache
		#------------------------------------------
		my $invalid = 0;
		if ($ccnt > $pcnt) {
			# cache is bigger than image solved list
			$invalid = 1;
		} else {
			foreach my $p (@cpac) {
				if (! defined $plist{$p}) {
					# cache package not part of image solved list
					$kiwi -> loginfo (
						"Cache: $meta $p not in image list\n"
					);
					$invalid = 1; last;
				}
			}
		}
		#==========================================
		# store valid cache
		#------------------------------------------
		if (! $invalid) {
			$Cache{$clic} = int (100 * ($ccnt / $pcnt));
			$haveCache = 1;
		}
	}
	#==========================================
	# Use/select cache if possible
	#------------------------------------------
	if ($haveCache) {
		my $max = 0;
		#==========================================
		# Find best match
		#------------------------------------------
		$kiwi -> info ("Cache list:\n");
		foreach my $clic (keys %Cache) {
			$kiwi -> info ("--> [ $Cache{$clic}% packages ]: $clic\n");
			if ($Cache{$clic} > $max) {
				$max = $Cache{$clic};
			}
		}
		#==========================================
		# Setup overlay for best match
		#------------------------------------------
		foreach my $clic (keys %Cache) {
			if ($Cache{$clic} == $max) {
				$kiwi -> info ("Using cache: $clic");
				$kiwi -> done();
				return $clic;
			}
		}
	}
	$cmdL -> unsetCacheDir();
	return;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this = shift;
	my $kic  = $this->{kic};
	if ($kic) {
		undef $kic;
	}
	return;
}

1;
