#!/bin/sh -eux

# Placeholders to annotate the Github actions logs
trace_on () { true; }
trace_off () { true; }
section_start () { true; }
section_end () { true; }

if [ -n "${CI+x}" ]
then
	if [ -n "${GITHUB_ACTION+x}" ]
	set -x
	then
		# Functions to annotate the Github actions logs
		trace_on () { set -x; }
		trace_off () {
			{ set +x; } 2>/dev/null
		}
		
		section_start_internal () {
			echo "::group::$1"
			trace_on
		}
		
		section_end_internal () {
			echo "::endgroup::"
			trace_on
		}
		
		section_start () {
			trace_off
			section_start_internal "$@"
		}
		section_end () {
			trace_off
			section_end_internal
		}
	else
		export PS4='(${0}:${LINENO}): - [$?] $ '
	fi
fi

if [ "$#" -eq 0 ] || [ "$#" -gt 2 ]
then
	echo "Usage: $0 domjudge-version <namespace>"
	echo "	For example: $0 5.3.0"
	echo "	or: $0 5.3.0 otherNamespace"
	exit 1
fi

VERSION="$1"
NAMESPACE="domjudge"
if [ -n "${2+x}" ]
then
	NAMESPACE="$2"
fi

URL=https://www.domjudge.org/releases/domjudge-${VERSION}.tar.gz
FILE=domjudge.tar.gz

section_start "Download DOMjudge tarball"
echo "[..] Downloading DOMjudge version ${VERSION}..."

if ! wget --quiet "${URL}" -O ${FILE}
then
	echo "[!!] DOMjudge version ${VERSION} file not found on https://www.domjudge.org/releases"
	exit 1
fi

echo "[ok] DOMjudge version ${VERSION} downloaded as domjudge.tar.gz"; echo
section_end

section_start "Build domserver container"
echo "[..] Building Docker image for domserver..."
./build-domjudge.sh "${NAMESPACE}/domserver:${VERSION}"
echo "[ok] Done building Docker image for domserver"
section_end

section_start "Build judgehost container (with intermediate image)"
echo "[..] Building Docker image for judgehost using intermediate build image..."
./build-judgehost.sh "${NAMESPACE}/judgehost:${VERSION}"
echo "[ok] Done building Docker image for judgehost"
section_end

section_start "Build judgehost container (judging chroot)"
echo "[..] Building Docker image for judgehost chroot..."
docker build -t "${NAMESPACE}/default-judgehost-chroot:${VERSION}" -f judgehost/Dockerfile.chroot .
echo "[ok] Done building Docker image for judgehost chroot"
section_end

section_start "Push instructions"
echo "All done. Image ${NAMESPACE}/domserver:${VERSION} and ${NAMESPACE}/judgehost:${VERSION} created"
echo "If you are a DOMjudge maintainer with access to the domjudge organization on Docker Hub, you can now run the following command to push them to Docker Hub:"
echo "$ docker push ${NAMESPACE}/domserver:${VERSION} && docker push ${NAMESPACE}/judgehost:${VERSION} && docker push $NAMESPACE}/default-judgehost-chroot:${VERSION}"
echo "If this is the latest release, also run the following command:"
echo "$ docker tag ${NAMESPACE}/domserver:${VERSION} ${NAMESPACE}/domserver:latest && \
docker tag ${NAMESPACE}/judgehost:${VERSION} ${NAMESPACE}/judgehost:latest && \
docker tag ${NAMESPACE}/default-judgehost-chroot:${VERSION} ${NAMESPACE}/default-judgehost-chroot:latest && \
docker push ${NAMESPACE}/domserver:latest && docker push ${NAMESPACE}/judgehost:latest && docker push ${NAMESPACE}/default-judgehost-chroot:latest"
section_end
