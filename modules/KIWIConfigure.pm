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
use KIWILog;

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
		foreach my $user (keys %users) {
			my $group = $users{$user}{group};
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
				$adduser .= " -m -d $home";
			}
			if (defined $group) {
				my $data = qx ( chroot $root grep -q $group /etc/group 2>&1 );
				my $code = $? >> 8;
				if ($code != 0) {
					$kiwi -> info ("Adding group: $group");
					my $data = qx ( chroot $root $addgroup $group );
					my $code = $? >> 8;
					if ($code != 0) {
						$kiwi -> failed ();
						$kiwi -> info   ($data);
						$kiwi -> failed ();
						return undef;
					}
					$kiwi -> done();
				}
				$adduser .= " -G $group";
			}
			if (defined $realname) {
				$adduser .= " -c '$realname'";
				$moduser .= " -c '$realname'";
			}
			my $data = qx ( chroot $root grep -q $user /etc/passwd 2>&1 );
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> info ("Adding user: $user [$group]");
				$data = qx ( chroot $root $adduser $user 2>&1 );
				$code = $? >> 8;
			} else {
				$kiwi -> info ("Modifying user: $user [$group]");
				$data = qx ( chroot $root $moduser $user 2>&1 );
				$code = $? >> 8;
			}
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> info   ($data);
				$kiwi -> failed ();
				return undef;
			}
			$kiwi -> done ();
		}
	}
	return $this;
}

#==========================================
# setupAutoYaST
#------------------------------------------
sub setupAutoYaST {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $root = $this->{root};
	my $imageDesc = $this->{imageDesc};
	if (-f "$imageDesc/config-yast.xml") {
		$kiwi -> info ("Setting up AutoYaST...");
		my $autodir = "var/lib/autoinstall/autoconf";
		my $autocnf = "autoconf.xml";
		if (! -d "$root/$autodir") {
			$kiwi -> failed ();
			$kiwi -> error  ("AutoYaST seems not be installed");
			$kiwi -> failed ();
			return undef;
		}
		qx ( cp $imageDesc/config-yast.xml $root/$autodir/$autocnf 2>&1 );
		if ( ! open (FD,">$root/etc/install.inf")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create install.inf: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "AutoYaST: http://192.168.100.99/part2.xml\n";
		close FD;
		if ( ! open (FD,">$root/var/lib/YaST2/runme_at_boot")) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to create runme_at_boot: $!");
			$kiwi -> failed ();
			return undef;
		}
		close FD;
		$kiwi -> done ();
	}
	return $this;
}

1;
