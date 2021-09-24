#!/bin/sh -eu

cd /domjudge-src/domjudge*
chown -R domjudge: .
# If we used a local source tarball, it might not have been built yet
sudo -u domjudge make configure
sudo -u domjudge ./configure -with-baseurl=http://localhost/

sudo -u domjudge echo "default	http://localhost/api	dummy	dummy" > etc/restapi.secret

sudo -u domjudge make judgehost
make install-judgehost
