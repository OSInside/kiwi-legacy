#================
# FILE          : KIWIPattern.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used for reading the SuSE
#               : specific pattern files
#               :
# STATUS        : Development
#----------------
package KIWIPattern;
#==========================================
# Modules
#------------------------------------------
use strict;
use KIWILog;
use KIWIURL;
use File::Glob ':glob';

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create new KIWIPattern object which is used to read
	# the given pattern data stream and provide all information
	# via member methods
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
	my $kiwi       = shift;
	my $pattref    = shift;
	my $urlref     = shift;
	my $pattype    = shift;
	my $patpactype = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my @data = ();
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (! defined $pattref) {
		$kiwi -> error ("Invalid pattern name");
		$kiwi -> failed ();
		return undef;
	}
	my @pattern = @{$pattref};
	if (! defined $urlref) {
		$kiwi -> error ("No URL list for pattern search");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $pattype) {
		$kiwi -> error ("No pattern type specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $patpactype) {
		$kiwi -> error ("No pattern package type specified");
		kiwi -> failed ();
		return undef;
	}
	my $arch = qx (arch); chomp $arch;
	if ($arch =~ /^i.86/) {
		$arch = 'i*86';
	}
	my @urllist = @{$urlref};
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{infodefault} = "Including pattern";
	$this->{infomessage} = $this->{infodefault};
	$this->{kiwi}        = $kiwi;
	$this->{urllist}     = \@urllist;
	$this->{pattern}     = \@pattern;
	$this->{pattype}     = $pattype;
	$this->{patpactype}  = $patpactype;
	$this->{arch}        = $arch;
	#==========================================
	# Initial check for pattern contents
	#------------------------------------------
	my @patdata = $this -> getPatternContents (\@pattern);
	if (! @patdata) {
		return undef;
	}
	push ( @data,@patdata );
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{data} = \@data;
	return $this;
}

#==========================================
# getPatternContents
#------------------------------------------
sub getPatternContents {
	my $this    = shift;
	my $pattref = shift;
	my $kiwi    = $this->{kiwi};
	my @urllist = @{$this->{urllist}};
	my @pattern = @{$pattref};
	my $content;
	foreach my $pat (@pattern) {
		my $result;
		my @errors;
		my $printinfo = 0;
		if (! defined $this->{cache}{$pat}) {
			$printinfo = 1;
		}
		if ($printinfo) {
			$kiwi -> info ("$this->{infomessage}: $pat");
		}
		foreach my $url (@urllist) {
			my @load = $this -> downloadPattern ( $url,$pat );
			$result .= $load[0]; push (@errors,$load[1]);
		}
		if (! $result) {
			if ($printinfo) {
				$kiwi -> failed ();
				foreach my $error (@errors) {
					$kiwi -> error  ($error);
					$kiwi -> failed ();
				}
			}
			return ();
		}
		$content .= $result;
		if ($printinfo) {
			$kiwi -> done ();
		}
	}
	my @patdata = split (/\n/,$content);
	return @patdata;
}

#==========================================
# downloadPattern
#------------------------------------------
sub downloadPattern {
	my $this    = shift;
	my $url     = shift;
	my $pattern = shift;
	my $arch    = $this->{arch};
	my $kiwi    = $this->{kiwi};
	my $content;
	if (defined $this->{cache}{$pattern}) {
		return $this->{cache}{$pattern};
	}
	if ($url =~ /^\//) {
		#==========================================
		# local pattern check
		#------------------------------------------
		my $path = "$url//suse/setup/descr";
		my @file = bsd_glob ("$path/$pattern-*.$arch.pat");
		if (! @file) {
			@file = bsd_glob ("$path/$pattern-*.$arch.pat.gz");
		}
		if (! @file) {
			return (undef,
				"Couldn't find pat by glob: \<$path/$pattern-*.$arch.pat\>"
			);
		}
		foreach my $file (@file) {
			# / FIXME /
			# The glob match will include the -32bit patterns in any
			# case. Is that ok or not ? should it be configurable ?
			# ---
			if ($file =~ /\.gz$/) {
				if (! open (FD,"cat $file | gzip -cd|")) {
					return (undef,"Couldn't uncompress pattern: $file: $!");
				}
			} else {
				if (! open (FD,$file)) {
					return (undef,"Couldn't open pattern: $file: $!");
				}
			}
			local $/; $content .= <FD>; close FD;
		}
	} else {
		#==========================================
		# remote pattern check
		#------------------------------------------
		my $urlHandler  = new KIWIURL ($kiwi);
		my $publics_url = $url;
		my $highlvl_url = $urlHandler -> openSUSEpath ($publics_url);
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
		my $browser  = LWP::UserAgent->new;
		my $location = $publics_url."/setup/descr";
		my $request  = HTTP::Request->new (GET => $location);
		my $response = $browser  -> request ( $request );
		my $title    = $response -> title ();
		$content     = $response -> content ();
		if ((! defined $title) || ($title =~ /not found/i)) {
			$location = $publics_url."/suse/setup/descr";
			$request  = HTTP::Request->new (GET => $location);
			$response = $browser  -> request ( $request );
			$title    = $response -> title ();
			$content  = $response -> content ();
			if ($title =~ /not found/i) {
				return (undef,"Page not found: $location");
			}
		}
		#==========================================
		# check for http pages first...
		#------------------------------------------
		my $pzip = 0;
		my $perr = 0;
		if ($content !~ /\"($pattern-.*$arch\.pat)\"/) {
			if ($content !~ /\"($pattern-.*$arch\.pat\.gz)\"/) {
				$perr = 1;
			} else {
				$location = $location."/".$1;
				$pzip = 1;
			}
		} else {
			$location = $location."/".$1;
		}
		#==========================================
		# check for ftp pages next...
		#------------------------------------------
		if ($perr) {
			my @plines = split (/\n/,$content);
			foreach my $line (@plines) {
				if ($line =~ / ($pattern-.*$arch\.pat\.gz)/) {
					$location = $location."/".$1;
					$pzip = 1; $perr = 0;
					last;
				}
				if ($line =~ / ($pattern-.*$arch\.pat)/) {
					$location = $location."/".$1;
					$pzip = 0; $perr = 0;
					last;
				}
			}
		}
		if ($perr) {
			return (undef,
				"Couldn't find pat by regexp: /$pattern-.*$arch\.pat/"
			);
		}
		#==========================================
		# finally get the pattern
		#------------------------------------------
		$request  = HTTP::Request->new (GET => $location);
		$response = $browser  -> request ( $request );
		$content  = $response -> content ();
		if ($pzip) {
			my $tmpdir = qx ( mktemp -q -d /tmp/kiwipattern.XXXXXX );
			my $result = $? >> 8;
			chomp $tmpdir;
			if ($result != 0) {
				return (undef,"Couldn't create tmpdir: $!");
			}
			if (! open (FD,">$tmpdir/pattern")) {
				rmdir  ($tmpdir);
				return (undef,"Couldn't create: $tmpdir/pattern: $!");
			}
			print FD $content; close FD;
			if (! open (FD,"cat $tmpdir/pattern | gzip -cd|")) {
				unlink ($tmpdir."/pattern");
				rmdir  ($tmpdir);
				return (undef,"Couldn't uncompress pattern: $!");
			}
			local $/; $content .= <FD>; close FD;
			unlink ($tmpdir."/pattern");
			rmdir  ($tmpdir);
		}
	}
	$this->{cache}{$pattern} = $content;
	return ($content,$this);
}

#==========================================
# getSection
#------------------------------------------
sub getSection {
	my $this   = shift;
	my $begin  = shift;
	my $end    = shift;
	my $patdata= shift;
	my @data   = @{$this->{data}};
	my @plist  = ();
	if (defined $patdata) {
		@plist = @{$patdata};
	} else {
		@plist = @data;
	}
	my $start  = 0;
	my %result = ();
	foreach my $line (@plist) {
		if ($line =~ /$begin/) {
			$start = 1; next;
		}
		if ($line =~ /$end/) {
			$start = 0;
		}
		if ($start) {
			if ($line) {
			if ($line !~ /^[\+\-]/) {
				$result{$line} = $line;
			}
			}
		}
	}
	return sort keys %result;
}

#==========================================
# getRequiredPatterns
#------------------------------------------
sub getRequiredPatterns {
	my $this    = shift;
	my $pattref = shift;
	my $kiwi    = $this->{kiwi};
	my $pattype = $this->{pattype};
	my @pattern = @{$pattref};
	my @patdata = $this -> getPatternContents (\@pattern);
	my @reqs;
	if ($pattype eq "onlyRequired") {
		@reqs = $this -> getSection (
			'^\+Req:','^\-Req:',\@patdata
		);
	} elsif ($pattype eq "plusSuggested") {
		@reqs = $this -> getSection (
			'^(\+Req:|\+Sug:)','^(\-Req:|\-Sug:)',\@patdata
		);
	} else {
		@reqs = $this -> getSection (
			'^\+Re[qc]:','^\-Re[qc]:',\@patdata
		);
	}
	foreach (my $count=0;$count<@reqs;$count++) {
		if ($reqs[$count] eq "basesystem") {
			$reqs[$count] = "base";
		}
	}
	foreach my $rpattern (@reqs) {
		if (defined $this->{patdone}{$rpattern}) {
			next;
		}
		$this->{infomessage} = "--> Including required pattern";
		my @patdata = $this -> getPatternContents ([$rpattern]);
		$this->{infomessage} = $this->{infodefault};
		if (! @patdata) {
			$kiwi -> warning ("Couldn't find required pattern: $rpattern");
			$kiwi -> skipped ();
			$this->{patdone}{$rpattern} = $rpattern;
			next;
		}
		push ( @{$this->{data}} , @patdata );
		$this->{patdone}{$rpattern} = $rpattern;
		$this -> getRequiredPatterns ([$rpattern]);
	}
	return @reqs;
}

#==========================================
# getPackages
#------------------------------------------
sub getPackages {
	my $this = shift;
	my $pattype = $this->{patpactype};
	my %result;
	my @reqs = $this -> getRequiredPatterns ($this->{pattern});
	my @pacs;
	if ($pattype eq "onlyRequired") {
		@pacs = $this -> getSection (
			'^\+Prq:','^\-Prq:'
		);
	} elsif ($pattype eq "plusSuggested") {
		@pacs = $this -> getSection (
			'^(\+Prq:|\+Psg:)','^(\-Prq:|\-Psg:)'
		);
	} else {
		@pacs = $this -> getSection (
			'^\+Pr[qc]:','^\-Pr[qc]:'
		);
	}
	return @pacs;
}

1;
