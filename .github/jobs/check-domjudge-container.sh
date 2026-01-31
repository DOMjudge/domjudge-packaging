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
MYSQL_ROOT_PASSWORD=rootpw # ggignore
MYSQL_USER=domjudge
MYSQL_PASSWORD=djpw        # ggignore
MYSQL_DATABASE=domjudge
DJ_DB_BARE=0
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
curl http://localhost:12345/public

# Gather passwords according to README.md
PASS_ADMIN=$(docker exec domserver cat /opt/domjudge/domserver/etc/initial_admin_password.secret)

# Currently gives [unknown]
PASS_JUDGEHOST=$(docker exec domserver cat /opt/domjudge/domserver/etc/restapi.secret)
if [ -z "$PASS_ADMIN" ] || [ -z "$PASS_JUDGEHOST" ]; then
  echo "Gathering passwords failed"
  exit 1
fi
PASS_ADMIN=$(docker exec domserver /opt/domjudge/domserver/webapp/bin/console --no-ansi domjudge:reset-user-password admin --no-ansi | sed 's/\\$//' | sed 's/[[:space:]]*$//' | grep admin |  grep -o '[^ ]*$')
HTTP_CODE=$(curl -u "admin:${PASS_ADMIN}" -o /dev/null -s -w "%{http_code}\n" http://localhost:12345/api/user)
if [ "$HTTP_CODE" -ne "200" ]; then
  echo "Failed authentication, reset failed or format changed"
fi

# Verify that we can restart services
for service in php nginx; do
  docker exec domserver supervisorctl restart "$service"
done

# Get more detailed health info
docker ps
docker inspect dj-mariadb
docker inspect domserver
HEALTH=$(docker inspect domserver | jq '.[0].State.Health.Status')
if [ "$HEALTH" != '"healthy"' ]; then
  exit 1
fi

# Search for incorrect permissions
for IMG in domserver judgehost default-judgehost-chroot icpc-judgehost-chroot full-judgehost-chroot; do
  files=$(docker run --rm --pull=never "${REPOSITORY_ORGANIZATION}/${IMG}:${DOMJUDGE_VERSION}" find / -xdev -perm -o+w ! -type l ! \( -type d -a -perm -+t \) ! -type c)
  if [ -n "$files" ]; then
    echo "error: image domjudge/$IMG:${DOMJUDGE_VERSION} contains world-writable files:" >&2
    printf "%s\n" "$files" >&2
    exit 1
  fi
done
