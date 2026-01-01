#!/bin/sh -eu

# Placeholders for grouping log lines
# (the body is a nested function declaration so it won't appear in the trace when using `set -x`)
section_start() { _() { :; }; }
section_end() { _() { :; }; }

if [ -n "${CI+x}" ]
then
	if [ -n "${GITHUB_ACTION+x}" ]
	then
		# Functions for grouping log lines on GitHub Actions
		trace_on() { set -x; }
		# trace_off is manually inlined so it won't appear in the trace
		section_start() {
			{ set +x; } 2>/dev/null # trace_off
			echo "::group::$1"
			trace_on
		}
		section_end() {
			{ set +x; } 2>/dev/null # trace_off
			echo "::endgroup::"
			trace_on
		}
		# Redirect stderr to stdout as a workaround so they won't be out-of-order; see
		# https://github.com/orgs/community/discussions/116552
		# https://web.archive.org/web/20220430214837/https://github.community/t/stdout-stderr-output-not-in-correct-order-in-logs/16335
		# (GitHub Actions displays stderr in the same style as stdout anyway, so
		# there is no harm in us merging them.)
		exec 2>&1
	fi
	set -x
fi

section_start "Variables"
VERSION="$1"
NAMESPACE="${2-domjudge}"
section_end

section_start "Build judgehost container (judging chroot)"
echo "[..] Building Docker image for judgehost chroot..."
docker build -t "${NAMESPACE}/default-judgehost-chroot:${VERSION}" -f Dockerfile.chroot .
docker build -t "${NAMESPACE}/full-judgehost-chroot:${VERSION}" -f Dockerfile.chroot-full .
docker build -t "${NAMESPACE}/icpc-judgehost-chroot:${VERSION}" -f Dockerfile.chroot-icpc .
echo "[ok] Done building Docker image for judgehost chroot"
section_end

section_start "Push instructions"
push_cmd="$ docker push docker push ${NAMESPACE}/default-judgehost-chroot:${VERSION}"
tag_cmd="$ docker tag ${NAMESPACE}/default-judgehost-chroot:${VERSION} ${NAMESPACE}/default-judgehost-chroot:latest"
push_tag_cmd="$ docker push ${NAMESPACE}/default-judgehost-chroot:latest"

for i in full icpc; do
  push_cmd="$push_cmd && docker push ${NAMESPACE}/${i}-judgehost-chroot:${VERSION}"
  tag_cmd="$tag_cmd && docker tag ${NAMESPACE}/${i}-judgehost-chroot:${VERSION} ${NAMESPACE}/${i}-judgehost-chroot:latest"
  push_tag_cmd="$push_tag_cmd && docker push ${NAMESPACE}/${i}-judgehost-chroot:latest"
done

echo "If you are a DOMjudge maintainer with access to the domjudge organization on Docker Hub, you can now run the following command to push them to Docker Hub:"
echo "$push_cmd"
echo "If this is the latest release, also run the following command:"
echo "$tag_cmd"
echo "$push_tag_cmd"
section_end
