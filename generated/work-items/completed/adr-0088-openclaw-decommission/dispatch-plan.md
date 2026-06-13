# Dispatch Plan — ADR-0088: Decommission OpenClaw from the HoneyDrunk Grid

**Initiative:** `adr-0088-openclaw-decommission`
**ADR:** ADR-0088 (Proposed → Accepted via packet 00)
**Sector:** Meta / Ops (governance + operator-machine teardown + org-admin + CI cleanup)
**Created:** 2026-05-30

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0086 already moved the **review transport** off OpenClaw (pull-based local worker) and built a portable scheduled-agent runner that covers every workload OpenClaw was reserved for. ADR-0088 is the single governing decision that **finishes the teardown** ADR-0086 deferred: it supersedes ADR-0081 (the broad "OpenClaw is the host for all local automation" premise), removes the OpenClaw runtime / webhook bridge / OpenClaw-bound Cloudflare Tunnel from the home server, deletes the one OpenClaw-bound credential that actually exists (`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`), and then — **only after that secret is gone** — retires the inventory triplet (row + walkthrough + standing issue #527) and reconciles the governance prose that still names a live OpenClaw secret surface.

The defining constraint is **invariant 103**: the inventory must reflect exactly what the Grid holds — never claim a secret it dropped, never drop a secret it still holds. So the packet that retires the inventory triplet is **blocked-by** the packet that deletes the secret. Until deletion confirms, the row stays.

This initiative ships **9 packets across 5 waves** (Waves 0–4), mapped to ADR-0088 D3's four groups (plus two governance-currency cleanups the refine pass surfaced: ADR-0084/0085 reconciliation folded into packet 05, and the ADR-0007 Operational Addendum retirement as new packet 07) — plus a **Wave-0 prerequisite (packet 00a)** the operator committed to: authoring + smoke-testing a `docs-sync` runner job spec so docs-sync keeps automated Friday scheduling on the ADR-0086 worker rather than dropping to its manual floor. The teardown does not begin until ADR-0086's replacement jobs are proven load-bearing (D3 Group 1 prerequisite gate, captured as packet 00's acceptance gate — now a concrete, falsifiable check, not a trust-based attestation — with packet 00a's docs-sync job spec as a hard precondition of that gate's Part B).

## Trigger

ADR-0088 is **Proposed 2026-05-30**. The operator decision to retire OpenClaw is already made; ADR-0086's Follow-up Work explicitly deferred "a dedicated OpenClaw-decommission ADR is being authored to supersede ADR-0081 and own deletion of the secret + bridge." This is that ADR, and these are its execution packets.

Context that shaped the sequencing: PR #528 (ADR-0083 inventory reconciliation) deliberately **kept** the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` inventory row, the `openclaw-webhook-secret-rotation.md` walkthrough, and standing issue #527 — because the secret was still live. Those three retire under **this** initiative (packet 04), gated on the secret deletion (packet 03), not before.

## Scope Detection

**Multi-repo.** Eight of nine packets target `HoneyDrunk.Architecture` (the docs-sync job-spec authoring, acceptance + supersession bookkeeping, reference-file removal, inventory-triplet retirement, governance-prose reconciliation across ADR-0082/0083/0084/0085, ADR-0007-addendum retirement) or are operator/org-admin chores recorded there. **One packet targets `HoneyDrunk.Actions`** (packet 06 — remove the vestigial deprecated `openclaw-webhook-url` / `openclaw-webhook-secret` / fallback inputs from `job-review-request.yml`). That cross-repo touch is what makes this multi-repo.

**No Node-graph cascade.** OpenClaw is operator-internal automation, **not a Node** (per `constitution/node-standup.md`'s carve-out). It has no `catalogs/nodes.json` row, no `relationships.json` edge, no `grid-health.json` entry. No consumes/consumed_by edge breaks; no downstream Node loses a dependency. The cascade is entirely in governance documents and operator infrastructure — a documentation-and-ops sequence, not a contract migration.

**No new-Node scaffolding.** Both target repos are live.

## Wave Diagram

Waves map to ADR-0088 D3's groups. Within a wave, order is not load-bearing; across waves it is strict. The `dependencies:` frontmatter is the real ordering signal — the wave grouping is for tidy filing.

### Wave 0 — Committed prerequisite: re-home docs-sync's scheduler onto the ADR-0086 worker

This wave precedes everything. It exists because the operator chose to keep docs-sync **automated** (option (a)) rather than dropping it to its ADR-0085 manual-dispatch floor (option (b)) after OpenClaw is gone. It is a hard precondition of packet 00's Part-B Group-1 gate and gates packet 02 (stopping the OpenClaw docs-sync schedule).

- [ ] **00a** — Architecture: **Author + smoke-test a `docs-sync` runner job spec** at `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1`, matching the shape of the six existing job specs (`grid-review`, `hive-sync`, `lore-ingest`, `lore-signal-review`, `lore-source`, `post-merge-audit`). Acceptance: the spec exists, validates against the runner's job-spec schema (`Assert-GridAgentJobSpec`), and carries a dry-run/smoke record (`Test-JobLocally.ps1 -JobId docs-sync` exits 0), so docs-sync's ADR-0085 weekly-Friday cadence runs on the ADR-0086 local worker. `Actor=Agent`. Blocked by: —.

**Wave 0 exit criterion:** `config/jobs/docs-sync.psd1` exists with all 18 schema keys, a weekly-Friday schedule (avoiding the Monday/Thursday `hive-sync` slot), `WriteMode = "pr"`, `Repo = "HoneyDrunk.Architecture"`, `PromptPath = ".claude/agents/docs-sync.md"`; and a passing dry-run smoke record. docs-sync now has an automated scheduler on the surviving runtime — its Part-B gate item is satisfied and packet 02 may stop its OpenClaw schedule.

### Wave 1 — D3 Group 1: Accept + confirm the replacement is load-bearing (prerequisite gate)

- [ ] **00** — Architecture: **Accept ADR-0088** — flip status; flip ADR-0081 to `Superseded by ADR-0088`; update `adrs/README.md` (ADR-0088 row → Accepted; ADR-0081 status); remove ADR-0081 from `initiatives/proposed-adrs.md`; register the initiative. The Group-1 prerequisite (ADR-0086 runner proven for `grid-review` + `hive-sync` + the Lore jobs) is recorded as this packet's acceptance gate. `Actor=Agent`. Blocked by: —.

**Wave 1 exit criterion (D5 abort gate) — concrete and falsifiable:**
- **Part A (review path): already green, provable from `main`.** 13 repos carry `runner: local-worker` in `.honeydrunk-review.yaml`; their `pr-review.yml` callers are on the clean (no-`openclaw-*`) form; `grid-review.psd1` is a live job spec. No operator action — recorded as fact.
- **Part B (non-review scheduled jobs): the open items.** `hive-sync` + `lore-source` + `lore-ingest` + `lore-signal-review` job specs are present in `config/jobs/` (verified) and each has a smoke record of a successful local-worker run; **and** packet **00a** has landed the `docs-sync` job spec with its dry-run smoke record. The docs-sync surface is no longer an open a/b choice — the operator committed to automated scheduling, packet 00a delivers it, and it is a hard precondition of this gate.

**If Part B is not green for a given workload, that workload's OpenClaw schedule is NOT stopped in Wave 2.** This ADR commits the intent to retire OpenClaw fully; it does not authorize tearing down a workload whose replacement is unproven.

### Wave 2 — D3 Group 2: Remove OpenClaw runtime + transport (no secret deletion yet)

Fully reversible (D5). Packets 01 (docs) and 02 (operator chore) run in parallel after 00.

- [ ] **01** — Architecture: Remove the `infrastructure/openclaw/` reference files (`grid-review-runner.md`, `hive-sync.md`); update the `infrastructure/workers/grid-agent-runner/README.md` predecessor pointers (lines 81–82) to tombstone form. `Actor=Agent`. Blocked by: 00. (Group 2 step 5.)
- [ ] **02** — Ops (operator chore, recorded in Architecture): Disable + remove OpenClaw Gateway / Honeyclaw runtime / all OpenClaw schedules (only those whose Part-B replacement is proven; **docs-sync's schedule only once packet 00a is Done** — its replacement scheduler exists); remove the ADR-0044 webhook bridge process + receiver config; remove the OpenClaw-bound Cloudflare Tunnel hostname (`grid-review.honeydrunkstudios.com`) + its route. **Mandatory repo-side edit:** reconcile `infrastructure/reference/owned-domains.md` lines 11 + 26 (the tunnel endpoint) to retired. Home server itself retained; non-OpenClaw tunnels untouched. `Actor=Human` (with the agent authoring the owned-domains.md + CHANGELOG record). Blocked by: 00, 00a. (Group 2 steps 2–4.)

**Wave 2 exit criterion:** OpenClaw runtime, webhook bridge, and OpenClaw-bound tunnel hostname are gone from the home server; the `infrastructure/openclaw/*` files are removed with the runner README pointers tombstoned. The org secret still exists (deletion is Wave 3) — invariant 103 is satisfied because the inventory row still describes a secret that still exists.

### Wave 3 — D3 Group 3: Delete the secret (point of no return), then retire the inventory triplet

This wave carries the invariant-103 gate. Packet 04 is **blocked-by** packet 03 — the inventory triplet retires only after the secret is confirmed deleted.

- [ ] **03** — Ops (org-admin chore, recorded in Architecture): **Delete the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org Actions secret**; close standing issue #527 as a decommission (no successor issue). No GitHub App or App private key is deleted (none is OpenClaw's). `Actor=Human`. Blocked by: 02. (Group 3 step 6 + step 9.) **Hard prerequisite for packet 04.**
- [ ] **04** — Architecture: **Gated on packet 03 confirming deletion (invariant 103).** Remove the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` row from `infrastructure/reference/sensitive-inventory.md`; remove/tombstone `infrastructure/walkthroughs/openclaw-webhook-secret-rotation.md`; remove the matrix row from `constitution/node-standup.md`. `Actor=Agent`. Blocked by: 03. (Group 3 steps 7–8 + Group 4 step 10.)

**Wave 3 exit criterion:** The secret is gone from GitHub org settings; #527 is closed (no successor); the inventory row, walkthrough, and node-standup matrix row are retired. The inventory no longer claims a secret the Grid no longer holds — invariant 103 satisfied in the post-deletion state. `external-credentials-check.yml` no longer has a row to watch for this credential.

### Wave 4 — D3 Group 4: Reconcile governance prose + CI cleanup + retire the orphaned skills rule

Runs after the secret is deleted (for the secret-surface parts) / after the runtime is torn down (for the execution-surface and skills-rule parts). Packets 05 and 06 depend on packet 03; packet 07 depends on packets 01 + 02 (the OpenClaw runtime/dir it retires). All three can run in parallel once their deps clear.

- [ ] **05** — Architecture: Reconcile OpenClaw references across **four** accepted ADRs as documentation-currency edits — ADR-0082 (invariant-102 conditional-secret enumeration line 225 + README row), ADR-0083 (footprint prose naming "the OpenClaw GitHub App private key" — a credential never provisioned — and the webhook secret), **ADR-0084** (OpenClaw session-boundary + home-server-bridge alert/event sources re-homed onto the ADR-0086 worker; home-server narrative retained), and **ADR-0085** (the docs-sync "Execution surface: OpenClaw scheduled trigger" re-pointed onto the ADR-0086 worker's `docs-sync` scheduled job authored by packet 00a — automated Friday cadence, **no manual-floor caveat**). `Actor=Agent`. Blocked by: 03, 00a. (Group 4 step 11, widened.)
- [ ] **06** — Actions: Remove the vestigial deprecated `openclaw-webhook-url` / `openclaw-webhook-secret` / `upload-fallback-artifact` / `post-fallback-comment` / `artifact-name` inputs from `.github/workflows/job-review-request.yml` (the live runner input is named `runs-on`, not `runner` — it is retained). Sequenced after the secret is deleted so no caller can pass a now-nonexistent secret. `Actor=Agent`. Blocked by: 03. (Group 4 step 12.)
- [ ] **07** — Architecture: Retire the **ADR-0007 "Operational Addendum: OpenClaw Skills"** companion-skill rule (a live orphan the decommission strands) and remove its live wirings — `constitution/node-standup.md` step 15's OpenClaw-mirroring clause and `copilot/agent-skills-map.md`'s OpenClaw-skill column + "OpenClaw Skill Pairing Rule" section. ADR-0007's core decision is retained (not superseded). `Actor=Agent`. Blocked by: 01, 02. (Refine-surfaced governance cleanup beyond D3's 12 steps.)

**Wave 4 exit criterion:** ADR-0082 / ADR-0083 / ADR-0084 / ADR-0085 prose no longer implies a live OpenClaw secret surface, alert source, or execution surface; the deprecated `openclaw-*` inputs are gone from `job-review-request.yml` (no caller references them, verified); and no governance surface (ADR-0007 addendum, node-standup step 15, agent-skills-map) mandates a live OpenClaw-skill pairing. The initiative archives when all five waves (0–4) are Done.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00a | [Author + smoke-test the `docs-sync` job spec](./00a-architecture-author-docs-sync-job-spec.md) | Architecture | Agent | 0 | — |
| 00 | [Accept ADR-0088 + supersede ADR-0081](./00-architecture-adr-0088-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Remove `infrastructure/openclaw/*` reference files](./01-architecture-remove-openclaw-reference-files.md) | Architecture | Agent | 2 | 00 |
| 02 | [Teardown OpenClaw runtime + bridge + tunnel](./02-ops-teardown-runtime-and-tunnel.md) | Architecture (ops chore) | Human | 2 | 00, 00a |
| 03 | [Delete org secret + close issue #527](./03-ops-delete-org-secret.md) | Architecture (org-admin chore) | Human | 3 | 02 |
| 04 | [Retire inventory triplet + matrix row](./04-architecture-retire-inventory-row.md) | Architecture | Agent | 3 | 03 |
| 05 | [Reconcile ADR-0082 / 0083 / 0084 / 0085 OpenClaw prose](./05-architecture-reconcile-adr-prose.md) | Architecture | Agent | 4 | 03, 00a |
| 06 | [Remove deprecated `openclaw-*` inputs](./06-actions-remove-deprecated-inputs.md) | Actions | Agent | 4 | 03 |
| 07 | [Retire ADR-0007 OpenClaw-skills addendum + wirings](./07-architecture-retire-openclaw-skills-rule.md) | Architecture | Agent | 4 | 01, 02 |

## Blocking / Gating Graph

```
00a ─────────────────────┐   (committed docs-sync scheduler; Part-B gate input)
                         ├──────────────► 02   (don't stop docs-sync's OpenClaw schedule with no replacement)
                         └──────────────► 05   (ADR-0085 re-point honest only once the spec exists)

00 ──┬── 01 ──────────────┐
     │                    ├── 07   (skills-rule retired after runtime + openclaw/ dir gone)
     └── 02 ──────────────┘
          └── 03 ──┬── 04   (invariant-103 gate: triplet retires only after secret deleted)
                   ├── 05
                   └── 06
```

(02 is blocked-by both 00 and 00a; 05 is blocked-by both 03 and 00a.)

- **00a → 02, 05 (and the Part-B gate)** — packet 00a authors + smoke-tests the `docs-sync` job spec on the ADR-0086 worker, the operator's committed choice to keep docs-sync automated. It is a **hard precondition of packet 00's Part-B Group-1 gate**, it blocks **02** (so docs-sync's OpenClaw schedule is not stopped before its replacement scheduler exists), and it blocks **05** (so the ADR-0085 re-point onto "the worker's `docs-sync` scheduled job, no manual-floor caveat" is honest only once the spec exists). It has no upstream blockers — it is the earliest packet (Wave 0).
- **00 → 01, 02** — nothing tears down until ADR-0088 is Accepted and (per packet 00's Part-B gate) the non-review ADR-0086 replacements are proven (Part A — the review path — is already green from `main`; the docs-sync replacement is packet 00a).
- **02 → 03** — the secret is deleted only after the webhook bridge it signed is already torn down (D5: deletion is the point of no return; the bridge must be gone first so deletion is clean).
- **03 → 04** — **the invariant-103 hard gate.** The inventory triplet retires only after the operator confirms the secret is actually deleted. If 04 ran before 03, the inventory would claim the Grid holds nothing while the secret still lived in GitHub — a false inventory, the exact failure invariant 103 exists to prevent. `external-credentials-check.yml` reads the inventory as truth; deleting the row while the secret lives would blind the watcher to a live credential.
- **03 → 05, 06** — the prose reconciliations (secret-surface parts) and the deprecated-input removal are honest only once the secret is gone. Removing the inputs before deletion could let a caller pass a now-nonexistent secret name. (Packet 05's ADR-0084 runtime / ADR-0085 execution-surface parts are honest once 02 + 00 land, both upstream of 03; packet 05 additionally carries a direct **00a** edge so the ADR-0085 "no manual-floor caveat" re-point lands only once the `docs-sync` job spec exists.)
- **01, 02 → 07** — the ADR-0007 OpenClaw-skills rule is honest to retire once the OpenClaw runtime is torn down (02) and the `infrastructure/openclaw/` directory the addendum cites is removed (01). It is **not** gated on the secret (03) — it is a runtime/skills-surface rule, not a credential.

## Single-vs-Multi-Repo Determination

**Multi-repo** — 8 packets in `HoneyDrunk.Architecture` (the docs-sync job-spec authoring + governance + docs + operator/org-admin chore records), 1 packet in `HoneyDrunk.Actions` (CI workflow input cleanup). No Node-graph cascade (OpenClaw is not a Node). One PR per repo per the standing convention: packets 00a, 00, 01, 04, 05, 07 are Architecture PRs; packet 06 is an Actions PR; packets 02 and 03 are operator/org-admin chores whose record lands as an Architecture PR (CHANGELOG + confirmation note, plus the mandatory owned-domains.md edit for 02) or as issue/PR-body evidence.

## Invariant Numbering

**No new invariants.** ADR-0088 D6 is explicit: it adds no invariants and reserves no numbers. It removes a row from the node-standup matrix and reconciles existing-ADR prose, but it does **not** edit `constitution/invariants.md`. Invariant 102's enumeration of conditional org secrets is a non-normative example list; dropping `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` from it (packet 05) is a documentation-currency edit, not an invariant change. Invariant 103 is the binding constraint **on the teardown ordering** (the 03 → 04 gate), not a target of change. **No packet in this initiative edits `constitution/invariants.md`.**

## Cross-Cutting Concerns

### Do not re-supersede ADR-0044 / ADR-0079

ADR-0044 D1/D5 and ADR-0079 D1/D2 are **already** "superseded in part by ADR-0086." ADR-0088 D2 is explicit: re-superseding already-superseded decisions muddies the supersession graph. **No packet edits ADR-0044 or ADR-0079.** ADR-0088 cross-references ADR-0086 as the replacement substrate and completes the physical teardown ADR-0086 deferred.

### The home server is retained

ADR-0088 D1 and the Alternatives Considered are explicit: OpenClaw ran *on* the home server; retiring OpenClaw does not retire the machine. The always-on mini-PC, the no-router-port-forwarding posture, the security checklist, and the local-agent-sandbox idea survive — re-homed under ADR-0086 (which names the home server as the runner host). **No packet decommissions the home server.** The runner framework (`grid-agent-runner`) remains the active local-automation host.

### The `honeydrunk-grid-review` GitHub App is retained

Per ADR-0088 Context: there is **no OpenClaw GitHub App** and no OpenClaw App private key. The org's installed Apps are `chatgpt-codex-connector`, `vercel`, `graphite-app`, `honeydrunk-hive`, `claude`, `honeydrunk-grid-review` (app_id 3841539), `sonarqubecloud`, `coderabbitai`. The `honeydrunk-grid-review` App is the ADR-0044 review-agent identity that **ADR-0086 D4 reuses as the pull-based worker's identity** — load-bearing for the *replacement* substrate, explicitly retained. **The teardown deletes no GitHub App and no App private key.** Packet 05 corrects ADR-0083's footprint prose that incorrectly named an "OpenClaw GitHub App private key" that was never provisioned.

### Access-policy anomaly resolved by deletion (D4)

`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` carries the `All repositories` access policy, which contradicts node-standup's "Selected repositories is the default for org secrets containing live credentials" rule. Because packet 03 **deletes** the secret outright, no access-policy remediation is needed — deletion resolves the drift. Packet 03 records this so the deletion is understood as also closing an access-policy anomaly. No other secret's access policy is changed.

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance/runner-config edits only (packets 00a, 00, 01, 04, 05, 07, and the chore records for 02/03 — including the new `docs-sync.psd1` job spec in 00a and the mandatory owned-domains.md edit in 02). The repo `CHANGELOG.md` is updated per repo convention on every packet.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; workflow/YAML edits (packet 06). The repo `CHANGELOG.md` is updated per repo convention.

## Rollback Plan

Per ADR-0088 D5, the teardown is reversible **up to and including Wave 2**; Wave 3's secret deletion is the point of no return for that credential.

- **Packet 00a (`docs-sync` job spec):** revert the PR removes `config/jobs/docs-sync.psd1` and the runner README bullet. Clean — PowerShell data file + markdown only, no runtime impact until the operator registers the scheduled task. Reverting before Wave 2 would re-open the docs-sync surface question (and block packet 02 from stopping docs-sync's OpenClaw schedule); reverting after Wave 2 would strand docs-sync with no scheduler, so a post-Wave-2 revert is only correct as part of a coordinated abort that also re-stands the OpenClaw docs-sync schedule.
- **Packet 00 (acceptance):** revert the PR. ADR-0088 returns to Proposed; ADR-0081 returns to Proposed and its `proposed-adrs.md` row + README status are restored; the initiative is unregistered. No runtime impact.
- **Packet 01 (reference-file removal):** revert the PR restores `infrastructure/openclaw/grid-review-runner.md` and `hive-sync.md` and the runner README's original predecessor pointers. Clean — markdown only.
- **Packet 02 (runtime/bridge/tunnel teardown):** **fully reversible (D5).** OpenClaw can be reinstalled, the bridge restarted, the tunnel hostname re-created. The org secret still exists at this stage, so signature verification would resume. Abort cost: re-standing the OpenClaw runtime. The operator records the teardown in the chore's PR/issue body for traceability.
- **Packet 03 (secret deletion): point of no return.** Once deleted, the prior HMAC value is gone (invariant 8: the inventory never held the value). Rolling back means **minting a new secret** and re-creating both ends (a fresh rotation per `openclaw-webhook-secret-rotation.md` against a new value), not "undeleting." Acceptable because the bridge it signed is already torn down in Wave 2 and the review transport has been the pull-based worker since ADR-0086. **Abort gate:** if Wave 1's prerequisite is not green, the teardown halts before Wave 2 and the secret is never deleted — invariant 103 stays satisfied automatically (the row still describes a secret that still exists).
- **Packet 04 (inventory triplet retirement):** revert the PR restores the inventory row, the walkthrough, and the node-standup matrix row. **But** if packet 03 already deleted the secret, reverting 04 would make the inventory claim a secret that no longer exists — a *different* invariant-103 violation. So a 04 revert is only correct as part of a coordinated abort that also re-mints the secret (re-creating what 03 deleted). In practice, once 03 lands, 04 should land and stay.
- **Packet 05 (prose reconciliation):** revert the PR restores the prior ADR-0082 / ADR-0083 / ADR-0084 / ADR-0085 prose. No runtime impact. (Note: a revert re-asserts "OpenClaw scheduled trigger" as ADR-0085's execution surface — only correct as part of a coordinated abort that also re-stands the OpenClaw runtime. The packet 00a `docs-sync` job spec is independent of this revert — it remains the live docs-sync scheduler regardless.)
- **Packet 06 (deprecated input removal):** revert the PR restores the deprecated inputs to `job-review-request.yml`. Since they are declared-but-unreferenced, restoring them is inert.
- **Packet 07 (ADR-0007 addendum retirement):** revert the PR restores the Operational Addendum, the node-standup step-15 OpenClaw-mirroring clause, and the agent-skills-map OpenClaw column + pairing rule. Clean — markdown/governance only; ADR-0007's core decision was never touched, so nothing else moves.

## Out-of-scope items

- **Editing `constitution/invariants.md`** — ADR-0088 D6 explicit; no invariant added or changed.
- **Editing ADR-0044 or ADR-0079** — ADR-0088 D2 explicit; already superseded-in-part by ADR-0086; re-superposition forbidden.
- **Decommissioning the home server** — ADR-0088 Alternatives Considered explicit; the machine is retained as the runner host.
- **Deleting any GitHub App or App private key** — ADR-0088 Context explicit; `honeydrunk-grid-review` is the retained ADR-0086 worker identity; no OpenClaw App exists.
- **Disabling non-review OpenClaw schedules whose ADR-0086 replacement is unproven** — the D5 abort gate (Wave 1 prerequisite) governs; a workload's OpenClaw schedule is disabled only after its runner replacement has a smoke-test record.
- **Opening a successor rotation issue after closing #527** — explicitly forbidden by D3 step 9; there is no longer a credential to rotate.

> **Previously deferred, now IN SCOPE:** authoring a `docs-sync` runner job spec. The operator resolved the open docs-sync surface question in favor of automated scheduling (option (a)), so authoring + smoke-testing the `docs-sync` job spec is now **packet 00a (Wave 0)** — the earliest, committed prerequisite of this initiative — not a deferred residual. Packet 05 re-points ADR-0085's prose onto the worker's `docs-sync` scheduled job with **no manual-floor caveat**, and packet 02 stops docs-sync's OpenClaw schedule only once packet 00a is Done.

## Cross-Cutting — ADR-0085 docs-sync execution surface (the one non-review re-home, now resolved)

ADR-0085 bound OpenClaw scheduled trigger as the docs-sync execution surface — the only **non-review** scheduled workload in this teardown whose ADR-0086 replacement was **not yet built** at refine time. hive-sync and the three Lore jobs already had job specs in `config/jobs/`; docs-sync did not. The operator resolved this in favor of automated scheduling: **packet 00a (Wave 0) authors + smoke-tests a `docs-sync` job spec** at `config/jobs/docs-sync.psd1`, re-homing docs-sync's weekly-Friday cadence onto the ADR-0086 worker. ADR-0085 itself frames the agent as "execution-surface-agnostic" with manual cadence as the floor, so the re-home is bounded — but because packet 00a delivers the spec, the **manual-floor caveat is dropped**: packet 05 re-points the ADR-0085 prose onto the worker's `docs-sync` scheduled job as a live, automated surface, and packet 02 stops docs-sync's OpenClaw schedule only once packet 00a is Done. Packet 00a is therefore a hard precondition of packet 00's Part-B Group-1 gate; everything else (the review path) was already green.

## Cross-Cutting — site sync

No site-sync flag. ADR-0088 is internal governance / operator-machine teardown / org-admin — no Studios public-facing content changes.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`. The pipeline files packets 00a and 00 first (neither has upstream blockers), then 01 after 00 and 02 after 00+00a, then 03 after 02 and 07 after 01+02, then 04 after 03, 05 after 03+00a, and 06 after 03.

## Archival

Per ADR-0008 D10, when every packet reaches `Done` on The Hive and all five wave exit criteria (Waves 0–4) are met, the entire `active/adr-0088-openclaw-decommission/` folder moves to `archive/adr-0088-openclaw-decommission/` in a single commit.
