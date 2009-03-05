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
