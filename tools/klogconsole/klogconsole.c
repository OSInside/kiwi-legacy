/* (C) 1996 under GPL, Hans Lermen <lermen@elserv.ffm.fgan.de>,
 * parts of switch_printk_console() stolen from Kevin Buhr <buhr@stat.wisc.edu>
 */


/* klogconsole -l 1 -r MAX_CONSOLE */
/* Tells the kernel to what terminal and starting from what level
 * it should copy printk() messages */

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <unistd.h>
#include <termios.h>
#if !(defined __GLIBC__ && __GLIBC__ >= 2)
# include <linux/unistd.h>
# include <linux/termios.h>
#endif
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>

#if !(defined __GLIBC__ && __GLIBC__ >= 2)
static _syscall3(int, syslog, int, type, char *, bufp, int, len);
#else
# include <sys/klog.h>
#endif

#ifndef  MAX_CONSOLE
# define MAX_CONSOLE 24
#endif

void usage(void) __attribute__((noreturn));

static void console_level(int level)
{
#if !(defined __GLIBC__ && __GLIBC__ >= 2)
    syslog(8,0,level);
#else
    klogctl(8, 0, level);
#endif
}

static void switch_printk_console(int new_console)
{
    char newvt[2];
    int vt;

    if ((new_console < 0) || (new_console > MAX_CONSOLE)) {
        fprintf(stderr,"wrong console number\n");
        exit(1);
    }

    newvt[0] = 11;
    newvt[1] = new_console;
    vt = open( "/dev/tty1", O_RDONLY );
    if( vt == -1 ) {
        perror("open(/dev/tty1)");
        exit(1);
    }
    if( ioctl( vt, TIOCLINUX, &newvt ) ) {
        /* shut up perror("ioctl(TIOCLINUX)"); */
        exit(1);
    }
    close(vt);
}

void usage(void)
{
    printf(
        "USAGE:\n"
        "  klogconsole [-l console_loglevel ] [ -r console ]\n\n"
        "  console_loglevel  0..7 (kernel may dissallow values <5)\n"
        "  console           0..%i console to which printk() dups messages\n"
        "                     (0 = current console)\n", MAX_CONSOLE
    );
    exit(1);
}

int
main (int argc, char** argv)
{
    int op,i;
    
    if (argc <= 1) usage();
    opterr = 0;
    while ((op = getopt(argc, argv, "l:r:")) != EOF) {
        switch (op) {
            case 'l': {
                i=atoi(optarg);
                console_level(i);
                break;
            }
            case 'r': {
                i=atoi(optarg);
                switch_printk_console(i);
                break;
            }
            default: {
                usage();
                /* doesn't return */
            }
        }
    }
    return 0;
}
