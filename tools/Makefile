all:
	${MAKE} -C startshell all
	${MAKE} -C dcounter all
	${MAKE} -C driveready all
	${MAKE} -C utimer all
	${MAKE} -C dbuslock -f Makefile.swig all
	${MAKE} -C dbuslock BINDLIB=${bindlib} all
	( \
		if test -d /usr/include/satsolver;then \
			cd ./satplugin && make -f Makefile.swig && make BINDLIB=${bindlib};\
		else \
			true;\
		fi\
	)

install:
	install -m 644 README ${PACKDOCVZ}/README.tools
	#install -m 755 init/* ${INITVZ}
	install -m 755 dcounter/dcounter ${TOOLSVZ}
	install -m 755 startshell/startshell ${TOOLSVZ}
	install -m 755 driveready/driveready ${TOOLSVZ}
	install -m 755 utimer/utimer ${TOOLSVZ}
	${MAKE} -C dbuslock DESTDIR=${buildroot} install_vendor
	( \
		if test -d /usr/include/satsolver;then \
			cd ./satplugin && make DESTDIR=${buildroot} install_vendor;\
		else \
			true;\
		fi\
	)

clean:
	${MAKE} -C dcounter clean
	${MAKE} -C startshell clean
	${MAKE} -C driveready clean
	${MAKE} -C utimer clean
	${MAKE} -C satplugin -f Makefile.swig clean
	${MAKE} -C dbuslock -f Makefile.swig clean
