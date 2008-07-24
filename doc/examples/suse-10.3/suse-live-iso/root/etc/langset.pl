#!/usr/bin/perl

INIT {
	$Lang=""; $Terr="";
	open(CMDL, "</proc/cmdline" );
	while (<CMDL>) {
		if (m,lang=([a-z][a-z])([_@][\w@]+)?,) {
			$Lang=$1;
			$Terr=$2;
			last;
		}
	}
	close CMDL;
	if (open(CONF, "</etc/langset/$Lang$Terr" ) ||
	    open(CONF, "</etc/langset/$Lang" )) {
	while (<CONF>) {
		m,RC_LANG=(.*), && ($RcLang = $1) ;
		m,KEYTABLE=(.*), && ($Keyt = $1) ;
		m,OOo_Country=(.*), && ($OOoC = $1) ;
	}
	close CONF;
        }
}

s,RC_LANG=".*,RC_LANG="$RcLang", if $RcLang ne "";

s,KEYTABLE=".*,KEYTABLE="$Keyt", if $Keyt ne "";

s,United States of America,$OOoC,;

END {
	print "$Lang\n";
	$Lang ne "";
}
