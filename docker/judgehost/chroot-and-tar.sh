#!/bin/bash

# Add packages with -i "<apt package name>" here
/opt/domjudge/judgehost/bin/dj_make_chroot -i

INSTALLDEBS=gcc g++ make default-jdk-headless default-jre-headless pypy pypy3 python3 locales

chroot /chroot/domjudge/
apt-get update && apt-get dist-upgrade
apt-get clean
apt-get install $INSTALLDEBS

cd /
echo "[..] Compressing chroot"
tar -czpf /chroot.tar.gz --exclude=/chroot/tmp --exclude=/chroot/proc --exclude=/chroot/sys --exclude=/chroot/mnt --exclude=/chroot/media --exclude=/chroot/dev --one-file-system /chroot
echo "[..] Compressing judge"
tar -czpf /judgehost.tar.gz /opt/domjudge/judgehost
