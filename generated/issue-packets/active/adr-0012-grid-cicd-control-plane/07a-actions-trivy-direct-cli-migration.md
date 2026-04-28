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

# CI Change: Migrate `release.yml` Trivy step from `aquasecurity/trivy-action` to direct Docker invocation (D4)

## Summary
The container-image vulnerability scan in `release.yml` line 606 currently uses `uses: aquasecurity/trivy-action@0.35.0`, which wraps the Trivy CLI. This violates ADR-0012 D4 (reusable workflows invoke tool CLIs directly; third-party marketplace wrappers are forbidden for tools with stable CLIs). Replace with a direct `docker run aquasec/trivy:<pinned-tag>` invocation matching the pattern already used in `nightly-security.yml`. Single-file edit, single PR, smoke-tested via a workflow_dispatch release simulation.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0012 D4 forbids third-party marketplace wrappers around tools that have a stable CLI. Trivy has a stable CLI and an official Docker image (`aquasec/trivy:<tag>`). `nightly-security.yml` already invokes Trivy via `docker run aquasec/trivy` — the canonical pattern. The `release.yml` container-scan step is the last surviving Trivy marketplace-wrapper invocation in the workflow set. The audit packet (07) catalogs this violation; this packet performs the migration.

The retrofit is mechanical: one `uses:` block becomes one `run:` block. The flags (`format: 'sarif'`, `output: 'container-scan.sarif'`, `severity: 'HIGH,CRITICAL'`, `exit-code: '1'`) are exactly what the Trivy CLI accepts. The image-ref input (`${{ steps.container_tags.outputs.image_tag }}`) becomes a positional CLI argument.

## Proposed Implementation

### `.github/workflows/release.yml` lines ~605-612

**Before:**
```yaml
- name: Scan container image for vulnerabilities
  uses: aquasecurity/trivy-action@0.35.0
  with:
    image-ref: ${{ steps.container_tags.outputs.image_tag }}
    format: 'sarif'
    output: 'container-scan.sarif'
    severity: 'HIGH,CRITICAL'
    exit-code: '1'
```

**After:**
```yaml
- name: Scan container image for vulnerabilities
  shell: bash
  env:
    TRIVY_IMAGE: aquasec/trivy:0.55.0  # pin to current; update via packet 06 / packet 09 cadence
  run: |
    set -euo pipefail
    docker run --rm \
      -v "$PWD:/workspace" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -w /workspace \
      "$TRIVY_IMAGE" \
      image \
      --format sarif \
      --output container-scan.sarif \
      --severity HIGH,CRITICAL \
      --exit-code 1 \
      "${{ steps.container_tags.outputs.image_tag }}"
```

The exact pinned Trivy version is the same one already in use in `nightly-security.yml` (verify at execution time — read `nightly-security.yml`'s Trivy step and copy that pin). If the pin in `nightly-security.yml` differs from `0.55.0` at execution time, use the canonical pin from `nightly-security.yml`, not the example above.

### Update `docs/action-pins.md` if it exists

Packet 06 stands up `docs/action-pins.md`. If 06 has already merged when this packet executes, remove the `aquasecurity/trivy-action` row from the inventory (it is no longer used). If 06 has not merged yet, no inventory edit is needed in this packet — packet 06 will scan the workflows at its execution time and reflect the post-migration state automatically.

### `docs/d4-retrofit-audit.md` cross-link

If packet 07's audit doc has merged when this packet executes, append a one-line "Migrated by Actions#NN" note to the Trivy row in the audit doc's audit table.

### `docs/CHANGELOG.md` (or repo-root)

Append entry referencing ADR-0012 D4 and this migration.

## Affected Files
- `.github/workflows/release.yml` — Trivy step replaced with direct `docker run`
- `docs/action-pins.md` — row removed (if file exists at execution time)
- `docs/d4-retrofit-audit.md` — row annotated (if file exists at execution time)
- `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) — entry

## NuGet Dependencies
None.

## Boundary Check
- [x] Single-repo, single-workflow-file edit (plus optional doc cross-link updates).
- [x] No semantic change to scan behavior — same flags, same exit code, same SARIF output path.
- [x] No new contract surface.

## Acceptance Criteria
- [ ] `release.yml` line ~606 no longer references `aquasecurity/trivy-action`.
- [ ] The replacement `run:` block invokes `docker run aquasec/trivy:<pinned-tag> image --format sarif --output container-scan.sarif --severity HIGH,CRITICAL --exit-code 1 <image-ref>` with the pin matching whatever `nightly-security.yml` uses for its Trivy invocation at execution time.
- [ ] The replacement reproduces the original step's flags (`format`, `output`, `severity`, `exit-code`) exactly.
- [ ] The Docker socket is mounted (`-v /var/run/docker.sock:/var/run/docker.sock`) so the in-container Trivy can scan host-side images, matching the pattern in `nightly-security.yml`.
- [ ] Smoke test: a `workflow_dispatch` test of `release.yml` (or a release-equivalent test if dispatch is gated) against a sandbox image completes with the same Pass/Fail outcome it would have before the migration. The SARIF output is uploaded to GitHub Security as before.
- [ ] If `docs/action-pins.md` exists, the `aquasecurity/trivy-action` row is removed.
- [ ] If `docs/d4-retrofit-audit.md` exists, the Trivy row is annotated with this migration's PR link.
- [ ] `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) updated.

## Human Prerequisites
- [ ] **Smoke test trigger.** After merge, the operator triggers a sandbox release flow (or asks the agent to dispatch on a sandbox tag) so the new `docker run aquasec/trivy` invocation runs end-to-end against a real image. Confirm the SARIF output is uploaded to the Security tab as before.
- [ ] **Pin verification.** Before committing, verify the Trivy version pin in the `run:` block matches the pin used in `nightly-security.yml`. Drift between the two would mean the same tool is pinned at two different versions in the same repo, which is a small consistency hazard.

## Referenced Invariants

> **Invariant 38 (post-acceptance numbering — see packet 01):** Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

This packet's job is to bring `release.yml` line ~606 into compliance with this invariant. Trivy has a stable CLI; `aquasecurity/trivy-action` is a third-party marketplace wrapper; `nightly-security.yml` already demonstrates the canonical direct-CLI pattern.

## Referenced ADR Decisions

**ADR-0012 D4 (Direct CLI invocation):** Reusable workflows in `HoneyDrunk.Actions` invoke tool CLIs directly via `run:` shell steps, installing or pulling the CLI at a pinned version in the same step. The flags passed to the CLI are the flags documented by the tool itself, and any breaking change in the tool's flags becomes visible at the next version bump — reviewable in a PR diff, not silently absorbed.

**ADR-0012 D8 (Gitleaks shared config + direct CLI):** Reference pattern. The Trivy migration follows the same shape (direct invocation, pinned tag, no marketplace wrapper).

## Dependencies
- Soft-blocked by packet 01 for invariant 38 numbering.
- Soft-relates to packet 07 (audit doc — this packet's PR closes one of three known violations).

## Labels
`chore`, `tier-1`, `ci-cd`, `ops`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Replace the `aquasecurity/trivy-action` wrapper at `release.yml` line ~606 with a direct `docker run aquasec/trivy` invocation matching the canonical pattern in `nightly-security.yml`.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Close one of three D4 violations enumerated in packet 07's audit.
- Feature: ADR-0012 Grid CI/CD Control Plane, D4 retrofit.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01 for invariant numbering.
- Soft-relates to packet 07 (audit) and packet 06 (action-pins inventory).

**Constraints:**
- **Invariant 38 (post-acceptance):** Reusable workflows invoke tool CLIs directly. The replacement is a direct `docker run aquasec/trivy:<pin>` invocation; no marketplace wrapper.
- **No semantic change.** Same flags, same SARIF path, same exit code. Reviewing the diff against the original `with:` block, every option must map 1:1 to a CLI flag.
- **Match `nightly-security.yml`'s pin.** The two Trivy invocations in the same repo should use the same pin. If the pins drift, the next pin bump becomes two PRs instead of one. Read `nightly-security.yml` at execution time and copy.

**Key Files:**
- `.github/workflows/release.yml` — primary edit target (line ~606).
- `.github/workflows/nightly-security.yml` — reference pattern + pin source.
- `docs/d4-retrofit-audit.md` — cross-link target if 07 has merged.
- `docs/action-pins.md` — row removal target if 06 has merged.

**Contracts:** No code or schema contracts. The behavioral contract is the SARIF output (same path, same shape) — preserved exactly.
