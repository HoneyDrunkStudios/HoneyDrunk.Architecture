# PDR-0009: HoneyHub as Internal Daily-Driver Workspace

**Status:** Proposed
**Date:** 2026-05-25
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / Platform
**Extends:** [PDR-0001](PDR-0001-honeyhub-platform-observation-and-ai-routing.md) (HoneyHub Platform — Observation and AI Routing Layers)

---

## Context

PDR-0001 repositioned HoneyHub from "internal control plane" to "operating system for any software project," introduced the Observation and AI Routing layers, and reconciled internal-versus-external value through explicit fidelity tiers (Native, Observed, Inferred). It is the load-bearing PDR for HoneyHub's external-platform direction.

What PDR-0001 left implicit, and what this PDR formalizes, is **the other half of HoneyHub's reason to exist**: it is also the operator's primary workspace. The Grid is built and operated by one human (with AI agents as collaborators) across 25+ repos, dozens of accepted ADRs and PDRs, a growing catalog of Nodes, an active initiative pipeline, and a packet-driven dispatch loop. The cognitive load of running this from scratch terminals, browser tabs, and a notes file is the actual daily problem. PDR-0001's external pitch is true and remains the long-term commercial direction. But the system also has to be the thing the operator opens on Monday morning.

ADR-0003 already accepted HoneyHub as a control plane in phases — Phase 1 (domain model + knowledge graph API) is the active build, with the developer-facing UI (Phase 4) explicitly deferred. This PDR does not contradict that phasing. It clarifies the *purpose* of that eventual UI, raises the priority of internal-daily-driver fitness from "nice eventual outcome" to a first-class success criterion, and names the composition model the UI will sit over so the architecture is legible before code is written.

It also reframes one specific PDR-0001 claim — that the Architecture repo is "static context" HoneyHub consumes — as an under-statement. In practice the Architecture repo has become a structured knowledge graph in markdown + JSON, and HoneyHub's UI should sit *directly over* that graph rather than mirror it into a parallel backend.

---

## Problem Statement

### 1. Internal-daily-driver fitness was never named

PDR-0001's narrative is dominated by the external-adoption story. The corresponding internal experience — the operator using HoneyHub as their primary workspace — is implicit in ADR-0003 Phase 4 ("Developer-facing UI") but not stated as a success criterion peer to "external platform." Without an explicit claim, the direction will decay into chat history and the eventual UI will be designed for external-tenant ergonomics first, internal-operator ergonomics second.

### 2. The Architecture repo's true role is under-stated

PDR-0001 describes the Architecture repo as "static context" HoneyHub consumes alongside Pulse signals and Observe events. That description is accurate but flat. In current practice, `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json`, `catalogs/grid-health.json`, `adrs/`, `pdrs/`, `initiatives/`, `generated/work-items/`, and `constitution/` form a structured knowledge graph in markdown + JSON that already answers most of the questions a HoneyHub UI would ask. If HoneyHub builds a parallel backend that mirrors this state, it duplicates state, breaks Architecture-as-code, and forces a migration. The repo *is* the structural backend.

### 3. The composition model for "what HoneyHub UI sits over" is unspecified

PDR-0001 names the inputs (Observe, Pulse, Architecture, HoneyDrunk.AI) but does not say what the UI composes. The operator needs a UI that simultaneously surfaces: structural facts (Nodes, contracts, decisions, packets, initiatives), operational state (telemetry, queue depth, rotation status, routing decisions, communications workflows, sessions), and dispatchable actions (open new ADR, scope a packet, refine, send Netrunner). Without an explicit composition model, the UI surface fragments into ad-hoc panels.

### 4. The action-versus-state boundary needs an invariant

The operator's daily loop is a mix of *reads* (status, decisions, packets) and *writes* (open a new ADR, dispatch a scope, file a packet). The Grid's existing discipline is that all state lives in version-controlled artifacts behind PR review. A UI that mutates catalogs or decision records directly would erode that discipline; a UI that opens draft PRs through the existing dispatch flow preserves it. This boundary needs to be a stated invariant of the platform, not an implementation detail discovered later.

### 5. Per-Node operational surface is unguided

Every Node deserves a "management page" inside HoneyHub. PDR-0001 implies this through fidelity tiers (native vs. observed) but does not specify a v1 shape that is useful *before* each Node implements a custom management surface. Without a generic shell that works from existing catalogs and grid-health, the per-Node management surface is gated on per-Node work that won't happen for a long time.

### 6. Products integrate inconsistently with HoneyHub

The Grid is growing a consumer-product portfolio (PDR-0002 Notify Cloud, PDR-0005 Hearth, PDR-0008 Curiosities, the operator's Honeyclaw bot, future products). Each will need an operational surface inside HoneyHub. Without a shared shell that treats Products like Nodes, each product invents its own integration.

---

## Decision

### A. Internal daily-driver fitness is a first-class success criterion

HoneyHub must become the operator's primary workspace — the single surface for planning, triage, dispatch, observation, decisions, and AI conversations. This goal is **peer with PDR-0001's external-platform pitch**, not subordinate. Both target audiences are served by the same product; the fidelity-tier model from PDR-0001 already reconciles them (native fidelity for internal Grid, observed fidelity for external).

Hand-writing code remains in the IDE. HoneyHub does not gain a code editor at any point. Agent-driven code work is dispatched *from* HoneyHub but executed in cloud runners against cloned repos with results returned as PRs. The IDE-versus-HoneyHub boundary is bright and permanent.

### B. The Architecture repo is HoneyHub's structural backend

PDR-0001's "static context" framing is upgraded. The Architecture repo *is* HoneyHub's structural backend. The following artifacts collectively form a structured knowledge graph in markdown + JSON that HoneyHub's UI reads directly:

| Source | What it provides |
|--------|------------------|
| `catalogs/nodes.json` | Node identity, sector, tier, owner, signal, version |
| `catalogs/relationships.json` | Dependency graph (edges between Nodes) |
| `catalogs/contracts.json` | Cross-Node contract surface |
| `catalogs/grid-health.json` | Per-Node health state, deployable status, review risk class |
| `adrs/` | Architecture Decision Records (markdown + frontmatter) |
| `pdrs/` | Product Decision Records (markdown + frontmatter) |
| `initiatives/` | Initiative narratives, active and archived |
| `generated/work-items/` | Filed and pending packets (markdown + `filed-work-items.json`) |
| `constitution/` | Invariants, sectors, AI-sector architecture, naming rules |
| `repos/{Node}/` | Per-Node overviews, boundaries, invariants, domain models |

HoneyHub's UI sits over this directly. No parallel backend is built. The Architecture repo remains the source of truth; HoneyHub maintains a derived read-index (potentially as static JSON, potentially as a cached service) and never authoritatively writes catalog or decision state.

### C. Composition model — two backends, one composed UI

HoneyHub's UI composes two distinct backends:

| Backend | Source | Provides |
|---------|--------|----------|
| **Structural backend** | Architecture repo | Nodes, contracts, decisions, packets, initiatives, invariants, boundaries |
| **Operational backend** | Per-Node management APIs | Telemetry (Pulse), delivery state (Notify), ingestion (Observe), rotation status (Vault), queue state (Transport), routing decisions and cost (AI), workflow state (Communications), sessions (Auth), audit records (Audit), and so on |

The UI is the composed workspace. A given page (e.g. the Notify Node page) draws structural facts from the Architecture repo and operational state from Notify's management surface; both are presented as one experience without the operator caring which backend supplied which row.

### D. PRs-as-artifacts invariant (architectural)

UI actions that produce new decision records, packets, or catalog changes — "New ADR," "New PDR," "Scope," "Refine," "Netrunner," "Site-sync," and any future composer/dispatch agent — open **draft pull requests** through the existing agent-dispatch flow. They do **not** directly mutate catalog or decision state in the Architecture repo (or any other repo).

This preserves:

- Architecture-as-code (all state in version-controlled markdown + JSON)
- The existing review-and-merge discipline (`pr-core`, cloud-wired `review` agent, branch protection)
- PR labeling, packet linkage, and `Authorship: agent-claude-code` conventions
- The acceptance workflow (Proposed → Accepted only after PR merge)

Consequence: v1 can be **largely read-only-with-dispatch** and still be enormously useful. The "write half" of every action is a PR, which the operator reviews and merges through the same flow they already use.

### E. Per-Node management page — generic shell first, custom tabs progressively

Every Node gets a management page composed from existing structural and operational sources. The v1 shell, achievable today without any Node implementing anything new, draws from:

- `catalogs/nodes.json` for identity, sector, tier, owner, signal
- `catalogs/grid-health.json` for status, deployable status, review risk class
- GitHub API for open issues, recent PRs, CI runs, latest release
- `repos/{Node}/` for overview, boundaries, invariants, domain model
- `adrs/` filtered by Node, `pdrs/` filtered by sector, packets filtered by initiative-or-Node label

Each Node progressively earns a richer Node-specific tab as it implements its operational surface. Pulse is the natural first earner (telemetry is universally useful); others follow as warranted.

### F. Products integrate via the same shell at appropriate fidelity tiers

Consumer products (Hearth, Curiosities, Notify Cloud as a product surface, Honeyclaw, future products) register with HoneyHub the same way Nodes do — either via the existing `catalogs/nodes.json` entry when they are first-party Grid components, or via a parallel Products sector entry if a separate taxonomy becomes warranted (a deliberate follow-up decision, not mandated here).

PDR-0001's fidelity tiers apply directly:

- **Native fidelity** — first-party HoneyDrunk products get full widgets (operational state from their own management surface, decisions, packets, workflow state)
- **Observed fidelity** — third-party or partially integrated products get observed-tier views (GitHub state, public health, declared metadata)

Hearth (PDR-0005), as the operator's first-build product pick, will be the first product to exercise this integration path. Its operational surface inside HoneyHub will set the pattern for Curiosities (PDR-0008) and others.

### G. Placement — no new Node yet

The UI surface lives inside the existing HoneyHub plan from PDR-0001 and ADR-0003 Phase 4. This PDR does **not** mandate creating a new Node such as `HoneyHub.Web`. If a separate Node becomes warranted (for hosting, auth, or deployment reasons), it is a deliberate follow-up ADR — not bundled into this decision.

The "agent-dispatch service" — the credentialed cloud worker that clones repos, runs composer/scope/refine/netrunner agents, and opens PRs — is named here, but its concrete placement (existing HoneyHub repo? new Node? GitHub Actions? Container Apps job?) and its contract are explicit follow-up work, not pre-decided.

---

## Options Evaluated

### Option A: Keep PDR-0001's external-first positioning untouched

**Description:** Make no changes. Continue treating "operating system for any software project" as the primary HoneyHub thesis; treat internal daily-driver fitness as an implicit consequence that will emerge as the platform matures.

**Pros:**
- Zero new architectural commitment
- PDR-0001 remains untouched

**Cons:**
- Internal-daily-driver direction decays into chat history with no record
- Eventual UI will be designed for external-tenant ergonomics first; the operator gets a secondary experience
- Per-Node operational surface remains unguided; each Node invents its own pattern when it gets there
- Products (Hearth, Curiosities, Honeyclaw) each invent their own integration with HoneyHub
- The Architecture repo's role as structural backend stays under-stated; risk of someone building a parallel backend later

**Verdict:** Rejected. The cost of writing this PDR is small; the cost of losing the direction is large. PDR-0001's external thesis is fine; this PDR adds the missing peer.

### Option B: Build a parallel backend independent of the Architecture repo

**Description:** HoneyHub maintains its own authoritative database of Nodes, decisions, packets, and initiatives. The Architecture repo becomes one of several inputs to HoneyHub's ingestion pipeline (Observe-style).

**Pros:**
- Familiar shape (canonical "platform with its own database")
- HoneyHub can model state the Architecture repo doesn't (UI preferences, dashboard layouts, ephemeral views)

**Cons:**
- Duplicates state — every catalog change has to flow into HoneyHub's database
- Breaks Architecture-as-code — the Architecture repo is no longer the source of truth, HoneyHub is, and the Architecture repo's PRs no longer have authority
- Forces a migration of existing structured artifacts into a new schema
- Erodes the agent-driven workflow that depends on markdown + JSON in the repo
- Two systems of record diverge over time, especially under outages or sync failures

**Verdict:** Rejected. Architecture-as-code is a foundational discipline of the Grid; building a parallel backend would undo it for marginal UI gains.

### Option C: HoneyHub UI sits over the Architecture repo + per-Node APIs, PRs-as-artifacts *(Selected)*

**Description:** HoneyHub's UI composes two backends — the Architecture repo (structural) and per-Node management APIs (operational). UI actions that mutate state open draft PRs through the existing agent-dispatch flow rather than writing directly. Per-Node management pages start as a generic shell composed from `nodes.json` + `grid-health.json` + GitHub, then progressively earn Node-specific tabs. Products integrate via the same shell using PDR-0001's fidelity tiers.

**Pros:**
- Architecture-as-code preserved end-to-end
- v1 can be largely read-only-with-dispatch and still enormously useful
- Per-Node management pages are useful from day one without per-Node work
- Products integrate via a single shared shape — no per-product UI rework
- Internal and external audiences share one model (fidelity tiers reconcile)
- Aligns with ADR-0003 Phase 4 commitments without contradicting them

**Cons:**
- UI write paths roundtrip through PRs (latency vs. direct writes)
- Per-Node management API contracts need a follow-up pattern decision
- Read-layer caching/indexing needs care so the Architecture repo isn't on the hot path for every page render

**Verdict:** Selected. The cons are addressable with optimistic UI, caching, and a follow-up ADR for the per-Node management surface. The pros preserve every existing discipline and let v1 ship with a fraction of the surface area.

### Option D: Spin up a separate `HoneyHub.Web` Node now

**Description:** Treat the UI surface as a separate Node from day one — its own repo, its own boundaries, its own management page. Decide hosting (Static Web Apps vs. Container Apps), auth (Entra), and deployment as part of this PDR.

**Pros:**
- Cleanest physical boundary
- Web concerns isolated from HoneyHub's existing knowledge-graph-and-orchestration concerns

**Cons:**
- Premature: ADR-0003 Phase 4 is explicitly deferred, and creating a new Node before there is code to put in it violates the "new-Node scaffolding needs its own ADR" preservation rule
- Pre-decides hosting/auth/deployment without the design work
- Locks in physical structure before the UI's actual shape is known

**Verdict:** Rejected for v1. Reasonable as a follow-up ADR once the UI's shape is clearer and hosting/auth need a decision.

---

## Tradeoffs

| Tradeoff | Favors | Rationale |
|----------|--------|-----------|
| Internal daily-driver fitness as first-class vs. external-platform purity | Both, as peers | The fidelity tiers from PDR-0001 reconcile internal and external in one product. Naming both as first-class success criteria prevents either from becoming the secondary experience. |
| Architecture repo as backend vs. parallel database | Architecture repo as backend | Architecture-as-code is foundational. A parallel database would force migrations and divergence. The repo is already a structured knowledge graph; the UI just needs to read it well. |
| PR-roundtrip writes vs. direct writes | PR roundtrips | Preserves the existing review/merge/label discipline. Latency is mitigated by optimistic UI and inline PR-state visibility. The cost is real but the benefit (every UI mutation is a reviewable artifact) is larger. |
| Generic Node shell first vs. wait for per-Node work | Generic shell first | A useful page on day one is better than a perfect page never. The shell composes from sources that already exist. Each Node earns a richer tab when it implements its management surface. |
| No new Node yet vs. spin up `HoneyHub.Web` | No new Node yet | Premature standup violates the "new-Node scaffolding needs its own ADR" rule. The UI surface can live inside the existing HoneyHub plan until physical structure is forced by hosting or auth needs. |
| Products via same shell vs. per-product integration | Same shell | Hearth, Curiosities, Notify Cloud, Honeyclaw, and future products are too many for per-product UI work. Fidelity tiers already provide the gradient. |

---

## Architecture Implications

### What this PDR *names* (no scaffolding triggered)

| Concept | Role |
|---------|------|
| **Structural backend** | The Architecture repo, read as a structured knowledge graph in markdown + JSON |
| **Operational backend** | The set of per-Node management APIs the UI composes alongside structural state |
| **Read layer** | The component (in-process or service) that loads catalogs + parses markdown frontmatter and exposes a queryable surface to the UI |
| **Agent-dispatch service** | The Claude-credentialed worker that clones repos, runs composer/scope/refine/netrunner agents, and opens PRs back to the source repo |
| **Per-Node management page** | The composed UI surface for any Node, starting as a generic shell and earning Node-specific tabs over time |

### What this PDR does NOT change

- **PDR-0001** is not modified. Its external-platform thesis, Observation domain, AI Routing layer, and fidelity-tier model all stand. This PDR adds a peer success criterion and refines the Architecture-repo framing.
- **ADR-0003** is not modified. HoneyHub's four-layer plan (Integration, Knowledge Graph, Orchestration Engine, Projection / UI) stands. Phase 4 deferral remains in effect; this PDR sets the *purpose* of that Phase 4 UI when it arrives.
- **No new Nodes** are added to `catalogs/nodes.json`. No new edges are added to `catalogs/relationships.json`.
- **`constitution/invariants.md`** is not modified by this PDR. The PRs-as-artifacts boundary stated here may become a formal invariant via a follow-up ADR.
- **`initiatives/active-initiatives.md`, `current-focus.md`, `releases.md`, and `roadmap.md`** are not modified. This is direction, not active build work.
- **No scaffolding, packets, or initiatives** are created. The operator's existing dispatch flow will handle that work when the time comes.

### v1 shape sketch (for reference, not commitment)

| Layer | v1 shape | Future |
|-------|----------|--------|
| **Read layer** | Loads catalogs + parses markdown frontmatter on a watch; exposes JSON or GraphQL. Can start as SSG-generated static JSON. | Becomes a cached service when read volume warrants it. |
| **Search** | Client-side Lunr / MiniSearch over the read-layer index. | Meilisearch when scale demands. |
| **Agent dispatch service** | Claude-credentialed worker that clones the target repo, runs the composer/scope/refine/netrunner agent, and opens a PR back to the right repo. | Placement and contract decided by a dedicated ADR. |
| **UI** | Graph browser (Nodes + relationships), filterable catalogs, ADR/PDR list with status/sector/date filters, initiative dashboard, packet inbox, grid-health, per-Node management pages (generic shell), agent kickoff buttons. | Custom per-Node tabs, dashboards, AI-assisted views, Pulse-driven status surfaces. |

### Boundaries (restated)

| Surface | Owns | Does NOT own |
|---------|------|--------------|
| HoneyHub UI | Composition of structural + operational backends; reads; dispatch buttons that open draft PRs | Authoritative writes to catalogs or decision records; code editing; secret storage; CI execution |
| Architecture repo | Structural source of truth (catalogs, decisions, packets, initiatives, constitution, per-Node docs) | Operational telemetry, runtime state, agent execution |
| Per-Node management surface | Operational state for that Node (telemetry, queue state, rotation, routing, sessions, audit records, workflow state) | Structural facts about the Node (those live in the Architecture repo) |
| Agent dispatch service | Repo cloning, agent execution, PR opening | Decisions about *what* to dispatch (operator drives that via the UI) |

---

## Product Implications

### Two audiences, one product

PDR-0001's fidelity-tier model already reconciles internal and external audiences in a single product. This PDR makes that reconciliation explicit at the workspace level:

| Audience | Fidelity tier | Experience |
|----------|---------------|------------|
| Operator (internal Grid) | Native | Full widgets — telemetry, routing decisions, rotation status, communications workflows, sessions, audit, packet inbox, decision composition, agent dispatch |
| External organization (observed projects) | Observed | Repo/issue/PR/CI visibility, basic signal correlation, planning support — the value tier from PDR-0001 §C |
| External organization (instrumented) | Standard | Pulse-instrumented runtime telemetry on top of observed-fidelity inputs |
| External organization (Grid-native) | Advanced | Full HoneyDrunk Kernel/Transport/Data stack integration |

The internal operator's experience sits at the top of the same fidelity gradient that external tenants climb. The same components serve both.

### Products integrate at appropriate fidelity tiers

| Product | Integration | Fidelity |
|---------|-------------|----------|
| Notify Cloud (PDR-0002) | First-party, registered as a Node | Native |
| Hearth (PDR-0005) | First-party, registered as a Node | Native (and first product to exercise the integration path) |
| Curiosities (PDR-0008) | First-party, registered as a Node | Native |
| Honeyclaw (operator's Telegram bot via OpenClaw) | First-party, registered as a Node or via a parallel Products sector | Native for operational state, Observed for OpenClaw's third-party hosting |
| Future external products | Via Observe connectors | Observed |

### What changes for the operator

- A single workspace replaces the patchwork of terminals, tabs, and notes
- Planning, triage, dispatch, observation, decisions, and AI conversations all happen in one surface
- Coding stays in the IDE; agent-driven code work is dispatched from the workspace
- Every UI mutation produces a reviewable PR — the existing review discipline holds end-to-end

### What does not change for the operator

- The IDE remains for hand-written code
- The packet → PR → review → merge discipline is unchanged
- The Architecture repo remains the source of truth; the operator can still work directly in markdown when they prefer

---

## What Does NOT Change

- **PDR-0001's external-platform thesis** — HoneyHub still targets the "operating system for any software project" positioning
- **PDR-0001's fidelity-tier model** — Native, Observed, Inferred remain the canonical tiers
- **ADR-0003's four-layer HoneyHub plan and phased acceptance** — Phase 1 active, Phase 4 UI still deferred until earlier phases prove out
- **Architecture-as-code** — catalogs, decisions, packets, initiatives, constitution all remain in version-controlled markdown + JSON
- **PR-driven review and merge discipline** — `pr-core`, cloud-wired `review`, branch protection, packet linkage, `out-of-band` labeling all stand
- **Acceptance workflow** — Proposed → Accepted only after PR merge (this PDR ships as Proposed; the operator's review and merge flips it)
- **`constitution/invariants.md`** — unchanged by this PDR; the PRs-as-artifacts boundary stated here is a candidate for a future formal invariant via ADR
- **`initiatives/active-initiatives.md`, `current-focus.md`, `releases.md`, `roadmap.md`** — unchanged; this is direction, not active build work
- **`catalogs/nodes.json` and `catalogs/relationships.json`** — no new entries or edges
- **The IDE-versus-HoneyHub boundary** — coding stays in the IDE; HoneyHub never gains a code editor

---

## Risks

| Risk | Severity | Description |
|------|----------|-------------|
| **UI becomes a slow shim over git operations** | Medium | PR roundtrips for every write create perceived latency. Without inline PR-state visibility and optimistic UI, the workspace feels like a slower wrapper around the existing flow. |
| **Per-Node management API contracts proliferate inconsistently** | Medium | Without a shared pattern, each Node invents its own management surface, and HoneyHub's UI fragments into Node-specific custom code. |
| **Architecture repo becomes load-bearing for a runtime system** | Medium | If every UI page render hits the repo, repo availability becomes a runtime concern. The repo should remain the source of truth, not the hot path. |
| **Scope creep — HoneyHub becomes "everything app"** | Medium | The pull toward "add a code editor," "add a terminal," "add chat" is strong. Without a bright boundary, HoneyHub absorbs responsibilities it should not own. |
| **Internal-versus-external positioning conflict** | Low | Internal-daily-driver and external-platform pull design in opposite directions on individual decisions (e.g. defaults, navigation, onboarding). |
| **Agent dispatch service grows ungoverned** | Medium | Repo cloning + Claude credentials + PR opening is powerful and underspecified. Without an ADR, the service evolves ad-hoc and accumulates implicit trust. |
| **Read layer caching becomes its own complexity tax** | Low | A naive watch-on-the-repo read layer scales poorly; a sophisticated one becomes a system to maintain. |

---

## Mitigations

| Risk | Mitigation |
|------|------------|
| Slow shim over git | Optimistic UI on dispatch actions; dispatch returns the PR URL immediately; PR state visible inline; long-running operations are background tasks with progress indicators, not blocking modals. |
| Inconsistent per-Node API contracts | Follow-up ADR defines the per-Node management surface pattern (or equivalent contract). Until that ADR lands, v1 falls back to the generic shell composed from `nodes.json` + `grid-health.json` + GitHub — useful without any Node implementing anything new. |
| Architecture repo on the hot path | Read layer caches aggressively; repo is the source of truth, not the per-render data source. SSG-generated static JSON is a viable v1. |
| Scope creep | Explicit boundary stated and re-stated: **coding stays in the IDE; HoneyHub never gains a code editor**. Any proposed addition that crosses this line requires a new PDR. |
| Internal-vs-external conflict | Fidelity tiers from PDR-0001 are the reconciliation mechanism. Native gets full widgets; observed gets observed-tier — same model serves both audiences. When a specific decision pulls in opposite directions, the operator's daily-driver fitness wins for default behavior; external configuration adjusts. |
| Agent dispatch service ungoverned | Dedicated ADR for the agent dispatch service architecture — placement, auth, repo-cloning model, sandboxing, secret handling — before any production deployment of that service. |
| Read layer caching complexity | v1 read layer is the simplest thing that works (SSG static JSON, watch-and-rebuild). Caching sophistication earned by demand, not pre-built. |

---

## Consequences

### Short-term

- The internal-daily-driver thesis is on record alongside PDR-0001's external thesis
- The Architecture repo's role as structural backend is named explicitly; future design conversations don't need to re-derive it
- The composition model (structural + operational) gives the eventual UI a clear shape to compose against
- The PRs-as-artifacts boundary is stated; it can be promoted to a formal invariant via ADR when warranted
- The per-Node management page shape is described well enough that v1 can ship as a generic shell when ADR-0003 Phase 4 work begins
- Products (Hearth first) have a clear integration target — same shell, fidelity tier matches first-party-ness

### Long-term

- HoneyHub's eventual UI is designed for both internal and external from the first stroke, with fidelity tiers as the reconciliation mechanism
- The operator runs the Grid from a single workspace, not a patchwork of tooling
- Every UI mutation flows through the same PR/review/merge discipline that already governs the Grid
- Per-Node management surfaces emerge progressively without a "rewrite the Node UI" cliff
- Products integrate at consistent fidelity tiers without per-product UI work
- The agent-dispatch service, once specified, makes "open a new ADR from the workspace" a first-class operation

---

## Rollout — Phased Approach

This PDR is direction. The phased rollout below sketches *when* its consequences land, not *what* is built immediately. Execution happens through subsequent packets and initiatives.

### Phase 1: Direction on record

- This PDR is accepted (after review)
- Future HoneyHub design conversations reference this PDR for internal-daily-driver positioning
- Follow-up ADRs (listed below) are written when their underlying work needs to start

### Phase 2: Read layer + generic Node shell

- Read layer over the Architecture repo's catalogs + frontmatter (SSG-generated static JSON is acceptable for v1)
- Generic Node management page composed from `nodes.json` + `grid-health.json` + GitHub
- ADR/PDR/initiative/packet list views with filters
- No dispatch actions yet

### Phase 3: Dispatch actions via PRs

- "New ADR," "New PDR," "Scope," "Refine," "Netrunner," "Site-sync" buttons open draft PRs through the agent-dispatch service
- Agent-dispatch service ADR is accepted before this phase ships
- Optimistic UI + inline PR-state visibility

### Phase 4: Per-Node operational tabs

- Pulse is the natural first earner: telemetry tab on every Node's management page
- Other Nodes earn richer tabs as they implement their management surface
- Per-Node management surface ADR (or equivalent pattern) governs how each Node declares its operational shape

### Phase 5: Products on the same shell

- Hearth (PDR-0005), as the operator's first-build product pick, is the first product to exercise the integration path at native fidelity
- Curiosities (PDR-0008), Notify Cloud (PDR-0002), Honeyclaw, and future products follow the same pattern at their appropriate fidelity tier
- Possibly: parallel Products sector if taxonomy clarity warrants it (a follow-up decision)

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Where does the agent-dispatch service physically live? (HoneyHub repo? new Node? Actions? Container Apps job?) | Architecture | Open — follow-up ADR. Touches secret handling, repo-cloning model, sandboxing. |
| What is the contract for a per-Node management surface? | Architecture | Open — follow-up ADR. v1 falls back to generic shell. |
| Where is the HoneyHub UI hosted, and how is it authenticated? (Static Web Apps vs. Container Apps; Entra ID for internal access) | Architecture / Ops | Open — follow-up ADR when Phase 4 work begins. |
| Read-layer format and refresh semantics — SSG static JSON, in-process index, or cached service? | Architecture | Open — start with simplest viable (SSG). |
| Should HoneyHub UI surface live inside the existing HoneyHub plan or become a separate `HoneyHub.Web` Node? | Architecture | Open — deliberate follow-up ADR if warranted. Not pre-decided here. |
| Do products register as Nodes or via a parallel Products sector? | Architecture / Product | Open — first product (Hearth) likely exercises the as-a-Node path; sector taxonomy decision deferred. |
| How do product Nodes declare their operational surface to HoneyHub? | Architecture / Product | Open — design doc or PDR once Hearth begins integration. |
| Does PRs-as-artifacts deserve promotion to a formal `constitution/invariants.md` entry? | Architecture | Open — likely yes once the agent-dispatch ADR is accepted. |
| What is the latency budget for dispatch-action UI feedback? | Product | Open — depends on agent-dispatch service shape. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|----------|------|---------|
| Agent-dispatch service architecture | ADR | Placement, auth, repo-cloning model, sandboxing, secret handling, PR-opening contract |
| Per-Node management surface contract | ADR | The pattern by which each Node declares its operational shape to HoneyHub (or equivalent) |
| HoneyHub UI hosting and deployment | ADR | Static Web Apps vs. Container Apps; auth model (likely Entra); environment promotion |
| Catalog read API / index format | Design doc | Format, refresh semantics, caching, SSG-vs-service tradeoff |
| `HoneyHub.Web` Node standup | ADR | Only if a separate Node becomes warranted; deliberate follow-up, not pre-decided |
| Product operational-surface declaration | PDR or design doc | How product Nodes (Hearth first, then Curiosities, Notify Cloud, Honeyclaw) declare their HoneyHub integration shape |
| PRs-as-artifacts as formal invariant | Invariant amendment via ADR | Promote the boundary stated in §D from PDR-level claim to constitution-level invariant once the agent-dispatch ADR is accepted |
