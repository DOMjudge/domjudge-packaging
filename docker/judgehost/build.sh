#!/bin/bash -e

cd /domjudge-src/domjudge*
USE_LEGACY=0
if [[ ! -d webapp ]]
then
  USE_LEGACY=1
fi
if [[ "${USE_LEGACY}" -eq "0" ]]
then
  echo "default	http://localhost/api	dummy	dummy" > etc/restapi.secret
else
  echo "default	http://localhost/api/v4	dummy	dummy" > etc/restapi.secret
fi
chown -R domjudge: .
sudo -u domjudge ./configure -with-baseurl=http://localhost/
sudo -u domjudge make judgehost
make install-judgehost
if [[ "${USE_LEGACY}" -eq "1" ]]
then
  touch /opt/domjudge/judgehost/legacy
fi
