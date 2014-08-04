#!/bin/bash
# prepare the jenkins worker to checkout kiwi and install all
# required packages to run the code tests. Put the following
# into the shell execution layer at jenkins
#
# cd /tmp && rm -f /tmp/prepare.sh* && wget \
#    https://raw.github.com/openSUSE/kiwi/master/tests/jenkins/prepare.sh && \
#    bash /tmp/prepare.sh
#
# Add jenkins user for running code tests
if ! grep -q jenkins /etc/passwd;then
    if ! useradd -m jenkins;then
        exit 1
    fi
fi

# clone or update kiwi git
if [ ! -d /home/jenkins/kiwi ];then
    kiwi=git://github.com/openSUSE/kiwi.git
    if ! su - jenkins -c \
        "mkdir -p /home/jenkins/kiwi";then
        exit 1
    fi
    if ! su - jenkins -c \
        "cd /home/jenkins/kiwi && git clone $kiwi";then
        exit 1
    fi
else
    if ! su - jenkins -c \
        "cd /home/jenkins/kiwi/kiwi && git checkout . && git pull";then
        exit 1
    fi
fi

# install required packages
spec=/home/jenkins/kiwi/kiwi/rpm/kiwi.spec
packages="grub grub2 genisoimage cdrkit-cdrtools-compat squashfs osc yum trang"
if ! zypper -n install --no-recommends $packages;then
    exit 1
fi
packages=$(grep ^Requires $spec | grep perl- | cut -f2 -d:)
if ! zypper -n install $packages;then
    exit 1
fi
packages="perl-Perl-Critic"
if ! zypper -n install $packages;then
    exit 1
fi

