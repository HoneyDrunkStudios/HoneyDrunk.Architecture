---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ci-cd", "ops", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-actions
---

# CI Change: Migrate `release.yml` SBOM step from `anchore/sbom-action` to direct `syft` CLI (D4)

## Summary
The SBOM-generation step in `release.yml` line 317 currently uses `uses: anchore/sbom-action@v0`, which wraps the `syft` CLI under the hood. This violates ADR-0012 D4 (third-party marketplace wrappers forbidden for tools with stable CLIs). Replace with a direct `syft` invocation: install the CLI from Anchore's binary distribution at a pinned version, then run `syft <path> -o spdx-json=<output>`. Single-file edit, single PR, output-shape preserved (same SPDX-JSON file at the same path).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0012 D4 forbids third-party marketplace wrappers for tools with stable CLIs. `syft` (the SBOM generator that `anchore/sbom-action` wraps) is a stable CLI distributed as a single static binary by Anchore at https://github.com/anchore/syft/releases. The wrapper offers no value beyond the direct invocation other than the convenience of GitHub-action-style inputs. Per D4, the convenience is not worth the silent-version-bump risk.

The audit packet (07) catalogs this as one of three known violations; this packet performs the migration. `release.yml` line 317's `with:` block has three keys: `path`, `format`, `output-file`. Each maps cleanly to a `syft` CLI flag.

## Proposed Implementation

### `.github/workflows/release.yml` lines ~316-322

**Before:**
```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    path: ${{ inputs.working-directory }}
    format: spdx-json
    output-file: ${{ inputs.working-directory }}/artifacts/sbom.spdx.json
    upload-artifact: false
```

**After:**
```yaml
- name: Generate SBOM
  shell: bash
  env:
    SYFT_VERSION: v1.18.0  # pin to current release; verify at execution time
    WORKING_DIR: ${{ inputs.working-directory }}
  run: |
    set -euo pipefail
    
    # Install syft CLI (direct binary download, not a wrapper).
    INSTALL_DIR="$RUNNER_TEMP/syft"
    mkdir -p "$INSTALL_DIR"
    curl -sSfL "https://raw.githubusercontent.com/anchore/syft/main/install.sh" \
      | sh -s -- -b "$INSTALL_DIR" "$SYFT_VERSION"
    
    # Generate SBOM.
    "$INSTALL_DIR/syft" \
      "dir:$WORKING_DIR" \
      -o "spdx-json=$WORKING_DIR/artifacts/sbom.spdx.json"
```

**Pin verification.** Before committing, check the latest stable `syft` release at https://github.com/anchore/syft/releases and pin to that version. Treat the `v1.18.0` above as a placeholder.

**Why `dir:` prefix.** `syft` accepts multiple source schemes: `dir:`, `image:`, `file:`, etc. The current wrapper's `path:` input maps to scanning a directory tree. Use the explicit `dir:` prefix in the migration to remove ambiguity.

**Install via the canonical Anchore installer.** Anchore maintains `install.sh` at the repo root of `anchore/syft`; it pins to the `$SYFT_VERSION` argument and writes the binary to `$INSTALL_DIR`. This matches D4's "direct CLI install + invocation" pattern. The installer itself is a small shell script; reading it at the pinned commit is part of the review.

### Update `docs/action-pins.md` if it exists

If packet 06 has merged when this packet executes, remove the `anchore/sbom-action` row from the inventory (no longer used). If 06 has not merged, no inventory edit needed here.

### `docs/d4-retrofit-audit.md` cross-link

If packet 07's audit doc has merged when this packet executes, append a "Migrated by Actions#NN" note to the SBOM row in the audit table.

### `docs/CHANGELOG.md` (or repo-root)

Append entry referencing ADR-0012 D4 and this migration.

## Affected Files
- `.github/workflows/release.yml` — SBOM step replaced with direct `syft` invocation
- `docs/action-pins.md` — row removed (if file exists)
- `docs/d4-retrofit-audit.md` — row annotated (if file exists)
- `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) — entry

## NuGet Dependencies
None.

## Boundary Check
- [x] Single-repo, single-workflow-file edit.
- [x] No semantic change to SBOM output — same SPDX-JSON file at the same path with the same scan target.
- [x] No new contract surface.

## Acceptance Criteria
- [ ] `release.yml` line ~317 no longer references `anchore/sbom-action`.
- [ ] The replacement `run:` block installs `syft` at a pinned version via Anchore's `install.sh` and invokes it directly.
- [ ] The replacement preserves the original step's behavior: `path` becomes `dir:$WORKING_DIR`, `format: spdx-json` becomes `-o spdx-json=...`, the output file lands at `$WORKING_DIR/artifacts/sbom.spdx.json`.
- [ ] The `upload-artifact: false` semantics are preserved — the new step does not upload an artifact (a downstream step handles artifact upload).
- [ ] The pinned `SYFT_VERSION` is the latest stable `syft` release as of execution time, not the placeholder `v1.18.0` shown in this packet body.
- [ ] Smoke test: a `workflow_dispatch` test of `release.yml` (or a release-equivalent test) produces a valid SPDX-JSON file at the expected path. The file parses as JSON and contains the expected SBOM document structure.
- [ ] If `docs/action-pins.md` exists, the `anchore/sbom-action` row is removed.
- [ ] If `docs/d4-retrofit-audit.md` exists, the SBOM row is annotated with this migration's PR link.
- [ ] `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) updated.

## Human Prerequisites
- [ ] **Smoke test trigger.** After merge, trigger a sandbox release flow so the new `syft` install + invocation runs end-to-end. Confirm the SPDX-JSON file is generated at the expected path and downstream steps that consume it (e.g. artifact upload) still pass.
- [ ] **Pin currency.** Verify the `SYFT_VERSION` pin against the latest GitHub release at execution time. The placeholder in this packet body may be stale.

## Referenced Invariants

> **Invariant 38 (post-acceptance numbering — see packet 01):** Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

`syft` has a stable CLI distributed as a single binary; `anchore/sbom-action` is the marketplace wrapper. The migration brings `release.yml` line ~317 into compliance.

## Referenced ADR Decisions

**ADR-0012 D4 (Direct CLI invocation):** Tool CLIs are installed via `run:` shell steps at a pinned version. The install is cheap (a single `curl` + `sh`), the flags passed to the CLI are the documented flags, and any breaking change becomes visible at the next version bump — reviewable in a PR diff, not silently absorbed by a wrapper's input-shape translation.

**ADR-0012 D8 (Gitleaks shared config + direct CLI):** Reference implementation. The SBOM migration follows the same shape (direct binary install, pinned version, direct invocation).

## Dependencies
- Soft-blocked by packet 01 for invariant 38 numbering.
- Soft-relates to packet 07 (audit doc — this packet closes one of three known violations) and packet 06 (action-pins inventory).

## Labels
`chore`, `tier-1`, `ci-cd`, `ops`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Replace the `anchore/sbom-action` wrapper at `release.yml` line ~317 with a direct `syft` CLI install + invocation.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Close one of three D4 violations enumerated in packet 07's audit.
- Feature: ADR-0012 Grid CI/CD Control Plane, D4 retrofit.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01.
- Soft-relates to packet 07 (audit) and packet 06 (inventory).

**Constraints:**
- **Invariant 38 (post-acceptance):** Direct CLI invocation; no marketplace wrapper.
- **Output-path stability.** Downstream steps in `release.yml` consume the SPDX-JSON file at `$WORKING_DIR/artifacts/sbom.spdx.json`. The new step must produce the file at exactly that path or downstream steps break.
- **Pinned install only.** Do not use `latest` — pin to a specific `syft` version. Treat `v1.18.0` in the packet body as a placeholder; verify the latest stable release at execution time and use that.
- **No artifact upload.** The wrapper's `upload-artifact: false` is the existing behavior — preserve it. A downstream step is responsible for artifact upload, not this step.

**Key Files:**
- `.github/workflows/release.yml` — primary edit target (line ~317).
- `docs/d4-retrofit-audit.md` — cross-link target if 07 has merged.
- `docs/action-pins.md` — row removal target if 06 has merged.

**Contracts:** Behavioral contract is the SPDX-JSON file at the expected path. Preserved exactly.
