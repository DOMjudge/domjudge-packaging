#!/bin/bash -e

function file_or_env {
    file=${1}_FILE
    if [ -n "${!file}" ]; then
        cat "${!file}"
    else
        echo -n "${!1}"
    fi
}

cd /opt/domjudge/domserver

MYSQL_PASSWORD=$(file_or_env MYSQL_PASSWORD)
MYSQL_ROOT_PASSWORD=$(file_or_env MYSQL_ROOT_PASSWORD)

if [ -z "${MYSQL_PORT}" ]; then MYSQL_PORT=3306; fi

DOCKER_GATEWAY_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
TRUSTED_PROXIES=$(file_or_env TRUSTED_PROXIES)

WEBAPP_BASEURL=$(file_or_env WEBAPP_BASEURL)

echo "[..] Generating credential files"
echo "dummy:${MYSQL_HOST}:${MYSQL_DATABASE}:${MYSQL_USER}:${MYSQL_PASSWORD}:${MYSQL_PORT}" | (umask 077 && cat > etc/dbpasswords.secret)

# Make a note of whether some of the credential files existed originally
if [[ -f etc/initial_admin_password.secret ]]
then
	admin_pw_file_existed=1
else
	admin_pw_file_existed=0
fi
if [[ -f etc/restapi.secret ]]
then
	restapi_secret_file_existed=1
else
	restapi_secret_file_existed=0
fi

# Generate secrets
if [[ -f etc/gen_all_secrets ]]
then
	# DOMjudge >= 7.2.1
	(cd etc && ./gen_all_secrets)
	# (Note: running 'etc/gen_all_secrets' does not work before commit DOMjudge/domjudge@9bac55144600)
elif [[ -f webapp/config/load_db_secrets.php ]]
then
	# DOMjudge 7.2.0
	# This version does not install gen_all_secrets and gensymfonysecret, so we have to inline them here (fixed in commit DOMjudge/domjudge@d523a965f8e0)
	if [[ ! -f etc/restapi.secret ]]; then
		etc/genrestapicredentials | (umask 077 && cat > etc/restapi.secret)
	fi
	if [[ ! -f etc/initial_admin_password.secret ]]; then
		etc/genadminpassword | (umask 077 && cat > etc/initial_admin_password.secret)
	fi
	if [[ ! -f etc/symfony_app.secret ]]; then
		{
			# From etc/gensymfonysecret
			head -c20 /dev/urandom | base64 | head -c20 | tr '/+' 'Aa'
			echo
		} | (umask 077 && cat > etc/symfony_app.secret)
	fi
else
	# DOMjudge 7.1
	if [[ ! -f etc/restapi.secret ]]; then
		etc/genrestapicredentials | (umask 077 && cat > etc/restapi.secret)
	fi
	if [[ ! -f etc/initial_admin_password.secret ]]; then
		etc/genadminpassword | (umask 077 && cat > etc/initial_admin_password.secret)
	fi
	# This version needs the database settings and app secret to be in webapp/.env.local
	# It is generated using etc/gensymfonyenv on DOMjudge 7.1, but that script is not installed so we inline it here
	if [[ ! -f webapp/.env.local ]]; then
		{
			SECRET=$(head -c20 /dev/urandom | base64 | head -c20 | tr '/+' 'Aa')
			echo "# Generated on $(hostname), $(date)."
			echo
			echo "# Uncomment the following line to run the application in development mode"
			echo "#APP_ENV=dev"
			echo "APP_SECRET=$SECRET"
			echo "DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}"
		} | (umask 077 && cat > webapp/.env.local)
	fi
fi

# Add the Docker gateway as a trusted proxy
if grep -q TRUSTED_PROXIES webapp/.env.local > /dev/null 2>&1
then
	sed -i "s|TRUSTED_PROXIES=.*|TRUSTED_PROXIES=${DOCKER_GATEWAY_IP}|" webapp/.env.local
else
	echo "TRUSTED_PROXIES=${DOCKER_GATEWAY_IP}" >> webapp/.env.local
fi

NGINX_CONFIG_FILE=/etc/nginx/snippets/domjudge-inner

# Set up BaseURL

# Fix BaseURL, Such as
# "" -> "/"
# "domjudge" -> "/domjudge"
if [[ -z "${WEBAPP_BASEURL}" ]] || [[ "${WEBAPP_BASEURL:0:1}" != '/' ]]; then
	WEBAPP_BASEURL="/${WEBAPP_BASEURL}"
	echo "Fix WEBAPP_BASEURL ${WEBAPP_BASEURL:1} -> ${WEBAPP_BASEURL}"
fi

# Fix BaseURL, Such as
# "/" -> "/"
# "/domjudge/" -> "/domjudge"
if [[ "${WEBAPP_BASEURL}" != "/" ]] && [[ "${WEBAPP_BASEURL: -1}" == '/' ]]; then
	WEBAPP_BASEURL="${WEBAPP_BASEURL%?}"
fi

# Remove the previous location configuration
sed -i "/^location \/.*/,/^\}/d" ${NGINX_CONFIG_FILE}

if [[ "${WEBAPP_BASEURL}" == "/" ]]; then
	sed -i "s|^set \$prefix .*;$|set \$prefix \"\";|" ${NGINX_CONFIG_FILE}
	sed -i "/^set \$prefix .*;/a\
\ \n\
# run it out of the root of your system\n\
location / {\n\
	root \$domjudgeRoot;\n\
	try_files \$uri @domjudgeFront;\n\
}
" ${NGINX_CONFIG_FILE}
else
	sed -i "s|^set \$prefix .*;$|set \$prefix \"${WEBAPP_BASEURL}\";|" ${NGINX_CONFIG_FILE}
	sed -i "/^set \$prefix .*;/a\
\ \n\
# install it with a prefix\n\
location $WEBAPP_BASEURL { return 301 $WEBAPP_BASEURL\/; }\n\
location $WEBAPP_BASEURL\/ {\n\
	root \$domjudgeRoot;\n\
	rewrite ^$WEBAPP_BASEURL\/(.*)\$ \/\$1 break;\n\
	try_files \$uri @domjudgeFront;\n\
}
" ${NGINX_CONFIG_FILE}
fi

sed -i "s|    domjudge.baseurl: .*|    domjudge.baseurl: http:\/\/localhost${WEBAPP_BASEURL}\/|" /opt/domjudge/domserver/webapp/config/static.yaml
sed -i "s|define('BASEURL',     '.*');|define('BASEURL',     'http:\/\/localhost${WEBAPP_BASEURL}/');|" /opt/domjudge/domserver/etc/domserver-static.php

# Add trusted proxies for Nginx

# Remove the previous configuration
sed -i "/^set_real_ip_from.*/d" ${NGINX_CONFIG_FILE}
sed -i "/^real_ip_header.*/d" ${NGINX_CONFIG_FILE}
sed -i "/^real_ip_recursive.*/d" ${NGINX_CONFIG_FILE}

echo "set_real_ip_from ${DOCKER_GATEWAY_IP};" >> ${NGINX_CONFIG_FILE}

IFS="," read -r -a TRUSTED_PROXIES_ARRAY <<< "${TRUSTED_PROXIES}"

for TRUSTED_PROXY in "${TRUSTED_PROXIES_ARRAY[@]}"
do
	echo "set_real_ip_from ${TRUSTED_PROXY};" >> ${NGINX_CONFIG_FILE}
done

echo "real_ip_header    X-Forwarded-For;" >> ${NGINX_CONFIG_FILE}
echo "real_ip_recursive on;" >> ${NGINX_CONFIG_FILE}

if [[ ! -f webapp/config/load_db_secrets.php ]]
then
	# DOMjudge 7.1 dumps the environment into webapp/.env.local.php for improved speed
	# We also do that here (with some additional setup to get composer to work)
	echo '{"config": {"vendor-dir": "lib/vendor"}, "extra": {"symfony": {"root-dir": "webapp/"}}}' > composer.json
	touch webapp/.env
	composer symfony:dump-env prod
	rm composer.json
	if [[ ! -s webapp/.env ]]; then
		rm webapp/.env
	fi
	chmod og= webapp/.env.local.php
fi

# Set up permissions
chown -R www-data: webapp/public/images
chown www-data: etc/dbpasswords.secret
chown www-data: etc/restapi.secret
if [[ -f etc/symfony_app.secret ]]
then
	chown www-data: etc/symfony_app.secret
fi
if [[ -f webapp/.env.local ]]
then
	chown www-data: webapp/.env.local
fi
if [[ -f webapp/.env.local.php ]]
then
	chown www-data: webapp/.env.local.php
fi
echo "[ok] Generated credential files"; echo

# Sometimes when running `docker-compose up` we're too fast at this step
DB_UP=9
while [ $DB_UP -gt 0 ]
do
	echo "[..] Checking database connection"
	if ! mysqlshow -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" -P "${MYSQL_PORT}" "${MYSQL_DATABASE}" > /dev/null 2>&1
	then
		echo "MySQL database ${MYSQL_DATABASE} not yet found on host ${MYSQL_HOST}:${MYSQL_PORT};"
		(( DB_UP-- ))
		sleep 10s
	else
		DB_UP=0
	fi
done
if ! mysqlshow -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" -P "${MYSQL_PORT}" "${MYSQL_DATABASE}" > /dev/null 2>&1
then
	echo "MySQL database ${MYSQL_DATABASE} not found on host ${MYSQL_HOST}:${MYSQL_PORT}; exiting"
	exit 1
fi

if ! bin/dj_setup_database -uroot -p"${MYSQL_ROOT_PASSWORD}" status > /dev/null 2>&1
then
	echo "  Database not installed; installing..."
	INSTALL=install
	if [ "${DJ_DB_INSTALL_BARE}" -eq "1" ]
	then
		INSTALL=bare-install
	fi
	echo "Using ${INSTALL}..."
	bin/dj_setup_database -uroot -p"${MYSQL_ROOT_PASSWORD}" ${INSTALL}
else
	echo "  Database installed; upgrading..."
	if [ "${admin_pw_file_existed}" -eq "0" ] && [[ -f etc/initial_admin_password.secret ]]
	then
		# The file etc/initial_admin_password.secret did not originally exist and was generated by etc/gen_all_secrets earlier.
		# However, the database already exists and has a different password.
		# We can't extract the password from the database because only the hash is stored, so we mark the password as unknown.
		echo "[unknown]" > etc/initial_admin_password.secret
	fi
	if [ "${restapi_secret_file_existed}" -eq "0" ]
	then
		# The generated file does not match the database (similar to initial_admin_password.secret above).
		{
			echo "# NOTE(password-mismatch):"
			echo "# The database was not automatically updated to use this judgehost password."
		} >> etc/restapi.secret
	fi
	bin/dj_setup_database -uroot -p"${MYSQL_ROOT_PASSWORD}" upgrade
fi
echo "[ok] Database ready"; echo

echo "[..] Fixing restapi path"
sed -i "s|localhost/domjudge|localhost${WEBAPP_BASEURL}|" etc/restapi.secret
echo "[ok] Changed restapi URL from http://localhost/domjudge to http://localhost${WEBAPP_BASEURL}"

if [[ -f etc/initial_admin_password.secret ]]
then
	echo -n "Initial admin password is "
	cat etc/initial_admin_password.secret
	echo
fi
echo -n "Initial judgehost password is "
if grep -q "^# NOTE(password-mismatch)" < etc/restapi.secret
then
	# When restapi.secret was generated (either just now or in a previous run) it did not match the database
	echo "[unknown]"
	if [ "${restapi_secret_file_existed}" -eq "0" ]
	then
		# The file was generated just now
		echo "A new judgehost password was generated in /opt/domjudge/domserver/etc/restapi.secret."
		echo "However, the database was not automatically updated to use this judgehost password."
	else
		# The file was generated in a previous run
		echo "The file /opt/domjudge/domserver/etc/restapi.secret contains a note indicating its password might not match the database."
	fi
	echo "The password in the database can be changed from the web interface by editing the 'judgehost' user."
else
	# Display the judgehost password
	grep -v '^#' etc/restapi.secret | cut -f4
fi

if [[ -d /scripts/post-start.d/ ]]
then
	for i in /scripts/post-start.d/*
	do
		if [[ -x "$i" ]]
		then
			echo "[..] Running post start script $(basename "$i")"
			if ! output=$("$i" 2>&1); then
				echo "[!!] Post start script $(basename "$i") failed"
				echo "$output"
				exit 1
			fi
		fi
	done
fi
