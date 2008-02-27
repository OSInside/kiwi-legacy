/**************
FILE          : dbusdevice.h
***************
PROJECT       : KIWI 
              :
AUTHOR        : Marcus Schäfer <ms@suse.de>
              :
BELONGS TO    : KIWI - System Imaging 
              : 
              : 
DESCRIPTION   : native C++ application which provides
              : locking functions for hal devices via
              : dbus
              : - open / close
              : - lock / unlock 
              : ---
              :
              :
STATUS        : Status: Development
**************/
#ifndef DBUSLOCK_DEVICE_H
#define DBUSLOCK_DEVICE_H 1

#include <dbus/dbus.h>
#include <hal/libhal.h>
#include <iostream>
#include <string>
#include <cstdlib>
#include <cstring>
#include <qobject.h>
#include <qmap.h>
#include <qstringlist.h>
#include <qstring.h>
#include <getopt.h>

class HalConnection {
	public:
	HalConnection():
		halContext(0),
		bOpen(false) {
		status = "ok";
	}

	private:
	QString status;

	public:
	LibHalContext* halContext;
	DBusConnection* connection;
	QMap<QString, QString> udiDeviceMap;
	QMap<QString, QString> deviceUdiMap;
	QMap<QString, QString> deviceMediumUdiMap;
	bool bOpen;

	public:
	enum ErrorCodes {
		org_freedesktop_Hal_Success = 0,
		org_freedesktop_Hal_CommunicationError,
		org_freedesktop_Hal_NoSuchDevice,
		org_freedesktop_Hal_DeviceAlreadyLocked,
		org_freedesktop_Hal_PermissionDenied,
		org_freedesktop_Hal_Device_Volume_NoSuchDevice,
		org_freedesktop_Hal_Device_Volume_PermissionDenied,
		org_freedesktop_Hal_Device_Volume_AlreadyMounted,
		org_freedesktop_Hal_Device_Volume_InvalidMountOption,
		org_freedesktop_Hal_Device_Volume_UnknownFilesystemType,
		org_freedesktop_Hal_Device_Volume_InvalidMountpoint,
		org_freedesktop_Hal_Device_Volume_MountPointNotAvailable,
		org_freedesktop_Hal_Device_Volume_PermissionDeniedByPolicy,
		org_freedesktop_Hal_Device_Volume_InvalidUnmountOption,
		org_freedesktop_Hal_Device_Volume_InvalidEjectOption
	};
    
	public:
	void close (void);
	bool open (void);
	void addDevice ( const char*);
	int lock ( const char*);
	int unlock ( const char*);
	char* state (void);
};

#endif
