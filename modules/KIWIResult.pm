#================
# FILE          : KIWIResult.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2014 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to bundle build results
#               :
#               :
# STATUS        : Production
#----------------
package KIWIResult;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Config::IniFiles;
use Digest::SHA qw(sha256);
use Cwd;

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
    # Create a new KIWIResult object
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
    my $sourcedir = shift;
    my $destdir   = shift;
    my $buildnr   = shift;
    #==========================================
    # Parameter check
    #------------------------------------------
    my $kiwi = KIWILog->instance();
    if (-d $destdir) {
        $kiwi -> error ("Destination dir $destdir already exists");
        $kiwi -> failed();
        return;
    }
    if (! $sourcedir) {
        $kiwi -> error ("No image source directory specified");
        $kiwi -> failed();
        return;
    }
    if (! $buildnr) {
        $kiwi -> error ("No build-id specified");
        $kiwi -> failed();
        return;
    }
    #==========================================
    # read in build information file
    #------------------------------------------
    my $file = $sourcedir.'/kiwi.buildinfo';
    if (! -e $file) {
        $kiwi -> error ("Can't find $file");
        $kiwi -> failed ();
        return;
    }
    my $buildinfo = Config::IniFiles -> new (
        -file => $file, -allowedcommentchars => '#'
    );
    my $imagebase = $buildinfo->val('main','image.basename');
    if (! $imagebase) {
        $kiwi -> error ("Can't find image.basename");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # create temp. dir
    #------------------------------------------
    my $tmpdir = KIWIQX::qxx (
        "mktemp -qdt kiwiresult.XXXXXX"
    );
    my $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
        $kiwi -> failed ();
        return;
    }
    chomp $tmpdir;
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{imagebase} = $imagebase;
    $this->{tmpdir}    = $tmpdir;
    $this->{buildinfo} = $buildinfo;
    $this->{kiwi}      = $kiwi;
    $this->{sourcedir} = $sourcedir;
    $this->{destdir}   = $destdir;
    $this->{buildnr}   = $buildnr;
    return $this;
}

#==========================================
# buildRelease
#------------------------------------------
sub buildRelease {
    # ...
    # bundle result image files into a tmpdir and skip
    # intermediate build results as well as the build
    # metadata. The result files will contain the
    # given build number
    # ---
    my $this = shift;
    my $buildnr = $this->{buildnr};
    my $kiwi = $this->{kiwi};
    my $buildinfo = $this->{buildinfo};
    my $result;
    $kiwi -> info ("Bundle build results for release: $buildnr\n");
    #==========================================
    # Evaluate bundler method
    #------------------------------------------
    my $type = $buildinfo->val('main','image.type')//'';

    if ($type eq 'product') {
        $kiwi -> info ("--> Calling product bundler\n");
        $result = $this -> __bundleProduct();
    } elsif ($type eq 'aci') {
        $kiwi -> info ("--> Calling aci bundler\n");
        $result = $this -> __bundleACI();
    } elsif ($type eq 'docker') {
        $kiwi -> info ("--> Calling docker bundler\n");
        $result = $this -> __bundleDocker();
    } elsif ($type eq 'lxc') {
        $kiwi -> info ("--> Calling LXC bundler\n");
        $result = $this -> __bundleLXC();
    } elsif ($type eq 'iso') {
        $kiwi -> info ("--> Calling ISO bundler\n");
        $result = $this -> __bundleISO();
    } elsif ($type eq 'tbz') {
        $kiwi -> info ("--> Calling TBZ bundler\n");
        $result = $this -> __bundleTBZ();
    } elsif ($type eq 'vmx') {
        $kiwi -> info ("--> Calling Disk VMX bundler\n");
        $result = $this -> __bundleDisk();
    } elsif ($type eq 'oem') {
        $kiwi -> info ("--> Calling Disk OEM bundler\n");
        $result = $this -> __bundleDisk();
    } else {
        $kiwi -> info ("--> Calling default bundler\n");
        $result = $this -> __bundleDefault();
    }
    if ($result) {
        $result = $this -> __sign_with_sha256sum();
    }
    $this->DESTROY if ! $result;
    return $result;
}

#==========================================
# populateRelease
#------------------------------------------
sub populateRelease {
    # ...
    # Move files from tmpdir back to destdir and
    # delete level 1 files from the destdir before
    # ---
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $dest   = $this->{destdir};
    my $tmpdir = $this->{tmpdir};
    $kiwi -> info (
        "Populating build results to: $dest\n"
    );
    #==========================================
    # copy build meta data
    #------------------------------------------
    if (! $this -> __bundleMeta()) {
        $this->DESTROY;
        return;
    }
    #==========================================
    # populate results
    #------------------------------------------
    my $status = KIWIQX::qxx (
        "mkdir -p $dest && mv $tmpdir/* $dest/ 2>&1"
    );
    my $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> error  ("Failed to populate results: $status");
        $kiwi -> failed ();
        $this->DESTROY;
        return;
    }
    #==========================================
    # cleanup
    #------------------------------------------
    $this->DESTROY;
    return $this;
}

#==========================================
# __bundleMeta
#------------------------------------------
sub __bundleMeta {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $source = $this->{sourcedir};
    my $tmpdir = $this->{tmpdir};
    my $bnr    = $this->{buildnr};
    my $base   = $this->{imagebase};
    my @meta   = (
        'packages','verified','channel'
    );
    my $data;
    my $code;
    foreach my $suffix (@meta) {
        my $meta = "$source/$base.$suffix";
        if (-e $meta) {
            $data = KIWIQX::qxx (
                "cp $meta $tmpdir/$base-$bnr.$suffix 2>&1"
            );
            $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> error  ("Failed to copy $meta: $data");
                $kiwi -> failed ();
                return;
            }
        }
    }
    return $this;
}

#==========================================
# __bundleDefault
#------------------------------------------
sub __bundleDefault {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $source = $this->{sourcedir};
    my $tmpdir = $this->{tmpdir};
    my $bnr    = $this->{buildnr};
    my $base   = $this->{imagebase};
    my @excl   = (
        '--exclude *.buildinfo',
        '--exclude *.verified',
        '--exclude *.packages'
    );
    my $opts = '--no-recursion';
    my $data = KIWIQX::qxx (
        "cd $source && find . -maxdepth 1 -type f 2>&1"
    );
    my $code = $? >> 8;
    if ($code == 0) {
        my @flist = split(/\n/,$data);
        $data = KIWIQX::qxx (
            "cd $source && tar $opts -czf $tmpdir/$base-$bnr.tgz @excl @flist"
        );
        $code = $? >> 8;
    }
    if ($code != 0) {
        $kiwi -> error  ("Failed to archive results: $data");
        $kiwi -> failed ();
        return;
    }
    return $this;
}

#==========================================
# __bundleExtension
#------------------------------------------
sub __bundleExtension {
    my $this   = shift;
    my $suffix = shift;
    my $base   = shift;
    my $kiwi   = $this->{kiwi};
    my $source = $this->{sourcedir};
    my $tmpdir = $this->{tmpdir};
    my $bnr    = $this->{buildnr};
    my $data;
    if (! $base) {
        $base = $this->{imagebase};
    }
    if ($suffix =~ /raw|vhdfixed/) {
        # compress raw (no format) and vhdfixed format using xz
        $data = KIWIQX::qxx (
            "xz -kc $source/$base.$suffix >$tmpdir/$base-$bnr.$suffix.xz 2>&1"
        );
    } elsif ($suffix eq 'docker') {
        # docker is an xz compressed tarball
        $data = KIWIQX::qxx (
            "cp $source/$base.tar.xz $tmpdir/$base-$bnr.tar.xz 2>&1"
        );
    } else {
        # default bundle handling is a copy
        $data = KIWIQX::qxx (
            "cp $source/$base.$suffix $tmpdir/$base-$bnr.$suffix 2>&1"
        );
    }
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error  ("Failed to copy $suffix image: $data");
        $kiwi -> failed ();
        return;
    }
    if ($suffix =~ /json|vmx|xenconfig/) {
        # there is metadata whose contents needs a path update
        my $file = "$tmpdir/$base-$bnr.$suffix";
        $data = KIWIQX::qxx (
            "sed -i -e 's/$base/$base-$bnr/' $file 2>&1"
        );
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> error  (
                "Failed to update metadata contents of $file: $data"
            );
            $kiwi -> failed ();
            return;
        }
    }
    return $this;
}

#==========================================
# __bundleProduct
#------------------------------------------
sub __bundleProduct {
    my $this = shift;
    return $this -> __bundleExtension ('iso');
}

#==========================================
# __bundleACI
#------------------------------------------
sub __bundleACI {
    my $this = shift;
    return $this -> __bundleExtension ('aci');
}

#==========================================
# __bundleDocker
#------------------------------------------
sub __bundleDocker {
    my $this = shift;
    return $this -> __bundleExtension ('docker');
}

#==========================================
# __bundleLXC
#------------------------------------------
sub __bundleLXC {
    my $this = shift;
    return $this -> __bundleExtension ('lxc');
}

#==========================================
# __bundleISO
#------------------------------------------
sub __bundleISO {
    my $this = shift;
    return $this -> __bundleExtension ('iso');
}

#==========================================
# __bundleTBZ
#------------------------------------------
sub __bundleTBZ {
    my $this = shift;
    return $this -> __bundleExtension ('tbz');
}

#==========================================
# __bundleDisk
#------------------------------------------
sub __bundleDisk {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $base   = $this->{imagebase};
    my $source = $this->{sourcedir};
    my $tmpd   = $this->{tmpdir};
    my $bnr    = $this->{buildnr};
    my $buildinfo = $this->{buildinfo};
    my $data;
    my $code;
    my $ret;
    my $install = 0;
    #==========================================
    # handle install media
    #------------------------------------------
    if ($buildinfo->exists('main','install.iso')) {
        $install = 1;
        $ret |= $this -> __bundleExtension ('install.iso');
    }
    if ($buildinfo->exists('main','install.stick')) {
        $install = 1;
        $ret |= $this -> __bundleExtension ('install.raw');
    }
    if ($buildinfo->exists('main','install.pxe')) {
        $install = 1;
        $ret |= $this -> __bundleExtension ('install.tar.xz');
    }
    if ($install) {
        return $ret;
    }
    #==========================================
    # handle formats
    #------------------------------------------
    my $format = $buildinfo->val('main','image.format');
    if (! $format) {
        return $this -> __bundleExtension ('raw');
    }
    if ($format eq 'vhd-fixed') {
        # inconsistency between format specified in schema and
        # extension used in the result file. More clean fix would
        # be a schema change plus xsl stylesheet
        $format = 'vhdfixed';
    }
    if ($format eq 'gce') {
        my @archives = glob ("$source/*gce-*.tar.gz");
        if (! @archives) {
            $kiwi -> error  ("No GCE archive(s) found");
            $kiwi -> failed ();
            return;
        }
        foreach my $archive (@archives) {
            if ($archive =~ /$source\/(.*gce-.*)\.tar\.gz/) {
                return $this -> __bundleExtension ('tar.gz', $1);
            }
        }
    }
    if ($format eq 'vagrant') {
        my @boxes = glob ("$source/$base.*.box");
        if (! @boxes) {
            $kiwi -> error  ("No box files found");
            $kiwi -> failed ();
            return;
        }
        foreach my $box (@boxes) {
            if ($box =~ /$base\.(.*)\.box/) {
                my $provider = $1;
                if (! $this -> __bundleExtension('box',"$base.$provider")) {
                    return;
                }
                if (! $this -> __bundleExtension('json',"$base.$provider")) {
                    return;
                }
            }
        }
        return $this;
    }
    if (! $this -> __bundleExtension ($format)) {
        return;
    }
    #==========================================
    # handle machine configuration
    #------------------------------------------
    if (-e "$source/$base.vmx") {
        return $this -> __bundleExtension ('vmx');
    }
    if (-e "$source/$base.xenconfig") {
        return $this -> __bundleExtension ('xenconfig');
    }
    return $this;
}

#==========================================
# __sign_with_sha256sum
#------------------------------------------
sub __sign_with_sha256sum {
    my $this   = shift;
    my $kiwi   = $this->{kiwi};
    my $tmpdir = $this->{tmpdir};
    my $dh;
    if (! opendir($dh, $tmpdir)) {
        $kiwi -> error  ("Can't open directory: $tmpdir: $!");
        $kiwi -> failed ();
        return;
    }
    my $orig_cwd = getcwd;
    chdir $tmpdir;
    while (my $entry = readdir ($dh)) {
        next if $entry eq "." || $entry eq "..";
        next if ! -f $entry;
        my $alg = 'sha256';
        my $sha = Digest::SHA->new($alg);
        if (! $sha) {
            $kiwi -> error  ("Unsupported Digest::SHA algorithm: $alg");
            $kiwi -> failed ();
            return;
        }
        $sha -> addfile ($entry);
        my $digest = $sha -> hexdigest;
        my $fd = FileHandle -> new();
        if (! $fd -> open (">$tmpdir/$entry.sha256")) {
            $kiwi -> error ("Can't open file $tmpdir/$entry.sha256: $!");
            $kiwi -> failed ();
            return;
        }
        print $fd $digest."\n";
        $fd -> close();
    }
    chdir $orig_cwd;
    closedir $dh;
    return $this;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
    my $this = shift;
    my $tmpdir = $this->{tmpdir};
    if (($tmpdir) && (-d $tmpdir)) {
        KIWIQX::qxx ("rm -rf $tmpdir");
    }
    return $this;
}

1;
