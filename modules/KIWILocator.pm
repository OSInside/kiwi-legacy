#================
# FILE          : KIWILocator.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to perform operations
#               : on the local filesystem
#               :
# STATUS        : Development
#----------------
package KIWILocator;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Env;
use Cwd qw (abs_path getcwd);
use IPC::Open3;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
use base qw /Class::Singleton/;

#==========================================
# KIWI Modules
#------------------------------------------
require KIWILog;
require KIWIQX;
require KIWITrace;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# createTmpDirectory
#------------------------------------------
sub createTmpDirectory {
    my $this          = shift;
    my $useRoot       = shift;
    my $selfRoot      = shift;
    my $cmdL          = shift;
    my $rootError     = 1;
    my $root;
    my $code;
    my $kiwi  = $this->{kiwi};
    my $trace = KIWITrace -> instance();
    my $forceRoot = $cmdL -> getForceNewRoot();
    if (! defined $useRoot) {
        if (! defined $selfRoot) {
            $root = KIWIQX::qxx ("mktemp -qdt kiwi.XXXXXX");
            $code = $? >> 8;
            if ($code == 0) {
                $rootError = 0;
            }
            chomp $root;
        } else {
            $root = $selfRoot;
            rmdir $root;
            if ( -e $root && -d $root && $forceRoot ) {
                $kiwi -> info ("Removing old root directory '$root'");
                my $status = KIWIQX::qxx (
                    "cat /proc/mounts | grep '$root' 2>&1"
                );
                my $result = $? >> 8;
                if ($result == 0) {
                    $kiwi -> failed();
                    $kiwi -> error  ("Found active mount points in '$root'");
                    $kiwi -> failed();
                    return;
                }
                KIWIQX::qxx ("rm -R $root");
                $kiwi -> done();
            }
            if (mkdir $root) {
                $rootError = 0;
            } else {
                $kiwi -> failed();
                $kiwi -> error ("Couldn't mkdir '$root': $!");
                $kiwi -> failed();
            }
        }
    } else {
        if (-d $useRoot) {
            $root = $useRoot;
            $rootError = 0;
        }
    }
    if ( $rootError ) {
        if ($kiwi -> trace()) {
            $trace->{BT}[$trace->{TL}] = eval {
                Carp::longmess ($trace->{TT}.$trace->{TL}++)
            };
        }
        return;
    }
    if ( $rootError ) {
        return;
    }
    return $root;
}

#==========================================
# getBootImageDescription
#------------------------------------------
sub getBootImageDescription {
    # ...
    # Return a fully qualified path for the boot image description.
    #
    # - If the given string argument starts with / verify that a control file
    #   can be found within
    # - If a relative path is given search in
    #   ~ the current working directory
    #   ~ the directory given as second argument
    #   ~ the kiwi default path
    #
    # returns the first match found
    #---
    my $this          = shift;
    my $bootImgPath   = shift;
    my $addlSearchDir = shift;
    my $kiwi = $this->{kiwi};
    if (! $bootImgPath) {
        my $msg = 'KIWILocator:getBootImageDescription called without '
            . 'boot image to look for. Internal error, please file a bug.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    # Check if we received an absolute path
    my $firstC = substr $bootImgPath, 0 , 1;
    if ($firstC eq '/') {
        if (! -d $bootImgPath) {
            my $msg = "Could not find given directory '$bootImgPath'.";
            $kiwi -> error ($msg);
            $kiwi -> failed();
            return;
        }
        my $config = $this -> getControlFile($bootImgPath);
        if (! $config) {
            my $msg = "Given boot image description '$bootImgPath' does "
                . 'not contain configuration file.';
            $kiwi -> error ($msg);
            $kiwi -> failed();
            return;
        }
        return $bootImgPath;
    }
    # Look in the current working directory
    my $cwd = getcwd();
    $cwd .= '/';
    my $potBootImgPath = $cwd . $bootImgPath;
    if ( -d $potBootImgPath) {
        my $config = $this -> getControlFile($potBootImgPath);
        if ($config) {
            return $potBootImgPath;
        }
    }
    # Look in the additional search directory
    if ($addlSearchDir) {
        my $absSearchDir = abs_path($addlSearchDir);
        if ( -d $absSearchDir) {
            $absSearchDir .= '/';
            my $probBootImgPath = $absSearchDir . $bootImgPath;
            if ( -d $probBootImgPath) {
                my $config = $this -> getControlFile($probBootImgPath);
                if ($config) {
                    return $probBootImgPath;
                }
            }
        }
    }
    # Look in the default location
    my $global = KIWIGlobals -> instance();
    my %confData = %{$global -> getKiwiConfig()};
    my $sysBootImgPath = $confData{System};
    $sysBootImgPath .= '/';
    my $kiwiBootImgDescript = $sysBootImgPath . $bootImgPath;
    if ( -d $kiwiBootImgDescript) {
        my $config = $this -> getControlFile($kiwiBootImgDescript);
        if ($config) {
            return $kiwiBootImgDescript
        }
    }
    my $msg = 'Could not find valid boot image description for'
        . "'$bootImgPath'.";
    $kiwi -> error($msg);
    $kiwi -> failed();
    return ();
}

#==========================================
# getControlFile
#------------------------------------------
sub getControlFile {
    # ...
    # This function receives a directory as parameter
    # and searches for a kiwi xml description in it.
    # ----
    my $this    = shift;
    my $dir     = shift;
    my $kiwi    = $this->{kiwi};
    my @subdirs = ("/","/image/");
    my $found   = 0;
    my @globsearch;
    my $config;
    if (! -d $dir) {
        my $msg = "Expected a directory at $dir.\nSpecify a directory";
        $msg .= ' as the configuration base.';
        $kiwi -> error ($msg);
        $kiwi -> failed();
        return;
    }
    foreach my $search (@subdirs) {
        $config = $dir.$search.$this->{configName};
        if (-f $config) {
            $found = 1; last;
        }
        @globsearch = glob ($dir.$search."*.kiwi");
        my $globitems  = @globsearch;
        if ($globitems == 0) {
            next;
        } elsif ($globitems > 1) {
            $found = 2; last;
        } else {
            $config = pop @globsearch;
            $found = 1; last;
        }
    }
    if ($found == 1) {
        return $config;
    } elsif ($found == 2) {
        my $msg = "Found multiple control files in $dir\n";
        for my $item (@globsearch) {
            $msg .= "\t$item\n";
        }
        $kiwi -> error ($msg);
        $kiwi -> failed();
    } else {
        $kiwi -> error ( "Could not locate a configuration file in $dir");
        $kiwi -> failed();
    }
    return;
}

#============================================
# getDefaultCacheDir
#--------------------------------------------
sub getDefaultCacheDir {
    # ...
    # Return the path of the default cache directory Kiwi uses
    # ---
    my $this = shift;
    return $this -> {defCacheDir};
}

#============================================
# getExecArgsFormat
#--------------------------------------------
sub getExecArgsFormat {
    # ...
    # Return a hash ref of the argument format for the sought after
    # arguments.
    # The method handles long arguments and deals with difference in
    # version where arguments may have changed from -argument to --argument
    # ---
    my $this = shift;
    my $execName = shift;
    my $opts = shift;
    my @optsToGet = @{ $opts };
    my %optInfo;
    my $allOptionsFound;
    my $execPath;
    my $numOptsToGet = @optsToGet;
    my $numOptsFound = 0;
    my $CHILDWRITE;
    my $CHILDSTDOUT;
    my $CHILDSTDERR;
    if (! -f $execName) {
        $execPath = $this -> getExecPath($execName);
        if (! $execPath) {
            $optInfo{'status'} = 0;
            $optInfo{'error'} = "Could not find $execName";
            return \%optInfo;
        } else {
            $execName = $execPath
        }
    }
    my $pid = open3 (
        $CHILDWRITE, $CHILDSTDOUT, $CHILDSTDERR, "$execName --help"
    );
    waitpid( $pid, 0 );
    my $status = $? >> 8;
    my @help = <$CHILDSTDOUT>;
    if (($status) && ($CHILDSTDERR)) {
        my @chldstderr = <$CHILDSTDERR>;
        @help = (@help, @chldstderr);
    }
    HELPOPTS:
    for my $opt (@help) {
        GETOPTS:
        for my $seekOpt (@optsToGet) {
            if ($opt =~ /$seekOpt[,\s=]+/x) {
                my @prts = split /[,\s=]+/x, $opt;
                OPTLINE:
                for my $item (@prts) {
                    if ($item =~ /-+$seekOpt/x) {
                        $optInfo{$seekOpt} = $item;
                        $numOptsFound += 1;
                        last OPTLINE;
                    }
                }
            }
        }
        if ($numOptsFound == $numOptsToGet) {
            $allOptionsFound = 1;
            last HELPOPTS;
        }
    }
    if ($allOptionsFound) {
        $optInfo{'status'} = 1;
    } else {
        my @foundOpts = keys %optInfo;
        for my $item (@optsToGet) {
            if (! grep { /$item/x } @foundOpts) {
                my $msg = "Could not find argument $item for $execName";
                $optInfo{'error'} = $msg;
                last;
            }
        }
        $optInfo{'status'} = 0;
    }
    return \%optInfo;
}

#============================================
# getExecPath
#--------------------------------------------
sub getExecPath {
    # ...
    # Return the full path of the given executable
    # ---
    my $this     = shift;
    my $execName = shift;
    my $root     = shift;
    my $nolog    = shift;
    my $kiwi     = $this->{kiwi};
    my $cmd      = q{};
    my $CHILDWRITE;
    my $CHILDSTDOUT;
    my $CHILDSTDERR;
    if ($root) {
        $cmd .= "chroot $root ";
    }
    $cmd .= 'bash -c "PATH=';
    if ($ENV{PATH}) {
        $cmd .= $ENV{PATH};
    }
    $cmd .= ':/bin:/sbin:/usr/bin:/usr/sbin type -p ';
    $cmd .= $execName . '" 2>&1';
    my $pid = open3 (
        $CHILDWRITE, $CHILDSTDOUT, $CHILDSTDERR, $cmd
    );
    waitpid( $pid, 0 );
    my $code = $? >> 8;
    my $execPath = <$CHILDSTDOUT>;
    if (($code != 0) || (! $execPath)) {
        if (($kiwi) && (! $nolog)) {
            $kiwi -> loginfo ("warning: $execName not found\n");
        }
        return;
    }
    chomp $execPath;
    return $execPath;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# One time initialization code
#------------------------------------------
sub _new_instance {
    # ...
    # Create the Locator object
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{configName}  = 'config.xml';
    $this->{defCacheDir} = '/var/cache/kiwi/image';
    $this->{kiwi}        = KIWILog -> instance();
    return $this;
}

1;
