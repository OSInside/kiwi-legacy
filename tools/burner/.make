#!/bin/sh
# Copyright (c) 2001 SuSE GmbH Nuernberg, Germany.  All rights reserved.
#
# Author: Matt Barringer <mbaringer@novell.com>, 2008
# Status: Up-to-date
#
if [ -d /usr/share/qt/mkspecs/linux-g++ ];then
	export QMAKESPEC=/usr/share/qt/mkspecs/linux-g++/
	`which qmake` -makefile -unix -o Makefile imagewriter.pro
else
	export QMAKESPEC=/usr/share/qt4/mkspecs/linux-g++/
	`which qmake` -makefile -unix -o Makefile imagewriter.pro
fi

