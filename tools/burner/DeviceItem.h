#ifndef __DEVICE_ITEM_H__
#define __DEVICE_ITEM_H__

#include <QWidget>

// This class represents the devices we find
// TODO: This should be subclassed for the different platforms, as they need different identifying details
class DeviceItem
{
public:
    DeviceItem() {};

    QString getPath() { return mPath; }
    QString getVendorString() { return mVendorString; }
    QString getModelString() { return mModelString; }
    QString getDisplayString() { return mDisplayString; }
    QString getUDI() { return mUDI; }
    qint64 getSize() { return mSize; }
    bool isRemovable() { return mIsRemovable; }

    void setPath(QString path) { mPath = path; }
    void setVendorString(QString vendor) { mVendorString = vendor; }
    void setModelString(QString modelString) { mModelString = modelString; }
    void setDisplayString(QString str) { mDisplayString = str; }
    void setSize(qint64 size) { mSize = size; }
    void setUDI(QString UDI) { mUDI = UDI; }
    void setIsRemovable(bool removable) { mIsRemovable = removable; }

private:
    QString mPath, // Path to the device (example: /dev/sdb)
            mUDI, // UDI for HAL
            mVendorString, // The vendor found in /proc/scsi/usb-storage/[id]
            mModelString, // the model string that has not had non-word characters replaced with "_"
            mDisplayString; // The string used in the pulldown device selection display
    qint64 mSize;
    bool mIsRemovable;
};

#endif
