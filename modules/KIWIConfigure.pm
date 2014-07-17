#================
# FILE          : KIWIConfigure.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to implement configuration
#               : methods for example adding users, groups, etc...
#               :
# STATUS        : Development
#----------------
package KIWIConfigure;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use FileHandle;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILocator;
use KIWILog;
use KIWIQX;

#==========================================
# Module Globals
#------------------------------------------
my @p_aug_path;    # store current augeas path
my $p_aug_id = 1;  # store current augeas comment ID
my $p_aug_val;     # store current augeas value
my @p_aug_result;  # result augeas call list

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIConfigure object which is used to provide
	# different image configuration functions. Configurations are
	# done within the pyhsical extend
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
	my $xml  = shift;
	my $root = shift;
	my $imageDesc = shift;
	my $imageDest = shift;
	#==========================================
	# Argument checking
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if (! defined $xml) {
		$kiwi -> error ("No XML reference specified");
		$kiwi -> failed ();
		return;
	}
	if (! defined $root) {
		$kiwi -> error  ("Missing chroot path");
		$kiwi -> failed ();
		return;
	}
	if (! defined $imageDesc) {
		$kiwi -> error  ("Missing image description path");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}      = $kiwi;
	$this->{locator}   = KIWILocator -> instance();
	$this->{imageDesc} = $imageDesc;
	$this->{imageDest} = $imageDest;
	$this->{xml}       = $xml;
	$this->{root}      = $root;
	$this->{gdata}     = KIWIGlobals -> instance() -> getKiwiConfig();
	return $this;
}

#==========================================
# setupAutoYaST
#------------------------------------------
sub setupAutoYaST {
	# ...
	# This function will make use of the autoyast system and setup
	# the image to call the autoyast automatically on first boot of
	# the system. To activate the call of yast on first boot the
	# file /var/lib/YaST2/runme_at_boot is created. Please note
	# according to the YaST people this is not the preferred method
	# of calling YaST to perform tasks on first boot. Use the function
	# setupFirstBootYaST below which uses yast2-firstboot to do the job
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $imageDesc = $this->{imageDesc};
	if (! -f "$imageDesc/config-yast-autoyast.xml") {
		return $this;;
	}
	$kiwi -> info ("Setting up AutoYaST...");
	my $autodir = "var/lib/autoinstall/autoconf";
	my $autocnf = "autoconf.xml";
	if (! -d "$root/$autodir") {
		$kiwi -> failed ();
		$kiwi -> error  ("AutoYaST seems not to be installed");
		$kiwi -> failed ();
		return;
	}
	KIWIQX::qxx (
		"cp $imageDesc/config-yast-autoyast.xml $root/$autodir/$autocnf 2>&1"
	);
	my $INFFD = FileHandle -> new();
	if ( ! $INFFD -> open (">$root/etc/install.inf")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create install.inf: $!");
		$kiwi -> failed ();
		return;
	}
	print $INFFD "AutoYaST: http://192.168.100.99/part2.xml\n";
	print $INFFD "Textmode: 0\n";
	$INFFD -> close();
	my $AUTOFD = FileHandle -> new();
	if ( ! $AUTOFD -> open (">$root/var/lib/YaST2/runme_at_boot")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create runme_at_boot: $!");
		$kiwi -> failed ();
		return;
	}
	$AUTOFD -> close();
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupFirstBootAnaconda
#------------------------------------------
sub setupFirstBootAnaconda {
	# ...
	# This function activates the RHEL firstboot mechanism.
	# So far I did not find a way to tell firstboot what
	# modules it should call. firstboot is activated if the
	# file config-anaconda-firstboot exists as part of your
	# image description
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $imageDesc = $this->{imageDesc};
	if (! -f "$imageDesc/config-anaconda-firstboot") {
		return $this;
	}
	$kiwi -> info ("Setting up Anaconda firstboot service...");
	#==========================================
	# touch/remove some files
	#------------------------------------------
	KIWIQX::qxx ("touch $root/etc/reconfigSys 2>&1");
	KIWIQX::qxx ("rm -f /etc/sysconfig/firstboot 2>&1");
	#==========================================
	# activate service
	#------------------------------------------
	my $data = KIWIQX::qxx ("chroot $root chkconfig --level 35 firstboot on 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to activate firstboot: $data");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# setupFirstBootYaST
#------------------------------------------
sub setupFirstBootYaST {
	# ...
	# This function is based on the yast2-firstboot functionality which
	# is a service which will be enabled by insserv. The firstboot service
	# uses a different xml format than the autoyast system. According to
	# this the input file has a different name. the firstboot input file
	# is preferred over the config-yast-autoyast.xml file
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $imageDesc = $this->{imageDesc};
	if (! -f "$imageDesc/config-yast-firstboot.xml") {
		return $this;
	}
	$kiwi -> info ("Setting up YaST firstboot service...");
	if (
		((! -f "$root/etc/init.d/firstboot") &&
		(! -f "$root/usr/share/YaST2/clients/firstboot.ycp"))
		&&
		((!-f "$root/usr/lib/systemd/system/YaST2-Firstboot.service") &&
		(! -f "$root/usr/share/YaST2/clients/firstboot.rb"))
	) {
		$kiwi -> failed ();
		$kiwi -> error  ('yast2-firstboot is not installed');
		$kiwi -> failed ();
		return;
	}
	my $firstboot = "$root/etc/YaST2/firstboot.xml";
	my $data = KIWIQX::qxx ("cp $imageDesc/config-yast-firstboot.xml $firstboot 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to copy config-yast-firstboot.xml: $data");
		$kiwi -> failed ();
		return;
	}
	# /.../
	# keep an existing /etc/sysconfig/firstboot or copy the template
	# from yast2-firstboot package if both don't exist, write a
	# generic one (bnc#604705)
	# ----
	if ( ! -e "$root/etc/sysconfig/firstboot" ) {
		my $FBFD = FileHandle -> new();
		if ( -e "$root/var/adm/fillup-templates/sysconfig.firstboot" ) {
			my $template = "$root/var/adm/fillup-templates/"
				. 'sysconfig.firstboot';
			$data = KIWIQX::qxx (
				"cp $template $root/etc/sysconfig/firstboot 2>&1"
			);
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  (
					"Failed to copy firstboot-sysconfig templage: $data"
				);
				$kiwi -> failed ();
				return;
			}
		} elsif ( ! $FBFD -> open (">$root/etc/sysconfig/firstboot")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create /etc/sysconfig/firstboot: $!");
			$kiwi -> failed ();
			return;
		} else {
			print $FBFD "## Description: Firstboot Configuration\n";
			print $FBFD "## Default: /usr/share/firstboot/scripts\n";
			print $FBFD "SCRIPT_DIR=\"/usr/share/firstboot/scripts\"\n";
			print $FBFD "FIRSTBOOT_WELCOME_DIR=\"/usr/share/firstboot\"\n";
			print $FBFD "FIRSTBOOT_WELCOME_PATTERNS=\"\"\n";
			print $FBFD "FIRSTBOOT_LICENSE_DIR=\"/usr/share/firstboot\"\n";
			print $FBFD "FIRSTBOOT_NOVELL_LICENSE_DIR=\"/etc/YaST2\"\n";
			print $FBFD "FIRSTBOOT_FINISH_FILE=";
			print $FBFD "\"/usr/share/firstboot/congrats.txt\"\n";
			print $FBFD "FIRSTBOOT_RELEASE_NOTES_PATH=\"\"\n";
			$FBFD -> close();
		}
	}
	if (-f "$root/etc/init.d/firstboot") {
		# /.../
		# old service script based firstboot service. requires some
		# default services to run
		# ----
		my @services = (
			"boot.rootfsck","boot.localfs",
			"boot.cleanup","boot.localfs","boot.localnet",
			"boot.clock","policykitd","dbus","consolekit",
			"haldaemon","network","atd","syslog","cron",
			"firstboot"
		);
		foreach my $service (@services) {
			if (! -e "$root/etc/init.d/$service") {
				next;
			}
			$data = KIWIQX::qxx (
				"chroot $root /sbin/insserv /etc/init.d/$service 2>&1"
			);
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error ("Failed to activate service(s): $data");
				$kiwi -> failed ();
				return;
			}
		}
		$data = KIWIQX::qxx ("touch $root/etc/reconfig_system 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to activate firstboot: $data");
			$kiwi -> failed ();
			return;
		}
	} else {
		# /.../
		# current firstboot service works like yast second stage and
		# is activated by touching /var/lib/YaST2/reconfig_system
		# ----
		$data = KIWIQX::qxx ("touch $root/var/lib/YaST2/reconfig_system 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to activate firstboot: $data");
			$kiwi -> failed ();
			return;
		}
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# setupAugeasImport
#------------------------------------------
sub setupAugeasImport {
	# ...
	# Apply configuration data from an augeas XML export
	# requires augeas and augeas-lenses to be installed as part
	# of the appliance. For the format of the augeas XML
	# schema please refer to the augeas documentation and/or
	# take a look at: 'augtool dump-xml /files/*'
	# ---
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $locator   = $this->{locator};
	my $root      = $this->{root};
	my $imageDesc = $this->{imageDesc};
	my $config    = $imageDesc.'/config-augeas.xml';
	#==========================================
	# check for augeas XML export file
	#------------------------------------------
	if (! -f $config) {
		return $this;
	}
	#==========================================
	# check for augtool in image root tree
	#------------------------------------------
	my $augtool = $locator -> getExecPath('augtool', $root);
	if (! $augtool) {
		$kiwi -> error ("Missing augtool command");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# open and read the augeas XML data
	#------------------------------------------
	$kiwi -> info ("Apply Augeas configuration...");
	my $AUG_XML = FileHandle -> new();
	if (! $AUG_XML -> open ("cat $config|")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to open $config: $!");
		$kiwi -> failed ();
		return;
	}
	binmode $AUG_XML;
	my $augxml  = XML::LibXML -> new();
	my $augtree = $augxml -> parse_fh ( $AUG_XML );
	my $augeas = $augtree
		-> getElementsByTagName ("augeas") -> get_node(1);
	$AUG_XML -> close();
	#==========================================
	# traverse tree / store command list
	#------------------------------------------
	$this -> setupAugeasTraverse ($augeas);
	if (! @p_aug_result) {
		$kiwi -> failed ();
		$kiwi -> error ("No action items for augeas found");
		$kiwi -> failed ();
		return;
	}
	my $AUG_AI = FileHandle -> new();
	if (! $AUG_AI -> open (">$root/augeas.tmp")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create $root/augeas.tmp: $!");
		return;
	}
	foreach my $set (@p_aug_result) {
		print $AUG_AI "set $set\n";
	}
	print $AUG_AI "save\n";
	$AUG_AI -> close();
	#==========================================
	# call augtool / apply configuration
	#------------------------------------------
	my $data = KIWIQX::qxx ("chroot $root $augtool -f augeas.tmp 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> info ($data);
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# setupAugeasTraverse
#------------------------------------------
sub setupAugeasTraverse {
	my $this = shift;
	my $node = shift;
	my @nodes = $node -> getChildrenByTagName ("node");
	if (! @nodes) {
		my $p = join ('/',@p_aug_path);
		if ($p_aug_val) {
			$p_aug_val =~ s/^"//x;
			$p_aug_val =~ s/"$//x;
			$p_aug_val =~ s/\\//xg;
			push @p_aug_result,"/files/$p \"$p_aug_val\"";
		}
		pop @p_aug_path;
		undef $p_aug_val;
		return;
	}
	$p_aug_id = 1;
	foreach my $node (@nodes) {
		my $label = $node -> getAttribute ("label");
		my $value = $node
			-> getChildrenByTagName ("value") -> get_node(1);
		if ($label eq '#comment') {
			$label = "#comment[$p_aug_id]";
			$p_aug_id++;
		}
		if ($value) {
			$p_aug_val = $value -> textContent();
		}
		push @p_aug_path,$label;
		$this -> setupAugeasTraverse ($node);
	}
	pop @p_aug_path;
	return;
}

#==========================================
# setupGroups
#------------------------------------------
sub setupGroups {
	my $this  = shift;
	my $kiwi    = $this->{kiwi};
	my $locator = $this->{locator};
	my $root    = $this->{root};
	my $xml     = $this->{xml};
	my $users    = $xml -> getUsers();
	my $addgroup = $locator -> getExecPath('groupadd', $root);
	my $numUsers = scalar @{$users};
	if ($numUsers) {
		if (! $addgroup) {
			$kiwi -> error ("Missing groupadd command");
			$kiwi -> failed ();
			return;
		}
	}
	for my $user (@{$users}) {
		my $group     = $user -> getGroupName();
		my $gid       = $user -> getGroupID();
		if (defined $group) {
			# create group if it does not exist
			my $data = KIWIQX::qxx (
				"chroot $root grep -q ^$group: /etc/group 2>&1"
			);
			my $code = $? >> 8;
			$group = quoteshell ($group);
			if ($code != 0) {
				$kiwi -> info ("Adding group: $group");
				if (defined $gid) {
					$addgroup .= " -g $gid";
				}
				$data = KIWIQX::qxx ("chroot $root $addgroup \"$group\"");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> info ($data);
					$kiwi -> failed ();
					return;
				}
				$kiwi -> done();
			}
		}
	}
	return $this;
}

#==========================================
# setupHWclock
#------------------------------------------
sub setupHWclock {
	# ...
	# Setup the configuration for the HW clock timezone
	# ---
	my $this = shift;
	my $kiwi    = $this->{kiwi};
	my $locator = $this->{locator};
	my $root    = $this->{root};
	my $xml     = $this->{xml};
	my $hwClock = $xml -> getPreferences() -> getHWClock();
	if (! $hwClock) {
		return $this;
	}
	my $timectl = $locator -> getExecPath('timedatectl', $root);
	if ($timectl) {
		if ($hwClock eq 'utc') {
			KIWIQX::qxx("chroot $root $timectl set-local-rtc false 2>&1");
		} else {
			KIWIQX::qxx("chroot $root $timectl set-local-rtc true 2>&1");
		}
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> loginfo ("warning: unable to set the system clock\n");
		}
	}
	return $this;
}

#==========================================
# setupKeyboardMap
#------------------------------------------
sub setupKeyboardMap {
	# ...
	# Setup the configuration for the keyboard
	# ---
	my $this = shift;
	my $kiwi    = $this->{kiwi};
	my $locator = $this->{locator};
	my $root    = $this->{root};
	my $xml     = $this->{xml};
	my $keymap = $xml -> getPreferences() -> getKeymap();
	if (! $keymap) {
		return $this;
	}
	my $localectl = $locator -> getExecPath('localectl', $root);
	if ($localectl) {
		KIWIQX::qxx("chroot $root $localectl set-keymap $keymap 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> loginfo ("warning: unable to set the keyboard map\n");
		}
	}
	return $this;
}

#==========================================
# setupLocale
#------------------------------------------
sub setupLocale {
	# ...
	# Setup the configuration for the locale
	# ---
	my $this = shift;
	my $kiwi    = $this->{kiwi};
	my $locator = $this->{locator};
	my $root    = $this->{root};
	my $xml     = $this->{xml};
	my $locale = $xml -> getPreferences() -> getLocale();
	if (! $locale) {
		return $this;
	}
	my @locales = split (/,/x,$locale);
	my $primary = $locales[0];
	my $localectl = $locator -> getExecPath('localectl', $root);
	if ($localectl) {
		KIWIQX::qxx("chroot $root $localectl set-locale $primary 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> loginfo ("warning: unable to set the locale\n");
		}
	}
	return $this;
}

#==========================================
# setupRecoveryArchive
#------------------------------------------
sub setupRecoveryArchive {
	my $this    = shift;
	my $fstype  = shift;
	my $kiwi    = $this->{kiwi};
	my $dest    = $this->{imageDest};
	my $xml     = $this->{xml};
	my $root    = $this->{root};
	my $oemconf = $xml -> getOEMConfig();
	my $start;
	my $inplace;
	if ($oemconf) {
		$start   = $oemconf -> getRecovery();
		$inplace = $oemconf -> getInplaceRecovery();
	}
	if ((! defined $start) || ("$start" eq "false")) {
		return $this;
	}
	if (! defined $dest) {
		$kiwi -> failed ();
		$kiwi -> error  ("Missing image destination path");
		return;
	}
	$kiwi -> info ("Creating recovery archive...");
	#==========================================
	# Create tar archive from root tree .tar
	#------------------------------------------
	my $topts  = "--numeric-owner --hard-dereference -cpf";
	my $excld  = "--exclude ./dev --exclude ./proc --exclude ./sys";
	my $cmd = "cd $root && tar $topts $dest/.recovery.tar . $excld 2>&1 && "
		. "mv $dest/.recovery.tar $root/recovery.tar";
	my $status = KIWIQX::qxx ($cmd);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery archive: $status");
		return;
	}
	#==========================================
	# Create file count information
	#------------------------------------------
	$status = KIWIQX::qxx (
		"tar -tf $root/recovery.tar | wc -l > $root/recovery.tar.files"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery file count: $status");
		return;
	}
	#==========================================
	# Create uncompressed byte size information
	#------------------------------------------
	my $TARFD = FileHandle -> new();
	if (! $TARFD -> open (">$root/recovery.tar.size")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery size info: $!");
		return;
	}
	my $size = -s "$root/recovery.tar";
	print $TARFD $size;
	$TARFD -> close();
	#==========================================
	# Compress archive into .tar.gz
	#------------------------------------------
	$status = KIWIQX::qxx (
		"$this->{gdata}->{Gzip} $root/recovery.tar 2>&1"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to compress recovery archive: $status");
		return;
	}
	#==========================================
	# Create recovery partition size info
	#------------------------------------------
	my $SIZEFD = FileHandle -> new();
	if (! $SIZEFD -> open (">$root/recovery.partition.size")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery partition size info: $!");
		return;
	}
	my $psize = -s "$root/recovery.tar.gz";
	$psize /= 1048576;
	$psize += 300;
	$psize = sprintf ("%.0f", $psize);
	print $SIZEFD $psize;
	$SIZEFD -> close();
	$status = KIWIQX::qxx ("cp $root/recovery.partition.size $dest 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to copy partition size info file: $status");
		return;
	}
	#==========================================
	# Create destination filesystem information
	#------------------------------------------
	my $FSFD = FileHandle -> new();
	if (! $FSFD -> open (">$root/recovery.tar.filesystem")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery filesystem info: $!");
		return;
	}
	print $FSFD $fstype;
	$FSFD -> close();
	#==========================================
	# Remove tarball for later recreation
	#------------------------------------------
	if (($inplace) && ("$inplace" eq "true")) {
		KIWIQX::qxx ("rm -f $root/recovery.tar.gz 2>&1");
	}
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupTimezone
#------------------------------------------
sub setupTimezone {
	# ...
	# Setup the configuration for the timezone
	# ---
	my $this = shift;
	my $kiwi    = $this->{kiwi};
	my $locator = $this->{locator};
	my $root    = $this->{root};
	my $xml     = $this->{xml};
	my $tz = $xml -> getPreferences() -> getTimezone();
	if (! $tz) {
		return $this;
	}
	my $timectl = $locator -> getExecPath('timedatectl', $root);
	if ($timectl) {
		KIWIQX::qxx("chroot $root $timectl set-timezone $tz 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> loginfo ("warning: unable to set the timezone\n");
		}
	}
	return $this;
}


#==========================================
# setupUsers
#------------------------------------------
sub setupUsers {
	my $this  = shift;
	my $kiwi    = $this->{kiwi};
	my $locator = $this->{locator};
	my $root    = $this->{root};
	my $xml     = $this->{xml};
	my $users    = $xml -> getUsers();
	my $adduser  = $locator -> getExecPath('useradd', $root);
	my $chown    = $locator -> getExecPath('chown', $root);
	my $grep     = $locator -> getExecPath('grep', $root);
	my $moduser  = $locator -> getExecPath('usermod', $root);
	my $numUsers = scalar @{$users};
	if ($numUsers) {
		if (! $adduser) {
			$kiwi -> error ("Missing useradd command");
			$kiwi -> failed ();
			return;
		}
		if (! $moduser) {
			$kiwi -> error ("Missing usermod command");
			$kiwi -> failed ();
			return;
		}
	}
	for my $user (@{$users}) {
		my $group     = $user -> getGroupName();
		my $gid       = $user -> getGroupID();
		my $logShell  = $user -> getLoginShell();
		my $pwd       = $user -> getPassword();
		my $pwdformat = $user -> getPasswordFormat();
		my $uHome     = $user -> getUserHomeDir();
		my $uID       = $user -> getUserID();
		my $uName     = $user -> getUserName();
		my $uRname    = $user -> getUserRealName();

		if ((defined $pwdformat) && ($pwdformat eq 'plain')) {
			$pwd = main::createPassword ($pwd);
		}
		if (defined $pwd) {
			$adduser .= " -p '$pwd'";
			$moduser .= " -p '$pwd'";
		}
		if (defined $logShell) {
			$adduser .= " -s '$logShell'";
			$moduser .= " -s '$logShell'";
		}
		if (defined $uHome) {
			$uHome = quoteshell ($uHome);
			$adduser .= " -m -d \"$uHome\"";
		}
		if (defined $gid) {
			# add user to primary group by group ID
			$adduser .= " -g $gid";
			$moduser .= " -g $gid";
		} elsif (defined $group) {
			# add user to primary group by group name
			$adduser .= " -g $group";
			$moduser .= " -g $group";
		}
		if (defined $uID) {
			$adduser .= " -u $uID";
		}
		if (defined $uRname) {
			$uRname = quoteshell ($uRname);
			$adduser .= " -c \"$uRname\"";
			$moduser .= " -c \"$uRname\"";
		}
		my $data = KIWIQX::qxx ("chroot $root $grep -q ^$uName: /etc/passwd 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> info ("Adding user: $uName [$group]");
			$data = KIWIQX::qxx ( "chroot $root $adduser $uName 2>&1" );
			$code = $? >> 8;
		} else {
			$kiwi -> info ("Modifying user: $uName [$group]");
			$data = KIWIQX::qxx ( "chroot $root $moduser $uName 2>&1" );
			$code = $? >> 8;
		}
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info ($data);
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done ();
		if ((defined $uHome) && (-d "$root/$uHome")) {
			my $iMsg = "Setting owner/group permissions $uName [$group]";
			$kiwi -> info($iMsg);
			$data = KIWIQX::qxx("chroot $root $chown -R $uName:$group $uHome 2>&1");
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> info ($data);
				$kiwi -> failed ();
				return;
			}
			$kiwi -> done();
		}
	}
	return $this;
}


#==========================================
# quoteshell
#------------------------------------------
sub quoteshell {
	# ...
	# Enclosing characters in double quotes preserves the
	# literal value of all characters within the quotes,
	# with the exception of $, `, \, and, when history
	# expansion is enabled, !.
	# ----
	my $name = shift;
	$name =~ s/([\"\$\!\`\\])/\\$1/gmsx;
	return $name;
}

#==========================================
# quoteFile
#------------------------------------------
sub quoteFile {
	# ...
	# ensure proper quoting of the given file
	# ---
	my $this = shift;
	my $file = shift;
	my $kiwi = $this->{kiwi};
	my $FD;
	my $data;
	my $tmpc = KIWIQX::qxx ("mktemp -q $file.XXXXXX"); chomp $tmpc;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to create tmp file");
		$kiwi -> failed ();
		return;
	}
	if (! open $FD, '>', "$tmpc") {
		$kiwi -> error  ("Failed to open tmp file");
		$kiwi -> failed ();
		return
	}
	print $FD "source $this->{gdata}->{BasePath}/modules/KIWIConfig.sh"."\n";
	print $FD "baseQuoteFile $file"."\n";
	close $FD;
	$data   = KIWIQX::qxx ("bash $tmpc");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to quote $file: $data");
		$kiwi -> failed ();
		return;
	}
	unlink $tmpc;
	return $this;
}

1;

# vim: set noexpandtab:
