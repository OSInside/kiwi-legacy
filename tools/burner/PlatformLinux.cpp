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

#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

#include <QtCore>
#include <QtGui>
#include <QDir>
#include <QProgressDialog>
#include <QtDBus>

#include "DeviceItem.h"
#include "PlatformLinux.h"

#define BLOCKSIZE 1048576

// Figure out which devices we should allow a user to write to.
void
PlatformLinux::findDevices(bool unsafe)
{
    char **drives;
    char *device, *product, *vendor;
    int drive_count, i;
    long long size;
    bool isRemovable = true;
    LibHalContext *context;

    if ((context = initHal()) == NULL)
    {
        QMessageBox msgBox;
        msgBox.setText(QObject::tr("Could not initialize HAL."));
        msgBox.exec();
        return;
    }

    // We want to only write to USB drives, unless the user specifies
    // the unsafe flag on the command line
    if (unsafe)
        drives = libhal_manager_find_device_string_match(context,
                                                        "storage.drive_type",
                                                        "disk",
                                                        &drive_count,
                                                        NULL);
    else
        drives = libhal_manager_find_device_string_match(context,
                                                        "storage.bus",
                                                        "usb",
                                                        &drive_count,
                                                        NULL);

    for(i = 0; i < drive_count; i++)
    {
        device = libhal_device_get_property_string(context,
                                                  drives[i],
                                                  "block.device",
                                                  NULL);
        if (device == NULL)
            continue;

        product = libhal_device_get_property_string(context,
                                                    drives[i],
                                                    "info.product",
                                                    NULL);

        vendor = libhal_device_get_property_string(context,
                                                   drives[i],
                                                   "info.vendor",
                                                   NULL);
        size = libhal_device_get_property_uint64(context,
                                                 drives[i],
                                                 "storage.removable.media_size",
                                                 NULL);
        
        isRemovable = libhal_device_get_property_bool(context,
                                                      drives[i],
                                                      "storage.removable",
                                                      NULL);

        DeviceItem *devItem = new DeviceItem;
        devItem->setUDI(drives[i]);
        devItem->setPath(device);
        devItem->setIsRemovable(isRemovable);
        devItem->setSize(size);

        if (!strcmp(product, ""))
            devItem->setModelString("");
        else
            devItem->setModelString(product);

        if (!strcmp(vendor, ""))
#ifdef KIOSKHACK
            devItem->setVendorString("SUSE Studio USB Key");
#else
            devItem->setVendorString("Unknown Device");
#endif
        else
            devItem->setVendorString(vendor);

        QString newDisplayString = QString("%1 %2 - %3 (%4 MB)").arg(devItem->getVendorString()).arg(devItem->getModelString()).arg(devItem->getPath()).arg(devItem->getSize() / 1048576);
        devItem->setDisplayString(newDisplayString);

#ifdef KIOSKHACK
        // VERY VERY VERY VERY VERY  ugly hack for kiosk: ignore hard disks bigger than 100GB
        if((devItem->getSize() / 1048576) < 200000) 
#endif
            itemList << devItem;

        libhal_free_string(device);
        libhal_free_string(product);
        libhal_free_string(vendor);
    }

    libhal_free_string_array(drives);
    libhal_ctx_shutdown(context, NULL);
    libhal_ctx_free(context);

    return;
}

LibHalContext *
PlatformLinux::initHal()
{
    DBusError error;
    DBusConnection *dbus_connection;
    LibHalContext *context;
    char **devices;
    int device_count;

    if ((context = libhal_ctx_new()) == NULL)
        return(NULL);

    dbus_error_init(&error);
    dbus_connection = dbus_bus_get(DBUS_BUS_SYSTEM, &error);
    if(dbus_error_is_set(&error))
    {
            dbus_error_free(&error);
            libhal_ctx_free(context);
            return(NULL);
    }

    libhal_ctx_set_dbus_connection(context, dbus_connection);
    if(!libhal_ctx_init(context, &error))
    {
            dbus_error_free(&error);
            libhal_ctx_free(context);
            return(NULL);
    }

    devices = libhal_get_all_devices(context, &device_count, NULL);
    if(devices == NULL)
    {
            libhal_ctx_shutdown(context, NULL);
            libhal_ctx_free(context);
            context = NULL;
            return(NULL);
    }

    libhal_free_string_array(devices);
    return(context);
}

bool
PlatformLinux::isMounted(QString path)
{
    LibHalContext *context;
    LibHalVolume *halVolume;
    bool ret = false;
    char **volumes;
    int volumeCount, i;
    
    if ((context = initHal()) == NULL)
    {
        QMessageBox msgBox;
        msgBox.setText(QObject::tr("Could not initialize HAL."));
        msgBox.exec();
        return false;
    }
    
    volumes = libhal_manager_find_device_string_match(context,
                                                      "info.parent",
                                                      path.toLatin1().data(),
                                                      &volumeCount,
                                                      NULL);
    for(i = 0; i < volumeCount; i++)
    {
        halVolume = libhal_volume_from_udi(context, volumes[i]);
        // I don't really know if this is better than just looking for the volume.is_mounted property,
        // might as well be on the safe side.
        if (libhal_volume_is_mounted(halVolume))
            ret = true;
        
        libhal_volume_free(halVolume);
    }

    libhal_free_string_array(volumes);
    libhal_ctx_shutdown(context, NULL);
    libhal_ctx_free(context);
    return ret;
}

bool
PlatformLinux::unmountDevice (QString path)
{
    LibHalContext *context;
    bool ret = true;
    char **volumes;
    int volumeCount, i;
    
    if ((context = initHal()) == NULL)
    {
        QMessageBox msgBox;
        msgBox.setText(QObject::tr("Could not initialize HAL."));
        msgBox.exec();
        return false;
    }
    
    volumes = libhal_manager_find_device_string_match(context,
                                                      "info.parent",
                                                      path.toLatin1().data(),
                                                      &volumeCount,
                                                      NULL);
    for(i = 0; i < volumeCount; i++)
    {
        if (!performUnmount(volumes[i]))
            ret = false;
    }

    libhal_free_string_array(volumes);
    libhal_ctx_shutdown(context, NULL);
    libhal_ctx_free(context);
    return ret;
}

bool
PlatformLinux::performUnmount(QString udi)
{
    bool ret = true;
    QDBusConnection connection = QDBusConnection::systemBus();
    QDBusMessage message, reply;
    QList<QVariant> options;

    message = QDBusMessage::createMethodCall("org.freedesktop.Hal", udi, "org.freedesktop.Hal.Device.Volume", "Unmount");
    message << QStringList();
    reply = connection.call(message);

    if (reply.type() == QDBusMessage::ErrorMessage)
    {
        qDebug() << "Failure: " <<  reply;
        ret = false;
    }

    return ret;
}

// TODO make this routine not be shit
void
PlatformLinux::writeData(QString path, QString fileName, qint64 deviceSize)
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
        QMessageBox msgBox;
        msgBox.setText(QObject::tr("Couldn't open ") + fileName);
        msgBox.exec();
        return;
    }

    if ((ofd = ::open(path.toLocal8Bit().data(), O_WRONLY|O_SYNC)) == -1)
    {
        QMessageBox msgBox;
        msgBox.setText(QObject::tr("Couldn't open ") + path + ": " + strerror(errno));
        msgBox.exec();
        ::close(ifd);
        return;
    }

    QProgressDialog progress(" ", "Cancel", 0, 100);
    progress.setMinimumDuration(0);
    progress.setWindowModality(Qt::WindowModal);
    progress.setValue(100);
    progress.setWindowTitle(QObject::tr("Writing"));

    for (i = 0; i <= realSize; i++)
    {
        if ((read = ::read(ifd, buffer, BLOCKSIZE)) == -1)
        {
            QMessageBox msgBox;
            msgBox.setText(QObject::tr("Read failure"));
            msgBox.exec();
            break;
        }

        written = ::write(ofd, buffer, read);
        if (written == -1)
        {
            QMessageBox msgBox;
            msgBox.setText(QObject::tr("Write failure"));
            msgBox.exec();
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
}
