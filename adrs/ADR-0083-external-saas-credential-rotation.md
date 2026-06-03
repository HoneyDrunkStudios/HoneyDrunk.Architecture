# ADR-0083: Sensitive Inventory and External-SaaS Credential Rotation Procedure

**Status:** Accepted
**Date:** 2026-05-25
**Deciders:** HoneyDrunk Studios
**Sector:** Infrastructure / cross-cutting

## Context

ADR-0005 pinned where Grid secrets live (`kv-hd-{service}-{env}`, per-deployable-Node Key Vaults, Managed Identity at runtime, OIDC at CI). ADR-0006 pinned the **lifecycle** for those secrets in two Vault tiers: Tier 1 (Azure-native, ≤ 30 days SLA) and Tier 2 (third-party providers rotated by `HoneyDrunk.Vault.Rotation`, ≤ 90 days SLA). Both ADRs were drafted around secrets the Grid's *workloads* consume at runtime — provider API keys, signing secrets, JWT keys.

There is a separate class of credential the Grid uses today that **neither ADR covers**: external-SaaS tokens that **plumb the development and operations machinery rather than the runtime Grid**. These tokens authenticate CI to a third-party service or authenticate cross-repo Actions to GitHub itself. They live as **GitHub organization-level secrets** (not in Azure Key Vault). They are bound to a human's user account or a Studios-owned organization principal at the SaaS, not to a Managed Identity. They have **provider-imposed expiration**, sometimes short, with no API to extend.

**The operator's broadened framing during drafting.** Mid-draft, the scope expanded. The original framing — "external-SaaS credentials that need rotation" — left a category of equally load-bearing artifacts undocumented: non-rotating identifiers (`HIVE_APP_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, GitHub org name, NuGet package owner IDs, Discord guild ID), webhook-signing-secret *slot names* whose values rotate elsewhere but whose existence is permanent, OIDC federated-credential configurations whose subject patterns are operationally binding even though they aren't secrets, long-lived Azure Key Vault signing/encryption keys whose values are out of scope here but whose existence should be discoverable from the same index, and resource identifiers (Key Vault names, Container Apps environments, Service Bus namespaces) that today live only in IaC. The recognition was: **lost / forgotten / undocumented credentials are themselves a bigger lottery-bus-factor risk than missed rotations**. The cure is the same artifact either way — a central index. So this ADR's deliverable is reframed as a **registry of what the Grid holds** (not a secret store; values continue to live in their authoritative location), of which rotation-needing credentials are one populated subset.

Four concrete cases are in the wild or imminent:

- **`SONAR_TOKEN`** — SonarQube Cloud Personal Access Token, bound to the org admin's user account. The free/OSS plan **caps PAT expiration at 60 days** with no UI to extend. Stored as a GitHub org secret. Consumed by `job-sonarcloud.yml` in `HoneyDrunk.Actions` (per ADR-0011 D11). Forcing function for this ADR: a missed rotation silently breaks SonarCloud analysis on every PR after the 60-day window, which is a code-review-gate degradation that ADR-0011 explicitly relies on for public-repo coverage.
- **`NUGET_API_KEY`** — NuGet.org Personal API Key, bound to the org admin's nuget.org account, scoped to the `HoneyDrunk.*` package glob. NuGet.org **caps Personal API Keys at 365 days** for keys created in recent years (legacy never-expires keys are grandfathered but should not be assumed available for new keys). Stored as a GitHub org secret. Consumed by `release.yml:442` in `HoneyDrunk.Actions` and surfaced through `examples/publish-nuget.yml`, `docs/consumer-usage.md`, and `README.md`. **Highest blast radius after SONAR_TOKEN**: every NuGet-shipping Node's release pipeline silently fails to publish, breaking the ADR-0034 publishing pipeline across the Grid and stalling downstream package restore. NuGet.org *does* expose an API for key management (`nuget.org/api/v2/...`); D1 still rules out automated rotation on cost grounds. **Discovery context**: this key has been rotating-by-default whenever it expired, without a documented procedure — another data point in the drift pattern this ADR closes.
- **`GH_ISSUE_TOKEN`** and peer GitHub PATs — variable expiration (fine-grained: up to 366 days; classic: optionally unlimited but deprecated). Used for cross-repo Actions secrets (file-issues batch action per ADR-0008 D6), Codex authentication, and as fallback identity for OpenClaw's webhook bridge before the ADR-0044 GitHub App migration completes.
- **Imminent**: Stripe API keys (PDR-0002 Notify Cloud commercial trial, governed by ADR-0037), Resend / Twilio API keys (ADR-0073 Notify default providers — these are in scope of Vault.Rotation Tier 2 once *issued*, but their *initial provisioning* lands here), possibly Sentry organization tokens (deferred per ADR-0040/0045's pivot to Azure Monitor + App Insights), SonarCloud organization tokens if the paid Team plan is ever adopted.

The shared shape: each is a credential the Grid depends on, **none of them lives in any `kv-hd-*` vault**, and none is rotated by `HoneyDrunk.Vault.Rotation`. They are entirely outside the ADR-0005 / ADR-0006 substrate. Today there is:

- No canonical inventory listing every external-SaaS token, who owns it, where it is stored, and when it expires.
- No documented rotation procedure for any of them.
- No expiration tracking — the next reminder is whatever a SaaS sends to the operator's inbox, which routinely lands in a spam fold or a tab that isn't open.
- No documented failure mode. SONAR_TOKEN expiry produces a silent CI degradation, not an alert; SonarCloud's check just doesn't post.

This gap was identified during ADR-0011 acceptance work — the SonarCloud organization setup walkthrough being authored alongside the ADR-0011 acceptance branch needs somewhere to point for *"and how do I rotate this PAT in 60 days, and how does the Grid notice when I forget?"* and the answer is "we don't have a procedure." This ADR closes that gap before SONAR_TOKEN's first expiry window lands.

This ADR depends on ADR-0005 (the env-var-driven Vault bootstrap that does **not** cover GitHub org secrets), ADR-0006 (the Vault.Rotation scope this ADR explicitly does **not** expand into), ADR-0011 (SONAR_TOKEN is the immediate forcing function), ADR-0034 (NuGet Publishing — NUGET_API_KEY has been in production longer than any other external-SaaS credential and is one of the forcing functions this ADR retroactively documents), ADR-0044 (which already names webhook signing secrets and a GitHub App token, both external-SaaS-shaped), ADR-0082 (the standup-procedure ADR drafted alongside this one, which is the onboarding-hook home), PDR-0002 (Stripe / Resend / Twilio credentials imminent), and Invariant 8 (secrets never appear in logs/traces — fully preserved, not relaxed).

## Decision

The decision is structured around seven bound sub-decisions: where the inventory lives, what shape each record takes, how expirations are tracked, where rotation procedures are documented, whether Vault.Rotation expands to cover external-SaaS rotation, what happens when a rotation is missed, the onboarding hook for new providers, and the new invariant that binds the discipline.

### D1 — Vault.Rotation does **not** expand to cover external-SaaS PATs. External-SaaS rotation stays manual indefinitely.

This is the load-bearing scope question and it is settled deliberately for the **Hedge** vendor posture per ADR-0080. The Grid does not build a rotation Node that integrates with the GitHub API, SonarCloud API, Stripe API, Resend API, Twilio API, etc. just to rotate the credentials the Grid uses to talk to those services. The cost discipline is explicit:

- A rotation Node consuming N third-party APIs at solo-developer scale is non-trivial recurring engineering — each provider's rotation API has its own auth model, its own rate limits, its own deprecation cadence. The maintenance bill scales with provider count.
- The volume is small. There are **fewer than ten** active external-SaaS tokens across the Grid today (SONAR_TOKEN, NUGET_API_KEY, GH_ISSUE_TOKEN, the ADR-0044 webhook signing secret, the then-anticipated OpenClaw GitHub App private key, plus the imminent commercial trio of Stripe / Resend / Twilio). At that scale, manual rotation with calendared reminders is cheaper than an automated rotation Node. ADR-0088 later confirmed there was no distinct OpenClaw GitHub App private key; the only OpenClaw-bound credential was the webhook signing secret, now retired.
- Vault.Rotation's existing scope (per ADR-0006) is **third-party secrets *the Grid issues to itself via the provider's API*** (e.g. Resend's `RESEND_API_KEY` minted via Resend's API, written into `kv-hd-notify-{env}`). The external-SaaS PATs in this ADR are categorically different: they are **CI/ops machinery credentials, not runtime workload credentials**, and they target GitHub org secrets, not Azure Key Vault. Conflating the two would force Vault.Rotation to grow a second storage backend (GitHub org secrets via the GitHub API) and a second identity model (the operator's GitHub user, not a Managed Identity).
- ADR-0080's vendor-posture taxonomy: SonarCloud and GitHub are both **Accept** posture (deep, intentional vendor relationships); their PATs are operational tax of that posture, not portability surface. Automating the tax doesn't reduce the lock-in; it just adds engineering on top of it.

The decision is **manual rotation with disciplined inventory and tracking**, not automated rotation. If the provider catalog grows past ten active tokens, or if a single high-blast-radius token recurs frequently enough to dominate operator attention, this ADR is revisited.

**Note on overlap with ADR-0006 Tier 2.** Resend and Twilio API keys *do* land in `kv-hd-notify-{env}` once issued, and Vault.Rotation *does* rotate them per ADR-0006 (today as documented portal runbooks; eventually via provider APIs where available). The split between "this ADR" and "ADR-0006" for those providers is: **this ADR covers the inventory row, the initial-provisioning walkthrough, and the operator-side tracking; ADR-0006 covers the post-issuance rotation into Key Vault.** When Vault.Rotation graduates from "portal runbook + manual KV write" to "provider-API-driven rotation" for Resend (or any other provider), the inventory row's `Rotation Procedure` field updates to point at the automated rotation; the inventory itself persists as the Grid's single source of "who has a credential and when does it expire."

**The inventory's broader scope per D2 does not pull non-rotating items into Vault.Rotation's responsibility.** This is the load-bearing clarification: the inventory is a **registry of what exists**, not a delegation of rotation duty. Non-rotating identifiers (`HIVE_APP_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, OIDC subject patterns, resource identifiers) live in the inventory with `Rotates: no` and have no rotation procedure, no standing rotation issue, and no escalation cadence — but they are *discoverable* there, which is the property the inventory exists to provide. Rotation responsibility stays where each item lives: Vault.Rotation rotates ADR-0006 Tier-2 secrets, this ADR's walkthroughs cover rotation-needing external-SaaS credentials, and non-rotating items have no rotation responsibility at all. Vault.Rotation's scope does not expand to anything else.

### D2 — Inventory location and shape: `infrastructure/reference/sensitive-inventory.md`

The canonical inventory lives at **`infrastructure/reference/sensitive-inventory.md`** (new file), alongside the existing reference documents (`vendor-inventory.md`, `azure-resource-inventory.md`, `deployment-map.md`, `owned-domains.md`, `tech-stack.md`).

**Filename choice.** Three candidate names were on the table during drafting:

- `external-credentials.md` — the original choice when scope was "rotation-needing tokens." Rejected after the broadening: the filename promises a narrower thing than the file holds. Non-rotating identifiers, OIDC subject patterns, resource identifiers, and webhook-secret slot names are not "external credentials" in the rotating-SaaS-token sense; keeping the name would be misleading on the first glance any agent or human gives the directory.
- `credentials-and-identifiers.md` — accurate but cumbersome; reads as a category-list, not a single registry.
- `secret-registry.md` — close, but "secret" mislabels half the contents (non-rotating IDs and resource identifiers are explicitly *not* secrets — they are public-or-internal identifiers that are operationally load-bearing).
- **`sensitive-inventory.md`** — chosen. "Sensitive" captures the union: things that are secret-valued, things that are identity-bearing, and things that are operationally load-bearing such that a lost or forgotten entry costs the Grid recovery time. "Inventory" frames the artifact correctly: an index of *what the Grid holds*, not a store of values.

**Scope.** The inventory is **the canonical index of every credential, identifier, secret, and identity binding the Grid holds**. The operator's framing: *"not the values but just that we have them."* Values continue to live in their authoritative location — GitHub organization secrets for CI-shaped credentials, Azure Key Vault for runtime workload secrets (governed by ADR-0006), environment configuration for non-rotating IDs, IaC for resource identifiers. The inventory is the **index** that makes the existence of each artifact discoverable; it never duplicates values.

**Rejected alternative: `catalogs/sensitive-inventory.json`.** Catalogs are JSON-shaped and consumed by tooling (`hive-sync`, the `review` agent, `node-audit`, grid-health aggregator). The inventory is consumed by **humans during rotation, onboarding, and incident response**, not by an automated agent making routing decisions. Markdown is the right surface — the human reads a table, follows a link to a rotation walkthrough, performs a portal action, updates the table. JSON would force an extra rendering layer with no consumer that benefits from structured queries. The drift-detection workflow per D5 parses the Markdown well enough for its needs.

**Rejected alternative: per-Node `infrastructure/reference/sensitive-inventory-{node}.md` files.** Inventory items don't cleanly partition by Node — `SONAR_TOKEN` is consumed by every public repo, `HIVE_APP_ID` is consumed by `hive-field-mirror.yml` and `refresh-hive-project-metadata.yml`, `AZURE_TENANT_ID` is consumed everywhere, the ADR-0044 webhook signing secret is consumed by the home-server-hosted OpenClaw bridge. A single Grid-wide table is the right granularity.

**Record shape (one row per inventory entry).** Every entry carries these columns:

| Column | Required | Notes |
|---|---|---|
| `Name` | yes | The artifact's canonical name — GitHub org secret name (`SONAR_TOKEN`, `HIVE_APP_ID`), environment variable name, Key Vault secret name, or descriptive identifier for things that don't have a stored "name" (e.g., an OIDC federated-credential configuration). |
| `Kind` | yes | One of: `external-saas-pat`, `external-saas-api-key`, `azure-key-vault-secret`, `azure-managed-identity`, `oidc-federated-credential`, `github-app-credential`, `webhook-signing-secret`, `non-rotating-id`, `resource-identifier`, `connection-string`. Drives downstream filtering (e.g., `external-credentials-check.yml` filters by `Rotates: yes`). |
| `Provider` | yes | The SaaS or platform issuing the artifact (SonarCloud, GitHub, Azure, Discord, NuGet, ...). |
| `Where Stored` | yes | GitHub org secret + the secret name; repo secret + repo + name; Vault + vault name + secret name; environment variable; IaC file path; or "operator-only (1Password)" for things that never enter a CI surface. |
| `Bound To` | yes | The principal — user account email, organization name, App Registration name, subscription ID, etc. Names *who* or *what* is on the hook when this artifact needs attention. |
| `Rotates` | yes | One of: `yes` (rotation governed by this ADR's procedure), `no` (non-rotating; rotate only on suspected compromise), or `automated-elsewhere` with a link to the governing ADR (e.g. `automated-elsewhere (ADR-0006 Tier 2)` for runtime-workload secrets governed by Vault.Rotation). |
| `Expiration Cadence` | optional | Provider-imposed maximum (`60 days` for SONAR_TOKEN free, `366 days` for GitHub fine-grained PATs). `n/a` for non-rotating entries. |
| `Current Expiration` | optional | The specific date the *current value* expires (ISO 8601 `YYYY-MM-DD`). Updated every rotation. `n/a` for non-rotating entries. |
| `Rotation Procedure` | optional | Relative link to the per-provider walkthrough under `infrastructure/walkthroughs/` (per D4). `n/a` for non-rotating entries and for `automated-elsewhere` entries that link to ADR-0006's surface. |
| `Use Cases` | yes | Bulleted list (inside the cell) of consumers and what the artifact enables them to do. Answers "what is this USED FOR?" — e.g., for `NUGET_API_KEY`: "publish HoneyDrunk packages to nuget.org from `HoneyDrunk.Actions/release.yml` invocations across all NuGet-shipping Nodes per ADR-0034." For `HIVE_APP_ID`: "GitHub App authentication for `hive-field-mirror.yml` and `refresh-hive-project-metadata.yml` per ADR-0014." |
| `Blast Radius if Missed` | yes | One sentence: what breaks when this artifact is misconfigured, expired (where applicable), or lost. Failure-mode framing, distinct from `Use Cases` which is the positive workflow-consumer framing. |
| `Owner` | yes | Solo-dev today (single name); future-proofs as the team grows. |
| `Notes` | optional | Free-form. Captures odd-shaped facts: "60-day cap on free tier" for `SONAR_TOKEN`, "App Insights connection string is non-rotating; instrumentation-key revocation is the security path," "planned — not yet provisioned," etc. Also the home for `status: planned` style flags for forward-looking entries. |

**Rejected fields.** No "rotation reminder set" boolean — that's tracked separately in D3, and duplicating it in the inventory invites drift. No "last rotated" column — `Current Expiration` already encodes that information backward through the cadence (and is `n/a` for non-rotating entries where it doesn't apply). No "criticality tier" — `Blast Radius if Missed` carries the same information in prose form without forcing a forced ranking.

**One summary row, not per-secret rows, for Azure Key Vault contents.** Every individual Key Vault secret governed by ADR-0006 is *not* given its own inventory row. The inventory carries **one summary row per Vault** (e.g., `kv-hd-notify-prod`) with `Kind: azure-key-vault-secret`, `Rotates: automated-elsewhere (ADR-0006)`, and a `Use Cases` cell that lists the consumer Nodes. Per-secret detail lives in the Vault inventory that ADR-0006 owns; duplicating it here would invite drift and triple the maintenance cost without adding signal.

### D3 — Tracking surface: GitHub issues with due dates, **not** calendar reminders.

(An in-flight ADR — [ADR-0084](./ADR-0084-discord-operator-alerts-surface.md) *Discord as the Canonical Operator-Alerts Surface* — adds Discord webhook alerts as the **escalation** surface for the T-30 / T-7 / T+0 cadence below. That ADR will amend this D3 in its own follow-up packet. **This revision deliberately does not preempt that change** — GitHub issues remain the canonical tracking surface in this ADR, and the Discord escalation channel composes on top via ADR-0084's `job-discord-notify.yml` seam once ADR-0084 lands.)

Every rotation-needing credential in the inventory (rows with `Rotates: yes`) carries a **standing GitHub issue** in `HoneyDrunk.Architecture` labeled `external-credential-rotation` with the title shape `[Rotate] {credential-name} — expires {YYYY-MM-DD}`. The issue body links to the inventory row and the rotation walkthrough. The issue is **closed on rotation**, and a new issue is opened immediately with the new expiration date in the title. Non-rotating inventory entries (rows with `Rotates: no` or `Rotates: automated-elsewhere`) do **not** get standing issues — there is nothing to escalate to.

**Why GitHub issues, not calendar reminders:**

- **Discoverability vs in-your-face — issues win both.** A calendar reminder fires once and disappears; an open issue sits in the org's issue list every time the operator opens GitHub for any reason. The "30 days from now" reminder shows up in a place the operator already is, not in a place (Calendar, email) that's easy to swipe away or filter out.
- **Audit trail.** Closed rotation issues are a permanent record of when each credential was last rotated and by whom. Calendar history is operator-local and not portable across devices/accounts.
- **Aligns with the rest of the Grid.** Per Invariant 23, every tracked work item has a GitHub Issue in its target repo. External-SaaS rotation is tracked work; tracking it the same way as every other tracked Grid action keeps one disciplined surface.
- **Visible to AI agents.** The `node-audit` agent (per ADR-0043's Tactical source) can walk open issues with the `external-credential-rotation` label and surface "rotation due in 30 days" findings in the weekly briefing per ADR-0043 D5. A calendar reminder is invisible to every agent on the Grid.

**Reminder cadence.** The issue is opened **at rotation time** with the new expiration date in the title and body. A second comment is posted on the issue at the **T-30-day** mark by a scheduled HoneyDrunk.Actions workflow (per D6) that pings the operator and re-applies the `urgent` label. T-7-day produces an additional comment and adds the `imminent` label. Past expiration produces a SEV-2 incident record per ADR-0054.

**Calendar reminders are not forbidden.** The operator is free to mirror the GitHub issue into their personal calendar if useful — but the calendar is a secondary surface, not the source of truth.

### D4 — Per-provider rotation walkthroughs live in `infrastructure/walkthroughs/`, one per rotation-needing provider.

Following the existing convention (`sonarcloud-organization-setup.md`, `key-vault-creation.md`, `oidc-federated-credentials.md`, etc.), every **rotation-needing** inventory entry (rows with `Rotates: yes`) has a **per-provider portal walkthrough** under `infrastructure/walkthroughs/`. Non-rotating entries (`Rotates: no`) and `automated-elsewhere` entries do **not** require walkthroughs — there is no rotation flow to document. The walkthrough is the rotation procedure: portal breadcrumb, step-by-step instructions, where to paste the new value, verification steps, and the inventory-update step.

The three mandatory first-wave walkthroughs unblocked by acceptance of this ADR (first follow-up packets) — all three cover credentials in active production use today:

- **`sonarcloud-token-rotation.md`** — rotates `SONAR_TOKEN` against the SonarQube Cloud free plan's 60-day cap. Covers: log in as the org admin → User → My Account → Security → revoke old token → generate new token with the same scopes → copy value → GitHub org secrets → update `SONAR_TOKEN` → verify against an open PR's SonarCloud check → close the standing rotation issue → open a new one with the new expiration date → update `infrastructure/reference/sensitive-inventory.md`.
- **`nuget-api-key-rotation.md`** — rotates `NUGET_API_KEY` against NuGet.org's 365-day Personal API Key cap. Covers: log in as the org admin → `nuget.org/account/apikeys` → create a new API key with the same `HoneyDrunk.*` package glob and the same scopes (Push new packages and package versions) → copy value → GitHub org secrets → update `NUGET_API_KEY` → delete the old key from `nuget.org/account/apikeys` → verify against the next `release.yml` invocation (or trigger a no-op publish smoke test) → close the standing rotation issue → open the next → update the inventory.
- **`github-pat-rotation.md`** — rotates GitHub fine-grained PATs (today: `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`, and any future PATs that aren't replaced by GitHub Apps). Covers: GitHub → Settings → Developer settings → Personal access tokens → Fine-grained → Regenerate the existing token with the same scopes → copy value → update destination (GitHub org secret or repo secret) → smoke-test → close the standing rotation issue → open the next → update the inventory.

Additional walkthroughs land as new external-SaaS providers are adopted (per the D6 onboarding hook). When PDR-0002 ships, `stripe-api-key-rotation.md` and `resend-api-key-rotation.md` (initial provisioning, since the in-Vault rotation is ADR-0006's responsibility) and `twilio-api-key-rotation.md` (same) join the set. The naming pattern is `{provider-or-credential}-rotation.md` for rotation flows and `{provider}-organization-setup.md` for first-time setup; this matches the existing walkthrough convention.

### D5 — Failure mode: drift-detection workflow at T-30, T-7, T+0.

A new scheduled workflow in `HoneyDrunk.Actions`, **`external-credentials-check.yml`** (cron: daily 09:00 ET), parses `infrastructure/reference/sensitive-inventory.md`, **filters by `Rotates: yes`** (rows with `Rotates: no` and `Rotates: automated-elsewhere` are skipped — they have no expiration to compute against), computes days-to-expiry for each remaining row, and:

- **T-30 days or fewer:** comments on the open rotation issue (or opens one if missing), applies the `urgent` label.
- **T-7 days or fewer:** comments again, applies the `imminent` label.
- **T+0 (past expiration):** files a **SEV-2 incident record** per ADR-0054 in `generated/incidents/{YYYY-MM-DD}-{credential}-expired.md` and emits an Operator approval-gate-shaped notification per ADR-0019 → ADR-0073 (operator's notification channel).

The workflow is **drift-detection only** — it does not call provider APIs to fetch live expiration data. The inventory is the source of truth; the workflow reads each `Rotates: yes` row's `Current Expiration` field and computes against `TimeProvider.GetUtcNow()` per ADR-0063. This is the cheapest possible expiration tracker — it requires no provider API integration, no auth, no rate-limit handling, no provider-specific code.

**Rejected alternative: provider-API-driven drift detection.** A workflow that calls SonarCloud's API to fetch the *real* expiration of `SONAR_TOKEN` and alerts on drift between provider state and inventory state. Rejected for the same reason D1 rejects automated rotation: per-provider engineering scaling with provider count, against fewer than ten total credentials. The cheap version catches the actual failure mode (operator forgets to update the inventory after a rotation, expiration sneaks up) without per-provider integration.

**Silent breakage is no longer the failure mode after this ADR.** Before this ADR: SONAR_TOKEN expires, SonarCloud check just stops posting on PRs, the operator notices weeks later. After this ADR: the T-30 issue comment fires 30 days before expiry, the T-7 fires 7 days before, the T+0 incident fires the day of, and the SonarCloud check stopping is the **fourth** signal, not the first.

### D6 — Onboarding hook: standup procedure (ADR-0082) extends to external-SaaS credentials.

When a new external-SaaS provider is adopted — Stripe per PDR-0002, Resend / Twilio per ADR-0073, any future SaaS the Grid integrates with — the **standup procedure per ADR-0082** gains a credential-onboarding step.

Specifically, ADR-0082 D5 (the class-specific steps) is extended with a new mandatory step for any Node whose standup introduces a new external-SaaS provider or a new sensitive-inventory artifact:

> **Sensitive-inventory onboarding.** If the Node's standup introduces any artifact governed by ADR-0083's inventory (an external-SaaS credential, a non-rotating identifier, a webhook signing secret, an OIDC federated-credential configuration, a resource identifier, or any other entry in the D2 `Kind` taxonomy) that does not already appear in `infrastructure/reference/sensitive-inventory.md`, the standup packet must, before the artifact enters any CI surface or workflow file:
>
> 1. Add a row to `infrastructure/reference/sensitive-inventory.md` per ADR-0083 D2, including the `Kind`, `Use Cases`, and `Rotates` columns.
> 2. If `Rotates: yes`: land the per-provider rotation walkthrough under `infrastructure/walkthroughs/{provider}-{credential}-rotation.md` per ADR-0083 D4 and open the initial standing rotation issue with the `external-credential-rotation` label per ADR-0083 D3.
> 3. If `Rotates: yes`: verify the artifact's `Current Expiration` date is picked up by `external-credentials-check.yml` on its next scheduled run.
> 4. If `Rotates: no` or `Rotates: automated-elsewhere`: no walkthrough or standing issue is required — the inventory row itself is the deliverable.

This step lands as an amendment to ADR-0082's D5 in the same packet that lands `constitution/node-standup.md` per ADR-0082's D7 follow-up work. The cross-reference is recorded here; ADR-0082's text is not edited directly (Accepted-ADR discipline), but its follow-up document — the canonical procedure — picks up this step.

**The inventory row exists before the integration ships.** This is the load-bearing rule: a new artifact does not enter a workflow file, a repo secret, an org secret, or an environment variable consumed by the Grid until its inventory row exists (and, for rotation-needing items, its walkthrough and standing issue exist). The procedural enforcement is the `review` agent per ADR-0044 D3 rubric category 9 (Security — secret handling, rotation support per ADR-0006/0083). Any PR that introduces a workflow consuming a new GitHub org secret, repo secret, or environment variable without a matching inventory row is a `Request Changes` finding.

### D7 — Invariant candidate: every credential, identifier, or load-bearing identity binding the Grid holds has an inventory row; rotation-needing items additionally carry a walkthrough and standing tracking issue.

The invariant is a single clause with two bound parts — a broader inventory-membership rule that covers everything the Grid holds, and a narrower rotation-discipline rule that applies only to the rotation-needing subset. Both parts land together; the rotation-specific clause is preserved (not weakened) from the pre-broadening draft.

A new invariant is added to `constitution/invariants.md` with this exact wording:

> **Every credential, identifier, secret, or load-bearing identity binding the Grid holds — including but not limited to GitHub Personal Access Tokens, GitHub App IDs and private keys, SonarCloud tokens, NuGet API keys, Azure subscription and tenant IDs, OIDC federated-credential configurations, webhook signing secrets, Discord webhook URLs, Stripe / Resend / Twilio API keys, resource identifiers (Key Vault names, Container Apps environments, Service Bus namespaces), and any provider-issued artifact whose loss, exposure, or expiration would cost the Grid recovery time — must have a row in `infrastructure/reference/sensitive-inventory.md` with the columns specified in ADR-0083 D2, including `Kind`, `Use Cases`, and `Rotates`.**
>
> **Additionally, for inventory rows with `Rotates: yes`**, the row must also carry:
> 1. **a `Current Expiration` date** no later than the provider's enforced maximum,
> 2. **a per-provider rotation walkthrough** at `infrastructure/walkthroughs/{provider-or-credential}-rotation.md` linked from the `Rotation Procedure` column, and
> 3. **an open GitHub issue** in `HoneyDrunk.Architecture` labeled `external-credential-rotation` with the credential name and current expiration date in its title.
>
> Artifacts whose rotation lifecycle is fully managed by `HoneyDrunk.Vault.Rotation` (ADR-0006 Tier 2 — runtime workload secrets resolved through `ISecretStore`) carry `Rotates: automated-elsewhere (ADR-0006)`; the inventory row remains required, but the rotation-discipline triplet (walkthrough, standing issue, escalation) is out of scope of this invariant for those rows — they are governed by Invariant 20. The inventory entry persists because the inventory's job is "what the Grid holds and where," not "is rotation automated yet."
>
> Non-rotating identifiers (`Rotates: no`) — non-expiring IDs, OIDC subject patterns, resource identifiers, Discord webhook URLs and similar — require **only** the inventory row, no walkthrough and no standing issue.
>
> Enforcement: human review at PR time, supplemented by the `review` agent per ADR-0044 D3 category 9 (Security). The scheduled `external-credentials-check.yml` workflow per ADR-0083 D5 catches `Rotates: yes` rows whose expiration has lapsed without an updated value, and surfaces them as SEV-2 incidents per ADR-0054. The `node-audit` agent surfaces missing rows of any `Kind` on its periodic pass.

The exact invariant number is assigned at acceptance by the scope agent, claiming the next free block in `constitution/invariant-reservations.md` (currently `102` as of 2026-05-25; the scope agent re-checks at acceptance time).

This invariant **complements, does not replace, Invariant 20**. Invariant 20 binds the rotation SLA for secrets in Azure Key Vault tiers; this invariant binds the inventory-and-tracking discipline for everything else the Grid holds — credentials outside the Vault, non-rotating identifiers, OIDC bindings, and resource identifiers. Together they cover the full surface of sensitive and load-bearing artifacts the Grid depends on, regardless of storage backend or rotation cadence.

## Consequences

### Positive

- **No more silent CI degradation from expired PATs.** The T-30 / T-7 / T+0 escalation in D5 surfaces every expiration before the consuming workflow breaks.
- **The Grid acquires an honest inventory of everything it holds.** Today's answer to "what credentials, identifiers, and identity bindings does the Grid depend on?" is "go grep the codebase, look at GitHub org secrets, ask the operator, hope nothing was forgotten." After this ADR, the answer is "read `infrastructure/reference/sensitive-inventory.md`." The lottery-bus-factor failure mode — a load-bearing artifact that exists but is undocumented and unrecoverable without the operator — is closed.
- **AI agents can reason about external-credential discipline.** The `review` agent, `node-audit` agent, and `hive-sync` agent all gain a structured surface to check against. ADR-0044 D3 category 9 (Security — Secret handling) and category 10 (Enterprise readiness — Operational maturity) gain a concrete inventory to evaluate PRs against.
- **The onboarding hook in D6 closes the "imminent Stripe / Resend / Twilio" gap before PDR-0002 ships.** New providers cannot land without their inventory row, walkthrough, and rotation issue.
- **Vault.Rotation's scope stays clean.** ADR-0006's Tier 2 covers runtime workload secrets; this ADR covers CI/ops machinery credentials; neither boundary is muddied.

### Negative

- **The discipline depends on the operator maintaining the inventory.** If the `Current Expiration` field drifts from reality (operator rotates but forgets to update the row), the T-30 / T-7 / T+0 schedule fires against stale dates. Mitigation: D4's rotation walkthroughs each end with an explicit "update the inventory row" step, and the `node-audit` agent's periodic pass walks the inventory.
- **One more constitutional document to maintain — but a richer one.** `infrastructure/reference/sensitive-inventory.md` joins the reference set. The broadening per the operator's framing means more rows than the original "rotation-needing only" scope (roughly 15–20 rows at seed time vs the original 8). Maintenance cost is still bounded — most non-rotating rows are write-once-read-many and only need touching when a referenced resource is renamed or retired.
- **The new invariant is procedurally enforced, not CI-enforced.** Per D7, enforcement lives in human review + the `review` agent + `external-credentials-check.yml` + `node-audit`. A cross-repo CI gate that fails another repo's PR for missing an inventory row in Architecture is out of scope. Accepted as the deliberate scope cut — the four enforcement layers are sufficient at solo-developer + AI-agent scale.
- **Manual rotation indefinitely is real ongoing operator load.** D1's "no automated rotation Node" is the cost-disciplined call today, but it does mean four-to-six rotation events per year (60-day SonarCloud cap plus ~yearly GitHub PATs plus ~yearly provider API keys for Stripe / Resend / Twilio once they land). Re-evaluation trigger: if the active rotation-needing-credential count exceeds ten, or if a single high-blast-radius credential rotates more than every 30 days, this ADR is revisited.
- **`external-credentials-check.yml` parses Markdown.** Workflow brittleness against table-format edits is a real concern; the workflow includes a schema-check step that fails fast if the table shape drifts. The schema check is part of the workflow's follow-up work below. Per D5 the workflow filters by `Rotates: yes` and ignores other rows, so adding non-rotating entries to the inventory does not expand its surface.

### Affected Nodes

- **`HoneyDrunk.Architecture`** — primary affected Node; new `infrastructure/reference/sensitive-inventory.md`, new walkthroughs under `infrastructure/walkthroughs/`, new invariant in `constitution/invariants.md`, new standing-issue label in the repo's label set.
- **`HoneyDrunk.Actions`** — new scheduled `external-credentials-check.yml` workflow per D5. New label seeding for `external-credential-rotation`, `urgent`, `imminent` if not already present.
- **`HoneyDrunk.Vault.Rotation`** — explicitly **unchanged**. Its scope per ADR-0006 Tier 2 stays as-is. The Resend / Twilio / Stripe API keys it rotates *post-issuance* are referenced from inventory rows but not stored or rotated by this ADR's machinery.
- **Every Grid repo that consumes a GitHub org secret or repo secret backing an external-SaaS credential** — no code change, but the credential's inventory row must exist before its consuming workflow is allowed to land. Enforced procedurally per D6 and per D7's invariant.

### Cascade Impact

- `infrastructure/reference/sensitive-inventory.md` lands as a new file via the first follow-up packet, seeded with the rows enumerated in Follow-up Work below (roughly 15–20 rows depending on which planned-but-not-live entries are deferred).
- `infrastructure/walkthroughs/sonarcloud-token-rotation.md`, `infrastructure/walkthroughs/nuget-api-key-rotation.md`, and `infrastructure/walkthroughs/github-pat-rotation.md` land as separate follow-up packets (parallelizable). Non-rotating inventory entries do **not** require walkthroughs.
- `HoneyDrunk.Actions/.github/workflows/external-credentials-check.yml` lands as a follow-up packet, with the schema-check sub-step and the `Rotates: yes` filter per D5.
- `constitution/invariants.md` gains the D7 invariant (number assigned at acceptance) via the same packet that lands the inventory file.
- `constitution/invariant-reservations.md` gains the ADR-0083 reservation row (block of 1).
- `adrs/README.md` gains the ADR-0083 row when this ADR flips Accepted.
- `infrastructure/reference/vendor-inventory.md` is **not edited** by this ADR — vendor inventory is product-level ("which SaaS products do we use"); the sensitive inventory is artifact-level ("which credentials, identifiers, and identity bindings do we hold against each product, plus everything else load-bearing"). The two files cross-reference each other.
- **No code changes in any Node repo.** This ADR is process architecture for the Grid's operational machinery.

### Cross-references to existing ADRs

- **ADR-0005** — unchanged. The env-var-driven Vault bootstrap (`AZURE_KEYVAULT_URI`) does not cover GitHub org secrets and was never meant to; this ADR fills the gap deliberately.
- **ADR-0006** — unchanged. Vault.Rotation scope stays Tier 1 / Tier 2 against Azure Key Vault. This ADR explicitly does not expand it.
- **ADR-0011** — SONAR_TOKEN is the immediate forcing function. The ADR-0011 acceptance pass's sonarcloud-organization-setup walkthrough cross-references `infrastructure/walkthroughs/sonarcloud-token-rotation.md` once the latter lands.
- **ADR-0034** — NuGet Publishing. `NUGET_API_KEY` has been in production use longer than any other external-SaaS credential; this ADR retroactively documents and disciplines its rotation. `infrastructure/walkthroughs/nuget-api-key-rotation.md` lands alongside the SonarCloud and GitHub-PAT walkthroughs as the third mandatory first-wave follow-up. NuGet.org's API for key management is acknowledged but explicitly out of scope per D1.
- **ADR-0044** — names a webhook signing secret and a GitHub App private key, both external-SaaS-shaped credentials. Both get inventory rows in the first follow-up packet.
- **ADR-0080** — vendor-posture taxonomy applies. SonarCloud / GitHub / Stripe / Resend / Twilio are all **Accept** or **Hedge** posture; their PATs are operational tax of that posture. The "Accept" posture's "exit measured in months" property is exactly what permits manual rotation indefinitely under D1.
- **ADR-0082** — the standup procedure ADR drafted alongside this one. The D6 onboarding hook lands in the canonical procedure document `constitution/node-standup.md` per ADR-0082's D7 follow-up work, not in the ADR-0082 ADR body itself.
- **PDR-0002 (Notify Cloud commercial trial)** — Stripe / Resend / Twilio key onboarding is gated on this ADR's inventory and walkthrough machinery existing first.
- **Invariant 8** (secrets never appear in logs/traces) — fully preserved. The inventory carries credential *names* and *expiration dates*, never values.
- **Invariant 20** (no secret may exceed its tier's rotation SLA without an active exception) — complementary, not amended. Invariant 20 binds Vault-stored secrets; this ADR's new invariant binds external-SaaS credentials stored outside the Vault.

### Follow-up Work

None of the following is part of this ADR. Each is discrete follow-up scoped via the `scope` agent after acceptance.

- **Author `infrastructure/reference/sensitive-inventory.md`** with the seed rows below. The seed split is "live or imminent" (lands at acceptance) vs "planned" (lands with the consuming ADR's acceptance — e.g., Discord rows land with ADR-0084, Notify-Cloud commercial rows land with PDR-0002). Total seed-row count at this ADR's acceptance: **15 rows** (the live/imminent set). The planned set adds another 10 rows as their consuming ADRs land.

  **Live or imminent (15 rows — seeded at ADR-0083 acceptance):**
  - `SONAR_TOKEN` — `Kind: external-saas-pat`, `Rotates: yes`, 60-day cap (free tier).
  - `NUGET_API_KEY` — `Kind: external-saas-api-key`, `Rotates: yes`, 365-day cap.
  - `GH_ISSUE_TOKEN` — `Kind: external-saas-pat`, `Rotates: yes`, fine-grained PAT.
  - `HIVE_APP_ID` — `Kind: non-rotating-id`, `Rotates: no`, GitHub App ID used by `hive-field-mirror.yml` and `refresh-hive-project-metadata.yml` per ADR-0014.
  - `HIVE_APP_PRIVATE_KEY` — `Kind: github-app-credential`, `Rotates: no` (rotate-on-compromise only, no calendar), GitHub App private key paired with `HIVE_APP_ID`.
  - `HIVE_FIELD_MIRROR_TOKEN` — `Kind: external-saas-pat`, `Rotates: yes`, live PAT used by `hive-field-mirror.yml` fallback path.
  - `LABELS_FANOUT_PAT` — `Kind: external-saas-pat`, `Rotates: yes`, live PAT used by `seed-labels-fanout.yml`.
  - `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` — `Kind: webhook-signing-secret`, `Rotates: yes`, per ADR-0044 D2; retired under ADR-0088 after OpenClaw decommission.
  - `AZURE_TENANT_ID` — `Kind: non-rotating-id`, `Rotates: no`, used across every Azure-touching workflow.
  - `AZURE_SUBSCRIPTION_ID` — `Kind: non-rotating-id`, `Rotates: no`, used across every Azure-touching workflow.
  - OIDC federated-credential configurations per repo — `Kind: oidc-federated-credential`, `Rotates: no`; one row summarizing the pattern with a link to the per-repo subject-pattern documentation rather than one row per repo.
  - Application Insights connection strings — `Kind: connection-string`, `Rotates: no` (non-rotating; instrumentation-key revocation is the security path, captured in `Notes`).
  - **Summary row: Azure Key Vault contents** — `Kind: azure-key-vault-secret`, `Rotates: automated-elsewhere (ADR-0006)`. Single summary row pointing at ADR-0006's Vault inventory rather than one row per Key Vault secret, per the D2 carve-out.
  - `ANTHROPIC_API_KEY` — `Kind: external-saas-api-key`, `Rotates: yes`, status `planned` in `Notes` (declared input to `agent-run.yml`, not yet live).
  - `OPENAI_API_KEY` — `Kind: external-saas-api-key`, `Rotates: yes`, status `planned` in `Notes` (declared input to `agent-run.yml`, not yet live).

  **Planned (deferred to the relevant consuming ADR's acceptance packet, not seeded here):**
  - Seven `DISCORD_WEBHOOK_*` rows per ADR-0084 (`Kind: webhook-signing-secret`, `Rotates: no` per ADR-0084 D4 — webhook URLs are non-expiring, rotate-on-compromise only). Seeded by the ADR-0084 first follow-up packet, not this ADR's.
  - Discord guild ID — `Kind: non-rotating-id`, `Rotates: no`. Seeded with ADR-0084.
  - `STRIPE_API_KEY`, `RESEND_API_KEY`, `TWILIO_API_KEY` — seeded with PDR-0002 acceptance (initial provisioning is this ADR's scope; post-issuance rotation into `kv-hd-notify-{env}` is ADR-0006's scope).

- **Author the mandatory first-wave per-provider rotation walkthroughs** — these three cover the rotation-needing credentials in active production use today and land first:
  - `infrastructure/walkthroughs/sonarcloud-token-rotation.md` — unblocks the ADR-0011 acceptance pass.
  - `infrastructure/walkthroughs/nuget-api-key-rotation.md` — covers `nuget.org/account/apikeys` → create new key with the `HoneyDrunk.*` glob → copy to GitHub org secret `NUGET_API_KEY` → delete old key → smoke-test against an open release PR → close the standing rotation issue → open the next.
  - `infrastructure/walkthroughs/github-pat-rotation.md` — covers fine-grained PATs (today: `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`).

  Walkthroughs are authored **only for rotation-needing entries** (`Rotates: yes`). Non-rotating entries and `automated-elsewhere` entries are intentionally walkthrough-less — there is no rotation flow to document. The OpenClaw webhook-secret walkthrough later landed and was retired under ADR-0088 when the credential was deleted; `anthropic-api-key-rotation.md` and `openai-api-key-rotation.md` land when those credentials go live.

- **Author `HoneyDrunk.Actions/.github/workflows/external-credentials-check.yml`** — scheduled drift-detection workflow per D5, with the Markdown-table-schema-check sub-step and the `Rotates: yes` row filter.
- **Add the `external-credential-rotation`, `urgent`, `imminent` labels** to the `HoneyDrunk.Architecture` repo's label set via the existing label-setup pattern.
- **Open the initial standing rotation issues** for the rotation-needing subset of seeded entries (the subset where `Rotates: yes`), one issue per credential, labeled and dated correctly. Non-rotating entries get no standing issue.
- **Amend `constitution/node-standup.md`** (the canonical procedure document landed by ADR-0082) to incorporate the D6 onboarding hook step. This is an edit to the procedure document — not an amendment to ADR-0082's body.
- **Add the new invariant** to `constitution/invariants.md` with the number claimed from `constitution/invariant-reservations.md`.
- **Cross-reference this ADR from `HoneyDrunk.Vault.Rotation/overview.md`** — note that external-SaaS PAT rotation is deliberately out of scope, governed by ADR-0083, and that the sensitive inventory carries a summary row for the Vault contents that Vault.Rotation governs.
- **Update `infrastructure/reference/vendor-inventory.md`** to cross-link to `sensitive-inventory.md` for each vendor whose artifacts the Grid holds.

## Alternatives Considered

### Expand Vault.Rotation to cover external-SaaS PATs

The most architecturally satisfying option on paper: one rotation Node handles every credential-rotation concern across the Grid, regardless of storage backend. Rejected per D1 on cost grounds. Each new provider adds a per-provider rotation integration (GitHub API, SonarCloud API, Stripe API, Resend API, Twilio API) with its own auth model, rate limits, and deprecation cadence. At fewer than ten active external-SaaS credentials, the maintenance bill of N provider integrations dominates the cost of manual rotation with disciplined inventory. Re-evaluate if the active-credential count exceeds ten or if rotation frequency increases.

### `catalogs/sensitive-inventory.json` instead of Markdown

Considered. JSON gives structured queries and a tooling-friendly surface. Rejected because the inventory is consumed by humans during rotation, onboarding, and incident response, not by automated agents making routing decisions. Markdown is the right surface — the human reads a table, follows a link, performs a portal action, updates the table. JSON would force an extra rendering layer with no consumer that benefits from structured queries. The Markdown file is parseable enough for `external-credentials-check.yml` (per D5) without becoming a tooling-first surface.

### Keep the narrow `external-credentials.md` filename and scope

Considered (the pre-broadening draft of this ADR). Rejected after the operator's framing during drafting: a narrow-scoped file leaves the lottery-bus-factor failure mode unaddressed for non-rotating IDs, OIDC bindings, webhook-secret slot names, and resource identifiers. The broadened scope per D2 and the renamed file (`sensitive-inventory.md`) costs marginal maintenance and acquires a much larger property — a single discoverable index for "what does the Grid hold?" The narrow scope would have required either a second inventory file (duplicate machinery) or accepting that the lottery-bus-factor risk goes uncovered (the larger of the two failure modes the operator named).

### Calendar reminders only, no GitHub issues

Considered. Lower discipline cost than maintaining standing issues. Rejected per D3 on three grounds: (a) calendar reminders fire once and disappear, GitHub issues sit in the operator's daily field of view; (b) closed rotation issues are a permanent audit trail, calendar history is operator-local; (c) AI agents (`node-audit`, the weekly briefing per ADR-0043) can walk open issues but cannot see the operator's calendar.

### Nightly provider-API drift-detection job

Considered. Calls each provider's expiration API (where one exists) and alerts when within 30 days of expiry. Rejected on cost: per-provider engineering scaling with provider count, against fewer than ten total credentials. The cheap version per D5 (parse the inventory's `Current Expiration` field, compute against now) catches the actual failure mode (operator forgets to update the inventory after a rotation) without per-provider integration. The expensive version would *also* catch the case where the inventory says 60 days from now but the provider has already invalidated the token via a separate UI action; that case is rare enough at solo-dev scale that the engineering cost is not justified.

### Accept silent CI breakage as the failure signal

Considered. Don't track expirations at all; let `job-sonarcloud.yml` fail loudly when SONAR_TOKEN expires, treat that as the rotation reminder. Rejected because (a) the failure isn't loud — SonarCloud's check just doesn't post on PRs, which the operator might not notice for days or weeks; (b) the failure mode for non-Sonar credentials is worse (Stripe API key expiry mid-billing-cycle is a paying-tenant impact, not a quiet CI degradation); (c) the discipline cost of "open one issue, update one row" is small enough that paying it for every credential is cheap insurance against the worst-case failure modes.

### Inventory in a private repo

Considered. The inventory contains the *names* of secrets and their *binding identities*, neither of which is itself a secret. But there's a "soft" exposure question: should the Grid publicly advertise which SaaS providers it has admin-bound credentials with? Rejected — the Grid is public-by-default (per the standing memory and ADR-0027 D2 carve-out), the inventory names credentials and identities not values (Invariant 8 fully preserved), and the existing public-vs-private posture for `infrastructure/reference/*.md` files keeps inventory metadata public alongside `vendor-inventory.md`, `tech-stack.md`, and the Azure resource inventory. Moving this inventory to a private repo would break the cross-link pattern and undermine the "single source of truth" property.

### Defer until first SONAR_TOKEN expiry

Considered. Wait until the first 60-day SonarCloud rotation forces the issue, then write the ADR. Rejected on the same grounds ADR-0082 was drafted now rather than deferred: the gap is real today, the cost of writing the ADR is low, the cost of a missed rotation on a credential that gates ADR-0011's third-party static analysis on every public-repo PR is meaningfully high (a code-review-gate regression on every PR for days or weeks), and the upcoming PDR-0002 / ADR-0073 rollouts add more external-SaaS credentials immediately. Industrialize the cheap process change before it has to be justified under fire.
