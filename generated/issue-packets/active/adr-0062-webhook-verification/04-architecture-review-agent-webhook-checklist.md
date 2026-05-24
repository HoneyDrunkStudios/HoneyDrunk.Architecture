---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0062", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0062"]
wave: 3
initiative: adr-0062-webhook-verification
node: honeydrunk-architecture
---

# Add the ADR-0062 webhook-receiver checklist to the review and security specialist agents

## Summary
Update `.claude/agents/review.md` and the `security` specialist review prompt with a webhook-receiver checklist that surfaces ADR-0062's load-bearing rules at PR review time: verifier registered against `IWebhookSignatureVerifier`; raw-body middleware wired on the receiver's route; Vault secret name follows `webhook-{provider}-{purpose}-signing-secret`; dedup TTL set on the `AddWebhookReceiver<T>` registration; audit emit wired against `IAuditLog` with category `WebhookReceipt`; 5-minute replay window enforced; no signing secrets or raw bodies in logs.

## Context
ADR-0062's follow-up work list explicitly names this packet: "Update `.claude/agents/review.md` and the `security` specialist review prompt with a webhook-receiver checklist: verifier registered, raw-body middleware on the route, secret name follows convention, dedup TTL set, audit emit wired." Per the coupling rule with the review agent (review.md context-loading is a superset of scope's; invariant 33), every new contract the scope agent authors against must have a matching review-time check.

The review agent enforces invariants and ADR decisions at PR time across every `enabled` repo (per invariant 52). The `security` specialist is one of the ADR-0046 specialist review agents that gets invoked on PRs touching auth, secrets, audit, or — now — webhook-receiver surfaces. The webhook-receiver checklist needs to land in both surfaces because:
- The general `review.md` is what runs on every non-draft PR (invariant 52); a PR that adds a webhook receiver without the checklist would slip through if only the specialist surface knows about it.
- The `security` specialist is the depth review for PRs that hit security-critical surfaces; for webhook receivers it gets the extended checklist (constant-time comparison, replay window, multi-key shape, audit emit, body-hash-not-body logging).

This is a docs/prompts packet. No code, no .NET project. Per invariant 33 (review-and-scope context-loading symmetry), this packet keeps the review surface in lockstep with what the scope agent now expects to author.

## Scope
- `.claude/agents/review.md` — add a `## Webhook Receiver Checklist` section (or extend the existing checklist surface, matching the file's existing structure) with the ADR-0062 rules every webhook-receiver-touching PR must satisfy.
- `copilot/specialists/security.md` (or whatever the canonical `security` specialist prompt file path is in the repo) — add the same checklist with the extended security-depth items (constant-time comparison, body-hash-not-body logging, no diagnostic responses on 401, audit-on-deny).
- No other files. No catalog changes, no invariant changes — invariants land in packet 00.

## Proposed Implementation
1. **`.claude/agents/review.md`** — add (or extend) the webhook-receiver section. The checklist items, expressed as the kind of bullet a reviewer flips through during a webhook-receiver PR:
   - [ ] The receiver registers a `IWebhookSignatureVerifier` (Kernel default `HmacSha256SignatureVerifier`, or a per-provider verifier living next to the receiver) via `services.AddWebhookReceiver<T>(options => …)`.
   - [ ] The Vault secret name follows `webhook-{provider}-{purpose}-signing-secret` (ADR-0062 D5; invariant 80).
   - [ ] The `WebhookReceiverOptions.ReplayWindow` is `TimeSpan.FromMinutes(5)` or the default is taken (5 minutes, hard-pinned per D3; invariant 78).
   - [ ] The `WebhookReceiverOptions.DedupTtl` is set: 7 days for standard receivers (ADR-0042 D4 Standard), 30 days for Billing/Audit-class receivers (Stripe, per ADR-0062 D8; ADR-0042 D4 Billing/Audit tier).
   - [ ] The `WebhookReceiverOptions.MaxBodyBytes` is left at the 1 MiB default unless a provider's known payloads exceed it (ADR-0062 D4).
   - [ ] If the receiver is ASP.NET-Core-hosted, `RawBodyPreservationMiddleware` is on the receiver's route (wired automatically by `AddWebhookReceiver<T>`; verify no manual route registration bypasses it).
   - [ ] If the receiver is Function-App-hosted (Stripe per ADR-0037 D4), it consumes the raw body via the Functions binding (`byte[]`/`Stream` overload) and calls `IWebhookSignatureVerifier` + `IIdempotencyStore` directly.
   - [ ] The response convention matches ADR-0062 D9: `200` (verified, empty body), `400` (replay window or malformed, RFC 7807), `401` (signature failed, empty body — no leak of which check failed), `409` (concurrent delivery, RFC 7807), `413` (body cap exceeded, RFC 7807). `5xx` reserved for genuine server errors only; never used for verification failure.
   - [ ] Every successful verification emits an `IAuditLog` record with `category = "WebhookReceipt"`, `target = "<provider>:<receiver>"`, `outcome` in `{Succeeded, Denied, Deduped}` (ADR-0062 D11; invariant 81). A failed verification (`401`) also emits with `outcome = Denied`.
   - [ ] No raw body in logs, traces, or audit; log only the body's size and its SHA-256 hash prefix (first 16 hex chars). No signing secrets in logs, traces, exceptions, or telemetry (invariant 8 + ADR-0062 D10).
2. **`copilot/specialists/security.md`** — same checklist plus the security-depth items:
   - [ ] Signature comparison uses `CryptographicOperations.FixedTimeEquals` (constant-time) — never `string.Equals` or `==` on the byte arrays (timing-side-channel).
   - [ ] Multi-key verification iterates all `CandidateSecrets` (ADR-0062 D6) and returns on first match; the verifier does not short-circuit on the first candidate alone.
   - [ ] The Vault entry value matches one of ADR-0062 D6's three shapes (bare string, newline list, or JSON `{ "active", "previous": [...] }`); the JSON object form is preferred for new receivers.
   - [ ] No diagnostic detail leaks in the `401` response body (D9 + D10 — the diagnostic detail lives in the log and the audit emit, never in the response).
   - [ ] If the receiver bridges to a Service Bus topic (per ADR-0028 / ADR-0037 D2), the emitted message carries an `IdempotencyKey` derived from the webhook event id (`webhook:{provider}:{event-id}`) — the downstream consumer dedupes against the same key shape.
   - [ ] The receiver does NOT distinguish "header missing" from "header malformed" from "signature mismatch" in the response (D9). All three are `401` with empty body.
3. **Verify the file paths against the repo's actual layout** — `.claude/agents/review.md` is canonical per the memory note "Architecture agents hardlinked globally"; the `security` specialist file path follows the repo's ADR-0046 layout (it may be `copilot/specialists/security.md`, `.claude/agents/security.md`, or similar — match the existing file at execution time).
4. No version bump (`HoneyDrunk.Architecture` is not a versioned .NET solution; the docs sync via PR).
5. Hardlink-resync command: per the memory note, Architecture agents are hardlinked into `~/.claude/agents/` and need a Claude Code restart to register. The packet's PR description should remind the operator to run the resync (if a `resync` script exists in the repo) and restart Claude Code after merge so the new prompts go live on subsequent reviews. The restart itself is a human action, not an acceptance criterion of this packet.

## Affected Files
- `.claude/agents/review.md`
- `copilot/specialists/security.md` (or the canonical security-specialist file at the path the repo uses)

## NuGet Dependencies
None. This packet touches only Markdown agent prompts; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps; the review agent's home is here per ADR-0044.
- [x] No code change in any other repo.
- [x] No invariant change in this packet — invariants land in packet 00; this packet is the *enforcement* surface for those invariants at review time.
- [x] No catalog change in this packet — catalogs land in packet 01.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` carries a webhook-receiver checklist covering verifier registration, raw-body middleware (ASP.NET Core case + Function-App case), Vault secret naming convention, replay window, dedup TTL, max body bytes, response convention, audit emit, and log-redaction rules
- [ ] `copilot/specialists/security.md` (or the canonical security-specialist file) carries the same checklist plus the security-depth items (constant-time comparison, multi-key iteration, Vault entry value shape, no diagnostic leak in `401`, downstream-message-key-derives-from-webhook-event-id, no header-status-distinction in response)
- [ ] Each checklist item that maps to a numbered invariant (8, 78, 79, 80, 81) cites the invariant inline — the executor reading the prompt does not have to follow the citation; the rule text is right there (the self-containment rule for agent prompts is the same as for issue packets)
- [ ] Each checklist item that maps to an ADR-0062 decision cites the decision (D1, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12) inline
- [ ] No file outside `.claude/agents/` and `copilot/` is modified (no invariant edits — those land in packet 00)
- [ ] The PR description notes that the new prompts go live only after the Architecture agents are resynced to `~/.claude/agents/` and Claude Code is restarted (operator action, not a packet acceptance criterion)

## Human Prerequisites
- [ ] After this PR merges, the operator runs the Architecture-agent resync command (per the memory note "Architecture agents hardlinked globally") and restarts Claude Code so the updated `review.md` and `security` specialist prompts are picked up. Subsequent PRs will be reviewed against the new checklist. This is a one-time action, not a recurring step.

## Referenced ADR Decisions
**ADR-0062 D4 — Raw-body preservation; ASP.NET Core vs Function-App split.** ASP.NET-Core-hosted receivers use the Kernel middleware; Function-App-hosted receivers (Stripe per ADR-0037 D4) consume bytes via the Functions binding and call `IWebhookSignatureVerifier` directly.

**ADR-0062 D5 — Vault secret-naming convention.** `webhook-{provider}-{purpose}-signing-secret`.

**ADR-0062 D6 — Multi-key verification.** Single Vault entry, bare-string / newline-list / JSON object shapes; JSON object preferred for new receivers.

**ADR-0062 D7 — `IWebhookSignatureVerifier`.** Per-provider verifiers register against this interface; Kernel ships the SHA-256 default.

**ADR-0062 D8 — Reuse `IIdempotencyStore`.** Receiver dedup key `webhook:{provider}:{event-id}`; standard TTL 7 days; Stripe TTL 30 days (Billing/Audit tier).

**ADR-0062 D9 — Response convention.** 200 / 400 / 401 / 409 / 413; empty body on 200 and 401; RFC 7807 envelope on 400 / 409 / 413; no diagnostic detail in 401.

**ADR-0062 D10 — Logging and redaction.** Never log signing secrets in any form. Never log the raw signed body in full. Log body size + SHA-256 hash prefix (first 16 hex). Always log verification outcome, signature header presence, timestamp drift, dedup outcome.

**ADR-0062 D11 — Audit emit on every webhook receipt.** Category `WebhookReceipt`; outcome `Succeeded` / `Denied` / `Deduped`; no body contents in the audit record.

**ADR-0046 — Specialist review agents.** The `security` specialist gets the extended depth-review checklist for webhook-receiver PRs. The general `review.md` carries the standard checklist.

## Constraints
- **Invariant 33 — Review-agent and scope-agent context-loading contracts are coupled.** Every new contract the scope agent authors against has a matching review-time check; this packet keeps the review surface in lockstep with what scope now expects to file.
- **Inline citation, not pointer.** Each checklist item cites invariants and ADR decisions by inline text plus number; a reviewer reading the prompt does not need to follow the citation to know the rule.
- **No invariant edits in this packet.** Invariants land in packet 00; this packet is the enforcement surface.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0062`, `wave-3`

## Agent Handoff

**Objective:** Add the ADR-0062 webhook-receiver checklist to `.claude/agents/review.md` and to the `security` specialist review prompt so every webhook-receiver PR is reviewed against the ADR's load-bearing rules.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Bring the review and security-specialist surfaces in lockstep with what scope expects to file under ADR-0062 (invariant 33).
- Feature: ADR-0062 Webhook Verification rollout, Wave 3 (parallel with packet 03).
- ADRs: ADR-0062 D4/D5/D6/D7/D8/D9/D10/D11 (primary), ADR-0046 (specialist surface), ADR-0044 (review-agent home).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0062 Accepted and its invariants (78, 79, 80, 81) live before the review prompts cite them.

**Constraints:**
- Inline citation (invariant + ADR decision text), not just numbers — a reviewer reads the prompt; they do not chase footnotes.
- No invariant edits (those landed in packet 00); no catalog edits (those landed in packet 01).
- Operator must resync agents and restart Claude Code after merge — note in the PR description.

**Key Files:**
- `.claude/agents/review.md`
- `copilot/specialists/security.md` (or the canonical security-specialist file path at execution time)

**Contracts:** None changed — agent prompt update.
