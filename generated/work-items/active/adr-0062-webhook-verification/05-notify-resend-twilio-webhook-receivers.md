---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0062", "wave-4"]
dependencies: ["work-item:02"]
adrs: ["ADR-0062"]
wave: 4
initiative: adr-0062-webhook-verification
node: honeydrunk-notify
---

# Implement Resend (Svix) and Twilio status-webhook receivers on the ADR-0062 contract

## Summary
Build (or migrate existing in-flight code) two inbound webhook receivers in `HoneyDrunk.Notify` — the Resend (Svix-shaped) delivery-receipt receiver and the Twilio status-callback receiver — composed against the Kernel ADR-0062 surface from packet 02: `IWebhookSignatureVerifier`, `RawBodyPreservationMiddleware`, `AddWebhookReceiver<T>` extension. Ship per-provider verifiers (`SvixSignatureVerifier`, `TwilioSignatureVerifier`) next to their receivers per ADR-0062 D7. Dedupe via `IIdempotencyStore` per ADR-0062 D8 with the 7-day standard TTL. Emit `WebhookReceipt` audit per ADR-0062 D11.

## Context
ADR-0027 (Notify Cloud standup) and ADR-0038 (outbound sender identity and deliverability) commit Notify Cloud to launch with provider delivery-receipt webhooks as a launch-shape requirement: "Notify Cloud GA carries Resend and Twilio status-webhook integration as a launch-shape requirement. Provider-side delivery receipts are the only credible way the Cloud surface knows whether a tenant's send succeeded; the integration cannot be deferred past GA." ADR-0062's purpose is to settle the verification pattern *before* Notify ships its receivers ad-hoc.

Two provider shapes:
- **Resend uses Svix internally for its webhook signing.** Headers: `svix-id`, `svix-timestamp`, `svix-signature`. The signature is `v1,<base64-hmac-sha256>` over `{msg_id}.{timestamp}.{body}`. Multiple `v1,...` signatures may appear (multi-key during rotation; D6). HMAC-SHA256 — the Kernel default `HmacSha256SignatureVerifier` covers this with a Svix-shaped canonical-string builder; a thin `SvixSignatureVerifier` wraps the default with the Svix header-reading adapter (D2 per-provider adapter).
- **Twilio uses HMAC-SHA1 over `{full request URL with query string} + concat(sorted form-encoded body params)`.** Header: `X-Twilio-Signature`. Twilio's algorithm is provider-specific cryptographic obligation (ADR-0062 D1 accepts SHA-1 as-is for v1). The default `HmacSha256SignatureVerifier` does NOT cover this; `TwilioSignatureVerifier` is a from-scratch `IWebhookSignatureVerifier` implementation using `HMACSHA1` from the BCL and Twilio's documented canonical-string algorithm.

The dedup key shape per ADR-0062 D8:
- Resend / Svix: `webhook:resend:{svix-id}` (Svix's `svix-id` is the unique-per-message identifier).
- Twilio: `webhook:twilio:{MessageSid}` (Twilio's `MessageSid`, which is sent in the form body and is unique per message status update).

Per ADR-0062 D4, ASP.NET-Core-hosted receivers use the Kernel `RawBodyPreservationMiddleware`. Notify's existing receiver hosting is ASP.NET Core (per the Notify repo layout: `HoneyDrunk.Notify.Hosting.AspNetCore`). Both receivers are routed through the middleware-and-extension path; no Function-App receiver here (Function-App-hosted Stripe is the Billing.Webhooks future Node, not Notify).

> **Audit on what exists today.** ADR-0062 Consequences names Notify's receivers as "existing webhook code (if any)" with a transitional "verify with old code, audit-emit per D11" bridging stance. The executor must, at the start of this packet, audit the Notify repo for any in-flight webhook receiver code (look under `HoneyDrunk.Notify.Hosting.AspNetCore/`, `HoneyDrunk.Notify.ProviderSupport/`, and the Resend / Twilio provider packages). Two cases:
> 1. **No receiver code exists yet** — build the receivers from scratch on the ADR-0062 surface. This is the cleaner path; record it in the PR.
> 2. **Bespoke receiver code already exists** — migrate it to the ADR-0062 surface. Move the existing signature-verification logic into a `SvixSignatureVerifier` / `TwilioSignatureVerifier` implementing `IWebhookSignatureVerifier`; replace any custom raw-body buffering with `RawBodyPreservationMiddleware`; wire `IIdempotencyStore` dedup at the route; add the `WebhookReceipt` audit emit. ADR-0062 Consequences allows a transitional "verify with old code, audit-emit per D11" stance if the receiver consolidation needs to land in two PRs; state the staging in the PR.
>
> Default expectation: this is a launch-shape requirement per ADR-0027, so the receivers are either greenfield or very recent; option 1 is more likely. State the audit finding in the PR.

`HoneyDrunk.Notify` is a live Node (Notify v0.2.0 released per the Notification Subsystem Launch tracker; confirm current version at execution time). This packet is the only packet on the `HoneyDrunk.Notify` solution in this initiative — per invariant 27 it bumps the whole solution to the next minor version.

## Scope
- New (or migrated) `SvixSignatureVerifier : IWebhookSignatureVerifier` living next to the Resend receiver. Uses the Kernel `HmacSha256SignatureVerifier` (or its primitives) with the Svix canonical-string pattern (`{msg_id}.{timestamp}.{body}`) and a Svix-header adapter.
- New (or migrated) `TwilioSignatureVerifier : IWebhookSignatureVerifier` living next to the Twilio receiver. From-scratch HMAC-SHA1 over Twilio's documented canonical string; reads `X-Twilio-Signature` header and the full request URL (passed in `WebhookVerificationRequest.Extras["RequestUrl"]`).
- ASP.NET Core webhook endpoints for `/webhooks/resend` and `/webhooks/twilio` (or whatever routes match the addresses configured in the Resend and Twilio dashboards — these are configured *at the provider*, so the route is fixed by what was registered there; the PR should state the actual routes).
- DI registration via `services.AddWebhookReceiver<SvixSignatureVerifier>(options => { … })` and `.AddWebhookReceiver<TwilioSignatureVerifier>(options => { … })`.
- The `webhook-resend-notify-signing-secret` and `webhook-twilio-notify-signing-secret` Vault entries are read in the D6 multi-key shape; if today's Notify code reads either secret directly (bypassing the multi-key shape), migrate.
- Dedup via `IIdempotencyStore` with 7-day TTL (ADR-0062 D8 standard tier; Notify is not Billing/Audit). Reuses the ADR-0042 packet 03 Cosmos store + ADR-0042 packet 03 InMemory store for tests.
- Audit emit per `WebhookReceipt` category (ADR-0062 D11) — handled by the Kernel extension; verify the wiring.
- Tests: signature verification (valid, invalid, multi-key, replay-window-exceeded); dedup-on-replay; response-code envelope (200 / 400 / 401 / 409 / 413); no secrets / raw bodies in logs.
- Version bump across the `HoneyDrunk.Notify` solution; CHANGELOG/README updates; idempotency-model and webhook-handling sections of README updated.

## Proposed Implementation
1. **Audit** Notify's existing webhook receiver code (see Context). Record findings in the PR — greenfield receivers vs migration.
2. **`SvixSignatureVerifier : IWebhookSignatureVerifier`** — `ProviderName => "resend"` (or `"svix"`; pick one and stick with it; the audit category is `WebhookReceipt` with `target = "resend:notify"` regardless). `VerifyAsync`:
   - Reads `svix-id`, `svix-timestamp`, `svix-signature` headers from the `WebhookVerificationRequest.SignatureHeaders` (the per-provider adapter pulled them off the HTTP request).
   - Splits the `svix-signature` header on space to get the candidate `v1,<sig>` entries (Svix's multi-version-support inside the header itself).
   - Constructs the canonical string `{msg_id}.{timestamp}.{body}`.
   - Iterates `request.CandidateSecrets` (D6 multi-key from Vault), HMAC-SHA256 each secret over the canonical string, base64-encode, compare against each `v1,<sig>` entry with `CryptographicOperations.FixedTimeEquals` (constant-time).
   - First match returns `WebhookVerificationResult { IsValid = true, VerifiedTimestamp = <parsed timestamp>, Reason = null }`.
   - No match returns `WebhookVerificationResult { IsValid = false, Reason = "signature did not match any candidate" }` (reason for logs only — never the response body).
   - If the timestamp is missing or unparseable, return `IsValid = false, Reason = "missing or malformed timestamp"`.
3. **`TwilioSignatureVerifier : IWebhookSignatureVerifier`** — `ProviderName => "twilio"`. `VerifyAsync`:
   - Reads `X-Twilio-Signature` from `SignatureHeaders` and the full request URL from `Extras["RequestUrl"]`.
   - Constructs Twilio's canonical string per their docs: `{full request URL including query string} + concat(<form-encoded body parameters sorted alphabetically by key>)`. The body parameters are form-encoded (not JSON); they need to be parsed once and re-concatenated. The receiver should pass the parsed form parameters in `Extras` (e.g. `Extras["FormParams"]` as a JSON-encoded sorted dictionary) since the verifier should not re-parse the body — the receiver knows the body shape.
   - HMAC-SHA1 each `CandidateSecret` over the canonical string, base64-encode, compare to the header value via `CryptographicOperations.FixedTimeEquals`.
   - **Twilio does not supply a separate timestamp.** Twilio relies on TLS + signature for replay protection at their layer. ADR-0062 D3's 5-minute window can't apply by timestamp; D3's fallback applies: "Receivers whose providers do not supply a timestamp in the signed payload (rare; an example would be a hand-rolled tenant-supplied webhook) fall back to nonce-based replay protection per D8 — the inbound signature is verified, the message ID is looked up in the dedup store, and a previously-seen ID is rejected." For Twilio, the dedup key (`webhook:twilio:{MessageSid}`) IS the replay protection. Return `VerifiedTimestamp = DateTimeOffset.UtcNow` so the receiver code does not branch on a null timestamp, but the receiver MUST NOT enforce a 5-minute window for Twilio (because there is no signed timestamp to compare against). Document this explicitly in the receiver's code comments and in the Notify webhook README.
4. **Resend receiver endpoint** — ASP.NET Core endpoint (Minimal API or controller, matching the repo's existing receiver convention). The route is whatever is registered in the Resend dashboard; document it in the PR. Registers via:
   ```csharp
   services.AddWebhookReceiver<SvixSignatureVerifier>(options =>
   {
       options.SecretName = "webhook-resend-notify-signing-secret";
       options.ReplayWindow = TimeSpan.FromMinutes(5);  // D3 default
       options.DedupTtl = TimeSpan.FromDays(7);          // D8 Standard
       options.MaxBodyBytes = 1_048_576;                 // D4 default
   });
   ```
   The receiver handler (whatever `IRequestHandler`-shaped wrapper the Kernel extension exposes per packet 02) receives the verified-and-deduped payload. Existing Notify provider-side logic (delivery-receipt → mark message delivered / bounced / opted-out) goes into the handler. The handler does NOT re-verify; that already happened.
5. **Twilio receiver endpoint** — same shape, with the Twilio adapter shovelling the request URL and form parameters into `WebhookVerificationRequest.Extras`. Per the D3 fallback note in step 3, the Twilio receiver does NOT enforce the 5-minute window — dedup is the replay protection. The Notify webhook README should make this distinction explicit.
6. **Per-provider header adapters (ADR-0062 D2)** — for each receiver, the adapter reads the provider's specific headers off the HTTP request and stuffs them into `SignatureHeaders` / `Extras` for the verifier. Resend adapter: reads `svix-id`, `svix-timestamp`, `svix-signature`. Twilio adapter: reads `X-Twilio-Signature`, the request URL, and the form-encoded body parameters. The adapter lives next to the receiver (per D2 "per-provider adapters live next to the receiver they serve").
7. **Response-code mapping (D9)** — wired by the Kernel extension (200 / 400 / 401 / 409 / 413). Verify the empty-body-on-200-and-401 contract is honoured (no accidental body writes from middleware or other pipeline components).
8. **Audit emit (D11)** — wired by the Kernel extension via `IAuditLog`. Verify the category, target, outcome, dedup key, and body hash prefix are present in the emitted record; verify no body contents are in the audit (invariant 8 + D11).
9. **Logging (D10)** — verify no log line emits the signing secret, the raw body, or the signature header value in full. Body size and SHA-256 prefix (first 16 hex) are the right amount.
10. **Tests** — unit + integration coverage:
    - `SvixSignatureVerifier`: a valid Svix signature verifies; an invalid one rejects; multi-key first-match works; missing timestamp rejects.
    - `TwilioSignatureVerifier`: a valid Twilio signature verifies; an invalid one rejects; multi-key first-match; documents the no-5-minute-window fallback.
    - Receiver integration test (Tier 2a per ADR-0047 — `WebApplicationFactory`): a duplicate inbound webhook produces exactly one side effect (dedup hit); a malformed signature returns 401 with empty body; an outside-replay-window webhook (Resend) returns 400; an oversize body returns 413.
    - Tests use the InMemory `IIdempotencyStore` from ADR-0042 packet 03; no `Thread.Sleep` (invariant 51); replay-window tests advance the injected `TimeProvider`.
11. **Versioning** — bump every non-test `.csproj` in the `HoneyDrunk.Notify` solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` new version entry; per-package CHANGELOGs only for packages with functional changes. `README.md` updated with the webhook-receiver model section (or extended if a webhook section already exists).

## Affected Files
- `HoneyDrunk.Notify.Hosting.AspNetCore/` (or wherever the existing receiver-hosting code lives) — Resend and Twilio receiver endpoint registration.
- Wherever per-provider verifier files live next to their receivers — `SvixSignatureVerifier.cs`, `TwilioSignatureVerifier.cs` + their header adapters.
- The handler files that process verified delivery receipts (Notify's existing delivery-state-update logic).
- Notify host composition / DI registration files.
- `README.md` — webhook-receiver section.
- Every non-test `.csproj` — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs for changed packages.
- Notify test project(s) — verifier unit tests + receiver integration tests.

## NuGet Dependencies
- The relevant Notify runtime project(s) gain or update:
  - `HoneyDrunk.Kernel` — version from packet 02 (provides `IWebhookSignatureVerifier`, `RawBodyPreservationMiddleware`, `AddWebhookReceiver<T>`).
  - `HoneyDrunk.Kernel.Abstractions` — version from packet 02 (transitive or explicit).
- Notify's **host/composition** project may already reference `HoneyDrunk.Data.Idempotency.Cosmos` (from ADR-0042 packet 03). If not, add it for the receiver's dedup store.
- Notify's **test** project(s) may already reference `HoneyDrunk.Data.Idempotency.InMemory` (from ADR-0042 packet 03). If not, add it.
- `HoneyDrunk.Standards` is already on every Notify project; no change.
- The Twilio verifier uses BCL `HMACSHA1` — no new package. The Svix verifier uses BCL `HMACSHA256` — no new package.
- Confirm exact current versions of upstream Kernel + Data packages at execution time — packet 02 and ADR-0042 packet 03 set them.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Notify` — Notify's own receivers, verifiers, and host composition. Routing rule "notification, email, SMS, ... notify, channel → HoneyDrunk.Notify" maps here.
- [x] No contract change — Notify consumes `IWebhookSignatureVerifier` / `RawBodyPreservationMiddleware` / `AddWebhookReceiver<T>` / `IIdempotencyStore` as shipped by packet 02 and ADR-0042 packet 03.
- [x] Per-provider verifiers live next to the receiver they serve (ADR-0062 D7 "per-provider verifiers live next to the receiver they serve in the consuming Node") — NOT in Kernel.
- [x] Preference/cadence/suppression decision logic is NOT touched (invariant 41 — that is Communications' boundary). Webhook receipt → delivery-status update is delivery-mechanics, not decision logic.

## Acceptance Criteria
- [ ] The PR describes the audit of Notify's existing webhook receiver code (greenfield vs migration) and which path is taken
- [ ] `SvixSignatureVerifier` implements `IWebhookSignatureVerifier`; verifies the Svix canonical string `{msg_id}.{timestamp}.{body}` with HMAC-SHA256; iterates `v1,<sig>` candidates inside the header and `CandidateSecrets` from Vault; uses `CryptographicOperations.FixedTimeEquals`
- [ ] `TwilioSignatureVerifier` implements `IWebhookSignatureVerifier`; verifies Twilio's URL-plus-form-params canonical string with HMAC-SHA1; iterates `CandidateSecrets`; uses `CryptographicOperations.FixedTimeEquals`
- [ ] Both verifiers live next to the receiver they serve in `HoneyDrunk.Notify`, NOT in `HoneyDrunk.Kernel`
- [ ] Resend receiver registered via `services.AddWebhookReceiver<SvixSignatureVerifier>(options => ...)` with `SecretName = "webhook-resend-notify-signing-secret"`, `ReplayWindow = TimeSpan.FromMinutes(5)`, `DedupTtl = TimeSpan.FromDays(7)`
- [ ] Twilio receiver registered via `services.AddWebhookReceiver<TwilioSignatureVerifier>(options => ...)` with `SecretName = "webhook-twilio-notify-signing-secret"`, `DedupTtl = TimeSpan.FromDays(7)`, and the 5-minute replay-window is not enforced for Twilio (D3 fallback — Twilio has no signed timestamp; dedup is the replay protection)
- [ ] The Twilio no-5-minute-window distinction is documented in code comments and in the Notify webhook README
- [ ] Dedup keys are `webhook:resend:{svix-id}` (Resend) and `webhook:twilio:{MessageSid}` (Twilio); a duplicate inbound webhook produces exactly one delivery-status side effect (integration-tested)
- [ ] Response-code envelope honours ADR-0062 D9: 200 + 401 empty body; 400 / 409 / 413 carry RFC 7807; 5xx reserved for genuine server errors only
- [ ] A signature failure returns 401 with empty body — no diagnostic detail (D9 + D10)
- [ ] Every successful and failed verification emits an `IAuditLog` record with `category = "WebhookReceipt"`, `target = "resend:notify"` or `"twilio:notify"`, `outcome` in `{Succeeded, Denied, Deduped}`, dedup key, body-hash prefix (D11)
- [ ] No log line emits the signing secret, the raw body, or the full signature header value (invariant 8 + D10); body size + SHA-256 prefix (first 16 hex) only
- [ ] The Vault secrets are read in the D6 multi-key shape (bare string, newline list, or JSON `{ "active", "previous": [...] }`); if today's code reads either secret directly bypassing multi-key, it is migrated
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry; per-package CHANGELOGs updated only for packages with functional changes
- [ ] `README.md` updated with the webhook-receiver model section (Resend and Twilio routes, signing-secret Vault names, replay/dedup model, response-code envelope)
- [ ] Tests contain no `Thread.Sleep` (invariant 51); replay-window tests use an injected `TimeProvider`
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Publish the upstream NuGet packages before this packet can compile.** This packet's projects reference `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` at the version packet 02 shipped. That artifact reaches the package feed only after a human pushes a git release tag on `HoneyDrunk.Kernel` — **agents never tag or publish.** After packet 02 merges, tag/release the new minor version before this packet starts. If ADR-0042 packet 03 has not yet shipped the Cosmos / InMemory `IIdempotencyStore` packages and Notify does not already reference them, that release is also needed.
- [ ] **Seed the Vault entries** in the D6 multi-key shape:
  - `webhook-resend-notify-signing-secret` in `kv-hd-notify-{env}` — value from the Resend dashboard (the endpoint signing secret).
  - `webhook-twilio-notify-signing-secret` in `kv-hd-notify-{env}` — value from the Twilio Console (the account's Auth Token; Twilio signs with the Auth Token, not a separate signing secret).
  - Seed as the JSON object form `{ "active": "<value>", "previous": [] }` so subsequent rotation can append to `previous` cleanly.
  - This is a one-time per-environment seed; subsequent rotation is the rotator's responsibility (Resend via packet 03's `SvixWebhookSigningSecretRotator`; Twilio via packet 03's portal-runbook fallback).
- [ ] **Configure the webhook receivers in the provider dashboards** — Resend dashboard: webhook endpoint URL pointing at Notify's `/webhooks/resend` route (or whatever the PR's chosen route is); Twilio Console: status callback URL pointing at Notify's `/webhooks/twilio` route. These are provider-side portal clicks; the URLs become routable only after Notify is deployed to the environment. Both providers will start sending events to the configured URL immediately on save.
- [ ] **Provision the Cosmos dedup account per environment** if not already provisioned for Notify's idempotency consumer-group (ADR-0042 packet 03 Human Prerequisites). The receiver's dedup uses the same Cosmos store and consumer-group as Notify's idempotency rollout.
- [ ] **Container App / Function Managed Identity** needs Cosmos data-plane RBAC on the dedup account and `get` permission on `kv-hd-notify-{env}` for the new webhook signing secrets.

## Referenced ADR Decisions
**ADR-0062 D2 — Per-provider header adapters.** Each receiver carries a provider-specific adapter that reads the provider's header(s). The shared verification surface accepts the header values as inputs; it does not impose a header schema. Per-provider adapters live next to the receiver they serve.

**ADR-0062 D3 — 5-minute replay window; timestamp-less fallback.** Every inbound webhook is verified against a 5-minute window measured against the signed timestamp. Receivers whose providers do not supply a timestamp in the signed payload fall back to nonce-based replay protection per D8 — the inbound signature is verified, the message ID is looked up in the dedup store, and a previously-seen ID is rejected. (Twilio has no signed timestamp; dedup is the replay protection.)

**ADR-0062 D4 — `RawBodyPreservationMiddleware`.** Wired by `AddWebhookReceiver<T>` onto the receiver's route. 1 MiB default cap; 413 on overflow.

**ADR-0062 D5 — Vault secret-naming convention.** `webhook-resend-notify-signing-secret`, `webhook-twilio-notify-signing-secret` in `kv-hd-notify-{env}`.

**ADR-0062 D6 — Multi-key verification.** Vault entry holds the candidate secrets; verifier iterates and accepts first match.

**ADR-0062 D7 — Per-provider verifiers live next to the receiver.** `SvixSignatureVerifier` and `TwilioSignatureVerifier` live in `HoneyDrunk.Notify`, NOT in Kernel.

**ADR-0062 D8 — Reuse `IIdempotencyStore`.** `webhook:resend:{svix-id}` and `webhook:twilio:{MessageSid}` keys; TTL 7 days (Standard tier — Notify is not Billing/Audit).

**ADR-0062 D9 — Response convention.** 200 / 400 / 401 / 409 / 413; empty body on 200 and 401; RFC 7807 on others; 5xx for genuine server errors only.

**ADR-0062 D10 — Logging and redaction.** No secrets, no raw bodies; log body size + SHA-256 prefix.

**ADR-0062 D11 — Audit emit on every receipt.** Category `WebhookReceipt`; target `resend:notify` / `twilio:notify`; outcome `Succeeded` / `Denied` / `Deduped`.

**ADR-0062 D12 — `AddWebhookReceiver<T>` extension.** The single registration extension wires the verifier, middleware, dedup, and audit.

**ADR-0062 Consequences — Transitional posture.** "Existing webhook code (if any) is amended in a separate rollout packet; transitional behavior is 'verify with old code, audit-emit per D11' so the audit surface lights up before the verifier consolidation lands." This packet may use that staging if the migration is too large for a single PR.

## Constraints
- **Invariant 41 — preference/cadence/suppression logic lives in Communications, not Notify.** This packet touches only webhook receipt → delivery-status update, which is delivery-mechanics. No decision logic added.
- **Invariant 9 — Vault is the only source of secrets.** Signing secrets resolve via `ISecretStore`; never read from env.
- **Invariant 8 — Secret values never appear in logs/traces/exceptions/telemetry.** Constant-time signature comparison via `CryptographicOperations.FixedTimeEquals`; log body size + SHA-256 prefix only.
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` together.
- **Invariant 51 — no `Thread.Sleep` in test code.** Replay-window tests advance an injected `TimeProvider`.
- **Per-provider verifiers stay in Notify (ADR-0062 D7).** Do not migrate `SvixSignatureVerifier` or `TwilioSignatureVerifier` into Kernel. Kernel ships only the SHA-256 default and the registration surface.
- **No diagnostic detail on 401 (ADR-0062 D9).** The verifier's `WebhookVerificationResult.Reason` is for logs and audit, never for the response body.

## Labels
`feature`, `tier-2`, `ops`, `adr-0062`, `wave-4`

## Agent Handoff

**Objective:** Build (or migrate) Notify's Resend + Twilio status-webhook receivers on the Kernel ADR-0062 surface; ship the per-provider verifiers; wire dedup, audit, and the response-code envelope.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Bring Notify's launch-shape webhook receivers (per ADR-0027 / 0038) onto the Grid-canonical verification pattern before drift forecloses consolidation.
- Feature: ADR-0062 Webhook Verification rollout, Wave 4.
- ADRs: ADR-0062 D2/D3/D4/D5/D6/D7/D8/D9/D10/D11/D12 (primary), ADR-0027 (Notify Cloud — the surface this composes against), ADR-0038 (deliverability — the why behind status webhooks), ADR-0042 (the `IIdempotencyStore` dedup contract reused by D8), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `IWebhookSignatureVerifier`, `RawBodyPreservationMiddleware`, `AddWebhookReceiver<T>` ship in `HoneyDrunk.Kernel` at the new minor version. This packet is parallel-eligible with `work-item:03` (Vault.Rotation rotators — different repo) and `work-item:04` (review-agent prompts — different repo).
- (Soft) ADR-0042 packet 03 — `HoneyDrunk.Data.Idempotency.Cosmos` and `.InMemory`. Notify may already reference them from its own idempotency rollout (`adr-0042-idempotency` packet 05); if not, add them here.

**Constraints:**
- Per-provider verifiers stay in Notify (ADR-0062 D7 — not in Kernel).
- Twilio has no signed timestamp — D3 fallback: dedup is the replay protection. Document explicitly.
- Constant-time signature comparison (`CryptographicOperations.FixedTimeEquals`); no secrets / raw bodies in logs.
- Decision logic stays in Communications (invariant 41); only delivery-mechanics here.
- Bump the whole solution one minor version (invariant 27).

**Key Files:**
- Notify receiver-hosting source files for Resend and Twilio routes.
- `SvixSignatureVerifier.cs`, `TwilioSignatureVerifier.cs` + their header adapters, living next to the receiver they serve.
- Notify host composition.
- `README.md` — webhook-receiver model section.
- Every non-test `.csproj`; repo-level `CHANGELOG.md`.

**Contracts:**
- Implements `IWebhookSignatureVerifier` (from `HoneyDrunk.Kernel.Abstractions` at packet 02's version) per provider — no contract change.
- Consumes `RawBodyPreservationMiddleware`, `AddWebhookReceiver<T>`, `WebhookReceiverOptions`, `IIdempotencyStore`, `IAuditLog` as shipped by packet 02 + ADR-0042 packet 03 + ADR-0030/0031.
