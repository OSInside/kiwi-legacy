use ExtUtils::MakeMaker;
use Env;

$QTLIBS = `pkg-config --libs QtCore`;
$QTINC = `pkg-config --cflags QtCore`;
chomp $QTINC;
$QTINC = $QTINC.'-I/usr/include/Qt';
$CFLAGS = $ENV{RPM_OPT_FLAGS} ." $QTINC";
$CFLAGS =~ s/-Wall//;

WriteMakefile(
  'NAME'     => 'KIWI::dbusdevice',
  'LIBS'     => ["$QTLIBS -lhal -ldbus-1"],
  'OBJECT'   => 'dbusdevice_wrap.o dbusdevice.o',
  'INC'      => "-I/usr/include/dbus-1.0 -I/usr/lib/dbus-1.0/include -I/usr/lib64/dbus-1.0/include -I/usr/include/g++ $QTINC",
  'OPTIMIZE' => "-O2 $CFLAGS",
  'CC'       => 'g++'
);

