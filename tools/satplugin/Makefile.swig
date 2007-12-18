all:
	swig -Wall -I/usr/include/satsolver -c++ -perl5 SaT.i
	perl Makefile.PL

test:sat.c
	${CC} -Wall sat.c -o sat -lsatsolver

clean:
	rm -rf sat
	rm -rf blib
	rm -f  Makefile
	rm -f  SaT_wrap.cxx
	rm -f  Makefile.old pm_to_blib
	rm -f  SaT.bs SaT.pm
	rm -f  SaT_wrap.o
