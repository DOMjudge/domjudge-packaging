#!/bin/sh

# This script is only relevant for within the CI, it tests the newly created domserver container
# Usage: $0 [options]... [command]

if [ $# -ne 2 ]; then
    echo "Usage: $0 <DOMJUDGE_VERSION> <ORGANIZATION>"
    exit 1
fi

DOCKER_NETWORK=djn
DOCKER_DB=dj-mariadb
DOCKER_DOMSERVER=domserver
DOCKER_JUDGEHOST=judgehost
MYSQL_ROOT_PASSWORD=rootpw # ggignore
MYSQL_USER=domjudge
MYSQL_PASSWORD=djpw        # ggignore
MYSQL_DATABASE=domjudge
DJ_DB_BARE=1
DOMJUDGE_VERSION="$1"
REPOSITORY_ORGANIZATION="$2"

set -eux

# See README.md
docker network create "$DOCKER_NETWORK"
MYSQL_SETTINGS="-e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD -e MYSQL_USER=$MYSQL_USER -e MYSQL_PASSWORD=$MYSQL_PASSWORD -e MYSQL_DATABASE=$MYSQL_DATABASE"

# Start the database container
# shellcheck disable=SC2086 # We want the $MYSQL_SETTINGS to be split as those are extra variables
docker run -d --name "$DOCKER_DB" --net "$DOCKER_NETWORK" $MYSQL_SETTINGS -p 13306:3306 mariadb --max-connections=1000 --max_allowed_packet=256M

# Booting seems to take 10s, directly display the logs when they come in.
timeout --preserve-status 15 docker logs -f "$DOCKER_DB" || true

# Start the domserver container
# shellcheck disable=SC2086 # We want the $MYSQL_SETTINGS to be split as those are extra variables
docker run -d --pull=never --name "$DOCKER_DOMSERVER"  --net "$DOCKER_NETWORK" \
  -e MYSQL_HOST="$DOCKER_DB" -e DJ_DB_INSTALL_BARE="$DJ_DB_BARE" $MYSQL_SETTINGS \
  -e CONTAINER_TIMEZONE="Iceland" -e FPM_MAX_CHILDREN="20" -e WEBAPP_BASEURL="/base/" \
  -p 12345:80 "${REPOSITORY_ORGANIZATION}/domserver:${DOMJUDGE_VERSION}"

# Inspect the network
docker network ls
docker network inspect "$DOCKER_NETWORK"
docker exec -t "$DOCKER_DB" getent hosts "$DOCKER_DOMSERVER"
docker exec -t "$DOCKER_DOMSERVER" getent hosts "$DOCKER_DB"

# Show that we see the port on the host
ss -tulpn

# Connect to SQL
docker exec -t "$DOCKER_DB" mariadb -uroot -p"$MYSQL_ROOT_PASSWORD"                     -e "SHOW DATABASES;"
docker exec -t "$DOCKER_DB" mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -D"$MYSQL_DATABASE" -e "SHOW TABLES;"
docker exec -t "$DOCKER_DOMSERVER" mysqlshow -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$DOCKER_DB" "$MYSQL_DATABASE"

# Show we indeed waited 3*60 seconds for 10*10 seconds checks,
timeout --preserve-status 180 docker logs -f "$DOCKER_DOMSERVER" || true

# Check if the default container comes up correctly
curl http://localhost:12345/base/public

# Gather passwords according to README.md
PASS_ADMIN=$(docker exec domserver cat /opt/domjudge/domserver/etc/initial_admin_password.secret)

# Currently gives [unknown]
PASS_JUDGEHOST=$(docker exec domserver cat /opt/domjudge/domserver/etc/restapi.secret | cut -s -f4)
if [ -z "$PASS_ADMIN" ] || [ -z "$PASS_JUDGEHOST" ]; then
  echo "Gathering passwords failed"
  exit 1
fi
PASS_ADMIN=$(docker exec domserver /opt/domjudge/domserver/webapp/bin/console --no-ansi domjudge:reset-user-password admin --no-ansi | sed 's/\\$//' | sed 's/[[:space:]]*$//' | grep admin |  grep -o '[^ ]*$')
HTTP_CODE=$(curl -u "admin:${PASS_ADMIN}" -o /dev/null -s -w "%{http_code}\n" http://localhost:12345/base/api/user)
if [ "$HTTP_CODE" -ne "200" ]; then
  echo "Failed authentication, reset failed or format changed"
  exit 1
fi

# Verify that we can restart services
for service in php nginx; do
  docker exec domserver supervisorctl restart "$service"
done

# Install examples
docker exec -t "$DOCKER_DB" mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -D"$MYSQL_DATABASE" -e "INSERT userrole VALUES (1, 3);"
docker exec -t "$DOCKER_DB" mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -D"$MYSQL_DATABASE" -e "UPDATE user SET teamid = 1 WHERE userid = 1;"
docker exec -t "$DOCKER_DB" mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -D"$MYSQL_DATABASE" -e "SELECT * FROM userrole;"
docker exec -t "$DOCKER_DB" mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -D"$MYSQL_DATABASE" -e "SELECT * FROM user;"
docker exec -t "$DOCKER_DOMSERVER" /opt/domjudge/domserver/bin/dj_setup_database -s install-examples

# Search for incorrect permissions
for IMG in domserver judgehost default-judgehost-chroot icpc-judgehost-chroot full-judgehost-chroot; do
  files=$(docker run --rm --pull=never "${REPOSITORY_ORGANIZATION}/${IMG}:${DOMJUDGE_VERSION}" find / -xdev -perm -o+w ! -type l ! \( -type d -a -perm -+t \) ! -type c)
  if [ -n "$files" ]; then
    echo "error: image domjudge/$IMG:${DOMJUDGE_VERSION} contains world-writable files:" >&2
    printf "%s\n" "$files" >&2
    exit 1
  fi
done

# Show cgroup config of host
cat /proc/cmdline

# Start judgehost to judge the submissions
docker run -d --pull=never --name "$DOCKER_JUDGEHOST"  -v /sys/fs/cgroup:/sys/fs/cgroup --privileged --cgroupns=host --init --net "$DOCKER_NETWORK" \
  -e CONTAINER_TIMEZONE="America/Denver" -e DOMSERVER_BASEURL="http://domserver/base/" \
  -e JUDGEDAEMON_PASSWORD="$PASS_JUDGEHOST" -e JUDGEDAEMON_USERNAME="judgehost" \
  -e RUN_USER_UID_GID=62861 -e DAEMON_ID=1 \
  "${REPOSITORY_ORGANIZATION}/judgehost:${DOMJUDGE_VERSION}"

# Inspect the network (again) with new container
docker network ls
docker network inspect "$DOCKER_NETWORK"
docker exec -t "$DOCKER_DOMSERVER" getent hosts "$DOCKER_JUDGEHOST"
docker exec -t "$DOCKER_JUDGEHOST" getent hosts "$DOCKER_DOMSERVER"

# It seems to take 4min so gather the full output for that time and check if we're finished afterwards.
timeout --preserve-status 240 docker logs -f "$DOCKER_JUDGEHOST" || true

CNTR=0
SINCE=0
mkdir /tmp/docker-logs
docker logs --since "$SINCE" "$DOCKER_JUDGEHOST" > /tmp/docker-logs/judgehost_log 2> /tmp/docker-logs/judgehost_err

while true; do
    CNTR=$((CNTR+1))
    NEW_SINCE=$(date --iso-8601=seconds)
    LOGS=$(docker logs --since "$SINCE" "$DOCKER_JUDGEHOST" 2>&1)
    if echo "$LOGS" | grep -q "No submissions in queue (for endpoint default), waiting..."; then
        break
    fi
    if [ "$CNTR" -eq 18 ]; then
        exit 1
    fi
    sleep 10
    SINCE="$NEW_SINCE"
done

# Verify that judging worked
JUDGEMENT_URL="http://localhost:12345/base/api/v4/contests/demo/judgements?result=CORRECT"
NUMBER_JUDGEMENTS=$(curl -u "admin:${PASS_ADMIN}" "$JUDGEMENT_URL" | jq length)
if [ "$NUMBER_JUDGEMENTS" -ne "27" ]; then
  exit 1
fi

# Get more detailed health info
docker ps
docker inspect "$DOCKER_DB"
docker inspect "$DOCKER_DOMSERVER"
# We don´t have a health command for the judgehost
#docker inspect judgehost
for container in $DOCKER_DB $DOCKER_DOMSERVER; do
  HEALTH=$(docker inspect "$container" | jq '.[0].State.Health.Status')
  if [ "$HEALTH" != '"healthy"' ]; then
    exit 1
  fi
done
