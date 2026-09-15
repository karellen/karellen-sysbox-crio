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

# The image ships one bootstrap Go, but supported CRI-O versions span several
# Go releases (v1.30 wants 1.22, v1.37 wants 1.26). Pin GOTOOLCHAIN per version
# from the source itself so one image builds them all. build.yml resolves the
# same version the same way, so local and release builds agree.
GO_TOOLCHAIN_VERSION="$(sed -n 's/^toolchain go//p' go.mod)"
if [ -z "$GO_TOOLCHAIN_VERSION" ]; then
    GO_TOOLCHAIN_VERSION="$(sed -n 's/^go //p' go.mod)"
fi

if [ -z "$GO_TOOLCHAIN_VERSION" ]; then
    echo "ERROR: could not determine Go version from go.mod" >&2
    exit 1
fi

# What go.mod states is a floor, not a pin, so build with the newest release of
# that Go train rather than the exact version named. x.y.0 is the least
# shaken-out build in a series, and later patches are bug and security fixes
# that stay language- and ABI-compatible. The toolchain module list is the
# authoritative set of versions GOTOOLCHAIN can actually fetch.
GO_TRAIN="$(echo "$GO_TOOLCHAIN_VERSION" | cut -d. -f1,2)"
GO_TOOLCHAIN_LIST_URL="https://proxy.golang.org/golang.org/toolchain/@v/list"

LATEST_GO_PATCH="$(wget -qO- "$GO_TOOLCHAIN_LIST_URL" \
    | sed -n "s/^v0\.0\.1-go\(${GO_TRAIN//./\\.}\.[0-9][0-9]*\)\.linux-${SYS_ARCH}$/\1/p" \
    | sort -V | tail -1)"

if [ -z "$LATEST_GO_PATCH" ]; then
    echo "ERROR: no Go ${GO_TRAIN}.x toolchain for ${SYS_ARCH} at ${GO_TOOLCHAIN_LIST_URL}" >&2
    exit 1
fi

# Only move forward. A go.mod naming a version newer than anything published
# (a fresh security release, say) must not be silently downgraded.
if [ "$(printf '%s\n%s\n' "$GO_TOOLCHAIN_VERSION" "$LATEST_GO_PATCH" | sort -V | tail -1)" = "$LATEST_GO_PATCH" ]; then
    echo "go.mod wants Go ${GO_TOOLCHAIN_VERSION}; using latest ${GO_TRAIN} release ${LATEST_GO_PATCH}"
    GO_TOOLCHAIN_VERSION="$LATEST_GO_PATCH"
else
    echo "go.mod wants Go ${GO_TOOLCHAIN_VERSION}, newer than any published ${GO_TRAIN} release; using it as-is"
fi

export GOTOOLCHAIN="go${GO_TOOLCHAIN_VERSION}"

go version

# CRI-O v1.30's Makefile exports GOSUMDB as a URL, but Go expects a verifier
# name, and it rejects it while verifying the toolchain module downloaded
# above. Upstream dropped the line in v1.31; override it for every version
# since sum.golang.org is the default anyway.
make GOSUMDB=sum.golang.org bin/crio-static bin/pinns

mkdir -p "/mnt/results/crio/${CRIO_VERSION}"
cp bin/crio-static "/mnt/results/crio/${CRIO_VERSION}/crio"
cp bin/pinns "/mnt/results/crio/${CRIO_VERSION}/pinns"

echo "*** CRI-O ${CRIO_VERSION} build complete ***"
