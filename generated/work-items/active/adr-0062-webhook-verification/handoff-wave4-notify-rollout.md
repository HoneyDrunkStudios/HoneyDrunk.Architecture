# Handoff — Wave 4: Notify Webhook-Receiver Rollout

**Initiative:** `adr-0062-webhook-verification`
**Wave transition:** Waves 2–3 (Kernel surface + rotation + review prompts) → Wave 4 (Notify receivers)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Waves 2–3 landed

- **Packet 02** — `HoneyDrunk.Kernel` at the new minor version. `HoneyDrunk.Kernel.Abstractions` ships `IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, `WebhookVerificationRequest`, `WebhookVerificationResult`. `HoneyDrunk.Kernel` ships `HmacSha256SignatureVerifier` (the SHA-256 default), `RawBodyPreservationMiddleware`, `WebhookReceiverOptions`, and `services.AddWebhookReceiver<TVerifier>(options => …)`.
- **Packet 03** — `HoneyDrunk.Vault.Rotation` ships scheduled rotators for `webhook-stripe-billing-signing-secret`, `webhook-github-observe-signing-secret`, `webhook-resend-notify-signing-secret`. Twilio gets a portal-runbook fallback ending in a Vault write to `webhook-twilio-notify-signing-secret`. All rotators write the D6 multi-key JSON object shape `{ "active": "<new>", "previous": ["<old>"] }`.
- **Packet 04** — `.claude/agents/review.md` and the `security` specialist prompt carry the ADR-0062 webhook-receiver checklist. New webhook-receiver PRs are now reviewed against the ADR's load-bearing rules.

The Kernel surface, the rotation path, and the review enforcement are now in place. Wave 4 brings Notify's launch-shape webhook receivers onto the surface.

## What Wave 4 must deliver (packet 05)

Build (or migrate existing in-flight code for) two inbound webhook receivers in **`HoneyDrunk.Notify`** (live Node, v0.2.0 per the launch tracker; confirm current version at execution time):

- **Resend receiver** — `/webhooks/resend` route (or whatever the Resend dashboard has registered). `SvixSignatureVerifier` implementing `IWebhookSignatureVerifier`, using HMAC-SHA256 over `{msg_id}.{timestamp}.{body}` with Svix-shape multi-`v1,...` candidates. Reads `webhook-resend-notify-signing-secret` from `kv-hd-notify-{env}` in the D6 multi-key shape.
- **Twilio receiver** — `/webhooks/twilio` route (or whatever the Twilio Console has registered). `TwilioSignatureVerifier` implementing `IWebhookSignatureVerifier`, using HMAC-SHA1 over `{full request URL} + concat(<sorted form-encoded body params>)`. Reads `webhook-twilio-notify-signing-secret` from `kv-hd-notify-{env}` in the D6 multi-key shape.
- Per-provider verifiers live **next to the receiver they serve in Notify**, NOT in Kernel (ADR-0062 D7).
- Both receivers composed via `services.AddWebhookReceiver<T>(options => …)`. Dedup via `IIdempotencyStore` (ADR-0042 contract; Cosmos backing in deployed environments, InMemory in tests). Audit emit via `IAuditLog` with category `WebhookReceipt`.
- Bump the whole `HoneyDrunk.Notify` solution one minor version (invariant 27).

## Audit existing receiver code before starting

Notify's webhook receivers may already exist in some form (in-flight per ADR-0027 Notify Cloud GA). The executor must audit the repo at the start of this packet — look under `HoneyDrunk.Notify.Hosting.AspNetCore/`, `HoneyDrunk.Notify.ProviderSupport/`, and the Resend / Twilio provider packages. Two cases:

1. **No receiver code exists yet** — greenfield build on the ADR-0062 surface. The cleaner path.
2. **Bespoke receiver code already exists** — migrate. Move existing signature-verification into a `SvixSignatureVerifier` / `TwilioSignatureVerifier` implementing `IWebhookSignatureVerifier`; replace custom raw-body buffering with `RawBodyPreservationMiddleware`; wire `IIdempotencyStore` dedup at the route; add the `WebhookReceipt` audit emit.

ADR-0062 Consequences allows a transitional "verify with old code, audit-emit per D11" stance if the consolidation needs to land in two PRs — state the staging in the PR.

State which case applies in the PR description.

## Per-provider implementation notes

### Resend / Svix verifier

```csharp
public class SvixSignatureVerifier : IWebhookSignatureVerifier
{
    public string ProviderName => "resend";  // (or "svix" — pick one and stick with it; audit target is "resend:notify" either way)

    public async ValueTask<WebhookVerificationResult> VerifyAsync(
        WebhookVerificationRequest request,
        CancellationToken cancellationToken = default)
    {
        // Headers: svix-id, svix-timestamp, svix-signature (whitespace-separated v1,<sig> entries).
        // Canonical string: $"{msg_id}.{timestamp}.{Encoding.UTF8.GetString(request.Body.Span)}".
        // Iterate request.CandidateSecrets; HMACSHA256 each; base64; compare via FixedTimeEquals.
        // First match → IsValid = true, VerifiedTimestamp = parsed timestamp.
        // No match → IsValid = false, Reason = "signature did not match any candidate".
    }
}
```

The Kernel `HmacSha256SignatureVerifier` may cover this with a Svix-shaped canonical-string builder — in which case `SvixSignatureVerifier` is a thin shell that constructs the request and delegates. Either path is valid; prefer the delegation path if the Kernel default is flexible enough.

### Twilio verifier

```csharp
public class TwilioSignatureVerifier : IWebhookSignatureVerifier
{
    public string ProviderName => "twilio";

    public async ValueTask<WebhookVerificationResult> VerifyAsync(
        WebhookVerificationRequest request,
        CancellationToken cancellationToken = default)
    {
        // Headers: X-Twilio-Signature.
        // Extras["RequestUrl"] = full request URL with query string.
        // Extras["FormParams"] = parsed form-encoded body params, sorted alphabetically (encoded in PR's choice of shape).
        // Canonical string: $"{requestUrl}{string.Concat(sortedFormParams.Select(p => p.Key + p.Value))}".
        // Iterate request.CandidateSecrets; HMACSHA1 (not SHA256!) each; base64; compare via FixedTimeEquals.
        // Twilio has no signed timestamp → VerifiedTimestamp = DateTimeOffset.UtcNow (placeholder).
        // The receiver must NOT enforce the 5-minute window for Twilio (D3 fallback — dedup is replay protection).
    }
}
```

The Kernel default verifier does NOT cover this case (SHA-1, not SHA-256). `TwilioSignatureVerifier` is a from-scratch implementation using BCL `HMACSHA1`.

### Twilio's no-signed-timestamp distinction is load-bearing

ADR-0062 D3's 5-minute replay window applies to providers that supply a signed timestamp. Twilio doesn't. D3's fallback applies: "the inbound signature is verified, the message ID is looked up in the dedup store, and a previously-seen ID is rejected." For Twilio, the dedup key `webhook:twilio:{MessageSid}` IS the replay protection.

Document this in:
- Code comments on `TwilioSignatureVerifier` and the Twilio receiver endpoint.
- The Notify webhook README's receiver model section.
- The PR description (so the reviewer sees the explicit fallback note).

The Twilio receiver MUST NOT enforce a 5-minute window — there is no signed timestamp to compare against. The Kernel extension's default `ReplayWindow = TimeSpan.FromMinutes(5)` may need a per-receiver override (e.g. `options.ReplayWindow = TimeSpan.Zero` to disable, or a sentinel value) — confirm at execution time how packet 02's extension models this and pick the right config.

## Composition shape

```csharp
services.AddWebhookReceiver<SvixSignatureVerifier>(options =>
{
    options.SecretName = "webhook-resend-notify-signing-secret";
    options.ReplayWindow = TimeSpan.FromMinutes(5);  // D3 standard
    options.DedupTtl = TimeSpan.FromDays(7);          // D8 Standard tier
    options.MaxBodyBytes = 1_048_576;                 // D4 default
});

services.AddWebhookReceiver<TwilioSignatureVerifier>(options =>
{
    options.SecretName = "webhook-twilio-notify-signing-secret";
    // Replay-window override or disable — see "no-signed-timestamp" note above.
    options.DedupTtl = TimeSpan.FromDays(7);
    options.MaxBodyBytes = 1_048_576;
});
```

Per-provider header adapters (ADR-0062 D2) live next to their receiver — they read the provider's specific headers off the HTTP request and stuff them into `SignatureHeaders` / `Extras` for the verifier. Resend adapter reads `svix-id`, `svix-timestamp`, `svix-signature`. Twilio adapter reads `X-Twilio-Signature`, the request URL, and the form-encoded body parameters.

## Dedup keys

- Resend: `webhook:resend:{svix-id}` — Svix's `svix-id` is the unique-per-message identifier.
- Twilio: `webhook:twilio:{MessageSid}` — Twilio's `MessageSid` is unique per message-status update (sent in the form body).

Both use the 7-day TTL (D8 Standard; Notify is not Billing/Audit). A duplicate inbound webhook hits the already-completed fast path of `IIdempotencyStore.TryClaim` and the side effect (delivery-status update) runs exactly once.

## Response convention (D9)

The Kernel extension wires the response codes. Verify the wiring:
- `200 OK` — verified + (processed or already-deduped). Empty body.
- `400 Bad Request` — replay window exceeded, malformed payload, missing signature header. RFC 7807 envelope.
- `401 Unauthorized` — signature failed. **Empty body** — no diagnostic detail (D9 + D10).
- `409 Conflict` — concurrent delivery in flight (dedup `Claimed-not-Completed`). RFC 7807.
- `413 Payload Too Large` — body cap exceeded. RFC 7807.
- `5xx` — only for genuine server errors (Vault unavailable, dedup store unavailable, downstream emit failed). Providers retry on 5xx.

Receivers do NOT distinguish "header missing" from "malformed" from "signature mismatch" in the response — all three are 401 with empty body. The distinction lives in the per-receiver log and audit emit.

## Logging and audit (D10, D11)

Per-receipt log line: verification outcome, signature header presence, timestamp drift in seconds (for Resend), dedup outcome, body size, body SHA-256 prefix (first 16 hex chars). NO signing secret values, NO raw body, NO full signature header value.

Per-receipt audit emit:
- `category = "WebhookReceipt"`.
- `target = "resend:notify"` or `"twilio:notify"`.
- `outcome = Succeeded | Denied | Deduped`.
- The verified timestamp (or `DateTimeOffset.UtcNow` for Twilio), the dedup key, and the body's SHA-256 prefix.
- No body contents.

The Kernel extension wires the audit emitter against `IAuditLog`; verify the wiring with a unit test or trace inspection in the integration test.

## Frozen / do-not-touch

- **Notify's preference/cadence/suppression decision logic** — invariant 41 says that lives in Communications, not Notify. This packet touches only webhook receipt → delivery-status update (delivery-mechanics).
- **`ICommunicationOrchestrator` / `IMessageIntent` / `IPreferenceStore` / `ICadencePolicy`** — Communications' hot-path contracts, not Notify's concern.
- **The Kernel verifier interface and middleware** — fixed by packet 02; consume, don't modify.
- **The `IIdempotencyStore` contract** — fixed by ADR-0042 packet 02; consume, don't modify.

## Invariants binding Wave 4

- **Invariant 8** — Secret values never in logs/traces/exceptions/telemetry. Constant-time signature comparison (`CryptographicOperations.FixedTimeEquals`).
- **Invariant 9** — Vault is the only source of secrets. Signing secrets via `ISecretStore`; never read from env.
- **Invariant 27** — Bump every non-test `.csproj` in `HoneyDrunk.Notify` together.
- **Invariant 41** — Preference/cadence/suppression in Communications; delivery in Notify. Don't move logic across the boundary.
- **Invariant 51** — No `Thread.Sleep` in test code; advance an injected `TimeProvider` for replay-window tests.
- **Invariant 78** — Verifier registered + 5-minute replay window (with the Twilio fallback noted).
- **Invariant 79** — Dedup by `webhook:{provider}:{event-id}` before any side effect.
- **Invariant 80** — Vault secret name `webhook-{provider}-{purpose}-signing-secret`.
- **Invariant 81** — `WebhookReceipt` audit emit on every receipt.

## Human Prerequisites carried into Wave 4

**Publish the upstream NuGet package first — agents never tag or publish.** Wave 4 compiles against `HoneyDrunk.Kernel` at packet 02's new minor version; that artifact reaches the package feed only after a human pushes a git release tag on `HoneyDrunk.Kernel` after packet 02 merges.

**Seed the Vault entries in the D6 multi-key shape:**
- `webhook-resend-notify-signing-secret` in `kv-hd-notify-{env}` — value from the Resend dashboard. Seed as JSON: `{ "active": "<value>", "previous": [] }`.
- `webhook-twilio-notify-signing-secret` in `kv-hd-notify-{env}` — value is the Twilio Account Auth Token. Seed as JSON: `{ "active": "<value>", "previous": [] }`.

**Configure the webhook URLs in the provider dashboards:**
- Resend dashboard: webhook endpoint URL pointing at Notify's `/webhooks/resend` route (or PR's chosen route).
- Twilio Console: status callback URL pointing at Notify's `/webhooks/twilio` route.

Both providers begin sending events immediately on save.

**Cosmos dedup account per environment** must exist for Notify's idempotency consumer-group (ADR-0042 packet 03's prereqs apply here). The receiver dedup uses the same Cosmos store and consumer-group as Notify's existing idempotency rollout from the ADR-0042 initiative.

**Managed Identity RBAC** — the Notify Container App's MI needs Cosmos data-plane RBAC on the dedup account and `get` permission on `kv-hd-notify-{env}` for the new webhook signing secrets.

The code work in packet 05 does not require the live Cosmos account — tests run against the InMemory `IIdempotencyStore`. The code work does require the upstream Kernel package to be published.

## Acceptance gate for the wave

Packet 05's PR passes the `pr-core.yml` tier-1 gate. The PR enumerates whether the receivers are greenfield or migrated. Both verifiers live next to the receivers in Notify (not in Kernel). Both receivers are registered via `AddWebhookReceiver<T>`. Dedup keys are correct. Audit emits with the right category, target, outcome. Logs carry no secrets, no raw bodies, only body size + SHA-256 prefix. The Twilio no-5-minute-window fallback is explicit in code, README, and PR. The Notify solution is bumped one minor version. README documents the webhook-receiver model.

Once packet 05 merges and Notify is deployed, Notify's launch-shape Resend and Twilio status-webhook receivers are operating on the Grid-canonical ADR-0062 pattern. The initiative closes (no Wave 5).
