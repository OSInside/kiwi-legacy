KIWI Custom files analyser
==========================

Introduction
------------

kiwi has created a set of files which does not belong to any
packagemanger or repository kiwi knows about. These information
is called custom/unpackaged files. You can find a raw list of
this data in the file

* custom.files

kiwi does not automatically sync all this information into the
description because on real world machines this could be a huge
set of information which are displayed in a nice way on the
kiwi created report page but normally you want only a specific
subset of this data to be synced and content controlled.

How to manage custom files
--------------------------

most people find it useful to control the contents of for
example '/etc' which you will find out has a lot of customfiles
which do not belong to any package but are pretty important for
the system to operate. In order to let the kiwi analyser take
care for this information store a file called:

* custom.sync

in the git repo and commit it. The contents of the file are used
by an rsync process as --files-from input. Thus to sync all
contents of '/etc' add the line

* /etc/

to the custom.sync file. Any subsequent call of kiwi --describe
will now care for /etc and track it via the git system
