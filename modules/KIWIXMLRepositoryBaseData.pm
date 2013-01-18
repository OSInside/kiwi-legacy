#================
# FILE          : KIWIXMLRepositoryBaseData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This is the base class for element sthat represent
#               : repository data
#               :
# STATUS        : Development
#----------------
package KIWIXMLRepositoryBaseData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use XML::LibXML;
require Exporter;

use base qw /KIWIXMLDataBase/;
#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLRepositoryBaseData object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $init   = shift;
	my $addlKW = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	if (! $this -> __hasInitArg($init) ) {
		return;
	}
	my %keywords = map { ($_ => 1) } qw(
		password
		path
		priority
		username
	);
	if ($addlKW) {
		for my $kw (@{$addlKW}) {
			$keywords{$kw} = 1;
		}
	}
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> __isInitHashRef($init) ) {
		return;
	}
	if (! $this -> __areKeywordArgsValid($init) ) {
		return;
	}
	if (! $this -> __isInitBaseConsistent($init)) {
		return;
	}
	$this->{elname}   = 'mustOverWrite';
	$this->{password} = $init->{password};
	$this->{path}     = $init->{path};
	$this->{priority} = $init->{priority};
	$this->{username} = $init->{username};

	return $this;
}

#==========================================
# getCredentials
#------------------------------------------
sub getCredentials {
	# ...
	# Return the username and password for the repository
	# ---
	my $this = shift;
	return $this->{username}, $this->{password};
}

#==========================================
# getPath
#------------------------------------------
sub getPath {
	# ...
	# Return the URI for the repository
	# ---
	my $this = shift;
	return $this->{path};
}

#==========================================
# getPriority
#------------------------------------------
sub getPriority {
	# ...
	# Return the priority setting for the repository
	# ---
	my $this = shift;
	return $this->{priority};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new( $this->{elname} );
	my ($uname, $pass) = $this -> getCredentials();
	if ($pass) {
		$element -> setAttribute('password', $pass);
	}
	my $prio = $this -> getPriority();
	if ($prio) {
		$element -> setAttribute('priority', $prio);
	}
	if ($uname) {
		$element -> setAttribute('username', $uname);
	}
	my $sElem = XML::LibXML::Element -> new('source');
	$sElem -> setAttribute('path', $this -> getPath());
	$element -> addChild($sElem);
	return $element;
}

#==========================================
# setCredentials
#------------------------------------------
sub setCredentials {
	# ...
	# Set the credentials for this repository
	# ---
	my $this = shift;
	my $username = shift;
	my $password = shift;
	if (! $username ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setCredentials: no username specified';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $password ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setCredentials: no password specified';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{username} = $username;
	$this->{password} = $password;
	return $this;
}

#==========================================
# setPath
#------------------------------------------
sub setPath {
	# ...
	# Set the path for the repository
	# ---
	my $this = shift;
	my $path = shift;
	if (! $path ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setPath: No location specified, retaining current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{path} = $path;
	return $this;
}

#==========================================
# setPriority
#------------------------------------------
sub setPriority {
	# ...
	# Set the priority for this repository
	# ---
	my $this = shift;
	my $prio = shift;
	if (! $prio ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setPriority: No priority specified, retaining current data';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{priority} = $prio;
	return $this;
}

#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitBaseConsistent {
	# ...
	# Verify that the initialization hash is valid
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my $className = ref($this);
	if (! $init->{path} ) {
		my $msg = "$className: no "
			. '"path" specified in initialization structure.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ( $init->{password} && ! $init->{username} ) {
		my $msg = "$className: initialization data contains "
			. 'password, but no username';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $init->{password} && $init->{username} ) {
		my $msg = "$className: initialization data contains "
			. 'username, but no password';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

1;
