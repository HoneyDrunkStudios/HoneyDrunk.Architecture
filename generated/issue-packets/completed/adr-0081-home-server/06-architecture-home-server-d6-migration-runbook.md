---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "docs", "infrastructure", "adr-0081", "wave-1"]
dependencies: []
adrs: ["ADR-0081"]
accepts: []
wave: 1
initiative: adr-0081-home-server
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Author the home-server D6 incremental migration runbook (ADR-0081 D6)

## Summary
Author `infrastructure/home-server/migration-runbook.md` — the operator's top-level checklist for executing the entire D6 migration from workstation to home server, with each of D6's six steps expanded into "what to do, how to verify, when to stop." Pulls together packets 02 (hardening), 03 (security checklist), 04 (tunnel + bridge plan), and 05 (backup plan) into one runbook the operator follows end-to-end.

## Context
ADR-0081 D6 sequences the migration in six steps. Packets 02–05 cover individual artifacts; this packet is the conductor. Without it, the operator at execution time has to assemble the order from the ADR plus four other docs. The runbook collapses that to one page with cross-links.

The runbook is also where the **stop conditions** live: each step has an explicit "do not proceed if..." gate. ADR-0081 D6 step 4 ("Verify ADR-0044 webhook delivery on one Architecture PR") is the most important of these — until that verification passes, steps 5 and 6 do not begin.

## Scope
- New doc: `infrastructure/home-server/migration-runbook.md`.
- Updates `infrastructure/home-server/README.md` to list it.

## Proposed Implementation

### Document structure for `migration-runbook.md`

1. **Pre-flight**
   - Hardware online and reachable (packet 01 hardware brief)
   - OS installed and hardening playbook applied (packet 02)
   - Pre-exposure security checklist reviewed (packet 03 — walked at step 3 below)
   - Backup tooling installed and first manual backup taken (packet 05)

2. **Step 1 — Stand up server OS and basic hardening** (D6 step 1)
   - Defer to packet 02's playbook.
   - Stop condition: hardening playbook "Applied to … on …" line is filled in.

3. **Step 2 — Install OpenClaw, Git, Node/.NET/Python toolchains as needed** (D6 step 2)
   - Concrete list of toolchains, install order, version-pin disposition.
   - Stop condition: OpenClaw starts under its dedicated service account, Git clones a public repo successfully, each toolchain reports `--version`.

4. **Step 3 — Move Cloudflare Tunnel and ADR-0044 webhook bridge** (D6 step 3)
   - Walk packet 03's pre-exposure security checklist.
   - Execute packet 04's tunnel + bridge migration plan.
   - Stop condition: a manual GitHub webhook redelivery from the Architecture repo settings succeeds against the new tunnel, the bridge log confirms signature verification, and OpenClaw is invoked locally.

5. **Step 4 — Verify ADR-0044 webhook delivery on one Architecture PR** (D6 step 4) — **THE GATE**
   - Open a throwaway PR against `HoneyDrunk.Architecture` (a trivial doc change is fine).
   - Confirm the cloud reviewer runs end-to-end on the home-server-hosted path and posts its review comment back.
   - Wait at least 24 hours and confirm at least one webhook delivery occurred during a wall-clock window when the workstation was asleep.
   - Stop condition: **do not proceed to step 5 until the 24-hour verification passes.** If the path is unreliable at this point, rollback per packet 04 and investigate before moving any more workloads.

6. **Step 5 — Move scheduled jobs one at a time** (D6 step 5)
   - Inventory: the scheduled Lore sourcing and signal review jobs called out in ADR-0081's Context section, plus any other workstation cron/scheduled tasks the operator wants on the home server.
   - For each: stop the workstation job, install the equivalent on the home server, run once manually, confirm output, then enable on schedule.
   - Stop condition (per job): one full scheduled run completes successfully on the home server before the next job is migrated.

7. **Step 6 — Only then disable workstation cron/poll fallbacks that the server replaces** (D6 step 6)
   - For each migrated workload, disable the workstation supervisor entry (do not delete; leave restorable for emergency rollback).
   - Stop condition: every workload listed in this runbook has its workstation entry disabled, and one full week of operation has elapsed without an unrecovered failure.

8. **Post-migration**
   - Update ADR-0081 status: this is the trigger for packet 07 (the acceptance flip).
   - Record migration completion date in this runbook.
   - File any operational issues discovered during the migration as Reactive-source packets per ADR-0043 D4 (e.g., "OpenClaw startup is slow under service-account user" → new packet in `proposed/` rather than a TODO in this runbook).

## Affected Files
- `infrastructure/home-server/migration-runbook.md` (new)
- `infrastructure/home-server/README.md` (update)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] Doc lives in `HoneyDrunk.Architecture/infrastructure/home-server/`.
- [x] No code change; no Node touched.
- [x] No secret committed.

## Acceptance Criteria
- [ ] `infrastructure/home-server/migration-runbook.md` exists with pre-flight + all six D6 steps + post-migration sections
- [ ] Each of the six D6 steps has an explicit stop condition (do-not-proceed gate)
- [ ] D6 step 4's 24-hour verification gate is unambiguous and called out as **the** load-bearing gate before steps 5 and 6 begin
- [ ] Steps 1, 3, and 6 cross-link to packets 02, 03+04, and 05 respectively (with relative `infrastructure/home-server/…` paths)
- [ ] Step 5 lists the specific scheduled jobs the operator intends to migrate (Lore sourcing + signal review at minimum, per ADR-0081 Context)
- [ ] Step 6 documents the "disable, do not delete" rule for workstation supervisor entries (emergency rollback path)
- [ ] Post-migration section instructs the operator to trigger packet 07 (ADR-0081 acceptance flip) once steps 1–6 complete
- [ ] `infrastructure/home-server/README.md` lists this artifact
- [ ] Repo-level `CHANGELOG.md` entry for ADR-0081 appended (per invariants 12, 27)
- [ ] No secret value appears in any committed file (invariant 8)

## Human Prerequisites
- [ ] None for authoring. Executing the runbook end-to-end is the operator's work, expected to span days to weeks (D6 is incremental by design).

## Dependencies
None for *authoring*. For *execution*, the runbook references packets 02, 03, 04, and 05 — but those can land in the same combined Wave 1 PR, so by the time the operator executes the runbook the cross-links resolve.

## Agent Handoff

**Objective:** Produce the top-level runbook the operator follows to move OpenClaw, the ADR-0044 bridge, the tunnel, and scheduled jobs from the workstation to the home server in D6's prescribed order.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make D6's six-step sequence executable and gated, so the migration is incremental, verifiable, and reversible at every step.
- Feature: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure.
- ADRs: ADR-0081 (this initiative); ADR-0044 (the load-bearing consumer of the bridge whose move is the gate at step 4); ADR-0043 (the Reactive packet source for migration-discovered issues).

**Acceptance Criteria:** (mirrored above)

**Dependencies:** None among the Wave 1 packets for authoring.

**Constraints:**
- ADR-0081 D6 (full text — the runbook implements this verbatim): "The workstation setup remains valid until the home server is ready. Migration order:
  1. Stand up server OS and basic hardening.
  2. Install OpenClaw, Git, Node/.NET/Python toolchains as needed.
  3. Move Cloudflare Tunnel and ADR-0044 webhook bridge.
  4. Verify ADR-0044 webhook delivery on one Architecture PR.
  5. Move scheduled jobs one at a time.
  6. Only then disable workstation cron/poll fallbacks that the server replaces."
- ADR-0081 D1 (workload set): "OpenClaw Gateway and Honeyclaw runtime state; ADR-0044 webhook bridge and Cloudflare Tunnel process; Scheduled local automation jobs where local context/tools matter; Local agent sandboxes, worktrees, and experimental runtimes; Lightweight observability/log capture for local automation." — these are the workloads step 5 inventories.
- ADR-0081 Initial-excluded-workload set (Implementation Notes): "Customer-facing production APIs; Revenue-node hosting; Public dashboards without Cloudflare Access or equivalent protection; Unbounded autonomous agent loops." — the runbook must not migrate any of these onto the home server.

**Key Files:**
- `infrastructure/home-server/migration-runbook.md` (new — primary artifact)
- `infrastructure/home-server/README.md` (update)
- `CHANGELOG.md` (append)

**Contracts:** None.

---

## PR Body Requirements
The PR opened against `HoneyDrunk.Architecture` for this packet must include in its body:

```
Authorship: Agent
Packet: generated/issue-packets/proposed/adr-0081-home-server/06-architecture-home-server-d6-migration-runbook.md
```
