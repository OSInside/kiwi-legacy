INST = init startshell wrapper

all:
	${MAKE} -C startshell all

install:${INST}
	
init:
	install -m 755 init/* ${TOOLSVZ}

startshell:
	install -m 755 startshell/startshell ${TOOLSVZ}

wrapper:
	install -m 755 wrapper/* ${TOOLSVZ}

clean:
	${MAKE} -C startshell clean
