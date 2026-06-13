---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0057", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0057"]
wave: 1
initiative: adr-0057-api-versioning
node: honeydrunk-architecture
---

# Record the public-API versioning substrate in tech-stack.md, contracts.json, and feature-flow-catalog.md

## Summary
Record ADR-0057's substrate, contract surface, and the deprecation-notification flow as catalog and reference data: append a Public HTTP API section to `infrastructure/reference/tech-stack.md` capturing the OpenAPI 3.1 + URL-path versioning + Scalar/Docusaurus + OpenAPI Generator + oasdiff + graphql-inspector choices and the rejected alternatives; introduce the `publicHttpApi` per-Node block in `catalogs/contracts.json` with empty/`null` entries for the affected Nodes (Web.Rest, Notify, HoneyHub when it exists, future Billing); and add the deprecation-notification flow to `constitution/feature-flow-catalog.md` so the named flow is canonical before any Node fires it.

## Context
ADR-0057 D7 commits OpenAPI 3.1 as the source of truth at `repos/{node}/api/openapi-v{n}.yaml`. ADR-0057 D2 commits URL-path versioning (`/v1/notify/send`). ADR-0057 D15 (reconciled with ADR-0075) commits Scalar for the OpenAPI reference and Docusaurus for narrative content. ADR-0057 D8 commits OpenAPI Generator with Studios-maintained override templates in `HoneyDrunk.Actions/openapi-templates/{language}/`. ADR-0057 D7 commits `oasdiff` (or equivalent) as the breaking-change diff tool. ADR-0057 D16 + D17 commit `graphql-inspector` (or equivalent) for HoneyHub schema-evolution gating. The `infrastructure/reference/tech-stack.md` document is the Grid's single source of truth for cross-cutting platform choices — recording these here means future ADRs and reviewers see "public HTTP API substrate = OpenAPI 3.1 + URL-path versioning + Scalar + Docusaurus + OpenAPI Generator + oasdiff + graphql-inspector" without having to read ADR-0057 to discover it.

ADR-0057 also extends `catalogs/contracts.json` per §Consequences/Affected Nodes: *"`catalogs/contracts.json` gains `publicHttpApi` entries per Node listing the surface name, current major version, OpenAPI spec path, and published SDK coordinates."* This packet introduces the schema for that new block on the affected Nodes — Web.Rest gets a populated v1 entry once its OpenAPI spec lands (packet 07); Notify gets one once its spec lands (packet 08); Notify Cloud, HoneyHub, and future Billing have `null` placeholders that fill in when those Nodes catch up.

ADR-0057 D5 + §Consequences/Affected Nodes name the deprecation-notification flow (T-90 / T-30 / T-7 emails routed through Communications + Notify to active tenants at the moment of deprecation announcement). The flow is added to `constitution/feature-flow-catalog.md` so it is named and discoverable before any Node fires it.

The Notify Cloud production OpenAPI spec is **not** registered here — Notify Cloud is not yet stood up (ADR-0027 is Proposed) and its catalog entry does not exist. When the ADR-0027 standup initiative completes, Notify Cloud's catalog row is created and its `publicHttpApi` block is populated. HoneyHub's `publicHttpApi` block is similarly deferred — HoneyHub does not exist on disk; this packet only documents the convention so the future HoneyHub standup writes to it.

This is a docs/catalog packet. No code, no .NET project.

## Scope
- `infrastructure/reference/tech-stack.md` — append a new section recording the public-HTTP-API substrate: OpenAPI 3.1 spec format + URL-path versioning + Scalar for reference docs + Docusaurus for narrative + OpenAPI Generator (`@openapitools/openapi-generator-cli`) for SDK generation + `oasdiff` for breaking-change diffs + `graphql-inspector` for GraphQL schema diffs + RFC 7807 problem details for errors + RFC 8594 (`Deprecation` / `Sunset` / `Link rel="successor-version"`) for deprecation signaling + the cursor-based pagination convention. Cross-link to ADR-0057, ADR-0067 (rate-limit envelope reconciled), ADR-0075 (docs tooling reconciled), ADR-0042 (idempotency for D13), ADR-0040 (App Insights for `traceId` in D12), ADR-0045 (`IErrorReporter` `correlationId` for D12).
- `catalogs/contracts.json` — introduce the `publicHttpApi` block convention on the Node entries that have or will have a public HTTP surface (Web.Rest, Notify, future Notify Cloud, future HoneyHub, future Billing). Shape: `publicHttpApi: { surfaceName, currentMajor, openApiSpecPath?, graphqlSchemaPath?, sdkCoordinates: { typescript?, swift?, kotlin? }, docsUrl? }`. **Populate only the Web.Rest and Notify entries** with `surfaceName` and `currentMajor = "v1"` (left empty for `openApiSpecPath` and `sdkCoordinates` until packets 07 / 08 land); the other Node entries either get `publicHttpApi: null` placeholders or omit the block entirely per the JSON file's convention for absent-but-known fields (match existing convention; default to omitting until populated to keep diffs clean).
- `constitution/feature-flow-catalog.md` — add the named flow `deprecation-notification` with: trigger (a public-API endpoint or major version enters its deprecation window per ADR-0057 D5); decision/orchestration owner (`HoneyDrunk.Communications` per ADR-0019); intake/delivery owner (`HoneyDrunk.Notify`); audit owner (`HoneyDrunk.Audit` per ADR-0030); cadence (T-90, T-30, T-7 emails); inputs (the deprecated endpoint / major-version identifier; the set of tenants whose API keys touched the endpoint in the past 30 days at announcement); outputs (audited tenant-notification events; the Sunset header on every response from the deprecated endpoint per RFC 8594).

## Proposed Implementation
1. **`infrastructure/reference/tech-stack.md`** — open the file and locate the appropriate section (look for an existing "Cross-cutting" / "Platform Services" / "Hosting" grouping; if none fits exactly, append a new `## Public HTTP APIs` section in the order the rest of the doc uses). Match the document's existing entry shape — at minimum:
   - **Spec format:** OpenAPI 3.1 (JSON Schema-aligned). Spec lives at `repos/{node}/api/openapi-v{n}.yaml`. GraphQL surfaces (HoneyHub only per ADR-0057 D1 + D16) carry `repos/{node}/api/schema.graphql` instead.
   - **Versioning scheme:** URL-path prefix (`/v1/notify/send` → `/v2/notify/send`). Major version per API surface, not per endpoint. At most two majors live concurrently. GraphQL surfaces use schema evolution (additive + per-field `@deprecated`) — no URL-prefix.
   - **Reference docs renderer:** Scalar (reconciled with ADR-0075 D1 — same renderer used in-product via `Scalar.AspNetCore`).
   - **Narrative docs framework:** Docusaurus (per ADR-0075 D2).
   - **SDK generator:** OpenAPI Generator (`@openapitools/openapi-generator-cli`). Languages at v1: TypeScript (`@honeydrunk/{api}-sdk` on npm), Swift (`HoneyDrunk{Api}Sdk` SPM), Kotlin (`com.honeydrunkstudios:{api}-sdk` on Maven Central). C# / Python / Go / Ruby / PHP deferred per D8.
   - **Breaking-change diff:** `oasdiff` (or equivalent) per D7 — gates every PR that modifies an `openapi-v*.yaml`. **Tool selection note:** packet 03 of this initiative pins the concrete `oasdiff` version + invocation in `HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml`; tech-stack here records the choice at the convention level.
   - **GraphQL schema diff:** `graphql-inspector` (or equivalent) per D16 + D17 Phase 4 — gates every PR that modifies a `schema.graphql`. Same selection note applies; packet 06 pins the version in the GraphQL workflows.
   - **Error envelope:** RFC 7807 `application/problem+json` per D12. `type` URI host: `docs.honeydrunkstudios.com/errors/` (reconciled with ADR-0067 D6 — the same docs host is canonical for both Studios-wide error types and per-API error types). Fields: `type`, `title`, `status`, `detail`, `instance`, `traceId` (W3C `traceparent`), `correlationId` (per ADR-0045 `ErrorContext`).
   - **Deprecation signaling:** RFC 8594 `Deprecation` + `Sunset` headers + `Link rel="successor-version"`; 180-day minimum lifecycle; T-90 / T-30 / T-7 tenant emails via the `deprecation-notification` named flow (Communications + Notify).
   - **Pagination:** cursor-based default per D14 (`?cursor=&limit=`; `{ items, next_cursor }` body; `Link rel="next"` header). Default `limit=50`, max `limit=200`. Cursors opaque base64; server-side cursor TTL 24h minimum; `410 Gone` per-D12 problem-details on expired cursor.
   - **Idempotency on writes:** `Idempotency-Key` header per ADR-0042; required for billing endpoints, recommended otherwise; SDKs auto-generate UUID v7 per write per D13.
   - **Authentication:** API key (`Authorization: Bearer {key}`) for machine-to-machine; OAuth 2.1 with PKCE for user-facing apps per D10.
   - **Rejected alternatives:** header versioning, media-type versioning, query-param versioning, date-based (Stripe-style), no-versioning-just-deprecate-forever, GraphQL-everywhere, gRPC, multi-scheme ASP.NET versioning library defaults, per-endpoint versioning, three-or-more concurrent majors (per D6), hand-written SDKs as v1 default, defer-SDK-publication, OpenAPI 3.0 (not 3.1), per-Node tooling choices — each with the one-line rejection reason from the ADR.
   - **Cross-links:** ADR-0057 (primary), ADR-0067 (D11 reconciliation), ADR-0075 (D15 reconciliation), ADR-0042 (D13 idempotency), ADR-0040 (D12 traceId), ADR-0045 (D12 correlationId), ADR-0034 (NuGet/namespace onboarding), ADR-0027 (Notify Cloud Phase 3 deferred), ADR-0003 (HoneyHub GraphQL carve-out).

2. **`catalogs/contracts.json`** — locate the existing Node entries and decide on populated vs. omitted shape. The shape for a populated `publicHttpApi` block:
   ```json
   "publicHttpApi": {
     "surfaceName": "Notify",
     "currentMajor": "v1",
     "openApiSpecPath": "repos/HoneyDrunk.Notify/api/openapi-v1.yaml",
     "graphqlSchemaPath": null,
     "sdkCoordinates": {
       "typescript": "@honeydrunk/notify-sdk",
       "swift": "HoneyDrunkNotifySdk",
       "kotlin": "com.honeydrunkstudios:notify-sdk"
     },
     "docsUrl": "https://docs.notify.honeydrunkstudios.com/v1/"
   }
   ```
   For `honeydrunk-web-rest` and `honeydrunk-notify`, **add the block with `surfaceName` and `currentMajor = "v1"` populated**; leave `openApiSpecPath`, `sdkCoordinates`, and `docsUrl` either `null` or omitted (match the file's convention for known-but-empty fields). Packet 07 populates Web.Rest's `openApiSpecPath` when the reverse-engineered spec lands; packets 08 + 09 populate Notify's `openApiSpecPath`, `sdkCoordinates`, and `docsUrl` when those land. For HoneyHub and future Billing — their Node rows do not yet exist; this packet does not pre-create them. The Notify Cloud row, when it lands in the ADR-0027 standup, will include its `publicHttpApi` block populated with `surfaceName = "Notify Cloud"`, GraphQL/REST split per the standup, and the SDK coordinates pulled from the Notify Cloud sub-SDK convention.
   - Match the JSON formatting (indent, trailing-comma convention, key order) used by the existing entries — do not reformat the file.
   - If the existing `contracts.json` does not use a `publicHttpApi` key on any Node today (it doesn't — this block is being introduced), this packet's PR is the *first* introduction; the executor adds the field consistently across the two Node entries that get populated and notes the new schema field in the file's top-level schema descriptor (if any exists; most catalog JSON files do not carry schemas, in which case the field shape is implicit).

3. **`constitution/feature-flow-catalog.md`** — locate the existing flow entries and append a new entry matching the file's shape:
   - **Flow name:** `deprecation-notification`
   - **Trigger:** A public-API endpoint OR an entire major version of a public-API surface enters its deprecation window per ADR-0057 D5 (the moment of deprecation announcement; the `Deprecation` + `Sunset` headers begin emitting; the 180-day clock starts).
   - **Decision/orchestration:** `HoneyDrunk.Communications` (per ADR-0019 — decision/orchestration vs intake/delivery split). Communications resolves the set of tenants to notify (every tenant whose API key touched the deprecated endpoint within the most recent 30 days at the moment of announcement), schedules the T-90, T-30, T-7 sends, and renders the per-tenant migration content (endpoint identifier, sunset date, migration guide URL, per-tenant traffic statistics at T-7).
   - **Intake/delivery:** `HoneyDrunk.Notify` — receives the per-tenant send request from Communications and dispatches via the tenant's preferred channel (email-default).
   - **Audit:** `HoneyDrunk.Audit` (per ADR-0030) — every announcement, every per-tenant send (T-90 / T-30 / T-7), and every post-sunset rejected request from the deprecated endpoint are durably recorded. Sunset compliance is reviewable after the fact via the audit substrate.
   - **Inputs:** the deprecated endpoint or major-version identifier; the active-tenant set (resolved from API-key access logs over the prior 30 days; Notify Cloud will own that resolution for its own surface; for Web.Rest's v1 freeze the active-tenant set is empty because no commercial Web.Rest tenants exist yet — the first time the flow fires in earnest is Notify Cloud GA).
   - **Outputs:** three audited tenant-notification events per tenant; `Deprecation` + `Sunset` + `Link rel="successor-version"` headers on every response from the deprecated endpoint until sunset; post-sunset rejected requests carry an RFC 7807 problem-details envelope citing `type: https://docs.honeydrunkstudios.com/errors/common/endpoint-sunsetted` (the docs page is a deferred Studios-website follow-up).
   - **Cross-references:** ADR-0057 D5 (deprecation policy), ADR-0019 (Communications-Notify split), ADR-0030 (Audit substrate), ADR-0034 (SDK publication — migration-guide URL pattern), RFC 8594 (Sunset/Deprecation headers).

4. Do **NOT** edit `catalogs/relationships.json`. The Communications → Notify edge is already in the catalog (per ADR-0019 / ADR-0013 acceptance); no new Node-to-Node edge is created by this packet.

5. Do **NOT** edit `catalogs/nodes.json`. nodes.json has no `interfaces` / `publicHttpApi` field — contract surface lives in contracts.json.

## Affected Files
- `infrastructure/reference/tech-stack.md`
- `catalogs/contracts.json`
- `constitution/feature-flow-catalog.md`

## NuGet Dependencies
None. This packet touches only Markdown and catalog JSON; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new Node-to-Node edge — Communications → Notify is already established.
- [x] `publicHttpApi` block is a new top-level field on the affected Node entries; no existing fields are removed or renamed.
- [x] JSON formatting matches surrounding entries.

## Acceptance Criteria
- [ ] `infrastructure/reference/tech-stack.md` carries a `## Public HTTP APIs` section with: OpenAPI 3.1 spec format, URL-path versioning, Scalar + Docusaurus docs composition, OpenAPI Generator for SDKs (TypeScript / Swift / Kotlin), `oasdiff` for breaking-change diff, `graphql-inspector` for GraphQL diff, RFC 7807 errors with `type` URI host at `docs.honeydrunkstudios.com/errors/`, RFC 8594 deprecation signaling, cursor pagination defaults (limit 50, max 200), `Idempotency-Key` per ADR-0042, API-key / OAuth 2.1 PKCE auth — and the full rejected-alternatives list with one-line reasons
- [ ] `catalogs/contracts.json` introduces the `publicHttpApi` block convention; the `honeydrunk-web-rest` and `honeydrunk-notify` entries each carry a `publicHttpApi` block with `surfaceName` and `currentMajor = "v1"` populated; the spec path / SDK coordinates / docs URL are left empty until packets 07 / 08 / 09 land
- [ ] `catalogs/contracts.json` JSON formatting matches the rest of the file (indentation, trailing-comma convention, key ordering)
- [ ] `constitution/feature-flow-catalog.md` lists the `deprecation-notification` named flow with trigger, decision/orchestration owner, intake/delivery owner, audit owner, cadence (T-90 / T-30 / T-7), inputs, outputs, and cross-references
- [ ] `catalogs/relationships.json` is NOT modified
- [ ] `catalogs/nodes.json` is NOT modified
- [ ] No invariant edit in this packet (invariants {N1}-{N4} land via packet 00)
- [ ] No new abstractions registered — the substrate is configuration + tooling, not a contract surface

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0057 D7 — OpenAPI 3.1 as the source of truth.** Every public REST API carries a checked-in OpenAPI 3.1 spec at `repos/{node}/api/openapi-v{n}.yaml`. The spec is load-bearing: SDK generation (D8), docs (D15), contract tests (cross-ref ADR-0047 D4), and the breaking-change CI gate (D7) all consume the same spec.

**ADR-0057 D2 — URL path prefix versioning.** `/v1/notify/send`. Major-version-in-URL is the operationally-legible choice; header / media-type / query-param / date-based all rejected with reasons.

**ADR-0057 D15 (reconciled with ADR-0075 — 2026-05-24) — Docs composition.** Scalar for the OpenAPI reference (same renderer ADR-0075 D1 uses in-product); Docusaurus for narrative (ADR-0075 D2). Hosted at `docs.{api}.honeydrunkstudios.com`; per-major version path prefixes (`/v1/api/`, `/v2/api/`); root redirects to current default major.

**ADR-0057 D8 — Three SDK languages at v1.** TypeScript (`@honeydrunk/{api}-sdk` on npm), Swift (`HoneyDrunk{Api}Sdk` SPM), Kotlin (`com.honeydrunkstudios:{api}-sdk` on Maven Central). C# / Python / Go / Ruby / PHP deferred. Tooling: OpenAPI Generator with Studios-maintained templates in `HoneyDrunk.Actions/openapi-templates/{language}/`.

**ADR-0057 D11 (reconciled with ADR-0067 D5/D7 — 2026-05-24) — Rate-limit envelope.** Unprefixed IETF `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`; `Retry-After` in seconds on 429; per-tenant keying. ADR-0067 is the canonical source.

**ADR-0057 D12 — RFC 7807 error envelope.** `application/problem+json` with `type` (URL at `docs.honeydrunkstudios.com/errors/{api}/...`), `title`, `status`, `detail`, `instance`, `traceId` (W3C `traceparent`; App Insights operation_id per ADR-0040), `correlationId` (per ADR-0045 `ErrorContext`). The trace/correlation linkage is load-bearing for tenant-driven incident triage.

**ADR-0057 D5 — Deprecation policy.** RFC 8594 `Deprecation` + `Sunset` + `Link rel="successor-version"`. 180-day minimum lifecycle. T-90, T-30, T-7 emails through Communications + Notify per ADR-0019.

**ADR-0057 §Consequences / Affected Nodes — Architecture additions.** `catalogs/contracts.json` gains `publicHttpApi` entries per Node listing surface name, current major, spec path, SDK coordinates. `constitution/feature-flow-catalog.md` gains the deprecation-notification flow.

## Constraints
- **No new abstractions in this packet.** The substrate is configuration + tooling, not a contract surface. The `publicHttpApi` block is descriptive metadata, not a new interface.
- **`catalogs/relationships.json` is NOT touched.** Communications → Notify already exists from ADR-0019. No new edge is created.
- **`catalogs/nodes.json` is NOT touched.** nodes.json has no `publicHttpApi` field.
- **Match JSON formatting precisely.** The repo's `pr-core.yml` includes a JSON-formatting gate.
- **HoneyHub / Notify Cloud / future Billing Node rows are not pre-created.** Those Node entries land via their respective standup initiatives.
- **`type` URI host pinned to `docs.honeydrunkstudios.com/errors/`.** Reconciled with ADR-0067 D6 — the same docs host is canonical for both Studios-wide error types and per-API error types.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0057`, `wave-1`

## Agent Handoff

**Objective:** Record the ADR-0057 substrate (OpenAPI 3.1 + URL-path + Scalar + Docusaurus + OpenAPI Generator + oasdiff + graphql-inspector + RFC 7807 + RFC 8594 + cursor pagination + auth schemes) in `infrastructure/reference/tech-stack.md`, introduce the `publicHttpApi` block convention in `catalogs/contracts.json` populated for Web.Rest and Notify, and add the `deprecation-notification` named flow to `constitution/feature-flow-catalog.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the Grid's substrate documentation, contract catalog, and named-flow catalog accurate so implementation packets (03-08) read a correct graph.
- Feature: ADR-0057 Public HTTP API Versioning and Client SDK Strategy rollout, Wave 1.
- ADRs: ADR-0057 (primary); ADR-0067 (D11 reconciliation); ADR-0075 (D15 reconciliation); ADR-0042 (D13 idempotency); ADR-0040 (D12 traceId); ADR-0045 (D12 correlationId); ADR-0019 (Communications-Notify orchestration split).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0057 should be Accepted (and the four invariants live) before its substrate is recorded as catalog data.

**Constraints:**
- No new abstractions registered. `publicHttpApi` is descriptive metadata on existing Node entries.
- `relationships.json` and `nodes.json` are NOT touched.
- Match JSON formatting precisely.

**Key Files:**
- `infrastructure/reference/tech-stack.md` — new Public HTTP APIs section.
- `catalogs/contracts.json` — `publicHttpApi` blocks on `honeydrunk-web-rest` and `honeydrunk-notify`.
- `constitution/feature-flow-catalog.md` — new `deprecation-notification` flow entry.

**Contracts:** None changed. This packet records catalog metadata only.
