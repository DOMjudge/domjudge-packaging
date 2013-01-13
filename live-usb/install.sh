#!/bin/sh
# This script installs DOMjudge specific stuff to a cleanly installed
# Debian image. It assumes that the Debian system is reachable via
# SSH; it copies the necessary files and then runs the installation
# script there.

# Run this script as:
# $ install.sh <hostname>

set -xe

EXTRA=/tmp/extra-files.tgz

if [ -n "$1" ]; then
	scp "$0" `dirname $0`/`basename $EXTRA` "$1:`dirname $EXTRA`"
	ssh "$1" /tmp/`basename $0`
	exit 0
else
	if [ ! -f $EXTRA ]; then
		echo "Error: file '$EXTRA' not found; did you specify the target hostname?"
		exit 1
	fi
fi

# Unpack extra files:
cd /
tar xzfk $EXTRA
rm -f $EXTRA

export DEBIAN_FRONTEND=noninteractive

# Add UvT Debian archive key:
echo -n "Adding UvT Debian APT archive key... "
apt-key add /tmp/uvt_key-with-signatures.asc
apt-get -q update

# Fix some GRUB boot loader settings:
sed -i -e 's/^\(GRUB_TIMEOUT\)=.*/\1=15/' \
       -e 's/^#\(GRUB_\(DISABLE_LINUX_RECOVERY\|INIT_TUNE\)\)/\1/' \
       -e '/GRUB_GFXMODE/a GRUB_GFXPAYLOAD_LINUX=1024x786,640x480' \
	/etc/default/grub
update-grub

# Add TTY 2-6 logins in runlevels 2-5:
sed -i 's/^\([0-9]:23\)\(:respawn:\/sbin\/getty\)/\145\2/' /etc/inittab
init q

# Enable Bash autocompletion and ls colors:
sed -i '/^#if \[ -f \/etc\/bash_completion/,/^#fi/ s/^#//' /etc/bash.bashrc
sed -i '/^#export LS_OPTIONS/,/^#alias ls=/ s/^#//' /root/.bashrc

# Write domjudge syslog to separate logfile:
cat  >> /etc/rsyslog.conf <<EOF
# DOMjudge also logs to the syslog local0 facility by default.
# Redirect these to a separate logfile.

local0.*			/var/log/domjudge/syslog.log
EOF

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
	openssh-server mysql-server apache2 sharutils php-geshi \
	gcc g++ openjdk-6-jdk openjdk-6-jre-headless

dpkg -i /tmp/domjudge-*.deb || apt-get -q update && apt-get install -f -q -y

# Set MySQL server to listen on external IP and increase some parameters:
sed -i -e 's/^#*\(bind-address.*=\) [0-9\.]*/\1 0.0.0.0/' \
       -e 's/^#*\(max_connections.*=\) [0-9]*/\1 1000/' \
       -e 's/^#*\(max_allowed_packet.*=\) .*/\1 128M/' \
	/etc/mysql/my.cnf

# Enable domserver/judgehost services at specific runlevels
update-rc.d mysql              disable 2 4
update-rc.d apache2            disable 2 4
update-rc.d domjudge-judgehost disable 2 3

# Allow larger file uploads:
sed -i '/^#<IfModule mod_php/,/<\/IfModule/ s/^#//' /etc/domjudge/apache.conf

# Include DOMjudge apache configuration snippet:
ln -s /etc/domjudge/apache.conf /etc/apache2/sites-enabled/domjudge.conf

# Move jury/plugin interface password files in place and fix
# permissions (only do this after installing DOMjudge packages):
mv /tmp/htpasswd-jury /tmp/htpasswd-plugin /etc/domjudge
chown root:www-data /etc/domjudge/htpasswd-*

# Build DOMjudge chroot environment:
dj_make_chroot

# Prebuild locate database (in background):
/etc/cron.daily/mlocate &

echo "Done installing."
