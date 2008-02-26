TEMPLATE  += app

SOURCES   += dbuslock.cpp

CONFIG    += thread warn_on release
unix:LIBS += -lhal -ldbus-1
TARGET    = dbuslock

RPM_OPT_FLAGS ?= -O2

QMAKE_CXXFLAGS = $(RPM_OPT_FLAGS) -fno-strict-aliasing
unix:INCLUDEPATH += /usr/include/dbus-1.0
unix:INCLUDEPATH += /usr/lib/dbus-1.0/include
unix:INCLUDEPATH += /usr/include/g++
