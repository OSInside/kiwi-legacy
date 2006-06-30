all:restart timed 

restart:
	gcc -Wall ${CFLAGS} restart.c -o restart
	strip restart

timed:
	gcc -Wall ${CFLAGS} timed.c -o timed
	strip timed

clean:
	rm -f restart
	rm -f timed
