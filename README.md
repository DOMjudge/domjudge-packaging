# DOMjudge packaging repository

This repository contains packaging code for DOMjudge in various
subdirectories. Below some information on these.


## DOMjudge Debian packaging HOWTO

The Debian packaging is located under `debian`.

Make sure you have installed the meta-package `packaging-dev` and the
DOMjudge build dependencies as specified in the admin manual.

Take a `domjudge-x.y.z.tar.gz` tarball and rename/symlink it to
`domjudge_x.y.z.orig.tar.gz`.

Extract it. Copy in the `debian` directory into this directory and
chdir to `domjudge-x.y.z/`.

Run from that position something like
`dch -v x.y.z-1 -m "New upstream release."`

Run `debuild`.

If everything was in order you will now get a .dsc (source package)
and several .deb's (binary package). If not, find out why and fix it.

Finally, if you're one of the DOMjudge maintainers, upload the package
to the DOMjudge Debian repository. When the packages are available on
domjudge@domjudge, run something like `dput domjudge_x.y.z-1_amd64.changes`.
Alternatively, set up `~/.dput.cf` to upload from your machine.
Then as domjudge@domjudge run `mini-dinstall`.


## DOMjudge-live image

Under `live-image` some packaging scripts are available to build a VM
image to run DOMjudge from without installing it; this can for example
be installed on a USB stick or run with Qemu, virtualbox or VMware.
This image is based on Debian and the DOMjudge Debian packages.

See `live-image/README` for more details. Note that most of the process
of generating a complete image is automated, but not completely.
