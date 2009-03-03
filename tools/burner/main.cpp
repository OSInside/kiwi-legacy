#include <QApplication>
#include "MainWindow.h"

#if defined (Q_OS_UNIX)
#include <unistd.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#endif

int
main (int argc, char *argv[])
{
    int c;
    char *device = NULL;
    char *file = NULL;
    bool unsafe = false;
#if defined(Q_OS_UNIX) 
#ifndef KIOSKHACK
    if (getuid() != 0)
        qFatal("You must run this program as the root user.");
#endif
#endif

    while ((c = getopt (argc, argv, "vuhd:f:")) != -1)
    {
        switch (c)
        {
            case 'h':
                fprintf(stdout, "Usage:\t%s [-d <device>] [-f <raw file>] [-u] [-v]\n", argv[0]);
                fprintf(stdout, "Flashes a raw disk file to a device\n\n");
                fprintf(stdout, "-d <device>\t\tSpecify a device, for example: /dev/sdc\n");
                fprintf(stdout, "-f <raw file\t\tSpecify the file to write\n");
                fprintf(stdout, "-u\t\t\tOperate in unsafe mode, listing all disks, not just removable ones\n");
                fprintf(stdout, "-v\t\t\tVersion and author information\n");
                exit(0);
            case 'u':
                unsafe = true;
                break;
            case 'd':
                device = strdup(optarg);
                break;
            case 'f':
                file = strdup(optarg);
                break;
            case 'v':
                fprintf(stdout, "%s\nWritten by Matt Barringer <mbarringer@suse.de>\n", VERSION);
                exit(0);
                break;
            default:
                break;
        }
    }

    QApplication app(argc, argv);
    MainWindow window(device, file, unsafe);
    window.show();
    return app.exec();
}
