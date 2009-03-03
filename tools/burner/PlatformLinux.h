#ifndef __PLATFORM_LINUX_H__
#define __PLATFORM_LINUX_H__

#include <hal/libhal.h>
#include <hal/libhal-storage.h>

#include "Platform.h"

class PlatformLinux : public Platform
{
public:
    PlatformLinux() { };
    void findDevices(bool unsafe = false);
    bool isMounted(QString path);
    void writeData(QString path, QString fileName, qint64 deviceSize);
    bool unmountDevice(QString path);

private:
    LibHalContext *initHal();
    bool performUnmount(QString udi);

public slots:
    void tick(qint64 lastWritten, qint64 bytesWritten);
};


#endif
