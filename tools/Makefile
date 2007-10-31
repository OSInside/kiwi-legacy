all:
	${MAKE} -C startshell all

install:
	install -m 755 init/* ${TOOLSVZ}
	install -m 755 startshell/startshell ${TOOLSVZ}
	install -m 755 wrapper/* ${TOOLSVZ}

clean:
	${MAKE} -C startshell clean
