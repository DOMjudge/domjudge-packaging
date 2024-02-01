#!/bin/bash -e

function file_or_env {
    file=${1}_FILE
    if [ -n "${!file}" ]; then
        cat "${!file}"
    else
        echo -n "${!1}"
    fi
}

echo "[..] Changing user/group ID"
sudo groupmod -g "${GID}" domjudge
sudo usermod -u "${UID}" domjudge
echo "[ok] User ID set to ${UID} and group ID set to ${GID}"; echo

echo "[..] Setting timezone"
sudo ln -snf "/usr/share/zoneinfo/${CONTAINER_TIMEZONE}" /etc/localtime
echo "${CONTAINER_TIMEZONE}" | sudo tee /etc/timezone
sudo dpkg-reconfigure -f noninteractive tzdata
echo "[ok] Container timezone set to: ${CONTAINER_TIMEZONE}"; echo

echo "[..] Changing nginx and PHP configuration settings"
# Set correct settings
sudo sed -ri -e "s/^user.*/user domjudge;/" /etc/nginx/nginx.conf
for VERSION in $PHPSUPPORTED
do
  sudo sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = 100M/" \
      -e "s/^post_max_size.*/post_max_size = 100M/" \
      -e "s/^memory_limit.*/memory_limit = 2G/" \
      -e "s/^max_file_uploads.*/max_file_uploads = 200/" \
      -e "s#^;date\.timezone.*#date.timezone = ${CONTAINER_TIMEZONE}#" \
      "/etc/php/${VERSION}/fpm/php.ini"
  sudo sed -ri -e "s#^;date\.timezone.*#date.timezone = ${CONTAINER_TIMEZONE}#" \
      "/etc/php/${VERSION}/cli/php.ini"
done
echo "[ok] Done changing nginx and PHP configuration settings"; echo

if [ -z "$PROJECT_DIR" ]
then
  PROJECT_DIR=/domjudge
fi

cd "$PROJECT_DIR"

if [[ ! -f README.md ]] || ! grep -q DOMjudge README.md
then
  echo "DOMjudge sources not found. Did you add a volume with your DOMjudge checkout at ${PROJECT_DIR}?"
  exit 1
fi

MYSQL_PASSWORD=$(file_or_env MYSQL_PASSWORD)
MYSQL_ROOT_PASSWORD=$(file_or_env MYSQL_ROOT_PASSWORD)

cat > /home/domjudge/.my.cnf <<EOF
[client]
host=${MYSQL_HOST}
user=root
password=${MYSQL_ROOT_PASSWORD}
EOF

echo "[..] Updating database credentials file"
echo "dummy:${MYSQL_HOST}:${MYSQL_DATABASE}:${MYSQL_USER}:${MYSQL_PASSWORD}" > etc/dbpasswords.secret
echo "[ok] Updated database credentials file"; echo

if [ "${DJ_SKIP_MAKE}" -eq "1" ]
then
  echo "Skipping maintainer-mode install for DOMjudge"
else
  echo "[..] Performing maintainer-mode install for DOMjudge"
  make maintainer-conf CONFIGURE_FLAGS="--with-baseurl=http://localhost/ --with-webserver-group=domjudge"
  make maintainer-install
  echo "[ok] DOMjudge installed in Maintainer-mode"; echo
fi

echo "[..] Setting up bind mount and correct permissions for judgings"
sudo mkdir -p /domjudge-judgings
sudo mount -o bind /domjudge-judgings "${PROJECT_DIR}/output/judgings"
sudo chown -R domjudge output
echo "[ok] Done setting up permissions"

# Sometimes when running `docker-compose up` we're too fast at this step
DB_UP=3
while [ $DB_UP -gt 0 ]
do
  echo "[..] Checking database connection"
  if ! mysqlshow -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" "${MYSQL_DATABASE}" > /dev/null 2>&1
  then
    echo "MySQL database ${MYSQL_DATABASE} not yet found on host ${MYSQL_HOST};"
    (( DB_UP-- ))
    sleep 30s
  else
    DB_UP=0
  fi
done

if ! mysqlshow -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" "${MYSQL_DATABASE}" > /dev/null 2>&1
then
  echo "MySQL database ${MYSQL_DATABASE} not found on host ${MYSQL_HOST}; exiting"
  exit 1
fi

if ! sudo bin/dj_setup_database -uroot -p"${MYSQL_ROOT_PASSWORD}" status > /dev/null 2>&1
then
  echo "  Database not installed; installing..."
  sudo bin/dj_setup_database -uroot -p"${MYSQL_ROOT_PASSWORD}" bare-install
else
  echo "  Database installed; upgrading..."
  sudo bin/dj_setup_database -uroot -p"${MYSQL_ROOT_PASSWORD}" upgrade
fi
echo "[ok] Database ready"; echo

echo "[..] Fixing restapi path"
sed -i 's/localhost\/domjudge/localhost/' etc/restapi.secret
echo "[ok] Changed restapi URL from http://localhost/domjudge to http://localhost"

echo "[..] Copying webserver config"
# Set up vhost
sudo cp etc/nginx-conf /etc/nginx/sites-enabled/default
# Replace nginx php socket location
sudo sed -i 's/server unix:.*/server unix:\/var\/run\/php-fpm-domjudge.sock;/' /etc/nginx/sites-enabled/default
# Remove default FPM pool config and link in DOMjudge version
for VERSION in $PHPSUPPORTED
do
  if [[ -f /etc/php/${VERSION}/fpm/pool.d/www.conf ]]
  then
    sudo rm "/etc/php/${VERSION}/fpm/pool.d/www.conf"
  fi
  if [[ ! -f /etc/php/${VERSION}/fpm/pool.d/domjudge.conf ]]
  then
    sudo ln -s "${PROJECT_DIR}/etc/domjudge-fpm.conf" "/etc/php/${VERSION}/fpm/pool.d/domjudge.conf"
  fi
  # Change pm.max_children
  sudo sed -i "s/^pm\.max_children = .*$/pm.max_children = ${FPM_MAX_CHILDREN}/" "/etc/php/${VERSION}/fpm/pool.d/domjudge.conf"
done

sudo chown domjudge: "${PROJECT_DIR}/etc/dbpasswords.secret"
sudo chown domjudge: "${PROJECT_DIR}/etc/restapi.secret"
sudo cp etc/nginx-conf-inner /etc/nginx/snippets/domjudge-inner
NGINX_CONFIG_FILE=/etc/nginx/snippets/domjudge-inner
sudo sed -i "s|${PROJECT_DIR}/etc/nginx-conf-inner|/etc/nginx/snippets/domjudge-inner|" /etc/nginx/sites-enabled/default
# Run DOMjudge in root
sudo sed -i '/^# location \//,/^# \}/ s/# //' $NGINX_CONFIG_FILE
sudo sed -i '/^location \/domjudge/,/^\}/ s/^/#/' $NGINX_CONFIG_FILE
sudo sed -i 's/\/domjudge;/"";/' $NGINX_CONFIG_FILE
# Remove access_log and error_log entries
sudo sed -i '/access_log/d' $NGINX_CONFIG_FILE
sudo sed -i '/error_log/d' $NGINX_CONFIG_FILE
# Use debug front controller
sudo sed -i 's/app\.php/app_dev.php/g' $NGINX_CONFIG_FILE
sudo sed -i 's/app\\\.php/app\\_dev.php/g' $NGINX_CONFIG_FILE
# Set up permissions (make sure the script does not stop if this fails, as this will happen on macOS / Windows)
sudo chown domjudge: "${PROJECT_DIR}/webapp/var"
echo "[ok] Webserver config installed"; echo

if [[ ! -d /chroot/domjudge ]]
then
  echo "[..] Setting up chroot"
  sudo bin/dj_make_chroot
  echo "[ok] Done setting up chroot"; echo
fi

echo "[..] Setting up cgroups"
if [[ -f bin/create_cgroups ]]
then
  sudo bin/create_cgroups
else
  sudo judge/create_cgroups
fi
echo "[ok] cgroups set up"; echo

echo "[..] Adding sudoers configuration"
sudo cp etc/sudoers-domjudge /etc/sudoers.d/
echo "[ok] Sudoers configuration added"; echo

sudo sed -i "s|PROJECT_DIR|${PROJECT_DIR}|" /etc/supervisor/conf.d/judgedaemon.conf
sudo sed -i "s|PROJECT_DIR|${PROJECT_DIR}|" /etc/supervisor/conf.d/judgedaemonextra.conf

exec sudo supervisord -n -c /etc/supervisor/supervisord.conf
