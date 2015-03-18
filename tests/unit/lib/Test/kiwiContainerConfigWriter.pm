#================
# FILE          : kiwiContainerConfigWriter.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIContainerConfigWriter
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiContainerConfigWriter;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use File::Slurp;

use KIWICommandLine;
use KIWIContainerConfigWriter;
use KIWILog;
use KIWIXML;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Construct new test case
    # ---
    my $this = shift -> SUPER::new(@_);
    $this->{dataDir} = $this -> getDataDir() . '/kiwiContainerConfWriter';
    $this -> removeTestTmpDir();
    return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
    # ...
    # Test the KIWIContainerConfigWriter
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml, '/tmp');
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($writer);
    return;
}

#==========================================
# test_ctor_dirNoExist
#------------------------------------------
sub test_ctor_dirNoExist {
    # ...
    # Test the KIWIContainerConfigWriter with directory argument of
    # non existing directory
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml, '/foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIContainerConfigWriter: configuration target directory '
        . 'does not exist.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_ctor_invalidArg1
#------------------------------------------
sub test_ctor_invalidArg1 {
    # ...
    # Test the KIWIContainerConfigWriter with invalid first argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $writer = KIWIContainerConfigWriter -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIContainerConfigWriter: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_ctor_noArg1
#------------------------------------------
sub test_ctor_noArg1 {
    # ...
    # Test the KIWIContainerConfigWriter with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $writer = KIWIContainerConfigWriter -> new();
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIContainerConfigWriter: expecting KIWIXML object as '
        . 'first argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_ctor_noArg2
#------------------------------------------
sub test_ctor_noArg2 {
    # ...
    # Test the KIWIContainerConfigWriter with no second argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIContainerConfigWriter: expecting configuration target '
        . 'directory as second argument.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($writer);
    return;
}

#==========================================
# test_getConfigDir
#------------------------------------------
sub test_getConfigDir {
    # ...
    # Test the getConfigDir method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml, '/tmp');
    my $cDir = $writer -> getConfigDir();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_str_equals('/tmp', $cDir);
    return;
}

#==========================================
# test_getConfigFileName
#------------------------------------------
sub test_getConfigFileName {
    # ...
    # Test the getConfigFileName method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml, '/tmp');
    my $cName = $writer -> getConfigFileName();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_str_equals('config', $cName);
    return;
}

#==========================================
# test_setConfigDir
#------------------------------------------
sub test_setConfigDir {
    # ...
    # Test the setConfigDir method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml, '/tmp');
    my $dir = $this -> createTestTmpDir();
    $writer = $writer -> setConfigDir($dir);
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($writer);
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# test_setConfigDirNoArg
#------------------------------------------
sub test_setConfigDirNoArg {
    # ...
    # Test the setConfigDir method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml, '/tmp');
    my $res = $writer -> setConfigDir();
    my $msg = $kiwi -> getMessage();
    my $expected = 'setConfigDir: no configuration directory argument '
        . 'provided, retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    my $cDir = $writer -> getConfigDir();
    $this -> assert_str_equals('/tmp', $cDir);
    return;
}

#==========================================
# test_setConfigDirNoExist
#------------------------------------------
sub test_setConfigDirNoExist {
    # ...
    # Test the setConfigDir method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIContainerConfigWriter -> new($xml, '/tmp');
    my $res = $writer -> setConfigDir('/foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'setConfigDir: given configuration directory does not '
        . 'exist, retaining current data.';
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_null($res);
    my $cDir = $writer -> getConfigDir();
    $this -> assert_str_equals('/tmp', $cDir);
    return;
}

#==========================================
# test_p_writeConfigFile
#------------------------------------------
sub test_p_writeConfigFile {
    # ...
    # Test the p_writeConfigFile method
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir};
    my $xml = $this -> __getXMLObj($confDir);
    my $cDir = $this -> createTestTmpDir();
    my $writer = KIWIContainerConfigWriter -> new($xml, $cDir);
    my $res = $writer -> p_writeConfigFile();
    my $msg = $kiwi -> getInfoMessage();
    my $expected = "Write container configuration file\n"
        . "--> /tmp/kiwiDevTests/configWrite fstab for container";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('completed', $state);
    # Test this condition last to get potential error messages
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cDir . '/config');
    $this -> assert_file_exists($cDir . '/fstab');
    my $config = '# KIWI generated container configuration file' . "\n"
        . 'lxc.network.type = vmac' . "\n"
        . 'lxc.network.flags = up' . "\n"
        . 'lxc.network.link = br0' . "\n"
        . 'lxc.network.hwaddr = 3E:EB:99:EA:AB:52' . "\n"
        . 'lxc.network.name = eth2' . "\n"
        . '#remove next line if host DNS configuration should not '
        . 'be available to container' . "\n"
        . 'lxc.mount.entry = /etc/resolv.conf '
        . '/var/lib/lxc/testCont/rootfs/etc/resolv.conf none '
        . 'bind,ro 0 0' . "\n\n"
        . 'lxc.autodev=1' . "\n"
        . 'lxc.tty = 4' . "\n"
        . 'lxc.kmsg = 0' . "\n"
        . 'lxc.pts = 1024' . "\n"
        . 'lxc.rootfs = /var/lib/lxc/mycontainer/rootfs' . "\n"
        . 'lxc.mount = /etc/lxc/mycontainer/fstab' . "\n\n"
        . 'lxc.cgroup.devices.deny = a' . "\n"
        . '# /dev/null and zero' . "\n"
        . 'lxc.cgroup.devices.allow = c 1:3 rwm' . "\n"
        . 'lxc.cgroup.devices.allow = c 1:5 rwm' . "\n"
        . '# consoles' . "\n"
        . 'lxc.cgroup.devices.allow = c 5:1 rwm' . "\n"
        . 'lxc.cgroup.devices.allow = c 5:0 rwm' . "\n"
        . 'lxc.cgroup.devices.allow = c 4:0 rwm' . "\n"
        . 'lxc.cgroup.devices.allow = c 4:1 rwm' . "\n"
        . '# /dev/{,u}random' . "\n"
        . 'lxc.cgroup.devices.allow = c 1:9 rwm' . "\n"
        . 'lxc.cgroup.devices.allow = c 1:8 rwm' . "\n"
        . 'lxc.cgroup.devices.allow = c 136:* rwm' . "\n"
        . 'lxc.cgroup.devices.allow = c 5:2 rwm' . "\n"
        . '# rtc' . "\n"
        . 'lxc.cgroup.devices.allow = c 254:0 rwm' . "\n";
    my $text = read_file($cDir . '/config');
    $this -> assert_str_equals($config, $text);
    my $fstab = '# KIWI generated container fstab' . "\n"
        . 'proc  /var/lib/lxc/mycontainer/rootfs/proc  proc  '
        . 'nodev,noexec,nosuid 0 0' . "\n"
        . 'sysfs /var/lib/lxc/mycontainer/rootfs/sys  '
        . 'sysfs  defaults  0 0' . "\n";
    my $fstabT = read_file($cDir . '/fstab');
    $this -> assert_str_equals($fstab, $fstabT);
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getXMLObj
#------------------------------------------
sub __getXMLObj {
    # ...
    # Create an XML object with the given config dir
    # ---
    my $this      = shift;
    my $configDir = shift;
    my $kiwi = $this->{kiwi};
    # TODO
    # Fix the creation of the XML object once the ctor arguments change
    my $cmdL = KIWICommandLine -> new();
    my $xml = KIWIXML -> new(
        $configDir, undef, undef, $cmdL
    );
    if (! $xml) {
        my $errMsg = $kiwi -> getMessage();
        print "XML create msg: $errMsg\n";
        my $msg = 'Failed to create XML obj, most likely improper config '
        . 'path: '
        . $configDir;
        $this -> assert_equals(1, $msg);
    }
    return $xml;
}

1;
