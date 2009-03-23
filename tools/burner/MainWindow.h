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

#ifndef __MAIN_WINDOW_H__
#define __MAIN_WINDOW_H__

#include <QtGui>
#include <QWidget>

#include "Platform.h"

#if defined (Q_OS_LINUX)
#include "PlatformLinux.h"
#endif

#if defined (Q_OS_WIN)
#include "PlatformWindows.h"
#endif

#if defined (Q_OS_MAC)
#include "PlatformMac.h"
#endif

#include "DeviceItem.h"
#define VERSION "SUSE Studio Image Writer 1.1"

class MainWindow : public QWidget
{
    Q_OBJECT

public:
    MainWindow(const char *cmddevice,
               const char *cmdfile,
               bool unsafe = false,
               bool maximized = false,
               QWidget *parent = 0);

public slots:
    void selectImage();

private slots:
    void write();

protected:
    void dragEnterEvent(QDragEnterEvent *event);
    void dropEvent(QDropEvent *event);
    void setSizeLabel(QString fileName);

private:
    void findDevices();
    void setFile(QString newFile);
    void divineMeaning(QString path);
    void divineFurther(DeviceItem *item);
    bool isMounted(QString path);
    void writeData(QString path);
    void centerWindow();
    void useNewUI();
    void useOldUI();

#if (QT_VERSION < 0x040400)
    QLineEdit* fileLine;
#endif

    QLabel *imageLabel, *directive;
    QString file;
    QLabel *fileSize, *fileLabel;
    QComboBox *deviceComboBox;
    Platform *platform;
    bool mMaximized;
};

// Rather than grabbing a mouse click for the entire window, just grab it for the part
// that contains the graphics
class CustomLabel : public QLabel
{
public:
    CustomLabel(QWidget* parent);

protected:
    void mousePressEvent(QMouseEvent *event);
};

#endif
