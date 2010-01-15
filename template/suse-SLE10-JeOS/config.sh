#!/bin/bash
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#======================================
# Activate services
#--------------------------------------
suseActivateDefaultServices
suseRemoveService gpm
suseRemoveService sshd
suseRemoveService nfs

#======================================
# Add missing gpg keys to rpm
#--------------------------------------
suseImportBuildKey

#======================================
# fix arch on x86_64 in /var/lib/zypp/db/products/*
#--------------------------------------
if [ `uname -m` == 'x86_64' ];then
	sed -i -e 's;<arch>i686</arch>;<arch>x86_64</arch>;' \
		/var/lib/zypp/db/products/*
fi

#==========================================
# remove unneeded packages
#------------------------------------------
suseRemovePackagesMarkedForDeletion

#======================================
# Remove all documentation
#--------------------------------------
baseStripDocs

#======================================
# SuSEconfig
#--------------------------------------
suseConfig

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
