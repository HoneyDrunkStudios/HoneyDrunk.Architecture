---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["feature", "tier-2", "core", "adr-0050", "wave-5"]
dependencies: ["work-item:05", "work-item:06"]
adrs: ["ADR-0050"]
wave: 5
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-auth
---

# Wire tenant-lifecycle audit emissions in Auth and Communications

## Summary
Wire the seven new tenant-lifecycle audit event emissions across `HoneyDrunk.Auth` and `HoneyDrunk.Communications`. Auth emits at state-machine transitions (`ITenantStore.TransitionAsync` → `TenantProvisioned` / `TenantSuspended` / `TenantReinstated` / `TenantOffboarding` / `TenantClosed`) and at identity-map deletion (`IIdentityMap.EraseUserAsync` → `UserErased`). Communications emits at workflow milestones (`TenantLifecycleWorkflow.ProvisionAsync` step 8 calls `IEmitTenantProvisionedAuditStep` which composes Auth's emission; `SuspendAsync` / `BeginOffboardingAsync` / `CloseAsync` similarly). All emissions use `AuditEntry.CreatePseudonymous` (packet 02) with pseudonymous tokens. `TenantDataExported` is already emitted by `HoneyDrunk.Data` (packet 06) — this packet does not duplicate it.

**Cross-repo PR note.** This packet's code lives in **two repos** (`HoneyDrunk.Auth` and `HoneyDrunk.Communications`). The `target_repo` is `HoneyDrunkStudios/HoneyDrunk.Auth` for board-routing purposes; the Communications-side work is a sibling PR explicitly called out in this packet's body. The two PRs may be authored in either order, but the Communications PR is `Blocked by` the Auth PR if a separate issue/PR pair is created — Auth's emission helpers are consumed by Communications' workflow steps. **If the executor prefers**, split this packet into `07a-auth-tenant-lifecycle-emissions.md` and `07b-communications-tenant-lifecycle-emissions.md` at execution time; both are acceptable. The dispatch plan tracks it as one logical unit.

## Context
Packet 03 shipped `ITenantStore.TransitionAsync` and `IIdentityMap.EraseUserAsync` / `EraseTenantAsync` as **mechanic-only** methods — they update state and delete rows but do NOT emit audit events. Packet 05 shipped `ITenantLifecycleWorkflow` with step seams including `IEmitTenantProvisionedAuditStep` — that step is implemented in this packet (it was a no-op in packet 05's scaffold, called out in 05's "no-op step seams" list — see Constraints below for the clarification).

Packet 02 shipped `AuditEntry.CreatePseudonymous` and the seven event-name constants. Packet 03 shipped pseudonymous-token issuance + the IdentityMap for resolution.

This packet **composes** these surfaces:

1. **Auth-side:** wire `ITenantStore.TransitionAsync` to emit the corresponding audit event after a successful transition. Wire `IIdentityMap.EraseUserAsync` / `EraseTenantAsync` to emit `UserErased` / a corresponding tenant-erasure event. The emission uses `AuditEntry.CreatePseudonymous` composing `IAuditLog` (Auth already references `HoneyDrunk.Audit.Abstractions` per v0.5.0 wiring).
2. **Communications-side:** the workflow's step 8 (`EmitTenantProvisionedAuditStep`) — currently a no-op per packet 05's scaffold — gains a real implementation that emits `TenantProvisioned`. Similarly, `SuspendAsync`, `ReinstateAsync`, `BeginOffboardingAsync`, `CloseAsync` compose state transitions with audit emissions (delegating to Auth's now-emitting `ITenantStore.TransitionAsync`, OR emitting in Communications directly — implementation choice; see Constraints).

**Which Node emits?** Either Auth or Communications can be the emitter. The cleaner pattern: **Auth emits the state-machine transition events** (Auth knows the source state and the new state — natural emission boundary). **Communications emits the workflow-milestone events** (e.g. "prospect rejected with reason X" is a Communications event, not a state-machine event since the prospect doesn't have a `TenantId` yet). For lifecycle state transitions that go through `ITenantStore.TransitionAsync`, Auth is the emitter. For workflow concerns (provisioning step failures, scheduled-job triggers), Communications is the emitter.

This packet does **not** wire Stripe webhook handlers or the API-gateway suspension responses — those are deferred follow-ups per the dispatch plan.

## Scope

### `HoneyDrunk.Auth` (runtime) — emission composition
- Modify `TenantStore.TransitionAsync` (from packet 03) to, after a successful transition persistence, build and append an `AuditEntry.CreatePseudonymous(...)` whose:
  - `EventName` is one of: `AuditEvents.TenantProvisioned` (Prospect → Trialing), `AuditEvents.TenantSuspended` (* → Suspended), `AuditEvents.TenantReinstated` (Suspended → Active), `AuditEvents.TenantOffboarding` (* → Offboarding), `AuditEvents.TenantClosed` (Offboarding → Closed). The mapping is explicit; transitions that don't correspond to a named event (e.g. Active ↔ PastDue, Trialing → Active) get a generic `tenant.state_changed` event (a new event-name constant added in this packet to Audit Abstractions — see Cross-Repo Audit-Abstractions Note).
  - `ActorToken` is the initiator's `PseudoUserToken` if available (resolved via `IIdentityMap.ResolveByUserIdAsync` for ops actors with a `userId`). For `Webhook` / `Scheduled` / `Customer (self-serve)` transitions where no specific user is the actor, use a synthetic actor string like `webhook-stripe`, `scheduled-job-pastdue-sweep`, or `customer-self-serve` — these pass the PII-rejection helper from packet 02.
  - `TenantToken` is the tenant's `PseudoTenantToken` (from the `Tenant` aggregate).
  - `Category` is `AuditCategory.Action` (or `Security` for ToS-driven suspensions — choose the most descriptive existing category).
  - `Outcome` is `AuditOutcome.Succeeded` (transitions only emit on success — the runtime-guard `InvalidTenantTransitionException` was thrown before reaching the emission point).
  - Metadata: `{ "from_state": "<source>", "to_state": "<target>", "initiator": "<TransitionInitiator>", "mechanism": "<description>", "reason": "<optional reason>" }`.
- Modify `IdentityMap.EraseUserAsync` (from packet 03) to emit `UserErased` after the row is deleted:
  - `ActorToken` is the orphaned `PseudoUserToken` (yes — the event references the now-unresolvable token; the canary spec from packet 04 verifies this works).
  - `TenantToken` may be `null` (`PseudoTenantToken?` per packet 02's optional init property) or carry the tenant the user belonged to if known and not erased.
  - Metadata: `{ "gdpr_request_id": "<id>" }`.
- Modify `IdentityMap.EraseTenantAsync` similarly to emit a tenant-erasure event. `TenantClosed` is the natural choice — it's emitted both at the state-machine transition (Offboarding → Closed) AND at the IdentityMap deletion. Deduplicate: either emit `TenantClosed` at the state transition AND a separate `TenantIdentityErased` event at the IdentityMap deletion, OR emit only `TenantClosed` and ensure the workflow calls state-transition *before* identity-map deletion so one event covers both. **Recommended: emit only `TenantClosed` at the state transition; do not emit a separate identity-map-deletion event for tenant.** The workflow's CloseAsync calls `TransitionAsync(Closed)` (which emits) THEN `IIdentityMap.EraseTenantAsync` (which does not emit, by design). User-level erasure does not have a state-machine transition, so `UserErased` IS emitted at the IdentityMap call. (This asymmetry is intentional; document it.)

### `HoneyDrunk.Communications` (runtime) — workflow-step composition
- Implement the `EmitTenantProvisionedAuditStep` from packet 05. The step calls `IAuditLog.Append(AuditEntry.CreatePseudonymous(..., AuditEvents.TenantProvisioned, ...))` directly. **However**, this overlaps with Auth's `TransitionAsync(Trialing)` emission described above. The clean resolution: **Auth's `TransitionAsync` emits `TenantProvisioned`**, and Communications' `EmitTenantProvisionedAuditStep` is **removed from the workflow** as redundant — the step's no-op nature in packet 05's scaffold becomes "absent" rather than "no-op."
  - Concretely: amend packet 05's `ProvisionAsync` to drop the `EmitTenantProvisionedAuditStep` call; the audit emission happens inside `ITenantStore.CreateProspectAsync` → `TransitionAsync` (the prospect is created in `Prospect` and immediately transitioned to `Trialing` on approval; Auth emits `TenantProvisioned` at the transition).
  - Update packet 05's `ProvisionAsync` step list comment / docs from "9 steps" to "8 steps (audit emission consolidated into the Auth state-machine transition)."
- For workflow concerns NOT covered by Auth state transitions, Communications emits directly. Examples:
  - **Prospect rejection** (`IProspectIntake.RejectAsync`): emit a new `prospect.rejected` event (also a new event-name constant added to Audit Abstractions — see Cross-Repo note). The prospect has no `TenantId` yet, so this is a Communications-only event.
  - **Provisioning workflow failure** (any step throws): emit a `tenant.provisioning_failed` event (also a new event-name constant) with metadata naming the failed step. Auth's state-machine has not transitioned (the failure was in steps 2-9, before or at the audit-emission step in the OLD shape; in the new shape Auth's transition happens before the workflow runs, so the workflow failure happens AFTER `TenantProvisioned` — see Constraints for the sequencing clarification).
- DI extensions: no new registrations beyond packet 05's `AddHoneyDrunkCommunicationsTenantLifecycle` and packet 03's `AddHoneyDrunkAuthTenants`. The composition wires through DI as services are resolved.

### Cross-Repo Audit-Abstractions Note

This packet may need to add **new event-name constants** to `HoneyDrunk.Audit.Abstractions` for events packet 02 did not enumerate (the seven D-named events). Specifically:

- `tenant.state_changed` — for transitions not covered by a specific event name (Active → PastDue, PastDue → Active, Trialing → Active).
- `prospect.rejected` — for Communications-side prospect rejection.
- `tenant.provisioning_failed` — for Communications-side workflow failure.

If these are needed, the executor has two choices:

1. **Add them as a small Audit-Abstractions patch in a sub-packet of this work** — `HoneyDrunk.Audit` ships v0.2.1 (patch bump for additive event-name constants; not a minor since no new types). The sub-PR lands in `HoneyDrunk.Audit` first, then this packet's Auth/Communications PRs build against v0.2.1.
2. **Inline the strings** at the emission sites in Auth/Communications (e.g. `eventName: "tenant.state_changed"`) without adding constants. This is less clean but avoids the cross-repo coordination. Document the strings in the Communications/Auth README so they're discoverable.

The executor decides. **Option 1 is preferred** for catalog hygiene; option 2 is acceptable if cross-repo coordination is friction-heavy.

### Versioning
- `HoneyDrunk.Auth` — already version-bumped to `0.6.0` by packet 03. This packet **appends** to the in-progress `[0.6.0]` CHANGELOG entry (invariant 27 — additional packets on the same solution append; do not bump again). If packet 03 has shipped to NuGet between then and now, this packet bumps to `0.6.1` (patch) — the Auth change is purely additive, no new types, just composition. The executor confirms the in-flight state at execution time.
- `HoneyDrunk.Communications` — already version-bumped to `0.3.0` by packet 05. Same append-to-CHANGELOG-or-patch-bump logic.
- `HoneyDrunk.Audit` (if event-name constants are added per option 1) — bump `0.2.0 → 0.2.1` (patch, additive constants).

The version state is implementation-time-checked; document the chosen pattern in the PR(s).

## Proposed Implementation

### 1. Auth-side state-machine emission

In `HoneyDrunk.Auth/Tenants/TenantStore.cs` (extend the implementation from packet 03):

```csharp
public sealed class TenantStore(
    IAuditLog auditLog,
    IIdentityMap identityMap)
    : ITenantStore
{
    // ... existing fields and methods from packet 03

    public async ValueTask<Tenant> TransitionAsync(
        TenantId id,
        TenantState target,
        TenantStateTransition transition,
        CancellationToken ct)
    {
        var current = await GetByIdAsync(id, ct)
            ?? throw new InvalidOperationException($"Tenant {id} not found.");

        if (!TransitionRules.IsAllowed(current.State, target))
            throw new InvalidTenantTransitionException(current.State, target, transition.Initiator);

        var updated = current with
        {
            State = target,
            LastTransitionedAt = DateTimeOffset.UtcNow,
        };

        await PersistAsync(updated, transition, ct);

        await EmitTransitionAuditAsync(current, updated, transition, ct);

        return updated;
    }

    private async ValueTask EmitTransitionAuditAsync(
        Tenant before, Tenant after, TenantStateTransition transition, CancellationToken ct)
    {
        var eventName = MapTransitionToEventName(before.State, after.State);
        var actorToken = await ResolveActorTokenAsync(transition, ct);

        var entry = AuditEntry.CreatePseudonymous(
            id: AuditEntryId.New(),
            occurredAt: DateTimeOffset.UtcNow,
            actor: actorToken ?? throw new InvalidOperationException("Could not resolve actor token; emission requires a token (synthetic-actor path takes the legacy overload, not CreatePseudonymous)."),
            tenantToken: after.PseudoTenantToken,
            eventName: eventName,
            category: AuditCategory.Action,
            outcome: AuditOutcome.Succeeded,
            target: new AuditTarget(/* tenant target */),
            metadata: new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["from_state"] = before.State.ToString(),
                ["to_state"] = after.State.ToString(),
                ["initiator"] = transition.Initiator.ToString(),
                ["mechanism"] = transition.Mechanism ?? string.Empty,
            });

        await auditLog.Append(entry);
    }

    private static string MapTransitionToEventName(TenantState from, TenantState to)
        => (from, to) switch
        {
            (TenantState.Prospect, TenantState.Trialing) => AuditEvents.TenantProvisioned,
            (_, TenantState.Suspended) => AuditEvents.TenantSuspended,
            (TenantState.Suspended, TenantState.Active) => AuditEvents.TenantReinstated,
            (_, TenantState.Offboarding) => AuditEvents.TenantOffboarding,
            (TenantState.Offboarding, TenantState.Closed) => AuditEvents.TenantClosed,
            _ => "tenant.state_changed",
        };

    private async ValueTask<PseudoUserToken?> ResolveActorTokenAsync(TenantStateTransition transition, CancellationToken ct)
    {
        if (transition.ActorUserId is not null)
        {
            var identity = await identityMap.ResolveByUserIdAsync(transition.ActorUserId, ct);
            return identity?.PseudoUserToken;
        }
        return null;
    }
}
```

**Note on synthetic actors.** For `Webhook` / `Scheduled` / `Customer (self-serve before tenant exists)` transitions where no `PseudoUserToken` is appropriate, the emitter **needs a path that uses a synthetic actor string**. Two options:

- **Option A:** Add a synthetic-actor `PseudoUserToken.System(string label)` factory to packet 02's value type — but pseudonymous tokens are random, not labeled, so this would be a separate type. Awkward.
- **Option B:** For synthetic actors, use the **legacy `string Actor` constructor** of `AuditEntry` (which still exists in v0.2.0 per packet 02's transitional accommodation) with a clearly-synthetic actor name like `webhook-stripe-payment-failed`. The PII-rejection helper passes synthetic strings; the audit substrate accepts them; the boundary intent is preserved (the synthetic string is not PII).

**Option B is the recommended pattern.** Document it in Auth's README and in `constitution/gdpr-erasure-canary.md` (which the canary spec from packet 04 already permits — synthetic actors pass the boundary). The audit substrate ends up with a mix of pseudonymous-token actors (user-driven) and synthetic-string actors (system/webhook/scheduled-driven); both are legitimate, both are non-PII, both satisfy invariant 78.

The `EmitTransitionAuditAsync` helper above branches: if a `PseudoUserToken` resolves, use `CreatePseudonymous`; otherwise, use the legacy constructor with the synthetic actor string from `transition.Mechanism` or a fallback.

### 2. Auth-side IdentityMap erasure emission

In `HoneyDrunk.Auth/Identity/IdentityMap.cs`:

```csharp
public async ValueTask EraseUserAsync(PseudoUserToken token, string gdprRequestId, CancellationToken ct)
{
    var existed = await HardDeleteUserRowAsync(token, ct);

    // Emit UserErased regardless of whether the row existed (idempotent erasure
    // means the call is legitimate; the audit substrate records the request).
    var entry = AuditEntry.CreatePseudonymous(
        id: AuditEntryId.New(),
        occurredAt: DateTimeOffset.UtcNow,
        actor: token,                           // the orphaned token references itself
        tenantToken: /* unknown post-erasure */,
        eventName: AuditEvents.UserErased,
        category: AuditCategory.Action,
        outcome: AuditOutcome.Succeeded,
        target: new AuditTarget(/* user target */),
        metadata: new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["gdpr_request_id"] = gdprRequestId,
            ["row_existed"] = existed.ToString(),
        });

    await auditLog.Append(entry);
}
```

The `actor` is the orphaned token referencing itself — this is intentional and is the GDPR-compliant outcome (the canary spec verifies the token is unresolvable post-erasure).

### 3. Communications-side: drop `EmitTenantProvisionedAuditStep`; emit prospect-rejection and workflow-failure

In `HoneyDrunk.Communications/TenantLifecycle/TenantLifecycleWorkflow.cs` (extend packet 05's implementation):

```csharp
public async ValueTask<TenantId> ProvisionAsync(Prospect prospect, CancellationToken ct)
{
    // Step 1: Allocate TenantId (this calls ITenantStore.CreateProspectAsync,
    // which records the Tenant in Prospect state; the immediately-following
    // transition to Trialing is what emits TenantProvisioned via Auth.)
    var tenant = await _allocateTenantId.ExecuteAsync(prospect, $"...:tenant_id", ct);

    // Trigger the Prospect → Trialing transition. Auth emits TenantProvisioned here.
    await _tenantStore.TransitionAsync(
        tenant.TenantId,
        TenantState.Trialing,
        new TenantStateTransition(
            from: TenantState.Prospect,
            to: TenantState.Trialing,
            initiator: TransitionInitiator.Ops,
            mechanism: "prospect approval via Studios admin console",
            actorUserId: prospect.ApproverUserId),
        ct);

    // Steps 2-7: Vault namespace, Auth scope, owner role, partition, quota, billing customer.
    // All currently no-op contract seams.

    // Step 9 (renumbered from packet 05's step 9): welcome email.
    // (Old step 8 - EmitTenantProvisionedAuditStep - is dropped; Auth already emitted.)
    await _sendWelcomeEmail.ExecuteAsync(tenant.TenantId, prospect.ContactEmail, $"...:welcome_email", ct);

    return tenant.TenantId;
}

public async ValueTask<Prospect> RejectAsync(string prospectId, string approverActor, string reason, CancellationToken ct)
{
    var prospect = await _prospectStore.GetByIdAsync(prospectId, ct)
        ?? throw new InvalidOperationException($"Prospect {prospectId} not found.");

    var rejected = prospect with { State = ProspectState.Rejected, Reason = reason };
    await _prospectStore.UpdateAsync(rejected, ct);

    // Emit prospect.rejected — no TenantId yet, no PseudoTenantToken yet.
    var actorIdentity = await _identityMap.ResolveByUserIdAsync(approverActor, ct);
    var entry = AuditEntry.CreatePseudonymous(
        id: AuditEntryId.New(),
        occurredAt: DateTimeOffset.UtcNow,
        actor: actorIdentity?.PseudoUserToken
               ?? throw new InvalidOperationException($"Approver {approverActor} has no IdentityMap entry."),
        tenantToken: /* synthetic 'prospect' marker token? or null per AuditEntry.CreatePseudonymous signature? */,
        eventName: AuditEvents.ProspectRejected ?? "prospect.rejected",
        category: AuditCategory.Action,
        outcome: AuditOutcome.Succeeded,
        target: new AuditTarget(/* prospect target — type 'prospect', id=prospectId */),
        metadata: new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["prospect_id"] = prospectId,
            ["reason"] = reason,
        });

    await _auditLog.Append(entry);
    return rejected;
}
```

Workflow failure emission is similar — composed at the catch boundary in `ProvisionAsync`.

### 4. Tests

- Auth transition emission: `TransitionAsync(Prospect → Trialing)` produces an `AuditEntry` with `EventName = TenantProvisioned`, the correct `PseudoTenantToken`, and the resolved actor token.
- Auth synthetic-actor transition emission: `TransitionAsync(Active → PastDue, initiator: Webhook)` produces an `AuditEntry` using the legacy constructor with a synthetic actor string (e.g. `webhook-stripe-invoice-payment-failed`), tenant token populated.
- Auth identity-map erasure emission: `EraseUserAsync` produces a `UserErased` event referencing the (now-orphaned) token; the canary-spec assertions from packet 04 hold.
- Communications prospect-rejection emission: `RejectAsync` produces a `prospect.rejected` event with the approver's `PseudoUserToken` and the reason in metadata.
- Communications workflow-failure emission: forced failure in step 6 produces a `tenant.provisioning_failed` event naming step 6.
- Integration: end-to-end provisioning — submit prospect, approve, observe `TenantProvisioned` emission in the audit log (verifying the consolidation: Auth emits, Communications does NOT emit a duplicate).

## Affected Files

**Auth-side PR:**
- `src/HoneyDrunk.Auth/Tenants/TenantStore.cs` (extended — emission composition)
- `src/HoneyDrunk.Auth/Identity/IdentityMap.cs` (extended — `UserErased` emission)
- `src/HoneyDrunk.Auth/CHANGELOG.md` (append to in-progress entry, OR new patch entry if `0.6.0` shipped)
- `src/HoneyDrunk.Auth/README.md` (document the synthetic-actor pattern and the emission boundary)
- Repo-level `CHANGELOG.md` (append or patch)
- Test project

**Communications-side PR:**
- `src/HoneyDrunk.Communications/TenantLifecycle/TenantLifecycleWorkflow.cs` (extended — drop `EmitTenantProvisionedAuditStep`, add prospect-rejection and workflow-failure emissions)
- `src/HoneyDrunk.Communications/TenantLifecycle/ProspectIntake.cs` (extended — emission in `RejectAsync`)
- `src/HoneyDrunk.Communications/CHANGELOG.md` (append to in-progress entry, OR new patch entry)
- `src/HoneyDrunk.Communications/README.md` (document the workflow emission map)
- Repo-level `CHANGELOG.md` (append or patch)
- Test project

**Optional Audit-side PR (option 1 from Cross-Repo note):**
- `src/HoneyDrunk.Audit.Abstractions/AuditEvents.cs` (extended — add `ProspectRejected`, `TenantProvisioningFailed`, `TenantStateChanged` constants)
- `src/HoneyDrunk.Audit.Abstractions/CHANGELOG.md` (new `[0.2.1]` patch entry)
- Repo-level `HoneyDrunk.Audit/CHANGELOG.md`

## NuGet Dependencies
- No new packages.
- Auth-side PR consumes `HoneyDrunk.Audit.Abstractions` `0.2.0` (already referenced via packet 03). If option 1 from Cross-Repo note is taken, bump to `0.2.1`.
- Communications-side PR consumes `HoneyDrunk.Audit.Abstractions` and `HoneyDrunk.Auth.Abstractions` (already referenced via packet 05).

## Boundary Check
- [x] Auth emits at state-machine transitions — the natural emission boundary (Auth owns the state machine; emitting from inside `TransitionAsync` is consistent with the existing pattern Auth's v0.5.0 token-validation audit emissions).
- [x] Communications emits workflow-specific events (prospect rejection, workflow failure) — events that don't correspond to a state-machine transition. Per ADR-0019, Communications owns decisions/workflows; these are its own concerns to record.
- [x] No emission duplication. The `EmitTenantProvisionedAuditStep` from packet 05's scaffold is **dropped** as redundant with Auth's transition emission. This packet's documentation is explicit about the consolidation.
- [x] Audit emissions use `AuditEntry.CreatePseudonymous` for user-actor events; the legacy `string Actor` constructor for synthetic-actor events (`webhook-*`, `scheduled-job-*`). Both pass invariant 78 (the legacy path's PII-rejection helper accepts synthetic strings).
- [x] No new cross-Node runtime dependency beyond what packets 02, 03, 05 already wired.
- [x] Invariant 47 preserved — `IAuditLog.Append` is append-only.

## Acceptance Criteria

**Auth-side PR acceptance:**
- [ ] `TenantStore.TransitionAsync` emits an `AuditEntry` after every successful transition; the `EventName` maps per the table in Proposed Implementation
- [ ] Transitions with a resolvable `ActorUserId` use `AuditEntry.CreatePseudonymous` with the resolved `PseudoUserToken`
- [ ] Transitions without a user actor (`Webhook` / `Scheduled` / synthetic initiator) use the legacy `string Actor` constructor with a synthetic actor name (e.g. `webhook-stripe-invoice-payment-failed`, `scheduled-job-pastdue-sweep`) — the synthetic name passes the audit-writer PII-rejection helper from packet 02
- [ ] `IdentityMap.EraseUserAsync` emits `UserErased` with the orphaned `PseudoUserToken` as actor; the metadata carries the `gdpr_request_id`
- [ ] `IdentityMap.EraseTenantAsync` does NOT emit a separate event — `TenantClosed` is already emitted by `TransitionAsync(Closed)` (documented asymmetry with user-erasure)
- [ ] All emissions include `from_state`, `to_state`, `initiator`, `mechanism`, optional `reason` in metadata
- [ ] Auth's CHANGELOG appended (in-progress `[0.6.0]`) or new patch entry; the entry references the audit-emission wiring
- [ ] Auth's README documents the synthetic-actor pattern and the emission boundary
- [ ] Unit tests cover: resolvable-actor emission; synthetic-actor emission; idempotency-map-erasure emission; transitions not specifically named (Active → PastDue) use the `tenant.state_changed` event name

**Communications-side PR acceptance:**
- [ ] `TenantLifecycleWorkflow.ProvisionAsync` does NOT emit `TenantProvisioned` directly — the emission is delegated to Auth's `TransitionAsync(Prospect → Trialing)` call
- [ ] `EmitTenantProvisionedAuditStep` is **dropped** from the step list (the workflow comment / docs reflect the consolidation)
- [ ] `IProspectIntake.RejectAsync` emits a `prospect.rejected` event with the approver's `PseudoUserToken` and the rejection reason in metadata
- [ ] Workflow failures emit a `tenant.provisioning_failed` event naming the failed step in metadata
- [ ] Communications' CHANGELOG appended (in-progress `[0.3.0]`) or new patch entry
- [ ] Communications' README documents the workflow → audit-event mapping
- [ ] Unit tests cover: end-to-end provisioning emits exactly one `TenantProvisioned` (verifying no duplication); prospect rejection emits `prospect.rejected`; workflow failure emits `tenant.provisioning_failed`

**Audit-side PR acceptance (if option 1):**
- [ ] `HoneyDrunk.Audit.Abstractions` gains `ProspectRejected`, `TenantProvisioningFailed`, `TenantStateChanged` constants
- [ ] Audit solution bumps `0.2.0 → 0.2.1` (patch, additive constants only)
- [ ] Audit's CHANGELOG entry describes the additive constants

**General acceptance:**
- [ ] Tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes on both Auth and Communications repos
- [ ] No new types added; this packet composes existing types (with the small exception of new event-name constants if option 1 is taken)
- [ ] The canary specification from packet 04's assertions hold: a test erasure produces `UserErased` referencing an orphaned token; the audit substrate retains the entry; resolution returns null

## Human Prerequisites
- [ ] **Cross-repo PR coordination.** This packet's PRs land in Auth, Communications, and (optionally) Audit. Order: Audit first (if option 1; trivial additive patch), then Auth, then Communications. A human acks each merge before the next PR is filed.
- [ ] **NuGet release of upstream packages between PRs (if version bumps were taken instead of in-progress CHANGELOG appends).** If Auth was bumped to `0.6.1` and Communications consumes `0.6.1`, a human pushes the `HoneyDrunk.Auth` `0.6.1` git release tag before the Communications PR builds. Same for Audit `0.2.1` → Auth. Agents merge code but do not tag.

## Referenced ADR Decisions

**ADR-0050 D3 — Provisioning emits `TenantProvisioned`.** This packet wires the emission via Auth's `TransitionAsync(Prospect → Trialing)`. The workflow's step 8 (the dropped `EmitTenantProvisionedAuditStep`) is consolidated into the Auth-side transition emission.

**ADR-0050 D4 — Suspension emits `TenantSuspended`.** Wired via Auth's `TransitionAsync(* → Suspended)`.

**ADR-0050 D5 — Offboarding emits `TenantOffboarding`; Close emits `TenantClosed`.** Wired via Auth's `TransitionAsync(* → Offboarding)` and `TransitionAsync(Offboarding → Closed)`.

**ADR-0050 D6 — Erasure emits `UserErased`; the orphaned `PseudoUserToken` is the actor.** Wired via Auth's `IdentityMap.EraseUserAsync`. The audit substrate retains the entry referencing the now-unresolvable token; the canary spec from packet 04 verifies this end-to-end.

**ADR-0050 D6 — Synthetic actors pass the boundary.** The PII-rejection helper from packet 02 accepts synthetic strings (`webhook-*`, `scheduled-job-*`); these are non-PII operational identifiers and are the appropriate actor for system-initiated transitions.

**Invariant 78 (this initiative) — Audit substrate accepts only pseudonymous tokens; PII rejected at the boundary.** This packet's emissions use `CreatePseudonymous` (for user-actor) or synthetic strings (for system-actor); both satisfy invariant 78.

**Invariant 79 (this initiative) — Every tenant transition is audited and initiator-attributed.** This packet is what wires the audit emission at every transition; without this packet, invariant 79 is unsatisfied for state-machine transitions.

**Invariant 47 (referenced) — Audit substrate is append-only.** All emissions through `IAuditLog.Append`.

**Invariant 27 (constraint) — Solution-wide version coherence.** Auth and Communications are already at minor-bumped versions from packets 03 and 05; this packet appends to their CHANGELOGs or takes patch bumps as appropriate.

## Constraints
- **Auth is the emission home for state-machine transitions.** Communications is the emission home for workflow-only concerns (prospect rejection, workflow failure). The split is clean and consistent with ADR-0019 (Communications owns workflows; Auth owns identity + state).
- **Do NOT duplicate emissions.** `EmitTenantProvisionedAuditStep` is dropped (or replaced with a no-op marker step that emits nothing) — Auth's transition emission is the single source. This is a behavioral change to packet 05's scaffold; document it explicitly in the Communications PR description.
- **Synthetic actors use the legacy constructor.** `webhook-stripe-*`, `scheduled-job-*`, `customer-self-serve` strings pass the audit-writer PII-rejection helper (packet 02). They are non-PII operational identifiers. Document the pattern in Auth's README.
- **`UserErased` references the orphaned token as actor.** The actor is the now-unresolvable `PseudoUserToken`. This is intentional — the canary verifies the resolution fails post-erasure. Do NOT replace the token with a synthetic string here; the canary's assertion #2 (audit substrate retains the unresolvable token) requires the orphaned token to remain.
- **`TenantClosed` is emitted at the state transition, NOT at the identity-map deletion.** This asymmetry with `UserErased` is intentional and documented in the README. `IdentityMap.EraseTenantAsync` is a deletion mechanic without its own audit event; the workflow's `CloseAsync` invokes `TransitionAsync(Closed)` (which emits) THEN `EraseTenantAsync` (which doesn't emit).
- **Version-bump or CHANGELOG-append is implementation-time.** If packet 03 / packet 05 have shipped to NuGet between then and now, this packet bumps Auth and Communications to patch versions. If they're still in-progress on `main`, append to the in-progress CHANGELOG entries. Invariant 27 is satisfied either way as long as every non-test `.csproj` in the solution carries the same version.
- **New event-name constants are optional.** Option 1 (add to Audit.Abstractions and patch-bump) is preferred; option 2 (inline strings at emission sites) is acceptable. Choose at execution time.
- **Tests in both repos.** Both PRs require their own test coverage; emissions are testable via an in-memory `IAuditLog` capturing entries.
- **Cross-repo PR ordering.** Audit (if option 1) → Auth → Communications. Each PR's NuGet release happens via a human-pushed git tag between PRs.

## Labels
`feature`, `tier-2`, `core`, `adr-0050`, `wave-5`

## Agent Handoff

**Objective:** Wire the tenant-lifecycle audit emissions across Auth (state-machine transitions, identity-map erasure) and Communications (workflow-only concerns: prospect rejection, workflow failure). Drop the redundant `EmitTenantProvisionedAuditStep` from packet 05's scaffold. Use `AuditEntry.CreatePseudonymous` for user-actor events and the legacy `string Actor` constructor with synthetic strings for system-actor events.

**Target:** `HoneyDrunk.Auth` for the primary PR; a sibling Communications PR follows. **The executor may split this into 07a (Auth) and 07b (Communications) packets if cross-repo coordination is friction-heavy.**

**Context:**
- Goal: Make ADR-0050's audit emissions actually flow — the missing wiring between packets 03/05 and the audit substrate. Without this, invariant 79 is unsatisfied (transitions are not yet audit-emitted).
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 5 (closes the foundation).
- ADRs: ADR-0050 D3/D4/D5/D6 (the events), ADR-0030/ADR-0031 (audit substrate, preserved), ADR-0019 (Communications/Auth boundary, preserved).

**Acceptance Criteria:** As listed above (Auth-side, Communications-side, optional Audit-side, general).

**Dependencies:**
- `work-item:05` — Communications has the workflow scaffold to extend.
- `work-item:06` — Data has the export pipeline with its own audit emission (no overlap; named to confirm full Wave 4 has landed).

**Constraints:**
- Auth is the emission home for state transitions; Communications for workflow-only events.
- Do NOT duplicate emissions — drop `EmitTenantProvisionedAuditStep` from the workflow.
- Synthetic actors use the legacy `string Actor` constructor with non-PII strings.
- `UserErased` references the orphaned token as actor (intentional; canary verifies).
- `TenantClosed` is emitted at the state transition, not at the identity-map deletion (asymmetry with `UserErased` — intentional).
- Cross-repo PR ordering: Audit (optional) → Auth → Communications. Human-pushed NuGet release tags between PRs.
- Version-bump or CHANGELOG-append per the in-flight state at execution time.

**Key Files:**
- `src/HoneyDrunk.Auth/Tenants/TenantStore.cs` (extended)
- `src/HoneyDrunk.Auth/Identity/IdentityMap.cs` (extended)
- `src/HoneyDrunk.Communications/TenantLifecycle/TenantLifecycleWorkflow.cs` (extended — drop step + add failure emission)
- `src/HoneyDrunk.Communications/TenantLifecycle/ProspectIntake.cs` (extended — add rejection emission)
- Optional: `src/HoneyDrunk.Audit.Abstractions/AuditEvents.cs` (extended — new constants)
- READMEs in Auth and Communications documenting the emission map
- CHANGELOGs (append or patch)

**Contracts:** None new (with the optional exception of additional event-name constants in `AuditEvents`). This packet is composition, not contract surface.
