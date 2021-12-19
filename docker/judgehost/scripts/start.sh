#!/bin/bash -e

function file_or_env {
    file=${1}_FILE
    if [ -n "${!file}" ]; then
        cat "${!file}"
    else
        echo -n "${!1}"
    fi
}

echo "[..] Setting timezone"
ln -snf "/usr/share/zoneinfo/${CONTAINER_TIMEZONE}" /etc/localtime
echo "${CONTAINER_TIMEZONE}" > /etc/timezone
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

echo "[..] Copying resolv.conf to chroot"
cp /etc/resolv.conf /chroot/domjudge/etc/resolv.conf
echo "[ok] resolv.conf copied"; echo

if ! id "domjudge-run-${DAEMON_ID}" > /dev/null 2>&1; then
  groupadd -g "${RUN_USER_UID_GID}" domjudge-run
  useradd -u "${RUN_USER_UID_GID}" -N -d /nonexistent -g nogroup -s /bin/false "domjudge-run-${DAEMON_ID}"
fi
exec sudo -u domjudge DOMJUDGE_CREATE_WRITABLE_TEMP_DIR="${DOMJUDGE_CREATE_WRITABLE_TEMP_DIR}" /opt/domjudge/judgehost/bin/judgedaemon -n "${DAEMON_ID}"
