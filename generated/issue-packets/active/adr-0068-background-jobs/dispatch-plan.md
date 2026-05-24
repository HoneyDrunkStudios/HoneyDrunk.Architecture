# Dispatch Plan — ADR-0068: Background Job and Recurring Work Substrate

**Initiative:** `adr-0068-background-jobs`
**ADR:** ADR-0068 (Proposed → Accepted via packet 05, at the end — see Acceptance Flow below)
**Sector:** Core / Ops · cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0068 settles the Grid's response to a planned-but-never-built `HoneyDrunk.Jobs` Node and seven workloads (existing and imminent) running on three different ad-hoc substrates. The decision is three-prong: CI/CD ops cron stays on GitHub Actions (out of scope); in-Node background work uses `IHostedService` / `BackgroundService` (D2); cross-Node recurring orchestration uses Azure Container Apps Jobs (D3). The `HoneyDrunk.Jobs` Node is deferred indefinitely — Container Apps Jobs subsumes its role (D4). Vault.Rotation's Azure Functions timer triggers are grandfathered (D7). Idempotency on every state-mutating job is mandatory (D6), routing through the ADR-0042 store. Cron format and clock substrate cross-reference ADR-0063.

This initiative delivers: catalog/governance updates that reflect the Jobs deferral and the two pinned substrates (Architecture); the `job-deploy-container-apps-job.yml` reusable workflow in HoneyDrunk.Actions; the **Notify retry pump** as the first in-Node `BackgroundService` under this ADR (D2's first consumer per D11); the **Communications cadence/drip-campaign scheduler** as the first cross-Node Container Apps Job under this ADR (D3's first consumer per D11); and the acceptance flip after both first-consumer packets ship.

**6 packets across 4 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`, `HoneyDrunk.Notify`, `HoneyDrunk.Communications`). All 6 are `Actor=Agent`, 0 `Actor=Human`. Several packets carry Human Prerequisites: portal-side Container Apps Jobs provisioning, KEDA scaler wiring, and the human git-tag/release of any upstream NuGet packages whose new versions ship in this initiative.

## Trigger

ADR-0068 is Proposed with no scope. Forcing functions from the ADR's Context: **ADR-0019 Communications cadence rules** are the next workload to land and need a scheduling substrate; **ADR-0027 Notify Cloud retries** need a retry substrate (in-Node `BackgroundService` is the strong candidate but uncommitted); **ADR-0015** pinned Container Apps as the deployable platform, and Container Apps Jobs is the Jobs-shaped sibling already on that platform; **ADR-0063** (paired, also Proposed) pins cron format and clock substrate. Without an ADR, the next consumer (Communications cadence is imminent) picks a fourth substrate unilaterally and the Grid drifts further. The ADR needs decomposition into actionable packets — and per its own Done-When list, acceptance gates on the deploy workflow landing and the first job under the new substrate shipping.

## Scope Detection

**Multi-repo, multi-Node.** The decisions land in `HoneyDrunk.Architecture` (acceptance, four invariants, catalog/reference updates per the ADR's follow-up checklist), `HoneyDrunk.Actions` (the new reusable workflow per the follow-up checklist and ADR-0012's CI/CD-control-plane mandate), `HoneyDrunk.Notify` (first in-Node `BackgroundService` per D2/D11 — the retry pump), and `HoneyDrunk.Communications` (first cross-Node Container Apps Job per D3/D11 — cadence/drip-campaign scheduling).

**No new-Node scaffolding.** The ADR's D4 explicitly defers `HoneyDrunk.Jobs`; this initiative removes the planned-Node slot from the catalog/roadmap and does not stand up any new Node. Every target repo is a live, scaffolded Node.

**No new contract surface in Kernel.Abstractions.** D2/D3 reuse BCL types (`BackgroundService`, `IHostedService`, `TimeProvider`) and platform manifests (Container Apps Jobs YAML/Bicep); ADR-0068 Catalog obligations: "no entry. The contract surface (cron strings, `BackgroundService` shape, Container Apps Jobs deploy manifest) is platform/BCL types; nothing HoneyDrunk-owned to register." This initiative therefore carries no Kernel/Abstractions packet.

## Cross-Dependency with ADR-0063 (Clock Policy)

ADR-0068 D5 explicitly cross-references ADR-0063 for cron format (5-field UTC), clock substrate (`TimeProvider`), test seam (`FakeTimeProvider`), and duration shape (ISO 8601 strings). ADR-0063 is **Proposed**, not Accepted, and ADR-0068's Done-When list names "ADR-0063 is Accepted" as a paired prerequisite.

**Posture for this initiative:** ADR-0068 packets reference ADR-0063 decisions inline (the rule text is summarized in each packet's Constraints/Referenced ADR Decisions) so executors don't need to read ADR-0063 to act. The two ADRs were authored as a paired set; in practice ADR-0063's scoping should happen first or in parallel so its acceptance lands before ADR-0068 packet 05 (the acceptance flip).

**Soft dependency, not a hard blocker for the Wave 1–3 work** — packets 00–04 land regardless of ADR-0063's exact filing order, because their cron/`TimeProvider`/ISO-8601-duration rules are reproduced from ADR-0063 inline. Packet 05 (acceptance flip) should be the final step and is gated behind ADR-0063 acceptance per the Done-When list — see Acceptance Flow.

## Acceptance Flow — flip is at the END, not the start

ADR-0068's "If Accepted" follow-up checklist names: "Scope agent flips Status → Accepted **after the deploy workflow lands and the first job migrated (or stood-up) under the new substrate**." This is the opposite of the more typical ADR-acceptance-first pattern (e.g. ADR-0042, ADR-0045). The packet order reflects it:

- Packet **00** (Architecture — catalog/reference updates) lands the follow-up checklist items **while the ADR is still Proposed**. Status flip is *not* in packet 00.
- Packet **01** (Architecture — pre-reserve four ADR-0068 invariants — block of four claimed from `constitution/invariant-reservations.md` as `{N1}`/`{N2}`/`{N3}`/`{N4}`) records the four invariants ADR-0068 D6/D7/D2/D3/D4 commits, with explicit "tied to ADR-0068, promoted on acceptance" notes. This separates the invariant-text recording from the flip.
- Packet **02** ships the Actions reusable workflow.
- Packets **03**, **04** ship the first in-Node `BackgroundService` (Notify retry pump) and the first cross-Node Container Apps Job (Communications cadence scheduler) respectively — D11's two-consumer first-shipping list.
- Packet **05** (Architecture — Status flip) flips the ADR header to Accepted, updates the `adrs/README.md` index row, promotes the four invariants from Proposed to numbered/accepted, and registers the initiative as complete. **Hard-blocked** behind 02, 03, 04 (and the cross-init ADR-0063 acceptance per Done-When).

This is deliberate: the ADR commits its acceptance to evidence (deploy workflow + first consumers), not to authorial intent.

## Wave Diagram

### Wave 1 (No code; governance + catalog — proposed-only state)
- [ ] **00** — Architecture: update `infrastructure/reference/tech-stack.md`, `initiatives/roadmap.md`, `repos/HoneyDrunk.Vault.Rotation/boundaries.md`, `repos/HoneyDrunk.Communications/`, `repos/HoneyDrunk.Notify/` context per the ADR-0068 follow-up checklist; register the `adr-0068-background-jobs` initiative. ADR-0068 stays **Proposed**. `Actor=Agent`.
- [ ] **01** — Architecture: pre-reserve the four ADR-0068 invariants (`{N1}` in-Node `BackgroundService`; `{N2}` cross-Node Container Apps Jobs + naming; `{N3}` idempotency on every job; `{N4}` job-failure observability — Pulse/Audit/`IErrorReporter` triad) as **Proposed invariants** in `constitution/invariants.md` with explicit ADR-0068-tied promotion notes — to be promoted to Accepted in packet 05. Block of four claimed from `constitution/invariant-reservations.md` at execution time. `Actor=Agent`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — the reusable deploy workflow)
- [ ] **02** — Actions: author `job-deploy-container-apps-job.yml` reusable workflow (Container Apps Jobs deploy: schedule-or-event trigger, replica policy, retry policy, KEDA scaler wiring, OIDC auth reuse from the existing `job-deploy-container-app.yml` shape). `Actor=Agent`. Blocked by: 00. (No code dependency on packet 01 — runs as early as 00 lands.)

### Wave 3 (Depends on Wave 2 — first consumers, parallel)
- [ ] **03** — Notify: implement the Notify retry pump as an in-Node `BackgroundService` per D2; backoff config in ISO 8601 duration strings per ADR-0063 D6; `TimeProvider` for wall-clock reads; idempotency per D6 via `IIdempotencyStore` (ADR-0042). `Actor=Agent`. Blocked by: 00. (Independent of packet 02 — the in-Node substrate doesn't use the Container Apps Jobs deploy workflow.)
- [ ] **04** — Communications: stand up the cadence/drip-campaign scheduler as the first cross-Node Container Apps Job per D3; cron is 5-field UTC per ADR-0063 D6; idempotency key `${jobName}:${scheduledInstant:yyyyMMddTHHmmssZ}` per D6; D7 retry defaults (3 retries, 1m/5m/25m exponential) wired in the Container Apps Jobs manifest; D8 observability (Pulse `jobs.outcome`/`jobs.duration`, lifecycle traces, long-running progress to Audit per ADR-0030, errors to ADR-0045). `Actor=Agent`. Blocked by: 02. Deploys via packet 02's new workflow.

### Wave 4 (Depends on Wave 3 — acceptance flip + invariant promotion)
- [ ] **05** — Architecture: flip ADR-0068 Status → Accepted; update `adrs/README.md` index row; promote the four invariants from packet 01's Proposed state to Accepted with their final numbers; mark the initiative complete in `active-initiatives.md`. `Actor=Agent`. Blocked by: 02, 03, 04. (Soft cross-init dependency on ADR-0063 acceptance per Done-When — see Cross-Dependency with ADR-0063.)

Packets within a wave run in parallel. **Wave 3 packets 03 and 04 are independent** — 03 lands in `HoneyDrunk.Notify` (in-Node substrate, no deploy-workflow dependency), 04 lands in `HoneyDrunk.Communications` (uses packet 02's deploy workflow). Packet 05 alone in Wave 4 ensures every D11-named first-consumer ships before the ADR is declared Accepted.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Catalog and reference updates per follow-up checklist](./00-architecture-jobs-deferral-and-context-updates.md) | Architecture | Agent | 1 | — |
| 01 | [Pre-reserve the four ADR-0068 invariants as Proposed](./01-architecture-prereserve-jobs-invariants.md) | Architecture | Agent | 1 | 00 |
| 02 | [`job-deploy-container-apps-job.yml` reusable workflow](./02-actions-job-deploy-container-apps-job-workflow.md) | Actions | Agent | 2 | 00 |
| 03 | [Notify retry pump as in-Node `BackgroundService`](./03-notify-retry-pump-background-service.md) | Notify | Agent | 3 | 00 |
| 04 | [Communications cadence scheduler as Container Apps Job](./04-communications-cadence-container-apps-job.md) | Communications | Agent | 3 | 02 |
| 05 | [Accept ADR-0068 — flip status + promote invariants](./05-architecture-adr-0068-acceptance.md) | Architecture | Agent | 4 | 02, 03, 04 |

## Version Bumps

- **`HoneyDrunk.Notify`** — packet 03 lands a new `BackgroundService` in the Notify Worker host. Per invariant 27 this is a minor bump (new feature). Confirm the current solution version at execution time (the launch tracker shows v0.3.0 most recently).
- **`HoneyDrunk.Communications`** — packet 04 adds the Container Apps Job deployable (a new `Program.cs`/binary subproject, the cadence scheduler) to the Communications solution. New runtime artifact — minor bump. Confirm the current solution version at execution time (overview shows v0.2.0).
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; packet 02 is a workflow/YAML change. CHANGELOG updated per the repo convention if it keeps one.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/doc edits only (packets 00, 01, 05).

No new public Kernel/Abstractions contracts ship in this initiative — D4's Jobs-Node deferral and ADR-0068's "no entry" in `catalogs/contracts.json` are explicit.

## Cross-Cutting Concerns

### Invariant numbering — four invariants, batched-block pre-reservation

ADR-0068 commits four new invariants (D6 idempotency, D7 retry defaults / grandfather, D2 in-Node substrate, D3 cross-Node substrate + naming). Numbers are claimed from `constitution/invariant-reservations.md` at packet 01 execution time per the registry's "first merge wins" rule — the block of four is referenced throughout packets 01/03/04 as `{N1}`/`{N2}`/`{N3}`/`{N4}`. At packet-authoring time the registry's next-free pointer named ADR-0068's block as **83/84/85/86**; the executor reconfirms at execution time and substitutes consistently across packets 01, 03, and 04 (and packet 05's promotion text once it lands). Packet 01 records them as **Proposed**; packet 05 promotes them on acceptance. **Earlier drafts of these packets hardcoded 75/76/77/78 — those numbers collided with the ADR-0042/0045 batch reservations and were replaced with placeholders during refine.**

The Container Apps Jobs naming rule (D3 — `caj-hd-{service}-{env}`) is captured inside the new invariant `{N2}`, **not** as an amendment to invariant 34 (`ca-hd-{service}-{env}` for Container Apps proper). The two naming rules are parallel and complementary; D3 is the Jobs-shaped sibling and gets its own invariant text. The 13-character service-name limit (invariant 19) applies to both unchanged — but the Azure Container Apps Jobs resource-name cap may differ; packet 02's Human Prerequisites verify the actual limit before locking the regex.

### `HoneyDrunk.Jobs` is deferred, not just postponed — catalog discipline

Per the ADR's "Catalog obligations": "`catalogs/nodes.json` — **no `honeydrunk-jobs` entry to add.** This ADR explicitly defers the Node." Packet 00 must NOT add a `honeydrunk-jobs` Node to any catalog (`nodes.json`, `relationships.json`, `contracts.json`). The tech-stack `Jobs | Ops | Background job scheduling` row in the Planned Nodes table is the only Jobs-Node trace in the catalogs; packet 00 removes that row (or moves it to a "Deferred — substrate covered by Container Apps Jobs" subsection if such a subsection makes sense). Same for `initiatives/roadmap.md` line 67. Packet 00's PR description states the move/removal explicitly so reviewers can verify no other catalog file is missed.

### Vault.Rotation grandfather posture is documentation-only

Per D7, Vault.Rotation stays on Azure Functions timer triggers until a natural migration moment (a major rewrite, or Functions plan retirement). Packet 00 records this in `repos/HoneyDrunk.Vault.Rotation/boundaries.md` as a "Substrate (grandfathered)" subsection. **No code change in `HoneyDrunk.Vault.Rotation`** in this initiative. The grandfather is explicit, documented, and time-bounded but does not produce a Vault.Rotation packet.

### Idempotency on jobs reuses ADR-0042 — no new contract

ADR-0068 D6 binds every state-mutating job (in-Node `BackgroundService` or cross-Node Container Apps Job) to `IIdempotencyStore` from ADR-0042. The idempotency key is `${jobName}:${scheduledInstant:yyyyMMddTHHmmssZ}` for schedule-triggered jobs; for KEDA event-triggered jobs, derived from the trigger event (Service Bus `MessageId` or Event Grid event ID, salted with job name).

**Hard cross-initiative dependency:** packets 03 and 04 consume `IIdempotencyStore` from `HoneyDrunk.Kernel.Abstractions` and a backing implementation (typically the Cosmos default from `HoneyDrunk.Data.Idempotency.Cosmos`) from ADR-0042's initiative. **ADR-0042's runtime packages must be on the NuGet feed before packets 03/04 can compile** — recorded in each packet's Human Prerequisites as a release-tagging step. If ADR-0042 has not yet shipped its Kernel/Data packages by the time packet 03 or 04 starts, those packets are blocked at execution time even though their `dependencies:` frontmatter does not encode the edge (because `packet:NN` only resolves within a folder and the ADR-0042 packet numbers are different issue numbers in `HoneyDrunk.Architecture`). The cleanest fix: file ADR-0042 fully *first*, then ADR-0068 packets 03/04 reference `Architecture#<n>` qualified edges to ADR-0042's packets 02/03/04. If ADR-0042 has already shipped by the time this folder is filed, drop the cross-init edge — the NuGet packages are simply present.

The dispatch plan flags this as an execution-order judgment for the operator, not as an unconditional dependency. See packets 03 and 04 for the precise Human Prerequisites text.

### Observability is mandatory — D8 wiring is per-packet, not a shared deliverable

ADR-0068 D8 commits four observability emissions on every job: Pulse `jobs.outcome` counter, Pulse `jobs.duration` histogram, lifecycle traces with `correlationId` per invariant 6, long-running (>60s) job progress to Audit via `JobProgress`, and final-failure errors to `IErrorReporter` per ADR-0045. The wiring is per-job — packets 03 and 04 each implement their own; there is no shared "jobs observability library" packet (consistent with D4's "no shared `HoneyDrunk.Jobs.Library` package"). Per-Node wiring is a near-mechanical pattern that the executor follows; the patterns from existing Pulse/Audit consumers are referenced inline.

### ADR-0042, ADR-0030, ADR-0045 cross-init relationships — soft

- **ADR-0042 (idempotency)** — packets 03/04 consume `IIdempotencyStore`. See "Idempotency on jobs reuses ADR-0042" above. Soft cross-init dependency.
- **ADR-0030 (Audit)** — packets 03/04 emit `JobProgress` and `JobFailure` audit categories per D8. Both categories are *new* audit categories implied by D8; their registration in the Audit Node's category list is **not in scope here** — it is a deferred Audit follow-up (the categories ride the existing `AuditEntry` shape; only the category-name strings are new). Flag this in packets 03/04: the audit emit uses the new category strings; if Audit later normalizes its category list, this initiative's emits are forward-compatible.
- **ADR-0045 (error tracking)** — packets 03/04 emit final-failure errors via `IErrorReporter` per D8 + ADR-0045 D3. ADR-0045's facade must be live; if ADR-0045 has not yet shipped by the time packets 03/04 start, the executor wires a TODO-comment `IErrorReporter`-shaped seam and lifts it once ADR-0045 lands — but this is unlikely given ADR-0045's earlier filing posture.

### `BackgroundService` retry semantics are author-decided, not platform-defaulted

Per D7's last paragraph: "In-Node `BackgroundService` work is not subject to D7's retry policy directly — the `BackgroundService` author decides the retry semantics in code." Packet 03 (Notify retry pump) is the first in-Node case under this ADR; its retry shape (the *Notify message* retry semantics, separate from the BackgroundService loop's own try/catch) is decided in-packet using Polly per the ADR's convention. The packet's PR description names the exact retry shape chosen so future Background-Service authors have a precedent to read.

### Local-dev story for Container Apps Jobs (D9) is per-packet, not a shared deliverable

Per D9, Container Apps Jobs don't run locally — the binary runs as a console app or under a timer-driven host for testing. Packet 04 ships the Communications cadence-scheduler binary as a Program.cs/Main entry that the Container Apps Jobs runtime invokes in production; locally, `dotnet run` invokes the same entry. Aspire integration (provisional ADR-0065) is not in scope; the binary stands alone via `dotnet run` regardless.

### Site sync

No site-sync flag. ADR-0068 is internal Core/Ops infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packet 00 (catalog/reference updates):** revert the PR. `HoneyDrunk.Jobs` returns to its Planned-Nodes row in tech-stack.md and its Future-section line in roadmap.md; Vault.Rotation boundaries.md returns to pre-grandfather state; Notify/Communications context loses its substrate-choice note. No runtime impact.
- **Packet 01 (Proposed invariants):** revert the PR; the four invariants leave the file. ADR-0068's commitments are then unrecorded as text — note this in the revert.
- **Packet 02 (Actions workflow):** revert the PR; the new reusable workflow leaves `.github/workflows/`. No consuming repo depends on it at runtime — Communications packet 04 is the first consumer and its deploy fails until the workflow returns or until packet 04 itself is reverted.
- **Packet 03 (Notify retry pump):** revert the PR; Notify's Worker host loses the new `BackgroundService`. Notify's pre-existing retry surface (provider-side `Message-ID` rejection, the existing in-flight queue retry handling) still tolerates duplicates — no regression below today's behaviour. The Notify solution version rolls back.
- **Packet 04 (Communications cadence Job):** revert the PR; the cadence Container Apps Job leaves the repo and is **un-deployed in every environment** via the `az containerapp job delete` portal click (or the equivalent CLI). The Communications solution version rolls back. Per-tenant cadence work resumes its pre-ADR-0068 (uncommitted) state — note: there is no pre-existing cadence scheduler to fall back to, so a revert here leaves Communications without scheduled cadence. Production deploys of packet 04 should be co-ordinated with the operator (Human Prerequisites).
- **Packet 05 (acceptance flip):** revert the PR; ADR-0068 returns to Proposed, the invariants return to Proposed state. The first-consumer code in Notify and Communications continues to run — the policy is just not yet Accepted as text.
- **Operational escape hatch:** if packet 04's Container Apps Job mis-fires (cron skew, double-run, idempotency check failure), use the Container Apps Jobs portal to suspend the schedule trigger without reverting the code. A suspended schedule is a one-click change, no redeploy.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

## Notes for the Operator (the human)

- **ADR-0063 (paired clock policy)** is referenced inline by every packet that touches cron strings or `TimeProvider`. The cross-init dependency is soft; packets 03/04 do not block on ADR-0063's scoping. Packet 05 (acceptance flip) is the right moment to verify ADR-0063 has also been accepted, per ADR-0068's Done-When list. If ADR-0063 has not yet been accepted at packet 05's filing time, hold packet 05 until it has.
- **ADR-0042 release tags** — packets 03 and 04 reference `IIdempotencyStore` and its backings. If ADR-0042's NuGet packages haven't been tagged/released yet at packet 03/04 execution time, surface this in the relevant PR: the agent should not invent a substitute idempotency shape (that would create a parallel store and violate ADR-0042's contract).
- **No standalone `HoneyDrunk.Jobs` repo to create or update** — the deferral is the decision; no scaffolding work.
- **First Container Apps Job in production** — packet 04 is the studio's first Container Apps Job deploy. The deploy workflow (packet 02) is also new. Expect a small amount of iteration on the workflow shape — the ADR's Negative Consequences flag this explicitly: "The deploy workflow … is the studio's first authored Jobs workflow; expect iteration."
