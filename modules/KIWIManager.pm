#================
# FILE          : KIWIManager.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to support multiple
#               : package manager like smart or zypper
#               :
# STATUS        : Development
#----------------
package KIWIManager;
#==========================================
# Modules
#------------------------------------------
require Exporter;
use strict;
use KIWILog;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (%packageManager);

#==========================================
# Private
#------------------------------------------
my $kiwi;           # log handler
my $xml;            # xml description
my $manager;        # package manager name
my %source;         # installation sources
my @channelList;    # list of channel names
my $root;           # root path
my $chroot = 0;     # is chroot or not

#==========================================
# Private
#------------------------------------------
our %packageManager;
$packageManager{smart}   = "/usr/bin/smart";
$packageManager{zypper}  = "/usr/bin/zypper";
$packageManager{default} = "smart";

#==========================================
# Private [internal]
#------------------------------------------
my $curCheckSig;
my $imgCheckSig;

#==========================================
# Constructor
#------------------------------------------
sub new { 
	# ...
	# Create a new KIWIManager object, which is used
	# to import all data needed to abstract from different
	# package managers
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi = shift;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	$xml = shift;
	if (! defined $xml) {
		$kiwi -> error  ("Missing XML description pointer");
		$kiwi -> failed ();
		return undef;
	}
	my $sourceRef = shift;
	if (! defined $sourceRef) {
		$kiwi -> error  ("Missing channel description pointer");
		$kiwi -> failed ();
		return undef;
	}
	%source  = %{$sourceRef};
	$root = shift;
	if (! defined $root) {
		$kiwi -> error  ("Missing chroot path");
		$kiwi -> failed ();
		return undef;
	}
	$manager = shift;
	if (! defined $manager) {
		$manager = "smart";
	}
	@channelList = ();
	return $this;
}

#==========================================
# switchToChroot
#------------------------------------------
sub switchToChroot {
	$chroot = 1;
}

#==========================================
# switchToLocal
#------------------------------------------
sub switchToLocal {
	$chroot = 0;
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
	my $this = shift;
	my $data;
	my $code;
	#==========================================
	# Get signature information
	#------------------------------------------
	$imgCheckSig = $xml -> getRPMCheckSignatures();

	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		my $optionName  = "rpm-check-signatures";
		$curCheckSig = qx (smart config --show $optionName|tr -d '\n');
		if (defined $imgCheckSig) {
			$kiwi -> info ("Setting RPM signature check to: $imgCheckSig");
			my $option = "$optionName=$imgCheckSig";
			if (! $chroot) {
				$data = qx ( smart config --set $option 2>&1 );
			} else {
				$data = qx ( chroot $root smart config --set $option 2>&1 );
			}
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			$kiwi -> done ();
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		# nothing to do for zypper here...
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
	my $this = shift;
	my $data;
	my $code;
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		if (defined $imgCheckSig) {
			my $optionName  = "rpm-check-signatures";
			$kiwi -> info ("Resetting RPM signature check to: $curCheckSig");
			my $option = "$optionName=$imgCheckSig";
			if (! $chroot) {
				$data = qx (smart config --set $option 2>&1);
			} else {
				$data = qx (chroot $root smart config --set $option 2>&1);
			}
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			$kiwi -> done ();
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		# nothing to do for zypper here...
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
	my $this = shift;
	my $data;
	my $code;
	#==========================================
	# Reset channel list
	#------------------------------------------
	@channelList = ();

	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		my $stype = "private";
		if (! $chroot) {
			$stype = "public";
		}
		foreach my $chl (keys %{$source{$stype}}) {
			my @opts = @{$source{$stype}{$chl}};
			if (! $chroot) {
				$kiwi -> info ("Adding local smart channel: $chl");
				$data = qx ( smart channel --add $chl @opts 2>&1 );
				$code = $? >> 8;
			} else {
				$kiwi -> info ("Adding image smart channel: $chl");
				$data = qx ( chroot $root smart channel --add $chl @opts 2>&1 );
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			push (@channelList,$chl);
			$kiwi -> done ();
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		my $stype = "private";
		if (! $chroot) {
			$stype = "public";
		}
		foreach my $alias (keys %{$source{$stype}}) {
			my @sopts = @{$source{$stype}{$alias}};
			my @zopts = ();
			foreach my $opt (@sopts) {
				my ($key,$val) = split (/=/,$opt);
				#==========================================
				# Adapt URI parameter
				#------------------------------------------
				if (($key eq "baseurl") || ($key eq "path")) {
					if ($val =~ /^\//) {
						$val = "file://$val";
					}
					push (@zopts,$val);
				}
				#==========================================
				# Adapt type parameter
				#------------------------------------------
				if ($key eq "type") {
					if ($val eq "yast2") {
						$val = "YaST";
					}
					push (@zopts,"--type $val");
				}
			}
			my $zypp = "zypper service-add @zopts";
			if (! $chroot) {
				$kiwi -> info ("Adding local zypper service: $alias");
				$data = qx (bash -c "yes | $zypp $alias 2>&1");
				$code = $? >> 8;
			} else {
				$kiwi -> info ("Adding image zypper service: $alias");
				$data = qx (chroot $root bash -c "yes | $zypp $alias 2>&1");
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ($data);
				return undef;
			}
			push (@channelList,$alias);
			$kiwi -> done ();
		}
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
	my $this = shift;
	my $data;
	my $code;
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		$kiwi -> info ("Removing smart channel(s): @channelList");
		my @list = @channelList;
		if (! $chroot) {
			$data = qx ( smart channel --remove @list -y 2>&1 );
			$code = $? >> 8;
		} else {
			$data = qx ( chroot $root smart channel --remove @list -y 2>&1 );
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		$kiwi -> info ("Removing zypper service(s): @channelList");
		my @list = @channelList;
		if (! $chroot) {
			$data = qx ( zypper service-delete @list 2>&1 );
			$code = $? >> 8;
		} else {
			$data = qx ( chroot $root zypper service-delete @list 2>&1 );
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$kiwi -> done ();
	}
	return $this;
}

#==========================================
# setupRootSystem
#------------------------------------------
sub setupRootSystem {
	# ...
	# install the bootstrap system to be able to
	# chroot into this minimal image
	# ---
	my $this  = shift;
	my @packs = @_;
	my $screenCall;
	my $screenCtrl;
	my $screenLogs;
	my $data;
	my $code;
	#==========================================
	# screen files
	#------------------------------------------
	my $screenCall = $root."/screenrc.smart";
	my $screenCtrl = $root."/screenrc.ctrls";
	my $screenLogs = $root."/screenrc.log";

	#==========================================
	# Initiate screen call file
	#------------------------------------------
	if ((! open (FD,">$screenCall")) || (! open (CD,">$screenCtrl"))) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create call file: $!");
		$kiwi -> failed ();
		resetInstallationSource();
		return undef;
	}
	print CD "logfile $screenLogs\n";
	close CD;
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		if (! $chroot) {
			$kiwi -> info ("Initializing image system on: $root...");
			my $forceChannels = join (",",@channelList);
			my @installOpts = (
				"-o rpm-root=$root",
				"-o deb-root=$root",
				"-o force-channels=$forceChannels",
				"--explain",
				"-y"
			);
			#==========================================
			# Add package manager to package list
			#------------------------------------------
			push (@packs,$manager);
			#==========================================
			# Create screen call file
			#------------------------------------------
			print FD "smart update @channelList\n";
			print FD "test \$? = 0 && smart install @packs @installOpts\n";
			print FD "echo \$? > $screenCall.exit\n";
		} else {
			$kiwi -> info ("Installing image packages...");
			my $querypack = "--installed --hide-version";
			my @installed = qx ( chroot $root smart query '*' $querypack );
			chomp ( @installed );
			my @install   = ();
			foreach my $need (@packs) {
				my $found = 0;
				foreach my $have (@installed) {
					if ($have eq $need) {
						$found = 1; last;
					}
				}
				if (! $found) {
					push @install,$need;
				}
			}
			my @installOpts = (
				"--explain",
				"-y"
			);
			print FD "chroot $root smart update\n";
			print FD "test \$? = 0 && chroot $root smart install @install ";
			print FD "@installOpts\n";
			print FD "echo \$? > $screenCall.exit\n";
		}
		close FD;
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		if (! $chroot) {
			# TODO
			$kiwi -> error  ("*** not implemented ***");
			$kiwi -> failed ();
			resetInstallationSource();
			return undef;
		} else {
			$kiwi -> info ("Installing image packages...");
			print FD "chroot $root zypper install -y @packs\n";
			print FD "echo \$? > $screenCall.exit\n";
		}
		close FD;
	}
	#==========================================
	# run update and install in screen
	#------------------------------------------
	$data = qx ( chmod 755 $screenCall );
	$data = qx ( screen -L -D -m -c $screenCtrl $screenCall );
	$code = $? >> 8;
	if (open (FD,$screenLogs)) {
		local $/; $data = <FD>; close FD;
	}
	if ($code == 0) {
		if (! open (FD,"$screenCall.exit")) {
			$code = 1;
		} else {
			$code = <FD>; chomp $code;
			close FD;
		}
	}
	qx ( rm -f $screenCall* );
	qx ( rm -f $screenCtrl );
	qx ( rm -f $screenLogs );
	#==========================================
	# check exit code from screen session
	#------------------------------------------
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		resetInstallationSource();
		return undef;
	}
	$kiwi -> done ();
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
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		foreach my $channel (keys %{$source{public}}) {
			#$kiwi -> info ("Removing smart channel: $channel\n");
			qx ( smart channel --remove $channel -y 2>&1 );
		}
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		foreach my $channel (keys %{$source{public}}) {
			#$kiwi -> info ("Removing zypper service: $channel\n");
			qx ( zypper service-delete $channel 2>&1 );
		}
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
	my $this = shift;
	my $pack = shift;
	my $data;
	my $code;
	my $opts;
	#==========================================
	# smart
	#------------------------------------------
	if ($manager eq "smart") {
		$kiwi -> info ("Checking for package: $pack");
		if (! $chroot) {
			$data = qx ( smart query --installed $pack | grep -qi $pack 2>&1 );
			$code = $? >> 8;
		} else {
			$opts = "--installed $pack";
			$data = qx ( chroot $root smart query $opts | grep -qi $pack 2>&1 );
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Package $pack is not installed");
			$kiwi -> failed ();
			return $code;
		}
		$kiwi -> done();
		return $code;
	}
	#==========================================
	# zypper
	#------------------------------------------
	if ($manager eq "zypper") {
		$kiwi -> info ("Checking for package: $pack");
		my $str = "not installed";
		if (! $chroot) {
			$data = qx ( zypper info $pack | grep -qi $str 2>&1 );
			$code = $? >> 8;
		} else {
			$data = qx ( chroot $root zypper info $pack | grep -qi $str 2>&1 );
			$code = $? >> 8;
		}
		if ($code == 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Package $pack is not installed");
			$kiwi -> failed ();
			return 1;
		}
		$kiwi -> done();
		return 0;
	}
	return 1;
}

1;
