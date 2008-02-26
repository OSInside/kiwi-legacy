all:
	${MAKE} -C startshell all
	${MAKE} -C pigz all
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
	#install -m 755 init/* ${INITVZ}
	#install -m 755 wrapper/* ${TOOLSVZ}
	install -m 755 startshell/startshell ${TOOLSVZ}
	install -m 755 pigz/pigz ${TOOLSVZ}
	${MAKE} -C dbuslock DESTDIR=${buildroot} install_vendor
	( \
		if test -d /usr/include/satsolver;then \
			cd ./satplugin && make DESTDIR=${buildroot} install_vendor;\
		else \
			true;\
		fi\
	)

clean:
	${MAKE} -C startshell clean
	${MAKE} -C pigz clean
	${MAKE} -C satplugin -f Makefile.swig clean
	${MAKE} -C dbuslock -f Makefile.swig clean
