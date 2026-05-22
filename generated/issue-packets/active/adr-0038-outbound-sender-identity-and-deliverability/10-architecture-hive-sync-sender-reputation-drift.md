---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0038", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0038", "ADR-0014"]
accepts: ["ADR-0038"]
wave: 3
initiative: adr-0038-outbound-sender-identity-and-deliverability
node: honeydrunk-architecture
---

# Extend hive-sync to reconcile sender_reputation_status and surface DMARC/warmup drift

## Summary
Extend the `hive-sync` agent definition to reconcile the `sender_reputation_status` field added in packet 01 — detecting sending identities stuck below their target DMARC posture, sending identities with no warmup progress, and missing-record drift — and surface each as a board-item drift finding per ADR-0014.

## Context
ADR-0038 D7 puts warmup state in `catalogs/grid-health.json` (`sender_reputation_status`, packet 01). ADR-0038 D2 commits a staged-strict DMARC path (`p=none` → `p=quarantine` → `p=reject`) and a staged SPF path (`~all` → `-all`). Without a reconciliation pass, a sending identity can silently sit at `p=none` forever — which is exactly the "stay at `p=none`" anti-pattern ADR-0038's Alternatives Considered rejects ("`p=none` ... offers no protection and signals to recipient filters that the domain isn't serious").

`hive-sync` is the Grid's drift-detection agent (ADR-0014, runs through OpenClaw scheduled/manual execution). It already reconciles board-item correspondence and, per the ADR-0036 initiative, DR-tier completeness and overdue restore drills. This packet adds a `sender_reputation_status` reconciliation lens, consistent with that pattern — a docs/agent-definition change, no runtime code.

The drift conditions to detect:

- **Missing record set.** A sending identity at `status: warmup` or `steady-state` whose `dmarc_policy` is `none` or `n/a` (when it should not be) — the full SPF + DKIM + DMARC set is incomplete. This is the packet-00 invariant ("every sending subdomain has SPF + DKIM + DMARC ... DMARC at minimum `p=quarantine`") expressed as a drift check.
- **Stuck DMARC.** A sending identity that has been at `dmarc_policy: none` past the 14-day observation window ADR-0038 D2 sets, or at `quarantine` long past the point where `reject` is the documented steady state — flagged for the operator to advance the policy.
- **Stuck SPF.** A sending identity at `spf_qualifier: ~all` well past the ≥30-day clean-sending window — flagged to advance to `-all`.
- **No warmup progress.** A sending identity at `status: warmup` with no progress recorded over an extended period.

## Scope
- `.claude/agents/hive-sync.md` — add a `sender_reputation_status` reconciliation section to the agent's reconciliation contract.

## Proposed Implementation
1. **Read `.claude/agents/hive-sync.md`** and locate its reconciliation-contract / drift-detection section (the section the ADR-0036 initiative extended for DR-tier reconciliation — this packet follows the same shape).
2. **Add a `sender_reputation_status` reconciliation lens** describing how `hive-sync` reconciles the catalog field:
   - For each entry in `grid-health.json` `sender_reputation_status`, evaluate the drift conditions above.
   - **Missing record set** — `status` is `warmup`/`steady-state` but the record set is incomplete (`dmarc_policy: none`/`n/a` for an active email identity): a drift finding. This is the packet-00 invariant restated as a check.
   - **Stuck DMARC** — `dmarc_policy: none` past the D2 14-day observation window, or `quarantine` indefinitely: a drift finding recommending policy advancement.
   - **Stuck SPF** — `spf_qualifier: ~all` past the D2 ≥30-day window: a drift finding recommending advancement to `-all`.
   - **No warmup progress** — `status: warmup` with stale `notes` over an extended period: a drift finding.
3. **Surface findings as board items** — consistent with ADR-0014 D3 and how DR-tier drift is surfaced: each finding becomes a board item mirrored onto The Hive, represented in `initiatives/board-items.md` per invariant 38.
4. **Note the determination inputs** — the field carries the data; reconciliation is date-arithmetic against the D2 windows (14 days for DMARC observation, 30 days for SPF). State the windows in the agent definition so the check is self-contained.

## Affected Files
- `.claude/agents/hive-sync.md`

## NuGet Dependencies
None. This packet touches only the `hive-sync` agent-definition Markdown; no .NET project.

## Boundary Check
- [x] `.claude/agents/hive-sync.md` lives in `HoneyDrunk.Architecture` — the agent definitions are repo-resident.
- [x] No code change in any repo — agent-definition extension only.
- [x] No new cross-Node runtime dependency.
- [x] Consistent with the ADR-0036 initiative's `hive-sync` DR-tier extension — same agent, same reconciliation-contract pattern.

## Acceptance Criteria
- [ ] `.claude/agents/hive-sync.md` has a `sender_reputation_status` reconciliation section
- [ ] The section detects missing record sets (the packet-00 SPF/DKIM/DMARC invariant restated as a drift check)
- [ ] The section detects stuck DMARC (`p=none` past 14 days; `quarantine` past steady-state target) and stuck SPF (`~all` past 30 days)
- [ ] The section detects warmup identities with no recorded progress
- [ ] Findings are surfaced as board items per ADR-0014 D3 / invariant 38 (`initiatives/board-items.md`)
- [ ] The D2 reconciliation windows (14-day DMARC observation, 30-day SPF) are stated in the agent definition so the check is self-contained
- [ ] No other agent definition is modified

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0038 D2 — Email authentication, staged-strict path.** DMARC: `p=quarantine` with `pct=100` after 14 days of `p=none` aggregate-report observation; steady state `p=reject`. SPF: `~all` during warmup, `-all` once reputation is established (≥30 days of clean sending). These windows are the reconciliation thresholds.

**ADR-0038 D7 — Warmup posture.** Warmup status is tracked in `catalogs/grid-health.json` (`sender_reputation_status`). This packet makes the field actively reconciled rather than passively recorded.

**ADR-0038 Alternatives Considered — "Skip DMARC at strict policy; stay at `p=none`."** Rejected: "`p=none` is for observation only; it offers no protection." The stuck-DMARC drift check is the mechanical guard against silently never advancing past `p=none`.

**ADR-0014 — Hive sync.** `hive-sync` reconciles board-item correspondence and drift; findings without a `filed-packets.json` entry are mirrored onto The Hive via `initiatives/board-items.md` (invariant 38). The agent runs through OpenClaw scheduled/manual execution.

## Constraints
> **Invariant 38 — The Architecture repo tracks all Hive board items.** Drift findings surfaced by `hive-sync` that are not packet-originated are represented in `initiatives/board-items.md`. The new `sender_reputation_status` findings follow that rule.

- **Agent-definition change only.** No runtime code — this extends the `hive-sync` agent's reconciliation contract, the same way the ADR-0036 initiative did for DR-tier drift.
- **Self-contained check.** State the D2 windows (14-day, 30-day) in the agent definition; do not make the check depend on reading the ADR.
- **Follow the existing reconciliation-section shape.** Match how `hive-sync.md` already structures its DR-tier / board-item reconciliation lenses.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0038`, `wave-3`

## Agent Handoff

**Objective:** Extend the `hive-sync` agent definition to reconcile `sender_reputation_status` and surface DMARC/SPF/warmup drift as board-item findings.

**Target:** `HoneyDrunk.Architecture` (`.claude/agents/hive-sync.md`), branch from `main`.

**Context:**
- Goal: Make the `sender_reputation_status` catalog field actively reconciled so a sending identity cannot silently sit at `p=none` forever — the ADR-0038 anti-pattern.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 3.
- ADRs: ADR-0038 D2 / D7 (primary), ADR-0014 (hive-sync reconciliation contract).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — hard. The `sender_reputation_status` field must exist for `hive-sync` to reconcile it.

**Constraints:**
- Agent-definition change only — no runtime code.
- State the D2 windows (14-day DMARC, 30-day SPF) in the agent definition — self-contained check.
- Follow the existing `hive-sync.md` reconciliation-section shape (DR-tier lens is the model).

**Key Files:**
- `.claude/agents/hive-sync.md`

**Contracts:** None changed — agent-definition extension only.
