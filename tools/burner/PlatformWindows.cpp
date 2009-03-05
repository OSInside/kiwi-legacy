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

#include <QtGui>

#include "PlatformWindows.h"

#define NUM_HOST_CONTROLLER_CHECKS 10

void
PlatformWindows::findDevices()
{
    wchar_t controllerName[16];
    int controllerNum;
    HANDLE controllerHandle;

    // There appear to be two ways of finding USB devices on Windows: iterate through
    // a bunch of shit like "\\.\HCD1" and iterate using GUIDs.

    // We have to do a trial and error method of finding the USB host controllers
    // which pretty much means "try to open every possible device name and see what happens".
    // This may be sub-optimal.
    for (controllerNum = 0; controllerNum < NUM_HOST_CONTROLLER_CHECKS; controllerNum++)
    {
        wsprintf(controllerName, L"\\\\.\\HCD%d", controllerNum);
        controllerHandle = CreateFile(controllerName,
                                      GENERIC_WRITE,
                                      FILE_SHARE_WRITE,
                                      NULL,
                                      OPEN_EXISTING,
                                      0,
                                      NULL);

        // Is the handler valid?
        if (controllerHandle != INVALID_HANDLE_VALUE)
        {
            // Super, we found a controller.  Lets see what devices are attached...
            examineController(controllerHandle);
            CloseHandle(controllerHandle);
        }
    }

    // TODO: GUID iteration
}

void
PlatformWindows::examineController(HANDLE controllerHandle)
{
    return;
}
  
bool
PlatformWindows::isMounted(QString path) { return true; }

void
PlatformWindows::writeData(QString path, QString fileName, qint64 deviceSize) { return; }
