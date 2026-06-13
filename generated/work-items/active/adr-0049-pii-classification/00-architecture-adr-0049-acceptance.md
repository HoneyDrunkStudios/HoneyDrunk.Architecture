---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0049", "wave-1"]
dependencies: []
adrs: ["ADR-0049"]
accepts: ["ADR-0049"]
wave: 1
initiative: adr-0049-pii-classification
node: honeydrunk-architecture
---

# Accept ADR-0049 — flip status, amend Invariant 47, add the three classification invariants, register the initiative

## Summary
Flip ADR-0049 (Data Classification, PII Handling, and Retention Schedule) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, **amend Invariant 47** to bind its "sensitive fields" phrase to ADR-0049 D2's `[PiiField(SensitivePii)]` definition, add the **three new classification invariants** ADR-0049 commits in its Consequences/Invariants section to `constitution/invariants.md` at the **reserved range 58–60 per `constitution/invariant-reservations.md`** (see Constraints for the claim procedure), register the `adr-0049-pii-classification` initiative in `initiatives/active-initiatives.md`, and amend ADR-0049 D5's table row for `Audit (AuditEntry.DataChange)` to remove the contradiction between D5 and D6 on the SensitivePii outcome (see "Required ADR amendment" below).

## Context
ADR-0049 commits the Grid's canonical four-tier data-classification taxonomy (Public / Internal / Confidential / Restricted), the PII sub-taxonomy (PII / Sensitive PII / Pseudonymous) with explicit GDPR Article 9 mapping, the Grid-wide retention schedule per data class, the field-level marking mechanism (`[Classification]` and `[PiiField]` attributes), the boundary-redaction extensions to ADRs 0030/0040/0045, the right-to-erasure policy principle (mechanics deferred to ADR-0050), the v1 Azure US East 2 residency commitment, the owners/reviewers rubric, the inventory artifact (`catalogs/data-classification.json`), and the six-phase rollout.

ADR-0049 was authored 2026-05-22 in a batch of cross-cutting Grid-gap ADRs. The forcing functions from the ADR's Context:

- **Invariant 47's "sensitive fields" phrase has no canonical definition.** The reviewer agent (per ADR-0044 D3 category 9 Security) and the `security` specialist (per ADR-0046 D2) cannot enforce a redaction rule that has no definition of what to redact. ADR-0049 D2 supplies the definition (`[PiiField(SensitivePii)]`).
- **ADR-0036 D7's deferred backup-vs-erasure reconciliation is overdue.** Notify Cloud (ADR-0027) will inevitably receive a data-subject-deletion request from an EU recipient; ADR-0049 D6 commits the policy principle (pseudonymous-token-in-audit + erasable PII map), and ADR-0050 (sibling) commits the operational mechanics.
- **The four consumer-product PDRs are blocked.** PDR-0003 (Lately), PDR-0005 (Hearth), PDR-0006 (Currents), PDR-0008 (Curiosities) all describe consumer apps that will collect personal data. None can move to `scope`-driven packet generation without a Grid-wide classification rubric, since per-app packets would each invent their own taxonomy and the drift would be permanent.
- **Florida Digital Bill of Rights effective 2026-07-01** introduces consumer rights to access/correction/deletion/portability — free compliance if D6 mechanics are in place.

ADR-0049 decides:
- **D1** — four-tier classification taxonomy (Public / Internal / Confidential / Restricted), ordered by handling rigor, applied at field level not record level, default-to-Restricted on ambiguity.
- **D2** — PII sub-taxonomy (PII / Sensitive PII / Pseudonymous) with GDPR Article 4 + Article 9 mapping; children's data is Sensitive PII.
- **D3** — Grid-wide retention schedule per data class: telemetry traces/logs 90 days; metrics 93 days; Audit-sourced logs 730 days; audit records minimum 730 days, T0 tenants 7 years; error events 90 days; tenant data indefinite while active with 90-day post-deletion grace; Restricted PII deleted within 30 days of erasure request; backups exempt from immediate erasure per Article 17(3); restore-drill logs 7 years; `generated/incidents/` indefinite.
- **D4** — field-level marking via `[Classification]` and `[PiiField]` attributes in `HoneyDrunk.Kernel.Abstractions`, with `DataClass` and `PiiCategory` enums; `HoneyDrunk.Standards` analyzer rule flags unmarked fields on records inside Restricted-class contexts.
- **D5** — boundary-redaction rules: extends ADR-0030/0040/0045 by binding their "sensitive field" concept to the D4 attributes; defense-in-depth at both emitter and boundary.
- **D6** — right-to-erasure policy principle via pseudonymous-token-in-audit + separately-erasable PII↔token map; `SensitivePii` fields never appear in audit even as tokens; operational mechanics deferred to ADR-0050.
- **D7** — v1 data residency: Azure US East 2 only; EU/UK transfers under SCCs + DPF; non-US tenancy forces a future ADR.
- **D8** — owners and reviewers: classification assignment is field-author's responsibility; `review` agent flags first-pass; `security` specialist invoked for SensitivePii / classification downgrades / new Restricted-boundary work; `database` specialist (promoted to v1 roster) invoked for schema migrations and retention-config changes on PII-bearing stores.
- **D9** — `catalogs/data-classification.json` inventory artifact; `hive-sync` reconciles drift nightly.
- **D10** — six-phase rollout: attributes + analyzer (week 1–2), backfill (week 2–4), redactor integrations (week 3–4), catalog + reconciliation (week 4–6), DPA/TIA/DPF (month 2–3), consumer-app onboarding stores (when PDRs stand up).
- **D11** — relationship to ADRs 0030/0036/0040/0045/0046/0050; extends each, sibling to 0050.

ADR-0049 is a **policy / contract** ADR. The concrete code — the Kernel attributes, the Standards analyzer rule, the Pulse/Audit redactor integrations, the per-Node backfill, the catalog population — lands in `HoneyDrunk.Kernel`, `HoneyDrunk.Standards`, `HoneyDrunk.Pulse`, `HoneyDrunk.Audit`, the per-Node backfills, and `HoneyDrunk.Architecture` (catalog + agent + governance) in this initiative. The DPA/TIA/DPF artifacts land in `HoneyDrunk.Studios`'s `business/` folder. Consumer-app Phase 6 onboarding stores are **out of scope** — they belong with each PDR's standup. Every other packet references ADR-0049's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0049-data-classification-pii-handling-and-retention-schedule.md`:
  - Flip `**Status:** Proposed` to `**Status:** Accepted`.
  - **Required D5 amendment** (see "Required ADR amendment" below). In the D5 table, the `Audit (AuditEntry.DataChange)` row currently writes `[PiiField(SensitivePii)] → [REDACTED:sensitive]`. That contradicts D6 (and the new invariant `59` below), which says SensitivePii is rejected entirely. Replace the SensitivePii outcome in the D5 row with **`REJECTED (per D6 + invariant 59)`** so the ADR is internally consistent before flipping to Accepted.
- `adrs/README.md` — update the ADR-0049 row Status column to Accepted.
- `constitution/invariant-reservations.md` — confirm the ADR-0049 row's `Status` is `Proposed` until this PR opens, then flip to `Merged` (or move to the **Reservation History** table per that file's convention) as part of this PR. The numbers `58/59/60` referenced throughout this packet resolve to the range claimed in that row.
- `constitution/invariants.md`:
  - **Amend Invariant 47** — within the body text of invariant 47 (line 185 of `constitution/invariants.md` at authoring time; verify at branch time), the verbatim sentence reads: `"Data-change details that include sensitive fields must be redacted before append."` Replace it verbatim with: `"Data-change details that include sensitive fields (as defined by ADR-0049 D2 — fields marked` `[PiiField(SensitivePii)]` `) must be redacted before append."` No other wording change. Also append to the trailing `See ADR-0030 D1, D3, D6, D7, D9.` so it reads: `See ADR-0030 D1, D3, D6, D7, D9; ADR-0049 D2 for the "sensitive fields" definition.`
  - **Add three new invariants** at the **reserved numbers `58/59/60` from `constitution/invariant-reservations.md`** under a new `## Data Classification Invariants` section, placed after `## Audit Invariants`. See Proposed Implementation for exact text.
- `initiatives/active-initiatives.md` — register the `adr-0049-pii-classification` initiative with the packet checklist for this folder.

## Required ADR amendment

ADR-0049 D5 and D6 disagree on the SensitivePii outcome at the audit boundary. The D5 redaction-extensions table (currently around lines 149–158 of `adrs/ADR-0049-data-classification-pii-handling-and-retention-schedule.md`; verify at branch time) writes:

> **Audit (`AuditEntry.DataChange`)** | ADR-0030 D3: "sensitive fields must be redacted before append" — undefined | **Defined** by D4: `[PiiField(Pii)]` → pseudonymous token; `[PiiField(SensitivePii)]` → `[REDACTED:sensitive]`; `[PiiField(Pseudonymous)]` → as-is. …

D6 (around lines 175–179) and the Consequences/Invariants section (around line 294) say the opposite: SensitivePii is **never** emitted to the audit channel even as a redaction-token. Packet 05 of this initiative implements the **D6 rejection** behavior. Both ADR readings cannot coexist.

**The fix in this work-item:** in the D5 table row for `Audit (AuditEntry.DataChange)`, replace `[PiiField(SensitivePii)] → [REDACTED:sensitive]` with `[PiiField(SensitivePii)] → REJECTED (per D6 + invariant 59); only the field-name and classification metadata may appear, never via the audit body`. Leave the `[PiiField(Pii)]` and `[PiiField(Pseudonymous)]` clauses in the same row unchanged. This is the minimum change to make D5 and D6 (and packet 05's runtime behavior) read the same. This amendment lands in the same PR that flips ADR-0049 to Accepted — no separate ADR-amendment ADR.

This is the only ADR edit in scope. Do not otherwise restructure ADR-0049.

## Proposed Implementation
1. **Reservation claim (do this first; informs steps 4–5).** Read `constitution/invariant-reservations.md`. The ADR-0049 reservation row claims a size-3 block at `max(invariants.md current max, highest existing reservation) + 1`. At authoring time `invariants.md` max is **53** and the only competing reservation is **ADR-0051 at 54–57**, so this block is **58–60**. Verify at branch time:
   - Recount `invariants.md` — if its max has advanced past 53, recompute.
   - Re-read the reservations table — if any new `Proposed`-status row was added above ADR-0049's, shift this block upward to remain contiguous-and-ascending per that file's rule 5.
   - Use `58` as the lowest number, `59` as the middle number, and `60` as the highest number in the resolved block.
   - The packets in this branch already use `58`/`59`/`60`; if the reservation shifts during rebase, update every reference in this packet and packets **04, 05, 06, 07, 08** before opening the PR.

2. Edit the ADR-0049 header: `**Status:** Proposed` → `**Status:** Accepted`.

3. **Apply the required D5 amendment to `adrs/ADR-0049-…`** (see "Required ADR amendment" above). In the D5 table row for `Audit (AuditEntry.DataChange)`, replace `[PiiField(SensitivePii)] → [REDACTED:sensitive]` with `[PiiField(SensitivePii)] → REJECTED (per D6 + invariant 59); only the field-name and classification metadata may appear, never via the audit body`. This is the only text change inside ADR-0049 beyond the status flip.

4. Update the ADR-0049 index row in `adrs/README.md` to Accepted.

5. **Amend Invariant 47** in `constitution/invariants.md` under `## Audit Invariants`. The current verbatim sentence inside invariant 47's body reads:

   > Data-change details that include sensitive fields must be redacted before append.

   Replace verbatim with:

   > Data-change details that include sensitive fields (as defined by ADR-0049 D2 — fields marked `[PiiField(SensitivePii)]`) must be redacted before append.

   Update the trailing `See ADR-0030 D1, D3, D6, D7, D9.` to `See ADR-0030 D1, D3, D6, D7, D9; ADR-0049 D2 for the "sensitive fields" definition.` No other wording change to invariant 47.

6. Add three new invariants under a new `## Data Classification Invariants` section, placed after the `## Audit Invariants` section, at the resolved reserved numbers `58/59/60`. Text taken verbatim-in-substance from ADR-0049's Consequences "Invariants" subsection:
   - **`58` — Every persisted field, every public API contract field, and every `AuditEntry` payload field carries a `[Classification]` attribute.** Unmarked fields on records inside Restricted-class contexts (persisted by `HoneyDrunk.Data` repositories or shipped through `HoneyDrunk.Audit`'s `AuditEntry.DataChange`) are a CI gate failure under the `HoneyDrunk.Standards` analyzer rule. Explicit `[Classification(DataClass.Public)]` is the way to opt out — the analyzer's purpose is to catch silently-unclassified fields, not to forbid Public data. See ADR-0049 D4.
   - **`59` — `[PiiField(SensitivePii)]`-marked fields never appear in the audit channel, even as redaction-tokens.** The Audit Node rejects appends whose `Before`/`After` payload reflection surfaces a `SensitivePii` marker. Only the field-name-and-class metadata (e.g. "field `TaxIdentifier` of class `SensitivePii` changed") may appear; the values are forbidden entirely. This is stricter than the `Pii` case, which is permitted in the audit channel after pseudonymous-token substitution. See ADR-0049 D5 (as amended in step 3 above), D6.
   - **`60` — Restricted-class data never leaves the v1 Azure US East 2 region.** Cross-region replication for backups (per ADR-0036 D2 geo-redundant storage choices) stays within the US Azure footprint. Any Node that needs non-US storage forces an ADR amendment to this rule. The v1 lawful basis for EU/UK data subjects is SCCs + EU-US DPF per ADR-0049 D7. See ADR-0049 D7.

7. Flip the ADR-0049 row in `constitution/invariant-reservations.md` from the Active Reservations table to the Reservation History table per that file's convention, recording the merge date and the resolved range.

8. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0049-data-classification-pii-handling-and-retention-schedule.md` (status flip + D5-row amendment)
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (flip ADR-0049 row from Active Reservations to Reservation History)
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0049 header reads `**Status:** Accepted`
- [ ] ADR-0049 D5's `Audit (AuditEntry.DataChange)` table row reads the `[PiiField(SensitivePii)] → REJECTED (per D6 + invariant 59)` form, eliminating the D5↔D6 contradiction (see "Required ADR amendment")
- [ ] The ADR-0049 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` ADR-0049 row is moved to **Reservation History** with the merge date and the resolved range
- [ ] `constitution/invariants.md` Invariant 47 is amended to bind "sensitive fields" to ADR-0049 D2 (`[PiiField(SensitivePii)]`); no other wording change to invariant 47
- [ ] `constitution/invariants.md` carries the three new classification invariants at the resolved reserved numbers `58/59/60` (as claimed in `constitution/invariant-reservations.md`) under a new `## Data Classification Invariants` section after `## Audit Invariants` — (`58`) every persisted/API/audit-payload field carries `[Classification]`; (`59`) `SensitivePii` fields never appear in audit even as tokens; (`60`) Restricted data never leaves Azure US East 2 — each citing ADR-0049
- [ ] Every `58/59/60` placeholder in packets **04, 05, 06, 07, 08** of this initiative is replaced with the resolved numbers before this PR opens (single sweep edit; the resolved numbers are the same across all packets)
- [ ] `initiatives/active-initiatives.md` registers the `adr-0049-pii-classification` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01 and 09)
- [ ] No `.claude/agents/` change in this packet (agent rubric updates land in packet 11)

## Human Prerequisites
- **`constitution/invariant-reservations.md` must exist on `main` before this packet executes.** That file is introduced by [PR #288](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/288); ADR-0049 already has a soft-claim row in it for invariants 58–60 (`58`–`60`). If #288 has not merged, hold this packet until it does.

## Referenced ADR Decisions
**ADR-0049 D1 — Four-tier taxonomy.** Public / Internal / Confidential / Restricted; ordered by handling rigor; classification is of the field, not the record; default-to-Restricted on ambiguity.

**ADR-0049 D2 — PII sub-taxonomy.** PII / Sensitive PII / Pseudonymous; Article 9 special-category triggers explicit-consent requirement; children's data is Sensitive PII; pseudonymous identifiers are not directly PII as long as the mapping table is held separately and access-controlled.

**ADR-0049 D5 — Boundary redaction extensions (as amended by this packet).** Audit's `AuditEntry.DataChange` redaction is **defined** by D4: `[PiiField(Pii)]` → pseudonymous token; `[PiiField(SensitivePii)]` → **REJECTED** (per D6 + invariant `59`); `[PiiField(Pseudonymous)]` → as-is. The pre-amendment ADR-0049 text wrote `[REDACTED:sensitive]` for the SensitivePii outcome; this packet amends D5's table row to remove the contradiction with D6.

**ADR-0049 D6 — Right-to-erasure principle.** Pseudonymous tokens in audit + separately-erasable PII↔token map. `SensitivePii` fields are never emitted to the audit channel even as tokens — the audit entry records *that* a Sensitive PII field changed (field name, classification, source Node), not the values.

**ADR-0049 D7 — v1 residency.** Azure US East 2 only; EU/UK transfers under SCCs + DPF; non-US tenancy is a future ADR.

**ADR-0049 Consequences — Invariants.** ADR-0049 amends Invariant 47 (binding "sensitive fields" to `[PiiField(SensitivePii)]`) and adds exactly three new invariants: (1) every persisted/API/audit-payload field carries `[Classification]`; (2) `SensitivePii` fields never appear in audit even as redaction-tokens; (3) Restricted data never leaves Azure US East 2.

## Constraints
- **Acceptance precedes flip.** ADR-0049 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers come from `constitution/invariant-reservations.md`.** The canonical reservation row claims the next free contiguous block (size 3) at `max(invariants.md current max, highest existing reservation) + 1`. At authoring time this resolves to **58, 59, 60** (invariants.md max=53; ADR-0051 reserves 54–57 immediately above). If any new `Proposed`-status reservation lands above ADR-0049's row before this PR opens, the reservations file's collision-resolution procedure (rule 4) applies: shift this block upward to remain contiguous-and-ascending and update both this packet and packets 04/05/06/07/08 in the same rebase. **Never claim a number already in `invariants.md` or already reserved.**
- **Amend Invariant 47, do not renumber.** The amendment is a verbatim sentence-level edit within Invariant 47's existing body text. The invariant number stays 47; the section (`## Audit Invariants`) stays the same.
- **New section.** The three classification invariants are a new cross-cutting topic; create a `## Data Classification Invariants` section after `## Audit Invariants` rather than appending to an unrelated section.
- **D5 amendment is in scope and unavoidable.** See "Required ADR amendment." Without the D5 row fix, ADR-0049 reads as both "redact to `[REDACTED:sensitive]`" (D5) and "reject entirely" (D6 + invariant `59`); packet 05 implements the D6 reading and would diverge from ADR text on merge. The D5 row edit lands in this packet, not in a separate ADR-amendment ADR.
- **Sibling ADR-0050 not in scope.** ADR-0050 (Tenant Lifecycle) consumes this ADR's D6 policy principle for its mechanics. This packet does not flip ADR-0050.
- **No `.claude/agents/` edits here.** The `security` agent's D1–D6 rubric update and the `review` agent's D3 category 9 checklist amendment land in packet 11. The new `database` specialist agent also lands in packet 11.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0049`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0049 to Accepted, amend Invariant 47, add the three classification invariants to `constitution/invariants.md`, and register the data-classification initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0049 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0049 Data Classification rollout, Wave 1.
- ADRs: ADR-0049 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0049 stays Proposed until this PR merges.
- Apply the required D5 amendment (`Audit (AuditEntry.DataChange)` row → SensitivePii REJECTED) in this PR; do not split into a separate ADR amendment.
- Amend Invariant 47 verbatim-sentence in place to bind "sensitive fields" to `[PiiField(SensitivePii)]`; do not renumber.
- Resolve invariant numbers from `constitution/invariant-reservations.md`. At authoring time the resolved block is **58, 59, 60** (max in invariants.md=53; ADR-0051 reserves 54–57). If a new `Proposed`-status reservation lands above ADR-0049's row before merge, follow that file's collision-resolution rule and update placeholders in packets 00 and 04–08 in the same rebase.
- No `.claude/agents/` edits in this packet — they land in packet 11.

**Key Files:**
- `adrs/ADR-0049-data-classification-pii-handling-and-retention-schedule.md` (status + D5 row)
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (claim move to history)
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
