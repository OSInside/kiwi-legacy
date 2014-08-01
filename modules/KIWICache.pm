#================
# FILE          : KIWICache.pm
#----------------
# PROJECT       : openSUSE Build-Service
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

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWIImage;
use KIWIImageCreator;
use KIWILog;
use KIWIQX;
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
    my $xml  = shift;
    my $cdir = shift;
    my $base = shift;
    my $prof = shift;
    my $conf = shift;
    my $cmdL = shift;
    #==========================================
    # Check pre-conditions
    #------------------------------------------
    my $msg = 'KIWICache: ';
    my $kiwi = KIWILog -> instance();
    if (! defined $cmdL) {
        $msg .= 'expecting KIWICommandLine object as sixth argument';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if (! defined $xml) {
        $msg.= 'expecting KIWIXML object as first argument';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if ((! defined $cdir) || (! -d $cdir)) {
        $msg.= 'no valid cache directory specified';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if ((! defined $base) || (! -d $base)) {
        $msg.= 'no valid base modules directory specified';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if (($prof) && (! ref $prof)) {
        $msg.= 'expecting ARRAY_REF as fourth argument';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    if ((! defined $conf) || (! -d $conf)) {
        $msg.= 'no valid image configuration directory specified';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    #==========================================
    # Store object data
    #------------------------------------------
    my $global = KIWIGlobals -> instance();
    $this->{kiwi}     = $kiwi;
    $this->{cmdL}     = $cmdL;
    $this->{xml}      = $xml;
    $this->{cdir}     = $cdir;
    $this->{base}     = $base;
    $this->{profiles} = $prof;
    $this->{config}   = $conf;
    $this->{gdata}    = $global -> getKiwiConfig();
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
    foreach my $typeName (@{$xml->getConfiguredTypeNames()}) {
        my $type = $xml->getType($typeName);
        if (($type->{boot}) && ($type->{boot} =~ /.*\/(.*)/)) {
            $CacheDistro = $1;
            last;
        } elsif (($typeName =~ /ext2|cpio/) && ($name =~ /initrd-.*boot-(.*)/)){
            $CacheDistro = $1;
            last;
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
    my $bootstrapPacks = $xml -> getBootstrapPackages();
    for my $package (@{$bootstrapPacks}) {
        my $name = $package -> getName();
        push @CachePackages, $name;
    }
    my $imagePackages = $xml -> getPackages();
    for my $package (@{$imagePackages}) {
        my $name = $package -> getName();
        push @CachePackages, $name;
    }
    my $imageCollection = $xml -> getPackageCollections();
    for my $collection (@{$imageCollection}) {
        my $name = $collection -> getName();
        push @CachePatterns, 'pattern:'.$name;
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
        my $info = KIWIXMLInfo -> new($cmdL,$xml);
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
    KIWIQX::qxx ("mkdir -p $imageCacheDir 2>&1");
    my $CacheName = $xml -> getImageName();
    $kiwi -> info (
        "--> Building cache $CacheName...\n"
    );
    my $rootTarget  = $imageCacheDir."/".$CacheDistro."-".$CacheName;
    #==========================================
    # Create satsolver based meta data
    #------------------------------------------
    my $info = KIWIXMLInfo -> new ($cmdL,$xml);
    my @infoReq = ('packages');
    my $meta = $info -> getXMLInfoTree(\@infoReq);
    if (! $meta) {
        return;
    }
    my @packages = $meta -> getElementsByTagName ("package");
    if (! @packages) {
        $kiwi -> error ("Got empty solver list");
        return;
    }
    my $metafd = FileHandle -> new();
    if (! $metafd -> open(">$rootTarget.cache")) {
        $kiwi -> error ("Failed to open cache metadata file: $!");
        return;
    }
    foreach my $node (@packages) {
        my $name = $node -> getAttribute ("name");
        my $arch = $node -> getAttribute ("arch");
        my $pver = $node -> getAttribute ("version");
        print $metafd "$name-$pver.$arch"."\n";
    }
    $metafd -> close();
    undef $info;
    #==========================================
    # Prepare cache
    #------------------------------------------
    $cmdL -> setBuildProfiles ($prof);
    $cmdL -> setRootTargetDir ($rootTarget);
    $cmdL -> setOperationMode ("prepare", $cmdL->getConfigDir());
    $cmdL -> setForceNewRoot (1);
    my $kic = KIWIImageCreator -> new($cmdL);
    if (! $kic) {
        return;
    }
    $this->{kic} = $kic;
    if (! $kic -> prepareImage()) {
        undef $kic; return;
    }
    #==========================================
    # Cleanup non cache relevant data
    #------------------------------------------
    my $root   = $rootTarget;
    KIWIQX::qxx ("rm -f $root/image/config.xml");
    KIWIQX::qxx ("rm -f $root/image/*.kiwi");
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
    $kiwi -> info ("Searching for cached data...\n");
    @file = glob ($this->{cdir}.'/'.$CacheDistro.'*.cache');
    if (! @file) {
        $kiwi -> info (
            "--> No caches found for $CacheDistro in $this->{cdir}\n"
        );
        $cmdL -> unsetCacheDir();
        return;
    }
    #==========================================
    # walk through cache files
    #------------------------------------------
    foreach my $meta (@file) {
        #==========================================
        # check cache files
        #------------------------------------------
        $kiwi -> info ("Cache check for: $meta...\n");
        my $CACHE_FD;
        if (! open ($CACHE_FD, '<', $meta)) {
            $kiwi -> info (
                "--> No cache meta data $meta found\n"
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
            "--> $meta $ccnt packages, Image: $pcnt packages\n"
        );
        #==========================================
        # check validity of cache
        #------------------------------------------
        my $invalid = 0;
        if ($ccnt > $pcnt) {
            # cache is bigger than image solved list
            $kiwi -> loginfo (
                "--> $meta contains more packages than image installs\n"
            );
            $invalid = 1;
        } else {
            foreach my $p (@cpac) {
                if (! defined $plist{$p}) {
                    # cache package not part of image solved list
                    $kiwi -> loginfo (
                        "--> $meta $p not in image install list\n"
                    );
                    $invalid = 1; last;
                }
            }
        }
        #==========================================
        # store valid cache
        #------------------------------------------
        if (! $invalid) {
            $Cache{$meta} = int (100 * ($ccnt / $pcnt));
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
        foreach my $meta (keys %Cache) {
            $kiwi -> info ("--> [ $Cache{$meta}% packages ]: $meta\n");
            if ($Cache{$meta} > $max) {
                $max = $Cache{$meta};
            }
        }
        #==========================================
        # Setup overlay for best match
        #------------------------------------------
        foreach my $meta (keys %Cache) {
            if ($Cache{$meta} == $max) {
                $kiwi -> info ("Using cache: $meta");
                $kiwi -> done();
                $meta =~ s/\/+/\//g;
                $meta =~ s/\.cache$//;
                return $meta;
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
