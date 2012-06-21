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
use Carp qw (cluck);
use POSIX ":sys_wait_h";
use KIWISocket;
use KIWISharedMem;
use FileHandle;
use KIWIQX qw (qxx qxxLogOff qxxLogOn);

#==========================================
# Tracing
#------------------------------------------
$Carp::Internal{KIWILog}++;

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
	$this->{channel}   = *STDOUT;
	$this->{errorOk}   = 0;
	$this->{message}   = "initialize";
	$this->{used}      = 1;
	$this -> getPrefix (1);
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
		if (($this->trace()) && ($main::TT)) {
			$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return;
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
		if ($this->trace()) {
			$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return;
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
}

#==========================================
# oops
#------------------------------------------
sub oops {
	# ...
	# This is the cyan "oops" flag
	# ---
	my $this    = shift;
	my $rootEFD = $this->{rootefd};
	my $FD      = $this->{channel};
	if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
		$this -> doStat();
		print $FD "\033[1;36moops\n";
		$this -> doNorm();
		if ($this->{errorOk}) {
			print $rootEFD "   notset\n";
		}
	} else {
		print $FD "   oops\n";
	}
	$this -> saveInCache ("   oops\n");
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
# resetRootChannel
#------------------------------------------
sub resetRootChannel {
	my $this = shift;
	undef $this -> {errorOk};
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
	my $EFD;
	if (! (open $EFD, '>>', "$file")) {
		if ($this->trace()) {
			$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return;
	}
	binmode($EFD,':unix');
	$this->{rootefd} = *$EFD;
	if ($this->{fileLog}) {
		$this->{channel} = *$EFD;
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
	#$date = qx (bash -c 'LANG=POSIX /bin/date "+%h-%d %H:%M:%S'"); chomp $date;
	my @lt= localtime(time());
	$date = sprintf ("%s-%02d %02d:%02d:%02d",
		(qw{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec})[$lt[4]],
		$lt[3], $lt[2], $lt[1], $lt[0]
	);
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
	my $rootEFD = $this->{rootefd};
	my $lglevel = $_[0];
	my $logdata = $_[1];
	my $flag    = $_[2];
	my @mcache  = ();
	my $date    = $this -> getPrefix ( $lglevel );
	#==========================================
	# check log status 
	#------------------------------------------
	if (! defined $lglevel) {
		$logdata = $lglevel;
		$lglevel = 1;
	}
	if (defined $this->{mcache}) {
		@mcache = @{$this->{mcache}};
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
		if (($lglevel == 1) || ($lglevel == 2)) {
			$result = $date.$logdata;
		} elsif ($lglevel == 5) {
			$result = $logdata;
		} elsif ($lglevel == 3) {
			$result = $date.$logdata;
			if ($this->trace()) {
				$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
			}
		} else {
			$result = Carp::longmess($logdata);
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
	# print message to root file
	#------------------------------------------
	if ($this->{errorOk} && ($rootEFD)) {
		my $msg = $result;
		$msg .= "\n" if ($msg !~ /\n$/);
		print $rootEFD $msg;
	}
	#==========================================
	# print message to log channel (stdin,file)
	#------------------------------------------
	if ((! defined $flag) || ($this->{fileLog})) {
		my $msg = $result;
		if ($this->{fileLog}) {
			$msg .= "\n" if ($msg !~ /\n$/);
		}
		print $FD $msg;
	}
	#==========================================
	# save in cache if needed
	#------------------------------------------
	$this -> saveInCache ($result);
	return $lglevel;
}

#==========================================
# printBackTrace
#------------------------------------------
sub printBackTrace {
	# ...
	# return currently saved backtrace information
	# if no information is present an empty string
	# is returned
	# ---
	my $this = shift;
	my $used = $this->{used};
	my $FD   = $this->{channel};
	if (! $used) {
		return $this;
	}
	if (! @main::BT) {
		return $this;
	}
	my $trace = pop @main::BT;
	if (! defined $this->{nocolor}) {
		print STDERR "\033[1;31m[*** back trace follows ***]\n";
		print STDERR "\033[1;31m$trace";
		print STDERR "\033[1;31m[*** end ***]\n";
		$this -> doNorm();
	} else {
		print STDERR ("[*** back trace follows ***]\n");
		print STDERR $trace;
		print STDERR "[*** end ***]\n";
	}
	return $this;
}

#==========================================
# activateBackTrace
#------------------------------------------
sub activateBackTrace {
	my $this = shift;
	$this->{used} = 1;
}

#==========================================
# deactivateBackTrace
#------------------------------------------
sub deactivateBackTrace {
	my $this = shift;
	$this->{used} = 0;
}

#==========================================
# trace, check for activation state
#------------------------------------------
sub trace {
	my $this = shift;
	return $this->{used};
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
	$this -> printLog ( 1,$data,"loginfo" );
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
	$this -> printLog ( 1,$data );
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
	$this -> printLog ( 3,$data );
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
	$this -> printLog ( 2,$data );
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
	$this -> printLog ( 5,$data );
}

#==========================================
# terminalLogging
#------------------------------------------
sub terminalLogging {
	my $this = shift;
	if (($this->{fileLog}) && ($this->{fileLog} == 2)) {
		return 1;
	}
	return 0;
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
		$this->{fileLog} = 2;
		return $this;
	}
	my $FD;
	if (! (open $FD, '>', "$file")) {
		$this -> warning ("Couldn't open log channel: $!\n");
		if ($this->trace()) {
			$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return;
	}
	binmode($FD,':unix');
	$this->{channel} = *$FD;
	$this->{rootefd} = *$FD;
	$this->{rootLog} = $file;
	$this->{fileLog} = 1;
	return $this;
}

#==========================================
# printLogExcerpt
#------------------------------------------
sub printLogExcerpt {
	my $this    = shift;
	my $rootLog = $this->{rootLog};
	my $search  = "Following information is JFYI";
	my $ignore;
	my $FD;
	if ((! defined $rootLog) || (! open ($FD, '<', $rootLog))) {
		return;
	}
	my @lines = <$FD>;
	close $FD;
	my @result = ();
	foreach my $line (@lines) {
		last if ($line =~ /$search/);
		push @result,$line;
	}
	if (@result > 50) {
		@lines  = splice @result,-50;
	} else {
		@lines = @result;
	}
	@result = ();
	$ignore = 0;
	foreach my $line (@lines) {
		if (($line !~ /BEGIN XML diff/) && (! $ignore)) {
			push @result,$line;
		} elsif ($line =~ /BEGIN XML diff/) {
			$ignore = 1;
		} elsif ($line =~ /END XML diff/) {
			$ignore = 0;
		}
	}
	unshift (@result,"[*** log excerpt follows, last significant bytes ***]\n");
	push    (@result,"[*** end ***]\n");
	if (! defined $this->{nocolor}) {
		print STDERR "\033[1;31m@result";
		$this -> doNorm();
	} else {
		print STDERR @result;
	}
	return $this;
}

#==========================================
# finalizeLog
#------------------------------------------
sub finalizeLog {
	my $this = shift;
	my $rootLog = $this -> getRootLog();
	if ((defined $rootLog) &&
		(-f $rootLog) && ($rootLog =~ /(.*)\..*\.screenrc\.log/)
	) {
		my $logfile = $1;
		$logfile = "$logfile.log";
		$this -> info ("Complete logfile at: $logfile");
		qxx ("mv $rootLog $logfile 2>&1");
		$this -> done ();
	}
	return $this;
}

#==========================================
# setLogHumanReadable
#------------------------------------------
sub setLogHumanReadable {
	my $this = shift;
	my $rootLog = $this->{rootLog};
	local $/;
	my $FD;
	if ((! defined $rootLog) || (! open ($FD, '<', $rootLog))) {
		return;
	}
	my $stream = <$FD>;
	close $FD;
	my @stream = split (//,$stream);
	my $line = "";
	my $cr   = 0;
	if (! open ($FD, '>', "$rootLog")) {
		if ($this->trace()) {
			$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return;
	}
	foreach my $l (@stream) {
		if ($l eq "\r") {
			# got carriage return, store it
			$cr = 1; next;
		}
		if (($l eq "\n") && (! $cr)) {
			# normal line, print it
			print $FD "$line\n"; $line = ""; next;
		}
		if (($l eq "\n") && ($cr)) {
			# multi line ended with line feed, print it
			print $FD "$line\n"; $cr = 0; $line = ""; next;
		}
		if (($l ne "\n") && ($cr)) {
			# multi line unfinished, overwrite 
			$line = $l; $cr = 0; next;
		}
		$line .= $l;
	}
	close $FD;
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
	my $EFD;
	if (! (open $EFD, '>', "$file")) {
		$this -> skipped ();
		$this -> warning ("Couldn't open root log channel: $!\n");
		$this->{errorOk} = 0;
	}
	binmode($EFD,':unix');
	$this -> done ();
	$this->{rootLog} = $file;
	$this->{errorOk} = 1;
	$this->{rootefd} = *$EFD;
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
# setLogServer
#------------------------------------------
sub setLogServer {
	# ...
	# setup a log server which can be queried. The answer to each
	# query is a XML formated information
	# ---
	my $this  = shift;
	my $port  = shift;
	#==========================================
	# Check for tiny object
	#------------------------------------------
	if ((defined $port) && (int $port == 0)) {
		return $this;
	}
	#==========================================
	# Create shmem segment for log messages
	#------------------------------------------
	my $smem = new KIWISharedMem ( $this,$this->{message} );
	if (! defined $smem) {
		$this -> warning ("Can't create shared log memory segment");
		$this -> skipped ();
		return $this;
	}
	$this->{smem} = $smem;
	#==========================================
	# Fork new child
	#------------------------------------------
	my $child = fork();
	if (! defined $child) {
		$this -> warning ("Can't fork logserver process: $!");
		$this -> skipped ();
		$this -> {smem} -> closeSegment();
		undef $this -> {smem};
		if ($this->trace()) {
			$main::BT[$main::TL] = eval { Carp::longmess ($main::TT.$main::TL++) };
		}
		return;
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
		our $logServer = new KIWISocket ($this,$port);
		our $sharedMem = $this->{smem};
		if (! defined $logServer) {
			$this -> warning ("Can't open log port: $port\n");
			$sharedMem -> closeSegment();
			undef $this-> {smem};
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
					$logServer -> writeTo ( $this -> getLogServerMessage() );
					$logServer -> closeConnection();
					$sharedMem -> closeSegment();
					undef $this-> {smem};
					exit 1;
				};
				while (my $command = $logServer -> readFrom()) {
					#==========================================
					# Handle command: status
					#------------------------------------------
					if ($command eq "status") {
						$logServer -> writeTo (
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
					$logServer -> writeTo (
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
	my $logchild = $this->{logchild};
	my $rootEFD  = $this->{rootefd};
	my $sharedMem= $this->{smem};
	if ($this->{errorOk}) {
		close $rootEFD;
	}
	if (defined $logchild) {
		kill (15, $logchild);
		waitpid ($logchild,0);
		undef $this->{logchild};
	}
	if (defined $sharedMem) {
		$sharedMem -> closeSegment();
	}
	undef  $this -> {smem};
	return $this;
}

#==========================================
# storeXML
#------------------------------------------
sub storeXML {
	my $this = shift;
	my $data = shift;
	my $orig = shift;
	$this->{xmlString}   = $data;
	$this->{xmlOrigFile} = $orig;
	return $this;
}

#==========================================
# writeXMLDiff
#------------------------------------------
sub writeXMLDiff {
	my $this   = shift;
	my $pretty = shift;
	my $data   = $this->{xmlString};
	my $cmpf   = $this->{xmlOrigFile};
	my $cache  = $this->{xmlCache};
	my @NC;
	my $FX;
	if ((! $data) || (! -f $cmpf)) {
		return;
	}
	qxxLogOff();
	my $used = qxx ("mktemp -q /tmp/kiwi-xmlused.XXXXXX"); chomp $used;
	my $code = $? >> 8;
	if ($code != 0) {
		qxxLogOn();
		return;
	}
	my $orig = qxx ("mktemp -q /tmp/kiwi-xmlorig.XXXXXX"); chomp $orig;
	if ($code != 0) {
		qxxLogOn();
		return;
	}
	qxx ("cp -a $cmpf $orig");
	if (! open ($FX, '>', "$used")) {
		qxxLogOn();
		unlink $used;
		unlink $orig;
		return;
	}
	binmode $FX;
	print $FX $data; close $FX;
	qxx ("xsltproc -o $used.new $pretty $used");
	qxx ("mv $used.new $used");
	qxx ("xsltproc -o $orig.new $pretty $orig");
	qxx ("mv $orig.new $orig");
	my $diff  = qxx ("diff -uwB $orig $used | grep -v -E '^[-+]{3}' 2>&1");
	if (! $diff) {
		qxxLogOn();
		unlink $used;
		unlink $orig;
		return $this;
	}
	qxxLogOn();
	my $print = 1;
	if ($cache) {
		@NC = @{$cache};
		foreach my $d (@NC) {
			if ($d eq $diff) {
				$print = 0; last;
			}
		}
	}
	if ($print) {
		$this -> loginfo ("BEGIN XML diff (JFYI)\n");
		$this -> loginfo ("file: $cmpf:\n");
		$this -> loginfo ("diff: $diff:\n");
		$this -> loginfo ("END XML diff\n");
		push @NC,$diff;
		$this->{xmlCache} = \@NC;
	}
	unlink $used;
	unlink $orig;
	return $this;
}

1;
