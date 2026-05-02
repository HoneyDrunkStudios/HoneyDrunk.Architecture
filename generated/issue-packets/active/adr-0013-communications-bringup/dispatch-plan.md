# Dispatch Plan: ADR-0013 Communications Bring-Up

**Date:** 2026-05-02
**Trigger:** ADR-0013 (Communications Orchestration Layer — HoneyDrunk.Communications) Accepted; catalog registration already complete
**Type:** Multi-repo (Architecture + new Communications repo)
**Sector:** Ops
**Upstream context references:** ADR-0013 (Communications Orchestration Layer — primary), ADR-0026 (Grid Multi-Tenant Primitives — cross-cutting tenancy requirement applied to every contract and store this initiative ships)
**Site sync required:** No (Communications is Seed; Studios will pick it up automatically once it ships its first package — the catalogs already reference it)
**Rollback plan:** Architecture-side edits revert cleanly via `git revert`. The new `HoneyDrunk.Communications` repo, if created and then deferred, can be archived rather than deleted (GitHub archive is non-destructive). The Phase 1 Abstractions package is additive — no breaking changes for any existing caller, since no caller exists yet. Phase 2 in-memory stores are local to the Communications runtime and have no cross-repo footprint to roll back.

## Cross-Cutting Requirement: ADR-0026 Tenancy Alignment

Every contract, in-memory store, and decision log entry in this initiative MUST land tenant-aware from day one. Retrofitting tenancy onto the welcome flow after Phase 2 ships means migrating an in-memory store that has barely had real callers — easy to overlook, hard to remember the original intent. The cost of designing it in now is one extra parameter on each store interface and one field on `DecisionLogEntry`. Specifically:

1. **`IPreferenceStore`** — lookups keyed by `(TenantId, RecipientHandle)`, never by `RecipientHandle` alone. The same human user across two tenants has two distinct preference rows.
2. **`ICadencePolicy`** — cadence state keyed by `(TenantId, RecipientHandle, IntentKind)`. Rate-limiting in one tenant must not affect cadence state in another.
3. **`DecisionLogEntry`** — `TenantId` is a first-class field from day one (in-memory in Phase 2; persisted in Phase 3). Adding it later means a migration on a table that barely exists.
4. **`TenantId` source** — consumers read tenancy from `IGridContext.TenantId` (typed `HoneyDrunk.Kernel.Abstractions.Identity.TenantId`, non-nullable per ADR-0026 D2). No stringly-typed propagation.
5. **Internal short-circuit** — when `TenantId.IsInternal` is true (sentinel from ADR-0026 D1), implementations short-circuit gracefully: cadence allows, preferences default to opted-in, decision log records with the Internal sentinel TenantId so the audit trail still reflects the tenant axis.

ADR-0026 itself ships its Kernel and Vault halves under a separate initiative. This initiative does **not** implement the Kernel-side `TenantId.Internal` sentinel, the type promotion of `IGridContext.TenantId`, `ITenantRateLimitPolicy`, or `IBillingEventEmitter` — those are owned by ADR-0026's own packets. What this initiative does is consume the Kernel-side primitives once they ship, so packets 04 and 05 are sequenced **after** ADR-0026 Kernel packets land (see Wave 3 dependency note below).

## Summary

ADR-0013 introduced HoneyDrunk.Communications as the decision and orchestration layer above Notify. Catalog registration (nodes.json, grid-health.json, relationships.json, contracts.json, modules.json, sector-interaction-map, feature-flow-catalog) is already complete and was shipped alongside the ADR. What remains is the **standup** — repo creation, scaffold, Phase 1 contracts, and Phase 2 welcome flow.

Per the "New-Node scaffolding needs its own ADR" convention, a new empty cataloged repo gets a standup ADR before the scaffold work runs. **ADR-0013 itself serves that purpose for Communications** — its Phase Plan (Phases 1–3) IS the standup plan, so this initiative does not spawn a separate scaffolding ADR.

This initiative ships **Phase 1 and Phase 2** (contracts + welcome flow). **Phase 3** (persistence via Data Node, production deployment on Container Apps, Pulse telemetry) is **deferred to a follow-up initiative** because:
- Persistence design depends on the Communications runtime having real flow state worth persisting (only true after Phase 2 ships)
- Production deployment depends on the broader Container Apps rollout completing for at least one peer Node (Notify.Worker per ADR-0015 wave 2)
- Pulse telemetry shape depends on what decisions Phase 2 actually emits

Five packets across two repos:

- 1 Architecture packet (repo context folder + ADR index + initiative trackers + roadmap)
- 1 Architecture packet (human-only chore — create the GitHub repo)
- 3 Communications packets (scaffold, Phase 1 contracts, Phase 2 welcome flow)

## Phase 3 — explicitly deferred

Tracking lives in three places so nothing gets lost:

1. **`initiatives/active-initiatives.md`** — this initiative's entry carries a "Next (Phase 3 — not yet scoped)" section
2. **ADR-0013 Phase Plan section** — canonical spec for what Phase 3 is
3. **`initiatives/roadmap.md`** — Phase 3 bulleted under Q3 2026 with infrastructure prerequisites

**Phase 3 triggers** (scope when these land):
- Phase 1 + Phase 2 packets all merged
- HoneyDrunk.Data persistence patterns are stable enough to host preference + flow state (Data is at v0.3.0 and stable today, so this gate is largely informational)
- ADR-0015 Container Apps rollout has shipped at least one peer Container App (Notify.Worker) so the deployment pattern is proven
- A real product surface needs persistent communication state (i.e., the in-memory stores from Phase 2 are observably insufficient)

## Execution Model

Manual on Codex Cloud, matching the ADR-0010 and ADR-0015 rollout patterns. Wave is execution guidance, not a filing gate — except for packets that target the new repo, which physically cannot file until the repo exists.

### Wave 1 — Architecture foundation + repo creation (parallel)

Run these first. They establish the context-folder identity and GitHub surface that Wave 2 consumes.

- [ ] `HoneyDrunk.Architecture`: Repo context folder + ADR index + initiative/roadmap trackers — [`01-architecture-adr-0013-acceptance.md`](01-architecture-adr-0013-acceptance.md)
- [ ] `HoneyDrunk.Architecture` (**human-only chore**): Create the `HoneyDrunk.Communications` GitHub repo — [`02-architecture-create-communications-repo.md`](02-architecture-create-communications-repo.md)
  - `Actor=Human`, `human-only` label. ~3-minute portal task. Root blocker for the scaffold packet below.

**Wave 1 exit criteria (before starting Wave 2 on Codex Cloud):**
- ADR-0013 index row in `adrs/README.md` reads `Accepted` (the user reports the ADR is accepted; verify the index matches)
- `repos/HoneyDrunk.Communications/` context folder committed (overview, boundaries, invariants, active-work, integration-points)
- `initiatives/active-initiatives.md` and `initiatives/roadmap.md` reflect this initiative
- `repos/HoneyDrunk.Notify/boundaries.md` and/or `integration-points.md` updated to acknowledge Communications as a downstream consumer (read-only awareness; no Notify code changes)
- `HoneyDrunkStudios/HoneyDrunk.Communications` repo exists on GitHub with default branch, branch protection mirroring HoneyDrunk.Vault, LICENSE/README committed

### Wave 2 — Repo scaffold (BLOCKED on Wave 1 — repo must exist)

- [ ] `HoneyDrunk.Communications` (**BLOCKED on `02-architecture-create-communications-repo.md`**): Scaffold solution + Abstractions and runtime project skeletons + repo metadata + validate-pr workflow — [`03-communications-scaffold.md`](03-communications-scaffold.md)
  - **Blocked on:** `02-architecture-create-communications-repo.md` closing. File this packet via the Next Steps script embedded in packet 02.

**Wave 2 exit criteria:**
- `HoneyDrunk.Communications.slnx` exists with two empty-shell projects (`HoneyDrunk.Communications.Abstractions`, `HoneyDrunk.Communications`)
- Repo-level `README.md` and `CHANGELOG.md` (entry `0.1.0`) present at solution root
- Per-package `README.md` and `CHANGELOG.md` present in each project directory
- `.editorconfig`, `Directory.Build.props`, `.gitignore` mirror HoneyDrunk.Vault
- `.github/workflows/pr-core.yml` consumes the `HoneyDrunk.Actions` reusable workflow
- PR traverses tier-1 gate (build + analyzers + unit tests if any + vuln scan + secret scan) and merges

### Wave 3 — Phase 1 contracts (BLOCKED on Wave 2 + ADR-0026 Kernel half)

- [ ] `HoneyDrunk.Communications`: Phase 1 — define the 5 seed contracts in Abstractions (tenant-aware shapes), wire Kernel integration in runtime, add publish workflow — [`04-communications-phase1-contracts.md`](04-communications-phase1-contracts.md)
  - **Blocked on:** `03-communications-scaffold.md` merged.
  - **Also blocked on:** ADR-0026 Kernel packets shipped — specifically the `IGridContext.TenantId` promotion to non-nullable `TenantId` and the `TenantId.Internal` sentinel + `IsInternal` predicate. Without these, the Phase 1 contract signatures cannot reference the strong type. If ADR-0026 Kernel half slips, this packet's executor must stop and surface the gap rather than fall back to `string?`-shaped tenancy.

**Wave 3 exit criteria:**
- `HoneyDrunk.Communications.Abstractions` contains `ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy` with full XML docs
- `IPreferenceStore` and `ICadencePolicy` signatures take `TenantId` (from `HoneyDrunk.Kernel.Abstractions.Identity`) as a first-class parameter; lookups are keyed by `(TenantId, ...)` not by recipient alone
- Runtime project has Kernel-integrated DI extension (`AddCommunications(...)`) wiring `IGridContext` (consumers read `gridContext.TenantId` as the typed `TenantId` per ADR-0026 D2), lifecycle hooks, telemetry — but no concrete orchestrator implementation yet (that's Phase 2)
- Publish workflow (`release-abstractions.yml`, tag-driven) added — Abstractions package can be published to NuGet via tag push
- Both projects bumped to `0.2.0` (Phase 1 is the bumping packet for shipped contracts)

### Wave 4 — Phase 2 welcome flow (BLOCKED on Wave 3)

- [ ] `HoneyDrunk.Communications`: Phase 2 — implement welcome email flow with in-memory preference + cadence stores, integrate `INotificationSender` — [`05-communications-phase2-welcome-flow.md`](05-communications-phase2-welcome-flow.md)
  - **Blocked on:** `04-communications-phase1-contracts.md` merged.

**Wave 4 exit criteria:**
- `WelcomeEmailIntent` (concrete `IMessageIntent`) implemented
- `InMemoryPreferenceStore`, `InMemoryCadencePolicy`, `InMemoryDecisionLog` implementations live in runtime; all three key state by `(TenantId, ...)`, never by recipient alone
- `DecisionLogEntry` carries `TenantId` as a first-class field (the audit trail records which tenant a decision was made for)
- `CommunicationOrchestrator` runtime reads `TenantId` from `IGridContext.TenantId` (typed, non-nullable per ADR-0026 D2), threads it into preference / cadence / decision log calls, and short-circuits when `TenantId.IsInternal` is true (Internal traffic skips preference + cadence enforcement; the decision log still records the entry stamped with the Internal sentinel)
- `CommunicationOrchestrator` runtime calls `INotificationSender` (NuGet dependency on `HoneyDrunk.Notify.Abstractions`) for the welcome email and schedules a 2-day follow-up
- Unit tests cover the decision branches (sent / suppressed by preference / suppressed by cadence) AND the cross-tenant isolation case (same RecipientHandle, two different TenantIds, independent preference + cadence state) AND the Internal short-circuit branch
- `HoneyDrunk.Communications.Tests` Canary project verifies integration with `HoneyDrunk.Notify.Abstractions` (using a stub `INotificationSender`)
- Solution version bumps to `0.3.0` per invariant 27 (every shipped change moves all projects together)

### Deferred — Phase 3 (persistence + production + Pulse)

Not in this initiative. See "Phase 3 — explicitly deferred" above. A follow-up initiative `adr-0013-communications-phase3` will scope it once the listed triggers fire.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and the Wave 4 exit criteria are met, the entire `active/adr-0013-communications-bringup/` folder moves to `archive/adr-0013-communications-bringup/` in a single commit. Partial archival is forbidden.

## `gh` CLI Commands — File Fileable Issues In One Pass

Paths are relative to the `HoneyDrunk.Architecture` repo root. Packets 03–05 against `HoneyDrunk.Communications` are excluded from this batch — they are filed by the Next Steps script inside packet 02 (for packet 03) and then by hand once Wave 3 / Wave 4 are ready (packets 04 and 05). Filing 04 and 05 against an empty repo is technically possible but premature — the repo must have a buildable scaffold first or the review agent has nothing to anchor against.

```bash
PACKETS="generated/issue-packets/active/adr-0013-communications-bringup"

# --- Wave 1: Foundation ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Accept ADR-0013 — Communications context folder, ADR index, initiative + roadmap, Notify boundary refresh" \
  --body-file $PACKETS/01-architecture-adr-0013-acceptance.md \
  --label "feature,tier-2,meta,docs,catalog,adr-0013,wave-1"

# Wave 1 human-only chore — create the HoneyDrunk.Communications GitHub repo
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Create HoneyDrunk.Communications GitHub repo (human-only, gates Communications scaffold)" \
  --body-file $PACKETS/02-architecture-create-communications-repo.md \
  --label "chore,tier-1,meta,new-node,adr-0013,human-only,wave-1"

# --- Wave 2: Scaffold (filed by packet 02's Next Steps after repo exists) ---
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Communications \
#   --title "Scaffold HoneyDrunk.Communications repo, solution, and project skeletons" \
#   --body-file $PACKETS/03-communications-scaffold.md \
#   --label "feature,tier-3,new-node,ops,scaffolding,adr-0013,wave-2"

# --- Wave 3: Phase 1 contracts (file after Wave 2 merges) ---
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Communications \
#   --title "Phase 1: define 5 seed contracts in Abstractions and wire Kernel integration" \
#   --body-file $PACKETS/04-communications-phase1-contracts.md \
#   --label "feature,tier-2,ops,contracts,adr-0013,wave-3"

# --- Wave 4: Phase 2 welcome flow (file after Wave 3 merges) ---
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Communications \
#   --title "Phase 2: welcome email flow with in-memory stores and Notify integration" \
#   --body-file $PACKETS/05-communications-phase2-welcome-flow.md \
#   --label "feature,tier-2,ops,workflow,adr-0013,wave-4"
```

After filing, add each issue to The Hive (`gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>`), set board fields per `infrastructure/github-projects-field-ids.md` (Wave, Initiative = `adr-0013-communications-bringup`, Node = `honeydrunk-communications`, Tier, Actor = Agent/Human), and wire `addBlockedBy` relationships:

- `03-communications-scaffold` blocked-by `01-architecture-adr-0013-acceptance`
- `03-communications-scaffold` blocked-by `02-architecture-create-communications-repo`
- `04-communications-phase1-contracts` blocked-by `03-communications-scaffold`
- `05-communications-phase2-welcome-flow` blocked-by `04-communications-phase1-contracts`

## Handoff Documents

- [`handoff-wave2-scaffold.md`](handoff-wave2-scaffold.md) — read at the Wave 1 → Wave 2 transition (after packets 01 and 02 close, before packet 03 ships against the new repo)

## Notes

- **Catalogs are already done.** `nodes.json`, `relationships.json`, `contracts.json`, `grid-health.json`, `modules.json`, `sector-interaction-map.md`, `feature-flow-catalog.md` were updated at ADR drafting time. Packet 01 confirms they are intact and adds only the missing pieces (repo context folder, ADR index status, trackers).
- **No invariant additions.** ADR-0013 does not introduce new invariants. Communications operates within existing invariants (1–4 dependency rules, 11–12 packaging, 13 XML docs, 16 test isolation, 23–27 work-tracking + versioning). No `constitution/invariants.md` edits.
- **Naming rule applied.** Per the Grid-wide naming rule (records drop `I`, interfaces keep `I`), the five Phase 1 contracts are interfaces (`ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`) and stay I-prefixed. Concrete record types (e.g., `MessageDecision`, `RecipientHandle`, `CadenceWindow`) introduced in Phases 1–2 must NOT carry the `I` prefix.
- **No new repo for Communications.Tests.** Per invariant 16, tests live in dedicated `.Tests` or `.Canary` projects within the same repo — `HoneyDrunk.Communications.Tests` (unit) and `HoneyDrunk.Communications.Canary` (cross-Node integration with Notify.Abstractions) both live inside the Communications repo, scaffolded as empty placeholders in Wave 2 and populated in Wave 3 / Wave 4.
- **Boundary discipline.** Communications consumes `HoneyDrunk.Notify.Abstractions` only — never the runtime, never a provider package. The Phase 2 packet introduces this NuGet reference and acceptance criteria explicitly verify the runtime is not pulled in (invariant 2: runtime packages depend on Abstractions, never on other runtime packages at the same layer).
- **Phase 3 is real and tracked.** It is deferred for sound architectural reasons — persistence schema design is hard to do well before there is real flow state — not because it has been forgotten.

## Known Gaps (pre-existing — not owned by this initiative)

- **`infrastructure/github-projects-field-ids.md` does not exist.** Both the "After filing" guidance above and packet 02's Next Steps script reference it as the source of truth for board custom-field option IDs. This is a pre-existing dangling reference also relied on by ADR-0010 and ADR-0015 dispatch plans. **Consequence for this initiative:** the human executing packet 02 must currently hand-populate Wave / Initiative / Node / Tier / Actor field values via the GitHub UI or by copy-pasting IDs from another already-filed packet's project-item state. Recommendation: ship `infrastructure/github-projects-field-ids.md` as a **separate standalone packet**, not as part of this initiative.
