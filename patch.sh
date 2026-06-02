#!/bin/bash

set -eEux
set -o pipefail

CRIO_VERSION="${1:?Usage: patch.sh <version> (e.g. v1.35)}"

git -C cri-o checkout -- .
git -C cri-o clean -fd -q

# Find the version-specific patch directory (exact match or fallback to highest)
PATCH_DIR="patches/${CRIO_VERSION}"

if [ ! -d "$PATCH_DIR" ]; then
    echo "No version-specific patches for ${CRIO_VERSION}, finding best match..."
    BEST_MATCH=""
    for d in patches/v*; do
        [ -d "$d" ] || continue
        BEST_MATCH="$d"
    done
    if [ -n "$BEST_MATCH" ]; then
        echo "Using version-specific patches from $BEST_MATCH"
        PATCH_DIR="$BEST_MATCH"
    else
        PATCH_DIR=""
    fi
fi

# Apply common patches, skipping any that have a version-specific override
for p in patches/*.patch; do
    [ -f "$p" ] || continue
    BASENAME="$(basename "$p")"
    if [ -n "$PATCH_DIR" ] && [ -f "${PATCH_DIR}/${BASENAME}" ]; then
        echo "Skipping common patch ${BASENAME} (version-specific override exists)"
        continue
    fi
    echo "Applying common patch ${BASENAME}..."
    patch -d cri-o -p1 < "$p"
done

# Apply version-specific patches
if [ -n "$PATCH_DIR" ]; then
    for p in "$PATCH_DIR"/*.patch; do
        [ -f "$p" ] || continue
        echo "Applying version-specific patch $(basename "$p") from ${PATCH_DIR}..."
        patch -d cri-o -p1 < "$p"
    done
fi

echo "All patches applied successfully for ${CRIO_VERSION}"
