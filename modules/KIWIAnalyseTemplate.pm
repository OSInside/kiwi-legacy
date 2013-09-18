#================
# FILE          : KIWIAnalyseTemplate.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide methods for
#               : creating basic image template data
#               :
#               :
#               :
# STATUS        : Development
#----------------
package KIWIAnalyseTemplate;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use Carp qw (cluck);
use XML::LibXML;
use Data::Dumper;
use FileHandle;
use File::Find;
use File::stat;
use File::Basename;
use File::Path;
use File::Copy;
use Storable;
use File::Spec;
use Fcntl ':mode';
use Cwd qw (abs_path cwd);
use JSON;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILog;
use KIWIQX qw (qxx);
use KIWIXML;
use KIWIXMLDescriptionData;
use KIWIXMLPreferenceData;
use KIWIXMLTypeData;
use KIWIXMLOEMConfigData;
use KIWIXMLRepositoryData;
use KIWIXMLPackageData;
use KIWIXMLPackageCollectData;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIAnalyseTemplate object which is used to
	# gather information on the running system
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
	my $dest    = shift;
	my $source  = shift;
	my $product = shift;
	my $patterns= shift;
	my $packages= shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $kiwi   = KIWILog -> instance();
	my $global = KIWIGlobals -> instance();
	if (! defined $source) {
		$kiwi -> error  ("KIWIAnalyseTemplate: No sourceref specified");
		$kiwi -> failed ();
		return;
	}
	if (! defined $product) {
		$kiwi -> error  ("KIWIAnalyseTemplate: No product name specified");
		$kiwi -> failed ();
		return;
	}
	if ((! defined $dest) || (! -d $dest)) {
		$kiwi -> error  (
			"KIWIAnalyseTemplate: Couldn't find destination dir: $dest"
		);
		$kiwi -> failed ();
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{gdata}   = $global -> getKiwiConfig();
	$this->{kiwi}    = $kiwi;
	$this->{dest}    = $dest;
	$this->{source}  = $source;
	$this->{product} = $product;
	$this->{packages}= $packages;
	$this->{patterns}= $patterns;
	return $this;
}

#==========================================
# writeKIWIXMLConfiguration
#------------------------------------------
sub writeKIWIXMLConfiguration {
	# ...
	# write kiwi config.xml description
	# ---
	my $this    = shift;
	my $dest    = $this->{dest};
	my $kiwi    = $this->{kiwi};
	my $product = $this->{product};
	my $pats    = $this->{patterns};
	my $pacs    = $this->{packages};
	my %osc     = %{$this->{source}};
	#==========================================
	# read template
	#------------------------------------------
	my $cmdL = KIWICommandLine -> new();
	my $xml  = KIWIXML -> new (
		$this->{gdata}->{KAnalyseTPL}, undef, undef, $cmdL, undef
	);
	if (! $xml) {
		return;
	}
	#==========================================
	# KIWIXMLDescriptionData
	#------------------------------------------
	my $xml_desc = $xml -> getDescriptionInfo();
	$xml_desc -> setSpecificationDescript ($product);
	#==========================================
	# KIWIXMLPreferenceData
	#------------------------------------------
	# getPreferences returns a new KIWIXMLPreferenceData object
	# containing combined information. Thus it's required to set
	# the changed object back into the KIWIXML space
	# ---
	my $xml_pref = $xml -> getPreferences();
	$xml_pref -> setBootLoaderTheme ('openSUSE');
	$xml_pref -> setBootSplashTheme ('openSUSE');
	$xml_pref -> setLocale ('en_US');
	$xml_pref -> setKeymap ('us.map.gz');
	$xml_pref -> setTimezone ('Europe/Berlin');
	$xml -> setPreferences ($xml_pref);
	#==========================================
	# KIWIXMLTypeData
	#------------------------------------------
	my $xml_type = $xml -> getImageType();
	$xml_type -> setBootImageDescript ('oemboot/'.$product);
	#==========================================
	# KIWIXMLOEMConfigData
	#------------------------------------------
	my $xml_oemc = $xml -> getOEMConfig();
	$xml_oemc -> setSwap ('true');
	#==========================================
	# KIWIXMLRepositoryData
	#------------------------------------------
	my @xml_repo = ();
	foreach my $source (sort keys %{$osc{$product}} ) {
		my $type = $osc{$product}{$source}{type};
		my $alias= $osc{$product}{$source}{alias};
		my $prio = $osc{$product}{$source}{prio};
		my $url  = $osc{$product}{$source}{src};
		my %repo_data = (
			'path'             => $url,
			'type'             => $type,
			'alias'            => $alias,
			'priority'         => $prio
		);
		my $r = KIWIXMLRepositoryData -> new (\%repo_data);
		push @xml_repo, $r;
	}
	$xml -> addRepositories (\@xml_repo, 'default');
	#==========================================
	# KIWIXMLPackageData
	#------------------------------------------
	my @xml_pack = ();
	if (defined $pacs) {
		foreach my $package (sort @{$pacs}) {
			my %pack_data = (
				'name' => $package
			);
			my $p = KIWIXMLPackageData -> new (\%pack_data);
			push @xml_pack, $p;
		}
	}
	$xml -> addBootstrapPackages (\@xml_pack);
	#==========================================
	# KIWIXMLPackageCollectData
	#------------------------------------------
	my @xml_patt = ();
	if (defined $pats) {
		# FIXME: I don't have a solution for the problem below
		# /.../
		# the migration put a set of packages to matching patterns
		# I found out that it might be a problem if a pattern provides
		# more than one package for the same purpose. In that case
		# the preferred package is installed but this might not be
		# the package which is currently used on the system. A good
		# example here is postfix vs. sendmail. kiwi will find
		# postfix to belong to a pattern. in fact it's provided by
		# the pattern mail_server. This pattern provides postfix
		# and sendmail. If only mail_server as pattern is requested,
		# sendmail will be selected and not postfix
		# ---
		foreach my $pattern (sort @{$pats}) {
			$pattern =~ s/^pattern://;
			my %patt_data = (
				'name'         => $pattern
			);
			my $p = KIWIXMLPackageCollectData -> new(\%patt_data);
			push @xml_patt, $p;
		}
	}
	$xml -> addPackageCollections (\@xml_patt);
	#==========================================
	# write XML description
	#------------------------------------------
	my $file = "$dest/$this->{gdata}->{ConfigName}";
	if (! $xml -> writeXML ($file)) {
		return;
	}
	my $temp = "/tmp/pretty.xml";
	my $data = qxx ("xsltproc -o $temp $this->{gdata}->{Pretty} $file");
	my $code = $? >> 8;
	if ($code != 0) {
		return;
	}
	qxx ("mv $temp $file");
	return $this;
}

#==========================================
# writeKIWIScripts
#------------------------------------------
sub writeKIWIScripts {
	# ...
	# Create config.sh script:
	# 1) add repos to become part of the image
	# 2) add services to run in the image
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $dest = $this->{dest};
	my %osc  = %{$this->{source}};
	my $product = $this->{product};
	#==========================================
	# create config script
	#------------------------------------------
	my $FD = FileHandle -> new();
	if (! $FD -> open (">$dest/config.sh")) {
		return;
	}
	print $FD '#!/bin/bash'."\n";
	print $FD 'test -f /.kconfig && . /.kconfig'."\n";
	print $FD 'test -f /.profile && . /.profile'."\n";
	print $FD 'echo "Configure image: [$kiwi_iname]..."'."\n";
	print $FD 'suseSetupProduct'."\n";
	#==========================================
	# Repos...
	#------------------------------------------
	foreach my $source (sort keys %{$osc{$product}} ) {
		my $alias= $osc{$product}{$source}{alias};
		my $url  = $osc{$product}{$source}{src};
		my $flag = $osc{$product}{$source}{flag};
		if ($flag ne "remote") {
			next;
		}
		# FIXME: do this packagemanager related
		print $FD "zypper ar \\\n\t\"".$url."\" \\\n\t\"".$alias."\"\n";
	}
	#==========================================
	# Product repo...
	#------------------------------------------
	my $repoProduct = "/etc/products.d/openSUSE.prod";
	if (-e $repoProduct) {
		my $PXML = FileHandle -> new();
		if (! $PXML -> open ("cat $repoProduct|")) {
			$kiwi -> failed ();
			$kiwi -> warning ("--> Failed to open product file $repoProduct");
			$kiwi -> skipped ();
		} else {
			binmode $PXML;
			my $pxml = XML::LibXML -> new();
			my $tree = $pxml -> parse_fh ( $PXML );
			my $urls = $tree -> getElementsByTagName ("product")
				-> get_node(1) -> getElementsByTagName ("urls")
				-> get_node(1) -> getElementsByTagName ("url");
			for (my $i=1;$i<= $urls->size();$i++) {
				my $node = $urls -> get_node($i);
				my $name = $node -> getAttribute ("name");
				if ($name eq "repository") {
					my $url   = $node -> textContent();
					my $alias = "openSUSE";
					my $alreadyThere = 0;
					$url =~ s/\/$//;
					foreach my $source (sort keys %{$osc{$product}} ) {
						my $curl = $osc{$product}{$source}{src};
						$curl =~ s/\/$//;
						if ($curl eq $url) {
							$alreadyThere = 1; last;
						}
					}
					if (! $alreadyThere) {
						# FIXME: do this packagemanager related
						print $FD "zypper ar \\\n\t\"";
						print $FD $url."\" \\\n\t\"".$alias."\"\n";
					}
				}
			}
			$PXML -> close();
		}
	}
	#==========================================
	# Systemd services
	#------------------------------------------
	my $sctl = FileHandle -> new();
	if ($sctl -> open ("systemctl list-unit-files|")) {
		while (my $line = <$sctl>) {
			if ($line =~ /^(.*)\.service.*enabled/) {
				my $service = $1;
				print $FD "suseInsertService $service\n";
			}
		}
		$sctl -> close();
	}
	print $FD 'suseConfig'."\n";
	print $FD 'baseCleanMount'."\n";
	print $FD 'exit 0'."\n";
	$FD -> close();
	chmod 0755, "$dest/config.sh";
	return $this;
}

#==========================================
# cloneLinuxConfigurationFiles
#------------------------------------------
sub cloneLinuxConfigurationFiles {
	# ...
	# use augeas to export the current config file values
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $dest = $this->{dest};
	$kiwi -> info ("Creating augeas system configuration export...");
	my $locator = KIWILocator -> instance();
	my $augtool = $locator -> getExecPath('augtool');
	if ($augtool) {
		qxx ("$augtool dump-xml /files/* > $dest/config-augeas.xml");
		$kiwi -> done();
	} else {
		$kiwi -> skipped ();
		$kiwi -> info ("Required augtool command not found");
		$kiwi -> skipped ();
	}
	return $this;
}

1;
