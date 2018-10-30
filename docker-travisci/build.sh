#!/bin/bash -e

VERSION=$1
if [[ -z ${VERSION} ]]
then
	echo "Usage: $0 version"
	echo "	For example: $0 1.0"
	exit 1
fi

echo "[..] Building Docker image for TravisCI..."
docker build -t domjudge/travisci:${VERSION} - <Dockerfile
echo "[ok] Done building Docker image for TravisCI"

echo "All done. Image domjudge/travisci:${VERSION} created"
echo "If you are a DOMjudge maintainer with access to the domjudge organization on Docker Hub, you can now run the following command to push them to Docker Hub:"
echo "$ docker push domjudge/travisci:${VERSION}"
echo "You probably will want to update .travis.yml to point to this new image in the DOMjudge/domjudge repository."
