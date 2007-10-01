#================
# FILE          : KIWILog.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used for logging purpose
#               : to ensure a single point for all log
#               : messages
#               :
# STATUS        : Development
#----------------
package KIWILog;
#==========================================
# Modules
#------------------------------------------
use strict;
use Net::Jabber qw(Client);
use Carp qw (cluck);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct a new KIWILog object. The log object
	# is used to print out info, error and warning
	# messages
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless  $this,$class;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{showLevel} = [0,1,2,3,4,5];
	$this->{channel}   = \*STDOUT;
	$this->{errorOk}   = 0;
	$this->{state}     = "O";
	#============================================
	# kiwirc jabber data
	#--------------------------------------------
	my $jstatus = 1;
	if ( ! -f $main::ConfigFile ) {
		$jstatus = 0;
	}
	#============================================
	# set local jabber variables
	#--------------------------------------------
	my $JabberServer;     # configurable jabber server
	my $JabberPort;       # configurable jabber port
	my $JabberUserName;   # configurable jabber user name
	my $JabberPassword;   # configurable jabber password
	my $JabberRessource;  # configurable jabber ressource
	my $JabberComponent;  # configurable jabber component
	if (! defined $JabberPort) {
		$JabberPort = 5223;
	}
	#============================================
	# Read $HOME/.kiwirc and setup jabber if ok
	#--------------------------------------------
	if (($jstatus) && (! do $main::ConfigFile)) {
		$this -> warning ("Invalid $main::ConfigFile file...");
		$this -> skipped ();
		$jstatus = 0;
	}
	if (($jstatus) &&
		((! defined $JabberServer)   || (! defined $JabberUserName)  ||
		 (! defined $JabberPassword) || (! defined $JabberRessource) ||
		 (! defined $JabberComponent))
	) {
		#$this -> warning ("Jabber setup skipped: Missing login data");
		#$this -> skipped ();
		$jstatus = 0;
	}
	my $jclient;
	my $jstatus;
	my @jresult;
	if ($jstatus) {
		$this -> info ("Connecting to Jabber server: $JabberServer");
		$jclient = new Net::Jabber::Client;
		$jstatus = $jclient -> Connect (
			hostname => $JabberServer,
			port     => $JabberPort
		);
		if (! defined $jstatus) {
			$this -> failed ();
			$this -> error  ("Server is not answering: $!");
			$this -> skipped ();
		} else {
			$this -> done();
			$this -> info ("Login to Jabber server: $JabberUserName");
			@jresult = $jclient -> AuthSend (
				username => $JabberUserName,
				password => $JabberPassword,
				resource => $JabberRessource
			);
			if ($jresult[0] ne "ok") {
				$this -> error   ("Failed: $jresult[0] $jresult[1]");
				$this -> skipped ();
			} else {
				$this -> done ();
			}
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{jcomponent}= $JabberComponent;
	$this->{jclient}   = $jclient;
	return $this;
}

#==========================================
# sendJabberMessage
#------------------------------------------
sub sendJabberMessage {
	my $this       = shift;
	my $message    = shift;
	my $jclient    = $this->{jclient};
	my $jcomponent = $this->{jcomponent};
	if (defined $jclient) {
		$jclient -> MessageSend (
			to   => $jcomponent,
			body => $message
		);
		$jclient->Process();
	}
	return $this;
}

#==========================================
# getColumns
#------------------------------------------
sub getColumns {
	# ...
	# get the terminal number of columns because we want
	# to put the status text at the end of the line
	# ---
	my $this = shift;
	my $size = qx (stty size 2>/dev/null); chomp ($size);
	if ($size eq "") {
		return 80;
	}
	my @size = split (/ +/,$size);
	return pop @size;
}

#==========================================
# doStat
#------------------------------------------
sub doStat {
	# ...
	# Initialize cursor position counting from the
	# end of the line
	# ---
	my $this = shift;
	$this -> setOutputChannel();
	my $cols = $this -> getColumns();
	printf ("\015\033[%sC\033[10D",$cols);
	$this -> resetOutputChannel();
}

#==========================================
# doNorm
#------------------------------------------
sub doNorm {
	# ...
	# Reset cursor position to standard value
	# ---
	my $this = shift;
	$this -> setOutputChannel();
	print "\033[m\017";
	$this -> resetOutputChannel();
}

#==========================================
# done
#------------------------------------------
sub done {
	# ...
	# This is the green "done" flag
	# ---
	my $this = shift;
	if (! defined $this->{fileLog}) {
	    $this -> doStat();
		$this -> setOutputChannel();
		print "\033[1;32mdone\n";
		$this -> resetOutputChannel();
		$this -> doNorm();
		if ($this->{errorOk}) {
			print EFD "   done\n";
		}
	} else {
		$this -> setOutputChannel();
		print "   done\n";
		$this -> resetOutputChannel();
	}
	$this->{state} = "O";
}

#==========================================
# failed
#------------------------------------------
sub failed {
	# ...
	# This is the red "failed" flag
	# ---
	my $this = shift;
	if (! defined $this->{fileLog}) {
		$this -> doStat();
		$this -> setOutputChannel();
		print "\033[1;31mfailed\n";
		$this -> resetOutputChannel();
		$this -> doNorm();
		if ($this->{errorOk}) {
			print EFD "   failed\n";
		}
	} else {
		$this -> setOutputChannel();
		print "   failed\n";
		$this -> resetOutputChannel();
	}
	$this->{state} = "O";
}

#==========================================
# skipped
#------------------------------------------
sub skipped {
	# ...
	# This is the yellow "skipped" flag
	# ---
	my $this = shift;
	if (! defined $this->{fileLog}) {
		$this -> doStat();
		$this -> setOutputChannel();
		print "\033[1;33mskipped\n";
		$this -> resetOutputChannel();
		$this -> doNorm();
		if ($this->{errorOk}) {
			print EFD "   skipped\n";
		}
	} else {
		$this -> setOutputChannel();
		print "   skipped\n";
		$this -> resetOutputChannel();
	}
	$this->{state} = "O";
}

#==========================================
# notset
#------------------------------------------
sub notset {
	# ...
	# This is the cyan "notset" flag
	# ---
	my $this = shift;
	if (! defined $this->{fileLog}) {
		$this -> doStat();
		$this -> setOutputChannel();
		print "\033[1;36mnotset\n";
		$this -> resetOutputChannel();
		$this -> doNorm();
		if ($this->{errorOk}) {
			print EFD "   notset\n";
		}
	} else {
		$this -> setOutputChannel();
		print "   notset\n";
		$this -> resetOutputChannel();
	}
	$this->{state} = "O";
}

#==========================================
# step
#------------------------------------------
sub step {
	# ...
	# This is the green "(...)" flag
	# ---
	my $this = shift;
	my $data = shift;
	if ($data > 100) {
		$data = 100;
	}
	if (! defined $this->{fileLog}) {
		$this -> doStat();
		$this -> setOutputChannel();
		print "\033[1;32m($data%)";
		$this -> resetOutputChannel();
		$this -> doStat();
		if ($this->{errorOk}) {
			# Don't set progress info to log file
		}
	} else {
		# Don't set progress info to log file
	}
}

#==========================================
# cursorOFF
#------------------------------------------
sub cursorOFF {
	my $this = shift;
	if (! defined $this->{fileLog}) {
		print "\033[?25l";
	}
}

#==========================================
# cursorON
#------------------------------------------
sub cursorON {
	my $this = shift;
	if (! defined $this->{fileLog}) {
		print "\033[?25h";
	}
}

#==========================================
# setOutputChannel
#------------------------------------------
sub setOutputChannel {
	my $this = shift;
	my $channel = $this->{channel};
	open ( OLDERR, ">&STDERR" );
	open ( OLDSTD, ">&STDOUT" );
	open ( STDERR,">&$$channel" );
	open ( STDOUT,">&$$channel" );
}

#==========================================
# resetOutputChannel
#------------------------------------------
sub resetOutputChannel {
	my $this = shift;
	close ( STDERR );
	open  ( STDERR, ">&OLDERR" );
	close ( STDOUT );
	open  ( STDOUT, ">&OLDSTD" );
}

#==========================================
# getPrefix
#------------------------------------------
sub getPrefix {
	my $this  = shift;
	my $level = shift;
	my $date;
	$date = qx ( LANG=POSIX /bin/date "+%h-%d %H:%M");
	$date =~ s/\n$//;
	$date .= " <$level> : ";
	return $date;
}

#==========================================
# log
#------------------------------------------
sub printLog {
	# ...
	# print log message to an optional given output channel
	# reference. The output channel can be one of the standard
	# channels or a previosly opened file
	# ---
	my $this = shift;
	my $lglevel = $_[0];
	my $logdata = $_[1];
	my $flag    = $_[2];
	my $needcr  = "";
	#==========================================
	# check log status 
	#------------------------------------------
	if (($this->{state} eq "I") && ($lglevel != 5)) {
		$needcr = "\n";
	}
	#==========================================
	# save log status 
	#------------------------------------------
	if ($logdata !~ /\n$/) {
		$this->{state} = "I";
	} else {
		$this->{state} = "O";
	}
	#==========================================
	# set log status 
	#------------------------------------------
	my @showLevel = @{$this->{showLevel}};
	if (! defined $this->{channel}) {
		$this->{channel} = \*STDOUT;
	}
	if ($lglevel !~ /^\d$/) {
		$logdata = $lglevel;
		$lglevel = 1;
	}
	my $date = getPrefix ( $this,$lglevel );
	if (defined $flag) {
		print EFD $needcr,$date,$logdata;
		return;
	}
	foreach my $level (@showLevel) {
	if ($level == $lglevel) {
		$this -> setOutputChannel();
		if (($lglevel == 1) || ($lglevel == 2) || ($lglevel == 3)) {
			print $needcr,$date,$logdata;
			$this -> sendJabberMessage ("$needcr,$date,$logdata");
			if ($this->{errorOk}) {
				print EFD $needcr,$date,$logdata;
			}
		} elsif ($lglevel == 5) {
			print $needcr,$logdata;
			$this -> sendJabberMessage ("$needcr,$logdata");
			if ($this->{errorOk}) {
				print EFD $needcr,$logdata;
			}
		} else {
			print Carp::longmess("$needcr,$logdata");
			$this -> sendJabberMessage ("$needcr,$logdata");
			if ($this->{errorOk}) {
				print EFD Carp::longmess("$needcr,$logdata");
			}
		}
		$this -> resetOutputChannel();
		return $lglevel;
	}
	}
}

#==========================================
# info
#------------------------------------------
sub loginfo {
	# ...
	# print an info log message to channel <1>
	# ---
	my $this = shift;
	my $data = shift;
	printLog ( $this,1,$data,"loginfo" );
}

#==========================================
# info
#------------------------------------------
sub info {
	# ...
	# print an info log message to channel <1>
	# ---
	my $this = shift;
	my $data = shift;
	printLog ( $this,1,$data );
}

#==========================================
# error
#------------------------------------------
sub error {
	# ...
	# print an error log message to channel <3>
	# ---
	my $this = shift;
	my $data = shift;
	printLog ( $this,3,$data );
}

#==========================================
# warning
#------------------------------------------
sub warning {
	# ...
	# print a warning log message to channel <2>
	# ---
	my $this = shift;
	my $data = shift;
	printLog ( $this,2,$data );
}

#==========================================
# message
#------------------------------------------
sub note {
	# ...
	# print a raw log message to channel <5>.
	# This is a message without date and time
	# information
	# ---
	my $this = shift;
	my $data = shift;
	printLog ( $this,5,$data );
}

#==========================================
# state
#------------------------------------------
sub state {
	# ...
	# get current cursor log state
	# ---
	my $this = shift;
	return $this->{state};
}

#==========================================
# setLogFile
#------------------------------------------
sub setLogFile {
	# ...
	# set a log file name for logging. Each call of
	# a log() method will write its data to this file
	# ---
	my $this = shift;
	my $file = $_[0];
	if ($file ne "terminal") {
		if (! (open FD,">$file")) {
			warning ( $this,"Couldn't open log channel: $!\n" );
			return undef;
		}
		binmode(FD,':unix');
		$this->{channel} = \*FD;
	}
	$this->{rootLog} = $file;
	$this->{fileLog} = 1;
	return $this;
}

#==========================================
# setRootLog
#------------------------------------------
sub setRootLog {
	# ...
	# set a root log file which corresponds with the
	# screen log file so that there is a complete log per
	# image prepare/build process available
	# ---
	my $this = shift;
	my $file = shift;
	if ($this->{errorOk}) {
		return;
	}
	info ( $this, "Set root log: $file..." );
	if (! (open EFD,">$file")) {
		$this -> skipped ();
		warning ( $this,"Couldn't open root log channel: $!\n" );
		$this->{errorOk} = 0;
	}
	binmode(EFD,':unix');
	$this -> done ();
	$this->{rootLog} = $file;
	$this->{errorOk} = 1;
}

#==========================================
# getRootLog
#------------------------------------------
sub getRootLog {
	# ...
	# return the current root log file name
	# ---
	my $this = shift;
	return $this->{rootLog};
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this    = shift;
	my $jclient = $this->{jclient};
	close EFD;
	if (defined $jclient) {
		$jclient -> Disconnect();
	}
}

1;
