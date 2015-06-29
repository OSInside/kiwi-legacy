#================
# FILE          : KIWIXMLValidator.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to upgrade and validate the
#               : XML file, describing the image to be created
#               :
# STATUS        : Development
#----------------
package KIWIXMLValidator;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use XML::LibXML;
use Scalar::Util 'refaddr';

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILog;
use KIWIQX;

#==========================================
# Exports
#------------------------------------------
our @ISA       = qw (Exporter);
our @EXPORT_OK = qw (getDOM validate);

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create the validator object.
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Module Parameters
    #------------------------------------------
    my $configPath = shift;
    my $revRecPath = shift;
    my $schemaPath = shift;
    my $xsltPath   = shift;
    #==========================================
    # Check pre-conditions
    #------------------------------------------
    my $kiwi = KIWILog -> instance();
    if ((! $configPath) || (! -f $configPath)) {
        if (! $configPath) {
            $configPath = "undefined";
        }
        $kiwi -> error ("Could not find specified configuration: $configPath");
        $kiwi -> failed ();
        return;
    }
    if (! -f $revRecPath) {
        $kiwi -> error ("Could not find specified revision file: $revRecPath");
        $kiwi -> failed ();
        return;
    }
    if (! -f $schemaPath) {
        $kiwi -> error ("Could not find specified schema: $schemaPath");
        $kiwi -> failed ();
        return;
    }
    if (! -f $xsltPath) {
        $kiwi -> error ("Could not find specified transformation: $xsltPath");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{config}   = $configPath;
    $this->{kiwi}     = $kiwi;
    $this->{revision} = $revRecPath;
    $this->{schema}   = $schemaPath;
    $this->{xslt}     = $xsltPath;
    #=========================================
    # Load the configuration, automatically upgrade if necessary
    #----------------------------------------
    my $XML = $this -> __loadControlfile ();
    if (! $XML) {
        return;
    }
    #=========================================
    # Generate the DOM
    #-----------------------------------------
    my $systemTree = $this -> __getXMLDocTree ( $XML );
    if (! $systemTree) {
        return;
    }
    $this->{systemTree} = $systemTree;
    return $this;
}

#=========================================
# getDOM
#-----------------------------------------
sub getDOM {
    # ...
    # Return the DOM for the configuration file.
    # ---
    my $this = shift;
    return $this->{systemTree};
}

#=========================================
# validate
#-----------------------------------------
sub validate {
    # ...
    # Validate the XML for syntactic correctness and consistency
    # ---
    my $this = shift;
    if (defined $this->{isValid}) {
        return $this;
    }
    #==========================================
    # validate XML document with the schema
    #------------------------------------------
    if (! $this -> __validateXML ()) {
        return;
    }
    #==========================================
    # Check data consistentcy
    #==========================================
    if (! $this -> __validateConsistency ()) {
        return;
    }
    $this->{isValid} = 1;
    return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __checkArchiveUnique
#------------------------------------------
sub __checkArchiveUnique {
    # ...
    # Check that a specified archive is unique, i.e. specified only
    # once per architecture per <packages> section
    # ---
    my $this = shift;
    my $uniqueCheck = $this -> __uniqueInPackages('archive');
    if ($uniqueCheck) {
        my $kiwi = $this -> {kiwi};
        my ($name, $arch) = split /,/, $uniqueCheck;
        if ($arch) {
            my $msg = "Archive '$name' specified multiple "
                . "times for architecture '$arch' in same "
                . '<packages> section.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        } else {
            my $msg = "Archive '$name' specified multiple times in "
                . 'same <packages> section.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkBootSpecPresent
#------------------------------------------
sub __checkBootSpecPresent {
    # ...
    # Check that the boot attribute is set for types that require an
    # initrd.
    # ---
    my $this        = shift;
    my $systemTree  = $this->{systemTree};
    my %needsInitrd = map { ($_ => 1) } qw (
        iso
        oem
        pxe
        split
        vmx
    );
    my @types = $systemTree -> getElementsByTagName('type');
    for my $type (@types) {
        my $image = $type -> getAttribute('image');
        if ($needsInitrd{$image}) {
            my $boot = $type -> getAttribute('boot');
            if (! $boot) {
                my $kiwi = $this -> {kiwi};
                my $msg = "$image requires initrd, but no 'boot' "
                    . 'attribute specified.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkContainerSpec
#------------------------------------------
sub __checkContainerSpec {
    # ...
    # Check that the container attribute is set and has a valid name
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my $systemTree  = $this->{systemTree};
    my @types = $systemTree -> getElementsByTagName('type');
    for my $type (@types) {
        my $image = $type -> getAttribute('image');
        if ($image eq 'lxc') {
            my $contName = $type -> getAttribute('container');
            if (! $contName) {
                my $msg = 'Must specify attribute "container" for "lxc" '
                    . 'image type.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
            if ($contName =~ /\W/smx) {
                my $msg = 'Container name contains non word character.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkDefaultProfSetting
#------------------------------------------
sub __checkDefaultProfSetting {
    # ...
    # Make sure only one profile is marked as default.
    # ---
    my $this        = shift;
    my $numDefProfs = 0;
    my $systemTree  = $this->{systemTree};
    my @profiles    = $systemTree -> getElementsByTagName('profile');
    for my $profile (@profiles) {
        my $import = $profile -> getAttribute('import');
        if (defined $import && $import eq 'true') {
            $numDefProfs++;
        }
        if ($numDefProfs > 1) {
            my $kiwi = $this->{kiwi};
            my $msg = 'Only one profile may be set as the default profile by '
            . 'using the "import" attribute.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkDeletePackNoPatNoTar
#------------------------------------------
sub __checkDeletePackNoPatNoTar {
    # ...
    # A <packages type="delete"> section may not specify patterns or archives.
    # We do not support deletion of archives and the underlying package
    # management systems do not support the deletion of patterns.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my @pkgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
    my $errMsg = 'Inconsistent data: specified INV_TYPE for '
        . 'deletion. This is not supported.';
    for my $pkgs (@pkgsNodes) {
        my $type = $pkgs -> getAttribute('type');
        if ($type eq 'delete') {
            my $archives = $pkgs -> getElementsByTagName('archive');
            if ($archives) {
                $errMsg =~ s/INV_TYPE/archive/x;
                $kiwi -> error($errMsg);
                $kiwi -> failed();
                return;
            }
            my $collect = $pkgs -> getElementsByTagName('namedCollection');
            if ($collect) {
                $errMsg =~ s/INV_TYPE/pattern/x;
                $kiwi -> error($errMsg);
                $kiwi -> failed();
                return;
            }
            my $prod = $pkgs -> getElementsByTagName('product');
            if ($prod) {
                $errMsg =~ s/INV_TYPE/product/x;
                $kiwi -> error($errMsg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkDefaultTypeSetting
#------------------------------------------
sub __checkDefaultTypeSetting {
    # ...
    # Check that only one type is marked as primary per profile
    # ---
    my $this        = shift;
    my $systemTree  = $this->{systemTree};
    my @preferences = $systemTree -> getElementsByTagName('preferences');
    for my $pref (@preferences) {
        my $hasPrimary = 0;
        my @types = $pref -> getChildrenByTagName('type');
        for my $typeN (@types) {
            my $primary = $typeN -> getAttribute('primary');
            if (defined $primary && $primary eq 'true') {
                $hasPrimary++;
            }
            if ($hasPrimary > 1) {
                my $kiwi = $this->{kiwi};
                my $msg = 'Only one primary type may be specified per '
                        . 'preferences section.';
                $kiwi -> error ($msg);
                $kiwi -> failed ();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkDisplaynameValid
#------------------------------------------
sub __checkDisplaynameValid {
    # ...
    # The displayname attribute of the image may not contain spaces
    # ---
    my $this = shift;
    my @imgNodes = $this->{systemTree} -> getElementsByTagName('image');
    # There is only one image node, it is the root node
    my $displayName = $imgNodes[0] -> getAttribute('displayname');
    if ($displayName) {
        my @words = split /\s/, $displayName;
        my $count = @words;
        if ($count > 1) {
            my $kiwi = $this->{kiwi};
            my $msg = 'Found white space in string provided as displayname. '
            . 'No white space permitted';
            $kiwi -> error ( $msg );
            $kiwi -> failed ();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkIsFormatEC2
#------------------------------------------
sub __checkIsFormatEC2 {
    # ...
    # We changed the EC2 build in an incompatible way we need to allert
    # users if they still have the old setup.
    # ---
    my $this = shift;
    my @typeNodes = $this->{systemTree}->getElementsByTagName('type');
    for my $type (@typeNodes) {
        my $format = $type -> getAttribute('format');
        if ($format && $format eq 'ec2') {
            my $msg = 'The EC2 image creation definition has changed in an '
                . 'incompatible way. Please refer to the ec2Flavour profile '
                . 'used in the JeOS templates provided by the kiwi-templates '
                . 'package to understand the new <type> definition for EC2 '
                . 'image creation';
            my $kiwi = $this->{kiwi};
            $kiwi -> error ( $msg );
            $kiwi -> failed ();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkFilesysSpec
#------------------------------------------
sub __checkFilesysSpec {
    # ...
    # It is necessary to specify the filesystem attribute for certain
    # image types. Make sure the attribute is specified when required.
    # ---
    my $this = shift;
    my $isInvalid;
    my $kiwi = $this->{kiwi};
    my @typeNodes = $this->{systemTree} -> getElementsByTagName('type');
    my @typesReqFS = qw /oem pxe vmx/;
    for my $typeN (@typeNodes) {
        my $imgType = $typeN -> getAttribute( 'image' );
        if (grep { /$imgType/x } @typesReqFS) {
            my $hasFSattr = $typeN -> getAttribute( 'filesystem' );
            if (! $hasFSattr) {
                my $msg = 'filesystem attribute must be set for image="'
                . $imgType
                . '"';
                $kiwi -> error ( $msg );
                $kiwi -> failed ();
                $isInvalid = 1;
            }
        }
    }
    if ($isInvalid) {
        return;
    }
    return 1;
}

#==========================================
# __checkGroupSettingsConsistent
#------------------------------------------
sub __checkGroupSettingsConsistent {
    # ...
    # Check that the group seetings are consistent across all <users> elements
    # A group may only be specified with one ID and ID may not be used
    # twice
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my @grpNodes = $this->{systemTree} -> getElementsByTagName('users');
    my %groupIDMap;
    my $errMsg;
    for my $grp (@grpNodes) {
        my $gname = $grp -> getAttribute('group');
        my $gid   = $grp -> getAttribute('id');
        if ($gid) {
            if ($groupIDMap{$gname} && ($groupIDMap{$gname} ne $gid)) {
                $errMsg = "Group '$gname' specified with different ids, "
                    . 'cannot resolve ambiguity.';
            }
            if ($groupIDMap{$gid} && ($groupIDMap{$gid} ne $gname)) {
                $errMsg = "Group ID '$gid' specified twice, cannot resolve "
                    . 'ambiguity.';
            }
            if ($errMsg) {
                $kiwi -> error($errMsg);
                $kiwi -> failed();
                return;
            }
            $groupIDMap{$gname} = $gid;
            $groupIDMap{$gid} = $gname;
        }
    }
    return 1;
}

#==========================================
# __checkHttpsCredentialsConsistent
#------------------------------------------
sub __checkHttpsCredentialsConsistent {
    # ...
    # username and password attributes for all repositories configured
    # as https: must have the same value. Any repository that has a
    # username attribute must also have a password attribute.
    # ---
    my $this = shift;
    my $kiwi = $this -> {kiwi};
    my @repoNodes = $this->{systemTree} -> getElementsByTagName('repository');
    my $uname;
    my $passwd;
    my $numRep = @repoNodes;
    for my $repoNode (@repoNodes) {
        my $user = $repoNode -> getAttribute('username');
        my $pass = $repoNode -> getAttribute('password');
        if (! $user && $pass) {
            my $msg = 'Specified password without username on repository';
            $kiwi -> error ($msg);
            $kiwi -> failed();
            return;
        }
        if ($user && (! $pass)) {
            my $msg = 'Specified username without password on repository';
            $kiwi -> error ($msg);
            $kiwi -> failed();
            return;
        }
        if ($user && $pass) {
            my @sources = $repoNode -> getElementsByTagName ('source');
            my $path = $sources[0] -> getAttribute('path');
            if ($path !~ /^https:/) {
                next;
            }
            if (! $uname) {
                $uname = $user;
                $passwd = $pass;
                next;
            }
            if ($user ne $uname) {
                my $msg = "Specified username, $user, for https repository "
                . "does not match previously specified name, $uname. "
                . 'All credentials for https repositories must be equal.';
                $kiwi -> error ($msg);
                $kiwi -> failed();
                return;
            }
            if ($pass ne $passwd) {
                my $msg = "Specified password, $pass, for https repository "
                . "does not match previously specified password, $passwd. "
                . 'All credentials for https repositories must be equal.';
                $kiwi -> error ($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkInstallVerifyAction
#------------------------------------------
sub __checkInstallVerifyAction {
    # ...
    # Check that the install verification settings do not conflict
    # ---
    my $this = shift;
    my @confNodes = $this->{systemTree} -> getElementsByTagName("oemconfig");
    my @instVerifyOpts = qw {
        oem-silent-verify
        oem-skip-verify
    };
    for my $oemconfig (@confNodes) {
        my $haveInstVerify = 0;
        for my $action (@instVerifyOpts) {
            my @actionList = $oemconfig -> getElementsByTagName($action);
            if (@actionList) {
                my $isSet = $actionList[0]->textContent();
                if ($isSet eq "true") {
                    if ($haveInstVerify == 0) {
                        $haveInstVerify = 1;
                        next;
                    }
                    my $kiwi = $this->{kiwi};
                    my $msg = 'Only one verification action may be  defined';
                    $kiwi -> error($msg);
                    $kiwi -> error("Use one of @instVerifyOpts");
                    $kiwi -> failed();
                    return;
                }
            }
        }
    }
    return 1;
}

#==========================================
# __checkNetInterfaceMACUnique
#------------------------------------------
sub __checkNetInterfaceMACUnique {
    # ...
    # Check that the interface name used is unique within one <machine>
    # definition.
    # ---
    my $this = shift;
    my $systemTree = $this->{systemTree};
    my @vmNodes = $systemTree -> getElementsByTagName('machine');
    for my $vmNode (@vmNodes) {
        my @nicNodes = $vmNode -> getElementsByTagName('vmnic');
        my %iFaces;
        for my $nicNode (@nicNodes) {
            my $mac = $nicNode -> getAttribute('mac');
            if ($mac) {
                if ($iFaces{$mac}) {
                    my $kiwi = $this->{kiwi};
                    my $msg = "Interface '$mac' assigned twice.";
                    $kiwi -> error($msg);
                    $kiwi -> failed();
                    return;
                }
                $iFaces{$mac} = 1;
            }
        }
    }
    return 1;
}

#==========================================
# __checkNetInterfaceNameUnique
#------------------------------------------
sub __checkNetInterfaceNameUnique {
    # ...
    # Check that the interface name used is unique within one <machine>
    # definition.
    # ---
    my $this = shift;
    my $systemTree = $this->{systemTree};
    my @vmNodes = $systemTree -> getElementsByTagName('machine');
    for my $vmNode (@vmNodes) {
        my @nicNodes = $vmNode -> getElementsByTagName('vmnic');
        my %iFaces;
        for my $nicNode (@nicNodes) {
            my $iFace = $nicNode -> getAttribute('interface');
            if ($iFaces{$iFace}) {
                my $kiwi = $this->{kiwi};
                my $msg = "Interface '$iFace' assigned twice.";
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
            $iFaces{$iFace} = 1;
        }
    }
    return 1;
}

#==========================================
# __checkNoBootVolume
#------------------------------------------
sub __checkNoBootVolume {
    # ...
    # Check that the boot directory, i.e. /boot is not specified as
    # a logical volume.
    # ---
    my $this = shift;
    my $systemTree  = $this->{systemTree};
    my @lvmNodes = $systemTree -> getElementsByTagName('systemdisk');
    for my $lvmSetup (@lvmNodes) {
        my @volumes = $lvmSetup -> getChildrenByTagName('volume');
        for my $vol (@volumes) {
            my $name = $vol -> getAttribute('name');
            if ($name =~ m{^/*boot\z}mx) {
                my $kiwi = $this->{kiwi};
                my $msg = 'Found <systemdisk> setup using "/boot" as '
                    . 'volume. This is not supported.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkNoIDSystemGroups
#------------------------------------------
sub __checkNoIDSystemGroups {
    # ...
    # Check that no group ID is specified if the specieife group name
    # is part of the system groups.
    # ---
    my $this = shift;
    my $systemTree = $this->{systemTree};
    my %sysGrps = map { ($_ => 1) } qw(
        at
        audio
        avahi
        bin
        cdrom
        colord
        console
        daemon
        dialout
        disk
        floppy
        ftp
        games
        gdm
        icecream
        kmem
        kvm
        libvirt
        lightdm
        lock
        lp
        maildrop
        mail
        man
        messagebus
        modem
        mysql
        news
        ntadmin
        ntp
        postfix
        public
        pulse
        pulse-access
        qemu
        root
        rtkit
        scard
        shadow
        smolt
        sshd
        sys
        tape
        tftp
        tomcat
        trusted
        tty
        users
        utmp
        uucp
        video
        wheel
        winbind
        www
        xok
    );
    my @usersNodes = $systemTree -> getElementsByTagName('users');
    for my $uNode (@usersNodes) {
        my $gName = $uNode -> getAttribute('group');
        if ($sysGrps{$gName}) {
            my $id = $uNode -> getAttribute('id');
            if ($id) {
                my $kiwi = $this->{kiwi};
                my $msg = "Assigning ID to system group '$gName' not "
                    . 'allowed.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkOVFTypeSet
#------------------------------------------
sub __checkOVFTypeSet {
    # ...
    # If the format attribute on the <type> is set to ovf the user must
    # specify the ovftype in the <machine> definition
    # ---
    my $this = shift;
    my $systemTree  = $this->{systemTree};
    my @types = $systemTree -> getElementsByTagName('type');
    for my $type (@types) {
        my $format = $type -> getAttribute('format');
        if ($format && $format eq 'ovf') {
            my @vmdef = $type -> getElementsByTagName('machine');
            # there can only be one <machine> section
            my $machineDef = $vmdef[0];
            my $ovfType = $machineDef -> getAttribute('ovftype');
            if (! $ovfType) {
                my $kiwi = $this -> {kiwi};
                my $msg = 'Specified ovf format for the image, but no '
                    . 'ovftype specified on the <machine> definition.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkPackageUnique
#------------------------------------------
sub __checkPackageUnique {
    # ...
    # Check that a specified package is unique, i.e. specified only
    # once per architecture per <packages> section
    # ---
    my $this = shift;
    my $uniqueCheck = $this -> __uniqueInPackages('package');
    if ($uniqueCheck) {
        my $kiwi = $this -> {kiwi};
        my ($name,$arch,$repl) = split /,/, $uniqueCheck;
        if ($arch) {
            my $msg = "Package '$name' specified multiple "
                . "times for architecture '$arch' in same "
                . '<packages> section.';
            $kiwi -> warning ($msg);
            $kiwi -> oops ();
            return 1;
        } else {
            my $msg = "Package '$name' specified multiple times in "
                . 'same <packages> section.';
            $kiwi -> warning ($msg);
            $kiwi -> oops ();
            return 1;
        }
    }
    return 1;
}

#==========================================
# __checkPatternUnique
#------------------------------------------
sub __checkPatternUnique {
    # ...
    # Check that a specified namedCollection is unique,
    # i.e. specified only once per architecture
    # per <packages> section
    # ---
    my $this = shift;
    my $uniqueCheck = $this -> __uniqueInPackages('namedCollection');
    if ($uniqueCheck) {
        my $kiwi = $this -> {kiwi};
        my ($name, $arch) = split /,/, $uniqueCheck;
        if ($arch) {
            my $msg = "Package pattern '$name' specified multiple "
                . "times for architecture '$arch' in same "
                . '<packages> section.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        } else {
            my $msg = "Package pattern '$name' specified multiple times in "
                . 'same <packages> section.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkPatternTypeAttrConsistent
#------------------------------------------
sub __checkPatternTypeAttrConsistent {
    # ...
    # Check that the values for the patternType attribute do not conflict.
    # This means patternTypes set for profiles must be uniq for this
    # profile. This also applies to sections without a profile which
    # are handled as __standard in this check. The getInstallOption
    # function from KIWIXML will use the highest prio patternType
    # according to the selected profiles.
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my @pkgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
    my %result;
    #==========================================
    # build hash profiles -> [ ptype list ]
    #------------------------------------------
    for my $pkgs (@pkgsNodes) {
        my $type = $pkgs -> getAttribute('type');
        if ($type ne 'image') {
            next;
        }
        my $ptype = $pkgs -> getAttribute('patternType');
        if (! $ptype) {
            $ptype = 'onlyRequired';
        }
        my $profile = $pkgs -> getAttribute('profiles');
        my @profile_list = ();
        if (! $profile) {
            push @profile_list, '__standard';
        } else {
            @profile_list = split (/,/,$profile);
        }
        foreach my $profile (@profile_list) {
            if (! $result{$profile}) {
                $result{$profile} = [$ptype];
            } else {
                my @list = @{$result{$profile}};
                push @list,$ptype;
                $result{$profile} = \@list;
            }
        }
    }
    #==========================================
    # check patternType consistency in profiles
    #------------------------------------------
    foreach my $profName (keys %result) {
        my %check;
        foreach my $ptype (@{$result{$profName}}) {
            $check{$ptype} = $ptype;
        }
        my $valid = keys %check;
        if ($valid > 1) {
            my $msg;
            $msg = 'Conflicting patternType attribute values for "';
            $msg.= $profName.'" profile found.';
            $kiwi -> error ( $msg );
            $kiwi -> failed ();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkPatternTypeAttrUse
#------------------------------------------
sub __checkPatternTypeAttrUse {
    # ...
    # The PatternType attribute may only be used for image and bootstrap
    # packages. Check that this is set appropriately.
    # ---
    my $this = shift;
    my @pkgsNodes = $this->{systemTree} -> getElementsByTagName("packages");
    my @notAllowedTypes = qw /delete/;
    for my $pkgs (@pkgsNodes) {
        if ($pkgs -> getAttribute( "patternType" )) {
            my $type = $pkgs -> getAttribute( "type");
            if (grep { /$type/x } @notAllowedTypes) {
                my $kiwi = $this->{kiwi};
                my $msg = 'The patternType atribute is not allowed on a '
                . "<packages> specification of type $type.";
                $kiwi -> error ( $msg );
                $kiwi -> failed ();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkPostDumpAction
#------------------------------------------
sub __checkPostDumpAction {
    # ...
    # Check that only one post dump action for the OEM
    # image type is set, spare oem-bootwait
    # It is reasonable to use oem-bootwait with other actions such
    # as shutdown or reboot.
    # ---
    my $this = shift;
    my @confNodes = $this->{systemTree} -> getElementsByTagName("oemconfig");
    my @postDumOpts = qw {
        oem-reboot
        oem-reboot-interactive
        oem-shutdown
        oem-shutdown-interactive
    };
    for my $oemconfig (@confNodes) {
        my $havePostDumpAction = 0;
        for my $action (@postDumOpts) {
            my @actionList = $oemconfig -> getElementsByTagName($action);
            if (@actionList) {
                my $isSet = $actionList[0]->textContent();
                if ($isSet eq "true") {
                    if ($havePostDumpAction == 0) {
                        $havePostDumpAction = 1;
                        next;
                    }
                    my $kiwi = $this->{kiwi};
                    $kiwi -> error('Only one post dump action may be defined');
                    $kiwi -> error("Use one of @postDumOpts");
                    $kiwi -> failed();
                    return;
                }
            }
        }
    }
    return 1;
}

#==========================================
# __checkPreferencesDefinition
#------------------------------------------
sub __checkPreferencesDefinition {
    # ...
    # Check that only one <preference> definition exists without
    # use of the profiles attribute.
    # ---
    my $this            = shift;
    my $kiwi            = $this->{kiwi};
    my $numProfilesAttr = 0;
    my $systemTree      = $this->{systemTree};
    my @preferences     = $systemTree -> getElementsByTagName('preferences');
    my @usedProfs       = ();
    for my $pref (@preferences) {
        my $profName = $pref -> getAttribute('profiles');
        if (! $profName) {
            $numProfilesAttr++;
        } else {
            if (grep { /^$profName$/x } @usedProfs) {
                my $msg = 'Only one <preferences> element may reference a '
                . "given profile. $profName referenced multiple times.";
                $kiwi -> error ($msg);
                $kiwi -> failed ();
                return;
            } else {
                push @usedProfs, $profName;
            }
        }
        if ($numProfilesAttr > 1) {
            my $msg = 'Specify only one <preferences> element without using '
            . 'the "profiles" attribute.';
            $kiwi -> error ($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkPreferLicenseUnique
#------------------------------------------
sub __checkPreferLicenseUnique {
    # ...
    # Check that the prefer-license attribute is set to true on only one
    # repository per profile.
    # ---
    my $this            = shift;
    my $kiwi            = $this->{kiwi};
    my $systemTree      = $this->{systemTree};
    my @repositories = $systemTree -> getElementsByTagName('repository');
    my $errorCond;
    my %definedPrefLic;
    REPOLOOP:
    for my $repo (@repositories) {
        my $prefLic = $repo -> getAttribute('prefer-license');
        if (defined $prefLic && $prefLic eq 'true') {
            my $profiles = $repo -> getAttribute('profiles');
            if (defined $profiles) {
                my @profs = split /,/, $profiles;
                PROFLOOP:
                for my $prof (@profs) {
                    if (! defined $definedPrefLic{$prof}) {
                        if (defined $definedPrefLic{default}) {
                            $errorCond = 1;
                            last REPOLOOP;
                        }
                        $definedPrefLic{$prof} = 1;
                    }
                    else {
                        $errorCond = 1;
                        last REPOLOOP;
                    }
                }
            }
            else {
                if (! defined $definedPrefLic{default}) {
                    $definedPrefLic{default} = 1;
                }
                else {
                    $errorCond = 1;
                    last REPOLOOP;
                }
            }
        }
    }
    if ($errorCond) {
        my $kiwi = $this -> {kiwi};
        my $msg = 'Ambiguous license preference defined. Cannot resolve '
            . 'prefer-license=true for 2 or repositories.';
        $kiwi -> error($msg);
        $kiwi -> failed();
        return;
    }
    return 1;
}

#==========================================
# __checkProfileNames
#------------------------------------------
sub __checkProfileNames {
    # ...
    # Check that a profile name does not contain whitespace, and is not
    # named "all". "all" has a special meaning in Kiwi :(
    # ---
    my $this = shift;
    my @profiles = $this->{systemTree} -> getElementsByTagName('profile');
    for my $prof (@profiles) {
        my $name = $prof -> getAttribute('name');
        if ($name =~ /\s/) {
            my $kiwi = $this -> {kiwi};
            my $msg = 'Name of a profile may not contain whitespace.';
            $kiwi -> error ($msg);
            $kiwi -> failed();
            return;
        }
        if ($name =~ /(^all$)|(^kiwi_default$)/) {
            my $match = $1 || $2;
            my $kiwi = $this -> {kiwi};
            my $msg = "Name of a profile may not be set to '$match'.";
            $kiwi -> error ($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkReferencedProfDefined
#------------------------------------------
sub __checkReferencedProfDefined {
    # ...
    # Check that any reference of profiles has a defined
    # target, i.e. the profile must be defined
    # ---
    my $this       = shift;
    my $status     = 1;
    my $systemTree = $this->{systemTree};
    my @profiles = $systemTree -> getElementsByTagName('profile');
    my @profNames = ();
    for my $prof (@profiles) {
        push @profNames, $prof -> getAttribute('name');
    }
    my %defProfs = map { ($_ => 1) } @profNames;
    my @nodes = ();
    push @nodes, $systemTree -> getElementsByTagName('drivers');
    push @nodes, $systemTree -> getElementsByTagName('packages');
    push @nodes, $systemTree -> getElementsByTagName('preferences');
    push @nodes, $systemTree -> getElementsByTagName('repository');
    push @nodes, $systemTree -> getElementsByTagName('users');
    for my $node (@nodes) {
        my $refProf = $node -> getAttribute('profiles');
        if (! $refProf) {
            next;
        }
        for my $profile (split (/,/,$refProf)) {
            if (! $defProfs{$profile}) {
                my $kiwi = $this->{kiwi};
                my $msg = 'Found reference to profile "'
                    . $profile
                    . '" but this profile is not defined.';
                $kiwi -> error ($msg);
                $kiwi -> failed ();
                $status = undef;
            }
        }
    }
    return $status;
}

#==========================================
# __checkRevision
#------------------------------------------
sub __checkRevision {
    # ...
    # Check that the current revision meets the minimum requirement
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $systemTree = $this->{systemTree};
    my $imgnameNodeList = $systemTree -> getElementsByTagName ("image");
    if (open (my $FD, '<', $this->{revision})) {
        my $cur_rev = <$FD>; close $FD; chomp $cur_rev;
        my $req_rev = $imgnameNodeList
            -> get_node(1) -> getAttribute ("kiwirevision");
        if ((defined $req_rev) && ($cur_rev ne $req_rev)) {
            $kiwi -> error  ("KIWI revision check");
            $kiwi -> failed ();
            $kiwi -> error ("--> req: $req_rev\n");
            $kiwi -> error ("--> got: $cur_rev\n");
            return;
        }
    }
    return 1;
}

#==========================================
# __checkSysdiskNameNoWhitespace
#------------------------------------------
sub __checkSysdiskNameNoWhitespace {
    # ...
    # Check that the name attribute of the <systemdisk> element does not
    # contain white space
    # ---
    my $this        = shift;
    my $systemTree  = $this -> {systemTree};
    my @sysdiskNodes = $systemTree -> getElementsByTagName('systemdisk');
    if (! @sysdiskNodes ) {
        return 1;
    }
    for my $sysdiskNode (@sysdiskNodes) {
        my $name = $sysdiskNode -> getAttribute('name');
        if ($name) {
            if ($name =~ /\s/x) {
                my $kiwi = $this -> {kiwi};
                my $msg = 'Found whitespace in name given for systemdisk. '
                    . 'Provided name may not contain whitespace.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkTypeConfigConsist
#------------------------------------------
sub __checkTypeConfigConsist {
    # ...
    # Check that a specified <*config> section is consistent with the
    # specified image type.
    # ---
    my $this        = shift;
    my $kiwi        = $this -> {kiwi};
    my $systemTree  = $this -> {systemTree};
    my @types = $systemTree -> getElementsByTagName('type');
    # /.../
    # Relationship of type children to expected type attribute values
    # allow all for cpio (initrd) type which is used to gather information
    # relevant inside the initrd
    # ----
    my %typeChildDeps = (
        'machine'       => 'image:cpio,aci,lxc,docker,oem,vmx,split',
        'oemconfig'     => 'image:cpio,oem,split',
        'vagrantconfig' => 'image:vmx',
        'pxedeploy'     => 'image:cpio,pxe',
        'size'          => ':', # generic
        'split'         => ':', # generic
        'systemdisk'    => ':'  # generic
    );
    for my $typeNode (@types) {
        if (! $typeNode -> hasChildNodes()) {
            next;
        }
        my @typeConfig = $typeNode -> childNodes();
        for my $typeOpt (@typeConfig) {
            my $optName = $typeOpt->localname();
            if ($optName) {
                if ( grep { /^$optName$/x } keys %typeChildDeps ) {
                    my @deps = split /:/, $typeChildDeps{$optName};
                    if (@deps) {
                        my $typeAttrReq    = $deps[0];
                        my @typeAttrValReq = split (/,/,$deps[1]);
                        my $configValue =
                            $typeNode -> getAttribute ($typeAttrReq);
                        my $found = 0;
                        foreach my $typeAttrValReq (@typeAttrValReq) {
                            if ( $configValue eq $typeAttrValReq ) {
                                $found = 1; last;
                            }
                        }
                        if ( ! $found ) {
                            my $msg = 'Inconsistent configuration: Found '
                            . "$optName type configuration as child of "
                            . "image type $configValue.";
                            $kiwi -> error($msg);
                            $kiwi -> failed();
                            return;
                        }
                    }
                } else {
                    my $msg = "Unknown type configuration section '$optName' "
                    . 'found. Please report to the kiwi mailing list';
                    $kiwi -> warning($msg);
                    $kiwi -> skipped();
                    next;
                }
            }
        }
    }
    return 1;
}

#==========================================
# __checkTypeInstallMediaConsist
#------------------------------------------
sub __checkTypeInstallMediaConsist {
    # ...
    # Cehck that the install media settings are consistent
    # Valid combinations
    # installiso="true"
    # installstick="true"
    # installstick="true" installiso="true"
    # installiso="true" hybrid="true"
    # ---
    my $this = shift;
    my @types = $this->{systemTree} -> getElementsByTagName('type');
    for my $type (@types) {
        my $hybrid = $type -> getAttribute('hybrid');
        if ($hybrid && $hybrid eq 'true') {
            my $stick = $type -> getAttribute('installstick');
            if ($stick && $stick eq 'true') {
                my $kiwi = $this -> {kiwi};
                my $msg = 'Combination of hybrid="true" and '
                    . 'installstick="true" is ambiguous.';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }

    return 1;
}

#==========================================
# __checkTypePckgsTypeExists
#------------------------------------------
sub __checkTypePckgsTypeExists {
    # ...
    # Check that the type for which packages are specified exists
    # for each profile
    # ---
    my $this = shift;
    my @prefs = $this->{systemTree} -> getElementsByTagName('preferences');
    my @profs = $this->{systemTree} -> getElementsByTagName('profiles');
    my $profNames;
    if (@profs) {
        for my $prof (@profs) {
            for my $profile ($prof -> getElementsByTagName('profile')) {
                my $name = $profile -> getAttribute('name');
                $profNames .= $name.',';
            }
        }
        $profNames =~ s/,$//;
    }
    my %typeInfo;
    for my $pref (@prefs) {
        my @specTypes;
        my @types = $pref -> getElementsByTagName('type');
        for my $type (@types) {
            my $name = $type -> getAttribute('image');
            push @specTypes, $name;
        }
        if ($profNames) {
            my @pNames = split /,/, $profNames;
            for my $pName (@pNames) {
                if (defined $typeInfo{$pName}) {
                    my @typeLst = @{$typeInfo{$pName}};
                    push @typeLst, @specTypes;
                    $typeInfo{$pName} = \@typeLst
                } else {
                    $typeInfo{$pName} = \@specTypes;
                }
            }
        } else {
            $typeInfo{default} = \@specTypes;
        }
    }
    my @pckNodes = $this->{systemTree} -> getElementsByTagName('packages');
    for my $pckNode (@pckNodes) {
        my $pckTypeName = $pckNode -> getAttribute('type');
        if ($pckTypeName =~ /bootstrap|delete|image|testsuite/x) {
            next;
        }
        if ($profNames) {
            my @pNames = split /,/, $profNames;
            for my $pName (@pNames) {
                my @typeLst = @{$typeInfo{$pName}};
                if (! grep { /^$pckTypeName$/x } @typeLst ) {
                    my $kiwi = $this -> {kiwi};
                    my $msg = "Specified packages for type '$pckTypeName'"
                        . ' but this type is not defined for profile '
                        . "'$pName'";
                    $kiwi -> error($msg);
                    $kiwi -> failed();
                    return;
                }
            }
        } else {
            my @typeLst = @{$typeInfo{default}};
            if (! grep { /^$pckTypeName$/x } @typeLst ) {
                my $kiwi = $this -> {kiwi};
                my $msg = "Specified packages for type '$pckTypeName'"
                    . ' but this type is not defined for the default '
                    . 'image';
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
        }
    }
    return 1;
}

#==========================================
# __checkTypeUnique
#------------------------------------------
sub __checkTypeUnique {
    # ...
    # Check that only one type with image="myName" exists per
    # <preferences section>
    # ---
    my $this        = shift;
    my $systemTree  = $this->{systemTree};
    my @preferences = $systemTree -> getElementsByTagName('preferences');
    for my $pref (@preferences) {
        my @imgTypes = ();
        my @types = $pref -> getChildrenByTagName('type');
        for my $typeN (@types) {
            my $imgT = $typeN -> getAttribute('image');
            if (grep { /$imgT/x } @imgTypes) {
                my $kiwi = $this->{kiwi};
                my $msg = 'Multiple definition of <type image="'
                    . $imgT
                    . '".../> found.';
                $kiwi -> error ($msg);
                $kiwi -> failed ();
                return;
            }
            push @imgTypes, $imgT
        }
    }
    return 1;
}

#==========================================
# __checkUserDataConsistent
#------------------------------------------
sub __checkUserDataConsistent {
    # ..
    # Check that the given data for a user is consistent if the
    # user is specified in two groups
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $systemTree = $this->{systemTree};
    my @grpNodes = $systemTree -> getElementsByTagName('users');
    my $errMsg;
    my %userData;
    for my $grpNode (@grpNodes) {
        my $group = $grpNode -> getAttribute('group');
        my $gid   = $grpNode -> getAttribute('id');
        my @userNodes = $grpNode -> getElementsByTagName('user');
        for my $usr (@userNodes) {
            my %info;
            my $name = $usr -> getAttribute('name');
            $info{group} = $group;
            $info{gid}   = $gid;
            $info{home}  = $usr -> getAttribute('home');
            $info{name}  = $name;
            $info{pwd}   = $usr -> getAttribute('password');
            $info{pwdf}  = $usr -> getAttribute('pwdformat');
            $info{rname} = $usr -> getAttribute('realname');
            $info{shell} = $usr -> getAttribute('shell');
            $info{uid}   = $usr -> getAttribute('id');
            if ($name =~ /\s/x) {
                $errMsg = 'Specified user name contains whitspace, this '
                    . 'is not supported.';
            }
            if ($info{home} =~ /\s/x) {
                $errMsg = 'Specified home directory contains whitspace, '
                    . 'this is not supported.';
            }
            if ($info{shell} && $info{shell} =~ /\s/x) {
                $errMsg = 'Specified login shell contains whitspace, '
                    . 'this is not supported.';
            }
            if ($userData{$name}) {
                if ($group eq $userData{$name}{group}) {
                    $errMsg = 'Same user defined in a single group, '
                    . 'cannot resolve ambiguity.';
                }
                if ($gid && $userData{$name}{gid}) {
                    $errMsg = 'Same user defined in two groups with '
                        . 'given groupid, cannot resolve ambiguity.';
                }
                if ($info{home} ne $userData{$name}{home}) {
                    $errMsg = 'Same user specified with different home '
                        . 'directories, cannot resolve ambiguity.';
                }
                if ($info{pwd}
                    && $userData{$name}{pwd}
                    && ($info{pwd} ne $userData{$name}{pwd}))
                {
                    $errMsg = 'Same user specified with different '
                        . 'passwords, cannot resolve ambiguity.';
                }
                if ($info{pwdf}
                    && $userData{$name}{pwdf}
                    && ($info{pwdf} ne $userData{$name}{pwdf}))
                {
                    $errMsg = 'Same user specified with different '
                        . 'password formats, cannot resolve ambiguity.';
                }
                if ($info{rname}
                    && $userData{$name}{rname}
                    && ($info{rname} ne $userData{$name}{rname}))
                {
                    $errMsg = 'Same user specified with different '
                        . 'real names, cannot resolve ambiguity.';
                }
                if ($info{shell}
                    && $userData{$name}{shell}
                    && ($info{shell} ne $userData{$name}{shell}))
                {
                    $errMsg = 'Same user specified with different '
                        . 'shells, cannot resolve ambiguity.';
                }
                if ($info{uid}
                    && $userData{$name}{uid}
                    && ($info{uid} ne $userData{$name}{uid}))
                {
                    $errMsg = 'Same user specified with different '
                        . 'user ids, cannot resolve ambiguity.';
                }
            }
            if ($errMsg) {
                $kiwi -> error($errMsg);
                $kiwi -> failed();
                return;
            }
            $userData{$name} = \%info;
        }
    }
    return 1;
}

#==========================================
# __checkVersionDefinition
#------------------------------------------
sub __checkVersionDefinition {
    # ...
    # Check image version format
    # This check should be implemented in the schema but there is a
    # bug in libxml2 that prevents proper type validation for elements
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $systemTree = $this->{systemTree};
    my @versions = $systemTree -> getElementsByTagName('version');
    my $numVersions = @versions;
    if (! @versions) {
        my $msg = 'The <version> element must be present';
        $kiwi -> error  ($msg);
        $kiwi -> failed ();
        return;
    }
    if ($numVersions > 1) {
        my $msg = "Only one <version> definition expected, found $numVersions";
        $kiwi -> error  ($msg);
        $kiwi -> failed ();
        return;
    }
    my $version = $versions[0] -> textContent();
    if ($version !~ /^\d+\.\d+\.\d+$/) {
        $kiwi -> error  ("Invalid version format: $version");
        $kiwi -> failed ();
        $kiwi -> error  ("Expected 'Major.Minor.Release'");
        $kiwi -> failed ();
        return;
    }
    return 1;
}

#==========================================
# __checkVolAttrsConsist
#------------------------------------------
sub __checkVolAttrsConsist {
    # ...
    # Check that the attributes size and freespace are not used in
    # combination on the <volume> element.
    # ---
    my $this        = shift;
    my $systemTree  = $this -> {systemTree};
    my @volumeNodes = $systemTree -> getElementsByTagName('volume');
    if (! @volumeNodes ) {
        return 1;
    }
    for my $volNode (@volumeNodes) {
        my $size = $volNode -> getAttribute('size');
        my $free = $volNode -> getAttribute('freespace');
        if ($size && $free) {
            my $kiwi = $this -> {kiwi};
            my $msg = 'Found combination of "size" and "freespace" attribute '
                . 'for volume element. This is not supported.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkVolNameNoWhitespace
#------------------------------------------
sub __checkVolNameNoWhitespace {
    # ...
    # Check that the name attribute of the <volume> element does not
    # contain white space
    # ---
    my $this        = shift;
    my $systemTree  = $this -> {systemTree};
    my @volumeNodes = $systemTree -> getElementsByTagName('volume');
    for my $volNode (@volumeNodes) {
        my $name = $volNode -> getAttribute('name');
        if ($name =~ /\s/x) {
            my $kiwi = $this -> {kiwi};
            my $msg = 'Found whitespace in given volume name. '
                . 'Provided name may not contain whitespace.';
            $kiwi -> error($msg);
            $kiwi -> failed();
            return;
        }
    }
    return 1;
}

#==========================================
# __checkVolNameUnique
#------------------------------------------
sub __checkVolNameUnique {
    # ...
    # Check that the given volume name is unique across all volumes in a
    # systemdisk configuration.
    # ---
    my $this        = shift;
    my $systemTree  = $this -> {systemTree};
    my @sysDiskNodes = $systemTree -> getElementsByTagName('systemdisk');
    for my $sysDNode (@sysDiskNodes) {
        my %volNames;
        my @volumes = $sysDNode -> getElementsByTagName('volume');
        for my $vol (@volumes) {
            my $name = $vol -> getAttribute('name');
            if ($volNames{$name}) {
                my $kiwi = $this->{kiwi};
                my $msg = "Found non unique volume name '$name'.";
                $kiwi -> error($msg);
                $kiwi -> failed();
                return;
            }
            $volNames{$name} = 1;
        }
    }
    return 1;
}

#==========================================
# __getXMLDocTree
#------------------------------------------
sub __getXMLDocTree {
    # ...
    # Generate the XML Document tree for perl
    # ---
    my $this = shift;
    my $XML  = shift;
    my $kiwi = $this->{kiwi};
    my $systemTree;
    my $systemXML = XML::LibXML -> new ();
    eval {
        $systemTree = $systemXML -> parse_fh ( $XML );
    };
    if ($@) {
        my $evaldata = $@;
        $kiwi -> error  ("Problem reading control file");
        $kiwi -> failed ();
        return;
    }
    return $systemTree;
}

#==========================================
# __loadControlfile
#------------------------------------------
sub __loadControlfile {
    # ...
    # Load the XML file and pass it to the XSLT stylesheet
    # processor for internal version conversion
    # ---
    my $this        = shift;
    my $controlFile = $this->{config};
    my $kiwi        = $this->{kiwi};
    my $skipXSLT    = 0; # For development debug purposes
    my $xslt        = $this->{xslt};
    my $XML;
    if ($skipXSLT) {
        if (! open ($XML, '-|', "cat $controlFile")) {
            $kiwi -> error ("XSL: Failed to open file $controlFile");
            $kiwi -> failed ();
            return;
        }
    } else {
        if (! open ($XML, '-|', "xsltproc $xslt $controlFile")) {
            $kiwi -> error ("XSL: Failed to open xslt processor");
            $kiwi -> failed ();
            return;
        }
    }
    binmode $XML;
    return $XML;
}

#==========================================
# __uniqueInPackages
#------------------------------------------
sub __uniqueInPackages {
    # ...
    # Loop through all packages sections and check that
    # specified names are unique for the given child
    # element.
    # ---
    my $this     = shift;
    my $chldName = shift;
    my @chldNodes = $this->{systemTree} -> getElementsByTagName('packages');
    for my $chld (@chldNodes) {
        my @names = ();
        my @children = $chld -> getElementsByTagName($chldName);
        for my $entry (@children) {
            my $arch = $entry -> getAttribute('arch');
            my $name = $entry -> getAttribute('name');
            my $repl = $entry -> getAttribute('replaces');
            my $item = $name;
            if ($arch) {
                $item .= ",$arch";
            }
            if ($repl) {
                $item .= ",$repl";
            }
            for my $name (@names) {
                if ($name eq $item) {
                    return $item;
                }
            }
            push @names,$item;
        }
    }
    return;
}

#==========================================
# __validateConsistency
#------------------------------------------
sub __validateConsistency {
    # ...
    # Validate XML data that cannot be validated through Schema and
    # structure validation. This includes conditional presence of
    # elements and attributes as well as certain values.
    # Note that any checks need to work off $this->{systemTree}. The
    # consistency check occurs prior to this object being porpulated
    # with XML data. This allows us to basically have no error checking
    # in any code that populates this object from XML data.
    # ---
    my $this = shift;
    if (! $this -> __checkArchiveUnique()) {
        return;
    }
    if (! $this -> __checkBootSpecPresent()) {
        return;
    }
    if (! $this -> __checkContainerSpec()) {
        return;
    }
    if (! $this -> __checkDefaultProfSetting()) {
        return;
    }
    if (! $this -> __checkDefaultTypeSetting()){
        return;
    }
    if (! $this -> __checkDeletePackNoPatNoTar()) {
        return;
    }
    if (! $this -> __checkDisplaynameValid()) {
        return;
    }
    if (! $this -> __checkIsFormatEC2()) {
        return;
    }
    if (! $this -> __checkFilesysSpec()) {
        return;
    }
    if (! $this -> __checkGroupSettingsConsistent()) {
        return;
    }
    if (! $this -> __checkHttpsCredentialsConsistent()) {
        return;
    }
    if (! $this -> __checkInstallVerifyAction()) {
        return;
    }
    if (! $this -> __checkNetInterfaceMACUnique()) {
        return;
    }
    if (! $this -> __checkNetInterfaceNameUnique()) {
        return;
    }
    if (! $this -> __checkNoBootVolume()) {
        return;
    }
    if (! $this -> __checkNoIDSystemGroups()) {
        return;
    }
    if (! $this -> __checkOVFTypeSet()) {
        return;
    }
    if (! $this -> __checkPackageUnique()) {
        return;
    }
    if (! $this -> __checkPatternUnique()) {
        return;
    }
    if (! $this -> __checkPatternTypeAttrUse()) {
        return;
    }
    if (! $this -> __checkPatternTypeAttrConsistent()) {
        return;
    }
    if (! $this -> __checkPostDumpAction()) {
        return;
    }
    if (! $this -> __checkPreferencesDefinition()) {
        return;
    }
    if (! $this -> __checkPreferLicenseUnique()) {
        return;
    }
    if (! $this -> __checkProfileNames()) {
        return;
    }
    if (! $this -> __checkReferencedProfDefined()) {
        return;
    }
    if (! $this -> __checkRevision()) {
        return;
    }
    if (! $this -> __checkSysdiskNameNoWhitespace()) {
        return;
    }
    if (! $this -> __checkTypeConfigConsist()) {
        return;
    }
    if (! $this -> __checkTypeInstallMediaConsist()) {
        return;
    }
    if (! $this -> __checkTypePckgsTypeExists()) {
        return;
    }
    if (! $this -> __checkTypeUnique()) {
        return;
    }
    if (! $this -> __checkUserDataConsistent()) {
        return;
    }
    if (! $this -> __checkVersionDefinition()) {
        return;
    }
    if (! $this -> __checkVolAttrsConsist()) {
        return;
    }
    if (! $this -> __checkVolNameNoWhitespace()) {
        return;
    }
    if (! $this -> __checkVolNameUnique()) {
        return;
    }
    return 1;
}

#==========================================
# __validateXML
#------------------------------------------
sub __validateXML {
    # ...
    # Validate the control file for syntactic and
    # structural correctness according to current schema
    # ---
    my $this = shift;
    my $controlFile = $this->{config};
    my $kiwi        = $this->{kiwi};
    my $systemTree  = $this->{systemTree};
    my $systemXML   = XML::LibXML -> new ();
    my $systemRNG   = XML::LibXML::RelaxNG -> new(location => $this->{schema});
    eval {
        $systemRNG ->validate ( $systemTree );
    };
    if ($@) {
        my $evaldata=$@;
        $kiwi -> error  ("Schema validation failed");
        $kiwi -> failed ();
        my $configStr = $systemXML -> parse_file( $controlFile ) -> toString();
        my $upgradedStr = $systemTree -> toString();
        my $upgradedContolFile = $controlFile;
        if ($configStr ne $upgradedStr) {
            $upgradedContolFile =~ s/\.xml/\.converted\.xml/;
            my $UPCNTFL;
            if (! open ($UPCNTFL, '>', $upgradedContolFile)) {
                $kiwi -> error  ("Failed to auto upgrade control file: $!");
                $kiwi -> failed ();
            } else {
                print $UPCNTFL $upgradedStr;
                close ( $UPCNTFL );
                my $info;
                $info = "Automatically upgraded $controlFile ";
                $info.= "to $upgradedContolFile\n";
                $kiwi -> info ( $info );
                $info = "Reported Line numbers may not match the ";
                $info.= "file $controlFile\n";
                $kiwi -> info ( $info );
            }
        }
        my $locator = KIWILocator -> instance();
        my $jingExec = $locator -> getExecPath('jing');
        if ($jingExec) {
            $evaldata = KIWIQX::qxx (
                "$jingExec $this->{schema} $upgradedContolFile 2>/dev/null"
            );
            $kiwi -> error ("$evaldata\n");
            return;
        } else {
            $kiwi -> error ("$evaldata\n");
            $kiwi -> info  ("Use the jing command for more details\n");
            $kiwi -> info  ("The following requires jing to be installed\n");
            $kiwi -> info  ("jing $this->{schema} $upgradedContolFile\n");
            return;
        }
    }
    return 1;
}

1;
