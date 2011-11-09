#================
# FILE          : KIWISatSolver.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
use Carp qw (cluck);
use KIWILog;
use KIWIQX;

#==========================================
# Plugins
#------------------------------------------
BEGIN {
	$KIWISatSolver::haveSaT = 1;
	eval {
		require satsolver;
		satsolver -> import;
	};
	if ($@) {
		$KIWISatSolver::haveSaT = 0;
	}
	if (! $KIWISatSolver::haveSaT) {
		package satsolver;
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
	my $kiwi    = shift;
	my $pref    = shift;
	my $urlref  = shift;
	my $solvep  = shift;
	my $repo    = shift;
	my $pool    = shift;
	my $quiet   = shift;
	my $ptype   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $solvable;  # sat solvable file name
	my $solver;    # sat solver object
	my @solved;    # solve result
	my @jobFailed; # failed jobs
	my $arch;      # system architecture
	my $job;       # job queue
	my $problems;  # solver problems
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	if ((! defined $repo) || (! defined $pool)) {
		if (! defined $quiet) {
			$kiwi -> info ("Setting up SaT solver...\n");
		}
	}
	if (! $KIWISatSolver::haveSaT) {
		$kiwi -> error ("--> No SaT plugin installed");
		$kiwi -> failed ();
		return;
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
	if (! defined $ptype) {
		$ptype = "onlyRequired";
	}
	#==========================================
	# Create and cache sat solvable
	#------------------------------------------
	if ((! defined $repo) || (! defined $pool)) {
		$solvable = KIWIXML::getInstSourceSatSolvable ($kiwi,$urlref);
		if (! defined $solvable) {
			return;
		}
		#==========================================
		# Create SaT repository
		#------------------------------------------
		my $FD;
		if (! open ($FD, '<' ,$solvable)) {
			$kiwi -> error  ("--> Couldn't open solvable: $!");
			$kiwi -> failed ();
			return;
		}
		close $FD;
		$pool = new satsolver::Pool;
		$arch = qx (uname -m); chomp $arch;
		$pool -> set_arch ($arch);
		$repo = $pool -> create_repo('repo');
		$repo -> add_solv ($solvable);
	}
	#==========================================
	# Create SaT Solver and jobs
	#------------------------------------------
	$solver = new satsolver::Solver ($pool);
	if ($ptype ne "plusRecommended") {
		$solver -> set_dont_install_recommended(1);
	}
	$pool -> prepare();
	$job = $pool->create_request();
	foreach my $p (@{$pref}) {
		my @names = $p;
		if (! defined $solvep) {
			push (@names, "pattern:".$p);
			push (@names, "patterns-openSUSE-".$p);
		}
		my $id   = 0;
		my $item = "";
		foreach my $name (@names) {
			my $item = $pool->find($name);
			if ((! $item) && (! $quiet)) {
				$kiwi -> warning ("--> Failed to queue job: $name");
				$kiwi -> skipped ();
				push @jobFailed, $name;
				next;
			}
			$job -> install ($item);
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}    = $kiwi;
	$this->{solver}  = $solver;
	$this->{repo}    = $repo;
	$this->{failed}  = \@jobFailed;
	#==========================================
	# Solve the job(s)
	#------------------------------------------
	$solver -> solve ($job);
	#==========================================
	# Check for problems
	#------------------------------------------
	$problems = $solver->problems_count();
	if ($problems) {
		$kiwi -> warning ("--> Solver Problems ! Here are the solutions:\n");
		my @problem_list = $solver->problems ($job);
		my $count = 1;
		my $info_string;
		foreach my $p (@problem_list) {
			$info_string .= sprintf "\nProblem $count:\n";
			$info_string .= sprintf "====================================\n";
			my $problem_string = $p->string();
			$info_string .= sprintf "$problem_string\n";
			my @solutions = $p->solutions();
			foreach my $s (@solutions) {
				my $solution_string = $s->string();
				$info_string .= sprintf "$solution_string\n";
			}
			$count++;
		}
		$this->{problem} = $info_string;
		print $info_string;
	}
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
	$this->{solfile} = $solvable;
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
# getRepo
#------------------------------------------
sub getRepo {
	# /.../
	# return satsolver repo object
	# ----
	my $this = shift;
	return $this->{repo};
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
	return $solver->problems_count();
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
	my $repo   = $this->{repo};
	my $solver = $this->{solver};
	my $sum    = 0;
	my @a = $solver->installs(1);
	for my $solvable (@a) {
		my $size = $solvable->attr_values("solvable:installsize");
		$sum += $size;
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
	my $repo   = $this->{repo};
	my $solver = $this->{solver};
	my %result = ();
	my @a = $solver->installs(1);
	for my $solvable (@a) {
		my $arch = $solvable->attr_values("solvable:arch");
		my $size = $solvable->attr_values("solvable:installsize");
		my $ver  = $solvable->attr_values("solvable:evr");
		my $name = $solvable->attr_values("solvable:name");
		$result{$name} = "$size:$arch:$ver";
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
	unlink $this->{solfile};
	return $this;
}

1;
