#!/bin/bash

set -eEux
set -o pipefail

#
# CRI-O build script (runs inside the build container)
#
# Expects:
#   - /mnt/cri-o: pre-patched CRI-O source tree
#   - /mnt/results: output directory for binaries
#   - CRIO_VERSION: version being built (e.g. v1.35)
#

CRIO_VERSION="${CRIO_VERSION:?CRIO_VERSION must be set}"

echo "*** Building CRI-O ${CRIO_VERSION} ... ***"

cd /mnt/cri-o
make bin/crio-static bin/pinns

mkdir -p "/mnt/results/crio/${CRIO_VERSION}"
cp bin/crio-static "/mnt/results/crio/${CRIO_VERSION}/crio"
cp bin/pinns "/mnt/results/crio/${CRIO_VERSION}/pinns"

echo "*** CRI-O ${CRIO_VERSION} build complete ***"
