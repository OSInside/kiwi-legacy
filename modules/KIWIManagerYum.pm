#================
# FILE          : KIWIManagerYum.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module adds support for the yum
#               : package manager
#               :
# STATUS        : Development
#----------------
package KIWIManagerYum;
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
use KIWILog;
use KIWILocator;
use KIWIQX qw (qxx);

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
	my $dataDir = $this->{dataDir};
	my $locator = $this->{locator};
	#==========================================
	# Create config files/dirs
	#------------------------------------------
	if (! -d $dataDir) {
		qxx ("mkdir -p $dataDir");
	}
	#==========================================
	# Store yum command parameters
	#------------------------------------------
	$this->{yum} = [
		$locator -> getExecPath('yum'),
		"-c $dataDir/yum.conf",
		"-y"
	];
	$this->{yum_chroot} = [
		"yum",
		"-c $dataDir/yum.conf",
		"-y"
	];
	$this->{yumconfig} = $this -> createYumConfig();
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
	my $imgCheckSig = $xml -> getRPMCheckSignatures_legacy();
	$this->{imgCheckSig} = $imgCheckSig;
	my $yumc = $this->{yumconfig};
	$data = Config::IniFiles -> new (
		-file => $yumc, -allowedcommentchars => '#'
	);
	my $optval = 0;
	if ($imgCheckSig eq "true") {
		$optval = 1;
	}
	$data -> newval ("main", "gpgcheck", $optval);
	$data -> RewriteConfig();
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
	my $yumc = $this->{yumconfig};
	$data = Config::IniFiles -> new (
		-file => $yumc, -allowedcommentchars => '#'
	);
	$data -> newval ("main", "gpgcheck", "0");
	$data -> RewriteConfig();
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
	my @kchroot = @{$this->{kchroot}};
	my %source  = %{$this->{source}};
	my $root    = $this->{root};
	my $dataDir = $this->{dataDir};
	my $data;
	my $code;
	my @channelList = ();
	my @yum = @{$this->{yum}};
	my $stype  = "private";
	if (! $chroot) {
		$stype = "public";
	}
	foreach my $alias (keys %{$source{$stype}}) {
		my @sopts = @{$source{$stype}{$alias}};
		my $repo  = "$dataDir/$alias.repo";
		#==========================================
		# create new repo file and open it
		#------------------------------------------
		qxx ("echo '[$alias]' > $repo");
		$data = Config::IniFiles -> new (
			-file => $repo, -allowedcommentchars => '#'
		);
		#==========================================
		# walk through the repo options
		#------------------------------------------
		foreach my $opt (@sopts) {
			next if ! defined $opt;
			$opt =~ /(.*?)=(.*)/;
			my $key = $1;
			my $val = $2;
			#==========================================
			# Set baseurl and name parameter
			#------------------------------------------
			if (($key eq "baseurl") || ($key eq "path")) {
				if ($val =~ /^'\//) {
					$val =~ s/^'(.*)'$/"file:\/\/$1"/
				}
				$val =~ s/^\"//;
				$val =~ s/\"$//;
				$val =~ s/^\'//;
				$val =~ s/\'$//;
				$data -> newval ($alias, "name"   , $alias);
				$data -> newval ($alias, "baseurl", $val);
			}
			if($key eq "priority"){
				$data -> newval ($alias, "priority", $val);
			}
		}
		if (! $chroot) {
			$kiwi -> info ("Adding bootstrap yum repo: $alias");
		} else {
			$kiwi -> info ("Adding chroot yum repo: $alias");
		}
		push (@channelList,$alias);
		$data -> RewriteConfig();
		$kiwi -> done();
	}
	#==========================================
	# create cache file
	#------------------------------------------
	if (! $chroot) {
		$kiwi -> info ("Creating yum metadata cache...");
		$data = qxx ("@yum makecache 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("yum: $data");
			return;
		}
		$kiwi -> done();
	} else {
		$kiwi -> info ('Rebuild RPM package db...');
		$data = qxx ("@kchroot /bin/rpm --rebuilddb 2>&1");
		$kiwi -> done();
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
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $dataDir = $this->{dataDir};
	$kiwi -> info ("Removing yum repo(s) in: $dataDir");
	qxx ("rm -f $dataDir/*.repo 2>&1");
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
	my @pacs   = @_;
	my $this   = shift @pacs;
	my $kiwi   = $this->{kiwi};
	# FIXME
	$kiwi -> failed ();
	$kiwi -> error  ("*** not implemeted ***");
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
	my @yum = @{$this->{yum_chroot}};
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
	print $fd "for i in @addonPackages;do\n";
	print $fd "\tif ! @kchroot @yum list all \$i;then\n";
	print $fd "\t\tECODE=1\n";
	print $fd "\t\techo \$ECODE > $screenCall.exit\n";
	print $fd "\t\texit \$ECODE\n";
	print $fd "\tfi\n";
	print $fd "done\n";
	print $fd "@kchroot @yum install @addonPackages &\n";
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
	my @yum  = @{$this->{yum_chroot}};
	#==========================================
	# Create screen call file
	#------------------------------------------
	$kiwi -> info ("Upgrading image...");
	print $fd "function clean { kill \$SPID;";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;";
	print $fd "if [ \"\$c\" = 5 ];then kill \$SPID;break;fi;"; 
	print $fd "c=\$((\$c+1));done;\n";
	print $fd "while kill -0 \$SPID &>/dev/null; do sleep 1;done\n";
	print $fd "echo 1 > $screenCall.exit; exit 1; }\n";
	print $fd "trap clean INT TERM\n";
	if (defined $delPacks) {
		my @removePackages = @{$delPacks};
		if (@removePackages) {
			print $fd "@kchroot @yum remove @removePackages &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
			print $fd "test \$? = 0 && ";
		}
	}
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
		print $fd "@kchroot @yum upgrade &\n";
		print $fd "SPID=\$!;wait \$SPID\n";
		if (@newpatts) {
			print $fd "for i in @newpatts;do\n";
			print $fd "\tif ! @kchroot @yum grouplist | grep -q \"\$i\";then\n";
			print $fd "\t\tECODE=1\n";
			print $fd "\t\techo \$ECODE > $screenCall.exit\n";
			print $fd "\t\texit \$ECODE\n";
			print $fd "\tfi\n";
			print $fd "done\n";
			print $fd "test \$? = 0 && ";
			print $fd "@kchroot @yum groupinstall @newpatts &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
		if (@addonPackages) {
			print $fd "for i in @addonPackages;do\n";
			print $fd "\tif ! @kchroot @yum list all \$i;then\n";
			print $fd "\t\tECODE=1\n";
			print $fd "\t\techo \$ECODE > $screenCall.exit\n";
			print $fd "\t\texit \$ECODE\n";
			print $fd "\tfi\n";
			print $fd "done\n";
			print $fd "test \$? = 0 && ";
			print $fd "@kchroot @yum install @addonPackages &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
	} else {
		print $fd "@kchroot @yum upgrade &\n";
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
		# Add package manager to package list
		#------------------------------------------
		my @yum = @{$this->{yum}};
		if ($this -> setupInstallPackages()) {
			push (@packs,$manager);
		}
		$kiwi -> info ("Initializing image system on: $root");
		#==========================================
		# check input list for group names
		#------------------------------------------
		my @newpacks = ();
		my @newpatts = ();
		foreach my $pac (@packs) {
			if ($pac =~ /^pattern:(.*)/) {
				push @newpatts,"\"$1\"";
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
		if (@newpatts) {
			print $fd "for i in @newpatts;do\n";
			print $fd "\tif ! @yum grouplist | grep -q \"\$i\";then\n";
			print $fd "\t\tECODE=1\n";
			print $fd "\t\techo \$ECODE > $screenCall.exit\n";
			print $fd "\t\texit \$ECODE\n";
			print $fd "\tfi\n";
			print $fd "done\n";
			print $fd "@yum --installroot=$root groupinstall @newpatts &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
		if (@packs) {
			if (@newpatts) {
				print $fd "test \$? = 0 && ";
			}
			print $fd "for i in @newpacks;do\n";
			print $fd "\tif ! @yum list all \$i;then\n";
			print $fd "\t\tECODE=1\n";
			print $fd "\t\techo \$ECODE > $screenCall.exit\n";
			print $fd "\t\texit \$ECODE\n";
			print $fd "\tfi\n";
			print $fd "done\n";
			print $fd "@yum --installroot=$root install @newpacks &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
		print $fd "ECODE=\$?\n";
		print $fd "echo \$ECODE > $screenCall.exit\n";
		print $fd "exit \$ECODE\n";
	} else {
		#==========================================
		# select groups and packages
		#------------------------------------------
		my @yum       = @{$this->{yum_chroot}};
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
			print $fd "for i in @newpatts;do\n";
			print $fd "\tif ! @kchroot @yum grouplist | grep -q \"\$i\";then\n";
			print $fd "\t\tECODE=1\n";
			print $fd "\t\techo \$ECODE > $screenCall.exit\n";
			print $fd "\t\texit \$ECODE\n";
			print $fd "\tfi\n";
			print $fd "done\n";
			print $fd "@kchroot @yum groupinstall @newpatts &\n";
			print $fd "SPID=\$!;wait \$SPID\n";
		}
		if (@install) {
			if (@newpatts) {
				print $fd "test \$? = 0 && ";
			}
			print $fd "for i in @install;do\n";
			print $fd "\tif ! @kchroot @yum list all \$i;then\n";
			print $fd "\t\tECODE=1\n";
			print $fd "\t\techo \$ECODE > $screenCall.exit\n";
			print $fd "\t\texit \$ECODE\n";
			print $fd "\tfi\n";
			print $fd "done\n";
			print $fd "@kchroot @yum install @install &\n";
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
	my $kiwi    = $this->{kiwi};
	my $dataDir = $this->{dataDir};
	$kiwi -> info ("Removing yum repo(s) in: $dataDir");
	qxx ("rm -f $dataDir/*.repo 2>&1");
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

#==========================================
# createYumConfig
#------------------------------------------
sub createYumConfig {
	my $this   = shift;
	my $root   = $this->{root};
	my $meta   = $this->{dataDir};
	my $config = $meta."/yum.conf";
	qxx ("echo '[main]' > $config");
	qxx ("echo 'cachedir=$meta' >> $config");
	qxx ("echo 'reposdir=$meta' >> $config");
	qxx ("echo 'keepcache=0' >> $config");
	qxx ("echo 'debuglevel=2' >> $config");
	qxx ("echo 'pkgpolicy=newest' >> $config");
	qxx ("echo 'tolerant=1' >> $config");
	qxx ("echo 'exactarch=1' >> $config");
	qxx ("echo 'obsoletes=1' >> $config");
	qxx ("echo 'plugins=1' >> $config");
	qxx ("echo 'metadata_expire=1800' >> $config");
	return $config;
}

1;
