#!/bin/bash
#
# Clean up any artifacts that may be left over from a previous test run
# This script is part of the Kiwi test framework
#

echo "Cleaning up artifacts"

for i in `find . -name "*.converted.xml"`;do \
    rm $i ;\
done

grep kiwiDevTests /proc/mounts >& /dev/null
if [ $? -ne 0 ]; then
    rm -rf /tmp/kiwiDevTests
else
    echo "Mounted directories detected in /tmp/kiwiDevTests not removing"
    echo "directory. Tests might fail. Manualy umount and re-run tests."
fi

