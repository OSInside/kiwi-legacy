all:
	swig -Wall -c++ -perl5 dbusdevice.i
	perl Makefile.PL

clean:
	rm -rf blib
	rm -f  Makefile
	rm -f  dbusdevice_wrap.cxx
	rm -f  Makefile.old pm_to_blib
	rm -f  dbusdevice.bs dbusdevice.pm
	rm -f  dbusdevice_wrap.o dbusdevice.o
