#================
# FILE          : KIWIConfigure.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
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
use Carp qw (cluck);
use KIWILog;
use KIWIQX;

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
	my $kiwi = shift;
	my $xml  = shift; 
	my $root = shift;
	my $imageDesc = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (! defined $xml) {
		$kiwi -> error ("No XML reference specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $root) {
		$kiwi -> error  ("Missing chroot path");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $imageDesc) {
		$kiwi -> error  ("Missing image description path");
		$kiwi -> failed (); 
		return undef;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}      = $kiwi;
	$this->{imageDesc} = $imageDesc;
	$this->{xml}       = $xml;
	$this->{root}      = $root;
	return $this;
}

#==========================================
# setupRecoveryArchive
#------------------------------------------
sub setupRecoveryArchive {
	my $this  = shift;
	my $fstype= shift;
	my $kiwi  = $this->{kiwi};
	my $xml   = $this->{xml};
	my $root  = $this->{root};
	my $start = $xml -> getOEMRecovery();
	my $FD;
	if ((! defined $start) || ("$start" eq "false")) {
		return $this;
	}
	$kiwi -> info ("Creating recovery archive...");
	my $topts  = "--numeric-owner -czpf";
	my $excld  = "--exclude ./dev --exclude ./proc --exclude ./sys";
	my $status = qxx (
		"cd $root && tar $topts $root.recovery.tar.gz . $excld 2>&1 &&
		mv $root.recovery.tar.gz $root/recovery.tar.gz"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery archive: $status");
		return undef;
	}
	$status = qxx (
		"tar -tf $root/recovery.tar.gz | wc -l > $root/recovery.tar.files"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery file count: $status");
		return undef;
	}
	if (! open ($FD,">$root/recovery.tar.filesystem")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery filesystem info: $!");
		return undef;
	}
	print $FD $fstype;
	close $FD;
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupUsersGroups
#------------------------------------------
sub setupUsersGroups {
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $xml   = $this->{xml};
	my $root  = $this->{root};
	my %users = $xml -> getUsers();
	if (%users) {
		my $adduser  = "/usr/sbin/useradd";
		my $moduser  = "/usr/sbin/usermod";
		my $addgroup = "/usr/sbin/groupadd";
		if (! -x "$root/$adduser") {
			$kiwi -> error ("Missing useradd command");
			$kiwi -> failed ();
			return undef;
		}
		if (! -x "$root/$moduser") {
			$kiwi -> error ("Missing usermod command");
			$kiwi -> failed ();
			return undef;
		}
		if (! -x "$root/$addgroup") {
			$kiwi -> error ("Missing groupadd command");
			$kiwi -> failed ();
			return undef;
		}
		foreach my $user (keys %users) {
			my $group = $users{$user}{group};
			my $gid   = $users{$user}{gid};
			my $uid   = $users{$user}{uid};
			my $pwd   = $users{$user}{pwd};
			my $home  = $users{$user}{home};
			my $shell = $users{$user}{shell};
			my $realname = $users{$user}{realname};
			if (defined $pwd) {
				$adduser .= " -p '$pwd'";
				$moduser .= " -p '$pwd'";
			}
			if (defined $shell) {
				$adduser .= " -s '$shell'";
				$moduser .= " -s '$shell'";
			}
			if (defined $home) {
				$home = quoteshell ($home);
				$adduser .= " -m -d \"$home\"";
			}
			if (defined $gid) {
				$adduser .= " -g $gid";
				$moduser .= " -g $gid";
			}
			if (defined $uid) {
				$adduser .= " -u $uid";
			}
			if (defined $group) {
				my $data = qxx (
					"chroot $root grep -q ^$group: /etc/group 2>&1"
				);
				my $code = $? >> 8;
				$group = quoteshell ($group);
				if ($code != 0) {
					$kiwi -> info ("Adding group: $group");
					if (defined $gid) {
						$addgroup .= " -g $gid";
					}
					my $data = qxx ("chroot $root $addgroup \"$group\"");
					my $code = $? >> 8;
					if ($code != 0) {
						$kiwi -> failed ();
						$kiwi -> info   ($data);
						$kiwi -> failed ();
						return undef;
					}
					$kiwi -> done();
				}
				$adduser .= " -G \"$group\"";
			}
			if (defined $realname) {
				$realname = quoteshell ($realname);
				$adduser .= " -c \"$realname\"";
				$moduser .= " -c \"$realname\"";
			}
			my $data = qxx ( "chroot $root grep -q ^$user: /etc/passwd 2>&1" );
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> info ("Adding user: $user [$group]");
				$data = qxx ( "chroot $root $adduser $user 2>&1" );
				$code = $? >> 8;
			} else {
				$kiwi -> info ("Modifying user: $user [$group]");
				$data = qxx ( "chroot $root $moduser $user 2>&1" );
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> info   ($data);
				$kiwi -> failed ();
				return undef;
			}
			$kiwi -> done ();
			if (defined $home) {
				$kiwi -> info("Setting owner/group permissions $user [$group]");
				$data = qxx ( "chroot $root chown -R $user:$group $home 2>&1" );
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> info   ($data);
					$kiwi -> failed ();
					return undef;
				}
				$kiwi -> done();
			}
		}
	}
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
		return "skipped";
	}
	$kiwi -> info ("Setting up AutoYaST...");
	my $autodir = "var/lib/autoinstall/autoconf";
	my $autocnf = "autoconf.xml";
	if (! -d "$root/$autodir") {
		$kiwi -> failed ();
		$kiwi -> error  ("AutoYaST seems not to be installed");
		$kiwi -> failed ();
		return "failed";
	}
	qxx (
		"cp $imageDesc/config-yast-autoyast.xml $root/$autodir/$autocnf 2>&1"
	);
	if ( ! open (FD,">$root/etc/install.inf")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create install.inf: $!");
		$kiwi -> failed ();
		return "failed";
	}
	print FD "AutoYaST: http://192.168.100.99/part2.xml\n";
	close FD;
	if ( ! open (FD,">$root/var/lib/YaST2/runme_at_boot")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create runme_at_boot: $!");
		$kiwi -> failed ();
		return "failed";
	}
	close FD;
	$kiwi -> done ();
	return "success";
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
		return "skipped";
	}
	$kiwi -> info ("Setting up YaST firstboot service...");
	if (
		(! -f "$root/etc/init.d/firstboot") &&
		(! -f "$root/usr/share/YaST2/clients/firstboot.ycp")
	) {
		$kiwi -> failed ();
		$kiwi -> error  ("yast2-firstboot is not installed");
		$kiwi -> failed ();
		return "failed";
	}
	my $firstboot = "$root/etc/YaST2/firstboot.xml";
	my $data = qxx ("cp $imageDesc/config-yast-firstboot.xml $firstboot 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to copy config-yast-firstboot.xml: $data");
		$kiwi -> failed ();
		return "failed"; 
	}
	if ( ! open (FD,">$root/etc/reconfig_system")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create /etc/reconfig_system: $!");
		$kiwi -> failed ();
		return "failed";
	}
	close FD;
	if ( ! open (FD,">$root/etc/sysconfig/firstboot")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create /etc/sysconfig/firstboot: $!");
		$kiwi -> failed ();
		return "failed";
	}
	print FD "## Description: Firstboot Configuration\n";
	print FD "## Default: /usr/share/firstboot/scripts\n";
	print FD "SCRIPT_DIR=\"/usr/share/firstboot/scripts\"\n";
	print FD "FIRSTBOOT_WELCOME_DIR=\"/usr/share/firstboot\"\n";
	print FD "FIRSTBOOT_WELCOME_PATTERNS=\"\"\n";
	print FD "FIRSTBOOT_LICENSE_DIR=\"/usr/share/firstboot\"\n";
	print FD "FIRSTBOOT_NOVELL_LICENSE_DIR=\"/etc/YaST2\"\n";
	print FD "FIRSTBOOT_FINISH_FILE=\"/usr/share/firstboot/congrats.txt\"\n";
	print FD "FIRSTBOOT_RELEASE_NOTES_PATH=\"\"\n";
	close FD;
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
			$data = qxx (
				"chroot $root /sbin/insserv /etc/init.d/$service 2>&1"
			);
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error ("Failed to activate service(s): $data");
				$kiwi -> failed ();
				return "failed";
			}
		}
	} else {
		# /.../
		# current firstboot service works like yast second stage and
		# is activated by touching /var/lib/YaST2/reconfig_system
		# ----
		$data = qxx ("touch $root/var/lib/YaST2/reconfig_system 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to activate firstboot: $data");
			$kiwi -> failed ();
			return "failed";
		}
	}
	$kiwi -> done();
	return "success";
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
	$name =~ s/([\"\$\!\`\\])/\\$1/g;
	return $name;
}

1;
