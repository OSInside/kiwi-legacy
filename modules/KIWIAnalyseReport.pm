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
use Carp qw (cluck);
use XML::LibXML;
use Data::Dumper;
use FileHandle;
use File::Find;
use File::stat;
use File::Basename;
use File::Path;
use File::Copy;
use Storable;
use File::Spec;
use Fcntl ':mode';
use Cwd qw (abs_path cwd);
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
	my $dest      = shift;
	my $multiple  = shift;
	my $localrepos= shift;
	my $custom    = shift;
	my $solverstat= shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi   = KIWILog -> instance();
	my $global = KIWIGlobals -> instance();
	if ((! defined $dest) || (! -d $dest)) {
		$kiwi -> error  (
			"KIWIAnalyseReport: Couldn't find destination dir: $dest"
		);
		$kiwi -> failed ();
		return;
	} 
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{gdata}     = $global -> getKiwiConfig();
	$this->{kiwi}      = $kiwi;
	$this->{dest}      = $dest;
	$this->{twice}     = $multiple;
	$this->{localrepos}= $localrepos;
	$this->{nopackage} = $custom;
	#==========================================
	# Store object data
	#------------------------------------------
	if ($solverstat) {
		$this->{solverProblem1}    = $solverstat->[0];
		$this->{solverFailedJobs1} = $solverstat->[1];
		$this->{solverProblem2}    = $solverstat->[2];
		$this->{solverFailedJobs2} = $solverstat->[3];
	}
	return $this;
}

#==========================================
# createViews
#------------------------------------------
sub createViews {
	# ...
	# use the d3 data visualization framework to show
	# the tree of custom files in a browser
	# ---
	my $this       = shift;
	my $kiwi       = $this->{kiwi};
	my $nopackage  = $this->{nopackage};
	my $dest       = $this->{dest};
	if (! $nopackage) {
		return;
	}
	#==========================================
	# we need a JSON ready perl data structure
	#------------------------------------------
	# split into binary and text data...
	my $tree_binary;
	my $tree_text;
	my @files_binary = ();
	my @files_text   = ();
	my @files  = sort keys %{$nopackage};
	foreach my $file (@files) {
		my $fattr = $nopackage->{$file}->[1];
		my $type  = $fattr->[13];
		my $is_binary = 0;
		if (($type) && ($type == 1)) {
			$is_binary = 1;
		}
		if ($is_binary) {
			push @files_binary,$file;
		} else {
			push @files_text,$file;
		}
	}
	# run twice for binary and text data...
	foreach my $file_ref (\@files_binary,\@files_text) {
		my $mode;
		my $tree;
		if ($file_ref == \@files_binary) {
			$mode = 'binary data';
		} else {
			$mode = 'text data';
		}
		my @files  = @{$file_ref};
		my $filenr = @files;
		next if ! $filenr;
		$kiwi -> info ("Creating JSON $mode parse tree...");
		my $factor = 100 / $filenr;
		my $done_percent = 0;
		my $done_previos = 0;
		my $done = 0;
		$kiwi -> cursorOFF();
		foreach my $file (@files) {
			my $fattr = $nopackage->{$file}->[1];
			my @ori_items = split (/\//,$file);
			$ori_items[0] = '/';
			my $u_fpath = join ('_',@ori_items);
			my @new_items = ();
			my $isdir = 0;
			my $filename;
			if (($fattr) && (S_ISDIR($fattr->mode))) {
				$isdir = 1;
			}
			if (! $isdir) {
				$filename = pop @ori_items;
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
			my $file_node;
			if ($filename) {
				$file_node->{name} = $filename;
			}
			#==========================================
			# search for nodes in current tree
			#------------------------------------------
			my @node_list = $this -> __searchNode ($tree,\@ori_items);
			#==========================================
			# walk through the tree and create/add data
			#------------------------------------------
			my $pre_node;
			for (my $i=@ori_items-1; $i >= 0; $i--) {
				my $dir_name = $ori_items[$i];
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
		if ($file_ref == \@files_binary) {
			$tree_binary = $tree;
		} else {
			$tree_text = $tree;
		}
		$kiwi -> step (100);
		$kiwi -> note ("\n");
		$kiwi -> doNorm ();
		$kiwi -> cursorON();
	}
	#==========================================
	# store JSON data
	#------------------------------------------
	$kiwi -> info ("Storing D3 data stream...");
	my $json = JSON->new->allow_nonref;
	my $binary = $json->pretty->encode( $tree_binary );
	$this->{jsontree_binary} = $binary;
	my $text = $json->pretty->encode( $tree_text );
	$this->{jsontree_text} = $text;
	$kiwi -> done();
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
	my $repos      = $this->{localrepos};
	my $twice      = $this->{twice};
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
	print $FD '</head>'."\n";
	#==========================================
	# Container Menu
	#------------------------------------------
	my %menu = ();
	my $img  = '.report/d3/img/menu';
	$menu{'RPM-packages'} = [
		"$img/RPM-packages.jpg","Hardware Packages"
	];
	$menu{'kernel'} = [
		"$img/kernel.jpg","Kernel"
	];
	$menu{'custom-files'} = [
		"$img/custom-files.jpg","Custom Files"
	];
	$menu{'custom-files-visualisation'} = [
		"$img/custom-files-visualisation.jpg","C. Files Visualisation"
	];
	if ($twice) {
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
	if ($repos) {
		$menu{'local-repositories'} = [
			"$img/local-repositories.jpg","Repositories"
		];
	}
	if (-x "/usr/bin/gem") {
		$menu{'gems'} = [
			"$img/gems.jpg","GEMs"
		];
	}
	print $FD '<body class="files">'."\n";
	print $FD '<header>'."\n";
	print $FD '<div class="container menu">'."\n";
	foreach my $item (keys %menu) {
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
	my $kernel = KIWIQX::qxx ("uname -r");
	chomp $kernel;
	if (! -e "/lib/modules/$kernel") {
		print $FD '<p>'."\n";
		print $FD "Sorry no kernel package found for running kernel: $kernel ";
		print $FD 'In case the kernel was updated make sure to reboot the ';
		print $FD 'machine in order to activate the installed kernel ';
		print $FD '</p>'."\n";
	} else {
		print $FD '<table>'."\n";
		my $list = KIWIQX::qxx (
			"rpm -qf --qf \"%{NAME}:%{VERSION}\\n\" /lib/modules/$kernel"
		);
		my @list = split(/\n/,$list);
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
	}
	print $FD '</div>'."\n";
	#==========================================
	# Hardware dependent packages report
	#------------------------------------------
	my $pack;
	my %modalias;
	print $FD '<div class="infoPanel">'."\n";
	print $FD '<a name="RPM-packages"></a>'."\n";
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
	for (KIWIQX::qxx ( "rpm -qa --qf '\n<%{name}>\n' --supplements" )) {
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
	print $FD '</div>'."\n";
	#==========================================
	# Local repository checkout(s)
	#------------------------------------------
	if ($repos) {
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="local-repositories"></a>'."\n";
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
		print $FD '</div>'."\n";
	}
	#==========================================
	# GEM packages report
	#------------------------------------------
	if (-x "/usr/bin/gem") {
		my @gems;
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="gems"></a>'."\n";
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
		for (KIWIQX::qxx ( "gem list --local" )) {
			chomp;
			push (@gems,$_);
		}
		foreach my $item (sort @gems) {
			print $FD '<tr valign="top">'."\n";
			print $FD '<td>'.$item.'</td>'."\n";
			print $FD '</tr>'."\n";
		}
		print $FD '</table>'."\n";
		print $FD '</div>'."\n";
	}
	#==========================================
	# Package/Pattern report
	#------------------------------------------
	if ($twice) {
		my @pacs = @{$twice};
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="multiple-RPM"></a>'."\n";
		print $FD '<h1>RPM Package(s) installed multiple times</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'The following packages are installed multiple times. ';
		print $FD 'For a clone of the system you only need to take the ';
		print $FD 'latest version into account which also is the default. ';
		print $FD 'action when re-installing those packages.';
		print $FD '</p>'."\n";
		print $FD '<hr>'."\n";
		print $FD '<table>'."\n";
		my $list = KIWIQX::qxx ("rpm -q @pacs --last");
		my @list = split(/\n/,$list);
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
		print $FD '</div>'."\n";
	}
	if ($problem1) {
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="pattern-conflicts"></a>'."\n";
		print $FD '<h1>Pattern conflict(s)</h1>'."\n";
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
	}
	if ($problem2) {
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="RPM-conflicts"></a>'."\n";
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
		print $FD '</div>'."\n";
	}
	if (($failedJob1) && (@{$failedJob1})) {
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="pattern-lost"></a>'."\n";
		print $FD '<h1>Pattern(s) not found</h1>'."\n";
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
	}
	if (($failedJob2) && (@{$failedJob2})) {
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="RPM-lost"></a>'."\n";
		print $FD '<h1>RPM Package(s) not found</h1>'."\n";
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
		my @pacs = @{$failedJob2};
		my $list = KIWIQX::qxx ("rpm -q @pacs --last");
		my @list = split(/\n/,$list);
		foreach my $job (sort @list) {
			if ($job =~ /([^\s]+)\s+([^\s].*)/) {
				my $pac  = $1;
				my $date = $2;
				my $rpm  = KIWIQX::qxx (
					'rpm -q --qf "%{distribution}\n%{disturl}\n%{url}\n" '.$pac
				);
				my @rpm = split(/\n/,$rpm);
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
		print $FD '</div>'."\n";
	}
	#==========================================
	# Custom files report...
	#------------------------------------------
	if ($nopackage) {
		print $FD '<div class="infoPanel">'."\n";
		print $FD '<a name="custom-files"></a>'."\n";
		print $FD '<h1>Custom files</h1>'."\n";
		print $FD '<p>'."\n";
		print $FD 'Below the current custom files directory you will ';
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
		print $FD 'of the image could become big. Move all of the files you ';
		print $FD 'want to be part of the image into the root ';
		print $FD 'directory. you can browse the tree on the filesystem ';
		print $FD 'level here:'."\n";
		print $FD '</p>'."\n";
		print $FD '<div>'."\n";
		print $FD 'Open <a href="custom" target="_blank">';
		print $FD 'Custom directory</a>.'."\n";
		print $FD '</div>'."\n";
		print $FD '</div>'."\n";
		foreach my $tree ($this->{jsontree_binary},$this->{jsontree_text}) {
			#==========================================
			# Run only with data
			#------------------------------------------
			next if ! $tree;
			#==========================================
			# Setup title and outfile
			#------------------------------------------
			my $file;
			my $title;
			if ($tree eq $this->{jsontree_binary}) {
				$file = "$dest/report-binary.html";
				$title = "Custom binary data report";
			} else {
				$file = "$dest/report-text.html";
				$title = "Custom text data report";
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
			if ($tree eq $this->{jsontree_binary}) {
				print $JD 'The visualisation of the data below shows ';
				print $JD 'the unmanaged binary data tree.'."\n";
			} else {
				print $JD 'The visualisation of the data below shows ';
				print $JD 'the unmanaged text data tree.'."\n";
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
		print $FD '<p>'."\n";
		print $FD 'For a better overview the following data reports ';
		print $FD 'were created';
		print $FD '</p>'."\n";
		print $FD '<div>'."\n";
		my $binary_report = $dest.'/report-binary.html';
		my $text_report   = $dest.'/report-text.html';
		if (-e $binary_report) {
			print $FD '<p>'."\n";
			print $FD "Open <a href=\"report-binary.html\" target=\"_blank\">";
			print $FD 'Custom binary data</a>.'."\n";
			print $FD '</p>'."\n";
		}
		if (-e $text_report) {
			print $FD '<p>'."\n";
			print $FD "Open <a href=\"report-text.html\" target=\"_blank\">";
			print $FD 'Custom text data</a>.'."\n";
			print $FD '</p>'."\n";
		}
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
	$kiwi -> info ("--> Please check the migration report !!\n");
	$kiwi -> note ("\n\tfile://$dest/report.html\n\n");
	return $this;
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

1;
