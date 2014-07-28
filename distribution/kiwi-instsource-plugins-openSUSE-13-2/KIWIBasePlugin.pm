################################################################
# Copyright (c) 2014 SUSE
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file LICENSE); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
package KIWIBasePlugin;

use strict;
use warnings;
use IO::Select;
use IPC::Open3;
use Symbol;

sub new {
	my $class = shift;
	my $this  = {
		m_handler     => undef,
		m_name        => "KIWIBasePlugin",
		m_order       => undef,
		m_requireddirs=> [],
		m_descr       => [],
		m_requires    => [],
		m_ready       => 0,
		m_collect     => 0
	};
	bless ($this, $class);
	$this->{m_handler} = shift;
	if (! ref($this->{m_handler})) {
		return;
	}
	$this->{m_collect} = $this->{m_handler}->collect();
	return $this;
}

sub name {
	my $this = shift;
	my $name = shift;
	if (! ref($this)) {
		return;
	}
	my $oldname = $this->{m_name};
	if($name) {
		$this->{m_name} = $name;
	}
	return $oldname;
}

sub order {
	my $this  = shift;
	my $order = shift;
	if (! ref($this)) {
		return;
	}
	my $oldorder = $this->{m_order};
	if($order) {
		$this->{m_order} = $order;
	}
	return $oldorder;
}

sub ready {
	my $this  = shift;
	my $ready = shift;
	if (! ref($this)) {
		return;
	}
	my $oldready = $this->{m_ready};
	if($ready) {
		$this->{m_ready} = $ready;
	}
	return $oldready;
}

sub requiredDirs {
	my @params = @_;
	my $this = shift @params;
	my @dirs = @params;
	if (! ref($this)) {
		return;
	}
	my @oldrd = @{$this->{m_requireddirs}};
	foreach my $entry(@params) {
		push @{$this->{m_requireddirs}}, $entry;
	}
	return @oldrd;
}

sub description {
	my @params = @_;
	my $this = shift @params;
	my @descr= @params;
	if (! ref($this)) {
		return;
	}
	my @olddesc = $this->{m_descr};
	foreach my $entry(@descr) {
		push @{$this->{m_descr}}, $entry;
	}
	return @olddesc;
}

sub requires {
	my @params = @_;
	my $this = shift;
	my @reqs = @params;
	if (! ref($this)) {
		return;
	}
	my @oldreq = $this->{m_requires};
	foreach my $entry(@reqs) {
		push @{$this->{m_requires}}, $entry;
	}
	return @oldreq;
}

sub handler {
	my $this = shift;
	if (! ref($this)) {
		return;
	}
	return $this->{m_handler};
}

sub collect {
	my $this = shift;
	if (! ref($this)) {
		return;
	}
	return $this->{m_collect};
}

sub logMsg {
	my $this = shift;
	if (! ref($this)) {
		return;
	}
	my $type = shift;
	my $msg = shift;
	if ((! defined($type)) || (! defined($msg))) {
		return;
	}
	$this->{m_collect}->logMsg($type, $msg);
	return $this;
}

sub callCmd {
	my $this = shift;
	my $cmd  = shift;
	my $BUFSIZE = 1024;
	my @result;
	my @errors;
	my $result_buf;
	my $errors_buf;
	my ($CHILDWRITE, $CHILDSTDOUT, $CHILDSTDERR) = map { gensym } 1..3;
	my $pid = open3 (
		$CHILDWRITE, $CHILDSTDOUT, $CHILDSTDERR, "$cmd"
	);
	my $sel = IO::Select->new();
	$sel->add($CHILDSTDOUT);
	$sel->add($CHILDSTDERR);
	while (my @ready = $sel->can_read()) {
		foreach my $handle (@ready) {
			while (sysread($handle, my $bytes_read, $BUFSIZE) != 0) {
				if ($handle == $CHILDSTDOUT) {
					$result_buf .= $bytes_read;
				} else {
					$errors_buf .= $bytes_read;
				}
			}
			$sel->remove($handle);
		}
	}
	if ($result_buf) {
		@result = split (/\n/x,$result_buf);
		chomp @result;
	}
	if ($errors_buf) {
		@errors = split (/\n/x,$errors_buf);
		chomp @errors;
	}
	waitpid( $pid, 0 );
	my $status = $? >> 8;
	return [$status,\@result,\@errors];
}

sub getSubdirLists {
	# ...
	# method to distinguish debugmedia and ftp media subdirectories.
	# ---
	my $this = shift;
	if (! ref($this)) {
		return;
	}
	my @ret = ();
	my $coll = $this->{m_collect};
	my $dbm = $coll->productData()->getOpt("DEBUGMEDIUM");
	my $flavor = $coll->productData()->getVar("FLAVOR");
	my $basesubdirs = $coll->basesubdirs();
	my @paths = values(%{$basesubdirs});
	@paths = grep { $_ =~ /[^0]$/x } @paths; # remove Media0
	my %path = map { $_ => 1 } @paths;
	if($flavor =~ m{ftp}i) {
		# 1: FTP tree, all subdirs get a separate call.
		my @d = sort(keys(%path));
		foreach(@d) {
			my @tmp;
			push @tmp, $_;
			push @ret, \@tmp;
		}
	} elsif($dbm >= 2) {
		# 2: non-ftp tree, may have separate DEBUGMEDIUM specified
		my @deb;
		my @rest;
		foreach my $d(keys(%path)) {
			if ($d =~ m{.*$dbm$}x) {
				push @deb, $d;
			} else {
				push @rest, $d;
			}
		}
		push @ret, \@deb;
		push @ret, \@rest;
	} else {
		my @d = keys(%path);
		push @ret, \@d;
	}
	return @ret;
}

1;
