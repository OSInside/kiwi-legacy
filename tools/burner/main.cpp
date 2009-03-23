/*
 *  Copyright (c) 2009 Novell, Inc.
 *  All Rights Reserved.
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of version 2 of the GNU General Public License as
 *  published by the Free Software Foundation.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, contact Novell, Inc.
 *  
 *  To contact Novell about this file by physical or electronic mail,
 *  you may find current contact information at www.novell.com
 *  
 *  Author: Matt Barringer <mbarringer@suse.de>
 *  
 */

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
    bool maximized = false;
#if defined(Q_OS_UNIX) 
#ifndef KIOSKHACK
    if (getuid() != 0)
        qFatal("You must run this program as the root user.");
#endif
#endif

    while ((c = getopt (argc, argv, "mvuhd:f:")) != -1)
    {
        switch (c)
        {
            case 'h':
                fprintf(stdout, "Usage:\t%s [-d <device>] [-f <raw file>] [-u] [-v]\n", argv[0]);
                fprintf(stdout, "Flashes a raw disk file to a device\n\n");
                fprintf(stdout, "-d <device>\t\tSpecify a device, for example: /dev/sdc\n");
                fprintf(stdout, "-f <raw file\t\tSpecify the file to write\n");
                fprintf(stdout, "-m\t\t\tMaximize the window");
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
            case 'm':
                 maximized = true;
                 break;
            default:
                break;
        }
    }

    QApplication app(argc, argv);
    MainWindow window(device, file, unsafe, maximized);
    if (maximized)
    {
        window.showMaximized();
    }
    else
    {
        window.show();
    }
    return app.exec();
}
