---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "ci-cd", "ops", "automation"]
dependencies: []
adrs: ["ADR-0008", "ADR-0012"]
initiative: standalone
node: honeydrunk-actions
actor: Agent
---

# CI: Add body-length pre-check + continue-on-failure to file-work-items

## Summary

`scripts/file-work-items.sh` shells out to `gh issue create` per packet without checking whether the packet body fits under GitHub's 65536-character issue-body limit. When a packet exceeds the cap, GraphQL rejects the request with `Body is too long (maximum is 65536 characters)`, the script exits at first failure (`set -euo pipefail`), and any packets queued behind the offender never attempt — leaving the run in a partial-success state that requires a follow-up PR to recover.

Hit on PR #152 (ADR-0031 standup): packet 03 (86 KB body) tripped the limit, packet 04 (also over) never attempted. Architecture#153 / #154 filed; Architecture#NN / #NN had to wait for a trim PR (#155).

Two structural fixes in one PR:

1. **Pre-flight body-length check.** Before any `gh issue create` calls, scan every packet's rendered body and fail fast with a clear error listing each offender (path + size + how many bytes over). Surfaces the problem before any partial state is created.

2. **Continue-on-failure for per-packet creation.** If `gh issue create` returns non-zero for one packet (after the pre-flight has passed), record the failure and proceed to the next packet rather than exiting. Report a summary at the end: which packets filed, which failed, with the failure reason for each. The dep-linking pass should still run for packets that filed successfully.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Actions` — both fixes live in `scripts/file-work-items.sh`. The reusable workflow `.github/workflows/file-work-items.yml` does not need changes (the script's exit code semantics are already what the workflow consumes via `if: always()` on the manifest commit step).

## Motivation

The 65k cap is a GitHub product constraint that has no soft warning — the first time a Grid initiative authors a scaffold packet over the line, the entire downstream filing run blocks until someone notices, opens a follow-up PR, and trims. PR #152 demonstrated this: the auth-wire packet (just under at 65 KB) wouldn't even have attempted because the audit-node-scaffold packet (over at 86 KB) failed first.

The fix is preventive (catch oversized packets at scope-author time, before pushing) and recoverable (when one packet fails for any reason, the rest still file). Both protect the user's edit time — pre-flight surfaces the problem in CI logs the moment the offending packet hits `main`; continue-on-failure means a single bad packet doesn't gate everything around it.

The 65k cap is documented in GitHub's GraphQL schema (`createIssue` mutation, `body` input field) but not in any reference doc the scope agent reads when authoring packets — so a "be more careful next time" remediation doesn't generalize. The script is the right enforcement point.

## Proposed Implementation

### Pre-flight body-length check

In `scripts/file-work-items.sh`, after the new-packet discovery pass (the part that builds the `NEW_PACKETS` array around line ~150–200) and **before** the per-packet filing loop:

```bash
BODY_LENGTH_LIMIT=65536
oversized=()
for packet in "${NEW_PACKETS[@]}"; do
  # Body is the markdown content minus the YAML frontmatter.
  # Frontmatter is delimited by --- at line 1 and a second --- before the body.
  body=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$packet")
  size=$(printf '%s' "$body" | wc -c)
  if (( size > BODY_LENGTH_LIMIT )); then
    over=$(( size - BODY_LENGTH_LIMIT ))
    oversized+=("$packet ($size bytes, $over over)")
  fi
done

if (( ${#oversized[@]} > 0 )); then
  echo "::error::The following packets exceed GitHub's $BODY_LENGTH_LIMIT-character issue body limit and must be trimmed before filing:"
  for entry in "${oversized[@]}"; do
    echo "::error::  $entry"
  done
  echo "::error::Trim the packet bodies (long C# samples, repetitive prose, verbose alternatives sections are the usual culprits) and push again."
  exit 1
fi
```

The check uses `wc -c` on the body excluding frontmatter, matching what `gh issue create --body-file` actually submits. Exit code 1 keeps the workflow's `conclusion: failure` semantics consistent with prior behavior — the workflow author who reads the run log gets a per-packet diagnosis, not an opaque "Body is too long" from GraphQL.

### Continue-on-failure per-packet

In the per-packet filing loop (around line ~250–350), wrap the `gh issue create` call in a per-packet try/capture and accumulate failures rather than exiting:

```bash
filed_packets=()
failed_packets=()

for packet in "${NEW_PACKETS[@]}"; do
  if issue_url=$(file_one_packet "$packet" 2>&1); then
    filed_packets+=("$packet|$issue_url")
  else
    failed_packets+=("$packet|$issue_url")
    echo "::warning::Failed to create issue for $work-item: $issue_url"
    # Continue to next packet; do not exit.
  fi
done
```

`file_one_packet` is whatever helper currently runs the `gh issue create`. Refactor the existing inline body if there isn't one.

At end of run, before exit:

```bash
echo "Filed: ${#filed_packets[@]} packet(s)"
echo "Failed: ${#failed_packets[@]} packet(s)"
if (( ${#failed_packets[@]} > 0 )); then
  echo "::error::Per-packet failures:"
  for entry in "${failed_packets[@]}"; do
    echo "::error::  $entry"
  done
  exit 1
fi
```

The dep-linking pass (the section that runs `addBlockedBy` per packet around line ~381) should iterate over `filed_packets` only — failed packets don't have an issue URL to wire edges from.

### Manifest commit

The existing `if: always()` manifest commit in the workflow keeps the `filed-work-items.json` updates for successful packets even when later packets fail. No workflow change needed.

## Affected Files

- `HoneyDrunk.Actions/scripts/file-work-items.sh` — pre-flight body-length check + per-packet failure capture + summary.

No workflow changes. No Architecture-repo changes. No CHANGELOG entry on Actions (this is internal scripting; Actions ships workflow versions via tags, not CHANGELOG-of-record).

## Acceptance Criteria

- [ ] `scripts/file-work-items.sh` runs a body-length pre-flight check over all `NEW_PACKETS` before entering the per-packet filing loop. Each packet's rendered body (frontmatter excluded) is measured against a `BODY_LENGTH_LIMIT=65536` constant.
- [ ] If any packet exceeds the limit, the script prints `::error::` lines naming each offender with its byte count and how many bytes over, then exits with code 1. No `gh issue create` calls run.
- [ ] If all packets fit, the per-packet filing loop runs to completion regardless of individual failures. A non-zero exit from `gh issue create` on one packet records the failure and continues to the next packet.
- [ ] After the loop, the script prints a summary (`Filed: N`, `Failed: M`) and, if any failures occurred, lists each failed packet with its failure reason and exits with code 1.
- [ ] The dep-linking pass (`addBlockedBy` wiring) iterates only over successfully-filed packets.
- [ ] Manifest commit (`filed-work-items.json` updates) still runs on `if: always()` from the workflow, capturing the successfully-filed packets even on partial failure.
- [ ] Manual smoke test: author a deliberately-oversized test packet (e.g., 70 KB body) under `generated/work-items/active/standalone/` in a throwaway branch, push, observe the workflow fails fast with the per-packet diagnosis (no `gh issue create` attempted), then delete the test packet.

## Boundary Check

- Single repo (HoneyDrunk.Actions); no Architecture-repo changes, no catalog edits, no constitutional invariants, no ADR amendments.
- No `gh` CLI version requirement bump — `gh issue create` exit-code handling is stable across current and recent versions.
- The 65536 limit is hardcoded in the script (matches GitHub's current `createIssue` cap). If GitHub raises or lowers the cap later, this is a one-line change to `BODY_LENGTH_LIMIT`.
- The "continue on failure" change does NOT bypass safety — the script still exits 1 at the end if any packet failed, so the workflow run is correctly marked failed and the manifest commit reflects partial-success state.

## Referenced Invariants

- **Invariant 35** (HoneyDrunk.Actions as the CI/CD control plane) — packet-filing logic lives in the reusable workflow / script in this repo; consumers do not reimplement it.

## Referenced ADR Decisions

- **ADR-0008** D6 (batch-filing action) — this packet hardens that action without changing its semantic contract.
- **ADR-0012** (Grid CI/CD control plane) — Actions owns the implementation; consumer repos do not.

## Constraints

- Do NOT introduce a runtime dependency on `jq` for body extraction unless it's already in the script (use `awk` for frontmatter stripping if `jq` isn't already loaded).
- Do NOT change the workflow file (`.github/workflows/file-work-items.yml`) unless the script's exit-code contract changes — and it shouldn't.
- Do NOT add an Architecture-repo PR for this change — the script is internal to Actions and ships when consumers reference the workflow at the next tag.

## Agent Handoff

**Context:** PR #152 in HoneyDrunk.Architecture (ADR-0031 standup) demonstrated the partial-failure mode. The trim PR (#155) is the recovery. This packet prevents the same failure shape from recurring.

**Key files:**
- `HoneyDrunk.Actions/scripts/file-work-items.sh` (the only file to edit)
- Reference: `HoneyDrunk.Actions/.github/workflows/file-work-items.yml` (read-only, to understand the exit-code contract)

**Test approach:** unit-style verification is awkward because the script depends on `gh` against live GitHub. The manual smoke test in Acceptance Criteria is the practical verification.

**Filing context:** standalone packet — not part of an initiative. `accepts:` is absent because no ADR flips on completion (the referenced ADRs 0008 + 0012 are already Accepted; this is hardening within the scope they defined).
