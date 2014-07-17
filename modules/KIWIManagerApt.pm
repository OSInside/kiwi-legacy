#================
# FILE          : KIWIManagerApt.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module adds support for the apt/dpkg
#               : package manager
#               :
# STATUS        : Development
#----------------
package KIWIManagerApt;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use base qw /Exporter/;
use Carp qw (cluck);
use Env;
use FileHandle;
use File::Basename;
use Config::IniFiles;

#==========================================
# Base class
#------------------------------------------
use base qw /KIWIManager/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILog;
use KIWILocator;
use KIWIQX;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
    my $this  = $class->SUPER::new(@_);
	#==========================================
	# Retrieve data from base class
	#------------------------------------------
	my $dataDir = $this->{dataDir};
	my $locator = $this->{locator};
	#==========================================
	# Create config files/dirs
	#------------------------------------------
	if (! -d $dataDir) {
		KIWIQX::qxx ("mkdir -p $dataDir");
	}
	if (! -d "$dataDir/lists") {
		KIWIQX::qxx ("mkdir -p $dataDir/lists");
	}
	if (! -d "$dataDir/repos") {
		KIWIQX::qxx ("mkdir -p $dataDir/repos");
	}
	if (! -d "$dataDir/preferences.d") {
		KIWIQX::qxx ("mkdir -p $dataDir/preferences.d");
	}
	if (! -d "$dataDir/sources.list.d") {
		KIWIQX::qxx ("mkdir -p $dataDir/sources.list.d");
	}
	#==========================================
	# Store apt-get command parameters
	#------------------------------------------
	$this->{apt} = [
		$locator -> getExecPath('apt-get'),
		"-c $dataDir/apt.conf",
		"-y"
	];
	$this->{apt_chroot} = [
		"apt-get",
		"-c $dataDir/apt.conf",
		"-y"
	];
	#==========================================
	# Create apt config file
	#------------------------------------------
	$this->{aptconfig} = $this -> createAptConfig();
	if (! -f $this->{aptconfig}) {
		return;
	}
	return $this;
}

#==========================================
# setupSignatureCheck
#------------------------------------------
sub setupSignatureCheck {
	# ...
	# Check if the image description contains the signature
	# check option or not. If yes activate or deactivate it
	# according to the used package manager
	# ---
	# I did not find a way how to turn off the signature check
	# when installing via dpkg. The install process also uses
	# the option --force-all at the moment which makes an extra
	# signature check yes/no option obsolete
	# ---
	my $this    = shift;
	return $this;
}

#==========================================
# resetSignatureCheck
#------------------------------------------
sub resetSignatureCheck {
	# ...
	# reset the signature check option to the previos
	# value of the package manager
	# ---
	my $this    = shift;
	return $this;
}

#==========================================
# setupExcludeDocs
#------------------------------------------
sub setupExcludeDocs {
	# ...
	# Check if the image description contains the exclude
	# docs option or not. If yes activate or deactivate it
	# according to the used package manager
	# ---
	# It seems dpkg can only exclude by path which is not
	# what I'd like to achieve. if the deb packages could
	# exclude docs because they are marked in the package
	# as documentation we can add it here
	# ---
	my $this = shift;
	return $this;
}

#==========================================
# resetExcludeDocs
#------------------------------------------
sub resetExcludeDocs {
	# ...
	# reset the signature check option to the previos
	# value of the package manager
	# ---
	my $this   = shift;
	return $this;
}

#==========================================
# setupInstallationSource
#------------------------------------------
sub setupInstallationSource {
	# ...
	# setup an installation source to retrieve packages
	# from. multiple sources are allowed
	# ---
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $chroot  = $this->{chroot};
	my %source  = %{$this->{source}};
	my $dataDir = $this->{dataDir};
	my @kchroot = @{$this->{kchroot}};
	my @apt     = @{$this->{apt_chroot}};
	my $stype   = "private";
	if (! $chroot) {
		$stype   = "public";
	}
	my $mainDist;
	my $mainPath;
	my $data;
	my $code;
	my $fd;
	#==========================================
	# create new repo sources file
	#------------------------------------------
	if ($chroot) {
		$fd = FileHandle -> new();
		my $repo = "$dataDir/repos/sources.list";
		if (! $fd -> open (">$repo")) {
			$kiwi -> error  ("Failed to create $repo file");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Walk through repo information
	#------------------------------------------
	foreach my $alias (keys %{$source{$stype}}) {
		#==========================================
		# walk through the repo options
		#------------------------------------------
		my @sopts = @{$source{$stype}{$alias}};
		my $dist  = $source{$alias}{distribution};
		my $comp  = $source{$alias}{components};
		my $path;
		#==========================================
		# Check distribution name tag
		#------------------------------------------
		if (! $dist) {
			$kiwi -> error  ("No distribution name set for this deb repo");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# Set path suitable for apt
		#------------------------------------------
		foreach my $opt (@sopts) {
			next if ! defined $opt;
			if ($opt =~ /(.*?)=(.*)/) {
				my $key = $1;
				my $val = $2;
				if (($key eq "baseurl") || ($key eq "path")) {
					if ($val =~ /^'\//) {
						$val =~ s/^'(.*)'$/"file:\/\/$1"/
					}
					$val =~ s/^\"//;
					$val =~ s/\"$//;
					$val =~ s/^\'//;
					$val =~ s/\'$//;
				}
				$path = $val;
			}
		}
		if (! $path) {
			$kiwi -> error  ("No source path for repo $alias found");
			$kiwi -> failed (); 
			return;
		}
		if (! $comp) {
			$comp = 'main';
		}
		$mainDist = $dist;
		if ($alias eq "system") {
			$mainPath = $path;
		}
		if ($chroot) {
			$kiwi -> info ("Adding chroot apt repo: $alias");
			print $fd "deb $path $dist $comp"."\n";
			$kiwi -> done();
		}
	}
	if ($chroot) {
		$fd -> close();
	}
	#==========================================
	# prepare for debootstrap or apt-get
	#------------------------------------------
	if (! $chroot) {
		#==========================================
		# store main dist and path for debootstrap
		#------------------------------------------
		if (! defined $mainPath) {
			$kiwi -> error  ("No repo aliased as 'system' repo");
			$kiwi -> failed ();
			return;
		}
		if (! defined $mainDist) {
			$kiwi -> error  ("No distribution name tag found");
			$kiwi -> failed ();
			return;
		}
		$this->{mainPath} = $mainPath;
		$this->{mainDist} = $mainDist;
	} else {
		#==========================================
		# create apt cache
		#------------------------------------------
		$kiwi -> info ("Creating apt metadata cache...");
		$data = KIWIQX::qxx ("@kchroot @apt update 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("apt-get: $data");
			return;
		}
		$kiwi -> done();
	}
	return $this;
}

#==========================================
# resetInstallationSource
#------------------------------------------
sub resetInstallationSource {
	# ...
	# clean the installation source environment
	# which means remove temporary inst-sources
	# ---
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $dataDir = $this->{dataDir};
	$kiwi -> info ("Removing apt repo(s) in: $dataDir");
	KIWIQX::qxx ("rm -f $dataDir/repos/* 2>&1");
	KIWIQX::qxx ("rm -f $dataDir/lists/* 2>&1");
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupDownload
#------------------------------------------
sub setupDownload {
	# ...
	# download package files for later handling
	# using the package manager download functionality
	# ---
	my @pacs = @_;
	my $this = shift @pacs;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my @apt  = @{$this->{apt}};
	my $screenCall = $this->{screenCall};
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return;
	}
	#==========================================
	# Create screen call file
	#------------------------------------------
	print $fd "function clean { kill \$SPID; ";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;";
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "pushd $root && @apt download @pacs &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "ECODE=\$?\n";
	print $fd "popd\n";
	print $fd "echo \$ECODE > $screenCall.exit\n";
	print $fd "exit \$ECODE\n";
	$fd -> close();
	return $this -> setupScreenCall();
}

#==========================================
# installPackages
#------------------------------------------
sub installPackages {
	# ...
	# install packages in the previosly installed root
	# system using the package manager install method
	# ---
	my $this       = shift;
	my $instPacks  = shift;
	my $kiwi       = $this->{kiwi};
	my $root       = $this->{root};
	my @kchroot    = @{$this->{kchroot}};
	my $screenCall = $this->{screenCall};
	#==========================================
	# check addon packages
	#------------------------------------------
	if (! defined $instPacks) {
		return $this;
	}
	#==========================================
	# setup screen call
	#------------------------------------------
	my @addonPackages = @{$instPacks};
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return;
	}
	my @apt = @{$this->{apt_chroot}};
	#==========================================
	# Create screen call file
	#------------------------------------------
	$kiwi -> info ("Installing addon packages...");
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;";
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "@kchroot @apt install @addonPackages &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "ECODE=\$?\n";
	print $fd "echo \$ECODE > $screenCall.exit\n";
	print $fd "exit \$ECODE\n";
	$fd -> close();
	return $this -> setupScreenCall();
}

#==========================================
# removePackages
#------------------------------------------
sub removePackages {
	# ...
	# remove packages from the previosly installed root
	# system using the package manager remove method
	# ---
	my $this       = shift;
	my $removePacks= shift;
	my $kiwi       = $this->{kiwi};
	my $root       = $this->{root};
	my @kchroot    = @{$this->{kchroot}};
	my $screenCall = $this->{screenCall};
	my @apt        = @{$this->{apt_chroot}};
	#==========================================
	# check to be removed packages
	#------------------------------------------
	if (! defined $removePacks) {
		return $this;
	}
	#==========================================
	# setup screen call
	#------------------------------------------
	my @removePackages = @{$removePacks};
	if (! @removePackages) {
		return $this;
	}
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return;
	}
	#==========================================
	# Create screen call file
	#------------------------------------------
	$kiwi -> info ("Removing packages...");
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "@kchroot mount -t proc proc /proc"."\n";
	print $fd "@kchroot @apt remove @removePackages &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "ECODE=\$?\n";
	print $fd "echo \$ECODE > $screenCall.exit\n";
	print $fd "@kchroot umount /proc"."\n";
	#print $fd "@kchroot /bin/bash\n";
	print $fd "exit \$ECODE\n";
	$fd -> close();
	return $this -> setupScreenCall();
}

#==========================================
# setupUpgrade
#------------------------------------------
sub setupUpgrade {
	# ...
	# upgrade the previosly installed root system
	# using the package manager upgrade functionality
	# along with the upgrade additional packages can
	# be removed or installed. It's also possible to
	# perform only the package remove/install operation
	# without running the dist-upgrade
	# ---
	my $this       = shift;
	my $addPacks   = shift;
	my $delPacks   = shift;
	my $noUpgrade  = shift;
	my $kiwi       = $this->{kiwi};
	my $root       = $this->{root};
	my $xml        = $this->{xml};
	my @kchroot    = @{$this->{kchroot}};
	my $screenCall = $this->{screenCall};
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return;
	}
	my @apt  = @{$this->{apt_chroot}};
	#==========================================
	# Create screen call file
	#------------------------------------------
	if ($noUpgrade) {
		$kiwi -> info (
			"Checking for package install/remove requests..."
		);
	} else {
		$kiwi -> info (
			"Upgrading/Checking for package install/remove requests....."
		);
	}
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	#==========================================
	# Handle upgrade request
	#------------------------------------------
	if (! $noUpgrade) {
		print $fd "test \$? = 0 && @kchroot @apt upgrade &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
	}
	#==========================================
	# Handle install request
	#------------------------------------------
	if (defined $addPacks) {
		my @addonPackages = @{$addPacks};
		my @newpatts = ();
		my @newpacks = ();
		foreach my $pac (@addonPackages) {
			if ($pac =~ /^pattern:(.*)/) {
				push @newpatts,"\"$1\"";
			} else {
				push @newpacks,$pac;
			}
		}
		@addonPackages = @newpacks;
		if (@newpatts) {
			# TODO: how to handle selections
		}
		if (@addonPackages) {
			print $fd "@kchroot @apt install @addonPackages &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
	}
	#==========================================
	# Handle remove request
	#------------------------------------------
	if (defined $delPacks) {
		my @removePackages = @{$delPacks};
		if (@removePackages) {
			print $fd "@kchroot @apt remove @removePackages &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
			print $fd "test \$? = 0 && ";
		}
	}
	print $fd "ECODE=\$?\n";
	print $fd "echo \$ECODE > $screenCall.exit\n";
	print $fd "exit \$ECODE\n";
	$fd -> close();
	#==========================================
	# Perform call
	#------------------------------------------
	return $this -> setupScreenCall();
}

#==========================================
# setupRootSystem
#------------------------------------------
sub setupRootSystem {
	# ...
	# install the bootstrap system to be able to
	# chroot into this minimal image
	# ---
	my @packs       = @_;
	my $this        = shift @packs;
	my $kiwi        = $this->{kiwi};
	my $chroot      = $this->{chroot};
	my @kchroot     = @{$this->{kchroot}};
	my $root        = $this->{root};
	my $xml         = $this->{xml};
	my $manager     = $this->{manager};
	my $screenCall  = $this->{screenCall};
	my %source      = %{$this->{source}};
	my $mainPath    = $this->{mainPath};
	my $mainDist    = $this->{mainDist};
	#==========================================
	# search for licenses on media
	#------------------------------------------
	if (! $chroot) {
		$this -> provideMediaLicense();
	}
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return;
	}
	if (! $chroot) {
		$kiwi -> info ("Initializing image system on: $root");
		#==========================================
		# Create screen call file
		#------------------------------------------
		mkdir "$root/tmp";
		print $fd "function clean { kill \$SPID;";
		print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
		print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
		print $fd "c=\$((\$c+1));done;\n";
		print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
		print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
		print $fd "trap clean INT TERM\n";
		print $fd "debootstrap $mainDist $root $mainPath &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		print $fd "ECODE=\$?\n";
		print $fd "echo \$ECODE > $screenCall.exit\n";
		print $fd "exit \$ECODE\n";
	} else {
		#==========================================
		# select groups and packages
		#------------------------------------------
		my @apt       = @{$this->{apt_chroot}};
		my @install   = ();
		my @newpatts  = ();
		foreach my $need (@packs) {
			if ($need =~ /^pattern:(.*)/) {
				push @newpatts,"\"$1\"";
				next;
			}
			push @install,$need;
		}
		#==========================================
		# Create screen call file
		#------------------------------------------
		$kiwi -> info ("Installing image packages...");
		print $fd "function clean { kill \$SPID;";
		print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
		print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
		print $fd "c=\$((\$c+1));done;\n";
		print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
		print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
		print $fd "trap clean INT TERM\n";
		if (@newpatts) {
			# TODO: how to handle selections
		}
		if (@install) {
			if (@newpatts) {
				print $fd "test \$? = 0 && ";
			}
			print $fd "@kchroot @apt install @install &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
		print $fd "ECODE=\$?\n";
		print $fd "echo \$ECODE > $screenCall.exit\n";
		print $fd "exit \$ECODE\n";
	}
	$fd -> close();
	#==========================================
	# run process
	#------------------------------------------
	if (! $this -> setupScreenCall()) {
		return;
	}
	return $this;
}

#==========================================
# resetSource
#------------------------------------------
sub resetSource {
	# ...
	# cleanup source data. In case of any interrupt
	# which means remove all changes made by %source
	# ---
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $dataDir = $this->{dataDir};
	$kiwi -> info ("Removing apt repo(s) in: $dataDir");
	KIWIQX::qxx ("rm -f $dataDir/repos/* 2>&1");
	KIWIQX::qxx ("rm -f $dataDir/lists/* 2>&1");
	$kiwi -> done();
	return $this;
}

#==========================================
# setupPackageInfo
#------------------------------------------
sub setupPackageInfo {
	# ...
	# check if a given package is installed or not.
	# return the exit code from the call
	# ---
	my $this   = shift;
	my $pack   = shift;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my @kchroot= @{$this->{kchroot}};
	my $root   = $this->{root};
	my $data;
	my $code;
	my $str = "not installed";
	if (! $chroot) {
		$kiwi -> info ("Checking for package: $pack");
		$data = KIWIQX::qxx ("dpkg --root $root -s \"$pack\" 2>&1");
		$code = $? >> 8;
	} else {
		$kiwi -> info ("Checking for package: $pack");
		$data= KIWIQX::qxx ("@kchroot dpkg -s \"$pack\" 2>&1 ");
		$code= $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> failed  ();
		$kiwi -> error   ("Package $pack is not installed");
		$kiwi -> skipped ();
		return 1;
	}
	$kiwi -> done();
	return 0;
}

#==========================================
# createAptConfig
#------------------------------------------
sub createAptConfig {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $root   = $this->{root};
	my $meta   = $this->{dataDir};
	my $config = $meta."/apt.conf";
	my $fd = FileHandle -> new();
	if (! $fd -> open (">$config")) {
		$kiwi -> error  ("Failed to create apt configuration: $!");
		$kiwi -> failed ();
		return;
	}
	print $fd 'Dir "/";'."\n";
	print $fd 'Dir::State "var/cache/kiwi/apt/";'."\n";
	print $fd 'Dir::Etc   "var/cache/kiwi/apt/";'."\n";
	print $fd 'Dir::Etc::sourcelist "repos/sources.list";'."\n";
	print $fd 'Dir::State::lists "lists/";'."\n";
	print $fd 'APT'."\n";
	print $fd '{'."\n";
	print $fd "\t".'Get'."\n";
	print $fd "\t".'{'."\n";
	print $fd "\t\t".'Force-Yes "true";'."\n";
	print $fd "\t".'}'."\n";
	print $fd '};'."\n";
	print $fd 'DPkg'."\n";
	print $fd '{'."\n";
	print $fd "\t".'Options {"--force-all";}'."\n";
	print $fd '};'."\n";
	$fd -> close();
	return $config;
}

1;
