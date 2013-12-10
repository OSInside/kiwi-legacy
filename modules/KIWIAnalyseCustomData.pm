#================
# FILE          : KIWIAnalyseCustomData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide methods for
#               : searching custom data not managed by any
#               : package manager
#               :
#               :
#               :
# STATUS        : Development
#----------------
package KIWIAnalyseCustomData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use Data::Dumper;
use FileHandle;
use File::Find;
use File::stat;
use File::Basename;
use File::Path;
use File::Copy;
use File::Spec;
use Fcntl ':mode';
use Cwd qw (abs_path cwd);
use File::Slurp;

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
	# Create a new KIWIAnalyseCustomData object which is used to
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
	my $dest    = shift; # destination directory
	my $excl    = shift; # list reference to exclude items
	my $skipgem = shift; # skip gem lookup
	my $skiprcs = shift; # skip revision control system lookup
	my $skipaug = shift; # skip augeas managed files lookup
	my $cdata   = shift; # cache reference
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if ((! defined $dest) || (! -d $dest)) {
		$kiwi -> error  (
			"KIWIAnalyseCustomData: Couldn't find destination dir: $dest"
		);
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store default files not used for inspect
	#------------------------------------------
	my $global = KIWIGlobals -> instance();
	$this->{gdata} = $global -> getKiwiConfig();
	my @denyFiles = ();
	my $FD = FileHandle -> new();
	if (! $FD -> open ($this->{gdata}->{KAnalyseSkip})) {
		$kiwi -> error  (
			"KIWIAnalyseCustomData: Couldn't open custom exception data"
		);
		$kiwi -> failed ();
		return;
	}
	while (my $line = <$FD>) {
		next if ($line =~ /^#/);
		chomp $line;
		push @denyFiles,$line;
	}
	$FD -> close();
	if (defined $excl) {
		my @exclude = @{$excl};
		foreach (@exclude) {
			$_ =~ s/\/$//;
			$_ = quotemeta;
		};
		push @denyFiles,@exclude;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}    = $kiwi;
	$this->{deny}    = \@denyFiles;
	$this->{dest}    = $dest;
	$this->{skipgem} = $skipgem;
	$this->{skiprcs} = $skiprcs;
	$this->{skipaug} = $skipaug;
	$this->{cdata}   = $cdata;
	return $this;
}

#==========================================
# runQuery
#------------------------------------------
sub runQuery {
	my $this = shift;
	return $this -> __populateCustomFiles();
}

#==========================================
# createCustomFileTree
#------------------------------------------
sub createCustomFileTree {
	# ...
	# create directory with hard/soft links to custom files
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $dest = $this->{dest};
	my $result_ref = $this->{nopackage};
	if (! $result_ref) {
		return;
	}
	my %result = %{$result_ref};
	#==========================================
	# Create custom (unpackaged) files tree
	#------------------------------------------
	$kiwi -> info ("Creating custom/unpackaged meta data...");
	$kiwi -> cursorOFF();
	my %filelist;
	my @dirslist;
	my @itemlist = sort keys %result;
	my $tasks = @itemlist;
	my $factor = 100 / $tasks;
	my $done_percent = 0;
	my $done_previos = 0;
	my $done = 0;
	foreach my $file (@itemlist) {
		my $fattr = $result{$file}->[1];
		my $type  = "file";
		my $key   = "/";
		my $binary= 0;
		# /.../
		# for performance reasons we only check for the
		# ELF header which identifies the Linux binary format
		# ----
		if (($fattr) && (S_ISREG($fattr->mode))) {
			if (sysopen (my $fd,$file,O_RDONLY)) {
				my $buf;
				seek ($fd,1,0);
				sysread ($fd,$buf,3);
				close ($fd);
				if ($buf eq 'ELF') {
					$binary = 1;
				}
			}
		}
		# /.../
		# The following code is more accurate but way too slow
		# $binary = 1;
		# my $magic = KIWIQX::qxx ("file \"$file\" 2>&1");
		# if ($magic =~ /text|character data/) {
		#	$binary = 0;
		# }
		# ----
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
		$fattr->[13] = $binary;
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	$kiwi -> info ("Creating custom/unpackaged files tree...");
	$kiwi -> cursorOFF();
	$factor = 100 / $tasks;
	$done_percent = 0;
	$done_previos = 0;
	$done = 0;
	KIWIQX::qxx ("rm -rf $dest/custom 2>&1");
	foreach my $dir (sort keys %filelist) {
		next if ! %{$filelist{$dir}};
		if (! -d "$dest/custom/$dir") {
			mkpath ("$dest/custom/$dir", {verbose => 0});
		}
		next if ! chdir "$dest/custom/$dir";
		foreach my $file (sort keys %{$filelist{$dir}}) {
			if (-e "$dir/$file") {
				if (! link "$dir/$file", "$file") {
					symlink "$dir/$file", "$file";
				}
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
	return $this;
}

#==========================================
# diffChangedConfigFiles
#------------------------------------------
sub diffChangedConfigFiles {
	# ...
	# diff all configuration files changed by the user
	# against the originals and store the result
	# in 'changed_config.diff'
	# ---
	my $this  = shift;
	my $dest  = $this->{dest};
	my $kiwi  = $this->{kiwi};
	my $cdata = $this->{cdata};
	my $original_conf = $cdata->{original_conf};
	my $result = 1;
	if (! %$original_conf) {
		return $this;
	}
	$kiwi -> info ("Create diff for changed config files...");
	my $diff_file = "$dest/changed_config.diff";
	if (-e $diff_file) {
		KIWIQX::qxx ("rm -rf '$diff_file' 2>&1");
	}
	my $tmpdir = KIWIQX::qxx ("mktemp -qdt kiwi-analyse.XXXXXX");
	chomp $tmpdir;
	while ( my ($file, $entry) = each(%$original_conf) ) {
		unless ($entry->{'content'}) {
			$kiwi -> failed();
			$kiwi -> info("--> Couldn't create diff for $file");
			$result = 0;
			next;
		}
		my $filename = "$tmpdir$file";
		my $dirn     = dirname($filename);
		KIWIQX::qxx ("mkdir -p '$dirn'");
		write_file( $filename, $entry->{'content'} );
		utime($entry->{'atime'}, $entry->{'mtime'}, $filename);
		KIWIQX::qxx ("diff -uN '$tmpdir$file' '$file' >> '$diff_file'");
	}
	KIWIQX::qxx ("rm -rf '$tmpdir' 2>&1");
	if ($result == 0) {
		$kiwi -> failed();
		return;
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# getCustomFiles
#------------------------------------------
sub getCustomFiles {
	my $this = shift;
	return $this->{nopackage};
}

#==========================================
# getLocalRepositories
#------------------------------------------
sub getLocalRepositories {
	my $this = shift;
	return $this->{localrepos};
}

#==========================================
# createDatabaseDump
#------------------------------------------
sub createDatabaseDump {
	# ...
	# check for running databases and if available
	# dump the content to a file
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $dest = $this->{dest};
	my $db_test_cmd;
	my $db_type;
	my $dump_cmd;
	my $dump_ext;
	my $target;
	my $result;
	my $status;
	$dest .= "/root/var/cache/dbs";
	$kiwi -> info ("Checking for running databases...\n");
	foreach my $db_type ('mysql') {
		#========================================
		# initialize db values
		#----------------------------------------
		if ($db_type eq 'mysql') {
			$db_test_cmd = "mysqladmin ping";
			$dump_cmd    = "mysqldump -p -u root --all-databases --events";
			$dump_ext    = 'sql';
		} else { 
			$kiwi -> error  ("DB $db_type unknown.");
			$kiwi -> failed ();
			return;
		}
		$target = "$dest/$db_type.$dump_ext";
		#========================================
		# check for running db
		#----------------------------------------
		$status = KIWIQX::qxx ("$db_test_cmd 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> info (
				"--> No running $db_type db found, ignoring..."
			);
			$kiwi -> skipped ();
			next;
		}
		#========================================
		# dump db content and compress it
		#----------------------------------------
		$kiwi -> info ("--> Found $db_type db, dumping contents...");
		$status = KIWIQX::qxx ("mkdir -p $dest && $dump_cmd > $target 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> loginfo ($status);
			next;
		} else {
			$kiwi -> done();
		}
		$kiwi -> info ("--> Compressing database [ $target.gz ]...");
		$status = KIWIQX::qxx ("$this->{gdata}->{Gzip} -f $target 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> loginfo ($status);
		} else {
			$kiwi -> done();
		}
	}
	return $this;
}

#==========================================
# __populateCustomFiles
#------------------------------------------
sub __populateCustomFiles {
	# ...
	# 1) Find all files not owned by any package
	# 2) Find all files changed according to the package manager
	# 3) create linked list of the result
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my @deny   = @{$this->{deny}};
	my $cdata  = $this->{cdata};
	my $checkopt;
	my %result;
	my $data;
	my $code;
	my @modified;
	my $original_conf = {};
	my $root = "/";
	#==========================================
	# Find files packaged but changed
	#------------------------------------------
	$kiwi -> info ("Inspecting RPM database [modified files]...");
	if (($cdata) && ($cdata->{modified}) && ($cdata->{original_conf})) {
		@modified = @{$cdata->{modified}};
		$original_conf = $cdata->{original_conf};
		$kiwi -> done(); 
	} else {
		$checkopt = "--nodeps --nodigest --nosignature --nomtime ";
		$checkopt.= "--nolinkto --nouser --nogroup --nomode";
		my $rpmcheck = KIWIQX::qxx ("rpm -Va $checkopt");
		my @rpmcheck = split(/\n/,$rpmcheck);
		my $rpmsize = @rpmcheck;
		my $spart = 100 / $rpmsize;
		my $count = 1;
		my $done;
		my $done_old;
		$kiwi -> cursorOFF();
		foreach my $check (@rpmcheck) {
			if ($check =~ /^..(.).+\s+(.)\s(\/.*)$/) {
				my $has_changed = ($1 eq "5");
				my $is_config = ($2 eq "c");
				my $file = $3;
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
					if (($has_changed) && ($is_config)) {
						my $package = KIWIQX::qxx ("rpm -qf '$file'");
						chomp $package;
						$original_conf->{$file}->{'package'} = $package;
					}
				}
			}
			$done = int ($count * $spart);
			if (($done_old) && ($done != $done_old)) {
				$kiwi -> step ($done);
			}
			$done_old = $done;
			$count++;
		}
		$cdata->{modified} = \@modified;
		$kiwi -> note ("\n");
		$kiwi -> doNorm ();
		$kiwi -> cursorON();
		#==========================================
		# download originals of changed conf. files
		#------------------------------------------
		$cdata->{original_conf} = \%{$original_conf};
		if (%{$original_conf}) {
			$this -> __getOriginalConfigFiles();
		}
	}
	#==========================================
	# Find files/directories not packaged
	#------------------------------------------
	$kiwi -> info ("Inspecting package database(s) [unpackaged files]\n");
	my @rpmcheck = ();
	if (($cdata) && ($cdata->{rpmlist})) {
		$kiwi -> info ("--> reading RPM package list from cache...");
		@rpmcheck = @{$cdata->{rpmlist}};
	} else {
		$kiwi -> info ("--> requesting RPM package list...");
		my $rpmcheck = KIWIQX::qxx ("rpm -qlav");
		@rpmcheck = split(/\n/,$rpmcheck);
		$cdata->{rpmlist} = \@rpmcheck;
	}
	my @rpm_dir  = ();
	my @rpm_file = ();
	# /.../
	# lookup rpm database files...
	# ----
	$kiwi -> done ();
	$kiwi -> info ("--> resolving RPM items to absolute paths...");
	foreach my $dir (@rpmcheck) {
		if ($dir =~ /^d.*?\/(.*)$/) {
			# applies to all directories from the rpm database
			my $base = $1;
			my $name = basename $base;
			my $dirn = dirname  $base;
			$dirn = abs_path ("/$dirn");
			if ($dirn) {
				$base = "$dirn/$name";
			} else {
				$base = "/$name";
			}
			$base =~ s/\/+/\//g;
			$base =~ s/^\///;
			next if $base eq './';
			push @rpm_dir ,$base;
		} elsif ($dir =~ /.*?\/(.*?)( -> .*)?$/) {
			# applies to all files/link from the rpm database
			my $base = $1;
			my $name = basename $base;
			my $dirn = dirname  $base;
			$dirn = abs_path ("/$dirn");
			if ($dirn) {
				$base = "$dirn/$name";
			} else {
				$base = "/$name";
			}
			$base =~ s/\/+/\//g;
			$base =~ s/^\///;
			next if $base eq './';
			push @rpm_file,$base;
		}
	}
	$kiwi -> done();
	# /.../
	# fake gem contents as rpm files...
	# ----
	if ((! $this->{skipgem}) && (-x "/usr/bin/gem")) {
		$kiwi -> info ("--> requesting GEM package list...");
		my $gemcheck = KIWIQX::qxx ("gem contents --all");
		my @gemcheck = split(/\n/,$gemcheck);
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
	# /.../
	# find files in packaged directories:
	# 1. convert directory list into dirs_cmp hash
	# 2. create uniq and sorted directory list from dirs_cmp
	# 3. apply deny expressions on the final directory list
	# 4. call find and return %result hash
	# ----
	$kiwi -> info ("searching files in packaged directories...\n");
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
		if (($ok) && (-d $dir)) {
			push @packaged_dirs_new,$dir;
		}
	}
	@packaged_dirs = @packaged_dirs_new;
	$kiwi -> snip ("--> Processing...");
	my $wref = __generateWanted (\%result);
	find({ wanted => $wref, follow => 0 }, @packaged_dirs);
	# /.../
	# reduce the amount of items in %result by the managed items
	# from the %file_rom and %dirs_rpm hashes
	# ----
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
	$kiwi -> snap();
	# /.../
	# reduce the amount of item in %result by those symlinks
	# whose origin is packaged because they are recreated on
	# install of that package
	# ----
	$kiwi -> info ("--> searching symlinks whose origin is packaged...");
	foreach my $file (sort keys %result) {
		if (-l $file) {
			my $origin = readlink $file;
			my $dirn = dirname $file;
			my $path = $dirn."/".$origin;
			my $base = basename $path;
			$dirn = dirname $path;
			$dirn = $this -> __resolvePath ($dirn);
			$path = $dirn."/".$base;
			if (exists $result{$path}) {
				delete $result{$file};
			}
		}
	}
	$kiwi -> done();
	# /.../
	# walk through the list of managed directories and check if
	# there are subdirectories which does not belong to managed
	# directories and add those to the %result hash
	# ----
	$kiwi -> info ("--> searching unpackaged directories...");
	foreach my $dir (sort keys %dirs_cmp) {
		my $FH;
		next if ! opendir ($FH,$dir);
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
	#==========================================
	# add custom deny rules
	#------------------------------------------
	my @custom_deny = ();
	#==========================================
	# check for local repository checkouts
	#------------------------------------------
	if (! $this->{skiprcs}) {
		$kiwi -> info ("Searching for revision control checkout(s)...");
		my %repos = ();
		foreach my $file (sort keys %result) {
			if ($file =~ /\.osc$/) {
				#==========================================
				# buildservice repo
				#------------------------------------------
				my $dir = $file;
				my $add = 1;
				$dir =~ s/\/\.osc$//;
				foreach my $rule (@custom_deny) {
					if ($dir =~ /$rule/) {
						$add = 0; last;
					}
				}
				if ($add) {
					push @custom_deny,'^'.$dir;
					$repos{$dir} = "buildservice";
				}
			} elsif ($file =~ /\.git$/) {
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
		$this->{localrepos} = \%repos;
		$kiwi -> done();
	}
	#==========================================
	# ignore files managed by augeas
	#------------------------------------------
	if (! $this->{skipaug}) {
		my $locator = KIWILocator -> instance();
		my $augtool = $locator -> getExecPath('augtool');
		if ($augtool) {
			my %aug_files;
			my $fd = FileHandle -> new();
			if ($fd -> open ("$augtool print /files/*|")) {
				while (my $line = <$fd>) {
					if ($line =~ /^\/files(.*)\/.*=/) {
						my $file = $1;
						if (-e $file) {
							$aug_files{$file} = 1;
						}
					}
				}
			}
			$fd -> close();
			foreach my $file (sort keys %aug_files) {
				push @custom_deny,$file;
			}
		}
	}
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
	# Ignore empty directories
	#------------------------------------------
	$kiwi -> info ("Checking for empty directories...");
	# /.../
	# store empty directories in %checkDirs
	# ----
	my $checkDirs;
	foreach my $file (sort keys %result) {
		my $sys_file = '/'.$file;
		if ((-d $sys_file) && ($this -> __isEmptyDir ($sys_file))) {
			$checkDirs->{$file} = $file;
			delete $result{$file};
		}
	}
	# /.../
	# store empty dirs and subdirs of empty directories in @checkList
	# ----
	my @checkList = ();
	while ($checkDirs) {
		my $checkDirsNext;
		foreach my $check (sort keys %{$checkDirs}) {
			my $pre_dir = dirname $check;
			if ($pre_dir ne '/') {
				$checkDirsNext->{$pre_dir} = $pre_dir;
			}
		}
		if (! $checkDirsNext) {
			undef $checkDirs;
			last;
		}
		$checkDirs = $checkDirsNext;
		foreach my $check (sort keys %{$checkDirs}) {
			push @checkList,$check;
		}
	}
	# /.../
	# walk through items in checkList and remove if substr occurs only once
	# ----
	my $tasks = @checkList;
	if ($tasks == 0) {
		$tasks = 1;
	}
	my $factor = 100 / $tasks;
	my $done_percent = 0;
	my $done_previos = 0;
	my $done = 0;
	$kiwi -> cursorOFF();
	my @fileList = sort keys %result;
	foreach my $check (@checkList) {
		my $count = 1;
		foreach my $file (@fileList) {
			if (index($file, $check.'/') != -1) {
				$count = 2; last;
			}
		}
		if ($count == 1) {
			delete $result{$check};
		}
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	#==========================================
	# Store in instance for report
	#------------------------------------------
	$this->{nopackage}  = \%result;
	return $this;
}

#==========================================
# __getOriginalConfigFiles
#------------------------------------------
sub __getOriginalConfigFiles {
	# ...
	# 1) Download all packages which configuration files where changed
	# 2) Extract the packages and store the configuration files in cache
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $cdata  = $this->{cdata};
	my $original_conf = $cdata->{original_conf};
	#==========================================
	# Get packages for changed configuration
	#------------------------------------------
	my @packages;
	$kiwi -> info ("Downloading packages of changed configuration files...");
	while ( my ($file, $entry) = each(%$original_conf) ) {
		my $package = $entry->{'package'};
		push(@packages, $package) unless grep{$_ eq $package} @packages;
	}
	#==========================================
	# Download and extract packages
	#------------------------------------------
	my $packages = @packages;
	my $spart = 100 / $packages;
	my $count = 1;
	my $done;
	my $done_old;
	my $status;
	my $result = 1;
	$kiwi -> cursorOFF();
	my $tmpdir = KIWIQX::qxx ("mktemp -qdt kiwi-analyse.XXXXXX");
	chomp $tmpdir;
	my $cwd = cwd();
	chdir $tmpdir;
	foreach my $package (@packages) {
		my $pck_path = KIWIQX::qxx (
			"find /var/cache/zypp/packages/ -name '$package*'"
		);
		chomp $pck_path;
		my $does_exist = (-e $pck_path) ? 1 : 0;
		$status = KIWIQX::qxx ("zypper install -dfy $package 2>&1");
		$pck_path = KIWIQX::qxx (
			"find /var/cache/zypp/packages/ -name '$package*'"
		);
		chomp $pck_path;
		unless ( -e $pck_path) {
			$kiwi -> loginfo ($status);
			$kiwi -> failed();
			$kiwi -> info ("--> The package $package couldn't be downloaded");
			$result = 0;
			next;
		}
		KIWIQX::qxx ("rpm2cpio '$pck_path' | cpio -idm 2>/dev/null");
		unless ($does_exist) {
			KIWIQX::qxx ("rm -f '$pck_path'");
		}
		$done = int ($count * $spart);
		if (($done_old) && ($done != $done_old)) {
			$kiwi -> step ($done);
		}
		$done_old = $done;
		$count++;
	}
	chdir $cwd;
	($result) ? $kiwi -> note ("\n") : $kiwi -> failed();
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	#==========================================
	# Store original config files in cache
	#------------------------------------------
	while ( my ($file, $entry) = each(%$original_conf) ) {
		if ( -e "$tmpdir$file") {
			my $content = read_file( "$tmpdir$file" ) ;
			my $sb = stat("$tmpdir$file");
			$original_conf->{ $file }->{ 'atime' }   = $sb->atime;
			$original_conf->{ $file }->{ 'mtime' }   = $sb->mtime;
			$original_conf->{ $file }->{ 'content' } = $content;
		}
	}
	KIWIQX::qxx ("rm -rf '$tmpdir' 2>&1");
	$cdata->{original_conf} = \%{$original_conf};
	return $this;
}

#==========================================
# __resolvePath
#------------------------------------------
sub __resolvePath {
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
		if (@path) {
			my @path_new;
			foreach my $p (@path) {
				if ($p) {
					push @path_new,$p
				}
			}
			$current = join ("/",@path_new);
		}
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

#==========================================
# __generateWanted
#------------------------------------------
sub __generateWanted {
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
# __isEmptyDir
#------------------------------------------
sub __isEmptyDir {
	my $this  = shift;
	my $ldir  = shift;
	my $empty = 1;
	my $dh;
	opendir($dh, $ldir) || return $empty;
	readdir ($dh);
	readdir ($dh);
	if (readdir ($dh)) {
		$empty = 0;
	}
	closedir $dh;
	return $empty;
}

1;

# vim: set noexpandtab:
