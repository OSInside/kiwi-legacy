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
		my $locator = KIWILocator -> instance();
		my $git = $locator -> getExecPath ("git");
		if ($git) {
			$data = KIWIQX::qxx ("cd $destdir && $git init 2>&1");
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
		}
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
	my $locator = KIWILocator -> instance();
	my $git = $locator -> getExecPath ("git");
	if (! $git) {
		return $this;
	}
	my $text = '- automatic transaction commit';
	my $data = KIWIQX::qxx ("cd $dest && $git add --all . 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error ("commitTransaction: $data");
		$kiwi -> failed();
		return;
	}
	$data = KIWIQX::qxx (
		"cd $dest && $git commit -a -m \"$text\" 2>&1"
	);
	return $this;
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
# getIPAddress
#------------------------------------------
sub getIPAddress {
	my $this = shift;
	my $routing_table = KIWIQX::qxx ("ip route show | grep default 2>&1");
	my $code = $? >> 8;
	if (($code != 0) || (! $routing_table)) {
		# no routing table output
		return;
	}
	my @routes = split(/ +/,$routing_table);
	if (! $routes[4]) {
		# no default interface name
		return;
	}
	my $iface = $routes[4];
	my $addr = KIWIQX::qxx ("ip -f inet -o addr show $iface 2>&1");
	$code = $? >> 8;
	if (($code != 0) || (! $addr)) {
		# no inet addr information
		return;
	}
	my @addr_list = split(/ +/,$addr);
	if (! $addr_list[3]) {
		# no ip address information
		return;
	}
	my $ip = $addr_list[3];
	if ($ip =~ /(.*)\//) {
		$ip = $1;
	} else {
		# unknown ip format
		return;
	}
	return $ip;
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
	if (! %modalias) {
		return;
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
				} elsif ($file =~ /^\./) {
					$type = 'hidden-directory';
				} elsif ($this -> __matchesHomeDir($item)) {
					$type = 'homedir';
				} else {
					$type = 'directory';
				}
			} elsif (($file) && ($file =~ /^\./)) {
				$attr = stat ($item);
				$type = 'hidden-file';
			} elsif ($this -> __matchesHomeDir($item)) {
				$attr = stat ($item);
				if ($item =~ /\/\./) {
					$type = 'file-in-hidden-home-path';
				} else {
					$type = 'homedata';
				}
			} else {
				$attr = stat ($item);
				if ($item =~ /\/\./) {
					$type = 'file-in-hidden-path';
				} else {
					$type = 'file';
				}
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
# createCustomDataSyncReference
#------------------------------------------
sub createCustomDataSyncReference {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $dest  = $this->{destdir};
	my $custom = $this->{custom};
	my $modified = $this->{rpm_modc};
	my $sync_source = "$dest/custom.files";
	my $readme = $this->{gdata}->{KAnalyseCMK};
	my $status;
	my $result;
	$kiwi -> info ("Creating custom/unpackaged files reference...");
	KIWIQX::qxx ("touch $sync_source");
	if (-f $custom) {
		$status = KIWIQX::qxx ("cp $custom $sync_source 2>&1");
		$result = $? >> 8;
	}
	if (($result == 0) && (-f $modified)) {
		$status = KIWIQX::qxx ("cat $modified >> $sync_source 2>&1");
		$result = $? >> 8;
	}
	if ($result == 0) {
		$status = KIWIQX::qxx ("cp $readme $dest/custom.files.readme");
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ($status);
		return;
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# syncCustomData
#------------------------------------------
sub syncCustomData {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $dest  = $this->{destdir};
	my $screen_conf = "$dest/screen.conf";
	my $sync_logfile= "$dest/custom.sync.log";
	my $sync_source = "$dest/custom.sync";
	my $sync_opts = "-zavh --progress --numeric-ids --delete "
		. "--files-from=$sync_source";
	my $status;
	$kiwi -> info ("Syncing custom/unpackaged files\n");
	unlink $screen_conf;
	unlink $sync_logfile;
	if (! -f $sync_source) {
		$kiwi -> info ("--> no custom.sync source file configured");
		$kiwi -> skipped();
		return $this;
	}
	$kiwi -> info ("--> Sync in progress");
	if (! -d "$dest/root") {
		KIWIQX::qxx ("mkdir -p $dest/root 2>&1");
	}
	my $cd = FileHandle -> new();
	if (! $cd -> open (">$screen_conf")) {
		$kiwi -> failed();
		$kiwi -> error ("Can't create screen config file: $!");
		$kiwi -> failed ();
		return;
	}
	print $cd "logfile $sync_logfile\n";
	print $cd "logfile flush 1\n";
	$cd -> close();
	KIWIQX::qxx (
		"screen -L -D -m -c $screen_conf rsync $sync_opts / root 2>&1"
	);
	my $fd = FileHandle -> new();
	if ($fd -> open ("tail -n 10 $sync_logfile|")) {
		local $/; $status = <$fd>; $fd -> close();
	}
	unlink $screen_conf;
	if ($status =~ /rsync error:/) {
		$kiwi -> failed();
		$kiwi -> error ("Sync errors see $sync_logfile for details");
		$kiwi -> failed ();
		return;
	}
	unlink $sync_logfile;
	$kiwi -> done();
	return $this;
}

#==========================================
# createCustomDataForType
#------------------------------------------
sub createCustomDataForType {
	my $this  = shift;
	my $type  = shift;
	my $max_child = shift;
	my $kiwi  = $this->{kiwi};
	my $result= $this-> getCustomData();
	my @items = ();
	my $tree;
	$kiwi -> info ("Creating D3 view for custom $type data...");
	my %filecount = ();
	foreach my $item (sort keys %{$result}) {
		my $cur_type = $result->{$item}->[0];
		if (($cur_type eq $type) ||
			(($cur_type eq 'directory') && ($type eq 'file'))
		) {
			push @items, $item;
			if (($max_child) && ($cur_type ne 'directory')) {
				my @path_elements = split (/\//,$item);
				$path_elements[0] = '/';
				pop @path_elements;
				my $dirname = join ("/",@path_elements);
				if (! $filecount{$dirname}) {
					$filecount{$dirname} = 1;
				} else {
					$filecount{$dirname}++;
				}
			}
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
	my %curcount = ();
	foreach my $item (@items) {
		my $type = $result->{$item}->[0];
		my @path_elements = ();
		@path_elements = split (/\//,$item);
		$path_elements[0] = '/';
		my $filename = pop @path_elements;
		my $dirname  = join ("/",@path_elements);
		if (($max_child) && ($type ne 'directory')) {
			if (! $curcount{$dirname}) {
				$curcount{$dirname} = 1;
			} else {
				$curcount{$dirname}++;
			}
		}
		#==========================================
		# add a more flag and stop after max_count
		#------------------------------------------
		if (($max_child) && ($type ne 'directory')) {
			if ($curcount{$dirname} == $max_child + 1) {
				my $rest = $filecount{$dirname} - $max_child;
				$filename = "THERE ARE [ $rest ] MORE ITEMS NOT DISPLAYED";
			} elsif ($curcount{$dirname} > $max_child + 1) {
				next;
			}
		}
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
		if ($type eq 'directory') {
			$file_node->{children} = [ ];
		}
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
						push @children,$add_node;
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
# __matchesHomeDir
#------------------------------------------
sub __matchesHomeDir {
	my $this  = shift;
	my $match = shift;
	my $homes = $this->{homedirs};
	if (! $homes) {
		$homes = $this -> __getHomeDirs();
		$this->{homedirs} = $homes;
	}
	foreach my $dir (@{$homes}) {
		if ($match =~ /^$dir/) {
			return 1;
		}
	}
	return 0;
}

#==========================================
# __getHomeDirs
#------------------------------------------
sub __getHomeDirs {
	my $this = shift;
	my $fd = FileHandle -> new();
	my @result = (
		'\/home', '\/root'
	);
	if (! $fd -> open ("/etc/passwd")) {
		return \@result;
	}
	while (my $line = <$fd>) {
		chomp $line;
		my $homedir = (split (/:/,$line))[5];
		my $userid  = (split (/:/,$line))[2];
		if ((! $homedir) || (! $userid)) {
			next;
		}
		if ((-d $homedir) && ($userid > 256) && ($homedir ne '/')) {
			push @result, quotemeta($homedir);
		}
	}
	$fd -> close();
	return \@result;
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
	# The following function is able to reduce the custom files
	# result by providing only the name of the directory if all
	# data below this directory contains only custom files.
	# Problem is that other types of data e.g repo checkouts
	# might vanish from the report which is imho unwanted.
	# Therefore the code is currently deactivated:
	#
	# if ($this -> __stripCustomData()) {
	#	KIWIQX::qxx ("mv $this->{custom}.stripped $this->{custom}");
	# }
	#
	$kiwi -> done();
	return $this;
}

#==========================================
# __stripCustomData
#------------------------------------------
sub __stripCustomData {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $custom= $this->{custom};
	my $filter= $this->__filter_filesystem();
	my $grep  = '^\/(tmp|dev|proc|sys|run|var\/lib\/ntp|lost\+found|var\/run)';
	if (! -f $custom) {
		$kiwi -> failed();
		$kiwi -> error ("Failed to find $custom file");
		$kiwi -> failed();
		return;
	}
	my $cfd = FileHandle -> new();
	if (! $cfd -> open ($custom)) {
		$kiwi -> error  ("Couldn't read $custom: $!");
		$kiwi -> failed ();
		return;
	}
	my $cfd_new = FileHandle -> new();
	if (! $cfd_new -> open (">$custom.stripped")) {
		$kiwi -> error  ("Couldn't open $custom.stripped for writing: $!");
		$kiwi -> failed ();
		return;
	}
	my $prev_item;
	my $count = 0;
	my @files;
	while (my $item = <$cfd>) {
		chomp $item;
		if ((! $prev_item) || ($item !~ /^$prev_item\//)) {
			if (! $prev_item) {
				# at the start there is no previous item to match
				print $cfd_new $item;
				$prev_item = $item;
				next;
			}
			# find items in subpath to compare number of elements
			my $find_options = "\"$prev_item\" $filter -mindepth 1 -print0";
			my $find_result = KIWIQX::qxx (
				"echo $find_options | xargs -x find 2>/dev/null"
			);
			my @find_list = split(/\0/,$find_result);
			my $find_count= 0;
			foreach my $f (@find_list) {
				next if ($f =~ /$grep/);
				$find_count++;
			}
			if (($count > 0) && ($count == $find_count)) {
				# entire tree is unmanaged
				print $cfd_new "\n";
			} elsif (($count == 0) && (-d "$prev_item")) {
				print $cfd_new "\n";
			} else {
				# there are managed items in this tree
				print $cfd_new "\n";
				foreach my $f (@files) {
					print $cfd_new $f."\n";
				}
			}
			if ($item) {
				print $cfd_new $item
			}
			$count = 0;
			undef @files;
			$prev_item = $item;
		} else {
			# we have a prev_item and it matches the current one
			$count++;
			push @files, $item;
		}
	}
	$cfd -> close();
	$cfd_new -> close();
	return $this;
}

#==========================================
# __filter_filesystem
#------------------------------------------
sub __filter_filesystem {
	my $this = shift;
	my @fs = qw(nfs tmpfs proc sysfs devtmpfs devpts);
	my $result;
	foreach my $fs (@fs) {
		$result .= "-not -fstype $fs "
	}
	return $result;
}

1;
