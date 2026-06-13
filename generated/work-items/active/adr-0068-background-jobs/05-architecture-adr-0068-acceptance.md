---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0068", "wave-4"]
dependencies: ["work-item:00", "work-item:01", "work-item:02", "work-item:03", "work-item:04"]
adrs: ["ADR-0068"]
accepts: ["ADR-0068"]
wave: 4
initiative: adr-0068-background-jobs
node: honeydrunk-architecture
---

# Accept ADR-0068 — flip status, promote the four invariants from Proposed to Accepted, close the initiative

## Summary
Flip ADR-0068 (Background Job and Recurring Work Substrate) from Proposed to Accepted now that the Done-When list is satisfied: the `job-deploy-container-apps-job.yml` reusable workflow has landed (packet 02); the first in-Node `BackgroundService` under D2 has shipped (Notify retry pump, packet 03); the first cross-Node Container Apps Job under D3 has shipped (Communications cadence scheduler, packet 04). This packet updates the ADR header, updates the ADR index row in `adrs/README.md`, promotes the four ADR-0068 invariants in `constitution/invariants.md` from `**Status:** Proposed (tied to ADR-0068)` to fully Accepted (the Proposed marker is removed), and marks the `adr-0068-background-jobs` initiative complete in `initiatives/active-initiatives.md`.

## Context
ADR-0068's Done-When list: ADR-0063 is Accepted (paired prerequisite — operator-verified); `job-deploy-container-apps-job.yml` workflow lands (packet 02); first cross-Node Container Apps Job ships (packet 04 — Communications cadence); first in-Node `BackgroundService` under this ADR ships (packet 03 — Notify retry pump); `infrastructure/reference/tech-stack.md` reflects the Jobs deferral (packet 00); `initiatives/roadmap.md` reflects the deferral (packet 00); `repos/HoneyDrunk.Vault.Rotation/boundaries.md` records the grandfather (packet 00); Communications and Notify context reflect substrate choices (packet 00); scope agent flips Status → Accepted (this packet).

This packet is the **flip-at-the-end** acceptance pattern — opposite of the more common ADR-acceptance-first model. ADR-0068's authors committed acceptance to evidence (deploy workflow + first consumers) rather than authorial intent; this packet completes the loop after the evidence is in.

The four invariants — `{N1}` (in-Node `BackgroundService`), `{N2}` (cross-Node Container Apps Jobs + naming), `{N3}` (idempotency on every state-mutating job), `{N4}` (job observability) — were recorded in packet 01 with the explicit marker `**Status:** Proposed (tied to ADR-0068); promoted on ADR-0068 acceptance per packet 05 of adr-0068-background-jobs`. The actual block-of-four numbers were claimed from `constitution/invariant-reservations.md` at packet 01's execution time (the registry's next-free pointer named ADR-0068's block as 83/84/85/86 at packet-authoring time; the executor reconfirms by reading `constitution/invariants.md` and the registry's reservation-history entry for ADR-0068). This packet removes the marker, making the four invariants Accepted in the same PR that flips the ADR. **If packet 01 shifted the block upward** at merge time, this packet promotes whatever block 01 actually used — read the current state of `constitution/invariants.md` at execution time and promote those exact invariants.

ADR-0063 acceptance is a **soft cross-init prerequisite** per the ADR's Done-When list. ADR-0063 (paired clock policy ADR) was Proposed alongside ADR-0068. If ADR-0063 has not yet been Accepted at this packet's filing time, the operator either (a) holds this packet until ADR-0063 is also Accepted, or (b) decides that the cron + `TimeProvider` rules are already in force in code (packets 03 and 04 inline-cite them as live rules) and that ADR-0063's text-state can lag — recording the choice in this packet's PR description. The default recommendation: hold until ADR-0063 is Accepted, since the Done-When list is explicit.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0068-background-job-and-recurring-work-substrate.md` — flip `**Status:** Proposed` → `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0068 row Status column to Accepted (the row may need to be added if it isn't yet present — verify at execution time; ADR-0068 was authored 2026-05-23 and may not yet have an index row).
- `constitution/invariants.md` — remove the `**Status:** Proposed (tied to ADR-0068); promoted on ADR-0068 acceptance per packet 05 of adr-0068-background-jobs` marker from each of the four ADR-0068 invariants (the `{N1}`/`{N2}`/`{N3}`/`{N4}` block packet 01 claimed from the reservation registry). The invariants are now Accepted (no marker means Accepted, per the convention in the file).
- `constitution/invariant-reservations.md` — move the ADR-0068 row from **Active Reservations** to **Reservation History** with the merge date (per the file's "When a reservation is consumed" convention).
- `initiatives/active-initiatives.md` — mark `adr-0068-background-jobs` complete (the initiative is finished — all five preceding packets have shipped; move the entry from active to whichever section the file uses for completed initiatives, or update its status in place per the file's existing convention).

## Proposed Implementation
1. **Verify Done-When is satisfied.** Confirm in the PR description:
   - ADR-0063 is Accepted (operator-verified — see Constraints if ADR-0063 is not yet Accepted at filing time).
   - Packet 02 (`job-deploy-container-apps-job.yml` reusable workflow in HoneyDrunk.Actions) is merged on `main`.
   - Packet 03 (Notify retry pump as `BackgroundService`) is merged on `main`.
   - Packet 04 (Communications cadence Container Apps Job) is merged on `main`.
   - Packet 00 (catalog/reference updates) is merged on `main`.
   - Packet 01 (Proposed invariants) is merged on `main`.
2. **Edit `adrs/ADR-0068-background-job-and-recurring-work-substrate.md` header:** `**Status:** Proposed` → `**Status:** Accepted`.
3. **Update `adrs/README.md`** — locate or add the ADR-0068 index row; set Status to Accepted; verify Sector and Date match the ADR's frontmatter. If the index row does not yet exist (ADR-0068 may have been authored without its README row landing yet), add it following the sibling rows' format.
4. **Promote the four invariants in `constitution/invariants.md`.** Locate the four ADR-0068 invariants (the `{N1}`/`{N2}`/`{N3}`/`{N4}` block packet 01 claimed). For each one, **remove** the `**Status:** Proposed (tied to ADR-0068); promoted on ADR-0068 acceptance per packet 05 of adr-0068-background-jobs` marker line. The invariant text itself is unchanged; only the marker line is removed. The invariant numbers stay the same. The `## Background Job Invariants` section heading (or whatever section packet 01 placed them under) stays.
5. **Move the ADR-0068 reservation row to history.** Edit `constitution/invariant-reservations.md`: move the ADR-0068 row from **Active Reservations** to **Reservation History** with the merge date.
6. **Update `initiatives/active-initiatives.md`** — mark `adr-0068-background-jobs` complete. Whether that is a move to a completed-initiatives section, a status field change in place, or a checkbox flip depends on the file's existing convention — match the precedent set by ADR-0042 and ADR-0045 initiatives' completion records, or by whichever initiatives have most recently been closed.

## Affected Files
- `adrs/ADR-0068-background-job-and-recurring-work-substrate.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (row moved from Active Reservations to Reservation History)
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule maps exactly.
- [x] No code change in any other repo.
- [x] No catalog change — D4's "no `honeydrunk-jobs` entry" stays honored.
- [x] No new invariant — the four invariants were recorded in packet 01; this packet only promotes their status.
- [x] No ADR text change beyond the Status header — the body of ADR-0068 stays as-is.

## Acceptance Criteria
- [ ] ADR-0068 header reads `**Status:** Accepted`
- [ ] The ADR-0068 row in `adrs/README.md` reflects Accepted (or is added if it didn't previously exist)
- [ ] Each of the four ADR-0068 invariants (the `{N1}`/`{N2}`/`{N3}`/`{N4}` block packet 01 claimed) no longer carries the `**Status:** Proposed (tied to ADR-0068); promoted on ADR-0068 acceptance per packet 05 of adr-0068-background-jobs` marker — they are now Accepted (no marker)
- [ ] The four invariants' text itself is unchanged from packet 01 — only the marker line is removed
- [ ] The four invariants keep their numbers (the `{N1}`/`{N2}`/`{N3}`/`{N4}` block from packet 01)
- [ ] The `## Background Job Invariants` section heading remains
- [ ] No other invariant is touched
- [ ] `constitution/invariant-reservations.md` has the ADR-0068 row moved from Active Reservations to Reservation History with the merge date
- [ ] `initiatives/active-initiatives.md` marks `adr-0068-background-jobs` complete per the file's existing convention
- [ ] The PR description confirms ADR-0063 is Accepted (or records the operator-recorded decision to flip ADR-0068 ahead of ADR-0063 per Constraints)
- [ ] The PR description confirms packets 00, 01, 02, 03, 04 are merged on `main` (Done-When evidence)
- [ ] ADR-0068's body text is unchanged (only the Status header is flipped)

## Human Prerequisites
- [ ] **ADR-0063 (paired clock policy ADR) should be Accepted before this packet's PR merges**, per ADR-0068's Done-When list. If ADR-0063 has not yet been Accepted, the operator decides whether to (a) hold this packet, or (b) flip ADR-0068 ahead of ADR-0063 (recording the rationale: cron + `TimeProvider` rules are already in force in packets 03/04 code which inline-cite them). Default: hold.
- [ ] **All five preceding packets must be merged.** The agent verifies merge status on `main` for packets 00, 01, 02, 03, 04 before opening this PR.
- [ ] **Container Apps Job in production is healthy.** Packet 04's first prod deploy should be observed running at least one successful cron cycle (a 30-minute observation window) before this packet's acceptance flip — the Done-When list reads "the first job migrated (or stood-up) under the new substrate," which implies the Job is actually running, not just deployed. The operator confirms via the Azure portal that `caj-hd-comms-cadence-prod` has at least one successful execution recorded.

## Referenced ADR Decisions
**ADR-0068 "If Accepted" follow-up — flip is at the end.** "Scope agent flips Status → Accepted after the deploy workflow lands and the first job migrated (or stood-up) under the new substrate." This packet completes that follow-up step.

**ADR-0068 "Done When" — full list.** ADR-0063 Accepted; `job-deploy-container-apps-job.yml` lands; first cross-Node Container Apps Job ships (Communications cadence per D11); first in-Node `BackgroundService` ships (Notify retry pump per D11); tech-stack/roadmap reflect the Jobs deferral; Vault.Rotation grandfather recorded; Communications/Notify context reflect substrate choices; Scope agent flips Status → Accepted.

**ADR-0068 Catalog obligations — invariant promotion.** "Promote D6 (idempotency on every job), D7 (retry policy defaults), and D8 (observability) into numbered invariants once Accepted — scope agent assigns invariant numbers in the same PR that flips Status." Packet 01 pre-assigned the numbers (the `{N1}`/`{N2}`/`{N3}`/`{N4}` block claimed from `constitution/invariant-reservations.md`); this packet completes the promotion by removing the Proposed marker.

## Constraints
- **All five preceding packets must be merged before this packet's PR opens.** Hard `dependencies: ["work-item:00", "work-item:01", "work-item:02", "work-item:03", "work-item:04"]` (packets 00 and 01 are transitive dependencies of those). The agent verifies merge status on `main`.
- **ADR-0063 acceptance is a soft prerequisite.** If ADR-0063 is not yet Accepted at this packet's filing time, the default is to hold — but the operator may flip ADR-0068 ahead of ADR-0063 if the code reality already enforces ADR-0063's rules (packets 03 and 04 cite ADR-0063 D1/D6/D7 inline). Record the choice in the PR description.
- **No invariant text change.** Only the `**Status:** Proposed ...` marker line is removed. The numbers stay; the text stays; the section heading stays.
- **No catalog change.** D4's "no `honeydrunk-jobs` entry" remains in force; this packet does not add one. `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json` are not modified.
- **Body of ADR-0068 stays as-is.** Only the Status header at the top of the ADR file changes. The body — Context, Decision, Consequences, Alternatives Considered — is unchanged.
- **README row may need to be added.** ADR-0068 may not yet have an `adrs/README.md` index row at this packet's filing time. If absent, add it following the sibling rows' format (ID / Title / Status=Accepted / Date / Sector / Impact); do not invent fields that aren't in ADR-0068's frontmatter.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0068`, `wave-4`

## Agent Handoff

**Objective:** Flip ADR-0068 to Accepted now that the Done-When list is satisfied — workflow landed, first consumers shipped, catalog/invariants/context reflect the decisions.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close the ADR-0068 acceptance loop. After this packet merges, the four invariants are in force and the substrate decisions are governing rules for future cross-Node and in-Node background work.
- Feature: ADR-0068 Background Job and Recurring Work Substrate rollout, Wave 4 (closing).
- ADRs: ADR-0068 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — hard. `job-deploy-container-apps-job.yml` must be on `main`.
- `work-item:03` — hard. Notify retry pump must be on `main`.
- `work-item:04` — hard. Communications cadence Job must be on `main`.
- Packets 00 and 01 are transitive dependencies (02/03/04 already depend on 00 via their own `dependencies:`).

**Constraints:**
- Verify Done-When is satisfied in the PR description (all five preceding packets merged; ADR-0063 status verified).
- Only the Status header on the ADR and the Proposed marker on the four invariants change. No invariant text change, no catalog change, no ADR body change.
- ADR-0063 acceptance is a soft prerequisite — default hold until accepted; operator may flip ahead with recorded rationale.

**Key Files:**
- `adrs/ADR-0068-background-job-and-recurring-work-substrate.md` — Status header.
- `adrs/README.md` — index row.
- `constitution/invariants.md` — remove Proposed markers from the four ADR-0068 invariants.
- `initiatives/active-initiatives.md` — mark complete.

**Contracts:** None changed.
