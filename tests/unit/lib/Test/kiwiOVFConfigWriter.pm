#================
# FILE          : kiwiOVFConfigWriter.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIOVFConfigWriter
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiOVFConfigWriter;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use File::Slurp;

use KIWICommandLine;
use KIWIOVFConfigWriter;
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
    $this->{dataDir} = $this -> getDataDir() . '/kiwiOVFConfWriter';
    $this -> removeTestTmpDir();
    return $this;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
    # ...
    # Test the KIWIOVFConfigWriter
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
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
    # Test the KIWIOVFConfigWriter with directory argument of
    # non existing directory
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIOVFConfigWriter: configuration target directory '
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
    # Test the KIWIOVFConfigWriter with invalid first argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $writer = KIWIOVFConfigWriter -> new('foo');
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIOVFConfigWriter: expecting KIWIXML object as '
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
    # Test the KIWIOVFConfigWriter with no argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $writer = KIWIOVFConfigWriter -> new();
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIOVFConfigWriter: expecting KIWIXML object as '
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
    # Test the KIWIOVFConfigWriter with no second argument
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml);
    my $msg = $kiwi -> getMessage();
    my $expected = 'KIWIOVFConfigWriter: expecting configuration target '
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
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
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
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
    my $cName = $writer -> getConfigFileName();
    my $msg = $kiwi -> getMessage();
    $this -> assert_str_equals('No messages set', $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('none', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('No state set', $state);
    # Test this condition last to get potential error messages
    my $arch = $xml -> getArch();
    $this -> assert_str_equals('ovfconfig-test.' . $arch . '-1.0.0.ovf', $cName);
    return;
}

#==========================================
# test_noImagePresent
#------------------------------------------
sub test_noImagePresent {
    # ...
    # Test an attempt to create a configuration when the image file does not
    # exist
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $arch = $xml -> getArch();
    my $expected = 'Could not find expected image '
        . "'/tmp/ovfconfig-test." . $arch . "-1.0.0.vmdk'";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    return;
}

#==========================================
# test_noMachineConfig
#------------------------------------------
sub test_noMachineConfig {
    # ...
    # Test an attempt to create a configuration when there is no <machine>
    # configuration
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/noOVFMachineConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $expected = 'Generation of OVF file requires <machine> '
        . "definition\nin config file.";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('error', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_str_equals('failed', $state);
    $this -> assert_null($res);
    return;
}

#==========================================
# test_powerWriteNoDVD
#------------------------------------------
sub test_powerWriteNoDVD {
    # ...
    # Test the creation of the config file for Power
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/powerOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10  2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/power.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_powerWriteNoDVD file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
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
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
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
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
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
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $writer = KIWIOVFConfigWriter -> new($xml, '/tmp');
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
# test_vmwareWriteDVDide
#------------------------------------------
sub test_vmwareWriteDVDide {
    # ...
    # Test the creation of the config file for VMWare with IDE DVD
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/dvdIdeConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10  2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/dvdIdeVMWare.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteDVDide file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteDVDscsi
#------------------------------------------
sub test_vmwareWriteDVDscsi {
    # ...
    # Test the creation of the config file for VMWare with SCSI DVD
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/dvdScsiConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10  2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/dvdScsiVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteDVDscsi file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteGenericGuestOS
#------------------------------------------
sub test_vmwareWriteGenericGuestOS {
    # ...
    # Test the creation of the config file for VMWare with unknown guest OS
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/genericGuestOSConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n"
    . "\nUnknown guest OS setting 'oel-64' using generic Linux setup";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/genericOSVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteGenericGuestOS file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteHWver8
#------------------------------------------
sub test_vmwareWriteHWver8 {
    # ...
    # Test the creation of the config file for VMWare with HW version 8
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/hwEightConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/hwEightVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteHWver8 file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteIdeCntrl
#------------------------------------------
sub test_vmwareWriteIdeCntrl {
    # ...
    # Test the creation of the config file for VMWare with HW version 8
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/ideCntrlConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/ideCntrlVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteIdeCntrl file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteKnownGuestOS
#------------------------------------------
sub test_vmwareWriteKnownGuestOS {
    # ...
    # Test the creation of the config file for VMWare with known guest OS
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my @knownDists = qw (rhel rhel-64 sles sles-64 suse suse-64);
    for my $dist (@knownDists) {
        my $confDir = $this -> {dataDir}
                        . qw (/)
                        . "$dist"
                        . 'GuestOSConfig';
        my $xml = $this -> __getXMLObj($confDir);
        my $cfgTgtDir = $this -> createTestTmpDir();
        my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
        $writer -> setPredictableID();
        my $cfgName = $writer -> getConfigFileName();
        my $vmdkName = $cfgName;
        $vmdkName =~ s/\.ovf/\.vmdk/msx;
        # Create a fake vmdk
        my $cmd = 'dd if=/dev/urandom '
            . "of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
        system $cmd;
        my $res = $writer -> writeConfigFile();
        my $msg = $kiwi -> getMessage();
        my $cfgFile = "$cfgTgtDir/$cfgName";
        my $expected = "Write OVF configuration file\n--> $cfgFile\n";
        $this -> assert_str_equals($expected, $msg);
        my $msgT = $kiwi -> getMessageType();
        $this -> assert_str_equals('info', $msgT);
        my $state = $kiwi -> getState();
        $this -> assert_not_null($res);
        $this -> assert_file_exists($cfgFile);
        my $arch = $xml -> getArch();
        my $refFile = $this -> getRefResultsDir()
            . "/$dist"
            . '_OSVMWare.ovf'
            . ".$arch";
        $res = $this -> compareFiles($refFile, $cfgFile);
        if ($res) {
            $this -> removeTestTmpDir();
        } else {
            my $saveDir = $this -> createResultSaveDir();
            system "cp $cfgFile $saveDir";
            my $tMsg = 'test_vmwareWriteKnownGuestOS file comparison failed, '
            . "for test '$dist'; result saved in $saveDir/$cfgName";
            $this -> assert(0, $msg);
            $this -> removeTestTmpDir();
        }
    }
    return;
}

#==========================================
# test_vmwareWriteMaxCPU
#------------------------------------------
sub test_vmwareWriteMaxCPU {
    # ...
    # Test the creation of the config file for VMWare with max CPU count set
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/maxCPUOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/maxCPUVMWare.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteMaxCPU file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteMinCPU
#------------------------------------------
sub test_vmwareWriteMinCPU {
    # ...
    # Test the creation of the config file for VMWare with min CPU count set
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/minCPUOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/minCPUVMWare.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteMinCPU file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteMinGTMaxCPU
#------------------------------------------
sub test_vmwareWriteMinGTMaxCPU {
    # ...
    # Test the creation of the config file for VMWare with min memory set
    # larger than max memory
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/minGTMaxCPUOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $errMsg = $kiwi -> getErrorMessage();
    my $errExpect = 'Minimum CPU count specified larger than maximum';
    $this -> assert_str_equals($errExpect, $errMsg);
    my $errState = $kiwi -> getErrorState();
    $this -> assert_str_equals('failed', $errState);
    # Reset the log state
    my $msg = $kiwi -> getMessage();
    my $msgT = $kiwi -> getMessageType();
    my $state = $kiwi -> getState();
    $this -> assert_null($res);
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# test_vmwareWriteMinMaxCPU
#------------------------------------------
sub test_vmwareWriteMinMaxCPU {
    # ...
    # Test the creation of the config file for VMWare with max and min CPU
    # count set
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/minMaxCPUOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/minMaxCPUVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteMinMaxCPU file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteMaxMemory
#------------------------------------------
sub test_vmwareWriteMaxMemory {
    # ...
    # Test the creation of the config file for VMWare with max memory set
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/maxMemoryOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/maxMemoryVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteMaxMemory file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteMinMemory
#------------------------------------------
sub test_vmwareWriteMinMemory {
    # ...
    # Test the creation of the config file for VMWare with min memory set
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/minMemoryOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/minMemoryVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteMinMemory file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteMinGTMaxMemory
#------------------------------------------
sub test_vmwareWriteMinGTMaxMemory {
    # ...
    # Test the creation of the config file for VMWare with min memory set
    # larger than max memory
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/minGTMaxMemoryOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $errMsg = $kiwi -> getErrorMessage();
    my $errExpect = 'Minimum memory specified larger than maximum';
    $this -> assert_str_equals($errExpect, $errMsg);
    my $errState = $kiwi -> getErrorState();
    $this -> assert_str_equals('failed', $errState);
    # Reset the log state
    my $msg = $kiwi -> getMessage();
    my $msgT = $kiwi -> getMessageType();
    my $state = $kiwi -> getState();
    $this -> assert_null($res);
    $this -> removeTestTmpDir();
    return;
}

#==========================================
# test_vmwareWriteMinMaxMemory
#------------------------------------------
sub test_vmwareWriteMinMaxMemory {
    # ...
    # Test the creation of the config file for VMWare with minMax memory set
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/minMaxMemoryOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/minMaxMemoryVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteMinMaxMemory file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteMultiNIC
#------------------------------------------
sub test_vmwareWriteMultiNIC {
    # ...
    # Test the creation of the config file for VMWare with multiple NICS
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/multiNICOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/multiNICVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteMultiNIC file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteNoDiskCrtl
#------------------------------------------
sub test_vmwareWriteNoDiskCrtl {
    # ...
    # Test the creation of the config file when no disk controller is specified
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/noDiskCrtlSpec';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $warnMsg = $kiwi -> getWarningMessage();
    my $warnExpect = '--> No disk controller set, using "lsilogic"';
    $this -> assert_str_equals($warnExpect, $warnMsg);
    my $warnState = $kiwi -> getNotsetState();
    $this -> assert_str_equals('notset', $warnState);
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    # The warning message is issued after the info message thus the log state
    # tracks the issued warning
    $this -> assert_str_equals('warning', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/noDiskCrtlVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteNoDiskCrtl file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteNoDVD
#------------------------------------------
sub test_vmwareWriteNoDVD {
    # ...
    # Test the creation of the config file for VMWare with no DVD device
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/baseOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/basicVMWare.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteNoDVD file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteNoCPUspec
#------------------------------------------
sub test_vmwareWriteNoCPUspec {
    # ...
    # Test the creation of the config file when no CPU is specified
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/noCPUspec';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $warnMsg = $kiwi -> getWarningMessage();
    my $warnExpect = '--> No nominal CPU count set, using 1';
    $this -> assert_str_equals($warnExpect, $warnMsg);
    my $warnState = $kiwi -> getNotsetState();
    $this -> assert_str_equals('notset', $warnState);
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    # The warning message is issued after the info message thus the log state
    # tracks the issued warning
    $this -> assert_str_equals('warning', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/noCPUVMWare.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteNoCPUspec file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteNoDiskCntrl
#------------------------------------------
sub test_vmwareWriteNoDiskCntrl {
    # ...
    # Test the creation of the config file when no Memory is specified
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/noDiskCntrl';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $warnMsg = $kiwi -> getWarningMessage();
    my $warnExpect = '--> No disk disktype set, using "scsi"';
    $this -> assert_str_equals($warnExpect, $warnMsg);
    my $warnState = $kiwi -> getNotsetState();
    $this -> assert_str_equals('notset', $warnState);
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    # The warning message is issued after the info message thus the log state
    # tracks the issued warning
    $this -> assert_str_equals('warning', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/noDiskCntrlVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteNoDiskCntrl file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_vmwareWriteNoMemoryspec
#------------------------------------------
sub test_vmwareWriteNoMemoryspec {
    # ...
    # Test the creation of the config file when no Memory is specified
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/noMemorySpec';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $warnMsg = $kiwi -> getWarningMessage();
    my $warnExpect = "--> No memory value set, using '1024 MB'";
    $this -> assert_str_equals($warnExpect, $warnMsg);
    my $warnState = $kiwi -> getNotsetState();
    $this -> assert_str_equals('notset', $warnState);
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    # The warning message is issued after the info message thus the log state
    # tracks the issued warning
    $this -> assert_str_equals('warning', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir()
        . '/noMemoryVMWare.ovf'
        . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_vmwareWriteNoMemoryspec file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_writeNoOvfType
#------------------------------------------
sub test_writeNoOvfType {
    # ...
    # Test the creation of the config file for the "default" ovf type
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/noOVFTypeConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $warnMsg = $kiwi -> getWarningMessage();
    my $warnExpect = '--> No OVF type specified using fallback "vmware".';
    $this -> assert_str_equals($warnExpect, $warnMsg);
    my $warnState = $kiwi -> getNotsetState();
    $this -> assert_str_equals('notset', $warnState);
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/basicVMWare.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_writeNoOvfType file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_xenWriteNoDVD
#------------------------------------------
sub test_xenWriteNoDVD {
    # ...
    # Test the creation of the config file for XEN
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/xenOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/xen.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_xenWriteNoDVD file comparison failed, '
            . "result saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
    return;
}

#==========================================
# test_zvmWriteNoDVD
#------------------------------------------
sub test_zvmWriteNoDVD {
    # ...
    # Test the creation of the config file for zvm
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $confDir = $this -> {dataDir} . '/zvmOVFConfig';
    my $xml = $this -> __getXMLObj($confDir);
    my $cfgTgtDir = $this -> createTestTmpDir();
    my $writer = KIWIOVFConfigWriter -> new($xml, $cfgTgtDir);
    $writer -> setPredictableID();
    my $cfgName = $writer -> getConfigFileName();
    my $vmdkName = $cfgName;
    $vmdkName =~ s/\.ovf/\.vmdk/msx;
    # Create a fake vmdk
    system "dd if=/dev/urandom of=$cfgTgtDir/$vmdkName bs=1k count=10 2>&1";
    my $res = $writer -> writeConfigFile();
    my $msg = $kiwi -> getMessage();
    my $cfgFile = "$cfgTgtDir/$cfgName";
    my $expected = "Write OVF configuration file\n--> $cfgFile\n";
    $this -> assert_str_equals($expected, $msg);
    my $msgT = $kiwi -> getMessageType();
    $this -> assert_str_equals('info', $msgT);
    my $state = $kiwi -> getState();
    $this -> assert_not_null($res);
    $this -> assert_file_exists($cfgFile);
    my $arch = $xml -> getArch();
    my $refFile = $this -> getRefResultsDir() . '/zvm.ovf' . ".$arch";
    $res = $this -> compareFiles($refFile, $cfgFile);
    if ($res) {
        $this -> removeTestTmpDir();
    } else {
        my $saveDir = $this -> createResultSaveDir();
        system "cp $cfgFile $saveDir";
        my $tMsg = 'test_zvmWriteNoDVD file comparison failed, result '
            . "saved in $saveDir/$cfgName";
        $this -> assert(0, $msg);
        $this -> removeTestTmpDir();
    }
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
