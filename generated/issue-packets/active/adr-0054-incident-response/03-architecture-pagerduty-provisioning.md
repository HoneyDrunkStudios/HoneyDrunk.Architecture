---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0054", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0054", "ADR-0052", "ADR-0005"]
accepts: ["ADR-0054"]
wave: 1
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Provision PagerDuty Starter — account, escalation policy, and integrations

## Summary
Provision the **PagerDuty Starter** account that serves as the secondary paging path per ADR-0054 D3, configure the one-user escalation policy with the operator's phone number as the SMS + phone-call target, create the source integrations the D4 routing table calls (Azure Monitor → PagerDuty, Stripe → PagerDuty, generic webhook → PagerDuty), and store the PagerDuty integration secrets / API key in the appropriate Key Vault. Author a walkthrough doc covering all steps so re-provisioning (e.g. environment refresh or vendor swap) is documented.

## Context
ADR-0054 D3 names PagerDuty Starter (~$21–25/month at 2026 pricing) as the secondary paging path — the redundant SMS + phone-call surface that survives a Notify-itself-down scenario. The primary path is Notify (packet 04); the two together provide the redundancy the ADR demands. D3 also names PagerDuty as **the source of truth for acknowledgment** (it has a true ack-button surface) — Notify-pushed alerts include a deep-link to the PagerDuty incident for ack.

ADR-0054's Follow-up Work names the discrete portal steps:

- "Implement the PagerDuty integration: account creation, escalation policy, webhook configuration."
- "Wire App Insights alerts (ADR-0040) to PagerDuty per the D4 routing table." (Packet 09 — alert wiring, depends on this packet.)
- "Wire `IErrorReporter` captures (ADR-0045), Azure Monitor budget alerts (ADR-0052), canary failure alerts (ADR-0012) to PagerDuty per the D4 routing table." (Packet 09.)

This packet is the **substrate provisioning** — packet 09 is the per-source wiring that consumes the integrations this packet creates.

Per the operator's standing preference, infra provisioning uses the vendor's portal UI, not CLI / API / Terraform — so this packet delivers a portal walkthrough. The walkthrough doc lives in `infrastructure/walkthroughs/pagerduty-provisioning.md`.

**Cost.** PagerDuty Starter is ~$21–25/month for one user (2026 list pricing — confirm the exact tier name and price at execution time; the vendor renames tiers periodically). The cost is named in ADR-0052's cost-discipline envelope as an **exempt category** — paging tooling itself doesn't fire its own budget alert (it would be self-referential).

**Free tier rejected.** ADR-0054 D3 explicitly rejects PagerDuty's free tier for SEV-1 use because the free tier lacks SMS reliability guarantees and phone-call escalation. Pick Starter (the lowest paid tier).

**Vault placement.** Per invariant 17 (one Key Vault per deployable Node per environment) there is **no shared Vault** — `kv-hd-shared-{env}` does not exist. The PagerDuty integration secrets are stored in the Vault of the Node that consumes them:

- The **PagerDuty Events API v2 key** is consumed by the Pulse synthetic probe (packet 06). It lives in `kv-hd-pulse-{env}`. Pulse is a Seed Node per the catalog; if `kv-hd-pulse-{env}` does not yet exist, this packet's walkthrough provisions it as an explicit prerequisite (see Human Prerequisites) — there is no "operator-internal Vault" or "shared Vault" fallback.
- The **PagerDuty Azure Monitor integration URL** is consumed by Azure Monitor action groups (packet 09 wires them); it lives in `kv-hd-notify-{env}` for the cross-deep-link Notify renders in paging payloads, since the URL also flows through the Notify-delivery payload. Notify is LIVE and already has `kv-hd-notify-{env}` provisioned.
- The **Stripe integration key** (if a separate first-party PagerDuty integration is used) is consumed by the Node that emits the Stripe webhook failure capture. If that Node is Notify-adjacent, it lives in that Node's Vault; otherwise it lives in `kv-hd-notify-{env}` alongside the Azure Monitor URL.

Record the chosen path per secret in the walkthrough.

**Provision-when-needed.** ADR-0054 D2's coverage window starts when the paging substrate is live. This packet provisions the PagerDuty account once, in the operator's PagerDuty account (a vendor account, not per-environment). The integration secrets are stored per-environment in Vault. Packet 09 wires the per-source alerts in `dev` (which exists per ADR-0033) and re-uses the walkthrough for `staging`/`prod` when they stand up.

This is an infrastructure walkthrough + provisioning packet. No code, no .NET project. **Actor=Human** — the steps are portal clicks the agent cannot perform (account signup, payment authorization, escalation policy clicks, phone-number entry).

## Scope
- `infrastructure/walkthroughs/pagerduty-provisioning.md` (new) — the PagerDuty portal walkthrough.
- The PagerDuty account itself — created via signup at pagerduty.com (a vendor surface, not a repo artifact).
- The Key Vault secrets for the PagerDuty integration URLs / API key — stored in the recommended Vault, path documented in the walkthrough.
- A note in `catalogs/grid-health.json` or the equivalent recording that the PagerDuty integration is `provisioned` in `dev` (or whichever environment the secret lands in).

## Proposed Work (human-executed, vendor portal + Azure Portal)
The walkthrough authors and the operator executes:

1. **PagerDuty account signup.**
   - Visit pagerduty.com → sign up for the **Starter** plan (confirm the current tier name and price; the free trial is acceptable for initial setup but the paid plan must be activated before SEV-1 reliance because the free tier lacks SMS guarantees per D3).
   - Add one user (the operator).
   - Set the operator's email, phone number (for SMS), and a second phone number (for phone-call escalation if the first phone goes silent). The phone number is **personal mobile** — never a shared studio number.
   - Configure the user's notification rules: SMS and phone call immediately for any incident.
2. **Escalation policy.**
   - Create a single escalation policy: "HoneyDrunk Studios Operator." One level: the operator. No secondary. The escalation policy has no timeout target — `null` after the operator per D3 ("escalation paths terminate at the single operator").
   - Per D12 (forward-looking) — when a second human is hired this escalation policy is amended to add a secondary level; not now.
3. **Service definitions.**
   - Create one PagerDuty **service** per signal source family the D4 routing table calls (alternatively, a single "HoneyDrunk Grid Production" service with integrations per source — match what's cleanest in the PagerDuty UI; one service is simpler at this scale). Recommended at this scale: one service.
   - Bind the service to the operator escalation policy.
4. **Integrations.**
   - Add the **Azure Monitor** integration to the service (PagerDuty has a first-party Azure Monitor integration). Note the integration URL; this is what Azure action groups call.
   - Add a **generic webhook (Events API v2)** integration for the sources that aren't first-party (Stripe via its own webhook, custom Notify alerts, canary failures). Note the integration key.
   - Add the **Stripe** integration if PagerDuty offers a first-party one; otherwise route Stripe via the generic Events API v2 endpoint.
5. **Store secrets in Vault.**
   - Per invariant 17 (one Vault per deployable Node per environment) there is no shared Vault. Store each integration credential in the Vault of the Node that consumes it:
     - `pagerduty-events-api-key` → `kv-hd-pulse-{env}` (consumed by Pulse synthetic probe in packet 06). If `kv-hd-pulse-{env}` does not yet exist (Pulse is a Seed Node), provision it first per the ADR-0005 Vault-creation walkthrough — this is an explicit prerequisite, not a fallback to a shared Vault.
     - `pagerduty-azure-monitor-integration-url` → `kv-hd-notify-{env}` (consumed by Notify for the cross-deep-link in paging payloads; Notify is LIVE and already has its Vault). Azure Monitor action groups read it from this Vault.
     - `pagerduty-stripe-integration-key` → `kv-hd-notify-{env}` (same Vault as the Azure Monitor URL).
   - Per invariant 9 (Vault is the only source of secrets), never paste the key into a config file or workflow.
6. **Synthetic-probe credential.**
   - The Pulse synthetic probe (packet 06) needs to send a fake SEV-3 to PagerDuty every 5 minutes. The probe authenticates via the Events API v2 key stored at `pagerduty-events-api-key` in `kv-hd-pulse-{env}`. Confirm Pulse's managed identity has Get permission on the secret. If `kv-hd-pulse-{env}` did not exist before this packet, the walkthrough's prerequisite step (Vault creation) covers it.
7. **Verify.**
   - From the PagerDuty UI, trigger a test incident. Confirm SMS and phone call arrive on the operator's phone within 30 seconds (D3's latency target).
   - Acknowledge the test incident from the phone; confirm the ack is reflected in the PagerDuty UI.
   - Resolve the test incident; confirm the auto-resolve flow.
8. **Update catalog readout.**
   - Flip the PagerDuty integration entry in `catalogs/grid-health.json` (or the appropriate per-vendor catalog file added at edit time — match existing convention) to `provisioned` for `dev`.
   - Record the chosen Vault paths in the walkthrough doc.
9. **Cost guard.**
   - Note the recurring monthly cost (~$21–25/month) in `business/context/` alongside the ADR-0052 cost-ceiling tracking. Mark PagerDuty as an **exempt** category — it does not fire its own budget alert.

## Affected Files
- `infrastructure/walkthroughs/pagerduty-provisioning.md` (new)
- `catalogs/grid-health.json` (or the equivalent catalog file at edit time) — PagerDuty integration entry flipped to `provisioned`.
- `business/context/` — PagerDuty cost entry (annotation, not a new note).
- The PagerDuty account and its integrations (a vendor surface, not repo artifacts).
- The Key Vault secrets `pagerduty-events-api-key`, `pagerduty-azure-monitor-integration-url`, `pagerduty-stripe-integration-key` (Azure resources, not repo artifacts).

## NuGet Dependencies
None. This packet has no .NET project.

## Boundary Check
- [x] The walkthrough doc lives in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs per the existing `infrastructure/walkthroughs/` convention.
- [x] No code change in any repo.
- [x] The PagerDuty account and Azure secrets land in vendor / Azure subscriptions, not in repo.
- [x] The recommended Vault is consistent with ADR-0005 (one Vault per deployable Node per environment); the integration secrets are stored where the Node that consumes them (Pulse for the probe; Notify for the cross-deep-link) reads from.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/pagerduty-provisioning.md` exists and documents: signup at pagerduty.com Starter plan; one-user account with personal mobile + secondary phone; the "HoneyDrunk Studios Operator" escalation policy with one level (the operator) and no secondary; one service bound to the policy; the Azure Monitor integration, the generic Events API v2 integration, and the Stripe integration (or generic-Events fallback); the recommended Vault path for each integration secret; the verify-with-test-incident step; the catalog flip and the cost note
- [ ] The PagerDuty account is **provisioned** on the Starter plan; the operator has SMS + phone-call notification rules; a test incident has been triggered, acked from the phone, and resolved
- [ ] The integration secrets are stored per the per-Node Vault rule (invariant 17): `pagerduty-events-api-key` in `kv-hd-pulse-{env}`, `pagerduty-azure-monitor-integration-url` and `pagerduty-stripe-integration-key` in `kv-hd-notify-{env}`. No "shared" Vault is created.
- [ ] `catalogs/grid-health.json` (or the equivalent catalog file) reflects PagerDuty as `provisioned` for `dev`
- [ ] `business/context/` carries the PagerDuty recurring-cost note (~$21–25/month) annotated as ADR-0052 cost-exempt
- [ ] The walkthrough notes the D12 future-state — when a second human is hired the escalation policy gains a secondary level

## Human Prerequisites
- [ ] **Sign up for PagerDuty at pagerduty.com on the Starter plan** — payment authorization required (recurring ~$21–25/month).
- [ ] **Operator's personal mobile phone number** — used as the SMS + phone-call target. Confirm carrier delivers SMS reliably.
- [ ] **Azure subscription access** to store integration secrets in the per-Node Key Vaults — the secrets cannot be created without portal/CLI access. The agent does not have this access.
- [ ] **Provision `kv-hd-pulse-{env}` first if it does not exist.** Per invariant 17 there is no shared Vault; the Events API v2 key has nowhere else to land. Follow the ADR-0005 Vault-creation walkthrough before storing the secret. (`kv-hd-notify-{env}` already exists — Notify is LIVE.)
- [ ] **Trigger the test incident from the PagerDuty UI** to confirm end-to-end delivery; the agent cannot click "Trigger test" in a vendor UI.

## Referenced ADR Decisions
**ADR-0054 D3 — Paging mechanism.** Push-to-phone via two redundant paths. PagerDuty Starter (~$21/user/month) is the secondary path. Both paths fire for SEV-1/2; SEV-3 fires Notify only (no PagerDuty cost burn for non-paging-worthy events); SEV-4 fires neither. PagerDuty is the source of truth for acknowledgment because it has a true ack-button surface. Latency target < 30 seconds from alert fire to phone receipt. OpsGenie was considered and rejected on continuity (PagerDuty has the larger ecosystem of integrations with Azure Monitor, GitHub, Stripe webhooks).

**ADR-0054 D12 — On-call hand-off (forward-looking).** Current state: one human operator. The escalation policy has one level (the operator), no secondary. When the trigger fires (second person with prod credentials + signed on-call contract + PagerDuty onboarding), the escalation policy is amended.

**ADR-0052 — Cost discipline.** PagerDuty Starter is named as an **exempt category** in the cost-discipline envelope — paging tooling itself doesn't fire its own budget alert.

**ADR-0005 — One Key Vault per deployable Node per environment.** Per invariant 17 there is no shared Vault. Integration secrets are stored in the Vault of the Node that consumes them: `kv-hd-pulse-{env}` for the Events API v2 key (Pulse synthetic probe); `kv-hd-notify-{env}` for the Azure Monitor integration URL (Notify cross-deep-link rendering, Azure Monitor action group reads).

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** The PagerDuty Events API key, Azure Monitor integration URL, and Stripe integration key are stored in Vault per invariant 9; never pasted into config files, workflow YAML, or commit history.

> **Invariant 9 — Vault is the only source of secrets.** PagerDuty integration secrets are read via `ISecretStore` at runtime; never via environment variables or hardcoded constants.

> **Invariant 17 — One Key Vault per deployable Node per environment.** There is **no shared Vault** (no `kv-hd-shared-{env}`). The Events API v2 key lives in `kv-hd-pulse-{env}` (consumed by Pulse); the Azure Monitor integration URL and Stripe integration key live in `kv-hd-notify-{env}` (consumed by Notify and Azure Monitor action groups). If `kv-hd-pulse-{env}` does not yet exist it is provisioned as a prerequisite — never deferred to a "shared" Vault.

- **Starter, not Free.** PagerDuty's free tier lacks SMS reliability for SEV-1 (D3). Provision the paid Starter plan.
- **One-level escalation now.** The escalation policy has one level (the operator) and no secondary. D12's amendment fires when a second human is hired — not now.
- **Personal mobile.** The SMS / phone-call target is the operator's personal mobile, not a shared studio number. The operator carries this phone outside coverage hours.
- **Vault-stored secrets only.** All PagerDuty integration credentials live in the recommended Key Vault. No `.env` file, no `appsettings.json` entry, no committed workflow value.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0054`, `wave-1`

## Agent Handoff

**Objective:** Provision PagerDuty Starter, configure the one-operator escalation policy, create the Azure Monitor / Stripe / generic-webhook integrations, store the integration secrets in the recommended Key Vault, and document the steps in an infrastructure walkthrough.

**Target:** `HoneyDrunk.Architecture`, branch from `main` for the walkthrough doc; the PagerDuty account and Azure secrets land outside the repo.

**Context:**
- Goal: Stand up the secondary paging path so packet 04 (Notify primary path) and packet 06 (Pulse synthetic probe) can verify end-to-end paging, and so packet 09 can wire alert sources to PagerDuty.
- Feature: ADR-0054 Incident Response rollout, Wave 1.
- ADRs: ADR-0054 D3 (primary), ADR-0054 D12 (forward-looking — one level only now), ADR-0052 (cost-exempt category), ADR-0005 (Vault placement).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0054 should be Accepted before its paging infrastructure stands up.

**Constraints:**
- Starter plan, not Free.
- One-level escalation policy now; D12 amendment when a second human is hired.
- Personal mobile, not shared.
- Vault-stored secrets only (invariants 8, 9, 17).

**Key Files:**
- `infrastructure/walkthroughs/pagerduty-provisioning.md` (new)
- `catalogs/grid-health.json` (or equivalent)
- `business/context/` (PagerDuty cost annotation)

**Contracts:** None changed. The PagerDuty integration URLs / keys become available secrets consumed by packets 06 and 09.
