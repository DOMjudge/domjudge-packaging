#!/bin/bash

sed -i.bak '/# Upgrade the system, and install\/remove packages as desired/i mkdir \"\$CHROOTDIR\/scripts\/" && cp \/scripts\/add_repositories.sh \"\$CHROOTDIR\/scripts\/" && chmod -R 755 \"\$CHROOTDIR\/scripts\/" && in_chroot \"\/scripts\/add_repositories.sh\"\n' /opt/domjudge/judgehost/bin/dj_make_chroot

# Usage: https://github.com/DOMjudge/domjudge/blob/main/misc-tools/dj_make_chroot.in#L58-L87
/opt/domjudge/judgehost/bin/dj_make_chroot -i openjdk-17-jre-headless,openjdk-17-jdk-headless,pypy3,icpc-kotlinc

cd /
echo "[..] Compressing chroot"
tar -czpf /chroot.tar.gz --exclude=/chroot/tmp --exclude=/chroot/proc --exclude=/chroot/sys --exclude=/chroot/mnt --exclude=/chroot/media --exclude=/chroot/dev --one-file-system /chroot
echo "[..] Compressing judge"
tar -czpf /judgehost.tar.gz /opt/domjudge/judgehost
