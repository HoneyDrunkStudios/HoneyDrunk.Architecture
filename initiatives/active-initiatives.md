# Active Initiatives

Tracked initiatives currently in progress or planned. Completed and cancelled initiatives live in [archived-initiatives.md](archived-initiatives.md). For the ranked priority order across all work, see [current-focus.md](current-focus.md).

## In Progress

### HoneyHub v1 — Agent Cockpit Standup + Phase 2
**Status:** In Progress — Phase A registration started; active packet set filed under `generated/issue-packets/active/honeyhub-v1/`
**Scope:** Architecture (catalog/context registration), Actions (`repo-to-node.yml` mapping), and **HoneyDrunk.HoneyHub** (NEW — React/Vite PWA + Tauri-class shell + Rust bridge workspace)
**Initiative:** `honeyhub-v1`
**Program:** [HoneyHub](programs/honeyhub.md)
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.HoneyHub` as the Agent Cockpit Node per ADR-0091: a `studios-typescript-native` workspace with one shared React PWA, a Tauri-class desktop shell, and a Rust local runner bridge. Phase 2 then implements the bridge core, pairing and allowlists, the first backend adapter (`claude.local`), local-first DispatchSession storage, state-only notifications, and the minimal run screen. PDR-0009's internal read layer remains a later HoneyHub layer; v1 is the free local cockpit per PDR-0011.

**Tracking (honeyhub-v1 packets):**
- [ ] **Wave 1 — Architecture packet 01:** Register `honeydrunk-honeyhub` in catalogs, sector map, grid-health, roadmap, active initiatives, and `repos/HoneyDrunk.HoneyHub/`.
- [ ] **Wave 2 — Human packet 02:** Reconcile GitHub repo settings, branch protection on `pr / build`, labels, local clone, and ADR-0086 runner-host enablement.
- [ ] **Wave 3 — HoneyHub packet 03 + Actions packet 10:** Scaffold the mixed TypeScript/Rust workspace, add the Actions repo-to-node mapping, and add shared Actions TypeScript/Rust reusable jobs consumed by HoneyHub.
- [ ] **Wave 4 — HoneyHub packets 04/05:** Bridge core plus pairing and allowlists.
- [ ] **Wave 5 — HoneyHub packets 06/07:** Claude Code adapter plus local store and notifications.
- [ ] **Wave 6 — HoneyHub packet 08:** Minimal run screen; first shippable Phase 2 slice.
- [ ] **Wave 7 — HoneyHub packet 09:** Phase 3+ outline tracking for Codex/Copilot, routing, coaching, packaging, and relay.

> **Sync (2026-06-07):** Local `HoneyDrunk.HoneyHub` repo exists with only the main branch ruleset reported by the operator. Architecture registration is being reconciled first so subsequent scaffold and mapping work has a Node identity.


### ADR-0077 Infrastructure-as-Code — Bicep (amended 2026-06-02)
**Status:** In Progress — ADR-0077 Accepted (amended); re-cut packets filed (Arch #571–575, Actions #122/#187); START sequence underway
**Scope:** Architecture (acceptance, invariants 90/91/92, new-Node registration, Actions-pipeline catalog edit, scaffold pattern, import playbook) + Actions (deploy + lint reusable workflows) + **HoneyDrunk.Infrastructure** (NEW — all Bicep content: `modules/` + `platform/` + `nodes/`)
**Initiative:** `adr-0077-iac-bicep`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Commit **Bicep** as the canonical IaC tool for every Azure resource the Grid provisions, with a per-concern modularization strategy, naming/tagging linter rules (D3), per-environment parameter files (D4), secrets-by-URI discipline (D7), an Azure-deep vendor posture (D5), and grandfather/opportunistic-import (D6). **Amended 2026-06-02:** all Bicep *content* consolidates into the new `HoneyDrunk.Infrastructure` repo (`modules/` + `platform/` + `nodes/`); the cross-repo module registry (`acrhdbicep`, `bicep-publish.yml`, `modules/v*` tag-publish, `br:` refs) is dropped in full (modules consumed by local relative path); the deploy/lint *pipeline* stays in `HoneyDrunk.Actions` per ADR-0012; infra deploys decouple from app release tags; **invariant 35 unchanged** (no `acrhdbicep` carve-out — registry dropped). The amendment adds a `platform/` first-class home for shared/foundational resources.

**Tracking (post-amendment packets 07 + 10–18; superseded originals 00–06/08/09):**
- [x] **Wave 1 — Arch #575** (packet 18): Accept ADR-0077 (amended), claim invariant block 90–92, add IaC invariants, register the initiative. **Do NOT amend invariant 35.** *(This entry is the registration that packet calls for.)*
- [ ] **Wave 1 — Arch #571** (packet 10): Register `HoneyDrunk.Infrastructure` as a new Grid Node (catalogs + routing + sectors + five-file context folder; invariant 102 Phase A). Blocked by #575.
- [ ] **Wave 1 — Arch #572** (packet 12): Register the Bicep deploy + lint reusable workflows under `honeydrunk-actions` in the catalogs; no `acrhdbicep` grid-health entry. Blocked by #575, #571.
- [ ] **Wave 2 — Infra packet 11** (not yet filed; Infra repo created 2026-06-06 as a bare shell): Stand up the repo — `modules/`+`platform/`+`nodes/` tree, single root `bicepconfig.json`, README/CHANGELOG, `.honeydrunk-review.yaml`, `pr.yml` consuming Actions' `pr-core.yml`. Bootstrap PR. Blocked by #575, #571.
- [ ] **Wave 3 — Infra packet 13**: First six per-concern modules in `modules/`, consumed by local relative path. Blocked by packet 11.
- [ ] **Wave 3 — Infra packet 14**: `platform/` shared-foundation templates (shared Container Apps Environment, image ACR, Log Analytics, Service Bus); grandfather existing `dev` resources via `what-if`. Blocked by packet 11, 13.
- [ ] **Wave 3 — Actions #187** (packet 16): `job-deploy-bicep.yml` reusable deploy workflow — local-path Bicep, OIDC, `what-if` preflight, no registry auth. Blocked by #575.
- [ ] **Wave 3 — Actions #122** (packet 07, UNCHANGED/already filed): Add `bicep lint` to `pr-core.yml`. Consumed by Infra's `pr.yml`. Blocked by #575.
- [ ] **Wave 4 — Arch #573** (packet 15): Author the `nodes/{node}/` leaf-template scaffold pattern. Blocked by #575, packet 13, 14.
- [ ] **Wave 4 — Arch #574** (packet 17): Author the D6 import-existing-resources playbook for the consolidated repo. Blocked by #575, packet 15.

**Operator/site-sync close-out (nine superseded/dead originals, all OPEN — close with successor pointers):** Arch #384→#575, Arch #385→#571+#572, Arch #386→#574 (residue to packet 14), Arch #387→#573, Arch #388→#574, Actions #118→packet 11+13, Actions #119→DEAD (registry dropped, no successor), Actions #120→packet 13, Actions #121→#187. **Actions #122 stays OPEN** (packet 07 untouched). The `scope`/`hive-sync` agents do not close issues — operator step.

**Exit criteria:** ADR-0077 Accepted (amended); invariants 90/91/92 live; `HoneyDrunk.Infrastructure` registered + scaffolded (`modules/`+`platform/`+`nodes/` + root `bicepconfig.json`); deploy + lint workflows shipped in Actions and consumed by Infra's `pr.yml`; first per-concern module set + `platform/` foundation authored; scaffold pattern + import playbook documented; the nine superseded originals closed with successor pointers.

### ADR-0043 Continuous Backlog Generation
**Status:** In Progress — ADR accepted; full ADR-0086 automation substrate landing
**Scope:** Architecture governance, generated packet lifecycle, agent prompts, ADR-0086 runner jobs, Discord visibility
**Initiative:** `adr-0043-continuous-backlog-generation`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Close the upstream work-sourcing gap by running Strategic, Tactical, Opportunistic, and Reactive backlog generation through the ADR-0086 Grid Agent Runner. Agent-generated work lands in `generated/issue-packets/proposed/`; humans promote selected packets to `active/`; weekly netrunner briefings provide the triage surface; Discord provides runner visibility and urgent reactive attention.

**Tracking (Automation substrate):**
- [x] Accept ADR-0043 and bind D7 to the ADR-0086 runner instead of deferring execution.
- [x] Add `proposed/`, audit, scout, briefing, and urgent generated surfaces.
- [x] Add backlog-generation invariants and packet `source` / `generator` authoring rules.
- [x] Add tactical audit rotation.
- [x] Amend `scope`, `node-audit`, `product-strategist`, `netrunner`, and `hive-sync` prompts for ADR-0043 automation.
- [x] Add ADR-0086 job specs and Codex prompts for `backlog-strategic-scope`, `backlog-tactical-audit`, `backlog-opportunistic-scout`, and `backlog-weekly-briefing`.
- [x] Add Discord alert-routing rows and runner notification summaries for backlog-generation jobs.
- [ ] Register scheduled tasks on the operator runner host after merge.
- [ ] First live Strategic source run creates proposed packets for currently Accepted decisions with missing implementation coverage.

**Exit criteria:** ADR-0043 Accepted; generated surfaces live; source/generator packet contract enforced in docs; all four runner jobs dry-run successfully; runner defaults include the jobs; Discord summaries route to `#hive-activity`; first live Strategic run produces or explicitly skips proposed packets with dedupe evidence.

### ADR-0052 Cost Governance, Budget Alerts, and Kill-Switches
**Status:** In Progress — Phase-1 governance substrate landed; contract + implementation packets gated
**Scope:** Architecture (governance), Kernel (contracts), AI (ledger impl + dispatcher kill-switch); Operator/Communications/Notify/Observe surfaces deferred to ADR-0018 standup
**Initiative:** `adr-0052-cost-governance`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Commit the Grid's cost-governance substrate per ADR-0052: five cost categories with per-category soft/hard caps, layered kill-switches (in-process AI-inference, Azure-suspend infra, GitHub-native CI), per-tenant/per-agent attribution, a Cosmos-backed `ICostLedger`, monthly reports, anomaly detection, time-bounded audited overrides, and a phased rollout. **This pass lands the Architecture-side governance substrate** — the policy is the cheap insurance the ADR argues for, ready for when the AI Node scaffolds.

**Tracking (Wave 1 — Architecture governance, shipped via PR #517):**
- [x] Architecture#354: Accept ADR-0052 — flip status, add cost-governance invariants 104/105/106, register the initiative (packet 00)
- [x] Architecture#356: Create `business/context/cost-budgets.json` with the D2 defaults + tuning policy (packet 02)
- [x] Architecture#357: Create `generated/cost-reports/` with the canonical monthly report format (packet 07)
- [x] Architecture#358: Add `cost-config` + `cost-kill-switch-retry` review categories to `.claude/agents/review.md` (packet 08)
- [x] Architecture#359: Capture the Operator-side rollout map for the deferred Phase 2–7 surfaces (packet 09; standalone playbook retired, residual gate map retained here)

**Deferred / gated (NOT in this pass):**
- [ ] Architecture#355: Catalog registration of the Kernel cost-governance contracts + AI-side `ICostLedger` relocation record (packet 01) — **deferred** to pair with the Kernel code (packet 03), so the catalog never claims contracts the Kernel package doesn't yet expose.
- [ ] Kernel: Add `ICostLedger`/`CostEvent`/`CostCategory`/`BudgetExceededException`/`BudgetOverride`/`IBudgetConfigProvider`/`BudgetConfig`/`CostQuery` to `HoneyDrunk.Kernel.Abstractions` (packet 03) — Kernel solution version bump (couples with ADR-0042); needs a human NuGet release tag before packet 04.
- [ ] AI: Relocate `ICostLedger` off the seed AI contract onto Kernel; migrate provider call sites; Phase-1 stub (packet 04) — **blocked** on the human Kernel release.
- [ ] AI: Cosmos-backed `CostLedger` v1 + cache + `BudgetConfigProvider` (packet 05) — **hard-blocked**: `HoneyDrunk.AI` is at seed v0.1.0; the ADR-0016 Phase-1 scaffold was never executed, so there is no scaffolded Node to host a Cosmos client. Also needs human Cosmos provisioning.
- [ ] AI: Dispatcher kill-switch wiring + canary (packet 06) — blocked on packet 05 + ADR-0045 `IErrorReporter` (still Proposed; structured-log fallback documented).
- [ ] **All Operator-side surfaces** (aggregator, `hd cost` CLI, auto-suspend, dashboard, anomaly Bicep, Communications+Notify alert wiring) — gated on ADR-0018 (Operator standup, still Proposed); use the deferred gate map below when this is re-scoped.

**Deferred gate map (formerly the standalone rollout playbook):**
- **Gate 0 — anytime:** per-provider API-key spending limits and operator override pattern docs.
- **Gate 1 — ADR-0018 Accepted + Operator scaffold executed:** Operator aggregator, `hd cost status`, `hd cost unlock`, `hd cost report`, monthly report writer, dashboard view, non-prod Container Apps auto-suspend, Communications/Notify alert wiring, dev/prod Azure split.
- **Gate 2 — ADR-0040 Accepted + App Insights provisioned:** App Insights anomaly-alert Bicep.
- **Gate 3 — one month of Phase-1 baseline data:** Phase-1 multiplier flip (`CostLedger:PhaseOneMultiplier:*` -> 1) and cap tuning.
- **Gate 4 — ADR-0037 Accepted + Billing Node scaffolded:** per-tenant cost query API.
- **Gate K — ADR-0016 Phase-1 AI scaffold executed + Kernel contracts released:** Kernel packet 03, AI relocation, Cosmos ledger, and dispatcher kill-switch packets.

**Exit criteria:** ADR-0052 Accepted; cost-governance invariants live; `cost-budgets.json` seeded; report format + review-agent cost gating in place; residual gate map captures every deferred surface with its gating event. Full enforcement (the kill-switch) goes live when the AI Node scaffolds (ADR-0016 Phase 1) and the Kernel contracts release.

> **Sync (2026-05-31):** ADR-0052 verified **Accepted** on `main`; wave-1 governance packets #354/#356/#357/#358/#359 confirmed CLOSED via live `gh`. ADR-0052 was struck from `current-focus.md` (was ranked #14) — the Architecture-side governance substrate is done. The only residual is **Architecture#355** (`ICostLedger` → Kernel relocation, confirmed OPEN), which is hard-gated AI-side work (HoneyDrunk.AI at seed v0.1.0; ADR-0016 Phase-1 scaffold unexecuted) plus a human Kernel release — tracked here as gated, deliberately **not** on current-focus.
> **Sync (2026-06-01):** The standalone `initiatives/adr-0052-rollout-playbook.md` file was retired as operator-directed cleanup; its durable residual gate map is retained in this initiative entry, and detailed phase sequencing remains in ADR-0052 D14. No ADR-0052 implementation gate changed.

### ADR-0083 Sensitive Inventory and External-SaaS Credential Rotation
**Status:** Complete — ADR-0083 Accepted; closing PRs #528 (Architecture) + #174 (Actions) MERGED 2026-05-30; ready for exit-criteria review/archive
**Scope:** Architecture (inventory, walkthroughs, invariant, onboarding hook, cross-links) + Actions (drift-detection workflow)
**Initiative:** `adr-0083-external-saas-credentials`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Build a registry of everything load-bearing the Grid holds — credentials, identifiers, OIDC bindings, resource identifiers — at `infrastructure/reference/sensitive-inventory.md`, with rotation discipline (walkthroughs, standing issues, T-30/T-7/T+0 escalation) applied only to the `Rotates: yes` subset. Closes the silent-CI-degradation failure mode (SONAR_TOKEN's 60-day cap) and the lottery-bus-factor risk of forgotten credentials. `HoneyDrunk.Vault.Rotation` does **not** expand to cover external-SaaS PATs (D1).

**Tracking:**
- [x] Architecture#467: Accept ADR-0083 — flip status, add the unified sensitive-inventory invariant (103), register the initiative (packet 00; PR #518)
- [x] Architecture#468: Seed `infrastructure/reference/sensitive-inventory.md` with the live/imminent rows (packet 01; PR #518) — labels seeded separately via `gh label create` (held)
- [x] Architecture#469: Author `sonarcloud-token-rotation.md` — the SONAR_TOKEN forcing-function walkthrough (packet 02; PR #518)
- [x] Architecture#470: Author `nuget-api-key-rotation.md` (packet 03; PR #518)
- [x] Architecture#471: Author `github-pat-rotation.md` (packet 04; PR #518)
- [x] Architecture#473: D6 onboarding hook in `node-standup.md` + Vault.Rotation/vendor-inventory cross-links (packet 07; PR #518)
- [x] Actions: Author `external-credentials-check.yml` scheduled drift-detection workflow + supporting scripts (packet 05; Actions PR #171)

**Live side-effects (done — required so invariant 103 is satisfied on merge, per the Grid review agent's BLOCK on PR #518):**
- [x] Seeded the 3 repo labels (`external-credential-rotation` #D93F0B, `urgent` #B60205, `imminent` #9B0000).
- [x] Architecture#472: Opened standing rotation issues for the live `Rotates: yes` rows — #520 `SONAR_TOKEN`, #521 `NUGET_API_KEY`, #523 `HIVE_FIELD_MIRROR_TOKEN`, #524 `LABELS_FANOUT_PAT`, #525 `INITIATIVES_SYNC_TOKEN`, #526 `GRID_HEALTH_PAT` (+ #530 `CREDENTIALS_CHECK_TOKEN`, opened during reconciliation). Carve-out is **planned-only** — only `OPENAI_API_KEY` (`status: planned`) is exempt.

**Reconciliation against live `gh secret list` (2026-05-30; PRs #528 Architecture / #174 Actions):**
- [x] **`GH_ISSUE_TOKEN` was a phantom** (no such org secret) — removed from the inventory and replaced by **`CREDENTIALS_CHECK_TOKEN`**, the dedicated fine-grained PAT (Architecture-scoped, Issues/Contents/PRs RW, expires 2027-05-30) the operator minted and bound to `HoneyDrunk.Actions`. `external-credentials-check.yml` repointed (PR #174); standing issue #522 closed, #530 opened.
- [x] **`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` retired under ADR-0088** — the org secret is gone, issue #527 is closed, and ADR-0088 packet 04 removed the inventory row + rotation walkthrough + node-standup matrix row.
- [x] **Dates corrected** — `NUGET_API_KEY` → ~2026-10-30 (issue #521 retitled); `ANTHROPIC_API_KEY` reclassified live / `Rotates: no`; `LABELS_FANOUT_PAT` + `GRID_HEALTH_PAT` corrected to **repo** secrets on `HoneyDrunk.Actions`.
- [ ] Minor follow-ups: verify the inferred `Use Cases` for `INITIATIVES_SYNC_TOKEN` / `GRID_HEALTH_PAT`; refine NUGET's exact date at next rotation.

**Remaining to close the initiative:** merge **#528 + #174** — the workflow goes live against the right token + reconciled inventory once both land. Operator items done: `CREDENTIALS_CHECK_TOKEN` bound, CodeRabbit Global Override updated. *(PR #529 — the CodeRabbit summary-placement fix — is unrelated config hygiene, not an ADR-0083 deliverable, and does not gate this initiative.)*

**Exit criteria:** ADR-0083 Accepted; invariant 103 live; the inventory + walkthroughs + onboarding hook landed; the drift-detection workflow live in Actions; labels + standing issues created; real expiration dates reconciled against ground truth. **All met once #528 + #174 merge.**

> **Sync (2026-05-31):** ADR-0083 verified **Accepted** on `main`; closing PRs **#528 (Architecture) and #174 (Actions) confirmed MERGED 2026-05-30** via live `gh`. All exit criteria now met — initiative is **ready to archive**. ADR-0083 was struck from `current-focus.md` (was ranked #3). One inventory row remained intentionally tracked at that point: `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` retired under the ADR-0088 OpenClaw-decommission cutover, not here.
> **Sync (2026-06-02):** ADR-0088 completed the OpenClaw secret cutover after the operator deleted `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`; issue #527 is closed, and the ADR-0083 inventory no longer carries the OpenClaw row or walkthrough.

### ADR-0084 Discord as the Canonical Operator-Alerts Surface
**Status:** Accepted — core shipped (acceptance + seam + credential pager + runner path); PRs #551 (Architecture, commit 89c3842) + #178 + #180 (Actions) MERGED 2026-05-31. Phase 1 emitter remainder + Phase 3/4 vendor-webhook emitters deferred pending a post-home-server substrate decision (ADR-0088 / ADR-0086).
**Scope:** Architecture (governance flip, invariant, alert-routing table, walkthrough, vendor-posture + standup amendments) + Actions (`job-discord-notify.yml` reusable workflow + phased emitter retrofits) + the ADR-0086 runner (non-Actions Discord posting path)
**Initiative:** `adr-0084-discord-alerts`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0084 and commit Discord as the single canonical operator-alerts surface for the Grid — the real-time operational pager across CI failures, security signals, agent activity, release events, hive-sync drift, and ADR-0083 credential-rotation escalation. Seven dedicated channels with a routing table; native Discord webhooks (one per channel per emitter class, no bot bridge); **two emitter classes** per the D4 refinement — GitHub Actions via `DISCORD_WEBHOOK_*` org secrets, and the ADR-0086 pull-based runner via `Discord--{ChannelPascalCase}--RunnerWebhookUrl` secrets in the shared automation Key Vault `kv-hd-automation-dev` (a third secret *category* — automation-runtime — beyond ADR-0083 D1's CI-machinery and workload-runtime, but two emitter *classes*). Single CI-side seam `job-discord-notify.yml`; the runner posts from its own Key Vault-resolved PowerShell path (best-effort, log-and-continue). Payload rules: no secret values, no customer PII, no full stack traces (invariant 8 extended to webhook payloads). The forcing function is ADR-0083 D5's T-30 / T-7 / T+0 escalation cadence needing a saliency-appropriate channel.

**Tracking:**
- [x] Architecture: Accept ADR-0084 — flip status, refine D4/D9 (third secret category for the ADR-0086 runner; drop the dead home-server helper path), claim invariant 107, register the initiative (packet 00) — PR #551
- [x] Architecture: `constitution/alert-routing.md` — the canonical, hive-sync-checked routing table seeded from D6 (packet 01) — PR #551
- [x] Architecture: Discord webhook rows in `infrastructure/reference/sensitive-inventory.md` per ADR-0083 D2 (`Rotates: no`) — seven Actions rows + two runner rows (packet 03) — PR #551
- [x] Architecture: `infrastructure/walkthroughs/discord-webhook-rotation.md` per ADR-0083 D4 (packet 04) — PR #551
- [x] Architecture: `constitution/node-standup.md` operator-alert-routing onboarding step per D10 (packet 07) — PR #551
- [x] Architecture: ADR-0080 D2 vendor-posture Discord row per D7 (packet 08) — PR #551
- [x] Operator (human): seven Actions webhooks (org secrets) + two runner webhooks (`kv-hd-automation-dev`) provisioned (packet 02)
- [x] Actions: `job-discord-notify.yml` reusable workflow with the D8 redaction pre-check (packet 05) — PR #178 (merged)
- [x] Actions: Phase 1 emitter retrofit — ADR-0083 credential-rotation escalation (T-30/T-7/T+0) → Discord (packet 10) — PR #180 (merged 2026-05-31)
- [x] ADR-0086 runner: Discord posting path live (resolves `Discord--*--RunnerWebhookUrl` from `kv-hd-automation-dev`) — covers review/specialist → `#agent-activity` and hive-sync → `#hive-activity`

**Deferred / phased (NOT in this pass):**
- [ ] Actions: Phase 1 remainder — CI-on-main failure, release/NuGet/deploy events → `#release` / `#ops-alerts` (cleanly wireable follow-up)
- [ ] Phase 3/4 vendor-webhook emitters — Dependabot/CodeQL/secret-scan, CodeRabbit P0/P1, Azure budget, App Insights error spikes. These were designed as home-server webhook bridges (ADR-0081); ADR-0088 tears down the OpenClaw webhook bridge they assumed, so they need a substrate decision (the ADR-0086 runner absorbs them, or an Azure Function receives the webhooks) before wiring. GitHub-native security alerts (email + Security tab) and the absence of any deployed service make these low-urgency.

**Dropped (OpenClaw / standalone home-server helper path retired):**
- The originally-planned home-server helper packet (#479 — `infrastructure/scripts/discord-notify.ps1`) is **dropped**: ADR-0088 retires the OpenClaw / standalone-helper delivery path (the home-server hardware survives as the ADR-0086 runner host, but the separate helper-script emitter premise is gone), so there is no separate home-server-hosted non-Actions emitter. The ADR-0086 runner is the sole non-Actions emitter and posts via its own Key Vault-resolved path — no separate helper script is authored.

**Exit criteria:** ADR-0084 Accepted; invariant 107 live; alert-routing table landed; the two webhook classes provisioned and inventoried; `job-discord-notify.yml` live in Actions and the ADR-0086 runner's Discord path wired; standup + vendor-posture amendments landed; phased emitter retrofits complete per the rollout plan.

> **Sync (2026-05-31):** ADR-0084 verified **Accepted** on `main` (commit 89c3842); acceptance/governance PR **#551 (Architecture)** + seam PR **#178** + Phase 1 emitter PR **#180 (Actions)** all confirmed MERGED 2026-05-31 via live `gh`. Core acceptance struck from `current-focus.md` (was ranked #4). Remaining work is deferred and Watch-tier, not ranked: the **Phase 3/4 vendor-webhook emitters** carry a current-focus Watch-tier line (substrate-gated on the ADR-0088 OpenClaw teardown + an ADR-0086-runner-or-Azure-Function decision); the Phase 1 emitter remainder (CI-on-main / release events) is a cleanly-wireable follow-up. Acceptance packet **Architecture#474 is still OPEN** — flagged as housekeeping for the operator (the PR merged but the issue was not auto-closed).

### ADR-0044 Cloud Code Review and AI-Authored PR Discipline
**Status:** Complete — all tracked packet issues closed; ready for exit-criteria review/archive
**Scope:** Architecture, Actions, OpenClaw runtime, and later the live Node repos
**Initiative:** `adr-0044-cloud-code-review`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0044 and ship the automatic Grid-aware code-review substrate: GitHub Actions emits signed review requests; OpenClaw/Codex runs the canonical `.claude/agents/review.md` with Grid context; review results are advisory in Phase 1 and piloted on `HoneyDrunk.Architecture` before fan-out.

**Tracking (Wave 1 — Phase 1: Architecture pilot):**
- [x] Architecture#170: Accept ADR-0044 — flip status, finalize invariants 52/53, register initiative (packet 01; shipped via PR #273)
- [x] Architecture#179: Define the OpenClaw/Codex Grid Review Runner runtime (packet 02b; shipped via PR #274)
- [x] Actions#87: Build `job-review-request.yml` — GitHub trigger rail for OpenClaw reviewer (packet 03b; shipped via Actions PR #99)
- [x] Architecture#172: Update `.claude/agents/review.md` with the D3 twenty-category rubric execution detail (packet 04; shipped via PR #276)
- [x] Architecture#180: Author the OpenClaw-aware `.honeydrunk-review.yaml` v1 schema doc (packet 05b; shipped via PR #277)
- [x] Architecture#181: Enable the OpenClaw/Codex reviewer on `HoneyDrunk.Architecture` (packet 06b; shipped via PR #278)

**Tracking (Wave 2 — Phase 2: live Node rollout + discipline foundations):**
- [x] Actions#85: Add authorship-check and pr-size-check jobs to `pr-core.yml` (packet 07; shipped via Actions PR #100, closed 2026-05-23)
- [x] Actions#86: Seed `large-pr`, `audit-sample`, and `skip-review` labels Grid-wide (packet 08; labels-as-code and seed/fanout workflows shipped via Actions PR #100; fanout repair shipped via Actions PR #101; fanout run verified 2026-05-24)
- [x] Architecture#175: Roll the D3 rubric into upstream authoring agents (packet 09; shipped via PR #279)
- [x] Architecture#176: Amend execution-surface prompts for `Authorship:` and D3 checklist (packet 10; shipped via PR #279)
- [x] Architecture#182: Superseded by ADR-0086 packet 09 — local-worker reviewer fan-out implementation landed on the 10 remaining live Nodes; repo-local PR templates are not duplicated because `HoneyDrunkStudios/.github` carries the org-wide `Authorship:` default.
- [x] Architecture#183: Verify `pr-review-rules.md` severity coverage across all D3 categories (packet 12; shipped via this PR)

**Tracking (Wave 3 — Phase 3: discipline tightening):**
- [x] Architecture#184: Add `review_risk_class` to `catalogs/grid-health.json` (packet 13)
- [x] Actions#88: Activate D8 multi-perspective review for high-risk-Node PRs (packet 14)

**Tracking (Wave 4 — Phase 4: sampling audit + drift detection):**
- [x] Architecture#185: Create `generated/post-merge-audits/` with README (packet 15)
- [x] Actions#89: Build the D9 `audit-sample` post-merge labeling and audit job (packet 16)
- [x] Architecture#186: Wire `hive-sync` to detect D3 ↔ agent-file drift (packet 17)

**Superseded packets:** Architecture#171, Actions#84, Architecture#173, Architecture#174, and Architecture#182 are superseded and should not be executed. Architecture#173 and Architecture#174 should be closed as superseded by Architecture#180/#181; Architecture#182 is superseded by ADR-0086 packet 09, which fans out the `local-worker` default instead of `openclaw-codex`; Architecture#171 remains a gated human/infra item only if webhook/GitHub-App credentials become necessary for the non-cron path.

**Exit criteria:** ADR-0044 is Accepted; Phase 1 MVP (`job-review-request.yml` + Grid Review Runner) is enabled on `HoneyDrunk.Architecture` only and running on every non-draft PR; each phase's dispatch-plan go/no-go criterion is satisfied before the next wave starts.

> **Sync (2026-05-24):** Phase 1 is functionally complete in artifact-plus-cron/poll mode: ADR-0044 is Accepted, `job-review-request.yml` is live, Architecture has `.honeydrunk-review.yaml` and the caller workflow, and OpenClaw posted advisory PR comments for reviewed head SHAs. Webhook provisioning remains the transport hardening gap; the temporary OpenClaw cron/poll jobs should be disabled after signed webhook delivery is configured and verified. Wave 2 Architecture-side docs/prompts (#175, #176, #183) have landed. Actions#85 is closed via Actions PR #100; Actions#86 is closed after the `seed-labels-fanout.yml` run completed successfully on 2026-05-24. ADR-0044 no longer uses the deprecated multi-agent cloud-review path; broad Node fan-out (#182) is unblocked.

> **Sync (2026-05-30):** 17/17 tracked ADR-0044 packet issues are closed in The Hive issue-state query. Packets moved to `completed/`; initiative is ready for exit-criteria review/archive.

### ADR-0086 Pull-Based Local Worker Grid Review Runner
**Status:** Complete — ADR-0086 Accepted on `main`; operator confirms the local-worker review runner is complete and operating across the Grid. Ready for exit-criteria review/archive. Residual dual-pass + OpenClaw-teardown work re-homed under ADR-0087 (dual-pass / risk-signals) and ADR-0088 (OpenClaw decommission); scheduled-job migration tracked as Phase C/D follow-on.
**Scope:** Architecture, Actions, the local runner host, HoneyDrunk.Lore scheduled jobs, and later the live Node repos
**Initiative:** `adr-0086-pull-based-local-worker-grid-review`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0086 and replace the fragile signed-webhook -> OpenClaw review path with a GitHub-native queue plus a portable scheduled agent runner. GitHub Actions normalizes managed PR labels and enqueues via labels plus a structured queue comment; the home-server runner polls, claims one PR/head SHA at a time, runs Codex CLI and Claude Code CLI under subscription auth when required, synthesizes their findings into one advisory verdict, and preserves ADR-0044/ADR-0079 review discipline. The same runner framework also owns scheduled agent job specs for `hive-sync`, Lore sourcing, Lore ingest/compile, and Lore signal review so those jobs can move off OpenClaw/Honeyclaw with smoke-tested cutovers.

**Tracking (Wave 1 — Phase A: Architecture pilot):**
- [x] Architecture: Accept ADR-0086, append supersession notes to ADR-0044/ADR-0079, register this initiative, and mark ADR-0044 Architecture#182 superseded (packet 01)
- [x] Architecture: Audit and reuse the existing ADR-0044 review-agent GitHub App walkthrough/credential contract (packet 02)
- [x] Architecture: Author the portable PowerShell scheduled agent runner under `infrastructure/workers/grid-agent-runner/`, including job specs, dual Codex/Claude synthesis, Task Scheduler startup/restart behavior, and initial hive-sync/Lore job specs (packet 03)
- [x] Architecture: Update the `.honeydrunk-review.yaml` schema doc for `runner: local-worker` / `api-ci` and removal of `openclaw-codex` (packet 04)
- [x] Actions: Rewrite `job-review-request.yml` as the managed-label-normalizing label/comment enqueue workflow (packet 05)
- [x] Actions: Add worker labels and the managed PR-label vocabulary Grid-wide (packet 06)
- [x] Architecture: Cut over the Architecture pilot to the local worker and record Phase-A go/no-go evidence (packet 07)

**Tracking (Wave 2 — Phase B: decommission + fan-out):**
- [x] Architecture: Decommission OpenClaw on the review path and document operator-side cutover steps (packet 08; review transport replaced by ADR-0086 local-worker queue; physical teardown/governance reconciliation owned by ADR-0088 — see #542/#545)
- [x] Cross-repo: Enable the local-worker reviewer on the 10 remaining live Nodes, superseding ADR-0044 Architecture#182 (packet 09; implementation landed 2026-05-30, Phase-A prerequisites now reconciled)

> **Sync (2026-05-30):** ADR-0086 packet 09 implementation landed across Kernel#70, Transport#43, Vault#48, Auth#38, Web.Rest#33, Data#39, Notify#52, Communications#29, Pulse#40, and the Actions queue/caller follow-ups through Actions#177. The `Authorship:` PR-template requirement is satisfied by the org-wide `HoneyDrunkStudios/.github` default template unless a repo deliberately overrides it.

> **Sync (2026-05-31):** Operator confirms **ADR-0086 is DONE** — Accepted on `main` and the local-worker review runner is complete and operating across the Grid. Phase A/B tracker boxes closed; ADR-0086 **struck from `current-focus.md`** (was ranked #1) and added to the Archive / exit-criteria review candidate list (current-focus #9). **Residual work re-homed, not lost:** the open issues that still reference ADR-0086 in their body are no longer ADR-0086 implementation work — the OpenClaw teardown packets (**Arch#542/#545**, plus the Actions `job-review-request` edits **#175/#176**) belonged to **ADR-0088** (OpenClaw decommission; completed 2026-06-02), and the worker **dual-pass / risk-signals substrate (Arch#537/#538)** is **ADR-0087** follow-on. ADR-0086 is no longer the tracker for any of these. The scheduled-agent-job migration (Phase C, packet 11) and observability polish (Phase D, packet 10) remain ADR-0086-homed follow-on phases below but are not current-focus-ranked.

**Tracking (Wave 3 — Phase C: scheduled agent job migration):**
- [ ] Architecture: Migrate `hive-sync`, Lore sourcing, Lore ingest/compile, and Lore signal review from OpenClaw/Honeyclaw schedules to ADR-0086 runner jobs with smoke-test and rollback records (packet 11)

**Tracking (Wave 4 — Phase D: observability polish):**
- [ ] Architecture: Surface runner health through hive-sync and the weekly briefing surfaces, including review queue backlog and scheduled-job freshness (packet 10)

**Exit criteria:** Phase A proves verdict quality, reliable polling/claim semantics, deterministic head-SHA invalidation, and near-zero marginal cost under subscription auth on `HoneyDrunk.Architecture`; Phase B follows only after OpenClaw is decommissioned on the review path; Phase C migrates scheduled agent jobs only after runner smoke tests; Phase D makes runner availability visible through the existing narrative surfaces without adding a pager or inbound alert.

### ADR-0088 Decommission OpenClaw from the HoneyDrunk Grid
**Status:** Complete — runtime/tunnel teardown, docs-sync scheduler, reference-file deletion, governance cleanup, org-secret deletion, and invariant-103 inventory cleanup are done; ready for exit-criteria review/archive
**Scope:** Architecture (governance flip, reference-file teardown, ADR reconciliation, ADR-0007 addendum retirement) + operator/runtime chores + Actions cleanup + the sensitive-inventory (`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` retirement)
**Initiative:** `adr-0088-openclaw-decommission`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0088 and govern the full teardown of OpenClaw from the Grid. **ADR-0088 supersedes ADR-0081** (the home-server-for-OpenClaw ADR): its OpenClaw-centric organizing premise is dead — ADR-0086's local-worker queue replaced the OpenClaw review path, and the home-server hardware/security premise is re-homed under ADR-0086 rather than retired — so the remaining OpenClaw surface area is dead reference material that needs a governed removal rather than a host to run on. This is the real owner of the dead-OpenClaw cleanup that `current-focus.md` was previously (incorrectly) tracking under ADR-0081. ADR-0086 Phase B (packet 08) explicitly defers the OpenClaw teardown + governance reconciliation here.

**Tracking:**
- [x] Architecture: Author + smoke-test the `docs-sync` runner job spec so docs-sync keeps automated Friday scheduling on the ADR-0086 worker (packet 00a)
- [x] Architecture#539: Accept ADR-0088 — decommission OpenClaw; supersede ADR-0081; register the teardown initiative (packet 00)
- [x] Architecture#541: Remove the `infrastructure/openclaw/*` reference files; tombstone the runner README pointers
- [x] Human/Ops: Remove OpenClaw Gateway, Honeyclaw runtime, webhook bridge, and OpenClaw-bound Cloudflare Tunnel route after replacement jobs are proven (packet 02)
- [x] Human/Org Admin: Delete `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` and close issue #527 as decommissioned, no successor issue (packet 03)
- [x] Architecture: Retire the sensitive-inventory row, rotation walkthrough, and node-standup matrix row only after packet 03 confirms the secret is gone (packet 04)
- [x] Architecture#545: Reconcile OpenClaw references in ADR-0082, ADR-0083, ADR-0084, and ADR-0085 as documentation-currency edits, excluding secret-retirement claims blocked by packet 03
- [x] Actions: Remove vestigial deprecated `openclaw-*` inputs from `job-review-request.yml` without deleting the org secret (packet 06; Actions branch `codex/adr-0088-openclaw-decommission`)
- [x] Architecture#546: Retire the ADR-0007 Operational Addendum (OpenClaw-skills-mirroring rule) + its node-standup and agent-skills-map wirings

**Cross-initiative dependencies:**
- Retires the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` inventory row that ADR-0083 deliberately left tracked pending this cutover (see the ADR-0083 reconciliation note above).
- Unblocks the ADR-0084 Phase 3/4 vendor-webhook-emitter substrate decision (the home-server bridge those emitters assumed is gone).

**Exit criteria:** ADR-0088 Accepted; `infrastructure/openclaw/*` removed and runner README pointers tombstoned; OpenClaw references across ADR-0082/0083/0084/0085 reconciled; ADR-0007 Operational Addendum retired with its wirings; `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row retired from the sensitive inventory and its standing issue #527 closed; ADR-0081 marked Superseded.

> **Sync (2026-05-31):** Registered as an active initiative and promoted to the then-current-focus #1 slot. Packet cluster #539/#541/#545/#546 confirmed OPEN via live `gh`. ADR-0088 verified **Proposed** on `main`. This initiative replaces the false ADR-0081 tracking that previously sat at current-focus #15 — **ADR-0081 has been removed from current-focus** (its only acceptance packet, Architecture#457, remains OPEN but its OpenClaw-centric premise is dead — the home-server hardware survives under ADR-0086 — so ADR-0081 should be marked Superseded by ADR-0088 rather than accepted).
> **Sync (2026-06-01):** ADR-0088 flipped to **Accepted** locally and ADR-0081 flipped to **Superseded by ADR-0088**. Wave 0 `docs-sync` scheduler work landed locally with a passing dry-run smoke; it runs weekly Friday at 10:30 local and posts report summaries to `#hive-activity`. At that point, remaining work was not just docs: OpenClaw runtime/tunnel teardown and org-secret deletion were human-gated, and the inventory row/walkthrough/matrix cleanup was blocked by the secret actually being deleted per invariant 103.
> **Sync (2026-06-01, teardown update):** Operator confirmed OpenClaw Gateway / Honeyclaw runtime / webhook bridge deletion, and `cloudflared tunnel delete --force grid-review` removed the remaining Cloudflare Tunnel (`cloudflared tunnel list` returned no tunnels afterward). Architecture governance cleanup landed locally: owned-domain record retired `grid-review.honeydrunkstudios.com`; ADR-0007's OpenClaw Skills addendum is retired; node-standup step 15 no longer requires OpenClaw mirroring; `copilot/agent-skills-map.md` no longer tracks OpenClaw companion skills; ADR-0084/0085 execution-surface prose now points at ADR-0086 runner paths. Actions cleanup landed on branch `codex/adr-0088-openclaw-decommission` (commit `454adfd`): `job-review-request.yml` no longer accepts the deprecated OpenClaw webhook/fallback inputs or no-op workflow secret. Secret-backed cleanup remained blocked until the operator deleted `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`: keep the inventory row, rotation walkthrough, standing issue #527, and matrix row until that deletion is confirmed.
> **Sync (2026-06-02, final secret cleanup):** Operator deleted `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`; live `gh secret list --org HoneyDrunkStudios` no longer returns the secret, and issue #527 is **CLOSED**. Packet 04 is complete: `infrastructure/reference/sensitive-inventory.md` no longer carries the row, `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md` is removed, and `constitution/node-standup.md` no longer has the OpenClaw matrix row. ADR-0088 is complete and ready to archive after exit-criteria review.

### ADR-0047 Testing Patterns and Tooling
**Status:** In Progress
**Scope:** Architecture, Standards, Actions, Data, Kernel, Studios, and every Node repo with test projects
**Initiative:** `adr-0047-testing-patterns-and-tooling`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Roll out the ADR-0047 Grid testing stack: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet for unit tests; WebApplicationFactory and Testcontainers for integration tiers; Playwright (.NET) for web E2E; Maestro for future mobile E2E; BenchmarkDotNet / Azure Load Testing for performance. Closes ADR-0011 Gap 1 and Gap 3.

**Tracking (Wave 1 — Phase 1: unit-test stack + migrations + coverage gates):**
- [x] Architecture#187: Accept ADR-0047 — flip status, close ADR-0011 Gap 1 and Gap 3, register the testing-patterns initiative (packet 00)
- [ ] Standards: Author shared unit-test-stack `Directory.Build.props` fragment (packet 01)
- [ ] Standards: Author `coverlet.runsettings` templates for D3 per-tier thresholds (packet 02)
- [ ] Standards: Add the `Thread.Sleep` analyzer rule for test projects (packet 03)
- [x] Architecture#188 / per-Node fan-out: Migrate FluentAssertions → AwesomeAssertions (packet 04)
- [x] Architecture#189 / per-Node fan-out: Migrate Moq → NSubstitute (packet 05)

**Tracking (Wave 2 — Phase 2: Tier 2a integration tests):**
- [ ] Actions: Author `job-integration-tests.yml` and wire it into `pr-core.yml` (packet 06)
- [x] Architecture#190: Author the integration-test scaffold template for the `scope` agent (packet 07)
- [x] Architecture#191: Update `.claude/agents/review.md` Testing Quality checklist per ADR-0047 D13 (packet 08)

**Tracking (Wave 3 — Phase 3: Tier 2b container-backed integration tests):**
- [ ] Actions: Author `job-integration-tests-containers.yml` (packet 09)
- [ ] Data: Pilot Tier 2b `Data.Tests.Integration.Containers` with Testcontainers Postgres (packet 10)
- [ ] Kernel: Pilot Tier 2a `IIdempotencyStore` reusable contract test + InMemory binding (packet 11)
- [ ] Kernel: Bind `IIdempotencyStore` contract test to Cosmos backing in Tier 2b (packet 12 — parked until ADR-0042 is Accepted and Cosmos backing exists)

**Tracking (Wave 4 — Phase 4: E2E web):**
- [ ] Actions: Author `job-e2e-web.yml` reusable workflow for Playwright (.NET) E2E (packet 13)
- [ ] Studios: Pilot `Studios.Tests.E2E` with Playwright and nightly schedule (packet 14)

**Tracking (Wave 5 — Phase 5: E2E mobile):**
- [ ] Actions: Author `job-e2e-mobile.yml` for Maestro (packet 15 — parked until first mobile app ships)

**Tracking (Wave 6 — Phase 6: performance):**
- [ ] Kernel: Add `Kernel.Tests.Benchmarks` with BenchmarkDotNet idempotency-store baseline (packet 16)

**Exit criteria:** ADR-0047 is Accepted; Standards ships the shared test stack, coverage templates, and analyzer; no Node test project retains Moq or FluentAssertions; Tier 2a/Tier 2b/E2E workflows and pilots land per D14; parked mobile/Cosmos work is either completed or explicitly re-homed when its trigger fires.

### Kernel Adoption Alignment
**Status:** In Progress
**Scope:** Kernel, Transport, Vault, Auth, Web.Rest, Data, Vault.Rotation, Notify, Pulse, Communications, Architecture
**Initiative:** `kernel-adoption-alignment`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Follow-up from the 2026-05-17 Kernel adoption audit. Align active .NET Nodes on canonical Kernel identity/context usage, remove avoidable runtime Kernel dependencies, enforce Grid/Operation context at HTTP/message/background entry points, clean up Notify queue-secret bootstrap drift, and reconcile Architecture compatibility metadata after repo PRs merge.

**Tracking:**
- [x] Kernel#29: Align Kernel context bootstrap and well-known Node IDs (packet 01 — closed 2026-05-18)
- [x] Transport#27: Drop Transport dependency on Kernel runtime (packet 02 — closed 2026-05-18)
- [x] Vault#31: Align Vault to current Kernel packages (packet 03 — closed 2026-05-18)
- [x] Auth#20: Align Auth to current Kernel packages (packet 04 — closed 2026-05-18)
- [x] Web.Rest#17: Require Kernel context in Web.Rest request pipeline (packet 05 — closed 2026-05-18)
- [x] Data#21: Require context for Data outbox enrichment (packet 06 — closed 2026-05-18)
- [x] Vault.Rotation#7: Establish Kernel context for rotation timer jobs (packet 07 — closed 2026-05-18)
- [x] Notify#13: Align Notify Kernel identity and queue secret boundary (packet 08 — closed 2026-05-18)
- [x] Pulse#15: Align Pulse to Kernel canonical identity (packet 09 — closed 2026-05-18)
- [x] Communications#14: Drop Communications runtime Kernel dependency (packet 10 — closed 2026-05-18)
- [x] Architecture#111: Reconcile Kernel adoption catalogs and compatibility (packet 11 — closed 2026-05-18)

> **Sync (2026-05-21):** Kernel#29, Transport#27, Communications#14, and Architecture#111 are now closed; packets 01, 02, 10, and 11 moved to `completed/`. All 11 packet issues are closed; initiative is ready for exit-criteria review/archive.

### ADR-0010 Observation Layer & AI Routing — Phase 1
**Status:** Phase 1 Observe-side complete; AI routing contracts satisfied by ADR-0016
**Scope:** Architecture, Observe (new), AI
**Initiative:** `adr-0010-observe-ai-routing-phase-1`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** ADR-0010 is accepted, HoneyDrunk.Observe is registered in Architecture catalogs/context, and the Observe repo now has the Phase 1 `HoneyDrunk.Observe.Abstractions` contract surface. The AI routing contracts originally tracked as packet 04 were superseded by ADR-0016 and shipped with the HoneyDrunk.AI standup scaffold. Phase 2 (first useful Observe connector + cost-first AI routing policy) and Phase 3 (HoneyHub integration, blocked on HoneyHub Phase 1 being live) remain future scope.

**Tracking (Phase 1 — Observe side):**
- [x] Architecture#35: Accept ADR-0010 — catalog, context folder, sectors, invariant 29-30 text, ADR index flip, initiative/roadmap trackers (packet 01 — closed 2026-05-21 via PR #157)
- [x] Architecture#36: Create HoneyDrunk.Observe GitHub repo (human-only chore — packet 02; closed 2026-04-18)
- [x] Observe#2: Scaffold HoneyDrunk.Observe.Abstractions with IObservationTarget / IObservationConnector / IObservationEvent (packet 03 — closed 2026-05-21 via Observe PR #3)

**Tracking (Phase 1 — AI routing contracts side):**
- [x] AI#2 / ADR-0016: HoneyDrunk.AI standup scaffold shipped `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`, and related routing/cost contracts in `HoneyDrunk.AI.Abstractions` (closed 2026-05-20 via AI PR #5)
- [x] AI#1 / AI#3: duplicate ADR-0010 packet-04 issues superseded by ADR-0016; retained only for traceability and closed during reconciliation

**Next (Phase 2 — not yet scoped):**
- Implement `HoneyDrunk.Observe` runtime composition and observation-state handling
- Implement `HoneyDrunk.Observe.Connectors.GitHub` — webhook receiver + repo health checks
- Implement cost-first `IRoutingPolicy` in HoneyDrunk.AI runtime and load routing policies from Azure App Configuration (per ADR-0005 three-tier config split)
- **Scope trigger:** Phase 1 contract surfaces are now present; begin Phase 2 only when there is a concrete external-project observation need and a live application-code caller for cost-first routing.

**Deferred (Phase 3 — blocked on HoneyHub Phase 1):**
- Route normalized `IObservationEvent` instances into HoneyHub's knowledge graph
- Allow HoneyHub to read routing-policy outcomes as plan-adjustment signals
- **Scope trigger:** HoneyHub Phase 1 domain model + graph API live

> **Sync (2026-05-21):** Architecture#35/#36 and Observe#2 are closed. HoneyDrunk.AI is no longer empty; ADR-0016 AI#2/PR#5 shipped the routing contracts packet 04 was waiting for. ADR-0010 Phase 1 contract/catalog work is complete; remaining work should be scoped as Phase 2 implementation, not more Phase 1 scaffold.

### ADR-0030 Grid-Wide Audit Substrate — Capability Acceptance
**Status:** In Progress
**Scope:** Architecture (capability acceptance only; HoneyDrunk.Audit standup is a separate ADR-0031-governed initiative)
**Initiative:** `adr-0030-audit-substrate`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept the capability/decision ADR for the Grid-wide durable, attributable security and action audit substrate homed in a new dedicated `HoneyDrunk.Audit` Node (Core sector). Registers the Node and its four new dependency edges across the catalogs, adds the Core-sector Audit row, flips the ADR index, verifies (does not modify) ADR-0018's pre-existing 2026-05-16 amendment (relocating `IAuditLog`/`AuditEntry` out of Operator, reclassifying Operator to consumer-not-owner), creates the `repos/HoneyDrunk.Audit/` context folder, and adds the constitutional audit-emission boundary invariant. The Node scaffold, the contract-shape canary, the Auth first-emitter wiring, and the Operator reconciliation are **all governed by the separate ADR-0031 standup** and are NOT in this initiative.

**Tracking:**
- [x] Architecture#108: Accept ADR-0030 — catalog registration, sectors row, ADR index flip, ADR-0018 amendment verification, repo context folder, trackers (packet 01 — closed 2026-05-18)
- [x] Architecture#109: Add the audit-emission boundary invariant to the constitution (packet 02 — closed 2026-05-18)

**Follow-up sync (2026-05-21):** ADR-0031 standup has now completed its initial packet set: Architecture invariants/catalog work, Audit repo scaffold + `v0.1.0` release, and Auth first-emitter wiring are closed. Remaining Operator reconciliation is future downstream work, not part of ADR-0030 capability acceptance. Audit `v0.1.0` and Auth `v0.5.0` are both published.

### ADR-0032 PR Validation Policy — Coverage Gate & NuGet Flagging
**Status:** In Progress
**Scope:** Meta (Actions CI/CD control plane) + ten test-bearing Nodes (per-repo coverage backfill)
**Initiative:** `adr-0032-pr-validation-policy`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** One PR Validation Policy owned by the Actions control plane, implemented once in the reusable workflows: (1) a blocking coverage gate — patch coverage threshold, no-regression vs. committed `.github/coverage-baseline.json`, flat absolute floor, skip-when-no-test-projects; (2) non-blocking NuGet flagging — outdated never blocks, surfaced as a PR-summary section and a single grouped `📦 Outdated Dependencies` issue per repo. Builds on ADR-0009 (outdated-vs-vulnerable split), ADR-0011 (`pr-core.yml` tier-1 gate), ADR-0012 (Actions as CI/CD control plane).

**Tracking (Wave 1 — Actions control plane, parallel):**
- [x] Actions#77: Coverage gate + ⚠️ outdated-packages PR-summary section (D1–D5) (packet 01 — closed 2026-05-19)
- [x] Actions#78: `nightly-deps` grouped per-repo `📦 Outdated Dependencies` tracking issue (D6) (packet 02 — closed 2026-05-19)

**Tracking (Wave 2 — per-repo coverage backfill to the absolute floor, hard-blocked by packet 01 only, fully parallel):**
- [x] Kernel#28 / Transport#26 / Vault#30 / Vault.Rotation#6 / Auth#19 / Web.Rest#16 / Data#20 / Pulse#14 / Notify#12 / Communications#13 — one backfill packet each (packets 03–12; closed 2026-05-19 through 2026-05-20)

**Notes:**
- New constitutional invariant (coverage gate at PR time) is added by the implementing packet; number assigned at acceptance, after the ADR-0030/0031 audit reservations (44–46) — see ADR-0032's New Invariant section.
- **Sync (2026-05-21):** All 12 packet issues are closed and packets moved to `completed/`. ADR-0032 remains `Proposed` because these packets do not yet declare `accepts:` frontmatter, so hive-sync will not auto-flip it; human/scope follow-up needed if acceptance should be automated.

### Hive Sync Rollout (ADR-0014)
**Status:** In Progress
**Scope:** Architecture
**Initiative:** `adr-0014-hive-sync-rollout`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Rename the legacy initiative sync agent to `hive-sync` and broaden its mandate to cover the packet lifecycle (active → completed), non-initiative board items, the Proposed-ADR/PDR queue, ADR/PDR auto-acceptance + README index sync, and a drift report. Closes the drift introduced by nightly-security issues having no Architecture-repo presence, completed packets lingering in `active/`, and ADRs/PDRs that drift out of sync with their implementing work or with the rest of the repo. Single repo (Architecture); six sequential phases. ADR-0014 itself auto-flips to Accepted via Phase 5's logic on the first run after Packet 06 closes.

**Tracking:**
- [x] Architecture#61: Rename agent + capability matrix (packet 01)
- [x] Architecture#62: Add packet lifecycle and Hive-Sync invariant for lifecycle (packet 02)
- [x] Architecture#63: Track non-initiative board items + Hive-Sync invariant for board coverage (packet 03)
- [x] Architecture#64: Surface Proposed-ADR acceptance queue (packet 04)
- [x] Architecture#65: ADR/PDR auto-acceptance + README index sync (packet 05)
- [x] Architecture#66: Drift detection + close out the rollout (packet 06)

> **Sync (2026-05-16):** ADR-0014 rollout implementation remains merged; Architecture#61-#66 remain closed. Hive Sync is running under OpenClaw cron; ready for human archive/exit-criteria review.


### Configuration & Secrets Rollout (ADR-0005 / ADR-0006)
**Status:** In Progress
**Scope:** Vault, Vault.Rotation (new), Architecture, Actions, Auth, Web.Rest, Data, Notify, Pulse, Studios
**Initiative:** `adr-0005-0006-rollout`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Per-Node Key Vault + shared App Configuration + env-driven bootstrap model (ADR-0005), plus rotation lifecycle, event-driven invalidation, and deploy-gate SLA checks (ADR-0006). Two waves: foundation then per-Node migration.
**Tracking:**
- [x] Issue packets authored (15 packets, 2 waves)
- [x] Wave 1 issues filed on board (7/7 — Architecture#8 closed 2026-04-11, unblocking Vault.Rotation scaffold)
- [x] Wave 1: Vault env-driven `AddVault` wiring (Vault#9 closed 2026-04-12)
- [x] Wave 1: Vault `AddAppConfiguration` extension (Vault#9 closed 2026-04-12)
- [x] Wave 1: Vault event-driven cache invalidation (Vault#10 closed 2026-04-12)
- [x] Wave 1: Vault.Rotation repo creation (Architecture#8 closed 2026-04-11 — repo created, unblocking scaffold execution)
- [x] Wave 1: Architecture portal walkthroughs (Architecture#7 closed 2026-04-11)
- [x] Wave 1: Architecture catalog registration for Vault.Rotation (Architecture#7 closed 2026-04-11)
- [x] Wave 1: Actions OIDC federated-credential workflow (Actions#20 closed)
- [x] Wave 2: Per-Node bootstrap migrations (Auth#5, Web.Rest#4, Data#4, Notify#1, Pulse#1, Studios#2 closed)
- [x] Wave 2: Actions direct secret removal + deploy-gate SLA check (Actions#21 closed)

> **Sync (2026-05-16):** 15/15 issue packets remain closed. Completed manifest entries older than 30 days were pruned from `filed-packets.json`; packet files remain archived in `completed/`. Initiative remains ready for exit-criteria review/archive, with release-verification notes still tracked in `initiatives/releases.md`.

### Container Apps Rollout (ADR-0015)
**Status:** Complete — all five rollout packet issues closed; ready for exit-criteria review/archive
**Scope:** Architecture, Actions, Notify, Pulse  
**Initiative:** `adr-0015-container-apps-rollout`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Deploy Notify and Pulse to Azure Container Apps. Includes infrastructure walkthroughs, Container App deployment workflow in Actions, and per-service release workflows.

**Tracking:**
- [x] Architecture#37: Infrastructure walkthroughs for Function App, ACR, Container Apps Environment, and Container App (closed)
- [x] Actions#48: Reusable workflow `job-deploy-container-app.yml` for Azure Container Apps (closed)
- [x] Notify#3: Release workflow and Azure bring-up for `Notify.Functions` (closed 2026-06-04)
- [x] Notify#4: Release workflow and Azure bring-up for `Notify.Worker` on Container Apps (closed 2026-06-04)
- [x] Pulse#3: Release workflow and Azure bring-up for `Pulse.Collector` on Container Apps (closed 2026-06-04)

> **Sync (2026-05-21):** 2/5 issues closed (40%). Foundation walkthroughs and reusable Actions workflow remain complete; Notify#3, Notify#4, and Pulse#3 are still open for service-specific release/Azure bring-up work. ADR-0033 environment-gated deploy-trigger packets (`Notify#19`, `Notify#20`, `Pulse#18`) are open in Backlog and should land before dev deploy verification resumes.

> **Sync (2026-06-03):** ADR-0033 deploy-trigger packets `Notify#19`, `Notify#20`, and `Pulse#18` are CLOSED (closed 2026-06-01) and ADR-0033 auto-flipped to Accepted. Container Apps rollout remains 2/5 closed: `Notify#3`, `Notify#4`, and `Pulse#3` are still open for service-specific release/Azure bring-up work; the trigger-model blocker is cleared.
> **Sync (2026-06-05):** Live GitHub issue state shows `Notify#3`, `Notify#4`, and `Pulse#3` CLOSED on 2026-06-04. ADR-0015 Container Apps rollout is now 5/5 issues closed; packets 03-05 and the dispatch plan moved to `completed/`. Marked complete and ready for exit-criteria review/archive; no archive move performed because downstream deploy verification should be reviewed by the operator.

### Package Scanning Rollout (ADR-0009)
**Status:** In Progress  
**Scope:** Kernel, Auth, Data, Transport, Vault, Pulse, Notify, Web.Rest  
**Initiative:** `adr-0009-package-scanning-rollout`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Wire CI scan workflows and dynamic release notes across all Nodes. Standardizes vulnerability scanning and auto-generates release summaries from commit history.

**Tracking:**
- [x] Kernel wire up CI scan workflows (Kernel#14 closed 2026-04-16)
- [x] Auth wire up CI scan workflows (Auth#6 closed 2026-04-12)
- [x] Data wire up CI scan workflows (Data#5 closed 2026-04-16)
- [x] Transport wire up CI scan workflows (Transport#14 closed 2026-04-12)
- [x] Vault wire up CI scan workflows (Vault#13 closed 2026-04-12)
- [x] Pulse wire up CI scan workflows (Pulse#2 closed)
- [x] Notify wire up CI scan workflows (Notify#2 closed)
- [x] Web.Rest wire up CI scan workflows (Web.Rest#5 closed 2026-04-16)

> **Sync (2026-05-16):** 8/8 issues remain closed (100%). Older completed manifest entries were pruned; packet files remain archived in `completed/`. Rollout remains ready for archive/exit-criteria review.

### Vault.Rotation Bring-Up
**Status:** In Progress  
**Scope:** Vault.Rotation, Architecture, Actions  
**Initiative:** `vault-rotation-bring-up`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Scaffold HoneyDrunk.Vault.Rotation as a deployable Function Node, wire OIDC + RBAC, and complete ADR-0006 Tier-2 operational setup.
**Tracking:**
- [x] Architecture catalog registration + routing keywords (Architecture#7 closed 2026-04-11)
- [x] Architecture repo stubs (`repos/HoneyDrunk.Vault.Rotation/*`)
- [x] Repo scaffold implementation packet execution (Vault.Rotation#3 closed)
- [x] Managed identity + vault RBAC automation
- [x] Rotation function runtime + observability

> **Sync (2026-05-16):** Related ADR-0005/0006 Vault.Rotation packets remain closed, including scaffold and release-tag issues. Ready for archive/exit-criteria review.

### Grid v0.4 Stabilization
**Status:** In Progress  
**Scope:** Kernel, Transport, Vault, Auth, Web.Rest, Data  
**Description:** All Core Nodes aligned on Kernel 0.4.0 contracts. Canary tests passing across all boundaries.  
**Tracking:**
- [x] Kernel 0.4.0 released
- [x] Transport 0.4.0 aligned
- [x] Vault 0.2.0 aligned
- [x] Auth 0.2.0 aligned
- [x] Web.Rest 0.2.0 aligned
- [x] Data 0.3.0 aligned
- [ ] Notify aligned to Kernel 0.4.0 patterns
- [ ] Pulse aligned to Kernel 0.4.0 patterns

> **Sync (2026-04-16):** 6/8 items done. Core nodes (Kernel, Transport, Vault, Auth, Web.Rest, Data) all v0.4.0 aligned. Notify (v0.1.0) and Pulse (v0.1.0) have signal: Seed, blocked by Azure deployment per grid-health.json. No new progress in past 4 days. Core objectives met; Notify/Pulse deployment gated on infrastructure provisioning.

### Notification Subsystem Launch
**Status:** In Progress  
**Scope:** Notify  
**Description:** First release of HoneyDrunk.Notify with email (SMTP, Resend) and SMS (Twilio) providers.  
**Tracking:**
- [x] Abstractions and runtime packages
- [x] Email providers (SMTP, Resend)
- [x] SMS provider (Twilio)
- [x] Queue backends (Azure Storage, InMemory)
- [x] Background worker
- [x] Azure Functions deployment workflow
- [ ] Integration tests with live providers

> **Sync (2026-05-05):** 6/7 items done. Notify v0.2.0 released and the Azure Functions deploy workflow completed. Live provider integration tests remain as production-hardening work.

### Ops: Observability Pipeline
**Status:** In Progress  
**Scope:** Pulse  
**Description:** Multi-backend telemetry with Pulse.Collector as OTLP receiver.  
**Tracking:**
- [x] All sink implementations
- [x] Pulse.Collector with OTLP parsing
- [x] Health and readiness endpoints
- [ ] Production deployment of Pulse.Collector
- [ ] Dashboard templates for Grafana

> **Sync (2026-04-16):** 3/5 items done. Production Pulse.Collector deployment and Grafana dashboard templates remain. grid-health.json confirms active_blockers. No progress in 4 days; gated on deployment and dashboard work.

## Planned

### HoneyDrunk.Lore Bring-Up
**Status:** On Deck  
**Scope:** Lore, Architecture  
**Initiative:** `honeydrunk-lore-bringup`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Stand up HoneyDrunk.Lore as a flat-file LLM-compiled wiki. Repo scaffolded with `raw/`, `wiki/`, `output/`, `tools/` directories, CLAUDE.md schema doc, sourcing playbook, Obsidian vault configuration, Web Clipper, scheduled ingest agent, and OpenClaw sourcing skill. Inspired by the Karpathy LLM-wiki pattern. Flat-file-first — Knowledge/Agents integration deferred until those nodes exist.  
**Tracking:**
- [x] Lore#1: Repo scaffold + CLAUDE.md schema doc (closed)
- [x] Lore#2: Obsidian vault setup + Web Clipper (human-only) (closed)
- [x] Lore#3: Scheduled ingest agent (CronCreate) (closed)
- [x] Lore#4: sourcing-playbook.md (closed)
- [x] Lore#5: OpenClaw setup + Lore sourcing skill (closed)
- [x] Architecture#9: Catalog registration for HoneyDrunk.Lore (closed)

> **Sync (2026-05-16):** 6/6 issues remain closed (100%). Lore bring-up packets are closed and in the completed archive; ready for archive/exit-criteria review.

### Agent Kit
**Status:** On Deck  
**Scope:** AI  
**Description:** Agent execution runtime, tool abstraction, and memory. Foundation for AI-powered workflows across the Grid.  
