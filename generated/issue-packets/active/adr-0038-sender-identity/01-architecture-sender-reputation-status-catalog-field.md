---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0038", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0038"]
accepts: ["ADR-0038"]
wave: 1
initiative: adr-0038-sender-identity
node: honeydrunk-architecture
---

# Add the sender_reputation_status field to grid-health.json and seed sending-identity entries

## Summary
Add a `sender_reputation_status` field to `catalogs/grid-health.json` per ADR-0038 D7, tracking the warmup/reputation state of each sending identity (`mail.`, `notify.`, the Studio toll-free SMS number). Seed each identity with an initial `not-provisioned` state so the catalog has the entries before the DNS and ESP work lands.

## Context
ADR-0038 D7 specifies: "Warmup status is tracked in `catalogs/grid-health.json` (new field, `sender_reputation_status`)." The field gives the Grid a machine-readable record of where each sending identity sits on the warmup ladder — pre-provisioning, in-warmup, or steady-state — which the `hive-sync` drift-detection extension (packet 10) reconciles, and which the future Notify Cloud onboarding flow reads to gate tenant throughput tiers off warmup state.

Sending identities are **not Nodes** — they are vendor/DNS-resident sending surfaces. They do not appear in `catalogs/nodes.json` or `relationships.json`. `grid-health.json` is the correct home: it already aggregates operational state and (per ADR-0036) carries the `dr_tier` field, which is the same kind of cross-cutting operational metadata.

This packet adds the field and seeds it. It does not provision anything — the DNS records (packet 03), ESP account (packet 09), and reporting inbox (packet 04) are separate human-executed packets that flip the field's values as they complete.

This is a docs/catalog-only packet. No code, no .NET project.

## Scope
- `catalogs/grid-health.json` — add the `sender_reputation_status` structure and seed the three v1 sending identities.

## Proposed Implementation
1. Add a top-level `sender_reputation_status` array (or object keyed by identity) to `catalogs/grid-health.json`. Match the file's existing structural conventions (inspect how `dr_tier` and other fields are structured before choosing array vs object).
2. Each entry records, at minimum:
   - `identity` — the sending identity name (`mail.honeydrunkstudios.com`, `notify.honeydrunkstudios.com`, `studio-toll-free-sms`).
   - `channel` — `email` or `sms`.
   - `status` — one of: `not-provisioned`, `dns-published`, `warmup`, `steady-state`. (Define this enumeration in the schema comment / a sibling schema note.)
   - `dmarc_policy` — for email identities only: `none` | `quarantine` | `reject` | `n/a`.
   - `spf_qualifier` — for email identities only: `~all` | `-all` | `n/a` (tracks the D2 warmup→strict SPF transition).
   - `notes` — free-text, e.g. "warmup ramp started YYYY-MM-DD".
3. Seed all three v1 identities at `status: not-provisioned`, `dmarc_policy: n/a` / `none` as appropriate, with a note "awaiting ADR-0038 packet 03/09".
4. If `grid-health.json` has an accompanying schema doc or a `meta`/`total_*` summary block, update it to acknowledge the new field. Do not break the existing `total_nodes` / `blocked_nodes` summary structure.

## Affected Files
- `catalogs/grid-health.json`
- Any sibling schema/README doc for `grid-health.json`, if one exists.

## NuGet Dependencies
None. This packet touches only catalog JSON; no .NET project is created or modified.

## Boundary Check
- [x] `catalogs/grid-health.json` lives in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Sending identities are vendor/DNS surfaces, not Nodes — no `nodes.json` / `relationships.json` / `contracts.json` change.

## Acceptance Criteria
- [ ] `catalogs/grid-health.json` carries a `sender_reputation_status` field
- [ ] The field has entries for all three v1 sending identities (`mail.`, `notify.`, the Studio toll-free SMS number), each seeded at `status: not-provisioned`
- [ ] Each email entry tracks `dmarc_policy` and `spf_qualifier` so the D2 staged-strict transition is observable
- [ ] The `status` enumeration (`not-provisioned` | `dns-published` | `warmup` | `steady-state`) is documented in a schema comment or sibling note
- [ ] The existing `grid-health.json` structure (node list, summary block) is unmodified and still valid JSON
- [ ] No `nodes.json`, `relationships.json`, or `contracts.json` change

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0038 D7 — Warmup posture.** `notify.honeydrunkstudios.com` and the toll-free SMS number begin sending under an explicit warmup ramp. Email warmup starts at ≤50 messages/day to engaged recipients, doubling daily until target volume or a complaint threshold (0.1% steady-state, 0.3% warmup ceiling). SMS warmup is bounded by the 10DLC throughput tier. The Studio `mail.` subdomain inherits reputation from the ESP-managed shared pool — not a from-zero warmup. "Warmup status is tracked in `catalogs/grid-health.json` (new field, `sender_reputation_status`)."

**ADR-0038 D2 — Email authentication.** SPF qualifier transitions `~all` → `-all` after ≥30 days of clean sending; DMARC transitions `p=none` → `p=quarantine` → `p=reject`. The catalog field's `spf_qualifier` and `dmarc_policy` keys make this staged transition observable.

## Constraints
- **Sending identities are not Nodes.** Do not add them to `nodes.json` or `relationships.json`. They are vendor/DNS surfaces; `grid-health.json` is the only catalog touched.
- **Seed only — do not invent a provisioned state.** All three identities start at `not-provisioned`. The values change when packets 03/04/09 complete; this packet establishes the entries, not their final state.
- **Preserve valid JSON.** `grid-health.json` is consumed by `hive-sync`; a malformed file breaks the aggregator.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0038`, `wave-1`

## Agent Handoff

**Objective:** Add the `sender_reputation_status` field to `grid-health.json` and seed the three v1 sending identities at `not-provisioned`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the Grid a machine-readable record of sending-identity warmup state, ready for the `hive-sync` reconciliation in packet 10 and the Notify Cloud onboarding flow.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 1.
- ADRs: ADR-0038 D7 (primary), D2 (the SPF/DMARC staged transition the field tracks).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0038 should be Accepted before its D7 catalog obligation is executed.

**Constraints:**
- Sending identities are not Nodes — only `grid-health.json` is touched.
- Seed at `not-provisioned`; do not fabricate a provisioned state.
- Keep the file valid JSON — `hive-sync` consumes it.

**Key Files:**
- `catalogs/grid-health.json`

**Contracts:** None changed — catalog metadata only.
