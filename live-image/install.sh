#!/bin/sh
# This script installs DOMjudge specific stuff to a cleanly installed
# Debian image. It assumes that the Debian system is reachable via
# SSH; it copies the necessary files and then runs the installation
# script there.

# Run this script as:
# $ install.sh <hostname> [options]
#
# options:
#  -p <proxy>     APT proxy URL to use during installation
#  -v <version>   Debian package version of DOMjudge to install

set -e

EXTRA=/tmp/extra-files.tgz

CHROOTDIR=/var/lib/domjudge/chroot

# Check if this script is started from the host:
if [ "$1" = "ON_TARGET" ]; then
	ON_TARGET_HOST=1
	shift
fi

while getopts ':p:v:' OPT ; do
	case $OPT in
		p)	DEBPROXY="$OPTARG" ;;
		v)	DJDEBVERSION="$OPTARG" ;;
		:)
			echo "Error: option '$OPTARG' requires an argument."
			exit 1
			;;
		?)
			echo "Error: unknown option '$OPTARG'."
			exit 1
			;;
		*)
			echo "Error: unknown error reading option '$OPT', value '$OPTARG'."
			exit 1
			;;
	esac
done
ARGS="$*"
shift $((OPTIND-1))

if [ -z "$ON_TARGET_HOST" ]; then
	if [ -z "$1" ]; then
		echo "Error: no target hostname specified."
		exit 1
	fi
	TARGET="$1"
	shift
	make -C "$(dirname "$0")" "$(basename $EXTRA)"
	scp "$0" "$(dirname "$0")/$(basename $EXTRA)" "root@$TARGET:$(dirname $EXTRA)"
	# shellcheck disable=SC2029
	ssh "root@$TARGET" "/tmp/$(basename "$0") ON_TARGET $ARGS"
	exit 0
fi

export DEBPROXY DJDEBVERSION

# Unpack extra files:
cd /
tar xzf $EXTRA
rm -f $EXTRA

export DEBIAN_FRONTEND=noninteractive

echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf

# Update packages, we've added sources and keys:
apt-get -q update
apt-get -q -y upgrade

# Fix some GRUB boot loader settings:
sed -i -e 's/^\(GRUB_DEFAULT\)=.*/\1=2/' \
       -e 's/^\(GRUB_TIMEOUT\)=.*/\1=15/' \
       -e 's/^#\(GRUB_\(DISABLE.*_RECOVERY\|INIT_TUNE\)\)/\1/' \
       -e '/GRUB_GFXMODE/a GRUB_GFXPAYLOAD_LINUX=1024x786,640x480' \
	/etc/default/grub
update-grub

# Mount /tmp as tmpfs:
sed -i '/^proc/a tmpfs		/tmp		tmpfs	size=512M,mode=1777	0	0' /etc/fstab

# Enable Bash autocompletion and ls colors:
sed -i '/^#if \[ -f \/etc\/bash_completion/,/^#fi/ s/^#//' /etc/bash.bashrc
sed -i '/^# *export LS_OPTIONS/,/^# *alias ls=/ s/^# *//' /root/.bashrc

# Disable persistent storage and network udev rules:
cd /lib/udev/rules.d
if [ -f 75-persistent-net-generator.rules ]; then
	mkdir -p disabled
	mv 75-persistent-net-generator.rules disabled
fi
cd -

# Install packages including DOMjudge:
debconf-set-selections <<EOF
domjudge-domserver	domjudge-domserver/dbconfig-install	boolean	true
domjudge-judgehost	domjudge-judgehost/dbconfig-install	boolean	true

EOF

apt-get install -q -y \
	apt-transport-https \
	openssh-server mariadb-server apache2 sudo php-zip \
	gcc g++ default-jdk default-jre-headless fp-compiler \
	python-minimal python3-minimal gnat gfortran mono-mcs \
	ntp debootstrap cgroup-bin libcgroup1 \
	enscript lpr zip unzip mlocate

# Use DOMjudge debian packages if present under /tmp:
# shellcheck disable=SC2144
if [ -f /tmp/domjudge-domserver_*.deb ]; then
	dpkg -i /tmp/domjudge-common_*.deb    /tmp/domjudge-doc_*.deb \
	        /tmp/domjudge-domserver_*.deb /tmp/domjudge-judgehost_*.deb \
	|| apt-get -q -y -f install
else
	USEVERSION="${DJDEBVERSION:+=$DJDEBVERSION}"
	apt-get install -q -y \
	        domjudge-domserver"${USEVERSION}" domjudge-doc"${USEVERSION}" \
	        domjudge-judgehost"${USEVERSION}"
fi

# Overwrite init script to fix start/restart:
mv /etc/init.d/domjudge-judgehost.new /etc/init.d/domjudge-judgehost

# Do not have stuff listening that we don't use:
apt-get remove -q -y --purge portmap nfs-common

# Add DOMjudge-live specific and sample DB content:
cat /tmp/mysql_db_livedata.sql \
    /usr/share/domjudge/sql/mysql_db_examples.sql \
    /usr/share/domjudge/sql/mysql_db_files_examples.sql \
| mysql domjudge

# Configure domserver/judgehost systemd target (aka. "runlevels"):
systemctl set-default multi-user.target
systemctl disable apache2.service mysql.service domjudge-judgehost.service

sed -i '/^CGROUPDIR=/c CGROUPDIR=/sys/fs/cgroup' /etc/init.d/domjudge-judgehost

# Make some files available in the doc root
ln -s /usr/share/doc/domjudge-doc/examples/*.pdf             /var/www/html/
ln -s /usr/share/domjudge/webapp/web/images/DOMjudgelogo.png /var/www/html/

# Build DOMjudge chroot environment (first reclaim some space):
apt-get -q clean
dj_make_chroot -i python3-minimal,mono-mcs,bash-static

# Copy (static) bash binary to location that is available within chroot
cp -a $CHROOTDIR/bin/bash-static $CHROOTDIR/usr/local/bin/bash

# Workaround: put nameserver in chroot, it will otherwise have the nameserver
# of the build system which will not work elsewhere.
echo "nameserver 8.8.8.8" > $CHROOTDIR/etc/resolv.conf

# Do some cleanup to prepare for creating a releasable image:
echo "Doing final cleanup, this can take a while..."
apt-get -q clean
rm -f /root/.ssh/authorized_keys /root/.bash_history

# Cleanup proxy settings used during installation:
if [ -n "$DEBPROXY" ]; then
	sed -i "/http::Proxy/d" /etc/apt/apt.conf
	sed -i "/http::Proxy/d" $CHROOTDIR/etc/apt/apt.conf
fi

# Prebuild locate database:
/etc/cron.daily/mlocate

# Remove SSH host keys to regenerate them on next first boot:
rm -f /etc/ssh/ssh_host_*

# Replace /etc/issue with live image specifics:
mv /etc/issue /etc/issue.orig
cat > /etc/issue.djlive <<EOF
DOMjudge-live running on $(cat /etc/issue.orig)

DOMjudge-live image generated on $(date)
DOMjudge Debian package version $(dpkg -s domjudge-common | sed -n 's/^Version: //p')

EOF
cp /etc/issue.djlive /etc/issue.djlive-default-passwords
cat /tmp/domjudge-default-passwords >> /etc/issue.djlive-default-passwords
ln -s /etc/issue.djlive-default-passwords /etc/issue

# Set default admin password:
/usr/local/sbin/dj_live adminpass admin
rm -f /etc/domjudge/initial_admin_password.secret

# Remove DOMjudge cache for password changes and space:
rm -rf /var/cache/domjudge/prod

# Unmount swap and zero empty space to improve compressibility:
swapoff -a
cat /dev/zero > /dev/sda1 2>/dev/null || true
cat /dev/zero > /zerofile 2>/dev/null || true
sync
rm -f /zerofile

# Recreate swap partition and use label to mount swap:
mkswap -L swap /dev/sda1
sed -i 's/^UUID=[a-z0-9-]* *\(.*swap.*\)$/LABEL=swap      \1/' /etc/fstab

# The old swap UUID isn't valid anymore for resume:
sed -i 's/^RESUME=.*$/RESUME=/' /etc/initramfs-tools/conf.d/resume
update-initramfs -u -k all

echo "Done installing, halting system..."

# Reboot in Qemu since a halt hangs the emulation:
if grep 'QEMU' /proc/cpuinfo >/dev/null ; then
	reboot
else
	halt
fi
