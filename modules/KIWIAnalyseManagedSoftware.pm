#================
# FILE          : KIWIAnalyseManagedSoftware.pm
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
package KIWIAnalyseManagedSoftware;
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
use KIWIQX qw (qxx);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIAnalyseManagedSoftware object which
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
	my $addr  = shift; # add repo list reference
	my $addt  = shift; # add repotype list reference
	my $adda  = shift; # add repoalias list reference
	my $addp  = shift; # add repoprio list reference
	my $skip  = shift; # skip package list reference
	my $cdata = shift; # cache data reference
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi   = KIWILog -> instance();
	my $global = KIWIGlobals -> instance();
	#==========================================
	# Store default packages to skip
	#------------------------------------------
	my @denyPacks = (
		'gpg-pubkey.*'
	);
	foreach my $s (@denyPacks) {
		push (@{$skip},$s);
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{gdata}       = $global -> getKiwiConfig();
	$this->{kiwi}        = $kiwi;
	$this->{skip}        = $skip;
	$this->{mount}       = [];
	$this->{cdata}       = $cdata;
	$this->{addrepo}     = $addr;
	$this->{addrepotype} = $addt;
	$this->{addrepoalias}= $adda;
	$this->{addrepoprio} = $addp;
	return $this;
}

#==========================================
# runQuery
#------------------------------------------
sub runQuery {
	# ...
	# Start the query for package managed software
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
	return $this -> __populatePackageList();
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
# getSolverProblems
#------------------------------------------
sub getSolverProblems {
	my $this = shift;
	my @result;
	if ((! $this->{solverProblem1})    &&
		(! $this->{solverFailedJobs1}) &&
		(! $this->{solverProblem2})    &&
		(! $this->{solverFailedJobs2})
	) {
		return;
	}
	@result = (
		$this->{solverProblem1},
		$this->{solverFailedJobs1},
		$this->{solverProblem2},
		$this->{solverFailedJobs2}
	);
	return \@result;
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
	my $VFD = FileHandle -> new();
	my $name;
	my $vers;
	my $plvl;
	if (! $VFD -> open ("/etc/products.d/baseproduct")) {
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
		if ($line =~ /<name>(.*)<\/name>/) {
			$name = $1;
		}
	}
	$VFD -> close();
	if ((! $name) || (! $vers)) {
		return;
	}
	if ($name eq 'SUSE_SLES') {
		$name = 'SUSE-Linux-Enterprise-Server';
	} elsif ($name eq 'SUSE_SLED') {
		$name = 'SUSE-Linux-Enterprise-Desktop';
	}
	if ($plvl) {
		$plvl = 'SP'.$plvl;
		$name = $name.'-'.$vers.'-'.$plvl;
	} else {
		$name = $name.'-'.$vers;
	}
	my $MFD = FileHandle -> new();
	if (! $MFD -> open ($this->{gdata}->{KAnalyse})) {
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
	# FIXME: move this into the KIWIManager backend
	my @list    = qxx ("bash -c 'LANG=POSIX zypper lr --details 2>&1'");
	chomp @list;
	my $code    = $? >> 8;
	if ($code != 0) {
		return;
	}
	foreach my $repo (@list) {
		$repo =~ s/^\s+//g;
		if ($repo =~ /^\d.*\|(.*)\|.*\|(.*)\|.*\|(.*)\|(.*)\|(.*)\|/) {
			my $enabled = $2;
			my $source  = $5;
			my $type    = $4;
			my $alias   = $1;
			my $prio    = $3;
			$enabled =~ s/^ +//; $enabled =~ s/ +$//;
			$source  =~ s/^ +//; $source  =~ s/ +$//;
			$type    =~ s/^ +//; $type    =~ s/ +$//;
			$alias   =~ s/^ +//; $alias   =~ s/ +$//; $alias =~ s/ $/-/g;
			$prio    =~ s/^ +//; $prio    =~ s/ +$//;
			my $origsrc = $source;
			if ($enabled eq "Yes") {
				#==========================================
				# handle special source type dvd|cd://
				#------------------------------------------
				if ($source =~ /^(dvd|cd):/) {
					if (! -e "/dev/dvd") {
						$kiwi -> warning ("DVD repo: /dev/dvd does not exist");
						$kiwi -> skipped ();
						next;
					}
					my $mpoint = qxx ("mktemp -qdt kiwimpoint.XXXXXX");
					my $result = $? >> 8;
					if ($result != 0) {
						$kiwi -> warning ("DVD tmpdir failed: $mpoint: $!");
						$kiwi -> skipped ();
						next;
					}
					chomp $mpoint;
					my $data = qxx ("mount -n /dev/dvd $mpoint 2>&1");
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
					my $mpoint = qxx ("mktemp -qdt kiwimpoint.XXXXXX");
					my $result = $? >> 8;
					if ($result != 0) {
						$kiwi -> warning ("ISO tmpdir failed: $mpoint: $!");
						$kiwi -> skipped ();
						next;
					}
					chomp $mpoint;
					my $data = qxx ("mount -n -o loop $iso $mpoint 2>&1");
					my $code = $? >> 8;
					if ($code != 0) {
						$kiwi -> warning ("ISO loop mount failed: $data");
						$kiwi -> skipped ();
						next;
					}
					$source = "dir://".$mpoint;
					push @{$mounts},$mpoint;
					$osc{$product}{$source}{flag} = "local";
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
	return $this;
}

#==========================================
# __populatePackageList
#------------------------------------------
sub __populatePackageList {
	# ...
	# Find all packages installed on the system which doesn't
	# belong to any of the installed patterns. This works
	# only for systems which implementes a concept of patterns
	# ---
	my $this    = shift;
	my $product = $this->{product};
	my $kiwi    = $this->{kiwi};
	my $skip    = $this->{skip};
	my %osc     = %{$this->{source}};
	my $cdata   = $this->{cdata};
	my @urllist = ();
	my @patlist = ();
	my @ilist   = ();
	my @rpmsort = ();
	my $code;
	#==========================================
	# clean pattern/package lists
	#------------------------------------------
	undef $this->{patterns};
	undef $this->{packages};
	#==========================================
	# search installed packages if not yet done
	#------------------------------------------
	$kiwi -> info ("Searching installed packages...\n");
	if (($cdata) && ($cdata->{rpmsort})) {
		$kiwi -> info ("--> reading from cache data");
		@ilist = @{$cdata->{rpmsort}};
		$kiwi -> done();
	} else {
		$kiwi -> info ("--> requesting from rpm database...");
		@ilist = qxx ('rpm -qa --qf "%{NAME}\n" | sort');
		chomp @ilist;
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to obtain installed packages");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
		@rpmsort = @ilist;
		$cdata->{rpmsort} = \@rpmsort;
	}
	#==========================================
	# find packages installed n times n > 1
	#------------------------------------------
	my %packages = ();
	my @twice = ();
	for (my $i=0;$i<@ilist;$i++) {
		my $p = $ilist[$i];
		my $inskip = 0;
		foreach my $s (@{$skip}) {
			if ($p =~ /$s/) {
				$inskip = 1; last;
			}
		}
		next if $inskip;
		$packages{$p}++;
	}
	foreach my $installed (sort keys %packages) {
		if ($packages{$installed} > 1) {
			my @list = qxx ("rpm -q $installed");
			chomp @list;
			push @twice,@list;
		}
	}
	if (@twice) {
		$this->{twice} = \@twice;
	}
	#==========================================
	# use uniq pac list for further processing
	#------------------------------------------
	@ilist = sort keys %packages;
	#==========================================
	# create URL list to lookup solvables
	#------------------------------------------
	foreach my $source (sort keys %{$osc{$product}}) {
		push (@urllist,$source);
	}
	#==========================================
	# find all patterns and packs of patterns 
	#------------------------------------------
	if (@urllist) {
		$kiwi -> info ("Creating System solvable from active repos...\n");
		# FIXME: move this into the KIWIManager backend
		my $opts = '-n --no-refresh';
		my @list = qxx (
			"bash -c 'LANG=POSIX zypper $opts patterns --installed 2>&1'"
		);
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
			undef,undef,"plusRecommended","merged-solvable"
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
		}
		my @packageList = $psolve -> getPackages();
		foreach my $installed (@ilist) {
			if (defined $skip) {
				my $inskip = 0;
				foreach my $s (@{$skip}) {
					if ($installed =~ /$s/) {
						$inskip = 1; last;
					}
				}
				next if $inskip;
			}
			my $inpattern = 0;
			foreach my $p (@packageList) {
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
		if (@result) {
			my @rest = ();
			my $pool = $psolve -> getPool();
			my $xsolve = KIWISatSolver -> new (
				\@result,\@urllist,"solve-packages",
				$pool,undef,"plusRecommended","merged-solvable"
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
			}
			@result = $xsolve -> getPackages();
			foreach my $p (@result) {
				my $inpattern = 0;
				foreach my $tobeinstalled (@packageList) {
					if ($tobeinstalled eq $p) {
						$inpattern = 1; last;
					}
				}
				if (! $inpattern) {
					push (@rest,$p);
				}
			}
			$this->{packages} = \@rest;
		}
	}
	return $this;
}


#==========================================
# __cleanMount
#------------------------------------------
sub __cleanMount {
	my $this   = shift;
	my @mounts = @{$this->{mount}};
	foreach my $mpoint (@mounts) {
		qxx ("umount $mpoint 2>&1 && rmdir $mpoint");
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
