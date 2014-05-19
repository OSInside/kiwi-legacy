################################################################
# Copyright (c) 2008 Jan-Christoph Bornschlegel, SUSE LLC
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
package KIWIContentPlugin;

use strict;
use warnings;

use base "KIWIBasePlugin";
use FileHandle;
use Data::Dumper;
use Config::IniFiles;

sub new {
	# ...
	# Create a new KIWIContentPlugin object
	# ---
	my $class   = shift;
	my $handler = shift;
	my $config  = shift;
	my $configpath;
	my $configfile;
	my $this = KIWIBasePlugin -> new ($handler);
	bless ($this, $class);
	if ($config =~ m{(.*)/([^/]+)$}x) {
		$configpath = $1;
		$configfile = $2;
	}
	if(not defined($configpath) or not defined($configfile)) {
		$this->logMsg("E", "wrong parameters in plugin initialisation\n");
		return;
	}
	## Gather all necessary information from the inifile:
	#===
	# Issue: why duplicate code here? Why not put it into the base class?
	# Answer: Each plugin may have different options. Some only need a
	# target filename, whilst some others may need much more. I don't want
	# to specify a complicated framework for the plugin, it shall just be
	# a simple straightforward way to get information into the plugin.
	# The idea is that the people who decide on the metadata write
	# the plugin, and therefore damn well know what it needs and what not.
	# I'm definitely not bothering PMs with Yet Another File Specification
	#---
	## plugin content:
	#-----------------
	#[base]
	# name = KIWIEulaPlugin
	# order = 3
	# defaultenable = 1
	#
	#[target]
	# targetfile = content
	# targetdir = $PRODUCT_DIR
	# media = (list of numbers XOR "all")
	#
	my $ini = Config::IniFiles -> new(
		-file => "$configpath/$configfile"
	);
	my $name      = $ini->val('base', 'name'); # scalar value
	my $order     = $ini->val('base', 'order'); # scalar value
	my $enable    = $ini->val('base', 'defaultenable'); # scalar value
	my $target    = $ini->val('target', 'targetfile');
	my $targetdir = $ini->val('target', 'targetdir');
	my @media     = $ini->val('target', 'media');
	# if any of those isn't set, complain!
	if(not defined($name)
		or not defined($order)
		or not defined($enable)
		or not defined($target)
		or not defined($targetdir)
		or not @media
	) {
		$this->logMsg("E", "Plugin ini file <$config> seems broken!");
		return;
	}
	$this->name($name);
	$this->order($order);
	$targetdir = $this->collect()->productData()->_substitute("$targetdir");
	if($enable != 0) {
		$this->ready(1);
	}
	$this->requiredDirs($targetdir);
	$this->{m_target} = $target;
	$this->{m_targetdir} = $targetdir;
	@{$this->{m_media}} = @media;
	return $this;
}

sub execute {
	my $this = shift;
	if(not ref($this)) {
		return;
	}
	my $retval = 0;
	if($this->{m_ready} == 0) {
		return $retval;
	}
	my $descrdir = $this->collect()->productData()->getInfo("DESCRDIR");
	if ((! $descrdir) || ($descrdir eq "/")) {
		$this->logMsg("I",
			"Empty or (/) descrdir, skipping content file creation"
		);
		return $retval;
	}
	my @targetmedia = $this->collect()->getMediaNumbers();
	my %targets;
	if($this->{m_media}->[0] =~ m{all}i) {
		%targets = map { $_ => 1 } @targetmedia;
	} else {
		foreach my $cd(@{$this->{m_media}}) {
			if(grep { $cd } @targetmedia) {
				$targets{$cd} = 1;
			}
		}
	}
	my $info = $this->collect()->productData()->getSet("prodinfo");
	if(!$info) {
		$this->logMsg("E", "data set named <prodinfo> seems to be broken:");
		$this->logMsg("E", Dumper($info));
		return $retval;
	}
	foreach my $cd(keys(%targets)) {
		$this->logMsg("I", "Creating content file on medium <$cd>:");
		my $dir = $this->collect()->basesubdirs()->{$cd};
		my $contentfile = "$dir/$this->{m_target}";
		my $CONT = FileHandle -> new();
		if (! $CONT -> open(">$contentfile")) {
			$this->logMsg("E", "Cannot create <$contentfile> on medium <$cd>");
			next;
		}
		# compute maxlen:
		my $len = 0;
		foreach(keys(%{$info})) {
			my $l = length($info->{$_}->[0]);
			$len = ($l>$len)?$l:$len;
		}
		$len++;
		# ftp media special mode ?
		my $coll = $this->{m_collect};
		my $flavor = $coll->productData()->getVar("FLAVOR");
		my $ftpmode = ($flavor =~ m{ftp}i);

		my %ftpcontentkeys = map {$_ => 1} qw{
			CONTENTSTYLE REPOID DESCRDIR DATADIR VENDOR
		};
		foreach my $i(sort { $a <=> $b } keys(%{$info})) {
		# ftp medias beside first one should get provide the product
			if ( !$ftpmode || $cd eq "1" || $ftpcontentkeys{$info->{$i}->[0]}) {
				print $CONT sprintf(
					'%-*s %s', $len, $info->{$i}->[0], $info->{$i}->[1]
				)."\n";
			}
		}
		$CONT -> close();
		$this->logMsg(
			"I", "Wrote file <$contentfile> for medium <$cd> successfully."
		);
		$retval++;
	}
	return $retval;
}

1;
