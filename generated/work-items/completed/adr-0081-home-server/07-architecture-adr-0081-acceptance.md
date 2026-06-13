---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "docs", "human-only", "adr-0081", "wave-2"]
dependencies: ["work-item:01", "work-item:02", "work-item:03", "work-item:04", "work-item:05", "work-item:06"]
adrs: ["ADR-0081"]
accepts: ["ADR-0081"]
wave: 2
initiative: adr-0081-home-server
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Flip ADR-0081 to Accepted and record acceptance evidence

## Summary
Flip the `Status:` field of `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md` from `Proposed` to `Accepted`, append an "Acceptance Evidence" section linking the five Acceptance-Criteria artifacts produced in Wave 1, update `initiatives/proposed-adrs.md` to move ADR-0081 out, and update `initiatives/active-initiatives.md` (or `archived-initiatives.md` if migration is complete by acceptance time) to record the rollout state.

## Context
ADR-0081's Acceptance Criteria are met when:
- Hardware target and budget are confirmed (packet 01)
- OS choice is confirmed (packet 02)
- Cloudflare Tunnel + OpenClaw bridge migration plan is documented (packet 04)
- Backup plan for OpenClaw state/config is documented (packet 05)
- Security checklist exists for the server before exposing any tunnel-backed endpoint (packet 03)

This packet is the formal flip once Wave 1 lands. It is `Actor=Human` because the acceptance decision itself is the operator's judgment call — the agent can prepare the diff but should not unilaterally accept architectural decisions.

This packet does **not** require the migration runbook (packet 06) to have been *executed*, only that the runbook *exists* as a documented artifact. ADR-0081 accepts the *decision* to introduce a home server; the execution of the migration is operational work the runbook governs and that can land before, during, or after acceptance depending on how the operator chooses to sequence procurement vs paper acceptance.

## Scope
- Update `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md`: `Status: Proposed` → `Status: Accepted`. Append `**Accepted:** YYYY-MM-DD` under the existing `**Date:**` line. Append an "Acceptance Evidence" section at the end of the doc linking each of the five artifacts.
- Update `initiatives/proposed-adrs.md`: remove the ADR-0081 line (per the existing convention for accepted ADRs).
- Update `initiatives/active-initiatives.md`: add an entry for `adr-0081-home-server` with the Wave 1 + Wave 2 status reflecting whatever is true at acceptance time. If the operator has already executed the migration runbook (packet 06) by the time of acceptance, mark the initiative complete and move it to `archived-initiatives.md` instead.
- Update repo-level `CHANGELOG.md`: finalize the in-progress ADR-0081 entry (started by packet 01) — change "in progress" markers to a released bullet noting ADR-0081 accepted with a list of artifacts.

## Proposed Implementation

### ADR file edit
```diff
- **Status:** Proposed
- **Date:** 2026-05-24
+ **Status:** Accepted
+ **Date:** 2026-05-24
+ **Accepted:** YYYY-MM-DD
```

Append at the end of the ADR:

```markdown
## Acceptance Evidence

Acceptance was reached on YYYY-MM-DD after the five Acceptance-Criteria artifacts were authored and reviewed:

- Hardware brief — `infrastructure/home-server/hardware-brief.md` (packet 01)
- OS and hardening playbook — `infrastructure/home-server/os-and-hardening.md` (packet 02)
- Pre-exposure security checklist — `infrastructure/home-server/pre-exposure-security-checklist.md` (packet 03)
- Tunnel + ADR-0044 webhook-bridge migration plan — `infrastructure/home-server/tunnel-and-bridge-migration-plan.md` (packet 04)
- OpenClaw state/config backup plan — `infrastructure/home-server/backup-plan.md` (packet 05)

Migration runbook (packet 06): `infrastructure/home-server/migration-runbook.md` — execution is operator-paced per D6 and is not a gate on acceptance.

Deferred follow-ups (per Neutral / Follow-up): GPU/local-LLM hosting, cloud webhook relay for offline durability, broader local-infrastructure backup/DR policy. Each is unblocked by a stated trigger and will produce a future ADR when triggered.
```

### `initiatives/proposed-adrs.md`
Remove the line referencing ADR-0081.

### `initiatives/active-initiatives.md` / `archived-initiatives.md`
Pattern-match the format of the existing `adr-0044-cloud-code-review` entry. Include: name, scope (`HoneyDrunk.Architecture` only), description, status of each packet (closed/open), and the acceptance date.

### Repo-level `CHANGELOG.md`
Convert the in-progress entry (created by packet 01 and appended-to by 02–06) into a released entry with the acceptance date and the list of five artifacts.

## Affected Files
- `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md`
- `initiatives/proposed-adrs.md`
- `initiatives/active-initiatives.md` (and possibly `archived-initiatives.md`)
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits live in `HoneyDrunk.Architecture`.
- [x] No code change; no Node touched.
- [x] No secret committed.

## Acceptance Criteria
- [ ] `adrs/ADR-0081-...md` `Status:` is `Accepted` and an `**Accepted:** YYYY-MM-DD` line is present
- [ ] An "Acceptance Evidence" section is appended to the ADR linking all five Wave 1 artifacts with relative paths
- [ ] `initiatives/proposed-adrs.md` no longer lists ADR-0081
- [ ] `initiatives/active-initiatives.md` reflects the rollout state (in progress, awaiting execution, or complete — whichever is true) and is consistent with the convention used for prior ADR rollouts (see `adr-0044-cloud-code-review` entry as a template)
- [ ] If the migration runbook has been fully executed by acceptance time, the initiative is moved to `archived-initiatives.md` instead and `active-initiatives.md` is not modified
- [ ] Repo-level `CHANGELOG.md` in-progress entry is finalized with the acceptance date and a one-line summary
- [ ] All five Wave 1 packets are closed on GitHub before this packet's PR is opened (verifies the dependency chain)
- [ ] No secret value appears in any committed file (invariant 8)

## Human Prerequisites
- [ ] Confirm Wave 1 PR has merged and all five Wave 1 GitHub issues are closed
- [ ] Operator decides the acceptance date (typically the date of this PR's merge)
- [ ] Operator decides whether migration execution has reached completion (drives active vs archived initiative placement)

## Dependencies
- work-item:01 (hardware brief — Acceptance Criterion 1)
- work-item:02 (OS + hardening — Acceptance Criterion 2)
- work-item:03 (security checklist — Acceptance Criterion 5)
- work-item:04 (tunnel + bridge migration plan — Acceptance Criterion 3)
- work-item:05 (backup plan — Acceptance Criterion 4)
- work-item:06 (migration runbook — referenced from acceptance evidence, not a gate)

## Agent Handoff

**Objective:** Formally accept ADR-0081 and record the evidence trail.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Move ADR-0081 from `Proposed` to `Accepted` with full evidence.
- Feature: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure.
- ADRs: ADR-0081 (this packet accepts it).

**Acceptance Criteria:** (mirrored above)

**Dependencies:** Wave 1 (packets 01–06).

**Constraints:**
- ADR-0081 Acceptance Criteria (verbatim): "This ADR is ready to accept when:
  - Hardware target and budget are confirmed.
  - OS choice is confirmed.
  - Cloudflare Tunnel + OpenClaw bridge migration plan is documented.
  - Backup plan for OpenClaw state/config is documented.
  - Security checklist exists for the server before exposing any tunnel-backed endpoint."
  Every bullet maps 1:1 to a Wave 1 packet; none of them require migration *execution*, only that the named artifact is *documented*.
- Existing convention: the format of the ADR status flip, the `proposed-adrs.md` removal, and the `active-initiatives.md` / `archived-initiatives.md` updates follow the pattern established by prior accepted ADRs (e.g., the ADR-0044 acceptance packet at `generated/work-items/active/adr-0044-cloud-code-review/01-architecture-adr-0044-acceptance.md` is a close shape-reference).

**Key Files:**
- `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md`
- `initiatives/proposed-adrs.md`
- `initiatives/active-initiatives.md` (and possibly `archived-initiatives.md`)
- `CHANGELOG.md`

**Contracts:** None.

---

## PR Body Requirements
The PR opened against `HoneyDrunk.Architecture` for this packet must include in its body:

```
Authorship: Human
Work Item: generated/work-items/proposed/adr-0081-home-server/07-architecture-adr-0081-acceptance.md
```

(`Authorship: Human` because the acceptance decision is the operator's call. If the operator delegates the mechanical diff to an agent after deciding to accept, switch to `Authorship: Agent`.)
