---
name: Repo Feature
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["ci", "tier-1", "ops", "adr-0008", "human-only"]
dependencies: []
adrs: ["ADR-0008"]
initiative: standalone
node: honeydrunk-actions
actor: Human
---

# Prerequisite: Create GH_ISSUE_TOKEN org secret

## Summary

Create a GitHub fine-grained personal access token with `issues:write` on all `HoneyDrunkStudios` repos and store it as the org secret `GH_ISSUE_TOKEN`. This unblocks the D6 batch-filing action (`2026-04-12-actions-packet-filing-action.md`) and the Architecture caller workflow (`2026-04-12-architecture-file-packets-caller.md`).

## Why This Exists as a Separate Packet

Org secret creation requires portal access and cannot be delegated to an agent. It is a one-time human step that unblocks two agent-executable packets. Separating it keeps those packets clean (`actor: Agent`) and makes the dependency explicit.

## Steps

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token
2. Name: `hd-issue-filer`
3. Resource owner: `HoneyDrunkStudios`
4. Repository access: All repositories (or select all current repos)
5. Permissions:
   - Repository permissions → Issues → **Read and write**
   - Repository permissions → Contents → **Read and write** (needed to commit `filed-packets.json` back to Architecture repo)
6. Generate token, copy value immediately
7. Go to `github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`
8. New organization secret → Name: `GH_ISSUE_TOKEN` → Paste value → Access: All repositories → Save

## Verification

```bash
# Smoke-test: create a draft issue in Architecture repo and immediately delete it
gh issue create \
  --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "token smoke test — delete me" \
  --body "verifying GH_ISSUE_TOKEN" \
  --label "ci"
# Then close it:
gh issue close {NUMBER} --repo HoneyDrunkStudios/HoneyDrunk.Architecture
```

## Acceptance Criteria

- [ ] `GH_ISSUE_TOKEN` exists as an org secret accessible to all repositories
- [ ] Token has `issues:write` and `contents:write` on all org repos
- [ ] Smoke-test issue creates and closes successfully

## Unblocks

- `2026-04-12-actions-packet-filing-action.md`
- `2026-04-12-architecture-file-packets-caller.md`
