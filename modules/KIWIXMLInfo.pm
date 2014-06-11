#================
# FILE          : KIWIXMLInfo.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2011 SUSE LLC
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
package KIWIXMLInfo;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;
use File::Find;
use XML::LibXML;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIGlobals;
use KIWILog;
use KIWIQX;
use KIWIXML;
use KIWIXMLRepositoryData;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the info object.
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
	my $cmdL = shift;
	my $xml  = shift;
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if (! defined $cmdL) {
		my $msg = 'KIWIXMLInfo: expecting KIWICommandLine object as '
			. 'second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	my $configDir = $cmdL -> getConfigDir();
	if (! defined $configDir) {
		my $msg = 'Invalid KIWICommandLine object, no configuration '
			. 'directory.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	#==========================================
	# Reset logging target if requested
	#------------------------------------------
	my $logFile = $cmdL -> getLogFile();
	if ($logFile) {
		$kiwi -> info ("Setting log file to: $logFile\n");
		if (! $kiwi -> setLogFile ( $logFile )) {
			return;
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	my $global = KIWIGlobals -> instance();
	$this->{addlRepos}      = $cmdL -> getAdditionalRepos();
	$this->{buildProfiles}  = $cmdL -> getBuildProfiles();
	$this->{configDir}      = $configDir;
	$this->{ignoreRepos}    = $cmdL -> getIgnoreRepos();
	$this->{kiwi}           = $kiwi;
	$this->{packageManager} = $cmdL -> getPackageManager();
	$this->{replRepo}       = $cmdL -> getReplacementRepo();
	$this->{gdata}          = $global -> getKiwiConfig();
	$this->{cmdL}           = $cmdL;
	#==========================================
	# Setup XML
	#------------------------------------------
	$this->{xml} = $this -> __xmlSetup ($xml);
	if (! $this->{xml}) {
		return;
	}
	$xml = $this->{xml};
	#==========================================
	# Store package names to be included
	#------------------------------------------
	my @items_install = ();
	my @items_delete  = ();
	my $bootstrapPacks = $xml -> getBootstrapPackages();
	for my $package (@{$bootstrapPacks}) {
		my $name = $package -> getName();
		push @items_install, $name;
	}
	my $imagePackages = $xml -> getPackages();
	for my $package (@{$imagePackages}) {
		my $name = $package -> getName();
		push @items_install, $name;
	}
	#==========================================
	# Store pattern names
	#------------------------------------------
	my $imageCollection = $xml -> getPackageCollections();
	for my $collection (@{$imageCollection}) {
		my $name = $collection -> getName();
		push @items_install, 'pattern:'.$name;
	}
	#==========================================
	# Add package manager
	#------------------------------------------
	my $manager = $xml -> getPreferences() -> getPackageManager();
	push @items_install, $manager;
	#==========================================
	# Store package names to be deleted later
	#------------------------------------------
	my $deletePacks = $xml -> getPackagesToDelete();
	for my $package (@{$deletePacks}) {
		my $name = $package -> getName();
		push @items_delete, $name;
	}
	#==========================================
	# Store URL list from repo setup/cmdline
	#------------------------------------------
	my @urllist = ();
	my $repos = $xml -> getRepositories();
	for my $repo (@{$repos}) {
		my ($user, $pwd) = $repo -> getCredentials();
		my $source = $repo -> getPath();
		my $urlHandler  = KIWIURL -> new ($cmdL,undef,$user,$pwd);
		my $publics_url = $urlHandler -> normalizePath ($source);
		push (@urllist,$publics_url);
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{install} = \@items_install;
	$this->{delete}  = \@items_delete;
	$this->{manager} = $manager;
	$this->{urllist} = \@urllist;
	return $this;
}

#==========================================
# getXMLInfoTree
#------------------------------------------
sub getXMLInfoTree {
	# ...
	# Return the tree object
	# ---
	my $this     = shift;
	my $requests = shift;
	my $infoRequests = $this -> __checkRequests ($requests);
	if (! $infoRequests) {
		return;
	}
	return $this -> __getTree ($infoRequests);
}

#==========================================
# printXMLInfo
#------------------------------------------
sub printXMLInfo {
	# ...
	# Print the XML information
	# ---
	my $this     = shift;
	my $requests = shift;
	my $kiwi = $this->{kiwi};
	my $infoRequests = $this -> __checkRequests ($requests);
	if (! $infoRequests) {
		return;
	}
	my $outfile = KIWIQX::qxx ("mktemp -qt kiwi-xmlinfo-XXXXXX 2>&1");
	my $code = $? >> 8; chomp $outfile;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create tmp file: $outfile: $!");
		$kiwi -> failed ();
		return;
	}
	$this -> {kiwi} -> info ("Reading image description [ListXMLInfo]...\n");
	my $infoTree = $this -> __getTree ($infoRequests);
	if (! $infoTree) {
		return;
	}
	my $F = FileHandle -> new();
	if (! $F -> open ("|xsltproc $this->{gdata}->{Pretty} - | cat > $outfile")) {
		return;
	}
	print $F $infoTree -> toString();
	$F -> close();
	system ("cat $outfile");
	$kiwi -> info ("Requested information written to: $outfile\n");
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __solve
#------------------------------------------
sub __solve {
	# ...
	# use the satsolver to solve the list of packages/patterns
	# in order to allow size estimations and a complete information
	# about the packages which will be installed later
	# ---
	my $this    = shift;
	my $manager = $this->{manager};
	my $items   = $this->{install};
	my $urllist = $this->{urllist};
	my $kiwi    = $this->{kiwi};
	my %meta;
	my @solp;
	my $solf;
	my $psolve = KIWISatSolver -> new (
		$items,$urllist,"solve-patterns"
	);
	if (! defined $psolve) {
		$kiwi -> error ("SaT solver setup failed\n");
		return;
	}
	if ($psolve -> getProblemsCount()) {
		$kiwi -> error ("SaT solver problems found !\n");
		$kiwi -> error ($psolve -> getProblemInfo());
		return;
	}
	if (@{$psolve -> getFailedJobs()}) {
		$kiwi -> error ("SaT solver failed jobs found !\n");
		$kiwi -> error ($psolve -> getProblemInfo());
		return;
	}
	%meta = $psolve -> getMetaData();
	$solf = $psolve -> getSolfile();
	@solp = $psolve -> getPackages();
	$this->{meta}    = \%meta;
	$this->{solfile} = $solf;
	$this->{solved}  = \@solp;
	return $this;
}

#==========================================
# __lookupPatterns
#------------------------------------------
sub __lookupPatterns {
	# ...
	# lookup patterns available in the repo metadata
	# ---
	my $this    = shift;
	my $items   = $this->{install};
	my $urllist = $this->{urllist};
	my $kiwi    = $this->{kiwi};
	my $psolve = KIWISatSolver -> new (
		$items,$urllist,"solve-patterns",undef,'quiet'
	);
	if (! defined $psolve) {
		$kiwi -> error ("SaT solver setup failed\n");
		return;
	}
	my $solf = $psolve -> getSolfile();
	my $rpat = KIWIQX::qxx (
		"dumpsolv $solf|grep 'solvable:name: pattern:'|cut -f4 -d :"
	);
	if (! $rpat) {
		$rpat = KIWIQX::qxx (
			"dumpsolv $solf|grep 'pattern()' | cut -f2 -d ="
		);
	}
	my @rpat = split(/\n/,$rpat);
	my %tmp_result;
	foreach my $pattern (@rpat) {
		$pattern =~ s/^\s+//;
		$pattern =~ s/\s+$//;
		next if ($pattern =~ /^\./);
		$tmp_result{$pattern} = 1;
	}
	@rpat = sort keys %tmp_result;
	$this->{repopat} = \@rpat;
	return $this;
}

#==========================================
# __getPackages
#------------------------------------------
sub __getPackages {
	# ...
	# provide information about packages, returns
	# a list of package names
	# ---
	my $this   = shift;
	my @result = ();
	if (! $this->{meta}) {
		if (! $this -> __solve()) {
			return;
		}
	}
	my $meta = $this->{meta};
	if (! $meta) {
		return;
	}
	if (! keys %{$meta}) {
		return;
	}
	foreach my $package (sort keys %{$meta}) {
		if ($package =~ /pattern:.*/) {
			next;
		}
		my @data = split (/:/,$meta->{$package});
		push @data,$package;
		push @result,\@data;
	}
	return @result;
}

#==========================================
# __getPatterns
#------------------------------------------
sub __getPatterns {
	# ...
	# provide information about patterns used in the
	# XML configuration, returns a list of pattern names
	# ---
	my $this   = shift;
	my @result = ();
	if (! $this->{meta}) {
		if (! $this -> __solve()) {
			return;
		}
	}
	my $meta = $this->{meta};
	if (! $meta) {
		return;
	}
	if (! keys %{$meta}) {
		return;
	}
	foreach my $package (sort keys %{$meta}) {
		if ($package =~ /pattern:(.*)/) {
			my $name = $1;
			push @result,$name;
		}
	}
	if ((scalar @result) == 0) {
		return;
	}
	return @result;
}

#==========================================
# __getProfiles
#------------------------------------------
sub __getProfiles {
	# ...
	# provide information about profiles, returns
	# a list with KIWIXMLProfileData objects
	# ---
	my $this  = shift;
	my $xml   = $this->{xml};
	my @result= @{$xml -> getProfiles()};
	if ((scalar @result) == 0) {
		return;
	}
	return @result;
}

#==========================================
# __getRepoPatterns
#------------------------------------------
sub __getRepoPatterns {
	# ...
	# provide information about the patterns provided
	# by the configured repositories. returns a list
	# of pattern names
	# ---
	my $this   = shift;
	my @result = ();
	if (! $this->{repopat}) {
		if (! $this -> __lookupPatterns()) {
			return;
		}
	}
	my $repopatterns = $this->{repopat};
	if (! $repopatterns) {
		return;
	}
	foreach my $pattern (@{$repopatterns}) {
		next if ($pattern eq "\n");
		$pattern =~ s/^\s+//;
		$pattern =~ s/\s+$//;
		push @result,$pattern;
	}
	return @result;
}

#==========================================
# __getOverlayFiles
#------------------------------------------
sub __getOverlayFiles {
	# ...
	# provide information about overlay files
	# returns a hash with the file as key and the path
	# as hash value
	# ---
	my $this  = shift;
	my %result= ();
	my $generateWanted = sub  {
		my $filehash = shift;
		my $basedir  = shift;
		return sub {
			my $file = $File::Find::name;
			if (! -d $file) {
				$file =~ s/$basedir//;
				$file = "[root/]$file";
				$filehash->{$file} = $basedir;
			}
		};
	};
	if (! -d $this->{configDir}."/root") {
		return;
	} else {
		my $wref = &$generateWanted (
			\%result,$this->{configDir}."/root/"
		);
		my $rdir = $this->{configDir}."/root";
		find({ wanted => $wref, follow => 0 }, $rdir);
	}
	return %result;
}

#==========================================
# __getArchives
#------------------------------------------
sub __getArchives {
	# ...
	# provide information about configured archives
	# returns a list with KIWIXMLArchiveData objects
	# ---
	my $this = shift;
	my $xml  = $this->{xml};
	my @result = @{$xml -> getArchives()};
	if ((scalar @result) == 0) {
		return;
	}
	return @result;
}

#==========================================
# __getSizeEstimation
#------------------------------------------
sub __getSizeEstimation {
	# ...
	# provide information about the overall size the later
	# image will have. This is just an estimation because
	# with the custom script and other hook-in mechanism
	# it's not possible to forecast the end size exactly.
	# returns a list with two elements:
	# rootsizeKB,deletionsizeKB
	# ---
	my $this   = shift;
	my @result = ();
	if (! $this->{meta}) {
		if (! $this -> __solve()) {
			return;
		}
	}
	my $meta   = $this->{meta};
	my $delete = $this->{delete};
	if (! $meta) {
		return;
	}
	my $size = 0;
	my %meta = %{$meta};
	foreach my $p (keys %meta) {
		my @metalist = split (/:/,$meta{$p});
		$size += $metalist[0];
	}
	# store root size in KB as first element
	push @result,$size;
	$size = 0;
	if ($delete) {
		foreach my $del (@{$delete}) {
			if ($meta{$del}) {
				my @metalist = split (/:/,$meta{$del});
				$size += $metalist[0];
			}
		}
	}
	if ($size > 0) {
		# store deletion size in KB as second element
		push @result,$size;
	}
	return @result;
}

#==========================================
# __getRepoURI
#------------------------------------------
sub __getRepoURI {
	# ...
	# provide information about the configured repos
	# returns a list with KIWIXMLRepositories objects
	# ---
	my $this  = shift;
	my $xml   = $this->{xml};
	my @result= @{$xml -> getRepositories()};
	if ((scalar @result) == 0) {
		return;
	}
	return @result;
}

#==========================================
# __getImageTypes
#------------------------------------------
sub __getImageTypes {
	# ...
	# provide information about the configured image types
	# returns a list of KIWIXMLTypeData objects. default or
	# primary built type is the first item in the list
	# ---
	my $this   = shift;
	my $xml    = $this->{xml};
	my @result = ();
	my $tData  = $xml -> getImageType();
	if (! $tData) {
		return;
	}
	my $defTypeName = $tData -> getTypeName();
	push @result,$tData;
	my @tNames = @{$xml -> getConfiguredTypeNames()};
	@tNames = sort @tNames;
	for my $tName (@tNames) {
		if ($tName eq $defTypeName) {
			next;
		}
		$tData = $xml -> getType ($tName);
		push @result,$tData;
	}
	return @result;
}

#==========================================
# __getImageVersion
#------------------------------------------
sub __getImageVersion {
	# ...
	# provide information about the image version
	# returns a list with two items: name,version
	# ---
	my $this = shift;
	my $xml  = $this->{xml};
	my $version = $xml -> getPreferences() -> getVersion();
	my $appname = $xml -> getImageName();
	return ($version,$appname);
}

#==========================================
# __checkRequests
#------------------------------------------
sub __checkRequests {
	# ...
	# Verify that the information requested is a supported request
	# ---
	my $this     = shift;
	my $requests = shift;
	my $kiwi = $this -> {kiwi};
	if (! $requests) {
		my $msg = 'No information requested';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	if (! ref $requests) {
		my $msg = 'Expecting ARRAY_REF as first argument for info requests.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my @infoReq = @{$requests};
	#==========================================
	# Verify the requested information is available
	#------------------------------------------
	my %supportedInfoReq;
	$supportedInfoReq{'packages'}      = 'List of packages to be installed';
	$supportedInfoReq{'patterns'}      = 'List configured patterns';
	$supportedInfoReq{'profiles'}      = 'List profiles';
	$supportedInfoReq{'repo-patterns'} = 'List available patterns from repos';
	$supportedInfoReq{'overlay-files'} = 'List of files in root overlay';
	$supportedInfoReq{'archives'}      = 'List of tar archives to be installed';
	$supportedInfoReq{'size'}          = 'List install/delete size estimation';
	$supportedInfoReq{'sources'}       = 'List configured source URLs';
	$supportedInfoReq{'types'}         = 'List configured types';
	$supportedInfoReq{'version'}       = 'List name and version';
	my @infoList;
	for my $info (@infoReq) {
		if (defined $supportedInfoReq{$info}) {
			push @infoList, $info;
			next;
		}
		my $msg = "Requested information option $info not supported, "
			. 'ignoring.';
		$kiwi -> warning ($msg);
		$kiwi -> skipped();
	}
	if (! @infoList) {
		my $msg = 'None of the specified information options are available.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		$kiwi -> info   ("Choose between the following:\n");
		for my $info (sort keys %supportedInfoReq) {
			my $s = sprintf ("--> %-15s:%s\n",$info,$supportedInfoReq{$info});
			$kiwi -> info ($s);
		}
		return;
	}
	return \@infoList;
}

#==========================================
# __cleanMountPnts
#------------------------------------------
sub __cleanMountPnts {
	# ...
	# Clean up any mount points, i.e. unmount and remove the directory
	# ---
	my $this   = shift;
	my $mountPnts = $this->{mountDirs};
	my $kiwi = $this->{kiwi};
	if (! $mountPnts) {
		return 1;
	}
	for my $dir (@{$mountPnts}) {
		next if ! defined $dir;
		KIWIQX::qxx ("umount $dir ; rmdir $dir 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			my $msg = 'Could not clean mount point "'
				. "$dir"
				. '". Please unmount manually and remove the directory.';
			$kiwi -> warning ($msg);
			$kiwi -> skipped();
		}
	}
	return 1;
}

#==========================================
# __getTree
#------------------------------------------
sub __getTree {
	# ...
	# Create the information XML tree
	# ---
	my $this     = shift;
	my $requests = shift;
	my $kiwi     = $this -> {kiwi};
	my $xml      = $this -> {xml};
	if (! $xml) {
		return;
	}
	if (! $this -> __setupRepoMounts($xml)) {
		return;
	}
	my @infoRequests = @{$requests};
	my $meta;
	my $delete;
	my $solfile;
	my $satlist;
	my $solp;
	my $rpat;
	#==========================================
	# Initialize XML imagescan element
	#------------------------------------------
	my $scan = XML::LibXML::Element -> new("imagescan");
	$scan -> setAttribute ("description",$this->{configDir});
	#==========================================
	# Walk through selection list
	#------------------------------------------
	my $generateWanted;
	for my $info (@infoRequests) {
		SWITCH: for ($info) {
			#==========================================
			# overlay-files
			#------------------------------------------
			/^overlay-files/ && do {
				my %result = $this -> __getOverlayFiles();
				if (! %result) {
					$kiwi -> info ("No overlay files found\n");
					return;
				} else {
					foreach my $file (sort keys %result) {
						my $overlay = XML::LibXML::Element->new("overlay");
						$overlay -> setAttribute ("file","$file");
						$scan -> appendChild ($overlay);
					}
				}
				last SWITCH;
			};
			#==========================================
			# repo-patterns
			#------------------------------------------
			/^repo-patterns/ && do {
				my @rpat = $this -> __getRepoPatterns();
				if (! @rpat) {
					$kiwi -> info ("No patterns in repo solvable\n");
					return;
				} else {
					foreach my $p (@rpat) {
						my $pattern = XML::LibXML::Element->new("repopattern");
						$pattern -> setAttribute ("name","$p");
						$scan -> appendChild ($pattern);
					}
				}
				last SWITCH;
			};
			#==========================================
			# patterns
			#------------------------------------------
			/^patterns/      && do {
				my @patterns = $this -> __getPatterns();
				if (! @patterns) {
					$kiwi -> info ("No packages/patterns solved\n");
					return;
				} else {
					foreach my $name (@patterns) {
						my $pattern = XML::LibXML::Element->new("pattern");
						$pattern -> setAttribute ("name",$name);
						$scan -> appendChild ($pattern);
					}
				}
				last SWITCH;
			};
			#==========================================
			# types
			#------------------------------------------
			/^types/         && do {
				my @tNames = $this -> __getImageTypes();
				if (! @tNames) {
					$kiwi -> info ("No image type(s) configured\n");
					return;
				} else {
					# output default or primary built type first
					my $tData = shift @tNames;
					my $defTypeName = $tData -> getTypeName();
					my $type = XML::LibXML::Element -> new('type');
					$type -> setAttribute('name', $defTypeName);
					$type -> setAttribute('primary', 'true');
					my $bootLoc = $tData -> getBootImageDescript();
					if ($bootLoc) {
						$type -> setAttribute('boot', $bootLoc);
					}
					$scan -> appendChild($type);
					# Handle any remaining types in alpha order
					for my $tData (@tNames) {
						my $tName = $tData -> getTypeName();
						$type = XML::LibXML::Element -> new('type');
						$type -> setAttribute('name', $tName);
						my $bootLoc = $tData -> getBootImageDescript();
						if ($bootLoc) {
							$type -> setAttribute('boot', $bootLoc);
						}
						$scan -> appendChild($type);
					}
				}
				last SWITCH;
			};
			#==========================================
			# sources
			#------------------------------------------
			/^sources/       && do {
				my @repos = $this -> __getRepoURI();
				if (! @repos) {
					$kiwi -> info ("No repository configured\n");
					return;
				} else {
					for my $repo (@repos) {
						my $source = XML::LibXML::Element -> new('source');
						$source -> setAttribute('path', $repo -> getPath());
						$source -> setAttribute('type', $repo -> getType());
						my $prio = $repo -> getPriority();
						if ($prio) {
							$source -> setAttribute('priority', $prio);
						}
						my ($uname, $pass) = $repo -> getCredentials();
						if ($uname) {
							$source -> setAttribute('username', $uname);
							$source -> setAttribute('password', $pass);
						}
						$scan -> appendChild($source);
					}
				}
				last SWITCH;
			};
			#==========================================
			# size
			#------------------------------------------
			/^size/          && do {
				my @sizeinfo = $this -> __getSizeEstimation();
				if (! @sizeinfo) {
					$kiwi -> info ("Can't calculate size estimation\n");
					return;
				} else {
					my $sizenode = XML::LibXML::Element -> new("size");
					$sizenode -> setAttribute ("rootsizeKB",$sizeinfo[0]);
					if ($sizeinfo[1]) {
						$sizenode -> setAttribute (
							"deletionsizeKB","$sizeinfo[1]"
						);
					}
					$scan -> appendChild ($sizenode);
				}
				last SWITCH;
			};
			#==========================================
			# packages
			#------------------------------------------
			/^packages/     && do {
				my @packages = $this -> __getPackages();
				if (! @packages) {
					$kiwi -> info ("No packages/patterns solved\n");
					return;
				} else {
					foreach my $p (@packages) {
						my $repo = $p->[4]; $repo =~ s/ /:/g;
						my $pacnode = XML::LibXML::Element -> new("package");
						$pacnode -> setAttribute ("name"   ,"$p->[5]");
						$pacnode -> setAttribute ("arch"   ,"$p->[1]");
						$pacnode -> setAttribute ("version","$p->[2]");
						$pacnode -> setAttribute ("sum"    ,"$p->[3]");
						$pacnode -> setAttribute ("repo"   ,$repo);
						$scan -> appendChild ($pacnode);
					}
				}
				last SWITCH;
			};
			#==========================================
			# archives
			#------------------------------------------
			/^archives/      && do {
				my @archives = $this -> __getArchives();
				if (! @archives) {
					$kiwi -> info ("No archives available\n");
					return;
				} else {
					for my $archive (@archives) {
						my $anode = XML::LibXML::Element -> new("archive");
						$anode -> setAttribute ('name', $archive -> getName());
						$scan -> appendChild ($anode);
					}
				}
				last SWITCH;
			};
			#==========================================
			# profiles
			#------------------------------------------
			/^profiles/      && do {
				my @profiles = $this -> __getProfiles();
				if (! @profiles) {
					$kiwi -> info ("No profiles available\n");
					return;
				} else {
					for my $profile (@profiles) {
						my $name = $profile -> getName();
						my $desc = $profile -> getDescription();
						my $pnode = XML::LibXML::Element -> new("profile");
						$pnode -> setAttribute ('name', "$name");
						$pnode -> setAttribute ('description', "$desc");
						$scan -> appendChild ($pnode);
					}
				}
				last SWITCH;
			};
			#==========================================
			# version
			#------------------------------------------
			/^version/       && do {
				my @vinfo = $this -> __getImageVersion();
				if (! @vinfo) {
					$kiwi -> info ("No image version/name found\n");
					return;
				} else {
					my $vnode = XML::LibXML::Element -> new("image");
					$vnode -> setAttribute ('version', $vinfo[0]);
					$vnode -> setAttribute ("name","$vinfo[1]");
					$scan -> appendChild ($vnode);
				}
			};
		}
	}
	return $scan;
}

#==========================================
# __setupRepoMounts
#------------------------------------------
sub __setupRepoMounts {
	# ...
	# Setup mount points and mount any repositories that need to be mounted
	# locally
	# ---
	my $this  = shift;
	my $xml   = shift;
	my $kiwi  = $this->{kiwi};
	my $cmdL  = $this->{cmdL};
	my $repos = $xml -> getRepositories();
	my @mountPnts;
	for my $repo (@{$repos}) {
		my ($user, $pwd) = $repo -> getCredentials();
		my $source = $repo -> getPath();
		my $urlHandler  = KIWIURL -> new ($cmdL,undef,$user,$pwd);
		my $uri = $urlHandler -> normalizePath ($source);
		#==========================================
		# iso:// sources
		#------------------------------------------
		if ($source =~ /^iso:\/\/(.*\.iso)/) {
			my $iso  = $1;
			if (! -f $iso) {
				return;
			}
			my $data = KIWIQX::qxx (
				"mkdir -p $uri; mount -o loop $iso $uri 2>&1"
			);
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> error  ("Failed to loop mount ISO path: $data");
				$kiwi -> failed ();
				rmdir $uri;
				return;
			}
			push @mountPnts, $uri;
		}
	}
	$this->{mountDirs} = \@mountPnts;
	return $this;
}

#==========================================
# __xmlSetup
#------------------------------------------
sub __xmlSetup {
	# ...
	# Configure the XML object to suitably collect all requested information
	# ---
	my $this = shift;
	my $xml  = shift;
	my $kiwi = $this->{kiwi};
	my $cmdL = $this->{cmdL};
	#==========================================
	# Setup the XML
	#------------------------------------------
	if (! $xml) {
		my $buildProfs = $this -> {buildProfiles};
		my $configDir  = $this -> {configDir};
		my $locator = KIWILocator -> instance();
		my $controlFile = $locator -> getControlFile ($configDir);
		if (! $controlFile) {
			return;
		}
		my $validator = KIWIXMLValidator -> new(
			$controlFile,
			$this->{gdata}->{Revision},
			$this->{gdata}->{Schema},
			$this->{gdata}->{SchemaCVT}
		);
		my $isValid = $validator ? $validator -> validate() : undef;
		if (! $isValid) {
			return;
		}
		$xml = KIWIXML -> new(
			$configDir, $cmdL->getBuildType(), $buildProfs, $cmdL
		);
		if (! defined $xml) {
			return;
		}
	}
	my $pkgMgr = $this->{packageManager};
	if ($pkgMgr) {
		$xml -> getPreferences() -> setPackageManager ($pkgMgr);
	}
	my $ignore = $this -> {ignoreRepos};
	if ($ignore) {
		$xml -> ignoreRepositories();
	}
	if ($this->{replRepo}) {
		$xml -> setRepository($this->{replRepo});
	}
	if ($this->{addlRepos}) {
		$xml -> addRepositories($this->{addlRepos}, 'default');
	}
	return $xml;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this = shift;
	$this -> __cleanMountPnts();
	return;
}

1;
