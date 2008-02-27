/**************
FILE          : dbusdevice.cpp
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
#include "dbusdevice.h"

//using namespace std;

//====================================
// close
//------------------------------------
void HalConnection::close (void) {
	if( halContext ) {
		if( bOpen ) {
			libhal_ctx_shutdown( halContext, 0 );
		}
		libhal_ctx_free( halContext );
		halContext = 0;
		bOpen = false;
	}
}

//====================================
// open
//------------------------------------
bool HalConnection::open (void) {
	close();
	//cout << "initializing HAL >= 0.5" << endl;

	halContext = libhal_ctx_new();
	if( ! halContext ) {
		status = "unable to create HAL context";
		return false;
	}
	DBusError error;
	dbus_error_init( &error );
	connection = dbus_bus_get( DBUS_BUS_SYSTEM, &error );
	if ( dbus_error_is_set(&error) ) {
		status = "unable to connect to DBUS: ";
		status+= error.message;
		return false;
	}

	libhal_ctx_set_dbus_connection( halContext, connection );
	//libhal_ctx_set_device_added( halContext, halDeviceAdded );
	//libhal_ctx_set_device_removed( halContext, halDeviceRemoved );
	libhal_ctx_set_device_new_capability( halContext, 0 );
	libhal_ctx_set_device_lost_capability( halContext, 0 );
	libhal_ctx_set_device_property_modified( halContext, 0 );
	libhal_ctx_set_device_condition( halContext, 0 );

	if (!libhal_ctx_init( halContext, 0 ) ) {
		status = "Failed to init HAL context!";
		return false;
	}
	bOpen = true;
	int numDevices;
	char** halDeviceList = libhal_get_all_devices(
		halContext, &numDevices, 0
	);
	for( int i = 0; i < numDevices; ++i ) {
		addDevice( halDeviceList[i] );
	}
	return true;
}

//====================================
// addDevice
//------------------------------------
void HalConnection::addDevice ( const char* udi ) {
	if (!libhal_device_property_exists(halContext, udi,"info.capabilities",0)) {
		return;
	}
	if (libhal_device_query_capability(halContext,udi,"storage", 0 )) {
		char* dev = libhal_device_get_property_string(
			halContext, udi, "block.device", 0
		);
		if( dev ) {
			QString s( dev );
			libhal_free_string( dev );
			if( !s.isEmpty() ) {
				//cout << "Mapping udi: " << udi << endl;
				//cout << "  to device: " << s.toLatin1().data() << endl;
				udiDeviceMap[udi] = s;
				deviceUdiMap[s] = udi;
			}
		}
	} else {
		if( libhal_device_property_exists(
			halContext, udi, "block.storage_device", 0 )
		) {
			char* deviceUdi = libhal_device_get_property_string(
				halContext, udi, "block.storage_device", 0
			);
			if( deviceUdi ) {
				QString du( deviceUdi );
				libhal_free_string( deviceUdi );
				if( udiDeviceMap.contains( du ) ) {
					deviceMediumUdiMap[du] = QString( udi );
				}
			}
		}
	}
}

//====================================
// lock
//------------------------------------
int HalConnection::lock ( const char* dev ) {
	// ...
	// The code below is based on the code from
	// kioslave/media/mediamanager/halbackend.cpp in the kdebase package
	// Copyright (c) 2004-2005 Jérôme Lodewyck <jerome dot lodewyck at
	// normalesup dot org>
	// ---
	const char* lockComment = "Locked by the kiwi subsystem";
	int ret = org_freedesktop_Hal_Success;
	DBusMessage* dmesg = 0;
	DBusMessage* reply = 0;
	DBusError error;

	if( ! deviceUdiMap.contains( dev ) ) {
		status = "Device doesn't exist: ";
		status+= dev;
		return org_freedesktop_Hal_Device_Volume_NoSuchDevice;
	}
	QString udi = deviceUdiMap[dev];

	if (!( dmesg = dbus_message_new_method_call (
		"org.freedesktop.Hal", udi.toLatin1().data(),
		"org.freedesktop.Hal.Device", "Lock"
	))) {
		// could not create dbus message
		status = "lock failed for ";
		status+= udi;
		return org_freedesktop_Hal_CommunicationError;
	}
	if( !dbus_message_append_args(
		dmesg, DBUS_TYPE_STRING, &lockComment, DBUS_TYPE_INVALID
	)) {
		// could not append args to dbus message
		status = "lock failed for ";
		status+= udi;
		dbus_message_unref( dmesg );
		return org_freedesktop_Hal_CommunicationError;
	}
	dbus_error_init( &error );
	reply = dbus_connection_send_with_reply_and_block (
		connection, dmesg, -1, &error
	);
	if( dbus_error_is_set( &error ) ) {
		status = "lock failed for ";
		status+= udi + ": " + error.name + " - " + error.message;
		if (!strcmp(error.name, "org.freedesktop.Hal.NoSuchDevice" )) {
			ret = org_freedesktop_Hal_NoSuchDevice;
		} else if (
			!strcmp(error.name, "org.freedesktop.Hal.DeviceAlreadyLocked" )
		) {
			ret = org_freedesktop_Hal_DeviceAlreadyLocked;
		} else if (
			!strcmp(error.name, "org.freedesktop.Hal.PermissionDenied")
		) {
			ret = org_freedesktop_Hal_PermissionDenied;
		}
		dbus_error_free( &error );
	} else {
		status = "lock queued for ";
		status+= udi;
	}
	dbus_message_unref( dmesg );
	if( reply ) {
		dbus_message_unref( reply );
	}
	return ret;
}

//====================================
// unlock
//------------------------------------
int HalConnection::unlock( const char* dev ) {
	// ...
	// The code below is based on the code from
	// kioslave/media/mediamanager/halbackend.cpp in the kdebase package
	// Copyright (c) 2004-2005 Jérôme Lodewyck <jerome dot lodewyck at
	// normalesup dot org>
	// ----
	int ret = org_freedesktop_Hal_Success;
	DBusMessage* dmesg = 0;
	DBusMessage* reply = 0;
	DBusError error;

	if( ! deviceUdiMap.contains( dev ) ) {
		status = "Device doesn't exist: ";
		status+= dev;
		return org_freedesktop_Hal_Device_Volume_NoSuchDevice;
	}
	QString udi = deviceUdiMap[dev];

	if (!( dmesg = dbus_message_new_method_call (
		"org.freedesktop.Hal", udi.toLatin1().data(),
		"org.freedesktop.Hal.Device", "Unlock"
	))) {
		// could not create dbus message
		status = "unlock failed for ";
		status+= udi;
		return org_freedesktop_Hal_CommunicationError;
	}

	if ( !dbus_message_append_args(dmesg, DBUS_TYPE_INVALID)) {
		// could not append args to dbus message
		status = "unlock failed for ";
		status+= udi; 
		dbus_message_unref( dmesg );
		return org_freedesktop_Hal_CommunicationError;
	}

	dbus_error_init( &error );
	reply = dbus_connection_send_with_reply_and_block(
		connection, dmesg, -1, &error
	);
	if ( dbus_error_is_set( &error ) ) {
		status = "unlock failed for ";
		status+= udi + ": " + error.name + " - " + error.message;
		if( !strcmp(error.name, "org.freedesktop.Hal.NoSuchDevice" )) {
			ret = org_freedesktop_Hal_NoSuchDevice;
		} else if (
			!strcmp(error.name, "org.freedesktop.Hal.DeviceAlreadyLocked" )
		) {
			ret = org_freedesktop_Hal_DeviceAlreadyLocked;
		} else if (
			!strcmp(error.name, "org.freedesktop.Hal.PermissionDenied" )
		) {
			ret = org_freedesktop_Hal_PermissionDenied;
		}
		dbus_error_free( &error );
	} else {
		status = "unlock queued for ";
		status+= udi;
	}
	dbus_message_unref( dmesg );
	if( reply ) {
		dbus_message_unref( reply );
	}
	return ret;
}

//====================================
// state
//------------------------------------
char* HalConnection::state ( void ) {
	return status.toLatin1().data();
}
