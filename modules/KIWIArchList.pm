#================
# FILE          : KIWIArchList
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to adminster a list of
#               : architecture objects
#               :
# STATUS        : Development
#----------------
package KIWIArchList;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Data::Dumper;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIArch;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIArchList object which administers
	# the arch objects
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = {
		m_collect	=> undef,
		m_archs	=> {},
	};
	bless ($this, $class);
	$this->{m_collect}	= shift;
	if(not defined($this->{m_collect})) {
		return;
	}
	return $this;
}

#==========================================
# arch
#------------------------------------------
sub arch {
	my $this = shift;
	if(not ref($this)) {
		return;
	}
	my $name = shift;
	if(defined($name) and defined($this->{m_archs}->{$name})) {
		return $this->{m_archs}->{$name};
	}
	else {
		return;
	}
}

#==========================================
# dumpList
#------------------------------------------
sub dumpList {
	my $this = shift;
	if(not ref($this)) {
		return;
	}
	if($@) {
		$this->{m_collect}->logger()->error("Cannot load Data::Dumper!");
		return;
	} else {
		return Dumper($this->{m_archs});
	}
}

#==========================================
# Private Helpers
#------------------------------------------
#==========================================
# _addArch
#------------------------------------------
sub _addArch {
	my @list  = @_;
	my $error = 0;
	my $this;
	if (! @list) {
		$error = 1;
	} else { 
		$this = shift @list;
		if (not ref ($this)) {
			$error = 1;
		}
		my $num = @list;
		if ($num < 3) {
			$error = 1;
		}
	}
	if ($error == 1) {
		$this->{m_collect}->logger()->error(
			"_addArch: wrong number of arguments!\n"
		);
		return;
	}
	my ($name, $desc, $next, $head) = @list;
	if(defined($this->{m_archs}->{$name})) {
		$this->{m_collect}->logger()->error(
			"_addArch: arch=$name already in list, skipping\n"
		);
		return 0;
	}
	my $arch = KIWIArch -> new ($name, $desc, $next, $head);
	$this->{m_archs}->{$name} = $arch;
	return 1;
}

#==========================================
# addArchs
#------------------------------------------
sub addArchs {
	# ...
	# Add all architectures from a hash
	# The hash has the following structure
	# (see KIWIXML::getProductRequiredArchitectures):
	# - name => [descr, nextname, ishead]
	# nextname is verified through xml validation:
	# there must be an entry with the referred name
	# ---
	my $this = shift;
	if(not ref($this)) {
		return;
	}
	my $hashref = shift;
	if(not defined($hashref)) {
		return;
	}
	foreach my $a(keys(%{$hashref})) {
		my $n = $hashref->{$a}->[1] eq "0"?"":$hashref->{$a}->[1];
		my $head = $hashref->{$a}->[2] eq "0"?"":$hashref->{$a}->[2];
		$this->_addArch($a, $hashref->{$a}->[0], $n, $head);
	}
	return 0;
}

#==========================================
# fallbacks
#------------------------------------------
sub fallbacks {
	my @list = @_;
	my @al;
	if (! @list) {
		return @al;
	}
	my $this = shift @list;
	if (not ref($this)) {
		return @al;
	}
	my $name = shift @list;
	if (not defined($name)) {
		return @al;
	}
	if (not defined($this->{m_archs}->{$name})) {
		return @al;
	}
	my %omits;
	if(@list) {
		%omits = map { $_ => 1 } @list;
	}
	# loop the whole chain following "$name":
	my $arch = $this->arch($name);
	while(1) {
		if (not($omits{$arch->name()})) {
			push @al, $arch->name();
		}
		$arch = $this->arch ($arch->follower());
		last if not defined ($arch);
	}
	return @al;
}

#==========================================
# headList
#------------------------------------------
sub headList {
	# ...
	# Returns a list of architecture object
	# references that are marked as "head"
	# These are specified in config.xml as:
	#   <architecures>
	#     <arch id=".." .../>
	#     ...
	#     <requiredarch ref="name"/>
	# whereby the element "name" must match an
	# arch's id="..." otherwise validation fails
	# therefore we don't check for existence
	# ---
	my $this = shift;
	my @al;
	if(not ref($this)) {
		return @al;
	}
	@al = grep { $this->{m_archs}->{$_}->isHead()  } keys(%{$this->{m_archs}});
	return @al;
}

1;
