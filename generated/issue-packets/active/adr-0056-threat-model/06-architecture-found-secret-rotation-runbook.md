---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "security", "docs", "adr-0056", "wave-4"]
dependencies: ["packet:00"]
adrs: ["ADR-0056", "ADR-0006"]
accepts: ["ADR-0056"]
wave: 4
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Author the found-secret rotation runbook with time-to-rotation targets and pre-staged commands

## Summary
Author the found-secret rotation runbook in `business/context/` per ADR-0056 D8: **immediate rotation, not deletion** as the response posture; 1-hour time-to-rotation for high-sensitivity secrets (model API keys, Stripe production keys, Azure subscription credentials); 4-hour target for lower-sensitivity secrets; pre-staged rotation commands per secret class so the operator can execute rather than re-derive at 3 AM; explicit "history rewriting is cosmetic, rotation is the actual remediation" framing. Cross-references ADR-0006 for rotation mechanics.

## Context
ADR-0056 D8 commits to GitHub-native secret scanning Grid-wide with push protection. The interesting part of D8 is the **found-secret runbook**, not the scanning enablement (that's packet 08 in `HoneyDrunk.Actions`). The runbook captures three load-bearing rules:

1. **Immediate rotation, not deletion.** Deletion alone is insufficient — the secret may already have been scraped before detection. The response is rotation at the source (Azure / Stripe / OpenAI / etc.), then Vault + consuming-environment update, then confirm rotation is in use. Only then address git history (and history rewriting is cosmetic, not actual remediation).
2. **Time-to-rotation targets.** 1-hour for high-sensitivity secrets (model API keys per AI-8, Stripe production keys, Azure subscription credentials). 4-hour for lower-sensitivity (third-party SaaS API keys with limited blast radius). Time starts at **detection**, not at operator-attention — detection may happen overnight; the runbook should be operable by a half-asleep operator without multi-step approvals.
3. **Pre-staged rotation commands.** For the high-sensitivity secrets, the runbook lists the **exact** rotation command sequence per secret class. The operator executes rather than re-derives at 3 AM. The pre-staging is the difference between "I think the runbook said to rotate the Azure subscription key but I have to look up how" and "step 1: open this portal page, step 2: click 'Rotate', step 3: copy new key, step 4: paste into this Vault secret name."

ADR-0006 (Accepted) governs the underlying rotation mechanics — Tier 1 Azure-native rotation, Tier 2 third-party rotation via Function, certificate auto-renewal. This runbook does not re-decide those — it **operationalizes** them for the found-secret emergency case.

**The runbook lives in `business/context/`** (operator-context location, per the precedent set by ADR-0040 packet 08 / ADR-0045 packet 06 / the security-incident-runbook from packet 05). The exact file path is verified at edit time:
- If an existing secret-management runbook lives in `business/context/`, extend it.
- If a Vault-rotation runbook exists (per ADR-0006), extend or cross-reference it.
- If neither exists, create `business/context/found-secret-rotation-runbook.md`.

**Coupling with ADR-0006.** ADR-0006 is the source-of-truth for rotation mechanics (Tier 1 / Tier 2 / cert auto-renewal). This runbook cites ADR-0006 D3/D4/D5 by reference and embeds **only the operational pre-staged commands** — the operator runs them, the ADR explains them.

**The pre-staged commands are concrete.** This is the load-bearing detail. Generic prose runbooks fail at 3 AM; the operator needs a checklist with exact portal URLs, exact `az` CLI commands, exact Vault secret names. The executor of this packet authors those concretely per secret class — listing every high-sensitivity secret the Grid currently uses and the exact rotation sequence.

**Coupling with packet 08 (Dependabot + secret scanning enablement).** Packet 08 enables GitHub secret scanning + push protection Grid-wide. This packet's runbook covers what to do **when scanning finds something**. They are complementary; this packet does not depend on packet 08 (the runbook is useful even before scanning is enabled, e.g., for a researcher report or an accidental commit caught by a code review).

**This is a docs packet. No code, no .NET project.**

## Scope
- A found-secret rotation runbook in `business/context/` — verified file path at edit time.

## Proposed Implementation

### Runbook content

Author the runbook with the following sections. Markdown, written for the operator at 3 AM with a half-functioning brain:

```markdown
# Found-secret rotation runbook

> When a secret is detected leaked (push-blocked, post-push-found, researcher report, code review catch), **the response is rotation, not deletion**. Deletion is cosmetic. Rotation is the remediation.

## Response posture

A leaked secret may have been scraped before detection (open-source repo scrapers, GitHub-search bots, malicious actors). Assume the leaked value is compromised; treat its replacement at the source as the load-bearing fix. Rewriting git history removes the value from the repo's history but cannot remove it from clones, forks, or scrapers — history rewriting is **cosmetic**, run after rotation, not before.

## Time-to-rotation targets

Time starts at **detection**, not at operator-attention. The runbook must be operable by a half-asleep operator without multi-step approvals.

| Secret class | Target | Examples |
|---|---|---|
| High-sensitivity | **1 hour** | Model API keys (OpenAI, Anthropic, Azure OpenAI) per AI-8; Stripe production keys; Azure subscription credentials; Auth signing keys |
| Lower-sensitivity | **4 hours** | Third-party SaaS API keys with limited blast radius (Resend, Twilio, GitHub PATs scoped narrowly) |

## Universal rotation sequence

For any class:

1. **Rotate at the source.** Generate a new credential at the source service (Azure / Stripe / OpenAI / etc.) per the pre-staged commands below.
2. **Update Vault.** Write the new value to the Vault secret using its existing name. Vault's event-driven cache invalidation (ADR-0006 D5) propagates to consumers.
3. **Confirm the rotated credential is in use.** Verify a real call hits the new credential and the old credential rejects. Vault's audit logs (invariant 22) and the consuming Node's telemetry confirm.
4. **Address git history (cosmetic).** Once steps 1–3 are complete, use `git filter-repo` to remove the leaked value from history if it is in a public repo. **Do not skip steps 1–3 in favor of history rewriting.** History rewriting alone leaves the leaked credential active at the source.
5. **Log the incident.** Even when scanning auto-detects and the rotation completes in under an hour, log the incident at `generated/incidents/{date}-{slug}.md`. The audit substrate (`IAuditLog`) records the rotation event automatically per invariant 47; the human-readable incident note exists for the post-mortem (per packet 05's threat-model-amendment section).

## Pre-staged commands

The runbook needs **exact portal links and exact commands** per high-sensitivity secret class. The executor authors these concretely. The skeleton:

### Model API keys (OpenAI, Anthropic, Azure OpenAI) — 1-hour target

For each model provider, list:
- Portal URL (the operator clicks this).
- Exact steps in the portal UI (verified at edit time — re-verify before each rotation since provider UIs drift).
- Vault secret name to update (per the Grid's secret naming convention — `model-{provider}-key-{env}` per ADR-0041 Proposed).
- Per-environment scope (dev / staging / prod separately; never rotate prod and dev with the same key per ADR-0056 D9 AI-8).

Example (OpenAI):
1. Portal: https://platform.openai.com/account/api-keys
2. Click the rotation icon next to the affected key.
3. Copy the new key value.
4. Update Vault secret `model-openai-key-prod` (or the env-specific name).
5. Verify next AI dispatch in {env} succeeds at the new key.

(The executor fills in the concrete steps for Anthropic, Azure OpenAI, and any other model provider currently used. If a provider lacks a rotation primitive — some smaller providers require manual key generation and deletion — document the workaround in the pre-staged commands.)

### Stripe production keys — 1-hour target

(Executor fills in: Stripe Dashboard URL → API keys section → Roll secret key → Vault secret name `stripe-secret-key-prod` per ADR-0037 Proposed. Note: rolling the secret key invalidates webhooks until the new key is propagated to the webhook endpoint — sequence carefully.)

### Azure subscription credentials — 1-hour target

(Executor fills in: Azure Portal URL → Service Principal → Reset credentials, or Managed Identity rotation if applicable. Note: Azure-native Tier 1 rotation per ADR-0006 — most Azure credentials rotate via Managed Identity assignment changes, not by replacing values in Vault.)

### Auth signing keys — 1-hour target

(Executor fills in: Auth Node's signing-key rotation procedure per ADR-0006 D3 + Vault's per-Node Key Vault structure per invariant 17.)

## Pre-staged commands for lower-sensitivity (4-hour target)

(Executor lists the third-party SaaS keys currently in use — Resend, Twilio, GitHub PATs, etc. — with the same portal-link-and-step structure.)

## What "lower sensitivity" means

A secret is lower-sensitivity if **all** of the following hold:
- The blast radius of compromise is bounded to a specific tenant or a specific external service.
- Compromise does not enable cross-tenant escalation.
- Compromise does not enable cost-amplification beyond a known cap.

A secret that fails any of these is high-sensitivity. **Default to high-sensitivity if unsure** — the asymmetric cost of mis-classifying a high-sensitivity secret as lower-sensitivity (rotation delayed 3 hours, blast radius runs unbounded) exceeds the cost of mis-classifying a lower-sensitivity secret as high-sensitivity (rotation done faster than strictly needed).

## What to do with the leaked value in git history

History rewriting is run **after** rotation completes. Tools:
- `git filter-repo` (preferred) — removes the value from all refs.
- BFG Repo-Cleaner — alternative; older but works.

After rewriting, force-push to the remote. Notify any collaborators who may have pulled the affected commits. Note that **clones, forks, and scrapers** retain the value — the rotation is what makes the leaked value non-load-bearing.

## When the leaked secret is in a still-active branch

If the leaked secret is in a branch that has not yet merged to `main`:
- Rotate at the source as above.
- Force-push the branch with the value removed. No further history work needed (the value never reached `main`).

## When the leaked secret was committed years ago

Older leaks are no less urgent — assume the value was scraped at the time of the leak. Rotate immediately. History rewriting on years-old commits is **futile** (the value is in countless clones and forks); skip it after rotation.

## Cross-references

- ADR-0006 — secret rotation mechanics (Tier 1 / Tier 2 / certificate auto-renewal).
- ADR-0056 D8 — this runbook's source.
- ADR-0041 (Proposed) — model API key registry.
- ADR-0037 (Proposed) — Stripe payment.
- Invariant 8 — secret values never appear in logs, traces, exceptions, or telemetry.
- Invariant 17 — one Key Vault per deployable Node per environment.
- Invariant 22 — diagnostic settings route Key Vault audit to Log Analytics.
- Invariant 47 — durable audit emission via `IAuditLog`.
```

### Operational notes for the executor

The pre-staged commands are the load-bearing content. The executor:
1. Lists every high-sensitivity secret class **currently in use** (model providers, Stripe, Azure subscription, Auth signing keys, any others — verify at edit time by reading Vault's current secret inventory and the operator's existing process docs).
2. Authors the concrete rotation sequence per class — portal URL, exact UI steps, Vault secret name, env scope.
3. Lists the lower-sensitivity SaaS keys (Resend, Twilio, GitHub PATs, any others) with the same concrete sequence.
4. Validates the runbook is operable at 3 AM by reading it cold — every step has the URL, every command has the exact parameter, no "look up X in the docs" footnotes.

The runbook is a **living document** — update it when the Grid adopts a new provider, when a provider's portal UI changes, when a secret class moves between sensitivity tiers. Each update is a small commit.

## Affected Files
- A found-secret rotation runbook in `business/context/` (verified file path at edit time).

## NuGet Dependencies
None. Docs only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. `business/context/` is the established operator-context location.
- [x] No code change in any other repo.
- [x] The runbook operationalizes ADR-0006's rotation mechanics — it does not re-decide them.

## Acceptance Criteria
- [ ] A found-secret rotation runbook exists in `business/context/` (verified path — extend an existing file if a related runbook is there, otherwise create `business/context/found-secret-rotation-runbook.md`)
- [ ] The runbook states the response posture: rotation, not deletion; history rewriting is cosmetic, run after rotation
- [ ] Time-to-rotation targets are explicit: 1-hour for high-sensitivity (model API keys, Stripe production keys, Azure subscription credentials, Auth signing keys); 4-hour for lower-sensitivity (third-party SaaS keys with limited blast radius). Time starts at detection.
- [ ] The universal rotation sequence is listed: rotate at source → update Vault → confirm in use → address git history (cosmetic) → log incident
- [ ] Pre-staged concrete commands are authored per high-sensitivity secret class currently in use — portal URL, exact UI steps, Vault secret name, env scope. **At minimum: model API keys (OpenAI, Anthropic, Azure OpenAI as applicable), Stripe production keys, Azure subscription credentials, Auth signing keys.**
- [ ] Pre-staged commands for lower-sensitivity SaaS keys (Resend, Twilio, GitHub PATs, others) are authored to the same level of concreteness
- [ ] The "what 'lower sensitivity' means" criteria are listed (bounded blast radius; no cross-tenant escalation; no cost-amplification beyond a known cap; default to high-sensitivity when unsure)
- [ ] Git-history rewriting guidance is included: post-rotation only, `git filter-repo` preferred, futile-after-years caveat
- [ ] Cross-references to ADR-0006, ADR-0056 D8, invariants 8/17/22/47

## Human Prerequisites
- [ ] Verify the current high-sensitivity secret inventory at edit time (read Vault's current secret names; cross-reference the operator's existing process docs). The runbook is only as useful as it is current; a missing provider in the pre-staged commands is a 3-AM gap.
- [ ] Re-verify portal URLs and UI steps for each provider at edit time. Provider UIs drift; a runbook from a year ago may have broken links. Re-verify at every quarterly review (per ADR-0056 D5).

## Referenced ADR Decisions
**ADR-0056 D8 — Secret scanning.** GitHub secret scanning + push protection. Found-secret runbook: immediate rotation, not deletion. 1-hour time-to-rotation for high-sensitivity; 4-hour for lower-sensitivity. Time starts at detection, not operator-attention. Pre-staged rotation commands for the high-sensitivity secrets so the operator can execute rather than re-derive at 3 AM.

**ADR-0056 D9 AI-8 — Model API key compromise.** Per-environment keys, usage caps, 90-day rotation cadence (tighter than general 180-day default). Compromise produces cost-amplification (a leaked key can burn through a budget overnight); the asymmetric cost justifies the tighter cadence and the 1-hour found-secret target.

**ADR-0006 D3/D4/D5 — Rotation mechanics.** Tier 1 Azure-native rotation, Tier 2 third-party via rotation Function, certificate auto-renewal. Event-driven cache invalidation. This runbook operationalizes those mechanics for the emergency case.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The runbook itself must not embed real secret values; the pre-staged commands use placeholder values + portal links + Vault secret names.

**Invariant 17 — One Key Vault per deployable Node per environment.** Vault secret name = `kv-hd-{service}-{env}` scoping per ADR-0005.

**Invariant 22 — Diagnostic settings route Key Vault audit to Log Analytics.** Confirming the rotated credential is in use reads from Vault's audit logs.

**Invariant 47 — Audit emission via `IAuditLog`.** Rotation events are recorded automatically; the human-readable incident note exists for the post-mortem, not for the audit substrate.

## Constraints
- **Pre-staged commands are concrete, not generic.** Portal URLs, exact UI steps, Vault secret names. A runbook that says "rotate the Azure key" without naming the portal page fails at 3 AM. The executor authors the concrete sequence per secret class currently in use.
- **Time starts at detection, not at operator-attention.** Detection may happen overnight. The runbook should be operable by a half-asleep operator without multi-step approvals.
- **No real secret values in the runbook.** Per invariant 8. Pre-staged commands use placeholders and Vault secret names; portal links retrieve the new values.
- **Rotation first, history rewriting last.** Reordering these is a recipe for an active leaked credential the operator believes is fixed.
- **Default to high-sensitivity when classifying.** The asymmetric cost favors over-rotation.
- **Re-verify portal URLs at every quarterly review.** Provider UIs drift; runbook freshness is a quarterly-review (D5) checklist item.

## Labels
`feature`, `tier-2`, `meta`, `security`, `docs`, `adr-0056`, `wave-4`

## Agent Handoff

**Objective:** Author the found-secret rotation runbook in `business/context/` with concrete pre-staged commands per secret class, 1-hour / 4-hour time-to-rotation targets, and the "rotation first, history rewriting cosmetic" framing.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the operator a runbook that is operable at 3 AM when GitHub secret scanning (packet 08), a researcher report, or a code-review catch finds a leaked credential.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 4.
- ADRs: ADR-0056 D8 (primary), ADR-0006 (rotation mechanics), ADR-0056 D9 AI-8 (model-key tighter rotation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0056 should be Accepted before its operational runbook lands.

**Constraints:**
- Pre-staged commands are concrete (portal URLs, exact UI steps, Vault secret names) — not generic prose.
- Time starts at detection.
- No real secret values in the runbook (invariant 8).
- Rotation first; history rewriting cosmetic.
- Default to high-sensitivity when unsure.
- Re-verify portal URLs at every quarterly review.

**Key Files:**
- A runbook in `business/context/` — extend existing or create `business/context/found-secret-rotation-runbook.md`.

**Contracts:** None changed.
