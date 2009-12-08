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
#               : for suse pattern and package solving tasks. As
#               : the satsolver is something SUSE specific the following
#               : code will only be used on systems where satsolver
#               : exists. The KIWIPattern module makes use of this
#               : module functions and will switch back to the old
#               : style pattern solving code if satsolver is not
#               : present
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
		require KIWI::SaT;
		KIWI::SaT -> import;
	};
	if ($@) {
		$KIWISatSolver::haveSaT = 0;
	}
	if (! $KIWISatSolver::haveSaT) {
		package KIWI::SaT;
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
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $solvable;  # sat solvable file name
	my $solver;    # sat solver object
	my $queue;     # sat job queue
	my @solved;    # solve result
	my @jobFailed; # failed jobs
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
		return undef;
	}
	if (! defined $pref) {
		$kiwi -> error ("--> Invalid package/pattern/product reference");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $urlref) {
		$kiwi -> error ("--> Invalid repository URL reference");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Create and cache sat solvable
	#------------------------------------------
	if ((! defined $repo) || (! defined $pool)) {
		$solvable = KIWIXML::getInstSourceSatSolvable ($kiwi,$urlref);
		if (! defined $solvable) {
			return undef;
		}
		#==========================================
		# Create SaT repository and job queue
		#------------------------------------------
		if (! open (FD,$solvable)) {
			$kiwi -> error  ("--> Couldn't open solvable: $!");
			$kiwi -> failed ();
			return undef;
		}
		$pool = new KIWI::SaT::_Pool;
		$repo = $pool -> createRepo('repo');
		$repo -> addSolvable (*FD); close FD;
	}
	$solver = new KIWI::SaT::Solver ($pool);
	$pool -> initializeLookupTable();
	$queue = new KIWI::SaT::Queue;
	foreach my $p (@{$pref}) {
		my $name = $p;
		if (! defined $solvep) {
			$name = "pattern:".$p;
		}
		my $id = $pool -> selectSolvable ($repo,$solver,$name);
		if (! $id) {
			$kiwi -> warning ("--> Failed to queue job: $name");
			$kiwi -> skipped ();
			push @jobFailed, $name;
			next;
		}
		$queue -> queuePush ( $KIWI::SaT::SOLVER_INSTALL_SOLVABLE );
		$queue -> queuePush ( $id );
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}    = $kiwi;
	$this->{queue}   = $queue;
	$this->{solver}  = $solver;
	$this->{failed}  = \@jobFailed;
	#==========================================
	# Solve the job(s)
	#------------------------------------------
	$solver -> solve ($queue);
	if ($this -> getProblemsCount()) {
		my $solution = $this -> getSolutions();
		$kiwi -> warning ("--> Solver Problems:\n$solution");
		$this->{problem} = "$solution";
	}
	my $size = $solver -> getInstallSizeKBytes();
	my $list = $solver -> getInstallList ($pool);
	my @plist= ();
	my %slist= ();
	my $count= 0;
	my $pprev;
	foreach my $name (@{$list}) {
		if ($count == 0) {
			push @plist,$name;
			$pprev = $name;
			$count = 1;
		} else {
			$slist{$pprev} = "$name";
			$count = 0;
		}
	}
	foreach my $name (@plist) {
		if ($name =~ /^(pattern|product):(.*)/) {
			my $type = $1;
			my $text = $2;
			if (! defined $quiet) {
				$kiwi -> info ("Including $type $text");
				$kiwi -> done ();
			}
		} else {
			push (@solved,$name);
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{size}    = $size;
	$this->{urllist} = $urlref;
	$this->{plist}   = $pref;
	$this->{repo}    = $repo;
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
	return $solver->getProblemsCount();
}

#==========================================
# getSolutions
#------------------------------------------
sub getSolutions {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $solver = $this->{solver};
	my $queue  = $this->{queue};
	my $oldout;
	if (! $solver->getProblemsCount()) {
		return undef;
	}
	my $solution = $solver->getSolutions ($queue);
	local $/;
	if (! open (FD, "<$solution")) {
		$kiwi -> error  ("Can't open $solution for reading: $!");
		$kiwi -> failed ();
		unlink $solution;
		return undef;
	}
	my $result = <FD>; close FD;
	unlink $solution;
	return $result;
}

#==========================================
# getInstallSizeKBytes
#------------------------------------------
sub getInstallSizeKBytes {
	# /.../
	# return install size in kB of the solved
	# package list
	# ----
	my $this = shift;
	return $this->{size};
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

1;
