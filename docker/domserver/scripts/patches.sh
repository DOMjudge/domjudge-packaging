#!/bin/sh

for i in /scripts/patches.d/*
do
	if [ -x "$i" ]
	then
		echo "[..] Running patch script" "$(basename "$i")"
		if ! "$i"
		then
			echo "[!!] Start patch" "$(basename "$i")" "failed"
			exit 1
		fi
	fi
done
