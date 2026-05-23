# ADR-0057: Public HTTP API Versioning and Client SDK Strategy

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has a governed story for **server-to-server NuGet abstractions** (ADR-0035) — versioning, deprecation, and breaking-change discipline are codified for the `.Abstractions` packages that compose Nodes internally. The Grid does **not** yet have a governed story for **public HTTP APIs** consumed by external clients (browsers, mobile apps, third-party integrations, tenant-built integrations on Notify Cloud).

Today's state:

- **`HoneyDrunk.Web.Rest`** is Live at 0.5.0 with no public-API versioning policy. Its endpoints exist; there is no committed contract for how they evolve, how breaking changes are signaled, or how clients should pin to a major version.
- **`HoneyDrunk.Notify.Cloud`** (PDR-0002 / ADR-0027) ships a public REST API as its primary product surface. Tenants will integrate against it from third-party systems; "we changed the response shape" without a versioning policy is a credible-paying-customer-blocker. The GA blocker is real.
- **Consumer PDRs** — Lately (PDR-0003), Hearth (PDR-0005), Currents (PDR-0006), Curiosities (PDR-0008) — all imply public APIs that mobile clients consume. Mobile clients have **long version tails** (a user with v1.2 of an app installed two years ago is a real shape of the client population). Without a versioning policy, every mobile release re-litigates "can we change this field."
- **ADR-0003 (HoneyHub)** explicitly leaves GraphQL-vs-REST open for HoneyHub specifically and offers no general guidance. This ADR settles the general case (REST) and the narrow exception (HoneyHub keeps GraphQL).
- **Cross-Node consistency is absent.** Notify and Web.Rest both expose HTTP endpoints today with different error envelopes, different pagination shapes, different auth headers. New Nodes (AI sector standup wave, future Notify Cloud sub-APIs, future Billing per ADR-0037) will each re-invent the wheel unless this ADR commits the shared shape.
- **SDK generation is absent.** Tenants of Notify Cloud will want client libraries; mobile apps need typed clients; the demo/sample code on the docs site needs typed examples. Hand-writing SDKs per language per API is not a viable solo-operator workflow.

The forcing functions for deciding this now:

- **Notify Cloud GA** is the first commercial API consumer. Without this ADR, every breaking change to a Notify Cloud endpoint risks a tenant outage.
- **The AI-sector standup wave** (ADR-0016 through ADR-0025) introduces multiple Nodes whose long-term posture includes public surfaces (Capabilities-as-API for partner integrations, Knowledge query API for retrieval consumers, etc.). They need the public-API shape committed before they each invent one.
- **Mobile consumer apps** (PDRs 0003 / 0005 / 0006 / 0008) all have a real-world client-version tail. Without versioning policy, the first breaking change to the API breaks installed mobile clients.
- **Operator scale.** Studios is one developer + AI agents. The decision must optimize for **operational legibility** (debuggable, cacheable, browser-explorable) over theoretical elegance.
- **ADR-0035 is settled for the internal case.** This ADR is the external-facing companion; absent it, the Grid has half a versioning story.

This ADR commits the REST-as-default decision, the URL-path versioning scheme, the breaking-change taxonomy, the deprecation policy, the SDK languages and tooling, the auth schemes, the error/pagination/rate-limit envelopes, and the HoneyHub-specific carve-out for GraphQL schema evolution.

## Decision

### D1 — REST is the v1 default; GraphQL is the HoneyHub-only exception

All Grid public HTTP APIs default to **REST** with OpenAPI 3.1 specifications. **GraphQL is reserved exclusively for HoneyHub** (ADR-0003), where the graph query — "give me the relationships across these Grid entities" — is **the product itself**, not an implementation detail.

The reasoning:

- **REST + OpenAPI tooling maturity.** SDK generation (D8), contract testing (cross-ref ADR-0047 D4), documentation hosting (D15), and breaking-change CI gates (D7, cross-ref ADR-0011) all have mature, multi-language tooling. GraphQL's equivalent tooling is good but younger, more JavaScript-centric, and less aligned with the .NET-first Grid backend.
- **Operational legibility.** A REST URL is debuggable by `curl`, browseable, cacheable by upstream proxies, and routable by CDNs without inspecting the request body. GraphQL endpoints are opaque to all of that. For a solo-operator shop the debuggability premium is non-trivial.
- **Client-side complexity.** REST clients are simple HTTP. GraphQL clients want a query client library (Apollo, Relay, urql) with their own caching, normalization, and subscription stories. The complexity tax compounds across the four committed SDK languages (D8).
- **Studios team size.** A two-paradigm story (REST for tactical APIs, GraphQL for HoneyHub) is what one operator can sustain. A two-paradigm-per-Node story is not.
- **HoneyHub-as-narrow-exception preserves graph optionality** where it matters most. HoneyHub's product value **is** the cross-Node relationship query — a REST-shaped HoneyHub would force consumers to chain N requests to traverse the graph, defeating the purpose. GraphQL stays where it earns its keep; REST takes everywhere else.

Per-Node defaults: every public API except HoneyHub uses REST. The decision is not re-litigated per Node.

### D2 — Versioning scheme: URL path prefix

The committed scheme is **URL path prefix versioning** — `/v1/notify/send`, `/v2/notify/send`. The major version number lives in the URL path; minor and patch versions are not in the URL.

Alternatives explicitly rejected:

- **Header versioning** (`Accept: application/vnd.honeydrunk.notify.v2+json` or `X-API-Version: 2`). Harder to debug — the version is invisible in browser URL bars, in `curl` examples on the docs site, and in operator-facing logs. Breaks browser-based exploration of the API (operators copying URLs out of docs is a real workflow). Harder to cache because intermediate proxies often don't vary on custom headers without explicit configuration. Harder for CDN routing because path-based rules are the natural primitive; header-based rules are second-class on most CDNs.
- **Media-type versioning** (`Accept: application/vnd.honeydrunk.notify.v2+json`). Inherits all of header versioning's drawbacks plus client-side complexity: every client must remember to set the `Accept` header correctly, and forgetting it returns the default (oldest) version silently.
- **Query-parameter versioning** (`/notify/send?api-version=2`). Slightly better than headers for debuggability (visible in URL) but harder to cache (query string variation), and the convention conflicts with Azure's own pattern where `api-version` is the per-service-not-per-API convention. Rejected on convention-conflict grounds.

The trade-off accepted: URL-path versioning is the option many large API vendors (Stripe excepted, for historical reasons) converge on. Stripe's date-based versioning model is acknowledged as elegant but rejected as overkill for the Studios operational scale; URL-path is the most operationally legible option at the size the Grid actually is.

### D3 — Versioning granularity: major version per API surface, not per endpoint

A breaking change in **any** endpoint of a given API surface bumps the entire surface to the next major. The unit of versioning is the **API surface** (Notify, HoneyHub, future Billing, future Capabilities), not the individual endpoint.

So `Notify` v1 carries every Notify endpoint at every revision-level up to the first breaking change. The first breaking change anywhere in Notify creates `Notify` v2, which includes:

- All v1 endpoints in their v2 shape (changed endpoint may have actually changed; unchanged endpoints are forwarded with their existing shape).
- v1 stays live concurrently per D6 (the two-major coexistence window).

Why surface-level, not endpoint-level:

- **Client mental model.** A client picks "we target Notify v1" — one mental anchor. Endpoint-level versioning forces the client to track N independent endpoint versions, multiplied across N endpoints, multiplied across the SDK's lifetime. Solo-operator scale cannot maintain that.
- **SDK generation.** OpenAPI tooling generates per-spec (per-version-of-the-surface). Per-endpoint versioning would require N specs per surface and N SDKs per language per surface. Combinatorial explosion.
- **Documentation site.** One docs site per major version per surface is legible. Per-endpoint version banners on every page are not.

Multiple major versions of the same surface coexist live during the deprecation window (D5/D6). Minor and patch versions are not in the URL — they're spec revisions that ship via the additive-only "not breaking" rule in D4.

### D4 — Breaking change taxonomy

Canonical list, governed by the OpenAPI diff CI gate (D7):

**Breaking (requires major version bump):**

- Removed endpoint.
- Removed response field.
- Renamed field (request or response).
- Type narrowing of a field (e.g., `string` → `enum`; `int64` → `int32`).
- Semantic change in field meaning (the field name is the same, the value's interpretation is not).
- Removed enum value (a client that previously could receive this value will now never receive it; that's fine for forward-only clients but breaks clients that switch-exhaustively).
- Added **required** request field (a client that didn't send it before now fails).
- Changed error code mapping (a previously-`409`-returning condition now returns `422`; clients that switched on status code break).
- Changed authentication requirement (an endpoint that previously accepted API key now requires OAuth, or vice versa).
- Changed rate-limit envelope shape (clients that parse rate-limit headers break; the per-D11 envelope is committed and stable, so this is a guard against drift, not an expected event).
- Changed pagination scheme (cursor → offset or vice versa; per D14 cursor is the committed default).

**Not breaking (ships in spec revision, no major bump):**

- New optional request field.
- New response field.
- New endpoint.
- New optional query parameter.
- New enum value, **conditional on the documented client-side rule**: "Clients MUST ignore unknown enum values, treating them as unrecognized." This rule is documented at the top of every API's docs site and is part of the SDK templates (the generated SDK's deserialization is lenient on unknown enum values by default).
- Loosened type (e.g., `int32` → `int64`; required → optional on response).
- Looser validation on a request field (the field accepts more values than before; existing clients still produce valid requests).

The "new enum value is not breaking" rule is the one that depends on a client-side contract. The other "not breaking" cases are unconditional. The documentation site and the SDK README both call out the enum-value rule prominently.

### D5 — Deprecation policy

Deprecated endpoints (and deprecated entire major versions) emit:

- A **`Deprecation` header** per RFC 8594 — `Deprecation: @1735689600` (Unix timestamp of the deprecation announcement) on every response from a deprecated endpoint.
- A **`Sunset` header** per RFC 8594 — `Sunset: Sat, 31 Jan 2027 00:00:00 GMT` — the date the endpoint will stop responding. Sunset date is **at least 180 days in the future** at the moment deprecation is announced.
- A **`Link` header** with `rel="successor-version"` pointing at the v(N+1) equivalent endpoint, where one exists. (`Link: <https://api.honeydrunkstudios.com/v2/notify/send>; rel="successor-version"`)

The **minimum lifecycle** for a deprecated endpoint is **6 months** between deprecation announcement and sunset. The 180-day window is a hard floor; longer windows are permitted and expected for high-traffic endpoints or for Notify Cloud endpoints where tenant integrations need migration runway.

**Active-tenant notification.** Tenants whose API keys made requests to the deprecated endpoint within the most recent 30 days at the moment of the deprecation announcement receive Notify-delivered email at:

- **T-90 days** before sunset — "We are sunsetting this endpoint."
- **T-30 days** before sunset — "Sunset is in 30 days. Migration guide: ..."
- **T-7 days** before sunset — "Sunset is in 7 days. Your traffic on this endpoint: N requests/day."

The emails route through `HoneyDrunk.Communications` (decision/orchestration) and `HoneyDrunk.Notify` (intake/delivery) per ADR-0019. The deprecation-notification flow is a named feature flow per `constitution/feature-flow-catalog.md`.

**Audit.** Every deprecation announcement, every tenant notification, and every post-sunset rejected request are audited via `HoneyDrunk.Audit` per ADR-0030. Sunset compliance is reviewable after the fact.

### D6 — Coexistence window: at most two major versions

For any given API surface, **at most two major versions** are live concurrently. The state machine:

- **Steady state:** v(N) is GA, no other versions live.
- **v(N+1) released GA:** v(N) becomes "deprecated" and enters its 180-day sunset clock. v(N+1) and v(N) are both live; v(N-1) (if it existed) has already been sunsetted.
- **v(N) sunsetted:** v(N+1) is the only live version. Steady state again.

**Why two, not three:** Studios is too small to maintain three majors in parallel. Three majors means three OpenAPI specs to keep current, three SDK generations to publish, three docs site versions to maintain, three sets of integration tests, three deprecation timelines to communicate. The operator-attention cost is super-linear. Two is the maximum that one developer + AI agents can credibly run.

**Implication for major-version cadence.** A new major version cannot be released until the previous v(N-1) has already been sunsetted. In the limit this caps the major-version frequency at roughly **one major per surface per ~6 months** — the floor set by D5's sunset window. This is a feature, not a bug: it disciplines API design at the moment of v(N+1) planning by forcing the question "is this breaking change urgent enough to start the 6-month meter?"

**Exception:** Pre-GA major versions (e.g., a Notify Cloud beta where the API is explicitly labeled unstable) are not bound by D6 until they reach GA. The two-version rule applies to GA-and-later only.

### D7 — OpenAPI 3.1 as the source of truth

Every public REST API has a checked-in OpenAPI 3.1 specification at:

```
repos/{node}/api/openapi-v{n}.yaml
```

So `HoneyDrunk.Notify` carries `repos/HoneyDrunk.Notify/api/openapi-v1.yaml` and (when it exists) `openapi-v2.yaml`. The spec is the **load-bearing artifact** — everything else generates from it:

- **Client SDK generation (D8)** — OpenAPI Generator consumes the spec; out comes the per-language SDK.
- **Documentation site (D15)** — the docs site generates from the same spec, ensuring docs and behavior stay coupled.
- **Contract tests (cross-ref ADR-0047 D4)** — server-side contract tests assert that the running API matches the spec; client-side contract tests assert that the SDK consumes the spec's shape. Both fail loudly on drift.
- **Breaking-change CI gate (cross-ref ADR-0011 / ADR-0032)** — every PR that modifies an `openapi-v*.yaml` runs an OpenAPI diff (tooling: `oasdiff` or equivalent) against the last released spec. A diff classified as "breaking" per D4's taxonomy **fails the build** unless the spec being modified is for a new (unreleased) major version. The reviewer cannot land a breaking change to a released spec without bumping the major.
- **Server scaffolding** (optional, per-Node) — some Nodes generate their server-side controllers from the spec (spec-first); others write controllers by hand and validate them against the spec via integration tests (code-first with spec validation). Either pattern is acceptable; the spec is the source of truth either way.

OpenAPI 3.1 (not 3.0) because 3.1 has full JSON Schema alignment, which matters for the SDK generators consuming the spec — JSON Schema is the lingua franca for typed-shape generation. The version-specific note is to prevent silent regression to 3.0 by tooling that defaults old.

### D8 — Client SDK strategy: generate from OpenAPI for three languages at v1

Studios publishes SDKs for **three languages** at v1, generated from the OpenAPI specs (D7):

| Language | Package coordinates | Target consumers |
|----------|---------------------|------------------|
| **TypeScript** | `@honeydrunk/{api}-sdk` on npm | Web (browser), Node.js services, React Native mobile clients |
| **Swift** | `HoneyDrunk{Api}Sdk` Swift Package | iOS native apps |
| **Kotlin** | `com.honeydrunkstudios:{api}-sdk` on Maven Central | Android native apps, JVM service consumers |

So for Notify v1:

- `@honeydrunk/notify-sdk` on npm.
- `HoneyDrunkNotifySdk` Swift Package.
- `com.honeydrunkstudios:notify-sdk` on Maven Central.

**Why these three:** TypeScript covers web and React Native (a credible mobile route per the pending mobile-platform ADR). Swift covers iOS native. Kotlin covers Android native and any JVM-server-side consumer. The combination spans every realistic consumer category the consumer PDRs imply without committing to N additional language SDKs that may sit unused.

**Languages explicitly deferred:**

- **C# .NET** — Grid internals use `HoneyDrunk.{Node}.Client` packages (per ADR-0035 internal abstractions), not the public SDKs. External .NET consumers exist in theory; their volume is presumed low enough to defer until first request.
- **Python** — high-demand for ML/data integrations; deferred until a concrete consumer requests it. OpenAPI Generator's Python templates are mature; adding it is cheap when needed.
- **Go, Ruby, PHP** — deferred indefinitely. Generate on request.

**Tooling:** **OpenAPI Generator** with Studios-maintained templates. Default OpenAPI Generator templates are acceptable v1 starting points; where defaults are insufficient (idiomatic naming, ergonomic builders, lenient enum deserialization per D4), Studios maintains override templates in `HoneyDrunk.Actions/openapi-templates/{language}/`.

**Publication automation:** Each API surface's repo carries a reusable workflow (in HoneyDrunk.Actions per ADR-0012) that on a tag matching `notify-api-v1.2.3`:

1. Validates the OpenAPI spec.
2. Runs the breaking-change diff vs the last released spec (D7).
3. Generates SDKs for all three languages.
4. Publishes each SDK to its registry with the version per D9.
5. Regenerates the docs site (D15).

The publish path is a single reusable workflow, not a per-language one-off. Aligns with ADR-0012's control-plane invariant.

### D9 — SDK versioning

SDK version tracks the spec version it was generated from plus a build counter:

```
SDK version = v{API-major}.{spec-revision}.{sdk-patch}
```

So:

- `v1.0.0` of the SDK = first release of the SDK targeting API v1 at spec revision 0.
- `v1.0.3` = third SDK-side patch (bug fix in the generator templates, e.g.) targeting API v1, spec revision 0.
- `v1.1.0` = SDK targeting API v1 with new endpoints/fields added (spec revision bumped by an additive change per D4).
- `v2.0.0` = SDK targeting API v2 (a new major); shipped alongside the API v2 release.

The SDK's major version is **always** the API's major version. SDK minor version tracks additive spec revisions. SDK patch is for SDK-internal fixes that don't reflect a spec change.

**Implication:** when API v2 ships, the SDK gets v2.0.0; the previous SDK line (`@honeydrunk/notify-sdk@1.x`) stays available on npm/Maven/SPM for the entire 180-day v1 sunset window. Clients pinned to `^1.0.0` continue to receive v1.x patches; clients ready to migrate move to `^2.0.0` explicitly.

**Multi-major coexistence in package registries.** Both major SDK lines stay published indefinitely (post-sunset, the older line is marked deprecated in the registry but not unpublished — unpublish breaks any frozen consumer build).

### D10 — Authentication: API key or OAuth 2.1 with PKCE

Per public API, the auth scheme is one of:

- **API key** for machine-to-machine flows. Per-tenant rotation per ADR-0006. Passed as `Authorization: Bearer {key}` header (not in URL query, never).
- **OAuth 2.1 with PKCE** for user-facing apps (the consumer PDRs' mobile clients fall here when they authenticate as an end-user rather than as the app's service account).

**Explicitly rejected:**

- **HTTP Basic auth.** Plaintext credentials in headers, no per-request rotation, no scoping. Even over TLS, the operational hygiene is poor and the SDK story is awkward.
- **Custom signed-header schemes** (HMAC-SHA256-of-canonical-request style). AWS does this and the implementation cost on every SDK side is meaningful — the request-canonicalization spec is famously fiddly and a frequent source of integration bugs. Adoption barrier on third-party clients is real. The security benefit over Bearer-API-key-over-TLS is marginal when tenant key rotation per ADR-0006 is already governed. Reconsidered if a specific high-value compliance scenario requires it.
- **Long-lived JWTs as the primary credential.** JWTs are fine as session tokens within an OAuth flow; they are not the primary credential. (A JWT is what an OAuth flow issues; the credential is the OAuth client.)

Per-endpoint auth requirement is declared in the OpenAPI spec via `securitySchemes`. The auth scheme for a given endpoint is not changeable without a major version bump per D4.

Cross-ref ADR-0006 (config & secrets strategy) for the per-tenant key storage and rotation flow.

### D11 — Rate-limit envelope

Standardized response headers on every endpoint, every response:

- **`X-RateLimit-Limit`** — the limit value for the current window (e.g., `1000`).
- **`X-RateLimit-Remaining`** — remaining requests in the current window (e.g., `847`).
- **`X-RateLimit-Reset`** — Unix timestamp at which the current window resets (e.g., `1735689600`).

On a `429 Too Many Requests` response:

- The above three headers are still present.
- A **`Retry-After`** header (RFC 7231) with the seconds-to-retry value (e.g., `Retry-After: 30`).

Headers follow the IETF draft (`draft-ietf-httpapi-ratelimit-headers`) close enough to be familiar to developers who've integrated with GitHub, Stripe, or Twitter; we use the `X-` prefix because the draft hasn't standardized at time of writing and the `X-` prefix is the de-facto compatibility shape.

**Scoping.** Rate limits are **per-tenant and per-API-key**. A single tenant with two API keys gets two independent rate-limit buckets. This lets a tenant separate "production traffic" from "ad-hoc scripts" without one starving the other.

**Limits per API are declared in the OpenAPI spec's `info.x-rate-limits` extension** so they're visible in generated SDKs and docs. Per-endpoint overrides are declared on the operation. Changing a rate-limit value downward (more restrictive) without a major version bump is a **breaking change** per D4; changing it upward (more permissive) is not breaking.

### D12 — Error envelope: RFC 7807 Problem Details

Standardized JSON shape for every non-2xx response, per **RFC 7807 (`application/problem+json`)** with Studios extensions:

```json
{
  "type": "https://errors.honeydrunkstudios.com/notify/recipient-not-found",
  "title": "Recipient not found",
  "status": 404,
  "detail": "No recipient exists for tenant 'tnt_abc123' with id 'rcp_def456'.",
  "instance": "/v1/notify/recipients/rcp_def456",
  "traceId": "00-7651cbab2bd2d5b2f8a9e07e6d5d6a0e-3c1d8c9b3b4d5e6f-01",
  "correlationId": "corr_2026_05_22_a7f3"
}
```

Fields:

- `type` — a URL identifying the error category (resolvable to a docs page).
- `title` — short human-readable summary; stable across instances of the same error type.
- `status` — HTTP status code, redundant with the response code but per RFC 7807.
- `detail` — instance-specific human-readable detail. May vary per occurrence.
- `instance` — the URI of the specific request that produced the error.
- `traceId` — the W3C Trace Context `traceparent` value (cross-ref ADR-0040 — the App Insights `operation_id`). Lets a tenant report an error with the `traceId` and Studios can look it up in App Insights immediately.
- `correlationId` — the per-request correlation ID per ADR-0045's `ErrorContext`. Lets a tenant cross-reference a single error event in their own logs with the Grid's error tracking.

The trace/correlation linkage is **the load-bearing piece** for tenant-driven incident triage: a tenant pastes their `traceId` into a support request and Studios immediately has the full distributed trace + error event in App Insights and the structured error in App Insights Failures. Cross-ref ADR-0040 (Azure Monitor + App Insights) and ADR-0045 (error tracking, `IErrorReporter`).

Per-API error type catalog lives at `errors.honeydrunkstudios.com/{api}/` and is generated from the OpenAPI spec's `components.responses` declarations. Adding a new error `type` (with a new docs page) is non-breaking; renaming or removing an error `type` is breaking per D4.

### D13 — Idempotency on writes

Per ADR-0042, public `POST`, `PUT`, and `PATCH` endpoints accept an **`Idempotency-Key`** request header. Server-side dedup is governed by ADR-0042's `IIdempotencyStore` contract — the same machinery that handles internal Grid idempotency.

**Required vs recommended:**

- **Required** for billing-relevant endpoints — anything that costs the tenant money (Notify Cloud send endpoints once metered billing per ADR-0037 lands; future Billing-API endpoints). A request without `Idempotency-Key` to a required endpoint returns `400 Bad Request` with a per-D12 problem-details envelope citing `type: "https://errors.honeydrunkstudios.com/common/idempotency-key-required"`.
- **Recommended** elsewhere. A request without the header is accepted; the docs site and SDK README call out the loss of safety.

SDK implementations (D8) auto-generate an `Idempotency-Key` (a UUID v7) for every write request by default; the SDK consumer can override per-call. This means the "recommended" cases are de-facto "required for any consumer using the SDK," which is the desired posture.

Idempotency window (how long the dedup-store retains a key) is **24 hours**, matching ADR-0042 D3. Documented per-API.

### D14 — Pagination: cursor-based

All list endpoints use **cursor-based pagination**:

- Request: `GET /v1/notify/messages?cursor={opaque}&limit={N}`
- Response body: `{ "items": [...], "next_cursor": "{opaque}" | null }`
- Response header: `Link: <https://api...?cursor=...&limit=...>; rel="next"` (RFC 8288).

**Rationale (rejecting offset-based):**

- **Consistency under concurrent writes.** Offset-based pagination (`?offset=100&limit=20`) is incorrect when items are inserted into the list between requests — the client sees duplicates, gaps, or both. Cursor-based pagination encodes "where you were" in a way that's stable against insertions.
- **Performance at scale.** Database offset queries degrade linearly with offset; cursor queries are constant-time (with appropriate indexing). At any tenant scale where pagination matters operationally, cursor wins.
- **Cleaner client paging-forward UX.** Mobile and web clients almost always paginate forward (infinite-scroll, "load more"). Cursor pagination is the natural shape for that; the cursor lives in the client's "last known" state. Offset pagination requires the client to track its own counter.

**Trade-off acknowledged:** cursor pagination makes "jump to page N" impossible (no client knows what `cursor` to send for page 47 without traversing). For the realistic Grid use cases (audit logs, message history, recipient lists), jump-to-page-N is not a common workflow. If a specific future API needs it, that endpoint can document an offset-based supplemental query parameter; cursor stays the default.

**Cursor opacity.** Cursors are opaque base64-encoded strings; clients MUST NOT parse or interpret them. The server is free to change cursor encoding without a major bump as long as previously-issued cursors remain decodable for the deprecation window of the previous encoding.

**Cursor TTL.** Server-side cursor state is retained for at minimum 24 hours from issuance. A client that holds a cursor longer and resumes against it may receive a `410 Gone` per-D12 problem-details envelope citing `type: "https://errors.honeydrunkstudios.com/common/cursor-expired"`. Documented per-API; mobile clients with intermittent connectivity are explicitly called out as the population most affected by the TTL and are guided in the docs to restart pagination from `cursor=null` on a `410 Gone`.

**Default and maximum `limit`.** The default `limit` per list endpoint is 50 and the maximum is 200. Per-endpoint overrides are declared in the OpenAPI spec. Tightening the maximum is breaking per D4 (an existing client passing `limit=500` would now fail); loosening it is not.

### D15 — Documentation hosting

Public API docs hosted at:

```
docs.{api}.honeydrunkstudios.com
```

So Notify's docs live at `docs.notify.honeydrunkstudios.com`; future Billing API docs at `docs.billing.honeydrunkstudios.com`; HoneyHub at `docs.honeyhub.honeydrunkstudios.com` (despite being GraphQL — the docs convention is uniform).

**Generation.** Docs are generated from the same OpenAPI spec (D7) at release time using a tool from the OpenAPI ecosystem (initial choice: **Redocly** for static site generation; reconsidered if a richer interactive experience is needed — Scalar and Stoplight are alternatives). The docs site for each major version is deployed to a path prefix (`docs.notify.honeydrunkstudios.com/v1/`, `/v2/`) with a version switcher in the navigation.

**Cross-ref Studios sector.** The docs subdomains are managed under the Studios sector (per ADR-0029's marketing/docs surface ownership). Each new API surface that ships requires a Studios-side packet to provision the docs subdomain.

**Versions retained.** Both live major versions (per D6) have published docs. The post-sunset older major's docs are archived to `docs.notify.honeydrunkstudios.com/archive/v1/` for ~12 months past sunset, then removed. Archived docs carry a banner stating the version is sunsetted.

### D16 — HoneyHub uses GraphQL schema evolution, not URL-prefix versioning

Per D1's exception, HoneyHub's GraphQL API uses **schema evolution**, not major-version URL prefixes:

- **Additive-only on the live schema.** New types, new fields, new query/mutation/subscription operations can be added at any time. They're not breaking.
- **Breaking changes go through per-field deprecation** via GraphQL's native `@deprecated` directive: `myField: String @deprecated(reason: "Use newField instead. Sunset 2027-01-31.")`. The directive carries the sunset date in the reason string.
- **Minimum 180-day deprecation window per field**, matching D5's REST rule. Tenant-notification flow per D5 also applies — HoneyHub tenants making queries that select deprecated fields receive the T-90/T-30/T-7 emails.
- **No `/v2` for HoneyHub.** The URL `/graphql` is stable; the schema evolves underneath. Clients that select only non-deprecated fields keep working indefinitely.

**Why this is the right shape for HoneyHub specifically:** GraphQL's whole-schema versioning has been considered an anti-pattern by the GraphQL community since ~2018 — the per-field deprecation model is GraphQL-native and respects the client's "I only asked for these fields" property. Forcing GraphQL into URL-version-prefix discipline would discard the language's built-in evolution story.

**HoneyHub schema is checked in** at `repos/HoneyHub/api/schema.graphql` as the source of truth (analogous to the OpenAPI spec for REST surfaces per D7). Breaking-change CI gate runs `graphql-inspector` (or equivalent) on every PR that modifies the schema.

### D17 — Phased rollout

- **Phase 1 (Week 1–3)** — **Foundations.** Author the OpenAPI spec template at `repos/{node}/api/openapi-v1.yaml.template`. Author the breaking-change CI gate (`job-openapi-diff.yml` in HoneyDrunk.Actions per ADR-0012). Author the reusable SDK-generation workflow (`job-publish-public-sdk.yml`) for the three target languages. Author the docs-generation workflow (`job-publish-docs.yml`). Pilot all of this on a low-risk surface — likely `HoneyDrunk.Web.Rest` v1 (already Live; the spec is reverse-engineered from the existing endpoints and the version freezes at v1).
- **Phase 2 (Week 4–6)** — **Notify v1 spec, SDKs, docs.** `HoneyDrunk.Notify`'s existing endpoints get an OpenAPI v1 spec checked in. SDKs published to all three registries. Docs site live at `docs.notify.honeydrunkstudios.com/v1/`. This is the dry run for Notify Cloud GA.
- **Phase 3 (Week 6–10)** — **Notify Cloud GA blocker resolution.** Notify Cloud's public API (per PDR-0002 / ADR-0027) ships with the full stack from day one: OpenAPI v1 spec, three SDKs published, docs site, RFC 7807 errors, cursor pagination, per-tenant rate limits, idempotency keys required on billing endpoints. Notify Cloud GA cannot ship without this Phase complete.
- **Phase 4 (Month 3+)** — **HoneyHub GraphQL schema** committed (`repos/HoneyHub/api/schema.graphql`); breaking-change CI gate; docs site at `docs.honeyhub.honeydrunkstudios.com`. Aligned with HoneyHub's Phase 2 timeline per ADR-0003.
- **Phase 5 (AI-sector standup wave)** — Every AI Node that exposes a public API (Capabilities-as-API, Knowledge query API, etc.) inherits the Phase 1 substrate at standup. Each standup ADR's canary includes the public API surface where applicable.
- **Phase 6 (Future Billing API per ADR-0037)** — Billing API is the first surface where every D4-required ("required on billing endpoints") rule is materialized. Idempotency keys required, per-tenant rate limits enforced, full audit trail.

Each phase is a discrete go/no-go.

## Consequences

### Affected Nodes

- **HoneyDrunk.Web.Rest** — Primary near-term affected Node. Endpoint set freezes at v1; OpenAPI spec checked in; SDKs published; docs site live. Future breaking changes go via v2.
- **HoneyDrunk.Notify** — Phase 2 wires the full stack. The deprecation-notification flow (D5) routes through Notify itself for the tenant emails; Notify is both subject (its own endpoints versioned) and infrastructure (delivery of deprecation notices for any API).
- **HoneyDrunk.Notify.Cloud** — Phase 3 GA blocker resolution. Full stack from day one.
- **HoneyDrunk.Communications** — Owns the deprecation-notification orchestration per ADR-0019 (decision/orchestration vs Notify intake/delivery).
- **HoneyHub** — Phase 4. GraphQL schema as source of truth; per-field deprecation; docs subdomain.
- **HoneyDrunk.Actions** — Gains five new reusable workflows: `job-openapi-diff.yml`, `job-publish-public-sdk.yml` (parameterized per language), `job-publish-docs.yml`, `job-graphql-inspector.yml`, `job-publish-graphql-docs.yml`. Hosts the `openapi-templates/{language}/` template overrides.
- **HoneyDrunk.Audit** — Receives deprecation announcements, tenant notifications, and post-sunset rejected requests per ADR-0030's audit substrate.
- **HoneyDrunk.Observe / Azure Monitor + App Insights** — RFC 7807 envelopes carry `traceId` and `correlationId` that link directly to App Insights traces (per ADR-0040) and `IErrorReporter` events (per ADR-0045). Cross-ref load-bearing for tenant incident triage.
- **HoneyDrunk.Kernel** — `IIdempotencyStore` (per ADR-0042) is the dedup substrate for D13. Already on the roadmap; this ADR cites it.
- **HoneyDrunk.Studios** — Owns the `docs.*.honeydrunkstudios.com` subdomains. New API surface = Studios-side packet to provision DNS and hosting.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` gains `publicHttpApi` entries per Node listing the surface name, current major version, OpenAPI spec path, and published SDK coordinates. `constitution/feature-flow-catalog.md` gains the deprecation-notification flow.
- **AI-sector Seed Nodes (ADR-0016 through ADR-0025)** — On standup, any Node that ships a public HTTP surface inherits the substrate from Phase 1. The substrate is in place before the first AI-sector public API exists.
- **Future HoneyDrunk.Billing (per ADR-0037)** — Designed against this ADR from day one. All "required on billing endpoints" rules are materialized at standup.

### Invariants

Adds three:

- **Invariant: every public HTTP REST API has a checked-in OpenAPI 3.1 spec at `repos/{node}/api/openapi-v{n}.yaml` as the source of truth.** Missing or out-of-sync spec is a CI gate failure per the OpenAPI-diff workflow.
- **Invariant: breaking changes (per D4 taxonomy) to a released public-API surface require a major version bump.** Enforced by the OpenAPI-diff CI gate (Phase 1).
- **Invariant: at most two major versions of a given public-API surface are live concurrently** (per D6). New major release forces the older surviving major into the 180-day sunset clock.

Plus one HoneyHub-scoped variant:

- **Invariant: HoneyHub uses schema evolution (additive + `@deprecated`), not URL-prefix versioning.** Enforced by the `graphql-inspector` CI gate (Phase 4).

(Final invariant numbers assigned at constitution update time; `hive-sync` reconciles.)

### Operational Consequences

- **OpenAPI spec authoring becomes a per-Node responsibility** for any Node with a public surface. The spec is non-trivially-sized for non-trivial APIs; the per-Node owner pays the authoring cost once and the diff-gate cost continuously.
- **SDK publication adds three registry relationships.** npm (TypeScript), Swift Package Index / GitHub-hosted SPM (Swift), Maven Central (Kotlin). Each has its own authentication, signing, and release-cadence concerns. The HoneyDrunk.Actions reusable workflow centralizes the credentials and the process; per-API consumers don't re-litigate.
- **Maven Central onboarding is the highest one-time cost** — namespace verification, GPG key registration, OSSRH (now Central Portal) onboarding. Done once for `com.honeydrunkstudios`; reused for all future Kotlin SDKs.
- **Docs subdomain proliferation.** Every API surface gets a docs subdomain. Phase 1 sets up the pattern; subsequent surfaces follow it. Acceptable proliferation; the cost is per-API DNS records and Studios-side hosting wiring.
- **Tenant-notification flow on deprecation is a real recurring obligation.** Every deprecation announcement triggers the 90/30/7-day cadence. The flow is automated (Notify orchestration); manual operator review per deprecation is the audit cost.
- **Coexistence-window discipline forces real API-design care.** The "you cannot release v3 until v1 is sunsetted" constraint (D6) is the most operationally significant rule — it makes "let's just bump major" cheap-feeling decisions explicitly costly. This is the intended discipline.
- **The breaking-change CI gate is the load-bearing enforcement.** Without it, the D4 taxonomy is aspirational. Phase 1 commits the gate; if the tooling (`oasdiff` etc.) produces false positives that block legitimate non-breaking changes, the gate's classification rules are tuned per the D4 taxonomy.
- **SDK auto-generation has known limitations.** Generated SDKs are functional but not ergonomic in idiomatic-language ways. The "auto-generated SDKs only" stance is the v1 default; hand-tuned wrappers are deferred per the alternatives section. If a specific SDK's ergonomics become a tenant adoption blocker, that SDK gets a per-language hand-tuned wrapper layer on top of the generated client — but only on evidence, not speculation.
- **GraphQL schema evolution discipline at HoneyHub** is a learned skill. Per-field `@deprecated` with sunset dates in the reason string requires reviewer attention; the `graphql-inspector` gate catches outright removals but not slow drift in deprecation hygiene. Cross-ref the `review` agent's PR checklist (per ADR-0044).

### Follow-up Work

- Author `job-openapi-diff.yml` in HoneyDrunk.Actions (Phase 1).
- Author `job-publish-public-sdk.yml` parameterized for TypeScript / Swift / Kotlin (Phase 1).
- Author `job-publish-docs.yml` using Redocly (or chosen alternative) (Phase 1).
- Author `job-graphql-inspector.yml` and `job-publish-graphql-docs.yml` (Phase 4).
- Onboard `com.honeydrunkstudios` namespace at Maven Central; register GPG keys for SDK signing (Phase 1).
- Establish `@honeydrunk` npm scope ownership (Phase 1).
- Reverse-engineer OpenAPI v1 spec for `HoneyDrunk.Web.Rest` from its existing endpoints; freeze the surface at v1 (Phase 1).
- Author OpenAPI v1 spec for `HoneyDrunk.Notify` (Phase 2).
- Provision `docs.notify.honeydrunkstudios.com` and `docs.honeyhub.honeydrunkstudios.com` via Studios-sector DNS packets (Phases 2 and 4).
- Add `publicHttpApi` field to `catalogs/contracts.json` schema; populate per affected Node.
- Add the deprecation-notification flow to `constitution/feature-flow-catalog.md`.
- Update `constitution/invariants.md` with the three (or four) new invariants.
- Update `.claude/agents/review.md` per ADR-0044 — new PR-review checklist items for: "OpenAPI spec updated if endpoints changed," "breaking-change CI gate green," "if breaking, major version bumped," "if HoneyHub, no removed fields without @deprecated + sunset date."
- Document the docs-subdomain provisioning playbook in `repos/HoneyDrunk.Studios/` (or equivalent).
- Author per-API migration guides (template) for when v(N+1) ships; the template lives in the docs-generation tooling.
- Coordinate with PDR-0002 (Notify Cloud GA) to confirm Phase 3 timeline alignment.

## Alternatives Considered

### Header versioning (`X-API-Version: 2` or `Accept: application/vnd.honeydrunk.v2+json`)

Considered. The argument for: keeps URLs "clean" (the path describes the resource, not the version); aligns with HATEOAS purist principles; the GitHub v3 API used media-type versioning historically. Rejected on operational legibility per D2. URL-path versioning is what a tired operator at 2am can actually debug.

### Query-parameter versioning (`?api-version=2`)

Considered. Visible in URL (good for debuggability) and trivially set per request (good for ad-hoc exploration). Rejected because (a) it conflicts with Azure's own `api-version` query-param convention which is per-service not per-API, leading to operator confusion; (b) cache keys typically vary on path but not on query string by default, requiring CDN tuning; (c) the path-vs-query split for "what version" is conceptually less crisp than "version is part of the URL hierarchy."

### Date-based versioning (Stripe style: `Stripe-Version: 2024-04-10`)

Considered. Elegant for high-cadence iteration; Stripe famously runs this with great success. Rejected as overkill at Studios operational scale. Stripe has the engineering capacity to maintain N "API versions" forever; Studios has one operator. The two-version coexistence rule (D6) is the operationally-feasible analog.

### No versioning, just deprecate-forever

Considered. The argument: every change is either backwards-compatible (additive) or done via documented deprecation; major version bumps are unnecessary ceremony. Rejected because the "all changes can be made additively" claim is empirically false — sooner or later a field needs to be renamed, a type narrowed, or a semantic changed in a way no additive workaround can express cleanly. Pretending otherwise produces an API that grows accreted vestigial fields forever ("`recipient_id` deprecated, use `recipientId`, deprecated, use `recipient`, deprecated, use ..."), each version of which has to be supported in perpetuity because no "breaking" event ever clears them. The major-version bump is the moment-of-cleanup that prevents that accretion.

### GraphQL everywhere

Considered. Strong query expressiveness, single endpoint, evolution-by-deprecation rather than version-by-prefix. Rejected per D1's reasoning: tooling maturity, operational legibility, SDK story across four languages, and Studios team size. GraphQL stays where it earns its keep (HoneyHub); REST takes elsewhere.

### REST everywhere (including HoneyHub)

Considered. The unification argument: one paradigm, one tooling chain, one SDK generation path. Rejected because HoneyHub's product **is** the graph query. A REST-shaped HoneyHub would require consumers to chain N requests to walk the graph, which is exactly the inefficiency GraphQL was invented to solve. The two-paradigm cost is real but worth it for HoneyHub specifically; the alternative is making HoneyHub a worse product.

### gRPC for public APIs

Considered. Excellent for low-latency, high-throughput, polyglot internal service-to-service. Rejected for public APIs because (a) browser support requires gRPC-Web with a translation proxy, adding moving parts; (b) third-party tenant developers expect REST/JSON, not protobuf; (c) the debuggability story (no `curl`-and-paste; binary wire format) hurts solo-operator support workflows. gRPC remains available for internal Grid Node-to-Node where the rationale flips, but is not the public-API default.

### Use ASP.NET API Versioning library defaults (multi-scheme support)

Considered. Microsoft.AspNetCore.Mvc.Versioning supports header, query, and URL versioning simultaneously by default. The "let the library handle multiple schemes" approach is tempting. Rejected because supporting multiple schemes simultaneously means tenants discover schemes that work and the documented scheme becomes "one of N options" — defeating the discipline. Pick one (D2: URL path), configure the library to that one, reject requests using the others.

### Per-endpoint independent versioning

Considered. Theoretically the most granular and "honest" — each endpoint evolves at its own pace. Rejected per D3 on SDK-generation explosion, docs-site complexity, and client mental model. Surface-level granularity is the workable trade-off.

### Three or more major versions live concurrently

Considered. More client migration runway; less pressure on tenants to upgrade. Rejected per D6: Studios operator-attention cost is super-linear in the number of live majors. Two is the maximum that is sustainable; tenants get 180 days of runway, which is the realistic floor for an enterprise migration project but not infinite.

### Hand-write SDKs per language per API

Considered. Hand-written SDKs are more idiomatic, more ergonomic, and can carry helper abstractions the generator can't express. Rejected as v1 default per D8: the multiplicative cost (3 languages × N APIs × N major versions) is prohibitive for a solo operator. Generator-from-OpenAPI is the v1 default; hand-tuned wrapper layers are an evidence-driven escalation per the "Operational Consequences" section.

### Skip the breaking-change CI gate; rely on PR review

Considered. PR review is already governed by ADR-0044 (review agent + specialist reviewers). The argument: another reviewer step ought to catch breaking changes. Rejected because (a) the OpenAPI-diff gate is the cheapest, most reliable detection — a reviewer can miss a subtle field-type narrowing where `oasdiff` cannot; (b) the gate produces a machine-readable artifact (the diff itself) that documents exactly what changed, useful in PR review independent of catch/no-catch.

### Use Sentry-style API key alone (no OAuth)

Considered. Sentry, Stripe, and several others use API key as the only auth scheme. Simpler SDK story. Rejected for the user-facing-app case per D10: a mobile app authenticating its end-user needs OAuth (PKCE) for the standard "user logs in, app gets a scoped token" flow. API key alone forces either embedded secrets in the client (security disaster) or per-user API keys (operational disaster). Both auth schemes are real; D10 commits both.

### Use protobuf-style "field number reuse forbidden" rule instead of JSON breaking-change list

Considered. Protobuf's discipline (never reuse a field number, never change a field's type, never rename) is rigorous and machine-enforceable. Rejected because JSON has no equivalent "field number"; renaming a JSON field is the human-facing operation that needs governance. D4's taxonomy is the JSON-shape analog of protobuf's rules.

### Defer SDK publication until first tenant requests it

Considered. Saves the upfront cost of registry onboarding, signing, etc. Rejected because (a) the substrate (HoneyDrunk.Actions reusable workflows, Maven namespace, etc.) is built once and reused for all future APIs — deferring it just defers when the cost is paid; (b) Notify Cloud GA needs SDKs at launch, not on-request — tenants integrating against Notify Cloud expect typed clients on day one; (c) the "build the tooling reactively per tenant request" pattern is the exact operational fragility this ADR is designed to prevent.

### Adopt OpenAPI 3.0, not 3.1

Considered. 3.0 has wider tooling support; 3.1 is newer. Rejected because 3.1's JSON Schema alignment is the load-bearing technical property for SDK generation — generators that target JSON Schema typings produce better idiomatic output than generators using 3.0's almost-but-not-quite-JSON-Schema dialect. The narrow tooling gap is closing rapidly; betting on 3.1 is the forward-looking choice.

### Allow per-Node OpenAPI tooling choices

Considered. Let each Node pick its preferred OpenAPI generator, docs renderer, diff tool. Rejected as the same per-Node-drift anti-pattern this ADR is designed to prevent. Grid-wide commitment to OpenAPI Generator + Redocly + `oasdiff` (or named alternatives) means the HoneyDrunk.Actions reusable workflows handle everything; per-Node configuration is minimized.

### Defer until the second commercial API exists to validate cross-API patterns

Rejected. Notify Cloud is the first commercial API and its GA is imminent. Shipping Notify Cloud without this ADR commits the Grid to whatever shape Notify Cloud invents ad-hoc, which then constrains every future API to either match Notify Cloud's shape or be inconsistent. Better to ship the policy before the first commercial API freezes the de-facto answer.

### Webhook-style outbound APIs as part of the same governance

Considered. Notify Cloud and future Billing both have outbound webhook surfaces (Stripe-style HTTPS POSTs to tenant-supplied URLs). The argument: govern inbound and outbound HTTP under one ADR for symmetry. Rejected on scope: webhooks have meaningfully different concerns (retry policy, signing/verification, replay-attack defenses, tenant URL allowlisting) that deserve their own ADR. This ADR covers Studios-hosted **inbound** APIs only; a separate ADR will govern outbound webhooks when the first concrete webhook surface lands (currently expected in Notify Cloud GA or shortly after).

### Adopt OpenAPI Specification's optional "x-internal" extension to publish a subset of the spec

Considered. Tooling lets internal-vs-external endpoints share a single spec file with internal endpoints filtered out at docs/SDK generation time. Rejected for v1 simplicity: public APIs get their own spec file (`openapi-v{n}.yaml`); internal APIs (Node-to-Node) are governed by ADR-0035's NuGet abstractions instead of OpenAPI. Two separate substrates with crisp boundaries beat one substrate with a per-endpoint visibility flag.

### Require tenants to send a `User-Agent` identifying their SDK and version

Considered. Lets Studios observe SDK-version adoption in App Insights without instrumenting the tenant. Generated SDKs (D8) set a `User-Agent` of the form `honeydrunk-{api}-sdk-{lang}/{sdk-version}` by default; tenants can override per request. Not a hard requirement (no enforcement on the header's presence), but the SDK default ensures coverage for the population that uses generated SDKs. Recorded here so the SDK templates implement it from Phase 1.
