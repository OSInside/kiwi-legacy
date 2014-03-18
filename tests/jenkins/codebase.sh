#!/bin/bash
# runner for unit / validation and critic tests
#
# Required:
# --> prepare.sh
#
# Put the following into the shell execution layer at jenkins
#
# /home/jenkins/kiwi/kiwi/tests/jenkins/codebase.sh <topic-name>
#
topic=$1
su - jenkins -c "cd /home/jenkins/kiwi/kiwi && make $topic"
