# karellen-sysbox-crio

Patched CRI-O builds for Sysbox Kubernetes integration. Applies Nestybox/Docker
sysbox patches to upstream cri-o/cri-o and produces static binaries.

## Repository Structure

- `cri-o/` — git submodule tracking upstream `cri-o/cri-o` on `main` branch
- `patches/v<version>/` — per-version patch sets (001-container-ids, 002-crio-static, 003-sysctl-enoent)
- `supported-versions` — minimum CRI-O version; all minor/micro versions at or above are auto-discovered
- `patch.sh` — applies version-appropriate patches to the cri-o submodule
- `check-updates.sh` — detects new upstream tags for supported versions
- `build.sh` — local build script (builds all versions via Docker)
- `scripts/crio-build.sh` — build script that runs inside the Docker container
- `Dockerfile.build` — build container (Ubuntu Jammy + Go + CRI-O build deps)

## Patches

Three patches are applied per version, originally from nestybox/cri-o sysbox branches:

1. **001-container-ids.patch** — Interprets pod security context UIDs/GIDs as container IDs
   instead of host IDs. This is the core sysbox integration patch.
2. **002-crio-static.patch** — Adds `bin/crio-static` Makefile target for static builds.
3. **003-sysctl-enoent.patch** — Makes pinns ignore missing sysctl files (ENOENT) in
   user namespaces.

Patches 2 and 3 are common across all versions and live at `patches/*.patch`.
Patch 1 differs across versions due to upstream refactors and lives in
`patches/v<version>/`. When no version-specific directory exists (e.g. v1.36),
`patch.sh` falls back to the highest available version's patches.

## CI/CD

- `update.yml` — Runs every 6 hours, compares upstream CRI-O tags against existing
  GitHub releases, triggers `build.yml` for each missing tag
- `build.yml` — Builds a single CRI-O tag (via `workflow_dispatch`), creates a
  GitHub release per tag with per-arch tarballs (e.g. `v1.35.3` release contains
  `crio-v1.35.3-amd64.tar.gz` and `crio-v1.35.3-arm64.tar.gz`)

## Adding a New CRI-O Version

New minor versions are auto-discovered from upstream tags. If the latest
patch set applies cleanly (patch.sh falls back to the highest available
patches directory), no action is needed. If patches fail to apply:

1. Create `patches/v<version>/` with adapted patch files
2. Test: `git -C cri-o checkout v<version>.0 && ./patch.sh v<version>`

To raise the minimum supported version, edit `supported-versions`.

## Build Artifacts

One GitHub release per upstream CRI-O tag. Each release contains:
- `crio-v<tag>-amd64.tar.gz` — static `crio` and `pinns` binaries for amd64
- `crio-v<tag>-arm64.tar.gz` — static `crio` and `pinns` binaries for arm64

These are consumed by karellen-sysbox's k8s deployment image build.
