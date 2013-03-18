#================
# FILE          : KIWIXMLSplitData.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use XML::LibXML;

use KIWIXMLExceptData;
use KIWIXMLFileData;

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
	my $class = shift;
	my $this  = $class->SUPER::new(@_);
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	my %keywords = map { ($_ => 1) } qw(
		persistent temporary
	);
	$this->{supportedKeywords} = \%keywords;
	if (! $this -> p_isInitHashRef($init) ) {
		return;
	}
	if (! $this -> p_areKeywordArgsValid($init) ) {
		return;
	}
	if ($init) {
		# Check for unsupported entries
		if (! $this -> __isInitConsistent($init)) {
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
	my %args = (
		behavior => 'persistent',
		usage    => 'except',
		caller   => 'getPersistentExceptions',
		content  => $arch
	);
	return $this -> __getData(\%args);
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
	my %args = (
		behavior => 'persistent',
		usage    => 'files',
		caller   => 'getPersistentFiles',
		content  => $arch
	);
	return $this -> __getData(\%args);
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
	my %args = (
		behavior => 'temporary',
		usage    => 'except',
		caller   => 'getTemporaryExceptions',
		content  => $arch
	);
	return $this -> __getData(\%args);
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
	my %args = (
		behavior => 'temporary',
		usage    => 'files',
		caller   => 'getTemporaryFiles',
		content  => $arch
	);
	return $this -> __getData(\%args);
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
	# ...
	# Return an XML Element representing the object's data
	# ---
	my $this = shift;
	my $element = XML::LibXML::Element -> new('split');
	my @behavior = qw /persistent temporary/;
	my @usage = qw /except files/;
	for my $behave (@behavior) {
		my $bElem = XML::LibXML::Element -> new($behave);
		for my $use (@usage) {
			my %args = (
				behavior => $behave,
				parent   => $bElem,
				usage    => $use,
			);
			$this -> __addChildXMLElements(\%args);
		}
		my @children = $bElem -> getChildrenByTagName('file');
		if (@children) {
			$element -> addChild($bElem);
		}
	}
	return $element;
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
	my %args = (
		behavior => 'persistent',
		usage    => 'except',
		caller   => 'setPersistentExceptions',
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
	my %args = (
		behavior => 'persistent',
		usage    => 'files',
		caller   => 'setPersistentFiles',
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
	my %args = (
		behavior => 'temporary',
		usage    => 'except',
		caller   => 'setTemporaryExceptions',
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
	my %args = (
		behavior => 'temporary',
		usage    => 'files',
		caller   => 'setTemporaryFiles',
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
# __addChildElements
#------------------------------------------
sub __addChildXMLElements {
	# ...
	# Add child XML elements to the given parent based on the given behavior
	# and usage.
	# ---
	my $this = shift;
	my $args = shift;
	my $kiwi = $this->{kiwi};
	if (ref($args) ne 'HASH') {
		my $msg = 'Internal error: __addChildXMLElements called without '
			. 'keyword arguments. Please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> oops();
		return;
	}
	my $behavior = $args->{behavior};
	my $parent   = $args->{parent};
	my $usage    = $args->{usage};
	if ($this->{$behavior} && $this->{$behavior}{$usage}) {
		my %args = (
		    behavior => $behavior,
			usage    => $usage,
			caller   => 'getXMLElement'
	    );
		my $genObjs = $this -> __getDataArchAgnostic(\%args);
		for my $dataO (@{$genObjs}) {
			$parent -> addChild($dataO -> getXMLElement());
		}
		my @arches = sort keys %{$this->{$behavior}{$usage}};
		for my $arch (@arches) {
			if ($arch eq 'all') {
				next;
			}
			$args{content} = $arch;
			my $dataObjs = $this -> __getDataArchSpecific(\%args);
			for my $dataO (@{$dataObjs}) {
				$parent -> addChild($dataO -> getXMLElement());
			}
		}
	}
	return 1;
}

#==========================================
# __getData
#------------------------------------------
sub __getData {
	# ...
	# Return the data from the internal data structure based on
	# behavior, usage, and content
	# ---
	my $this = shift;
	my $init = shift;
	my $behavior = $init->{behavior};
	my $usage    = $init->{usage};
	my $caller   = $init->{caller};
	my $content  = $init->{content};
	my $kiwi = $this->{kiwi};
	my @dataObjs;
	if (! $behavior || ! $usage || ! $caller) {
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
		push @dataObjs, @{$this -> __getDataArchSpecific($init)};
	}
	push @dataObjs, @{$this -> __getDataArchAgnostic($init)};
	return \@dataObjs;
}

#==========================================
# __getDataArchAgnostic
#------------------------------------------
sub __getDataArchAgnostic {
	# ...
	# Return the data from the internal data structure based on
	# behavior, usage, and content that is architecture agnostic
	# ---
	my $this = shift;
	my $init = shift;
	my $behavior = $init->{behavior};
	my $usage    = $init->{usage};
	my $caller   = $init->{caller};
	my $kiwi = $this->{kiwi};
	my @dataObjs;
	if ($this->{$behavior}) {
		my @files;
		if ($this->{$behavior}{$usage}) {
			if ($this->{$behavior}{$usage}{all}) {
				push @files, @{$this->{$behavior}{$usage}{all}};
			}
		}
		for my $fl (@files) {
			my %init = ( name => $fl );
			if ($usage eq 'except') {
				push @dataObjs, KIWIXMLExceptData -> new(\%init);
			} elsif ($usage eq 'files') {
				push @dataObjs, KIWIXMLFileData -> new(\%init);
			} else {
				my $msg = 'Internal error: please file a bug __getData on '
					. 'SplitData called with unkown usage access.';
				$kiwi -> error($msg);
				$kiwi -> oops();
				return;
			}
		}
	}
	return \@dataObjs;
}
#==========================================
# __getDataArchSpecific
#------------------------------------------
sub __getDataArchSpecific {
	# ...
	# Return the data from the internal data structure based on
	# behavior, usage, and content that is architecture specific
	# ---
	my $this = shift;
	my $init = shift;
	my $behavior = $init->{behavior};
	my $usage    = $init->{usage};
	my $caller   = $init->{caller};
	my $content  = $init->{content};
	my $kiwi = $this->{kiwi};
	my @dataObjs;
	if ($content) {
		my @files;
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
		for my $fl (@files) {
			my %init = (
				arch => $content,
				name => $fl
			);
			if ($usage eq 'except') {
				push @dataObjs, KIWIXMLExceptData -> new(\%init);
			} elsif ($usage eq 'files') {
				push @dataObjs, KIWIXMLFileData -> new(\%init);
			} else {
				my $msg = 'Internal error: please file a bug __getData on '
					. 'SplitData called with unkown usage access.';
				$kiwi -> error($msg);
				$kiwi -> oops();
				return;
			}
		}
	}
	return \@dataObjs;
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
	if (! $this->{supportedArch}{$arch} ) {
		my $msg = "$caller: specified architecture '$arch' is not supported.";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
	# ...
	# Verify that the initialization hash given to the constructor meets
	# all consistency and data criteria.
	# ---
	my $this = shift;
	my $init = shift;
	my $kiwi = $this->{kiwi};
	my %supportedBehavior = %{$this->{supportedKeywords}};
	my %supportedUsage = (
		except => 1,
		files  => 1
	);
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
