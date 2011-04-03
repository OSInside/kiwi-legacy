#================
# FILE          : kiwiCommandLine.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 Novell Inc.
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWICommandLine module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiCommandLine;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {kiwi} = new Common::ktLog();

	return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the commandline constructor, it has no error conditions, thus check
	# the object construction.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = new KIWICommandLine($kiwi);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($cmd);
}

#==========================================
# test_cmdAddRepos_improperAlias
#------------------------------------------
sub test_cmdAddRepos_improperAlias {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3');
	my @alias = ('alias');
	my $res = $cmd -> setAdditionalRepos(\@repos, @alias);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method expecting ARRAY_REF as '
		. 'second argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_improperPrio
#------------------------------------------
sub test_cmdAddRepos_improperPrio {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3');
	my @prio = (1);
	my $res = $cmd -> setAdditionalRepos(\@repos, undef, @prio);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method expecting ARRAY_REF as '
		. 'third argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_improperRepo
#------------------------------------------
sub test_cmdAddRepos_improperRepo {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3');
	my $res = $cmd -> setAdditionalRepos(@repos);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method expecting ARRAY_REF as '
		. 'first argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_improperTypes
#------------------------------------------
sub test_cmdAddRepos_improperTypes {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3');
	my @types = ('yast2');
	my $res = $cmd -> setAdditionalRepos(\@repos, undef, undef, @types);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method expecting ARRAY_REF as '
		. 'fourth argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_mismatchRepoAli
#------------------------------------------
sub test_cmdAddRepos_mismatchRepoAli {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3', 'os11.3-non-oss');
	my @alias = ('alias');
	my @types = ('yast2');
	my $res = $cmd -> setAdditionalRepos(\@repos, \@alias, undef, \@types);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Number of specified repositories does not match number '
		. 'of provided alias, cannot form proper match.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_mismatchRepoPrio
#------------------------------------------
sub test_cmdAddRepos_mismatchRepoPrio {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3', 'os11.3-non-oss');
	my @prio = (1);
	my @types = ('yast2');
	my $res = $cmd -> setAdditionalRepos(\@repos, undef, \@prio, \@types);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Number of specified repositories does not match number '
		. 'of provided priorities, cannot form proper match.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_mismatchRepoTypes
#------------------------------------------
sub test_cmdAddRepos_mismatchRepoTypes {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3', 'os11.3-non-oss');
	my @types = ('yast2');
	my $res = $cmd -> setAdditionalRepos(\@repos, undef, undef, \@types);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Number of specified repositories does not match number '
		. 'of provided types, cannot form proper match.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_noRepo
#------------------------------------------
sub test_cmdAddRepos_noRepo {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that there are no default repos
	my $defRepos = $cmd -> getAdditionalRepos();
	$this -> assert_null($defRepos);
	# Provide no arguments
	my $res = $cmd -> setAdditionalRepos();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method called without specifying '
		. 'repositories';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_noTypes
#------------------------------------------
sub test_cmdAddRepos_noTypes {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide no arguments
	my @repos = ('os11.3');
	my $res = $cmd -> setAdditionalRepos(\@repos, undef, undef);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method called without specifying '
		. 'repository types';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_unssupType
#------------------------------------------
sub test_cmdAddRepos_unssupType {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3', 'os11.3-non-oss');
	my @types = ('yast2', 'foo');
	my $res = $cmd -> setAdditionalRepos(\@repos, undef, undef, \@types);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Specified repository type foo not supported.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdAddRepos_valid
#------------------------------------------
sub test_cmdAddRepos_valid {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @repos = ('os11.3', 'os11.3-non-oss');
	my @alias = ('name1', 'name2');
	my @prios = (1, 2);
	my @types = ('yast2', 'rpm-md');
	my $res = $cmd -> setAdditionalRepos(\@repos, \@alias, \@prios, \@types);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	my %repoInfo = %{$cmd -> getAdditionalRepos()};
	$this -> assert_array_equal(\@repos, $repoInfo{repositories});
	$this -> assert_array_equal(\@alias, $repoInfo{repositoryAlia});
	$this -> assert_array_equal(\@prios, $repoInfo{repositoryPriorities});
	$this -> assert_array_equal(\@types, $repoInfo{repositoryTypes});
}

#==========================================
# test_cmdBuildTypeUsage
#------------------------------------------
sub test_cmdBuildTypeUsage {
	# ...
	# Test the storage and verification of the build type data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that there is no default
	my $defBT = $cmd -> getBuildType();
	$this -> assert_null($defBT);
	# Use valid data to set a type information
	my $res = $cmd -> setBuildType('reiserfs');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we can get our data back
	my $cmdT = $cmd -> getBuildType();
	$this -> assert_str_equals('reiserfs', $cmdT);
}

#==========================================
# test_cmdConfDirUsage_noArg
#------------------------------------------
sub test_cmdConfDirUsage_noArg {
	# ...
	# Test the storage and verification of the configuration directory data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that there is no default
	my $defDir = $cmd -> getConfigDir();
	$this -> assert_null($defDir);
	# No argument specified
	my $res = $cmd -> setConfigDir();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setConfigDir method called without specifying a '
		. 'configuration directory.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdConfDirUsage_noDirExist
#------------------------------------------
sub test_cmdConfDirUsage_noDirExist {
	# ...
	# Test the storage and verification of the configuration directory data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Directory does not exist
	my $res = $cmd -> setConfigDir('ola');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Specified configuration directory "ola" could '
		. 'not be found.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdConfDirUsage_noDirRead
#------------------------------------------
sub test_cmdConfDirUsage_noDirRead {
	# ...
	# Test the storage and verification of the configuration directory data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Directory has no read access
	# If the test is run a root the test will fail
	my $res = $cmd -> setConfigDir('/root');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'No read access to specified configuration directory '
		. '"/root".';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdConfDirUsage_valid
#------------------------------------------
sub test_cmdConfDirUsage_valid {
	# ...
	# Test the storage and verification of the configuration directory data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Expecting success
	my $res = $cmd -> setConfigDir('/tmp');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	my $dir = $cmd -> getConfigDir();
	$this -> assert_str_equals('/tmp', $dir);
}

#==========================================
# test_cmdIgnoreRepoUsage
#------------------------------------------
sub test_cmdIgnoreRepoUsage {
	# ...
	# Test the storage of the repo ignore state information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that the default state if false
	my $defIgnore = $cmd -> getIgnoreRepos();
	$this -> assert_null($defIgnore);
	# Test that passing no argument does not change the state
	$cmd -> setIgnoreRepos();
	my $ignore = $cmd -> getIgnoreRepos();
	$this -> assert_null($defIgnore);
	# Test we get our value back
	$cmd -> setIgnoreRepos(1);
	$ignore = $cmd -> getIgnoreRepos();
	$this -> assert_equals(1, $ignore);
}

#==========================================
# test_cmdIgnoreRepoUsage_conflict
#------------------------------------------
sub test_cmdIgnoreRepoUsage_conflict {
	# ...
	# Test the storage of the repo ignore state information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that passing no argument does not change the state
	$cmd -> setReplacementRepo('os11.3', 'alias', 1, 'yast2');
	my $res = $cmd -> setIgnoreRepos();
	$this -> assert_not_null($res);
	# Create conflicting settings
	$res = $cmd -> setIgnoreRepos(1);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Conflicting command line arguments; ignore repos and '
		. 'set repos';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdLogFileUsage_noArg
#------------------------------------------
sub test_cmdLogFileUsage_noArg {
	# ...
	# Test the storage of the logfile path
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that the command line object has no default
	my $defLog = $cmd -> getLogFile();
	$this -> assert_null($defLog);
	# Test improper call no argument
	my $res = $cmd -> setLogFile();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setLogFileName method called without specifying a '
		. 'log file path.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdLogFileUsage_noWrite
#------------------------------------------
sub test_cmdLogFileUsagee_noWrite {
	# ...
	# Test the storage of the logfile path
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test no write permission
	# If the test is executed as root this test will fail
	my $res = $cmd -> setLogFile('/usr/cmdlTestLog.log');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Unable to write to location /usr/, cannot create log '
		. 'file.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdLogFileUsage_valid
#------------------------------------------
sub test_cmdLogFileUsage_valid {
	# ...
	# Test the storage of the logfile path
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test proper use
	my $res = $cmd -> setLogFile('/tmp/cmdlTestLog.log');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	my $logFile = $cmd -> getLogFile();
	$this -> assert_str_equals('/tmp/cmdlTestLog.log', $logFile);
}

#==========================================
# test_cmdPackageMgrUsage_improper
#------------------------------------------
sub test_cmdPackageMgrUsage_improper {
	# ...
	# Test the storage of the package manager
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that the command line object has no default
	my $defMgr = $cmd -> getPackageManager();
	$this -> assert_null($defMgr);
	# Test improper call
	my $res = $cmd -> setPackageManager();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setPackageManager method called without specifying '
	. 'package manager value.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdPackageMgrUsage_noSupport
#------------------------------------------
sub test_cmdPackageMgrUsage_noSupport {
	# ...
	# Test the storage of the package manager
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test unsupported package manager
	my $res = $cmd -> setPackageManager('pablo');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Unsupported package manager specified: pablo';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdPackageMgrUsage_valid
#------------------------------------------
sub test_cmdPackageMgrUsage_valid {
	# ...
	# Test the storage of the package manager
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Make sure we can get our data back
	my $res = $cmd -> setPackageManager('zypper');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $pckMgr = $cmd -> getPackageManager();
	$this -> assert_str_equals('zypper', $pckMgr);
}

#==========================================
# test_cmdProfileUsage_invalid
#------------------------------------------
sub test_cmdProfileUsage_invalid {
	# ...
	# Test the storage for profile data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that there are no default profiles
	my $defProfs = $cmd -> getBuildProfiles();
	$this -> assert_null($defProfs);
	# Test improper call no argument
	my $res = $cmd -> setBuildProfiles();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setBuildProfiles method called without specifying '
		. 'profiles in ARRAY_REF';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdProfileUsage_improper
#------------------------------------------
sub test_cmdProfileUsage_improper {
	# ...
	# Test the storage for profile data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Set some list data
	my @profiles = qw(first second);
	# Test improper argument type
	my $res = $cmd -> setBuildProfiles(@profiles);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setBuildProfiles method expecting ARRAY_REF as '
		. 'argument';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdProfileUsage_valid
#------------------------------------------
sub test_cmdProfileUsage_valid {
	# ...
	# Test the storage for profile data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Set some list data
	my @profiles = qw(first second);
	# Proper use, make sure we get our array back
	my $res = $cmd -> setBuildProfiles(\@profiles);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we can get our data back
	my @cmdProfs = @{$cmd -> getBuildProfiles()};
	$this -> assert_array_equal(\@profiles, \@cmdProfs);
}

#==========================================
# test_cmdReplaceRepo_conflict
#------------------------------------------
sub test_cmdReplaceRepo_conflict {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	$cmd -> setIgnoreRepos(1);
	my $res = $cmd -> setReplacementRepo('os11.3', 'alias', 1, 'yast2');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Conflicting command line arguments; ignore repos '
		. 'and set repos';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdReplaceRepo_noAlias
#------------------------------------------
sub test_cmdReplaceRepo_noAlias {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	my $res = $cmd -> setReplacementRepo('os11.3', undef, 1, 'yast2');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = "No repo alias defined, generating time based name.\n";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
}

#==========================================
# test_cmdReplaceRepo_noPrio
#------------------------------------------
sub test_cmdReplaceRepo_noPrio {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	my $res = $cmd -> setReplacementRepo('os11.3', 'alias', undef, 'yast2');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = "No repo priority specified, using default value '10'\n";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Verify the default priority
	my %repoInfo = %{$cmd -> getReplacementRepo()};
	$this -> assert_equals(10, $repoInfo{repositoryPriority});
}

#==========================================
# test_cmdReplaceRepo_noRepo
#------------------------------------------
sub test_cmdReplaceRepo_noRepo {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that commandline object has no default setting
	my $defRepo = $cmd -> getReplacementRepo();
	$this -> assert_null($defRepo);
	# Test improper call no argument
	my $res = $cmd -> setReplacementRepo();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setReplacementRepo method called without specifying '
		. 'a repository.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdReplaceRepo_noRepoType
#------------------------------------------
sub test_cmdReplaceRepo_noRepoType {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	my $res = $cmd -> setReplacementRepo('os11.3', 'alias', 1);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setReplacementRepo method called without specifying '
		. 'a repository type.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdReplaceRepo_unsupRepoType
#------------------------------------------
sub test_cmdReplaceRepo_unsupRepoType {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	my $res = $cmd -> setReplacementRepo('os11.3', 'alias', 1, 'foo');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Specified repository type foo not supported.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
}

#==========================================
# test_cmdReplaceRepo_valid
#------------------------------------------
sub test_cmdReplaceRepo_valid {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	my $res = $cmd -> setReplacementRepo('os11.3', 'alias', 1, 'yast2');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Check we get the expected result
	my %repoInfo = %{$cmd -> getReplacementRepo()};
	$this -> assert_str_equals('os11.3', $repoInfo{repository});
	$this -> assert_str_equals('alias', $repoInfo{repositoryAlias});
	$this -> assert_equals(1, $repoInfo{repositoryPriority});
	$this -> assert_str_equals('yast2', $repoInfo{repositoryType});
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getCmdObj
#------------------------------------------
sub __getCmdObj {
	# ...
	# Helper method to create a CommandLine object;
	# ---
	my $this = shift;
	my $cmd = new KIWICommandLine($this -> {kiwi});
	return $cmd;
}

1;
