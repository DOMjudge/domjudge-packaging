#! /bin/bash

TOP_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
FILE_NAME="domjudge"
FILE="${TOP_DIR}/${FILE_NAME}.tar.gz"
DIR="${TOP_DIR}/${FILE_NAME}"

VERSION="${1}"
REPO="${2}"
COMMIT_ID="${3}"

if [[ -z "${VERSION}" ]]; then
    VERSION="latest"
fi

if [[ -z "${REPO}" ]]; then
    REPO="DOMjudge/domjudge"
fi

if command -v git >/dev/null 2>&1; then
    GIT_COMMAND="git clone https://github.com/${REPO}.git"
    if [[ -z "${COMMIT_ID}" ]] && [[ X"${VERSION}" != X"latest" ]]; then
        GIT_COMMAND="${GIT_COMMAND} -b ${VERSION}"
    fi

    GIT_COMMAND="${GIT_COMMAND} ${DIR}"

    ${GIT_COMMAND}

    if [[ -n "${COMMIT_ID}" ]]; then
        cd "${DIR}" || exit 1
        git reset --hard "${COMMIT_ID}"
        cd - || exit 1
    fi

    tar -cvzf "${FILE}" -C "${TOP_DIR}" "${FILE_NAME}"
    rm -rf "${DIR}"
else
    if [[ X"${VERSION}" = X"latest" ]]; then
        URL=https://codeload.github.com/${REPO}/tar.gz/refs/heads/main
    else
        URL=https://codeload.github.com/${REPO}/tar.gz/refs/tags/${VERSION}
    fi

    echo "[..] Downloading DOMjudge version ${VERSION}..."

    if ! wget --quiet "${URL}" -O "${FILE}"; then
        echo "[!!] DOMjudge version ${VERSION} file not found on https://codeload.github.com/DOMjudge/domjudge"
        exit 1
    fi
fi
