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
my $kiwi;
my @data;
my @urllist;
my $pattern;

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
	$pattern = shift;
	if (! defined $pattern) {
		$kiwi -> error ("Invalid pattern name");
		$kiwi -> failed ();
		return undef;
	}
	my $urlref = shift;
	if (! defined $urlref) {
		$kiwi -> error ("No URL list for pattern search");
		$kiwi -> failed ();
		return undef;
	}
	@urllist = @{$urlref};
	my @patdata = getPatternContents ($pattern);
	if (! @patdata) {
		$kiwi -> error  ("Couldn't find pattern: $pattern");
		$kiwi -> failed ();
		return undef;
	}
	push ( @data,@patdata );
	return $this;
}

#==========================================
# getPatternContents
#------------------------------------------
sub getPatternContents {
	my $pattern = shift;
	my $content;
	foreach my $url (@urllist) {
		$content .= downloadPattern ( $url,$pattern );
	}
	if (! $content) {
		return ();
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
	if ($url =~ /^\//) {
		my $file = bsd_glob ("$url//suse/setup/descr/$pattern-*.pat");
		if (! open (FD,$file)) {
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
			return undef;
		}
		if ($content !~ /\"($pattern-.*\.pat)\"/) {
			return undef;
		}
		$location = $location."/".$1;
		$request  = HTTP::Request->new (GET => $location);
		$response = $browser  -> request ( $request );
		$content  = $response -> content ();
	}
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
	my $pattern = shift;
	my @patdata = getPatternContents ($pattern);
	if (! @patdata) {
		return undef;
	}
	my @reqs = getSection (
		'^\+Req:','^\-Req:',\@patdata
	);
	foreach my $rpattern (@reqs) {
		if ($rpattern eq "basesystem") {
			$rpattern = "base";
		}
		$kiwi -> info ("Pattern $pattern requires: $rpattern");
		my @patdata = getPatternContents ($rpattern);
		if (! @patdata) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't find required pattern: $rpattern");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done ();
		push ( @data,@patdata );
		getRequiredPatterns ($rpattern);
	}
	return $pattern;
}

#==========================================
# getPackages
#------------------------------------------
sub getPackages {
	my $this = shift;
	getRequiredPatterns ($pattern);
	my @pacs = getSection ('^\+Pr[qc]:','^\-Pr[qc]:');
	return @pacs;
}

1;
