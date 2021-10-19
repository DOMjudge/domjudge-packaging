#!/bin/sh -eu

if [ "$#" -ne 1 ]
then
        echo "Usage $0 <docker tag>"
fi
docker_tag="$1"

# Build the builder
docker build -t "${docker_tag}-build" -f judgehost/Dockerfile.build .

# Build chroot
builder_name=$(echo "${docker_tag}" | sed 's/[^a-zA-Z0-9_-]/-/g')
docker rm -f "${builder_name}" > /dev/null 2>&1 || true
docker run --name "${builder_name}" --cap-add=sys_admin "${docker_tag}-build"
docker cp "${builder_name}:/chroot.tar.gz" .
docker cp "${builder_name}:/judgehost.tar.gz" .
docker rm -f "${builder_name}"
docker rmi "${docker_tag}-build"

# Build actual judgehost
docker build -t "${docker_tag}" -f judgehost/Dockerfile .
