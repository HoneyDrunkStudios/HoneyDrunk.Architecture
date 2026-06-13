---
name: Accept ADR-0087 — risk-signals catalog, Invariant 53 rewrite, amendment pointers
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["meta", "architecture", "governance", "catalog", "constitution", "tier-3", "adr-0087", "wave-1"]
dependencies: []
adrs: ["ADR-0087", "ADR-0086", "ADR-0044", "ADR-0083", "ADR-0046"]
accepts: ["ADR-0087"]
wave: 1
initiative: adr-0087-per-change-risk-scoring
node: honeydrunk-architecture
---

# Accept ADR-0087 — risk-signals catalog, Invariant 53 rewrite, amendment pointers

## Summary
Accept ADR-0087 (flip DRAFT → Accepted), author the new machine-readable `catalogs/review-risk-signals.json` signal catalog (sensitivity + blast-radius + boundary-spread + size), rewrite Invariant 53 in place to the per-change definition, append amendment pointers to ADR-0044 D8 / ADR-0086 D8, add the ADR README index row, and register the `adr-0087-per-change-risk-scoring` initiative. This is the Phase-1 **foundation** work-item: it defines the catalog schema — including the **path→node-id join key** — that the Actions scorer (packet 02) consumes without guessing. The catalog schema is the highest-risk cross-packet seam; it is nailed down here.

## Context
ADR-0086 D8 and Invariant 53 both depend on a definition of "high risk" that exists today only as a phantom. `review_risk_class` was deferred at ADR-0044 acceptance, is still absent from `catalogs/grid-health.json`, and the live `job-review-request.yml` (HoneyDrunk.Actions, commit 7a3330e) reads it from each repo's `.honeydrunk-review.yaml` defaulting to `normal` — a value nobody populates **and that the local worker never reads**. ADR-0087 replaces that static-per-Node flag with a deterministic per-change weighted-signal scorer. This packet lands the *governance and data* side so the scorer (packet 02) has a catalog to read and the constitution agrees with the ADR. No code or `.NET` projects are touched — Architecture is pure knowledge infrastructure.

Full ADR: `adrs/ADR-0087-per-change-risk-scoring-for-double-review.md` (decision-complete; it pins signal *ordering* only and defers weights/threshold to packet 02).

## Scope
- `adrs/ADR-0087-per-change-risk-scoring-for-double-review.md` — status flip, remove the draft note.
- `catalogs/review-risk-signals.json` — **new file** (the weight-bearing machine surface).
- `constitution/invariants.md` — Invariant 53 rewritten in place (number unchanged).
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md` — append a one-line D8 amendment pointer.
- `adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md` — append a one-line D8 amendment pointer.
- `adrs/README.md` — add the ADR-0087 index row (Accepted).
- `initiatives/active-initiatives.md` — register the initiative.

## Proposed Implementation

### 1. Flip ADR-0087 to Accepted
Change `**Status:** DRAFT (not yet accepted — pending operator review)` to `**Status:** Accepted` and **remove the entire `> Draft note (remove on acceptance).` block**. Keep the body otherwise verbatim — all six previously-open questions are already resolved in it.

### 2. Author `catalogs/review-risk-signals.json`
A new committed catalog, **deliberately NOT a retrofit of `grid-health.json`** (repo-readiness data at the wrong granularity). It is the single weight-bearing, machine-readable surface the scorer reads. ADR-0087 D4 binds:

- It is **derived from and cross-references** — never silently duplicates — three authoritative sources: ADR-0044 D8's enumerated high-risk areas, `catalogs/relationships.json` `exposes.contracts` (blast-radius lookups), and ADR-0083's `infrastructure/reference/sensitive-inventory.md` rows.
- Structure: machine-readable **path-glob** patterns and **symbol/contract** patterns, each with a per-pattern weight contribution, grouped by the **four D2 signals: `sensitivity`, `blast_radius`, `boundary_spread`, `size`** (note: the third signal is **boundary spread**, NOT "complexity" — the prior draft's "complexity" name is wrong and must not appear).
- The **pinned signal ordering** (binding; the one thing the ADR fixes) is `sensitivity ≥ blast-radius > boundary-spread > size`. Concrete numeric weights are owned by packet 02 (the scorer), so this catalog carries the *pattern → which-signal + relative-weight-hint* mapping; the scorer supplies absolute weights and the threshold. Encode weights as relative hints (`high`/`medium`/`low` or an integer) and document in the file header that absolute calibration lives in the scorer per D2/D7.
- **Mark the sensitivity-forced subset explicitly.** Vault secret-resolution paths, credentials paths, and `ISecretStore`-class contracts must carry a machine-readable flag (`"forced": true`) so the scorer and worker can identify the subset that gates **regardless of authorship** (D6, the named subset in the rewritten Invariant 53).

#### 2a. CRITICAL — the path→node-id JOIN KEY (highest-risk cross-packet seam)
The scorer (packet 02) receives `github.repository` as an owner-qualified name (e.g. `HoneyDrunkStudios/HoneyDrunk.Vault`) but must look up blast-radius in `catalogs/relationships.json`, which keys Nodes by an `id` slug (e.g. `honeydrunk-vault`). **This catalog MUST carry the explicit mapping so the scorer never has to guess the transform.** Do not leave the scorer to lowercase-and-dot-strip by convention — encode the join table. Provide a top-level `repo_to_node_id` object mapping every `HoneyDrunk.<Name>` (and its `HoneyDrunkStudios/HoneyDrunk.<Name>` long form) to the exact `relationships.json` node id. Derive the values by reading `relationships.json` `id` fields — every value MUST exist as an `id` in `relationships.json` (an acceptance check). Example rows: `"HoneyDrunk.Vault": "honeydrunk-vault"`, `"HoneyDrunk.Kernel": "honeydrunk-kernel"`, `"HoneyDrunk.Actions": "honeydrunk-actions"`. If `relationships.json` uses a different slug convention than lowercase-hyphenated, the table records the actual slug, not the assumed one — this is the whole point of committing it explicitly.

#### 2b. Schema must be concrete enough that packet 02 consumes it without guessing
Specify, in the file itself, for each signal group: the field that names the match kind (`glob` vs `symbol`), the field that carries the weight hint, the `forced` flag location, and the `source` provenance field. For `blast_radius`, specify that the scorer joins the touched repo to a node id via `repo_to_node_id`, then reads that node's `consumed_by` / `consumed_by_planned` from `relationships.json`, and that the signal only fires when the diff touches that node's `exposes.contracts` symbols or a `*.Abstractions/**` path. Suggested top-level shape (executor may refine field names but MUST keep `forced` machine-detectable, the four-signal grouping stable, and `repo_to_node_id` present):

```json
{
  "$comment": "Per-change review risk signals (ADR-0087 D4). Signal ordering is BINDING: sensitivity >= blast-radius > boundary-spread > size. Absolute numeric weights and the gate threshold live in the scorer (HoneyDrunk.Actions/.github/workflows/job-review-request.yml) per ADR-0087 D2/D7 and are tunable without an ADR amendment. Derived from ADR-0044 D8 areas, catalogs/relationships.json exposes.contracts, and infrastructure/reference/sensitive-inventory.md. Never silently duplicate those sources.",
  "schema_version": 1,
  "repo_to_node_id": {
    "$comment": "JOIN KEY for blast-radius. github.repository (owner/HoneyDrunk.<Name> or short HoneyDrunk.<Name>) -> relationships.json node id. Every value MUST exist as an id in relationships.json.",
    "HoneyDrunk.Kernel": "honeydrunk-kernel",
    "HoneyDrunk.Vault": "honeydrunk-vault",
    "HoneyDrunk.Auth": "honeydrunk-auth",
    "HoneyDrunk.Transport": "honeydrunk-transport",
    "HoneyDrunk.Data": "honeydrunk-data",
    "HoneyDrunk.Actions": "honeydrunk-actions",
    "HoneyDrunk.Architecture": "honeydrunk-architecture"
  },
  "signals": {
    "sensitivity": {
      "ordering_rank": 1,
      "patterns": [
        { "glob": "**/*.Abstractions/**", "weight_hint": "high", "source": "ADR-0044-D8 (Kernel ABI)" },
        { "glob": "**/Vault/**", "weight_hint": "high", "forced": true, "source": "ADR-0044-D8, sensitive-inventory" },
        { "symbol": "ISecretStore", "weight_hint": "high", "forced": true, "source": "ADR-0044-D8 secret-resolution" },
        { "glob": "**/secret-resolution/**", "weight_hint": "high", "forced": true, "source": "ADR-0087-D6 named subset" },
        { "symbol": "credentials", "weight_hint": "high", "forced": true, "source": "ADR-0087-D6 named subset" },
        { "glob": "**/Auth/**token**", "weight_hint": "high", "source": "ADR-0044-D8 token validation / principal resolution" },
        { "glob": "**/Audit/**", "weight_hint": "high", "source": "ADR-0044-D8 append-only boundary" },
        { "glob": "**/Transport/**middleware**", "weight_hint": "medium", "source": "ADR-0087-D2.1 envelope/middleware" },
        { "glob": "**/Data/**migration**", "weight_hint": "medium", "source": "ADR-0087-D2.1 persistence" },
        { "glob": ".honeydrunk-review.yaml", "weight_hint": "high", "source": "ADR-0087-D2.1" },
        { "glob": "**/boundaries.md", "weight_hint": "medium", "source": "ADR-0087-D2.1" },
        { "glob": "constitution/invariants.md", "weight_hint": "high", "source": "ADR-0087-D2.1" },
        { "glob": ".github/workflows/**", "weight_hint": "medium", "source": "ADR-0087-D2.1 privileged-token CI" }
      ],
      "sensitive_inventory_ref": "infrastructure/reference/sensitive-inventory.md"
    },
    "blast_radius": {
      "ordering_rank": 2,
      "source": "catalogs/relationships.json",
      "join": "Map github.repository via repo_to_node_id, then read consumed_by / consumed_by_planned for that node id.",
      "rule": "Fires only when the diff touches that Node's exposes.contracts symbols or a *.Abstractions/** path. Score proportional to consumed_by size (discount consumed_by_planned). Internal/runtime-only changes with no contract surface score 0 here regardless of repo.",
      "discount_planned": true
    },
    "boundary_spread": {
      "ordering_rank": 3,
      "rule": "STRUCTURAL signal from file PATHS only (the cloud Action has file list + per-file add/delete counts, NOT file contents or hunks). Counts distinct top-level path roots crossed (e.g. src/<Package>/, infrastructure/, .github/, catalogs/) and whether the diff touches code-bearing extensions (.cs, .ps1, .psm1, workflow .yml) vs pure docs/config (.md, txt). NOT a line-count proxy. Deeper structural complexity (control-flow, cyclomatic, API-surface deltas) is NOT computable at this tier and is out of scope (ADR-0087 D2.3)."
    },
    "size": {
      "ordering_rank": 4,
      "rule": "Total added+deleted lines and file count. WEAKEST signal by design: size alone never forces double-review; small size never exempts a sensitive change. Coordinates with — does not duplicate — ADR-0044 D7's independent PR-size discipline. Magnitude facet only; boundary_spread reads the structural facet of the same data."
    }
  }
}
```

The exact pattern list above is illustrative — derive the authoritative set by reading the three sources. Do NOT invent sensitive paths not traceable to a source; every entry carries a `source` note.

### 3. Rewrite Invariant 53 in place
In `constitution/invariants.md`, **replace the current Invariant 53 text** (the "high-risk Node ... catalog ... `grid-health.json` ... `review_risk_class`" wording) with the exact wording ADR-0087 fixes (Consequences → Invariants). Keep the number `53`. The new text (verbatim from the corrected ADR — note the signal name is **boundary spread**, not "change complexity"):

> 53. **Agent-authored PRs whose changes are scored high-risk receive two independent LLM-review perspectives before merge.** "High risk" is computed **per change**, on the (PR, head SHA) pair, by the deterministic weighted-signal scorer defined in ADR-0087 (signals: sensitivity of touched area, blast radius, boundary spread, diff size), evaluated against `catalogs/review-risk-signals.json` and `catalogs/relationships.json`. It is **never** a static per-Node or per-repo flag; no `review_risk_class` repo field gates this invariant. A change whose sensitivity signal trips the most sensitive paths (Vault secret-resolution, credentials, `ISecretStore`-class contracts) is forced into the double-review gate **regardless of authorship**. The second perspective is the dual Codex CLI + Claude Code CLI pass on the local worker, synthesized into one verdict (ADR-0086 D8); the human may also invoke `refine` for manual escalation. Enforceable once ADR-0087 Phase 3 lands **and** the ADR-0086 dual-pass worker substrate it depends on is implemented (D8 prerequisite).

This removes the now-dead `grid-health.json:review_risk_class` pointer and supersedes ADR-0044 D8's static-flag language so the two no longer conflict. **Re-verify against the source ADR's Consequences → Invariants block before committing** — if the ADR text and this quote ever diverge, the ADR is authoritative.

### 4. Amendment pointers (do NOT mutate the prior decisions' bodies beyond a one-line append)
- In ADR-0044, at D8: append — "**Amended by ADR-0087 (2026-05-30):** the static `review_risk_class`-per-Node definition is superseded by ADR-0087's per-change weighted-signal scorer; high-risk is computed per (PR, head SHA), not per repo."
- In ADR-0086, at D8: append — "**Amended by ADR-0087 (2026-05-30):** 'high risk' is defined per-change per ADR-0087; double-review scope is extended to human-authored PRs touching Vault secret-resolution / credentials / `ISecretStore`-class contracts (a narrow named exception, not a blanket reversal). The dual-pass execution substrate this ADR's D8 describes remains ADR-0086 deferred/unbuilt work and is a hard prerequisite for ADR-0087 Phase 2/3 (built under initiative packet 03)."

### 5. ADR README row + initiative registration
- Add the ADR-0087 row to `adrs/README.md` with Status `Accepted`, Date `2026-05-30`, Sector `Meta`, and a one-paragraph summary matching the existing row style.
- Register `### ADR-0087 Per-Change Risk Scoring for the Double-Review Gate` under `## In Progress` in `initiatives/active-initiatives.md`, with Scope (Architecture + Actions), Initiative slug, Board link, Description, and a Tracking section mirroring the dispatch plan's **four** packets (01, 02, 03, 04).

## Acceptance Criteria
- [ ] ADR-0087 Status is `Accepted`; the draft note block is removed.
- [ ] `catalogs/review-risk-signals.json` exists, is valid JSON, groups patterns under the four D2 signals named `sensitivity` / `blast_radius` / `boundary_spread` / `size` (no "complexity" anywhere), and encodes the binding ordering rank (`sensitivity` rank 1 ≥ `blast_radius` rank 2 > `boundary_spread` rank 3 > `size` rank 4).
- [ ] The catalog includes a top-level `repo_to_node_id` join table, and **every value in it exists as an `id` in `catalogs/relationships.json`** (verify by cross-reading the file).
- [ ] The `blast_radius` group documents the join (`repo_to_node_id` → `consumed_by`/`consumed_by_planned`) and the "fires only on `exposes.contracts` / `*.Abstractions` touch" rule.
- [ ] The `boundary_spread` group documents the paths-only structural rule and explicitly records that file contents/hunks are unavailable at the cloud-Action tier (it is not a line-count proxy).
- [ ] Every sensitivity pattern carries a `source` note traceable to ADR-0044 D8, `relationships.json`, or `sensitive-inventory.md`.
- [ ] The Vault secret-resolution / credentials / `ISecretStore`-class entries carry the machine-detectable `forced` flag (the sensitivity-forced subset of D6).
- [ ] The catalog header documents that absolute weights + threshold live in the scorer (packet 02) and are tunable without an ADR amendment.
- [ ] Invariant 53 is rewritten in place to the exact ADR wording (signal list: sensitivity, blast radius, **boundary spread**, diff size); the `grid-health.json:review_risk_class` pointer is gone; the number is still 53; no new invariant number is added; the closing clause names BOTH Phase 3 landing AND the ADR-0086 dual-pass substrate prerequisite.
- [ ] One-line amendment pointers appended to ADR-0044 D8 and ADR-0086 D8 (their bodies otherwise unchanged — Invariant-24-style discipline); the ADR-0086 pointer notes the dual-pass substrate is unbuilt/prerequisite.
- [ ] `adrs/README.md` has the ADR-0087 row (Accepted, 2026-05-30, Meta).
- [ ] `initiatives/active-initiatives.md` registers the initiative with a four-packet (01/02/03/04) tracking section.
- [ ] No `.NET` project, `.csproj`, or package version is touched (this is governance/data only).

## Human Prerequisites
None. This is a documentation/catalog PR with no portal, secret, or RBAC actions.

## Dependencies
None — this is the foundation packet. Packet 02 (the Actions scorer) is blocked by this packet because the scorer has nothing to read until `catalogs/review-risk-signals.json` (with the four-signal grouping, the `forced` flag, and the `repo_to_node_id` join table) exists.

## Agent Handoff

**Objective:** Land the governance + data foundation for per-change review risk scoring: accept ADR-0087, ship the signals catalog (with the path→node-id join key), rewrite Invariant 53, append amendment pointers.
**Target:** HoneyDrunk.Architecture, branch from `main`.
**Context:**
- Goal: replace the phantom static `review_risk_class` Node-flag with an enforceable per-change risk definition.
- Feature: deterministic, arithmetic-only weighted-signal scorer; this packet ships its catalog + constitution side.
- ADRs: ADR-0087 (accept here), ADR-0086 D8 (dual-pass substrate is UNBUILT prerequisite, amendment pointer), ADR-0044 D8 (superseded static-flag, amendment pointer), ADR-0083 (sensitive-inventory source), ADR-0046 (Invariant 53 origin).

**PR metadata (required by `pr-core` checks):** the PR body must carry `Authorship: <enum>` (one of `human` / `agent-codex` / `agent-copilot` / `agent-claude-code` / `mixed`) and exactly one of `Work Item: <issue link>` (this packet's filed issue) or `Out-of-band reason: <text>`. Free-form text in place of these breaks the `pr-core` metadata check.

**Acceptance Criteria:** see the checkboxes above — all must be met.

**Dependencies:** None.

**Constraints:**
- **Pin the signal ordering, not the numbers.** ADR-0087 D2 binds `sensitivity ≥ blast-radius > boundary-spread > size`. Numeric weights and the gate threshold are deferred to the scorer (packet 02) so they stay tunable during the pilot without an ADR amendment. Encode relative hints only in this catalog; document that absolute calibration is the scorer's.
- **The third signal is boundary spread, not complexity.** A paths-only structural signal (distinct package/path-root boundaries crossed + code-bearing-extension vs docs/config). Explicitly NOT a line-count proxy. Deeper structural complexity is not computable at the cloud-Action tier (no file contents/hunks) and is out of scope.
- **Commit the path→node-id join table.** The scorer maps `github.repository` (e.g. `HoneyDrunk.Vault`) to a `relationships.json` node id (e.g. `honeydrunk-vault`) for blast-radius. Do not assume a lowercase-dot-strip transform — encode `repo_to_node_id` explicitly, with every value verified to exist as an `id` in `relationships.json`. This cross-packet contract is the highest-risk seam; nail it down here.
- **Do not retrofit `grid-health.json`.** ADR-0087 D4 deliberately commits a *new* dedicated catalog. `relationships.json` is a weightless dependency graph; `sensitive-inventory.md` is human-Markdown that ADR-0083 D2 kept tooling-free. The new catalog is the single weight-bearing machine surface.
- **Derive, never duplicate.** Every sensitivity pattern must be traceable to ADR-0044 D8, `relationships.json` `exposes.contracts`, or a `sensitive-inventory.md` row, and carry a `source` note. Do not invent sensitive paths.
- **Invariant 8 (no secrets in logs):** "Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced." The catalog and scorer read *paths and contract names only*, never secret values; the `sensitive-inventory` cross-reference uses names only. Keep it that way.
- **Invariant 24 (work items immutable once filed) and prior-ADR immutability:** append only a one-line amendment pointer to ADR-0044 D8 and ADR-0086 D8 — do not rewrite their decision bodies. ADR-0086 stays Accepted and immutable; this is amendment-in-part, not supersession.
- **Rewrite Invariant 53 in place — no new invariant number.** Do not allocate a 5x successor. The exact replacement text is quoted above and in the ADR; the ADR is authoritative if they diverge.

**Key Files:**
- `adrs/ADR-0087-per-change-risk-scoring-for-double-review.md`
- `catalogs/review-risk-signals.json` (new)
- `constitution/invariants.md` (Invariant 53)
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md` (D8 pointer)
- `adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md` (D8 pointer)
- `adrs/README.md`
- `initiatives/active-initiatives.md`
- Read-only sources for derivation: `catalogs/relationships.json`, `infrastructure/reference/sensitive-inventory.md`

**Contracts:**
- New machine surface: `catalogs/review-risk-signals.json`. The scorer (packet 02) reads it; the worker (packet 03) reads the scorer's queue-comment output, not this file. Field names you choose here are a contract packet 02 must match — keep `forced` machine-detectable, keep the four-signal grouping (`sensitivity`/`blast_radius`/`boundary_spread`/`size`) stable, and keep `repo_to_node_id` present and accurate against `relationships.json`.
