---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault.Rotation
labels: ["feature", "tier-2", "core", "adr-0062", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0062"]
wave: 3
initiative: adr-0062-webhook-verification
node: honeydrunk-vault-rotation
---

# Add scheduled rotators for Stripe, GitHub, and Svix webhook signing secrets

## Summary
Add scheduled `IRotator` implementations to `HoneyDrunk.Vault.Rotation` for the three webhook-signing-secret providers that expose a rotation API — Stripe, GitHub, and Svix — wiring them into the rotation Function's scheduled-rotator list per ADR-0006 Tier 2. Twilio (no rotation API at time of writing) gets a documented portal-runbook fallback that ends in a Key Vault write so the receiver's multi-key verifier (ADR-0062 D6) picks the new version up automatically (invariant 21).

## Context
ADR-0062 D5 places every webhook signing secret in Vault under the `webhook-{provider}-{purpose}-signing-secret` naming convention, classifies them as Tier 2 per ADR-0006 Tier 5 (third-party, ≤ 90-day rotation SLA), and explicitly names where rotation lives: "the rotation Function (`HoneyDrunk.Vault.Rotation` per ADR-0006 Tier 2) writes the new version and Event Grid invalidates per ADR-0006 Tier 3. Where the provider does not support rotation through an API (Twilio at time of writing), Tier 2's portal-runbook fallback applies: the runbook ends in a Key Vault write, and the receiver picks the new version up automatically per Invariant 21."

ADR-0062's own follow-up work list calls this out: "Confirm with ADR-0006's rotation surface that Stripe, GitHub, and Svix signing-secret rotation are added to `HoneyDrunk.Vault.Rotation`'s scheduled-rotator list at the next rotation-Function packet wave." This packet is that work.

`HoneyDrunk.Vault.Rotation` is a live Node exposing `IRotator` and `RotationResult` (per `catalogs/contracts.json`). It consumes `HoneyDrunk.Kernel` (context for the timer job) and `HoneyDrunk.Vault` (`ISecretStore` for the Key Vault write). The new rotators are additive — they slot into the existing rotator-registration shape without changing the contract.

Per provider:
- **Stripe** — endpoint signing secrets are managed in the Stripe Dashboard / via the Stripe API (`/v1/webhook_endpoints/{id}`). Stripe supports two endpoint signing secrets coexisting during rotation (the documented rotation pattern). Rotation creates a new signing secret on the Stripe side, writes it into the Key Vault entry's "active" position with the previous secret moving to "previous" (ADR-0062 D6 multi-key shape), and signals Event Grid invalidation per ADR-0006 Tier 3.
- **GitHub** — webhook secrets are managed via the GitHub REST API (`PATCH /repos/{owner}/{repo}/hooks/{hook_id}` for repo hooks, `PATCH /orgs/{org}/hooks/{hook_id}` for org hooks). GitHub's documented rotation supports overlapping keys for organisation webhooks (different shape than Stripe; verify the exact API at execution time — GitHub's rotation surface has changed over the years). Rotation generates a new secret, calls the GitHub API to update the webhook, writes the new value to Vault in the D6 multi-key shape.
- **Svix** — `POST /api/v1/app/{app_id}/endpoint/{endpoint_id}/secret/rotate` rotates the endpoint signing secret; the response carries the new secret; the previous secret stays valid for an overlap window (Svix-configurable, default 24 hours per Svix docs at time of writing). Rotation calls Svix, writes the new value to Vault in the D6 multi-key shape.
- **Twilio** — Twilio's webhook signing secret is the Auth Token; rotation requires logging into the Twilio Console (no rotation API at time of writing). This packet does NOT ship a Twilio rotator. It DOES document the portal-runbook fallback in `repos/HoneyDrunk.Vault.Rotation/integration-points.md` (or the equivalent docs surface the repo uses) — Tier 2's "the runbook ends in a Key Vault write, and the receiver picks the new version up automatically per Invariant 21."

Confirm `HoneyDrunk.Vault.Rotation`'s current version at execution time and bump one minor per invariant 27.

## Scope
- New `IRotator` implementations:
  - `StripeWebhookSigningSecretRotator` — `webhook-stripe-billing-signing-secret` (rotation API; D6 multi-key write).
  - `GitHubWebhookSigningSecretRotator` — `webhook-github-observe-signing-secret` (rotation API; D6 multi-key write).
  - `SvixWebhookSigningSecretRotator` — `webhook-resend-notify-signing-secret` (Resend uses Svix's signing-secret model; rotation via Svix API).
- DI registration for the new rotators in the rotation Function's scheduled-rotator list.
- Documented portal-runbook for Twilio (`webhook-twilio-notify-signing-secret`) ending in a Key Vault write.
- Unit tests covering the multi-key write shape, the active+previous overlap, and the API-call boundary (Stripe / GitHub / Svix clients mocked).
- Version bump across the `HoneyDrunk.Vault.Rotation` solution; CHANGELOG/README updates.
- Docs surface (the repo's `README.md` or its rotation runbook doc, whichever is canonical) — the four secrets and their rotation paths listed.

## Proposed Implementation
1. **`StripeWebhookSigningSecretRotator : IRotator`**:
   - Reads the Stripe API key from Vault (existing pattern in the repo — `ISecretStore`-resolved; never read from env directly per invariant 9).
   - Reads the current `webhook-stripe-billing-signing-secret` Vault entry; parses the D6 multi-key shape (bare string, newline list, or JSON `{ "active", "previous": [...] }` — the JSON object is preferred for new rotators per ADR-0062 D6's "new receivers SHOULD use the JSON object form").
   - Calls the Stripe API to generate / register the new endpoint signing secret (the exact endpoint depends on whether Studios is rotating an existing endpoint's secret or pairing two endpoints; verify against current Stripe docs at execution time).
   - Writes the new value back to the Vault entry in the JSON object form: `{ "active": "<new>", "previous": ["<old>"] }`. This is the D6 multi-key shape; the receiver's verifier accepts the first match across both candidates during the overlap window.
   - Returns a `RotationResult` indicating success + the new version metadata.
   - Audit-emits per ADR-0030/0031 — `category: "SecretRotation"`, `target: "webhook-stripe-billing-signing-secret"`, `outcome: Succeeded` / `Failed`. (Note: the rotation-emit category is the existing rotation-substrate convention, not the `WebhookReceipt` category — that is the receiver's emit.)
2. **`GitHubWebhookSigningSecretRotator : IRotator`** — same shape, GitHub REST API. Confirm the API at execution time (`PATCH /repos/{owner}/{repo}/hooks/{hook_id}` vs `PATCH /orgs/{org}/hooks/{hook_id}` vs the newer rotation endpoint if GitHub has shipped one). The webhook target details (which repo, which org) come from configuration — `IConfigProvider` for the non-secret config (the webhook id) and `ISecretStore` for the GitHub PAT used to authenticate the API call.
3. **`SvixWebhookSigningSecretRotator : IRotator`** — same shape, Svix `POST /api/v1/app/{app_id}/endpoint/{endpoint_id}/secret/rotate`. The Svix API key, app id, and endpoint id come from configuration. Svix's overlap window is configurable per tenant; the rotator writes both the new active and the previous so the receiver tolerates both during the overlap.
4. **DI registration** — add the three rotators to the rotation Function's scheduled-rotator list (follow the repo's existing registration convention; the existing rotators registered for other Tier-5 secrets are the template). Schedule cadence: ADR-0006 Tier 5 says ≤ 90-day rotation SLA; the rotation Function's scheduler should run the rotators on a cadence well inside that — e.g. every 60 days. Match the cadence the existing Tier-5 rotators use; do not invent a new cadence shape.
5. **Twilio portal runbook** — add a section to the repo's rotation runbook doc:
   - Title: "Rotate `webhook-twilio-notify-signing-secret` (Twilio Auth Token)."
   - Steps: log into the Twilio Console; rotate the Auth Token; write the new value to `kv-hd-notify-{env}` under the `webhook-twilio-notify-signing-secret` name in the D6 multi-key shape (move the previous Auth Token into the `previous` array; set the new one to `active`); Event Grid invalidation propagates automatically per ADR-0006 Tier 3 and the receiver picks the new version up per invariant 21.
   - Cadence: same ≤ 90-day SLA (ADR-0006 Tier 5); a calendar reminder is the operator's mechanism since there is no scheduled rotator.
   - The runbook ends in a Key Vault write — this is the load-bearing detail per ADR-0062 D5 ("the runbook ends in a Key Vault write").
6. **Tests** — unit tests on each rotator with the provider API client mocked (per ADR-0047 Tier 1 unit-test stack: xUnit v2 + NSubstitute + AwesomeAssertions). Cover: (a) a successful rotation writes the JSON object shape `{ "active": "<new>", "previous": ["<old>"] }`; (b) the previous value is preserved (the receiver needs it during overlap); (c) a failed API call returns a `RotationResult` with the failure outcome and does NOT write to Vault (atomicity — never strand the receiver with a stale Vault write and a stale provider secret). No `Thread.Sleep` (invariant 51).
7. **Versioning** — bump every non-test `.csproj` in the `HoneyDrunk.Vault.Rotation` solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` new version entry; per-package CHANGELOGs only for changed packages.
8. **README** — update the `HoneyDrunk.Vault.Rotation` README's "rotated secrets" list (or whatever the existing surface is) to include the four new webhook signing secrets and link to ADR-0062 D5 / D6 for the convention.

## Affected Files
- `HoneyDrunk.Vault.Rotation/` — three new rotator type files + the registration call site + the rotation runbook doc.
- Every non-test `.csproj` in the solution — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs for changed packages.
- The unit-test project — new tests.

## NuGet Dependencies
- **`HoneyDrunk.Vault.Rotation`** — may need:
  - **Stripe SDK** — `Stripe.net` (the official Stripe .NET SDK). Verify the exact package name at execution time.
  - **GitHub client** — `Octokit` (the most common .NET GitHub API client) or the lighter REST option (`HttpClient`-based). If the repo already uses a GitHub client elsewhere, match that choice.
  - **Svix client** — `Svix` (Svix's official .NET SDK). Verify name at execution time.
  - Alternative: take none of the SDKs and roll `HttpClient` calls. The SDK-vs-`HttpClient` choice is a one-line tradeoff per provider; state it in the PR. Prefer the official SDKs unless they pull in transitive dependencies the repo wants to avoid.
- `HoneyDrunk.Vault` is already a direct dependency (the repo `consumes` honeydrunk-vault per relationships.json).
- `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` are already direct dependencies (context for the timer jobs).
- The unit-test project uses the repo's existing test stack (ADR-0047) — no new test dependencies expected beyond the provider-SDK reference if the tests touch the SDK types directly.
- `HoneyDrunk.Standards` is already on every `.csproj` (`PrivateAssets: all`).

## Boundary Check
- [x] All code change is in `HoneyDrunk.Vault.Rotation`. Routing rule "rotation, secret rotation, IRotator, RotationResult, third-party rotation, Vault.Rotation → HoneyDrunk.Vault.Rotation" maps exactly.
- [x] No contract change — the rotators implement the existing `IRotator` interface.
- [x] The rotators write to Vault via the existing `ISecretStore` pattern; secret values never leak through logs/traces (invariant 8).
- [x] No dependency on `HoneyDrunk.Notify`, `HoneyDrunk.Observe`, `HoneyDrunk.Communications`, or `HoneyDrunk.Audit` — the rotator emits audit via the existing rotation-substrate audit path (whatever the repo already uses), not by taking a new package dependency on Audit.

## Acceptance Criteria
- [ ] `StripeWebhookSigningSecretRotator`, `GitHubWebhookSigningSecretRotator`, `SvixWebhookSigningSecretRotator` exist as `IRotator` implementations and are registered in the rotation Function's scheduled-rotator list
- [ ] Each rotator writes the Vault entry in the ADR-0062 D6 JSON object shape `{ "active": "<new>", "previous": ["<old>"] }`, preserving the previous value during overlap
- [ ] A failed provider API call returns a `RotationResult` with the failure outcome and does NOT write to Vault (atomicity — the receiver is never stranded with a stale Vault write)
- [ ] Each rotator resolves the provider API credentials via `ISecretStore` (invariant 9) — never from env directly
- [ ] Each rotator's logs/traces contain no secret values (invariant 8); only the secret *name* and rotation outcome are observable
- [ ] Rotation cadence matches the existing Tier-5 rotators in the repo (ADR-0006 Tier 5: ≤ 90-day rotation SLA; in practice 60 days or whatever the existing cadence is)
- [ ] Twilio runbook is added to the repo's rotation runbook doc; the runbook ends in a Key Vault write to `webhook-twilio-notify-signing-secret` in the D6 multi-key shape
- [ ] Unit tests cover: successful rotation writes the JSON object shape; previous value is preserved; failed API call returns failure and does not write to Vault
- [ ] No `Thread.Sleep` in tests (invariant 51)
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry; per-package CHANGELOGs updated only for changed packages
- [ ] `README.md` updated to list the four new webhook signing secrets in the "rotated secrets" surface (or whatever the existing convention is) with a link to ADR-0062 D5 / D6
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Provision the four Vault entries before the rotators run.** Each receiver Node's Key Vault needs the initial signing-secret value seeded manually before the scheduled rotator can rotate it:
  - `webhook-stripe-billing-signing-secret` in `kv-hd-billing-{env}` (created when Billing.Webhooks stands up per ADR-0037 D4 — does not exist yet; Stripe rotator activates when that vault exists).
  - `webhook-github-observe-signing-secret` in `kv-hd-observe-{env}` (created when the Observe GitHub connector lands per ADR-0010 Phase 2 — does not exist yet; GitHub rotator activates when that vault exists).
  - `webhook-resend-notify-signing-secret` in `kv-hd-notify-{env}` (Resend's signing secret; seeded by the Notify Cloud rollout per ADR-0027). Initial seed value comes from the Resend dashboard.
  - `webhook-twilio-notify-signing-secret` in `kv-hd-notify-{env}` (Twilio Auth Token; seeded by the Notify Cloud rollout per ADR-0027). Initial seed value comes from the Twilio Console.
  Until each Vault entry exists, the corresponding rotator should skip-with-info (not fail) — a rotator scheduled against a non-existent Vault entry is a deploy-ordering condition, not an error. Confirm the skip-with-info behaviour matches the repo's existing convention for not-yet-provisioned secrets.
- [ ] **Provider API credentials seeded in `kv-hd-vault-rotation-{env}`** (or wherever the rotation Function's own secrets live in the repo's existing convention):
  - Stripe API key with permission to rotate webhook signing secrets.
  - GitHub PAT (or GitHub App credential) with permission to rotate the configured webhook secret.
  - Svix API key with permission to call the rotate-endpoint endpoint.
  These are Tier-2-or-3 secrets in their own right (provider API keys); they get their own rotation paths per the repo's existing convention.
- [ ] **Rotation Function's Managed Identity** needs the Key Vault `set` permission on each consuming Node's vault (`kv-hd-billing-{env}`, `kv-hd-observe-{env}`, `kv-hd-notify-{env}`). This may already exist for other Tier-5 rotators; verify and grant if missing.
- [ ] **Event Grid wiring** — the rotation-driven cache invalidation per ADR-0006 Tier 3 should already be set up for other rotated secrets; confirm the new secret names are within the existing Event Grid scope (typically a Key-Vault-wide subscription, so they should be).
- [ ] **Twilio portal step**: the Twilio rotation runbook is a recurring portal-click; add a calendar reminder per the ≤ 90-day SLA (ADR-0006 Tier 5). The Twilio Console is the only path.

## Referenced ADR Decisions
**ADR-0062 D5 — Vault secret-naming convention and Tier-2 classification.** `webhook-{provider}-{purpose}-signing-secret`; Tier 2 per ADR-0006 Tier 5 (third-party, ≤ 90-day rotation SLA). Where the provider supports overlapping keys during rotation (D6), the rotation Function writes the new version and Event Grid invalidates per ADR-0006 Tier 3. Where the provider does not support rotation through an API (Twilio at time of writing), Tier 2's portal-runbook fallback applies: the runbook ends in a Key Vault write, and the receiver picks the new version up automatically per Invariant 21.

**ADR-0062 D6 — Multi-key verification.** Single Vault entry holds the candidate secrets in either a bare string, newline list, or JSON `{ "active", "previous": [...] }` object. New rotators SHOULD use the JSON object form. This matches Stripe's documented rotation pattern, GitHub's, and Svix's.

**ADR-0062 Affected Nodes — Vault.Rotation.** "The rotation Function gains the webhook-signing-secret rotators where the provider supports it (Stripe today; GitHub on rotation-API; Svix on rotation-API). Twilio falls through to the portal-runbook fallback."

**ADR-0006 Tier 5 — Third-party secrets, ≤ 90-day rotation SLA.** Provider-shaped rotation. Where the provider has a rotation API, the rotator automates it; where it doesn't, the portal-runbook fallback ends in a Vault write.

## Constraints
- **Invariant 9 — Vault is the only source of secrets.** Provider API credentials resolve via `ISecretStore`, never from env.
- **Invariant 8 — Secret values never appear in logs/traces/exceptions/telemetry.** The rotator logs the secret *name* and outcome; never the secret value. Provider SDK clients should be configured not to log request/response bodies that contain secrets (verify per SDK).
- **Invariant 21 — Applications must never pin to a specific secret version.** The D6 multi-key shape is the JSON object; the receiver reads the *current* version of the Vault entry and accepts either candidate. Never write version-suffixed key names (`-v1`, `-v2`); always update the single canonical entry.
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` in `HoneyDrunk.Vault.Rotation` together.
- **Invariant 51 — no `Thread.Sleep` in test code.**
- **Atomicity:** if the provider API call fails, do NOT write to Vault. Stranding the receiver with a new Vault value the provider does not yet sign with breaks verification for the overlap window.

## Labels
`feature`, `tier-2`, `core`, `adr-0062`, `wave-3`

## Agent Handoff

**Objective:** Wire Stripe / GitHub / Svix webhook-signing-secret rotators into `HoneyDrunk.Vault.Rotation` and document the Twilio portal-runbook fallback.

**Target:** `HoneyDrunk.Vault.Rotation`, branch from `main`.

**Context:**
- Goal: Bring the four new webhook signing secrets onto the existing Tier-5 rotation path; close ADR-0062 D5's "the rotation Function writes the new version" by name.
- Feature: ADR-0062 Webhook Verification rollout, Wave 3 (parallel with packet 04).
- ADRs: ADR-0062 D5/D6 (primary), ADR-0006 Tier 2/3/5 (the rotation substrate this composes against), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0062 Accepted and its invariants (especially 80 — Vault secret-naming convention with multi-key shape) live.

**Constraints:**
- D6 JSON object shape (`{ "active", "previous": [...] }`) is the preferred multi-key form for new rotators.
- Atomicity: failed provider API call returns failure outcome and does NOT write to Vault.
- Twilio gets a runbook, not a rotator (no rotation API today); the runbook ends in a Key Vault write so the receiver picks the new version up automatically (invariant 21).
- Provider API credentials via `ISecretStore` (invariant 9); secret values never logged (invariant 8).
- Bump the whole solution one minor version (invariant 27).

**Key Files:**
- `HoneyDrunk.Vault.Rotation/` — three new rotator source files + the registration call site + the rotation runbook doc.
- Every non-test `.csproj`; repo-level `CHANGELOG.md`.

**Contracts:**
- Implements existing `IRotator` interface; no contract change.
