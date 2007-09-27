#================
# FILE          : KIWISocket.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide socket 
#               : operations which can be used for setting
#               : up a milestone server
#               : 
#               :
# STATUS        : Development
#----------------
package KIWISocket;
#==========================================
# Modules
#------------------------------------------
use strict;
use KIWILog;
use FileHandle;
use Socket;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWISocket object which is used to create
	# a server socket for communication to the outside. The module
	# provides methods for writing reports based on XML and is used
	# to provide milestone information of the kiwi process
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
	my $kiwi = shift;
	my $port = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $server = $this -> serverSocket ($port);
	if (! defined $server) {
		return undef;
	}
	$SIG{CHLD} = \&KIWISocket::reaper;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}   = $kiwi;
	$this->{port}   = $port;
	$this->{server} = $server;
	return $this;
}

#==========================================
# serverSocket
#------------------------------------------
sub serverSocket {
	my $this  = shift;
	my $port  = shift;
	my $proto = getprotobyname("tcp");
	socket(FD, PF_INET, SOCK_STREAM, $proto) ||
		return undef;
	setsockopt(FD, SOL_SOCKET, SO_REUSEADDR, pack("l",1)) ||
		return undef;
	bind(FD, sockaddr_in($port,INADDR_ANY)) ||
		return undef;
	listen(FD,SOMAXCONN) ||
		return undef;
	return *FD;
}

#==========================================
# reaper
#------------------------------------------
sub reaper {
	my $waitedpid = wait;
	$SIG{CHLD} = \&KIWISocket::reaper;
	#print ("+++ reaped $waitedpid". ($? ? " with exit $?" : ""));
}

#==========================================
# acceptConnection
#------------------------------------------
sub acceptConnection {
	my $this    = shift;
	my $server  = $this->{server};
	my $paddr   = accept (FD,$server);
	if (! $paddr) {
		return undef;
	}
	$this->{client} = *FD;
	return $this;
}

#==========================================
# write
#------------------------------------------
sub write {
	my $this    = shift;
	my $message = shift;
	my $client  = $this->{client};
	my $pid;
	if (! defined ($pid = fork)) {
		return undef;
	} elsif ($pid) {
		# nothing to do for the parent here...
		return $this;
	}
	print $client $message;
	flush $client;
	exit 0;
}

#==========================================
# read
#------------------------------------------
sub read {
	my $this   = shift;
	my $client = $this->{client};
	my $line   = <$client>;
	flush $client;
	return $line;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this   = shift;
	my $client = $this->{client};
	my $server = $this->{server};
	close $client;
	close $server;
}

1;
