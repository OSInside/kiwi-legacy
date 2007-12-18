use ExtUtils::MakeMaker;
use Env;

$CFLAGS = $ENV{RPM_OPT_FLAGS};
$CFLAGS =~ s/-Wall//;

WriteMakefile(
  'NAME'     => 'SaT',
  'LIBS'     => ["-ldb -lexpat -lsatsolver -lstdc++"],
  'OBJECT'   => 'SaT_wrap.o',
  'OPTIMIZE' => "-O2 $CFLAGS",
  'INC'      => "-I/usr/include/satsolver"
);

