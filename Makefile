# /.../
# Copyright (c) 2006 SUSE LINUX Products GmbH. All rights reserved.
# Author: Marcus Schaefer <ms@suse.de>, 2006
#
# Makefile for OpenSuSE - KIWI Image System
# ---
arch      = `uname -m | grep -q ^i[3-6] && echo ix86 || uname -m`
buildroot = /
syslinux  = /usr/share/syslinux
bindlib   = lib

XML_CATALOG_FILES = .catalog.xml

export

#============================================
# Prefixs...
#--------------------------------------------
bin_prefix  = ${buildroot}/usr/bin
init_prefix = ${buildroot}/etc/init.d
kiwi_prefix = ${buildroot}/usr/share/kiwi
tftp_prefix = ${buildroot}/srv/tftpboot
doc_prefix  = ${buildroot}/usr/share/doc/packages
man_prefix  = ${buildroot}/usr/share/man

#============================================
# Variables... 
#--------------------------------------------
KIWIBINVZ   = ${buildroot}/usr/sbin
KIWIMODVZ   = ${kiwi_prefix}/modules
KIWITSTVZ   = ${kiwi_prefix}/tests
KIWIXSLVZ   = ${kiwi_prefix}/xsl
TOOLSVZ     = ${bin_prefix}
INITVZ      = ${init_prefix}
KIWIIMAGE   = ${kiwi_prefix}/image
KIWIREPO    = ${kiwi_prefix}/repo
TFTPKIWI    = ${tftp_prefix}/KIWI
TFTPBOOT    = ${tftp_prefix}/
TFTPBOOTBOOT= ${tftp_prefix}/boot
TFTPBOOTCONF= ${tftp_prefix}/pxelinux.cfg
TFTPUPLOAD  = ${tftp_prefix}/upload
TFTPIMAGE   = ${tftp_prefix}/image
PACKDOCVZ   = ${doc_prefix}/kiwi
MANVZ       = ${man_prefix}/man1

all: modules/KIWIScheme.rng modules/KIWISchemeTest.rng
	#============================================
	# create checksum files for boot images...
	#--------------------------------------------
	(cd system/boot/${arch} && ./.md5)
	(cd system/boot/${arch} && \
		find -type f | grep -v -E ".svn|.test|.md5" |\
		xargs chmod u-w &>/dev/null || true)

	#============================================
	# build tools
	#--------------------------------------------
	${MAKE} -C tools all

install:
	#============================================
	# Install base directories
	#--------------------------------------------
	install -d -m 755 ${KIWIBINVZ} ${KIWIMODVZ} ${KIWIIMAGE} ${KIWIXSLVZ}
	install -d -m 755 ${TFTPKIWI} ${TFTPBOOT} ${TFTPBOOTCONF} ${TFTPIMAGE}
	install -d -m 755 ${TFTPBOOTBOOT} ${KIWITSTVZ}
	install -d -m 755 ${TFTPUPLOAD} ${KIWIREPO}
	install -d -m 755 ${PACKDOCVZ} ${MANVZ}
	install -d -m 755 ${TOOLSVZ} ${INITVZ}

	#============================================
	# install .revision file
	#--------------------------------------------
	test -f ./.revision || ./.version > .revision
	install -m 644 ./.revision ${kiwi_prefix}

	#============================================
	# kiwi documentation and examples
	#--------------------------------------------
	cp -a doc/examples/ ${PACKDOCVZ}
	cp -a doc/schema/   ${PACKDOCVZ}
	cp -a doc/*.pdf     ${PACKDOCVZ}
	cp -a doc/COPYING   ${PACKDOCVZ}
	test -e doc/ChangeLog && cp -a doc/ChangeLog ${PACKDOCVZ} || true

	#============================================
	# kiwi manual pages
	#--------------------------------------------
	for i in `ls -1 ./doc/kiwi-man/*.1`;do \
		install -m 644 $$i ${MANVZ} ;\
	done

	#============================================
	# Install kiwi tools
	#--------------------------------------------
	${MAKE} -C tools TOOLSVZ=${TOOLSVZ} INITVZ=${INITVZ} install

	#============================================
	# Install KIWI base and modules
	#--------------------------------------------
	install -m 755 ./kiwi.pl       ${KIWIBINVZ}/kiwi
	install -m 644 ./xsl/*         ${KIWIXSLVZ}
	for i in `find modules -type f | grep -v -E ".svn|.test"`;do \
		install -m 644 $$i ${KIWIMODVZ} ;\
	done

	#============================================
	# Install KIWI tests
	#--------------------------------------------
	cp -a tests/* ${KIWITSTVZ}

	#============================================
	# Install TFTP netboot structure and loader
	#--------------------------------------------
	test -f ${syslinux}/pxelinux.0 && \
		install -m 755 ${syslinux}/pxelinux.0 ${TFTPBOOT}/pxelinux.0|| /bin/true
	test -f ${syslinux}/mboot.c32 && \
		install -m 755 ${syslinux}/mboot.c32  ${TFTPBOOT}/mboot.c32 || /bin/true
	install -m 644 pxeboot/README             ${TFTPBOOT}
	install -m 644 pxeboot/README.prebuild    ${TFTPBOOT}
	#install -m 755 pxeboot/pxelinux.0.config ${TFTPBOOTCONF}/default

	#============================================
	# Install boot image descriptions
	#--------------------------------------------
	cp -a system/boot/${arch}/* ${KIWIIMAGE} &>/dev/null || true

	#============================================
	# Install system image template descriptions
	#--------------------------------------------
	cp -a template/* ${KIWIIMAGE}

	#============================================
	# Install kiwi repo
	#--------------------------------------------
	cp -a system/suse-repo ${KIWIREPO}

modules/KIWIScheme.rng: modules/KIWIScheme.rnc
	#============================================
	# Convert RNC -> RNG...
	#--------------------------------------------
	@echo "*** Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng modules/KIWIScheme.rnc modules/KIWIScheme.rng

	#============================================
	# Check RNG Scheme...
	#--------------------------------------------
	for i in `find -name config.xml`;do \
		xsltproc -o $$i.new xsl/convert20to24.xsl $$i && mv $$i.new $$i;\
		echo $$i; j=`jing modules/KIWIScheme.rng $$i`;if test ! -z "$$j";then\
			echo $$j; break;\
		fi;\
	done; test -z "$$j" || false

modules/KIWISchemeTest.rng: modules/KIWISchemeTest.rnc
	#============================================
	# Convert RNC -> RNG...
	#--------------------------------------------
	@echo "*** Converting KIWI TEST RNC -> RNG..."
	trang -I rnc -O rng modules/KIWISchemeTest.rnc modules/KIWISchemeTest.rng

	#============================================
	# Check RNG TEST Scheme...
	#--------------------------------------------
	for i in `find tests -name test-case.xml`;do \
		echo $$i; j=`jing modules/KIWISchemeTest.rng $$i`;if test ! -z "$$j";\
		then\
			echo $$j; break;\
		fi;\
	done; test -z "$$j" || false

clean:
	(cd system/boot && find -type f | grep -v .svn | xargs chmod u+w)
	rm -f modules/KIWIScheme.rng
	${MAKE} -C tools clean

build:
	./.doit -p --local
