# ADR-0081: Home Server for OpenClaw and Local Agent Infrastructure

**Status:** Proposed
**Date:** 2026-05-24
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / Ops / AI

## Context

HoneyDrunk's local automation footprint is no longer just a workstation convenience. The Grid now has several always-on or near-always-on local responsibilities:

- OpenClaw Gateway and Honeyclaw sessions.
- ADR-0044 Grid Review Runner webhook handling and PR review execution.
- Cloudflare Tunnel for inbound webhook delivery.
- Scheduled Lore sourcing and signal review jobs.
- Background agent workflows, child sessions, and local worktree operations.
- Future experiments with local agents, local tool execution, and possibly small local models.

Running these on the operator's primary workstation is acceptable for prototyping, but it has obvious operational limits:

- The workstation sleeps, reboots, travels, and gets used interactively.
- Webhooks fail when the machine, tunnel, bridge, or OpenClaw process is down.
- Long-running agent work competes with normal development workloads.
- Security boundaries are blurrier when public tunnel termination, personal files, dev tooling, and always-on automation all share the same interactive machine.

ADR-0044's webhook-first direction makes this sharper. A Cloudflare Tunnel can safely expose a narrow local webhook bridge, but the bridge still needs a stable local host. The question is whether HoneyDrunk should invest in a small always-on home server as the local automation substrate.

## Decision

HoneyDrunk will introduce a small always-on **home server** as the preferred host for OpenClaw, webhook bridges, scheduled local automations, and local-agent experimentation.

This server is **not** a production application host for public HoneyDrunk customer-facing Nodes. Public/runtime products remain on their chosen cloud hosts (Azure Container Apps/App Service/Functions, Vercel, etc.). The home server is an **operator-owned local control-plane host** for development automation, review automation, and agent infrastructure.

## Decisions

### D1 - Home server is the always-on local automation host

The home server owns workloads that need to survive workstation sleep/restarts:

- OpenClaw Gateway and Honeyclaw runtime state.
- ADR-0044 webhook bridge and Cloudflare Tunnel process.
- Scheduled local automation jobs where local context/tools matter.
- Local agent sandboxes, worktrees, and experimental runtimes.
- Lightweight observability/log capture for local automation.

The workstation remains the primary interactive development machine. It can still run OpenClaw during transition, but it is not the target steady-state host.

### D2 - No public router/firewall exposure

The home server must not require inbound router port-forwarding. Public ingress uses Cloudflare Tunnel or a similarly narrow, authenticated tunnel.

Rules:

- Expose only specific webhook/application paths, never the whole machine.
- Do not tunnel the OpenClaw dashboard/gateway wholesale.
- Prefer one tiny local bridge per public integration.
- Every inbound integration verifies an application-layer secret/signature before triggering work.

For ADR-0044 specifically, GitHub posts to a Cloudflare Tunnel hostname, the tunnel forwards to a local webhook bridge, and the bridge verifies the signed payload before invoking OpenClaw locally.

### D3 - Hardware target favors boring reliability over homelab complexity

The first home server should be a boring low-power mini PC, not a rack/homelab project.

Minimum target:

- Modern low-power x86 CPU with virtualization support (Intel N100/N150 class or better; i3/i5-class preferred if budget allows).
- 32 GB RAM minimum; 64 GB preferred for local agent concurrency and container headroom.
- 1 TB NVMe minimum; 2 TB preferred.
- Wired Ethernet.
- Quiet/low-power enough to run continuously.
- External backup drive or NAS target for backup.

A UPS is recommended once the box becomes relied upon for webhooks/scheduled automation.

### D4 - Local agents are in scope; local model hosting is optional

The server should support **local agent execution**: OpenClaw sessions, CLI agents, isolated worktrees, Docker/containerized tools, and long-running automation.

Running large local LLMs is **not** a Phase 1 requirement. Cloud/subscription-backed models remain the default for serious review and coding work. The box may experiment with small local models, but buying GPU-class hardware is deferred until there is a concrete local-model use case.

If local LLM hosting becomes a real requirement, it gets a follow-up decision: either a GPU-capable workstation/server, an eGPU path, or a separate inference box. Do not overbuy the first server for speculative GPU needs.

### D5 - Security posture is least-privilege and recoverable

The server must be treated as infrastructure, not a casual desktop:

- Dedicated OS user/service accounts for long-running automation where practical.
- Secrets stored in OS credential storage, OpenClaw config secrets, or Vault-backed mechanisms; never committed to repo files.
- Cloudflare Tunnel credentials protected as machine secrets.
- GitHub tokens scoped to required repos/actions only.
- Automatic OS/package updates configured conservatively.
- Regular backup of OpenClaw state, config, and durable automation metadata.
- No autonomous destructive or external actions beyond the same review/approval rules that apply on the workstation.

### D6 - Migration is incremental

The workstation setup remains valid until the home server is ready. Migration order:

1. Stand up server OS and basic hardening.
2. Install OpenClaw, Git, Node/.NET/Python toolchains as needed.
3. Move Cloudflare Tunnel and ADR-0044 webhook bridge.
4. Verify ADR-0044 webhook delivery on one Architecture PR.
5. Move scheduled jobs one at a time.
6. Only then disable workstation cron/poll fallbacks that the server replaces.

## Consequences

### Positive

- Webhooks and scheduled jobs become reliable independent of workstation state.
- OpenClaw and local agents get a stable always-on home.
- The workstation can sleep/reboot without breaking Grid automation.
- Cloudflare Tunnel exposure stays narrow and does not require router port-forwarding.
- Local agent experimentation has a dedicated sandbox and resource envelope.

### Negative

- Adds a machine to maintain: updates, backups, monitoring, physical power/network reliability.
- Adds modest hardware cost and power draw.
- Creates a new security surface that must be treated seriously.
- Does not eliminate the need for cloud hosting for public production Nodes.

### Neutral / Follow-up

- GPU/local-LLM hosting remains deferred until justified by a concrete workload.
- A future cloud relay may still be useful if OpenClaw needs webhook durability when the home server is offline.
- A future ADR may define a broader local-infrastructure backup/DR policy if the server becomes mission-critical.

## Alternatives Considered

### Keep everything on the workstation

Rejected as steady-state. Good for prototyping, but fragile for webhooks and scheduled automation because the workstation sleeps, reboots, travels, and competes with interactive work.

### Run OpenClaw and webhook bridge on a cloud VM

Deferred. A cloud VM improves availability but introduces recurring cost, cloud hardening work, and a broader remote-administration surface. The immediate need is local automation with local tooling and low operational burden.

### Buy a GPU workstation/server now

Rejected for Phase 1. Local model hosting is interesting but not yet a hard requirement. A low-power mini server handles OpenClaw, webhook bridge, cron, and local-agent orchestration without overfitting to speculative inference workloads.

### Use only Cloudflare Worker/Azure Function relay

Deferred. A relay can improve webhook durability, but it does not solve local agent/tool execution by itself. The home server is still useful as the local execution substrate.

## Implementation Notes

Initial candidate workload set:

- OpenClaw Gateway.
- Cloudflare Tunnel for `grid-review.honeydrunkstudios.com`.
- ADR-0044 Grid Review webhook bridge.
- Lore scheduled sourcing/signal review jobs if they need local repo/filesystem access.
- Agent sandbox/worktree root for local experiments.

Initial excluded workload set:

- Customer-facing production APIs.
- Revenue-node hosting.
- Public dashboards without Cloudflare Access or equivalent protection.
- Unbounded autonomous agent loops.

## Acceptance Criteria

This ADR is ready to accept when:

- Hardware target and budget are confirmed.
- OS choice is confirmed.
- Cloudflare Tunnel + OpenClaw bridge migration plan is documented.
- Backup plan for OpenClaw state/config is documented.
- Security checklist exists for the server before exposing any tunnel-backed endpoint.
