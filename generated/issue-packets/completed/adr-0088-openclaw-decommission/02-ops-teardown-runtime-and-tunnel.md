---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "infrastructure", "human-only", "adr-0088", "wave-2"]
dependencies: ["packet:00", "packet:00a"]
adrs: ["ADR-0088", "ADR-0086", "ADR-0081"]
accepts: []
wave: 2
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Operator teardown — remove OpenClaw runtime, the webhook bridge, and the OpenClaw-bound tunnel

## Summary
Operator/human chore: on the home server, disable and remove OpenClaw Gateway and the Honeyclaw runtime, stop all OpenClaw scheduled jobs / cron / `agentTurn` schedules, remove the ADR-0044 webhook-bridge process and its receiver config, and remove the OpenClaw-bound Cloudflare Tunnel hostname (`grid-review.honeydrunkstudios.com` or equivalent) and the tunnel route that forwarded to the webhook bridge. The home server itself is retained (it remains the ADR-0086 runner host); tunnels and routes for any other workload are unaffected. **No org secret is deleted in this packet** — that is packet 03, and it depends on this teardown completing first. The teardown work is operator-only (agents cannot stop processes or edit Cloudflare on the home server); the durable record lands as an Architecture CHANGELOG entry / PR-body checklist.

## Context
ADR-0088 D3 Group 2, steps 2–4:

> 2. Disable and remove OpenClaw Gateway and the Honeyclaw runtime on the home server (and on the workstation if still present). Stop all OpenClaw scheduled jobs / cron / `agentTurn` schedules.
> 3. Remove the ADR-0044 webhook bridge process and its receiver config on the home server.
> 4. Remove the **OpenClaw-bound Cloudflare Tunnel** pieces — the `grid-review.honeydrunkstudios.com` (or equivalent) hostname and the tunnel route that forwarded to the webhook bridge. Tunnels and routes for any other workload are **unaffected**.

Per ADR-0088 D5, this entire group is **fully reversible**: OpenClaw can be reinstalled, the bridge restarted, the tunnel hostname re-created. The org secret still exists at this stage, so signature verification would resume. Abort cost: re-standing the OpenClaw runtime. The point of no return is the *next* group (secret deletion, packet 03), which is why packet 03 is blocked-by this packet — the bridge the secret signed must be gone before the secret is deleted, so deletion is clean.

The **D5 abort gate** (Group 1 prerequisite) governs which OpenClaw schedules may be stopped: a workload's OpenClaw schedule is disabled only after its ADR-0086 runner replacement has a smoke-test record (confirmed in packet 00's gate). If any replacement is unproven, that workload's OpenClaw schedule keeps running and this packet does not stop it. **docs-sync specifically:** its OpenClaw schedule is stopped only once packet **00a** (the committed `docs-sync` job spec on the ADR-0086 worker) is Done — this packet is **blocked-by packet 00a** for that reason, so docs-sync is never stranded with no scheduler. The operator chose to keep docs-sync automated (not manual-floor), so the worker's Friday schedule must be in place before OpenClaw's docs-sync trigger is removed.

This is `Actor=Human` — the entire work item is operator portal/SSH/Cloudflare work that cannot be delegated to an agent. The agent's only role is to author the CHANGELOG/PR-body record once the operator confirms completion.

## Scope (operator actions — all in Human Prerequisites)
- Home server: disable + remove OpenClaw Gateway and Honeyclaw runtime; stop all OpenClaw cron / `agentTurn` / poll schedules whose ADR-0086 replacement is proven. **docs-sync's OpenClaw schedule is stopped only after packet 00a is Done** (its replacement scheduler — the `docs-sync` job spec on the ADR-0086 worker — exists).
- Home server: remove the ADR-0044 webhook-bridge process and its receiver config (the receiver that verified `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` signatures).
- Cloudflare: remove the OpenClaw-bound tunnel hostname (`grid-review.honeydrunkstudios.com` — verify against `infrastructure/reference/owned-domains.md` and ADR-0081 D6) and the route to the webhook bridge. Leave every other tunnel host and route untouched.
- Workstation (if OpenClaw is still present there): same disable/remove.

## Repo-side record (the agent's work)
- `CHANGELOG.md` — record the Group-2 teardown: OpenClaw Gateway/Honeyclaw removed, webhook bridge removed, OpenClaw-bound tunnel hostname + route removed, home server retained, non-OpenClaw tunnels untouched, with timestamps.
- **`infrastructure/reference/owned-domains.md` — MANDATORY edit.** Lines 11 and 26 name `grid-review.honeydrunkstudios.com` as the Cloudflare Tunnel endpoint for the ADR-0044 Grid Review webhook. Once the tunnel hostname and route are torn down (above), this doc must not keep implying a live tunnel endpoint. Update both references: line 26 (`Use grid-review.honeydrunkstudios.com for the Cloudflare Tunnel endpoint...`) must be past-tensed/annotated as retired per ADR-0088, and line 11's "Candidate parent for ADR-0044 Grid Review webhook, e.g. `grid-review.honeydrunkstudios.com`" reconciled to note the tunnel was decommissioned (the review transport is the ADR-0086 pull-based worker, which needs no inbound tunnel). This is not optional — leaving it asserts a live tunnel hostname that was just torn down.

## Boundary Check
- [x] Operator action on operator-owned home server + Cloudflare; the record lands in `HoneyDrunk.Architecture`.
- [x] No code change in any repo.
- [x] **No org secret deleted here** — that is packet 03 (blocked-by this packet).
- [x] The home server is NOT decommissioned (ADR-0088 D1 / Alternatives Considered — it remains the ADR-0086 runner host).
- [x] Non-OpenClaw tunnels, routes, and schedules are untouched (ADR-0088 D3 step 4 scoping).
- [x] No GitHub App or App private key touched (none is OpenClaw's; `honeydrunk-grid-review` is the retained worker identity).

## Acceptance Criteria
- [ ] OpenClaw Gateway and Honeyclaw runtime are disabled and removed on the home server (and the workstation if present), confirmed by the operator
- [ ] All OpenClaw scheduled jobs / cron / `agentTurn` schedules whose ADR-0086 replacement is proven are stopped; any whose replacement is unproven are explicitly left running and noted (D5 abort gate). **docs-sync's OpenClaw schedule is stopped only after packet 00a is confirmed Done** (its `docs-sync` job spec is live on the ADR-0086 worker)
- [ ] The ADR-0044 webhook-bridge process and its receiver config are removed from the home server
- [ ] The OpenClaw-bound Cloudflare Tunnel hostname (`grid-review.honeydrunkstudios.com` or equivalent) and its route to the webhook bridge are removed; all other tunnel hosts/routes verified untouched
- [ ] The home server itself is retained and the ADR-0086 runner (`grid-agent-runner`) is confirmed still operating
- [ ] No org secret is deleted in this packet (that is packet 03)
- [ ] `CHANGELOG.md` records the Group-2 teardown with timestamps
- [ ] `infrastructure/reference/owned-domains.md` lines 11 and 26 are reconciled (MANDATORY) — the `grid-review.honeydrunkstudios.com` Cloudflare Tunnel endpoint is past-tensed/annotated as retired per ADR-0088; no live-tense claim of a tunnel hostname remains
- [ ] The PR/issue body carries the operator's completion checklist (each action + timestamp) as the audit record

## Human Prerequisites
- [ ] **Packet 00 (acceptance) merged and the D3 Group-1 prerequisite confirmed green.** Do not start this teardown for any workload whose ADR-0086 replacement is not yet proven (D5 abort gate).
- [ ] **Packet 00a (the `docs-sync` job spec) Done before stopping docs-sync's OpenClaw schedule.** The committed `docs-sync` job spec on the ADR-0086 worker must be live (validated + smoke-recorded) before OpenClaw's docs-sync trigger is removed — otherwise docs-sync is stranded with no scheduler. The rest of the teardown (gateway, bridge, tunnel, other proven schedules) may proceed once packet 00 is green; only the docs-sync schedule is additionally gated on 00a.
- [ ] **Disable and remove OpenClaw Gateway + Honeyclaw runtime** on the home server (and workstation if present). Stop the gateway process, remove its service/daemon registration, and uninstall the runtime.
- [ ] **Stop all OpenClaw scheduled jobs / cron / `agentTurn` schedules** whose ADR-0086 runner replacement is proven (per packet 00's gate). For any workload whose replacement is unproven, leave its schedule running and record that exception. For **docs-sync**, confirm packet 00a is Done (its job spec is live on the worker) before stopping its OpenClaw schedule.
- [ ] **Remove the ADR-0044 webhook-bridge process and receiver config.** This is the receiver that verified `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` signatures. Stop the process, remove its service registration and config file.
- [ ] **Remove the OpenClaw-bound Cloudflare Tunnel hostname and route.** Hostname is `grid-review.honeydrunkstudios.com` per ADR-0081 D6 — verify against `infrastructure/reference/owned-domains.md` and the Cloudflare portal. Remove only this hostname and the route that forwarded to the webhook bridge; leave every other tunnel host and route alone.
- [ ] **Confirm the home server and the ADR-0086 runner are unaffected.** The machine stays; `grid-agent-runner` keeps running. Verify the runner's scheduled tasks still fire after the OpenClaw removal.
- [ ] **Record the completion checklist in this packet's PR/issue body** (each action + timestamp). The record is the audit trail; this packet's repo-side deliverables are the CHANGELOG entry **and the mandatory `infrastructure/reference/owned-domains.md` reconciliation** (lines 11 + 26 — the tunnel endpoint is past-tensed/retired per ADR-0088 once the operator confirms the hostname/route are gone).

## Dependencies
- `packet:00` — ADR-0088 acceptance (the teardown decision must be live).
- `packet:00a` — the committed `docs-sync` job spec on the ADR-0086 worker (so stopping docs-sync's OpenClaw schedule does not strand it with no scheduler).

## Referenced ADR Decisions
**ADR-0088 D3 Group 2 (steps 2–4) — Remove OpenClaw runtime and transport (no secret deletion yet).** Disable/remove OpenClaw Gateway + Honeyclaw; stop OpenClaw schedules; remove the webhook bridge + receiver config; remove the OpenClaw-bound Cloudflare Tunnel hostname + route. Other workloads' tunnels/routes/schedules unaffected.

**ADR-0088 D5 — Rollback / abort.** Group 2 is fully reversible. The point of no return is Group 3's secret deletion (packet 03). The abort gate: if any OpenClaw workload's ADR-0086 replacement is not yet proven, the teardown halts before Group 2 for that workload.

**ADR-0088 D1 / Alternatives Considered — Decommission the home server too: rejected.** OpenClaw ran *on* the home server; retiring OpenClaw does not retire the machine. The home server is the ADR-0086 runner host.

## Constraints
- **No secret deletion here.** The org secret is deleted in packet 03, which is blocked-by this packet. The bridge the secret signed must be gone first so deletion is clean (D5).
- **Surgical tunnel removal.** Remove only the OpenClaw review-traffic hostname and its route; every other tunnel host/route stays.
- **The home server is retained.** Do not decommission the machine; verify the ADR-0086 runner keeps operating after the OpenClaw removal.
- **Respect the abort gate.** Only stop an OpenClaw schedule whose ADR-0086 replacement is proven (packet 00's gate). Leave unproven-replacement workloads running and record the exception.
- **No GitHub App touched.** `honeydrunk-grid-review` is the retained ADR-0086 worker identity; no OpenClaw App exists.
- **Invariant 8 (referenced):** *Secret values never appear in logs, traces, exceptions, or telemetry.* The completion checklist records the hostname and the secret *name* and timestamps only — never the secret value.

## Labels
`chore`, `tier-2`, `meta`, `ops`, `infrastructure`, `human-only`, `adr-0088`, `wave-2`

## Agent Handoff

**Objective (Actor=Human):** This is an operator chore. Disable/remove OpenClaw Gateway + Honeyclaw, the ADR-0044 webhook bridge, and the OpenClaw-bound Cloudflare Tunnel hostname/route on the home server. Retain the home server and the ADR-0086 runner. Record completion in the Architecture CHANGELOG/PR body. No org secret is deleted here.

**Target:** Operator home server + Cloudflare; record in `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Complete D3 Group 2 — remove the OpenClaw runtime and transport before the secret is deleted (Group 3).
- Feature: ADR-0088 OpenClaw decommission, Wave 2 (D3 Group 2).
- ADRs: ADR-0088 (primary, D3 Group 2 + D5), ADR-0086 (runner is retained), ADR-0081 (home server retained, premise re-homed).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0088 acceptance.
- `packet:00a` — the committed `docs-sync` job spec (stopping docs-sync's OpenClaw schedule is gated on it).

**Constraints:**
- No secret deletion here (packet 03 owns that, blocked-by this packet).
- docs-sync's OpenClaw schedule is stopped only after packet 00a is Done (its replacement scheduler exists).
- Surgical tunnel removal (only the review-traffic hostname/route).
- Home server retained; ADR-0086 runner must keep operating.
- Respect the D5 abort gate — only stop schedules whose replacement is proven.
- No GitHub App touched.

**Key Files:**
- `CHANGELOG.md` (the teardown record)
- `infrastructure/reference/owned-domains.md` (MANDATORY — lines 11 + 26 reconcile the `grid-review.honeydrunkstudios.com` tunnel endpoint to retired)

**Contracts:** None.
