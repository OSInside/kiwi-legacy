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

#==========================================
# Private
#------------------------------------------
my @showLevel = (0,1,2,3,4,5);
my $channel   = \*STDOUT;
my $logfile;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct a new KIWILog object. The log object
	# is used to print out info, error and warning
	# messages
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
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
	setOutputChannel();
	my $cols = getColumns();
	printf ("\015\033[%sC\033[10D",$cols);
	resetOutputChannel();
}

#==========================================
# doNorm
#------------------------------------------
sub doNorm {
	# ...
	# Reset cursor position to standard value
	# ---
	setOutputChannel();
	print "\033[m\017";
	resetOutputChannel();
}

#==========================================
# done
#------------------------------------------
sub done {
	# ...
	# This is the green "done" flag
	# ---
    doStat();
	setOutputChannel();
    print "\033[1;32mdone\n";
	resetOutputChannel();
    doNorm();
}

#==========================================
# failed
#------------------------------------------
sub failed {
	# ...
	# This is the red "failed" flag
	# ---
    doStat();
	setOutputChannel();
    print "\033[1;31mfailed\n";
	resetOutputChannel();
    doNorm();
}

#==========================================
# skipped
#------------------------------------------
sub skipped {
	# ...
	# This is the yellow "skipped" flag
	# ---
	doStat();
	setOutputChannel();
	print "\033[1;33mskipped\n";
	resetOutputChannel();
	doNorm();
}

#==========================================
# setOutputChannel
#------------------------------------------
sub setOutputChannel {
	open ( OLDERR, ">&STDERR" );
	open ( OLDSTD, ">&STDOUT" );
	open ( STDERR,">&$$channel" );
	open ( STDOUT,">&$$channel" );
}

#==========================================
# resetOutputChannel
#------------------------------------------
sub resetOutputChannel {
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

	if (! defined $channel) {
		$channel = \*STDOUT;
	}
	if ($lglevel !~ /^\d$/) {
		$logdata = $lglevel;
		$lglevel = 1;
	}
	my $date = getPrefix ( $this,$lglevel );
	foreach my $level (@showLevel) {
	if ($level == $lglevel) {
		setOutputChannel();
		if (($lglevel == 1) || ($lglevel == 2) || ($lglevel == 3)) {
			print $date,$logdata;
		} elsif ($lglevel == 5) {
			print $logdata;
		} else {
			cluck $date,$logdata;
		}
		resetOutputChannel();
		return $lglevel;
	}
	}
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
# setLogFile
#------------------------------------------
sub setLogFile {
	# ...
	# set a log file name for logging. Each call of
	# a log() method will write its data to this file
	# ---
	my $this = shift;
	my $file = $_[0];
	if (! (open FD,">$file")) {
		warning ( $this,"Couldn't open log channel: $!\n" );
		return undef;
	}
	$logfile = \*FD;
	$channel = \*FD;
	return $this;
}

1;
