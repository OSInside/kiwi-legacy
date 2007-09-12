# /.../
# Copyright (c) 2006 SUSE LINUX Products GmbH. All rights reserved.
# Author: Marcus Schaefer <sax@suse.de>, 2006
#
# Makefile for OpenSuSE - KIWI Image System
# ---
buildroot = /
syslinux  = /usr/share/syslinux

export

#============================================
# Prefixs...
#--------------------------------------------
kiwi_prefix = ${buildroot}/usr/share/kiwi
tftp_prefix = ${buildroot}/srv/tftpboot
doc_prefix  = ${buildroot}/usr/share/doc/packages
man_prefix  = ${buildroot}/usr/share/man

#============================================
# Variables... 
#--------------------------------------------
KIWIBINVZ   = ${buildroot}/usr/sbin
KIWIMODVZ   = ${kiwi_prefix}/modules
TOOLSVZ     = ${kiwi_prefix}/tools
KIWIIMAGE   = ${kiwi_prefix}/image
TFTPKIWI    = ${tftp_prefix}/KIWI
TFTPBOOT    = ${tftp_prefix}/
TFTPBOOTBOOT= ${tftp_prefix}/boot
TFTPBOOTCONF= ${tftp_prefix}/pxelinux.cfg
TFTPUPLOAD  = ${tftp_prefix}/upload
TFTPIMAGE   = ${tftp_prefix}/image
PACKDOCVZ   = ${doc_prefix}/kiwi

all:
	#============================================
	# Check XSD Scheme...
	#--------------------------------------------
	find -name config.xml | xargs xmllint -noout -schema modules/KIWIScheme.xsd 

	#============================================
	# resolve relative links
	#--------------------------------------------
	# ./.links

install:
	#============================================
	# Install base directories
	#--------------------------------------------
	install -d -m 755 ${KIWIBINVZ} ${KIWIMODVZ} ${TOOLSVZ} ${KIWIIMAGE}
	install -d -m 755 ${TFTPKIWI} ${TFTPBOOT} ${TFTPBOOTCONF} ${TFTPIMAGE}
	install -d -m 755 ${TFTPBOOTBOOT}
	install -d -m 755 ${TFTPUPLOAD}
	install -d -m 755 ${PACKDOCVZ}

	#============================================
	# install .revision file
	#--------------------------------------------
	install -m 644 ./.revision ${kiwi_prefix}

	#============================================
	# kiwi system draft
	#--------------------------------------------
	install -m 644 ./doc/kiwi.pdf  ${PACKDOCVZ}

	#============================================
	# Install kiwi tools
	#--------------------------------------------
	install -m 755 ./tools/helper/* ${TOOLSVZ}

	#============================================
	# Install KIWI base and modules
	#--------------------------------------------
	install -m 755 ./kiwi.pl       ${KIWIBINVZ}/kiwi
	install -m 644 ./modules/*     ${KIWIMODVZ}

	#============================================
	# Install TFTP netboot structure and loader
	#--------------------------------------------
	install -m 755 ${syslinux}/pxelinux.0     ${TFTPBOOT}/pxelinux.0
	test -f ${syslinux}/mboot.c32 && \
		install -m 755 ${syslinux}/mboot.c32  ${TFTPBOOT}/mboot.c32 || /bin/true
	install -m 644 pxeboot/README             ${TFTPBOOT}
	install -m 644 pxeboot/README.prebuild    ${TFTPBOOT}
	#install -m 755 pxeboot/pxelinux.0.config ${TFTPBOOTCONF}/default

	#============================================
	# Install image descriptions
	#--------------------------------------------
	cp -a system/boot/* ${KIWIIMAGE}
