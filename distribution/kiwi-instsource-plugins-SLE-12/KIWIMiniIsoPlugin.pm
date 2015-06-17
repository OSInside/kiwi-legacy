################################################################
# Copyright (c) 2014 SUSE
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
    my @gfxbootfiles;
    find(
        sub { find_cb($this, '.*/gfxboot\.cfg$', \@gfxbootfiles) },
        $this->handler()->collect()->basedir()
    );
    my @rootfiles;
    find(
        sub { find_cb($this, '.*/root$', \@rootfiles) },
        $this->handler()->collect()->basedir()
    );
    foreach(@rootfiles) {
        $this->logMsg("I", "removing file <$_>");
        unlink $_;
    }
    if (!@gfxbootfiles) {
        my $msg = "No gfxboot.cfg file found! "
            . "This _MIGHT_ be ok for S/390. "
            . "Please verify <installation-images> package(s)";
        $this->logMsg("W", $msg);
        return $retval;
    }
    $this -> updateEFIGrubConfig($repoloc);
    $retval = $this -> updateGraphicsBootConfig (
        \@gfxbootfiles, $repoloc, $srv, $path
    );
    return $retval;
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

sub updateEFIGrubConfig {
    my $this = shift;
    my $repoloc = shift;
    my $grubcfg = $this->collect()
        ->basesubdirs()->{1} . "/EFI/BOOT/grub.cfg";
    if (! -f $grubcfg ) {
        $this->logMsg("I", "no grub.cfg at <$grubcfg>");
        return;
    }
    $this->logMsg("I", "editing <$grubcfg>");
    my $IN  = FileHandle -> new();
    my $OUT = FileHandle -> new();
    if (! $IN -> open($grubcfg)) {
        croak "Cant open file for reading $grubcfg: $!";
    }
    if (! $OUT -> open(">$grubcfg.new")) {
        croak "Cant open file for writing $grubcfg.new: $!";
    }
    while(<$IN>) {
        my $line = $_;
        chomp $line;
        $this->logMsg("I", "-$line");
        $line =~
            s,(linuxefi /boot/x86_64/loader/linux),$1 install=$repoloc,x;
        $this->logMsg("I", "+$line");
        print $OUT "$line\n";
    }
    $OUT -> close();
    $IN  -> close(); 
    $this -> callCmd("diff -u $grubcfg $grubcfg.new");
    rename("$grubcfg.new", $grubcfg);
    return $this;
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
