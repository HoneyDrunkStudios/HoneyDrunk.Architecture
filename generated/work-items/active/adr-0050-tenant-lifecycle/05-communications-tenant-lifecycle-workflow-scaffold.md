---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-2", "ops", "adr-0050", "wave-4"]
dependencies: ["work-item:03"]
adrs: ["ADR-0050", "ADR-0019"]
wave: 4
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-communications
---

# Scaffold the tenant-lifecycle workflow and prospect-approval intake in HoneyDrunk.Communications

## Summary
Scaffold the ADR-0050 D8 tenant-lifecycle workflow in `HoneyDrunk.Communications`: the `ITenantLifecycleWorkflow` contract in `HoneyDrunk.Communications.Abstractions`, the prospect-approval intake (creates `Prospect` records, notifies ops via the existing `INotificationSender` seam), and the provisioning workflow scaffold composing the D3 step seams (Auth `TenantId` allocation, Vault namespace creation, Auth scope provisioning, Notify quota allocation, Audit emission, welcome email). The runtime is an **in-process placeholder** backed by `Task.Run` and the existing in-memory decision log — the durable-workflow runtime choice (Dapr Workflow vs Azure Durable Functions per D8) is a deferred follow-up spike packet. Version-bumping packet for `HoneyDrunk.Communications`.

## Context
ADR-0050 D8 commits Communications as the home of the tenant-lifecycle workflow, consistent with ADR-0019's "Communications owns decisions about what should happen and when, across Nodes; Notify owns intake and delivery mechanics." Tenant provisioning is the canonical "what should happen and when across Nodes" — the workflow composes Auth (state machine + identity-map), Vault (namespace), Data (partition — currently a no-op contract seam per the dispatch plan's discussion of the absent Tenant-Data-Isolation ADR), Notify (quota + welcome email), Audit (`TenantProvisioned` event).

This packet scaffolds the workflow structure but **does not pick the durable runtime**. ADR-0050 D8 explicitly defers that choice: *"the durable workflow runtime choice (Dapr Workflow vs Azure Durable Functions vs roll-your-own using `HoneyDrunk.Kernel`'s idempotency + the audit substrate as a state log) is left to the Communications-side execution packet."* This packet treats the runtime as a seam:

- The `ITenantLifecycleWorkflow` contract describes step ordering, per-step idempotency keys (D3), and the failure-recovery semantics (resume from failed step; rollback via `DeprovisionPartial` sibling workflow).
- The in-process runtime implements the contract using `Task.Run` and the in-memory `ICommunicationDecisionLog` (and the audit substrate, when packet 07 wires it) as the state log.
- When the durable runtime is chosen (a separate spike packet), the runtime swaps behind the same contract without touching the step seams.

This is consistent with Communications' v0.2.0 in-memory-first pattern (existing `IPreferenceStore` and `ICadencePolicy` ship in-memory defaults; durable stores are deferred).

`HoneyDrunk.Communications` is a live Node at v0.2.0 (per the active-initiatives.md and the overview doc). This packet is the **first packet on the `HoneyDrunk.Communications` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.2.0` → `0.3.0`; new feature: the tenant-lifecycle workflow surface; additive).

## Scope

### `HoneyDrunk.Communications.Abstractions` — new contracts

- `IProspect` / `Prospect` — record carrying the pre-signup signal: prospect_id, contact email, company name, intended use case, expected volume, submission timestamp, current state (`PendingApproval` / `Approved` / `Rejected`), optional reviewer, optional reason.
- `IProspectIntake` — interface:
  - `ValueTask<Prospect> SubmitAsync(/* prospect details */, CancellationToken ct)` — creates the Prospect record in `PendingApproval`, emits an ops notification.
  - `ValueTask<Prospect?> GetByIdAsync(string prospectId, CancellationToken ct)`
  - `ValueTask<Prospect> ApproveAsync(string prospectId, string approverActor, CancellationToken ct)` — transitions the prospect to `Approved`, triggers `ITenantLifecycleWorkflow.ProvisionAsync`.
  - `ValueTask<Prospect> RejectAsync(string prospectId, string approverActor, string reason, CancellationToken ct)` — transitions to `Rejected` with a recorded reason.
- `ITenantLifecycleWorkflow` — interface (the central contract):
  - `ValueTask<TenantId> ProvisionAsync(Prospect prospect, CancellationToken ct)` — runs the D3 provisioning steps in order, returning the allocated `TenantId`. Idempotent per prospect_id.
  - `ValueTask DeprovisionPartialAsync(string prospectId, CancellationToken ct)` — rollback path for the failure-recovery case in D3.
  - `ValueTask SuspendAsync(TenantId id, SuspensionReason reason, CancellationToken ct)` — the D4 suspension state transition + audit emission. (Actual API-gateway gating is a deferred follow-up.)
  - `ValueTask ReinstateAsync(TenantId id, string operatorActor, CancellationToken ct)` — Suspended → Active.
  - `ValueTask BeginOffboardingAsync(TenantId id, OffboardingReason reason, CancellationToken ct)` — Active/Suspended → Offboarding, triggers offboarding-email send, schedules T+30 close (the scheduled-job substrate is a deferred follow-up; this method emits the state transition + the email).
  - `ValueTask CloseAsync(TenantId id, CancellationToken ct)` — Offboarding → Closed; hard-delete tenant partition + Vault namespace + IdentityMap row (the partition/Vault deletion is currently a no-op contract seam; the IdentityMap erasure is wired via `IIdentityMap.EraseTenantAsync` from packet 03).
- `IProvisioningStep` (and concrete step contracts) — one per D3 step, so each step is observable and individually retryable:
  - `IAllocateTenantIdStep` — calls `ITenantStore.CreateProspectAsync` returning the allocated `TenantId` + `PseudoTenantToken`.
  - `ICreateVaultNamespaceStep` — currently a no-op contract seam; logs a structured "would create Vault namespace" entry. A durable implementation lands when Vault namespace provisioning is automated.
  - `IProvisionAuthScopeStep` — no-op contract seam (Auth scope provisioning beyond the existing `ITenantStore.CreateProspectAsync` is a future Auth-side extension).
  - `IAssignOwnerRoleStep` — no-op contract seam.
  - `IProvisionDataPartitionStep` — no-op contract seam, per the dispatch plan's discussion of the absent Tenant-Data-Isolation ADR.
  - `IAllocateNotifyQuotaStep` — no-op contract seam (Notify quota allocation is a future Notify-side extension).
  - `ICreateBillingCustomerStep` — no-op contract seam (`HoneyDrunk.Billing` not yet scaffolded).
  - `IEmitTenantProvisionedAuditStep` — calls `IAuditLog.Append(AuditEntry.CreatePseudonymous(..., AuditEvents.TenantProvisioned, ...))`. **This step is the first one that actually does something cross-Node beyond Auth.**
  - `ISendWelcomeEmailStep` — composes `INotificationSender` to send the welcome email. **Second cross-Node real action.**
- `SuspensionReason` / `OffboardingReason` — enums or records capturing the categorization from D4/D5.
- `ProvisioningWorkflowFailure` — exception carrying the failed step name, the underlying exception, and the partial-rollback recommendation.

### `HoneyDrunk.Communications` (runtime) — implementations

- In-memory `IProspectIntake` implementation. New Prospect records live in an in-memory `IProspectStore`.
- `TenantLifecycleWorkflow` implementation of `ITenantLifecycleWorkflow`. Uses `Task.Run`-style sequential execution; each step is awaited in order; failure halts the workflow and returns a `ProvisioningWorkflowFailure`. Step-level idempotency is delegated to the steps themselves (each step composes an `IIdempotencyStore` if/when available — currently the in-memory stores are not idempotency-tracked, but the contract names the keys per D3).
- Default concrete `IProvisioningStep` implementations:
  - `AllocateTenantIdStep` — composes `ITenantStore.CreateProspectAsync`.
  - `EmitTenantProvisionedAuditStep` — composes `IAuditLog.Append` with the pseudonymous-token factory.
  - `SendWelcomeEmailStep` — composes `INotificationSender` with a hardcoded welcome-email template (existing `WelcomeEmailIntent` pattern from v0.2.0).
  - The other steps (Vault namespace, Auth scope extensions, Notify quota, Billing customer, Data partition) ship as `NoOpStep` instances logging structured "would-do" entries to the decision log. A follow-up packet replaces each with a real implementation as the underlying Node capabilities land.
- DI extensions: `services.AddHoneyDrunkCommunicationsTenantLifecycle()` registers the default step implementations + the workflow runtime + the in-memory `IProspectStore`.

### Versioning
- Bump every non-test `.csproj` in the `HoneyDrunk.Communications` solution to `0.3.0` in one commit (invariant 27).
- Repo-level `CHANGELOG.md` new `[0.3.0]` entry.
- `HoneyDrunk.Communications.Abstractions/CHANGELOG.md` `[0.3.0]` entry.
- `HoneyDrunk.Communications/CHANGELOG.md` `[0.3.0]` entry.
- READMEs updated.

## Proposed Implementation

### 1. Workflow shape (concrete)

The provisioning workflow (ADR-0050 D3) runs nine steps in order:

```csharp
public async ValueTask<TenantId> ProvisionAsync(Prospect prospect, CancellationToken ct)
{
    var idempotencyKeyBase = $"provision:{prospect.Id}";

    // Step 1: Allocate TenantId (idempotency key: "provision:{prospect_id}:tenant_id")
    var tenant = await _allocateTenantId.ExecuteAsync(prospect, $"{idempotencyKeyBase}:tenant_id", ct);

    // Step 2: Create tenant Key Vault namespace (no-op for now)
    await _createVaultNamespace.ExecuteAsync(tenant.TenantId, $"{idempotencyKeyBase}:vault", ct);

    // Step 3: Provision Auth tenant scope (no-op for now; CreateProspectAsync already created the Tenant)
    await _provisionAuthScope.ExecuteAsync(tenant.TenantId, $"{idempotencyKeyBase}:auth_scope", ct);

    // Step 4: Assign initial owner role (no-op for now)
    await _assignOwnerRole.ExecuteAsync(tenant.TenantId, prospect.SignupUserId, $"{idempotencyKeyBase}:owner_role:{prospect.SignupUserId}", ct);

    // Step 5: Provision per-tenant data partition (no-op for now per the absent Tenant-Data-Isolation ADR)
    await _provisionDataPartition.ExecuteAsync(tenant.TenantId, $"{idempotencyKeyBase}:partition", ct);

    // Step 6: Allocate Notify quota (no-op for now)
    await _allocateNotifyQuota.ExecuteAsync(tenant.TenantId, $"{idempotencyKeyBase}:quota", ct);

    // Step 7: Create billing customer (no-op for now; HoneyDrunk.Billing not scaffolded)
    await _createBillingCustomer.ExecuteAsync(tenant.TenantId, prospect, $"{idempotencyKeyBase}:billing", ct);

    // Step 8: Emit TenantProvisioned audit event
    await _emitTenantProvisioned.ExecuteAsync(tenant.TenantId, tenant.PseudoTenantToken, $"{idempotencyKeyBase}:audit", ct);

    // Step 9: Send welcome email
    await _sendWelcomeEmail.ExecuteAsync(tenant.TenantId, prospect.ContactEmail, $"{idempotencyKeyBase}:welcome_email", ct);

    return tenant.TenantId;
}
```

Each step receives its own canonical idempotency key per D3's column. Step-level failure halts the workflow; the caller receives a `ProvisioningWorkflowFailure` naming the failed step. Re-running `ProvisionAsync` with the same `prospect_id` resumes from the failed step (in the in-memory implementation, this means re-executing all steps — they are idempotent in spirit, and the contract names the keys for when the runtime gains idempotency tracking).

### 2. Failure-recovery contract

`DeprovisionPartialAsync(prospectId, ct)` rolls back the steps that have run:

```csharp
public async ValueTask DeprovisionPartialAsync(string prospectId, CancellationToken ct)
{
    // For each step that ran, call its sibling Undo method.
    // In the in-memory implementation, this is largely no-op since no real
    // resources were allocated (Vault namespace not created, partition not
    // provisioned, etc.). The TenantId allocation is rolled back by
    // marking the Tenant 'Closed' in the state machine.
}
```

The contract obligation is "rollback is supported"; the no-op implementation is honest about its current state.

### 3. Prospect intake (D2)

`IProspectIntake.SubmitAsync(...)` creates a `Prospect` record in `PendingApproval`. The intake composes `INotificationSender` to email ops ("New prospect signup awaiting approval: {company} for {use case} at {volume}"). The notification is a fixed template; the recipient is a configured ops-channel address (from `HoneyDrunk.Communications` configuration).

`ApproveAsync(prospectId, approverActor, ct)`:
1. Transitions the Prospect to `Approved`.
2. Calls `ITenantLifecycleWorkflow.ProvisionAsync(prospect, ct)`.
3. Returns the updated Prospect (with the allocated TenantId).

`RejectAsync(prospectId, approverActor, reason, ct)`:
1. Transitions the Prospect to `Rejected`.
2. Records the reason.
3. Returns the updated Prospect.

### 4. Decision-log integration

Each step emits a `CommunicationDecisionLogEntry` via the existing `ICommunicationDecisionLog` from v0.2.0. The entry carries: step name, idempotency key, outcome (succeeded / failed / no-op-deferred), timestamp, and the in-progress workflow correlation id. This is the in-memory "state log" the workflow consults on resume (in lieu of a durable runtime).

### 5. Tests

- Workflow happy path: a Prospect submitted, approved, provisioned. Verify nine step entries in the decision log; verify the issued `TenantId` is returned; verify the `TenantProvisioned` audit event was emitted with the correct `PseudoTenantToken` (composed via the new `AuditEntry.CreatePseudonymous` factory from packet 02).
- Workflow failure: simulate a failure in step N (e.g. force the welcome-email step to throw). Verify the workflow halts at step N, returns a `ProvisioningWorkflowFailure` naming step N, and the decision log shows steps 1..N-1 as succeeded.
- Prospect intake: SubmitAsync creates a Prospect in `PendingApproval` and sends an ops notification.
- ApproveAsync: transitions the Prospect and triggers provisioning.
- RejectAsync: transitions and records the reason.
- Suspension: `SuspendAsync` transitions Active → Suspended and emits a `TenantSuspended` audit event.
- Offboarding: `BeginOffboardingAsync` transitions Active → Offboarding, emits a `TenantOffboarding` audit event, sends the offboarding email.

## Affected Files
- `src/HoneyDrunk.Communications.Abstractions/TenantLifecycle/` — new folder with the contracts (Prospect, IProspectIntake, ITenantLifecycleWorkflow, IProvisioningStep + the named step interfaces, SuspensionReason, OffboardingReason, ProvisioningWorkflowFailure)
- `src/HoneyDrunk.Communications/TenantLifecycle/` — new folder with the implementations (TenantLifecycleWorkflow, ProspectIntake, ProspectStore, the default step implementations)
- `src/HoneyDrunk.Communications/DependencyInjection/ServiceCollectionExtensions.cs` (extended — `AddHoneyDrunkCommunicationsTenantLifecycle`)
- Every non-test `.csproj` — version bump to `0.3.0`
- `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md`, `README.md`
- `src/HoneyDrunk.Communications/CHANGELOG.md`, `README.md`
- Repo-level `CHANGELOG.md`
- Test project(s) — workflow happy-path, workflow-failure, prospect-intake tests

## NuGet Dependencies
- **`HoneyDrunk.Communications.Abstractions`** — gain `HoneyDrunk.Auth.Abstractions` v0.6.0 (for `TenantState`, `ITenantStore`, `IIdentityMap`, etc.) and `HoneyDrunk.Audit.Abstractions` v0.2.0 (for `PseudoTenantToken`, `AuditEvents`, the `AuditEntry.CreatePseudonymous` factory).
- **`HoneyDrunk.Communications`** (runtime) — transitively gains the above.
- Confirm exact versions at execution time — packets 02 and 03 set them.

## Boundary Check
- [x] The tenant-lifecycle workflow is **decision/orchestration across Nodes** — it composes Auth, Vault, Data, Notify, Audit. Per ADR-0019, decision/orchestration belongs in `HoneyDrunk.Communications`. Routing rule "communications, decision, workflow, orchestration → HoneyDrunk.Communications" maps exactly.
- [x] The workflow does NOT contain delivery mechanics. The welcome email goes through `INotificationSender` (Notify's surface). Suspension/offboarding emails go through `INotificationSender`. This preserves invariant 41 ("Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify. Notify owns delivery mechanics; Communications owns decision logic.").
- [x] The workflow emits decision-log entries via `ICommunicationDecisionLog` (invariant 42: "Every orchestrated send records a decision-log entry"). Per-step entries make the workflow observable.
- [x] No Studios admin-console surface change in this packet (D9 is a deferred follow-up; this packet ships only the contract surface the eventual admin console would call).

## Acceptance Criteria
- [ ] `HoneyDrunk.Communications.Abstractions` exposes `Prospect` (record) with the prospect fields from ADR-0050 D2
- [ ] `HoneyDrunk.Communications.Abstractions` exposes `IProspectIntake` with `SubmitAsync`, `GetByIdAsync`, `ApproveAsync`, `RejectAsync`
- [ ] `HoneyDrunk.Communications.Abstractions` exposes `ITenantLifecycleWorkflow` with `ProvisionAsync`, `DeprovisionPartialAsync`, `SuspendAsync`, `ReinstateAsync`, `BeginOffboardingAsync`, `CloseAsync`
- [ ] `HoneyDrunk.Communications.Abstractions` exposes the nine `IProvisioningStep`-derived interfaces (one per D3 step), each with a documented idempotency-key shape from D3
- [ ] `HoneyDrunk.Communications.Abstractions` exposes `SuspensionReason`, `OffboardingReason`, `ProvisioningWorkflowFailure`
- [ ] `HoneyDrunk.Communications` ships in-memory default implementations of `IProspectIntake`, `IProspectStore`, `ITenantLifecycleWorkflow`, and the nine step implementations (with no-op behavior for the steps that touch un-scaffolded Nodes — Vault, Data partition, Notify quota, Billing customer)
- [ ] The workflow happy-path emits a `TenantProvisioned` audit event using `AuditEntry.CreatePseudonymous` with the correct `PseudoTenantToken`
- [ ] The workflow happy-path sends a welcome email via `INotificationSender`
- [ ] Workflow failure halts at the failed step and returns a `ProvisioningWorkflowFailure` naming the step
- [ ] Prospect intake submits a Prospect in `PendingApproval` and emits an ops notification via `INotificationSender`
- [ ] DI extension `services.AddHoneyDrunkCommunicationsTenantLifecycle()` registers the in-memory implementations
- [ ] Per-step decision-log entries are emitted via `ICommunicationDecisionLog` (invariant 42)
- [ ] All new public types have XML documentation (invariant 13)
- [ ] Every non-test `.csproj` in the solution is at `0.3.0` in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.3.0]` entry
- [ ] `HoneyDrunk.Communications.Abstractions/CHANGELOG.md` and `HoneyDrunk.Communications/CHANGELOG.md` have `[0.3.0]` entries
- [ ] READMEs updated to document the new tenant-lifecycle surface
- [ ] Tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes; the Communications contract-shape canary passes (the new contracts are additive, paired with the `0.3.0` bump)

## Human Prerequisites
- [ ] The ops-notification email recipient (used by `IProspectIntake.SubmitAsync` to email "new prospect signup awaiting approval") is configured in `HoneyDrunk.Communications` configuration. This is a config-time decision (an email address; likely `ops@honeydrunkstudios.com` or the user's personal address). The packet ships the configuration key + the in-memory default of the user's email per the active dev environment; production deployment configures the production recipient. No Azure portal action; just a config-value to land.

## Referenced ADR Decisions

**ADR-0050 D8 — Communications hosts the tenant-lifecycle workflow.** Tenant provisioning is decision/orchestration across Nodes. The durable-workflow runtime choice (Dapr Workflow vs Azure Durable Functions vs roll-your-own) is deferred to a separate spike packet; this packet ships the in-process placeholder.

**ADR-0050 D3 — Provisioning steps and idempotency keys.** Nine steps in order with canonical idempotency-key shapes (`provision:{prospect_id}:tenant_id`, `provision:{tenant_id}:vault`, etc.). Each step is a named contract. Failure halts the workflow; the workflow can resume from the failed step.

**ADR-0050 D2 — Self-serve sign-up with manual approval.** Prospects submit; ops approves or rejects. The approval triggers provisioning. The rejection records a reason in audit.

**ADR-0050 D4 / D5 — Suspension and offboarding.** This packet ships the state-transition + audit-emission + email-send surfaces for these flows. The API-gateway gating (402/403/410 responses) and the scheduled-job timers (PastDue grace, T+30 close) are deferred follow-ups.

**ADR-0050 D6 — Audit events use `AuditEntry.CreatePseudonymous` with pseudonymous tokens.** Every `TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `UserErased` event uses the pseudonymous-token factory; raw tenant or user identifiers never reach the audit substrate.

**ADR-0019 (referenced) — Communications boundary.** Communications owns decisions (this packet); Notify owns delivery mechanics (composed via `INotificationSender`). Invariants 40, 41, 42 are preserved.

**Invariant 27 (constraint) — All projects in a solution share one version and move together.** Bump every non-test `.csproj` to `0.3.0` in one commit.

**Invariant 41 (constraint) — Decision logic lives in Communications, not Notify.** Delivery mechanics (the actual SMTP send) go through `INotificationSender` (Notify). This packet does NOT add any sender-side logic to Notify.

**Invariant 42 (constraint) — Every orchestrated send records a decision-log entry via `ICommunicationDecisionLog`.** Each provisioning step emits its decision-log entry.

**Invariant 47 (referenced) — Audit substrate is append-only and durable.** Audit emissions in this workflow use `IAuditLog.Append` (append-only); no audit mutation.

**Invariant `67` (this initiative, claimed by packet 00) — Audit substrate accepts only pseudonymous tokens.** Workflow audit emissions use `CreatePseudonymous` with `PseudoTenantToken` / `PseudoUserToken`.

**Invariant `68` (this initiative, claimed by packet 00) — Every tenant transition is audited and initiator-attributed.** Each `SuspendAsync` / `ReinstateAsync` / `BeginOffboardingAsync` / `CloseAsync` call composes the state-machine transition (Auth-side, packet 03) AND an audit emission.

## Constraints
- **Durable runtime is NOT chosen in this packet.** The in-process implementation is the explicit deliverable. Do NOT introduce a dependency on Dapr Workflow, Azure Durable Functions, MassTransit Sagas, or any other workflow runtime. The contract shape is deliberately runtime-agnostic so the spike packet can pick later.
- **The no-op step seams are honest.** `ICreateVaultNamespaceStep`, `IProvisionDataPartitionStep`, `IAllocateNotifyQuotaStep`, `ICreateBillingCustomerStep` ship as `NoOpStep` implementations logging structured "would-do" entries. Do NOT pretend they do real work. Document each as "no-op contract seam; replaced by a real implementation when the underlying Node capability lands."
- **Audit emissions use the new pseudonymous-token factory from packet 02.** Use `AuditEntry.CreatePseudonymous(...)`, not the legacy `string Actor` constructor. The pseudonymous tokens come from the `Tenant.PseudoTenantToken` (issued by packet 03's `ITenantStore.CreateProspectAsync`) and from the approver's `PseudoUserToken` (resolved via `IIdentityMap.ResolveByUserIdAsync`).
- **The actor on each audit event is the initiator.** Prospect approval: the approving ops operator (Customer/Ops/Webhook/Scheduled per `TransitionInitiator`). Suspension: the actor depends on the trigger. The audit emission carries the initiator's `PseudoUserToken` (or a synthetic actor string for `Scheduled` / `Webhook` triggers per the dispatch plan's PII-rejection note — synthetic strings like `webhook-stripe-payment-failed` pass the boundary).
- **Step 7 (Create billing customer) is no-op for now.** `HoneyDrunk.Billing` is not scaffolded; per the dispatch plan, the Billing customer creation is deferred to ADR-0037 standup. The contract seam exists so the workflow shape is complete; the step is a no-op.
- **Steps 5 (data partition) and the Vault namespace step are no-op for now.** Per the dispatch plan's discussion of the absent Tenant-Data-Isolation ADR, the partition step is no-op. Vault namespace creation is similarly deferred until automated.
- **`HoneyDrunk.Communications.Abstractions` references `HoneyDrunk.Auth.Abstractions` and `HoneyDrunk.Audit.Abstractions` — both are Abstractions packages.** This keeps the dependency graph DAG-clean (invariant 4) and preserves invariant 1 (Abstractions have no runtime dependencies on HoneyDrunk runtime packages).
- **Records drop the `I`.** `Prospect`, `SuspensionReason`, `OffboardingReason` are records / enums. `IProspectIntake`, `ITenantLifecycleWorkflow`, the step interfaces — interfaces keep it.
- **Invariant 27 — version bump every non-test `.csproj` in one commit.**
- **Suspension API gates are NOT in this packet.** The 402/403/410 gateway responses are a deferred follow-up. This packet ships only the state-transition + audit + email surfaces.

## Labels
`feature`, `tier-2`, `ops`, `adr-0050`, `wave-4`

## Agent Handoff

**Objective:** Scaffold the tenant-lifecycle workflow surface in `HoneyDrunk.Communications`: prospect-approval intake, the workflow contract + in-process runtime, the nine D3 step contracts (with no-op seams for steps that touch un-scaffolded capabilities), suspension / reinstate / offboarding / close state-transition surfaces. Bump the solution to `0.3.0`.

**Target:** `HoneyDrunk.Communications`, branch from `main`.

**Context:**
- Goal: Ship the Communications-side workflow scaffold every downstream tenant-lifecycle operation composes. The durable runtime is deferred; this packet is the contract shape + in-process placeholder.
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 4.
- ADRs: ADR-0050 D2/D3/D4/D5/D6/D8 (primary), ADR-0019 (Communications boundary, preserved), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — `HoneyDrunk.Auth` v0.6.0 ships `ITenantStore`, `IIdentityMap`, the seven-state machine, pseudonymous-token issuance.

**Constraints:**
- **Durable runtime is NOT chosen.** In-process implementation only. Contract shape is runtime-agnostic.
- **No-op step seams are honest.** Vault namespace, Data partition, Notify quota, Billing customer steps ship as `NoOpStep` implementations with "would-do" decision-log entries.
- **Audit emissions use the pseudonymous-token factory from packet 02.** Use `AuditEntry.CreatePseudonymous(...)`.
- **Suspension API gates are NOT in this packet.** State transition + audit + email surfaces only.
- **Communications boundary preserved.** Delivery mechanics through `INotificationSender` (invariant 41). Per-orchestrated-send decision-log entries (invariant 42).
- Records drop the `I`; interfaces keep it.
- Bump every non-test `.csproj` to `0.3.0` in one commit (invariant 27).
- `HoneyDrunk.Communications.Abstractions` stays Abstractions-only — references Auth.Abstractions and Audit.Abstractions, no runtime packages.

**Key Files:**
- `src/HoneyDrunk.Communications.Abstractions/TenantLifecycle/` (new folder with contracts)
- `src/HoneyDrunk.Communications/TenantLifecycle/` (new folder with implementations)
- DI extension
- Every non-test `.csproj` for the version bump
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs; READMEs

**Contracts:**
- `Prospect` (new record), `IProspectIntake` (new interface) — prospect submission + approval + rejection.
- `ITenantLifecycleWorkflow` (new interface) — the workflow surface (provision, deprovision-partial, suspend, reinstate, begin-offboarding, close).
- Nine step interfaces (one per D3 step) — each carrying a canonical idempotency-key shape.
- `SuspensionReason`, `OffboardingReason`, `ProvisioningWorkflowFailure`.
- In-memory default implementations in `HoneyDrunk.Communications`.
