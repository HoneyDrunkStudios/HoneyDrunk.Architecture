# Dispatch Plan: ADR-0009 Package Scanning Rollout

**Date:** 2026-04-11
**Trigger:** ADR-0009 (Package Scanning — Vulnerability and Dependency Freshness) proposed
**Type:** Multi-repo
**Sector:** Core
**Site sync required:** No
**Rollback plan:** Delete the new `.github/workflows/` files and revert `publish.yml` from any repo if a workflow causes unexpected failures. No application code changes, no version bumps — fully reversible.

## Summary

ADR-0009 formalises the package scanning policy for the HoneyDrunk Grid. `HoneyDrunk.Actions` already contains all the necessary reusable workflows (`pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`) and the `release/generate-notes` composite action — the missing piece is consumer wiring in each .NET repo.

This rollout creates four workflow files and migrates `publish.yml` release notes in each of the 8 .NET repos:

1. **`pr.yml`** — calls `pr-core.yml@main` on `pull_request` to `main`. Includes vulnerability scan gate at `High+` severity.
2. **`nightly-security.yml`** — calls `nightly-security.yml@main` nightly at 02:00 UTC. Runs full vulnerability scan, CodeQL SAST, gitleaks secrets, Trivy IaC.
3. **`nightly-deps.yml`** — calls `nightly-deps.yml@main` weekly on Monday at 03:00 UTC. Reports outdated and deprecated NuGet packages.
4. **`hive-field-mirror.yml`** — calls `hive-field-mirror.yml@main` on issue events for project board field sync.
5. **`publish.yml` (modify)** — replace static release-body template with `generate-notes` action that auto-discovers the repo-level `CHANGELOG.md`.

No application code changes. No version bumps. Tier 1.

## Execution Model

All 8 packets are independent and can be executed in parallel on Codex Cloud. There are no cross-repo dependencies and no wave ordering required.

## Packets

All packets are parallel — no wave sequencing needed:

- [ ] `HoneyDrunk.Kernel` — [`01-kernel-wire-up-scan-workflows.md`](01-kernel-wire-up-scan-workflows.md)
- [ ] `HoneyDrunk.Auth` — [`02-auth-wire-up-scan-workflows.md`](02-auth-wire-up-scan-workflows.md)
- [ ] `HoneyDrunk.Data` — [`03-data-wire-up-scan-workflows.md`](03-data-wire-up-scan-workflows.md)
- [ ] `HoneyDrunk.Transport` — [`04-transport-wire-up-scan-workflows.md`](04-transport-wire-up-scan-workflows.md)
- [ ] `HoneyDrunk.Vault` — [`05-vault-wire-up-scan-workflows.md`](05-vault-wire-up-scan-workflows.md)
- [ ] `HoneyDrunk.Pulse` — [`06-pulse-wire-up-scan-workflows.md`](06-pulse-wire-up-scan-workflows.md)
- [ ] `HoneyDrunk.Notify` — [`07-notify-wire-up-scan-workflows.md`](07-notify-wire-up-scan-workflows.md)
- [ ] `HoneyDrunk.Web.Rest` — [`08-web-rest-wire-up-scan-workflows.md`](08-web-rest-wire-up-scan-workflows.md)

## Exit Criteria

- All 8 repos have `.github/workflows/pr.yml`, `.github/workflows/nightly-security.yml`, `.github/workflows/nightly-deps.yml`, and `.github/workflows/hive-field-mirror.yml`
- All 8 repos have `publish.yml` using `generate-notes` action instead of static body template
- All 8 repos have a repo-level `CHANGELOG.md` next to the `.slnx` file
- PR workflow appears as a check on at least one PR in each repo
- At least one nightly-security run completes successfully per repo (SARIF uploaded to Security tab)
- At least one nightly-deps run completes successfully per repo (artifact uploaded)

## Archival

When all 8 packets reach `Done` on the org Project board and the exit criteria above are met, move the entire `active/adr-0009-package-scanning-rollout/` folder to `archive/adr-0009-package-scanning-rollout/` in one commit. Partial archival is forbidden.

## `gh` CLI Commands — File All Issues At Once

```bash
PACKETS="generated/issue-packets/active/adr-0009-package-scanning-rollout"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/01-kernel-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Auth \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/02-auth-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Data \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/03-data-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Transport \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/04-transport-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/05-vault-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Pulse \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/06-pulse-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Notify \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/07-notify-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Web.Rest \
  --title "Wire up PR validation and nightly scan workflows" \
  --body-file $PACKETS/08-web-rest-wire-up-scan-workflows.md \
  --label "chore,tier-1,adr-0009"
```
