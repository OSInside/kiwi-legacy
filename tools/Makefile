all:
	${MAKE} -C startshell all
	${MAKE} -C dcounter all
	${MAKE} -C pigz all
	${MAKE} -C driveready all
	${MAKE} -C dbuslock -f Makefile.swig all
	${MAKE} -C dbuslock BINDLIB=${bindlib} all
	( \
		if test -d /usr/include/satsolver;then \
			cd ./satplugin && make -f Makefile.swig && make BINDLIB=${bindlib};\
		else \
			true;\
		fi\
	)
	( cd burner && ./.make )
	${MAKE} -C burner all || true

install:
	install -m 644 README ${PACKDOCVZ}/README.tools
	#install -m 755 init/* ${INITVZ}
	install -m 755 dcounter/dcounter ${TOOLSVZ}
	install -m 755 startshell/startshell ${TOOLSVZ}
	install -m 755 pigz/pigz ${TOOLSVZ}
	install -m 755 driveready/driveready ${TOOLSVZ}
	install -m 755 cdtool/suse-isolinux ${TOOLSVZ}
	${MAKE} -C dbuslock DESTDIR=${buildroot} install_vendor
	( \
		if test -d /usr/include/satsolver;then \
			cd ./satplugin && make DESTDIR=${buildroot} install_vendor;\
		else \
			true;\
		fi\
	)
	if [ -f ./burner/imagewriter ];then \
		install -m 644 burner/README ${PACKDOCVZ}/README.imagewriter ;\
		install -m 755 burner/imagewriter ${bin_prefix} ;\
	fi

clean:
	${MAKE} -C dcounter clean
	${MAKE} -C burner clean
	${MAKE} -C startshell clean
	${MAKE} -C pigz clean
	${MAKE} -C driveready clean
	${MAKE} -C satplugin -f Makefile.swig clean
	${MAKE} -C dbuslock -f Makefile.swig clean
