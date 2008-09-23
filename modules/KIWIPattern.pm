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
use KIWIQX;

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
	my @products = ();
	my @patterns = ();
	my @packages = ();
	foreach my $p (@{$pattref}) {
		if ($p =~ /^product:(.*)/) {
			$p = $1;
			my $pname = "product:" . quotemeta $p;
			push(@products, $pname);
		} elsif ($p =~ /^pattern:(.*)/) {
			$p = $1;
			my $pname = "pattern:" . quotemeta $p;
			push(@patterns, $pname);
		} else {
			push (@packages,$p);
		}
	}
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
	my $arch = qxx ("uname -m"); chomp $arch;
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
	$this->{patterns}    = \@patterns;
	$this->{products}    = \@products;
	$this->{packages}    = \@packages;
	$this->{pattype}     = $pattype;
	$this->{patpactype}  = $patpactype;
	$this->{arch}        = $arch;
	#==========================================
	# Initial check for pattern contents
	#------------------------------------------
	my $nothing = 1;
	if (@products) {
		$nothing = 0;
		my @proddata = $this -> getProductContents (\@products);
		if (! @proddata) {
			return undef;
		}
	}
	if (@patterns) {
		$nothing = 0;
		my @patdata = $this -> getPatternContents (\@patterns);
		if (! @patdata) {
			return undef;
		}
		push ( @data,@patdata );
	}
	if (@packages) {
		$nothing = 0;
	}
	if ($nothing) {
		return undef;
	}
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
	my @patterns = @{$pattref};
	my $content;
	foreach my $pat (@patterns) {
		my $result;
		my @errors;
		my $printinfo = 0;
		if ($pat =~ /^pattern:(.*)/) {
			$pat = $1;
		}
		if (! defined $this->{cache}{$pat}) {
			$printinfo = 1;
		}
		if ($printinfo) {
			$kiwi -> info ("$this->{infomessage}: $pat");
		}
		foreach my $url (@urllist) {
			my @load = $this -> downloadPattern ( $url,$pat );
			if ($load[0]) {
				$result .= $load[0];
			}
			push (@errors,"[$url] -> $load[1]");
		}
		if (! $result) {
			if ($printinfo) {
				$kiwi -> failed ();
				my $count = 1;
				foreach my $error (@errors) {
					$kiwi -> error  ("    $count) $error");
					$kiwi -> failed ();
					$count++;
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
# checkContentFile
#------------------------------------------
sub checkContentData {
	my $this    = shift;
	my $location= shift;
	my $content = shift;
	my $pattern = shift;
	my $arch    = $this->{arch};
	#==========================================
	# check content...
	#------------------------------------------
	if (! $content) {
		return undef;
	}
	#==========================================
	# check content: DESCRDIR...
	#------------------------------------------
	my $perr   = 1;
	my @plines = split (/\n/,$content);
	foreach my $line (@plines) {
		if ($line =~ /DESCRDIR (.*)/) {
			$location = $location."/".$1;
			$perr = 0;
			last;
		}
	}
	if ($perr) {
		return undef;
	}
	#===========================================
	# check content: pattern file...
	#-------------------------------------------
	$perr = 1;
	$this->{pzip} = 0;
	foreach my $line (@plines) {
		if ($line =~ / ($pattern-.*$arch\.pat\.gz)/) {
			$location = $location."/".$1;
			$this->{pzip} = 1;
			$perr = 0;
			last;
		}
		if ($line =~ / ($pattern-.*$arch\.pat)/) {
			$location = $location."/".$1;
			$this->{pzip} = 0;
			$perr = 0;
			last;
		}
	}
	if ($perr) {
		return undef;
	}
	return $location;
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
	my $pfile;
	my $message;
	if (defined $this->{cache}{$pattern}) {
		return $this->{cache}{$pattern};
	}
	if ($url =~ /^\//) {
		#==========================================
		# local pattern check
		#------------------------------------------
		my $cfile = $url."/content";
		if (-f $cfile) {
			#==========================================
			# check content file
			#------------------------------------------
			if (! open (FD,$cfile)) {
				$message = "couldn't open \$url/content file";
				return (undef,"local[content]: $message: $!");
			}
			local $/; $content .= <FD>; close FD;
			$pfile = $this -> checkContentData ($url,$content,$pattern);
			if (! defined $pfile) {
				$message = "pattern match or DESCRDIR search in content failed";
				return (undef, "local[content]: $message: $pattern");
			}
		} else {
			#===========================================
			# no content file but local, try glob search
			#-------------------------------------------
			my $path = "$url//suse/setup/descr";
			my @file = bsd_glob ("$path/$pattern-*.$arch.pat");
			if (! @file) {
				@file = bsd_glob ("$path/$pattern-*.$arch.pat.gz");
			}
			if (! @file) {
				$message = "pattern glob match in dirlist failed";
				return (undef,"local[glob]: $message: $pattern");
			}
			$pfile = $file[0];
		}
		#==========================================
		# finally get the pattern
		#------------------------------------------
		if ($pfile =~ /\.gz$/) {
			if ((! -e $pfile) || (! open (FD,"cat $pfile|$main::Gzip -cd|"))) {
				$message = "couldn't uncompress pattern";
				return (undef,"local[gzip]: $message: $pfile: $!");
			}
		} else {
			if (! open (FD,$pfile)) {
				$message = "couldn't open pattern";
				return (undef,"local[open]: $message: $pfile: $!");
			}
		}
		local $/; $content .= <FD>;
		close FD;
	} else {
		#==========================================
		# remote pattern check
		#------------------------------------------
		my $urlHandler  = new KIWIURL ($kiwi,undef);
		my $publics_url = $url;
		my $highlvl_url = $urlHandler -> openSUSEpath ($publics_url,"quiet");
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
		my $browser  = LWP::UserAgent->new;
		my $location = $publics_url."/content";
		my $request  = HTTP::Request->new (GET => $location);
		my $response = $browser  -> request ( $request );
		$content     = $response -> content ();
		if ((defined $content) && ($content ne "")) {
			#==========================================
			# check content file
			#------------------------------------------
			$location = $this -> checkContentData (
				$publics_url,$content,$pattern
			);
			if (! defined $location) {
				$message = "pattern match or DESCRDIR search in content failed";
				return (undef, "remote[content]: $message: $pattern");
			}
		} else {
			#==========================================
			# no content file try remote file listing
			#------------------------------------------
			# Note:
			# some firewalls block active FTP access which will cause
			# download problems with LWP. This can be fixed by using
			# export FTP_PASSIVE=1 in your shell environment
			# ---- 
			$location = $publics_url."//suse/setup/descr";
			$request  = HTTP::Request->new (GET => $location);
			#$request -> header(Accept => "text/html");
			$response = $browser  -> request ( $request );
			$content  = $response -> content ();
			if ((! defined $content) || ($content eq "")) {
				$message = "couldn't get directory listing: ";
				$message.= $response->status_line;
				return (undef, "remote[dirlist]: $message: $location");
			}
			my $perr = 1;
			my @plines = split (/\n/,$content);
			foreach my $line (@plines) {
				if ($line =~ /[\" ]($pattern-.*$arch\.pat\.gz)(\"|$)/) {
					$location = $location."/".$1;
					$this->{pzip} = 1;
					$perr = 0;
					last;
				}
				if ($line =~ /[\" ]($pattern-.*$arch\.pat)(\"|$)/) {
					$location = $location."/".$1;
					$this->{pzip} = 0;
					$perr = 0;
					last;
				}
			}
			if ($perr) {
				$message = "pattern glob match in dirlist failed";
				return (undef, "remote[glob]: $message: $pattern");
			}
		}
		#==========================================
		# finally get the pattern
		#------------------------------------------
		$request  = HTTP::Request->new (GET => $location);
		$response = $browser  -> request ( $request );
		$content  = $response -> content ();
		if ($this->{pzip}) {
			my $tmpdir = qxx (" mktemp -q -d /tmp/kiwipattern.XXXXXX ");
			my $result = $? >> 8;
			chomp $tmpdir;
			if ($result != 0) {
				$message = "couldn't create tmpdir";
				return (undef,"remote[tmpdir] $message: $!");
			}
			if (! open (FD,">$tmpdir/pattern")) {
				rmdir  ($tmpdir);
				$message = "couldn't create";
				return (undef,"remote[open] $message: $tmpdir/pattern: $!");
			}
			print FD $content; close FD;
			if (! open (FD,"cat $tmpdir/pattern | $main::Gzip -cd|")) {
				unlink ($tmpdir."/pattern");
				rmdir  ($tmpdir);
				$message = "couldn't uncompress pattern";
				return (undef,"remote[gzip] $message: $!");
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
	my @patterns = @{$pattref};
	my @patdata = $this -> getPatternContents (\@patterns);
	my @reqs;
	if ($pattype eq "onlyRequired") {
		@reqs = $this -> getSection (
			'^\+Req:','^\-Req:',\@patdata
		);
	} elsif ($pattype eq "plusSuggested") {
		@reqs = $this -> getSection (
			'^\+(Re[qc]:|Sug:)','^\-(Re[qc]:|Sug:)',\@patdata
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
		$rpattern = quotemeta $rpattern;
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
# getProductContents
#------------------------------------------
sub getProductContents {
	my $this    = shift;
	my $prodref = shift;
	my $kiwi    = $this->{kiwi};
	my @urllist = @{$this->{urllist}};
	my @product = @{$prodref};
	my $content;
	foreach my $prd (@product) {
		my $result;
		my @errors;
		my $printinfo = 0;
		if (! defined $this->{cache}{$prd}) {
			$printinfo = 1;
		}
		if ($printinfo) {
			$kiwi -> info ("$this->{infomessage}: $prd");
		}
		foreach my $url (@urllist) {
			my @load = $this -> downloadProduct ( $url,$prd );
			if ($load[0]) {
				$result .= $load[0];
			}
			push (@errors,"[$url] -> $load[1]");
		}
		if (! $result) {
			if ($printinfo) {
				$kiwi -> failed ();
				my $count = 1;
				foreach my $error (@errors) {
					$kiwi -> error  ("    $count) $error");
					$kiwi -> failed ();
					$count++;
				}
			}
			return ();
		}
		$content .= $result;
		if ($printinfo) {
			$kiwi -> done ();
		}
	}
	my @prddata = split (/\n/,$content);
	return @prddata;
}

#==========================================
# downloadProduct
#------------------------------------------
sub downloadProduct {
	my $this    = shift;
	my $url     = shift;
	my $product = shift;
	my $arch    = $this->{arch};
	my $kiwi    = $this->{kiwi};
	my $content;
	my $pfile;
	my $message;
	if (defined $this->{cache}{$product}) {
		return $this->{cache}{$product};
	}
	if ($url =~ /^\//) {
		#==========================================
		# local product check
		#------------------------------------------
		my $cfile = $url."/content";
		if (! open (FD,$cfile)) {
			$message = "couldn't open \$url/content file";
			return (undef,"local[content]: $message: $!");
		}
		local $/; $content .= <FD>; close FD;
	} else {
		#==========================================
		# remote product check
		#------------------------------------------
		my $urlHandler  = new KIWIURL ($kiwi,undef);
		my $publics_url = $url;
		my $highlvl_url = $urlHandler -> openSUSEpath ($publics_url,"quiet");
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
		my $browser  = LWP::UserAgent->new;
		my $location = $publics_url."/content";
		my $request  = HTTP::Request->new (GET => $location);
		my $response = $browser  -> request ( $request );
		$content     = $response -> content ();
	}
	$pfile = $this->providesProduct($content,$product);
	if (! defined $pfile) {
		$message = "product match in content failed";
		return (undef, "local[content]: $message: $product");
	}
	$this->{cache}{$product} = $content;
	return ($content,$this);
}


#==========================================
# providesProduct
#------------------------------------------
sub providesProduct {
	my $this    = shift;
	my $content = shift;
	my $product = shift;
	#==========================================
	# check content...
	#------------------------------------------
	if (! $content) {
		return undef;
	}
	# are we or do we provide the product?
	#==========================================
	# check content: PRODUCT...
	#------------------------------------------
	my $perr   = 1;
	my $result;
	my @plines = split (/\n/,$content);
	my $prodname;
	foreach my $line (@plines) {
		$prodname = $line; $prodname =~ s/^product://;
		if ($line =~ /PRODUCT (.*)/) {
			if ($1 eq $prodname) {
				$result = $1;
				$perr = 0;
				last;
			}
		}
		if ($line =~ /PROVIDES (.*)/) {
			foreach my $prv ($this->parseRelString($1)) {
				if ($prv eq $product) {
					$result = $prv;
					$perr = 0;
					last;
				}
			}
		}
	}
	if ($perr) {
		return undef;
	}
	return $result;
}


#==========================================
# parseRelString
#------------------------------------------
sub parseRelString {
	my $this = shift;
	my $str = shift;
	my $skipnext = 0;
	my @reqs = ();
	foreach my $tok (split (/\s+/,$str)) {
		if ($skipnext) {
			$skipnext = 0;
			next;
		}
		if ($tok =~ /^[<>=]+$/) {
			$skipnext = 1;
			next;
		}
		push(@reqs,$tok);
	}
	return @reqs;
}


#==========================================
# getProductRequirements
#------------------------------------------
sub getProductRequirements {
	my $this    = shift;
	my $location= shift;
	my $content = shift;
	my $product = shift;
	my $arch    = $this->{arch};
	#==========================================
	# check content...
	#------------------------------------------
	if (! $content) {
		return undef;
	}
	#==========================================
	# check content: REQUIRES...
	#------------------------------------------
	my $perr   = 1;
	my $result;
	my @reqs = ();
	my @plines = split (/\n/,$content);
	foreach my $line (@plines) {
		if ($line =~ /REQUIRES (.*)/) {
			$result = $1;
			$perr = 0;
			my @r = $this->parseRelString($result);
			push(@reqs,@r);
		}
	}
	if ($perr) {
		return undef;
	}
	return @reqs;
}

#==========================================
# getRequiredProducts
#------------------------------------------
sub getRequiredProducts {
	my $this    = shift;
	my $prodref = shift;
	my $kiwi    = $this->{kiwi};
	my $pattype = $this->{pattype};
	my @products = @{$prodref};
	my @prddata = $this -> getProductContents (\@products);
	my @reqs = $this -> getProductRequirements (\@prddata);
	my @prdreqs = ();
	my @patreqs = ();
	my @pkgreqs = ();
	foreach my $r (@reqs) {
		if ($r =~ /^product:(.*)/) {
			$r = $1;
			my $pname = "product:" . quotemeta $r;
			push(@prdreqs, $pname);
		} elsif ($r =~ /^pattern:(.*)/) {
			$r = $1;
			my $pname = "pattern:" . quotemeta $r;
			push(@patreqs, $pname);
		} else {
			push (@pkgreqs,$r);
		}
	}
	foreach my $rproduct (@prdreqs) {
		if (defined $this->{prddone}{$rproduct}) {
			next;
		}
		$this->{infomessage} = "--> Including required product";
		my @prddata = $this -> getProductContents ([$rproduct]);
		$this->{infomessage} = $this->{infodefault};
		if (! @prddata) {
			$kiwi -> warning ("Couldn't find required product: $rproduct");
			$kiwi -> skipped ();
			$this->{patdone}{$rproduct} = $rproduct;
			next;
		}
		$this->{prddone}{$rproduct} = $rproduct;
		$this -> getRequiredProducts ([$rproduct]);
	}
	foreach my $rpattern (@patreqs) {
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
	return @pkgreqs;
}

#==========================================
# getPackages
#------------------------------------------
sub getPackages {
	my $this = shift;
	my $pattype = $this->{patpactype};
	my %result;
	my @packages = @{$this->{packages}};

	my @prodpkgreqs = $this -> getRequiredProducts ($this->{products});
	push (@packages, @prodpkgreqs);

	my @reqs = $this -> getRequiredPatterns ($this->{patterns});
	my @pacs;
	if ($pattype eq "onlyRequired") {
		@pacs = $this -> getSection (
			'^\+Prq:','^\-Prq:'
		);
	} elsif ($pattype eq "plusSuggested") {
		@pacs = $this -> getSection (
			'^\+(Pr[qc]:|Psg:)','^\-(Pr[qc]:|Psg:)'
		);
	} else {
		@pacs = $this -> getSection (
			'^\+Pr[qc]:','^\-Pr[qc]:'
		);
	}
	push(@packages, @pacs);

	@packages = sort @packages;
	my $prev = '__none__';
	return grep($_ ne $prev && (($prev) = $_), @packages);
}

1;
