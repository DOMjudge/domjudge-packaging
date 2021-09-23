#!/bin/sh -eu

if [ "$#" -ne 1 ]
then
	echo "Usage $0 <docker tag>"
fi
docker_tag="$1"

docker build -t "${docker_tag}" -f domserver/Dockerfile .

