#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>

void exception (int);

int main (int argc,char*argv[]) {
	char value[128] = "";
	int  items = 0;

	signal (SIGALRM, exception);
	if ((argv[1]) && (atoi (argv[1]) > 0)) {
		int timeout = atoi (argv[1]);
		alarm (timeout);
	}
	items = scanf ("%80s", value);
	if (items) {
		printf ("%s\n",value);
	}
	exit (0);
}

void exception (int s) {
	printf ("undefined\n");
	exit (1);
}
