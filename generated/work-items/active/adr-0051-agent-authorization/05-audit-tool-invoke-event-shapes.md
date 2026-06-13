---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["feature", "tier-2", "ai", "audit", "adr-0051", "wave-3"]
dependencies: ["work-item:03", "work-item:04"]
adrs: ["ADR-0051"]
wave: 3
initiative: adr-0051-agent-authorization
node: honeydrunk-audit
---

# Register tool.invoke.granted and tool.invoke.denied event shapes in HoneyDrunk.Audit

## Summary
Extend the Audit Node's event-shape registry to recognize the two new event names ADR-0051 D10 commits — `tool.invoke.granted` and `tool.invoke.denied` — with their canonical 13-field shape, and ship a small documentation/constants surface in `HoneyDrunk.Audit.Abstractions` so emitters (Capabilities, when its Phase-2 follow-up lands) and queriers (Operator dashboards, forensic queries) reference one shared definition. This is the version-bumping packet for the `HoneyDrunk.Audit` solution.

## Context
ADR-0051 D10 specifies the exact audit-record shape for every `IToolInvoker` authorization decision: 13 fields including `event` (`tool.invoke.granted` or `tool.invoke.denied`), `agent.id`, `agent.runId`, `agent.bundles`, `onBehalfOf.type`, `onBehalfOf.id`, `tenant.id`, `tool.name`, `tool.requiredCapabilities`, `effective.capabilities`, `decision`, `deny.reason`, `deny.missingCapability`, plus `timestamp` and `traceId`.

The existing `src/HoneyDrunk.Audit.Abstractions/AuditEntry.cs` already has a generic carrier: `EventName` (string), `Actor` (string), `Category` (already includes `AgentAction = 4`), `Outcome`, `Target`, `TenantId`, `CorrelationId`, plus a free-form `Metadata` `IReadOnlyDictionary<string, string>`. The `AuditEntry` shape **does not need to change** — the ADR-0051 D10 fields fit into the existing carrier:

- `event` ← `EventName`
- `agent.id`, `agent.runId` ← `Actor` (composed: `"agent:<id>@<runId>"`) and/or `Metadata` keys
- `onBehalfOf.type` / `onBehalfOf.id` ← `Metadata` keys
- `tool.name` ← `Target.Name` (per the existing `AuditTarget` shape)
- `tool.requiredCapabilities`, `effective.capabilities` ← `Metadata` keys (joined string lists)
- `deny.reason` ← maps to the string form of one of the four new `AuthorizationDenyCode` values from packet 04
- `traceId` ← `CorrelationId` (per ADR-0040)
- `timestamp` ← `OccurredAt`
- `tenant.id` ← `TenantId`
- `decision` ← `Outcome` (Granted maps to one outcome; Denied to another — verify the existing `AuditOutcome` values include the right mapping; if not, this packet extends `AuditOutcome` minimally)

This packet's job is therefore not to invent a new event shape — it is to **canonicalize the field-naming for the two new events**: a `KnownEventNames` static class (or equivalent constants surface) carrying the two event name literals, and a `ToolInvokeAuditFields` static class (or equivalent metadata-key catalog) carrying the canonical `Metadata` keys (`"agent.id"`, `"agent.runId"`, `"agent.bundles"`, `"onBehalfOf.type"`, `"onBehalfOf.id"`, `"tool.requiredCapabilities"`, `"effective.capabilities"`, `"deny.reason"`, `"deny.missingCapability"`). This is the discoverability surface every emitter and querier compiles against — typo-safe, refactor-safe, documented.

`HoneyDrunk.Audit` is a live Node at v0.1.0. The current `CHANGELOG.md` already has an Unreleased section recording a Standards bump (`HoneyDrunk.Standards.Tests` 0.2.9 adoption); per the user's standing convention ("No commits under CHANGELOG Unreleased — move to dated versioned section + SemVer bump before committing"), the in-flight Unreleased entry must be consolidated into the dated version entry this packet creates, or kept as a separate Unreleased entry that this packet's PR explicitly does not touch (executor confirms at execution time). The clean option is to **roll the existing Unreleased content into the same new minor version this packet bumps**, since both are additive.

## Scope

- `HoneyDrunk.Audit.Abstractions/` — new files:
  - `KnownEventNames.cs` — a static class (or `static readonly` constants on an existing config-like type) carrying:
    - `public const string ToolInvokeGranted = "tool.invoke.granted";`
    - `public const string ToolInvokeDenied = "tool.invoke.denied";`
    - XML doc cross-referencing ADR-0051 D10 for the field shape.
  - `ToolInvokeAuditFields.cs` (or appropriately-named, matching the existing repo's naming style) — a static class carrying the canonical `Metadata` keys as `const string` values:
    - `AgentId = "agent.id"`
    - `AgentRunId = "agent.runId"`
    - `AgentBundles = "agent.bundles"`
    - `OnBehalfOfType = "onBehalfOf.type"`
    - `OnBehalfOfId = "onBehalfOf.id"`
    - `ToolRequiredCapabilities = "tool.requiredCapabilities"`
    - `EffectiveCapabilities = "effective.capabilities"`
    - `DenyReason = "deny.reason"`
    - `DenyMissingCapability = "deny.missingCapability"`
    - XML doc.

- (Optional, verify at execution time) `src/HoneyDrunk.Audit.Abstractions/AuditOutcome.cs` — extend with `Granted` / `Denied` values if the existing enum does not already distinguish the two for the agent-tool surface. Verify the existing enum first; only extend if needed. If extended, ship per-package CHANGELOG entry; if not, no change.

- (Optional, verify at execution time) `src/HoneyDrunk.Audit.Abstractions/AuditCategory.cs` — confirm `AgentAction = 4` is the correct category for these events (it is, per the existing comment). No change unless a refinement is warranted.

- `HoneyDrunk.Audit.Abstractions.csproj` — `HoneyDrunk.Kernel.Abstractions` `PackageReference` bumped to `0.8.0` (the packet 03 release; the constants don't directly use the type, but `AuditEntry` already references `TenantId` from `HoneyDrunk.Kernel.Abstractions.Identity`, so the package may already be referenced — verify at execution time). If `HoneyDrunk.Auth.Abstractions` is added as a dependency (only if `AuthorizationDenyCode` is referenced directly — e.g., to provide a typed helper that maps `AuthorizationDenyCode → deny.reason` string), bump that too — but per Boundary Check below, prefer keeping Audit.Abstractions free of Auth.Abstractions to preserve invariant 1.

- Every non-test `.csproj` in the `HoneyDrunk.Audit` solution version-bumped one minor version (`0.1.0 → 0.2.0`) (invariant 27).

- `src/HoneyDrunk.Audit.Abstractions/CHANGELOG.md` and `README.md` updated.

- Repo-level `CHANGELOG.md` — new `[0.2.0]` entry. **Consolidate the existing Unreleased entry into the new `[0.2.0]` entry** per the no-Unreleased-commits convention; or, if the Standards bump in Unreleased has already shipped to NuGet, leave that note in place and add the new authz-event-shape section under the same `[0.2.0]`.

## Proposed Implementation

1. **`KnownEventNames`** — new static class in `HoneyDrunk.Audit.Abstractions`:
   ```
   public static class KnownEventNames
   {
       /// <summary>Tool invocation was authorized and dispatched per ADR-0051 D10.</summary>
       public const string ToolInvokeGranted = "tool.invoke.granted";

       /// <summary>Tool invocation was denied; see deny.reason metadata key per ADR-0051 D10.</summary>
       public const string ToolInvokeDenied = "tool.invoke.denied";
   }
   ```
   If a similar constants-style file already exists in the repo (e.g., a `WellKnown*` file), append the constants there rather than creating a duplicate-shape file. The executor verifies at execution time.

2. **`ToolInvokeAuditFields`** — new static class carrying the canonical metadata-key constants listed in Scope. Each `const string` value is XML-documented with its purpose and the type of value the emitter is expected to store (e.g., `AgentBundles` carries a semicolon-separated list of `bundle:<name>@v<n>` references; `EffectiveCapabilities` carries a semicolon-separated list of capability names with no values).

3. **No `AuditEntry` schema change.** The existing `AuditEntry` shape carries everything the ADR-0051 D10 fields need. Emitters compose the entry with the new `EventName` constant, `Actor = $"agent:{agentId.Value}"` (or a similar canonical composition the executor settles), `Category = AuditCategory.AgentAction`, `Target = new AuditTarget(...) { Name = toolName }`, `Outcome = AuditOutcome.Granted/Denied`, `CorrelationId = traceId`, and the rest in `Metadata` keyed by the new `ToolInvokeAuditFields` constants.

4. **`AuditOutcome` extension (only if needed)** — read `src/HoneyDrunk.Audit.Abstractions/AuditOutcome.cs` at execution time. If the existing enum already carries values that fit `Granted` / `Denied` for the agent-tool surface (e.g., `Success` / `Failure`, or a literal `Allowed` / `Denied`), use those — no change. If not, add explicit `AuthorizationGranted` / `AuthorizationDenied` members.

5. **Unit tests** — `HoneyDrunk.Audit.Abstractions` test project: verify the constants are exposed as `const string` with the exact ADR-0051 D10 field names; verify any new `AuditOutcome` member compiles and serializes (if added). A small "round-trip" test where an `AuditEntry` is constructed using the new constants and the field values are recoverable proves the shape works end-to-end against the existing carrier — no `IAuditLog`/runtime invocation, pure carrier composition.

6. **Versioning** — bump every non-test `.csproj` in the `HoneyDrunk.Audit` solution from `0.1.0` to `0.2.0` in one commit (invariant 27). Repo-level `CHANGELOG.md` `[0.2.0]` entry. Per-package CHANGELOG: `HoneyDrunk.Audit.Abstractions` gets an entry (real changes); `HoneyDrunk.Audit.Data` is an alignment bump only and gets NO per-package entry (invariant 12/27). Roll the existing Unreleased Standards-bump line into the new `[0.2.0]` entry if it hasn't already shipped; the executor verifies the repo state.

7. **README** — update `src/HoneyDrunk.Audit.Abstractions/README.md` to document `KnownEventNames` and `ToolInvokeAuditFields`, with a short worked example of composing an `AuditEntry` for `tool.invoke.granted` so a Capabilities-side emitter has a copy-pasteable template.

## Affected Files
- `src/HoneyDrunk.Audit.Abstractions/KnownEventNames.cs` (or extend an existing similarly-purposed file)
- `src/HoneyDrunk.Audit.Abstractions/ToolInvokeAuditFields.cs`
- `src/HoneyDrunk.Audit.Abstractions/AuditOutcome.cs` (only if extension is needed — verify at execution time)
- `src/HoneyDrunk.Audit.Abstractions/HoneyDrunk.Audit.Abstractions.csproj` — version bump; possibly `HoneyDrunk.Kernel.Abstractions` reference bumped to `0.8.0` if reference is direct
- `src/HoneyDrunk.Audit.Data/HoneyDrunk.Audit.Data.csproj` — version alignment
- `src/HoneyDrunk.Audit.Abstractions/CHANGELOG.md`, `src/HoneyDrunk.Audit.Abstractions/README.md`
- Repo-level `CHANGELOG.md`
- `HoneyDrunk.Audit.Abstractions` test project — new tests

## NuGet Dependencies
- **`HoneyDrunk.Audit.Abstractions`** — verify `HoneyDrunk.Kernel.Abstractions` is already referenced (it is, for `TenantId` and `CorrelationId`). Bump that reference to `0.8.0` to align with the AgentId-bearing Kernel that packet 03 ships, even though this packet's constants don't directly reference `AgentId` — keeping the reference current is cleaner than skewing.
- **`HoneyDrunk.Audit.Abstractions`** does NOT reference `HoneyDrunk.Auth.Abstractions`. The `deny.reason` field's value mapping (`AuthorizationDenyCode → "capability_missing"` string) is the **emitter's** responsibility (the Capabilities Node, in its Phase-2 follow-up), not Audit's. Adding an Auth.Abstractions reference here would couple two Abstractions packages unnecessarily — see Boundary Check.
- **`HoneyDrunk.Audit.Data`** — picks up the Kernel.Abstractions bump transitively.
- The unit-test project follows the repo's existing test stack; no new packages.

## Boundary Check
- [x] Event taxonomy and audit-field canonicalization live in `HoneyDrunk.Audit.Abstractions` — this is the discoverability home for every Node that emits or queries audit events.
- [x] **No reference from `HoneyDrunk.Audit.Abstractions` to `HoneyDrunk.Auth.Abstractions`.** The `deny.reason` field is a string in the audit record; the mapping from `AuthorizationDenyCode` to that string lives at the emitter (Capabilities Node, Phase-2 follow-up). Coupling Audit.Abstractions to Auth.Abstractions for a string-valued field is unnecessary and would tighten the dependency graph (invariant 4).
- [x] No new event *carrier* — the existing `AuditEntry` shape handles the ADR-0051 D10 fields. This packet only canonicalizes the field-naming and event-name constants.
- [x] No runtime emission logic — the `IToolInvoker.InvokeAsync` audit emission is the Capabilities Node's responsibility (Phase-2 follow-up in `adr-0017-capabilities-standup`).
- [x] Records drop the `I`; interfaces keep it. `KnownEventNames` and `ToolInvokeAuditFields` are static classes (no `I`).

## Acceptance Criteria
- [ ] `HoneyDrunk.Audit.Abstractions` exposes `KnownEventNames.ToolInvokeGranted = "tool.invoke.granted"` and `KnownEventNames.ToolInvokeDenied = "tool.invoke.denied"` as `const string` values
- [ ] `HoneyDrunk.Audit.Abstractions` exposes `ToolInvokeAuditFields` carrying the nine canonical metadata-key constants per ADR-0051 D10 (`agent.id`, `agent.runId`, `agent.bundles`, `onBehalfOf.type`, `onBehalfOf.id`, `tool.requiredCapabilities`, `effective.capabilities`, `deny.reason`, `deny.missingCapability`)
- [ ] No new `AuditEntry` field or breaking schema change — the existing carrier handles the new fields via the established `EventName`/`Actor`/`Target`/`Metadata`/`CorrelationId` slots
- [ ] `AuditOutcome` is extended only if the existing enum cannot already represent Granted/Denied for the agent-tool surface; if extended, the change is additive
- [ ] `HoneyDrunk.Audit.Abstractions.csproj` references `HoneyDrunk.Kernel.Abstractions` at version `0.8.0`
- [ ] `HoneyDrunk.Audit.Abstractions` does NOT take a `PackageReference` on `HoneyDrunk.Auth.Abstractions` (the `deny.reason` string mapping is the emitter's responsibility)
- [ ] All new public types have XML documentation including a cross-reference to ADR-0051 D10
- [ ] Unit tests cover constant values, optional `AuditOutcome` member compilation, and an end-to-end `AuditEntry` composition using the new constants
- [ ] Every non-test `.csproj` in the solution is at version `0.2.0` in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.2.0]` dated section describing the additive event-shape registration (and consolidating the prior Unreleased Standards-bump line if it has not yet been published — verify at execution time)
- [ ] `src/HoneyDrunk.Audit.Abstractions/CHANGELOG.md` has a corresponding `[0.2.0]` entry; `HoneyDrunk.Audit.Data` is an alignment bump with NO per-package entry (invariant 12/27)
- [ ] `src/HoneyDrunk.Audit.Abstractions/README.md` documents the new constants and shows a worked `tool.invoke.granted` composition example
- [ ] The `pr-core.yml` tier-1 gate and the Audit contract-shape canary pass — the new constants are additive paired with the version bump

## Human Prerequisites
- [ ] **`HoneyDrunk.Kernel.Abstractions` `0.8.0` must be published before this packet's PR can compile.** This packet's csproj bumps the Kernel.Abstractions reference to `0.8.0` (the version packet 03 in this initiative ships). Agents never tag — a human pushes the Kernel git release tag after packet 03 merges; coordinate with the ADR-0042 Wave 2→3 release boundary if both initiatives land in the same Kernel release.
- [ ] **(Optional, downstream-only) Tag/release `HoneyDrunk.Audit` `0.2.0` after this packet merges** so the Capabilities Node's Phase-2 follow-up (in `adr-0017-capabilities-standup`) can compile against the new constants when it lands. This is not in this initiative's critical path — Capabilities Phase 2 has not yet been packaged — but is a clean step to flag.

## Referenced ADR Decisions

**ADR-0051 D10 — Audit record shape for authz decisions.** 13 fields: `event` (`tool.invoke.granted` / `tool.invoke.denied`), `agent.id`, `agent.runId`, `agent.bundles`, `onBehalfOf.type` (string?), `onBehalfOf.id` (string?, pseudonymous per ADR-0045 D7 PII rules), `tenant.id`, `tool.name`, `tool.requiredCapabilities`, `effective.capabilities` (names only, no secret values), `decision`, `deny.reason` (`"capability_missing"` / `"scope_mismatch"` / `"grant_expired"` / `"principal_type_mismatch"`), `deny.missingCapability`, `timestamp`, `traceId`. Emitted via `IAuditAppender`. If Audit is unavailable, tool invocation denies (fail-closed).

**ADR-0051 D3 — `IToolInvoker` emits `tool.invoke.granted` or `tool.invoke.denied`.** Step 5 emits granted on dispatch; step 6 emits denied on failure. The emitter is the `IToolInvoker` default implementation in the Capabilities Node; the audit record's field-naming is the canonicalization this packet ships.

**ADR-0030 Invariant 47 — Durable audit emission via `IAuditLog`.** This packet preserves the invariant — the new event names ride the existing `IAuditLog.AppendAsync(AuditEntry)` surface unchanged. The carrier is constant; the event name and field keys are new.

**ADR-0040 D3 — 730-day retention.** ADR-0051's audit volume at v1 is single-digit invocations per second across the Grid — well within the retention budget. No retention policy change in this packet.

**ADR-0045 D7 — PII pseudonymization.** The `onBehalfOf.id` field carries a **pseudonymous** principal id, not the raw user id. The Capabilities-side emitter is responsible for the pseudonymization; this packet documents the expectation on the `OnBehalfOfId` metadata-key constant's XML doc.

## Constraints

- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages, except other Abstractions.** `HoneyDrunk.Audit.Abstractions` references only `HoneyDrunk.Kernel.Abstractions`; do NOT add `HoneyDrunk.Auth.Abstractions` as a reference. The `deny.reason` field carries a string at the audit layer; the typed `AuthorizationDenyCode → string` mapping is the emitter's concern.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Audit.Abstractions` gets an entry; `HoneyDrunk.Audit.Data` (alignment bump only) gets none.
- **Invariant 13 — all public APIs have XML documentation.**
- **Invariant 27 — all projects in a solution share one version and move together.** Both `.csproj` files go to `0.2.0` in one commit.
- **No Unreleased commits.** The user's convention: do not commit under `## [Unreleased]`. Move any extant Unreleased entries into the new dated `[0.2.0]` section (or, if they have already been published as part of a different release, the executor should verify and leave the historical record intact — but no in-flight Unreleased should remain after this PR).
- **No `AuditEntry` schema change.** The existing carrier handles every ADR-0051 D10 field via the established slots. Resist the temptation to add a typed `AgentAuditEntry` subtype — that would fragment the audit surface.
- **No `IToolInvoker` emission logic.** That is the Capabilities Node's responsibility in its Phase-2 follow-up. This packet ships discoverability + canonicalization only.

## Labels
`feature`, `tier-2`, `ai`, `audit`, `adr-0051`, `wave-3`

## Agent Handoff

**Objective:** Ship `KnownEventNames.ToolInvokeGranted` / `ToolInvokeDenied` and `ToolInvokeAuditFields` constants in `HoneyDrunk.Audit.Abstractions` so emitters and queriers have one canonical reference for the ADR-0051 D10 event taxonomy and field-naming.

**Target:** `HoneyDrunk.Audit`, branch from `main`.

**Context:**
- Goal: Register the event taxonomy in Audit so when the Capabilities Node ships its Phase-2 `IToolInvoker` authz check and audit emission, the field names and event names are already canonicalized.
- Feature: ADR-0051 AI Agent Authorization rollout, Wave 3 (audit event taxonomy).
- ADRs: ADR-0051 D3/D10 (primary), ADR-0030 (audit substrate), ADR-0040 (telemetry/trace correlation), ADR-0045 (PII pseudonymization).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — `HoneyDrunk.Kernel.Abstractions` `0.8.0` exists in source (and is the version this packet's csproj references).
- `work-item:04` — `AuthorizationDenyCode` extended with the four new values exists in source (this packet documents the string forms of the four reasons on the `ToolInvokeAuditFields.DenyReason` XML doc; the typed enum is referenced only via the docstring, not via a `PackageReference`).

**Constraints:**
- Records drop the `I`; constants live in static classes.
- No `AuditEntry` schema change — the existing carrier handles every D10 field.
- No `HoneyDrunk.Auth.Abstractions` `PackageReference` — keep Audit.Abstractions decoupled from Auth (invariant 1 / 4).
- No `IToolInvoker` emission code — that ships in the Capabilities Phase-2 follow-up.
- Bump every non-test `.csproj` to `0.2.0` in one commit (invariant 27).
- Consolidate any existing CHANGELOG Unreleased entry into the new `[0.2.0]` per the no-Unreleased-commits convention.

**Key Files:**
- `src/HoneyDrunk.Audit.Abstractions/KnownEventNames.cs`, `ToolInvokeAuditFields.cs`
- Both `.csproj` files for the version bump
- `src/HoneyDrunk.Audit.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`

**Contracts:**
- `KnownEventNames` (new static class) — canonical event name constants for the ADR-0051 D10 event taxonomy.
- `ToolInvokeAuditFields` (new static class) — canonical `Metadata`-key constants for the ADR-0051 D10 record shape.
- `AuditEntry` (existing record) — unchanged; the new constants ride the existing carrier.
- `AuditOutcome` (existing enum) — extended only if the existing values don't fit `Granted`/`Denied` for agent-tool authz; verify first.
