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

echo "[..] Changing nginx and PHP configuration settings"
# Set correct settings
sed -ri -e "s/^user.*/user www-data;/" /etc/nginx/nginx.conf
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = 100M/" \
	-e "s/^post_max_size.*/post_max_size = 100M/" \
	-e "s/^memory_limit.*/memory_limit = 2G/" \
	-e "s/^max_file_uploads.*/max_file_uploads = 200/" \
	-e "s#^;date\.timezone.*#date.timezone = ${CONTAINER_TIMEZONE}#" \
	 /etc/php/7.3/fpm/php.ini
echo "[ok] Done changing nginx and PHP configuration settings"; echo

cd /opt/domjudge/domserver

# Determine whether we have a legacy DOMjudge instance, i.e. one without Symfony
USE_LEGACY=0
if [[ ! -d webapp ]]
then
	USE_LEGACY=1
fi

MYSQL_PASSWORD=$(file_or_env MYSQL_PASSWORD)
MYSQL_ROOT_PASSWORD=$(file_or_env MYSQL_ROOT_PASSWORD)

DOCKER_GATEWAY_IP=$(/sbin/ip route|awk '/default/ { print $3 }')

echo "[..] Updating database credentials file"
echo "dummy:${MYSQL_HOST}:${MYSQL_DATABASE}:${MYSQL_USER}:${MYSQL_PASSWORD}" > etc/dbpasswords.secret
if [[ "${USE_LEGACY}" -eq "0" ]]
then
	if [[ -f webapp/.env ]]
	then
		# We only set database settings for DOMjudge < 7.2.0, newer versions load it automatically from etc/dbpasswords.secret
		if [[ -f webapp/.env.local ]]
		then
			DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:3306/${MYSQL_DATABASE}
			sed -i "s|DATABASE_URL=.*|DATABASE_URL=${DATABASE_URL}|" webapp/.env.local
			if [[ -f webapp/.env.local.php ]]
			then
				sed -i "s|'mysql://.*',$|'${DATABASE_URL}',|" webapp/.env.local.php
			fi
		fi

		# Add the Docker gateway as a trusted proxy
		if grep -q TRUSTED_PROXIES webapp/.env.local > /dev/null 2>&1
		then
			sed -i "s|TRUSTED_PROXIES=.*|TRUSTED_PROXIES=${DOCKER_GATEWAY_IP}|" webapp/.env.local
			if [[ -f webapp/.env.local.php ]]
			then
				sed -i "s|'TRUSTED_PROXIES' => .*|'TRUSTED_PROXIES' => '${DOCKER_GATEWAY_IP}',|" webapp/.env.local.php
			fi
		else
			echo "TRUSTED_PROXIES=${DOCKER_GATEWAY_IP}" >> webapp/.env.local
			if [[ -f webapp/.env.local.php ]]
			then
				sed -i "s|);|  'TRUSTED_PROXIES' => '${DOCKER_GATEWAY_IP}',\n);|" webapp/.env.local.php
			fi
		fi
	else
		sed -i "s/database_host: .*/database_host: ${MYSQL_HOST}/" webapp/app/config/parameters.yml
		sed -i "s/database_name: .*/database_name: ${MYSQL_DATABASE}/" webapp/app/config/parameters.yml
		sed -i "s/database_user: .*/database_user: ${MYSQL_USER}/" webapp/app/config/parameters.yml
		sed -i "s/database_password: .*/database_password: ${MYSQL_PASSWORD}/" webapp/app/config/parameters.yml

		# Add the Docker gateway as a trusted proxy
		sed -i "s#^//\s*\(Request::setTrustedProxies(\)[^,]*#\1['${DOCKER_GATEWAY_IP}']#" webapp/web/app.php
	fi
fi
echo "[ok] Updated database credentials file"; echo

echo "[..] Checking database connection"
if ! mysqlshow -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} ${MYSQL_DATABASE} > /dev/null 2>&1
then
	echo "MySQL database ${MYSQL_DATABASE} not found on host ${MYSQL_HOST}; exiting"
	exit 1
fi

if ! bin/dj_setup_database -uroot -p${MYSQL_ROOT_PASSWORD} status > /dev/null 2>&1
then
	echo "  Database not installed; installing..."
	if [[ -f etc/genadminpassword ]] && [[ ! -f etc/initial_admin_password.secret ]]
	then
		etc/genadminpassword > etc/initial_admin_password.secret
	fi
	INSTALL=install
	if [ "${DJ_DB_INSTALL_BARE}" -eq "1" ]
	then
		INSTALL=bare-install
	fi
	echo "Using ${INSTALL}..."
	bin/dj_setup_database -uroot -p${MYSQL_ROOT_PASSWORD} ${INSTALL}
else
	echo "  Database installed; upgrading..."
	bin/dj_setup_database -uroot -p${MYSQL_ROOT_PASSWORD} upgrade
fi
echo "[ok] Database ready"; echo

echo "[..] Fixing restapi path"
sed -i 's/localhost\/domjudge/localhost/' etc/restapi.secret
echo "[ok] Changed restapi URL from http://localhost/domjudge to http://localhost"

echo "[..] Copying webserver config"
# Set up vhost
cp etc/nginx-conf /etc/nginx/sites-enabled/default
if [[ -f /opt/domjudge/domserver/etc/domjudge-fpm.conf ]]
then
	# Replace nginx php socket location
	sed -i 's!server unix:.*!server unix:/var/run/php-fpm-domjudge.sock;!' /etc/nginx/sites-enabled/default
	# Remove default FPM pool config and link in DOMJudge version
	if [[ -f /etc/php/7.3/fpm/pool.d/www.conf ]]
	then
		rm /etc/php/7.3/fpm/pool.d/www.conf
	fi
	if [[ ! -f /etc/php/7.3/fpm/pool.d/domjudge.conf ]]
	then
		ln -s /opt/domjudge/domserver/etc/domjudge-fpm.conf /etc/php/7.3/fpm/pool.d/domjudge.conf
	fi
	# Change pm.max_children
	sed --follow-symlinks -i "s/^pm\.max_children = .*$/pm.max_children = ${FPM_MAX_CHILDREN}/" /etc/php/7.3/fpm/pool.d/domjudge.conf
else
	# Replace nginx php socket location
	sed -i 's!server unix:.*!server unix:/var/run/php/php7.3-fpm.sock;!' /etc/nginx/sites-enabled/default
fi

# Set up permissions
chown www-data: etc/dbpasswords.secret
chown www-data: etc/restapi.secret

if [[ "${USE_LEGACY}" -eq "0" ]]
then
	HAS_INNER_NGINX=0
	NGINX_CONFIG_FILE=/etc/nginx/sites-enabled/default

	# Check if we have DOMjudge >= 6.1 which has a separate file for the inner nginx configuration
	if [[ -f etc/nginx-conf-inner ]]
	then
		HAS_INNER_NGINX=1
		cp etc/nginx-conf-inner /etc/nginx/snippets/domjudge-inner
		NGINX_CONFIG_FILE=/etc/nginx/snippets/domjudge-inner
		sed -i 's/\/opt\/domjudge\/domserver\/etc\/nginx-conf-inner/\/etc\/nginx\/snippets\/domjudge-inner/' /etc/nginx/sites-enabled/default
		# Run DOMjudge in root
		sed -i '/^# location \//,/^# \}/ s/# //' $NGINX_CONFIG_FILE
		sed -i '/^location \/domjudge/,/^\}/ s/^/#/' $NGINX_CONFIG_FILE
		sed -i 's/\/domjudge;/"";/' $NGINX_CONFIG_FILE
	else
		# Run DOMjudge in root
		sed -i '/^\t#location \//,/^\t#\}/ s/\t#/\t/' $NGINX_CONFIG_FILE
		sed -i '/^\tlocation \/domjudge/,/^\t\}/ s/^\t/\t#/' $NGINX_CONFIG_FILE
	fi
	# Remove access_log and error_log entries
	sed -i '/access_log/d' $NGINX_CONFIG_FILE
	sed -i '/error_log/d' $NGINX_CONFIG_FILE
	# Clear Symfony cache
	webapp/bin/console cache:clear --env=prod
	# Fix permissions on cache and log directories
	chown -R www-data: webapp/var
	# Also fix permissions on .env files
	if [[ -f webapp/.env.local ]]
	then
		chown www-data: webapp/.env.local
	fi
	if [[ -f webapp/.env.local.php ]]
	then
		chown www-data: webapp/.env.local.php
	fi
fi
echo "[ok] Webserver config installed"; echo

if [[ -f etc/initial_admin_password.secret ]]
then
	echo -n "Initial admin password is "
	cat etc/initial_admin_password.secret
	echo
	echo
	echo
fi

exec supervisord -n -c /etc/supervisor/supervisord.conf
