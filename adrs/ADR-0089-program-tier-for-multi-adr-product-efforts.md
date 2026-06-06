# ADR-0089: Program Tier for Multi-ADR Product Efforts

**Status:** Proposed
**Date:** 2026-06-06
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

The Grid's work-tracking model has a well-defined spine for *small* units of work and a well-defined horizon for *strategic* direction, but nothing durable in between for a single product that spawns many decisions.

The existing layers, from coarse to fine:

- **PDR** (`pdrs/PDR-*.md`) — a product *decision*. It records what a product is, why, the trade-offs, the kill criteria, and the recommended follow-up artifacts. It is a decision document, not a live tracker; once Accepted it is amended rarely (PDR-0011's same-day amendment is the exception, not the rule). A PDR does not hold live status across the ADRs it spawns.
- **`roadmap.md`** — groups work by "product thread" (HoneyHub / Notify Cloud / Curiosities) at the *quarterly horizon*. It answers "what quarter does this land in," not "what is the live dependency graph between this product's decisions right now."
- **`current-focus.md`** — the ranked, strict-ordinal priority list. A product surfaces here as *one row at a time* (HoneyHub is rank #1 today as "promote the local-runner-bridge ADR"), never as a whole multi-ADR effort. By design — `current-focus.md` rows are single phases, not rollouts.
- **`proposed-adrs.md`** — the pre-acceptance queue for individual ADRs/PDRs. It tracks each decision's packet-closure state in isolation; it does not express that ADR X cites ADR Y's contract, or that phase 3 can't build until phase 2 ships.
- **`active-initiatives.md`** — tracks rollouts that are **~1:1 with a single ADR** (or a single ADR family). An "initiative" today is one decision's implementation: its packets, its waves, its Hive issues, its exit criteria. ADR-0077, ADR-0043, ADR-0052 each get one initiative entry.
- **Packets** (`generated/issue-packets/`) → **Hive issues** (org Project #4) → **PRs** — the execution substrate. The `file-issues` agent wires *build-dependency* blocking relationships between implementation issues on the board.

The gap is concrete and the operator hit it starting HoneyHub. **PDR-0011 (Accepted) spawns 5+ ADRs**, each with its own initiative, in a dependency chain:

- the **local-runner-bridge ADR** (promote from `generated/adr-drafts/ADR-DRAFT-honeyhub-local-runner-bridge.md`) — the v1 foundation;
- the **app-stack ADR** (the `[Provisional]` Tauri-class shell + mobile→bridge relay, PDR-0011 §6 / Follow-Up Artifacts);
- a **session + usage-telemetry ADR** (`DispatchSession` / `DispatchRun` / `UsageSignal`, PDR-0011 Follow-Up Artifacts), which carries the routing + subscription-governance surface;
- and a gated **v2 cluster** behind the §5 validation probe and the §3 `[Firm]` boundary: **BYOK cloud-execution**, the **Dev-surface** ADR (the re-sequenced PDR-0009 read-layer), a **team/org-governance** ADR, and a **learned-coaching** enrichment.

These have real edges. The routing/telemetry ADR cannot be written until the bridge ADR is Accepted (it depends on the bridge's session contract). BYOK cloud-execution can't build until the local v1 ships and the §5 probe converts. The dependency is *between decisions* and *between phases*, and **no Grid construct holds it**. The same shape applies to **Notify Cloud (PDR-0002)** — ADR-0027 node standup, tenant-isolation (ADR-0026/0050), Stripe/billing (ADR-0037), REST API (ADR-0057), client NuGet (ADR-0034/0035) — and to **Curiosities (PDR-0008)**. These are exactly the three named 2026 product threads on `roadmap.md`.

Today the operator reconstructs that graph from memory each time, or spreads it implicitly across a PDR's Rollout section, several `active-initiatives.md` entries, a `roadmap.md` line, and the Hive board's blocking edges. Nothing is the single live home for "where is this *product* as a whole, and what unblocks what." That reconstruction cost is the bottleneck this ADR closes — the same asymmetry ADR-0043 closed for backlog sourcing, applied to multi-decision products.

This is a process/meta ADR in the lineage of ADR-0008 (work-tracking spine), ADR-0043 (backlog generation), and ADR-0082 (node-standup procedure): it formalizes a layer of the Grid's own workflow.

## Decision

### D1 — Name the tier "Program"

The new tier is the **Program**: a major, durable effort governed by a PDR that spans **multiple ADRs and their initiatives**.

"Program" is chosen over the alternatives:

- **"Product"** is rejected because the governing PDR already *is* the product decision, and not every program is a sellable product (a large internal substrate effort governed by one PDR could be a program too). "Product" also collides with `roadmap.md`'s existing "product thread" language in a confusing way — the program is the *durable home* of a roadmap thread, not a rename of it.
- **"Epic"** is rejected because it is Hive/issue-tracker vocabulary (GitHub Projects, Jira). The Grid deliberately keeps its decision-layer vocabulary (PDR / ADR / BDR / initiative / packet) distinct from its issue-board vocabulary. Borrowing "Epic" upward would blur the decision layer into the board layer.
- **"Thread"** (from `roadmap.md`) is rejected as the *tier* name because a roadmap thread is a horizon grouping, not a tracked artifact with a schema. The program is what a roadmap thread *points at* once it has more than one ADR; reusing "thread" for both would erase that distinction. Instead, **a `roadmap.md` product thread links to its Program tracker** (D3), and the program is the thread's durable, live backing.

A Program is created when, and only when, **a PDR spawns more than one ADR**. A PDR that resolves into a single ADR + single initiative needs no program — `active-initiatives.md` already holds it. This keeps the tier from adding ceremony to small efforts.

### D2 — Placement in the hierarchy; it groups initiatives, it does not replace them

The full hierarchy, coarse to fine:

```
PDR  (the product decision — pdrs/PDR-*.md)
 └── Program  (the live cross-ADR tracker — initiatives/programs/{slug}.md)   ← NEW
      ├── ADR  (a decision the program needs — adrs/ADR-*.md)
      │    └── Initiative  (that ADR's rollout — active-initiatives.md)
      │         └── Packet  (generated/issue-packets/)
      │              └── Hive issue  (org Project #4)
      │                   └── PR
      ├── ADR → Initiative → ...
      └── ADR → Initiative → ...
```

The Program sits **between the PDR and the set of ADRs**. It is explicitly a **grouping layer, not a replacement** for "initiative":

- An **initiative stays exactly what it is today** — the ~1:1 rollout of a single ADR (or single ADR family). ADR-0089 changes nothing about initiative semantics, `active-initiatives.md` schema, packet lifecycle, or hive-sync's initiative reconciliation.
- A **Program references** the child initiatives; it does not absorb them. A program with five ADRs has up to five initiative entries in `active-initiatives.md`, each tracked normally. The program is the index and the dependency graph *over* them.

Mapping to the adjacent surfaces (each is referenced, none is duplicated):

| Surface | Relationship to a Program |
|---------|---------------------------|
| **PDR** | The program's governing decision and kill-criteria source. One PDR → at most one Program. The program links up to the PDR; the PDR is unchanged by program creation. |
| **`roadmap.md` thread** | The program is the **durable backing of a roadmap product thread**. The thread's quarterly line links down to the program tracker; the program does not restate quarters. |
| **`current-focus.md` row** | A program may surface **one ranked row at a time** (the current actionable phase). `current-focus.md` stays single-phase-per-row; the program's "what's next" pointer is what gets promoted into a row. The program never becomes a multi-row block on the focus list. |
| **`proposed-adrs.md`** | Tracks each child ADR's pre-acceptance packet-closure in isolation, as today. The program's ADR dependency map (D4) *links to* those rows; it does not replace the queue. |
| **`active-initiatives.md`** | Holds each child initiative. The program links to each entry; status flows **up** from initiatives to the program rollup, never the reverse. |
| **Hive board (Project #4)** | Build-dependency blocking edges between *implementation issues* remain the `file-issues` agent's job. The program's dependency map is the **decision-and-phase-level** graph that those issue-level edges roll up to. The program tracker may carry an optional Hive epic/label name for board filtering, but the board is not the program's system of record. |

The program adds **one** new edge type to the model: **decision-to-decision and phase-to-phase dependency**, which no existing surface holds. Everything else it does is *reference and rollup* over existing surfaces.

### D3 — Programs live at `initiatives/programs/{slug}.md`, one file per program

A program tracker is a single Markdown file at `initiatives/programs/{slug}.md` (e.g. `initiatives/programs/honeyhub.md`). The `initiatives/programs/` directory is new and is created by the first program instance (backfill, D6). The slug matches the roadmap thread name, lowercased and kebabed.

A program tracker has this schema. It is deliberately thin — every section is either a link list or a single table, and the operator updates it by hand on ADR status changes (D5):

```markdown
# Program: {Name}

**Governing PDR:** [PDR-NNNN: {title}](../../pdrs/PDR-NNNN-...md) — {status}
**Status:** {Forming | Active | Gated | Paused | Shipped | Killed}
**Roadmap thread:** [{thread name}](../roadmap.md#...)   ·   **Current-focus row:** {rank # or "—"}
**Kill criteria / gates:** {one-line pointer to the PDR section that holds them}
**Last updated:** {YYYY-MM-DD}

## Phase Roadmap
{The phase sequence taken from the PDR's Rollout section — phase name, one-line goal,
 and the decision(s) that constitute each phase. This is the product's spine, not a date plan;
 dates live on roadmap.md.}

| Phase | Goal | Decisions in phase | State |
|-------|------|--------------------|-------|

## ADR Dependency Map
{THE core artifact. One row per decision the program needs. Captures both edge types:
 decision→decision (an ADR citing another's contract) and decision→build / build→build
 (a phase needing a prior phase to ship). "Depends on" / "Unblocks" name the other rows.}

| Decision | Status | Depends on | Unblocks | Phase |
|----------|--------|------------|----------|-------|

## Child Initiatives
{One row per child initiative, linking to its active-initiatives.md entry and its Hive work.}

| Initiative | Governing ADR | active-initiatives link | Hive |
|------------|---------------|-------------------------|------|

## Status Rollup
{2–4 sentences: where the program is overall, what's in flight, what's blocked on what,
 and the single next action. This is the human-readable head of the program.}
```

**ADR Dependency Map columns** (the operator's actual ask — load-bearing, stated exactly):

- **Decision** — the ADR (or named ADR-draft) the program needs. Link when numbered; name the draft when not yet promoted.
- **Status** — one of `needed → drafting → accepted → implemented`, **or** `gated` (a decision deliberately blocked behind a PDR gate / kill-criterion / validation probe, not yet eligible to start). The four-step main line tracks a decision from "we know we need it" through "shipped"; `gated` is the off-ramp for v2-style deferred work.
- **Depends on** — the other map rows (or external ADRs) this decision requires before it can be *drafted or built*. This column carries **both** edge types: a decision→decision edge ("routing/telemetry ADR depends on bridge ADR" — cites its contract) and a decision→build / build→build edge ("BYOK cloud depends on local-v1 *shipped*" — a phase needing a prior phase). Name the dependency kind inline when it isn't obvious (e.g. "bridge ADR *accepted*" vs "local v1 *shipped*").
- **Unblocks** — the inverse: which rows this decision frees once it reaches its required status. Maintaining both directions is intentional redundancy — it makes the graph readable from either end and makes a stale edge obvious.
- **Phase** — which Phase Roadmap phase this decision belongs to.

### D4 — The dependency map is the program's reason to exist

The ADR Dependency Map is the single artifact that no existing surface provides and the reason the tier is worth adding. It is the live answer to "what is the critical path through this product's decisions, and what is blocked on what right now." `roadmap.md` can't hold it (horizon-only), `current-focus.md` can't (single-row), `proposed-adrs.md` can't (per-decision, no edges), `active-initiatives.md` can't (per-rollout, no cross-ADR edges), and the Hive board holds only the *issue-level* edges one layer below. The map rolls those issue-level edges up to the decision-and-phase level a solo operator actually reasons in.

### D5 — Lifecycle and ownership

- **Creation.** A program tracker is created when a PDR is Accepted (or amended) into a shape that spawns **more than one ADR**. Creation is an execution step (a packet or a hand edit), not part of accepting the PDR — accepting the PDR remains the PDR's own concern. The trigger is "a PDR with >1 implementing ADR exists without a program file."
- **Ownership / cadence.** The program tracker is **operator-maintained by hand**, updated on **child-ADR status changes** (a child ADR moves `needed→drafting`, gets a number, flips to Accepted, or an initiative completes) and at the weekly ADR-0043 briefing review. The update is small: flip one Status cell, adjust the affected Depends-on/Unblocks edges, refresh the Status Rollup and Last-updated line. No agent is required to keep it live at v1.
- **Forward-compat with ADR-0043.** The program tracker is designed to be **fed by, not dependent on, ADR-0043 backlog generation**. When ADR-0043's Strategic source fires on a child ADR's acceptance, that same event is the natural trigger to flip the corresponding dependency-map row — a future enhancement may have `hive-sync` or the Strategic-source pass update the map row automatically. ADR-0089 does **not** require that automation; the manual path is the committed v1 and the automated path is an explicitly optional follow-up. This mirrors how ADR-0043 itself layered automation onto the pre-existing manual packet flow.

### D6 — Backfill: the three 2026 threads become the first programs

The three named 2026 roadmap product threads become the first program instances, created as execution (packets/hand edits), not as part of this ADR's decision:

- **HoneyHub** → `initiatives/programs/honeyhub.md`, governing PDR-0011 (with PDR-0001/PDR-0009 as the external-platform and read-layer context). First and highest-value instance — it is the live forcing function for this ADR.
- **Notify Cloud** → `initiatives/programs/notify-cloud.md`, governing PDR-0002.
- **Curiosities** → `initiatives/programs/curiosities.md`, governing PDR-0008.

Instantiation (populating each map, wiring the child-initiative links) is downstream packet work, named here but not performed by this ADR.

### D7 — No new invariant at v1

ADR-0089 does **not** add a constitutional invariant. A candidate rule was considered — *"every Accepted PDR that spawns >1 ADR has a program tracker at `initiatives/programs/{slug}.md`"* — and is **deliberately deferred**, not adopted, for a solo operator:

- There are exactly **three** programs at v1. The membership rule is trivially checkable by eye; a constitutional invariant + an enforcement mechanism (a `review`/`node-audit`/hive-sync check) is more machinery than three files justify. The Grid's invariant discipline is real (115 live invariants), and adding one that polices a three-row set is the "performing visibility" failure mode the charter warns against.
- The convention is forward-only and low-stakes: a missing program tracker is a mild inconvenience, not a boundary violation or a correctness/security risk. That is the wrong profile for a canary-enforced invariant.
- Promotion path is left open: **if the number of concurrent programs grows past roughly five, or if a program tracker is found stale/missing in practice**, this ADR is amended to add the invariant and reserve a number. The convention earns enforcement when drift actually appears, consistent with ADR-0043's forward-only invariants 108/109 and the reservation system's "only file when you're authoring a packet today" rule.

Because no invariant is added, **no number is reserved** in `constitution/invariant-reservations.md` (next-free remains 116 for the next claimant).

## Consequences

- **New directory and convention.** `initiatives/programs/` is created (by the first backfill instance) with one file per multi-ADR product. The `initiatives/README` conventions and any agent that enumerates initiative surfaces should learn about it; `hive-sync`'s board-coverage reconciliation (invariant 112) is **unaffected** — programs reference initiatives and board items, they do not introduce new untracked board items.
- **`active-initiatives.md`, packet lifecycle, and initiative semantics are unchanged.** Programs are purely additive: a reference-and-rollup layer above initiatives.
- **`roadmap.md` and `current-focus.md` gain a link target.** Each of the three product threads on `roadmap.md` can now link to its program tracker; the rank-#1 HoneyHub row on `current-focus.md` can link to `programs/honeyhub.md` for the full dependency picture. These are link additions, not schema changes.
- **Backfill work.** Three program trackers (HoneyHub, Notify Cloud, Curiosities) are authored as a follow-up packet set; HoneyHub first. Delegate to the `scope` agent to generate the issue packets for the directory creation + the three trackers + the roadmap/current-focus link edits.
- **No invariant, no catalog edit, no Node-graph cascade.** This ADR touches only the `initiatives/` work-tracking surface and the `adrs/` index. No `nodes.json` / `relationships.json` / `grid-health.json` change; no `constitution/invariants.md` change.
- **Forward-compat hook for ADR-0043.** The dependency-map row becomes a natural automation target once ADR-0043's Strategic source is live; this ADR keeps that path open without depending on it.

## Alternatives Considered

- **Do nothing; keep spreading the graph across PDR Rollout + initiatives + roadmap + the board.** Rejected. This is the status quo that produced the gap. The operator reconstructs the cross-ADR dependency graph from memory each time a product advances; that reconstruction cost is exactly the throughput cap on multi-ADR products, and it grows with the v2 gated clusters.
- **Extend `active-initiatives.md` to allow a "multi-ADR initiative" instead of a new tier.** Rejected. It would overload "initiative," which is precisely the ~1:1-with-an-ADR unit the whole downstream pipeline (packets, dispatch plans, hive-sync, invariant 110 implementation-notes) assumes. Stretching it to mean "a whole product" would muddy every consumer of the word and the schema.
- **Put the dependency graph on the Hive board as an epic with blocking issues.** Rejected as the *system of record*. The board holds implementation-issue edges (and the program references them), but decisions that are not yet drafted have no issue to block on, gated v2 work has no board presence, and the board is not version-controlled Markdown the operator reviews in the repo. The decision-and-phase-level graph belongs in `initiatives/`, with the board as the layer below it.
- **Name the tier "Product" or "Epic."** Rejected per D1 — "Product" collides with the PDR's role and roadmap's "thread" wording; "Epic" imports issue-board vocabulary into the decision layer the Grid keeps deliberately separate.
- **Add the membership invariant now.** Rejected per D7 — three files do not justify a canary-enforced constitutional rule for a solo operator; the convention earns enforcement if and when drift appears, and the promotion path is named.
- **Make the tracker agent-generated/maintained from day one.** Rejected for v1. The manual tracker is cheap and the trigger events (ADR status flips) are already operator-touched. Automation is the right ADR-0043-fed follow-up, not a v1 dependency that would couple this thin convention to a larger automation surface.
