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
use KIWIQX;
use KIWIXMLInfo;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw ();

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
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	if (! defined $cmdL) {
		my $msg = 'KIWICache: failed to create KIWICommandLine object';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! defined $xml) {
		my $msg = 'KIWICache: expecting KIWIXML object as second argument';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if ((! defined $cdir) || (! -d $cdir)) {
		my $msg = 'KIWICache: no valid cache directory specified';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if ((! defined $base) || (! -d $base)) {
		my $msg = 'KIWICache: no valid base modules directory specified';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (($prof) && (! ref $prof)) {
		my $msg = 'KIWICache: expecting ARRAY_REF as fifth argument';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if ((! defined $conf) || (! -d $conf)) {
		my $msg = 'KIWICache: no valid image configuration directory specified';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return undef;
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
	# Check boot type of the image
	#------------------------------------------
	$kiwi -> info ("Initialize image cache...\n");
	my %type = %{$xml->getImageTypeAndAttributes()};
	my $name = $xml -> getImageName();
	if (($type{boot}) && ($type{boot} =~ /.*\/(.*)/)) {
		$CacheDistro = $1;
	} elsif (
		($type{type} =~ /ext2|cpio/) && ($name =~ /initrd-.*boot-(.*)/)
	) {
		$CacheDistro = $1;
	} else {
		$kiwi -> warning ("Can't setup cache without a boot type");
		$kiwi -> skipped ();
		return undef;
	}
	#==========================================
	# Check for cachable patterns
	#------------------------------------------
	my @sections = ("bootstrap","image");
	foreach my $section (@sections) {
		my @list = $xml -> getList ($section);
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
		return undef;
	}
	#==========================================
	# Create image package list
	#------------------------------------------
	$cmdL -> setConfigDir ($conf);
	my $info = new KIWIXMLInfo ($kiwi,$cmdL,$xml);
	my @infoReq = ('packages', 'sources');
	$CacheScan = $info -> getXMLInfoTree(\@infoReq);
	if (! $CacheScan) {
		$kiwi -> warning ("Failed to scan cache");
		$kiwi -> skipped ();
		return undef;
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
	my $base = $this->{base};
	my $prof = $this->{profiles};
	if (! $init) {
		return undef;
	}
	#==========================================
	# Variable setup and reset function
	#------------------------------------------
	my $CacheDistro   = $init->[0];
	my @CachePatterns = @{$init->[1]};
	my @CachePackages = @{$init->[2]};
	my $CacheScan     = $init->[3];
	my $imageCacheDir = $cdir;
	my @repoPaths     = ();
	my @repoTypes     = ();    
	#==========================================
	# setup variables for kiwi prepare call
	#------------------------------------------
	qxx ("mkdir -p $imageCacheDir 2>&1");
	if (@CachePackages) {
		push @CachePatterns,"package-cache"
	}
	#==========================================
	# walk through cachable patterns
	#------------------------------------------
	foreach my $pattern (@CachePatterns) {
		if ($pattern eq "package-cache") {
			$pattern = $xml -> getImageName();
			$cmdL -> setAdditionalPackages (
				[@CachePackages,$xml->getPackageManager()]
			);
			$cmdL -> setAdditionalPatterns ([]);
			$kiwi -> info (
				"--> Building cache file for plain package list\n"
			);
		} else {
			$cmdL -> setAdditionalPackages ([$xml->getPackageManager()]);
			$cmdL -> setAdditionalPatterns ([$pattern]);
			$kiwi -> info (
				"--> Building cache file for pattern: $pattern\n"
			);
		}
		#==========================================
		# use KIWICache.kiwi for cache preparation
		#------------------------------------------
		my $rootTarget  = $imageCacheDir."/".$CacheDistro."-".$pattern;
		$cmdL -> setBuildProfiles ($prof);
		$cmdL -> setConfigDir ($base."/modules");
		$cmdL -> setRootTargetDir ($rootTarget);
		$cmdL -> setForceNewRoot (1);
		my $kic = new KIWIImageCreator ($kiwi, $cmdL);
		if (! $kic) {
			return undef;
		}
		$this->{kic} = $kic;
		if (! $kic -> prepareImage()) {
			undef $kic;	return undef;
		}
		#==========================================
		# Create cache meta data
		#------------------------------------------
		my $meta   = $rootTarget.".cache";
		my $root   = $rootTarget;
		my $ignore = "'gpg-pubkey|bundle-lang'";
		my $rpmopts= "'%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n'";
		my $rpm    = "rpm --root $root";
		qxx ("$rpm -qa --qf $rpmopts | grep -vE $ignore > $meta");
		qxx ("rm -f $root/image/config.xml");
		qxx ("rm -f $root/image/*.kiwi");
		#==========================================
		# Turn cache into ext2 fs image
		#------------------------------------------
		$kiwi -> info (
			"--> Building ext2 cache...\n"
		);
		my $cxml  = new KIWIXML ($kiwi,$base."/modules",undef,undef,$cmdL);
		my $pkgMgr = $cmdL -> getPackageManager();
		if ($pkgMgr) {
			$cxml -> setPackageManager($pkgMgr);
		}
		# /.../
		# tell the system that we are in cache mode with
		# the 'active' flag and therefore prevent kernel
		# extraction from image cache
		# ----
		my $image = new KIWIImage (
			$kiwi,$cxml,$root,$imageCacheDir,
			undef,"/base-system",undef,"active",$cmdL
		);
		if (! defined $image) {
			undef $kic; return undef;
		}
		if (! $image -> createImageEXT2 ()) {
			undef $kic; return undef;
		}
		my $name= $imageCacheDir."/".$cxml -> buildImageName();
		qxx ("mv $name $rootTarget.ext2");
		qxx ("rm -f  $name.ext2");
		qxx ("rm -f  $imageCacheDir/initrd-*");
		qxx ("rm -rf $rootTarget");
		#==========================================
		# write XML changes to logfile...
		#------------------------------------------
		$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
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
	}
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
		return undef;
	}
	my $CacheDistro   = $init->[0];
	my @CachePatterns = @{$init->[1]};
	my @CachePackages = @{$init->[2]};
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
	if (@CachePackages) {
		my $cstr = $xml -> getImageName();
		my $cdir = $this->{cdir}."/".$CacheDistro."-".$cstr.".ext2";
		push @file,$cdir;
	}
	foreach my $pattern (@CachePatterns) {
		my $cdir = $this->{cdir}."/".$CacheDistro."-".$pattern.".ext2";
		push @file,$cdir;
	}
	#==========================================
	# walk through cache files
	#------------------------------------------
	foreach my $clic (@file) {
		my $meta = $clic;
		$meta =~ s/\.ext2$/\.cache/;
		#==========================================
		# check cache files
		#------------------------------------------
		my $CACHE_FD;
		if (! open ($CACHE_FD,$meta)) {
			$kiwi -> loginfo (
				"Cache: no cache meta data $meta found\n"
			);
			next;
		}
		#==========================================
		# read cache file
		#------------------------------------------
		my @cpac = <$CACHE_FD>; chomp @cpac;
		my $ccnt = @cpac; close $CACHE_FD;
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
	return undef;
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
}

1;
