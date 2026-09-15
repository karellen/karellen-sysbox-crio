#!/bin/bash

set -eEux
set -o pipefail

CRIO_VERSION="${1:?Usage: patch.sh <version> (e.g. v1.35)}"

git -C cri-o checkout -- .
git -C cri-o clean -fd -q

# Find the version-specific patch directory (exact match, or fall back to the
# highest patch set that is not newer than the requested version). A newer set
# is written against later upstream refactors and will not apply: once
# patches/v1.37 exists, a v1.36 build still has to use patches/v1.35.
PATCH_DIR="patches/${CRIO_VERSION}"

if [ ! -d "$PATCH_DIR" ]; then
    echo "No version-specific patches for ${CRIO_VERSION}, finding best match..."
    BEST_MATCH=""
    for ver in $(for d in patches/v*; do if [ -d "$d" ]; then basename "$d"; fi; done | sort -V); do
        # Ascending order, so the last version that sorts at or below the
        # requested one is the best match.
        if [ "$(printf '%s\n%s\n' "$ver" "$CRIO_VERSION" | sort -V | head -1)" = "$ver" ]; then
            BEST_MATCH="patches/${ver}"
        fi
    done
    if [ -n "$BEST_MATCH" ]; then
        echo "Using version-specific patches from $BEST_MATCH"
        PATCH_DIR="$BEST_MATCH"
    else
        echo "ERROR: no patch set at or below ${CRIO_VERSION} in patches/" >&2
        exit 1
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
