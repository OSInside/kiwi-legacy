#================
# FILE          : KIWIAnalyseSystem.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2014 SUSE LINUX Products GmbH, Germany
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
package KIWIAnalyseSystem;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use FileHandle;
use File::stat;
use File::Path;
use Fcntl ':mode';
use POSIX qw( strftime );
use Storable;
use JSON;

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
	# Create a new KIWIAnalyseSystem object which is used
	# to provide the base information and files to create
	# s system description from the running machine
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
	my $destdir = shift;
	my $cmdL    = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi   = KIWILog -> instance();
	my $global = KIWIGlobals -> instance();
	my $code;
	my $data;
	my $cleanup = $cmdL -> getForceNewRoot();
	my $mail = 'kiwi-images@googlegroups.com';
	if (defined $cleanup) {
		KIWIQX::qxx ("rm -rf $destdir");
	}
	if (-d $destdir) {
		$kiwi -> info ("Using already existing destination dir");
		$kiwi -> done();
	} else {
		$data = KIWIQX::qxx ("mkdir $destdir 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Couldn't create destination dir: $data");
			$kiwi -> failed ();
			return;
		}
		$data = KIWIQX::qxx ("git init $destdir 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("git init failed: $data");
			$kiwi -> failed ();
			return;
		}
		$data = KIWIQX::qxx (
			"cd $destdir && git config user.email \"$mail\" 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("git config failed: $data");
			$kiwi -> failed ();
			return;
		}
		$data = KIWIQX::qxx (
			"cd $destdir && git config user.name \"KIWI\" 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("git config failed: $data");
			$kiwi -> failed ();
			return;
		}
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$destdir/.gitignore")) {
			$kiwi -> error  ("Couldn't create .gitignore: $!");
			$kiwi -> failed ();
			return;
		}
		print $FD 'custom'."\n";
		$FD -> close();
	}
	$destdir =~ s/\/$//;
	$kiwi -> info ("Results will be written to: $destdir");
	$kiwi -> done ();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{gdata}   = $global -> getKiwiConfig();
	$this->{kiwi}    = $kiwi;
	$this->{destdir} = $destdir;
	$this->{cmdL}    = $cmdL;
	#==========================================
	# Open the cache
	#------------------------------------------
	my %cdata;
	my $cdata = \%cdata;
	my $cache = $destdir.".cache";
	if (-f $cache) {
		$kiwi -> info ("Open cache file: $cache\n");
		my $cdata_cur = retrieve($cache);
		if (! $cdata_cur) {
			$kiwi -> warning ("--> Failed to open cache file");
			$kiwi -> skipped ();
		} elsif (! $cdata_cur->{version}) {
			$kiwi -> warning ("--> Cache doesn't provide version");
			$kiwi -> skipped ();
		} elsif ($cdata_cur->{version} ne $this->{gdata}->{Version}) {
			$kiwi -> warning ("--> Cache version doesn't match");
			$kiwi -> skipped ();
		} elsif (
			(! $cdata_cur->{rpm_dump}) ||
			(! $cdata_cur->{rpm_pack}) ||
			(! $cdata_cur->{rpm_modc})
		) {
			$kiwi -> warning ("--> Cache is missing mandatory data");
			$kiwi -> skipped ();
		} elsif ($cdata_cur->{rpmdbsum}) {
			my $rpmdb = '/var/lib/rpm/Packages';
			if (-e $rpmdb) {
				my $dbsum = KIWIQX::qxx (
					"cat $rpmdb | md5sum - | cut -f 1 -d-"
				);
				chomp $dbsum;
				if ($dbsum ne $cdata_cur->{rpmdbsum}) {
					$kiwi -> warning ("--> RPM database has changed");
					$kiwi -> skipped ();
				} else {
					$kiwi -> info ("--> Using cache file\n");
					$cdata = $cdata_cur;
				}
			} else {
				$kiwi -> warning ("--> RPM database not found");
				$kiwi -> oops();
				$kiwi -> info ("--> Using possibly outdated cache file\n");
				$cdata = $cdata_cur;
			}
		} else {
			$kiwi -> info ("--> Using cache file\n");
			$cdata = $cdata_cur;
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{cdata} = $cdata;
	$this->{rpm_dump} = '/tmp/rpm_dump';
	$this->{rpm_pack} = '/tmp/rpm_packages';
	$this->{rpm_modc} = '/tmp/rpm_modified';
	$this->{custom}   = '/tmp/rpm_unmanaged';
	#==========================================
	# Initialize
	#------------------------------------------
	if (! $this -> __dumpRPMDatabase()) {
		return;
	}
	if (! $this -> __dumpCustomData()) {
		return;
	}
	return $this;
}

#==========================================
# commitTransaction
#------------------------------------------
sub commitTransaction {
	my $this = shift;
	my $dest = $this->{destdir};
	my $kiwi = $this->{kiwi};
	my $text = '- automatic transaction commit';
	my $data = KIWIQX::qxx ("cd $dest && git add . 2>&1");
	my $code = $? >> 8;
	if ($code == 0) {
		$data = KIWIQX::qxx ("cd $dest && git commit -a -m \"$text\" 2>&1");
		$code = $? >> 8;
	}
	return $code;
}

#==========================================
# getDestination
#------------------------------------------
sub getDestination {
	my $this = shift;
	return $this->{destdir};
}

#==========================================
# getCache
#------------------------------------------
sub getCache {
	my $this = shift;
	return $this->{cdata};
}

#==========================================
# writeCache
#------------------------------------------
sub writeCache {
	my $this  = shift;
	my $cdata = $this->{cdata};
	my $kiwi  = $this->{kiwi};
	my $dest  = $this->{destdir};
	if (! $cdata) {
		return;
	}
	$kiwi -> info ("Writing cache file...");
	my $rpmdb = '/var/lib/rpm/Packages';
	if (-e $rpmdb) {
		my $dbsum = KIWIQX::qxx ("cat $rpmdb | md5sum - | cut -f 1 -d-");
		chomp $dbsum;
		$cdata->{rpmdbsum} = $dbsum;
	}
	$cdata->{version} = $this->{gdata}->{Version};
	store ($cdata,$dest.".cache");
	$this->{cdata} = $cdata;
	$kiwi -> done();
	return $this;
}

#==========================================
# getKernelVersion
#------------------------------------------
sub getKernelVersion {
	my $this = shift;
	my $kernel = KIWIQX::qxx ('uname -r');
	chomp $kernel;
	return $kernel;
}

#==========================================
# getKernelPackages
#------------------------------------------
sub getKernelPackages {
	my $this   = shift;
	my $kernel = $this -> getKernelVersion();
	if (! -e "/lib/modules/$kernel") {
		return;
	}
	my $list = KIWIQX::qxx (
		"rpm -qf --qf \"%{NAME}:%{VERSION}\\n\" /lib/modules/$kernel"
	);
	my @list = split(/\n/,$list);
	return @list;
}

#==========================================
# getHardwareDependantPackages
#------------------------------------------
sub getHardwareDependantPackages {
	my $this = shift;
	my %modalias;
	if ($this->{getHardwareDependantPackages_result}) {
		return $this->{getHardwareDependantPackages_result};
	}
	my $pack_call = KIWIQX::qxx (
		"rpm -qa --qf '\n<%{name}>\n' --supplements"
	);
	my @pack_list = split(/\n/,$pack_call);
	my $cur_pack;
	foreach my $item (@pack_list) {
		if ($item =~ /^<(.+)>/) {
			$cur_pack = $1;
		}
		if ($item =~ /^modalias/) {
			push @{$modalias{$cur_pack}}, $item;
		}
	}
	$this->{getHardwareDependantPackages_result} = \%modalias;
	return \%modalias;
}

#==========================================
# getInstalledPackages
#------------------------------------------
sub getInstalledPackages {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $rpm_pack = $this->{rpm_pack};
	my %result = ();
	my @skip = (
		'gpg-pubkey.*'
	);
	if ($this->{getInstalledPackages_result}) {
		return $this->{getInstalledPackages_result};
	}
	if (! -f $rpm_pack) {
		return;
	}
	my $pack = FileHandle -> new();
	if (! $pack -> open ($rpm_pack)) {
		$kiwi -> error  ("Couldn't read $rpm_pack: $!");
		$kiwi -> failed ();
		return;
	}
	while (my $line = <$pack>) {
		chomp $line;
		my ($name,$distribution,$disturl,$url,$installtime) = split(/\|/,$line);
		my $prune = 0;
		foreach my $skip_pattern (@skip) {
			if ($name =~ /$skip_pattern/) {
				$prune = 1;
				last;
			}
		}
		next if $prune;
		if (! $result{$name}) {
			$result{$name}{count} = 1;
		} else {
			$result{$name}{count}++;
		}
		$result{$name}{distribution} = $distribution;
		$result{$name}{disturl} = $disturl;
		$result{$name}{url} = $url;
		$result{$name}{installdate} = strftime(
			"%Y-%m-%d %H:%M:%S", localtime($installtime)
		);
	}
	$pack -> close();
	$this->{getInstalledPackages_result} = \%result;
	return \%result;
}

#==========================================
# getCustomData
#------------------------------------------
sub getCustomData {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $custom= $this->{custom};
	my $modified = $this->{rpm_modc};
	my %result= ();
	if ($this->{getCustomData_result}) {
		return $this->{getCustomData_result};
	}
	my @files;
	if (-f $custom) {
		push @files, $custom;
	}
	if (-f $modified) {
		push @files, $modified;
	}
	if (! @files) {
		return;
	}
	my $customfiles = int (KIWIQX::qxx ("cat @files | wc -l"));
	my $customfd = FileHandle -> new();
	if (! $customfd -> open ($custom)) {
		$kiwi -> error  ("Couldn't read $custom: $!");
		$kiwi -> failed ();
		return;
	}
	my $modifiedfd = FileHandle -> new();
	if (! $modifiedfd -> open ($modified)) {
		$kiwi -> error  ("Couldn't read $modified: $!");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> info ("Creating custom/unpackaged data attributes...");
	my $factor = 100 / $customfiles;
	my $done_percent = 0;
	my $done_previos = 0;
	my $done = 0;
	$kiwi -> cursorOFF();
	$kiwi-> step($done_percent);
	my $rule;
	my $type;
	while (my $item = <$modifiedfd>) {
		chomp $item;
		my $attr;
		if (-l $item) {
			$attr = lstat ($item);
		} else {
			$attr = stat ($item);
		}
		if ($attr) {
			$result{$item} = ['modified',$attr];
		}
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	$modifiedfd -> close();
	while (my $item = <$customfd>) {
		chomp $item;
		my @path = split(/\//,$item);
		my $file = pop(@path);
		my $attr;
		if (($rule) && ($item =~ /$rule/)) {
			if (-l $item) {
				$attr = lstat ($item);
			} else {
				$attr = stat ($item);
			}
		} else {
			undef $rule;
			if (-l $item) {
				$attr = lstat ($item);
				$type = 'symlink';
			} elsif (-d $item) {
				$attr = stat ($item);
				if (-e "$item/.git") {
					$rule = '^\\'.$item;
					$type = 'git';
				} elsif (-e "$item/.osc") {
					$rule = '^\\'.$item;
					$type = 'osc';
				} elsif (-e "$item/.svn") {
					$rule = '^\\'.$item;
					$type = 'svn';
				} elsif ($item =~ /\/gems/) {
					$rule = '^\\'.$item;
					$type = 'rubygems';
				} else {
					$type = 'directory';
				}
			} elsif ($file =~ /^\./) {
				$attr = stat ($item);
				$type = 'hidden';
			} else {
				$attr = stat ($item);
				$type = 'file';
				# try to check for binary data in a fast way by
				# reading only the ELF bytes and by guessing that
				# such evil data somehow lives in path names
				# containing a bin or opt in its name
				if (($attr) && ($item =~ /bin|opt/) && (S_ISREG($attr->mode))) {
					if (sysopen (my $fd,$item,O_RDONLY)) {
						my $buf;
						seek ($fd,1,0);
						sysread ($fd,$buf,3);
						close ($fd);
						if ($buf eq 'ELF') {
							$type = 'elfbin'
						}
					}
				}
			}
		}
		if ($attr) {
			$result{$item} = [$type,$attr];
		}
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	$customfd -> close();
	$kiwi -> step(100);
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	$this->{getCustomData_result} = \%result;
	return \%result;
}

#==========================================
# createCustomDataTree
#------------------------------------------
sub createCustomDataTree {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $dest  = $this->{destdir};
	my $result= $this-> getCustomData();
	if (! $result) {
		return;
	}
	$kiwi -> info ("Creating custom/unpackaged data tree...");
	my $factor;
	my $done_percent = 0;
	my $done_previos = 0;
	my $done = 0;
	$kiwi -> cursorOFF();
	if (! -d "$dest/custom") {
		KIWIQX::qxx ("mkdir -p $dest/custom 2>&1");
	} else {
		KIWIQX::qxx ("rm -rf $dest/custom 2>&1");
	}
	my @dirs = ();
	my @files= ();
	foreach my $item (sort keys %{$result}) {
		if ($result->{$item}->[0] eq 'directory') {
			push @dirs, $item;
		} else {
			push @files, $item;
		}
	}
	$factor = 100.0 / (@dirs + @files);
	$kiwi-> step($done_percent);
	foreach my $dir (@dirs) {
		if (! -d "$dest/custom/$dir") {
			mkpath ("$dest/custom/$dir", {verbose => 0});
		}
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	foreach my $file (@files) {
		if (-e $file) {
			if (! link $file, "$dest/custom/$file") {
				symlink $file, "$dest/custom/$file";
			}
		}
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
	}
	$kiwi -> step(100);
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	return $this;
}

#==========================================
# createCustomDataForType
#------------------------------------------
sub createCustomDataForType {
	my $this  = shift;
	my $type  = shift;
	my $kiwi  = $this->{kiwi};
	my $result= $this-> getCustomData();
	my @items = ();
	my $tree;
	if ($type eq 'directory') {
		# directory information is part of file path
		return;
	}
	$kiwi -> info ("Creating D3 view for custom $type data...");
	foreach my $item (sort keys %{$result}) {
		if ($result->{$item}->[0] eq $type) {
			push @items, $item;
		}
	}
	if (! @items) {
		$kiwi -> skipped();
		$kiwi -> info ("--> No $type custom data found");
		$kiwi -> skipped();
		return;
	}
	my $factor = 100.0 / @items;
	my $done_percent = 0;
	my $done_previos = 0;
	my $done = 0;
	$kiwi -> cursorOFF();
	my $files = 0;
	my $max_child = 5;
	foreach my $item (@items) {
		my @path_elements = ();
		@path_elements = split (/\//,$item);
		$path_elements[0] = '/';
		my $filename = pop @path_elements;
		#==========================================
		# update progress
		#------------------------------------------
		$done_percent = int ($factor * $done);
		if ($done_percent > $done_previos) {
			$kiwi -> step ($done_percent);
		}
		$done_previos = $done_percent;
		$done++;
		#==========================================
		# create file node first
		#------------------------------------------
		my $file_node->{name} = $filename;
		#==========================================
		# search for nodes in current tree
		#------------------------------------------
		my @node_list = $this -> __searchNode (
			$tree,\@path_elements
		);
		#==========================================
		# walk through the tree and create/add data
		#------------------------------------------
		my $pre_node;
		for (my $i=@path_elements-1; $i >= 0; $i--) {
			my $dir_name = $path_elements[$i];
			my $dir_node = $node_list[$i];
			if (! $dir_node) {
				$dir_node->{name} = $dir_name;
				if ($filename) {
					$dir_node->{children} = [ $file_node ];
				} elsif ($pre_node) {
					$dir_node->{children} = [ $pre_node ];
				}
			} else {
				my $children = $dir_node->{children};
				my @children = ();
				if ($children) {
					@children = @{$children};
				}
				my $add_node;
				if ($filename) {
					$add_node = $file_node;
				} elsif ($pre_node) {
					$add_node = $pre_node;
				}
				if ($add_node) {
					my $added = 0;
					foreach my $c (@children) {
						if ($c == $add_node) {
							$added = 1; last;
						}
					}
					if (! $added) {
						if (($filename) && (@children >= $max_child)) {
							$files++;
							$add_node->{name} =
								"THERE ARE ($files) MORE ITEMS NOT DISPLAYED";
							$children[$max_child] = $add_node;
						} else {
							$files = 0;
							push @children,$add_node;
						}
						$dir_node->{children} = \@children;
					}
				}
			}
			if ($filename) {
				undef $filename;
			}
			if ((! $tree) && ($dir_name eq '/') && ($dir_node)) {
				$tree = $dir_node;
			}
			$pre_node = $dir_node;
		}
	}
	$kiwi -> step (100);
	$kiwi -> note ("\n");
	$kiwi -> doNorm ();
	$kiwi -> cursorON();
	$kiwi -> info ("Encoding D3 data stream...");
	my $json_obj = JSON->new->allow_nonref;
	my $json = $json_obj->canonical->pretty->encode($tree);
	$kiwi -> done();
	return $json;
}

#==========================================
# __searchNode
#------------------------------------------
sub __searchNode {
	my $this   = shift;
	my $tree   = shift;
	my $search = shift;
	my @result;
	my @search_list = @{$search};
	foreach my $item (@search_list) {
		push @result,undef;
	}
	if ((! $tree) || (ref $tree ne 'HASH') || (! $tree->{name})) {
		return @result;
	}
	my $count = 0;
	foreach my $item (@search_list) {
		if (($count == 0) && ($tree->{name} eq $item)) {
			$result[$count] = $tree;
		} elsif ($tree->{children}) {
			my @child_list = @{$tree->{children}};
			my $found = 0;
			foreach my $child (@child_list) {
				if ($child->{name} eq $item) {
					$result[$count] = $child;
					$tree  = $child;
					$found = 1;
					last;
				}
			}
			if (! $found) {
				return @result;
			}
		}
		$count++;
	}
	return @result;
}

#==========================================
# __dumpRPMDatabase
#------------------------------------------
sub __dumpRPMDatabase {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $cdata = $this->{cdata};
	my $rpm_dump = $this->{rpm_dump};
	my $rpm_pack = $this->{rpm_pack};
	my $rpm_modc = $this->{rpm_modc};
	my $code;
	my $pack_data;
	my $dump_data;
	my $modc_data;
	if (($cdata) &&
		($cdata->{rpm_dump}) &&
		($cdata->{rpm_pack}) &&
		($cdata->{rpm_modc})
	) {
		$kiwi -> info ("Reading RPM database from cache");
		$dump_data = $cdata->{rpm_dump};
		$pack_data = $cdata->{rpm_pack};
		$modc_data = $cdata->{rpm_modc};
		$kiwi -> done();
	} else {
		$kiwi -> info ("Reading RPM database [files]");
		$dump_data = KIWIQX::qxx ('rpm -qlav --dump 2>&1');
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("rpm call failed: $dump_data");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
		$kiwi -> info ("Reading RPM database [packages]");
		my $flags = '%{name}|%{distribution}|%{disturl}|%{url}|%{installtime}';
		$pack_data = KIWIQX::qxx ("rpm -qa --qf '$flags\n'");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("rpm call failed: $pack_data");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
		$kiwi -> info ("Reading RPM database [modified]");
		my $checkopt;
		my %checkpack;
		$checkopt = "--nodeps --nodigest --nosignature --nomtime ";
		$checkopt.= "--nolinkto --nouser --nogroup --nomode";
		my $packlist = KIWIQX::qxx ("rpm -qac | grep ^/ | xargs rpm -qf");
		foreach my $package (split(/\n/,$packlist)) {
			$checkpack{$package} = 1;
		}
		my @checklist = sort keys %checkpack;
		my $rpmcheck = KIWIQX::qxx ("rpm -V $checkopt @checklist 2>/dev/null");
		foreach my $check (split(/\n/,$rpmcheck)) {
			if ($check =~ /^..(.).+\s+(.)\s(\/.*)$/) {
				my $has_changed = ($1 eq "5");
				my $is_config = ($2 eq "c");
				my $file = $3;
				if (($has_changed) && ($is_config)) {
					$modc_data .= $file."\n";
				}
			}
		}
		$kiwi -> done();
		$cdata->{rpm_dump} = $dump_data;
		$cdata->{rpm_pack} = $pack_data;
		$cdata->{rpm_modc} = $modc_data;
		if (! $this -> writeCache()) {
			return;
		}
	}
	$kiwi -> info ("Writing RPM dump files");
	if ($dump_data) {
		my $dump = FileHandle -> new();
		if (! $dump -> open (">$rpm_dump")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $rpm_dump: $!");
			$kiwi -> failed ();
			return;
		}
		print $dump $dump_data;
		$dump -> close();
	}
	if ($pack_data) {
		my $pack = FileHandle -> new();
		if (! $pack -> open (">$rpm_pack")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $rpm_pack: $!");
			$kiwi -> failed ();
			return;
		}
		print $pack $pack_data;
		$pack -> close();
	}
	if ($modc_data) {
		my $modc = FileHandle -> new();
		if (! $modc -> open (">$rpm_modc")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $rpm_modc: $!");
			$kiwi -> failed ();
			return;
		}
		print $modc $modc_data;
		$modc -> close();
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# __dumpCustomData
#------------------------------------------
sub __dumpCustomData {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $rpm_dump = $this->{rpm_dump};
	my $script = $this->{gdata}->{KModules}.'/KIWIAnalyseCustomData.sh';
	$kiwi -> info ("Searching custom files/directories");
	if (! -f $rpm_dump) {
		$kiwi -> failed();
		$kiwi -> error ("Failed to find $rpm_dump file");
		$kiwi -> failed();
		return;
	}
	my $data = KIWIQX::qxx ("bash $script 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed();
		$kiwi -> error ("Calling $script failed with: $data");
		$kiwi -> failed();
		return;
	}
	$kiwi -> done();
	return $this;
}

1;
