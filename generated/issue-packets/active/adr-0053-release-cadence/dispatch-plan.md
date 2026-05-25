# Dispatch Plan — ADR-0053: Environments, Branching, and Release Cadence

**Initiative:** `adr-0053-release-cadence`
**ADR:** ADR-0053 (Proposed → Accepted via packet 00)
**Sector:** Meta / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0053 commits what every other recent operational ADR has been quietly presuming: **three always-on environments (`dev`, `staging`, `prod`), trunk-based branching off `main`, short-lived feature branches (5-day target / 7-day stale / 30-day auto-close), squash merge by default, automatic `main`→`dev` deploys with tag-driven promotion (`staging-{date}`, `prod-{date}` per ADR-0033), per-Node release-as-needed cadence with a monthly "at-least-one prod release or 'no changes' CHANGELOG entry" floor, mandatory `dotnet run` local-dev parity against InMemory/Testcontainers, and a v1 single-subscription + environment-RBAC isolation model that splits to subscription-per-environment when the first paying tenant lands.**

The ADR closes the load-bearing gap behind ADR-0011 (review), ADR-0015 (Container Apps), ADR-0032 (PR validation), ADR-0033 (env-gated deploys), and ADR-0044 (AI-PR discipline). It unblocks the Notify.Functions / Notify.Worker / Pulse.Collector Azure bring-up that has been the top item on `current-focus.md` for weeks — those Nodes finally have a named, committed environment topology to deploy against.

This initiative delivers: ADR acceptance + the three new invariants (numbers **81, 82, 83**); the `infra/{env}/` Bicep module set for `dev`/`staging`/`prod` per D16 Phase 1 with paired Azure-portal walkthroughs (so the work is reviewable in both Bicep and click-by-click form); a `catalogs/services.json` schema extension adding the `environments: [...]` field per service per Consequences; the HoneyDrunk.Actions reusable deploy workflows amended with an `environment` parameter and the D15 self-approval gate (Phase 2); three Actions workflows for branch-lifetime discipline (stale-PR alert + 30-day auto-close + branch-prefix validation, Phase 4); the local-dev parity audit deliverable (`## Quick Start` per-Node template + audit playbook, Phase 5); and the monthly CHANGELOG cadence enforcement Actions workflow (Phase 6).

**9 packets across 3 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`). All 9 are `Actor=Agent` by default; packet 02 (Bicep + portal walkthroughs for `dev` provisioning) carries Human Prerequisites — Azure-Portal resource-group/RBAC creation and budget-acceptance clicks — but the *artefact authoring* (Bicep + walkthrough doc) is fully delegable, so it stays `Actor=Agent`.

**D16 Phase 3** (Notify.Functions / Notify.Worker / Pulse.Collector Azure bring-up against the new topology) is **deliberately NOT a new packet here**. Those three services already have open issues in the `adr-0015-container-apps-rollout` initiative (`Notify#3`, `Notify#4`, `Pulse#3`) and the `adr-0033-deploy-trigger-model` initiative (`Notify#19`, `Notify#20`, `Pulse#18`); adding a fourth set of packets covering the same code paths would duplicate work and violate the "one issue = one logical change" rule. This initiative provides the topology those packets consume — see the Cross-Cutting Concerns section on Phase 3 hand-off.

**D16 Phase 7** (subscription split when the first paying tenant arrives) is also explicitly deferred — the trigger is "first paying tenant lands" per D3 and PDR-0002. The mechanical path is recorded in this dispatch plan and in packet 00's acceptance text; no packet is filed until that trigger fires.

## Trigger

ADR-0053 is Proposed with no scope. The forcing functions from the ADR Context: (1) **ADR-0033's** tag→environment mapping presumes named environments that are not committed anywhere; (2) **ADR-0015's** multi-revision Container Apps strategy presumes deploy targets that are not committed; (3) **ADR-0011 / ADR-0032 / ADR-0044** presume a branching model that no ADR has written down; (4) the **Notify/Pulse Azure bring-up** has been the #1 blocker on `current-focus.md` for weeks, waiting on this exact topology decision. Landing the ADR's decisions as live artefacts (Bicep + walkthroughs + Actions workflows + the local-dev audit playbook + the cadence enforcement workflow) unblocks that bring-up and removes a class of "implicit topology" assumption from the ADR set.

## Scope Detection

**Multi-repo.** ADR-0053 touches `HoneyDrunk.Architecture` (acceptance, three invariants, catalog schema extension, Bicep modules + portal walkthroughs, the local-dev Quick Start template + audit playbook, governance/index updates) and `HoneyDrunk.Actions` (the reusable deploy workflow's `environment` input + D15 self-approval gate; the stale-PR / auto-close / branch-prefix-validation workflows; the monthly CHANGELOG cadence workflow).

**No Node code touched in this initiative.** D11's local-dev parity requirement is delivered as a template + per-Node audit *playbook*, not as 12+ premature per-Node packets. Each Node owns its own `repos/{name}/overview.md` `## Quick Start` section work — applying the template lands in each Node's own track (mirroring ADR-0045 packet 07's "playbook, not per-Node packets" decision).

**No new-Node scaffolding.** Every target repo already exists. No empty cataloged repo is touched; no standup ADR is needed.

## Wave Diagram

### Wave 1 (No Dependencies — governance + foundation, parallel)

- [ ] **00** — Architecture: Accept ADR-0053, add the three environments/branching/cadence invariants (numbers **81, 82, 83**), register the initiative. `Actor=Agent`. Blocked by: nothing.
- [ ] **01** — Architecture: extend `catalogs/services.json` schema with `environments: [dev, staging, prod]` field; document branching/cadence conventions in `infrastructure/conventions/` and `routing/sdlc.md` per D4–D7, D9. `Actor=Agent`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — environment substrate + Actions workflow plumbing, parallel)

- [ ] **02** — Architecture: Author `infra/{env}/` Bicep modules for `dev`/`staging`/`prod` per D2 + the paired Azure-Portal walkthrough(s) per the operator's standing preference; execute `dev` provisioning. `Actor=Agent`. Blocked by: 00. **Human Prerequisites:** Azure-Portal resource-group/RBAC/budget steps for `dev`.
- [ ] **03** — Actions: amend `job-deploy-container-app.yml` and `job-deploy-function.yml` with an `environment` input + the D15 self-approval gate on the prod path. `Actor=Agent`. Blocked by: 00.
- [ ] **04** — Actions: author `nightly-pr-stale-alert.yml` (D6 7-day stale comment) and `weekly-pr-auto-close.yml` (D6 30-day auto-close with `flagged-keep-open` escape hatch). `Actor=Agent`. Blocked by: 00. (Independent of 02/03 — parallel.)
- [ ] **05** — Actions: amend `pr-core.yml` with a branch-prefix validation step that asserts the head branch matches `{feat|fix|chore|docs|refactor|codex|copilot|claude|release}/.+` per D5. `Actor=Agent`. Blocked by: 00. (Independent of 02/03/04 — parallel.)

### Wave 3 (Depends on Wave 2 — operational substrate, parallel)

- [ ] **06** — Architecture: Author the local-dev `## Quick Start` template (per-Node section template + the "first 60 seconds" audit checklist per D11). `Actor=Agent`. Blocked by: 00. (Independent of 02–05 — parallel; sequenced into Wave 3 only for tidy filing.)
- [ ] **07** — Actions: author `monthly-changelog-cadence.yml` per D9 / D16 Phase 6 — check every Live Node for either a prod deploy in the past 30 days or a "no changes this month" CHANGELOG entry; open a Grid-health alert for any miss. `Actor=Agent`. Blocked by: 03. (Reuses the tag → environment mapping packet 03 finalizes.)
- [ ] **08** — Architecture: Per-Node `## Quick Start` audit using packet 06's template; surface any Node that misses the 60-second target as a follow-up packet in that Node's own track (not pre-written here). `Actor=Agent`. Blocked by: 06.

Packets within a wave run in parallel. Cross-wave sequencing is strict.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0053](./00-architecture-adr-0053-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Environments catalog schema + conventions](./01-architecture-environments-catalog-and-conventions.md) | Architecture | Agent | 1 | 00 |
| 02 | [`infra/{env}/` Bicep modules + dev portal walkthrough](./02-architecture-infra-env-bicep-and-walkthrough.md) | Architecture | Agent | 2 | 00 |
| 03 | [Actions: `environment` input + self-approval gate](./03-actions-environment-input-and-self-approval-gate.md) | Actions | Agent | 2 | 00 |
| 04 | [Actions: stale-PR + auto-close workflows](./04-actions-stale-pr-and-auto-close-workflows.md) | Actions | Agent | 2 | 00 |
| 05 | [Actions: branch-prefix validation in `pr-core.yml`](./05-actions-branch-prefix-validation.md) | Actions | Agent | 2 | 00 |
| 06 | [Local-dev `## Quick Start` template + audit playbook](./06-architecture-local-dev-quick-start-template-and-audit-playbook.md) | Architecture | Agent | 3 | 00 |
| 07 | [Actions: monthly CHANGELOG cadence workflow](./07-actions-monthly-changelog-cadence-workflow.md) | Actions | Agent | 3 | 03 |
| 08 | [Per-Node Quick Start audit execution](./08-architecture-per-node-quick-start-audit-execution.md) | Architecture | Agent | 3 | 06 |

## Cross-Cutting Concerns

### D16 Phase 3 — Notify/Pulse Azure bring-up is delegated to in-flight initiatives

ADR-0053 D16 Phase 3 reads: "the currently-blocked Notify.Functions / Notify.Worker / Pulse.Collector deploys (per `current-focus.md`) are the first deploys against this topology." Those deploys are already tracked by two open in-flight initiatives:

- `adr-0015-container-apps-rollout` — `Notify#3`, `Notify#4`, `Pulse#3` (Azure bring-up against Container Apps).
- `adr-0033-deploy-trigger-model` — `Notify#19`, `Notify#20`, `Pulse#18` (environment-gated trigger model).

**This initiative does not file a fourth set of packets covering the same three services.** Instead, packet 02 provisions the `dev` environment and the operator references its Bicep + walkthrough output when the existing bring-up packets land. The handoff path:

1. Packet 02 lands `dev` resource group, RBAC, App Configuration, Log Analytics workspace, and any cross-cutting per-environment shared resources.
2. The existing `Notify#3` / `Notify#4` / `Pulse#3` PRs build against the now-provisioned `dev` topology — their consumer workflows (per `adr-0033-deploy-trigger-model`) already accept an `environment` input through packet 03's new wiring.
3. No coordination edge is needed from this initiative back to those packets — they pull from the topology this initiative ships, not the other way around.

If the existing bring-up packets need refinement to reflect ADR-0053's environment topology (e.g. resource-group naming alignment), the refinement is a small follow-up in that initiative, not a new packet here.

### D16 Phase 7 — subscription split is deferred behind a real trigger

ADR-0053 D3 v2 / D16 Phase 7 says the subscription split (`sub-honeydrunk-prod` carved out from `sub-honeydrunk-nonprod`) happens "when PDR-0002 / ADR-0050 lands Notify Cloud's first paying tenant." That trigger has not fired. No packet is filed here for Phase 7. When the trigger fires, the subscription split is a separate small initiative (1–2 packets: Azure portal/CLI work + a one-time Bicep state migration) — record the trigger and the mechanical steps in this dispatch plan's history; do not pre-author the packets.

### Bicep vs portal — both, in packet 02

ADR-0053 D16 Phase 1 reads "**Author `infra/{env}/` Bicep modules**." The operator's standing preference (per the memory record) is "Azure Portal over CLI" for infra-provisioning walkthroughs. **Both are honored in packet 02:** the Bicep module is the deploy artefact (versioned, idempotent, the CI's hook for provisioning new environments mechanically); the paired Azure-Portal walkthrough is the human-facing review surface and the bootstrap path for the first execution. ADR-0077 (Infrastructure-as-Code Bicep) is the governing IaC ADR; ADR-0053 leans on it.

The walkthrough records the same resource shape the Bicep produces; it does not invent a parallel topology. If a future operator review prefers the walkthrough's resource shape over the Bicep's, the Bicep is amended (not the walkthrough), and the divergence is recorded in the packet's PR body.

### Local-dev Quick Start — template + audit, not pre-written per-Node packets

D11 commits "every Node must boot locally with `dotnet run` against either InMemory contract-compatible fakes or Testcontainers-driven Tier 2b dependencies." Each Live Node's `repos/{name}/overview.md` gets a `## Quick Start` section. Writing 12+ packets one per Node would prematurely decompose work that has not been validated against each Node's actual boot path. **Packet 06 ships the template + the per-Node audit checklist; packet 08 runs the audit and identifies which Nodes need work.** Each gap becomes a small follow-up in that Node's own track — same pattern as ADR-0045 packet 07's playbook.

### CHANGELOG cadence workflow — depends on a tag → environment mapping that already exists

D9 commits "every Live Node ships at least one prod release per calendar month OR an explicit 'no changes this month' CHANGELOG entry." Packet 07's monthly workflow scans every Live Node repo for either a `prod-{date}` tag in the past 30 days (per ADR-0033's tag scheme) or a `## [no changes]` entry under the dated CHANGELOG block. Misses surface as Grid-health alerts. Packet 07 depends on packet 03 — packet 03 finalizes the `environment` input convention the cadence workflow's "deployed within the last 30 days" check leans on.

### Site sync

No site-sync flag. ADR-0053 is internal Meta-sector governance — no public-facing Studios website content changes. (Studios' own deploy story is touched by ADR-0053 but the website's *content* is not.)

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/Bicep/Markdown edits only.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; workflow YAML changes. The repo's `CHANGELOG.md` (if it keeps one for the workflow surface) is updated per the existing repo convention from each Actions packet.

No `.csproj` versions touched in this initiative — every packet is YAML, Markdown, JSON, or Bicep.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the three invariants and the catalog schema extension are removed. No runtime impact.
- **Packet 02 (Bicep + dev walkthrough + dev provisioning):** revert the PR pulls the Bicep module out of the repo. The provisioned `dev` resources are *not* automatically deleted — destruction is a deliberate human portal action (cost-bearing resources should not be deleted by a revert). The walkthrough's "deprovisioning" section documents the clean-tear-down path.
- **Packet 03 (Actions deploy workflow `environment` input + self-approval gate):** revert the workflow edits. The `environment` input was optional with a default; existing consumers are unaffected. The self-approval gate going away means prod deploys lose the friction step — flag as an operational concern in the revert PR body.
- **Packet 04 (stale-PR + auto-close workflows):** revert the workflow files. No PRs are auto-closed by absence; the workflows are creating side effects, not maintaining state. Outstanding stale-PR comments stay; outstanding auto-close annotations stay.
- **Packet 05 (branch-prefix validation):** revert the `pr-core.yml` step. PRs with non-conforming branch names stop failing. No backfill needed.
- **Packets 06, 08 (Quick Start template + audit):** revert the docs/audit PR. No runtime impact.
- **Packet 07 (monthly CHANGELOG cadence workflow):** revert the workflow file. No Grid-health alerts are created by absence; existing alerts stay until manually resolved.

**Operational escape hatch for packets 04, 05, 07:** the new Actions workflows are gated by an opt-in input or an explicit on-schedule trigger. If any workflow starts producing false-positive noise (e.g. stale-PR alerts on PRs the operator is actively reviewing), flip the schedule input off rather than reverting code — same one-input-change pattern as ADR-0045 packet 07's release-annotation gate.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
