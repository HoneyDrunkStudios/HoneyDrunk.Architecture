---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "honeyhub", "adr-0091", "wave-1"]
dependencies: []
adrs: ["ADR-0091", "ADR-0090", "ADR-0092", "ADR-0082"]
accepts: ADR-0091
source: human
generator: scope
wave: 1
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Chore: Register HoneyDrunk.HoneyHub in Architecture catalogs + five-file context folder (Phase A standup)

## Summary
Land the Phase A (Architecture registration) standup surface for the new `HoneyDrunk.HoneyHub` Node per ADR-0091 D1/D6 and the ADR-0082 canonical node-standup procedure. Add the new Meta-sector Node to every catalog file (`nodes.json`, `relationships.json`, `grid-health.json`, `modules.json`), add the sector row in `constitution/sectors.md`, add the Q2 2026 roadmap bullet and the in-progress `active-initiatives.md` entry, and create the five-file context folder at `repos/HoneyDrunk.HoneyHub/` (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`).

HoneyHub stands up under the dedicated **`studios-typescript-native`** Node class — the seventh class, added to ADR-0082 D2 by its 2026-06-06 amendment specifically for the TypeScript-UI + native-Rust-bridge-in-one-workspace shape HoneyHub introduces. See "The node-class" below. (The ADR-0082 amendment and the `constitution/node-standup.md` update are separate Architecture edits in this same initiative; this packet declares the class and wires the catalog identity to it.)

ADR-0091 (and its siblings 0090/0092) stay at their current `Status` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the whole initiative completes. This packet's body does not edit any ADR header.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0090 (Accepted) decided the bridge boundary and the `DispatchSession`/`DispatchRun`/`UsageSignal` session contract. ADR-0091 (Proposed) decided the app stack and named the new `HoneyDrunk.HoneyHub` Node and its standup via ADR-0082. ADR-0092 (Proposed) decided session/usage persistence and the routing engine. None of that has reached the canonical catalogs. Until it does, the program tracker (`initiatives/programs/honeyhub.md`) reads "No `HoneyDrunk.HoneyHub` repo exists yet," the scaffold packet (packet 03 of this initiative) has nothing to anchor its `node:` frontmatter against, and grid observability cannot resolve any issue filed against the future repo back to a Node identity.

Per **invariant 102** (*Node registration is mandatory before the first non-bootstrap PR merges*), every Node repo must carry the ten registration items — three catalog rows, the five-file context folder, a sector row, the `repo-to-node.yml` mapping (packet 02), `.honeydrunk-review.yaml` + `pr.yml` + branch protection + org-secret binding (Phase B/C, packets 02/03) — before its first non-bootstrap PR merges. For this `studios-typescript-native` Node, the tier-1 gate (invariant 31) is delivered by a **self-contained `pr.yml`** (Node + Rust lanes, not `pr-core.yml`), so the required `main` branch-protection check is **`pr / build`**, not `pr-core / core`, and the default org-secret binding is **none**. This packet lands the Phase A subset (catalog rows + context folder + sector row); packets 02 and 03 land the rest.

Per **invariant 41** (*new Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time* — a repo missing from the catalog is invisible to grid observability), the `repos/HoneyDrunk.HoneyHub/` folder must exist before the repo is meaningfully tracked.

## The node-class (resolved: `studios-typescript-native`)
ADR-0091 D1 and its Open Questions table flagged the mixed-class question: HoneyHub is a TypeScript web/PWA + Tauri-class shell surface plus a Rust bridge package, in one workspace repo (D4), and ADR-0082 D2's original six-class taxonomy had no row for "TypeScript UI + native (Rust) bridge in one repo." **That question is now resolved.** The operator-approved resolution is a one-row ADR-0082 D2 amendment (2026-06-06) adding a dedicated seventh class, **`studios-typescript-native`**, exactly the lightweight "one-row D2 amendment + per-class walkthrough for a new shape" path ADR-0082 pre-authorizes (and `constitution/node-standup.md` names "Tauri desktop" as such a future addition).

**Decision recorded for this standup:** declare HoneyHub as **`node_class: studios-typescript-native`**. Its delta vs `studios-typescript`: a dual **Node + Cargo** workspace; CI runs both an npm/pnpm lane **and** a `cargo build`/`cargo test`/`cargo clippy` lane via a **self-contained `pr.yml`** (it does NOT call the .NET `pr-core.yml`); the required `main` status check is the job's own name **`pr / build`**, not `pr-core / core`; no `.slnx`/`Directory.Build.props`/`HoneyDrunk.Standards`/NuGet; and **no org secret is required by default** (no npm publish, no Sonar lane unless added). This is the dedicated class, not a `studios-typescript` Node with a bolted-on lane.

The bridge *language* (Rust) and packaging remain `[Provisional]` per ADR-0091 D2/D3 — but the *class* is firm: even if the bridge language later moves (e.g. to TS), a TS-UI + native-binary workspace still maps to `studios-typescript-native`. Record the remaining `[Provisional]` seams (bridge language, desktop-shell toolkit, relay, store engine) in `repos/HoneyDrunk.HoneyHub/active-work.md` so the review agent sees them. The ADR-0082 D2 amendment and the `constitution/node-standup.md` update are landed as part of this initiative (separate Architecture edits); this registration packet declares the class against them.

## Proposed Implementation

### `catalogs/nodes.json` — new `honeydrunk-honeyhub` entry
**Anchor semantically, not by line number.** Find a Meta-sector neighbor (e.g. `honeydrunk-studios` or `honeydrunk-operator`) via `rg -n '"id": "honeydrunk-studios"' catalogs/nodes.json` at edit time and insert the new block adjacent to it. Match the schema every other Node uses (all fields: `id`, `type`, `name`, `public_name`, `short`, `description`, `sector`, `signal`, `cluster`, `energy`, `priority`, `flow`, `tags`, `links.repo`, `long_description` (with all sub-fields), `foundational`, `strategy_base`, `tier`, `time_pressure`, `done`, `cooldown_days`).

Key field choices (load-bearing):
- `"sector": "Meta"` — ADR-0090/0091/0092 all label the sector "Meta / AI / Platform." `Meta` is the existing canonical sector that fits; the tri-label is descriptive, not a new sector. Do **not** invent a "Platform" sector.
- `"signal": "Seed"` — repo not yet created; scaffold pending.
- `"cluster": "orchestration"` — the existing taxonomy is `foundation`, `security`, `observability`, `infrastructure`, `orchestration`, `governance`, `visualization`, `cognition`, `quality`, `knowledge`. A cockpit that starts/watches/interrupts/governs agent sessions is an orchestration surface; `orchestration` is the closest match. Do not invent a new cluster value.
- `"done": false`, `"foundational": false`.
- `links.repo`: `https://github.com/HoneyDrunkStudios/HoneyDrunk.HoneyHub`.
- `tags`: include `agent-cockpit`, `local-runner-bridge`, `pwa`, `tauri-class-shell`, `rust-bridge`, `usage-governance`, `dispatch-session`.

The `long_description` sub-fields (`overview`, `why_it_exists`, `primary_audience`, `value_props`, `monetization_signal`, `roadmap_focus`, `grid_relationship`, `integration_depth`, `demo_path`, `signal_quote`, `stability_tier`, `impact_vector`) should summarize: HoneyHub v1 = the FREE, local Agent Cockpit (mobile PWA + desktop, one shared React UI) driving Codex / Claude Code / Copilot via their official CLIs under the user's own local auth; bundled Rust bridge in a Tauri-class shell; local-first session/usage store; first real consumer of ADR-0010's `IRoutingPolicy`. `monetization_signal`: free at v1; the one gated paid candidate is BYOK cloud execution (validation-gated, never subscription auth). `stability_tier`: `seed`. `integration_depth`: `shallow` (consumes Architecture as a read backend later; no runtime Grid-Node dependency at v1).

### `catalogs/relationships.json` — new `honeydrunk-honeyhub` block
Add a new entry to the `nodes` array adjacent to the `honeydrunk-studios` block. Per ADR-0091 D6, the intended placement (stated by the ADR, wired here):

```json
{
  "id": "honeydrunk-honeyhub",
  "consumes": [],
  "consumed_by": [],
  "consumed_by_planned": [],
  "blocked_by": [],
  "exposes": {
    "contracts": ["DispatchSession", "DispatchRun", "DispatchMessage", "DispatchControlEvent", "DispatchArtifact", "UsageSignal", "PolicyHint"],
    "packages": []
  },
  "consumes_detail": {}
}
```

**Record the planned-consume intent the schema-native way.** The live `relationships.json` schema has **no `consumes_planned` field** — its real keys are `id`, `consumes`, `consumed_by`, `consumed_by_planned`, `blocked_by`, `exposes` (`contracts` / `packages`), and `consumes_detail`. A planned *upstream* dependency is therefore recorded on the **upstream node's `consumed_by_planned` array**, not on a (nonexistent) `consumes_planned` array on HoneyHub. Concretely: add `"honeydrunk-honeyhub"` to the **`consumed_by_planned`** array of **`honeydrunk-architecture`** (the later PDR-0009 Dev-surface read-backend edge) and to the **`consumed_by_planned`** array of **`honeydrunk-ai`** (the later ADR-0092 `IRoutingPolicy` routing edge). Find each block via `rg -n '"id": "honeydrunk-architecture"' catalogs/relationships.json` / `rg -n '"id": "honeydrunk-ai"'` and append `"honeydrunk-honeyhub"` to its `consumed_by_planned` list (match the existing array formatting).

Notes:
- **`consumes` is empty at v1.** Per ADR-0091 D6 and ADR-0092 D3, HoneyHub has **no runtime Grid-Node dependency** at v1. The Architecture read-backend edge (PDR-0009 Dev-surface layer) and the HoneyDrunk.AI `IRoutingPolicy` edge (ADR-0092) are **planned/later**, recorded on the upstream nodes' `consumed_by_planned` arrays (see above), not wired as live edges. This preserves invariant 4 (the dependency graph is a DAG; Kernel at root) — HoneyHub adds no cycle and no live upstream edge.
- `packages` is empty pre-scaffold; the scaffold packet (03) does not publish Grid NuGet/npm packages at v1 (the PWA is a static build; the bridge is a bundled binary, not a published Grid package). If any package is later published, a post-scaffold reconciliation adds it.
- Do **not** add `honeydrunk-honeyhub` to any existing Node's `consumes`/`consumed_by` — nothing consumes HoneyHub at v1.

### `catalogs/grid-health.json` — new `honeydrunk-honeyhub` row
Insert a row reflecting empty standup state. `version: "0.0.0"`, `canary_status: "none"`, `last_release: null`, `signal: "Seed"`, `sector: "Meta"`. `active_blockers` lists: GitHub repo not yet created (packet 02), scaffold packet (packet 03) not yet executed. (The node-class is resolved — `studios-typescript-native` per the ADR-0082 2026-06-06 amendment — so it is no longer a blocker.) Append `"honeydrunk-honeyhub"` to `summary.blocked_nodes` and bump `summary.total_nodes` / `summary.seed` / `summary.canary_none` each by 1 — **read the actual current values at edit time** via `rg -n '"summary"' catalogs/grid-health.json`.

### `catalogs/modules.json`
HoneyHub publishes **no Grid package** at v1 (static PWA + bundled bridge binary, not an npm/NuGet Grid module). **Do not invent module entries.** Follow the precedent of **`honeydrunk-operator`** — a deployable/product Node that publishes no package and therefore has **no `modules.json` entry at all** (`modules.json` is a flat list of published packages keyed by `nodeId`; a node with no published package simply does not appear). HoneyHub follows the same treatment: **omit it from `modules.json` entirely** and note in the PR body that HoneyHub is a non-publishing product Node (like `honeydrunk-operator`). Confirm the convention at edit time by checking that `honeydrunk-operator` has no `modules.json` entry.

### `constitution/sectors.md` — add HoneyHub to the Meta sector
Find the `## Meta` section via `rg -n '^## Meta' constitution/sectors.md`. Add a row to the Meta-sector table (matching the existing table format):

```
| **HoneyHub** | Seed | Agent Cockpit — mobile PWA + desktop shell that drives local Codex / Claude Code / Copilot sessions via their official CLIs under the user's own local auth; bundled local runner bridge; local-first session/usage store; usage governance + routing |
```

Do **not** add HoneyHub to the "Dependency Flow (Real Nodes)" block — it is not yet "Real" (repo doesn't exist, scaffold pending) and has no upstream Grid-Node dependency. It joins the diagram only after the scaffold lands and a `0.1.0` ships. Flag this in the PR body so a future agent doesn't preemptively edit the diagram.

### `initiatives/roadmap.md` — add HoneyHub entry under Q2 2026
Find the Q2 2026 section. Add:

```
- [ ] **HoneyDrunk.HoneyHub Standup + Phase 2 (ADR-0090/0091/0092)** — Stand up the Agent Cockpit Node (mixed TS PWA + Rust bridge); Phase 2 ships the Rust bridge core + secure pairing + one backend adapter (Claude Code) + minimal React run screen + local DispatchSession store. Lead near-term build thread per PDR-0011.
```

### `initiatives/active-initiatives.md` — new "In Progress" entry
Insert under `## In Progress`. The entry describes: stand up `HoneyDrunk.HoneyHub` per ADR-0091 (new Meta-sector Node, `studios-typescript-native` class — TS PWA + Rust bridge in one workspace), then Phase 2 (bridge core + Claude Code adapter + minimal run screen + local store). List the packets with `Architecture#NN` / `HoneyHub#NN` placeholders and a dated sync line. Reference the program tracker at `initiatives/programs/honeyhub.md`.

### `repos/HoneyDrunk.HoneyHub/` — new five-file context folder
Create all five files (invariant 102 item 4 — the five-file shape is non-negotiable; it is the surface the `review` and `scope` agents load on every PR per invariant 33).

**Sector label in all five files: `Meta`** (the canonical single-word sector), **not** the ADR tri-label "Meta / AI / Platform." The tri-label is the ADRs' descriptive sector line; the context-folder files (and the catalogs) use the canonical `Meta`. Do not write "Meta / AI / Platform" into any of the five files.

#### `repos/HoneyDrunk.HoneyHub/overview.md`
Cover: sector (Meta), signal (Seed), version (0.0.0, standup pending), stack (TypeScript · React · Vite · PWA · Tauri-class shell · **Rust** bridge), repo link, status. Purpose: the Agent Cockpit Node — one shared React PWA across mobile + desktop, a Tauri-class desktop shell that bundles the local runner bridge (one install), the bridge that drives local agent CLIs under the user's own local auth, and the local-first session/usage store + routing engine. Summarize the ADR-0090 session contract entities (`DispatchSession`, `DispatchRun`, `DispatchMessage`, `DispatchControlEvent`, `DispatchArtifact`, `UsageSignal`, `PolicyHint`) and the D4 capability flags (`streaming_output`, `interactive_reply`, `resume_session`, `stop_signal`, `structured_events`, `usage_exact`, `usage_estimated`). Note the three surfaces (Web/PWA, Desktop shell, Mobile-same-PWA-over-relay) per ADR-0091 D2.

#### `repos/HoneyDrunk.HoneyHub/boundaries.md`
What HoneyHub owns: session UI, transcript display, run status, notifications, policy hints, usage analytics, artifact links, the local runner bridge (process launch/lifecycle, official-CLI driving, pairing, workspace-root allowlist, artifact detection), the local-first DispatchSession/UsageSignal store, the app-tier routing engine. What it does NOT own: a code editor or terminal (the `[Firm]` not-an-editor boundary — coding stays in the IDE); authoritative Architecture/catalog/code state (the bridge writes only through reviewable git branches/PRs — the `[Firm]` PRs-as-artifacts boundary); vendor subscription auth (HoneyHub never holds/stores/proxies it — the `[Firm]` BYOK-only-cloud boundary); the canonical routing-policy contract (that is HoneyDrunk.AI's `IRoutingPolicy` per ADR-0010 — HoneyHub consumes it, does not fork it); the Grid cost-rate table (read from ADR-0052/ADR-0016, not coined here).

#### `repos/HoneyDrunk.HoneyHub/invariants.md`
HoneyHub-specific operating rules (this Node adds **no `constitution/invariants.md` entry** — ADR-0090/0091/0092 each explicitly state "no new invariant"; the `[Firm]` boundaries are HoneyHub decision-ledger items, not constitution entries). Record the `[Firm]` boundaries as local invariants:
1. The bridge drives each vendor's official CLI under the user's own local session; HoneyHub never holds/stores/proxies subscription auth (ADR-0090 D8/D10).
2. Cloud/hosted execution is BYO-API-key only, never a subscription token (ADR-0090 D10, PDR-0011 Amendment §3).
3. Artifacts are the write boundary — no direct mutation of authoritative state outside a reviewable git branch/PR (ADR-0090 D9; PDR-0009 §D inherited).
4. Honest capability flags — the bridge never fakes live interaction a backend lacks (ADR-0090 D4).
5. State-only notifications — status/backend/repo/link only, never prompt text/code/secrets/stack traces/full paths (ADR-0090 D7/D11).
6. Local-first data default with per-session/workspace opt-in sync; no central transcript store at v1 (ADR-0090 D11, ADR-0092 D1).
7. Usage fidelity is always tagged `exact`/`derived`/`estimated`; the UI never renders an estimate as an exact figure (ADR-0092 D2).
8. HoneyDrunk.AI's `IRoutingPolicy` is the canonical routing-policy contract; HoneyHub consumes it and does not fork a parallel routing abstraction (ADR-0092 D3).
9. Routing = "optimize your own subscriptions" (capability/cost fit + the user's own subscription headroom), NEVER cap-dodging / rate-limit evasion / account multiplexing / credential rotation (ADR-0092 D3, PDR-0011 Amendment §1).
10. Not-an-editor / not-a-terminal — HoneyHub never gains a code editor or terminal (PDR-0011 `[Firm]` ledger).

#### `repos/HoneyDrunk.HoneyHub/active-work.md`
Record: the standup initiative is in progress (`honeyhub-v1`); Phase 2 packets follow the standup. **Record the resolved node-class** (`studios-typescript-native` — the dedicated seventh ADR-0082 D2 class added 2026-06-06 for the TS-UI + Rust-bridge-in-one-workspace shape; self-contained `pr.yml`, required check `pr / build`). List the remaining ADR-0091/0092 `[Provisional]` open seams so the review agent sees them: exact desktop-shell toolkit + code-signing/auto-update (ADR-0091 Open Q); the mobile relay mechanism (Tailscale default, dumb-pipe relay gated); the routing-engine placement (live HoneyDrunk.AI `IModelRouter` call vs app-side policy-config copy, ADR-0092 Open Q); the embedded local-store engine (SQLite-class, ADR-0092 D1); retention-window defaults.

#### `repos/HoneyDrunk.HoneyHub/integration-points.md`
Upstream dependencies: **zero runtime Grid-Node dependency at v1.** Later (named, not wired): Architecture repo as a structural **read** backend for the PDR-0009 Dev-surface layer (HoneyHub reads decisions/catalogs as a derived read-index, never authoritatively writes them); HoneyDrunk.AI's `IRoutingPolicy`/`IModelRouter` (ADR-0010) for the routing engine; the ADR-0052/ADR-0016 cost-rate surface (read-only) for `derived` USD figures; the ADR-0086 runner host as the solo-mode bridge host (operational hosting relationship, not a package edge). External runtime deps: the three vendor official CLIs (Claude Code, Codex, Copilot) driven locally; Tailscale for the mobile relay (D5). Downstream consumers: none at v1.

## Acceptance Criteria
- [ ] `catalogs/nodes.json` has a complete `honeydrunk-honeyhub` entry (Meta sector, Seed signal, `orchestration` cluster, `done: false`, all schema fields populated, repo link correct).
- [ ] `catalogs/relationships.json` has a `honeydrunk-honeyhub` block with **all-empty edge arrays** (`consumes`, `consumed_by`, `consumed_by_planned`, `blocked_by`) using only schema-native keys (no invented `consumes_planned`); the planned upstream edges are recorded by adding `"honeydrunk-honeyhub"` to the **`consumed_by_planned`** arrays of `honeydrunk-architecture` and `honeydrunk-ai` (no live runtime edges; DAG preserved per invariant 4).
- [ ] `catalogs/grid-health.json` has a `honeydrunk-honeyhub` row at `version: "0.0.0"`, `canary_status: "none"`, honest `active_blockers`; `summary` counts incremented by reading actual values at edit time.
- [ ] `modules.json` handled per the non-publishing-Node convention (no invented package entries; PR body notes HoneyHub publishes no Grid package at v1).
- [ ] `constitution/sectors.md` Meta-sector table gains a HoneyHub row; the "Dependency Flow (Real Nodes)" block is **not** edited (flagged in PR body for the post-scaffold reconciliation).
- [ ] `initiatives/roadmap.md` gains a Q2 2026 HoneyHub bullet; `initiatives/active-initiatives.md` gains an "In Progress" entry referencing `initiatives/programs/honeyhub.md`.
- [ ] `repos/HoneyDrunk.HoneyHub/` exists with all five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`); `active-work.md` records the resolved node class (`studios-typescript-native`) and the ADR-0091/0092 `[Provisional]` seams.
- [ ] No `constitution/invariants.md` edit (ADRs explicitly add no new invariant); no `adrs/*.md` Status flip in this packet.
- [ ] Repo-level `CHANGELOG.md` (Architecture) gains an entry for the HoneyHub registration under the in-progress version section (invariants 12, 27).
- [ ] PR body links the packet (invariant 32) and notes the resolved `studios-typescript-native` node class.

## Human Prerequisites
None. This is an agent-eligible Architecture-repo edit (catalog rows + context folder + sector row + roadmap/initiative entries). The GitHub repo creation and org-admin actions are packet 02.

## Dependencies
None. This is the first packet of the initiative (Phase A registration) and has no blockers. The body's narrative dependency on ADR-0091 being the governing decision is informational; the `dependencies:` frontmatter is empty.

## Agent Handoff

**Objective:** Land the Phase A standup registration (catalogs + sector + five-file context folder) for the new `HoneyDrunk.HoneyHub` Node, and record the resolved node class (`studios-typescript-native`).
**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.
**Context:**
- Goal: stand up the HoneyHub Agent Cockpit Node (PDR-0011, the lead near-term build thread).
- Feature: Phase A of the ADR-0082 canonical node-standup for `HoneyDrunk.HoneyHub`.
- ADRs: ADR-0091 (app stack + Node home), ADR-0090 (bridge + session contract), ADR-0092 (session/usage/routing), ADR-0082 (standup procedure).

**Acceptance Criteria:**
- [ ] All catalog files + sector row + roadmap + active-initiatives + five-file context folder landed per the body.
- [ ] DAG preserved — no live runtime edge added; `consumes` empty.
- [ ] Node-class recorded in `active-work.md` as `studios-typescript-native` (self-contained `pr.yml`; required check `pr / build`); remaining `[Provisional]` seams (bridge language, shell toolkit, relay, store engine) listed.
- [ ] Architecture CHANGELOG updated; no invariant edit; no ADR Status flip.

**Dependencies:**
- None (first packet).

**Constraints:**
- Invariant 102 (Node registration is mandatory before the first non-bootstrap PR merges): every Node repo must have, before its first non-bootstrap PR merges, an entry in `catalogs/nodes.json`, a section in `catalogs/relationships.json`, an entry in `catalogs/grid-health.json`, a context folder at `repos/{NodeName}/` with all five files, a sector row in `constitution/sectors.md`, a `repo-to-node.yml` mapping, `.honeydrunk-review.yaml`, a `pr.yml`, branch protection on the required PR check, and org-secret repo binding. For this `studios-typescript-native` Node, the `pr.yml` is **self-contained** (it does NOT call `pr-core.yml`) and the required `main` check is **`pr / build`** (not `pr-core / core`); the default org-secret binding is **none** (see packets 02/03). This packet lands the catalog/context/sector subset; packets 02/03 land the rest.
- Invariant 41 (new Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time — a repo missing from the catalog is invisible to grid observability).
- Invariant 33 (review-agent and scope-agent context-loading contracts are coupled — the five-file context folder is the surface both agents load; all five files must exist and be substantive).
- Invariant 4 (the dependency graph is a DAG; Kernel is always at the root) — HoneyHub adds no cycle and no live upstream edge at v1; all edges are `*_planned`.
- Invariant 12 / 27 (semantic versioning with CHANGELOG; all projects in a solution share one version) — update the Architecture repo-level CHANGELOG.
- ADR-0082 D2 taxonomy: declare `node_class: studios-typescript-native` (the dedicated seventh class added by the ADR-0082 2026-06-06 amendment). The amendment + the `constitution/node-standup.md` update land as part of this initiative; this packet wires the catalog identity to that class.
- Do not flip any ADR Status; do not add a `constitution/invariants.md` entry (the ADRs add none).

**Key Files:**
- `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/modules.json`
- `constitution/sectors.md`
- `initiatives/roadmap.md`, `initiatives/active-initiatives.md`
- `repos/HoneyDrunk.HoneyHub/{overview,boundaries,invariants,active-work,integration-points}.md`
- `CHANGELOG.md` (repo root)

**Contracts:**
- No code contracts in this packet. The catalog `exposes.contracts` array records the ADR-0090 session-model entity names for discoverability only.
