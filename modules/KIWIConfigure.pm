#================
# FILE          : KIWIConfigure.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
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
use KIWILog;
use KIWIQX qw (qxx);

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
	my $imageDest = shift;
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
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}      = $kiwi;
	$this->{imageDesc} = $imageDesc;
	$this->{imageDest} = $imageDest;
	$this->{xml}       = $xml;
	$this->{root}      = $root;
	$this->{gdata}     = $main::global -> getGlobals();
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
	my $start   = $xml -> getOEMRecovery_legacy();
	my $inplace = $xml -> getOEMRecoveryInPlace_legacy();
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
	my $status = qxx (
		"cd $root && tar $topts $dest/.recovery.tar . $excld 2>&1 &&
		mv $dest/.recovery.tar $root/recovery.tar"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create recovery archive: $status");
		return;
	}
	#==========================================
	# Create file count information
	#------------------------------------------
	$status = qxx (
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
	$status = qxx (
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
	$psize += 200;
	$psize = sprintf ("%.0f", $psize);
	print $SIZEFD $psize;
	$SIZEFD -> close();
	$status = qxx ("cp $root/recovery.partition.size $dest 2>&1");
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
		qxx ("rm -f $root/recovery.tar.gz 2>&1");
	}
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
	my %users = $xml -> getUsers_legacy();
	if (%users) {
		if (! -x "$root/usr/sbin/useradd") {
			$kiwi -> error ("Missing useradd command");
			$kiwi -> failed ();
			return;
		}
		if (! -x "$root/usr/sbin/usermod") {
			$kiwi -> error ("Missing usermod command");
			$kiwi -> failed ();
			return;
		}
		if (! -x "$root/usr/sbin/groupadd") {
			$kiwi -> error ("Missing groupadd command");
			$kiwi -> failed ();
			return;
		}
		foreach my $user (keys %users) {
			my $adduser  = "/usr/sbin/useradd";
			my $moduser  = "/usr/sbin/usermod";
			my $addgroup = "/usr/sbin/groupadd";
			my $group = $users{$user}{group};
			my $gid   = $users{$user}{gid};
			my $uid   = $users{$user}{uid};
			my $pwd   = $users{$user}{pwd};
			my $home  = $users{$user}{home};
			my $shell = $users{$user}{shell};
			my $realname = $users{$user}{realname};
			my $pwdformat= $users{$user}{pwdformat};
			if ((defined $pwdformat) && ($pwdformat eq 'plain')) {
				$pwd = main::createPassword ($pwd);
			}
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
				# add user to primary group by group ID
				$adduser .= " -g $gid";
				$moduser .= " -g $gid";
			} elsif (defined $group) {
				# add user to primary group by group name
				$adduser .= " -g $group";
				$moduser .= " -g $group";
			}
			if (defined $uid) {
				$adduser .= " -u $uid";
			}
			if (defined $group) {
				# create group if it does not exist
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
						return;
					}
					$kiwi -> done();
				}
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
				return;
			}
			$kiwi -> done ();
			if ((defined $home) && (-d "$root/$home")) {
				$kiwi -> info("Setting owner/group permissions $user [$group]");
				$data = qxx ( "chroot $root chown -R $user:$group $home 2>&1" );
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> info   ($data);
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
	my $INFFD = FileHandle -> new();
	if ( ! $INFFD -> open (">$root/etc/install.inf")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create install.inf: $!");
		$kiwi -> failed ();
		return "failed";
	}
	print $INFFD "AutoYaST: http://192.168.100.99/part2.xml\n";
	$INFFD -> close();
	my $AUTOFD = FileHandle -> new();
	if ( ! $AUTOFD -> open (">$root/var/lib/YaST2/runme_at_boot")) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to create runme_at_boot: $!");
		$kiwi -> failed ();
		return "failed";
	}
	$AUTOFD -> close();
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
	# /.../
	# keep an existing /etc/sysconfig/firstboot or copy the template
	# from yast2-firstboot package if both don't exist, write a
	# generic one (bnc#604705)
	# ----
	if ( ! -e "$root/etc/sysconfig/firstboot" ) {
		my $FBFD = FileHandle -> new();
		if ( -e "$root/var/adm/fillup-templates/sysconfig.firstboot" ) {
			my $template = "$root/var/adm/fillup-templates/sysconfig.firstboot";
			my $data = qxx (
				"cp $template $root/etc/sysconfig/firstboot 2>&1"
			);
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  (
					"Failed to copy firstboot-sysconfig templage: $data"
				);
				$kiwi -> failed ();
				return "failed";
			}
		} elsif ( ! $FBFD -> open (">$root/etc/sysconfig/firstboot")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create /etc/sysconfig/firstboot: $!");
			$kiwi -> failed ();
			return "failed";
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
		$data = qxx ("touch $root/etc/reconfig_system 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to activate firstboot: $data");
			$kiwi -> failed ();
			return "failed";
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
		return "skipped";
	}
	$kiwi -> info ("Setting up Anaconda firstboot service...");
	#==========================================
	# touch/remove some files
	#------------------------------------------
	qxx ("touch $root/etc/reconfigSys 2>&1");
	qxx ("rm -f /etc/sysconfig/firstboot 2>&1");
	#==========================================
	# activate service
	#------------------------------------------
	my $data = qxx ("chroot $root chkconfig --level 35 firstboot on 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to activate firstboot: $data");
		$kiwi -> failed ();
		return "failed";
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
	my $tmpc = qxx ("mktemp -q $file.XXXXXX"); chomp $tmpc;
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
	$data   = qxx ("bash $tmpc");
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
