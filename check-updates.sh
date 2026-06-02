#!/bin/bash

set -eEux
set -o pipefail

GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-/proc/self/fd/1}

SUBMODULE_URL="$(git config -f .gitmodules submodule.cri-o.url)"

SUPPORTED_VERSIONS_FILE="supported-versions"
if [ ! -f "$SUPPORTED_VERSIONS_FILE" ]; then
    echo "ERROR: $SUPPORTED_VERSIONS_FILE not found"
    exit 1
fi

# Read minimum version
MIN_VERSION=""
while read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue
    MIN_VERSION="$line"
    break
done < "$SUPPORTED_VERSIONS_FILE"

if [ -z "$MIN_VERSION" ]; then
    echo "ERROR: No minimum version found in $SUPPORTED_VERSIONS_FILE"
    exit 1
fi

MIN_MAJOR="${MIN_VERSION%%.*}"
MIN_MINOR="${MIN_VERSION#*.}"

# Get successfully published releases (exclude drafts — those are failed builds)
EXISTING_RELEASES="$(gh release list --limit 1000 --exclude-drafts --json tagName --jq '.[].tagName')"

NEW_TAGS=""

# Enumerate all upstream tags >= minimum version
REMOTE_TAGS=$(git ls-remote --tags "$SUBMODULE_URL" 'refs/tags/v[0-9]*' | grep -v '\^{}' | sed 's|.*refs/tags/||' | sort -V)

for tag in $REMOTE_TAGS; do
    VER="${tag#v}"
    TAG_MAJOR="${VER%%.*}"
    TAG_REST="${VER#*.}"
    TAG_MINOR="${TAG_REST%%.*}"

    [[ "$TAG_MAJOR" =~ ^[0-9]+$ ]] || continue
    [[ "$TAG_MINOR" =~ ^[0-9]+$ ]] || continue

    # Skip pre-release tags (rc, alpha, beta)
    [[ "$VER" == *-* ]] && continue

    if [ "$TAG_MAJOR" -lt "$MIN_MAJOR" ]; then
        continue
    elif [ "$TAG_MAJOR" -eq "$MIN_MAJOR" ] && [ "$TAG_MINOR" -lt "$MIN_MINOR" ]; then
        continue
    fi

    if [ "${FORCE:-}" != "true" ] && echo "$EXISTING_RELEASES" | grep -qx "$tag"; then
        continue
    fi

    echo "## New tag: $tag" >> "$GITHUB_STEP_SUMMARY"
    NEW_TAGS="${NEW_TAGS} ${tag}"
done

if [ -z "$NEW_TAGS" ]; then
    echo "## No new tags found" >> "$GITHUB_STEP_SUMMARY"
fi
