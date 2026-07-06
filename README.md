# karellen-sysbox-crio

Patched [CRI-O](https://github.com/cri-o/cri-o) builds for
[Sysbox](https://github.com/nestybox/sysbox) Kubernetes integration.

This repository applies the Nestybox/Docker sysbox patches to upstream CRI-O and
produces static `crio` and `pinns` binaries for amd64 and arm64. New upstream
CRI-O releases are discovered and built automatically.

## Patches

Three patches are applied to each CRI-O version, originally from the
[nestybox/cri-o](https://github.com/nestybox/cri-o) sysbox branches:

1. **Container IDs** (`001-container-ids`) -- Interprets pod security context
   UIDs/GIDs as container IDs instead of host IDs. This is the core sysbox
   integration patch.
2. **Static build** (`002-crio-static`) -- Adds a `bin/crio-static` Makefile
   target that builds CRI-O as a fully static binary using pure-Go OpenPGP
   (`containers_image_openpgp`).
3. **Sysctl ENOENT** (`003-sysctl-enoent`) -- Makes `pinns` ignore missing
   sysctl files (ENOENT) in user namespaces.

Patches 2 and 3 are common across all supported versions. Patch 1 differs
across CRI-O minor versions due to upstream refactors; version-specific variants
live under `patches/v<minor>/`. When no version-specific directory exists,
`patch.sh` falls back to the highest available patch set.

## Build artifacts

Pre-built binaries are published as
[GitHub Releases](https://github.com/karellen/karellen-sysbox-crio/releases),
one release per upstream CRI-O tag. Each release contains:

- `crio-v<tag>-amd64.tar.gz`
- `crio-v<tag>-arm64.tar.gz`

Each tarball includes the static `crio` and `pinns` binaries, plus a matching
`crictl` binary from [kubernetes-sigs/cri-tools](https://github.com/kubernetes-sigs/cri-tools).

## Supported versions

All CRI-O minor and micro releases at or above the minimum version in
[`supported-versions`](supported-versions) (currently **1.30**) are tracked.

## How it works

1. **`check-updates.sh`** enumerates upstream CRI-O tags via `git ls-remote`,
   filters by the minimum version, and compares against existing GitHub releases.
2. **`update.yml`** (GitHub Actions, every 6 hours) runs the check and triggers
   a build for each missing tag.
3. **`build.yml`** checks out the CRI-O submodule at the target tag, applies
   patches via `patch.sh`, builds static binaries on native amd64 and arm64
   runners, and publishes a GitHub release. After publishing, it notifies
   [karellen-sysbox](https://github.com/karellen/karellen-sysbox) via
   `repository_dispatch` so the `sysbox-deploy-k8s` images are repackaged
   with the new CRI-O binaries.

Both workflows accept a **force** option for manual dispatch that rebuilds and
clobbers existing releases.

## Adding a new CRI-O version

New minor versions are auto-discovered. If the latest patch set applies cleanly,
no action is needed. If patches fail:

1. Create `patches/v<minor>/` with adapted patch files.
2. Test: `git -C cri-o checkout v<minor>.0 && ./patch.sh v<minor>`

To raise the minimum supported version, edit `supported-versions`.

## Local build

A Docker-based local build is available:

```bash
./build.sh
```

This uses `Dockerfile.build` and `scripts/crio-build.sh` to build all
supported versions in a container.

## License

The patches are derived from [nestybox/cri-o](https://github.com/nestybox/cri-o)
and follow its upstream [Apache 2.0](https://github.com/cri-o/cri-o/blob/main/LICENSE)
license.
