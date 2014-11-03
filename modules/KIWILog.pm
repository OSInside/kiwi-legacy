#================
# FILE          : KIWILog.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use warnings;
use Carp qw (cluck);
use FileHandle;
use POSIX ":sys_wait_h";
use Time::HiRes qw( sleep );

#==========================================
# Base class
#------------------------------------------
use base qw /Class::Singleton/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIQX;
use KIWITrace;

#==========================================
# Tracing
#------------------------------------------
$Carp::Internal{KIWILog}++;

#==========================================
# getColumns
#------------------------------------------
sub getColumns {
    # ...
    # get the terminal number of columns because we want
    # to put the status text at the end of the line
    # ---
    my $this = shift;
    my $size = qx (stty size 2>/dev/null);
    if ((! $size) || (chomp $size eq "")) {
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
    return;
}

#==========================================
# doNorm
#------------------------------------------
sub doNorm {
    # ...
    # Reset cursor position to standard value
    # ---
    my $this = shift;
    print STDOUT "\033[m\017";
    print STDERR "\033[m\017";
    return;
}

#==========================================
# setFlag
#------------------------------------------
sub setFlag {
    # ...
    # set status flag
    # ---
    my $this = shift;
    my $flag = shift;
    my $FD   = $this->{channel};
    #==========================================
    # no flag in file logging mode
    #------------------------------------------
    if ($this->{fileLog}) {
        # Don't set status flags in logging mode
        return;
    }
    #==========================================
    # setup flag color
    #------------------------------------------
    my %color;
    $color{done}    = 32;
    $color{failed}  = 31;
    $color{skipped} = 33;
    $color{notset}  = 36;
    $color{oops}    = 36;
    #==========================================
    # print flag
    #------------------------------------------
    if (! defined $this->{nocolor}) {
        $this -> doStat();
        print $FD "\033[1;".$color{$flag}."m".$flag."\n";
        $this -> doNorm();
    } else {
        print $FD "   $flag\n";
    }
    return;
}

#==========================================
# done
#------------------------------------------
sub done {
    # ...
    # This is the green "done" flag
    # ---
    my $this = shift;
    $this -> setFlag ("done");
    return;
}

#==========================================
# failed
#------------------------------------------
sub failed {
    # ...
    # This is the red "failed" flag
    # ---
    my $this = shift;
    $this -> setFlag ("failed");
    return;
}

#==========================================
# skipped
#------------------------------------------
sub skipped {
    # ...
    # This is the yellow "skipped" flag
    # ---
    my $this = shift;
    $this -> setFlag ("skipped");
    return;
}

#==========================================
# notset
#------------------------------------------
sub notset {
    # ...
    # This is the cyan "notset" flag
    # ---
    my $this = shift;
    $this -> setFlag ("notset");
    return;
}

#==========================================
# oops
#------------------------------------------
sub oops {
    # ...
    # This is the cyan "oops" flag
    # ---
    my $this = shift;
    $this -> setFlag ("oops");
    return;
}

#==========================================
# snip
#------------------------------------------
sub snip {
    # ...
    # Show moving elements while waiting
    # ---
    my $this = shift;
    my $text = shift;
    my $col  = 36; # cyan
    my @data = ('-','\\','|','/','-','\\','|','/');
    if (defined $this->{nocolor}) {
        return;
    }
    my $child = fork();
    $this -> cursorOFF();
    if ($child) {
        $this->{spinPID} = $child;
    } else {
        local $SIG{"TERM"} = 'DEFAULT';
        if ($text) {
            my $prefix = $this -> getPrefix(1);
            print $prefix.$text;
        }
        while (1) {
            foreach my $flag (@data) {
                $this -> doStat();
                print "\033[1;".$col."m".$flag;
                sleep 0.1;
                $this -> doNorm();
            }
        }
    }
    return;
}

#==========================================
# snap
#------------------------------------------
sub snap {
    # ...
    # Stop moving elements
    # ---
    my $this = shift;
    if ($this->{spinPID}) {
        kill 15, $this->{spinPID};
        $this -> done ();
        $this -> cursorON();
    }
    return;
}

#==========================================
# step
#------------------------------------------
sub step {
    # ...
    # This is the green "(...%)" flag
    # ---
    my $this = shift;
    my $data = shift;
    my $FD   = $this->{channel};
    if ($data > 100) {
        $data = 100;
    }
    if (defined $this->{fileLog}) {
        # Don't set progress info to log file
        return;
    }
    if (! defined $this->{nocolor}) {
        $this -> doStat();
        print $FD "\033[1;32m($data%)";
        $this -> doStat();
        if ($this->{errorOk}) {
            # Don't set progress info to default log file
        }
    } else {
        # Don't set progress info in no-curses mode
    }
    return;
}

#==========================================
# cursorOFF
#------------------------------------------
sub cursorOFF {
    my $this = shift;
    if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
        print "\033[?25l";
    }
    return;
}

#==========================================
# cursorON
#------------------------------------------
sub cursorON {
    my $this = shift;
    if ((! defined $this->{fileLog}) && (! defined $this->{nocolor})) {
        print "\033[?25h";
    }
    return;
}

#==========================================
# resetRootChannel
#------------------------------------------
sub resetRootChannel {
    my $this = shift;
    undef $this -> {errorOk};
    return;
}

#==========================================
# closeRootChannel
#------------------------------------------
sub closeRootChannel {
    my $this = shift;
    if (defined $this->{rootefd}) {
        close $this->{rootefd};
        if ($this->{rootefd} eq $this->{channel}) {
            undef $this->{channel};
        }
        undef $this->{rootefd};
    }
    return;
}

#==========================================
# reopenRootChannel
#------------------------------------------
sub reopenRootChannel {
    my $this   = shift;
    my $file   = $this->{rootLog};
    my $trace  = KIWITrace -> instance();
    if (! $file) {
        return;
    }
    if (defined $this->{rootefd}) {
        return $this;
    }
    my $EFD = FileHandle -> new();
    if (! $EFD -> open (">>$file")) {
        if ($this -> trace()) {
            $trace->{BT}[$trace->{TL}] = eval {
                Carp::longmess ($trace->{TT}.$trace->{TL}++)
            };
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
    my $lglevel = shift;
    my $logdata = shift;
    my $flag    = shift;
    my @mcache  = ();
    my $rootEFD = $this->{rootefd};
    my $date    = $this -> getPrefix ( $lglevel );
    my $trace   = KIWITrace -> instance();
    my $prev    = $this->{last_line};
    my $prev_channel = $this->{last_channel};
    #==========================================
    # no logdata -> return
    #------------------------------------------
    return if ! $logdata;
    #==========================================
    # Setup channel location due to loglevel
    #------------------------------------------
    if ((! $this->{fileLog}) || ($this->{fileLog} == 2)) {
        if ($lglevel == 3) {
            $this->{channel} = *STDERR;
        } else {
            $this->{channel} = *STDOUT;
        }
    }
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
    my $FD = $this->{channel};
    #==========================================
    # setup message string
    #------------------------------------------
    my $result;
    if (($lglevel == 1) || ($lglevel == 2)) {
        $result = $date.$logdata;
    } elsif ($lglevel == 5) {
        $result = $logdata;
    } elsif ($lglevel == 3) {
        $result = $date.$logdata;
        if ($this -> trace()) {
            $trace->{BT}[$trace->{TL}] = eval {
                Carp::longmess ($trace->{TT}.$trace->{TL}++)
            };
        }
    } else {
        $result = Carp::longmess($logdata);
    }
    #==========================================
    # send message cache if needed
    #------------------------------------------
    if ((($this->{fileLog}) || ($this->{errorOk})) && (@mcache) && ($rootEFD)) {
        my $line = "\n";
        foreach my $message (@mcache) {
            my $last_line_ending = chop $line;
            if ($last_line_ending ne "\n") {
                print $rootEFD "\n";
            }
            print $rootEFD $message;
            $line = $message;
        }
        undef $this->{mcache};
    }
    #==========================================
    # check if last log line ended with a CR
    #------------------------------------------
    my $needCR = 0;
    if ($prev) {
        my $last_line_ending = chop $prev;
        if ($last_line_ending ne "\n") {
            $needCR = 1;
        }
    }
    #==========================================
    # print message to root file
    #------------------------------------------
    if (($this->{errorOk}) && ($rootEFD)) {
        if ($needCR) {
            print $rootEFD "\n";
        }
        print $rootEFD $result;
    }
    #==========================================
    # print message to log channel (stdin,file)
    #------------------------------------------
    if (($prev_channel) && ((! defined $flag) || ($this->{fileLog}))) {
        if (($needCR) && ($this->{fileLog})) {
            print $prev_channel "\n";
        }
        print $prev_channel $result;
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
    my $this  = shift;
    my $used  = $this->{used};
    my $FD    = $this->{channel};
    my $trace = KIWITrace -> instance();
    if (! $used) {
        return $this;
    }
    if (! $trace->{BT}) {
        return $this;
    }
    my $trace_text = pop @{$trace->{BT}};
    if (! defined $this->{nocolor}) {
        print STDERR "\033[1;31m[*** back trace follows ***]\n";
        print STDERR "\033[1;31m$trace_text";
        print STDERR "\033[1;31m[*** end ***]\n";
        $this -> doNorm();
    } else {
        print STDERR ("[*** back trace follows ***]\n");
        print STDERR $trace_text;
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
    return;
}

#==========================================
# deactivateBackTrace
#------------------------------------------
sub deactivateBackTrace {
    my $this = shift;
    $this->{used} = 0;
    return;
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
    $this->{last_line} = $logdata;
    $this->{last_channel} = $this->{channel};
    if (defined $this->{mcache}) {
        @mcache = @{$this->{mcache}};
    }
    if ((! $this->{fileLog}) && (! $this->{rootefd})) {
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
    return;
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
    return;
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
    return;
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
    return;
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
    return;
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
    my $this   = shift;
    my $file   = shift;
    my $trace  = KIWITrace -> instance();
    if ($file eq "terminal") {
        $this->{fileLog} = 2;
        return $this;
    }
    my $FD = FileHandle -> new();
    if (! $FD -> open (">$file")) {
        $this -> warning ("Couldn't open log channel: $!\n");
        if ($this -> trace()) {
            $trace->{BT}[$trace->{TL}] = eval {
                Carp::longmess ($trace->{TT}.$trace->{TL}++)
            };
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
        KIWIQX::qxx ("mv $rootLog $logfile 2>&1");
        $this -> info ("Complete logfile at: $logfile\n");
    }
    return $this;
}

#==========================================
# setLogHumanReadable
#------------------------------------------
sub setLogHumanReadable {
    my $this    = shift;
    my $rootLog = $this->{rootLog};
    my $FDR     = FileHandle -> new();
    my $trace   = KIWITrace -> instance();
    local $/;
    if ((! defined $rootLog) || (! $FDR -> open ($rootLog))) {
        return;
    }
    my $stream = <$FDR>;
    $FDR -> close();
    my @stream = split (//,$stream);
    my $line = "";
    my $cr   = 0;
    my $FDW  = FileHandle -> new();
    if (! $FDW -> open (">$rootLog")) {
        if ($this -> trace()) {
            $trace->{BT}[$trace->{TL}] = eval {
                Carp::longmess ($trace->{TT}.$trace->{TL}++)
            };
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
            print $FDW "$line\n"; $line = ""; next;
        }
        if (($l eq "\n") && ($cr)) {
            # multi line ended with line feed, print it
            print $FDW "$line\n"; $cr = 0; $line = ""; next;
        }
        if (($l ne "\n") && ($cr)) {
            # multi line unfinished, overwrite 
            $line = $l; $cr = 0; next;
        }
        $line .= $l;
    }
    $FDW -> close();
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
    my $EFD = FileHandle -> new();
    if (! $EFD -> open (">$file")) {
        $this -> skipped ();
        $this -> warning ("Couldn't open root log channel: $!\n");
        $this->{errorOk} = 0;
    }
    binmode($EFD,':unix');
    $this -> done ();
    $this->{rootLog} = $file;
    $this->{errorOk} = 1;
    $this->{rootefd} = *$EFD;
    return;
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
# Private helper methods
#------------------------------------------
#==========================================
# One time initialization code
#------------------------------------------
sub _new_instance {
    # ...
    # Construct a KIWILog object. The log object
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
    $this->{channel}   = *STDOUT;
    $this->{errorOk}   = 0;
    $this->{used}      = 1;
    $this -> getPrefix (1);
    return $this;
}

1;
