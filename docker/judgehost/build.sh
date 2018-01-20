#!/bin/bash -e

cd /domjudge-src/domjudge*
echo "default	http://localhost/api/v4	dummy	dummy" > etc/restapi.secret
sudo -u domjudge ./configure -with-baseurl=http://localhost/
sudo -u domjudge make judgehost
make install-judgehost
