#!/bin/bash -e

if [[ -n ${CI} ]]
then
        set -euxo pipefail
        export PS4='(${0}:${LINENO}): - [$?] $ '
fi

VERSION=$1
if [[ -z ${VERSION} ]]
then
	echo "Usage: $0 version"
	echo "	For example: $0 1.0"
	exit 1
fi
if [[ -z $2 ]]
then
	REGISTRY="domjudge/gitlabci"
else
	REGISTRY=$2
fi

echo "[..] Building Docker image for Gitlab CI..."
cp -r ../docker-contributor/php-config ./
docker build -t "${REGISTRY}:${VERSION}" . 
rm -r php-config
echo "[ok] Done building Docker image for Gitlab CI"

if [[ -z ${CI} ]]
then
        echo "All done. Image ${REGISTRY}:${VERSION} created"
        echo "If you are a DOMjudge maintainer with access to the domjudge organization on Docker Hub, you can now run the following command to push them to Docker Hub:"
        echo "$ docker push ${REGISTRY}:${VERSION}"
        echo "You probably will want to update .gitlab-ci.yml to point to this new image in the DOMjudge/domjudge repository."
else
        echo "When this is not a PR, we will try to upload this to the GitLab registry."
fi
