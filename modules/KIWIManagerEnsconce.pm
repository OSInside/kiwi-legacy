#================
# FILE          : KIWIManagerEnsconce.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module adds support for the suse studio
#               : ensconce package manager
#               :
# STATUS        : Development
#----------------
package KIWIManagerEnsconce;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use base qw /Exporter/;
use Carp qw (cluck);
use Env;
use FileHandle;
use File::Basename;
use Config::IniFiles;
use KIWILog;
use KIWILocator;
use KIWIQX;

#==========================================
# Base class
#------------------------------------------
use base qw /KIWIManager/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
    #==========================================
    # Object setup
    #------------------------------------------
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    #==========================================
    # Retrieve data from base class
    #------------------------------------------
    my $dataDir = $this->{dataDir};
    my $locator = $this->{locator};
    my $root    = $this->{root};
    #==========================================
    # Create config files/dirs
    #------------------------------------------
    if (! -d $dataDir) {
        KIWIQX::qxx ("mkdir -p $dataDir");
    }
    #==========================================
    # Store ensconce command parameters
    #------------------------------------------
    $this->{ensconce} = [
        $locator -> getExecPath('ensconce'),
        "-r $root"
    ];
    $this->{ensconce_chroot} = [
        "ensconce",
        "-r $root"
    ];
    return $this;
}

#==========================================
# setupSignatureCheck
#------------------------------------------
sub setupSignatureCheck {
    # ...
    # Check if the image description contains the signature
    # check option or not. If yes activate or deactivate it
    # according to the used package manager
    # ---
    my $this = shift;
    return $this;
}

#==========================================
# resetSignatureCheck
#------------------------------------------
sub resetSignatureCheck {
    # ...
    # reset the signature check option to the previos
    # value of the package manager
    # ---
    my $this   = shift;
    return $this;
}

#==========================================
# setupExcludeDocs
#------------------------------------------
sub setupExcludeDocs {
    # ...
    # Check if the image description contains the exclude
    # docs option or not. If yes activate or deactivate it
    # according to the used package manager
    # ---
    my $this = shift;
    return $this;
}

#==========================================
# resetExcludeDocs
#------------------------------------------
sub resetExcludeDocs {
    # ...
    # reset the signature check option to the previos
    # value of the package manager
    # ---
    my $this   = shift;
    return $this;
}

#==========================================
# setupInstallationSource
#------------------------------------------
sub setupInstallationSource {
    # ...
    # setup an installation source to retrieve packages
    # from. multiple sources are allowed
    # ---
    my $this   = shift;
    return $this;
}

#==========================================
# resetInstallationSource
#------------------------------------------
sub resetInstallationSource {
    # ...
    # clean the installation source environment
    # which means remove temporary inst-sources
    # ---
    my $this   = shift;
    return $this;
}

#==========================================
# setupDownload
#------------------------------------------
sub setupDownload {
    # ...
    # download package files for later handling
    # using the package manager download functionality
    # ---
    my @pacs   = @_;
    my $this   = shift @pacs;
    my $kiwi   = $this->{kiwi};
    # FIXME
    $kiwi -> failed ();
    $kiwi -> error  ("*** not implemeted ***");
    $kiwi -> failed ();
    return;
}

#==========================================
# installPackages
#------------------------------------------
sub installPackages {
    # ...
    # install packages in the previosly installed root
    # system using the package manager install method
    # ---
    my $this       = shift;
    my $instPacks  = shift;
    my $kiwi       = $this->{kiwi};
    # FIXME
    $kiwi -> failed ();
    $kiwi -> error  ("*** not implemeted ***");
    $kiwi -> failed ();
    return;
}

#==========================================
# removePackages
#------------------------------------------
sub removePackages {
    # ...
    # remove packages from the previosly installed root
    # system using the package manager remove method
    # ---
    my $this       = shift;
    my $removePacks= shift;
    my $kiwi       = $this->{kiwi};
    my $root       = $this->{root};
    my @kchroot    = @{$this->{kchroot}};
    my $screenCall = $this->{screenCall};
    #==========================================
    # check to be removed packages
    #------------------------------------------
    if (! defined $removePacks) {
        return $this;
    }
    #==========================================
    # setup screen call
    #------------------------------------------
    my @removePackages = @{$removePacks};
    if (! @removePackages) {
        return $this;
    }
    my $fd = $this -> setupScreen();
    if (! defined $fd) {
        return;
    }
    #==========================================
    # Create screen call file
    #------------------------------------------
    $kiwi -> info ("Removing packages...");
    if (! $this -> rpmLibs()) {
        return;
    }
    my @removeOpts = (
        "--nodeps --allmatches --noscripts"
    );
    print $fd "export LANG=C"."\n";
    print $fd "export LC_ALL=C"."\n";
    print $fd "function clean { kill \$SPID;";
    print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
    print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
    print $fd "c=\$((\$c+1));done;\n";
    print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
    print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
    print $fd "trap clean INT TERM\n";
    print $fd "@kchroot mount -t proc proc /proc"."\n";
    print $fd "final=\$(@kchroot rpm -q @removePackages ";
    print $fd " | grep -v 'is not installed')"."\n";
    print $fd "if [ ! -z \"\$final\" ];then"."\n";
    print $fd "@kchroot rpm -e @removeOpts \$final &\n";
    print $fd "SPID=\$!;wait \$SPID\n";
    print $fd "ECODE=\$?\n";
    print $fd "else"."\n";
    print $fd "ECODE=0"."\n";
    print $fd "fi"."\n";
    print $fd "echo \$ECODE > $screenCall.exit\n";
    print $fd "@kchroot umount /proc"."\n";
    #print $fd "@kchroot /bin/bash\n";
    print $fd "exit \$ECODE\n";
    $fd -> close();
    return $this -> setupScreenCall();
}

#==========================================
# setupUpgrade
#------------------------------------------
sub setupUpgrade {
    # ...
    # Ignored for ensconce, always report success
    # ---
    my $this       = shift;
    my $addPacks   = shift;
    my $delPacks   = shift;
    my $noUpgrade  = shift;
    my $screenCall = $this->{screenCall};
    #==========================================
    # setup screen call
    #------------------------------------------
    my $fd = $this -> setupScreen();
    if (! defined $fd) {
        return;
    }
    print $fd "echo 0 > $screenCall.exit; exit 0\n";
    $fd -> close();
    return $this;
}

#==========================================
# setupRootSystem
#------------------------------------------
sub setupRootSystem {
    # ...
    # install the bootstrap system to be able to
    # chroot into this minimal image
    # ---
    my @packs       = @_;
    my $this        = shift @packs;
    my $kiwi        = $this->{kiwi};
    my $chroot      = $this->{chroot};
    my @kchroot     = @{$this->{kchroot}};
    my $root        = $this->{root};
    my $xml         = $this->{xml};
    my $manager     = $this->{manager};
    my @channelList = @{$this->{channelList}};
    my $screenCall  = $this->{screenCall};
    my %source      = %{$this->{source}};
    #==========================================
    # search for licenses on media
    #------------------------------------------
    if (! $chroot) {
        $this -> provideMediaLicense();
    }
    #==========================================
    # setup screen call
    #------------------------------------------
    my $fd = $this -> setupScreen();
    if (! defined $fd) {
        return;
    }
    my @ensconce = @{$this->{ensconce}};
    my $imagename = $xml -> getImageName();
    my $ensconce_args = "-i $imagename";
    if (! $chroot) {
        #==========================================
        # Ensconce options
        #------------------------------------------
        $ensconce_args .= " -b";
    }
    if (! $chroot) {
        $kiwi -> info ("Initializing image system on: $root");
    } else {
        $kiwi -> info ("Installing image packages...");
    }
    print $fd "function clean { kill \$SPID; ";
    print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
    print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
    print $fd "c=\$((\$c+1));done;\n";
    print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
    print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
    print $fd "trap clean INT TERM\n";
    print $fd "@ensconce $ensconce_args &\n";
    print $fd "SPID=\$!;wait \$SPID\n";
    print $fd "ECODE=\$?\n";
    print $fd "echo \$ECODE > $screenCall.exit\n";
    print $fd "exit \$ECODE\n";
    $fd -> close();
    #==========================================
    # run process
    #------------------------------------------
    if (! $this -> setupScreenCall()) {
        return;
    }
    #==========================================
    # setup baselibs
    #------------------------------------------
    if (! $chroot) {
        if (! $this -> rpmLibs()) {
            return;
        }
    }
    return $this;
}

#==========================================
# resetSource
#------------------------------------------
sub resetSource {
    # ...
    # cleanup source data. In case of any interrupt
    # which means remove all changes made by %source
    # ---
    my $this = shift;
    return $this;
}

#==========================================
# setupPackageInfo
#------------------------------------------
sub setupPackageInfo {
    # ...
    # check if a given package is installed or not.
    # return the exit code from the call
    # ---
    my $this  = shift;
    my $pack  = shift;
    # Ignored for ensconce, always report package as installed
    return 0;
}

1;
