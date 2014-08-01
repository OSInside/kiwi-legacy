#================
# FILE          : KIWIOverlay.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used for directory overlay techniques
#               :
#               :
# STATUS        : Development
#----------------
package KIWIOverlay;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use File::Spec;
use File::stat;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILog;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct a new KIWIOverlay object. The constructor
    # will store all information in order to overlay the
    # given directory information. A check whether the mount
    # has worked is done on demand
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless  $this,$class;
    #==========================================
    # Module Parameters
    #------------------------------------------
    my $rootRW = shift;
    my $baseRO = shift;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    if (! -d $rootRW) {
        $kiwi -> error ("Directory $rootRW doesn't exist");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Check rootRW structure
    #------------------------------------------
    $this->{initial} = 0;
    if (defined $baseRO) {
        # ...
        # base read-only path specified, means this is an initial
        # prepare call using a cache
        # ---
        $this->{initial} = 1;
    }
    if (-f "$rootRW/image/kiwi-root.cache") {
        my $FD;
        if (! open ($FD, '<', "$rootRW/image/kiwi-root.cache")) {
            $kiwi -> error  ("Can't open cache root meta data");
            $kiwi -> failed ();
            return;
        }
        $baseRO = <$FD>;
        close $FD;
        chomp $baseRO;
    }
    #==========================================
    # Store object data
    #------------------------------------------
    my $global = KIWIGlobals -> instance();
    $this->{kiwi}   = $kiwi;
    $this->{gdata}  = $global -> getKiwiConfig();
    $this->{baseRO} = $baseRO;
    $this->{rootRW} = $rootRW;
    return $this;
}

#==========================================
# mountOverlay
#------------------------------------------
sub mountOverlay {
    # ...
    # call the appropriate overlay function
    # ---
    my $this = shift;
    if (! defined $this->{baseRO}) {
        return $this->{rootRW};
    }
    return $this -> unionOverlay();
}

#==========================================
# unionOverlay
#------------------------------------------
sub unionOverlay {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $baseRO = $this->{baseRO};
    my $rootRW = $this->{rootRW};
    my @mount  = ();
    my $tmpdir;
    my $result;
    my $status;
    #==========================================
    # Create tmpdir for mount point
    #------------------------------------------
    $tmpdir = KIWIQX::qxx ("mktemp -qdt kiwiRootOverlay.XXXXXX"); chomp $tmpdir;
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Failed to create overlay tmpdir");
        return;
    }
    $this->{tmpdir} = $tmpdir;
    #==========================================
    # Mount cache as snapshot
    #------------------------------------------
    $kiwi -> info("Creating overlay path\n");
    $kiwi -> info("--> Base: $baseRO(ro)\n");
    $kiwi -> info("--> COW:  $rootRW(rw)\n");
    #==========================================
    # overlay mount both paths
    #------------------------------------------
    my $opts= "lowerdir=$baseRO,upperdir=$rootRW";
    $status = KIWIQX::qxx (
        "mount -n -t overlayfs -o $opts overlayfs $tmpdir 2>&1"
    );
    $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Failed to overlay mount paths: $status");
        $kiwi -> failed ();
        return;
    }
    push @mount,"umount $tmpdir";
    $this->{mount} = \@mount;
    #==========================================
    # setup cache meta data
    #------------------------------------------
    if ($this->{initial}) {
        # /.../
        # store the location of the base read-only cache file
        # on invocation of an initial prepare call
        # ----
        KIWIQX::qxx ("mkdir -p $rootRW/image");
        KIWIQX::qxx ("echo $this->{baseRO} > $rootRW/image/kiwi-root.cache");
    }
    return $tmpdir;
}

#==========================================
# resetOverlay
#------------------------------------------
sub resetOverlay {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $tmpdir = $this->{tmpdir};
    my $baseRO = $this->{baseRO};
    my $mount  = $this->{mount};
    my $data;
    my $code;
    if ($mount) {
        foreach my $cmd (reverse @{$mount}) {
            KIWIQX::qxx ("$cmd 2>&1");
        }
    }
    if (($tmpdir) && (-d $tmpdir)) {
        KIWIQX::qxx ("rmdir $tmpdir 2>&1");
    }
    return $this;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
    my $this = shift;
    $this -> resetOverlay();
    return $this;
}

1;
