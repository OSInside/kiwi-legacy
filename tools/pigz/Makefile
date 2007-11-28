OBJ = pigz
CC  = gcc -Wall -fpic -O2

all:${OBJ}

pigz: pigz.c
	${CC} ${CFLAGS} pigz.c -o pigz -lpthread -lz

clean:
	rm -f pigz
