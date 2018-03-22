#!/bin/bash -e

function file_or_env {
    file=${1}_FILE
    if [ ! -z "${!file}" ]; then
        cat "${!file}"
    else
        echo -n ${!1}
    fi
}

echo "[..] Setting timezone"
ln -snf /usr/share/zoneinfo/${CONTAINER_TIMEZONE} /etc/localtime
echo ${CONTAINER_TIMEZONE} > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo "[ok] Container timezone set to: ${CONTAINER_TIMEZONE}"; echo

cd /opt/domjudge/judgehost

JUDGEDAEMON_PASSWORD=$(file_or_env JUDGEDAEMON_PASSWORD)

echo "[..] Setting up restapi file"
if [[ -f /opt/domjudge/judgehost/legacy ]]
then
  echo "default	${DOMSERVER_BASEURL}api	${JUDGEDAEMON_USERNAME}	${JUDGEDAEMON_PASSWORD}" > etc/restapi.secret
else
  echo "default	${DOMSERVER_BASEURL}api/v4	${JUDGEDAEMON_USERNAME}	${JUDGEDAEMON_PASSWORD}" > etc/restapi.secret
fi
echo "[ok] Restapi file set up"; echo

echo "[..] Setting up cgroups"
bin/create_cgroups
echo "[ok] cgroups set up"; echo

if ! id domjudge-run-${DAEMON_ID} > /dev/null 2>&1; then
  useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-${DAEMON_ID}
fi
exec sudo -u domjudge /opt/domjudge/judgehost/bin/judgedaemon -n ${DAEMON_ID}
