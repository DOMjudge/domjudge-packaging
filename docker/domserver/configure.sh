#!/bin/sh -eu

# Add user, create PHP FPM socket dir, change permissions for domjudge directory and fix scripts
useradd -m domjudge
mkdir -p /run/php
chown -R domjudge: /opt/domjudge
chown -R www-data: /opt/domjudge/domserver/tmp
# for DOMjudge <= 7.2 (submitdir was removed in commit DOMjudge/domjudge@d66725038)
if [ -d /opt/domjudge/domserver/submissions ]
then
	chown -R www-data: /opt/domjudge/domserver/submissions
fi

chmod 755 /scripts/start.sh
for script in /scripts/bin/*
do
	if [ -f "$script" ]
	then
		chmod 755 "$script"
		ln -s "$script" /usr/bin/
	fi
done

# Configure php

php_folder=$(echo "/etc/php/7."?"/")
php_version=$(basename "$php_folder")

if [ ! -d "$php_folder" ]
then
	echo "[!!] Could not find php path"
	exit 1
fi

# Set correct settings
sed -ri -e "s/^user.*/user www-data;/" /etc/nginx/nginx.conf
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = 100M/" \
	-e "s/^post_max_size.*/post_max_size = 100M/" \
	-e "s/^memory_limit.*/memory_limit = 2G/" \
	-e "s/^max_file_uploads.*/max_file_uploads = 200/" \
	-e "s#^;date\.timezone.*#date.timezone = ${CONTAINER_TIMEZONE}#" \
	 "$php_folder/fpm/php.ini"

ln -s "/usr/sbin/php-fpm$php_version" "/usr/sbin/php-fpm"

# Set up vhost
cp /opt/domjudge/domserver/etc/nginx-conf /etc/nginx/sites-enabled/default
if [ -f /opt/domjudge/domserver/etc/domjudge-fpm.conf ]
then
	# Replace nginx php socket location
	sed -i 's!server unix:.*!server unix:/var/run/php-fpm-domjudge.sock;!' /etc/nginx/sites-enabled/default
	# Remove default FPM pool config and link in DOMjudge version
	if [ -f "$php_version/fpm/pool.d/www.conf" ]
	then
		rm "$php_version/fpm/pool.d/www.conf"
	fi
	if [ ! -f "$php_version/fpm/pool.d/domjudge.conf" ]
	then
		ln -s /opt/domjudge/domserver/etc/domjudge-fpm.conf "$php_folder/fpm/pool.d/domjudge.conf"
	fi
	# Change pm.max_children
	sed --follow-symlinks -i "s/^pm\.max_children = .*$/pm.max_children = ${FPM_MAX_CHILDREN}/" "$php_folder/fpm/pool.d/domjudge.conf"
else
	# Replace nginx php socket location
	sed -i "s!server unix:.*!server unix:/var/run/php/php$php_version-fpm.sock;!" /etc/nginx/sites-enabled/default
fi

cp /opt/domjudge/domserver/etc/nginx-conf-inner /etc/nginx/snippets/domjudge-inner
NGINX_CONFIG_FILE=/etc/nginx/snippets/domjudge-inner
sed -i 's/\/opt\/domjudge\/domserver\/etc\/nginx-conf-inner/\/etc\/nginx\/snippets\/domjudge-inner/' /etc/nginx/sites-enabled/default
# Run DOMjudge in root
sed -i '/^# location \//,/^# \}/ s/# //' "$NGINX_CONFIG_FILE"
sed -i '/^location \/domjudge/,/^\}/ s/^/#/' "$NGINX_CONFIG_FILE"
sed -i 's/\/domjudge;/"";/' "$NGINX_CONFIG_FILE"
# Remove access_log and error_log entries
sed -i '/access_log/d' "$NGINX_CONFIG_FILE"
sed -i '/error_log/d' "$NGINX_CONFIG_FILE"

# Fix permissions on cache and log directories
chown www-data: -R /opt/domjudge/domserver/webapp/var
