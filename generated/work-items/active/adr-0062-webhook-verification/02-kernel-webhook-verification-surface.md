---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0062", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0062"]
wave: 2
initiative: adr-0062-webhook-verification
node: honeydrunk-kernel
---

# Add the ADR-0062 webhook verification surface to HoneyDrunk.Kernel

## Summary
Ship the full ADR-0062 Kernel-owned webhook-verification surface in one work-item: the `IWebhookSignatureVerifier` contract in `HoneyDrunk.Kernel.Abstractions` (with supporting records and the `IRawWebhookBodyFeature` request feature); the `HmacSha256SignatureVerifier` default, the `RawBodyPreservationMiddleware`, the `WebhookReceiverOptions` options type, and the `services.AddWebhookReceiver<TVerifier>(options => …)` extension in the `HoneyDrunk.Kernel` runtime package. The version-bumping packet for the `HoneyDrunk.Kernel` solution under this initiative.

## Context
ADR-0062 D7 places `IWebhookSignatureVerifier` in `HoneyDrunk.Kernel.Abstractions` because Kernel is the zero-dependency contract layer every Node already consumes — the same placement precedent as `IGridContext`, `TenantId`, `IIdempotencyStore`. ADR-0062 D4 places the `RawBodyPreservationMiddleware` in Kernel runtime "because the raw-body-preservation problem is purely ASP.NET-Core-shaped and the solution is reusable verbatim across every receiver. Per-Node ownership would invite per-Node implementation drift on the exact ASP.NET Core gotchas (`HttpContext.Request.Body` vs `BodyReader`, async disposal, buffer disposal under exceptions) that are the hardest part of getting this right." ADR-0062 D12 names the `services.AddWebhookReceiver<TVerifier>(options => …)` extension as the canonical Kernel registration shape.

This packet ships **both the contracts and the runtime** in one packet (unlike ADR-0042 where contracts and runtime split into packets 02 and 04). The reason: the four runtime pieces here — the SHA-256 default verifier, the middleware, the options type, and the extension — are *load-bearing for the contracts to be useful at all*. A Node cannot compose `IWebhookSignatureVerifier` without `AddWebhookReceiver<T>`; it cannot get the raw bytes without `RawBodyPreservationMiddleware`; the default `HmacSha256SignatureVerifier` covers the GitHub/Stripe/Svix-style timestamp-prefix-HMAC-SHA256 case and is the seam every per-provider verifier reuses. Splitting this into two packets would force Wave 3 (Notify in packet 05) to wait for two Kernel publishes instead of one. The packet stays large but the testable unit is "a Node can verify inbound webhooks end-to-end against the Kernel surface."

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts) and `HoneyDrunk.Kernel` (runtime). This packet is the **only packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (confirm the in-flight version at execution time — if ADR-0042's `0.8.0` bump has merged, this packet bumps `0.8.0` → `0.9.0`; if 0.8.0 has not landed, this packet still bumps one minor version above the current released version). Additive new types, no break.

The verifier surface composes with `IIdempotencyStore` (ADR-0042) at the receiver registration site — `AddWebhookReceiver<T>` wires both the verifier and the dedup-store lookup. That coupling lives at the extension; the verifier interface itself has no `IIdempotencyStore` dependency.

> **Soft dependency on ADR-0042 status.** ADR-0062 D8 reuses `IIdempotencyStore` from ADR-0042. If ADR-0042 packet 02 (the `IIdempotencyStore` contract) has merged at execution time, `AddWebhookReceiver<T>` can take a hard reference to the `IIdempotencyStore` resolution at composition time. If ADR-0042 packet 02 has NOT yet merged, the executor has two options: (a) wait until ADR-0042 packet 02 lands (it has no blockers and is parallel-eligible); or (b) make the dedup-store lookup at receiver composition the responsibility of the host Node rather than the extension — the extension wires the verifier and middleware, the host wires dedup. State the choice in the PR. The Notify-side packet 05 here assumes the extension wires dedup; if option (b) is taken, packet 05's composition gets a tiny extra line. Default to option (a): file packets in an order that lets ADR-0042 packet 02 merge first, since both initiatives are open.

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new contract types:
  - `IWebhookSignatureVerifier` — interface (per-provider implementations register against it).
  - `IRawWebhookBodyFeature` — interface (ASP.NET Core request feature exposing byte-exact body).
  - `WebhookVerificationRequest` — record (inputs to a verifier).
  - `WebhookVerificationResult` — record (outcome of a verifier call).
- `HoneyDrunk.Kernel` runtime — new types:
  - `HmacSha256SignatureVerifier` — concrete `IWebhookSignatureVerifier`; covers the GitHub-Hub-Signature-256 / Stripe / Svix shape (timestamp-prefix HMAC-SHA256 over a configurable canonical-string pattern).
  - `RawBodyPreservationMiddleware` — ASP.NET Core middleware that buffers the request body, exposes `IRawWebhookBodyFeature`, resets the stream; 1 MiB default cap; 413 on overflow.
  - `WebhookReceiverOptions` — record (or class) carrying secret name, replay window, dedup TTL, max body bytes.
  - `services.AddWebhookReceiver<TVerifier>(options => …)` extension on `IServiceCollection`/`IEndpointRouteBuilder` (per the repo's existing extension conventions) — binds the verifier, wires the middleware onto the receiver's route, registers the dedup-store lookup (assumes `IIdempotencyStore` from ADR-0042 is registered in the host), registers the audit emitter (assumes `IAuditLog` from ADR-0030/0031 is registered in the host).
- Both `.csproj` files in the solution version-bumped together (invariant 27).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel/CHANGELOG.md`, both README.md files updated.
- Repo-level `CHANGELOG.md` gets a new version entry.
- Unit tests for the contract types, the SHA-256 verifier, the middleware (using `TestServer`), and the extension's wiring behaviour.

## Proposed Implementation

### Contract types (`HoneyDrunk.Kernel.Abstractions`)
1. **`IWebhookSignatureVerifier`** — interface exposing exactly:
   ```csharp
   public interface IWebhookSignatureVerifier
   {
       string ProviderName { get; }
       ValueTask<WebhookVerificationResult> VerifyAsync(
           WebhookVerificationRequest request,
           CancellationToken cancellationToken = default);
   }
   ```
   XML-doc that per-provider implementations (Stripe, GitHub, Svix, Twilio, etc.) live next to the receiver they serve in the consuming Node; this interface is the registration seam.
2. **`WebhookVerificationRequest`** — `record` carrying:
   - `ReadOnlyMemory<byte> Body` — the byte-exact provider-signed body (from `IRawWebhookBodyFeature` or a Function-binding `byte[]`).
   - `DateTimeOffset? Timestamp` — the provider-supplied signed timestamp; null for the rare provider that does not supply one (then D8 nonce-based replay protection applies — see D3 fallback).
   - `IReadOnlyList<string> SignatureHeaders` — the raw signature header value(s) the per-provider adapter (D2) read off the request.
   - `IReadOnlyList<string> CandidateSecrets` — the candidate signing secrets (D6 multi-key shape) resolved from Vault; the verifier accepts the first match.
   - `IReadOnlyDictionary<string, string> Extras` — provider-specific inputs (Twilio's full URL, Svix's message id, etc.).
3. **`WebhookVerificationResult`** — `record` carrying:
   - `bool IsValid` — verification outcome.
   - `string? Reason` — optional diagnostic reason for D10 logging (NOT for the response body — that stays empty on 401, D9).
   - `DateTimeOffset? VerifiedTimestamp` — the timestamp the verifier accepted (used by the caller for the D3 replay-window check).
4. **`IRawWebhookBodyFeature`** — interface with `ReadOnlyMemory<byte> Body { get; }` (and any other accessors the middleware needs). XML-doc: "Request feature exposing the byte-exact webhook body for signature verification. Provided by `RawBodyPreservationMiddleware` on receiver routes."
5. All new public types get full XML documentation (invariant 13).

### Runtime types (`HoneyDrunk.Kernel`)
6. **`HmacSha256SignatureVerifier`** — concrete `IWebhookSignatureVerifier`. Verifies the timestamp-prefix HMAC-SHA256 shape used by Stripe (`t=...,v1=hmac_sha256(timestamp + "." + body)`), GitHub (`sha256=hmac_sha256(body)`), and Svix (`v1,hmac_sha256(msg_id + "." + timestamp + "." + body)`). The canonical-string pattern is configurable per receiver — e.g. via a constructor parameter or a `Func<WebhookVerificationRequest, string>` builder — so the same default verifier composes for the three SHA-256 providers without three near-identical types. Uses `System.Security.Cryptography.HMACSHA256` from the BCL. Uses constant-time comparison (`CryptographicOperations.FixedTimeEquals`) — invariant 8 (secret values never leak; timing-leak avoidance is the load-bearing reason here). Iterates `CandidateSecrets` (D6 multi-key), returns on first match.
7. **`RawBodyPreservationMiddleware`** — ASP.NET Core `IMiddleware` or `RequestDelegate`-shaped. Per ADR-0062 D4:
   - Calls `HttpRequest.EnableBuffering()` with a configurable size cap (default 1 MiB — read from `WebhookReceiverOptions.MaxBodyBytes`).
   - Reads the body into a `byte[]`, exposes it as a request feature (`IRawWebhookBodyFeature`), resets the stream position so downstream model binding still works.
   - Refuses bodies larger than the cap: short-circuits with `413 Payload Too Large` and an RFC 7807 envelope citing `https://errors.honeydrunkstudios.com/webhooks/payload-too-large`.
   - Handles async disposal and exception paths correctly — the ASP.NET Core gotchas (`HttpContext.Request.Body` vs `BodyReader`, buffer disposal under exceptions) the ADR D4 calls out are exactly what unit tests need to cover.
   - Registered explicitly per webhook receiver route (not Grid-globally) — the `AddWebhookReceiver<T>` extension wires this.
8. **`WebhookReceiverOptions`** — options carrying:
   - `string SecretName` (the `webhook-{provider}-{purpose}-signing-secret` Vault name, D5).
   - `TimeSpan ReplayWindow` (default `TimeSpan.FromMinutes(5)`, D3 hard pin).
   - `TimeSpan DedupTtl` (default `TimeSpan.FromDays(7)`, D8 Standard tier; Billing-class receivers override to 30 days).
   - `int MaxBodyBytes` (default `1_048_576`, D4 1 MiB).
9. **`services.AddWebhookReceiver<TVerifier>(Action<WebhookReceiverOptions> configure)`** — `IServiceCollection` extension. Per ADR-0062 D12 this wires:
   - The verifier as `IWebhookSignatureVerifier` (DI'd by `TVerifier`).
   - The `RawBodyPreservationMiddleware` for the receiver's route (the registration shape matches the repo's existing extension convention — if Kernel today exposes `IEndpointRouteBuilder` extensions or only `IServiceCollection` ones, follow that).
   - The dedup-store lookup against `IIdempotencyStore` (from ADR-0042 — assumed registered in the host).
   - The audit emitter against `IAuditLog` (from ADR-0030/0031 — assumed registered in the host).
   - Each receiver gets its own keyed registration so multiple receivers in the same host (e.g. Notify hosting both a Resend and a Twilio receiver) do not collide. Use `IServiceCollection.AddKeyedTransient`/`AddKeyedScoped` (the .NET 8+ keyed-DI shape) with the verifier provider name (or the secret name) as the key.

### Tests
10. Unit tests on `HmacSha256SignatureVerifier`:
    - Valid signature with the canonical Stripe pattern verifies.
    - Valid signature with the canonical Svix pattern verifies (different builder).
    - Invalid signature returns `IsValid = false`.
    - Multi-key: with `CandidateSecrets = ["old", "new"]`, a signature generated with `"new"` verifies; one generated with `"old"` verifies; one generated with `"unknown"` does not.
    - Uses `CryptographicOperations.FixedTimeEquals` (verified by code review — runtime test would be a timing test and is not deterministic, so cover this via inspection-grade comment + unit-test for the equality outcome).
11. Unit tests on `RawBodyPreservationMiddleware`, using ASP.NET Core's `TestServer`:
    - A request body is readable by `IRawWebhookBodyFeature` and remains readable by downstream model binding.
    - A request body within the cap completes; one exceeding the cap short-circuits with 413.
    - Async disposal does not leak buffers.
    - No `Thread.Sleep` (invariant 51).
12. Unit tests on `AddWebhookReceiver<T>` — composition: register a verifier, resolve `IServiceProvider`, confirm the verifier and the options are wired; confirm the middleware is on the configured route. Use the `Microsoft.AspNetCore.Mvc.Testing` `WebApplicationFactory` per ADR-0047 Tier 2a, OR a Kernel-local lighter test pattern if that is what the repo already uses for middleware tests — match the repo's existing convention.

### Versioning + docs
13. Bump every non-test `.csproj` in the `HoneyDrunk.Kernel` solution to the next minor version in one commit (invariant 27). Confirm the in-flight version at execution time (`0.7.0` is the released version per the v0.4 tracker; if ADR-0042 packet 02 has merged its `0.8.0` bump, this packet bumps `0.8.0` → `0.9.0`; otherwise this packet bumps `0.7.0` → `0.8.0` and the ADR-0042 packet 02 has to coordinate).
14. Add repo-level `CHANGELOG.md` entry under the new version.
15. Add a per-package CHANGELOG entry to `HoneyDrunk.Kernel.Abstractions` (real changes — new contracts) and to `HoneyDrunk.Kernel` (real changes — new runtime types). No noise entries on packages without changes (invariant 12).
16. Update `HoneyDrunk.Kernel.Abstractions/README.md` and `HoneyDrunk.Kernel/README.md` — the public API surface gained the webhook-verification contracts and runtime types; document them in the API-surface section.

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files: `IWebhookSignatureVerifier.cs`, `IRawWebhookBodyFeature.cs`, `WebhookVerificationRequest.cs`, `WebhookVerificationResult.cs`.
- `HoneyDrunk.Kernel/` — new runtime type files: `HmacSha256SignatureVerifier.cs`, `RawBodyPreservationMiddleware.cs`, `WebhookReceiverOptions.cs`, the `AddWebhookReceiver` extension file (location matches the repo's existing `Add*` extension placement).
- `HoneyDrunk.Kernel.Abstractions.csproj`, `HoneyDrunk.Kernel.csproj` — version bumps.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel/CHANGELOG.md`, both `README.md` files.
- Repo-level `CHANGELOG.md`.
- `HoneyDrunk.Kernel.Tests` (or the repo's equivalent unit-test project) — tests for the verifier, middleware, and extension wiring.

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new HoneyDrunk `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions. The records reference only BCL types (`ReadOnlyMemory<byte>`, `DateTimeOffset`, `IReadOnlyList<T>`, `IReadOnlyDictionary<string, string>`). `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel`** — may need:
  - `Microsoft.AspNetCore.Http.Abstractions` (or `Microsoft.AspNetCore.Http.Features`) — for `IMiddleware` / `HttpContext.Features.Set<T>` access. ASP.NET Core middleware support is the load-bearing reason. Confirm whether `HoneyDrunk.Kernel` already takes an AspNetCore dependency; if not, this is a new dependency edge that needs explicit acknowledgement in the PR. Alternative: ship the middleware in a separate `HoneyDrunk.Kernel.Webhooks.AspNetCore` package to keep the core `HoneyDrunk.Kernel` AspNetCore-free. **Default to keeping it in `HoneyDrunk.Kernel`** — ADR-0062 D4 says "the middleware lives in Kernel" without qualification; a sub-package split would be the same shape with a different name. Take the AspNetCore dependency; document the new edge in the CHANGELOG and the README. If review pushes back, the sub-package split is an in-PR re-org.
  - `Microsoft.Extensions.DependencyInjection.Abstractions` and `Microsoft.Extensions.Options` — for `AddWebhookReceiver` and options binding. These are likely already referenced.
  - `Microsoft.Extensions.Logging.Abstractions` — for the middleware's log lines (D10 redaction rules apply).
- **Unit-test project** — the repo's existing test stack (xUnit v2 + NSubstitute + AwesomeAssertions + coverlet per ADR-0047). For the middleware tests, `Microsoft.AspNetCore.Mvc.Testing` and/or `Microsoft.AspNetCore.TestHost`. `HoneyDrunk.Standards` is already on the test project (`PrivateAssets: all`).

## Boundary Check
- [x] `IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, `WebhookVerificationRequest`, `WebhookVerificationResult` are Kernel contracts per ADR-0062 D7/D4. Routing rule "context, GridContext, NodeContext, ... CorrelationId → HoneyDrunk.Kernel" and the ADR's explicit placement both map here.
- [x] `HmacSha256SignatureVerifier`, `RawBodyPreservationMiddleware`, `WebhookReceiverOptions`, `AddWebhookReceiver<T>` are runtime types in the `HoneyDrunk.Kernel` runtime package per ADR-0062 D4/D7/D12.
- [x] No dependency on `HoneyDrunk.Transport`, `HoneyDrunk.Vault`, or `HoneyDrunk.Data` from Kernel — the dependency graph is those → Kernel, never the reverse (invariant 4). The verifier reads candidate secrets passed into `WebhookVerificationRequest` (the host resolves them from Vault); the extension wires `IIdempotencyStore` and `IAuditLog` at composition time without taking a `PackageReference` on Data or Audit.
- [x] AspNetCore dependency on the runtime package is the one new edge — note it explicitly in the PR.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `IWebhookSignatureVerifier` with `string ProviderName { get; }` and `ValueTask<WebhookVerificationResult> VerifyAsync(WebhookVerificationRequest, CancellationToken)` exactly as ADR-0062 D7 specifies
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `IRawWebhookBodyFeature` and the `WebhookVerificationRequest` + `WebhookVerificationResult` records with the fields enumerated in Proposed Implementation
- [ ] `WebhookVerificationRequest.CandidateSecrets` is a list (multi-key, D6); the verifier accepts the first match
- [ ] `WebhookVerificationResult.Reason` is documented as for logging only — never to be surfaced in a response body (D9 401 has empty body)
- [ ] `HoneyDrunk.Kernel` ships `HmacSha256SignatureVerifier` covering the Stripe / GitHub / Svix timestamp-prefix HMAC-SHA256 shape with a configurable canonical-string pattern; uses `CryptographicOperations.FixedTimeEquals` for the constant-time comparison; iterates the candidate-secrets list and returns on first match
- [ ] `HoneyDrunk.Kernel` ships `RawBodyPreservationMiddleware` that calls `HttpRequest.EnableBuffering()`, reads the body into a `byte[]`, exposes it via `IRawWebhookBodyFeature`, resets the stream, refuses bodies larger than `WebhookReceiverOptions.MaxBodyBytes` with `413 Payload Too Large` and an RFC 7807 envelope citing `https://errors.honeydrunkstudios.com/webhooks/payload-too-large`
- [ ] `WebhookReceiverOptions` carries `SecretName`, `ReplayWindow` (default 5 minutes, D3), `DedupTtl` (default 7 days, D8 Standard), `MaxBodyBytes` (default 1 MiB, D4)
- [ ] `services.AddWebhookReceiver<TVerifier>(Action<WebhookReceiverOptions> configure)` extension wires the verifier, the middleware on the receiver's route, the dedup-store lookup against `IIdempotencyStore`, and the audit emitter against `IAuditLog`; multiple receivers in the same host do not collide (keyed DI)
- [ ] All new public types have XML documentation (invariant 13)
- [ ] `HoneyDrunk.Kernel.Abstractions` has zero runtime `PackageReference` on any HoneyDrunk package (invariant 1)
- [ ] The new AspNetCore dependency on `HoneyDrunk.Kernel` runtime is acknowledged in the PR and added to the runtime `.csproj`; if a sub-package split is chosen instead (`HoneyDrunk.Kernel.Webhooks.AspNetCore`), the split is justified in the PR
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry dated to the merge
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` and `HoneyDrunk.Kernel/CHANGELOG.md` each have an entry describing their portion of the webhook surface (real changes in both packages)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` and `HoneyDrunk.Kernel/README.md` document the new types in their public-API sections
- [ ] Unit tests cover: valid + invalid SHA-256 signatures for Stripe and Svix patterns, multi-key first-match, constant-time comparison usage, middleware buffering + reset + 413 overflow, extension wiring; no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes and the Kernel contract-shape canary stays green — the new contracts are additive, paired with the version bump

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0062 D1 — Per-provider HMAC (SHA-256 default).** The Grid does not impose a uniform HMAC scheme. Each receiver verifies signatures using the provider's emitted scheme. SHA-256 is the first-party default; SHA-1 is accepted as-is for Twilio (per-provider verifier). The default Kernel verifier `HmacSha256SignatureVerifier` covers the SHA-256 timestamp-prefix shape; SHA-1 verifiers live next to the receiver they serve.

**ADR-0062 D4 — Kernel-owned `RawBodyPreservationMiddleware`.** Registered explicitly per webhook receiver route. Calls `HttpRequest.EnableBuffering()` with a configurable size cap (default 1 MiB). Reads the body into a `byte[]`, exposes it as a request feature (`IRawWebhookBodyFeature`), resets the stream so downstream model binding still works. Refuses bodies larger than the cap with `413 Payload Too Large`. Function-App-hosted receivers bypass the middleware (the Functions binding gives them the bytes) and call into the same verifier.

**ADR-0062 D6 — Multi-key verification.** Every verifier supports verifying against N candidate signing secrets simultaneously, accepting the first match. Default N=2 (current + previous). The verifier reads candidate secrets from a single Vault entry whose value is either a bare secret string (N=1), a newline-separated list (N>1), or a JSON `{ "active", "previous": [...] }` object. The verifier accepts all three shapes; the receiver chooses.

**ADR-0062 D7 — `IWebhookSignatureVerifier`.** Lives in `HoneyDrunk.Kernel.Abstractions`. Interface exposes `string ProviderName { get; }` and `ValueTask<WebhookVerificationResult> VerifyAsync(WebhookVerificationRequest, CancellationToken)`. `WebhookVerificationRequest` carries body bytes, timestamp, signature headers, candidate secrets, and an extras dictionary. `WebhookVerificationResult` carries `bool IsValid`, optional reason for diagnostics, verified timestamp. Records drop the `I`; interfaces keep it.

**ADR-0062 D9 — Response convention.** 200 / 400 / 401 / 409 / 413. 200 and 401 have empty bodies. 400, 409, 413 carry an RFC 7807 envelope. 401 never leaks which check failed (D10 distinction lives in logs and the audit emit).

**ADR-0062 D10 — Logging and redaction.** Never log signing secrets in any form. Never log the raw signed body in full. Log body size in bytes and a SHA-256 hash prefix (first 16 hex chars). Always log verification outcome, signature header presence, timestamp drift in seconds, and dedup outcome. The middleware and the verifier are the load-bearing sites for these rules.

**ADR-0062 D12 — Registration shape.** `services.AddWebhookReceiver<TVerifier>(options => { options.SecretName = ...; options.ReplayWindow = TimeSpan.FromMinutes(5); options.DedupTtl = TimeSpan.FromDays(7); options.MaxBodyBytes = 1_048_576; });` — binds the verifier, wires raw-body middleware on the receiver's route, registers the dedup-store lookup against `IIdempotencyStore`, registers the audit emitter against `IAuditLog`.

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` abstractions permitted. No SHA256 import is needed in Abstractions (the records carry data, not behaviour); SHA256 lives in the runtime `HmacSha256SignatureVerifier`. No runtime logic, no DI, no JSON loading in Abstractions.
- **Invariant 4 — DAG; Kernel is at the root.** No reference to `HoneyDrunk.Transport`, `HoneyDrunk.Vault`, `HoneyDrunk.Data`, or `HoneyDrunk.Audit` from Kernel. The verifier receives candidate secrets as input (host resolves from Vault); the extension wires `IIdempotencyStore` and `IAuditLog` at composition without taking package references.
- **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The verifier and middleware log only signature *header presence*, *body size*, and *body SHA-256 hash prefix* — never the secret value, never the raw body. Constant-time comparison (`CryptographicOperations.FixedTimeEquals`) is the load-bearing primitive for the equality check.
- **Invariant 13 — all public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 27 — all projects in a solution share one version and move together.** Both `.csproj` files bump together. Confirm the in-flight version at execution time and bump one minor above it.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** Both `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` have real changes in this packet; both get entries.
- **Records drop the `I`; interfaces keep it.** `WebhookVerificationRequest`, `WebhookVerificationResult` (records); `IWebhookSignatureVerifier`, `IRawWebhookBodyFeature` (interfaces). `HmacSha256SignatureVerifier`, `RawBodyPreservationMiddleware`, `WebhookReceiverOptions` are classes (no `I`).
- **AspNetCore dependency acknowledgement.** If `HoneyDrunk.Kernel` runtime did not previously depend on AspNetCore abstractions, this packet introduces that edge. State it explicitly in the PR; if review pushes back, split the middleware + extension into a `HoneyDrunk.Kernel.Webhooks.AspNetCore` sub-package — ADR-0062 D4's "lives in Kernel" reading covers either shape.

## Labels
`feature`, `tier-2`, `core`, `adr-0062`, `wave-2`

## Agent Handoff

**Objective:** Ship the full ADR-0062 Kernel-owned webhook-verification surface (contracts + runtime + extension) so consuming Nodes can compose it end-to-end.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Build the contract + runtime + registration shape that every webhook-hosting Node in the Grid composes against.
- Feature: ADR-0062 Webhook Verification rollout, Wave 2 (the foundation).
- ADRs: ADR-0062 D1/D4/D6/D7/D9/D10/D12 (primary), ADR-0042 (the `IIdempotencyStore` `AddWebhookReceiver<T>` wires — assumed registered by the host), ADR-0030/0031 (the `IAuditLog` it emits to — assumed registered by the host), ADR-0035 (additive minor-bump policy), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0062 Accepted and its four invariants live before the contracts are built against them.
- **Soft coordination with ADR-0042's `adr-0042-idempotency` initiative.** This packet's `AddWebhookReceiver<T>` extension wires `IIdempotencyStore` (the ADR-0042 contract). If ADR-0042 packet 02 has not landed at execution time, see the Context note for the option to make dedup lookup the host's responsibility instead.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1).
- No `PackageReference` to `HoneyDrunk.Transport`, `HoneyDrunk.Vault`, `HoneyDrunk.Data`, or `HoneyDrunk.Audit` from Kernel (invariant 4).
- AspNetCore dependency on the runtime package is the one new edge — state in PR; sub-package split is a fallback.
- Constant-time signature comparison (`CryptographicOperations.FixedTimeEquals`); never log secrets, never log raw bodies (invariant 8 + D10).
- Bump both non-test `.csproj` files together (invariant 27). This is the bumping packet for `HoneyDrunk.Kernel` in this initiative.
- Records drop the `I`; interfaces keep it.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files.
- `HoneyDrunk.Kernel/` — `HmacSha256SignatureVerifier.cs`, `RawBodyPreservationMiddleware.cs`, `WebhookReceiverOptions.cs`, the `AddWebhookReceiver` extension file.
- Both `CHANGELOG.md` + `README.md` files; repo-level `CHANGELOG.md`.
- Both `.csproj` files for the version bump.

**Contracts:**
- `IWebhookSignatureVerifier` (new interface) — per-provider verifier seam.
- `IRawWebhookBodyFeature` (new interface) — ASP.NET Core request feature exposing byte-exact body.
- `WebhookVerificationRequest`, `WebhookVerificationResult` (new records).
- Default runtime types: `HmacSha256SignatureVerifier`, `RawBodyPreservationMiddleware`, `WebhookReceiverOptions`, `AddWebhookReceiver<T>` extension.
