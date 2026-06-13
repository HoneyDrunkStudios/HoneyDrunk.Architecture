---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0057", "wave-1"]
dependencies: []
adrs: ["ADR-0057"]
accepts: ["ADR-0057"]
wave: 1
initiative: adr-0057-api-versioning
node: honeydrunk-architecture
---

# Accept ADR-0057 — flip status, reserve invariants {N1}-{N4}, register the initiative

## Summary
Flip ADR-0057 (Public HTTP API Versioning and Client SDK Strategy) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, reserve a four-invariant block (`{N1}`-`{N4}`) in `constitution/invariant-reservations.md`, write the four invariants verbatim into `constitution/invariants.md`, and register the `adr-0057-api-versioning` initiative in `initiatives/active-initiatives.md`. The four invariants are: every public REST API has a checked-in OpenAPI 3.1 spec at `repos/{node}/api/openapi-v{n}.yaml`; breaking changes (per D4 taxonomy) require a major version bump; at most two majors of a given surface are live concurrently; and HoneyHub uses GraphQL schema evolution rather than URL-prefix versioning.

## Context
ADR-0057 commits the Grid's substrate for public HTTP APIs: URL-path versioning with OpenAPI 3.1 as the source of truth (D7), a four-tier breaking-change taxonomy enforced by an `oasdiff` CI gate (D4 + D7), a 180-day deprecation lifecycle with tenant-notification cadence (D5), a hard two-major coexistence window (D6), three published SDK languages generated from the spec (D8), per-API key + OAuth 2.1 PKCE auth (D10), and HoneyHub as the narrow GraphQL-schema-evolution exception (D1 + D16). Three near-term forcing functions drive acceptance now: Notify Cloud GA is the first commercial API consumer (PDR-0002 / ADR-0027); the AI-sector standup wave (ADR-0016 through ADR-0025) needs the public-API substrate before each Node invents one; mobile consumer apps (PDRs 0003 / 0005 / 0006 / 0008) all have a real-world long client-version tail that the policy must accommodate.

The ADR carries two reconciliations already merged into the text:
- **D11 reconciled with ADR-0067 D5/D7** — the rate-limit envelope is the IETF unprefixed `RateLimit-*` form (`RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset`); per-tenant keying; no legacy `X-RateLimit-*` mirrors; `Retry-After` in seconds on 429. ADR-0067 remains the canonical source for the rate-limit envelope; ADR-0057 restates D11's commitments only so SDK consumers reading ADR-0057 in isolation see the same shape.
- **D15 reconciled with ADR-0075** — per-API docs sites are a two-part composition: Scalar renders the OpenAPI reference, Docusaurus carries the narrative content. Hosted at `docs.{api}.honeydrunkstudios.com`. The earlier draft picked Redocly; that choice was superseded.

This packet flips Status to Accepted at the *start* of the initiative because the ADR's decisions are needed as live rules by packets 01-11. The deeper success criterion ("Phase 1 substrate in place; Web.Rest v1 frozen; Notify v1 spec + SDKs published") is the initiative-completion gate recorded in `initiatives/active-initiatives.md`; that gate is satisfied across multiple wave boundaries. This split mirrors the pattern used by ADR-0067 (which has the same shape: flip at start, completion gate at end).

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0057 row Status column to Accepted.
- `constitution/invariant-reservations.md` — append the ADR-0057 reservation row: range `{N1}-{N4}`, status Proposed (the table tracks Proposed-while-in-flight, then moves to Reservation History at merge); claim text matches the four invariants below. The four-invariant block claims at `max(current ceiling, ADR-0080 reservation=101) + 1`, so the contiguous block per rule 5 is **102-105**.
- `constitution/invariants.md` — append four invariants verbatim:
  - **{N1}** — Every public HTTP REST API has a checked-in OpenAPI 3.1 specification at `repos/{node}/api/openapi-v{n}.yaml` as the source of truth. Missing or out-of-sync spec is a CI gate failure per the `job-openapi-diff.yml` workflow.
  - **{N2}** — Breaking changes (per the ADR-0057 D4 taxonomy) to a released public-API surface require a major version bump. Enforced by the OpenAPI-diff CI gate; the gate fails any PR whose diff against the last released spec is classified as breaking unless the spec under change is for a new (unreleased) major version.
  - **{N3}** — At most two major versions of a given public-API surface are live concurrently. A new major's release forces the older surviving major into the 180-day sunset clock; v(N-1) is sunsetted before v(N+1) ships.
  - **{N4}** — HoneyHub uses GraphQL schema evolution (additive types/fields + per-field `@deprecated(reason: "...; sunset YYYY-MM-DD.")`), not URL-prefix versioning. Enforced by the `graphql-inspector` CI gate (`job-graphql-inspector.yml`).
- `initiatives/active-initiatives.md` — register the `adr-0057-api-versioning` initiative with the Wave structure and packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0057 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0057 index row in `adrs/README.md` to Accepted.
3. Append to `constitution/invariant-reservations.md` — Active Reservations table — a new row for ADR-0057: range `102-105` (the contiguous block above ADR-0080's 99-101), status Proposed; Notes column carries the four invariant texts verbatim from §Scope above; packet 00 is the writer. **Rule 5 check at execution time:** if the reservations table has shifted since this packet was authored (e.g. a sibling ADR's reservation merged ahead and consumed a higher block), bump the claim upward to the new "next free" block, update every `{N1}/{N2}/{N3}/{N4}` placeholder in the packet bodies in this initiative folder, and state the shift in the PR.
4. Append to `constitution/invariants.md` — at the end, in invariant-number order — the four invariants with the resolved numbers from step 3. Match the file's existing entry shape (numbered heading, theme tag, body). Theme: `Public API Versioning` for {N1}-{N3}; `HoneyHub GraphQL Evolution` for {N4}.
5. Register the initiative in `initiatives/active-initiatives.md` under `## In Progress` with the Wave structure and packet checklist for this folder. Match the existing entry-shape used by sibling ADR initiatives (`adr-0067-rate-limiting`, `adr-0075-docs-tooling`): an `### ADR-0057 Public HTTP API Versioning and Client SDK Strategy` heading, Status / Scope / Initiative / Board / Description fields, and a Tracking checklist of all twelve packets in this folder. Use the file naming as the canonical packet references (the GitHub issue numbers will be backfilled by `hive-sync` after filing).
6. Record the **exit criterion** for the initiative in `initiatives/active-initiatives.md`: ADR-0057 Phase 1 substrate is complete (`job-openapi-diff.yml`, `job-publish-public-sdk.yml`, `job-publish-docs.yml`, `job-graphql-inspector.yml`, `job-publish-graphql-docs.yml` in Actions; `openapi-templates/{lang}/` in Actions); `HoneyDrunk.Web.Rest` `openapi-v1.yaml` checked in and frozen at v1; `HoneyDrunk.Notify` `openapi-v1.yaml` checked in with first SDKs published to npm/Maven/SPM and docs site live at `docs.notify.honeydrunkstudios.com/v1/`. **Notify Cloud Phase 3 is explicitly outside this initiative's exit criterion** — it is satisfied across the ADR-0027 standup boundary; the specification document (packet 10 of this initiative) is the handoff to a future follow-up packet against `HoneyDrunk.Notify.Cloud`.

## Affected Files
- `adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] Invariant reservation contiguous and ascending per `invariant-reservations.md` rule 5.

## Acceptance Criteria
- [ ] ADR-0057 header reads `**Status:** Accepted`
- [ ] The ADR-0057 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a new ADR-0057 row in Active Reservations with the four-invariant range (resolved to the next free contiguous block at execution time; expected `102-105` per current state)
- [ ] `constitution/invariants.md` has four new invariants appended in number order matching the resolved range, with the verbatim texts in §Scope
- [ ] `initiatives/active-initiatives.md` registers the `adr-0057-api-versioning` initiative with all twelve packets in the Tracking checklist and the explicit exit criterion (Phase 1 substrate complete; Web.Rest v1 frozen; Notify v1 spec/SDKs/docs live; Notify Cloud Phase 3 deferred)
- [ ] If invariant-reservations.md has shifted at execution time, the shift is recorded in the PR and every `{N1}/{N2}/{N3}/{N4}` placeholder in packets 01-11 is updated in the same PR
- [ ] No catalog schema change in this packet (catalog/tech-stack updates land in packet 01)

## Human Prerequisites
None. The four invariants land at acceptance per the registry rule "reservation is added in the same PR that introduces the ADR's packet set" — the placeholder convention `{N1}-{N4}` is resolved to concrete numbers in this packet, not deferred to a later packet. Packet 00's PR is the writer.

## Referenced ADR Decisions
**ADR-0057 §Consequences / Invariants — adds three plus one HoneyHub-scoped.** Verbatim:

> Adds three:
> - **Invariant: every public HTTP REST API has a checked-in OpenAPI 3.1 spec at `repos/{node}/api/openapi-v{n}.yaml` as the source of truth.** Missing or out-of-sync spec is a CI gate failure per the OpenAPI-diff workflow.
> - **Invariant: breaking changes (per D4 taxonomy) to a released public-API surface require a major version bump.** Enforced by the OpenAPI-diff CI gate (Phase 1).
> - **Invariant: at most two major versions of a given public-API surface are live concurrently** (per D6). New major release forces the older surviving major into the 180-day sunset clock.
>
> Plus one HoneyHub-scoped variant:
> - **Invariant: HoneyHub uses schema evolution (additive + `@deprecated`), not URL-prefix versioning.** Enforced by the `graphql-inspector` CI gate (Phase 4).

**ADR-0057 D17 — Phased rollout.** Six phases. Phase 1 (Weeks 1-3) — Foundations: author the OpenAPI spec template, the breaking-change CI gate, the reusable SDK-generation workflow, the docs-generation workflow; pilot on `HoneyDrunk.Web.Rest` v1. Phase 2 (Weeks 4-6) — Notify v1 spec, SDKs, docs (Phase 2 is the dry run for Notify Cloud GA). **Phase 3 (Weeks 6-10) is Notify Cloud GA blocker resolution and is explicitly deferred** in this initiative because the `HoneyDrunk.Notify.Cloud` repo does not exist on disk (ADR-0027 is Proposed). Phase 4 (Month 3+) — HoneyHub GraphQL schema commitment; deferred because HoneyHub does not exist on disk. Phase 5 — AI-sector standup wave inherits the Phase 1 substrate. Phase 6 — Future Billing API per ADR-0037.

**Initiative scope reconciliation.** This initiative ships Phase 1 (substrate in Actions + Architecture; pilot on Web.Rest) and Phase 2 (Notify v1 spec/SDKs/docs). Phase 3 (Notify Cloud GA implementation) and the live HoneyHub schema/docs (Phase 4 implementation) are deferred to follow-up initiatives that file against the Notify Cloud and HoneyHub repos *after* those repos exist. The Phase 4 *substrate* (the two GraphQL reusable workflows in Actions) ships in this initiative (packet 06) so the substrate is in place when HoneyHub stands up.

## Constraints
- **Acceptance precedes implementation.** ADR-0057 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers are resolved here, not deferred.** Packet 00's PR claims the block in `invariant-reservations.md` and writes the verbatim texts into `invariants.md`. Subsequent packets 01-11 reference the resolved numbers — placeholders `{N1}-{N4}` in those packets are search-and-replaced in the same PR if a collision forces a shift, per `invariant-reservations.md` rule 5.
- **Notify Cloud Phase 3 is deferred.** ADR-0027 (Notify Cloud standup) is Proposed; the `HoneyDrunk.Notify.Cloud` repo does not exist on disk; `file-work-items.yml` cannot file against it. This initiative ships the Phase 1 substrate and the Phase 2 Notify pilot; the Notify Cloud production OpenAPI spec + SDKs + docs land as part of (or after) the ADR-0027 standup — see the dispatch plan's Cross-Initiative Coupling section and packet 10 (the specification document).
- **HoneyHub Phase 4 implementation is deferred.** HoneyHub does not exist on disk. The two reusable workflows for GraphQL ship in this initiative (packet 06) because the substrate is buildable substrate. The actual `schema.graphql` commitment, the breaking-change gate enabling on the HoneyHub repo, and the docs site provisioning at `docs.honeyhub.honeydrunkstudios.com` land as part of (or after) the HoneyHub standup.
- **ADR-0034 namespace onboarding is operator-time-budgeted.** Maven Central namespace verification (`com.honeydrunkstudios`), GPG key generation/registration, npm `@honeydrunk` scope ownership, and Swift Package Index registration are all portal/manual steps performed by the operator. Packet 11 carries the checklist; that packet is `Actor=Human`. The Actions reusable workflows (packets 04, 05) consume the registered credentials once the operator completes the onboarding; tests against the workflows use a dry-run mode until the credentials exist.
- **No `Unreleased` CHANGELOG entries.** Per the user's standing convention, all repo-level CHANGELOG additions go into dated, versioned sections — never `[Unreleased]`.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0057`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0057 to Accepted, claim the four-invariant block in `invariant-reservations.md`, write the four invariants verbatim into `invariants.md`, and register the rollout initiative with its twelve-packet checklist.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0057 so the remaining packets in this initiative can reference its decisions as live rules and the resolved invariant numbers as live constitutional constraints.
- Feature: ADR-0057 Public HTTP API Versioning and Client SDK Strategy rollout, Wave 1.
- ADRs: ADR-0057 (primary); ADR-0067 (D11 reconciliation — rate-limit envelope); ADR-0075 (D15 reconciliation — Scalar + Docusaurus); ADR-0034 (NuGet/namespace onboarding — operator-time-budgeted, surfaced in packet 11); ADR-0027 (Notify Cloud — Phase 3 deferred); ADR-0042 (idempotency — `IIdempotencyStore` is the dedup substrate for D13); ADR-0040 / ADR-0045 (trace and error correlation for D12 envelope).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- ADR-0057 stays Proposed until this PR merges.
- Resolve `{N1}/{N2}/{N3}/{N4}` placeholders to concrete numbers here. Update packets 01-11 in the same PR if a collision forces a shift upward.
- Notify Cloud Phase 3 is **not** in this initiative's exit criterion — record it as a deferred follow-up handoff to a future ADR-0027-aligned initiative.
- HoneyHub Phase 4 implementation is also deferred. Only the substrate workflows (Actions packet 06) ship now.
- ADR-0034 namespace onboarding is operator-time-budgeted — packet 11 is `Actor=Human`.

**Key Files:**
- `adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
