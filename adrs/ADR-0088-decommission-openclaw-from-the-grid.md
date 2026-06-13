# ADR-0088: Decommission OpenClaw from the HoneyDrunk Grid

**Status:** Accepted
**Date:** 2026-05-30
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / Ops

## Context

OpenClaw was onboarded as the Grid's local-automation substrate across two decisions:

- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) (Accepted) made OpenClaw/Codex the subscription-backed execution runtime for the Grid Review Runner (D5) behind a signed GitHub→OpenClaw webhook (D1).
- [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) (then Proposed; now superseded by this ADR) generalized the premise: it named a small always-on **home server** as the preferred host for OpenClaw Gateway and the Honeyclaw runtime, the ADR-0044 webhook bridge, the Cloudflare Tunnel that exposes that bridge, scheduled local automations, and local-agent experimentation. ADR-0081 was the **broad** onboarding — it made OpenClaw the host for essentially all local automation.

Two things have changed since.

**First, the review transport already moved off OpenClaw.** [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) (Accepted) replaced the signed-webhook→OpenClaw review transport with a pull-based local worker (`infrastructure/workers/grid-agent-runner/`): a cheap GitHub Action enqueues review requests as a label (`needs-agent-review`) plus a structured queue comment, and a local PowerShell worker polls GitHub, claims one PR at a time, and runs `.claude/agents/review.md` under subscription-backed Codex CLI / Claude Code CLI. ADR-0086 D1–D4 explicitly removed the inbound webhook, the Cloudflare Tunnel **for review traffic**, and OpenClaw from the review path. ADR-0086 already appended supersession notes to ADR-0044 (D1/D5) and ADR-0079 (D1/D2). **This ADR does not re-supersede those decisions** — it completes the teardown ADR-0086 began and crosses-references it as the replacement substrate.

**Second, the runner grew past reviews.** ADR-0086 D4 deliberately built a **portable scheduled-agent runner framework**, not a one-off review script. Its committed job specs already cover every workload OpenClaw was reserved for in ADR-0081's Implementation Notes:

| OpenClaw / Honeyclaw workload (ADR-0081) | Replacement on the ADR-0086 runner |
|---|---|
| Grid Review Runner (PR review) | `grid-review` job spec |
| Post-merge sampling audit (ADR-0044 D9) | `post-merge-audit` job spec |
| `hive-sync` Architecture↔Hive reconciliation (ADR-0014) | `hive-sync` job spec |
| Lore sourcing | `lore-source` job spec |
| Lore ingest / compile | `lore-ingest` job spec |
| Lore signal review | `lore-signal-review` job spec |
| Scheduled jobs needing local repo/filesystem context | Task Scheduler job specs on the same runner |

OpenClaw as a substrate is therefore **fully replaced**. What was missing was a single governing decision that retires it cleanly: ADR-0081 described OpenClaw as the local-automation host, the broad OpenClaw premise had no decommission owner, and the concrete teardown — the org secret, the webhook bridge, the Cloudflare Tunnel pieces, the `infrastructure/openclaw/*` reference files, the inventory row, the standing rotation issue, and the OpenClaw references scattered across ADR-0044 / 0079 / 0082 — had no single sequenced home. This ADR is that decision.

### What was verified (footprint, as of 2026-05-30)

The operator decision to retire OpenClaw is **already made**; this section records the precise footprint so the teardown packets touch exactly what exists and nothing more.

**Secrets — what actually exists in the store:**

- `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` — org Actions secret, **exists** (last updated 2026-05-24, access policy `All repositories`). The ADR-0044 D2 HMAC webhook-signing secret. Inventory expiration `2026-08-28`. This is the one OpenClaw-bound credential that exists.
- **OpenClaw GitHub App private key — does NOT exist as a distinct secret.** ADR-0083's footprint prose ("the OpenClaw GitHub App private key") anticipated a credential that was never separately provisioned. The org's installed GitHub Apps are `chatgpt-codex-connector`, `vercel`, `graphite-app`, `honeydrunk-hive`, `claude`, `honeydrunk-grid-review` (app_id 3841539), `sonarqubecloud`, `coderabbitai`. **There is no OpenClaw App.** The `honeydrunk-grid-review` App is the ADR-0044 review-agent identity that **ADR-0086 D4 reuses as the pull-based worker's identity** — it is load-bearing for the *replacement* substrate and is explicitly **retained**, not decommissioned. The teardown deletes no GitHub App and no App private key, because none is OpenClaw's.

**Files under `infrastructure/openclaw/`:**

- `infrastructure/openclaw/grid-review-runner.md` — the superseded OpenClaw/Codex webhook-receiver review runtime contract (ADR-0044 packet 02b). Replaced by `infrastructure/workers/grid-agent-runner/`.
- `infrastructure/openclaw/hive-sync.md` — the OpenClaw/Honeyclaw `hive-sync` runtime contract (Monday/Thursday 06:00 UTC `agentTurn`). Replaced by the `hive-sync` runner job spec.

**Inventory + rotation discipline (ADR-0083 / invariant 103):**

- `infrastructure/reference/sensitive-inventory.md` — the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row (already annotated "Retire this row at OpenClaw decommission cutover").
- `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md` — the rotation walkthrough for that secret (already notes "If the webhook bridge is fully decommissioned, retire this secret and its inventory row instead of rotating").
- GitHub issue **#527** — `[Rotate] OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET — expires 2026-08-28`, open, labeled `external-credential-rotation`. The standing rotation issue this teardown closes.

**Node-standup binding matrix:**

- `constitution/node-standup.md` — the per-class org-secret matrix carries an `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row ("Any Node whose `.honeydrunk-review.yaml` has `enabled: true` and posts review results upstream"). This row is obsolete under ADR-0086 (the worker pulls; nothing posts review results upstream through a webhook secret).
- Invariant 102's text and ADR-0082's index row both name `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` in their conditional-secret enumerations.

**Cross-repo (HoneyDrunk.Actions):**

- `.github/workflows/job-review-request.yml` — already rewritten by ADR-0086 to the label-and-comment enqueue form. ADR-0088 packet 06 removes the deprecated `openclaw-webhook-url` / `openclaw-webhook-secret` / fallback compatibility inputs from the reusable workflow; the org secret itself remains a human deletion gate.
- `HoneyDrunk.Architecture/.github/workflows/grid-review-request.yml` — the consumer caller. No live OpenClaw dependency (it queues via labels/comments).

**ADRs referencing OpenClaw:** 0007 (skills mirroring addendum), 0011, 0028, 0043 (execution-surface deferral), 0044, 0064, 0068, 0079, 0080 (vendor posture), 0081, 0082, 0083, 0084, 0085, 0086. Of these, 0044 / 0079 are **already** "superseded in part by ADR-0086" and are NOT re-touched here; 0081 is superseded by this ADR; 0082 / 0083 / 0084 / 0085 carry OpenClaw references that this ADR's follow-ups reconcile (matrix row, footprint prose, skills-mirroring note).

## Decision

HoneyDrunk **fully retires OpenClaw** as a Grid substrate. The pull-based local worker framework from ADR-0086 is the canonical and only home for scheduled/triggered agent work (PR review, post-merge audit, hive-sync, Lore sourcing/ingest/compile, Lore signal review, and future scheduled jobs). OpenClaw Gateway, the Honeyclaw runtime, the ADR-0044 webhook bridge, and the OpenClaw-bound Cloudflare Tunnel are decommissioned. No OpenClaw workload remains after this ADR's teardown sequence completes.

This decision has six bound sub-decisions.

### D1 — Supersede ADR-0081 in full

[ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) ("Home Server for OpenClaw and Local Agent Infrastructure") is **superseded by this ADR.** ADR-0081's broad premise — *OpenClaw is the host for all local automation, and the home server exists to host OpenClaw* — no longer holds. ADR-0086 already removed OpenClaw from the review path and built the portable runner; this ADR removes OpenClaw entirely.

**What survives ADR-0081's supersession, re-homed under ADR-0086:** the home-server *hardware and security premise* is still valid and is **not** retired. The always-on mini-PC, the no-router-port-forwarding posture, the least-privilege/recoverable security checklist, and the local-agent-sandbox idea are all preserved — but their document-of-record becomes ADR-0086 (which already names the home server as the runner host in D4) rather than ADR-0081. ADR-0081 is superseded because its *organizing premise* (OpenClaw-centric) is dead, not because the home server is. The teardown does not decommission the home server; it decommissions OpenClaw running on it.

ADR-0081 is moved to `Status: Superseded by ADR-0088` in the same pass that records this ADR's acceptance, and its row is updated in `adrs/README.md` and removed from `initiatives/proposed-adrs.md`'s "Awaiting Implementing Packets" queue.

### D2 — Cross-reference ADR-0086 as the replacement substrate; do not re-supersede ADR-0044 / ADR-0079

The review-transport teardown is **already governed** by [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md). ADR-0044 D1/D5 and ADR-0079 D1/D2 are already marked "superseded in part by ADR-0086." This ADR:

- **Does not re-supersede** ADR-0044 D1/D5 or ADR-0079 D1/D2. Re-superseding already-superseded decisions would muddy the supersession graph.
- **Cross-references** ADR-0086 as the canonical replacement and **completes** the physical teardown ADR-0086 D10 / Follow-up Work named but did not perform (the webhook bridge, the Cloudflare Tunnel hostname, the secret rotation-out, the `infrastructure/openclaw/*` files). ADR-0086 deliberately left those for "a dedicated OpenClaw-decommission ADR" — that ADR is this one.

The split of authority is: **ADR-0086 owns the substrate replacement; ADR-0088 owns the OpenClaw teardown and the ADR-0081 supersession.**

### D3 — Teardown sequence (ordered, with the invariant-103 gate)

The teardown runs as an ordered sequence. Steps are grouped; within a group, order is not load-bearing, but the groups run top-to-bottom. The **invariant-103 constraint is hard**: the inventory row, the rotation walkthrough's standing-issue obligation, and issue #527 retire **only when the org secret is actually deleted** — not before. Until the secret is deleted, invariant 103 requires the row to remain (the inventory must reflect what the Grid actually holds).

**Group 1 — Confirm the replacement is load-bearing (prerequisite gate).**

1. Confirm the ADR-0086 runner is operating: `grid-review` and `hive-sync` (at minimum) have run successfully under the local worker, and the Lore job specs are installed and smoke-tested per ADR-0086 D10/D11 Phase C. This ADR's teardown does not start until ADR-0086's Phase C scheduled-job migration is green for the jobs being moved off OpenClaw. **No OpenClaw workload is torn down before its ADR-0086 replacement is proven.**

**Group 2 — Remove OpenClaw runtime and transport (no secret deletion yet).**

2. Disable and remove OpenClaw Gateway and the Honeyclaw runtime on the home server (and on the workstation if still present). Stop all OpenClaw scheduled jobs / cron / `agentTurn` schedules.
3. Remove the ADR-0044 webhook bridge process and its receiver config on the home server.
4. Remove the **OpenClaw-bound Cloudflare Tunnel** pieces — the `grid-review.honeydrunkstudios.com` (or equivalent) hostname and the tunnel route that forwarded to the webhook bridge. Tunnels and routes for any other workload are **unaffected** (ADR-0086 D10 scoping preserved).
5. Remove the `infrastructure/openclaw/` reference files: `grid-review-runner.md` and `hive-sync.md`. Both describe a runtime that no longer exists; their successors are `infrastructure/workers/grid-agent-runner/` and the runner job specs. A one-line tombstone pointer may be left in `infrastructure/workers/grid-agent-runner/README.md` (which already references `infrastructure/openclaw/grid-review-runner.md` as the superseded contract — that pointer is updated, not orphaned).

**Group 3 — Delete the secret, then (and only then) retire the inventory triplet.**

6. **Delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret** at `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`. This is the single OpenClaw-bound credential that exists. No GitHub App or App private key is deleted (none is OpenClaw's — see Context: the `honeydrunk-grid-review` App is the *retained* ADR-0086 worker identity).
7. **Only after step 6 succeeds:** remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from `infrastructure/reference/sensitive-inventory.md`.
8. **Only after step 6 succeeds:** remove (or tombstone) `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md`. The walkthrough already anticipates this path ("If the webhook bridge is fully decommissioned, retire this secret and its inventory row instead of rotating").
9. **Only after step 6 succeeds:** close GitHub issue **#527** with a comment recording the decommission (not a rotation), referencing this ADR. **Do not open a successor standing issue** — there is no longer a credential to rotate.

The invariant-103 ordering is not a nicety: if steps 7–9 ran before step 6, the inventory would claim the Grid holds nothing while the secret still existed in GitHub — a false inventory, which is exactly the failure mode invariant 103 exists to prevent. The drift-detection workflow (`external-credentials-check.yml`) reads the inventory as truth; deleting the row while the secret lives would blind the watcher to a live credential.

**Group 4 — Reconcile governance references.**

10. Remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from the `constitution/node-standup.md` per-class org-secret binding matrix (D8 matrix). It is obsolete: nothing posts review results upstream through a webhook secret under ADR-0086.
11. Reconcile the OpenClaw references in **ADR-0082** (invariant 102 enumeration and the README index row) and **ADR-0083** (footprint prose naming "the OpenClaw GitHub App private key" and the webhook secret) so they no longer imply a live OpenClaw secret surface. These are text reconciliations of accepted ADRs, performed as documentation-currency edits (the standing convention for keeping accepted-ADR prose honest), not re-supersessions.
12. Remove the vestigial deprecated `openclaw-webhook-url` / `openclaw-webhook-secret` / fallback inputs from `HoneyDrunk.Actions/.github/workflows/job-review-request.yml` once no caller references them. The workflow cleanup may land before the org secret is deleted because the inputs are already ignored; actual deletion of `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` remains the human gate for inventory retirement.

### D4 — Access-policy note surfaced during teardown

`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` currently carries the `All repositories` access policy, which contradicts `constitution/node-standup.md`'s "Standing access-policy" rule (`Selected repositories` is the Grid default for org secrets containing live credentials; `All repositories` is reserved for benign org constants). Because the secret is being **deleted** outright by D3 step 6, no remediation of the access policy is needed — deletion resolves the drift. The teardown packet records this so the deletion is understood as also closing an access-policy anomaly, not introducing one. No other secret's access policy is changed by this ADR.

### D5 — Rollback / abort considerations

The teardown is reversible up to a clearly-marked point of no return.

- **Up to and including Group 2 (runtime + transport removal):** fully reversible. OpenClaw can be reinstalled, the bridge restarted, and the tunnel hostname re-created. The org secret still exists, so signature verification would resume. Abort cost: re-standing the OpenClaw runtime.
- **Group 3 step 6 (secret deletion) is the point of no return for *this* credential.** Once deleted, the prior HMAC value is gone (invariant 8: the inventory never held the value). Rolling back means **minting a new secret** and re-creating both ends (a fresh rotation per `openclaw-webhook-secret-rotation.md` against a new value), not "undeleting." This is acceptable because the webhook bridge it signed is already torn down in Group 2 and the review transport has been the pull-based worker since ADR-0086.
- **Abort gate:** if Group 1's prerequisite is not green — if any OpenClaw workload's ADR-0086 replacement is not yet proven — **the teardown halts before Group 2.** OpenClaw keeps running for that workload until its replacement job spec has a smoke-test record and rollback note (the same per-job discipline ADR-0086 D10 mandates). This ADR commits the *intent* to retire OpenClaw fully; it does not authorize tearing down a workload whose replacement is unproven.
- **Inventory safety under abort:** because the inventory row (D3 step 7) is gated behind the secret deletion (step 6), an abort at any earlier point leaves invariant 103 satisfied automatically — the row still describes a secret that still exists. There is no intermediate state where the inventory lies.

### D6 — No new invariants

This ADR adds no invariants and reserves no invariant numbers. It removes a row from the node-standup matrix and reconciles existing-ADR prose, but it does not edit `constitution/invariants.md`. Invariant 102's enumeration of conditional org secrets is a non-normative example list; dropping `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` from it (D3 step 11) is a documentation-currency edit reconciled via the standing convention, not an invariant change. Invariant 103 is the binding constraint *on the teardown ordering* (D3 Group 3), not a target of change.

## Consequences

### Affected Nodes / surfaces

- **HoneyDrunk.Architecture** — removes `infrastructure/openclaw/grid-review-runner.md` and `infrastructure/openclaw/hive-sync.md`; removes the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` inventory row and rotation walkthrough (gated on secret deletion); supersedes ADR-0081; reconciles ADR-0082 / ADR-0083 OpenClaw prose; updates the `constitution/node-standup.md` matrix; updates `adrs/README.md` and `initiatives/proposed-adrs.md`.
- **HoneyDrunk.Actions** — removes the vestigial deprecated `openclaw-*` inputs/secret from `job-review-request.yml` (D3 step 12), sequenced after secret deletion.
- **GitHub org (`HoneyDrunkStudios`)** — deletes the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org secret; closes issue #527. **Retains** the `honeydrunk-grid-review` GitHub App (the ADR-0086 worker identity) and all other Apps.
- **Home server (per ADR-0086 D4, formerly ADR-0081)** — OpenClaw Gateway / Honeyclaw runtime / webhook bridge / OpenClaw-bound tunnel removed. The runner framework (`grid-agent-runner`) remains the active local-automation host. The machine itself is retained.
- **HoneyDrunk.Lore** — no change to prompt files; their scheduler moved to the runner under ADR-0086 (this ADR confirms the OpenClaw schedules are disabled once the runner jobs are proven).
- **`constitution/invariants.md`** — **no change.** Invariant 103 governs the teardown ordering but its text is untouched.

### Cascade impact (per `catalogs/relationships.json` reasoning)

OpenClaw is **operator-internal automation infrastructure, not a Node** (per `constitution/node-standup.md`'s carve-out — OpenClaw schedules and the home server are explicitly "NOT a Node"). It has no `catalogs/nodes.json` row, no `relationships.json` edges, and no `grid-health.json` entry. There is therefore **no Node-graph cascade** — no consumes/consumed_by edge is broken, no downstream Node loses a dependency. The cascade is entirely in governance documents (ADRs, the inventory, the node-standup matrix, the Actions workflow) and operator infrastructure, which is why the teardown is a documentation-and-ops sequence rather than a contract migration.

### Positive

- One substrate to maintain (the ADR-0086 runner), not two. One scheduler story, one recovery story, one auth model.
- The OpenClaw attack surface (inbound webhook receiver, public tunnel termination, a long-running gateway process) is removed entirely. The review path's trust boundary collapsed to GitHub auth + local filesystem under ADR-0086; this ADR finishes the job for the non-review workloads.
- The sensitive inventory shrinks by one rotating credential, and a standing rotation obligation (#527) is permanently closed rather than perpetually rotated.
- The supersession graph is cleaned: ADR-0081's stale Proposed premise is resolved instead of lingering.

### Negative / risks

- Loss of OpenClaw-specific capabilities not covered by the runner job specs (e.g. interactive Honeyclaw sessions, OpenClaw dashboard observability) — accepted: the operator decision is to retire these, and the runner covers the scheduled/triggered workloads that mattered.
- The secret deletion is a one-way door for that HMAC value (D5). Mitigated by the bridge already being torn down before deletion.
- If any ADR-0086 replacement job is less mature than believed, tearing down its OpenClaw counterpart prematurely creates a coverage gap. Mitigated by D5's abort gate (Group 1 prerequisite).

### Neutral / follow-up

- The home-server hardware/security premise survives under ADR-0086; a future ADR may formalize a broader local-infrastructure backup/DR policy if the runner becomes mission-critical (this was ADR-0081's deferred follow-up; it carries forward).
- Future scheduled agent jobs land as new runner job specs, never as new OpenClaw schedules.

## Follow-up Execution Packets

This ADR is the decision record. The teardown work is **scoped and committed** under `generated/work-items/completed/adr-0088-openclaw-decommission/` (dispatch-plan + 9 packets across Waves 0–4), produced via `adr-composer → scope → refine → re-scope` and ordered to honor D3's groups and the invariant-103 gate.

- **`00a`** *(Wave 0, Architecture, agent)* — author + smoke-test a `docs-sync` job spec at `infrastructure/workers/grid-agent-runner/config/jobs/` so docs-sync keeps automated (Friday) scheduling on the ADR-0086 local worker before its OpenClaw schedule is stopped. The one OpenClaw-hosted workload that lacked a local-worker home; gates packet 02. (Operator chose this over dropping docs-sync to its manual-dispatch floor.)
- **`00`** *(Wave 1, Architecture, agent)* — flip ADR-0088 to Accepted; flip ADR-0081 to `Superseded by ADR-0088`; update `adrs/README.md` + remove ADR-0081 from `initiatives/proposed-adrs.md`; register the initiative. Records the concrete Group-1 prerequisite gate (Part A review-path already green on `main`; Part B = the scheduled-job smoke records incl. 00a). No teardown side effects.
- **`01`** *(Wave 2, Architecture, agent)* — remove `infrastructure/openclaw/grid-review-runner.md` + `hive-sync.md`; fix the `grid-agent-runner/README.md` predecessor pointers. (Group 2 step 5.)
- **`02`** *(Wave 2, Architecture ops, **human**)* — remove OpenClaw Gateway / Honeyclaw / webhook bridge / OpenClaw-bound Cloudflare Tunnel hostname on the home server; **mandatorily** reconcile `infrastructure/reference/owned-domains.md`. Gated on `00a`. (Group 2 steps 2–4.)
- **`03`** *(Wave 3, Architecture org-admin, **human**)* — delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org secret; close issue #527 (decommission, no successor). Point of no return; **hard prerequisite for packet 04.** (Group 3 step 6 + step 9.)
- **`04`** *(Wave 3, Architecture, agent)* — **gated on packet 03 confirming deletion** (invariant 103): remove the inventory row; remove `openclaw-webhook-secret-rotation.md`; remove the matrix row from `constitution/node-standup.md`. (Group 3 steps 7–8 + Group 4 step 10.)
- **`05`** *(Wave 4, Architecture, agent)* — reconcile OpenClaw references in ADR-0082 / ADR-0083 / **ADR-0084** / **ADR-0085** (incl. re-pointing docs-sync's execution surface onto the worker) as documentation-currency edits. (Group 4 step 11.)
- **`06`** *(Wave 4, Actions, agent)* — in `HoneyDrunk.Actions`, remove the deprecated `openclaw-*` inputs from `job-review-request.yml` (the 13 callers already migrated off them on `main`). Sequenced after packet 03. (Group 4 step 12.)
- **`07`** *(Wave 4, Architecture, agent)* — retire the **ADR-0007 "OpenClaw Skills" Operational Addendum** companion-skill rule + its `node-standup.md` step-15 clause + the `copilot/agent-skills-map.md` entry. Gated on packets 01 + 02. (Surfaced in refinement; not in the original 7.)

**Gating:** `00a → {02, 05}`, `00 → {01, 02}`, `02 → 03`, `03 → {04, 05, 06}`, `{01, 02} → 07`. One PR per repo per the standing convention: the Architecture packets land in `HoneyDrunk.Architecture`, packet 06 in `HoneyDrunk.Actions`; packets 02 and 03 are operator/human chores. Packet 04 must not file or merge until packet 03 confirms the secret is gone.

## Alternatives Considered

### Leave ADR-0081 Proposed and let it lapse

Rejected. A Proposed ADR with a dead organizing premise is exactly the supersession-graph rot the Grid's ADR discipline exists to prevent. ADR-0086 already references ADR-0081 as the runner host and flagged "ADR-0081 is still Proposed" as a reason it could not edit it. Leaving ADR-0081 in limbo means future readers cannot tell whether OpenClaw is current. An explicit supersession is the honest record.

### Fold the OpenClaw teardown into ADR-0086

Rejected, and ADR-0086 itself rejected it: ADR-0086 D10 and its Follow-up Work explicitly deferred "a dedicated OpenClaw-decommission ADR is being authored to supersede ADR-0081 and own deletion of the secret + bridge." ADR-0086's scope was the *substrate replacement*; bundling the ADR-0081 supersession and the physical secret/bridge/tunnel teardown into an already-Accepted ADR would have either bloated it or required amending an Accepted decision. A separate decision record is cleaner and is what ADR-0086 anticipated.

### Re-supersede ADR-0044 D1/D5 and ADR-0079 D1/D2 here

Rejected. Those decisions are already "superseded in part by ADR-0086." Re-superseding them would create two superseding ADRs for the same sub-decisions and confuse the graph. This ADR cross-references ADR-0086 and completes the physical teardown instead.

### Delete the inventory row and close #527 up front, before deleting the secret

Rejected — it violates invariant 103. The inventory must reflect what the Grid actually holds; removing the row while the secret still exists in GitHub would make the inventory lie and would blind `external-credentials-check.yml` to a live credential. The row, walkthrough obligation, and standing issue retire **only after** the secret is deleted (D3 Group 3 ordering).

### Decommission the home server too

Rejected. The home server's hardware and security premise is sound and is the host for the ADR-0086 runner. OpenClaw ran *on* the home server; retiring OpenClaw does not retire the machine. The home-server premise is re-homed under ADR-0086, not deleted.

## References

- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — Grid-aware cloud code review; D1/D5 already superseded in part by ADR-0086 (cross-referenced, not re-superseded)
- [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) — multi-perspective PR review stack; D1/D2 already superseded in part by ADR-0086 (cross-referenced, not re-superseded)
- [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) — Home Server for OpenClaw (**superseded by this ADR**)
- [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) — pull-based local worker (**the replacement substrate**; this ADR completes the teardown it began)
- [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) — secret lifecycle; the webhook secret's deletion (vs rotation) path
- [ADR-0082](./ADR-0082-canonical-node-standup-procedure.md) — node-standup procedure (invariant 102; matrix reconciled by this ADR)
- [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) — sensitive inventory (invariant 103; footprint prose reconciled by this ADR)
- [`../constitution/invariants.md`](../constitution/invariants.md) — invariant 103 (the teardown-ordering gate); invariant 8 (the inventory never held the secret value)
- [`../constitution/node-standup.md`](../constitution/node-standup.md) — the per-class org-secret matrix (OpenClaw row retained only until the org secret is deleted) and the operator-internal-automation carve-out (OpenClaw is not a Node)
- [`../infrastructure/workers/grid-agent-runner/README.md`](../infrastructure/workers/grid-agent-runner/README.md) — the ADR-0086 runner that replaces every OpenClaw workload
- GitHub issue #527 — `[Rotate] OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` (closed by this ADR's teardown, no successor)
