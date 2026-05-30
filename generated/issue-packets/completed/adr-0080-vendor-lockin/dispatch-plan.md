# Dispatch Plan — ADR-0080: Vendor Lock-In Posture and Exit-Readiness Hedges

**Initiative:** `adr-0080-vendor-lockin`
**ADR:** ADR-0080 (Proposed → Accepted via packet 00)
**Sector:** Meta / Infrastructure / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0080 commits the Grid's **vendor posture as a chosen position** rather than accidental drift. It assigns each load-bearing vendor one of three postures — **Accept (deep, intentional)**, **Hedge (active)**, or **Abstract (already portable)** — names the cheap hedges that apply Grid-wide, defines the decision-point triggers that fire a posture re-evaluation conversation (the charter's "decision points are in, kill clocks are out" framing), and creates a new `governance/vendor-postures/` canonical home for per-vendor governance files. The two **Accept**-posture vendors (Azure, GitHub) get placeholder stubs at this initiative's acceptance; full content is deliberately deferred.

This initiative delivers: ADR acceptance + the three new vendor-posture invariants + initiative registration (Architecture); the new `governance/vendor-postures/` directory (Architecture); the `azure.md` stub documenting Azure's Accept posture, its current hedges (Redis-protocol-only per ADR-0076 D3, Bicep modules per ADR-0077 D2, OIDC-standard-claims-only per ADR-0078 D3, OTel-first emit per ADR-0040, `ISecretStore`/`IConfigProvider` per ADR-0005), and the honest per-surface exit-cost narrative (Architecture); the `github.md` stub documenting GitHub's Accept posture, the SCM-migration-pre-condition framing, and the honest exit-cost narrative (Architecture); and the citation-only follow-up edits to ADR-0076, ADR-0077, and ADR-0078 redirecting their pending "vendor-exit playbook" references to `governance/vendor-postures/azure.md` (Architecture).

**4 packets across 2 waves**, targeting **1 repo** (`HoneyDrunk.Architecture`). All 4 are `Actor=Agent`, 0 `Actor=Human`. No code, no .NET project, no workflow. Pure governance.

## Trigger

ADR-0080 is Proposed with no scope. The forcing functions (from the ADR's Context):

- **Three ADRs already cite the same pattern.** ADR-0076 D3, ADR-0077 D5, and ADR-0078 D3 each name Redis-protocol-only, Bicep modules by concern, and OIDC-standard claims only as "the cheap vendor-exit hedge." Three ADRs cite the same pattern; none of them is the umbrella that says it is Grid-wide discipline rather than three coincidences.
- **AI-sector invariants already prove the discipline works.** Invariants 28, 29, 44, and 45 instantiated the pattern for the AI sector through `IModelRouter` and `HoneyDrunk.AI.Abstractions`. ADR-0080 generalizes the same discipline to every vendor surface.
- **The candidate-surface doc explicitly names this artifact.** `generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md` cluster 2.1 observes that *"each vendor ADR cites a future 'vendor-exit playbook' without a defined home or shape."* The ADRs are leaving footnotes that point nowhere. ADR-0080 resolves the pointer.
- **The charter's many-decade horizon.** A studio with a 12-month horizon may treat lock-in as "future-self's problem." A studio with a multi-decade horizon will see at least one of its vendor relationships turn — through pricing, terms, acquisition, deprecation, or simple drift in alignment. The hedges are cheap **only because** they are pre-paid before lock-in compounds.

This ADR explicitly does **not** enable cheap migration; it makes the lock-in deliberate. All hedges in D3 are already true at the code level via the existing invariants and source ADRs — no code changes are implied by acceptance. The initiative is **governance-shaped**, not code-shaped.

## Scope Detection

**Single-repo (`HoneyDrunk.Architecture` only).** ADR-0080's Affected Nodes section is explicit: *"No application-code Node is directly affected by this ADR. The hedges in D3 are already in place at the code level via the source ADRs and the existing invariants (1, 2, 3, 28, 29, 44, 45)."* The work surface is the Architecture repo's governance, ADR, and invariants files — and the three cross-link footnotes in ADR-0076/0077/0078 that point at the new `governance/vendor-postures/azure.md` canonical home.

**No new-Node scaffolding.** No empty cataloged repo is touched; no standup ADR is needed. No catalog schema change is needed — `governance/vendor-postures/` is its own canonical home, named in ADR-0080 D5; it does not need a `catalogs/contracts.json` or `catalogs/grid-health.json` entry.

## Wave Diagram

### Wave 1 (No Dependencies — governance acceptance)
- [ ] **00** — Architecture: Accept ADR-0080, claim a 3-invariant block in `constitution/invariant-reservations.md` and add the three vendor-posture invariants under that block (placeholders `{N1}/{N2}/{N3}`), register the initiative. `Actor=Agent`.

> **Invariant numbering.** Packet 00 reads `constitution/invariant-reservations.md`, picks the next contiguous block of size 3 above the highest existing reservation, and adds an `Active Reservations` row for ADR-0080 in the same PR that writes packet 00. The packet body uses `{N1}/{N2}/{N3}` placeholders; the registry's "first merge wins" mechanic handles races. As of authoring, the highest reservation in the registry is ADR-0079 at 95–98, putting ADR-0080's block at **99–101** — but the load-bearing claim lives in the registry, not in this paragraph.

### Wave 2 (Per-vendor governance stubs + cross-link — depends on Wave 1, parallel)
- [ ] **01** — Architecture: create `governance/vendor-postures/` and ship the Azure stub (`governance/vendor-postures/azure.md`). `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: ship the GitHub stub (`governance/vendor-postures/github.md`). `Actor=Agent`. Blocked by: 00. (Parallel with 01 — different file in the same directory created by 01; sequencing handled inside the wave by directory existence.)
- [ ] **03** — Architecture: cross-link the three Azure-deep ADRs (ADR-0076, ADR-0077, ADR-0078) and their Follow-up Work sections at `governance/vendor-postures/azure.md` (citation-only; no decision change). `Actor=Agent`. Blocked by: 01.

Packets 01 and 02 are file-creation tasks in the same directory. Packet 01 creates the directory and the Azure stub; packet 02 adds the GitHub stub alongside it. To avoid a race on directory creation, **packet 02 declares packet 01 as a dependency** in `dependencies:` — they sequence one after the other, not strictly in parallel, but the two together take less than a single human-review cycle. Packet 03 also depends on packet 01 because its cross-link target is `governance/vendor-postures/azure.md`, which packet 01 creates.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0080](./00-architecture-adr-0080-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [governance/vendor-postures/ + azure.md stub](./01-architecture-governance-vendor-postures-azure-stub.md) | Architecture | Agent | 2 | 00 |
| 02 | [governance/vendor-postures/github.md stub](./02-architecture-governance-vendor-postures-github-stub.md) | Architecture | Agent | 2 | 01 |
| 03 | [Cross-link ADR-0076/0077/0078 to azure.md](./03-architecture-cross-link-azure-deep-adrs.md) | Architecture | Agent | 2 | 01 |

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/docs edits only. No CHANGELOG version bump required by these packets (the repo-level CHANGELOG may receive a dated entry per the repo's existing convention for ADR-acceptance events; match what ADR-0042/0045/0077 acceptance packets did).
- **No other repo touched.** Zero .NET solution version bumps.

## Cross-Cutting Concerns

### Why no catalog packet

This initiative deliberately omits a catalog packet. The new `governance/vendor-postures/` directory is its own canonical home per ADR-0080 D5 — *"The `governance/vendor-postures/` directory is the canonical home for per-vendor posture documentation."* It is not a Node contract; it is governance documentation. `catalogs/contracts.json` registers Node contracts (interfaces, workflows, schemas); `catalogs/grid-health.json` tracks Node readiness state; neither has a slot for governance-document directories. Inventing a slot would be a phantom catalog entry — the same anti-pattern ADR-0045 packet 01 documented for the Notify-Sentry decommission and the phantom observability section. **Skip the catalog packet entirely.**

### Why no code/workflow/test packets

The ADR's Operational Consequences section says it explicitly:

> No today-cost on any active workstream. All hedges in D3 are already true at the code level via the existing invariants and source ADRs. This ADR adds the **posture** layer above the code-level discipline; no code changes are implied by acceptance.

The new invariants (per D3 / Consequences §Invariants) restate existing structural discipline as Grid-wide policy. Invariant 1, 2, 3, and 44 already enforce the abstraction/runtime/provider split for Vault, Transport, AI, Communications, Audit. The new "no vendor-proprietary feature in application code" invariant generalizes those four — but it does not create a new structural rule. Existing application code already complies. There is no canary to add (the existing per-Node contract-shape canaries already cover their respective Abstractions packages); there is no test to write (the abstraction boundary is the test); there is no provider package to split (every Node already has `*.Abstractions` / `*.Providers.*` shape per invariant 3).

The Grid-aware review agent (per ADR-0044) is the structural enforcement point for the new invariant going forward — at PR time, on any code that touches a vendor SDK or proprietary feature. ADR-0080's Operational Consequences explicitly cites this: *"The discipline is enforced through the standard Grid review mechanisms — invariants are checked by canary tests and architecture review; provider-package vs. application-code boundaries are checked by the Grid-aware review agent per ADR-0044; the `.coderabbit.yaml` per ADR-0079 Reviewer 2 can carry vendor-leakage rules over time."*

A *future* packet may add a vendor-leakage rule to `.claude/agents/review.md` when a real vendor-leakage anti-pattern is observed at PR time (per ADR-0080 Follow-up Work watch-list item). That packet is **not** part of this initiative — it is reactive, triggered by an observed event, and would be its own scope under the ADR-0044 governance.

### Why no `governance/vendor-postures/` packet for Hedge or Abstract postures

ADR-0080 D5 is explicit: *"For 'Hedge (active)' and 'Abstract (already portable)' vendors, no separate file is required at this ADR's acceptance. The source ADR is the document of record; the hedge is named in the source ADR; the per-vendor governance file becomes useful only when the surface area grows enough to justify it."*

So this initiative ships **only** the Azure and GitHub stubs — the two Accept-posture vendors. Cloudflare, Stripe, Anthropic, OpenAI, Resend, Twilio, and Expo each have their source ADRs (0029, 0037, 0041, 0073) as the canonical posture record. If a future surface area expansion warrants promoting one of them to its own governance file, that promotion is the subject of a future packet, not this initiative.

### Decision-point triggers — not packets

ADR-0080 D4 names six triggers that cause a posture re-evaluation conversation: deprecation/material price increase, sustained reliability problems (two or more incidents exceeding one hour of impact within a single calendar quarter), terms-change conflicts with charter, mature alternatives, adjacent Grid decisions changing the math, and vendor acquisition / corporate event. **These triggers fire conversations, not migrations** — and the conversations are not scheduled work. The initiative does not pre-create any "watch for trigger X" packet. The Operational Consequences explicit framing — *"The trigger fires the conversation, not the migration"* — applies. When a trigger is observed, the operator opens a re-evaluation conversation; the conversation's outcome is "stay," "hedge harder," or "exit." Only the "exit" outcome produces a follow-up ADR and an associated initiative.

### Coordination with ADR-0076, ADR-0077, ADR-0078

The three Azure-deep ADRs each cite a future "vendor-exit playbook" with no defined home (per ADR-0080's Context and the candidate-surface document). Packet 03 adds **citation-only** updates to their Follow-up Work and References sections — pointing at `governance/vendor-postures/azure.md` as the resolved home. **No decisions in those ADRs change**; the cross-link is wording-only. The packet must not modify any D-decision, invariant, or scope claim in ADR-0076/0077/0078 — only the references-to-future-work text.

ADR-0076 is currently Proposed (its acceptance is in `adr-0076-cache-backing-redis` if scoped). ADR-0077 is currently Proposed (its acceptance is in the sibling `adr-0077-iac-bicep` initiative). ADR-0078 is currently Proposed (no initiative folder yet). Packet 03 edits the cross-link text regardless of each ADR's acceptance state — the text being edited is the **Follow-up Work** / **References** sections, which exist in all three ADRs at draft time. If any of those ADRs has its acceptance packet land while packet 03 is in flight, packet 03 still operates against the current ADR text (the cross-link goes into Follow-up Work, which is preserved on acceptance).

### Site sync

No site-sync flag. ADR-0080 is internal Grid governance; the `governance/vendor-postures/` directory is internal documentation, not a public-facing Studios website surface. No `HoneyDrunk.Studios` packet needed.

### No CHANGELOG impact in any other repo

This initiative is contained entirely in `HoneyDrunk.Architecture`. No `.NET` solution version bump, no per-package CHANGELOG entry in any consuming Node, no NuGet feed impact. The repo-level `HoneyDrunk.Architecture/CHANGELOG.md` (if maintained) may receive a dated entry per the repo's convention for ADR-acceptance events — match what ADR-0042 and ADR-0077 acceptance packets did.

## Rollback Plan

- **Packet 00 (acceptance + invariants):** revert the PR. ADR-0080 returns to Proposed; the three vendor-posture invariants (`{N1}/{N2}/{N3}` — the block claimed in `invariant-reservations.md`) are removed; the reservation row is removed; the initiative entry in `active-initiatives.md` is removed. No runtime impact.
- **Packet 01 (azure.md stub + directory creation):** revert the PR. `governance/vendor-postures/` and `governance/vendor-postures/azure.md` are deleted. No runtime impact; the ADR's Follow-up Work item "Ship stub azure.md" returns to open.
- **Packet 02 (github.md stub):** revert the PR. `governance/vendor-postures/github.md` is deleted; the directory persists if packet 01 has merged. No runtime impact.
- **Packet 03 (cross-link footnotes):** revert the PR. ADR-0076/0077/0078 Follow-up Work / References sections return to their pre-cross-link state, pointing at the candidate-surface document instead of `governance/vendor-postures/azure.md`. No decisions change in those ADRs (the cross-link is wording-only); revert is purely a documentation correction.

The full initiative is governance-only — no rollback affects any deployed code, infrastructure, or runtime behavior.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

No cross-initiative `{Repo}#N` dependencies to substitute — every dependency in this initiative is a `packet:NN` reference, all of which resolve within this folder once filed.
