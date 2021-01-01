#!/bin/bash -e

VERSION=$1
if [[ -z ${VERSION} ]]
then
	echo "Usage: $0 version"
	echo "	For example: $0 1.0"
	exit 1
fi

echo "[..] Building Docker image for Gitlab CI..."
cp -r ../docker-contributor/php-config ./
docker build -t domjudge/gitlabci:${VERSION} . 
rm -r php-config
echo "[ok] Done building Docker image for Gitlab CI"

echo "All done. Image domjudge/gitlabci:${VERSION} created"
echo "If you are a DOMjudge maintainer with access to the domjudge organization on Docker Hub, you can now run the following command to push them to Docker Hub:"
echo "$ docker push domjudge/gitlabci:${VERSION}"
echo "You probably will want to update .gitlab-ci.yml to point to this new image in the DOMjudge/domjudge repository."
