#!/bin/sh

sudo apt install acl composer debootstrap g++ gcc libcgroup-dev lsof make \
                 mariadb-server nginx ntp php php-bcmath php-cli php-curl \
                 php-fpm php-gd php-intl php-json php-mbstring php-mysql \
                 php-xml php-zip pkg-config procps pv python3-yaml sudo unzip zip

cd docker-gitlabci || exit 1
  wget https://github.com/DOMjudge/domjudge/archive/refs/heads/main.zip
  unzip main.zip
  cd domjudge-main || exit 1
    chroot_path="$(pwd)/chroot"
    make configure
    ./configure --with-domjudge-user=domjudge --with-judgehost_chrootdir="${chroot_path}"
  cd misc-tools || exit 1
    make dj_make_chroot
    sudo ./dj_make_chroot
    sudo tar -cvf "${chroot_path}.tar" "${chroot_path}"
