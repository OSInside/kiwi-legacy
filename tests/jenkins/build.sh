#!/bin/bash
# runner for building oem images. The oem image covers many
# image building parts including creation of install media.
# Thus this image type was choosen for testing
#
# Required:
# --> prepare.sh
#
# Put the following into the shell execution layer at jenkins
#
# /home/jenkins/kiwi/kiwi/tests/jenkins/build.sh <jeos-name>
#
# possible jeos-name: see the result of 'kiwi -l'
#
jeos=$1
shift
kiwi --build $jeos -d /tmp/mytest --type oem --logfile terminal $@
