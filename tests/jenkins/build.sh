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
arch=$2
if [ -z "$arch" ];then
    arch=x86_64
fi

/home/jenkins/kiwi/kiwi/kiwi \
    --build /home/jenkins/kiwi/kiwi/template/$arch/$jeos \
    --type oem --logfile terminal $@
