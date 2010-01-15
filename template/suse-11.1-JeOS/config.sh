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
suseRemoveService sshd
suseRemoveService gpm
suseRemoveService nfs

#======================================
# Setup baseproduct link
#--------------------------------------
suseSetupProduct

#======================================
# Add missing gpg keys to rpm
#--------------------------------------
suseImportBuildKey
    
#==========================================
# remove unneeded packages
#------------------------------------------
suseRemovePackagesMarkedForDeletion

#======================================
# Remove all documentation
#--------------------------------------
baseStripDocs

#======================================
# only basic version of vim is
# installed; no syntax highlighting
#--------------------------------------
sed -i -e's/^syntax on/" syntax on/' /etc/vimrc

#======================================
# SuSEconfig
#--------------------------------------
suseConfig

#======================================
# Add 11.1 repo
#--------------------------------------
baseRepo="http://download.opensuse.org/distribution/11.1/repo/oss"
baseName="suse-11.1"
zypper ar $baseRepo $baseName

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
