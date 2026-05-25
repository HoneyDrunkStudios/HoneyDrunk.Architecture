---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "core", "adr-0057", "wave-4"]
dependencies: ["packet:00", "packet:01", "packet:03", "packet:04", "packet:05", "packet:07"]
adrs: ["ADR-0057"]
wave: 4
initiative: adr-0057-api-versioning
node: honeydrunk-notify
---

# Author openapi-v1.yaml for HoneyDrunk.Notify and pilot the SDK + docs publication (Phase 2)

## Summary
The Phase 2 pilot per ADR-0057 D17 — the dry run for Notify Cloud GA. `HoneyDrunk.Notify` exposes a small set of internal-Grid HTTP endpoints today (intake / send / status / templates per the existing Notify endpoints); this packet authors `HoneyDrunk.Notify/api/openapi-v1.yaml` capturing those endpoints in OpenAPI 3.1 with the full ADR-0057 conventions: RFC 7807 errors with the `type` URI at `docs.honeydrunkstudios.com/errors/notify/{category}/`; cursor pagination on list endpoints (message history, templates list); IETF `RateLimit-*` headers documented in `info.x-rate-limits`; `Idempotency-Key` required on `POST /v1/notify/send` (Notify's billing-relevant endpoint per ADR-0042 + ADR-0057 D13); per-`securitySchemes` API key auth declaration. Scaffold Notify's `docs/` Docusaurus tree; wire the per-repo CI to call `job-openapi-diff.yml`, `job-publish-public-sdk.yml`, and `job-publish-docs.yml` from `HoneyDrunk.Actions`. Tag the first release `notify-api-v1.0.0` to trigger the publication pipeline. SDKs publish in dry-run until packet 11's operator onboarding seeds the per-registry credentials.

## Context
ADR-0057 D17 Phase 2 names Notify as the second pilot: *"`HoneyDrunk.Notify`'s existing endpoints get an OpenAPI v1 spec checked in. SDKs published to all three registries. Docs site live at `docs.notify.honeydrunkstudios.com/v1/`. This is the dry run for Notify Cloud GA."* Notify is more substantive than Web.Rest because it ships actual endpoints (intake, send, status, templates) rather than conventions; the OpenAPI spec is per-endpoint and the SDK generation produces real-callable clients.

`HoneyDrunk.Notify` is Live at `0.3.0` per `catalogs/nodes.json`. It ships a large solution: `HoneyDrunk.Notify` (core), `HoneyDrunk.Notify.Abstractions` (zero-dependency contracts), `HoneyDrunk.Notify.Functions` (Azure Functions host shape), `HoneyDrunk.Notify.HostBootstrap`, `HoneyDrunk.Notify.Hosting.AspNetCore`, `HoneyDrunk.Notify.IntegrationTests`, `HoneyDrunk.Notify.ProviderSupport`, `HoneyDrunk.Notify.Providers.Email.Resend`, `HoneyDrunk.Notify.Providers.Email.Smtp`, `HoneyDrunk.Notify.Providers.Sms.Twilio`, `HoneyDrunk.Notify.Queue.Abstractions`, `HoneyDrunk.Notify.Queue.AzureStorage`, `HoneyDrunk.Notify.Queue.InMemory`, `HoneyDrunk.Notify.Worker`, `HoneyDrunk.Notify.Tools`, plus the test project and a separate `HoneyDrunk.Notify.Tests`. The HTTP endpoints exposed today live in `HoneyDrunk.Notify.Hosting.AspNetCore` (the API host) and `HoneyDrunk.Notify.Functions` (the Functions host); both expose roughly the same intake / send / status surface. The OpenAPI v1 spec captures the AspNetCore-host shape as canonical (Functions-host parity is preserved at the controller layer; spec deviations between the two are flagged in the README).

**Notify is NOT Notify Cloud.** `HoneyDrunk.Notify` is the internal-Grid intake/delivery substrate consumed by other Grid Nodes (Web.Rest passes to Notify for tenant emails; Communications routes deprecation-notification through Notify per packet 01's named flow); `HoneyDrunk.Notify.Cloud` is the future commercial product (PDR-0002 / ADR-0027). The two surfaces are related but distinct — Notify Cloud will eventually expose its own OpenAPI spec with its own commercial endpoints (per ADR-0057 D17 Phase 3, deferred). Notify's v1 spec here documents the internal-Grid surface; it's a useful exercise for the SDK pipeline and the docs publication but its SDKs are unlikely to have external consumers at this scale.

Per ADR-0057 D8, the three SDKs publish to npm / Maven Central / Swift Package Index. Notify's SDKs (`@honeydrunk/notify-sdk`, `com.honeydrunkstudios:notify-sdk`, `HoneyDrunkNotifySdk`) are the **first concrete instances** of the SDK pipeline. They publish in dry-run mode until packet 11's operator onboarding completes; once credentials are seeded, the first tag push (`notify-api-v1.0.0`) publishes for real.

The version bump on the Notify solution itself is `0.3.0` → `0.4.0` (minor; additive — the new `api/openapi-v1.yaml` is reference-only, the `docs/` is new, the workflow wiring is config). No package shape change.

**Cursor pagination on Notify list endpoints.** Notify has list endpoints for message history (`GET /v1/notify/messages`) and templates (`GET /v1/notify/templates`). Per ADR-0057 D14, both move to cursor pagination at v1. This is a small behavior change for any internal Grid caller that uses these endpoints — the existing offset behavior (if any) becomes secondary or removed. **Check at execution time** whether the Notify endpoints currently expose offset-based pagination; if yes, the v1 spec documents cursor as the default and offset as a deprecated query parameter (`?offset=N&limit=N` returns the same shape but with an audit signal — to be removed at v2). If no offset pagination exists today, cursor is the only shape from v1.

The executor confirms the current endpoint shape at PR time by reading the Notify AspNetCore controllers and then commits the v1 spec that captures the current behavior plus the ADR-0057 conventions (RFC 7807 errors, IETF rate-limit headers documented, `Idempotency-Key` on `POST /v1/notify/send`). The breaking-change diff gate (packet 03) runs in first-introduction mode (no prior spec exists).

## Scope
- **`HoneyDrunk.Notify/api/openapi-v1.yaml`** (new) — OpenAPI 3.1 spec for the AspNetCore-host endpoints. Covers (at minimum, confirmed against the actual controllers at PR time): `POST /v1/notify/send` (with `Idempotency-Key` required), `GET /v1/notify/messages/{id}` (status lookup), `GET /v1/notify/messages` (list — cursor pagination), `GET /v1/notify/templates` (list — cursor pagination), `POST /v1/notify/templates` (create), `GET /v1/notify/templates/{id}` (read), `PUT /v1/notify/templates/{id}` (update — `Idempotency-Key` recommended), `DELETE /v1/notify/templates/{id}` (delete). Confirm the actual endpoint list against the controllers at execution time and add / remove as appropriate. `components.responses` covers `400`, `401`, `403`, `404`, `409`, `410` (cursor expired), `422`, `429`, `500` — each as RFC 7807 `application/problem+json`. `components.schemas` declares `SendRequest`, `MessageStatus`, `Template`, `CreateTemplateRequest`, `UpdateTemplateRequest`, `ProblemDetails` (the ADR-0057 D12 shape), `CursorPageResult` parametrized over `MessageStatus` and `Template`. `info.x-rate-limits` documents the per-tenant default limits (defer the concrete numbers to a future Notify-internal review; the substrate documents the convention). `securitySchemes` declares `apiKey` (`Authorization: Bearer {key}`).
- **`HoneyDrunk.Notify/docs/`** (new directory) — Docusaurus scaffold consuming the shared preset from packet 05 (or its own minimal config). Narrative: getting started, authentication, idempotency, pagination, rate limits, error handling, migration-to-future-majors.
- **`HoneyDrunk.Notify/.github/workflows/pr-openapi.yml`** (new) — calls `job-openapi-diff.yml` on PRs touching `HoneyDrunk.Notify/api/openapi-v*.yaml`.
- **`HoneyDrunk.Notify/.github/workflows/release-api.yml`** (new) — on tag `notify-api-v*`, calls `job-publish-public-sdk.yml` (all three languages enabled) and `job-publish-docs.yml`. Secret pass-through wired but the workflows run in dry-run when secrets are absent.
- **Endpoint behavior alignment** — confirm the actual endpoints return RFC 7807 errors (use the `HoneyDrunk.Web.Rest` middleware from packet 07 with the `Accept: application/problem+json` content negotiation as the path of least resistance — Notify's API host consumes `HoneyDrunk.Web.Rest.AspNetCore`, so wiring the middleware once on the host gives RFC 7807 for free for any caller that opts in via `Accept`). The actual default error envelope for clients that don't set `Accept` remains the existing Notify shape (Option C — non-breaking).
- **Idempotency wiring** — `POST /v1/notify/send` and `PUT /v1/notify/templates/{id}` consume `Idempotency-Key` via the `IIdempotencyStore` from ADR-0042. If ADR-0042's substrate is not yet wired into Notify at PR time, document the gap and ship the OpenAPI-spec-side `Idempotency-Key` parameter declaration anyway (the spec is the contract; runtime enforcement lands when the substrate catches up). State the choice in the PR.
- **Cursor pagination** — confirm at PR time whether the existing controllers paginate; if they do, refactor `GET /v1/notify/messages` and `GET /v1/notify/templates` to consume `CursorPageRequest` (from packet 07's `HoneyDrunk.Web.Rest.Abstractions`) and return `CursorPageResult<T>`. If they don't paginate today, add cursor pagination as a new feature in this packet (this is additive — non-breaking — and consistent with the v1 spec).
- **Tag and trigger** — at the end of the packet, the operator pushes `notify-api-v1.0.0` to trigger the publication workflows. The push is **deferred to the operator** (agents never tag per the convention); this packet ships the workflow wiring but does not push the tag. The Human Prerequisites list calls this out.
- **Version bump.** `HoneyDrunk.Notify` solution from `0.3.0` to `0.4.0` (additive minor); every non-test `.csproj` in one commit per invariant 27. Per-package CHANGELOGs only for packages with actual changes (the AspNetCore host + controllers if cursor pagination is added; the Abstractions if any new types — likely none, since the cursor primitives are pulled from `HoneyDrunk.Web.Rest.Abstractions`). Repo-level `CHANGELOG.md` gets a new dated `[0.4.0]` entry.
- **`HoneyDrunk.Notify/README.md`** — document the new OpenAPI v1 spec, the docs site at `docs.notify.honeydrunkstudios.com/v1/`, the SDK coordinates, and the v1 freeze.
- **Architecture-side `catalogs/contracts.json` update** — same as packet 07's note: either include a sibling commit to `HoneyDrunk.Architecture` populating the `honeydrunk-notify` `publicHttpApi` block's `openApiSpecPath`, `sdkCoordinates`, and `docsUrl`, or file a tiny follow-up packet (operator decision).

## Proposed Implementation
1. **Read the current Notify AspNetCore controllers** to enumerate the actual exposed endpoints. Confirm method / path / request shape / response shape for each.
2. **Author `api/openapi-v1.yaml`** matching the enumerated endpoints with the ADR-0057 conventions baked in:
   - `info.title: "HoneyDrunk Notify"`, `info.version: "1.0.0"`, `openapi: "3.1.0"`.
   - `info.x-rate-limits`: per-tenant defaults (free-tier-default numbers — substrate-level only; the actual per-tier limits emerge during Notify Cloud commercialization per ADR-0027 + ADR-0067 D3).
   - `components.responses`: every non-2xx response is `application/problem+json` → `ProblemDetails`.
   - `components.schemas.ProblemDetails`: the ADR-0057 D12 shape (`type`, `title`, `status`, `detail`, `instance`, `traceId`, `correlationId`).
   - `securitySchemes`: `apiKey` (Bearer in Authorization header per ADR-0057 D10).
   - Per-endpoint `parameters` include `Idempotency-Key` (header parameter) on `POST /v1/notify/send` as required; on `PUT /v1/notify/templates/{id}` as recommended.
   - List endpoints document `cursor` and `limit` query parameters per ADR-0057 D14.
   - The `info.x-honeydrunk-content-negotiation` extension documents that the AspNetCore host honors `Accept: application/problem+json` for error responses (Option C from packet 07 inherited via the Web.Rest middleware).
3. **Scaffold `docs/`** matching packet 07's Docusaurus structure. Narrative pages: `intro.md` (what Notify is), `auth.md` (Bearer API key per D10), `idempotency.md` (the `Idempotency-Key` contract per D13), `pagination.md` (cursor per D14, with the 410-gone behavior on expired cursor), `rate-limits.md` (IETF headers per D11; per-tenant), `errors.md` (RFC 7807 per D12, with the `type` URI catalog), `migrating-to-v2.md` (placeholder; will be rendered from the migration-guide template per packet 02 when v2 ships). Versioned at `versioned_docs/version-1/`.
4. **Wire per-repo CI workflows.**
   - `.github/workflows/pr-openapi.yml` — invokes `job-openapi-diff.yml` per packet 03 on PRs touching the spec file.
   - `.github/workflows/release-api.yml` — invokes `job-publish-public-sdk.yml` (TS + Swift + Kotlin enabled) and `job-publish-docs.yml` on `notify-api-v*` tag pushes. Pass through the secret env vars; dry-run when absent.
5. **Refactor list-endpoint controllers** to consume `CursorPageRequest` from `HoneyDrunk.Web.Rest.Abstractions` (packet 07's new types) and return `CursorPageResult<T>`. This is additive if the existing endpoints aren't paginated; if they were offset-paginated, the v1 spec captures both with the migration note. Add the `HoneyDrunk.Web.Rest.Abstractions` `0.6.0` `PackageReference` if not already present (it likely is — Notify consumes Web.Rest per `catalogs/relationships.json`).
6. **Wire `Idempotency-Key` enforcement on `POST /v1/notify/send`** via the `IIdempotencyStore` from ADR-0042. If ADR-0042's wiring is incomplete in Notify at PR time, the controller can return a 501 / 400 indicating the substrate is not yet live, or the wiring is deferred to a follow-up packet against Notify after ADR-0042 substrate is universal. State the choice in the PR.
7. **Version bump + CHANGELOGs + README + Canary.**
8. **Architecture-side catalog update note.**

## Affected Files
- `HoneyDrunk.Notify/api/openapi-v1.yaml` (new)
- `HoneyDrunk.Notify/docs/` (new directory + Docusaurus scaffold)
- `HoneyDrunk.Notify/.github/workflows/pr-openapi.yml` (new)
- `HoneyDrunk.Notify/.github/workflows/release-api.yml` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Hosting.AspNetCore/` — controller refactors for cursor pagination + RFC 7807 middleware composition + `Idempotency-Key` wiring (or deferred placeholder)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/` — equivalent controller updates if the Functions host parallels the AspNetCore host shape
- All non-test `.csproj` files in the Notify solution (version bump to `0.4.0`)
- `HoneyDrunk.Notify/CHANGELOG.md` (new dated `[0.4.0]` entry)
- Per-package CHANGELOGs only for packages with actual functional changes
- `HoneyDrunk.Notify/README.md`

## NuGet Dependencies
- **`HoneyDrunk.Web.Rest.Abstractions` `0.6.0`** (from packet 07) — `PackageReference` on `HoneyDrunk.Notify.Hosting.AspNetCore` (likely already present; bump version pin). The cursor pagination primitives flow from there.
- **`HoneyDrunk.Web.Rest.AspNetCore` `0.6.0`** — if Notify's host doesn't already use Web.Rest's middleware, this packet wires it (composition; no new types). Otherwise just bump the version pin.
- **`Microsoft.AspNetCore.RateLimiting`** — transitively present via the AspNetCore framework; no explicit `PackageReference` change.
- **`HoneyDrunk.Kernel`** — already a dependency for `IIdempotencyStore` (per ADR-0042); if the version pin needs bumping to pull in the latest, do so.

## Boundary Check
- [x] All edits in `HoneyDrunk.Notify`. Per routing rule.
- [x] No code change in any other repo.
- [x] OpenAPI spec is additive (no prior spec; first introduction).
- [x] Cursor pagination consumes `HoneyDrunk.Web.Rest.Abstractions` primitives from packet 07 — no new abstractions in Notify itself.
- [x] RFC 7807 middleware is `HoneyDrunk.Web.Rest.AspNetCore` composition — no new middleware logic in Notify.
- [x] Version bump applies invariant 27 (all non-test csprojs in one commit).

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify/api/openapi-v1.yaml` is checked in as OpenAPI 3.1; covers the actual endpoints (confirmed against the controllers at PR time); each non-2xx response is `application/problem+json` → `ProblemDetails`; `securitySchemes` declares Bearer API key; `POST /v1/notify/send` requires `Idempotency-Key`; list endpoints document `cursor` / `limit` query parameters; `info.x-rate-limits` documents the header convention
- [ ] `HoneyDrunk.Notify/docs/` carries a Docusaurus scaffold with at-minimum the narrative pages: `intro`, `auth`, `idempotency`, `pagination`, `rate-limits`, `errors`, `migrating-to-v2` placeholder
- [ ] `HoneyDrunk.Notify/.github/workflows/pr-openapi.yml` calls `job-openapi-diff.yml` per packet 03
- [ ] `HoneyDrunk.Notify/.github/workflows/release-api.yml` calls `job-publish-public-sdk.yml` (TS + Swift + Kotlin) and `job-publish-docs.yml` per packets 04 and 05; secret pass-through wired; dry-run when secrets absent
- [ ] List endpoints (`GET /v1/notify/messages`, `GET /v1/notify/templates`) consume `CursorPageRequest` and return `CursorPageResult<T>` from `HoneyDrunk.Web.Rest.Abstractions` 0.6.0
- [ ] `POST /v1/notify/send` enforces `Idempotency-Key` via `IIdempotencyStore` from ADR-0042 (or documents the deferred-substrate state explicitly in the PR if ADR-0042's wiring is incomplete in Notify at execution time)
- [ ] AspNetCore host wires `HoneyDrunk.Web.Rest.AspNetCore` middleware so the RFC 7807 content negotiation (Option C from packet 07) is in effect
- [ ] Tests cover: `POST /v1/notify/send` without `Idempotency-Key` returns a 400 problem+json; with `Idempotency-Key` succeeds (or documents the deferred-substrate state); list endpoints honor `?cursor=...&limit=...`; the `Accept: application/problem+json` flips the error envelope shape
- [ ] All non-test `.csproj` files at `0.4.0` in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` carries a new dated `[0.4.0]` entry (no `[Unreleased]`)
- [ ] Per-package CHANGELOGs entered only for packages with actual functional changes (avoid noise entries per invariant 12/27)
- [ ] `README.md` documents the new OpenAPI v1 spec, the docs site URL, the SDK coordinates, and the v1 freeze
- [ ] No invariant edit in this packet (invariants `{N1}-{N4}` land via packet 00; this packet honors them)
- [ ] First run of `job-openapi-diff.yml` against `openapi-v1.yaml` passes (first-introduction case)

## Human Prerequisites
- [ ] **Publishing the upstream NuGet package** — after this packet merges, a human pushes a git release tag `v0.4.0` (or `notify-v0.4.0` per the repo convention) for the Notify NuGet packages. Agents never tag.
- [ ] **Trigger the API publication** — push the tag `notify-api-v1.0.0` to trigger `release-api.yml` (which calls the three publication workflows). This is the first concrete invocation of the SDK + docs pipeline. **Dry-run is expected** until packet 11 seeds the credentials — the workflow logs will be loud about the dry-run reason.
- [ ] **Cloudflare Pages project for `docs.notify.honeydrunkstudios.com`** — packet 09 (Studios) provisions this. Until packet 09 is complete, the docs publication runs in dry-run via the `job-publish-docs.yml` fallback. Re-tag (or re-run the workflow manually) after packet 09 + packet 11 complete to publish for real.
- [ ] **npm `@honeydrunk` scope + Maven Central `com.honeydrunkstudios` namespace + Swift Package Index** — packet 11 covers the namespace onboarding. Until then, SDK publication is dry-run.
- [ ] **Architecture-side `catalogs/contracts.json` update** — populating `openApiSpecPath: "repos/HoneyDrunk.Notify/api/openapi-v1.yaml"`, `sdkCoordinates: { typescript: "@honeydrunk/notify-sdk", swift: "HoneyDrunkNotifySdk", kotlin: "com.honeydrunkstudios:notify-sdk" }`, and `docsUrl: "https://docs.notify.honeydrunkstudios.com/v1/"` on the `honeydrunk-notify` `publicHttpApi` block — either as a sibling commit to `HoneyDrunk.Architecture` or as a tiny follow-up packet. State the choice in the PR.

## Referenced ADR Decisions
**ADR-0057 D17 Phase 2 — Notify Phase 2 pilot.** "`HoneyDrunk.Notify`'s existing endpoints get an OpenAPI v1 spec checked in. SDKs published to all three registries. Docs site live at `docs.notify.honeydrunkstudios.com/v1/`. This is the dry run for Notify Cloud GA."

**ADR-0057 D7 — OpenAPI 3.1 as source of truth.** Spec at `HoneyDrunk.Notify/api/openapi-v1.yaml`.

**ADR-0057 D8 — SDK languages.** `@honeydrunk/notify-sdk` (npm), `HoneyDrunkNotifySdk` (SPM), `com.honeydrunkstudios:notify-sdk` (Maven Central). Generated via `job-publish-public-sdk.yml` per packet 04.

**ADR-0057 D12 — RFC 7807 error envelope.** `type` URIs at `docs.honeydrunkstudios.com/errors/notify/{category}/`. `traceId` from W3C `traceparent` (ADR-0040); `correlationId` from the `IOperationContextAccessor` (ADR-0045).

**ADR-0057 D13 — Idempotency on writes.** `Idempotency-Key` required on `POST /v1/notify/send` (billing-relevant when Notify Cloud commercializes per ADR-0027 + ADR-0037); recommended on `PUT /v1/notify/templates/{id}`. SDK-generated key auto-injection per packet 04's override templates.

**ADR-0057 D14 — Cursor pagination.** Default `limit=50`, max `limit=200`. Cursor opacity, 24h TTL, `410 Gone` on expired cursor. Consumes the `CursorPageRequest` / `CursorPageResult` primitives from `HoneyDrunk.Web.Rest.Abstractions` 0.6.0 (packet 07).

**ADR-0057 D11 (reconciled with ADR-0067) — Rate-limit envelope.** Documented in `info.x-rate-limits`; runtime emission via `HoneyDrunk.Web.Rest.AspNetCore` middleware (packet 07's rate-limit hook) or the Kernel's `UseGridRateLimiting` (ADR-0067 packet 02 when composed into the Notify host).

**ADR-0042 (referenced) — `IIdempotencyStore`.** The dedup substrate consumed by `POST /v1/notify/send` and `PUT /v1/notify/templates/{id}`. If ADR-0042's wiring is incomplete in Notify at PR time, the OpenAPI-spec-side declaration ships anyway; runtime wiring lands when the substrate catches up.

**ADR-0035 D1 (referenced) — Additive minor bump.** `0.3.0` → `0.4.0`.

**Invariants `{N1}` and `{N2}`** — Notify ships its first OpenAPI 3.1 spec (`{N1}`); the OpenAPI-diff gate prevents future breaking changes without a major bump (`{N2}`).

## Constraints
- **Spec contents are reverse-engineered from current controllers** — confirm against actual code at PR time; do not invent endpoints that don't exist.
- **Cursor pagination requires Web.Rest 0.6.0** (packet 07).
- **RFC 7807 middleware comes from Web.Rest 0.6.0** (packet 07's Option C content negotiation).
- **Idempotency wiring may be deferred** if ADR-0042 substrate is incomplete in Notify; the spec ships the declaration regardless.
- **Per-tier rate-limit numbers deferred** — Notify's commercialization is via Notify Cloud (ADR-0027 deferred); the v1 spec documents the header convention but does not commit per-tier numbers.
- **Notify is NOT Notify Cloud.** Notify's SDKs are unlikely to have external consumers at this scale; this pilot exercises the pipeline and validates the workflows.
- **Tag is operator-pushed.** Agents never tag.
- **Dry-run for SDK + docs publication** until packet 11 + packet 09.
- **Functions host parity preserved** — if the AspNetCore controllers are updated, the Functions host either matches (preferred) or the README documents the divergence as known tech debt.
- **No `Unreleased` CHANGELOG.**

## Labels
`feature`, `tier-2`, `core`, `adr-0057`, `wave-4`

## Agent Handoff

**Objective:** Pilot ADR-0057's Phase 2 substrate on `HoneyDrunk.Notify`: author the OpenAPI 3.1 v1 spec capturing the existing endpoints with the full ADR-0057 conventions; scaffold Notify's Docusaurus docs; wire the per-repo CI to call the three reusable workflows from `HoneyDrunk.Actions`; refactor list endpoints to cursor pagination; wire `Idempotency-Key` on the billing-relevant write endpoint; compose Web.Rest's RFC 7807 middleware on the host. Tag and trigger the publication pipeline (operator-pushed; dry-run until credentials seeded).

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: The dry run for Notify Cloud GA. Exercise the full SDK + docs publication pipeline on a real-endpoint surface.
- Feature: ADR-0057 rollout, Wave 4 (Phase 2 pilot).
- ADRs: ADR-0057 D17 Phase 2 / D7 / D8 / D12 / D13 / D14 / D11 / D10 (primary); ADR-0042 (`IIdempotencyStore`); ADR-0067 (rate-limit envelope); ADR-0027 (Notify Cloud — Phase 3 deferred); ADR-0035 D1 (additive minor bump).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0057 Accepted.
- `packet:01` — tech-stack.md + `publicHttpApi` block convention.
- `packet:03` — `job-openapi-diff.yml`.
- `packet:04` — `job-publish-public-sdk.yml`.
- `packet:05` — `job-publish-docs.yml`.
- `packet:07` — Web.Rest 0.6.0 (cursor primitives + RFC 7807 middleware + rate-limit-header hook).

**Constraints:**
- Spec contents reverse-engineered, not invented.
- Cursor pagination consumed from Web.Rest 0.6.0.
- RFC 7807 middleware composed from Web.Rest 0.6.0.
- Idempotency may be deferred; spec declaration ships regardless.
- Per-tier rate-limit numbers deferred to Notify Cloud commercialization.
- Tag operator-pushed; dry-run until credentials seeded.
- Functions / AspNetCore host parity preserved or documented divergence.
- No `Unreleased` CHANGELOG.

**Key Files:**
- `HoneyDrunk.Notify/api/openapi-v1.yaml` (new)
- `HoneyDrunk.Notify/docs/` (Docusaurus scaffold)
- `HoneyDrunk.Notify/.github/workflows/pr-openapi.yml`, `release-api.yml` (new)
- `HoneyDrunk.Notify.Hosting.AspNetCore/` and `HoneyDrunk.Notify.Functions/` controller updates
- All non-test `.csproj` files (version bump to 0.4.0)
- CHANGELOGs + README

**Contracts:**
- Consumed: `CursorPageRequest`, `CursorPageResult`, `ProblemDetails`, `UseRateLimitHeaders` from Web.Rest 0.6.0 (packet 07).
- Consumed: `IIdempotencyStore` from Kernel (ADR-0042).
- New: the per-endpoint contract as expressed in the OpenAPI spec.
