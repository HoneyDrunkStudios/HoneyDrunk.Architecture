---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0088", "wave-4"]
dependencies: ["work-item:03", "work-item:00a"]
adrs: ["ADR-0088", "ADR-0082", "ADR-0083", "ADR-0084", "ADR-0085"]
accepts: []
wave: 4
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Reconcile OpenClaw references in ADR-0082, ADR-0083, ADR-0084, and ADR-0085 as documentation-currency edits

## Summary
Reconcile the OpenClaw references across four accepted ADRs so none of them keeps naming OpenClaw as a live secret surface or a live execution/transport surface. These are **documentation-currency edits of accepted ADRs** (the standing convention for keeping accepted-ADR prose honest), **not re-supersessions**:

- **ADR-0082** — the invariant-102 conditional-secret enumeration that names `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`, plus its `adrs/README.md` index row.
- **ADR-0083** — the footprint prose naming "the OpenClaw GitHub App private key" (a credential never provisioned) and the webhook secret.
- **ADR-0084** (Discord operator alerts, Accepted) — ~10 OpenClaw references: a depends-on edge to ADR-0081, "OpenClaw session boundaries" as an `#agent-activity` alert source (line 61), and "`job-review-request.yml` or its successor in the home-server-hosted bridge per ADR-0081" (line 116). Re-home these onto the post-OpenClaw reality (the ADR-0086 worker; ADR-0081 superseded by ADR-0088).
- **ADR-0085** (docs-sync / grid-wide documentation-currency agent, Accepted) — the live **"Execution surface: OpenClaw scheduled trigger"** decision (lines 51, 188–196, 223, 246, 338, and the ADR-0081 reference at line 387). This is a live run-surface decision, not stale prose; decommissioning OpenClaw invalidates it. Re-home docs-sync's execution surface onto the ADR-0086 local worker **with its now-authored `docs-sync` job spec** (packet 00a) — consistent with how hive-sync and the Lore jobs moved, and now backed by a live spec so docs-sync's Friday cadence is automated. **No manual-floor caveat** — the operator chose automated scheduling (option (a)), packet 00a landed the job spec, so the prose re-points cleanly onto the worker's scheduled job. ADR-0085 itself notes the agent is "execution-surface-agnostic," so this is a surface re-pointing, not a redesign.

The ADR-0082/0083 secret-surface edits and ADR-0084's bridge/secret references are **gated on packet 03** (the secret deletion) so the reconciliation is truthful when it lands. The ADR-0085 execution-surface re-homing and ADR-0084's runtime/session-boundary references are honest once the OpenClaw **runtime** is torn down (packet 02) and ADR-0081 is superseded (packet 00); they are bundled here in Wave 4 with the secret-surface work for a single coherent accepted-ADR-currency PR, which is correct because packet 03 (and therefore packet 02) precede this packet in the chain.

## Context
ADR-0088 D3 Group 4 step 11:

> Reconcile the OpenClaw references in **ADR-0082** (invariant 102 enumeration and the README index row) and **ADR-0083** (footprint prose naming "the OpenClaw GitHub App private key" and the webhook secret) so they no longer imply a live OpenClaw secret surface. These are text reconciliations of accepted ADRs, performed as documentation-currency edits (the standing convention for keeping accepted-ADR prose honest), not re-supersessions.

Two specific inaccuracies must be corrected, per ADR-0088's verified footprint:

1. **The "OpenClaw GitHub App private key" never existed.** ADR-0083's footprint prose names "the OpenClaw GitHub App private key" in two places (the credential-class enumeration and the volume-count list). ADR-0088 Context verified: the org's installed Apps are `chatgpt-codex-connector`, `vercel`, `graphite-app`, `honeydrunk-hive`, `claude`, `honeydrunk-grid-review` (app_id 3841539), `sonarqubecloud`, `coderabbitai`. **There is no OpenClaw App.** The `honeydrunk-grid-review` App is the ADR-0044 review-agent identity that ADR-0086 D4 reuses as the pull-based worker's identity — it is the *retained* replacement-substrate identity, not OpenClaw's. ADR-0083's prose anticipated a credential that was never separately provisioned; this packet corrects it.
2. **`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` is no longer a live secret.** By the time this packet lands (gated on packet 03), the secret is deleted. ADR-0082's invariant-102 conditional-secret enumeration (and its README index row) and ADR-0083's footprint prose that name it as a live conditional org secret must be reconciled to past tense / decommissioned, with a pointer to ADR-0088.

This is a docs-only packet. `Actor=Agent`. Gated on packet 03 so the prose is honest when it merges.

## Scope — ADR-0082
- `adrs/ADR-0082-canonical-node-standup-procedure.md` line ~225 — the invariant-102 "Conditional on ADR-0044 review-pipeline emission" enumeration lists `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`. Reconcile: either remove the bullet, or annotate it as decommissioned per ADR-0088. Recommended: replace the bullet with a one-line note that the ADR-0044 review-pipeline upstream-emission secret was decommissioned under ADR-0086/ADR-0088 (the pull-based worker posts nothing upstream through a webhook secret), so this conditional no longer applies. The note preserves the *shape* of D8's "moving target" enumeration while removing the dead entry.
- ADR-0082's body also references OpenClaw skills-mirroring (line ~98, "Mirrored to OpenClaw skills per ADR-0007's Operational Addendum") and the taxonomy note (line ~247, "Honeyclaw/OpenClaw configuration repos"). **Decision Point below** — these are ADR-0007 mirroring / taxonomy references, arguably out of scope for the "live secret surface" reconciliation. Default: leave them unless they assert a live OpenClaw secret surface (they do not). Only the line-225 secret enumeration is in firm scope.
- `adrs/README.md` ADR-0082 index row (line ~90) — the row's description enumerates the org-secret binding artifacts and names `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`. Reconcile to remove or past-tense that mention, consistent with the body edit.

## Scope — ADR-0083
- `adrs/ADR-0083-external-saas-credential-rotation.md`:
  - Line ~20 — names "OpenClaw's webhook bridge" as a fallback-identity use of `GH_ISSUE_TOKEN`. Reconcile: note the webhook bridge is decommissioned per ADR-0088 (past tense), or annotate that this use no longer applies. Light touch — the sentence is about `GH_ISSUE_TOKEN`'s use cases, not OpenClaw per se.
  - Line ~43 — the volume-count list names "the OpenClaw GitHub App private key" as one of the fewer-than-ten active tokens. **Correct the inaccuracy:** there is no OpenClaw GitHub App private key; it was never provisioned. Remove it from the list and adjust the count narrative, or annotate that it was an anticipated credential that never materialized (the `honeydrunk-grid-review` App is the retained ADR-0086 worker identity, not OpenClaw's).
  - Line ~68 — names "the ADR-0044 webhook signing secret is consumed by the home-server-hosted OpenClaw bridge." Reconcile to past tense (the bridge and the secret are decommissioned per ADR-0088).
  - Line ~238 — the seed-inventory bullet `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET — Kind: webhook-signing-secret, Rotates: yes, per ADR-0044 D2`. Reconcile: annotate that this row was retired under ADR-0088 (the secret is deleted; the inventory row removed in packet 04). This is an ADR's *snapshot* of the seed inventory — annotate, do not necessarily delete, since the ADR records the inventory's state at its drafting.
  - Line ~257 — names a "future `openclaw-webhook-secret-rotation.md` walkthrough lands with the webhook-bridge work." Reconcile: note the walkthrough was retired (not landed long-term) under ADR-0088 — the webhook bridge was decommissioned rather than completed.
- `adrs/README.md` ADR-0083 index row (line ~91) — the row description names "the OpenClaw GitHub App private key" as one of the credentials the inventory covers. **Correct the same inaccuracy** as the body: it was never provisioned. Remove or past-tense it.

## Scope — ADR-0084 (Discord operator alerts)
ADR-0084 is Accepted and carries ~10 OpenClaw references. Reconcile each so it reflects the post-OpenClaw reality (the ADR-0086 pull-based worker is the runtime; ADR-0081 is superseded by ADR-0088). Light-touch, past-tense/annotate — do not rewrite the alert-surface decisions:
- Line ~31 — Context depends-on list names ADR-0081 as "home-server hosts the OpenClaw bridge and is a complementary surface." Annotate that ADR-0081 is superseded by ADR-0088 and the home-server premise re-homed under ADR-0086; the bridge is decommissioned.
- Line ~61 — the `#agent-activity` alert-source roster lists "OpenClaw session boundaries" as a source. Reconcile: OpenClaw is decommissioned, so "OpenClaw session boundaries" is no longer an emitting source. Replace with the ADR-0086 worker's session/run boundaries (the local worker is the surviving scheduled-agent runtime) or remove the dead source, per the Decision Point posture.
- Line ~116 — the event-source table names "`job-review-request.yml` (or its successor in the home-server-hosted bridge per ADR-0081)". The "home-server-hosted bridge" successor never materialized and is now decommissioned; the live path is the ADR-0086 pull-based worker. Reconcile to name the ADR-0086 worker, not the bridge.
- Line ~119 — names a "tiny relay (home server per ADR-0081)" for PR webhooks. Past-tense the ADR-0081 reference (superseded by ADR-0088); the home-server premise survives under ADR-0086 but the OpenClaw-bridge framing does not.
- Lines ~184, ~264, ~276, ~307, ~323, ~393 — these reference the **home server** as a credible host / second delivery path / helper-script home via ADR-0081. The home server itself is **retained** (ADR-0088 D1), so these are valid in substance; only the **ADR-0081 citation** needs a forward pointer to ADR-0088 (premise re-homed under ADR-0086). Do not delete the home-server delivery-path narrative — it survives.

## Scope — ADR-0085 (docs-sync / grid-wide documentation-currency agent)
ADR-0085 is Accepted and binds **"Execution surface: OpenClaw scheduled trigger"** as a live D6 run-surface decision. Decommissioning OpenClaw invalidates that decision, so this is more than past-tensing prose — it is a **surface re-pointing** onto the ADR-0086 local worker (consistent with how hive-sync and the Lore jobs moved). The operator chose automated scheduling: **packet 00a authored a `docs-sync` job spec** (`infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1`, validated + smoke-recorded), so docs-sync's weekly-Friday cadence runs on the worker's scheduled job — **drop the manual-floor caveat** entirely; the re-pointing lands on a live, scheduled surface, not a deferred one. ADR-0085 itself states the agent is "execution-surface-agnostic (it reads files, writes files, and calls `gh`)," so the re-pointing is bounded and does not redesign the agent. Reconcile:
- Line 51 — "**Execution surface:** OpenClaw scheduled trigger (consistent with `hive-sync`), with manual dispatch supported." Re-home: the execution surface is the **ADR-0086 local worker scheduled job** (the `docs-sync` job spec landed by ADR-0088 packet 00a, consistent with `hive-sync`, which runs as a runner job spec), with manual dispatch still supported as a fallback. Annotate with a forward pointer to ADR-0088/ADR-0086. No manual-floor caveat — the Friday cadence is automated on the worker.
- Lines 188–196 (D6 region) — "Execution surface: OpenClaw scheduled trigger, with manual dispatch. Consistent with `hive-sync` per ADR-0081." and "until OpenClaw scheduling for the Friday slot lands…" and "A future ADR may reverse this if OpenClaw availability becomes a constraint; the agent itself is execution-surface-agnostic…". Re-home onto the ADR-0086 worker's `docs-sync` job spec (Friday slot, automated). ADR-0081 reference past-tensed (superseded by ADR-0088). The "until … the Friday slot lands" deferral is **resolved** — the slot landed via packet 00a; reconcile that sentence to past tense / done rather than carrying it as an open deferral.
- Lines 223, 225 (Phase plan) — "Wire OpenClaw scheduled trigger (Friday slot)" / "Verifies: OpenClaw can invoke the agent…". Re-home onto the ADR-0086 worker's job-spec wiring.
- Line 246 — "Confirm Friday cadence and OpenClaw integration." Re-home onto the ADR-0086 worker.
- Lines 338, 340 (Alternatives Considered "Decide the execution surface (OpenClaw vs GitHub Actions cron)") — reconcile so the rejected-alternative narrative reads against the ADR-0086 worker as the chosen surface rather than OpenClaw; or annotate that the OpenClaw surface this section weighed is decommissioned per ADR-0088 and the local worker (ADR-0086) is now the surface, GitHub-Actions cron remaining the documented fallback.
- Line 387 — the ADR-0081 "OpenClaw execution surface" reference link. Past-tense/annotate: ADR-0081 superseded by ADR-0088; execution surface re-homed onto the ADR-0086 local worker.

> **Gap closed by packet 00a (no residual deferral):** the `docs-sync` job spec now **exists** at `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` — packet 00a (Wave 0) authored, validated, and smoke-tested it as the committed prerequisite of this initiative. So re-homing docs-sync's execution surface onto the worker points at a **live, scheduled job spec**, not a pointer to something that does not exist. This packet's edit re-points ADR-0085 to "the ADR-0086 local worker's `docs-sync` scheduled job (Friday cadence)" with **no manual-floor caveat** — the operator chose automated scheduling and packet 00a delivered it. Verify the spec is present (and 00a Done) before this packet's PR merges, the same way the secret-surface edits verify packet 03.

## Decision Point — depth of edits
All four are *accepted* ADRs. The documentation-currency convention keeps their prose honest without rewriting their decisions. The recommended posture is **annotate with a forward pointer to ADR-0088, in past tense**, rather than deleting historical narrative wholesale — an ADR is partly a historical record of what was believed at drafting time. The firm requirements are: (a) **no remaining live-tense claim** that the Grid holds an `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` or an "OpenClaw GitHub App private key"; (b) the "OpenClaw GitHub App private key" inaccuracy is explicitly corrected (it never existed); (c) **no remaining live-tense claim that OpenClaw is the docs-sync execution surface or a live alert-emitting runtime** — ADR-0085's execution surface is re-pointed onto the ADR-0086 worker's `docs-sync` job spec (authored by packet 00a; **no manual-floor caveat**, the Friday cadence is automated), and ADR-0084's "OpenClaw session boundaries" source + bridge-successor references are re-homed; (d) the home-server narrative in ADR-0084 is **retained** (only its ADR-0081 citations get forward pointers), because the machine survives. The **ADR-0007 Operational Addendum / OpenClaw-skills-mirroring rule** (node-standup step 15, `copilot/agent-skills-map.md`) is a *binding governance rule*, not accepted-ADR currency prose — it is retired in **packet 07**, not here. The ADR-0082 skills-mirroring (line ~98) and taxonomy (line ~247) references are out of scope here unless they assert a live secret surface (they do not).

## Proposed Implementation
1. **Verify packet 03 deleted the secret** (the prose says "decommissioned" — confirm it actually is). Record in the PR body.
2. Reconcile ADR-0082 line ~225 and its README row (line ~90) — the invariant-102 conditional-secret enumeration.
3. Reconcile ADR-0083 lines ~20, ~43, ~68, ~238, ~257 and its README row (line ~91) — correcting the "OpenClaw GitHub App private key" inaccuracy and past-tensing the webhook-secret/bridge references.
4. Reconcile ADR-0084 lines ~31, ~61, ~116, ~119 (OpenClaw bridge/session-boundary/successor references) and forward-point the ADR-0081 citations at ~184/~264/~276/~307/~323/~393 — retaining the home-server delivery-path narrative.
5. Re-home ADR-0085's execution surface (lines 51, 188–196, 223, 225, 246, 338, 340, 387) onto the ADR-0086 local worker's `docs-sync` scheduled job (authored by packet 00a). **No manual-floor caveat** — the Friday cadence is automated; resolve the "until the Friday slot lands" deferral to done. Verify the `docs-sync.psd1` job spec is present (packet 00a Done) before merging.
6. Add a brief `> **Documentation-currency note (ADR-0088, 2026-05-30):**` annotation near each reconciled passage pointing at ADR-0088 as the decommission record, per the standing convention.
7. Update `CHANGELOG.md`.

## Affected Files
- `adrs/ADR-0082-canonical-node-standup-procedure.md`
- `adrs/ADR-0083-external-saas-credential-rotation.md`
- `adrs/ADR-0084-discord-operator-alerts-surface.md`
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md`
- `adrs/README.md` (ADR-0082 + ADR-0083 index rows; check ADR-0084 / ADR-0085 rows for OpenClaw-surface claims and reconcile if present)
- `CHANGELOG.md`

## NuGet Dependencies
None. Markdown edits only; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any repo.
- [x] **Documentation-currency edits, NOT re-supersessions** (ADR-0088 D3 step 11). ADR-0082, ADR-0083, ADR-0084, and ADR-0085 all remain Accepted; their decisions are unchanged; only OpenClaw secret-surface / execution-surface / runtime prose is reconciled. ADR-0085's "Execution surface: OpenClaw" is re-pointed onto the ADR-0086 worker — a surface re-pointing the ADR explicitly anticipates ("execution-surface-agnostic"), not a decision reversal.
- [x] ADR-0044 and ADR-0079 are NOT edited (ADR-0088 D2 — already superseded-in-part by ADR-0086).
- [x] `constitution/invariants.md` is NOT edited (ADR-0088 D6). Invariant 102's enumeration is a non-normative example list in ADR-0082, not the invariant text.
- [x] **Blocked-by packet 03** — the prose reconciliation is truthful only after the secret is deleted.

## Acceptance Criteria
- [ ] ADR-0082's invariant-102 conditional-secret enumeration (line ~225) no longer presents `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` as a live conditional org secret; it is removed or annotated as decommissioned per ADR-0088
- [ ] The ADR-0082 README index row (line ~90) no longer names `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` as a live binding artifact (removed or past-tensed)
- [ ] ADR-0083's "OpenClaw GitHub App private key" references (line ~43 body + line ~91 README row) are corrected — the credential never existed; the `honeydrunk-grid-review` App is identified as the retained ADR-0086 worker identity, not OpenClaw's
- [ ] ADR-0083's webhook-secret/bridge references (lines ~20, ~68, ~238, ~257) are past-tensed/annotated as decommissioned per ADR-0088
- [ ] Each reconciled passage carries a brief documentation-currency note pointing at ADR-0088
- [ ] No remaining live-tense claim that the Grid holds an `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` or an "OpenClaw GitHub App private key" exists in ADR-0082, ADR-0083, or their README rows
- [ ] ADR-0084's "OpenClaw session boundaries" alert source (line ~61) and the "home-server-hosted bridge / its successor" review-event source (line ~116) no longer name OpenClaw as a live emitting source; they are re-homed onto the ADR-0086 worker, and the ADR-0081 citations carry a forward pointer to ADR-0088
- [ ] ADR-0084's home-server delivery-path narrative (lines ~184/~264/~276/~307/~323/~393) is **retained** (the machine survives) — only the ADR-0081 citations are forward-pointed, not deleted
- [ ] ADR-0085's "Execution surface: OpenClaw scheduled trigger" (lines 51, 188–196, 223, 225, 246, 338, 340, 387) is re-pointed onto the ADR-0086 local worker's `docs-sync` scheduled job (authored by packet 00a), **with no manual-floor caveat** (the Friday cadence is automated; the "until the Friday slot lands" deferral is resolved to done); no live-tense claim that OpenClaw is the docs-sync execution surface remains
- [ ] ADR-0082, ADR-0083, ADR-0084, and ADR-0085 remain `Accepted`; their decisions are unchanged (currency edits / surface re-pointing only, not re-supersessions)
- [ ] ADR-0044 and ADR-0079 are unchanged
- [ ] The ADR-0007 Operational Addendum / OpenClaw-skills-mirroring rule is NOT touched here (that is packet 07)
- [ ] `constitution/invariants.md` is unchanged
- [ ] CHANGELOG.md records the ADR-0082 / ADR-0083 / ADR-0084 / ADR-0085 documentation-currency reconciliation, including the ADR-0085 execution-surface re-homing onto the worker's `docs-sync` job spec (automated Friday cadence, no manual-floor caveat)

## Human Prerequisites
- [ ] **Confirm packet 03 deleted the secret before this packet's PR merges.** The reconciled prose states the secret is decommissioned; verify it actually is. Record in the PR body.
- [ ] **Confirm packet 00a landed the `docs-sync` job spec before this packet's PR merges.** The reconciled ADR-0085 prose points at the worker's `docs-sync` scheduled job with no manual-floor caveat; verify `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` exists (packet 00a Done). Record in the PR body.

## Dependencies
- `work-item:03` — secret deletion (the prose reconciliation is honest only after the secret is gone).
- `work-item:00a` — the `docs-sync` job spec (the ADR-0085 re-point to "the worker's `docs-sync` scheduled job, no manual-floor caveat" is honest only once the spec exists).

## Referenced ADR Decisions
**ADR-0088 D3 Group 4 step 11 — Reconcile OpenClaw prose in accepted ADRs.** Documentation-currency edits of accepted ADRs (the standing convention for keeping accepted-ADR prose honest), not re-supersessions. ADR-0082: invariant-102 enumeration + README row. ADR-0083: footprint prose (the inaccurate "OpenClaw GitHub App private key" + the webhook secret). **ADR-0084 and ADR-0085 are folded in by this revision** because they too carry live OpenClaw surface claims that the decommission invalidates: ADR-0084 names OpenClaw session boundaries + the home-server bridge as live alert/event sources; ADR-0085 binds OpenClaw scheduled trigger as the docs-sync execution surface. Reconciling them under the same documentation-currency convention keeps every accepted ADR honest in one pass.

**ADR-0085 D6 — Execution surface is deferred / execution-surface-agnostic.** ADR-0085 explicitly states the agent "reads files, writes files, and calls `gh`" and is execution-surface-agnostic, with manual cadence as the floor until automation lands. Re-pointing the surface from OpenClaw to the ADR-0086 worker is therefore *within* ADR-0085's own deferral posture — not a reversal of its decision. The **deferral is now resolved**: packet 00a authored the `docs-sync` job spec, so automation landed and the Friday cadence is automated. The manual-floor caveat is **dropped** — manual dispatch remains supported as a fallback, but it is no longer "the floor until automation lands," because automation has landed.

**ADR-0081 superseded by ADR-0088 (packet 00).** ADR-0084's and ADR-0085's ADR-0081 citations are forward-pointed to ADR-0088; the home-server premise survives re-homed under ADR-0086, so the home-server narrative (esp. in ADR-0084) is retained, not deleted.

**ADR-0088 Context (verified footprint) — There is no OpenClaw App.** The org's Apps are `chatgpt-codex-connector`, `vercel`, `graphite-app`, `honeydrunk-hive`, `claude`, `honeydrunk-grid-review`, `sonarqubecloud`, `coderabbitai`. `honeydrunk-grid-review` (app_id 3841539) is the retained ADR-0086 worker identity. ADR-0083's "OpenClaw GitHub App private key" anticipated a credential never provisioned.

**ADR-0088 D6 — No new invariants.** `constitution/invariants.md` is not edited; invariant 102's enumeration is a non-normative example list in ADR-0082.

**ADR-0088 D2 — Do not re-supersede ADR-0044 / ADR-0079.** Those ADRs are not edited.

## Constraints
- **Currency edits, not re-supersessions.** ADR-0082, ADR-0083, ADR-0084, and ADR-0085 stay Accepted; their decisions are untouched; only OpenClaw secret-surface / execution-surface / runtime prose is reconciled. Annotate with a forward pointer to ADR-0088 in past tense.
- **ADR-0085 is a surface re-pointing, not a redesign.** Re-home the docs-sync execution surface onto the ADR-0086 worker's `docs-sync` job spec (authored by packet 00a) per ADR-0085's own "execution-surface-agnostic" framing. **Drop the manual-floor caveat** — packet 00a landed the job spec, so the Friday cadence is automated; do not author a job spec in this packet (00a owns that), but do verify it exists.
- **Retain ADR-0084's home-server narrative.** The home server survives (ADR-0088 D1); only its ADR-0081 citations get forward pointers. Do not delete the delivery-path / helper-script narrative.
- **Correct the "OpenClaw GitHub App private key" inaccuracy explicitly.** It never existed; the `honeydrunk-grid-review` App is the retained ADR-0086 worker identity.
- **Verify packet 03 first.** The reconciled prose claims decommission — it must be true when it lands.
- **Do not edit `constitution/invariants.md`** (ADR-0088 D6) — invariant 102's enumeration is a non-normative example list, not the invariant text.
- **Do not edit ADR-0044 / ADR-0079** (ADR-0088 D2).
- **Do not touch the ADR-0007 Operational Addendum / OpenClaw-skills-mirroring rule** — that binding governance rule is retired in packet 07, not here.
- **ADR-0082 skills-mirroring / taxonomy references are out of scope** unless they assert a live secret surface (they do not).

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0088`, `wave-4`

## Agent Handoff

**Objective:** Reconcile OpenClaw references across four accepted ADRs as documentation-currency edits: ADR-0082 (invariant-102 enumeration + README row), ADR-0083 (footprint prose, correcting the never-provisioned "OpenClaw GitHub App private key" + past-tensing the webhook secret), ADR-0084 (OpenClaw session-boundary / bridge-successor alert sources re-homed onto the ADR-0086 worker; home-server narrative retained), and ADR-0085 (the docs-sync execution surface re-pointed off "OpenClaw scheduled trigger" onto the ADR-0086 worker's `docs-sync` scheduled job authored by packet 00a — automated Friday cadence, no manual-floor caveat).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Complete D3 Group 4 step 11 (widened) — make every accepted ADR honest now that OpenClaw and its secret are decommissioned, including the live ADR-0085 execution-surface decision and ADR-0084's runtime references.
- Feature: ADR-0088 OpenClaw decommission, Wave 4 (D3 Group 4).
- ADRs: ADR-0088 (primary, D3 step 11), ADR-0082 / ADR-0083 / ADR-0084 / ADR-0085 (reconciled), ADR-0086 (the surviving worker the surfaces re-home onto), ADR-0081 (superseded by ADR-0088 in packet 00).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — secret deletion (the secret-surface reconciliations are honest only after deletion; the ADR-0084 runtime / ADR-0085 execution-surface re-homing is honest after packet 02's runtime teardown + packet 00's ADR-0081 supersession, both upstream of packet 03 in the chain).
- `work-item:00a` — the `docs-sync` job spec (the ADR-0085 re-point to the worker's `docs-sync` scheduled job, no manual-floor caveat, is honest only once the spec exists).

**Constraints:**
- Currency edits / surface re-pointing, not re-supersessions — ADR-0082/0083/0084/0085 stay Accepted.
- ADR-0085 is a surface re-pointing within its own "execution-surface-agnostic" framing; **drop the manual-floor caveat** — packet 00a landed the `docs-sync` job spec, so the Friday cadence is automated. Do not author a job spec here (00a owns that); do verify it exists.
- Retain ADR-0084's home-server delivery-path narrative; only forward-point its ADR-0081 citations.
- Correct the "OpenClaw GitHub App private key" inaccuracy (it never existed).
- Verify packet 03 first.
- Do not touch the ADR-0007 Operational Addendum / skills-mirroring rule (packet 07 owns that).
- Do not edit `constitution/invariants.md`, ADR-0044, or ADR-0079.

**Key Files:**
- `adrs/ADR-0082-canonical-node-standup-procedure.md` (line ~225)
- `adrs/ADR-0083-external-saas-credential-rotation.md` (lines ~20, ~43, ~68, ~238, ~257)
- `adrs/ADR-0084-discord-operator-alerts-surface.md` (lines ~31, ~61, ~116, ~119; home-server citations ~184/~264/~276/~307/~323/~393)
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md` (lines 51, 188–196, 223, 225, 246, 338, 340, 387)
- `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1` (verify it exists — packet 00a's deliverable — before re-pointing ADR-0085 with no manual-floor caveat)
- `adrs/README.md` (ADR-0082 + ADR-0083 rows; check ADR-0084 / ADR-0085 rows)
- `CHANGELOG.md`

**Contracts:** None.
