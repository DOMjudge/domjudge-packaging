#!/bin/bash -e

cd /domjudge-src/domjudge*
chown -R domjudge: .
sudo -u domjudge ./configure -with-baseurl=http://localhost/

# Passwords should not be included in the built image. We create empty files here to prevent passwords from being generated.
sudo -u domjudge touch etc/dbpasswords.secret etc/restapi.secret etc/symfony_app.secret etc/initial_admin_password.secret
if [[ ! -f webapp/config/load_db_secrets.php ]]
then
	# DOMjudge 7.1
	sudo -u domjudge touch webapp/.env.local webapp/.env.local.php
fi

sudo -u domjudge make domserver
make install-domserver

# Remove installed password files
rm /opt/domjudge/domserver/etc/*.secret
if [[ ! -f webapp/config/load_db_secrets.php ]]
then
	# DOMjudge 7.1
	rm /opt/domjudge/domserver/webapp/.env.local /opt/domjudge/domserver/webapp/.env.local.php
fi

sudo -u domjudge make docs
make install-docs
