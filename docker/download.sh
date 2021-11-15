#! /bin/bash

TOP_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

VERSION="$1"

if [[ X"${VERSION}" = X"latest" ]]; then
	URL=https://codeload.github.com/DOMjudge/domjudge/tar.gz/refs/heads/main
else
	URL=https://codeload.github.com/DOMjudge/domjudge/tar.gz/refs/tags/${VERSION}
fi

FILE="${TOP_DIR}"/domjudge.tar.gz

echo "[..] Downloading DOMjudge version ${VERSION}..."

if ! wget --quiet "${URL}" -O "${FILE}"; then
	echo "[!!] DOMjudge version ${VERSION} file not found on https://codeload.github.com/DOMjudge/domjudge"
	exit 1
fi
