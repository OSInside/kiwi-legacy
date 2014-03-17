#!/bin/bash
# prepare the jenkins worker to checkout kiwi and install all
# required packages to run the code tests. Put the following
# into the shell execution layer at jenkins
#
# cd /tmp && wget \
#    https://raw.github.com/openSUSE/kiwi/master/tests/jenkins/prepare.sh
# /tmp/prepare.sh
#
# Add jenkins user for running code tests
grep -q jenkins /etc/passwd || useradd -m jenkins

# clone or update kiwi git
if [ ! -d /home/jenkins/kiwi ];then
	kiwi=git://github.com/openSUSE/kiwi.git
	su - jenkins -c "mkdir -p /home/jenkins/kiwi"
	su - jenkins -c "cd /home/jenkins/kiwi && git clone $kiwi"
else
	su - jenkins -c "cd /home/jenkins/kiwi && git pull"
fi

# install required packages
packages="genisoimage cdrkit-cdrtools-compat"
zypper -n install --no-recommends $packages
packages=$(grep ^Requires kiwi/rpm/kiwi.spec | grep perl- | cut -f2 -d:)
zypper -n install $packages
packages="perl-Perl-Critic"
zypper -n install $packages
