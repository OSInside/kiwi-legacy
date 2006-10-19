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
my %cache;
my %patdone;

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
		foreach my $url (@urllist) {
			$result .= downloadPattern ( $url,$pat );
		}
		if (! $result) {
			return ();
		}
		$content .= $result;
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
	$kiwi -> info ("$infomessage: $pattern");
	if ($url =~ /^\//) {
		my $file = bsd_glob ("$url//suse/setup/descr/$pattern-*.pat");
		if (! open (FD,$file)) {
			$kiwi -> failed ();
			return undef;
		}
		local $/; $content = <FD>; close FD;
	} else {
		my $browser  = LWP::UserAgent->new;
		my $location = $url."/suse/setup/descr";
		my $request  = HTTP::Request->new (GET => $location);
		my $response = $browser  -> request ( $request );
		my $title    = $response -> title ();
		my $content  = $response -> content ();
		if ((! defined $title) || ($title =~ /not found/i)) {
			$kiwi -> failed ();
			return undef;
		}
		if ($content !~ /\"($pattern-.*\.pat)\"/) {
			$kiwi -> failed ();
			return undef;
		}
		$location = $location."/".$1;
		$request  = HTTP::Request->new (GET => $location);
		$response = $browser  -> request ( $request );
		$content  = $response -> content ();
	}
	$kiwi -> done();
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
				$result{$line} = $line;
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
	my @reqs = getSection (
		'^\+Req:','^\-Req:',\@patdata
	);
	foreach my $rpattern (@reqs) {
		if ($rpattern eq "basesystem") {
			$rpattern = "base";
		}
		if (defined $patdone{$rpattern}) {
			next;
		}
		$infomessage = "--> Including required pattern";
		my @patdata = getPatternContents ([$rpattern]);
		$infomessage = $infodefault;
		if (! @patdata) {
			$kiwi -> error  ("Couldn't find required pattern: $rpattern");
			$kiwi -> failed ();
			return undef;
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
	my @pacs = getSection ('^\+Prq:','^\-Prq:');
	return @pacs;
}

1;
