#!/bin/sh -eu

if [ -d /scripts/start.ro ]
then
	for i in /scripts/start.ro/*
	do
		echo "[..] Copying script $(basename $i)"
		cp "$i" "/scripts/start.d/$(basename $i)"
	done
fi

for i in /scripts/start.d/*
do
	if [ -x "$i" ]
	then
		echo "[..] Running start script $(basename $i)"
		if ! "$i"
		then
			echo "[!!] Start script $(basename $i) failed"
			exit 1
		fi
	fi
done

echo "[..] Starting supervisor"

exec supervisord -n -c /etc/supervisor/supervisord.conf
