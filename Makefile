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
emacs_prefix= ${buildroot}/usr/share/emacs

#============================================
# Variables... 
#--------------------------------------------
KIWIBINVZ   = ${buildroot}/usr/sbin
KIWIMODVZ   = ${kiwi_prefix}/modules
KIWILOCVZ   = ${kiwi_prefix}/locale
KIWIXSLVZ   = ${kiwi_prefix}/xsl
TOOLSVZ     = ${bin_prefix}
LIVESTICKVZ = ${kiwi_prefix}/livestick
INITVZ      = ${init_prefix}
KIWIIMAGE   = ${kiwi_prefix}/image
KIWIEDITING = ${kiwi_prefix}/editing
KIWIEMACS   = ${emacs_prefix}/site-lisp
KIWIREPO    = ${kiwi_prefix}/repo
KIWITESTS   = ${kiwi_prefix}/tests
TFTPKIWI    = ${tftp_prefix}/KIWI
TFTPBOOT    = ${tftp_prefix}/
TFTPBOOTBOOT= ${tftp_prefix}/boot
TFTPBOOTCONF= ${tftp_prefix}/pxelinux.cfg
TFTPUPLOAD  = ${tftp_prefix}/upload
TFTPIMAGE   = ${tftp_prefix}/image
PACKDOCVZ   = ${doc_prefix}/kiwi
MANVZ       = ${man_prefix}/man1

ifdef KIWIVERBTEST
TESTVERBOSE = --verbose
endif

ifdef KIWINONETWORKTEST
NONETWORKTEST = env KIWI_NO_NET=1
endif

ifdef KIWINOFSTEST
KIWINOFSTEST = env KIWI_NO_FS=1
endif

all: modules/KIWISchema.rng
	#============================================
	# build tools
	#--------------------------------------------
	${MAKE} -C tools all
	${MAKE} -C locale all

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
	install -d -m 755 ${TFTPBOOTBOOT} ${KIWILOCVZ} ${KIWIKEYVZ}
	install -d -m 755 ${TFTPUPLOAD} ${KIWIREPO}
	install -d -m 755 ${PACKDOCVZ} ${MANVZ}
	install -d -m 755 ${TOOLSVZ} ${INITVZ} ${LIVESTICKVZ}
	install -d -m 755 ${KIWIEDITING} ${KIWIEMACS} ${KIWITESTS}

	#============================================
	# install XML editor support
	#--------------------------------------------
	# for Emacs
	install -m 644 ./editing/suse-start-kiwi-mode.el ${KIWIEMACS}
	install -m 644 ./editing/suse-start-kiwi-xmllocator.xml ${KIWIEDITING}

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
	rm -f ${PACKDOCVZ}/schema/Makefile
	rm -f ${PACKDOCVZ}/schema/susesync

	#============================================
	# kiwi manual pages
	#--------------------------------------------
	for i in `ls -1 ./doc/*.1`;do \
		install -m 644 $$i ${MANVZ} ;\
	done

	#============================================
	# Install kiwi tests
	#--------------------------------------------
	cp -r ./tests/unit ${KIWITESTS}
	install -m 755 ./tests/writeTester ${KIWITESTS}

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

valid: modules/KIWISchema.rng
	#============================================
	# Validate all XML descriptions...
	#--------------------------------------------
	for i in `find -name config.xml | grep -v tests`;do \
		test -f xsl/master.xsl && \
			xsltproc -o $$i.new xsl/master.xsl $$i && mv $$i.new $$i;\
		echo $$i;\
		./kiwi.pl --check-config $$i || break;\
	done

test:
	#============================================
	# Run unit tests...
	#--------------------------------------------
	tests/unit/cleanup.sh
	if test ! -d tests/.timestamps; then \
		mkdir tests/.timestamps; \
	fi
	for i in `find -name "*.t" | cut -d/ -f4`;do \
		touch tests/.timestamps/$$i's';\
	done
	cd tests/unit && \
		${NONETWORKTEST} ${KIWINOFSTEST} /usr/bin/prove ${TESTVERBOSE} .
	rm -f .revision

%.t:
	#============================================
	# Run specific unit test
	#--------------------------------------------
	tests/unit/cleanup.sh
	if test ! -d tests/.timestamps; then \
		mkdir tests/.timestamps; \
	fi
	touch tests/.timestamps/$@s
	cd tests/unit && \
		${NONETWORKTEST} ${KIWINOFSTEST} /usr/bin/prove ${TESTVERBOSE} $@

clean:
	(cd system/boot && find -type f | grep -v .svn | xargs chmod u+w)
	(find -name .checksum.md5 | xargs rm -f)
	${MAKE} -C tools clean
	${MAKE} -C locale clean
	rm -f tools/burner/Makefile
	rm -f tools/burner/imagewriter
	rm -f .revision

uninstall:
	rm -rf /usr/share/kiwi
	rm -rf /usr/share/doc/packages/kiwi
	rm -f /usr/sbin/kiwi
	rm -f /usr/share/emacs/site-lisp/suse-start-kiwi-mode.el

build:
	./.doit -p --local
