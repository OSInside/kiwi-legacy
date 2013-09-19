#================
# FILE          : KIWIAnalyse.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide methods for
#               : migrating a running system into an image
#               : description
#               :
#               :
#               :
# STATUS        : Development
#----------------
package KIWIAnalyse;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use XML::LibXML;
use Data::Dumper;
use FileHandle;
use File::Find;
use File::stat;
use File::Basename;
use File::Path;
use File::Copy;
use Storable;
use File::Spec;
use Fcntl ':mode';
use Cwd qw (abs_path cwd);
use JSON;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILog;
use KIWIQX qw (qxx);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIAnalyse object which is used to gather
	# information on the running system
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
	my $dest = shift;
	my $fnr  = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi   = KIWILog -> instance();
	my $global = KIWIGlobals -> instance();
	my $code;
	my $data;
	if (defined $fnr) {
		qxx ("rm -rf $dest");
	}
	if (! defined $dest) {
		$dest = qxx ("mktemp -qdt kiwi-analyse.XXXXXX");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create destination dir: $!");
			$kiwi -> failed ();
			return;
		}
		chomp $dest;
	} elsif (-d $dest) {
		$kiwi -> done ();
		$kiwi -> info ("Using already existing destination dir");
	} else {
		$data = qxx ("mkdir $dest 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create destination dir: $data");
			$kiwi -> failed ();
			return;
		}
		$data = qxx ("git init $dest 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("git init failed: $data");
			$kiwi -> failed ();
			return;
		}
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$dest/.gitignore")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create .gitignore: $!");
			$kiwi -> failed ();
			return;
		}
		print $FD 'custom'."\n";
		$FD -> close();
	}
	$dest =~ s/\/$//;
	$kiwi -> done ();
	$kiwi -> info ("Results will be written to: $dest");
	$kiwi -> done ();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{gdata} = $global -> getKiwiConfig();
	$this->{kiwi}  = $kiwi;
	$this->{dest}  = $dest;
	#==========================================
	# Clear the kiwi repo cache
	#------------------------------------------
	qxx ("rm -f /var/cache/kiwi/satsolver/*");
	#==========================================
	# Open the cache
	#------------------------------------------
	my %cdata;
	my $cdata = \%cdata;
	my $cache = $dest.".cache";
	if (-f $cache) {
		$kiwi -> info ("Open cache file: $cache\n");
		my $cdata_cur = retrieve($cache);
		if (! $cdata_cur) {
			$kiwi -> warning ("--> Failed to open cache file");
			$kiwi -> skipped ();
		} elsif (! $cdata_cur->{version}) {
			$kiwi -> warning ("--> Cache doesn't provide version");
			$kiwi -> skipped ();
		} elsif ($cdata_cur->{version} ne $this->{gdata}->{Version}) {
			$kiwi -> warning ("--> Cache version doesn't match");
			$kiwi -> skipped ();
		} elsif ($cdata_cur->{rpmdbsum}) {
			my $rpmdb = '/var/lib/rpm/Packages';
			if (-e $rpmdb) {
				my $dbsum = qxx ("cat $rpmdb | md5sum - | cut -f 1 -d-");
				chomp $dbsum;
				if ($dbsum ne $cdata_cur->{rpmdbsum}) {
					$kiwi -> warning ("--> RPM database has changed");
					$kiwi -> skipped ();
				} else {
					$kiwi -> info ("--> Using cache file\n");
					$cdata = $cdata_cur;
				}
			} else {
				$kiwi -> warning ("--> RPM database not found");
				$kiwi -> oops();
				$kiwi -> info ("--> Using possibly outdated cache file\n");
				$cdata = $cdata_cur;
			}
		} else {
			$kiwi -> info ("--> Using cache file\n");
			$cdata = $cdata_cur;
		}
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{cdata} = $cdata;
	return $this;
}

#==========================================
# commitTransaction
#------------------------------------------
sub commitTransaction {
	my $this = shift;
	my $dest = $this->{dest};
	my $kiwi = $this->{kiwi};
	my $text = '- automatic transaction commit';
	my $data = qxx ("cd $dest && git add . 2>&1");
	my $code = $? >> 8;
	if ($code == 0) {
		$data = qxx ("cd $dest && git commit -a -m \"$text\" 2>&1");
		$code = $? >> 8;
	}
	return $code;
}

#==========================================
# getDestination
#------------------------------------------
sub getDestination {
	my $this = shift;
	return $this->{dest};
}

#==========================================
# getCache
#------------------------------------------
sub getCache {
	my $this = shift;
	return $this->{cdata};
}

#==========================================
# writeCache
#------------------------------------------
sub writeCache {
	my $this  = shift;
	my $cdata = $this->{cdata};
	my $kiwi  = $this->{kiwi};
	my $dest  = $this->{dest};
	if (! $cdata) {
		return;
	}
	$kiwi -> info ("Writing cache file...");
	my $rpmdb = '/var/lib/rpm/Packages';
	if (-e $rpmdb) {
		my $dbsum = qxx ("cat $rpmdb | md5sum - | cut -f 1 -d-");
		chomp $dbsum;
		$cdata->{rpmdbsum} = $dbsum;
	}
	$cdata->{version} = $this->{gdata}->{Version};
	store ($cdata,$dest.".cache");
	$this->{cdata} = $cdata;
	$kiwi -> done();
	return $this;
}

1;
