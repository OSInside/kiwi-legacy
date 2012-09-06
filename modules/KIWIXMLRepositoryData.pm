#================
# FILE          : KIWIXMLRepositoryData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <repository> element
#               : and it's child element <source>.
#               :
# STATUS        : Development
#----------------
package KIWIXMLRepositoryData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIXMLRepositoryData object
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
	my $path = shift;
	my $type = shift;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	my %supported = map { ($_ => 1) } qw(
		apt-deb apt-rpm	deb-dir	mirrors	red-carpet rpm-dir rpm-md slack-site
		up2date-mirrors	urpmi yast2
	);
	$this->{supportedRepoTypes} = \%supported;
	#==========================================
	# Argument checking
	#------------------------------------------
	if (! $path) {
		my $msg = 'Expecting a string or hash ref as second argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($path) eq 'HASH') {
		if (! $path->{path} ) {
			my $msg = 'Provided hash ref must contain key "path" providing '
				. 'the URI for the repository';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		if (! $path->{type} ) {
			my $msg = 'Provided hash ref must contain key "type" providing '
				. 'the type of the repository';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		} else {
			my $repoType = $path->{type};
			if (! $this->__isSupportedRepoType($repoType) ) {
				return;
			}
		}
		if ( $path->{password} && ! $path->{username} ) {
			my $msg = 'Provided hash ref contains password, but no username';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		if (! $path->{password} && $path->{username} ) {
			my $msg = 'Provided hash ref contains username, but no password';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		$this->{alias}         = $path->{alias};
		$this->{imageinclude}  = $path->{imageinclude};
		$this->{password}      = $path->{password};
		$this->{path}          = $path->{path};
		$this->{preferlicense} = $path->{preferlicense};
		$this->{priority}      = $path->{priority};
		$this->{status}        = $path->{status};
		$this->{type}          = $path->{type};
		$this->{username}      = $path->{username};
	} else {
		$this->{path} = $path;
		if (! $type) {
			my $msg = 'Expecting string specifying repo type as third arg';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		if (! $this->__isSupportedRepoType($type) ) {
			return;
		}
		$this->{type} = $type;
	}

	return $this;
}

#==========================================
# getAlias
#------------------------------------------
sub getAlias {
	# ...
	# Return the alias setting for the repository
	# ---
	my $this = shift;
	return $this->{alias};
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
# getImageInclude
#------------------------------------------
sub getImageInclude {
	# ...
	# Return the image include indicator for the repository
	# ---
	my $this = shift;
	return $this->{imageinclude};
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
# getPreferLicense
#------------------------------------------
sub getPreferLicense {
	# ...
	# Return the license file indicator for the repository
	# ---
	my $this = shift;
	return $this->{preferlicense};
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
# getStatus
#------------------------------------------
sub getStatus {
	# ...
	# Return the repository status
	# ---
	my $this = shift;
	return $this->{status};
}

#==========================================
# getType
#------------------------------------------
sub getType {
	# ...
	# Return the type setting for the repository
	# ---
	my $this = shift;
	return $this->{type};
}

#==========================================
# setAlias
#------------------------------------------
sub setAlias{
	# ...
	# Set the alias for this repository
	# ---
	my $this = shift;
	$this->{alias} = shift;
	return $this;
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
# setImageInclude
#------------------------------------------
sub setImageInclude {
	# ...
	# Set the image include indicator, when called with no argument
	# the indicator is turned off.
	# ---
	my $this = shift;
	my $include = shift;
	if ($include) {
		$this->{imageinclude} = 'true';
	} else {
		delete $this->{imageinclude};
	}
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
		$kiwi -> info($msg);
		$kiwi -> done ();
		return $this;
	}
	$this->{path} = $path;
	return $this;
}

#==========================================
# setPreferLicense
#------------------------------------------
sub setPreferLicense {
	# ...
	# Set the prefer license indicator, when called with no argument
	# the indicator is turned off.
	# ---
	my $this = shift;
	my $useLic = shift;
	if ($useLic) {
		$this->{preferlicense} = 'true';
	} else {
		delete $this->{preferlicense};
	}
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
	$this->{priority} = $prio;
	return $this;
}

#==========================================
# setStatus
#------------------------------------------
sub setStatus {
	# ...
	# Set the statusfor this repository based on keywords (fixed, replacable)
	# ---
	my $this = shift;
	my $status = shift;
	if (! $status ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setStatus: No status specified, retaining current data';
		$kiwi -> info($msg);
		$kiwi -> done ();
		return $this;
	}
	if ($status ne 'fixed' && $status ne 'replacable') {
		my $kiwi = $this->{kiwi};
		my $msg = 'setStatus: Expected keyword "fixed" or "replacable"';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{status} = $status;
	return $this;
}

#==========================================
# setType
#------------------------------------------
sub setType {
	# ...
	# Set the type of the repository
	# ---
	my $this = shift;
	my $type = shift;
	if (! $type ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'setType: No type specified, retaining current data';
		$kiwi -> info($msg);
		$kiwi -> done ();
		return $this;
	}
	if (! $this->__isSupportedRepoType($type) ) {
		return;
	}
	$this->{type} = $type;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isSupportedRepoType
#------------------------------------------
sub __isSupportedRepoType {
	# ...
	# Check if the specified repository type is supported
	# ---
	my $this = shift;
	my $type = shift;
	my %supported = %{ $this->{supportedRepoTypes} };
	if (! $supported{$type} ) {
		my $kiwi = $this->{kiwi};
		my $msg = "Specified repository type '$type' is not supported";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

1;
