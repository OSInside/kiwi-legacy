#================
# FILE          : KIWIXMLSplitData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <split> element
#               : and it's children.
#               :
# STATUS        : Development
#----------------
package KIWIXMLSplitData;
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
	# Create the KIWIXMLSplitData object
	#
	# Internal data structure
	#
	# this = {
	#    persistent = {
	#        except = {
	#            all     = (),
	#            arch[+] = ()
	#        }
	#        files = {
	#            all     = (),
	#            arch[+] = ()
	#        }
	#    }
	#    temporary = {
	#        except = {
	#            all     = (),
	#            arch[+] = ()
	#        }
	#        files = {
	#            all     = (),
	#            arch[+] = ()
	#        }
	#    }
	# }
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
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	if ($init && ref($init) ne 'HASH') {
		my $msg = 'Expecting a hash ref as second argument if provided';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($init) {
		# Check for unsupported entries
		if (! $this -> __isInitHashValid($init)) {
			return;
		}
		$this->{persistent} = $init->{persistent};
		$this->{temporary}  = $init->{temporary};
	}
	
	return $this;
}

#==========================================
# getPersistentExceptions
#------------------------------------------
sub getPersistentExceptions {
	# ...
	# Return an array ref to an array containing a list of exceptions to
	# the persistent file for the given architecture or the architecture
	# independent files if no architecture is specified.
	# ---
	my $this = shift;
	my $arch = shift;
	my $files = $this->__getData('persistent',
								'except',
								'getPersistentExceptions',
								$arch
								);
	return $files;
}

#==========================================
# getPersistentFiles
#------------------------------------------
sub getPersistentFiles {
	# ...
	# Return an array ref to an array containing a list of persistent files
	# for the given architecture or the architecture independent files if
	# no architecture is specified.
	# ---
	my $this = shift;
	my $arch = shift;
	my $files = $this->__getData('persistent',
								'files',
								'getPersistentFiles',
								$arch
								);
	return $files;
}

#==========================================
# getTemporaryExecptions
#------------------------------------------
sub getTemporaryExceptions {
	# ...
	# Return an array ref to an array containing a list of exceptions to
	# the persistent file for the given architecture or the architecture
	# independent files if no architecture is specified.
	# ---
	my $this = shift;
	my $arch = shift;
	my $files = $this->__getData('temporary',
								'except',
								'getTemporaryExceptions',
								$arch
								);
	return $files;
}

#==========================================
# getTemporaryFiles
#------------------------------------------
sub getTemporaryFiles {
	# ...
	# Return an array ref to an array containing a list of persistent files
	# for the given architecture or the architecture independent files if
	# no architecture is specified.
	# ---
	my $this = shift;
	my $arch = shift;
	my $files = $this->__getData('temporary',
								'files',
								'getTemporaryFiles',
								$arch
								);
	return $files;
}

#==========================================
# setPersistentExecptions
#------------------------------------------
sub setPersistentExceptions {
	# ...
	# Set the exception array for the persistent data for the given
	# architecture or the architecture independent files if no architecture
	# is specified. Any existing data will be overwritten or erased if no
	# new data is defined.
	# ---
	my $this = shift;
	my $data = shift;
	my $arch = shift;
	my %args = ( behavior => 'persistent',
				usage    => 'except',
				'caller' => 'setPersistentExceptions',
				data     => $data,
				content  => $arch
			);
	my $status = $this->__setData(\%args);
	return $status;
}

#==========================================
# setPersistentFiles
#------------------------------------------
sub setPersistentFiles {
	# ...
	# Set the file array for the persistent data for the given
	# architecture or the architecture independent files if no architecture
	# is specified. Any existing data will be overwritten or erased if no
	# new data is defined.
	# ---
	my $this = shift;
	my $data = shift;
	my $arch = shift;
	my %args = ( behavior => 'persistent',
				usage    => 'files',
				'caller' => 'setPersistentFiles',
				data     => $data,
				content  => $arch
			);
	my $status = $this->__setData(\%args);
	return $status;
}

#==========================================
# setTemporaryExecptions
#------------------------------------------
sub setTemporaryExceptions {
	# ...
	# Set the exception array for the temporary data for the given
	# architecture or the architecture independent files if no architecture
	# is specified. Any existing data will be overwritten or erased if no
	# new data is defined.
	# ---
	my $this = shift;
	my $data = shift;
	my $arch = shift;
	my %args = ( behavior => 'temporary',
				usage    => 'except',
				'caller' => 'setTemporaryExceptions',
				data     => $data,
				content  => $arch
			);
	my $status = $this->__setData(\%args);
	return $status;
}

#==========================================
# setTemporaryFiles
#------------------------------------------
sub setTemporaryFiles {
	# ...
	# Set the file array for the temporary data for the given
	# architecture or the architecture independent files if no architecture
	# is specified. Any existing data will be overwritten or erased if no
	# new data is defined.
	# ---
	my $this = shift;
	my $data = shift;
	my $arch = shift;
	my %args = ( behavior => 'temporary',
				usage    => 'files',
				'caller' => 'setTemporaryFiles',
				data     => $data,
				content  => $arch
			);
	my $status = $this->__setData(\%args);
	return $status;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getData
#------------------------------------------
sub __getData {
	# ...
	# Return the data from the internal data structure based on
	# behavior, usage, and content
	# ---
	my $this     = shift;
	my $behavior = shift;
	my $usage    = shift;
	my $caller   = shift;
	my $content  = shift;
	my @files;
	if (! $behavior || ! $usage || ! $caller) {
		my $kiwi = $this->{kiwi};
		my $msg = 'Internal error: please file a bug __getData on SplitData '
			. 'called with insufficient arguments.';
		$kiwi -> error($msg);
		$kiwi -> oops();
		return;
	}
	if ($content) {
		if (! $this->__isArchValid($content, $caller)) {
			return;
		}
		if ($this->{$behavior}) {
			if ($this->{$behavior}{$usage}) {
				if ($this->{$behavior}{$usage}{$content}) {
					@files = @{$this->{$behavior}{$usage}{$content}};
				}
			}
		}
	}
	if ($this->{$behavior}) {
		if ($this->{$behavior}{$usage}) {
			if ($this->{$behavior}{$usage}{all}) {
				push @files, @{$this->{$behavior}{$usage}{all}};
			}
		}
	}
	return \@files;
}

#==========================================
# __isArchValid
#------------------------------------------
sub __isArchValid {
	# ...
	# Verify that the architecture used is supported
	# ---
	my $this   = shift;
	my $arch   = shift;
	my $caller = shift;
	my $kiwi = $this->{kiwi};
	my %supportedArch = map { ($_ => 1) } qw(
		armv7l ia64 ix86 ppc ppc64 s390 s390x x86_64
	);
	if (! $arch) {
		my $msg = '__isArchValid: internal error called without arch arg.';
		$kiwi -> info($msg);
		$kiwi -> oops();
		return;
	}
	if (! $caller ) {
		my $msg = '__isArchValid: internal error called without call '
			. 'origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
		return;
	}
	if (! $supportedArch{$arch} ) {
		my $msg = "$caller: specified architecture '$arch' is not supported.";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __isInitHashValid
#------------------------------------------
sub __isInitHashValid {
	# ...
	# Verify that the initialization hash given to the constructor meets
	# all consistency and data criteria.
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my %supportedBehavior = ( persistent => 1,
							temporary  => 1
							);
	my %supportedUsage = ( except => 1,
						files  => 1
						);
	for my $key (keys %{$init}) {
		if (! $supportedBehavior{$key} ) {
			my $msg = 'Unsupported option in initialization structure '
				. "found '$key'";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	for my $behavior (keys %supportedBehavior) {
		if ($init->{$behavior} && ref($init->{$behavior}) ne 'HASH') {
			my $msg = "Expecting hash ref as entry for '$behavior' in "
				. 'initialization structure.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		for my $usage (keys %{$init->{$behavior}}) {
			if (! $supportedUsage{$usage} ) {
				my $msg = 'Unsupported option in initialization structure '
					. "for '$behavior', found '$usage'";
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
			if (ref($init->{$behavior}{$usage}) ne 'HASH') {
				my $msg = "Expecting hash ref as entry for '$usage' in "
				. 'initialization structure.';
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
			LEVEL3:
			for my $key (keys %{$init->{$behavior}{$usage}} ) {
				if (ref($init->{$behavior}{$usage}{$key}) ne 'ARRAY') {
					my $msg = 'Expecting array ref as the entry for '
						. "'$key' files in initialization structure for "
						. "'$behavior' with '$usage'.";
					$kiwi -> error($msg);
					$kiwi -> failed();
					return;
				}
				if ($key eq 'all') {
					next LEVEL3;
				}
				if (! $this->__isArchValid($key,'Initialization structure')) {
					return;
				}
			}
		}
	}
	return 1;
}

#==========================================
# __setData
#------------------------------------------
sub __setData {
	# ...
	# Set the data from the internal data structure based on
	# behavior, usage, and content
	# ---
	my $this = shift;
	my $args = shift;
	my $behavior = $args->{behavior};
	my $usage    = $args->{usage};
	my $caller   = $args->{caller};
	my $data     = $args->{data};
	my $content  = $args->{content};
	my $kiwi = $this->{kiwi};
	my @files;
	if (! $behavior || ! $usage || ! $caller) {
		my $msg = 'Internal error: please file a bug __setData on SplitData '
			. 'called with insufficient arguments.';
		$kiwi -> error($msg);
		$kiwi -> oops();
		return;
	}
	if ($data && ref($data) ne 'ARRAY') {
		my $msg = "$caller: expecting array ref as first argument if given.";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($content) {
		if (! $this->__isArchValid($content, $caller)) {
			return;
		}
		if ($data) {
			$this->{$behavior}{$usage}{$content} = $data;
		} else {
			if ($this->{$behavior}) {
				if ($this->{$behavior}{$usage}) {
					if ($this->{$behavior}{$usage}{$content}) {
						delete $this->{$behavior}{$usage}{$content};
					}
				}
			}
		}
		return $this;
	}
	if ($data) {
		$this->{$behavior}{$usage}{all} = $data;
	} else {
		if ($this->{$behavior}) {
			if ($this->{$behavior}{$usage}) {
				if ($this->{$behavior}{$usage}{all}) {
					delete $this->{$behavior}{$usage}{all};
				}
			}
		}
	}
	return $this;
}

1;
