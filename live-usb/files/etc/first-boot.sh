#!/bin/sh -e
#
# This script is run one time only at the first boot of this
# DOMjudge-live image. It (re)generates host specific things such as
# SSH host keys, root passwords.

dpkg-reconfigure openssh-server

exit 0


# Generate random password for system and MySQL root user.
PASS=`head -c12 /dev/urandom | base64 | head -c8 | tr '/+' 'Aa'`
SALT=`head -c12 /dev/urandom | base64 | head -c8 | tr '/+' 'Aa'`
HASH=`mkpasswd -m sha-512 $ROOTPW $SALT`

usermod -p "$HASH" root

# Use Debian administrative credentials to login to the MySQL server.
/usr/bin/mysql --defaults-file=/etc/mysql/debian.cnf mysql <<EOF
UPDATE user SET password=PASSWORD('$PASS') WHERE user='root';
FLUSH PRIVILEGES;
EOF

cat <<EOF

**********************************************************************
*** NOTE: a new password for the system and MySQL root user has    ***
*** been generated. The password is:      $PASS                 ***
**********************************************************************

This password can be used to login to this machine over SSH:
$ ssh root@<domjudge-live-hostname>

The program 'dj-live' can be used to change these passwords and
perform some other tasks. Run it as root without arguments for usage
information.

See the file '/README' for more details on this image and how to use it.

EOF
