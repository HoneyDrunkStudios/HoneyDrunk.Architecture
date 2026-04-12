---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["chore", "tier-1", "release", "human-only", "wave-1"]
dependencies: ["vault-bootstrap-extensions", "vault-event-driven-cache-invalidation"]
adrs: []
wave: 1
initiative: adr-0005-0006-rollout
node: honeydrunk-vault
actor: human
version_bump: false
---

# Chore: Tag and release `HoneyDrunk.Vault` v0.3.0 (human-only)

## Summary
After packets 01 (`vault-bootstrap-extensions`) and 02 (`vault-event-driven-cache-invalidation`) are both merged to `main`, push the `v0.3.0` git tag to trigger the NuGet publish pipeline. This is the human release gate — agents do not push tags.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault`

## Actor
**`Human`.** Tag pushes are not delegated to agents. This is the release ceremony for the ADR-0005/0006 Vault work.

## Prerequisites
- [ ] Packet 01 (`vault-bootstrap-extensions`) PR merged to `main`
- [ ] Packet 02 (`vault-event-driven-cache-invalidation`) PR merged to `main`
- [ ] All solution projects confirmed at `0.3.0` in `main`
- [ ] `CHANGELOG.md` has a complete `[0.3.0]` entry covering both packets

## Steps

1. Pull latest `main`:
   ```bash
   git checkout main && git pull
   ```
2. Verify all non-test projects are at `0.3.0`:
   ```bash
   grep -r "<Version>" --include="*.csproj" .
   ```
3. Confirm `CHANGELOG.md` `[0.3.0]` section is complete and accurate
4. Push the tag:
   ```bash
   git tag v0.3.0 && git push origin v0.3.0
   ```
5. Confirm the CI publish workflow triggers and completes successfully on GitHub Actions
6. Verify the new packages appear on NuGet / GitHub Packages

## Acceptance Criteria
- [ ] `v0.3.0` tag exists on `main`
- [ ] CI publish workflow green
- [ ] All solution packages visible at `0.3.0` on the package feed
- [ ] This chore issue closed

## Dependencies
- `vault-bootstrap-extensions` (packet 01) — must be merged first
- `vault-event-driven-cache-invalidation` (packet 02) — must be merged first

## Labels
`chore`, `tier-1`, `release`, `human-only`, `wave-1`
