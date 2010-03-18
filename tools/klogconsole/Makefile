#
# Makefiel for klogconsole
#
# Author: Werner Fink <werner@suse.de>
#

CC	= gcc
ifeq ($(RPM_OPT_FLAGS),)
 CFLAGS	= $(RPM_OPT_FLAGS) -Wall
else
 CFLAGS	= -O2 -pipe -Wall
endif
INSTALL	= install

all:	klogconsole

klogconsole:	klogconsole.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	$(RM) klogconsole
