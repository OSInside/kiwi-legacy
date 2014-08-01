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
    my $ini = Config::IniFiles -> new( -file => "$configpath/$configfile" );
    my $name       = $ini->val('base', 'name');
    my $order      = $ini->val('base', 'order');
    my $tool       = $ini->val('base', 'tool');
    my $createrepo = $ini->val('base', 'createrepo');
    my $rezip      = $ini->val('base', 'rezip');
    my $tdir       = $ini->val('base', 'tooldir');
    my $tpack      = $ini->val('base', 'toolpack');
    my $enable     = $ini->val('base', 'defaultenable');
    my @params     = $ini->val('options', 'parameter');
    my $gzip       = $ini->val('target', 'compress');
    # if any of those isn't set, complain!
    if(not defined($name)
        or not defined($order)
        or not defined($tool)
        or not defined($createrepo)
        or not defined($rezip)
        or not defined($tdir)
        or not defined($tpack)
        or not defined($enable)
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
    $this->{m_createrepo} = $createrepo;
    $this->{m_rezip} = $rezip;
    $this->{m_params} = $params;
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
    if($this->{m_ready} == 0) {
        return 0
    }
    my $coll = $this->{m_collect};
    my $basesubdirs = $coll->basesubdirs();
    if(not defined($basesubdirs)) {
        ## prevent crash when dereferencing
        $this->logMsg("E",
            "<basesubdirs> is undefined! Skipping <$this->name()>"
        );
        return 0;
    }
    foreach my $dirlist($this->getSubdirLists()) {
        my ($s,$m) = $this->executeDir(sort @{$dirlist});
    }
    return 0;
}

sub executeDir {
    my @params = @_;
    my $this     = shift @params;
    my @paths    = @params;
    my $call;
    my $status;
    my $cmd;
    if(!@paths) {
        $this->logMsg("W", "Empty path list!");
        return 0;
    }
    my $coll  = $this->{m_collect};
    my $datadir  = $coll->productData()->getInfo("DATADIR");
    my $descrdir = $coll->productData()->getInfo("DESCRDIR");
    my $cpeid = $coll->productData()->getInfo("CPEID");
    my $repoid = $coll->productData()->getInfo("REPOID");
    my $createrepomd = $coll->productData()->getVar("CREATE_REPOMD");
    my $targetdir;
    my $newtargetdir;
    ## this ugly bit creates a parameter string from a list of directories:
    # param = -d <dir1> -d <dir2> ...
    # the order is important. Idea: use map to make hash <dir> => -d for
    # all subdirs not ending with "0" (those are for metafile unpacking
    # only). The result is evaluated in list context be reverse, so
    # there's a list looking like "<dir_N> -d ... <dir1> -d" which is
    # reversed again, making the result '-d', '<dir1>', ..., '-d', '<dir_N>'",
    # after the join as string.
    # ---
    if ($descrdir && $descrdir ne "/") {
        my $pathlist = "-d ".join(' -d ', map{$_."/".$datadir}(@paths));
        $this->logMsg("I",
            "Calling ".$this->name()." for directories <@paths>:"
        );
        $targetdir = $paths[0]."/".$descrdir;
        $cmd = "$this->{m_tooldir}/$this->{m_tool} "
            . "$pathlist $this->{m_params} -o "
            . $paths[0]
            . "/"
            . $descrdir;
        $this->logMsg("I", "Executing command <$cmd>");
        $call = $this -> callCmd($cmd);
        $status = $call->[0];
        if($status) {
            my $out = join("\n",@{$call->[1]});
            $this->logMsg("E",
                "Called <$cmd> exit status <$status> output: $out"
            );
            return 0;
        }
    }
    if ( $createrepomd && $createrepomd eq "true" ) {
        my $distroname = $coll->productData()->getInfo("DISTRIBUTION")."."
                . $coll->productData()->getInfo("VERSION");
        my $result = $this -> createRepositoryMetadata(
            \@paths, $repoid, $distroname, $cpeid, $datadir, $targetdir
        );
        # return values 0 || 1 indicates an error
        if ($result != 2) {
            return $result;
        }
    }
    return 1 unless $descrdir;
    return 1 unless $targetdir;
    # insert translation files
    my $trans_dir  = '/usr/share/locale/en_US/LC_MESSAGES';
    my $trans_glob = 'package-translations-*.mo';
    foreach my $trans (glob($trans_dir.'/'.$trans_glob)) {
        $trans = basename($trans, ".mo");
        $trans =~ s,.*-,,x;
        $cmd = "/usr/bin/translate_packages.pl $trans "
            . "< $targetdir/packages.en "
            . "> $targetdir/packages.$trans";
        $call = $this -> callCmd($cmd);
        $status = $call->[0];
        if($status) {
            my $out = join("\n",@{$call->[1]});
            $this->logMsg("E",
                "Called <$cmd> exit status: <$status> output: $out"
            );
            return 1;
        }
    }
    # one more time for english to insert possible EULAs
    $cmd = "/usr/bin/translate_packages.pl en "
        . "< $targetdir/packages.en "
        . "> $targetdir/packages.en.new && "
        . "mv $targetdir/packages.en.new $targetdir/packages.en";
    $call = $this -> callCmd($cmd);
    $status = $call->[0];
    if ($status) {
        my $out = join("\n",@{$call->[1]});
        $this->logMsg("E",
            "Called <$cmd> exit status: <$status> output: $out"
        );
        return 1;
    }
    if ((-x "/usr/bin/extract-appdata-icons") &&
        (-s "$targetdir/appdata.xml")
    ) {
        $cmd = "/usr/bin/extract-appdata-icons "
            . "$targetdir/appdata.xml $targetdir";
        $call = $this -> callCmd($cmd);
        $status = $call->[0];
        if($status) {
            my $out = join("\n",@{$call->[1]});
            $this->logMsg("E",
                "Called <$cmd> exit status: <$status> output: $out"
            );
            return 1;
        }
        if($this->{m_compress} =~ m{yes}i) {
            system("gzip", "--rsyncable", "$targetdir/appdata.xml");
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

sub createRepositoryMetadata {
    my @params = @_;
    my $this       = $params[0];
    my $paths      = $params[1];
    my $repoid     = $params[2];
    my $distroname = $params[3];
    my $cpeid      = $params[4];
    my $datadir    = $params[5];
    my $targetdir  = $params[6];
    my $cmd;
    my $call;
    my $status;
    foreach my $p (@{$paths}) {
        $cmd = "$this->{m_createrepo}";
        $cmd .= " --unique-md-filenames";
        $cmd .= " --checksum=sha256";
        $cmd .= " --no-database";
        $cmd .= " --repo=\"$repoid\"" if $repoid;
        $cmd .= " --distro=\"$cpeid,$distroname\"" if $cpeid && $distroname;
        $cmd .= " $p/$datadir";
        $this->logMsg("I", "Executing command <$cmd>");
        $call = $this -> callCmd($cmd);
        $status = $call->[0];
        if($status) {
            my $out = join("\n",@{$call->[1]});
            $this->logMsg("E",
                "Called <$cmd> exit status: <$status> output: $out"
            );
            return 0;
        }
        $cmd = "$this->{m_rezip} $p/$datadir ";
        $this->logMsg("I", "Executing command <$cmd>");
        $call = $this -> callCmd($cmd);
        $status = $call->[0];
        if($status) {
            my $out = join("\n",@{$call->[1]});
            $this->logMsg("E",
                "Called <$cmd> exit status: <$status> output: $out"
            );
            return 0;
        }
        my $newtargetdir = "$p/$datadir/repodata";
        if ((-x "/usr/bin/extract-appdata-icons") && 
            (-s "$newtargetdir/appdata.xml")
        ) {
            $cmd = "/usr/bin/extract-appdata-icons "
                . "$newtargetdir/appdata.xml $newtargetdir";
            $call = $this -> callCmd($cmd);
            $status = $call->[0];
            if($status) {
                my $out = join("\n",@{$call->[1]});
                $this->logMsg("E",
                    "Called $cmd exit status: <$status> output: $out"
                );
                return 1;
            }
            if($this->{m_compress} =~ m{yes}i) {
                system("gzip", "--rsyncable", "$newtargetdir/appdata.xml");
            }
        }
        if ((-x "/usr/bin/extract-appdata-icons") &&
            (-s "$targetdir/appdata.xml")
        ) {
            $newtargetdir = "$p/$datadir/repodata";
            system("cp $targetdir/appdata.xml $newtargetdir/appdata.xml");
            $cmd = "/usr/bin/extract-appdata-icons "
                . "$newtargetdir/appdata.xml $newtargetdir";
            $call = $this -> callCmd($cmd);
            $status = $call->[0];
            if($status) {
                my $out = join("\n",@{$call->[1]});
                $this->logMsg("E",
                    "Called $cmd exit status: <$status> output: $out"
                );
                return 1;
            }
            if($this->{m_compress} =~ m{yes}i) {
                system("gzip", "--rsyncable", "$newtargetdir/appdata.xml");
            }
        }
        if ( -f "/usr/bin/add_product_susedata" ) {
            my $kwdfile = abs_path(
                $this->collect()->{m_xml}->{xmlOrigFile}
            );
            $kwdfile =~ s/.kiwi$/.kwd/x;
            $cmd = "/usr/bin/add_product_susedata";
            $cmd .= " -u"; # unique filenames
            $cmd .= " -k $kwdfile";
            $cmd .= " -e /usr/share/doc/packages/eulas";
            $cmd .= " -d $p/$datadir";
            $this->logMsg("I", "Executing command <$cmd>");
            $call = $this -> callCmd($cmd);
            $status = $call->[0];
            if($status) {
                my $out = join("\n",@{$call->[1]});
                $this->logMsg("E",
                    "Called <$cmd> exit status: <$status> output: $out"
                );
                return 0;
            }
        }
    }
    return 2;
}

1;
