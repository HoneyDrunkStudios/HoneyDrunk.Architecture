---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0080", "wave-1"]
dependencies: []
adrs: ["ADR-0080"]
accepts: ["ADR-0080"]
wave: 1
initiative: adr-0080-vendor-lockin
node: honeydrunk-architecture
---

# Accept ADR-0080 — flip status, add the three vendor-posture invariants, register the initiative

## Summary
Flip ADR-0080 (Vendor Lock-In Posture and Exit-Readiness Hedges) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new vendor-posture invariants ADR-0080 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0080-vendor-lockin` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0080 commits the Grid's **vendor posture as a chosen position** rather than accidental drift. Across the last twelve months the Grid has accumulated vendor relationships at every layer (Azure for compute/config/secrets/telemetry/cache/identity; GitHub for source/CI/projects; Cloudflare for DNS/edge; Stripe for payments; Anthropic and OpenAI for AI; Resend/Twilio/Expo for Notify default providers). Each source ADR picked the right vendor for its surface; none of them, individually or collectively, stated the Grid's posture toward vendor lock-in as a chosen position — what is accepted, what is hedged, what is abstracted, what triggers a re-evaluation, and what the honest exit cost looks like per vendor.

The ADR decides:

- **D1** — Per-vendor posture is one of three: **Accept (deep, intentional)**, **Hedge (active)**, or **Abstract (already portable)**. The three-posture vocabulary is the only vendor-posture language the Grid uses; "multi-cloud," "vendor-neutral," "cloud-agnostic," and similar enterprise-shaped framings are explicitly not in the Grid's vocabulary (per D8's rejection of multi-cloud-by-default).
- **D2** — Per-vendor posture table. Azure and GitHub are Accept (deep, intentional). Cloudflare, Stripe, Twilio, and Expo are Hedge (active). Anthropic, OpenAI, and Resend are Abstract (already portable). Posture is a per-surface concern, not a per-vendor concern — a vendor with multiple Grid surfaces may carry different postures per surface.
- **D3** — Cheap Grid-wide hedges already in place at the code level: provider abstractions held at every boundary (per invariants 1, 2, 3, 44); no vendor-proprietary features in application code; EF Core LINQ kept provider-agnostic (per ADR-0072); Bicep modules by concern (per ADR-0077 D2); OTel-first telemetry emit (per ADR-0040); per-vendor governance files at `governance/vendor-postures/{vendor}.md` for Accept-posture vendors.
- **D4** — Decision-point triggers (not kill clocks): deprecation/material price increase, sustained reliability problems (two or more incidents exceeding one hour of impact within a single calendar quarter), terms-change conflicts with charter, mature alternative emerges (after twelve-month maturation), adjacent Grid decision changes the math, vendor acquisition/corporate event. The trigger fires a **conversation**, not a migration. The conversation produces one of three outcomes: Stay / Hedge harder / Exit. Triggers are not promises.
- **D5** — Per-vendor exit-playbook stubs for Accept-posture vendors. Two stubs created with this ADR's acceptance: `governance/vendor-postures/azure.md` and `governance/vendor-postures/github.md`. Hedge and Abstract postures use the source ADR as document-of-record; no separate governance file required at acceptance.
- **D6** — Explicit non-commitments: this ADR does not commit to any exit, does not budget engineering time for portability work, does not require multi-cloud-by-default, and does not override the workshop framing.
- **D7** — Cross-reference to AI-sector invariants (28/29/44/45) as the **proof of concept** that the discipline works.
- **D8** — Out of scope: multi-cloud-by-default, per-vendor SLA negotiation, vendor-cost optimization (owned by ADR-0052), per-vendor security review (owned by ADR-0056), full content of the per-vendor governance files (D5 stubs only at acceptance; body deferred).

ADR-0080 is a **posture / governance** ADR. The concrete artifacts — the `governance/vendor-postures/azure.md` stub, the `governance/vendor-postures/github.md` stub, and the cross-link updates to ADR-0076/0077/0078's Follow-up Work and References sections — land in packets 01–03. Every other packet in this initiative references ADR-0080's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — add or update the ADR-0080 row in the index table. If a row already exists, update its Status column to Accepted. If no row exists, append one in the existing table format, citing the ADR's Sector (`Meta / Infrastructure / cross-cutting`), Date (`2026-05-23`), and a one-sentence impact summary.
- `constitution/invariants.md` — add the three new vendor-posture invariants (see Proposed Implementation for exact text), numbered **{N1}, {N2}, {N3}** per the reservation claimed in `constitution/invariant-reservations.md` (see Constraints for the numbering rationale).
- `constitution/invariant-reservations.md` — claim the next free block of size 3 above the highest existing reservation; add an `Active Reservations` row for ADR-0080 with the placeholder numbers.
- `initiatives/active-initiatives.md` — register the `adr-0080-vendor-lockin` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0080 header: `**Status:** Proposed` → `**Status:** Accepted`. While editing the ADR, amend the D2 per-vendor posture table's Microsoft Azure row to surface the per-surface posture mismatch the table currently flattens: the App Insights / Azure Monitor surface is **Accept with strong hedge** (the OTel-first emit per ADR-0040 reduces traces/metrics/logs backend swap to a configuration change — days, not weeks — with the error path as the carve-out described in D3's "OTel-first telemetry emit" bullet). The Azure row's `Posture` column may stay "Accept (deep, intentional)" as the vendor-level posture; add a parenthetical note that App Insights / Azure Monitor specifically carries "Accept with strong hedge" as its per-surface posture, consistent with `governance/vendor-postures/azure.md`'s per-surface table that packet 01 ships. This is the only D2 text change in this packet; no other D-decision is touched.
2. Update the ADR-0080 index row in `adrs/README.md`. The repo's `adrs/README.md` currently has rows through ADR-0057; ADR-0058–0080 are not yet in the table. **Either** (a) append a new row in the existing table format with `Status: Accepted` for ADR-0080 specifically (consistent with what `hive-sync` would do per ADR-0014's ADR-acceptance reconciliation), **or** (b) leave the index alone if the policy is that `hive-sync` is responsible for back-filling rows. Pick (a) — append the row directly — to keep the index consistent and avoid a `hive-sync` drift report flag. Match the existing row format (`| ADR-XXXX | Title | Status | Date | Sector | Impact |`).
3. **Claim the invariant-number block.** Open `constitution/invariant-reservations.md`. Read the `Active Reservations` table and find the highest reservation already claimed. Pick the next contiguous block of three numbers above that ceiling — these become `{N1}`, `{N2}`, `{N3}` for this packet. Add a row to the `Active Reservations` table with `Range | ADR-0080 | Proposed | <one-line description and (N1)–(N3) summary; packet 00 path>` matching the format of sibling rows. If two ADR packet-00s race to merge, the second one's author shifts upward by editing `invariant-reservations.md` plus every `{N1}/{N2}/{N3}` placeholder in this packet's body — that is the "first merge wins" mechanic the file documents.
4. Add three new invariants to `constitution/invariants.md`, numbered **{N1}, {N2}, {N3}** per step 3 (see Constraints). The text, taken verbatim-in-substance from ADR-0080's Consequences "Invariants" section:
   - **{N1} — Every vendor surface in the Grid carries one of the three postures from ADR-0080 D1: Accept (deep, intentional), Hedge (active), or Abstract (already portable).** Posture is documented in ADR-0080's per-vendor table (D2) or, for new vendors introduced after this ADR's acceptance, in the source ADR that adopts the vendor. The three-posture vocabulary is the only vendor-posture language the Grid uses; "multi-cloud," "vendor-neutral," "cloud-agnostic," and similar enterprise-shaped framings are explicitly not in the Grid's vocabulary. See ADR-0080 D1, D2.
   - **{N2} — No vendor-proprietary feature is consumed in application code.** Proprietary features (Azure Cache for Redis modules, Entra-proprietary claims, Stripe-specific webhook semantics, Cloudflare Workers, Twilio Studio flows, etc.) are allowed only at the `*.Providers.*` package layer; application code consumes Grid-defined interfaces and standard protocols (Redis-protocol-only per ADR-0076 D3, OIDC-standard claims only per ADR-0078 D3, OTel-first emit per ADR-0040, EF Core LINQ provider-agnostic per ADR-0072, normalized webhook intake per ADR-0062). This follows the same abstraction/runtime/provider shape that invariants 1, 2, 3 codify for internal Grid packaging, and that invariant 44 codifies for the AI sector; invariants 9 / 9a / 47 / 48 are the per-surface analogues already in place for Vault secrets and Audit append-by-interface. See ADR-0080 D3.
   - **{N3} — "Accept (deep, intentional)" posture vendors have a per-vendor governance file under `governance/vendor-postures/{vendor}.md`.** The file documents the lock-in honestly: every surface depended on, the exit cost per surface, the cheap hedges already in place, the canonical home for "vendor-exit playbook" references from source ADRs. Hedge and Abstract posture vendors use the source ADR as document-of-record; no separate governance file is required at acceptance, with the bar for promotion being "the source ADR's cited hedge is no longer the only relevant context." See ADR-0080 D5.
   - Create a new `## Vendor Posture Invariants` section. The file's existing sectioning convention groups invariants by topic (Dependency / Context / Secrets / Packaging / Testing / Infrastructure & Configuration / Work Tracking / AI / Code Review / Hosting Platform / Hive Sync / Multi-Tenant Boundary / Communications / Audit). Vendor posture is a new cross-cutting topic; place the new section after `## Audit Invariants` (or after the existing tail section, whichever is structurally last).
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. Match the format used by ADR-0042, ADR-0045, ADR-0077, and other sibling ADR-acceptance initiative entries.

## Affected Files
- `adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency — vendor posture is a governance concern; no contract cascade.

## Acceptance Criteria
- [ ] ADR-0080 header reads `**Status:** Accepted`
- [ ] An ADR-0080 row exists in `adrs/README.md` with Status `Accepted`, the correct Date (`2026-05-23`), Sector (`Meta / Infrastructure / cross-cutting`), and a one-sentence impact summary in the existing row format
- [ ] `constitution/invariant-reservations.md` carries an `Active Reservations` row claiming a contiguous block of size 3 for ADR-0080 above the highest existing reservation, with `(N1)`–`(N3)` summaries and the packet 00 path
- [ ] `constitution/invariants.md` carries the three new vendor-posture invariants (every vendor surface carries one of three postures; no vendor-proprietary feature in application code; Accept-posture vendors have a per-vendor governance file) numbered with the `{N1}/{N2}/{N3}` block claimed in `invariant-reservations.md`, under a new `## Vendor Posture Invariants` section, each citing ADR-0080
- [ ] Invariant `{N2}`'s text follows the same abstraction/runtime/provider shape that invariants 1, 2, 3 codify for internal Grid packaging and that invariant 44 codifies for the AI sector — the relationship is named, not implied; invariants 9 / 9a / 47 / 48 are referenced as the per-surface analogues already in place
- [ ] `initiatives/active-initiatives.md` registers the `adr-0080-vendor-lockin` initiative with a packet checklist matching the structure used by sibling initiative entries (ADR-0042, ADR-0045, ADR-0077)
- [ ] No catalog schema change in this packet (no `catalogs/contracts.json`, `catalogs/grid-health.json`, `catalogs/relationships.json`, or `catalogs/nodes.json` edit — see dispatch plan §"Why no catalog packet")
- [ ] No `governance/vendor-postures/` directory creation in this packet (that lands in packet 01)
- [ ] No edits to ADR-0076, ADR-0077, or ADR-0078 in this packet (cross-link footnotes land in packet 03)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0080 D1 — Three-posture vocabulary.** Accept (deep, intentional) / Hedge (active) / Abstract (already portable). This is the only vendor-posture vocabulary the Grid uses. Enterprise-shaped framings (multi-cloud, vendor-neutral, cloud-agnostic) are explicitly not in the Grid's vocabulary per D8's rejection of multi-cloud-by-default.

**ADR-0080 D2 — Per-vendor posture table.** Azure and GitHub are Accept (deep, intentional). Cloudflare, Stripe, Twilio, Expo are Hedge (active). Anthropic, OpenAI, Resend are Abstract (already portable). Posture is per-surface, not per-vendor — a vendor with multiple Grid surfaces may carry different postures per surface.

**ADR-0080 D3 — Cheap Grid-wide hedges.** Most are already true at the code level: provider abstractions at every boundary, no vendor-proprietary features in application code, EF Core LINQ provider-agnostic per ADR-0072, Bicep modules by concern per ADR-0077 D2, OTel-first telemetry per ADR-0040, per-vendor governance files under `governance/vendor-postures/{vendor}.md` for Accept vendors. This ADR adds the **posture** layer above the code-level discipline; no new code changes implied.

**ADR-0080 D5 — Per-vendor governance file structure.** `governance/vendor-postures/` is the canonical home for per-vendor posture documentation. Azure and GitHub stubs created at acceptance; full content deferred. Hedge and Abstract postures use the source ADR as document-of-record; no separate file required.

**ADR-0080 D7 — Cross-reference to AI-sector invariants.** Invariants 28, 29, 44, and 45 instantiated the discipline for the AI sector. This ADR generalizes them to every vendor surface — what those four did for Anthropic and OpenAI through `IModelRouter` and `HoneyDrunk.AI.Abstractions`, the rest of the Grid does for Azure, Cloudflare, Stripe, Resend, Twilio, and Expo through the abstractions and hedges in D3.

**ADR-0080 Consequences — Invariants.** ADR-0080 adds exactly three invariants: (1) every vendor surface carries one of three postures; (2) no vendor-proprietary feature is consumed in application code (same abstraction/runtime/provider shape that 1, 2, 3 codify for internal packaging and that 44 codifies for the AI sector); (3) Accept-posture vendors have a per-vendor governance file.

**Invariants 1, 2, 3, 44 (referenced by invariant {N2}).** Invariants 1, 2, 3 codify the abstraction/runtime/provider split for internal Grid packaging; invariant 44 codifies the same shape for the AI sector specifically. Invariant {N2} restates that shape at the vendor-surface boundary, and points at invariants 9 / 9a / 47 / 48 as the per-surface analogues already in place for Vault secrets and Audit append-by-interface. None of the upstream invariants are modified.

## Constraints
- **Acceptance precedes flip.** ADR-0080 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers `{N1}/{N2}/{N3}` — claim via the reservation registry.** Do not hardcode invariant numbers in this packet. Read `constitution/invariant-reservations.md`, pick the next contiguous block of three above the current ceiling, add the `Active Reservations` row in the same PR that writes this packet, and substitute the chosen numbers for the `{N1}/{N2}/{N3}` placeholders throughout this packet body and in the invariants section of `constitution/invariants.md`. "First merge wins" applies — if two ADR packet-00s race, the second author shifts upward by editing the registry plus every placeholder before pushing. Never reuse a number already claimed by another sibling reservation (today: ADR-0051 54–57; ADR-0049 58–60; ADR-0054 61–63; ADR-0060 64–66; ADR-0050 67–68; ADR-0063 69–73; ADR-0064 74–77; ADR-0065 78–79; ADR-0066 80–82; ADR-0068 83–86; ADR-0071 87–89; ADR-0077 90–92; ADR-0078 93–94; ADR-0079 95–98).
- **New section.** The three vendor-posture invariants are a new cross-cutting topic; create a `## Vendor Posture Invariants` section after the existing tail section (currently `## Audit Invariants`) rather than appending to an unrelated section.
- **Invariant `{N2}` names its upstream relationship explicitly but precisely.** The text must state that it follows the same abstraction/runtime/provider shape that invariants 1, 2, 3 codify for internal Grid packaging and that invariant 44 codifies for the AI sector, and name invariants 9 / 9a / 47 / 48 as the per-surface analogues already in place — not the looser "generalizes 1, 2, 3, 44 across all vendor surfaces" framing. Invariants 1/2/3 are intra-Grid packaging rules, not vendor-portability rules; the connection is structural shape, not scope expansion. The upstream invariants are not modified; `{N2}` is additive.
- **No catalog edits, no governance/ directory creation, no ADR-0076/0077/0078 edits in this packet.** Those land in subsequent packets per the dispatch plan. This packet is the governance/invariants flip only.
- **Match the existing `adrs/README.md` row format.** The repo's ADR index uses a six-column markdown table (`| ID | Title | Status | Date | Sector | Impact |`). Append the ADR-0080 row in that format. Do not invent a new column or alter the table header.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0080`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0080 to Accepted, add the three vendor-posture invariants to `constitution/invariants.md`, and register the vendor-lockin initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0080 so packets 01–03 can reference its decisions as live rules and start shipping the `governance/vendor-postures/` substrate.
- Feature: ADR-0080 Vendor Lock-In Posture rollout, Wave 1.
- ADRs: ADR-0080 (primary), invariants 1/2/3/44 (referenced by invariant 88), ADR-0008 (initiative/packet conventions), ADR-0014 (ADR-acceptance reconciliation pattern that `hive-sync` follows).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0080 stays Proposed until this PR merges.
- Claim the invariant-number block via `constitution/invariant-reservations.md` — read the registry, pick the next contiguous block of three above the current ceiling, add the row, substitute `{N1}/{N2}/{N3}` throughout the packet body and in `constitution/invariants.md`. Do not renumber existing invariants; create a new `## Vendor Posture Invariants` section.
- Invariant `{N2}` follows the same abstraction/runtime/provider shape that invariants 1, 2, 3 codify for internal Grid packaging and that invariant 44 codifies for the AI sector; cites 9 / 9a / 47 / 48 as the per-surface analogues already in place. Not the looser "generalizes 1, 2, 3, 44" framing.
- No catalog edits, no `governance/vendor-postures/` directory creation, no ADR-0076/0077/0078 edits in this packet.
- Match the existing `adrs/README.md` row format when appending the ADR-0080 row.

**Key Files:**
- `adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
