---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0062", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0062"]
wave: 1
initiative: adr-0062-webhook-verification
node: honeydrunk-architecture
---

# Register the webhook-verification contract surface in the Grid catalogs

## Summary
Record ADR-0062's new contract surface as catalog data: register `IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, `WebhookVerificationRequest`, and `WebhookVerificationResult` under the `honeydrunk-kernel` Node in `catalogs/contracts.json`; append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array in `catalogs/relationships.json`; and add a `webhooks` section to `repos/HoneyDrunk.Kernel/integration-points.md` describing the verifier interface, the raw-body middleware, and the `AddWebhookReceiver<T>` extension. Do **not** edit `catalogs/nodes.json` (it has no `exposes` field).

## Context
ADR-0062 D7 places `IWebhookSignatureVerifier` in `HoneyDrunk.Kernel.Abstractions` (the zero-dependency contract layer every Node already consumes — same precedent as `IGridContext`, `TenantId`, `IIdempotencyStore`). The supporting records `WebhookVerificationRequest` and `WebhookVerificationResult` ride alongside. ADR-0062 D4 adds `IRawWebhookBodyFeature` (an ASP.NET Core request-feature exposing the byte-exact body). The `HmacSha256SignatureVerifier` default and the `RawBodyPreservationMiddleware` and the `AddWebhookReceiver<T>` extension are *runtime* types (they ship from `HoneyDrunk.Kernel` runtime package, not Abstractions); they are not contracts in the catalog sense and do not get `contracts.json` entries.

The Grid catalogs are the discoverability surface — `catalogs/contracts.json` registers each Node's contracts in its node block's `interfaces` array, and `catalogs/relationships.json` lists each Node's contract names under `exposes.contracts`. (Note: `catalogs/nodes.json` has **no** `exposes` field — the `exposes` object lives on relationships.json entries.) This packet keeps both catalogs accurate so the implementation packet (02) and any downstream Node have an accurate contract/dependency graph to read.

The future webhook-consuming Nodes — `HoneyDrunk.Notify` (packet 05 in this initiative), the future `HoneyDrunk.Billing.Webhooks` (ADR-0037 D4 standup), `HoneyDrunk.Observe` (ADR-0010 Phase 2 GitHub connector), `HoneyDrunk.Communications` (Operator-approval subscriber) — each take a runtime dependency on `HoneyDrunk.Kernel.Abstractions` already; no new top-level Node-to-Node edge is created by the new contracts. Only `consumes_detail` enrichment is needed (and only for Notify today; the rest record their consumption in their own standup packets when those Nodes light up).

The `webhooks` section in `repos/HoneyDrunk.Kernel/integration-points.md` is the developer-facing surface ADR-0062's follow-up work list explicitly names. Catalogs are machine-readable; the integration-points doc is the human-readable explanation of how a Node hosting a webhook receiver wires it up.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — locate the node block whose `node` value is `honeydrunk-kernel`; append the new contract entries from ADR-0062 D4/D7 to that block's `interfaces` array.
- `catalogs/relationships.json` — append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array; update `consumes_detail` for `honeydrunk-notify` to record the new Kernel contracts it consumes for the Notify webhook receivers landing in packet 05. (The other consuming Nodes — Billing.Webhooks, Observe, Communications — record their consumption in their own standup packets, not here, since those Nodes either do not exist yet or do not yet host a webhook receiver.)
- `catalogs/nodes.json` — **not edited.** nodes.json entries have no `exposes` field; the contract surface lives in relationships.json and contracts.json.
- `repos/HoneyDrunk.Kernel/integration-points.md` — add a `## Webhooks` section describing `IWebhookSignatureVerifier`, the `RawBodyPreservationMiddleware`, and the `AddWebhookReceiver<T>` extension.

## Proposed Implementation
1. **`catalogs/contracts.json`** — locate the node block whose `node` value is `honeydrunk-kernel` (do not rely on line numbers). Append entries to that block's `interfaces` array, matching the existing `{ "name", "kind", "description" }` shape:
   - `IWebhookSignatureVerifier` — `kind: interface` — "Provider-aware signature verifier for inbound webhooks. Exposes ProviderName plus VerifyAsync(WebhookVerificationRequest) returning WebhookVerificationResult. Per-provider implementations (Stripe, GitHub, Svix, Twilio) live next to the receiver they serve in the consuming Node."
   - `IRawWebhookBodyFeature` — `kind: interface` — "ASP.NET Core request-feature exposing the byte-exact webhook body for signature verification. Provided by RawBodyPreservationMiddleware on receiver routes."
   - `WebhookVerificationRequest` — `kind: type` — "Record. Inputs to a signature check: raw body bytes, provider-supplied timestamp, signature header value(s), candidate signing secrets (resolved from Vault), and an extras dictionary for provider-specific inputs (Twilio URL, Svix message id)."
   - `WebhookVerificationResult` — `kind: type` — "Record. Outcome of a signature check: IsValid, an optional diagnostic reason for logs, and the verified timestamp."
   - Drop the leading `I` from record names per the Grid naming rule; interfaces keep the `I`.
2. **`catalogs/relationships.json`** — append `IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, `WebhookVerificationRequest`, `WebhookVerificationResult` to the `honeydrunk-kernel` entry's `exposes.contracts` array. Do not touch existing entries. Then, for `honeydrunk-notify` only, extend the `consumes_detail["honeydrunk-kernel"]` array with `"IWebhookSignatureVerifier"`, `"IRawWebhookBodyFeature"`, `"WebhookVerificationRequest"`, `"WebhookVerificationResult"`. Do not add a new top-level edge — Notify's `consumes` already includes `honeydrunk-kernel`. Do not pre-emptively enrich `consumes_detail` for `honeydrunk-observe`, `honeydrunk-communications`, or any future Billing.Webhooks Node — those record their consumption in their own standup packets when the actual receiver lands.
3. **`catalogs/nodes.json`** — no edit. nodes.json has no `exposes` field; do not invent one.
4. **`repos/HoneyDrunk.Kernel/integration-points.md`** — add a `## Webhooks` section between the existing sections. Document:
   - `IWebhookSignatureVerifier` — what it does, what `WebhookVerificationRequest` carries, what `WebhookVerificationResult` returns; a short example showing the per-provider verifier shape (one or two lines for Stripe-style timestamp-prefix, Twilio-style URL-plus-form-encoded).
   - `RawBodyPreservationMiddleware` and `IRawWebhookBodyFeature` — the ASP.NET Core gotchas (read-once stream, `EnableBuffering`, byte-exact verification body), the 1 MiB default cap, the per-route registration model.
   - The `services.AddWebhookReceiver<TVerifier>(options => { … })` extension — secret name, replay window, dedup TTL, max body bytes options; that it wires raw-body middleware, dedup-store lookup, and audit emitter automatically.
   - The Function-App-hosted case (Stripe per ADR-0037 D4): bypass the middleware, take the raw bytes from the Functions binding, and call `IWebhookSignatureVerifier` + `IIdempotencyStore` directly.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `repos/HoneyDrunk.Kernel/integration-points.md`

## NuGet Dependencies
None. This packet touches only catalog JSON and a Markdown doc; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog/docs data only — the Kernel verifier-and-middleware code lands in packet 02; the Notify receiver code lands in packet 05.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers all four new contracts in the `honeydrunk-kernel` node block's `interfaces` array, matching the existing entry shape
- [ ] `catalogs/relationships.json` `honeydrunk-kernel` entry lists all four new type names in `exposes.contracts`, with all existing entries untouched
- [ ] `catalogs/relationships.json` `consumes_detail["honeydrunk-kernel"]` for `honeydrunk-notify` includes the four new contract names
- [ ] `catalogs/nodes.json` is NOT modified (it has no `exposes` field)
- [ ] No new top-level Node-to-Node edge is created (the dependency on `HoneyDrunk.Kernel.Abstractions` already exists for Notify)
- [ ] `consumes_detail` is NOT pre-emptively enriched for `honeydrunk-observe`, `honeydrunk-communications`, or any future Billing.Webhooks Node — those record their consumption in their own standup packets when the actual receiver lands
- [ ] `repos/HoneyDrunk.Kernel/integration-points.md` has a new `## Webhooks` section covering `IWebhookSignatureVerifier`, `RawBodyPreservationMiddleware` + `IRawWebhookBodyFeature`, `AddWebhookReceiver<T>`, and the Function-App case
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0062 D4 — Kernel-owned `RawBodyPreservationMiddleware`.** Reads the request body into a `byte[]` once, exposes it via `IRawWebhookBodyFeature`, resets the stream so model binding still works; configurable size cap (1 MiB default); 413 Payload Too Large on overflow; registered explicitly per webhook receiver route, not Grid-globally.

**ADR-0062 D7 — `IWebhookSignatureVerifier` in `HoneyDrunk.Kernel.Abstractions`.** Interface: `string ProviderName { get; }` + `ValueTask<WebhookVerificationResult> VerifyAsync(WebhookVerificationRequest request, CancellationToken cancellationToken = default);`. `WebhookVerificationRequest` is a record carrying raw body bytes, the provider-supplied timestamp, signature header value(s), candidate signing secrets (resolved from Vault per D5/D6), and an `IReadOnlyDictionary<string, string>` of provider-specific extras. `WebhookVerificationResult` is a record exposing `bool IsValid`, optional reason string for diagnostics, and the verified timestamp.

**ADR-0062 D12 — Registration extension.** `services.AddWebhookReceiver<TVerifier>(options => { options.SecretName = ...; options.ReplayWindow = TimeSpan.FromMinutes(5); options.DedupTtl = TimeSpan.FromDays(7); options.MaxBodyBytes = 1_048_576; });` — binds the verifier, wires raw-body middleware onto the receiver's route, registers dedup-store lookup, and registers the audit emitter.

**ADR-0062 Consequences — Affected Nodes.** "`HoneyDrunk.Kernel` — gains `IWebhookSignatureVerifier` in `Kernel.Abstractions`, the `HmacSha256SignatureVerifier` default in `HoneyDrunk.Kernel`, the `RawBodyPreservationMiddleware`, and the `AddWebhookReceiver<T>` extension. Spec-level additions, not breaking." The Cosmos-backed `IIdempotencyStore` reused by D8 is already governed by ADR-0042 packet 03; this packet does not re-register it.

## Constraints
- **Records drop the `I`, interfaces keep it.** Grid-wide naming rule: `WebhookVerificationRequest` / `WebhookVerificationResult` (records), `IWebhookSignatureVerifier` / `IRawWebhookBodyFeature` (interfaces).
- **Catalog only the contracts.** `HmacSha256SignatureVerifier`, `RawBodyPreservationMiddleware`, `WebhookReceiverOptions`, and the `AddWebhookReceiver<T>` extension are runtime types shipped from `HoneyDrunk.Kernel`. They are not contracts in the catalog sense and do not get `contracts.json` entries. They DO get described in the `integration-points.md` developer-facing doc.
- **Do not register provider-specific verifiers as Kernel contracts.** `StripeSignatureVerifier`, `TwilioSignatureVerifier`, `SvixSignatureVerifier`, etc. live next to the receiver they serve in the consuming Node (per ADR-0062 D7 alternative-rejected discussion); they are registered against `IWebhookSignatureVerifier` in their own Node's DI, not in Kernel's `contracts.json` block.
- **No `consumes_detail` for future Nodes.** Only Notify gets enrichment here. Observe, Communications, and any future Billing.Webhooks Node record their consumption in their own standup packets when the receiver lands.
- **`catalogs/nodes.json` is NOT touched** — it has no `exposes` field.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0062`, `wave-1`

## Agent Handoff

**Objective:** Register ADR-0062's webhook-verification contract surface in the Grid catalogs and the Kernel integration-points doc.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs and the Kernel developer-facing doc accurate so implementation packets 02 and 05 read a correct graph.
- Feature: ADR-0062 Webhook Verification rollout, Wave 1.
- ADRs: ADR-0062 D4/D7/D12 (primary), ADR-0042 (the dedup contract that D8 reuses — not re-registered here).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0062 should be Accepted before its contract surface is recorded as catalog data.

**Constraints:**
- Records drop the `I`; interfaces keep it.
- Catalog only the contracts; runtime types (default verifier, middleware, options, extension) are described in the integration-points doc but not registered in `contracts.json`.
- Only Notify gets `consumes_detail` enrichment in this packet — Observe / Communications / future Billing.Webhooks self-register at their own standup.
- nodes.json is NOT edited — it has no `exposes` field.

**Key Files:**
- `catalogs/contracts.json` — new entries in the `honeydrunk-kernel` block's `interfaces` array.
- `catalogs/relationships.json` — `honeydrunk-kernel` `exposes.contracts` + Notify-only `consumes_detail` enrichment.
- `repos/HoneyDrunk.Kernel/integration-points.md` — new `## Webhooks` section.

**Contracts:** None changed — this packet only records catalog metadata for contracts that packet 02 implements. The contract entries land in `contracts.json`'s `interfaces` array and `relationships.json`'s `exposes.contracts`; `nodes.json` is untouched.
