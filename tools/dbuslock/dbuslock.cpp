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

using namespace std;

class HalConnection {
	public:
	HalConnection():
		halContext(0),
		bOpen(false) {
		// empty constructor
	}

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
};

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

bool HalConnection::open (void) {
	close();
	cout << "initializing HAL >= 0.5" << endl;

	halContext = libhal_ctx_new();
	if( ! halContext ) {
		cout << "unable to create HAL context." << endl;
		return false;
	}
	DBusError error;
	dbus_error_init( &error );
	connection = dbus_bus_get( DBUS_BUS_SYSTEM, &error );
	if ( dbus_error_is_set(&error) ) {
		cout << "unable to connect to DBUS: " << error.message << endl;
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
		cout << "Failed to init HAL context!" << endl;
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
				cout << "Mapping udi: " << udi << endl;
				cout << "  to device: " << s.toLatin1().data() << endl;
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
		cout << "Device doesn't exist: " << dev << endl;
		return org_freedesktop_Hal_Device_Volume_NoSuchDevice;
	}
	QString udi = deviceUdiMap[dev];

	if (!( dmesg = dbus_message_new_method_call (
		"org.freedesktop.Hal", udi.toLatin1().data(),
		"org.freedesktop.Hal.Device", "Lock"
	))) {
		// could not create dbus message
		cout << "lock failed for " << udi.toLatin1().data();
		return org_freedesktop_Hal_CommunicationError;
	}
	if( !dbus_message_append_args(
		dmesg, DBUS_TYPE_STRING, &lockComment, DBUS_TYPE_INVALID
	)) {
		// could not append args to dbus message
		cout << "lock failed for " << udi.toLatin1().data();
		dbus_message_unref( dmesg );
		return org_freedesktop_Hal_CommunicationError;
	}
	dbus_error_init( &error );
	reply = dbus_connection_send_with_reply_and_block (
		connection, dmesg, -1, &error
	);
	if( dbus_error_is_set( &error ) ) {
		cout << "lock failed for " << udi.toLatin1().data() << ": "
			 << error.name << " - " << error.message << endl;
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
		cout << "(K3bDevice::HalConnection) lock queued for " 
			 << udi.toLatin1().data() << endl;
	}
	dbus_message_unref( dmesg );
	if( reply ) {
		dbus_message_unref( reply );
	}
	return ret;
}

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
		cout << "Device doesn't exist: " << dev << endl;
		return org_freedesktop_Hal_Device_Volume_NoSuchDevice;
	}
	QString udi = deviceUdiMap[dev];

	if (!( dmesg = dbus_message_new_method_call (
		"org.freedesktop.Hal", udi.toLatin1().data(),
		"org.freedesktop.Hal.Device", "Unlock"
	))) {
		// could not create dbus message
		cout << "unlock failed for " << udi.toLatin1().data();
		return org_freedesktop_Hal_CommunicationError;
	}

	if ( !dbus_message_append_args(dmesg, DBUS_TYPE_INVALID)) {
		// could not append args to dbus message
		cout << "unlock failed for " << udi.toLatin1().data();
		dbus_message_unref( dmesg );
		return org_freedesktop_Hal_CommunicationError;
	}

	dbus_error_init( &error );
	reply = dbus_connection_send_with_reply_and_block(
		connection, dmesg, -1, &error
	);
	if ( dbus_error_is_set( &error ) ) {
		cout << "unlock failed for " << udi.toLatin1().data() << ": "
			 << error.name << " - " << error.message << endl;
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
		cout << "(K3bDevice::HalConnection) unlock queued for " 
			 << udi.toLatin1().data() << endl;
	}
	dbus_message_unref( dmesg );
	if( reply ) {
		dbus_message_unref( reply );
	}
	return ret;
}

int main (int argc,char*argv[]) {
	//=====================================
	// open hal/dbus connection...
	//-------------------------------------
	int status = 0;
	HalConnection* d = new HalConnection();
	d -> open();

	//=====================================
	// handle options...
	//-------------------------------------
	while (1) {
		int option_index = 0;
		static struct option long_options[] =
		{
			{"lock"       , 1 , 0 , 'l'},
			{"unlock"     , 1 , 0 , 'u'}
		};
		int c = getopt_long (
			argc, argv, "l:u:",long_options, &option_index
		);
		if (c == -1) {
			return 1;
		}
		switch (c) {
			case 'l':
				status = d -> lock ( optarg );
			break;
			case 'u':
				status = d -> unlock ( optarg );
			break;
		}
	}
	d -> close();
	return status;
}
