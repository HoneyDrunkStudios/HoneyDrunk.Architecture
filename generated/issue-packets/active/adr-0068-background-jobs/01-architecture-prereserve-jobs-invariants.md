---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0068", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0068"]
wave: 1
initiative: adr-0068-background-jobs
node: honeydrunk-architecture
---

# Pre-reserve the four ADR-0068 background-jobs invariants in Proposed state

## Summary
Add four new invariants (numbered `{N1}`, `{N2}`, `{N3}`, `{N4}` — the next contiguous block of four reserved from `constitution/invariant-reservations.md`) to `constitution/invariants.md` as **Proposed invariants tied to ADR-0068**. Each invariant text is final; only the lifecycle marker ("Proposed; promoted on ADR-0068 acceptance per packet 05") differs from a regular invariant. Packet 05 (the ADR-0068 acceptance flip) removes the Proposed marker and finalizes the four invariants as Accepted in the same PR that flips the ADR header.

## Context
ADR-0068's Done-When list and the "If Accepted" follow-up checklist commit four new invariants — D6 (idempotency on every job), D7 (retry policy defaults / grandfather), D2 (in-Node `BackgroundService` substrate), D3 (cross-Node Container Apps Jobs substrate + naming). Per ADR-0068's "Catalog obligations" subsection: "constitution/invariants.md — append the new invariants listed above with sequential numbers at acceptance."

ADR-0068 stays **Proposed** through packets 00–04. The acceptance flip is packet 05's job. To avoid landing four already-Accepted-looking invariants while their ADR is still Proposed (a state-mismatch readers would find confusing), this packet records the four invariants in a **Proposed** state with an explicit marker — "Proposed; promoted on ADR-0068 acceptance per packet 05." Packet 05 removes the marker.

**Invariant numbers are claimed from `constitution/invariant-reservations.md` at packet-authoring time.** The executor reads that file, picks the next free contiguous block of four (size 4), adds a row to **Active Reservations** for ADR-0068 in the same PR that lands this packet, and uses those four numbers as `{N1}`/`{N2}`/`{N3}`/`{N4}` throughout this packet and the downstream packets (03 — Notify retry pump; 04 — Communications cadence Job) that reference them. If a collision is detected at merge time (another in-flight ADR's packet 00 lands first and claims overlapping numbers), the executor follows the "first merge wins" rule in `invariant-reservations.md` — shift this packet's block upward to the new "next free" and update every `{N*}` placeholder in this packet plus packets 03 and 04 in a follow-up commit before pushing.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `constitution/invariants.md` — add four new invariants in a new `## Background Job Invariants` section (or under an existing topic-section if one fits — see Proposed Implementation). Each invariant is tagged "Proposed; promoted on ADR-0068 acceptance per packet 05."

## Proposed Implementation
1. **Read `constitution/invariant-reservations.md`** to determine the next free contiguous block of four (`{N1}`/`{N2}`/`{N3}`/`{N4}`). At packet-authoring time, the reservation registry's next-free pointer named ADR-0068's block as **83/84/85/86**; the executor reconfirms at execution time and uses whatever block the registry resolves to (the first-merge-wins rule may have shifted the block upward). Add an "Active Reservations" row for ADR-0068 in the same PR that lands this packet.
2. **Create a `## Background Job Invariants` section** in `constitution/invariants.md` (place it after the most recent topic-section — likely after `## Audit Invariants`, parallel to the precedent in ADR-0042's packet 00 which created `## Idempotency Invariants`).
3. **Add four invariants in order, numbered `{N1}`/`{N2}`/`{N3}`/`{N4}`** from the reservation block claimed in step 1:
   - **`{N1}` — In-Node background processing uses `IHostedService` / `BackgroundService`.** Every Node that needs in-process recurring or background work uses the BCL `IHostedService` interface (typically via the `BackgroundService` base class) registered with `services.AddHostedService<T>()`. Third-party in-process schedulers (Quartz, Hangfire, and equivalents) are forbidden in Node host processes without a follow-up ADR that justifies the dependency. `BackgroundService` instances read wall-clock time via `TimeProvider` (ADR-0063 D1) and use ISO 8601 duration strings for any backoff/interval configuration (ADR-0063 D6). See ADR-0068 D2.
   - **`{N2}` — Cross-Node recurring orchestration uses Azure Container Apps Jobs.** Every cross-Node recurring or event-triggered job (cron-scheduled or KEDA-scaler-triggered) runs on Azure Container Apps Jobs, deployed via the reusable `job-deploy-container-apps-job.yml` workflow in `HoneyDrunk.Actions`. New cross-Node recurring work on Azure Functions timer triggers is forbidden; existing Functions-based jobs (Vault.Rotation per ADR-0006 Tier 2) are grandfathered per ADR-0068 D7 until a natural migration moment. Container Apps Jobs follow the naming convention `caj-hd-{service}-{env}` — the Jobs-shaped sibling of invariant 34's `ca-hd-{service}-{env}`; the 13-character service-name limit (invariant 19) applies the same way. Cron strings are 5-field UTC per ADR-0063 D6. See ADR-0068 D3, D7.
   - **`{N3}` — Every state-mutating job is idempotent.** Every job — in-Node `BackgroundService` or cross-Node Container Apps Job — that mutates state must be idempotent. Schedule-triggered jobs use the deterministic idempotency key `${jobName}:${scheduledInstant:yyyyMMddTHHmmssZ}` against `IIdempotencyStore` (ADR-0042); event-triggered (KEDA) jobs derive their key from the trigger event (Service Bus `MessageId` or Event Grid event ID, salted with the job name). Read-only jobs (status probes, health checks) are exempt because re-execution is harmless. The canary surface for jobs idempotency is part of ADR-0042's canary obligations — no separate canary in ADR-0068. See ADR-0068 D6.
   - **`{N4}` — Job failure emits Audit and Pulse signals on the documented schedule.** Every job emits a Pulse `jobs.outcome` counter (tags `{job_name, outcome=success|retry|fail}`) and a Pulse `jobs.duration` histogram (tags `{job_name}`) via the existing Kernel `ITelemetryActivityFactory` plumbing. Job lifecycle (start, end, retry attempt) is a span on the Pulse trace pipeline with the job's `correlationId` propagated to every downstream call (invariant 6). Jobs running longer than 60 seconds emit progress to `IAuditLog` as a `JobProgress` audit-category entry (ADR-0030). Final-failure jobs raise an error via `IErrorReporter` (ADR-0045) carrying the final-failure stack trace, retry count, and correlation ID, and emit a `JobFailure` audit-category `AuditEntry` (ADR-0030) carrying job name, scheduled instant, retry count, and last exception summary. See ADR-0068 D8.
4. **Tag each as Proposed.** Append to each invariant the marker: *"**Status:** Proposed (tied to ADR-0068); promoted on ADR-0068 acceptance per packet 05 of `adr-0068-background-jobs`."*
5. **No other change** in this packet (besides the reservation-registry row in step 1). Existing invariants are untouched; their numbers are not renumbered.

## Affected Files
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (Active Reservations row added — block of four claimed)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule maps exactly.
- [x] No code change in any other repo.
- [x] No catalog file modified — D4's "no `honeydrunk-jobs` entry" stays honored.
- [x] No existing invariant renumbered or reworded.

## Acceptance Criteria
- [ ] `constitution/invariant-reservations.md` has a new row under **Active Reservations** for ADR-0068 claiming the next free block of four (`{N1}`–`{N4}`); the registry's "Current ceiling" / next-free pointer advances accordingly
- [ ] `constitution/invariants.md` contains four new invariants in a new `## Background Job Invariants` section (or appropriate existing section), numbered with the `{N1}`/`{N2}`/`{N3}`/`{N4}` block claimed in the reservation-registry row above
- [ ] Each of the four invariants carries the explicit `**Status:** Proposed (tied to ADR-0068); promoted on ADR-0068 acceptance per packet 05` marker
- [ ] Invariant `{N1}` (in-Node `BackgroundService`) names Quartz, Hangfire, and equivalents as forbidden without a follow-up ADR; cites ADR-0068 D2 and ADR-0063 D1/D6
- [ ] Invariant `{N2}` (cross-Node Container Apps Jobs) names the Functions-timer prohibition (with the Vault.Rotation grandfather), the `caj-hd-{service}-{env}` naming convention, the 13-char service-name limit (invariant 19), and the ADR-0063 D6 cron format
- [ ] Invariant `{N3}` (idempotency on every state-mutating job) references `IIdempotencyStore` (ADR-0042), names the deterministic schedule key and the KEDA event-derived key, and exempts read-only jobs
- [ ] Invariant `{N4}` (job observability) names the two Pulse signals (`jobs.outcome`, `jobs.duration`), the lifecycle traces with `correlationId` (invariant 6), the long-running-progress `JobProgress` audit category (ADR-0030), and the final-failure `IErrorReporter` + `JobFailure` audit pair (ADR-0045 + ADR-0030)
- [ ] Downstream packets 03 (Notify retry pump) and 04 (Communications cadence Job) have any `{N1}`/`{N2}`/`{N3}`/`{N4}` placeholders resolved to the same final block numbers chosen here (if numbers shifted at merge time, both packets are updated in the same follow-up commit)
- [ ] No existing invariant is renumbered, reworded, or moved
- [ ] No other file is modified

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0068 D2 — In-Node `BackgroundService`.** "Every Node that needs in-process recurring or background work uses ASP.NET Core's built-in `IHostedService` interface (typically via the `BackgroundService` base class). No Quartz, no Hangfire, no third-party scheduler dependency." Time substrate is `TimeProvider` per ADR-0063 D1.

**ADR-0068 D3 — Cross-Node Container Apps Jobs.** "Every cross-Node recurring or event-driven job runs on Azure Container Apps Jobs." Naming: `caj-hd-{service}-{env}`. Cron 5-field UTC per ADR-0063 D6.

**ADR-0068 D6 — Idempotency on every job.** "Every job (in-Node `BackgroundService` or cross-Node Container Apps Job) must be idempotent. Re-execution is a normal failure mode." Schedule key `${jobName}:${scheduledInstant:yyyyMMddTHHmmssZ}`; KEDA event-derived key from `MessageId` / event ID + job-name salt. Uses ADR-0042's `IIdempotencyStore`.

**ADR-0068 D7 — Retry policy and Vault.Rotation grandfather.** Container Apps Jobs default: 3 retries, exponential 1m / 5m / 25m; per-job override allowed. Final failure emits `JobFailure` audit entry (ADR-0030) and raises error (ADR-0045). Vault.Rotation grandfathered.

**ADR-0068 D8 — Observability.** Two Pulse signals (`jobs.outcome` counter, `jobs.duration` histogram); lifecycle traces with propagated `correlationId` per invariant 6; long-running (>60s) progress to Audit as `JobProgress`; final failure to `IErrorReporter` per ADR-0045.

**ADR-0068 "If Accepted" follow-up — invariant promotion.** "Promote D6 (idempotency on every job), D7 (retry policy defaults), and D8 (observability) into numbered invariants once Accepted — scope agent assigns invariant numbers in the same PR that flips Status." This packet records them as Proposed; packet 05 promotes.

## Constraints
- **Numbers `{N1}`/`{N2}`/`{N3}`/`{N4}` are claimed from `constitution/invariant-reservations.md`** at packet-authoring/execution time. The reservation registry's "first merge wins" rule (per the file's own documentation) governs any collision: if another in-flight ADR's packet 00 merges first and lands on overlapping numbers, the executor shifts ADR-0068's block upward to the new "next free," updates the reservation-registry row, and updates every `{N*}` placeholder in this packet plus packets 03 (Notify retry pump) and 04 (Communications cadence Job) in a follow-up commit before pushing. Record the resolution in the PR description so packet 05 can locate the right numbers for promotion. **Do not hardcode 75/76/77/78** — the original draft of this packet used those numbers, but they collided with the ADR-0042/0045 batch and were replaced with placeholders.
- **Proposed marker is mandatory.** Each invariant carries the explicit `**Status:** Proposed (tied to ADR-0068); promoted on ADR-0068 acceptance per packet 05 of `adr-0068-background-jobs`` marker. Without the marker a reader cannot tell whether the rule is in force.
- **No existing invariant is renumbered or reworded.** This is an append-only edit. Existing numbering is sacrosanct.
- **New section is preferred.** `## Background Job Invariants` is the parallel to ADR-0042 packet 00's `## Idempotency Invariants`. If editorial judgment puts the four under an existing section (e.g. Ops), record the rationale in the PR description.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0068`, `wave-1`

## Agent Handoff

**Objective:** Pre-reserve ADR-0068's four invariants in `constitution/invariants.md` as Proposed, ready to be promoted to Accepted in packet 05.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Capture the rule text now (so packets 02–04 reference real invariants), while preserving the ADR's lifecycle (ADR stays Proposed until packet 05).
- Feature: ADR-0068 Background Job and Recurring Work Substrate rollout, Wave 1.
- ADRs: ADR-0068 D2/D3/D6/D7/D8 (primary), ADR-0042 (`IIdempotencyStore`), ADR-0063 (cron + `TimeProvider`), ADR-0030 (Audit categories), ADR-0045 (`IErrorReporter`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — the catalog/reference updates land first so the invariants reference an editorially-consistent context.

**Constraints:**
- Numbers `{N1}`/`{N2}`/`{N3}`/`{N4}` are claimed from `constitution/invariant-reservations.md` at execution time; first-merge-wins per the registry's documented rule. Update placeholders consistently across packets 01, 03, and 04 once the block is resolved.
- Proposed marker is mandatory on each invariant.
- No existing invariant is renumbered or reworded — append-only edit.

**Key Files:**
- `constitution/invariant-reservations.md` — claim the next-free block of four; add the Active Reservations row.
- `constitution/invariants.md` — new `## Background Job Invariants` section.

**Contracts:** None changed.
