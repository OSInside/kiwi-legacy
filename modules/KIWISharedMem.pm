#================
# FILE          : KIWISharedMem.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide shared memory
#               : operations used in the log server process
#               : the segment will contain information used by
#               : multiple processes
#               :
#               :
# STATUS        : Development
#----------------
package KIWISharedMem;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use IPC::SysV qw(IPC_PRIVATE IPC_RMID IPC_CREAT S_IRWXU);
use IPC::Semaphore;
use KIWIQX qw (qxx);
sub MAXBUF { return 2000; }

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWISharedMem object which is used to allow
	# operations on a shared memory segment
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
	my $kiwi  = shift;
	my $value = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $key = shmget(IPC_PRIVATE, MAXBUF, S_IRWXU);
	if (! defined $key) {
		$kiwi -> error  ("shmget: $!");
		$kiwi -> failed ();
		return;
	}
	my $sem = IPC::Semaphore -> new (IPC_PRIVATE, 1, S_IRWXU | IPC_CREAT);
	if (! defined $sem) {
		$kiwi -> error  ("IPC::Semaphore->new: $!");
		$kiwi -> failed ();
		return;
	}
	if (! $sem -> setval (0,1)) {
		$kiwi -> error  ("sem setval: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}   = $kiwi;
	$this->{OWNER}  = $$;
	$this->{SHMKEY} = $key;
	$this->{SEMA}   = $sem;

	#==========================================
	# Store data to segment
	#------------------------------------------
	$this -> unlock;
	$this -> put ($value);
	return $this;
}

#==========================================
# get
#------------------------------------------
sub get {
	my @list = @_;
	my $this = shift @list;
	$this -> lockme;
	my $value = $this -> peek(@list);
	$this -> unlock;
	return $value;
}

#==========================================
# peek
#------------------------------------------
sub peek {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $buff = '';
	if (! shmread($this->{SHMKEY}, $buff, 0, MAXBUF)) {
		$kiwi -> error  ("shmread: $!");
		$kiwi -> failed ();
		return;
	}
	substr($buff, index($buff, "\0")) = '';
	return $buff;
}

#==========================================
# put
#------------------------------------------
sub put {
	my @list = @_;
	my $this = shift @list;
	$this -> lockme;
	$this -> poke(@list);
	$this -> unlock;
	return;
}

#==========================================
# poke
#------------------------------------------
sub poke {
	my ($this,$msg) = @_;
	my $kiwi = $this->{kiwi};
	if (! shmwrite($this->{SHMKEY}, $msg, 0, MAXBUF)) {
		$kiwi -> error  ("shmwrite: $!");
		$kiwi -> failed ();
		return;
	}
	return $this;
}

#==========================================
# lockme
#------------------------------------------
sub lockme {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	if (! $this->{SEMA}->op(0,-1,0)) {
		$kiwi -> error  ("semop: $!");
		$kiwi -> failed ();
		return;
	}
	return $this;
}

#==========================================
# unlock
#------------------------------------------
sub unlock {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	if (! $this->{SEMA}->op(0,1,0)) {
		$kiwi -> error  ("semop: $!");
		$kiwi -> failed ();
		return;
	}
	return $this;
}

#==========================================
# closeSegment
#------------------------------------------
sub closeSegment {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	if (! defined $this->{OWNER}) {
		$this->{OWNER} = 0;
	}
	return unless $this->{OWNER} == $$;  # avoid dup dealloc
	if (! shmctl($this->{SHMKEY}, IPC_RMID, 0)) {
		$kiwi -> loginfo ("shmctl RMID: $!\n");
	}
	if (! $this->{SEMA}->remove()) {
		$kiwi -> loginfo ("sema->remove: $!\n");
	}
	return $this;
}

#==========================================
# DESTRUCTOR
#------------------------------------------
sub DESTROY {
	my $this = shift;
	$this -> closeSegment();
	return;
}

1;
