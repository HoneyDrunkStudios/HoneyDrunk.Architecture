# Dispatch Plan — ADR-0062: Inbound Webhook Verification and Receiver Pattern

**Initiative:** `adr-0062-webhook-verification`
**ADR:** ADR-0062 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0062 settles the verification pattern for the four inbound-webhook surfaces about to land inside one release window (Stripe / Resend / Twilio / GitHub / Operator-approval callbacks). Without a Grid-level decision each receiver lands its own HMAC implementation, replay window, secret-naming convention, raw-body-buffering middleware, and response-code mapping — predictable per-Node drift on the parts a `security` specialist review (ADR-0046) cannot easily compare across Nodes.

This initiative delivers: ADR acceptance + the four new webhook-receiver invariants + catalog registration + Kernel integration-points doc (Architecture); the Kernel-owned verification surface — `IWebhookSignatureVerifier` interface, `IRawWebhookBodyFeature`, the supporting records, the `HmacSha256SignatureVerifier` default, the `RawBodyPreservationMiddleware`, the `WebhookReceiverOptions` options type, and the `AddWebhookReceiver<T>` extension (Kernel); the scheduled rotators for Stripe / GitHub / Svix signing secrets and the Twilio portal-runbook fallback (Vault.Rotation); the review and security-specialist agent webhook-receiver checklist (Architecture); and the Resend + Twilio receivers in Notify composed against the Kernel surface (the only existing live Node with launch-shape webhook surfaces today).

**6 packets across 4 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.Vault.Rotation`, `HoneyDrunk.Notify`). All 6 are `Actor=Agent`, 0 `Actor=Human`. Packets 03 and 05 carry Human Prerequisites — Vault entry seeding, provider-dashboard configuration, Cosmos dedup account provisioning, Managed Identity RBAC — but the *code* work is fully delegable (tests run against the InMemory store and provider SDK mocks), so they stay `Actor=Agent`.

## Trigger

ADR-0062 is Proposed with no scope. The forcing functions from the ADR's Context:
- **Stripe webhook handler is the immediate consumer** — ADR-0037 D4 names `HoneyDrunk.Billing.Webhooks` as a future Function App; whatever shape ships becomes de-facto canon.
- **Notify Cloud GA carries Resend and Twilio status-webhook integration as a launch-shape requirement** — ADR-0027 / ADR-0038. Provider-side delivery receipts are the only credible way the Cloud surface knows whether a tenant's send succeeded; the integration cannot be deferred past GA.
- **Observe's GitHub-connector webhook receiver is the AI-sector-readiness gate** for any external observation source per ADR-0010 / Invariant 30. GitHub is the first realistic connector.
- **Communications subscriber surfaces are about to be specified** — the Operator-approval-event-subscriber design is one packet away. Settling the verification pattern before Communications writes its first receiver prevents per-Node drift.
- **ADR-0049 (PII) and ADR-0006 (rotation)** both have load-bearing implications for any webhook surface; patterns that don't compose with them need re-litigation later.

The ADR needs decomposition into actionable packets, with the Grid-canonical pattern locked in before the Stripe handler, the Notify receivers, the Observe connector, and the Communications subscriber drift apart.

## Scope Detection

**Multi-repo, multi-Node, but bounded to the four live surfaces today.** The contract + runtime lands in `HoneyDrunk.Kernel.Abstractions` (the zero-dependency contract layer every Node already consumes) and `HoneyDrunk.Kernel` (runtime). The scheduled rotators land in `HoneyDrunk.Vault.Rotation`. The review-agent enforcement lands in `HoneyDrunk.Architecture` (`.claude/agents/review.md` + the `security` specialist prompt). The first live Node consumer — `HoneyDrunk.Notify` for Resend and Twilio status webhooks — composes against the Kernel surface.

**Contract is additive — no forced downstream cascade.** The new contracts (`IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, `WebhookVerificationRequest`, `WebhookVerificationResult`) are *additive* to `HoneyDrunk.Kernel.Abstractions`. Per ADR-0062's Operational Consequences and ADR-0035, this is an additive minor bump (no breaking change). Downstream Nodes that consume `HoneyDrunk.Kernel.Abstractions` are not *forced* to update — they adopt the contract when they host a webhook receiver. This initiative amends only **`HoneyDrunk.Notify`**, the one existing live Node with launch-shape webhook receivers today.

**Future consumers — deliberately out of scope here, per the standup-gets-its-own-ADR rule:**
- **`HoneyDrunk.Billing.Webhooks`** — a future Node (ADR-0037 D4). The Stripe receiver lands at Billing.Webhooks standup, which is governed by ADR-0037. This initiative does NOT scaffold the Node, does NOT ship the receiver, does NOT register the `webhook-stripe-billing-signing-secret` Vault entry. Packet 03's Stripe rotator is scaffolded *now* (its registration code can sit waiting for the Vault entry to exist) but only activates when Billing.Webhooks stands up and seeds the secret. ADR-0037's standup packet is the right home for the Stripe receiver itself.
- **`HoneyDrunk.Observe`** — the GitHub-connector webhook receiver is ADR-0010 Phase 2 work. The Observe Node has its Phase 1 contract surface (`HoneyDrunk.Observe.Abstractions`) but no Phase 2 implementation yet. The GitHub receiver is built as part of `HoneyDrunk.Observe.Connectors.GitHub` (Phase 2) and composes against the Kernel surface this initiative ships. Packet 03's GitHub rotator is similarly scaffolded now and activates when the Vault entry is seeded.
- **`HoneyDrunk.Communications`** — the Operator-approval-event subscriber receivers and tenant-supplied callbacks are Communications' own follow-up work. The Communications Node consumes `HoneyDrunk.Kernel.Abstractions` already; the receiver pattern is unblocked by this initiative but the receiver code itself is Communications' job.

This keeps the initiative bounded and consistent with the Grid's standup-gets-its-own-ADR rule (no new-Node scaffolding bundled into feature packets).

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node. No empty cataloged repo is touched; no standup ADR is needed.

## Cross-Dependency with ADR-0042

ADR-0062 D8 reuses `IIdempotencyStore` from ADR-0042 ("Reuse `IIdempotencyStore` per ADR-0042"). The relationship:
- ADR-0062's `AddWebhookReceiver<T>` extension wires `IIdempotencyStore` at composition time. The interface itself ships in ADR-0042 packet 02.
- ADR-0062 packet 05 (Notify receivers) takes a runtime dependency on the Cosmos `IIdempotencyStore` (from ADR-0042 packet 03) for deployed environments and the InMemory `IIdempotencyStore` for tests.
- ADR-0062 packet 02 references the ADR-0042 contract but does not block on it — see the soft-coordination note in packet 02's Context. If ADR-0042 packet 02 has not landed at execution time, packet 02 here can defer the dedup-store wiring to the host (which would push the dedup-store registration into packet 05's composition). Default to coordinating the merges.

**This is a soft dependency, not a hard blocker.** ADR-0062 can be scoped, accepted, and implemented while ADR-0042 is still mid-rollout, because:
1. The verifier contract itself does not depend on `IIdempotencyStore` — only the extension wiring does.
2. Packet 02 here can ship the verifier + middleware + extension with the dedup-store wiring as an optional seam if ADR-0042 packet 02 has not yet shipped.

**Flagged for the operator:** the two initiatives — `adr-0042-idempotency` and `adr-0062-webhook-verification` — share the `HoneyDrunk.Kernel` solution. Both bump the same `.csproj` files. If both initiatives are in flight simultaneously, sequence the Kernel bumps:
1. ADR-0042 packet 02 first (its own initiative is Wave 2; the bumping packet for `HoneyDrunk.Kernel` `0.7.0` → `0.8.0`).
2. Then ADR-0062 packet 02 (this initiative's Wave 2; bumps `0.8.0` → `0.9.0`).

If ADR-0042 packet 02 has not yet merged when packet 02 here starts, the executor coordinates: rebase onto the ADR-0042 packet 02 merge so the version line is consistent, or work on parallel branches and resolve the version-line conflict at merge time. State the sequencing in the PR.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0062, add the four webhook-receiver invariants (numbers **78, 79, 80, 81**), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the webhook-verification contract surface in the Grid catalogs + Kernel integration-points doc. `Actor=Agent`. Blocked by: 00.

> **Invariant numbering.** The current verified maximum in `constitution/invariants.md` is **53** (ADR-0044's 52, 53). Invariant numbers **78, 79, 80, 81** are pre-reserved for ADR-0062 as part of a cross-cutting ADR batch (ADR-0042 already pre-reserved **75, 76, 77**). If any invariant in the **75–81** range lands from outside this batch before packet 00 merges, shift this block upward, never reuse a number.

### Wave 2 (Depends on Wave 1 — the Kernel verification surface)
- [ ] **02** — Kernel: ship the full ADR-0062 Kernel-owned verification surface — contracts in `HoneyDrunk.Kernel.Abstractions` (`IWebhookSignatureVerifier`, `IRawWebhookBodyFeature`, the records), runtime in `HoneyDrunk.Kernel` (`HmacSha256SignatureVerifier`, `RawBodyPreservationMiddleware`, `WebhookReceiverOptions`, `AddWebhookReceiver<T>` extension). `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Kernel` (next minor above the in-flight version).**

> **Why one packet, not two.** ADR-0042's analogue split contracts (packet 02) from runtime (packet 04). ADR-0062 keeps them together: the runtime types here (SHA-256 default, middleware, options, extension) are load-bearing for the contracts to be useful at all. A consuming Node cannot compose `IWebhookSignatureVerifier` without `AddWebhookReceiver<T>`; cannot get the raw bytes without the middleware. Splitting would force Wave 3 / 4 to wait for two Kernel publishes instead of one. The testable unit is "a Node can verify inbound webhooks end-to-end against the Kernel surface."

### Wave 3 (Depends on Wave 1 — rotation + review-prompt enforcement, parallel)
- [ ] **03** — Vault.Rotation: add scheduled rotators for Stripe / GitHub / Svix signing secrets; portal-runbook fallback for Twilio. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Vault.Rotation`.**
- [ ] **04** — Architecture: add the ADR-0062 webhook-receiver checklist to `.claude/agents/review.md` and the `security` specialist prompt. `Actor=Agent`. Blocked by: 00.

> Packets 03 and 04 are intentionally in Wave 3, NOT Wave 2 — neither depends on the Kernel surface from packet 02. Packet 03 writes to Vault and calls provider APIs; packet 04 updates agent prompts. They are unblocked the moment ADR-0062 is Accepted (packet 00). Filing them in parallel with packet 02 (instead of after) shortens the critical path.

### Wave 4 (Depends on Waves 2 & 3 — the Notify rollout)
- [ ] **05** — Notify: implement `SvixSignatureVerifier` + `TwilioSignatureVerifier` and the receiver endpoints; compose against the Kernel surface; wire dedup, audit, response convention. `Actor=Agent`. Blocked by: 02. (Soft coordination with the ADR-0042 packet 03 Cosmos `IIdempotencyStore` — Notify may already reference it from its own ADR-0042 packet 05 rollout.)

Packets within a wave run in parallel. **Wave-3 packets 03 and 04 are independent** — 03 is `HoneyDrunk.Vault.Rotation`; 04 is `HoneyDrunk.Architecture` — different repos, no shared solution. Both run in parallel with packet 02 (different repos).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0062](./00-architecture-adr-0062-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Webhook verification catalog + integration-points](./01-architecture-webhook-verification-catalog.md) | Architecture | Agent | 1 | 00 |
| 02 | [Kernel webhook verification surface](./02-kernel-webhook-verification-surface.md) | Kernel | Agent | 2 | 00 |
| 03 | [Vault.Rotation webhook signing-secret rotators](./03-vault-rotation-webhook-signing-secret-rotators.md) | Vault.Rotation | Agent | 3 | 00 |
| 04 | [Review-agent webhook checklist](./04-architecture-review-agent-webhook-checklist.md) | Architecture | Agent | 3 | 00 |
| 05 | [Notify Resend + Twilio webhook receivers](./05-notify-resend-twilio-webhook-receivers.md) | Notify | Agent | 4 | 02 |

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 02 is the only packet on the solution in this initiative; it bumps every non-test `.csproj` one minor version (additive new feature: webhook verification surface). Confirm the in-flight version at execution time. If ADR-0042 packet 02 has merged `0.8.0`, this packet bumps `0.8.0` → `0.9.0`. If ADR-0042 packet 02 has not merged, this packet bumps `0.7.0` → `0.8.0` and ADR-0042's bump coordinates around it. Per-package CHANGELOGs: both `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` get entries (real changes in both packages).
- **`HoneyDrunk.Vault.Rotation`** — packet 03 bumps the whole solution one minor version (new rotators added). Confirm current at execution time.
- **`HoneyDrunk.Notify`** — packet 05 bumps the whole solution one minor version. Notify v0.2.0 per the launch tracker; confirm current at execution time.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/prompt edits only.

## Cross-Cutting Concerns

### Stripe receiver is deferred to Billing.Webhooks standup

ADR-0062 names `HoneyDrunk.Billing.Webhooks` as the first concrete consumer. This initiative deliberately does NOT ship the Stripe receiver. Billing.Webhooks is a future Node (ADR-0037 D4) that does not exist yet; its standup is ADR-0037's scope, not this initiative's. The Stripe receiver implementation — `StripeSignatureVerifier` and the Function-App-hosted endpoint — lands in Billing.Webhooks' standup packet wave, composed against the Kernel surface this initiative ships. Packet 03's `StripeWebhookSigningSecretRotator` is scaffolded now and waits for the `webhook-stripe-billing-signing-secret` Vault entry to be seeded at Billing.Webhooks standup.

### Observe GitHub-connector receiver is deferred to ADR-0010 Phase 2

ADR-0062 names the Observe GitHub receiver as the third forcing function. This initiative deliberately does NOT ship the GitHub receiver. `HoneyDrunk.Observe` has its Phase 1 contract surface (`HoneyDrunk.Observe.Abstractions`) but no Phase 2 implementation yet. The GitHub receiver lands in `HoneyDrunk.Observe.Connectors.GitHub` (Phase 2), composed against the Kernel surface this initiative ships. Packet 03's `GitHubWebhookSigningSecretRotator` is scaffolded now and waits for the `webhook-github-observe-signing-secret` Vault entry to be seeded at Observe Phase 2.

### Communications subscriber surfaces are unblocked but not built here

ADR-0062 names the Operator-approval-event subscriber as the fourth forcing function. The Communications Node consumes `HoneyDrunk.Kernel.Abstractions` already; the receiver pattern is unblocked the moment packet 02 merges. The receivers themselves are Communications' own follow-up work (its own packet, scoped against ADR-0019 / the Operator subscriber design). This initiative deliberately does not author a Communications packet — Communications' subscriber design is "one packet away" per the ADR Context, not yet specified, and the standup-gets-its-own-ADR principle applies once that design lands.

### Notify is the only live consumer in this initiative

Per the deferral notes above, `HoneyDrunk.Notify` is the only Node with launch-shape webhook receivers today (Resend + Twilio status callbacks, per ADR-0027 / ADR-0038). It is the one packet-5 consumer here. The other three future surfaces (Billing.Webhooks Stripe, Observe GitHub, Communications Operator-approval) compose against the same Kernel surface in their own initiatives.

### Twilio's no-signed-timestamp fallback

ADR-0062 D3's 5-minute replay window applies "to every receiver in the Grid, including providers whose own documentation suggests a longer tolerance." Twilio is the exception — Twilio does not supply a signed timestamp. D3's fallback applies: "the inbound signature is verified, the message ID is looked up in the dedup store, and a previously-seen ID is rejected." Packet 05 enforces dedup (by `MessageSid`) as the replay protection for Twilio and explicitly does NOT enforce the 5-minute window for that receiver. This is documented in code comments and in the Notify webhook README.

### Outbound webhooks are out of scope

ADR-0062 D13 is explicit: outbound (Studios-emitted) webhooks are out of scope. The "first-party HMAC-SHA256 over `timestamp.body`" anchor in D1 is recorded for a future outbound-webhook ADR; nothing in this initiative commits a Studios-emitted webhook surface. ADR-0057 explicitly defers outbound webhooks. No packet here addresses outbound emission.

### Tenant-supplied callback URL allowlisting is out of scope

Outbound concern per ADR-0062 D13. When the first concrete tenant-callback receiver lands (Communications' tenant-supplied callbacks per the ADR Context), it gets its own packet.

### Cross-receiver orchestration is out of scope

ADR-0062 D13: each receiver is independent. No "webhook hub" pattern in this initiative; if it becomes credible later, that is a future ADR (likely the same one that lifts webhooks into a `HoneyDrunk.Webhooks` Node — see ADR-0062 D7 alternative).

### Coupling with the review agent

Packet 04 ensures the review and security-specialist agent prompts gain the webhook-receiver checklist at the same wave as the Kernel surface ships. Invariant 33: review-agent and scope-agent context-loading are coupled. Without packet 04, packet 05 (Notify receivers) would not be reviewable against the ADR-0062 rules at PR time.

### Site sync

No site-sync flag. ADR-0062 is internal Core-sector infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the four invariants and the catalog entries are removed; the Kernel integration-points `## Webhooks` section is removed. No runtime impact.
- **Packet 02 (Kernel verification surface):** revert the PR; the `HoneyDrunk.Kernel` solution rolls back the version bump. The contracts and runtime are additive — no consuming Node depends on them at runtime until it composes them, so the revert is contained to `HoneyDrunk.Kernel`. Packet 05 cannot proceed; defer its execution.
- **Packet 03 (Vault.Rotation rotators):** revert the PR; the three new rotators leave the solution; the version rolls back. The Twilio runbook doc revert removes the portal-runbook section (operators fall back to whatever convention existed before). No runtime regression on existing rotators.
- **Packet 04 (review prompts):** revert the PR; the review and security-specialist prompts return to their pre-ADR-0062 state. New webhook-receiver PRs are reviewed without the checklist until re-applied. No runtime impact.
- **Packet 05 (Notify receivers):** revert the PR; Notify's webhook receivers return to whatever state they were in before this packet (greenfield: receivers disappear; migration: receivers fall back to bespoke pre-ADR-0062 verification code). The Notify solution version rolls back. Resend and Twilio continue sending status webhooks to the configured URLs; if the receivers disappear entirely, the URLs return 404 and the providers retry — no signed-bad-state scenario, but Notify loses delivery-status visibility until rolled forward.
- **Operational escape hatch:** if a per-provider verifier in packet 05 has a bug (false-rejecting valid signatures, for example), short-term mitigation is a config flag to bypass that receiver's verification temporarily (NEVER bypass the dedup). Document the flag if it exists, never enable it without an explicit operator decision.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
