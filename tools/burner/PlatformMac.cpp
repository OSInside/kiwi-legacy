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

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>

#include <fcntl.h>
#include <errno.h>

#include <QtGui>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h> 
#include <IOKit/IOBSD.h> 

#include "PlatformMac.h"
#include "DeviceItem.h"

#define BLOCKSIZE 1048576

void
PlatformMacintosh::findDevices(bool unsafe)
{
    kern_return_t ret;
    io_registry_entry_t entry;
    io_iterator_t iterator;
    io_name_t devName;
    CFStringRef bsdname;
    CFNumberRef data;
    SInt64 capacity = 0;

    // Search for USB devices
    // TODO: Pay attention to the unsafe flag
    CFMutableDictionaryRef dict = NULL;
    dict = IOServiceMatching("IOUSBDevice");

    ret = IOServiceGetMatchingServices(kIOMasterPortDefault, dict, &iterator);

    entry = IOIteratorNext(iterator);
    while (entry)
    {
        bsdname = (CFStringRef) IORegistryEntrySearchCFProperty(entry, kIOServicePlane, CFSTR(kIOBSDNameKey), kCFAllocatorDefault, kIORegistryIterateRecursively);
        data = (CFNumberRef) IORegistryEntrySearchCFProperty(entry, kIOServicePlane, CFSTR("Size"), kCFAllocatorDefault, kIORegistryIterateRecursively);
        if (bsdname) // If we can't look up "BSD name" then it isn't a removable device
        {
            IORegistryEntryGetName(entry, devName);
            DeviceItem *devItem = new DeviceItem;
            
            if (data)
            {
                CFNumberGetValue(data, kCFNumberSInt64Type, &capacity );
                devItem->setSize(capacity);
            }
            devItem->setVendorString(devName);

            QString newDevString = QString("/dev/%1").arg(CFStringGetCStringPtr(bsdname, kCFStringEncodingMacRoman));
            devItem->setPath(newDevString);
            devItem->setUDI(newDevString);

            QString newDisplayString = QString("%1 - %2 (%3 MB)").arg(devItem->getVendorString()).arg(devItem->getPath()).arg(devItem->getSize() / 1048576);
            devItem->setDisplayString(newDisplayString);
            itemList << devItem;
        }
        entry = IOIteratorNext(iterator);
    }
}
 
bool
PlatformMacintosh::isMounted(QString path)
{
    unsigned int mounts = 0;
    struct statfs *fsStats=NULL;

    mounts = getmntinfo(&fsStats, MNT_NOWAIT);
    if (mounts)
        return(true);
    return(false);
}

bool
PlatformMacintosh::unmountDevice(QString path)
{
    int mounts = 0;
    int i;
    int len = path.length();
    struct statfs *fsStats=NULL;
    FSRef volFSRef;
    FSCatalogInfo volumeInfo;

    mounts = getmntinfo(&fsStats, MNT_NOWAIT);
    if (mounts)
    {
        for (i = 0; i < mounts; i++)
        {
            if ((!memcmp(path.toLocal8Bit().data(), &fsStats[i].f_mntfromname[0], len)) // First check the path
                && (!isdigit(fsStats[i].f_mntfromname[len]))) // Then make sure we're not going to really mess things up
            {
                qDebug() << "Will try to unmount " << &fsStats[i].f_mntfromname[0];
                if (FSPathMakeRef((UInt8 *) fsStats[i].f_mntonname, &volFSRef, NULL) != noErr)
                    return(false);

                if (FSGetCatalogInfo(&volFSRef, kFSCatInfoVolume, &volumeInfo, NULL, NULL, NULL) != noErr)
                    return(false);

                if (FSUnmountVolumeSync(volumeInfo.volume, 0, NULL) != noErr)
                    return(false);
            }
        }
    }
    return(true);
}

void
PlatformMacintosh::writeData(QString path, QString fileName, qint64 deviceSize)
{
    QFileInfo info(fileName);
    qint64 realSize = info.size();

    if (realSize > deviceSize)
    {
        QMessageBox msgBox;
        msgBox.setText(QObject::tr("The image you are trying to write is larger than your USB stick."));
        msgBox.exec();
        return;
    }

    qint64 i = 0;
    char *buffer = (char *) malloc(BLOCKSIZE);
    qint64 read = 0;
    qint64 written = 0;

    int ofd = -1;
    int ifd = -1;

    int percentWritten, megsWritten, megsTotal;
    megsTotal = realSize / 1048576;

    // Open the file to read from 
    if ((ifd = ::open(fileName.toLocal8Bit().data(), O_RDONLY)) == -1)
    {
        qDebug() << "Couldn't open " + fileName;
        return;
    }

    if ((ofd = ::open(path.toLocal8Bit().data(), O_WRONLY|O_SYNC)) == -1)
    {
        // TODO complain
        qDebug() << "Couldn't open " + path + ": " + strerror(errno);
        ::close(ifd);
        return;
    }

    QProgressDialog progress(" ", "Cancel", 0, 100);
    progress.setMinimumDuration(0);
    progress.setWindowModality(Qt::WindowModal);
    progress.setValue(100);
    progress.setWindowTitle(QObject::tr("Writing Image..."));

    for (i = 0; i <= realSize; i++)
    {
        if ((read = ::read(ifd, buffer, BLOCKSIZE)) == -1)
        {
            qDebug() << "Uh oh";
            break;
        }

        written = ::write(ofd, buffer, read);
        if (written == -1)
        {
            qDebug() << "Hit a problem at " << i;
            break;
        }

        i += written;
        percentWritten = (i*100)/realSize;
        megsWritten = i / 1048576;
        progress.setValue(percentWritten);
        progress.setLabelText(QObject::tr("Written %1MB out of %2MB").arg(megsWritten).arg(megsTotal));
        qApp->processEvents();

        if (progress.wasCanceled())
             break;
     }
    ::close(ofd);
    ::close(ifd);
    free(buffer);
    progress.setValue(100);

    return;
}

