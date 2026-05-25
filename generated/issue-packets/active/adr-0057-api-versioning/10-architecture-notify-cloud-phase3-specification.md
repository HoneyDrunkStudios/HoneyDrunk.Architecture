---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0057", "adr-0027", "wave-4"]
dependencies: ["packet:00", "packet:02"]
adrs: ["ADR-0057", "ADR-0027"]
wave: 4
initiative: adr-0057-api-versioning
node: honeydrunk-architecture
---

# Author the Notify Cloud Phase 3 GA specification — deferred handoff to ADR-0027 standup

## Summary
Author the detailed specification document for the Notify Cloud Phase 3 GA-blocker work per ADR-0057 D17 Phase 3. This is the **deferral marker** — Notify Cloud does not exist on disk (ADR-0027 is Proposed; the repo will be created and scaffolded as part of the `adr-0027-notify-cloud-standup` initiative). This packet authors the specification *now* in the Architecture repo so when the ADR-0027 standup completes, the executor has a fully-spec'd implementation target for the public-API + SDK + docs work. The specification turns into one or more Notify Cloud packets (filed against the new repo) as a follow-up after the `adr-0027-notify-cloud-standup` initiative completes. This packet mirrors the pattern used by ADR-0067's packet 05 (the Notify Cloud rate-limit-policy specification).

## Context
ADR-0057 D17 Phase 3 names Notify Cloud's GA-blocker work: *"Notify Cloud's public API (per PDR-0002 / ADR-0027) ships with the full stack from day one: OpenAPI v1 spec, three SDKs published, docs site, RFC 7807 errors, cursor pagination, per-tenant rate limits, idempotency keys required on billing endpoints. Notify Cloud GA cannot ship without this Phase complete."*

But:
1. **ADR-0027 (Notify Cloud standup) is Proposed**, not Accepted. The `HoneyDrunk.Notify.Cloud` repo does not exist on disk; `catalogs/nodes.json` has no `honeydrunk-notify-cloud` entry; `file-packets.yml` cannot file an issue against a repo that does not exist.
2. **Per the user's standing convention**, new-Node scaffolding gets its own standup ADR — feature packets do not bundle scaffolding. The Notify Cloud public-API packet must therefore be filed *after* the `adr-0027-notify-cloud-standup` initiative's scaffold packet (per the ADR-0067 packet 05 precedent — packet 06 in that initiative).
3. **ADR-0057's exit criterion** for this initiative is Phase 1 substrate + Phase 2 Notify pilot complete. Phase 3 is satisfied across the ADR-0027 standup boundary, not within this initiative's filing window.

The clean structure: this packet authors the specification *now* (in the Architecture repo, where it is reviewable and discoverable). When the ADR-0027 standup completes — i.e., when Notify Cloud's scaffold packet lands on `main` and the Notify Cloud repo exists with its solution structure and a placeholder API surface — a follow-up packet against `HoneyDrunk.Notify.Cloud` consumes this specification and ships the full ADR-0057 + ADR-0067 + ADR-0042 stack as Phase 3 prescribes. The follow-up packet is **not** filed by this initiative.

This is a docs-only packet. No code, no .NET project, no catalog change.

## Scope
- New document at `infrastructure/walkthroughs/notify-cloud-public-api-specification.md` authoring the Notify Cloud Phase 3 public-API specification.
- Update `initiatives/active-initiatives.md` to record the cross-initiative coupling explicitly: this `adr-0057-api-versioning` initiative completes Phase 1 + Phase 2; Notify Cloud Phase 3 is a deferred follow-up tracked against the `adr-0027-notify-cloud-standup` initiative.

## Proposed Implementation
1. Author the specification document at `infrastructure/walkthroughs/notify-cloud-public-api-specification.md`. Required sections:

   ### OpenAPI v1 spec authoring (ADR-0057 D7)
   - Spec file location: `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud/api/openapi-v1.yaml`. OpenAPI 3.1 per ADR-0057.
   - Surface name: `notify-cloud` (distinct from `notify` per packet 08 — `notify-cloud` is the commercial product surface; `notify` is the internal-Grid intake/delivery substrate).
   - Endpoints (at minimum — refine at PR time against the ADR-0027 standup's emerged endpoint set):
     - `POST /v1/messages` — send a message (required `Idempotency-Key`; billing-relevant per ADR-0037 + ADR-0057 D13).
     - `GET /v1/messages/{id}` — message status lookup.
     - `GET /v1/messages` — list (cursor pagination per D14).
     - `GET /v1/recipients/{id}` / `POST /v1/recipients` / `PUT /v1/recipients/{id}` / `DELETE /v1/recipients/{id}` — recipient CRUD (`Idempotency-Key` on writes).
     - `GET /v1/recipients` — list (cursor pagination).
     - `GET /v1/templates/{id}` / `POST /v1/templates` / `PUT /v1/templates/{id}` / `DELETE /v1/templates/{id}` — template CRUD (`Idempotency-Key` on writes).
     - `GET /v1/templates` — list (cursor pagination).
     - `GET /v1/usage` — per-tenant quota / usage report (per ADR-0067 D8 / ADR-0037 D2).
   - Refine the endpoint list at PR time. The Notify Cloud product PDR-0002 may have added or removed endpoints by then.

   ### Error envelope (ADR-0057 D12)
   - RFC 7807 `application/problem+json` for every non-2xx response.
   - `type` URI host: `docs.honeydrunkstudios.com/errors/notify-cloud/{category}/`. Per-category URIs declared in `components.responses`.
   - `traceId` (W3C `traceparent` per ADR-0040) and `correlationId` (per ADR-0045 `ErrorContext`) on every error.
   - For the **billing-relevant rejection cases** (quota exceeded for Free; quota exceeded for Pro/Scale with overage billable), the error envelope shape matches ADR-0067 D6 (`tier`, `retry_after_seconds`, `correlation_id`; `tenant_id` NOT in body).

   ### Cursor pagination (ADR-0057 D14)
   - Every list endpoint uses cursor pagination.
   - `CursorPageRequest` / `CursorPageResult<T>` shapes inherited from `HoneyDrunk.Web.Rest.Abstractions` 0.6.0 (packet 07).
   - Cursor TTL minimum 24 hours; `410 Gone` per-D12 envelope on expired cursor.
   - Default `limit=50`, max `limit=200`.

   ### Rate limits + quotas (ADR-0057 D11 + ADR-0067 D3 / D8)
   - Per-tenant rate limits enforced via the ADR-0067 substrate. The production `ITenantRateLimitPolicy` implementation per ADR-0067 packet 05's specification (the analogous deferred spec in that initiative).
   - Per-tier limits at GA: Free / Pro / Scale per ADR-0067 D3.
   - IETF `RateLimit-*` headers on every response per ADR-0057 D11 / ADR-0067 D7.
   - 429 envelope per ADR-0067 D6 (RFC 7807, `tier` for authenticated, `retry_after_seconds`, `correlation_id`; `tenant_id` NOT in body).
   - `Retry-After` in seconds.
   - Quota counter store per ADR-0067 D8 (Azure Storage Tables at Phase 1).

   ### Idempotency (ADR-0057 D13 + ADR-0042)
   - `Idempotency-Key` **required** on every billing-relevant write — `POST /v1/messages` is the canonical example. Returns 400 problem+json on missing key with `type: https://docs.honeydrunkstudios.com/errors/common/idempotency-key-required`.
   - Other write endpoints: `Idempotency-Key` recommended (SDK auto-injects via packet 04's override templates).
   - Backed by `IIdempotencyStore` per ADR-0042; 24h dedup window per ADR-0042 D3.

   ### Authentication (ADR-0057 D10)
   - API key (`Authorization: Bearer {key}`) for the v1 surface. Per-tenant key rotation per ADR-0006.
   - OAuth 2.1 with PKCE deferred to the first end-user-facing Notify Cloud feature (tenant-portal pages; the current v1 surface is API-only and tenant-app integrations are API-key authenticated).
   - Per-endpoint `securitySchemes` declaration in the OpenAPI spec.

   ### SDK publication (ADR-0057 D8 + D9)
   - Three SDKs: `@honeydrunk/notify-cloud-sdk` (npm), `HoneyDrunkNotifyCloudSdk` (SPM), `com.honeydrunkstudios:notify-cloud-sdk` (Maven Central).
   - Tag scheme: `notify-cloud-api-v{N}.{spec-revision}.{sdk-patch}`.
   - SDKs published in **real-publish** mode from day one (Notify Cloud GA is a commercial product; tenants integrate against SDKs at launch). This assumes packet 11's namespace onboarding has completed by then.

   ### Documentation site (ADR-0057 D15)
   - Site at `docs.notify-cloud.honeydrunkstudios.com/v1/`.
   - Scalar reference at `/v1/api/`; Docusaurus narrative at `/v1/`.
   - Cloudflare Pages project `honeydrunk-docs-notify-cloud`. DNS + Pages provisioning follows the playbook in packet 02; a Studios-side packet provisions the subdomain (analogous to packet 09 for Notify).

   ### Per-API CI wiring
   - `HoneyDrunk.Notify.Cloud/.github/workflows/pr-openapi.yml` calls `job-openapi-diff.yml` (packet 03).
   - `HoneyDrunk.Notify.Cloud/.github/workflows/release-api.yml` calls `job-publish-public-sdk.yml` (packet 04) and `job-publish-docs.yml` (packet 05) on `notify-cloud-api-v*` tags.
   - Real-publish mode from day one (credentials seeded per packet 11 by then).

   ### Audit + Pulse (ADR-0030 / ADR-0010 + ADR-0067 D10)
   - Every state-changing call audits via `IAuditLog` (ADR-0030); event-shape per the Notify-Cloud-specific event catalog (to be authored alongside the implementation).
   - The `RateLimitRejected` + `QuotaOverageBilled` audit shapes from ADR-0067 packet 03 apply when the rate-limiter rejects or the billable-overage transition fires.
   - Pulse metric catalog (ADR-0067 packet 04) for rate-limit observability.

   ### Migration runway + deprecation
   - Migration-guide template inherited from packet 02 of this initiative.
   - Deprecation runbook (packet 02) governs any future deprecations.
   - Two-major coexistence per invariant `{N3}`.

   ### Cross-references and out-of-scope
   - This specification consumes the ADR-0057 Phase 1 substrate (packets 03-06 in this initiative) and the Phase 2 Notify pilot (packet 08).
   - Notify Cloud's **billing wiring** (Stripe meter increment per ADR-0037; overage events) is out of scope of this spec — that's an ADR-0037 follow-up consumed by the same Notify Cloud Phase 3 packet.
   - Notify Cloud's **tenant onboarding flow** (tenant creation, API key issuance, tier assignment) is out of scope — that's ADR-0050 (Multi-Tenant Lifecycle) + ADR-0027 standup work.

2. At the bottom of the specification document, add a **"Follow-up Notify Cloud packet" outline** — the executor-ready skeleton for the future filer to turn into a real packet:
   - Target repo: `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud` (does not exist at the time of writing this spec).
   - Blocked by: `adr-0027-notify-cloud-standup` scaffold packet (when ADR-0027's initiative is filed and its scaffold lands).
   - Version-bumping packet for the Notify Cloud solution.
   - Consumes: `HoneyDrunk.Web.Rest` 0.6.0 (cursor + RFC 7807 from packet 07); `HoneyDrunk.Kernel` (`IIdempotencyStore` per ADR-0042; `UseGridRateLimiting` per ADR-0067 packet 02); the production `ITenantRateLimitPolicy` from ADR-0067 packet 05's deferred spec.
   - Includes the per-API DNS / Pages provisioning Studios-side packet (analogous to packet 09 for Notify).
   - Includes the `catalogs/contracts.json` update on the new `honeydrunk-notify-cloud` Node entry with the populated `publicHttpApi` block.

3. Update `initiatives/active-initiatives.md` to record the cross-initiative coupling. Add a Tracking entry note under this initiative: "Notify Cloud Phase 3 public-API + SDKs + docs per ADR-0057 D17 Phase 3 is a deferred follow-up. It is filed as a new packet (or a small new initiative `adr-0057-notify-cloud-public-api`) against `HoneyDrunk.Notify.Cloud` after the `adr-0027-notify-cloud-standup` initiative's scaffold packet lands. The specification is at `infrastructure/walkthroughs/notify-cloud-public-api-specification.md`."

## Affected Files
- `infrastructure/walkthroughs/notify-cloud-public-api-specification.md` (new)
- `initiatives/active-initiatives.md` (cross-initiative coupling note)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] Notify Cloud production implementation is explicitly deferred to the `adr-0027-notify-cloud-standup` initiative — this packet does not file against `HoneyDrunk.Notify.Cloud` (the repo does not exist).
- [x] Mirrors the ADR-0067 packet 05 pattern (the analogous deferred spec for Notify Cloud's rate-limit policy).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/notify-cloud-public-api-specification.md` exists with the required sections: OpenAPI v1 spec authoring, error envelope, cursor pagination, rate limits + quotas, idempotency, authentication, SDK publication, documentation site, per-API CI wiring, audit + pulse, migration runway, cross-references / out-of-scope
- [ ] The "Follow-up Notify Cloud packet" outline is at the bottom with target repo, blocking dependency, version-bump expectation, consumed contracts, and Studios-side packet companion
- [ ] `initiatives/active-initiatives.md` records the cross-initiative coupling note linking this initiative's specification to the future Notify Cloud follow-up
- [ ] URL patterns in the specification match ADR-0057 D5 / D12 / D15 verbatim
- [ ] No code change
- [ ] No catalog change (the `honeydrunk-notify-cloud` entry lands when Notify Cloud is stood up)
- [ ] No invariant change

## Human Prerequisites
None. The specification document is authored at PR time; the future Notify Cloud follow-up packet is filed by the ADR-0027 standup executor or a follow-up operator action.

## Referenced ADR Decisions
**ADR-0057 D17 Phase 3 — Notify Cloud GA-blocker resolution.** "Notify Cloud's public API (per PDR-0002 / ADR-0027) ships with the full stack from day one: OpenAPI v1 spec, three SDKs published, docs site, RFC 7807 errors, cursor pagination, per-tenant rate limits, idempotency keys required on billing endpoints. Notify Cloud GA cannot ship without this Phase complete."

**ADR-0027 (referenced) — Notify Cloud standup.** Currently Proposed; the repo does not exist on disk. Phase 3 implementation lands after the standup completes.

**ADR-0067 (referenced) — Inbound rate limiting and quota enforcement.** Notify Cloud's production `ITenantRateLimitPolicy` implementation per ADR-0067 packet 05's deferred spec; tier-to-limits defaults per ADR-0067 D3; quota counter store per ADR-0067 D8.

**ADR-0042 (referenced) — Idempotency.** `IIdempotencyStore` substrate consumed by `POST /v1/messages` and other billing-relevant writes.

**ADR-0037 (referenced) — Payment and billing.** Stripe meter increment on quota-overage-billable events; out of scope of this spec but consumed by the same Notify Cloud Phase 3 packet.

**ADR-0030 (referenced) — Audit substrate.** Every state-changing call audits via `IAuditLog`.

**ADR-0050 (referenced — Proposed) — Multi-tenant lifecycle.** Tenant onboarding flow is out of scope of this spec; covered by ADR-0050 + ADR-0027 standup work.

**ADR-0057 D5 / D6 / D7 / D8 / D9 / D10 / D11 / D12 / D13 / D14 / D15 — All applied at Notify Cloud GA per Phase 3.**

## Constraints
- **Specification-only — no code.**
- **Notify Cloud production implementation deferred to ADR-0027 standup.** This packet is the handoff document.
- **Real-publish mode at GA.** Unlike packet 08 (Notify Phase 2, dry-run by default), Notify Cloud Phase 3 is commercial product — SDKs publish for real from the first tag. Packet 11 must complete before then.
- **No new invariants.** ADR-0057's invariants `{N1}-{N4}` already govern; no per-Node restatement.
- **Mirrors ADR-0067 packet 05 pattern** — same shape of deferred spec for the same Notify-Cloud-not-yet-stood-up reason.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0057`, `adr-0027`, `wave-4`

## Agent Handoff

**Objective:** Author the detailed Notify Cloud Phase 3 public-API specification at `infrastructure/walkthroughs/notify-cloud-public-api-specification.md` as the deferred handoff to the `adr-0027-notify-cloud-standup` initiative. The follow-up implementation packet against `HoneyDrunk.Notify.Cloud` is filed *after* that standup completes.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Have the Phase 3 spec ready and reviewable in the Architecture repo so the ADR-0027 standup executor (or a follow-up filer) can turn it into a real implementation packet without re-discovering the requirements.
- Feature: ADR-0057 rollout, Wave 4 (deferred handoff).
- ADRs: ADR-0057 D17 Phase 3 (primary); ADR-0027 (Notify Cloud — currently Proposed); ADR-0067 (rate-limit policy — consumed); ADR-0042 (idempotency); ADR-0037 (billing — out of scope here); ADR-0030 (audit).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0057 Accepted.
- `packet:02` — provisioning playbook authored (referenced by the spec's docs-site section).

**Constraints:**
- Specification-only, no code.
- Notify Cloud production implementation deferred.
- Real-publish mode at GA.
- No new invariants.
- Mirrors ADR-0067 packet 05 pattern.

**Key Files:**
- `infrastructure/walkthroughs/notify-cloud-public-api-specification.md` (new)
- `initiatives/active-initiatives.md` (cross-initiative coupling note)

**Contracts:** None changed.
