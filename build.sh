#!/bin/bash

set -eEux
set -o pipefail

#
# Build patched CRI-O binaries for all supported versions.
#
# Usage: ./build.sh [version...]
#   No arguments: builds all versions from supported-versions file
#   With arguments: builds only specified versions (e.g. ./build.sh v1.35 v1.34)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

UNAME_M="$(uname -m)"
case "$UNAME_M" in
    x86_64)  SYS_ARCH=amd64 ;;
    aarch64) SYS_ARCH=arm64 ;;
    arm64)   SYS_ARCH=arm64 ;;
    *)       echo "Unsupported architecture: $UNAME_M"; exit 1 ;;
esac

SUPPORTED_VERSIONS_FILE="supported-versions"

if [ $# -gt 0 ]; then
    VERSIONS=("$@")
else
    # Read minimum version
    MIN_VERSION=""
    while read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        MIN_VERSION="$line"
        break
    done < "$SUPPORTED_VERSIONS_FILE"

    MIN_MAJOR="${MIN_VERSION%%.*}"
    MIN_MINOR="${MIN_VERSION#*.}"

    git submodule update --init
    git -C cri-o fetch --tags origin

    # Discover all minor versions >= minimum from tags
    declare -A LATEST_TAGS
    for tag in $(git -C cri-o tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -V); do
        VER="${tag#v}"
        TAG_MAJOR="${VER%%.*}"
        TAG_REST="${VER#*.}"
        TAG_MINOR="${TAG_REST%%.*}"

        [[ "$TAG_MAJOR" =~ ^[0-9]+$ ]] || continue
        [[ "$TAG_MINOR" =~ ^[0-9]+$ ]] || continue

        if [ "$TAG_MAJOR" -lt "$MIN_MAJOR" ]; then
            continue
        elif [ "$TAG_MAJOR" -eq "$MIN_MAJOR" ] && [ "$TAG_MINOR" -lt "$MIN_MINOR" ]; then
            continue
        fi

        LATEST_TAGS["v${TAG_MAJOR}.${TAG_MINOR}"]="$tag"
    done

    VERSIONS=("${!LATEST_TAGS[@]}")
fi

docker build -t crio-bld -f Dockerfile.build --build-arg sys_arch="$SYS_ARCH" .

git submodule update --init

for ver in "${VERSIONS[@]}"; do
    if [ -f "bin/crio/${ver}/crio" ] && [ -f "bin/crio/${ver}/pinns" ]; then
        echo "*** Skip building CRI-O ${ver} -- binaries already present ***"
        continue
    fi

    echo "*** Preparing CRI-O ${ver} source ***"

    LATEST_TAG=$(git -C cri-o tag -l "${ver}.*" | sort -V | tail -1)
    if [ -z "$LATEST_TAG" ]; then
        echo "ERROR: No tag found for ${ver}.* in cri-o submodule"
        exit 1
    fi

    echo "Using tag: $LATEST_TAG"
    git -C cri-o checkout -q "$LATEST_TAG"

    ./patch.sh "$ver"

    echo "*** Building CRI-O ${ver} (tag: $LATEST_TAG) ***"
    docker run --rm \
        -v "$(pwd)/cri-o:/mnt/cri-o" \
        -v "$(pwd)/bin:/mnt/results" \
        -e "CRIO_VERSION=${ver}" \
        crio-bld

    git -C cri-o checkout -- .
    git -C cri-o clean -fd -q
done

echo "*** All builds complete ***"
ls -la bin/crio/*/
