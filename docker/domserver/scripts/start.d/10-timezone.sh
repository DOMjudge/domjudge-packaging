#!/bin/sh -eu

ln -snf /usr/share/zoneinfo/${CONTAINER_TIMEZONE} /etc/localtime
echo ${CONTAINER_TIMEZONE} > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo "[ok] Container timezone set to: ${CONTAINER_TIMEZONE}"; echo

# Configure php
php_folder=$(echo "/etc/php/7."?"/")

sed -ri -e "s#^;date\.timezone.*#date.timezone = ${CONTAINER_TIMEZONE}#" \
	"$php_folder/fpm/php.ini"