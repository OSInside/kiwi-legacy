use ExtUtils::MakeMaker;
use Env;

$CFLAGS = $ENV{RPM_OPT_FLAGS};
$CFLAGS =~ s/-Wall//;

WriteMakefile(
  'NAME'     => 'KIWI::SaT',
  'LIBS'     => ["-lrpmdb -lexpat -lsatsolver -lstdc++"],
  'OBJECT'   => 'SaT_wrap.o',
  'OPTIMIZE' => "-O2 $CFLAGS",
  'INC'      => "-I/usr/include/satsolver"
);

