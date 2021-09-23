#!/bin/bash -e

useradd -m domjudge
chown -R domjudge: /opt/domjudge

chmod 755 /scripts/start.sh
if compgen -G "/scripts/bin/*"
then
	chmod 755 /scripts/bin/*
	ln -s /scripts/bin/* /usr/bin/
fi
