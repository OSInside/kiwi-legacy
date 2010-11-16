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
KIWILOCVZ   = ${kiwi_prefix}/locale
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

all: modules/KIWISchema.rng modules/KIWISchemaTest.rng
	#============================================
	# build tools
	#--------------------------------------------
	${MAKE} -C tools all

	#============================================
	# install .revision file
	#--------------------------------------------
	test -f ./.revision || ./.version > .revision

install:
	#============================================
	# Install base directories
	#--------------------------------------------
	install -d -m 755 ${KIWIBINVZ} ${KIWIMODVZ} ${KIWIIMAGE} ${KIWIXSLVZ}
	install -d -m 755 ${TFTPKIWI} ${TFTPBOOT} ${TFTPBOOTCONF} ${TFTPIMAGE}
	install -d -m 755 ${TFTPBOOTBOOT} ${KIWITSTVZ} ${KIWILOCVZ}
	install -d -m 755 ${TFTPUPLOAD} ${KIWIREPO}
	install -d -m 755 ${PACKDOCVZ} ${MANVZ}
	install -d -m 755 ${TOOLSVZ} ${INITVZ}

	#============================================
	# install .revision file
	#--------------------------------------------
	install -m 644 ./.revision ${kiwi_prefix}

	#============================================
	# kiwi documentation and examples
	#--------------------------------------------
	cp -a doc/examples/ ${PACKDOCVZ}
	cp -a doc/images/   ${PACKDOCVZ}
	cp -a doc/schema/   ${PACKDOCVZ}
	cp -a doc/kiwi.pdf  ${PACKDOCVZ}
	cp -a doc/kiwi.html ${PACKDOCVZ}
	cp -a doc/*.css     ${PACKDOCVZ}
	cp -a doc/COPYING   ${PACKDOCVZ}
	test -e doc/ChangeLog && cp -a doc/ChangeLog ${PACKDOCVZ} || true

	#============================================
	# kiwi manual pages
	#--------------------------------------------
	for i in `ls -1 ./doc/*.1`;do \
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
	# install NLS support (translations)...
	#--------------------------------------------
	${MAKE} -C locale KIWILOCVZ=${KIWILOCVZ} install

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
	#install -m 755 pxeboot/pxelinux.0.config ${TFTPBOOTCONF}/default

	#============================================
	# Install boot image descriptions
	#--------------------------------------------
	cp -a system/boot/${arch}/* ${KIWIIMAGE} &>/dev/null || true
	cp system/boot/${arch}/.md5 ${KIWIIMAGE} 
	(cd ${KIWIIMAGE} && ./.md5)
	(cd ${KIWIIMAGE} && \
		find -type f | grep -v -E ".git|.test|.md5" |\
		xargs chmod u-w &>/dev/null || true)
	rm -f ${KIWIIMAGE}/.md5

	#============================================
	# Install system image template descriptions
	#--------------------------------------------
	cp -a template/${arch}/* ${KIWIIMAGE} &>/dev/null || true
	rm -f ${KIWIIMAGE}/README

	#============================================
	# Install kiwi repo
	#--------------------------------------------
	cp -a system/repo/${arch}/* ${KIWIREPO}

modules/KIWISchema.rng: modules/KIWISchema.rnc
	#============================================
	# Convert RNC -> RNG...
	#--------------------------------------------
	@echo "*** Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng modules/KIWISchema.rnc modules/KIWISchema.rng

	#============================================
	# Check RNG Schema...
	#--------------------------------------------
	for i in `find -name config.xml` modules/KIWICache.kiwi;do \
		test -f xsl/master.xsl && \
			xsltproc -o $$i.new xsl/master.xsl $$i && mv $$i.new $$i;\
		echo $$i; j=`jing modules/KIWISchema.rng $$i`;if test ! -z "$$j";then\
			echo $$j; break;\
		fi;\
	done; test -z "$$j" || false

modules/KIWISchemaTest.rng: modules/KIWISchemaTest.rnc
	#============================================
	# Convert RNC -> RNG...
	#--------------------------------------------
	@echo "*** Converting KIWI TEST RNC -> RNG..."
	trang -I rnc -O rng modules/KIWISchemaTest.rnc modules/KIWISchemaTest.rng

	#============================================
	# Check RNG TEST Schema...
	#--------------------------------------------
	for i in `find tests -name test-case.xml`;do \
		echo $$i; j=`jing modules/KIWISchemaTest.rng $$i`;if test ! -z "$$j";\
		then\
			echo $$j; break;\
		fi;\
	done; test -z "$$j" || false

clean:
	(cd system/boot && find -type f | grep -v .svn | xargs chmod u+w)
	(find -name .checksum.md5 | xargs rm -f)
	${MAKE} -C tools clean
	${MAKE} -C locale clean
	rm -f tools/burner/Makefile
	rm -f tools/burner/imagewriter
	rm -f .revision

build:
	./.doit -p --local
