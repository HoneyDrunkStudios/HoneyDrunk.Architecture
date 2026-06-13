# Dispatch Plan — ADR-0055: Feature Flag and Progressive Rollout Strategy

**Initiative:** `adr-0055-feature-flags`
**ADR:** ADR-0055 (Proposed — flipped to Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0055 commits the Grid's first formal feature-flag substrate. It selects **Azure App Configuration's feature-flags surface** as the v1 backend (`Microsoft.FeatureManagement.AzureAppConfiguration`) — leveraging the App Configuration resource already provisioned per ADR-0005 — and names three flag categories with distinct lifecycle policies (`release`, `permission`, `operational`). The abstraction is `IFeatureGate` in `HoneyDrunk.Kernel.Abstractions`; the concrete implementation and the `TenantTargetingFilter` ship from a **new Node `HoneyDrunk.FeatureFlags`**. CI registration is enforced via per-Node `featureflags.json` + a Roslyn analyzer + a new reusable workflow `job-featureflags-validate.yml` in `HoneyDrunk.Actions`. Observability emits a structured `feature_flag_evaluated` event per evaluation via `HoneyDrunk.Pulse`/`HoneyDrunk.Observe`; permission and operational flips are audited via `HoneyDrunk.Audit`. The operator surface is a new `operator flags …` subcommand on the Operator Node CLI.

This initiative delivers the v1 substrate: the `IFeatureGate` contract + `InMemoryFeatureGate` in Kernel, the `HoneyDrunk.FeatureFlags` Node scaffold + App-Configuration-backed implementation + `TenantTargetingFilter`, the App Configuration feature-flag-surface walkthrough extension (label conventions per D9), the `job-featureflags-validate.yml` reusable workflow + the Roslyn analyzer NuGet, the Notify pilot release flag (Phase 2 end-to-end-loop validation), the `operator flags …` CLI subcommand, and the docs/governance (D13 anti-patterns into `review.md`, feature-flag-evaluation flow into `feature-flow-catalog.md`, D15 escalation triggers into `business/context/`, the `featureflags-v1.json` schema doc).

**Deliberately out of scope (deferred per the ADR's phasing):**

- **Phase 4 — Notify.Cloud per-tenant permission flag.** Notify.Cloud is **PDR-0002** — not yet a standup Node. The first permission flag for Cloud-only features wires when Notify.Cloud reaches standup; the substrate this initiative ships is the prerequisite.
- **Phase 5 — Consumer-app PDR consumers (Lately, Hearth, Currents, Arcadia, Curiosities).** Those Nodes adopt `IFeatureGate` from day one of their own standup, on the substrate this initiative ships.
- **Phase 6 — Escalation evaluation.** A Phase-6 review is a future operator action against observed flag count + flip frequency; not a packet here.

**10 packets across 5 waves**, targeting **5 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.FeatureFlags`, `HoneyDrunk.Actions`, `HoneyDrunk.Notify`, `HoneyDrunk.Operator`). 9 `Actor=Agent`, 1 `Actor=Human` (the App Configuration feature-flag-surface walkthrough — portal work). Several `Actor=Agent` packets carry Human Prerequisites (creation of the `HoneyDrunk.FeatureFlags` GitHub repo, git-tag/release of the Kernel/FeatureFlags packages at wave boundaries, App Configuration label seeding).

## Trigger

ADR-0055 is Proposed with no scope. The forcing functions from the ADR's Context:

- **ADR-0053 trunk-based development** explicitly defers the flag-system commitment to a future ADR (this one). Trunk-based dev's "decouple deploy from release" property requires application-level flags — without them, in-progress work either blocks the trunk or ships visible-but-broken.
- **Notify.Cloud (PDR-0002)** introduces per-tenant feature enablement; ADR-0015's Container Apps multi-revision traffic splitting cannot express "tenant A on, tenant B off" within a single revision.
- **The AI-sector standup wave (ADR-0016–0025)** introduces experimental code paths (alternative agent routing, eval-time-only capabilities, model swaps) that flags excel at.
- **Consumer-app PDRs (0003/0005/0006/0007/0008)** anticipate trunk-based development from day one of their standup.
- **ADR-0044 D3 category 11 and ADR-0047** assume a mechanism for testing flag-on and flag-off states; this ADR names it (`InMemoryFeatureGate` in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15).

## Scope Detection

**Multi-repo, multi-Node, with new-Node standup.** ADR-0055 ships:

- A new contract (`IFeatureGate`, `ITargetingContext`) in `HoneyDrunk.Kernel.Abstractions` and a test fixture (`InMemoryFeatureGate`) in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15.
- A **new Node `HoneyDrunk.FeatureFlags`** — standup governed by this ADR (D4 names it). Per the user's standing convention "new-Node standup gets its own ADR," ADR-0055 *is* that ADR.
- An extension to `HoneyDrunk.Actions` (new reusable workflow `job-featureflags-validate.yml` plus a Roslyn analyzer NuGet package).
- A pilot consumer change to `HoneyDrunk.Notify` (one release flag).
- A new subcommand on the `HoneyDrunk.Operator` CLI (depends on Operator's CLI shell being live — see Cross-Cutting Concerns).
- Catalog/governance edits in `HoneyDrunk.Architecture`.

**Contract is additive — no forced downstream cascade.** `IFeatureGate` and `ITargetingContext` are additive to `HoneyDrunk.Kernel.Abstractions`. Per ADR-0035 (additive minor bump) and ADR-0055 D14 Phase 1, this bumps `HoneyDrunk.Kernel` `0.7.0` → `0.8.0` (or the current state at execution time — see Version Bumps). Downstream Nodes that consume `HoneyDrunk.Kernel.Abstractions` are not forced to update; they adopt `IFeatureGate` when their own flagged code paths are written. The only consumer this initiative amends is `HoneyDrunk.Notify` (Phase 2 pilot, one release flag).

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog + schema + walkthrough)
- [ ] **00** — Architecture: Accept ADR-0055, add the two feature-flag invariants (pre-reserved numbers — see Invariant Numbering), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the `IFeatureGate` / `ITargetingContext` contracts and the new `honeydrunk-featureflags` Node in the Grid catalogs. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: author the `featureflags-v1.json` schema doc, the per-Node `featureflags.json` shape, and pin it for `https://schemas.honeydrunkstudios.com/featureflags-v1.json`. `Actor=Agent`. Blocked by: 00.
- [ ] **03** — Architecture: extend the App Configuration provisioning walkthrough with the feature-flag-surface section (D2 backend, D9 label conventions `dev`/`staging`/`prod`/`ci`); apply the label-default-state policy in the `dev` App Configuration resource. `Actor=Human`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — the contract foundation)
- [ ] **04** — Kernel: add `IFeatureGate`, `ITargetingContext`, and `InMemoryFeatureGate` to `HoneyDrunk.Kernel.Abstractions` / `HoneyDrunk.Kernel.Abstractions.Testing`. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Kernel`.**

### Wave 3 (Depends on Wave 2 — the FeatureFlags Node standup)
- [ ] **05** — FeatureFlags: stand up the `HoneyDrunk.FeatureFlags` Node — solution, packages, App-Configuration-backed `IFeatureGate` implementation, `TenantTargetingFilter`, in-memory test fixture, CI. `Actor=Agent`. Blocked by: 01, 02, 03, 04.

### Wave 4 (Depends on Wave 3 — CI validation + pilot — parallel)
- [ ] **06** — Actions: author `job-featureflags-validate.yml` reusable workflow and the Roslyn analyzer NuGet package for static flag-string discovery. `Actor=Agent`. Blocked by: 02 (schema), 04 (contract surface analyzed). Independent of 05 — the analyzer parses calls to `IFeatureGate.IsEnabledAsync` and reads `featureflags.json`; it does not require the App-Configuration backing to exist.
- [ ] **07** — Notify: pilot consumer — declare one release flag in `featureflags.json`, gate an in-progress feature behind `IFeatureGate.IsEnabledAsync`, verify the end-to-end loop (declare → use → CI validates → flip via App Configuration → log emitted). `Actor=Agent`. Blocked by: 05 (FeatureFlags package published), 06 (CI validation workflow).

### Wave 5 (Depends on Wave 4 — operator CLI + governance docs — parallel)
- [ ] **08** — Operator: add the `operator flags …` CLI subcommand per D11; wire permission/operational flip events to `HoneyDrunk.Audit` per D10. `Actor=Agent`. Blocked by: 05. **Conditional on Operator's CLI shell being live — see Human Prerequisites.**
- [ ] **09** — Architecture: roll the D13 anti-pattern checklist into `.claude/agents/review.md`, add the feature-flag-evaluation flow to `constitution/feature-flow-catalog.md`, document the D15 escalation triggers in `business/context/`. `Actor=Agent`. Blocked by: 00. (Independent of 04–08 — could run as early as Wave 2; grouped here for tidy filing.)

Packets within a wave run in parallel except where listed. Wave 4 packets 06 and 07 are independent — different repos — but 07 (Notify) hard-depends on 05 (the FeatureFlags package), so it cannot start until 05 ships. Wave 5 packet 09 is technically only blocked by 00 — its `dependencies:` frontmatter expresses that.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0055](./00-architecture-adr-0055-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Catalog: IFeatureGate + FeatureFlags Node](./01-architecture-featureflags-catalog-and-node-registration.md) | Architecture | Agent | 1 | 00 |
| 02 | [featureflags-v1.json schema doc](./02-architecture-featureflags-schema.md) | Architecture | Agent | 1 | 00 |
| 03 | [App Configuration feature-flag surface walkthrough](./03-architecture-appconfig-featureflag-surface-walkthrough.md) | Architecture | Human | 1 | 00 |
| 04 | [Kernel: IFeatureGate + ITargetingContext + InMemoryFeatureGate](./04-kernel-ifeaturegate-and-targeting-context.md) | Kernel | Agent | 2 | 00 |
| 05 | [HoneyDrunk.FeatureFlags Node standup](./05-featureflags-node-standup.md) | FeatureFlags | Agent | 3 | 01, 02, 03, 04 |
| 06 | [Actions: job-featureflags-validate.yml + Roslyn analyzer](./06-actions-featureflags-validate-and-analyzer.md) | Actions | Agent | 4 | 02, 04 |
| 07 | [Notify: pilot release flag end-to-end](./07-notify-pilot-release-flag.md) | Notify | Agent | 4 | 05, 06 |
| 08 | [Operator: operator flags CLI + Audit wiring](./08-operator-flags-cli-subcommand.md) | Operator | Agent | 5 | 05 |
| 09 | [Governance: review.md D13 + flow catalog + escalation doc](./09-architecture-review-flow-and-escalation.md) | Architecture | Agent | 5 | 00 |

## Invariant Numbering

Packet 00 adds the two invariants ADR-0055's Consequences names:

1. **Feature flags are evaluated through `IFeatureGate`, never via direct SDK calls to `Microsoft.FeatureManagement` or the App Configuration client.** Preserves backend reversibility (D15 escalation), audit hookup (D10), and PII scrubbing on log emission.
2. **Feature-flag names follow `{category}.{node}.{feature}` and are registered in the consuming Node's `featureflags.json` before first use.** CI gate per D6.

ADR-0055 explicitly says: "Final invariant numbers assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles per the ADR-0044 pattern." The current verified maximum in `constitution/invariants.md` is **53**. ADR-0055 is **not** in a pre-reserved batch — pick the next two free numbers at execution time (likely **54, 55**, but check at edit time against any sibling ADR-acceptance packets that landed first; never reuse a claimed number).

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 04 is the version-bumping packet. Confirm the current version at execution time. As of grid-health snapshot 2026-05-21, `HoneyDrunk.Kernel` is at `0.7.0`. If ADR-0042's `0.8.0` has shipped by execution time (per `adr-0042-idempotency` initiative), packet 04 here moves the next minor (e.g. `0.8.0` → `0.9.0`). If not, packet 04 bumps `0.7.0` → `0.8.0`. Per-package CHANGELOG: `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel.Abstractions.Testing` get entries (real new contracts + fixture); `HoneyDrunk.Kernel` runtime gets no per-package entry in this packet (alignment bump only — invariant 12/27).
- **`HoneyDrunk.FeatureFlags`** — packet 05 is the first packet on the solution (it stands the solution up). Ships `0.1.0` per the standup convention (a 0.x.y baseline for new Nodes; see HoneyDrunk.Audit `0.1.0` as the precedent).
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; packet 06 ships workflow YAML + a Roslyn analyzer NuGet package. The analyzer NuGet is versioned independently per the existing Standards/analyzer release pattern; consult the repo's existing release flow at edit time.
- **`HoneyDrunk.Notify`** — packet 07 amends Notify to consume `HoneyDrunk.FeatureFlags`. Whether it bumps depends on whether the change is functional (yes — a real flag-gated feature). Confirm at execution; the packet expects a minor bump.
- **`HoneyDrunk.Operator`** — packet 08 adds a CLI subcommand. Whether it bumps depends on Operator's release state at execution. Operator is currently at Seed/`0.0.0`; if its standup has shipped a `0.1.0` by the time this packet runs, the CLI subcommand bumps to the next minor.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only.

## Cross-Cutting Concerns

### Operator CLI dependency

Packet 08 adds the `operator flags …` subcommand to the Operator CLI. Operator is governed by **ADR-0018** (its own standup initiative, in progress at the time of this scoping). For packet 08 to execute, Operator must have a CLI shell — a `dotnet` console host with a verb-based command surface — already in place. ADR-0018's scaffold packet (the `HoneyDrunk.Operator` Node standup) is the prerequisite; if Operator's CLI shell is not yet shipped at execution time, packet 08 either (a) lands the CLI shell as part of the same PR if the scope can be bounded to "the flags subcommand plus minimum shell," (b) is deferred until Operator's standup lands far enough, or (c) is split — a follow-up to ADR-0018's standup track.

The recommendation, given the user's standing rule "new-Node standup gets its own ADR," is **(b)**: defer packet 08 if Operator's CLI shell does not exist when this initiative reaches Wave 5. The packet is written assuming the shell exists; its Human Prerequisites surface this gate explicitly.

### Flags vs config — the boundary lives in code review

ADR-0055 D12 names the flag/config boundary. The CI validator (D6) catches the obvious case (a non-boolean value declared as a flag fails registration). The judgment-call case ("this feature flag probably should be config; this config value probably should be a flag") is enforced by the `review` agent's rubric — packet 09 rolls the D13 anti-patterns into `.claude/agents/review.md` so the review agent applies them PR-by-PR.

### The two-name registration — `IFeatureGate` is *the* surface; the SDK is hidden

ADR-0055 D4 places `IFeatureGate` in `HoneyDrunk.Kernel.Abstractions`. The `Microsoft.FeatureManagement` SDK lives inside `HoneyDrunk.FeatureFlags` as an implementation detail — consumers depend on `HoneyDrunk.Kernel.Abstractions` (for the contract) and compose `HoneyDrunk.FeatureFlags` (for the App Configuration backing) at host startup, never reach for `IFeatureManager` directly. This is the **first new invariant** packet 00 adds. The Notify pilot (packet 07) and any future consumer must use only `IFeatureGate`; the analyzer in packet 06 may add a future rule flagging direct `IFeatureManager` consumption, but at v1 the invariant + review rubric carry the rule.

### Notify.Cloud and Phase 4 — deferred

ADR-0055 D14 Phase 4 wires `TenantTargetingFilter` into Notify.Cloud's tenant-tier resolution for the first **permission** flag. Notify.Cloud is **PDR-0002** — not yet a standup Node. This initiative ships the `TenantTargetingFilter` as part of packet 05 so it is *available* when Notify.Cloud reaches standup, but no packet here wires the first per-tenant permission flag — that is a Notify.Cloud-standup-track concern.

### Consumer-app PDR adoption — deferred

ADR-0055 D14 Phase 5 lists the consumer-app PDRs (Lately, Hearth, Currents, Arcadia, Curiosities) as adopters of `IFeatureGate` from day one of their standup. Each Node's adoption lands in its own standup initiative, on top of the substrate this initiative ships. Not in scope here.

### Roslyn analyzer scope — literal flag strings only

The Roslyn analyzer in packet 06 scans for `IFeatureGate.IsEnabledAsync("…")` and `GetVariantAsync<…>("…")` calls and validates the literal string is registered in the consuming Node's `featureflags.json`. ADR-0055 D6 explicitly notes "Variable-fed flag names are flagged as a separate warning — they defeat static analysis and should be avoided." The analyzer ships with both: a hard-error rule on undeclared literal flags, and a warning rule on non-literal flag-name arguments (variable, string-concat, interpolation). The analyzer is consumer-facing — it ships from `HoneyDrunk.Actions` (or `HoneyDrunk.Standards`, depending on which repo's release flow is the closer fit at execution time — packet 06's executor decides between the two; default to `HoneyDrunk.Actions` per ADR-0012's CI/CD-control-plane framing unless Standards is the better mechanical fit).

### App Configuration label seeding — D9 inversion

ADR-0055 D9 commits the "dev defaults on, staging/prod/ci default off" inversion. The mechanism is **not** `Microsoft.FeatureManagement`'s `RequirementType.Any/All` — it is per-label `enabled` definitions in App Configuration. Packet 03 seeds the label conventions; packet 05's `HoneyDrunk.FeatureFlags` consumes them; packet 06's CI validator enforces that every flag has both a `dev` and a non-dev label.

### Site sync

No site-sync flag. ADR-0055 is internal Core infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packets 00–02 (governance + catalog + schema):** revert the PR. ADR returns to Proposed; invariants and catalog entries removed. No runtime impact.
- **Packet 03 (App Configuration walkthrough + label seeding):** revert the walkthrough doc; in the Azure Portal, delete the dev/staging/prod/ci label conventions seeded by the human run. No runtime impact until a consumer composes the flag system.
- **Packet 04 (Kernel contracts):** revert the PR; `HoneyDrunk.Kernel` rolls back the version. Additive — no consuming Node depends on `IFeatureGate` until it composes it.
- **Packet 05 (FeatureFlags Node):** revert the PR; the `HoneyDrunk.FeatureFlags` repo loses the scaffold + first release. No host depends on it until the Notify pilot composes it (packet 07).
- **Packet 06 (CI workflow + analyzer):** revert the workflow YAML and the analyzer NuGet bump; consuming repos lose the validation gate but build is unaffected (the workflow is opt-in via `featureflags-validate: true` input).
- **Packet 07 (Notify pilot):** revert the PR; the gated feature returns to "always off" (or "always on," depending on the rollout state of the feature behind the flag); the `featureflags.json` entry is removed; the Notify solution version rolls back.
- **Packet 08 (Operator CLI):** revert the PR; the `flags` subcommand is removed; operators flip flags through the App Configuration portal directly (a documented fallback, not the supported path).
- **Packet 09 (governance docs):** revert the PR. Docs only.
- **Backend-level escape hatch:** ADR-0055 D15's escalation path (LaunchDarkly or self-hosted GrowthBook) is the architectural rollback for the *backend choice itself* — `IFeatureGate` stays, `HoneyDrunk.FeatureFlags.LaunchDarkly` (or `.GrowthBook`) backing comes online, consumers re-register their DI to the new backing. The migration is the cost of the new backing implementation + the export/import of the existing flag definitions to the new platform's storage shape; the contract surface and the operator CLI semantics are preserved.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

**Before pushing — `HoneyDrunk.FeatureFlags` repo creation.** Packet 05 targets `HoneyDrunkStudios/HoneyDrunk.FeatureFlags`. The repo must exist on GitHub before its issue can be filed. ADR-0055 D4 names the repo; the human-only prerequisite step is to create the empty GitHub repo (public per the user's "repos public by default" convention, with the standard `main` branch) before pushing this folder to `main`. This is recorded as a Human Prerequisite on packet 05.
