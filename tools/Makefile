all:
	${MAKE} -C startshell all
	${MAKE} -C pigz all

install:
	install -m 755 init/* ${INITVZ}
	install -m 755 startshell/startshell ${TOOLSVZ}
	install -m 755 pigz/pigz ${TOOLSVZ}
	install -m 755 wrapper/* ${TOOLSVZ}

clean:
	${MAKE} -C startshell clean
	${MAKE} -C pigz clean
