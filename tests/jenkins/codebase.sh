#!/bin/bash
# runner for unit / validation and critic tests
#
# Required: prepare.sh
#
topic=$1
su - jenkins -c "cd /home/jenkins/kiwi/kiwi && make $topic"
