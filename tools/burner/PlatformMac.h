#ifndef __PLATFORM_MACINTOSH_H__
#define __PLATFORM_MACINTOSH_H__

#include "Platform.h"

class PlatformMacintosh : public Platform
{
public:
    PlatformMacintosh() { };
    // Override the Platform functions
    void findDevices();
    bool isMounted(QString path);
    void writeData(QString path, QString fileName, qint64 deviceSize);
};

#endif

