#================
# FILE          : KIWIMigrate.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
package KIWIMigrate;
#==========================================
# Modules
#------------------------------------------
use strict;
use Carp qw (cluck);
use XML::LibXML;
use File::Find;
use File::stat;
use File::Basename;
use File::Path;
use File::Copy;
use Storable;
use File::Spec;
use Fcntl ':mode';
use Cwd qw (abs_path cwd);
#==========================================
# KIWI Modules
#------------------------------------------
use KIWILog;
use KIWIQX qw (qxx);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIMigrate object which is used to gather
	# information on the running system 
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
	my $kiwi = shift;
	my $dest = shift;
	my $name = shift;
	my $excl = shift;
	my $skip = shift;
	my $addr = shift;
	my $addt = shift;
	my $adda = shift;
	my $addp = shift;
	my $fnr  = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $code;
	my $data;
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
	}
	if (! defined $name) {
		$kiwi -> failed ();
		$kiwi -> error  ("No image name for migration given");
		$kiwi -> failed ();
		return;
	}
	$this->{gdata} = $main::global -> getGlobals();
	my $product = $this -> getOperatingSystemVersion();
	if (! defined $product) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find system version information");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> note (" [$product]");
	if (defined $fnr) {
		qxx ("rm -rf $dest");
	}
	if (! defined $dest) {
		$dest = qxx (" mktemp -q -d /tmp/kiwi-migrate.XXXXXX ");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create destination dir: $!");
			$kiwi -> failed ();
			return;
		}
		chomp $dest;
	} elsif (-d $dest) {
		$kiwi -> done ();
		$kiwi -> info ("Using already existing destination dir");
	} else {
		$data = qxx ("mkdir $dest 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create destination dir: $data");
			$kiwi -> failed ();
			return;
		}
	}
	$dest =~ s/\/$//;
	$kiwi -> done ();
	$kiwi -> info ("Results will be written to: $dest");
	$kiwi -> done ();
	#==========================================
	# Store addon repo information if specified
	#------------------------------------------
	my %OSSource;
	if ((defined $addr) && (defined $addt)) {
		my @addrepo     = @{$addr};
		my @addrepotype = @{$addt};
		my @addrepoalias= @{$adda};
		my @addrepoprio = @{$addp};
		foreach (my $count=0;$count <@addrepo; $count++) {
			my $source= $addrepo[$count];
			my $type  = $addrepotype[$count];
			my $alias = $addrepoalias[$count];
			my $prio  = $addrepoprio[$count];
			$OSSource{$product}{$source}{type} = $type;
			$OSSource{$product}{$source}{alias}= $alias;
			$OSSource{$product}{$source}{prio} = $prio;
		}
	}
	#==========================================
	# Store default files not used for inspect
	#------------------------------------------
	my @denyFiles = (
		'\.rpmnew',                     # no RPM backup files
		'\.rpmsave',                    # []
		'\.rpmorig',                    # []
		'\.cache',                      # no cache files
		'~$',                           # no emacs backup files
		'\.swp$',                       # no vim backup files
		'\.rej$',                       # no diff reject files
		'\.lock$',                      # no lock files
		'\.tmp$',                       # no tmp files
		'\/etc\/gconf\/',               # no gconf files
		'\.depend$',                    # no make depend targets
		'\.backup$',                    # no sysconfig backup files
		'\.gz',                         # no gzip archives
		'\/usr\/src\/',                 # no sources
		'\/spool',                      # no spool directories
		'^\/dev\/',                     # no device node files
		'\/usr\/X11R6\/',               # no depreciated dirs
		'\/tmp',                        # no /tmp data
		'\/boot\/',                     # no /boot data
		'\/proc\/',                     # no /proc data
		'\/sys\/',                      # no /sys data
		'\/abuild\/',                   # no /abuild data
		'\/fillup-templates',           # no fillup data
		'\/var\/lib\/rpm',              # no RPM data
		'\/var\/lib\/zypp',             # no ZYPP data
		'\/var\/lib\/smart',            # no smart data
		'\/var\/lock\/',                # no locks
		'\/var\/adm\/',                 # no var/adm
		'\/var\/yp\/',                  # no yp files
		'\/var\/lib\/',                 # no var/lib
		'\/usr\/include\/',             # no header changes
		'\/usr\/share/fonts\/',         # no font cache
		'\/usr\/share/fonts-config\/',  # no font config
		'\/usr\/share/locale-bundle\/', # no locale bundle
		'\/usr\/share/sax\/',           # no sax data
		'\/var\/log',                   # no logs
		'\/var\/run',                   # no pid files
		'\/etc\/fstab',                 # no fstab file
		'\/etc\/udev\/rules.d',         # no udev rules
		'\/media\/',                    # no media automount files
		'\/lost\+\/found',              # no filesystem specific files
		'\/var\/lib\/hardware\/',       # no hwinfo hardware files
		'\/var\/cache\/',               # no cache files
		'\/var\/db\/',                  # no db caches
		'\/usr\/share\/doc\/',          # no documentation
		'\/ruby\/gems\/.*\/doc\/',      # no ruby gem documentation
		'\/usr\/share\/mime\/',         # no mime types
		'\/lost\+found',                # no fs inode backup
		'\/icons',                      # no icon directories
		'\/etc\/bootsplash',            # no splash data
		'\/etc\/lvm',                   # no lvm meta data
		'\/etc\/grub.conf',             # no bootloader config
		'\.old$',                       # no .old files
		'\/weak-updates'                # no weak-update links
	);
	if (defined $excl) {
		my @exclude = @{$excl};
		foreach (@exclude) {
			$_ =~ s/\/$//;
			$_ = quotemeta;
		};
		push @denyFiles,@exclude;
	}
	#==========================================
	# Store default packages to skip
	#------------------------------------------
	my @denyPacks = (
		'gpg-pubkey.*'
	);
	foreach my $s (@denyPacks) {
		push (@{$skip},$s);
	}
	#==========================================
	# Setup autoyast clone module names
	#------------------------------------------
	my @autoyastCloneList = qw (
		firewall users host kerberos language networking
		nis ntp-client printer proxy runlevel
		samba-client security sound suse_register
		timezone add-on routing
	);
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}    = $kiwi;
	$this->{deny}    = \@denyFiles;
	$this->{skip}    = $skip;
	$this->{dest}    = $dest;
	$this->{name}    = $name;
	$this->{source}  = \%OSSource;
	$this->{product} = $product;
	$this->{mount}   = [];
	$this->{autoyastCloneList} = \@autoyastCloneList;
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
	my $this       = shift;
	my $kiwi       = $this->{kiwi};
	my $dest       = $this->{dest};
	my $problem1   = $this->{solverProblem1};
	my $problem2   = $this->{solverProblem2};
	my $failedJob1 = $this->{solverFailedJobs1};
	my $failedJob2 = $this->{solverFailedJobs2};
	my $nopackage  = $this->{nopackage};
	my $repos      = $this->{repos};
	my $twice      = $this->{twice};
	#==========================================
	# Beautify report...
	#------------------------------------------
	mkdir "$dest/.report";
	qxx ("tar -C $dest/.report -xf $this->{gdata}->{KMigraCSS} 2>&1");
	#==========================================
	# Start report
	#------------------------------------------
	my $FD;
	if (! open ($FD, '>', "$dest/report.html")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create report: $!");
		$kiwi -> failed ();
		return;
	}
	print $FD '<!DOCTYPE html>'."\n";
	print $FD '<html>'."\n";
	print $FD "\t".'<head>'."\n";
	print $FD "\t\t".'<title>Migration report</title>'."\n";
	print $FD "\t\t".'<!--[if lt IE 9]>'."\n";
	print $FD "\t\t".'<script src="';
	print $FD 'http://html5shiv.googlecode.com/svn/trunk/html5.js">';
	print $FD '</script>'."\n";
	print $FD "\t\t".'<![endif]-->'."\n";
	print $FD "\t\t".'<link rel="stylesheet" type="text/css" ';
	print $FD 'href=".report/css/kiwi.css">'."\n";
	print $FD "\t\t".'<script type="text/javascript" ';
	print $FD 'src=".report/js/jquery.min.js">';
	print $FD '</script>'."\n";
	print $FD "\t\t".'<script type="text/javascript" ';
	print $FD 'src=".report/js/data.js">';
	print $FD '</script>'."\n";
	print $FD "\t\t".'<script type="text/javascript" ';
	print $FD 'src=".report/js/kiwi.js">';
	print $FD '</script>'."\n";
	print $FD "\t".'</head>'."\n";
	print $FD '<body class="files">'."\n";
	print $FD '<div class="headerwrap">'."\n";
	print $FD "\t";
	print $FD '<div class="container"><h1>Migration report</h1></div>'."\n";
	print $FD '</div>'."\n";
	print $FD '<div class="container">'."\n";
	#==========================================
	# Kernel version report
	#------------------------------------------
	print $FD '<h1>Currently active kernel version</h1>'."\n";
	print $FD '<p>'."\n";
	print $FD 'The table below shows the packages required for the currently ';
	print $FD 'active kernel. If multiple kernels are installed make sure ';
	print $FD 'that the reported kernel package names are part of the ';
	print $FD 'image description';
	print $FD '</p>'."\n";
	print $FD '<hr>'."\n";
	print $FD '<table>'."\n";
	my @list = qxx (
		'rpm -qf --qf "%{NAME}:%{VERSION}\n" /lib/modules/$(uname -r)'
	); chomp @list;
	foreach my $item (sort @list) {
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
	#==========================================
	# Hardware dependent packages report
	#------------------------------------------
	my $pack;
	my %modalias;
	print $FD '<h1>Hardware dependent RPM packages </h1>'."\n";
	print $FD '<p>'."\n";
	print $FD 'The table below shows packages that depend on specific ';
	print $FD 'hardware Please note that it might be required to have a ';
	print $FD 'different set of hardware dependent packages included into the ';
	print $FD 'image description depending on the target hardware. If there ';
	print $FD 'is the need for such packages make sure you add them as follows';
	print $FD '<package name="name-of-package" bootinclude="true"/>';
	print $FD '</p>'."\n";
	print $FD '<hr>'."\n";
	print $FD '<table>'."\n";
	for (qxx ( "rpm -qa --qf '\n<%{name}>\n' --supplements" )) {
		chomp;
		$pack = $1 if /^<(.+)>/;
		push @{$modalias{$pack}}, $_ if /^modalias/;
	}
	foreach my $item (sort keys %modalias) {
		print $FD '<tr valign="top">'."\n";
		print $FD '<td>'.$item.'</td>'."\n";
		print $FD '</tr>'."\n";
	}
	print $FD '</table>'."\n";
	#==========================================
	# Local repository checkout(s)
	#------------------------------------------
	if ($repos) {
		print $FD '<h1>Local repository checkout paths </h1>'."\n";
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
		foreach my $repo (sort keys %{$repos}) {
			print $FD '<tr valign="top">'."\n";
			print $FD '<td>'.$repo.'</td>'."\n";
			print $FD '<td> type: '.$repos->{$repo}.'</td>'."\n";
			print $FD '</tr>'."\n";
		}
		print $FD '</table>'."\n";
	}
	#==========================================
	# GEM packages report
	#------------------------------------------
	if (-x "/usr/bin/gem") {
		my @gems;
		print $FD '<h1>Installed GEM packages </h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'The table below shows GEM packages installed locally. ';
		print $FD 'In order to migrate them correctly make sure you either ';
		print $FD 'have the corresponding rpm package for this gem in your ';
		print $FD 'kiwi packages list or implement a mechanism to let the ';
		print $FD 'gem package manager install this software ';
		print $FD '</p>'."\n";
		print $FD '<hr>'."\n";
		print $FD '<table>'."\n";
		for (qxx ( "gem list --local" )) {
			chomp;
			push (@gems,$_);
		}
		foreach my $item (sort @gems) {
			print $FD '<tr valign="top">'."\n";
			print $FD '<td>'.$item.'</td>'."\n";
			print $FD '</tr>'."\n";
		}
		print $FD '</table>'."\n";
	}
	#==========================================
	# Package/Pattern report
	#------------------------------------------
	if ($twice) {
		my @pacs = @{$twice};
		print $FD '<h1>RPM Package(s) installed multiple times</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'The following packages are installed multiple times. ';
		print $FD 'Please uninstall the old versions of the packages ';
		print $FD 'and re-run the migration. ';
		print $FD '</p>'."\n";
		print $FD '<hr>'."\n";
		print $FD '<table>'."\n";
		my @list = qxx ("rpm -q @pacs --last"); chomp @list;
		foreach my $job (sort @list) {
			if ($job =~ /([^\s]+)\s+([^\s].*)/) {
				my $pac  = $1;
				my $date = $2;
				print $FD '<tr valign="top">'."\n";
				print $FD '<td>'.$pac.'</td>'."\n";
				print $FD '<td>'.$date.'</td>'."\n";
				print $FD '</tr>'."\n";
			}
		}
		print $FD '</table>'."\n";
	}
	if ($problem1) {
		print $FD '<h1>Pattern conflict(s) by zypper</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'The following patterns could not be solved because ';
		print $FD 'they have dependency conflicts. Please check the list ';
		print $FD 'and solve the conflicts by either: ';
		print $FD "\n";
		print $FD '<ul>'."\n";
		print $FD '<li>'."\n";
		print $FD 'Adding all software repositories to zypper which provide ';
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
	}
	if ($problem2) {
		print $FD '<h1>RPM Package conflict(s)</h1>'."\n";
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
	}
	if (($failedJob1) && (@{$failedJob1})) {
		print $FD '<h1>Pattern(s) not found by zypper</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'The following patterns could not be found in your ';
		print $FD 'repository list marked as installed. Please check the ';
		print $FD 'list and solve the problem by either: ';
		print $FD "\n";
		print $FD '<ul>'."\n";
		print $FD '<li>'."\n";
		print $FD 'Adding a repository to zypper which provides the ';
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
	}
	if (($failedJob2) && (@{$failedJob2})) {
		print $FD '<h1>RPM Package(s) not found</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'The following packages could not be found in your ';
		print $FD 'repository list but are installed on the system ';
		print $FD 'Please check the list and solve the problem by ';
		print $FD 'either:';
		print $FD "\n";
		print $FD '<ul>'."\n";
		print $FD '<li>'."\n";
		print $FD 'Adding a repository to zypper which provides the ';
		print $FD 'package, or';
		print $FD "\n";
		print $FD '</li>'."\n";
		print $FD '<li>'."\n";
		print $FD 'Ignoring the package. If you ignore the package, your ';
		print $FD 'software selection might not be part of your final ';
		print $FD 'image. Also, if you ignore a package which contains ';
		print $FD 'files modified in the system, kiwi will store the ';
		print $FD 'modified files inside the overlay tree. This means your ';
		print $FD 'image might contain files from the ignored package but ';
		print $FD 'they are most likely not useful without the full ';
		print $FD 'package installed.';
		print $FD "\n";
		print $FD '</li>'."\n";
		print $FD '</ul>'."\n";
		print $FD '</p>'."\n";
		print $FD '<hr>'."\n";
		print $FD '<table>'."\n";
		my @pacs = @{$failedJob2};
		my @list = qxx ("rpm -q @pacs --last"); chomp @list;
		foreach my $job (sort @list) {
			if ($job =~ /([^\s]+)\s+([^\s].*)/) {
				my $pac  = $1;
				my $date = $2;
				my @rpm  = qxx (
					'rpm -q --qf "%{distribution}\n%{disturl}\n%{url}\n" '.$pac
				); chomp @rpm;
				my $distro  = $rpm[0];
				my $disturl = $rpm[1];
				my $srcurl  = $rpm[2];
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
		}
		print $FD '</table>'."\n";
	}
	#==========================================
	# Modified files report...
	#------------------------------------------
	if ($nopackage) {
		print $FD '<h1>Overlay files</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'Behind the current overlay files directory you will ';
		print $FD 'find the packaged but modified files and also a ';
		print $FD 'collection of files which seems to be required for ';
		print $FD 'this system. Please check the current tree ';
		print $FD 'and take the same rules as for the unpackaged files ';
		print $FD 'mentioned in the next section into account. ';
		print $FD '</p>'."\n";
		print $FD '<div>'."\n";
		print $FD 'See <a href="'.$dest.'/root">Overlay directory</a>.'."\n";
		print $FD '</div>'."\n";

		print $FD '<h1>Unpackaged files</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'Behind the current custom files directory you will ';
		print $FD 'find files/directories which are not part of any packages.';
		print $FD 'For binary files, including executables and libraries, ';
		print $FD 'you should try to find and include a package that ';
		print $FD 'provides them. If there are no package providers for ';
		print $FD 'this file, you can leave them as overlay files, but it ';
		print $FD 'may cause problems like broken dependencies later. ';
		print $FD 'After that, you should look for personal files like ';
		print $FD 'pictures, movies, etc. and remove them if ';
		print $FD 'they can be easily restored in the later image. ';
		print $FD 'Move all of the files you want to be part of the ';
		print $FD 'image into the '.$dest.'/root directory.'."\n";
		print $FD '</p>'."\n";
		print $FD '<div>'."\n";
		print $FD 'See <a href="'.$dest.'/custom">Custom directory</a>.'."\n";
		print $FD '</div>'."\n";
	}
	print $FD '</div>'."\n";
	print $FD '<div class="footer container">'."\n";
	print $FD "\t".'&copy; 2012 SuSE Linux Products GmbH.'."\n";
	print $FD '</div>'."\n";
	print $FD '</body>'."\n";
	print $FD '</html>'."\n";
	close $FD;
	#==========================================
	# Print report note...
	#------------------------------------------
	$kiwi -> info ("--> Please check the migration report !!\n");
	$kiwi -> note ("\n\tfile://$dest/report.html\n\n");
	return $this;
}

#==========================================
# generateWanted
#------------------------------------------
sub generateWanted {
	my $filehash = shift;
	return sub {
		my $file = $File::Find::name;
		my $dirn = $File::Find::dir;
		my $attr;
		if (-d $file) {
			$attr = stat ($file);
			# dont follow directory links and nfs locations...
			if (($attr->dev < 0x100) || (-l $file)) {
				$File::Find::prune = 1;
			} else {
				$filehash->{$file} = [$dirn,$attr];
			}
		} else {
			if (-l $file) {
				$attr = lstat ($file);
			} else {
				$attr = stat ($file);
			}
			$filehash->{$file} = [$dirn,$attr];
		}
	}
}

#==========================================
# getRepos
#------------------------------------------
sub getRepos {
	# ...
	# use zypper defined repositories as setup for the
	# migration
	# ---
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my %osc     = %{$this->{source}};
	my $product = $this->{product};
	my $mounts  = $this->{mount};
	my @list    = qxx ("zypper lr --details 2>&1");	chomp @list;
	my $code    = $? >> 8;
	if ($code != 0) {
		return;
	}
	foreach my $repo (@list) {
		$repo =~ s/^\s+//g;
		if ($repo =~ /^\d.*\|(.*)\|.*\|(.*)\|.*\|(.*)\|(.*)\|(.*)\|/) {
			my $enabled = $2;
			my $source  = $5;
			my $type    = $4;
			my $alias   = $1;
			my $prio    = $3;
			$enabled =~ s/^ +//; $enabled =~ s/ +$//;
			$source  =~ s/^ +//; $source  =~ s/ +$//;
			$type    =~ s/^ +//; $type    =~ s/ +$//;
			$alias   =~ s/^ +//; $alias   =~ s/ +$//; $alias =~ s/ $/-/g;
			$prio    =~ s/^ +//; $prio    =~ s/ +$//;
			my $origsrc = $source;
			if ($enabled eq "Yes") {
				#==========================================
				# handle special source type dvd://
				#------------------------------------------
				if ($source =~ /^dvd:/) {
					if (! -e "/dev/dvd") {
						$kiwi -> warning ("DVD repo: /dev/dvd does not exist");
						$kiwi -> skipped ();
						next;
					}
					my $mpoint = qxx ("mktemp -q -d /tmp/kiwimpoint.XXXXXX");
					my $result = $? >> 8;
					if ($result != 0) {
						$kiwi -> warning ("DVD tmpdir failed: $mpoint: $!");
						$kiwi -> skipped ();
						next;
					}
					chomp $mpoint;
					my $data = qxx ("mount /dev/dvd $mpoint 2>&1");
					my $code = $? >> 8;
					if ($code != 0) {
						$kiwi -> warning ("DVD mount failed: $data");
						$kiwi -> skipped ();
						next;
					}
					$source = "dir://".$mpoint;
					push @{$mounts},$mpoint;
					$osc{$product}{$source}{flag} = "local";
				}
				#==========================================
				# handle special source type iso://
				#------------------------------------------
				elsif ($source =~ /iso=(.*\.iso)/) {
					my $iso = $1;
					if (! -e $iso) {
						$kiwi -> warning ("ISO repo: $iso does not exist");
						$kiwi -> skipped ();
						next;
					}
					my $mpoint = qxx ("mktemp -q -d /tmp/kiwimpoint.XXXXXX");
					my $result = $? >> 8;
					if ($result != 0) {
						$kiwi -> warning ("ISO tmpdir failed: $mpoint: $!");
						$kiwi -> skipped ();
						next;
					}
					chomp $mpoint;
					my $data = qxx ("mount -o loop $iso $mpoint 2>&1");
					my $code = $? >> 8;
					if ($code != 0) {
						$kiwi -> warning ("ISO loop mount failed: $data");
						$kiwi -> skipped ();
						next;
					}
					$source = "dir://".$mpoint;
					push @{$mounts},$mpoint;
					$osc{$product}{$source}{flag} = "local";
				}
				#==========================================
				# handle source type http|https|ftp://
				#------------------------------------------
				elsif ($source =~ /^(http|https|ftp)/) {
					$osc{$product}{$source}{flag} = "remote";
				}
				#==========================================
				# handle all other source types
				#------------------------------------------
				else {
					$osc{$product}{$source}{flag} = "unknown";
				}
				#==========================================
				# store repo information
				#------------------------------------------
				$osc{$product}{$source}{src}  = $origsrc;
				$osc{$product}{$source}{type} = $type;
				$osc{$product}{$source}{alias}= $alias;
				$osc{$product}{$source}{prio} = $prio;
			}
		}
	}
	$this->{source} = \%osc;
	return $this;
}

#==========================================
# setTemplate
#------------------------------------------
sub setTemplate {
	# ...
	# create basic image description structure and files
	# ---
	my $this    = shift;
	my $dest    = $this->{dest};
	my $name    = $this->{name};
	my $kiwi    = $this->{kiwi};
	my $product = $this->{product};
	my $pats    = $this->{patterns};
	my $pacs    = $this->{packages};
	my %osc     = %{$this->{source}};
	#==========================================
	# create xml description
	#------------------------------------------
	my $FD;
	if (! open ($FD, '>', "$dest/$this->{gdata}->{ConfigName}")) {
		return;
	}
	#==========================================
	# <description>
	#------------------------------------------
	print $FD '<image schemaversion="5.3" ';
	print $FD 'name="suse-migration-'.$product.'">'."\n";
	print $FD "\t".'<description type="system">'."\n";
	print $FD "\t\t".'<author>***AUTHOR***</author>'."\n";
	print $FD "\t\t".'<contact>***MAIL***</contact>'."\n";
	print $FD "\t\t".'<specification>'.$product.'</specification>'."\n";
	print $FD "\t".'</description>'."\n";
	#==========================================
	# <preferences>
	#------------------------------------------
	print $FD "\t".'<preferences>'."\n";
	print $FD "\t\t".'<type image="oem" boot="oemboot/'.$product.'"';
	print $FD ' filesystem="ext3" installiso="true">'."\n";
	print $FD "\t\t\t".'<oemconfig/>'."\n";
	print $FD "\t\t".'</type>'."\n";
	print $FD "\t\t".'<version>1.1.1</version>'."\n";
	print $FD "\t\t".'<packagemanager>zypper</packagemanager>'."\n";
	print $FD "\t\t".'<locale>en_US</locale>'."\n";
	print $FD "\t\t".'<keytable>us.map.gz</keytable>'."\n";
	print $FD "\t\t".'<timezone>Europe/Berlin</timezone>'."\n";
	print $FD "\t\t".'<bootloader-theme>openSUSE</bootloader-theme>'."\n";
	print $FD "\t\t".'<bootsplash-theme>openSUSE</bootsplash-theme>'."\n";
	print $FD "\t".'</preferences>'."\n";
	#==========================================
	# <repository>
	#------------------------------------------
	foreach my $source (keys %{$osc{$product}} ) {
		my $type = $osc{$product}{$source}{type};
		my $alias= $osc{$product}{$source}{alias};
		my $prio = $osc{$product}{$source}{prio};
		my $url  = $osc{$product}{$source}{src};
		print $FD "\t".'<repository type="'.$type.'"';
		if (defined $alias) {
			print $FD ' alias="'.$alias.'"';
		}
		if ((defined $prio) && ($prio != 0)) {
			print $FD ' priority="'.$prio.'"';
		}
		print $FD '>'."\n";
		print $FD "\t\t".'<source path="'.$url.'"/>'."\n";
		print $FD "\t".'</repository>'."\n";
	}
	#==========================================
	# <packages>
	#------------------------------------------
	print $FD "\t".'<packages type="bootstrap" patternType="plusRecommended">';
	print $FD "\n";
	if (defined $pats) {
		# FIXME: I don't have a solution for the problem below
		# /.../
		# the migration put a set of packages to matching patterns
		# I found out that it might be a problem if a pattern provides
		# more than one package for the same purpose. In that case
		# the preferred package is installed but this might not be
		# the package which is currently used on the system. A good
		# example here is postfix vs. sendmail. kiwi will find
		# postfix to belong to a pattern. in fact it's provided by
		# the pattern mail_server. This pattern provides postfix
		# and sendmail. If only mail_server as pattern is requested,
		# sendmail will be selected and not postfix
		# ---
		foreach my $pattern (sort @{$pats}) {
			$pattern =~ s/^pattern://;
			print $FD "\t\t".'<opensusePattern name="'.$pattern.'"/>'."\n";
		}
	}
	if (defined $pacs) {
		foreach my $package (sort @{$pacs}) {
			print $FD "\t\t".'<package name="'.$package.'"/>'."\n";
		}
	}
	print $FD "\t".'</packages>'."\n";
	print $FD '</image>'."\n";
	close $FD;
	return $this;
}

#==========================================
# getOperatingSystemVersion
#------------------------------------------
sub getOperatingSystemVersion {
	# ...
	# Find the version information of this system according
	# to the table KIWIMigrate.txt
	# ---
	my $this = shift;
	my $FD;
	if (! open ($FD, '<', "/etc/SuSE-release")) {
		return;
	}
	my $name = <$FD>; chomp $name;
	my $vers = <$FD>; chomp $vers;
	my $plvl = <$FD>; chomp $plvl;
	$name =~ s/\s+/-/g;
	$name =~ s/\-\(.*\)//g;
	if ((defined $plvl) && ($plvl =~ /PATCHLEVEL = (.*)/)) {
		$plvl = $1;
		if ($plvl > 0) {
			$name = $name."-SP".$plvl;
		}
	}
	close $FD;
	if (! open ($FD, '<', $this->{gdata}->{KMigrate})) {
		return;
	}
	while (my $line = <$FD>) {
		next if $line =~ /^#/;
		if ($line =~ /(.*)\s*=\s*(.*)/) {
			my $product= $1;
			my $boot   = $2;
			if ($product eq $name) {
				close $FD;
				return $boot;
			}
		}
	}
	close $FD;
	return;
}

#==========================================
# setPrepareConfigSkript
#------------------------------------------
sub setPrepareConfigSkript {
	# ...
	# Find all services enabled on the system and create
	# an appropriate config.sh file
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $dest = $this->{dest};
	my %osc  = %{$this->{source}};
	my $product = $this->{product};
	#==========================================
	# create config script
	#------------------------------------------
	my $FD;
	if (! open ($FD, '>', "$dest/config.sh")) {
		return;
	}
	print $FD '#!/bin/bash'."\n";
	print $FD 'test -f /.kconfig && . /.kconfig'."\n";
	print $FD 'test -f /.profile && . /.profile'."\n";
	print $FD 'echo "Configure image: [$kiwi_iname]..."'."\n";
	print $FD 'suseSetupProduct'."\n";
	#==========================================
	# Services...
	#------------------------------------------
	my @serviceList;
	my @slist = qxx ('chkconfig -l | grep :on'); chomp @slist;
	my $code = $? >> 8;
	if ($code == 0) {
		foreach my $line (@slist) {
			my ($name) = split(/\s+/,$line);
			push (@serviceList,$name);
		}
	}
	if (@serviceList) {
		foreach my $service (@serviceList) {
			print $FD "suseInsertService '$service'"."\n";
		}
	}
	#==========================================
	# Repos...
	#------------------------------------------
	foreach my $source (keys %{$osc{$product}} ) {
		my $alias= $osc{$product}{$source}{alias};
		my $url  = $osc{$product}{$source}{src};
		my $flag = $osc{$product}{$source}{flag};
		if ($flag ne "remote") {
			# $kiwi -> warning (
			#	"Local repo: $alias will not be added to config.sh"
			# );
			# $kiwi -> skipped ();
			next;
		}
		print $FD "zypper ar \\\n\t\"".$url."\" \\\n\t\"".$alias."\"\n";
	}
	#==========================================
	# Product repo...
	#------------------------------------------
	my $repoProduct = "/etc/products.d/openSUSE.prod";
	if (-e $repoProduct) {
		my $PXML;
		if (! open ($PXML, '-|', "cat $repoProduct")) {
			$kiwi -> failed ();
			$kiwi -> warning ("--> Failed to open product file $repoProduct");
			$kiwi -> skipped ();
		} else {
			binmode $PXML;
			my $pxml = new XML::LibXML;
			my $tree = $pxml -> parse_fh ( $PXML );
			my $urls = $tree -> getElementsByTagName ("product")
				-> get_node(1) -> getElementsByTagName ("urls")
				-> get_node(1) -> getElementsByTagName ("url");
			for (my $i=1;$i<= $urls->size();$i++) {
				my $node = $urls -> get_node($i);
				my $name = $node -> getAttribute ("name");
				if ($name eq "repository") {
					my $url   = $node -> textContent();
					my $alias = "openSUSE";
					my $alreadyThere = 0;
					$url =~ s/\/$//;
					foreach my $source (keys %{$osc{$product}} ) {
						my $curl = $osc{$product}{$source}{src};
						$curl =~ s/\/$//;
						if ($curl eq $url) {
							$alreadyThere = 1; last;
						}
					}
					if (! $alreadyThere) {
						print $FD "zypper ar \\\n\t\"";
						print $FD $url."\" \\\n\t\"".$alias."\"\n";
					}
				}
			}
			close $PXML;
		}
	}
	print $FD 'suseConfig'."\n";
	print $FD 'baseCleanMount'."\n";
	print $FD 'exit 0'."\n";
	close $FD;
	chmod 0755, "$dest/config.sh";
	return $this;
}

#==========================================
# getPackageList
#------------------------------------------
sub getPackageList {
	# ...
	# Find all packages installed on the system which doesn't
	# belong to any of the installed patterns. This method
	# requires a SUSE system based on zypper and rpm to work
	# correctly
	# ---
	my $this    = shift;
	my $product = $this->{product};
	my $kiwi    = $this->{kiwi};
	my $skip    = $this->{skip};
	my $dest    = $this->{dest};
	my %osc     = %{$this->{source}};
	my @urllist = ();
	my @patlist = ();
	my @ilist   = ();
	my $code;
	#==========================================
	# clean pattern/package lists
	#------------------------------------------
	undef $this->{patterns};
	undef $this->{packages};
	#==========================================
	# search installed packages if not yet done
	#------------------------------------------
	if ($this->{ilist}) {
		@ilist = @{$this->{ilist}};
	} else {
		$kiwi -> info ("Searching installed packages...");
		@ilist = qxx ('rpm -qa --qf "%{NAME}\n" | sort'); chomp @ilist;
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to obtain installed packages");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# find packages installed n times n > 1
	#------------------------------------------
	my %packages = ();
	my @twice = ();
	for (my $i=0;$i<@ilist;$i++) {
		my $p = $ilist[$i];
		my $inskip = 0;
		foreach my $s (@{$skip}) {
			if ($p =~ /$s/) {
				$inskip = 1; last;
			}
		}
		next if $inskip;
		$packages{$p}++;
	}
	foreach my $installed (keys %packages) {
		if ($packages{$installed} > 1) {
			my @list = qxx ("rpm -q $installed"); chomp @list;
			push @twice,@list;
		}
	}
	if (@twice) {
		$this->{twice} = \@twice;
	}
	#==========================================
	# use uniq pac list for further processing
	#------------------------------------------
	@ilist = sort keys %packages;
	#==========================================
	# create URL list to lookup solvables
	#------------------------------------------
	foreach my $source (keys %{$osc{$product}}) {
		push (@urllist,$source);
	}
	#==========================================
	# find all patterns and packs of patterns 
	#------------------------------------------
	if (@urllist) {
		$kiwi -> info ("Creating System solvable from active repos...\n");
		my @list = qxx ("zypper -n --no-refresh patterns --installed 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to obtain installed patterns");
			$kiwi -> failed ();
			return;
		} else {
			my %pathash = ();
			foreach my $line (@list) {
				if ($line =~ /^i.*\|(.*)\|.*\|.*\|/) {
					my $name = $1;
					$name =~ s/^ +//g;
					$name =~ s/ +$//g;
					$pathash{"pattern:$name"} = "$name";
				}
			}
			@patlist = keys %pathash;
		}
		$this->{patterns} = \@patlist;
		my $psolve = new KIWISatSolver (
			$kiwi,\@patlist,\@urllist,"solve-patterns",
			undef,undef,"plusRecommended","merged-solvable"
		);
		my @result = ();
		if (! defined $psolve) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to solve patterns");
			$kiwi -> failed ();
			return;
		}
		# /.../
		# solve the zypper pattern list into a package list and
		# create a package list with packages _not_ part of the
		# pattern list.
		# ----
		$this->{solverProblem1}    = $psolve -> getProblemInfo();
		$this->{solverFailedJobs1} = $psolve -> getFailedJobs();
		if ($psolve -> getProblemsCount()) {
			$kiwi -> warning ("Pattern problems found check in report !\n");
		}
		my @packageList = $psolve -> getPackages();
		foreach my $installed (@ilist) {
			if (defined $skip) {
				my $inskip = 0;
				foreach my $s (@{$skip}) {
					if ($installed =~ /$s/) {
						$inskip = 1; last;
					}
				}
				next if $inskip;
			}
			my $inpattern = 0;
			foreach my $p (@packageList) {
				if ($installed eq $p) {
					$inpattern = 1; last;
				}
			}
			if (! $inpattern) {
				push (@result,$installed);
			}
		}
		# /.../
		# walk through the non pattern based packages and solve
		# them again. packages which are not part of the base
		# repository will be ignored. This might be a problem
		# if the package comes from a non base repository.
		# The solved list is again checked with the pattern
		# package list and the result is returned
		# ----
		if (@result) {
			my @rest = ();
			my $pool = $psolve -> getPool();
			my $xsolve = new KIWISatSolver (
				$kiwi,\@result,\@urllist,"solve-packages",
				$pool,undef,"plusRecommended","merged-solvable"
			);
			if (! defined $xsolve) {
				$kiwi -> error  ("Failed to solve packages");
				$kiwi -> failed ();
				return;
			}
			$this->{solverProblem2}    = $xsolve -> getProblemInfo();
			$this->{solverFailedJobs2} = $xsolve -> getFailedJobs();
			if ($xsolve -> getProblemsCount()) {
				$kiwi -> warning ("Package problems found check in report !\n");
			}
			@result = $xsolve -> getPackages();
			foreach my $p (@result) {
				my $inpattern = 0;
				foreach my $tobeinstalled (@packageList) {
					if ($tobeinstalled eq $p) {
						$inpattern = 1; last;
					}
				}
				if (! $inpattern) {
					push (@rest,$p);
				}
			}
			$this->{packages} = \@rest;
		}
	}
	return $this;
}

#==========================================
# setSystemOverlayFiles
#------------------------------------------
sub setSystemOverlayFiles {
	# ...
	# 1) Find all files not owned by any package
	# 2) Find all files changed according to the package manager
	# 3) create linked list of the result
	# ---
	my $this   = shift;
	my $mounts = $this->{mount};
	my $dest   = $this->{dest};
	my $kiwi   = $this->{kiwi};
	my $rdev   = $this->{rdev};
	my @deny   = @{$this->{deny}};
	my $cache  = $dest.".cache";
	my $cdata;
	my $checkopt;
	my %result;
	my $data;
	my $code;
	my @modified;
	my $root = "/";
	#==========================================
	# check for cache file
	#------------------------------------------
	if (! -f $cache) {
		undef $cache;
	} else {
		$kiwi -> info ("=> Open cache file: $cache\n");
		$cdata = retrieve($cache);
		if (! $cdata) {
			$kiwi -> warning ("=> Failed to open cache file");
			$kiwi -> skipped ();
			undef $cache;
		} elsif (! $cdata->{version}) {
			$kiwi -> warning ("=> Cache doesn't provide version");
			$kiwi -> skipped ();
			undef $cache;
		} elsif ($cdata->{version} ne $this->{gdata}->{Version}) {
			$kiwi -> warning ("=> Cache version doesn't match");
			$kiwi -> skipped ();
			undef $cache;
		} else {
			$kiwi -> info ("=> Using cache file\n");
			$kiwi -> info ("=> Remove cache if your system has changed !!\n");
		}
	}
	#==========================================
	# Find files packaged but changed
	#------------------------------------------
	$kiwi -> info ("Inspecting RPM database [modified files]...");
	if ($cache) {
		@modified = @{$cdata->{modified}};
		$kiwi -> done(); 
	} else {
		$checkopt = "--nodeps --nodigest --nosignature --nomtime ";
		$checkopt.= "--nolinkto --nouser --nogroup --nomode";
		my @rpmcheck = qxx ("rpm -Va $checkopt"); chomp @rpmcheck;
		my $rpmsize = @rpmcheck;
		my $spart = 100 / $rpmsize;
		my $count = 1;
		my $done;
		my $done_old;
		$kiwi -> cursorOFF();
		foreach my $check (@rpmcheck) {
			if ($check =~ /(\/.*)/) {
				my $file = $1;
				my ($name,$dir,$suffix) = fileparse ($file);
				my $ok   = 1;
				foreach my $exp (@deny) {
					if ($file =~ /$exp/) {
						$ok = 0; last;
					}
				}
				if (($ok) && (-e $file)) {
					my $attr;
					if (-l $file) {
						$attr = lstat ($file);
					} else {
						$attr = stat ($file);
					}
					$result{$file} = [$dir,$attr];
					push (@modified,$file);
				}
			}
			$done = int ($count * $spart);
			if ($done != $done_old) {
				$kiwi -> step ($done);
			}
			$done_old = $done;
			$count++;
		}
		$cdata->{modified} = \@modified;
		$kiwi -> note ("\n");
		$kiwi -> doNorm ();
		$kiwi -> cursorON();
	}
	#==========================================
	# Find files/directories not packaged
	#------------------------------------------
	$kiwi -> info ("Inspecting package database(s) [unpackaged files]\n");
	if ($cache) {
		$kiwi -> info ("=> reading from cache");
		%result = %{$cdata->{result}};
		$kiwi -> done();
	} else {
		$kiwi -> info ("=> requesting RPM package list...");
		my @rpmcheck = qxx ("rpm -qlav");
		chomp @rpmcheck;
		my @rpm_dir  = ();
		my @rpm_file = ();
		# lookup rpm database files...
		foreach my $dir (@rpmcheck) {
			if ($dir =~ /^d.*?\/(.*)$/) {
				my $base = $1;
				my $name = basename $base;
				my $dirn = dirname  $base;
				$dirn = abs_path ("/$dirn");
				$base = "$dirn/$name";
				$base =~ s/\/+/\//g;
				$base =~ s/^\///;
				next if $base eq './';
				push @rpm_file,$base;
				push @rpm_dir ,$base;
			} elsif ($dir =~ /.*?\/(.*?)( -> .*)?$/) {
				my $base = $1;
				my $name = basename $base;
				my $dirn = dirname  $base;
				$dirn = abs_path ("/$dirn");
				$base = "$dirn/$name";
				$base =~ s/\/+/\//g;
				$base =~ s/^\///;
				next if $base eq './';
				push @rpm_file,$base;
			}
		}
		$kiwi -> done();
		# fake gem contents as rpm files...
		if (-x "/usr/bin/gem") {
			$kiwi -> info ("=> requesting GEM package list...");
			my @gemcheck = qxx ("gem contents --all");
			chomp @gemcheck;
			foreach my $item (@gemcheck) {
				my $name = basename $item;
				my $dirn = dirname  $item;
				$name =~ s/^\///;
				$dirn =~ s/^\///;
				push @rpm_file,$dirn."/".$name;
				push @rpm_dir ,$dirn;
			}
			$kiwi -> done();
		}
		# search files in packaged directories...
		$kiwi -> info ("=> searching files in packaged directories...");
		my %file_rpm;
		my %dirs_rpm;
		my %dirs_cmp;
		@file_rpm{map {$_ = "/$_"} @rpm_file} = ();
		@dirs_rpm{map {$_ = "/$_"} @rpm_dir}  = ();
		$dirs_cmp{"/"} = undef;
		foreach my $dir (sort keys %dirs_rpm) {
			while ($dir =~ s:/[^/]+$::) {
				$dirs_cmp{$dir} = undef;
			}
		}
		my @packaged_dirs = sort keys %dirs_rpm;
		my @packaged_dirs_new = ();
		foreach my $dir (@packaged_dirs) {
			my $ok = 1;
			foreach my $exp (@deny) {
				if ($dir =~ /$exp/) {
					$ok = 0; last;
				}
			}
			if ($ok) {
				push @packaged_dirs_new,$dir;
			}
		}
		@packaged_dirs = @packaged_dirs_new;
		$kiwi -> loginfo ("packaged directories: @packaged_dirs");
		my $wref = generateWanted (\%result);
		find({ wanted => $wref, follow => 0 }, @packaged_dirs);
		$kiwi -> done();

		# search for unpackaged symlinks whose origin is packaged
		$kiwi -> info ("=> searching symlinks whose origin is packaged...");
		foreach my $file (sort keys %result) {
			if (-l $file) {
				my $origin = readlink $file;
				my $dirn = dirname $file;
				my $path = $dirn."/".$origin;
				my $base = basename $path;
				$dirn = dirname $path;
				$dirn = $this -> resolvePath ($dirn);
				$path = $dirn."/".$base;
				if (exists $result{$path}) {
					delete $result{$file};
				}
			}
		}
		$kiwi -> done();

		# search for unpackaged files in packaged directories...
		$kiwi -> info ("=> searching unpackaged files in packaged dirs...");
		foreach my $file (sort keys %result) {
			if (exists $file_rpm{$file}) {
				delete $result{$file};
			}
		}
		foreach my $dir (sort keys %dirs_rpm) {
			if (exists $result{$dir}) {
				delete $result{$dir};
			}
		}
		$kiwi -> done();

		# search for unpackaged directories...
		$kiwi -> info ("=> searching unpackaged directories...");
		foreach my $dir (sort keys %dirs_cmp) {
			my $FH;	opendir $FH,$dir;
			while (my $f = readdir $FH) {
				next if $f eq "." || $f eq "..";
				my $path = "$dir/$f";
				if ($dir eq "/") {
					$path = "/$f";
				}
				if ((-d $path) && (! -l $path)) {
					if (! exists $dirs_rpm{$path}) {
						my $attr = stat $path;
						$result{$path} = [$path,$attr];
					}
				}
			}
			closedir $FH;
		}
		$kiwi -> done ();
		$cdata->{result} = \%result;
	}
	#==========================================
	# Write cache if required
	#------------------------------------------
	if (! $cache) {
		$kiwi -> info ("Writing cache file...");
		$cdata->{version} = $this->{gdata}->{Version};
		store ($cdata,$dest.".cache");
		$kiwi -> done();
	}
	#==========================================
	# add custom deny rules
	#------------------------------------------
	my @custom_deny = ();
	#==========================================
	# check for local repository checkouts
	#------------------------------------------
	$kiwi -> info ("Searching for revision control checkout(s)...");
	my %repos = ();
	foreach my $file (sort keys %result) {
		if ($file =~ /\.git$/) {
			#==========================================
			# git repo
			#------------------------------------------
			my $dir = $file;
			$dir =~ s/\/\.git$//;
			push @custom_deny,'^'.$dir;
			$repos{$dir} = "git";
		} elsif ($file =~ /\.svn$/) {
			#==========================================
			# svn repo
			#------------------------------------------
			my $dir = $file;
			my $add = 1;
			$dir =~ s/\/\.svn$//;
			foreach my $rule (@custom_deny) {
				if ($dir =~ /$rule/) {
					$add = 0; last;
				}
			}
			if ($add) {
				push @custom_deny,'^'.$dir;
				$repos{$dir} = "svn";
			}
		}
	}
	$kiwi -> done();
	#==========================================
	# apply all deny files on result hash
	#------------------------------------------
	$kiwi -> info ("Apply deny expressions on custom tree...");
	foreach my $file (sort keys %result) {
		my $ok = 1;
		foreach my $exp ((@deny,@custom_deny)) {
			if ($file =~ /$exp/) {
				$ok = 0; last;
			}
		}
		if (! $ok) {
			delete $result{$file};
		}
	}
	$kiwi -> done();
	#==========================================
	# Create modified files tree
	#------------------------------------------
	$kiwi -> info ("Creating modified files tree...");
	mkdir "$dest/root";
	my %modfiles;
	my $tasks = 0;
	my $done  = 0;
	foreach my $file (@modified) {
		my ($name,$dir,$suffix) = fileparse ($file);
		$modfiles{$dir}{$name} = $file;
		$tasks++;
	}
	$kiwi -> cursorOFF();
	my $factor = 100 / $tasks;
	my $done_percent = 0;
	my $done_previos = 0;
	foreach my $dir (sort keys %modfiles) {
		mkpath ("$dest/root/$dir", {verbose => 0});
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	foreach my $dir (sort keys %modfiles) {
		next if ! chdir "$dest/root/$dir";
		foreach my $file (sort keys %{$modfiles{$dir}}) {
			if (-e "$dir/$file") {
				link "$dir/$file", "$file";
				$done_percent = int ($factor * $done);
				if ($done_percent > $done_previos) {
					$kiwi -> step ($done_percent);
				}
				$done_previos = $done_percent;
				$done++;
			}
		}
	}
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	#==========================================
	# apply deny files on overlay tree
	#------------------------------------------
	$kiwi -> info ("Apply deny expressions on overlay tree...");
	foreach my $exp (@deny) {
		$exp =~ s/\$//;  # shell glob differs from regexps
		qxx ("rm -rf $dest/root/$exp");
	}
	$kiwi -> done();
	#==========================================
	# Create custom (unpackaged) files tree
	#------------------------------------------
	$kiwi -> info ("Creating custom/unpackaged files tree...");
	my %filelist;
	my @dirslist;
	$tasks = 0;
	$done  = 0;
	foreach my $file (sort keys %result) {
		my $fattr = $result{$file}->[1];
		my $type  = "file";
		my $key   = "/";
		if (($fattr) && (S_ISDIR($fattr->mode))) {
			$type = "directory";
		}
		if ($type eq "directory") {
			push @dirslist,$file;
		} else {
			my $name = basename $file;
			my $dirn = dirname  $file;
			$filelist{$dirn}{$name} = $fattr;
			push @dirslist,$dirn;
		}
		$tasks++;
	}
	$kiwi -> cursorOFF();
	$factor = 100 / $tasks;
	$done_percent = 0;
	$done_previos = 0;
	foreach my $dir (sort @dirslist) {
		mkpath ("$dest/custom/$dir", {verbose => 0});
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	foreach my $dir (sort keys %filelist) {
		next if ! chdir "$dest/custom/$dir";
		foreach my $file (sort keys %{$filelist{$dir}}) {
			if (-e "$dir/$file") {
				link "$dir/$file", "$file";
				$done_percent = int ($factor * $done);
				if ($done_percent > $done_previos) {
					$kiwi -> step ($done_percent);
				}
				$done_previos = $done_percent;
				$done++;
			}
		}
	}
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	#==========================================
	# Store in instance for report
	#------------------------------------------
	$this->{nopackage} = \%result;
	$this->{repos} = \%repos;
	return $this;
}

#==========================================
# setInitialSetup
#------------------------------------------
sub setInitialSetup {
	# ...
	# During first deployment of the migrated image we will call
	# YaST2 with the result of the yast2 clone system feature
	# ---
	# 1) create a framebuffer based xorg.conf file, needed for <= 11.1
	# 2) run autoyastClone()
	# ---
	my $this = shift;
	my $dest = $this->{dest};
	my $kiwi = $this->{kiwi};
	$kiwi -> info ("Setting up initial deployment workflow...");
	#==========================================
	# create root directory
	#------------------------------------------
	mkdir "$dest/root";
	#==========================================
	# create xorg.conf [fbdev]
	#------------------------------------------
	qxx ("mkdir -p $dest/root/etc/X11");
	if (-f "/etc/X11/xorg.conf.install") {
		qxx ("cp /etc/X11/xorg.conf.install $dest/root/etc/X11/xorg.conf");
	} else {
		my $FD;
		if (! open ($FD, '>', "$dest/root/etc/X11/xorg.conf")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create fbdev xorg.conf: $!");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# Files
		#------------------------------------------
		print $FD 'Section "Files"'."\n";
		print $FD "\t".'FontPath   "/usr/share/fonts/truetype/"'."\n";
		print $FD "\t".'FontPath   "/usr/share/fonts/uni/"'."\n";
		print $FD "\t".'FontPath   "/usr/share/fonts/misc/"'."\n";
		print $FD "\t".'ModulePath "/usr/lib/xorg/modules"'."\n";
		print $FD 'EndSection'."\n";
		#==========================================
		# ServerFlags / Module
		#------------------------------------------
		print $FD 'Section "ServerFlags"'."\n";
		print $FD "\t".'Option "AllowMouseOpenFail"'."\n";
		print $FD "\t".'Option "BlankTime" "0"'."\n";
		print $FD 'EndSection'."\n";
		print $FD 'Section "Module"'."\n";
		print $FD "\t".'Load  "dbe"'."\n";
		print $FD "\t".'Load  "extmod"'."\n";
		print $FD 'EndSection'."\n";
		#==========================================
		# InputDevice [kbd/mouse]
		#------------------------------------------
		print $FD 'Section "InputDevice"'."\n";
		print $FD "\t".'Driver      "kbd"'."\n";
		print $FD "\t".'Identifier  "Keyboard[0]"'."\n";
		print $FD "\t".'Option      "Protocol"      "Standard"'."\n";
		print $FD "\t".'Option      "XkbRules"      "xfree86"'."\n";
		print $FD "\t".'Option      "XkbKeycodes"   "xfree86"'."\n";
		print $FD "\t".'Option      "XkbModel"      "pc104"'."\n";
		print $FD "\t".'Option      "XkbLayout"     "us"'."\n";
		print $FD 'EndSection'."\n";
		print $FD 'Section "InputDevice"'."\n";
		print $FD "\t".'Driver      "mouse"'."\n";
		print $FD "\t".'Identifier  "Mouse[1]"'."\n";
		print $FD "\t".'Option      "Device"    "/dev/input/mice"'."\n";
		print $FD "\t".'Option      "Protocol"  "explorerps/2"'."\n";
		print $FD 'EndSection'."\n";
		#==========================================
		# Monitor
		#------------------------------------------
		print $FD 'Section "Monitor"'."\n";
		print $FD "\t".'HorizSync     25-40'."\n";
		print $FD "\t".'Identifier    "Monitor[0]"'."\n";
		print $FD "\t".'ModelName     "Initial"'."\n";
		print $FD "\t".'VendorName    "Initial"'."\n";
		print $FD "\t".'VertRefresh   47-75'."\n";
		print $FD 'EndSection'."\n";
		#==========================================
		# Screen
		#------------------------------------------
		print $FD 'Section "Screen"'."\n";
		print $FD "\t".'SubSection "Display"'."\n";
		print $FD "\t\t".'Depth  8'."\n";
		print $FD "\t\t".'Modes  "default"'."\n";
		print $FD "\t".'EndSubSection'."\n";
		print $FD "\t".'SubSection "Display"'."\n";
		print $FD "\t\t".'Depth  15'."\n";
		print $FD "\t\t".'Modes  "default"'."\n";
		print $FD "\t".'EndSubSection'."\n";
		print $FD "\t".'SubSection "Display"'."\n";
		print $FD "\t\t".'Depth  16'."\n";
		print $FD "\t\t".'Modes  "default"'."\n";
		print $FD "\t".'EndSubSection'."\n";
		print $FD "\t".'SubSection "Display"'."\n";
		print $FD "\t\t".'Depth  24'."\n";
		print $FD "\t\t".'Modes  "default"'."\n";
		print $FD "\t".'EndSubSection'."\n";
		print $FD "\t".'Device     "Device[fbdev]"'."\n";
		print $FD "\t".'Identifier "Screen[fbdev]"'."\n";
		print $FD "\t".'Monitor    "Monitor[0]"'."\n";
		print $FD 'EndSection'."\n";
		#==========================================
		# Device
		#------------------------------------------
		print $FD 'Section "Device"'."\n";
		print $FD "\t".'Driver      "fbdev"'."\n";
		print $FD "\t".'Identifier  "Device[fbdev]"'."\n";
		print $FD 'EndSection'."\n";
		#==========================================
		# ServerLayout
		#------------------------------------------
		print $FD 'Section "ServerLayout"'."\n";
		print $FD "\t".'Identifier    "Layout[all]"'."\n";
		print $FD "\t".'InputDevice   "Keyboard[0]"  "CoreKeyboard"'."\n";
		print $FD "\t".'InputDevice   "Mouse[1]"     "CorePointer"'."\n";
		print $FD "\t".'Screen        "Screen[fbdev]"'."\n";
		print $FD 'EndSection'."\n";
		close $FD;
	}
	qxx (
		"cp $dest/root/etc/X11/xorg.conf $dest/root/etc/X11/xorg.conf.install"
	);
	$kiwi -> done();
	#==========================================
	# Activate YaST on initial deployment
	#------------------------------------------	
	if (! $this -> autoyastClone()) {
		return;
	}
	return $this;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	my $this   = shift;
	my @mounts = @{$this->{mount}};
	foreach my $mpoint (@mounts) {
		qxx ("umount $mpoint 2>&1 && rmdir $mpoint");
	}
	return $this;
}

#==========================================
# checkBrokenLinks
#------------------------------------------
sub checkBrokenLinks {
	# ...
	# the tree could contain broken symbolic links because
	# the target is part of a package and therefore not part
	# of the overlay root tree.
	# ---   
	my $this = shift;
	my $dest = $this->{dest};
	my $kiwi = $this->{kiwi};
	my @base = ("root");
	my @link = ();
	#==========================================
	# search links in overlay subtrees
	#------------------------------------------
	foreach my $root (@base) {
		my @list = qxx ("find $dest/$root -type l");
		push @link,@list;
	}
	my $returnok = 1;
	#==========================================
	# check link targets
	#------------------------------------------
	foreach my $linkfile (@link) {
		chomp $linkfile;
		my $ref = readlink ($linkfile);
		if ($ref !~ /^\//) {
			my ($name,$dir,$suffix) = fileparse ($linkfile);
			$dir =~ s/$dest\/root-.*?\///;
			$ref = $dir."/".$ref;
		}
		my $remove = 1;
		foreach my $root (@base) {
			if (-e "$dest/$root/$ref") {
				$remove = 0; last;
			}
		}
		if ($remove) {
			$kiwi -> loginfo ("Broken link: $linkfile [ REMOVED ]");
			unlink $linkfile;
			$returnok = 0;
		}
	}
	if ($returnok) {
		return $this;
	}
	checkBrokenLinks ($this);
}

#==========================================
# autoyastClone
#------------------------------------------
sub autoyastClone {
	# ...
	# call yast clone_system to backup the current system
	# configuration information into an auto yast profile
	# On first deployment of the appliance autoyast is 
	# called with the created profile in order to clone
	# the current system configuration into the appliance
	# ---
	my $this = shift;
	my $dest = $this->{dest};
	my $kiwi = $this->{kiwi};
	my @list = @{$this->{autoyastCloneList}};
	#==========================================
	# check autoyast2 version
	#==========================================
	my $ayVersion = qxx( 'rpm -q --qf "%{VERSION}" autoyast2 2>&1' );
	if( $? != 0 ) {
		$kiwi -> warning("checking AutoYaST version failed");
		$kiwi -> skipped();
		return;
	}
	$ayVersion =~ /^(\d+)\.(\d+)/;
	if( $1 < 3 && $2 < 19 ) {
		# version is less than 2.19.x (1.xx.yy with xx >= 19 can be ignored)
		$kiwi -> warning("AutoYaST version $ayVersion is too old for cloning");
		$kiwi -> skipped();
		return $this;
	}
	#==========================================
	# run yast for cloning
	#------------------------------------------
	my $cloneList = join( ',', @list );
	if (-e "/root/autoinst.xml") {
		qxx ("mv /root/autoinst.xml /root/autoinst.xml.backup");
	}
	qxx("yast clone_system modules clone=$cloneList");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("AutoYaST cloning failed. $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# store clone XML for use in kiwi
	#------------------------------------------
	qxx ("mv /root/autoinst.xml $dest/config-yast-autoyast.xml");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("failed to move /root/autoinst.xml after cloning. $!");
		$kiwi -> failed ();
		return;
	}
	if (-e "/root/autoinst.xml.backup") {
		qxx ("mv /root/autoinst.xml.backup /root/autoinst.xml");
	}
	return $this;
}

#==========================================
# resolvePath
#------------------------------------------
sub resolvePath {
	# ...
	# resolve a given path string into a clean
	# representation this includes solving of jump
	# backs like ../ or irrelevant information
	# like // or ./
	# ---
	my $this = shift;
	my $origin = shift;
	my $current= $origin;
	#========================================
	# resolve jump back
	#----------------------------------------
	while ($current =~ /\.\./) {
		my @path = split (/\/+/,$current);
		for (my $l=0;$l<@path;$l++) {
			if ($path[$l] eq "..") {
				delete $path[$l];
				delete $path[$l-1];
				last;
			}
		}
		$current = join ("/",@path);
	}
	#========================================
	# resolve the rest
	#----------------------------------------
	my $result;
	my @path = split (/\/+/,$current);
	for (my $l=0;$l<@path;$l++) {
		my $part = $path[$l];
		if ($part eq "") {
			$result.="/"; next;
		}
		if ($part eq ".") {
			next;
		}
		$result.=$part;
		if ($l < @path - 1) {
			$result.="/";
		}
	}
	$result =~ s/\/+/\//g;
	return $result;
}

1;

# vim: set noexpandtab:
