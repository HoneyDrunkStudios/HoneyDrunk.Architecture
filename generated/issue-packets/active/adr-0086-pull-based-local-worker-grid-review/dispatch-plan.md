# Dispatch Plan — ADR-0086: Pull-Based Local Worker as the Grid Review Runner

**Initiative:** `adr-0086-pull-based-local-worker-grid-review`
**ADR:** ADR-0086 (Proposed → Accepted via packet 01)
**Sector:** Meta (governance + CI + operator-machine automation)
**Created:** 2026-05-27

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0086 keeps the **discipline** of ADR-0044/ADR-0079 intact and changes only the **transport** and **execution substrate**. The inbound webhook + Cloudflare Tunnel + OpenClaw-on-the-review-path are removed. A cheap GitHub Action enqueues review requests by labelling and commenting on the PR; a PowerShell pull worker on the always-on home server polls GitHub on a 60–120 s cadence, claims one PR at a time via a label swap, runs the canonical `.claude/agents/review.md` agent locally under Codex CLI / Claude Code CLI subscription auth, and posts the verdict back. Reviewer 4 (Claude Code CLI under Max) runs today through the same local worker — the June 15 2026 dependency and the Claude-Code-on-the-web GitHub integration are removed from the Grid Review Runner's design.

This initiative ships **10 packets across 3 waves**, mapped 1:1 to ADR-0086 D11's three phases (A / B / C). Phase A is the critical path: build the new substrate, prove it on `HoneyDrunk.Architecture` only, and decommission the OpenClaw review-runner role. Phase B widens to the 10 remaining live .NET Nodes (superseding ADR-0044 Architecture#182 which was the same fan-out at the old default). Phase C is the narrative-surfacing polish — make worker availability observable through the weekly briefing and hive-sync. Multi-perspective on high-risk Nodes (D8) and post-merge sampling audit (D9) are preserved disciplines whose substrate moves to the local worker — both are wired into the worker by packet 03 ahead of their respective ADR-0044 activation packets (13/14 for D8, 15/16 for D9).

## Trigger

ADR-0086 is **Proposed 2026-05-26** in response to weeks of unreliability in the ADR-0044 webhook-to-OpenClaw substrate. The forcing functions from the ADR's Context:

- **Webhook delivery flakes.** GitHub redelivery is best-effort; the bridge has missed `synchronize` events on long PR sessions.
- **Tunnel uptime is operator-coupled.** Cloudflare Tunnel on the home server is fine when the home server is fine — also the single inbound path; when the operator travels, when the home server reboots, when the tunnel daemon hiccups, the inbound rail is down.
- **OpenClaw process stability** is improving but is not yet "set it and forget it." Crashes, session-credential expiry, dashboard-coupled state.
- **The architectural mismatch:** always-on inbound HTTP receiver on operator infrastructure does not match a solo-operator setup with travel.

The right move is to change the transport (pull instead of webhook) and the execution substrate (subscription-backed CLIs instead of OpenClaw/Codex). Discipline is preserved verbatim.

## Scope Detection

**Multi-repo.** ADR-0086 touches `HoneyDrunk.Architecture` (acceptance, supersession notes, worker source under `infrastructure/workers/`, schema-doc update, Architecture-pilot cutover, OpenClaw decommission, hive-sync/briefing wiring) and `HoneyDrunk.Actions` (the `job-review-request.yml` rewrite, the four worker labels added to labels-as-code and fanned out). Phase B widens to the 10 remaining live .NET Nodes via the same `target_repos` shape ADR-0044 packet 11 used (now superseded by this initiative's packet 09).

**No new-Node scaffolding.** Both Wave-1 target repos are live. The worker source lives in HoneyDrunk.Architecture under `infrastructure/workers/grid-review-runner/` — a directory choice pinned in packet 03 per ADR-0086 D4 Follow-up Work recommendation. No new Node repo is created.

## Wave Diagram

### Wave 1 — Phase A: MVP on the Architecture pilot

Packet 01 first (the acceptance flip). Then 02 (App provisioning) gates 03 (worker source); 04/05/06 run in parallel after 01; 07 (Phase-A cutover) depends on 02/03/04/05/06.

- [ ] **01** — Architecture: **Accept ADR-0086** — flip status, append supersession amendment notes to ADR-0044 and ADR-0079, register initiative, mark ADR-0044 Architecture#182 superseded. `Actor=Agent`.
- [ ] **02** — Architecture: Create `honeydrunk-review-worker` GitHub App, write its credentials to Vault, author the walkthrough doc. `Actor=Human` (portal work). Blocked by: 01.
- [ ] **03** — Architecture: Author the pull-based PowerShell worker at `infrastructure/workers/grid-review-runner/` (claim protocol, Task Scheduler installer, env hygiene, multi-perspective dispatch wiring, audit-mode dispatch wiring, README). `Actor=Agent`. Blocked by: 01, 02.
- [ ] **04** — Architecture: Update `copilot/review-config-schema.md` for the `runner:` enum change (drop `openclaw-codex`, add `local-worker` default, preserve `api-ci`). `Actor=Agent`. Blocked by: 01.
- [ ] **05** — Actions: Rewrite `job-review-request.yml` from webhook-emitting to label-and-comment-emitting per D2. `Actor=Agent`. Blocked by: 01.
- [ ] **06** — Actions: Add four worker labels (`needs-agent-review`, `agent-review-in-progress`, `agent-reviewed`, `changes-requested-by-agent`) to labels-as-code and fan out Grid-wide. `Actor=Agent`. Blocked by: 01.
- [ ] **07** — Architecture: Cut `HoneyDrunk.Architecture` over to `runner: local-worker`; update its `pr-review.yml` caller; verify end-to-end on the cutover PR; record Phase-A go/no-go. `Actor=Agent`. Blocked by: 02, 03, 04, 05, 06.

**Wave 1 exit criterion (Phase A go/no-go):** Per ADR-0086 D11 Phase A — verdict quality at least as useful as the manual local-agent invocation, reliable polling and claim semantics, head-SHA invalidation deterministically handles pushes mid-review, near-zero marginal cost under subscription auth. **If this bar is missed, Wave 2 does not start.**

### Wave 2 — Phase A → B cutover + Phase B fan-out

Runs after the Phase-A go decision. Packet 08 (OpenClaw decommission) must merge before packet 09 (Phase B fan-out) per ADR-0086 D10 sequencing.

- [ ] **08** — Architecture: Decommission OpenClaw on the review path — mark legacy contract doc superseded, cross-link new worker README, document operator-side cutover (Cloudflare Tunnel hostname removal, ADR-0044 webhook-signing secret rotation, OpenClaw review-role disable) as Human Prerequisites. **`adrs/ADR-0081-*.md` is NOT edited** (ADR-0086 Follow-up Work explicit; ADR-0081 is still Proposed). `Actor=Agent`. Blocked by: 07.
- [ ] **09** — Cross-repo (Architecture tracking + 10 child issues): Enable `runner: local-worker` on the 10 remaining live .NET Nodes (Kernel, Transport, Vault, Auth, Web.Rest, Data, Notify, Communications, Pulse, Actions). **Supersedes ADR-0044 Architecture#182.** `Actor=Agent`. Blocked by: 07, 08.

**Wave 2 exit criterion (Phase B go/no-go):** All 10 fan-out Nodes enabled with `runner: local-worker`; each Node's enablement PR was itself reviewed by the worker (smoke test); labels transition correctly across all 10 repos; OpenClaw review-runner role is offline; OpenClaw's other workloads (Honeyclaw, Lore sourcing) remain running. **Phase B miss pauses Phase C.**

### Wave 3 — Phase C: queue-depth surfacing + ramp

Runs after the Phase-B go decision. Phase C also includes the readiness for ADR-0044 packet 13 (`review_risk_class` catalog field) and packet 14 (D8 multi-perspective activation) — both ADR-0044 packets are **preserved** (not superseded) by ADR-0086; the worker (packet 03) is already wired for the dispatch. When ADR-0044 packets 13/14 land, D8 activates without further work in this initiative.

- [ ] **10** — Architecture: Wire queue-depth surfacing into `hive-sync` (new `grid_review_queue` field per ADR-0014 reconciliation) and the weekly ADR-0043 briefing (PRs in `needs-agent-review` older than 24 h). `Actor=Agent`. Blocked by: 07.

**Wave 3 exit criterion:** Queue depth surfaces in the weekly briefing's Reactive pillar and in hive-sync's output; D8 multi-perspective activates downstream when ADR-0044 packet 13 lands (no new work in this initiative); D9 post-merge audit-mode dispatch activates downstream when ADR-0044 packets 15/16 land. The initiative archives when all Phase C signals are clean.

Packets within a wave run in parallel where their `dependencies:` array permits (Wave 1 packets 02/04/05/06 are parallel after 01; 03 needs 02; 07 is the gate). The `dependencies:` frontmatter is the real ordering signal — the wave grouping is for tidy filing only.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 01 | [Accept ADR-0086](./01-architecture-adr-0086-acceptance.md) | Architecture | Agent | 1 | — |
| 02 | [GitHub App + Vault credentials](./02-architecture-create-review-worker-github-app.md) | Architecture | Human | 1 | 01 |
| 03 | [Pull-based PowerShell worker](./03-architecture-author-pull-worker.md) | Architecture | Agent | 1 | 01, 02 |
| 04 | [Schema-doc `runner:` enum update](./04-architecture-update-review-config-schema-doc.md) | Architecture | Agent | 1 | 01 |
| 05 | [Rewrite `job-review-request.yml`](./05-actions-rewrite-job-review-request-as-label-and-comment.md) | Actions | Agent | 1 | 01 |
| 06 | [Four worker labels Grid-wide](./06-actions-add-four-worker-labels-grid-wide.md) | Actions | Agent | 1 | 01 |
| 07 | [Architecture cutover to `runner: local-worker`](./07-architecture-cutover-pilot-to-local-worker.md) | Architecture | Agent | 1 | 02, 03, 04, 05, 06 |
| 08 | [Decommission OpenClaw review substrate](./08-architecture-decommission-openclaw-review-substrate.md) | Architecture | Agent | 2 | 07 |
| 09 | [Enable `runner: local-worker` on 10 Nodes](./09-cross-repo-enable-local-worker-ten-nodes.md) | Cross-repo | Agent | 2 | 07, 08 |
| 10 | [Hive-sync / briefing queue-depth surfacing](./10-architecture-hive-sync-queue-depth-surfacing.md) | Architecture | Agent | 3 | 07 |

## Invariant Numbering

**No new invariants.** ADR-0086's Invariants section is explicit: ADR-0044's invariants 52/53 are **preserved** with the "requests" mechanism redefined ("lands in the GitHub-native queue, processed by the local worker"); ADR-0079's preserved invariants are unchanged. The reconciliation — making the existing invariant 52's text read consistently with the new transport — is `hive-sync`'s job per ADR-0014, not this initiative's. **No packet in this initiative edits `constitution/invariants.md`.**

This is a deliberate choice in the ADR and a load-bearing constraint of packet 01's acceptance scope. If a future reading of invariants 52/53 shows drift between their text and the actual rule, the fix is an edit to invariants.md scheduled via `hive-sync` reconciliation, not a packet in this initiative.

## Cross-Cutting Concerns

### `.claude/agents/review.md` is unchanged

ADR-0086 D1 and Follow-up Work are explicit: the substrate change is invisible to the prompt. Both the (removed) OpenClaw path and the (new) local-worker path consume the same canonical agent file per ADR-0007. No packet in this initiative edits `.claude/agents/review.md`.

### ADR-0081 is unchanged

ADR-0086 Follow-up Work flags ADR-0081 D1's Implementation Notes review-webhook-bridge bullet as a one-line edit belonging to ADR-0081's own acceptance/amendment cycle (ADR-0081 is still Proposed). **No packet in this initiative edits ADR-0081.** Packet 08 (OpenClaw decommission) is explicit on this.

### Coupling with ADR-0044 packets 13–16 (preserved)

ADR-0044 packet 13 (`review_risk_class` catalog field) and packet 14 (D8 multi-perspective activation) are **preserved** by ADR-0086 — D8 is preserved as discipline; its substrate moves to the local worker. The worker (packet 03 in this initiative) is wired for the D8 dispatch ahead of activation. When ADR-0044 packets 13/14 land, D8 activates Grid-wide on the local-worker substrate without further work in this initiative.

ADR-0044 packets 15/16 (post-merge audit) are similarly preserved — the worker's audit-mode dispatch (packet 03) is wired; ADR-0044 packets 15/16 own the `generated/post-merge-audits/` directory and the `audit-sample` labelling logic.

### Supersession of ADR-0044 packet 11

ADR-0044 packet 11 (Architecture#182, the Phase-2 fan-out at the old OpenClaw default) is **superseded** by this initiative's packet 09 at the new `local-worker` default. Packet 01 marks the supersession in `initiatives/active-initiatives.md`; packet 09 closes Architecture#182 as superseded once it files.

### Phase A is the critical path

Everything downstream is sequenced behind Phase A's go decision (packet 07). If Phase A fails, the rollout halts — diagnose, fix, re-run Phase A; do not file Wave 2 or Wave 3 packets until Phase A is green. The exit criterion is documented in packet 07's PR body and is the canonical record.

### Operator-side cutover work

Packet 02 carries portal work (GitHub App creation) as Human Prerequisites. Packet 08 carries the Cloudflare Tunnel hostname removal, the ADR-0044 webhook-signing secret rotation, and the OpenClaw review-role disable as Human Prerequisites. All other packets are pure code/docs delegable to the agent.

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance/operator-script edits only (packets 01, 02, 03, 04, 07, 08, 10). The repo `CHANGELOG.md` is updated per repo convention on every packet.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; workflow/YAML/config edits (packets 05, 06). The repo `CHANGELOG.md` is updated per repo convention.
- **The 10 .NET Node repos in packet 09** — `.honeydrunk-review.yaml` and `pr-review.yml` are CI-config edits; per-Node CHANGELOG.md updated per repo convention. No NuGet package version bump (this is purely CI config).

## Rollback Plan

- **Packet 01 (acceptance):** revert the PR. ADR-0086 returns to Proposed; the supersession amendment notes are removed from ADR-0044 and ADR-0079; the initiative is unregistered. No runtime impact.
- **Packet 02 (GitHub App):** the operator removes the App installation from `HoneyDrunk.Architecture` via the org portal; deletes the three Vault secrets. The walkthrough doc remains as a historical record (or revert that PR too).
- **Packet 03 (worker):** revert the PR removes the worker source from `infrastructure/workers/grid-review-runner/`. On the home-server host, the operator runs the inverse of `Register-Task.ps1` (an `Unregister-Task.ps1` companion, or removes the Scheduled Task manually) to stop the worker. The repo carries no compiled code, so revert is clean.
- **Packet 04 (schema doc):** revert the PR. The schema doc returns to its pre-ADR-0086 shape.
- **Packet 05 (`job-review-request.yml` rewrite):** revert the PR restores the webhook-emitting form. Architecture's caller (packet 07) would then have to re-add the webhook inputs to function. **Note:** if packet 07 has already landed and Architecture's caller no longer passes the webhook inputs, the reverted workflow would skip the webhook-delivery step (`if: ... && inputs.openclaw-webhook-url != ''`) and just leave the artifact fallback — degrading gracefully to the old fallback path. Coordinated revert (07 + 05) returns to the prior state.
- **Packet 06 (labels):** revert the PR removes the four label definitions from the labels-as-code config. The labels stay on the repos until the operator manually deletes them — or simply lets them sit unused.
- **Packet 07 (Architecture cutover):** revert the PR returns Architecture's `.honeydrunk-review.yaml` to `runner: openclaw-codex` and restores the webhook inputs to the caller. The local worker stops being invoked on Architecture PRs. **This is the architectural escape hatch:** if Phase A reveals a fundamental problem with the local-worker substrate, flip Architecture back, re-evaluate, and re-scope. The OpenClaw bridge is still alive at this stage (packet 08 has not yet shipped) so falling back is clean.
- **Packet 08 (decommission):** revert the PR restores the supersession banner removal on the legacy doc. The operator-side work (Cloudflare hostname, secret rotation, OpenClaw process) is more durable — restoring those is operator portal work, recorded in the PR body for traceability.
- **Packet 09 (Phase B fan-out):** per-repo revert; each of the 10 PRs can be reverted independently. Per-repo `.honeydrunk-review.yaml` flips back to `enabled: false` or removed; the worker stops processing that repo. Per-repo control is the blast-radius mechanism.
- **Packet 10 (queue-depth surfacing):** revert the PR removes the narrative surfacing. No runtime impact.

**Architectural escape hatch:** at any phase, flipping `.honeydrunk-review.yaml` to `enabled: false` (or removing it) on any repo makes the worker go silent on that repo immediately. The phased rollout (D11) is itself the blast-radius control — each phase is a discrete go/no-go.

## Out-of-scope items from ADR-0086

- **Editing `.claude/agents/review.md`** — explicitly excluded by ADR-0086 D1 and Follow-up Work. The substrate change is invisible to the prompt.
- **Editing `constitution/invariants.md`** — explicitly excluded by ADR-0086's Invariants section. Reconciliation is `hive-sync`'s mandate per ADR-0014.
- **Editing `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md` D1 review-webhook-bridge bullet** — explicitly excluded by ADR-0086 Follow-up Work. The edit belongs to ADR-0081's own acceptance/amendment cycle (ADR-0081 is still Proposed).
- **A cloud queue (Azure Storage Queue / SQS) substitute for the GitHub-native queue** — ADR-0086 Alternatives Considered explicitly rejects this. The GitHub label + comment is sufficient at solo-dev volume; the cloud queue is a follow-up amendment if volume justifies it.
- **A self-hosted GitHub Actions runner** — ADR-0086 Alternatives Considered explicitly rejects this. The pull-worker is structurally simpler.
- **A separate review-log surface (S3 / Azure Blob) instead of PR comments** — ADR-0086 Alternatives Considered explicitly rejects this. The GitHub PR is the system of record per ADR-0011 D1.
- **`HoneyDrunk.Studios` (TypeScript) onboarding to the worker** — evaluated separately from the .NET-shaped fan-out (matches ADR-0044 packet 11 carve-out).
- **`HoneyDrunk.Vault.Rotation` onboarding** — its CI shape is non-canonical (`validate-pr.yml` instead of `pr.yml`); onboard when its CI conforms to the Grid convention (matches the ADR-0011 deferral note).
- **Reviewer 4 web-integration path** — ADR-0086 D8 explicitly rejects this for the Grid Review Runner's design. Reviewer 4 runs through the local worker today via Claude Code CLI under Max. If a future operator concern about model-substrate diversity emerges, it is re-evaluated then.

## Cross-Cutting — site sync

No site-sync flag. ADR-0086 is internal CI / operator-machine automation / governance — no Studios public-facing content changes.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

Packets land in the active folder; the file-packets pipeline files them in dependency order (the `dependencies:` array per packet drives the `addBlockedBy` graph; the pipeline files Wave 1's packet 01 first, then 02/04/05/06 in parallel, then 03 after 02, then 07 after 02/03/04/05/06; Wave 2 and Wave 3 file on subsequent pushes after their dependencies close).

## Archival

Per ADR-0008 D10, when every packet reaches `Done` on The Hive and all three phase exit criteria are met, the entire `active/adr-0086-pull-based-local-worker-grid-review/` folder moves to `archive/adr-0086-pull-based-local-worker-grid-review/` in a single commit. Polish-phase follow-up packets (e.g., the optional richer payload via workflow artifact mentioned in ADR-0086 D2; the optional off-hours cadence tuning in D4) live in a new initiative folder if they are scoped later — not appended here.
