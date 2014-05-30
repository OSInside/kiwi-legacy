#================
# FILE          : KIWISatSolver.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to integrate the sat solver
#               : for suse pattern and package solving tasks.
#               : it is used for package managers which doesn't know
#               : about patterns and also for the kiwi info module
#               :
# STATUS        : Development
#----------------
package KIWISatSolver;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use KIWILog;
use KIWIQX;

#==========================================
# Plugins
#------------------------------------------
BEGIN {
	$KIWISatSolver::haveSaT = 1;
	$KIWISatSolver::libsatsolver = 1;
	$KIWISatSolver::libsolv = 1;
	eval {
		require solv;
		solv -> import;
	};
	if ($@) {
		# OK: no libsolv binding
		$KIWISatSolver::libsolv = 0;
	}
	eval {
		require satsolver;
		satsolver -> import;
	};
	if ($@) {
		# OK: no libsatsolver binding
		$KIWISatSolver::libsatsolver = 0;
	}
	if ((! $KIWISatSolver::libsatsolver) && (! $KIWISatSolver::libsolv)) {
		# No solver bindings at all, no fun
		$KIWISatSolver::haveSaT = 0;
	}
}

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct a new KIWISatSolver object if satsolver is present.
	# The solver object is used to queue product, pattern, and package solve
	# requests which gets solved by the contents of a sat solvable
	# which is either created by the repository metadata contents
	# or used directly from the repository if it is provided
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
	my $pref    = shift;
	my $urlref  = shift;
	my $solvep  = shift;
	my $pool    = shift;
	my $quiet   = shift;
	my $ptype   = shift;
	my $solvtype= shift;
	my $aliases = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi    = KIWILog -> instance();
	my $solver;    # sat solver object
	my @solved;    # solve result
	my $failed;    # failed jobs
	my $job;       # job queue
	my $problems;  # solver problems
	if (! -d "/var/cache/kiwi/satsolver") {
		KIWIQX::qxx ("mkdir -p /var/cache/kiwi/satsolver");
	}
	if (! defined $pool) {
		if (! defined $quiet) {
			$kiwi -> info ("Setting up SaT solver...\n");
			if ($KIWISatSolver::libsolv) {
				$kiwi -> info ("--> Using libsolv binding\n");
			} elsif ($KIWISatSolver::libsatsolver) {
				$kiwi -> info ("--> Using libsatsolver binding\n");
			}
		}
	}
	if (! $KIWISatSolver::haveSaT) {
		$kiwi -> error ("--> No SaT plugin found");
		$kiwi -> failed ();
		$kiwi -> error (
			"--> Check if perl-solv or perl-satsolver is installed"
		);
		$kiwi -> failed ();
		return;
	} elsif ($KIWISatSolver::libsatsolver) {
		my $satsolver = (glob ("/usr/lib/perl5/vendor_perl/*/satsolver.pm"))[0];
		my $legacy    = 1;
		if ($satsolver) {
				# /.../
				# check for solutions() method provided with this version of
				# perl-satsolver. It must exist in order to work with kiwi
				# ----
				system ("grep -q '^\*solutions =' $satsolver");
				$legacy = $? >> 8;
		}
		if ($legacy) {
			$kiwi -> error ("--> Can't find solutions() method in SaT plugin");
			$kiwi -> failed ();
			$kiwi -> error ("--> perl-satsolver >= 0.42 is required");
			$kiwi -> failed ();
			return;
		}
	}
	if (! defined $pref) {
		$kiwi -> error ("--> Invalid package/pattern/product reference");
		$kiwi -> failed ();
		return;
	}
	if (! defined $urlref) {
		$kiwi -> error ("--> Invalid repository URL reference");
		$kiwi -> failed ();
		return;
	}
	if (($solvtype) && ($solvtype eq "system-solvable") && (! $aliases)) {
		$kiwi -> error ("--> Need repo aliases in system-solvable mode");
		$kiwi -> failed ();
		return;
	}
	if (! defined $ptype) {
		$ptype = "onlyRequired";
	}
	#==========================================
	# Build job hash
	#------------------------------------------
	my %jobs = ();
	foreach my $item (@{$pref}) {
		if ($item =~ /^product:/) {
			# can't solve products...
			next;
		}
		if (! defined $solvep) {
			# given names should be solved as patterns...
			$jobs{"pattern:".$item} = $item;
			$jobs{"patterns-openSUSE-".$item} = $item;
		} else {
			# given names are passed directly...
			$jobs{$item} = $item;
		}
	}
	#==========================================
	# Create and cache sat solvable
	#------------------------------------------
	if (! defined $pool) {
		#==========================================
		# Create list of solvables
		#------------------------------------------
		my @files   = ();
		my $solfile = '/var/cache/kiwi/satsolver/merged.solv';
		if (($solvtype) && ($solvtype eq "system-solvable")) {
			#==========================================
			# read solv files locally stored by zypper
			#------------------------------------------
			my $sys_solve = '/var/cache/zypp/solv/';
			foreach my $alias (@{$aliases}) {
				my $solv_file = $sys_solve.$alias.'/solv';
				if (! -e $solv_file) {
					$kiwi -> error  ("--> Solvable for $alias not found");
					$kiwi -> failed ();
					$kiwi -> error  ("--> Run zypper refresh first");
					$kiwi -> failed ();
					return;
				}
				push @files, quotemeta($solv_file);
			}
		} else {
			#==========================================
			# download repo metadata and turn into solv
			#------------------------------------------
			my $solvable = KIWIXML::getInstSourceSatSolvable ($urlref);
			if (! defined $solvable) {
				return;
			}
			@files = keys %{$solvable};
		}
		#==========================================
		# merge solvables into one
		#------------------------------------------
		if (! @files) {
			$kiwi -> error  ("--> No repository solvables found");
			$kiwi -> failed ();
			return;
		}
		if (@files > 1) {
			KIWIQX::qxx ("mergesolv @files > $solfile");
		} else {
			KIWIQX::qxx ("cp @files $solfile 2>&1");
		}
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("--> Couldn't merge/copy solv files");
			$kiwi -> failed ();
			return;
		}
		$this->{solfile} = $solfile;
		#==========================================
		# Create SaT pool
		#------------------------------------------
		$pool = $this -> __createPool();
		#==========================================
		# Create SaT repos
		#------------------------------------------
		if (($solvtype) && ($solvtype =~ /merged|system/)) {
			$this -> __createRepo($pool,$solfile);
		} else {
			foreach my $solfile (@files) {
				$this -> __createRepo($pool,$solfile);
			}
		}
	}
	#==========================================
	# Create SaT Solver
	#------------------------------------------
	$solver = $this -> __createSolver($pool,$ptype);
	#==========================================
	# Create SaT job queue
	#------------------------------------------
	($job,$failed) = $this -> __createJobs($pool,\%jobs);
	if ($failed) {
		foreach my $name (@{$failed}) {
			if (! $quiet) {
				$kiwi -> warning ("--> Failed to queue job: $name");
				$kiwi -> skipped ();
			}
		}
	}
	#==========================================
	# Solve the job(s)
	#------------------------------------------
	$this->{problems} = $this -> __solveJobs($job,$solver);
	#==========================================
	# Check for problems
	#------------------------------------------
	$problems = $this -> __getProblems($solver,$job);
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{problem} = $problems;
	$this->{kiwi}    = $kiwi;
	$this->{solver}  = $solver;
	$this->{failed}  = $failed;
	#==========================================
	# Handle result lists
	#------------------------------------------
	my $size  = $this -> getInstallSizeKBytes();
	my %list  = $this -> getInstallList ();
	my @plist = ();
	my %slist = ();
	my %info;
	if (%list) {
		foreach my $package (keys %list) {
			push (@plist,$package);
			$slist{$package} = $list{$package};
		}
		foreach my $name (@plist) {
			my $type = "package";
			my $item = $name;
			if ($name =~ /^patterns-openSUSE-(.*)/) {
				$item = $1;
				$type = "pattern";
			} elsif ($name =~ /^pattern:(.*)/) {
				$item = $1;
				$type = "pattern";
			} elsif ($name =~ /^product:(.*)/) {
				$item = $1;
				$type = "product";
			} else {
				push (@solved,$name);
			}
			if ($type ne "package") {
				$info{$item} = $type;
			}
		}
		if ((%info) && (! defined $quiet)) {
			foreach my $item (keys %info) {
				$kiwi -> info ("Including $info{$item} $item");
				$kiwi -> done ();
			}
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{size}    = $size;
	$this->{urllist} = $urlref;
	$this->{plist}   = $pref;
	$this->{pool}    = $pool;
	$this->{result}  = \@solved;
	$this->{meta}    = \%slist;
	return $this;
}

#==========================================
# getProblemInfo
#------------------------------------------
sub getProblemInfo {
	# /.../
	# return problem solution text
	# ----
	my $this = shift;
	return $this->{problem};
}

#==========================================
# getFailedJobs
#------------------------------------------
sub getFailedJobs {
	# /.../
	# return package names of failed jobs
	# ----
	my $this = shift;
	return $this->{failed};
}

#==========================================
# getSolfile
#------------------------------------------
sub getSolfile {
	# /.../
	# return satsolver index file created or used
	# by an object of this class
	# ----
	my $this = shift;
	return $this->{solfile};
}

#==========================================
# getPool
#------------------------------------------
sub getPool {
	# /.../
	# return satsolver pool object
	# ----
	my $this = shift;
	return $this->{pool};
}

#==========================================
# getProblemsCount
#------------------------------------------
sub getProblemsCount {
	my $this   = shift;
	my $solver = $this->{solver};
	return $this -> __getProblemsCount($solver);
}

#==========================================
# getInstallSizeKBytes
#------------------------------------------
sub getInstallSizeKBytes {
	# /.../
	# return install size in kB of the solved
	# package list
	# ----
	my $this   = shift;
	my $solver = $this->{solver};
	my %attr   = $this -> __getPackageAttributes($solver);
	my $sum    = 0;
	foreach my $package (keys %attr) {
		my $size = $attr{$package}{installsize};
		if ($size) {
			$sum += $size;
		}
	}
	return $sum;
}

#==========================================
# getInstallList
#------------------------------------------
sub getInstallList {
	# /.../
	# return package list and attributes
	# ----
	my $this   = shift;
	my $solver = $this->{solver};
	my %attr   = $this -> __getPackageAttributes($solver);
	my %result = ();
	foreach my $package (keys %attr) {
		my $arch = $attr{$package}{arch};
		my $size = $attr{$package}{installsize};
		my $ver  = $attr{$package}{evr};
		my $chs  = $attr{$package}{checksum};
		my $url  = $attr{$package}{url};
		$result{$package} = "$size:$arch:$ver:$chs:$url";
	}
	return %result;
}

#==========================================
# getMetaData
#------------------------------------------
sub getMetaData {
	# /.../
	# return meta data hash, containing the install
	# size per package
	# ----
	my $this = shift;
	return %{$this->{meta}};
}

#==========================================
# getPackages
#------------------------------------------
sub getPackages {
	# /.../
	# return solved list
	# ----
	my $this   = shift;
	my $result = $this->{result};
	my @result = ();
	if (defined $result) {
		return @{$result};
	}
	return @result;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this = shift;
	if ($this->{solfile}) {
		unlink $this->{solfile};
	}
	return $this;
}

#==========================================
# Internal methods
#------------------------------------------
#==========================================
# __createPool
#------------------------------------------
sub __createPool {
	# /.../
	# Create a new solver Pool
	# ----
	my $this = shift;
	my $arch = qx(uname -m);
	chomp $arch;
	if ($arch eq "armv7l") {
		$arch = "armv7hl";
	}
	if ($arch eq "armv6l") {
		$arch = "armv6hl";
	}
	my $pool;
	if ($ENV{KIWI_REPO_INFO_ARCH}) {
		$arch = $ENV{KIWI_REPO_INFO_ARCH};
	}
	if ($KIWISatSolver::libsolv) {
		$pool = solv::Pool -> new();
		$pool->setarch ($arch);
	} elsif ($KIWISatSolver::libsatsolver) {
		$pool = satsolver::Pool -> new();
		$pool->set_allow_self_conflicts(1);
		$pool->set_arch ($arch);
		$pool->prepare();
	}
	return $pool;
}

#==========================================
# __createRepo
#------------------------------------------
sub __createRepo {
	my $this = shift;
	my $pool = shift;
	my $solv = shift;
	my $repo;
	if ($KIWISatSolver::libsolv) {
		$repo = $pool->add_repo($solv);
		$repo->add_solv($solv);
		$pool->addfileprovides();
		$pool->createwhatprovides();
	} elsif ($KIWISatSolver::libsatsolver) {
		$repo = $pool->create_repo($solv);
		$repo->add_solv($solv);
	}
	return $repo;
}

#==========================================
# __createSolver
#------------------------------------------
sub __createSolver {
	my $this = shift;
	my $pool = shift;
	my $ptype= shift;
	my $solvRecommends = 1;
	my $solver;
	if ($ptype ne "plusRecommended") {
		$solvRecommends = 0;
	}
	if ($KIWISatSolver::libsolv) {
		# TODO: set_dont_install_recommended does not exist in libsolv
		$solver = $pool->Solver();
	} elsif ($KIWISatSolver::libsatsolver) {
		$solver = satsolver::Solver->new($pool);
		if (! $solvRecommends) {
			$solver->set_dont_install_recommended(1);
		}
	}
	return $solver;
}

#==========================================
# __createJobs
#------------------------------------------
sub __createJobs {
	my $this = shift;
	my $pool = shift;
	my $jobs = shift;
	my @fail;
	my $job;
	if ($KIWISatSolver::libsolv) {
		my @job_list = ();
		foreach my $name (sort keys %{$jobs}) {
			my $item = $pool->select($name, $solv::Selection::SELECTION_NAME);
			if ($item->isempty()) {
				push @fail, $name;
				next;
			}
			push @job_list, $item->jobs($solv::Job::SOLVER_INSTALL);
		}
		$job = \@job_list;
	} elsif ($KIWISatSolver::libsatsolver) {
		$job = $pool->create_request();
		foreach my $name (sort keys %{$jobs}) {
			my $item = $pool->find($name);
			if (! $item) {
				push @fail,$name;
				next;
			}
			$job->install ($item);
		}
	}
	return ($job,\@fail);
}

#==========================================
# __solveJobs
#------------------------------------------
sub __solveJobs {
	my $this   = shift;
	my $job    = shift;
	my $solver = shift;
	my @result;
	if ($KIWISatSolver::libsolv) {
		@result = $solver->solve($job);
	} elsif ($KIWISatSolver::libsatsolver) {
		@result = $solver->solve ($job);
	}
	return \@result;
}

#==========================================
# __getProblems
#------------------------------------------
sub __getProblems {
	my $this   = shift;
	my $solver = shift;
	my $job    = shift;
	my $infotext;
	if ($KIWISatSolver::libsolv) {
		return if ! $this->{problems};
		my @p_list  = @{$this->{problems}};
		my $p_count = @p_list;
		for my $problem (@p_list) {
			my $p_id = $problem->{id};
			$infotext .= sprintf "\nProblem $p_id/$p_count:\n";
			$infotext .= sprintf "====================================\n";
			my $problem_string = $problem->findproblemrule()
				->info()->problemstr();
			$infotext .= sprintf "$problem_string\n";
			my @solutions = $problem->solutions();
			for my $solution (@solutions) {
				$infotext .= sprintf "  Solution $solution->{id}:\n";
				for my $element ($solution->elements(1)) {
					$infotext .= sprintf "  - ".$element->str()."\n";
				}
			}
		}
	} elsif ($KIWISatSolver::libsatsolver) {
		my $problems = $solver->problems_count();
		if (! $problems) {
			return;
		}
		my @problem_list = $solver->problems ($job);
		my $count = 1;
		foreach my $p (@problem_list) {
			$infotext .= sprintf "\nProblem $count:\n";
			$infotext .= sprintf "====================================\n";
			my $problem_string = $p->string();
			$infotext .= sprintf "$problem_string\n";
			my @solutions = $p->solutions();
			foreach my $s (@solutions) {
				my $solution_string = $s->string();
				$infotext .= sprintf "$solution_string\n";
			}
			$count++;
		}
	}
	return $infotext;
}

#==========================================
# __getProblemsCount
#------------------------------------------
sub __getProblemsCount {
	my $this   = shift;
	my $solver = shift;
	my $count  = 0;
	if ($KIWISatSolver::libsolv) {
		if ($this->{problems}) {
			$count = @{$this->{problems}}
		}
	} elsif ($KIWISatSolver::libsatsolver) {
		$count = $solver->problems_count();
	}
	return $count;
}

#==========================================
# __getPackageAttributes
#------------------------------------------
sub __getPackageAttributes {
	my $this   = shift;
	my $solver = shift;
	my %result = ();
	if ($KIWISatSolver::libsolv) {
		my $transaction = $solver->transaction();
		if ($transaction->isempty()) {
			return %result;
		}
		for my $solvable ($transaction->newpackages()) {
			my $name = $solvable->lookup_str($solv::SOLVABLE_NAME);
			$result{$name}{url} = $solvable->{repo}{name};
			$result{$name}{installsize}
				= $solvable->lookup_num($solv::SOLVABLE_INSTALLSIZE);
			$result{$name}{arch}
				= $solvable->lookup_str($solv::SOLVABLE_ARCH);
			$result{$name}{evr}
				= $solvable->lookup_str($solv::SOLVABLE_EVR);
			my $checksum
				= $solvable->lookup_checksum($solv::SOLVABLE_CHECKSUM);
			my $chst = $checksum->{type};
			if ($chst) {
				if ($chst == $solv::REPOKEY_TYPE_SHA256) {
					$chst = "sha256";
				} elsif ($chst == $solv::REPOKEY_TYPE_MD5) {
					$chst = "md5";
				} elsif ($chst == $solv::REPOKEY_TYPE_SHA1) {
					$chst = "sha1";
				}
				$result{$name}{checksum} = $chst."=".$checksum->hex();
			} else {
				$result{$name}{checksum} = "unknown";
			}
		}
	} elsif ($KIWISatSolver::libsatsolver) {
		my @a = $solver->installs(1);
		for my $solvable (@a) {
			my $arch = $solvable->attr_values("solvable:arch");
			my $size = $solvable->attr_values("solvable:installsize");
			my $ver  = $solvable->attr_values("solvable:evr");
			my $name = $solvable->attr_values("solvable:name");
			my $chs  = $solvable->attr_values("solvable:checksum");
			my $url  = $solvable->repo->name();
			my $chst = "unknown";
			my $di   = satsolver::Dataiterator -> new (
				$solvable->repo->pool,$solvable->repo,
				undef,0,$solvable,"solvable:checksum"
			);
			while ($di->step() != 0) {
				$chst = $di->key()->type_id();
				if ($chst == $satsolver::REPOKEY_TYPE_SHA256) {
					$chst = "sha256";
				} elsif ($chst == $satsolver::REPOKEY_TYPE_MD5) {
					$chst = "md5";
				} elsif ($chst == $satsolver::REPOKEY_TYPE_SHA1) {
					$chst = "sha1";
				}
			}
			if (! $chs) {
				$chs = "unknown";
			}
			if (! $size) {
				$size = 0;
			}
			$chs = $chst."=".$chs;
			$result{$name}{installsize} = $size;
			$result{$name}{arch} = $arch;
			$result{$name}{evr} = $ver;
			$result{$name}{checksum} = $chs;
			$result{$name}{url} = $url;
		}
	}
	return %result;
}

1;
