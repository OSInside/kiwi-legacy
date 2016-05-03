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
package KIWILiveTreePlugin;

use strict;
use warnings;

use base "KIWIBasePlugin";
use Data::Dumper;
use Config::IniFiles;
use File::Find;
use File::Basename;
use Carp;

sub new {
    # ...
    # Create a new KIWILiveTreePlugin object
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
    if(not defined($configpath) or not defined($configfile)) {
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
    my $ini = Config::IniFiles -> new(
        -file => "$configpath/$configfile"
    );
    my $name   = $ini->val('base', 'name');
    my $order  = $ini->val('base', 'order');
    my $enable = $ini->val('base', 'defaultenable');
    # if any of those isn't set, complain!
    if(not defined($name)
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
    if($this->{m_ready} == 0) {
        return 0;
    }
    my $ismini = $this->collect()
        ->productData()->getVar("FLAVOR");
    if(not defined($ismini)) {
        $this->logMsg("W", "FLAVOR not set?");
        return 0;
    }
    if($ismini !~ m{livetree}i) {
        return 0;
    }
    my $medium = $this->collect()
        ->productData()->getVar("MEDIUM_NAME");
    my $cd;
    find(
        sub { if (m/.iso/x) { $cd = $File::Find::name; } },
        $this->handler()->collect()->basedir()
    );
    if (!$cd) {
        $this->logMsg("E", "Initial CD not found\n");
        croak "E: fatal";
    }
    $this->logMsg("I", "$cd $medium");
    my $dname = dirname($cd);
    $this->logMsg("I", "$dname");
    my $nname = "$medium.iso";
    $nname =~ s,-i586-,-i686-,x;
    $this->logMsg("I",
        "Renaming $cd to $dname/$nname"
    );
    if (! rename($cd, "$dname/$nname")) {
        $this->logMsg("E", "could not rename $cd");
        croak "E: fatal";
    }
    return 0;
}

1;
