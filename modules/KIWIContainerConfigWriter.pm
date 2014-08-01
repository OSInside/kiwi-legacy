#================
# FILE          : KIWIContainerConfigWriter.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Write a configuration file for a container
#               :
# STATUS        : Development
#----------------
package KIWIContainerConfigWriter;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
use base qw /KIWIConfigWriter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIXML;
use KIWIXMLVMachineData;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the KIWIContainerConfigWriter object
    # ---
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    if (! $this) {
        return;
    }
    $this->{name} = 'config';
    return $this;
}

#==========================================
# p_writeConfigFile
#------------------------------------------
sub p_writeConfigFile {
    # ...
    # Write the container configuration file
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $xml = $this->{xml};
    my $loc = $this -> getConfigDir();
    my $fileName = $this -> getConfigFileName();
    $kiwi -> info("Write container configuration file\n");
    $kiwi -> info ("--> $loc/$fileName");
    my $vmConfig = $xml -> getVMachineConfig();
    my $config = '# KIWI generated container configuration file' . "\n";
    if ($vmConfig) {
        my @nicIDs = @{$vmConfig -> getNICIDs()};
        # Only consider the first nic specified
        if (@nicIDs) {
            my $nmode = $vmConfig -> getNICMode($nicIDs[0]);
            if (! $nmode) {
                $nmode = 'veth';
            }
            $config .= "lxc.network.type = $nmode" . "\n"
                . 'lxc.network.flags = up' . "\n"
                . 'lxc.network.link = br0' . "\n";
            my $mac = $vmConfig -> getNICMAC($nicIDs[0]);
            if ($mac) {
                $config .= 'lxc.network.hwaddr = ' . $mac . "\n";
            }
            my $iface = $vmConfig -> getNICInterface($nicIDs[0]);
            if (! $iface) {
                $iface = 'eth0';
            }
            $config .= 'lxc.network.name = ' . $iface . "\n"
                . '#remove next line if host DNS configuration should not '
                . 'be available to container' . "\n"
                . 'lxc.mount.entry = /etc/resolv.conf '
                . '/var/lib/lxc/testCont/rootfs/etc/resolv.conf none '
                . 'bind,ro 0 0' . "\n";
        }
    }
    $config .= "\n" . '#When the host system has lxc >= 0.8.0 uncoment '
        . 'the following line' . "\n"
        . '#lxc.autodev=1' . "\n"
        . 'lxc.tty = 4' . "\n"
        . 'lxc.pts = 1024' . "\n";
    my $name =  $xml -> getImageType() -> getContainerName();
    $config .= 'lxc.rootfs = /var/lib/lxc/' . $name . '/rootfs' . "\n";
    $config .= 'lxc.mount = /etc/lxc/' . $name . '/fstab' . "\n\n"
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
    my $status = open (my $CONF, '>', "$loc/$fileName");
    if (! $status) {
        $kiwi -> failed();
        my $msg = 'Could not write container configuration file'
            . "$loc/$fileName";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    binmode $CONF;
    print $CONF $config;
    $status = close $CONF;
    if (! $status) {
        $kiwi -> oops();
        my $msg = 'Unable to close configuration file'
            . "$loc/$fileName";
        $kiwi -> warning($msg);
        $kiwi -> skipped();
    }
    $kiwi -> done();
    $status = $this -> __writeFStab();
    if (! $status) {
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __writeFStab
#------------------------------------------
sub __writeFStab {
    # ...
    # Wite the fstab for the configuration
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    $kiwi -> info('Write fstab for container');
    my $xml = $this->{xml};
    my $name =  $xml -> getImageType() -> getContainerName();
    my $fstab = '# KIWI generated container fstab' . "\n"
        . 'proc  /var/lib/lxc/' . $name . '/rootfs/proc  proc  '
        . 'nodev,noexec,nosuid 0 0' . "\n"
        . 'sysfs /var/lib/lxc/' . $name . '/rootfs/sys  '
        . 'sysfs  defaults  0 0' . "\n";

    my $loc = $this -> getConfigDir();
    my $status = open (my $CONF, '>', "$loc/fstab");
    if (! $status) {
        $kiwi -> failed();
        my $msg = 'Could not write container fstab'
            . "$loc/fstab";
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    binmode $CONF;
    print $CONF $fstab;
    $status = close $CONF;
    if (! $status) {
        my $msg = 'Unable to close fstab file'
            . "$loc/fstab";
        $kiwi -> warning($msg);
        $kiwi -> skipped();
    }
    $kiwi -> done();
    return 1;
}

1;
