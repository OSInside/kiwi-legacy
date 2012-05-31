#!/bin/bash

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
	[ -e "$file" ] || echo "ERROR_NO_BOOT_CONFIG_FILE_FOUND"

	# my professional enterprise ready xml parser:
	while read line; do
		l=($line)
		package=${l[0]}
		arch=${l[1]}
		if [ -z "$arch" -o "$arch" == "$architecture" ]; then
			echo -n "$package "
			unset MISSING
		fi
		done < <( sed '/<packages type="delete">/,/<\/packages>/d' "$file" | sed -En 's,.*package name="([^"]*)"( arch="([^"]*)")?.*,\1 \3,p' )
done

[ -z "$MISSING" ] || echo "ERROR_NO_DEPENDENCIES_FOUND"

#cleanup
rm -rf kiwi
