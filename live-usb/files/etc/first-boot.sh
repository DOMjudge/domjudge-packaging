#!/bin/sh -e
#
# This script is run one time only at the first boot of this
# DOMjudge-live image. It (re)generates host specific things such as
# SSH host keys, root passwords.

dpkg-reconfigure openssh-server

# Generate new random password for domjudge database user; first make
# sure that MySQL is running.
service mysql start
/usr/local/sbin/dj-live genpass > /dev/null

exit 0
