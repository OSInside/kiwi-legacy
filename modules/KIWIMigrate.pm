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
	$kiwi -> note (" [$product]...");
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
		'\.rpmnew',                  # no RPM backup files
		'\.rpmsave',                 # []
		'\.rpmorig',                 # []
		'~$',                        # no emacs backup files
		'\.swp$',                    # no vim backup files
		'\.rej$',                    # no diff reject files
		'\.lock$',                   # no lock files
		'\.tmp$',                    # no tmp files
		'\/etc\/init\.d\/rc.*\/',    # no service links
		'\/etc\/init\.d\/boot.d\/',  # no boot service links
		'\.depend',                  # no make depend targets
		'\.backup',                  # no sysconfig backup files
		'\.gz',                      # no gzip archives
		'\/usr\/src\/',              # no sources
		'\/spool',                   # no spool directories
		'^\/dev\/',                  # no device node files
		'\/usr\/X11R6\/',            # no depreciated dirs
		'\/tmp\/',                   # no /tmp data
		'\/boot\/',                  # no /boot data
		'\/proc\/',                  # no /proc data
		'\/sys\/',                   # no /sys data
		'\/abuild\/',                # no /abuild data
		'\/cache',                   # no cache files
		'\/fillup-templates',        # no fillup data
		'\/var\/lib\/rpm',           # no RPM data
		'\/var\/lib\/zypp',          # no ZYPP data
		'\/var\/lib\/smart',         # no smart data
		'\/var\/log',                # no logs
		'\/var\/run',                # no pid files
		'\/media\/',                 # no media automount files
		'\/var\/lib\/hardware\/'     # no hwinfo hardware files
	);
	if (defined $excl) {
		my @exclude = @{$excl};
		foreach (@exclude) { $_ = quotemeta; };
		push @denyFiles,@exclude;
	}
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
	# TODO... make it nice as html page
	my $this       = shift;
	my $kiwi       = $this->{kiwi};
	my $dest       = $this->{dest};
	my $problem1   = $this->{solverProblem1};
	my $problem2   = $this->{solverProblem2};
	my $failedJob1 = $this->{solverFailedJobs1};
	my $failedJob2 = $this->{solverFailedJobs2};
	my $filechanges= $this->{filechanges};
	#==========================================
	# start report
	#------------------------------------------
	# package report...
	$kiwi -> info ("Migration Report\n");
	$kiwi -> info ("----------------\n");
	if ($problem1) {
		$kiwi -> info ("Following patterns couldn't be solved due to\n");
		$kiwi -> info ("dependency conflicts. Please check if your\n");
		$kiwi -> info ("repository setup contains a system repository\n");
		$kiwi -> info ("which matches the system you are about to migrate\n");
		$kiwi -> note ("$problem1");
	}
	if ($problem2) {
		$kiwi -> info ("Following packages couldn't be solved due to\n");
		$kiwi -> info ("dependency conflicts. Please check the conflicts\n");
		$kiwi -> info ("and solve them by either uninstalling the\n");
		$kiwi -> info ("package(s) from your system or skip them by using\n");
		$kiwi -> info ("the --skip option\n"); 
		$kiwi -> note ("$problem2");
	}
	if (@{$failedJob1}) {
		$kiwi -> info ("Following patterns couldn't be found in your\n");
		$kiwi -> info ("repository list but are marked as installed.\n");
		$kiwi -> info ("You can either ignore it or add a repository which\n");
		$kiwi -> info ("contains the mentioned patterns\n");
		foreach my $job (@{$failedJob1}) {
			$kiwi -> note ("$job\n");
		}
	}
	if (@{$failedJob2}) {
		$kiwi -> info ("Following packages couldn't be found in your\n");
		$kiwi -> info ("repository list but are installed on your system.\n");
		$kiwi -> info ("You can either ignore it or add a repository which\n");
		$kiwi -> info ("contains the mentioned packages\n");
		my @pacs = @{$failedJob2};
		my @list = qxx ("rpm -q @pacs --last"); chomp @list;
		foreach my $job (@list) {
			if ($job =~ /([^\s]+)\s+([^\s].*)/) {
				my $pac  = $1;
				my $date = $2;
				$kiwi -> note ("--> $pac\n\t$date\n");
			}
		}
	}
	# files report...
	#if ($filechanges) {
	#	my %result = %{$filechanges};
	#	my @rpmcheck = sort keys %result;
	#	$kiwi -> info ("Creating files report\n");
	#	if (! open (FD,">$dest/report-files")) {
	#		$kiwi -> failed ();
	#		$kiwi -> error  ("Couldn't create report file: $!");
	#		$kiwi -> failed ();
	#		return undef;
	#	}
	#	my @list = ();
	#	foreach my $file (@rpmcheck) {
	#		print FD $file."\0";
	#	}
	#	close FD;
	#	my $file = "$dest/report-files";
	#	my $prog = "du -ch --time --files0-from";
	#	my @data = qxx ("$prog $file 2>$dest/report-lost"); chomp @data;
	#	my $code = $? >> 8;
	#	if ($code == 0) {
	#		unlink "$dest/report-lost";
	#	}
	#	unlink $file;
	#	foreach my $line (@data) {
	#		$kiwi -> info ("$line\n");
	#	}
	#}
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
			if ($enabled eq "Yes") {
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
	# create root directory
	#------------------------------------------
	mkdir "$dest/root";
	#==========================================
	# create xml description
	#------------------------------------------
	if (! open (FD,">$dest/$main::ConfigName")) {
		return undef;
	}
	#==========================================
    # <description>
    #------------------------------------------
	print FD '<image schemaversion="3.8" ';
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
	print FD "\t\t".'<type boot="vmxboot/suse-'.$product.'" filesystem="ext3"';
	print FD ' format="vmdk">vmx</type>'."\n";
	print FD "\t\t".'<version>1.1.1</version>'."\n";
	print FD "\t\t".'<packagemanager>zypper</packagemanager>'."\n";
	print FD "\t\t".'<locale>en_US</locale>'."\n";
	print FD "\t\t".'<keytable>us.map.gz</keytable>'."\n";
	print FD "\t\t".'<timezone>Europe/Berlin</timezone>'."\n";
	print FD "\t\t".'<rpm-excludedocs>true</rpm-excludedocs>'."\n";
	print FD "\t\t".'<boot-theme>openSUSE</boot-theme>'."\n";
	print FD "\t".'</preferences>'."\n";
	#==========================================
	# <repository>
	#------------------------------------------
	foreach my $source (keys %{$osc{$product}} ) {
		my $type = $osc{$product}{$source}{type};
		my $alias= $osc{$product}{$source}{alias};
		my $prio = $osc{$product}{$source}{prio};
		print FD "\t".'<repository type="'.$type.'"';
		if (defined $alias) {
			print FD ' "alias="'.$alias.'"';
		}
		if ((defined $prio) && ($prio != 0)) {
			print FD ' "priority="'.$prio.'"';
		}
		print FD '>'."\n";
		print FD "\t\t".'<source path="'.$source.'"/>'."\n";
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
	# Find the version information of this system an create
	# a xml description comment in order to allow to choose the
	# correct installation source
	# ---
	my $this = shift;
	my @data = qxx ("zypper --no-refresh products --installed 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		return undef;
	}
	if ($data[4] =~ /.*(\d\d\.\d)-.*/) {
		return $1;
	}
	return undef
}

#==========================================
# setServiceList
#------------------------------------------
sub setServiceList {
	# ...
	# Find all services enabled on the system and create
	# an appropriate config.sh file
	# ---
	my $this = shift;
	my $dest = $this->{dest};
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
	foreach my $service (@result) {
		print FD 'suseInsertService '.$service."\n";
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
	my %osc     = %{$this->{source}};
	my @urllist = ();
	my @patlist = ();
	my %problem = ();
	my $code;
	my @ilist;
	#==========================================
	# find all rpm's installed
	#------------------------------------------
	undef $this->{patterns};
	undef $this->{packages};
	$kiwi -> info ("Searching installed packages...");
	@ilist = qxx ('rpm -qa --qf "%{NAME}\n" | sort | uniq'); chomp @ilist;
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to obtain installed packages");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
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
		$kiwi -> info ("Creating System solvable from active repos...");
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
		$kiwi->done();
		$this->{solverProblem1}    = $psolve -> getProblemInfo();
		$this->{solverFailedJobs1} = $psolve -> getFailedJobs();
		if ($psolve -> getProblemsCount()) {
			$kiwi -> warning ("Pattern problems found check in report !\n");
		}
		if (defined $skip) {
			foreach my $s (@{$skip}) {
				$problem{$s} = $s;
			}
		}
		my @packageList = $psolve -> getPackages();
		foreach my $installed (@ilist) {
			next if ($problem{$installed});
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
	$this->{mount} = "/kiwiroot";
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
	my $this = shift;
	my $dest = $this->{dest};
	my $kiwi = $this->{kiwi};
	my $rdev = $this->{rdev};
	my $mount= $this->{mount};
	my @deny = @{$this->{deny}};
	my $cache= $dest.".cache";
	my $cdata;
	my $checkopt;
	my @rpmlist;
	my @rpmcheck;
	my %result;
	my $data;
	my $code;
	#==========================================
	# check for cache file
	#------------------------------------------
	if (! -f $cache) {
		undef $cache;
	} else {
		$kiwi -> info ("Using cache file: $cache\n");
		$kiwi -> info ("Remove cache file if your system has changed !\n");
		$cdata = retrieve($cache);
	}
	#==========================================
	# mount root system
	#------------------------------------------
	if (! $cache) {
		if (! -d $mount && ! mkdir $mount) {
			$kiwi -> error  ("Failed to create kiwi root mount point: $!");
			$kiwi -> failed ();
			return undef;
		}
		$data = qxx ("mount $rdev $mount 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Failed to mount root system: $data");
			$kiwi -> failed ();
			return undef;
		}
	}
	$this->{mounted} = $code;
	#==========================================
	# generate File::Find closure
	#------------------------------------------
	sub generateWanted {
		my $filehash = shift;
		my $mount    = shift;
		return sub {
			if (! -d $File::Find::name) {
				my $expr = quotemeta $mount;
				my $file = $File::Find::name; $file =~ s/$expr//;
				my $dirn = $File::Find::dir;  $dirn =~ s/$expr//;
				$filehash->{$file} = $dirn;
			}
		}
	};
	#==========================================
	# Find files not packaged
	#------------------------------------------
	$kiwi -> info ("Inspecting root file system...\n");
	if ($cache) {
		%result = %{$cdata->{result}};
	} else {
		my $wref = generateWanted (\%result,$mount);
		find ({ wanted => $wref, follow => 0 }, $mount );
		$this -> cleanMount();
		$cdata->{result} = \%result;
	}
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
	my $spart = 100 / $cursize;
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
		$checkopt = "--nodeps --nodigest --nosignature ";
		$checkopt.= "--nolinkto --nouser --nogroup --nomode";
		@rpmcheck = qxx ("rpm -Va $checkopt"); chomp @rpmcheck;
		$cdata->{rpmcheck} = \@rpmcheck;
	}
	$rpmsize = @rpmcheck;
	$spart = 100 / $rpmsize;
	$count = 1;
	$kiwi -> cursorOFF();
	foreach my $check (@rpmcheck) {
		if ($check =~ /^(\/.*)/) {
			my $file = $1;
			my $dir  = dirname ($file);
			my $ok   = 1;
			foreach my $exp (@deny) {
				if ($file =~ /$exp/) {
					$ok = 0; last;
				}
			}
			if ($ok) {
				$result{$file} = $dir;
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
	# Create hard link list
	#------------------------------------------
	$kiwi -> info ("Creating link list...");
	$data = qxx ("mkdir -p $dest/root 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create overlay root directory: $data");
		$kiwi -> failed ();
		return undef;
	}
	# make directory structure...
	print "++++ making directory structure...\n";
	my %files = ();
	my %paths = ();
	foreach my $file (keys %result) {
		$file = quotemeta ($file);
		my ($name,$path,$suffix) = fileparse ($file);
		$paths{$path} = $path;
		if ($name) {
			$files{$file} = $path;
		}
	}
	foreach my $path (keys %paths) {
		qxx ("mkdir -p $dest/root/$path 2>&1");
	}
	# make links
	print "++++ making links...\n";
	foreach my $file (keys %files) {
		my $path = $files{$file};
		$data = qxx ("ln -t $dest/root/$path $file 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> warning ("hard link for $file failed: $data");
			$kiwi -> skipped ();
		}
	}
	#==========================================
	# Cleanup symbolic links
	#------------------------------------------
	$kiwi -> info ("Cleaning symlinks...");
	$this -> checkBrokenLinks();
	$kiwi -> done();
	$this->{filechanges} = \%result;
	$this->{filecheck}   = \@rpmcheck;
	return $this;
}

#==========================================
# setInitialSetup
#------------------------------------------
sub setInitialSetup {
	# ...
	# During first deployment of the migrated image we will call
	# the second phase of the YaST2 installation workflow. This step
	# takes care for the hardware detection/configuration which may
	# have changed because of another system environment.
	# ---
	# 1) create a framebuffer based xorg.conf file
	# 2) create the file /var/lib/YaST2/runme_at_boot
	# ---
	my $this = shift;
	my $dest = $this->{dest};
	my $kiwi = $this->{kiwi};
	$kiwi -> info ("Setting up initial deployment workflow...");
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
	#==========================================
	# Activate YaST on initial deployment
	#------------------------------------------
	qxx ("touch $dest/root/var/lib/YaST2/runme_at_boot");
	$kiwi -> done();
	return $this;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	my $this = shift;
	my $mount= $this->{mount};
	if (defined $this->{mounted}) {
		qxx ("umount $mount"); undef $this->{mounted};
	}
	if (-d $mount) {
		rmdir $mount;
	}
	return $this;
}

#==========================================
# checkBrokenLinks
#------------------------------------------
sub checkBrokenLinks {
	# ...
	# the tree could contain broken symbolic links because
	# the target is unmodified and part of a package. The
	# broken links will be removed in this function and it
	# is assumed that a post install script of the package
	# creates this links when the package gets installed
	# in the kiwi prepare mode. If the links are created
	# manually or by an application at system installation
	# for example the links needs to be created in a
	# separate image description config.sh script 
	# ---   
	my $this = shift;
	my $dest = $this->{dest};
	my $kiwi = $this->{kiwi};
	my @link = qxx ("find $dest/root -type l");
	my $returnok = 1;
	my $dir;
	foreach my $linkfile (@link) {
		chomp $linkfile;
		my $ref = readlink ($linkfile);
		if ($ref !~ /^\//) {
			$dir = dirname ($linkfile);
			$dir.= "/";
		} else {
			$dir = $dest."/root";
		}
		if (! -e $dir.$ref) {
			$kiwi -> loginfo ("Broken link: $linkfile -> $ref [ REMOVED ]");
			unlink $linkfile;
			$returnok = 0;
		}
	}
	if ($returnok) {
		return $this;
	}
	checkBrokenLinks ($this);
}

1;
