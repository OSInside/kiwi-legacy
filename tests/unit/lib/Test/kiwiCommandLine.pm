#================
# FILE          : kiwiCommandLine.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
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

use Cwd;
use FindBin;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWICommandLine;
use KIWIXMLRepositoryData;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
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
	my $cmd = KIWICommandLine -> new();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($cmd);

	return;
}

#==========================================
# test_cmdAddPackages_improperArg
#------------------------------------------
sub test_cmdAddPackages_improperArg {
	# ...
	# Test the AdditionalPackages storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @packages = ('foo');
	my $res = $cmd -> setAdditionalPackages(@packages);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalPackages method expecting ARRAY_REF as '
		. 'first argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdAddPackages_noArg
#------------------------------------------
sub test_cmdAddPackages_noArg {
	# ...
	# Test the AdditionalPackages storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide no argument
	my $res = $cmd -> setAdditionalPackages();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalPackages method called without '
		. 'specifying packages';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdAddPackages_valid
#------------------------------------------
sub test_cmdAddPackages_valid {
	# ...
	# Test the AdditionalPackages storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Make sure there is no dafault
	my $addlPckgs = $cmd -> getPackagesToRemove();
	$this -> assert_null($addlPckgs);
	# Expected use case
	my @packages = ('foo', 'bar');
	my $res = $cmd -> setAdditionalPackages(\@packages);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	$addlPckgs = $cmd -> getAdditionalPackages();
	$this -> assert_array_equal(\@packages, $addlPckgs);

	return;
}

#==========================================
# test_cmdAddPatterns_improperArg
#------------------------------------------
sub test_cmdAddPatterns_improperArg {
	# ...
	# Test the AdditionalPatterns storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @patterns = ('foo');
	my $res = $cmd -> setAdditionalPatterns(@patterns);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalPatterns method expecting ARRAY_REF as '
		. 'first argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdAddPatterns_noArg
#------------------------------------------
sub test_cmdAddPatterns_noArg {
	# ...
	# Test the AdditionalPatterns storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide no argument
	my $res = $cmd -> setAdditionalPatterns();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalPatterns method called without '
		. 'specifying packages';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdAddPatterns_valid
#------------------------------------------
sub test_cmdAddPatterns_valid {
	# ...
	# Test the AdditionalPatterns storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Make sure there is no dafault
	my $addlPatterns = $cmd -> getPackagesToRemove();
	$this -> assert_null($addlPatterns);
	# Expected use case
	my @patterns = ('foo', 'bar');
	my $res = $cmd -> setAdditionalPatterns(\@patterns);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	$addlPatterns = $cmd -> getAdditionalPatterns();
	$this -> assert_array_equal(\@patterns, $addlPatterns);

	return;
}

#==========================================
# test_cmdAddRepos_invalidType
#------------------------------------------
sub test_cmdAddRepos_invalidType {
	# ...
	# Test the AdditionalRepo storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	my $res = $cmd -> setAdditionalRepos('foo');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method expecting ARRAY_REF as '
		. 'argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
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

	return;
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
	my %init = (
		path => '/work/myrepo',
		type => 'rpm-dir'
	);
	my $repo = KIWIXMLRepositoryData -> new(\%init);
	my @repos = ($repo, 'foo');
	my $res = $cmd -> setAdditionalRepos(\@repos);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setAdditionalRepos method expecting ARRAY_REF of '
		. 'KIWIXMLRepositoryData objects.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
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
	my %init = (
		path => '/work/myrepo',
		type => 'rpm-dir'
	);
	my $repo = KIWIXMLRepositoryData -> new(\%init);
	my @repos = ($repo);
	%init = (
		path => 'http://download.opensuse.org/distribution/12.3',
		type => 'yast2'
	);
	$repo = KIWIXMLRepositoryData -> new(\%init);
	push @repos, $repo;
	my $res = $cmd -> setAdditionalRepos(\@repos);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	my $repoInfo = $cmd -> getAdditionalRepos();
	for my $repoObj (@{$repoInfo}) {
		$this -> assert_str_equals(ref($repoObj), 'KIWIXMLRepositoryData');
	}
	return;
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

	return;
}

#==========================================
# test_cmdCacheDirUsage_relPath
#------------------------------------------
sub test_cmdCacheDirUsage_relPath {
	# ...
	#Test the storage and verification of the cache directory data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Specify relative path
	my $res = $cmd -> setCacheDir('tmp');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Specified relative path as cache location; moving '
		. "cache to /var/cache/kiwi/image/tmp\n";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get the proper value back
	my $dir = $cmd -> getCacheDir();
	$this -> assert_str_equals('/var/cache/kiwi/image/tmp', $dir);

	return;
}

#==========================================
# test_cmdCacheDirUsage_noArg
#------------------------------------------
sub test_cmdCacheDirUsage_noArg {
	# ...
	# Test the storage and verification of the cache directory data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# No argument specified
	my $res = $cmd -> setCacheDir();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setCacheDir method called without specifying a '
		. 'cache directory.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdCacheDirUsage_valid
#------------------------------------------
sub test_cmdCacheDirUsage_valid {
	# ...
	# Test the storage and verification of the cache directory data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Expecting success
	my $res = $cmd -> setCacheDir('/tmp');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	my $dir = $cmd -> getCacheDir();
	$this -> assert_str_equals('/tmp', $dir);

	return;
}

#==========================================
# test_cmdCacheDirUsage_noDirWrite
#------------------------------------------
sub test_cmdCacheDirUsage_noDirWrite {
	# ...
	# Test the storage and verification of the cache directory data
	# ---
	if ($< == 0) {
		print "\t\tInfo: user root, skipping ";
		print "test_cmdCacheDirUsage_noDirRead\n";
		return;
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Directory has no read access
	# If the test is run a root the test is skipped
	my $res = $cmd -> setCacheDir('/root');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'No write access to specified cache directory '
		. '"/root".';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
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

	return;
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

	return;
}

#==========================================
# test_cmdConfDirUsage_noDirRead
#------------------------------------------
sub test_cmdConfDirUsage_noDirRead {
	# ...
	# Test the storage and verification of the configuration directory data
	# ---
	if ($< == 0) {
		print "\t\tInfo: user root, skipping test_cmdConfDirUsage_noDirRead\n";
		return;
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Directory has no read access
	# If the test is run a root the test is skipped
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

	return;
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

	return;
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

	return;
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
	my %init = (
		path => '/work/myrepo',
		type => 'rpm-dir'
	);
	my $repo = KIWIXMLRepositoryData -> new(\%init);
	$cmd -> setReplacementRepo($repo);
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

	return;
}

#==========================================
# test_cmdImageArchUsage_invalidArg
#------------------------------------------
sub test_cmdImageArchUsage_invalidArg {
	# ...
	# Test the storage of the logfile path
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	my $res = $cmd -> setImageArchitecture('ia64');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Improper architecture setting, expecting on of: '
		. 'i586 x86_64';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdImageArchUsage_noArg
#------------------------------------------
sub test_cmdImageArchUsage_noArg {
	# ...
	# Test the storage of the logfile path
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that the command line object has no default
	my $defArch = $cmd -> getImageArchitecture();
	$this -> assert_null($defArch);
	# Test improper call no argument
	my $res = $cmd -> setImageArchitecture();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setImageArchitecture method called without specifying '
		. 'an architecture.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdImageArchUsage_valid
#------------------------------------------
sub test_cmdImageArchUsage_valid {
	# ...
	# Test the storage of the logfile path
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test improper call no argument
	my $res = $cmd -> setImageArchitecture('x86_64');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our value back
	my $arch = $cmd -> getImageArchitecture();
	$this -> assert_str_equals('x86_64', $arch);

	return;
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

	return;
}

#==========================================
# test_cmdLogFileUsage_noWrite
#------------------------------------------
sub test_cmdLogFileUsagee_noWrite {
	# ...
	# Test the storage of the logfile path
	# ---
	if ($< == 0) {
		print "\t\tInfo: user root, skipping test_cmdLogFileUsagee_noWrite\n";
		return;
	}
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test no write permission
	# If the test is executed as root this test is skipped
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

	return;
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

	return;
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

	return;
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

	return;
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

	return;
}

#==========================================
# test_cmdPckgsRemove_improperArg
#------------------------------------------
sub test_cmdPckgsRemove_improperArg {
	# ...
	# Test the PackagesToRemove storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide improper argument
	my @packages = ('foo');
	my $res = $cmd -> setPackagesToRemove(@packages);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setPackagesToRemove method expecting ARRAY_REF as '
		. 'first argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdPckgsRemove_noArg
#------------------------------------------
sub test_cmdPckgsRemove_noArg {
	# ...
	# Test the PackagesToRemove storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Provide no argument
	my $res = $cmd -> setPackagesToRemove();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setPackagesToRemove method called without '
		. 'specifying packages';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdPckgsRemove_valid
#------------------------------------------
sub test_cmdPckgsRemove_valid {
	# ...
	# Test the PackagesToRemove storage
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Make sure there is no dafault
	my $rmPckgs = $cmd -> getPackagesToRemove();
	$this -> assert_null($rmPckgs);
	# Expected use case
	my @packages = ('foo', 'bar');
	my $res = $cmd -> setPackagesToRemove(\@packages);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Make sure we get our data back
	$rmPckgs = $cmd -> getPackagesToRemove();
	$this -> assert_array_equal(\@packages, $rmPckgs);

	return;
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

	return;
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

	return;
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

	return;
}

#==========================================
# test_cmdRecycleRoot_delayedSet
#------------------------------------------
sub test_cmdRecycleRoot_delayedSet {
	# ...
	# Test the storage for root directory recycling
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test the command lien object has no default
	my $recycle = $cmd -> getRecycleRootDir();
	$this -> assert_null($recycle);
	# Enable root recycle, make sure we have not data as the source is not
	# set yet
	$cmd -> setRootRecycle();
	$recycle = $cmd -> getRecycleRootDir();
	$this -> assert_null($recycle);
	# Set the root target, verify the recycle root get set
	$cmd -> setRootTargetDir('/tmp');
	$recycle = $cmd -> getRecycleRootDir();
	$this -> assert_str_equals('/tmp', $recycle);

	return;
}

#==========================================
# test_cmdRecycleRoot_delayedSet
#------------------------------------------
sub test_cmdRecycleRoot_immediateSet {
	# ...
	# Test the storage for root directory recycling
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();

	# Enable root recycle should have immediate effect
	$cmd -> setRootTargetDir('/tmp');
	$cmd -> setRootRecycle();
	my $recycle = $cmd -> getRecycleRootDir();
	$this -> assert_str_equals('/tmp', $recycle);

	return;
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
	my %init = (
		path => '/work/myrepo',
		type => 'rpm-dir'
	);
	my $repo = KIWIXMLRepositoryData -> new(\%init);
	my $res = $cmd -> setReplacementRepo($repo);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'Conflicting command line arguments; ignore repos '
		. 'and set repos';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdReplaceRepo
#------------------------------------------
sub test_cmdReplaceRepo {
	# ...
	# Test the storage of the replacement repo information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that commandline object has no default setting
	my $defRepo = $cmd -> getReplacementRepo();
	$this -> assert_null($defRepo);
	my %init = (
		path => '/work/myrepo',
		type => 'rpm-dir'
	);
	my $repo = KIWIXMLRepositoryData -> new(\%init);
	my $res = $cmd -> setReplacementRepo($repo);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	my $repoObj = $cmd -> getReplacementRepo();
	$this -> assert_str_equals('KIWIXMLRepositoryData', ref($repoObj));
	return;
}

#==========================================
# test_cmdReplaceRepo_invalidType
#------------------------------------------
sub test_cmdReplaceRepo_invalidType {
	# ...
	# Test the storage of the replacement repo information, generate
	# an error for wrong argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	my $res = $cmd -> setReplacementRepo('foo');
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setReplacementRepo: expecting KIWIXMLRepositoryData '
		. 'object as argument.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	return;
}

#==========================================
# test_cmdReplaceRepo_noArg
#------------------------------------------
sub test_cmdReplaceRepo_noArg {
	# ...
	# Test the storage of the replacement repo information, generate an
	# error when no argument is given
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
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
	return;
}

#==========================================
# test_cmdRootTargetDir_noArgs
#------------------------------------------
sub test_cmdRootTargetDir_noArgs {
	# ...
	# Test the storage of the root target directory information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test that commandline object has no default setting
	my $rootTgt = $cmd -> getRootTargetDir();
	$this -> assert_null($rootTgt);
	# Test improper call no argument
	my $res = $cmd -> setRootTargetDir();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'setRootTargetDir method called without specifying a '
		. 'target directory';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);

	return;
}

#==========================================
# test_cmdRootTargetDir_absPath
#------------------------------------------
sub test_cmdRootTargetDir_absPath {
	# ...
	# Test the storage of the root target directory information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test expected use case with absolute path
	my $res = $cmd -> setRootTargetDir('/tmp');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Check we get the expected result
	my $rootTgt = $cmd -> getRootTargetDir();
	$this -> assert_str_equals('/tmp', $rootTgt);

	return;
}

#==========================================
# test_cmdRootTargetDir_noArgs
#------------------------------------------
sub test_cmdRootTargetDir_relPath {
	# ...
	# Test the storage of the root target directory information
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $cmd = $this -> __getCmdObj();
	# Test expected use case with absolute path
	my $res = $cmd -> setRootTargetDir('unpacked');
	my $tgtPath = Cwd::realpath($FindBin::Bin . '/../../tests/unit/unpacked');
	my $expectedMsg = 'Specified relative path for target directory; target '
		. "is $tgtPath\n";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('info', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($res);
	# Check we get the expected result
	my $rootTgt = $cmd -> getRootTargetDir();
	$this -> assert_str_equals($tgtPath, $rootTgt);

	return;
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
	my $cmd = KIWICommandLine -> new();
	return $cmd;
}

1;
