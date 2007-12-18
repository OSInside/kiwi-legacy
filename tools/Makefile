all:
	${MAKE} -C startshell all
	${MAKE} -C pigz all
	( \
		cd ./satplugin && \
		make -f Makefile.swig && make BINDLIB=${bindlib} \
	)

install:
	install -m 755 init/* ${INITVZ}
	install -m 755 startshell/startshell ${TOOLSVZ}
	install -m 755 pigz/pigz ${TOOLSVZ}
	install -m 755 wrapper/* ${TOOLSVZ}
	( cd ./satplugin && make DESTDIR=${buildroot} install_vendor )

clean:
	${MAKE} -C startshell clean
	${MAKE} -C pigz clean
	${MAKE} -C satplugin -f Makefile.swig clean
