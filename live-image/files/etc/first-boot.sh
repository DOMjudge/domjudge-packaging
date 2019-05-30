#!/bin/sh -e
#
# This script is run one time only at the first boot of this
# DOMjudge-live image. It (re)generates host specific things such as
# SSH host keys, root passwords.

dpkg-reconfigure openssh-server

# Generate new random password for domjudge DB and API; first make
# sure that MySQL is running.
service mysql start
/usr/local/sbin/dj_live dbapipass

service domjudge-judgehost restart

exit 0
