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

#include <QtGui>
#include <QFileDialog>
#include <QProgressDialog>

#include "MainWindow.h"

MainWindow::MainWindow (const char *cmddevice, const char *cmdfile, bool unsafe, QWidget *parent)
 : QWidget(parent)
{
    int dev = -1;

    QVBoxLayout *mainLayout;
    QStackedLayout *logoLayout;
    QGridLayout *bottomLayout;

    QHBoxLayout *pathSizeLayout;
    QPushButton *writeButton;
    

    file = QString();

    // Set the background colour
    QPalette pal = palette();
    pal.setColor(QPalette::Window, Qt::white);
    setPalette(pal);

    // The upper left studio logo
    imageLabel = new CustomLabel(this);
    imageLabel->setBackgroundRole(QPalette::Base);
    imageLabel->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
    imageLabel->setScaledContents(false);
    QImage image(":logo-empty.png");
    imageLabel->setPixmap(QPixmap::fromImage(image));
    imageLabel->setAlignment(Qt::AlignCenter);

    fileSize = new QLabel("      ");
    fileLabel = new QLabel("     ");
    directive = new CustomLabel(this);
    directive->setText(tr("Drag appliance image here\n or click to select."));
    directive->setAlignment(Qt::AlignCenter);
    deviceComboBox = new QComboBox;

    writeButton = new QPushButton(tr("Copy"));
    connect(writeButton, SIGNAL(clicked()), this, SLOT(write()));

    // These layouts are kind of a mess
    logoLayout = new QStackedLayout;
    logoLayout->setStackingMode(QStackedLayout::StackAll);
    logoLayout->addWidget(directive);
    logoLayout->addWidget(imageLabel);

    pathSizeLayout = new QHBoxLayout;
    pathSizeLayout->addWidget(fileLabel, Qt::AlignLeft);
    pathSizeLayout->addWidget(fileSize, Qt::AlignLeft);

    bottomLayout = new QGridLayout;
    bottomLayout->addLayout(pathSizeLayout, 0, 0);

    mainLayout = new QVBoxLayout;
    mainLayout->addLayout(logoLayout, Qt::AlignHCenter);

    QGridLayout *comboLayout = new QGridLayout;
    comboLayout->addLayout(bottomLayout, 0, 0, Qt::AlignBottom);
    comboLayout->addWidget(deviceComboBox, 1,0);
    comboLayout->addWidget(writeButton, 1, 1, Qt::AlignRight);
    mainLayout->addLayout(comboLayout);

    setLayout(mainLayout);
    setWindowTitle(tr(VERSION));

    // Setup the platform-specific bits
#if defined (Q_OS_LINUX)
    platform = new PlatformLinux;
#elif defined (Q_OS_WIN)
    platform = new PlatformWindows;
#elif defined (Q_OS_MAC)
    platform = new PlatformMacintosh;
#else
    QMessageBox msgBox;
    msgBox.setText(tr("Your platform is not currently supported."));
    msgBox.exec();
    qFatal("Unsupported platform.");
#endif

    platform->findDevices(unsafe);

    // Now that we've found the devices, add them to the combo box
    QLinkedList<DeviceItem *> list = platform->getDeviceList();
    QLinkedList<DeviceItem *>::iterator i;
    for (i = list.begin(); i != list.end(); ++i)
    {
        if (!(*i)->getPath().isEmpty())
            deviceComboBox->addItem((*i)->getDisplayString(), 0);
        if (cmddevice != NULL)
            if ((*i)->getPath().compare(cmddevice) == 0)
                dev = deviceComboBox->findText((*i)->getDisplayString(), 0);
    }

    if (dev != -1)
        deviceComboBox->setCurrentIndex(dev);

    if (cmdfile != NULL)
    {
        if(QFile(cmdfile).exists())
        {
          setFile(cmdfile);
          setSizeLabel(cmdfile);
        }
    }


    resize(600, 400);
    setAcceptDrops(true);
    centerWindow();
}

void
MainWindow::centerWindow()
{
    QDesktopWidget *desktop = QApplication::desktop();
    
    int screenWidth, width; 
    int screenHeight, height;
    int x, y;
    int screen = desktop->screenNumber(this);
    QSize windowSize;
 
    screenWidth = desktop->screenGeometry(screen).width();
    screenHeight = desktop->screenGeometry(screen).height();
    
    windowSize = size();
    width = windowSize.width(); 
    height = windowSize.height();
    
    x = (screenWidth - width) / 2;
    y = (screenHeight - height) / 2;
    y -= 50;
    
    move ( x, y );
}

void
MainWindow::selectImage()
{
    QString fileName = QFileDialog::getOpenFileName(this,
                        tr("Open Image"),
                        QDir::currentPath(),
                        tr("Image Files (*.raw)"));
    if (!fileName.isEmpty())
    {
        setFile(fileName);
        setSizeLabel(fileName);
    }

    return;
}

void
MainWindow::setSizeLabel(QString fileName) 
{
    QFile filecheck(fileName);
    if(filecheck.exists())
    {
        int size = filecheck.size() / (1024*1024);
        fileSize->setText("(<b>" + QString::number(size) + " MB</b>)" );
    }
    return;
}

void MainWindow::dragEnterEvent(QDragEnterEvent *event)
{
#if 0
    qDebug() << event->mimeData()->text();
    qDebug() << event->mimeData()->formats();
    qDebug() << event->mimeData()->urls();
#endif
    if (event->mimeData()->hasFormat("text/uri-list"))
        event->acceptProposedAction();

}

void MainWindow::dropEvent(QDropEvent *event)
{
    QString file = event->mimeData()->urls()[0].toLocalFile();
    setFile(file);
    setSizeLabel(file);
}

void MainWindow::setFile(QString newFile)
{
    file = newFile;
    QImage image(":logo-mini.png");
    imageLabel->setPixmap(QPixmap::fromImage(image));
    fileLabel->setText("<b>Selected:</b> " + file);
    directive->setText("");
}

void
MainWindow::write()
{
    if (file.isEmpty())
    {
        QMessageBox msgBox;
        msgBox.setText(tr("Please select an image to use."));
        msgBox.exec();
        return;
    }

    DeviceItem *item = NULL;
    QLinkedList<DeviceItem *> list = platform->getDeviceList();

    QLinkedList<DeviceItem *>::iterator i;
    for (i = list.begin(); i != list.end(); ++i)
    {
        if ((*i)->getDisplayString() == deviceComboBox->currentText())
            item = (*i);
    }

    if (item != NULL)
    {
        if (platform->isMounted(item->getUDI()))
        {
            // We won't let them nuke a mounted device
            QMessageBox msgBox;
            msgBox.setText(tr("This device is already mounted.  Would you like me to attempt to unmount it?"));
            msgBox.setStandardButtons(QMessageBox::Yes | QMessageBox::No);
            msgBox.setDefaultButton(QMessageBox::No);
            switch (msgBox.exec())
            {
                case QMessageBox::Yes:
                {
                    if (!platform->unmountDevice(item->getUDI()))
                    {
                        QMessageBox failedBox;
                        failedBox.setText(tr("Unmount failed.  I will not write to this device."));
                        failedBox.exec();
                        return;
                    }
                    break;
                }
                case QMessageBox::No:
                    return;
                default:
                    break;
            }
        }

        QMessageBox msgBox;
        QString messageString;
        if (item->isRemovable())
            messageString = tr("This will overwrite the contents of ") + item->getPath() + tr(".  Are you sure you want to continue?");
        else
            messageString = item->getPath() + tr(" is a non-removable hard drive, and this will overwrite the contents.  Are you <b>sure</b> you want to continue?");
        msgBox.setText(messageString);
        msgBox.setStandardButtons(QMessageBox::Cancel | QMessageBox::Ok);
        msgBox.setDefaultButton(QMessageBox::Cancel);
        switch (msgBox.exec())
        {
            case QMessageBox::Ok:
            {
                platform->writeData(item->getPath(), file, item->getSize());
                break;
            }
            default:
                break;
        }
    }
}

CustomLabel::CustomLabel(QWidget* parent)
 : QLabel(parent)
{
}

void CustomLabel::mousePressEvent(QMouseEvent *event)
{
    if (event->button() == Qt::LeftButton)
    {
        MainWindow *window = (MainWindow *) parentWidget();
        window->selectImage();
    }
}
