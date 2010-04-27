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
use File::Find;
use File::Basename;
use File::Path;
use File::Copy;
use Storable;
use KIWILog;
use KIWIQX;

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
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $code;
	my $data;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (! defined $name) {
		$kiwi -> failed ();
		$kiwi -> error  ("No image name for migration given");
		$kiwi -> failed ();
		return undef;
	}
	my $product = $this -> getOperatingSystemVersion();
	if (! defined $product) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find system version information");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> note (" [$product]");
	if (defined $main::ForceNewRoot) {
		qxx ("rm -rf $dest");
	}
	if (! defined $dest) {
		$dest = qxx (" mktemp -q -d /tmp/kiwi-migrate.XXXXXX ");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create destination dir: $!");
			$kiwi -> failed ();
			return undef;
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
			return undef;
		}
	}
	$dest =~ s/\/$//;
	$kiwi -> done ();
	$kiwi -> info ("Results will be written to: $dest");
	$kiwi -> done ();
	if (! $this -> getRootDevice()) {
		$kiwi -> failed ();
		$kiwi -> error ("Couldn't find system root device");
		$kiwi -> failed ();
		rmdir $dest;
		return undef;
	}
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
		'\/etc\/init\.d\/rc.*\/',       # no service links
		'\/etc\/init\.d\/boot.d\/',     # no boot service links
		'\.depend',                     # no make depend targets
		'\.backup',                     # no sysconfig backup files
		'\.gz',                         # no gzip archives
		'\/usr\/src\/',                 # no sources
		'\/spool',                      # no spool directories
		'^\/dev\/',                     # no device node files
		'\/usr\/X11R6\/',               # no depreciated dirs
		'\/tmp\/',                      # no /tmp data
		'\/boot\/',                     # no /boot data
		'\/proc\/',                     # no /proc data
		'\/sys\/',                      # no /sys data
		'\/abuild\/',                   # no /abuild data
		'\/cache',                      # no cache files
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
		'\/media\/',                    # no media automount files
		'\/var\/lib\/hardware\/'        # no hwinfo hardware files
	);
	if (defined $excl) {
		my @exclude = @{$excl};
		foreach (@exclude) { $_ = quotemeta; };
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
	my $filechanges= $this->{filechanges};
	my $modified   = $this->{modified};
	my $twice      = $this->{twice};
	#==========================================
	# Start report
	#------------------------------------------
	if (! open (FD,">$dest/report.html")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create report: $!");
		$kiwi -> failed ();
		return undef;
	}
	print FD '<html>'."\n";
	print FD "\t".'<head>'."\n";
	print FD "\t\t".'<title>Migration report</title>'."\n";
	print FD "\t".'</head>'."\n";
	print FD '<body>'."\n";
	#==========================================
	# Package/Pattern report
	#------------------------------------------
	if ($twice) {
		my @pacs = @{$twice};
		print FD '<h1>Package(s) installed multiple times</h1>'."\n";
		print FD '<p>'."\n";
		print FD 'The following packages are installed multiple times. ';
		print FD 'Please uninstall the old versions of the packages ';
		print FD 'and re-run the migration. ';
		print FD '</p>'."\n";
		print FD '<hr>'."\n";
		print FD '<table>'."\n";
		my @list = qxx ("rpm -q @pacs --last"); chomp @list;
		foreach my $job (@list) {
			if ($job =~ /([^\s]+)\s+([^\s].*)/) {
				my $pac  = $1;
				my $date = $2;
				print FD '<tr valign="top">'."\n";
				print FD '<td>'.$pac.'</td>'."\n";
				print FD '<td>'.$date.'</td>'."\n";
				print FD '</tr>'."\n";
			}
		}
		print FD '</table>'."\n";
	}
	if ($problem1) {
		print FD '<h1>Pattern conflict(s)</h1>'."\n";
		print FD '<p>'."\n";
		print FD 'The following patterns could not be solved because ';
		print FD 'they have dependency conflicts. Please check the list ';
		print FD 'and solve the conflicts by either: ';
		print FD "\n";
		print FD '<ul>'."\n";
		print FD '<li>'."\n";
		print FD 'Adding all software repositories to zypper which provide ';
		print FD 'the missing dependences, or';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '<li>'."\n";
		print FD 'Ignoring the pattern. If you ignore the pattern, your ';
		print FD 'selected software might not be part of your final image.';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '</ul>'."\n";
		print FD '</p>'."\n";
		print FD '<hr>'."\n";
		print FD '<pre>'."\n";
		print FD "$problem1";
		print FD '</pre>'."\n";
	}
	if ($problem2) {
		print FD '<h1>Package conflict(s)</h1>'."\n";
		print FD '<p>'."\n";
		print FD 'The following packages could not be solved due to ';
		print FD 'dependency conflicts. Please check the list and ';
		print FD 'solve them by either:';
		print FD "\n";
		print FD '<ul>'."\n";
		print FD '<li>'."\n";
		print FD 'Following one of the problem solutions mentioned in ';
		print FD 'the conflict report below, or';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '<li>'."\n";
		print FD 'Skipping the concerning package(s) by calling kiwi ';
		print FD 'again with the --skip option.';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '</ul>'."\n";
		print FD '</p>'."\n";
		print FD '<hr>'."\n";
		print FD '<pre>'."\n"; 
		print FD "$problem2";
		print FD '</pre>'."\n";
	}
	if (($failedJob1) && (@{$failedJob1})) {
		print FD '<h1>Pattern(s) not found</h1>'."\n";
		print FD '<p>'."\n";
		print FD 'The following patterns could not be found in your ';
		print FD 'repository list marked as installed. Please check the ';
		print FD 'list and solve the problem by either: ';
		print FD "\n";
		print FD '<ul>'."\n";
		print FD '<li>'."\n";
		print FD 'Adding a repository to zypper which provides the ';
		print FD 'pattern, or';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '<li>'."\n";
		print FD 'Ignoring the pattern.  If you ignore the pattern, your ';
		print FD 'selected software will not be a part of your final image.';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '</ul>'."\n";
		print FD '</p>'."\n";
		print FD '<hr>'."\n";
		print FD '<ul>'."\n";
		foreach my $job (@{$failedJob1}) {
			print FD '<li>'.$job.'</li>'."\n";
		}
		print FD '</ul>'."\n";
	}
	if (($failedJob2) && (@{$failedJob2})) {
		print FD '<h1>Package(s) not found</h1>'."\n";
		print FD '<p>'."\n";
		print FD 'The following packages could not be found in your ';
		print FD 'repository list but are installed on the system ';
		print FD 'Please check the list and solve the problem by ';
		print FD 'either:';
		print FD "\n";
		print FD '<ul>'."\n";
		print FD '<li>'."\n";
		print FD 'Adding a repository to zypper which provides the ';
		print FD 'package, or';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '<li>'."\n";
		print FD 'Ignoring the package. If you ignore the package, your ';
		print FD 'software selection might not be part of your final ';
		print FD 'image. Also, if you ignore a package which contains ';
		print FD 'files modified in the system, kiwi will store the ';
		print FD 'modified files inside the overlay tree. This means your ';
		print FD 'image might contain files from the ignored package but ';
		print FD 'they are most likely not useful without the full ';
		print FD 'package installed.';
		print FD "\n";
		print FD '</li>'."\n";
		print FD '</ul>'."\n";
		print FD '</p>'."\n";
		print FD '<hr>'."\n";
		print FD '<table>'."\n";
		my @pacs = @{$failedJob2};
		my @list = qxx ("rpm -q @pacs --last"); chomp @list;
		foreach my $job (@list) {
			if ($job =~ /([^\s]+)\s+([^\s].*)/) {
				my $pac  = $1;
				my $date = $2;
				print FD '<tr valign="top">'."\n";
				print FD '<td>'.$pac.'</td>'."\n";
				print FD '<td>'.$date.'</td>'."\n";
				print FD '</tr>'."\n";
			}
		}
		print FD '</table>'."\n";
	}
	#==========================================
	# Modified files report...
	#------------------------------------------
	if ($modified) {
		# modified...
		print FD '<h1>Modified files</h1>'."\n";
		print FD '<p>'."\n";
		print FD 'Behind the "Modified files directory" link you will find ';
		print FD 'files which are part of a package and were modified ';
		print FD 'in the past. In most cases this is because a ';
		print FD 'configuration file provided by the package has changed. ';
		print FD 'You may want to keep these files in your  overlay tree. ';
		print FD 'You should prevent your overlay tree from containing ';
		print FD 'binary files like executables or libraries. ';
		print FD 'Just change into the directory below and remove ';
		print FD 'all the files you do not want to keep in your overlay ';
		print FD 'tree. If you are finished, copy the entire tree into ';
		print FD 'the directory '.$dest.'/root'."\n";
		print FD '</p>'."\n";
		print FD '<hr>'."\n";
		print FD '<a href="'."$dest/root-modified/".'">';
		print FD 'Modified files directory</a>'."\n";
		# unpackaged...
		print FD '<h1>Unpackaged files</h1>'."\n";
		print FD '<p>'."\n";
		print FD 'Behind the "Unpackaged files directory" link, you will ';
		print FD 'find a list of files which are not part of any packages. ';
		print FD 'For binary files, including executables and libraries, ';
		print FD 'you should try to find and include a package that ';
		print FD 'provides them. If there are no package providers for ';
		print FD 'this file, you can leave them as overlay files, but it ';
		print FD 'may cause problems like broken dependencies later. ';
		print FD 'After that, you should look for personal files like ';
		print FD 'pictures, movies, or repositories, and remove them if ';
		print FD 'they can be easily restored in the later image. ';
		print FD 'The rest of the tree can be checked with a program ';
		print FD 'called kdirstat which allows you to find large files ';
		print FD 'and lets you decide whether or not you need them in ';
		print FD 'your image description. Remove all of the files you ';
		print FD 'do not want to keep in your overlay files from the ';
		print FD 'unpackaged files directory and copy the rest into ';
		print FD 'the '.$dest.'/root directory.'."\n";
		print FD '</p>'."\n";
		print FD '<a href="'."$dest/root-nopackage/".'">';
		print FD 'Unpackaged files directory</a>'."\n";
	}
	close FD;
	$kiwi -> info ("--> Please check the migration report !!\n");
	$kiwi -> note ("\n\tfile://$dest/report.html\n\n");
	return $this;
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
		return undef;
	}
	foreach my $repo (@list) {
		$repo =~ s/ +//g;
		if ($repo =~ /^\d.*\|(.*)\|.*\|(.*)\|.*\|(.*)\|(.*)\|(.*)\|/) {
			my $enabled = $2;
			my $source  = $5;
			my $type    = $4;
			my $alias   = $1;
			my $prio    = $3;
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
	if (! open (FD,">$dest/$main::ConfigName")) {
		return undef;
	}
	#==========================================
    # <description>
    #------------------------------------------
	print FD '<image schemaversion="4.4" ';
	print FD 'name=suse-migration"'.$product.'">'."\n";
	print FD "\t".'<description type="system">'."\n";
	print FD "\t\t".'<author>***AUTHOR***</author>'."\n";
	print FD "\t\t".'<contact>***MAIL***</contact>'."\n";
	print FD "\t\t".'<specification>'.$product.'</specification>'."\n";
	print FD "\t".'</description>'."\n";
	#==========================================
	# <preferences>
	#------------------------------------------
	print FD "\t".'<preferences>'."\n";
	print FD "\t\t".'<type image="oem" boot="oemboot/suse-'.$product.'"';
	print FD ' filesystem="ext3" format="iso">'."\n";
	print FD "\t\t\t".'<oemconfig>'."\n";
	print FD "\t\t\t\t".'<oem-home>false</oem-home>'."\n";
	print FD "\t\t\t".'</oemconfig>'."\n";
	print FD "\t\t".'</type>'."\n";
	print FD "\t\t".'<version>1.1.1</version>'."\n";
	print FD "\t\t".'<packagemanager>zypper</packagemanager>'."\n";
	print FD "\t\t".'<locale>en_US</locale>'."\n";
	print FD "\t\t".'<keytable>us.map.gz</keytable>'."\n";
	print FD "\t\t".'<timezone>Europe/Berlin</timezone>'."\n";
	print FD "\t\t".'<boot-theme>openSUSE</boot-theme>'."\n";
	print FD "\t".'</preferences>'."\n";
	#==========================================
	# <repository>
	#------------------------------------------
	foreach my $source (keys %{$osc{$product}} ) {
		my $type = $osc{$product}{$source}{type};
		my $alias= $osc{$product}{$source}{alias};
		my $prio = $osc{$product}{$source}{prio};
		my $url  = $osc{$product}{$source}{src};
		print FD "\t".'<repository type="'.$type.'"';
		if (defined $alias) {
			print FD ' alias="'.$alias.'"';
		}
		if ((defined $prio) && ($prio != 0)) {
			print FD ' priority="'.$prio.'"';
		}
		print FD '>'."\n";
		print FD "\t\t".'<source path="'.$url.'"/>'."\n";
		print FD "\t".'</repository>'."\n";
	}
	#==========================================
	# <packages>
	#------------------------------------------
	print FD "\t".'<packages type="image">'."\n";
	if (defined $pats) {
		foreach my $pattern (@{$pats}) {
			print FD "\t\t".'<opensusePattern name="'.$pattern.'"/>'."\n";
		}
	}
	if (defined $pacs) {
		foreach my $package (@{$pacs}) {
			print FD "\t\t".'<package name="'.$package.'"/>'."\n";
		}
	}
	print FD "\t".'</packages>'."\n";
	#==========================================
	# <packages type="bootstrap">
	#------------------------------------------
	print FD "\t".'<packages type="bootstrap">'."\n";
	print FD "\t\t".'<package name="filesystem"/>'."\n";
	print FD "\t\t".'<package name="glibc-locale"/>'."\n";
	print FD "\t\t".'<package name="cracklib-dict-full"/>'."\n";
	print FD "\t\t".'<package name="openssl-certs"/>'."\n";
	print FD "\t".'</packages>'."\n";
	print FD '</image>'."\n";
	close FD;
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
	if (! open (FD,"/etc/SuSE-release")) {
		return undef;
	}
	my $name = <FD>; chomp $name;
	my $vers = <FD>; chomp $vers;
	my $plvl = <FD>; chomp $plvl;
	$name =~ s/\s+/-/g;
	$name =~ s/\-\(.*\)//g;
	if ((defined $plvl) && ($plvl =~ /PATCHLEVEL = (.*)/)) {
		$plvl = $1;
		$name = $name."-SP".$plvl;
	}
	close FD;
	if (! open (FD,$main::KMigrate)) {
		return undef;
	}
	while (my $line = <FD>) {
		next if $line =~ /^#/;
		if ($line =~ /(.*)\s*=\s*(.*)/) {
			my $product= $1;
			my $boot   = $2;
			if ($product eq $name) {
				close FD; return $boot;
			}
		}
	}
	close FD;
	return undef;
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
	my @serviceBoot = glob ("/etc/init.d/boot.d/S*");
	my @serviceList = glob ("/etc/init.d/rc5.d/S*");
	my @service = (@serviceBoot,@serviceList);
	my @result;
	foreach my $service (@service) {
		my $name = readlink $service;
		if (defined $name) {
			$name =~ s/\.+\/+//g;
			push @result,$name;
		}
	}
	#==========================================
	# create config script
	#------------------------------------------
	if (! open (FD,">$dest/config.sh")) {
		return undef;
	}
	print FD '#!/bin/bash'."\n";
	print FD 'test -f /.kconfig && . /.kconfig'."\n";
	print FD 'test -f /.profile && . /.profile'."\n";
	print FD 'echo "Configure image: [$kiwi_iname]..."'."\n";
	print FD 'suseSetupProduct'."\n";
	#==========================================
	# Services...
	#------------------------------------------
	foreach my $service (@result) {
		print FD 'suseInsertService '.$service."\n";
	}
	#==========================================
	# Repos...
	#------------------------------------------
	foreach my $source (keys %{$osc{$product}} ) {
		my $alias= $osc{$product}{$source}{alias};
		my $url  = $osc{$product}{$source}{src};
		my $flag = $osc{$product}{$source}{flag};
		if ($flag ne "remote") {
			$kiwi -> warning (
				"Local repo: $alias will not be added to config.sh"
			);
			$kiwi -> skipped ();
			next;
		}
		print FD "zypper ar \\\n\t\"".$url."\" \\\n\t\"".$alias."\"\n";
	}
	print FD 'suseConfig'."\n";
	print FD 'baseCleanMount'."\n";
	print FD 'exit 0'."\n";
	close FD;
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
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# find packages installed n times n > 1
	#------------------------------------------
	my %packages = ();
	my @twice = ();
	for (my $i=0;$i<@ilist;$i++) {
		$packages{$ilist[$i]}++;
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
		my @list = qxx ("zypper --no-refresh patterns --installed 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to obtain installed patterns");
			$kiwi -> failed ();
			return undef;
		} else {
			my %pathash = ();
			foreach my $line (@list) {
				if ($line =~ /^i.*\|(.*)\|.*\|.*\|/) {
					my $name = $1;
					$name =~ s/^ +//g;
					$name =~ s/ +$//g;
					$pathash{"$name"} = "$name";
				}
			}
			@patlist = keys %pathash;
		}
		$this->{patterns} = \@patlist;
		my $psolve = new KIWISatSolver (
			$kiwi,\@patlist,\@urllist,undef,undef,undef,"silent"
		);
		my @result = ();
		if (! defined $psolve) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to solve patterns");
			$kiwi -> failed ();
			return undef;
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
				foreach my $s (@{$skip}) {
					next if ($installed =~ /$s/);
				}
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
			my $repo = $psolve -> getRepo();
			my $pool = $psolve -> getPool();
			my $xsolve = new KIWISatSolver (
				$kiwi,\@result,\@urllist,"solve-packages",$repo,$pool,"silent"
			);
			if (! defined $xsolve) {
				$kiwi -> error  ("Failed to solve packages");
				$kiwi -> failed ();
				return undef;
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
# getRootDevice
#------------------------------------------
sub getRootDevice {
	# ...
	# Find the root device of the operating system. Only those
	# data are inspected. We don't handle sub-mounted systems
	# within the root tree
	# ---
	my $this = shift;
	my $rootdev;
	if (! open (FD,"/etc/fstab")) {
		return undef;
	}
	my @fstab = <FD>; close FD;
	foreach my $mount (@fstab) {
		if ($mount =~ /\s+\/\s+/) {
			my @attribs = split (/\s+/,$mount);
			if ( -e $attribs[0]) {
				$rootdev = $attribs[0]; last;
			}
		}
	}
	if (! $rootdev) {
		return undef;
	}
	my $data = qxx ("df $rootdev | tail -n1");
	my $code = $? >> 8;
	if ($code != 0) {
		return undef;
	}
	if ($data =~ /$rootdev\s+\d+\s\s(\d+)\s\s/) {
		$data = $1;
		$data = int ( $data / 1024 );
	}	
	$this->{rdev}  = $rootdev;
	$this->{rsize} = $data;
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
	my @rpmlist;
	my @rpmcheck;
	my %result;
	my $data;
	my $code;
	my @modified;
	my @ilist;
	my $root = "/";
	#==========================================
	# check for cache file
	#------------------------------------------
	if (! -f $cache) {
		undef $cache;
	} else {
		$kiwi -> info ("=> Using cache file: $cache\n");
		$kiwi -> info ("=> Remove cache file if your system has changed !!\n");
		$cdata = retrieve($cache);
	}
	#==========================================
	# search installed packages
	#------------------------------------------
	$kiwi -> info ("Searching installed packages...");
	if ($cache) {
		@ilist = @{$cdata->{ilist}};
	} else {
		@ilist = qxx ('rpm -qa --qf "%{NAME}\n" | sort | uniq'); chomp @ilist;
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to obtain installed packages");
			$kiwi -> failed ();
			return undef;
		}
		$cdata->{ilist} = \@ilist;
	}
	$kiwi -> done();
	#==========================================
	# exclude special and non local mounts
	#------------------------------------------
	if (! $cache) {
		my @mounts = qxx ("cat /proc/mounts|cut -f 2,3 -d ' '"); chomp @mounts;
		foreach my $mount (@mounts) {
			my @details = split (/\s+/,$mount);
			my $path = quotemeta ($details[0]);
			my $type = $details[1];
			$path .= "\/";
			if ($type =~
				/^(tmpfs|proc|sysfs|debugfs|devpts|fusectl|autofs|nfs|nfsd)$/) {
				push @deny,$path;
				$kiwi -> loginfo ("Excluding path: $path per mount table\n");
			}
		}
	}
	#==========================================
	# generate File::Find closure
	#------------------------------------------
	sub generateWanted {
		my $filehash = shift;
		return sub {
			if (((-l $File::Find::name) && (-e $File::Find::name)) ||
				(! -d $File::Find::name))
			{
				my $file = $File::Find::name;
				my $dirn = $File::Find::dir;
				$filehash->{$file} = $dirn;
			}
		}
	};
	#==========================================
	# Find files not packaged
	#------------------------------------------
	$kiwi -> info ("Reading root file system...");
	if ($cache) {
		%result = %{$cdata->{result}};
	} else {
		my $wref = generateWanted (\%result);
		find ({ wanted => $wref }, $root );
		$cdata->{result} = \%result;
	}
	$kiwi -> done ();
	$kiwi -> info ("Inspecting RPM database [installed files]...");
	if ($cache) {
		@rpmlist = @{$cdata->{rpmlist}};
	} else {
		@rpmlist = qxx ("rpm -qal");
		$cdata->{rpmlist} = \@rpmlist;
	}
	my @curlist = keys %result;
	my $cursize = @curlist;
	my $rpmsize = @rpmlist;
	my $spart = 100 / ($cursize + $rpmsize);
	my $count = 0;
	my $done;
	my $done_old;
	$kiwi -> cursorOFF();
	foreach my $managed (@rpmlist) {
		chomp $managed; delete $result{$managed};
		$done = int ($count * $spart);
		if ($done != $done_old) {
			$kiwi -> step ($done);
		}
		$done_old = $done;
		$count++;
	}
	@curlist = keys %result;
	$cursize = @curlist;
	$spart = 100 / ($cursize + $rpmsize);
	foreach my $file (sort keys %result) {
		foreach my $exp (@deny) {
			if ($file =~ /$exp/) {
				delete $result{$file}; last;
			}
		}
		$done = int ($count * $spart);
		if ($done != $done_old) {
			$kiwi -> step ($done);
		}
		$done_old = $done;
		$count++;
	}
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	#==========================================
	# Find files packaged but changed
	#------------------------------------------
	$kiwi -> info ("Inspecting RPM database [verify]...");
	if ($cache) {
		@rpmcheck = @{$cdata->{rpmcheck}};
	} else {
		$checkopt = "--nodeps --nodigest --nosignature --nomtime ";
		$checkopt.= "--nolinkto --nouser --nogroup --nomode";
		@rpmcheck = qxx ("rpm -Va $checkopt"); chomp @rpmcheck;
		$cdata->{rpmcheck} = \@rpmcheck;
	}
	$rpmsize = @rpmcheck;
	$spart = 100 / $rpmsize;
	$count = 1;
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
				$result{$file} = $dir;
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
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	#==========================================
	# Write cache if required
	#------------------------------------------
	if (! $cache) {
		store ($cdata,$dest.".cache");
	}
	#==========================================
	# Cleanup
	#------------------------------------------
	qxx ("rm -rf $dest/root-nopackage 2>&1");
	qxx ("rm -rf $dest/root-modified  2>&1");
	#==========================================
	# Create overlay root tree
	#------------------------------------------
	$kiwi -> info ("Creating link list...\n");
	$data = qxx ("mkdir -p $dest/root-nopackage 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create overlay root directory: $data");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# 1) Create directory structure
	#------------------------------------------
	my %paths = ();
	foreach my $file (keys %result) {
		my $path = $result{$file};
		$paths{"$dest/root-nopackage/$path"} = $path;
	}
	mkpath (keys %paths, {verbose => 0});
	#==========================================
	# 2) Create hard link list
	#------------------------------------------
	foreach my $file (keys %result) {
		my $old = $file;
		my $new = $dest."/root-nopackage".$old;
		if (! link "$old","$new") {
			$kiwi -> warning ("hard link for $file failed: $!");
			$kiwi -> skipped ();
		}
	}
	#==========================================
	# Create modified files tree
	#------------------------------------------
	$kiwi -> info ("Creating modified files tree...");
	mkdir "$dest/root-modified";
	foreach my $file (@modified) {
		my ($name,$dir,$suffix) = fileparse ($file);
		mkpath ("$dest/root-modified/$dir", {verbose => 0});
		move ("$dest/root-nopackage/$file","$dest/root-modified/$dir");
	}
	$kiwi -> done();
	#==========================================
	# Cleanup symbolic links
	#------------------------------------------
	$kiwi -> info ("Cleaning symlinks...");
	$this -> checkBrokenLinks();
	$kiwi -> done();
	#==========================================
	# Remove empty directories
	#------------------------------------------
	$kiwi -> info ("Removing empty directories...");
	qxx ("find $dest/root-nopackage -type d | xargs rmdir -p 2>/dev/null");
	$kiwi -> done();
	#==========================================
	# Store in instance for report
	#------------------------------------------
	$this->{filechanges} = \%result;
	$this->{modified}    = \@modified;
	$this->{ilist}       = \@ilist;
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
	# Cleanup
	#------------------------------------------
	qxx ("rm -rf $dest/root 2>&1");
	#==========================================
	# create root directory
	#------------------------------------------
	mkdir "$dest/root";
	#==========================================
	# create xorg.conf [fbdev]
	#------------------------------------------
	qxx ("mkdir -p $dest/root/etc/X11");
	qxx ("mkdir -p $dest/root/var/lib/YaST2");
	if (-f "/etc/X11/xorg.conf.install") {
		qxx ("cp /etc/X11/xorg.conf.install $dest/root/etc/X11/xorg.conf");
	} else {
		if (! open (FD,">$dest/root/etc/X11/xorg.conf")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create fbdev xorg.conf: $!");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# Files
		#------------------------------------------
		print FD 'Section "Files"'."\n";
		print FD "\t".'FontPath   "/usr/share/fonts/truetype/"'."\n";
		print FD "\t".'FontPath   "/usr/share/fonts/uni/"'."\n";
		print FD "\t".'FontPath   "/usr/share/fonts/misc/"'."\n";
		print FD "\t".'ModulePath "/usr/lib/xorg/modules"'."\n";
		print FD 'EndSection'."\n";
		#==========================================
		# ServerFlags / Module
		#------------------------------------------
		print FD 'Section "ServerFlags"'."\n";
		print FD "\t".'Option "AllowMouseOpenFail"'."\n";
		print FD "\t".'Option "BlankTime" "0"'."\n";
		print FD 'EndSection'."\n";
		print FD 'Section "Module"'."\n";
		print FD "\t".'Load  "dbe"'."\n";
		print FD "\t".'Load  "extmod"'."\n";
		print FD 'EndSection'."\n";
		#==========================================
		# InputDevice [kbd/mouse]
		#------------------------------------------
		print FD 'Section "InputDevice"'."\n";
		print FD "\t".'Driver      "kbd"'."\n";
		print FD "\t".'Identifier  "Keyboard[0]"'."\n";
		print FD "\t".'Option      "Protocol"      "Standard"'."\n";
		print FD "\t".'Option      "XkbRules"      "xfree86"'."\n";
		print FD "\t".'Option      "XkbKeycodes"   "xfree86"'."\n";
		print FD "\t".'Option      "XkbModel"      "pc104"'."\n";
		print FD "\t".'Option      "XkbLayout"     "us"'."\n";
		print FD 'EndSection'."\n";
		print FD 'Section "InputDevice"'."\n";
		print FD "\t".'Driver      "mouse"'."\n";
		print FD "\t".'Identifier  "Mouse[1]"'."\n";
		print FD "\t".'Option      "Device"    "/dev/input/mice"'."\n";
		print FD "\t".'Option      "Protocol"  "explorerps/2"'."\n";
		print FD 'EndSection'."\n";
		#==========================================
		# Monitor
		#------------------------------------------
		print FD 'Section "Monitor"'."\n";
		print FD "\t".'HorizSync     25-40'."\n";
		print FD "\t".'Identifier    "Monitor[0]"'."\n";
		print FD "\t".'ModelName     "Initial"'."\n";
		print FD "\t".'VendorName    "Initial"'."\n";
		print FD "\t".'VertRefresh   47-75'."\n";
		print FD 'EndSection'."\n";
		#==========================================
		# Screen
		#------------------------------------------
		print FD 'Section "Screen"'."\n";
		print FD "\t".'SubSection "Display"'."\n";
		print FD "\t\t".'Depth  8'."\n";
		print FD "\t\t".'Modes  "default"'."\n";
		print FD "\t".'EndSubSection'."\n";
		print FD "\t".'SubSection "Display"'."\n";
		print FD "\t\t".'Depth  15'."\n";
		print FD "\t\t".'Modes  "default"'."\n";
		print FD "\t".'EndSubSection'."\n";
		print FD "\t".'SubSection "Display"'."\n";
		print FD "\t\t".'Depth  16'."\n";
		print FD "\t\t".'Modes  "default"'."\n";
		print FD "\t".'EndSubSection'."\n";
		print FD "\t".'SubSection "Display"'."\n";
		print FD "\t\t".'Depth  24'."\n";
		print FD "\t\t".'Modes  "default"'."\n";
		print FD "\t".'EndSubSection'."\n";
		print FD "\t".'Device     "Device[fbdev]"'."\n";
		print FD "\t".'Identifier "Screen[fbdev]"'."\n";
		print FD "\t".'Monitor    "Monitor[0]"'."\n";
		print FD 'EndSection'."\n";
		#==========================================
		# Device
		#------------------------------------------
		print FD 'Section "Device"'."\n";
		print FD "\t".'Driver      "fbdev"'."\n";
		print FD "\t".'Identifier  "Device[fbdev]"'."\n";
		print FD 'EndSection'."\n";
		#==========================================
		# ServerLayout
		#------------------------------------------
		print FD 'Section "ServerLayout"'."\n";
		print FD "\t".'Identifier    "Layout[all]"'."\n";
		print FD "\t".'InputDevice   "Keyboard[0]"  "CoreKeyboard"'."\n";
		print FD "\t".'InputDevice   "Mouse[1]"     "CorePointer"'."\n";
		print FD "\t".'Screen        "Screen[fbdev]"'."\n";
		print FD 'EndSection'."\n";
		close FD;
	}
	qxx (
		"cp $dest/root/etc/X11/xorg.conf $dest/root/etc/X11/xorg.conf.install"
	);
	#==========================================
	# Activate YaST on initial deployment
	#------------------------------------------	
	if (! $this -> autoyastClone()) {
		return undef;
	}
	$kiwi -> done();
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
	my @base = ("root-nopackage","root-modified");
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
		return undef;
	}
	#==========================================
	# store clone XML for use in kiwi
	#------------------------------------------
	qxx("cp /root/autoinst.xml $dest/config-yast-autoyast.xml");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("failed to copy /root/autoinst.xml after cloning. $!");
		$kiwi -> failed ();
		return undef;
	}
	qxx("mv /root/autoinst.xml.backup /root/autoinst.xml");
	if ( ! open (FD,">$dest/root/etc/install.inf")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create install.inf: $!");
		$kiwi -> failed ();
		return undef;
	}
	print FD "AutoYaST: \n";
	close FD;
	if ( ! open (FD,">$dest/root/var/lib/YaST2/runme_at_boot")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create runme_at_boot: $!");
		$kiwi -> failed ();
		return undef;
	}
	close FD;
	return $this;
}

1;

# vim: set noexpandtab:
