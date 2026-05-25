---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["feature", "tier-2", "core", "adr-0057", "wave-3"]
dependencies: ["packet:00", "packet:01", "packet:03", "packet:05"]
adrs: ["ADR-0057"]
wave: 3
initiative: adr-0057-api-versioning
node: honeydrunk-web-rest
---

# Reverse-engineer openapi-v1.yaml for HoneyDrunk.Web.Rest, freeze the surface at v1, ship Option C envelope alignment

## Summary
The Phase 1 pilot per ADR-0057 D17. `HoneyDrunk.Web.Rest` is the low-risk surface that exercises the full substrate (packet 03 OpenAPI diff gate; packet 05 docs publication) before Notify's higher-stakes Phase 2 pilot. Reverse-engineer an OpenAPI 3.1 specification from Web.Rest's existing AspNetCore middleware-emitted endpoints + shapes; check it in at `HoneyDrunk.Web.Rest/api/openapi-v1.yaml`; freeze the public surface at v1 (any future endpoint addition is a minor spec revision; any future breaking change is v2). Ship the **Option C envelope alignment**: additive RFC 7807 `application/problem+json` shape on errors *alongside* the existing `ApiErrorResponse`, with the in-AspNetCore middleware now emitting both shapes — a `Accept: application/problem+json`-aware content negotiation, defaulting to `ApiErrorResponse` for backwards compatibility, switching to RFC 7807 when the client signals it. Add IETF `RateLimit-*` header conventions (the response-shaping hooks on `ApiResult`/middleware so future limiter wiring per packet 02 of ADR-0067 inserts the correct headers). Add cursor-pagination primitives to `HoneyDrunk.Web.Rest.Abstractions/Paging/` alongside the existing `PageRequest`/`PageResult` (the existing offset shape is retained for backwards compatibility; the new cursor shape is the v2-default per ADR-0057 D14 once v2 ships). Wire `job-openapi-diff.yml` + `job-publish-docs.yml` into the per-repo CI. Scaffold a minimal `docs/` Docusaurus tree for the docs site. Version-bump the Web.Rest solution per invariant 27.

## Context
`HoneyDrunk.Web.Rest` is Live at `0.5.0` per `catalogs/nodes.json`. It ships two packages — `HoneyDrunk.Web.Rest.Abstractions` (zero-dependency contracts: `ApiResult<T>`, `ApiErrorResponse`, `ApiError`, `ApiErrorCode`, `ValidationError`, `PageRequest`, `PageResult`) and `HoneyDrunk.Web.Rest.AspNetCore` (ASP.NET Core middleware: correlation, exception-to-error mapping, auth failure shaping, MVC/minimal-API conventions). ADR-0057 D17 Phase 1 names Web.Rest as the pilot: *"likely `HoneyDrunk.Web.Rest` v1 (already Live; the spec is reverse-engineered from the existing endpoints and the version freezes at v1)."*

**The envelope migration is the load-bearing tactical decision.** Web.Rest today emits `ApiErrorResponse` (Studios-specific shape: `Code`, `Message`, `Details`, `CorrelationId`, validation array). ADR-0057 D12 commits RFC 7807 `application/problem+json` (`type`, `title`, `status`, `detail`, `instance`, `traceId`, `correlationId`). The existing consumers of Web.Rest cannot be assumed to handle a sudden shape change; per ADR-0057 D4, changing the error envelope is a breaking change requiring a major version bump.

**Three options were considered at refine time; pin Option C:**
- **Option A (sudden cutover):** middleware emits only RFC 7807 from `0.6.0`. Every Web.Rest consumer breaks. Rejected — this is what versioning policy is designed to prevent.
- **Option B (defer to v2):** middleware emits only `ApiErrorResponse` until v2 ships, then v2 emits only RFC 7807. Works in principle but ADR-0057 D17 Phase 1 names Web.Rest as the *pilot* — the whole point is to exercise the substrate now, not in 180 days. Also, ADR-0057's RFC 7807 is the Grid-wide convention; deferring the alignment means downstream consumer code keeps coupling to `ApiErrorResponse` even longer.
- **Option C (additive headers + RFC 7807 alignment — PINNED):** middleware emits *both* shapes via content negotiation. Default response remains `ApiErrorResponse` for existing consumers. When the request `Accept` header includes `application/problem+json` (with quality higher than `application/json`), the middleware emits the RFC 7807 shape instead. The two shapes are emitted from a single code path — the middleware builds a canonical internal error record, then projects it into one shape or the other based on content negotiation. ADR-0057's `type` / `traceId` / `correlationId` fields are populated in both shapes (the existing `ApiErrorResponse` gets a `Type` field added — additive per D4 — and the existing `CorrelationId` is reused). The IETF `RateLimit-*` headers are added to the response-shaping pipeline (the actual rate-limit wiring lands per ADR-0067 packet 02 in Kernel; Web.Rest's middleware just makes sure the headers, when present, are preserved end-to-end and the response-decorator hooks exist). Cursor pagination primitives are added to Abstractions alongside the existing offset shape; the OpenAPI v1 spec documents the offset shape (the surface freezes at v1's existing shape per the pilot's freeze-the-surface constraint) and the cursor shape is documented as the v2-default convention.

Option C is **additive on the existing surface**: per ADR-0057 D4, a new optional response field (`Type` on `ApiErrorResponse`) is non-breaking; new endpoints / new content-negotiated representations are non-breaking; new optional Abstractions types (`CursorPageRequest` / `CursorPageResult`) are non-breaking. The v1 OpenAPI spec captures the current behavior (offset-only pagination, both error envelopes via content negotiation). The breaking-change diff gate (packet 03) will pass.

**Web.Rest is library-only.** It has no deployable endpoints; the "API surface" it exposes is its `Abstractions` package + the middleware-emitted shapes consuming services use. The OpenAPI v1 spec for Web.Rest therefore documents the **convention** — the shapes of `ApiResult<T>`, `ApiErrorResponse`, RFC 7807 problem+json, `PageRequest`/`PageResult`, `CursorPageRequest`/`CursorPageResult`, the IETF `RateLimit-*` header set — as a reference document rather than as a per-endpoint catalog. Future consuming services (Notify Cloud, future Billing) generate their own per-API spec; Web.Rest's spec is the upstream contract document.

This is the **first concrete OpenAPI spec checked into the Grid.** It exercises packet 03's diff gate (first run: no prior tag → falls back to branch mode; no prior file on `main` → first-introduction info-level pass), packet 05's docs publication (first build of `docs.web-rest.honeydrunkstudios.com/v1/` — Cloudflare Pages project must exist; per the dispatch plan's deferral note, the first docs publication is dry-run until packet 09's per-API docs subdomain provisioning extends to Web.Rest in a follow-up).

The version bump is `0.5.0` → `0.6.0` (additive minor per ADR-0035 D1) since `ApiErrorResponse.Type` is additive, the cursor primitives are net-new, and the middleware content negotiation is additive (default-`ApiErrorResponse` preserves the existing default).

## Scope
- **`HoneyDrunk.Web.Rest/api/openapi-v1.yaml`** (new) — the reverse-engineered OpenAPI 3.1 spec. Documents the Abstractions shapes and the AspNetCore middleware behavior as a reference contract.
- **`HoneyDrunk.Web.Rest.Abstractions/Errors/ProblemDetails.cs`** (new) — record implementing the RFC 7807 shape: `Type`, `Title`, `Status`, `Detail`, `Instance`, `TraceId`, `CorrelationId`.
- **`HoneyDrunk.Web.Rest.Abstractions/Errors/ApiErrorResponse.cs`** — add an additive `Type` property (nullable string, defaults to null; populated by the middleware to match the RFC 7807 `type` URI for the same error category).
- **`HoneyDrunk.Web.Rest.Abstractions/Paging/CursorPageRequest.cs`** (new) — record: `Cursor` (nullable string), `Limit` (int, default 50, max 200 per ADR-0057 D14).
- **`HoneyDrunk.Web.Rest.Abstractions/Paging/CursorPageResult.cs`** (new) — record: `Items` (IReadOnlyList<T>), `NextCursor` (nullable string).
- **`HoneyDrunk.Web.Rest.AspNetCore/Middleware/`** — extend the existing exception-to-error middleware to (a) build a canonical internal error record, (b) project it into `ApiErrorResponse` when the request `Accept` header prefers `application/json`, (c) project it into `ProblemDetails` (RFC 7807 `application/problem+json` media type) when the request prefers `application/problem+json`. The default-`ApiErrorResponse` preserves backwards compatibility.
- **`HoneyDrunk.Web.Rest.AspNetCore/Middleware/`** — add a small response-decoration hook that, when an `IRateLimitState` ambient (or equivalent ASP.NET Core RateLimiter lease metadata, when the Kernel's `UseGridRateLimiting` from ADR-0067 packet 02 is wired into the consuming host) is present, projects the IETF `RateLimit-*` headers per ADR-0057 D11 / ADR-0067 D7. The hook is best-effort and a no-op when no rate-limit state is present.
- **`HoneyDrunk.Web.Rest/docs/`** (new directory) — minimal Docusaurus scaffold (`docusaurus.config.js`, `sidebars.js`, `docs/intro.md`, `versioned_docs/version-1/` per Docusaurus convention). Narrative: a "Web.Rest conventions reference" landing page that complements the OpenAPI reference. Consumes the shared Docusaurus preset from packet 05 (if shipped) or carries its own minimal config (acceptable per packet 05's constraint).
- **`HoneyDrunk.Web.Rest/.github/workflows/`** — wire the reusable workflows from packets 03 and 05:
  - `pr-openapi.yml` — calls `job-openapi-diff.yml` on every PR touching `HoneyDrunk.Web.Rest/api/openapi-v*.yaml`.
  - `release.yml` (or extend existing release workflow) — on tag matching `web-rest-api-v*`, calls `job-publish-docs.yml`. (SDK publication via `job-publish-public-sdk.yml` is **deferred for Web.Rest** — Web.Rest is a library Node consumed by .NET callers via NuGet; no TS / Swift / Kotlin SDK is published per the ADR-0057 D8 deferred-list reasoning extended to .NET-consumer libraries.)
- **Tests** — unit tests for: the middleware's content negotiation (Accept `application/json` → `ApiErrorResponse`; Accept `application/problem+json` → `ProblemDetails`; missing/wildcard Accept → `ApiErrorResponse`); the new `Type` field on `ApiErrorResponse`; the `CursorPageRequest`/`CursorPageResult` shapes (record equality, default `Limit=50`, validation of `Limit<=200`); the response decoration hook for `RateLimit-*` headers (best-effort; no-op when state absent).
- **Version bump.** Both non-test `.csproj` files in the Web.Rest solution from `0.5.0` to `0.6.0` (invariant 27). Repo-level `CHANGELOG.md` gets a new dated `[0.6.0]` entry. Per-package CHANGELOGs: `HoneyDrunk.Web.Rest.Abstractions/CHANGELOG.md` gets an entry (new types added — `ProblemDetails`, `CursorPageRequest`, `CursorPageResult`, `ApiErrorResponse.Type` field); `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` gets an entry (content negotiation + rate-limit-header hook). `HoneyDrunk.Web.Rest.Canary` (the contract-shape canary) is updated to assert the new types are exposed.
- **`HoneyDrunk.Web.Rest/README.md`** — document the OpenAPI v1 spec, the content-negotiation behavior, the cursor pagination primitives, the v1 freeze, and the v2-future conventions (cursor-default-on-list-endpoints, RFC-7807-default-on-error-responses).
- **Repo-level `catalogs/contracts.json` update in HoneyDrunk.Architecture** — packet 01 introduced the `publicHttpApi` block on the `honeydrunk-web-rest` entry with `surfaceName` / `currentMajor` only; this packet populates `openApiSpecPath: "repos/HoneyDrunk.Web.Rest/api/openapi-v1.yaml"` and `docsUrl: "https://docs.web-rest.honeydrunkstudios.com/v1/"` (deferred to a small Architecture-side update PR by the executor if the per-repo target is awkward — flag it in the PR). `sdkCoordinates` stays empty (no public SDK per the deferred-language reasoning above).

## Proposed Implementation
1. **Author the OpenAPI 3.1 spec.** The spec documents the Web.Rest *convention* surface:
   - `info.title: "HoneyDrunk.Web.Rest Conventions"`, `info.version: "1.0.0"`, `openapi: "3.1.0"`.
   - `components.schemas`: `ApiResult` (oneOf success/failure), `ApiResult_Of_T` (generic schema referenced by spec callers), `ApiErrorResponse` (with the new `Type` field), `ApiError`, `ApiErrorCode` (enum), `ValidationError`, `ProblemDetails` (RFC 7807), `PageRequest`, `PageResult`, `CursorPageRequest`, `CursorPageResult`.
   - `components.responses`: `ProblemResponse` (media type `application/problem+json` → `ProblemDetails`); `ErrorResponse` (media type `application/json` → `ApiErrorResponse`).
   - `paths`: empty (Web.Rest does not expose endpoints — it ships conventions). The spec ships an `x-honeydrunk-conventions: true` extension to signal this to docs and SDK generators (the SDK generator should NOT generate a client for this spec — it is reference-only).
   - `info.x-rate-limits`: documented per ADR-0067 D7 / ADR-0057 D11 convention (the limits themselves are deferred to consuming services; this spec documents the header shape).
   - `info.x-honeydrunk-content-negotiation`: documents the Option C content negotiation (`application/json` → `ApiErrorResponse`; `application/problem+json` → `ProblemDetails`).
2. **`ProblemDetails.cs`** — record matching RFC 7807. JSON-serializable with `System.Text.Json` lower-case key names; `Type` / `Title` / `Status` / `Detail` / `Instance` are RFC; `TraceId` / `CorrelationId` are Studios extensions (acceptable per RFC 7807 §3.2 "Members of a problem type can be extended").
3. **`ApiErrorResponse.cs`** — add the new optional `Type` property (nullable string, default null). Existing consumers continue to ignore the field per ADR-0057 D4 "new response field is non-breaking, conditional on the client-side ignore-unknown-fields rule" — which `System.Text.Json` honors by default with its `JsonIgnoreCondition.WhenWritingNull`. The Web.Rest README adds a note to the conventions doc reminding consumers that new optional fields may appear.
4. **`CursorPageRequest.cs` / `CursorPageResult.cs`** — records matching ADR-0057 D14 shape. `CursorPageRequest`: `string? Cursor`, `int Limit = 50` with constructor-side validation `Limit >= 1 && Limit <= 200`. `CursorPageResult<T>`: `IReadOnlyList<T> Items`, `string? NextCursor`.
5. **Middleware content negotiation.** In the existing exception-to-error middleware (or its constructor/extension):
   - Build the canonical internal error record from the exception (existing code path).
   - Inspect `HttpContext.Request.Headers.Accept`. If `application/problem+json` is present and its quality is `>= application/json`'s quality (or `application/json` is absent), set the response `Content-Type = application/problem+json` and serialize the canonical record into a `ProblemDetails` shape. Otherwise, set `Content-Type = application/json` and serialize into the existing `ApiErrorResponse` shape (now with the optional `Type` field populated).
   - The `Type` URI is the per-error-category URI per ADR-0057 D12. Web.Rest's middleware ships a small lookup table mapping `ApiErrorCode` → `type URI` (each URI at `https://docs.honeydrunkstudios.com/errors/web-rest/{category}/`). The lookup is `internal static`; consuming services that introduce new error codes register their own URIs via an opt-in extension (defer to a future packet if needed — the Web.Rest-defined codes have URIs in this packet).
   - The `TraceId` is sourced from `Activity.Current?.Id` (W3C `traceparent` per ADR-0040). The `CorrelationId` is sourced from the existing `IOperationContextAccessor` (per ADR-0045's `ErrorContext`).
6. **`RateLimit-*` header hook.** A small middleware (`UseRateLimitHeaders()` extension on `IApplicationBuilder`) that, after the response is being prepared, inspects the rate-limit context if present and emits the `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset` headers per ADR-0057 D11 / ADR-0067 D7. Best-effort, no-op when context absent. When the consuming host wires the Kernel's `UseGridRateLimiting` from ADR-0067 packet 02, the Kernel middleware emits the headers itself; Web.Rest's hook is a defensive fallback for any host that needs the headers but isn't on the Kernel limiter yet.
7. **Docusaurus scaffold.** A minimal `docs/` directory: `docusaurus.config.js`, `sidebars.js`, `docs/intro.md` (the conventions landing page), `versioned_docs/version-1/intro.md` (the v1 frozen narrative). The narrative covers: what Web.Rest is, what `ApiResult<T>` / `ApiErrorResponse` / `ProblemDetails` are, how to opt into RFC 7807 via `Accept`, cursor vs. offset pagination conventions, the IETF rate-limit header set, the v1 freeze.
8. **Per-repo CI workflows.** Add `.github/workflows/pr-openapi.yml` (calls `job-openapi-diff.yml` per packet 03) and extend the existing release workflow to call `job-publish-docs.yml` per packet 05 on `web-rest-api-v*` tags. The docs deploy runs in dry-run until the `docs.web-rest.honeydrunkstudios.com` Pages project is provisioned (packet 09 covers Notify; Web.Rest's docs subdomain follows the same playbook in a follow-up).
9. **Tests** — assert the content negotiation, the new field, the cursor primitives, the rate-limit header hook.
10. **Version bump + CHANGELOGs + README.**
11. **Architecture-side `catalogs/contracts.json` follow-up note** — if it's awkward for this packet (which targets Web.Rest) to also touch the Architecture catalog, flag it as a small follow-up packet against Architecture. The note in the PR is sufficient; the catalog update can land in a tiny `12-architecture-web-rest-contracts-update.md` follow-up if necessary, or be batched into a later catalog-update packet.

## Affected Files
- `HoneyDrunk.Web.Rest/api/openapi-v1.yaml` (new)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Abstractions/Errors/ProblemDetails.cs` (new)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Abstractions/Errors/ApiErrorResponse.cs` (additive change)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Abstractions/Paging/CursorPageRequest.cs` (new)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Abstractions/Paging/CursorPageResult.cs` (new)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Middleware/` — extension for content negotiation + the rate-limit header hook
- `HoneyDrunk.Web.Rest/docs/` (new directory + Docusaurus scaffold)
- `HoneyDrunk.Web.Rest/.github/workflows/pr-openapi.yml` (new)
- `HoneyDrunk.Web.Rest/.github/workflows/` release workflow (extension to call `job-publish-docs.yml`)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Abstractions/HoneyDrunk.Web.Rest.Abstractions.csproj` (version bump)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/HoneyDrunk.Web.Rest.AspNetCore.csproj` (version bump)
- Per-package CHANGELOGs (`HoneyDrunk.Web.Rest.Abstractions/CHANGELOG.md`, `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md`)
- Repo-level `HoneyDrunk.Web.Rest/CHANGELOG.md` (new dated `[0.6.0]` entry)
- `HoneyDrunk.Web.Rest/README.md`
- `HoneyDrunk.Web.Rest.Tests/` — new tests for content negotiation, cursor primitives, rate-limit hook
- `HoneyDrunk.Web.Rest.Canary/` — updated to assert the new types

## NuGet Dependencies
- **`HoneyDrunk.Web.Rest.Abstractions`** — no new `PackageReference`. RFC 7807 shape is a Studios-defined record; no library dependency needed. (Note: `Microsoft.AspNetCore.Mvc.Core` ships its own `Microsoft.AspNetCore.Mvc.ProblemDetails` — we deliberately do NOT consume that one in Abstractions because Abstractions is zero-HoneyDrunk-and-zero-AspNetCore-runtime-dependency per the package's existing posture.)
- **`HoneyDrunk.Web.Rest.AspNetCore`** — no new `PackageReference`. The middleware extension uses existing ASP.NET Core APIs.

## Boundary Check
- [x] `HoneyDrunk.Web.Rest` per routing rule "REST conventions, response standardization, middleware → HoneyDrunk.Web.Rest".
- [x] New types in `Abstractions` are zero-dependency (no HoneyDrunk runtime, no ASP.NET Core types in Abstractions per the package's existing posture — invariant 1).
- [x] Middleware lives in `AspNetCore` package only.
- [x] All shape additions are additive per ADR-0057 D4 (`ApiErrorResponse.Type` new optional field; new types in Abstractions; new middleware) — the breaking-change diff gate (packet 03) will pass.
- [x] No cross-Node runtime dependency added.

## Acceptance Criteria
- [ ] `HoneyDrunk.Web.Rest/api/openapi-v1.yaml` is checked in; OpenAPI 3.1 (not 3.0); documents the convention surface (`ApiResult`, `ApiErrorResponse` with new `Type`, `ProblemDetails`, `PageRequest`/`PageResult`, `CursorPageRequest`/`CursorPageResult`, the IETF `RateLimit-*` header set, the content-negotiation convention); `info.x-honeydrunk-conventions: true` extension is set
- [ ] `HoneyDrunk.Web.Rest.Abstractions/Errors/ProblemDetails.cs` is a new record matching RFC 7807 fields plus the `TraceId` / `CorrelationId` Studios extensions
- [ ] `ApiErrorResponse` gains an optional `Type` (nullable string, default null) property — additive
- [ ] `CursorPageRequest` and `CursorPageResult` are new records in `Paging/`; `Limit` defaults to 50, validates `1 <= Limit <= 200`
- [ ] The middleware does content negotiation: `Accept: application/problem+json` → emits `ProblemDetails`; otherwise emits the existing `ApiErrorResponse` (now with `Type` populated from the per-`ApiErrorCode` lookup table)
- [ ] The middleware sources `TraceId` from `Activity.Current?.Id` and `CorrelationId` from `IOperationContextAccessor`
- [ ] A new `UseRateLimitHeaders()` middleware extension exists in `AspNetCore` that emits IETF `RateLimit-*` headers when rate-limit context is present, no-op otherwise
- [ ] `HoneyDrunk.Web.Rest/docs/` carries a minimal Docusaurus scaffold (config, sidebars, intro, versioned-docs structure for v1)
- [ ] `HoneyDrunk.Web.Rest/.github/workflows/pr-openapi.yml` calls `job-openapi-diff.yml` from `HoneyDrunk.Actions`
- [ ] The release workflow (existing or new) calls `job-publish-docs.yml` from `HoneyDrunk.Actions` on `web-rest-api-v*` tags (dry-run until the `docs.web-rest.honeydrunkstudios.com` Pages project exists)
- [ ] Web.Rest is **not** wired to `job-publish-public-sdk.yml` (Web.Rest is a .NET-consumer library; per ADR-0057 D8's deferred-language reasoning, no TS / Swift / Kotlin SDK is published)
- [ ] Tests cover: content negotiation (three Accept cases); `ApiErrorResponse.Type` populated and round-tripped; `CursorPageRequest` defaults and validation; `CursorPageResult` shape; `UseRateLimitHeaders` no-op without context and emit-correct with context
- [ ] Both non-test `.csproj` files at `0.6.0` in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` carries a new dated `[0.6.0]` entry (no `[Unreleased]`)
- [ ] Per-package CHANGELOGs (`Abstractions`, `AspNetCore`) get `[0.6.0]` entries
- [ ] `Canary` project asserts the new types are exposed (contract-shape canary)
- [ ] `README.md` documents the OpenAPI v1 spec, content negotiation, cursor primitives, v1 freeze, and v2-future conventions
- [ ] No invariant edit in this packet — invariants `{N1}-{N4}` land via packet 00; this packet honors them
- [ ] The first run of `job-openapi-diff.yml` against `openapi-v1.yaml` passes (first-introduction case)

## Human Prerequisites
- [ ] **Publishing the upstream NuGet package** — after this packet merges, a human pushes a git release tag `v0.6.0` (or `web-rest-v0.6.0` per the repo convention) so consuming services can compile against the new `HoneyDrunk.Web.Rest.Abstractions` `0.6.0` shape. The `web-rest-api-v1.0.0` tag (separate from the package release tag) is pushed at the same time to trigger the `job-publish-docs.yml` workflow (dry-run until packet 09 + Web.Rest docs subdomain provisioning).
- [ ] **Cloudflare Pages project for `docs.web-rest.honeydrunkstudios.com`** — packet 09 provisions the Notify docs subdomain; the Web.Rest docs subdomain follows the same playbook in a follow-up (operator-time). Until then, the docs deploy runs in dry-run via the `job-publish-docs.yml` fallback. This is acceptable for Phase 1 pilot — the substrate is exercised, the docs are buildable, deployment is the deferred-but-easy last mile.
- [ ] **`catalogs/contracts.json` update** — the Architecture-side update (populating `openApiSpecPath` and `docsUrl` on the `honeydrunk-web-rest` `publicHttpApi` block) is awkward to land from a Web.Rest PR. State the choice in this PR: either (a) include a sibling commit to `HoneyDrunk.Architecture` if the merge sequence allows, or (b) file a tiny `12-architecture-web-rest-contracts-update.md` follow-up packet (operator decision; either is acceptable).

## Referenced ADR Decisions
**ADR-0057 D17 Phase 1 — Pilot on HoneyDrunk.Web.Rest.** "Pilot all of this on a low-risk surface — likely `HoneyDrunk.Web.Rest` v1 (already Live; the spec is reverse-engineered from the existing endpoints and the version freezes at v1)."

**ADR-0057 D7 — OpenAPI 3.1 as the source of truth.** Spec at `repos/{node}/api/openapi-v{n}.yaml`. Web.Rest's spec documents the convention surface rather than endpoints — `info.x-honeydrunk-conventions: true` extension is the signal.

**ADR-0057 D12 — RFC 7807 error envelope.** `application/problem+json` with `type` URI at `docs.honeydrunkstudios.com/errors/web-rest/{category}/`, plus `traceId` (W3C `traceparent`) and `correlationId` (per ADR-0045 `ErrorContext`).

**ADR-0057 D4 — Additive changes are non-breaking.** New optional response field (`ApiErrorResponse.Type`), new endpoints, new content-negotiated representations (RFC 7807 alongside existing `ApiErrorResponse`), and new optional Abstractions types (`CursorPageRequest`, `CursorPageResult`, `ProblemDetails`) are all non-breaking. The OpenAPI diff gate (packet 03) confirms.

**ADR-0057 D11 (reconciled with ADR-0067) — Rate-limit envelope.** IETF unprefixed `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset`. Web.Rest's middleware ships the response-decoration hook; the Kernel-side wiring (ADR-0067 packet 02) emits the headers via its own middleware when composed.

**ADR-0057 D14 — Cursor-based pagination.** Default `limit=50`, max `limit=200`. Cursor opacity, 24h server-side TTL, `410 Gone` per-D12 on expired cursor. Web.Rest ships the Abstractions primitives; the v1 spec documents the existing offset shape (frozen at v1 per the pilot's freeze rule); cursor is the v2-default convention.

**ADR-0057 D8 (referenced — deferral) — SDK languages.** No TypeScript / Swift / Kotlin SDK is published for Web.Rest; Web.Rest is a .NET-consumer library and falls under the C# .NET deferred-language reasoning.

**ADR-0035 D1 (referenced) — Additive minor bump.** `0.5.0` → `0.6.0` is a minor bump for the additive changes.

**Invariant 27 — One version across the solution.** Both non-test `.csproj` files at `0.6.0` in one commit.

**Invariant `{N1}` — Every public REST API has a checked-in OpenAPI 3.1 spec.** Web.Rest's spec lands here; this packet satisfies the invariant for Web.Rest.

## Constraints
- **Option C is pinned** — additive RFC 7807 alongside existing `ApiErrorResponse` via content negotiation; defaults to `ApiErrorResponse` for backwards compatibility. The other two options (sudden cutover; defer-to-v2) were rejected at refine time.
- **v1 freeze.** Any breaking change after this packet bumps to v2 per invariant `{N2}`. The freeze is enforced by the OpenAPI-diff gate.
- **Abstractions has no HoneyDrunk-runtime and no ASP.NET Core dependency.** `ProblemDetails` is Studios-defined; do NOT consume `Microsoft.AspNetCore.Mvc.ProblemDetails` in Abstractions.
- **No public SDK for Web.Rest.** Web.Rest is consumed by .NET callers via NuGet; the per-language SDK pipeline does not apply.
- **First-run OpenAPI diff is the no-prior-tag-no-prior-file case.** Packet 03's workflow handles this with an info-level pass.
- **Cloudflare Pages provisioning for `docs.web-rest.honeydrunkstudios.com` is deferred.** Dry-run docs deploy is acceptable for v1.
- **`Type` URI lookup for `ApiErrorCode`** — Web.Rest ships URIs for the codes it defines; consuming services that introduce new codes register URIs via an opt-in extension (defer the extension API to a future packet if needed; v1 covers the Web.Rest-defined codes).
- **The `IOperationContextAccessor` and `Activity.Current` integrations** are the existing Web.Rest mechanisms — no new contract.
- **No `Unreleased` CHANGELOG.**

## Labels
`feature`, `tier-2`, `core`, `adr-0057`, `wave-3`

## Agent Handoff

**Objective:** Pilot ADR-0057's Phase 1 substrate on `HoneyDrunk.Web.Rest`: reverse-engineer the OpenAPI 3.1 v1 spec; freeze the surface at v1; ship Option C envelope alignment (additive RFC 7807 alongside `ApiErrorResponse` via content negotiation); add cursor pagination primitives; add IETF `RateLimit-*` header hook; scaffold Docusaurus docs; wire the per-repo CI to call `job-openapi-diff.yml` and `job-publish-docs.yml`; bump to `0.6.0`.

**Target:** `HoneyDrunk.Web.Rest`, branch from `main`.

**Context:**
- Goal: Exercise the full ADR-0057 substrate on a low-risk surface before Notify's higher-stakes Phase 2 pilot.
- Feature: ADR-0057 rollout, Wave 3 (Phase 1 pilot).
- ADRs: ADR-0057 D17 Phase 1 / D7 / D12 / D4 / D11 / D14 / D8 (primary); ADR-0067 (rate-limit-header reconciliation); ADR-0035 D1 (additive minor bump); ADR-0040 (`Activity.Current` for traceId); ADR-0045 (`IOperationContextAccessor` for correlationId); ADR-0075 (Docusaurus narrative).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0057 Accepted; invariants `{N1}-{N4}` live.
- `packet:01` — tech-stack.md + `publicHttpApi` block convention.
- `packet:03` — `job-openapi-diff.yml` exists and is consumable.
- `packet:05` — `job-publish-docs.yml` exists and is consumable (dry-run for the first Web.Rest docs deploy until per-API Pages provisioning catches up).

**Constraints:**
- Option C pinned.
- v1 freeze enforced by the diff gate.
- Abstractions zero-runtime-dependency preserved.
- No public TS / Swift / Kotlin SDK.
- One version across both packages.
- No `Unreleased` CHANGELOG.
- Cloudflare Pages for Web.Rest docs is deferred (dry-run acceptable).

**Key Files:**
- `HoneyDrunk.Web.Rest/api/openapi-v1.yaml` (new)
- `HoneyDrunk.Web.Rest.Abstractions/Errors/ProblemDetails.cs` (new)
- `HoneyDrunk.Web.Rest.Abstractions/Errors/ApiErrorResponse.cs` (additive `Type` field)
- `HoneyDrunk.Web.Rest.Abstractions/Paging/CursorPageRequest.cs`, `CursorPageResult.cs` (new)
- `HoneyDrunk.Web.Rest.AspNetCore/Middleware/` (content negotiation + rate-limit hook)
- `HoneyDrunk.Web.Rest/docs/` (Docusaurus scaffold)
- `HoneyDrunk.Web.Rest/.github/workflows/` (per-repo wiring)
- Both `.csproj` files (version bump)
- CHANGELOGs + README + Canary updates

**Contracts:**
- `ProblemDetails` (new record).
- `CursorPageRequest`, `CursorPageResult` (new records).
- `ApiErrorResponse.Type` (new optional property).
- `UseRateLimitHeaders` (new middleware extension).
- `ApiResult`, `ApiErrorResponse`, `ApiError`, `ApiErrorCode`, `ValidationError`, `PageRequest`, `PageResult` (existing — preserved).
