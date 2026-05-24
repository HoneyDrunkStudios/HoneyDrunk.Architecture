# Dispatch Plan — ADR-0059 Stand Up the HoneyDrunk.Cache Node

**Initiative:** `adr-0059-cache-standup`
**Sector:** Core
**Governing ADR:** [ADR-0059 — Stand Up the HoneyDrunk.Cache Node](../../../../adrs/ADR-0059-stand-up-honeydrunk-cache-node.md) (Proposed 2026-05-23; stays Proposed across all three packet PRs. Flips to Accepted only after every packet in this initiative is closed AND the paired ADR-0058 is Accepted, as a separate post-merge housekeeping step the scope agent runs — see "Status-flip handling" below.)
**Driving Decision ADR:** [ADR-0058 — Grid-Wide Caching Strategy](../../../../adrs/ADR-0058-grid-wide-caching-strategy.md) (Proposed 2026-05-23; must be Accepted before ADR-0059 can flip to Accepted because ADR-0059's "Done When" gate requires the contract this Node implements to exist. ADR-0058 commits `ICacheStore<T>` to `HoneyDrunk.Kernel.Abstractions` and `InMemoryCacheStore<T>` to `HoneyDrunk.Kernel`.)
**Trigger:** ADR-0059 in the Proposed queue. `HoneyDrunk.Cache` has lived as a planned Node in `infrastructure/reference/tech-stack.md` and `initiatives/roadmap.md` since the early Grid catalogs were authored, but does not exist on disk or in `catalogs/nodes.json`. ADR-0058 names distributed-cache backings as the per-Node, per-workload choice that activates when a consumer pulls on it; those backings need a Node home and ADR-0059 stands it up — front-loaded per the charter, before the first consumer materializes.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Cache` (new))
**Site sync required:** No (scaffold-only; no public-API surface change needs site update yet — when the first distributed backing ships in a later feature packet, a site-sync follow-up may be warranted).
**Rollback plan:**
- **Pre-tag rollback** (before any tag is pushed in Cache): `git revert` of each PR. Packet 01 is an Architecture-side revert; packet 02 (human-only) is undone by archiving/deleting the new GitHub repo; packet 03 reverts the entire scaffold as a single PR.
- **Post-tag rollback** (after a tag is ever pushed in Cache — not at stand-up, since the scaffold has no implementations to publish): NuGet packages are immutable; prefer fix-forward.
- **No consumers yet.** Per ADR-0059 D9, Cache has no Grid-internal downstream consumers at stand-up — every existing cache in the Grid is either grandfathered or has not yet been introduced. Rollback at this stage costs nothing downstream.
- **`file-packets.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Sequencing Against ADR-0058 — Coupled, Not Hard-Gated For Packet Execution

ADR-0058 and ADR-0059 are a paired pair. ADR-0058 commits the `ICacheStore<T>` contract in `HoneyDrunk.Kernel.Abstractions` and the `InMemoryCacheStore<T>` reference implementation in `HoneyDrunk.Kernel`; ADR-0059 stands up the Cache Node that will host distributed backings of that contract. ADR-0059's own §"Done When" gate (line 185) requires ADR-0058 to be Accepted before ADR-0059 can flip to Accepted.

That gate is on the **ADR Status flip**, not on the packet execution. Concretely:

- **Packets 01, 02, 03 of this initiative can execute regardless of ADR-0058's Status.** None of the packets here require the `ICacheStore<T>` contract to be in `Kernel.Abstractions` yet — the scaffold is "the empty room with the right lighting" per ADR-0059 D3. No `ICacheStore<T>` reference, no `InMemoryCacheStore<T>` reference, no placeholder implementation in Cache's day-one shape. The scaffold proves the repo exists and CI runs green on an empty solution.
- **The ADR-0059 Status flip is the only step that needs ADR-0058 Accepted.** That flip is post-merge housekeeping (see "Status-flip handling" below) — not authored by any packet in this initiative.

This means ADR-0058 and ADR-0059 can land their respective initiatives **in either order or in parallel** as long as the two Status flips are sequenced correctly: ADR-0058 must flip Accepted **before** ADR-0059 flips Accepted, regardless of which initiative's packets merged first. The scope agent's post-merge housekeeping reads both ADRs' state before flipping ADR-0059.

If ADR-0058 has not been scoped yet at this initiative's filing time, this initiative is still safe to push — the only downstream effect is that ADR-0059's Status flip waits until ADR-0058's initiative completes. The repo, scaffold, CI, and catalog entries all land as scheduled.

## Summary

ADR-0059 is the stand-up ADR for `HoneyDrunk.Cache`. It decides what the Node owns (D1, D6: distributed-cache backing implementations of `ICacheStore<T>`), the front-loading justification (D2), the initial scaffolding shape (D3, D8: a single placeholder project, no backing implementations on day one), owner/visibility (D4: solo-dev with agent collaborators; D5: public per Grid default), and the downstream coupling rule at stand-up (D9: leaf in the dependency graph from its own side, no consumers yet). None of that has been built — the `HoneyDrunkStudios/HoneyDrunk.Cache` repo does not exist yet, and no catalog rows refer to it.

Three packets land the work:

1. **Architecture catalog registration** — register `honeydrunk-cache` in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, and `catalogs/modules.json`; update `constitution/sectors.md` Core table to include Cache; move `infrastructure/reference/tech-stack.md`'s Cache row out of "Planned Nodes"; update `initiatives/roadmap.md` Future list; create the `repos/HoneyDrunk.Cache/` context folder with `overview.md`, `boundaries.md`, `invariants.md`; add an "ADR-0059 HoneyDrunk.Cache Standup" entry to `initiatives/active-initiatives.md`. **Does not flip the ADR Status** — that is post-merge housekeeping.
2. **Create the HoneyDrunk.Cache GitHub repo (human-only)** — create the public repo on `HoneyDrunkStudios`, apply branch protection, seed labels, configure OIDC federated credential, clone locally. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` and `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md`.
3. **HoneyDrunk.Cache scaffold** — empty repo to first-shippable state. Solution (`HoneyDrunk.Cache.slnx`), single placeholder project (`HoneyDrunk.Cache.Adapters`), `HoneyDrunk.Standards` wiring, CI via HoneyDrunk.Actions shared workflows (build, test, security scan, package scan — **no contract-shape canary**, since Cache owns no contracts), `README.md`, `CHANGELOG.md` starting at `0.0.1`, LICENSE confirmation. No backing implementations.

**No invariants packet.** ADR-0059 explicitly says "None at stand-up" (line 204-208 of the ADR). The cache-related invariants (per-Node-opaque caches; tenant-key isolation; classification inheritance) are committed by ADR-0058, not by ADR-0059. The Cache Node enforces them by virtue of being where the backings live; it does not declare them. This is the meaningful asymmetry vs the Capabilities and Audit standups — both of those required an invariants packet.

## Wave Diagram

```
Wave 1: Architecture catalog + context-folder updates (sequential, may push with Wave 2)
   └─ Architecture: 01-architecture-cache-catalog-registration
         No upstream dependencies (this packet is the foundation of the initiative).

Wave 2: GitHub repo creation (human-only, parallel-able with Wave 1 in clock time
        but sequenced after Wave 1 here so the tracking issue lands once the
        catalogs already point at the eventual repo)
   └─ Architecture: 02-architecture-create-cache-repo  (human-only)
         Blocked by: packet 01

Wave 3: HoneyDrunk.Cache scaffold
   └─ HoneyDrunk.Cache: 03-cache-node-scaffold
         Blocked by: packet 01 (the repos/HoneyDrunk.Cache/ context folder and the
                                catalog entries must be in place so the scaffold's
                                README and CHANGELOG cross-reference real catalog state)
                     packet 02 (the GitHub repo must exist and the local working tree
                                must be cloned before scaffolding can run)
```

In practice packets 01 and 02 can be filed in the same push — packet 02 is human-only, packet 01 is agent, and the `dependencies:` frontmatter wires the blocking edge automatically. Packet 03 must wait until packet 01 has merged and packet 02 is Done.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Register HoneyDrunk.Cache in Architecture catalogs + create context folder + update sectors / tech-stack / roadmap / active-initiatives](./01-architecture-cache-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Create `HoneyDrunkStudios/HoneyDrunk.Cache` public repo, branch protection, labels, OIDC, clone locally (human-only)](./02-architecture-create-cache-repo.md) | Architecture (tracking issue) | 2 | Human | packet:01 |
| 03 | [Stand up `HoneyDrunk.Cache` — solution with single placeholder project, Standards wiring, CI without canary, README + CHANGELOG + LICENSE](./03-cache-node-scaffold.md) | HoneyDrunk.Cache | 3 | Agent | packet:01, packet:02 |

## Phase Mapping (ADR-0059 "If Accepted" checklist → packets)

ADR-0059's "If Accepted — Required Follow-Up Work" checklist (lines 8-22), mapped to packets:

| Checklist item | Packet |
|---|---|
| Create the `HoneyDrunk.Cache` GitHub repo as **public** | packet 02 |
| Add `honeydrunk-cache` entry to `catalogs/nodes.json` with Core sector and empty contracts list | packet 01 |
| Add `honeydrunk-cache` entries to `catalogs/relationships.json` (consumes `honeydrunk-kernel`; empty `consumed_by`; `consumed_by_planned` includes the two most likely first consumers) | packet 01 |
| Add `honeydrunk-cache` to `catalogs/grid-health.json` and `catalogs/modules.json` | packet 01 |
| Update `constitution/sectors.md` Core-sector entry to include Cache | packet 01 |
| Update `infrastructure/reference/tech-stack.md` — move Cache row out of "Planned Nodes" and update the Redis row | packet 01 |
| Update `initiatives/roadmap.md` — remove or relocate the Cache line from "Future" | packet 01 |
| Create `repos/HoneyDrunk.Cache/` context folder with `overview.md`, `boundaries.md`, `invariants.md` stubs | packet 01 |
| File the `HoneyDrunk.Cache` scaffold packet (solution, Standards wiring, CI, empty solution day-one) | packet 03 |
| Scope agent assigns final invariant numbers if any new invariants are promoted from ADR-0058 at acceptance time | not in this initiative (ADR-0059 commits no new invariants at stand-up; ADR-0058's eventual acceptance initiative handles any invariants it introduces) |
| Scope agent flips Status → Accepted after the scaffold packet lands | post-merge housekeeping (see Status-flip handling below) |

## What This Initiative Does NOT Deliver

The following are explicitly out of scope for this initiative. Each becomes a separate packet at the appropriate time:

- **The `ICacheStore<T>` contract itself.** Per ADR-0058 D2, that lives in `HoneyDrunk.Kernel.Abstractions` and is the work of the ADR-0058 acceptance initiative (separate scoping run). This initiative's packet 03 does NOT add any `ICacheStore<T>` reference to the Cache scaffold; the contract is in Kernel, not Cache.
- **The `InMemoryCacheStore<T>` reference implementation.** Per ADR-0058 D4, that lives in `HoneyDrunk.Kernel`. Not in Cache. Not in this initiative.
- **The first distributed-cache backing implementation.** Per ADR-0059 D3 + D8 ("No implementations on day one"), no Redis adapter, no Cosmos-TTL adapter, no Postgres-TTL adapter ships in this initiative. The first backing arrives in a separate feature packet when the first real consumer (likely Notify Cloud multi-replica or Communications shared cache) pulls on a distributed cache. The choice between Redis / Cosmos / Postgres is **deferred to the first feature packet** per ADR-0059 D3.
- **Contract-shape canary.** Per ADR-0059 D3 + D8 + §Negative, Cache owns no contracts at stand-up — the contract it implements lives in `Kernel.Abstractions` and is guarded by Kernel's canary surface. Packet 03's CI explicitly does NOT wire `api-compatibility.yml`. The first canary surface arrives with the first backing implementation, scoped to that backing's public surface (a different ADR/packet).
- **Azure resource provisioning.** Per ADR-0059 D2 + D3 + §Consequences, no Azure resource is provisioned by this ADR — `HoneyDrunk.Cache` is a library Node on day one with no deployable host. The first Redis-class cache instance, first Cosmos container with TTL, or first Postgres table for cache is provisioned through Cache Node's bicep/terraform/portal walkthrough at the time the first backing lands, not now. Same pattern as ADR-0016 AI standup, ADR-0017 Capabilities standup, ADR-0031 Audit standup — library Nodes defer Azure provisioning until the first deployable host composes them.
- **HTTP / output response caching.** Per ADR-0059 §Unblocks, this is a future cache-related ADR likely paired with the Gateway standup. Not in scope here. Cache's role today is distributed `ICacheStore<T>` backings only; HTTP/output caching is a separate concern that may land as future siblings under the Cache Node.
- **`HybridCache` adoption or rejection.** Per ADR-0058 D8, deferred behind the boundary. Future ADR.
- **Cache invariants.** Per ADR-0059 §New invariants ("None at stand-up"). The cache-related invariants (per-Node-opaque caches; tenant-key isolation; classification inheritance) are committed by ADR-0058 D1/D5/D6, not by ADR-0059. If ADR-0058's acceptance initiative promotes any of those to constitutional invariants, that work lives in ADR-0058's initiative — not here.
- **First consumer (Notify Cloud multi-replica, Communications shared cache).** Each is a separate feature packet against the consuming Node at the time its workload demands a distributed cache. Surfaced in `catalogs/relationships.json` `consumed_by_planned` by packet 01 so the planned coupling is visible on the dependency map — but no work happens on the consumer side in this initiative.

## Filing-order rule

Packet 03's body references `repos/HoneyDrunk.Cache/overview.md` and the catalog state landed by packet 01. Filed packets are immutable (invariant 24). Therefore:

**Packet 01 must be filed, its PR merged, and the catalog/context-folder edits actually on `main` before packet 03 is filed.**

In practice:

1. Push packets 01 and 02 (they may travel together — packet 02's `dependencies: ["packet:01"]` wires the blocking edge automatically).
2. Wait for packet 01's PR to merge so `repos/HoneyDrunk.Cache/` exists in the Architecture repo and the catalogs reflect the stand-up.
3. Wait for packet 02 to close (the repo must exist and the local working tree must be cloned before `file-packets.sh` can target a packet against `HoneyDrunkStudios/HoneyDrunk.Cache`).
4. Push packet 03.

**Packets 01 and 03 cannot be filed in the same push.** Packet 03 must reach a state where the GitHub repo it targets exists, which requires packet 02 to be complete, which requires packet 01 to be merged.

## Asymmetry vs ADR-0017 Capabilities / ADR-0031 Audit standups

Three deliberate asymmetries are worth recording:

1. **Three packets, not four.** Both Capabilities and Audit shipped an invariants packet (Capabilities 02, Audit 01). Cache ships none — ADR-0059 explicitly commits zero new invariants at stand-up. The cache-related invariants live with ADR-0058's acceptance work, not here. This simplifies the wave shape: no number-collision check, no cross-reference into ADR Consequences, no pre-push amendment of the scaffold packet for assigned invariant numbers.

2. **No contracts in `Abstractions`, no `Abstractions` package at all.** Cache implements a contract declared elsewhere (in `Kernel.Abstractions` per ADR-0058 D2). It does not declare its own Abstractions package. The scaffold ships exactly one project (`HoneyDrunk.Cache.Adapters`) as a placeholder so CI has something to build. Future backings ship as sibling packages (`HoneyDrunk.Cache.Adapters.Redis`, `HoneyDrunk.Cache.Adapters.Cosmos`, etc. — or under whatever subnamespace the first backing packet chooses). The placeholder project is a backing-axis name from the start.

3. **No contract-shape canary in CI.** Per ADR-0059 D3, the contract Cache implements lives in `Kernel.Abstractions` and is canaried by Kernel's surface. Cache owns no contracts of its own to freeze. Packet 03's CI omits `api-compatibility.yml`. This is consistent with ADR-0027 Notify Cloud standup's first scaffold — Notify Cloud also shipped without an own-canary because its first scaffold owned no contracts.

4. **Front-loaded with no consumer.** Unlike Communications (ADR-0013/0019), AI (ADR-0016), Capabilities (ADR-0017), or Audit (ADR-0030/0031) — each of which had at least one known near-term consumer at standup time — Cache has zero current Grid consumers pulling on a distributed cache. The standup is justified by the charter §"What this charter licenses" and by the eight prior front-loaded Node standups (Agents, Knowledge, Memory, Evals, Flow, Sim, Operator, Audit) all of which were stood up before their first consumers materialized. This is well-established Grid practice; the cost of the standup is an afternoon's scaffold work; the benefit is that the first distributed-cache backing has a home Node to land in without a blocking Node-or-not decision.

## Status-flip handling

ADR-0059 stays at `Status: Proposed` for the duration of this scoping run and across all three packet PRs. Per the user's standing ADR acceptance workflow (`feedback_adr_workflow.md`): new ADRs start Proposed; the scope agent flips Status → Accepted only after the bundle's PRs have merged, never on a first-draft packet.

None of the three packets in this initiative flip ADR-0059's status. That is a separate housekeeping step the scope agent performs once packets 01 / 02 / 03 are all closed and the scaffold has merged.

**Two gates on the ADR-0059 Status flip:**

1. All three packets in this initiative are Done.
2. ADR-0058 is Accepted. Per ADR-0059's "Done When" gate (line 185: "ADR-0058 is Accepted (paired prerequisite — the contract this Node implements must exist before the Node has a defined role)"). If ADR-0058 is still Proposed when this initiative completes, the scope agent waits to flip ADR-0059 until ADR-0058 is Accepted. The Cache repo, catalog rows, and scaffold all land in the meantime; only the ADR header is gated.

The flip is a one-line edit to `adrs/ADR-0059-stand-up-honeydrunk-cache-node.md` line 3 (`**Status:** Proposed` → `**Status:** Accepted`), plus any matching update to `adrs/README.md` if it carries a per-ADR Status entry, plus a CHANGELOG note. The hive-sync agent's ADR auto-acceptance loop may also reconcile this on its next run if it is delayed.

This is the same pattern ADR-0017's and ADR-0031's standup initiatives followed.

## Notes

- **No Azure provisioning in scope.** HoneyDrunk.Cache is a library Node at Phase 1, not a deployable. There is no Key Vault, no Container App, no resource group to create. The first Redis-class cache instance, first Cosmos container with TTL, or first Postgres table for cache is provisioned through the Cache Node's bicep/terraform/portal walkthrough at the time the first backing lands, not now. Cross-link: [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) for when that work lands.

- **Repo is public by default.** Per memory `project_repos_public_by_default`, HoneyDrunk repos are public unless a revenue/compliance/experiment carve-out applies. Cache backings are substrate, not commercial product — no revenue carve-out. Cache owns no secrets, no PII storage, no audit-bearing surfaces — no compliance carve-out (cached data classification is the consumer Node's concern per ADR-0058 D6). Cache is committed substrate, not exploratory — no experiment carve-out. Public is the right call. Packet 02's portal step specifies Visibility = Public.

- **No ADR numbers in user-facing docs or code comments.** Per memory `feedback_no_adr_in_docs`, the scaffold's README does **not** cite "ADR-0059" or "ADR-0058" by number in its narrative — the README explains what the Node is for and what it does not own at Phase 1. Runtime / packet-data references (catalog entries, frontmatter, this dispatch plan, the CHANGELOG) are fine to cite ADRs by number.

- **No commits under CHANGELOG Unreleased.** Per memory `feedback_no_unreleased_commits`, the scaffold's first commit lands under `## [0.0.1] - YYYY-MM-DD`, not under `## Unreleased`. The tag push (if ever; the scaffold has no implementations so no NuGet publish is expected at stand-up time) happens after merge — but the version section in CHANGELOG is dated and SemVer-bumped before the commit. Packet 03's acceptance criteria call this out.

- **No manual packet filing.** Per memory `feedback_no_manual_packet_filing`, file-packets.yml auto-files on push to main. Do not run `gh issue create` against these packets. Filing happens by pushing the packet files into `generated/issue-packets/active/adr-0059-cache-standup/`. The filing-order rule above governs which packets land in which push.

- **Cache → Kernel edge direction (one-way, strict).** Throughout this initiative, the dependency direction is **Cache → Kernel, never the reverse**. Cache references `HoneyDrunk.Kernel.Abstractions` at the point a backing implementation exists (not in this initiative — the placeholder project carries the .NET version, analyzers, and CI wiring only). Kernel does not reference any `HoneyDrunk.Cache.*` package — Kernel is at the root of the DAG. The eventual `consumed_by_planned` Nodes (Notify Cloud, Communications) take the dependency edge on Cache, not vice versa.

- **No grid-health aggregator wiring needed for this initiative.** If `HoneyDrunk.Actions/.github/workflows/grid-health-aggregator.yml` auto-discovers from `catalogs/nodes.json`, packet 01's edit to `nodes.json` is sufficient. If not, packet 03's Human Prerequisites flag a small follow-up to add `HoneyDrunk.Cache` to the watched-repos list. Confirm which behavior is in place at packet 03 execution time.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND ADR-0058 is Accepted AND the scope agent has flipped ADR-0059 to Accepted, the entire `active/adr-0059-cache-standup/` folder moves to `archive/adr-0059-cache-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done` and ADR-0059 is Accepted.

## Filing

The `file-packets.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/issue-packets/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.

The exception is packet 02 (the human chore), which itself contains a "Next Steps" script the human runs after creating the repo. That script is the path by which packet 03 is filed against the new repo (or, alternatively, packet 03 is filed via the normal file-packets pipeline once the repo exists and `HoneyDrunkStudios/HoneyDrunk.Cache` is reachable from the org-level `gh` permissions).
