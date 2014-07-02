KIWI
====

Introduction
------------

The openSUSE KIWI Image System provides an operating
system image solution for Linux supported hardware platforms as
well as for virtualization systems like Xen, VMware, etc. The KIWI
architecture was designed as a two level system. The first stage,
based on a valid software package source, creates a so called 
unpacked image according to the provided image description.
The second stage creates from a required unpacked image an
operating system image. The result of the second stage is called
a packed image or short an image.

Installation
------------

packages for kiwi are provided at the openSUSE buildservice:
http://download.opensuse.org/repositories/Virtualization:/Appliances/

Usage
-----

1. make sure you have the kiwi-templates package installed
2. build a live ISO example:

```
kiwi --build suse-XXX-JeOS -d /tmp/myimage --type iso
```

3. run your OS in a VM like kvm

```
kvm -cdrom /tmp/myimage/*.iso
```

Mailing list
------------

*  http://groups.google.com/group/kiwi-images

Contributing
------------

1. Fork it.
2. Create a branch (`git checkout -b my_kiwi`)
3. Commit your changes (`git commit -am "Added Snarkdown"`)
4. Push to the branch (`git push origin my_kiwi`)
5. Create an [Issue][1] with a link to your branch
6. Enjoy a refreshing Diet Coke and wait

also see the git-review gem

Remember to have fun :)
