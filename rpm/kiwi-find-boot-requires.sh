#!/bin/bash
# Author: Adrian Schröter <adrian@suse.com>
#
# This script creates the required package list from the kiwi
# boot image descriptions
#

sourcearchive=$1
shift
boottype=$1
shift
architecture=$1
shift
oses="$@"

# extract files
tar xfj $sourcearchive kiwi/system/boot/ >&/dev/null

declare -i MISSING
MISSING="1"
for os in $oses; do
    file="kiwi/system/boot/$architecture/$boottype/$os/config.xml"
    if [ ! -e "$file" ];then
        echo "ERROR_NO_${architecture}_${boottype}_${os}_BOOT_CONFIG_FILE_FOUND"
        break
    fi

    # my professional enterprise ready xml parser:
    while read line; do
        l=($line)
        package=${l[0]}
        arch=${l[1]}
        if [ -z "$arch" -o "$arch" == "$architecture" ]; then
            echo -n "$package "
            unset MISSING
        fi
        done < <( sed '/<packages type="delete">/,/<\/packages>/d' "$file" | perl -e 'while (<STDIN>) { if ($_ =~ /.*package name="([^"]*)"( arch="([^"]*)")?.*/ ) { print $1." ".$3."\n"; }; }' 
 )
done

[ -z "$MISSING" ] || echo "ERROR_NO_DEPENDENCIES_FOUND"

#cleanup
rm -rf kiwi
