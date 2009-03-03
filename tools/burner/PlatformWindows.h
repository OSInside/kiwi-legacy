#ifndef __PLATFORM_WINDOWS_H__
#define __PLATFORM_WINDOWS_H__

#include <windows.h>
#include <basetyps.h>
#include <winioctl.h>
#include <setupapi.h>
#include <string.h>
#include <stdio.h>
#include <tchar.h>

#include "Platform.h"

class PlatformWindows : public Platform
{

public:
    PlatformWindows() { };
    // Override the Platform functions
    void findDevices();
    bool isMounted(QString path);
    void writeData(QString path, QString fileName, qint64 deviceSize);

private:
    void examineController(HANDLE controllerHandle);

};


#endif
