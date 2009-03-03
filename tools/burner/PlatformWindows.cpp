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
