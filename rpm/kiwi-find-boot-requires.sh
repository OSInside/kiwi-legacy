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

DONE=""

for os in $oses; do
  file="kiwi/system/boot/$architecture/$boottype/$os/config.xml"
  [ -e "$file" ] || continue

  # my professional enterprise ready xml parser:
  packs=`sed -n 's,.*package name="\([^"]*\)".*,\1,p' "$file"`
  for p in $packs; do
    echo -n "$p "
  done
  
  DONE="1"
done

[ -z "$DONE" ] && echo "DUMMY_TO_AVOID_RPM_BREAKAGE"

