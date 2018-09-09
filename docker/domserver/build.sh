#!/bin/bash -e

cd /domjudge-src/domjudge*
chown -R domjudge: .
sudo -u domjudge ./configure -with-baseurl=http://localhost/
sudo -u domjudge make domserver
make install-domserver
sudo -u domjudge make docs
make install-docs

cd /opt/domjudge/domserver

# Determine whether we have a legacy DOMjudge instance, i.e. one without Symfony
USE_LEGACY=0
if [[ ! -d webapp ]]
then
	USE_LEGACY=1
fi

if [[ "${USE_LEGACY}" -eq "0" ]]
then
	# Make sure the logo points to the correct path
	cd /opt/domjudge/domserver/webapp/web/images
	rm DOMjudgelogo.png
	ln -s ../../../../doc/logos/DOMjudgelogo.png
fi
