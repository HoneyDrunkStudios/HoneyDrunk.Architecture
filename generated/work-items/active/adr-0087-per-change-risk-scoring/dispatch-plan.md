# Dispatch Plan — ADR-0087 Per-Change Risk Scoring for the Double-Review Gate

**Initiative:** `adr-0087-per-change-risk-scoring`
**Source ADR:** `adrs/ADR-0087-per-change-risk-scoring-for-double-review.md` (corrected 2026-05-30)
**Scope:** multi-repo (HoneyDrunk.Architecture + HoneyDrunk.Actions)
**Status:** re-scoped after the ADR correction. Supersedes the prior 3-packet plan.

> **Living document (ADR-0008 D7).** This dispatch plan is the one mutable artifact in the
> initiative; it is updated at wave boundaries as a historical record. The packets themselves
> are immutable once filed (invariant 24).

## Summary
ADR-0087 replaces the phantom static-per-Node `review_risk_class` flag with a deterministic,
per-change weighted-signal risk scorer that flips a PR into the double-review path. The four
signals are **sensitivity ≥ blast-radius > boundary-spread > size** (ordering binding; numbers
tunable in the scorer). The initiative ships in four packets across three waves:

- **01 (Architecture, foundation):** accept the ADR, author `catalogs/review-risk-signals.json`
  (incl. the `repo_to_node_id` join key — the highest-risk cross-packet seam), rewrite Invariant 53.
- **02 (Actions, the scorer):** deterministic scorer in `job-review-request.yml`, emitting
  `risk_score`/`double_review_required`/`gate_mode`/`risk_rationale` from day one. Shadow posture.
- **03 (Architecture, the worker substrate):** build the ADR-0086-D8-deferred dual-pass execution
  + synthesis + contrarian fallback in `grid-agent-runner`. The hard prerequisite for enforcement.
- **04 (Architecture, enforce):** worker reads `double_review_required`/`gate_mode`, fires the
  packet-03 dual-pass when authoritative, flips Invariant 53 to enforceable.

## What changed vs the prior (stale) plan
1. **`review_risk_class` transition/retirement is GONE.** The worker never read that field
   (`grid-agent-runner/lib/Queue.psm1` parses only `head_sha`/`claimed_at`). The scorer emits the
   new explicit fields from day one; there is no interim computed value and nothing to retire.
   Removed from packets 02 and 04; the old "retire review_risk_class" step in packet 04 is deleted.
2. **The dual-pass substrate is UNBUILT and is now its own packet (03).** ADR-0086 D8's dual
   Codex/Claude second pass + synthesis (`Join-ReviewFindings`, currently dead code) +
   contrarian fallback does not exist (`Queue.psm1` is a flat single-pass `foreach`). Enforcement
   cannot work until it is built. Promoted to a named hard prerequisite.
3. **"complexity" → "boundary spread."** A paths-only structural signal; explicitly not a
   line-count proxy. Catalog field and Invariant 53 wording renamed.
4. **Scorer mechanics tightened in packet 02:** raw-fetch from Architecture@main is THE catalog
   mechanism (workflow does not check out Architecture), with fail-open-to-shadow + logged;
   `risk-gate-mode` read from `.honeydrunk-review.yaml` (not a workflow_call input — the pinned
   caller can't pass one); per-signal weight caps + a worked arithmetic example; a fixture-based
   unit test; a `gate_mode:` shadow marker.
5. **Packet 04 now asserts `gate_mode`:** the worker refuses to act on a `double_review_required`
   that carries `gate_mode: shadow`, and asserts the pilot is `gate` before authoritative action.

## Trigger
ADR-0087 corrected and ready for acceptance. Packet 01 accepts it.

## Wave Diagram

```
### Wave 1 (No Dependencies)
- [ ] 01 HoneyDrunk.Architecture: accept ADR-0087 + review-risk-signals.json (with repo_to_node_id) + Invariant 53 rewrite
- [ ] 03 HoneyDrunk.Architecture: build worker dual-pass substrate (second pass + Join-ReviewFindings synthesis + contrarian fallback)

### Wave 2 (Depends on Wave 1)
- [ ] 02 HoneyDrunk.Actions: deterministic risk scorer in job-review-request.yml (shadow posture)
  - Blocked by: 01 (the catalog it reads)

### Wave 3 (Depends on Wave 2 AND the Wave-1 substrate; gated on human Phase-2 go/no-go)
- [ ] 04 HoneyDrunk.Architecture: worker reads double_review_required/gate_mode, fires the dual-pass, flips Invariant 53 enforceable
  - Blocked by: 02 (the fields it reads) AND 03 (the substrate it fires)
  - Human gate: ADR-0087 D7 Phase-2 pilot go/no-go (operator sets pilot .honeydrunk-review.yaml risk-gate-mode: gate, observes firing rate)
```

Wave 1's two packets (01, 03) run in **parallel** — 03 touches no catalog and no scorer, only the
worker. 02 needs 01's catalog. 04 needs both 02 and 03 plus the human go/no-go.

## Blocking graph (as encoded in packet frontmatter `dependencies:`)
```
01  dependencies: []
03 dependencies: []                       (parallel to 01; relates to ADR-0086 follow-up)
02  dependencies: ["work-item:01"]
04  dependencies: ["work-item:02", "work-item:03"]   (+ human Phase-2 go/no-go, recorded at this boundary)
```
The filing pipeline (`HoneyDrunk.Actions/scripts/file-work-items.sh`) resolves `work-item:NN` against the
filed-work-items manifest and wires `addBlockedBy` edges automatically on push to `main`.

## One-PR-per-repo analysis (three Architecture packets: 01, 03, 04)
Oleg's convention is **one PR per repo per initiative**, satisfied here by **wave sequencing** — the
three Architecture packets land as three separate PRs at three different times, not concurrently:
- **01** lands in Wave 1 (foundation: ADR + catalog + Invariant 53). Its own PR.
- **03** lands in Wave 1 too, but is a **disjoint change set** (the worker `grid-agent-runner/`
  PowerShell substrate — no overlap with 01's `adrs/`/`catalogs/`/`constitution/` files). It can be a
  separate concurrent PR without conflict because the file sets do not intersect. If the operator
  prefers strict one-open-PR-per-repo, land 01 first, then 03 — they are independent so either order
  works; there is no code dependency between them.
- **04** lands in Wave 3, well after 01 and 03 merge (it depends on 03's substrate and 02's fields,
  and on the human Phase-2 go/no-go). Its own PR, at a different time.
**Conclusion:** no violation. The three Architecture PRs are temporally separated by wave boundaries
and (01 vs 03) by disjoint file sets. 02 is the only Actions packet — trivially one PR for that repo.

## Drift cross-check follow-up (ADR-0087 Follow-up Work)
ADR-0087 D4 calls for a `hive-sync` / `node-audit` cross-check that flags drift between
`catalogs/review-risk-signals.json` and its source documents (ADR-0044 D8 areas,
`relationships.json` `exposes.contracts`, `sensitive-inventory.md`). **This is NOT silently
dropped.** It is tracked as an explicit follow-up item here (not yet a packet) because the audit
tooling it extends lives outside this initiative's critical path and the catalog must exist and
stabilize first (packet 01). **Action:** after packet 01 merges, file a standalone follow-up packet
against HoneyDrunk.Architecture to add the `review-risk-signals.json` drift check to the existing
`hive-sync`/`node-audit` machinery (also verify the `repo_to_node_id` values still all resolve to
live `relationships.json` ids). Owner: Oleg. This boundary note is the tracking record.

## Site sync
No website update triggered. This is review-process architecture (catalogs, constitution, worker,
CI). No public Node contract or docs-site surface changes. **site-sync: not required.**

## Rollback plan
- **01:** revert the PR — removes `review-risk-signals.json`, restores prior Invariant 53, reverts
  ADR to DRAFT. No runtime impact (governance/data only).
- **02:** revert the PR — removes the scorer step + `risk-high` label. The queue comment loses the
  risk fields; the worker (pre-04) never read them anyway, so no behavior regression. Shadow posture
  means nothing was acting on the output.
- **03:** revert the PR — the worker returns to single-pass. Default single-pass behavior was
  preserved throughout (the dual-pass was behind a flag never wired until 04), so reverting before 04
  is a no-op for live behavior; reverting after 04 disables enforcement (revert 04 first).
- **04:** revert the PR — the worker stops reading `double_review_required`/`gate_mode` and returns to
  single-pass; Invariant 53 returns to the not-yet-enforceable caveat. The scorer keeps recording in
  shadow. Clean rollback to Phase-1 posture.

## Filing
Filing is automated: pushing these packets to `main` triggers `file-work-items.yml` in
HoneyDrunk.Architecture, which creates the issues, adds them to The Hive (project #4), sets
Status/Wave/Node/Tier/Actor/Initiative/ADR fields from frontmatter, and wires `addBlockedBy` from
the `dependencies:` arrays. Do not run `gh issue create` / `addBlockedBy` by hand. Verify the wave
landed by checking The Hive for the four items + their blocked-by chains.

## Wave boundary notes (appended as waves complete)
- _Wave 1 → 2:_ (pending) confirm 01 merged and `review-risk-signals.json` (incl. `repo_to_node_id`)
  is on `main` before 02 starts.
- _Wave 2 → 3:_ (pending) confirm 02 merged AND 03 merged AND deployed to the home-server worker,
  AND record the human Phase-2 go/no-go decision (pilot `.honeydrunk-review.yaml` set to
  `risk-gate-mode: gate`, firing rate acceptable) before 04 starts.
