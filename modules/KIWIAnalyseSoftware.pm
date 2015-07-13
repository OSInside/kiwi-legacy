#================
# FILE          : KIWIAnalyseSoftware.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide methods for
#               : getting information about managed software
#               : manages software is part of packaging
#               : system like rpm
#               :
#               :
#               :
# STATUS        : Development
#----------------
package KIWIAnalyseSoftware;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use FileHandle;
use File::Find;
use File::stat;
use File::Basename;
use File::Path;
use File::Copy;
use Storable;
use File::Spec;
use Fcntl ':mode';
use Cwd qw (abs_path cwd);

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
    # Create a new KIWIAnalyseSoftware object which
    # is used to gather information about software
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
    my $system_analyser = shift;
    my $cmdL = shift;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $kiwi   = KIWILog -> instance();
    my $global = KIWIGlobals -> instance();
    my $addlRepos = $cmdL -> getAdditionalRepos();
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{gdata}       = $global -> getKiwiConfig();
    $this->{kiwi}        = $kiwi;
    $this->{addrepo}     = $addlRepos->{repositories};
    $this->{addrepotype} = $addlRepos->{repositoryTypes};
    $this->{addrepoalias}= $addlRepos->{repositoryAlias};
    $this->{addrepoprio} = $addlRepos->{repositoryPriorities};
    $this->{sys_analyser}= $system_analyser;
    $this->{mount}       = [];
    #==========================================
    # Initialize
    #------------------------------------------
    if (! $this -> __dumpSoftwareStack()) {
        return;
    }
    return $this;
}


#==========================================
# getOS
#------------------------------------------
sub getOS {
    my $this = shift;
    return $this->{product};
}

#==========================================
# getRepositories
#------------------------------------------
sub getRepositories {
    my $this = shift;
    return $this->{source}
}

#==========================================
# getSolverPatternConflict
#------------------------------------------
sub getSolverPatternConflict {
    my $this = shift;
    return $this->{solverProblem1};
}

#==========================================
# getSolverPatternNotFound
#------------------------------------------
sub getSolverPatternNotFound {
    my $this = shift;
    return $this->{solverFailedJobs1};
}

#==========================================
# getSolverPackageConflict
#------------------------------------------
sub getSolverPackageConflict {
    my $this = shift;
    return $this->{solverProblem2};
}

#==========================================
# getSolverPackageNotFound
#------------------------------------------
sub getSolverPackageNotFound {
    my $this = shift;
    return $this->{solverFailedJobs2};
}

#==========================================
# getMultipleInstalledPackages
#------------------------------------------
sub getMultipleInstalledPackages {
    my $this = shift;
    return $this->{twice};
}

#==========================================
# getPackageNames
#------------------------------------------
sub getPackageNames {
    my $this = shift;
    return $this->{packages};
}

#==========================================
# getPackagesToDelete
#------------------------------------------
sub getPackagesToDelete {
    my $this = shift;
    return $this->{delete_packages};
}

#==========================================
# getPackageCollections
#------------------------------------------
sub getPackageCollections {
    my $this = shift;
    return $this->{patterns};
}

#==========================================
# __populateOperatingSystemVersion
#------------------------------------------
sub __populateOperatingSystemVersion {
    # ...
    # Find the version information of this system according
    # to the table KIWIAnalyse.systems
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $VFD = FileHandle -> new();
    my $name;
    my $vers;
    my $plvl;
    if (! $VFD -> open ("/etc/products.d/baseproduct")) {
        $kiwi -> error ("Can't find a baseproduct");
        $kiwi -> failed();
        return;
    }
    while (my $line = <$VFD>) {
        if ($line =~ /<baseversion>(.*)<\/baseversion>/) {
            $vers = $1;
        } elsif ($line =~ /<version>(.*)<\/version>/) {
            $vers = $1;
        }
        if ($line =~ /<patchlevel>(.*)<\/patchlevel>/) {
            $plvl = $1;
        }
        if ($line =~ /<distribution>(.*)<\/distribution>/) {
            $name = $1;
        }
    }
    $VFD -> close();
    if ((! $name) || (! $vers)) {
        $kiwi -> error ("Can't find a product name/version");
        $kiwi -> failed();
        return;
    }
    if ($name eq 'SUSE_SLES') {
        $name = 'SUSE-Linux-Enterprise-Server';
    } elsif ($name eq 'SLES') {
        $name = 'SUSE-Linux-Enterprise-Server';
    } elsif ($name eq 'SUSE_SLED') {
        $name = 'SUSE-Linux-Enterprise-Desktop';
    } elsif ($name eq 'SLED') {
        $name = 'SUSE-Linux-Enterprise-Desktop';
    } elsif ($name eq 'SUSE_SLE') {
        $name = 'SUSE-Linux-Enterprise-Server';
    }
    if ($plvl) {
        $plvl = 'SP'.$plvl;
        $name = $name.'-'.$vers.'-'.$plvl;
    } else {
        $name = $name.'-'.$vers;
    }
    my $MFD = FileHandle -> new();
    if (! $MFD -> open ($this->{gdata}->{KAnalyse})) {
        $kiwi -> error ("Can't open $this->{gdata}->{KAnalyse}");
        $kiwi -> failed();
        return;
    }
    while (my $line = <$MFD>) {
        next if $line =~ /^#/;
        if ($line =~ /(.*)\s*=\s*(.*)/) {
            my $product= $1;
            my $boot   = $2;
            if ($product eq $name) {
                close $MFD;
                $this->{product} = $boot;
                return $boot;
            }
        }
    }
    $MFD -> close();
    $kiwi -> error (
        "Can't find product in $this->{gdata}->{KAnalyse}"
    );
    $kiwi -> failed();
    return;
}

#==========================================
# __populateRepos
#------------------------------------------
sub __populateRepos {
    # ...
    # find configured repositories on this system
    # ---
    my $this    = shift;
    my $kiwi    = $this->{kiwi};
    my $product = $this->{product};
    my $mounts  = $this->{mount};
    my $addr    = $this->{addrepo};
    my $addt    = $this->{addrepotype};
    my $adda    = $this->{addrepoalias};
    my $addp    = $this->{addrepoprio};
    my %osc;
    #==========================================
    # Store addon repo information if specified
    #------------------------------------------
    if ((defined $addr) && (defined $addt)) {
        my @addrepo     = @{$addr};
        my @addrepotype = @{$addt};
        my @addrepoalias= @{$adda};
        my @addrepoprio = @{$addp};
        foreach (my $count=0;$count <@addrepo; $count++) {
            my $source= $addrepo[$count];
            my $type  = $addrepotype[$count];
            my $alias = $addrepoalias[$count];
            my $prio  = $addrepoprio[$count];
            $osc{$product}{$source}{type} = $type;
            $osc{$product}{$source}{alias}= $alias;
            $osc{$product}{$source}{prio} = $prio;
        }
    }
    #==========================================
    # Obtain list from package manager
    #------------------------------------------
    my $list = KIWIQX::qxx ("bash -c 'LANG=POSIX zypper lr --details 2>&1'");
    my @list = split(/\n/,$list);
    my $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> error ("Failed to detect repository list: $list");
        $kiwi -> failed();
        return;
    }
    foreach my $repo (@list) {
        $repo =~ s/^\s+//g;
        if ($repo =~ /^\d/) {
            my @record = split(/\|/, $repo);
            my $enabled = $record[4];
            my $source  = $record[8];
            my $type    = $record[7];
            my $alias   = $record[1];
            my $prio    = $record[6];
            $enabled =~ s/^ +//; $enabled =~ s/ +$//;
            $source  =~ s/^ +//; $source  =~ s/ +$//;
            $type    =~ s/^ +//; $type    =~ s/ +$//;
            $alias   =~ s/^ +//; $alias   =~ s/ +$//; $alias =~ s/ $/:/g;
            $prio    =~ s/^ +//; $prio    =~ s/ +$//;
            my $origsrc = $source;
            if ($enabled =~ /Yes/) {
                #==========================================
                # handle special source type dvd|cd://
                #------------------------------------------
                if ($source =~ /^(dvd|cd):/) {
                    if (! -e "/dev/dvd") {
                        $kiwi -> warning ("DVD repo: /dev/dvd does not exist");
                        $kiwi -> skipped ();
                        next;
                    }
                    my $mpoint = KIWIQX::qxx ("mktemp -qdt kiwimpoint.XXXXXX");
                    my $result = $? >> 8;
                    if ($result != 0) {
                        $kiwi -> warning ("DVD tmpdir failed: $mpoint: $!");
                        $kiwi -> skipped ();
                        next;
                    }
                    chomp $mpoint;
                    my $data = KIWIQX::qxx ("mount -n /dev/dvd $mpoint 2>&1");
                    my $code = $? >> 8;
                    if ($code != 0) {
                        $kiwi -> warning ("DVD mount failed: $data");
                        $kiwi -> skipped ();
                        next;
                    }
                    $source = "dir://".$mpoint;
                    push @{$mounts},$mpoint;
                    $osc{$product}{$source}{flag} = "local";
                }
                #==========================================
                # handle special source type iso://
                #------------------------------------------
                elsif ($source =~ /iso=(.*\.iso)/) {
                    my $iso = $1;
                    if (! -e $iso) {
                        $kiwi -> warning ("ISO repo: $iso does not exist");
                        $kiwi -> skipped ();
                        next;
                    }
                    my $mpoint = KIWIQX::qxx ("mktemp -qdt kiwimpoint.XXXXXX");
                    my $result = $? >> 8;
                    if ($result != 0) {
                        $kiwi -> warning ("ISO tmpdir failed: $mpoint: $!");
                        $kiwi -> skipped ();
                        next;
                    }
                    chomp $mpoint;
                    my $data = KIWIQX::qxx ("mount -n -o loop $iso $mpoint 2>&1");
                    my $code = $? >> 8;
                    if ($code != 0) {
                        $kiwi -> warning ("ISO loop mount failed: $data");
                        $kiwi -> skipped ();
                        next;
                    }
                    $source = "dir://".$mpoint;
                    push @{$mounts},$mpoint;
                    $osc{$product}{$source}{flag} = "local";
                    $origsrc = "iso://$iso";
                }
                #==========================================
                # handle source type http|https|ftp://
                #------------------------------------------
                elsif ($source =~ /^(http|https|ftp)/) {
                    $osc{$product}{$source}{flag} = "remote";
                }
                #==========================================
                # handle all other source types
                #------------------------------------------
                else {
                    $osc{$product}{$source}{flag} = "unknown";
                }
                #==========================================
                # store repo information
                #------------------------------------------
                $osc{$product}{$source}{src}  = $origsrc;
                $osc{$product}{$source}{type} = $type;
                $osc{$product}{$source}{alias}= $alias;
                $osc{$product}{$source}{prio} = $prio;
            }
        }
    }
    $this->{source} = \%osc;
    if (! %osc) {
        $kiwi -> warning("No enabled repository found");
        $kiwi -> skipped();
    }
    return $this;
}

#==========================================
# __populatePackagesAndPatterns
#------------------------------------------
sub __populatePackagesAndPatterns {
    # ...
    # Find all packages installed on the system which doesn't
    # belong to any of the installed patterns. This works
    # only for systems which implementes a concept of patterns
    # ---
    my $this    = shift;
    my $product = $this->{product};
    my $kiwi    = $this->{kiwi};
    my %osc     = %{$this->{source}};
    my $system  = $this->{sys_analyser};
    my @urllist = ();
    my @alias   = ();
    my @patlist = ();
    my @rpmsort = ();
    my $code;
    #==========================================
    # clean pattern/package lists
    #------------------------------------------
    undef $this->{patterns};
    undef $this->{packages};
    #==========================================
    # get installed packages
    #------------------------------------------
    my $ilist = $system -> getInstalledPackages();
    if (! $ilist) {
        return;
    }
    #==========================================
    # find packages installed n times n > 1
    #------------------------------------------
    my @twice = ();
    my @ilist = sort keys %{$ilist};
    foreach my $installed (@ilist) {
        if ($ilist->{$installed}{count} > 1) {
            my $list = KIWIQX::qxx ("rpm -q $installed");
            my @list = split(/\n/,$list);
            push @twice,@list;
        }
    }
    if (@twice) {
        $this->{twice} = \@twice;
    }
    #==========================================
    # create URL list to lookup solvables
    #------------------------------------------
    foreach my $source (sort keys %{$osc{$product}}) {
        push (@urllist,$source);
        push (@alias,$osc{$product}{$source}{alias});
    }
    #==========================================
    # find all patterns and packs of patterns
    #------------------------------------------
    if (@urllist) {
        $kiwi -> info ("Creating System solvable from active repos...\n");
        my $opts = '-n --no-refresh';
        my $list = KIWIQX::qxx (
            "bash -c 'LANG=POSIX zypper $opts patterns --installed 2>&1'"
        );
        my @list = split(/\n/,$list);
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to obtain installed patterns: @list");
            $kiwi -> failed ();
            return;
        } else {
            my %pathash = ();
            foreach my $line (@list) {
                if ($line =~ /^i.*\|(.*)\|.*\|.*\|/) {
                    my $name = $1;
                    $name =~ s/^ +//g;
                    $name =~ s/ +$//g;
                    $pathash{"pattern:$name"} = "$name";
                }
            }
            @patlist = sort keys %pathash;
        }
        $this->{patterns} = \@patlist;
        my $psolve = KIWISatSolver -> new (
            \@patlist,\@urllist,"solve-patterns",
            undef,"quiet","onlyRequired","system-solvable",\@alias
        );
        my @result = ();
        if (! defined $psolve) {
            $kiwi -> failed ();
            $kiwi -> error  ("Failed to solve patterns");
            $kiwi -> failed ();
            return;
        }
        # /.../
        # solve the pattern list into a package list and
        # create a package list with packages _not_ part of the
        # pattern list.
        # ----
        $this->{solverProblem1}    = $psolve -> getProblemInfo();
        $this->{solverFailedJobs1} = $psolve -> getFailedJobs();
        if ($psolve -> getProblemsCount()) {
            $kiwi -> warning ("Pattern problems found check in report !\n");
            $kiwi -> info ($this->{solverProblem1});
        }
        my @patternPackages = $psolve -> getPackages();
        foreach my $installed (@ilist) {
            my $inpattern = 0;
            foreach my $p (@patternPackages) {
                if ($installed eq $p) {
                    $inpattern = 1; last;
                }
            }
            if (! $inpattern) {
                push (@result,$installed);
            }
        }
        # /.../
        # walk through the non pattern based packages and solve
        # them again. packages which are not part of the base
        # repository will be ignored. This might be a problem
        # if the package comes from a non base repository.
        # The solved list is again checked with the pattern
        # package list and the result is returned
        # ----
        my @solved_packages = ();
        my $pool = $psolve -> getPool();
        if (@result) {
            my $xsolve = KIWISatSolver -> new (
                \@result,\@urllist,"solve-packages",
                $pool,"quiet","onlyRequired","system-solvable",\@alias
            );
            if (! defined $xsolve) {
                $kiwi -> error  ("Failed to solve packages");
                $kiwi -> failed ();
                return;
            }
            $this->{solverProblem2}    = $xsolve -> getProblemInfo();
            $this->{solverFailedJobs2} = $xsolve -> getFailedJobs();
            if ($xsolve -> getProblemsCount()) {
                $kiwi -> warning ("Package problems found check in report !\n");
                $kiwi -> info ($this->{solverProblem2});
            }
            @result = $xsolve -> getPackages();
            foreach my $package (@result) {
                my $inpattern = 0;
                foreach my $tobeinstalled (@patternPackages) {
                    if ($tobeinstalled eq $package) {
                        $inpattern = 1; last;
                    }
                }
                if (! $inpattern) {
                    push (@solved_packages,$package);
                }
            }
            $this->{packages} = \@solved_packages;
        }
        # /.../
        # Walk through the list of installed packages and compare them
        # with the list of solved required packages. packages which are
        # not installed but part of the solved required list seems to
        # be unwanted and should be added to the delete section
        # ----
        my @delete_packages = ();
        my $zsolve = KIWISatSolver -> new (
            \@ilist,\@urllist,"solve-packages",
            $pool,"quiet","onlyRequired","system-solvable",\@alias
        );
        my @installed_solved = $zsolve -> getPackages();
        foreach my $solved (@installed_solved) {
            my $found = 0;
            foreach my $installed (@ilist) {
                if ($installed eq $solved) {
                    $found = 1;
                    last;
                }
            }
            if (! $found) {
                push @delete_packages, $solved;
            }
        }
        $this->{delete_packages} = \@delete_packages;
    }
    return $this;
}

#==========================================
# __strip_list
#------------------------------------------
sub __strip_list {
    # ...
    # remove items specified in @del from the list
    # given in @in and return a new sorted list
    # ---
    my $this = shift;
    my $in   = shift;
    my $del  = shift;
    my @result;
    foreach my $in_item(@{$in}) {
        my $found = 0;
        foreach my $del_item (@{$del}) {
            if ($del_item eq $in_item) {
                $found = 1;
                last;
            }
        }
        if ($found == 0) {
            push @result, $in_item;
        }
    }
    @result = sort @result;
    return @result;
}

#==========================================
# __dumpSoftwareStack
#------------------------------------------
sub __dumpSoftwareStack {
    # ...
    # Collect information about packages, patterns and
    # repositories suitable to generate an system
    # description from it
    # ---
    my $this = shift;
    my $product = $this -> __populateOperatingSystemVersion();
    if (! $product) {
        return;
    }
    if (! $this -> __populateRepos()) {
        $this -> __cleanMount();
        return;
    }
    return $this -> __populatePackagesAndPatterns();
}

#==========================================
# __cleanMount
#------------------------------------------
sub __cleanMount {
    my $this   = shift;
    my @mounts = @{$this->{mount}};
    foreach my $mpoint (@mounts) {
        KIWIQX::qxx ("umount $mpoint 2>&1 && rmdir $mpoint");
    }
    return $this;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
    my $this = shift;
    return $this -> __cleanMount();
}

1;
