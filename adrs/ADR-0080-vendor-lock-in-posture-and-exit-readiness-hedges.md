# ADR-0080: Vendor Lock-In Posture and Exit-Readiness Hedges

**Status:** Accepted
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / Infrastructure / cross-cutting

## Context

Across the last twelve months the Grid has accumulated vendor relationships at every layer: Azure for compute and config and secrets and telemetry and cache and identity ([ADR-0015](./ADR-0015-container-hosting-platform.md), [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md), [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md), [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md), [ADR-0045](./ADR-0045-grid-wide-error-tracking.md), [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md), [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md), [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md)); GitHub for source, CI, project tracking, and PR workflow ([ADR-0008](./ADR-0008-work-tracking-and-execution-flow.md), [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md), [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md)); Cloudflare for DNS and edge ([ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md)); Stripe for payments ([ADR-0037](./ADR-0037-payment-and-billing-integration.md)); Anthropic and OpenAI for AI ([ADR-0041](./ADR-0041-ai-model-registry-and-approval-workflow.md), [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md)); Resend, Twilio, and Expo for Notify default providers ([ADR-0073](./ADR-0073-notify-default-providers.md)).

Each of those ADRs picked the right vendor for its surface. None of them, individually or collectively, stated **the Grid's posture toward vendor lock-in as a chosen position** — what is accepted, what is hedged, what is abstracted, what triggers a re-evaluation, and what the honest exit cost looks like per vendor.

The forcing functions converging now:

- **[ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md) D3, [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) D5, and [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md) D3 each name the same pattern** — Redis-protocol-only, Bicep modules by concern, OIDC-standard claims only — as "the cheap vendor-exit hedge." Three ADRs cite the same pattern; none of them is the umbrella that says *this is the Grid's discipline across all vendor surfaces, not three ad-hoc instances of the same idea*.
- **[Invariant 28](../constitution/invariants.md), [Invariant 29](../constitution/invariants.md), [Invariant 44](../constitution/invariants.md), and [Invariant 45](../constitution/invariants.md)** instantiate the same principle in the AI sector — never hardcode a model, always go through `IModelRouter`, downstream Nodes depend on `Abstractions` only, rates and policies live in App Configuration. The discipline applies more broadly than AI; this ADR generalizes it.
- **The candidate-surface document** ([`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 2.1) names this artifact explicitly and observes that *each vendor ADR cites a future "vendor-exit playbook" without a defined home or shape*. The ADRs are leaving a footnote that points nowhere. This ADR resolves the pointer.
- **The charter's many-decade framing** ([`constitution/charter.md`](../constitution/charter.md) §"What this is" and §"The AI multiplier") makes vendor-posture a load-bearing concern. A studio with a 12-month horizon may treat lock-in as "future-self's problem." A studio with a multi-decade horizon will see at least one of these vendor relationships turn — through pricing, terms, acquisition, deprecation, or simple drift in alignment. The charter explicitly licenses the honest framing:

  > If the bet were wrong — if AI capability plateaued or got gated — the Grid's pace would slow. It wouldn't die.

  That sentence is about the AI bet, but the shape generalizes: **the Grid is built to survive any single vendor going sideways**. Not through portability-by-default (which is a permanent tax), but through chosen lock-in, documented honestly, with hedges where they are cheap and re-evaluation triggers where they are necessary.

- **The charter's "decision points are in, kill clocks are out" framing** ([`constitution/charter.md`](../constitution/charter.md) §"Commercial trials") applies directly: this ADR does not commit any exit, does not budget portability work, and does not set vendor-exit timelines. It names the **triggers** that would cause a deliberate decision conversation. The outcome of that conversation is always "stay," "hedge harder," or "exit" — all three are valid.

This ADR commits the **Grid's vendor posture as a chosen position** — per-vendor posture assignment, the cheap hedges already in place, the decision-point triggers that cause re-evaluation, and the honest exit-cost narrative for each surface. It does **not** enable cheap migration; it makes the lock-in deliberate.

The charter framing makes the framing explicit ([`constitution/charter.md`](../constitution/charter.md) §"How to read other docs in light of this"):

> Architecture-heavy ADRs that look like over-investment for a 12-month startup are correctly-sized for a many-decade platform. The cost-benefit math runs differently here.

This ADR is exactly that — over-investment for a single-product startup, correctly-sized for a workshop that intends to outlast any single vendor's product roadmap.

## Decision

### D1 — Per-vendor posture is one of three: Accept, Hedge, or Abstract

Every vendor relationship in the Grid is assigned **one of three postures**:

- **Accept (deep, intentional)** — lock-in is the chosen position; productivity gain outweighs portability concern; no active hedge work; exit would be a multi-month re-platforming and that is understood and accepted.
- **Hedge (active)** — a small ongoing discipline keeps options open; the discipline is named concretely (a code-level convention, an interface seam, a configuration pattern); the hedge is cheap-by-construction and the exit cost is bounded to weeks per surface.
- **Abstract (already portable)** — the provider seam is real (a Grid-defined interface with multiple compatible implementations); switching is bounded work in days; the abstraction is enforced by canary tests and invariants.

The three-posture model is the **only** posture vocabulary the Grid uses for vendors. "Multi-cloud," "vendor-neutral," "cloud-agnostic," and similar enterprise-shaped framings are explicitly not in the Grid's vocabulary (per D8's rejection of multi-cloud-by-default).

### D2 — Per-vendor posture table

The current assignment across every load-bearing vendor in the Grid:

| Vendor | Surface(s) | Posture | Specific hedges in place | Estimated exit cost |
|---|---|---|---|---|
| **Microsoft Azure** | Container Apps ([ADR-0015](./ADR-0015-container-hosting-platform.md)), Key Vault ([ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md)), App Configuration ([ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md)), App Insights / Azure Monitor ([ADR-0040](./ADR-0040-telemetry-backend-and-retention.md), [ADR-0045](./ADR-0045-grid-wide-error-tracking.md)), Cache for Redis ([ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md)), Bicep ([ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md)), Entra External ID ([ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md)) | **Accept (deep, intentional)** _(per-surface note: the App Insights / Azure Monitor surface specifically carries **Accept with strong hedge** — OTel-first emit per [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) reduces a traces/metrics/logs backend swap to a configuration change, with the error path as the documented carve-out; consistent with the per-surface table in [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md))_ | Standard Redis protocol only ([ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md) D3); OIDC-standard claims only ([ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md) D3); Bicep modules per concern ([ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) D2); OTel-first telemetry emit with App Insights as backend ([ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) post-PR-164); `ISecretStore` / `IConfigProvider` abstractions hide vault and config ([ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md), [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md)) | Multi-month re-platforming if exiting all surfaces; weeks per individual surface |
| **GitHub** | Source, Actions, Projects, PR workflow + Grid review runner ([ADR-0008](./ADR-0008-work-tracking-and-execution-flow.md), [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md), [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md), [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) — the local-worker label/comment queue that supersedes the ADR-0044 OpenClaw webhook transport) | **Accept (deep, intentional)** | None. Full lock-in is the correct posture; GitHub is the substrate for the operator's solo-dev workflow and the SDLC depends on its specific affordances | Months. A full SCM migration would require porting source, PR history, Actions, project board, the ADR-0086 review-runner queue, and the per-Node CI surface. |
| **Cloudflare** | Registrar, authoritative DNS, edge ([ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md)) | **Hedge (active)** | DNSSEC + DNS records are exportable in standard zone-file format; no proprietary edge features (Workers, R2, KV) are depended on in application code; registrar transfer is a defined ICANN process | Days for DNS; weeks if Workers or other Cloudflare-specific edge features were ever adopted |
| **Stripe** | Payments / billing ([ADR-0037](./ADR-0037-payment-and-billing-integration.md)) | **Hedge (active)** | The Billing Node owns the payment-provider abstraction; webhook intake is normalized at the receiver boundary per [ADR-0062](./ADR-0062-inbound-webhook-verification.md); application code does not depend on Stripe-specific webhook semantics | Weeks to swap providers. The harder problem is historical invoice / charge data migration if exiting; the active customer relationships move provider-by-provider on the consumer's next billing cycle. |
| **Anthropic (Claude)** | AI model routing ([ADR-0041](./ADR-0041-ai-model-registry-and-approval-workflow.md)), review agent execution path ([ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md)) | **Abstract (already portable)** | `IModelRouter` per [Invariant 28](../constitution/invariants.md); `HoneyDrunk.AI.Abstractions` per [Invariant 44](../constitution/invariants.md); routing configurable via App Configuration per [Invariant 45](../constitution/invariants.md); the review agent definition lives in `.claude/agents/review.md` and executes under either model family per [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D2 | Days to swap a model; weeks to validate quality at parity across consuming Nodes |
| **OpenAI (Codex)** | AI model routing ([ADR-0041](./ADR-0041-ai-model-registry-and-approval-workflow.md)), review agent execution path ([ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md)) | **Abstract (already portable)** | Same as Anthropic. Review-agent execution is one of two interchangeable paths per [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D2; model selection is operator-configurable per [Invariant 28](../constitution/invariants.md) and [Invariant 45](../constitution/invariants.md) | Days to swap a model; weeks to validate quality |
| **Resend** | Email provider ([ADR-0073](./ADR-0073-notify-default-providers.md)) | **Abstract (already portable)** | Notify provider slot; Postmark and SES are noted runner-ups in [ADR-0073](./ADR-0073-notify-default-providers.md); provider swap is a `HoneyDrunk.Notify.*` package change | Days |
| **Twilio** | SMS provider ([ADR-0073](./ADR-0073-notify-default-providers.md)) | **Hedge (active)** | Notify provider slot; provider role is explicitly "tentative" in [ADR-0073](./ADR-0073-notify-default-providers.md); cost-pressure inflection is the named re-evaluation trigger | Days |
| **Expo** | Mobile push + EAS + Updates ([ADR-0070](./ADR-0070-frontend-platform-stack.md), [ADR-0073](./ADR-0073-notify-default-providers.md)) | **Hedge (active)** | Notify provider slot for push; EAS lock-in is real but bounded by Expo's eject-to-bare-RN documented path | Weeks if fully ejecting from EAS and replacing the build / update pipeline |
| **Discord** | Operator-alerts surface ([ADR-0084](./ADR-0084-discord-operator-alerts-surface.md)) | **Hedge (active)** | Webhook-only integration shape — no bot, no Discord-proprietary feature dependency, no Discord-Modules-equivalent vendor leakage; alert *content* lives in the Grid (inventory files, GitHub Actions logs, incident records); Discord receives a textual *projection* of those sources, never the source of truth; the reusable `job-discord-notify.yml` workflow ([ADR-0084](./ADR-0084-discord-operator-alerts-surface.md) D9) is the single Grid-side seam for GitHub-Actions emitters; the only configuration is per-(channel × emitter-class) webhook URLs in two stores — GitHub org secrets (`DISCORD_WEBHOOK_*`) for Actions, and the `kv-hd-automation-dev` Key Vault (`Discord--{ChannelPascalCase}--RunnerWebhookUrl`) for the ADR-0086 runner (D4) | Days. Swap to Slack / Mattermost / Matrix / Teams (or even an email digest, per the candidate-surface document's preservation-grade fallback) by changing the webhook URL per emitter and the post-formatting in `job-discord-notify.yml` (and the runner's equivalent formatter) |

**Why these postures, not others:** Azure and GitHub are deep enough into the Grid's substrate that pretending they are portable would be dishonest. Cloudflare and Stripe and Twilio and Expo each have real provider seams or open standards that make a hedge cheap. Anthropic, OpenAI, and Resend are already behind first-class Grid abstractions with multiple implementations contemplated by the source ADRs.

**Posture is a per-surface concern, not a per-vendor concern.** Azure is "Accept" across all its current surfaces; if a future Azure-only product (e.g., Azure OpenAI for AI sourcing) were considered, the posture for *that* surface would be evaluated independently. A vendor with multiple Grid surfaces may carry different postures per surface.

**Discord — Why Hedge, not Accept, not Abstract** (per [ADR-0084](./ADR-0084-discord-operator-alerts-surface.md) D7). Not **Accept** because Discord is replaceable — the value is the rich client and the existing operator usage pattern, not any Discord-specific API; naming it Accept would over-state the lock-in. Not **Abstract** because Abstract requires a Grid-defined interface with multiple compatible implementations enforced by canary tests (D1) — an `IChatNotifier` abstraction backed by per-vendor implementations is conceivable but premature at v1 (one operator, one chat product). The Discord-specific re-evaluation triggers to watch (the D4 triggers apply unchanged): a material price change to Discord's currently-free webhook feature (re-evaluate against Slack / Mattermost / Matrix), terms-of-service drift conflicting with the charter's build-in-public stance, and an operator-pattern shift away from Discord (the alerting surface follows the operator's daily flow). See [ADR-0084](./ADR-0084-discord-operator-alerts-surface.md) D7 for the full rationale.

### D3 — Cheap hedges to take immediately (and the discipline that backs them)

Code-level disciplines that apply across **all** vendor surfaces, not just the AI sector or the three ADRs that already cite them. Most are already true at the code level; this ADR restates them as Grid-wide policy:

- **Provider abstractions held at every boundary** per [Invariant 1](../constitution/invariants.md), [Invariant 2](../constitution/invariants.md), [Invariant 3](../constitution/invariants.md), and [Invariant 44](../constitution/invariants.md). Application code consumes Grid-defined interfaces (`ISecretStore`, `IConfigProvider`, `ICacheStore<T>`, `IChatClient`, `IExternalIdpClaimMapper`, etc.); vendor specifics live in `*.Providers.*` packages. This already exists for Vault, Transport, AI, Communications, Audit; this ADR codifies that the discipline applies to **every** vendor surface, present and future.
- **No vendor-proprietary features in application code.** When a vendor offers a proprietary feature that beats the open alternative (Azure Cache for Redis modules, Entra-proprietary claims, Stripe-specific webhook semantics, Cloudflare Workers, Twilio Studio flows, etc.), the proprietary feature is consumed **only at the provider-package layer**, never in application code. The application code stays on the open standard; the provider package may use the proprietary feature internally to implement the standard better.
- **EF Core LINQ kept provider-agnostic.** T-SQL, PostgreSQL, or Cosmos-specific syntax (raw SQL, vendor-specific functions, provider-specific extension methods) is allowed only in dedicated provider packages, never in shared data-access code per [ADR-0072](./ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md). Where Dapper is used for hot-path reads, the SQL string is per-provider by construction; this discipline keeps the Grid honest about which database back-ends each Node supports.
- **Bicep modules by concern** ([ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) D2). Networking, compute, identity, data — each its own module — so any future port (Terraform, Pulumi, or otherwise) has module boundaries to mirror 1:1.
- **OTel-first telemetry emit** ([ADR-0040](./ADR-0040-telemetry-backend-and-retention.md)). Application code emits OpenTelemetry; App Insights is the backend, not the API. A future backend swap (Honeycomb, Grafana Cloud, self-hosted Tempo+Loki+Mimir, etc.) is a configuration change at the OTel exporter level, not a code rewrite at every emitter.
- **Document every "Accept (deep, intentional)" vendor** in a per-vendor file under `governance/vendor-postures/{vendor}.md`. The cost narrative — what is locked in, where the seams are, what the exit cost looks like in concrete steps, which Bicep modules / interface seams / configuration surfaces the migration would touch — survives the ADR. Future operators and future agents (or the present operator after a long absence) can read the per-vendor file and know what was chosen and why.

The discipline is enforced through the standard Grid review mechanisms — invariants are checked by canary tests and architecture review; provider-package vs. application-code boundaries are checked by the Grid-aware review agent per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md); the `.coderabbit.yaml` per [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) Reviewer 2 can carry vendor-leakage rules over time.

### D4 — Decision-point triggers (not kill clocks)

A vendor-posture re-evaluation conversation is triggered when **any** of the following occurs. The trigger does **not** auto-fire a migration; it causes a deliberate decision conversation whose outcome is "stay," "hedge harder," or "exit." All three outcomes are valid.

The triggers:

- **Deprecation or material price increase.** Vendor announces end-of-life for a depended-on capability; vendor raises prices in a way that crosses the cost-governance threshold per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md).
- **Sustained reliability problems.** Defined concretely as **two or more incidents exceeding one hour of impact within a single calendar quarter** on a depended-on surface. The two-incidents-in-a-quarter threshold is the operating definition of "sustained"; a single bad day is not a trigger.
- **Terms change conflicts with charter.** Vendor changes terms of service in a way that conflicts with the charter's build-in-public stance or OSS posture ([ADR-0039](./ADR-0039-grid-open-source-license-policy.md), [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)). Examples: new restrictions on commercial use of free-tier data, mandatory data-residency that conflicts with the Grid's deployment model, license-change patterns matching the Redis 2024 BSL/SSPL shift.
- **Mature alternative emerges.** A clearly better-fit alternative emerges and **matures for twelve or more months** before being considered as a serious replacement candidate. The twelve-month cooling period prevents the chase-the-shiny-new-thing failure mode the charter explicitly warns against ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 1).
- **Adjacent Grid decision changes the math.** An adjacent Grid decision (e.g., adopting multi-region per a future ADR, adopting a substantially different compute model, standing up a Node whose workload no longer fits the current vendor's tier ceiling) materially changes the cost-benefit analysis for the existing vendor relationship.
- **Vendor acquisition / corporate event.** Vendor is acquired, restructures, or changes its strategic direction in a way that the operator judges to be a forward-looking risk to the surface the Grid depends on.

The trigger fires the **conversation**, not the migration. The conversation produces one of three outcomes:

1. **Stay.** The trigger is observed; the assessment is that the current posture is still correct; the trigger is documented in the per-vendor `governance/vendor-postures/{vendor}.md` file as a known concern that was reviewed and held.
2. **Hedge harder.** The trigger is observed; the assessment is that the posture should remain (Accept or Hedge) but with strengthened mitigation; specific new hedges are added; the per-vendor file is updated.
3. **Exit.** The trigger is observed; the assessment is that the cost-benefit has flipped; a follow-up ADR is authored to commit the exit; the migration becomes its own initiative under the standard Grid SDLC.

**Triggers are not promises.** A trigger that fires does not bind the studio to a specific outcome; it binds the studio to a specific conversation. The output of the conversation is the binding commitment, captured in a follow-up ADR if the answer is "exit" or in a per-vendor governance-file update if the answer is "stay" or "hedge harder."

### D5 — Per-vendor exit-playbook stubs for Accept-posture vendors

For the two "Accept (deep, intentional)" vendors — Azure and GitHub — this ADR creates **placeholder per-vendor governance files** under a new `governance/vendor-postures/` directory:

- **`governance/vendor-postures/azure.md`** — Azure exit-playbook stub. Documents the lock-in honestly: every Azure surface the Grid depends on, the exit cost per surface, the cheap hedges already in place per [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md) D3, [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) D5, [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md) D3, [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) (OTel-first), and [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) (`ISecretStore` / `IConfigProvider`). The file is a stub at this ADR's acceptance; the full content lives in a follow-up packet.
- **`governance/vendor-postures/github.md`** — GitHub exit-playbook stub. Documents that lock-in is full and intentional; names the surfaces (source, Actions, Projects, OpenClaw, per-repo CI) and the migration cost; explicitly notes that the SCM-migration pre-condition is *another SCM with equivalent affordances for solo-dev + AI-agent SDLC* — not "GitLab can host the source," but the full workflow story.

For **"Hedge (active)"** and **"Abstract (already portable)"** vendors, no separate file is required at this ADR's acceptance. The source ADR is the document of record; the hedge is named in the source ADR; the per-vendor governance file becomes useful only when the surface area grows enough to justify it. The bar for promoting a Hedge or Abstract vendor to a per-vendor governance file is "the source ADR's cited hedge is no longer the only relevant context" — a judgment call held until the moment it is needed.

The `governance/vendor-postures/` directory is the **canonical home** for per-vendor posture documentation. Future ADRs that name new vendor relationships cite this directory as the place where Accept-posture documentation lives.

### D6 — What this ADR does NOT do

Explicit non-commitments, because vendor-posture ADRs at every other studio have a tendency to drift into commitments they were not authored to make:

- **This ADR does not commit to any exit.** No vendor named here is on a path away from the Grid. The triggers in D4 may surface; their outcomes may include exit; the exit itself would be a follow-up ADR.
- **This ADR does not budget engineering time for portability work.** The hedges in D3 are cheap-by-construction (most are already in place per the source ADRs); no separate "portability sprint" is implied or scheduled.
- **This ADR does not require multi-cloud-by-default for new code.** New code targets the chosen vendor for its surface. The hedges keep the future-state migration tractable; they do not make today's code multi-cloud.
- **This ADR does not override the workshop framing.** The charter is the tiebreaker. If a future ADR proposes a portability investment that this ADR's hedges do not already pre-pay, that ADR has to justify itself against the charter on its own terms, not against this ADR's framing alone.

### D7 — Cross-reference to AI-sector invariants

The discipline this ADR commits is already instantiated in the AI sector through [Invariant 28](../constitution/invariants.md), [Invariant 29](../constitution/invariants.md), [Invariant 44](../constitution/invariants.md), and [Invariant 45](../constitution/invariants.md). This ADR **generalizes that discipline to all vendors** — what the AI sector did for Anthropic and OpenAI through `IModelRouter` and `HoneyDrunk.AI.Abstractions`, the rest of the Grid does for Azure, Cloudflare, Stripe, Resend, Twilio, and Expo through the abstractions and hedges in D3.

The AI-sector invariants are the **proof of concept** that the discipline works. The Grid already runs against `IModelRouter`-and-App-Configuration for model selection; the same pattern applied across every vendor surface is what makes the "Abstract" posture (D2) honest and what keeps the "Hedge" posture cheap.

### D8 — Out of scope

The following are explicitly **not** decided by this ADR:

- **Multi-cloud-by-default.** Considered and rejected in Alternatives Considered. The charter does not license a permanent portability tax in service of hypothetical migrations.
- **Per-vendor SLA negotiation.** Vendor-by-vendor SLA commitments live with the source ADRs for each surface ([ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md) for DR; [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) for incident response). This ADR does not re-decide them.
- **Vendor-cost optimization.** Owned by [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md). This ADR's "material price increase" trigger (D4) hands off to that ADR's governance discipline.
- **Per-vendor security review.** Owned by [ADR-0056](./ADR-0056-threat-model-and-security-review-cadence.md). Vendor security posture is a security-review concern; this ADR is the lock-in-posture concern.
- **The full content of the per-vendor governance files (D5).** The stubs are created with this ADR; the full content is a follow-up packet. The stub commits the structure and the canonical home; the body is filled in incrementally.
- **Hedges for future vendor surfaces.** When a future ADR names a new vendor, that ADR is responsible for naming its own posture (Accept / Hedge / Abstract) and the hedges in place. This ADR's table (D2) is updated by amendment when new vendor surfaces are introduced.

## Consequences

### Affected Nodes

- **HoneyDrunk.Architecture** — primary affected Node. Creates the new `governance/vendor-postures/` directory; ships the two stub files per D5 in the follow-up packet.
- **No application-code Node** is directly affected by this ADR. The hedges in D3 are already in place at the code level via the source ADRs and the existing invariants ([Invariant 1](../constitution/invariants.md), [Invariant 2](../constitution/invariants.md), [Invariant 3](../constitution/invariants.md), [Invariant 28](../constitution/invariants.md), [Invariant 29](../constitution/invariants.md), [Invariant 44](../constitution/invariants.md), [Invariant 45](../constitution/invariants.md)).
- **[ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md), [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md), [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md)** — the three ADRs whose "cheap vendor-exit hedge" language now points at this ADR's `governance/vendor-postures/azure.md` per D5. No amendments required; the cross-reference is by-convention.
- **Future vendor-introducing ADRs** — any future ADR that names a new vendor surface cites this ADR for the posture vocabulary (Accept / Hedge / Abstract) and is responsible for placing the new vendor on the D2 table by amendment.

### Invariants

This ADR proposes (numbering finalized at acceptance):

- **Every vendor surface in the Grid carries one of the three postures from D1.** Posture is documented in this ADR's table (D2) or, for new vendors introduced after this ADR's acceptance, in the source ADR that adopts the vendor.
- **No vendor-proprietary feature is consumed in application code.** Proprietary features are allowed only at the `*.Providers.*` package layer; application code consumes Grid-defined interfaces and standard protocols. (Generalizes [Invariant 1](../constitution/invariants.md), [Invariant 2](../constitution/invariants.md), [Invariant 3](../constitution/invariants.md), [Invariant 44](../constitution/invariants.md) across all vendor surfaces; codifies D3.)
- **"Accept (deep, intentional)" posture vendors have a per-vendor governance file under `governance/vendor-postures/{vendor}.md`.** (Codifies D5.)

### Operational Consequences

- **Vendor lock-in becomes a chosen position, not an accidental drift.** The Grid's posture per vendor is named, documented, and reviewable. Future ADRs that adopt new vendors must place them on the D2 table; the omission would be flagged at PR review.
- **The "cheap vendor-exit hedge" language across [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md), [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md), [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md) now points at a real artifact.** The three ADRs each cited a future "vendor-exit playbook"; D5 gives the playbook a home and a structure.
- **Decision-point triggers replace kill clocks.** Per the charter's "decision points are in, kill clocks are out" framing — the triggers in D4 cause conversations, not migrations. The Grid does not commit to leaving any vendor; it commits to noticing when leaving would deserve a conversation.
- **The per-vendor exit cost is honestly known.** D2's "Estimated exit cost" column is the honest answer to "what does leaving this vendor look like?" The answer ranges from days (most Abstract-posture vendors) to multi-month re-platforming (Azure across all surfaces; GitHub). Honest cost-knowledge prevents both over-investment in portability and under-estimation of exit pain.
- **The discipline generalizes beyond AI.** [Invariant 28](../constitution/invariants.md) / [Invariant 29](../constitution/invariants.md) / [Invariant 44](../constitution/invariants.md) / [Invariant 45](../constitution/invariants.md) instantiated the pattern for AI; D3 restates that the same discipline applies to every vendor. Future Grid code is written with the discipline already in mind; no separate "portability sprint" is needed because portability is cheap-by-construction.
- **No today-cost on any active workstream.** All hedges in D3 are already true at the code level via the existing invariants and source ADRs. This ADR adds the **posture** layer above the code-level discipline; no code changes are implied by acceptance.
- **The charter's many-decade horizon is structurally served.** The Grid is now positioned to survive at least one vendor going sideways without needing a panic-mode re-platforming sprint. The hedges pre-pay the migration cost; the triggers ensure the situation is noticed; the per-vendor governance files capture the operator-memory needed for the eventual conversation.

### Follow-up Work

- Create the `governance/vendor-postures/` directory.
- Ship stub `governance/vendor-postures/azure.md` per D5 (one follow-up packet).
- Ship stub `governance/vendor-postures/github.md` per D5 (same or sibling packet).
- Update [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md), [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md), and [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md) follow-up notes to cite `governance/vendor-postures/azure.md` as the home for the future-state "vendor-exit playbook" they reference (citation-only; no decision change).
- When the next vendor-introducing ADR is authored, place the new vendor on the D2 table by amendment to this ADR (or, if the cumulative amendments grow large enough, supersede with a refreshed posture table).
- Watch list: the [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) reviewer stack carries a "vendor-leakage rule" for the Grid-aware reviewer as the discipline matures; the rule is added to `.claude/agents/review.md` when a real vendor-leakage anti-pattern is observed at PR time.
- Quarterly self-review (informal): does any vendor on the D2 table warrant a posture change based on D4 triggers? The review is a self-check, not a process gate; the outcome is either "no change" or a follow-up ADR.

## Alternatives Considered

### Multi-cloud by default

Considered. The argument: hedge the Azure lock-in by maintaining a second-cloud-ready posture in all new code — every Azure-specific API behind an abstraction with an AWS / GCP implementation present from day one.

Rejected. The charter explicitly licenses the workshop framing over the enterprise framing ([`constitution/charter.md`](../constitution/charter.md) §"What this is not"); multi-cloud-by-default is a permanent tax (every new feature must work across providers, every test suite must run against multiple back-ends, every Bicep module needs a Terraform sibling) in service of a hypothetical migration that may never happen. The cost-benefit math for a solo-dev workshop runs the opposite direction from a multi-region enterprise — productivity from a deep, well-understood single-vendor stack outweighs the optionality of a never-exercised second-vendor capability. The hedges in D3 are the **bounded** form of the same instinct.

### Pure abstraction discipline (vendor-agnostic everywhere)

Considered. The argument: the Grid already enforces vendor-agnostic interfaces ([Invariant 1](../constitution/invariants.md), [Invariant 2](../constitution/invariants.md), [Invariant 3](../constitution/invariants.md), [Invariant 44](../constitution/invariants.md)); no additional posture layer is needed; the abstractions *are* the vendor-exit posture.

Rejected. The abstractions are the **code-level** vendor-exit posture; this ADR adds the **document-level** posture above it. The two layers serve different purposes: abstractions keep code portable in principle; the posture document keeps the operator (and future agents and future operators) honest about which vendors are accepted-deep, which are actively hedged, and which are genuinely portable in practice. Without the posture layer, "the abstractions exist" can be misread as "we are vendor-portable," when in fact the operational lock-in is real even when the code-level lock-in is not (managed identity, billing relationships, data residency, learned operational patterns, etc.). The posture document captures what the abstractions alone cannot.

### No vendor posture documentation

Considered. The argument: the source ADRs name their vendors; the invariants enforce the abstractions; no umbrella document is needed; this ADR is redundant ceremony.

Rejected. Undocumented lock-in is **accidental lock-in**. Three separate ADRs ([ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md), [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md), [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md)) each cite the same "cheap vendor-exit hedge" pattern; none of them is the umbrella that says the pattern is **Grid-wide**, not three coincidences. The charter explicitly licenses honest assessment ([`constitution/charter.md`](../constitution/charter.md) §"Build-in-public, honestly"); naming the lock-in as a chosen position is the build-in-public-shaped move. Skipping this ADR leaves the footnotes pointing nowhere and the posture undocumented.

### Per-vendor ADRs (one ADR per vendor instead of one umbrella ADR)

Considered. The argument: each vendor's exit cost, hedges, and triggers are different; one umbrella ADR is forced to summarize what a per-vendor ADR could detail; let each vendor have its own ADR.

Rejected on scope grounds. The "Abstract" posture vendors (Anthropic, OpenAI, Resend) do not warrant a full ADR — the source ADR already describes the abstraction and the swap cost is bounded by the abstraction itself. The "Hedge" posture vendors (Cloudflare, Stripe, Twilio, Expo) similarly do not warrant a full ADR — the hedge is named in the source ADR; the per-vendor governance file (D5) handles the cases where more depth is justified. Only the "Accept (deep, intentional)" vendors (Azure, GitHub) warrant per-vendor documentation, and D5's per-vendor governance files give them that without the overhead of full ADRs. The umbrella-ADR-plus-per-vendor-governance-files shape is the right scope.

### Defer this ADR until a vendor surface actually becomes hostile

Considered. The argument: write the playbook when the conversation is real; pre-emptive vendor-posture documentation is YAGNI.

Rejected per the charter's many-decade horizon framing. The hedges in D3 are cheap **only because** they are pre-paid (the discipline is established before the lock-in compounds). Writing the posture document when a vendor turns hostile means the operator is doing posture-design under stress, with biases skewed by the hostile event, and with the cost-of-not-having-hedges already accrued. The cluster-2.1 candidate doc names this trade-off directly: *"Write while leverage is still cheap (before lock-in compounds)."* The pre-emptive document is the small-cost-now move that buys the future conversation.

### Adopt a portability tax (e.g., "every Azure-specific feature requires a multi-cloud feasibility note")

Considered. The argument: enforce the discipline through a process gate; every PR touching an Azure-specific surface has to argue why it is acceptable.

Rejected. The discipline is already enforced at the structural level by the invariants and the abstraction boundaries; a per-PR process gate is bureaucratic overhead the workshop framing does not warrant ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 3 — performing visibility instead of building). The Grid-aware review agent ([ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)) is the right enforcement point if and when a vendor-leakage anti-pattern is observed; until then, the abstractions and invariants are sufficient.

### Use a vendor-rating framework (red/yellow/green per vendor, scored on multiple dimensions)

Considered. Many enterprise architecture practices use multi-dimensional vendor scorecards (financial health, technical alignment, support quality, lock-in depth, etc.) with quarterly re-scoring.

Rejected. The three-posture model (Accept / Hedge / Abstract) is the smallest vocabulary that captures the operator-meaningful distinction. A multi-dimensional scorecard would imply quarterly re-scoring ceremony that the workshop framing does not warrant. The decision-point triggers (D4) are the trigger-based equivalent: posture re-evaluation happens when something changes, not on a calendar.

## References

- [`constitution/charter.md`](../constitution/charter.md) — many-decade horizon, decision-points-not-kill-clocks, workshop-not-startup framing, build-in-public-honestly stance
- [`constitution/invariants.md`](../constitution/invariants.md) — invariants 1-3 (abstractions/runtime/provider split), invariant 28 (no hardcoded model), invariant 29 (Vault-resolved connector credentials), invariant 44 (downstream depends on Abstractions only), invariant 45 (rates and policies in App Configuration)
- [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — Key Vault + App Configuration (Azure deep)
- [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) — secrets rotation (Azure deep)
- [ADR-0008](./ADR-0008-work-tracking-and-execution-flow.md) — GitHub Projects (GitHub deep)
- [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md) — GitHub Projects / The Hive (GitHub deep)
- [ADR-0015](./ADR-0015-container-hosting-platform.md) — Azure Container Apps (Azure deep)
- [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md) — Cloudflare DNS + edge (Hedge)
- [ADR-0037](./ADR-0037-payment-and-billing-integration.md) — Stripe (Hedge)
- [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) — Azure Monitor / App Insights, OTel-first emit (Azure deep with hedge)
- [ADR-0041](./ADR-0041-ai-model-registry-and-approval-workflow.md) — AI model registry (Anthropic + OpenAI, Abstract)
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — Grid-aware review agent (GitHub + OpenClaw, GitHub deep)
- [ADR-0045](./ADR-0045-grid-wide-error-tracking.md) — Azure App Insights (Azure deep)
- [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) — cost governance (price-increase trigger handoff)
- [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) — incident response (reliability-trigger handoff)
- [ADR-0056](./ADR-0056-threat-model-and-security-review-cadence.md) — security review (security-posture handoff)
- [ADR-0062](./ADR-0062-inbound-webhook-verification.md) — normalized webhook intake (Stripe hedge)
- [ADR-0070](./ADR-0070-frontend-platform-stack.md) — React Native + Expo (Expo hedge)
- [ADR-0072](./ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md) — EF Core LINQ provider-agnostic (data-layer hedge)
- [ADR-0073](./ADR-0073-notify-default-providers.md) — Resend / Twilio / Expo (provider-slot postures)
- [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md) — Azure Cache for Redis, Redis-protocol-only (Azure deep + hedge in D3)
- [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) — Bicep, per-concern modules (Azure deep + hedge in D2 / D5)
- [ADR-0078](./ADR-0078-end-user-identity-entra-external-id.md) — Entra External ID, OIDC-standard claims only (Azure deep + hedge in D3)
- [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) — review stack (Anthropic + OpenAI, Abstract; GitHub deep)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 2.1 — the candidate-surfacing entry that named this ADR
