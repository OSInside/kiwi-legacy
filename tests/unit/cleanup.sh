#!/bin/sh
# cleanup
#
# Clean up any artifacts that may be left over from a previous test run
# 
# This script is part of the Kiwi test framework

echo "Cleaning up artifacts"

for i in `find . -name "*.converted.xml"`;do \
    rm $i ;\
done

rm -rf /tmp/kiwiDevTests
