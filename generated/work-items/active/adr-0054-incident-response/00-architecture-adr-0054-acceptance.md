---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0054", "wave-1"]
dependencies: []
adrs: ["ADR-0054"]
accepts: ["ADR-0054"]
wave: 1
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Accept ADR-0054 — flip status, add the three incident-response invariants, register the initiative

## Summary
Flip ADR-0054 (Incident Response and On-Call Model for a One-Person Studio) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the **three** new invariants ADR-0054 commits in its Consequences/Invariants section to `constitution/invariants.md` (numbered **`{N1}, {N2}, {N3}`** — the three-wide block reserved for ADR-0054 in `constitution/invariant-reservations.md`), and register the `adr-0054-incident-response` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0054 binds the Grid's existing incident-shaped signals (App Insights alerts per ADR-0040, error captures per ADR-0045, budget alerts per ADR-0052, canary failures per ADR-0012, DR drill outcomes per ADR-0036, Audit anomalies per ADR-0030, Stripe webhook failures per ADR-0037) to a defined response process shaped by the one-person-studio constraint. The decisions are:

- **D1** — Four severity levels (SEV-1/2/3/4) keyed to **customer impact**, with explicit ack and communication targets. SEV defaults map approximately to ADR-0036 DR tiers; severity can be promoted but not demoted without a recorded reason.
- **D2** — Operator availability is **09:00–21:00 ET, 7 days a week** for tenant-impacting SEV-1/2; outside-window SEV-1/2 alerts page but acknowledgment is best-effort; SEV-3/4 never page outside coverage. The Notify Cloud SLA publishes 99.5% / 99.0% (within / overall) and the 15-min / best-effort ack split.
- **D3** — Push-to-phone via **two redundant paths**: primary through `HoneyDrunk.Notify` Communications channel; secondary via **PagerDuty Starter** (~$21–25/month). Both required because Notify-itself-down is a credible failure mode.
- **D4** — Single alert routing table mapping every signal source (App Insights, `IErrorReporter`, Azure Monitor budgets, canary failures, Audit, Vault, Stripe, DR drills, tenant-initiated tickets) to a default severity and routing target.
- **D5** — Single-page rule with 1-hour fingerprint dedup; auto-resolve when condition clears for ≥5 minutes; operator manual override (ack / resolve).
- **D6** — Seven-state incident lifecycle: Open → Acknowledged → Investigating → Mitigating → Resolved → Reviewing → Closed.
- **D7** — Incident-record template at `generated/incidents/YYYY-MM-DD-<slug>.md` with machine-readable front-matter (incident_id, severity, status, opened/acknowledged/investigating/mitigating/resolved/reviewing/closed timestamps, mtta/mtmitigate/mttr minutes, customer impact, affected nodes/tenants, alert sources, post-mortem link).
- **D8** — Blameless post-mortem cadence: SEV-1/2 required within **5 business days**; SEV-3 optional; SEV-4 not required. Blameless template at `generated/incidents/post-mortems/`.
- **D9** — Communication channels: Atlassian Statuspage (Starter when first paying tenant exists; static-page v0 fallback until then); tenant emails through `HoneyDrunk.Communications`; in-product banner deferred to Notify Cloud.
- **D10** — Per-Node runbooks at `repos/{node}/runbooks/` with minimum set (`restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`, `escalation.md` for Tier 0). Operator agent (ADR-0018) consults runbooks during incident mitigation.
- **D11** — Quarterly game days; first within 30 days post-acceptance.
- **D12** — Second-human-on-call hand-off is a forward-looking appendix gated on a specific trigger (second person with prod credentials + contract + PagerDuty onboarding). No infrastructure for it now.
- **D13** — Honesty constraint: published SLAs and process commitments must reflect what one human plus AI agents can actually deliver. Tighter SLAs require ADR amendment first.

The forcing functions (from the ADR's Context):

- **Notify Cloud GA (PDR-0002 / ADR-0027)** is the first paying-tenant surface and cannot ship a published SLA without ADR-0054's coverage-hour and acknowledgment commitments behind it.
- **The ADR-0034–0047 wave just landed** introducing observability, error tracking, cost alerts, and DR drills — each emits signals that need a defined receiving end.
- **The AI-sector standup wave (ADR-0016–0025)** is about to introduce nine Nodes with operationally novel failure modes whose blast radius needs a paired response model.
- **The one-person constraint is load-bearing** — standard SRE on-call models do not transfer; pretending otherwise produces an unworkable runbook and a credibility hit during the first real incident.

ADR-0054 is a **policy / decision** ADR. The concrete code (the Notify paging integration, the Pulse synthetic probe, the Communications templates, the Actions generators, the alert-routing wiring, the runbook minimum set, the operator-agent amendment, the game-day scaffolding) lands in the implementing packets (02–12). Catalog updates land as packet 01.

Every other packet in this initiative references ADR-0054's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Invariant Numbering
ADR-0054 adds **three** invariants from its Consequences/Invariants section. Invariant numbers are coordinated via `constitution/invariant-reservations.md` — read that file before editing `constitution/invariants.md` and confirm the three-wide block reserved for ADR-0054 (today: **61–63**). If the reservations file has shifted because another ADR landed first, take the new next-free block and update every `{N1}`/`{N2}`/`{N3}` placeholder below before committing. The reservations-file row stays "Proposed" until this packet merges, then moves to **Reservation History** with the merge date.

The three invariants, numbered **`{N1}, {N2}, {N3}`**, taken verbatim-in-substance from ADR-0054's Consequences "Invariants" subsection:

- **`{N1}` — Every paying-tenant-impacting incident (SEV-1 / SEV-2) produces a record in `generated/incidents/` with the D7 template's required front-matter.** Missing records is a CI gate failure (the gate is implemented as a `hive-sync` check that diffs PagerDuty's incident log against the directory). See ADR-0054 D6, D7.

- **`{N2}` — Every SEV-1 and SEV-2 incident has a post-mortem filed within 5 business days of close.** Missing post-mortems flag in the nightly `hive-sync` report. See ADR-0054 D8.

- **`{N3}` — Every deployable Node has the minimum runbook set per D10** (`restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`; `escalation.md` additionally for Tier 0 Nodes per ADR-0036). Missing runbooks block the Node's next release tag. See ADR-0054 D10.

## Scope
- `adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0054 row Status column to Accepted.
- `constitution/invariants.md` — add the three new invariants (incident-record-for-SEV-1/2, 5-business-day post-mortem SLA, minimum runbook set per deployable Node), numbered **`{N1}, {N2}, {N3}`** — the three-wide block reserved for ADR-0054 in `constitution/invariant-reservations.md` (see Constraints).
- `constitution/invariant-reservations.md` — move the ADR-0054 row from **Active Reservations** to **Reservation History** with the merge date.
- `initiatives/active-initiatives.md` — register the `adr-0054-incident-response` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0054 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0054 index row in `adrs/README.md` to Accepted.
3. Read `constitution/invariant-reservations.md` and confirm the three-wide block reserved for ADR-0054 (today: **61–63**). If the reservations file has shifted because another ADR landed first, take the new next-free block and update every `{N1}`/`{N2}`/`{N3}` placeholder in this packet body before committing.

   Add the three new invariants to `constitution/invariants.md`, numbered **`{N1}, {N2}, {N3}`**, in the appropriate section (a new `## Incident Response Invariants` section placed after the existing operational-substrate invariants is acceptable). The exact texts as listed in Invariant Numbering above. Cite ADR-0054 D6/D7/D8/D10 where the invariant binds.
4. Move the ADR-0054 row in `constitution/invariant-reservations.md` from **Active Reservations** to **Reservation History** with the merge date.
5. Register the initiative in `initiatives/active-initiatives.md` with a "Tracking" section listing every packet in this folder (00 through 13) and an exit criterion: "ADR-0054 is Accepted; PagerDuty Starter is provisioned; Statuspage v0 (or Starter on first paying tenant) is live; Notify and Pulse paging-substrate packets have shipped; the `generated/incidents/` template and the `HoneyDrunk.Actions` generators exist; Communications tenant-email templates land; Azure Monitor → PagerDuty wiring per D4 is configured; the operator agent consults per-Node runbooks; the three `hive-sync` drift checks (incident-record/PagerDuty, post-mortem deadline, runbook freshness) are wired; the first game day has run; the Notify Cloud draft SLA reflects D2."

## Affected Files
- `adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0054 header reads `**Status:** Accepted`
- [ ] The ADR-0054 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the three new invariants (incident-record for every SEV-1/2 with the D7 front-matter; 5-business-day post-mortem SLA for SEV-1/2; minimum runbook set per deployable Node), each citing ADR-0054, numbered with the block claimed from `constitution/invariant-reservations.md` (today **61–63**)
- [ ] `constitution/invariant-reservations.md` — ADR-0054 row moved from **Active Reservations** to **Reservation History** with the merge date
- [ ] `initiatives/active-initiatives.md` registers the `adr-0054-incident-response` initiative with a packet checklist (00 through 13) and an exit criterion
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)
- [ ] No template file added in this packet (the D7 incident-record and D8 post-mortem templates land in packet 02)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0054 D6 — Incident lifecycle.** Open → Acknowledged → Investigating → Mitigating → Resolved → Reviewing → Closed. Each state transition is recorded in the incident record with a timestamp.

**ADR-0054 D7 — Incident record template.** Every incident produces a markdown file at `generated/incidents/YYYY-MM-DD-<slug>.md` with the front-matter described in the ADR.

**ADR-0054 D8 — Post-mortem cadence.** SEV-1/2 post-mortems are required within 5 business days of close; blameless template.

**ADR-0054 D10 — Per-Node runbook minimum set.** `restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md` for every deployable Node; `escalation.md` for Tier 0 Nodes per ADR-0036.

**ADR-0054 Consequences — Invariants.** ADR-0054 adds three invariants. Final numbering claimed from `constitution/invariant-reservations.md`; the three `hive-sync` drift checks that enforce them land in packet 13.

## Constraints
- **Acceptance precedes flip.** ADR-0054 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Three invariants, reserved block.** The three invariants land at the numbers claimed in `constitution/invariant-reservations.md` (today **61–63**). If a collision shifts the block, update every `{N1}`/`{N2}`/`{N3}` placeholder in this packet body before committing. Do not renumber existing invariants.
- **No template files here.** The D7 incident-record and D8 post-mortem template files land in packet 02. The invariant text references the templates but does not require the files to exist before this packet merges — the invariant comes online when packet 02 lands.
- **No catalog edits here.** The `generated/incidents/` contract registration and the `repos/{node}/runbooks/` convention land in packet 01.
- **No `hive-sync` wiring here.** The three drift checks that operationalize the new invariants (incident-record vs. PagerDuty log, post-mortem 5-business-day tracker, runbook freshness) land in packet 13.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0054`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0054 to Accepted, add the three incident-response invariants to `constitution/invariants.md`, and register the incident-response initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0054 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0054 Incident Response rollout, Wave 1.
- ADRs: ADR-0054 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet on the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0054 stays Proposed until this PR merges.
- Three invariants land at the numbers claimed in `constitution/invariant-reservations.md` (today **61–63**); update the `{N1}`/`{N2}`/`{N3}` placeholders if the reservations file has shifted. Do not renumber existing invariants.
- Move the ADR-0054 row from **Active Reservations** to **Reservation History** in the reservations file.
- No template files in this packet; the D7/D8 templates land in packet 02.
- No `hive-sync` wiring here; the three drift checks land in packet 13.

**Key Files:**
- `adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
