#================
# FILE          : KIWIManagerZypper.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module adds support for the zypper
#               : package manager
#               :
# STATUS        : Development
#----------------
package KIWIManagerZypper;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;
use Carp qw (cluck);
use Env;
use FileHandle;
use File::Basename;
use Config::IniFiles;
#==========================================
# KIWI Modules
#------------------------------------------
use KIWILog;
use KIWILocator;
use KIWIQX qw (qxx);
use KIWIXML;
use KIWIXMLPreferenceData;

#==========================================
# Modules
#------------------------------------------
use base qw /KIWIManager/;

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
	my $dataDir    = $this->{dataDir};
	my $targetArch = $this->{targetArch};
	my $locator    = $this->{locator};
	my $root       = $this->{root};
	my $xml        = $this->{xml};
	my $kiwi       = $this->{kiwi};
	#==========================================
	# Create config files/dirs
	#------------------------------------------
	qxx ("mkdir -p $dataDir");
	my $zypperConf = "$dataDir/zypper.conf.$$";
	my $zyppConf = "$dataDir/zypp.conf.$$";
	qxx ("echo '[main]' > $zypperConf");
	qxx ("echo '[main]' > $zyppConf");
	local $ENV{ZYPP_CONF} = $zyppConf;
	my $zconfig = Config::IniFiles -> new (
		-file => $zyppConf, -allowedcommentchars => '#'
	);
	my ($uname, $pass) = $xml->getHttpsRepositoryCredentials_legacy();
	if ($uname) {
		$kiwi -> info ('Creating credentials data');
		my $credDir = "$dataDir/credentials.d";
		mkdir $credDir;
		$zconfig->newval('main', 'credentials.global.dir', $credDir);
		$zconfig->RewriteConfig();
		my $CREDFILE = FileHandle -> new();
		if (! $CREDFILE -> open (">$credDir/kiwiRepoCredentials")) {
			my $msg = 'Unable to open credetials file for write '
			. "in $credDir";
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
		print $CREDFILE "username=$uname\n";
		print $CREDFILE "password=$pass\n";
		$CREDFILE -> close();
		$kiwi -> done();
	}
	if (defined $targetArch) {
		$kiwi -> info ("Setting target architecture to: $targetArch");
		$zconfig->newval('main', 'arch', $targetArch);
		$zconfig->RewriteConfig();
		$kiwi -> done ();
	}
	#==========================================
	# Store zypper command parameters
	#------------------------------------------
	$this->{zypper} = [
		$locator -> getExecPath('zypper'),
		'--non-interactive',
		'--no-gpg-checks',
		'--pkg-cache-dir /var/cache/kiwi/packages',
		"--reposd-dir $root/$dataDir/repos",
		"--cache-dir $root/$dataDir",
		"--config $zypperConf"
	];
	$this->{zypper_chroot} = [
		"zypper",
		'--non-interactive',
		'--no-gpg-checks',
		'--pkg-cache-dir /var/cache/kiwi/packages',
		"--reposd-dir $dataDir/repos",
		"--cache-dir $dataDir",
		"--config $zypperConf"
	];
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{zyppconf} = $zyppConf;
	$this->{zconfig}  = $zconfig;
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
	my $this = shift;
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
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $xml     = $this->{xml};
	my $chroot  = $this->{chroot};
	my @kchroot = @{$this->{kchroot}};
	my $root    = $this->{root};
	my $data;
	my $code;
	#==========================================
	# Get and store docs information
	#------------------------------------------
	my $imgExclDocs = $xml -> getPreferences() -> getRPMExcludeDoc();
	$this->{imgExclDocs} = $imgExclDocs;
	#==========================================
	# Update zypper configuration
	#------------------------------------------
	my $zconfig = $this->{zconfig};
	my $optionParam = 'rpm.install.excludedocs';
	my $curExclDocs = $zconfig->val('main', $optionParam);
	$this->{curExclDocs} = $curExclDocs;
	if (defined $imgExclDocs) {
		$kiwi -> info ("Setting RPM doc exclusion to: $imgExclDocs");
		$zconfig->newval('main', $optionParam, $imgExclDocs);
		$zconfig->RewriteConfig;
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
	my $this        = shift;
	my $kiwi        = $this->{kiwi};
	my $chroot      = $this->{chroot};
	my @kchroot     = @{$this->{kchroot}};
	my $root        = $this->{root};
	my $curExclDocs = $this->{curExclDocs};
	my $data;
	my $code;
	if (defined $this->{imgExclDocs}) {
		my $zconfig = $this->{zconfig};
		my $optionParam = 'rpm.install.excludedocs';
		if (defined $curExclDocs) {
			$kiwi -> info ("Resetting RPM doc exclusion to: $curExclDocs");
			$zconfig->newval('main', $optionParam, $curExclDocs);
		} else {
			$kiwi -> info ("Unsetting RPM doc exclusion");
			$zconfig->delval('main', $optionParam);
		}
		$zconfig->RewriteConfig;
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
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $chroot  = $this->{chroot};
	my @kchroot = @{$this->{kchroot}};
	my %source  = %{$this->{source}};
	my $root    = $this->{root};
	my $dataDir = $this->{dataDir};
	my $data;
	my $code;
	my @channelList = ();
	my @zypper = @{$this->{zypper}};
	my $stype = "private";
	undef $ENV{ZYPP_LOCKFILE_ROOT};
	if (! $chroot) {
		local $ENV{ZYPP_LOCKFILE_ROOT} = $root;
		$stype = "public";
	}
	if ($chroot) {
		$data = qxx ("@kchroot zypper --version 2>&1 | cut -c 8");
		if ($data < 1) {
			$kiwi -> info ("image zypper version is too old");
			$kiwi -> skipped ();
			return $this;
		}
	}
	foreach my $alias (keys %{$source{$stype}}) {
		my @sopts = @{$source{$stype}{$alias}};
		my @zopts = ();
		my $prio;
		foreach my $opt (@sopts) {
			next if ! defined $opt;
			$opt =~ /(.*?)=(.*)/;
			my $key = $1;
			my $val = $2;
			#==========================================
			# keep packages on remote repos
			#------------------------------------------
			if (($val) &&
				($val =~ /^'ftp:\/\/|http:\/\/|https:\/\/|opensuse:\/\//)
			) {
				push (@zopts,"--keep-packages");
			}
			#==========================================
			# Adapt URI parameter
			#------------------------------------------
			if (($key) && (($key eq "baseurl") || ($key eq "path"))) {
				if ($val =~ /^'\//) {
					$val =~ s/^'(.*)'$/"file:\/\/$1"/
				}
				if ($val =~ /^'https:/) {
					my ($uname, $pass) = $this->{xml}
								->getHttpsRepositoryCredentials_legacy();
					if ($uname) {
						chop $val;
						$val .= "?credentials=kiwiRepoCredentials'";
					}
				}
				push (@zopts,$val);
			}
			#==========================================
			# Adapt type parameter
			#------------------------------------------
			if (($key) && ($key eq "type")) {
				if ($val eq "yast2") {
					$val = "YaST";
				}
				if ($val eq "rpm-dir") {
					$val = "Plaindir";
				}
				if ($val eq "rpm-md") {
					$val = "YUM";
				}
				push (@zopts,"--type $val");
			}
			#==========================================
			# Adapt priority parameter
			#------------------------------------------
			if (($key) && ($key eq "priority")) {
				$prio = $val;
			}
		}
		my $sadd = "addrepo -f @zopts $alias";
		my $alias_filename = $alias;
		$alias_filename =~ s/\//_/g;
		my $repo = "$root/$dataDir/repos/$alias_filename.repo";
		my $sed;
		if (! $chroot) {
			if (! -f $repo) {
				$kiwi -> info ("Adding bootstrap zypper service: $alias");
				$data = qxx ("@zypper --root \"$root\" $sadd 2>&1");
				$code = $? >> 8;
			} else {
				$kiwi -> info ("Updating bootstrap zypper service: $alias");
				$data = qxx ("grep -q '^baseurl=file:/base-system' $repo");
				$code = $? >> 8;
				if ($code == 0) {
					$sed = '@\(baseurl=file:/base-system\)@baseurl=file:@';
					$data = qxx ('sed -i -e s"'.$sed.'" '.$repo);
					$code = $? >> 8;
				} else {
					$code = 0;
				}
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("zypper: $data");
				return;
			}
			$kiwi -> done ();
		} else {
			my @zypper= @{$this->{zypper_chroot}};
			if (! -f $repo) {
				$kiwi -> info ("Adding chroot zypper service: $alias");
				$data = qxx ("@kchroot @zypper $sadd 2>&1");
				$code = $? >> 8;
			} else {
				$kiwi -> info ("Updating chroot zypper service: $alias");
				$data = qxx ("grep -q '^baseurl=file:/base-system' $repo");
				$code = $? >> 8;
				if ($code != 0) {
					$sed = '@\(baseurl=file:/\)@\1base-system/@';
					$data = qxx ('sed -i -e s"'.$sed.'" '.$repo);
					$code = $? >> 8;
				}
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("zypper: $data");
				return;
			}
			$kiwi -> done ();
			if ($source{$alias}{imgincl}) {
				$kiwi -> info ("Adding $alias repo to image");
				$sadd =~ s/--keep-packages//;
				$data = qxx ("@kchroot zypper $sadd 2>&1");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> error  ("zypper: $data");
					return;
				}
				if ( $prio ) {
					$data = qxx (
						"@kchroot zypper modifyrepo -p $prio $alias 2>&1"
					);
					$code = $? >> 8;
					if ($code != 0) {
						$kiwi -> failed ();
						$kiwi -> error  ("zypper: $data");
						return;
					}
				}
				$kiwi -> done ();
			}
		}
		if ( $prio ) {
			$kiwi -> info ("--> Set priority to: $prio");
			my $modrepo = "modifyrepo -p $prio $alias";
			if (! $chroot) {
				$data = qxx ("@zypper --root \"$root\" $modrepo 2>&1");
				$code = $? >> 8;
			} else {
				my @zypper= @{$this->{zypper_chroot}};
				$data = qxx ("@kchroot @zypper $modrepo 2>&1");
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("zypper: $data");
				return;
			}
			$kiwi -> done ();
		}
		push (@channelList,$alias);
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
	my $this = shift;
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
	my @pacs   = @_;
	my $this   = shift @pacs;
	my $kiwi   = $this->{kiwi};
	# FIXME
	$kiwi -> failed ();
	$kiwi -> error  ("*** not implemeted for zypper ***");
	$kiwi -> failed ();
	return;
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
	my @zypper = @{$this->{zypper_chroot}};
	#==========================================
	# Create screen call file
	#------------------------------------------
	$kiwi -> info ("Installing addon packages...");
	my @installOpts = (
		"--auto-agree-with-licenses"
	);
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "export ZYPP_MODALIAS_SYSFS=/tmp\n";
	print $fd "export YAST_IS_RUNNING=true\n";
	print $fd "export ZYPP_CONF=".$this->{zyppconf}."\n";
	print $fd "@kchroot @zypper install ";
	print $fd "@installOpts @addonPackages &\n";
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
	#==========================================
	# Create screen call file
	#------------------------------------------
	$kiwi -> info ("Removing packages...");
	if (! $this -> rpmLibs()) {
		return;
	}
	my @removeOpts = (
		"--nodeps --allmatches --noscripts"
	);
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "@kchroot mount -t proc proc /proc"."\n";
	print $fd "final=\$(@kchroot rpm -q @removePackages ";
	print $fd " | grep -v 'is not installed')"."\n";
	print $fd "if [ ! -z \"\$final\" ];then"."\n";
	print $fd "@kchroot rpm -e @removeOpts \$final &\n";
	print $fd "SPID=\$!;wait \$SPID\n";
	print $fd "ECODE=\$?\n";
	print $fd "else"."\n";
	print $fd "ECODE=0"."\n";
	print $fd "fi"."\n";
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
	# ---
	my $this       = shift;
	my $addPacks   = shift;
	my $delPacks   = shift;
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
	my @zypper = @{$this->{zypper_chroot}};
	#==========================================
	# Create screen call file
	#------------------------------------------
	$kiwi -> info ("Upgrading image...");
	my @installOpts = (
		"--auto-agree-with-licenses"
	);
	my %pattr = $xml -> getPackageAttributes_legacy("image");
	if ($pattr{patternType} ne "plusRecommended") {
		push (@installOpts,"--no-recommends");
	}
	print $fd "ZV=\$(@kchroot zypper --version 2>&1 | cut -c 8)"."\n";
	print $fd 'if [ $ZV = 0 ];then'."\n";
	print $fd "\t".'echo "image zypper version is too old, skipped"'."\n";
	print $fd "\t"."ECODE=0\n";
	print $fd "\t"."echo \$ECODE > $screenCall.exit\n";
	print $fd "\t"."exit \$ECODE\n";
	print $fd "fi"."\n";
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	print $fd "export ZYPP_MODALIAS_SYSFS=/tmp\n";
	print $fd "export YAST_IS_RUNNING=true\n";
	print $fd "export ZYPP_CONF=".$this->{zyppconf}."\n";
	if (defined $delPacks) {
		my @removePackages = @{$delPacks};
		if (@removePackages) {
			print $fd "@kchroot @zypper remove ";
			print $fd "--force-resolution @removePackages || true &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
			print $fd "test \$? = 0 && ";
		}
	}
	if (defined $addPacks) {
		my @addonPackages = @{$addPacks};
		my @newpatts = ();
		my @newprods = ();
		my @newpacks = ();
		my @institems= ();
		foreach my $pac (@addonPackages) {
			if ($pac =~ /^pattern:(.*)/) {
				push @newpatts,"\"$1\"";
			} elsif ($pac =~ /^product:(.*)/) {
				push @newprods,$1;
			} else {
				push @newpacks,$pac;
			}
		}
		@addonPackages = @newpacks;
		print $fd "@kchroot @zypper dist-upgrade @installOpts &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		if (@newprods) {
			foreach my $p (@newprods) {
				push @institems,"product:$p";
			}
		}
		if (@newpatts) {
			foreach my $p (@newpatts) {
				push @institems,"pattern:$p";
			}
		}
		if (@addonPackages) {
			push @institems,@addonPackages
		}
		print $fd "test \$? = 0 && @kchroot @zypper install ";
		print $fd "@installOpts @institems &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
	} else {
		print $fd "@kchroot @zypper dist-upgrade @installOpts &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
	}
	print $fd "ECODE=\$?\n";
	print $fd "echo \$ECODE > $screenCall.exit\n";
	print $fd "exit \$ECODE\n";
	$fd -> close();
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
	if (! $chroot) {
		#==========================================
		# setup install options outside of chroot
		#------------------------------------------
		my @zypper = @{$this->{zypper}};
		my @installOpts = (
			"--auto-agree-with-licenses"
		);
		my %pattr = $xml -> getPackageAttributes_legacy("bootstrap");
		if ($pattr{patternType} ne "plusRecommended") {
			push (@installOpts,"--no-recommends");
		}
		#==========================================
		# Add package manager to package list
		#------------------------------------------
		if ($this -> setupInstallPackages()) {
			push (@packs,$manager);
		}
		$kiwi -> info ("Initializing image system on: $root");
		#==========================================
		# check input list for pattern names
		#------------------------------------------
		my @newpacks = ();
		my @newpatts = ();
		my @newprods = ();
		my @institems= ();
		foreach my $pac (@packs) {
			if ($pac =~ /^pattern:(.*)/) {
				push @newpatts,"\"$1\"";
			} elsif ($pac =~ /^product:(.*)/) {
				push @newprods,$1;
			} else {
				push @newpacks,$pac;
			}
		}
		@packs = @newpacks;
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
		print $fd "export ZYPP_MODALIAS_SYSFS=/tmp\n";
		print $fd "export YAST_IS_RUNNING=true\n";
		print $fd "export ZYPP_CONF=".$root."/".$this->{zyppconf}."\n";
		print $fd "export ZYPP_LOCKFILE_ROOT=$root\n";
		if (@newprods) {
			foreach my $p (@newprods) {
				push @institems,"product:$p";
			}
		}
		if (@newpatts) {
			foreach my $p (@newpatts) {
				push @institems,"pattern:$p";
			}
		}
		if (@packs) {
			push @institems,@packs;
		}
		print $fd "@zypper --root $root install ";
		print $fd "@installOpts @institems &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		print $fd "ECODE=\$?\n";
		print $fd "echo \$ECODE > $screenCall.exit\n";
		print $fd "exit \$ECODE\n";
	} else {
		#==========================================
		# select patterns and packages
		#------------------------------------------
		my @zypper    = @{$this->{zypper_chroot}};
		my @install   = ();
		my @newpatts  = ();
		my @newprods  = ();
		my @institems = ();
		foreach my $need (@packs) {
			if ($need =~ /^pattern:(.*)/) {
				push @newpatts,"\"$1\"";
				next;
			} elsif ($need =~ /^product:(.*)/) {
				push @newprods,$1;
				next;
			}
			push @install,$need;
		}
		#==========================================
		# setup install options inside of chroot
		#------------------------------------------
		my @installOpts = (
			"--auto-agree-with-licenses"
		);
		my %pattr = $xml -> getPackageAttributes_legacy("image");
		if ($pattr{patternType} ne "plusRecommended") {
			push (@installOpts,"--no-recommends");
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
		print $fd "export ZYPP_MODALIAS_SYSFS=/tmp\n";
		print $fd "export YAST_IS_RUNNING=true\n";
		print $fd "export ZYPP_CONF=".$this->{zyppconf}."\n";
		if (@newprods) {
			foreach my $p (@newprods) {
				push @institems,"product:$p";
			}
		}
		if (@newpatts) {
			foreach my $p (@newpatts) {
				push @institems,"pattern:$p";
			}
		}
		if (@install) {
			push @institems,@install;
		}
		print $fd "@kchroot @zypper install ";
		print $fd "@installOpts @institems &\n";
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
	my $this    = shift;
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
	my $this    = shift;
	my $pack    = shift;
	my $kiwi    = $this->{kiwi};
	my $chroot  = $this->{chroot};
	my @kchroot = @{$this->{kchroot}};
	my $root    = $this->{root};
	my $data;
	my $code;
	my $str = "not installed";
	if (! $chroot) {
		$kiwi -> info ("Checking for package: $pack");
		$data = qxx ("rpm --root $root -q \"$pack\" 2>&1");
		$code = $? >> 8;
	} else {
		$kiwi -> info ("Checking for package: $pack");
		$data= qxx ("@kchroot rpm -q \"$pack\" 2>&1 ");
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

1;
