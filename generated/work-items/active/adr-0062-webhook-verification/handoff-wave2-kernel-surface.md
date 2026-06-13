# Handoff — Wave 2: Kernel Verification Surface

**Initiative:** `adr-0062-webhook-verification`
**Wave transition:** Wave 1 (governance + catalog) → Wave 2 (Kernel verification surface)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 landed

- **Packet 00** — ADR-0062 flipped to **Accepted**. Four new invariants added to `constitution/invariants.md` under a new `## Webhook Invariants` section, numbered **78, 79, 80, 81** (pre-reserved for ADR-0062):
  1. **78** — Inbound webhook receivers must verify provider signatures via `IWebhookSignatureVerifier` and reject requests outside a 5-minute replay window.
  2. **79** — Inbound webhook receivers must dedupe by `webhook:{provider}:{event-id}` against `IIdempotencyStore` before invoking handler side effects.
  3. **80** — Webhook signing secrets follow the `webhook-{provider}-{purpose}-signing-secret` Vault naming convention.
  4. **81** — Every webhook receipt produces an `IAuditLog` emit with category `WebhookReceipt`, outcome `Succeeded` / `Denied` / `Deduped`, and no payload body.
- **Packet 01** — the webhook-verification contract surface (`IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, `WebhookVerificationRequest`, `WebhookVerificationResult`) registered in `catalogs/contracts.json` and `catalogs/relationships.json` under `honeydrunk-kernel`. Kernel integration-points doc gains a `## Webhooks` section documenting the verifier interface, the raw-body middleware, and the `AddWebhookReceiver<T>` extension.

ADR-0062's decisions are now live rules. Packet 02 implements the contracts the catalog already advertises.

## What Wave 2 must deliver (packet 02)

Build the full ADR-0062 Kernel-owned webhook-verification surface in **`HoneyDrunk.Kernel`** (live Node, .NET 10.0; confirm current version at execution time — see Version-line section):

- **`HoneyDrunk.Kernel.Abstractions`** — add `IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, and the supporting records `WebhookVerificationRequest`, `WebhookVerificationResult`. Pure records/interfaces — zero HoneyDrunk runtime dependencies (invariant 1).
- **`HoneyDrunk.Kernel`** — add `HmacSha256SignatureVerifier` (the default for the SHA-256 timestamp-prefix shape Stripe / GitHub / Svix use), `RawBodyPreservationMiddleware` (ASP.NET Core middleware), `WebhookReceiverOptions` (options type), and the `services.AddWebhookReceiver<TVerifier>(options => …)` extension.
- This is the **version-bumping packet** for the `HoneyDrunk.Kernel` solution: bump every non-test `.csproj` one minor in one commit (invariant 27).

## Interface signatures for downstream packets

`IWebhookSignatureVerifier` — the shape packet 05 consumes:
```csharp
public interface IWebhookSignatureVerifier
{
    string ProviderName { get; }
    ValueTask<WebhookVerificationResult> VerifyAsync(
        WebhookVerificationRequest request,
        CancellationToken cancellationToken = default);
}
```

`WebhookVerificationRequest` — a record carrying:
- `ReadOnlyMemory<byte> Body` — the byte-exact provider-signed body.
- `DateTimeOffset? Timestamp` — provider-supplied signed timestamp; null for providers that don't supply one (Twilio).
- `IReadOnlyList<string> SignatureHeaders` — raw signature header value(s) the per-provider adapter read off the request.
- `IReadOnlyList<string> CandidateSecrets` — candidate signing secrets (D6 multi-key) resolved from Vault.
- `IReadOnlyDictionary<string, string> Extras` — provider-specific inputs (Twilio full URL, Svix message id).

`WebhookVerificationResult` — a record:
- `bool IsValid`
- `string? Reason` — optional diagnostic for logs only (NOT for the response body — 401 stays empty per D9).
- `DateTimeOffset? VerifiedTimestamp` — used by the caller for the D3 replay-window check.

`IRawWebhookBodyFeature` — interface with `ReadOnlyMemory<byte> Body { get; }`. Provided by `RawBodyPreservationMiddleware` on receiver routes.

`HmacSha256SignatureVerifier` — concrete `IWebhookSignatureVerifier` covering Stripe / GitHub / Svix timestamp-prefix HMAC-SHA256 with a configurable canonical-string pattern. Uses BCL `HMACSHA256` + `CryptographicOperations.FixedTimeEquals` (constant-time comparison, load-bearing for invariant 8). Iterates `CandidateSecrets`, returns on first match.

`RawBodyPreservationMiddleware` — ASP.NET Core middleware. Calls `HttpRequest.EnableBuffering()`, reads body into a `byte[]`, exposes via `IRawWebhookBodyFeature`, resets the stream so model binding still works. 1 MiB default cap (`WebhookReceiverOptions.MaxBodyBytes`); 413 with RFC 7807 envelope on overflow.

`WebhookReceiverOptions` — options carrying `SecretName`, `ReplayWindow` (default 5 min, D3), `DedupTtl` (default 7 days, D8 Standard), `MaxBodyBytes` (default 1 MiB, D4).

`services.AddWebhookReceiver<TVerifier>(Action<WebhookReceiverOptions> configure)` — `IServiceCollection` extension. Per D12 it wires:
- The verifier as `IWebhookSignatureVerifier`.
- `RawBodyPreservationMiddleware` on the receiver's route.
- Dedup-store lookup against `IIdempotencyStore` (ADR-0042 contract — assumed host-registered).
- Audit emitter against `IAuditLog` (ADR-0030/0031 contract — assumed host-registered).
- Keyed DI so multiple receivers in the same host don't collide (each receiver keyed by verifier provider name or secret name).

## Frozen / do-not-touch

- **`IIdempotencyStore`** (in `HoneyDrunk.Kernel.Abstractions` from ADR-0042) — packet 02 here *consumes* it via the `AddWebhookReceiver<T>` extension wiring; do NOT modify `IIdempotencyStore` or the supporting records. If ADR-0042 packet 02 has not landed when this packet starts, see the soft-coordination note in packet 02's Context.
- **`IAuditLog`** (in `HoneyDrunk.Audit.Abstractions`) — packet 02 wires emission against it; do NOT modify or add a new audit contract.
- **Existing Kernel context contracts** (`IGridContext`, `TenantId`, `CorrelationId`, etc.) — the webhook surface composes the existing context; do not fork a parallel context model (invariant 5/6).
- **`HoneyDrunk.Transport` and `HoneyDrunk.Vault`** — Kernel does NOT take a `PackageReference` on these. Invariant 4 (Kernel at DAG root). The verifier receives candidate secrets as input; the extension wires `IIdempotencyStore` and `IAuditLog` at composition without taking package references.

## Version-line coordination with ADR-0042

ADR-0042's `adr-0042-idempotency` initiative also bumps `HoneyDrunk.Kernel`. Both initiatives share the same solution. Sequence the bumps:
1. **ADR-0042 packet 02 first** — if not yet merged, this packet rebases onto its merge so the version line is consistent (ADR-0042 packet 02 bumps `0.7.0` → `0.8.0`; this packet then bumps `0.8.0` → `0.9.0`).
2. **If ADR-0042 packet 02 has not merged at execution time** — coordinate at PR time. Either wait for the ADR-0042 packet 02 merge, or work on a parallel branch and resolve the version-line conflict at merge time.

State the sequencing decision in the PR. Either path is valid; the only error mode is partial-bump (some `.csproj` files at `0.8.0`, others at `0.9.0`) — that violates invariant 27 and is a build failure.

## Invariants binding Wave 2

- **Invariant 1** — `HoneyDrunk.Kernel.Abstractions` has zero runtime dependencies on other HoneyDrunk packages; only `Microsoft.Extensions.*` abstractions permitted. The records carry data, not behaviour; SHA-256 lives in the runtime verifier.
- **Invariant 4** — DAG; Kernel is at the root. No `PackageReference` to `HoneyDrunk.Transport`, `HoneyDrunk.Vault`, `HoneyDrunk.Data`, or `HoneyDrunk.Audit`.
- **Invariant 8** — Secret values never appear in logs/traces/exceptions/telemetry. Constant-time signature comparison via `CryptographicOperations.FixedTimeEquals` is the load-bearing primitive.
- **Invariant 13** — all public APIs have XML documentation. Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 27** — all projects in a solution share one version and move together. Both `.csproj` files bump together in one commit.
- **Naming rule** — records drop the `I` (`WebhookVerificationRequest`, `WebhookVerificationResult`); interfaces keep it (`IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`). `HmacSha256SignatureVerifier`, `RawBodyPreservationMiddleware`, `WebhookReceiverOptions` are classes (no `I`).

## New dependency edge — AspNetCore on Kernel runtime

ADR-0062 D4 places the middleware in `HoneyDrunk.Kernel` runtime, which means the runtime package gains a dependency on `Microsoft.AspNetCore.Http.Abstractions` (or `Microsoft.AspNetCore.Http.Features`). If `HoneyDrunk.Kernel` does not already take an AspNetCore dependency, this is a new edge — acknowledge in the PR.

**Fallback if review pushes back:** split the middleware + extension into a `HoneyDrunk.Kernel.Webhooks.AspNetCore` sub-package. ADR-0062 D4's "lives in Kernel" reading covers either shape; the sub-package keeps the core `HoneyDrunk.Kernel` AspNetCore-free at the cost of one more package in the family. Default to the in-Kernel placement; sub-package split is an in-PR re-org if needed.

## Acceptance gate for the wave

Packet 02's PR passes the `pr-core.yml` tier-1 gate and the Kernel contract-shape canary (the new contracts are additive, paired with the version bump). `HoneyDrunk.Kernel` is at the new minor version with the full webhook-verification surface shipped. Wave 3 packets 03 (Vault.Rotation) and 04 (review prompts) can start in parallel (neither depends on packet 02). Wave 4 packet 05 (Notify) starts once packet 02's release is on the package feed.

**Human package release at the Wave 2→4 boundary — agents never tag.** Packet 05 (Wave 4) builds against `HoneyDrunk.Kernel` at the new minor version; that artifact reaches the package feed only after a human pushes a git release tag on `HoneyDrunk.Kernel`. After packet 02 merges, a human must tag/release before packet 05 starts. Wave 3 packets 03 and 04 do NOT need the Kernel release — packet 03 is `HoneyDrunk.Vault.Rotation` (doesn't consume Kernel webhook code), packet 04 is `HoneyDrunk.Architecture` (docs).
