all:
	${MAKE} -C startshell all
	${MAKE} -C dcounter all
	${MAKE} -C driveready all
	${MAKE} -C utimer all
	${MAKE} -C kversion all

install:
	install -m 644 README ${PACKDOCVZ}/README.tools
	install -m 755 kversion/kversion ${TOOLSVZ}
	install -m 755 dcounter/dcounter ${TOOLSVZ}
	install -m 755 startshell/startshell ${TOOLSVZ}
	install -m 755 driveready/driveready ${TOOLSVZ}
	install -m 755 utimer/utimer ${TOOLSVZ}

clean:
	${MAKE} -C dcounter clean
	${MAKE} -C startshell clean
	${MAKE} -C driveready clean
	${MAKE} -C utimer clean
	${MAKE} -C kversion clean
