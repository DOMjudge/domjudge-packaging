#!/bin/bash -e

echo "[..] Setting timezone"
ln -snf /usr/share/zoneinfo/${CONTAINER_TIMEZONE} /etc/localtime
echo ${CONTAINER_TIMEZONE} > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo "[ok] Container timezone set to: ${CONTAINER_TIMEZONE}"; echo

cd /opt/domjudge/judgehost

echo "[..] Setting up restapi file"
echo "default	${DOMSERVER_BASEURL}api	${JUDGEDAEMON_USERNAME}	${JUDGEDAEMON_PASSWORD}" > etc/restapi.secret
echo "[ok] Restapi file set up"; echo

useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-${DAEMON_ID}
exec sudo -u domjudge /opt/domjudge/judgehost/bin/judgedaemon -n ${DAEMON_ID}
