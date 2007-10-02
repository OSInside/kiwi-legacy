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
	$port = int $port;
	if ($port <= 0) {
		return undef;
	}
	my $server = $this -> serverSocket ($port);
	if (! defined $server) {
		return undef;
	}
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
	socket(SD, PF_INET, SOCK_STREAM, $proto) ||
		return undef;
	setsockopt(SD, SOL_SOCKET, SO_REUSEADDR, pack("l",1)) ||
		return undef;
	bind(SD, sockaddr_in($port,INADDR_ANY)) ||
		return undef;
	listen(SD,SOMAXCONN) ||
		return undef;
	return *SD;
}

#==========================================
# acceptConnection
#------------------------------------------
sub acceptConnection {
	my $this    = shift;
	my $server  = $this->{server};
	my $paddr   = accept (CD,$server);
	if (! $paddr) {
		return undef;
	}
	$this->{client} = *CD;
	return $this->{client};
}

#==========================================
# closeConnection
#------------------------------------------
sub closeConnection {
	my $this   = shift;
	my $client = $this->{client};
	if (defined $client) {
		close $client;
	}
}

#==========================================
# write
#------------------------------------------
sub write {
	my $this    = shift;
	my $message = shift;
	my $client  = $this->{client};
	print $client $message;
	flush $client;
	return $this;
}

#==========================================
# read
#------------------------------------------
sub read {
	my $this    = shift;
	my $client  = $this->{client};
	if (! defined $client) {
		return undef;
	}
	my $line = <$client>;
	flush $client;
	chop $line;
	chop $line;
	return $line;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this    = shift;
	my $client  = $this->{client};
	my $server  = $this->{server};
	if (defined $client) {
		close $client;
	}
	if (defined $server) {
		close $server;
	}
}

1;
