#================
# FILE          : ktLog.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This is a stand in class to replace the KIWILog class
#               : used during regular Kiwi execution for logging purposes.
#               :
#               : The class allows the test cases to retrive messages passed
#               : to the logging mechanism and check the status set for
#               : loging.
#               :
#               : The interface mimicks parts of the interface of the logging
#               : facility provided by KIWILog.pm
#               :
#               : Expected use:
#               : my $kiwi  = new ktLog();
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

#==========================================
# Constructor
#------------------------------------------
sub new {
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
	$this -> {errMsg}  = '';
	$this -> {infoMsg} = '';
	$this -> {warnMsg} = '';
	#==========================================
	# Stored State
	#------------------------------------------
	$this -> {completed} = 0;
	$this -> {failed}    = 0;
	$this -> {msgType}   = 'none';
	$this -> {skipped}   = 0;
	return $this;
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
	if ( $this -> {warnMsg} ) {
		$msg = $this -> {warnMsg};
		$msgCnt += 1;
	}
	if ( $msgCnt == 0 ) {
		$msg = 'No messages set';
	}
	if ( $msgCnt > 1 ) {
		$msg = 'Log error: Multiple messages defined';
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
# info
#------------------------------------------
sub info {
	# ...
	# Set the information message
	# ---
	my $this = shift;
	$this -> {infoMsg} = shift;
	$this -> {msgType} = 'info';
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
# Private helper methods
#------------------------------------------
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
	$this->{errMsg}  = '';
	$this->{infoMsg} = '';
	$this->{warnMsg} = '';
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
	$this -> {skipped}   = 0;
	return $this;
}

1;
