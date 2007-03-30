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
# Private
#------------------------------------------
my $infodefault = "Including pattern";
my $infomessage = $infodefault;

#==========================================
# Private
#------------------------------------------
my $kiwi;
my @data;
my @urllist;
my @pattern;
my $pattype;
my %cache;
my %patdone;
my $arch;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create new KIWIPattern object which is used to read
	# the given pattern data stream and provide all information
	# via member methods
	# ---
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi   = shift;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	my $pattref = shift;
	if (! defined $pattref) {
		$kiwi -> error ("Invalid pattern name");
		$kiwi -> failed ();
		return undef;
	}
	@pattern = @{$pattref};
	my $urlref = shift;
	if (! defined $urlref) {
		$kiwi -> error ("No URL list for pattern search");
		$kiwi -> failed ();
		return undef;
	}
	$pattype = shift;
	if (! defined $pattype) {
		$kiwi -> error ("No pattern type specified");
		$kiwi -> failed ();
		return undef;
	}
	$arch = qx (arch); chomp $arch;
	if ($arch =~ /^i.86/) {
		$arch = 'i*86';
	}
	@urllist = @{$urlref};
	my @patdata = getPatternContents (\@pattern);
	if (! @patdata) {
		return undef;
	}
	push ( @data,@patdata );
	return $this;
}

#==========================================
# getPatternContents
#------------------------------------------
sub getPatternContents {
	my $pattref = shift;
	my @pattern = @{$pattref};
	my $content;
	foreach my $pat (@pattern) {
		my $result;
		my $printinfo = 0;
		if (! defined $cache{$pat}) {
			$printinfo = 1;
		}
		if ($printinfo) {
			$kiwi -> info ("$infomessage: $pat");
		}
		foreach my $url (@urllist) {
			$result .= downloadPattern ( $url,$pat );
		}
		if (! $result) {
			if ($printinfo) {
				$kiwi -> failed ();
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
	my $url     = shift;
	my $pattern = shift;
	my $content;
	if (defined $cache{$pattern}) {
		return $cache{$pattern};
	}
	if ($url =~ /^\//) {
		my $path = "$url//suse/setup/descr";
		my $file = bsd_glob ("$path/$pattern-*.$arch.pat");
		if (! defined $file) {
			$file = bsd_glob ("$path/$pattern-*.pat");
		}
		if (! open (FD,$file)) {
			return undef;
		}
		local $/; $content = <FD>; close FD;
	} else {
		my $urlHandler  = new KIWIURL ($kiwi);
		my $publics_url = $url;
		my $highlvl_url = $urlHandler -> openSUSEpath ($publics_url);
		if (defined $highlvl_url) {
			$publics_url = $highlvl_url;
		}
		my $browser  = LWP::UserAgent->new;
		my $location = $publics_url."/suse/setup/descr";
		my $request  = HTTP::Request->new (GET => $location);
		my $response = $browser  -> request ( $request );
		my $title    = $response -> title ();
		$content  = $response -> content ();
		if ((! defined $title) || ($title =~ /not found/i)) {
			return undef;
		}
		if ($content !~ /\"($pattern-.*$arch\.pat)\"/) {
			return undef;
		}
		$location = $location."/".$1;
		$request  = HTTP::Request->new (GET => $location);
		$response = $browser  -> request ( $request );
		$content  = $response -> content ();
	}
	$cache{$pattern} = $content;
	return $content;
}

#==========================================
# getSection
#------------------------------------------
sub getSection {
	my $begin  = shift;
	my $end    = shift;
	my $patdata= shift;
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
	my $pattref = shift;
	my @pattern = @{$pattref};
	my @patdata = getPatternContents (\@pattern);
	my @reqs;
	if ($pattype eq "onlyRequired") {
		@reqs = getSection (
			'^\+Req:','^\-Req:',\@patdata
		);
	} else {
		@reqs = getSection (
			'^\+Re[qc]:','^\-Re[qc]:',\@patdata
		);
	}
	push (@reqs,"base");
	push (@reqs,"desktop-base");
	foreach my $rpattern (@reqs) {
		if (defined $patdone{$rpattern}) {
			next;
		}
		$infomessage = "--> Including required pattern";
		my @patdata = getPatternContents ([$rpattern]);
		$infomessage = $infodefault;
		if (! @patdata) {
			$kiwi -> warning ("Couldn't find required pattern: $rpattern");
			$kiwi -> skipped ();
			$patdone{$rpattern} = $rpattern;
			next;
		}
		push ( @data,@patdata );
		$patdone{$rpattern} = $rpattern;
		getRequiredPatterns ([$rpattern]);
	}
	return @reqs;
}

#==========================================
# getPackages
#------------------------------------------
sub getPackages {
	my $this = shift;
	my %result;
	my @reqs = getRequiredPatterns (\@pattern);
	my @pacs;
	if ($pattype eq "onlyRequired") {
		@pacs = getSection ('^\+Prq:','^\-Prq:');
	} else {
		@pacs = getSection ('^\+Pr[qc]:','^\-Pr[qc]:');
	}
	return @pacs;
}

1;
