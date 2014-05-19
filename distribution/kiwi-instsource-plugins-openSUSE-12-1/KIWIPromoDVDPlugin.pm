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
package KIWIPromoDVDPlugin;

use strict;
use warnings;

use base "KIWIBasePlugin";
use Data::Dumper;
use Config::IniFiles;
use File::Find;
use File::Basename;

sub new {
	# ...
	# Create a new KIWIPromoDVDPlugin object
	# ---
	my $class   = shift;
	my $handler = shift;
	my $config  = shift;
	my $configpath;
	my $configfile;
	my $this = KIWIBasePlugin -> new($handler);
	bless ($this, $class);

	if ($config =~ m{(.*)/([^/]+)$}x) {
		$configpath = $1;
		$configfile = $2;
	}
	if ((! $configpath) || (! $configfile)) {
		$this->logMsg("E",
			"wrong parameters in plugin initialisation\n"
		);
		return;
	}
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
	my $name   = $ini->val('base', 'name');
	my $order  = $ini->val('base', 'order');
	my $enable = $ini->val('base', 'defaultenable');
	# if any of those isn't set, complain!
	if(not defined($name)
		or not defined($order)
		or not defined($enable)
	) {
		$this->logMsg("E",
			"Plugin ini file <$config> seems broken!\n"
		);
		return;
	}
	$this->name($name);
	$this->order($order);
	if($enable != 0) {
		$this->ready(1);
	}
	return $this;
}

sub execute {
	my $this = shift;
	if(not ref($this)) {
		return;
	}
	if($this->{m_ready} == 0) {
		return 0;
	}
	my $ismini = $this->collect()
		->productData()->getVar("FLAVOR");
	if(not defined($ismini)) {
		$this->logMsg("W", "FLAVOR not set?");
		return 0;
	}
	if ($ismini !~ m{dvd-promo}ix) {
		return 0;
	}
	my $medium = $this->collect()
		->productData()->getVar("MEDIUM_NAME");
	find( sub { 
			if (m/initrd.liv/x) { 
				my $cd = $File::Find::name; 
				system("mkdir -p boot; echo $medium > boot/mbrid");
				system("echo boot/mbrid | cpio --create --format=newc --quiet | gzip -9 -f >> $cd");
				system("rm boot/mbrid; rmdir boot");
				$this->logMsg("I", "updated $cd");
			}
		},
		$this->handler()->collect()->basedir()
	);
	return 0;
}

1;
