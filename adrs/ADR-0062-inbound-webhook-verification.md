# ADR-0062: Inbound Webhook Verification and Receiver Pattern

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid is about to acquire four independent inbound-webhook surfaces inside one release window:

- **`HoneyDrunk.Billing.Webhooks`** — Stripe webhook handler, named explicitly in [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D4 as a Function App. Validates Stripe signatures, persists raw events to the buffer, fans out to the default Service Bus topic per [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md).
- **`HoneyDrunk.Notify`** — Resend and Twilio status webhooks (delivery receipts, bounce events, opt-outs). Currently in flight as part of the Notify Cloud rollout per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) and [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md). The provider feeds are Svix-shaped for Resend and Basic-Auth-plus-signature for Twilio.
- **`HoneyDrunk.Observe`** — GitHub connector webhook receiver (the Q3 roadmap item). Inbound GitHub events normalized through `IObservationEvent` per [ADR-0010](./ADR-0010-observation-layer.md) and Invariant 30.
- **`HoneyDrunk.Communications`** — Operator approval-event subscribers and tenant-supplied callback endpoints that the orchestration layer per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) reacts to.

Without a Grid-level decision, each of these four lands its own HMAC implementation, its own replay window, its own secret-naming convention, its own raw-body-buffering middleware, and its own response-code mapping. Four roughly-correct implementations is the predictable failure mode: drift on the parts a `security` specialist review (per [ADR-0046](./ADR-0046-specialist-review-agents.md)) cannot easily compare across Nodes.

The forcing functions for deciding this now:

- **Stripe webhook handler is the immediate consumer.** [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D4 names `HoneyDrunk.Billing.Webhooks` as a future Function App; whatever shape it ships becomes de-facto canon for every webhook surface after it.
- **Notify Cloud GA carries Resend and Twilio status-webhook integration as a launch-shape requirement.** Provider-side delivery receipts are the only credible way the Cloud surface knows whether a tenant's send succeeded; the integration cannot be deferred past GA.
- **Observe's connector model (per [ADR-0010](./ADR-0010-observation-layer.md)) is the AI-sector-readiness gate** for any external observation source. GitHub is the first realistic connector to land. The webhook-verification shape decided here is what the connector slot consumes.
- **Communications subscriber surfaces are about to be specified.** The Operator-approval-event-subscriber design is one packet away. Settling the verification pattern before Communications writes its first receiver prevents the per-Node-drift outcome.
- **[ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) and [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md)** both have load-bearing implications for any webhook surface (PII handling on the payload side; signing-secret rotation on the credential side). Receiver patterns that don't compose with those ADRs will need to be re-litigated later.

This ADR commits the verification pattern, the signature-header adapter posture, the replay window, the raw-body preservation rule, the secret-naming convention, the rotation/multi-key shape, the home of the verification helper, the replay-protection storage decision, the response-code envelope, and the logging-and-redaction rules. It does **not** govern outbound webhooks (Studios-hosted endpoints that emit signed POSTs to tenant URLs); that surface deserves its own ADR when the first concrete outbound webhook lands, and [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) explicitly defers it for the same reason.

## Decision

### D1. HMAC algorithm: per-provider-as-emitted; SHA-256 the first-party default

The Grid does not impose a uniform HMAC scheme on inbound webhooks. Each receiver verifies signatures using the **provider's emitted scheme** — Stripe's timestamp-prefixed `t=...,v1=hmac_sha256(payload)`, GitHub's `sha256=hmac_sha256(payload)`, Svix's `v1,hmac_sha256(msg_id.timestamp.payload)`, Twilio's URL-plus-form-encoded HMAC-SHA1. The receiver does not reinterpret what the provider sent; it verifies what the provider sent.

For **first-party-emitted webhooks** (Studios-as-emitter; not in scope for this ADR but anticipated when outbound-webhook governance lands), the standard is **HMAC-SHA256** computed over `timestamp.body` with the timestamp also exposed in a header. That convention is recorded here so the future outbound ADR has a v1 anchor; it does not bind any current receiver.

Provider-specific cryptographic obligations (e.g., Twilio's HMAC-SHA1) are accepted as-is for v1. The trust boundary is the provider; the Grid's job is to verify their signature correctly, not to impose a stronger scheme on top.

### D2. Signature header convention: per-provider adapter, no Grid-uniform header

Different providers emit different header names:

- GitHub: `X-Hub-Signature-256`
- Stripe: `Stripe-Signature`
- Resend / Svix: `svix-id`, `svix-timestamp`, `svix-signature`
- Twilio: `X-Twilio-Signature`

The Grid does **not** rewrite these into a uniform header. Each receiver carries a provider-specific adapter that reads the provider's header(s). The shared verification surface (D7) accepts the header values as inputs; it does not impose a header schema. Per-provider adapters live next to the receiver they serve.

Rejected: a uniform `X-HoneyDrunk-Signature` header that receivers normalize into. The normalization is meaningless because the underlying signing schemes are not uniform — there is no payload shape a uniform header could carry that would survive Stripe-vs-Twilio-vs-Svix differences. The adapter is the right layer of abstraction.

### D3. Replay window: 5 minutes, hard-pinned

Every inbound webhook is verified against a **5-minute replay window** measured against the signed timestamp the provider supplies. Requests outside the window are rejected at the verification step with `400 Bad Request` per D9. The 5-minute value matches Stripe's documented default, the [OWASP webhook cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Webhook_Security_Cheat_Sheet.html) recommendation, and the implicit pattern in Svix's reference implementation. It is conservative enough to defeat replay over the public internet and loose enough to absorb the clock skew Container Apps revisions exhibit in practice.

The 5-minute window applies to **every receiver in the Grid**, including providers whose own documentation suggests a longer tolerance. We pin the tighter window deliberately: the marginal cost of a tighter replay tolerance is a few legitimately-late retries the provider will themselves redeliver; the marginal benefit is a shorter replay surface for stolen-secret scenarios.

Receivers whose providers do not supply a timestamp in the signed payload (rare; an example would be a hand-rolled tenant-supplied webhook) fall back to nonce-based replay protection per D8 — the inbound signature is verified, the message ID is looked up in the dedup store, and a previously-seen ID is rejected.

### D4. Raw-body preservation: Kernel-owned middleware

Signature verification requires the **byte-exact request body** the provider signed, not the deserialized object graph. ASP.NET Core's default middleware pipeline reads the request body once and disposes it; verification needs to read it twice (once for verification, once for handler deserialization).

The Grid commits a **Kernel-owned middleware** — `HoneyDrunk.Kernel.Webhooks.RawBodyPreservationMiddleware` — that:

- Is registered explicitly per webhook receiver route (not Grid-globally; raw-body buffering on every request is a memory tax we don't pay everywhere).
- Calls `HttpRequest.EnableBuffering()` with a configurable size cap (default 1 MiB; providers we receive from do not emit larger payloads in practice).
- Reads the body into a `byte[]` once, exposes it as a request feature (`IRawWebhookBodyFeature`), and resets the stream position so downstream model binding still works.
- Refuses to process bodies larger than the cap with `413 Payload Too Large`.

The middleware lives in Kernel — not per-Node — because the raw-body-preservation problem is purely ASP.NET-Core-shaped and the solution is reusable verbatim across every receiver. Per-Node ownership would invite per-Node implementation drift on the exact ASP.NET Core gotchas (`HttpContext.Request.Body` vs `BodyReader`, async disposal, buffer disposal under exceptions) that are the hardest part of getting this right.

Function-App-hosted receivers ([ADR-0037](./ADR-0037-payment-and-billing-integration.md) D4's Stripe handler is the canonical case) do not go through ASP.NET Core middleware. They consume the raw body via the Functions binding (the trigger's `byte[]` or `Stream` overload), then call into the same verification helper (D7) with the bytes in hand. The middleware is the ASP.NET Core ergonomics; the helper is the verification.

### D5. Secret storage: Vault, with the `webhook-{provider}-{purpose}-signing-secret` convention

Every webhook signing secret lives in Vault per Invariant 9 and [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md). The naming convention:

```
webhook-{provider}-{purpose}-signing-secret
```

Worked examples:

- `webhook-stripe-billing-signing-secret` (per-environment in `kv-hd-billing-{env}` once Billing's vault exists).
- `webhook-github-observe-signing-secret` (in `kv-hd-observe-{env}` when the Observe connector lands).
- `webhook-resend-notify-signing-secret`, `webhook-twilio-notify-signing-secret` (in `kv-hd-notify-{env}`).
- `webhook-operator-communications-signing-secret` (in `kv-hd-comm-{env}`).

`{provider}` is the external provider name (or `internal` for Studios-emitted webhooks once the outbound ADR lands). `{purpose}` is the consuming Node's short name when one provider serves multiple Nodes, or a discriminator when one provider feeds multiple endpoints in the same Node. The secret length is provider-determined; the secret value is opaque to the Grid.

Webhook signing secrets are Tier-2 secrets per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 5 (third-party, ≤ 90-day rotation SLA). Where the provider supports overlapping keys during rotation (D6), the rotation Function (`HoneyDrunk.Vault.Rotation` per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 2) writes the new version and Event Grid invalidates per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 3. Where the provider does not support rotation through an API (Twilio at time of writing), Tier 2's portal-runbook fallback applies: the runbook ends in a Key Vault write, and the receiver picks the new version up automatically per Invariant 21.

### D6. Key rotation: multi-key verification, accept first match

Every webhook verifier supports verifying against **N candidate signing secrets simultaneously**, accepting the first one that matches. The default N is 2 (current + previous), aligned with the rotation overlap window most providers expose. Configurable per receiver if a provider supports more.

The verifier reads candidate secrets from a single Vault entry whose value is either:

- A bare secret string (N=1; the trivial case for steady state), or
- A newline-separated list of secret strings (N>1; during rotation), or
- A JSON object `{ "active": "...", "previous": ["...", "..."] }` for receivers that need explicit labeling.

The receiver chooses the format. The verifier accepts all three shapes; new receivers SHOULD use the JSON object form for clarity.

This matches Stripe's documented rotation pattern (two endpoint-signing secrets coexist during rotation), GitHub's (the documented "rotate secret" workflow), and Svix's (signing-secret history is queryable from their API). It is also the shape that [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 3's cache-invalidation pathway composes with cleanly — the secret store reads the new value on Event-Grid-driven invalidation; the verifier reads the new value-list on next call.

Rejected: per-key Vault entries (`webhook-stripe-billing-signing-secret-v1`, `-v2`). The convention conflicts with Invariant 21's "applications must never pin to a specific secret version" rule by requiring the receiver to enumerate version-suffixed keys. The single-key-multi-value shape composes correctly with both `ISecretStore` and Event Grid invalidation.

### D7. Verification helper: Kernel-owned interface and SHA-256 default; per-provider verifiers register their own

The verification helper lives in **`HoneyDrunk.Kernel.Abstractions`** as `IWebhookSignatureVerifier`:

```csharp
public interface IWebhookSignatureVerifier
{
    string ProviderName { get; }
    ValueTask<WebhookVerificationResult> VerifyAsync(
        WebhookVerificationRequest request,
        CancellationToken cancellationToken = default);
}
```

`WebhookVerificationRequest` is a record carrying the raw body bytes, the timestamp the provider supplied, the signature header value(s), the candidate signing secrets (resolved from Vault per D5/D6), and an `IReadOnlyDictionary<string, string>` of provider-specific extras (Twilio needs the full URL, Svix needs the message ID, etc.). `WebhookVerificationResult` is a record exposing a `bool IsValid`, an optional reason string for diagnostics, and the verified timestamp.

`HoneyDrunk.Kernel` ships a single concrete: `HmacSha256SignatureVerifier`, which covers the GitHub-Hub-Signature-256 / Stripe / Svix shape (timestamp-prefixed HMAC-SHA256 over a configurable canonical-string pattern). Per-provider verifiers (a `TwilioSignatureVerifier`, a `StripeSignatureVerifier` that handles the `t=...,v1=...` format, a `SvixSignatureVerifier` that handles the multi-version `v1,...` format) live next to the receiver they serve in the consuming Node, register against this interface, and reuse Kernel's HMAC primitives where the algorithm matches.

The records (`WebhookVerificationRequest`, `WebhookVerificationResult`) follow the Grid naming convention — records drop the `I`, interfaces keep it.

Rejected alternatives:

- **Per-Node-only verification with a copy-paste utility library.** Each Node owns its own copy of the HMAC plumbing. Drift is the failure mode; this is exactly what every other Grid-wide primitive (Vault, Transport, Audit) rejected.
- **A new `HoneyDrunk.Webhooks` Node.** Plausible if the volume of provider-specific verifiers were large. Today it is four. The Kernel-interface-plus-per-Node-implementation shape composes with the existing Vault and Transport patterns; lifting webhooks into their own Node would invent boundaries we don't need yet. Revisit if the number of distinct provider verifiers crosses ~10, or if a credible cross-Node webhook orchestration use case appears (none today).

### D8. Replay protection storage: reuse `IIdempotencyStore` per [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md)

After signature verification passes, each receiver dedupes the inbound webhook by its **provider-supplied event ID** (Stripe's `event.id`, GitHub's `X-GitHub-Delivery`, Svix's `svix-id`, Twilio's `MessageSid`-prefixed key) using the `IIdempotencyStore` contract committed in [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md) D2.

The pattern:

1. Verifier confirms signature and timestamp window (D3).
2. Receiver constructs an idempotency key of the form `webhook:{provider}:{event-id}` and calls `IIdempotencyStore.TryClaim` against the receiver's own consumer-group.
3. If the claim succeeds, the receiver processes the webhook (emit to Service Bus topic per [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md), persist to a buffer per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D2, normalize through `IObservationEvent` per Invariant 30 — whatever the receiver's downstream shape is). On completion the claim is closed with `Succeeded`.
4. If the claim returns "already completed," the receiver returns `200 OK` (the webhook was already processed; the provider should not retry) without re-executing side effects.
5. If the claim returns "in flight" (a concurrent delivery in the same window), the receiver returns `409 Conflict` with the per-D12-style envelope so the provider retries after backoff.

TTL is the provider's documented redelivery window plus margin — Stripe documents up to 72 hours of redelivery, GitHub up to ~8 hours, Svix per-tenant-configurable — rounded up to the nearest [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md) tier. Default is the [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md) D4 "Standard" tier (7 days); receivers integrating with providers whose redelivery window is longer override at registration to the 30-day "Billing/Audit" tier. The Stripe receiver uses 30 days because Stripe's audit retention pairs with their redelivery semantics.

Rejected alternative: a webhook-specific dedup store. The dedup semantics are identical to [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md)'s claim/complete pattern; inventing a parallel store would duplicate exactly the storage-and-TTL machinery already governed. Reuse is the right call.

### D9. Response convention: 200 / 401 / 400 / 409 / 413, no body on success

Receivers return a narrow, fixed set of response codes:

- **`200 OK`** — verification passed; webhook accepted (whether processed-now or already-processed-deduped per D8). Empty response body. Providers do not consume response bodies; emitting one is wasted bytes.
- **`400 Bad Request`** — verification passed structurally but the payload is malformed, the replay window check failed (D3), or a required field is missing. Response body is a minimal RFC 7807 envelope per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D12 — the same envelope used Grid-wide. The `type` URL identifies the specific failure (`https://errors.honeydrunkstudios.com/webhooks/replay-window-exceeded`, `.../malformed-payload`, `.../missing-signature-header`).
- **`401 Unauthorized`** — signature verification failed. Empty response body (do not leak which check failed; attackers do not get diagnostics). Logging captures the failure detail per D10.
- **`409 Conflict`** — a concurrent delivery of the same idempotency key is in flight per D8 step 5. RFC 7807 envelope citing `.../webhook-delivery-in-flight`. The provider should retry after backoff.
- **`413 Payload Too Large`** — body exceeded the D4 cap. RFC 7807 envelope.
- **`5xx`** — only for genuine server errors (Vault unavailable, dedup store unavailable, downstream Service Bus emit failed). Providers retry on 5xx; the receiver expects to be retried. Never use 5xx for a verification failure; that would teach the provider to keep retrying invalid signatures forever.

Receivers do **not** distinguish "signature header missing" from "signature header malformed" from "signature didn't match" in the response — all three are 401. The distinction lives in the per-receiver log line (D10) and the audit emit (D11).

### D10. Logging and redaction: redact secrets and full bodies; preserve hashes

Logging from a webhook receiver follows three rules:

- **Never log signing secrets, candidate or active, in any form.** Invariant 8 already mandates this Grid-wide; this restates it because webhook receivers are the load-bearing site for the rule.
- **Never log the raw signed body in full.** The body is provider-classified data; for Stripe and Twilio receivers it routinely contains PII (cardholder names, recipient phone numbers, message bodies) per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md). Log the body's **size in bytes** and a **SHA-256 hash prefix** (first 16 hex characters) for cross-reference; that is enough to correlate to the audit emit (D11) and the dedup store entry (D8) without exposing payload contents to observability.
- **Always log the verification outcome, the signature header presence, the timestamp drift in seconds, and the dedup outcome.** That is the diagnostic surface a `security` specialist review needs without exposing what was signed.

The per-Node log envelope adheres to [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md)'s structured-log schema; the verification-specific fields land under a `webhook.*` namespace.

### D11. Audit emit on every webhook receipt

Every successful webhook verification produces an `IAuditLog` emit per Invariant 47 and [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md). The audit record carries:

- `category` = `WebhookReceipt`
- `target` = the provider name plus the receiver's logical name (`stripe:billing`, `github:observe`, etc.)
- `outcome` = `Succeeded` (signature passed) or `Denied` (signature failed) or `Deduped` (dedup hit per D8)
- The verified timestamp, the dedup key, and the body's hash prefix (per D10's "preserve hashes" rule)
- **No body contents.** [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) D3 requires sensitive-field redaction; webhook payloads are sensitive by default.

A failed verification (D9 `401`) emits an audit record with outcome `Denied`. This is the surface a forensic review uses to detect attempted webhook forgery; without it, the rejection lives only in telemetry, which is sampled and retention-bounded (Invariant 47).

### D12. Receiver registration and DI shape

Each Node hosting webhook receivers registers them through a Kernel-supplied extension:

```csharp
services.AddWebhookReceiver<StripeSignatureVerifier>(options =>
{
    options.SecretName = "webhook-stripe-billing-signing-secret";
    options.ReplayWindow = TimeSpan.FromMinutes(5);  // D3 default; here for explicitness
    options.DedupTtl = TimeSpan.FromDays(30);        // Billing tier per D8
    options.MaxBodyBytes = 1_048_576;                // D4 default; explicit per-receiver
});
```

The extension binds the verifier, wires the raw-body middleware (D4) onto the receiver's route, registers the dedup-store lookup (D8), and registers the audit emitter (D11). Receivers compose their handler against the verified-and-deduped surface — the handler does not see a webhook until verification, replay, and dedup have all passed.

ASP.NET-Core-hosted receivers consume the middleware-and-route shape. Function-App-hosted receivers (Stripe per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D4) skip the middleware (the binding gives them the bytes already) and call directly into `IWebhookSignatureVerifier` and `IIdempotencyStore`. The verification surface is the same; the host plumbing differs.

### D13. Out of scope

- **Outbound (Studios-emitted) webhooks.** The "first-party HMAC-SHA256 over `timestamp.body`" anchor in D1 is recorded for the future outbound-webhook ADR; nothing in this ADR commits a Studios-emitted webhook surface. [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) explicitly defers outbound webhooks to that future ADR.
- **Tenant-supplied callback URL allowlisting.** Outbound concern.
- **Webhook payload schema validation beyond signature verification.** Per-receiver concern; this ADR governs the verification boundary, not the receiver's per-event handling.
- **Cross-receiver orchestration.** Each receiver is independent. If a Grid-wide "webhook hub" pattern becomes credible later, that is a future ADR (likely the same one that would lift webhooks into a `HoneyDrunk.Webhooks` Node — see D7 alternative).

## Consequences

### Affected Nodes

- **`HoneyDrunk.Kernel`** — gains `IWebhookSignatureVerifier` in `Kernel.Abstractions`, the `HmacSha256SignatureVerifier` default in `HoneyDrunk.Kernel`, the `RawBodyPreservationMiddleware`, and the `AddWebhookReceiver<T>` extension. Spec-level additions, not breaking. Contract-shape canary scope expands per Invariant 46-style coverage.
- **`HoneyDrunk.Billing.Webhooks`** (planned per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D4) — first concrete consumer at standup. Implements `StripeSignatureVerifier`, registers it via `AddWebhookReceiver<>`, uses `IIdempotencyStore` for dedup with the 30-day TTL.
- **`HoneyDrunk.Notify`** — Resend (Svix-shaped) and Twilio receivers compose against this ADR. Existing webhook code (if any) is amended in a separate rollout packet; transitional behavior is "verify with old code, audit-emit per D11" so the audit surface lights up before the verifier consolidation lands.
- **`HoneyDrunk.Observe`** — the GitHub-connector webhook receiver (Q3 roadmap) composes against this ADR from day one. The receiver's normalized output through `IObservationEvent` is unchanged; only the verification entry-point is governed here.
- **`HoneyDrunk.Communications`** — Operator-approval-event subscriber receivers and any tenant-supplied callbacks compose against this ADR. The receiver work was about to start; this ADR is its prerequisite.
- **`HoneyDrunk.Vault`** — no contract change. Existing `ISecretStore` reads carry the new secrets; existing rotation pathway (Tier 2 → Tier 3) handles them per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md).
- **`HoneyDrunk.Audit`** — receives `WebhookReceipt` audit records per D11. New `category` value; no contract change (`IAuditLog` already accepts arbitrary category strings per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) D3).
- **`HoneyDrunk.Vault.Rotation`** — the rotation Function gains the webhook-signing-secret rotators where the provider supports it (Stripe today; GitHub on rotation-API; Svix on rotation-API). Twilio falls through to the portal-runbook fallback.

### Cascade impact

Cross-checked against `catalogs/relationships.json`:

- Kernel changes propagate to every Node that consumes `Kernel.Abstractions` (~all of them). Risk is bounded: the additions are interfaces and records (no shape drift on existing types); the contract-shape canary on `Kernel.Abstractions` is the existing gate.
- `Billing.Webhooks` is the first Node committed by [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D4 to depend on this surface; its standup ADR (a follow-up) will cite this ADR as a prerequisite.
- Notify, Observe, and Communications each take a runtime dependency on `Kernel.Abstractions` already; no new edges in the relationship graph.
- The Audit consumer-edge from each webhook-hosting Node already exists per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md); the `WebhookReceipt` emit is a new category, not a new edge.

### Invariants

This ADR proposes the following new invariants (final numbers assigned at acceptance by the scope agent; constitution edits are follow-up work, not authored here):

- **Inbound webhook receivers must verify provider signatures via `IWebhookSignatureVerifier` and reject requests outside a 5-minute replay window.** Enforced at receiver registration; a Node hosting a webhook surface without the verifier registered is a canary-eligible failure.
- **Inbound webhook receivers must dedupe by `webhook:{provider}:{event-id}` against `IIdempotencyStore` before invoking handler side effects.** Enforced per [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md) D2's existing pattern.
- **Webhook signing secrets follow the `webhook-{provider}-{purpose}-signing-secret` Vault naming convention.** Enforced by the `security` specialist review per [ADR-0046](./ADR-0046-specialist-review-agents.md) and by the `scope` agent at packet authoring.
- **Every webhook receipt produces an `IAuditLog` emit with category `WebhookReceipt`, outcome `Succeeded` / `Denied` / `Deduped`, and no payload body in the record.** Reinforces Invariant 47.

### Operational consequences

- **The raw-body middleware adds a per-receiver memory cost equal to the size cap (1 MiB default).** Acceptable at Grid scale; the cap is configurable per-receiver if a future provider's payload exceeds it.
- **Multi-key verification adds one Vault read per inbound webhook.** Mitigated by Vault's caching layer per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 3. Cache invalidation on Event Grid means rotation propagates within the standard window.
- **Dedup TTL across the Stripe receiver is 30 days; the dedup-store growth on a high-volume Stripe surface is non-trivial.** Per [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md) D4 the dedup store's capacity is sized to its busiest consumer; the Stripe receiver becomes the sizing anchor for the Billing-side dedup store.
- **Audit emit on every webhook receipt — including denied ones — increases the audit-record volume.** The `WebhookReceipt` category is a forensic surface; volume is acceptable, retention is governed by [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) D4's "distinct from observability" rule.
- **The verifier-helper-in-Kernel decision (D7) means every Node that hosts a webhook surface takes a dependency on Kernel.Abstractions — which they already do.** No new dependency edge; the substrate is reused.

### Follow-up work

Not edited by this ADR — listed for the scope agent's packet wave at acceptance time. The user runs the scope agent separately per the standard workflow.

- Add a `webhooks` section to `repos/HoneyDrunk.Kernel/integration-points.md` describing the `IWebhookSignatureVerifier` interface, the `RawBodyPreservationMiddleware`, and the `AddWebhookReceiver<T>` extension.
- Update `catalogs/contracts.json` with `IWebhookSignatureVerifier` and the supporting `WebhookVerificationRequest` / `WebhookVerificationResult` records under `honeydrunk-kernel`.
- Add the proposed invariants to `constitution/invariants.md` with scope-agent-assigned numbers at acceptance time.
- File the Kernel implementation packet — `IWebhookSignatureVerifier`, `HmacSha256SignatureVerifier`, `RawBodyPreservationMiddleware`, `AddWebhookReceiver<T>`, contract-shape canary additions.
- File the `HoneyDrunk.Billing.Webhooks` scaffold packet ([ADR-0037](./ADR-0037-payment-and-billing-integration.md) D4 standup) — depends on the Kernel implementation packet landing first.
- File Notify-side amendments for Resend and Twilio receivers to compose against `IWebhookSignatureVerifier`; bridge the existing receiver code through the transitional pattern.
- File the Observe GitHub-connector receiver packet when the Q3 roadmap pulls on it.
- File a Communications packet that composes the Operator-approval-event subscriber against this ADR.
- Update `.claude/agents/review.md` and the `security` specialist review prompt with a webhook-receiver checklist: verifier registered, raw-body middleware on the route, secret name follows convention, dedup TTL set, audit emit wired.
- Confirm with [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md)'s rotation surface that Stripe, GitHub, and Svix signing-secret rotation are added to `HoneyDrunk.Vault.Rotation`'s scheduled-rotator list at the next rotation-Function packet wave.

## Alternatives Considered

### Uniform Grid-wide signature header

Considered: rewrite every inbound webhook's signature header into `X-HoneyDrunk-Signature` at the receiver edge, so the verification surface accepts one header shape. Rejected because the underlying signing schemes are not uniform — there is no canonical payload shape an `X-HoneyDrunk-Signature` could carry that survives Stripe-vs-Twilio-vs-Svix differences. The per-provider adapter (D2) is the right abstraction layer.

### Per-Node webhook verification with a shared copy-pasteable utility

Considered: ship a `HoneyDrunk.Webhooks.Common` NuGet package with helper functions; each Node calls into the helpers from its own receivers without a common interface. Rejected per the Grid's standing preference for abstraction-plus-implementation splits (Vault, Transport, Audit) — copy-paste utility libraries drift. The interface-in-Kernel-plus-per-provider-implementation shape composes with the existing pattern.

### A new `HoneyDrunk.Webhooks` Node hosting all verifiers

Considered: a dedicated Node owning every provider verifier, with a contract-shape canary specific to the verifier surface. Rejected as premature. Four provider verifiers (Stripe, GitHub, Svix, Twilio) is not enough Node-shaped substance to justify the standup overhead. Revisit if the number crosses ~10, or if a credible Grid-wide webhook-orchestration use case (a "webhook hub" that re-emits inbound webhooks to multiple in-Grid consumers as Service Bus topic events) appears. Today's pattern — emit-on-receipt-to-Service-Bus per receiver — handles the fanout without an intermediate Node.

### Looser replay window (15 minutes, 1 hour)

Considered: pin the replay window at the loosest value any provider's documentation suggests (Stripe's docs allow up to ~5 minutes by default; some providers allow custom tolerances up to hours). Rejected. The marginal cost of a 5-minute window is provider-side retries on the rare legitimately-late delivery; the marginal benefit is a shorter replay surface for stolen-secret scenarios. The OWASP cheat sheet and NIST SP 800-63B both treat short replay windows as the discipline.

### Per-key Vault entries for multi-key rotation

Considered: store each candidate signing secret in its own Vault entry (`webhook-stripe-billing-signing-secret-v1`, `-v2`) and enumerate version-suffixed names. Rejected because the convention conflicts with Invariant 21 (no version pinning at the consumer side). The single-Vault-entry-with-list-value shape (D6) composes correctly with `ISecretStore` and Event Grid invalidation.

### A webhook-specific dedup store separate from `IIdempotencyStore`

Considered: a `IWebhookDedupStore` interface scoped to webhook receivers, with its own backing and its own TTL semantics. Rejected because the dedup semantics are identical to [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md)'s claim/complete pattern. Reuse is the right call. A receiver-specific TTL is expressed by the per-consumer-group TTL configuration that [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md) D4 already exposes.

### Diagnostic responses on signature failure (`401` with reason in the body)

Considered: return a structured RFC 7807 envelope on `401` describing exactly which check failed (missing header, malformed signature, signature mismatch, timestamp out of window). Rejected because exposing the failure reason to an attacker teaches them how to construct a valid-looking request. The diagnostic detail lives in logs (D10) and the audit emit (D11), not in the response body.

### Verification-only-at-the-receiver, no audit emit on receipt

Considered: skip the audit emit on every webhook receipt; rely on telemetry for the forensic surface. Rejected because telemetry is sampled and retention-bounded (Invariant 47). Webhook receipt is exactly the kind of attributable event the audit substrate is designed to carry — provider, target, outcome, timestamp. The volume is acceptable; the forensic surface is load-bearing.

### Defer until the first non-Stripe webhook surface materializes

Considered: let [ADR-0037](./ADR-0037-payment-and-billing-integration.md)'s Stripe handler ship its own bespoke verifier, decide the Grid pattern later when the second webhook surface lands. Rejected because the second, third, and fourth webhook surfaces (Notify-Resend, Notify-Twilio, Observe-GitHub) are all within one release window of the first. The de-facto pattern set by whichever ships first becomes hard to dislodge; settling the pattern now is cheaper than reconciling four divergent implementations later.
