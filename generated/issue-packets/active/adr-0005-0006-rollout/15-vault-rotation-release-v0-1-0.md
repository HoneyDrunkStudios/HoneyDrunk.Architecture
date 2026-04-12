---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault.Rotation
labels: ["chore", "tier-1", "release", "human-only", "wave-1"]
dependencies: ["vault-rotation-scaffold"]
adrs: ["ADR-0006"]
wave: 1
initiative: adr-0005-0006-rollout
node: honeydrunk-vault
actor: human
version_bump: false
---

# Chore: Tag and release `HoneyDrunk.Vault.Rotation` v0.1.0 (human-only)

## Summary
After packet 06 (`vault-rotation-scaffold`) is merged to `main`, push the `v0.1.0` git tag to trigger the first release of the new repo. This is the human release gate — agents do not push tags.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault.Rotation`

## Actor
**`Human`.** Tag pushes are not delegated to agents.

## Prerequisites
- [ ] Packet 06 (`vault-rotation-scaffold`) PR merged to `main`
- [ ] All non-test projects confirmed at `0.1.0` in `main`
- [ ] `CHANGELOG.md` has a `[0.1.0]` entry describing the scaffold
- [ ] CI pipeline is green on `main`

## Steps

1. Pull latest `main`:
   ```bash
   git checkout main && git pull
   ```
2. Verify all non-test projects are at `0.1.0`:
   ```bash
   grep -r "<Version>" --include="*.csproj" .
   ```
3. Confirm `CHANGELOG.md` `[0.1.0]` section is present
4. Push the tag:
   ```bash
   git tag v0.1.0 && git push origin v0.1.0
   ```
5. Confirm the CI publish workflow triggers and completes successfully
6. Verify packages appear on the feed at `0.1.0`

## Acceptance Criteria
- [ ] `v0.1.0` tag exists on `main`
- [ ] CI publish workflow green
- [ ] `HoneyDrunk.Vault.Rotation`, `HoneyDrunk.Vault.Rotation.Abstractions`, `HoneyDrunk.Vault.Rotation.Providers` all visible at `0.1.0` on the package feed
- [ ] This chore issue closed

## Dependencies
- `vault-rotation-scaffold` (packet 06) — must be merged first

## Labels
`chore`, `tier-1`, `release`, `human-only`, `wave-1`
