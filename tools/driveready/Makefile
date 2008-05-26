OBJ = driveready
CC  = gcc -Wall -fpic -O2

all:${OBJ}

pigz: driveready.c
	${CC} ${CFLAGS} driveready.c -o driveready

clean:
	rm -f driveready
