#================
# FILE          : KIWISocket.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use warnings;
use base qw (Exporter);
use Carp qw (cluck);
use FileHandle;
use Socket;
use KIWIQX;

my @EXPORT_OK = qw ();

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
	my $port = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	$port = int $port;
	if ($port <= 0) {
		return;
	}
	my $server = $this -> serverSocket ($port);
	if (! defined $server) {
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}   = KIWILog -> instance();
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
		return;
	setsockopt(SD, SOL_SOCKET, SO_REUSEADDR, pack("l",1)) ||
		return;
	bind(SD, sockaddr_in($port,INADDR_ANY)) ||
		return;
	listen(SD,SOMAXCONN) ||
		return;
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
		return;
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
	return;
}

#==========================================
# write
#------------------------------------------
sub writeTo {
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
sub readFrom {
	my $this    = shift;
	my $client  = $this->{client};
	if (! defined $client) {
		return;
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
	return $this;
}

1;
