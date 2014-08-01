#================
# FILE          : ktLog.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This is a stand in class to replace the KIWILog class
#               : used during regular kiwi execution for logging purposes.
#               :
#               : The class allows the test cases to retrive messages passed
#               : to the logging mechanism and check the status set for
#               : loging.
#               :
#               : The implementation coerces a KIWILog to return an instance
#               : of this Singelton as it's own instance.
#               :
#               : The interface mimicks parts of the interface of the logging
#               : facility provided by KIWILog.pm
#               :
#               : Expected use:
#               : my $kiwi  = ktLog -> instance();
#               : my $msg   = $kiwi -> getMessage();
#               : my $msgT  = $kiwi -> getMessageType();
#               : my $state = $kiwi -> getState();
#               :
#               : The object data is reset when the state is returned in
#               : expectation that the logger will be reused.
#               :
# STATUS        : Development
#----------------
package Common::ktLog;

use strict;
use warnings;

use KIWILog;

use base qw /Class::Singleton/;

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
    # ...
    # Clean up
    # ---
    unlink '/tmp/kiwiTestLog.log';
    return;
}

#==========================================
# closeRootChannel
#------------------------------------------
sub closeRootChannel {
    # ...
    # Dummy method to mimick interface of proper log object
    # ---
    return;
}

#==========================================
# done
#------------------------------------------
sub done {
    # ...
    # Set the task completed state
    # ---
    my $this = shift;
    $this -> {completed} = 1;
    return $this;
}

#==========================================
# trace
#------------------------------------------
sub trace {
    return 0;
}

#==========================================
# error
#------------------------------------------
sub error {
    # ...
    # Set the error message
    # ---
    my $this = shift;
    $this -> {errMsg} = shift;
    $this -> {msgType} = 'error';
    return $this;
}

#==========================================
# failed
#------------------------------------------
sub failed {
    # ...
    # Set the failure state
    # ---
    my $this = shift;
    $this -> {failed} = 1;
    return $this;
}

#==========================================
# getErrorMessage
#------------------------------------------
sub getErrorMessage {
    # ...
    # Retrieve the error message.
    # In general the getMessage method should be used. However, under certain
    # test conditions it is unavoidable to have multiple messages in the log
    # object. For these rare occasions the log allows access to the specific
    # message types directly. The message type is reset, the final call in a
    # test should always be to getMessage() to assure no unexpected messages
    # are present.
    # ---
    my $this = shift;
    my $msg = $this -> {errMsg};
    $this -> {errMsg} = q{};
    return $msg;
}

#==========================================
# getErrorState
#------------------------------------------
sub getErrorState {
    # ...
    # Retrieve the state of the error flag.
    # Generally the getState method should be used. However, under certain
    # circumstances the code issues a set of messages together. The individual
    # get*State methods allow to retrieve the expected state and clear the
    # flag for this state. THe final call in any test should always be to
    # getState to assure there are no unexpected messages.
    my $this = shift;
    my $val = $this -> {failed} ? 'failed' : 0;
    $this -> {failed} = 0;
    return $val;
}

#==========================================
# getInfoMessage
#------------------------------------------
sub getInfoMessage {
    # ...
    # Retrieve the info message.
    # In general the getMessage method should be used. However, under certain
    # test conditions it is unavoidable to have multiple messages in the log
    # object. For these rare occasions the log allows access to the specific
    # message types directly. The message type is reset, the final call in a
    # test should always be to getMessage() to assure no unexpected messages
    # are present.
    # ---
    my $this = shift;
    my $msg = $this -> {infoMsg};
    $this -> {infoMsg} = q{};
    return $msg;
}

#==========================================
# getLogInfoMessage
#------------------------------------------
sub getLogInfoMessage {
    # ...
    # Retrieve the loginfo message.
    # In general the getMessage method should be used. However, under certain
    # test conditions it is unavoidable to have multiple messages in the log
    # object. For these rare occasions the log allows access to the specific
    # message types directly. The message type is reset, the final call in a
    # test should always be to getMessage() to assure no unexpected messages
    # are present.
    # ---
    my $this = shift;
    my $msg = $this -> {logInfoMsg};
    $this -> {logInfoMsg} = q{};
    return $msg;
}

#==========================================
# getMessage
#------------------------------------------
sub getMessage {
    # ...
    # Return the message
    # ---
    my $this = shift;
    my $msg;
    my $msgCnt = 0;
    if ( $this -> {errMsg} ) {
        $msg = $this -> {errMsg};
        $msgCnt += 1;
    }
    if ( $this -> {infoMsg} ) {
        $msg = $this -> {infoMsg};
        $msgCnt += 1;
    }
    if ( $this -> {logInfoMsg} ) {
        $msg = $this -> {logInfoMsg};
        $msgCnt += 1;
    }
    if ( $this -> {noteMsg} ) {
        $msg = $this -> {noteMsg};
        $msgCnt += 1;
    }
    if ( $this -> {warnMsg} ) {
        $msg = $this -> {warnMsg};
        $msgCnt += 1;
    }
    if ( $msgCnt == 0 ) {
        $msg = 'No messages set';
    }
    if ( $msgCnt > 1 ) {
        $msg = 'Log error: Multiple messages defined';
        $this -> __printAllMessages();
    }
    return $msg;
}

#==========================================
# getMessageType
#------------------------------------------
sub getMessageType {
    # ...
    # Return the type of the stored message
    # ---
    my $this = shift;
    return $this -> {msgType};
}

#==========================================
# getNotsetState
#------------------------------------------
sub getNotsetState {
    # ...
    # Retrieve the state of the notset flag.
    # Generally the getState method should be used. However, under certain
    # circumstances the code issues a set of messages together. The individual
    # get*State methods allow to retrieve the expected state and clear the
    # flag for this state. The final call in any test should always be to
    # getState to assure there are no unexpected messages.
    my $this = shift;
    my $val = $this -> {notset} ? 'notset' : 0;
    $this -> {notset} = 0;
    return $val;
}

#==========================================
# getOopsState
#------------------------------------------
sub getOopsState {
    # ...
    # Retrieve the state of the oops flag.
    # Generally the getState method should be used. However, under certain
    # circumstances the code issues a set of messages together. The individual
    # get*State methods allow to retrieve the expected state and clear the
    # flag for this state. THe final call in any test should always be to
    # getState to assure there are no unexpected messages.
    my $this = shift;
    my $val = $this -> {oops} ? 'oops' : 0;
    $this -> {oops} = 0;
    return $val;
}

#==========================================
# getRootLog
#------------------------------------------
sub getRootLog {
    # ...
    # Return test logfile location
    # ---
    my $this = shift;
    return $this -> {rootLog};
}

#==========================================
# getState
#------------------------------------------
sub getState {
    # ...
    # Return the logging operation state
    # Only one state may be set.
    # ---
    my $this = shift;
    my $state;
    my $stateCnt = 0;
    if ( $this -> {completed} ) {
        $state = 'completed';
        $stateCnt += 1;
    }
    if ($this -> {failed} ) {
        $state = 'failed';
        $stateCnt += 1;
    }
    if ($this -> {notset} ) {
        $state = 'notset';
        $stateCnt += 1;
    }
    if ( $this -> {oops} ) {
        $state = 'oops';
        $stateCnt += 1;
    }
    if ( $this -> {skipped} ) {
        $state = 'skipped';
        $stateCnt += 1;
    }
    if ( $stateCnt == 0 ) {
        $state = 'No state set';
    }
    if ( $stateCnt > 1 ) {
        $state = 'Log error: Multiple states defined';
    }
    $this -> __reset();
    return $state;
}

#==========================================
# getWarningMessage
#------------------------------------------
sub getWarningMessage {
    # ...
    # Retrieve the warning message.
    # In general the getMessage method should be used. However, under certain
    # test conditions it is unavoidable to have multiple messages in the log
    # object. For these rare occasions the log allows access to the specific
    # message types directly. The message type is reset, the final call in a
    # test should always be to getMessage() to assure no unexpected messages
    # are present.
    # ---
    my $this = shift;
    my $msg = $this -> {warnMsg};
    $this -> {warnMsg} = q{};
    return $msg;
}

#==========================================
# getWarningState
#------------------------------------------
sub getWarningState {
    # ...
    # Retrieve the state of the skipped flag.
    # Generally the getState method should be used. However, under certain
    # circumstances the code issues a set of messages together. The individual
    # get*State methods allow to retrieve the expected state and clear the
    # flag for this state. THe final call in any test should always be to
    # getState to assure there are no unexpected messages.
    my $this = shift;
    my $val = $this -> {skipped} ? 'skipped' : 0;
    $this -> {skipped} = 0;
    return $val;
}

#==========================================
# info
#------------------------------------------
sub info {
    # ...
    # Set the information message
    # ---
    my $this = shift;
    if ($this -> {infoMsg}) {
        $this -> {infoMsg} = $this -> {infoMsg} . shift;
    } else {
        $this -> {infoMsg} = shift;
    }
    $this -> {msgType} = 'info';
    return $this;
}

#==========================================
# loginfo
#------------------------------------------
sub loginfo {
    # ...
    # Set the information message
    # ---
    my $this = shift;
    my $msg  = shift;
    if ($msg !~ /EXEC/ms) {
        $this -> {logInfoMsg} = $msg;
        $this -> {msgType} = 'info';
    }
    return $this;
}

#==========================================
# note
#------------------------------------------
sub note {
    # ...
    # Set note message
    # ---
    my $this = shift;
    $this -> {noteMsg} = shift;
    $this -> {msgType} = 'note';
    return;
}

#==========================================
# notset
#------------------------------------------
sub notset {
    # ...
    # notset state
    # ---
    my $this = shift;
    $this -> {notset} = 1;
    return $this;
}

#==========================================
# reopenRootChannel
#------------------------------------------
sub reopenRootChannel {
    # ...
    # Dummy implementation to mimick log object
    # ---
    my $this = shift;
    return $this;
}
#==========================================
# setRootLog
#------------------------------------------
sub setRootLog {
    # ...
    # Create a test log file
    # ---
    my $this = shift;
    my $log = $this -> {rootLog};
    system "touch $log";
    return;
}

#==========================================
# oops
#------------------------------------------
sub oops {
    # ...
    # Set the opps state
    # ---
    my $this = shift;
    $this -> {oops} = 1;
    return $this;
}

#==========================================
# skipped
#------------------------------------------
sub skipped {
    # ...
    # Set the skipped step state
    # ---
    my $this = shift;
    $this -> {skipped} = 1;
    return $this;
}

#==========================================
# storeXML
#------------------------------------------
sub storeXML {
    # ...
    # Dummy function, storing the XML has nothing really to do with logging
    # but that's a discussion for another day.
    my $this = shift;
    return $this;
}

#==========================================
# warning
#------------------------------------------
sub warning {
    # ...
    # Set the warning message
    # ---
    my $this = shift;
    $this -> {warnMsg} = shift;
    $this -> {msgType} = 'warning';
    return $this;
}

#==========================================
# writeXMLDiff
#------------------------------------------
sub writeXMLDiff {
    # ...
    # Dummy implementation to mimick regular KIWILog object
    # ---
    my $this = shift;
    return $this;
}

#==========================================
# doNorm
#------------------------------------------
sub doNorm {
    # ...
    # Reset cursor position to standard value
    # In this module do nothing
    # ---
    my $this = shift;
    return $this;
}

#==========================================
# terminalLogging
#------------------------------------------
sub terminalLogging {
    # ...
    # Check if terminal logging is activated
    # In this module always report false -> not activated
    # ---
    my $this = shift;
    return 0;
}

#==========================================
# Private helper methods
#------------------------------------------
# The _new_instance method is used to initialize the Singleton, but this
# cannot be seen by perlcritic, thus we need to exclude unused private method
# checking. In order to allow us to have a Singleton log object in the
# code base but to also allow us to test the messages produced when kiwi
# runs we must coerce the KIWILog class when the test run, therefore we
# must assign to a package varaiable, ProhibitPackageVars and
# ProtectPrivateVars avoid perlcritic complaints about using the package
# variable _instance of the Singleton object.
## no critic (ProhibitUnusedPrivateSubroutines, ProhibitPackageVars, ProtectPrivateVars)
#==========================================
# Constructor
#------------------------------------------
sub _new_instance {
    # ...
    # Construct a new ktLog object
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless  $this,$class;
    #==========================================
    # Stored Messages
    #------------------------------------------
    $this -> {errMsg}     = q{};
    $this -> {infoMsg}    = q{};
    $this -> {logInfoMsg} = q{};
    $this -> {warnMsg}    = q{};
    #==========================================
    # Stored State
    #------------------------------------------
    $this -> {completed} = 0;
    $this -> {failed}    = 0;
    $this -> {msgType}   = 'none';
    $this -> {notset}    = 0;
    $this -> {oops}      = 0;
    $this -> {skipped}   = 0;
    #==========================================
    # A "fake" log file
    #------------------------------------------
    $this -> {rootLog} = '/tmp/kiwiTestLog.log';
    # Coerce the KIWILog to be a ktLog
    $KIWILog::_instance = $this;
    return $this;
}
## use critic
#==========================================
# __printAllMessages
#------------------------------------------
sub __printAllMessages {
    # ...
    # Print all the messages that have been set.
    # During testing it is expected that the state of the log object is
    # such that only one message is set. To aid in test development and
    # failure investigation it is useful when all messages that have been set
    # get printed upon failure.
    # ---
    my $this = shift;
    if ( $this -> {errMsg} ) {
        my $msg = $this -> {errMsg};
        print {*STDERR} "Log set error message: $msg\n";
    }
    if ( $this -> {infoMsg} ) {
        my $msg = $this -> {infoMsg};
        print {*STDERR} "Log set info message: $msg\n";
    }
    if ( $this -> {logInfoMsg} ) {
        my $msg = $this -> {logInfoMsg};
        print {*STDERR} "Log set loginfo message: $msg\n";
    }
    if ( $this -> {warnMsg} ) {
        my $msg = $this -> {warnMsg};
        print {*STDERR} "Log set warning message: $msg\n";
    }
    return;
}

#==========================================
# __reset
#------------------------------------------
sub __reset {
    # ...
    # Reset object data and state
    # ---
    my $this = shift;
    $this -> __resetData();
    $this -> __resetState();
    return $this;
}

#==========================================
# __resetData
#------------------------------------------
sub __resetData {
    # ...
    # Reset object data
    # ---
    my $this = shift;
    $this->{errMsg}     = q{};
    $this->{infoMsg}    = q{};
    $this->{logInfoMsg} = q{};
    $this->{warnMsg}    = q{};
    return $this;
}

#==========================================
# __resetState
#------------------------------------------
sub __resetState {
    # ...
    # Reset object state
    # ---
    my $this = shift;
    $this -> {completed} = 0;
    $this -> {failed}    = 0;
    $this -> {msgType}   = 'none';
    $this -> {notset}    = 0;
    $this -> {oops}      = 0;
    $this -> {skipped}   = 0;
    return $this;
}

1;
