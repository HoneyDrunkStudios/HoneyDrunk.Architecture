---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0062", "wave-1"]
dependencies: []
adrs: ["ADR-0062"]
accepts: ["ADR-0062"]
wave: 1
initiative: adr-0062-webhook-verification
node: honeydrunk-architecture
---

# Accept ADR-0062 — flip status, add the four webhook-receiver invariants, register the initiative

## Summary
Flip ADR-0062 (Inbound Webhook Verification and Receiver Pattern) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the four new webhook-receiver invariants ADR-0062 commits in its Consequences/Invariants section to `constitution/invariants.md`, claim the four-number invariant block (`{N1}`–`{N4}`) in `constitution/invariant-reservations.md`, and register the `adr-0062-webhook-verification` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0062 decides the Grid's response to four near-simultaneous inbound-webhook surfaces (Stripe via `HoneyDrunk.Billing.Webhooks` per ADR-0037 D4; Resend + Twilio status callbacks via `HoneyDrunk.Notify` per ADR-0027/0038; GitHub via `HoneyDrunk.Observe` per ADR-0010; Operator-approval callbacks via `HoneyDrunk.Communications` per ADR-0019). Without a Grid-level decision each receiver lands its own HMAC implementation, replay window, secret-naming convention, raw-body buffering middleware, and response-code mapping — predictable per-Node drift on the parts a `security` specialist review (ADR-0046) cannot easily compare across Nodes.

The ADR decides:
- **D1** — per-provider HMAC schemes as emitted (Stripe SHA-256, GitHub SHA-256, Svix SHA-256, Twilio SHA-1); first-party HMAC-SHA256 anchor noted for future outbound-webhook ADR.
- **D2** — per-provider signature-header adapters; no Grid-uniform `X-HoneyDrunk-Signature` rewrite.
- **D3** — 5-minute replay window, hard-pinned across all receivers.
- **D4** — Kernel-owned `RawBodyPreservationMiddleware` exposing `IRawWebhookBodyFeature`; 1 MiB default cap.
- **D5** — Vault secret naming convention `webhook-{provider}-{purpose}-signing-secret`; Tier 2 (≤ 90-day rotation SLA).
- **D6** — multi-key verification, accept first match (default N=2); single Vault entry with bare-string, newline-list, or JSON `{ "active", "previous": [...] }` shapes.
- **D7** — `IWebhookSignatureVerifier` in `HoneyDrunk.Kernel.Abstractions`; Kernel ships `HmacSha256SignatureVerifier` default; per-provider verifiers live next to the receiver they serve.
- **D8** — replay-protection storage reuses `IIdempotencyStore` per ADR-0042; key form `webhook:{provider}:{event-id}`; TTL = standard 7 days, Stripe 30 days.
- **D9** — response convention 200 / 400 / 401 / 409 / 413; no body on 200 or 401; RFC 7807 envelope on 400/409/413.
- **D10** — logging and redaction rules: never log signing secrets or raw bodies; preserve body size + SHA-256 prefix.
- **D11** — every webhook receipt emits `IAuditLog` with category `WebhookReceipt` and outcome `Succeeded` / `Denied` / `Deduped`.
- **D12** — `services.AddWebhookReceiver<TVerifier>(options => …)` registration extension.
- **D13** — outbound (Studios-emitted) webhooks, tenant-callback-URL allowlisting, and cross-receiver orchestration are deliberately out of scope.

ADR-0062 is a **policy / contract** ADR. The concrete code — the Kernel verifier interface + default verifier + raw-body middleware + DI extension, the Vault.Rotation rotators for the rotation-API-supporting providers, the Notify-side verifier composition, and the review-agent webhook checklist — lands in `HoneyDrunk.Kernel`, `HoneyDrunk.Vault.Rotation`, `HoneyDrunk.Notify`, and (for the agent prompts) `HoneyDrunk.Architecture` in this initiative. Every other packet references ADR-0062's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0062-inbound-webhook-verification.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0062 row Status column to Accepted.
- `constitution/invariant-reservations.md` — claim a contiguous block of four invariant numbers (`{N1}`–`{N4}`) for ADR-0062 by adding a row to the **Active Reservations** table. The block is `max(invariants.md max accepted, all existing reservation ceilings) + 1` through `+ 4`; see Constraints for the resolution at authoring time.
- `constitution/invariants.md` — add the four new webhook-receiver invariants (see Proposed Implementation for exact text), numbered with the block claimed in `invariant-reservations.md` (`{N1}`, `{N2}`, `{N3}`, `{N4}`).
- `initiatives/active-initiatives.md` — register the `adr-0062-webhook-verification` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0062 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0062 index row in `adrs/README.md` to Accepted.
3. **Claim the invariant block in `constitution/invariant-reservations.md`.** Read the **Active Reservations** table. Compute `next free = max(invariants.md accepted ceiling, all existing reservation upper bounds) + 1`. The block size is 4 (ADR-0062 adds four invariants). Add a row to **Active Reservations** in the same commit that adds the invariants to `invariants.md`, recording the range `{N1}`–`{N4}`, ADR (ADR-0062), Status (Proposed → flipped to Accepted by this packet), and the path to this packet 00. Use the concrete computed numbers in the row (not `{N1}`–`{N4}` literals), but throughout this packet body — and any downstream packet — keep the placeholders so a late-merge collision is a single re-substitution. If a collision shifts the block, update every `{N1}`–`{N4}` site in this packet plus any downstream packet that references the invariant numbers before pushing.
4. Add four new invariants to `constitution/invariants.md`, numbered with the block claimed in step 3 (`{N1}`, `{N2}`, `{N3}`, `{N4}` — contiguous, ascending). The text, taken verbatim-in-substance from ADR-0062's Consequences "Invariants" section:
   - **`{N1}` — Inbound webhook receivers must verify provider signatures via `IWebhookSignatureVerifier` and reject requests outside a 5-minute replay window.** Enforced at receiver registration; a Node hosting a webhook surface without the verifier registered is a canary-eligible failure. See ADR-0062 D1, D3, D7.
   - **`{N2}` — Inbound webhook receivers must dedupe by `webhook:{provider}:{event-id}` against `IIdempotencyStore` before invoking handler side effects.** Reuses the ADR-0042 D2 claim/process/complete pattern; TTL is the provider's documented redelivery window rounded up to an ADR-0042 D4 tier (Standard 7 days; Stripe uses Billing/Audit 30 days). See ADR-0062 D8.
   - **`{N3}` — Webhook signing secrets follow the `webhook-{provider}-{purpose}-signing-secret` Vault naming convention.** Tier 2 (third-party, ≤ 90-day rotation SLA) per ADR-0006 Tier 5; multi-key verification per ADR-0062 D6 reads candidate secrets from a single Vault entry whose value is a bare string, a newline-separated list, or a JSON `{ "active", "previous": [...] }` object. Enforced by the `security` specialist review per ADR-0046 and by the `scope` agent at packet authoring. See ADR-0062 D5, D6.
   - **`{N4}` — Every webhook receipt produces an `IAuditLog` emit with category `WebhookReceipt`, outcome `Succeeded` / `Denied` / `Deduped`, and no payload body in the record.** Reinforces invariant 47 — the audit substrate is the forensic surface for attempted webhook forgery; observability is sampled and retention-bounded and is not a substitute. See ADR-0062 D11.
   - Create a new `## Webhook Invariants` section. The file's existing sectioning convention groups invariants by topic (Dependency, Context, Secrets, Packaging, Testing, AI, Audit, Communications, Idempotency, etc.); inbound webhook verification is a new cross-cutting topic and warrants its own section. Place it after the `## Audit Invariants` section.
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0062-inbound-webhook-verification.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0062 header reads `**Status:** Accepted`
- [ ] The ADR-0062 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a new row in **Active Reservations** for ADR-0062 claiming a contiguous block of four numbers (`{N1}`–`{N4}`) computed as `max(invariants.md ceiling, all existing reservation upper bounds) + 1` through `+ 4` at PR authoring time, pointing at this packet 00's path
- [ ] `constitution/invariants.md` carries the four new webhook-receiver invariants (verifier + 5-minute replay window; dedup by `webhook:{provider}:{event-id}` against `IIdempotencyStore`; Vault secret-naming convention with multi-key shape; `WebhookReceipt` audit emit), numbered with the block claimed in `invariant-reservations.md` under a new `## Webhook Invariants` section, each citing ADR-0062
- [ ] `initiatives/active-initiatives.md` registers the `adr-0062-webhook-verification` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0062 D1 — Per-provider HMAC.** Each receiver verifies signatures using the provider's emitted scheme (Stripe / GitHub / Svix SHA-256, Twilio SHA-1). The Grid does not impose a uniform HMAC scheme on inbound webhooks. First-party HMAC-SHA256 over `timestamp.body` noted as the anchor for a future outbound-webhook ADR.

**ADR-0062 D3 — 5-minute replay window.** Every inbound webhook is verified against a 5-minute window measured against the signed timestamp the provider supplies. Requests outside the window are rejected with `400 Bad Request`. Matches Stripe's documented default, OWASP webhook cheat-sheet recommendation, and Svix's reference implementation; conservative enough to defeat public-internet replay, loose enough to absorb Container Apps clock skew.

**ADR-0062 D5 — Vault secret-naming convention.** `webhook-{provider}-{purpose}-signing-secret`; lives in the consuming Node's Key Vault; Tier 2 per ADR-0006 Tier 5 (≤ 90-day rotation SLA).

**ADR-0062 D7 — Kernel-owned verifier surface.** `IWebhookSignatureVerifier` in `HoneyDrunk.Kernel.Abstractions`; Kernel ships a single concrete `HmacSha256SignatureVerifier`; per-provider verifiers live next to the receiver they serve and register against this interface.

**ADR-0062 D8 — Reuse `IIdempotencyStore` per ADR-0042.** Each receiver dedupes by `webhook:{provider}:{event-id}` using the existing claim/process/complete pattern; TTL = ADR-0042 D4 Standard (7 days) by default, Stripe receiver uses Billing/Audit (30 days).

**ADR-0062 D11 — Audit emit on every receipt.** Category `WebhookReceipt`, target `{provider}:{receiver}`, outcome `Succeeded` / `Denied` / `Deduped`, no payload body.

**ADR-0062 Consequences — Invariants.** ADR-0062 adds exactly four invariants: (1) verifier + 5-minute replay window registration requirement; (2) dedup by `webhook:{provider}:{event-id}` against `IIdempotencyStore`; (3) Vault secret-naming convention and multi-key shape; (4) `WebhookReceipt` audit emit on every receipt.

## Constraints
- **Acceptance precedes flip.** ADR-0062 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers are claimed via `constitution/invariant-reservations.md`, not hardcoded.** Read the **Active Reservations** table at PR authoring time. Pick the next free contiguous block of four above the highest existing claim (`next free = max(invariants.md accepted ceiling, all existing reservation upper bounds) + 1`). Add a row to **Active Reservations** in the same commit that adds the invariants to `invariants.md`. Do not renumber existing invariants. Throughout this packet body and any downstream packet that references the numbers, use the `{N1}`–`{N4}` placeholders so a late-merge collision is a single re-substitution; substitute the concrete numbers only in the actual `invariants.md` and `invariant-reservations.md` edits.
- **Collision handling.** If a `git pull` produces a conflict on `invariant-reservations.md`, shift this block upward to the new `next free`, update every `{N1}`–`{N4}` site in this packet and every downstream packet that references the numbers, then push. **First merge wins** per the reservation file's rule 4.
- **New section.** The four webhook-receiver invariants are a new cross-cutting topic; create a `## Webhook Invariants` section after `## Audit Invariants` rather than appending to an unrelated section.
- **Do not edit ADR-0042's invariants.** ADR-0062 D8 *reuses* ADR-0042's `IIdempotencyStore` contract; it does not amend ADR-0042's invariants.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0062`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0062 to Accepted, add the four webhook-receiver invariants to `constitution/invariants.md`, and register the webhook-verification initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0062 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0062 Inbound Webhook Verification rollout, Wave 1.
- ADRs: ADR-0062 (primary), ADR-0042 (idempotency contract this ADR reuses), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0062 stays Proposed until this PR merges.
- Claim a contiguous block of four invariant numbers via `constitution/invariant-reservations.md`: `next free = max(invariants.md accepted ceiling, all existing reservation upper bounds) + 1`. Add a row to **Active Reservations**, use the computed numbers in `invariants.md`, and keep `{N1}`–`{N4}` placeholders in this packet body so a late-merge collision is a single re-substitution. Do not renumber existing invariants. **First merge wins** on collision — shift upward and update every downstream packet that references the block before pushing.

**Key Files:**
- `adrs/ADR-0062-inbound-webhook-verification.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
