# Dispatch Plan — ADR-0017 HoneyDrunk.Capabilities Standup

**Initiative:** `adr-0017-honeydrunk-capabilities-standup`
**Sector:** AI
**Governing ADR:** [ADR-0017 — Stand Up the HoneyDrunk.Capabilities Node](../../../../adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md) (Proposed 2026-04-19; stays Proposed across all four packet PRs. Flips to Accepted only after every packet in this initiative is closed, as a separate post-merge housekeeping step the scope agent runs — see "Status-flip handling" below.)
**Trigger:** ADR-0017 in the Proposed queue. Five AI-sector Nodes (Agents, Operator, Memory, Knowledge, Evals) plus every domain Node that exposes agent-callable tools (Data, Notify, Vault) are blocked on `HoneyDrunk.Capabilities.Abstractions` existing. This initiative builds the tool-registry and dispatch substrate that unblocks them.
**Type:** Multi-repo (3 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Capabilities` + the human chore that creates the latter)
**Site sync required:** No (scaffold-only; no public-API surface change needs site update yet — when 0.1.0 ships and downstream Nodes start consuming, a site-sync follow-up may be warranted)
**Rollback plan:** Each packet is a single PR. Rollback is `git revert`. The new `HoneyDrunk.Capabilities` repo's `0.1.0` tag is published only after the human pushes the tag — which is post-merge — so a rollback before tag push is just a revert. After tag push, NuGet packages are immutable but unconsumed at this point in the rollout (downstream Nodes haven't started yet).

## Summary

ADR-0017 is the standup ADR for `HoneyDrunk.Capabilities`. It decides what the Node owns (D1), the package families (D2 — `Abstractions`, runtime, `Testing`), the four exposed contracts (D3 — `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, `ICapabilityGuard`), naming-collision disambiguation (D4), Auth as the authorization root (D5/D10), versioning principle (D6), one-way telemetry to Pulse (D7), the contract-shape canary (D8), and the downstream coupling rule (D9). None of that has been built — the AI repo's catalog entry exists but the GitHub repo does not.

Four packets land the work:

1. **Architecture catalog registration + integration-points** — reconcile `contracts.json` (deprecate `ICapability`/`ICapabilityPermission`, add the four D3 contracts), update `relationships.json` exposes, refresh `grid-health.json`, refresh `nodes.json` and `ai-sector-architecture.md` to match D3 names and the D7 telemetry direction, refresh `repos/HoneyDrunk.Capabilities/overview.md` to drop `ICapabilityDescriptor` (interface) in favor of `CapabilityDescriptor` (record), add a new `repos/HoneyDrunk.Capabilities/integration-points.md`, and update the active-initiatives tracker. Does **not** flip ADR-0017's Status — that is a separate post-merge housekeeping step.
2. **Constitution invariants** — four new invariants from D9, D6, D5/D10, D8 added to `constitution/invariants.md` at the next four free numbers (currently 43/44/45/46 assuming ADR-0016 lands first and takes 40/41/42; collision check at edit time may shift these).
3. **Create the HoneyDrunk.Capabilities GitHub repo** — human-only org-admin chore. The GitHub repo does not exist yet. Repo creation is not delegated to agents.
4. **HoneyDrunk.Capabilities scaffold** — empty repo to first-shippable state. Solution, three packages (`HoneyDrunk.Capabilities.Abstractions`, `HoneyDrunk.Capabilities`, `HoneyDrunk.Capabilities.Testing`), four contracts in `Abstractions`, default registry/invoker/guard implementations in the runtime, in-memory registry/dispatcher fixture in `Testing`, five CI workflow files including the contract-shape canary scoped to `Abstractions` per ADR-0017 D8.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (sequential)
   ├─ Architecture: 01-architecture-capabilities-catalog-registration
   └─ Architecture: 02-architecture-capabilities-invariants
       Blocked by: 01 (so the invariant text aligns with the contract surface 01 lands)

Wave 2: GitHub repo creation (human-only, parallel-able with Wave 1 in clock time
        but sequenced after Wave 1 here so the tracking issue lands once the
        catalogs already point at the eventual repo)
   └─ Architecture: 03-architecture-create-capabilities-repo
       Blocked by: 01

Wave 3: Capabilities repo scaffold
   └─ HoneyDrunk.Capabilities: 04-capabilities-node-scaffold
       Blocked by: 01, 02, 03
```

In practice 01 and 02 are both Architecture-repo packets touching different files (catalogs/integration-points vs constitution), so they could be reviewed as a single PR. They are kept as separate packets to honor the "one logical change per packet" rule and to give a clean review surface for each.

Packet 03 is human-only and gates packet 04 because the repo it creates is the target repo of packet 04 — `file-packets.sh` cannot file an issue against a repo that does not exist yet.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + integration-points](./01-architecture-capabilities-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add four new invariants for D9 / D6 / D5+D10 / D8](./02-architecture-capabilities-invariants.md) | Architecture | 1 | Agent | 01 |
| 03 | [Create `HoneyDrunk.Capabilities` GitHub repo (human-only)](./03-architecture-create-capabilities-repo.md) | Architecture | 2 | Human | 01 |
| 04 | [Stand up `HoneyDrunk.Capabilities` — solution, three packages, contracts, CI, in-memory testing fixture](./04-capabilities-node-scaffold.md) | HoneyDrunk.Capabilities | 3 | Agent | 01, 02, 03 |

## Phase Mapping

- **Wave 1 (packets 01 + 02) = ADR-0017's "If Accepted" catalog/constitution obligations.**
  - Packet 01 covers `contracts.json` reconciliation, `grid-health.json` refresh, and the new `integration-points.md`. Packet 01 does **not** flip ADR-0017's Status — that is handled separately post-merge (see "Status-flip handling" below).
  - Packet 02 covers the invariants ADR-0017 explicitly delegates to the scope agent at acceptance.
- **Wave 2 (packet 03) = the human-only repo creation chore.** Surfaced as its own packet so it lives on The Hive board with `Actor=Human` and the `human-only` label, instead of being an implicit prerequisite of packet 04.
- **Wave 3 (packet 04) = the standup itself.** Three packages (not six, unlike AI), four contracts, an in-memory fixture in a separate `Testing` NuGet artifact rather than a `Providers.*` slot per ADR-0017 D2.

## Filing-order rule

Packet 04 hard-codes invariant numbers in its body and acceptance criteria. Filed packets are immutable (invariant 24). Therefore:

**Packet 02 must be filed, its PR merged, and the assigned invariant numbers locked in `constitution/invariants.md` before packet 04 is filed.**

If packet 02's collision check at edit time forces a renumber away from the assumed 43/44/45/46 — for example because ADR-0016 lands first and takes 40/41/42 (consuming the next-three-free that ADR-0026 left at 39), then ADR-0010 Phase 1 lands and takes 29-30, or some other ADR grabs slots in the interim — the packet 04 source file at `generated/issue-packets/active/adr-0017-honeydrunk-capabilities-standup/04-capabilities-node-scaffold.md` MUST be amended in place before push (it has not been filed yet at that point — invariant 24's pre-filing carve-out applies).

**Packets 02 and 04 cannot be filed in the same push.** Concretely:

1. Push packets 01 and 02 (they may travel together — packet 02's `dependencies: ["packet:01"]` wires the blocking edge automatically).
2. Push packet 03 in the same wave or shortly after (it depends only on 01).
3. Wait for packet 02's PR to merge so the assigned invariant numbers actually land in `constitution/invariants.md`.
4. Wait for packet 03 to close (the repo must exist before packet 04 can be filed against it).
5. If the numbers shifted away from the assumed 43/44/45/46, edit `04-capabilities-node-scaffold.md` in place to match (pre-filing carve-out under invariant 24).
6. Push packet 04.

Packet 02's acceptance criteria call this out; packet 04's body assumes the lock has happened.

## What This Initiative Does **NOT** Deliver

The five AI-sector Nodes that consume Capabilities (Agents, Operator, Memory, Knowledge, Evals) are **not** delivered by this initiative. The initiative unblocks them, but each gets its own bring-up under its own standup ADR per the user's "new-Node scaffolding gets its own ADR/packet" rule.

Tool implementations from domain Nodes (Data, Notify, Vault registering their own callable surfaces against `ICapabilityRegistry`) are **not** in scope. Each domain Node will register its tools in a follow-up packet once its agent-callable surface is decided.

The specific tool-schema versioning *mechanism* — name-suffixed strings, strict semver on the package, or a hybrid — is deferred to packet 04 per ADR-0017 D6. The stand-up contract is "versioning is required, descriptors declare it, registry lookup is version-aware" — packet 04 picks the format.

The contract-shape canary in this initiative is wired by reusing `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml` (the same workflow ADR-0016 D8 leverages for AI). No Actions repo change is required.

## Notes

- **Scoping insight: the contract-shape canary needs no Actions packet.** `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml` already exists and supports `project-path`-scoped diffing. Per ADR-0017 D9, `HoneyDrunk.Capabilities.Abstractions` is the only public-boundary package — so scoping the canary to that one assembly satisfies D8 without per-type filtering. The wiring is a single `.github/workflows/api-compatibility.yml` file inside HoneyDrunk.Capabilities itself, folded into packet 04's CI bring-up. No Actions repo change required.

- **Why a separate `Testing` package, not a provider slot.** ADR-0017 D2 is explicit: there is no family of providers at the registry layer (no OpenAI-vs-Anthropic axis on the tool-registry side). The in-memory implementation is a testing fixture for downstream Nodes' deterministic unit and integration tests, not a production backend. Shipping it as `HoneyDrunk.Capabilities.Testing` (separate NuGet artifact) makes the intent explicit — production composition references `HoneyDrunk.Capabilities`, test projects reference `HoneyDrunk.Capabilities.Testing`.

- **Naming collision disambiguation surfaces in two repo edits.** ADR-0017 D4 disambiguates two collisions: (a) the superseded ADR-0004's `capabilities:` YAML frontmatter on agent definition files, and (b) HoneyDrunk.Actions (Ops Node for CI/CD). Neither is a code change, but packet 01 should ensure no doc in `repos/HoneyDrunk.Capabilities/` accidentally calls the Node's primitives "actions" or borrows the frontmatter word.

- **Strict Abstractions stance — same precedent as ADR-0016.** Per the user's resolution during ADR-0016 scoping, Abstractions packages ship with zero `HoneyDrunk.*` references. ADR-0017 D2 says `HoneyDrunk.Capabilities.Abstractions` has "Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions" — the executing agent for packet 04 must apply the strict stance regardless. Concretely: Capabilities-side types that need a correlation/identity reference use `string`, not `CorrelationId`/`NodeId`. GridContext propagation lives in the `HoneyDrunk.Capabilities` runtime package's invoker pipeline, not in any `Abstractions` type. This matches `repos/HoneyDrunk.Capabilities/invariants.md:5` which already declares the strict stance for Capabilities locally. Packet 01 amends ADR-0017 D2's "beyond `HoneyDrunk.Kernel` abstractions" phrasing to "beyond `Microsoft.Extensions.*` abstractions" in the same edit it lands the catalog work — same pattern packet 01 of ADR-0016 used.

## Status-flip handling

ADR-0017 stays at `Status: Proposed` for the duration of this scoping run and across all four packet PRs. Per the user's standing ADR acceptance workflow (`feedback_adr_workflow.md`): new ADRs start Proposed; the scope agent flips Status → Accepted only after the bundle's PRs have merged, never on a first-draft packet.

None of the four packets in this initiative flip ADR-0017's status. That is a separate housekeeping step the scope agent performs once packets 01 / 02 / 03 / 04 are all closed and the scaffold has merged. The flip is a one-line edit to `adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` line 3 (`**Status:** Proposed` → `**Status:** Accepted`), plus any matching update to `adrs/README.md` if it carries a per-ADR Status entry, plus a CHANGELOG note. The hive-sync agent's ADR auto-acceptance loop may also reconcile this on its next run if it is delayed.

This is the same pattern ADR-0016's standup initiative followed (`generated/issue-packets/active/adr-0016-honeydrunk-ai-standup/dispatch-plan.md` lines 71-115).

- **No Azure provisioning in scope.** HoneyDrunk.Capabilities is a library Node, not a deployable. There is no Key Vault, no Container App, no resource group to create. App Configuration provisioning is already in place from the ADR-0005/0006 rollout — packet 04 has no App Config consumer in this initiative (Capabilities does not source rate tables or routing policies from App Config; that is AI's concern). The Auth dependency for `ICapabilityGuard`'s default implementation is in-process composition, not a deploy-time wiring.

## Filing

The `file-packets.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/issue-packets/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.

The exception is packet 03 (the human chore), which itself contains a "Next Steps" script the human runs after creating the repo. That script is the path by which packet 04 is filed against the new repo.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and `HoneyDrunk.Capabilities 0.1.0` is published to NuGet, the entire `active/adr-0017-honeydrunk-capabilities-standup/` folder moves to `archive/adr-0017-honeydrunk-capabilities-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done`.
