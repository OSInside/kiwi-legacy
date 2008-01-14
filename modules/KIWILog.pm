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
use POSIX ":sys_wait_h";
use Carp qw (cluck);
use KIWISocket;
use KIWISharedMem;
use FileHandle;

#==========================================
# Plugins
#------------------------------------------
BEGIN {
	$KIWILog::haveJabberSupport = 1;
	eval {
		require Net::Jabber;
		Net::Jabber->import qw(Client);
	};
	if ($@) {
		$KIWILog::haveJabberSupport = 0;
	}
	if (! $KIWILog::haveJabberSupport) {
		package Net::Jabber::Client;
	}
}

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
	# Module Parameters
	#------------------------------------------
	my $tiny  = shift;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{showLevel} = [0,1,2,3,4,5];
	$this->{channel}   = *STDOUT;
	$this->{errorOk}   = 0;
	$this->{state}     = "O";
	$this->{message}   = "initialize";
	$this -> getPrefix (1);
	#==========================================
	# Check for tiny object
	#------------------------------------------
	if (defined $tiny) {
		return $this;
	}
	#==========================================
	# Setup jabber connection
	#------------------------------------------
	$this -> setJabberConnection();

	#==========================================
	# Create shmem segment for log messages
	#------------------------------------------
	my $smem = new KIWISharedMem ( $this,$this->{message} );
	if (! defined $smem) {
		$this -> warning ("Can't create shared log memory segment");
		$this -> skipped ();
		return $this;
	}
	$this->{smem}   = $smem;
	#==========================================
	# Create Log Server on $LogServerPort
	#------------------------------------------
	$this -> setLogServer();
	return $this;
}

#==========================================
# sendJabberMessage
#------------------------------------------
sub sendJabberMessage {
	# ...
	# send a jabber message to the jabber server with the
	# given component. The same information which one can see
	# on the command line will be send
	# ---
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
# sendLogServerMessage
#------------------------------------------
sub sendLogServerMessage {
	# ...
	# send the current message to the shared memory segment.
	# with getLogServerMessage the current memory contents
	# will be read
	# ---
	my $this    = shift;
	my $smem    = $this->{smem};
	my $message = $this->{message};
	my $level   = $this->{level};
	my $date    = $this->{date};
	if (! defined $smem) {
		return undef;
	}
	my $data;
	if ($level == 1) {
		$data = '<info>';
	} elsif ($level == 2) {
		$data = '<warning>';
	} else {
		$data = '<error>';
	}
	$data .= "\n".'  <message info="'.$message.'"/>'."\n";
	if ($level == 1) {
        $data .= '</info>';
	} elsif ($level == 2) {
		$data .= '</warning>';
	} else {
		$data .= '</error>';
	}
	$data .= "\n";
	$smem -> lock();
	$smem -> poke($data);
	$smem -> unlock();
	return $this;
}

#==========================================
# getLogServerMessage
#------------------------------------------
sub getLogServerMessage {
	# ...
	# get the contents of the shared memory segment and
	# return them
	# ---
	my $this = shift;
	my $smem = $this->{smem};
	if (! defined $smem) {
		return undef;
	}
	return $smem -> get();
}

#==========================================
# getLogServerDefaultErrorMessage
#------------------------------------------
sub getLogServerDefaultErrorMessage {
	# ...
	# create the default answer if an unknown query command
	# was passed to the log server port
	# ---
	my $this = shift;
	my $data = '<error>';
	$data .= "\n".'  <message info="unknown command"/>'."\n";
	$data .= '</error>'."\n";
	return $data;
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
	my $cols = $this -> getColumns();
	my $FD   = $this->{channel};
	printf $FD "\015\033[%sC\033[10D" , $cols;
}

#==========================================
# doNorm
#------------------------------------------
sub doNorm {
	# ...
	# Reset cursor position to standard value
	# ---
	my $this = shift;
	my $FD   = $this->{channel};
	print $FD "\033[m\017";
}

#==========================================
# done
#------------------------------------------
sub done {
	# ...
	# This is the green "done" flag
	# ---
	my $this    = shift;
	my $rootEFD = $this->{rootefd};
	my $FD      = $this->{channel};
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
	    $this -> doStat();
		print $FD "\033[1;32mdone\n";
		$this -> doNorm();
		if ($this->{errorOk}) {
			print $rootEFD "   done\n";
		}
	} else {
		print $FD "   done\n";
	}
	$this -> saveInCache ("   done\n");
	$this->{state} = "O";
}

#==========================================
# failed
#------------------------------------------
sub failed {
	# ...
	# This is the red "failed" flag
	# ---
	my $this    = shift;
	my $rootEFD = $this->{rootefd};
	my $FD      = $this->{channel};
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
		$this -> doStat();
		print $FD "\033[1;31mfailed\n";
		$this -> doNorm();
		if ($this->{errorOk}) {
			print $rootEFD "   failed\n";
		}
	} else {
		print $FD "   failed\n";
	}
	$this -> saveInCache ("   failed\n");
	$this->{state} = "O";
}

#==========================================
# skipped
#------------------------------------------
sub skipped {
	# ...
	# This is the yellow "skipped" flag
	# ---
	my $this    = shift;
	my $rootEFD = $this->{rootefd};
	my $FD      = $this->{channel};
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
		$this -> doStat();
		print $FD "\033[1;33mskipped\n";
		$this -> doNorm();
		if ($this->{errorOk}) {
			print $rootEFD "   skipped\n";
		}
	} else {
		print $FD "   skipped\n";
	}
	$this -> saveInCache ("   skipped\n");
	$this->{state} = "O";
}

#==========================================
# notset
#------------------------------------------
sub notset {
	# ...
	# This is the cyan "notset" flag
	# ---
	my $this    = shift;
	my $rootEFD = $this->{rootefd};
	my $FD      = $this->{channel};
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
		$this -> doStat();
		print $FD "\033[1;36mnotset\n";
		$this -> doNorm();
		if ($this->{errorOk}) {
			print $rootEFD "   notset\n";
		}
	} else {
		print $FD "   notset\n";
	}
	$this -> saveInCache ("   notset\n");
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
	my $FD   = $this->{channel};
	if ($data > 100) {
		$data = 100;
	}
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
		$this -> doStat();
		print $FD "\033[1;32m($data%)";
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
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
		print "\033[?25l";
	}
}

#==========================================
# cursorON
#------------------------------------------
sub cursorON {
	my $this = shift;
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
		print "\033[?25h";
	}
}

#==========================================
# closeRootChannel
#------------------------------------------
sub closeRootChannel {
	my $this = shift;
	if (defined $this->{rootefd}) {
		close $this->{rootefd};
		undef $this->{rootefd};
	}
}

#==========================================
# reopenRootChannel
#------------------------------------------
sub reopenRootChannel {
	my $this = shift;
	my $file = $this->{rootLog};
	if (defined $this->{rootefd}) {
		return $this;
	}
	if (! (open EFD,">>$file")) {
		return undef;
	}
	binmode(EFD,':unix');
	$this->{rootefd} = *EFD;
	if ($this->{fileLog}) {
		$this->{channel} = *EFD;
	}
	return $this;
}

#==========================================
# getPrefix
#------------------------------------------
sub getPrefix {
	my $this  = shift;
	my $level = shift;
	my $date;
	$date = qx ( LANG=POSIX /bin/date "+%h-%d %H:%M:%S"); chomp $date;
	$this->{date} = $date;
	$this->{level}= $level;
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
	my $this    = shift;
	my $smem    = $this->{smem};
	my $rootEFD = $this->{rootefd};
	my $lglevel = $_[0];
	my $logdata = $_[1];
	my $flag    = $_[2];
	my @mcache  = ();
	my $needcr  = "";
	my $date    = $this -> getPrefix ( $lglevel );
	#==========================================
	# check log status 
	#------------------------------------------
	if (! defined $lglevel) {
		$logdata = $lglevel;
		$lglevel = 1;
	}
	if (($this->{state} eq "I") && ($lglevel != 5)) {
		$needcr = "\n";
	}
	if (defined $this->{mcache}) {
		@mcache = @{$this->{mcache}};
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
		$this->{channel} = *STDOUT;
	}
	#==========================================
	# setup message string
	#------------------------------------------
	my $result;
	my $FD = $this->{channel};
	foreach my $level (@showLevel) {
		if ($level != $lglevel) {
			next;
		}
		if (($lglevel == 1) || ($lglevel == 2) || ($lglevel == 3)) {
			$result = $needcr.$date.$logdata;
		} elsif ($lglevel == 5) {
			$result = $needcr.$logdata;
		} else {
			$result = Carp::longmess($needcr.$logdata);
		}
	}
	#==========================================
	# send message cache if needed
	#------------------------------------------
	if ((($this->{fileLog}) || ($this->{errorOk})) && (@mcache) && ($rootEFD)) {
		foreach my $message (@mcache) {
			print $rootEFD $message;
		}
		undef $this->{mcache};
	}
	#==========================================
	# store current message in shared mem
	#------------------------------------------
	$this -> {message} = $logdata;
	$this -> sendLogServerMessage ();
	#==========================================
	# send message to jabber server if con
	#------------------------------------------
	$this -> sendJabberMessage ("$needcr,$date,$logdata");
	#==========================================
	# print message to root file
	#------------------------------------------
	if ($this->{errorOk}) {
		print $rootEFD $result;
	}
	#==========================================
	# print message to log channel (stdin,file)
	#------------------------------------------
	if ((! defined $flag) || ($this->{fileLog})) {
		print $FD $result;
	}
	#==========================================
	# save in cache if needed
	#------------------------------------------
	$this -> saveInCache ($result);
	return $lglevel;
}

#==========================================
# saveInCache
#------------------------------------------
sub saveInCache {
	# ...
	# save message in object cache if needed. If no
	# log or root-log file is set the message will
	# be cached until a file was set
	# ---
	my $this    = shift;
	my $logdata = shift;
	my @mcache;
	if (defined $this->{mcache}) {
		@mcache = @{$this->{mcache}};
	}
	if ((! $this->{fileLog}) && (! $this->{errorOk})) {
		push (@mcache,$logdata);
		$this->{mcache} = \@mcache;
	}
	return $this;
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
	if ($file eq "terminal") {
		return $this;
	}
	if (! (open FD,">$file")) {
		$this -> warning ("Couldn't open log channel: $!\n");
		return undef;
	}
	binmode(FD,':unix');
	$this->{channel} = *FD;
	$this->{rootefd} = *FD;
	$this->{rootLog} = $file;
	$this->{fileLog} = 1;
	return $this;
}

#==========================================
# setLogHumanReadable
#------------------------------------------
sub setLogHumanReadable {
	my $this = shift;
	my $rootLog = $this->{rootLog};
	local $/;
	if ((! defined $rootLog) || (! open (FD, $rootLog))) {
		return undef;
	}
	my $stream = <FD>; close FD;
	my @stream = split (//,$stream);
	my $line = "";
	my $cr   = 0;
	if (! open (FD, ">$rootLog")) {
		return undef;
	}
	foreach my $l (@stream) {
		if ($l eq "\r") {
			# got carriage return, store it
			$cr = 1; next;
		}
		if (($l eq "\n") && (! $cr)) {
			# normal line, print it
			print FD "$line\n"; $line = ""; next;
		}
		if (($l eq "\n") && ($cr)) {
			# multi line ended with line feed, print it
			print FD "$line\n"; $cr = 0; $line = ""; next;
		}
		if (($l ne "\n") && ($cr)) {
			# multi line unfinished, overwrite 
			$line = $l; $cr = 0; next;
		}
		$line .= $l;
	}
	close FD;
	return $this;
}

#==========================================
# setColorOff
#------------------------------------------
sub setColorOff {
	# ...
	# switch off the colored output - do it by simulating output file
	# ---
	my $this = shift;
	$this->{nocolor} = 1;
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
		$this -> warning ("Couldn't open root log channel: $!\n");
		$this->{errorOk} = 0;
	}
	binmode(EFD,':unix');
	$this -> done ();
	$this->{rootLog} = $file;
	$this->{errorOk} = 1;
	$this->{rootefd} = *EFD;
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
# setJabberConnection
#------------------------------------------
sub setJabberConnection {
	# ...
	# Setup jabber connection if possible. This requires the
	# package perl-Net-Jabber to be installed
	# ---
	my $this = shift;
	my $jclient;
	my @jresult;
	my $jstatus;
	if (! $main::ConfigStatus) {
		return undef;
	}
	if (
		(! defined $main::JabberServer)    ||
		(! defined $main::JabberUserName)  ||
		(! defined $main::JabberPassword)  ||
		(! defined $main::JabberRessource) ||
		(! defined $main::JabberComponent)
	) {
		#$this -> warning ("Jabber setup skipped: Missing login data");
		#$this -> skipped ();
		return undef;
	}
	if (! $KIWILog::haveJabberSupport) {
		return undef;
	}
	$this -> info ("Connecting to Jabber server: $main::JabberServer");
	$jclient = new Net::Jabber::Client;
	$jstatus = $jclient -> Connect (
		hostname => $main::JabberServer,
		port     => $main::JabberPort
	);
	if (! defined $jstatus) {
		$this -> failed ();
		$this -> error  ("Server is not answering: $!");
		$this -> skipped ();
		return $this;
	}
	$this -> done();
	$this -> info ("Login to Jabber server: $main::JabberUserName");
	@jresult = $jclient -> AuthSend (
		username => $main::JabberUserName,
		password => $main::JabberPassword,
		resource => $main::JabberRessource
	);
	if ($jresult[0] ne "ok") {
		$this -> error   ("Failed: $jresult[0] $jresult[1]");
		$this -> skipped ();
		return $this;
	}
	$this -> done ();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{jcomponent}= $main::JabberComponent;
	$this->{jclient}   = $jclient;
	return $this;
}

#==========================================
# setLogServer
#------------------------------------------
sub setLogServer {
	# ...
	# setup a log server which can be queried. The answer to each
	# query is a XML formated information
	# ---
	my $this  = shift;
	my $child = fork();
	if (! defined $child) {
		$this -> warning ("Can't fork logserver process: $!");
		$this -> skipped ();
		return undef;
	}
	if ($child) {
		#==========================================
		# Parent log server process
		#------------------------------------------
		$this->{logchild} = $child;
		return $this;
	} else {
		#==========================================
		# Child log server process
		#------------------------------------------
		our @logChilds = ();
		our %logChilds = ();
		our $logServer = new KIWISocket ( $this,$main::LogServerPort );
		our $sharedMem = $this->{smem};
		if (! defined $logServer) {
			$this -> warning ("Can't open log port: $main::LogServerPort");
			$this -> skipped ();
			exit 1;
		}
		$SIG{TERM} = sub {
			foreach my $child (@logChilds) { kill (13,$child); };
			undef $logServer;
			exit 0;
		};
		$SIG{CHLD} = sub {
			while ((my $child = waitpid(-1,WNOHANG)) > 0) {
				$logServer -> closeConnection();
				kill (13,$child);
			}
		};
		$SIG{INT} = $SIG{TERM};
		while (1) {
			$logServer -> acceptConnection();
			my $child = fork();
			if (! defined $child) {
				$this -> warning ("Can't fork logserver process: $!");
				$this -> skipped ();
				last;
			}
			if ($child) {
				#==========================================
				# Wait for incoming connections
				#------------------------------------------
				$logChilds{$child} = $child;
				@logChilds = keys %logChilds;
				next;
			} else {
				#==========================================
				# Handle log requests...
				#------------------------------------------
				$SIG{PIPE} = sub {
					$logServer -> write ( $this -> getLogServerMessage() );
					$logServer -> closeConnection();
					$sharedMem -> closeSegment();
					exit 1;
				};
				while (my $command = $logServer -> read()) {
					#==========================================
					# Handle command: status
					#------------------------------------------
					if ($command eq "status") {
						$logServer -> write (
							$this -> getLogServerMessage()
						);
						next;
					}
					#==========================================
					# Handle command: exit
					#------------------------------------------
					if ($command eq "exit") {
						last;
					}
					#==========================================
					# Add More commands here...
					#------------------------------------------
					# ...
					#==========================================
					# Invalid command...
					#------------------------------------------
					$logServer -> write (
						$this -> getLogServerDefaultErrorMessage()
					);
				}
				$logServer -> closeConnection();
				exit 0;
			}
		}
		undef $logServer;
		exit 1;
	}
	return $this;
}

#==========================================
# cleanSweep
#------------------------------------------
sub cleanSweep {
	my $this     = shift;
	my $jclient  = $this->{jclient};
	my $logchild = $this->{logchild};
	my $rootEFD  = $this->{rootefd};
	if ($this->{errorOk}) {
		close $rootEFD;
	}
	if (defined $jclient) {
		$jclient -> Disconnect();
	}
	if (defined $logchild) {
		kill (15, $logchild);
		waitpid ($logchild,0);
		undef $this->{logchild};
	}
	return $this;
}

1;
