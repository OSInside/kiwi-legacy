#ifndef __PLATFORM_H__
#define __PLATFORM_H__

#include <QtCore>

#include "DeviceItem.h"

// Virtual class for platform-specific operations
class Platform
{

public:
    Platform();
    virtual void findDevices(bool unsafe = false) = 0;
    virtual bool isMounted(QString path) = 0;
    virtual bool unmountDevice(QString path) = 0;
    virtual void writeData(QString path, QString fileName, qint64 deviceSize) = 0;

    QLinkedList<DeviceItem *> getDeviceList() { return itemList; }

protected:
    DeviceItem *pDevice;
    QLinkedList<DeviceItem *> itemList;
};

#endif
