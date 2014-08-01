#================
# FILE          : KIWIAnalyseReport.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide methods for
#               : migrating a running system into an image
#               : description
#               :
#               :
#               :
# STATUS        : Development
#----------------
package KIWIAnalyseReport;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use XML::LibXML;
use FileHandle;
use File::Basename;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILog;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
    # ...
    # Create a new KIWIAnalyseReport object which is used to
    # gather information on the running system
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
    my $destdir  = shift;
    my $cmdL     = shift;
    my $system   = shift;
    my $software = shift;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $kiwi   = KIWILog -> instance();
    my $global = KIWIGlobals -> instance();
    if ((! $destdir) || (! -d $destdir)) {
        $kiwi -> error  (
            "KIWIAnalyseReport: Couldn't find destination dir: $destdir"
        );
        $kiwi -> failed ();
        return;
    } 
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{gdata}    = $global -> getKiwiConfig();
    $this->{kiwi}     = $kiwi;
    $this->{dest}     = $destdir;
    $this->{system}   = $system;
    $this->{software} = $software;
    $this->{cmdL}     = $cmdL;
    return $this;
}

#==========================================
# createReport
#------------------------------------------
sub createReport {
    # ...
    # create html page report including action items for the
    # user to solve outstanding problems in order to allow a
    # clean migration of the system into an image description
    # ---
    my $this = shift;
    my $kiwi = $this->{kiwi};
    my $dest = $this->{dest};
    my $software = $this->{software};
    my $system   = $this->{system};
    my %gems;
    my %repo;
    my %json;
    my $ip = $system -> getIPAddress();
    $json{files} = $system
        -> createCustomDataForType('file',5);
    $json{binaries} = $system
        -> createCustomDataForType('elfbin');
    $json{modified} = $system
        -> createCustomDataForType('modified');
    $json{homes} = $system
        -> createCustomDataForType('homedata',5);
    my $custom = $system
        -> getCustomData();
    my $multiple = $software
        -> getMultipleInstalledPackages();
    my $problem1 = $software
        -> getSolverPatternConflict();
    my $problem2 = $software
        -> getSolverPackageConflict();
    my $failedJob1 = $software
        -> getSolverPatternNotFound();
    my $failedJob2 = $software
        -> getSolverPackageNotFound();
    my $packages = $system
        -> getInstalledPackages();
    my $modalias = $system
        -> getHardwareDependantPackages();
    my $kernel = $system
        -> getKernelVersion();
    my @kernelPackages = $system
        -> getKernelPackages();
    my $svnbase;
    foreach my $item (sort keys %{$custom}) {
        my $type = $custom->{$item}->[0];
        if (($svnbase) && ($item !~ /$svnbase/)) {
            undef $svnbase;
        }
        if ($type eq 'rubygems') {
            next if (-d $item);
            if ($item =~ /(.*\/gems)\/(.*)\/Rakefile$/) {
                my $gempath = $1;
                my @gemname = split(/\//,$2);
                $gems{$gempath}{$gemname[0]} = $type;
            }
        }
        if ($type eq 'git') {
            if (-d "$item/.git") {
                $repo{$item} = $type;
            }
        }
        if ($type eq 'osc') {
            if (-d "$item/.osc") {
                $repo{$item} = $type;
            }
        }
        if ($type eq 'svn') {
            if (-d "$item/.svn") {
                if (! defined $svnbase) {
                    $svnbase = $item;
                    $repo{$item} = $type;
                }
            }
        }
    }
    #==========================================
    # Beautify report...
    #------------------------------------------
    mkdir "$dest/.report";
    my $status = KIWIQX::qxx (
        "tar -C $dest/.report -xf $this->{gdata}->{KAnalyseCSS} 2>&1"
    );
    my $result = $? >> 8;
    if ($result != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't extract CSS data: $status");
        $kiwi -> failed ();
        return;
    }
    #==========================================
    # Start report
    #------------------------------------------
    my $FD = FileHandle -> new();
    if (! $FD -> open (">$dest/report.html")) {
        $kiwi -> failed ();
        $kiwi -> error  ("Couldn't create report: $!");
        $kiwi -> failed ();
        return;
    }
    my $title = "Migration report";
    print $FD '<!DOCTYPE html>'."\n";
    print $FD '<html>'."\n";
    print $FD '<head>'."\n";
    print $FD "<meta http-equiv=\"Content-Type\"";
    print $FD " content=\"text/html;charset=utf-8\"/>"."\n";
    print $FD '<title>'.$title.'</title>'."\n";
    #==========================================
    # CSS
    #------------------------------------------
    print $FD '<link type="text/css" rel="stylesheet"';
    print $FD ' href=".report/d3/style.css"/>'."\n";
    print $FD '<link type="text/css" rel="stylesheet"';
    print $FD ' href=".report/d3/kiwi.css">'."\n";
    print $FD '<link type="text/css" rel="stylesheet"';
    print $FD ' href=".report/d3/theme.css">'."\n";
    #==========================================
    # Java Script
    #------------------------------------------
    print $FD '<script type="text/javascript"';
    print $FD ' src=".report/d3/d3.js"></script>'."\n";
    print $FD '<script type="text/javascript"';
    print $FD ' src=".report/d3/d3.layout.js"></script>'."\n";
    print $FD '<script type="text/javascript"';
    print $FD ' src=".report/d3/kiwi.js"></script>'."\n";
    print $FD '<script src="http://code.jquery.com/jquery-1.11.0.min.js">';
    print $FD '</script>'."\n";
    print $FD '<script type="text/javascript">'."\n";
    print $FD '  $(document).on("ready", function(){'."\n";
    print $FD '    $(".infoPanel").each(function(index, val) {'."\n";
    print $FD '      $("h1").css({'."\n";
    print $FD '        "cursor": "pointer"'."\n";
    print $FD '      })'."\n";
    print $FD '      $(this).children(".panel-wraper").show()'."\n";
    print $FD '    })'."\n";
    print $FD '    $("h1").click(function(event) {'."\n";
    print $FD '  $(this).parent().children(".panel-wraper").slideToggle(400)';
    print $FD "\n";
    print $FD '  });'."\n";
    print $FD '})'."\n";
    print $FD '</script>'."\n";
    print $FD '</head>'."\n";
    #==========================================
    # Container Menu
    #------------------------------------------
    my %menu = ();
    my $img  = '.report/d3/img/menu';
    $menu{'kernel'} = [
        "$img/kernel.jpg","Kernel"
    ];
    if ($custom) {
        $menu{'custom-files'} = [
            "$img/custom-files.jpg","Custom Files"
        ];
        $menu{'custom-files-visualisation'} = [
            "$img/custom-files-visualisation.jpg","Visualisation"
        ];
    }
    if ($modalias) {
        $menu{'RPM-packages'} = [
            "$img/RPM-packages.jpg","Hardware Packages"
        ];
    }
    if ($multiple) {
        $menu{'multiple-RPM'} = [
            "$img/multiple-RPM.jpg","Multiple RPM"
        ];
    }
    if ($problem2) {
        $menu{'RPM-conflicts'} = [
            "$img/RPM-conflicts.jpg","RPM Conflicts"
        ];
    }
    if ($problem1) {
        $menu{'pattern-conflicts'} = [
            "$img/RPM-conflicts.jpg","Pattern Conflicts"
        ];
    }
    if (($failedJob1) && (@{$failedJob1})) {
        $menu{'pattern-lost'} = [
            "$img/RPM-lost.jpg","Pattern not found"
        ];
    }
    if (($failedJob2) && (@{$failedJob2})) {
        $menu{'RPM-lost'} = [
            "$img/RPM-lost.jpg","RPM not found"
        ];
    }
    if (%repo) {
        $menu{'local-repositories'} = [
            "$img/local-repositories.jpg","Repositories"
        ];
    }
    if (%gems) {
        $menu{'gems'} = [
            "$img/gems.jpg","GEMs"
        ];
    }
    print $FD '<body class="files">'."\n";
    print $FD '<header>'."\n";
    print $FD '<div class="container menu">'."\n";
    foreach my $item (sort keys %menu) {
        print $FD '<a href="#'.$item.'">'."\n";
        print $FD '<img src="'.$menu{$item}->[0].'">'."\n";
        print $FD '<h3>'.$menu{$item}->[1].'</h3>'."\n";
        print $FD '</a>'."\n";
    }
    print $FD '</div>'."\n";
    print $FD '</header>'."\n";
    #==========================================
    # Chapters
    #------------------------------------------
    print $FD '<div class="container">'."\n";
    #==========================================
    # Kernel version report
    #------------------------------------------
    print $FD '<div class="infoPanel">'."\n";
    print $FD '<a name="kernel"></a>'."\n";
    print $FD '<h1>Currently active kernel version</h1>'."\n";
    print $FD '<div class="panel-wraper">'."\n";
    print $FD '<p>'."\n";
    print $FD 'The table below shows the packages required for the currently ';
    print $FD 'active kernel. The generated image description template ';
    print $FD 'always uses the default kernel when building the image. ';
    print $FD 'If another kernel e.g the xen kernel is in use or multiple ';
    print $FD 'kernels are installed, you need to make sure to select ';
    print $FD 'the kernel of the image with the bootkernel and bootprofile ';
    print $FD 'attributes in the type section of the config.xml file';
    print $FD '</p>'."\n";
    print $FD '<hr>'."\n";
    if (! -e "/lib/modules/$kernel") {
        print $FD '<p>'."\n";
        print $FD "Sorry no kernel package found for running kernel: $kernel ";
        print $FD 'In case the kernel was updated make sure to reboot the ';
        print $FD 'machine in order to activate the installed kernel ';
        print $FD '</p>'."\n";
    } else {
        print $FD '<table>'."\n";
        foreach my $item (sort @kernelPackages) {
            if ($item =~ /(.*):(.*)/) {
                my $pac = $1;
                my $ver = $2;
                print $FD '<tr valign="top">'."\n";
                print $FD '<td>'.$pac.'</td>'."\n";
                print $FD '<td>'.$ver.'</td>'."\n";
                print $FD '</tr>'."\n";
            }
        }
        print $FD '</table>'."\n";
    }
    print $FD '</div>'."\n";
    print $FD '</div>'."\n";
    #==========================================
    # Hardware dependent packages report
    #------------------------------------------
    if ($modalias) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="RPM-packages"></a>'."\n";
        print $FD '<h1>Hardware dependent RPM packages </h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The table below shows packages that depend on specific ';
        print $FD 'hardware Please note that it might be required to have a ';
        print $FD 'different set of hardware dependent packages included into ';
        print $FD 'the image description depending on the target hardware. ';
        print $FD 'If there is the need for such packages make sure you add ';
        print $FD 'them as package name="name-of-package" bootinclude="true"';
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        print $FD '<table>'."\n";
        foreach my $item (sort keys %{$modalias}) {
            print $FD '<tr valign="top">'."\n";
            print $FD '<td>'.$item.'</td>'."\n";
            print $FD '</tr>'."\n";
        }
        print $FD '</table>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    #==========================================
    # Local repository checkout(s)
    #------------------------------------------
    if (%repo) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="local-repositories"></a>'."\n";
        print $FD '<h1>Local repository checkout paths </h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The table below shows the local paths which belongs ';
        print $FD 'to source control systems like git. It is assumed ';
        print $FD 'that this data can be restored from a central place ';
        print $FD 'and thus the data there is not part of the unpackaged ';
        print $FD 'files tree. Please check whether the repository can ';
        print $FD 'be cloned from a central storage or include the data ';
        print $FD 'in the overlay tree';
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        print $FD '<table>'."\n";
        foreach my $repopath (sort keys %repo) {
            print $FD '<tr valign="top">'."\n";
            print $FD '<td>'.$repopath.'</td>'."\n";
            print $FD '<td> type: '.$repo{$repopath}.'</td>'."\n";
            print $FD '</tr>'."\n";
        }
        print $FD '</table>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    #==========================================
    # GEM packages report
    #------------------------------------------
    if (%gems) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="gems"></a>'."\n";
        print $FD '<h1>Installed GEM packages </h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The table(s) below shows GEM packages found on the system ';
        print $FD 'and installed by gem manually. In order to migrate them ';
        print $FD 'correctly make sure you either have the corresponding ';
        print $FD 'rpm package for this gem in your kiwi packages list or ';
        print $FD 'implement a mechanism to let the gem package manager ';
        print $FD 'install this software.';
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        foreach my $gempath (sort keys %gems) {
            print $FD "<h2>$gempath</h2>"."\n";
            print $FD '<table>'."\n";
            foreach my $gem (sort keys %{$gems{$gempath}}) {
                print $FD '<tr valign="top">'."\n";
                print $FD '<td>'.$gem.'</td>'."\n";
                print $FD '</tr>'."\n";
            }
            print $FD '</table>'."\n";
        }
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    #==========================================
    # Package/Pattern report
    #------------------------------------------
    if ($multiple) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="multiple-RPM"></a>'."\n";
        print $FD '<h1>RPM Package(s) installed multiple times</h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The following packages are installed multiple times. ';
        print $FD 'For a clone of the system you only need to take the ';
        print $FD 'latest version into account which also is the default. ';
        print $FD 'action when re-installing those packages.';
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        print $FD '<table>'."\n";
        foreach my $pac (sort @{$multiple}) {
            print $FD '<tr valign="top">'."\n";
            print $FD '<td>'.$pac.'</td>'."\n";
            print $FD '</tr>'."\n";
        }
        print $FD '</table>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    if ($problem1) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="pattern-conflicts"></a>'."\n";
        print $FD '<h1>Pattern conflict(s)</h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The following patterns could not be solved because ';
        print $FD 'they have dependency conflicts. Please check the list ';
        print $FD 'and solve the conflicts by either: ';
        print $FD "\n";
        print $FD '<ul>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Adding all software repositories which provide ';
        print $FD 'the missing dependences, or';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Ignoring the pattern. If you ignore the pattern, your ';
        print $FD 'selected software might not be part of your final image.';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '</ul>'."\n";
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        print $FD '<pre>'."\n";
        print $FD "$problem1";
        print $FD '</pre>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    if ($problem2) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="RPM-conflicts"></a>'."\n";
        print $FD '<h1>RPM Package conflict(s)</h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The following packages could not be solved due to ';
        print $FD 'dependency conflicts. Please check the list and ';
        print $FD 'solve them by either:';
        print $FD "\n";
        print $FD '<ul>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Following one of the problem solutions mentioned in ';
        print $FD 'the conflict report below, or';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Skipping the concerning package(s) by calling kiwi ';
        print $FD 'again with the --skip option.';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '</ul>'."\n";
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        print $FD '<pre>'."\n"; 
        print $FD "$problem2";
        print $FD '</pre>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    if (($failedJob1) && (@{$failedJob1})) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="pattern-lost"></a>'."\n";
        print $FD '<h1>Pattern(s) not found</h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The following patterns could not be found in your ';
        print $FD 'repository list marked as installed. Please check the ';
        print $FD 'list and solve the problem by either: ';
        print $FD "\n";
        print $FD '<ul>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Adding a repository which provides the ';
        print $FD 'pattern, or';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Ignoring the pattern.  If you ignore the pattern, your ';
        print $FD 'selected software will not be a part of your final image.';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '</ul>'."\n";
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        print $FD '<ul>'."\n";
        foreach my $job (@{$failedJob1}) {
            print $FD '<li>'.$job.'</li>'."\n";
        }
        print $FD '</ul>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    if (($failedJob2) && (@{$failedJob2})) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="RPM-lost"></a>'."\n";
        print $FD '<h1>RPM Package(s) not found</h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'The following packages could not be found in your ';
        print $FD 'repository list but are installed on the system ';
        print $FD 'Please check the list and solve the problem by ';
        print $FD 'either:';
        print $FD "\n";
        print $FD '<ul>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Adding a repository which provides the ';
        print $FD 'package, or';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '<li>'."\n";
        print $FD 'Ignoring the package. If you ignore the package, your ';
        print $FD 'software selection might not be part of your final image.';
        print $FD "\n";
        print $FD '</li>'."\n";
        print $FD '</ul>'."\n";
        print $FD '</p>'."\n";
        print $FD '<hr>'."\n";
        print $FD '<table>'."\n";
        foreach my $pac (@{$failedJob2}) {
            my $date    = $packages->{$pac}{installdate};
            my $distro  = $packages->{$pac}{distribution};
            my $disturl = $packages->{$pac}{disturl};
            my $srcurl  = $packages->{$pac}{url};
            if ($disturl !~ s:/[^/]*$::) {
                $disturl = $srcurl;
            }
            if ($distro =~ /^(\s*|\(none\))$/) {
                $distro = "No distribution";
            }
            if ($disturl =~ /^(\s*|\(none\))$/) {
                $disturl = "No URL";
            }
            print $FD '<tr valign="top">'."\n";
            print $FD '<td><nobr>'.$pac.'</nobr></td>'."\n";
            print $FD '<td>';
            print $FD '<nobr>'.$date.'</nobr><br>';
            print $FD '<nobr>'.$distro.'</nobr><br>';
            print $FD '<nobr>'.$disturl.'</nobr>';
            print $FD '</td>'."\n";
            print $FD '</tr>'."\n";
        }
        print $FD '</table>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    #==========================================
    # Custom files report...
    #------------------------------------------
    if ($custom) {
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="custom-files"></a>'."\n";
        print $FD '<h1>Custom files</h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'Within the current custom.files sync source file you will ';
        print $FD 'find files/directories which are not part of any package.';
        print $FD 'For binary files, including executables and libraries, ';
        print $FD 'you should try to find and include a package that ';
        print $FD 'provides them. If there are no package providers for ';
        print $FD 'this file, you can leave them as overlay files, but it ';
        print $FD 'may cause problems like broken dependencies later. ';
        print $FD 'After that, you should look for personal files like ';
        print $FD 'pictures, movies, etc. and decide to either skip them ';
        print $FD 'if they can be easily restored later or store them in ';
        print $FD 'the overlay files tree but keep in mind that the size ';
        print $FD 'of the image could become big. Update the created sync ';
        print $FD 'source file with the files/directories you want to be ';
        print $FD "part of the image and call $dest/custom.sync when done.";
        print $FD 'You can watch the complete custom source file here: '."\n";
        print $FD '</p>'."\n";
        print $FD '<p>'."\n";
        print $FD 'Open <a href="custom.files" target="_blank">';
        print $FD 'Custom sync source file</a>.'."\n";
        print $FD '</p>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
        foreach my $type (sort keys %json) {
            #==========================================
            # Run only with data
            #------------------------------------------
            my $tree = $json{$type};
            next if ! $tree;
            #==========================================
            # Setup title and outfile
            #------------------------------------------
            my $file;
            my $title;
            if ($type eq 'binaries') {
                $file = "$dest/report-binary.html";
                $title = "Custom OS binary data report";
            } elsif ($type eq 'modified') {
                $file = "$dest/report-modified.html";
                $title = "RPM modified files data report";
            } elsif ($type eq 'homes') {
                $file = "$dest/report-homes.html";
                $title = "Custom user data report";
            } else {
                $file = "$dest/report-text.html";
                $title = "Custom OS text data report";
            }
            #==========================================
            # Start D3 report
            #------------------------------------------
            my $JD = FileHandle -> new();
            if (! $JD -> open (">$file")) {
                $kiwi -> failed ();
                $kiwi -> error  ("Couldn't create report: $!");
                $kiwi -> failed ();
                return;
            }
            print $JD '<!DOCTYPE html>'."\n";
            print $JD '<html>'."\n";
            print $JD '<head>'."\n";
            print $JD "<meta http-equiv=\"Content-Type\"";
            print $JD " content=\"text/html;charset=utf-8\"/>"."\n";
            print $JD '<title>'.$title.'</title>'."\n";
            #==========================================
            # CSS
            #------------------------------------------
            print $JD '<link type="text/css" rel="stylesheet"';
            print $JD ' href=".report/d3/style.css"/>'."\n";
            print $JD '<link type="text/css" rel="stylesheet"';
            print $JD ' href=".report/d3/kiwi.css">'."\n";
            #==========================================
            # Java Script
            #------------------------------------------
            print $JD '<script type="text/javascript"';
            print $JD ' src=".report/d3/d3.js"></script>'."\n";
            print $JD '<script type="text/javascript"';
            print $JD ' src=".report/d3/d3.layout.js"></script>'."\n";
            print $JD '<script type="text/javascript"';
            print $JD ' src=".report/d3/kiwi.js"></script>'."\n";
            print $JD '</head>'."\n";
            #==========================================
            # Title
            #------------------------------------------
            print $JD '<body class="files">'."\n";
            print $JD '<div class="headerwrap">'."\n";
            print $JD '<div class="container"><h1>'.$title.'</h1></div>'."\n";
            print $JD '</div>'."\n";
            #==========================================
            # Chapters
            #------------------------------------------
            print $JD '<div class="container">'."\n";
            #==========================================
            # Intro
            #------------------------------------------
            print $JD '<p>'."\n";
            if ($type eq 'binaries') {
                print $JD 'The visualisation of the data below shows ';
                print $JD 'the custom OS binary data tree.'."\n";
            } elsif ($type eq 'modified') {
                print $JD 'The visualisation of the data below shows ';
                print $JD 'the RPM modified files data tree.'."\n";
            } elsif ($type eq 'homes') {
                print $JD 'The visualisation of the data below shows ';
                print $JD 'the custom user data tree.'."\n";
            } else {
                print $JD 'The visualisation of the data below shows ';
                print $JD 'the custom OS text data tree.'."\n";
            }
            print $JD '</p>'."\n";
            print $JD '<div id="body" class="container">'."\n";
            print $JD '<script type="text/javascript">'."\n";
            print $JD 'var m = [20, 120, 20, 120],'."\n";
            print $JD 'w = 1280 - m[1] - m[3],'."\n";
            print $JD "\t".'h = 800  - m[0] - m[2],'."\n";
            print $JD "\t".'i = 0,'."\n";
            print $JD "\t".'root;'."\n";
            print $JD 'var tree = d3.layout.tree()'."\n";
            print $JD "\t".'.size([h, w]);'."\n";
            print $JD 'var diagonal = d3.svg.diagonal()'."\n";
            print $JD "\t".'.projection(function(d) {return [d.y,d.x];});'."\n";
            print $JD 'var vis = d3.select("#body").append("svg:svg")'."\n";
            print $JD "\t".'.attr("width", w + m[1] + m[3])'."\n";
            print $JD "\t".'.attr("height", h + m[0] + m[2])'."\n";
            print $JD "\t".'.append("svg:g")'."\n";
            print $JD "\t".'.attr("transform","translate("+m[3]+","+m[0]+")");';
            print $JD "\n";
            print $JD 'd3.inplace = function(callback) {'."\n";
            print $JD "\t".'var myJSONObject = '.$tree.';';
            print $JD "\n";
            print $JD "\t".'callback(myJSONObject);'."\n";
            print $JD '};'."\n";
            print $JD 'd3.inplace(function(json) {'."\n";
            print $JD "\t".'root = json;'."\n";
            print $JD "\t".'root.x0 = h / 2;'."\n";
            print $JD "\t".'root.y0 = 0;'."\n";
            print $JD "\t".'function toggleAll(d) {'."\n";
            print $JD "\t\t".'if (d.children) {'."\n";
            print $JD "\t\t".'d.children.forEach(toggleAll);'."\n";
            print $JD "\t\t".'toggle(d);'."\n";
            print $JD "\t\t".'}'."\n";
            print $JD "\t".'}'."\n";
            print $JD "\t".'root.children.forEach(toggleAll);'."\n";
            print $JD "\t".'update(root);'."\n";
            print $JD '});'."\n";
            print $JD '</script>'."\n";
            print $JD '</div>'."\n";
            print $JD '</div>'."\n";
            print $JD '</body>'."\n";
            print $JD '</html>'."\n";
            $JD -> close();
        }
        print $FD '<div class="infoPanel">'."\n";
        print $FD '<a name="custom-files-visualisation"></a>'."\n";
        print $FD '<h1>Custom files visualisation</h1>'."\n";
        print $FD '<div class="panel-wraper">'."\n";
        print $FD '<p>'."\n";
        print $FD 'For a better overview the following data reports ';
        print $FD 'were created';
        print $FD '</p>'."\n";
        print $FD '<table>'."\n";
        foreach my $type (sort keys %json) {
            my $title;
            my $link;
            my $file;
            if ($type eq 'binaries') {
                $file = "$dest/report-binary.html";
                $title = "Custom OS binary data";
                $link = "Open <a href=\"report-binary.html\" ";
                $link.= "target=\"_blank\"> Report</a>.";
            } elsif ($type eq 'modified') {
                $file = "$dest/report-modified.html";
                $title = "RPM modified files";
                $link = "Open <a href=\"report-modified.html\" ";
                $link.= "target=\"_blank\"> Report</a>.";
            } elsif ($type eq 'homes') {
                $file = "$dest/report-homes.html";
                $title = "Custom user data";
                $link = "Open <a href=\"report-homes.html\" ";
                $link.= "target=\"_blank\"> Report</a>.";
            } else {
                $file = "$dest/report-text.html";
                $title = "Custom OS text data";
                $link = "Open <a href=\"report-text.html\" ";
                $link.= "target=\"_blank\"> Report</a>.";
            }
            if (($file) && (-f $file)) {
                print $FD '<tr valign="top">'."\n";
                print $FD '<td>'."$title".'</td>'."\n";
                print $FD '<td>'.$link.'</td>'."\n";
                print $FD '</tr>'."\n";
            }
        }
        print $FD '</table>'."\n";
        print $FD '</div>'."\n";
        print $FD '</div>'."\n";
    }
    print $FD '</div>'."\n";
    print $FD '<div class="footer container">'."\n";
    print $FD "\t".'&copy; 2012 SUSE Linux Products GmbH.'."\n";
    print $FD '</div>'."\n";
    print $FD '</body>'."\n";
    print $FD '</html>'."\n";
    $FD -> close();
    #==========================================
    # Print report note...
    #------------------------------------------
    $kiwi -> info ("--> Created report: file://$dest/report.html\n");
    my $locator = KIWILocator -> instance();
    my $git = $locator -> getExecPath ("git");
    if ($git) {
        $kiwi -> info ("--> Clone this system description with:\n");
        if ($ip) {
            $kiwi -> note ("\n\tgit clone root\@$ip:$dest\n\n");
        } else {
            $kiwi -> note ("\n\tgit clone root\@<ip-address>:$dest\n\n");
        }
    }
    return $this;
}

1;
