#================
# FILE          : KIWIManagerSmart.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module adds support for the smart
#               : package manager
#               :
# STATUS        : Development
#----------------
package KIWIManagerSmart;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use Env;
use FileHandle;
use File::Basename;
use Config::IniFiles;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
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
	my $root    = $this->{root};
	#==========================================
	# Create config files/dirs
	#------------------------------------------
	if (! -d $dataDir) {
		KIWIQX::qxx ("mkdir -p $dataDir");
	}
	#==========================================
	# Store smart command parameters
	#------------------------------------------
	$this->{smart} = [
		$locator -> getExecPath('smart'),
		"--data-dir=$dataDir",
		"-o remove-packages=false"
	];
	$this->{smart_chroot} = [
		"smart",
		"--data-dir=$dataDir",
		"-o remove-packages=false"
	];
	$this->{smartroot} = ["-o rpm-root=$root"];
	if (glob ("$root//etc/smart/channels/*")) {
		KIWIQX::qxx ( "rm -f $root/etc/smart/channels/*" );
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
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $xml     = $this->{xml};
	my $chroot  = $this->{chroot};
	my $root    = $this->{root};
	my @kchroot = @{$this->{kchroot}};
	my $data;
	my $code;
	#==========================================
	# Get signature information
	#------------------------------------------
	my $imgCheckSig = $xml -> getPreferences() -> getRPMCheckSig();
	$this->{imgCheckSig} = $imgCheckSig;
	#==========================================
	# smart
	#------------------------------------------
	my @smart = @{$this->{smart}};
	my $optionName  = "rpm-check-signatures";
	my $curCheckSig = KIWIQX::qxx ("@smart config --show $optionName|tr -d '\\n'");
	$this->{curCheckSig} = $curCheckSig;
	if (defined $imgCheckSig) {
		my $option = "$optionName=$imgCheckSig";
		if (! $chroot) {
			$kiwi -> info ("Setting RPM signature check to: $imgCheckSig");
			$data = KIWIQX::qxx ("@smart config --set $option 2>&1");
		} else {
			@smart= @{$this->{smart_chroot}};
			$kiwi -> info ("Setting RPM signature check to: $imgCheckSig");
			$data=KIWIQX::qxx ("@kchroot @smart config --set $option 2>&1");
		}
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return;
		}
		$kiwi -> done ();
	}
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
	my $kiwi    = $this->{kiwi};
	my $chroot  = $this->{chroot};
	my $root    = $this->{root};
	my @kchroot = @{$this->{kchroot}};
	my $curCheckSig = $this->{curCheckSig};
	my $data;
	my $code;
	my @smart  = @{$this->{smart}};
	if (defined $this->{imgCheckSig}) {
		my $optionName  = "rpm-check-signatures";
		my $option = "$optionName=$curCheckSig";
		if (! $chroot) {
			$kiwi -> info ("Reset RPM signature check to: $curCheckSig");
			$data = KIWIQX::qxx ("@smart config --set $option 2>&1");
		} else {
			@smart= @{$this->{smart_chroot}};
			$kiwi -> info ("Reset RPM signature check to: $curCheckSig");
			$data=KIWIQX::qxx ("@kchroot @smart config --set $option 2>&1");
		}
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return;
		}
		$kiwi -> done ();
	}
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
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $chroot  = $this->{chroot};
	my @kchroot = @{$this->{kchroot}};
	my $root    = $this->{root};
	my $data;
	my $code;
	#==========================================
	# Get docs information
	#------------------------------------------
	my $imgExclDocs = $xml -> getPreferences() -> getRPMExcludeDoc();
	$this->{imgExclDocs} = $imgExclDocs;
	my @smart = @{$this->{smart}};
	my $optionName  = "rpm-excludedocs";
	my $curExclDocs = KIWIQX::qxx (
		"@smart config --show $optionName 2>/dev/null | tr -d '\\n'"
	);
	$this->{curExclDocs} = $curExclDocs;
	if (defined $imgExclDocs) {
		my $option = "$optionName=$imgExclDocs";
		if (! $chroot) {
			$kiwi -> info ("Setting RPM doc exclusion to: $imgExclDocs");
			$data = KIWIQX::qxx ("@smart config --set $option 2>&1");
		} else {
			@smart= @{$this->{smart_chroot}};
			$kiwi -> info ("Setting RPM doc exclusion to: $imgExclDocs");
			$data=KIWIQX::qxx ("@kchroot @smart config --set $option 2>&1");
		}
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return;
		}
		$kiwi -> done ();
	}
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
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $chroot  = $this->{chroot};
	my @kchroot = @{$this->{kchroot}};
	my $root    = $this->{root};
	my $curExclDocs = $this->{curExclDocs};
	my $data;
	my $code;
	my @smart = @{$this->{smart}};
	if (defined $this->{imgExclDocs}) {
		my $optionName  = "rpm-excludedocs";
		my $option = "$optionName=$curExclDocs";
		if (! $chroot) {
			$kiwi -> info ("Resetting RPM doc exclusion to: $curExclDocs");
			$data = KIWIQX::qxx ("@smart config --set $option 2>&1");
		} else {
			@smart= @{$this->{smart_chroot}};
			$kiwi -> info ("Resetting RPM doc exclusion to: $curExclDocs");
			$data=KIWIQX::qxx ("@kchroot @smart config --set $option 2>&1");
		}
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return;
		}
		$kiwi -> done ();
	}
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
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my @kchroot= @{$this->{kchroot}};
	my %source = %{$this->{source}};
	my $root   = $this->{root};
	my $dataDir= $this->{dataDir};
	my $data;
	my $code;
	my @channelList = ();
	my @smart  = @{$this->{smart}};
	my @rootdir= @{$this->{smartroot}};
	#==========================================
	# make sure channel list is clean
	#------------------------------------------
	my $chls = KIWIQX::qxx ("@smart channel --show | grep ^\'\\[\'|tr -d [] 2>&1");
	my @chls = split(/\n/,$chls);
	foreach my $c (@chls) {
		chomp $c; KIWIQX::qxx ("@smart channel --remove $c -y 2>&1");
	}
	my $stype; # private or public channels
	my $cmds;  # smart call in and outside of the chroot
	#==========================================
	# re-add new channels
	#------------------------------------------
	if (! $chroot) {
		$stype = "public";
		$cmds  = "@smart @rootdir channel --add";
	} else {
		$stype = "private";
		@smart  = @{$this->{smart_chroot}};
		$cmds   = "@smart channel --add";
	}
	foreach my $chl (keys %{$source{$stype}}) {
		my @opts = @{$source{$stype}{$chl}};
		@opts = map { if (defined $_) { $_ }  } @opts;
		if (! $chroot) {
			$kiwi -> info ("Adding bootstrap smart channel: $chl");
			$data = KIWIQX::qxx ("$cmds $chl @opts 2>&1");
			$code = $? >> 8;
		} else {
			$kiwi -> info ("Adding chroot smart channel: $chl");
			$data = KIWIQX::qxx ("@kchroot $cmds $chl @opts 2>&1");
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("smart: $data");
			return;
		}
		push (@channelList,$chl);
		$kiwi -> done ();
	}
	$this->{channelList} = \@channelList;
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
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $chroot = $this->{chroot};
	my @kchroot= @{$this->{kchroot}};
	my $root   = $this->{root};
	my $dataDir= $this->{dataDir};
	my @channelList = @{$this->{channelList}};
	my $data;
	my $code;
	my @smart  = @{$this->{smart}};
	my @rootdir= @{$this->{smartroot}};
	my @list   = @channelList;
	my $cmds;
	if (! $chroot) {
		$cmds="@smart @rootdir channel --remove";
	} else {
		@smart= @{$this->{smart_chroot}};
		$cmds = "@smart channel --remove";
	}
	if (! $chroot) {
		$kiwi -> info ("Removing smart channel(s): @channelList");
		$data = KIWIQX::qxx ("$cmds @list -y 2>&1");
		$code = $? >> 8;
	} else {
		$kiwi -> info ("Removing smart channel(s): @channelList");
		$data = KIWIQX::qxx ("@kchroot $cmds @list -y 2>&1");
		$code = $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return;
	}
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
	my @pacs        = @_;
	my $this        = shift @pacs;
	my $kiwi        = $this->{kiwi};
	my $root        = $this->{root};
	my @channelList = @{$this->{channelList}};
	my $screenCall  = $this->{screenCall};
	#==========================================
	# setup screen call
	#------------------------------------------
	my $fd = $this -> setupScreen();
	if (! defined $fd) {
		return;
	}
	#==========================================
	# prepare smart loader options
	#------------------------------------------
	my @smart  = @{$this->{smart}};
	$kiwi -> info ("Downloading packages...");
	my @loadOpts = (
		"--target=$root"
	);
	#==========================================
	# Create screen call file
	#------------------------------------------
	print $fd "function clean { kill \$SPID; ";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "rm -f $root/etc/smart/channels/*; ";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "@smart update @channelList &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "test \$? = 0 && @smart download @pacs @loadOpts &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "ECODE=\$?\n";
	print $fd "echo \$ECODE > $screenCall.exit\n";
	print $fd "rm -f $root/etc/smart/channels/*\n";
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
	my @smart = @{$this->{smart_chroot}};
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
	print $fd "@kchroot @smart update &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "test \$? = 0 && @kchroot @smart channel --show &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "test \$? = 0 && @kchroot @smart install -y ";
	print $fd "@addonPackages || false &\n";
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
	my @smart = @{$this->{smart_chroot}};
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
	print $fd "@kchroot @smart update &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "test \$? = 0 && @kchroot @smart channel --show &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "test \$? = 0 && @kchroot @smart remove -y ";
	print $fd "@removePackages || false &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "ECODE=\$?\n";
	print $fd "echo \$ECODE > $screenCall.exit\n";
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
	#==========================================
	# prepare smart loader options
	#------------------------------------------
	my @smart = @{$this->{smart_chroot}};
	my @opts = (
		"--log-level=error",
		"-y"
	);
	my $force = $xml -> getPreferences() -> getRPMForce();
	if (defined $force) {
		push (@opts,"-o rpm-force=yes");
	}
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
	print $fd "@kchroot @smart update &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "test \$? = 0 && ";
	print $fd "@kchroot @smart channel --show &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	#==========================================
	# Handle upgrade request
	#------------------------------------------
	if (! $noUpgrade) {
		print $fd "test \$? = 0 && @kchroot @smart upgrade @opts &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
	}
	#==========================================
	# Handle install request
	#------------------------------------------
	if (defined $addPacks) {
		my @addonPackages = @{$addPacks};
		if (@addonPackages) {
			print $fd "test \$? = 0 && @kchroot @smart install @opts ";
			print $fd "@addonPackages || false &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
	}
	#==========================================
	# Handle remove request
	#------------------------------------------
	if (defined $delPacks) {
		my @removePackages = @{$delPacks};
		if (@removePackages) {
			print $fd "test \$? = 0 && @kchroot @smart remove -y ";
			print $fd "@removePackages || false &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
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
	my @channelList = @{$this->{channelList}};
	my $screenCall  = $this->{screenCall};
	my %source      = %{$this->{source}};
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
	my @rootdir = @{$this->{smartroot}};
	if (! $chroot) {
		#==========================================
		# setup install options outside of chroot
		#------------------------------------------
		my @smart = @{$this->{smart}};
		my @installOpts = (
			"--explain",
			"--log-level=error",
			"-y"
		);
		my $force = $xml -> getPreferences() -> getRPMForce();
		if (defined $force) {
			push (@installOpts,"-o rpm-force=yes");
		}
		#==========================================
		# Add package manager to package list
		#------------------------------------------
		if ($this -> setupInstallPackages()) {
			push (@packs,$manager);
		}
		$kiwi -> info ("Initializing image system on: $root");
		#==========================================
		# Create screen call file
		#------------------------------------------
		print $fd "function clean { kill \$SPID;";
		print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
		print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
		print $fd "c=\$((\$c+1));done;\n";
		print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
		print $fd "rm -f $root/etc/smart/channels/*; ";
		print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
		print $fd "trap clean INT TERM\n";
		print $fd "@smart @rootdir channel --show &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		print $fd "test \$? = 0 && @smart @rootdir update ";
		print $fd "@channelList || false &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		print $fd "test \$? = 0 && @smart @rootdir install ";
		print $fd "@packs @installOpts &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		print $fd "ECODE=\$?\n";
		print $fd "echo \$ECODE > $screenCall.exit\n";
		print $fd "rm -f $root/etc/smart/channels/*\n";
		print $fd "exit \$ECODE\n";
	} else {
		#==========================================
		# setup install options inside of chroot
		#------------------------------------------
		my @smart   = @{$this->{smart_chroot}};
		my @install = @packs;
		my @installOpts = (
			"--explain",
			"--log-level=error",
			"-y"
		);
		my $force = $xml -> getPreferences() -> getRPMForce();
		if (defined $force) {
			push (@installOpts,"-o rpm-force=yes");
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
		print $fd "echo 1 > $screenCall.exit;exit 1; }\n";
		print $fd "trap clean INT TERM\n";
		print $fd "@kchroot @smart update &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		print $fd "test \$? = 0 && @kchroot @smart channel --show &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		print $fd "test \$? = 0 && @kchroot @smart install ";
		print $fd "@install @installOpts &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
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
	#==========================================
	# setup baselibs
	#------------------------------------------
	if (! $chroot) {
		if (! $this -> rpmLibs()) {
			return;
		}
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
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %source  = %{$this->{source}};
	my $dataDir = $this->{dataDir};
	my @smart = @{$this->{smart}};
	foreach my $channel (keys %{$source{public}}) {
		$kiwi -> info ("Removing smart channel: $channel\n");
		KIWIQX::qxx ("@smart channel --remove $channel -y 2>&1");
	}
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
	my @smart  = @{$this->{smart}};
	my @rootdir= @{$this->{smartroot}};
	if (! $chroot) {
		$kiwi -> info ("Checking for package: $pack");
		$data = KIWIQX::qxx ("@smart @rootdir query --installed $pack 2>/dev/null");
		$code = $? >> 8;
	} else {
		@smart= @{$this->{smart_chroot}};
		$kiwi -> info ("Checking for package: $pack");
		$data = KIWIQX::qxx (
			"@kchroot @smart query --installed $pack 2>/dev/null"
		);
		$code = $? >> 8;
	}
	if ($code == 0) {
		if (! grep {/$pack/} $data) {
			$code = 1;
		}
	}
	if ($code != 0) {
		$kiwi -> failed  ();
		$kiwi -> error   ("Package $pack is not installed");
		$kiwi -> skipped ();
		return $code;
	}
	$kiwi -> done();
	return $code;
}

1;
