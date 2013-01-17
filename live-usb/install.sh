#!/bin/sh
# This script installs DOMjudge specific stuff to a cleanly installed
# Debian image. It assumes that the Debian system is reachable via
# SSH; it copies the necessary files and then runs the installation
# script there.

# Run this script as:
# $ install.sh <hostname>

set -e

EXTRA=/tmp/extra-files.tgz

if [ -n "$1" ]; then
	scp "$0" `dirname $0`/`basename $EXTRA` "root@$1:`dirname $EXTRA`"
	ssh "root@$1" /tmp/`basename $0`
	exit 0
else
	if [ ! -f $EXTRA ]; then
		echo "Error: file '$EXTRA' not found; did you specify the target hostname?"
		exit 1
	fi
fi

# Unpack extra files:
cd /
tar xzf $EXTRA
rm -f $EXTRA

export DEBIAN_FRONTEND=noninteractive

# Add UvT Debian archive key:
echo -n "Adding UvT Debian APT archive key... "
apt-key add /tmp/uvt_key-with-signatures.asc
apt-get -q update

echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf

# Fix some GRUB boot loader settings:
sed -i -e 's/^\(GRUB_TIMEOUT\)=.*/\1=15/' \
       -e 's/^#\(GRUB_\(DISABLE_LINUX_RECOVERY\|INIT_TUNE\)\)/\1/' \
       -e '/GRUB_GFXMODE/a GRUB_GFXPAYLOAD_LINUX=1024x786,640x480' \
	/etc/default/grub
update-grub

# Mount /tmp as tmpfs:
sed -i '/^proc/a tmpfs		/tmp		tmpfs	size=512M,mode=1777	0	0' /etc/fstab

# Add TTY 2-6 logins in runlevels 2-5:
sed -i 's/^\([0-9]:23\)\(:respawn:\/sbin\/getty\)/\145\2/' /etc/inittab
init q

# Enable Bash autocompletion and ls colors:
sed -i '/^#if \[ -f \/etc\/bash_completion/,/^#fi/ s/^#//' /etc/bash.bashrc
sed -i '/^#export LS_OPTIONS/,/^#alias ls=/ s/^#//' /root/.bashrc

# Disable persistent storage and network udev rules:
cd /lib/udev/rules.d
mkdir disabled
mv 75-persistent-net-generator.rules disabled
mv 75-cd-aliases-generator.rules     disabled
cd -

# Pregenerate random password for DOMjudge database, so that we can
# set it the same for domserver and judgehost packages.
DBPASSWORD=`date +%s | sha256sum | base64 | head -c 20`

# Install packages including DOMjudge:
debconf-set-selections <<EOF
mysql-server-5.1	mysql-server/root_password	password	domjudge
mysql-server-5.1	mysql-server/root_password_again		password	domjudge

domjudge-domserver	domjudge-domserver/mysql/app-pass       password	$DBPASSWORD
domjudge-domserver	domjudge-domserver/app-password-confirm	password	$DBPASSWORD
domjudge-domserver	domjudge-domserver/dbconfig-install	boolean	true
domjudge-domserver	domjudge-domserver/mysql/admin-user	string	root
domjudge-domserver	domjudge-domserver/mysql/admin-pass	password	domjudge

domjudge-judgehost	domjudge-judgehost/mysql/app-pass       password	$DBPASSWORD
domjudge-judgehost	domjudge-judgehost/app-password-confirm	password	$DBPASSWORD
domjudge-judgehost	domjudge-judgehost/dbconfig-install	boolean	true
domjudge-judgehost	domjudge-judgehost/mysql/admin-user	string	root
domjudge-judgehost	domjudge-judgehost/mysql/admin-pass	password	domjudge

EOF

apt-get install -q -y \
	openssh-server mysql-server apache2 php-geshi sudo \
	gcc g++ openjdk-6-jdk openjdk-6-jre-headless fp-compiler ghc \
	ntp phpmyadmin

dpkg -i /tmp/domjudge-*.deb || apt-get -q update && apt-get install -f -q -y

# do not have stuff listening that we don't use
apt-get remove --purge portmap nfs-common
apt-get clean

# Add DOMjudge-live specific DB content:
mysql -u domjudge_jury --password=$DBPASSWORD domjudge < /tmp/mysql_db_livedata.sql

# Enable domserver/judgehost services at specific runlevels
update-rc.d mysql              disable 2 4
update-rc.d apache2            disable 2 4
update-rc.d domjudge-judgehost disable 2 3

# Include DOMjudge apache configuration snippet:
ln -s /etc/domjudge/apache.conf /etc/apache2/conf.d/domjudge.conf

# Move jury/plugin interface password files in place and fix
# permissions (only do this after installing DOMjudge packages):
mv /tmp/htpasswd-jury /tmp/htpasswd-plugin /etc/domjudge
chown root:www-data /etc/domjudge/htpasswd-*

# Build DOMjudge chroot environment:
dj_make_chroot

# Prebuild locate database (in background):
/etc/cron.daily/mlocate &

echo "Done installing."
