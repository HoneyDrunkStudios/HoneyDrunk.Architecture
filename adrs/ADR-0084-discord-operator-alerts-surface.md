# ADR-0084: Discord as the Canonical Operator-Alerts Surface

**Status:** Accepted
**Date:** 2026-05-25
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / Meta / cross-cutting

## Context

HoneyDrunk Studios has an existing Discord server, but it has never been pinned as the canonical operator-alerts surface for the Grid. Today, operational signal lands in four scattered places:

- **GitHub issue notifications**, which compete with a backlog north of 350 issues — label-filtered issues still get lost in volume.
- **Email from GitHub Actions** (per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) D7 — "Only notify for failed workflows"), which is real-time per-failure but lands in the same inbox as every other product email.
- **Manual checks** of Actions tabs, the `🕸️ Grid Health` aggregator issue, and SaaS-provider dashboards.
- **The operator's GitHub profile notifications**, which are useful but provide no taxonomy, no shared timeline, and no place where security/agent/release/CI events sit side-by-side for human pattern-matching.

There is no single place that is *"the operator pager."*

The forcing function is [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) (External-SaaS Credential Inventory and Rotation Procedure, drafted today). [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D3 originally picked "GitHub issues with the `external-credential-rotation` label" as the rotation-tracking surface — and that choice survives in [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) as the canonical *tracking* surface (because closed issues are an audit trail and AI agents can walk them). But [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D5's escalation cadence (T-30 / T-7 / T+0) explicitly needs a higher-saliency channel than "another label-filtered issue in a 350-issue backlog." The operator named chat-webhook (Discord specifically) as the right alerting surface during ADR-0083 drafting — but Discord's structure across the Grid had not been decided. This ADR closes that gap and unblocks [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D3's final shape.

There is also a converging set of Grid signal sources that have grown past the "GitHub email" surface in the last six months and have no defined alerting destination:

- The [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) Grid Review pipeline posts PR comments, but agent-activity has no rolling timeline the operator can scan.
- The [ADR-0046](./ADR-0046-specialist-review-agents.md) specialist agents are similarly comment-bound today.
- [ADR-0032](./ADR-0032-pr-validation-policy-coverage-gate-and-nuget-flagging.md) coverage / NuGet drift, [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md) hive-sync drift detection, and [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) D6 grid-health aggregator each produce signals that benefit from a human-glanceable surface.
- [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4's alert-routing table names "Notify + PagerDuty" for paying-tenant pages — but that is the **paying-tenant** path, not the operator-internal day-to-day operational surface. [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) presupposes a real-time channel that is **not** the same surface paying tenants get; this ADR names it.
- [ADR-0034](./ADR-0034-public-package-distribution-and-nuget-policy.md) NuGet publishes and per-Node release tags are silent today except for the GitHub email.

Several Grid Nodes already participate in *customer-facing* notification — `HoneyDrunk.Communications` per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md), `HoneyDrunk.Notify` per [ADR-0073](./ADR-0073-notify-default-providers.md), the future Notify Cloud per [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md). Those substrates exist; **operator alerts are categorically different from any of them**. Operator alerts are pre-customer, internal, pre-SLA, pre-tenant. Reusing the customer-notification substrate for operator alerts would muddle the boundary the [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) decision was authored to keep clean. This ADR draws the boundary explicitly.

This ADR depends on [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) (Communications boundary — Discord is NOT a Communications-Node concern), [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) (review-agent activity is one of the sources), [ADR-0046](./ADR-0046-specialist-review-agents.md) (specialist-agent activity is another source), [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) (incident-routing table cross-references this surface), [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) (vendor-posture taxonomy — Discord is Hedge), [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) (the runner is the non-Actions operator-emitter surface), [ADR-0088](./ADR-0088-decommission-openclaw-from-the-grid.md) (OpenClaw bridge and tunnel retired), [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) (rotation-escalation routes here), [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) (Notify Cloud is the customer-facing notification substrate, explicitly **not** consumed by this ADR), and [Invariant 8](../constitution/invariants.md) (secret-redaction discipline extends to webhook payloads).

## Decision

The decision is structured around eight bound sub-decisions: role and scope, channel taxonomy, webhook strategy, secret storage, alert-source roster, alert-routing table, vendor posture, and the new invariant binding the discipline.

### D1 — Role and scope: Discord is the canonical **operator-alerts surface**, nothing more

Discord is committed as the **single canonical channel** for **operator-facing operational alerts** about the Grid itself. Concretely, Discord IS:

- The real-time, day-to-day operational pager surface for the solo operator across CI failures, security signals, agent activity, release events, hive-sync drift, and credential-rotation escalations.
- The visible-by-default shared timeline where the operator can pattern-match across signal sources without opening five GitHub tabs.
- A **read mostly** surface — humans-do-not-respond-here is the operating mode; responses happen in GitHub Issues / PRs / the home server.

Discord is explicitly **NOT**:

- **Not a `HoneyDrunk.Communications` concern.** Communications per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) is the orchestration layer above customer notifications; it owns preference enforcement, cadence, suppression, and the welcome-flow lifecycle for **end users**. Operator alerts have no preferences, no cadence policy, no suppression beyond "drop duplicates," and no tenant scope. Routing operator alerts through Communications would dilute its boundary and complicate every Communications canary test for no operational benefit. See Communications' `boundaries.md` — operator alerts fail every Communications boundary decision test.
- **Not a `HoneyDrunk.Notify` concern.** Notify per [ADR-0073](./ADR-0073-notify-default-providers.md) owns email/SMS/push delivery mechanics for outbound user-facing messages. Discord as an operator-alert surface is neither email nor SMS nor push, and its consumers are not users with preferences. A future `IChatSender` provider slot inside Notify is conceivable for **customer-facing** chat (e.g., a tenant-bound Slack/Teams adapter), but operator-alert Discord is not that adapter; the consumer is "the operator," not "the tenant."
- **Not a Notify Cloud concern.** [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) Notify Cloud is the multi-tenant *commercial* delivery surface; operator alerts are internal, pre-customer, and would never traverse a tenant-scoped path. The operator does not pay themselves to receive their own alerts.
- **Not customer-facing community management.** [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) §G names a "public Discord" for Notify Cloud community support; that Discord is a *different surface in a different Discord server* (or in different channels within the existing server, fenced behind community-role permissions). This ADR is about the operator-alerts channels, not the public community channels. The two coexist; D7's tenant-isolation rules apply at the channel level.
- **Not the home-server's job.** [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) makes the home server a possible runner host, but that runner is an execution surface, not the operator-alerts surface. ADR-0088 retired the OpenClaw/webhook-bridge path. Native desktop notifications from local automation can still be useful when the operator is at the workstation, but they are blind when the operator is mobile. Discord is the mobile-and-desktop, anywhere-the-operator-is surface and remains the source-of-truth alerting surface.

### D2 — Channel taxonomy: six operator-alerts channels, one human-readable digest, one private audit channel

The existing Discord server gains the following dedicated **operator-alerts channels** (created as a single human task per the follow-up work below; channel naming is `lowercase-with-hyphens` per Discord convention):

| Channel | Audience | Routing | Description |
|---|---|---|---|
| `#ops-alerts` | Operator only | Bot-readable, human-glanceable | Credential expiry escalation (per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D5 T-30 / T-7 / T+0), CI failures on `main`, deploy events, scheduled-workflow failures (hive-sync, nightly-deps, nightly-security, grid-health aggregator). Default destination for "something operational just happened." |
| `#security-alerts` | Operator only | Bot-readable, human-glanceable | Dependabot / SonarCloud / CodeRabbit / CodeQL flagged issues, secret-scan hits, anything from [ADR-0056](./ADR-0056-threat-model-and-security-review-cadence.md) cadence's security-review surfaces, GitHub Advanced Security alerts. Separated from `#ops-alerts` because security signals warrant a higher-attention disposition and benefit from being a clean queue. |
| `#agent-activity` | Operator only | Bot-readable, human-glanceable | [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) Grid Review verdicts (summary line + PR link), [ADR-0046](./ADR-0046-specialist-review-agents.md) specialist invocations, [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) Codex/Claude/CodeRabbit/Copilot reviewer activity, and ADR-0086 runner job boundaries. Optional "agent-noisy" suppression rule per D8 below. |
| `#hive-activity` | Operator only | Bot-readable, human-glanceable | Issue board state changes (per [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md)), PRs opened/merged/closed, hive-sync drift findings, packet lifecycle transitions (`active/` → `completed/`). Rolling timeline of "what is moving in the Grid right now." |
| `#release` | Operator only | Bot-readable, human-glanceable | NuGet publishes per [ADR-0034](./ADR-0034-public-package-distribution-and-nuget-policy.md), version tag events, [ADR-0033](./ADR-0033-environment-gated-deploy-trigger-model.md) deploy successes / failures across `dev` / `staging` / `prod`, release-notes generation per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md). |
| `#announcements` | Operator only at v1; eventual community-facing | Human-readable summaries | Operator-authored summaries — "shipped X today," "ADR-0084 accepted," "tenant onboarded," "outage post-mortem published." This is the channel that grows into the public-facing surface when the studio expands beyond solo-dev. At v1 it is operator-only; the migration plan when audience widens is "rename or carve out a new channel for the operator-internal version." |
| `#audit-sensitive` | Operator only; private channel | Bot-readable, restricted | Credential expiry **dates** (not values — see D7), Vault rotation events, [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) audit anomalies, anything classified Internal or Confidential per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) that would be inappropriate in `#ops-alerts`. Discord channel-role-gated; webhook URL stored in a separate secret. Sensitive-by-permission, not sensitive-by-payload — Invariant 8 still applies and secret **values** never go here either. |

**Rejected channel taxonomies:**

- **Single firehose channel.** Rejected because alert taxonomy is the entire point — a 350-line/day firehose loses the property a pager exists to provide (glanceable categorization). The cost of seven channels is one-time setup; the benefit recurs every operational day.
- **One channel per source system** (e.g., `#github-actions`, `#dependabot`, `#sonarcloud`, `#coderabbit`). Rejected because routing-by-source means the operator must mentally re-categorize every alert into "what does this mean operationally." Routing-by-disposition (`ops`, `security`, `agent`, `hive`, `release`) puts that categorization at the source.
- **Two channels (`#alerts`, `#info`).** Considered as a minimal viable taxonomy. Rejected because security signals deserve their own attention slice, and agent activity is high enough volume that bundling it with CI failures creates the alert-fatigue failure mode this ADR is built to prevent.

### D3 — Webhook strategy: native Discord webhooks, one per channel, no bot bridge

The Grid uses **Discord's native incoming webhook feature**, with **one webhook per channel**. There is **no bot process** sitting in the middle routing by message envelope, and there is **no fan-out worker**.

**Rationale.** Discord incoming webhooks are dead-simple HTTP POST endpoints with no state, no process to maintain, no auth model beyond the secret URL itself, and native to GitHub Actions and any other emitter via `curl`. For a solo-dev studio at this scale, a bot bridge would be a process to monitor (own logs, own health, own rotation, own incident class) for marginal routing benefit. Webhook-per-channel is the canonical operating shape Discord exposes; it matches the [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) Hedge posture (D6 below) because swapping to Slack / Mattermost / Matrix / Teams is a webhook-URL change per emitter, not a rebuild of the routing layer.

**Rejected alternatives:**

- **One bot bridge that routes by message metadata** (`X-Channel: ops-alerts` header → bot reads → posts to `#ops-alerts`). Considered. A bot can offer richer formatting (slash commands, threaded replies, interactive components, message edits to consolidate noisy alerts). Rejected because (a) every richness benefit is a v2 concern, none of them is blocking the [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) escalation path; (b) the bot is a process with its own SLA, its own host, its own credential, its own incident class — a paradox where the alerting infrastructure itself can be the thing that needs an alert; (c) the bot couples the Grid to Discord's bot API surface (proprietary, evolves, lock-in), whereas webhooks are an open-shaped HTTP POST.
- **A single webhook + content-based routing inside a Cloudflare Worker / Azure Function fan-out.** Considered. One secret to rotate, central place to apply filtering. Rejected because the central fan-out is yet another process to operate; per-channel webhooks are simpler at every layer; and the [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) inventory entry per webhook is a feature, not a tax — each webhook is a credential with a blast radius, and inventorying them per channel is the right granularity.

### D4 — Webhook URL storage: per emitter class — GitHub org secrets for Actions, the automation Key Vault for the runner

Discord webhook URLs are stored **per emitter class**, because the Grid has two distinct emitter runtimes that cannot share one secret store.

**GitHub Actions emitters → GitHub organization-level secrets.** Each channel's Actions-side webhook URL is a **GitHub organization-level secret** with the naming pattern `DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}`:

- `DISCORD_WEBHOOK_OPS_ALERTS`
- `DISCORD_WEBHOOK_SECURITY_ALERTS`
- `DISCORD_WEBHOOK_AGENT_ACTIVITY`
- `DISCORD_WEBHOOK_HIVE_ACTIVITY`
- `DISCORD_WEBHOOK_RELEASE`
- `DISCORD_WEBHOOK_ANNOUNCEMENTS`
- `DISCORD_WEBHOOK_AUDIT_SENSITIVE`

The `#audit-sensitive` webhook is the only one of the seven that warrants more careful access scoping; it is also a GitHub org secret but is **not** exposed to public-repo workflows by default (consumed only by Architecture / Vault / Audit / private repos).

**ADR-0086 runner emitters → the shared automation Key Vault.** The pull-based local/grid runner ([ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md)) runs scheduled jobs (grid-review, post-merge-audit, hive-sync, lore-source, lore-ingest, lore-signal-review) under Task Scheduler **outside GitHub Actions**. It cannot natively consume GitHub org secrets without routing every job through Actions — precisely the coupling ADR-0086 was built to avoid. Its Discord webhook URLs are therefore **automation-runtime secrets**: a third category alongside [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D1's CI/ops-machinery secrets (GitHub org secrets) and workload-runtime secrets (Key Vault governed by `HoneyDrunk.Vault.Rotation`). They live in the shared automation Key Vault — vault **name** (`kv-hd-automation-dev`) resolved from the runner's host config, never a hardcoded URI — and are read at runtime by the runner's PowerShell secret helper (today `Get-RunnerVaultSecret` in `infrastructure/workers/grid-agent-runner/lib/GitHub.psm1`, a narrow `az keyvault secret show` wrapper; a generalized name-based resolver is future work, see D9). Runner webhook secrets use the Key-Vault-legal naming pattern `Discord--{ChannelPascalCase}--RunnerWebhookUrl`:

- `Discord--AgentActivity--RunnerWebhookUrl`
- `Discord--HiveActivity--RunnerWebhookUrl`

Only the channels the runner actually posts to get a runner webhook — at v1, `#agent-activity` and `#hive-activity`. A `Discord--OpsAlerts--RunnerWebhookUrl` is added later only if runner failures are duplicated to `#ops-alerts`.

**One webhook identity per (channel × emitter class).** Where both emitter classes post to the same channel (`#agent-activity` and `#hive-activity` at v1), each gets its **own Discord webhook** — never a shared URL. Actions posts via the org-secret webhook; the runner posts via the Key-Vault webhook. This is deliberate blast-radius hygiene: an org-secret leak does not compromise the runner's path and vice-versa, and the two rotate independently. Discord permits arbitrarily many webhooks per channel, so the only cost is one extra inventory row per shared channel. The distinct namespaces (`DISCORD_WEBHOOK_*` vs `Discord--*--RunnerWebhookUrl`) make a shared URL structurally impossible.

**Inventory and rotation.** Each Discord webhook URL — org-secret-stored and Key-Vault-stored alike — is an external-SaaS credential per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) and lands in `infrastructure/reference/sensitive-inventory.md` as an inventory row: the seven Actions webhooks plus one row per runner webhook (two at v1). Discord webhook URLs have **no provider-imposed expiration** — they remain valid until manually revoked. The inventory rows therefore carry `Expiration Cadence: n/a — non-expiring (rotate on suspected compromise only)` and have no standing rotation issue, but they still appear in the inventory because they are external-SaaS credentials by every other property: bound to a Discord-resource principal, with a real blast radius if leaked. Rotation procedure per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D4 lands as `infrastructure/walkthroughs/discord-webhook-rotation.md` (regenerate the webhook in Discord → update the store the webhook lives in: the GitHub org secret for an Actions webhook, the `kv-hd-automation-dev` secret for a runner webhook → smoke-test). This composes naturally with [ADR-0083](./ADR-0083-external-saas-credential-rotation.md); it does not amend it.

**Rejected alternatives:**

- **One secret with envelope-based routing.** Considered (paired with the bot bridge in D3). Rejected on the same grounds as D3 — central routing requires a central process; per-channel secrets match the per-channel webhook shape and surface the blast-radius granularity correctly.
- **Azure Key Vault as the storage backend for the GitHub Actions emitters.** Considered for the Actions path specifically. Rejected *for Actions* because GitHub Actions workflows are the dominant Actions-side emitter (CI failures, nightly workflows, release pipelines, the [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) review-pipeline), and GitHub-Actions-to-Key-Vault adds an OIDC round-trip per workflow — putting an Azure-auth dependency on the *alerting* path, which is the last path that should depend on another system being healthy. For the Actions class the credentials are Actions-secrets-shaped (per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D1 categorization), not workload-runtime-shaped; they live in GitHub org secrets alongside `SONAR_TOKEN`, `NUGET_API_KEY`, `CREDENTIALS_CHECK_TOKEN` for the same reason those do. **This rejection does not extend to the ADR-0086 runner.** The runner is not a GitHub Actions emitter, cannot consume org secrets without re-coupling to Actions, and already resolves secrets from `kv-hd-automation-dev` — so for the runner class Key Vault is the *correct* store, not the rejected one. The two emitter classes use different stores by design (see the body of this decision).
- **One webhook URL per channel, shared across both emitter classes (dual-stored).** Considered — a single Discord webhook per channel with the same URL written to both the org secret and the Key Vault. Rejected because one leak burns both delivery paths at once and rotation must touch two stores in lockstep; per-emitter webhooks (one identity per channel × emitter class, above) give independent rotation and a smaller blast radius for free, since Discord allows many webhooks per channel.

### D5 — Alert sources: a defined roster, not a free-for-all

The following sources publish to Discord at v1 (the alert-routing table below maps each to its destination channel and severity). New emitters require an entry on this list before they may consume a webhook secret.

| Source | Origin | Trigger |
|---|---|---|
| **GitHub Actions: CI failure on `main`** | Reusable workflow in `HoneyDrunk.Actions` (D9 follow-up) | Any workflow with `on: push: branches: [main]` failing |
| **GitHub Actions: deploy event** | [ADR-0033](./ADR-0033-environment-gated-deploy-trigger-model.md) `release.yml` per Node | Deploy to `dev` / `staging` / `prod` succeeds or fails |
| **GitHub Actions: NuGet publish** | [ADR-0034](./ADR-0034-public-package-distribution-and-nuget-policy.md) `job-publish-nuget.yml` | NuGet push succeeds or fails |
| **GitHub Actions: scheduled-workflow failure** | `nightly-deps.yml`, `nightly-security.yml`, `hive-field-mirror.yml`, `weekly-governance.yml`, `external-credentials-check.yml` ([ADR-0083](./ADR-0083-external-saas-credential-rotation.md)), grid-health aggregator ([ADR-0012](./ADR-0012-grid-cicd-control-plane.md) D6) | Cron job fails or produces a drift finding |
| **[ADR-0083](./ADR-0083-external-saas-credential-rotation.md) credential-rotation escalation** | `external-credentials-check.yml` | T-30 / T-7 / T+0 against inventory |
| **[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) review pipeline** | `job-review-request.yml` enqueue path + ADR-0086 runner completion notification | Review verdict posted on a PR |
| **[ADR-0046](./ADR-0046-specialist-review-agents.md) specialist invocations** | Same pipeline as Grid Review | Specialist agent invoked manually |
| **[ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md) hive-sync findings** | `hive-sync` agent run | Drift detected; packet move; field mirror result |
| **GitHub: PR opened / merged** | GitHub-Actions-on-`pull_request` reusable workflow or ADR-0086 runner-derived event where already executing | PR lifecycle events |
| **GitHub: security alerts** | GitHub Dependabot / CodeQL / secret-scanning webhooks | New alert at High+ severity |
| **SonarCloud quality gate failures** | SonarCloud webhook → relay or `job-sonarcloud.yml` post-step | Quality gate failed on PR or `main` |
| **CodeRabbit findings (P0/P1)** | [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) `.coderabbit.yaml` rule output | High-severity findings only |
| **Azure: budget alerts** | [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) 50/75/90/100% thresholds | Budget threshold crossed |
| **App Insights: error spike / failure-rate alert** | [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) / [ADR-0045](./ADR-0045-grid-wide-error-tracking.md) alert rules | Internal-Grid error/failure thresholds (tenant-facing remain on PagerDuty per [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md)) |
| **Operator-authored announcements** | Manual post by the operator | Anytime |

**Not on this list at v1, deliberately:**

- **Pulse telemetry firehose.** Per [Invariant 47](../constitution/invariants.md), audit and telemetry are distinct channels; Discord is **neither** of those substrates and must not become a downstream of Pulse. Pulse → Discord is a boundary violation.
- **Audit log tail.** [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) audit records are durable, attributable, and queried via `IAuditQuery`; Discord is not a query surface and is not append-only. Specific audit *anomalies* (rare, signal-shaped) may post to `#audit-sensitive` (a single line, no PII, no payload — just "anomaly detected, query Audit for INC-XYZ"); the rest of the audit log stays in the Audit substrate.
- **Customer-facing notifications.** Per D1 — out of scope, owned by Communications / Notify / Notify Cloud.

### D6 — Alert-routing table

This table pins the v1 routing for every source above. It lives in this ADR as the committed shape; the operational reference copy lives at `constitution/alert-routing.md` (new file, landed by follow-up work) and stays in sync via a `hive-sync` check that diffs the two (parallel to [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4's table treatment).

| Event source | Destination channel | Severity | Format hint |
|---|---|---|---|
| CI failure on `main` (any workflow) | `#ops-alerts` | High | `❌ {repo} / {workflow}: {commit-short} — {link-to-run}` |
| Deploy success ([ADR-0033](./ADR-0033-environment-gated-deploy-trigger-model.md)) | `#release` | Info | `🚀 {node} {tag} → {env} ({duration})` |
| Deploy failure ([ADR-0033](./ADR-0033-environment-gated-deploy-trigger-model.md)) | `#ops-alerts` + `#release` | High | `🔥 {node} {tag} → {env} FAILED — {link-to-run}` |
| NuGet publish success ([ADR-0034](./ADR-0034-public-package-distribution-and-nuget-policy.md)) | `#release` | Info | `📦 {package} {version} published to nuget.org` |
| NuGet publish failure ([ADR-0034](./ADR-0034-public-package-distribution-and-nuget-policy.md)) | `#ops-alerts` + `#release` | High | `📦❌ {package} {version} publish failed — {link-to-run}` |
| Scheduled workflow failure (cron) | `#ops-alerts` | Medium | `🕒❌ {workflow} ({schedule}) — {link-to-run}` |
| Credential rotation escalation T-30 ([ADR-0083](./ADR-0083-external-saas-credential-rotation.md)) | `#ops-alerts` | Medium | `🔑 {credential} expires in 30 days — {rotation-walkthrough-link}` |
| Credential rotation escalation T-7 ([ADR-0083](./ADR-0083-external-saas-credential-rotation.md)) | `#ops-alerts` + `#security-alerts` | High | `🔑⚠️ {credential} expires in 7 days — {rotation-walkthrough-link}` |
| Credential rotation T+0 (expired) ([ADR-0083](./ADR-0083-external-saas-credential-rotation.md)) | `#security-alerts` + `#audit-sensitive` | Critical | `🔑🔥 {credential} EXPIRED — {incident-record-link}` |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) review verdict (Approve / Request Changes / Comment) | `#agent-activity` | Info | `🐝 review on {repo}#{pr}: {verdict} — {pr-link}` |
| [ADR-0046](./ADR-0046-specialist-review-agents.md) specialist invocation | `#agent-activity` | Info | `🎯 {specialist} on {repo}#{pr}: {verdict} — {pr-link}` |
| [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md) hive-sync drift finding | `#hive-activity` | Medium | `🔄 hive-sync: {finding-summary} — {issue-link}` |
| [ADR-0085](./ADR-0085-grid-wide-documentation-currency-agent.md) docs-sync run report | `#hive-activity` | Info | `docs-sync: {summary-counts} — {report-or-pr-link}` |
| [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) strategic backlog source run | `#hive-activity` | Info | `backlog-strategic: {packets-created} proposed packets — {report-or-pr-link}` |
| [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) tactical node-audit backlog source run | `#hive-activity` | Info | `backlog-tactical: {node} audit, {findings-count} findings, {packets-created} packets — {report-or-pr-link}` |
| [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) opportunistic Scout backlog source run | `#hive-activity` | Info | `backlog-scout: {recommendation}, {packets-created} packets — {report-or-pr-link}` |
| [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) weekly backlog briefing generated | `#hive-activity` | Info | `backlog-briefing: {new-proposed-count} proposed, top-3 ready — {briefing-or-pr-link}` |
| [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) urgent reactive security packet | `#security-alerts` | High | `backlog-urgent-security: {summary} — {urgent-briefing-or-pr-link}` |
| [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) urgent reactive operational packet | `#ops-alerts` | High | `backlog-urgent-ops: {summary} — {urgent-briefing-or-pr-link}` |
| Packet lifecycle transition (`active/` → `completed/`) | `#hive-activity` | Info | `✅ {packet-slug} completed — {issue-link}` |
| PR opened | `#hive-activity` | Info | `🆕 {repo}#{pr}: {title} — {pr-link}` |
| PR merged | `#hive-activity` | Info | `✔️ {repo}#{pr} merged — {pr-link}` |
| GitHub Dependabot / CodeQL High+ alert | `#security-alerts` | High | `🛡️ {repo}: {alert-summary} — {alert-link}` |
| GitHub secret-scanning hit | `#security-alerts` + `#audit-sensitive` | Critical | `🛡️🔥 secret detected in {repo} — {alert-link}` (no value) |
| SonarCloud quality gate failure (main or PR) | `#security-alerts` | Medium | `📊 SonarCloud gate failed on {repo}#{pr-or-main} — {link}` |
| CodeRabbit P0/P1 finding ([ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md)) | `#security-alerts` | High | `🐰 CodeRabbit {severity} on {repo}#{pr} — {pr-link}` |
| Azure budget 50% threshold ([ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) | `#ops-alerts` | Info | `💰 budget at 50% ({category}, ${spend}/${cap})` |
| Azure budget 75% threshold ([ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) | `#ops-alerts` | Medium | `💰 budget at 75% ({category})` |
| Azure budget 90% / 100% threshold ([ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) | `#ops-alerts` + `#security-alerts` | Critical | `💰🔥 budget at {pct}% ({category}) — kill-switch posture: {posture}` |
| App Insights internal-Grid error spike ([ADR-0045](./ADR-0045-grid-wide-error-tracking.md)) | `#ops-alerts` | High | `🐞 {node}: {error-fingerprint} firing {rate}/h — {link}` |
| Grid Health aggregator drift ([ADR-0012](./ADR-0012-grid-cicd-control-plane.md) D6) | `#ops-alerts` | Medium | `🕸️ grid-health: {drift-summary} — {issue-link}` |
| Operator-authored announcement | `#announcements` | n/a | Human-written |

**Severity is advisory at v1, not enforced.** It exists to give the operator a glance-level disposition (Info / Medium / High / Critical) and to give a future filtering layer (D8) a hook. v1 does not implement Discord role-mentions per severity; that is a v2 concern called out below.

**Tenant-facing incident pages** ([ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4) continue to route via Notify + PagerDuty as that ADR pins. Discord may receive a *mirror* of the same alert via the App Insights or Grid-Health rows in the table above (so the operator sees the page land in two surfaces), but Discord is **not** a substitute for the PagerDuty escalation path for paying-tenant SEV-1/SEV-2 events. [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) is the canonical surface for tenant-facing incidents; this ADR is the canonical surface for operator-internal day-to-day.

### D7 — Vendor posture: Hedge, with named hedges

Per [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md)'s three-posture taxonomy, Discord is assigned **Hedge (active)**. The amendment is added to [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2's per-vendor table by follow-up packet:

| Vendor | Surface(s) | Posture | Specific hedges in place | Estimated exit cost |
|---|---|---|---|---|
| **Discord** | Operator-alerts surface (ADR-0084) | **Hedge (active)** | Webhook-only integration shape — no bot, no Discord-proprietary feature dependency, no Discord-Modules-equivalent vendor leakage; alert *content* lives in the Grid (inventory files, GitHub Actions logs, incident records); Discord receives a textual *projection* of those sources, never the source of truth; the reusable `job-discord-notify.yml` workflow (D9) is the single Grid-side seam; per-channel webhook URLs in GitHub org secrets are the only configuration | Days. Swap to Slack / Mattermost / Matrix / Teams (or even an email digest, per the candidate-surface document's preservation-grade fallback) by changing the webhook URL per emitter and the post-formatting in `job-discord-notify.yml` |

**Why Hedge, not Accept, not Abstract:**

- **Not Accept.** Discord is replaceable. The value is the rich client (mobile + desktop), the existing operator usage pattern, and the threading/search affordances — not any Discord-specific API. Naming it Accept would over-state the lock-in.
- **Not Abstract.** Abstract postures per [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D1 require a Grid-defined interface with multiple compatible implementations enforced by canary tests. An `IChatNotifier` abstraction backed by per-vendor implementations is conceivable but premature at v1 — there is **one** operator and **one** chat product; building an abstraction for the second is the kind of speculation the charter warns against. Hedge captures the situation correctly: the swap is bounded by the `job-discord-notify.yml` boundary, which is a *reusable workflow*, not an in-process abstraction.

**The re-evaluation triggers** per [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D4 apply unchanged. The Discord-specific ones to watch:

- **Material price change.** Discord's webhook feature is currently free with no documented usage limit; if that changes, posture re-evaluates against Slack (paid) / Mattermost (self-hosted, [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) home server is a credible host) / Matrix.
- **Terms-of-service drift conflicting with charter's build-in-public stance.** Discord's data-handling and account-policy regime is not a build-in-public-friendly substrate at the corporate-account level — this is acknowledged and is part of why Discord is Hedge, not Accept.
- **Operator-pattern shift.** If the operator's daily flow moves away from Discord (toward Slack for a paying-tenant integration, toward Matrix on the home server, toward something else entirely), the alerting surface follows. The operator's Discord usage is the load-bearing reason this surface is Discord; if that load-bearing reason changes, the surface changes.

### D8 — Privacy and signal-hygiene rules

The following are non-negotiable at the alert-payload level. They are enforced by the same secret-redaction discipline as logs (per [Invariant 8](../constitution/invariants.md) and [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md)):

- **No secret values.** Token values, API keys, connection strings, Vault contents, webhook signing secrets, and anything else governed by [Invariant 8](../constitution/invariants.md) **never** appear in a Discord payload. Names, identifiers, and metadata (expiration dates, blast-radius prose, rotation-walkthrough links) are permitted. The discipline matches `VaultTelemetry`'s redaction model.
- **No customer PII.** Tenant identifiers (`tenant-{id}`) and aggregate counts are permitted in operator-alerts channels; individual end-user identifiers, email addresses, phone numbers, account names, file contents, and journal/photo/voice content per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) Restricted tier are **never** posted. The principle is: Discord receives operational metadata about the Grid, not customer payload.
- **No full stack traces.** Stack traces belong in App Insights / the linked GitHub Actions log / the incident record. Discord posts get a one-line error fingerprint and a link. Stack-trace bodies pasted into chat are the alert-fatigue failure mode this ADR is built to prevent.
- **No customer-bound content from Notify Cloud.** Notify Cloud tenant message bodies, recipient lists, and template-rendering outputs do not traverse Discord. This is a corollary of "no customer PII" but is named explicitly because Notify Cloud will eventually emit operational events the operator wants to see (tenant suspended, abuse-rate threshold tripped) — those events post a metadata line, not the underlying message content.
- **Volume bounding.** The alert-routing table (D6) is the v1 budget. Any new emitter that would meaningfully grow alert volume (defined as: any source projected to emit more than 50 messages per day on average) requires an entry on the table per the onboarding hook (D10) — including a per-source severity floor, a duplicate-suppression rule, or both. Alert fatigue is the failure mode that makes a pager useless; pre-emptive volume budgeting prevents it.
- **Channel-appropriate posting.** Sources route to **one** channel per the table; cross-posting (e.g., a high-severity item posting to two channels) is permitted only when the table specifies it, never as an emitter-local decision.

**v2 considerations explicitly deferred:**

- **Role-mentions per severity** (e.g., `@operator` on Critical, no mention on Info). Useful once mobile-notification-discipline becomes load-bearing; not v1.
- **Duplicate-suppression / fingerprint dedup** parallel to [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D5's 1-hour fingerprint window. Useful for noisy CI; not v1. The single-page rule in [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) governs *tenant-facing* dedup; operator-internal alerts at v1 are best-effort.
- **Threaded follow-ups** (Discord threads keyed by alert fingerprint, so re-fires extend a thread instead of flooding the channel). Useful at scale; not v1.

### D9 — Implementation seam: `job-discord-notify.yml` reusable workflow in `HoneyDrunk.Actions`

A single reusable workflow lands in `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml`, callable by every other workflow via `workflow_call` per the [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) reusable-workflow pattern. Inputs:

- `channel` (one of: `ops-alerts`, `security-alerts`, `agent-activity`, `hive-activity`, `release`, `announcements`, `audit-sensitive`) — selects which `DISCORD_WEBHOOK_*` secret to use
- `severity` (one of: `info`, `medium`, `high`, `critical`) — selects which emoji/color decoration
- `title` — short one-line summary
- `body` — optional longer text (Discord embed `description`)
- `link` — optional URL the alert points at
- `metadata` (optional JSON) — structured fields rendered as an embed footer

The workflow handles message formatting consistently across emitters, applies the D8 redaction rules at the formatting boundary (a single pre-check that rejects messages containing patterns matching common secret shapes — same redaction discipline as VaultTelemetry), and POSTs to the correct webhook URL. **Every CI emitter routes through this workflow**; ad-hoc `curl` to webhook URLs in arbitrary workflows is forbidden per the v1 invariant in D11.

For emitters **outside** GitHub Actions, the canonical (and only) non-Actions emitter is the **[ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) pull-based runner** (PowerShell; entrypoint `Invoke-GridAgentRunner.ps1`; runs under Task Scheduler). There is **no** `infrastructure/scripts/discord-notify.ps1` home-server helper — ADR-0088 retired the OpenClaw/helper path, and the runner already owns its own posting path. The runner does not call the reusable workflow; it posts to Discord directly from its own PowerShell, applying the same D8 redaction pre-check and using the same `channel` / `severity` / `title` / `body` / `link` / `metadata` contract as `job-discord-notify.yml`. It resolves the channel's **runner** webhook URL from the shared automation Key Vault by secret name (`Discord--{ChannelPascalCase}--RunnerWebhookUrl`, per D4): today via the runner's `Get-RunnerVaultSecret` helper (`infrastructure/workers/grid-agent-runner/lib/GitHub.psm1`), a narrow `az keyvault secret show` wrapper currently prefix-scoped to `GitHub--AgentRunner--*`. Generalizing that helper into a name-based resolver any job can call for arbitrary secret names is **future work for this path and is not yet built**. Runner integration is centralized in `Invoke-GridAgentRunner.ps1` — every job's completion fires one notification through that path, so individual jobs do not each implement posting.

**Notification on the runner path is best-effort.** A Key Vault read failure, a Discord outage, or a non-2xx webhook response must **log and continue** — it must never turn a successful job (e.g. a completed `lore-ingest`) into a failed one. This differs from the Actions path, where `job-discord-notify.yml` is a discrete job the caller may choose to gate on; on the runner the notify call is strictly advisory. Same contract, same redaction rules, two delivery paths — GitHub Actions org secrets for cloud-CI emitters, the `kv-hd-automation-dev` Key Vault for the runner.

### D10 — Onboarding hook: new alert sources must declare their routing

When a new alert source is introduced anywhere in the Grid (new CI job, new scheduled workflow, new Node emitting operational events, new agent firing a non-PR-comment signal), the packet introducing it must include:

1. A new row on the D6 alert-routing table (added to this ADR by amendment or, once the alert-routing.md companion document exists, edited in that document with a cross-reference here).
2. The specific `channel` and `severity` inputs the source will pass to `job-discord-notify.yml`.
3. A volume estimate (messages-per-day projection) and, if above 50/day, an explicit suppression rule per D8.

This is checked at packet-authoring time by the [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) `review` agent's rubric category 19 (Anti-entropy — does this packet add to a structured surface or drift past it?) and surfaced by `hive-sync` if an alert source is observed firing into Discord without a routing-table entry.

This onboarding hook attaches to the [ADR-0082](./ADR-0082-canonical-node-standup-procedure.md) procedure document `constitution/node-standup.md`: any Node standup that introduces a new operational event surface gains a step parallel to [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D6's external-credential-onboarding step:

> **Operator-alert routing.** If the Node's standup introduces a new operational alert source (a new CI workflow, scheduled job, agent activity, or operational event emitter) that the operator should see in chat, the standup packet must, before the source enters any CI surface:
>
> 1. Add a row to `constitution/alert-routing.md` per ADR-0084 D6.
> 2. Pass `channel` and `severity` inputs through `job-discord-notify.yml` in HoneyDrunk.Actions per ADR-0084 D9.
> 3. If the source's projected volume exceeds 50 messages per day, declare a suppression rule per ADR-0084 D8.

### D11 — Invariant candidate: every operator-actionable Grid event routes through `job-discord-notify.yml`

A new invariant is added to `constitution/invariants.md` with this exact wording:

> **Every operator-actionable Grid event that the operator must see in real time** — CI failure on `main`, deploy event, NuGet publish, scheduled-workflow failure, credential-rotation escalation, agent verdict, hive-sync drift, security alert, budget threshold, internal-Grid error spike — **must publish to Discord via `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml`** (for GitHub-Actions-hosted emitters) **or via the ADR-0086 runner's Key Vault-resolved path** (for non-Actions emitters). The destination channel and severity must match an entry on the alert-routing table in `constitution/alert-routing.md` (or, until that file lands, ADR-0084 D6). **No Discord channel may receive secret values, customer PII, or full stack traces** ([Invariant 8](../constitution/invariants.md) extended to webhook payloads per ADR-0084 D8). Ad-hoc `curl` to a Discord webhook URL outside the reusable workflow / runner path is forbidden — the seam boundary is what allows redaction, formatting consistency, and vendor-posture swap per [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2.
>
> Enforcement: human review at PR time, supplemented by the `review` agent per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 categories 9 (Security — Secret handling) and 14 (Distributed systems — Observability / Notification discipline). The `hive-sync` agent surfaces emitters firing into Discord without a corresponding alert-routing-table entry.

The exact invariant number is assigned at acceptance by the scope agent, claiming the next free block in `constitution/invariant-reservations.md`. This invariant **complements**, does not replace, [Invariant 8](../constitution/invariants.md) (the secret-redaction discipline that pre-existed and that this invariant explicitly extends to webhook payloads).

## Consequences

### Positive

- **Operator-alerts surface is no longer scattered.** Today: GitHub email + 350-issue backlog + manual SaaS-dashboard checks + the operator's memory. After this ADR: seven dedicated Discord channels with a routing table.
- **[ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D5 escalation has a saliency-appropriate channel.** The T-30 / T-7 / T+0 path that started this ADR is no longer "yet another labeled issue" — it lands in `#ops-alerts` and (at T+0) in `#security-alerts` and `#audit-sensitive`, with severity decoration the operator can glance.
- **[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) and [ADR-0046](./ADR-0046-specialist-review-agents.md) agent activity becomes pattern-matchable.** Today every review verdict is a PR comment buried in a notification list; after this ADR there is a rolling timeline in `#agent-activity` where the operator can see "did Claude and Codex disagree on this PR?" without opening every PR.
- **Customer-facing and operator-facing notification substrates stay clearly separated.** Communications / Notify / Notify Cloud / Hearth-community-Discord all coexist with no boundary muddling, because operator alerts now have their own surface with its own ADR.
- **Vendor-exit is bounded to weeks.** The Hedge posture per D7 plus the `job-discord-notify.yml` seam per D9 means switching from Discord to Slack / Mattermost / Matrix / Teams / email-digest is a contained change at the workflow and webhook-URL level, not a Grid-wide rewrite.
- **The discipline composes with existing invariants.** [Invariant 8](../constitution/invariants.md) (secrets) and [Invariant 47](../constitution/invariants.md) (audit-vs-telemetry separation) both extend naturally to D8's payload rules and D5's "Pulse and Audit do not flow to Discord" carve-outs.

### Negative

- **Discord becomes a vendor relationship the Grid depends on for operational saliency.** The Hedge posture and the named hedges bound the exit cost to weeks, but Discord-the-product turning hostile (price, terms, account policy) is a real failure mode. The re-evaluation triggers in D7 catch it; the cost is one decision conversation when triggered, not perpetual portability work.
- **Seven channels and seven secrets is real inventory.** Seven rows in [ADR-0083](./ADR-0083-external-saas-credential-rotation.md)'s `external-credentials.md`. Manageable, but not free.
- **Alert volume must be actively budgeted.** D8's 50-messages-per-day-per-source rule plus the onboarding hook in D10 are the mitigations; the failure mode if they erode is alert fatigue, which makes the pager useless. The cost is ongoing discipline.
- **A reusable workflow plus the ADR-0086 runner's own path is two delivery paths.** D9 calls this out — two seams, same contract, twice the maintenance touch on emitter changes. Accepted because GitHub Actions and the ADR-0086 runner are the two distinct execution environments; a single seam would require routing every runner job back through Actions (the coupling ADR-0086 exists to avoid) or every CI emitter through the runner, and neither is the right answer.
- **The `#audit-sensitive` channel is private-by-permission but still on Discord.** It is not a cryptographically protected surface. The D8 rule that secret *values* never appear there is the load-bearing protection; the channel-permission is defense-in-depth. Operators who treat `#audit-sensitive` as a vault are misreading the design.
- **Operator-internal Discord coexists with the future Notify Cloud community Discord** per [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) §G. The boundary is "different channels (or different servers) with different role-based permissions"; muddling them is a failure mode this ADR's D1 names but does not enforce — enforcement is procedural at channel-setup time.

### Affected Nodes

- **`HoneyDrunk.Architecture`** — primary affected Node. Lands `constitution/alert-routing.md` (the canonical alert-routing surface), the new invariant in `constitution/invariants.md`, the seven inventory rows added to `infrastructure/reference/external-credentials.md` per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md), and the `infrastructure/walkthroughs/discord-webhook-rotation.md` walkthrough.
- **`HoneyDrunk.Actions`** — new reusable workflow `job-discord-notify.yml` per D9; every existing workflow that currently emits a notable signal (CI failure on main, release events, scheduled-workflow failures, [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) review pipeline) gains a `job-discord-notify` call site in its post-step. Phased rollout per Follow-up Work below — every workflow change is a separate packet, not bundled.
- **`HoneyDrunk.Vault.Rotation`** — **unchanged**. Discord webhook URLs are external-SaaS credentials per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D1's CI/ops-machinery category, not runtime workload secrets; rotation stays manual via the [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) walkthrough, not via Vault.Rotation.
- **`HoneyDrunk.Communications`** — **unchanged**. D1's boundary is explicit: operator alerts do not flow through Communications.
- **`HoneyDrunk.Notify`** — **unchanged**. Same boundary — Notify owns customer-facing delivery, not operator-facing alerts.
- **`HoneyDrunk.Pulse`, `HoneyDrunk.Observe`, `HoneyDrunk.Audit`** — **unchanged at the runtime level**. Pulse and Audit do not flow to Discord per the D5 carve-outs and [Invariant 47](../constitution/invariants.md). Observe may eventually grow a connector that publishes normalized observation events to Discord — that is a separate ADR if and when it happens, governed by [ADR-0010](./ADR-0010-observation-layer.md)'s connector pattern.
- **[ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) pull-based runner** — the non-Actions emitter class. Posts to Discord from its own PowerShell path, resolving the `Discord--{ChannelPascalCase}--RunnerWebhookUrl` secrets from the shared automation Key Vault (`kv-hd-automation-dev`) per D4/D9. No `infrastructure/scripts/discord-notify.*` home-server helper is introduced; ADR-0088 retired the OpenClaw/helper path while retaining the machine as a possible ADR-0086 runner host.

### Cascade Impact

- `constitution/alert-routing.md` lands as a new file via the first follow-up packet, seeded from D6.
- `constitution/invariants.md` gains the D11 invariant (number assigned at acceptance) via the same packet.
- `constitution/invariant-reservations.md` gains the ADR-0084 reservation row (block of 1).
- `adrs/README.md` gains the ADR-0084 row when this ADR flips Accepted.
- `infrastructure/reference/external-credentials.md` gains seven new rows (one per Discord webhook) — landed alongside or after the [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) initial-inventory packet.
- `infrastructure/walkthroughs/discord-webhook-rotation.md` lands as a follow-up packet.
- `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml` lands as a follow-up packet, with secret-redaction unit tests where feasible.
- Per-workflow `job-discord-notify` adoptions land as a phased rollout — one packet per emitter family (CI-on-main, release events, scheduled cron, [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) review pipeline).
- [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D3's escalation language is amended (in follow-up, not in the ADR-0083 body — Proposed-ADR discipline) to cite this ADR as the alerting surface for T-30 / T-7 / T+0.
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) follow-up note added: if the review-pipeline events are surfaced here, the [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 rubric category 14 (Distributed systems — Observability) gains "review-event publication to `#agent-activity`" as a check.
- [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2 table gains a Discord row per D7 (amendment, not supersession).
- [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4 routing-table is cross-referenced (no edit) — that table remains the canonical surface for tenant-facing pages; Discord is the canonical surface for operator-internal alerts; the two coexist.

### Cross-references to existing ADRs

- **[ADR-0010](./ADR-0010-observation-layer.md)** — Observe could in principle grow a Discord connector under its connector pattern; out of scope here, separate ADR if needed.
- **[ADR-0012](./ADR-0012-grid-cicd-control-plane.md)** — `job-discord-notify.yml` is a new reusable workflow under [ADR-0012](./ADR-0012-grid-cicd-control-plane.md)'s control-plane discipline. The grid-health aggregator (D6 in that ADR) is one of the alert sources in D5/D6 here.
- **[ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md)** — `hive-sync` is both a source of alerts (drift findings) and the enforcement mechanism for the alert-routing-table-vs-ADR-0084-D6 drift check.
- **[ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md)** — explicit boundary: Communications owns customer-facing message orchestration, this ADR owns operator-facing alert surface. Two distinct concerns, two distinct substrates.
- **[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)** — review pipeline is a v1 alert source. The rubric extension is in Cascade Impact above.
- **[ADR-0046](./ADR-0046-specialist-review-agents.md)** — specialist agents are a v1 alert source.
- **[ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md)** — Restricted-tier data never traverses Discord; classification taxonomy is referenced in D8.
- **[ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md)** — D4 routing-table cross-reference; tenant-facing pages still flow through Notify + PagerDuty, operator-internal alerts flow through Discord; the two are sibling surfaces, not substitutes.
- **[ADR-0056](./ADR-0056-threat-model-and-security-review-cadence.md)** — security signals route to `#security-alerts` per D6.
- **[ADR-0073](./ADR-0073-notify-default-providers.md)** — Resend/Twilio/Expo provider slots stay scoped to customer-facing delivery; operator alerts do not consume them.
- **[ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md)** — CodeRabbit P0/P1 findings are a v1 alert source.
- **[ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md)** — Discord is added to the per-vendor table per D7.
- **[ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md)** — superseded by ADR-0088; its OpenClaw bridge/helper premise is no longer a delivery path.
- **[ADR-0082](./ADR-0082-canonical-node-standup-procedure.md)** — D10 onboarding hook attaches to the standup procedure document.
- **[ADR-0083](./ADR-0083-external-saas-credential-rotation.md)** — escalation surface; Discord webhook URLs are inventory rows in `external-credentials.md`; D6 onboarding hook in [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) parallels D10 here.
- **[PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md)** — Notify Cloud community Discord is a sibling surface, channel-isolated.
- **[Invariant 8](../constitution/invariants.md)** — secret-redaction discipline extends to Discord webhook payloads per D8 and the new invariant in D11.
- **[Invariant 47](../constitution/invariants.md)** — audit and telemetry are distinct from Discord; Pulse and Audit do not flow to Discord per D5.

### Follow-up Work

None of the following is part of this ADR. Each is discrete follow-up scoped via the `scope` agent after acceptance.

- **Create the seven operator-alerts channels** in the existing Discord server (human task, operator-only): `#ops-alerts`, `#security-alerts`, `#agent-activity`, `#hive-activity`, `#release`, `#announcements`, `#audit-sensitive`. Set per-channel role permissions; `#audit-sensitive` is private to the operator-only role.
- **Provision the seven Actions webhook URLs** in Discord (Server Settings → Integrations → Webhooks → New Webhook per channel) and store each as a GitHub organization secret (`DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY_ALERTS`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE`). **Additionally provision the two runner webhooks** (`#agent-activity`, `#hive-activity` at v1) as separate Discord webhooks and store each in the shared automation Key Vault (`kv-hd-automation-dev`) under `Discord--AgentActivity--RunnerWebhookUrl` / `Discord--HiveActivity--RunnerWebhookUrl` per D4.
- **Author `infrastructure/reference/external-credentials.md`** entries for the seven Discord webhooks per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D2 — cadence `n/a — non-expiring (rotate on suspected compromise only)`, owner solo-dev, blast-radius prose per channel.
- **Author `infrastructure/walkthroughs/discord-webhook-rotation.md`** per [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D4 — regenerate webhook in Discord → update GitHub org secret → smoke-test via `job-discord-notify.yml` with a test payload.
- **Author `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml`** — the reusable workflow per D9, including the redaction pre-check.
- **Wire the ADR-0086 runner's Discord posting path** per D9 — the runner posts directly from its own PowerShell, resolving the `Discord--{ChannelPascalCase}--RunnerWebhookUrl` secrets from `kv-hd-automation-dev` (today via `Get-RunnerVaultSecret`; a generalized name-based resolver is future work). No `infrastructure/scripts/discord-notify.*` home-server helper is authored — the home server is decommissioned.
- **Author `constitution/alert-routing.md`** — the canonical, hive-sync-checked alert-routing table seeded from D6.
- **Add the new invariant** to `constitution/invariants.md` with the number claimed from `constitution/invariant-reservations.md`.
- **Phase 1 rollout** — wire CI failure on `main`, release events, NuGet publishes, scheduled-workflow failures, and the [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) credential-rotation escalation to `job-discord-notify.yml`. One packet per emitter family.
- **Phase 2 rollout** — wire the [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) review pipeline and [ADR-0046](./ADR-0046-specialist-review-agents.md) specialist invocations to `#agent-activity`. Cross-link from [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)'s follow-up notes.
- **Phase 3 rollout** — wire hive-sync findings, packet lifecycle transitions, GitHub Dependabot / CodeQL / secret-scanning alerts, SonarCloud and CodeRabbit signals.
- **Phase 4 rollout** — wire Azure budget alerts ([ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) and App Insights internal-Grid error spikes ([ADR-0045](./ADR-0045-grid-wide-error-tracking.md)).
- **Amend [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) D3 follow-up note** (in the follow-up packet, not in [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) body — Proposed-ADR discipline) to cite this ADR as the alerting surface.
- **Amend [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2 table** by follow-up to add the Discord row per D7.
- **Amend `constitution/node-standup.md`** (the [ADR-0082](./ADR-0082-canonical-node-standup-procedure.md) procedure document) to include the operator-alert-routing step per D10.
- **Cross-reference this ADR from `repos/HoneyDrunk.Notify/runbooks/alert-routing.md`** ([ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D10 lives there) — Notify Cloud's tenant-facing alert routing and this ADR's operator-internal Discord routing are sibling surfaces; the runbook should make the boundary explicit.

## Alternatives Considered

### Route operator alerts through `HoneyDrunk.Communications`

The most architecturally tidy-looking option on paper: Communications is already the orchestration substrate; let it grow an `IOperatorAlertSink` and route Discord through it. Rejected because Communications per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) owns **end-user** preference, cadence, suppression, and lifecycle workflows; operator alerts have none of those concerns. Reusing Communications would muddle its boundary, complicate every Communications canary test, and create a second class of consumer ("operator" vs "user") with completely different semantics. The Communications boundary tests in `repos/HoneyDrunk.Communications/boundaries.md` fail for operator-alert payloads on every dimension — no preferences, no cadence, no business-event-to-intent mapping, no tenant scope. The right boundary is **Discord is its own substrate**, not "a new sink behind Communications."

### Route operator alerts through `HoneyDrunk.Notify`

Considered. Notify is the delivery substrate; an `IChatSender` provider slot could deliver to Discord. Rejected for the same boundary-muddling reason as Communications, plus an additional one: Notify per [ADR-0073](./ADR-0073-notify-default-providers.md) is being shaped around **multi-tenant** customer-facing delivery (Resend / Twilio / Expo, with provider keys in `kv-hd-notify-{env}` and tenant-scoped suppression lists). Operator alerts have no tenant, no preference store, no cadence policy — putting them through Notify would force every Notify code path to handle the "no-tenant" sentinel case, fork the provider-slot pattern for chat, and gain a new test surface for non-tenant flows. The cost-benefit math runs the wrong way; Discord-as-its-own-substrate stays clean.

### Use the existing GitHub issue mechanism only (status quo)

Considered. [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) D6/D7 (the `🕸️ Grid Health` aggregator + the operator's GitHub email notifications) is an existing surface; adding Discord adds another. Rejected because the existing surface has the failure mode this ADR closes: real-time per-failure email plus a daily-batched aggregator issue do not provide a glanceable, categorized, mobile-and-desktop, shared-timeline surface. [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) D6 itself names the upgrade path: *"Slack or Discord integration. No current channel matches, and D7 covers per-failure real-time notification via a mechanism that already exists. Named as a future extension if HoneyDrunk Studios operations grow beyond one human."* This ADR is the named-future-extension landing — the upgrade is triggered now because [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) creates a forcing function and because the alert volume (review-pipeline activity, security signals, deploy events, hive-sync drift) has grown past the GitHub-email surface independent of team size.

### Build an in-house notification bus (e.g., reuse Pulse, or stand up a new `HoneyDrunk.OperatorBus` Node)

Considered. Both options promise "we control the substrate" and would compose more tightly with the Grid's other observability surfaces. Rejected on cost-discipline grounds: standing up a Node to operate the alerting infrastructure inverts the cost-benefit math — the substrate that exists to notice operational problems would now itself be an operational problem (its own SLA, its own host, its own incident class, its own canary). Pulse is the wrong shape because per [Invariant 47](../constitution/invariants.md) audit and telemetry are distinct channels and the Grid is committed to that separation; routing operator alerts through Pulse would collide with that invariant and with [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md)'s App Insights backend choice. Discord-as-third-party-vendor with Hedge posture per D7 is the right cost-shape at solo-dev scale; "if Discord turns hostile, swap to Slack" is a far cheaper insurance than "operate our own pager."

### One Discord channel for everything (single firehose)

Considered as a minimum-viable taxonomy. Rejected for the reasons in D2's rejected-taxonomies — alert taxonomy is the entire point of a pager; a firehose is the failure mode it exists to prevent.

### One bot bridge that routes by message envelope

Considered. A bot bridge offers richer formatting, threading, message edits to consolidate noisy alerts, and slash-command interactivity. Rejected for the reasons in D3 — a bot is a process to operate (own SLA, own host, own incident class), the richness benefits are all v2 concerns, and the bot couples the Grid to Discord's bot API surface in a way webhooks do not. Re-evaluate at the trigger point where alert volume or formatting needs justify the operating cost — explicitly **not** at v1.

### Use a managed third-party alerting service (PagerDuty / Opsgenie / Better Stack)

Considered. PagerDuty already exists in the Grid per [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4 for tenant-facing pages; expanding it to cover operator-internal alerts would unify on one vendor. Rejected because (a) PagerDuty's escalation-policy model is overkill for "operator glances at chat throughout the day" — that is the *opposite* of a "this is broken right now wake the operator up" page; (b) PagerDuty's per-user pricing scales with team size and the value-per-month for an operator-internal-low-severity stream is poor; (c) the right disposition for operator-internal alerts is "ambient saliency in a place I already look" (chat), not "phone call + SMS + push" (PagerDuty); (d) [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) already pairs Notify + PagerDuty for the high-severity tenant-impacting path; Discord is the complementary low-severity ambient path. The two surfaces serve different purposes and both are correct.

### Use email digests only (no chat surface)

Considered as the simplest-possible alternative. Rejected because email is the surface this ADR is built to *replace* — the operator's email already gets GitHub Actions failure notifications per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) D7, and that surface is exactly where alerts go to die alongside marketing email and product newsletters. The forcing function ([ADR-0083](./ADR-0083-external-saas-credential-rotation.md)'s "label-filtered GitHub issues still get lost in a 350-issue backlog") applies equally to "label-filtered emails get lost in an inbox." Chat is structurally different from email — the unread-indicator, the channel taxonomy, the mobile push behavior, the shared timeline are all properties email does not provide.

### Defer this ADR until [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) ships in production

Considered. Wait until [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) hits the field and the T-30 escalation has fired a few times against the existing GitHub-issues surface; if it works, no need for Discord. Rejected on the same grounds [ADR-0082](./ADR-0082-canonical-node-standup-procedure.md) and [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) themselves were drafted now rather than deferred: the gap is real today across multiple sources (CI failures, agent activity, security signals, release events, hive-sync drift), [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) is a forcing function but not the only one, and the cost of the ADR is low. Industrialize the operator-alert surface before [ADR-0083](./ADR-0083-external-saas-credential-rotation.md)'s first T-30 fires — the inventory shows SonarCloud's 60-day cap means a first rotation event is realistically within the next 30–60 days from acceptance, and a missed signal in that window collides exactly with what this ADR is built to prevent.

## References

- [`constitution/charter.md`](../constitution/charter.md) — many-decade horizon, decision-points-not-kill-clocks, workshop-not-startup framing, bus-factor-of-1 framing (the operator's mobile pager is a bus-factor-of-1 concern)
- [`constitution/invariants.md`](../constitution/invariants.md) — Invariant 8 (secrets in logs/traces, extended to webhook payloads), Invariant 47 (audit / telemetry separation, extended to "Discord is neither")
- [ADR-0010](./ADR-0010-observation-layer.md) — Observe connector pattern; future Discord connector is in-scope-for-Observe-not-this-ADR
- [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) — `HoneyDrunk.Actions` as CI/CD control plane (home of `job-discord-notify.yml`); D6/D7 the alerting baseline this ADR upgrades
- [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md) — hive-sync as both source-of-alerts and drift-check enforcement
- [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) — Communications boundary; this ADR explicitly does not consume it
- [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) — Audit substrate (anomalies post to `#audit-sensitive` but audit log proper does not flow to Discord)
- [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) — App Insights internal-Grid alerts as a source
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — review pipeline as a source (`#agent-activity`); rubric category 14 cross-reference
- [ADR-0045](./ADR-0045-grid-wide-error-tracking.md) — error tracking as a source
- [ADR-0046](./ADR-0046-specialist-review-agents.md) — specialist agents as a source
- [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) — Restricted-tier data never crosses Discord
- [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) — budget alerts as a source
- [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) — tenant-facing PagerDuty path is sibling to this ADR's operator-internal Discord path
- [ADR-0056](./ADR-0056-threat-model-and-security-review-cadence.md) — security-review cadence outputs route to `#security-alerts`
- [ADR-0073](./ADR-0073-notify-default-providers.md) — customer-facing delivery; this ADR explicitly does not consume
- [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) — CodeRabbit as a source
- [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) — Discord is Hedge; D2 table amended by follow-up
- [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) — superseded by ADR-0088; historical home-server/OpenClaw context only
- [ADR-0082](./ADR-0082-canonical-node-standup-procedure.md) — onboarding hook attaches to the standup procedure document
- [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) — forcing function; rotation escalation routes here; Discord webhook URLs are inventory rows
- [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) — Notify Cloud community Discord is a sibling surface, channel-isolated
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) — adjacent candidate-surface document (build-in-public alerting was named there as a candidate surface)
