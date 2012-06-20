OBJ = get_kernel_version
CC  = gcc -Wall -fpic -O2

all:${OBJ}

get_kernel_version: get_kernel_version.c
	${CC} ${CFLAGS} get_kernel_version.c -o get_kernel_version

clean:
	rm -f get_kernel_version
