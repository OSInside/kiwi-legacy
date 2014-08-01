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
package KIWIDescrPlugin;

use strict;
use warnings;

use File::Basename;
use base "KIWIBasePlugin";
use Config::IniFiles;
use Data::Dumper;
use Cwd 'abs_path';

sub new {
    # ...
    # Create a new KIWIDescrPlugin object
    # creates patterns file
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
    if((! $configpath) || (! $configfile)) {
        $this->logMsg("E",
            "wrong parameters in plugin initialisation"
        );
        return;
    }
    my $ini = Config::IniFiles -> new(
        -file => "$configpath/$configfile"
    );
    my $name       = $ini->val('base'   , 'name');
    my $order      = $ini->val('base'   , 'order');
    my $tool       = $ini->val('base'   , 'tool');
    my $createrepo = $ini->val('base'   , 'createrepo');
    my $rezip      = $ini->val('base'   , 'rezip');
    my $tdir       = $ini->val('base'   , 'tooldir');
    my $tpack      = $ini->val('base'   , 'toolpack');
    my $enable     = $ini->val('base'   , 'defaultenable');
    my $pdbfiles   = $ini->val('options', 'pdbfiles');
    my @params     = $ini->val('options', 'parameter');
    my @langs      = $ini->val('options', 'language');
    my $gzip       = $ini->val('target' , 'compress');
    # if any of those isn't set, complain!
    if(not defined($name)
        or not defined($order)
        or not defined($tool)
        or not defined($createrepo)
        or not defined($rezip)
        or not defined($tdir)
        or not defined($tpack)
        or not defined($enable)
        or not defined($pdbfiles)
        or not defined($gzip)
        or not (@params)
    ) {
        $this->logMsg("E",
            "Plugin ini file <$config> seems broken!"
        );
        return;
    }
    # sanity check for tools' existence:
    if(not( -f "$tdir/$tool" and -x "$tdir/$tool")) {
        $this->logMsg("E",
            "Plugin <$name>: tool <$tdir/$tool> is not executable!"
        );
        $this->logMsg("I",
            "Check if package <$tpack> is installed."
        );
        return;
    }
    my $params = "";
    foreach my $p(@params) {
        $p = $this->collect()->productData()->_substitute("$p");
        $params .= "$p ";
    }
    # add local kwd files as argument
    my $extrafile = abs_path($this->collect()->{m_xml}->{xmlOrigFile});
    $extrafile =~ s/.kiwi$/.kwd/x;
    if (-f $extrafile) {
        $this->logMsg("W", "Found extra tags file $extrafile.");
        $params .= "-T $extrafile ";
    }
    $this->name($name);
    $this->order($order);
    $this->{m_tool} = $tool;
    $this->{m_tooldir} = $tdir;
    $this->{m_toolpack} = $tpack;
    $this->{m_pdbfiles} = $pdbfiles;
    $this->{m_createrepo} = $createrepo;
    $this->{m_rezip} = $rezip;
    $this->{m_params} = $params;
    $this->{m_languages} = join(' ', @langs);
    $this->{m_compress} = $gzip;
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
    # sanity check:
    if($this->{m_ready} == 0) {
        return $retval;
    }
    my $coll = $this->{m_collect};
    my $basesubdirs = $coll->basesubdirs();
    if(not defined($basesubdirs)) {
        ## prevent crash when dereferencing
        $this->logMsg("E",
            "<basesubdirs> is undefined! Skipping <$this->name()>"
        );
        return $retval;
    }
    foreach my $dirlist($this->getSubdirLists()) {
        my ($s,$m) = $this->executeDir(sort @{$dirlist});
    }
    return $retval;
}

sub executeDir {
    my @params = @_;
    my $this   = shift @params;
    my @paths  = @params;
    my $retval = 0;
    my $status;
    my $call;
    if(!@paths) {
        $this->logMsg("W", "Empty path list!");
        return $retval;
    }
    my $coll  = $this->{m_collect};
    my $datadir  = $coll->productData()->getInfo("DATADIR");
    my $descrdir = $coll->productData()->getInfo("DESCRDIR");
    my $createrepomd = $coll->productData()->getVar("CREATE_REPOMD");
    my $targetdir = $paths[0]."/".$descrdir;
    ## this bits creates a parameter string from a list of directories:
    # param = -d <dir1> -d <dir2> ...
    # the order is important. Idea: use map to make hash <dir> => -d
    # for all subdirs not ending with "0" (those are for metafile
    # unpacking only). The result is evaluated in list context be reverse,
    # so there's a list looking like "<dir_N> -d ... <dir1> -d" which is
    # reversed again, making the result '-d', '<dir1>', ..., '-d', '<dir_N>'",
    # after the join as string.
    # ----
    my $pathlist = "-d ".join(' -d ', map{$_."/".$datadir}(@paths));
    $this->logMsg("I",
        "Calling ".$this->name()." for directories <@paths>:"
    );
    my $cmd = "$this->{m_tooldir}/$this->{m_tool} "
        . "$this->{m_pdbfiles} $pathlist $this->{m_params} "
        . "$this->{m_languages} -o "
        . $paths[0]
        . "/".$descrdir;
    $this->logMsg("I", "Executing command <$cmd>");
    $call = $this -> callCmd($cmd);
    $status = $call->[0];
    if($status) {
        my $out = join("\n",@{$call->[1]});
        $this->logMsg("E",
            "Called <$cmd> exit status: <$status> output: $out"
        );
        return $retval;
    }
    if ( $createrepomd eq "true" ) {
        foreach my $p (@paths) {
            my $cmd_repo = "$this->{m_createrepo} $p/$datadir ";
            $this->logMsg("I", "Executing command <$cmd_repo>");
            $call = $this -> callCmd($cmd_repo);
            $status = $call->[0];
            if ($status) {
                my $out = join("\n",@{$call->[1]});
                $this->logMsg("E",
                    "Called <$cmd_repo> exit status: <$status> output: $out"
                );
                return $retval;
            }
            my $cmd_zipp = "$this->{m_rezip} $p/$datadir ";
            $this->logMsg("I", "Executing command <$cmd_zipp>");
            $call = $this -> callCmd($cmd_zipp);
            $status = $call->[0];
            if($status) {
                my $out = join("\n",@{$call->[1]});
                $this->logMsg("E",
                    "Called <$cmd_zipp> exit status: <$status> output: $out"
                );
                return $retval;
            }
        }
    }
    if($this->{m_compress} =~ m{yes}i) {
        foreach my $pfile(glob("$targetdir/packages*")) {
            if(system("gzip", "--rsyncable", "$pfile") == 0) {
                unlink "$targetdir/$pfile";
            } else {
                $this->logMsg("W",
                    "Can't compress file <$targetdir/$pfile>!"
                );
            }
        }
    }
    return 1;
}

1;
