################################################################
# Copyright (c) 2014, 2015 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file LICENSE); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
package KIWIMiniIsoPlugin;

use strict;
use warnings;

use base "KIWIBasePlugin";
use Data::Dumper;
use Config::IniFiles;
use File::Find;
use FileHandle;
use Carp;
use File::Basename qw /dirname/;

sub new {
    # ...
    # Create a new KIWIMiniIsoPlugin object
    # ---
    my $class   = shift;
    my $handler = shift;
    my $config  = shift;
    my $configpath;
    my $configfile;
    my $this = KIWIBasePlugin -> new($handler);
    bless ($this, $class);
    if ($config =~ m{(.*)/([^/]+)$}x) {
        $configpath = $1;
        $configfile = $2;
    }
    if ((! $configpath) || (! $configfile)) {
        $this->logMsg("E",
            "wrong parameters in plugin initialisation\n"
        );
        return;
    }
    ## plugin content:
    #-----------------
    #[base]
    # name = KIWIEulaPlugin
    # order = 3
    # defaultenable = 1
    #
    #[target]
    # targetfile = content
    # targetdir = $PRODUCT_DIR
    # media = (list of numbers XOR "all")
    #
    my $ini = Config::IniFiles -> new (
        -file => "$configpath/$configfile"
    );
    my $name   = $ini->val('base', 'name');
    my $order  = $ini->val('base', 'order');
    my $enable = $ini->val('base', 'defaultenable');
    # if any of those isn't set, complain!
    if (not defined($name)
        or not defined($order)
        or not defined($enable)
    ) {
        $this->logMsg("E",
            "Plugin ini file <$config> seems broken!\n"
        );
        return;
    }
    $this->name($name);
    $this->order($order);
    if($enable != 0) {
        $this->ready(1);
    }
    return $this;
}

sub execute {
    my $this = shift;
    if(not ref($this)) {
        return;
    }
    my $retval = 0;
    if($this->{m_ready} == 0) {
        return $retval;
    }
    my $repoloc = $this->collect()->productData()->getOpt("REPO_LOCATION");
    my $ismini = $this->collect()->productData()->getVar("FLAVOR");
    if(not defined($ismini)) {
        $this->logMsg("W", "FLAVOR not set?");
        return $retval;
    }
    if ($ismini !~ m{mini}i) {
        $this->logMsg("I",
            "Nothing to do for media type <$ismini>"
        );
        return $retval;
    }
    my ($srv, $path);
    if (not defined($repoloc)) {
        $this->logMsg("I",
            "<REPO_LOCATION> is unset, boot protocol will be set to 'slp'!"
        );
    } else {
        if ($repoloc =~ m{^http://([^/]+)/(.+)}x) {
            ($srv, $path) = ($1, $2);
        }
        if(not defined($srv) or not defined($path)) {
            $this->logMsg("W",
                "Parsing repo-location=<$repoloc> failed!"
            );
            return $retval;
        }
    }
    
    my @rootfiles;
    find(
        sub { find_cb($this, '.*/root$', \@rootfiles) },
        $this->handler()->collect()->basedir()
    );
    if (@rootfiles) {
        $this->removeInstallSystem($rootfiles[0]);
    }

    my @isolxfiles;
    find(
        sub { find_cb($this, '.*/isolinux.cfg$', \@isolxfiles) },
        $this->handler()->collect()->basedir()
    );
    if (@isolxfiles) {
        $this->removeMediaCheck($isolxfiles[0]);
    }

    $this -> updateInitRDNET($repoloc);

    my @gfxbootfiles;
    find(
        sub { find_cb($this, '.*/gfxboot\.cfg$', \@gfxbootfiles) },
        $this->handler()->collect()->basedir()
    );

    if (!@gfxbootfiles) {
        my $msg = "No gfxboot.cfg file found! "
            . "This _MIGHT_ be ok for S/390. "
            . "Please verify <installation-images> package(s)";
        $this->logMsg("W", $msg);
        return $retval;
    }
    $retval = $this -> updateGraphicsBootConfig (
        \@gfxbootfiles, $repoloc, $srv, $path
    );

    return $retval;
}

sub removeInstallSystem {
    my $this = shift;
    my $rootfile = shift;

    print STDERR "RF $rootfile\n";
    my $rootdir = dirname($rootfile);
    $this->logMsg("I", "removing files from <$rootdir>");
    foreach my $file (glob("$rootdir/*")) {
        if (-f $file && $file !~ m,/(efi|linux|initrd)$,) {
            $this->logMsg("I", "removing <$file>");
	    unlink $file;
        }
    }
    return $this;
}

sub removeMediaCheck {
	my $this = shift;
	my $cfg = shift;

	$this->logMsg("I", "Processing file <$cfg>: ");

    my $CFG = FileHandle -> new();
    if (! $CFG -> open($cfg)) {
		$this->logMsg("E", "Cant open file <$cfg>!");
		return;
	}

    my $CFGNEW = FileHandle -> new();
    if (! $CFGNEW -> open(">$cfg.new")) {
		$this->logMsg("E", "Cant open file <$cfg.new>!");
		return;
	}

	my $mediacheck = -1;
	while ( <$CFG> ) {
		chomp;

		if (m/label mediachk/) {
			$mediacheck = 1;
		}
		if ($mediacheck == 1 && m/^\s*$/) {
			$mediacheck = -1;
		}

		if ($mediacheck == 1) {
			print $CFGNEW "#$_\n";
		} else {
			print $CFGNEW "$_\n";
		}
	}

	$CFG -> close();
	$CFGNEW -> close();

	unlink $cfg;
	rename "$cfg.new", $cfg;
    return $this;
}

sub updateGraphicsBootConfig {
    my $this = shift;
    my $gfxbootfiles = shift;
    my $repoloc = shift;
    my $srv = shift;
    my $path = shift;
    my $retval = 0;
    foreach my $cfg(@{$gfxbootfiles}) {
        $this->logMsg("I", "Processing file <$cfg>: ");
        my $F = FileHandle -> new();
        if (! $F -> open($cfg)) {
            $this->logMsg("E", "Cant open file <$cfg>!");
            next;
        }
        my @lines = <$F>;
        $F -> close();
        chomp(@lines);
        my $install = -1;
        my $ihs = -1;
        my $ihp = -1;
        my $i = -1;
        foreach my $line(@lines) {
            $i++;
            next if $line !~ m{^install}x;
            if($line =~ m{^install=.*}x) {
                $install = $i;
            }
            if ($line =~ m{^install.http.server=+}x) {
                $ihs = $i;
            }
            if($line =~ m{^install.http.path=+}x) {
                $ihp = $i;
            }
        }
        if(!$repoloc) {
            if($install == -1) {
                push @lines, "install=slp";
            } else {
                $lines[$install] =~ s{^install.*}{install=slp}x;
            }
        } elsif($srv) {
            if($ihs == -1) {
                push @lines, "install.http.server=$srv";
            } else {
                $lines[$ihs] =~ s{^(install.http.server).*}{$1=$srv}x;
            }
            if($ihp == -1) {
                push @lines, "install.http.path=$path";
            } else {
                $lines[$ihp] =~ s{^(install.http.path).*}{$1=$path}x;
            }
            if($install == -1) {
                push @lines, "install=http";
            } else {
                $lines[$install] =~ s{^install.*}{install=http}x;
            }
        }
        unlink $cfg;
        if (! $F -> open(">$cfg")) {
            $this->logMsg("E", "Cant open file for writing <$cfg>!");
            next;
        }
        foreach(@lines) {
            print $F "$_\n";
        }
        $F -> close();
        $retval++;
    }
    return $retval;
}

# borrowed from obs with permission from mls@suse.de to license as
# GPLv2+
sub _makecpiohead {
    my ($name, $s) = @_;
    return "07070100000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000b00000000TRAILER!!!\0\0\0\0" if !$s;
    #        magic ino
    my $h = "07070100000000";
    # mode                S_IFREG
    $h .= sprintf("%08x", oct(100000) | $s->[2]&oct(777));
    #      uid     gid     nlink
    $h .= "000000000000000000000001";
    $h .= sprintf("%08x%08x", $s->[9], $s->[7]);
    $h .= "00000000000000000000000000000000";
    $h .= sprintf("%08x", length($name) + 1);
    $h .= "00000000$name\0";
    $h .= substr("\0\0\0\0", (length($h) & 3)) if length($h) & 3;
    my $pad = '';
    $pad = substr("\0\0\0\0", ($s->[7] & 3)) if $s->[7] & 3;
    return ($h, $pad);
}

# append a config snippet to initrd that instructs linuxrc to use
# download.opensuse.org
# https://bugzilla.opensuse.org/show_bug.cgi?id=916175
sub updateInitRDNET {
    my ($this, $repoloc) = @_;

    $this -> logMsg("I", "prepare initrd for NET iso");

    my $zipper = KIWIGlobals -> instance() -> getKiwiConfig() -> {IrdZipperCommand};

    # FIXME: looks like IrdZipperCommand is not configured correctly
    # in openSUSE product files to match installation-images so
    # hardcode for now
    $zipper = "xz --check=crc32";

    my $linuxrc = "defaultrepo=$repoloc\n";

    my ($cpio, $pad) = _makecpiohead('./etc/linuxrc.d/10_repo', [0, 0, oct(644), 1, 0, 0, 0, length($linuxrc), 0, 0, 0]);
    $cpio .= $linuxrc;
    $cpio .= $pad if $pad;
    $cpio .= _makecpiohead();

    my @initrdfiles;
    find(
        sub { find_cb($this, '.*/initrd$', \@initrdfiles) },
        $this->handler()->collect()->basedir()
    );

    $this -> logMsg("E", "no initrds found!") unless @initrdfiles;

    for my $initrd (@initrdfiles) {
        $this -> logMsg("I", "updating $initrd with $repoloc");
        my $fh  = FileHandle -> new();
        if (! $fh -> open("|$zipper -c >> $initrd")) {
        #if (! $fh -> open(">$initrd.append")) {
            croak "Cant launch $zipper for $initrd: $!";
        }
        print $fh $cpio;
        $fh -> close();
    }
    return;
}

sub find_cb {
    my $this = shift;
    return if not ref($this);

    my $pat = shift;
    my $listref = shift;
    if(not defined($listref) or not defined($pat)) {
        return;
    }
    if($File::Find::name =~ m{$pat}x) {
        push @{$listref}, $File::Find::name;
    }
    return $this;
}

1;
