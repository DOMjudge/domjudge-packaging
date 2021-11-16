#!/bin/bash

# Add packages with -i "<apt package name>" here
/opt/domjudge/judgehost/bin/dj_make_chroot -y

# CHROOTDIR=/chroot/domjudge
# INSTALLDEBS="gcc g++ make default-jdk-headless default-jre-headless pypy pypy3 python3 locales"

# mount -t proc proc "$CHROOTDIR"/proc
# mount -t sysfs sysfs "$CHROOTDIR"/sys
# mount --bind /dev/pts "$CHROOTDIR"/dev/pts

# chroot "$CHROOTDIR" /bin/sh -c "apt-get update && apt-get dist-upgrade"
# chroot "$CHROOTDIR" /bin/sh -c "apt-get clean"
# chroot "$CHROOTDIR" /bin/sh -c "apt-get install $INSTALLDEBS"
# chroot "$CHROOTDIR" /bin/sh -c "apt-get clean"

# umount "$CHROOTDIR/dev/pts"
# umount "$CHROOTDIR/sys"
# umount "$CHROOTDIR/proc"

cd /
echo "[..] Compressing chroot"
tar -czpf /chroot.tar.gz --exclude=/chroot/tmp --exclude=/chroot/proc --exclude=/chroot/sys --exclude=/chroot/mnt --exclude=/chroot/media --exclude=/chroot/dev --one-file-system /chroot
echo "[..] Compressing judge"
tar -czpf /judgehost.tar.gz /opt/domjudge/judgehost
