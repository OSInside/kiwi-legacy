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
#define VERSION "SUSE Studio Image Writer 1.0"

class MainWindow : public QWidget
{
    Q_OBJECT

public:
    MainWindow(const char *cmddevice, const char *cmdfile, bool unsafe = false, QWidget *parent = 0);
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

    QLabel *imageLabel, *directive;
    QString file;
    QLabel *fileSize, *fileLabel;
    QComboBox *deviceComboBox;
    Platform *platform;
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
